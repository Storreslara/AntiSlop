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
DAYS = ARGS.days
SINCE = iso_epoch(ARGS.since) if ARGS.since else None
UNTIL = iso_epoch(ARGS.until) if ARGS.until else None
cut = time.time() - DAYS * 86400
files = [f for f in glob.glob(root + '/*/subagents/*.jsonl') if os.path.getmtime(f) > cut]

# parent map: agentId -> subagent_type (search parent jsonl for tool_use with subagent_type and following agentId mention)
parent_types = {}
for pf in glob.glob(root + '/*.jsonl'):
    if os.path.getmtime(pf) < cut: continue
    try:
        with open(pf) as fh:
            for ln in fh:
                if 'subagent_type' not in ln and 'agentId' not in ln: continue
                try: r = json.loads(ln)
                except Exception: continue
                m = r.get('message') or {}
                c = m.get('content')
                if isinstance(c, list):
                    for b in c:
                        if isinstance(b, dict) and b.get('type') == 'tool_use' and b.get('name') == 'Agent':
                            inp = b.get('input') or {}
                            parent_types[b.get('id')] = inp.get('subagent_type', '?')
                        if isinstance(b, dict) and b.get('type') == 'tool_result':
                            txt = json.dumps(b.get('content'))[:3000]
                            mm = re.search(r'agentId["\s:]+([0-9a-f]{12,20})', txt)
                            if mm and b.get('tool_use_id') in parent_types:
                                parent_types[mm.group(1)] = parent_types[b['tool_use_id']]
                tr = r.get('toolUseResult')
                if isinstance(tr, dict) and tr.get('agentId'):
                    pass
    except Exception:
        pass

SKILL_SIG = {
    frozenset(['antislop:roast-work', 'antislop:ubiquitous-language']): 'reviewer',
    frozenset(['antislop:coding-discipline', 'antislop:tdd']): 'lead-programmer',
    frozenset(['antislop:grilling', 'antislop:domain-modeling', 'antislop:ubiquitous-language']): 'spec-master',
    frozenset(['antislop:pathfinder']): 'task-master',
    frozenset(['antislop:domain-modeling']): 'scribe',
    frozenset(['antislop:grilling', 'antislop:ubiquitous-language']): 'milestone-auditor',
}

def classify(recs, agent_id):
    skills = set()
    for r in recs[:12]:
        if r.get('type') != 'user': continue
        c = (r.get('message') or {}).get('content')
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'text':
                    mm = re.search(r'<command-name>([^<]+)</command-name>', b.get('text', ''))
                    if mm: skills.add(mm.group(1))
    if frozenset(skills) in SKILL_SIG: return SKILL_SIG[frozenset(skills)]
    if agent_id in parent_types: return parent_types[agent_id]
    first = recs[0].get('message', {}).get('content') if recs else ''
    if isinstance(first, str) and first.startswith('Unit:') and 'Implementer tier' in first: return 'reviewer?'
    return 'other/' + ','.join(sorted(skills)) if skills else 'other'

agg = {}
for f in files:
    try:
        recs = [json.loads(l) for l in open(f) if l.strip()]
    except Exception:
        continue
    if not recs: continue
    if not in_range(recs, SINCE, UNTIL): continue
    aid = recs[0].get('agentId', '?')
    persona = classify(recs, aid)
    first_ctx = None; total_in = 0; turns = 0; out = 0; models = set()
    tool_bytes = {}; last_tool = None; reads = 0; bash = 0
    for r in recs:
        m = r.get('message') or {}
        if r.get('type') == 'assistant':
            u = m.get('usage')
            if u:
                turns += 1
                ctx = u.get('input_tokens', 0) + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0)
                if first_ctx is None: first_ctx = ctx
                total_in += ctx
                out += u.get('output_tokens', 0)
                models.add(m.get('model', '?'))
            c = m.get('content')
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get('type') == 'tool_use':
                        last_tool = b.get('name')
                        if last_tool == 'Read': reads += 1
                        if last_tool == 'Bash': bash += 1
        elif r.get('type') == 'user':
            c = m.get('content')
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get('type') == 'tool_result':
                        n = len(json.dumps(b.get('content')))
                        tool_bytes[last_tool] = tool_bytes.get(last_tool, 0) + n
    if turns == 0: continue
    d = agg.setdefault(persona, [])
    d.append(dict(first=first_ctx, total=total_in, turns=turns, out=out, models=models, tb=tool_bytes, reads=reads, bash=bash, f=os.path.basename(f)))

def med(xs): return int(st.median(xs)) if xs else 0
def p90(xs): xs = sorted(xs); return xs[int(len(xs) * 0.9) - 1] if len(xs) >= 2 else (xs[0] if xs else 0)
print(f'window: last {DAYS} days'+(f', since {ARGS.since}' if ARGS.since else '')+(f', until {ARGS.until}' if ARGS.until else '')+f', subagent transcripts with usage: {sum(len(v) for v in agg.values())}')
print(f"{'persona':22} {'n':>4} {'1st-ctx med':>11} {'total-in med':>12} {'total-in p90':>12} {'turns med':>9} {'out med':>8} {'Read':>5} {'Bash':>5} models")
for p, rows in sorted(agg.items(), key=lambda kv: -sum(r['total'] for r in kv[1])):
    ms = set().union(*[r['models'] for r in rows])
    print(f"{p:22} {len(rows):4} {med([r['first'] for r in rows]):11,} {med([r['total'] for r in rows]):12,} {p90([r['total'] for r in rows]):12,} {med([r['turns'] for r in rows]):9} {med([r['out'] for r in rows]):8,} {med([r['reads'] for r in rows]):5} {med([r['bash'] for r in rows]):5} {','.join(sorted(m.replace('claude-','') for m in ms))}")
print()
print('tool_result bytes per dispatch (median) by tool, per persona:')
for p, rows in agg.items():
    if len(rows) < 3: continue
    tools = {}
    for r in rows:
        for t, n in r['tb'].items(): tools.setdefault(t, []).append(n)
    line = ', '.join(f"{t}={med(v):,}" for t, v in sorted(tools.items(), key=lambda kv: -sum(kv[1]))[:5])
    print(f'  {p:22} {line}')
print()
print('share of cumulative input tokens by persona (window):')
tot = sum(r['total'] for rows in agg.values() for r in rows)
for p, rows in sorted(agg.items(), key=lambda kv: -sum(r['total'] for r in kv[1])):
    s = sum(r['total'] for r in rows)
    print(f'  {p:22} {s/1e6:8.1f}M  {100*s/tot:5.1f}%')
