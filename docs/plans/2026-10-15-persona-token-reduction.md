# Persona token reduction: twelve changes to the heavyweight personas

Status: **FINAL** (2026-10-15). Open Questions round 1 (four questions) was
answered by the user via AskUserQuestion on 2026-10-15, taking the
recommended option each time; the answers are in Clarifications. Item 10 is
not built (no U10), item 11 is an audit record only (U11), item 12 is in
(U12), and validate.sh is quiet by default (U1).
Baseline: `3dfdf2f`, plugin `0.31.171`. Source review: the read-only Fable
review of HEAD 0.31.171 (transcript-measured, ~4 chars/token).
Unit labels keep the Fable numbering (U1-U12); U0 is the measurement unit;
items 4 and 7 split into U4a/U4b and U7a/U7b/U7c.

## Goal

Lower per-dispatch token use (baseline context x turns) for lead-programmer,
reviewer, spec-master, task-master and scribe without removing any rule an
agent acts on and without weakening the Writer/Reviewer split, any gate, the
terminal status-line rule, the gate-blocked rule, `bashOutputMaxChars`,
`dispatchHygiene.mode`, reviewer tier floors or reviewer effort. `maxTurns`
is not used as a lever.

## Context

### Measured baseline (re-run 2026-10-15, 21-day window, 963 subagent transcripts)

Reproduced with the Fable scripts (`python3 -I <scratchpad>/agg.py 21`,
`agg2.py 21`); the figures match the review:

| Persona | n | first-turn ctx (median) | cumulative input (median) | turns (median) | validate.sh runs / dispatch | gate blocks / dispatch |
|---|---|---|---|---|---|---|
| lead-programmer | 256 | 47,498 | 2,788,051 | 38 | 0.46 | 0.04 |
| reviewer | 297 | 40,001 | 3,448,887 | 49 | 2.98 | 1.09 |
| spec-master | 50 | 48,476 | 12,038,910 | 100 | 3.83 | 3.00 |
| task-master | 10 | 43,956 | 38,256,190 | 194 | - | - |
| scribe | 107 | 27,473 | 1,479,087 | 35 | 0.60 | 0.21 |

Share of cumulative input in the window: lead-programmer 29.4%, reviewer
24.2%, spec-master 20.3%, task-master 12.4%, scribe 7.0%.

Top reads: scribe reads `docs/harness-glossary.md` (230 KB, 3,331 lines, so a
Read truncates at line 2000) 122 times and `CONTEXT.md` (97 KB) 118 times in
107 dispatches; the reviewer reads the persona config (9 KB) in 269 of 297
dispatches.

The Fable scripts live in another session's scratchpad (ephemeral). U0
vendors them so the after-measurement is reproducible.

### Premise corrections (measured while writing this spec)

1. **Item 7c needs no config split.** `harness-integrity-gate.sh` already lets
   one read-only `jq` through (`is_benign_jq_read`, lines ~278-287; it also
   lets `command_is_provably_benign` reads through at ~289). Measured in this
   session: `jq -r '.reviewGating.mode // "enforce", .humanReviewMode // "absent", ...' <abs path to persona config>`
   ran unblocked; the same file named in a `cd ...; wc -c ...` compound was
   blocked. `agents/reviewer.md:124-126` claims "a Bash command naming that file
   is refused", which is false for a lone `jq` read. U7c becomes a reviewer-text
   change. `fileHashes` stays where it is (only `bin/cli.js` reads it).
2. **Item 11's evidence is stale.** The 32.5% haiku FAIL rate (plan
   2026-08-25 §B4) and the 28.6% overall rate are August figures. ADR-0040's
   pre-registered forward-rule audit command, run 2026-10-15 on a fresh
   `scripts/unit-outcomes.js` export (486 units), gives population n=77
   (post-cutover `2026-10-08T17:28:48Z`, excluding `htd-` units and 13
   guard-demoted units), f1=6, f2=2, f6=0: fail-rate 0.078, escalation-rate
   0.026, exhaustion-rate 0. The rule prints **`met`**. All post-cutover units
   (n=90): 6 with a FAIL (0.067). All-time: 121 of 486 (0.249).
3. **Item 10's sonnet review already exists for small diffs.**
   `hooks/scripts/reviewer-tier.sh` prints `sonnet` for any non-sensitive diff
   of at most 40 changed lines and 3 files (docs/ is not in
   `SENSITIVE_PATHS`). The open question is only whether a docs-only class gets
   larger size caps. `spec-master` declares no `effort:`, effort is
   frontmatter-only (not settable per dispatch, orchestrator.md "Effort-tier
   policy"), and that policy says a persona's effort may be raised, never
   lowered. So "effort medium for follow-up specs only" cannot be built as
   stated. Neither part of item 10 is built (user ruling, Clarifications).
4. **Item 6 needs no render-time conditional.** The packet machinery in
   `agents/reviewer.md` (lines ~286-492, 13.2 KB; ~16.5 KB counting the
   ESCALATE-TO-HUMAN bullet at 231) largely repeats the protocol's
   `## Fourth verdict: escalate-to-human` section (lines 386-753 of
   `templates/persona-protocol.md`: CHANGES.md, EXAMPLES.md, the `view.sh`
   block, the DECISION file). That section is dropped from the reviewer's
   inlined block, but it ships to every full-tier project as
   `.claude/persona-protocol.md` (`bin/cli.js:616`, `:2507`). A pointer to that
   file needs no `humanReviewMode` conditional and no `--update` re-render on
   config change. That matters because `needsRender` (`bin/cli.js:1452-1490`)
   never looks at config, so a config-conditional render would go stale.
   This repeats the item04 spec's finding (2026-09-25: the matrix cannot reach
   persona-body prose); U6 handles the body directly.
5. **Item 5: the teammate fallback is not teammate-only.** The Write/Edit
   rejection was measured on named dispatches with agent teams off (protocol
   §"Teammate Write/Edit fallback": "regardless of how the tools were
   granted", re-measured 2026-08-09). Lead-programmer keeps it. The 0.5 KB
   agent-teams section is in `UNIVERSAL_PROTOCOL_CORE` (`bin/cli.js:755-762`)
   and `cli.js` reads no environment, so dropping it on
   `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0` would add a new, per-user,
   install-time mechanism for 0.5 KB. Not done.
6. **Item 5: Microworld is dead weight for lead-programmer.** In the last 566
   commits since 2026-09-15, 0 touched `microworlds/`, yet lead-programmer
   inlines the 6.7 KB section on every turn.
7. **Item 7b: most of the proposed allowlist already exists.**
   `program_allowed()` (`hooks/scripts/lib/benign-command.sh:36-50`) already
   allows ls, cat, head, tail, wc, stat, file, test, [, grep, diff, cmp,
   sha256sum, md5sum, basename, dirname, readlink, realpath, echo, printf and
   gh issue|pr|search. Of Fable's list only `du` and `jq` are missing (and
   `jq` is handled only by harness-integrity-gate). The three false positives
   hit while writing this spec were caused by command *shape*, not program
   names: a `cd <repo>;` prefix, `for` loops, `2>&1`, and pipes into
   `xargs`/`sort`/`cut`/`tr`. U7b is therefore corpus-first, and the families
   it may add are frozen (see U7b).
8. **Item 7a was handed off before and never landed.** The 2026-08-25
   dampeners spec (Unit C, ruling E9) gave the denial-message rewrite to
   "spec 1's Step 5". The live `reviewed-path-gate.sh` denial is still ~370
   words: hit three times in this session, text at lines 292/298. §B3's word
   budgets are reused here, not re-measured.
9. **Item 4: the size check already exists.** `bin/agent-memory-size-check.sh`
   is warn-only (512 KB per-namespace threshold) and `tests/validate.sh` already
   runs it (lines 1156-1166). U4b adds an index-size rule to it, so
   `tests/validate.sh` is not touched. The 2026-09-25 item05 spec ruled "do not
   bulk-delete" and gave scribe a prune-on-release duty
   (`agents/scribe.md:57-62`). U4a therefore **moves** index lines to an
   archive index: it does not delete them, and topic files are untouched.
10. **Item 3: the scorers already take a file.** `bin/contract-guard.js
    <path|-> --unit=<id>` (line 29) accepts a file whose line 1 is
    `Unit: <id>` (line 49) as well as a fenced block. `bin/contract-score.js
    <path|->` (line 398) scores one contract. `dispatch-hygiene.sh` H2
    (lines 276-300) already tells a dispatcher to reference a large block by
    path. Adapter ports carry no ladder text (`grep -c ladder` = 0 in both
    orchestrator ports), so U9 does not touch the ports.
11. **Item 12: lead-programmer barely uses Agent.** Its per-dispatch
    tool_result bytes in the window show no `Agent` entry (Read 31.6 KB, Bash
    16.0 KB, Edit, Write, SubagentHandback). The body already forbids explorer
    spawns under a contract (`agents/lead-programmer.md:34`, `:68`).

### Prior plans reused, not redone

- `docs/plans/2026-08-25-agent-throughput-performance-dampeners.md`: §B3 denial
  word counts feed U7a's budget. §B4 pricing (Opus $5/$25, Sonnet $3/$15, Haiku
  $1/$5 per MTok; cache read 0.1x) and its confound disclosure informed the item 10/11 rulings.
  §B2's "the reviewer's run is the only trusted run" supports U1 (quiet output,
  same exit code).
- `docs/plans/2026-09-25-item04-protocol-matrix-trimming.md`: the matrix
  guards (`assertProtocolMatrixComplete`, `assertNoDanglingCrossReferences`)
  and its "keep when unsure" rule govern U5.
- `docs/plans/2026-09-25-item05-agent-memory-dedup.md`: no bulk delete;
  scribe prune duty (U4a).
- ADR-0040 forward rule (U11), `hooks/scripts/reviewer-tier.sh` (item 10, not built).

### Prior FAIL history and spec notes on the touched surfaces

The `.fail` records and `marker-audit.sh --notes` were swept for every touched
surface. The sweep is best-effort: `.claude/reviewed/` is per-clone and has no
history.

- `item04-1-measure-footprint.fail`, `item04-2-apply-drops.fail`: the last
  protocol-matrix trim FAILed, once on dirty agent-memory residue (since
  closed by ADR-0037) and once on measurement. **U5 is ratcheted:** its
  re-scope must never be tagged below the Implementer-tier ratchet, and its
  criteria mutation-prove both matrix guards.
- `packet-brevity-1.fail`: an edit to the reviewer packet text broke
  `tests/cli-backfill.test.js` (mirror and matrix drift). U6 must regenerate
  mirrors in the same commit and run that suite.
- `harness-integrity-gate-hardening.fail`, `hdg-prose-2.fail`: gate-hardening
  units went into FAIL loops under unbounded "every bypass" criteria. U7b
  freezes its family table and its negative corpus up front.
- `reviewer-changes-examples-lean-2.fail` (version-stamp discipline):
  every agents/templates commit carries its own bump (CC-P3 below).
- NOTE[spec] dispositions:
  - `bin/contract-score.js` (rgh-u3-1: persona text vs scorer pointer-phrase
    gaps): U3 changes no scorer rules. Contract files are scored as-is.
  - `agents/orchestrator.md` (blc-6: "FAIL-block count" vs "FAIL count"): U9
    uses "FAIL-block count".
  - `agents/orchestrator.md` (cost-governance-step5: the effort one-way rule
    reads as dispatch-time): moot, since item 10b is not built.
  - `hooks/scripts/lib/benign-command.sh` (item19-2: plain reads are not
    blocked by harness-integrity-gate): consistent with premise 1.
  - `skills/ubiquitous-language` (item03-3: the skill is NOT vendored, so no
    ADR-0012 deviation record): U2 edits it in place.
  - `bin/agent-memory-size-check.sh` (item05-3): U4b extends the same script.
  - `agents/lead-programmer.md` (fc-3, rgh-h13b: the researcher/WebSearch
    carve-out has no contract guard): out of scope. U12 rewrites only the
    explorer bullets.

### Draft ADR (for scribe to number and land; not numbered here)

**Title: The contract of record lives in a per-unit contract file.**
Context: implementers and reviewers read 50-170 KB plan docs to find one
`Unit:` block. The contract of record was a block inside a plan file or issue
body, and a plan revision between two dispatches could silently replace it
(CONTEXT.md "contract of record"). Decision: every dispatch contract is
written to `docs/plans/<plan-slug>/contracts/<unit-id>.md`, whose line 1 is
`Unit: <unit-id>`. The plan doc and the tracker issue link to it and hold no
copy, and the dispatch's Retrieval line cites the file. Consequences: one
source of truth (no plan/contract drift by construction), a 2-6 KB read
instead of 50-170 KB, and the contract-score guard scores the file. A
contract revision is a visible commit to one file.
Alternatives rejected: keep the contracts embedded and grep them out (drift
stays possible, and every implementer must know the grep); issue-body-only
(the fast path has no issue).
This meets all three ADR tests: hard to reverse, since it touches every
persona's dispatch path; surprising without context; a real trade-off.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-15 Functional scope & success criteria: Q Are items 10, 11 and 12
  in scope as changes, or only as decisions? → A: per user (2026-10-15,
  Open Questions round 1). Item 11: record the forward-rule audit and change
  nothing (U11 only). Item 10: build neither part, so there is no docs-only
  reviewer size class and no spec-master `effort:` change. Item 12: drop
  `Agent` from lead-programmer (U12).
- 2026-10-15 Domain entities / data model: Q Where does a unit's contract of
  record live once item 3 lands, and does the standard path keep the
  issue-body copy? → A (self-resolved): in a per-unit contract file on both
  paths. The issue body links to the file and carries no copy (one source,
  no drift). See the draft ADR.
- 2026-10-15 User interaction flow: Q How does a checkpointed
  task-master/spec-master dispatch resume? → A (self-resolved): the persona
  ends with `STATUS: incomplete — checkpoint: <handoff path>` and the
  orchestrator re-dispatches a fresh spawn citing that path. The orchestrator
  also dispatches task-master one wave (5 or fewer units) at a time. No human
  in the loop.
- 2026-10-15 External dependencies & integrations: Q Is the duplicated agent
  roster (bare + `antislop:`) controllable, and can a hook meter a
  subagent's context? → A (self-resolved): the roster is attached to the Agent
  tool, so U12 removing Agent removes it for lead-programmer. Collapsing the
  namespace is an install-architecture change and out of scope. A
  context-meter hook needs a `hooks/hooks.json` registration (Set B, human
  only) and is out of scope; U8 uses a work-size trigger instead.
- 2026-10-15 Edge cases / failure handling: Q Can quiet mode hide a failing
  check? → A (self-resolved): no. The filter drops only known-OK line shapes
  (exclusion, never inclusion), prints the full-log path, and U1 proves with a
  set-inclusion criterion and a mutation run that every FAIL/WARN/SKIP/⚠ line
  survives.
- 2026-10-15 Edge cases / failure handling: Q What if another agent appends
  to a MEMORY.md while U4a prunes it? → A (self-resolved): U4a runs only when
  no other dispatch is in flight. The index cap is warn-only, so later growth
  never blocks the merge gate.
- 2026-10-15 Technical constraints & tradeoffs: Q Can the units be
  implemented concurrently? → A (self-resolved): not the gated ones. See
  "Parallelism and waves".
- 2026-10-15 Technical constraints & tradeoffs: Q Should quiet be validate.sh's
  default or opt-in? → A: per user (2026-10-15): quiet by default, with
  `--verbose` (and `ANTISLOP_VALIDATE_VERBOSE=1`) restoring full output; CI
  passes `--verbose`. `testAndLintCommand` is therefore unchanged and no
  persona-config edit is needed.
- 2026-10-15 Terminology consistency: Q The review says "contract-of-record
  files", "checkpoint" and "quiet mode". Are these glossary terms? → A
  (self-resolved): "contract of record" (CONTEXT.md:462) stays the name of
  the concept and its new home is called a **contract file**. "Dispatch
  checkpoint" is new and distinct from the WIP sentinel (a file a *gated*
  agent writes before pausing; task-master and spec-master are not gated).
  "Quiet mode" is harness vocabulary for `docs/harness-glossary.md`. None are
  written into the glossaries yet: they name artifacts that do not exist yet. Scribe adds them at landing (see the Scribe
  update hint).
- 2026-10-15 Completion / acceptance signals: Q How is "tokens went down
  without quality loss" decided when it needs future dispatches? → A
  (self-resolved): U0 makes the measurement re-runnable with `--since`, and
  this plan pre-registers per-wave targets and no-regression rules (see
  "Measurement and no-regression"). The rules are checked at the milestone
  audit, never as a unit's acceptance criterion.
- 2026-10-15 Edge cases / failure handling: Q (task-master SPEC-GAP 1, #543)
  U1's exclusion filter leaves 694 lines / 47 KB on the real run, so AC1.2
  cannot pass. Relax the bounds, or widen the drop list? → A (self-resolved):
  widen the drop list. It is frozen as KEEP/DROP regexes plus a context rule
  that preserves a failing case's announcement line. Simulated on the saved
  run: 102 lines / 13,050 bytes. The bounds are set at 220 lines / 26,000
  bytes, and AC1.3's set-inclusion uses the full KEEP regex.
- 2026-10-15 Technical constraints & tradeoffs: Q (ptr-u1 second gap) The
  fixture `sample.log` is gitignored (`.gitignore:3`), and the serial gate
  takes 14 minutes, which is over the foreground ceiling. Fix how? → A
  (self-resolved): rename the fixture to `sample.txt` (no `.gitignore` edit,
  no `git add -f`). The wrapper criteria become stub-tree cases, the bounds
  and set-inclusion run on the `validate-lanes.sh` stream, and CC-gate is
  ruled plan-wide (see Common criteria).
- 2026-10-15 Domain entities / data model: Q (SPEC-GAP 2a, #544)
  lead-programmer's 56 kept lines cannot meet the 40-line / 4 KB cap. Change
  the cap or the keep rule? → A (self-resolved): change the keep rule; the cap
  stays. Only `feedback_` lines stay; technique/reference lines move verbatim
  to `TECHNIQUES.md`, the rest to `ARCHIVE.md`, and feedback hooks are
  shortened where needed. Nothing is deleted (item05's no-bulk-delete
  ruling).
- 2026-10-15 User interaction flow: Q (SPEC-GAP 2b, #544) Does a scribe
  contract's `prune: none` or the prune duty at `agents/scribe.md:57-62`
  govern U4a? → A (self-resolved): the contract governs. U4a is a listed index
  reorganization under a scribe contract, not the release prune duty, and
  task-master's own index is added to its scope.
- 2026-10-15 Technical constraints & tradeoffs: Q (SPEC-GAP 3, #546) May U0
  precede U1, given both edit `tests/validate.sh`? → A (self-resolved): yes.
  They edit different regions, each passes in either order, and the route
  gate serializes them anyway.

## Risks / dependencies

- **R1 Mirror and port drift (P3 + parity).** Every unit that edits
  `agents/*.md`, `templates/persona-protocol*.md` or `bin/cli.js` must, in the
  same commit: bump `.claude-plugin/plugin.json`, add a CHANGELOG entry,
  regenerate `.claude/agents/*.md` and `.claude/persona-protocol.md` with
  `node bin/cli.js --update` *after* the bump, and hand-sync the adapter ports
  it affects. Ports exist for explorer, lead-programmer, orchestrator and
  reviewer (`adapters/{codex/agents/*.toml,cursor/agents/*.md}`), plus the
  protocol ports `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc`. They are hand-maintained, not
  generated. Never split a source edit and its shipped copy across two units,
  because `tests/validate.sh` asserts the shipped copies.
- **R2 Removed rule reaches nobody.** U5 and U6 move text out of an inlined
  surface. Mitigation: each has a claim-anchored probe list (every moved
  directive must still exist at its new location) and an explicit keep/drop
  table.
- **R3 Gate-surface changes (U7a/U7b) are a hardening risk.** Frozen family
  table, negative corpus, isolated gate-function harness. Adapter copies of
  `lib/benign-command.sh` must stay byte-identical.
- **R4 U1 changes what every agent sees from the merge gate.** Exit code is
  unchanged; `stop-gate`/`task-gate` read only the exit code. CI
  (`.github/workflows/validate.yml:17`) keeps full output via `--verbose`.
  `tests/validate-lanes.sh` cuts *script* sections, not output, and must stay
  green.
- **R5 A pointer the agent never follows (U5 Microworld, U6 escalation).**
  Each pointer sits at the decision point: "before you create or edit
  anything under `microworlds/`" and "before writing any `.escalated` marker
  or packet, or when the dispatch asks you to resolve a standing escalation",
  so the trigger is in the rule the agent is already executing.
- **R6 Shared files force serial order.** `agents/orchestrator.md`: U3, U8,
  U9, U12. `agents/reviewer.md`: U6, U7c. `agents/task-master.md` and
  `agents/spec-master.md`: U3, U8. `agents/lead-programmer.md`: U5, U12.
  `templates/persona-protocol.md`: U5, U6. `bin/cli.js`: U5 only (U6 does
  not need it). Every agents/templates unit also touches `plugin.json` and
  `CHANGELOG.md`.
- **R7 This plan is sliced before U3 lands,** so task-master slices it under
  today's convention (contracts in issue bodies). Units dispatched after U3
  lands may be re-homed to contract files; that is U3's adoption path, not
  scope creep.
- **R8 The after-measurement is confounded** by workload mix (which plans run
  in the window). Targets are evaluated as medians over at least N dispatches
  per persona and read with the same caution as plan 2026-08-25 §B4.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied — every premise above was measured in
  this session (jq probe, forward-rule run, section sizes, sweep); every step
  carries runnable criteria and mutation proofs where an inverse exists.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  mirrors are regenerated with `bin/cli.js --update`, never hand-edited; the
  persona config is never edited by an agent (U1 default-quiet avoids it, U7c
  reads only); U9 moves ladder arithmetic out of prose into a script.
- P3 "Version-stamp discipline": satisfied — CC-P3 is a required criterion on
  every unit touching `agents/*.md` or `templates/*`, checked per commit by
  `hooks/scripts/version-stamp-check.sh`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — new pointer
  prose is conditional ("if present"); no new unconditional persona reference.
- P5 "`tests/validate.sh` is the merge gate": satisfied — U1 keeps exit
  semantics bit-for-bit (AC1.5/AC1.6), and every new test is registered in it.

## Common criteria (referenced by steps)

- **CC-gate:** `bash tests/validate.sh` (Bash timeout 600000 ms). exit: 0.
  Ruling 2026-10-15 (ptr-u1): the serial gate measured 14 minutes of real time,
  which is over the 600000 ms tool ceiling, and criteria always run in the
  foreground (never `run_in_background`; protocol "Running acceptance-criteria
  commands"). When the serial run cannot finish inside the ceiling, CC-gate is
  met by `bash tests/validate-lanes.sh --lanes 4` (exit: 0) in the foreground.
  That runner executes the same sections with the same per-section exit
  semantics, pinned by `tests/validate-lanes.test.sh`. The serial
  `bash tests/validate.sh` remains the merge gate (constitution P5) and still
  runs at stop-gate as `testAndLintCommand`. If the lane run also exceeds the
  ceiling, the only legal turn-end is the WIP sentinel, whose reason says
  there is no autonomous wake-up.
- **CC-P3** (any unit touching `agents/*.md` or `templates/*`):
  `bash hooks/scripts/version-stamp-check.sh <baseline>..HEAD`. stdout line 1
  starts `version-stamp-check: ok touched: yes`. exit: 0. mutation: drop the
  bump from one touching commit (in a scratch branch) and the output becomes
  `violation`.
- **CC-mirror** (any unit touching `agents/*.md`, `templates/persona-protocol*.md`
  or `bin/cli.js`): `node tests/cli-backfill.test.js` exits 0, AND in a
  throwaway worktree of HEAD (`git worktree add <W> HEAD`),
  `node bin/cli.js --update` followed by `git -C <W> status --porcelain | wc -l`
  prints `0` (remove the worktree by name afterwards). Do not use the
  `--update --check | grep ': (updated|created|pending)$'` idiom: it detects
  nothing.
- **CC-parity** (any unit touching the protocol, a protocol port or an agent
  port): `node tests/adapter-protocol-parity.test.js` and
  `node tests/adapter-skill-parity.test.js` both exit 0.

## Steps

Reviewer tier: every unit marked **sensitive** touches a `reviewer-tier.sh`
`SENSITIVE_PATHS` entry (`hooks/`, `agents/`, `.claude/agents/`, `bin/cli.js`,
`tests/validate.sh`, `templates/persona-protocol*.md`, `.claude-plugin/`) and
reviews on opus. "Recommended model" is advisory input to task-master, which
owns the final `Suggested model` tag. Tags only raise the Escalation ladder's
tier and never lower it.

### Step U0 — Vendor and parameterize the token-usage measurement

Recommended model: sonnet. Sensitive: yes (registers a test in `tests/validate.sh`).
Affected files: `scripts/token-usage/agg.py`, `scripts/token-usage/agg2.py`,
`scripts/token-usage/cache.py` (vendored from the Fable scratchpad
`/tmp/claude-1000/-home-sebas-AntiSlop/1e0be32d-39df-499b-a0d2-41dac7eeea02/scratchpad/`;
the implementer copies them at dispatch time, and if that path is gone,
re-derives them from the column definitions in this plan's baseline table),
`tests/token-usage.test.sh`, `tests/fixtures/token-usage/**` (synthetic
transcripts, no host paths), `docs/audits/2026-10-15-token-baseline.md`,
`tests/validate.sh` (one registration line; SKIP when `python3` is absent).

Changes: add `--root <dir>` (default `~/.claude/projects/-home-sebas-AntiSlop`
expanded at run time, never hard-coded in criteria), `--since <ISO-8601>` and
`--until <ISO-8601>` (filter dispatches by first-message timestamp), and keep
the positional days argument. Output columns are unchanged. The baseline doc
records the table above, the command lines, the window, and HEAD at the time
of the run.

Acceptance criteria:
- AC0.1 `bash tests/token-usage.test.sh` → exit 0; last stdout line
  `token-usage: <k>/<k> passed` with k ≥ 4 (cases: medians on a fixture with
  known values, `--since` drops older dispatches, `--until` drops newer ones,
  persona attribution from the parent `Agent` tool_use). mutation: replace
  the median with a mean in `agg.py` → the fixture-median case fails.
- AC0.2 `python3 -I scripts/token-usage/agg.py --root tests/fixtures/token-usage 36500`
  → exit 0; stdout contains a header line matching `1st-ctx med`.
- AC0.3 `grep -cE '^\| (lead-programmer|reviewer|spec-master|task-master|scribe) \|' docs/audits/2026-10-15-token-baseline.md`
  → `5`.
- CC-gate.

### Step U1 — validate.sh quiet output (item 1)

Recommended model: sonnet. Sensitive: yes (`tests/validate.sh`).
Quiet is the default (user ruling 2026-10-15); `--verbose` or
`ANTISLOP_VALIDATE_VERBOSE=1` restores full output.
Affected files: `tests/validate.sh` (outer wrapper, lines 14-26 only),
`tests/lib/validate-quiet.sh` (new: the filter as a sourced function),
`tests/validate-quiet.test.sh` (new) plus its registration in
`tests/validate.sh`, `tests/fixtures/validate-quiet/sample.txt` (new; `.txt`
because `.gitignore:3` ignores `*.log`, ruling 2026-10-15; one line
of each DROP and KEEP shape below, plus a `Test (x): ...` announcement
followed by a `✗` result line),
`.github/workflows/validate.yml` (add `--verbose`), `README.md` (one line
documenting the flag), `CHANGELOG.md` (entry; no version bump required,
since `tests/` is not version-stamped).

Design: the wrapper already re-runs the script with
`ANTISLOP_VALIDATE_INNER=1` and tees to a `mktemp` file. In quiet mode it keeps
that file (no `rm` on EXIT), prints the inner stream through the filter, and
ends with exactly the existing SKIP summary plus two new lines:
`Counts: OK=<n> FAIL=<n> WARN=<n> SKIP=<n>` and `Full log: <path>`. The inner
script and the exit code are unchanged. `--verbose` prints the inner stream
unfiltered (today's behaviour).

The filter (revised 2026-10-15, ruling on task-master SPEC-GAP 1 for #543) is
an exclusion filter with a keep override. Both regexes are frozen; they are
applied per line, as ERE (PCRE `\d`/`\s` spelled `[0-9]`/`[[:space:]]` in the
bash implementation):

- **KEEP** (always printed, overrides DROP):
  `^(FAIL|WARN|SKIP)|⚠|✗|not ok|FAILED|Error|ERROR`
- **DROP** (printed only if KEEP also matches):
  `^(OK |ok |Test |hint:|All .*(passed|pass)|\[master|\[detached| create mode| delete mode| [0-9]+ files? changed|editing .*budget|Switched to|Preparing worktree|HEAD is now|Initialized empty Git)`,
  `^[[:space:]]*✓`, `^[[:space:]]*$`, and `^--( .* --)?$` (the `-- sub-section --`
  titles);
- **context rule:** when a line matches KEEP and the line just before it was
  dropped and is not blank, print that previous line first, so a failing
  case's `Test (x): ...` announcement survives with its result;
- **headers:** an `== ` header prints only when at least one line of its
  section prints.

Measured on the saved real run (the Fable scratchpad `validate.out`, 4,209
lines, 251,857 bytes; task-master's figures re-derived with a Python model
of exactly these rules), the filtered stream is **102 lines, 13,050 bytes**.
Of that, the 17 `⚠ hooks/hooks.json` warning lines are about 6 KB, and the
rest is unclassified stderr from passing suites, which correctly still prints
because it matches neither list. The AC1.2 bounds below are about twice
those figures, leaving room for growth. The earlier draft's list (no `Test `,
titles, `hint:` or git-noise drops) measured 694 lines and 47,175 bytes and
could not meet any sensible bound; that list is superseded.

Acceptance criteria:
- AC1.1 `bash tests/validate-quiet.test.sh` → exit 0. It asserts, on the
  fixture: every input line matching the KEEP regex is present in the output;
  no line matching DROP-but-not-KEEP is; a `Test (x): ...` line directly above
  a `✗` line is present (context rule) while a `Test (y): ...` line above a
  `✓` line is absent; a header with only dropped lines under it is absent; a
  header with a FAIL under it is present. mutation: remove `✗` from KEEP →
  exit 1.
- AC1.2 (revised 2026-10-15) `bash tests/validate-lanes.sh --lanes 4 > <T>/full.out 2>&1`
  → exit 0, run in the foreground. The stream is then piped through
  `validate_quiet_filter` (sourced from `tests/lib/validate-quiet.sh`) into
  `<T>/q.out`, and `wc -c < <T>/q.out` ≤ 26000 and `wc -l < <T>/q.out` ≤ 220.
  Baseline: 251,857 bytes and 4,209 lines. The filter simulated on the saved
  run gives 102 lines / 13,050 bytes, and the implementer's first real serial
  run measured 101 lines / 13,085 bytes.
- AC1.3 `grep -c '^OK ' <T>/full.out` ≥ 2000, AND
  `comm -23 <(grep -E '^(FAIL|WARN|SKIP)|⚠|✗|not ok|FAILED|Error|ERROR' <T>/full.out | sort -u) <(sort -u <T>/q.out) | wc -l`
  → `0`.
- AC1.4 to AC1.6 (revised 2026-10-15) are stub-tree cases inside
  `tests/validate-quiet.test.sh`, run by AC1.1. A throwaway tree holds the real
  wrapper (every line of `tests/validate.sh` up to the wrapper's closing `fi`)
  followed by a stub body that prints a FAIL line and then an OK line and exits
  `$STUB_RC`. The cases assert, with `ANTISLOP_VALIDATE_INNER` unset:
  - quiet mode returns rc 1 and rc 0 as given, prints the FAIL line, drops the
    OK line, and prints a `Full log:` path whose file holds the OK line;
  - `--verbose` and `ANTISLOP_VALIDATE_VERBOSE=1` print the OK line and
    return rc 1;
  - `--verbose` prints no `Full log:` line.
  mutation: `exit 0` in place of `exit "$inner_rc"`. Measured by spec-master
  on a scratch copy of the first attempt's wrapper: 3 FAIL lines. These cases
  replace the full-gate runs of the earlier draft, which cannot finish inside
  the 600000 ms ceiling.
- AC1.7 `bash tests/validate-lanes.test.sh` → exit 0.
- CC-gate.

### Step U4a — Move index lines out of four memory indexes (item 4, scribe)

Recommended model: haiku (scribe, ungated). Sensitive: no.
Revised 2026-10-15 (ruling on task-master SPEC-GAP 2 for #544).

**Executor and governing text (ruling on gap 2b).** U4a is dispatched to
`scribe` **with** a scribe dispatch contract. That contract's Doc edits list
the eight index files below by path and end with `prune: none`, as every
scribe contract does. The contract governs. U4a is a **listed index
reorganization**, not the release prune duty at `agents/scribe.md:57-62`:
that duty (hand-reviewing and pruning completion entries) does **not** run,
no topic file is deleted, and no persona text changes. This also respects
the "no bulk delete" ruling (item05, 2026-09-25), since every index line is
moved verbatim, never deleted. Run U4a only when no other dispatch is in
flight, so no persona appends to a MEMORY.md mid-move.

**Scope (ruling on task-master's MEMORY.md).** Four indexes:
`.claude/agent-memory/{lead-programmer,scribe,spec-master,task-master}/MEMORY.md`.
task-master is added (4,560 bytes, over the byte cap) because a warning
that never clears trains everyone to ignore it. The `antislop-*` namespaces
are already under the cap and are not touched.
Affected files: those four `MEMORY.md` files, plus a new `TECHNIQUES.md` and
`ARCHIVE.md` in each of the four directories, only where at least one line
moves there. Topic files are **not** edited, renamed or deleted.

**Rule (ruling on gap 2a; deterministic, one rule for all four).** The cap
stays at 4096 bytes and 40 lines for every index.
1. Lines whose target starts `feedback_` stay in `MEMORY.md`.
2. Lines whose target starts `technique_`, `review_technique_` or
   `reference_` move verbatim to `TECHNIQUES.md`.
3. Every other line (`project_`, `cross_plan_`, anything else) moves verbatim
   to `ARCHIVE.md`.
4. `MEMORY.md` gains exactly these pointer lines, each only if its file
   exists:
   `- [Techniques](TECHNIQUES.md) — how-to notes (bash, gates, tests); grep it by keyword before solving a mechanics problem`
   `- [Archive](ARCHIVE.md) — closed-plan and project notes; grep it before concluding none exists`
5. Each new file opens with one header line:
   `# <persona> memory <techniques|archive> — index lines moved from MEMORY.md on 2026-10-15; topic files unchanged`.
6. If `MEMORY.md` is still over the cap, shorten the **hooks** (the text
   after ` — `) of the kept `feedback_` lines, never their `[title](target)`
   part, until it fits. lead-programmer (19 feedback lines, 4,337 B) and
   task-master (19 lines, 4,006 B) need it once the two pointer lines (about
   230 B) are added: about 500 B and 150 B must come off respectively.
7. Optional fill: if room remains under the cap, scribe may move individual
   lines back from `TECHNIQUES.md` (verbatim) and must list each one in its
   report.
`MEMORY.md` is not auto-trimmed after this. U4b's warning reports regrowth.

Measured fit (2026-10-15 sizes of the feedback lines alone): lead-programmer
19 lines / 4,337 B; task-master 19 / 4,006 B; spec-master 12 / 2,578 B (plus 2
non-link lines); scribe 7 / 1,397 B (plus 7 non-link lines). Every result
has 23 lines or fewer, so the line cap is never binding. The byte cap is met
by step 6 for lead-programmer and task-master.

Acceptance criteria. Let `<pre>` be the parent of U4a's commit, **not** the
plan baseline: memory indexes change between the two, for example
spec-master's on 2026-10-15. Each criterion is run for each persona P of the
four.
- AC4a.1 `wc -c < .claude/agent-memory/P/MEMORY.md` ≤ 4096 and
  `wc -l < .claude/agent-memory/P/MEMORY.md` ≤ 40.
- AC4a.2 No link lost:
  `diff <(git show <pre>:.claude/agent-memory/P/MEMORY.md | grep -oE '\]\([^)]+\)' | sort) <(cat .claude/agent-memory/P/MEMORY.md .claude/agent-memory/P/TECHNIQUES.md .claude/agent-memory/P/ARCHIVE.md 2>/dev/null | grep -oE '\]\([^)]+\)' | grep -vE '\]\((TECHNIQUES|ARCHIVE)\.md\)' | sort)`
  → empty, exit 0. mutation: delete one moved line from `ARCHIVE.md` → one
  diff line.
- AC4a.3 Every `feedback_` link at `<pre>` is still in `MEMORY.md`:
  `comm -23 <(git show <pre>:.claude/agent-memory/P/MEMORY.md | grep -oE '\(feedback_[^)]+\)' | sort -u) <(grep -oE '\(feedback_[^)]+\)' .claude/agent-memory/P/MEMORY.md | sort -u) | wc -l`
  → `0`.
- AC4a.4 Moved lines are verbatim: every line of `TECHNIQUES.md` and
  `ARCHIVE.md` except the header occurs in `<pre>`'s `MEMORY.md`:
  `comm -23 <(tail -n +2 -q .claude/agent-memory/P/TECHNIQUES.md .claude/agent-memory/P/ARCHIVE.md 2>/dev/null | sort -u) <(git show <pre>:.claude/agent-memory/P/MEMORY.md | sort -u) | wc -l`
  → `0`.
- AC4a.5 Topic files untouched:
  `git diff --name-only <pre>..HEAD -- .claude/agent-memory/ | grep -vE '/(MEMORY|ARCHIVE|TECHNIQUES)\.md$' | wc -l`
  → `0`.

### Step U4b — Advisory index-size rule (item 4)

Recommended model: haiku. Sensitive: no (`tests/validate.sh` already runs the
script; not edited).
Affected files: `bin/agent-memory-size-check.sh`,
`tests/agent-memory-size-check.test.sh`.
Change: besides the existing per-namespace check, print
`WARN agent-memory index <path> is <bytes> B / <lines> lines (cap 4096 B / 40 lines)`
for any `.claude/agent-memory/*/MEMORY.md` over either cap. Exit status stays
0 (warn-only). Caps can be changed with `--index-cap-bytes N` and
`--index-cap-lines N`.

Acceptance criteria:
- AC4b.1 `bash tests/agent-memory-size-check.test.sh` → exit 0, with new
  cases: an over-cap fixture index prints exactly one `WARN agent-memory index`
  line and exits 0; an at-cap fixture (4096 B, 40 lines) prints none.
  mutation: change `-gt` to `-ge` in the byte comparison → the at-cap case
  fails.
- AC4b.2 `bash bin/agent-memory-size-check.sh; echo $?` → last line `0`.
- CC-gate.

### Step U7c — Reviewer reads two config keys with one jq (item 7c)

Recommended model: haiku. Sensitive: yes (`agents/`).
Affected files: `agents/reviewer.md` (the bullet at ~124-135 and the
`humanReviewMode` read at ~234-240), `.claude/agents/reviewer.md`
(regenerated), `adapters/codex/agents/reviewer.toml` and
`adapters/cursor/agents/reviewer.md` (only if they carry the Read-tool
mandate; check with `grep -n 'Read. tool' <port>`),
`tests/harness-integrity-gate.test.sh` (one pin case),
`.claude-plugin/plugin.json`, `CHANGELOG.md`.
Change: replace the "read with the Read tool (a Bash command naming that file
is refused …)" mandate with the single command
`jq -r '.reviewGating.mode // "enforce", .humanReviewMode // "critical"' .claude/persona-config.json`
run alone: no `cd` prefix, pipe, redirect or separator, because
`is_benign_jq_read` admits only a lone jq. Semantics are unchanged: only the
exact string `off` counts for each key, and a non-zero exit (unreadable
config) means `enforce` / `critical`. State the false premise plainly: a lone
`jq` read is allowed; compound commands naming the file are not.

Acceptance criteria:
- AC7c.1 The documented command passes all three Bash gates. The new test
  case feeds the exact command string, extracted from `agents/reviewer.md`
  (not retyped), as a PreToolUse payload with
  `agent_type=reviewer` to `harness-integrity-gate.sh`,
  `reviewed-path-gate.sh` and `human-decision-gate.sh`, and asserts exit 0
  from each. `bash tests/harness-integrity-gate.test.sh` → exit 0. mutation:
  prefix the extracted command with `cd /tmp; ` inside the test → the case
  fails.
- AC7c.2 `grep -c 'with the .Read. tool' agents/reviewer.md` → `0`, and
  `grep -c "jq -r '.reviewGating.mode" agents/reviewer.md` → `1`.
- CC-P3, CC-mirror, CC-parity, CC-gate.

### Step U6 — Reviewer escalation packet machinery becomes a pointer (item 6)

Recommended model: sonnet. Sensitive: yes (`agents/`, `templates/persona-protocol.md`).
Depends on: U7c (same file).
Affected files: `agents/reviewer.md` (bullets "Durable escalation packet"
through "Resolving a standing escalation", ~lines 286-492, replaced by one
pointer bullet), `.claude/agents/reviewer.md` (regenerated),
`templates/persona-protocol.md` §"Fourth verdict: escalate-to-human" (only
to absorb reviewer-only directives it lacks), and, only if that template
section changes, its surfaces `.claude/persona-protocol.md`,
`adapters/codex/agents-md-fragment.md` and
`adapters/cursor/rules/persona-protocol.mdc`;
`tests/packet-view-script.test.sh` (drop `agents/reviewer.md` and
`.claude/agents/reviewer.md` from its `copies=` list at line 13),
`tests/adapter-protocol-parity.test.js` (`ESCALATION_PROBES`, only if a probe
targets the reviewer body), any other test that pins a removed reviewer
string (find with `git grep -l` over `tests/`), `.claude-plugin/plugin.json`,
`CHANGELOG.md`.

Keep in `agents/reviewer.md`: the ESCALATE-TO-HUMAN decision bullet (verdict
precedence, `humanReviewMode` resolution, "only a unit you would have passed
escalates"), the INSUFFICIENT-CONTEXT and FAIL bullets, and the stop-gate
bullet at ~493. The Writer/Reviewer split text is untouched.
New pointer bullet (verbatim payload):
"**Escalation packet and resolution (read on demand):** before you write any
`.escalated` marker or packet, and whenever a dispatch asks you to resolve a
standing escalation, Read the `## Fourth verdict: escalate-to-human` section
of `.claude/persona-protocol.md` (in this plugin's own repo:
`templates/persona-protocol.md`) and follow it. It defines the packet
directory, `PACKET.md`, `CHANGES.md`, `EXAMPLES.md`, `view.sh`, the manifest
`verifiedBy` stamp and the DECISION-file transcription routes. Under
`humanReviewMode: off` or `reviewGating.mode: off` you never escalate, so you
never need it."

First ordered edit: build the **probe list** of every normative directive in
the removed block, one distinctive phrase per bullet or sentence (at least:
`cp -a`, `byte-identical copy of the marker body`, `verifiedBy`, `startLine`,
`examples:`, `view.sh:begin`, `chmod +x`, `transcription, never re-review`,
plus one per remaining sentence that states a MUST or never). Then confirm
each phrase occurs in the protocol section, adding the missing ones to it.
Commit the probe list as `tests/fixtures/reviewer-escalation-probes.txt`.

Acceptance criteria:
- AC6.1 Every probe moved:
  `while IFS= read -r p; do awk '/^## Fourth verdict: escalate-to-human/,/^## Continuing after a FAIL verdict/' templates/persona-protocol.md | tr -s ' \n' ' ' | grep -qF -- "$p" || echo "MISSING $p"; done < tests/fixtures/reviewer-escalation-probes.txt | wc -l`
  → `0` (prose flattened before matching). mutation: delete one probed
  sentence from the template section → `1`.
- AC6.2 `wc -l < tests/fixtures/reviewer-escalation-probes.txt` ≥ 12.
- AC6.3 `wc -c < agents/reviewer.md` ≤ 21500 (baseline 33,540).
- AC6.4 `grep -c 'Fourth verdict: escalate-to-human' agents/reviewer.md` → ≥ 1,
  and `grep -c 'view.sh:begin' agents/reviewer.md` → `0`.
- AC6.5 `bash tests/packet-view-script.test.sh` → exit 0.
- CC-P3, CC-mirror, CC-parity, CC-gate.

### Step U2 — Grep-first glossary access (item 2)

Recommended model: sonnet. Sensitive: yes (`agents/`, `tests/validate.sh` registration).
Affected files: `skills/ubiquitous-language/SKILL.md` (in-repo authored, not
vendored), `agents/scribe.md`, `.claude/agents/scribe.md` (regenerated),
adapter skill copies if `tests/adapter-skill-parity.test.js` covers this
skill, `tests/glossary-index.test.sh` (new) and its registration in
`tests/validate.sh`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
No generated `CONTEXT.index.md`: a generated index is a new mirror that can
drift, and the grep is ~5 KB anyway (measured: 4,844 bytes for CONTEXT.md
term and `_Avoid_` lines vs 96,874 bytes whole).

Change: one canonical recipe, held between
`<!-- glossary-index:begin -->` and `<!-- glossary-index:end -->` markers in
`SKILL.md` and repeated verbatim in `scribe.md`:
1. Index: `grep -nE '^\*\*|^\s*_Avoid_:' <glossary>`. This prints every
   term line and every avoid line with its line number, and serves all three
   lenses' breadth (the term list for lens 3, the avoid lines for lens 2).
2. Read only a matching entry by range: from its term line up to the line
   before the next term line (`Read` with offset/limit, or
   `sed -n '<a>,<b>p'`).
3. The whole-file read is allowed only when the input's terms match more than
   15 entries.
Scribe uses the same recipe for `docs/harness-glossary.md`, which also fixes
today's silent truncation at Read's 2000-line limit (that file has 3,331
lines).

Acceptance criteria:
- AC2.1 `bash tests/glossary-index.test.sh` → exit 0. It extracts the index
  command from between the SKILL.md markers, runs it on both glossaries and
  asserts: the term-line count equals `grep -c '^\*\*' <glossary>` (125 and 233
  at baseline; computed live, not hard-coded); every `_Avoid_:` line is
  present; the output is ≤ 10% of the glossary's bytes; the range recipe on
  the term `contract of record` returns a block whose first line starts with
  `**contract of record**` and that contains no other `^\*\*` line. It also
  asserts that the recipe text in `agents/scribe.md` is byte-identical to the
  SKILL.md block. mutation: change `^\*\*` to `^\*\*[a-z]` in SKILL.md →
  count mismatch, exit 1.
- AC2.2 Flattened, the old whole-read directive is gone: the phrase
  instructing a whole-file read of `CONTEXT.md`, located by the implementer
  and named in the ready-for-review packet, gives
  `tr -s ' \n' ' ' < agents/scribe.md | grep -c '<phrase>'` → `0`.
- CC-P3, CC-mirror, CC-parity, CC-gate.

### Step U5 — Split the shared protocol for lead-programmer (item 5)

Recommended model: sonnet (ratcheted, see FAIL history; never haiku).
Sensitive: yes (`bin/cli.js`, `templates/`, `agents/`).
Depends on: U6 (same template file).
Affected files: `templates/persona-protocol.md`, `bin/cli.js`
(`PROTOCOL_SECTIONS_BY_PERSONA` rows at ~777-930 only),
`agents/lead-programmer.md` (one pointer line), `.claude/persona-protocol.md`,
`.claude/agents/*.md` (regenerated), `adapters/codex/agents-md-fragment.md`,
`adapters/cursor/rules/persona-protocol.mdc`,
`tests/adapter-protocol-parity.test.js` (section maps),
`tests/cli-backfill.test.js` (only if it enumerates section names),
`templates/protocol-digest.md` (only if it names the split section; the digest
is not a mirror), `.claude-plugin/plugin.json`, `CHANGELOG.md`.

Per-persona keep/drop decision for lead-programmer (sizes measured from
`templates/persona-protocol.md`):

| Section | KB | Decision | Why |
|---|---|---|---|
| Universal core (6 sections incl. Agent-teams 0.5) | 7.9 | keep | code-enforced core; no env-conditional render (premise 5) |
| Teammate Write/Edit fallback | 1.7 | keep | applies to named dispatches without teams (premise 5) |
| WIP sentinel, Pending-review flag | 1.0 + 2.9 | keep | `GATED_AGENT_SECTIONS` force-include for gated agents |
| Running acceptance-criteria, Retrieval, Machine-checkable | 1.9 | keep | executed every unit |
| Review ownership | 6.5 | **split** | see below |
| Continuing after a FAIL verdict | 1.9 | keep | fix re-dispatches land on lead-programmer |
| A note on `memory` | 1.3 | keep | commit-own-memory rule is executed |
| Microworld bundles (+6 subsections) | 6.7 | **drop + pointer** | 0 commits touched `microworlds/` in the last 566 |

The **split**: `## Review ownership — one unit, one review, single owner`
keeps only what an implementer acts on: it never spawns or messages the
reviewer; the four verdicts and that "done" means PASS; a FAIL routes back
to it, it fixes only the listed items, never re-plans or grades its own work;
the one-unit-at-a-time invariant; and under `reviewGating.mode: off` the
verdict is advisory. Everything else (marker format v3 and its parsers,
`.blocked` heuristics and ADR-0028 scoping, the two axes and ADR-0016,
`TaskCompleted`/`task-gate.sh`, the `off` inert/armed lists, leftover-flag
cleanup) moves verbatim to a new
`## Review markers and gate mechanics (owner-facing)` section, placed right
after it. The new section is **included for every persona that includes
Review ownership today except lead-programmer**, so only lead-programmer's
block changes.
The pointer line in `agents/lead-programmer.md`: "Before creating or editing
anything under `microworlds/`, Read the `## Microworld bundles` section of
`.claude/persona-protocol.md` (in this plugin's own repo:
`templates/persona-protocol.md`) and follow it."

Acceptance criteria:
- AC5.1 Only lead-programmer's block shrinks: after `node bin/cli.js --update`,
  `wc -c < .claude/agents/lead-programmer.md` is at least 9000 bytes below
  baseline (record both numbers), and for every other `.claude/agents/*.md`
  the protocol block's text is unchanged except for the new section heading.
  Check: `git diff <baseline>..HEAD -- .claude/agents/ ':!.claude/agents/lead-programmer.md' | grep -E '^[-+][^-+]' | grep -vE '^[-+](## Review markers and gate mechanics|<!-- antislop v)' | wc -l`
  → `0`. Moved lines reappear unchanged, so they cancel in a section-order
  diff. If they do not cancel, the implementer reports the residual lines with
  a reason in the review packet and the reviewer judges them.
- AC5.2 Moved, not lost: every non-blank line of the baseline's Review
  ownership section appears in the template's Review ownership section or
  in the new owner-facing section:
  `comm -23 <(git show <baseline>:templates/persona-protocol.md | awk '/^## Review ownership/,/^## Pending-review flag/' | grep -v '^## ' | grep -v '^$' | sort -u) <(awk '/^## Review ownership/,/^## Pending-review flag/' templates/persona-protocol.md | grep -v '^$' | sort -u) | wc -l`
  → `0`.
- AC5.3 Both matrix guards are live (mutation-proved): in a scratch copy,
  removing the new heading from one include/drop list makes
  `node bin/cli.js --update` exit non-zero (`assertProtocolMatrixComplete`);
  dropping `Review markers and gate mechanics (owner-facing)` for the reviewer
  while a kept reviewer section names it also exits non-zero
  (`assertNoDanglingCrossReferences`). Unmutated: exit 0.
- AC5.4 `grep -c 'microworlds/' agents/lead-programmer.md` ≥ 1 and
  `grep -c '^## Microworld bundles' .claude/agents/lead-programmer.md` → `0`.
- CC-P3, CC-mirror, CC-parity, CC-gate.

### Step U3 — Per-unit contract files (item 3)

Recommended model: sonnet. Sensitive: yes (`agents/`).
Affected files: `agents/spec-master.md` (fast-path hand-off),
`agents/task-master.md` (Contract home and precedence, ~60-75, and the
issue-body example), `agents/orchestrator.md` (Dispatch hygiene item 1/2
wording and the Contract-score guard command at ~509-515),
`.claude/agents/{spec-master,task-master,orchestrator}.md` (regenerated),
`adapters/codex/agents/orchestrator.toml` and
`adapters/cursor/agents/orchestrator.md` (only where they carry the
contract-home or guard text; check with grep), `skills/pathfinder/SKILL.md`
(only if it prescribes the contract's location in the issue body),
`tests/contract-files.test.sh` (new: the AC3.1 equivalence script, registered in `tests/validate.sh`; `tests/contract-score.test.js` exists but no contract-guard test does), `.claude-plugin/plugin.json`,
`CHANGELOG.md`. `bin/contract-guard.js` and `bin/contract-score.js` are
**not** changed unless the bare-file test fails; if it fails, the fix is
limited to input parsing.

Rules to write:
- Every dispatch contract (lead or scribe shape, fast or standard path) is
  written to `docs/plans/<plan-slug>/contracts/<unit-id>.md`. Line 1 is
  `Unit: <unit-id>`; it is unfenced and has no other content than the
  nine-element contract. The writer commits it before the unit is dispatched.
- The plan doc's dispatch section and the tracker issue body hold a link to
  the file and **no copy** (the per-unit file is authoritative; a copy
  anywhere else is a spec gap).
- The dispatch's Retrieval line cites the file path. "Artifact, not argument"
  and "One brief, many siblings" still hold: cite the path, never paste the
  body.
- The Contract-score guard command on both paths becomes
  `node bin/contract-guard.js docs/plans/<plan-slug>/contracts/<unit-id>.md --unit=<unit-id>`.
  The `gh issue view … | contract-guard -` form stays only as the fallback for
  units sliced before this step.
- The implementer reads the contract file, plus a plan section only when
  the contract's Pre-resolved context names one by heading.

Acceptance criteria:
- AC3.1 Equivalence: for every fenced `Unit:` contract in
  `docs/plans/2026-10-14-validate-lanes-followups-2.md` and
  `docs/plans/2026-10-14-skills-audit-leftovers-2.md` (implementer extracts
  each into `<T>/<id>.md`), both
  `node bin/contract-guard.js <T>/<id>.md --unit=<id>` and
  `node bin/contract-guard.js <plan> --unit=<id>` print the same first stdout
  line; and `node bin/contract-score.js --rubric=v2 <T>/<id>.md` equals the
  score of the same block given on stdin. A script under `tests/` asserts
  this and exits 0. mutation: append a stray ``` line to one extracted
  file → the guard's first line differs.
- AC3.2 `grep -c 'contracts/<unit-id>.md' agents/task-master.md agents/spec-master.md agents/orchestrator.md`
  → each ≥ 1. And `tr -s ' \n' ' ' < agents/task-master.md | grep -c 'contract lives in the issue body under'`
  → `0` (the old home sentence is gone).
- CC-P3, CC-mirror, CC-parity, CC-gate.

### Step U8 — Dispatch checkpoints for task-master and spec-master (item 8)

Recommended model: sonnet. Sensitive: yes (`agents/`).
Depends on: U3 (contract files are the flush target).
Affected files: `agents/task-master.md`, `agents/spec-master.md`,
`agents/orchestrator.md` ("Default feature pipeline" ~437 and
"Dispatch-model routing for spec-master, milestone-auditor, and task-master"
~540), `.claude/agents/*` (regenerated), orchestrator ports only if they
carry the pipeline text, `.claude-plugin/plugin.json`, `CHANGELOG.md`.

Rules (size trigger = work size, because context size is invisible to the
agent and `maxTurns` does not bound it):
- **Orchestrator batching.** Dispatch task-master for at most one wave of 5
  or fewer units per spawn, naming the step range in the prompt. Waves are
  the plan's "Parallelism and waves" list if it has one; otherwise
  consecutive steps.
- **task-master flush.** Write and commit each unit's contract file as soon as
  that unit is finished, never in one batch at the end. After every 3 units
  in one spawn, or at the end of the wave if sooner, end the turn with
  `STATUS: incomplete — checkpoint: <path of the handoff note>` when units
  remain. The handoff note (`docs/plans/<slug>/handoff-task-master.md`,
  overwritten each time) lists the units done (with contract paths) and the
  next unit, plus any decision taken that is not in a contract. It holds no
  discussion.
- **spec-master checkpoints.** There are three natural ones: (1) Open Questions
  returned; (2) plan doc written and Self-check passed; (3) after publishing,
  before dispatch contracts on the fast path. At (2) and (3), if the spec has
  more than 5 steps, end with `STATUS: incomplete — checkpoint: <plan path>`
  and leave the next phase to a fresh spawn. Decisions live in the plan's
  Clarifications and Context, never in the transcript.
- **Orchestrator resume.** On `STATUS: incomplete — checkpoint: <path>`,
  re-dispatch the same persona fresh, citing the path. This is not a failure
  and is not counted toward anything.

Acceptance criteria:
- AC8.1 `tr -s ' \n' ' ' < agents/task-master.md | grep -c 'STATUS: incomplete — checkpoint:'`
  ≥ 1, and the same check on `agents/spec-master.md` and
  `agents/orchestrator.md` gives ≥ 1 each.
- AC8.2 The status regex of the protocol accepts the checkpoint form:
  `printf 'STATUS: incomplete — checkpoint: docs/plans/x/handoff-task-master.md\n' | grep -cE '^STATUS: (complete|incomplete [—-] .+)$'`
  → `1` (this guards against inventing a third status word).
- AC8.3 `grep -cE 'at most one wave of 5|≤ ?5 units per spawn' agents/orchestrator.md`
  ≥ 1.
- CC-P3, CC-mirror, CC-parity, CC-gate.

### Step U9 — Mechanize ladder arithmetic and the escalation card (item 9)

Recommended model: sonnet. Sensitive: yes (`agents/orchestrator.md`,
`tests/validate.sh` registration).
Affected files: `bin/ladder-tier.sh` (new), `bin/escalation-card.sh` (new),
`tests/ladder-tier.test.sh` (new) plus its registration in `tests/validate.sh`,
`tests/fixtures/ladder-tier/**` (synthetic marker dirs),
`agents/orchestrator.md` ("Per-unit model routing" ~449-539 and "At the
2-FAIL cap" ~380), `.claude/agents/orchestrator.md` (regenerated),
`.claude-plugin/plugin.json`, `CHANGELOG.md`. The ports carry no ladder text,
so they are not touched.

`bin/ladder-tier.sh <unit-id> [--contract <path>] [--project <dir>]` (or `bin/ladder-tier.sh --census`, which prints one line per existing `.fail` record, prefixed `<unit-id> `) prints
exactly one line, `ladder-tier: <haiku|sonnet|opus|EXHAUSTED> n=<n> ladder=<a,b,...> reason=<word>`,
and exits 0. It encodes the prose exactly:
- the default tier from `defaultImplementerModel` via one lone `jq` read
  (absent → frontmatter `model:` of `agents/lead-programmer.md`;
  unrecognised → `opus`);
- the ladder is two entries per tier from the default upward;
- n is the FAIL-block count (reuse `bin/fail-count.sh`'s logic through
  `hooks/scripts/lib/state-access.sh`);
- any FAIL block before the Haiku-default cutover (read from the cutover line
  in `agents/orchestrator.md`, not duplicated) moves the start to the more
  capable of sonnet and the default;
- the guard: when the ladder starts at haiku and `--contract` is given, run
  `node bin/contract-guard.js`; anything but a first line starting
  `contract-guard: haiku ` means a sonnet ladder and `reason=guard-demotion`.
  When the ladder starts at haiku and `--contract` is absent, use a sonnet
  ladder with `reason=no-contract` (fail toward more capable);
- expiry: a PASS marker newer than the `.fail` record means n=0;
- n ≥ ladder length means `EXHAUSTED`;
- any read error means `opus` with `reason=fail-closed`.
It never writes anything, including the rulings ledger, which stays the
orchestrator's job. `bin/escalation-card.sh <unit-id>` prints the defect
history the cap section requires (every FAIL block's header + `tier:` line +
first defect line, and every fix-attempt commit subject from
`git log --format='%h %s' --grep='(<unit-id>)'`). It never prints the
options: they stay in orchestrator.md, defined in one place.
The orchestrator prose shrinks to three rules: run the script before every
per-unit dispatch and pass its tier; on `EXHAUSTED`, run the card script and
go to "At the 2-FAIL cap"; a `Suggested model` tag can only raise the tier.
The definitional paragraphs move to the script header comment.

Acceptance criteria:
- AC9.1 `bash tests/ladder-tier.test.sh` → exit 0, over a **frozen** branch
  table of ≥ 14 fixture cases: default ∈ {haiku, sonnet, opus, absent,
  bogus} × n ∈ {0, 1, 2, 4, 6}, the subset needed to cover every ladder
  position, plus pre-cutover block, expired record, guard pass, guard
  demotion, no contract, unreadable count. Each expected line is literal in
  the test. mutation: change `-ge` to `-gt` in the exhaustion comparison → at
  least one case fails.
- AC9.2 Census over the real record set:
  `bash bin/ladder-tier.sh --census` prints one line per existing `.fail`
  record. Every line's `n=` equals `bash bin/fail-count.sh <unit>` for that
  unit (asserted inside `tests/ladder-tier.test.sh` without spelling the
  marker directory in command text), and no line has
  `reason=fail-closed`.
- AC9.3 `awk '/^## Per-unit model routing/,/^### Dispatch-model routing/' agents/orchestrator.md | wc -c`
  ≤ 2500 (baseline 5,977), and
  `grep -c 'bin/ladder-tier.sh' agents/orchestrator.md` ≥ 1.
- CC-P3, CC-mirror, CC-gate.

### Step U7a — Shorter denial messages (item 7a)

Recommended model: sonnet. Sensitive: yes (`hooks/`).
Affected files: `hooks/scripts/reviewed-path-gate.sh` (denials at ~292, ~298),
`hooks/scripts/human-decision-gate.sh` (`deny()` ~656-672), their adapter
copies if `tests/validate.sh` asserts byte identity, `tests/reviewed-path-gate.test.sh`,
`tests/human-decision-gate.test.sh` (message pins), `docs/harness-glossary.md`
(two anchored entries that receive the explanatory text verbatim),
`CHANGELOG.md`.
Message shape: one line naming what was blocked and why (≤ 25 words); one
line with the remedy (`reviewed-path-gate`: `grep -r` to search,
`git commit -F <file>` to commit a message naming the path, a trailing `#`
comment to narrate; `human-decision-gate`: the sanctioned heredoc
template's name); and one line `More: docs/harness-glossary.md — "<term>"`.
Total ≤ 70 words. The "self-authorized bypass" sentence stays, shortened.
The trigger logic does not change.

Acceptance criteria:
- AC7a.1 For each gate and each denial branch, the test feeds a canned
  payload, captures stderr and asserts `wc -w` ≤ 70, exit code 2 unchanged,
  and that it contains the remedy tokens above and the glossary term. The
  term must be present in `docs/harness-glossary.md` as a `**<term>**` line.
  `bash tests/reviewed-path-gate.test.sh` and
  `bash tests/human-decision-gate.test.sh` → exit 0. mutation: delete the
  remedy line → the token assertion fails.
- AC7a.2 Trigger logic unchanged:
  `git diff <baseline>..HEAD -- hooks/scripts/reviewed-path-gate.sh hooks/scripts/human-decision-gate.sh | grep -E '^[-+]' | grep -vE '^[-+]{3}' | grep -vE 'printf|echo|cat <<|^[-+]\s*#|^[-+]\s*$|^[-+][^$]*BLOCKED|^[-+]EOF' | wc -l`
  → `0`. Any residual line is listed in the packet for the reviewer.
- CC-gate.

### Step U7b — Corpus-first read-only allowlist families (item 7b)

Recommended model: sonnet (ratchet history on gate hardening). Sensitive:
yes (`hooks/`).
Depends on: U7a (shared test files).
Affected files: `scripts/gate-fp-harvest.py` (new: extracts PreToolUse-denied
Bash commands, tool_result `is_error` with `BLOCKED`, from the transcript store;
it replaces `$HOME` with `~`), `tests/fixtures/gate-fp-corpus/blocked.jsonl`
and `tests/fixtures/gate-fp-corpus/negative.jsonl` (new),
`docs/audits/2026-10-15-gate-fp-corpus.md` (classification table),
`hooks/scripts/lib/benign-command.sh`, its adapter copies
(`adapters/{codex,cursor}/hooks/scripts/lib/benign-command.sh`, byte-identical),
`tests/benign-command-families.test.sh` (new, isolated harness: sources the lib
and calls `command_is_provably_benign` directly) plus its registration in
`tests/validate.sh`, `CHANGELOG.md`.

**Frozen family table (the unit adds these and nothing else):**
- F1 a leading `cd <word>` segment joined by `&&` or `;`, where `<word>` has no
  metacharacter, `$`, backtick or glob, and the rest is itself benign;
- F2 the fd redirections `2>&1`, `2>/dev/null` and `>/dev/null` (no other
  redirect target);
- F3 programs `du`, `sort` (rejecting `-o`, `--output*` and any `-o` cluster),
  `uniq` (at most one operand, since a second operand is an output file),
  `cut`, `tr`, `nl`, `jq` (rejecting `-f`/`--from-file` when the next word is
  not a literal path, and any redirect not in F2).
Explicitly **not** added: `for`/`while` loops, `xargs`, `awk`, `sed`, `bash`
or `sh` execution, `git`, `rg`, command substitution.

**Frozen negative corpus** (each must stay blocked through every gate that
uses the lib): `sort -o x y`, `sort --output=x y`, `uniq a b`, `jq . f > g`,
`cd x && rm -f y`, `cd $(pwd) && ls`, `ls 2>x`, `cut -f1 f >> g`,
`du -sh . ; touch z`, `tr a b < f > g`, plus every existing bypass case
already in the three gates' test suites, which must stay green.

Acceptance criteria:
- AC7b.1 `bash tests/benign-command-families.test.sh` → exit 0. Every
  `negative.jsonl` line returns non-benign; every `blocked.jsonl` line the
  audit classifies as F1-F3-only now returns benign; every other
  `blocked.jsonl` line still returns non-benign. mutation: drop the `-o`
  rejection for `sort` → the `sort -o x y` case fails.
- AC7b.2 `grep -cE '^\| F[123] ' docs/audits/2026-10-15-gate-fp-corpus.md` → `3`,
  and the doc states the share of harvested blocks each family covers.
- AC7b.3 Lib copies identical:
  `cmp hooks/scripts/lib/benign-command.sh adapters/codex/hooks/scripts/lib/benign-command.sh && cmp hooks/scripts/lib/benign-command.sh adapters/cursor/hooks/scripts/lib/benign-command.sh`
  → exit 0.
- AC7b.4 `bash tests/reviewed-path-gate.test.sh`,
  `bash tests/human-decision-gate.test.sh` and
  `bash tests/harness-integrity-gate.test.sh` → exit 0 each.
- CC-gate.

### Step U11 — Implementer-tier evidence record (item 11)

Recommended model: haiku (scribe or spec-master, docs-only). Sensitive: no.
User ruling (2026-10-15): record the audit, change nothing.
Affected files: `docs/audits/2026-10-15-adr0040-forward-rule.md` (new).
Content: the export command, the audit command verbatim from ADR-0040, its
output (`met`, n=77 f1=6 f2=2 f6=0, the 13 guard demotions excluded), the
post-cutover all-units figure (6/90), and a per-path-class breakdown (units
touching `hooks/|agents/|templates/` vs the rest). The breakdown is computed
by joining the export's unit ids to commit paths, so a later sonnet-floor
proposal starts from data. No config, ADR or persona change.
Criteria: `grep -c '^met$' docs/audits/2026-10-15-adr0040-forward-rule.md` → `1`;
re-running the recorded commands reproduces the recorded counts (the doc
pins the export file's `--until` timestamp so the counts are stable).

### Step U12 — Drop `Agent` from lead-programmer (item 12)

Recommended model: haiku. Sensitive: yes (`agents/`).
Depends on: U5 (same file).
Affected files: `agents/lead-programmer.md` (the `tools:` line, and the
explorer bullets at ~34 and ~68-74 rewritten to: "You have no Agent tool.
Structural context comes in your dispatch's Pre-resolved context. When a
no-contract dispatch lacks the context you need, say exactly what is missing
in your report instead of guessing."), `adapters/codex/agents/lead-programmer.toml`
and `adapters/cursor/agents/lead-programmer.md` (tools and explorer
wording), `.claude/agents/lead-programmer.md` (regenerated),
`agents/orchestrator.md` (one sentence in "Delegation contract": for a
no-contract lead-programmer dispatch, spawn `explorer` first and paste its
distilled answer under Pre-resolved context), any test pinning
lead-programmer's tool list (find with `git grep -n 'lead-programmer' tests/ | grep -i tools`),
`.claude-plugin/plugin.json`, `CHANGELOG.md`.
The namespace duplication (bare + `antislop:` roster) is measured, not changed:
the after-measurement reports lead-programmer's first-turn median, and a
drop of ≥ 1.5K tokens attributable to the roster is recorded in the wave
audit.
Criteria: `sed -n '1,12p' agents/lead-programmer.md | grep -E '^tools:' | grep -c 'Agent'`
→ `0`; the same check on `.claude/agents/lead-programmer.md` → `0`;
`grep -c 'spawn .explorer. first' agents/orchestrator.md` ≥ 1; CC-P3,
CC-mirror, CC-parity, CC-gate.

## Parallelism and waves

### File map (✱ = sensitive, opus review)

| Unit | Affected files (abridged; full list in the step) | Gated? |
|---|---|---|
| U0 | `scripts/token-usage/*`, `tests/token-usage.test.sh`, fixtures, `docs/audits/…baseline.md`, ✱`tests/validate.sh` | yes |
| U1 | ✱`tests/validate.sh`, `tests/lib/validate-quiet.sh`, `tests/validate-quiet.test.sh`, `.github/workflows/validate.yml`, README, CHANGELOG | yes |
| U4a | 4× `MEMORY.md`, ≤ 4× `TECHNIQUES.md`, ≤ 4× `ARCHIVE.md` (agent-memory of lead-programmer, scribe, spec-master, task-master) | **no** (scribe, under a scribe contract) |
| U4b | `bin/agent-memory-size-check.sh`, its test | yes |
| U7c | ✱`agents/reviewer.md`, ✱mirror, reviewer ports, `tests/harness-integrity-gate.test.sh`, ✱plugin.json, CHANGELOG | yes |
| U6 | ✱`agents/reviewer.md`, ✱`templates/persona-protocol.md` (+3 surfaces), `tests/packet-view-script.test.sh`, ✱plugin.json, CHANGELOG | yes |
| U2 | `skills/ubiquitous-language/SKILL.md`, ✱`agents/scribe.md`, ✱mirror, `tests/glossary-index.test.sh`, ✱`tests/validate.sh`, ✱plugin.json, CHANGELOG | yes |
| U5 | ✱`templates/persona-protocol.md`, ✱`bin/cli.js`, ✱`agents/lead-programmer.md`, ✱all mirrors, protocol ports, parity tests, ✱plugin.json, CHANGELOG | yes |
| U3 | ✱`agents/{spec-master,task-master,orchestrator}.md`, ✱mirrors, orchestrator ports, contract-guard test, ✱plugin.json, CHANGELOG | yes |
| U8 | ✱`agents/{spec-master,task-master,orchestrator}.md`, ✱mirrors, ✱plugin.json, CHANGELOG | yes |
| U9 | `bin/ladder-tier.sh`, `bin/escalation-card.sh`, tests, ✱`tests/validate.sh`, ✱`agents/orchestrator.md`, ✱mirror, ✱plugin.json, CHANGELOG | yes |
| U7a | ✱`hooks/scripts/{reviewed-path,human-decision}-gate.sh`, gate tests, `docs/harness-glossary.md`, CHANGELOG | yes |
| U7b | ✱`hooks/scripts/lib/benign-command.sh` + ✱adapter copies, harvest script, corpus, audit doc, new test, ✱`tests/validate.sh`, CHANGELOG | yes |
| U11 | `docs/audits/…adr0040-forward-rule.md` | **no** (docs) |
| U12 | ✱`agents/lead-programmer.md`, lead-programmer ports, ✱`agents/orchestrator.md`, ✱plugin.json, CHANGELOG | yes |

### Disjointness

- **Dependent pairs (shared files, strict order):** U7c → U6 (`reviewer.md`);
  U6 → U5 (`persona-protocol.md`); U5 → U12 (`lead-programmer.md`);
  U3 → U8 (`task-master.md`, `spec-master.md`, `orchestrator.md`, and U8
  needs contract files); U8 → U9 (`orchestrator.md`); U12 also
  touches `orchestrator.md` and goes after U5 and before U3 (Wave 3); U7a → U7b (gate test files); U0, U2, U9, U7b all
  register in `tests/validate.sh` (one line each, rebase-trivial but still
  serial); U1 edits the `tests/validate.sh` wrapper and the others add
  registration lines in other regions, so their order is free (U0 may
  precede U1).
- **File-disjoint except for `plugin.json`/`CHANGELOG.md`:** U2 vs
  {U7c, U6}; U4b vs everything; U0 vs everything except its
  `tests/validate.sh` line; U7a/U7b vs all persona units.
- **Every agents/templates unit bumps `.claude-plugin/plugin.json`**, so any
  two of them conflict on the version line even when otherwise disjoint
  (P3 forbids batching the bumps).

### What can actually overlap

`reviewer-route-gate.sh` blocks dispatching a gated implementer unit while an
earlier unit has a standing pending-review flag, and `gatedAgents` is
`["lead-programmer"]`. So **no two gated units are ever implemented
concurrently**, worktrees or not. The pipeline is: implement A → review A →
implement B. What can overlap with a gated unit's implementation or review:
- **U4a** (scribe, not gated) can run alongside any gated unit, but only when
  no other agent is writing agent memory;
- **U11** (docs audit, not gated) can run at any time;
- **after-measurement runs** (U0's script, read-only).
To overlap gated units, the route gate would have to track pending reviews
per unit rather than refuse while any flag stands (the one-unit-at-a-time
invariant, ADR-0016/0028), and the per-commit version bumps would have to be
renumbered at merge. **Not proposed.** This plan does not weaken that gate.

### Recommended order

- **Wave 1 (minimal, fully reversible; Fable's first wave):** U1, U4a, U4b
  and U0. Within the wave, **U0 may precede U1** (ruling on task-master
  SPEC-GAP 3 for #546). The two touch different regions of
  `tests/validate.sh`: U1 the wrapper at lines 14-26, U0 one registration
  line. Each criterion passes on either order, and the route gate serializes
  them anyway. So the U0 → U1 edge is not required, and task-master may drop
  the native GitHub blocking edge and release U0. U4b can be dispatched now.
  U4a (ungated) can run while any gated unit is in review, provided no other
  agent is writing agent memory. U0 must land before Wave 1's
  after-measurement is read.
- **Wave 2 (reviewer and scribe bodies):** U7c → U6 → U2.
- **Wave 3 (protocol and lead-programmer):** U5 → U12 (U12 after U5 on
  `lead-programmer.md`, and before U3 on `orchestrator.md`).
- **Wave 4 (dispatch artifacts):** U3 → U8. Dispatch task-master for this
  plan one wave at a time from now on: that is U8's own rule, applied by hand
  before it lands.
- **Wave 5:** U9.
- **Wave 6 (gate surfaces, highest risk last):** U7a → U7b.
- **Any time (ungated):** U11.

Units: **15 dispatchable** (U0, U1, U2, U3, U4a, U4b, U5, U6, U7a, U7b,
U7c, U8, U9, U11, U12). Of these, 13 are gated lead-programmer units, and
U4a (scribe) and U11 (docs audit) are ungated. **That is ≥ 6, so this spec
goes to `task-master`** (standard path).

## Measurement and no-regression (pre-registered 2026-10-15)

**Instrument:** U0's `scripts/token-usage/agg.py --since <wave landing commit time>`.
A target is read only after it has the minimum sample: lead-programmer ≥ 20
dispatches, reviewer ≥ 20, scribe ≥ 10, spec-master ≥ 5, task-master ≥ 3.

| Persona | Metric | Baseline | Target | Expected from |
|---|---|---|---|---|
| lead-programmer | first-turn ctx median | 47.5K | ≤ 42K | U4a, U5, U12 |
| lead-programmer | cumulative median | 2.79M | ≤ 2.5M | U3, U5, U12 |
| reviewer | first-turn ctx median | 40.0K | ≤ 37K | U6, U7c |
| reviewer | cumulative median | 3.45M | ≤ 2.9M | U1, U3, U6, U7a/b |
| scribe | cumulative median | 1.48M | ≤ 1.0M | U2, U4a |
| spec-master | cumulative median | 12.0M | ≤ 8M | U1, U4a, U8 |
| task-master | cumulative median | 38.3M | ≤ 15M | U3, U8 |
| reviewer / spec-master | gate blocks per dispatch | 1.09 / 3.00 | ≤ 0.6 / ≤ 1.5 | U7a, U7b |

**No-regression rules** (checked at the milestone audit after each wave; a
breach sends that wave's units to a milestone-auditor review and becomes a
revert candidate, never an automatic revert):
- **NR1 FAIL rate:** over the first 20 units whose terminal timestamp falls
  after the wave lands (a fresh `scripts/unit-outcomes.js` export), the
  fail-rate is ≤ 0.15 and the escalation-rate ≤ 0.10. Baseline after the
  cutover: 6/90 = 0.067 and 2/90 = 0.022.
- **NR2 contract quality:** the guard-demotion rate over those units is
  ≤ 0.20 (baseline 13/90 = 0.14), and U3's AC3.1 equivalence holds.
- **NR3 per-unit:** each step's own mutation-proved criteria (the probe lists
  for U5/U6, set inclusion for U1, the frozen corpora for U7b).
- **NR4 target miss:** a persona whose target is missed by more than half the
  expected saving at the minimum sample is investigated before the next wave
  that targets the same persona.

## Version bump / CHANGELOG / validate.sh obligations

- Units touching `agents/*.md` or `templates/*` (U2, U3, U5, U6, U7c, U8, U9,
  U12): bump `.claude-plugin/plugin.json` and add a CHANGELOG entry **in
  each such commit** (constitution P3 v1.1.0, per commit). Run
  `node bin/cli.js --update` after the bump and commit the regenerated
  mirrors in the same commit.
- Units touching only `hooks/`, `tests/`, `bin/` (not cli.js) or `scripts/`
  (U0, U1, U4b, U7a, U7b): a CHANGELOG entry per repo convention. No bump is
  required by P3.
- Every new test is registered in `tests/validate.sh` (P5), and every unit
  ends on CC-gate.

## Out of scope

- Item 10 (user ruling 2026-10-15): no docs-only reviewer size class in
  `reviewer-tier.sh`, and no `effort:` change for spec-master.
- Item 11 beyond the audit record (user ruling 2026-10-15): no tier flip, no
  path-based sonnet floor, no ADR-0040 amendment.
- A context-meter hook (PostToolUse reading the agent's transcript usage):
  it needs a `hooks/hooks.json` registration, which is Set B and human only.
  Follow-up candidate if U8's work-size trigger misses its target.
- Collapsing the bare/`antislop:` agent namespace (install architecture).
- An env-conditional render of the agent-teams section (premise 5).
- Any change to reviewer effort or tier floors, `dispatchHygiene.mode`,
  `bashOutputMaxChars`, the route gate, or the Writer/Reviewer split.
- Shrinking orchestrator.md's 23 KB "Review routing" section. It is not one of
  the twelve items; it is the largest remaining main-session block and the
  next candidate.

## Open Questions

None. Round 1 (four questions, items 1, 10, 11 and 12) was answered on
2026-10-15; the answers are recorded in Clarifications.

## Self-check

- CHK1: Does every step carry at least one runnable criterion with an exit
  code or exact stdout? — PASS
- CHK2: Do U6 and U5 agree on who edits `templates/persona-protocol.md`
  first? — PASS (the dependent-pairs list and Wave 2/3 both put U6 first)
- CHK3: Is the reviewer tier for each unit stated, and do the ✱ marks agree
  with `reviewer-tier.sh`'s `SENSITIVE_PATHS`? — FAIL (conflicting): U4b was
  first marked sensitive although it no longer edits `tests/validate.sh` —
  revised in place
- CHK4: Is the U1 quiet/opt-in choice defined for both answers? — FAIL
  (missing) — converted to Open Question 4; answered 2026-10-15 (quiet by default), U1 revised
- CHK5: Is item 10's "spec-master effort medium for follow-ups" buildable as
  stated? — FAIL (conflicting with the effort-tier policy and the
  frontmatter-only fact) — converted to Open Question 2; answered 2026-10-15 (not built), U10 removed
- CHK6: Is the item 11 flip decided by the plan rather than the user? — FAIL
  (missing: a policy decision) — converted to Open Question 1; answered 2026-10-15 (record only), U11 revised
- CHK7: Is the no-contract explorer case for U12 defined? — FAIL (missing) —
  converted to Open Question 3; answered 2026-10-15 (drop), U12 unconditional
- CHK8: Do U3 and U8 agree on where task-master flushes its output? — PASS
  (both use `docs/plans/<slug>/contracts/<unit-id>.md`)
- CHK9: Is every Goal clause mapped to a step or an out-of-scope line ("not
  weakening" clauses included)? — PASS (Out of scope plus constitution check;
  U6 keeps the Writer/Reviewer text; U7b's negative corpus)
- CHK10: Is AC5.1's "only lead-programmer shrinks" check machine-checkable,
  given that moved lines can reorder? — FAIL (ambiguous) — revised in place
  (moved-line cancellation and a named-residual rule added)
- CHK11: Is U7b's scope bounded, so that a reviewer cannot demand "every
  bypass"? — PASS (frozen family table and frozen negative corpus)
- CHK12: Does any criterion spell `.claude/reviewed/` in Bash command text,
  which would trip `reviewed-path-gate.sh` for the reviewer? — PASS (AC9.2
  routes through `fail-count.sh` and the test, and U7c's command names only
  the persona config)
- CHK13: Do the after-measurement targets have a minimum sample and an
  owner? — PASS (minimum per persona; checked at the milestone audit)
- CHK14: Does the unit count match the step list? — PASS (15 step headings
  after U10's removal: U0, U1, U2, U3, U4a, U4b, U5, U6, U7a, U7b, U7c, U8,
  U9, U11, U12)
- CHK15: Replay source: does any `docs/audits/unit-outcomes/` vacuous/host
  unit's files intersect a criterion's `run:`? — PASS (directory not present
  at baseline; adds no item)
- CHK16: Can U1's AC1.2 bounds be met by U1's own filter? — FAIL
  (conflicting; task-master SPEC-GAP 1) — revised in place: filter frozen and
  simulated (102 lines / 13,050 B against bounds of 220 / 26,000)
- CHK17: Can every U4a persona meet the cap under the keep rule? — FAIL
  (conflicting; SPEC-GAP 2a) — revised in place: feedback-only keep rule,
  `TECHNIQUES.md`, hook shortening
- CHK18: Is U4a's governing text (contract vs prune duty) defined? — FAIL
  (missing; SPEC-GAP 2b) — revised in place: the contract governs
- CHK19: Do U4a's criteria compare against the right baseline, given that
  memory indexes change after the plan baseline? — FAIL (conflicting) —
  revised in place: `<pre>` is the parent of U4a's commit


## Scribe update hint

At landing, not now:
- CONTEXT.md: amend **contract of record** (its home is a contract file); add
  **contract file**; add **dispatch checkpoint** (a `STATUS: incomplete —
  checkpoint: <path>` turn-end, distinct from the WIP sentinel).
- `docs/harness-glossary.md`: **quiet mode** (validate.sh), the two denial
  anchor terms U7a adds, and the F1-F3 **read-only families**.
- Number and land the draft ADR in Context (contract files). Do not reuse the
  0007 hole: re-derive the next ADR number at landing time.
- Record U11's audit in ADR-0040's history line (user ruling: record, no change).

## Publication

Published 2026-10-15 as GitHub issue #542 (`[spec] Persona token reduction
(15 units)`, label `ready-for-agent`), a PRD mapped from this document. This
file stays the canonical artifact; where the two differ, this file wins.

**Retrieval contract (for task-master):** the spec is
`docs/plans/2026-10-15-persona-token-reduction.md` at the commit that marks it
FINAL; the umbrella PRD is issue #542 (`gh issue view 542`). task-master
slices it into per-step issues under label `plan/persona-token-reduction`
(fetch with `gh issue list --label plan/persona-token-reduction`), one wave
(5 or fewer units) per task-master dispatch, in the order given in
"Recommended order".

**Dispatch contracts (task-master).** Contract files live under
`docs/plans/2026-10-15-persona-token-reduction/contracts/`. Wave 5 split U9 in
two, because its new-file payloads exceed the 30000-byte contract budget:
- U9 part 1 (scripts, test, registration): [ptr-u9a](2026-10-15-persona-token-reduction/contracts/ptr-u9a.md), issue #559.
- U9 part 2 (orchestrator routing section, version 0.31.179): [ptr-u9b](2026-10-15-persona-token-reduction/contracts/ptr-u9b.md), issue #560.
- Wave 6, U7a part 1 (scribe contract, dispatch FIRST; lands the two glossary terms the lead contract reads): [ptr-u7a.scribe](2026-10-15-persona-token-reduction/contracts/ptr-u7a.scribe.md), issue #561.
- Wave 6, U7a part 2 (lead contract, dispatched after the scribe contract; no version bump): [ptr-u7a](2026-10-15-persona-token-reduction/contracts/ptr-u7a.md), issue #561.
- Wave 6, U7b: issue #562 is HELD on a spec gap (classification rule, reproducible corpus, privacy); it has no contract file, see the issue body for the gap and a proposed ruling.
