#!/usr/bin/env bash
# Usage: sfu-claims.sh <sfu-1|sfu-2|sfu-3>
# Claim-anchored checks for the prose units of the skills-audit follow-up slice
# (docs/plans/2026-10-14-skills-audit-followups.md). Each check counts a phrase
# in a file whose whitespace runs are collapsed to one space first, so a phrase
# split by the hard wrap is still found. A check is: file, phrase, wanted count.
# Exit 0 iff every check of the named unit holds. Red at the slice's base commit.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
[ "$#" -eq 1 ] || { echo "usage: $0 <sfu-1|sfu-2|sfu-3>" >&2; exit 2; }
python3 -I - "$1" <<'PY'
import re, sys
unit = sys.argv[1]
C = 'CONTEXT.md'; H = 'docs/harness-glossary.md'
A = 'docs/adr/0041-retire-skills-fork-and-own-archive-originals.md'
checks = {
 'sfu-1': [
  (C, 'publishes via `to-spec`', 0),
  (C, 'owns `to-tickets` slicing', 0),
  (C, '`task-master` and `to-tickets` are bypassed', 0),
  (C, 'onto the `to-spec` PRD template', 0),
  (C, 'by `fail-triage`/debug spec', 0),
  (C, 'wired to `spec-master` via `antislop:to-spec`. Turns', 0),
  (C, 'Nothing loads, lists, mirrors, hashes or ships it', 0),
  (C, '**Retired skill**:', 1),
  (C, '**Forked skill** (synonym: **fork-and-own**):', 1),
  (C, '**PRD template**:', 1),
  (C, '**debug spec**:', 1),
  (C, '**self-grill**:', 1),
  (C, '**Open Questions**:', 1),
  (C, '**work the frontier**:', 1),
  (C, '**expand-contract**:', 1),
  (H, '**skill base directory**:', 1),
  (H, 'because both are **drift-tracked skills**', 0),
  (H, 'Now that these SKILL.md files are tracked/shipped', 0),
  (H, 'Not the retired `code-review` skill', 1),
  (A, 'Retire five skills', 0),
  (A, 'Retire ten skills', 1),
  (A, 'Nothing loads, lists, mirrors, hashes or ships that directory', 0),
  (A, '## Corrections', 1),
 ],
 'sfu-2': [
  ('docs/persona-design-notes.md', '`to-spec`', 0),
  ('docs/persona-design-notes.md', '`to-tickets`', 0),
  ('docs/persona-design-notes.md', '`to-issues`', 0),
  ('docs/trust-model.md', 'and added a CHANGELOG entry naming the new version in that same commit', 1),
  ('skills/THIRD-PARTY-NOTICES.md', '`tdd` is forked: its live file', 0),
  ('skills/THIRD-PARTY-NOTICES.md', '`grilling`, `tdd`, `diagnosing-bugs` and `improve-codebase-architecture` are forked', 1),
  ('docs/maintenance/resync-vendored-skills.md', '| `grilling` | `skills/productivity/grilling` | verbatim |', 0),
  ('docs/maintenance/resync-vendored-skills.md', '| `skills/engineering/tdd` | verbatim |', 0),
  ('docs/maintenance/resync-vendored-skills.md', 'Do not run a project-wide find/replace', 1),
  ('docs/archive/skills/README.md', 'Nothing loads, lists, mirrors, hashes or ships this directory', 0),
  ('skills/grilling/SKILL.md', 'In a self-grill there is no one to ask', 1),
  ('skills/install-antislop/SKILL.md', 'a `jq` check', 0),
  ('skills/install-antislop/SKILL.md', '`persona-config.json` (inspect it with the `Read` tool', 1),
  ('skills/pathfinder/SKILL.md', 'under the directory the `issueTracker` field names', 1),
  ('skills/roast-work/SKILL.md', 'It never determines PASS/FAIL', 1),
  ('skills/improve-codebase-architecture/SKILL.md', 'You run as a one-shot subagent:', 0),
  ('skills/improve-codebase-architecture/SKILL.md', 'invoked through the `Skill` tool', 1),
 ],
 'sfu-3': [
  ('agents/lead-programmer.md', 'CHANGELOG line', 0),
  ('agents/scribe.md', 'CHANGELOG line', 0),
  ('agents/reviewer.md', 'CHANGELOG line', 0),
  ('skills/version-stamp-discipline/SKILL.md', 'CHANGELOG line', 0),
  (C, 'CHANGELOG line', 0),
  ('agents/lead-programmer.md', 'where `skills:` preloads are not applied', 1),
  ('.claude/agents/lead-programmer.md', 'where `skills:` preloads are not applied', 1),
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
print('sfu-claims: %s %s' % (unit, 'FAIL' if bad else 'ok'))
sys.exit(1 if bad else 0)
PY
