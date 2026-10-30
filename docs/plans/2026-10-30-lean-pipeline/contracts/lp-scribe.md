Unit: lp-scribe

## Objective
Record the lean-pipeline vocabulary (plan step "U12 lp-scribe", Clarifications line "Terminology"). One scribe run. This repo's `knowledgeWrites` is `apply`, and this contract names the only knowledge files it edits.
- New entries in `CONTEXT.md`: **five-field contract**, **release**, **needs-human note**, and **task-master** (no entry exists today, so it is added already marked retired).
- A `Retired (0.32.0): ...` line goes directly below the heading of eight entries: four in `CONTEXT.md` (**Escalation packet**, **ESCALATE-TO-HUMAN**, **`.escalated` marker**, **escalation card**) and four in `docs/harness-glossary.md` (**review-join stamp**, **decision-gate denial**, **The human-decision gate**, **frozen family table**). Nothing is deleted.
- Two stale definitions are corrected: **fix contract** (task-master no longer writes it) and **version-stamp discipline** (now per release, stated first in the entry). The **Persona** entry drops task-master from its optional list.
- lp-vsr (0.31.227) left two more per-commit statements: the harness glossary's **per-commit semantics** entry gets a `Retired (0.31.227)` line (glossary edit 15), and row 25 of `docs/trust-model.md` is rewritten to the per-release rule (doc edit 1).
- The **release** entry names **bumping commit** as a synonym, the word `agents/lead-programmer.md`, `agents/scribe.md` and `skills/version-stamp-discipline/SKILL.md` use. That one glossary line is smaller than editing three sources plus their mirrors, so those files are not edited.
- One ADR, 0044, records the decision drafted in the plan (Decisions, "ADR candidate").

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md` (Decisions D1, D3, D4, D5, D6; Risks R1, R2; step "U12 lp-scribe"). Contract file: `docs/plans/2026-10-30-lean-pipeline/contracts/lp-scribe.md`, the contract of record. Dispatch after lp-orch has PASSed. Implementer tier: haiku if `node .claude/bin/contract-guard.js docs/plans/2026-10-30-lean-pipeline/contracts/lp-scribe.md --unit=lp-scribe --shape=scribe` prints `contract-guard: haiku`, otherwise sonnet.

## Glossary edits
Every payload is written with this contract's 3-space indent: strip exactly 3 leading spaces from each non-empty payload line.
1. file: `CONTEXT.md`
   heading: `**Persona**:`
   placement: replace the one line below with the text below
   indent: 3
   before:
   ~~~~
     personas (spec-master, task-master, scribe, reviewer, researcher,
   ~~~~
   text:
   ~~~~
     personas (spec-master, scribe, reviewer, researcher,
   ~~~~
2. file: `CONTEXT.md`
   heading: `**task-master**:`
   placement: new entry; insert the text, then one blank line, directly above the line `**Version-stamped file**:`
   indent: 3
   text:
   ~~~~
   **task-master**:
   Retired (0.32.0): the persona was deleted (plan 2026-10-30-lean-pipeline).
     It sliced a finalized spec into units and wrote their nine-element
     contracts and fix contracts. spec-master now writes one
     [[five-field contract]] per unit, and the orchestrator writes the
     [[fix contract]]. The name stays a legacy `--personas` and
     `personaSelection` token that maps to spec-master.
   ~~~~
3. file: `CONTEXT.md`
   heading: `**version-stamp discipline**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Superseded (0.31.227): the rule is per [[release]] (plan 2026-10-30-lean-pipeline, constitution P3 v1.2.0). A content commit needs no bump; `version-stamp-check.sh` checks only that a bumping commit adds a CHANGELOG line naming its version and that the version never decreases. The per-commit rule below, including the within-range check, is history.
   ~~~~
4. file: `CONTEXT.md`
   heading: `**release**:`
   placement: new entry; insert the text, then one blank line, directly above the line `**whole version**:`
   indent: 3
   text:
   ~~~~
   **release**:
   (plan 2026-10-30-lean-pipeline, constitution P3 v1.2.0) — one commit that
     bumps `version` in `.claude-plugin/plugin.json` and `package.json` and adds
     a CHANGELOG line naming the new version (from 0.32.0 on, a
     `## [<version>] - <date>` heading). Content commits between releases carry
     no bump and may add `[Unreleased]` bullets. The version never decreases.
     Projects running `--update` receive content changes at releases only.
     Also called a bumping commit (the wording of the lead-programmer and
     scribe personas and the version-stamp-discipline skill).
   _Avoid_: per-commit bump
   ~~~~
5. file: `CONTEXT.md`
   heading: `**five-field contract**:`
   placement: new entry; insert the text, then one blank line, directly above the line `**dispatch checkpoint**:`
   indent: 3
   text:
   ~~~~
   **five-field contract**:
   (plan 2026-10-30-lean-pipeline, 0.32.0) — the dispatch contract a writer
     receives: `Unit: <id>` on line 1, then `## Objective`, `## Affected files`,
     `## Do NOT touch` and `## Acceptance criteria` (numbered `run:` lines), at
     most 3,072 bytes, kept in its [[contract file]]. spec-master writes one per
     unit; after a FAIL the orchestrator writes the [[fix contract]] in the same
     shape. An optional `## Ordered edits` section is kept for a haiku writer.
   _Avoid_: nine-element contract (the form task-master wrote)
   ~~~~
6. file: `CONTEXT.md`
   heading: `**Escalation packet**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): no packet is written any more; a [[needs-human note]] replaces it (ADR-0044).
   ~~~~
7. file: `CONTEXT.md`
   heading: `**ESCALATE-TO-HUMAN**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): the reviewer has three verdicts, and a [[needs-human note]] replaces this one (ADR-0044).
   ~~~~
8. file: `CONTEXT.md`
   heading: `**needs-human note**:`
   placement: new entry; insert the text, then one blank line, directly above the line `**per-clone review state**:`
   indent: 3
   text:
   ~~~~
   **needs-human note**:
   (plan 2026-10-30-lean-pipeline, 0.32.0) — an optional line
     `needs-human: <one line>` that the reviewer adds to its verdict when a
     decision belongs to the user. It does not change the verdict (PASS, FAIL
     or INSUFFICIENT-CONTEXT). The orchestrator relays it with AskUserQuestion
     and continues on the answer. No marker, packet, card or gate is written.
     It replaces [[ESCALATE-TO-HUMAN]] (ADR-0044).
   _Avoid_: escalation, fourth verdict
   ~~~~
9. file: `CONTEXT.md`
   heading: `` **`.escalated` marker**: ``
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): no reviewer writes this marker any more; see [[needs-human note]] (ADR-0044).
   ~~~~
10. file: `CONTEXT.md`
   heading: `**escalation card**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): it went with the `.escalated` marker; see [[needs-human note]] (ADR-0044).
   ~~~~
11. file: `docs/harness-glossary.md`
   heading: `**fix contract**:`
   placement: replace the whole entry (its heading line to the line ending `bullet **Fix contract**.`) with the text below
   indent: 3
   before:
   ~~~~
   **fix contract**:
   (unit rgh-h10, 2026-10-07) — a nine-element dispatch contract that task-master,
     if present, writes for the same `Unit:` id from the latest FAIL block: literal
     edits, the original criteria plus one criterion per defect,
     `fix-of: <FAIL header timestamp>`, and `diagnosis: none`. task-master does the
     diagnosis itself; if it cannot determine the cause, it writes no fix contract
     and reports a spec gap. The orchestrator dispatches task-master between the FAIL
     verdict and the fix dispatch (`agents/orchestrator.md` **Fix-contract
     re-dispatch**), and lead-programmer applies [[contract precedence]] to it
     (`agents/lead-programmer.md` **Fix turns**). Defined in `agents/task-master.md`
     bullet **Fix contract**.
   ~~~~
   text:
   ~~~~
   **fix contract**:
   (unit rgh-h10, 2026-10-07; rewritten plan 2026-10-30-lean-pipeline, 0.32.0)
     — a [[five-field contract]] for the same `Unit:` id that the orchestrator
     writes after a FAIL, from the latest FAIL block. Its first `## Objective`
     line is `fix-of: <FAIL header timestamp>`, and it keeps the original
     criteria plus one criterion per defect. lead-programmer applies
     [[contract precedence]] to it. Before 0.32.0, task-master wrote it as a
     nine-element contract.
   ~~~~
12. file: `docs/harness-glossary.md`
   heading: `**review-join stamp**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): the stop gate keeps one pending-review flag check and no longer writes or reads these stamps (ADR-0044).
   ~~~~
13. file: `docs/harness-glossary.md`
   heading: `**decision-gate denial**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): `human-decision-gate.sh` was deleted, so this denial no longer occurs (ADR-0044).
   ~~~~
14. file: `docs/harness-glossary.md`
   heading: the line starting `**The human-decision gate**`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): the gate was deleted together with the escalation verdict (ADR-0044).
   ~~~~
15. file: `docs/harness-glossary.md`
   heading: `**per-commit semantics**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.31.227): `version-stamp-check.sh` no longer checks each commit against its parent; the version-stamp discipline is per release (constitution P3 v1.2.0, plan 2026-10-30-lean-pipeline).
   ~~~~
16. file: `docs/harness-glossary.md`
   heading: `**frozen family table**:`
   placement: insert the text as a new line directly below the heading line
   indent: 3
   text:
   ~~~~
   Retired (0.32.0): its rows lived in the gate's test suite, deleted with the gate (unit lp-hdg), and `tests/validate.sh` no longer checks its pins (ADR-0044).
   ~~~~

## Doc edits
1. file: `docs/trust-model.md`
   heading: the line starting `| 25 |`
   placement: replace that one line with the text below
   indent: 3
   before:
   ~~~~
   | 25 | A unit touching `agents/*.md` or `templates/` bumped `.claude-plugin/plugin.json`'s version in each commit that touched it, and added a CHANGELOG entry naming the new version in that same commit (constitution P3 / version-stamp discipline) | `hooks/scripts/version-stamp-check.sh` | self-reported | Deliberately **not** hook-registered — a reviewer-invoked helper, matching `heavy-trigger.sh`/`reviewer-tier.sh` (units version-stamp-guard-1, version-stamp-check-roast-1). Implements **per-commit semantics**: every commit in the range that touches a version-stamped path is checked against its own immediate parent. Takes an explicit range because a unit's range is a per-unit input only the reviewer knows. Deterministic given an explicit `<commit-range>` argument; nothing independently re-derives whether the reviewer actually ran it against the right range. |
   ~~~~
   text:
   ~~~~
   | 25 | A release (a commit that bumps `.claude-plugin/plugin.json`'s version) added a CHANGELOG line naming the new version in that same commit, and no commit lowered the version; content commits need no bump (constitution P3 v1.2.0 / version-stamp discipline, per release since 0.31.227) | `hooks/scripts/version-stamp-check.sh` | self-reported | Deliberately **not** hook-registered — a reviewer-invoked helper, matching `heavy-trigger.sh`/`reviewer-tier.sh` (units version-stamp-guard-1, version-stamp-check-roast-1, lp-vsr). Checks every bumping commit in the range against its own immediate parent; a range with no bump is `ok`. The per-commit check of version-stamp-check-roast-1 was retired in 0.31.227. Takes an explicit range because a unit's range is a per-unit input only the reviewer knows. Deterministic given an explicit `<commit-range>` argument; nothing independently re-derives whether the reviewer actually ran it against the right range. |
   ~~~~
Make no other doc changes.
prune: none

## ADR
0044 Retire the escalation verdict and Bash text scanning
file: docs/adr/0044-retire-escalation-and-bash-scans.md
body:
indent: 0
~~~~
# ADR 0044: Retire the escalation verdict and Bash text scanning

Date: 2026-10-30
Status: Accepted
Related: ADR-0002, ADR-0016, ADR-0034

## Context

Two protections cost more than they caught. The ESCALATE-TO-HUMAN verdict, with its `.escalated` marker, review packet, escalation card and human-decision gate, was issued 0 times in 917 review markers. The Bash command-text scans in `harness-integrity-gate.sh` and `reviewed-path-gate.sh` blocked 583 commands a month, and every sampled block was a read-only command.

## Decision

- The reviewer has three verdicts (PASS, FAIL, INSUFFICIENT-CONTEXT). When a decision belongs to the user, it adds a `needs-human: <one line>` note, and the orchestrator relays it with AskUserQuestion. No marker, packet, card or gate exists for it.
- The Bash branches of both gates allow at once. Their `hooks/hooks.json` registrations stay, because the A/B harness (`tests/abtest-arms.test.sh`) pins them. The Write and Edit denies stay.
- A replacement check landed first: `dispatch-hygiene.sh` stamps each gated writer dispatch, and the stop gate blocks a writer's stop when a `.pass`, `.fail` or `.blocked` marker is newer than that stamp. Pending-review flags clear only on a reviewer stop.
- The stop gate keeps one pending-review flag check, the WIP sentinel, and `skip:`/`defer:`.

## Consequences

- Any agent can write review markers or the harness's own config and audit files through Bash without a pre-block. A marker forged during a writer dispatch is caught at that writer's stop; a forgery at any other time is not. `bin/audit-seal-verify.sh` still detects audit-log tampering on demand.
- The stop gate no longer runs test and lint at Stop (the reviewer's single `validate.sh` run covers it), no longer gates microworld reruns, no longer checks config drift, and no longer scopes review per unit through review-join stamps (the protocol already allows one unit mid-review).
- Removing the two inert hooks.json registrations needs the A/B harness changed first.
~~~~

## Close conditions
- issue #0: the fast path has no tracker issue, so close nothing and run no `gh issue` command
- task-id: lp-scribe
- marker first line: "PASS lp-scribe "
- Commit once, staging only `CONTEXT.md`, `docs/harness-glossary.md`, `docs/trust-model.md` and `docs/adr/0044-retire-escalation-and-bash-scans.md`, with the subject `docs(lp-scribe): lean-pipeline glossary entries and ADR-0044 (#0)` and the trailer line `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` (a fix round on another tier names that tier's model). A fix round is a new commit whose subject keeps `(lp-scribe): `. Commit your own memory notes separately.
- precondition: `test ! -e docs/adr/0044-retire-escalation-and-bash-scans.md && ls docs/adr | grep -c '^0044-'` prints `0`; each `before` text and each heading line appears in its file exactly once; the tree is clean. Anything else: STOP.

## Affected files
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/trust-model.md` (doc edit 1)
- `docs/adr/0044-retire-escalation-and-bash-scans.md` (new)

## Do NOT touch
- `agents/`, `templates/`, `adapters/`, `skills/`, `tests/`, `hooks/`, `bin/` (criterion 6)
- `.claude/`, `docs/plans/`, every other `docs/adr/` file, every other glossary entry (criterion 6)

## Acceptance criteria
1. run: `bash -c 'for t in "five-field contract" "release" "needs-human note" "task-master"; do printf "%s=%s " "$t" "$(grep -cxF "**$t**:" CONTEXT.md)"; done | sed "s/ $//"; echo'`
   exit: 0
   stdout: `five-field contract=1 release=1 needs-human note=1 task-master=1`
   mutation: skip glossary edit 4; the second field reads `release=0`, and criterion 5 fails on the dangling `[[release]]` link (spec-master ran both on today's tree: all four read `=0`).
2. run: `bash -c 'chk(){ awk -v h="$2" "index(\$0,h)==1{f=1;next} f&&/^\\*\\*/{exit} f" "$1" | grep -qF "Retired (0.32.0)" || echo "missing: $2"; }; chk CONTEXT.md "**task-master**:"; chk CONTEXT.md "**Escalation packet**:"; chk CONTEXT.md "**ESCALATE-TO-HUMAN**:"; chk CONTEXT.md "**\`.escalated\` marker**:"; chk CONTEXT.md "**escalation card**:"; chk docs/harness-glossary.md "**review-join stamp**:"; chk docs/harness-glossary.md "**decision-gate denial**:"; chk docs/harness-glossary.md "**The human-decision gate**"; chk docs/harness-glossary.md "**frozen family table**:"; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: skip glossary edit 13; stdout gains `missing: **decision-gate denial**:` before `checked` (spec-master ran it on today's tree: nine `missing:` lines, then `checked`).
3. run: `bash -c 'grep -qF "On FAIL, the orchestrator writes the fix contract" agents/orchestrator.md || echo "no-source: fix contract"; grep -qF "needs-human:" agents/reviewer.md || echo "no-source: needs-human"; grep -qi "per release" skills/version-stamp-discipline/SKILL.md || echo "no-source: release"; e(){ awk -v h="$2" "index(\$0,h)==1{f=1;next} f&&/^\\*\\*/{exit} f" "$1" | tr -s " \n" " "; }; f=$(e CONTEXT.md "**five-field contract**:"); for x in "## Acceptance criteria" "at most 3,072 bytes" "[[fix contract]]"; do printf "%s" "$f" | grep -qF -- "$x" || echo "missing: five-field $x"; done; n=$(e CONTEXT.md "**needs-human note**:"); for x in "needs-human: <one line>" "It does not change the verdict" "AskUserQuestion"; do printf "%s" "$n" | grep -qF -- "$x" || echo "missing: needs-human $x"; done; r=$(e CONTEXT.md "**release**:"); printf "%s" "$r" | grep -qF "The version never decreases" || echo "missing: release"; x=$(e docs/harness-glossary.md "**fix contract**:"); printf "%s" "$x" | grep -qF "that the orchestrator writes after a FAIL" || echo "missing: fix orchestrator"; printf "%s" "$x" | grep -qF "task-master, if present" && echo "stale: fix contract"; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: skip glossary edit 11; stdout gains `missing: fix orchestrator` and `stale: fix contract` before `checked`. The three `no-source:` checks fail if lp-tmroute, lp-escprose or lp-vsr did not land as specified.
4. run: `bash -c 'a=docs/adr/0044-retire-escalation-and-bash-scans.md; test -f $a || { echo no-adr; exit 1; }; for x in "# ADR 0044: Retire the escalation verdict and Bash text scanning" "issued 0 times in 917 review markers" "blocked 583 commands a month" "needs-human: <one line>" "newer than that stamp"; do grep -qF -- "$x" $a || echo "missing: $x"; done; ls docs/adr | grep -c "^0044-"'`
   exit: 0
   stdout: `1`
   mutation: delete the ADR file; stdout is `no-adr`, exit 1 (today's tree: `no-adr`).
5. run: `node tests/context-glossary-links.test.js | tail -1; bash tests/glossary-index.test.sh >/dev/null 2>&1 && echo index-ok`
   exit: 0
   stdout: `All context-glossary-links checks passed.` then `index-ok`
   mutation: write `[[needs-human notes]]` in glossary edit 6; the link resolves to no entry and the first line changes.
6. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(lp-scribe): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "CONTEXT.md|docs/harness-glossary.md|docs/trust-model.md|docs/adr/0044-retire-escalation-and-bash-scans.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: also stage `docs/adr/0043-refutation-pass-inside-reviewer-turn.md` in a `(lp-scribe): ` commit; stdout is `1` (today's tree: `no-commits`).
7. run: `bash -c 'git status --porcelain --untracked-files=no -- . ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave a glossary edit unstaged; stdout is `1`.
8. run: `bash -c 'e(){ awk -v h="$2" "index(\$0,h)==1{f=1;next} f&&/^\\*\\*/{exit} f" "$1"; }; e CONTEXT.md "**version-stamp discipline**:" | head -1 | grep -qF "Superseded (0.31.227): the rule is per [[release]]" || echo "stale: version-stamp discipline"; e CONTEXT.md "**release**:" | tr -s " \n" " " | grep -qF "Also called a bumping commit" || echo "missing: release synonym"; e docs/harness-glossary.md "**per-commit semantics**:" | head -1 | grep -qF "Retired (0.31.227)" || echo "stale: per-commit semantics"; r=$(grep -E "^[|] 25 [|]" docs/trust-model.md); printf "%s" "$r" | grep -qF "per release since 0.31.227" || echo "stale: trust row 25"; printf "%s" "$r" | grep -qF "in each commit that touched it" && echo "per-commit: trust row 25"; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: skip doc edit 1; stdout gains `stale: trust row 25` and `per-commit: trust row 25` before `checked` (spec-master ran it on today's tree: five lines, `stale: version-stamp discipline`, `missing: release synonym`, `stale: per-commit semantics`, `stale: trust row 25`, `per-commit: trust row 25`, then `checked`; on a scratch worktree with glossary edits 3, 4, 15 and doc edit 1 applied: `checked` alone).

## Escalation
If any `before` text or heading line is not found exactly once, STOP and report the current text as a spec gap. If criterion 3 prints `no-source: …`, an earlier unit changed its wording: stop and report it. If a gate blocks a command, report it and wait.
