# Replace the escalation packet's comprehension quiz with worked examples

**Status:** FINAL — ready to dispatch (fast path, 4 units)
**Date:** 2026-08-20
**Author:** spec-master
**Supersedes behaviour from:** unit #300 (comprehension quiz), unit #375 Step 14
(`quiz:` token), unit #379 Step 2 / #380 D2 (injection guards — property retained)

## Goal

Retire the **comprehension quiz** (`QUIZ.md` + `QUIZ-ANSWERS.md` + the `quiz:`
attestation token) from the escalation packet, and replace it with **worked
examples** (`EXAMPLES.md`): 3 to 5 behavioural before/after illustrations,
written **only when the change has an observable behavioural consequence**, with
the approve-route attestation preserved under a renamed token vocabulary
(`examples: reviewed | skipped | none-offered`).

## Context

On an `ESCALATE-TO-HUMAN` verdict the reviewer writes a packet to
`.claude/human-review/<task-id>/` containing `PACKET.md`, `CHANGES.md`,
`QUIZ.md`, `QUIZ-ANSWERS.md`, and a copy of the unit's microworld bundle. The
quiz exists because, of the DECISION channel's three routes, **approve is the
only one a human can complete without demonstrating engagement** — reject needs
a reason, direct needs a directive, approve needed only a name
(`templates/persona-protocol.md:394`, described there as a *speed regulator*).

This change swaps the **artifact** (questions the human answers → examples the
reviewer writes) while **keeping the ledger** (a required attestation token on
the approve route). The engagement property gh300 established is preserved; the
self-administered-test ceremony is not.

The reviewer's non-adjudication constraint (R6 — never grade, never gate) is
preserved and becomes structurally trivial: with no questions and no answer key
there is nothing to grade, but the protocol must still state that the reviewer
never reads or judges the human's engagement, so a later editor cannot
reintroduce grading.

### Distribution shape (why the unit slicing is what it is)

Three separate propagation mechanisms carry protocol text, and they behave
differently:

1. `templates/persona-protocol.md` and `agents/*.md` are **sources**; their
   `.claude/` counterparts are **generated mirrors** (`bin/cli.js`'s
   `inlineProtocolBlock`, `:871`/`:905`/`:2270`). Regenerating requires
   `node bin/cli.js --update --force-render` — a plain `--update` fast-paths out
   when `pluginVersion` already matches and compares the **stamp, not the
   content** (`:1221`).
2. `adapters/codex/agents-md-fragment.md` and
   `adapters/cursor/rules/persona-protocol.mdc` are **hand-maintained ports**.
   `bin/cli.js` only copies them into place (`:1599-1604`, `:2034`); it never
   renders them from the template. `--force-render` does nothing for them.
   `tests/adapter-protocol-parity.test.js:60-69` keeps them honest with an
   `ESCALATION_PROBES` array of **literal strings**.
3. `bin/microworld-dashboard/decision-block.js` is **injected verbatim into
   `index.html`** by `server.js`'s `GET /` handler (`server.js:88-89`,
   `index.html:122-124`), and `tests/dashboard-decisions-client.test.js:92`
   evaluates the real module source alongside the client. Renaming a token in
   the composer without updating the client fails in the **same commit**.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-20 Functional scope & success criteria: Q The quiz is documented as a
  *speed regulator* on the approve route; does replacing it with examples
  (material the reviewer gives, not engagement the human owes) deliberately
  drop that property, or is it retained? → A: retained — keep an attestation
  token, renamed. Approve still cannot be completed with only a name.
- 2026-08-20 Domain entities / data model: Q Is the `quiz:` DECISION/marker
  token deleted or renamed? → A: renamed to
  `examples: reviewed | skipped | none-offered`, exact spelling at
  spec-master's discretion within the existing grammar.
- 2026-08-20 Domain entities / data model: Q One file or a pair, and what
  filename? → A (self-resolved): a single `EXAMPLES.md`. The `QUIZ.md` /
  `QUIZ-ANSWERS.md` split existed only so the human could attempt before
  self-checking; examples are illustrative, so there is nothing to withhold and
  no answer key to write.
- 2026-08-20 User interaction flow: Q What happens to the dashboard's "Reveal
  answer key" button and its lazy `/api/source` fetch? → A (self-resolved):
  both removed — there is no key. `/api/source` itself stays; it has two other
  consumers (`index.html:753` briefing/plan-doc excerpts, `:1223`
  milestone-finding locations), so removing the reveal does not orphan it.
- 2026-08-20 Non-functional attributes: Q Does removing the `quiz:` token
  weaken the DECISION-body newline-injection guard? → A (self-resolved): no —
  the guard's property is *allowlist by exact literal*, which the renamed
  `EXAMPLES_TOKENS` preserves unchanged. The separate `by`/`reason`
  `assertNoNewline` guards are untouched; only their comment text (which cites
  a forged `quiz:` line as the example attack) is reworded.
- 2026-08-20 Edge cases / failure handling: Q What migrates for in-flight
  escalations and historical markers? → A (self-resolved): nothing.
  `.claude/human-review/` is empty and there are zero `.escalated` markers, so
  no packet is mid-flight. Six historical `.pass` markers carry a `quiz:` line;
  they are untracked per-unit history and `task-gate.sh`'s `marker_valid()`
  reads line 1 only, so they stay valid untouched. No back-compat alias for
  `quiz:` is added — the token never persists across units.
- 2026-08-20 Technical constraints & tradeoffs: Q Do the adapter ports
  regenerate from the template? → A (self-resolved): no, they are hand-adapted
  (see Context §2); they need an explicit edit step, and the parity test's
  literal probe array is a deliverable, not test incidentals.
- 2026-08-20 Terminology consistency: Q "Examples" is generic and overlaps the
  glossary's **comprehension material**; what is the canonical term? → A
  (self-resolved): **worked example**, defined as a *subtype* of comprehension
  material (alongside the literate change summary), not a parallel concept.
- 2026-08-20 Edge cases / failure handling: Q What makes examples "needed", and
  how is a skip auditable rather than silent? → A: needed whenever the change
  has an observable behavioural consequence; skipped for pure
  docs/formatting/comment/rename changes, with the reviewer logging a one-line
  reason — not a bare `none-offered`.
- 2026-08-20 Completion / acceptance signals: Q What gates this work? → A
  (self-resolved): `bash tests/validate.sh` exit 0 per unit (verified in a
  clean worktree at the unit's own commit), plus `node bin/cli.js --update
  --dry-run` exit 0 for mirror parity, plus per-unit negative greps proving the
  old vocabulary is gone from that unit's own files.

### Terminology check (`ubiquitous-language`, prose mode)

- **Lens 1 — glossary term used with a different meaning.** The originating
  request says "remove quizzes from **the review**". `CONTEXT.md` defines
  *review* as the reviewer's PASS/FAIL adjudication; the quiz lives in the
  **escalation packet**, on the human-review path. Scoped accordingly: no unit
  in this spec touches verdict behaviour.
- **Lens 2 — new synonym for a defined term.** "Examples" overlaps
  **comprehension material** (already defined, covering `PACKET.md` and the
  literate change summary). Resolved by defining **worked example** as a
  subtype of comprehension material rather than a new sibling concept.
- **Lens 3 — load-bearing new term with no entry.** **worked example** needs a
  `CONTEXT.md` entry; the **comprehension quiz** entry needs the repo's
  retired-entry treatment (`**[Retired in 0.31.61; see worked example below.]**`,
  the convention at `CONTEXT.md:295`), not deletion. The **Escalation packet**
  and **Document pane** entries both name the quiz files and need updating —
  the latter enumerates *six* document panes by name, which becomes five.

## Risks / dependencies

- **R1 — Mirror parity is transitive and unforgiving.** `tests/validate.sh:520`
  runs `tests/cli-backfill.test.js`, which copies the real repo root into a
  fixture and asserts `node bin/cli.js --update --dry-run` exits 0 on it. Any
  unit editing `agents/*.md` or `templates/*.md` **must regenerate its `.claude/`
  mirrors in the same unit**, with `--force-render`. Deferring makes that unit's
  own `validate.sh exit 0` criterion unsatisfiable. This exact failure class has
  now caused three recorded incidents (`gh385-2.fail`, `gh402.pass` note 1,
  `gh403.fail`) — Unit 1 is scoped to avoid a fourth.
- **R2 — Do not split the composer from its injected copy.** `decision-block.js`
  and `index.html` must change in one unit (Context §3). This is why Unit 3 is
  larger than it looks; splitting it would red the tree at the intermediate
  commit.
- **R3 — The parity probe array can go vacuous.** Removing the `QUIZ.md` probes
  without adding `EXAMPLES.md` probes leaves
  `tests/adapter-protocol-parity.test.js` passing while asserting nothing about
  the new concept. Unit 2's criteria assert probe *presence*, not just a green
  run.
- **R4 — Prior-defect history.** No `.fail` record exists for any unit in this
  area, and no unit here is a re-scope of previously-failed work. However,
  `gh403.fail` and `gh402.pass` are both mirror-parity failures on
  protocol-source edits, i.e. Unit 1's exact shape. Unit 1 must not be tagged
  `haiku`.
- **R5 — Section count must not change.** `tests/protocol-doc-drift.test.js`
  asserts the `## `-delimited section count in the protocol templates matches
  counts hardcoded in prose. This spec edits *inside* `## Fourth verdict:
  escalate-to-human` and adds/removes no section, so the count is stable. Do not
  "tidy" the change into a new section.
- **R6 — the never-grade constraint (the project's own principle, confusingly
  also called "R6" in existing code comments; this bullet is this plan's risk
  numbering, the principle is the thing at risk).** The reviewer's
  never-grade/never-gate constraint must survive the rewrite as explicit prose,
  not be dropped as obsolete. With no answer key it is trivially satisfied,
  which is exactly how it silently disappears.
- **Measured baseline, 2026-08-20** (working tree at `130664d`, dirty with
  unrelated in-flight work): `bash tests/validate.sh` exits **0** with zero
  `FAIL` lines, and `node bin/cli.js --update --dry-run` exits **0** ("already
  current" for every managed path). Both tree-wide criteria are therefore real
  gates, not pre-broken ones — any red after a unit is that unit's own doing.
  Per the baselines-expire rule, re-measure if this spec is dispatched more than
  a few days out or after unrelated units land.
- **Dependency order:** Unit 1 → Unit 2 → Unit 3 → Unit 4. Units 1 and 2 are
  separable (the parity test reads probes against the *adapters*, which Unit 1
  does not touch, so Unit 1 alone leaves the tree green). Unit 4 must run last;
  it documents what the first three shipped.

## Constitution check

`.claude/constitution.md` does not exist in this repository — no constitution
gate applies. (Checked 2026-08-20.)

---

## Step 1 — Protocol + persona sources + generated mirrors

**Affected files:** `templates/persona-protocol.md`, `agents/reviewer.md`,
`agents/orchestrator.md`, and the `.claude/` mirrors regenerated from them
(`.claude/persona-protocol.md`, `.claude/agents/reviewer.md`,
`.claude/agents/orchestrator.md`, plus any other mirror `--force-render`
rewrites).

Replace the quiz mechanism with worked examples in the normative sources:

- The packet-creation bullet writes `EXAMPLES.md` in place of `QUIZ.md` +
  `QUIZ-ANSWERS.md`.
- `EXAMPLES.md` holds **3 to 5 worked examples**, each a behavioural
  before/after ("before this change, X did Y; after, X does Z"), each grounded
  in `CHANGES.md` and the bundle, each about **consequence rather than recall**.
- **When needed:** written whenever the change has an **observable behavioural
  consequence**; skipped for changes with no behavioural surface (pure docs,
  formatting, comments, pure renames).
- **Auditable skip:** the `.escalated` marker body gains one `examples:` line —
  `examples: <count>` when written, or `examples: none — <one-line reason>` when
  not. `PACKET.md` is a byte-identical copy of the marker body, so it inherits
  this automatically.
- Authored **after** the would-be verdict; never gates or influences it.
  **R6 retained explicitly:** the reviewer writes the examples and stops — it
  never reads, judges, or scores the human's engagement, and never conditions a
  verdict, marker, or route on it.
- Approve-route attestation becomes
  `human: approved by <name> <UTC ISO-8601> examples: <token>`, token exactly one
  of `reviewed`, `skipped`, `none-offered` (the last only when no `EXAMPLES.md`
  was written). All existing rules carry over verbatim under the new name:
  first-class legitimate skip, approve-route only, absent-line fallback
  (`skipped` when examples were written, `none-offered` when not, never a stall),
  and marker-format safety (appended line only, never line 1).
- Packet-lifecycle and three-route deletion bullets name `EXAMPLES.md` in place
  of the two quiz files.
- `agents/orchestrator.md:195-217`: surface `EXAMPLES.md` (if present); the
  never-answer-the-quiz rule becomes **never author or extend the examples on
  the human's behalf**; the decision-template third line becomes
  `examples: <token>`, relayed verbatim, never inferred, never nagged on a skip.

**Acceptance criteria** (all run from the repo root; verify in a clean worktree
at this unit's own commit, not the live tree):

1. `git grep -ci quiz -- templates/persona-protocol.md agents/reviewer.md agents/orchestrator.md` exits non-zero (no matches remain).
2. `git grep -ci quiz -- .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md` exits non-zero.
3. `git grep -c 'EXAMPLES.md' -- templates/persona-protocol.md` reports ≥ 3, and ≥ 1 for each of `agents/reviewer.md` and `agents/orchestrator.md`.
4. `git grep -c 'examples: none-offered' -- templates/persona-protocol.md` reports ≥ 1, and the same file matches `examples: reviewed` and `examples: skipped`.
5. `git grep -c 'never graded' -- templates/persona-protocol.md agents/reviewer.md` reports ≥ 1 in each (R6 survives the rewrite).
6. `node bin/cli.js --update --dry-run` exits 0 (mirrors regenerated and byte-current).
7. `node tests/protocol-doc-drift.test.js` exits 0 (section count unchanged).
8. `node tests/protocol-cross-references.test.js` exits 0.
9. `bash tests/validate.sh` exits 0.

---

## Step 2 — Hand-adapted Codex + Cursor ports and their parity probes

**Affected files:** `adapters/codex/agents-md-fragment.md`,
`adapters/cursor/rules/persona-protocol.mdc`,
`tests/adapter-protocol-parity.test.js`.

Port Step 1's protocol change into both hand-maintained adapter ports (codex
`:183-190`, `:217`, `:228`, `:232-248`; cursor `:191-198`, `:226`, `:237`,
`:241-257`), preserving each port's existing house style (reworded headers,
ASCII hyphens). Then update `ESCALATION_PROBES`
(`tests/adapter-protocol-parity.test.js:60-69`): drop `'QUIZ.md'`,
`'QUIZ-ANSWERS.md'`, `'quiz: passed-self-check'`, `'quiz: skipped'`,
`'quiz: none-offered'`; add `'EXAMPLES.md'`, `'examples: reviewed'`,
`'examples: skipped'`, `'examples: none-offered'`. Keep
`'Fourth verdict: escalate-to-human'`, `'Comprehension material only'`, and
`'never graded by the reviewer'` unchanged.

**Acceptance criteria:**

1. `git grep -ci quiz -- adapters/` exits non-zero.
2. `git grep -ci quiz -- tests/adapter-protocol-parity.test.js` exits non-zero.
3. `git grep -c 'EXAMPLES.md' -- adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc` reports ≥ 1 for each file.
4. `node tests/adapter-protocol-parity.test.js` exits 0.
5. **Non-vacuity proof (required, report the output):** temporarily delete the string `EXAMPLES.md` from `adapters/codex/agents-md-fragment.md`, re-run criterion 4, and confirm it now exits **non-zero**; restore the file and confirm exit 0 again. A probe array that passes with the concept absent is a defect, not a pass.
6. `bash tests/validate.sh` exits 0.

---

## Step 3 — Dashboard: composer, server, reader, client, and their four tests

**Affected files:** `bin/microworld-dashboard/decision-block.js`,
`bin/microworld-dashboard/server.js`, `bin/microworld-dashboard/decisions.js`,
`bin/microworld-dashboard/index.html`, `tests/dashboard-decision-block.test.js`,
`tests/dashboard-decision-run.test.js`, `tests/dashboard-decisions.test.js`,
`tests/dashboard-decisions-client.test.js`.

**These ship together by necessity** — see R2.

- `decision-block.js:25`: `QUIZ_TOKENS = ['passed-self-check','skipped','none-offered']`
  → `EXAMPLES_TOKENS = ['reviewed','skipped','none-offered']`. Rename the `quiz`
  context field to `examples` (`:77`, `:132-139`), emitting `examples: <token>`.
  Preserve every existing behaviour: approve-route only; omitted field composes
  today's body unchanged; a leftover field on reject/direct is **ignored with a
  warning, never thrown** (a shared form carries it across route switches).
  Update the comments at `:17-24` and `:60-63` that cite a forged `quiz:` line
  as the injection example.
- `server.js:289`, `:351`: rename the destructured/forwarded field.
- `decisions.js:46`, `:57`, `:67-69`: `quizBody` → `examplesBody`, reading
  `EXAMPLES.md`, same fail-soft-to-`null` behaviour. Update the comment noting
  the answer key must never enter the payload — with no answer key, state
  instead that only `EXAMPLES.md` is read.
- `index.html`: `escalationForm.quiz` → `.examples` (`:151`, `:333`, `:589`,
  `:676`, `:1097`), default `'skipped'`; doc pane labelled `EXAMPLES.md` reading
  `entry.examplesBody` (`:596`, `:608-610`); pill group relabelled `Examples`
  with ids `examplesOption-reviewed` / `-skipped` / `-none-offered`
  (`:625-629`, `:655-658`). **Delete** the reveal button, its container, and the
  lazy fetch (`:612-615`, `:682-687`, `:691-710`, including
  `loadQuizAnswerKey()`).
- Update the four test files' assertions to the new vocabulary, preserving each
  existing check's intent one-for-one — including
  `dashboard-decisions.test.js` Test (j) (which proves a sibling file in the
  packet directory never enters the `/api/decisions` payload; retarget it from
  `QUIZ-ANSWERS.md` to any non-`EXAMPLES.md` sibling so the containment property
  keeps a test) and `dashboard-decision-run.test.js` Test (10) (all three tokens
  behave identically).

**Acceptance criteria:**

1. `git grep -ci quiz -- bin/microworld-dashboard/` exits non-zero.
2. `git grep -ci quiz -- tests/dashboard-decision-block.test.js tests/dashboard-decision-run.test.js tests/dashboard-decisions.test.js tests/dashboard-decisions-client.test.js` exits non-zero.
3. `git grep -ci 'QUIZ-ANSWERS\|answer key\|revealBtn' -- bin/microworld-dashboard/index.html` exits non-zero.
4. `git grep -c '/api/source?file=' -- bin/microworld-dashboard/index.html` reports **exactly 2** (down from 3 today: the answer-key fetch goes, the briefing-excerpt and milestone-finding fetches stay), **and** `git grep -c "pathname === '/api/source'" -- bin/microworld-dashboard/server.js` reports **exactly 1** (the endpoint itself must NOT be removed). Measured baseline 2026-08-20: 3 and 1 respectively.
5. Each of these exits 0: `node tests/dashboard-decision-block.test.js`, `node tests/dashboard-decision-run.test.js`, `node tests/dashboard-decisions.test.js`, `node tests/dashboard-decisions-client.test.js`, `node tests/dashboard-server.test.js`, `node tests/dashboard-client.test.js`.
6. **Non-vacuity proof (required, report the output):** temporarily change `EXAMPLES_TOKENS` in `decision-block.js` to `['reviewed']`, re-run `node tests/dashboard-decision-block.test.js`, confirm it exits **non-zero**; restore and confirm exit 0.
7. `bash tests/validate.sh` exits 0.

---

## Step 4 — Glossary, README, CHANGELOG (scribe)

**Affected files:** `CONTEXT.md`, `README.md`, `CHANGELOG.md`.

- `CONTEXT.md:1001-1035`: mark the **comprehension quiz** entry retired using
  the repo's existing convention (`CONTEXT.md:295`):
  `**[Retired in 0.31.61; see worked example below.]**`, keeping the historical
  body. Do **not** delete it.
- `CONTEXT.md`: add a **worked example** entry — a *subtype of comprehension
  material* (alongside the literate change summary), 3 to 5 behavioural
  before/after illustrations in `EXAMPLES.md`, written only when the change has
  an observable behavioural consequence, skip logged as
  `examples: none — <reason>` on the `.escalated` marker; the three attestation
  tokens; first-class skip; approve-route only; marker-format safety; an
  `_Avoid_` line (suggested: *example, sample, demo, examples quiz* — use
  "worked example", or name `EXAMPLES.md` directly).
- `CONTEXT.md:864-868` (**Escalation packet**): name `EXAMPLES.md` in place of
  the quiz pair.
- `CONTEXT.md:1096-1101` (**Document pane**): the enumeration drops entries (3)
  `QUIZ.md` body and (4) `QUIZ-ANSWERS.md` lazy reveal and gains `EXAMPLES.md`
  body — **six panes becomes five**, and the numbering of the survivors must be
  renumbered consistently, including any prose references to the count.
- `README.md:199-212`: rewrite "What's in the packet" for `EXAMPLES.md` and the
  three `examples:` tokens; keep the reader-facing reassurance that the material
  is theirs and a skip is legitimate.
- `CHANGELOG.md`: new entry recording the swap, its rationale (the approve-route
  engagement property is retained, the self-test ceremony is not), the token
  rename, the when-needed rule with its auditable skip, and that no migration is
  required for historical markers.

**Acceptance criteria:**

1. `git grep -c 'Retired in 0.31.61' -- CONTEXT.md` reports ≥ 1.
2. `git grep -c 'worked example' -- CONTEXT.md` reports ≥ 3.
3. `git grep -ci quiz -- README.md` exits non-zero.
4. `git grep -c 'EXAMPLES.md' -- README.md CHANGELOG.md CONTEXT.md` reports ≥ 1 for each file.
5. `git grep -c 'renders six' -- CONTEXT.md` exits **non-zero** and `git grep -c 'renders five' -- CONTEXT.md` reports **1**. (Do **not** grep for the phrase "six document panes" — it is split across a line wrap at `CONTEXT.md:1097` and never matches on one line, so such a criterion passes vacuously. Measured 2026-08-20.)
6. `node tests/ubiquitous-language.test.js` exits 0.
7. `bash tests/validate.sh` exits 0.
8. Manual, stated in the report: every `[[wiki-link]]` introduced in the new **worked example** entry resolves to an existing `CONTEXT.md` entry heading.

---

## Open Questions

None outstanding. The three questions returned on 2026-08-20 (attestation
token's fate, definition of an example, "when needed" criterion) were answered
by the operator and are recorded in Clarifications above.

## Self-check

- CHK1: Is the exact `examples:` token vocabulary defined in one place and used
  consistently across all four steps? — PASS (`reviewed | skipped |
  none-offered`, Step 1, asserted in Steps 1/2/3).
- CHK2: Do Steps 1 and 3 agree on which route emits the token? — PASS (both say
  approve-route only; Step 3 additionally pins the ignore-with-warning
  behaviour on reject/direct).
- CHK3: Is "when needed" backed by something auditable rather than arbitrary? —
  FAIL (ambiguous on first draft: "observable behavioural consequence" is a
  judgment call with no artifact) — **revised in place**: Step 1 now requires an
  `examples:` line in the `.escalated` marker body, `examples: none — <reason>`
  on a skip, which makes every skip a written record.
- CHK4: Does any step's `validate.sh exit 0` criterion depend on work assigned to
  a later step? — FAIL (missing on first draft: Step 1 edited protocol sources
  with mirror regeneration unassigned) — **revised in place**: Step 1's affected
  files now include the generated mirrors and criterion 6 pins
  `--update --dry-run` exit 0. See R1.
- CHK5: Are the composer and its injected client copy in the same unit? — PASS
  (Step 3 bundles them; R2 states why).
- CHK6: Is the reviewer's never-grade/never-gate constraint preserved in the
  plan's own text, not just assumed obsolete now that there is no answer key? —
  PASS (Step 1 bullet 5, asserted by Step 1 criterion 5 and Step 2's retained
  `'never graded by the reviewer'` probe).
- CHK7: Could the parity test pass while asserting nothing about the new
  concept? — FAIL (ambiguous on first draft: a green run proves nothing after
  probes are deleted) — **revised in place**: Step 2 criterion 5 adds a mutation
  proof.
- CHK8: Is the fate of `/api/source` unambiguous, given only one of its three
  consumers is removed? — PASS (Step 3 criterion 4 asserts ≥ 2 surviving
  consumers, so deleting the endpoint fails the unit).
- CHK9: Does the plan state what happens to existing markers and in-flight
  packets? — PASS (Clarifications: nothing migrates; measured — no `.escalated`
  markers, `.claude/human-review/` empty).
- CHK10: Is the doc-pane count change stated as a count change, not just a list
  edit? — PASS (Step 4, "six panes becomes five", asserted by criterion 5).
- CHK11: Does any step risk changing the protocol's `## ` section count? — PASS
  (R5; all edits are inside an existing section).
- CHK12: Does every grep criterion in this plan actually flip state when the
  work is done? — FAIL (ambiguous on first draft) — **revised in place**. Two
  were defective when executed against the live tree: Step 4's
  `git grep -n 'six document panes'` **already exited non-zero before any work**
  (the phrase is split across a line wrap at `CONTEXT.md:1097`), making it
  vacuous; and Step 3's `/api/source` count criterion was too loose (`-c` counts
  comment lines, reporting 6, so it would have passed even if a fetch site were
  wrongly deleted). Both replaced with measured, exact-count criteria.
- CHK13: Are the two tree-wide criteria (`validate.sh`, `--update --dry-run`)
  satisfiable from the current baseline? — PASS (both measured exit 0 on
  2026-08-20; recorded under Risks).

## Dispatch contracts (fast path — 4 units, no `task-master` routing)

Common to all four units:

- **Retrieval:** no tracker issue exists for this work. Read this document at
  `/home/sebas/AntiSlop/docs/plans/2026-08-20-quiz-to-worked-examples.md`; your
  unit's Step section is authoritative for scope and criteria.
- **Escalation:** if a criterion cannot be satisfied within your unit's affected
  files, stop and report — do not widen scope into another unit's files, and do
  not weaken a criterion to make it pass. If `bash tests/validate.sh` is red on
  arrival (before your edits), report that rather than absorbing it: the
  measured baseline is green. Verify `validate.sh` in a clean worktree at your
  own commit, never the live tree.
- **Do NOT touch (all units):** `hooks/scripts/*` (no hook references the quiz —
  measured: `git grep -i quiz -- hooks/` is empty, and the DECISION gates block
  writes to the path without parsing its grammar); the `route`/`by`/`reason`/
  `escalation`/`via` fields of the DECISION grammar; `PACKET.md` and
  `CHANGES.md` semantics; existing `.claude/reviewed/*.pass` markers; any
  `docs/plans/*.md` other than this one (historical, append-only).

---

**Unit: `examples-1`** — protocol + persona sources + generated mirrors

- **Objective:** Step 1 above.
- **Affected files / Ordered edits / Acceptance criteria:** Step 1.
- **Do NOT touch:** `adapters/**` (Unit 2), `bin/microworld-dashboard/**`
  (Unit 3), `CONTEXT.md` / `README.md` / `CHANGELOG.md` (Unit 4),
  `agents/spec-master.md` and `agents/milestone-auditor.md` (owned by the
  concurrent `grilling-fix-1` unit).
- **Pre-resolved context:** mirrors regenerate with
  `node bin/cli.js --update --force-render` — a plain `--update` will silently
  do nothing (stamp-not-content fast path, `bin/cli.js:1221`). Never hand-edit a
  `.claude/` mirror. Adding or removing a `## ` section would break
  `protocol-doc-drift.test.js`; all edits belong inside the existing
  `## Fourth verdict: escalate-to-human` section.
- **Escalation:** common clause. Additionally — this unit is the shape that
  caused three recorded mirror-parity failures (R1/R4); do not tag it `haiku`.

---

**Unit: `examples-2`** — hand-adapted adapter ports + parity probes

- **Objective / Affected files / Ordered edits / Acceptance criteria:** Step 2.
- **Do NOT touch:** `templates/**`, `agents/**`, `.claude/**`,
  `bin/microworld-dashboard/**`, Unit 4's docs.
- **Pre-resolved context:** the two ports are **hand-maintained** — `bin/cli.js`
  only copies them (`:1599-1604`, `:2034`) and never renders them from the
  template, so `--force-render` will not help you. Match each port's existing
  house style (reworded headers, ASCII hyphens). The probe array is a
  deliverable, not test scaffolding: `canonicalHeaders()` derives section names
  from `templates/persona-protocol.md`, and since Unit 1 changes no header, only
  the probe *contents* need changing.
- **Escalation:** common clause. If criterion 5's mutation proof does **not**
  fail as expected, the probe array is not actually gating — report it rather
  than proceeding.

---

**Unit: `examples-3`** — dashboard composer, server, reader, client, four tests

- **Objective / Affected files / Ordered edits / Acceptance criteria:** Step 3.
- **Do NOT touch:** `templates/**`, `agents/**`, `.claude/**`, `adapters/**`,
  Unit 4's docs; the `/api/source` endpoint handler in `server.js`; the
  `assertNoNewline` / `assertStringField` guards themselves (comment text only).
- **Pre-resolved context:** `decision-block.js` is **injected verbatim into
  `index.html`** by `server.js:88-89`, and
  `tests/dashboard-decisions-client.test.js:92` evaluates the real module source
  — so the composer and the client must change in the same commit or the client
  test reds. Preserve three existing behaviours exactly under the new names:
  approve-route-only emission, omitted-field composes an unchanged body, and a
  leftover field on reject/direct warns rather than throws (a shared form
  carries it across route switches). This is the largest unit; it is
  deliberately not split (R2).
- **Escalation:** common clause.

---

**Unit: `examples-4`** — glossary, README, CHANGELOG (dispatch to `scribe`)

- **Objective / Affected files / Ordered edits / Acceptance criteria:** Step 4.
- **Do NOT touch:** everything shipped by Units 1-3; the retired
  **comprehension quiz** entry's historical body (mark it retired, keep the
  text).
- **Pre-resolved context:** the retired-entry convention already exists at
  `CONTEXT.md:295` (`**[Retired in <version>; see <replacement>.]**`); current
  plugin version is `0.31.61`. `quiz` legitimately **remains** in `CONTEXT.md`
  after this unit (inside the retired entry), so do not add a blanket
  `git grep -i quiz -- CONTEXT.md` criterion — it would be wrong, not merely
  vacuous. The **Document pane** entry enumerates its panes by number; removing
  two and adding one requires renumbering the survivors, not just deleting
  lines.
- **Escalation:** common clause. Run last — this unit documents what Units 1-3
  actually shipped; if it contradicts the code, the code wins and you report the
  discrepancy.

## Scribe update hint

After Step 4, `CONTEXT.md` carries a retired **comprehension quiz** entry and a
new **worked example** entry; the **Escalation packet** and **Document pane**
entries change. The wiki page for the human-review path (if one exists beyond
`.claude/wiki/protocol-delivery-tiers.md`, which is unaffected — no section
count change) should be checked for quiz references at the same time.
