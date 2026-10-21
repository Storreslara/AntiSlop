# AntiSlop review patches (spec)

Date: 2026-10-20, Step 9 added 2026-10-21. Author: spec-master. Status: finalized; every unit is contracted
(rp-u1 to rp-u10 and the scribe contract rp-s1, tracker issue #634) and no Open Question remains. Source: the non-blocking notes and blockers reviewers raised during
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
  dispatch. Step 6 (rp-u6).
- G7 (finding G): the new terms get glossary entries and three stale wiki/glossary passages are fixed, in
  one scribe run after the last unit. Step 7 (rp-s1).
- G8 (qw-u5 review notes): the blast-radius script counts only `tests/`-style paths as tests, survives odd
  paths, caps its output, and its installed copy is committed executable; the protocol names `bash`. Step 8
  (rp-u7).
- G9 (st-u1 review, 2026-10-21, safety first): the reviewer tier prints `opus`, exit 0, whenever a library
  it sources is missing, unreadable, empty or cut short (rp-u8); the unit-scope classifier excludes only a
  `## Do NOT touch` bullet's whole subject, has an explicit `partial:` marker, keeps globs inside one path
  segment and classifies unsafe paths `out` (rp-u9); st-u2 to st-u4 fail closed the same way and use the
  corrected classifier (amended contracts); three review notes on qw-u6, rp-u3 and rp-u2 are fixed and
  pinned (rp-u10). Step 9.

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
  still holds after later units land (aof-u2 AC2.6 is the counter-example). Once rp-u6 lands, the check
  is `node bin/contract-anchors.js <contract> --chain=<queued contract>...` (queued contracts in dispatch
  order, landed ones left out), run before the contract is committed; until then the scratch applier does
  the same job. The prototype of that script reported `ok` for rp-u4 to rp-u7 against HEAD 4732f6c3 (rp-u1
  landed) with the chain rp-u2, rp-u3, qw-u6, st-u1 to st-u4 and the earlier rp units.

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

### st-u1 review findings (verified 2026-10-21 against 0b45bd46, 0.31.198)

st-u1 passed review; the reviewer recorded real defects, fixed here before st-u2 is dispatched.
- **S1 (safety): confirmed.** `hooks/scripts/reviewer-tier.sh:16-18` runs `set -euo pipefail` and then
  sources `lib/state-access.sh` and `lib/sensitive-paths.sh` bare. On a scratch copy with the sensitive-path
  library emptied, a range touching only `hooks/scripts/probe.sh` printed `sonnet`, exit 0 (an undefined
  `touches_sensitive_path` inside `if` is only false); with it removed or unreadable the script printed
  nothing, exit 1; cut inside the array (a syntax error), exit 2. The header promises `sonnet` or `opus`,
  exit 0. Callers (`unit-bookkeeping.sh review`) already treat anything but `sonnet` as opus. rp-u8.
- **S2: confirmed.** `us_entries <contract> "Do NOT touch"` (`unit-scope.sh:20-22`) takes every backtick path
  token of the section, and `us_excluded` (`:63-66`) matches them exactly. Run over the commits of the 15
  units shipped this session, the files changed by qw-u2 and qw-u4 classify `agents/orchestrator.md` as
  `excluded` (their bullets "`agents/orchestrator.md` ESCALATE-TO-HUMAN steps" and "... from the paragraph
  starting `If no` ..."); qw-u3's reason names `tests/protocol-doc-drift.test.js`. With rp-u9's
  `us_exclusions` none of the 15 units' changed files classifies `excluded`, and whole-file bullets still do.
  (The finding's line numbers ~58-61, ~215-217 and ~229 match no layout of the 101-line file; the
  defects are at the lines above.)
- **S3: confirmed.** `us_listed` (`:34`) matches a glob with `[[ "$p" == $e ]]`, where `*` crosses `/`
  (`docs/*.md` lists `docs/adr/0042-x.md`); `:33` lists `src/../CONTEXT.md` under `src`; a path holding a
  newline passed to `grep -qxF` or `grep -E` becomes two patterns. git prints none of these shapes unquoted
  (st-u2 already fails a C-quoted name as `scope: out ... unquotable`), so the minimal safe handling is a
  shared `us_safe_path` that makes them never listed and `out`, not a NUL-delimited rewrite. rp-u9.
- **S4 (a): confirmed.** `bin/cli.js:1115` interpolates the raw `orchestratorModel` value; `{toString: 'x'}`
  throws `Cannot convert object to primitive value` during the render. **(b): confirmed.**
  `bin/unit-bookkeeping.sh:51-57` forces opus on a non-zero ladder exit, then still runs the
  guard-demotion branch (appending `contract-guard sonnet: ...`) and writes no ruling for the force.
  **(c): confirmed.** `hooks/scripts/stop-gate.sh:34` ("never re-trigger ourselves in a loop") and
  `:144-147` ("the core never blocks such a stop") and the rp-u2 CHANGELOG entry overstate: the microworld
  surfacing block (`lib/stop-gate-core.sh:64-90`) runs before the reviewer branch and can exit 2 once.
  Two mutations survive every test today: dropping the `loop_guard_active` condition of the commit-check
  block (`:490`), and replacing the entry script's reviewer-identity condition with `if true` (the existing
  gated-agent case has no repo and no dirty tree). Under the guard, `markerCommitCheck.mode: block` is
  one-shot: the unguarded reviewer stop blocks, the guarded one that follows logs, consumes and clears.
  rp-u10.
- **Queued contracts affected.** st-u2 (`bin/review-precheck.sh`) and st-u3 (`writer-scope-gate.sh`) read
  `## Do NOT touch` with `us_entries ... "Do NOT touch"` and source the libraries without a function check;
  st-u4 (`bin/unit-size.sh`) sources them without one (an empty `unit-scope.sh` gave `-- <path>` input a small
  lane). st-u3 sourced `unit-scope.sh` after `agent-identity.sh` had turned `set -e` on, so a missing library
  exited 1 (Claude Code treats that as allow). All three are amended (Step 9).

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
- 2026-10-20 Functional scope & success criteria: Q (Open Question 6) add "a changed hook or prompt file
  with no caller lines" as an explorer trigger for the reviewer? → A: no, per operator: no new explorer
  trigger; the ruled triggers (`provenance=none`, script missing, an open question that decides a
  finding) stay as they are (rp-u7 changes no trigger).
- 2026-10-20 Technical constraints & tradeoffs: Q rp-u7 item 4 says `awk -v` for the output lines; is that
  the fix? → A (self-resolved): no, `awk -v` rewrites backslash escapes in the value, so a path holding `\`
  would still change; a `while read` loop with `printf '%s'` copies every byte. `core.quotePath=false` as
  suggested.
- 2026-10-20 Technical constraints & tradeoffs: Q does rp-u7 make `--update` restore the mode of a
  content-current helper? → A (self-resolved): no; the update loop skips a content-current file, so this
  needs a new branch there, more than one line. Residual. rp-u7's own content change makes `--update`
  rewrite the helper with the packaged mode, and `git update-index --chmod=+x` fixes the index.
- 2026-10-20 Edge cases / failure handling: Q what is rp-u7's total output cap? → A (self-resolved): 300
  lines after the header, then `truncated: <n> more lines`; the header and the per-file cap of 40 stay.
- 2026-10-20 User interaction flow: Q does task-master.md or spec-master.md name `bin/contract-anchors.js`
  (operator: only if cheap and safe)? → A (self-resolved): no; an installed project has no
  `bin/contract-anchors.js`, so a prompt line naming it costs every install tokens and invites a failed
  command. Its usage text and Context I of this spec are its documentation, and rp-u6 touches no
  `agents/*.md`.
- 2026-10-20 Technical constraints & tradeoffs: Q the anchor script's chain flag: Step 6's `--against`
  (collision report) or the operator's "created by an earlier contract in a given chain"? → A
  (self-resolved): `--chain=<contract>`, repeatable, applied in order in memory before the contract's own
  edits; a line a queued unit rewrites then reads `missing`, which subsumes the collision report. Only the
  `=` flag forms are read; a space form exits 2, the lesson of finding E.
- 2026-10-20 Terminology consistency: Q which glossary gets each rp-s1 term? → A (self-resolved): by the
  routing rule in `CONTEXT.md` **domain glossary**: the unit-scope family, **bump files**,
  **knowledgeWrites**, **knowledge proposal** and **lane** describe what a plugin user meets and go to
  `CONTEXT.md`; the scripts, the header, **review in flight** and **provenance** need the harness
  internals and go to `docs/harness-glossary.md`. Each term lives in one glossary (rp-s1 criterion 3).
- 2026-10-20 Terminology consistency: Q "lane" now names two things (st-u4's routing lanes and the
  validate lane runner); and "provenance" two (the blast-radius header field and the reviewer's
  escalation-packet stamp)? → A (self-resolved): **lane** (`CONTEXT.md`) carries a "Not the lanes of the
  **lane runner**" line and the lane runner entry a reverse line; **provenance** is one entry with two
  numbered senses and a pointer to the unrelated eval senses.
- 2026-10-20 Functional scope & success criteria: Q does rp-s1 delete the status-line reasoning from
  `.claude/wiki/persona-handoff-mechanisms.md` (Step 7 said "reduced to the protocol's short form")? → A
  (self-resolved): no; the wiki is where that reasoning lives now that qw-u3 cut it from the protocol (as
  qw-u2 moved the orchestrator narratives to docs). rp-s1 adds a pointer to the protocol's rule at line 93
  and rewords line 99's "Not a substitute for the WIP sentinel" label to the protocol's "co-occurs" form.
- 2026-10-20 External dependencies & integrations: Q rp-s1's tracker issue? → A: #634, created with
  labels `plan/antislop-review-patches` (created for it) and `ready-for-agent`; its body holds the scribe
  contract in a five-tilde fence (the payloads use four-tilde fences, which would close a three-tilde one);
  contract-guard scores the issue body 7/7.
- 2026-10-21 Functional scope & success criteria: Q Which st-u1 review findings get units, and how are they
  grouped? → A (self-resolved): all four, each verified against 0b45bd46 (Context, "st-u1 review findings"):
  rp-u8 S1 (safety, one hook), rp-u9 S2 and S3 (one library and its test), rp-u10 S4 (a) to (c) (three
  small fixes in different files, one commit); the operator asked for at most three contracts.
- 2026-10-21 Domain entities / data model: Q What exactly makes a `## Do NOT touch` bullet a whole-file
  exclusion? → A (self-resolved): its subject (text before the first ` (`, `: `, ` - ` or ` — `) is only
  backticked path tokens joined by `, `, ` and `, `, and `, ` or `, `, or `; every token excludes. Lists of
  paths are allowed, wider than "just the backticked path", because 11 of the shipped bullets list several
  whole files that way; a bullet mixing whole files and a qualifier excludes nothing (under-excluding is
  safe, over-excluding was the defect).
- 2026-10-21 Terminology consistency: Q What is the explicit partial-file marker? → A (self-resolved): the
  token `partial:` anywhere in the bullet, written `- `<path>` partial: <which part>`. A leading
  `- partial: ...` form was tried first and dropped: contract-score v2 R6 requires every Do-NOT-touch
  bullet to open with a backticked path (rp-u10 scored 6/7 with it).
- 2026-10-21 Edge cases / failure handling: Q What does a newline, `.` or `..` path classify as, and do
  callers switch to NUL-delimited input? → A (self-resolved): `out` through `us_safe_path` (never listed);
  no NUL rewrite, since git C-quotes such names and st-u2 already fails a quoted name.
- 2026-10-21 Edge cases / failure handling: Q What is fail-closed for each library consumer? → A
  (self-resolved): reviewer-tier.sh prints `opus`, exit 0 (rp-u8); review-precheck.sh exits 2 with no
  packet, so the reviewer runs the checks itself (st-u2); writer-scope-gate.sh blocks the three writers'
  stops with a report-and-wait message and allows everyone else (st-u3); unit-size.sh prints
  `lane: full ... reason=unmeasurable` (st-u4).
- 2026-10-21 Technical constraints & tradeoffs: Q Where do rp-u8 to rp-u10 go in the dispatch order? → A:
  per operator, rp-u8 and rp-u9 immediately (before st-u2), then st-u2, st-u3, st-u4, rp-u10, rp-u7,
  rp-u4, rp-u5, rp-u6, rp-s1. Checked both ways on a clone (Dispatch section); no other order is needed.
- 2026-10-21 Completion / acceptance signals: Q Do the amended and new contracts name the unit's own last
  commit in range criteria? → A (self-resolved): yes; st-u2 criteria 5 and 7, st-u3 criteria 4 and 6 and
  st-u4 criteria 5 and 7 were changed from `HEAD` to the unit's last commit.

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
- rp-u8 and rp-u10 edit sensitive hook paths (`reviewer-tier.sh`, `stop-gate.sh`); the reviewer-tier
  ratchet must not tag them below sonnet. rp-u10's stop-gate change is comments only, but its two new
  review-join pins are the only tests that catch two live mutations.
- st-u3's fail-closed branch blocks every writer stop while `unit-scope.sh` is broken (bounded by Claude
  Code's 8-continuation stop-hook loop). That is louder than an allow, and recoverable by `--update`; a
  silent allow would make the gate a no-op exactly when the install is damaged.
- Two Affected-files token lists are wider than the files edited (aof-u1 and aof-u4 name scripts in
  prose); `us_entries` still lists those names. Not fixed: over-listing only loosens scope for a name the
  contract itself wrote, and the reviewer reads the list.
- Residuals recorded, not fixed: `--update` does not restore the mode of a content-current helper (rp-u7);
  the blast-radius script still quotes a path holding `"`, a tab or a newline (git quotes those whatever
  `core.quotePath` says); st-u2's protocol sentence names `.claude/bin/review-precheck.sh` without `bash`
  (its pins live in st-u2's test, outside rp-u7's scope).

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

### Step 6 (rp-u6): contract anchor check script
`bin/contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...` applies the `--chain` contracts
(queued, in dispatch order) and then the contract's own edits in memory, and prints one `<kind> <status>
<item> <file>` line per check and `contract-anchors: <ok|fail> checks=<n> bad=<n> unchecked=<n>`: a `line
matching|ending|starting` anchor holds on exactly one line (or sits inside a payload that matched once); a
`before:`/`delete:` payload occurs exactly once as whole lines (verbatim, or after stripping `indent: N`);
`anchor: new file` needs the file absent; Affected-files anchors hold once before or after the edits.
Exit 0 / 1 / 2 (usage or read error). Not installed to `.claude/bin/`, no persona prose names it
(Clarifications). Test `tests/contract-anchors.test.sh` plus a `tests/validate.sh` section after st-u4's.
Acceptance criteria: `docs/plans/antislop-review-patches/contracts/rp-u6.md` (test exit 0, the script
passes its own contract against the pre-unit tree, usage exits 2, both new files 100755 and not installed,
changed-file list exact, version-stamp-check ok, validate.sh registration and exit 0). Order: last lead unit.

### Step 7 (rp-s1): glossary and wiki run (scribe, after the last rp unit; issue #634)
`CONTEXT.md` entries: **unit scope**, **standing exception**, **bump files** (with a "Not the
**Version-stamped file**" line), **Proposed out-of-scope changes**, **knowledge proposal**,
**knowledgeWrites** (`scoped` / `apply`), **lane** (st-u4's routing lanes, with a "Not the lanes of the
**lane runner**" line). `docs/harness-glossary.md` entries: **reviewer dispatch header**, **review in
flight** (audit token `stop-allowed=review-in-flight`, loop-guard `loop-guard=allow`), **blast-radius
script**, **provenance** (two senses: the script header's search source; the reviewer's escalation-packet
stamp, **verifiedBy**), **unit-size script**. Corrections, verified against `tests/validate.sh` (vsp-1:
lane run by default, `--serial` / `ANTISLOP_VALIDATE_SERIAL=1`) and constitution P5: the **lane runner**
entry drops "opt-in" and "Serial ... remains the merge gate"; `.claude/wiki/modules/hooks.md:70-73` retires
the `defer: reviewer dispatched` convention and describes the review-in-flight allow (1800 s);
`.claude/wiki/persona-handoff-mechanisms.md:93,99` gain a pointer to the protocol's rule and its
"co-occurs" wording (Clarifications). Under this repo's `knowledgeWrites: apply`. Contract:
`docs/plans/antislop-review-patches/contracts/rp-s1.md`, copied into issue #634's body (7/7, scribe shape).

### Step 8 (rp-u7): blast-radius script follow-ups from the qw-u5 review
Contracted: `docs/plans/antislop-review-patches/contracts/rp-u7.md`. Item (4) uses a `printf` loop, not
`awk -v`; item (2)'s `--update` part is not taken (no `bin/cli.js` change); the executable check lives in
`tests/bin-helpers-scaffold.test.sh` (fresh scaffold, `--update` restore, this repo's index); OQ6 ruled no
(Clarifications). Original scope, verified 2026-10-20:
Source: coordinator addendum, qw-u5 (82844f70, 0.31.193) PASS notes. Verified 2026-10-20: (1)
`templates/persona-protocol.md:41` says "runs `.claude/bin/blast-radius.sh <baseline>`" without `bash`,
while `agents/reviewer.md` says `bash .claude/bin/...`; add `bash`. (2) `.claude/bin/blast-radius.sh` is
committed as 100644 (`bin/blast-radius.sh` is 100755): `git update-index --chmod=+x`, plus a test that a
fresh scaffold's copy and this repo's copy are executable; `--update` restoring the mode of a
content-current helper is in scope only if the test shows it is a one-line change in the helper copy loop
(otherwise a Proposed out-of-scope change). (3) `bin/blast-radius.sh:13` `TESTRE` counts `specs?/` folders
and `_spec.<ext>` names as tests (so `docs/specs/` and `.claude/agent-memory/**/*_spec.md` match): restrict
the folder match to `tests/` and `__tests__/` and the name match to `.test.` / `.spec.` before a code
extension. (4) `bin/blast-radius.sh:26` puts `$p` into a `sed` replacement (breaks on `|` or `&`): use
`awk -v`; run git with `-c core.quotePath=false` so non-ASCII paths are not quoted. (5) Add a total output
cap with a `truncated: <n> more lines` marker (the qw-u5 range printed 1111 lines). (6) Open Question 6. (7)
glossary terms **blast-radius script** and the two senses of **provenance** go to rp-s1.
Affected files: `bin/blast-radius.sh`, `tests/blast-radius.test.sh`, `templates/persona-protocol.md`,
`.claude/bin/blast-radius.sh` (mode only, plus `--update`), `bin/cli.js` only if (2)'s `--update` part is
taken, bump files, generated mirrors. Order: after rp-u3 and after st-u2 (st-u2 edits
`templates/persona-protocol.md` near the same reuse paragraph; the anchor check must run against st-u2's
payloads) - so after st-u4 in practice, before rp-u4. Expected version then shifts rp-u4 and later by one.

### Step 9 (rp-u8 to rp-u10): st-u1 review findings, and the queued structural contracts amended
Source: st-u1's PASS notes (0b45bd46, 0.31.198) and the coordinator's findings S1 to S4, verified in Context,
"st-u1 review findings". Three contracts, safest first:
- rp-u8 (S1, safety): `hooks/scripts/reviewer-tier.sh` sources its two libraries in one guarded step and
  checks `declare -F touches_sensitive_path unit_id_sanitize state_unit_marker_exists`; any failure prints
  `opus`, exit 0. Tests for a missing, empty, cut-short and unreadable library on the source and the
  installed copy, plus a `cmp` of the installed script. Affected: `hooks/scripts/reviewer-tier.sh`,
  `tests/reviewer-tier.test.sh`, `tests/scope-libs.test.sh` (case (b)), bump files, generated copies.
  Contract: `docs/plans/antislop-review-patches/contracts/rp-u8.md`.
- rp-u9 (S2, S3): `us_exclusions` (whole-subject grammar, `partial:` marker; Clarifications 2026-10-21),
  `us_entries <f> "Do NOT touch"` delegating to it, `us_glob_re` (`*` and `?` within one segment) and
  `us_safe_path` (empty, newline, `.` or `..` segment: never listed, `out`). Regression fixtures copied
  from the Do-NOT-touch bullets of aof-u1 to aof-u4, aof-u3b, qw-u1 to qw-u6, rp-u1 to rp-u3 and st-u1.
  Affected: `hooks/scripts/lib/unit-scope.sh`, `tests/scope-libs.test.sh`, bump files, generated copy.
  Contract: `docs/plans/antislop-review-patches/contracts/rp-u9.md`.
- rp-u10 (S4 a to c): `JSON.stringify` in the `orchestratorModel` note; `helper failed rc=<n>: <tier>`
  ruling and no guard or no-contract branch on a non-zero ladder exit; stop-gate comments and the rp-u2
  CHANGELOG entry say "never blocks on the review-join or the marker-commit-check", and
  `markerCommitCheck.mode: block` is one-shot under the guard. Two review-join pins kill the two
  surviving mutations. Affected: `bin/cli.js`, `bin/unit-bookkeeping.sh`, `hooks/scripts/stop-gate.sh`,
  `CHANGELOG.md`, `tests/orchestrator-model.test.js`, `tests/unit-bookkeeping.test.sh`,
  `tests/review-join.test.sh`, bump files, generated copies. Contract:
  `docs/plans/antislop-review-patches/contracts/rp-u10.md`.
- Amended in place (`docs/plans/antislop-structural/contracts/`): st-u2 (`declare -F` guard, exit 2;
  `us_exclusions`; fixture u2.md and cases (a), (c), (k)), st-u3 (sources `unit-scope.sh` after `set +e`;
  `declare -F` guard blocks the writers; `us_exclusions`; cases (m), (n)), st-u4 (`declare -F` guard;
  library-empty case; whole-subject hooks bullet). All three now name the unit's last commit in their
  range criteria and expect versions 0.31.201 to 0.31.203.
Acceptance criteria: the three contracts and the amended st-u2 to st-u4, each 7/7 on
`node .claude/bin/contract-score.js --rubric=v2`, each ending in a validate.sh exit-code criterion.

## Dispatch section

Fast path: 10 lead units (rp-u1 to rp-u10) plus one scribe contract (rp-s1). Contract files, committed before
dispatch (all scored with `node .claude/bin/contract-score.js --rubric=v2`):
- rp-u1: `docs/plans/antislop-review-patches/contracts/rp-u1.md` (landed, 4732f6c3, 0.31.194)
- rp-u2: `docs/plans/antislop-review-patches/contracts/rp-u2.md` (7/7)
- rp-u3: `docs/plans/antislop-review-patches/contracts/rp-u3.md` (7/7)
- rp-u7: `docs/plans/antislop-review-patches/contracts/rp-u7.md` (7/7, proven on the chained clone)
- rp-u4: `docs/plans/antislop-review-patches/contracts/rp-u4.md` (7/7, re-proven after rp-u7)
- rp-u5: `docs/plans/antislop-review-patches/contracts/rp-u5.md` (7/7, re-proven after rp-u4)
- rp-u6: `docs/plans/antislop-review-patches/contracts/rp-u6.md` (7/7, proven on the chained clone)
- rp-s1: `docs/plans/antislop-review-patches/contracts/rp-s1.md` (scribe shape 7/7), copy in issue #634
- st-u1 to st-u3 amended in place for Open Question 1 (commit 2246cb45; all still 7/7).
- rp-u8: `docs/plans/antislop-review-patches/contracts/rp-u8.md` (7/7, proven on the chained clone)
- rp-u9: `docs/plans/antislop-review-patches/contracts/rp-u9.md` (7/7, proven on the chained clone)
- rp-u10: `docs/plans/antislop-review-patches/contracts/rp-u10.md` (7/7, proven on the chained clone)
- st-u2, st-u3, st-u4 amended in place for Step 9 (2026-10-21; all 7/7).

Landed so far: rp-u1 0.31.194, rp-u2 0.31.195, rp-u3 0.31.196, qw-u6 0.31.197, st-u1 0.31.198 (0b45bd46).
Remaining order and expected versions (no fix rounds; each unit bumps relative to the version it starts at),
superseding the 2026-10-20 order: rp-u8 0.31.199, rp-u9 0.31.200, st-u2 0.31.201, st-u3 0.31.202, st-u4
0.31.203, rp-u10 0.31.204, rp-u7 0.31.205, rp-u4 0.31.206, rp-u5 0.31.207, rp-u6 0.31.208, then rp-s1 (no
bump; closes #634). The rp-u4 to rp-u7 contracts state older expected versions; they bump relatively, so
the shift is harmless. One unit at a time. Why this order: rp-u8 and rp-u9 first (operator), because st-u2
and st-u3 call `us_exclusions` and all three st units rely on rp-u8's fail-closed rule; rp-u10 after st-u4
and before rp-u7 (operator), with no shared anchor either way; rp-u7 needs st-u2 landed (same protocol
paragraph), rp-u5 needs st-u4 (same orchestrator file), rp-u6 needs st-u4's validate.sh section.
Anchor check, both ways: spec-master applied rp-u8, rp-u9, the amended st-u2 to st-u4, rp-u10, rp-u7,
rp-u4, rp-u5 and rp-u6 in this order to a fresh clone of 0b45bd46 with the scratch applier (every
`before:` payload must occur exactly once; every command's exit must match), and ran each new or amended
contract's criteria 1 to n-1 right after its commit (validate.sh not run): all matched and passed, the
final version read 0.31.208. The prototype of `bin/contract-anchors.js` (rp-u6, built on that clone) then
reported `ok`, `bad=0`, for each of the ten contracts against the real tree at 0b45bd46 with its
predecessors as `--chain`. Only st-u2 and st-u4's "change both occurrences of `(a) ... helpers present`"
instructions are prose, applied by hand on the clone.

## Open Questions

None open. All six were ruled on 2026-10-20 (Clarifications); kept below for the record.

6. Add "a changed hook or prompt file with no caller lines" as an explorer trigger for the reviewer?
   Ruled no, per operator: the triggers stay `provenance=none`, script missing, and an open question that
   decides a finding.

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
- CHK12: Does every Open Question have a dated ruling in Clarifications? — PASS (1 to 6)
- CHK13: Do rp-u7's anchors agree with st-u2's chained edit of the same protocol paragraph? — PASS
  (applied after st-u2 on the clone; the prototype anchor check reports ok against HEAD plus the chain)
- CHK14: Is each rp-s1 term assigned to exactly one glossary? — PASS (Clarifications; rp-s1 criterion 3)
- CHK15: Do Step 6 and the rp-u6 contract agree on the flag name? — FAIL (conflicting: `--against` vs
  `--chain`) — revised in place (Step 6 now says `--chain`)
- CHK16: Is the dispatch position and expected version of every unit stated? — PASS (Dispatch section)
- CHK17 (2026-10-21): Is every finding S1 to S4 mapped to a contract with a criterion that fails under
  its own mutation? — PASS (S1 rp-u8 c1/c2; S2, S3 rp-u9 c1/c3; S4 a, b, c rp-u10 c1, c2, c3/c4)
- CHK18: Do Step 9, the rp-u9 contract and the amended st-u2/st-u3 fixtures agree on the partial marker? —
  FAIL (conflicting: a leading `- partial:` form broke contract-score R6) — revised in place (`partial:`
  after the path, anywhere in the bullet)
- CHK19: Does each consumer of the libraries define its fail-closed result? — PASS (Clarifications
  2026-10-21; rp-u8, st-u2 c1, st-u3 c1, st-u4 c1 mutations)
- CHK20: Do the new and amended range criteria name the unit's own last commit? — PASS
- CHK21: Is each Do-NOT-touch bullet of the six contracts whole-subject or marked `partial:`, and does
  none exclude a file its own Affected list names? — PASS (checked with the rp-u9 library on the clone)
- CHK22 (replay): Do the criteria whose `run:` names `bin/cli.js`, `hooks/scripts/reviewer-tier.sh`,
  `hooks/scripts/stop-gate.sh` or `tests/reviewer-tier.test.sh` (files of replay units gh348-4, gh360,
  gh409, gh413, item04-2-apply-drops, mw-step3, recorded vacuous/host) still fail under their own
  `mutation:` line? — PASS (rp-u8 c1, rp-u10 c1 and c3 mutations were run on the clone and flip the result)
- CHK23: Is the dispatch order checked both ways for anchor collisions? — PASS (Dispatch section, clone
  chain plus prototype `contract-anchors.js`, bad=0 for all ten)

Ubiquitous-language check (prose mode, advisory): lens 1, "version-stamp files" in the current rules
diverges from `CONTEXT.md` **Version-stamped file**, resolved in rp-u1; lens 2, "review in flight" and
"review-in-flight" (audit token) name the same thing, the entry should name both; lens 3, the seven terms of
finding G, queued for rp-s1.

## Scribe update hint
rp-s1 (Step 7, issue #634) carries the glossary and wiki work. Knowledge proposals from this spec: the entries listed
in Step 7; **review in flight** should note the audit token `stop-allowed=review-in-flight` and that
loop-guarded reviewer stops log `loop-guard=allow`.
Step 9 knowledge proposals for rp-s1 (or a later scribe run): **whole-subject exclusion** (a `## Do NOT
touch` bullet whose subject is only backticked paths) and the **`partial:` marker**, under the unit-scope
family in `CONTEXT.md`; **fail closed** for a missing or incomplete hook library (reviewer tier opus,
precheck exit 2, scope gate blocks writers, lane full) in `docs/harness-glossary.md`.
