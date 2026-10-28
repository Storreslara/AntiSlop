#!/usr/bin/env python3
"""Score a refutation replay (rfp-u2). Usage: score.py <report.jsonl> [--gate] [--labels <labels.tsv>]

A report row is {"id", "answer": REFUTED|CONFIRMED|UNCERTAIN|NONE, "artifact", "num_turns", "cost_usd"}.
A real defect answered REFUTED with a non-empty artifact is a miss: the pass would have dropped a real
defect. Prints one line:
  replay-gate: <pass|fail|insufficient> real=<n> refuted-real=<m> confirmed-real=<c> uncertain-real=<u>
  unanswered=<x> bogus=<b> refuted-bogus=<rb> max-turns=<t> mean-cost-usd=<c>
With --gate: exit 0 on pass, 1 on fail, 2 on insufficient (fewer than MIN_REAL real defects replayed).
pass = real >= MIN_REAL, refuted-real <= MAX_MISSES, unanswered <= 20% of rows, max-turns <= MAX_TURNS.
Without --gate it always exits 0.
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
    real = [r for r in rows if labels.get(r.get('id')) == 'real']
    bogus = [r for r in rows if labels.get(r.get('id')) == 'bogus']
    refuted = lambda r: r.get('answer') == 'REFUTED' and str(r.get('artifact') or '').strip() != ''
    misses = sum(1 for r in real if refuted(r))
    unanswered = sum(1 for r in rows if r.get('answer') not in ('REFUTED', 'CONFIRMED', 'UNCERTAIN'))
    turns = [int(r.get('num_turns') or 0) for r in rows]
    costs = [float(r.get('cost_usd') or 0) for r in rows]
    max_turns = max(turns) if turns else 0
    if len(real) < MIN_REAL:
        verdict, code = 'insufficient', 2
    elif misses <= MAX_MISSES and unanswered <= MAX_UNANSWERED * len(rows) and max_turns <= MAX_TURNS:
        verdict, code = 'pass', 0
    else:
        verdict, code = 'fail', 1
    print('replay-gate: %s real=%d refuted-real=%d confirmed-real=%d uncertain-real=%d unanswered=%d bogus=%d '
          'refuted-bogus=%d max-turns=%d mean-cost-usd=%.3f' % (
              verdict, len(real), misses, sum(1 for r in real if r.get('answer') == 'CONFIRMED'),
              sum(1 for r in real if r.get('answer') == 'UNCERTAIN'), unanswered, len(bogus),
              sum(1 for r in bogus if refuted(r)), max_turns, (sum(costs) / len(costs)) if costs else 0.0))
    return code if gate else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
