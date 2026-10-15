# Skills audit leftovers 2 (slice `lo2`)

Status: FINAL for lo2-1..lo2-5, ready to dispatch (fast path, 5 units). Batch A (lo2-1, lo2-2, lo2-3, lo2-4) runs in parallel; lo2-5 runs alone after all four PASS. The stamp-ownership fix (Step 6) is HELD on Open Question 1: Claude Code's `SubagentStart` payload does not carry the reviewer's unit id (measured), so Design B cannot be specced as asked. Every contract below scores `contract-guard: haiku ... score=7/7`.
Slug: `2026-10-14-skills-audit-leftovers-2`. Unit ids: `lo2-1` .. `lo2-5` (`lo2-6` held). Criteria script: `docs/plans/lo2-criteria/lo2-claims.sh`.

## Goal

Close what is left from the skills-audit work after lov-1..lov-5 (`docs/plans/2026-10-14-skills-audit-leftovers.md`): the reviewers' non-blocking notes on lov-1..lov-5, the broken relative links outside the maintained set, the unwired archive check, and the review-join stamp ownership fix. Each item was checked against the tree at `da1b2da` (version 0.31.170). The work is cut so that four units run at the same time on disjoint files, and the edits that need one owner (version bump, `CHANGELOG.md`, rendered `.claude` mirrors) go into one serial integration unit.

## Context

Input: the orchestrator's list, the `NOTE[...]` lines in the five `lov-*.pass` markers, and the tree at `da1b2da`. Every unit's edits were applied in order, with the batch first, to a scratch clone of `da1b2da`. Each unit's criteria then held, and `bash tests/validate-lanes.sh --lanes 6` printed `All checks passed.` (119 sections, 134 s).

Measured facts the units rely on:

- **Glossary gaps.** `CONTEXT.md:357-364` (**equivalent mutant**) uses "surviving mutant" and nothing defines it. "spec publication" appears in `CONTEXT.md:619` and has no entry; the nearest entries are **publish threshold** (:567) and **PRD template** (:703). Contract layout terms are kept in `docs/harness-glossary.md` (**contract precedence** :778, **scribe dispatch contract** :801), and that file has no **issue-body layout** entry.
- **Review-join residual, measured from the code.** `docs/harness-glossary.md:1130-1136` says the residual hits only "a reviewer whose own stamp was already consumed". In `hooks/scripts/lib/stop-gate-core.sh`, `review_join_state` (:239-330) classifies every stamp, and :396-397 allow a stop only when some stamp is satisfied, a stamp failed open, or none is unsatisfied. So the residual also blocks a reviewer dispatched without a `Unit:` line (it has no stamp) and an advisory pass (:278-282 delete its advisory stamp, which never counts as satisfied). It also has a converse: a reviewer that wrote no verdict is let through when another unit's stamp is satisfied, and :408-433 consume that stamp for it. Separately, **scoped unit set** (:1147-1149) says the set comes from "that reviewer's own" stamps, but :347 builds it from every stamp present.
- **Block message.** `stop-gate-core.sh:469` ends with "For each unit you did review, a v3 PASS or FAIL marker must be written". An advisory pass owns no verdict (`templates/persona-protocol.md`, advisory-reviewer axis), so it should not be told to write one. The text is pinned only on the Claude path (`tests/review-join.test.sh:615-635`). The Codex and Cursor copies are covered by byte identity alone.
- **Agent wording.** `agents/lead-programmer.md:57-59` says an installed project finds the `tdd` skill under the plugin's install directory, "not a path in the project's own tree", but in this repo the skill is also at `skills/tdd/SKILL.md`. `agents/orchestrator.md:52` calls the scribe contract "the `~~~`-fenced block", while `agents/task-master.md:359` has it fenced like the lead contract (`~~~~` around `~~~`). `agents/task-master.md:63` says the lead contract goes "last", which cannot hold when a scribe contract follows it. A body carrying both contracts scores haiku 7/7 for each under the guard (measured).
- **"no FAIL line".** `agents/task-master.md:163-164` already limits `stdout:` to "a fragment, or `empty`". The descriptive wording appears only in dated plans (`2026-08-26-microworld-memo-mutation-proof.md`, `2026-10-14-skills-audit-followups.md`, `2026-10-14-skills-audit-leftovers.md`), not in any convention note. On success `tests/validate-lanes.sh` prints `All checks passed.` (:145), and every criterion in this plan uses that line.
- **CHANGELOG.** The only triple newline under `## [Unreleased]` is between the lov-3 and lov-2 entries (lines 9-11). Two older ones (:1224, :1240) separate released sections and are not touched.
- **Link test.** `tests/doc-relative-links.test.js:32` matches `\]\(([^)\n]*)\)`, which stops at the first `)`. The `\([^()]*\)` title branch of `DEST` (:28) is therefore never reached, and `[x](a.md (t))` or `[e](c_(1).md)` is reported unparsable or broken. The lov-3 checks have no fixtures inside the suite. The `tests/resync-vendored-skills-offline.test.sh` lov-3 checks have none either; their mutation proofs exist only in the lov-3 review record.
- **Broken relative links outside the maintained set** (running the link test's own logic with a different SCOPE):
  - `.claude/agents`: 18. Each of the six full-tier renders has the three links `templates/persona-protocol.md:239,248,250` writes as `../docs/adr/...`. They resolve from `templates/` and from `.claude/persona-protocol.md`, but not from `.claude/agents/`. In an installed project `docs/adr/` does not exist at all, because the package ships no `docs/`. The `agents/*.md` sources contain no links. The fix goes in the template, as plain backticked paths, and is then rendered.
  - `adapters/cursor`: 2. `tests.md` and `mocking.md` in `adapters/cursor/agents/lead-programmer.md:138` belong to the inlined `skills/tdd/SKILL.md` body, which `tests/adapter-skill-parity.test.js` pins byte for byte. The same two links are in the Codex `.toml`, which the link test does not scan.
  - `docs/plans`: now 22, not 15 (newer plans). Most of them sit inside contract payloads that quote another file's text, so they resolve from that file and not from the plan. Some are regex text inside code spans (`fs|child_process|http`), and some are deliberate examples (`./rel/path.md`, `a.md`). A few are real prose mistakes in dated plans.
  - Outside the request, `docs/self-improvement-loops.md` has one broken link, to a sibling repo (`../../claude_trace/...`).
  - `templates/` has 3 links, all fine until lo2-5 removes them.
- **Archive check.** `docs/plans/skr-criteria/skr-archive-verify.sh` reads only git objects. It takes 0.24 s, runs offline, and with no argument checks every README row. CI checks out with `fetch-depth: 0` (`.github/workflows/validate.yml:13`), so every archived-from SHA is present there. `tests/validate.sh` does not run it.
- **Render reach.** With the batch files dirty (`CONTEXT.md`, `docs/harness-glossary.md`, the four test files, `tests/validate.sh`) plus the stop-gate core, `node bin/cli.js --update --force-render --dry-run` names only the three stop-gate copies and the persona config. lo2-4 can therefore render during the batch without picking up any other unit's work.
- **`SubagentStart` payload (Claude Code 2.1.300, read from the binary).** `{...base, hook_event_name:"SubagentStart", agent_id, agent_type}`, with no prompt and no `tool_use_id`. `SubagentStop` carries `agent_id`, `agent_type`, `agent_transcript_path` (empty in some modes) and `last_assistant_message`. PreToolUse(Agent) carries `tool_use_id` and `tool_input`. On this machine the first record of a reviewer's `agent_transcript_path` file is `type:"user"`, and its `message.content` starts `Unit: lov-5\n` (checked on the lov-5 reviewer). See Open Question 1.
- **Prior FAIL history.** None of lov-1..lov-5 has a `.fail` record; each has only `.pass`. This slice touches no surface with a recorded FAIL. ADR-0016's per-unit join has a FAIL-loop history in earlier slices, which is why Step 6 is the riskiest unit. The sweep is per-clone state, so an absence proves nothing.

### Verified in-scope findings

| # | Finding (source) | Verified at `da1b2da` | Unit |
|---|---|---|---|
| M1 | "surviving mutant" undefined (lov-1 note) | yes, `CONTEXT.md:362` | lo2-1 |
| M2 | "spec publication" undefined (skr-2 note, request) | yes, no entry | lo2-1 |
| M3 | "issue-body layout" undefined (request) | yes, no entry | lo2-1 |
| M4 | Residual glossary understates blocked reviewers (lov-5 note) | yes, :1130-1136 vs core :396-397; also the converse let-through | lo2-1 |
| M5 | **scoped unit set** says "own" stamps (found while checking M4) | yes, :1148 vs core :347 | lo2-1 |
| M6 | Link test `DEST` paren-title branch dead (lov-3 note) | yes, reproduced | lo2-2 (balanced scan) |
| M7 | No in-suite fixtures or mutants for the lov-3 checks (lov-3 note) | yes | lo2-2 |
| M8 | Out-of-scope paths of the link test are undocumented | yes | lo2-2 (header), lo2-5 (`.claude/agents` scope) |
| M9 | No guard check of a fenced scribe contract in an issue body; "last" not asserted (lov-4 note) | yes | lo2-3 |
| M10 | `skr-archive-verify.sh` not in `tests/validate.sh` (skr-1 note) | yes | lo2-3 |
| M11 | Block text tells an advisory pass to write a marker; codex/cursor text unpinned; multi-unit list untested (lov-5 notes) | yes, :469 | lo2-4 |
| M12 | lead-programmer tdd location; orchestrator `~~~`-fenced; task-master "last" (lov-1, lov-4 notes) | yes | lo2-5 (0.31.171) |
| M13 | "no FAIL line" is a description, not a fragment (lov-4 note) | yes; no convention note says otherwise | lo2-5 (task-master R3 wording) and this plan's criteria |
| M14 | Double blank line under `[Unreleased]` (lov-2, lov-3 notes) | yes, lines 9-11 | lo2-5 |
| M15 | 18 broken links in rendered `.claude/agents` | yes, from `templates/persona-protocol.md` | lo2-5 |
| M16 | Review-join stamps carry no owner (lov plan Open Question 1) | yes, still reproduced by `residual-ownerless-stamp` | Step 6, HELD (Open Question 1) |

### Findings that get no unit

- **adapters/cursor (2 links)**: they stay out of scope, for the reason lo2-2 writes into the test header. The port inlines `skills/tdd/SKILL.md` byte for byte, so fixing the port means changing the live skill's links. A port does not ship `tests.md` or `mocking.md`, so a link there points to nothing whatever form it takes.
- **docs/plans (22 links)**: they stay out of scope, for the reason lo2-2 writes into the test header. Plans are dated records, and most hits are payload text quoted from another file. Rewriting old contract payloads would change contracts that past reviews ran against. Report only: the real prose mistakes are in `2026-08-03-efficiency-audit-remediation-pass3.md` (ADR-0007 path), `2026-09-23-harness-integrity-gate-human-confirmation.md` (ADR-0029), `2026-09-25-item11-dispatch-override-replay-window.md` (ADR-0024), `2026-10-08-haiku-default-tier.md` (ADR-0026) and `2026-10-14-skills-audit-followups.md` (ADR-0041, ADR-0010, and two links to the per-clone review state, which are broken by construction).
- **Rewriting the dated plans' "no FAIL line" criteria**: no change. They are records of what was run, and the convention (task-master.md:163-164) was already correct. lo2-5 states it explicitly and this plan follows it.
- **`.claude/persona-config.json`** (`issueTracker` still cites "to-tickets' own default"): human-only edit, report only.
- **`docs/self-improvement-loops.md`** sibling-repo link: outside the request, report only.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Missing
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-14 Functional scope & success criteria: Q Which items enter the slice, and which are dropped as fixed or false? → A (self-resolved): M1-M15 as units, M16 held. None of the listed items was already fixed. The broken-link counts changed (docs/plans 15 → 22). M5 is a new finding of the same kind as M4 and is folded into lo2-1.
- 2026-10-14 Functional scope & success criteria: Q Fast path or task-master slicing? → A (self-resolved): fast path, 5 dispatchable units with contracts here. When Open Question 1 is answered, the ownership fix gets its own one-unit plan, so this spec stays below the publish threshold (≥6 units) and no tracker issue is filed.
- 2026-10-14 Domain entities / data model: Q Which file owns each glossary term? → A (self-resolved): surviving mutant and spec publication go in `CONTEXT.md`, next to **equivalent mutant** and **publish threshold**, because both are domain process terms already used there. Issue-body layout goes in `docs/harness-glossary.md`, next to **scribe dispatch contract**, because it is harness mechanics. lo2-1 is the only unit that edits either file.
- 2026-10-14 Non-functional attributes: Q Can the batch run in one shared checkout? → A (self-resolved): yes, with three rules. Files are disjoint. No unit runs `git add`; each commits with `git commit -- <its own paths>`, which commits only those paths whatever else is staged. Only lo2-4 renders in the batch, and its render reaches only its own files (measured). Units do not use worktree isolation, because `tests/validate-lanes.sh` refuses a linked worktree and the reviewers' marker `commit:` must be reachable from `HEAD`.
- 2026-10-14 External dependencies & integrations: Q Can `SubagentStart` bind a stamp to its reviewer (Design B)? → A (self-resolved, measured): no. Its payload carries `agent_id` and `agent_type` and nothing that names the unit or the dispatching `tool_use_id`. Binding would have to guess ("the newest unbound stamp"), and a wrong guess turns another unit's stamp fail-open. Per the request this goes back as Open Question 1, not as a guessed unit.
- 2026-10-14 Edge cases / failure handling: Q What does a batch lead-programmer do when its own stop is blocked by another unit's in-progress files (`testAndLintCommand` is `bash tests/validate.sh`)? → A (self-resolved): it reports the block and waits. It writes the WIP sentinel and names the other unit, and the orchestrator resumes it after the batch settles. It never edits another unit's files.
- 2026-10-14 Edge cases / failure handling: Q What if a commit hits `.git/index.lock` because another unit is committing? → A (self-resolved): re-run the same commit command once the other commit has finished. Never delete the lock.
- 2026-10-14 Technical constraints & tradeoffs: Q How are the stamped edits and the shared files owned? → A (self-resolved): lo2-5 is the single owner of `agents/*.md`, `templates/`, both version files, `CHANGELOG.md` and every rendered `.claude/agents` file. The batch units write no CHANGELOG entry; lo2-5 writes one for each. P3 holds because the only stamped commit is lo2-5's, and it carries the bump and its CHANGELOG entry.
- 2026-10-14 Technical constraints & tradeoffs: Q For the link-test `DEST`, scan with balanced parentheses or drop the dead option? → A (self-resolved): scan with balanced parentheses (CommonMark allows both forms). The scanner is 12 lines, and a fixture plus mutant m1 pin it.
- 2026-10-14 Technical constraints & tradeoffs: Q Wire `skr-archive-verify.sh` in place or move it to `scripts/`? → A (self-resolved): in place. The archive README and three plans name its path, and it is offline and takes 0.24 s.
- 2026-10-14 Terminology consistency: Q Does the request's wording drift from the glossaries? → A (self-resolved): "stamp ownership" means the same as the **review-join stamp** residual, and no synonym entry is added. "integration unit" is plan wording only, not a glossary term. "issue-body layout" is new and gets an entry. "spec publication" is in use but undefined, and gets an entry. "surviving mutant" is in use but undefined, and gets an entry.

## Risks / dependencies

- R1. **Parallel batch mechanics.** Batch A units share one checkout. The commit command of each names only that unit's paths (`git commit -m ... -- <paths>`; lo2-4 adds `.claude ':(exclude).claude/agent-memory'`, because the gate refuses a command that names the persona config). Never `git add`, never `git add -u`, never `git commit -a`. The criteria check the commit's exact file count (`files= other=`), so a stray file fails review.
- R2. **Stop-gate during the batch.** A gated lead-programmer's SubagentStop runs `testAndLintCommand` (`bash tests/validate.sh`) against the shared tree, which may hold another unit's half-done edit. If it fails only because of another unit's file, write the WIP sentinel naming that unit and report. Do not touch that file. (The serial suite also runs longer than 600 s, which is pre-existing.)
- R3. **Reviews must be sequential (stamp residual, M16).** Two reviewers stopping at the same time can block each other, or one can be let through on the other's satisfied stamp. Dispatch reviewer k+1 only after reviewer k has returned.
- R4. **Gates on command text.** A Bash command naming the persona config is refused by `harness-integrity-gate.sh`. A Bash command spelling the per-clone review-record directory is refused by `reviewed-path-gate.sh`. No payload or command in this plan does either.
- R5. **lo2-5 base.** lo2-5 sets version 0.31.171 on top of 0.31.170. If `.claude-plugin/plugin.json` is not 0.31.170 at dispatch, its before blocks do not match: STOP and report a spec gap.
- R6. **Link counts are exact.** lo2-2 expects `ok (165 links in 83 files)` and lo2-5 expects `ok (162 links in 93 files)`. lo2-1 adds no relative link (measured). Any other commit that adds or removes a link in scope between dispatch and review changes the count. If so, re-measure; do not edit a link to make the number fit.
- R7. **Dated criteria that move.** lov-3 criterion 3 (`3 broken of 165 links`) and lov-1 criterion 5 (`162 links in 80 files`) no longer match once lo2-2 adds `templates`. Those are run-once records, not suites. `lov-claims.sh lov-1`, `lov-4` and `lov-5` stay green and are re-run as criteria here.
- R8. Commit trailer: criteria grep only `^Co-Authored-By: Claude `. The orchestrator supplies the dispatched tier's own line.
- R9. Where a contract and the narrative Steps differ, the contract governs.
- R10. **Tags.** lo2-4 touches the gate core and is tagged `sonnet` although the guard scores it haiku-eligible. The others are `haiku`.
- R11. **Lane flake.** In the scratch clone, one of five `bash tests/validate-lanes.sh --lanes 6` runs over the finished tree printed `One or more checks FAILED.`. Four reruns over the same tree passed, and the failing section was not captured. If lo2-5 criterion 11 fails, run it once more. If the second run passes, record both outcomes in the review packet. If it fails again, report the failing section as a spec gap; do not edit to make it pass.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every finding was re-checked at `da1b2da`. Every contract was applied to a scratch clone and its criteria were run. The `SubagentStart` payload was read from the installed binary rather than assumed, and that reading is why Step 6 is held.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors, adapter hook libs and fileHashes come only from `node bin/cli.js --update --force-render` (lo2-4, lo2-5). Nothing edits the persona config by hand.
- P3 "Version-stamp discipline": satisfied. lo2-5 is the only unit touching `agents/*.md` or `templates/`. Its one commit carries the 0.31.171 bump and a CHANGELOG entry naming it, checked by `version-stamp-check.sh` on that commit. Every batch commit is checked to report `touched: no`.
- P5 "`tests/validate.sh` is the merge gate": deviation. The serial suite runs longer than the 600 s Bash cap, and `tests/validate-lanes.sh` copies the working tree, which during the batch holds other units' unfinished edits. Batch units therefore run their own sections' tests, and lo2-5 runs `bash tests/validate-lanes.sh --lanes 6` once over the whole slice, on a quiet tree. Every batch commit is also covered by that final run, because lo2-5 is blocked by all four.

## Parallel execution plan

| Unit | Model | Group | Files it writes (single owner) | Depends on |
|---|---|---|---|---|
| lo2-1 | haiku | Batch A | `CONTEXT.md`, `docs/harness-glossary.md` | none |
| lo2-2 | haiku | Batch A | `tests/doc-relative-links.test.js`, `tests/resync-vendored-skills-offline.test.sh` | none |
| lo2-3 | haiku | Batch A | `tests/contract-examples.test.js`, `tests/validate.sh` | none |
| lo2-4 | sonnet | Batch A | `hooks/scripts/lib/stop-gate-core.sh`, `tests/adapter-stop-gate-parity.test.sh`; rendered `.claude/hooks/scripts/lib/stop-gate-core.sh`, `adapters/{codex,cursor}/hooks/scripts/lib/stop-gate-core.sh`, persona-config fileHashes | none |
| lo2-5 | haiku | Serial (integration) | `agents/lead-programmer.md`, `agents/orchestrator.md`, `agents/task-master.md`, `templates/persona-protocol.md`, `tests/doc-relative-links.test.js` (SCOPE line, after lo2-2), `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`; rendered `.claude/agents/*`, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, persona-config | lo2-1, lo2-2, lo2-3, lo2-4 (all PASS) |
| lo2-6 | opus (proposed) | Serial, HELD | see Step 6 | lo2-5 and Open Question 1 |

Shared files and their single owner: `CHANGELOG.md`, both version files, `.claude/agents/*`, `agents/*`, `templates/*` belong to lo2-5. `CONTEXT.md` and `docs/harness-glossary.md` belong to lo2-1. `tests/doc-relative-links.test.js` belongs to lo2-2 in the batch and to lo2-5 afterwards. The persona config's fileHashes belong to lo2-4 in the batch and to lo2-5 afterwards. No two concurrent units write the same file.

Orchestrator batching (the route gate blocks a gated dispatch while any pending-review flag stands, so the batch must leave in one message):
1. Commit this plan and `docs/plans/lo2-criteria/lo2-claims.sh` first, so the tree is clean.
2. Run `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-leftovers-2.md --unit=lo2-N` for N = 1..4.
3. Send ONE message with four `Agent` calls (lead-programmer: lo2-1, lo2-2, lo2-3, lo2-4) before any of them returns.
4. Wait for all four to return. Each leaves its own pending-review flag.
5. Review one unit at a time: dispatch the reviewer for lo2-1, wait for its verdict, then lo2-2, and so on. Each verdict consumes its own stamp and clears one flag (bounded clearing). Never run two reviewers at once (R3).
6. After all four verdicts, the flags are clear. Re-dispatch any FAILed units, again in one message, and review them one at a time again.
7. When lo2-1..lo2-4 have all PASSed, dispatch lo2-5 alone and review it.
8. Step 6 waits for Open Question 1.

## Steps

Every unit ends with one commit, scope `(lo2-N)`, made with `git commit -m ... -- <the unit's paths>` and no `git add`. Common criteria (spelled out in each contract), with `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-N\): ' | head -1 | cut -d' ' -f1)`:
- `bash hooks/scripts/version-stamp-check.sh "$C~1..$C"` prints `ok touched: no` for lo2-1..lo2-4, and `ok touched: yes old: 0.31.170 new: 0.31.171` for lo2-5.
- The commit's trailer count is 1.
- The commit's file count and the number of files outside its own list are exact (`files=N other=M`).
- The unit's own paths are clean against `HEAD`.

### Step 1 (lo2-1): glossary entries and the widened residual. Lead-programmer, Batch A, no version bump
Covers M1-M5. Files: `CONTEXT.md` (**surviving mutant**, **spec publication**), `docs/harness-glossary.md` (**issue-body layout**, **review-join stamp** residual, **scoped unit set**). Criteria: `lo2-claims.sh lo2-1` (12 checks, all red at `da1b2da`), glossary link test, `lov-claims.sh lov-5` still green, common criteria.

### Step 2 (lo2-2): link test balanced parentheses, scope notes, fixtures; resync fixtures. Lead-programmer, Batch A, TDD, no version bump
Covers M6-M8. Tests first: edit 3 adds the self-test, and the suite shows `FAIL (fixture)` and m1 not found; then edits 4-5 add the scanner. The resync self-test runs five mutated copies of the resync script, each with one planted defect. Criteria: both tests green, 6 link self-test OK lines, 5 resync rejections, the scope note present.

### Step 3 (lo2-3): contract-guard scribe shape; archive check in the merge gate. Lead-programmer, Batch A, no version bump
Covers M9-M10. `tests/contract-examples.test.js` builds an issue body with both contracts fenced and checks the guard's scribe and lead verdicts, the unfenced scribe no-contract, and that the documented layout ends with its fence. `tests/validate.sh` gains a section running `skr-archive-verify.sh`.

### Step 4 (lo2-4): join block advisory-pass wording, per-port text pins. Lead-programmer, Batch A, TDD, no version bump
Covers M11. Test first: case (f5) in `tests/adapter-stop-gate-parity.test.sh` (all three ports, two stamps) is red until the core text changes and the copies are rendered. Exit codes and join logic are unchanged.

### Step 5 (lo2-5): integration, the stamped wording, protocol links, CHANGELOG, render. Lead-programmer, serial, version 0.31.171
Covers M12-M15 and writes the CHANGELOG entries for lo2-1..lo2-5. It runs only after lo2-1..lo2-4 PASS, because it edits `tests/doc-relative-links.test.js` after lo2-2 and renders over lo2-4's hook copies. Criteria include `lo2-claims.sh lo2-5` (14 checks, all red at `da1b2da`), the link test with `.claude/agents` in scope, version sync, render currency, `version-stamp-check`, the CHANGELOG blank-run check, and `bash tests/validate-lanes.sh --lanes 6` → `All checks passed.`

### Step 6 (lo2-6, HELD on Open Question 1): review-join stamp ownership. RISKIEST UNIT
Not dispatchable. When Open Question 1 is answered, spec-master writes it as its own one-unit plan (`docs/plans/2026-10-14-review-join-stamp-ownership.md`). It is serial, after lo2-5. These parts are fixed whichever design is chosen:
- **Files**: `hooks/scripts/lib/stop-gate-core.sh` (`review_join_state` and the :396 decision), `hooks/scripts/lib/reviewer-route-gate-core.sh` (only if the stamp format grows a field), `hooks/hooks.json` (only if a new event is registered), the rendered `.claude/hooks/scripts/lib/*` and `adapters/{codex,cursor}/hooks/scripts/lib/*` copies and fileHashes, `docs/adr/0016-per-unit-review-join.md` (dated amendment), `docs/harness-glossary.md` (**review-join stamp** residual and **scoped unit set** rewritten), `tests/review-join.test.sh`, `tests/adapter-stop-gate-parity.test.sh`, `CHANGELOG.md`.
- **The flip**: `tests/review-join.test.sh` case (residual-ownerless-stamp) must go from `rc2=2` to `rc2=0`, with a `join-owner` audit line, and be renamed to say so. New cases: (a) the stopping reviewer's own unsatisfied stamp still blocks it (no regression of f1/M1 coupling); (b) a foreign unsatisfied stamp does not block it; (c) a foreign satisfied stamp is neither consumed nor counted for it (the converse let-through in M4); (d) an unowned or unattributable stamp keeps today's all-stamps behaviour (the fallback), so enforcement is never weaker than today; (e) codex and cursor, which lack the attribution input, keep today's behaviour byte for byte.
- **Mutation proofs (in the suite)**: (i) make the owner filter match every stamp: (b) and (c) go red. (ii) Make it match no stamp: (a) goes red. (iii) Delete the fallback: (d) goes red. (iv) Revert to `da1b2da`'s core: the renamed residual case goes red.
- **Rollback**: one commit, `git revert <sha>` followed by `node bin/cli.js --update --force-render`, restores lo2-5's tree. No state migration, because stamps are per-dispatch and short-lived. A stamp carrying an added field must stay readable by the old core, so any new field is appended after `prior_mtime=` and the reverted core's regexes ignore it.
- **Criteria shape**: `bash tests/review-join.test.sh`, `bash tests/adapter-stop-gate-parity.test.sh`, the four-copy `cmp` loop, `node tests/filehashes-currency.test.js`, `bash tests/validate-lanes.sh --lanes 6` → `All checks passed.`

## Dispatch contracts

Batch A (lo2-1, lo2-2, lo2-3, lo2-4) is dispatched in one message and reviewed one at a time. lo2-5 is blocked by all four. Each contract is the fenced block below its heading. The guard reads it with `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-leftovers-2.md --unit=lo2-N`.

### Contract lo2-1: glossary entries and the widened review-join residual

Suggested model: haiku

~~~~
Unit: lo2-1

## Objective
`CONTEXT.md` defines **surviving mutant** (next to **equivalent mutant**) and **spec publication** (next to **publish threshold**). `docs/harness-glossary.md` defines **issue-body layout** (next to **scribe dispatch contract**). It also widens the **review-join stamp** residual to cover every reviewer that stops while no stamp is satisfied (a consumed reviewer, an un-stamped reviewer, an advisory pass) and the converse let-through, and corrects **scoped unit set**, which comes from every stamp, not from the reviewer's own. Batch A unit: it runs in parallel with lo2-2, lo2-3 and lo2-4, so it touches only its two files and commits them by path. No version bump, no CHANGELOG entry (lo2-5 writes it).

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers-2.md`. Criteria script: `docs/plans/lo2-criteria/lo2-claims.sh`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `CONTEXT.md` (anchors: line matching `[[Mutation-proved]].` and line matching `filing a tracker issue nobody slices from.`)
- `docs/harness-glossary.md` (anchors: line matching `section with example(s) between whole-line scribe-contract-example markers.`, line matching `Residual (unit lov-5, 2026-10-14): A stamp names no owner, and every` and line matching `(ADR-0028, gh425-3) — the set of unit ids that a stopping reviewer is`)

## Ordered edits
1. file: `CONTEXT.md`
   anchor: line matching `[[Mutation-proved]].`
   before:
   ~~~
     `version-stamp-check.sh` was first misdescribed this way. See
     [[Mutation-proved]].
   ~~~
   after:
   ~~~
     `version-stamp-check.sh` was first misdescribed this way. See
     [[Mutation-proved]].

   **surviving mutant**:
   (unit lo2-1, 2026-10-14) — a mutant that the suite does not kill: every
     check still passes with the mutation in place. It is either a gap in the
     suite, when some input tells it apart from the original and a check could
     be added, or an [[equivalent mutant]], when no input can; calling it the
     latter needs proof. A surviving mutant may be left unpinned on purpose, but
     the plan or test must say so and why.
   ~~~
   indent: 3
2. file: `CONTEXT.md`
   anchor: line matching `filing a tracker issue nobody slices from.`
   before:
   ~~~
     filing a tracker issue nobody slices from.
     Archived originals (skills audit, 2026-10-14): `docs/archive/skills/to-spec/`.
   ~~~
   after:
   ~~~
     filing a tracker issue nobody slices from.
     Archived originals (skills audit, 2026-10-14): `docs/archive/skills/to-spec/`.

   **spec publication**:
   (unit lo2-1, 2026-10-14) — `spec-master`'s step, after its Self-check
     passes, of mapping a finished plan onto its [[PRD template]] and filing it
     to the issue tracker with the `ready-for-agent` label. Required at or above
     the [[publish threshold]], optional below it; additive either way, since the
     `docs/plans/` document stays the canonical artifact. A synthesis step, not a
     second interview. Distinct from `task-master` publishing the sliced units as
     per-unit issues.
   ~~~
   indent: 3
3. file: `docs/harness-glossary.md`
   anchor: line matching `section with example(s) between whole-line scribe-contract-example markers.`
   before:
   ~~~
     section with example(s) between whole-line scribe-contract-example markers.
   ~~~
   after:
   ~~~
     section with example(s) between whole-line scribe-contract-example markers.

   **issue-body layout**:
   (unit lo2-1, 2026-10-14) — the arrangement of a published unit's tracker issue
     body that lets `bin/contract-guard.js` find its contracts: prose first, then
     the contracts last, the lead one under `## Dispatch contract` and, when the
     unit has one, the [[scribe dispatch contract]] after it under
     `## Dispatch contract (scribe)`. Each contract is one tilde-fenced block whose
     first interior line is `Unit: <task-id>`, with a fence longer than any fence
     inside it (`~~~~` around `~~~` payloads). An unfenced contract scores
     `reason=no-contract`, a guard demotion to `sonnet`. Documented by the marked
     issue-body example in `agents/task-master.md` and pinned by
     `tests/contract-examples.test.js`.
   ~~~
   indent: 3
4. file: `docs/harness-glossary.md`
   anchor: line matching `Residual (unit lov-5, 2026-10-14): A stamp names no owner, and every`
   before:
   ~~~
     Residual (unit lov-5, 2026-10-14): A stamp names no owner, and every
     reviewer's SubagentStop classifies every stamp in the directory, so a
     reviewer whose own stamp was already consumed (a resumed or second turn) is
     blocked while another unit's freshly dispatched review is unsatisfied. The
     block message says so; that reviewer reports and waits, and never writes a
     marker for a unit it did not review. See [ADR-0016](adr/0016-per-unit-review-join.md)
   ~~~
   after:
   ~~~
     Residual (unit lov-5, 2026-10-14; widened by lo2-1): A stamp names no owner,
     and every reviewer's SubagentStop classifies every stamp in the directory, so
     any reviewer that stops while no stamp is satisfied is blocked as long as
     another unit's stamp is unsatisfied. That covers a reviewer whose own stamp
     was already consumed (a resumed or second turn), a reviewer dispatched without
     a `Unit:` line (it has no stamp), and an advisory pass (its advisory stamp is
     never satisfied). Conversely, a reviewer that wrote no verdict is let through
     when another unit's stamp happens to be satisfied, and that stamp is consumed
     on its behalf. The block message says so; a blocked reviewer reports and
     waits, and never writes a marker for a unit it did not review, and an advisory
     pass never writes one at all. See [ADR-0016](adr/0016-per-unit-review-join.md)
   ~~~
   indent: 3
5. file: `docs/harness-glossary.md`
   anchor: line matching `(ADR-0028, gh425-3) — the set of unit ids that a stopping reviewer is`
   before:
   ~~~
   (ADR-0028, gh425-3) — the set of unit ids that a stopping reviewer is
     responsible for, derived from that reviewer's own [[review-join stamp]]
     files at stop time. Used to determine which `.blocked` / `.escalated` markers
   ~~~
   after:
   ~~~
   (ADR-0028, gh425-3) — the set of unit ids that a stopping reviewer is
     treated as responsible for, derived from every [[review-join stamp]] file
     present at stop time; stamps name no owner, so this includes units other
     reviewers are reviewing (corrected by lo2-1). Used to determine which `.blocked` / `.escalated` markers
   ~~~
   indent: 3
6. command: `git commit -m "docs(lo2-1): glossary - surviving mutant, spec publication, issue-body layout, review-join residual widened (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>" -- CONTEXT.md docs/harness-glossary.md`
   expect: 0

## Do NOT touch
- `CHANGELOG.md` (lo2-5 is its single owner; this unit writes no entry)
- `hooks/scripts/lib/stop-gate-core.sh` (lo2-4 owns it in this batch; the glossary describes the code, the code is not changed here)
- `docs/adr/0016-per-unit-review-join.md` (amended only by the held ownership fix)

## Acceptance criteria
1. run: `bash docs/plans/lo2-criteria/lo2-claims.sh lo2-1`
   exit: 0
   stdout: `lo2-claims: lo2-1 ok`
   mutation: skip edit 4; the old residual sentence stays, four checks print FAIL and the script exits 1.
2. run: `node tests/context-glossary-links.test.js`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: write `[[publish thresholds]]` in edit 2; the link resolves to no entry and the test exits 1.
3. run: `bash docs/plans/lov-criteria/lov-claims.sh lov-5`
   exit: 0
   stdout: `lov-claims: lov-5 ok`
   mutation: drop the words "A stamp names no owner" from edit 4; that check counts 0 and the script exits 1.
4. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-1\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add an agents/*.md change to this commit without a bump; the line reads violation.
5. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-1\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; no commit has the scope, test -n fails and nothing prints.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-1\): ' | head -1 | cut -d' ' -f1); test -n "$C" && echo "files=$(git show --name-only --format= "$C" | wc -l) other=$(git show --name-only --format= "$C" | grep -cvxF -e CONTEXT.md -e docs/harness-glossary.md)"`
   exit: 0
   stdout: `files=2 other=0`
   mutation: commit with `git add -A && git commit` while another batch unit has edits; the other unit's files are counted and the line differs.
7. run: `git diff --quiet HEAD -- CONTEXT.md docs/harness-glossary.md && echo own-files-clean`
   exit: 0
   stdout: `own-files-clean`
   mutation: skip edit 6; both files differ from HEAD and git diff exits 1.

## Pre-resolved context
tdd: no glossary prose; claim checks in docs/plans/lo2-criteria/lo2-claims.sh (12 checks, all red at da1b2da)
blast-radius: CONTEXT.md:364, CONTEXT.md:579, docs/harness-glossary.md:807, docs/harness-glossary.md:1130, docs/harness-glossary.md:1148, hooks/scripts/lib/stop-gate-core.sh:347, hooks/scripts/lib/stop-gate-core.sh:396
commit-message: docs(lo2-1): glossary - surviving mutant, spec publication, issue-body layout, review-join residual widened (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
parallel: Batch A; never run git add; if the commit fails on index.lock, re-run edit 6 once the other commit finishes and never delete the lock; if your stop is blocked by a test failing on another unit's file, write the WIP sentinel naming that unit and report
measured: every before block and anchor matched exactly once at da1b2da, applied in a scratch clone
review-packet:
~~~
unit: lo2-1
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract lo2-2: link test balanced parentheses, scope notes and fixtures; resync fixtures

Suggested model: haiku

~~~~
Unit: lo2-2

## Objective
`tests/doc-relative-links.test.js` scans each link destination to its matching parenthesis, so a parenthesised title or a destination with balanced parentheses parses. It also scans `templates`, says in its header why `docs/plans/` and `adapters/` stay out of scope, and runs a self-test: a fixture repository with one planted defect per check, and five mutated copies of itself that must change that result. `tests/resync-vendored-skills-offline.test.sh` accepts `RESYNC_SCRIPT` and runs five mutated copies of the resync script, each with one planted defect its checks must reject. TDD order: edits 1-3, run the link test and see `FAIL (fixture)` and `FAIL (m1 ...)`, then edits 4-5, then 6-7. Batch A unit: it runs in parallel with lo2-1, lo2-3 and lo2-4. No version bump, no CHANGELOG entry (lo2-5 writes it).

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers-2.md`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `tests/doc-relative-links.test.js` (anchors: line matching `// Unit sfu-5, hardened by lov-3: every relative markdown link in the maintained docs resolves`, line matching `const ROOT = path.resolve(__dirname, '..');`, line matching `if (links === 0) {`, line matching `const DEST = ` and line matching `for (const m of text.matchAll(`)
- `tests/resync-vendored-skills-offline.test.sh` (anchors: line matching `SCRIPT=scripts/resync-vendored-skills.sh` and line matching `[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok"`)

## Ordered edits
1. file: `tests/doc-relative-links.test.js`
   anchor: line matching `// Unit sfu-5, hardened by lov-3: every relative markdown link in the maintained docs resolves`
   before:
   ~~~
   // Unit sfu-5, hardened by lov-3: every relative markdown link in the maintained docs resolves
   // to a tracked file or directory, relative to the linking file's own directory (the way GitHub
   // renders it). Fenced code is skipped, and so are URLs and pure #fragment links. A link may
   // carry a title or an <angle-bracket> destination; a destination that cannot be parsed, or
   // whose percent escapes are malformed, is reported as broken, and so is a scope entry that
   // matches no tracked file.
   ~~~
   after:
   ~~~
   // Unit sfu-5, hardened by lov-3 and lo2-2: every relative markdown link in the maintained docs
   // resolves to a tracked file or directory, relative to the linking file's own directory (the way
   // GitHub renders it). Fenced code is skipped, and so are URLs and pure #fragment links. A link may
   // carry a quoted or parenthesised title, an <angle-bracket> destination, or balanced parentheses
   // in its destination; a destination that cannot be parsed, or whose percent escapes are
   // malformed, is reported as broken, and so is a scope entry that matches no tracked file. Not
   // handled: inline code spans are scanned like prose, and a link split across lines is skipped.
   //
   // Out of scope on purpose (lo2-2): docs/plans/, dated records whose contract payloads quote other
   // files' text (a payload link resolves from the file it targets, not from the plan) and whose
   // nested fences defeat the fence skip; adapters/, whose lead-programmer ports inline
   // skills/tdd/SKILL.md byte-for-byte (tests/adapter-skill-parity.test.js), so its tests.md and
   // mocking.md links name files a port does not ship. The self-test at the end runs this script
   // over a fixture repository (DOC_LINKS_ROOT, DOC_LINKS_SCOPE) and over mutated copies of itself.
   ~~~
   indent: 3
2. file: `tests/doc-relative-links.test.js`
   anchor: line matching `const ROOT = path.resolve(__dirname, '..');`
   before:
   ~~~
   const ROOT = path.resolve(__dirname, '..');
   const SCOPE = ['CONTEXT.md', 'docs/harness-glossary.md', 'docs/trust-model.md', 'docs/adr',
     '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills'];
   ~~~
   after:
   ~~~
   const ROOT = process.env.DOC_LINKS_ROOT || path.resolve(__dirname, '..');
   const SCOPE = process.env.DOC_LINKS_SCOPE ? process.env.DOC_LINKS_SCOPE.split(',')
     : ['CONTEXT.md', 'docs/harness-glossary.md', 'docs/trust-model.md', 'docs/adr',
       '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills', 'templates'];
   ~~~
   indent: 3
3. file: `tests/doc-relative-links.test.js`
   anchor: line matching `if (links === 0) {`
   before:
   ~~~
   if (links === 0) {
     console.log('FAIL no links found: the scope list matches nothing');
   ~~~
   after:
   ~~~
   // lo2-2 self-test: a fixture repository with one planted defect per check, and mutated copies
   // of this script that must change the fixture's result. Skipped in the child runs
   // (DOC_LINKS_ROOT is set there), so it never recurses.
   if (!process.env.DOC_LINKS_ROOT) {
     const os = require('os');
     const { spawnSync } = require('child_process');
     const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'doc-links-'));
     const fx = path.join(tmp, 'repo');
     const put = (rel, body) => {
       fs.mkdirSync(path.dirname(path.join(fx, rel)), { recursive: true });
       fs.writeFileSync(path.join(fx, rel), body);
     };
     put('docs/target.md', '# target\n');
     put('docs/c_(1).md', '# parens\n');
     put('docs/ok.md', '[a](target.md)\n[b](target.md "t")\n[c](target.md (t))\n[d](<target.md>)\n[e](c_(1).md)\n[f](#frag)\n');
     put('docs/bad.md', '[g](missing.md "t")\n[h](<missing h.md>)\n[i](target%E0%A4%A.md)\n[j](a b c)\n');
     execFileSync('git', ['init', '-q'], { cwd: fx });
     execFileSync('git', ['add', '-A'], { cwd: fx });
     const run = (script) => spawnSync('node', [script], { encoding: 'utf8',
       env: { ...process.env, DOC_LINKS_ROOT: fx, DOC_LINKS_SCOPE: 'docs,docs/gone' } }).stdout;
     const want = [
       'FAIL scope entry docs/gone matches no tracked file',
       'FAIL docs/bad.md: missing.md',
       'FAIL docs/bad.md: missing h.md',
       'FAIL docs/bad.md: target%E0%A4%A.md has a malformed percent escape',
       'FAIL docs/bad.md: (a b c) is not a parsable link destination',
       'doc-relative-links: 5 broken of 8 links',
     ].join('\n') + '\n';
     const self = fs.readFileSync(__filename, 'utf8');
     const cut = self.indexOf('// lo2-2 self-test:');
     const code = self.slice(0, cut);
     if (run(__filename) === want) console.log('OK   (fixture) every planted defect is reported, and nothing else');
     else { broken += 1; console.log('FAIL (fixture) the fixture repository did not give the expected report'); }
     const mutants = [
       ['m1 parentheses do not nest', "if (text[j] === '(') depth += 1;", 'if (false) depth += 1;'],
       ['m2 no scope-entry check', "if (git(['ls-files', '-z', '--', entry]).length === 0)", 'if (false)'],
       ['m3 no percent-escape check', 'try { decoded = decodeURI(target); }', 'try { decoded = target; }'],
       ['m4 no title', '(?:\\s+(?:"[^"]*"|\'[^\']*\'|\\([^()]*\\)))?', ''],
       ['m5 no angle destination', '<([^<>]*)>|', ''],
     ];
     for (const [name, from, to] of mutants) {
       if (code.split(from).length !== 2) { broken += 1; console.log(`FAIL (${name}) mutation text not found exactly once`); continue; }
       const copy = path.join(tmp, 'mutant.js');
       fs.writeFileSync(copy, code.replace(from, to) + self.slice(cut));
       if (run(copy) !== want) console.log(`OK   (${name}) the fixture result changes`);
       else { broken += 1; console.log(`FAIL (${name}) the fixture result is unchanged, so the check is not pinned`); }
     }
     fs.rmSync(tmp, { recursive: true, force: true });
   }
   if (links === 0) {
     console.log('FAIL no links found: the scope list matches nothing');
   ~~~
   indent: 3
4. file: `tests/doc-relative-links.test.js`
   anchor: line matching `const DEST = /^\s*(?:<([^<>]*)>|(\S+))(?:\s+(?:"[^"]*"|'[^']*'|\([^()]*\)))?\s*$/;`
   before:
   ~~~
   const DEST = /^\s*(?:<([^<>]*)>|(\S+))(?:\s+(?:"[^"]*"|'[^']*'|\([^()]*\)))?\s*$/;
   ~~~
   after:
   ~~~
   const DEST = /^\s*(?:<([^<>]*)>|(\S+))(?:\s+(?:"[^"]*"|'[^']*'|\([^()]*\)))?\s*$/;
   // The text between `](` and its matching `)`: parentheses nest, a backslash escapes the next
   // character, and the scan stops at the end of the line (an unclosed link is not a link).
   function* linkDests(text) {
     for (let i = text.indexOf(']('); i !== -1; i = text.indexOf('](', i + 2)) {
       let depth = 1;
       let j = i + 2;
       for (; j < text.length && text[j] !== '\n'; j += 1) {
         if (text[j] === '\\') { j += 1; continue; }
         if (text[j] === '(') depth += 1;
         else if (text[j] === ')' && --depth === 0) break;
       }
       if (depth === 0) yield text.slice(i + 2, j);
     }
   }
   ~~~
   indent: 3
5. file: `tests/doc-relative-links.test.js`
   anchor: line matching `for (const m of text.matchAll(/\]\(([^)\n]*)\)/g)) {`
   before:
   ~~~
     for (const m of text.matchAll(/\]\(([^)\n]*)\)/g)) {
       const d = DEST.exec(m[1]);
       if (!d) { bad(`${f}: (${m[1]}) is not a parsable link destination`); continue; }
   ~~~
   after:
   ~~~
     for (const dest of linkDests(text)) {
       const d = DEST.exec(dest);
       if (!d) { bad(`${f}: (${dest}) is not a parsable link destination`); continue; }
   ~~~
   indent: 3
6. file: `tests/resync-vendored-skills-offline.test.sh`
   anchor: line matching `SCRIPT=scripts/resync-vendored-skills.sh`
   before:
   ~~~
   SCRIPT=scripts/resync-vendored-skills.sh
   ~~~
   after:
   ~~~
   SCRIPT="${RESYNC_SCRIPT:-scripts/resync-vendored-skills.sh}"
   ~~~
   indent: 3
7. file: `tests/resync-vendored-skills-offline.test.sh`
   anchor: line matching `[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"`
   before:
   ~~~
   [ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"
   ~~~
   after:
   ~~~
   # lo2-2 self-test: mutated copies of the resync script, one planted defect each, that the checks
   # above must reject. Skipped in the child runs (RESYNC_SELFTEST is set there), so it never recurses.
   if [ -z "${RESYNC_SELFTEST:-}" ]; then
     st="$(mktemp -d)"
     st_case() { # <label> <sed expression> <fragment the child's output must contain>
       sed "$2" "$SCRIPT" > "$st/resync.sh"
       if cmp -s "$SCRIPT" "$st/resync.sh"; then no "($1) sed matched nothing"; return; fi
       st_out="$(RESYNC_SELFTEST=1 RESYNC_SCRIPT="$st/resync.sh" bash "$0" 2>&1)"
       st_rc=$?
       case "$st_out" in
         *"$3"*) if [ "$st_rc" = 1 ]; then ok "($1) rejected: $3"; else no "($1) exit $st_rc, want 1"; fi ;;
         *) no "($1) no output line contains: $3" ;;
       esac
     }
     st_case dropped-row '/^tdd:doc:docs\/archive\/skills\/tdd\/mocking.md:/d' "tdd: FILES rows"
     st_case upstream-typo 's#engineering/tdd/mocking.md$#engineering/tdd/mockng.md#' "upstream path 'skills/engineering/tdd/mockng.md' does not end in tdd/mocking.md"
     st_case unknown-type 's#^handoff:fm-noflag:#handoff:fmx:#' "handoff row type 'fmx' unknown"
     st_case untracked-local 's#^handoff:fm-noflag:skills/handoff/SKILL.md:#handoff:fm-noflag:skills/handoff/SKILLX.md:#' "skills/handoff/SKILLX.md is not tracked"
     st_case order-mismatch 's#^SKILL_ORDER="grilling #SKILL_ORDER="#' "differ from SKILL_ORDER"
     rm -rf "$st"
   fi

   [ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"
   ~~~
   indent: 3
8. command: `git commit -m "test(lo2-2): link test balanced parentheses, scope notes and in-suite fixtures; resync fixtures (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>" -- tests/doc-relative-links.test.js tests/resync-vendored-skills-offline.test.sh`
   expect: 0

## Do NOT touch
- `scripts/resync-vendored-skills.sh` (tested through mutated copies in a temporary directory, never edited)
- `tests/validate.sh` (lo2-3 owns it in this batch; both tests are already registered)
- `CHANGELOG.md` (lo2-5 is its single owner)

## Acceptance criteria
1. run: `node tests/doc-relative-links.test.js`
   exit: 0
   stdout: `doc-relative-links: ok (165 links in 83 files)`
   mutation: skip edit 5; the loop keeps the first-parenthesis match, the fixture report differs, `FAIL (fixture)` prints and the test exits 1.
2. run: `node tests/doc-relative-links.test.js | grep -cE '^OK   \((fixture\)|m[1-5] )'`
   exit: 0
   stdout: `6`
   mutation: skip edit 3; no self-test runs, the count is 0 and grep exits 1.
3. run: `grep -c 'Out of scope on purpose (lo2-2): docs/plans/' tests/doc-relative-links.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; the count is 0 and grep exits 1.
4. run: `bash tests/resync-vendored-skills-offline.test.sh`
   exit: 0
   stdout: `resync-vendored-skills-offline: ok`
   mutation: replace `[ "$want_files" = "$have_files" ] && ok` with `true && ok`; the dropped-row case prints FAIL (exit 0, want 1) and the test exits 1 (measured in a scratch clone).
5. run: `bash tests/resync-vendored-skills-offline.test.sh | grep -c '^OK   ([a-z-]*) rejected: '`
   exit: 0
   stdout: `5`
   mutation: skip edit 7; no self-test runs, the count is 0 and grep exits 1.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-2\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add an agents/*.md change to this commit without a bump; the line reads violation.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-2\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no commit has the scope, test -n fails and nothing prints.
8. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-2\): ' | head -1 | cut -d' ' -f1); test -n "$C" && echo "files=$(git show --name-only --format= "$C" | wc -l) other=$(git show --name-only --format= "$C" | grep -cvxF -e tests/doc-relative-links.test.js -e tests/resync-vendored-skills-offline.test.sh)"`
   exit: 0
   stdout: `files=2 other=0`
   mutation: commit with `git add -A && git commit` while another batch unit has edits; the other unit's files are counted and the line differs.
9. run: `git diff --quiet HEAD -- tests/doc-relative-links.test.js tests/resync-vendored-skills-offline.test.sh && echo own-files-clean`
   exit: 0
   stdout: `own-files-clean`
   mutation: skip edit 8; both files differ from HEAD and git diff exits 1.

## Pre-resolved context
tdd: yes tests/doc-relative-links.test.js
blast-radius: tests/doc-relative-links.test.js:3, tests/doc-relative-links.test.js:13, tests/doc-relative-links.test.js:28, tests/doc-relative-links.test.js:32, tests/doc-relative-links.test.js:44, tests/resync-vendored-skills-offline.test.sh:7, tests/resync-vendored-skills-offline.test.sh:59, tests/validate.sh:932
commit-message: test(lo2-2): link test balanced parentheses, scope notes and in-suite fixtures; resync fixtures (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
parallel: Batch A; never run git add; if the commit fails on index.lock, re-run edit 8 once the other commit finishes and never delete the lock; if your stop is blocked by a test failing on another unit's file, write the WIP sentinel naming that unit and report
measured: every before block and anchor matched exactly once at da1b2da; after edits 1-3 the suite printed FAIL (fixture) and m1 not found; after all edits both tests passed in a scratch clone
review-packet:
~~~
unit: lo2-2
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

### Contract lo2-3: contract-guard scribe shape; archive check in the merge gate

Suggested model: haiku

~~~~
Unit: lo2-3

## Objective
`tests/contract-examples.test.js` builds an issue body that carries both contracts, the documented lead layout and then the scribe example fenced under `## Dispatch contract (scribe)`. It checks that `bin/contract-guard.js --shape=scribe` scores the scribe one haiku 7/7, that the lead one still scores haiku, that the body without its `~~~~` lines scores the scribe one `reason=no-contract`, and that the documented issue-body example ends with its contract fence. `tests/validate.sh` gains a section running `docs/plans/skr-criteria/skr-archive-verify.sh`, the archive's byte-identity check. Batch A unit: it runs in parallel with lo2-1, lo2-2 and lo2-4. No version bump, no CHANGELOG entry (lo2-5 writes it).

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers-2.md`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `tests/contract-examples.test.js` (anchor: line matching `console.log(failures === 0 ? '\nAll contract-examples checks passed.' :`)
- `tests/validate.sh` (anchor: line matching `echo "== scripts/resync-vendored-skills.sh: offline FILES/SKILL_ORDER checks (sfu-5) =="`)

## Ordered edits
1. file: `tests/contract-examples.test.js`
   anchor: line matching `console.log(failures === 0 ? '\nAll contract-examples checks passed.' :`
   before:
   ~~~
   console.log(failures === 0 ? '\nAll contract-examples checks passed.' : `\n${failures} check(s) failed.`);
   ~~~
   after:
   ~~~
   // lo2-3: an issue body carrying both contracts, the lead one and then the scribe one under
   // `## Dispatch contract (scribe)`, each fenced; the guard finds each by its own shape.
   function guardShape(text, id, shape) {
     const r = spawnSync('node', ['bin/contract-guard.js', '-', `--unit=${id}`, `--shape=${shape}`], { cwd: REPO_ROOT, encoding: 'utf8', input: text });
     return r.stdout.trim();
   }
   function bothBody() {
     return `${issueBody()}\n\n## Dispatch contract (scribe)\n~~~~\n${example('scribe-contract-example')}\n~~~~\n`;
   }

   check('issue-body layout example ends with its fenced contract', () => {
     const lines = example('issue-body-layout-example').split('\n').filter((l) => l.trim() !== '');
     assert.strictEqual(lines[lines.length - 1], '~~~~');
   });

   check('issue body with both contracts: the scribe one scores haiku through contract-guard --shape=scribe', () => {
     assert.strictEqual(guardShape(bothBody(), 'demo-8', 'scribe'), 'contract-guard: haiku unit=demo-8 shape=scribe score=7/7');
   });

   check('issue body with both contracts: the lead one still scores haiku', () => {
     assert.strictEqual(guardShape(bothBody(), 'demo-7', 'lead'), 'contract-guard: haiku unit=demo-7 shape=lead score=7/7');
   });

   check('issue body with both contracts, unfenced: the scribe one scores no-contract', () => {
     const unfenced = bothBody().split('\n').filter((l) => l !== '~~~~').join('\n');
     assert.strictEqual(guardShape(unfenced, 'demo-8', 'scribe'), 'contract-guard: sonnet unit=demo-8 shape=scribe reason=no-contract');
   });

   console.log(failures === 0 ? '\nAll contract-examples checks passed.' : `\n${failures} check(s) failed.`);
   ~~~
   indent: 3
2. file: `tests/validate.sh`
   anchor: line matching `echo "== scripts/resync-vendored-skills.sh: offline FILES/SKILL_ORDER checks (sfu-5) =="`
   before:
   ~~~
   echo
   echo "== scripts/resync-vendored-skills.sh: offline FILES/SKILL_ORDER checks (sfu-5) =="
   ~~~
   after:
   ~~~
   echo
   echo "== docs/archive/skills: archived originals are byte-identical to git (Bash, skr-archive-verify, lo2-3) =="
   if bash docs/plans/skr-criteria/skr-archive-verify.sh; then
     echo "OK   docs/plans/skr-criteria/skr-archive-verify.sh"
   else
     echo "FAIL docs/plans/skr-criteria/skr-archive-verify.sh"
     fail=1
   fi

   echo
   echo "== scripts/resync-vendored-skills.sh: offline FILES/SKILL_ORDER checks (sfu-5) =="
   ~~~
   indent: 3
3. command: `git commit -m "test(lo2-3): contract-guard scribe-shape issue body; archive byte-identity check in validate.sh (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>" -- tests/contract-examples.test.js tests/validate.sh`
   expect: 0

## Do NOT touch
- `agents/task-master.md` (lo2-5 owns it; the test builds the two-contract body itself, so it needs no new example marker)
- `bin/contract-guard.js` and `bin/contract-score.js` (unchanged by design)
- `docs/plans/skr-criteria/skr-archive-verify.sh` (wired in, not edited)

## Acceptance criteria
1. run: `node tests/contract-examples.test.js`
   exit: 0
   stdout: `All contract-examples checks passed.`
   mutation: drop the two `~~~~` lines that bothBody() puts around the scribe example in edit 1; the --shape=scribe check gets reason=no-contract, prints FAIL and the test exits 1.
2. run: `node tests/contract-examples.test.js | grep -c '^OK   issue body with both contracts'`
   exit: 0
   stdout: `3`
   mutation: skip edit 1; the count is 0 and grep exits 1.
3. run: `f=$(mktemp) && { echo 'fail=0'; sed -n '/^echo "== docs\/archive\/skills: archived originals/,/^fi$/p' tests/validate.sh; echo 'echo "section-fail=$fail"'; } > "$f" && bash "$f"; rm -f "$f"`
   exit: 0
   stdout: `OK   docs/plans/skr-criteria/skr-archive-verify.sh`
   mutation: skip edit 2; sed extracts nothing and only section-fail=0 prints. Changing one byte of docs/archive/skills/grilling/SKILL.md instead makes the section print FAIL and section-fail=1.
4. run: `bash -n tests/validate.sh`
   exit: 0
   stdout: `empty`
   mutation: drop the closing fi of the section added by edit 2; bash -n reports a syntax error and exits 2.
5. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-3\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add an agents/*.md change to this commit without a bump; the line reads violation.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-3\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; no commit has the scope, test -n fails and nothing prints.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-3\): ' | head -1 | cut -d' ' -f1); test -n "$C" && echo "files=$(git show --name-only --format= "$C" | wc -l) other=$(git show --name-only --format= "$C" | grep -cvxF -e tests/contract-examples.test.js -e tests/validate.sh)"`
   exit: 0
   stdout: `files=2 other=0`
   mutation: commit with `git add -A && git commit` while another batch unit has edits; the other unit's files are counted and the line differs.
8. run: `git diff --quiet HEAD -- tests/contract-examples.test.js tests/validate.sh && echo own-files-clean`
   exit: 0
   stdout: `own-files-clean`
   mutation: skip edit 3; both files differ from HEAD and git diff exits 1.

## Pre-resolved context
tdd: yes tests/contract-examples.test.js
blast-radius: tests/contract-examples.test.js:65, tests/contract-examples.test.js:84, tests/validate.sh:939, agents/task-master.md:327, agents/task-master.md:364, bin/contract-guard.js:93
commit-message: test(lo2-3): contract-guard scribe-shape issue body; archive byte-identity check in validate.sh (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
parallel: Batch A; never run git add; if the commit fails on index.lock, re-run edit 3 once the other commit finishes and never delete the lock; if your stop is blocked by a test failing on another unit's file, write the WIP sentinel naming that unit and report
measured: every before block and anchor matched exactly once at da1b2da; all criteria held in a scratch clone (the guard printed haiku 7/7 for demo-8 scribe and demo-7 lead, and no-contract unfenced)
review-packet:
~~~
unit: lo2-3
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract lo2-4: join block advisory-pass wording and per-port text pins

Suggested model: sonnet

~~~~
Unit: lo2-4

## Objective
The SubagentStop join block in `hooks/scripts/lib/stop-gate-core.sh` tells an advisory pass that it owns no verdict and writes no marker. Only the message text changes: exit codes, the join logic and every other line stay as they are. `tests/adapter-stop-gate-parity.test.sh` gains case (f5), run on the Claude, Codex and Cursor ports. It seeds two unsatisfied stamps, then requires exit 2, the two-unit list `unit-f5a, unit-f5b`, the ownerless-stamp guidance and the advisory-pass clause. TDD order: edit 1 (test) first; f5 prints FAIL on all three ports. After edit 2, f5 still prints FAIL on Codex and Cursor, until edit 3 renders their copies. Batch A unit: it runs in parallel with lo2-1, lo2-2 and lo2-3, and is the only batch unit that renders (measured: with the other batch files dirty, the render reaches only this unit's copies and the persona config). No version bump, no CHANGELOG entry (lo2-5 writes it).

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers-2.md`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `tests/adapter-stop-gate-parity.test.sh` (anchor: line matching `f0_case claude`)
- `hooks/scripts/lib/stop-gate-core.sh` (anchor: line matching `block "No verdict is recorded for the stamped unit(s)`)
- `.claude/hooks/scripts/lib/stop-gate-core.sh`, `adapters/codex/hooks/scripts/lib/stop-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh` and the persona config's fileHashes (rendered by edit 3)

## Ordered edits
1. file: `tests/adapter-stop-gate-parity.test.sh`
   anchor: line matching `f0_case claude`
   before:
   ~~~
   f0_case claude
   f2_case claude
   ~~~
   after:
   ~~~
   # f5 (lo2-4): the join block's text, pinned on every port (the copies are byte-identical, but
   #     this proves each entry script delivers the core's message): two unsatisfied stamps are
   #     listed in glob order, and the block carries the ownerless-stamp and advisory-pass guidance.
   f5_case() {
     local port="$1" dot dir rc=0 err
     dot="$(dotdir_for "$port")"
     dir="$(make_project "$port" f5-text)"
     run_gated_stop "$port" "$dir" 2>/dev/null || true
     seed_join_stamp "$dir" "$port" unit-f5a none -
     seed_join_stamp "$dir" "$port" unit-f5b none -
     err="$(run_reviewer_stop "$port" "$dir" 2>&1 >/dev/null)" || rc=$?
     check "(f5) $port: the join block lists both units and carries the ownerless-stamp and advisory-pass guidance" \
       "$([ "$rc" = 2 ] \
          && grep -qF 'No verdict is recorded for the stamped unit(s): unit-f5a, unit-f5b.' <<< "$err" \
          && grep -qF 'A review-join stamp names no owner' <<< "$err" \
          && grep -qF 'report this block to your dispatcher and wait' <<< "$err" \
          && grep -qF 'unless you are an advisory pass (which owns no verdict and writes no marker)' <<< "$err" \
          && echo true || echo false)" \
       "rc=$rc"
   }
   f0_case claude
   f2_case claude
   for port in $PORTS; do f5_case "$port"; done
   ~~~
   indent: 3
2. file: `hooks/scripts/lib/stop-gate-core.sh`
   anchor: line matching `block "No verdict is recorded for the stamped unit(s): ${missing}. A review-join stamp names no owner, so a unit another reviewer is reviewing right now is listed here too: if you were not dispatched for one of them, do not write its marker; report this block to your dispatcher and wait. For each unit you did review, a v3 PASS or FAIL marker must be written, first line exactly:`
   before:
   ~~~
         block "No verdict is recorded for the stamped unit(s): ${missing}. A review-join stamp names no owner, so a unit another reviewer is reviewing right now is listed here too: if you were not dispatched for one of them, do not write its marker; report this block to your dispatcher and wait. For each unit you did review, a v3 PASS or FAIL marker must be written, first line exactly:
   ~~~
   after:
   ~~~
         block "No verdict is recorded for the stamped unit(s): ${missing}. A review-join stamp names no owner, so a unit another reviewer is reviewing right now is listed here too: if you were not dispatched for one of them, do not write its marker; report this block to your dispatcher and wait. For each unit you did review, unless you are an advisory pass (which owns no verdict and writes no marker), a v3 PASS or FAIL marker must be written, first line exactly:
   ~~~
   indent: 3
3. command: `node bin/cli.js --update --force-render`
   expect: 0
4. command: `git commit -m "fix(lo2-4): join block tells an advisory pass it writes no marker; per-port text pins (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" -- hooks/scripts/lib/stop-gate-core.sh tests/adapter-stop-gate-parity.test.sh adapters/codex/hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh .claude ':(exclude).claude/agent-memory'`
   expect: 0

## Do NOT touch
- `hooks/scripts/lib/reviewer-route-gate-core.sh` and `hooks/hooks.json` (stamp writing and hook wiring belong to the held ownership fix)
- `tests/review-join.test.sh` (its residual case must keep passing unchanged; the held ownership fix is what flips it)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `bash tests/adapter-stop-gate-parity.test.sh`
   exit: 0
   stdout: `OK   (f5) cursor:`
   mutation: skip edit 2; the advisory-pass clause is missing, f5 prints FAIL on all three ports and the test exits 1.
2. run: `bash tests/adapter-stop-gate-parity.test.sh 2>&1 | grep -c '^OK   (f5) '`
   exit: 0
   stdout: `3`
   mutation: skip edit 3; the Codex and Cursor copies keep the old text, only the Claude line is OK and the count is 1 (measured).
3. run: `bash tests/review-join.test.sh`
   exit: 0
   stdout: `OK   (residual-ownerless-stamp)`
   mutation: drop "report this block to your dispatcher and wait" from edit 2's text; the residual case prints FAIL and the test exits 1.
4. run: `bad=0; for f in .claude/hooks/scripts/lib/stop-gate-core.sh adapters/codex/hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh; do cmp -s hooks/scripts/lib/stop-gate-core.sh "$f" || { echo "differs: $f"; bad=1; }; done; [ "$bad" = 0 ] && echo copies-identical`
   exit: 0
   stdout: `copies-identical`
   mutation: skip edit 3; three differs lines print, copies-identical does not, and the command exits 1.
5. run: `node tests/filehashes-currency.test.js`
   exit: 0
   stdout: `All filehashes-currency tests passed.`
   mutation: skip edit 3; the recorded hashes are stale and the test exits 1.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-4\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add an agents/*.md change to this commit without a bump; the line reads violation.
7. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-4\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; no commit has the scope, test -n fails and nothing prints.
8. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-4\): ' | head -1 | cut -d' ' -f1); test -n "$C" && echo "files=$(git show --name-only --format= "$C" | wc -l) other=$(git show --name-only --format= "$C" | grep -cvxF -e hooks/scripts/lib/stop-gate-core.sh -e tests/adapter-stop-gate-parity.test.sh -e adapters/codex/hooks/scripts/lib/stop-gate-core.sh -e adapters/cursor/hooks/scripts/lib/stop-gate-core.sh -e .claude/hooks/scripts/lib/stop-gate-core.sh)"`
   exit: 0
   stdout: `files=6 other=1`
   mutation: commit with `git add -A && git commit` while another batch unit has edits; the other unit's files are counted and the line differs (the one other file is the persona config).
9. run: `git diff --quiet HEAD -- hooks adapters tests/adapter-stop-gate-parity.test.sh .claude/hooks && echo own-files-clean`
   exit: 0
   stdout: `own-files-clean`
   mutation: skip edit 4; the edited files differ from HEAD and git diff exits 1.

## Pre-resolved context
tdd: yes tests/adapter-stop-gate-parity.test.sh
blast-radius: hooks/scripts/lib/stop-gate-core.sh:469, tests/adapter-stop-gate-parity.test.sh:186, tests/adapter-stop-gate-parity.test.sh:236, tests/review-join.test.sh:631, bin/cli.js:690
commit-message: fix(lo2-4): join block tells an advisory pass it writes no marker; per-port text pins (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
parallel: Batch A; never run git add; the pathspec .claude with the agent-memory exclusion commits the rendered hook copy and the persona config without naming the config; if the commit fails on index.lock, re-run edit 4 once the other commit finishes and never delete the lock; if your stop is blocked by a test failing on another unit's file, write the WIP sentinel naming that unit and report
measured: every before block and anchor matched exactly once at da1b2da; after edits 1-2 f5 was OK on claude and FAIL on codex and cursor; after edit 3 all three were OK and the render changed only the three copies and the persona config
review-packet:
~~~
unit: lo2-4
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

### Contract lo2-5: integration, stamped wording, protocol links, CHANGELOG, render (0.31.171)

Suggested model: haiku

~~~~
Unit: lo2-5

## Objective
Serial integration unit, dispatched only after lo2-1..lo2-4 have all PASSed. `agents/lead-programmer.md` says the `tdd` skill is also `skills/tdd/SKILL.md` in the antislop repo itself. `agents/orchestrator.md` calls the scribe contract tilde-fenced. `agents/task-master.md` puts the contracts last, lead then scribe, and says a `stdout:` fragment is text the command prints, never a description. `templates/persona-protocol.md` names ADR-0016 and ADR-0028 by path instead of by a relative link that broke in every rendered `.claude/agents/*.md`. `tests/doc-relative-links.test.js` also scans `.claude/agents`. Version 0.31.171. `CHANGELOG.md` loses the double blank line under `[Unreleased]` and gains one entry per lo2 unit. Everything is rendered and committed in one commit.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-leftovers-2.md`. Criteria script: `docs/plans/lo2-criteria/lo2-claims.sh`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop`.

## Affected files
- `agents/lead-programmer.md` (anchor: line matching `directory, not a path in the project's own tree). For hard bugs, invoke`)
- `agents/orchestrator.md` (anchor: line matching `present) as written: the`)
- `agents/task-master.md` (anchors: line matching `in the issue body under`, line matching `**Issue-body layout.** A published unit's issue body keeps its prose first and` and line matching `(a fragment, or`)
- `templates/persona-protocol.md` (anchors: line matching `reviewers' operations — this scoped-relevance mechanism (see`, line matching `reviewer). [ADR-0016]` and line matching `Neither axis's rule changes here: [ADR-0028]`)
- `tests/doc-relative-links.test.js` (anchor: line matching `'docs/archive/skills/README.md', 'skills', 'templates'];`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.170",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- rendered by edit 14: `.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the persona config

## Ordered edits
1. file: `agents/lead-programmer.md`
   anchor: line matching `directory, not a path in the project's own tree). For hard bugs, invoke`
   before:
   ~~~
     project that is `skills/tdd/SKILL.md` under the antislop plugin's install
     directory, not a path in the project's own tree). For hard bugs, invoke
   ~~~
   after:
   ~~~
     project that is `skills/tdd/SKILL.md` under the antislop plugin's install
     directory, not a path in the project's own tree; in the antislop repo
     itself it is also `skills/tdd/SKILL.md` at the repo root). For hard bugs, invoke
   ~~~
   indent: 3
2. file: `agents/orchestrator.md`
   anchor: line matching `present) as written: the`
   before:
   ~~~
   present) as written: the `~~~`-fenced block under the issue body's `##
   ~~~
   after:
   ~~~
   present) as written: the tilde-fenced block under the issue body's `##
   ~~~
   indent: 3
3. file: `agents/task-master.md`
   anchor: line matching `in the issue body under`
   before:
   ~~~
     in the issue body under `## Dispatch contract`, last, as one fenced block
     whose first interior line is `Unit: <task-id>`. Use a tilde fence longer
   ~~~
   after:
   ~~~
     in the issue body under `## Dispatch contract`, as one fenced block
     whose first interior line is `Unit: <task-id>`. The contracts go last in the
     body, the lead contract first and the scribe contract (if any) after it,
     under its own heading (see **Scribe dispatch contract**). Use a tilde fence longer
   ~~~
   indent: 3
4. file: `agents/task-master.md`
   anchor: line matching `**Issue-body layout.** A published unit's issue body keeps its prose first and`
   before:
   ~~~
   **Issue-body layout.** A published unit's issue body keeps its prose first and
   the contract last, fenced; `tests/contract-examples.test.js` substitutes the
   ~~~
   after:
   ~~~
   **Issue-body layout.** A published unit's issue body keeps its prose first and
   the contracts last, fenced, the lead contract and then the scribe contract (if
   any); `tests/contract-examples.test.js` substitutes the
   ~~~
   indent: 3
5. file: `agents/task-master.md`
   anchor: line matching `(a fragment, or`
   before:
   ~~~
        (inline code), `exit:` (an integer), `stdout:` (a fragment, or
        `empty`) and `mutation:` (the edit that makes the check fail, so it is
   ~~~
   after:
   ~~~
        (inline code), `exit:` (an integer), `stdout:` (a fragment, or
        `empty`; a fragment is text the command prints, such as
        `All checks passed.`, never a description such as "no FAIL line") and
        `mutation:` (the edit that makes the check fail, so it is
   ~~~
   indent: 3
6. file: `templates/persona-protocol.md`
   anchor: line matching `reviewers' operations — this scoped-relevance mechanism (see`
   before:
   ~~~
   reviewers' operations — this scoped-relevance mechanism (see
   [ADR-0028](../docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md)) is
   ~~~
   after:
   ~~~
   reviewers' operations — this scoped-relevance mechanism (see ADR-0028,
   `docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md`) is
   ~~~
   indent: 3
7. file: `templates/persona-protocol.md`
   anchor: line matching `reviewer). [ADR-0016](../docs/adr/0016-per-unit-review-join.md) names this`
   before:
   ~~~
   reviewer). [ADR-0016](../docs/adr/0016-per-unit-review-join.md) names this
   ~~~
   after:
   ~~~
   reviewer). ADR-0016 (`docs/adr/0016-per-unit-review-join.md`) names this
   ~~~
   indent: 3
8. file: `templates/persona-protocol.md`
   anchor: line matching `Neither axis's rule changes here: [ADR-0028](../docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md)'s`
   before:
   ~~~
   Neither axis's rule changes here: [ADR-0028](../docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md)'s
   ~~~
   after:
   ~~~
   Neither axis's rule changes here: ADR-0028's
   ~~~
   indent: 3
9. file: `tests/doc-relative-links.test.js`
   anchor: line matching `'.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills', 'templates'];`
   before:
   ~~~
       '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills', 'templates'];
   ~~~
   after:
   ~~~
       '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills', 'templates',
       '.claude/agents'];
   ~~~
   indent: 3
10. file: `.claude-plugin/plugin.json`
   anchor: line matching `"version": "0.31.170",`
   before:
   ~~~
     "version": "0.31.170",
   ~~~
   after:
   ~~~
     "version": "0.31.171",
   ~~~
   indent: 3
11. file: `package.json`
   anchor: line matching `"version": "0.31.170",`
   before:
   ~~~
     "version": "0.31.170",
   ~~~
   after:
   ~~~
     "version": "0.31.171",
   ~~~
   indent: 3
12. command: `python3 -I -c "p='CHANGELOG.md';t=open(p).read();o='\n\n\n**version-stamp-check: --no-textconv and four more pinned mutants (lov-2).**';assert t.count(o)==1;open(p,'w').write(t.replace(o,o[1:]))"`
   expect: 0
13. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Skills-audit leftovers 2: stamped wording and protocol links (lo2-5, 0.31.171).** `agents/lead-programmer.md` says the `tdd` skill is also `skills/tdd/SKILL.md` in the antislop repo itself; `agents/orchestrator.md` calls the scribe contract tilde-fenced; `agents/task-master.md` puts the contracts last, the lead contract and then the scribe contract, and says a `stdout:` fragment is text the command prints, never a description; `templates/persona-protocol.md` names ADR-0016 and ADR-0028 by path instead of by a relative link that broke in every rendered `.claude/agents/*.md`; `tests/doc-relative-links.test.js` also scans `.claude/agents`. A double blank line under `[Unreleased]` is removed.

   **Review-join block text: advisory passes and per-port pins (lo2-4).** The SubagentStop join block in `hooks/scripts/lib/stop-gate-core.sh` (and its `.claude` and adapter copies) tells an advisory pass that it owns no verdict and writes no marker. `tests/adapter-stop-gate-parity.test.sh` case (f5) pins the block text, with a two-unit list, on the Claude, Codex and Cursor ports. Exit codes and the join logic are unchanged.

   **Contract guard scribe shape; archive check in the merge gate (lo2-3).** `tests/contract-examples.test.js` runs `bin/contract-guard.js --shape=scribe` over an issue body carrying both contracts (haiku 7/7, and no-contract once unfenced) and checks that the documented layout ends with its fenced contract. `tests/validate.sh` runs `docs/plans/skr-criteria/skr-archive-verify.sh`, the archive's byte-identity check.

   **Link and resync tests: balanced parentheses and in-suite fixtures (lo2-2).** `tests/doc-relative-links.test.js` scans a link destination to its matching parenthesis, so a parenthesised title or a destination with balanced parentheses parses; it also covers `templates/`, says why `docs/plans/` and `adapters/` stay out of scope, and runs a fixture repository and five mutated copies of itself. `tests/resync-vendored-skills-offline.test.sh` runs five mutated copies of the resync script, one planted defect each.

   **Glossary: surviving mutant, spec publication, issue-body layout; review-join residual widened (lo2-1).** `CONTEXT.md` defines surviving mutant and spec publication. `docs/harness-glossary.md` defines issue-body layout, widens the review-join stamp residual to un-stamped reviewers, advisory passes and the converse let-through, and corrects the scoped unit set, which is derived from every stamp, not from the stopping reviewer's own.
   ~~~
   indent: 3
14. command: `node bin/cli.js --update --force-render`
   expect: 0
15. command: `git commit -m "docs(lo2-5): stamped wording, protocol links, link-test scope, CHANGELOG (0.31.171) (#530 follow-up)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>" -- agents/lead-programmer.md agents/orchestrator.md agents/task-master.md templates/persona-protocol.md tests/doc-relative-links.test.js .claude-plugin/plugin.json package.json CHANGELOG.md .claude ':(exclude).claude/agent-memory'`
   expect: 0

## Do NOT touch
- `adapters/` (the ports carry no protocol links and no task-master or orchestrator text this unit changes)
- `docs/plans/` other than reading (dated records; see the link test's out-of-scope note)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `bash docs/plans/lo2-criteria/lo2-claims.sh lo2-5`
   exit: 0
   stdout: `lo2-claims: lo2-5 ok`
   mutation: skip edit 2; the orchestrator source and its render keep the old wording, three checks print FAIL and the script exits 1.
2. run: `bash docs/plans/lov-criteria/lov-claims.sh lov-1 && bash docs/plans/lov-criteria/lov-claims.sh lov-4`
   exit: 0
   stdout: `lov-claims: lov-4 ok`
   mutation: drop "as one fenced block" from edit 3's text; the lov-4 check counts 0 and the script exits 1.
3. run: `node tests/doc-relative-links.test.js`
   exit: 0
   stdout: `doc-relative-links: ok (162 links in 93 files)`
   mutation: skip edit 7; after the render the six full-tier agents each carry a broken ../docs/adr link, which the .claude/agents scope reports, and the test exits 1.
4. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;if(a!==b||a!=='0.31.171')process.exit(1);console.log('version-sync: ok')"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 11; package.json stays 0.31.170 and the script exits 1.
5. run: `node bin/cli.js --update --force-render --dry-run | grep -c 'would be'`
   exit: 1
   stdout: `0`
   mutation: skip edit 14; the rendered agents are stale, the count is above 0 and grep exits 0.
6. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-5\): ' | head -1 | cut -d' ' -f1); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes old: 0.31.170 new: 0.31.171 offenders: -`
   mutation: skip edit 13; the commit bumps without a CHANGELOG entry naming 0.31.171 and the line reads violation.
7. run: `python3 -I -c "t=open('CHANGELOG.md').read();a=t.index('## [Unreleased]');b=t.index('\n## [',a+5);s=t[a:b];print('unreleased-blank-runs=%d entries=%d'%(s.count('\n\n\n'),s.count('(lo2-')))"`
   exit: 0
   stdout: `unreleased-blank-runs=0 entries=5`
   mutation: skip edit 12; the double blank line stays and the line reads unreleased-blank-runs=1.
8. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-5\): ' | head -1 | cut -d' ' -f1); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 15; no commit has the scope, test -n fails and nothing prints.
9. run: `C=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(lo2-5\): ' | head -1 | cut -d' ' -f1); test -n "$C" && echo "other=$(git show --name-only --format= "$C" | grep -v '^\.claude/' | grep -cvxF -e agents/lead-programmer.md -e agents/orchestrator.md -e agents/task-master.md -e templates/persona-protocol.md -e tests/doc-relative-links.test.js -e .claude-plugin/plugin.json -e package.json -e CHANGELOG.md)"`
   exit: 0
   stdout: `other=0`
   mutation: commit with `git add -A && git commit` while an unrelated file is dirty; that file is counted and the line reads other=1.
10. run: `git diff --quiet HEAD -- agents templates tests/doc-relative-links.test.js .claude-plugin package.json CHANGELOG.md .claude/agents && echo own-files-clean`
   exit: 0
   stdout: `own-files-clean`
   mutation: skip edit 15; the edited files differ from HEAD and git diff exits 1.
11. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `All checks passed.`
   mutation: skip edit 14; the rendered-mirror and fileHashes sections print FAIL and the run ends One or more checks FAILED.

## Pre-resolved context
tdd: no stamped prose, version bump and render; claim checks in docs/plans/lo2-criteria/lo2-claims.sh (14 checks, all red at da1b2da)
blast-radius: agents/lead-programmer.md:58, agents/orchestrator.md:52, agents/task-master.md:63, agents/task-master.md:163, agents/task-master.md:322, templates/persona-protocol.md:239, templates/persona-protocol.md:248, templates/persona-protocol.md:250, tests/doc-relative-links.test.js:15, CHANGELOG.md:9
commit-message: docs(lo2-5): stamped wording, protocol links, link-test scope, CHANGELOG (0.31.171) (#530 follow-up)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
base: lo2-1..lo2-4 committed and PASSed, plugin version 0.31.170; if the version differs, STOP (R5)
measured: every before block and anchor matched exactly once on the tree lo2-1..lo2-4 leave, applied in a scratch clone; bash tests/validate-lanes.sh --lanes 6 printed All checks passed. (119 sections)
review-packet:
~~~
unit: lo2-5
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

## Open Questions

1. (Blocking for Step 6 only; holds no lo2-1..lo2-5 unit.) **How should a review-join stamp be tied to the reviewer that owns it, given that `SubagentStart` cannot name the unit?** Measured on Claude Code 2.1.300: the `SubagentStart` payload is `{session_id, transcript_path, cwd, ..., hook_event_name, agent_id, agent_type}`, with no prompt and no `tool_use_id`. Design B as requested ("bind an owner at reviewer start") therefore has no unit to bind. Options:
   - **C (recommended default): read the stopping reviewer's own prompt at SubagentStop.** Read the first JSONL record of `agent_transcript_path`. If it is `type:"user"` and the first non-blank line of `message.content` matches the route gate's own `^Unit:[[:space:]]+<id>[[:space:]]*$` rule, the stopping reviewer's scope is that unit's stamp and its advisory stamp. Its own unsatisfied stamp still blocks it, and other units' stamps neither block it nor are consumed for it. In every other case (empty path, unreadable file, no `Unit:` line, the Codex and Cursor ports) it falls back to today's all-stamps behaviour, so enforcement is never weaker than today. No new hook event and no stamp-format change. The cost is a dependency on Claude Code's transcript format (measured: the lov-5 reviewer's file starts `{"type":"user",...,"content":"Unit: lov-5\n...`), which ADR-0016's amendment records.
   - **B' (B plus correlation).** The route gate records PreToolUse's `tool_use_id` in the stamp. A new `SubagentStart` hook reads `<dir of transcript_path>/<session_id>/subagents/agent-<agent_id>.meta.json`, whose `toolUseId` names the dispatch, and writes `owner=<agent_id>` onto the matching stamp. Deterministic, but it needs two hooks and a new `hooks.json` event. It depends on the same transcript store, and on `meta.json` already existing when `SubagentStart` fires, which is not measured.
   - **B (as requested, heuristic): bind the newest unowned stamp at `SubagentStart`.** It races when two reviewers are dispatched in one message. A wrong binding turns another unit's stamp fail-open, which is weaker than today. Not recommended.
   - **A: keep the documented residual.** Rely on R3's sequential reviews (which this plan already requires) and on the lo2-4 block text.

   Whichever is chosen, Step 6 lists the fixed file set, the test flip, the mutation proofs and the rollback. The answer goes into a one-unit plan, `docs/plans/2026-10-14-review-join-stamp-ownership.md`.

## Self-check
- CHK1: Does every finding M1-M16 map to a unit criterion or an Open Question? — PASS. M1-M5 map to lo2-1 criteria 1-3, M6-M8 to lo2-2 criteria 1-3 and lo2-5 criterion 3, M9-M10 to lo2-3 criteria 1-3, M11 to lo2-4 criteria 1-3, M12-M15 to lo2-5 criteria 1-3 and 7, and M16 to Open Question 1.
- CHK2: Are the four Batch A units file-disjoint, with every shared file owned by exactly one unit? — PASS. See the Parallel execution plan table. `tests/doc-relative-links.test.js` and the persona config each have a batch owner and a later owner, never two at once.
- CHK3: Can a concurrent unit's commit sweep in another unit's files? — PASS. No contract runs `git add`. Every commit names its paths (`git commit -- <paths>`), and criteria `files= other=` fail on a stray file. lo2-4's render reach was measured.
- CHK4: Do the prose units' criteria count claims rather than check existence? — PASS. `lo2-claims.sh` counts the wrong phrase (want 0) and the corrected phrase (want 1). All 26 checks are red at `da1b2da` (lo2-1 12 of 12, lo2-5 14 of 14) and green after.
- CHK5: Do the units agree on the version sequence? — PASS. Only lo2-5 bumps (0.31.170 → 0.31.171). Every batch commit is checked to report `touched: no`.
- CHK6: Does any `stdout:` field describe output instead of quoting it? — PASS. Every `stdout:` is printed text or `empty`. The lane run uses `All checks passed.`
- CHK7: Do all five contracts pass the guard? — PASS. `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-leftovers-2.md --unit=lo2-N` prints `haiku ... score=7/7` for N = 1..5.
- CHK8: Does every before block and anchor match exactly once on the tree its unit applies to? — PASS. The contracts were parsed from this file and applied in order (lo2-1..lo2-4, then lo2-5) to a fresh clone of `da1b2da`.
- CHK9: Does every criterion hold after its unit? — PASS, with one note. All criteria held in the clone. One of five lane runs over the finished tree printed `One or more checks FAILED.`, and four reruns (two before, two after) passed. The failing section was not captured, so R11 treats a lone lane FAIL as a re-run-once, then report.
- CHK10: Is each mutation line true? — PASS for those measured in the clone: lo2-1 criterion 2, lo2-2 criteria 1 and 4, lo2-4 criteria 1-2, lo2-5 criterion 3, and lo2-3 criterion 1's unfenced no-contract. The rest hold by construction: the commit-scope, trailer, clean-tree and version criteria have the same shape as lov's, which were proven there.
- CHK11: Is the stamp-ownership design decided or explicitly held? — FAIL (missing) — converted to Open Question 1.
- CHK12: Does the batch's stop-gate hazard (`testAndLintCommand` over a shared tree) have a defined response? — PASS. R2 and every batch contract's `parallel:` line.
- CHK13: Does any payload or command name the persona config or the per-clone review-record directory in Bash? — PASS. lo2-4 and lo2-5 commit with `.claude ':(exclude).claude/agent-memory'`, and no criterion `run:` names either path.
- CHK14: Did lo2-2 criterion 2's count match the output? — FAIL (conflicting) — revised in place. The draft regex `\((fixture|m[1-5]) ` missed `(fixture)`, which is followed by `)`, not a space, so it counted 5. It is now `\((fixture\)|m[1-5] )` and counts 6 (measured).
- CHK15: Did lo2-1 criterion 1's mutation line give the right count? — FAIL (conflicting) — revised in place. Skipping edit 4 turns four checks red, not three.
- CHK16: Does the request's "fix them" for adapters/cursor and docs/plans have a stated disposition? — PASS. Both are documented out of scope in the link-test header (lo2-2 edit 1, criterion 3), with the reasons under "Findings that get no unit".
- CHK17 (replay, item03-2-link-integrity-guard, class vacuous): Does lo2-1 AC2 still fail under its own `mutation:` line? — PASS (measured: `[[publish thresholds]]` gives exit 1).
- CHK18 (replay, ci-fetch-depth-cleanup and item17-4-name-p3-offenders, class host): Do the `version-stamp-check.sh` criteria (lo2-1 AC4, lo2-2 AC6, lo2-3 AC5, lo2-4 AC6, lo2-5 AC6) still fail under their own `mutation:` lines? — PASS. Each reads the stdout `ok`/`violation` word, not only the exit code (lov-1's note: the script exits 0 on violation), and lo2-5's mutation (skip edit 13) yields `violation`.
- CHK19 (replay, gh-303/gh339/gh354/gh409/gh426/gh429/human-review-cleanup-1, classes vacuous/host): Do lo2-1 AC6-AC7 (naming `CONTEXT.md`) still fail under their own `mutation:` lines? — PASS. AC6 counts the commit's files exactly, and AC7 is `git diff --quiet` on the named paths.
- CHK20 (replay, gh317/gh320/gh346-2/gh409/gh413/mw-step1/mw-step2, classes vacuous/host): Do lo2-3 AC3, AC4, AC7 and AC8 (naming `tests/validate.sh`) still fail under their own `mutation:` lines? — PASS. AC3 keys on the section's own OK line, which sed cannot produce when the section is absent, and a real archive byte change makes it print FAIL. AC4 is `bash -n`.
- CHK21 (replay, mw-step3/gh429/gh413/spec2-unitA/spec2-unitB, class vacuous): Do lo2-4 AC1-AC5, AC8 and AC9 still fail under their own `mutation:` lines? — PASS. AC1-AC2 were measured (count 1 before the render, 3 after). AC4 is the lov-5 `cmp` loop that prints `copies-identical` only on success.
- CHK22 (replay, gh-303/gh288-1/gh313/gh317/gh320/gh339/gh348-x/gh360/gh377-5/item04-2-apply-drops/adhoc-preload-tdd-skill, classes vacuous/host): Do lo2-5 AC4, AC5, AC7, AC9 and AC10 still fail under their own `mutation:` lines? — PASS. AC4 checks the exact version string. AC5 needs exit 1 and a count of 0. AC7 prints the blank-run count. AC9 counts unlisted files. AC10 is `git diff --quiet`.
- CHK23 (ubiquitous-language, prose mode, advisory): Does the draft drift from `CONTEXT.md` or the harness glossary? — PASS. "integration unit" and "Batch A" are plan-local words, not domain terms. "stamp ownership" refers to the **review-join stamp** residual, with no new synonym entry. The three new terms are the ones lo2-1 defines.

## Report only (out of slice, not specced)

1. `.claude/persona-config.json` `issueTracker` still cites "to-tickets' own default". Human-only edit.
2. Real prose link mistakes in dated plans (listed under "Findings that get no unit"). The plans stay out of the link test's scope.
3. `docs/self-improvement-loops.md` links to a sibling repository (`../../claude_trace/...`).
4. The Codex lead-programmer port carries the same two `tdd` companion links as the Cursor port, inside a `.toml` that the link test never scans.
5. `tests/validate.sh` serially runs longer than the 600 s Bash cap, and `testAndLintCommand` runs it at every gated SubagentStop. That is pre-existing, and R2 is how this slice works around it.

## Scribe update hint

After lo2-5 passes, scribe should check the wiki changelog for the five lo2 units, and check `.claude/wiki/modules/hooks.md`'s stop-gate notes against the new block text (advisory-pass clause). No new ADR in this slice: lo2-4 changes text only, and the ownership fix's ADR-0016 amendment belongs to the follow-up plan for Open Question 1.
