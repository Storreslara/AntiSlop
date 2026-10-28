#!/usr/bin/env python3
# Server suite for eval/refutation-replay/label.py; every fixture lives under tempfile.mkdtemp(). `fixture <dir> tall|empty` builds one for the browser probe.
import sys
sys.dont_write_bytecode = True
import hashlib
import http.client
import importlib.util
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RR = os.path.normpath(os.path.join(HERE, '..', 'eval', 'refutation-replay'))
LABEL_PY = os.path.join(RR, 'label.py')
HEADER = '# id<TAB>real|bogus|unknown (Gate G1: a human sets each label)\n'
SCRIPT_RE = re.compile(r'<script id="data" type="application/json">(.*?)</script>', re.S)
TMPS = []

try:
    _spec = importlib.util.spec_from_file_location('label_under_test', LABEL_PY)
    L = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(L)
    LOAD_ERR = None
except Exception as e:
    L, LOAD_ERR = None, e


def mktmp():
    d = tempfile.mkdtemp(prefix='label-suite-')
    TMPS.append(d)
    return d


def git(repo, *args):
    cmd = ['git', '-C', repo, '-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false'] + list(args)
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def build_repo(d):
    repo = os.path.join(d, 'repo')
    os.makedirs(repo)
    git(repo, 'init', '-q')
    write(os.path.join(repo, 'a.txt'), ''.join('line %d\n' % i for i in range(1, 6)))
    write(os.path.join(repo, 'c.txt'), 'old one\nold two\n')
    write(os.path.join(repo, 'big.txt'), 'start\n')
    git(repo, 'add', '.')
    git(repo, 'commit', '-qm', 'base')
    write(os.path.join(repo, 'a.txt'), ''.join('line %d\n' % i for i in range(1, 6)) + 'added\n')
    git(repo, 'mv', 'c.txt', 'd.txt')
    write(os.path.join(repo, 'd.txt'), 'old one\nold two\nnew three\n')
    write(os.path.join(repo, 'big.txt'), 'start\n' + ''.join('more %d\n' % i for i in range(300)))
    git(repo, 'add', '.')
    git(repo, 'commit', '-qm', 'fix: edit a, rename c to d, grow big')
    return repo, git(repo, 'rev-parse', 'HEAD').strip()


def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(text)


def mkrow(fix, group, n, dline):
    return {'id': '%s#D%d' % (group, n), 'unit': group.split('@')[0], 'group': group, 'fail_ts': '2026-01-01T00:00:00Z',
            'baseline': fix, 'reviewed': fix, 'fix_commit': fix, 'dline': dline}


def small_rows(fix):
    specs = [('u1@2026-01-01T00:00:00Z', 1, 'D1: a.txt:2 claim one'),
             ('u1@2026-01-01T00:00:00Z', 2, 'D2: c.txt:1 claim cites the old name'),
             ('u2@2026-01-01T00:00:00Z', 1, 'D1: d.txt:1 claim cites the new name'),
             ('u2@2026-01-01T00:00:00Z', 12, 'D12: a.txt:2 two digit number'),
             ('u3@2026-01-01T00:00:00Z', 1, 'D1: a.txt:1 </script><b>x</b> claim'),
             ('u3@2026-01-01T00:00:00Z', 2, 'D2: zzz.txt:1 claim for an untouched file')]
    return [mkrow(fix, g, n, d) for g, n, d in specs]


def tall_rows(fix):
    return [mkrow(fix, 'g%d@2026-01-01T00:00:00Z' % (n // 8), n % 8 + 1,
                  'D%d: a.txt:2 tall claim %d %s' % (n % 8 + 1, n, 'word ' * (20 + 9 * (n % 5)))) for n in range(24)]


def labels_text(rows, values=None):
    values = values or {}
    return HEADER + ''.join('%s\t%s\n' % (r['id'], values.get(r['id'], 'unknown')) for r in rows)


class Fx:
    # one fixture directory: repo, corpus, labels, and a log outside the labels directory
    def __init__(self, rows_fn=small_rows, values=None, rows=None):
        self.dir = mktmp()
        self.repo, self.fix = build_repo(self.dir)
        self.rows = rows if rows is not None else rows_fn(self.fix)
        self.corpus = os.path.join(self.dir, 'corpus.jsonl')
        self.labels = os.path.join(self.dir, 'labels.tsv')
        self.logdir = mktmp()
        self.log = os.path.join(self.logdir, 'writes.log')
        write(self.corpus, ''.join(json.dumps(r) + '\n' for r in self.rows))
        write(self.labels, labels_text(self.rows, values))
        self.srv = None

    def ids(self):
        return [r['id'] for r in self.rows]

    def start(self):
        self.srv = L.make_server(self.corpus, self.labels, self.repo, self.log, 0)
        threading.Thread(target=self.srv.serve_forever, kwargs={'poll_interval': 0.05}, daemon=True).start()
        self.port, self.token = self.srv.server_address[1], self.srv.token
        return self

    def stop(self):
        if self.srv:
            self.srv.shutdown()
            self.srv.server_close()

    def raw(self):
        with open(self.labels, 'rb') as f:
            return f.read()

    def version(self):
        return hashlib.sha256(self.raw()).hexdigest()

    def snap(self):
        st = os.stat(self.labels)
        return (self.raw(), st.st_ino, st.st_mtime_ns, st.st_mode, sorted(os.listdir(self.dir)))

    def hdrs(self, **over):
        h = {'Host': '127.0.0.1:%d' % self.port, 'Origin': 'http://127.0.0.1:%d' % self.port,
             'X-Label-Token': self.token, 'Content-Type': 'application/json'}
        for k, v in over.items():
            k = k.replace('_', '-')
            if v is None:
                h.pop(k, None)
            else:
                h[k] = v
        return h

    def req(self, method, path, headers=None, body=None, no_cl=False):
        c = http.client.HTTPConnection('127.0.0.1', self.port, timeout=10)
        headers = dict(self.hdrs() if headers is None else headers)
        c.putrequest(method, path, skip_host=True, skip_accept_encoding=True)
        for k, v in headers.items():
            c.putheader(k, v)
        data = body.encode() if isinstance(body, str) else body
        if data is not None and not no_cl:
            c.putheader('Content-Length', str(len(data)))
        c.endheaders(data if not no_cl else None)
        r = c.getresponse()
        out = (r.status, {k.lower(): v for k, v in r.getheaders()}, r.read())
        c.close()
        return out

    def get_page(self, token=True, **over):
        h = {'Host': '127.0.0.1:%d' % self.port}
        h.update({k.replace('_', '-'): v for k, v in over.items()})
        return self.req('GET', '/?t=' + self.token if token else '/', headers=h)

    def post(self, obj, **over):
        body = obj if isinstance(obj, (str, bytes)) else json.dumps(obj)
        return self.req('POST', '/label', headers=self.hdrs(**over), body=body)

    def page_data(self):
        st, _, body = self.get_page()
        assert st == 200, 'page status %d' % st
        return json.loads(SCRIPT_RE.search(body.decode()).group(1))

    def valid(self, i=1, value='real', version=None):
        return {'id': self.ids()[i], 'value': value, 'version': version or self.version()}


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def unchanged(fx, before, what):
    check(fx.snap() == before, '%s changed the labels file' % what)


def s01():
    fx = Fx()
    before = fx.snap()
    fx.start()
    try:
        fx.get_page()
        fx.get_page(token=False)
        for p in ('/nope', '/label', '/x/y'):
            fx.req('GET', p, headers={'Host': '127.0.0.1:%d' % fx.port})
        unchanged(fx, before, 'GET and startup')
        check(not os.path.exists(fx.log), 'log file was created without a POST')
    finally:
        fx.stop()


def s02():
    fx = Fx().start()
    try:
        for tok in (False, True):
            st, _, body = fx.req('GET', '/?t=wrong' if tok else '/', headers={'Host': '127.0.0.1:%d' % fx.port})
            check(st == 403, 'status %d' % st)
            check(fx.token.encode() not in body, '403 body carries the token')
        st, h, body = fx.get_page()
        check(st == 200, 'status %d' % st)
        check(h.get('cache-control') == 'no-store', 'cache-control %r' % h.get('cache-control'))
        check(h.get('x-content-type-options') == 'nosniff', 'nosniff missing')
        csp = h.get('content-security-policy', '')
        check("default-src 'none'" in csp and "frame-ancestors 'none'" in csp, 'csp %r' % csp)
        check(b'data-rows="6"' in body, 'data-rows missing')
        check(json.loads(SCRIPT_RE.search(body.decode()).group(1))['version'] == fx.version(), 'embedded version is not the sha256')
    finally:
        fx.stop()


def s03():
    fx = Fx().start()
    try:
        before = fx.snap()
        for tok in (None, 'wrong'):
            st, _, _ = fx.post(fx.valid(), X_Label_Token=tok)
            check(st == 403, 'token %r gave %d' % (tok, st))
        unchanged(fx, before, 'a token-less POST')
    finally:
        fx.stop()


def s04():
    fx = Fx().start()
    try:
        before = fx.snap()
        hosts = ['evil.example:%d' % fx.port, '127.0.0.1:%d' % (fx.port + 1), None]
        for h in hosts:
            hd = {} if h is None else {'Host': h}
            st, _, _ = fx.req('GET', '/?t=' + fx.token, headers=hd)
            check(st == 403, 'GET host %r gave %d' % (h, st))
            hd = fx.hdrs()
            hd.pop('Host')
            if h:
                hd['Host'] = h
            st, _, _ = fx.req('POST', '/label', headers=hd, body=json.dumps(fx.valid()))
            check(st == 403, 'POST host %r gave %d' % (h, st))
        unchanged(fx, before, 'a foreign Host')
        st, _, _ = fx.get_page(Host='localhost:%d' % fx.port)
        check(st == 200, 'localhost host gave %d' % st)
    finally:
        fx.stop()


def s05():
    fx = Fx().start()
    try:
        before = fx.snap()
        for o in (None, 'null', 'http://evil.example', 'http://127.0.0.1:%d' % (fx.port + 1)):
            st, _, _ = fx.post(fx.valid(), Origin=o)
            check(st == 403, 'origin %r gave %d' % (o, st))
        unchanged(fx, before, 'a foreign Origin')
    finally:
        fx.stop()


def s06():
    fx = Fx().start()
    try:
        before = fx.snap()
        v = fx.version()
        good = fx.valid()
        cases = [('unknown id', dict(good, id='nope#D1')), ('REAL', dict(good, value='REAL')), ('maybe', dict(good, value='maybe')),
                 ('empty value', dict(good, value='')), ('null value', dict(good, value=None)), ('non-JSON', 'not json'),
                 ('array', '[]'), ('missing key', {'id': good['id'], 'value': 'real'}), ('extra key', dict(good, extra=1))]
        for name, body in cases:
            st, _, _ = fx.post(body)
            check(st == 400, '%s gave %d' % (name, st))
        st, _, _ = fx.post(good, Content_Type='text/plain')
        check(st == 400, 'content-type gave %d' % st)
        check(fx.version() == v, 'file changed')
        unchanged(fx, before, 'a bad body')
    finally:
        fx.stop()


def s07():
    fx = Fx().start()
    try:
        before = fx.snap()
        st, _, _ = fx.post('x' * 1100)
        check(st in (411, 413), 'oversize gave %d' % st)
        st, _, _ = fx.req('POST', '/label', headers=fx.hdrs(), body=None, no_cl=True)
        check(st in (411, 413), 'no content-length gave %d' % st)
        unchanged(fx, before, 'an oversize body')
    finally:
        fx.stop()


def ext_edit(fx, i, value):
    lines = fx.raw().decode().split('\n')
    lines[1 + i] = '%s\t%s' % (fx.ids()[i], value)
    tmp = fx.labels + '.ext'
    write(tmp, '\n'.join(lines))
    os.replace(tmp, fx.labels)


def s08():
    fx = Fx().start()
    try:
        before = fx.snap()
        st, _, body = fx.post(fx.valid(version='0' * 64))
        check(st == 409, 'stale gave %d' % st)
        check(json.loads(body)['version'] == fx.version(), '409 lacks the current version')
        unchanged(fx, before, 'a stale POST')
        v0 = fx.page_data()['version']
        ext_edit(fx, 3, 'bogus')
        edited = fx.raw()
        st, _, body = fx.post(fx.valid(version=v0))
        check(st == 409 and json.loads(body)['version'] == fx.version(), 'outside edit gave %d' % st)
        check(fx.raw() == edited, 'the outside edit was overwritten')
    finally:
        fx.stop()


def s09():
    fx = Fx(values={'u1@2026-01-01T00:00:00Z#D1': 'bogus'}).start()
    try:
        old, ino, mode = fx.raw(), os.stat(fx.labels).st_ino, os.stat(fx.labels).st_mode
        before_dir = sorted(os.listdir(fx.dir))
        st, _, body = fx.post(fx.valid(2, 'real'))
        check(st == 200, 'status %d' % st)
        new = fx.raw()
        check(json.loads(body)['version'] == hashlib.sha256(new).hexdigest(), 'version is not the new sha256')
        ol, nl = old.split(b'\n'), new.split(b'\n')
        diff = [i for i in range(len(ol)) if ol[i] != nl[i]]
        check(len(ol) == len(nl) and diff == [3], 'differing lines %r' % diff)
        check(nl[3] == (fx.ids()[2] + '\treal').encode(), 'line is %r' % nl[3])
        check(ol[0] == nl[0], 'header changed')
        st = os.stat(fx.labels)
        check(st.st_mode == mode, 'mode changed')
        check(st.st_ino != ino, 'inode unchanged: written in place')
        check(sorted(os.listdir(fx.dir)) == before_dir, 'a temp file remains: %r' % os.listdir(fx.dir))
        ino2, mt = st.st_ino, st.st_mtime_ns
        st2, _, body = fx.post(fx.valid(2, 'real'))
        s = os.stat(fx.labels)
        check(st2 == 200 and s.st_ino == ino2 and s.st_mtime_ns == mt and fx.raw() == new, 'a repeated value rewrote the file')
        check(json.loads(body)['version'] == fx.version(), 'repeat version wrong')
    finally:
        fx.stop()


def s10():
    fx = Fx(tall_rows).start()
    results, bad, done = {}, [], threading.Event()
    ids = fx.ids()[:20]

    def reader():
        while not done.is_set():
            lines = fx.raw().decode().split('\n')
            ok = lines[0].startswith('#') and lines[-1] == '' and len(lines) == len(fx.rows) + 2
            ok = ok and all(l.split('\t')[0] == i and l.split('\t')[1] in ('real', 'bogus', 'unknown') for l, i in zip(lines[1:-1], fx.ids()))
            if not ok:
                bad.append(lines)

    def worker(i, v0, barrier):
        barrier.wait()
        st, _, body = fx.post({'id': ids[i], 'value': 'real', 'version': v0})
        first, ver = st, json.loads(body).get('version')
        while st != 200:
            st, _, body = fx.post({'id': ids[i], 'value': 'real', 'version': ver})
            ver = json.loads(body).get('version')
        results[i] = first

    try:
        v0 = fx.version()
        barrier = threading.Barrier(20)
        ts = [threading.Thread(target=worker, args=(i, v0, barrier)) for i in range(20)]
        rt = threading.Thread(target=reader)
        rt.start()
        for t in ts:
            t.start()
        for t in ts:
            t.join(60)
        done.set()
        rt.join()
        firsts = sorted(results.values())
        check(firsts == [200] + [409] * 19, 'first statuses %r' % firsts)
        check(not bad, 'a read saw an incomplete labels file')
        lab = dict(l.split('\t') for l in fx.raw().decode().split('\n')[1:-1])
        check(all(lab[i] == 'real' for i in ids) and all(lab[i] == 'unknown' for i in fx.ids()[20:]), 'final file wrong')
    finally:
        done.set()
        fx.stop()


def s11():
    fx = Fx().start()
    try:
        seen = []
        for m in ('PUT', 'DELETE', 'PATCH', 'OPTIONS'):
            for p in ('/', '/label'):
                st, h, _ = fx.req(m, p, headers=fx.hdrs(), body='{}' if m != 'OPTIONS' else None)
                seen.append(h)
                check(st == 405, '%s %s gave %d' % (m, p, st))
        hh = {'Host': '127.0.0.1:%d' % fx.port}
        for p in ('/label', '/labels.tsv', '/corpus.jsonl', '/../labels.tsv', '/label.py'):
            st, h, _ = fx.req('GET', p + ('?t=' + fx.token), headers=hh)
            seen.append(h)
            check(st in (404, 405), 'GET %s gave %d' % (p, st))
        st, h, _ = fx.req('POST', '/', headers=fx.hdrs(), body='{}')
        seen.append(h)
        check(st in (404, 405), 'POST / gave %d' % st)
        seen.append(fx.get_page()[1])
        check(not any(k.startswith('access-control-') for h in seen for k in h), 'an Access-Control header was sent')
    finally:
        fx.stop()


def s12():
    fx = Fx().start()
    try:
        check(os.path.dirname(fx.log) != fx.dir, 'log is in the labels directory')
        fx.post(fx.valid(), X_Label_Token='wrong')
        fx.post(fx.valid(1, 'real'))
        with open(fx.log) as f:
            text = f.read()
        recs = [json.loads(l) for l in text.splitlines()]
        check(len(recs) == 2, '%d log lines' % len(recs))
        keys = {'ts', 'status', 'id', 'old', 'new', 'version_before', 'version_after', 'remote', 'origin', 'user_agent'}
        check(all(set(r) == keys for r in recs), 'log keys %r' % [sorted(r) for r in recs])
        check(recs[0]['status'] == 403 and recs[1]['status'] == 200, 'statuses %r' % [r['status'] for r in recs])
        r = recs[1]
        check(r['id'] == fx.ids()[1] and r['old'] == 'unknown' and r['new'] == 'real', 'accepted line %r' % r)
        check(r['version_before'] != r['version_after'] and r['version_after'] == fx.version(), 'versions %r' % r)
        check(r['remote'] == '127.0.0.1' and r['origin'] == 'http://127.0.0.1:%d' % fx.port, 'remote/origin %r' % r)
        check(fx.token not in text, 'token in the log')
    finally:
        fx.stop()


def cli(fx, *extra, labels=None, corpus=None, repo=None):
    cmd = [sys.executable, LABEL_PY, 'serve', '--no-open', '--corpus', corpus or fx.corpus, '--labels', labels or fx.labels,
           '--repo', repo or fx.repo, '--log', fx.log] + list(extra)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=30)


def s13():
    variants = {
        'no header': lambda t: t.split('\n', 1)[1],
        'CRLF': lambda t: t.replace('\n', '\r\n'),
        'bad value': lambda t: t.replace('\tunknown', '\tmaybe', 1),
        'repeated id': lambda t: t + t.split('\n')[1] + '\n',
        'missing id': lambda t: t.replace(t.split('\n')[2] + '\n', ''),
        'other order': lambda t: '\n'.join([t.split('\n')[0], t.split('\n')[2], t.split('\n')[1]] + t.split('\n')[3:]),
    }
    for name, fn in variants.items():
        fx = Fx()
        write(fx.labels, fn(labels_text(fx.rows)))
        before = fx.snap()
        p = cli(fx, '--port', '0')
        out = (p.stdout + p.stderr).strip()
        check(p.returncode == 2, '%s: exit %d: %s' % (name, p.returncode, out[:100]))
        check(len(out.splitlines()) == 1, '%s: reason is not one line: %r' % (name, out[:200]))
        unchanged(fx, before, name)
        check(not os.path.exists(fx.log), '%s: log created' % name)
    fx = Fx()
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    s.listen(1)
    try:
        before = fx.snap()
        p = cli(fx, '--port', str(s.getsockname()[1]))
        check(p.returncode == 2, 'bound port: exit %d' % p.returncode)
        check(len((p.stdout + p.stderr).strip().splitlines()) == 1, 'bound port: reason is not one line')
        unchanged(fx, before, 'a bound port')
    finally:
        s.close()


def listening(port):
    with open('/proc/net/tcp') as f:
        return [l.split()[1] for l in f.readlines()[1:] if l.split()[3] == '0A' and int(l.split()[1].split(':')[1], 16) == port]


def closed(port):
    s = socket.socket()
    s.settimeout(2)
    try:
        return s.connect_ex(('127.0.0.1', port)) != 0
    finally:
        s.close()


def launch(fx, env=None, no_open=True):
    cmd = [sys.executable, LABEL_PY, 'serve', '--port', '0', '--corpus', fx.corpus, '--labels', fx.labels,
           '--repo', fx.repo, '--log', fx.log] + (['--no-open'] if no_open else [])
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
    line = p.stdout.readline().strip()
    return p, line


def s14():
    fx = Fx()
    pat = re.compile(r'^label: http://127\.0\.0\.1:([0-9]+)/\?t=([A-Za-z0-9_-]{32,})$')
    for sig in (signal.SIGTERM, signal.SIGINT):
        p, line = launch(fx)
        try:
            m = pat.match(line)
            check(m, 'url line %r' % line)
            port = int(m.group(1))
            check(listening(port) == ['0100007F:%04X' % port], 'listening on %r' % listening(port))
            c = http.client.HTTPConnection('127.0.0.1', port, timeout=10)
            c.request('GET', '/?t=' + m.group(2))
            check(c.getresponse().status == 200, 'GET not 200')
            p.send_signal(sig)
            check(p.wait(5) == 0, 'exit %r on %s' % (p.returncode, sig.name))
            check(closed(port), 'port still open after %s' % sig.name)
        finally:
            if p.poll() is None:
                p.kill()
    fake, rec = mktmp(), os.path.join(mktmp(), 'rec')
    for n in ('wslview', 'xdg-open'):
        write(os.path.join(fake, n), '#!/bin/sh\necho "%s $@" >> %s\nexit 1\n' % (n, rec))
        os.chmod(os.path.join(fake, n), 0o755)
    env = dict(os.environ, PATH=fake + ':/usr/bin:/bin')
    p, line = launch(fx, env=env, no_open=False)
    try:
        m = pat.match(line)
        check(m, 'url line without --no-open %r' % line)
        c = http.client.HTTPConnection('127.0.0.1', int(m.group(1)), timeout=10)
        c.request('GET', '/?t=' + m.group(2))
        check(c.getresponse().status == 200, 'did not serve after a failed opener')
        for _ in range(30):
            if os.path.exists(rec) and line.split(' ', 1)[1] in open(rec).read():
                break
            time.sleep(0.1)
        check(os.path.exists(rec) and line.split(' ', 1)[1] in open(rec).read(), 'no fake opener got the URL')
        p.send_signal(signal.SIGTERM)
        p.wait(5)
    finally:
        if p.poll() is None:
            p.kill()


def s15():
    fx = Fx().start()
    try:
        check(L.cited('D12: a.txt:2 x') == ('a.txt', 2), 'cited %r' % (L.cited('D12: a.txt:2 x'),))
        hints = {r['id']: L.evidence(fx.repo, r)['hint'] for r in fx.rows}
        want = ['touches', 'touches', 'touches', 'touches', 'touches', 'untouched']
        check([hints[i] for i in fx.ids()] == want, 'hints %r' % hints)
        big = L.evidence(fx.repo, mkrow(fx.fix, 'u@t', 1, 'D1: big.txt:1 grown file'))
        check(len(big['diff'].splitlines()) == 200 and big['diff_truncated'] is True, 'diff cut %d %r' % (len(big['diff'].splitlines()), big['diff_truncated']))
        small = L.evidence(fx.repo, fx.rows[0])
        check(small['diff_truncated'] is False and small['diff'], 'short diff flagged or empty')
        gone = L.evidence(fx.repo, mkrow('0' * 40, 'u@t', 1, 'D1: a.txt:1 gone'))
        check(gone['hint'] == 'unknown', 'unreachable gave %r' % gone['hint'])
        st, _, body = fx.get_page()
        page = body.decode()
        with open(os.path.join(RR, 'label_page.html'), encoding='utf-8') as f:
            tpl = f.read()
        check(page.count('</script>') == tpl.count('</script>'), '%d closers, template has %d' % (page.count('</script>'), tpl.count('</script>')))
        check('</script><b>' not in page and '\\u003c/script\\u003e\\u003cb\\u003ex\\u003c/b\\u003e' in page, 'claim not escaped')
        check('not a label' in page, 'hint wording missing')
        d = fx.page_data()
        if os.path.exists(os.path.join(RR, 'score.py')):  # a stripped copy has no score.py: the targets are then null
            score = importlib.util.spec_from_file_location('score_ref', os.path.join(RR, 'score.py'))
            sm = importlib.util.module_from_spec(score)
            score.loader.exec_module(sm)
            check(d['min_real'] == sm.MIN_REAL and d['max_bogus'] == len(fx.rows) - sm.MIN_REAL, 'thresholds %r %r' % (d['min_real'], d['max_bogus']))
        else:
            check(d['min_real'] is None and d['max_bogus'] is None, 'targets without score.py: %r' % ((d['min_real'], d['max_bogus']),))
    finally:
        fx.stop()


def s16():
    fx = Fx(rows=[])
    fx.start()
    try:
        st, _, body = fx.get_page()
        check(st == 200 and b'data-rows="0"' in body, 'empty page status %d' % st)
        st, _, _ = fx.post({'id': 'a#D1', 'value': 'real', 'version': fx.version()})
        check(st == 400, 'empty corpus POST gave %d' % st)
        check(fx.raw().decode() == HEADER, 'file changed')
    finally:
        fx.stop()


CASES = [('S01', 'starting and every GET write nothing', s01), ('S02', 'GET needs the token, page headers and version', s02),
         ('S03', 'POST needs the token header', s03), ('S04', 'foreign or missing Host refused on GET and POST', s04),
         ('S05', 'missing or foreign Origin refused', s05), ('S06', 'malformed POST bodies get 400', s06),
         ('S07', 'oversize or length-less body refused', s07), ('S08', 'stale version gets 409', s08),
         ('S09', 'a valid POST changes one line atomically', s09), ('S10', '20 concurrent writers serialize', s10),
         ('S11', 'only GET / and POST /label exist, no CORS', s11), ('S12', 'every POST is logged without the token', s12),
         ('S13', 'startup refuses a bad labels file or bound port', s13), ('S14', 'CLI url line, opener failure, signals', s14),
         ('S15', 'evidence, escaping, hint wording, thresholds', s15), ('S16', 'empty corpus serves and refuses writes', s16)]


def main():
    fails = 0
    for cid, text, fn in CASES:
        try:
            if LOAD_ERR:
                raise RuntimeError('label.py not loadable: %s' % LOAD_ERR)
            fn()
            print('ok - %s %s' % (cid, text))
        except Exception as e:
            fails += 1
            print('FAIL - %s %s: %s' % (cid, text, (str(e) or repr(e)).splitlines()[0][:300]))
        sys.stdout.flush()
    for d in TMPS:
        shutil.rmtree(d, ignore_errors=True)
    return 1 if fails else 0


def fixture(d, kind):
    repo, fix = build_repo(d)
    rows = tall_rows(fix) if kind == 'tall' else []
    write(os.path.join(d, 'corpus.jsonl'), ''.join(json.dumps(r) + '\n' for r in rows))
    write(os.path.join(d, 'labels.tsv'), labels_text(rows))


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == 'fixture':
        fixture(sys.argv[2], sys.argv[3])
        sys.exit(0)
    sys.exit(main())
