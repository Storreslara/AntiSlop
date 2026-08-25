# Agent-throughput performance dampeners in the review-gating harness

Status: **FINAL — dispatch-ready** (spec-master, 2026-08-25). Resolves to **five
units**. At the ≤5 fast-path threshold (ADR-0024 Step 3), so this spec may be
dispatched directly without `task-master` slicing — but see "Sequencing" below:
Unit B gates on Unit A's harness, so the fast path is not a parallel dispatch.

**Unit D carries a RATIFIED decision, not an open question** (2026-08-25):
`lead-programmer` defaults to **`sonnet`**, reversing ADR-0010's implementer-
haiku default. See "Unit D — The decision (RATIFIED)". The pre-ratification
draft's Open Question 1 is closed and recorded there.

**Unit C was reduced in scope** by spec 5's ruling E9: its denial-message
rewrite is now **spec 1's Step 5**, and Unit C keeps only the marker-write
helper. See "Relationship to sibling specs".

Derived from an adversarial architecture critique of this repo's review-gating
harness. This is spec **2 of 5** in the original critique set; siblings cover
trust gaps, harness ceremony, the Microworlds workflow redesign, and
streamlining, and a later **sibling spec 6** (CI-shaped review) was adopted
after this one was drafted. Cross-spec coordination points — two with spec 6,
one with spec 1, one ruling inherited from spec 5 — are collected in
"Relationship to sibling specs". **This spec is scoped strictly to the
performance / latency / token-cost dimension.**
Where a finding is also a trust or ceremony problem, the acceptance criteria
here are written only against its cost, and the overlap is named explicitly in
"Relationship to sibling specs".

**Every number below was measured live against this repo at HEAD `09cc304` on
2026-08-25.** No figure is inferred, and each is reproducible by the command
named beside it. Where the critique's own figure differed from measurement, the
measured value is used and the discrepancy is flagged.

---

## Problem Statement

A developer running this persona system pays three compounding costs that
nothing in the harness currently prices:

1. **Every edit to a hot gate file blocks for minutes.** Editing
   `tests/human-decision-gate.test.sh` runs **211.96 seconds** of test suites
   synchronously, inline, in `PostToolUse`, before the agent can emit its next
   token. The agent is not thinking during that time; it is waiting on a
   *reporter* that is explicitly not a gate.

2. **The same test suites execute three to five times per unit** — once (or
   several times) per edit via the rerun hook, once at `SubagentStop`
   (`bash tests/validate.sh`, **102.56 s**), and once more by the reviewer
   before PASS. Only the reviewer's run is independently trusted; the rest are
   defence-in-depth that has already been paid for.

3. **The cheap tier does the hard work and the expensive tier pays for the
   retries.** `lead-programmer` defaults to `haiku` for the hardest,
   most open-ended generative work. Measured across 1,073 session transcripts,
   haiku accounts for **4.6 % of total spend ($207.29 of $4,520.80)** while
   opus accounts for **58.6 %**. The entire theoretical upside of the cheap
   writer tier is capped at a rounding error, while its documented failure mode
   — an extra FAIL cycle — draws on the most expensive line item in the system.

The developer experiences this as: long unexplained pauses after edits, review
cycles that feel disproportionate to the size of the change, and a bill
dominated by re-verification rather than by work.

## Solution

Re-price the harness along the one axis it has never measured — **cost per unit
of forward progress** — with five changes, each independently verifiable:

- **A.** Make the microworld rerun hook **asynchronous**: enqueue on edit, run
  detached, surface results at the next `Stop`/`SubagentStop`. The hook's own
  header already licenses this ("This is a REPORTER, not a gate"), so deferred
  reporting changes no trust property.
- **B.** Let `stop-gate.sh` **skip its full suite run** when the rerun queue has
  already recorded a clean pass covering every changed file since the last edit.
  The reviewer's independent run is untouched, and the skip is mutation-proved
  non-vacuous.
- **C.** Collapse the sanctioned two-call marker-write dance into a
  **single-call helper**. *(Reduced to this one deliverable by spec 5's E9
  ruling; the denial-message rewrite this unit originally carried is now spec 1's
  Step 5, which inherits the word budgets measured in §B3.)*
- **D.** **Re-price the writer tier to `sonnet`** (ratified 2026-08-25),
  amending ADR-0010 with the answer to the question that ADR deferred as "not
  measurable forward" — and build the cost-accounting script that produced that
  answer as a **standing** tool, to verify the reversal forward against a
  pre-registered rule rather than justify it retroactively.
- **E.** Make `protected-paths.sh`'s **coverage match its declared risk class**,
  so the cheapest gate in the system stops being the sole guard over surfaces
  nobody priced it for.

---

## Measured baseline

All figures reproducible at HEAD `09cc304`, 2026-08-25.

### B1 — Synchronous write-path latency (Finding 2)

Measured by invoking the real `hooks/scripts/microworld-rerun.sh` with canned
`PostToolUse` input naming an existing file (the hook requires only that the
file exist), so no repo file was modified:

| Edited file | Bundles triggered | Measured inline latency |
|---|---|---|
| `tests/human-decision-gate.test.sh` | 4 | **211.96 s** |
| `hooks/scripts/human-decision-gate.sh` | 3 | **158.89 s** |
| `tests/reviewed-path-gate.test.sh` | 3 | **156.18 s** |
| `hooks/scripts/reviewed-path-gate.sh` | 2 | **115.85 s** |
| `bin/cli.js` | 1 | **12.54 s** |

Bundle fan-out comes from the `watch` globs in `microworlds/*/manifest.json`.
The critique named four overlapping bundles; measurement confirms this and
shows it is **understated** — `tests/human-decision-gate.test.sh` is watched by
`hdg-anchor-1`, `hdg-lexer-1`, `hdg-prose-2-fix2` *and* `hdg-prose-2`, whose
declared `timeoutSeconds` sum to a **540 s worst case**.

Two compounding facts the critique did not name:

- **The bundles re-run each other's suites.** `microworlds/hdg-prose-2/run.sh`
  and `microworlds/rpg-canon-2/run.sh` each invoke *both*
  `tests/human-decision-gate.test.sh` and `tests/reviewed-path-gate.test.sh`.
  One edit to `hooks/scripts/human-decision-gate.sh` therefore executes each of
  those two suites **three times**, inside a single hook invocation, before
  `stop-gate.sh` or the reviewer runs either of them again.
- **The worst case exceeds any plausible harness hook timeout.**
  `hooks/hooks.json` declares no `timeout` for this hook. Real
  `.claude/microworld-audit.log` sequences show a single edit's fan-out spanning
  **116 s** of wall clock (`01:41:13` → `01:43:09`), so the blocking is real
  rather than silently truncated — but a design whose happy path is a
  three-and-a-half-minute synchronous hook is one harness-default change away
  from becoming a silently truncated reporter on exactly the files it most needs
  to cover. Making the hook asynchronous moots the question entirely.

### B2 — Redundant suite execution (Finding 4)

`bash tests/validate.sh` — the configured `testAndLintCommand` — runs **37 test
suites in 102.56 s**. It includes both `tests/human-decision-gate.test.sh` and
`tests/reviewed-path-gate.test.sh`, the same suites the bundles run.

For one unit editing `hooks/scripts/human-decision-gate.sh` with *n* edits, the
suite `tests/human-decision-gate.test.sh` executes:

| Layer | Executions | Trusted? |
|---|---|---|
| `microworld-rerun.sh` (per edit, 3 bundles each running it) | 3 × *n* | No — reporter |
| `stop-gate.sh` `testAndLintCommand` at `SubagentStop` | 1 | No — defence-in-depth (its own header says so) |
| Reviewer's own pre-PASS run | 1 | **Yes — the only independently trusted run** |

At a modest *n* = 10 edits that is **32 executions of the same suite**, of which
one is load-bearing, costing roughly **26.5 minutes** of blocked write path plus
**205 s** of stop/review runs.

`stop-gate.sh`'s own header already concedes the redundancy: *"the reviewer
independently re-runs checks before PASS regardless, so this is
defense-in-depth, not the only safety net."*

### B3 — Denial-message token cost (Finding 3)

Measured by executing each gate with canned hook input and counting the stderr
actually returned to the model:

| Gate / path | Exit | Words | Bytes | ≈ tokens |
|---|---|---|---|---|
| `reviewed-path-gate.sh` — Bash write | 2 | **357** | 2,168 | ~542 |
| `human-decision-gate.sh` — Bash write | 2 | **230** | 1,535 | ~383 |
| `stop-gate.sh` — reviewer, no marker | 2 | ~99 | — | — |
| `reviewed-path-gate.sh` — Write tool | 2 | 60 | 455 | ~113 |
| `protected-paths.sh` — Write tool | 2 | 19 | 191 | ~47 |

The critique's "300+ words" is **confirmed for `reviewed-path-gate.sh` (357)**
and **overstated for `human-decision-gate.sh` (230)**; both are recorded as
measured.

This cost is not hypothetical and not merely CPU: **authoring this spec
triggered the 357-word `reviewed-path-gate.sh` denial twice**, each time
consuming a full turn and ~542 tokens to recover a read-only marker listing. The
two denials were provoked by exactly the two shapes the message spends most of
its length explaining — a pipeline through a non-allowlisted program, and a
quote-split path spelling.

The messages' length is spent re-teaching *general bypass reasoning* — why the
workaround is sanctioned for one gate and not the other, what a self-authorized
bypass is, which spellings are recognized — rather than stating the fix. The
`reviewed-path-gate.sh` message additionally documents a **ratified
false-positive class** in its own text: *"A comment on a line of its OWN still
fails closed; that is a ratified residual (issue #183)."* Every agent that hits
that residual pays 542 tokens to be told it is known and unfixed.

The sanctioned marker-write workaround is a **documented two-call dance**: the
agent must not spell a packet-dir path and the literal `DECISION` field in one
Bash call, so a single logical write costs two turns.

### B4 — Writer/reviewer tier pricing (Finding 1)

**Frontmatter, as claimed and confirmed:**

| Persona | `model` | `maxTurns` |
|---|---|---|
| `lead-programmer` | `haiku` | 50 |
| `reviewer` | `opus` | 50 |
| `spec-master` | `opus` | 40 |
| `milestone-auditor` | `opus` | 20 |
| `task-master` | `sonnet` | 40 |

**Measured spend**, aggregated over 69,636 assistant messages carrying `usage`
across 1,073 transcript files in `~/.claude/projects/-home-sebas-AntiSlop/`,
priced at current published rates (Haiku 4.5 $1/$5, Sonnet 5 $3/$15, Opus 5
$5/$25, Fable 5 $10/$50 per MTok; cache reads at 0.1×, cache writes at 1.25×):

| Model | Msgs | Cost | Share |
|---|---|---|---|
| `claude-opus-5` | 26,699 | **$2,647.41** | 58.6 % |
| `claude-sonnet-5` | 23,192 | $1,444.59 | 32.0 % |
| `claude-fable-5` | 1,361 | $218.60 | 4.8 % |
| `claude-haiku-4-5` | 18,304 | **$207.29** | **4.6 %** |
| `claude-opus-4-8` | 57 | $2.90 | 0.1 % |
| **Total** | | **$4,520.80** | |

**Measured FAIL rate**, from 269 units in `.claude/reviewed/`, split at
ADR-0010's date (2026-08-02) by earliest marker mtime:

| Period | Implementer default | Units | With a FAIL record | Rate |
|---|---|---|---|---|
| Before 2026-08-02 | `sonnet` | 66 | 11 | **16.7 %** |
| From 2026-08-02 | `haiku` | 203 | 66 | **32.5 %** |

Overall: 269 units, 77 with a FAIL record (28.6 %); 72 recovered on a later
PASS, 5 never passed.

**This is the measurement ADR-0010 deferred.** That ADR states its bet
explicitly — *"The bet is that such units are rare enough that the expected
value of defaulting all units to haiku justifies the cost of occasional
escalation"* — and then states that it could not be settled: *"The success
criterion is not measurable forward… Any before/after measurement must start
forward from this change."* It is now 23 days forward, and the data exists.

**The shape of the mispricing.** ADR-0010 §4 prices a wrong-cheap unit at one
wasted haiku attempt + one sonnet re-run + **two reviews**. The second review is
forced to `opus` by the reviewer-gate ratchet (`hooks/scripts/reviewer-tier.sh`
reads the `.fail` record). So each avoidable FAIL cycle converts a small haiku
saving into an extra **opus** review plus a full redispatch — dispatch contract,
`.review-join` stamp, marker write, and another 102.56 s `stop-gate` run. The
upside is bounded by a 4.6 % line item; the downside draws on the 58.6 % one.

**Stated honestly, this comparison is confounded** and must not be treated as
proof on its own: marker mtime is a proxy for dispatch date, the two populations
differ in composition (later units concentrate in gate-hardening work that is
plausibly harder regardless of tier), and the sample sizes are unequal (66 vs
203). **These confounds were disclosed to the ratifier and acknowledged before
the decision was taken** (see "Unit D — The decision (RATIFIED)"). They are
precisely why Unit D's Deliverable 1 remains a **re-runnable accounting script
carrying a pre-registered forward rule**, rather than being descoped once the
decision was made: the retrospective evidence motivated the reversal, but only
forward measurement under a single consistent policy can confirm it.

**Prior art that must not be repeated.** ADR-0009 and ADR-0010 record that
`task-master`'s *pre-implementation* prediction of a cheap tier reached "roughly
0 % of units in practice." Any proposal that reintroduces pre-emptive
"this unit looks mechanical" tagging is re-running a measured failure. The two
live options are therefore a flat default change or a cheaper escalation path —
not a smarter predictor.

### B5 — `protected-paths.sh` cost allocation (Finding 5)

Confirmed: **39 lines**, advisory-only, `Write|Edit` only (its own header
concedes *"a persona running `sed -i`, `git mv`, or a package manager… bypasses
this gate entirely"*), and a 19-word denial message.

Measured coverage gap — `hooks/scripts/` holds **16 `.sh` files** (14
top-level plus 2 under `lib/`). `protectedPaths` in
`.claude/persona-config.json` lists 4 patterns, which cover **2 of the 8
enforcement gates** (the scripts that can block a tool call or a turn) and none
of the shared libraries:

| Gate script | In `protectedPaths`? |
|---|---|
| `human-decision-gate.sh` | Yes |
| `reviewed-path-gate.sh` | Yes |
| `stop-gate.sh` | **No** |
| `task-gate.sh` | **No** |
| `reviewer-route-gate.sh` | **No** |
| `dispatch-hygiene.sh` | **No** |
| `protected-paths.sh` (itself) | **No** |
| `lib/benign-command.sh` | **No** |

`stop-gate.sh` is the single largest gate in the system and is the mechanism
that blocks turn-end pending review; `lib/benign-command.sh` is the shared lexer
both textual gates depend on. Neither is covered.

---

## User Stories

1. As a developer, I want an edit to a hot gate file to return control in under
   two seconds, so that I am not waiting three and a half minutes for a reporter
   that cannot block me anyway.
2. As a developer, I want microworld results to still reach me, so that making
   the rerun asynchronous does not silently become "turning it off."
3. As a developer, I want a broken bundle to surface at the next stop boundary
   with the same unit/result/file detail it reports today, so that I lose no
   diagnostic information to the latency fix.
4. As a developer, I want two edits in quick succession to the same watched file
   not to pile up unbounded background jobs, so that the async queue cannot
   become its own resource problem.
5. As a developer, I want the microworld dashboard to keep working unchanged, so
   that the audit-log consumer contract survives the rewrite.
6. As a developer, I want `stop-gate.sh` to skip its 102-second suite run when
   the rerun queue already recorded a clean pass covering every changed file, so
   that I stop paying twice for the same evidence.
7. As a developer, I want that skip to be provably non-vacuous, so that
   "cheaper" never quietly means "no longer checking."
8. As a reviewer persona, I want my own independent pre-PASS verification to be
   completely untouched by every change in this spec, so that the one trusted
   run in the system stays trusted.
9. *(→ spec 1, Step 5)* As an agent that hits a gate, I want a denial message
   that tells me the fix in under 120 words, so that recovering from a block
   costs a fraction of a turn rather than 542 tokens.
10. *(→ spec 1, Step 5)* As an agent that hits a gate, I want the general
    bypass-reasoning essay to live in a document the message *points at*, so that
    I can read it when I need it and not pay for it every time.
11. As an agent writing a verdict marker, I want a single-call helper, so that
    the sanctioned workaround stops costing an extra turn per marker.
12. *(→ spec 1, Step 5)* As an agent, I want a known ratified false-positive
    class to cost me a short message naming the issue, not a long one re-deriving
    why it is unfixed.

    *Stories 9, 10 and 12 are retained rather than deleted: they are the
    user-facing statement of the need that §B3 measured, and spec 1's Step 5
    inherits them along with the word budgets. Story 11 is Unit C's.*
13. As a developer, I want a re-runnable script that reports spend per model tier
    and FAIL rate per tier, so that the writer-tier decision is evidence-driven
    rather than re-argued each time.
14. As a developer, I want that script to answer the exact question ADR-0010
    deferred, so that a ratified bet finally gets settled against data.
15. As a developer, I want the writer-tier decision recorded as an ADR amendment
    with its measured basis, so that the next person to revisit it inherits the
    numbers and not just the conclusion.
16. As a developer, I want the writer tier to be consistent across every surface
    that states it, so that frontmatter, orchestrator policy, README, and CONTEXT
    cannot drift apart.
17. As a developer, I want no reintroduction of pre-emptive "this unit looks
    mechanical" tagging, so that a measured 0 %-reachable mechanism is not
    rebuilt.
18. As a developer, I want every gate script to be either protected or explicitly
    and reasonedly unprotected, so that the coverage of the cheapest gate is a
    decision rather than an accident.
19. As a developer, I want the harness's own cost characteristics to be
    measurable by a command, so that "feels faster" is never the standard of
    proof for a change made in this spec.
20. As a developer, I want each latency fix to declare its measured before-value,
    so that a regression is detectable rather than merely suspected.
21. As a maintainer, I want every hook change to land in the adapter mirrors and
    the adapted in-repo copy together, so that the Cursor and Codex ports do not
    silently diverge.
22. As a developer, I want deferred bundle results to keep reaching me after
    review-gating is switched off, so that making the rerun asynchronous does not
    become making it invisible.
23. As a developer, I want a stale bundle failure announced once rather than at
    every session start, so that the backstop channel does not become noise I
    learn to ignore.
24. As a maintainer, I want the writer-tier change to bump the plugin version and
    actually re-render the adapted mirrors, so that the repo's live personas
    match the decision the ADR records rather than silently keeping the old
    default.
25. As a developer, I want the cost-accounting figures to be re-derivable months
    later, so that the evidence behind a ratified reversal can be audited rather
    than taken on trust.

---

## Implementation Decisions

### Seams

Existing seams are preferred throughout; **exactly one new seam** is introduced
(Unit D's accounting script), and it is modelled directly on two pieces of prior
art rather than invented.

| Unit | Seam | Status |
|---|---|---|
| A | `hooks/scripts/microworld-rerun.sh` + its audit-log line format | Existing |
| B | `stop-gate.sh` step 4 (`testAndLintCommand` invocation) | Existing |
| C | each gate's single `deny()` / block-message site | Existing |
| D | a deterministic, read-only accounting script under `scripts/` | **New** |
| E | `protectedPaths` in `.claude/persona-config.json` + a coverage test | Existing |

### Unit A — Asynchronous microworld rerun

- The hook's contract changes from *run and report* to **enqueue and return**.
  Its licence for this is already in its own header: *"This is a REPORTER, not a
  gate."*
- **The audit-log line format is a frozen consumed interface.** The format
  `<timestamp> unit=<slug> result=<pass|fail|timeout|error> file=<path>` is
  parsed by `bin/dashboard/audit-log.js` and mutation-proved by
  `tests/microworld-audit-contract.test.js`. The async rewrite must emit
  byte-identical lines. This is the single hardest constraint on the unit and
  the reason the audit log — not a new IPC channel — is the queue's result
  surface.
- **Deduplication within a single edit is in scope and is the cheapest win
  available.** Because several bundles invoke the same suite, the enqueue step
  must collapse the *set of suites to run* rather than the *set of bundles*, or
  the async version merely moves 212 s of duplicated work off the critical path
  instead of eliminating it. Bundle-level results must still be logged per
  bundle, so the dashboard sees no change.
- **Coalescing across edits**: a pending enqueue for a file whose run has not
  started is replaced, not appended. An in-flight run is allowed to finish; at
  most one queued run and one in-flight run per bundle may exist.
- **Result surfacing** happens at the next `Stop`/`SubagentStop`. `stop-gate.sh`
  already runs at both and already writes to stderr, so it is the natural
  reporting point and no new hook registration is needed — **but see the
  survivability requirement immediately below, which is load-bearing.**

#### Surfacing must survive spec 6's gate-silencing flip (REQUIRED)

`stop-gate.sh` is one of the ten gates that spec 6's `reviewGating.mode: off`
silences. If Unit A's only reporting channel is a hook that the flip turns off,
then **the moment spec 6 lands, deferred bundle results go dark with nothing
reading them** — and async-without-surfacing is strictly worse than today's
synchronous blocking, because breakage becomes invisible rather than merely
slow. That is precisely the "feedback nobody sees" failure that let CI stay red
for a week, rebuilt in a new place. Unit A must therefore satisfy **both** of:

1. **Primary — the mode-off early exit reports before it exits.** `stop-gate.sh`
   is a gate *and* a reporter, and only its gating half is what
   `reviewGating.mode: off` is meant to silence. Its mode-off path must run the
   deferred-result reporting half **first**, then take the early exit. Reporting
   is not gating: it writes to stderr and never changes the exit status, so this
   preserves spec 6's intent exactly while keeping same-session feedback alive.
   This is the channel that matters, because it is the only one that reports
   results **in the session that caused them**.
2. **Backstop — `session-start.sh` surfaces anything still unreported.** It is an
   exempt reporter under spec 6, already emits
   `hookSpecificOutput.additionalContext`, and already accumulates messages in a
   `context_parts` array — so an unreported-results line is a small, idiomatic
   addition to an existing channel, not a new mechanism.

**Why both, stated honestly:** `SessionStart` fires at the *start* of a session,
so on its own it reports a bundle broken by this session's edits only at the
*next* session — too late to be the primary channel, and the reason (1) is
mandatory rather than optional. But it is the right backstop, because it is the
one channel that still fires if `stop-gate.sh` is silenced more aggressively
than expected, or removed outright by a later spec. Results must therefore be
marked **reported** when surfaced, so the backstop reports each result once and
does not re-announce stale breakage every session.

**Dependency note, not a scope claim:** requirement (1) describes behaviour that
spec 6's own early-exit path must have. If spec 6 has already landed when Unit A
is dispatched, this is an edit to *its* code and must be coordinated with that
spec's owner rather than applied unilaterally. If Unit A lands first, it should
leave the reporting half structured so that a later mode-off early exit can be
inserted *after* it. Either way, **this spec does not redesign spec 6's
mechanism** — it states one property its early-exit path must preserve.
- **Failure posture is unchanged**: infrastructure problems (no `jq`, malformed
  manifest, missing `run.sh`) are logged and exit 0; only a genuine bundle
  failure or timeout is surfaced. Async adds one new infrastructure case — the
  queue itself being unwritable — which takes the same log-and-exit-0 path.
- **Mirrors**: `adapters/cursor/hooks/scripts/microworld-rerun.sh` and
  `adapters/codex/hooks/scripts/microworld-rerun.sh` both exist and must move
  together, per `tests/microworld-rerun.test.sh`'s existing adapter cases.

### Unit B — Cheapen the redundant stop-gate run

- `stop-gate.sh` step 4 gains a **precondition**: if the rerun queue recorded a
  clean pass for every bundle watching every file changed since the session
  baseline, and no edit has landed since those passes, skip
  `testAndLintCommand` and log the skip.
- **The skip is conservative and fails closed.** Any file changed since baseline
  that no bundle watches, any bundle result that is `fail`/`timeout`/`error`,
  any unreadable queue state, or any missing timestamp → run the full command as
  today. A skip must be *provable*, never assumed.
- **The skip is logged** to `.claude/review-audit.log` with a distinct token, so
  the audit trail distinguishes "checked and passed" from "skipped because
  already checked" — these must never be conflated after the fact.
- **The reviewer's own run is out of scope and must not be touched.** No change
  to `agents/reviewer.md`'s independent-verification clause, and no mechanism
  that lets a reviewer consult the queue in place of running the checks itself.
  This is a hard constraint, verified by AC-B4.

### Unit C — Denial-message and workaround cost

> **SCOPE REDUCED (spec 5, ruling E9).** Spec 5 found that this unit and
> **spec 1's Step 5** independently rewrite the *same* stderr shape in
> `reviewed-path-gate.sh` and `human-decision-gate.sh` — an uncoordinated
> collision. The ruling: **spec 1's Step 5 lands first and owns the message
> rewrite.** Unit C is reduced to **its marker-writing-helper deliverable
> only**. Confirmed and applied here.
>
> The message-size analysis in §B3 is **retained as evidence** — it is the
> measurement that motivated Step 5, and AC-C1's word budgets are handed to
> spec 1 rather than deleted. What changes is who implements them.

**In scope for Unit C: the single-call marker-write helper, and nothing else.**

- **The two-call dance collapses to a helper.** A single invocable command takes
  verdict, unit id, commit, and criteria, and writes a format-valid marker —
  such that invoking it is not itself denied by either gate. Prior art for a
  deterministic, orchestrator-invoked, non-hook helper under `hooks/scripts/` is
  `reviewer-tier.sh`; prior art for a user-facing script under `bin/` is
  `bin/marker-commit-audit.sh`. The helper must produce markers that satisfy the
  existing `marker_format_valid()` check in `stop-gate.sh` and `marker_valid()`
  in `task-gate.sh` — one definition of a valid marker, not a third.
- **No gate's trigger logic changes in this unit**, and after the E9 reduction
  **no gate's message text changes in this unit either**. Anything that alters
  what is blocked belongs to the sibling trust spec; anything that alters what a
  gate *says* belongs to spec 1's Step 5.
- **Ordering against spec 1.** The helper is independent of the message rewrite
  and does not have to wait for it — the two touch disjoint code (a new script
  vs. existing `deny()` bodies). If spec 1's Step 5 slips, Unit C still lands.
  What must *not* happen is Unit C re-editing a message Step 5 owns.

### Unit D — Writer-tier re-pricing

- **Deliverable 1: a cost-accounting script.** Read-only, deterministic, exits 0,
  emits a stable machine-parseable report of per-model spend and per-tier FAIL
  rate from the transcript corpus and `.claude/reviewed/`. Modelled on
  `scripts/agent-audit.sh` — which already extracts the dispatched model per
  agent from transcript records and is the natural place for this to live or
  attach.
- **Deliverable 2: the decision, recorded as an ADR amending ADR-0010**, quoting
  the measured spend split and FAIL-rate split, recording the ratification below,
  and explicitly noting the confounds in the pre/post comparison.
- **Deliverable 3: consistent propagation** of the ratified tier across
  `agents/lead-programmer.md` frontmatter, `agents/orchestrator.md` dispatch
  policy, `agents/task-master.md` tagging rules, `README.md`'s persona table,
  and `CONTEXT.md`. Prior art for enforcing exactly this kind of cross-surface
  consistency: `tests/protocol-cross-references.test.js` and
  `tests/protocol-doc-drift.test.js`.

#### The decision (RATIFIED)

> **`lead-programmer` defaults to `sonnet`, not `haiku`. ADR-0010's
> implementer-haiku default is reversed.**
>
> **Ratified by:** the user (repo owner), in the spec-master session of
> **2026-08-25**, on the measured accounting in §B4 of this spec — haiku at
> **4.6 % of total spend ($207.29 of $4,520.80)** against a FAIL rate that
> roughly doubled across ADR-0010 (**16.7 % pre → 32.5 % post**). The
> confounds in that comparison (marker-mtime proxy, differing unit
> populations, 66 vs 203 samples) were **disclosed to and acknowledged by the
> ratifier**; the decision was taken with them on the record, not in ignorance
> of them.

This resolves what was Open Question 1 in the pre-ratification draft of this
spec. Unit D no longer carries a decision to be made — it carries a decision to
be **implemented and then monitored**.

Two constraints ride along with the ratification:

- **No predictor is reintroduced.** Option (b) from the originating critique —
  reserving `haiku` for `task-master`-tagged mechanical units — is **rejected on
  the record**, not merely unchosen. ADR-0009 and ADR-0010 both document that
  pre-emptive tier prediction reached ~0 % of units in practice; rebuilding it
  would re-run a measured failure. `task-master` keeps tagging reactively, and
  the tag's default value changes from `haiku` to `sonnet`.
- **The existing reactive escalation ladder is retained**, not replaced. A
  `.fail` record still ratchets a unit's implementer tier — the ladder simply
  starts one rung higher (`sonnet` → `opus` on FAIL, rather than
  `haiku` → `sonnet` → `opus`). The reviewer-gate ratchet in `reviewer-tier.sh`
  is untouched by this unit.

#### Constitution check: Unit D triggers the version-stamp MUST

Unit D edits **three version-stamped `agents/*.md` files**
(`lead-programmer.md`, `orchestrator.md`, `task-master.md`), which puts it
squarely under `.claude/constitution.md` **Principle 3, "Version-stamp
discipline (MUST)"**: *"Any change to a version-stamped file (`agents/*.md`,
templates) must bump `.claude-plugin/plugin.json`'s version and add a CHANGELOG
entry, since the `--update` mechanism depends on the version actually changing
when content does."*

No other unit in this spec touches `agents/*.md` — Units A, B and E are hooks,
Unit C after its E9 reduction is a new script, and AC-B4 requires
`agents/reviewer.md` to stay byte-identical. **So this obligation is Unit D's
alone**, and all four parts land in **Unit D's own commit alongside the ADR**:

1. **Bump `.claude-plugin/plugin.json`** from its current **`0.31.63`**.
2. **Add a CHANGELOG entry** describing the tier reversal and naming the ADR.
3. **The new ADR is `docs/adr/0026-*`** — `0025` is currently the highest, and
   `0026` is what AC-D4's ADR-0010 amendment should be numbered.
4. **Regenerate the adapted mirrors** with
   **`node bin/cli.js --update --force-render`**.

**The `--force-render` flag is not optional, and this is the step most likely to
be skipped.** Verified on disk: `bin/cli.js:1269` returns early when
`config.pluginVersion === version` unless `forceRender` is set, and
`bin/cli.js:1222` shows `--force-render` is one of only three ways to set it. So
a plain `--update` run *after* the version bump in step 1 sees a matching version
and **exits without re-rendering** — silently leaving `.claude/agents/*.md` and
`persona-config.json`'s `fileHashes` stale, with the repo's own live personas
still carrying the reversed `haiku` default. The bump would appear to have landed
while the running system had not changed at all.

Note the interaction with Principle 2 ("Prefer deterministic scripts over LLM
re-derivation"): the mirrors and `fileHashes` are script-driven and **must not be
hand-edited** to work around a skipped regen.

#### The accounting script is a standing tool, not a one-off justification

Deliverable 1 **survives the ratification and is not descoped by it.** Its job
changes from *informing* the decision to *verifying* it:

- The pre/post evidence that motivated the reversal is retrospective and
  confounded. The script's forward role is to establish whether the reversal
  **actually improves the FAIL rate going forward**, on a population measured
  under one consistent policy rather than split across a policy change.
- The **decision rule is pre-registered now, before the post-reversal data
  exists**, so the reversal cannot be retroactively justified by whatever the
  numbers happen to show: *if, after ≥60 units dispatched under the `sonnet`
  default, the FAIL rate has not fallen below the 32.5 % haiku-era rate, the
  reversal has not delivered its predicted benefit and ADR-0010's amendment must
  be revisited rather than defended.* Recording this commitment is itself part
  of Deliverable 2.
- A falling FAIL rate is necessary but not sufficient: the script must also show
  total spend not materially worsening, since a `sonnet` writer costs ~3× a
  `haiku` one per attempt (§B4 pricing). The bet being ratified is that fewer
  opus re-reviews more than pay for that.

### Unit E — `protected-paths.sh` coverage vs. risk class

- The unit is **coverage allocation only**, not a gate redesign. Adding Bash-text
  scanning to this gate is explicitly **out of scope** (see "Relationship to
  sibling specs").
- Every script under `hooks/scripts/` must be either listed in `protectedPaths`
  or recorded in a declared, reasoned exemption list. The point is that the
  set becomes a decision with a rationale attached, rather than the current
  situation where 6 of 8 gates are uncovered with no recorded reason.
- The existing 19-word denial message is already terse and is left as is.

### Sequencing

- **A → B.** Unit B's skip precondition reads the queue state Unit A introduces;
  B cannot be specified against the current synchronous hook.
- **A → D (measurement only).** Unit D's accounting script should be run once
  before and once after A and B land, so the latency and cost changes are
  attributable. D's decision is already ratified and blocks on nothing; only its
  *forward verification* benefits from A and B having landed first.
- **D is now dispatchable immediately.** In the pre-ratification draft its
  Deliverable 3 was held behind a human ruling. That ruling has been given, so
  D's three deliverables can proceed in one unit.
- **C and E are independent** of the others and of each other.

### Cross-cutting implementation constraints

- **Every hook change is a four-copy change**: `hooks/scripts/` (plugin source),
  `.claude/hooks/scripts/` (this repo's adapted copy, hash-tracked in
  `persona-config.json`'s `fileHashes` and resynced by `bin/cli.js --update`),
  and the `adapters/cursor/` and `adapters/codex/` mirrors where that script
  exists. `microworld-rerun.sh`, `stop-gate.sh` and `protected-paths.sh` all
  have adapter mirrors; `reviewed-path-gate.sh` and `human-decision-gate.sh` do
  not. `tests/cli-hook-propagation.test.js` and
  `tests/adapter-stop-gate-parity.test.sh` already guard this.
- **The plugin-snapshot drift observed during drafting is resolved.** While this
  spec was being written, the installed plugin cache was at **0.31.57** while the
  repo's `persona-config.json` recorded **0.31.63**, leaving it ambiguous which
  copy of a hook was actually live. `claude plugin update` has since been run and
  both are now at **0.31.63**. Implementers can treat the repo source as
  authoritative; no reconciliation step is needed before starting.
- **Every unit in this spec draws an `opus` reviewer, unavoidably.**
  `hooks/scripts/reviewer-tier.sh`'s `SENSITIVE_PATHS` includes `^hooks/`,
  `^\.claude/hooks/`, `^adapters/.*hooks`, `^agents/` and `^\.claude/agents/`.
  This is correct and must not be worked around — but it means the spec's own
  implementation cost is high, which strengthens rather than weakens the case
  for landing it once, carefully. **This assumes `reviewer-tier.sh` still governs
  reviewer model selection when these units land — which sibling spec 6 may
  change; see the coordination point below.**
- **New tests must be registered in `tests/validate.sh`**, per existing
  convention — and note the second-order effect: every suite added there is a
  suite that runs in the 102.56 s stop-gate command. Units A and B should not
  make B2 worse by adding long-running suites; prefer fast, targeted cases.

---

## Testing Decisions

**What makes a good test here.** Every criterion below is a command whose exit
status decides the question, testing externally observable behaviour — measured
latency, measured message size, emitted log lines, gate exit codes — never
internal structure. Per this repo's `mutation-proved` convention (CONTEXT.md),
each criterion that asserts a *cheapening* must additionally be shown
non-vacuous by running it against a deliberately corrupted artifact and
confirming it fails.

**Prior art followed:**
- `tests/microworld-rerun.test.sh` — executes the real hook with canned hook-input
  JSON; carries adapter cases for both mirrors.
- `tests/microworld-audit-contract.test.js` — cross-language contract test with an
  explicit mutation proof on the log separator.
- `tests/reviewer-tier.test.sh` — deterministic script with fail-closed cases.
- `tests/adapter-stop-gate-parity.test.sh` — mirror parity.
- `tests/protocol-cross-references.test.js`, `tests/protocol-doc-drift.test.js` —
  cross-surface consistency.

**Measurement harness.** Units A and B need a small, committed timing harness so
their criteria are re-runnable by anyone rather than depending on a one-off
script. It must invoke the *real* hooks with canned input against *existing*
files, modify no repo file, report p50 over ≥5 iterations, and exit non-zero
when a declared budget is exceeded.

### Acceptance criteria

Each is a runnable check with a measured before-value.

**Unit A — async rerun**

- **AC-A1** *(latency)*: with the harness, editing `tests/human-decision-gate.test.sh`
  returns from `PostToolUse` in **p50 ≤ 2.0 s and p99 ≤ 5.0 s** over ≥5
  iterations. *Before: 211.96 s.* Same budget for
  `hooks/scripts/human-decision-gate.sh` (*before: 158.89 s*) and
  `hooks/scripts/reviewed-path-gate.sh` (*before: 115.85 s*).
- **AC-A2** *(contract preserved)*: `node tests/microworld-audit-contract.test.js`
  passes **with the test file unmodified**, and its existing separator-mutation
  proof still fails the test when applied.
- **AC-A3** *(results still surface)*: a bundle seeded to fail, triggered by an
  enqueue, produces the broken-bundle report on stderr at the next
  `Stop`/`SubagentStop` with exit 2, naming the same slug the synchronous hook
  named. Verified by executing the real hooks against a fixture.
- **AC-A4** *(dedup)*: one enqueue for `hooks/scripts/human-decision-gate.sh`
  executes `tests/human-decision-gate.test.sh` **exactly once**, while still
  emitting one audit line per matched bundle (3 lines). *Before: 3 executions.*
  Asserted by counting suite invocations, not by timing.
- **AC-A5** *(bounded queue)*: 10 rapid enqueues for the same file yield **at
  most one in-flight and one queued run per bundle**; no orphaned process
  survives the test.
- **AC-A6** *(mirrors)*: `bash tests/microworld-rerun.test.sh` passes, including
  its Cursor and Codex adapter cases, and `node tests/cli-hook-propagation.test.js`
  passes.
- **AC-A7** *(fail-open preserved)*: with `jq` absent, a malformed `manifest.json`,
  a missing `run.sh`, or an unwritable queue, the hook logs and exits **0**.
- **AC-A8** *(surfacing survives gate-silencing — the key one)*: with
  `reviewGating.mode: off` set, a failed bundle result enqueued during the
  session is **still reported on stderr** at the next `Stop`/`SubagentStop`, and
  the stop **still exits 0** (reporting, not gating). Both halves are asserted:
  a version that reports but blocks has broken spec 6, and one that exits
  cleanly without reporting has recreated the invisible-breakage failure this
  requirement exists to prevent.
- **AC-A9** *(backstop reports, and reports once)*: with the stop-path reporting
  suppressed entirely, `session-start.sh` surfaces the unreported failed-bundle
  result in its `additionalContext`; after it has been surfaced once, a second
  `SessionStart` with no new results does **not** re-announce it. Prevents the
  backstop from degrading into per-session noise about stale breakage.
- **AC-A10** *(mutation proof for A8)*: reverting the mode-off reporting hook
  makes AC-A8 fail. Without this, AC-A8 could pass vacuously on a build where
  `reviewGating.mode: off` was never actually honoured.

**Unit B — cheapen the stop-gate run**

- **AC-B1** *(skip works)*: after a clean enqueue-run covering every changed file,
  a gated `SubagentStop` completes in **≤ 5.0 s**. *Before: 102.56 s.*
- **AC-B2** *(skip is logged distinctly)*: that stop appends a line to
  `.claude/review-audit.log` bearing a skip token distinct from every existing
  token, so "passed" and "skipped" are separable in the audit trail.
- **AC-B3** *(mutation proof — non-vacuous)*: with the tree mutated so
  `tests/validate.sh` fails, and with a *stale* clean queue record standing,
  `stop-gate.sh` **still blocks (exit 2)**. Reverting the fix must make this case
  fail — the criterion is void otherwise.
- **AC-B4** *(reviewer untouched — hard constraint)*: `agents/reviewer.md`'s
  independent-verification clause is byte-identical to HEAD `09cc304`, asserted
  by hash; and no code path added in this spec reads queue state on behalf of a
  reviewer identity. Checkable by diff plus a grep assertion.
- **AC-B5** *(fails closed)*: a changed file watched by no bundle, an
  unreadable queue, or any non-`pass` bundle result each force the full
  `testAndLintCommand` run.
- **AC-B6** *(parity)*: `bash tests/adapter-stop-gate-parity.test.sh` passes.

**Unit C — message and workaround cost**

*Scope reduced per spec 5's E9 ruling — the message-rewrite criteria below are
**handed to spec 1's Step 5**, not dropped. They are retained here, marked, so
Step 5 inherits concrete budgets against measured baselines rather than
re-deriving them.*

- **AC-C1 → SPEC 1 / STEP 5** *(size)*: executing each gate with canned blocking
  input yields stderr of **≤ 120 words** for `reviewed-path-gate.sh` Bash
  (*before: 357*) and **≤ 100 words** for `human-decision-gate.sh` Bash
  (*before: 230*). No gate's denial message exceeds **150 words**. Asserted by a
  committed test that runs the gates and counts words, so it cannot drift.
- **AC-C2 → SPEC 1 / STEP 5** *(actionability retained)*: each shortened message
  still contains its concrete remediation — the sanctioned marker-write template
  for `human-decision-gate.sh`, the `git commit -F <file>` / `grep -r` remedies
  for `reviewed-path-gate.sh` — asserted by substring match.
- **AC-C3 → SPEC 1 / STEP 5** *(behaviour unchanged)*:
  `bash tests/human-decision-gate.test.sh` and
  `bash tests/reviewed-path-gate.test.sh` pass unmodified. Exactly the same
  commands are allowed and denied as at HEAD `09cc304`; only the text differs.

*The two criteria below are Unit C's actual, reduced deliverable:*

- **AC-C4** *(single-call helper)*: one invocation of the helper writes a
  format-valid marker, **is not denied** by `reviewed-path-gate.sh` or
  `human-decision-gate.sh`, and the resulting marker satisfies
  `stop-gate.sh`'s `marker_format_valid()`. *Before: two calls.*
- **AC-C5** *(helper cannot forge)*: the helper refuses to write a marker for a
  malformed unit id or a missing commit, and provides no capability the reviewer
  identity does not already have — it is an ergonomics wrapper, not a new
  privilege.
- **AC-C6** *(scope guard — the E9 collision cannot recur)*: Unit C's own commit
  leaves the `deny()` bodies and every stderr string in `reviewed-path-gate.sh`
  and `human-decision-gate.sh` **byte-identical**, asserted by hash. This is the
  criterion that makes the E9 reduction verifiable rather than merely stated —
  without it, "Unit C was narrowed" is an intention, not a fact. Mirrors AC-E3's
  role for Unit E.

**Unit D — writer-tier re-pricing (ratified: `haiku` → `sonnet`)**

- **AC-D1** *(script runs)*: the accounting script exits 0 and emits per-model
  spend and per-period FAIL rate in a stable, parseable format; it writes nothing
  outside its own output.
- **AC-D2** *(reproduces the baseline — requires a corpus cutoff)*: the script
  **must accept an explicit upper cutoff** (e.g. `--until <ISO-8601>`) bounding
  which transcript records and which `.claude/reviewed/` markers it counts.
  Invoked with the cutoff **`2026-08-25T00:00:00Z`**, it reports the §B4 figures
  within a stated tolerance — haiku share 4.6 %, opus share 58.6 %, pre/post FAIL
  rates 16.7 % / 32.5 %.

  **The cutoff is what makes this criterion a criterion at all.** Unlike the
  latency and message-size baselines, the corpus this one reads is **not
  versioned by the repo**: `~/.claude/projects/-home-sebas-AntiSlop/` grows with
  every session, including the sessions that implement this very spec. Pinning
  the git SHA does not pin the corpus. Without a cutoff, an unbounded run drifts
  the moment anyone works in the repo, and the criterion would be unreproducible
  the day after it was written — failing not because the script is wrong but
  because the world moved. Records must be bounded by their own `timestamp`
  field and markers by mtime, not by file mtime alone, so that a transcript
  rewritten later still lands in the period it belongs to.
- **AC-D3** *(deterministic)*: two consecutive runs **at the same cutoff** over a
  corpus that has since grown produce identical output — which is the real test
  of AC-D2's mechanism, not merely of ordering stability.
- **AC-D4** *(decision + ratification recorded)*: an ADR exists amending
  ADR-0010, naming the measured basis, **the ratifier and ratification date
  (the user, 2026-08-25)**, and the acknowledged confounds; ADR-0010 links
  forward to it and its status reflects that it has been amended.
- **AC-D5** *(the ratified tier is live and consistent)*: a test asserts the
  writer tier reads **`sonnet`** — not merely "the same value" — across
  `agents/lead-programmer.md` frontmatter, `agents/orchestrator.md`,
  `agents/task-master.md`, `README.md`, and `CONTEXT.md`, following
  `tests/protocol-cross-references.test.js`. A consistency-only check would pass
  on a repo that never applied the reversal, so the literal is asserted.
- **AC-D6** *(no predictor reintroduced)*: a grep assertion that no surface
  instructs pre-emptive "looks mechanical" tier tagging, preserving ADR-0010 §2's
  ruling under the new default.
- **AC-D7** *(escalation ladder starts one rung higher)*: `agents/orchestrator.md`
  no longer instructs a `haiku` → `sonnet` first-FAIL escalation; a FAIL on a
  default-tier unit escalates `sonnet` → `opus`. Asserted by grep, because a
  stale `haiku` → `sonnet` rule would silently re-introduce the reversed default
  on exactly the retry path that motivated the reversal. *This is the most
  likely way for the reversal to be applied incompletely.*
- **AC-D8** *(forward-verification rule is on record, not just intended)*: the
  ADR from AC-D4 states the pre-registered rule verbatim — *after ≥60 units under
  the `sonnet` default, a FAIL rate not below 32.5 % means the reversal has not
  delivered its predicted benefit and must be revisited* — together with the
  spend-neutrality condition. Asserted by substring match, so the commitment
  cannot quietly evaporate once post-reversal numbers exist.
- **AC-D9** *(Constitution Principle 3 satisfied)*: Unit D's commit contains a
  `.claude-plugin/plugin.json` version strictly greater than **`0.31.63`**, a new
  CHANGELOG entry naming the ADR, and the ADR at `docs/adr/0026-*`. Checkable by
  diffing the commit.
- **AC-D10** *(the regen actually re-rendered — the skip-prone step)*: after
  `node bin/cli.js --update --force-render`, every `.claude/agents/*.md` mirror
  affected by the tier change reads **`sonnet`**, and `persona-config.json`'s
  `fileHashes` match the rendered files on disk. **Mutation proof: running plain
  `node bin/cli.js --update` instead must leave at least one mirror stale**,
  demonstrating the early-return at `bin/cli.js:1269` is real and that
  `--force-render` is doing the work. Without this proof the criterion passes on
  a repo where the regen silently no-opped.

**Unit E — protected-paths coverage**

- **AC-E1** *(coverage is total and reasoned)*: a test enumerates every `*.sh`
  under `hooks/scripts/` (including `lib/`) and asserts each is either matched by
  a `protectedPaths` pattern or present in a declared exemption list with a
  non-empty reason. *Before: 16 scripts enumerated, 2 covered (both of them
  enforcement gates, out of 8), 0 reasoned exemptions.*
- **AC-E2** *(gate still works)*: executing `protected-paths.sh` against a
  newly-covered path returns exit 2; against an exempt path, exit 0.
- **AC-E3** *(no scope creep)*: `protected-paths.sh` remains `Write|Edit`-only —
  a test asserts a Bash payload naming a protected path still exits 0 here, so
  this unit demonstrably did not absorb the sibling trust spec's work.
- **AC-E4** *(mirrors)*: the Cursor and Codex mirrors stay in parity.

---

## Out of Scope

- **The reviewer's independent pre-PASS verification.** Untouched by every unit;
  AC-B4 exists specifically to prove it.
- **Adding Bash-text scanning to `protected-paths.sh`**, or any redesign of what
  a gate blocks. Unit E is cost allocation only.
- **Changing any gate's trigger logic**, allowlist, or lexer. Unit C is message
  text plus a helper.
- **The reviewer-tier mechanism** (`reviewer-tier.sh`, ADR-0009, the
  reviewer-gate ratchet). Only the *writer* tier is re-priced.
- **Removing the microworld rerun hook, or the bundles themselves.** The
  Microworlds workflow redesign is a sibling spec; this spec takes the current
  bundle set as given and only changes *when* it runs.
- **Reducing the number of registered gates, or the review protocol's ceremony**
  — the sibling ceremony spec's territory.
- **`maxTurns` re-tuning.** Named in the critique's framing but not a measured
  cost driver here; changing it without evidence would repeat ADR-0010's mistake.
- **Retroactive cost attribution per persona.** The transcript corpus supports
  per-*model* attribution (used in B4); per-*persona* attribution needs dispatch
  records and is a nice-to-have for the Unit D script, not a requirement.
- **Pruning `.claude/` accumulated state** (120 `.session-baseline.*` files
  stand at HEAD). Real, but housekeeping, not a throughput dampener.

## Relationship to sibling specs

- **Streamlining spec — async rerun.** Its async-rerun item is the same mechanism
  as Unit A. This spec's criteria are scoped to the **latency dimension only**
  (AC-A1's p50 budget against a measured 211.96 s baseline). If the streamlining
  spec also lands an async design, these are one unit, not two — coordinate
  rather than implement twice.
- **Trust-gap spec — `protected-paths.sh`.** Finding 5 is genuinely both. Unit E
  is deliberately confined to "a cheap gate is the sole guard over surfaces
  nobody priced it for," and AC-E3 asserts the gate's `Write|Edit`-only scope is
  *unchanged*, so the two specs cannot collide.
- **Spec 1, Step 5 — denial messages. RESOLVED COLLISION (spec 5, ruling E9).**
  Unit C and spec 1's Step 5 independently rewrote the same stderr shape in
  `reviewed-path-gate.sh` and `human-decision-gate.sh`. **Step 5 lands first and
  owns that rewrite; Unit C is reduced to the marker-write helper.** Applied
  throughout this spec: the Solution bullet, the Unit C section, and AC-C1–C3
  (retained but marked as handed to Step 5, so Step 5 inherits §B3's measured
  budgets instead of re-deriving them). **AC-C6 asserts the reduction held** —
  Unit C's commit must leave both gates' stderr byte-identical.
- **Ceremony spec — gates.** Unit C no longer touches gate messages at all, so
  the remaining interaction is narrow: if the ceremony spec removes a gate
  outright, the marker-write helper may lose part of its reason to exist and
  should be re-scoped rather than merged.
- **Sibling spec 6 (CI-shaped review), touchpoint 1 of 2 — Unit A's reporting
  channel. HARD DEPENDENCY, not just a note.** `stop-gate.sh` is one of the ten gates spec 6's
  `reviewGating.mode: off` silences, and it is Unit A's primary surfacing point.
  See "Surfacing must survive spec 6's gate-silencing flip" — Unit A must report
  from the mode-off early-exit path *and* carry a `session-start.sh` backstop,
  verified by AC-A8/A9/A10. This is a **property spec 6's early exit must
  preserve**, coordinated with that spec's owner; this spec does not redesign
  spec 6's mechanism.
- **Sibling spec 6 (CI-shaped review), touchpoint 2 of 2 — `reviewer-tier.sh`.
  COORDINATION POINT, not a scope claim.** *(Distinct from touchpoint 1: that one
  is a behaviour Unit A depends on; this one only affects a cost note.)* Spec 6 was adopted as a **full replacement for this
  repo's own gate enforcement** after this spec was drafted. This spec touches
  `reviewer-tier.sh` **nowhere** — it is listed under "Out of Scope" and Unit D's
  ratified decision explicitly leaves the reviewer-gate ratchet untouched. But
  this spec *depends* on it in one place, and that dependency must be checked
  before dispatch:

  > This spec's cross-cutting note "every unit here draws an `opus` reviewer"
  > is derived from `reviewer-tier.sh`'s `SENSITIVE_PATHS`. **If spec 6's
  > headless reviewer invocation no longer consults `reviewer-tier.sh`, or
  > consults it differently, that note is stale** — the reviewer model for these
  > five units would then be decided by spec 6's mechanism instead, and the
  > dispatch-cost expectation set here must be re-derived from whatever spec 6
  > establishes.

  **This spec does not redesign, constrain, or take a position on spec 6's
  mechanism.** The flag is one-directional: whoever dispatches these units should
  confirm which mechanism is live at that moment and, if it is spec 6's, restate
  the reviewer-cost expectation accordingly. Nothing in Units A–E changes on
  either answer; only the cost note does.

## Open Questions

**OQ1 — RESOLVED (ratified 2026-08-25).** *Is a flat `sonnet` writer default the
right re-pricing, and who ratifies reversing a ratified ADR?*

**Answered: yes, and the user ratified it.** The decision, its basis, its
ratifier, and the acknowledged confounds are recorded in full under
"Unit D — The decision (RATIFIED)". `lead-programmer` defaults to `sonnet`;
ADR-0010's implementer-haiku default is reversed; option (b) from the critique
(reserving haiku for `task-master`-tagged mechanical units) is rejected on the
recorded ~0 %-reachability of pre-emptive tier prediction.

This entry is retained rather than deleted so the audit trail shows the question
was raised, the confounds were disclosed *before* the ruling, and the ruling was
made by a human rather than assumed by the spec. The pre-registered decision rule
that OQ1 proposed **survives the ratification** and is now a forward-verification
commitment on Unit D's Deliverable 1 — see "The accounting script is a standing
tool, not a one-off justification". Two questions remain genuinely open below.

**OQ2 — Where should the queue state live?**

`.claude/` is already crowded and largely gitignored. Reusing
`.claude/microworld-audit.log` as the sole result surface is attractive (it
preserves the dashboard contract for free) but the log is append-only and
carries no "in flight" state, so Unit A needs *some* additional state. Whether
that is a sibling file, a directory of per-bundle stamps (mirroring the existing
`.review-join.<unit>` stamp pattern in `reviewer-route-gate.sh`), or a lock
directory is an implementation choice this spec deliberately leaves open — but
whichever is chosen, **the audit log's line format stays frozen** (AC-A2).

**OQ3 — What is the acceptable staleness window for Unit B's skip?**

The skip requires "no edit since the recorded pass." Whether that is enforced by
mtime comparison, by content hash, or by requiring the queue to be fully drained
affects both safety and how often the skip actually fires. Mtime is cheapest and
matches the existing `prior_mtime` comparison in `stop-gate.sh`'s
`review_join_state()`; a content hash is stricter. AC-B3 and AC-B5 constrain the
answer (it must fail closed and must block on a stale record) without dictating
the mechanism.

## Further Notes

- **The strongest single datum in this spec is that haiku is 4.6 % of spend.**
  It is what carried the writer-tier reversal: the cheap tier is not where the
  money goes — re-verification is. The corollary is worth keeping in view after
  the reversal lands, because it cuts both ways: if the writer tier was never
  where the spend was, then moving it to `sonnet` cannot by itself make the
  system much cheaper either. The reversal is justified by the **FAIL cycles it
  avoids** — each one an extra `opus` review plus a full redispatch — not by the
  writer line item, which will now grow. AC-D2 and AC-D8 exist so that claim
  stays falsifiable.
- **The second strongest is 211.96 s.** That is not a tuning problem; a reporter
  that cannot block the agent should not be able to stall it for three and a half
  minutes either.
- **This spec was written under the conditions it describes.** Two
  `reviewed-path-gate.sh` denials (357 words, ~542 tokens each) were incurred
  while gathering the very evidence in B3, both for read-only operations. That is
  reported as data, not as complaint: the false-positive classes the message
  documents are the ones that actually fire.
- **Measurement method, for reproducibility.** Latency figures came from invoking
  the real hooks with canned hook-input JSON naming existing files; no repo file
  was modified and no marker or `DECISION` file was written or attempted. Spend
  figures came from summing `message.usage` across the transcript corpus at
  published rates. FAIL rates came from `.claude/reviewed/` marker names and
  mtimes. Every number is re-derivable from the commands described alongside it.
