# Persona token reduction: twelve changes to the heavyweight personas

Status: **FINAL** (2026-10-15). Open Questions round 1 (four questions) was
answered by the user via AskUserQuestion on 2026-10-15, taking the
recommended option each time; the answers are in Clarifications. Item 10 is
not built (no U10), item 11 is an audit record only (U11), item 12 is in
(U12), and validate.sh is quiet by default (U1).
Revised 2026-10-16 (append-only): ruling H-U7B splits U7b into U7b-1 and
U7b-2, and Wave 7 adds the cleanup units U13a-U13c (19 units in total).
Revised again 2026-10-16 (rulings H-U7B1, H-U7B2, H-U13C on task-master's
SPEC-GAPs #562/#563 and a U7a review finding): U7b-1 drops the adapter lib
copies and replaces the `sort` denylist with option allowlists (20 frozen
negatives); U7b-2's real-store harvest becomes human step H7b2; U13c gains
edit 6 (protocol refusal-text sentence). Still 19 units.
Revised a third time 2026-10-16 (ruling H-U7B3 on task-master's second
SPEC-GAP in #562): U7b-1 also edits two existing gate-test pins that F1/F3
correctly free (`[U7c]` cd-prefix control, `OB-10`), each replaced by a
still-refused pin; F1 is accepted at segment level. OQ2 answered (a): the
user will run H7b2. Still 19 units.
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
12. **Item 7b, F2 already exists (measured 2026-10-16, ruling H-U7B).**
    `mask_inert_redirections` (`hooks/scripts/lib/benign-command.sh` ~140-168)
    already masks `2>&1`, `2>/dev/null` and `>/dev/null`. Sourcing the lib at
    HEAD `adb9795` and calling `command_is_provably_benign`: `ls 2>&1`,
    `grep -c x f 2>/dev/null`, `wc -l f >/dev/null` and `ls 2>&1 | head -5`
    return benign. `cd /tmp && ls`, `du -sh .`, `sort f`, `cut -d: -f1 f`,
    `tr a b < f`, `nl f`, `jq .a f.json` and `uniq -c f` return non-benign.
    Every frozen negative returns non-benign. So F1 and F3 are the only new
    families, and F2 gets regression pins only (U7b-1). This spec-master
    session was itself blocked twice by exactly F1 (`cd <repo>; …`) and F3
    (`… | cut`) shapes.

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
4. Non-functional attributes (perf, security, scale): Partial
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
- 2026-10-16 Completion / acceptance signals: Q (task-master SPEC-GAP, #562
  HELD) Who or what classifies a harvested blocked command as "F1-F3-only"
  for AC7b.1? → A (self-resolved, ruling H-U7B): nobody does, for the lib
  unit. U7b-1's criteria read only frozen, hand-written files (a positive set
  and the negative corpus, both listed literally in the step), so the input
  is not circular. In U7b-2 the classifier is the lib itself: a harvested
  command is **flipped** when the pre-U7b-1 lib returns non-benign and the
  post-U7b-1 lib returns benign. Family attribution is a fixed syntactic rule
  (see U7b-2), not a second classifier, and a command may count in more than
  one family.
- 2026-10-16 Domain entities / data model: Q What is the harvested corpus:
  window, cap, dedupe and denominator? → A (self-resolved, H-U7B): this
  repository's transcript-store project directory only, the window
  `[2026-09-25T00:00:00Z, 2026-10-16T00:00:00Z)` on the Bash tool_use
  timestamp, deduplicated to distinct exact command strings, commands over
  4,096 characters counted in an `oversize` row and not classified. The
  denominator for every share is distinct in-window commands that are not
  oversize.
- 2026-10-16 Non-functional attributes (security/privacy): Q May raw
  harvested commands be committed? → A (self-resolved default, H-U7B): no. The
  dispatcher's instruction defaults to not committing raw private commands,
  and that is the conservative choice. Committed artifacts hold aggregate
  counts and the hand-written examples of U7b-1 only, and U7b-2 proves this
  with a sentinel fixture and a `--check-doc` leak count. `blocked.jsonl` is
  dropped. A user override is Open Question 1 (non-blocking).
- 2026-10-16 Edge cases / failure handling: Q (wave-1-6 reviewer
  follow-up d) Is a missing `--contract` (`reason=no-contract`) a guard
  demotion? → A (self-resolved): yes. CONTEXT.md **guard demotion** already
  counts "no contract block was found" as a guard demotion that "gets a line
  in the Rulings ledger", so the orchestrator prose is the drift and U13b
  fixes the prose to match the glossary. The script stays as is.
- 2026-10-16 User interaction flow: Q (follow-up g) spec-master checkpoint
  (3) fires only for specs over 5 steps, but it sits before the fast path's
  contracts, and the fast path only runs for 5 or fewer units, so it can
  never fire. How do these reconcile? → A (self-resolved): checkpoint (2)
  keeps its step-count trigger (it bounds plan-writing). Checkpoint (3)
  becomes the task-master rule applied to the fast path: write and commit
  each contract file as it is finished, and after every 3 contract files in
  one spawn, with contracts remaining, end with
  `STATUS: incomplete — checkpoint: <plan path>`. The plan's dispatch
  section links show what is done. A re-dispatch is progress only if the
  cited path has a newer commit than at the previous checkpoint (U13b).
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
- 2026-10-16 External dependencies & integrations: Q (SPEC-GAP #562) U7b-1
  names adapter copies of `benign-command.sh`, but `bin/cli.js:671` declares
  the lib `CLAUDE_ONLY_HOOK_LIB_FILES` and no adapter copy ever existed. Create
  them, or drop them? → A (self-resolved, H-U7B1): drop them. Creating them
  would reclassify the lib, a design change outside this plan. The only copy
  is the `.claude/hooks/scripts/lib/` mirror that `node bin/cli.js --update`
  refreshes, and AC7b1.3 now compares against that.
- 2026-10-16 Edge cases / failure handling: Q (SPEC-GAP #562) The frozen
  `sort` rule ("rejecting `--output*`") lets `sort --ou=x y` write `x`
  (getopt_long abbreviation, measured with coreutils 9.4), and
  `--compress-program`, `-T`, quoted, brace and glob option words, `$`
  expansions and uniq's `--` all get past a word denylist. Patch the
  denylist or switch to an allowlist? → A (self-resolved, H-U7B1): switch
  `sort` and `uniq` to frozen option allowlists (exact long names, never
  prefixes), ban quote, `$`, brace and glob characters in their segments,
  require uniq options before its single operand, and add 10 frozen
  negatives (20 in total). This follows the lib's own rule that a denylist
  fails open (`benign-command.sh:9-27`). `du`, `cut`, `tr`, `nl` and `jq` need
  no option rule: none of their options writes a file or runs a program
  (checked against `--help` for coreutils 9.4 and jq 1.8.2). `cd` takes only
  `-L -P -e -@`, so F1 gets the same banned-character word rule and no new
  negative. AC7b1.2 stays at 13, because the positives are unchanged and every
  new negative is already non-benign on the old lib (it allowlists neither
  `sort` nor `uniq`).
- 2026-10-16 Completion / acceptance signals: Q (SPEC-GAP #563) Who produces
  the real-store numbers for AC7b2.3-5, given that the environment refuses to
  let an agent read private session transcripts? → A (self-resolved,
  H-U7B2): the user, in their own terminal, as human step H7b2 after U7b-2
  PASS. The lead builds the script (with a new `--fill-doc` mode), its test,
  the fixtures, the registration and a doc skeleton whose marker span is a
  PENDING line. AC7b2.3-5 move out of the lead's contract and into H7b2.
  U7b-2's PASS certifies only the synthetic-store behaviour and the skeleton.
- 2026-10-16 Terminology consistency: Q (U7a reviewer finding) The protocol
  says both gates "print their complete remediation"; after U7a they print a
  short remedy plus a `More:` pointer to a glossary entry. → A
  (self-resolved, H-U13C): U13c edit 6 rewords the sentence and pins the old
  wording out.
- 2026-10-16 Edge cases / failure handling: Q (second SPEC-GAP, #562) Two
  existing pins expect a refusal for commands that a correct F1/F3 makes
  benign: the `[U7c]` negative control `cd /tmp; <reviewer jq read>` in
  `tests/harness-integrity-gate.test.sh`, and `OB-10` (`grep … | cut -c1-220`)
  in `tests/human-decision-gate.test.sh`. Drop them, or replace them? → A
  (self-resolved, H-U7B3): neither pin is deleted. Each freed command becomes
  an `allowed` pin (it documents the narrowing), and each gets a still-refused
  companion of equal strength, measured refused under an F1/F3 superset lib:
  `touch /tmp/u7c-armed; <jq read>` and `cd /tmp; touch u7c-armed; <jq read>`
  for U7c, and OB-10's command with `cut -c1-220` replaced by
  `tee /tmp/ob15.out` as new pin OB-15. U7b-1 gains the two test files.
- 2026-10-16 Technical constraints & tradeoffs: Q (second SPEC-GAP, #562) F1
  as implemented allows a `cd <word>` segment anywhere (`ls && cd docs`,
  `cd x | ls`), wider than the frozen "leading segment joined by `&&` or `;`".
  Accept, or constrain? → A (self-resolved, H-U7B3): accept. `cd` writes no
  file and runs no program, every other segment must still be benign, and a
  benign command is read-only wherever its cwd is. The two-word and
  banned-character rules of H-U7B1 still apply. New criterion AC7b1.6 pins it.
- 2026-10-16 User interaction flow: Q (OQ2) Will the user run human step H7b2
  after U7b-2 PASS? → A: (a) yes, per user (relayed by the orchestrator).

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
  `lib/benign-command.sh` must stay byte-identical. (Corrected 2026-10-16,
  H-U7B1: no adapter copy exists; the lib is `CLAUDE_ONLY_HOOK_LIB_FILES`, and
  its only copy is the `.claude/` mirror refreshed by `node bin/cli.js
  --update`.) Accepted residuals, not in U7b-1's scope: `TMPDIR` (out-of-band
  environment) can make `sort` put its temporary files, which it deletes, in
  another directory; and the already-allowlisted `file` has `-C`, which writes
  a compiled `.mgc` magic file (a follow-up candidate for the existing
  `program_allowed` list, not a U7b-1 item).
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

**Superseded 2026-10-16 by U7b-1 and U7b-2 (ruling H-U7B).** Kept below
unedited, as history. Do not slice or dispatch this step: its AC7b.1 and
AC7b.2 have no classifier and no committable corpus (task-master
SPEC-GAP, issue #562), and F2 already exists (premise 12).

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

### Step U7b-1 — Add read-only families F1 and F3 to the benign-command lib (item 7b, ruling H-U7B)

Recommended model: sonnet (ratchet history on gate hardening). Sensitive:
yes (`hooks/`, `tests/validate.sh`).
Depends on: U7a (shared gate test files, which it runs and does not edit).
(Revised by H-U7B3: U7b-1 now edits two pins in
`tests/harness-integrity-gate.test.sh` and `tests/human-decision-gate.test.sh`;
U7a and U7c have PASSed, so the order is unchanged.)
Affected files: `hooks/scripts/lib/benign-command.sh` and its mirror
`.claude/hooks/scripts/lib/benign-command.sh` (refreshed by
`node bin/cli.js --update`, never hand-edited; revised by H-U7B1: the lib is
`CLAUDE_ONLY_HOOK_LIB_FILES` in `bin/cli.js:671`, so no adapter copy exists
and none is created),
`tests/fixtures/gate-fp-corpus/positive.jsonl` (new),
`tests/fixtures/gate-fp-corpus/negative.jsonl` (new),
`tests/benign-command-families.test.sh` (new) plus one registration in
`tests/validate.sh`, and `CHANGELOG.md`. No version bump is needed (P3 covers
only `agents/` and `templates/`).
Not in this unit: any harvest script, `blocked.jsonl`, or audit doc (see
U7b-2). Nothing harvested from a transcript store is read or committed.

**Families (frozen; the U7b table with F2 corrected by premise 12):** add F1
(a leading `cd <word>` segment joined by `&&` or `;`, where `<word>` has no
metacharacter, `$`, backtick or glob, and the rest is itself benign) and F3
(`du`, `sort` rejecting `-o`, `--output*` and any `-o` cluster, `uniq` with at
most one operand, `cut`, `tr`, `nl`, and `jq` rejecting `-f`/`--from-file`
when the next word is not a literal path). F2 (`2>&1`, `2>/dev/null`,
`>/dev/null`) already exists in `mask_inert_redirections`: do not change it,
only pin it. The "explicitly not added" list of U7b stands unchanged.

**Family rules, sharpened (ruling H-U7B1, 2026-10-16; these replace the
`sort`/`uniq` clauses above and govern where the two differ).** The `sort`
and `uniq` rules become allowlists, because a word denylist fails open
(`sort --ou=x y` writes `x` through getopt_long abbreviation, measured), which
is the lib's own reason for being allowlist-shaped (`benign-command.sh:9-27`).
- **Banned characters.** The real text of a `sort` or `uniq` segment contains
  none of `'` `"` `$` `{` `}` `*` `?` `[` `]`. Quoted, expanded, brace and glob
  words can turn into option words that a word scan never sees. The F1 `cd`
  word also contains none of them (in addition to whitespace, `;&|<>()` and
  backtick), and its segment is exactly two words.
- **Option allowlists.** In a `sort` or `uniq` segment, every word that starts
  with `-` must match the program's list below. Anything else is non-benign,
  including the bare `--`, any abbreviation, and any option not listed. Long
  options match the whole name exactly, never a prefix.
  - `sort`: a single-dash cluster of characters from `bdfghiMnRrsuVcCz`;
    `-k<keydef>`, `-k <keydef>` or `--key=<keydef>`, where `<keydef>` matches
    `^[0-9]+(\.[0-9]+)?[bdfghiMnRrV]*(,[0-9]+(\.[0-9]+)?[bdfghiMnRrV]*)?$`;
    `-t<c>`, `-t <c>` or `--field-separator=<c>`, where `<c>` is exactly one
    character other than a banned one or whitespace; and the long options
    `--reverse --unique --numeric-sort --general-numeric-sort
    --human-numeric-sort --version-sort --month-sort --random-sort
    --ignore-case --ignore-leading-blanks --dictionary-order
    --ignore-nonprinting --stable --check --zero-terminated`. So `-o`,
    `--output`, `-T`, `--temporary-directory`, `--compress-program` (runs a
    program) and every abbreviation of them are non-benign.
  - `uniq`: a single-dash cluster of characters from `cdDiuz`; `-f`, `-s` and
    `-w` followed by digits in the same word or the next one; and the long
    options `--count --repeated --unique --ignore-case --zero-terminated`, plus
    `--skip-fields=<digits>`, `--skip-chars=<digits>` and
    `--check-chars=<digits>`. At most one operand, and no word starting with
    `-` after it (with `POSIXLY_CORRECT` set such a word is a second operand,
    and a second operand is an output file).
- `du`, `cut`, `tr`, `nl` and `jq` get no option rule beyond jq's frozen `-f`
  clause. None of their options writes a file or runs a program (checked
  2026-10-16 against `--help` of GNU coreutils 9.4 and jq 1.8.2), so
  abbreviations and quoting cannot reach a writer. The generic checks still
  apply to them: no `>` other than F2, no substitution, and every segment
  allowlisted.

**Frozen test data.** Each line of the two files is one JSON object.
`positive.jsonl` holds exactly these 16 objects `{"family":"<F>","cmd":"<cmd>"}`:
- F1: `cd /tmp && ls` · `cd docs; wc -l README.md` · `cd hooks && grep -c x f 2>/dev/null`
- F2: `ls 2>&1 | head -5` · `grep -c x f 2>/dev/null` · `wc -l f >/dev/null`
- F3: `du -sh .` · `sort f` · `grep x f | sort | uniq -c` · `cut -d: -f1 f` ·
  `tr a b < f` · `nl f` · `jq .a f.json` · `jq -r .a f.json 2>/dev/null` ·
  `sort -u f | uniq` · `uniq -c f`

`negative.jsonl` holds exactly the ten frozen negatives of U7b as
`{"cmd":"<cmd>"}` objects: `sort -o x y`, `sort --output=x y`, `uniq a b`,
`jq . f > g`, `cd x && rm -f y`, `cd $(pwd) && ls`, `ls 2>x`,
`cut -f1 f >> g`, `du -sh . ; touch z`, `tr a b < f > g`. The gates' existing
bypass cases are not copied into the file. AC7b1.4 covers them by running
their suites.
**Revised by H-U7B1: `negative.jsonl` holds exactly 20 objects**, the ten above
followed by these ten, in this order: `sort --ou=x y`,
`sort --compress-program=sh y`, `sort -T d y`, `sort -uo x y`,
`sort '-o' x y`, `sort -{o,x} y`, `sort -[o] x y`, `sort $O x y`,
`uniq -- -c b`, `uniq f -c`. `positive.jsonl` is unchanged (16 objects).

**Test shape.** `tests/benign-command-families.test.sh` sources the lib named
by `$BENIGN_LIB` (default `hooks/scripts/lib/benign-command.sh`) and calls
`command_is_provably_benign` directly for every line, passing the command as
an argument and never through `eval`. It prints one line per case,
`ok|FAIL <positive|negative> <family|-> <cmd>`, and exits 0 only when there
are no `FAIL` lines. A positive case passes when the command is benign, and a
negative case passes when it is not.

Acceptance criteria:
- AC7b1.1 `bash tests/benign-command-families.test.sh` → exit 0;
  `bash tests/benign-command-families.test.sh | grep -c '^ok positive '` → `16`
  and `... | grep -c '^ok negative '` → `10`. mutation: drop the `sort -o`
  rejection → a `FAIL negative - sort -o x y` line, exit 1.
  **Revised by H-U7B1:** the negative count is `20`
  (`... | grep -c '^ok negative '` → `20`). Mutations, each run on its own
  against the finished lib, and each must give exit 1 with the named line:
  (a) add `o` to `sort`'s short-option characters →
  `FAIL negative - sort -o x y`; (b) replace `sort`'s long-option allowlist
  with the old denylist (reject `--output*`, accept every other `--` word) →
  `FAIL negative - sort --ou=x y`; (c) drop the banned-character check →
  `FAIL negative - sort '-o' x y`; (d) drop uniq's options-before-operand
  rule → `FAIL negative - uniq f -c`.
- AC7b1.2 (the families are new; this proves every F1/F3 positive
  non-vacuous) with `<pre>` = the parent of U7b-1's first commit:
  `t="$(mktemp)"; git show <pre>:hooks/scripts/lib/benign-command.sh > "$t"; BENIGN_LIB="$t" bash tests/benign-command-families.test.sh`
  → exit 1. Its stdout has exactly 13 lines matching `^FAIL positive F[13] `
  and exactly 13 lines matching `^FAIL ` (F2 positives and all negatives pass
  on the old lib; measured on HEAD `adb9795`, premise 12). Unchanged by
  H-U7B1 (still 13 = 3 F1 + 10 F3): the positives are unchanged, and all ten
  new negatives are non-benign on the old lib, which allowlists neither `sort`
  nor `uniq`.
- AC7b1.3 (replaced by H-U7B1; the old adapter `cmp` can never pass)
  `cmp hooks/scripts/lib/benign-command.sh .claude/hooks/scripts/lib/benign-command.sh`
  → exit 0, and
  `git ls-files adapters/codex/hooks/scripts/lib/benign-command.sh adapters/cursor/hooks/scripts/lib/benign-command.sh | wc -l`
  → `0`. mutation: skip `node bin/cli.js --update` after the lib edit → `cmp`
  exits 1.
- AC7b1.4 `bash tests/reviewed-path-gate.test.sh`,
  `bash tests/human-decision-gate.test.sh` and
  `bash tests/harness-integrity-gate.test.sh` → exit 0 each.
- AC7b1.5 `grep -c 'tests/benign-command-families.test.sh' tests/validate.sh` ≥ 1.
- CC-gate.

**Ruling H-U7B3 (2026-10-16; task-master's second SPEC-GAP in #562).** Two
existing pins expect a refusal for a command that a correct F1/F3 makes
benign, so AC7b1.4 and CC-gate cannot pass as the plan stood. Measured in a
scratch clone of `b1f013b` with a **superset** lib (`program_allowed` given
`cd|du|sort|uniq|cut|tr|nl|jq` with any arguments, which contains every
command the real F1/F3 allows): across all 17 test files that name the lib
or one of its three consuming gates (`harness-integrity-gate.sh`,
`human-decision-gate.sh`, `reviewed-path-gate.sh` are its only consumers),
exactly these two checks fail, and all five suites pass on the unpatched
clone. No third pin exists. A literal grep of the three gate suites for the
eight programs in refusal-expecting lines found nothing more.
- **Affected files (added):** `tests/harness-integrity-gate.test.sh` and
  `tests/human-decision-gate.test.sh`. Only the two edits below; nothing else
  in either file changes.
- **Edit A, `[U7c]` in `tests/harness-integrity-gate.test.sh`.** The
  `cd /tmp; $u7c_cmd` check flips to expect exit 0, with pass label
  `[U7c] harness-integrity-gate allows the cd-prefixed form (F1+F3, U7b-1)`.
  Two negative controls are added, each expecting exit 2, built from the same
  extracted `$u7c_cmd`: `touch /tmp/u7c-armed; $u7c_cmd` (pass label
  `[U7c] harness-integrity-gate refuses the touch-prefixed compound form`) and
  `cd /tmp; touch u7c-armed; $u7c_cmd` (pass label
  `[U7c] harness-integrity-gate refuses the cd-then-touch compound form`).
  The first keeps the old control's job (the gate is armed, and the jq
  carve-out never covers a compound); the second proves an F1 prefix does
  not launder a non-benign segment. Why they are refused, from the source:
  `touch` is in no allowlist before or after U7b-1, so
  `command_is_provably_benign` returns 1; `is_benign_jq_read` returns 1 on
  the `;` in the skeleton; `set_a_mentioned` is true (the command names the
  persona config), so the gate reaches `deny A` (`harness-integrity-gate.sh`
  lines 288-295). Measured: exit 2 for both, on the current lib and on the
  superset lib. Update the comment above the control to match.
- **Edit B, OB block in `tests/human-decision-gate.test.sh`.** The OB rows
  are accepted **over-blocks** (real read-only commands that write nothing
  protected), not bypass attempts, and the block's own comment says a
  narrowing that frees one "shows up here". So OB-10 is not deleted and not
  renumbered: it stays at index 10 and is pinned `allowed`, reason text
  `freed by F3 (U7b-1): the cut segment is now provably benign`. What OB-10
  carried as a blocking pin (an unquoted `adapters/*/rules/*` glob that can
  name both tokens, plus one non-benign segment, is refused) moves to new pin
  **OB-15**, pinned `blocked`: OB-10's exact command with its trailing
  ` | cut -c1-220` replaced by ` | tee /tmp/ob15.out`, reason text
  `OB-10's shape with cut replaced by tee: unquoted adapters/*/rules/* can name both tokens; the tee segment is not provably benign`.
  Measured: OB-15 is refused (rc 2) on the current lib and on the superset
  lib. How the loop learns OB-10's expectation is the lead's choice (for
  example a parallel `ob_expect` array); the observable output is frozen by
  AC7b1.8. The section header becomes `(OB-1..OB-15)`, and its comment notes
  that OB-10 is pinned `allowed` since U7b-1 and that OB-15 is derived, not
  from the sweep corpus.
- **F1 at segment level is accepted.** A segment that is exactly `cd <word>`
  (two words, H-U7B1's banned characters absent) is benign in any position
  and after any separator, not only as a leading `&&`/`;` prefix. This
  amends the frozen F1 wording above. Reason: `cd` writes no file and runs no
  program, every other segment must still be benign, and a benign command is
  read-only wherever its working directory is.
- **Unchanged:** `positive.jsonl` (16) and `negative.jsonl` (20), so
  AC7b1.1's counts (16 and 20) and AC7b1.2's 13 stand; AC7b1.3-AC7b1.5 and
  CC-gate stand.
- **Trap (pre-resolved context for the contract).** The C4.1 sweep in
  `tests/harness-integrity-gate.test.sh` (pattern at its line 1312) fails
  CC-gate if any newly hit-bearing file appears. No file U7b-1 creates or
  edits outside that test's own table may contain any of the four phrases in
  `c41_pattern` (read them there; this plan does not spell them, so that it
  stays out of the sweep itself). CC-gate's `[C4.1a]` lines enforce it.

Added acceptance criteria (H-U7B3), each run against the finished lib:
- AC7b1.6 (F1 at segment level)
  `bash -c '. hooks/scripts/lib/benign-command.sh; command_is_provably_benign "ls && cd docs" && command_is_provably_benign "cd docs | wc -l f" && ! command_is_provably_benign "cd a b && ls" && ! command_is_provably_benign "cd && ls" && ! command_is_provably_benign "ls; cd docs; touch z"'`
  → exit 0. It exits 1 against the `<pre>` lib of AC7b1.2 (no F1).
  mutations, each on its own → exit 1: (e) allow `cd` only in the first
  segment; (f) drop the two-word rule for the `cd` segment.
- AC7b1.7 (`[U7c]` pins)
  `bash tests/harness-integrity-gate.test.sh | grep -cE '^OK +\[U7c\] harness-integrity-gate (allows the cd-prefixed form \(F1\+F3, U7b-1\)|refuses the touch-prefixed compound form|refuses the cd-then-touch compound form)$'`
  → `3`. Fails closed: a missing or reworded label, or a control that is not
  refused, lowers the count. mutation: add `touch` to `program_allowed` in the
  lib → count `1`, and the suite exits 1.
- AC7b1.8 (OB pins)
  `bash tests/human-decision-gate.test.sh | grep -cE '^OK +OB-([1-9]|1[0-5]) .* -> blocked$'`
  → `14`; `... | grep -cE '^OK +OB-10 .* -> allowed$'` → `1`;
  `... | grep -c '^FAIL OB-'` → `0`. mutation: add `tee` to `program_allowed`
  in the lib → the `blocked` count is `13`, a `FAIL OB-15` line appears, and
  the suite exits 1.

### Step U7b-2 — Measure the families' share of real gate blocks, aggregates only (item 7b, ruling H-U7B)

Recommended model: sonnet. Sensitive: yes (`tests/validate.sh`).
Depends on: U7b-1 (it compares the libs before and after U7b-1).
Affected files: `scripts/gate-fp-harvest.py` (new),
`tests/gate-fp-harvest.test.sh` (new) plus one registration in
`tests/validate.sh`, `tests/fixtures/gate-fp-harvest/**` (new, synthetic
only), `docs/audits/2026-10-15-gate-fp-corpus.md` (new, filename kept from
U7b), `CHANGELOG.md`.

**Privacy rule (default, Clarifications 2026-10-16; OQ1 may override).** No
harvested command text is committed anywhere: not in the doc, not in
fixtures, not in a commit message. The script has **no** mode or flag that
prints a command; its only outputs are counts. Fixtures are synthetic. Any
example in the doc is copied from U7b-1's `positive.jsonl`/`negative.jsonl`.

**Script contract.**
`python3 -I scripts/gate-fp-harvest.py [--root <dir>] --since <iso> --until <iso> --lib <path> --baseline-lib <path> [--check-doc <path>]`.
- Root: `--root`, defaulting to `~/.claude/projects/<cwd with every / replaced by ->`
  (this repository's project directory only). Files read: `<root>/*.jsonl`
  and `<root>/*/subagents/*.jsonl`.
- **Hit:** a `Bash` tool_use whose paired tool_result (same `tool_use_id`)
  has `is_error: true` and content containing `BLOCKED`, with the tool_use
  record's `timestamp` in `[since, until)`.
- **Gate:** the first of `reviewed-path-gate`, `human-decision-gate` and
  `harness-integrity-gate` found in the result text, else `other`.
- **Dedupe and cap:** distinct exact command strings. A command over 4,096
  characters is counted as `oversize` and not classified. D (the denominator)
  is the number of distinct commands that are not oversize.
- **Classifier = the lib:** each counted command goes to a `bash` subprocess
  that sources the lib and calls `command_is_provably_benign "$1"` with the
  command as an argument. **flipped** means non-benign under `--baseline-lib`
  and benign under `--lib`.
- **Family attribution of flipped commands (frozen syntactic rule; a command
  may count in several families):** F1 if it matches
  `^\s*cd\s+[^\s;&|$`*?\[]+\s*(&&|;)`; F2 if it contains `2>&1`,
  `2>/dev/null` or `>/dev/null`; F3 if any segment (split on `|`, `;`, `&&`
  and `||`) starts with one of `du sort uniq cut tr nl jq`.
- **stdout** is exactly one markdown table, header `| row | count | share |`,
  with these rows in this order: `hits`, `distinct`, `oversize`, `classified`
  (= D), `F1`, `F2`, `F3`, `flipped`, `still-blocked`, then one `gate:<name>`
  row per gate (hit counts). share is count/D to 3 decimals for the
  F rows, flipped and still-blocked, and `-` otherwise.
- `--check-doc <path>` prints exactly one line, `leaks=<n>`: the number of
  distinct in-window commands of 20 characters or more that occur verbatim in
  the file. It never prints which ones.

**Audit doc.** It records the exact command line run (window
`--since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z`, `--lib` = the
working-tree lib, `--baseline-lib` = the `<pre>` lib of AC7b1.2 extracted to
a temp file, with the extraction command written out), the commit both
were taken at, and the script's stdout verbatim between
`<!-- harvest:begin -->` and `<!-- harvest:end -->`. It also states that
reproduction is per-machine and best-effort (the store is local and
transcript cleanup can delete in-window sessions). (Revised by H-U7B2 below:
both libs are extracted from fixed commits, `--lib` included, and the
user fills the marker span in human step H7b2; the lead writes the skeleton.)

Acceptance criteria:
- AC7b2.1 `bash tests/gate-fp-harvest.test.sh` → exit 0. The synthetic store
  holds: two identical blocked hits, one out-of-window hit, one
  `is_error: false` result containing `BLOCKED`, one `is_error: true` result
  without `BLOCKED`, one oversize command, one F1 flip, one F3 flip, one
  still-blocked `rm -f x`, and one blocked command containing
  `ZZ-PRIVATE-SENTINEL-42`. Two stub libs under the fixture dir define
  `command_is_provably_benign` deterministically. The test asserts the
  literal expected table, asserts that `ZZ-PRIVATE-SENTINEL-42` appears in no
  output, and asserts that `--check-doc` prints `leaks=1` on a fixture doc
  holding the sentinel command and `leaks=0` on a clean one. mutation: remove
  the dedupe → the `distinct` row changes, exit 1.
- AC7b2.2 `grep -c 'tests/gate-fp-harvest.test.sh' tests/validate.sh` ≥ 1.
- AC7b2.3 `grep -cE '^\| F[123] \|' docs/audits/2026-10-15-gate-fp-corpus.md`
  → `3`; `grep -c 'harvest:begin' docs/audits/2026-10-15-gate-fp-corpus.md`
  → `1`; `grep -c -- '--since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z' docs/audits/2026-10-15-gate-fp-corpus.md`
  ≥ 1.
- AC7b2.4 (privacy, on the measuring machine) the recorded command with
  `--check-doc docs/audits/2026-10-15-gate-fp-corpus.md` appended → stdout
  `leaks=0`.
- AC7b2.5 (reproduction, on the measuring machine) re-running the recorded
  command and `diff`-ing its stdout against the lines between the doc's
  harvest markers → exit 0.
- AC7b2.6 `git ls-files tests/fixtures/gate-fp-corpus/blocked.jsonl | wc -l` → `0`.
- CC-gate.

**Ruling H-U7B2 (2026-10-16; task-master SPEC-GAP #563).** An agent cannot read
the real transcript store here (the environment refuses private session
transcripts), so the real harvest is **human step H7b2**, run by the user in
their own terminal after U7b-2 PASS. H7b2 is not a unit: it is not gated, not
dispatched, and not in the unit count. The changes to U7b-2:
- **Lead's contract = AC7b2.1, AC7b2.2, AC7b2.6, AC7b2.7, AC7b2.8, CC-gate.**
  AC7b2.3, AC7b2.4 and AC7b2.5 move out of it into H7b2, unchanged in
  substance. Nothing in the lead's contract reads `~/.claude/projects`.
- **New script mode** `--fill-doc <path>`: compute the same table as stdout
  mode, replace every line strictly between `<!-- harvest:begin -->` and
  `<!-- harvest:end -->` in `<path>` with that table, leave every other line
  of the file byte-identical, print exactly `filled <path>`, and exit 0. If
  the file does not hold exactly one of each marker, in that order, exit 2
  and leave the file unchanged. Like every other mode, it never prints or
  writes a command.
- **Doc skeleton (lead).** `docs/audits/2026-10-15-gate-fp-corpus.md` holds
  the method (the script contract summary, the family rule, the privacy rule,
  the per-machine best-effort note); the two concrete commit hashes `<pre>`
  (the parent of U7b-1's first commit) and `<u7b1>` (U7b-1's final commit),
  each written as a full 40-hex hash; the H7b2 command block below with both
  hashes filled in; and between the markers exactly one line,
  `PENDING: real-store harvest, human step H7b2`. It holds no count from any
  store, synthetic or real.
- Added criteria for the lead:
  - AC7b2.7 `bash tests/gate-fp-harvest.test.sh` (the same suite as AC7b2.1)
    also covers `--fill-doc`. On a copy of a fixture doc it asserts the span
    between the markers equals the literal expected table, every line outside
    the span is unchanged (`diff` of the outside lines → exit 0), stdout is
    `filled <path>`, and the sentinel `ZZ-PRIVATE-SENTINEL-42` is absent from
    the file. On a fixture doc with two begin markers it asserts exit 2 and an
    unchanged file (`cmp`). mutation: make `--fill-doc` append the table after
    the end marker instead of replacing the span → the span assertion fails,
    exit 1.
  - AC7b2.8 on the skeleton:
    `grep -c '^PENDING: real-store harvest, human step H7b2$' docs/audits/2026-10-15-gate-fp-corpus.md`
    → `1`; `grep -c 'harvest:begin' …` → `1`; `grep -c 'harvest:end' …` → `1`;
    `grep -cE 'git show [0-9a-f]{40}:hooks/scripts/lib/benign-command.sh' …`
    → `2`; `grep -c -- '--fill-doc docs/audits/2026-10-15-gate-fp-corpus.md' …`
    ≥ 1; and with `p` and `u` set to the first and second hash printed by
    `grep -oE '[0-9a-f]{40}:hooks' docs/audits/2026-10-15-gate-fp-corpus.md | cut -c1-40`,
    `git merge-base --is-ancestor "$p" "$u" && test "$p" != "$u"` → exit 0. mutation: write `<u7b1>` as an abbreviated
    hash → the `{40}` count drops to 1.

**Human step H7b2 (the user, in their own terminal, from the repo root, after
U7b-2 PASS).** The doc holds this block with `<pre>` and `<u7b1>` already
filled in:

```
b="$(mktemp)"; n="$(mktemp)"
git show <pre>:hooks/scripts/lib/benign-command.sh > "$b"
git show <u7b1>:hooks/scripts/lib/benign-command.sh > "$n"
python3 -I scripts/gate-fp-harvest.py --since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z --lib "$n" --baseline-lib "$b" --fill-doc docs/audits/2026-10-15-gate-fp-corpus.md
python3 -I scripts/gate-fp-harvest.py --since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z --lib "$n" --baseline-lib "$b" --check-doc docs/audits/2026-10-15-gate-fp-corpus.md
```

Both libs come from fixed commits, not the working tree, so a later lib edit
cannot change a re-run. The user reports the `leaks=<n>` line. Then the user,
or the main session on the user's word, commits the doc by explicit path
(`git add docs/audits/2026-10-15-gate-fp-corpus.md`). The doc then holds only
counts, so no scribe or gated dispatch is needed. H7b2's criteria, checked at
that point:
- AC7b2.3 (as written above; any agent can run it on the committed doc), plus
  `grep -c '^PENDING: real-store harvest' docs/audits/2026-10-15-gate-fp-corpus.md`
  → `0`.
- AC7b2.4 the `--check-doc` line in the user's terminal prints `leaks=0`. A
  value above 0 means: do not commit; `git checkout -- docs/audits/2026-10-15-gate-fp-corpus.md`
  and report it.
- AC7b2.5 (reproduction, the user's machine) re-run the `--fill-doc` line,
  then `git diff --exit-code -- docs/audits/2026-10-15-gate-fp-corpus.md` →
  exit 0.

**What U7b-2's PASS means.** The script, its modes, the privacy properties,
dedupe, cap, family attribution and `--fill-doc` are proved on the synthetic
store, and the doc skeleton is correct and ready for H7b2. It does **not**
certify any real-store count. Until H7b2 is done, the families' real share is
**unmeasured**. The Wave-6 milestone audit records it that way, the item-7b
share claim stays open, and nothing else is blocked: the per-dispatch
gate-block target in "Measurement and no-regression" uses U0's `agg.py`, not
this doc. If the user declines H7b2, the doc stays PENDING. That is a valid
end state, and the PENDING line says so.

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

### Wave-7 cleanup U13a-U13c: shared notes (added 2026-10-16)

One cleanup item set, split three ways. Two reasons: a contract is capped at
30000 bytes and 80 lines (`bin/contract-score.js:413`), which nine items with
their literal payloads cannot fit, and scripts and persona prose stay in
separately reviewable units, as the dispatcher asked. Items: (a) ladder-tier
default read, (b) the EXHAUSTED exception, (c) contract of record for the
ladder, (d) no-contract as guard demotion, (e) unit-outcomes contract files,
(f) agg2 main-session window, (g) checkpoint wording, commit and progress
rule, (h) leftover spawn language after U12, (i) prose pins. **None dropped.**
(e) and (f) feed the final measurement (NR2 and the before/after windows),
(a) is the open NOTE[spec] from ptr-u9a, and the prose items are each one
sentence. Spec-note dispositions: the ptr-u9a note on `bin/ladder-tier.sh:63`
is closed by (a). The ptr-u3b note on `scripts/unit-outcomes.js:159-163` is
closed by (e), including its "plan fallback also ignores contract files"
half. The README-drift notes on `scripts/unit-outcomes.js` (rgh-u0-3,
rgh-h10, fc-1, htd-1) are out of scope and unchanged. The ptr-u0b note on
`scripts/token-usage/agg2.py:114-133` is closed by (f). The untagged notes on
`agents/orchestrator.md` (units 125, 137, 148, 194) belong to units that were
dispatched long ago and are not this plan's inputs.

### Step U13a — Script fixes: ladder default, contract files in the export, agg2 window (items a, e, f)

Recommended model: sonnet. Sensitive: no (`bin/ladder-tier.sh` and
`scripts/` are not in `SENSITIVE_PATHS`, and the three suites are already
registered in `tests/validate.sh` at ~708, ~1343 and ~1354, so that file is
not edited). Depends on: U9a, U0 (landed).
Affected files: `bin/ladder-tier.sh` (`resolve_default` ~66-80),
`tests/ladder-tier.test.sh`; `scripts/unit-outcomes.js` (`issueIsUnit` ~172,
`ghIssue` ~178, `contractFor` ~211), `tests/unit-outcomes.test.js`,
`tests/fixtures/unit-outcomes/**` (new `fx-cfile` issue, marker and contract
file); `scripts/token-usage/agg2.py` (main-session section ~114-133),
`tests/token-usage.test.sh`, `tests/fixtures/token-usage-main/m1.jsonl`
(new; a separate root so the existing `tests/fixtures/token-usage` pins do
not move); `CHANGELOG.md`. One commit per item (three commits), each with
its CHANGELOG line. No version bump (P3 does not apply).
- (a) `resolve_default` uses one lone `jq` read that tells a missing
  `defaultImplementerModel` key apart from a present one
  (`has("defaultImplementerModel")`). Absent key or absent config file → the
  frontmatter model, as today. Present key whose value is not the string
  `haiku`, `sonnet` or `opus` (including `""`, `null`, `false` and numbers) →
  `opus`. A jq error → fail-closed, as today.
- (e) Contract source order in `contractFor`: (1) the issue body's first line
  matching `^Contract file: (\S+)\s*$` (unqualified; a qualified line such as
  `Contract file (scribe, dispatch first): …` is ignored), resolved against
  `--repo`, when that file exists and its line 1 is exactly `Unit: <id>` →
  `source: file:<repo-relative path>`, `text` = the whole file,
  `ts` = the issue's `createdAt`; (2) else `docs/plans/*/contracts/<id>.md`
  (sorted, first) whose line 1 is `Unit: <id>` → the same `file:` source with
  `ts` = the file's first commit time (the fast path has no issue); (3) the
  legacy `## Dispatch contract` block; (4) the plan block; (5) the transcript;
  (6) none. `issueIsUnit` also accepts a title whose first word is
  `[<id>]` (task-master's title form, e.g. `[ptr-u7a] …`) and an issue whose
  body passes rule (1).
- (f) The main-session section applies the subagent section's `[since,
  until)` window, using the `timestamp` of the session's first assistant
  record that carries `usage`. When `--since` or `--until` is given, a session
  with no such timestamp is excluded, matching `in_range`. The mtime day cut
  is unchanged.

Acceptance criteria:
- AC13a.1 `bash tests/ladder-tier.test.sh` → exit 0, with three new literal
  rows: config `{"defaultImplementerModel":""}`, `{"defaultImplementerModel":null}`
  and `{"defaultImplementerModel":false}`, each at n=0 →
  `ladder-tier: opus n=0 ladder=opus,opus reason=default`. The existing
  absent-key and absent-file rows are unchanged. mutation: restore
  `.defaultImplementerModel // empty` → the three new rows FAIL (they print
  the haiku ladder), exit 1.
- AC13a.2 `node tests/unit-outcomes.test.js` → exit 0, with new checks:
  `fx-cfile` (issue title `[fx-cfile] …`, body holding a qualified
  `Contract file (scribe, dispatch first): …` line before the unqualified
  `Contract file: <fixture contract path>` line, and no `## Dispatch contract`
  block) → `contract_source` is `file:<fixture contract path>` and
  `contract_score` is not null. The existing `issue#7`, `issue#11`,
  `issue#12`, `issue#901` and `none` assertions are unchanged (the legacy
  fallback). mutation: delete branch (1) and branch (2) → `fx-cfile`
  reports `none`, exit non-zero.
- AC13a.3 `bash tests/token-usage.test.sh` → exit 0, with new checks on
  `tests/fixtures/token-usage-main` (`m1.jsonl` = one assistant record,
  `timestamp` `2026-01-01T00:00:00Z`, `usage.input_tokens` 10):
  `python3 -I scripts/token-usage/agg2.py --root tests/fixtures/token-usage-main 36500 --since 2026-01-02T00:00:00Z`
  prints `sessions=0`; with `--since 2025-12-31T00:00:00Z` it prints
  `sessions=1`; with `--until 2026-01-01T00:00:00Z` it prints `sessions=0`.
  mutation: drop the window test → the first check prints `sessions=1`
  (measured 2026-10-16 at `adb9795` on an identical scratch fixture), exit 1.
- CC-gate.

### Step U13b — Orchestration prose: ladder and checkpoint wording (items b, c, d, g, and h's pointer)

Recommended model: sonnet. Sensitive: yes (`agents/`, `tests/validate.sh`).
Depends on: U13a (wave order only; no shared file).
Affected files: `agents/orchestrator.md`, `agents/task-master.md`,
`agents/spec-master.md`, the orchestrator ports
`adapters/codex/agents/orchestrator.toml` (~110) and
`adapters/cursor/agents/orchestrator.md` (~103) (their checkpoint sentence
gains the progress rule), `.claude/agents/*` (regenerated),
`tests/persona-prose-pins.test.sh` (new) plus one registration in
`tests/validate.sh`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
The agents/ports edits go in one commit with one bump. The test can be a
second commit that touches no agents/templates file.
Edits (the quoted text is the literal target):
1. (b) "Per-unit model routing" ~469: `On \`EXHAUSTED\`, dispatch nothing:` →
   `On \`EXHAUSTED\`, dispatch nothing, except a human-chosen (a)/(b) re-dispatch from **At the 2-FAIL cap**:`.
2. (c) ~466-467: after `--contract <contract file>` insert
   `(the contract of record, never a fix contract: a fix contract can score back onto \`haiku\`)`.
3. (d) "Contract-score guard" ~485-495, after the guard-demotion ledger
   sentence: `\`reason=no-contract\` is a guard demotion too (CONTEXT.md **guard demotion**): tell the user in one line that the unit had no contract, and append \`RULING <UTC ISO-8601 timestamp> unit=<task-id> decision=contract-guard sonnet: no-contract\`.`
   The phrases pinned by `tests/writer-tier-consistency.test.js:210` stay
   verbatim.
4. (g) "Cut off" bullet ~656: `or \`STATUS: incomplete\` other than a checkpoint`
   → `or \`STATUS: incomplete\` other than a task-master or spec-master checkpoint`.
5. (g) "Dispatch checkpoints" ~508-514, appended:
   `A checkpoint is progress only if the cited path has a newer commit (\`git log -1 --format=%h -- <path>\`) than at the same persona's previous checkpoint on this plan; otherwise it is not progress: do not re-dispatch, surface it to the user.`
   The same sentence goes after the checkpoint sentence in both orchestrator
   ports.
6. (h) ~433: `"Review ownership" section lists` →
   `"Review markers and gate mechanics (owner-facing)" section lists`.
7. (g) `agents/task-master.md` "Flush each unit, checkpoint every 3" ~460-470,
   appended: `Commit the handoff note with the contract file of the last unit it lists as done, in the same commit.`
8. (g) `agents/spec-master.md` "Dispatch checkpoints" ~234-241: checkpoint (3)
   becomes `(3) on the fast path, write and commit each contract file as soon as it is finished; after every 3 contract files in one spawn, with contracts remaining, end with \`STATUS: incomplete — checkpoint: <plan path>\` (the plan's dispatch-section links show which are done).`
   The "more than 5 steps" condition then applies to (2) only.
`tests/persona-prose-pins.test.sh` flattens each file (`tr -s ' \n' ' '`)
and prints `ok|FAIL <file> <phrase>`, exiting 0 only with no FAIL. It
checks that `agents/orchestrator.md` and `.claude/agents/orchestrator.md`
each contain the phrases `except a human-chosen (a)/(b) re-dispatch`,
`the contract of record, never a fix contract`,
`decision=contract-guard sonnet: no-contract`,
`other than a task-master or spec-master checkpoint`, `is not progress` and
`"Review markers and gate mechanics (owner-facing)" section lists`, and do
not contain `"Review ownership" section lists`. It checks that both
task-master copies contain `Commit the handoff note with`, that both
spec-master copies contain `after every 3 contract files`, and that both
orchestrator ports contain `is not progress`. The checkpoint parity row
checks that orchestrator, task-master and spec-master (source and mirror)
all contain `STATUS: incomplete — checkpoint:`.

Acceptance criteria:
- AC13b.1 `bash tests/persona-prose-pins.test.sh` → exit 0. mutation: delete
  edit 5's sentence from `agents/orchestrator.md` → a FAIL line, exit 1.
- AC13b.2 `grep -c 'tests/persona-prose-pins.test.sh' tests/validate.sh` ≥ 1.
- AC13b.3 `node tests/writer-tier-consistency.test.js` → exit 0.
- CC-P3, CC-mirror, CC-gate.

### Step U13c — Lead-programmer surface: no spawn language, tools pin (items h, i)

Recommended model: sonnet. Sensitive: yes (`templates/persona-protocol.md`,
`agents/`). Depends on: U13b (it appends rows to U13b's new test).
Affected files: `templates/persona-protocol.md` (four sentences: edits 1-3,
and edit 6 added by H-U13C), protocol
ports `adapters/codex/agents-md-fragment.md` and
`adapters/cursor/rules/persona-protocol.mdc` (the same three),
`agents/lead-programmer.md` (~79-81), lead-programmer ports
`adapters/codex/agents/lead-programmer.toml` and
`adapters/cursor/agents/lead-programmer.md`, `.claude/agents/*.md` and
`.claude/persona-protocol.md` (regenerated), `tests/persona-prose-pins.test.sh`
(rows appended), `.claude-plugin/plugin.json`, `CHANGELOG.md`. `bin/cli.js`
is not touched: the fix is a one-clause exception in the shared text, not a
matrix change (U5's matrix trims have FAIL history).
Edits:
1. Protocol "Structural questions go to the explorer", appended to its first
   paragraph: `\`lead-programmer\` is the exception: it has no \`Agent\` tool, never spawns the explorer, takes structure from its dispatch's \`## Pre-resolved context\`, and names what is missing in its report.`
2. Protocol "Reuse over re-derivation": after
   `spawning the \`explorer\` only to check that claim` insert
   ` (\`lead-programmer\`, which cannot spawn, names the doubted claim in its report instead)`.
3. Protocol "Agent-teams mode":
   `- You CAN spawn foreground subagents; only nested TEAMS are barred.` →
   `- If your persona has the \`Agent\` tool, you CAN spawn foreground subagents; only nested TEAMS are barred.`
4. `agents/lead-programmer.md` and both lead-programmer ports: the
   `Spawn \`researcher\`` bullet → `- **No researcher**: you cannot spawn \`researcher\` and have no WebSearch tool. When a technique is unclear, say so in your report; the orchestrator can dispatch \`researcher\`.`
5. Both lead-programmer ports: delete the `**Scribe updates (batched,
   blocking-but-brief)**` bullet (it is absent from `agents/lead-programmer.md`).
6. (added 2026-10-16, ruling H-U13C; U7a reviewer finding) Protocol "Teammate
   Write/Edit fallback and gate rephrasing doctrine", the bullet that starts
   `If either \`reviewed-path-gate.sh\` or \`human-decision-gate.sh\` refuses a heredoc`
   (~82-86): replace
   `read its refusal text before doing anything else: both gates print their complete remediation — the sanctioned heredoc template, when rephrasing a path is allowed, and when it isn't — at the moment they refuse.`
   with
   `read its refusal text and the glossary entry its \`More:\` line names before doing anything else: the refusal names the sanctioned route, and the entry (\`reviewed-path denial\` or \`decision-gate denial\` in \`docs/harness-glossary.md\`) holds the full remediation, including when rephrasing a path is allowed and when it isn't.`
   The next sentence (`Rewording a command to dodge …`) stays. Since U7a the
   gates print a three-line denial whose last line is
   `More: docs/harness-glossary.md — "<entry>"`. The protocol ports carry no
   copy of this bullet (measured 2026-10-16), so this edit touches only the
   template, and `node bin/cli.js --update` regenerates
   `.claude/persona-protocol.md` and the four mirrors whose trimmed protocol
   carries the section: `.claude/agents/{lead-programmer,reviewer,spec-master,task-master}.md`.
Rows appended to `tests/persona-prose-pins.test.sh`:
- the `^tools:` line within lines 1-12 of `agents/lead-programmer.md` and of
  `.claude/agents/lead-programmer.md` exists and does not contain `Agent`
  (the tools pin);
- no hits for `Spawn \`researcher\``, `Scribe updates` or
  `You CAN spawn foreground` in the lead-programmer source, mirror and ports;
- `.claude/agents/lead-programmer.md` contains
  `is the exception: it has no` and `If your persona has the`.
- (edit 6) each of `templates/persona-protocol.md`, `.claude/persona-protocol.md`
  and `.claude/agents/{lead-programmer,reviewer,spec-master,task-master}.md`,
  flattened, does not contain `print their complete remediation` and does
  contain `the glossary entry its \`More:\` line names`.

Acceptance criteria:
- AC13c.1 `bash tests/persona-prose-pins.test.sh` → exit 0. mutation: append
  `, Agent` to the `tools:` line of `agents/lead-programmer.md` → a FAIL line,
  exit 1. Second mutation (edit 6): restore the old sentence in
  `templates/persona-protocol.md` and run `node bin/cli.js --update` → FAIL
  lines for the template and the regenerated copies, exit 1.
- AC13c.2 `node tests/protocol-cross-references.test.js` → exit 0.
- AC13c.3 (edit 6) `for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/*.md; do tr -s ' \n' ' ' < "$f" | grep -c 'print their complete remediation'; done | grep -vc '^0$'`
  → `0` (no file carries the old sentence, including mirrors the row list
  does not name).
- CC-P3, CC-mirror, CC-parity, CC-gate.

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
| U7b | superseded by U7b-1/U7b-2 (H-U7B) | - |
| U7b-1 | ✱`hooks/scripts/lib/benign-command.sh` + ✱its `.claude/` mirror (no adapter copies, H-U7B1), `tests/fixtures/gate-fp-corpus/{positive,negative}.jsonl`, new test, ✱`tests/validate.sh`, CHANGELOG; two pins in `tests/{harness-integrity,human-decision}-gate.test.sh` (H-U7B3) | yes |
| U7b-2 | `scripts/gate-fp-harvest.py`, its test and synthetic fixtures, `docs/audits/…gate-fp-corpus.md` (skeleton), ✱`tests/validate.sh`, CHANGELOG | yes |
| H7b2 | `docs/audits/…gate-fp-corpus.md` marker span (human step, user's terminal; not a unit, H-U7B2) | **no** (human) |
| U11 | `docs/audits/…adr0040-forward-rule.md` | **no** (docs) |
| U12 | ✱`agents/lead-programmer.md`, lead-programmer ports, ✱`agents/orchestrator.md`, ✱plugin.json, CHANGELOG | yes |
| U13a | `bin/ladder-tier.sh`, `scripts/unit-outcomes.js`, `scripts/token-usage/agg2.py`, their three tests and fixtures, CHANGELOG | yes |
| U13b | ✱`agents/{orchestrator,task-master,spec-master}.md`, ✱mirrors, orchestrator ports, `tests/persona-prose-pins.test.sh`, ✱`tests/validate.sh`, ✱plugin.json, CHANGELOG | yes |
| U13c | ✱`templates/persona-protocol.md`, protocol ports, ✱`agents/lead-programmer.md`, lead-programmer ports, ✱mirrors, `tests/persona-prose-pins.test.sh`, ✱plugin.json, CHANGELOG | yes |

### Disjointness

- **Dependent pairs (shared files, strict order):** U7c → U6 (`reviewer.md`);
  U6 → U5 (`persona-protocol.md`); U5 → U12 (`lead-programmer.md`);
  U3 → U8 (`task-master.md`, `spec-master.md`, `orchestrator.md`, and U8
  needs contract files); U8 → U9 (`orchestrator.md`); U12 also
  touches `orchestrator.md` and goes after U5 and before U3 (Wave 3); U7a → U7b-1 (gate test files) → U7b-2 (compares the libs before and after U7b-1); U13b → U13c (`tests/persona-prose-pins.test.sh`, mirrors); U0, U2, U9, U7b-1, U7b-2, U13b all
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
- **Wave 6 (gate surfaces, highest risk last):** U7a → U7b-1 → U7b-2
  (ruling H-U7B; U7b is superseded). After U7b-2 PASS comes human step H7b2
  (H-U7B2): the user runs it in their own terminal, at any time before the
  Wave-6 milestone audit. It is not a unit and does not hold Wave 7.
- **Wave 7 (cleanup, after everything else):** U13a → U13b → U13c. Then the
  final before/after measurement runs (U0's `agg.py`/`agg2.py` with U13a's
  `agg2` window fix, and a fresh `scripts/unit-outcomes.js` export with
  U13a's contract-file source for NR2).
- **Any time (ungated):** U11.

Units: **15 dispatchable** (U0, U1, U2, U3, U4a, U4b, U5, U6, U7a, U7b,
U7c, U8, U9, U11, U12). Of these, 13 are gated lead-programmer units, and
U4a (scribe) and U11 (docs audit) are ungated. **That is ≥ 6, so this spec
goes to `task-master`** (standard path).
Revised 2026-10-16: **19 dispatchable** (U7b replaced by U7b-1 and U7b-2;
U13a, U13b and U13c added). 17 are gated lead-programmer units; U4a and U11
stay ungated. Still the standard path.
Re-checked 2026-10-16 after H-U7B1, H-U7B2 and H-U13C: still **19**. H7b2 is
a human step, not a unit, and U13c's edit 6 adds no unit.
Re-checked 2026-10-16 after H-U7B3: still **19**. H-U7B3 adds two files and
three criteria to U7b-1, and no unit; waves and order are unchanged.

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
| reviewer / spec-master | gate blocks per dispatch | 1.09 / 3.00 | ≤ 0.6 / ≤ 1.5 | U7a, U7b-1 |

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
  for U5/U6, set inclusion for U1, the frozen corpora for U7b-1).
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
  (U0, U1, U4b, U7a, U7b-1, U7b-2, U13a): a CHANGELOG entry per repo
  convention. No bump is required by P3.
- Added 2026-10-16: U13b and U13c touch `agents/*.md` (and U13c
  `templates/persona-protocol.md`), so each bumps `.claude-plugin/plugin.json`,
  adds a CHANGELOG entry in the same commit and regenerates mirrors after the
  bump (CC-P3, CC-mirror). U13a splits into one commit per item, U13b's agents
  commit is separate from its test commit, and every touching commit carries
  its own bump.
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

Added 2026-10-16 (non-blocking; the default applies and U7b-2 is
dispatchable as written):
1. Should U7b-2 also commit raw harvested commands (redacted), rather than
   aggregate counts only? Recommended default: **no**, aggregates only, with
   the examples taken from U7b-1's hand-written files. Options: (a) no,
   aggregates only (default); (b) yes, a capped sample (at most 50 distinct
   commands, each at most 300 characters, `$HOME` → `~`, issue numbers and
   quoted strings replaced by placeholders). Choosing (b) adds a criterion to
   U7b-2 and needs no new unit. (From CHK22.)

Added 2026-10-16 (non-blocking; nothing waits on the answer before U7b-2
PASS):
2. Will you run human step H7b2 (five commands in your own terminal, from the
   repo root, after U7b-2 PASS; the exact block is in Step U7b-2 and will be in
   the audit doc with both hashes filled in)? Recommended default: **yes**,
   soon after U7b-2 PASS, because Claude Code's transcript cleanup can delete
   in-window sessions as they age. Options: (a) yes (default); (b) no: the doc
   stays PENDING and the families' real share is recorded as unmeasured.
   (From CHK33.)
   **Resolved 2026-10-16: (a) yes.** The user will run H7b2 after U7b-2
   passes review (recorded in Clarifications). OQ1 stands (aggregates only).

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
- CHK20 (2026-10-16): Is the input classified for U7b's AC7b.1 defined, and
  not circular? — FAIL (missing; task-master SPEC-GAP #562) — revised in
  place: U7b-1 reads only the frozen hand-written files, and U7b-2's
  classifier is the lib itself, with a frozen syntactic family rule
- CHK21: Are the corpus window, cap, dedupe and denominator defined for the
  share figures? — FAIL (missing) — revised in place: U7b-2 script contract
  (window, 4,096-character cap, distinct strings, D = classified)
- CHK22: Is the privacy rule for harvested commands decided, and is it
  machine-checked? — FAIL (missing) — revised in place (default: aggregates
  only, proven by the sentinel fixture, `--check-doc` `leaks=0` and AC7b2.6)
  and converted to Open Question 1 for a possible user override
- CHK23: Does each F1/F3 positive fail on the pre-U7b-1 lib, so that AC7b1.1
  is not vacuous? — PASS (AC7b1.2 asserts exactly 13 FAIL lines on the old
  lib; all 13 commands were probed non-benign at `adb9795`)
- CHK24: Do premise 12 and U7b-1 agree that F2 is pinned and not changed?
  — PASS (U7b-1 "Families" and AC7b1.2's count, which excludes F2)
- CHK25: Do the step list, file map, wave list and unit count agree after the
  revision? — PASS (19 = the 15 headings minus U7b plus U7b-1, U7b-2,
  U13a, U13b, U13c; every one has a file-map row; Wave 6 is U7a → U7b-1 →
  U7b-2 and Wave 7 is U13a → U13b → U13c)
- CHK26: Do U13b's no-contract ledger line and CONTEXT.md **guard demotion**
  agree? — PASS (both make no-contract a guard demotion with a ledger line;
  `decision=contract-guard` is reused, so `writer-tier-consistency` pins hold)
- CHK27: Do spec-master checkpoint (3) and the ≤ 5-unit fast path agree? —
  FAIL (conflicting: (3) could never fire) — revised in place: U13b edit 8
  makes (3) an every-3-contracts flush on the fast path
- CHK28: Does every U13 item carry a mutation-proved criterion? — PASS
  (AC13a.1-3, AC13b.1, AC13c.1; (b), (c), (d), (g) and (h) are pinned by
  `tests/persona-prose-pins.test.sh`, whose mutation is AC13b.1/AC13c.1)
- CHK29: Do U13b and U13c both bump, and stay serial on their shared test
  file? — PASS (version obligations, Disjointness)
- CHK30 (glossary, advisory): Does "handoff note" match the spec-master
  checkpoint path? — FAIL (conflicting: CONTEXT.md **dispatch checkpoint**
  says the path is the handoff note, while spec-master cites the plan path) —
  revised in place: routed to scribe in the update hint (advisory only,
  never blocking)
- CHK31 (2026-10-16, H-U7B1): Can AC7b1.3 pass, given the files it names? —
  FAIL (conflicting with `bin/cli.js:671`; task-master SPEC-GAP #562) —
  revised in place: AC7b1.3 compares against the `.claude/` mirror and pins
  that the adapter copies stay absent; the affected files, file map and R3
  are corrected to match
- CHK32: Does every frozen `sort`/`uniq` negative fail under at least one
  named mutation, and does the frozen rule cover abbreviation, quoting, brace,
  glob, `$`, `--compress-program`, `-T`, `--` and the POSIXLY_CORRECT operand
  case? — FAIL (missing; the `--output*` rule is bypassable) — revised in
  place: option allowlists, banned characters, 10 new negatives, mutations
  (a)-(d)
- CHK33 (H-U7B2): Is it defined who produces the real-store numbers that
  AC7b2.3-5 need, and what U7b-2's PASS means without them? — FAIL (missing;
  SPEC-GAP #563) — revised in place: human step H7b2 with the exact commands,
  and a PASS-meaning paragraph; whether the user will run it is converted to
  Open Question 2 (non-blocking)
- CHK34: Do AC7b1.2's count of 13 and the revised data agree? — PASS (the
  positives are unchanged; all 20 negatives are non-benign on the old lib,
  which has no `sort` or `uniq` in `program_allowed`)
- CHK35: Is every lead criterion of U7b-2 runnable without the real
  transcript store? — PASS (AC7b2.1/7 use the synthetic store; AC7b2.2/6/8 are
  greps and git commands on the repo)
- CHK36 (H-U13C): Is U13c edit 6 pinned so that the old sentence cannot
  return, including in mirrors? — PASS (the prose-pins rows, AC13c.3 measured
  at `6` files today and expected `0` after, and AC13c.1's second mutation)
- CHK37: Do the step list, file map, wave list and unit count still agree?
  — PASS (19 units; H7b2 has a file-map row marked human and a Wave-6
  sentence, and it is excluded from the count in both places)
- CHK38: Are the marker-audit notes on the touched surfaces disposed? — PASS.
  `bin/marker-audit.sh --notes` was run 2026-10-16 on
  `hooks/scripts/lib/benign-command.sh` and `templates/persona-protocol.md`.
  gh345-1 N5 ("the lib has no direct test file") is closed by U7b-1's new
  test. hdg-lexer-1 (quoted-span vocabulary) and gh325 (the human-decision
  suite is now registered: `tests/validate.sh` has 4 hits) are unchanged and
  not this plan's inputs. The template notes (units 125, 137, 188, 189, 202,
  236) belong to units dispatched long ago. The one NOTE[spec]
  (item19-2-measure-skip-rate) concerns another plan's surface.
- CHK39 (H-U7B3): Can AC7b1.4 and CC-gate pass on a correct F1/F3? — PASS
  (revised in place). Before the ruling: FAIL (conflicting), the `[U7c]`
  control and OB-10 pinned freed commands. Edits A and B change both pins,
  and a superset-lib sweep of all 17 test files naming the lib or its three
  gates finds no third.
- CHK40: Is every dropped refusal replaced by one of equal strength? — PASS.
  No pin is deleted: the cd-prefixed control and OB-10 become `allowed`
  pins; two U7c refusals (touch-prefixed, cd-then-touch) and OB-15 are added,
  each measured refused on the current and the superset lib, and frozen by
  AC7b1.7 (count 3) and AC7b1.8 (14 `blocked`, 1 `allowed`).
- CHK41: Is the F1 segment-level reading decided, with a criterion behind
  it? — PASS (accepted; AC7b1.6, exit 1 on the `<pre>` lib, mutations (e)
  and (f)).
- CHK42: Do AC7b1.1 and AC7b1.2 still agree with the frozen data? — PASS
  (H-U7B3 adds no corpus line: 16 and 20 `ok`, 13 `FAIL` on `<pre>`).
- CHK43: Can a U7b-1 edit trip the C4.1 sweep in
  `tests/harness-integrity-gate.test.sh`? — PASS (revised in place: the ruling
  names the trap, and this plan was checked to contain none of the four
  phrases, `git grep -l` → no output).
- CHK44: Are the marker-audit notes on the two newly touched test files
  disposed? — PASS. Swept 2026-10-16. NOTE[spec] hcb-prose-history (C4.1
  classification) is what CHK43 handles. NOTE[spec] item19-1: six local,
  gitignored microworld bundles (hdg-anchor-1, hdg-prose-2, hdg-prose-2-fix2,
  hdg-lexer-1, rpg-comment-3, rpg-canon-2) run the human-decision suite; on
  the superset lib each fails only on OB-10, so Edit B turns them green and
  none needs an edit. The other notes (hcb-regcheck, esc-chat-6, esc-fu-1,
  esc-left-4, rnc-1, gh325, gh418) concern other pins and are not this
  ruling's inputs.
- CHK45: Is OQ2's answer recorded? — PASS (Clarifications, and OQ2 marked
  resolved (a)).


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
- Added 2026-10-16. At U7b-1 landing: **read-only families** lists F1 and F3
  as added, with F2 already present (premise 12). At U7b-2 landing:
  **flipped command** (non-benign under the baseline lib, benign under the new
  one) in `docs/harness-glossary.md`. At U13b landing: amend CONTEXT.md
  **dispatch checkpoint** (the spec-master path is the plan doc, not a
  handoff note, and the progress-only re-dispatch rule) and **guard demotion**
  (`reason=no-contract` is named explicitly).

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
- Wave 6, U7b-1 (issue #562) and U7b-2 (issue #563): both HELD on spec gaps found while slicing after ruling H-U7B (the adapter copies of `benign-command.sh` do not exist; nobody can produce the real-store harvest numbers); no contract files exist, see the issue bodies for each gap and a proposed ruling.
- Ruling H-U7B (2026-10-16, spec-master): the split is accepted, with changes.
  U7b is superseded by Step U7b-1 (lib families F1+F3, frozen hand-written
  positive and negative files, no harvested data) and Step U7b-2 (harvest
  script, aggregate counts only, sentinel-proved privacy). task-master
  re-slices #562 as U7b-1 and opens U7b-2, then U13a-U13c for Wave 7.
- Rulings H-U7B1, H-U7B2, H-U13C (2026-10-16, spec-master), answering the
  SPEC-GAPs in #562 and #563 and the U7a reviewer finding. task-master
  removes the `HELD:` lines from #562 and #563 and writes their contract files
  (U7b-1 first). U13c's issue, when sliced in Wave 7, carries edit 6.
- Resume 2026-10-16 (task-master): U7b-1 (#562) and U7b-2 (#563) stay HELD, no contract files. Replaying the revised U7b-1 in a scratch clone met a second spec gap: AC7b1.4 and CC-gate cannot pass on any correct F1/F3 implementation, because `tests/harness-integrity-gate.test.sh` (`[U7c]` cd-prefix negative control) and `tests/human-decision-gate.test.sh` (pin `OB-10`) assert commands that F1/F3 now make benign. #563 is held behind #562. See the #562 body for the measured failures and a proposed ruling.
- Ruling H-U7B3 (2026-10-16, spec-master), answering the second SPEC-GAP in
  #562: U7b-1 adds `tests/harness-integrity-gate.test.sh` and
  `tests/human-decision-gate.test.sh` (Edits A and B in Step U7b-1), with
  AC7b1.6-AC7b1.8; F1 at segment level is accepted. task-master removes the
  `HELD:` lines from #562 and #563 and writes their contract files (U7b-1
  first). OQ2 answered (a): the user will run H7b2.
- Wave 6, U7b-1 (lead contract, no version bump; the `HELD:` line is removed after ruling H-U7B3): [ptr-u7b-1](2026-10-15-persona-token-reduction/contracts/ptr-u7b-1.md), issue #562.
- Wave 6, U7b-2 (lead contract, dispatched after U7b-1 PASS; human step H7b2 follows its PASS): [ptr-u7b-2](2026-10-15-persona-token-reduction/contracts/ptr-u7b-2.md), issue #563.
- Wave 7, U13a (lead contract, no version bump): [ptr-u13a](2026-10-15-persona-token-reduction/contracts/ptr-u13a.md), issue #564.
- Wave 7, U13b (lead contract, 0.31.180, blocked by U13a): [ptr-u13b](2026-10-15-persona-token-reduction/contracts/ptr-u13b.md), issue #565.
- Wave 7, U13c (lead contract, 0.31.181, blocked by U13b; carries edit 6 of ruling H-U13C): [ptr-u13c](2026-10-15-persona-token-reduction/contracts/ptr-u13c.md), issue #566.
