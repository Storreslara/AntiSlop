# Reviewer report style — action-first prose, structure wins

Status: FINAL (pending the two Open Questions below)
Date: 2026-08-13
Author: spec-master
Task-id: `reviewer-report-style`

## Goal

Adopt a terser, action-first communication style for the **free-form prose the
`reviewer` persona writes into its own verdict message and non-blocking notes**,
inspired by the MIT-licensed `i-have-adhd` Claude Code skill — without altering
any verdict line, marker format, citation string, advisory-section ordering, or
the terminal `STATUS:` line.

This is a **guidance-only** change in this repo's canonical sense (CONTEXT.md:
"improves documentation, protocol prose, or instruction without altering any
shipped code or hook enforcement logic"). No hook, gate, or validator changes
behaviour.

## Context

**The single most important finding: most of what the source skill asks for is
already shipped, and the honest delta is small.**

`agents/reviewer.md`'s "Verdict — terse, verdict-first, advisory sections
(plural)" bullet (lines 81-97) already mandates: the final message is ONLY the
verdict; PASS is one line; "no restated context, no summary of what you read, no
praise"; "All of your investigation happens in tool calls, not in the final
message." The shared protocol's `## Answer shape` section
(`templates/persona-protocol.md:36-41`) already mandates "lead with the direct
answer, then compact supporting facts" for *every* persona.

So the source skill's rules 1 (lead with the answer), 5 (no preamble/recap/
pleasantries) are **already satisfied**, and rules 3 (restate progress each
turn), 4 (time estimates) and 7 (session toggle) **do not transfer** to a
one-shot structured artifact. Manufacturing a large diff here would violate the
"no forced changes" discipline.

Three things genuinely transfer and are currently absent:

| Source rule | Transfers as | Current state |
|---|---|---|
| Number multi-step work | Number the FAIL defect list so a fix pass and a re-review can cite items by number | absent — the file says "a bare list" |
| Matter-of-fact on errors; no apologising/hedging | State findings as facts with evidence; a finding you cannot state as fact is not a FAIL ground | absent — nothing forbids hedging |
| The skill's five override cases | Collapse to exactly one that matters here: **a required structural format always wins over terseness** | absent — and this is the load-bearing safety clause |

The source skill's "cap lists at 5 items" is **rejected outright**: the shared
protocol requires the `.fail` record to reproduce the verdict's defect list
*verbatim*, and the non-blocking notes persist into the `.pass` marker. A cap
would silently destroy audit records.

### Load-bearing vs free-form catalog (the user's item 1)

**Load-bearing — must survive byte-identical.** Verified against the hooks by
the `explorer` (graph-derived; no hook parses the reviewer's returned *message
text* at all — every consumer reads marker-file first lines and review-join
stamp fields):

- Every marker's required first line: `.pass` (v3 `printf`), `.fail`,
  `.blocked`, `.escalated`, `.directed`. Consumed by `task-gate.sh`'s
  `marker_valid()` (line-1 prefix + non-emptiness) and `dispatch-hygiene.sh`'s
  H3 (`commit:` field).
- The `constitution vX.Y.Z / <principle name>` citation string and the
  defect-bullet shape that carries it.
- `file:line` anchors on every defect and every `ubiquitous-language` finding.
- Verdict line first; advisory sections after it in the fixed order
  `roast-work` → `ubiquitous-language`; never interleaved, never preceding.
- The terminal `STATUS: complete` / `STATUS: incomplete — <reason>` line, last.
- The four-verdict precedence, the full FAIL defect list, the ESCALATE packet
  body fields, the `human:` attestation, and DECISION transcription verbatim.

**Free-form — style-eligible, no downstream consumer.** The prose *inside* a
defect bullet after its `file:line` anchor; the prose of the non-blocking notes;
the INSUFFICIENT-CONTEXT description of what is missing; any rationale the
reviewer adds.

### Scope (the user's item 3)

`agents/reviewer.md` alone, plus its mechanically-regenerated mirror. Not the
shared protocol: `## Answer shape` already carries the generic action-first rule
for all nine personas, and editing `templates/persona-protocol.md` fans out to
the slim variant, two adapter protocol ports, and
`tests/adapter-protocol-parity.test.js`'s `canonicalHeaders()` drift guard —
disproportionate blast radius for a refinement the user scoped to one persona.
Noted as an available future option; **not acted on**.

## Risks and dependencies

- **R1 — Mirror regeneration requires the version bump FIRST.** `bin/cli.js:1091`
  takes an "already current" fast path when `config.pluginVersion === version`,
  and `needsRender` (`bin/cli.js:1063-1089`) only inspects the *destination's*
  stamp and existence — never the *source's* content — for stamped specs. So
  editing `agents/reviewer.md` and running `--update` at an unchanged version
  regenerates nothing, silently. Confirmed by CHANGELOG 0.31.25, which hit
  exactly this. **Bump `.claude-plugin/plugin.json` before running `--update`.**
- **R2 — Never hand-edit the mirror** (Constitution P2). `.claude/agents/reviewer.md`
  is produced only by `node bin/cli.js --update`.
- **R3 — THIS WORKTREE CARRIES ANOTHER UNIT'S UNCOMMITTED WORK. Do not start
  until it is resolved.** Measured 2026-08-13 while authoring: `tests/validate.sh`
  first reported `FAIL .claude/hooks/scripts diverged from hooks/scripts` on two
  consecutive runs, then went green on the next two. The cause is **not** a
  self-healing merge gate (my first diagnosis, now withdrawn) — it is a
  concurrent, in-flight implementation of
  `docs/plans/2026-08-12-reviewer-dispatch-caller-allowlist.md` living
  uncommitted in this same working tree:
  - `hooks/scripts/reviewer-route-gate.sh` — modified (caller allowlist added)
  - `.claude/hooks/scripts/reviewer-route-gate.sh` — modified (mirror synced)
  - `tests/validate.sh` — modified (registers a new suite)
  - `tests/reviewer-route-gate-caller.test.sh` — **untracked**, created 17:45
  - `.claude/persona-config.json` — one `fileHashes` entry rewritten

  The parity check flapped because that unit edited the canonical hook first and
  ran `node bin/cli.js --update` afterwards, between my runs. Consequences for
  this unit: (a) any `bash tests/validate.sh` reading is measuring **both**
  units, so a green baseline cannot be attributed to this one; (b) this unit
  also runs `--update`, which will pick up that unit's changes into its own
  commit; (c) the reviewer's v3 marker precondition (`git diff --quiet HEAD`
  exits 0) is **currently unsatisfiable**. Land, stash, or revert the in-flight
  work before dispatching this unit — do not interleave them.
- **R7 — Do not hard-code the target version.** `0.31.29` is written below as
  the *expected* next patch, but the in-flight unit in R3 also requires a P3
  version bump and may claim it first. Re-derive the bump target at execution
  time by reading `.claude-plugin/plugin.json` and incrementing the patch, the
  same discipline this repo uses for ADR numbers (increment at execution time,
  never backfill — sibling specs collide). C1 is written to tolerate this: it
  asserts only that the version *changed* and that a matching CHANGELOG heading
  exists, never a specific number.
- **R4 — `grep` line-wrap trap.** `agents/reviewer.md` is wrapped prose; the
  phrase "then a bare list of specific reproducible defects" spans two physical
  lines and a naive `grep` returns 0. Every criterion below uses the line-join
  idiom. Note the joined `grep -c` is a **boolean** (0 or 1), not a tally.
- **R5 — Reviewer tier is forced to opus.** `tests/reviewer-tier.test.sh` cases
  (aq)/(ar) assert that any diff touching `agents/reviewer.md` or
  `.claude/agents/reviewer.md` resolves the reviewer to **opus**. This is a
  measured mechanical fact, not a tag assigned here.
- **R6 — Prior FAIL history.** All 22 `.fail` records under `.claude/reviewed/`
  were enumerated; **none** names a reviewer-prose or reviewer-style unit. No
  prior defect history constrains this scope. Adjacent-but-distinct precedent:
  `gh-286-docs` and `gh138` FAILed because documentation units were gated on
  existence greps while prose *accuracy* was the deliverable — which is why the
  criteria below are claim-anchored (negative + positive + survival pins) rather
  than existence-only.
- **D1 — No dependency on the source skill.** Already researched; the repo will
  not fetch it. MIT attribution is a courtesy question, not an obligation (see
  Open Question 1) — this adapts rules into original prose for a different
  purpose, not a "substantial portion" of the licensed work.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-13 Functional scope & success criteria: Q How much of the source
  skill's 10 rules is actually missing from `agents/reviewer.md` today, and
  where does the new prose go? → A (self-resolved): rules 1 and 5 are already
  shipped (lines 81-97 plus the protocol's `## Answer shape`); rules 3, 4 and 7
  do not transfer to a one-shot artifact; the real delta is numbering,
  no-hedging, and a format-precedence clause. Placed as one new bullet
  immediately after the existing Verdict bullet, so the two output-shape rules
  read together and cannot drift apart.
- 2026-08-13 User interaction flow: Q Who actually reads the verdict message —
  a human, or the orchestrator that routes defects? → A (self-resolved): both,
  and no gate parses it (explorer-confirmed: every consumer reads marker-file
  first lines, never message text). So optimising the prose for a human reader
  carries zero machine risk, and numbered defects additionally help the
  orchestrator route "fix items 2 and 4" back to `lead-programmer`.
- 2026-08-13 Non-functional attributes: Q What is the safety attribute at risk
  from a brevity rule? → A (self-resolved): audit-trail completeness. The
  `.fail` record reproduces the defect list verbatim and the `.pass` marker
  carries the notes, so any cap or truncation destroys durable records. Answered
  by making the precedence clause explicit rather than implied.
- 2026-08-13 Edge cases / failure handling: Q Does "no apologising, no hedging"
  suppress the reviewer's disclosure of its own earlier misses? → A
  (self-resolved): no, and the new prose says so in the same breath. The user's
  own standing feedback values explicit self-reporting of reviewer errors for
  audit trust; the rule removes the apology, never the disclosure.
- 2026-08-13 Technical constraints & tradeoffs: Q Do the Cursor and Codex
  reviewer ports need updating too? → A: they each carry the exact sentence
  being edited but are ungated (measured: `tests/adapter-protocol-parity.test.js`
  checks *protocol* sections against `templates/persona-protocol.md`, never
  persona body prose) and deliberately abridged (84 and 94 lines vs 253).
  Escalated to Open Question 2 rather than guessed.
- 2026-08-13 Terminology consistency: Q Does the request's vocabulary drift from
  `CONTEXT.md`? → A (self-resolved): three `ubiquitous-language` (prose mode)
  findings, all advisory. **Lens 1** — none. **Lens 2** — the request's word
  "report" is a new synonym for what the corpus calls the reviewer's *final
  message* / *verdict*; this plan and the new prose use "verdict message" and
  "non-blocking notes" instead, and avoid coining "report" as a noun for the
  artifact. **Lens 3** — "action-first prose" is a load-bearing new term with no
  glossary entry; suggested to `scribe` in the Scribe update hint below. The
  change itself is correctly described by the existing canonical term
  **guidance-only**, which this plan uses.
- 2026-08-13 Completion / acceptance signals: Q How is a *style guideline* — a
  prose deliverable — machine-checked at all? → A (self-resolved): it cannot be
  fully. Gated instead on a three-part claim-anchored set: positive anchors that
  the new clauses exist, a negative/positive pair proving the "bare"→"numbered"
  edit landed, and **survival pins** proving every load-bearing string is still
  present (per the rule that a deletion check must never be able to destroy the
  rule it protects). Whether the prose is *good* stays reviewer judgment, and
  the plan says so plainly rather than inventing a gate that looks mechanical.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every criterion below was executed
  against the working tree at authoring time and its current value recorded.
  Doing so caught two authoring defects: the line-wrap trap (R4) and a
  `STATUS: complete` pin wrongly placed on the source file, which carries no
  protocol block (it belongs on the mirror only).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  mirror is regenerated by `node bin/cli.js --update`, never hand-edited (R2).
- P3 "Version-stamp discipline": satisfied — the version bump and CHANGELOG
  entry are ordered edits 2 and 3 of the unit, and gated by C1/C2.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the change is
  confined to `agents/reviewer.md`; a project that did not select the reviewer
  never renders the file, and no shared prose gains a reviewer reference.
- P5 "`tests/validate.sh` is the merge gate": satisfied — C9 runs it. **No clean
  baseline could be established**: every reading on 2026-08-13 was taken over a
  tree carrying another unit's uncommitted work (R3), so the green runs cannot
  be attributed to this unit's starting state. Re-measure after R3 is resolved,
  before dispatch.

## Step 1 — the whole change (single unit)

**Affected files**

- `agents/reviewer.md` — two edits (below).
- `.claude-plugin/plugin.json` — version `0.31.28` → `0.31.29`.
- `CHANGELOG.md` — new `## [0.31.29] - 2026-08-13` entry.
- `.claude/agents/reviewer.md` — **regenerated, never hand-edited**.
- `.claude/persona-config.json` — `pluginVersion` + `fileHashes`, rewritten by
  `--update`.
- `.claude/hooks/scripts/**` — may be touched mechanically by `--update` as
  unavoidable collateral (see R3); acceptable, but no hand edits.

**Edit A** — in the existing Verdict bullet, change `then a bare list of` to
`then a numbered list of`, so the two bullets cannot be read as contradicting.

**Edit B** — insert one new bullet immediately after the Verdict bullet (after
the line ending `...is never obscured.`):

> - **Report style — action-first prose, required structure always wins**: this
>   governs only the free-form text you control — each defect's explanation, the
>   non-blocking notes, and the INSUFFICIENT-CONTEXT description of what is
>   missing. Lead each with what the reader must DO, then the evidence that
>   justifies it; the narrative of how you found it belongs in your tool calls,
>   not here. State findings as facts with evidence attached: no hedging ("might
>   be", "possibly", "I think"), no apologising, no softening. If you cannot
>   state a defect as a fact, it is not a FAIL ground — put it in the
>   non-blocking notes, or return INSUFFICIENT-CONTEXT. Owning a miss from your
>   own earlier pass is a fact like any other: state it plainly and keep it, in
>   the verdict and in the marker. Removing the apology never removes the
>   disclosure. Number the FAIL defect list so a fix pass, a `.fail` record and
>   a later re-review can cite items by number. A PASS verdict stays exactly one
>   line and gains no "next step" — routing is the orchestrator's call, not
>   yours. **No brevity rule may shorten, reorder, or drop anything this file
>   already requires**: the verdict line and its position, the complete defect
>   list (the `.fail` record reproduces it verbatim), the
>   `constitution vX.Y.Z / <principle name>` citation, `file:line` anchors,
>   every marker's required first line, the advisory sections and their fixed
>   order, and the terminal `STATUS:` line all survive intact. Where brevity and
>   completeness conflict, completeness wins, and an item cap never applies to a
>   list this file requires to be complete.

**Ordered edits** — the order is load-bearing (R1): Edit A and B → bump
`plugin.json` → CHANGELOG entry → `node bin/cli.js --update` → `bash
tests/validate.sh` → commit.

### Acceptance criteria

Run from the repo root, on the committed tree. Every value below was measured
on 2026-08-13 before authoring; the "now" column is the pre-change reading, so
each criterion is provably RED (or a survival pin at its expected value).

```sh
J() { tr '\n' ' ' < "$1" | tr -s ' '; }   # joined grep -c is a BOOLEAN (0/1)

# C1  version bumped and CHANGELOG entry matches it        (now: 0.31.28, no entry)
V=$(python3 -c "import json;print(json.load(open('.claude-plugin/plugin.json'))['version'])")
test "$V" != "0.31.28" && grep -q "^## \[$V\] - " CHANGELOG.md

# C2  the precedence clause exists                          (now: 0)
test "$(J agents/reviewer.md | grep -c 'required structure always wins')" = 1
test "$(J agents/reviewer.md | grep -c 'completeness wins')" = 1

# C3  the no-hedging clause exists                          (now: 0)
test "$(J agents/reviewer.md | grep -c 'no hedging')" = 1

# C4  self-disclosure is preserved, not suppressed          (now: 0)
test "$(J agents/reviewer.md | grep -c 'Removing the apology never removes the disclosure')" = 1

# C5  the numbering clause exists                           (now: 0)
test "$(J agents/reviewer.md | grep -c 'Number the FAIL defect list')" = 1

# C6  Edit A landed: negative + positive pair               (now: bare=1, numbered=0)
test "$(J agents/reviewer.md | grep -c 'then a bare list of specific reproducible defects')" = 0
test "$(J agents/reviewer.md | grep -c 'then a numbered list of specific reproducible defects')" = 1

# C7  SURVIVAL PINS — load-bearing text must still be there (now: 1 each)
test "$(J agents/reviewer.md | grep -c 'All of your investigation happens in tool calls, not in the final message.')" = 1
test "$(J agents/reviewer.md | grep -c 'never precede or interleave with the verdict')" = 1
test "$(J agents/reviewer.md | grep -c 'constitution vX.Y.Z / <principle name>')" = 1
test "$(grep -c "printf 'PASS <task-id> %s commit: %s criteria:" agents/reviewer.md)" = 1

# C8  mirror regenerated by --update, stamp bumped, protocol intact
#     NOTE: the stamp line reads GREEN today only because $V is read from the
#     very file C1 bumps. It is non-vacuous *in conjunction with C1*: once the
#     version changes, it stays RED until `--update` re-renders the mirror.
test "$(grep -c "antislop v$V | source: agents/reviewer.md" .claude/agents/reviewer.md)" = 1
test "$(J .claude/agents/reviewer.md | grep -c 'required structure always wins')" = 1
test "$(J .claude/agents/reviewer.md | grep -c 'then a numbered list of specific reproducible defects')" = 1
test "$(J .claude/agents/reviewer.md | grep -c 'STATUS: complete')" = 1   # protocol block intact

# C9  merge gate green (Constitution P5). See R3: re-run once before believing
#     a `.claude/hooks/scripts diverged` line, and re-check the tree is clean.
bash tests/validate.sh

# C10 SCOPE PIN — the adapter ports were NOT touched (Open Question 2 default)
test "$(J adapters/cursor/agents/reviewer.md | grep -c 'bare list of specific reproducible defects')" = 1
test "$(J adapters/codex/agents/reviewer.toml | grep -c 'bare list of specific reproducible defects')" = 1

# C11 no residual drift: exit code AND a post-run tree assertion (both needed —
#     `--update --check` is not a dry run and self-heals silently).
#     The porcelain check is SCOPED to the paths --update manages. A bare
#     `git status --porcelain` is wrong here: it counts untracked files
#     (agent-memory writes, plan docs) and would redden this criterion for
#     reasons that have nothing to do with the unit — measured 19 vs 0 on
#     2026-08-13.
node bin/cli.js --update && test -z "$(git status --porcelain -- \
  agents .claude/agents .claude/persona-config.json .claude/hooks/scripts)"
```

**Not machine-checkable, stated plainly rather than faked:** whether the new
prose *reads* as terse and action-first, and whether it contradicts any other
instruction in the file, is reviewer judgment. C2-C7 prove the clauses exist and
that nothing load-bearing was deleted; they cannot prove the prose is good.

## Open Questions

1. **Attribution for the adapted source skill.** The repo credits adapted
   third-party material inline (`skills/pathfinder` "adapted from
   mattpocock/skills `wayfinder`"; `skills/fail-triage` "Derived from
   mattpocock/skills `triage`"), and vendored material in
   `skills/THIRD-PARTY-NOTICES.md`. This change vendors nothing — it re-expresses
   three rules in original prose for a different purpose, which is not a
   "substantial portion" under MIT, so attribution is courtesy, not obligation.
   - **(a, recommended)** Add a one-line HTML comment above the new bullet
     crediting `ayghri/i-have-adhd` (MIT) as the inspiration. Matches house
     style, costs one line, survives mirror regeneration.
   - (b) Credit it in the CHANGELOG entry only, leaving the persona file clean.
   - (c) No attribution.

2. **Do the Cursor and Codex reviewer ports get the change?** Both carry the
   exact sentence Edit A changes, both are ungated for body prose, and both are
   deliberately abridged ports with "loud degradation" notes.
   - **(a, recommended)** Canonical + mirror only. Each port stays internally
     self-consistent — a port that does not carry the numbering instruction
     correctly says "bare list" — and the abridged ports' completeness is a
     separate, larger question. C10 pins this scope so the choice is visible.
   - (b) Also apply Edit A (the one-word change) to both ports, leaving the new
     bullet out of them.
   - (c) Apply both edits to both ports.

   If the answer is (b) or (c), C10 inverts and the two port files join the
   affected-files list; the unit stays a single unit either way.

## Self-check

- CHK1: Does the plan state where the new bullet goes precisely enough to place
  it without guessing? — PASS (immediately after the Verdict bullet, anchored on
  the line ending "is never obscured.")
- CHK2: Do the new prose and the existing Verdict bullet agree about the FAIL
  defect list's shape? — FAIL (conflicting: "a bare list" vs "number the defect
  list") — revised in place, by adding Edit A and gating it with C6's
  negative/positive pair.
- CHK3: Does the new prose contradict "PASS: one line ... nothing else" by
  demanding an action-first lead? — FAIL (conflicting) — revised in place: the
  bullet now says a PASS verdict stays exactly one line and gains no "next
  step", because routing is the orchestrator's call.
- CHK4: Is the audit-trail-completeness attribute (category 4) defended by a
  clause a reader can point at? — PASS (the "No brevity rule may shorten,
  reorder, or drop" sentence, gated by C2).
- CHK5: Does the no-hedging rule leave the reviewer's self-disclosure of its own
  earlier misses intact? — FAIL (missing on first draft) — revised in place; now
  stated explicitly and gated by C4.
- CHK6: Is every load-bearing string protected by a *survival* pin rather than a
  deletion check that could destroy the rule it names? — PASS (C7 asserts
  presence `= 1`; no criterion asserts a load-bearing string is absent).
- CHK7: Was each criterion run against the tree and found RED? — PASS (all
  measured 2026-08-13; readings recorded inline in the sh block).
- CHK8: Is the `STATUS: complete` pin placed on a file that actually contains
  it? — FAIL (missing/wrong target on first draft: the source file carries no
  protocol block and reads 0) — revised in place; the pin moved to the mirror
  (C8).
- CHK9: Does the plan say which parts are *not* machine-checkable instead of
  inventing a gate that looks mechanical? — PASS (the paragraph following C11).
- CHK10: Do the ordered edits encode the version-bump-before-`--update`
  constraint that R1 measured? — PASS.
- CHK11: Is the adapter-port scope decision recorded as a decision rather than
  silently taken? — FAIL (ambiguous on first draft) — converted to Open
  Question 2, with C10 pinning the recommended default so the choice is visible
  in the diff.
- CHK12: Does the plan avoid claiming the shared protocol needs editing? — PASS
  (Context § Scope justifies reviewer.md alone and names the fan-out avoided).
- CHK13: Is C11's tree assertion scoped so unrelated untracked files cannot
  redden it? — FAIL (ambiguous: a bare `git status --porcelain` counts untracked
  agent-memory and plan files; measured 19 dirty entries vs 0 scoped) — revised
  in place.
- CHK14: Does the plan's account of the validate.sh flapping match what was
  actually measured? — FAIL (conflicting: the first draft asserted a
  self-healing merge gate; the real cause is another unit's uncommitted work in
  the same tree) — revised in place, R3 rewritten and the withdrawn diagnosis
  named as withdrawn rather than quietly deleted.
- CHK15: Does any step hard-code a version number that a concurrent unit could
  claim first? — FAIL (missing) — revised in place: R7 added, ordered edit 2
  re-derives the target, and C1 asserts only that the version changed.
- CHK16: Does the plan state a starting precondition for the tree, given R3? —
  PASS (ordered edit 0, and the Escalation clause below).

## Scribe update hint

If this lands, `CONTEXT.md` may warrant one new glossary entry for **action-first
prose** (lens-3 finding above): the reviewer's free-form explanatory text leads
with the required action and its evidence, distinct from the load-bearing verdict
and marker formats, which no style rule may alter. Cross-reference the existing
**Guidance-only** entry, which is what this change *is*.

## Dispatch contract (fast path — 1 unit, no tracker issue)

**Unit: `reviewer-report-style`**

### Objective
Add action-first report-style guidance to the `reviewer` persona's free-form
prose, change the FAIL defect list from "bare" to "numbered", and regenerate the
mirror — without altering any verdict line, marker format, citation string,
advisory ordering, or the `STATUS:` line.

### Retrieval
No tracker issue exists (fast path). This document is the contract:
`/home/sebas/AntiSlop/docs/plans/2026-08-13-reviewer-report-style.md`.
Read Step 1 for the exact prose, R1 for the ordering constraint.

### Affected files
`agents/reviewer.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`, and — by
`node bin/cli.js --update` only — `.claude/agents/reviewer.md`,
`.claude/persona-config.json`, and possibly `.claude/hooks/scripts/**`.

### Ordered edits
0. Confirm the tree is clean of R3's in-flight work (`git status --porcelain
   -uno` empty). If it is not, stop and report — do not interleave.
1. `agents/reviewer.md` Edit A (`bare` → `numbered`) and Edit B (new bullet).
2. `.claude-plugin/plugin.json`: bump the patch version. Re-derive the target by
   reading the current value and incrementing (R7); `0.31.29` is the expected
   value but is not guaranteed.
3. `CHANGELOG.md`: new `## [<that version>] - 2026-08-13` entry under
   `### Changed`, describing this as a guidance-only reviewer-prose change.
4. `node bin/cli.js --update` — **after** step 2, never before (R1).
5. `bash tests/validate.sh`, then commit everything in one commit.

### Do NOT touch
`.claude/agents/reviewer.md` by hand (Constitution P2 — regenerate only);
`templates/persona-protocol.md` / `-slim.md`; `adapters/**` (Open Question 2
default is to leave the ports alone — C10 pins this); `hooks/scripts/**`; any
marker format string, the `constitution vX.Y.Z / <principle name>` citation, or
the advisory-section ordering sentence.

### Acceptance criteria
C1-C11 in the fenced `sh` block above, run verbatim from the repo root.

### Pre-resolved context
- No hook parses the reviewer's returned message text; every consumer reads
  marker-file first lines and review-join stamp fields (explorer, graph-derived).
  A prose-only change to the message is therefore safe by construction.
- `bin/cli.js:1091` fast-path + `needsRender` (`:1063-1089`) never inspect source
  content for stamped specs — hence the mandatory bump-before-update ordering.
- `tests/adapter-protocol-parity.test.js` checks protocol sections against
  `templates/persona-protocol.md`, never persona body prose — the adapter ports
  are ungated for this change.
- `tests/reviewer-tier.test.sh` (aq)/(ar) force the reviewer to **opus** for any
  diff touching either reviewer file.
- `agents/reviewer.md` is wrapped prose: use the line-join idiom for every grep
  (R4), and single-quote every pattern — this repo's prose is backtick-dense and
  double quotes trigger command substitution.
- Baseline `bash tests/validate.sh` measured green on 2026-08-13; see R3 for the
  first-run `.claude/hooks/scripts` self-heal caveat.

### Escalation
Stop and report if: **`git status --porcelain -uno` is non-empty at start** —
the tree still carries R3's in-flight caller-allowlist work and the two units
must not interleave; `--update` reports a divergence requiring
`--accept`/`--keep` on `.claude/agents/reviewer.md`; C9 stays red after a second
run; or either Open Question is still unanswered when the answer would change
the affected-files list (Open Question 2 options b/c).
