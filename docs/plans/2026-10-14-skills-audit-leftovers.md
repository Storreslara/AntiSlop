# Skills audit leftovers (slice `lov`)

Status: FINAL, ready to dispatch (fast path, 5 units, strict order lov-1 -> lov-5). No blocking Open Question; Open Question 1 concerns a future spec and does not hold any unit. Contracts: `## Dispatch contracts` below; each scores `contract-guard: haiku ... score=7/7`.
Slug: `2026-10-14-skills-audit-leftovers`. Unit ids: `lov-1` .. `lov-5`. Criteria scripts: `docs/plans/lov-criteria/`.

## Goal

Close the non-blocking findings the reviewers left on the skills-audit slices (skr-1..skr-11, `docs/plans/2026-10-14-skills-audit-implementation.md`; sfu-1..sfu-5, `docs/plans/2026-10-14-skills-audit-followups.md`), after checking each against the tree at `d937e67` (version 0.31.168). Three groups: doc and wording fixes (lov-1), test hardening (lov-2 version-stamp-check, lov-3 resync and link tests), and two harness units kept apart so each is reviewed alone (lov-4 contract-guard issue-body layout, lov-5 review-join stamp ownership). Findings that no longer hold, or need no change, are listed with the reason and get no unit.

## Context

Input: the orchestrator's list of leftovers, the `NOTE[...]` lines in the sfu and skr `.pass` markers, and a `bin/marker-audit.sh . --notes` sweep over every surface this slice touches (2026-10-14, 101 s). Every file:line below was re-checked at `d937e67`.

Measured facts the units rely on:

- **Archive README and its siblings.** `docs/archive/skills/README.md:22-23` give `grilling` and `improve-codebase-architecture` the disposition `rewritten (stays live)`, while `CONTEXT.md` **Forked skill** names both forked. The README (line 3), `CONTEXT.md` **Archived skill** (:641-643) and ADR-0041 Decision 3 (:16) all say nothing "lists, mirrors or hashes" the archive. `scripts/resync-vendored-skills.sh:46-54` names the archived originals of the four forked skills as FILES local paths, and `--check` diffs them. So "lists" is false in all three places, not only in the README.
- **jq.** `hooks/scripts/harness-integrity-gate.sh:278-290` (`is_benign_jq_read`) allows a command that is one `jq` invocation with no pipe, separator, redirection or substitution; `tests/harness-integrity-gate.test.sh:153` pins `jq -r .gatedAgents .claude/persona-config.json` as allowed. `skills/install-antislop/SKILL.md:315` gives `jq` as its example of a refused command.
- **Resync runbook.** `docs/maintenance/resync-vendored-skills.md:22` says "The first 7 are byte-verbatim"; 4 of the 7 are forked, and the `fm-noflag` deviation on the improve-codebase-architecture row applies to its archived original. Step 4 (:121-131) re-pins the headers of files the FILES table names under `skills/`; `skills/tdd/tests.md` and `skills/tdd/mocking.md` carry a full-SHA "Vendored verbatim" header but FILES names only their archived copies (`scripts/resync-vendored-skills.sh:49-50`). Both live files are byte-identical to the archived ones today.
- **Skill wording.** `skills/improve-codebase-architecture/SKILL.md:18` ends "return the result as your final message", which is wrong when the skill is loaded through the `Skill` tool inside another persona's turn. `skills/pathfinder/SKILL.md:50` says "the `issueTracker` line" where :48 says field. `docs/plans/sfu-criteria/sfu-claims.sh:56` pins the old pathfinder phrase, so lov-1 updates that check too (no suite runs `sfu-claims.sh`; the edit keeps it re-runnable).
- **TDD skill location.** `agents/lead-programmer.md:55-57` tells a teammate to read "the `tdd` skill's `SKILL.md`" without saying where it is. In an installed project it lives in the plugin's install tree (`~/.claude/plugins/cache/<marketplace>/antislop/<version>/skills/tdd/SKILL.md` here); a teammate gets no "Base directory for this skill" line, because the skill was never loaded.
- **Followups plan.** `docs/plans/2026-10-14-skills-audit-followups.md:1359` (sfu-4 criterion 1) says that with the function reverted, cases (f) and (g) print FAIL. Reproduced in a scratch clone with the pre-sfu-4 function: (f) and (g) print OK, only (h1), (h2) and (i) FAIL, and the mc8-mc11 and mc13 seds match nothing. The old function already kept added lines only and used `grep -F`. The same plan (:91, :1183) and the sfu-4 CHANGELOG entry call the `+++`-exclusion mutant equivalent; it is not, because an added CHANGELOG line whose text starts with `++` renders as `+++...`, which the shipped code skips and the mutant counts.
- **version-stamp-check.** `hooks/scripts/version-stamp-check.sh:69` runs `git diff --no-color --no-ext-diff --no-renames`, without `--no-textconv`. Three hardenings are pinned only by the suite's "sed matched nothing" guard, not by a fixture: the left boundary's dot, the right boundary without the dot, and `--no-ext-diff`. `tests/version-stamp-check.test.sh:88,105,117` still say "CHANGELOG line".
- **Resync offline test.** `tests/resync-vendored-skills-offline.test.sh` passes when one of a skill's several FILES rows is deleted (for example `tdd:doc:...mocking.md`) and when an upstream path has a typo in its file name.
- **Relative-link test.** `tests/doc-relative-links.test.js`: a SCOPE entry that is renamed or deleted drops out silently (`git ls-files` ignores an unmatched pathspec); links with a title (`[x](a.md "t")`) or an `<angle>` destination are skipped; a malformed percent escape makes `decodeURI` throw. The lov-3 rewrite, run against `d937e67`, still reports `ok (162 links in 80 files)`, the same as the current test, so it finds no new broken link.
- **Contract guard.** `bin/contract-guard.js:36-51` accepts a contract only as a fenced block whose first interior line is `Unit: <id>`, or an input whose line 1 is `Unit: <id>`. The skr issue bodies (for example #531) put an unfenced `Unit: skr-1` after a prose preamble and `## Dispatch contract`, so every unit scored `reason=no-contract`, a guard demotion to `sonnet`. Measured: task-master.md's own lead example, wrapped in a preamble plus `## Dispatch contract` and a `~~~~` fence, scores `contract-guard: haiku unit=demo-7 shape=lead score=7/7`; the same body unfenced scores `reason=no-contract`. `agents/task-master.md:62-66` and :333-334 place the contract under a heading and never say it must be fenced; `skills/pathfinder/SKILL.md` says nothing about where the contract goes in an issue.
- **Review-join stamps.** `hooks/scripts/lib/reviewer-route-gate-core.sh:149-152` writes `.claude/.review-join.<unit>` holding `<ts> unit= prior= prior_mtime=`, with no owner. `review_join_state` in `hooks/scripts/lib/stop-gate-core.sh:239-329` classifies every stamp in the directory on any reviewer's SubagentStop, and :460-469 blocks when one is unsatisfied, telling the reviewer the unit is one "you were dispatched for". Reproduced with the real hooks in a scratch project: reviewer `rev-a` reviews `res-a`, writes its PASS and stops (exit 0, `join-consumed=res-a`); a reviewer is dispatched for `res-b`; `rev-a` stops again and gets exit 2, naming `res-b`. Claude Code 2.1.300 has both a `SubagentStart` hook event and an `agent_transcript_path` payload field, so two attribution designs exist. Either one changes the gate core, its two generated adapter copies, `hooks/hooks.json` or the transcript contract, and ADR-0016's per-unit join, which has a FAIL-loop history. lov-5 is therefore the documented-only option the request allows: the block message stops claiming ownership and tells the reviewer to report and wait, the glossary records the residual, and a test reproduces it. The fix itself is Open Question 1, for a later spec.
- **Generated copies.** `node bin/cli.js --update --force-render` refreshes `.claude/agents/*.md`, `.claude/hooks/scripts/**`, `adapters/{codex,cursor}/hooks/scripts/lib/*.sh` (`bin/cli.js:690-710`, the shared hook libs) and the fileHashes in `.claude/persona-config.json`.
- **Prior FAIL history.** None of skr-1..skr-11 or sfu-1..sfu-5 has a `.fail` record (all sixteen have only `.pass`). Sweep result: the lov-relevant `NOTE[spec]` lines are the ones listed in the table below. Three others concern files this slice touches and are dispositioned under "Findings that get no unit". No `untagged` line names a step of this slice. The sweep is per-clone state; an absence proves nothing.
- **End-to-end verification.** The five contracts were parsed from this file and applied in order to a fresh clone of `d937e67`. Every before block and anchor matched exactly once, every command exited as expected, and every acceptance criterion then held; see CHK13.

### Verified in-scope findings

| # | Finding (source) | Verified at `d937e67` | Unit |
|---|---|---|---|
| L1 | Archive README rows grilling / improve-codebase-architecture say `rewritten (stays live)`; CONTEXT.md and ADR-0041 say forked (sfu-1, sfu-2, sfu-3 notes) | yes, :22-23 | lov-1 |
| L2 | "nothing lists, mirrors or hashes" the archive, while the resync script lists archived files (sfu-2 note) | yes, and also in CONTEXT.md :641-643 and ADR-0041 :16 | lov-1 |
| L3 | install-antislop :315 gives `jq` as a refused command; a lone read-only `jq` is allowed (sfu-2 note) | yes | lov-1 |
| L4 | Resync runbook :22 "first 7 are byte-verbatim"; step 4 misses live `skills/tdd/tests.md`, `mocking.md` (sfu-2 note) | yes | lov-1 |
| L5 | improve-codebase-architecture :18 "final message"; pathfinder :50 "`issueTracker` line" (sfu-2 notes) | yes | lov-1 |
| L6 | lead-programmer.md does not say where the `tdd` skill lives in an installed project (sfu-3 note) | yes, :55-57 | lov-1 (0.31.169) |
| L7 | CONTEXT.md lacks whole version, equivalent mutant, per-clone review state | yes, no heading for any | lov-1 |
| L8 | Followups plan :1359 says (f)/(g) print FAIL with the function reverted; "equivalent mutant" for `+++` (sfu-4 notes) | yes, reproduced | lov-1 (plan), lov-2 (CHANGELOG, test comment) |
| L9 | version-stamp-check: no `--no-textconv`; no fixture for `x.0.3.13`, a version at a sentence end, `diff.external`; labels say "CHANGELOG line" (sfu-3, sfu-4 notes) | yes | lov-2 |
| L10 | Resync offline test misses a dropped FILES row and an upstream file-name typo (sfu-5 note) | yes | lov-3 |
| L11 | Link test drops a renamed SCOPE entry, skips titled and `<angle>` links, crashes on a bad escape (sfu-5 notes) | yes | lov-3 |
| L12 | contract-guard demotes every task-master issue body: unfenced `Unit:` after prose (sfu plan Report-only 1) | yes, measured | lov-4 (0.31.170) |
| L13 | Review-join stamps carry no owner; a reviewer is blocked on another unit's stamp (sfu plan Report-only 2) | yes, reproduced | lov-5 (documented-only) |

### Findings that get no unit

- **Codex and Cursor lead-programmer ports lack the agent-teams TDD fallback** (sfu-3 note): false as a gap. Neither port has an agent-teams mode or a `skills:` preload; both inline the `tdd` skill body (`adapters/codex/agents/lead-programmer.toml:127-159`, `adapters/cursor/agents/lead-programmer.md:125-157`, pinned by `tests/adapter-skill-parity.test.js`). A preload fallback has nothing to fall back from there. No change.
- **`(0.3.14).` as the right-boundary fixture** (sfu-4 note): it would not kill the mutant. With the right boundary widened to `(?![0-9.])`, `(0.3.14).` still matches, because `)` follows the version. lov-2 uses `0.3.14.` at the end of a sentence (case h5), which the mutant rejects.
- **Hunk-aware CHANGELOG parse to kill the `+++` mutant** (sfu-4 note): it would change shipped behaviour to fix a tiny old false-violation path (an added line starting with `++`). lov-2 records the mutant truthfully and leaves it unpinned on purpose; no parse change.
- **skr-1 note: `skr-archive-verify.sh` is not in `tests/validate.sh`**, **skr-2 note: "spec publication" has no glossary entry**, **skr-4 note: the persona config's `issueTracker` string cites `to-tickets`**: not in the requested list. The last is a human-only edit. Report only.
- Out of scope by request: `.claude/persona-config.json` (human-only), the 18 broken relative links in rendered `.claude/agents`, 2 in `adapters/cursor`, 15 in `docs/plans`.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-14 Functional scope & success criteria: Q Which leftovers enter the slice? → A (self-resolved): the thirteen verified findings L1-L13; the false or no-change ones are listed above with the reason. L2 is widened from the README to CONTEXT.md and ADR-0041, which carry the same false clause.
- 2026-10-14 Functional scope & success criteria: Q Fast path or task-master slice? → A (self-resolved): fast path, 5 units. The doc and agent-wording findings share one stamped unit (lov-1, 0.31.169) instead of two; test hardening is two units (one per test family); each harness change is its own unit, as requested.
- 2026-10-14 Domain entities / data model: Q Where do "whole version", "equivalent mutant" and "per-clone review state" go? → A (self-resolved): CONTEXT.md, next to **version-stamp discipline**, **Mutation-proved** and **PASS marker** respectively; each is a term the reviewers and plans already use.
- 2026-10-14 Non-functional attributes: Q Is a stamp-ownership fix safe to spec now? → A (self-resolved): no. Both candidate designs (bind at `SubagentStart`, or read the stopping agent's own prompt from `agent_transcript_path`) touch the gate core, its generated adapter copies and ADR-0016's per-unit join, an area with a FAIL-loop history. lov-5 is the documented-only option the request allows; the design choice is Open Question 1 for a later spec.
- 2026-10-14 Edge cases / failure handling: Q What does the blocked reviewer do in the ownerless-stamp case? → A (self-resolved): what the shared protocol already requires of a block it cannot satisfy: report and wait, never write a marker for a unit it did not review. lov-5 puts that instruction into the block message, which is the only text the reviewer is guaranteed to read at that moment.
- 2026-10-14 Edge cases / failure handling: Q Should the `+++` mutant be pinned? → A (self-resolved): no. Pinning it would pin the old false violation for added lines starting with `++`. It is described truthfully in the test and the CHANGELOG instead.
- 2026-10-14 Technical constraints & tradeoffs: Q Contract-guard fix: change the guard or the layout? → A (self-resolved, per the request's preference): the layout. task-master and pathfinder put the contract in a tilde-fenced block longer than any fence inside it; the guard is unchanged, and a test pipes task-master's documented issue-body example through the guard.
- 2026-10-14 Technical constraints & tradeoffs: Q Which units owe the P3 bump? → A (self-resolved): lov-1 (agents/lead-programmer.md, 0.31.168 -> 0.31.169) and lov-4 (agents/task-master.md, 0.31.169 -> 0.31.170). lov-2 and lov-5 change hooks, which are not version-stamped, and still run `node bin/cli.js --update --force-render` for the mirrors, adapter copies and fileHashes.
- 2026-10-14 Terminology consistency: Q Does the request's vocabulary drift from the glossary? → A (self-resolved): "CHANGELOG line" is the retired wording; the canonical term is **CHANGELOG entry** (lov-2 fixes the last three test labels). "Equivalent mutant" was used with a wrong meaning in the sfu plan; lov-1 defines it. "Stamp attribution" means the same as stamp ownership; the glossary keeps **review-join stamp** as the term and adds no synonym.

## Risks / dependencies

- R1. Strict chain lov-1 -> lov-2 -> lov-3 -> lov-4 -> lov-5. `CHANGELOG.md` is shared by every unit. `skills/pathfinder/SKILL.md` is shared by lov-1 (the Local files bullet) and lov-4 (the real-tracker bullet); the anchors are distinct lines. lov-1 and lov-4 each set HEAD + 1 for the version.
- R2. `tests/harness-integrity-gate.test.sh:1313` (C4.1) sweeps four fixed gate phrases across the tree, `docs/plans/` included. No text in this plan or its payloads contains them.
- R3. Gates on command text. A Bash command naming the persona config is refused by `harness-integrity-gate.sh`: stage `.claude` changes with `git add -u .claude`. A Bash command spelling the per-clone review-record directory is refused by `reviewed-path-gate.sh`: the CONTEXT.md entry in lov-1 edit 7, and the lov-5 test payload, are applied with the Edit tool, never with sed or a heredoc.
- R4. `tests/validate.sh` exceeds the 600 s Bash cap serially. Each unit runs `bash tests/validate-lanes.sh --lanes 6` once. Leave `tests/validate-lanes*`, `tests/reviewed-dir-leak-guard.test.sh` and the `docs/plans/*-criteria/` directories of other slices alone (lov-1 edits exactly one line of `docs/plans/sfu-criteria/sfu-claims.sh`).
- R5. Nested fences. lov-4's payloads hold `~~~~` and three-backtick lines, so its contract uses a 7-tilde outer fence and 5-tilde payload fences; a shorter outer fence would end the contract early for `bin/contract-guard.js`. Every other contract uses `~~~~` outer and `~~~` payload fences.
- R6. lov-5 changes the text, not the exit code, of a gate block. The reproducing test pins the current behaviour (exit 2 on a foreign stamp) as a known residual; a later ownership fix must flip that case to exit 0 and say so.
- R7. Commit trailer: criteria grep only `^Co-Authored-By: Claude `. The orchestrator supplies the dispatched tier's own line.
- R8. Where a contract and the narrative Steps differ, the contract governs.
- R9. Tags: lov-2 (hook, version-stamp-check FAIL history in earlier slices) and lov-5 (gate core) are tagged `sonnet` although the guard scores them haiku-eligible; the other three are `haiku`.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every finding was re-checked at `d937e67`; the residual in L13 and the old-function behaviour in L8 were reproduced with the real scripts; every contract was applied to a fresh clone and its criteria run.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors, adapter hook libs and fileHashes come only from `node bin/cli.js --update --force-render`; nothing edits `.claude/persona-config.json` by hand.
- P3 "Version-stamp discipline": satisfied. lov-1 and lov-4 are the only units touching `agents/*.md`; each bumps the version with a same-commit CHANGELOG entry naming it and checks its own commit with `version-stamp-check.sh`. No unit touches `templates/`.
- P5 "`tests/validate.sh` is the merge gate": deviation. The serial suite exceeds the 600 s Bash cap, so each unit runs the same sections through `bash tests/validate-lanes.sh --lanes 6`, as the sfu and skr reviewers did.

## Steps

Every unit ends with one commit, staged by explicit path, subject scope `(lov-N)`. Common criteria (the contracts spell them out), with `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-N\): ' | head -1 | cut -d' ' -f1)`:
- `bash hooks/scripts/version-stamp-check.sh "$C~1..$C"` prints `ok touched: no`, except lov-1 (`ok touched: yes old: 0.31.168 new: 0.31.169`) and lov-4 (`old: 0.31.169 new: 0.31.170`).
- `git log -1 --format=%B "$C" | grep -c '^Co-Authored-By: Claude '` prints 1.
- `bash tests/validate-lanes.sh --lanes 6` exits 0 with no FAIL line.

### Step 1 (lov-1): doc, glossary and agent wording. Lead-programmer, version bump 0.31.169

Files: `docs/archive/skills/README.md`, `CONTEXT.md`, `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`, `skills/install-antislop/SKILL.md` (+ `.claude/skills/install-antislop/SKILL.md` by `cp`), `docs/maintenance/resync-vendored-skills.md`, `skills/improve-codebase-architecture/SKILL.md`, `skills/pathfinder/SKILL.md`, `docs/plans/sfu-criteria/sfu-claims.sh` (one line), `docs/plans/2026-10-14-skills-audit-followups.md`, `agents/lead-programmer.md`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`; rendered `.claude/` files.
Covers L1-L8 (L8: the plan text). Criteria: `lov-claims.sh lov-1` (red at `d937e67`: all 30 checks FAIL), mirror diff, `sfu-claims.sh sfu-2` still green, glossary link test, link test, archive bytes unchanged, version sync and render, the common criteria.

### Step 2 (lov-2): version-stamp-check second hardening pass. Lead-programmer, TDD, no version bump

Files: `tests/version-stamp-check.test.sh`, `hooks/scripts/version-stamp-check.sh`, `CHANGELOG.md`; rendered `.claude/hooks/scripts/version-stamp-check.sh`, fileHashes.
Tests first: cases (h4) `x.0.3.13`, (h5) `0.3.14.` at a sentence end, (j) a textconv driver on CHANGELOG.md, (k) `diff.external`; controls mc14 (`--no-ext-diff` removed), mc15 (`--no-textconv` removed), mc16 (left boundary without the dot), mc17 (right boundary with the dot); mc13's sed retargeted. Before the hook edit, (j) FAILs and mc15's sed matches nothing; (h4), (h5), (k) pass and pin existing behaviour, as do mc14, mc16 and mc17. Then `--no-textconv` in the hook. Labels say "CHANGELOG entry"; the `+++` mutant is described truthfully in a test comment and in the sfu-4 CHANGELOG entry.

### Step 3 (lov-3): resync offline and relative-link test hardening. Lead-programmer, TDD, no version bump

Files: `tests/resync-vendored-skills-offline.test.sh`, `tests/doc-relative-links.test.js`, `CHANGELOG.md`.
Resync: per skill, the FILES rows equal the tracked files under its drift-tracked root, and each row's upstream path ends in the same skill-relative path. Links: per-SCOPE-entry non-empty check, titled and `<angle>` destinations parsed, unparsable destinations and malformed escapes reported as broken. Proofs run in `git worktree` checkouts.

### Step 4 (lov-4): task-master issue-body layout matches contract-guard. Lead-programmer, version bump 0.31.170

Files: `agents/task-master.md`, `skills/pathfinder/SKILL.md`, `tests/contract-examples.test.js`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`; rendered `.claude/agents/task-master.md` and friends.
task-master's contract-home rule and scribe paragraph require the tilde-fenced contract; a new marked issue-body example; pathfinder's real-tracker bullet says the same; `tests/contract-examples.test.js` pipes the example (with the lead example substituted in) through `bin/contract-guard.js` and expects haiku 7/7, and expects `reason=no-contract` with the fence lines removed. `bin/contract-guard.js` is unchanged.

### Step 5 (lov-5): review-join ownerless-stamp residual, documented. Lead-programmer, TDD, no version bump

Files: `tests/review-join.test.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `docs/harness-glossary.md`, `CHANGELOG.md`; rendered `.claude/hooks/scripts/lib/stop-gate-core.sh`, `adapters/{codex,cursor}/hooks/scripts/lib/stop-gate-core.sh`, fileHashes.
Test first: case (residual-ownerless-stamp) reproduces the foreign-stamp block and requires the new guidance in the block text (red until the hook edit). The block message no longer says "you were dispatched for"; it says a stamp names no owner and tells a reviewer not dispatched for a listed unit to report and wait. The **review-join stamp** glossary entry drops "without cross-dispatch interference" and records the residual. Exit codes are unchanged.

## Dispatch contracts

Strict order lov-1 -> lov-2 -> lov-3 -> lov-4 -> lov-5; each unit is blocked by the previous one (shared `CHANGELOG.md`; `skills/pathfinder/SKILL.md` in lov-1 and lov-4; the two version bumps). Each contract is the fenced block below its heading; the guard reads it with `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-leftovers.md --unit=lov-N`.

### Contract lov-1: archive dispositions, archive listing, jq, runbook, skill wording, tdd location, glossary, sfu plan corrections

Suggested model: haiku

~~~~
Unit: lov-1

## Objective
The archive README marks `grilling` and `improve-codebase-architecture` forked, and the README, `CONTEXT.md` and ADR-0041 (with a dated correction) say the resync script lists the forked skills' archived originals. `skills/install-antislop` says a lone read-only `jq` is allowed. The resync runbook counts the 3 verbatim skills and names the live `tdd` companions that step 4 misses. improve-codebase-architecture and pathfinder wording is fixed. `agents/lead-programmer.md` says where the `tdd` skill lives in an installed project (version 0.31.169, rendered). `CONTEXT.md` defines whole version, equivalent mutant and per-clone review state. The sfu follow-ups plan's sfu-4 notes are corrected.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers.md`. Criteria scripts: `docs/plans/lov-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop` (the skills-audit umbrella).

## Affected files
- `docs/archive/skills/README.md` (anchor: line matching `| grilling | skills/grilling |`)
- `CONTEXT.md` (anchor: line matching `**PASS marker**:`)
- `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md` (anchor: line matching `## Corrections`)
- `skills/install-antislop/SKILL.md` (anchor: line matching `correctly; a Bash command such as`), copied to `.claude/skills/install-antislop/SKILL.md`
- `docs/maintenance/resync-vendored-skills.md` (anchor: line matching `The first 7 are byte-verbatim`)
- `skills/improve-codebase-architecture/SKILL.md` (anchor: line matching `Do the exploration, then return the result`)
- `skills/pathfinder/SKILL.md` (anchor: line matching `-> write one file per unit under the directory the`)
- `docs/plans/sfu-criteria/sfu-claims.sh` (anchor: line matching `('skills/pathfinder/SKILL.md', 'under the directory the`)
- `docs/plans/2026-10-14-skills-audit-followups.md` (anchor: line matching `After sfu-5 passes, scribe should check`)
- `agents/lead-programmer.md` (anchor: line matching `once before the first test). For hard bugs, invoke`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.168",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `docs/archive/skills/README.md`
   anchor: line matching `| grilling | skills/grilling |`
   before: `| grilling | skills/grilling | 35496ab14f05b81d0f9be538ed52d2146bf63da6 | rewritten (stays live) | skills/grilling |`
   after: `| grilling | skills/grilling | 35496ab14f05b81d0f9be538ed52d2146bf63da6 | forked (stays live) | skills/grilling |`
2. file: `docs/archive/skills/README.md`
   anchor: line matching `| improve-codebase-architecture | skills/improve-codebase-architecture |`
   before: `| improve-codebase-architecture | skills/improve-codebase-architecture | 864bfc7c2c7cafc95975d0c5b2a3e9e1f8d47c9a | rewritten (stays live) | skills/improve-codebase-architecture |`
   after: `| improve-codebase-architecture | skills/improve-codebase-architecture | 864bfc7c2c7cafc95975d0c5b2a3e9e1f8d47c9a | forked (stays live) | skills/improve-codebase-architecture |`
3. file: `docs/archive/skills/README.md`
   anchor: line matching `Byte-identical originals of skills that were retired`
   before:
   ~~~
   Byte-identical originals of skills that were retired, merged away or rewritten. No skill loader discovers this directory and nothing lists, mirrors or hashes it: it is outside every discovery root, and package.json ships no docs/ path (a git clone or plugin install carries it as inert files). Read it for history; do not edit it. Each directory is verified against git by docs/plans/skr-criteria/skr-archive-verify.sh.
   ~~~
   after:
   ~~~
   Byte-identical originals of skills that were retired, merged away, rewritten, trimmed or forked. No skill loader discovers this directory and nothing mirrors or hashes it: it is outside every discovery root, and package.json ships no docs/ path (a git clone or plugin install carries it as inert files). scripts/resync-vendored-skills.sh lists the archived originals of the forked skills as the local side of its upstream drift check, and `--check` reads them. Read it for history; do not edit it. Each directory is verified against git by docs/plans/skr-criteria/skr-archive-verify.sh.
   ~~~
   indent: 3
4. file: `CONTEXT.md`
   anchor: line matching `  directory and commit. No skill loader discovers it and nothing lists,`
   before:
   ~~~
     directory and commit. No skill loader discovers it and nothing lists,
     mirrors or hashes it; the npm package ships no `docs/` path, while a git
   ~~~
   after:
   ~~~
     directory and commit. No skill loader discovers it and nothing mirrors or
     hashes it; `scripts/resync-vendored-skills.sh` lists the archived originals
     of the forked skills as the local side of its upstream drift check. The npm
     package ships no `docs/` path, while a git
   ~~~
   indent: 3
5. file: `CONTEXT.md`
   anchor: line matching `  fields in the output remain informational only. See row 25 of`
   insert-after:
   ~~~

   **whole version**:
   (unit lov-1, 2026-10-14) — how a CHANGELOG entry must name a version for
     [[version-stamp discipline]] to count it: the version's dots are literal,
     and the match may not run into a digit on the right or into a digit or dot
     on the left. `0.31.16` is named by `v0.31.16`, by `(0.31.16)` and by
     `0.31.16.` at the end of a sentence, but not by `0.31.166`, `10.31.16` or
     `x.0.31.16`.
   ~~~
   indent: 3
6. file: `CONTEXT.md`
   anchor: line matching `_Avoid_: vacuous test, untested criterion`
   insert-after:
   ~~~

   **equivalent mutant**:
   (unit lov-1, 2026-10-14) — a mutant that no input can tell apart from the
     original, so no test can kill it and leaving it alive is not a gap in the
     suite. Calling a mutant equivalent is a claim that needs proof like any
     other: a mutant that differs from the original on even one rare input is a
     surviving mutant, not an equivalent one. The `+++`-exclusion mutant of
     `version-stamp-check.sh` was first misdescribed this way. See
     [[Mutation-proved]].
   ~~~
   indent: 3
7. file: `CONTEXT.md` (apply with the Edit tool: the payload names the per-clone review-record directory, see R3)
   anchor: line matching `**PASS marker**:`
   before: `**PASS marker**:`
   after:
   ~~~
   **per-clone review state**:
   (unit lov-1, 2026-10-14) — the [[PASS marker]]s, [[FAIL record]]s and other
     verdict files under `.claude/reviewed/`, which git ignores: each clone has
     its own, nothing pushes or restores them, and a fresh clone starts with
     none. A link to one from a tracked document is broken by construction, and
     an empty directory proves only that this clone recorded nothing.

   **PASS marker**:
   ~~~
   indent: 3
8. file: `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`
   anchor: line matching `3. Every pre-change original of a skill that was deleted, merged away or rewritten`
   before:
   ~~~
   3. Every pre-change original of a skill that was deleted, merged away or rewritten is kept byte-identical under `docs/archive/skills/<name>/`, with an index row in `docs/archive/skills/README.md` naming its origin path and commit. No skill loader discovers that directory and nothing lists, mirrors or hashes it; the npm package ships no `docs/` path, while a git clone or plugin install carries it as inert files (ADR-0022).
   ~~~
   after:
   ~~~
   3. Every pre-change original of a skill that was deleted, merged away or rewritten is kept byte-identical under `docs/archive/skills/<name>/`, with an index row in `docs/archive/skills/README.md` naming its origin path and commit. No skill loader discovers that directory and nothing mirrors or hashes it; `scripts/resync-vendored-skills.sh` lists the archived originals of the forked skills as the local side of its upstream drift check. The npm package ships no `docs/` path, while a git clone or plugin install carries it as inert files (ADR-0022).
   ~~~
   indent: 3
9. file: `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`
   anchor: line matching `- 2026-10-14 (unit sfu-1): the title said five skills`
   insert-after:
   ~~~
   - 2026-10-14 (unit lov-1): Decision 3 said nothing lists the archive, but `scripts/resync-vendored-skills.sh` names the archived originals of the four forked skills as the local paths of its drift check. Corrected in place; the decision is unchanged.
   ~~~
   indent: 3
10. file: `skills/install-antislop/SKILL.md`
   anchor: line matching `correctly; a Bash command such as`
   before:
   ~~~
   correctly; a Bash command such as `jq` naming that file can be refused by
   `harness-integrity-gate.sh`) before moving
   ~~~
   after:
   ~~~
   correctly; `harness-integrity-gate.sh` allows a lone read-only `jq` query of
   that file but can refuse any other Bash command naming it, such as a `jq` in
   a pipe or with a redirection) before moving
   ~~~
   indent: 3
11. command: `cp skills/install-antislop/SKILL.md .claude/skills/install-antislop/SKILL.md`
   expect: 0
12. file: `docs/maintenance/resync-vendored-skills.md`
   anchor: line matching `The first 7 are byte-verbatim aside from their provenance header`
   before:
   ~~~
   The first 7 are byte-verbatim aside from their provenance header, with two intentional deviations — `handoff` and `improve-codebase-architecture` — that have the `disable-model-invocation: true` flag stripped, tracked as the `fm-noflag` reconstruction type. Forked skills
   ~~~
   after:
   ~~~
   The 3 verbatim skills (`handoff`, `codebase-design`, `domain-modeling`) are byte-verbatim aside from their provenance header, except that `handoff` has the `disable-model-invocation: true` flag stripped, tracked as the `fm-noflag` reconstruction type (the archived `improve-codebase-architecture` original is compared the same way). Forked skills
   ~~~
   indent: 3
13. file: `docs/maintenance/resync-vendored-skills.md`
   anchor: line matching `   would then drift against the new pin); stop and raise it.`
   insert-after:
   ~~~
      The live `skills/tdd/tests.md` and `skills/tdd/mocking.md` keep a full-SHA
      "Vendored verbatim" header although the FILES table names only their
      archived copies, so step 4 does not reach them; they belong to the forked
      `tdd` skill and fall under the same stop.
   ~~~
   indent: 3
14. file: `skills/improve-codebase-architecture/SKILL.md`
   anchor: line matching `Do the exploration, then return the result as your final message.`
   before:
   ~~~
   Whether you run as a one-shot subagent or are invoked through the `Skill` tool inside another persona's turn, you cannot ask a question, open a browser or wait for a reply. Do the exploration, then return the result as your final message.
   ~~~
   after:
   ~~~
   Whether you run as a one-shot subagent or are invoked through the `Skill` tool inside another persona's turn, you cannot ask a question, open a browser or wait for a reply. Do the exploration, then return the ranked list: as your final message when you run as a subagent, or as your reply inside the invoking persona's turn when it loaded you through the `Skill` tool.
   ~~~
   indent: 3
15. file: `skills/pathfinder/SKILL.md`
   anchor: line matching `-> write one file per unit under the directory the`
   before:
   ~~~
   - **Local files** -> write one file per unit under the directory the `issueTracker` line names (if it names none, `.scratch/<feature-slug>/issues/`), as `<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers or titles it depends on. One unit per file, never a single combined file; use the template below.
   ~~~
   after:
   ~~~
   - **Local files** -> write one file per unit under the directory the `issueTracker` field names (if it names none, `.scratch/<feature-slug>/issues/`), as `<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers or titles it depends on. One unit per file, never a single combined file; use the template below.
   ~~~
   indent: 3
16. file: `docs/plans/sfu-criteria/sfu-claims.sh`
   anchor: line matching `('skills/pathfinder/SKILL.md', 'under the directory the`
   before:
   ~~~
     ('skills/pathfinder/SKILL.md', 'under the directory the `issueTracker` line names', 1),
   ~~~
   after:
   ~~~
     ('skills/pathfinder/SKILL.md', 'under the directory the `issueTracker` field names', 1),
   ~~~
   indent: 3
17. file: `docs/plans/2026-10-14-skills-audit-followups.md`
   anchor: line matching `exclusion mutant killable? → A (self-resolved): no, it is an equivalent mutant.`
   before:
   ~~~
   - 2026-10-14 Edge cases / failure handling: Q Is the `+++` exclusion mutant killable? → A (self-resolved): no, it is an equivalent mutant. The header line is always `+++ b/CHANGELOG.md` or `+++ /dev/null`, and with the boundary rule a version cannot match inside it. No fixture is added for it; the plan records why. The substring boundary itself is Open Question 2.
   ~~~
   after:
   ~~~
   - 2026-10-14 Edge cases / failure handling: Q Is the `+++` exclusion mutant killable? → A (self-resolved): no fixture is added for it. Corrected 2026-10-14 (unit lov-1): it is not an equivalent mutant. The header line is always `+++ b/CHANGELOG.md` or `+++ /dev/null` and names no version, but an added line whose text starts with `++` also renders as `+++...`: the shipped code skips it and the mutant counts it. That old false-violation path stays unpinned on purpose. The substring boundary itself is Open Question 2.
   ~~~
   indent: 3
18. file: `docs/plans/2026-10-14-skills-audit-followups.md`
   anchor: line matching `mutation: revert edit 3; cases (f), (g), (h1), (h2), (i) print FAIL`
   before: `   mutation: revert edit 3; cases (f), (g), (h1), (h2), (i) print FAIL, mc8-mc13 report their sed matched nothing, and the suite exits 1.`
   after: `   mutation: revert edit 3; cases (h1), (h2) and (i) print FAIL, mc8-mc11 and mc13 report that their sed matched nothing, and the suite exits 1. Cases (f) and (g) still print OK: each is a regression pin for the rewritten matcher, not a red-first test (corrected 2026-10-14, unit lov-1).`
19. file: `docs/plans/2026-10-14-skills-audit-followups.md`
   anchor: line matching `After sfu-5 passes, scribe should check the wiki changelog`
   insert-after:
   ~~~

   ## Corrections

   - 2026-10-14 (unit lov-1): the sfu-4 notes said cases (f) and (g) fail against the pre-sfu-4 script (Step 4 edit 1 and its first criterion, contract criterion 1). They print OK there, because that script already read added lines only and matched with `grep -F`; each is a regression pin for the rewritten matcher, not a red-first test. Only (h1), (h2) and (i) are red against it. The `+++`-exclusion mutant was called equivalent (Clarifications, contract sfu-4 Objective); it is not, see the corrected Clarifications line. Contract criterion 1 and the Clarifications line are corrected in place; Step 4 and the contract Objective keep their original text.
   ~~~
   indent: 3
20. file: `agents/lead-programmer.md`
   anchor: line matching `once before the first test). For hard bugs, invoke`
   before:
   ~~~
     the `tdd` skill's `SKILL.md` once before the first test). For hard bugs, invoke
   ~~~
   after:
   ~~~
     the `tdd` skill's `SKILL.md` once before the first test; in an installed
     project that is `skills/tdd/SKILL.md` under the antislop plugin's install
     directory, not a path in the project's own tree). For hard bugs, invoke
   ~~~
   indent: 3
21. file: `.claude-plugin/plugin.json` (version 0.31.169)
   anchor: line matching `"version": "0.31.168",`
   before: `  "version": "0.31.168",`
   after: `  "version": "0.31.169",`
22. file: `package.json` (version 0.31.169)
   anchor: line matching `"version": "0.31.168",`
   before: `  "version": "0.31.168",`
   after: `  "version": "0.31.169",`
23. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Skills-audit leftovers: archive, jq, runbook, skill wording, tdd location, glossary (lov-1, 0.31.169).** `docs/archive/skills/README.md` marks `grilling` and `improve-codebase-architecture` forked; the README, `CONTEXT.md` and ADR-0041 (dated correction) say `scripts/resync-vendored-skills.sh` lists the forked skills' archived originals; `skills/install-antislop` (and its `.claude/skills` mirror) says a lone read-only `jq` of the persona config is allowed; the resync runbook counts the 3 verbatim skills and names the live `tdd` companions step 4 misses; `skills/improve-codebase-architecture` and `skills/pathfinder` wording is fixed; `agents/lead-programmer.md` says where the `tdd` skill lives in an installed project; `CONTEXT.md` defines whole version, equivalent mutant and per-clone review state; the sfu follow-ups plan's sfu-4 notes are corrected.
   ~~~
   indent: 3
24. command: `node bin/cli.js --update --force-render`
   expect: 0
25. command: `git add docs/archive/skills/README.md CONTEXT.md docs/adr/0041-retire-skills-fork-and-own-archive-originals.md skills/install-antislop/SKILL.md docs/maintenance/resync-vendored-skills.md skills/improve-codebase-architecture/SKILL.md skills/pathfinder/SKILL.md docs/plans/sfu-criteria/sfu-claims.sh docs/plans/2026-10-14-skills-audit-followups.md agents/lead-programmer.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u .claude && git commit -m "docs(lov-1): skills-audit leftovers, archive, jq, runbook, tdd location, glossary (0.31.169) (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `docs/archive/skills/grilling/` and every other archived skill directory (byte-identical originals; only the README index changes)
- `adapters/` (the ports inline the `tdd` skill and have no agent-teams mode)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `bash docs/plans/lov-criteria/lov-claims.sh lov-1`
   exit: 0
   stdout: `lov-claims: lov-1 ok`
   mutation: skip edit 2; the improve-codebase-architecture row still reads rewritten, two checks print FAIL and the script exits 1.
2. run: `diff -rq skills/install-antislop .claude/skills/install-antislop`
   exit: 0
   stdout: `empty`
   mutation: skip edit 11; the mirror differs and diff exits 1.
3. run: `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-2`
   exit: 0
   stdout: `sfu-claims: sfu-2 ok`
   mutation: skip edit 16; the pathfinder check counts 0 and the script exits 1.
4. run: `node tests/context-glossary-links.test.js`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: write `[[PASS markers]]` in edit 7; the link does not resolve and the test exits 1.
5. run: `node tests/doc-relative-links.test.js`
   exit: 0
   stdout: `doc-relative-links: ok (162 links in 80 files)`
   mutation: add `[x](docs/adr/0041.md)` to the edit 5 entry; the link resolves to no tracked file, the test reports 1 broken and exits 1.
6. run: `bash docs/plans/skr-criteria/skr-archive-verify.sh grilling improve-codebase-architecture tdd diagnosing-bugs`
   exit: 0
   stdout: `ok  improve-codebase-architecture (2 files from`
   mutation: edit `docs/archive/skills/improve-codebase-architecture/SKILL.md`; that row no longer reads ok and the script exits 1.
7. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;if(a!==b||a!=='0.31.169')process.exit(1);console.log('version-sync: ok')"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 22; package.json stays 0.31.168 and the script exits 1.
8. run: `node bin/cli.js --update --force-render --dry-run | grep -c 'would be'`
   exit: 1
   stdout: `0`
   mutation: skip edit 24; the rendered agents are stale, the count is above 0 and grep exits 0.
9. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-1\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes old: 0.31.168 new: 0.31.169 offenders: -`
   mutation: skip edit 23; the commit bumps without a CHANGELOG entry naming 0.31.169 and the line reads violation.
10. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-1\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 25; no commit has the scope, test -n fails and nothing prints.
11. run: `git status --porcelain --untracked-files=no`
   exit: 0
   stdout: `empty`
   mutation: skip edit 25; the edited files are listed as modified.
12. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `no FAIL line`
   mutation: skip edit 11; the install-antislop mirror section prints FAIL and the run exits 1.

## Pre-resolved context
tdd: no prose and version-bump edits; claim checks in docs/plans/lov-criteria/lov-claims.sh
blast-radius: docs/archive/skills/README.md:3, CONTEXT.md:641, CONTEXT.md:974, docs/adr/0041-retire-skills-fork-and-own-archive-originals.md:16, skills/install-antislop/SKILL.md:315, docs/maintenance/resync-vendored-skills.md:22, skills/improve-codebase-architecture/SKILL.md:18, skills/pathfinder/SKILL.md:50, agents/lead-programmer.md:57
commit-message: docs(lov-1): skills-audit leftovers, archive, jq, runbook, tdd location, glossary (0.31.169) (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block and anchor matched exactly once at d937e67, applied in order in a fresh clone
review-packet:
~~~
unit: lov-1
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract lov-2: version-stamp-check --no-textconv and four more pinned mutants

Suggested model: sonnet

~~~~
Unit: lov-2

## Objective
`hooks/scripts/version-stamp-check.sh` reads the CHANGELOG diff with `--no-textconv` as well, so a `.gitattributes` textconv driver cannot rewrite the lines it parses. `tests/version-stamp-check.test.sh` gains cases (h4) `x.0.3.13`, (h5) a version at a sentence end, (j) a textconv driver and (k) `diff.external`, and mutation controls mc14-mc17; mc13's sed is retargeted; its labels say CHANGELOG entry; a comment and the sfu-4 CHANGELOG entry describe the `+++` mutant truthfully (not equivalent, unpinned on purpose). TDD order: edits 1-6 (tests), run the suite and see (j) FAIL and the mc15 sed match nothing, then edits 7-8. No version bump; edit 8 refreshes the `.claude/hooks` mirror and fileHashes.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers.md`. Criteria scripts: `docs/plans/lov-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `tests/version-stamp-check.test.sh` (anchors in edits 1-6)
- `hooks/scripts/version-stamp-check.sh` (anchor: line matching `# --no-color and --no-ext-diff keep a user's color.ui=always or diff.external`)
- `.claude/hooks/scripts/version-stamp-check.sh` and `.claude/persona-config.json` (rendered by edit 8)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `echo "-- CHANGELOG half (skr-5): a bump needs a same-commit CHANGELOG line naming it --"`
   before: `echo "-- CHANGELOG half (skr-5): a bump needs a same-commit CHANGELOG line naming it --"`
   after: `echo "-- CHANGELOG half (skr-5): a bump needs a same-commit CHANGELOG entry naming it --"`
2. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `run_case "(a) bump plus matching CHANGELOG line" "ok" "$r_chg_ok"`
   before: `run_case "(a) bump plus matching CHANGELOG line" "ok" "$r_chg_ok"`
   after: `run_case "(a) bump plus matching CHANGELOG entry" "ok" "$r_chg_ok"`
3. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `run_case "(c) CHANGELOG line names a different version" "violation" "$r_chg_wrong"`
   before: `run_case "(c) CHANGELOG line names a different version" "violation" "$r_chg_wrong"`
   after: `run_case "(c) CHANGELOG entry names a different version" "violation" "$r_chg_wrong"`
4. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `run_case_color "(i) color.ui=always, compliant bump" "ok" "$r_chg_ok"`
   insert-after:
   ~~~

   echo "-- CHANGELOG half hardening, second pass (lov-2) --"
   run_case_git_config() {
     # <key> <value> <run_case args...>: run_case with one git config pair forced on every git call
     local key="$1" value="$2"
     shift 2
     if ! ( export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="$key" GIT_CONFIG_VALUE_0="$value"; fail=0; run_case "$@"; exit "$fail" ); then
       fail=1
     fi
   }
   run_case_textconv() {
     # run_case with a textconv driver bound to CHANGELOG.md that turns every digit into N
     printf 'CHANGELOG.md diff=lovtc\n' > "$tmproot/lov-attributes"
     if ! ( export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.attributesFile GIT_CONFIG_VALUE_0="$tmproot/lov-attributes" \
              GIT_CONFIG_KEY_1=diff.lovtc.textconv GIT_CONFIG_VALUE_1='sed s/[0-9]/N/g'; fail=0; run_case "$@"; exit "$fail" ); then
       fail=1
     fi
   }

   echo "chg h4" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.13
   changelog_line x.0.3.13
   r_chg_h4=$(snap chglog-h4-dot-on-left)
   run_case "(h4) x.0.3.13 does not name 0.3.13" "violation" "$r_chg_h4"

   echo "chg h5" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.14
   printf '**Bumped to 0.3.14.**\n' >> "$repo/CHANGELOG.md"
   r_chg_h5=$(snap chglog-h5-dot-on-right)
   run_case "(h5) 0.3.14 at the end of a sentence names 0.3.14" "ok" "$r_chg_h5"

   run_case_textconv "(j) textconv driver on CHANGELOG.md, compliant bump" "ok" "$r_chg_ok"
   run_case_git_config diff.external false "(k) diff.external set, compliant bump" "ok" "$r_chg_ok"
   ~~~
   indent: 3
5. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `if mutate no-color-removed 's/git diff --no-color --no-ext-diff --no-renames/git diff --no-renames/'; then`
   before: `if mutate no-color-removed 's/git diff --no-color --no-ext-diff --no-renames/git diff --no-renames/'; then`
   after: `if mutate no-color-removed 's/git diff --no-color /git diff /'; then`
6. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `echo "-- offender collection is computed, not hardcoded (item 5) --"`
   before: `echo "-- offender collection is computed, not hardcoded (item 5) --"`
   after:
   ~~~
   if mutate no-ext-diff-removed 's/git diff --no-color --no-ext-diff /git diff --no-color /'; then
     run_case_git_config diff.external false "(mc14) --no-ext-diff removed: (k) should flip to" "violation" "$r_chg_ok" "$MUTANT"
   fi

   if mutate no-textconv-removed 's/--no-ext-diff --no-textconv /--no-ext-diff /'; then
     run_case_textconv "(mc15) --no-textconv removed: (j) should flip to" "violation" "$r_chg_ok" "$MUTANT"
   fi

   if mutate left-boundary-digit-only 's/(?<!\[0-9.\])/(?<![0-9])/'; then
     run_case "(mc16) left boundary without the dot: (h4) should flip to" "ok" "$r_chg_h4" "$MUTANT"
   fi

   if mutate right-boundary-with-dot 's/(?!\[0-9\])/(?![0-9.])/'; then
     run_case "(mc17) right boundary with the dot: (h5) should flip to" "violation" "$r_chg_h5" "$MUTANT"
   fi

   # Not pinned on purpose: dropping the +++ exclusion. The header line
   # `+++ b/CHANGELOG.md` never names a version, but an added line whose text
   # starts with "++" also renders as "+++..."; the shipped code skips such a
   # line and that mutant counts it, so the mutant is not equivalent. A fixture
   # would pin that old false violation, so none is added (unit lov-2).

   echo "-- offender collection is computed, not hardcoded (item 5) --"
   ~~~
   indent: 3
7. file: `hooks/scripts/version-stamp-check.sh`
   anchor: line matching `# --no-color and --no-ext-diff keep a user's color.ui=always or diff.external`
   before:
   ~~~
   # --no-color and --no-ext-diff keep a user's color.ui=always or diff.external
   # from rewriting the lines this parses. python3 reads all of its input, so
   # pipefail never sees a SIGPIPE from an early exit.
   changelog_adds_version() {
     git diff --no-color --no-ext-diff --no-renames "$1^" "$1" -- CHANGELOG.md 2>/dev/null \
   ~~~
   after:
   ~~~
   # --no-color, --no-ext-diff and --no-textconv keep a user's color.ui=always,
   # diff.external or .gitattributes textconv driver from rewriting the lines this
   # parses. python3 reads all of its input, so pipefail never sees a SIGPIPE from
   # an early exit.
   changelog_adds_version() {
     git diff --no-color --no-ext-diff --no-textconv --no-renames "$1^" "$1" -- CHANGELOG.md 2>/dev/null \
   ~~~
   indent: 3
8. command: `node bin/cli.js --update --force-render`
   expect: 0
9. file: `CHANGELOG.md`
   anchor: line matching `which pin every mutant the skr-5 review found surviving except the`
   before:
   ~~~
   **version-stamp-check CHANGELOG match hardened (sfu-4).** `hooks/scripts/version-stamp-check.sh` reads the CHANGELOG diff with `--no-color --no-ext-diff`, counts added lines only, and matches the version literally as a whole version (0.31.16 is no longer named by 0.31.166 or 10.31.16; `v0.31.16` still is); `tests/version-stamp-check.test.sh` gains cases (e)-(i) and mutation controls mc8-mc13, which pin every mutant the skr-5 review found surviving except the `+++`-exclusion one, an equivalent mutant.
   ~~~
   after:
   ~~~
   **version-stamp-check CHANGELOG match hardened (sfu-4).** `hooks/scripts/version-stamp-check.sh` reads the CHANGELOG diff with `--no-color --no-ext-diff`, counts added lines only, and matches the version literally as a whole version (0.31.16 is no longer named by 0.31.166 or 10.31.16; `v0.31.16` still is); `tests/version-stamp-check.test.sh` gains cases (e)-(i) and mutation controls mc8-mc13, which pin every mutant the skr-5 review found surviving except the `+++`-exclusion one. That mutant is not equivalent (an added line whose text starts with `++` renders as `+++...`) and stays unpinned on purpose (wording corrected by lov-2).
   ~~~
   indent: 3
10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **version-stamp-check: --no-textconv and four more pinned mutants (lov-2).** `hooks/scripts/version-stamp-check.sh` also reads the CHANGELOG diff with `--no-textconv`, so a `.gitattributes` textconv driver cannot rewrite the lines it parses. `tests/version-stamp-check.test.sh` gains cases (h4) `x.0.3.13`, (h5) a version at the end of a sentence, (j) a textconv driver and (k) `diff.external`, with mutation controls mc14-mc17; its case labels say CHANGELOG entry, and a comment records why the `+++`-exclusion mutant stays unpinned.
   ~~~
   indent: 3
11. command: `git add hooks/scripts/version-stamp-check.sh tests/version-stamp-check.test.sh CHANGELOG.md && git add -u .claude && git commit -m "test(lov-2): version-stamp-check --no-textconv and four more pinned mutants (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/` and `templates/` (no version-stamped change in this unit)
- `hooks/hooks.json` (the script stays unregistered, a reviewer-invoked helper)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `bash tests/version-stamp-check.test.sh`
   exit: 0
   stdout: `OK   (mc17) right boundary with the dot`
   mutation: skip edit 7; case (j) prints FAIL, mc15 reports its sed matched nothing, and the suite exits 1.
2. run: `bash tests/version-stamp-check.test.sh | grep -cE '^OK   [(](h4|h5|j|k|mc13|mc14|mc15|mc16|mc17)[)]'`
   exit: 0
   stdout: `9`
   mutation: skip edit 6; the four mc14-mc17 lines are missing and the count is 5.
3. run: `grep -c 'CHANGELOG line' tests/version-stamp-check.test.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; the count is 1 and grep exits 0.
4. run: `bash hooks/scripts/version-stamp-check.sh e9a2bf3~1..879c678`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes old: 0.31.162 new: 0.31.167 offenders: -`
   mutation: make the right boundary (?![0-9.]) in the hook; a real CHANGELOG line of that range no longer matches and the line reads violation.
5. run: `diff -q hooks/scripts/version-stamp-check.sh .claude/hooks/scripts/version-stamp-check.sh`
   exit: 0
   stdout: `empty`
   mutation: skip edit 8; the mirror differs and diff exits 1.
6. run: `node tests/filehashes-currency.test.js`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: skip edit 8; the recorded hash of the mirror is stale and the test exits 1.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-2\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
8. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-2\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; no commit has the scope, test -n fails and nothing prints.
9. run: `git status --porcelain --untracked-files=no`
   exit: 0
   stdout: `empty`
   mutation: skip edit 11; the edited files are listed as modified.
10. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `no FAIL line`
   mutation: skip edit 7; the version-stamp-check section prints FAIL and the run exits 1.

## Pre-resolved context
tdd: yes tests/version-stamp-check.test.sh
blast-radius: hooks/scripts/version-stamp-check.sh:66, hooks/scripts/version-stamp-check.sh:69, tests/version-stamp-check.test.sh:88, tests/version-stamp-check.test.sh:184, tests/version-stamp-check.test.sh:299
commit-message: test(lov-2): version-stamp-check --no-textconv and four more pinned mutants (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block and anchor matched exactly once on the tree lov-1 leaves, applied in order in a fresh clone of d937e67
review-packet:
~~~
unit: lov-2
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract lov-3: resync offline test and relative-link test hardening

Suggested model: haiku

~~~~
Unit: lov-3

## Objective
`tests/resync-vendored-skills-offline.test.sh` also checks, per skill, that the FILES rows name every tracked file under the skill's drift-tracked root, and that each row's upstream path ends in the same skill-relative path as its local copy, so a dropped row or an upstream file-name typo fails offline. `tests/doc-relative-links.test.js` fails on a SCOPE entry that matches no tracked file, checks links with a title and `<angle>` destinations, and reports an unparsable destination or a malformed percent escape as broken instead of skipping or crashing. TDD order: edits 1-3, then run both tests (both still pass on the tree, which has no such defect) and the worktree criteria 3-4. No version bump.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers.md`. Criteria scripts: `docs/plans/lov-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `tests/resync-vendored-skills-offline.test.sh` (anchor: line matching `[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok"`)
- `tests/doc-relative-links.test.js` (anchors: line matching `// Unit sfu-5: every relative markdown link` and line matching `const files = git(['ls-files', '-z', '--', ...SCOPE])`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `tests/resync-vendored-skills-offline.test.sh`
   anchor: line matching `[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok"`
   before: `[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"`
   after:
   ~~~
   # lov-3: every tracked file under a skill's drift-tracked root has a FILES row, and
   # each row's upstream path ends in the same skill-relative path as its local copy.
   root_of() { case " $FORKED " in *" $1 "*) echo "docs/archive/skills/$1/" ;; *) echo "skills/$1/" ;; esac; }
   for s in $order; do
     root="$(root_of "$s")"
     want_files="$(git ls-files -- "$root" | sort | tr '\n' ' ')"
     have_files="$(printf '%s\n' "$rows" | awk -F: -v s="$s" '$1 == s {print $3}' | sort | tr '\n' ' ')"
     [ "$want_files" = "$have_files" ] && ok "$s: FILES rows cover every tracked file under $root" || no "$s: FILES rows '$have_files' differ from the tracked files '$want_files' under $root"
   done
   while IFS=: read -r skill type local upstream extra; do
     [ -n "$skill" ] || continue
     rel="${local#"$(root_of "$skill")"}"
     case "$upstream" in */"$skill/$rel") ok "$skill $rel: upstream path names the same file" ;; *) no "$skill $rel: upstream path '$upstream' does not end in $skill/$rel" ;; esac
   done <<< "$rows"

   [ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"
   ~~~
   indent: 3
2. file: `tests/doc-relative-links.test.js`
   anchor: line matching `// Unit sfu-5: every relative markdown link in the maintained docs resolves to a`
   before:
   ~~~
   // Unit sfu-5: every relative markdown link in the maintained docs resolves to a
   // tracked file or directory, relative to the linking file's own directory (the way GitHub
   // renders it). Fenced code is skipped. URLs and <angle> targets are skipped.
   ~~~
   after:
   ~~~
   // Unit sfu-5, hardened by lov-3: every relative markdown link in the maintained docs resolves
   // to a tracked file or directory, relative to the linking file's own directory (the way GitHub
   // renders it). Fenced code is skipped, and so are URLs and pure #fragment links. A link may
   // carry a title or an <angle-bracket> destination; a destination that cannot be parsed, or
   // whose percent escapes are malformed, is reported as broken, and so is a scope entry that
   // matches no tracked file.
   ~~~
   indent: 3
3. file: `tests/doc-relative-links.test.js`
   anchor: line matching `const files = git(['ls-files', '-z', '--', ...SCOPE]).filter((f) => f.endsWith('.md'));`
   before:
   ~~~
   const files = git(['ls-files', '-z', '--', ...SCOPE]).filter((f) => f.endsWith('.md'));
   let links = 0;
   let broken = 0;
   for (const f of files) {
     const text = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^\s*(```|~~~)[\s\S]*?^\s*\1/gm, '');
     for (const m of text.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)) {
       const target = m[1];
       if (/^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith('<')) continue;
       links += 1;
       const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(f), decodeURI(target))).replace(/\/$/, '');
       if (!tracked.has(resolved)) {
         broken += 1;
         console.log(`FAIL ${f}: ${target}`);
       }
     }
   }
   ~~~
   after:
   ~~~
   let broken = 0;
   const bad = (msg) => { broken += 1; console.log(`FAIL ${msg}`); };
   for (const entry of SCOPE) {
     if (git(['ls-files', '-z', '--', entry]).length === 0) bad(`scope entry ${entry} matches no tracked file`);
   }
   const files = git(['ls-files', '-z', '--', ...SCOPE]).filter((f) => f.endsWith('.md'));
   const DEST = /^\s*(?:<([^<>]*)>|(\S+))(?:\s+(?:"[^"]*"|'[^']*'|\([^()]*\)))?\s*$/;
   let links = 0;
   for (const f of files) {
     const text = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^\s*(```|~~~)[\s\S]*?^\s*\1/gm, '');
     for (const m of text.matchAll(/\]\(([^)\n]*)\)/g)) {
       const d = DEST.exec(m[1]);
       if (!d) { bad(`${f}: (${m[1]}) is not a parsable link destination`); continue; }
       const target = (d[1] !== undefined ? d[1] : d[2]).split('#')[0];
       if (target === '' || /^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
       links += 1;
       let decoded;
       try { decoded = decodeURI(target); } catch (e) { bad(`${f}: ${target} has a malformed percent escape`); continue; }
       const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(f), decoded)).replace(/\/$/, '');
       if (!tracked.has(resolved)) bad(`${f}: ${target}`);
     }
   }
   ~~~
   indent: 3
4. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Resync offline test and relative-link test hardened (lov-3).** `tests/resync-vendored-skills-offline.test.sh` now fails when a skill's FILES rows miss a tracked file under its drift-tracked root, or when a row's upstream path names a different file than its local copy. `tests/doc-relative-links.test.js` now fails on a SCOPE entry that matches no tracked file, checks links with a title and `<angle>` destinations, and reports an unparsable destination or a malformed percent escape as broken.
   ~~~
   indent: 3
5. command: `git add tests/resync-vendored-skills-offline.test.sh tests/doc-relative-links.test.js CHANGELOG.md && git commit -m "test(lov-3): resync offline test and relative-link test hardening (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `scripts/resync-vendored-skills.sh` (tested, not changed)
- `tests/validate.sh` (both tests are already registered)
- `tests/validate-lanes.sh` and `tests/reviewed-dir-leak-guard.test.sh` (another slice's files)

## Acceptance criteria
1. run: `bash tests/resync-vendored-skills-offline.test.sh`
   exit: 0
   stdout: `resync-vendored-skills-offline: ok`
   mutation: delete the `tdd:doc:docs/archive/skills/tdd/mocking.md:` row from scripts/resync-vendored-skills.sh; the tdd coverage line prints FAIL and the test exits 1 (proof: run in a scratch clone, 2026-10-14).
2. run: `bash tests/resync-vendored-skills-offline.test.sh | grep -cE '^OK   .*(FILES rows cover every tracked file|upstream path names the same file)'`
   exit: 0
   stdout: `22`
   mutation: skip edit 1; neither check runs, the count is 0 and grep exits 1.
3. run: `d=$(mktemp -d) && git worktree add -q --detach "$d" HEAD && printf '\n[a](missing-a.md "t")\n[b](<missing b.md>)\n[c](adr/%%E0%%A4%%A.md)\n' >> "$d/docs/trust-model.md" && (cd "$d" && node tests/doc-relative-links.test.js); rc=$?; git worktree remove --force "$d"; echo "rc=$rc"`
   exit: 0
   stdout: `doc-relative-links: 3 broken of 165 links`
   mutation: skip edit 3; the titled and angle links are skipped and decodeURI throws on the third, so the summary line never prints.
4. run: `d=$(mktemp -d) && git worktree add -q --detach "$d" HEAD && git -C "$d" mv docs/trust-model.md docs/trust-model-moved.md && (cd "$d" && node tests/doc-relative-links.test.js); rc=$?; git worktree remove --force "$d"; echo "rc=$rc"`
   exit: 0
   stdout: `FAIL scope entry docs/trust-model.md matches no tracked file`
   mutation: skip edit 3; the renamed entry drops out silently and that line never prints.
5. run: `node tests/doc-relative-links.test.js`
   exit: 0
   stdout: `doc-relative-links: ok (162 links in 80 files)`
   mutation: make DEST reject titles (drop the title group); no link in scope has a title today, so this stays ok, which is why criterion 3 carries the proof; a broken link anywhere in scope makes it exit 1.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-3\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-3\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no commit has the scope, test -n fails and nothing prints.
8. run: `git status --porcelain --untracked-files=no`
   exit: 0
   stdout: `empty`
   mutation: skip edit 5; the edited files are listed as modified.
9. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `no FAIL line`
   mutation: break a relative link in docs/trust-model.md; the doc-relative-links section prints FAIL and the run exits 1.

## Pre-resolved context
tdd: yes tests/doc-relative-links.test.js
blast-radius: tests/resync-vendored-skills-offline.test.sh:36, tests/doc-relative-links.test.js:3, tests/doc-relative-links.test.js:19, tests/validate.sh:921
commit-message: test(lov-3): resync offline test and relative-link test hardening (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block and anchor matched exactly once on the tree lov-2 leaves, applied in order in a fresh clone of d937e67
review-packet:
~~~
unit: lov-3
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract lov-4: task-master issue-body layout matches contract-guard

Suggested model: haiku

~~~~~~~
Unit: lov-4

## Objective
`agents/task-master.md` requires the issue-body dispatch contract (lead and scribe) to be one tilde-fenced block whose first interior line is `Unit: <task-id>`, with a fence longer than any fence inside it, and documents the layout as a marked issue-body example; `skills/pathfinder/SKILL.md` says the same for a real tracker. `tests/contract-examples.test.js` pipes that example, with the lead example substituted in, through `bin/contract-guard.js` and expects `haiku ... score=7/7`, and expects `reason=no-contract` once the fence lines are removed. `bin/contract-guard.js` is unchanged. Version 0.31.170, rendered. TDD order: edit 4 (test) first and see it FAIL (the markers are missing), then the rest.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers.md`. Criteria scripts: `docs/plans/lov-criteria/`. Background only: `gh issue view 531 --repo Storreslara/AntiSlop` (an issue body with the unfenced layout).

## Affected files
- `agents/task-master.md` (anchors: line matching `- **Contract home and precedence.** On the standard path the contract lives`, line matching `, exactly. Score it with`, line matching `<!-- lead-contract-example:end -->`)
- `skills/pathfinder/SKILL.md` (anchor: line matching `- **A real issue tracker** (GitHub, Linear, ...) -> publish one issue per unit`)
- `tests/contract-examples.test.js` (anchor: line matching `console.log(failures === 0 ? '\nAll contract-examples checks passed.'`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.169",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `agents/task-master.md`
   anchor: line matching `- **Contract home and precedence.** On the standard path the contract lives`
   before:
   ~~~
   - **Contract home and precedence.** On the standard path the contract lives
     in the issue body under `## Dispatch contract`. On the fast path
     spec-master writes it, and task-master never runs the fast path; there it
     lives in the
     plan's `### Unit:` block. For the implementer the contract outranks the issue
   ~~~
   after:
   ~~~
   - **Contract home and precedence.** On the standard path the contract lives
     in the issue body under `## Dispatch contract`, last, as one fenced block
     whose first interior line is `Unit: <task-id>`. Use a tilde fence longer
     than any fence inside the contract (`~~~~` around `~~~` payloads):
     `bin/contract-guard.js` finds a contract only as such a block, so an
     unfenced contract after the issue's prose scores `reason=no-contract`, a
     guard demotion to `sonnet`. See the issue-body example below. On the fast
     path spec-master writes it, and task-master never runs the fast path;
     there it lives in the plan's fenced `Unit:` block, fenced the same way.
     For the implementer the contract outranks the issue
   ~~~
   indent: 3
2. file: `agents/task-master.md`
   anchor: line matching `, exactly. Score it with`
   before:
   ~~~
   heading `## Dispatch contract (scribe)`, exactly. Score it with
   ~~~
   after:
   ~~~
   heading `## Dispatch contract (scribe)`, exactly, fenced the same way as the
   lead contract. Score it with
   ~~~
   indent: 3
3. file: `agents/task-master.md`
   anchor: line matching `<!-- lead-contract-example:end -->`
   insert-after:
   ~~~~~

   **Issue-body layout.** A published unit's issue body keeps its prose first and
   the contract last, fenced; `tests/contract-examples.test.js` substitutes the
   lead example above for the placeholder line and runs `bin/contract-guard.js`
   over the result.

   <!-- issue-body-layout-example:begin -->
   ```
   Step 3 of the demo slice (umbrella #998). Stamped: yes.

   Suggested model: haiku

   Depends on / blocked by: #997.

   ## Dispatch contract
   ~~~~
   <the lead contract above, `Unit: demo-7` first>
   ~~~~
   ```
   <!-- issue-body-layout-example:end -->
   ~~~~~
   indent: 3
4. file: `tests/contract-examples.test.js`
   anchor: line matching `console.log(failures === 0 ? '\nAll contract-examples checks passed.'`
   before:
   ~~~~~
   console.log(failures === 0 ? '\nAll contract-examples checks passed.' : `\n${failures} check(s) failed.`);
   ~~~~~
   after:
   ~~~~~
   // lov-4: the issue-body layout task-master documents is one bin/contract-guard.js accepts.
   function guard(text, id) {
     const r = spawnSync('node', ['bin/contract-guard.js', '-', `--unit=${id}`], { cwd: REPO_ROOT, encoding: 'utf8', input: text });
     return r.stdout.trim();
   }
   function issueBody() {
     const lead = example('lead-contract-example');
     return example('issue-body-layout-example').split('\n')
       .map((l) => (l === '<the lead contract above, `Unit: demo-7` first>' ? lead : l)).join('\n');
   }

   check('issue-body layout example scores haiku through contract-guard', () => {
     assert.strictEqual(guard(issueBody(), 'demo-7'), 'contract-guard: haiku unit=demo-7 shape=lead score=7/7');
   });

   check('issue-body layout without its ~~~~ fence lines scores no-contract', () => {
     const unfenced = issueBody().split('\n').filter((l) => l !== '~~~~').join('\n');
     assert.strictEqual(guard(unfenced, 'demo-7'), 'contract-guard: sonnet unit=demo-7 shape=lead reason=no-contract');
   });

   console.log(failures === 0 ? '\nAll contract-examples checks passed.' : `\n${failures} check(s) failed.`);
   ~~~~~
   indent: 3
5. file: `skills/pathfinder/SKILL.md`
   anchor: line matching `- **A real issue tracker** (GitHub, Linear, ...) -> publish one issue per unit`
   before:
   ~~~
   - **A real issue tracker** (GitHub, Linear, ...) -> publish one issue per unit in dependency order (blockers first), so each unit's blocking edges can reference real identifiers. Use the platform's native blocking or sub-issue relationship where it has one; otherwise set each unit's "Blocked by" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise.
   ~~~
   after:
   ~~~
   - **A real issue tracker** (GitHub, Linear, ...) -> publish one issue per unit in dependency order (blockers first), so each unit's blocking edges can reference real identifiers. Use the platform's native blocking or sub-issue relationship where it has one; otherwise set each unit's "Blocked by" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise. When a unit carries a dispatch contract, put it last, under `## Dispatch contract`, as one fenced block whose first interior line is `Unit: <task-id>`, in a tilde fence longer than any fence inside it (`~~~~` around `~~~` payloads); `bin/contract-guard.js` reads only that shape.
   ~~~
   indent: 3
6. file: `.claude-plugin/plugin.json` (version 0.31.170)
   anchor: line matching `"version": "0.31.169",`
   before: `  "version": "0.31.169",`
   after: `  "version": "0.31.170",`
7. file: `package.json` (version 0.31.170)
   anchor: line matching `"version": "0.31.169",`
   before: `  "version": "0.31.169",`
   after: `  "version": "0.31.170",`
8. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Issue-body contracts are fenced so contract-guard finds them (lov-4, 0.31.170).** `agents/task-master.md` requires the issue-body dispatch contract, lead or scribe, to be one tilde-fenced block whose first interior line is `Unit: <task-id>`, last in the body, and documents the layout as a marked example; `skills/pathfinder/SKILL.md` says the same for a real tracker. Every skr issue body had an unfenced contract after its prose, which `bin/contract-guard.js` scores `reason=no-contract` (a guard demotion to sonnet). `tests/contract-examples.test.js` runs the guard over the documented layout (haiku 7/7) and over the same body unfenced (no-contract). The guard is unchanged.
   ~~~
   indent: 3
9. command: `node bin/cli.js --update --force-render`
   expect: 0
10. command: `git add agents/task-master.md skills/pathfinder/SKILL.md tests/contract-examples.test.js .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u .claude && git commit -m "fix(lov-4): fence the issue-body dispatch contract so contract-guard finds it (0.31.170) (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/contract-guard.js` and `bin/contract-score.js` (the guard is unchanged by design)
- `agents/orchestrator.md` (its guard step already reads the issue body this layout produces)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `node tests/contract-examples.test.js`
   exit: 0
   stdout: `All contract-examples checks passed.`
   mutation: delete the two `~~~~` lines inside the example in edit 3; the haiku check prints FAIL and the test exits 1.
2. run: `node tests/contract-examples.test.js | grep -c '^OK   issue-body layout'`
   exit: 0
   stdout: `2`
   mutation: skip edit 4; the count is 0 and grep exits 1.
3. run: `bash docs/plans/lov-criteria/lov-claims.sh lov-4`
   exit: 0
   stdout: `lov-claims: lov-4 ok`
   mutation: skip edit 5; the pathfinder check counts 0 and the script exits 1.
4. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;if(a!==b||a!=='0.31.170')process.exit(1);console.log('version-sync: ok')"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 7; package.json stays 0.31.169 and the script exits 1.
5. run: `node bin/cli.js --update --force-render --dry-run | grep -c 'would be'`
   exit: 1
   stdout: `0`
   mutation: skip edit 9; the rendered task-master is stale, the count is above 0 and grep exits 0.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-4\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes old: 0.31.169 new: 0.31.170 offenders: -`
   mutation: skip edit 8; the commit bumps without a CHANGELOG entry naming 0.31.170 and the line reads violation.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-4\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no commit has the scope, test -n fails and nothing prints.
8. run: `git status --porcelain --untracked-files=no`
   exit: 0
   stdout: `empty`
   mutation: skip edit 10; the edited files are listed as modified.
9. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `no FAIL line`
   mutation: skip edit 9; the rendered-mirror section prints FAIL and the run exits 1.

## Pre-resolved context
tdd: yes tests/contract-examples.test.js
blast-radius: agents/task-master.md:62, agents/task-master.md:315, agents/task-master.md:334, skills/pathfinder/SKILL.md:51, tests/contract-examples.test.js:64, agents/orchestrator.md:515
commit-message: fix(lov-4): fence the issue-body dispatch contract so contract-guard finds it (0.31.170) (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block and anchor matched exactly once on the tree lov-3 leaves, applied in order in a fresh clone of d937e67
review-packet:
~~~
unit: lov-4
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~~~~

### Contract lov-5: review-join ownerless-stamp residual, documented

Suggested model: sonnet

~~~~
Unit: lov-5

## Objective
The SubagentStop block in `hooks/scripts/lib/stop-gate-core.sh` no longer tells a reviewer that every unsatisfied stamp is a unit "you were dispatched for": it says a review-join stamp names no owner, and that a reviewer not dispatched for a listed unit must not write its marker but report the block and wait. Exit codes and the join logic are unchanged. `docs/harness-glossary.md` **review-join stamp** drops "without cross-dispatch interference" and records the residual. `tests/review-join.test.sh` gains case (residual-ownerless-stamp), which reproduces the foreign-stamp block and requires the new text. TDD order: edit 1 (test) first and see it FAIL, then edits 2-5. No version bump; edit 3 refreshes the `.claude` mirror, the two adapter copies and fileHashes.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers.md`. Criteria scripts: `docs/plans/lov-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `tests/review-join.test.sh` (anchor: line matching `exit "$fail"`)
- `hooks/scripts/lib/stop-gate-core.sh` (anchor: line matching `block "No verdict is recorded for the unit(s) you were dispatched for: ${missing}.`)
- `.claude/hooks/scripts/lib/stop-gate-core.sh`, `adapters/codex/hooks/scripts/lib/stop-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh`, `.claude/persona-config.json` (rendered by edit 3)
- `docs/harness-glossary.md` (anchor: line matching `  Replaces the global clear-watermark; enables per-unit verdict coupling without`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `tests/review-join.test.sh` (apply with the Edit tool: the payload names the per-clone review-record directory, see R3)
   anchor: line matching `exit "$fail"`
   before: `exit "$fail"`
   after:
   ~~~
   # --- (residual-ownerless-stamp, lov-5): a stamp names no owner. Reviewer rev-a's own
   # stamp is consumed on its first stop; a second unit is dispatched; rev-a stops again
   # and is blocked on the other unit's stamp. Pinned as a known residual (see the
   # review-join stamp entry in docs/harness-glossary.md); a fix that attributes stamps
   # to their reviewer flips rc2 to 0, and this case must then be rewritten.
   dir="$(make_project residual-ownerless)"
   run_route_gate "$dir" "$(reviewer_payload $'Unit: own-a\n\nReview.')" || true
   printf 'PASS own-a 2026-10-14T00:00:00Z commit: abc1234 criteria: true\n' > "$dir/.claude/reviewed/own-a.pass"
   stop_a='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-a","session_id":"s-a"}'
   rc1=0
   printf '%s' "$stop_a" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>/dev/null || rc1=$?
   run_route_gate "$dir" "$(reviewer_payload $'Unit: other-b\n\nReview.')" || true
   rc2=0
   err="$(printf '%s' "$stop_a" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>&1 >/dev/null)" || rc2=$?
   if [ "$rc1" = 0 ] && [ "$rc2" = 2 ] \
      && grep -q 'marker=MISSING unit=other-b' "$dir/.claude/review-audit.log" \
      && printf '%s' "$err" | grep -q 'A review-join stamp names no owner' \
      && printf '%s' "$err" | grep -q 'report this block to your dispatcher and wait'; then
     echo "OK   (residual-ownerless-stamp) a consumed reviewer is blocked on another unit's stamp, and the block tells it to report and wait"
   else
     echo "FAIL (residual-ownerless-stamp) expected rc1=0, rc2=2 and the ownerless-stamp guidance (rc1=$rc1 rc2=$rc2)"
     fail=1
   fi

   exit "$fail"
   ~~~
   indent: 3
2. file: `hooks/scripts/lib/stop-gate-core.sh`
   anchor: line matching `block "No verdict is recorded for the unit(s) you were dispatched for: ${missing}.`
   before: `      block "No verdict is recorded for the unit(s) you were dispatched for: ${missing}. A v3 PASS or FAIL marker must be written for each, first line exactly:`
   after: `      block "No verdict is recorded for the stamped unit(s): ${missing}. A review-join stamp names no owner, so a unit another reviewer is reviewing right now is listed here too: if you were not dispatched for one of them, do not write its marker; report this block to your dispatcher and wait. For each unit you did review, a v3 PASS or FAIL marker must be written, first line exactly:`
3. command: `node bin/cli.js --update --force-render`
   expect: 0
4. file: `docs/harness-glossary.md`
   anchor: line matching `  Replaces the global clear-watermark; enables per-unit verdict coupling without`
   before:
   ~~~
     Replaces the global clear-watermark; enables per-unit verdict coupling without
     cross-dispatch interference. See [ADR-0016](adr/0016-per-unit-review-join.md)
   ~~~
   after:
   ~~~
     Replaces the global clear-watermark and couples each verdict to its own unit.
     Residual (unit lov-5, 2026-10-14): A stamp names no owner, and every
     reviewer's SubagentStop classifies every stamp in the directory, so a
     reviewer whose own stamp was already consumed (a resumed or second turn) is
     blocked while another unit's freshly dispatched review is unsatisfied. The
     block message says so; that reviewer reports and waits, and never writes a
     marker for a unit it did not review. See [ADR-0016](adr/0016-per-unit-review-join.md)
   ~~~
   indent: 3
5. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Review-join ownerless-stamp residual documented (lov-5).** A review-join stamp names no owner, so a reviewer whose own stamp was already consumed can be blocked at SubagentStop on another unit's stamp. The block message in `hooks/scripts/lib/stop-gate-core.sh` (and its `.claude` and adapter copies) no longer says the listed units are ones "you were dispatched for"; it tells a reviewer not dispatched for a listed unit to report the block and wait rather than write its marker. The **review-join stamp** glossary entry records the residual, and `tests/review-join.test.sh` reproduces it (case residual-ownerless-stamp). Exit codes are unchanged; an ownership fix is left to a later spec.
   ~~~
   indent: 3
6. command: `git add tests/review-join.test.sh hooks/scripts/lib/stop-gate-core.sh docs/harness-glossary.md CHANGELOG.md adapters/codex/hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh && git add -u .claude && git commit -m "fix(lov-5): review-join block message names the ownerless-stamp residual (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `hooks/scripts/lib/reviewer-route-gate-core.sh` (stamp writing is unchanged)
- `hooks/hooks.json` (no new hook event)
- `docs/adr/0016-per-unit-review-join.md` (the design is unchanged; the residual is recorded in the glossary)

## Acceptance criteria
1. run: `bash tests/review-join.test.sh`
   exit: 0
   stdout: `OK   (residual-ownerless-stamp)`
   mutation: skip edit 2; the block text lacks the guidance, the case prints FAIL and the test exits 1.
2. run: `bash tests/review-join.test.sh | grep -c '^OK   (residual-ownerless-stamp)'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; the case is absent, the count is 0 and grep exits 1.
3. run: `bad=0; for f in .claude/hooks/scripts/lib/stop-gate-core.sh adapters/codex/hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh; do cmp -s hooks/scripts/lib/stop-gate-core.sh "$f" || { echo "differs: $f"; bad=1; }; done; [ "$bad" = 0 ] && echo copies-identical`
   exit: 0
   stdout: `copies-identical`
   mutation: skip edit 3; three `differs:` lines print, `copies-identical` does not, and the command exits 1.
4. run: `bash tests/adapter-stop-gate-parity.test.sh`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: skip edit 3; the adapter copies differ from the source and the byte-identity check prints FAIL.
5. run: `node tests/filehashes-currency.test.js`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: skip edit 3; the recorded hashes are stale and the test exits 1.
6. run: `bash docs/plans/lov-criteria/lov-claims.sh lov-5`
   exit: 0
   stdout: `lov-claims: lov-5 ok`
   mutation: skip edit 4; the glossary still says "without cross-dispatch interference" and the script exits 1.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-5\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
8. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lov-5\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; no commit has the scope, test -n fails and nothing prints.
9. run: `git status --porcelain --untracked-files=no`
   exit: 0
   stdout: `empty`
   mutation: skip edit 6; the edited files are listed as modified.
10. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `no FAIL line`
   mutation: skip edit 2; the review-join section prints FAIL and the run exits 1.

## Pre-resolved context
tdd: yes tests/review-join.test.sh
blast-radius: hooks/scripts/lib/stop-gate-core.sh:469, hooks/scripts/lib/reviewer-route-gate-core.sh:149, docs/harness-glossary.md:1130, tests/review-join.test.sh:615, tests/adapter-stop-gate-parity.test.sh:5
commit-message: fix(lov-5): review-join block message names the ownerless-stamp residual (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block and anchor matched exactly once on the tree lov-4 leaves, applied in order in a fresh clone of d937e67
review-packet:
~~~
unit: lov-5
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

## Open Questions

1. (Non-blocking; for a later spec, holds no unit.) How should a review-join stamp be tied to the reviewer that owns it? Recommended default: **B**.
   - **B: bind at `SubagentStart`.** A new `SubagentStart` hook writes `owner=<agent_id>` onto the newest unbound stamp, and `review_join_state` at SubagentStop considers only the stopping agent's own stamps (unbound stamps keep today's behaviour). Needs a new hook registration, adapter decisions (Codex and Cursor have no measured equivalent), and a race argument for back-to-back dispatches.
   - **C: read the stopping agent's own prompt.** At SubagentStop, read the `Unit:` line from the first user message in `agent_transcript_path` and consider only that unit's stamp. No new hook, but it depends on the transcript format, and the transcript is a new input for a gate.
   - **A: keep the documented residual only** (what lov-5 ships).
   lov-5's test case is the reproduction either fix must flip.

## Self-check
- CHK1: Does every Goal clause and every verified finding L1-L13 map to a unit criterion? — PASS. L1-L7 and L8's plan text: lov-1 criteria 1-6; L8's test comment and CHANGELOG wording and L9: lov-2 criteria 1-3; L10-L11: lov-3 criteria 1-4; L12: lov-4 criteria 1-3; L13: lov-5 criteria 1-6.
- CHK2: Are the prose units' criteria claim-anchored rather than existence greps (the docs-unit FAIL class)? — PASS. `lov-claims.sh` counts the wrong phrase (want 0) and the corrected phrase (want 1) per claim; at `d937e67` every check is red (`lov-1` 30 of 30, `lov-4` 5 of 5, `lov-5` 4 of 4), and every one is green after its unit.
- CHK3: Do lov-1 and lov-4 agree on the version sequence? — PASS. lov-1 0.31.168 -> 0.31.169, lov-4 0.31.169 -> 0.31.170; each has its own version-sync and version-stamp-check criterion over its own commit.
- CHK4: Is every per-unit commit criterion independent of HEAD? — PASS. Each range comes from the unit's own commit found by subject scope.
- CHK5: Does any unit edit a skill that an adapter port inlines without the port? — PASS. lov-1 and lov-4 edit install-antislop, improve-codebase-architecture and pathfinder, none of which is inlined (`tests/adapter-skill-parity.test.js` rows name only coding-discipline, tdd, roast-work); install-antislop's `.claude/skills` mirror is copied by lov-1 edit 11.
- CHK6: Does any new text risk the C4.1 phrase sweep or the reviewed-path gate? — PASS. R2 and R3; the two payloads naming the review-record directory are Edit-tool edits.
- CHK7: Does lov-4's contract survive its own nested fences for the guard? — PASS. Its payloads hold `~~~~` lines, so it uses a 7-tilde outer fence and 5-tilde payload fences (R5); the guard scores it 7/7.
- CHK8: Is the `+++` mutant described the same way everywhere this slice writes about it? — PASS. CONTEXT.md **equivalent mutant**, the corrected sfu Clarifications line and Corrections section (lov-1), the test comment and the corrected sfu-4 CHANGELOG entry (lov-2) all say: not equivalent, unpinned on purpose.
- CHK9: Is the stop-gate design question decided or explicitly deferred? — PASS. lov-5 is documented-only by the request's own allowance; the design is Open Question 1, non-blocking.
- CHK10: Does lov-5 change any gate exit code or join behaviour? — PASS. Only the block text changes; criterion 1's case pins exit 2 and the audit line.
- CHK11: Do the nine-element contracts exist and score haiku for the fast path? — PASS. `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-leftovers.md --unit=lov-N` prints `contract-guard: haiku unit=lov-N shape=lead score=7/7` for N = 1..5.
- CHK12: Does every before block and anchor match exactly once against the tree the earlier units leave? — PASS (applied in order to a fresh clone of `d937e67`).
- CHK13: Does every criterion hold after its unit, and is the suite green at the end? — PASS (all criteria held in the clone; `bash tests/validate-lanes.sh --lanes 6` passed after each unit).
- CHK14: Is each mutation line true (the named edit, when skipped, makes the criterion fail)? — PASS. The test-file mutations (lov-2 c1-c2, lov-3 c1-c4, lov-4 c1-c2, lov-5 c1-c3) were run in the clone; lov-3 criterion 5 states it cannot fail on today's tree and points to criterion 3.
- CHK15: Replay source (`docs/audits/unit-outcomes/`): does any recorded vacuous or host unit intersect a criterion's files? — PASS. The directory does not exist in this clone; no item added.
- CHK16: Is every inline payload and anchor unambiguous (no backticks nested inside a backticked literal)? — FAIL (ambiguous) — revised in place: the draft's inline payloads and anchors containing backticks (lov-1 edits 5, 9, 15, 16, 17, 20; lov-2 edit 9; lov-4 edit 2) became fenced payloads and backtick-free anchors, each confirmed unique with `grep -cF`.
- CHK17: Can lov-5 criterion 3 fail? — FAIL (ambiguous) — revised in place: the draft printed a fixed word after the loop whatever `cmp` found; it now prints `copies-identical` and exits 0 only when all three copies match (mutation proven: exit 1 with the pre-lov-5 source).
- CHK18: Is each `lov-claims.sh` check specific to the text it guards? — FAIL (conflicting) — revised in place: the draft counted `## Corrections` in the sfu plan, which already holds that heading 7 times inside sfu contract payloads; the check now counts the lov-1 correction line itself.
- CHK19: Does every mutation line name an edit that touches what the criterion checks? — FAIL (conflicting) — revised in place: lov-1 criterion 5's mutation named edit 4, which adds no link; it now adds a broken link to the edit 5 entry.

## Report only (out of slice, not specced)

1. `docs/plans/skr-criteria/skr-archive-verify.sh` is the only check of the archive's byte identity and `tests/validate.sh` does not run it (skr-1 note).
2. "spec publication" has no glossary entry (skr-2 note).
3. The persona config's `issueTracker` string still cites "to-tickets' own default" (human-only edit).
4. Broken relative links outside the maintained docs: rendered `.claude/agents` 18, `adapters/cursor` 2, `docs/plans` 15.

## Scribe update hint

After lov-5 passes, scribe should check the wiki changelog for the five lov units and the `modules/hooks.md` stop-gate notes against the new block text. No new ADR: lov-5 changes no decision of ADR-0016, and ADR-0041's correction lives in its own `## Corrections` section.
