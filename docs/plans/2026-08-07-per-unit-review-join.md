# Per-unit review join + no self-authorized bypass (issue #226)

Date: 2026-08-07
Author: spec-master
Status: finalized, ready for `task-master`
Resolves: GitHub issue #226 (deferred from the #219 / #220 / #221 review cycle)
Amends: the clear-watermark mechanism landed by #221 and ported by #222; the
shared persona protocol (`templates/persona-protocol.md`).

> Terminology note: this document refers to the reviewer-owned marker directory
> (the gitignored `reviewed` directory under the project dot-dir) by role rather
> than by literal path, because this repo's own Bash/Write gate refuses to lex
> any command whose text spells that path. "Marker" always means a `.pass` /
> `.fail` / `.blocked` file in that directory.

## Goal

Replace the single global clear-watermark with a **per-unit review join**, so
that the hook coupling a reviewer's flag-clear to a marker-write asks the right
question — "did *this dispatched unit* get a verdict?" — instead of the wrong one
it asks today ("has *any* marker been written since *anyone's* last clear?").

Three defects close together, and they are causally linked, so they ship as one
change:

- **Under-inclusive.** Unit A's marker satisfies unit B's check. The
  `find`-based predicate proves "some marker exists", never "this unit's verdict
  was recorded".
- **Over-inclusive / liveness.** Reproduced live 2026-08-02. Reviewer A writes a
  valid marker; concurrent reviewer B clears first and advances the shared
  watermark past A's marker; A's own subsequent stop is then blocked demanding a
  marker it already wrote. The same shape structurally traps an advisory
  second-reviewer dispatch (a `Roast pass` on an already-verdicted unit), which
  is *forbidden* to write a marker and so has no legal exit at all.
- **Existence-only validation.** The check is satisfied by a bare zero-byte
  `touch`, while `task-gate.sh`'s `marker_valid()` explicitly rejects exactly
  that ("existence alone is not enough"). Two mechanisms from the same parent
  spec use two different definitions of "a marker was written".

Plus the **process half**, which is neither optional nor a later afterthought: a
persona blocked by a control whose verdict it does not own must report-and-wait,
never self-authorize a workaround — *including* a metadata-only one such as
bumping a marker's mtime. The code bug created a bind with no sanctioned exit;
one reviewer instance took a bypass, a second correctly refused and escalated.
Closing the code bug without codifying the rule leaves the next bind unhandled.

**Honest scoping, stated up front so ADR-0016 does not overclaim.** The new
design fixes the liveness direction *completely* and the under-inclusive
direction *substantially but not absolutely* — see "Residual gaps". It also
narrows the mechanism's coverage: it fires only for reviewer dispatches carrying
a `Unit: <id>` first line. Step 5 makes that line mandatory in the prose
governing reviewer dispatch, but the hook itself fails OPEN without it —
deliberately, matching today's bootstrap posture.

## Context

Verified facts this plan rests on, all read/grep-derived at commit `f2d8d2d`
(`master`, 2026-08-07). An `explorer` dispatch for the same structural map did
not return before this document was finalized; every claim below was therefore
measured directly. **Re-measure if execution is deferred past further commits.**

**The mechanism as it stands**

- `hooks/scripts/stop-gate.sh:96-111` — `marker_since_last_clear()` returns 2
  when `.claude/.last-review-clear` is absent (bootstrap, fail OPEN), 0 when a
  `*.pass`/`*.fail` is `-newer` than it, 1 otherwise. `-newer` is applied over a
  whole-directory glob: no unit id ever enters the predicate.
- `hooks/scripts/stop-gate.sh:137-163` — the reviewer's `SubagentStop` grant
  branch runs that check after the `.blocked` early-exit and before the global
  `rm -f` of every pending-review flag, then `touch`es the watermark.
- The `SubagentStop` payload carries `agent_type`, `agent_id` and `session_id`.
  **It carries no unit id and no prompt.** This is the root constraint: any
  per-unit join must be established at *dispatch* time, not at stop time.
- `hooks/scripts/reviewer-route-gate.sh` (66 lines) is the other half of this
  mechanism and is already a `PreToolUse (Agent)` hook. It reads
  `.tool_input.subagent_type` but **not** `.tool_input.prompt` (verified: zero
  matches for `tool_input.prompt`).
- `hooks/scripts/dispatch-hygiene.sh:270-330` already parses
  `^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$` from a
  prompt's first non-blank line — but only for **gated** targets, and its header
  states "explorer/scribe/reviewer spawns are never touched". That invariant is
  worth preserving; the join belongs in the reviewer-lifecycle hook instead.
- `agents/orchestrator.md:106-110` **already requires** the unit id in every
  reviewer dispatch ("never omit the id; the reviewer needs it to write" the
  marker). `agents/reviewer.md:118-120` already gives `Unit: <id>` on the first
  non-blank line top precedence for the marker filename. Requiring it as the
  *literal first line* formalizes an existing obligation; it adds no new one.

**Why the issue's three suggested directions collapse to one**

- *Direction A (per-unit watermark) and Direction B (stamp the task-id at
  dispatch) are the same fix.* A per-unit watermark is unimplementable without B,
  because stop time has no unit id (above). They are one design, not two.
- *Keying per **agent_id** instead is provably wrong*, recorded here so it is not
  re-proposed: the check must fire on a reviewer's **first** stop when no marker
  was written — that is its entire purpose — but a per-agent watermark has no
  prior value on a first stop, so every first stop would bootstrap fail-open and
  the check would never fire for anyone. The global watermark's cross-dispatch
  persistence is what carries first-stop coverage today. Per-agent keying
  destroys it.
- *Direction C (accept a marker newer than the watermark's predecessor)* fixes
  only the liveness direction, leaves under-inclusiveness untouched, and degrades
  with more than two concurrent reviewers. Rejected.

**Blast radius of a template change (discovered; not visible from the issue)**

- `bin/cli.js:546-677` holds `PROTOCOL_SECTIONS_BY_PERSONA`, an **exhaustive**
  per-persona classification of every canonical `## ` section, asserted at module
  load by `assertProtocolMatrixComplete` (`:654-677`). A new canonical section
  with no matrix classification makes `bin/cli.js` **unloadable** — no command
  renders any mirror. `UNIVERSAL_PROTOCOL_CORE` (`:525-531`) is spread into all
  six full-tier rows, so one entry there classifies the section for every row.
  This exact failure is on record: `224.fail` names the assertion "--update fails
  at load and rewrites no mirror when the template gains a section no matrix row
  classifies".
- `tests/adapter-protocol-parity.test.js:42-47,93-109` derives the canonical
  section list from the template and **fails closed** on any section lacking a
  `codexMap`/`cursorMap` entry, forcing an explicit present-or-deferred decision.
- Six full-tier mirrors carry the canonical protocol (`spec-master`,
  `orchestrator`, `milestone-auditor`, `task-master`, `lead-programmer`,
  `reviewer` — measured, not assumed); nine mirrors total carry some protocol
  block. Regeneration is `node bin/cli.js --update --check` — a **forced render,
  not a dry run**; a plain `--update` takes the version-match fast path and
  writes nothing.

**Adapter surface (the issue's scope note about #222)**

The #222 ports **have landed and do replicate the global-watermark design
verbatim**:

- `adapters/codex/hooks/scripts/stop-gate.sh:64-77` and `:131-158`
- `adapters/cursor/hooks/scripts/stop-gate.sh:47-60` and `:91-117`

Both carry an identical `marker_since_last_clear()` and `.last-review-clear`.
Both also ship a `reviewer-route-gate.sh` (61 and 59 lines). So the fix lands in
**six script files**, not one — and **per-location, not centralized**, because
`bin/cli.js` copies adapter files verbatim rather than generating them (the same
reason `tests/adapter-protocol-parity.test.js` is a drift test rather than
construction-time injection; see its header at `:4-16`).
`tests/adapter-stop-gate-parity.test.sh` (379 lines, scenarios (f0)-(f4) plus
mutation control (g)) is the mechanism keeping the three copies honest and must
be extended, not bypassed.

One prior defect on this surface is already closed and must stay closed:
`222.fail` recorded that the codex port's clear-watermark block used a bare
`exit 2`, bypassing codex's `block()` loop-guard helper and removing the only
liveness escape for this very check. It now correctly calls `block()`
(`adapters/codex/hooks/scripts/stop-gate.sh:147-153`). **The replacement block
path must also call `block()` in codex**; claude and cursor have no loop guard
and keep a bare `exit 2`.

**Test harness**

- `tests/validate.sh` runs each suite by **explicit registration** (`:242-302`,
  `:354-368`), not auto-discovery. A new test file that is not registered runs
  nowhere.
- `tests/stop-gate-blocked.test.sh` (455 lines) is the fixture pattern: canned
  hook-input JSON over stdin, projects seeded under `mktemp -d` by
  `make_project()`. Cases (o)-(v) at `:295-445` are the existing clear-watermark
  coverage, including mutation control (v).
- All three affected suites are green at `f2d8d2d` (measured).

**Documented state to correct**

- `.claude/wiki/modules/hooks.md:208-256` documents the clear-watermark and
  already carries a "Known issues" bullet for #226 stating the report-and-wait
  rule — descriptively, in a wiki. The rule needs to be **normative**, in the
  protocol every persona actually carries.
- `CONTEXT.md:67-70` and `:95-102` define **Clear-watermark** as a glossary term
  (capital C at `:95` — `225.fail` was a case-mismatch defect on this exact
  entry; write criteria case-insensitively or against the literal file text).
- `adapters/codex/hooks/scripts/stop-gate.sh:151-152` still prints a **v2**
  marker example ("A v2 PASS or FAIL marker must be written"), stale since marker
  format v3 landed in 0.27.0. This plan rewrites that exact message anyway (it
  must now name the unit), so correcting v2 to v3 inside it is part of the same
  edit, not unrelated drift.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Missing
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-07 Functional scope & success criteria: Q The issue offers three
  non-prescriptive fix directions — which is adopted, and must the fix close both
  failure directions? -> A (self-resolved): adopt the A+B synthesis (a per-unit
  join stamp written at reviewer-dispatch time), because A is unimplementable
  without B and C fixes only one direction. Both failure directions are in scope;
  the liveness one closes completely, the under-inclusive one closes to a
  documented residual (see "Residual gaps").
- 2026-08-07 Domain entities / data model: Q What exactly is the join artifact —
  its path, content, lifecycle, and who owns each transition? -> A
  (self-resolved): a **review-join stamp** at `.claude/.review-join.<unit-id>`,
  written by `reviewer-route-gate.sh` at reviewer-dispatch time, consumed
  (deleted) by `stop-gate.sh` when that unit's verdict marker is found. Full
  state table in Step 2. It replaces `.claude/.last-review-clear` entirely; the
  old file is retired and left inert.
- 2026-08-07 User interaction flow: Q What does a blocked reviewer see, and what
  is it allowed to do about it? -> A (self-resolved): the block message names the
  specific unit id whose verdict is missing (today's message names none), and
  Step 4's new protocol section states the only two legal responses. Bumping a
  marker's mtime, `touch`ing a file to satisfy a gate, and deleting a stamp are
  all named as forbidden.
- 2026-08-07 Non-functional attributes: Q This is an audit/security control —
  which way must each new branch fail, and is a prompt read in a PreToolUse hook
  acceptable cost? -> A (self-resolved): fail OPEN when no stamp exists (identical
  posture to today's bootstrap, and the only safe default for agent-teams
  `SendMessage` resumes and for projects with no `Unit:` convention); fail CLOSED
  when stamps exist and none is satisfied. Cost is one `jq` read of a field the
  sibling hook in the same `PreToolUse (Agent)` chain already reads, plus one
  `head -n 1` per stamp — no subprocess fan-out, no `git`.
- 2026-08-07 External dependencies & integrations: Q Do #222's adapter ports
  replicate the bug, and does the fix apply per-location or centrally? -> A
  (self-resolved): they replicate it verbatim in both ports, and the fix must be
  applied **per-location** (six script files) because `bin/cli.js` copies adapter
  files verbatim rather than generating them.
  `tests/adapter-stop-gate-parity.test.sh` is the anti-drift mechanism and is
  extended, not bypassed.
- 2026-08-07 Edge cases / failure handling: Q What are the branches, and which
  direction does each fail? -> A (self-resolved): seven, enumerated as a state
  table in Step 2. Governing rule: **a stop is allowed iff no stamp exists, or at
  least one stamp is satisfied.** That single rule is what makes the advisory
  second pass, the same-reviewer re-fire, and the concurrent-reviewer case all
  live, while a reviewer that wrote nothing still blocks.
- 2026-08-07 Technical constraints & tradeoffs: Q What does adding a canonical
  protocol section actually cost? -> A (self-resolved): three coupled edits that
  are invisible from the issue — a `UNIVERSAL_PROTOCOL_CORE` entry in
  `bin/cli.js` (omitting it makes `bin/cli.js` unloadable), a parity-map entry in
  both `codexMap` and `cursorMap`, and the prose in both adapter ports. Recorded
  as R2/R3 and as Step 4's affected files.
- 2026-08-07 Terminology consistency: Q "clear-watermark" is an established
  glossary term in `CONTEXT.md` and the wiki — is the new mechanism a renamed
  watermark or a new noun? -> A (self-resolved): a **new noun**. The canonical
  term is **review-join stamp**; "clear-watermark" is retired and its glossary
  entry rewritten to say so, rather than redefined in place. Redefining a term
  whose old meaning is cited in an ADR and two test suites is how `225.fail`
  happened. Only `review-join` is used as a greppable token in criteria.
- 2026-08-07 Completion / acceptance signals: Q What is the acceptance signal for
  the change as a whole? -> A (self-resolved): `bash tests/validate.sh` exits 0
  with the new `tests/review-join.test.sh` **registered in it**, plus each step's
  own greppable criteria. `tests/validate.sh` is the declared merge gate
  (constitution P5); registration is explicit, so an unregistered new suite runs
  nowhere and is a Step 1 defect.

## Risks / dependencies

- **R1 — heavy prior-FAIL history on four of this plan's surfaces.** The
  reviewer's records directory holds **25** `.fail` records (measured
  2026-08-07; it is live local state and one landed *during* this plan's
  authoring, so re-measure rather than quoting this number). Filtered by the
  surfaces this plan touches:
  - **stop-gate / clear-watermark / pending-review**: 124, 128, 150, 191, 197,
    205, 222, 224, 225, 260, 261 — eleven records. That is **Steps 2 and 3's**
    surface.
  - **`bin/cli.js` and the persona mirrors**: 124, 128, 191, 192, 197, 224, 225,
    237, 238, 261, `gh-228-deepmerge-dedup` — eleven records. That is
    **Steps 4 and 6's** surface.
  - Read in full and load-bearing here: `222.fail` (the codex `block()` bypass),
    `224.fail` (validate.sh green only in a dirty tree; partially committed
    `--update` output leaving a stale `pluginVersion`), `225.fail` (glossary case
    mismatch; docs written from the spec draft rather than the shipped code;
    unrelated dirty state in the wrong commit), `220.fail` (a `set -u`
    arithmetic-expansion abort in a sibling hook that `||` could not catch,
    silently disarming every check with no audit trace).

  **Consequence for `task-master`: Steps 2, 3, 4 and 6 must NOT be tagged
  `haiku`.** This is durable on-record evidence that these surfaces need more
  judgment than a mechanical executor brings. Steps 1, 5, 7 and 8 carry no
  matching history and may take the normal default.
- **R2 — a new canonical protocol section can brick the CLI.** Omitting the
  `UNIVERSAL_PROTOCOL_CORE` entry makes `bin/cli.js` throw *at module load*, so
  no command renders anything — the exact failure `224.fail` records. Step 4 puts
  the `bin/cli.js` edit and the template edit in the same unit for this reason;
  they must not be split across units.
- **R3 — the adapter parity test fails closed on a new section.** Both `codexMap`
  and `cursorMap` need an entry. This plan chooses `probe` (present in both
  ports), not `deferred`: the rule is platform-independent, and deferring it
  would leave the exact gap the incident exposed in two of three platforms.
- **R4 — `set -euo pipefail` is active in all six scripts.** Every new
  glob/`head`/`grep` must be wrapped so a non-zero exit is captured, never
  propagated (`|| true`, `|| rc=$?`, `2>/dev/null`). `220.fail` records this trap
  already being sprung once in this hook family. Use `shopt -s nullglob` /
  `shopt -u nullglob` around every stamp glob, matching the existing convention
  at `stop-gate.sh:129-131`.
- **R5 — the unit id reaches a filesystem path.** `<unit-id>` comes from a
  model-authored prompt. It must be constrained by the same ERE
  `^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$` that
  `dispatch-hygiene.sh:277` already uses, **plus** the same explicit
  `case "$id" in */*|*..*) ;;` traversal guard it keeps at `:284-286`. Do not
  widen the character class.
- **R6 — existing fixtures assume the old mechanism.** Cases (o)-(v) of
  `tests/stop-gate-blocked.test.sh` and (f0)-(f4)+(g) of
  `tests/adapter-stop-gate-parity.test.sh` seed `.last-review-clear` and, in (f2),
  a **zero-byte** `touch`ed marker that the new format check must reject. These
  are rewrites, not additions, and the rewrite is expected — but the mutation
  controls (v) and (g) must remain *binding* after it, i.e. still fail against a
  mutant with the check reverted.
- **R7 — regenerating mirrors is a live-repo write.** This repo dogfoods its own
  plugin. `node bin/cli.js --update --check` from the repo root is the intended
  command and also rewrites `.claude/persona-config.json`. Every *other*
  `cli.js` invocation must be subshell-`cd`'d into a throwaway directory. Step 6
  ends with a working-tree review of exactly what the render touched, and
  `224.fail`'s lesson applies directly: commit **all** of the render's output, or
  the next `--update` reports divergence.
- **D1** — Step 2 depends on Step 1 (the stop-side check reads the stamp Step 1
  writes). Ship them adjacent; a tree with Step 1 but not Step 2 is inert-safe (a
  stamp nothing reads), a tree with Step 2 but not Step 1 fails open always.
- **D2** — Step 3 depends on Steps 1 and 2 (it ports finished logic).
- **D3** — Step 6 depends on Steps 4 and 5 (the render must carry the finished
  template and persona wording).
- **D4** — Steps 7 and 8 depend on Steps 1-6 (docs and CHANGELOG describe landed
  behaviour).
- **D5** — Steps 4 and 5 are independent of Steps 1-3 and may run in parallel.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — every Context claim was read or
  run at `f2d8d2d`, including the three suites' current green state and the
  non-vacuity of every new-token criterion (measured: all absent today). The Goal
  explicitly declines to claim the under-inclusive direction closes absolutely.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  Step 6 regenerates all mirrors via `node bin/cli.js --update --check` and
  forbids hand-editing any mirror. The adapter ports in Step 3 are the one place
  hand-adaptation is correct, and Context records why (`bin/cli.js` copies them
  verbatim by design; the parity *test* is the deterministic guard).
- P3 "Version-stamp discipline" (MUST): satisfied — Step 8 bumps
  `.claude-plugin/plugin.json` and `package.json` to `0.28.0` and adds the
  CHANGELOG entry. Declared sequencing detail: the bump lands last, so
  intermediate commits on this branch are momentarily unstamped; the branch as a
  whole satisfies P3.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — Step 4's new
  section is written persona-agnostically ("a control whose verdict you do not
  own"), naming no persona unconditionally; Step 5's reviewer/orchestrator prose
  sits inside already-reviewer-conditional text.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — every step
  carries `bash tests/validate.sh` as a criterion, and Steps 1-3 extend the
  suites it runs. Step 1 additionally carries a criterion that the new suite is
  *registered* in it, since registration is explicit rather than discovered.

## Deliberate non-changes

Stated so a later reader does not read them as oversights, and so `task-master`
does not slice units for them.

1. **No change to `dispatch-hygiene.sh`.** Its `Unit:` parser is the model for
   the new one, but its "gated targets only — reviewer spawns are never touched"
   invariant is load-bearing and stays. The join lives in the reviewer-lifecycle
   hook instead.
2. **No new hook registration.** Both edited scripts are already registered
   (`PreToolUse (Agent)` and `Stop`/`SubagentStop`). `hooks/hooks.json` is not
   touched, and there is no `SendMessage` matcher to add — that tool is not
   hookable in this harness.
3. **No stale-stamp sweeper and no stamp TTL.** An unconsumed stamp is inert: a
   stop is allowed whenever *any* stamp is satisfied, so a leaked stamp can never
   deadlock a reviewer that did its job. A TTL would reintroduce a clock into a
   control that is otherwise purely factual. Left as a documented property.
4. **No marker-format change.** Marker format v3 (0.27.0) is untouched. Step 2
   only *reads* the first line, reusing `task-gate.sh`'s prefix-only definition
   so all pre-existing markers stay valid.
5. **No enforcement H-check for the `Unit:` line on reviewer dispatches.** Step 5
   makes it a documented requirement and the hook fails open without it. A
   blocking check would make a missing line a hard dispatch failure for a
   mechanism whose whole point is to fail safe.
6. **No deletion or migration of existing `.claude/.last-review-clear` files.**
   They become inert once nothing reads them. Deleting operator-visible state
   inside a hook is out of proportion to the benefit.

## Residual gaps (must be recorded in ADR-0016, not papered over)

- **Concurrent reviews of two different units remain partially under-inclusive.**
  If A and B are genuinely in flight at once and B's marker lands first, A's stop
  is allowed by B's satisfied stamp. This is strictly narrower than today (today
  *any* marker anywhere satisfies *any* reviewer's stop, indefinitely); it is now
  bounded to units currently in flight, and only until their stamps are consumed.
  It is also a state the protocol's own one-unit-at-a-time invariant says should
  not exist.
- **Coverage narrows to `Unit:`-prefixed reviewer dispatches.** A reviewer
  dispatched without that first line, or resumed purely by `SendMessage` in
  agent-teams mode without a fresh `Agent` spawn, produces no stamp and its stop
  fails open. Mitigated by Step 5 (the line becomes mandatory prose) and by the
  fact that a teammate's *initial* spawn is an `Agent` call and therefore is
  stamped. Not mitigated for a teammate re-tasked onto a second unit by message
  alone.
- **Nothing here makes the control tamper-proof.** `rm -f` of a stamp via Bash
  remains possible, exactly as the file's existing "Honest limit" header says of
  the pending-review flags. The audit log is the deterrent; Step 4's protocol
  section is what makes reaching for it a stated violation rather than an
  ambiguity.

## Step 1 — reviewer-route-gate writes the per-unit review-join stamp

**Affected files**

- `hooks/scripts/reviewer-route-gate.sh` — a new block appended after the
  existing pending-flag check (`:47-65`), before the final `exit 0`. The two
  existing blocks (lead-programmer-may-not-spawn-reviewer, and the gated-dispatch
  block) are untouched.
- `tests/review-join.test.sh` — **new file**.
- `tests/validate.sh` — register the new suite alongside the existing
  `tests/stop-gate-blocked.test.sh` registration at `:242-247`.

**Behaviour**

When `persona_matches_gate "$target_type" reviewer` is true (the liberal matcher,
consistent with every other gate site in this file):

1. Read `.tool_input.prompt` via `jq -r '.tool_input.prompt // empty'`, guarded
   `2>/dev/null || true` (R4).
2. Take the **first non-blank line only** — never a whole-body scan, matching
   `dispatch-hygiene.sh:271-276`.
3. If it does not match
   `^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$`, write no
   stamp and fall through. Not an error, not a block.
4. Apply the `*/*|*..*` traversal guard to the captured id (R5).
5. If a **format-valid** `.pass` marker already exists for that unit, write no
   stamp: the unit already holds a verdict, so this dispatch is advisory by
   construction and owns no verdict to record. A `.fail` or `.blocked` marker does
   **not** exempt — a re-review after FAIL must produce a fresh verdict.
6. Otherwise write `.claude/.review-join.<unit-id>`, whose single line is
   `<UTC ISO-8601 timestamp> unit=<unit-id> prior=<none|fail|blocked> prior_mtime=<epoch|->`,
   and append `review-join=<unit-id>` to `.claude/review-audit.log`. `prior_mtime`
   is the epoch mtime of the existing `.fail`/`.blocked` marker if one is present,
   else `-`.
7. Writing a stamp **never blocks** — this hook's exit status is unchanged by the
   new block on every path.

Act only when `.claude/persona-config.json` exists (an adapted project), matching
the file's existing guard at `:34`/`:47`.

**Acceptance criteria**

```
bash -n hooks/scripts/reviewer-route-gate.sh                                   # exit 0
grep -qF 'review-join=' hooks/scripts/reviewer-route-gate.sh                   # exit 0
grep -qF 'tool_input.prompt' hooks/scripts/reviewer-route-gate.sh              # exit 0
grep -qF '*/*|*..*' hooks/scripts/reviewer-route-gate.sh                       # exit 0
bash tests/review-join.test.sh                                                 # exit 0
for n in route-gate-stamps-unit route-gate-no-unit-line-no-stamp \
         route-gate-existing-pass-no-stamp route-gate-existing-fail-stamps \
         route-gate-non-reviewer-target-no-stamp route-gate-never-blocks; do \
  grep -qF "$n" tests/review-join.test.sh || { echo "MISSING $n"; exit 1; }; \
done                                                                           # exit 0
grep -qF 'tests/review-join.test.sh' tests/validate.sh                         # exit 0
bash tests/validate.sh                                                         # exit 0
```

The six fixture names are mandatory literal strings, one per behaviour above.
`route-gate-never-blocks` must assert exit 0 across all five other fixtures'
payloads. Fixtures seed their own `mktemp -d` project dir and must never touch
this repo's tree or its reviewer-owned marker directory.

## Step 2 — stop-gate consumes the stamp instead of the global watermark

**Affected files**

- `hooks/scripts/stop-gate.sh` — replace `marker_since_last_clear()` (`:96-111`)
  and the reviewer-branch check that calls it (`:137-163`); update the
  file-header logic summary at `:35-44`. The `.blocked` early-exit (`:129-135`),
  the `persona_matches_grant` gate (`:127`), the foreign-namespace message
  (`:166-170`) and everything from `:173` down are untouched.
- `tests/stop-gate-blocked.test.sh` — rewrite cases (o)-(v) (`:295-445`) onto the
  new mechanism; cases (a)-(n) untouched.

**Behaviour**

Two new helpers replace the old one.

`marker_format_valid <path> <unit-id> <verb>` — mirrors `task-gate.sh`'s
`marker_valid()` (`:54-62`), so the two mechanisms finally share one definition
of "a marker was written": the file must exist, be **non-empty**, and its first
line must begin `<verb> <unit-id> ` (`PASS` for a `.pass`, `FAIL` for a `.fail`).
A zero-byte `touch` fails. Prefix-only, so every pre-existing marker still passes
and none is retroactively rejected.

`review_join_state` — enumerates `.claude/.review-join.*` and classifies each.

State table for the reviewer's `SubagentStop`, evaluated **after** the `.blocked`
early-exit and **before** the flag `rm -f`:

| # | Condition | Classification |
|---|-----------|----------------|
| 1 | no stamps exist at all | **allow**, log `marker-check=bootstrap` |
| 2 | stamp for U; a format-valid `U.pass` or `U.fail` exists; no `prior_mtime` recorded | satisfied |
| 3 | stamp for U; format-valid marker exists; marker mtime **greater than** recorded `prior_mtime` | satisfied |
| 4 | stamp for U; format-valid marker exists; marker mtime **not greater than** recorded `prior_mtime` | unsatisfied (re-review produced no new verdict) |
| 5 | stamp for U; marker exists but fails the format check (e.g. zero-byte) | unsatisfied |
| 6 | stamp for U; no marker at all | unsatisfied |
| 7 | stamp file unreadable, or its `unit=` field absent/malformed | satisfied (fail OPEN) and delete the stamp |

Then the governing rule:

- **At least one stamp satisfied** -> delete every satisfied stamp, log one
  `join-consumed=<unit-id>` line per deletion, clear the flags, log
  `cleared-by=reviewer`, `exit 0`.
- **Stamps exist and none is satisfied** -> do **not** clear the flags. Log
  `cleared-by=reviewer marker=MISSING unit=<unit-id>` (one line per unsatisfied
  stamp), print a stderr message naming those unit ids and giving the v3
  `printf`, `exit 2`.

Unsatisfied stamps are left in place on both paths — never deleted by the hook
except via case 7. `.claude/.last-review-clear` is no longer read or written;
`marker_since_last_clear` is deleted outright.

The stderr block message must additionally state, in one sentence, that the only
two legal responses are writing the genuine verdict or reporting and waiting, and
that touching a file's mtime to satisfy this check is a violation — the hook-side
echo of Step 4's protocol section, so the rule is present at the moment of the
block and not only in a document.

**Acceptance criteria**

```
bash -n hooks/scripts/stop-gate.sh                                             # exit 0
! grep -qF 'last-review-clear' hooks/scripts/stop-gate.sh                      # exit 0
! grep -qF 'marker_since_last_clear' hooks/scripts/stop-gate.sh                # exit 0
grep -qF 'marker_format_valid' hooks/scripts/stop-gate.sh                      # exit 0
grep -qF 'join-consumed=' hooks/scripts/stop-gate.sh                           # exit 0
grep -qF 'review-join.' hooks/scripts/stop-gate.sh                             # exit 0
grep -qF 'marker=MISSING unit=' hooks/scripts/stop-gate.sh                     # exit 0
bash tests/stop-gate-blocked.test.sh                                           # exit 0
for n in join-absent-fails-open join-unsatisfied-blocks join-satisfied-clears \
         join-zero-byte-marker-rejected join-fail-marker-satisfies \
         join-restale-marker-blocks join-concurrent-liveness \
         join-repeat-stop-allowed; do \
  grep -qF "$n" tests/stop-gate-blocked.test.sh || { echo "MISSING $n"; exit 1; }; \
done                                                                           # exit 0
bash tests/validate.sh                                                         # exit 0
```

The eight fixture names are mandatory literal strings. Two encode the bug this
plan exists to fix and must be written as *regression* tests, i.e. they must fail
against the pre-change hook:

- `join-concurrent-liveness` — two stamps (A and B) present; a marker exists for
  A only; the stop must exit 0, delete A's stamp, and leave B's standing.
- `join-repeat-stop-allowed` — a satisfied stop, then a second stop by the same
  reviewer with no new marker: the second must exit 0 (no stamps remain), which
  is precisely the case the global watermark blocked.

The existing mutation control (case (v)) must be rewritten to stub the new check
and must remain **binding** — with the check reverted, `join-unsatisfied-blocks`
and `join-zero-byte-marker-rejected` must both stop blocking. A mutation control
that passes against a mutant is a defect, not a pass (`222.fail`, defect 1).

## Step 3 — port Steps 1-2 to the Codex and Cursor adapters

**Affected files**

- `adapters/codex/hooks/scripts/reviewer-route-gate.sh`
- `adapters/cursor/hooks/scripts/reviewer-route-gate.sh`
- `adapters/codex/hooks/scripts/stop-gate.sh` — `:64-77`, `:131-158`
- `adapters/cursor/hooks/scripts/stop-gate.sh` — `:47-60`, `:91-117`
- `tests/adapter-stop-gate-parity.test.sh` — scenarios (f0)-(f4) and mutation
  control (g)

**Behaviour**

Faithful ports of Steps 1 and 2, preserving each port's documented port-specific
differences, its own dot-dir (`.codex` / `.cursor`, never `.claude`) and its own
payload shape. Two port-specific requirements are not optional:

- **Codex must route the new block through `block()`**, never a bare `exit 2`, so
  the check participates in the `.stop-loop-guard` escape like every other block
  site in that script (`222.fail`, defect 3 — already fixed once for the old
  check at `:147-153`; the replacement must not regress it). Claude and Cursor
  have no loop guard and keep a bare `exit 2`.
- **The codex block message's stale `v2` example is corrected to v3** as part of
  this rewrite. This is in scope because the message is being rewritten anyway to
  name the unit; it is not unrelated drift.

Scenario (f2) currently seeds a zero-byte `touch`ed marker and must be updated —
under the new format check that is case 5 (unsatisfied), and (f2) is a
*satisfied* case, so it needs a real v3 first line.

**Acceptance criteria**

```
bash -n adapters/codex/hooks/scripts/stop-gate.sh                              # exit 0
bash -n adapters/cursor/hooks/scripts/stop-gate.sh                             # exit 0
bash -n adapters/codex/hooks/scripts/reviewer-route-gate.sh                    # exit 0
bash -n adapters/cursor/hooks/scripts/reviewer-route-gate.sh                   # exit 0
[ "$(grep -rlF 'last-review-clear' hooks/scripts adapters | wc -l)" -eq 0 ]    # exit 0
[ "$(grep -rlF 'marker_format_valid' hooks/scripts adapters | wc -l)" -eq 3 ]  # exit 0
[ "$(grep -rlF 'review-join=' hooks/scripts adapters | wc -l)" -eq 3 ]         # exit 0
! grep -qF 'A v2 PASS or FAIL marker' adapters/codex/hooks/scripts/stop-gate.sh  # exit 0
grep -qF 'block "' adapters/codex/hooks/scripts/stop-gate.sh                   # exit 0
bash tests/adapter-stop-gate-parity.test.sh                                    # exit 0
bash tests/validate.sh                                                         # exit 0
```

Both counts are measured from the current tree, not assumed: three `stop-gate.sh`
copies carry `last-review-clear` today (`hooks/scripts` plus both adapters), and
those same three must carry `marker_format_valid` after. `review-join=` lands in
the three `reviewer-route-gate.sh` copies. Scenario (f)'s existing shape — all
cases driven across all three ports via each port's own payload shape and dot-dir
— is preserved, and (g) must remain binding on codex.

## Step 4 — protocol codifies "never self-authorize a bypass"

**Affected files**

- `templates/persona-protocol.md` — one **new** `## ` section, placed immediately
  after "WIP sentinel (mid-task handoff, not a bypass)" (`:61-74`), its nearest
  conceptual sibling. Also amend the "Pending-review flag" section (`:194-213`)
  to describe the review-join stamp in place of the retired watermark.
- `templates/persona-protocol-slim.md` — a condensed two-to-four sentence form of
  the same section (see Open Question 2).
- `bin/cli.js` — add the new header to `UNIVERSAL_PROTOCOL_CORE` (`:525-531`).
  **Must land in this same unit** (R2): without it `bin/cli.js` throws at load
  and nothing renders.
- `tests/adapter-protocol-parity.test.js` — add the new header to **both**
  `codexMap` (`:54-70`) and `cursorMap` (`:72-88`), each as
  `{ probe: 'Blocked by a gate you do not own' }`, not `deferred` (R3).
- `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc` — the corresponding prose, so both
  probes resolve.

**Behaviour**

The new section is headed exactly:

`## Blocked by a gate you do not own (never self-authorize a bypass)`

— no apostrophe, deliberately, so it stays greppable with `-F` from a
single-quoted shell string. It must state, at minimum:

1. **The rule.** When a hook or gate blocks you and the verdict it is asking for
   is not yours to give, the only two legal responses are (a) do the thing it is
   actually asking for, if that is genuinely your call, or (b) report and wait —
   a message to the orchestrator or team lead, or the WIP sentinel where that is
   the fitting mechanism for the blocking hook.
2. **Metadata-only workarounds count as bypasses.** Bumping a file's mtime,
   `touch`ing a file to satisfy an existence check, deleting or editing a gate's
   own state file, and re-running with a flag that disarms the check are each
   named, explicitly, as violations. Good intent, a correct underlying state, and
   full disclosure do not make one acceptable.
3. **A block whose premise is wrong is evidence of a defect in the gate**, and
   reporting it is the useful action — the mechanism only ever gets fixed if the
   block is surfaced instead of routed around.
4. **This is not the WIP sentinel and not the `defer:`/`skip:` escape hatch.**
   Those are *sanctioned* exits with their own audit trail, and using one is not
   a bypass. Cross-reference both by name so the boundary is unambiguous.

The section is written persona-agnostically (P4) — naming no persona
unconditionally, so it reads correctly in a project shipping no reviewer.

**Acceptance criteria**

```
grep -qF '## Blocked by a gate you do not own (never self-authorize a bypass)' templates/persona-protocol.md   # exit 0
grep -qF 'Blocked by a gate you do not own' templates/persona-protocol-slim.md                                 # exit 0
grep -qF 'Blocked by a gate you do not own' bin/cli.js                                                         # exit 0
[ "$(grep -cF 'Blocked by a gate you do not own' tests/adapter-protocol-parity.test.js)" -eq 2 ]                # exit 0
grep -qF 'Blocked by a gate you do not own' adapters/codex/agents-md-fragment.md                               # exit 0
grep -qF 'Blocked by a gate you do not own' adapters/cursor/rules/persona-protocol.mdc                          # exit 0
grep -qiF 'mtime' templates/persona-protocol.md                                                                # exit 0
grep -qF 'review-join' templates/persona-protocol.md                                                           # exit 0
! grep -qF 'clear-watermark' templates/persona-protocol.md                                                     # exit 0
node -e "require('./bin/cli.js')" 2>&1 | grep -q 'does not classify every canonical section' && exit 1 || exit 0  # exit 0
node tests/adapter-protocol-parity.test.js                                                                     # exit 0
bash tests/validate.sh                                                                                         # exit 0
```

Non-vacuity was measured on the current tree: `Blocked by a gate you do not own`,
`review-join` and `marker_format_valid` return **zero** matches across
`hooks/scripts/`, `templates/`, `bin/cli.js` and `agents/` today. The one
criterion that is *currently satisfied* is
`! grep -qF 'clear-watermark' templates/persona-protocol.md` — stated here
explicitly rather than presented as proof of work: it is a **regression guard**
against the retired term being introduced during the Pending-review-flag rewrite.

## Step 5 — reviewer and orchestrator carry the two new obligations

**Affected files**

- `agents/orchestrator.md` — the "Review routing — you are the single owner"
  section (`:104-131`), specifically the dispatch instruction at `:106-110`.
- `agents/reviewer.md` — near the marker-write bullets (`:90-125`).

**Behaviour**

`agents/orchestrator.md`: the existing "never omit the id" instruction becomes
specific — every reviewer dispatch opens with `Unit: <task-id>` as its **literal
first non-blank line**, the same shape a gated dispatch already uses (`:95-96`).
State the mechanical consequence plainly: `reviewer-route-gate.sh` reads that
line to write the review-join stamp, and a dispatch without it leaves the
marker-coupling check inert for that unit (fails open, does not error). Also
state the advisory case: a second, advisory reviewer dispatch on a unit that
already holds a `.pass` is deliberately not stamped, and is expected to end its
turn without writing any marker.

`agents/reviewer.md`: add the reviewer-specific application of Step 4's rule — if
a stop-gate block demands a marker the reviewer believes it already wrote, or
demands a verdict for a unit it does not own (an advisory pass), it must not
touch, re-`touch`, mtime-bump or overwrite any marker, and must not delete a
stamp. It reports the block and its reasoning to the orchestrator and waits.
Reference the new protocol section by name rather than restating it in full.

**Acceptance criteria**

```
grep -qF 'literal first non-blank line' agents/orchestrator.md              # exit 0
grep -qF 'review-join' agents/orchestrator.md                              # exit 0
grep -qF 'Blocked by a gate you do not own' agents/reviewer.md             # exit 0
grep -qiF 'mtime' agents/reviewer.md                                       # exit 0
[ "$(grep -cF 'Unit: <task-id>' agents/orchestrator.md)" -ge 2 ]           # exit 0
bash tests/validate.sh                                                     # exit 0
```

The `-ge 2` count is measured: `agents/orchestrator.md` carries exactly **one**
`Unit: <task-id>` occurrence today (the gated-dispatch rule at `:96`), so the
criterion fails on the current tree and passes only once the reviewer-dispatch
instruction adds its own.

## Step 6 — regenerate the persona mirrors

**Affected files**

- The six full-tier mirrors — `spec-master`, `orchestrator`,
  `milestone-auditor`, `task-master`, `lead-programmer`, `reviewer` — plus the
  three slim-tier mirrors (`explorer`, `researcher`, `scribe`), which change here
  because Step 4 amends the slim template too. **Never hand-edited**
  (constitution P2).
- `.claude/persona-config.json`, `.claude/persona-protocol.md`,
  `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md` — incidentally
  rewritten/re-stamped by the render. Review their diffs; do not revert
  selectively, and commit **all** of them (`224.fail`: a partially-committed
  render leaves a stale `pluginVersion` and makes the next `--update` report
  divergence).

**Behaviour**

From the repo root, run `node bin/cli.js --update --check`. This is a forced
render that bypasses the version-match fast path; a plain `--update` on a clean
tree writes nothing, so "run it and diff" would prove nothing. Then inspect
`git status --short` and confirm the only paths touched are the nine mirrors and
the four stamped files above. Any `.cursor/`, `.codex/`, `CLAUDE.md` or
`.gitignore` change is a defect — stop and report (R7). Assert on file
**content**, never on mtime.

**Acceptance criteria**

```
[ "$(grep -rlF 'Blocked by a gate you do not own' .claude/agents/ | wc -l)" -eq 9 ]   # exit 0
git status --porcelain -- .cursor .codex CLAUDE.md .gitignore | wc -l                 # outputs 0
node bin/cli.js --update                                                              # exit 0
node tests/cli-backfill.test.js                                                        # exit 0
bash tests/validate.sh                                                                 # exit 0
```

The count `9` is measured, not assumed: nine mirrors currently carry a protocol
block (six full-tier, three slim-tier), and Step 4 puts the new section in both
templates, so all nine must carry it. If Open Question 2 is answered "canonical
template only", this count becomes `6` and the slim-template edit drops out of
Step 4 — the only place that answer changes anything. The
`node bin/cli.js --update` criterion is the `224.fail` guard: it exits non-zero
while any rendered file remains uncommitted or any hash is stale, so it fails
exactly in the partially-committed state that defect describes.

## Step 7 — institutional record

**Affected files**

- `docs/adr/0016-per-unit-review-join.md` — **new**. `0015` is the highest
  present; the `0007` hole is **not** free (it is linked from `CONTEXT.md`) and
  must never be backfilled.
- `CONTEXT.md` — the **Clear-watermark** glossary entry (`:95-102`) and the
  dispatch-hygiene narrative reference (`:67-70`).
- `.claude/wiki/modules/hooks.md` — the "stop-gate.sh: marker coupling via
  clear-watermark (issue #153)" section (`:208-256`), including its now-resolved
  "Known issues" bullet for #226, and the H3 narrative at `:180-191`, which cites
  the watermark as the mechanism closing #153's gap.

**ADR-0016 must record**, at minimum: the review-join stamp's path, content and
lifecycle; the reasoning that per-agent keying is *provably* wrong (it destroys
first-stop coverage) and that Directions A and B are one design rather than two;
the seven-branch state table and the governing "allow iff no stamps, or at least
one satisfied" rule with its fail directions; the unification of the two "a
marker was written" definitions onto `task-gate.sh`'s prefix-only check; all
three **Residual gaps** verbatim; the six Deliberate non-changes; and the
per-location (not centralized) adapter decision with its reason.

The **Clear-watermark** glossary entry is *retired and rewritten*, not
redefined — the term keeps its historical meaning and the entry says it was
replaced by the review-join stamp in 0.28.0. `225.fail` records what redefining a
cited term in place costs, and what documenting a mechanism from the spec draft
rather than from the shipped code costs: write these entries against the landed
scripts.

**Acceptance criteria**

```
test -f docs/adr/0016-per-unit-review-join.md                              # exit 0
! ls docs/adr/0007-* >/dev/null 2>&1                                       # exit 0 (hole preserved)
grep -qF 'review-join' docs/adr/0016-per-unit-review-join.md               # exit 0
grep -qF 'Residual gaps' docs/adr/0016-per-unit-review-join.md             # exit 0
grep -qF 'review-join' CONTEXT.md                                          # exit 0
grep -qF 'ADR-0016' CONTEXT.md                                             # exit 0
grep -qF 'review-join' .claude/wiki/modules/hooks.md                       # exit 0
! grep -qF 'Issue #226' .claude/wiki/modules/hooks.md                      # exit 0
grep -qiF 'clear-watermark' CONTEXT.md                                     # exit 0 (retired, not deleted)
bash tests/validate.sh                                                     # exit 0
```

The `! grep -qF 'Issue #226'` criterion asserts the wiki's "Known issues" bullet
is *removed* once the issue is closed — it is present today
(`.claude/wiki/modules/hooks.md:250`), so the criterion fails on the current
tree. The final criterion is case-insensitive on purpose: `CONTEXT.md:95`
capitalizes the term, and a case-sensitive criterion on this exact entry is what
`225.fail` recorded.

## Step 8 — version bump and CHANGELOG

**Affected files**

- `.claude-plugin/plugin.json` — `version` -> `0.28.0` (currently `0.27.0`).
- `package.json` — `version` -> `0.28.0` (`tests/validate.sh` cross-checks the two).
- `CHANGELOG.md` — new `## [0.28.0] - 2026-08-07` section.

Minor bump, not patch: a hook's blocking behaviour changes, an operator-visible
state file is replaced, and a new canonical protocol section reaches every
persona.

The entry must lead with the two operator-visible changes — the clear-watermark
is replaced by the per-unit review-join stamp, and a bare zero-byte marker no
longer satisfies the check — before any internal detail, and must not attribute
to this release any change absent from its diff (`224.fail`, defects 3 and 4).

**Acceptance criteria**

```
python3 -c "import json;assert json.load(open('.claude-plugin/plugin.json'))['version']=='0.28.0'"  # exit 0
python3 -c "import json;assert json.load(open('package.json'))['version']=='0.28.0'"                # exit 0
grep -qF '## [0.28.0] - 2026-08-07' CHANGELOG.md                                                    # exit 0
grep -qF 'review-join' CHANGELOG.md                                                                 # exit 0
grep -qF '#226' CHANGELOG.md                                                                        # exit 0
bash tests/validate.sh                                                                              # exit 0
```

## Open Questions

Both carry a recommended default. **The plan proceeds on those defaults** — a
different answer amends one step; neither blocks Steps 1-3.

1. **Should the `Unit: <id>` first line on reviewer dispatches be mechanically
   enforced rather than documented?**
   *Recommended default, assumed by this plan: documented only (Deliberate
   non-change 5).* The hook fails open without it, so a missing line silently
   narrows coverage rather than erroring — the safe direction, but also an
   invisible one. Enforcing it would mean a new H-check in `dispatch-hygiene.sh`,
   which requires relaxing that file's "reviewer spawns are never touched"
   invariant. If the answer is "enforce it", that is one additional unit on
   `dispatch-hygiene.sh` plus its fixtures; it does not change Steps 1-3.

2. **Does the new protocol section belong in the slim tier as well as the
   canonical template?**
   *Recommended default, assumed by this plan: yes.* Slim-tier personas
   (`explorer`, `researcher`, `scribe`) are not gated by the review mechanism,
   but `protected-paths.sh` and `reviewed-path-gate.sh` do block them, and the
   rule is about *any* gate whose verdict you do not own. The slim tier carries
   no matrix and no parity-map cost, so the price is a few lines. If the answer
   is "canonical only", drop the slim edit from Step 4 and change Step 6's mirror
   count from `9` to `6`; nothing else moves.

## Self-check

- CHK1: Is the join artifact fully specified — path, content, who writes it, who
  deletes it, and on which transitions? — PASS (Step 1 item 6 gives the path and
  single-line content; Step 2's table and governing rule give every consumption
  transition; Deliberate non-change 3 states what is *not* cleaned up and why).
- CHK2: Do Steps 1 and 2 agree on the stamp's content fields? — FAIL
  (conflicting: an earlier draft had Step 1 writing only a timestamp while
  Step 2's table branched on `prior_mtime`) — revised in place; Step 1 item 6 now
  writes `unit=`, `prior=` and `prior_mtime=`, and Step 2's cases 2-4 consume
  exactly those.
- CHK3: Is a fail direction stated for every branch, including the unverifiable
  ones? — PASS (Step 2's seven-row table plus the governing rule; case 7 and
  row 1 are the two fail-open branches, both named as such in Clarifications
  item 4).
- CHK4: Does the plan explain why the two rejected fix directions were rejected,
  in terms a later reader can check? — PASS (Context, "Why the issue's three
  suggested directions collapse to one"; the per-agent argument is stated as a
  falsifiable claim about first-stop coverage, and Step 7 requires ADR-0016 to
  carry it).
- CHK5: Does the plan state what the fix does **not** achieve? — PASS ("Residual
  gaps", three items, each required verbatim in ADR-0016 by Step 7).
- CHK6: Is the adapter question from the issue's scope note answered with
  evidence, and does the plan say per-location or centralized? — PASS (Context
  cites both ports with line ranges; Clarifications item 5 and Step 3 both say
  per-location, with `bin/cli.js`'s verbatim-copy behaviour as the reason).
- CHK7: Do Steps 2 and 3 agree on which files must and must not contain the
  retired watermark token? — PASS (Step 2 negates it in
  `hooks/scripts/stop-gate.sh`; Step 3's recursive count over `hooks/scripts` and
  `adapters` is 0, which subsumes it, so the two criteria cannot disagree).
- CHK8: Is the cost of adding a canonical protocol section stated everywhere a
  unit could trip over it? — PASS (R2/R3, Clarifications item 7, Step 4's
  affected-files list naming `bin/cli.js` and both parity maps, and Step 4's
  explicit "must land in this same unit").
- CHK9: Does the plan define the process fix concretely enough that a reviewer
  can tell whether it was written, rather than "add some prose"? — FAIL
  (ambiguous: the first draft said only "codify report-and-wait") — revised in
  place; Step 4 now enumerates four required content points and pins the exact
  heading string, which the criteria grep for verbatim.
- CHK10: Is every acceptance criterion non-vacuous — does each fail on the
  pre-change tree? — PASS, and *measured* rather than reasoned: `review-join`,
  `join-consumed`, `marker_format_valid` and `Blocked by a gate you do not own`
  return zero matches across `hooks/scripts/`, `templates/`, `bin/cli.js` and
  `agents/` today; `grep -cF 'Unit: <task-id>' agents/orchestrator.md` is exactly
  `1` today, so Step 5's `-ge 2` fails now; `Issue #226` is present in the wiki
  today, so Step 7's negated criterion fails now; all three affected suites exit
  0 today, so any regression is attributable. The single currently-satisfied
  criterion is Step 4's `! grep -qF 'clear-watermark'
  templates/persona-protocol.md`, and that step says so explicitly rather than
  presenting it as proof of work.
- CHK11: Does the plan say which steps must not be tagged `haiku`, with the
  evidence behind it? — FAIL (missing: the first draft asserted a `.fail` count
  from a filtered sample) — revised in place, then corrected a second time when
  a re-measure during authoring showed the directory had grown from 24 to **25**
  `.fail` files. Filtering by this plan's surfaces gives eleven on the
  stop-gate/watermark surface and eleven on the `bin/cli.js`/mirrors surface
  (the first pattern used, `agents/`, over-matched and had to be narrowed to
  `.claude/agents`). R1
  now carries the enumeration and the explicit "Steps 2, 3, 4 and 6 must NOT be
  tagged `haiku`" directive.
- CHK12: Do the two mutation controls remain binding after the fixtures are
  rewritten, and does the plan say so? — PASS (Step 2 requires case (v) to be
  rewritten and to stay binding against a reverted mutant, naming the two
  fixtures that must stop blocking; Step 3 requires the same of (g) on codex,
  citing `222.fail` defect 1 as precedent that a non-binding control is a defect).
- CHK13: Is the new test file's *registration* covered, given that
  `tests/validate.sh` uses explicit registration rather than discovery? — FAIL
  (missing: an earlier draft asserted only `bash tests/review-join.test.sh`) —
  revised in place; Step 1 lists `tests/validate.sh` as an affected file and
  carries `grep -qF 'tests/review-join.test.sh' tests/validate.sh` as its own
  criterion, and Clarifications item 9 records why.
- CHK14: Do Steps 4 and 6 agree on how many mirrors carry the new section? —
  PASS (Step 4 edits both templates; Step 6 asserts `9`, states the measurement
  behind it, and names Open Question 2 as the single input that would change it
  to `6` — so the two cannot drift silently).
- CHK15: Is the ADR number justified against the existing numbering, including
  the `0007` hole? — PASS (Step 7 states `0015` is the highest present and that
  `0007` must never be backfilled; a criterion asserts the hole survives).
- CHK16: Does the plan define a single acceptance signal for the change as a
  whole? — PASS (`bash tests/validate.sh` exits 0, carried on every step;
  recorded in Clarifications item 9).

Three FAILs (CHK2, CHK9, CHK11) plus one found by running rather than reading
(CHK13), all resolved in the single permitted revision pass and re-checked. No
unresolved failure remains, so nothing here was converted to an Open Question;
Open Questions 1 and 2 are pre-existing scope decisions, not Self-check
escalations.

## Scribe update hint

After Step 7 lands: `CONTEXT.md`'s **Clear-watermark** glossary entry is retired
in favour of a **review-join stamp** entry, and the dispatch-hygiene narrative at
`:67-70` re-points at the new mechanism; `.claude/wiki/modules/hooks.md`'s
clear-watermark section is rewritten around the seven-branch state table and its
"Known issues" bullet for #226 is removed; `.claude/wiki/changelog.md` gains a
v0.28.0 line. ADR-0016 is new and should be linked from `CONTEXT.md` alongside
the existing ADR pointers, and from the wiki wherever ADR-0015 is referenced. The
wiki's H3 narrative at `:180-191` cites the clear-watermark as what closed #153's
gap — that sentence needs re-pointing too. No `docs/dependencies.md` change is
expected; no dependency is added. Issue #226 is closed by the `scribe` per its
issue-closing duty once Step 8 lands.

## Handoff

Eight dispatchable units, so this is the **standard path**: `task-master` slices
these steps with `to-tickets`, assigns each unit's `Suggested model` tag (heeding
R1's `haiku` exclusions for Steps 2, 3, 4 and 6), states the retrieval contract,
and writes the per-unit dispatch prompts. `spec-master` emits no dispatch
contract for this plan.
