# Dispatch contracts: implementer tier defaults to haiku (2026-10-08)

Spec: `docs/plans/2026-10-08-haiku-default-tier.md` (canonical). Slicing: task-master, standard path, 7 units (htd-1 .. htd-7 = U1 .. U7). Umbrella spec issue (PRD view): #529, `gh issue view 529 --repo Storreslara/AntiSlop`.

## Retrieval contract
No per-unit issues exist: `gh label create` and `gh issue create` for the unit issues were denied by the permission classifier and were not retried or worked around. The retrieval contract for every unit is therefore the plan file plus this file: `docs/plans/2026-10-08-haiku-default-tier.md` (Step U<k>) and `docs/plans/2026-10-08-haiku-default-tier-contracts.md` under `## Unit htd-<n>`. The contract block under each `## Unit` heading outranks the plan prose; a conflict between them is a spec gap: STOP. Every contract's commit subject ends `(#529)` (the umbrella issue); scribe closes nothing and never closes #529.

## Dispatch order and tags
| order | unit | persona | Suggested model | state |
|---|---|---|---|---|
| 1 | htd-1 dispatch A (ADR-0040 and ADR-0026 line) | scribe | scribe frontmatter `haiku` (no tag) | dispatchable |
| 2 | htd-1 dispatch B (audit file, old plan) | lead-programmer | `Suggested model: sonnet` | dispatchable, after A |
| 3 | htd-2 | lead-programmer | `Suggested model: sonnet` | dispatchable |
| 4 | htd-3 | lead-programmer | `Suggested model: sonnet` | dispatchable, after htd-1 and htd-2 |
| 5 | htd-5 | lead-programmer | `Suggested model: sonnet` | dispatchable, after htd-3 (runs before htd-4 by ruling) |
| 6 | htd-4 | lead-programmer | `Suggested model: sonnet` | dispatchable, after htd-5 (released) |
| 7 | htd-6 | lead-programmer | `Suggested model: sonnet` | dispatchable, after htd-4 and htd-5 (released) |
| 8 | htd-7 | lead-programmer | `Suggested model: sonnet` | dispatchable, after htd-4 (released) |

Tags: `sonnet` is the default tier until htd-4 flips it, and no unit has a prior `.fail` record (spot check: no `htd-2.fail`; the ids are new), so no unit is tagged above `sonnet` and none below it (spec R1). Every contract states that the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the actual diff. The ladder assumption stands: `opus` gets two attempts, ladder exhaustion is the sixth FAIL (Open Question 1, unchanged).

Version chain (assumes HEAD at 0.31.140 and no other bump): htd-2 0.31.141, htd-3 0.31.142, htd-5 0.31.143, htd-4 0.31.144. This swaps htd-4 and htd-5 relative to the plan's R3 (confirmed by spec-master). Each persona contract carries a precondition on the exact current version and STOPs on any mismatch; the orchestrator then re-derives every version literal (HEAD version + 1). htd-1, htd-6, htd-7 set no version.

## Slice state
| unit | dispatchable or held | reason |
|---|---|---|
| htd-1 A, B | dispatchable | none |
| htd-2 | dispatchable | none |
| htd-3 | dispatchable | none |
| htd-5 | dispatchable | none |
| htd-4 | dispatchable | released: spec-master ruled H-htd4 (literal 'haiku' in the skeleton, edits 5 and 6, criterion 10) |
| htd-6 | dispatchable | released with htd-4 |
| htd-7 | dispatchable | released with htd-4 |

Resume done: the HELD lines for htd-4, htd-6 and htd-7 are removed and htd-4 is re-derived from the amended Step U4.

## Intersection table
| unit | shared files | depends on |
|---|---|---|
| htd-1 | none | none (dispatch B depends on dispatch A) |
| htd-2 | `bin/cli.js`, `templates/persona-config.schema.json` | none |
| htd-3 | `agents/orchestrator.md`, `agents/task-master.md`, `tests/writer-tier-consistency.test.js` | htd-1, htd-2 |
| htd-5 | none | htd-3 |
| htd-4 | `bin/cli.js`, `templates/persona-config.schema.json`, `agents/orchestrator.md`, `agents/task-master.md`, `tests/writer-tier-consistency.test.js` | htd-2, htd-3, htd-5 |
| htd-6 | `tests/writer-tier-consistency.test.js` | htd-4, htd-5 |
| htd-7 | none | htd-4 |

htd-2, htd-3, htd-4, htd-5 edit version-stamped files, so each sets HEAD + 1 and they serialise (htd-3 after htd-2, htd-5 after htd-3, htd-4 after htd-5). htd-1, htd-6, htd-7 touch no stamped path.

## SPEC-GAP H-htd4 (resolved)
spec-master ruled on 2026-10-08: the fresh-scaffold skeleton in `bin/cli.js` gets the literal `'haiku'` (never `implementerFrontmatterDefault()`) and its comment says `model: haiku`. htd-4 now carries these as edits 5 and 6, a mutation on criterion 3, and new criterion 10; edits after the old edit 4 are renumbered by +2.

## Notes for the orchestrator
- htd-1 is split in two dispatches under the one id `htd-1` (scribe: `docs/adr/` files; lead-programmer: `docs/audits/` and `docs/plans/` files, which are outside scribe's write scope per `agents/scribe.md`). Review once, after both land. Two commits carry `(htd-1)`; the range criteria bind to the first and last of them.
- htd-2 writes the migration (confirmed by spec-master) as a column-0 function `applyImplementerModelMigration` plus one call line instead of the plan's inline block, so every payload keeps its exact indentation (the contract's `indent: N` rule). Behaviour is the plan's; spec-master may veto.
- htd-4 has one orchestrator-filled token, `<T0>` (edit 3): the committer time of HEAD at dispatch (command in its Pre-resolved context). A dispatch that still contains it must STOP.
- The ADR body in htd-1's scribe contract is 87 lines, over the 80-line inline limit; it is a single fenced `body:` payload as the scribe shape requires, in a tilde fence (the limit counts backtick fences only). Do not split it.
- `bash tests/validate.sh` is the last criterion of every unit (plan P5). It takes about 11 minutes, and in a fresh `git worktree` of HEAD it already exits 1 for environment reasons (agent-memory notes not present, unreachable old commits), so run it in the main checkout. It was not run in the verification below.
- Verification done for every contract, in scratch worktrees chained in dispatch order (htd-1 A, B, htd-2, htd-3, htd-5, htd-4, then htd-6 and htd-7 on top of htd-4; htd-4 re-verified after the ruling with the skeleton edits): each Ordered edit applied literally (anchor count 1, before-text once), every non-validate criterion ran with the expected exit and stdout, each `skip edit N` mutation was run by re-applying the unit without edit N, and the manual mutations carry the proof line of what was run. `node bin/contract-score.js --rubric=v2` prints `"score":7` and `"sizeOver":false` for all eight contract blocks.
- This file and `docs/plans/2026-10-08-haiku-default-tier.md` are untracked at the time of writing; commit both before the first dispatch.

## Unit htd-1

Step U1 (scribe + lead-programmer): spirit ruling, ADR, supersession lines. Suggested model: scribe on its frontmatter (dispatch A), sonnet (dispatch B). Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U1.

## Dispatch contract (two dispatches)

### Dispatch A - persona: scribe

~~~~~~markdown
Unit: htd-1

## Objective
Dispatch A of two under unit htd-1 (scribe half): `docs/adr/0040-implementer-tier-haiku-default.md` exists with the full ADR text below, and `docs/adr/0026-writer-tier-reversed-to-sonnet.md` gains exactly one new line naming it. One commit. Dispatch B (lead-programmer) edits the audit file and the old plan and runs after this one.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U1. This contract is under `## Unit htd-1` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Glossary edits
none

## Doc edits
1. file: `docs/adr/0026-writer-tier-reversed-to-sonnet.md`
   heading: `# ADR 0026`
   insert-after: `Ratified by: user (repo owner), 2026-08-25`
   text: `Superseded-in-part-by: ADR-0040 (implementer tier defaults to haiku, two attempts per tier)`
   (one new line directly under the `Ratified by:` line; no other line of the file changes)
prune: none

## ADR
0040 Implementer tier defaults to haiku, two attempts per tier
file: docs/adr/0040-implementer-tier-haiku-default.md
body:
indent: 0
~~~~markdown
# ADR 0040: Implementer tier defaults to `haiku`, two attempts per tier

Date: 2026-10-08
Status: Accepted
Amends: ADR-0026
Ratified by: user (repo owner), 2026-10-08

## Context

ADR-0026 (2026-08-25) set the implementer tier to `sonnet` and pre-registered a
forward rule. The audit `docs/audits/2026-10-06-adr0026-forward-rule.md` found
the letter of that rule met (n=205, FAIL rate 30.7% against 32.5%) and the spend
half unverifiable. The user ruled the spirit **not met** on 2026-10-08: "it
doesn't, we need more testing and long-term evidence".

The rubric-gated programme (`docs/plans/2026-10-06-rubric-gated-haiku-programme.md`)
would have changed the tier only after a replay verdict (gate G4) showed a
rubric-gated `haiku` tag beating both `sonnet` baselines. Its gate G3 had not
opened (`rubric_era=13 scored7=10`, against 60 and 20), so no replay ran.

## Human override

The user (repo owner) overrides, on 2026-10-08, the programme's Stage 4 replay
verdict (gate G4) and its Stage 5 condition that the `haiku` policy beat both
baselines. Stage 4 is parked, Stage 5 is superseded by this ADR, and no replay
evidence supports this decision. The pre-registered forward rule below is what
tests it.

## Decision

1. `agents/lead-programmer.md` frontmatter is `model: haiku`. scribe stays
   `haiku`.
2. `defaultImplementerModel` accepts `haiku`, `sonnet`, `opus`; any other present
   value still resolves to `opus`. The resolved value is the default tier. A
   recorded `"sonnet"` from before this change is migrated once to `"haiku"` by
   `--update`, with a printed note; a project that wants `sonnet` sets it again.
3. Escalation ladder: the tiers from the default tier upward (`haiku`, `sonnet`,
   `opus`), two attempts each. A tier's second FAIL moves the unit to the next
   tier automatically. Only the second FAIL on the top tier (ladder exhaustion)
   stops and asks the human. The next tier is computed from the unit's FAIL-block
   count, so a fresh session needs no record of which tier failed; an unreadable
   count dispatches `opus`. FAIL blocks older than the haiku-default cutover start
   the unit's ladder at `sonnet`.
4. The reviewer-gate ratchet (`hooks/scripts/reviewer-tier.sh`, ADR-0009) is
   unchanged. The exporter, the contract rubric and the audits stay.

## Forward rule (pre-registered)

**After ≥60 units dispatched under the `haiku` default** (units in a fresh
`node scripts/unit-outcomes.js` export with `terminal_ts` at or after the
**Haiku-default cutover** timestamp in `agents/orchestrator.md`), all three must
hold:

- fail-rate ≤ 0.35 (units with at least one FAIL block / units)
- escalation-rate ≤ 0.15 (units with at least two FAIL blocks, i.e. that left
  `haiku` / units)
- exhaustion-rate ≤ 0.02 (units with at least six FAIL blocks / units)

Early tripwire: from 20 units, an escalation-rate above 0.30 or two exhausted
units ends the trial early with the same consequence.

Audit command (`<F>` the export file, `<T0>` the cutover timestamp):

    jq -rs --arg t0 "<T0>" '[.[] | select(.terminal_ts >= $t0)] as $p | ($p|length) as $n | ($p|map(select(.fail_blocks>=1))|length) as $f1 | ($p|map(select(.fail_blocks>=2))|length) as $f2 | ($p|map(select(.fail_blocks>=6))|length) as $f6 | if $n < 20 then "insufficient" elif $n < 60 then (if ($f2/$n) > 0.30 or $f6 >= 2 then "tripwire" else "insufficient" end) elif ($f1/$n) <= 0.35 and ($f2/$n) <= 0.15 and ($f6/$n) <= 0.02 then "met" else "not-met" end' <F>

**If the rule prints `not-met` or `tripwire`,** the pre-committed action is to
restore ADR-0026's `sonnet` default (`model: sonnet` in lead-programmer's
frontmatter and `"default": "sonnet"` in the schema; the ladder then starts at
`sonnet` by itself). Keeping `haiku` instead needs an explicit user ruling
written into the audit file. This rule is revisited, not defended.

Spend is recorded alongside (`bash scripts/spend-accounting.sh --until=<cutoff>`)
for information only: the script cannot attribute spend to a unit or to the
implementer, and transcripts are pruned after about 30 days.

## Consequences

- More attempts per unit are possible (up to six before a human sees it), each
  with a reviewer pass; the bet is that most units finish on `haiku`.
- The forward rule needs no new tooling; the exporter's era inference learns the
  new era (`haiku` from the cutover).

## Related

- ADR-0026 (amended here: tier and ladder), ADR-0010 (the first `haiku`
  default, with first-FAIL escalation), ADR-0009 (reviewer tier, unchanged).
- Plan: `docs/plans/2026-10-08-haiku-default-tier.md`.
~~~~

## Close conditions
- issue #529 is the parent [spec] issue for this unit and no per-unit issue exists: close nothing, and never close #529
- task-id: htd-1
- marker first line: "PASS htd-1 "
- commit: one commit of the two files, subject `docs(htd-1): ADR-0040 implementer tier defaults to haiku, ADR-0026 superseded in part (#529)`, then a second `-m` argument holding exactly the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; stage with `git add docs/adr/0040-implementer-tier-haiku-default.md docs/adr/0026-writer-tier-reversed-to-sonnet.md`
- precondition: `ls docs/adr | /usr/bin/grep -c '^0040-'` prints `0` and `ls docs/adr | /usr/bin/grep -E '^[0-9]{4}-' | sort | tail -1` starts with `0039-`; anything else: STOP and report a spec gap (the number is re-derived by the orchestrator)

## Do NOT touch
- `agents/`
- `tests/`
- `CONTEXT.md`
- `docs/audits/` (dispatch B)
- `docs/plans/` (dispatch B)
- `docs/adr/0026-writer-tier-reversed-to-sonnet.md` lines other than the one new `Superseded-in-part-by:` line
- every other file under `docs/adr/`

## Acceptance criteria
1. run: `ls docs/adr | /usr/bin/grep -cE '^[0-9]{4}-implementer-tier-haiku-default\.md$'`
   exit: 0
   stdout: `1`
   mutation: skip the ADR; prints `0`, exit 1.
2. run: `ls docs/adr | /usr/bin/grep -E '^[0-9]{4}-' | sort | tail -1`
   exit: 0
   stdout: `0040-implementer-tier-haiku-default.md`
   mutation: name the file `0041-implementer-tier-haiku-default.md`; prints `0041-implementer-tier-haiku-default.md`.
   proof: scratch checkout: `git mv docs/adr/0040-implementer-tier-haiku-default.md docs/adr/0041-implementer-tier-haiku-default.md`; this `run:` printed `0041-implementer-tier-haiku-default.md`.
3. run: `git diff "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" -- docs/adr/0026-writer-tier-reversed-to-sonnet.md | /usr/bin/grep -E '^[-+]' | /usr/bin/grep -vE '^(\+\+\+|---) ' | wc -l`
   exit: 0
   stdout: `1`
   mutation: change any second line of ADR-0026; prints `2`.
   proof: scratch checkout: appended one line to ADR-0026 before the commit; this `run:` printed `2`.
4. run: `git diff "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" -- docs/adr/0026-writer-tier-reversed-to-sonnet.md | /usr/bin/grep -c '^+Superseded-in-part-by: ADR-0040 (implementer tier defaults to haiku, two attempts per tier)$'`
   exit: 0
   stdout: `1`
   mutation: skip the Doc edit; prints `0`, exit 1.
5. run: `for p in "Amends: ADR-0026" "## Human override" "docs/audits/2026-10-06-adr0026-forward-rule.md" "≥60 units dispatched under the" "fail-rate ≤ 0.35" "escalation-rate ≤ 0.15" "exhaustion-rate ≤ 0.02" "tripwire" "restore ADR-0026's" "rubric_era=13 scored7=10"; do tr '\n' ' ' < docs/adr/0040-implementer-tier-haiku-default.md | tr -s ' ' | /usr/bin/grep -cF -- "$p"; done | /usr/bin/grep -c '^1$'`
   exit: 0
   stdout: `10`
   mutation: delete the `## Human override` heading line from the ADR; prints `9`.
   proof: ran `sed '/^## Human override$/d'` over the ADR text in a scratch checkout; the loop printed `9`.
6. run: `A=docs/adr/0040-implementer-tier-haiku-default.md; for t in 2026-08-25T00:00:00Z 2026-10-05T00:00:00Z; do /usr/bin/grep -E '^    jq -rs' "$A" | sed "s/^    //; s/<T0>/$t/; s#<F>#docs/audits/unit-outcomes/2026-10-06.jsonl#" | bash; done | tr '\n' ' '`
   exit: 0
   stdout: `met insufficient`
   mutation: in a scratch copy replace `0.35` by `0.30` in the jq line; the first word becomes `not-met`.
   proof: ran `sed 's/<= 0.35/<= 0.30/'` on the extracted jq line against the 2026-08-25 cutoff in a scratch checkout; printed `not-met` (63/205 = 0.307).
7. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'docs(htd-1): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
8. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
9. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `docs/adr/0026-writer-tier-reversed-to-sonnet.md docs/adr/0040-implementer-tier-haiku-default.md`
   mutation: also commit an edit to `CONTEXT.md`; the list gains `CONTEXT.md`.
   proof: scratch checkout of the finished unit: `echo x >> CONTEXT.md && git commit -a --amend --no-edit`, then this `run:` printed a list starting with `CONTEXT.md`; reset with `git reset --hard <finished SHA>`.
10. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: delete the substring `32.5%` from ADR-0026; AC-D8 fails, exit 1.
   proof: ran `sed -i 's/32\.5%/xx/' docs/adr/0026-writer-tier-reversed-to-sonnet.md` in a scratch checkout; this `run:` exited 1; restored with `git checkout -- docs/adr/0026-writer-tier-reversed-to-sonnet.md`.
11. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave ADR-0026 unstaged at commit time; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap.
~~~~~~

### Dispatch B - persona: lead-programmer (after A)

~~~~~markdown
Unit: htd-1

## Objective
Dispatch B of two under unit htd-1 (lead-programmer half; dispatch A, the scribe's ADR, has already landed): the audit file records the user's spirit ruling `not-met`, and the rubric-gated programme plan opens with a line saying its Stage 5 is superseded and its Stage 4 parked. One commit; no version-stamped path is touched, so there is no version bump.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U1. This contract is under `## Unit htd-1` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `docs/audits/2026-10-06-adr0026-forward-rule.md` (anchor: line matching `spirit-ruling: PENDING-HUMAN`)
- `docs/plans/2026-10-06-rubric-gated-haiku-programme.md` (anchor: line matching `## Goal`)

## Ordered edits
1. file: `docs/audits/2026-10-06-adr0026-forward-rule.md`
   anchor: line matching `spirit-ruling: PENDING-HUMAN`
   before: `spirit-ruling: PENDING-HUMAN`
   indent: 0
   after:
```
spirit-ruling: not-met
spirit-ruled-by: user (repo owner), 2026-10-08: "it doesn't, we need more testing and long-term evidence"
```
2. file: `docs/plans/2026-10-06-rubric-gated-haiku-programme.md`
   anchor: line matching `## Goal`
   before: `## Goal`
   indent: 0
   after:
```
Superseded in part (2026-10-08): Stage 5 (U5-1..U5-3 and the Draft ADR) is superseded by docs/plans/2026-10-08-haiku-default-tier.md and its ADR (*-implementer-tier-haiku-default.md); Stage 4 (U4-1..U4-3) is parked and not dispatched; gate G4 was overridden by the user on 2026-10-08. Stages 0-3, the exporter, the contract rubric and gate G3's query stay in force.

## Goal
```
3. command: `git add docs/audits/2026-10-06-adr0026-forward-rule.md docs/plans/2026-10-06-rubric-gated-haiku-programme.md && git commit -m "docs(htd-1): spirit ruling recorded, rubric programme Stage 5 superseded and Stage 4 parked (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
4. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/`
- `tests/`
- `CONTEXT.md`
- `docs/adr/` (dispatch A owns it)
- `docs/audits/2026-10-06-adr0026-forward-rule.md` lines other than the `spirit-ruling:` line

## Acceptance criteria
1. run: `printf '%s %s\n' "$(/usr/bin/grep -c '^spirit-ruling: not-met$' docs/audits/2026-10-06-adr0026-forward-rule.md)" "$(/usr/bin/grep -c 'PENDING-HUMAN' docs/audits/2026-10-06-adr0026-forward-rule.md)"`
   exit: 0
   stdout: `1 0`
   mutation: skip edit 1; prints `0 1`.
2. run: `printf '%s %s\n' "$(/usr/bin/grep -c '^spirit-ruled-by: user (repo owner), 2026-10-08' docs/audits/2026-10-06-adr0026-forward-rule.md)" "$(/usr/bin/grep -cE '^spirit-ruling: (PENDING-HUMAN|met|not-met)$' docs/audits/2026-10-06-adr0026-forward-rule.md)"`
   exit: 0
   stdout: `1 1`
   mutation: skip edit 1; prints `0 1`.
3. run: `/usr/bin/grep -c '^Superseded in part (2026-10-08):' docs/plans/2026-10-06-rubric-gated-haiku-programme.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; prints `0`, exit 1.
4. run: `test "$(ls docs/adr | /usr/bin/grep -E 'implementer-tier-haiku-default' | cut -c1-4)" = "$(/usr/bin/grep -o '^Superseded-in-part-by: ADR-[0-9]*' docs/adr/0026-writer-tier-reversed-to-sonnet.md | /usr/bin/grep -o '[0-9]*$')" && echo adr-link-ok`
   exit: 0
   stdout: `adr-link-ok`
   mutation: run without dispatch A; prints nothing, exit 1.
   proof: in a scratch checkout without dispatch A, `ls docs/adr` lists no `implementer-tier-haiku-default` file and the `test` fails, exit 1.
5. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `docs/adr/0026-writer-tier-reversed-to-sonnet.md docs/adr/0040-implementer-tier-haiku-default.md docs/audits/2026-10-06-adr0026-forward-rule.md docs/plans/2026-10-06-rubric-gated-haiku-programme.md`
   mutation: also commit an edit to `README.md`; the list gains `README.md`. (AC1.8, both dispatches)
   proof: scratch checkout of the finished unit: `echo '# x' >> README.md && git commit -a --amend --no-edit`, then this `run:` printed a list starting with `README.md`; reset with `git reset --hard <finished SHA>`.
6. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: delete the substring `32.5%` from `docs/adr/0026-writer-tier-reversed-to-sonnet.md`; AC-D8 fails, exit 1.
7. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'docs(htd-1): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
8. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-1)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `2`
   mutation: drop the trailer from one of the two commits; prints `1`.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `1`; reset as above.
9. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one edited file unstaged at commit time; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
10. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; the writer-tier test inside validate.sh fails and it prints `validate-exit=1`.
   proof: the same mutation made `node tests/writer-tier-consistency.test.js` exit 1 in a scratch checkout; validate.sh itself takes about 11 minutes and was not re-run for this probe.

## Pre-resolved context
precondition: dispatch A (scribe) has landed: `git log --format=%H -F --grep='(htd-1)' | wc -l` prints `1` before you start. Anything else: STOP and report.
precondition: FIRST check that `/usr/bin/grep -cF 'spirit-ruling: PENDING-HUMAN' docs/audits/2026-10-06-adr0026-forward-rule.md` and `/usr/bin/grep -cF '## Goal' docs/plans/2026-10-06-rubric-gated-haiku-programme.md` each print `1`. Anything else: STOP and report; do not adapt the text.
tdd: no prose-only doc edit
blast-radius: docs/audits/2026-10-06-adr0026-forward-rule.md:31, docs/plans/2026-10-06-rubric-gated-haiku-programme.md:12
note: these two files are outside scribe's write scope (`agents/scribe.md` allows `.claude/wiki/`, `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/`), which is why this half is a lead-programmer dispatch under the shared unit id htd-1.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff.
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: docs(htd-1): spirit ruling recorded, rubric programme Stage 5 superseded and Stage 4 parked (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-1 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit htd-2

Step U2 (lead-programmer): `haiku` is a recognised `defaultImplementerModel`; one-time migration (disabled until htd-4). Suggested model: sonnet. Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U2.

## Dispatch contract

~~~~~markdown
Unit: htd-2

## Objective
`haiku` is a recognised `defaultImplementerModel` value in `bin/cli.js` and the schema enum (any other unrecognised value still resolves to `opus`), and a one-time `--update` migration of an old `"sonnet"` to `"haiku"` exists but is switched off (`IMPLEMENTER_HAIKU_DEFAULT_SINCE = null`). Version 0.31.141, mirrors refreshed, one commit. Done = every criterion below passes.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U2. This contract is under `## Unit htd-2` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `bin/cli.js` (anchor: line matching `const IMPLEMENTER_MODEL_TIERS = ['sonnet', 'opus'];`)
- `templates/persona-config.schema.json` (anchor: line matching `"enum": ["sonnet", "opus"],`)
- `tests/default-implementer-model.test.js` (anchor: line matching `check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.140",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites (10 agent mirrors, the project config, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`); never edit them by hand

## Ordered edits
1. file: `bin/cli.js`
   anchor: line matching `const IMPLEMENTER_MODEL_TIERS = ['sonnet', 'opus'];`
   indent: 0
   before:
```
// Recognised `defaultImplementerModel` tier values — must stay in sync with
// templates/persona-config.schema.json's `defaultImplementerModel` enum,
// which (with CONTEXT.md's **Writer tier** entry) is what establishes that
// only two tiers exist today, so "more capability" resolves unambiguously
// to 'opus'.
const IMPLEMENTER_MODEL_TIERS = ['sonnet', 'opus'];
```
   after:
```
// Recognised `defaultImplementerModel` tier values, cheapest first — must
// stay in sync with templates/persona-config.schema.json's
// `defaultImplementerModel` enum. 'opus' is the most capable, so "more
// capability" for an unrecognised value still resolves to 'opus'.
const IMPLEMENTER_MODEL_TIERS = ['haiku', 'sonnet', 'opus'];

// The first plugin version whose packaged agents/lead-programmer.md
// frontmatter reads `model: haiku` (docs/plans/2026-10-08-haiku-default-tier.md).
// null disables the migration below; the cutover unit sets it in the same
// commit as the frontmatter flip.
const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;

// A recorded "sonnet" older than IMPLEMENTER_HAIKU_DEFAULT_SINCE is the old
// shipped default (scaffold or item18-2 backfill) as far as this code can
// tell, so --update moves it to "haiku" once. Returns the new value, or null
// for no change.
function migrateDefaultImplementerModel(value, oldPluginVersion, since, frontmatterDefault) {
  if (since == null || value !== 'sonnet' || frontmatterDefault !== 'haiku') return null;
  if (oldPluginVersion && compareSemver(oldPluginVersion, since) >= 0) return null;
  return 'haiku';
}

// Applies the migration above to a config in place and prints the Note. Called
// from runUpdate after the item18-2 backfill; kept at column 0 so the edit that
// calls it is a single line.
function applyImplementerModelMigration(config, dryRun) {
  const migratedImplementerModel = migrateDefaultImplementerModel(
    config.defaultImplementerModel, config.pluginVersion, IMPLEMENTER_HAIKU_DEFAULT_SINCE, implementerFrontmatterDefault());
  if (migratedImplementerModel) {
    config.defaultImplementerModel = migratedImplementerModel;
    console.log(
      `Note: persona-config.json defaultImplementerModel "sonnet" predates the haiku default (v${IMPLEMENTER_HAIKU_DEFAULT_SINCE}) ` +
        `— ${dryRun ? 'would migrate' : 'migrated'} to "haiku". Set it back to "sonnet" by hand to keep the old default.\n`
    );
  }
}
```
2. file: `bin/cli.js`
   anchor: line matching `  const backfilled = backfilledSubs || backfilledHashes;`
   insert-after: `  applyImplementerModelMigration(config, dryRun);`
3. file: `bin/cli.js`
   anchor: line matching `  resolveDefaultImplementerModel,`
   indent: 0
   before:
```
  resolveDefaultImplementerModel,
};
```
   after:
```
  resolveDefaultImplementerModel,
  migrateDefaultImplementerModel,
  IMPLEMENTER_MODEL_TIERS,
  IMPLEMENTER_HAIKU_DEFAULT_SINCE,
};
```
4. file: `templates/persona-config.schema.json`
   anchor: line matching `"enum": ["sonnet", "opus"],`
   before: `      "enum": ["sonnet", "opus"],`
   after: `      "enum": ["haiku", "sonnet", "opus"],`
5. file: `templates/persona-config.schema.json`
   anchor: line matching `The lead-programmer model tier the orchestrator dispatches on when a unit carries no per-dispatch`
   before: `An ABSENT key resolves to the frontmatter default (\"sonnet\" today)`
   after: `An ABSENT key resolves to the packaged frontmatter default`
6. file: `templates/persona-config.schema.json`
   anchor: line matching `The lead-programmer model tier the orchestrator dispatches on when a unit carries no per-dispatch`
   before: `own absent/unrecognised-value fallback."`
   after: `own absent/unrecognised-value fallback. A \"sonnet\" value recorded before the haiku default shipped is migrated once to \"haiku\" by --update (bin/cli.js migrateDefaultImplementerModel)."`
7. file: `tests/default-implementer-model.test.js`
   anchor: line matching `check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {`
   indent: 0
   before:
```
check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'haiku' }, 'sonnet'), 'opus');
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'bogus-junk' }, 'sonnet'), 'opus');
});
```
   after:
```
check('resolveDefaultImplementerModel: haiku is a recognised tier and passes through', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'haiku' }, 'sonnet'), 'haiku');
});

check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'bogus-junk' }, 'sonnet'), 'opus');
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'fable' }, 'haiku'), 'opus');
});

check('IMPLEMENTER_MODEL_TIERS equals the schema enum', () => {
  const schema = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'templates', 'persona-config.schema.json'), 'utf8'));
  assert.deepStrictEqual(cli.IMPLEMENTER_MODEL_TIERS, schema.properties.defaultImplementerModel.enum);
});

check('migrateDefaultImplementerModel: only an old-version "sonnet" moves, only to haiku, only when enabled', () => {
  const m = cli.migrateDefaultImplementerModel;
  assert.strictEqual(m('sonnet', '0.31.140', '0.31.143', 'haiku'), 'haiku');
  assert.strictEqual(m('sonnet', '0.31.143', '0.31.143', 'haiku'), null);
  assert.strictEqual(m('sonnet', undefined, '0.31.143', 'haiku'), 'haiku');
  assert.strictEqual(m('opus', '0.31.140', '0.31.143', 'haiku'), null);
  assert.strictEqual(m('haiku', '0.31.140', '0.31.143', 'haiku'), null);
  assert.strictEqual(m('sonnet', '0.31.140', null, 'haiku'), null);
  assert.strictEqual(m('sonnet', '0.31.140', '0.31.143', 'sonnet'), null);
});
```
8. file: `tests/default-implementer-model.test.js`
   anchor: line matching `check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {`
   indent: 0
   before:
```
check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {
```
   after:
```
check('--update applies migrateDefaultImplementerModel to an old-version "sonnet" config', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-migrate-'));
  try {
    const before = buildBaselineProject(tmp);
    before.defaultImplementerModel = 'sonnet';
    before.pluginVersion = '0.31.0';
    writeConfig(tmp, before);

    const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

    const frontmatter = frontmatterModel(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'lead-programmer.md'), 'utf8'));
    const expected = cli.migrateDefaultImplementerModel('sonnet', '0.31.0', cli.IMPLEMENTER_HAIKU_DEFAULT_SINCE, frontmatter) || 'sonnet';
    assert.strictEqual(readConfig(tmp).defaultImplementerModel, expected);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {
```
9. file: `.claude-plugin/plugin.json` (version 0.31.141)
   anchor: line matching `"version": "0.31.140",`
   before: `  "version": "0.31.140",`
   after: `  "version": "0.31.141",`
10. file: `package.json` (version 0.31.141)
   anchor: line matching `"version": "0.31.140",`
   before: `  "version": "0.31.140",`
   after: `  "version": "0.31.141",`
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**haiku is a recognised implementer tier (htd-2, 0.31.141).** `bin/cli.js` `IMPLEMENTER_MODEL_TIERS` and the `defaultImplementerModel` schema enum gain `haiku`; any other unrecognised value still resolves to `opus`. A one-time `--update` migration of a pre-cutover `"sonnet"` to `"haiku"` is added but disabled (`IMPLEMENTER_HAIKU_DEFAULT_SINCE = null`) until the cutover unit.
```
12. command: `node bin/cli.js --update`
   expect: 0
13. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
14. command: `git add bin/cli.js templates/persona-config.schema.json tests/default-implementer-model.test.js .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(htd-2): haiku is a recognised implementer tier, migration added but disabled (0.31.141) (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
15. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/` (every file in it)
- `hooks/scripts/reviewer-tier.sh`
- `templates/persona-config.schema.json` line with `"default": "sonnet",` (U4 flips it)
- `bin/cli.js` function body of `resolveDefaultImplementerModel`
- `tests/default-implementer-model.test.js` checks from `stripWhitespace` through the `orchestrator.md restricts the frontmatter fallback` check

## Acceptance criteria
1. run: `node tests/default-implementer-model.test.js`
   exit: 0
   stdout: `All default-implementer-model checks passed.`
   mutation: skip edit 1; exit 1.
   proof: this criterion also passes at the base (the old checks pass); criterion 2 counts the four new checks.
2. run: `node tests/default-implementer-model.test.js | /usr/bin/grep -cE '^OK   (resolveDefaultImplementerModel: haiku is a recognised|IMPLEMENTER_MODEL_TIERS equals|migrateDefaultImplementerModel: only|--update applies migrateDefaultImplementerModel)'`
   exit: 0
   stdout: `4`
   mutation: skip edit 7; prints `1`.
3. run: `node -e "const c=require('./bin/cli.js');const ok=c.resolveDefaultImplementerModel({defaultImplementerModel:'haiku'},'sonnet')==='haiku'&&c.resolveDefaultImplementerModel({defaultImplementerModel:'bogus'},'haiku')==='opus';console.log(ok?'resolve-ok':'resolve-bad');process.exit(ok?0:1)"`
   exit: 0
   stdout: `resolve-ok`
   mutation: skip edits 1 and 3; prints `resolve-bad`, exit 1.
4. run: `node -e "const c=require('./bin/cli.js');const s=require('./templates/persona-config.schema.json');const ok=JSON.stringify(c.IMPLEMENTER_MODEL_TIERS)===JSON.stringify(s.properties.defaultImplementerModel.enum)&&c.IMPLEMENTER_HAIKU_DEFAULT_SINCE===null&&s.properties.defaultImplementerModel.default==='sonnet';console.log(ok?'enum-sync-ok':'enum-sync-bad');process.exit(ok?0:1)"`
   exit: 0
   stdout: `enum-sync-ok`
   mutation: skip edit 4; prints `enum-sync-bad`, exit 1.
5. run: `node -e "const m=require('./bin/cli.js').migrateDefaultImplementerModel;console.log(JSON.stringify([m('sonnet','0.31.140','0.31.143','haiku'),m('sonnet','0.31.143','0.31.143','haiku'),m('sonnet',undefined,'0.31.143','haiku'),m('opus','0.31.140','0.31.143','haiku'),m('sonnet','0.31.140',null,'haiku'),m('sonnet','0.31.140','0.31.143','sonnet')]))"`
   exit: 0
   stdout: `["haiku",null,"haiku",null,null,null]`
   mutation: change `>= 0` to `> 0` in `migrateDefaultImplementerModel`; the second entry becomes `"haiku"`.
   proof: `sed -i 's/oldPluginVersion, since) >= 0/oldPluginVersion, since) > 0/' bin/cli.js` then re-run `run:` printed `["haiku","haiku","haiku",null,null,null]` in a scratch checkout; restored with `git checkout -- bin/cli.js`.
6. run: `grep -c 'applyImplementerModelMigration' bin/cli.js`
   exit: 0
   stdout: `2`
   mutation: skip edit 2; prints `1`.
7. run: `node tests/cli-backfill.test.js`
   exit: 0
   stdout: `All cli-backfill tests passed.`
   mutation: insert the line `throw new Error('x');` as the first body line of `applyImplementerModelMigration`; every `--update` run inside the test exits non-zero and the suite exits 1.
   proof: ran that mutation in a scratch checkout of the finished change; `node tests/cli-backfill.test.js` exited 1; restored with `git checkout -- bin/cli.js`.
8. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; AC-D6 fails, exit 1.
   proof: ran that mutation in a scratch checkout of the finished change; the test exited 1; restored with `git checkout -- agents/task-master.md`.
9. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)"`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edit 9; the line no longer reads `ok` (the script reads only plugin.json).
10. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;console.log(a===b&&a==='0.31.141'?'version-sync: ok':'version-sync: mismatch');process.exit(a===b&&a==='0.31.141'?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 10; prints `version-sync: mismatch`, exit 1.
11. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md bin/cli.js package.json templates/persona-config.schema.json tests/default-implementer-model.test.js | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: also commit an edit to `README.md`; diff prints `< README.md`, exit 1. (AC-SCOPE-1)
   proof: scratch checkout of the finished change: `echo '# x' >> README.md && git commit -a --amend --no-edit`, then this `run:` printed `3d2 < README.md`, exit 1; reset with `git reset --hard <finished SHA>`.
12. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 12; prints `0`. (AC-SCOPE-2)
13. run: `git diff -U0 "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)" -- .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/protocol-digest.md | /usr/bin/grep -E '^[-+]' | /usr/bin/grep -vE '^(\+\+\+|---) ' | /usr/bin/grep -cvE '^[-+]<!-- antislop v[0-9]+\.[0-9]+\.[0-9]+ \| source: '`
   exit: 1
   stdout: `0`
   mutation: hand-edit one line of `.claude/agents/scribe.md` before committing; the count is 1, exit 0. (AC-SCOPE-3; exit 1 is grep -c counting no line)
   proof: scratch checkout of the finished change: `echo x >> .claude/agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed `1`, exit 0; reset as above.
14. run: `git diff --quiet "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)" -- agents hooks/scripts/reviewer-tier.sh && echo untouched-ok`
   exit: 0
   stdout: `untouched-ok`
   mutation: edit `agents/scribe.md` in the commit; prints nothing, exit 1.
   proof: scratch checkout: `echo x >> agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed nothing, exit 1; reset as above.
15. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'feat(htd-2): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
16. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-2)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
17. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one `.claude/` path unstaged at commit time; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
18. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; the writer-tier test inside validate.sh fails and it prints `validate-exit=1`.
   proof: the same mutation made criterion 8 exit 1 in a scratch checkout; validate.sh itself takes about 11 minutes and was not re-run for this probe.

## Pre-resolved context
precondition: before the version edits, `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.140`. Anything else: STOP; each version literal here becomes HEAD version + 1 and the orchestrator re-derives it.
precondition: FIRST check, for every `anchor:`, that `/usr/bin/grep -cF '<literal>' <file>` prints `1`, and that every `before:` payload appears verbatim in its file. On any mismatch, STOP and report; do not adapt the text.
tdd: yes tests/default-implementer-model.test.js
blast-radius: bin/cli.js:338, bin/cli.js:345, bin/cli.js:1270, bin/cli.js:2731, templates/persona-config.schema.json:56, tests/default-implementer-model.test.js:69
note: edit with the Edit tool. `bin/cli.js` and `tests/default-implementer-model.test.js` name gate-scanned words in their text; if a Bash heredoc is refused, use the Edit tool or STOP and report; never reword a command to get past a gate.
note: the migration code is written as the column-0 function `applyImplementerModelMigration` plus one call line, so each payload keeps its exact indentation; the behaviour is the one in docs/plans/2026-10-08-haiku-default-tier.md, Step U2.
note: criteria 1, 7 and 8 already pass at the base (they guard existing behaviour; criterion 2 counts the new checks); criteria 13, 15 and 17 pass at the base only because no `(htd-2)` commit exists yet.
note: unit order: htd-2 has no dependency and can run beside htd-1. htd-4 later sets `IMPLEMENTER_HAIKU_DEFAULT_SINCE` and flips the schema default.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff (`agents/` and `bin/cli.js` are sensitive paths, so expect an `opus` reviewer).
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: feat(htd-2): haiku is a recognised implementer tier, migration added but disabled (0.31.141) (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-2 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit htd-3

Step U3 (lead-programmer): the Escalation ladder (tier-neutral), tag vocabulary `haiku|sonnet|opus`. Suggested model: sonnet. Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U3.

## Dispatch contract

~~~~~markdown
Unit: htd-3

## Objective
`agents/orchestrator.md` states the tier-neutral Escalation ladder (the tiers from the default tier upward, two attempts each) in place of "Sonnet units escalate on first FAIL", only ladder exhaustion asks the human, and `agents/task-master.md` tags `Suggested model: haiku|sonnet|opus` from that ladder; the writer-tier test pins the new text. The default tier stays `sonnet` in this unit. Version 0.31.142, mirrors refreshed, one commit.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U3. This contract is under `## Unit htd-3` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchor: line matching `lead-programmer with that fix contract on the ratcheted tier. If task-master's`)
- `agents/task-master.md` (anchor: line matching `- **Per-unit model tag**: tag every sliced unit `)
- `tests/writer-tier-consistency.test.js` (anchor: line matching `check('AC-D7: orchestrator.md escalation ladder starts sonnet -> opus, not haiku -> sonnet', () => {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.141",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `lead-programmer with that fix contract on the ratcheted tier. If task-master's`
   before: `lead-programmer with that fix contract on the ratcheted tier. If task-master's`
   after: `lead-programmer with that fix contract on the tier the **Escalation ladder** gives. If task-master's`
2. file: `agents/orchestrator.md`
   anchor: line matching `**At the 2-FAIL cap**: stop re-dispatching lead-programmer on this unit.`
   indent: 0
   before:
```
**At the 2-FAIL cap**: stop re-dispatching lead-programmer on this unit. Surface the full two-attempt
defect history to the user (both `.fail` records and the fix-attempt commits), then ask the human how to proceed via `AskUserQuestion`. The orchestrator waits for the user's choice before proceeding:
```
   after:
```
**At the 2-FAIL cap**: a tier's second FAIL below the top of the **Escalation ladder** is not a stop: dispatch the ladder's next entry automatically, with the full defect history, and do not ask the human. At **ladder exhaustion** (the second FAIL on the ladder's top tier), stop re-dispatching lead-programmer on this unit. Surface the full
defect history to the user (every FAIL block in the `.fail` record and every fix-attempt commit), then ask the human how to proceed via `AskUserQuestion`. The orchestrator waits for the user's choice before proceeding:
```
3. file: `agents/orchestrator.md`
   anchor: line matching `diagnosis read from the latest`
   indent: 0
   before:
```
diagnosis read from the latest `.fail` record and both fix-attempt commits, plus revised acceptance
```
   after:
```
diagnosis read from the latest `.fail` record and the fix-attempt commits, plus revised acceptance
```
4. file: `agents/orchestrator.md`
   anchor: line matching `marker is written and none is deleted.`
   indent: 0
   insert-after:
```

After ladder exhaustion, a re-dispatch under (a) or (b) runs on `opus` unless the human names a tier, and any FAIL after it comes back to this section.
```
5. file: `agents/orchestrator.md`
   anchor: line matching `At the second advisory FAIL`
   indent: 0
   before:
```
in this session (there are no `.fail` records). At the second advisory FAIL
of a unit, do **not** stop for the human and do not offer the options above:
```
   after:
```
in this session (there are no `.fail` records), and apply the **Escalation
ladder** with n = that count. At ladder exhaustion, do **not** stop for the human and do not offer the options above:
```
6. file: `agents/orchestrator.md`
   anchor: line matching `reached its second advisory FAIL counts as reviewed. When you dispatch`
   before: `reached its second advisory FAIL counts as reviewed. When you dispatch`
   after: `reached ladder exhaustion counts as reviewed. When you dispatch`
7. file: `agents/orchestrator.md`
   anchor: line matching `it when absent, so lead-programmer's`
   indent: 0
   before:
```
When dispatching a unit to `lead-programmer`, check its `Suggested model:
sonnet|opus` tag and pass it as the dispatch's `model` parameter; omit
it when absent, so lead-programmer's `model: sonnet` frontmatter is the
default, not an absolute (ADR-0026 reversed the prior `haiku` default on
2026-08-25). An `opus` tag passes through identically — it
normally appears only after a unit hits the 2-FAIL cap (sonnet → FAIL →
opus → FAIL) and the human chooses option (a) to pursue a debug spec,
surfaced as a re-derived dispatch; treat it as expected when it appears. Per Claude Code's per-invocation model override (env
```
   after:
```
When dispatching a unit to `lead-programmer`, pass the tier the **Escalation
ladder** below gives as the dispatch's `model` parameter. A `Suggested model: haiku|sonnet|opus`
tag can raise that tier, never lower it. You may omit the parameter only when
that tier equals lead-programmer's frontmatter `model:`, which is the default,
not an absolute (its value and history: CONTEXT.md's **Writer tier** entry). An
`opus` dispatch after ladder exhaustion is expected when the human chose option
(a) or (b) at **At the 2-FAIL cap**. Per Claude Code's per-invocation model override (env
```
8. file: `agents/orchestrator.md`
   anchor: line matching `**Implementer-tier fail ratchet expiry.** A fail record for unit`
   indent: 0
   before:
```
**Implementer-tier fail ratchet expiry.** A fail record for unit `X` stops
disqualifying `X` from a cheaper implementer tier once a pass marker for `X`
exists and is newer than the fail record. Until then it disqualifies
unchanged; while a unit is mid-retry with no PASS yet, nothing expires.

**Sonnet units escalate on first FAIL.** A FAIL on a `sonnet` unit
re-dispatches on `opus` (not sonnet again) with the defect list; this still
counts against the 2-FAIL cap. See the ratchet-expiry rule above for when a
prior FAIL stops disqualifying.
With a fix contract (**Fix-contract re-dispatch**), that re-dispatch carries
the fix contract instead of the bare defect list.

**Check for a prior `.fail` record before ANY per-unit dispatch**, not only
right after an in-session FAIL — a fresh session has no memory of a prior
one's FAIL. If `.claude/reviewed/<task-id>.fail` exists, treat it like an
in-session FAIL: the **Implementer-tier ratchet** (CONTEXT.md's **Writer tier**
and **Implementer-tier ratchet** entries) still forbids a cheaper tier, and
include the prior defect history in the dispatch prompt. Ratchet expiry
above still applies.
```
   after:
```
**Escalation ladder.** Each implementer tier gets two attempts at a unit. The
**default tier** is the `defaultImplementerModel` value resolved above, or
lead-programmer's frontmatter `model:` when the key is absent. The ladder is
the tiers from the default tier upward, in the order `haiku`, `sonnet`, `opus`,
two entries each: from `haiku` it is `haiku`, `haiku`, `sonnet`, `sonnet`,
`opus`, `opus`; from `sonnet`, `sonnet`, `sonnet`, `opus`, `opus`; from `opus`,
`opus`, `opus`.

**Check for a prior `.fail` record before ANY per-unit dispatch**, not only
right after an in-session FAIL — a fresh session has no memory of a prior
one's FAIL. Count the unit's FAIL blocks, n: n is 0 when
`test -f .claude/reviewed/<task-id>.fail` fails, and otherwise
`grep -c '^FAIL <task-id> ' .claude/reviewed/<task-id>.fail`. Dispatch
attempt n+1 on the ladder's entry n+1. When n equals the ladder's length,
that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
cap**. The ladder depends only on n and the default tier, so a fresh session
computes the same tier the session that saw the FAIL would have; which tier
wrote a block is never needed. Fail closed: if n cannot be read (the grep
errors, or the file exists and no line matches), dispatch on `opus`. Every
re-dispatch carries the prior defect history; with a fix contract
(**Fix-contract re-dispatch**), it carries the fix contract instead of the
bare defect list. The **Implementer-tier ratchet** (CONTEXT.md's **Writer
tier** and **Implementer-tier ratchet** entries) is this rule: never a tier
cheaper than the ladder's entry.

**Implementer-tier fail ratchet expiry.** A fail record for unit `X` stops
disqualifying `X` from a cheaper implementer tier once a pass marker for `X`
exists and is newer than the fail record. Until then it disqualifies
unchanged; while a unit is mid-retry with no PASS yet, nothing expires. An
expired record counts as n = 0.
```
9. file: `agents/task-master.md`
   anchor: line matching `- **Per-unit model tag**: tag every sliced unit`
   indent: 0
   before:
```
- **Per-unit model tag**: tag every sliced unit `Suggested model:
  sonnet|opus`. Tagging is **reactive**, not predictive: `sonnet` is
  the default for every unit, and a unit you judge security-sensitive,
  structural, or otherwise hard-judgment still starts on sonnet — you never
  pre-emptively tag a unit `opus`, no matter how risky it looks.
  `opus` is reachable only two ways, both reactive to something
  already on record, never to your own risk judgment: (a) check
  `.claude/reviewed/<task-id>.fail` before tagging any unit — a prior FAIL is
  durable evidence it needed more judgment than first estimated;
  never tag that unit `sonnet`
  (unless a `.pass` marker newer than the `.fail` record exists for that unit,
  indicating it was subsequently fixed and independently verified); or (b) the
  orchestrator's own first-FAIL escalation (a sonnet unit's first FAIL routes its
  retry to opus) — that mechanism lives in `agents/orchestrator.md`, not here,
  and is unchanged by this rule.
```
   after:
```
- **Per-unit model tag**: tag every sliced unit `Suggested model:
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `sonnet` is
  the default for every unit, and a unit you judge security-sensitive,
  structural, or otherwise hard-judgment still starts on the default tier —
  you never pre-emptively tag a unit above it, no matter how risky it looks.
  A higher tag is reachable only one way, reactive to something already on
  record, never to your own risk judgment: check
  `.claude/reviewed/<task-id>.fail` before tagging any unit, count its FAIL
  blocks, and tag the tier the orchestrator's **Escalation ladder** gives for
  that count (`agents/orchestrator.md`); a `.pass` marker newer than the
  `.fail` record means the count is 0, and at ladder exhaustion you tag
  `opus`. The orchestrator recomputes the ladder at dispatch, and your tag can
  raise its tier but never lower it.
```
10. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `check('AC-D7: orchestrator.md escalation ladder starts sonnet -> opus, not haiku -> sonnet', () => {`
   indent: 0
   before:
```
check('AC-D7: orchestrator.md escalation ladder starts sonnet -> opus, not haiku -> sonnet', () => {
  const text = read('agents/orchestrator.md');
  assert.ok(
    /Sonnet units escalate on first FAIL/.test(text),
    'orchestrator.md does not state the sonnet-first-FAIL escalation rule',
  );
  assert.ok(
    !/Haiku units escalate on first FAIL/.test(text),
    'orchestrator.md still states the stale haiku-first-FAIL escalation rule',
  );
});
```
   after:
```
check('AC-D7: orchestrator.md states the two-attempts-per-tier Escalation ladder, not a first-FAIL escalation', () => {
  const text = read('agents/orchestrator.md');
  assert.ok(/\*\*Escalation ladder\.\*\* Each implementer tier gets two attempts/.test(text), 'orchestrator.md does not state the Escalation ladder rule');
  assert.ok(!/Sonnet units escalate on first FAIL/.test(text), 'orchestrator.md still states the stale sonnet-first-FAIL escalation rule');
  assert.ok(!/Haiku units escalate on first FAIL/.test(text), 'orchestrator.md still states the stale haiku-first-FAIL escalation rule');
});
```
11. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from`
   before: `// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from`
   indent: 0
   after:
```
check('AC-D8b: the haiku-default ADR pins its forward rule, and ADR-0026 names it', () => {
  const dir = path.join(REPO_ROOT, 'docs', 'adr');
  const hits = fs.readdirSync(dir).filter((f) => /^\d{4}-implementer-tier-haiku-default\.md$/.test(f));
  assert.strictEqual(hits.length, 1, `expected exactly one *-implementer-tier-haiku-default.md ADR, got ${hits.length}`);
  const text = fs.readFileSync(path.join(dir, hits[0]), 'utf8');
  for (const s of ['Amends: ADR-0026', '≥60 units dispatched under the `haiku` default', 'fail-rate ≤ 0.35',
    'escalation-rate ≤ 0.15', 'exhaustion-rate ≤ 0.02', 'tripwire']) {
    assert.ok(text.includes(s), `${hits[0]} does not state ${s}`);
  }
  assert.ok(/^Superseded-in-part-by: ADR-\d{4} /m.test(read('docs/adr/0026-writer-tier-reversed-to-sonnet.md')), 'ADR-0026 lacks its Superseded-in-part-by line');
});

// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from
```
12. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `check('AC-D9: agents/orchestrator.md never names haiku as a default, tag value, or ladder rung', () => {`
   indent: 0
   before:
```
check('AC-D9: agents/orchestrator.md never names haiku as a default, tag value, or ladder rung', () => {
  const text = stripWhitespace(read('agents/orchestrator.md'));
  assert.ok(!text.includes(stripWhitespace('`model: haiku` frontmatter is the')), 'orchestrator.md still claims haiku frontmatter is the default');
  assert.ok(!text.includes(stripWhitespace('haiku|sonnet|opus')), 'orchestrator.md still lists haiku in the Suggested model tag vocabulary');
  assert.ok(!text.includes(stripWhitespace('haiku → FAIL')), 'orchestrator.md still states a haiku-first escalation ladder rung');
  assert.ok(!text.includes(stripWhitespace('never dispatch on `haiku`')), 'orchestrator.md still contains the vacuous never-dispatch-on-haiku clause');
});
```
   after:
```
check('AC-D9: agents/orchestrator.md states the three-tier vocabulary and no stale default or ladder', () => {
  const text = stripWhitespace(read('agents/orchestrator.md'));
  assert.ok(!text.includes(stripWhitespace('`model: sonnet` frontmatter is the')), 'orchestrator.md still claims sonnet frontmatter is the default');
  assert.ok(text.includes(stripWhitespace('`Suggested model: haiku|sonnet|opus`')), 'orchestrator.md does not list the haiku|sonnet|opus Suggested model vocabulary');
  assert.ok(!text.includes(stripWhitespace('sonnet → FAIL → opus → FAIL')), 'orchestrator.md still states the ADR-0026 sonnet-first cap path');
  assert.ok(!text.includes(stripWhitespace('never dispatch on `haiku`')), 'orchestrator.md still contains the vacuous never-dispatch-on-haiku clause');
});
```
13. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `hasAll('agents/orchestrator.md', ['At the 2-FAIL cap', 'Sonnet units escalate on first FAIL',`
   before: `  hasAll('agents/orchestrator.md', ['At the 2-FAIL cap', 'Sonnet units escalate on first FAIL',`
   after: `  hasAll('agents/orchestrator.md', ['At the 2-FAIL cap', '**Escalation ladder.**',`
14. file: `.claude-plugin/plugin.json` (version 0.31.142)
   anchor: line matching `"version": "0.31.141",`
   before: `  "version": "0.31.141",`
   after: `  "version": "0.31.142",`
15. file: `package.json` (version 0.31.142)
   anchor: line matching `"version": "0.31.141",`
   before: `  "version": "0.31.141",`
   after: `  "version": "0.31.142",`
16. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Escalation ladder: two attempts per implementer tier (htd-3, 0.31.142).** `agents/orchestrator.md`: "Sonnet units escalate on first FAIL" is replaced by the Escalation ladder (the tiers from the default tier upward, two attempts each); a tier's second FAIL moves the unit up automatically and only ladder exhaustion asks the human; the tier is recomputed from the FAIL-block count, and an unreadable count dispatches `opus`. `agents/task-master.md`: `Suggested model: haiku|sonnet|opus`, tagged from the ladder. The default tier is unchanged (`sonnet`).
```
17. command: `node bin/cli.js --update`
   expect: 0
18. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
19. command: `git add agents/orchestrator.md agents/task-master.md tests/writer-tier-consistency.test.js .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(htd-3): Escalation ladder, two attempts per implementer tier (0.31.142) (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
20. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/orchestrator.md` paragraph that starts with the bold label for the `defaultImplementerModel` config precedence (`tests/default-implementer-model.test.js` pins two of its sentences)
- `agents/orchestrator.md` line for `fable` is excluded for `task-master`, and its "Reviewer gate model selection" section
- `hooks/scripts/reviewer-tier.sh`
- `agents/lead-programmer.md`
- `agents/spec-master.md`
- `CONTEXT.md`
- `templates/`
- `adapters/`

## Acceptance criteria
1. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: skip edit 8; exit 1.
2. run: `F=agents/orchestrator.md; for p in '\*\*Escalation ladder\.\*\* Each implementer tier gets two attempts at a unit\.' 'from .haiku. it is .haiku., .haiku., .sonnet., .sonnet., .opus., .opus.;' 'dispatch on .opus.\. Every re-dispatch carries' 'An expired record counts as n = 0\.' 'After ladder exhaustion, a re-dispatch under \(a\) or \(b\) runs on .opus. unless'; do tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oE -- "$p" | wc -l; done | /usr/bin/grep -c '^1$'`
   exit: 0
   stdout: `5`
   mutation: skip edit 8; prints `1`.
3. run: `F=agents/orchestrator.md; for p in 'Sonnet units escalate on first FAIL' 'on the ratcheted tier' 'full two-attempt' 'At the second advisory FAIL' 'reached its second advisory FAIL' 'both fix-attempt commits'; do tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | /usr/bin/grep -c '^0$'`
   exit: 0
   stdout: `6`
   mutation: skip edit 1; prints `5`.
4. run: `F=agents/task-master.md; printf '%s %s %s\n' "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'Suggested model: haiku|sonnet|opus' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'first-FAIL escalation' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'never lower it' | wc -l)"`
   exit: 0
   stdout: `1 0 1`
   mutation: skip edit 9; prints `0 1 0`.
5. run: `node -e "const t=require('fs').readFileSync('agents/task-master.md','utf8');const b=String.fromCharCode(96);const ok=t.includes(b+'sonnet'+b+' is\n  the default for every unit');console.log(ok?'linebreak-ok':'linebreak-bad');process.exit(ok?0:1)"`
   exit: 0
   stdout: `linebreak-ok`
   mutation: join the two lines with a single space in `agents/task-master.md`; prints `linebreak-bad`, exit 1.
   proof: ran `sed -i 'N;s/ is\n  the default for every unit/ is the default for every unit/;P;D' agents/task-master.md` in a scratch checkout of the finished change, then this `run:` printed `linebreak-bad`, exit 1; restored with `git checkout -- agents/task-master.md`.
6. run: `F=agents/orchestrator.md; printf '%s %s\n' "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oE -- 'tier.s second FAIL below the top of the \*\*Escalation ladder\*\* is not a stop' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'Unresolved advisory findings' | wc -l)"`
   exit: 0
   stdout: `1 1`
   mutation: skip edit 2; prints `0 1`.
7. run: `node tests/default-implementer-model.test.js`
   exit: 0
   stdout: `All default-implementer-model checks passed.`
   mutation: change `Only an **absent** key` to `Only a missing key` in `agents/orchestrator.md`; the precedence check fails, exit 1.
   proof: ran `sed -i 's/Only an \*\*absent\*\* key/Only a missing key/' agents/orchestrator.md` in a scratch checkout of the finished change; this `run:` exited 1; restored with `git checkout -- agents/orchestrator.md`.
8. run: `printf '%s %s\n' "$(tr '\n' ' ' < .claude/agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oF -- '**Escalation ladder.** Each implementer tier gets two attempts' | wc -l)" "$(tr '\n' ' ' < .claude/agents/task-master.md | tr -s ' ' | /usr/bin/grep -oF -- 'Suggested model: haiku|sonnet|opus' | wc -l)"`
   exit: 0
   stdout: `1 1`
   mutation: skip edit 17; prints `0 0`.
9. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)"`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edit 14; the line no longer reads `ok` (the script reads only plugin.json).
10. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;console.log(a===b&&a==='0.31.142'?'version-sync: ok':'version-sync: mismatch');process.exit(a===b&&a==='0.31.142'?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 15; prints `version-sync: mismatch`, exit 1.
11. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md agents/task-master.md package.json tests/writer-tier-consistency.test.js | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: skip edit 16; exit 1. (AC-SCOPE-1)
12. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 17; prints `0`. (AC-SCOPE-2)
13. run: `git diff -U0 "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)" -- .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/protocol-digest.md ':(exclude).claude/agents/orchestrator.md' ':(exclude).claude/agents/task-master.md' | /usr/bin/grep -E '^[-+]' | /usr/bin/grep -vE '^(\+\+\+|---) ' | /usr/bin/grep -cvE '^[-+]<!-- antislop v[0-9]+\.[0-9]+\.[0-9]+ \| source: '`
   exit: 1
   stdout: `0`
   mutation: hand-edit one line of `.claude/agents/scribe.md` before committing; the count is 1, exit 0. (AC-SCOPE-3; exit 1 is grep -c counting no line)
   proof: scratch checkout of the finished change: `echo x >> .claude/agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed `1`, exit 0; reset with `git reset --hard <finished SHA>`.
14. run: `git diff --quiet "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)" -- agents/lead-programmer.md agents/spec-master.md agents/scribe.md CONTEXT.md templates adapters hooks/scripts/reviewer-tier.sh && echo untouched-ok`
   exit: 0
   stdout: `untouched-ok`
   mutation: edit `agents/scribe.md` in the commit; prints nothing, exit 1.
   proof: scratch checkout: `echo x >> agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed nothing, exit 1; reset as above.
15. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'feat(htd-3): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
16. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-3)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
17. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified after the commit; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
18. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; the writer-tier test inside validate.sh fails and it prints `validate-exit=1`.
   proof: the same mutation made criterion 1 exit 1 in a scratch checkout; validate.sh itself takes about 11 minutes and was not re-run for this probe.

## Pre-resolved context
precondition: before the version edits, `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.141`. Anything else: STOP; each version literal here becomes HEAD version + 1 and the orchestrator re-derives it.
precondition: htd-1 and htd-2 have landed: `ls docs/adr | /usr/bin/grep -c 'implementer-tier-haiku-default'` prints `1`, and `git log --format=%H -F --grep='(htd-2)' | wc -l` prints `1`. Anything else: STOP and report.
precondition: FIRST check, for every `anchor:`, that `/usr/bin/grep -cF '<literal>' <file>` prints `1`, and that every `before:` payload appears verbatim in its file. On any mismatch, STOP and report; do not adapt the text.
tdd: yes tests/writer-tier-consistency.test.js
blast-radius: agents/orchestrator.md:200, agents/orchestrator.md:361, agents/orchestrator.md:429, agents/orchestrator.md:456, agents/task-master.md:104, tests/writer-tier-consistency.test.js:73, tests/default-implementer-model.test.js:92
note: edit the persona files and the test with the Edit tool; the orchestrator text names gate-scanned words. If a Bash heredoc is refused, use the Edit tool or STOP and report; never reword a command to get past a gate.
note: edit 9 must keep `` `sonnet` is `` at the end of its second line and `  the default for every unit` at the start of the third (the writer-tier test pins that line break); the next unit changes only the word `sonnet` there.
note: the orchestrator's persona body is loaded at session start, so the new routing takes effect from the next session after htd-3 and htd-4 land.
note: criteria 1, 5 and 7 already pass at the base (they guard existing behaviour; criteria 2, 3, 4, 6 and 8 are the ones that fail until the edits land); criteria 13, 15 and 17 pass at the base only because no `(htd-3)` commit exists yet.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff (`agents/` is a sensitive path, so expect an `opus` reviewer).
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: feat(htd-3): Escalation ladder, two attempts per implementer tier (0.31.142) (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-3 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit htd-5

Step U5 (lead-programmer): shared protocol states the per-tier cap. Suggested model: sonnet. Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U5.

## Dispatch contract

~~~~~markdown
Unit: htd-5

## Objective
The shared protocol's cap paragraph reads "Cap at 2 FAILs per tier" (a tier's second FAIL moves the unit up the Escalation ladder, only ladder exhaustion reaches the human), its three other mentions of the cap say the same, `commands/start-feature-team.md` and the label quote in `agents/spec-master.md` agree, and the mirrors that inline the paragraph are refreshed. Version 0.31.143, one commit. The codex and cursor ports are not edited.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U5. This contract is under `## Unit htd-5` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `templates/persona-protocol.md` (anchor: line matching `**Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the`)
- `agents/spec-master.md` (anchor: line matching `cap ("Cap at 2 FAILs per unit")`)
- `commands/start-feature-team.md` (anchor: line matching `2-FAIL cap: on a second FAIL for the same unit, stop re-delegating and`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.142",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `templates/persona-protocol.md`
   anchor: line matching `means the reviewer returned an advisory PASS, or the unit reached its second`
   indent: 0
   before:
```
means the reviewer returned an advisory PASS, or the unit reached its second
advisory FAIL and the orchestrator listed the remaining findings and moved
```
   after:
```
means the reviewer returned an advisory PASS, or the unit reached ladder
exhaustion on advisory FAILs and the orchestrator listed the remaining findings and moved
```
2. file: `templates/persona-protocol.md`
   anchor: line matching `the 2-FAIL cap (a unit stops being re-dispatched to `
   indent: 0
   before:
```
the 2-FAIL cap (a unit stops being re-dispatched to `lead-programmer` after
its second `.fail` record) counts `.fail` records only, unchanged. When the reviewer
```
   after:
```
the 2-FAIL cap (two FAILs per implementer tier, after which the unit moves up
the orchestrator's Escalation ladder, stopping only at ladder exhaustion) counts `.fail` records only, unchanged. When the reviewer
```
3. file: `templates/persona-protocol.md`
   anchor: line matching `2-FAIL cap (a unit stops being re-dispatched to `lead-programmer` after its`
   indent: 0
   before:
```
2-FAIL cap (a unit stops being re-dispatched to `lead-programmer` after its
second `.fail` record) counts `.fail` records only, unchanged.
```
   after:
```
2-FAIL cap (two FAILs per implementer tier, after which the unit moves up the
orchestrator's Escalation ladder, stopping only at ladder exhaustion) counts `.fail` records only, unchanged.
```
4. file: `templates/persona-protocol.md`
   anchor: line matching `**Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the`
   indent: 0
   before:
```
**Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the
orchestrator (or team lead) stops re-dispatching `lead-programmer` — it
surfaces the full defect history across both attempts to the human and asks
how to proceed, rather than spawning a third fix attempt on its own
authority. Which choices the human is offered, and what each one does, are
defined in one place only — the orchestrator's own "At the 2-FAIL cap"
section — and are pointed at from here rather than restated, so a later
amendment cannot leave two copies disagreeing. A unit that fails twice
usually means the plan itself has a gap, not that one more automated pass
will close it.
```
   after:
```
**Cap at 2 FAILs per tier.** Each implementer tier gets two attempts at a
unit. A unit's second FAIL on one tier hands it, automatically, to the next
tier of the orchestrator's **Escalation ladder** (the tiers from the default
tier upward: `haiku`, `sonnet`, `opus`), with the full defect history; no
human stop happens there. Only the second FAIL on the ladder's top tier,
ladder exhaustion, stops re-dispatch: the orchestrator (or team lead) then
surfaces the full defect history to the human and asks how to proceed,
rather than spawning a further attempt on its own authority. Which choices
the human is offered, and what each one does, are defined in one place
only — the orchestrator's own "At the 2-FAIL cap" section — and are pointed
at from here rather than restated, so a later amendment cannot leave two
copies disagreeing. A unit that exhausts the ladder usually means the plan
itself has a gap, not that one more automated pass will close it.
```
5. file: `agents/spec-master.md`
   anchor: line matching `cap ("Cap at 2 FAILs per unit")`
   before: `  cap ("Cap at 2 FAILs per unit") — a focused diagnostic artifact, never a`
   after: `  cap ("Cap at 2 FAILs per tier") — a focused diagnostic artifact, never a`
6. file: `commands/start-feature-team.md`
   anchor: line matching `2-FAIL cap: on a second FAIL for the same unit, stop re-delegating and`
   indent: 0
   before:
```
2-FAIL cap: on a second FAIL for the same unit, stop re-delegating and
surface the full defect history to the user instead. "Done" is enforced
```
   after:
```
2-FAIL cap, which is per implementer tier: a tier's second FAIL moves the unit up
the orchestrator's Escalation ladder, and only at ladder exhaustion do you stop
re-delegating and surface the full defect history to the user instead. "Done" is enforced
```
7. file: `.claude-plugin/plugin.json` (version 0.31.143)
   anchor: line matching `"version": "0.31.142",`
   before: `  "version": "0.31.142",`
   after: `  "version": "0.31.143",`
8. file: `package.json` (version 0.31.143)
   anchor: line matching `"version": "0.31.142",`
   before: `  "version": "0.31.142",`
   after: `  "version": "0.31.143",`
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Shared protocol: the 2-FAIL cap is per implementer tier (htd-5, 0.31.143).** `templates/persona-protocol.md`: "Cap at 2 FAILs per tier" — a tier's second FAIL moves the unit up the Escalation ladder; only ladder exhaustion reaches the human. Same wording in `commands/start-feature-team.md`; `agents/spec-master.md` quotes the new label. The codex and cursor ports keep their per-unit cap (no per-dispatch model routing there).
```
10. command: `node bin/cli.js --update`
   expect: 0
11. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
12. command: `git add templates/persona-protocol.md agents/spec-master.md commands/start-feature-team.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(htd-5): shared protocol states the 2-FAIL cap per implementer tier (0.31.143) (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
13. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `adapters/` (the codex and cursor ports have no per-dispatch model routing, so their cap paragraph stays correct)
- `templates/persona-protocol-slim.md`
- `templates/protocol-digest.md`
- `agents/orchestrator.md`
- `templates/persona-protocol.md` section heading lines (every line that starts with `## `; the adapter parity test probes headings)

## Acceptance criteria
1. run: `F=templates/persona-protocol.md; printf '%s %s %s %s %s\n' "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- '**Cap at 2 FAILs per tier.**' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'Cap at 2 FAILs per unit' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oE -- 'second .\.fail. record' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'reached its second advisory FAIL' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'stopping only at ladder exhaustion' | wc -l)"`
   exit: 0
   stdout: `1 0 0 0 2`
   mutation: skip edit 3; prints `1 0 1 0 1`.
2. run: `/usr/bin/grep -l 'Cap at 2 FAILs per tier' .claude/agents/*.md | sort | tr '\n' ' '`
   exit: 0
   stdout: `.claude/agents/lead-programmer.md .claude/agents/orchestrator.md .claude/agents/spec-master.md`
   mutation: skip edit 10; prints nothing, so the stdout check fails.
3. run: `/usr/bin/grep -c 'Cap at 2 FAILs per unit' .claude/agents/*.md | /usr/bin/grep -vc ':0$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 10; prints `3`, exit 0.
4. run: `printf '%s %s\n' "$(tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | /usr/bin/grep -oF -- '("Cap at 2 FAILs per tier")' | wc -l)" "$(tr '\n' ' ' < commands/start-feature-team.md | tr -s ' ' | /usr/bin/grep -oF -- 'only at ladder exhaustion do you stop' | wc -l)"`
   exit: 0
   stdout: `1 1`
   mutation: skip edits 5 and 6; prints `0 0`.
5. run: `git diff --quiet "$(git log --format=%H -F --grep='(htd-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-5)' | head -1)" -- adapters templates/persona-protocol-slim.md templates/protocol-digest.md agents/orchestrator.md agents/scribe.md && echo untouched-ok`
   exit: 0
   stdout: `untouched-ok`
   mutation: edit `agents/scribe.md` in the commit; prints nothing, exit 1.
   proof: scratch checkout of the finished change: `echo x >> agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed nothing, exit 1; reset with `git reset --hard <finished SHA>`.
6. run: `node tests/adapter-protocol-parity.test.js`
   exit: 0
   stdout: `All adapter-protocol-parity checks passed.`
   mutation: change every `Continuing after a FAIL verdict` in `adapters/codex/agents-md-fragment.md` to `X`; the parity test fails, exit 1.
   proof: ran `sed -i 's/Continuing after a FAIL verdict/X/g' adapters/codex/agents-md-fragment.md` in a scratch checkout of the finished change; this `run:` exited 1; restored with `git checkout -- adapters/codex/agents-md-fragment.md`.
7. run: `node tests/writer-tier-consistency.test.js && node tests/cli-backfill.test.js`
   exit: 0
   stdout: `All cli-backfill tests passed.`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; AC-D6 fails, exit 1.
   proof: ran that mutation in a scratch checkout of the finished change; the writer-tier test exited 1; restored with `git checkout -- agents/task-master.md`.
8. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(htd-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-5)' | head -1)"`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edit 7; the line no longer reads `ok` (the script reads only plugin.json).
9. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;console.log(a===b&&a==='0.31.143'?'version-sync: ok':'version-sync: mismatch');process.exit(a===b&&a==='0.31.143'?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 8; prints `version-sync: mismatch`, exit 1.
10. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(htd-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-5)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md agents/spec-master.md commands/start-feature-team.md package.json templates/persona-protocol.md | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: skip edit 9; exit 1. (AC-SCOPE-1)
11. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-5)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 10; prints `0`. (AC-SCOPE-2)
12. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-5)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'feat(htd-5): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
13. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-5)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
14. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified after the commit; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
15. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of `.claude/agents/orchestrator.md` so it differs from the template; the mirror-parity checks in validate.sh fail and it prints `validate-exit=1`.
   proof: not re-run (validate.sh takes about 11 minutes); the parity checks are the mirror-versus-template comparisons validate.sh runs for every persona.

## Pre-resolved context
precondition: before the version edits, `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.142`. Anything else: STOP; each version literal here becomes HEAD version + 1 and the orchestrator re-derives it. (htd-5 is dispatched before htd-4 because htd-4 is held; htd-4's version is re-derived after htd-5 lands.)
precondition: htd-3 has landed: `git log --format=%H -F --grep='(htd-3)' | wc -l` prints `1`. Anything else: STOP and report.
precondition: FIRST check, for every `anchor:`, that `/usr/bin/grep -cF '<literal>' <file>` prints `1`, and that every `before:` payload appears verbatim in its file. On any mismatch, STOP and report; do not adapt the text.
tdd: no prose-only edit; the checks are greps, the adapter parity test and the mirror parity inside validate.sh
blast-radius: templates/persona-protocol.md:290, templates/persona-protocol.md:373, templates/persona-protocol.md:526, templates/persona-protocol.md:704, agents/spec-master.md:238, commands/start-feature-team.md:46, adapters/codex/agents-md-fragment.md:160
note: the mirrors that inline the cap paragraph change only through `node bin/cli.js --update` (criterion 2 lists them); never edit a `.claude/` file by hand.
note: criteria 6 and 7 already pass at the base (they guard the unchanged ports and existing tests); criteria 12 and 14 pass at the base only because no `(htd-5)` commit exists yet. The other criteria fail at the base.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff (`agents/` and `templates/` are sensitive paths, so expect an `opus` reviewer).
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: feat(htd-5): shared protocol states the 2-FAIL cap per implementer tier (0.31.143) (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-5 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit htd-4

Step U4 (lead-programmer): the cutover (frontmatter `haiku`, migration on, cutover timestamp). Suggested model: sonnet. Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U4.

## Dispatch contract

~~~~~markdown
Unit: htd-4

## Objective
The cutover: `agents/lead-programmer.md` frontmatter reads `model: haiku`, the schema default and the README row read `haiku`, `IMPLEMENTER_HAIKU_DEFAULT_SINCE` is `'0.31.144'`, the fresh-scaffold skeleton in `bin/cli.js` ships the literal `'haiku'` (never a call to `implementerFrontmatterDefault()`, so the scaffold check can still fail on drift), so `--update` moves this repo's own `"sonnet"` config value to `"haiku"`, and `agents/orchestrator.md` carries exactly one `**Haiku-default cutover: <timestamp>.**` line. Version 0.31.144, mirrors refreshed, one commit.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U4. This contract is under `## Unit htd-4` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `agents/lead-programmer.md` (anchor: line matching `model: sonnet`)
- `agents/task-master.md` (anchor: line matching `Tagging is **reactive**, not predictive:`)
- `agents/orchestrator.md` (anchor: line matching `cheaper than the ladder's entry.`)
- `bin/cli.js` (anchor: line matching `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;`)
- `templates/persona-config.schema.json` (anchor: line matching `      "default": "sonnet",`)
- `README.md` (anchor: line matching `Always | Executes an approved plan TDD-first`)
- `tests/writer-tier-consistency.test.js` (anchor: line matching `check('AC-D5: agents/lead-programmer.md frontmatter reads model: sonnet', () => {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.143",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites (the project config's `defaultImplementerModel` moves to `"haiku"` in this commit); never edit them by hand

## Ordered edits
1. file: `agents/lead-programmer.md`
   anchor: line matching `model: sonnet`
   before: `model: sonnet`
   after: `model: haiku`
2. file: `agents/task-master.md`
   anchor: line matching `Tagging is **reactive**, not predictive:`
   indent: 0
   before:
```
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `sonnet` is
```
   after:
```
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `haiku` is
```
3. file: `agents/orchestrator.md`
   anchor: line matching `cheaper than the ladder's entry.`
   indent: 0
   insert-after:
```

**Haiku-default cutover: <T0>.** FAIL blocks whose header timestamp is
earlier than this were written under ADR-0026's `sonnet` default, and the
count alone cannot say which tier wrote them. Fail closed: a unit with any
such block uses the ladder that starts at `sonnet` (`sonnet`, `sonnet`,
`opus`, `opus`), whatever the default tier.
```
4. file: `bin/cli.js`
   anchor: line matching `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;`
   before: `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;`
   after: `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = '0.31.144';`
5. file: `bin/cli.js`
   anchor: line matching `Matches agents/lead-programmer.md's`
   indent: 0
   before:
```
lead-programmer.md's `model: sonnet` frontmatter today
```
   after:
```
lead-programmer.md's `model: haiku` frontmatter today
```
6. file: `bin/cli.js`
   anchor: line matching `defaultImplementerModel: 'sonnet',`
   before: `      defaultImplementerModel: 'sonnet',`
   after: `      defaultImplementerModel: 'haiku',`
7. file: `templates/persona-config.schema.json`
   anchor: line matching `      "default": "sonnet",`
   before: `      "default": "sonnet",`
   after: `      "default": "haiku",`
8. file: `README.md`
   anchor: line matching `Always | Executes an approved plan TDD-first`
   indent: 0
   before:
```
| `lead-programmer` | sonnet | Always |
```
   after:
```
| `lead-programmer` | haiku | Always |
```
9. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `check('AC-D5: agents/lead-programmer.md frontmatter reads model: sonnet', () => {`
   indent: 0
   before:
```
check('AC-D5: agents/lead-programmer.md frontmatter reads model: sonnet', () => {
  assert.strictEqual(frontmatterModel(read('agents/lead-programmer.md')), 'sonnet');
});

check('AC-D5: .claude/agents/lead-programmer.md mirror reads model: sonnet', () => {
  assert.strictEqual(frontmatterModel(read('.claude/agents/lead-programmer.md')), 'sonnet');
});

check('AC-D5: README.md persona table lists lead-programmer as sonnet', () => {
  const text = read('README.md');
  const row = text.split('\n').find((l) => l.includes('`lead-programmer`'));
  assert.ok(row, 'lead-programmer row not found in README.md');
  assert.ok(/\|\s*sonnet\s*\|/.test(row), `expected sonnet in README row, got: ${row}`);
});

check('AC-D5: agents/task-master.md default tag is sonnet, not haiku', () => {
  const text = read('agents/task-master.md');
  assert.ok(text.includes('`sonnet` is\n  the default for every unit'), 'task-master.md does not state sonnet as the default tag');
  assert.ok(!text.includes('`haiku` is\n  the default'), 'task-master.md still states haiku as the default tag');
});
```
   after:
```
check('AC-D5: agents/lead-programmer.md frontmatter reads model: haiku', () => {
  assert.strictEqual(frontmatterModel(read('agents/lead-programmer.md')), 'haiku');
});

check('AC-D5: .claude/agents/lead-programmer.md mirror reads model: haiku', () => {
  assert.strictEqual(frontmatterModel(read('.claude/agents/lead-programmer.md')), 'haiku');
});

check('AC-D5: README.md persona table lists lead-programmer as haiku', () => {
  const text = read('README.md');
  const row = text.split('\n').find((l) => l.includes('`lead-programmer`'));
  assert.ok(row, 'lead-programmer row not found in README.md');
  assert.ok(/\|\s*haiku\s*\|/.test(row), `expected haiku in README row, got: ${row}`);
});

check('AC-D5: agents/task-master.md default tag is haiku, not sonnet', () => {
  const text = read('agents/task-master.md');
  assert.ok(text.includes('`haiku` is\n  the default for every unit'), 'task-master.md does not state haiku as the default tag');
  assert.ok(!text.includes('`sonnet` is\n  the default'), 'task-master.md still states sonnet as the default tag');
});
```
10. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from`
   before: `// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from`
   indent: 0
   after:
```
check('AC-D10: this repo\'s own defaultImplementerModel resolves to the lead-programmer frontmatter default', () => {
  const cli = require(path.join(REPO_ROOT, 'bin', 'cli.js'));
  const config = JSON.parse(read(path.join('.claude', 'persona-config.json')));
  const fm = frontmatterModel(read('agents/lead-programmer.md'));
  assert.strictEqual(cli.resolveDefaultImplementerModel(config, fm), fm);
});

check('AC-D11: orchestrator.md states exactly one Haiku-default cutover timestamp', () => {
  const hits = read('agents/orchestrator.md').match(/\*\*Haiku-default cutover: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\.\*\*/g) || [];
  assert.strictEqual(hits.length, 1, `expected one cutover line, got ${hits.length}`);
});

// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from
```
11. file: `.claude-plugin/plugin.json` (version 0.31.144)
   anchor: line matching `"version": "0.31.143",`
   before: `  "version": "0.31.143",`
   after: `  "version": "0.31.144",`
12. file: `package.json` (version 0.31.144)
   anchor: line matching `"version": "0.31.143",`
   before: `  "version": "0.31.143",`
   after: `  "version": "0.31.144",`
13. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Implementer tier defaults to haiku (htd-4, 0.31.144).** `agents/lead-programmer.md` frontmatter is `model: haiku` and the `defaultImplementerModel` schema default is `"haiku"` (ADR 0040, amending ADR-0026). `--update` migrates a recorded `"sonnet"` from before this version to `"haiku"` once and says so; set it back to keep a `sonnet`-first ladder. `agents/orchestrator.md` records the haiku-default cutover: FAIL blocks older than it start the unit's ladder at `sonnet`.
```
14. command: `node bin/cli.js --update`
   expect: 0
   stdout: `migrated to "haiku"`
15. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
16. command: `git add agents/lead-programmer.md agents/task-master.md agents/orchestrator.md bin/cli.js templates/persona-config.schema.json README.md tests/writer-tier-consistency.test.js .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(htd-4): implementer tier defaults to haiku, cutover recorded (0.31.144) (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
17. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/scribe.md`
- `hooks/scripts/reviewer-tier.sh`
- `adapters/`
- `CONTEXT.md`
- `agents/orchestrator.md` text written by htd-3, apart from the one insertion in edit 3

## Acceptance criteria
1. run: `printf '%s %s %s\n' "$(sed -n '1,12p' agents/lead-programmer.md | /usr/bin/grep -c '^model: haiku$')" "$(sed -n '1,12p' .claude/agents/lead-programmer.md | /usr/bin/grep -c '^model: haiku$')" "$(sed -n '1,12p' agents/scribe.md | /usr/bin/grep -c '^model: haiku$')"`
   exit: 0
   stdout: `1 1 1`
   mutation: skip edit 1; prints `0 0 1`.
2. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: skip edit 1; exit 1.
3. run: `node tests/default-implementer-model.test.js && node tests/cli-backfill.test.js`
   exit: 0
   stdout: `All cli-backfill tests passed.`
   mutation: skip edit 6; `node tests/default-implementer-model.test.js` exits 1 and its fresh-scaffold check prints `fresh-install skeleton must ship defaultImplementerModel: "haiku", got "sonnet"`.
4. run: `printf '%s %s\n' "$(/usr/bin/grep -cE '^\*\*Haiku-default cutover: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\.\*\*' agents/orchestrator.md)" "$(/usr/bin/grep -cE '^\*\*Haiku-default cutover: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\.\*\*' .claude/agents/orchestrator.md)"`
   exit: 0
   stdout: `1 1`
   mutation: skip edit 3; prints `0 0`.
5. run: `L=$(/usr/bin/grep -oE 'Haiku-default cutover: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' agents/orchestrator.md | /usr/bin/grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z'); D=$(TZ=UTC git log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1"); test -n "$L" && test "$L" = "$D" && echo cutover-matches-baseline`
   exit: 0
   stdout: `cutover-matches-baseline`
   mutation: skip edit 3; prints nothing, exit 1.
6. run: `node -e "const c=require('./bin/cli.js');const ok=c.IMPLEMENTER_HAIKU_DEFAULT_SINCE===require('./package.json').version&&require('./templates/persona-config.schema.json').properties.defaultImplementerModel.default==='haiku';console.log(ok?'cutover-const-ok':'cutover-const-bad');process.exit(ok?0:1)"`
   exit: 0
   stdout: `cutover-const-ok`
   mutation: skip edit 4; prints `cutover-const-bad`, exit 1.
7. run: `node tests/writer-tier-consistency.test.js | /usr/bin/grep -c '^OK   AC-D10'`
   exit: 0
   stdout: `1`
   mutation: skip edit 14; the `--update` does not migrate the repo's config, AC-D10 fails, and this prints `0`, exit 1.
8. run: `/usr/bin/grep -c '| .lead-programmer. | haiku | Always |' README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; prints `0`, exit 1.
9. run: `node -e "const t=require('fs').readFileSync('agents/task-master.md','utf8');const b=String.fromCharCode(96);const ok=t.includes(b+'haiku'+b+' is\n  the default for every unit');console.log(ok?'tm-haiku-ok':'tm-haiku-bad');process.exit(ok?0:1)"`
   exit: 0
   stdout: `tm-haiku-ok`
   mutation: skip edit 2; prints `tm-haiku-bad`, exit 1.
10. run: `printf '%s %s %s\n' "$(/usr/bin/grep -cE "agents/lead-programmer.md's .model: haiku. frontmatter today" bin/cli.js)" "$(/usr/bin/grep -cE "agents/lead-programmer.md's .model: sonnet. frontmatter today" bin/cli.js)" "$(/usr/bin/grep -c "^      defaultImplementerModel: 'haiku',$" bin/cli.js)"`
   exit: 0
   stdout: `1 0 1`
   mutation: skip edit 5; prints `0 1 1`.
11. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)"`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edit 11; the line no longer reads `ok` (the script reads only plugin.json).
12. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;console.log(a===b&&a==='0.31.144'?'version-sync: ok':'version-sync: mismatch');process.exit(a===b&&a==='0.31.144'?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 12; prints `version-sync: mismatch`, exit 1.
13. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md README.md agents/lead-programmer.md agents/orchestrator.md agents/task-master.md bin/cli.js package.json templates/persona-config.schema.json tests/writer-tier-consistency.test.js | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: skip edit 13; exit 1. (AC-SCOPE-1)
14. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 14; prints `0`. (AC-SCOPE-2)
15. run: `git diff -U0 "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)" -- .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/protocol-digest.md ':(exclude).claude/agents/lead-programmer.md' ':(exclude).claude/agents/task-master.md' ':(exclude).claude/agents/orchestrator.md' | /usr/bin/grep -E '^[-+]' | /usr/bin/grep -vE '^(\+\+\+|---) ' | /usr/bin/grep -cvE '^[-+]<!-- antislop v[0-9]+\.[0-9]+\.[0-9]+ \| source: '`
   exit: 1
   stdout: `0`
   mutation: hand-edit one line of `.claude/agents/scribe.md` before committing; the count is 1, exit 0. (AC-SCOPE-3; exit 1 is grep -c counting no line)
   proof: scratch checkout of the finished change: `echo x >> .claude/agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed `1`, exit 0; reset with `git reset --hard <finished SHA>`.
16. run: `git diff --quiet "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)" -- adapters hooks/scripts/reviewer-tier.sh agents/scribe.md agents/spec-master.md CONTEXT.md && echo untouched-ok`
   exit: 0
   stdout: `untouched-ok`
   mutation: edit `agents/scribe.md` in the commit; prints nothing, exit 1.
   proof: scratch checkout: `echo x >> agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed nothing, exit 1; reset as above.
17. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'feat(htd-4): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
18. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-4)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
19. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified after the commit; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
20. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; the writer-tier test inside validate.sh fails and it prints `validate-exit=1`.
   proof: the same mutation made criterion 2 exit 1 in a scratch checkout; validate.sh itself takes about 11 minutes and was not re-run for this probe.

## Pre-resolved context
orchestrator-fill: the token `<T0>` in edit 3 is the only unresolved literal in this contract. Before dispatch the orchestrator replaces it with the output of `TZ=UTC git log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd HEAD` (HEAD is the baseline commit). If the dispatch still contains `<T0>`: STOP and report a spec gap. Criterion 5 re-derives the same value from the unit's own baseline, so a wrong literal fails it.
precondition: before the version edits, `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.143`. Anything else: STOP; each version literal here (and the quoted `'0.31.144'` in edit 4 and the CHANGELOG entry) becomes HEAD version + 1 and the orchestrator re-derives it.
precondition: htd-2, htd-3 and htd-5 have landed: `git log --format=%H -F --grep='(htd-2)' | wc -l`, `git log --format=%H -F --grep='(htd-3)' | wc -l` and `git log --format=%H -F --grep='(htd-5)' | wc -l` each print `1`. Anything else: STOP and report.
precondition: FIRST check, for every `anchor:`, that `/usr/bin/grep -cF '<literal>' <file>` prints `1`, and that every `before:` payload appears verbatim in its file. On any mismatch, STOP and report; do not adapt the text.
tdd: yes tests/writer-tier-consistency.test.js
blast-radius: bin/cli.js:2551, bin/cli.js:2558, agents/lead-programmer.md:4, agents/task-master.md:105, agents/orchestrator.md:456, bin/cli.js:338, templates/persona-config.schema.json:57, README.md:53, tests/writer-tier-consistency.test.js:37
note: edit `tests/writer-tier-consistency.test.js` with the Edit tool, never a Bash heredoc: its new text names the project config file and a Bash command spelling that name is refused by the harness integrity gate. If an edit is refused, STOP and report; never split or reword the name to get past the scan.
note: the repo config is changed only by edit 14 (`node bin/cli.js --update`); no agent writes it by hand. The reviewer reads the committed config with the Read tool (never Bash) and expects the line `"defaultImplementerModel": "haiku"`.
note: criteria 2 and 3 already pass at the base (they run existing tests of the old literals); criteria 15, 17 and 19 pass at the base only because no `(htd-4)` commit exists yet. The other criteria fail at the base.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff (`agents/` and `bin/cli.js` are sensitive paths, so expect an `opus` reviewer).
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: feat(htd-4): implementer tier defaults to haiku, cutover recorded (0.31.144) (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-4 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit htd-6

Step U6 (lead-programmer): glossary for the ladder; AC-D5's CONTEXT literal. Suggested model: sonnet. Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U6.

## Dispatch contract

~~~~~markdown
Unit: htd-6

## Objective
`CONTEXT.md` and `docs/harness-glossary.md` state the haiku default, the two-attempts-per-tier ratchet, the **Escalation ladder** and **ladder exhaustion** (two new entries), and the writer-tier test's CONTEXT check is rewritten to match. No version-stamped path is touched, so there is no version bump. One commit.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U6. This contract is under `## Unit htd-6` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `CONTEXT.md` (anchor: line matching `**Implementer-tier ratchet**:`)
- `docs/harness-glossary.md` (anchor: line matching `**FAIL routing (post-reviewer)**:`)
- `tests/writer-tier-consistency.test.js` (anchor: line matching `check('AC-D5: CONTEXT.md Implementer-tier ratchet reads sonnet→opus on re-attempt, not haiku→sonnet', () => {`)

## Ordered edits
1. file: `CONTEXT.md`
   anchor: line matching `**Implementer-tier ratchet**:`
   indent: 0
   before:
```
**Implementer-tier ratchet**:
the `.fail` disqualifier on lead-programmer
  tier scaling. A unit's `.claude/reviewed/<task-id>.fail` record (from a
  prior FAIL verdict) permanently removes access to cheaper tiers, forcing
  `sonnet`→`opus` on re-attempt. This ratchet expires on a
```
   after:
```
**Implementer-tier ratchet**:
the `.fail` disqualifier on lead-programmer
  tier scaling. A unit's `.claude/reviewed/<task-id>.fail` record (from prior
  FAIL verdicts) forbids any tier cheaper than the [[Escalation ladder]] gives
  for its FAIL-block count: two attempts per tier, `haiku`→`sonnet`→`opus`. This ratchet expires on a
```
2. file: `CONTEXT.md`
   anchor: line matching `**Writer tier**:`
   indent: 0
   before:
```
**Writer tier**:
the lead-programmer's (implementer's) model tier, defaulting to
  `sonnet` as of ADR-0026 (reversing ADR-0010's earlier `haiku` default).
```
   after:
```
**Writer tier**:
the lead-programmer's (implementer's) model tier, defaulting to
  `haiku` as of ADR-0040 (amending ADR-0026's `sonnet`, which had reversed ADR-0010's `haiku`).
```
3. file: `CONTEXT.md`
   anchor: line matching `  applies when a unit fails: a `
   indent: 0
   before:
```
  applies when a unit fails: a `.fail` record forces `opus` on re-attempt.
  See [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).

**Suggested model vocabulary**:
```
   after:
```
  applies when a unit fails: each tier gets two attempts before the next (the [[Escalation ladder]]).
  See [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).

**Escalation ladder**:
(ADR-0040, 2026-10-08) — the order of implementer tiers a unit moves
  through on FAIL: the tiers from the default tier upward (`haiku`, `sonnet`,
  `opus`), two attempts each. The next tier is a function of the unit's
  FAIL-block count alone, so a session with no memory of earlier FAILs
  computes the same tier. A unit with a FAIL block older than the
  haiku-default cutover starts its ladder at `sonnet`. See [[ladder
  exhaustion]] and [[Implementer-tier ratchet]].
_Avoid_: handoff (names the cutoff handoff), first-FAIL escalation (the ADR-0026 rule this replaced)

**ladder exhaustion**:
(ADR-0040, 2026-10-08) — a unit's second FAIL on the top tier of its
  [[Escalation ladder]]: the only point at which the orchestrator stops
  re-dispatching and asks the human, offering the options of the 2-FAIL cap.
  A lower tier's second FAIL moves the unit up automatically.
_Avoid_: "the 2-FAIL cap" for this stop alone (the 2-FAIL cap is per tier)

**Suggested model vocabulary**:
```
4. file: `CONTEXT.md`
   anchor: line matching `(units item06-3, 2026-09-25) — the canonical allowed-value list for the`
   indent: 0
   before:
```
(units item06-3, 2026-09-25) — the canonical allowed-value list for the
  `Suggested model:` tag emitted by `task-master` during dispatch (and historically
  by `spec-master` before ADR-0009's reversal). Current vocabulary:
  `Suggested model: sonnet|opus`. Pinned as a cross-file invariant by
  tests/writer-tier-consistency.test.js AC-D9 (agreement guard between
  `agents/orchestrator.md` and `agents/task-master.md`). Historically included
  `haiku` (pre-ADR-0026); see [[Writer tier]] and [[Implementer-tier ratchet]]
  for the escalation semantics those tags trigger.
```
   after:
```
(units item06-3, 2026-09-25) — the canonical allowed-value list for the
  `Suggested model:` tag emitted by `task-master` during dispatch (and historically
  by `spec-master` before ADR-0009's reversal). Current vocabulary:
  `Suggested model: haiku|sonnet|opus`. Pinned as a cross-file invariant by
  tests/writer-tier-consistency.test.js AC-D9 (agreement guard between
  `agents/orchestrator.md` and `agents/task-master.md`). Historically included
  `haiku` before ADR-0026 and was `sonnet|opus` under it; see [[Writer tier]] and [[Implementer-tier ratchet]]
  for the escalation semantics those tags trigger.
```
5. file: `CONTEXT.md`
   anchor: line matching `(unit item18, 2026-09-25) — a persona-config field (`
   indent: 0
   before:
```
(unit item18, 2026-09-25) — a persona-config field (`defaultImplementerModel: "sonnet"|"opus"`)
```
   after:
```
(unit item18, 2026-09-25) — a persona-config field (`defaultImplementerModel: "haiku"|"sonnet"|"opus"`)
```
6. file: `CONTEXT.md`
   anchor: line matching `  [[Writer tier]], [ADR-0010](docs/adr/0010-haiku-as-default-implementer-model.md),`
   indent: 0
   before:
```
  [[Writer tier]], [ADR-0010](docs/adr/0010-haiku-as-default-implementer-model.md),
  [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).

**Reviewer-gate ratchet**:
```
   after:
```
  [[Writer tier]], [ADR-0010](docs/adr/0010-haiku-as-default-implementer-model.md),
  [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md). A recorded `"sonnet"` from before the haiku default shipped is migrated once to `"haiku"` by `--update` (ADR-0040).

**Reviewer-gate ratchet**:
```
7. file: `CONTEXT.md`
   anchor: line matching `**review gating off** (everyday name: *gateless mode*):`
   indent: 0
   before:
```
**review gating off** (everyday name: *gateless mode*):
(unit rgo-5, 2026-09-29) — the project state where `reviewGating.mode` in
  `.claude/persona-config.json` is exactly `off`. Reviewer verdicts are
  advisory, and the review-enforcement and human-escalation gates are inert;
  the protection gates (`protected-paths.sh`, `harness-integrity-gate.sh` and
  config-drift detection, `reviewed-path-gate.sh`, the reviewer-dispatch
  identity and privileged-name guards, and the stop-gate test+lint check)
  stay armed. Absent or junk values mean `enforce`. At a unit's second
  advisory FAIL the orchestrator reports `Unresolved advisory findings` and
```
   after:
```
**review gating off** (everyday name: *gateless mode*):
(unit rgo-5, 2026-09-29) — the project state where `reviewGating.mode` in
  `.claude/persona-config.json` is exactly `off`. Reviewer verdicts are
  advisory, and the review-enforcement and human-escalation gates are inert;
  the protection gates (`protected-paths.sh`, `harness-integrity-gate.sh` and
  config-drift detection, `reviewed-path-gate.sh`, the reviewer-dispatch
  identity and privileged-name guards, and the stop-gate test+lint check)
  stay armed. Absent or junk values mean `enforce`. At a unit's [[ladder exhaustion]]
  on advisory FAILs the orchestrator reports `Unresolved advisory findings` and
```
8. file: `CONTEXT.md`
   anchor: line matching `**parked unit**:`
   indent: 0
   before:
```
**parked unit**:
(unit gh404, 2026-08-16, Step 4 of the ceremony-reduction plan) — option (c)
  at the 2-FAIL cap (see [[FAIL routing (post-reviewer)]]): the orchestrator
  stops re-dispatching `lead-programmer` on the unit and moves on, leaving
  the two-attempt defect history standing. No marker is written and none is
```
   after:
```
**parked unit**:
(unit gh404, 2026-08-16, Step 4 of the ceremony-reduction plan) — option (c)
  at [[ladder exhaustion]] (see [[FAIL routing (post-reviewer)]]): the orchestrator
  stops re-dispatching `lead-programmer` on the unit and moves on, leaving
  the full defect history standing. No marker is written and none is
```
9. file: `docs/harness-glossary.md`
   anchor: line matching `**FAIL routing (post-reviewer)**:`
   indent: 0
   before:
```
**FAIL routing (post-reviewer)**:
normal FAIL routes the defect list to
  `lead-programmer` (unchanged). At the 2-FAIL cap, the orchestrator surfaces
  the two-attempt defect history and asks the human (via `AskUserQuestion`) how
```
   after:
```
**FAIL routing (post-reviewer)**:
normal FAIL routes the defect list to
  `lead-programmer` (unchanged); a tier's second FAIL moves the unit up the
  Escalation ladder. At ladder exhaustion, the orchestrator surfaces
  the full defect history and asks the human (via `AskUserQuestion`) how
```
10. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `check('AC-D5: CONTEXT.md Implementer-tier ratchet reads sonnet→opus on re-attempt, not haiku→sonnet', () => {`
   indent: 0
   before:
```
check('AC-D5: CONTEXT.md Implementer-tier ratchet reads sonnet→opus on re-attempt, not haiku→sonnet', () => {
  const text = read('CONTEXT.md');
  assert.ok(text.includes('`sonnet`→`opus` on re-attempt'), 'CONTEXT.md does not state the sonnet→opus re-attempt ratchet');
  assert.ok(!text.includes('`haiku`→`sonnet` on re-attempt'), 'CONTEXT.md still states the stale haiku→sonnet re-attempt ratchet');
});
```
   after:
```
check('AC-D5: CONTEXT.md Implementer-tier ratchet reads two attempts per tier, haiku→sonnet→opus', () => {
  const text = read('CONTEXT.md');
  assert.ok(text.includes('two attempts per tier, `haiku`→`sonnet`→`opus`'), 'CONTEXT.md does not state the two-attempts-per-tier ratchet');
  assert.ok(!text.includes('`sonnet`→`opus` on re-attempt'), 'CONTEXT.md still states the stale sonnet→opus re-attempt ratchet');
});
```
11. command: `git add CONTEXT.md docs/harness-glossary.md tests/writer-tier-consistency.test.js && git commit -m "docs(htd-6): glossary states the Escalation ladder and ladder exhaustion (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
12. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/`
- `templates/`
- `docs/adr/`
- `CONTEXT.md` and `docs/harness-glossary.md` entries other than the ones named in the edits above
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump in this unit)

## Acceptance criteria
1. run: `printf '%s %s\n' "$(/usr/bin/grep -c '^\*\*Escalation ladder\*\*:$' CONTEXT.md)" "$(/usr/bin/grep -c '^\*\*ladder exhaustion\*\*:$' CONTEXT.md)"`
   exit: 0
   stdout: `1 1`
   mutation: skip edit 3; prints `0 0`.
2. run: `F=CONTEXT.md; printf '%s %s %s %s %s\n' "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oE -- 'two attempts per tier, .haiku.→.sonnet.→.opus.' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oE -- 'forcing .sonnet.→.opus. on re-attempt' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'Suggested model: haiku|sonnet|opus' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- '"haiku"|"sonnet"|"opus"' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'the two-attempt defect history' | wc -l)"`
   exit: 0
   stdout: `1 0 1 1 0`
   mutation: skip edit 1; prints `0 1 1 1 0`.
3. run: `F=docs/harness-glossary.md; printf '%s %s\n' "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'the two-attempt defect history' | wc -l)" "$(tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- 'At ladder exhaustion, the orchestrator surfaces' | wc -l)"`
   exit: 0
   stdout: `0 1`
   mutation: skip edit 9; prints `1 0`.
4. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: skip edit 1; exit 1.
5. run: `node tests/context-glossary-links.test.js && node tests/ubiquitous-language.test.js`
   exit: 0
   stdout: `passes all 4 structural/distinguishability checks`
   mutation: skip edit 3; the `[[Escalation ladder]]` and `[[ladder exhaustion]]` links in the other entries have no target and the link test exits 1.
6. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-6)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `CONTEXT.md docs/harness-glossary.md tests/writer-tier-consistency.test.js`
   mutation: also commit an edit to `README.md`; the list gains `README.md`.
   proof: scratch checkout of the finished change: `echo '# x' >> README.md && git commit -a --amend --no-edit`, then this `run:` printed a list starting with `CONTEXT.md` and containing `README.md`; reset with `git reset --hard <finished SHA>`.
7. run: `git diff --quiet "$(git log --format=%H -F --grep='(htd-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-6)' | head -1)" -- agents templates .claude-plugin package.json CHANGELOG.md .claude docs/adr && echo no-stamp-ok`
   exit: 0
   stdout: `no-stamp-ok`
   mutation: edit `agents/scribe.md` in the commit; prints nothing, exit 1.
   proof: scratch checkout: `echo x >> agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed nothing, exit 1; reset as above.
8. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-6)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'docs(htd-6): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
9. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-6)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
10. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified after the commit; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
11. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; the writer-tier test inside validate.sh fails and it prints `validate-exit=1`.
   proof: the same mutation made criterion 4 exit 1 in a scratch checkout; validate.sh itself takes about 11 minutes and was not re-run for this probe.

## Pre-resolved context
precondition: htd-4 and htd-5 have landed: `git log --format=%H -F --grep='(htd-4)' | wc -l` and `git log --format=%H -F --grep='(htd-5)' | wc -l` each print `1`. Anything else: STOP and report.
precondition: the haiku-default ADR number is 0040: `ls docs/adr | /usr/bin/grep -c '^0040-implementer-tier-haiku-default.md$'` prints `1`. Anything else: STOP; every `ADR-0040` and `ADR 0040` literal in this contract becomes the actual number and the orchestrator re-derives it.
precondition: FIRST check, for every `anchor:`, that `/usr/bin/grep -cF '<literal>' <file>` prints `1`, and that every `before:` payload appears verbatim in its file. On any mismatch, STOP and report; do not adapt the text.
tdd: yes tests/writer-tier-consistency.test.js
blast-radius: CONTEXT.md:341, CONTEXT.md:353, CONTEXT.md:361, CONTEXT.md:372, CONTEXT.md:175, CONTEXT.md:1186, docs/harness-glossary.md:1713, tests/writer-tier-consistency.test.js:58
note: keep the words "handoff" and "first-FAIL escalation" out of the new entries except inside the `_Avoid_` lines as written (the first names the cutoff handoff, the second the ADR-0026 rule this replaced).
note: this unit is a lead-programmer unit because it edits a test; `CONTEXT.md` and `docs/harness-glossary.md` are glossary files and the test couples one of them to AC-D5.
note: criteria 4 and 5 already pass at the base (4 runs a test of the old CONTEXT text, 5 guards links and drift); criteria 8 and 10 pass at the base only because no `(htd-6)` commit exists yet. The other criteria fail at the base.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff.
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: docs(htd-6): glossary states the Escalation ladder and ladder exhaustion (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-6 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit htd-7

Step U7 (lead-programmer): the exporter infers `haiku` from the cutover. Suggested model: sonnet. Plan: `docs/plans/2026-10-08-haiku-default-tier.md` U7.

## Dispatch contract

~~~~~markdown
Unit: htd-7

## Objective
`scripts/unit-outcomes.js` infers `haiku` as the era implementer tier for any unit whose terminal timestamp is at or after the haiku-default cutover timestamp written in `agents/orchestrator.md` (and still `sonnet` before it), so the pre-registered forward rule stays measurable; a new fixture and test pin it. No version-stamped path is touched, so there is no version bump. One commit.

## Retrieval
Plan file (no per-unit issue exists: `gh issue create` for the unit issues was denied by the permission classifier): `docs/plans/2026-10-08-haiku-default-tier.md`, Step U7. This contract is under `## Unit htd-7` in `docs/plans/2026-10-08-haiku-default-tier-contracts.md`. Umbrella spec issue (PRD view): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict between them is a spec gap: STOP.

## Affected files
- `scripts/unit-outcomes.js` (anchor: line matching `function eraTier(ts) {`)
- `tests/unit-outcomes.test.js` (anchor: line matching `check('era reviewer empty', () => {`)
- `tests/fixtures/unit-outcomes/markers/fx-era-4.pass` (new file; anchor: whole file, created by edit 2)

## Ordered edits
1. file: `scripts/unit-outcomes.js`
   anchor: line matching `function eraTier(ts) {`
   indent: 0
   before:
```
// Implementer tier by era when no transcript meta exists (ADR-0010, ADR-0026).
function eraTier(ts) {
  const t = Date.parse(ts);
  return t >= Date.parse('2026-08-02') && t < Date.parse('2026-08-25') ? 'haiku' : 'sonnet';
}
```
   after:
```
// The haiku-default cutover (ADR-0040), read from the orchestrator's own
// literal so the two cannot drift; null if the line is absent.
const HAIKU_CUTOVER = (() => {
  try {
    const text = fs.readFileSync(path.join(__dirname, '..', 'agents', 'orchestrator.md'), 'utf8');
    const m = text.match(/\*\*Haiku-default cutover: (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\.\*\*/);
    return m ? m[1] : null;
  } catch (_) {
    return null;
  }
})();

// Implementer tier by era when no transcript meta exists (ADR-0010, ADR-0026, ADR-0040).
// Only the default tier of the era: a laddered unit's later tiers are not inferred.
function eraTier(ts) {
  const t = Date.parse(ts);
  if (HAIKU_CUTOVER && t >= Date.parse(HAIKU_CUTOVER)) return 'haiku';
  return t >= Date.parse('2026-08-02') && t < Date.parse('2026-08-25') ? 'haiku' : 'sonnet';
}
```
2. command: `printf '%s\n' 'PASS fx-era-4 2026-12-01T10:00:00Z commit: none criteria: fixture' > tests/fixtures/unit-outcomes/markers/fx-era-4.pass`
   expect: 0
3. file: `tests/unit-outcomes.test.js`
   anchor: line matching `check('era reviewer empty', () => {`
   before: `check('era reviewer empty', () => {`
   indent: 0
   after:
```
check('era from the haiku-default cutover haiku', () => {
  const later = rows(scratch.dir, '2027-01-01T00:00:00Z').map;
  assert.deepStrictEqual(later['fx-era-4'].implementer_tiers, [{ tier: 'haiku', source: 'era-inferred' }]);
  assert.deepStrictEqual(later['fx-era-3'].implementer_tiers, [{ tier: 'sonnet', source: 'era-inferred' }]);
});

check('era reviewer empty', () => {
```
4. command: `git add scripts/unit-outcomes.js tests/unit-outcomes.test.js tests/fixtures/unit-outcomes/markers/fx-era-4.pass && git commit -m "feat(htd-7): exporter infers haiku from the haiku-default cutover (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
5. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/`
- `scripts/unit-outcomes.js` outside the `eraTier` block and the constant above it (the G3 gate code and everything else)
- `tests/fixtures/unit-outcomes/markers/fx-era-1.pass`, `fx-era-2.pass` and `fx-era-3.pass`
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump in this unit)

## Acceptance criteria
1. run: `node tests/unit-outcomes.test.js | tail -1`
   exit: 0
   stdout: `All unit-outcomes checks passed.`
   mutation: skip edit 2; the new check cannot find `fx-era-4` and the suite exits 1.
2. run: `node tests/unit-outcomes.test.js | /usr/bin/grep -c '^OK   era from the haiku-default cutover haiku$'`
   exit: 0
   stdout: `1`
   mutation: delete the line `if (HAIKU_CUTOVER && t >= Date.parse(HAIKU_CUTOVER)) return 'haiku';` from `scripts/unit-outcomes.js`; the check fails and this prints `0`, exit 1.
   proof: ran `sed -i "/if (HAIKU_CUTOVER/d" scripts/unit-outcomes.js` in a scratch checkout of the finished change; this `run:` printed `0`, exit 1; restored with `git checkout -- scripts/unit-outcomes.js`.
3. run: `node -e "const t=require('fs').readFileSync('agents/orchestrator.md','utf8');const ok=/\*\*Haiku-default cutover: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\.\*\*/.test(t);console.log(ok?'cutover-literal-ok':'cutover-literal-missing');process.exit(ok?0:1)"`
   exit: 0
   stdout: `cutover-literal-ok`
   mutation: remove the cutover line from `agents/orchestrator.md`; prints `cutover-literal-missing`, exit 1.
   proof: this criterion also passes at the base (htd-4 wrote the literal); it only reads a file this unit must not change.
4. run: `/usr/bin/grep -c '2026-08-25' scripts/unit-outcomes.js`
   exit: 0
   stdout: `2`
   mutation: delete the old era line `return t >= Date.parse('2026-08-02') && ...` from `eraTier`; prints `1`.
   proof: also `2` at the base: the old era boundaries stay.
5. run: `git diff --name-only "$(git log --format=%H -F --grep='(htd-7)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-7)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `scripts/unit-outcomes.js tests/fixtures/unit-outcomes/markers/fx-era-4.pass tests/unit-outcomes.test.js`
   mutation: also commit an edit to `README.md`; the list gains `README.md`.
   proof: scratch checkout of the finished change: `echo '# x' >> README.md && git commit -a --amend --no-edit`, then this `run:` printed a list containing `README.md`; reset with `git reset --hard <finished SHA>`.
6. run: `git diff --quiet "$(git log --format=%H -F --grep='(htd-7)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-7)' | head -1)" -- agents templates .claude-plugin package.json CHANGELOG.md .claude && echo no-stamp-ok`
   exit: 0
   stdout: `no-stamp-ok`
   mutation: edit `agents/scribe.md` in the commit; prints nothing, exit 1.
   proof: scratch checkout: `echo x >> agents/scribe.md && git commit -a --amend --no-edit`, then this `run:` printed nothing, exit 1; reset as above.
7. run: `git log --format=%s "$(git log --format=%H -F --grep='(htd-7)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-7)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: scratch checkout: `git commit --amend -m 'feat(htd-7): no issue suffix' -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`, then this `run:` printed `1`, exit 0; reset as above.
8. run: `git log --format=%B "$(git log --format=%H -F --grep='(htd-7)' | tail -1)~1".."$(git log --format=%H -F --grep='(htd-7)' | head -1)" | /usr/bin/grep -cxF 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer from the commit; prints `0`, exit 1.
   proof: scratch checkout: `git commit --amend -m "$(git log -1 --format=%s)"`, then this `run:` printed `0`, exit 1; reset as above.
9. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified after the commit; prints `1`.
   proof: scratch checkout: `echo x >> README.md` with no commit, then this `run:` printed `1`; reset as above.
10. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add the phrase `looks mechanical` to `agents/task-master.md`; the writer-tier test inside validate.sh fails and it prints `validate-exit=1`.
   proof: the same mutation makes `node tests/writer-tier-consistency.test.js` exit 1; validate.sh itself takes about 11 minutes and was not re-run for this probe.

## Pre-resolved context
precondition: htd-4 has landed: `git log --format=%H -F --grep='(htd-4)' | wc -l` prints `1`, and criterion 3's `run:` already exits 0. Anything else: STOP and report.
precondition: the haiku-default ADR number is 0040: `ls docs/adr | /usr/bin/grep -c '^0040-implementer-tier-haiku-default.md$'` prints `1`. Anything else: STOP; the two `ADR-0040` literals in edit 1 become the actual number and the orchestrator re-derives it.
precondition: FIRST check, for every `anchor:`, that `/usr/bin/grep -cF '<literal>' <file>` prints `1`, and that every `before:` payload appears verbatim in its file. On any mismatch, STOP and report; do not adapt the text.
tdd: yes tests/unit-outcomes.test.js
blast-radius: scripts/unit-outcomes.js:102, scripts/unit-outcomes.js:111, tests/unit-outcomes.test.js:297
note: `fs` and `path` are already required at the top of `scripts/unit-outcomes.js` (lines 7 and 9), so edit 1 adds no `require`.
note: the existing runs use the cutoff 2026-09-15, which excludes `fx-era-4` (its timestamp is 2026-12-01), so no existing assertion changes. If an existing assertion fails after the edits, STOP and report a spec gap.
note: edit 2 writes a fixture marker with a shell redirect; if a hook refuses the command, create the same one-line file (plus a trailing newline) with the Write tool, or STOP and report. Never reword the command to get past a gate.
note: criteria 1, 3 and 4 already pass at the base (1 guards the existing suite, 3 reads the literal htd-4 wrote, 4 guards the old era boundaries); criteria 7 and 9 pass at the base only because no `(htd-7)` commit exists yet. Criteria 2, 5, 6 and 8 fail at the base.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's actual diff.
explorer: not needed (provenance: grep and read by task-master at 7fba8f9; no explorer spawned).
commit-message: feat(htd-7): exporter infers haiku from the haiku-default cutover (#529)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
```
unit: htd-7 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs and subjects>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

