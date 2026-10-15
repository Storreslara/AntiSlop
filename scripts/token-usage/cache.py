import argparse, datetime, json, os, glob, re, statistics as st, time, sys


_DATETIME = datetime.datetime
_UTC = datetime.timezone.utc


def parse_args():
    ap = argparse.ArgumentParser(description='Per-persona token usage over subagent transcripts.')
    ap.add_argument('days', nargs='?', type=int, default=21, help='window in days, by file mtime (default 21)')
    ap.add_argument('--root', default=os.path.join('~', '.claude', 'projects', '-home-sebas-AntiSlop'),
                    help='transcript directory (default: ~/.claude/projects/-home-sebas-AntiSlop, expanded at run time)')
    ap.add_argument('--since', help='keep dispatches whose first message is at or after this ISO-8601 time')
    ap.add_argument('--until', help='keep dispatches whose first message is before this ISO-8601 time')
    return ap.parse_args()


def iso_epoch(s):
    d = _DATETIME.fromisoformat(s.replace('Z', '+00:00'))
    if d.tzinfo is None:
        d = d.replace(tzinfo=_UTC)
    return d.timestamp()


def in_range(recs, since, until):
    """True when the dispatch's first-message timestamp is inside [since, until)."""
    if since is None and until is None:
        return True
    t = recs[0].get('timestamp') if recs else None
    if not t:
        return False
    e = iso_epoch(t)
    return (since is None or e >= since) and (until is None or e < until)


ARGS = parse_args()
root = os.path.expanduser(ARGS.root)
SINCE = iso_epoch(ARGS.since) if ARGS.since else None
UNTIL = iso_epoch(ARGS.until) if ARGS.until else None
cut = time.time() - ARGS.days * 86400
SIG = {frozenset(['antislop:roast-work', 'antislop:ubiquitous-language']): 'reviewer',
       frozenset(['antislop:coding-discipline', 'antislop:tdd']): 'lead-programmer',
       frozenset(['antislop:grilling', 'antislop:domain-modeling', 'antislop:ubiquitous-language']): 'spec-master',
       frozenset(['antislop:pathfinder']): 'task-master', frozenset(['antislop:domain-modeling']): 'scribe'}
agg = {}
for f in glob.glob(root + '/*/subagents/*.jsonl'):
    if os.path.getmtime(f) < cut: continue
    recs = [json.loads(l) for l in open(f) if l.strip()]
    if not recs or not in_range(recs, SINCE, UNTIL): continue
    skills = set()
    for r in recs[:12]:
        c = (r.get('message') or {}).get('content')
        if r.get('type') == 'user' and isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'text':
                    m = re.search(r'<command-name>([^<]+)</command-name>', b.get('text', ''))
                    if m: skills.add(m.group(1))
    p = SIG.get(frozenset(skills), 'other')
    d = agg.setdefault(p, dict(cr=0, cw=0, inp=0, gaps=[], n=0))
    d['n'] += 1
    last_t = None
    for r in recs:
        if r.get('type') != 'assistant': continue
        u = (r.get('message') or {}).get('usage')
        if not u: continue
        d['cr'] += u.get('cache_read_input_tokens', 0); d['cw'] += u.get('cache_creation_input_tokens', 0); d['inp'] += u.get('input_tokens', 0)
        ts = r.get('timestamp')
        if ts and last_t:
            try:
                from datetime import datetime
                g = (datetime.fromisoformat(ts.replace('Z', '+00:00')) - datetime.fromisoformat(last_t.replace('Z', '+00:00'))).total_seconds()
                d['gaps'].append(g)
            except Exception: pass
        last_t = ts
for p, d in sorted(agg.items(), key=lambda kv: -kv[1]['cr']):
    tot = d['cr'] + d['cw'] + d['inp']
    gaps = d['gaps']
    print(f"{p:16} n={d['n']:4} cache_read={100*d['cr']/tot:5.1f}%  cache_write={100*d['cw']/tot:5.1f}%  uncached={100*d['inp']/tot:5.1f}%  gaps>5min={100*sum(1 for g in gaps if g>300)/max(1,len(gaps)):4.1f}% of {len(gaps)} turn gaps")
