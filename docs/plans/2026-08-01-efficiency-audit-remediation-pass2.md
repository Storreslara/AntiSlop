# Efficiency audit remediation — Pass 2 (fail-open closure + adapter-port drift)

Date: 2026-08-01
Status: Finalized spec, ready for `task-master` slicing
Amended: 2026-08-01 (A1 — operator rulings on both Open Questions. Both are
applied **in place** throughout this document, and **Amendment A1** at the end
records every edit exactly. Read the body as authoritative; A1 is the audit
trail, not a separate set of instructions to reconcile.)
Predecessor: `docs/plans/2026-08-01-efficiency-audit-remediation-pass1.md`
(shipped as v0.19.0; nothing it resolved is re-opened here)
Scope: the *verified* subset of Pass 1's "Pass 1 execution backlog". F4–F9, the
contradictions list, and the trigger-happiness list remain deferred — see
"Deferred to Pass 3" for which, and why each.

## Methodology (inherited from Pass 1's Amendment A4.2 — in force from Step 1)

These are not aspirations; they govern every step below and every dispatch
`task-master` writes from it. They are stated here so nobody re-derives them.

1. **One mutation control per mechanism, not per criterion.** Where several
   criteria on a step bind to the same code path, one throwaway copy and one
   revert-run-restore cycle is evidence for all of them. No per-criterion
   `cp -r`/worktree.
2. **The writer records evidence once; the reviewer's Tier 1 default is to
   re-run the writer's recorded commands and diff observed against claimed
   output** — not to re-derive from scratch. Tier 2 (independent from-scratch
   experiments) only on: Tier 1 disagreement, incomplete/suspicious evidence, a
   security-sensitive path, or a prior `.fail` record for that unit. Steps 1
   and 5 carry prior FAIL records (#192, #191) and therefore *do* start at
   Tier 2; every other step starts at Tier 1.
3. **Blast-radius explorer dispatch is conditional.** Skip it when the diff
   falls entirely inside the step's affected-files list below. Those lists were
   verified against the working tree during authoring and are exact.
4. **Dispatch prompts cite the issue; they do not re-paste context.** `Unit:`
   line, retrieval contract, and the delta since any prior attempt. Nothing else.
5. **`maxTurns` is already 50** for `lead-programmer` and `reviewer` (raised
   during Pass 1's `resume-cost-fix` unit). No step here proposes raising it.
   No step here is expected to need more; if one does, that is a signal the
   step is mis-sized and must route back to `spec-master`, not a signal to
   raise the cap.
6. **Cost ceiling is an acceptance property of this pass, not a wish.** Pass 1
   spent ~2.45M tokens against a ~30–40k projected saving. Pass 2's value is
   correctness (closing fail-open gaps on the review gate), not token savings,
   so it cannot be justified by savings arithmetic — which makes runaway
   verification cost the primary risk to manage. See R5.

## Goal

Close the **fail-open gaps and adapter-port drift that Pass 1's own mechanisms
left behind**. That single thesis is the scope boundary: an item is in Pass 2
iff it is (a) a mechanism Pass 1 built or touched, and (b) currently failing
open, silently diverged, or asserting something false about its own behaviour.
Anything else is Pass 3.

Every defect below was reproduced live during authoring — none is carried on
the backlog's word alone. Three backlog entries did **not** survive that
check and are corrected or dropped here (see Context).

**The acceptance bar is a fresh Fable re-audit confirming these are fixed, not
merely "criteria technically pass"** (operator ruling, 2026-08-01, mirroring
Pass 1's own bar). Step 8 is that gate and it is the last step. Per-step
criteria are necessary but not sufficient: a step whose criteria all pass but
whose mechanism the re-audit still finds failing open has not converged.

## Context — verified findings

### C-A. `reviewer-tier.sh` fails **open** three ways (prior FAIL: #192)

The script is the reviewer gate's measurement instrument. Fail-open here
under-reviews real work. All three reproduced:

**(a) `diff.relative` — worse than the backlog describes.** The backlog says a
`diff.relative=true` config "strips the cwd prefix, breaking `^`-anchored
patterns". Measured, the effect is stronger: the sensitive file *disappears
from the measurement entirely*, so both the path class **and** the line count
are wrong. Fixture: a repo whose HEAD~1..HEAD modifies `hooks/scripts/thing.sh`
and `sub/other.txt`.

```
from repo root, diff.relative unset      -> opus     (correct)
from sub/, diff.relative=true            -> sonnet   (WRONG)
  numstat seen there: "1  0  other.txt"  -- hooks/scripts/thing.sh invisible
```

**(b) `CLAUDE_PROJECT_DIR` fails open on the `.fail` disqualifier.**
`project_dir="${CLAUDE_PROJECT_DIR:-.}"` (`hooks/scripts/reviewer-tier.sh:56`).
If the marker directory is not under `.`, the lookup misses and the unit is
treated as having no FAIL record. Fixture: 1-file/1-line non-sensitive diff
with a live FAIL record for `u1`:

```
cwd = repo root, CLAUDE_PROJECT_DIR unset -> opus     (record found)
cwd = sub/,      CLAUDE_PROJECT_DIR unset -> sonnet   (WRONG — record lost)
cwd = sub/,      CLAUDE_PROJECT_DIR set   -> opus     (correct)
```

Note this is a *silent* loss: the script prints a normal `sonnet` and exits 0.

**(c) `agents/*.md` is not in `SENSITIVE_PATHS`.** Measured: a 1-file, 1-line
edit to `agents/reviewer.md` prints `sonnet`. The prose governing how deeply
everything else gets reviewed is itself sonnet-reviewable.

`SENSITIVE_PATHS` today (`reviewer-tier.sh:24-33`) covers `^hooks/`,
`^\.claude/hooks/`, `^adapters/.*hooks`, `^bin/cli\.js$`, `^tests/validate\.sh$`,
`^templates/persona-protocol.*\.md$`, `^templates/settings-fragment\.json$`,
`^\.claude/settings.*\.json$`, `^\.claude-plugin/` — no persona-source entry.

**Why these three are one unit:** all are the same failure mode (a measurement
the script cannot make is treated as "safe" instead of "unmeasurable"), on one
file, closed by the same fail-closed discipline the script already applies to
renames, C-quoted paths and binary files.

**Prior defect history (R1).** `.claude/reviewed/192.fail` records exactly this
bug class on exactly this file: rename-compaction and C-quoting both caused
`SENSITIVE_PATHS` to **under**-match, and its third finding is that the test
suite's near-miss cases "only assert the anchors do not OVER-match; nothing
asserts they do not UNDER-match". Step 1's criteria are written to close that
gap directly.

### C-B. `stop-gate.sh`'s `defer:` handling breaks on two input shapes

**(a) A multi-line `defer:` reason defeats the dedupe completely** —
reinstating the original F3 defect for that input. `flag_content` is the whole
file (`stop-gate.sh:135`), `last_logged` is only the log's last line
(`:142`), so they can never compare equal. Measured, 3 consecutive Stops:

```
multi-line reason  -> 6 log lines (3 duplicated entries)   WRONG
single-line reason -> 1 log line                            correct
```

**(b) The whitespace-only `defer: ` glob hole.** `"defer: "*` matches a reason
that is empty after the colon (`*` matches the empty string). Measured: rc=0,
and `defer: ` is written to the audit log — while all three block messages
state **"Empty reason rejected."** The in-repo precedent points the other way:
the WIP sentinel genuinely enforces this (`stop-gate.sh:188` tests `-s`, and
`:195` explains the rejection). So the defer/skip path is the inconsistent one.
Pass 1 flagged this twice (#193, #195) and deliberately left it, because
fixing it flips that input's exit code and each unit's Keep-unchanged list
protected it. It needs its own unit and an explicit ruling — see Open
Question 1.

### C-C. Adapter ports diverged, and no test can see it

Both port headers assert the ordered decision logic is *identical* to the main
hook, differing "only [in] the payload field extraction and the loop guard".
That documented invariant is currently false:

| Site | State |
|---|---|
| `adapters/codex/hooks/scripts/stop-gate.sh:132-134` | `defer:` appends unconditionally — no dedupe |
| `adapters/cursor/hooks/scripts/stop-gate.sh:92-94` | `defer:` appends unconditionally — no dedupe |
| `adapters/codex/.../stop-gate.sh:145` | block message still asserts "spawn the reviewer" |
| `adapters/cursor/.../stop-gate.sh:105` | block message still asserts "spawn the reviewer" |
| `adapters/cursor/rules/persona-protocol.mdc:83` | still claims "that one stop allowed" (one-shot) |

The `.mdc` line is why Pass 1's #193 criterion missed it: that criterion greps
`'one Stop allowed'` **case-sensitively**, and the Cursor port downcases
"stop". A case-insensitive sweep finds it immediately.

**Root cause, and the actual deliverable:** `tests/validate.sh:221-230` enforces
byte-parity only for `lib/agent-identity.sh`. `tests/adapter-protocol-parity.test.js`
covers protocol *section presence* in the doc ports, not hook *behaviour*. So no
test in this repo can observe stop-gate behavioural drift. Porting the three
fixes without adding a guard guarantees a Pass 3 entry identical to this one.

Harness feasibility was checked, not assumed: `tests/stop-gate-blocked.test.sh:23`
already parameterizes the script path (`${2:-hooks/scripts/stop-gate.sh}`, used
by its own mutation control at `:170`). Per-port parameterization needs exactly
three values, all verified:

| Port | event name | project-dir field | dot-dir |
|---|---|---|---|
| claude | `Stop` | `CLAUDE_PROJECT_DIR` env | `.claude/` |
| codex | `Stop` | `.cwd` | `.codex/` |
| cursor | `stop` | `.workspace_roots[0] // .cwd` | `.cursor/` |

Codex's self-tracked loop guard force-allows after 5 consecutive **blocks**; a
`defer:` scenario never blocks, so a 3-Stop fixture cannot trip it.

### C-D. The `gatedAgents` force-include is a silent no-op for slim-tier personas (prior FAIL: #191)

`inlineProtocolBlock` (`bin/cli.js:713-722`) returns the slim template wholesale
for `tier === 'slim'` and never calls `selectProtocolSections`. Measured:

```
selectProtocolSections('scribe','slim',['scribe']) -> 16 headers (function level)
slim template contains '## WIP sentinel'          -> false
slim template contains '## Pending-review flag'   -> false
```

Two things are wrong at once: the exported selector reports the full set for a
slim persona (because `tier !== 'full'` short-circuits to "all"), while the
renderer that actually ships bypasses it and emits a template containing
neither gate section. Gating a slim persona would therefore force-include
nothing, silently. Unreachable under the shipped config
(`gatedAgents: ["lead-programmer"]`, full tier) — latent, not live.

This is squarely on-thesis: `gatedAgents` exists *specifically* so a persona
gated by a mechanism cannot lose the section describing it (Pass 1's A4.1
ruling). A safety force-include that silently does nothing is the same defect
class as C-A. Scope is **fail loudly**, not "make slim trimming work" — the
latter is F9 and stays in Pass 3.

### C-E. `ADR-0006` has no back-pointer to `ADR-0009`

Verified: `docs/adr/0006-...md` mentions ADR-0004 at lines 1, 4, 7, 15, 20, 34,
70 and never mentions 0009. The convention exists and is applied one link
earlier in the same chain — `docs/adr/0004-...md:50` reads
`- **Amended by ADR-0006:** …`. #194's Keep-unchanged list forbade touching
ADR-0006, so the link was never added. One line.

### C-F. `agents/orchestrator.md` states no fallback for `reviewer-tier.sh`

`agents/orchestrator.md:306` reads "It prints exactly `sonnet` or `opus` (exit
0 either way)" and the surrounding paragraph (`:300-315`) gives no instruction
for a missing script or a non-zero exit. Both the opus reviewer and the fable
pass on #194 raised this independently. One clause: any other outcome is `opus`.

### Backlog entries corrected during authoring

- **`fileHashes` entry for an untracked `.claude/persona-protocol.md` — DROPPED,
  no longer true.** The file is tracked and committed (`fa2f912`). The backlog
  entry described a transient state during Pass 1. Nothing to do.
- **`diff.relative` — corrected upward.** The backlog understated it as an
  anchor-matching problem; it is a measurement-loss problem (see C-A(a)).
- **Cross-unit dedupe collision — confirmed real, deferred.** Its fix is a
  log-*format* change (adding the agent-id to the logged line), which needs its
  own decision about a format consumed by humans and by the audit trail. Not a
  fail-open in the Pass 2 sense. → Pass 3.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-08-01 Functional scope & success criteria: Q Which of the ~14 backlog
  items belong in Pass 2 rather than Pass 3? → A (self-resolved): the operator
  delegated the mix explicitly. Applied a single thesis — "a mechanism Pass 1
  built or touched that is currently failing open, silently diverged, or
  asserting something false about itself" — which selects C-A…C-F and excludes
  everything else. A one-line thesis is itself scope protection: it gives the
  implementer and reviewer a test for "is this in scope?" that does not require
  re-reading the backlog.
- 2026-08-01 Domain entities / data model: Q What is the unit of change — the
  hook scripts, the adapter ports, or the generated mirrors? → A
  (self-resolved): hand-maintained sources only (`hooks/scripts/*`,
  `adapters/**`, `agents/*.md`, `docs/adr/*`, `bin/cli.js`, `tests/*`).
  `.claude/agents/*.md` are generated and are never hand-edited; Step 6 is the
  single regeneration point, exactly as Pass 1's Step 9 was.
- 2026-08-01 User interaction flow: Q Does any step change what an operator
  does at the keyboard? → A (self-resolved): only Open Question 1's ruling
  does — rejecting an empty `defer: ` reason changes a turn-end from allowed to
  blocked. Every other change is invisible in normal use and observable only in
  the audit log or the reviewer's model tier.
- 2026-08-01 Non-functional attributes: Q Are these security changes or
  efficiency changes? → A (self-resolved): security/correctness. C-A and C-D
  are fail-open gaps on the review gate; C-B(a) reinstates a fixed defect.
  Pass 2 must therefore NOT be justified by token savings, and its steps must
  not be traded away against cost — but see R5 for the cost ceiling that still
  binds how expensively they are proven.
- 2026-08-01 External dependencies & integrations: Q Can Codex/Cursor hook
  behaviour actually be tested in this repo, given neither platform runs here?
  → A (self-resolved): yes. The ports are plain bash reading JSON on stdin;
  the existing harness already parameterizes the script path, and the three
  per-port differences (event name, project-dir field, dot-dir) were verified
  and are tabulated in C-C. No platform runtime is needed.
- 2026-08-01 Edge cases / failure handling: Q Should an empty-after-colon
  `defer: ` / `skip: ` reason be rejected, or should the message be corrected
  to admit it is accepted? → A: **escalated as Open Question 1** — it flips an
  input's exit code, and Pass 1 twice declined it deliberately. Recommended
  default baked into Step 3 provisionally: reject. *(Superseded by the
  operator's ruling later the same day — see the "reject, per operator" entry
  below, which is the current state.)*
- 2026-08-01 Technical constraints & tradeoffs: Q What shape should the
  adapter-port guard take — byte-parity, grep-on-source, or behavioural? → A
  (self-resolved): behavioural. Byte-parity is impossible (the ports differ by
  design in payload extraction and loop guard); grep-on-source asserts text,
  not behaviour, and would have passed while the dedupe was absent. Behavioural
  is also cheaper than it appears because the existing harness already takes a
  script path. Recorded because a reviewer who expects the
  `lib/agent-identity.sh` byte-parity precedent will otherwise re-raise it.
- 2026-08-01 Terminology consistency: Q Is "fail-open" used consistently
  against Pass 1's "fail-closed"? → A (self-resolved): yes — fail-closed means
  an unmeasurable input routes to the safe outcome (`opus`, block, throw).
  Every C-A/C-D defect is an unmeasurable input routing to the *unsafe*
  outcome. No new vocabulary is introduced by this pass.
- 2026-08-01 Completion / acceptance signals: Q Does Pass 2 need a fresh Fable
  re-audit as its acceptance bar, as Pass 1 had? → A: **yes, required, per
  operator** — overriding this spec's recommendation of "no full re-audit".
  Landed as Step 8 with a named artifact and a greppable per-finding verdict,
  so the bar is checkable rather than prose-only as Pass 1's was. Closes Open
  Question 2.
- 2026-08-01 Edge cases / failure handling: Q Reject an empty-after-colon
  `defer: ` / `skip: ` reason, or correct the messages to admit it is accepted?
  → A: **reject, per operator** — the recommended option, extended to `skip:`
  as well. Closes Open Question 1.
- 2026-08-01 Functional scope & success criteria: Q Should the required
  re-audit's scope be broadened to regenerate the two lost backlog lists, and
  if so does that regeneration gate Pass 2? → A (self-resolved): broadened yes,
  gating no. The auditor already loads the surface those items live on, so the
  marginal cost is an additive read; but a gate that can fail on whether an
  auditor rediscovered items Pass 2 never claimed to fix is unbounded by
  construction, which is the R5 failure mode. Split into Step 8's gating
  Part A and non-gating Part B.

## Risks / dependencies

- **R1 — prior FAIL history on two of the five surfaces, both durable.**
  `.claude/reviewed/192.fail` (`reviewer-tier.sh`: two under-match bugs plus a
  test-suite gap that "only assert[s] the anchors do not OVER-match") and
  `.claude/reviewed/191.fail` (`bin/cli.js`: `gatedAgents` threaded into one
  render path but not the other, and a test calling `renderCleanBody(spec, {})`
  that structurally could not see it). **No unit in this plan is `haiku`-
  eligible and `task-master` must not tag any of them `haiku`.** Steps 1 and 5
  inherit these records directly and start reviewer verification at Tier 2 per
  Methodology rule 2.
- **R2 — the same under-match blind spot can recur in Step 1.** #192's third
  finding was a *coverage* defect, not a code defect. Step 1's criteria
  therefore require a one-directional under-match sweep, not more examples.
  Asserting the `sonnet` direction is banned: it would freeze today's
  over-matches in as required behaviour.
- **R3 — Step 4 touches two live hook chains this repo does not dogfood.** A
  broken Codex/Cursor stop-gate would not surface here. Mitigation: the
  behavioural guard added in the same step is what makes the port verifiable at
  all; it must be written before or with the port, never after.
- **R4 — ordering.** Step 3 must land before Step 4 (Step 4 ports the *fixed*
  dedupe, not today's). Step 6 must run after Steps 1–5. Step 7 after Step 6.
  Steps 1, 2, 3 and 5 are mutually independent and may run in any order.
- **R5 — this spec ballooning is the risk the operator named explicitly.**
  Mitigations, all binding: the one-line thesis in Goal; a hard rule that any
  mid-flight finding *outside* that thesis routes to Pass 3's backlog rather
  than becoming an amendment; and the A4.2 methodology in force from Step 1
  rather than retrofitted at Step 4 as in Pass 1. **If a step needs a third
  acceptance-criteria revision, that is the escalation trigger — stop and route
  to `spec-master`, do not amend in place.**
- **R6 — version-stamp coupling (constitution P3).** Steps 2, 4 and 5 touch
  version-stamped sources (`agents/*.md`, `adapters/**`, template-adjacent
  code). Step 6 is the single bump + regeneration + CHANGELOG point.
- **D1 — issue #152** remains the tracker home for the `defer:` mechanism;
  Steps 3 and 4 should reference it.
- **D2 — `tests/validate.sh` is the merge gate** and must pass at every step.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every finding in Context was
  reproduced live (fixture repos and piped hook payloads), not taken from the
  backlog's prose. Three backlog entries did not survive verification and are
  corrected or dropped in "Backlog entries corrected during authoring".
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 4
  replaces "remember to keep the ports in sync" with a merge-gate test; Step 1
  keeps the tier decision in the existing script rather than moving judgment
  back into prose.
- P3 "Version-stamp discipline": satisfied — Step 6 bumps
  `.claude-plugin/plugin.json` to `0.20.0` and adds a CHANGELOG entry covering
  every version-stamped file touched.
- P4 "Optional personas degrade gracefully": satisfied — Step 5 fails loudly
  only when a persona is *explicitly* listed in `gatedAgents`, so a project
  omitting a persona never trips it. Step 2's prose keeps conditional phrasing.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step's
  acceptance criteria include it, and Step 4 registers a new test in it.

---

## Step 1 — `reviewer-tier.sh`: close the three fail-open gaps

Make the two unmeasurable-input cases fail closed and add the missing
sensitive-path class.

- **`diff.relative`**: force it off at the call site (`git -c diff.relative=false`),
  alongside the existing `-c core.quotepath=false`. Do not rely on the
  "run from the repo root" instruction — it is unenforced, and C-A(a) shows the
  failure is silent.
- **Project-dir resolution**: resolve the marker directory robustly rather than
  defaulting to `.`, and **fail closed** (`opus`) when a `<task-id>` was given
  but the reviewed-marker directory cannot be located at all — an absent
  directory means the disqualifier could not be evaluated, which is exactly the
  condition the script already treats as `opus` everywhere else.
- **`SENSITIVE_PATHS`**: add `^agents/` and `^\.claude/agents/` (persona
  sources and their generated mirrors — the prose governing review depth).

Keep unchanged: `MAX_CHANGED_LINES=40` / `MAX_CHANGED_FILES=3` and their
strictly-greater-than comparison; the existing rename/C-quote/binary handling;
the `sonnet`-or-`opus`-only, exit-0 output contract.

**Affected files**
- `hooks/scripts/reviewer-tier.sh`
- `tests/reviewer-tier.test.sh`

**Acceptance criteria**
1. `grep -q 'diff\.relative=false' hooks/scripts/reviewer-tier.sh` exits 0.
2. `grep -qE "^\s*'\^agents/'" hooks/scripts/reviewer-tier.sh` and
   `grep -qE "\^\\\\\.claude/agents/" hooks/scripts/reviewer-tier.sh` both exit 0.
3. **Under-match sweep, one-directional.** A new case builds one fixture repo
   whose HEAD~1..HEAD touches a sensitive path, then invokes the script under
   each of these conditions, asserting `opus` every time:
   `diff.relative=true` from a subdirectory; `diff.relative=false`; from the
   repo root; a renamed sensitive path; a C-quoted (non-ASCII) sensitive path;
   `agents/reviewer.md`; `.claude/agents/reviewer.md`.
   **Assert only the `opus` direction.** No case may assert `sonnet` for a path
   shape — that would freeze today's over-matches in as required behaviour
   (R2). A non-vacuity floor is required: assert the sweep executed the
   expected number of probes.
4. A new case asserts the fail-closed disqualifier: a 1-file/1-line
   non-sensitive diff plus a live FAIL record for the task-id prints `opus`
   from the repo root, from a subdirectory with `CLAUDE_PROJECT_DIR` unset,
   and with `CLAUDE_PROJECT_DIR` set. All three print `opus`.
5. The existing boundary sweep (39/40/41 lines, 2/3/4 files) still passes
   unchanged: `git diff --numstat -- tests/reviewer-tier.test.sh` shows added
   lines only for those cases, no deletions within them.
6. **One mutation control for the whole step** (Methodology rule 1): in a
   throwaway copy, revert `diff.relative=false` and confirm criterion 3's
   subdirectory case fails; restore. Record the literal command and literal
   output in the review packet.
7. `bash tests/reviewer-tier.test.sh` exits 0.
8. `bash tests/validate.sh` exits 0.

## Step 2 — `reviewer-tier.sh`'s two prose gaps

Two independent one-clause documentation fixes on the same mechanism.

- `agents/orchestrator.md`: state the fallback. If `reviewer-tier.sh` is
  missing, exits non-zero, or prints anything other than exactly `sonnet` or
  `opus`, treat the result as `opus`. Keep the existing downgrade-only
  asymmetry, the fable exclusion, and the `.fail` disqualifier untouched.
- `docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`: add the
  `**Amended by ADR-0009:** …` back-pointer, matching the form already used at
  `docs/adr/0004-reviewer-roast-work-dual-model-routing.md:50`. Add only that
  line; ADR-0006's decision is unchanged.

**Affected files**
- `agents/orchestrator.md`
- `docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`

**Acceptance criteria**
1. `grep -qi 'treat.*as .opus.\|any other outcome' agents/orchestrator.md` matches
   the new fallback clause, and the matched sentence names both the
   missing-script and the non-zero-exit cases.
2. `grep -q 'Amended by ADR-0009' docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
   exits 0.
3. `git diff --numstat -- docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
   reports **0 deletions** (append-only — the decision is not being rewritten).
4. `grep -qi 'fable' agents/orchestrator.md` and
   `grep -q '\.fail' agents/orchestrator.md` still match; the downgrade-only
   asymmetry statement is still present.
5. `bash tests/validate.sh` exits 0.

## Step 3 — `stop-gate.sh`: make `defer:` handling shape-proof

- **Multi-line reasons**: flatten the flag content to a single logical line
  before both the dedupe comparison and the write, so a multi-line reason
  dedupes exactly like a single-line one. The log must remain one record per
  line — a record that spans lines is what broke the comparison.
- **Empty-after-colon reasons**: reject them, matching the block messages'
  existing "Empty reason rejected." claim and the WIP sentinel's precedent at
  `stop-gate.sh:188`/`:195`. **Operator-confirmed 2026-08-01 (Open Question 1,
  option (a)) — no longer provisional, and not to be softened during
  implementation.** A flag whose content is exactly `defer: ` (or `skip: `)
  with nothing after the colon is not a valid escape hatch: it must block, not
  allow. Apply the same tightening to `skip:`, which deletes the flag and is
  the more consequential of the two.

Keep unchanged: the `skip:` deletion behaviour, the `cleared-by=reviewer` line,
the `verdict=blocked flags-kept` line, sticky defer semantics, and
`reviewer-route-gate.sh` (which blocks on flag existence only and is untouched
by any of this).

**Affected files**
- `hooks/scripts/stop-gate.sh`
- `tests/stop-gate-blocked.test.sh`

**Acceptance criteria**
1. New case: a **multi-line** `defer:` reason followed by three `Stop` events
   yields exactly **one** `defer:` record in `.claude/review-audit.log`, and all
   three exit 0.
2. New case: the existing single-line behaviour is unchanged — one `defer:`
   write, three Stops, exactly one record.
3. New case: `defer: A` → Stop → `defer: B` → Stop yields exactly **two**
   records in order (a changed reason is still recorded).
4. New case: an identical `defer:` separated from an earlier one by a
   `cleared-by=reviewer` line is still appended (only *consecutive* duplicates
   are suppressed).
5. New case: a flag whose content is exactly `defer: ` (empty after the colon)
   **blocks** — exit 2 — and writes no `defer:` record. Same for `skip: `,
   which must additionally **not** delete the flag.
6. Shape sweep on the dedupe, one-directional: for reasons that are multi-line,
   trailing-whitespace, CR-terminated, and >1KB, three consecutive Stops yield
   exactly one record each. Assert only the deduped count; do not assert any
   shape must produce two.
7. **One mutation control for the step**: revert the flattening in a throwaway
   copy and confirm criterion 1 fails; restore.
8. `bash tests/stop-gate-blocked.test.sh` exits 0.
9. `bash tests/validate.sh` exits 0.

## Step 4 — Adapter-port parity: port the fixes, then guard the invariant

Depends on Step 3. Port Step 3's fixed behaviour and Pass 1's #193 wording to
both adapter copies, correct the Cursor rules file, and add the test that makes
this class of drift visible.

- `adapters/{codex,cursor}/hooks/scripts/stop-gate.sh`: port the dedupe and
  Step 3's shape handling; replace the "spawn the reviewer" block-message
  assertion with the same confirm-or-defer phrasing the main hook now uses.
  Preserve each port's own payload extraction, loop guard, and dot-dir — those
  are the documented, legitimate differences.
- `adapters/cursor/rules/persona-protocol.mdc:83`: replace the false "that one
  stop allowed" one-shot claim with the sticky semantics.
- **New `tests/adapter-stop-gate-parity.test.sh`**, registered in
  `tests/validate.sh`: drives all three stop-gate scripts through the same
  defer-dedupe scenario, parameterized by the three per-port values tabulated
  in C-C, and asserts the same observable outcome from each.

**Affected files**
- `adapters/codex/hooks/scripts/stop-gate.sh`
- `adapters/cursor/hooks/scripts/stop-gate.sh`
- `adapters/cursor/rules/persona-protocol.mdc`
- `tests/adapter-stop-gate-parity.test.sh` (new)
- `tests/validate.sh` (registration only)

**Acceptance criteria**
1. `! grep -rni 'one stop allowed' adapters/ templates/ skills/ hooks/` exits 0
   — **case-insensitive**, which is the exact gap that let this survive #193.
2. `! grep -rn 'spawn the reviewer' adapters/ hooks/` exits 0.
3. `bash tests/adapter-stop-gate-parity.test.sh` exits 0, and for **each** of
   the three scripts asserts: three Stops after one single-line `defer:` write
   yield exactly one record in that port's own audit log; the same for a
   multi-line reason; and `defer: A` → Stop → `defer: B` → Stop yields two.
4. **One mutation control for the step**: in a throwaway copy, revert the
   dedupe in *one* adapter script and confirm the parity test fails naming that
   port; restore. This is the criterion that proves the guard can fail — a
   parity test that passes against an unported script is worthless.
5. `bash tests/validate.sh` exits 0 and its output names
   `tests/adapter-stop-gate-parity.test.sh`.
6. `node tests/adapter-protocol-parity.test.js` exits 0 (unchanged — no
   canonical protocol header is touched).

## Step 5 — Make the `gatedAgents` force-include fail loudly on a slim persona

Scope is **fail loudly**, not "make slim trimming work" (that is F9, Pass 3).

Add a load-time assertion beside the existing `assertProtocolMatrixComplete` /
`assertGatedSectionsCanonical` calls: if any persona in `gatedAgents` resolves
to a non-`full` protocol tier, `throw` with a message naming the persona and
stating that the slim template carries neither gate section, so the
force-include cannot be honoured. Additionally make `selectProtocolSections`
stop reporting a full section list for a slim-tier persona it is never
consulted for, so the exported function and the shipped renderer agree.

**Affected files**
- `bin/cli.js`
- `tests/cli-backfill.test.js`

**Acceptance criteria**
1. New test: a config with `gatedAgents` containing a slim-tier persona (e.g.
   `scribe`) makes the render path throw, and the message names that persona.
2. New test (positive control): the shipped config
   (`gatedAgents: ["lead-programmer"]`) renders without throwing, and
   `.claude/agents/lead-programmer.md`'s regenerated body still contains
   `## WIP sentinel` and `## Pending-review flag` — A4.1's force-include ruling
   is preserved, not regressed.
3. The test renders using the **real** `.claude/persona-config.json`, not
   `renderCleanBody(spec, {})` — #191's third finding was a test that could not
   see the defect because it passed an empty config.
4. Both render paths are covered: the `--update` path and the fresh-scaffold
   path (#191's first finding was that only one was threaded).
5. **One mutation control for the step**: remove the new assertion in a
   throwaway copy and confirm criterion 1 fails; restore.
6. `node tests/cli-backfill.test.js` exits 0.
7. `bash tests/validate.sh` exits 0.

## Step 6 — Version bump, mirror regeneration, CHANGELOG

Runs **after** Steps 1–5. Bump `.claude-plugin/plugin.json` `0.19.0` → `0.20.0`,
regenerate the nine `.claude/agents/*.md` mirrors plus
`.claude/persona-protocol.md` and `.claude/persona-protocol-slim.md` via the
tool, and add a CHANGELOG entry.

The CHANGELOG must **lead** with the two operator-visible behaviour changes:
(a) `reviewer-tier.sh` now fails closed on an unresolvable marker directory and
treats `agents/*.md` as sensitive, so some units that previously measured
`sonnet` will now measure `opus`; and (b) an empty `defer: ` / `skip: ` reason
now blocks turn-end where it previously allowed it (operator ruling,
2026-08-01) — state plainly that the previous behaviour contradicted the
"Empty reason rejected." message the hook already printed.

Note `--update --check` is **not** a dry run and a plain `--update` at an
unchanged version takes the fast path and writes nothing (Pass 1 Amendment A1).
Criteria below are written accordingly — the version bump itself is what
defeats the fast path.

**Affected files**
- `.claude-plugin/plugin.json`
- `CHANGELOG.md`
- `.claude/agents/*.md`, `.claude/persona-protocol.md`,
  `.claude/persona-protocol-slim.md` (regenerated output only, never hand-edited)

**Acceptance criteria**
1. `node -e "process.exit(require('./.claude-plugin/plugin.json').version==='0.20.0'?0:1)"` exits 0.
2. `grep -q '## \[0.20.0\]' CHANGELOG.md` exits 0.
3. After committing the regenerated tree, a **forced** re-render changes
   nothing: run `node bin/cli.js --update` and assert
   `git status --porcelain .claude/` is empty (idempotence at the new version).
4. `bash tests/validate.sh` exits 0.

## Step 7 (scribe) — institutional record

**Affected files**
- `.claude/wiki/modules/hooks.md` (defer shape-handling; the adapter-port
  behavioural parity guard as a new merge-gate check)
- `.claude/wiki/modules/adapters.md` (the parity guard and what it does/does
  not cover)
- `CONTEXT.md` (glossary: adapter behavioural parity)

**Acceptance criteria**
1. `grep -qi 'parity' .claude/wiki/modules/adapters.md` exits 0 and the
   surrounding text names `tests/adapter-stop-gate-parity.test.sh`.
2. `grep -q 'adapter-stop-gate-parity' .claude/wiki/modules/hooks.md` exits 0.
3. `grep -qi 'behavioural parity\|behavioral parity' CONTEXT.md` exits 0.
4. `bash tests/validate.sh` exits 0.

## Step 8 — Convergence gate: fresh Fable re-audit (operator-required)

Runs **last**, after Steps 1–7 have landed and committed. Operator ruling
2026-08-01 (Open Question 2). This is a **gate, not a formality**: Pass 2 is not
done when the per-step criteria pass, it is done when a fresh audit confirms the
mechanisms no longer fail open.

Dispatch a **read-only** Fable audit over the same surface Pass 1's audit
covered — `agents/*.md`, `templates/persona-protocol.md`, `hooks/scripts/*`,
the adapter ports, `bin/cli.js`'s mirror generation, and
`.claude/review-audit.log` — and have it produce **one written report** at
`docs/audits/2026-08-01-efficiency-pass2-reaudit.md`.

The report has two parts, and the distinction between them is load-bearing:

**Part A — convergence verdict (GATING).** One line per finding id below,
each ending in exactly `CONVERGED` or `REGRESSED`, with the evidence the
auditor observed. The two verdict tokens are deliberately **not** substrings of
each other — a `CONVERGED`/`NOT CONVERGED` pair would make any count of
`CONVERGED` satisfiable by nine failures. The ids are fixed so the check is
deterministic:

| id | finding |
|---|---|
| `P2-A1` | `reviewer-tier.sh` measurement loss under `diff.relative` |
| `P2-A2` | `reviewer-tier.sh` marker-directory fail-open on the `.fail` disqualifier |
| `P2-A3` | persona sources absent from `SENSITIVE_PATHS` |
| `P2-B1` | multi-line `defer:` defeating the audit-log dedupe |
| `P2-B2` | empty-after-colon `defer: ` / `skip: ` accepted |
| `P2-C1` | adapter stop-gate ports missing the dedupe and carrying the stale block message |
| `P2-C2` | Cursor rules file's false one-shot claim |
| `P2-D1` | `gatedAgents` force-include silently no-op for a slim-tier persona |
| `P2-E1` | ADR-0006 missing its ADR-0009 back-pointer |

**Part B — re-derived backlog inventory (NON-GATING, seeds Pass 3).** Best
effort at regenerating the "contradictions / redundant mechanisms" and
"heavyweight-model trigger-happiness" lists that Pass 1's audit produced and
that survive nowhere on disk (see "Deferred to Pass 3"). Enumerated under its
own heading, with each item stated concretely enough that a future spec can
scope it without a third audit.

**Why Part B is deliberately non-gating** — this is the ruling, and it is
`spec-master`'s call rather than the operator's: the marginal cost of Part B is
low, because the auditor is already loading exactly the surface those items
live on, so re-deriving them is an additive read rather than a second audit.
But making it *gating* would let Pass 2 fail on whether an auditor rediscovered
a list of items Pass 2 never claimed to fix — coupling an open-ended discovery
task to a convergence gate is precisely the unbounded-scope mechanism that made
Pass 1 balloon (R5). So the two are separated: Part A can fail Pass 2; Part B
cannot. If Part B comes back thin or empty, that is a Pass 3 scoping input, not
a Pass 2 defect.

**Cost and scope bounds (binding, per R5):** read-only — the audit modifies no
tracked file and opens no issue. It fixes nothing. Any *new* finding outside
the nine ids goes to Pass 3's backlog in Part B, **except** a regression in a
Pass 2 mechanism, which is a `REGRESSED` on that mechanism's own id. The
audit is one dispatch, not a loop; a `REGRESSED` routes the named step back
through the normal fix/review pipeline and then re-runs Part A only for the
ids that failed.

**Affected files**
- `docs/audits/2026-08-01-efficiency-pass2-reaudit.md` (new; the audit's own
  output, and the only file this step creates)

**Acceptance criteria**
1. `test -s docs/audits/2026-08-01-efficiency-pass2-reaudit.md` exits 0.
2. Every id is present exactly once in Part A:
   `for id in P2-A1 P2-A2 P2-A3 P2-B1 P2-B2 P2-C1 P2-C2 P2-D1 P2-E1; do
   [ "$(grep -c "$id" docs/audits/2026-08-01-efficiency-pass2-reaudit.md)" -ge 1 ] || exit 1; done`
   exits 0.
3. **The gate itself:**
   `! grep -q 'REGRESSED' docs/audits/2026-08-01-efficiency-pass2-reaudit.md`
   exits 0. While any id reads `REGRESSED`, Pass 2 is not complete.
4. Non-vacuity — the ids carry verdicts rather than merely being listed:
   `[ "$(grep -c 'CONVERGED' docs/audits/2026-08-01-efficiency-pass2-reaudit.md)" -ge 9 ]`
   exits 0. Sound only because `REGRESSED` is not a substring of `CONVERGED`,
   so this count cannot be inflated by failures.
5. Part B is present under its own heading, even if it reports that a list
   could not be reconstructed:
   `grep -qi '^#\+ .*Part B\|^#\+ .*backlog inventory' docs/audits/2026-08-01-efficiency-pass2-reaudit.md`
   exits 0.
6. The audit was read-only: `git status --porcelain` shows no modification to
   any tracked file attributable to this step other than the new report.
7. `bash tests/validate.sh` exits 0 (the tree is still green at the gate).

---

## Deferred to Pass 3 (with reasons — none of these is "not assessed")

- **Cross-unit dedupe collision** (two flags, identical text, one log line).
  Real. Fix is a log-format change (agent-id in the logged line); needs its own
  decision about a format the audit trail depends on. Off-thesis: not a
  fail-open.
- **Task-id mismatch defeating the `.fail` disqualifier.** Real, but the fix is
  a new enforcement mechanism, not a correction. Step 1's fail-closed marker
  lookup removes one of its two failure modes (a missing directory); the
  remaining one (a correct directory, wrong id) still needs binding the
  orchestrator's `reviewer-tier.sh` id to the reviewer's marker filename.
- **Dangling cross-references in trimmed persona bodies.** Confirmed present in
  four mirrors during #191. Needs a template restructure making
  cross-references section-local or conditional — exactly the "no canonical
  heading touched" constraint Pass 1 declined twice. A restructure is a pass of
  its own, and folding it here is the balloon risk R5 names.
- **F4** (roast passes fire too readily), **F6** (the 14-subsection routing
  tree), **F9** (slim-tier protocol delivery). Each is a design project, not a
  correction. F6 should follow Step 5's script-based precedent from Pass 1.
- **F7** (`reviewed-path-gate.sh` friction, issue #155, and the #159/#154
  issue-lifecycle deadlock). Two fresh datapoints from authoring this spec,
  worth recording: the gate blocked `for f in …; do cat .claude/reviewed/$f.fail;
  done` and a `git`-containing command that merely *mentioned* a path inside a
  throwaway `mktemp -d`. Both were read-only and both were benign. This adds to
  the measured false-positive set in `.claude/agent-memory/antislop-spec-master/project_reviewed_path_gate_155.md`.
  Still deferred: narrowing the matcher is its own spec.
- **F5** (maxTurns / resume churn). Pass 1 already established that the base
  cost of resuming is structural to the resume mechanism and not removable by
  prose. `maxTurns` is already 50. Nothing further to attempt without a
  compact-resume primitive.
- **The nine "contradictions / redundant mechanisms" and six
  "heavyweight-model trigger-happiness" items.** Deferred **for lack of a
  source**, not on assessment. Searched and confirmed absent: no file in the
  repo enumerates them (`grep -rn 'trigger-happiness'` matches only the Pass 1
  plan's own forward reference), and issue #187 restates F1–F3 without the
  lists. They existed only in the live Fable audit session. **Retrieval path is
  now live:** the operator's ruling on Open Question 2 requires a fresh audit,
  and Step 8's non-gating Part B tasks it with re-deriving these lists to seed
  Pass 3. Whatever Part B returns is a Pass 3 input; it cannot fail Pass 2.

## Open Questions

**None outstanding — nothing blocks dispatch.** Both questions raised during
authoring were ruled on by the operator on 2026-08-01. Retained here as an
audit trail of what was decided and by whom, so a later pass does not silently
re-open them.

1. ~~Should an empty-after-colon `defer: ` / `skip: ` reason be rejected, or
   should the block messages be corrected to admit it is accepted?~~
   **RESOLVED 2026-08-01 — option (a): reject it**, matching the recommended
   default. The rejected alternatives were (b) correct the three messages
   instead, and (c) reject for `defer:` only. Baked into Step 3 as
   not-to-be-softened, extended to `skip:` per (c)'s rejection, with the
   behaviour change carried in Step 6's CHANGELOG lead.

2. ~~Is a fresh Fable re-audit part of Pass 2's acceptance bar, as it was for
   Pass 1?~~ **RESOLVED 2026-08-01 — re-audit REQUIRED**, overriding this
   spec's recommendation of (a) "no full re-audit". The operator's ruling
   mirrors Pass 1's own bar. Landed as **Step 8**, an explicit gate with a
   named artifact and a greppable per-finding verdict, rather than as prose —
   deliberately, because Pass 1's equivalent bar was prose-only and therefore
   not checkable. `spec-master` additionally ruled that the re-audit's Part B
   (re-deriving the two lost backlog lists) is **non-gating**; see Step 8 for
   that reasoning.

## Self-check

- CHK1: Is it stated which files are generated versus hand-maintained, so no
  step hand-edits a mirror? — PASS
- CHK2: Do Steps 3 and 4 agree on which behaviour is being ported, and in which
  order? — PASS
- CHK3: Is every finding in Context backed by a reproduction rather than by the
  backlog's assertion? — PASS
- CHK4: Is the empty-reason `defer:` behaviour defined? — PASS (was FAIL
  (missing) → Open Question 1; ruled by the operator 2026-08-01 and baked into
  Step 3 as not-to-be-softened, extended to `skip:`, so the plan's own text now
  answers it)
- CHK5: Is Pass 2's acceptance bar defined? — PASS (was FAIL (missing) → Open
  Question 2; ruled by the operator 2026-08-01 and landed as Step 8)
- CHK6: Do Steps 1 and 5 both record their prior FAIL history and its
  consequence for model tagging and reviewer tier? — PASS
- CHK7: Is the adapter-parity guard's shape decided, with the rejected
  alternatives named so a reviewer does not re-raise byte-parity? — PASS
- CHK8: Does any step's acceptance criterion lack a runnable command? — FAIL
  (ambiguous) — Step 1's under-match criterion initially said "cover rename and
  quoted paths", which is a coverage wish, not a check; revised in place into an
  enumerated probe list with a non-vacuity floor.
- CHK9: Is the one-directional assertion rule (never assert `sonnet`, never
  assert "must produce two records") stated where it applies? — PASS
- CHK10: Is the ordering dependency between Steps 3, 4, 6 and 7 stated? — PASS
- CHK11: Does each step have exactly one mutation control rather than one per
  criterion, per A4.2? — PASS
- CHK12: Is it stated that `maxTurns` is already 50 and must not be re-raised?
  — PASS
- CHK13: Does the plan say what happens if a mid-flight finding falls outside
  the thesis? — PASS (R5: route to Pass 3's backlog, do not amend; a third
  criteria revision is the escalation trigger)
- CHK14: Are the deferred items each given a reason distinguishing "assessed
  and deferred" from "could not be assessed"? — FAIL (missing) — revised in
  place; the two lost audit lists now state explicitly that they are deferred
  for lack of a source, with the searches that established it.
- CHK15: Do Step 5's criteria avoid repeating #191's empty-config test defect?
  — PASS (criterion 3 requires the real config; criterion 4 requires both
  render paths)
- CHK16: Is Step 6's criterion written against the real `--update` semantics
  rather than assuming `--check` is a dry run? — PASS
- CHK17: Is Step 8's convergence bar machine-checkable, rather than prose as
  Pass 1's equivalent bar was? — PASS (named artifact path, fixed nine-id set,
  greppable per-id verdict, explicit gate command)
- CHK18: Does Step 8 state which of its two parts can fail Pass 2 and which
  cannot? — PASS (Part A gating, Part B explicitly non-gating, with the
  reasoning stated rather than asserted)
- CHK19: Can Step 8's non-vacuity count be satisfied by nine failing verdicts?
  — FAIL (ambiguous) — the original `CONVERGED` / `NOT CONVERGED` token pair
  made `grep -c 'CONVERGED'` count failures too; revised in place to
  `CONVERGED` / `REGRESSED`, which share no substring.
- CHK20: Do Step 3 and Step 8's `P2-B2` agree on what the empty-reason ruling
  requires? — PASS (both state rejection, both cover `skip:` as well as
  `defer:`)
- CHK21: Is Step 8 bounded against becoming an open-ended audit loop, given R5?
  — PASS (read-only, one dispatch not a loop, fixes nothing, new findings route
  to Part B, re-runs scoped to failed ids only)

Re-check history: the first revision pass closed CHK8 and CHK14 in place. CHK4
and CHK5 needed information only the operator had and became Open Questions 1
and 2; **both were ruled on by the operator on 2026-08-01 and now PASS on the
plan's own text** — OQ1 confirming the recommended default, OQ2 overriding it.
CHK17–CHK21 were added when Step 8 landed, since a new gate introduces
checkable properties the earlier text did not have; CHK19 failed on first
inspection and was revised in place. **All 21 items PASS; no item is
unrepresented and no Open Question is outstanding.**

## Scribe update hint

After Step 6, `.claude/wiki/modules/adapters.md` gains a genuinely new concept:
adapter ports now have a **behavioural** parity guard, distinct from both the
byte-parity check on `lib/agent-identity.sh` and the document parity check in
`adapter-protocol-parity.test.js`. The wiki currently describes only the latter
two. `.claude/wiki/modules/hooks.md` needs the defer shape-handling rules.
`CONTEXT.md`'s glossary needs "adapter behavioural parity". ADR-0006 gains its
back-pointer in Step 2, completing the 0004→0006→0009 chain in both directions.

---

## Amendment A1 — operator rulings on both Open Questions (2026-08-01)

Author: `spec-master` | Trigger: operator ruling relayed by the orchestrator,
before any unit was dispatched from this spec.

**Why this is applied in place rather than appended as superseding text.**
Pass 1's Amendment A1 recorded the failure mode this is avoiding: a reader
landing on a document marked *Finalized* executes the criteria printed under
the steps, not an amendment 1,500 lines later. Pass 1 had already dispatched
units when its amendments landed, so in-place edits would have rewritten
criteria that units were mid-execution against. **Here neither condition
holds** — the only tracker artifact is the spec issue #198, `task-master` has
not sliced anything, and no unit exists. Editing in place is therefore both
safe and strictly less error-prone than leaving contradictory text standing.
This section is the audit trail of what changed.

**A note on how that is audited.** This document is **untracked** at the time
of writing (`git status` reports `??`), so `git diff --numstat` has no baseline
to report deletions against — the same caveat Pass 1's A1 recorded. Until the
first commit tracks this file, the auditable record is the change list below.
Any later amendment must use the `git diff --numstat` 0-deletions form once a
baseline exists.

### Ruling 1 — empty-after-colon `defer: ` / `skip: ` is REJECTED

Operator ruled **option (a)**, matching this spec's recommended default. No
substantive change; the provisional hedging is removed and the ruling is
recorded as not-to-be-softened.

Edits: Step 3's second bullet (de-provisionalized, extended explicitly to
`skip:`); Step 3 criterion 5 (drops "provisional", adds the `skip: ` case and
the requirement that it must not delete the flag); Step 6's CHANGELOG bullet
(drops the "if OQ1 is ruled" conditional); Open Question 1 (marked RESOLVED);
Clarifications (dated line added); Self-check CHK4 (FAIL→PASS).

### Ruling 2 — a fresh Fable re-audit IS the acceptance bar

Operator ruled **the re-audit is required**, overriding this spec's
recommendation of "no full re-audit". Recorded plainly because the override is
the interesting part of the audit trail: the spec argued that every finding was
individually reproduced and that Step 4's parity guard is durable rather than
point-in-time; the operator's ruling mirrors Pass 1's own bar and takes
precedence.

Landed as **Step 8**, an explicit final gate rather than prose. Pass 1's
equivalent bar *was* prose ("the acceptance bar is a fresh Fable re-audit …")
and was therefore not checkable; Step 8 names an artifact path, fixes a
nine-id finding set, and requires a greppable per-id verdict, so the gate can
actually fail.

Edits: new Step 8 (with affected files and seven acceptance criteria); Goal
(acceptance-bar paragraph added); Open Question 2 (marked RESOLVED, override
recorded); "Deferred to Pass 3" (the two lost lists now have a live retrieval
path); Clarifications (two dated lines); Self-check (CHK5 FAIL→PASS, CHK17–21
added).

### `spec-master` ruling — Part B is broadened in, but non-gating

The orchestrator left the re-audit's scope to this persona's judgment. Ruling:
**broaden it, do not gate on it.** The auditor is already loading the exact
surface the two lost lists describe, so re-deriving them is an additive read
rather than a second audit — cheap enough that skipping it would waste the one
dispatch that can recover them. But gating on it would let Pass 2 fail on
whether an auditor rediscovered items Pass 2 never claimed to fix, which is an
unbounded gate by construction and the precise R5 failure mode. Hence Step 8's
Part A (gating, nine fixed ids) / Part B (non-gating, best-effort, seeds
Pass 3) split. Part B's output is a Pass 3 scoping input; a thin or empty
Part B is not a Pass 2 defect.

### Self-check defect found and fixed while drafting Step 8

The gate's verdict tokens were originally `CONVERGED` / `NOT CONVERGED`. Since
the latter contains the former, the non-vacuity criterion
(`grep -c 'CONVERGED' … -ge 9`) would have been satisfied by nine *failing*
verdicts — a gate that counts its own failures as evidence of success. Tokens
changed to `CONVERGED` / `REGRESSED`, which share no substring. Recorded as
CHK19 (FAIL, ambiguous → revised in place) rather than silently corrected.

**Net effect on scope:** one step added (Step 8), no step removed, no step's
substance changed. The seven implementation steps are exactly as published;
Pass 2 now ends with a convergence gate instead of with the scribe record.

---

## Amendment A2 — Step 4 criterion 2 was unsatisfiable; replaced (2026-08-01)

Author: `spec-master` | Trigger: defect reported by `lead-programmer` during
issue #202's execution, raised while #202 is in review. Scope of this
amendment is **Step 4, acceptance criterion 2, and nothing else.** No other
step, criterion, ruling or Keep-unchanged list is reopened.

**Why this is APPENDED rather than applied in place — the opposite call from
A1, and deliberately so.** A1 edited in place because no unit had been sliced
or dispatched, so no reader was mid-execution against the printed text. That
condition no longer holds: #202 exists, has been dispatched, and is in review
right now. Rewriting a criterion a unit is being judged against, mid-review,
is exactly the failure mode Pass 1's own Amendment A1 recorded. So the body of
Step 4 stands as published and **this section supersedes its criterion 2**.

*Audit-trail caveat, re-checked rather than assumed:* A1 said a later amendment
must use the `git diff --numstat` 0-deletions form "once a baseline exists".
Checked at the time of writing — this document is **still untracked**
(`git status` reports `??`; `e622880` committed the Pass **1** spec, not this
one), so no baseline exists yet and `--numstat` reports nothing. The auditable
record for A2 therefore remains the change list in this section: exactly one
criterion superseded, zero characters of the body altered.

### Independent verification (not taken on the report's word)

All four residual matches of `grep -rn 'spawn the reviewer' adapters/ hooks/`
were read in place. They are **three** distinct provenances, not two:

| # | Site | What it actually is | In scope for #202? |
|---|---|---|---|
| 1 | `hooks/scripts/reviewer-route-gate.sh:42` | Live block message of a *different* gate ("lead-programmer may not spawn the reviewer directly"). True, current, and the gate's whole point. | No — #202's Keep-unchanged names `reviewer-route-gate.sh` "and its adapter equivalents" explicitly. |
| 2 | `adapters/codex/agents-md-fragment.md:74`, `adapters/cursor/rules/persona-protocol.mdc:80` | Verbatim mirrors of `templates/persona-protocol.md:209` — "the orchestrator's correct next move (spawn the reviewer, or spawn anything non-gated like `explorer`) is **never blocked**". A statement about what is NOT blocked. | No — `templates/persona-protocol.md` is Keep-unchanged; that surface is Pass 1's shipped #193. |
| 3 | `adapters/codex/agents-md-fragment.md:173` | **Not** a mirror of the above, contrary to the report. It is Codex port-notes prose quoting the route-gate *rule name*: `- "lead-programmer must not spawn the reviewer directly" (the other half of review ownership) is UNVERIFIED whether SubagentStart exposes …`. Its true peer is `docs/codex-port-notes.md:80`, i.e. site 1's surface, not site 2's. | No — same Keep-unchanged as site 1. |

The report's ruling is upheld; its **reasoning for site 3 is corrected here**
rather than passed along. Correcting it matters because it changes which
Keep-unchanged entry protects that line, and therefore which future pass owns
it: site 3 belongs to the route-gate/port-notes surface, not the protocol
mirror surface.

The in-scope half is confirmed landed: `git log -S'spawn the reviewer'` shows
`abb285f` ("port the defer: dedupe and empty-reason rejection to both
stop-gate ports (issue #202, Step 4)") as the commit that removed the stale
assertion from **both** adapter stop-gate ports. The canonical
`hooks/scripts/stop-gate.sh` was cleared earlier by Pass 1's #193 and now
carries the confirm-or-defer phrasing at `:168`.

**Ruling: criterion 2 as published is unsatisfiable by any in-scope work.**
Every remaining match sits on a surface this unit is forbidden to touch. A
criterion that can only be satisfied by violating the same step's
Keep-unchanged list is a spec defect, not an implementation gap.

### Replacement — Step 4, criterion 2 (supersedes the published text)

```
# 2a — no stale block-message assertion survives in ANY of the three
#      block-message-bearing stop-gate scripts (the only surface Step 4 owns)
! grep -n 'spawn the reviewer' \
    hooks/scripts/stop-gate.sh \
    adapters/codex/hooks/scripts/stop-gate.sh \
    adapters/cursor/hooks/scripts/stop-gate.sh

# 2b — non-vacuity floor: all three files exist AND carry the replacement
#      phrasing. Without this, 2a passes on a typo'd/renamed path (grep exits
#      2 on a missing file; `!` turns that into a pass — verified live).
[ "$(grep -lF 'confirm the reviewer is dispatched' \
      hooks/scripts/stop-gate.sh \
      adapters/codex/hooks/scripts/stop-gate.sh \
      adapters/cursor/hooks/scripts/stop-gate.sh | wc -l)" -eq 3 ]
```

Both verified live: 2a exits 0, 2b exits 0 as of `abb285f`; 2b exits 1 when a
path is corrupted, and 2a alone was confirmed to false-pass on a missing file,
which is why 2b is not optional. Non-vacuity is established historically as
well: at `abb285f^` the 2a scope contained the stale assertion in both adapter
ports, so this criterion was **red before the unit's fix and green after** —
it discriminates the deliverable rather than merely being satisfiable.

### Why the suggested replacement was not adopted verbatim

`lead-programmer` proposed
`! grep -rn 'spawn the reviewer' adapters/codex/hooks/ adapters/cursor/hooks/ hooks/scripts/stop-gate.sh`.
Correct in intent, and it passes today — but it is scoped by **directory**,
and both `adapters/{codex,cursor}/hooks/scripts/` contain the ported
`reviewer-route-gate.sh`, which is Keep-unchanged and which *does* discuss
"lead-programmer may not spawn the reviewer directly" in its header comment.
Those ports pass the directory-scoped grep today only because the phrase
happens to straddle a comment line break —
`adapters/cursor/hooks/scripts/reviewer-route-gate.sh:9` ends on "may not
spawn the" and `:10` begins "# reviewer directly". A future comment reflow, or
a `fmt`-width change, would reintroduce the identical false positive on a
Keep-unchanged file. Scoping to the three stop-gate **files** by name removes
that dependency on comment wrapping entirely, and matches the precedent form
Pass 1's #193 already used on the canonical script.

### Coverage deliberately given up, and where it is recovered

The published criterion was a repo-wide sweep; the replacement is a
three-file check. What is no longer caught: a stale block-message assertion
appearing in some *new* file outside these three. That is accepted, because a
repo-wide sweep for this phrase is permanently unsatisfiable — legitimate
"never blocked" prose and the route-gate's own true block message both contain
it, and neither can be textually distinguished from a stale assertion without
brittle negative-lookahead patterns that would themselves need a spec. The
backstop is unchanged and already exists: Step 8's `P2-C1` verdict covers
"adapter stop-gate ports … carrying the stale block message" behaviourally,
via a fresh audit rather than a grep. A general "block messages must not
assert an unverifiable next move" check, if wanted, is Pass 3 scope and needs
its own mechanism — not a widened grep.

### Effect on #202, and what task-master / the orchestrator must carry

Non-blocking to #202's own verdict, which is judged on the deliverable
independently. But the corrected text is now the criterion of record, and
**issue #202's body still prints the superseded `! grep -rn 'spawn the
reviewer' adapters/ hooks/`.** `task-master` / the orchestrator must carry
2a+2b above into #202's record so the reviewer and any later re-run are
checking the criterion that can actually pass. Nothing is re-dispatched by
this amendment and no other criterion changes; criterion 1's case-insensitive
sweep was re-run during this verification and still exits 0, untouched.

### Clarifications addendum (extends the body's section; append-only)

Re-scored only the categories this amendment touches; the rest of the body's
scorecard stands.

```
1. Functional scope & success criteria: Partial
6. Edge cases / failure handling: Partial
9. Completion / acceptance signals: Partial
```

- 2026-08-01 Completion / acceptance signals: Q Can Step 4's criterion 2 be
  satisfied by any work permitted by Step 4's own Keep-unchanged list? → A
  (self-resolved): no — all four residual matches sit on Keep-unchanged
  surfaces. Replaced with a file-scoped check plus a non-vacuity floor.
- 2026-08-01 Edge cases / failure handling: Q Does the replacement criterion
  fail correctly when a scoped path is missing or renamed? → A
  (self-resolved): 2a alone does not (verified: `!` inverts grep's exit 2 into
  a pass); 2b closes it by requiring all three files to be *listed* by
  `grep -l`, which a missing file cannot be.
- 2026-08-01 Functional scope & success criteria: Q Should the repo-wide sweep
  be preserved by excluding the known-legitimate sites textually? → A
  (self-resolved): no — the exclusions would encode three prose strings that
  Keep-unchanged surfaces are free to reword, trading an unsatisfiable
  criterion for a brittle one. Coverage loss is stated above and backstopped
  by Step 8's `P2-C1`.

### Self-check addendum (extends the body's section; append-only)

- CHK22: Is the replacement criterion satisfiable by work Step 4 is permitted
  to do? — PASS (scoped to the three stop-gate scripts, all of which Step 4
  owns or which #193 already cleared)
- CHK23: Can the replacement pass vacuously — on a renamed, missing or empty
  file? — FAIL (ambiguous) on the first draft, which was 2a alone; revised in
  place by adding the 2b floor, and the hole was demonstrated live before
  closing it.
- CHK24: Was the replacement red before the unit's fix and green after, rather
  than green at baseline? — PASS (`abb285f` is the commit that removed the
  stale assertion from both ports; `git log -S` confirms)
- CHK25: Does this amendment agree with Step 4's Keep-unchanged list and with
  Step 8's `P2-C1` about which surface owns the residual matches? — PASS
  (Keep-unchanged names the route-gate "and its adapter equivalents" and
  `templates/persona-protocol.md`; `P2-C1` retains the behavioural backstop)
- CHK26: Does the amendment state what coverage is lost, rather than implying
  the narrowed check is strictly better? — PASS ("Coverage deliberately given
  up" names the loss and routes the general case to Pass 3)

All items resolved; no Open Question is raised by this amendment and nothing
is outstanding. **Net effect on scope:** one criterion replaced, no step
added or removed, no ruling reopened.

---

## Debug spec — unit 205 (Step 7) hit the 2-FAIL cap (2026-08-02)

Append-only, same discipline as Amendments A1/A2. This is **not** a replan of
Step 7 and touches no other step: Step 7's affected-files list, its
Keep-unchanged list, and criteria 1–4 all stand unchanged. What follows adds
criteria 5–9 and records why two attempts were needed.

### Front half — `fail-triage` VERIFY / CATEGORIZE

**VERIFY — could-not-reproduce via the acceptance criteria; defect reproduced
only by direct read.** All four of Step 7's criteria were re-run live on the
working tree at `ad36cf1`, not read from the `.fail` record:

```
grep -qi 'parity' .claude/wiki/modules/adapters.md              -> rc 0
  (and 'adapter-stop-gate-parity.test.sh' named there, 2 hits)
grep -q 'adapter-stop-gate-parity' .claude/wiki/modules/hooks.md -> rc 0
grep -qi 'behavioural parity\|behavioral parity' CONTEXT.md      -> rc 0
bash tests/validate.sh                                           -> rc 0
                                                    (468 OK, 0 FAIL)
```

**All four are green while the defect is present.** The defect reproduces only
by reading the prose:

```
awk '/[*][*]Empty-reason rejection/,/^[[:space:]]*$/' \
  .claude/wiki/modules/hooks.md
```

emits, in one paragraph, "…after the WIP sentinel was observed accepting such
content…" followed two sentences later by "…remain accepted per WIP-sentinel
precedent (non-empty file is sufficient)" — the same named mechanism as both
the accepter and the rejecter of empty content. Source disagrees with the
first clause: `hooks/scripts/stop-gate.sh:199` gates the sentinel on
`[ -s "$sentinel" ]` and `:206` prints "…is empty - a reason is required". The
branch that actually accepted `defer: ` / `skip: ` is the pending-review
flag's, at `stop-gate.sh:148`/`:158`.

**CATEGORIZE — spec/criterion defect (primary), with one execution component
on the first attempt.** Not a code defect: no code is in scope for this unit,
and the source the prose describes is correct. See the split below.

### Root-cause diagnosis

The escalation is **not** two independent execution slips, and it is not one
systemic writing failure either. The two FAILs have different proximate causes
and one shared spec-level cause.

**Proximate cause, FAIL #1 (closed):** a staging/provenance misjudgment on a
dirty tree. `dbb44f9` classified this unit's own hooks.md shape-handling hunk
as unrelated prior-session Pass 1 Step 10 work and deliberately left it
unstaged; `ad36cf1`'s message documents the correction. Execution, not
writing.

**Proximate cause, FAIL #2 (open):** the misattributed sentence was **not
composed fresh under the fix attempt**. `git show ad36cf1 --
.claude/wiki/modules/hooks.md` shows the whole "Empty-reason rejection"
paragraph arriving as one `+` block — it is the inherited working-tree hunk
that FAIL #1 forced to land. Attempt 2 correctly framed its own job as *land
the hunk that never landed*, and a landing operation carries no prompt to
re-audit inherited prose for factual attribution. So attempt 2 did not repeat
attempt 1's mistake; it inherited an unreviewed sentence that attempt 1's
defect had kept out of the reviewer's sight.

**Shared spec-level cause — an Amendment A1 propagation gap.** Amendment A1
introduced the empty-after-colon rejection as a new, operator-ruled behaviour,
and its own "Edits:" line enumerates where it propagated: Step 3's second
bullet, Step 3 criterion 5, Step 6's CHANGELOG bullet, Open Question 1,
Clarifications, Self-check CHK4. **Step 7 and the "Scribe update hint" are
absent from that list.** The consequences compound:

1. **Step 7's criteria predate the deliverable they were meant to cover.**
   Criteria 1–4 are three presence-greps plus `validate.sh`. Nothing in them
   mentions the empty-reason rule at all, and criterion 2 greps only
   `adapter-stop-gate-parity` — which is why FAIL #1's *entirely missing*
   deliverable and FAIL #2's *factually wrong* deliverable were both invisible
   to the same four commands. One under-covering criteria set explains both
   FAILs, which is the answer to "why twice on a doc-only unit".
2. **The Scribe update hint says only "hooks.md needs the defer shape-handling
   rules"** — no mechanism named, no attribution constraint.
3. **Correct attribution is stated in exactly one place the scribe was never
   routed to.** §C-B(b) says it plainly ("the WIP sentinel genuinely enforces
   this … So the defer/skip path is the inconsistent one"), but §C-B is a
   Context section, and issue #205's own Methodology bullet 4 states that
   dispatch prompts cite the issue and do not re-paste spec context. `#205`
   Objective bullet 2 did carry the requirement forward in prose ("state this
   as a correction against the hook's own pre-existing 'Empty reason
   rejected.' message") — but with no criterion behind it, so nothing could
   fail when it was missed.
4. **The two surfaces the writer *was* routed to both place "WIP sentinel"
   next to the empty-reason rule as a positive precedent.** Step 3's second
   bullet: "matching the block messages' existing 'Empty reason rejected.'
   claim **and the WIP sentinel's precedent**". Neither surface carries the
   negative half — that the sentinel is not the mechanism that was broken.
   This is a conflation-prone framing, not a careless read.

**Therefore the revised criteria must do more than fix one sentence.** They
must (a) pin the attribution machine-checkably, and (b) close the
un-criterioned `#205` Objective bullet 2 requirement, so a re-dispatch cannot
satisfy Step 7 while getting either wrong.

Vocabulary note, since it determines that this is a factual error rather than
loose synonymy: "WIP sentinel" and "pending-review flag" are the repo's own
mechanism names 1 and 2 in `.claude/wiki/persona-handoff-mechanisms.md`,
indexed as such at `.claude/wiki/README.md:12`, and `hooks.md` itself already
uses "pending-review flag" at `:24` and `:38`.

### Evaluation of the reviewer's suggested wording

The reviewer suggested: "… after the pending-review flag's `defer: `/`skip: `
branch was observed accepting such content despite the hook's own 'Empty
reason rejected.' block message", leaving the next sentence's WIP-sentinel
precedent citation as-is. **Adopted, with two non-gating notes.**

- Correct on the mechanism (`stop-gate.sh:148`/`:158` is the pending-review
  flag's branch), correct on the repo's naming, and strictly more precise than
  the text it replaces: "despite prose claims of rejection" named no artifact,
  whereas "the hook's own 'Empty reason rejected.' block message" names one
  that exists verbatim in the source and simultaneously satisfies `#205`
  Objective bullet 2 — which the current text misses. Leaving the following
  sentence alone is also right: the sentinel genuinely is the precedent for
  accepting whitespace-only reasons, so deleting sentinel mentions wholesale
  would be an over-correction. Criterion 7 below exists to prevent exactly
  that over-correction.
- **Note 1 (style, non-gating):** this repo's prose quotes the block message
  with double quotes (`#205` and §C-B both do); the suggestion uses single
  quotes. Criteria below match the bare phrase and are indifferent.
- **Note 2 (style, non-gating):** do **not** add `stop-gate.sh:148`/`:158`
  line citations to the wiki page. `hooks.md` cites no source line numbers
  anywhere and cites issues instead (e.g. `(issue #202)` at `:72`); line
  numbers drift. If a pointer is wanted, `(issue #201)` matches convention.

### Revised acceptance criteria — Step 7 (additive; 1–4 stand unchanged)

Criteria 5–8 share one extraction; run it first. Criterion 5 is the
non-vacuity floor for 6–8 and is not optional: without it, a renamed or
deleted paragraph makes the negative half of criterion 6 pass on empty input.

```sh
PARA="$(awk '/[*][*]Empty-reason rejection/,/^[[:space:]]*$/' \
  .claude/wiki/modules/hooks.md | tr '\n' ' ')"
```

Flattening with `tr` is required, not cosmetic: the phrase "WIP-sentinel
precedent" straddles a line break in the current file, and a line-oriented
grep for it returns a false negative.

5. **Non-vacuity floor.** `[ "$(printf '%s' "$PARA" | wc -c)" -ge 300 ]` exits
   0. Measured at `ad36cf1`: 562 characters.
6. **Correct attribution (the defect this escalation is about).** The clause
   asserting the observation names the pending-review flag and does not name
   the sentinel:

   ```sh
   OBS="$(printf '%s' "$PARA" | grep -o '[^.]*observed[^.]*')"
   [ -n "$OBS" ] \
     && printf '%s' "$OBS" | grep -q 'pending-review flag' \
     && ! printf '%s' "$OBS" | grep -qi 'sentinel'
   ```

   Scoped to the observation clause rather than the paragraph, deliberately:
   a paragraph-wide `! grep -i sentinel` would forbid the legitimate precedent
   citation criterion 7 requires, i.e. it would be unsatisfiable against this
   step's own required output — the failure mode Amendment A2 already hit
   repo-wide. The `[ -n "$OBS" ]` guard is this criterion's own second floor,
   since a negated grep passes vacuously on empty input.
7. **The correct precedent citation survives the fix (anti-over-correction).**
   `printf '%s' "$PARA" | grep -q 'WIP-sentinel precedent'` exits 0.
8. **Correction framing — closes `#205` Objective bullet 2, previously
   un-criterioned.** `printf '%s' "$PARA" | grep -q 'Empty reason rejected'`
   exits 0. The change must read as a correction against the hook's own
   pre-existing block message, not as an arbitrary new restriction.
9. **Regression floor on the deliverable FAIL #1 lost.**
   `grep -qi 'flatten' .claude/wiki/modules/hooks.md` exits 0. **This is
   deliberately green at baseline** and verifies no new writing — it is the
   grep the reviewer used to re-verify FAIL #1's closure, promoted from a
   one-time manual read into a standing check so the re-dispatch's edit to the
   adjacent paragraph cannot silently drop it. It must not be counted as
   evidence of new work.

**Baselines, measured live before publishing (2026-08-02, tree at
`ad36cf1`).** Criteria 5–8 were run against the defective text and against a
simulated fix applying the reviewer's wording:

| criterion | at `ad36cf1` (defect) | with the fix applied |
| --- | --- | --- |
| 5 non-vacuity floor | PASS (562 ≥ 300) | PASS |
| 6 attribution | **FAIL** | PASS |
| 7 precedent retained | **FAIL** (line-break straddle; PASS once flattened) | PASS |
| 8 correction framing | **FAIL** | PASS |
| 9 flatten regression floor | PASS | PASS |

Criterion 6 was additionally run against a reworded variant that moves the
precedent citation ahead of "accepted" in the following sentence; it stays
PASS, confirming the clause scoping does not false-positive on legitimate
rewordings of the neighbouring sentence.

**Scope of the re-dispatch:** one sentence in
`.claude/wiki/modules/hooks.md`'s "Empty-reason rejection" paragraph. No other
paragraph, file, step, or ruling is reopened. `adapters.md` and `CONTEXT.md`
are untouched by this debug spec — the `.fail` record verified both clean.

### Clarifications addendum — re-scored for this escalation only

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Missing
9. Completion / acceptance signals: Partial

- 2026-08-02 Functional scope & success criteria: Q Does closing this defect
  require rewriting Step 7, or only adding criteria to it? → A
  (self-resolved): criteria only — the three affected files, the deliverable
  set, and criteria 1–4 were all verified correct; the gap is coverage, not
  scope.
- 2026-08-02 Domain entities / data model: Q Which named mechanism governs
  empty-reason rejection for `defer: `/`skip: `? → A (self-resolved): the
  pending-review flag (`stop-gate.sh:148`/`:158`); the WIP sentinel
  (`:199`/`:206`) is only the *precedent* for the whitespace-only carve-out,
  and the two are separately-documented mechanisms 1 and 2 in
  `persona-handoff-mechanisms.md`.
- 2026-08-02 Terminology consistency: Q Is "WIP sentinel" for the
  pending-review flag loose synonymy this repo tolerates? → A (self-resolved):
  no — `README.md:12` indexes them as distinct mechanisms and `hooks.md`
  already uses "pending-review flag" at `:24`/`:38`; criterion 6 makes the
  distinction machine-checkable rather than conventional.
- 2026-08-02 Completion / acceptance signals: Q Why did four green criteria
  coexist with two FAILs? → A (self-resolved): criteria 1–4 are presence-greps
  covering three of the unit's deliverables by string presence and none by
  correctness; Amendment A1 never propagated the empty-reason deliverable into
  Step 7. Criteria 5–9 close it.

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim here was reproduced live
  (all four original criteria re-run, source line numbers read, both
  fix-attempt diffs inspected, criteria 5–9 run against defective, fixed and
  reworded text).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  attribution requirement moves from `#205` prose into a runnable check.
- P3 "Version-stamp discipline": not engaged — no version-stamped file is
  touched; Step 6 owns the bump and CHANGELOG, and that constraint is
  unchanged.
- P4 "Optional personas degrade gracefully": not engaged.
- P5 "`tests/validate.sh` is the merge gate": satisfied — criterion 4 stands
  unchanged and still gates the re-dispatch.

### Self-check addendum (extends the body's section; append-only)

- CHK27: Does the diagnosis state explicitly whether the cause is spec-level
  or two independent execution slips? — PASS (spec-level primary, named as an
  Amendment A1 propagation gap, with the per-attempt proximate causes kept
  distinct)
- CHK28: Can criterion 6 pass vacuously on a renamed, deleted or empty
  paragraph? — FAIL (ambiguous) on the first draft, which had the negated grep
  alone; revised in place by adding criterion 5's floor and the `[ -n "$OBS" ]`
  guard, after demonstrating the hole live.
- CHK29: Is criterion 6 satisfiable simultaneously with criterion 7, or do
  they contradict each other about whether "sentinel" may appear? — PASS
  (6 is scoped to the observation clause, 7 to the paragraph; both verified
  green on the same simulated fixed text)
- CHK30: Were criteria 5–9 red before the fix and green after, rather than
  green at baseline? — PASS for 6, 7 and 8 (measured, table above); criterion
  9 is green at baseline **by design** and is labelled a regression floor
  in-line so a reviewer cannot mistake it for verification of new work.
- CHK31: Do this section and the reviewer's suggested wording agree on whether
  the following sentence's WIP-sentinel citation is kept? — PASS (both keep
  it; criterion 7 enforces it)
- CHK32: Is `#205` Objective bullet 2 ("state it as a correction against the
  hook's own … message") represented by a criterion? — FAIL (missing) in the
  published Step 7; revised in place as criterion 8.
- CHK33: Does this section avoid reopening any step other than Step 7? — PASS
  (Steps 1–6 and 8, Amendments A1/A2, and all Keep-unchanged lists are
  untouched; the re-dispatch's blast radius is one sentence in one file)

All items resolved; no Open Question is raised by this debug spec. **Net
effect on scope:** five criteria added to Step 7, no criterion removed, no
step added or removed, no ruling reopened.
