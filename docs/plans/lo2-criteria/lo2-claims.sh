#!/usr/bin/env bash
# Usage: lo2-claims.sh <lo2-1|lo2-5>
# Claim-anchored checks for the prose parts of the skills-audit leftovers-2 slice
# (docs/plans/2026-10-14-skills-audit-leftovers-2.md). Each check counts a phrase
# in a file whose whitespace runs are collapsed to one space first, so a phrase
# split by the hard wrap is still found. A check is: file, phrase, wanted count.
# Exit 0 iff every check of the named unit holds. Every check is red at da1b2da.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
[ "$#" -eq 1 ] || { echo "usage: $0 <lo2-1|lo2-5>" >&2; exit 2; }
python3 -I - "$1" <<'PY'
import re, sys
unit = sys.argv[1]
C = 'CONTEXT.md'
G = 'docs/harness-glossary.md'
LP = 'agents/lead-programmer.md'
OR = 'agents/orchestrator.md'
TM = 'agents/task-master.md'
PP = 'templates/persona-protocol.md'
checks = {
 'lo2-1': [
  (C, '**surviving mutant**:', 1),
  (C, 'or an [[equivalent mutant]], when no input can', 1),
  (C, '**spec publication**:', 1),
  (C, 'Required at or above the [[publish threshold]], optional below it', 1),
  (G, '**issue-body layout**:', 1),
  (G, 'the lead one under `## Dispatch contract` and, when the unit has one, the [[scribe dispatch contract]] after it', 1),
  (G, 'a reviewer whose own stamp was already consumed (a resumed or second turn) is blocked while', 0),
  (G, 'a reviewer dispatched without a `Unit:` line (it has no stamp)', 1),
  (G, 'an advisory pass (its advisory stamp is never satisfied)', 1),
  (G, 'a reviewer that wrote no verdict is let through', 1),
  (G, "derived from that reviewer's own [[review-join stamp]]", 0),
  (G, 'derived from every [[review-join stamp]] file present at stop time', 1),
 ],
 'lo2-5': [
  (LP, 'in the antislop repo itself it is also `skills/tdd/SKILL.md` at the repo root', 1),
  ('.claude/' + LP, 'in the antislop repo itself it is also `skills/tdd/SKILL.md` at the repo root', 1),
  (OR, 'the `~~~`-fenced block', 0),
  (OR, 'as written: the tilde-fenced block under', 1),
  ('.claude/' + OR, 'as written: the tilde-fenced block under', 1),
  (TM, 'in the issue body under `## Dispatch contract`, last,', 0),
  (TM, 'the lead contract first and the scribe contract (if any) after it', 1),
  (TM, 'the contracts last, fenced, the lead contract and then the scribe contract', 1),
  (TM, 'never a description such as "no FAIL line"', 1),
  ('.claude/' + TM, 'never a description such as "no FAIL line"', 1),
  (PP, '](../docs/adr/', 0),
  (PP, 'ADR-0016 (`docs/adr/0016-per-unit-review-join.md`) names this', 1),
  ('.claude/persona-protocol.md', '](../docs/adr/', 0),
  ('.claude/agents/reviewer.md', '](../docs/adr/', 0),
 ],
}
if unit not in checks:
    print('unknown unit: ' + unit, file=sys.stderr); sys.exit(2)
bad = 0
for f, phrase, want in checks[unit]:
    try:
        text = re.sub(r'\s+', ' ', open(f, encoding='utf-8').read())
    except OSError as e:
        print('FAIL %s unreadable: %s' % (f, e)); bad = 1; continue
    got = text.count(phrase)
    ok = got == want
    print('%s %s: %r count=%d want=%d' % ('OK  ' if ok else 'FAIL', f, phrase, got, want))
    bad |= not ok
print('lo2-claims: %s %s' % (unit, 'FAIL' if bad else 'ok'))
sys.exit(1 if bad else 0)
PY
