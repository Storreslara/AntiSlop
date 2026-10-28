#!/usr/bin/env python3
"""Score a refutation replay (rfp-u2; per-id scoring rfp-u2b). Usage: score.py <report.jsonl> [--gate] [--labels <labels.tsv>]

A report row is {"id", "answer": REFUTED|CONFIRMED|UNCERTAIN|NONE, "artifact", "num_turns", "cost_usd"}.
Scoring is per distinct id, never per row:
- a row whose id is not in labels.tsv is `foreign` and ignored;
- repeated rows for one id count once; if they differ in answer or artifact, the id is a `dup-conflict`;
- every id labelled real or bogus must have a row, or it is `missing`.
A real defect answered REFUTED with a non-empty artifact is a miss: the pass would have dropped a real
defect. Prints one line:
  replay-gate: <pass|fail|insufficient> real=<n> refuted-real=<m> confirmed-real=<c> uncertain-real=<u>
  unanswered=<x> bogus=<b> refuted-bogus=<rb> max-turns=<t> mean-cost-usd=<c> missing=<k>
  dup-conflict=<d> foreign=<f>
With --gate: exit 0 on pass, 1 on fail, 2 on insufficient.
insufficient = fewer than MIN_REAL distinct real ids, or missing > 0.
pass = not insufficient, refuted-real <= MAX_MISSES, unanswered <= 20% of the scored ids,
max-turns <= MAX_TURNS and dup-conflict = 0. Anything else is fail. Without --gate it always exits 0.
"""
import json, os, sys

MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20


def main(argv):
    gate = '--gate' in argv
    args = [x for x in argv if x != '--gate']
    labels_file = None
    if '--labels' in args:
        i = args.index('--labels')
        labels_file = args[i + 1]
        del args[i:i + 2]
    report = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'report.jsonl')
    labels_file = labels_file or os.path.join(os.path.dirname(os.path.abspath(report)), 'labels.tsv')
    labels = {}
    if os.path.exists(labels_file):
        for l in open(labels_file):
            if l.strip() and not l.startswith('#'):
                k, _, v = l.rstrip('\n').partition('\t')
                labels[k] = v
    rows = [json.loads(l) for l in open(report) if l.strip()] if os.path.exists(report) else []
    first, conflict, foreign, turns = {}, set(), set(), []
    for r in rows:
        rid = str(r.get('id'))
        if rid not in labels:
            foreign.add(rid)
            continue
        turns.append(int(r.get('num_turns') or 0))
        if rid not in first:
            first[rid] = r
        elif (first[rid].get('answer'), first[rid].get('artifact')) != (r.get('answer'), r.get('artifact')):
            conflict.add(rid)
    scored = list(first.values())
    real = [r for r in scored if labels[str(r.get('id'))] == 'real']
    bogus = [r for r in scored if labels[str(r.get('id'))] == 'bogus']
    missing = sum(1 for k, v in labels.items() if v in ('real', 'bogus') and k not in first)
    refuted = lambda r: r.get('answer') == 'REFUTED' and str(r.get('artifact') or '').strip() != ''
    misses = sum(1 for r in real if refuted(r))
    unanswered = sum(1 for r in scored if r.get('answer') not in ('REFUTED', 'CONFIRMED', 'UNCERTAIN'))
    costs = [float(r.get('cost_usd') or 0) for r in scored]
    max_turns = max(turns) if turns else 0
    if len(real) < MIN_REAL or missing:
        verdict, code = 'insufficient', 2
    elif (misses <= MAX_MISSES and unanswered <= MAX_UNANSWERED * len(scored) and max_turns <= MAX_TURNS
          and not conflict):
        verdict, code = 'pass', 0
    else:
        verdict, code = 'fail', 1
    print('replay-gate: %s real=%d refuted-real=%d confirmed-real=%d uncertain-real=%d unanswered=%d bogus=%d '
          'refuted-bogus=%d max-turns=%d mean-cost-usd=%.3f missing=%d dup-conflict=%d foreign=%d' % (
              verdict, len(real), misses, sum(1 for r in real if r.get('answer') == 'CONFIRMED'),
              sum(1 for r in real if r.get('answer') == 'UNCERTAIN'), unanswered, len(bogus),
              sum(1 for r in bogus if refuted(r)), max_turns, (sum(costs) / len(costs)) if costs else 0.0,
              missing, len(conflict), len(foreign)))
    return code if gate else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
