Unit: rp-s1-scribe

## Objective
Finding G (spec Step 7), one scribe run after the plan's last lead unit, rp-u6, reaches PASS: seven `CONTEXT.md` entries (**unit scope**, **standing exception**, **bump files**, **Proposed out-of-scope changes**, **knowledge proposal**, **knowledgeWrites**, **lane**) and five `docs/harness-glossary.md` entries (**reviewer dispatch header**, **review in flight**, **blast-radius script**, **provenance**, **unit-size script**); the **lane runner** entry corrected now that the lane run is the default merge gate and `--serial` exists; `.claude/wiki/modules/hooks.md` no longer prescribes the retired `defer: reviewer dispatched` write; `.claude/wiki/persona-handoff-mechanisms.md` points at the protocol's short form. Then close issue #634. This repo's `knowledgeWrites` is `apply`, and this contract names every knowledge file it edits.

## Retrieval
GitHub issues: `gh issue view 634 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-review-patches`. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 7 (rp-s1)" and Clarifications. Contract file: `docs/plans/antislop-review-patches/contracts/rp-s1.md`.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `**model policy**:`
   placement: insert after the paragraph of this entry (the last entry of the file), separated by one blank line
   indent: 3
   text:
   ~~~~
   **unit scope**:
   (unit rp-s1, 2026-10-20) — the paths a unit may change: the files under its dispatch's `## Affected files`, plus `docs/plans/` and `.claude/` bookkeeping, plus the **standing exceptions**. A path under the contract's `## Do NOT touch` is outside unit scope even when a standing exception covers it. lead-programmer edits only inside it and the reviewer FAILs a unit whose diff leaves it; any other change the writer believes is needed goes to its report under **Proposed out-of-scope changes**. Defined in `agents/lead-programmer.md` and `agents/reviewer.md`, "Unit scope" (aof-u3, rp-u1). For the scribe and spec-master, **knowledgeWrites** decides whether a knowledge file outside the list is in unit scope.
   ~~~~
2. file: `CONTEXT.md`
   heading: `**unit scope**:`
   placement: insert after the paragraph of the entry from item 1, separated by one blank line
   indent: 3
   text:
   ~~~~
   **standing exception**:
   (unit rp-s1, 2026-10-20) — a path in **unit scope** without being listed: the **bump files**; a file that an acceptance-criteria command names literally as a file it reads; and, in a fix round, a path named in a defect of the unit's `.fail` record or listed under its fix contract's `## Affected files`. A script or test that a criterion runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as `tests/validate.sh`) is never a standing exception: it is in unit scope only when listed (rp-u1). A path under the contract's `## Do NOT touch` beats every standing exception.
   ~~~~
3. file: `CONTEXT.md`
   heading: `**standing exception**:`
   placement: insert after the paragraph of the entry from item 2, separated by one blank line
   indent: 3
   text:
   ~~~~
   **bump files**:
   (unit rp-s1, 2026-10-20) — the files the project's constitution or merge gate requires every version-bumping commit to change; in this plugin's own repo `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md` (constitution P3). A **standing exception** of **unit scope**, and excluded when task-master looks for a **shared file** (`docs/harness-glossary.md`). Not the **Version-stamped file** (an ADAPT-copied file carrying a stamp comment); the unit-scope rules said "version-stamp files" until rp-u1.
   ~~~~
4. file: `CONTEXT.md`
   heading: `**bump files**:`
   placement: insert after the paragraph of the entry from item 3, separated by one blank line
   indent: 3
   text:
   ~~~~
   **Proposed out-of-scope changes**:
   (unit rp-s1, 2026-10-20) — the report heading `Proposed out-of-scope changes:` under which lead-programmer lists every change it believes is needed outside **unit scope** (a glossary entry, a README line, an ADR, a caller outside the list, an existing test its change breaks) without applying it. When the suite cannot pass without such a change, it stops as blocked and names it, and the orchestrator amends the contract. The orchestrator relays every entry to the user in its final message. The scribe's and spec-master's counterpart is the **knowledge proposal**.
   ~~~~
5. file: `CONTEXT.md`
   heading: `**Proposed out-of-scope changes**:`
   placement: insert after the paragraph of the entry from item 4, separated by one blank line
   indent: 3
   text:
   ~~~~
   **knowledge proposal**:
   (unit rp-s1, 2026-10-20) — a change to a knowledge file (`CONTEXT.md`, `docs/harness-glossary.md`, `README.md`, `docs/adr/`) that is recorded instead of applied because, under `knowledgeWrites: scoped`, the file is outside **unit scope**: the scribe lists it in its report under `Knowledge proposals:` (and in the plan's "Scribe update hint" when the dispatch names a plan), spec-master in the plan's Scribe update hint. The orchestrator relays every one to the user. `.claude/wiki/` never needs one: it is always the scribe's to write. See **knowledgeWrites**.
   ~~~~
6. file: `CONTEXT.md`
   heading: `**knowledge proposal**:`
   placement: insert after the paragraph of the entry from item 5, separated by one blank line
   indent: 3
   text:
   ~~~~
   **knowledgeWrites**:
   (unit rp-s1, 2026-10-20) — the persona-config key that decides whether scribe and spec-master edit the knowledge files directly (aof-u4). `scoped`, the default and also the reading of an absent or unrecognised value: a knowledge file is edited only when it is in **unit scope** (listed under `## Affected files`, named by the edits of a scribe contract, or named in the user's request); every other change is a **knowledge proposal**. `apply`: direct edits. Set with `node bin/cli.js --knowledge-writes=<scoped|apply>`, on a fresh install or with `--update`; the space form `--knowledge-writes <v>` exits 2 (rp-u4). Under `apply` only "no tracker issue to close" can skip the end-of-plan scribe dispatch (rp-u5).
   ~~~~
7. file: `CONTEXT.md`
   heading: `**knowledgeWrites**:`
   placement: insert after the paragraph of the entry from item 6, separated by one blank line
   indent: 3
   text:
   ~~~~
   **lane**:
   (unit rp-s1, 2026-10-20) — the pipeline a unit is routed through, picked before dispatch by the **unit-size script** (`docs/harness-glossary.md`) from the unit's planned `## Affected files` (st-u4, `agents/orchestrator.md` "Lane routing"): **small** (4 entries or fewer: no spec-master and no explorer first), **medium** (no spec-master: the orchestrator writes `## Affected files` and at most 5 steps itself) or **full** (the default feature pipeline, also for a sensitive path, a FAIL record, more than 10 entries, an unmeasurable entry, or a missing or failing script). Downgrade-only: the orchestrator may pick a heavier lane than printed, never a lighter one. Every lane ends with the reviewer. Not the lanes of the **lane runner** (`docs/harness-glossary.md`), which split the `tests/validate.sh` sections across parallel **lane copies**.
   ~~~~
8. file: `docs/harness-glossary.md`
   heading: `**decision table**:`
   placement: insert after the paragraph of this entry (the last entry of the file), separated by one blank line
   indent: 3
   text:
   ~~~~
   **reviewer dispatch header**:
   (unit rp-s1, 2026-10-20) — the block `bin/unit-bookkeeping.sh review <unit> <baseline> [--implementer-tier <t>]` writes to `.claude/bookkeeping/<unit>.header` and prints (qw-u1): `Unit: <task-id>`, `Implementer tier: <t>` (taken from the flag alone; omitted with no flag or an invalid tier), `Range: <baseline sha>..<head sha>` (two full SHAs, rp-u3), `Reviewer model: <sonnet|opus>` and the changed files. The orchestrator opens the reviewer dispatch with its `Unit:` line and, unless the dispatch is advisory, its `Implementer tier:` line verbatim. See **Reviewer dispatch opening line** in `CONTEXT.md`.
   ~~~~
9. file: `docs/harness-glossary.md`
   heading: `**reviewer dispatch header**:`
   placement: insert after the paragraph of the entry from item 8, separated by one blank line
   indent: 3
   text:
   ~~~~
   **review in flight**:
   (unit rp-s1, 2026-10-20) — the state in which the stop gate lets the main session's `Stop` through although pending-review flags stand: fresh, unsatisfied, non-advisory **review-join stamps** number at least the undeferred flags (aof-u2). A stamp is fresh when its timestamp is exactly `YYYY-MM-DDTHH:MM:SSZ`, not in the future and at most 1800 s old (`REVIEW_INFLIGHT_MAX_AGE_S`; the strict format and the future check are rp-u2), and unsatisfied while its unit has no verdict marker. The gate logs `stop-allowed=review-in-flight units=<ids>` (the audit token is hyphenated). It replaced the `defer: reviewer dispatched` flag write: a reviewer dispatched with a `Unit:` line needs no flag write. A reviewer's own stop that follows a block (`stop_hook_active: true`) still consumes its stamp and clears its flag; when its verdict is still missing it logs `loop-guard=allow marker=MISSING unit=<id>` and allows (rp-u2).
   ~~~~
10. file: `docs/harness-glossary.md`
   heading: `**review in flight**:`
   placement: insert after the paragraph of the entry from item 9, separated by one blank line
   indent: 3
   text:
   ~~~~
   **blast-radius script**:
   (unit rp-s1, 2026-10-20) — `bin/blast-radius.sh <baseline>`, installed to `.claude/bin/`, which the reviewer runs itself as `bash .claude/bin/blast-radius.sh <baseline>` to scope a review (qw-u5); it never takes a blast radius from the dispatch. For each file changed in `<baseline>..HEAD` it lists the tracked files naming it (its basename, and its stem when 4 or more characters) as `test:` or `caller:` lines, at most 40 per changed file and 300 in all, each overflow marked by a `truncated:` line (rp-u7). A test is a path under `tests/` or `__tests__/`, or a `.test`/`.spec` (or `_test`/`_spec`) name with a code extension. Line 1 is `blast-radius: provenance=<grep|none> files=<n>` (see **provenance**). The reviewer spawns the explorer only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open (operator ruling, 2026-10-20). Read-only.
   ~~~~
11. file: `docs/harness-glossary.md`
   heading: `**blast-radius script**:`
   placement: insert after the paragraph of the entry from item 10, separated by one blank line
   indent: 3
   text:
   ~~~~
   **provenance**:
   (unit rp-s1, 2026-10-20) — two senses, never interchangeable. (1) Search provenance, where a structural answer came from: the **blast-radius script**'s header field, `provenance=grep` (git grep ran for every changed file) or `provenance=none` (an empty range or a failed search, the reviewer's cue to spawn the explorer); the explorer likewise says whether its answer is graph-derived or grep-fallback. (2) The reviewer's provenance stamp on an escalation packet: the **verifiedBy** / **functionsAuthoredBy** block in its `manifest.json`, which records who authored the `functions[]` array and how it was verified. Eval result rows use the word in a third, unrelated sense (**stale provenance**, **mixed provenance**).
   ~~~~
12. file: `docs/harness-glossary.md`
   heading: `**provenance**:`
   placement: insert after the paragraph of the entry from item 11, separated by one blank line
   indent: 3
   text:
   ~~~~
   **unit-size script**:
   (unit rp-s1, 2026-10-20) — `bin/unit-size.sh <unit> (--contract <path> | -- <path>...)`, installed to `.claude/bin/` (st-u4): picks a unit's **lane** (`CONTEXT.md`) from its planned `## Affected files` before anything is dispatched, prints `lane: <small|medium|full> files=<n> reason=<word>` and writes `.claude/bookkeeping/<unit>.lane` and `<unit>.scope`. Entries under `.claude/` and `docs/plans/` never count; a sensitive path (the class `hooks/scripts/reviewer-tier.sh` uses), a FAIL record, more than 10 entries or an unmeasurable entry is full. Exit 0, or 2 on a bad unit id. reviewer-tier.sh still measures the actual diff afterwards.
   ~~~~
13. file: `docs/harness-glossary.md`
   heading: `**lane runner**:`
   placement: replace the paragraph line that follows this heading (the only line starting `(units vlg-1..3, 2026-10-14)`) with the text below
   indent: 3
   before:
   ~~~~
   (units vlg-1..3, 2026-10-14) — `tests/validate-lanes.sh [--lanes N]` (default 3, max 8), an opt-in parallel runner for `tests/validate.sh`. It splits the suite's sections across N **lane copies** and merges the results. Serial `tests/validate.sh` remains the merge gate; the lane runner is a speed aid (3 lanes, 116 sections: about 162 s against about 476 s serial). Regression-tested by `tests/validate-lanes.test.sh` (validate.sh section 116). On EXIT, TERM or INT the runner sends TERM to each lane's whole process group, waits, then removes its work dir (vln-1); a process that leaves its group or ignores TERM is not reached, and the wait has no KILL escalation. See **lane copy**.
   ~~~~
   text:
   ~~~~
   (units vlg-1..3, 2026-10-14; the default run since vsp-1) — `tests/validate-lanes.sh [--lanes N]` (default 3, max 8), the parallel runner for `tests/validate.sh`. It splits the suite's sections across N **lane copies** and merges the results (3 lanes, 116 sections: about 162 s against about 476 s serial, measured at vlg-3). Since vsp-1, `bash tests/validate.sh` runs through the lane runner by default, with `--lanes` set to `nproc` capped at 6 (or `ANTISLOP_VALIDATE_LANES`), so the lane run is the merge gate of constitution P5; `bash tests/validate.sh --serial` or `ANTISLOP_VALIDATE_SERIAL=1` runs the suite serially in one process, and the exit code is the inner run's either way. Regression-tested by `tests/validate-lanes.test.sh`. On EXIT, TERM or INT the runner sends TERM to each lane's whole process group, waits, then removes its work dir (vln-1); a process that leaves its group or ignores TERM is not reached, and the wait has no KILL escalation. See **lane copy**. Not the **lane** of `CONTEXT.md` (the pipeline a unit is routed through).
   ~~~~

## Doc edits
1. file: `.claude/wiki/modules/hooks.md`
   heading: `**Why this is safe to leave sticky:**`
   placement: replace these four lines of that paragraph with the text below
   indent: 3
   before:
   ~~~~
   every turn while a background reviewer ran) is relaxed. The orchestrator's
   convention as of this pass: write `defer: reviewer dispatched (agent <id>),
   awaiting verdict` once, at the moment it dispatches the reviewer in the
   background — not on every subsequent turn.
   ~~~~
   text:
   ~~~~
   every turn while a background reviewer ran) is relaxed. That pass's
   orchestrator convention, a `defer: reviewer dispatched (agent <id>), awaiting
   verdict` write at dispatch time, is retired: since aof-u2 (0.31.184) the stop
   gate itself lets `Stop` through while a reviewer dispatched with a `Unit:`
   line is in flight, for up to 1800 s per review-join stamp, and logs
   `stop-allowed=review-in-flight units=<ids>`; no flag write is needed (see
   **review in flight** in `docs/harness-glossary.md`).
   ~~~~
2. file: `.claude/wiki/persona-handoff-mechanisms.md`
   heading: `## 3. Terminal status line (every dispatched turn)`
   placement: replace the line below (line 93 at c02b286a) with the text below
   indent: 3
   before:
   ~~~~
   This line is that signature. Its absence is the only available evidence of a cutoff.
   ~~~~
   text:
   ~~~~
   This line is that signature. Its absence is the only available evidence of a cutoff. The rule itself, in its short form, is `templates/persona-protocol.md`, "Terminal status line"; this section keeps the reasoning that qw-u3 (0.31.191) cut from the protocol.
   ~~~~
3. file: `.claude/wiki/persona-handoff-mechanisms.md`
   heading: `## 3. Terminal status line (every dispatched turn)`
   placement: replace the line below (line 99 at c02b286a) with the text below; the fenced `STATUS: incomplete` example that follows it stays
   indent: 3
   before:
   ~~~~
   **Not a substitute for the WIP sentinel:** The two are different mechanisms and co-occur. The sentinel is a **file** written before a voluntary pause; the status line is a **report line** emitted at every turn-end. A turn ended via the WIP sentinel is therefore:
   ~~~~
   text:
   ~~~~
   **It co-occurs with the WIP sentinel** (the protocol's short form): the two are different mechanisms. The sentinel is a **file** (`.claude/wip-handoff.<agent-id>`) written before a voluntary pause; the status line is a **report line** emitted at every turn-end. A turn ended via the WIP sentinel therefore ends with:
   ~~~~
prune: none

## ADR
none

## Close conditions
- issue #634
- task-id: rp-u6 (the plan's last lead unit; this run, rp-s1-scribe, follows its PASS)
- marker first line: "PASS rp-u6 "
- verdict line: <PASS-VERDICT-LINE>
- Commit the glossary and doc edits first, in one commit with the subject `docs(rp-s1): glossary entries for the review-patches terms; lane runner, hooks wiki and status-line wiki corrected (#634)`, staging only the four edited files by path; then close #634 with a comment that quotes the verdict line. Commit your own memory notes separately (`docs(agent-memory): ...`), never in this commit. If the plan stopped before rp-u6 passed, the orchestrator's dispatch says so and quotes the last PASS line instead; apply the same edits.

## Do NOT touch
- `agents/`, `templates/`, `adapters/`
- `hooks/`, `bin/`, `tests/`
- `README.md`, `docs/adr/` (no entry here needs them)

## Acceptance criteria
1. run: `grep -cE '^\*\*(unit scope|standing exception|bump files|Proposed out-of-scope changes|knowledge proposal|knowledgeWrites|lane)\*\*:$' CONTEXT.md`
   exit: 0
   stdout: `7`
   mutation: skip glossary edit 7; stdout `6`.
2. run: `grep -cE '^\*\*(reviewer dispatch header|review in flight|blast-radius script|provenance|unit-size script)\*\*:$' docs/harness-glossary.md`
   exit: 0
   stdout: `5`
   mutation: skip glossary edit 11; stdout `4`.
3. run: `bash -c 'grep -cE "^\*\*(unit scope|standing exception|bump files|Proposed out-of-scope changes|knowledge proposal|knowledgeWrites|lane)\*\*:" docs/harness-glossary.md; grep -cE "^\*\*(reviewer dispatch header|review in flight|blast-radius script|provenance|unit-size script)\*\*:" CONTEXT.md; true'`
   exit: 0
   stdout: `0` then `0` (each term lives in one glossary)
   mutation: also add a `**lane**:` entry to docs/harness-glossary.md; the first count is `1`.
4. run: `bash -c 'f=docs/harness-glossary.md; for n in "runs through the lane runner by default" "or ANTISLOP_VALIDATE_SERIAL=1 runs the suite serially in one process" "an opt-in parallel runner" "remains the merge gate; the lane runner is a speed aid"; do tr -s " \n" " " < "$f" | tr -d "\140" | grep -c "$n"; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 0 0 `
   mutation: skip glossary edit 13; stdout `0 0 1 1 `.
5. run: `bash -c 'tr -s " \n" " " < CONTEXT.md | grep -c "Not the lanes of the \*\*lane runner\*\*"; tr -s " \n" " " < docs/harness-glossary.md | tr -d "\140" | grep -c "provenance=grep (git grep ran for every changed file)"; tr -s " \n" " " < docs/harness-glossary.md | grep -c "the \*\*verifiedBy\*\* / \*\*functionsAuthoredBy\*\* block"'`
   exit: 0
   stdout: `1` then `1` then `1`
   mutation: drop the "(2) The reviewer's provenance stamp ..." sentence from glossary edit 11; the third count is `0` and the command exits 1.
6. run: `bash -c 'w=.claude/wiki/modules/hooks.md; grep -c "convention as of this pass" "$w"; tr -s " \n" " " < "$w" | tr -d "\140" | grep -c "logs stop-allowed=review-in-flight units=<ids>; no flag write is needed"; true'`
   exit: 0
   stdout: `0` then `1`
   mutation: skip doc edit 1; stdout `1` then `0`.
7. run: `bash -c 'w=.claude/wiki/persona-handoff-mechanisms.md; grep -c "Not a substitute for the WIP sentinel" "$w"; tr -s " \n" " " < "$w" | tr -d "\140" | grep -c "The rule itself, in its short form, is templates/persona-protocol.md, \"Terminal status line\""; true'`
   exit: 0
   stdout: `0` then `1`
   mutation: skip doc edits 2 and 3; stdout `1` then `0`.
8. run: `bash -c 'node tests/context-glossary-links.test.js >/dev/null 2>&1; a=$?; node tests/ubiquitous-language.test.js >/dev/null 2>&1; b=$?; bash tests/glossary-index.test.sh >/dev/null 2>&1; echo "$a $b $?"'`
   exit: 0
   stdout: `0 0 0`
   mutation: add the link `[[no such term]]` to glossary edit 1's text; the first status is non-zero.
9. run: `bash -c 'l=$(git log --format=%H --grep="(rp-s1)" | head -1); test -n "$l" || exit 3; git diff --name-only "$l~1..$l" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude/wiki/modules/hooks.md .claude/wiki/persona-handoff-mechanisms.md CONTEXT.md docs/harness-glossary.md `
   mutation: also stage `README.md`; the list gains that path.
10. run: `gh issue view 634 --repo Storreslara/AntiSlop --json state -q .state`
   exit: 0
   stdout: `CLOSED`
   mutation: skip closing the issue; stdout `OPEN`.
11. run: `git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave a glossary edit unstaged; stdout is non-zero.

## Escalation
If a `heading:` or `before:` text is not found exactly once (another scribe run may have edited the entry), STOP and report the current text. If any item cannot be applied exactly, STOP and report a spec gap.
