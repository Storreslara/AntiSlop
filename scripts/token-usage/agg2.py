import argparse, datetime, json, os, glob, re, statistics as st, time, sys
from collections import Counter


_DATETIME = datetime.datetime
_UTC = datetime.timezone.utc


def parse_args():
    ap = argparse.ArgumentParser(description='Per-persona token usage over subagent transcripts.')
    ap.add_argument('days', nargs='?', type=int, default=21, help='window in days, by file mtime (default 21)')
    ap.add_argument('--root', default=os.path.join('~', '.claude', 'projects', '-home-sebas-AntiSlop'),
                    help='transcript directory (default: ~/.claude/projects/-home-sebas-AntiSlop, expanded at run time)')
    ap.add_argument('--since', help='keep dispatches whose first message is at or after this ISO-8601 time')
    ap.add_argument('--until', help='keep dispatches whose first message is before this ISO-8601 time')
    ap.add_argument('--repo', default=os.getcwd(), help='repository checkout used to size the top Read paths (default: current directory)')
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
REPO = os.path.abspath(ARGS.repo)
DAYS = ARGS.days
SINCE = iso_epoch(ARGS.since) if ARGS.since else None
UNTIL = iso_epoch(ARGS.until) if ARGS.until else None
cut = time.time() - DAYS * 86400
files = [f for f in glob.glob(root + '/*/subagents/*.jsonl') if os.path.getmtime(f) > cut]
SKILL_SIG = {
    frozenset(['antislop:roast-work', 'antislop:ubiquitous-language']): 'reviewer',
    frozenset(['antislop:coding-discipline', 'antislop:tdd']): 'lead-programmer',
    frozenset(['antislop:grilling', 'antislop:domain-modeling', 'antislop:ubiquitous-language']): 'spec-master',
    frozenset(['antislop:pathfinder']): 'task-master',
    frozenset(['antislop:domain-modeling']): 'scribe',
}
def classify(recs):
    skills = set()
    for r in recs[:12]:
        if r.get('type') != 'user': continue
        c = (r.get('message') or {}).get('content')
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'text':
                    mm = re.search(r'<command-name>([^<]+)</command-name>', b.get('text', ''))
                    if mm: skills.add(mm.group(1))
    return SKILL_SIG.get(frozenset(skills), 'other')
def med(xs): return int(st.median(xs)) if xs else 0
stats = {}
for f in files:
    try: recs = [json.loads(l) for l in open(f) if l.strip()]
    except Exception: continue
    if not recs: continue
    if not in_range(recs, SINCE, UNTIL): continue
    p = classify(recs)
    if p == 'other': continue
    s = stats.setdefault(p, dict(prompt=[], blocked=[], validate=[], bigread=[], paths=Counter(), ctxmax=[], growth=[], bashtimeouts=[], n=0))
    s['n'] += 1
    first = recs[0].get('message', {}).get('content')
    if isinstance(first, list): first = ' '.join(b.get('text', '') for b in first if isinstance(b, dict))
    s['prompt'].append(len(first or ''))
    blocked = 0; validate = 0; bigread = 0; ctxs = []; timeouts = 0
    last_tool = None; last_input = {}
    for r in recs:
        m = r.get('message') or {}
        c = m.get('content')
        if r.get('type') == 'assistant':
            u = m.get('usage')
            if u: ctxs.append(u.get('input_tokens', 0) + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0))
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get('type') == 'tool_use':
                        last_tool = b.get('name'); last_input = b.get('input') or {}
                        if last_tool == 'Bash' and 'validate.sh' in str(last_input.get('command', '')): validate += 1
                        if last_tool == 'Read':
                            fp = str(last_input.get('file_path', '')).replace(REPO + os.sep, '')
                            s['paths'][fp] += 1
        elif r.get('type') == 'user' and isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'tool_result':
                    txt = json.dumps(b.get('content'))
                    if 'BLOCKED:' in txt[:400] or 'hook error' in txt[:200]: blocked += 1
                    if 'timed out' in txt[:300].lower(): timeouts += 1
                    if last_tool == 'Read' and len(txt) > 20000: bigread += 1
    s['blocked'].append(blocked); s['validate'].append(validate); s['bigread'].append(bigread); s['bashtimeouts'].append(timeouts)
    if ctxs:
        s['ctxmax'].append(max(ctxs)); s['growth'].append(max(ctxs) - ctxs[0])
print(f"{'persona':16} {'n':>4} {'prompt B med':>12} {'prompt B p90':>12} {'gate blocks med/mean':>20} {'validate runs mean':>18} {'bash timeouts mean':>18} {'reads>20KB mean':>15} {'ctx max med':>11} {'growth med':>10}")
for p, s in stats.items():
    pr = sorted(s['prompt'])
    print(f"{p:16} {s['n']:4} {med(pr):12,} {pr[int(len(pr)*0.9)-1]:12,} {med(s['blocked']):>8}/{st.mean(s['blocked']):<11.2f} {st.mean(s['validate']):18.2f} {st.mean(s['bashtimeouts']):18.2f} {st.mean(s['bigread']):15.2f} {med(s['ctxmax']):11,} {med(s['growth']):10,}")
print()
for p, s in stats.items():
    print(f"top Read paths for {p} (count over {s['n']} dispatches):")
    for path, n in s['paths'].most_common(8):
        sz = os.path.getsize(os.path.join(REPO, path)) if os.path.exists(os.path.join(REPO, path)) else -1
        print(f"   {n:4}  {sz:8,}B  {path[:90]}")
# main sessions (orchestrator)
print()
print('main-session (orchestrator) transcripts, window:')
rows = []
for pf in glob.glob(root + '/*.jsonl'):
    if os.path.getmtime(pf) < cut: continue
    ctxs = []; n = 0
    for ln in open(pf):
        if '"usage"' not in ln: continue
        try: r = json.loads(ln)
        except Exception: continue
        if r.get('type') != 'assistant': continue
        u = (r.get('message') or {}).get('usage') or {}
        ctxs.append(u.get('input_tokens', 0) + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0))
    if ctxs: rows.append((ctxs[0], med(ctxs), max(ctxs), len(ctxs), sum(ctxs)))
rows.sort(key=lambda r: -r[4])
if not rows:
    print('  sessions=0')
    sys.exit(0)
print(f"  sessions={len(rows)}  first-ctx med={med([r[0] for r in rows]):,}  per-msg ctx med={med([r[1] for r in rows]):,}  max-ctx med={med([r[2] for r in rows]):,}  msgs med={med([r[3] for r in rows])}  cumulative-in med={med([r[4] for r in rows]):,}  top session cumulative={rows[0][4]:,} over {rows[0][3]} msgs")
