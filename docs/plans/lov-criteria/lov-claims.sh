#!/usr/bin/env bash
# Usage: lov-claims.sh <lov-1|lov-4|lov-5>
# Claim-anchored checks for the prose parts of the skills-audit leftovers slice
# (docs/plans/2026-10-14-skills-audit-leftovers.md). Each check counts a phrase
# in a file whose whitespace runs are collapsed to one space first, so a phrase
# split by the hard wrap is still found. A check is: file, phrase, wanted count.
# Exit 0 iff every check of the named unit holds. Red at the slice's base commit.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
[ "$#" -eq 1 ] || { echo "usage: $0 <lov-1|lov-4|lov-5>" >&2; exit 2; }
python3 -I - "$1" <<'PY'
import re, sys
unit = sys.argv[1]
C = 'CONTEXT.md'; R = 'docs/archive/skills/README.md'
A = 'docs/adr/0041-retire-skills-fork-and-own-archive-originals.md'
F = 'docs/plans/2026-10-14-skills-audit-followups.md'
IA = 'skills/install-antislop/SKILL.md'
RB = 'docs/maintenance/resync-vendored-skills.md'
TM = 'agents/task-master.md'
checks = {
 'lov-1': [
  (R, '| rewritten (stays live) | skills/grilling |', 0),
  (R, '| forked (stays live) | skills/grilling |', 1),
  (R, '| rewritten (stays live) | skills/improve-codebase-architecture |', 0),
  (R, '| forked (stays live) | skills/improve-codebase-architecture |', 1),
  (R, 'nothing lists, mirrors or hashes it', 0),
  (R, 'lists the archived originals of the forked skills', 1),
  (C, 'nothing lists, mirrors or hashes it', 0),
  (C, 'lists the archived originals of the forked skills', 1),
  (C, '**whole version**:', 1),
  (C, '**equivalent mutant**:', 1),
  (C, '**per-clone review state**:', 1),
  (A, 'nothing lists, mirrors or hashes it', 0),
  (A, 'lists the archived originals of the forked skills', 1),
  (A, '(unit lov-1)', 1),
  (IA, 'a Bash command such as `jq` naming that file can be refused', 0),
  (IA, 'allows a lone read-only `jq` query of that file', 1),
  ('.claude/' + IA, 'allows a lone read-only `jq` query of that file', 1),
  (RB, 'The first 7 are byte-verbatim', 0),
  (RB, 'The 3 verbatim skills', 1),
  (RB, 'so step 4 does not reach them', 1),
  ('skills/improve-codebase-architecture/SKILL.md', 'return the result as your final message', 0),
  ('skills/improve-codebase-architecture/SKILL.md', 'as your final message when you run as a subagent', 1),
  ('skills/pathfinder/SKILL.md', 'the `issueTracker` line names', 0),
  ('skills/pathfinder/SKILL.md', 'the `issueTracker` field names', 1),
  ('agents/lead-programmer.md', "under the antislop plugin's install directory", 1),
  ('.claude/agents/lead-programmer.md', "under the antislop plugin's install directory", 1),
  (F, 'it is an equivalent mutant', 0),
  (F, 'mutation: revert edit 3; cases (f), (g), (h1), (h2), (i) print FAIL', 0),
  (F, 'not a red-first test', 2),
  (F, '- 2026-10-14 (unit lov-1): the sfu-4 notes said cases (f) and (g)', 1),
 ],
 'lov-4': [
  (TM, 'as one fenced block whose first interior line is `Unit: <task-id>`', 1),
  ('.claude/agents/task-master.md', 'as one fenced block whose first interior line is `Unit: <task-id>`', 1),
  (TM, '<!-- issue-body-layout-example:begin -->', 1),
  (TM, 'fenced the same way as the lead contract', 1),
  ('skills/pathfinder/SKILL.md', 'as one fenced block whose first interior line is `Unit: <task-id>`', 1),
 ],
 'lov-5': [
  ('docs/harness-glossary.md', 'without cross-dispatch interference', 0),
  ('docs/harness-glossary.md', 'A stamp names no owner', 1),
  ('hooks/scripts/lib/stop-gate-core.sh', 'the unit(s) you were dispatched for', 0),
  ('hooks/scripts/lib/stop-gate-core.sh', 'A review-join stamp names no owner', 1),
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
print('lov-claims: %s %s' % (unit, 'FAIL' if bad else 'ok'))
sys.exit(1 if bad else 0)
PY
