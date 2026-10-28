#!/usr/bin/env python3
# Gate G1 labeling server: serves the evidence page on 127.0.0.1 and writes one labels.tsv line per human click.
import argparse
import hashlib
import hmac
import http.server
import importlib.util
import json
import os
import re
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
from datetime import datetime, timezone

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
VALUES = ('real', 'bogus', 'unknown')
DIFF_CAP = 200
MAX_BODY = 1024
KEYS = {'id', 'value', 'version'}


class LabelError(Exception):
    pass


def git(repo, *args):
    p = subprocess.run(['git', '-C', repo] + list(args), capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


def cited(dline):
    m = re.match(r'^D\d+: ([^\s:]+):(\d+)', dline)
    return (m.group(1), int(m.group(2))) if m else (None, None)


def sides(p):
    # numstat writes a rename as 'old => new' or 'pre/{old => new}/post'; both names count as the path
    m = re.match(r'^(.*)\{(.*) => (.*)\}(.*)$', p)
    if m:
        pre, a, b, post = m.groups()
        return [re.sub('/+', '/', pre + a + post), re.sub('/+', '/', pre + b + post)]
    return p.split(' => ', 1)


def evidence(repo, row):
    fix = row['fix_commit']
    subject = (git(repo, 'show', '-s', '--format=%h %s', fix) or '').strip()
    out = {'fix_sha': fix[:8], 'fix_subject': subject.partition(' ')[2] or '(fix commit unreachable)',
           'files': [], 'diff': '', 'diff_truncated': False}
    numstat = git(repo, 'show', '--numstat', '--format=', fix)
    path, line = cited(row['dline'])
    out['cited_path'], out['cited_line'] = path, line
    if numstat is None:
        out['hint'] = 'unknown'
        return out
    for l in numstat.splitlines():
        a, d, p = (l.split('\t') + ['', '', ''])[:3]
        out['files'].append({'path': p, 'add': a, 'del': d, 'cite': path in sides(p)})
    hit = [f for f in out['files'] if f['cite']]
    out['hint'] = 'touches' if hit else 'untouched'
    if hit:
        lines = (git(repo, 'show', '--format=', fix, '--', *sides(hit[0]['path'])) or '').splitlines()
        out['diff'] = '\n'.join(lines[:DIFF_CAP])
        out['diff_truncated'] = len(lines) > DIFF_CAP
    return out


def embed(data):
    s = json.dumps(data, ensure_ascii=True)
    return s.replace('<', '\\u003c').replace('>', '\\u003e').replace('&', '\\u0026')


def read_min_real():
    # None when score.py is not beside this file (a stripped copy): the page then shows no targets
    if not os.path.exists(os.path.join(HERE, 'score.py')):
        return None
    spec = importlib.util.spec_from_file_location('score_consts', os.path.join(HERE, 'score.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MIN_REAL


def sha(data):
    return hashlib.sha256(data).hexdigest()


def label_lines(data):
    # (id, value) for each non-header line, in file order
    return [tuple(l.split('\t', 1)) for l in data.decode('utf-8').split('\n')[1:] if l]


def validate_labels(ids, data):
    if b'\r' in data:
        raise LabelError('labels file has CRLF line endings')
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        raise LabelError('labels file is not UTF-8')
    lines = text.split('\n')
    if lines[-1] == '':
        lines.pop()
    if not lines or not lines[0].startswith('#'):
        raise LabelError('labels file has no # header as its first line')
    seen = []
    for l in lines[1:]:
        k, tab, v = l.partition('\t')
        if not tab or v not in VALUES:
            raise LabelError('labels file has a bad line: %r' % l[:80])
        if k in seen:
            raise LabelError('labels file repeats id %s' % k)
        seen.append(k)
    if set(ids) - set(seen):
        raise LabelError('labels file lacks corpus id %s' % sorted(set(ids) - set(seen))[0])
    if seen != ids:
        raise LabelError('labels file ids are not the corpus ids in corpus order')


def replace_line(data, id_, value):
    out, hit = [], False
    for l in data.splitlines(keepends=True):
        body = l.rstrip(b'\r\n')
        if not hit and not l.startswith(b'#') and body.split(b'\t', 1)[0] == id_.encode():
            l, hit = id_.encode() + b'\t' + value.encode() + l[len(body):], True
        out.append(l)
    return b''.join(out) if hit else None


def atomic_write(path, data):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix='.labels.', suffix='.tmp')
    try:
        os.chmod(tmp, stat.S_IMODE(os.stat(path).st_mode))
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)  # mut:atomic
        dfd = os.open(d, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def same(a, b):
    return hmac.compare_digest(str(a).encode('utf-8', 'replace'), str(b).encode('utf-8', 'replace'))


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = 'label'
    sys_version = ''
    timeout = 10
    _rec = None

    def log_message(self, *a):
        pass

    def _host_ok(self):
        return self.headers.get('Host') in self.server.hosts

    def _origin_ok(self):
        return self.headers.get('Origin') in self.server.origins

    def _token_ok(self):
        return same(self.headers.get('X-Label-Token', ''), self.server.token)

    def _send(self, status, ctype, body, extra=()):
        self._log(status)
        self.send_response(status)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status, obj):
        self._send(status, 'application/json', json.dumps(obj).encode())

    def _refuse(self, status, reason, **extra):
        self._json(status, dict({'error': reason}, **extra))

    def _log(self, status):
        if self._rec is None:
            return
        rec = dict(self._rec, ts=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), status=status,
                   remote=self.client_address[0], origin=self.headers.get('Origin'),
                   user_agent=(self.headers.get('User-Agent') or '')[:200])
        try:
            with self.server.log_lock, open(self.server.log, 'a', encoding='utf-8') as f:
                f.write(json.dumps(rec) + '\n')
        except OSError as e:
            print('label: could not write the log: %s' % e, file=sys.stderr, flush=True)

    def _page(self):
        S = self.server
        with open(S.labels, 'rb') as f:
            data = f.read()
        labels = dict(label_lines(data))
        nonce = secrets.token_urlsafe(16)
        page = {'rows': S.rows, 'labels': labels, 'version': sha(data), 'token': S.token,
                'min_real': S.min_real, 'max_bogus': None if S.min_real is None else len(S.rows) - S.min_real}
        html = (S.template.replace('__NONCE__', nonce).replace('__ROWS__', str(len(S.rows)))
                .replace('__DATA__', embed(page))).encode()
        csp = ("default-src 'none'; script-src 'nonce-%s'; style-src 'unsafe-inline'; connect-src 'self'; "
               "base-uri 'none'; form-action 'none'; frame-ancestors 'none'" % nonce)
        self._send(200, 'text/html; charset=utf-8', html, [('Content-Security-Policy', csp)])

    def do_GET(self):
        if not self._host_ok(): return self._refuse(403, 'host')  # mut:host
        path, _, query = self.path.partition('?')
        if path != '/':
            return self._refuse(404, 'not found')
        t = [p[2:] for p in query.split('&') if p.startswith('t=')]
        if not t or not same(t[0], self.server.token):
            return self._refuse(403, 'token')
        self._page()

    def do_POST(self):
        self._rec = {'id': None, 'old': None, 'new': None, 'version_before': None, 'version_after': None}
        try:
            if not self._host_ok(): return self._refuse(403, 'host')  # mut:host
            if self.path.partition('?')[0] != '/label':
                return self._refuse(404, 'not found')
            if not self._origin_ok(): return self._refuse(403, 'origin')  # mut:origin
            if not self._token_ok(): return self._refuse(403, 'token')  # mut:token
            body = self._read_body()
            if body is not None:
                self._apply(body)
        finally:
            self._drain()

    def _read_body(self):
        if self.headers.get('Content-Type', '').split(';')[0].strip().lower() != 'application/json':
            return self._refuse(400, 'content-type')
        n = self.headers.get('Content-Length')
        if n is None:
            return self._refuse(411, 'length required')
        if not n.isdigit():
            return self._refuse(400, 'bad length')
        if int(n) > MAX_BODY:
            return self._refuse(413, 'too large')
        self._unread = 0
        try:
            body = json.loads(self.rfile.read(int(n)))
        except ValueError:
            return self._refuse(400, 'not json')
        if not isinstance(body, dict) or set(body) != KEYS:
            return self._refuse(400, 'body must be an object with id, value and version')
        self._rec.update(id=body['id'], new=body['value'])
        if not all(isinstance(body[k], str) for k in KEYS):
            return self._refuse(400, 'id, value and version must be strings')
        if body['id'] not in self.server.ids:
            return self._refuse(400, 'unknown id')
        if body['value'] not in VALUES:
            return self._refuse(400, 'bad value')
        return body

    def _apply(self, body):
        S = self.server
        with S.lock:
            with open(S.labels, 'rb') as f:
                data = f.read()
            current = sha(data)
            self._rec['version_before'] = self._rec['version_after'] = current
            if body['version'] != current: return self._refuse(409, 'stale', version=current)  # mut:version
            old = dict(label_lines(data)).get(body['id'])
            self._rec['old'] = old
            if old != body['value']:
                new = replace_line(data, body['id'], body['value'])
                if new is None:
                    return self._refuse(500, 'labels file no longer matches the corpus')
                atomic_write(S.labels, new)
                self._rec['version_after'] = current = sha(new)
            self._json(200, {'ok': True, 'id': body['id'], 'value': body['value'], 'version': current})

    def _drain(self):
        # read what a refused POST left unread so closing the socket cannot reset the response
        n = self.headers.get('Content-Length', '')
        if n.isdigit() and 0 < int(n) <= 65536 and getattr(self, '_unread', 1):
            try:
                self.rfile.read(int(n))
            except OSError:
                pass

    def _not_allowed(self):
        self._refuse(405, 'method not allowed')

    do_PUT = do_DELETE = do_PATCH = do_OPTIONS = do_HEAD = _not_allowed


def make_server(corpus, labels, repo, log, port=0):
    with open(corpus, encoding='utf-8') as f:
        rows = [json.loads(l) for l in f if l.strip()]
    try:
        with open(labels, 'rb') as f:
            data = f.read()
    except OSError as e:
        raise LabelError('cannot read labels file: %s' % e.strerror)
    ids = [r['id'] for r in rows]
    validate_labels(ids, data)
    out_rows = []
    for r in rows:
        out_rows.append(dict({k: r[k] for k in ('id', 'unit', 'group', 'fail_ts', 'dline')}, **evidence(repo, r)))
    with open(os.path.join(HERE, 'label_page.html'), encoding='utf-8') as f:
        template = f.read()

    class Server(http.server.ThreadingHTTPServer):
        allow_reuse_address = False
        daemon_threads = True
        request_queue_size = 64

    srv = Server(('127.0.0.1', port), Handler)
    p = srv.server_address[1]
    srv.hosts = {'127.0.0.1:%d' % p, 'localhost:%d' % p}
    srv.origins = {'http://127.0.0.1:%d' % p, 'http://localhost:%d' % p}
    srv.token = secrets.token_urlsafe(32)
    srv.url = 'http://127.0.0.1:%d/?t=%s' % (p, srv.token)
    srv.rows, srv.ids, srv.template = out_rows, set(ids), template
    srv.labels, srv.log, srv.min_real = os.path.abspath(labels), log, read_min_real()
    srv.lock, srv.log_lock = threading.Lock(), threading.Lock()
    return srv


def open_browser(url):
    try:
        wsl = 'microsoft' in open('/proc/sys/kernel/osrelease').read().lower()
    except OSError:
        wsl = False
    for name in (['wslview', 'explorer.exe'] if wsl else ['xdg-open']):
        exe = shutil.which(name)
        if not exe:
            continue
        try:
            subprocess.Popen([exe, url], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            return
        except OSError:
            continue
    print('label: could not open a browser; open the URL above', flush=True)


def default_log(repo):
    g = git(repo, 'rev-parse', '--absolute-git-dir')
    if not g:
        raise LabelError('--log is required: %s is not in a git repository' % repo)
    return os.path.join(g.strip(), 'refutation-label-writes.log')


def parser():
    p = argparse.ArgumentParser(prog='label.py')
    s = p.add_subparsers(dest='cmd', required=True).add_parser('serve', help='serve the labeling page on 127.0.0.1')
    s.add_argument('--corpus', default=os.path.join(HERE, 'corpus.jsonl'))
    s.add_argument('--labels', default=os.path.join(HERE, 'labels.tsv'))
    s.add_argument('--repo', default=os.path.normpath(os.path.join(HERE, '..', '..')))
    s.add_argument('--port', type=int, default=0, help='0 picks a free port')
    s.add_argument('--log', default=None, help='write log, default <git dir>/refutation-label-writes.log')
    s.add_argument('--no-open', action='store_true', help='do not try to open a browser')
    return p


def counts(path):
    with open(path, 'rb') as f:
        vals = [v for _, v in label_lines(f.read())]
    return tuple(vals.count(v) for v in VALUES)


def serve(a):
    srv = make_server(a.corpus, a.labels, a.repo, a.log or default_log(a.repo), a.port)

    def stop(*_):
        threading.Thread(target=srv.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    print('label: ' + srv.url, flush=True)
    if not a.no_open:
        open_browser(srv.url)
    srv.serve_forever(poll_interval=0.2)
    srv.server_close()
    print('label: stopped real=%d bogus=%d unknown=%d' % counts(a.labels), flush=True)
    return 0


def main(argv=None):
    a = parser().parse_args(argv)
    try:
        return serve(a)
    except (LabelError, OSError, ValueError, KeyError) as e:
        print('label: ' + (str(e).splitlines() or ['failed'])[0], file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
