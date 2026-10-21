# AntiSlop review patches (spec)

Date: 2026-10-20. Author: spec-master. Status: finalized for rp-u1 to rp-u3 (contracted); rp-u4, rp-u5,
rp-u6 and the scribe contract rp-s1 are specified here and contracted in the next spawn (checkpoint rule:
at most 3 contract files per spawn). Source: the non-blocking notes and blockers reviewers raised during
the antislop-overhead-fixes (aof-*), validate-speed and quick-win (qw-*) units, relayed by the operator on
2026-10-20 as findings A to I. Operator goal: "finish the spec and implement any blockers or patches found
during review". Contracts: `docs/plans/antislop-review-patches/contracts/rp-uN.md`.

## Goal

Every finding A to I is either fixed by a unit with runnable criteria, or recorded here as wrong, already
fixed, or accepted, with the evidence. Ranked by risk, safety and correctness first:

- G1 (finding A, safety): a unit can no longer edit, unlisted, a script or test its own acceptance
  criteria run, and a contract's `## Do NOT touch` list beats every standing exception. Step 1 (rp-u1).
- G2 (findings B and H, gate correctness): a review-join stamp with a non-ISO or future timestamp never
  counts as a review in flight, and a reviewer's verdict written after a `marker=MISSING` block still
  consumes its stamp and clears its flag. Step 2 (rp-u2).
- G3 (findings C and D, bookkeeping and stale prose): `unit-bookkeeping.sh dispatch` fails safe on a
  non-zero ladder exit, its usage names `--implementer-tier`, the header's `Range:` is two full SHAs; four
  stale or unpinned prose spots are repointed, ported and pinned. Step 3 (rp-u3).
- G4 (finding E): `--knowledge-writes` is never silently ignored. Step 4 (rp-u4).
- G5 (finding F): passed units' issues are closed even when a later unit of the plan stops at ladder
  exhaustion, and the scribe skip rule accounts for `knowledgeWrites: apply`. Step 5 (rp-u5).
- G6 (finding I): a contract's file anchors and `before:` payloads are checked mechanically before
  dispatch. Step 6 (rp-u6), pending Open Question 3.
- G7 (finding G): the new terms get glossary entries and three stale wiki/glossary passages are fixed, in
  one scribe run after the last unit. Step 7 (rp-s1).

## Context

### Verification of each finding against the tree at cfb7ddac (0.31.192)

- **A: confirmed.** `agents/lead-programmer.md:68-75` and `agents/reviewer.md:33-39` (and the four codex
  and cursor ports, byte-identical wrapping) exempt "a path that one of the unit's acceptance-criteria
  commands names literally". A criterion `bash tests/validate.sh` therefore makes `tests/validate.sh`
  editable unlisted. Neither rule mentions `## Do NOT touch`. The fix-round exception the operator asked to
  add already exists in both rules ("in a fix round / after a FAIL, a path named in a defect of the unit's
  `.fail` record or listed under its fix contract's `## Affected files`"); no new exception is needed.
  `tests/cli-backfill.test.js` in aof-u1's commit 68235153 (a fixture line updated for the new
  `buildBinHelperSpecs()`) was neither listed in aof-u1's contract nor named by any of its criteria: it is
  out of scope under today's rule and under the new one. That is the intended outcome; the remedy is for
  the contract to list it. The new rule says so explicitly ("an existing test your change breaks" goes to
  `Proposed out-of-scope changes:`, and the lead-programmer stops as blocked if the suite cannot pass
  without it).
  The same rule says "version-stamp files", which clashes with `CONTEXT.md`'s **Version-stamped file** (an
  ADAPT-copied file with a stamp comment). The repo already says "bump files" for the three files
  (`agents/task-master.md` "Shared file, defined"; `docs/harness-glossary.md` **shared file**), so rp-u1 uses
  "bump files" in all six copies.
  Mechanical copies of the old rule are queued: st-u1's `hooks/scripts/lib/unit-scope.sh` `us_classify`
  returns class `criteria` for any whole path token in a `run:` line (st-u1 contract, edit 4), and st-u2's
  precheck and st-u3's scope gate consume it. They have not been dispatched. See Open Question 1.
- **B: confirmed.** `hooks/scripts/lib/stop-gate-core.sh` `review_inflight_units` (lines 341-385): `ts` is
  the first field, passed to `date -u -d` with no format check, and only `now - epoch <= 1800` is tested, so
  `now` (GNU date accepts it) and `2099-01-01T00:00:00Z` (negative age) count as in flight. Stamps are
  written only by `reviewer-route-gate-core.sh` as `%Y-%m-%dT%H:%M:%SZ`. `tests/stop-gate-review-inflight.test.sh`
  has no case for a future stamp, a non-ISO stamp, `.blocked`/`.escalated`, the `date -j` fallback, the block
  message's last sentence, or the duplicate-audit-line check. The three copies
  (`adapters/codex|cursor/hooks/scripts/lib/stop-gate-core.sh`, `.claude/hooks/scripts/lib/stop-gate-core.sh`)
  are byte-identical today and are in `.claude/persona-config.json` `fileHashes`: `node bin/cli.js --update`
  regenerates them (header: "generated copies"). aof-u2's AC2.6 reads `HEAD`, so it fails on any later
  commit: note only, no unit (a historical contract is not re-run).
- **H: premise wrong, real defect found.** No code path lets a non-reviewer identity clear a flag:
  flags are cleared only inside `if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name
  "$agent_type")" = "reviewer" ]` (`stop-gate-core.sh:397`) and by a `skip:` flag (`:603-607`); an explorer
  stop only logs `grant-denied hook=stop-gate identity=explorer` (`:559-566`). The audit tail shows two
  separate lines in the same second, `2026-10-21T01:00:02Z grant-denied hook=stop-gate identity=explorer`
  and `2026-10-21T01:00:02Z cleared-by=reviewer marker=MISSING unit=aof-u4`, the second being the reviewer's
  own stop, blocked (exit 2) because no aof-u4 verdict was written yet (the reviewer had a background
  explorer outstanding). After that block no `join-consumed=aof-u4` or `cleared-by=reviewer cleared=` line
  follows; the next line is the operator's `skip:` at 01:01:31. Cause: `hooks/scripts/stop-gate.sh:141-142`
  exits 0 on `stop_hook_active: true` before anything else, and Claude Code sets that field on the stop that
  follows a Stop-hook block. So the reviewer's second stop, the one that carried the PASS, never reached
  the consume-and-clear code: the stamp stayed (satisfied, so not in flight) and the flag stood. The log
  line `cleared-by=reviewer marker=MISSING` clears nothing, which is why it read as a premature clear.
  Fix (rp-u2): on `stop_hook_active: true`, a SubagentStop whose identity passes the reviewer grant still
  runs the reviewer branch with `loop_guard_active=true`; in that mode the branch never blocks (the missing
  verdict logs `loop-guard=allow marker=MISSING unit=<id>` and allows, as today), so the loop guard's
  purpose is kept. Every other stop with `stop_hook_active: true` allows at once, as today. The codex and
  cursor entry scripts do not set the variable, so they are unchanged (residual: Cursor's `loop_count >= 5`
  allow has the same shape after five blocks; recorded, not fixed).
- **C: confirmed.** `bin/unit-bookkeeping.sh:44` `line="$(bash "$ladder" ... | head -n1)"` discards the
  ladder's exit status; `review` (line 78-80) already forces `opus` on non-zero. `ladder-tier.sh` always exits
  0 (its header, line 2, and lines 141-149), so a non-zero exit means the helper broke. Decision: non-zero
  exit forces `opus`, except that `EXHAUSTED` stays `EXHAUSTED`, because the exhaustion stop routes to the
  human and must never become a dispatch. Usage (line 12) omits `[--implementer-tier <t>]`. `Range:` (line
  61) prints `$base` as given.
- **D: confirmed, four parts.** (1) `agents/reviewer.md:320` points to `agents/orchestrator.md`'s "Dispatch
  naming" section for the auto-suffix residual, which qw-u2 moved to `docs/orchestrator-rationale.md` "N1:
  reviewer dispatch naming, the unobserved residual"; the ports carry no such sentence. (2) The roster
  narrative O4 lives in `commands/start-feature-team.md` (pinned); the only orchestrator sentence pointing
  there is `agents/orchestrator.md:641` "If the `start-feature-team` command is running, its rules govern
  instead of the routing/review-ownership rules above", which nothing pins. (3) `tests/prompt-diet-pins.test.sh`
  pins the absence of four qw-u3 narratives; three more removed by qw-u3 (bc8594ad) are unpinned: "not an
  exemption", "Not an alternative to the WIP sentinel", "a complementary safety layer". (4) The codex and
  cursor orchestrator ports (`orchestrator.toml:96-98`, `orchestrator.md:90-92`) still say "When you dispatch
  scribe for a unit, quote the reviewer's PASS verdict line verbatim in that dispatch; scribe closes an issue
  only on that quoted line", while `agents/orchestrator.md:320-322` reads "When you dispatch scribe, quote each
  unit's reviewer PASS verdict line verbatim in that dispatch; scribe closes an issue only on its own quoted
  line."
- **E: to be re-verified by the next spawn before contracting.** `bin/cli.js:1177-1210` reads only the
  `--knowledge-writes=` form and only in `--update`. Decisions in Step 4 and Open Question 4.
- **F: confirmed.** `agents/orchestrator.md` "Scribe dispatch convention" (lines 40-61) dispatches the scribe
  once "after the last unit of a plan ... reaches PASS"; a plan that stops at ladder exhaustion never reaches
  that point, so issues of units that did pass stay open. The skip rule ("no unit has a tracker issue to
  close and no unit's digest reports a changed API or new convention whose knowledge file is in unit scope")
  does not mention `knowledgeWrites`.
- **G: confirmed with one correction.** The **lane runner** entry lives in `docs/harness-glossary.md:3359-3360`,
  not `CONTEXT.md`. `.claude/wiki/modules/hooks.md:71` still prescribes `defer: reviewer dispatched (agent
  <id>)`; `.claude/wiki/persona-handoff-mechanisms.md:93` and `:99` hold the long-form status-line narrative
  qw-u3 cut from the protocol. None of the seven terms has an entry in either glossary. They are harness
  terms, so they go to `docs/harness-glossary.md` (the ubiquitous-language skill: harness mechanics live
  there, not in `CONTEXT.md`).
- **qw-u4 review addendum (coordinator, 2026-10-20): confirmed, folded into rp-u3.** (1) Unpinned safety
  phrases, verified present once each: orchestrator stub "ask through one `AskUserQuestion` call" and "If
  that section cannot be read, print the whole marker verbatim, write nothing, and tell the human to resolve
  the escalation from their terminal or the Microworld dashboard."; protocol subsection "never retry or
  rephrase the write", "Write only from this session's answer", "never pick one for them", "Do not relay the
  decision in the prompt" (the orchestrator's lowercase form is already pinned). rp-u3 adds `has` rows that
  read the current files, so the verbatim-move guarantee no longer depends on git history. (2) The stub's
  fallback names the terminal route whose template lives only in the section it assumes unreadable:
  recorded as accepted (inlining a DECISION template into the orchestrator body puts the packet path and
  `DECISION` in persona prose that trips `human-decision-gate.sh` whenever quoted in Bash); Open Question 5.
  (3) qw-u4 criterion 4's mutation is inert unless the version changed (`--update` reports "already
  current"): contract-hygiene note, added to the finding-I rule below. (4) The protocol template grew 9,086
  bytes in a section no persona inlines: note only.
- **I: confirmed, recorded.** Hand-typed anchors failed twice (aof-u2 AC2.2/AC2.3, amended in e24b17b1; qw-u1
  step 6). No mechanical check exists: `contract-guard.js` and `contract-score.js` score shape, not whether
  an anchor exists in the target file. spec-master used a scratch applier for rp-u1 to rp-u3 (Pre-resolved
  context of each contract). Rule for task-master and spec-master, effective now: every `before:` and
  `anchor: line matching` literal in a contract is checked against the current file (exactly one match)
  and against every queued contract's `before:` payloads (no queued unit rewrites it) before the contract
  is committed. A mutation that relies on `node bin/cli.js --update` re-rendering is valid only in a unit
  that bumps the version (otherwise `--update` reports "already current"). A range criterion names the
  unit's own last commit (`l=$(git log --format=%H --grep="(<unit>)" | head -1)`), never `HEAD`, so it
  still holds after later units land (aof-u2 AC2.6 is the counter-example).

### Queued units and anchor collisions (checked 2026-10-20)

Queued, not yet dispatched: qw-u5, qw-u6 (`docs/plans/antislop-quick-wins/contracts/`), st-u1 to st-u4
(`docs/plans/antislop-structural/contracts/`). Their affected files: `agents/reviewer.md` (qw-u5 edits 6-7
at "Scope the review via the explorer" and line 91; st-u2 edit 6 at "Scope the review with the blast-radius
script"), `agents/orchestrator.md` (qw-u6 frontmatter; st-u4 edits 6-8 at "Planning a non-trivial change",
"## Delegation contract", "For a lead-programmer dispatch that carries no dispatch contract"),
`templates/persona-protocol.md`, `bin/cli.js`, `tests/validate.sh` (each adds a section anchored on the
previous unit's echo line), `tests/bin-helpers-scaffold.test.sh`, `hooks/scripts/reviewer-tier.sh`,
`tests/reviewer-tier.test.sh`, `hooks/hooks.json`, `docs/trust-model.md`, new files. None edits
`agents/lead-programmer.md`, any `adapters/` file, `hooks/scripts/stop-gate.sh`,
`hooks/scripts/lib/stop-gate-core.sh`, `bin/unit-bookkeeping.sh`, `tests/unit-scope-prose.test.sh`,
`tests/stop-gate-review-inflight.test.sh`, `tests/review-join.test.sh`, `tests/unit-bookkeeping.test.sh` or
`tests/prompt-diet-pins.test.sh`. rp-u1 to rp-u3 add no `tests/validate.sh` section (they extend tests
validate.sh already runs), so they do not join the validate.sh anchor chain. A scratch check confirmed
that no line of any rp-u1 to rp-u3 `before:` payload occurs in a queued contract's `before:` payload, and
that no queued anchor line falls inside an rp `before:` payload. The shared bump files are edited by a
relative `perl` bump and a `## [Unreleased]` insert, which never collide.

### Prior FAIL history (`.claude/reviewed/`, best-effort, gitignored)

aof-u2 (stop-gate in-flight) FAILed on hand-typed AC anchors, not on code; aof-u3 PASSed with a design
finding that became aof-u3b; qw-u1 FAILed once on three bookkeeping defects (fixed in qw-u1-fix1) and
once on a contract anchor. rp-u2 and rp-u3 touch the same files: their contracts carry literal payloads
proven on a scratch clone, and the reviewer-tier ratchet must not tag rp-u2 below sonnet (it edits a
sensitive hook path).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-20 Functional scope & success criteria: Q Finding H asks to restrict flag clearing to the
  reviewer identity; is that the fix? → A (self-resolved): no, the code already restricts it (`stop-gate-core.sh:397`);
  the observed stuck flag comes from the `stop_hook_active` short-circuit, so rp-u2 fixes that and pins the
  identity restriction with a regression case.
- 2026-10-20 Functional scope & success criteria: Q Does rule A need a new fix-round exception? → A
  (self-resolved): no, both rules already carry it; rp-u1 adds only the executed-path carve-out, the
  `## Do NOT touch` precedence and the broken-existing-test route.
- 2026-10-20 User interaction flow: Q How should `--knowledge-writes apply` (space form) and the flag in
  fresh-install mode behave? → A: open, Open Question 4 (recommended defaults recorded there).
- 2026-10-20 External dependencies & integrations: Q st-u1 to st-u3 mechanize the old criteria
  exception; amend them or patch after? → A: open, Open Question 1.
- 2026-10-20 Edge cases / failure handling: Q On a non-zero ladder exit that printed `EXHAUSTED`, does
  `dispatch` force opus? → A (self-resolved): no; `EXHAUSTED` stays, every other tier becomes `opus`.
- 2026-10-20 Edge cases / failure handling: Q Can the loop guard still prevent an endless reviewer block
  loop after rp-u2? → A (self-resolved): yes; a loop-guarded reviewer stop never blocks (missing verdict
  allows and logs), the marker-commit-check `block` mode is skipped too.
- 2026-10-20 Edge cases / failure handling: Q What does a lead-programmer do when an existing, unlisted
  test breaks because of the intended change? → A (self-resolved): it proposes the test under
  `Proposed out-of-scope changes:` and, if the suite cannot pass without it, stops as blocked naming it; the
  orchestrator amends the contract.
- 2026-10-20 Technical constraints & tradeoffs: Q Where do rp-u1 to rp-u3 go in the dispatch order? → A
  (self-resolved): anywhere after the unit currently in flight (no shared anchors); rp-u1 before st-u1.
  See "Dispatch section".
- 2026-10-20 External dependencies & integrations: Q (Open Question 1) amend st-u1 to st-u3? → A: yes,
  per operator via coordinator; done in this spawn (st-u1 `excluded` class and executed-path carve-out,
  st-u2/st-u3 wiring, structural spec amendment paragraph), all three still 7/7.
- 2026-10-20 Functional scope & success criteria: Q (Open Question 2) scribe for passed units before an
  early stop? → A: yes, per operator (rp-u5).
- 2026-10-20 Functional scope & success criteria: Q (Open Question 3) build `bin/contract-anchors.js`? → A:
  yes, not installed to `.claude/bin` (rp-u6).
- 2026-10-20 User interaction flow: Q (Open Question 4) `--knowledge-writes` forms? → A: as recommended:
  the space form exits 2 with a usage line, fresh install honours the flag, the exit code stays the
  render's (rp-u4).
- 2026-10-20 Edge cases / failure handling: Q (Open Question 5) inline the terminal DECISION template in the
  orchestrator stub? → A: no, accepted as is.
- 2026-10-20 Terminology consistency: Q "version-stamp files" in the scope rules vs `CONTEXT.md`
  **Version-stamped file**? → A (self-resolved): rename to "bump files" (existing usage) in rp-u1.

## Risks / dependencies

- rp-u1 changes a rule the reviewer applies to every later unit. A queued contract whose criteria execute
  an unlisted script would now FAIL on scope; checked: every script the queued contracts' criteria run is
  in their own `## Affected files` or untouched by them.
- rp-u2 edits a sensitive gate. The loop-guard change can only add consume-and-clear work to a reviewer
  stop that today allows unconditionally; it never adds a block. A regression case pins that a
  loop-guarded stop with no verdict exits 0.
- st-u1 to st-u3 without amendment would ship a scope classifier more permissive than the prose (Open
  Question 1). The reviewer prose still FAILs the unit, so the gap is a weaker backstop, not a hole.
- Cursor's `loop_count >= 5` early allow has the same shape as H; not fixed (no observed incident, no
  port test fixture for loop counts).
- `.claude/reviewed/` is untracked per-clone state; the prior-FAIL screen above is best-effort.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied (every finding re-verified against cfb7ddac; H's premise rejected on evidence)
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied (generated mirrors only through `node bin/cli.js --update`; Step 6 proposes a script for finding I)
- P3 "Version-stamp discipline": satisfied (every unit bumps the patch version and adds a CHANGELOG entry in the same commit; criterion runs `version-stamp-check.sh`)
- P5 "`tests/validate.sh` is the merge gate": satisfied (every lead contract ends with a validate.sh exit-code criterion)

## Steps

### Step 1 (rp-u1): unit scope never exempts a criterion-executed path; `## Do NOT touch` wins
Affected files: `agents/lead-programmer.md`, `agents/reviewer.md`, `adapters/codex/agents/lead-programmer.toml`,
`adapters/cursor/agents/lead-programmer.md`, `adapters/codex/agents/reviewer.toml`,
`adapters/cursor/agents/reviewer.md`, `tests/unit-scope-prose.test.sh`, bump files, generated mirrors.
Acceptance criteria: `docs/plans/antislop-review-patches/contracts/rp-u1.md` (unit-scope-prose exit 0, six
copies carry the carve-out, ports equal the source byte for byte over the rule, changed-file list exact,
version-stamp-check ok, validate.sh exit 0).

### Step 2 (rp-u2): review-in-flight timestamps are strict; a loop-guarded reviewer stop still consumes
Affected files: `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/stop-gate.sh`,
`tests/stop-gate-review-inflight.test.sh`, `tests/review-join.test.sh`, bump files, generated copies
(`.claude/hooks/scripts/`, `adapters/codex|cursor/hooks/scripts/lib/stop-gate-core.sh`).
Acceptance criteria: `docs/plans/antislop-review-patches/contracts/rp-u2.md`.

### Step 3 (rp-u3): bookkeeping fail-safe and stale prose
Affected files: `bin/unit-bookkeeping.sh`, `tests/unit-bookkeeping.test.sh`, `agents/reviewer.md`,
`adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md`,
`tests/prompt-diet-pins.test.sh`, bump files, generated mirrors. Includes the qw-u4 addendum pins.
Acceptance criteria: `docs/plans/antislop-review-patches/contracts/rp-u3.md`.

### Step 4 (rp-u4): `--knowledge-writes` is never silently ignored (contract next spawn)
Behaviour (recommended defaults, Open Question 4): the space form `--knowledge-writes <v>` exits 2 with
`--knowledge-writes takes the form --knowledge-writes=<scoped|apply>`; in fresh-install mode the flag is
honoured (the key is written to the new `persona-config.json`); `--update --knowledge-writes=<v>` prints the
`Note:` line before rendering, so a render failure unrelated to the flag (no graph launch command) still
shows that the value was saved, and the exit code stays the render's; `=scoped` on a project with no key
writes the key explicitly, now pinned. Affected files (to be confirmed against the tree at contract time):
`bin/cli.js` (argument parsing near `const kwFlag = args.find`), `tests/knowledge-writes.test.sh`, bump
files. Criteria: knowledge-writes test exit 0 with one case per form, version-stamp-check, validate.sh.
Order: after st-u4 if its anchors fall in a region qw-u5, qw-u6, st-u1, st-u2 or st-u4 edit in `bin/cli.js`;
otherwise anywhere.

### Step 5 (rp-u5): scribe on an early stop; skip rule under `knowledgeWrites: apply` (contract next spawn)
Rule text (recommended, Open Question 2), added to `agents/orchestrator.md` "Scribe dispatch convention" and
its codex and cursor ports: "If the plan stops before its last unit passes (ladder exhaustion, a human stop,
an abandoned unit), dispatch the scribe once for the units that already reached PASS before you surface the
stop." Skip rule gains: "Under `knowledgeWrites: apply` the knowledge files are always in scope, so only
the first condition (no tracker issue to close) can skip the dispatch." Pin rows in
`tests/prompt-diet-pins.test.sh` below the rp-u3 rows. Order: after st-u4 (both edit `agents/orchestrator.md`;
the overlap check must be re-run against st-u4's payloads) and after rp-u3 (same pins file).

### Step 6 (rp-u6): contract anchor check script (contract next spawn, Open Question 3)
`bin/contract-anchors.js <contract> [--against <dir>]...`: for each ordered edit with `file:`, prints one
line `anchor ok|missing|ambiguous <n> <file>` (exactly one occurrence of the `before:` payload, or of the
`anchor: line matching` literal, in the current file), and with `--against`, `collides <n> <contract>`
when a queued contract's `before:` payload shares a non-blank line with it. Exit 0 when every line is `ok`.
Not installed to `.claude/bin/` (no `bin/cli.js` change), so it joins no queued anchor chain. Test
`tests/contract-anchors.test.sh` plus a `tests/validate.sh` section anchored after st-u4's section.
task-master and spec-master prose gains one sentence naming it. Order: after st-u4.

### Step 7 (rp-s1): glossary and wiki run (scribe contract next spawn, after the last rp unit)
`docs/harness-glossary.md` entries: **reviewer dispatch header**, **unit scope**, **standing exception**,
**bump files** (with a "Not the **Version-stamped file**" line), **Proposed out-of-scope changes:**,
**knowledge proposal**, **knowledgeWrites** (`scoped` / `apply`), **review in flight**. Corrections: the
**lane runner** entry (`docs/harness-glossary.md:3360`) drops "opt-in" and names the lane run as the merge
gate if the validate-speed plan made it so (the scribe verifies against `tests/validate-lanes.sh` and the
constitution P5 text before editing); `.claude/wiki/modules/hooks.md:71` describes the review-in-flight
allow instead of `defer: reviewer dispatched`; `.claude/wiki/persona-handoff-mechanisms.md:93,99` reduced to
the protocol's short form with a pointer. Under this repo's `knowledgeWrites: apply`. The scribe contract
needs a tracker issue for rubric row S3; the next spawn files one (`gh issue create`, label
`plan/antislop-review-patches`).

## Dispatch section

Fast path (5 lead units plus one scribe contract; Step 6 optional). Contract files, committed before
dispatch:
- rp-u1: `docs/plans/antislop-review-patches/contracts/rp-u1.md`
- rp-u2: `docs/plans/antislop-review-patches/contracts/rp-u2.md`
- rp-u3: `docs/plans/antislop-review-patches/contracts/rp-u3.md`
- rp-u4, rp-u5, rp-u6, rp-s1: next spawn.

Dispatch order against the queued units (qw-u5 landed as 82844f70 while this spec was written; all three
contracts were re-proven in sequence on a clone of 8b931f0f): rp-u1, rp-u2, rp-u3 right after the unit currently in flight
(they share no anchor with qw-u5, qw-u6 or st-u1 to st-u4), rp-u1 strictly before st-u1. Then the queued
qw-u5, qw-u6, st-u1 (amended per Open Question 1), st-u2, st-u3, st-u4. Then rp-u4, rp-u5, rp-u6 in that
order, then rp-s1 last. Every unit bumps the version relative to the version it starts at.

## Open Questions

All five were ruled on 2026-10-20 (Clarifications); kept below for the record.

1. st-u1 to st-u3 encode the old criteria exception (`us_classify` class `criteria` for any path token in a
   `run:` line). Recommended default: before st-u1 is dispatched, a spec-master pass on
   `docs/plans/antislop-structural/` amends st-u1 so `criteria` excludes a token that is the program or the
   interpreter script of a `run:` command, and adds a first class `excluded` for a path under the
   contract's `## Do NOT touch`; st-u2 and st-u3 then report it. Alternative: leave st-u1 as is and add a
   follow-up rp unit after st-u3 that patches `hooks/scripts/lib/unit-scope.sh` and `tests/scope-libs.test.sh`.
2. Scribe on an early stop (Step 5). Recommended: adopt the rule as written in Step 5. Alternatives: (b)
   record as accepted (issues stay open until a human closes them); (c) dispatch the scribe after every
   PASS again (reverts aof's once-per-plan batching).
3. Build `bin/contract-anchors.js` (Step 6)? Recommended: yes; two contracts failed on hand-typed anchors in
   this one plan family and the check is about 80 lines. Alternative: record the rule only (Context, I).
5. qw-u4 addendum item 2: inline the one-line terminal DECISION template in the orchestrator stub?
   Recommended: no, accepted as is (Context, addendum). Alternative: a rp-u5 edit that inlines it, after
   checking `human-decision-gate.sh` lets the edit and its pins through.
4. `--knowledge-writes` forms (Step 4). Recommended: space form exits 2 with a usage line; fresh install
   honours the flag; exit code stays the render's. Alternative: accept the space form as a synonym.

## Self-check
- CHK1: Is every finding A to I either mapped to a step with a contract or recorded with evidence as wrong,
  fixed or accepted? — PASS (A Step 1; B, H Step 2; C, D Step 3; E Step 4; F Step 5; I Step 6 and Context;
  G Step 7; AC2.6 note in Context B)
- CHK2: Do Step 2 and Context H agree that no non-reviewer identity can clear a flag today? — PASS
- CHK3: Is the dispatch position of each rp unit stated against the queued units? — PASS (Dispatch section)
- CHK4: Is the behaviour of `--knowledge-writes` in fresh-install mode defined? — FAIL (missing) —
  converted to Open Question 4
- CHK5: Is the st-u1 interaction with rule A defined? — FAIL (missing) — converted to Open Question 1
- CHK6: Do rp-u1 and Step 7 agree on the term for the three bump files? — PASS ("bump files" in both)
- CHK7: Does each contracted step have a validate.sh exit-code criterion and a version-stamp-check
  criterion? — PASS (rp-u1 to rp-u3)
- CHK8: Is the scribe-on-early-stop rule decided? — FAIL (missing) — converted to Open Question 2
- CHK9: Is building the anchor script decided? — FAIL (missing) — converted to Open Question 3
- CHK10: Is each qw-u4 addendum item either pinned by rp-u3 or recorded? — PASS (items 1 rp-u3; 2 Open
  Question 5; 3 and 4 Context)
- CHK11: Do the range criteria of rp-u1 to rp-u3 survive later commits? — FAIL (conflicting, they read
  HEAD) — revised in place (they name the unit's last commit)

Ubiquitous-language check (prose mode, advisory): lens 1, "version-stamp files" in the current rules
diverges from `CONTEXT.md` **Version-stamped file**, resolved in rp-u1; lens 2, "review in flight" and
"review-in-flight" (audit token) name the same thing, the entry should name both; lens 3, the seven terms of
finding G, queued for rp-s1.

## Scribe update hint
rp-s1 (Step 7) carries the glossary and wiki work. Knowledge proposals from this spec: the entries listed
in Step 7; **review in flight** should note the audit token `stop-allowed=review-in-flight` and that
loop-guarded reviewer stops log `loop-guard=allow`.
