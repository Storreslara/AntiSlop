# `ubiquitous-language` in spec-master's own workflow

Status: finalized 2026-08-09. Supersedes the skill definition in
`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`
Step 1 (issue #129) — see "Relationship to #129" below.

## Goal

Ground `spec-master`'s self-scored taxonomy category 8 ("Terminology
consistency") in the repo's actual glossary, so terminology drift is caught at
**spec-authoring time** — where it is cheap, and where canonical language is
actually being minted — rather than only at reviewer time on a finished diff,
where it is expensive and has already propagated into code, tickets, and
persona prose.

## Context

Verified findings from exploration:

- **`skills/ubiquitous-language/` does not exist.** It is spec-only, defined at
  `docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`
  lines 568-629, tracked as issue #129 (OPEN, unassigned, `ready-for-agent`,
  `Depends on / blocked by: none`).
- **That spec is structurally diff-shaped and cannot be reused as-is.** Line
  586 scopes it to names "introduced or renamed by **the diff**"; line 588
  requires "Every finding names `file:line`". A natural-language request has
  neither. This is a structural mismatch, not a matter of taste.
- **`spec-master`'s category 8 is currently ungrounded.** `agents/spec-master.md`
  never mentions `CONTEXT.md` anywhere in its 228 lines (`grep -c 'CONTEXT.md'`
  returns **0**). Category 8 (line 31) is scored purely by judgment.
- **There is no "rough draft" phase in `spec-master`'s pipeline.** The
  documented pipeline is explore → taxonomy scoring → `grill-me` → plan
  write-up → Self-check → `to-spec`. Per OQ3, this plan adds **no new phase**;
  it attaches the check to two phases that already exist.
- **The "own spec" candidate at line 1530 of the Microworlds doc is
  `/explain-diff`, not `ubiquitous-language`.** Read in context (lines
  1518-1531): item 2 states ubiquitous-language "already is the source's
  'shared vocabulary' idea… No gap"; item 4's "candidate for its own spec"
  refers to the standalone explainer skill. **This plan is not that named
  candidate** — it is a new request.
- **This repo's own `CONTEXT.md` does not conform to `CONTEXT-FORMAT.md`.** It
  has **zero** `_Avoid_` lines and no `## Language` heading; it is a flat
  `- **Term** — definition` list of **32** entries. The `_Avoid_` list is
  precisely the machine-readable signal powering drift lens (b), "a new synonym
  for an already-defined term" (line 585). Today that lens has no input — a gap
  that affects the already-speced reviewer-side skill identically.
- **`tests/validate.sh` cannot catch a dangling skill reference.** Its loop is
  `for f in skills/*/SKILL.md` (line 120) — it iterates over skills that
  *exist*. Nothing cross-checks an agent's `skills:` frontmatter against disk,
  so declaring `antislop:ubiquitous-language` while the skill is absent passes
  the merge gate silently. Guarded explicitly in Step 3.
- **Blast radius is narrow when scoped to the persona body.** `spec-master.md`
  has exactly two copies: `agents/spec-master.md` and
  `.claude/agents/spec-master.md` (regenerated via `bin/cli.js --update`, G2).
  The adapter ports (`adapters/codex/agents-md-fragment.md`,
  `adapters/cursor/rules/persona-protocol.mdc`) port the *protocol* and the
  *orchestrator*, not `spec-master`'s body — so this plan touches neither
  adapter port nor either parity map.
- **Defect history, directly on point.** Commit `028bc23` — "correct **vacuous
  drift-check** acceptance-criterion form (F2)" — is a prior instance of a
  drift-check acceptance criterion *in this repo* that passed while detecting
  nothing; `8cedabd` and `22f5bb2` are the same lineage. This is why Step 4
  exists and why R2 governs every criterion below.

### Relationship to #129 (resolved: supersede)

This plan **supersedes the skill definition** in Microworlds Step 1. The skill
has never been built, so respecing costs a spec edit, whereas building it
diff-only and revising afterwards costs a build plus a migration. Step 1 below
delivers everything #129 asked for (diff mode, reviewer wiring, the verdict
bullet going singular → plural) **plus** prose mode, so nothing #129 scoped is
lost. Issue #129's body is annotated to point here so it is not grabbed
independently while this is in flight; it is **not** closed and **not**
re-sliced, and issues #130-138 are untouched.

### Relationship to Microworlds Step 8 (ordering contract)

Microworlds Step 8 (lines 1210-1218, `scribe`-owned) **adds** six glossary
terms to `CONTEXT.md` but does **not** normalize its format. That step and this
plan's Step 2 therefore write the same file with order-dependent results:

- If Step 2 lands first, Microworlds Step 8 must add its six terms in the
  **canonical `CONTEXT-FORMAT.md` shape**, with `_Avoid_` lines.
- If Microworlds Step 8 lands first, Step 2 normalizes 38 entries instead of 32.

Step 2's acceptance criterion is written as a **baseline-independent
conservation check** so it is correct under either ordering. No blocking edge
is imposed in either direction.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Missing
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Missing
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-09 Functional scope & success criteria: Q Does this spec build the
  base skill, or only spec-master's consumption of an already-shipped #129? → A:
  build it — this spec supersedes #129's skill definition and delivers the skill
  dual-mode (diff + prose), per user, OQ1 option (a).
- 2026-08-09 Domain entities / data model: Q What is a drift finding against
  prose, given there is no `file:line`? → A (self-resolved): a *section-anchored*
  finding — the anchor is the quoted request span or the plan's own
  heading/step number, plus the same two sentences diff mode uses (the drift,
  then the canonical term). The three drift lenses at lines 583-587 are
  input-agnostic and carry over unchanged; only the anchor differs.
- 2026-08-09 User interaction flow: Q Is the "first pass at a rough spec" a new
  pipeline phase, and is the raw request, the draft, or both checked? → A: both,
  at two phases that already exist, adding no new phase — the raw request during
  grill-before-planning (feeding category 8's score, exactly where that score is
  produced) and the draft plan during Self-check. Per user, OQ3 option (a).
- 2026-08-09 Non-functional attributes: Q What is the token cost of loading a
  22KB `CONTEXT.md` on every spec-master run? → A (self-resolved): ~6k tokens,
  acceptable once per session but not twice; the glossary is read **once** and
  reused across both check points. If `CONTEXT-MAP.md` ever appears, the
  multi-context fan-out is the real risk, capped by reading the map plus only
  the contexts the request actually names.
- 2026-08-09 External dependencies & integrations: Q What is this spec's
  relationship to unbuilt issue #129 — supersede, depend, or neither? → A:
  supersede; #129's body is annotated to point here, not closed. Per user, OQ1.
- 2026-08-09 Edge cases / failure handling: Q What happens with no `CONTEXT.md`,
  and with a `CONTEXT.md` that doesn't match `CONTEXT-FORMAT.md`? → A: absent
  glossary reuses #129's degradation verbatim (lines 591-593 — one line saying
  the glossary is absent and that `scribe` (if present) can seed one, then stop;
  not a finding, not an error). Non-conformant glossary is fixed at source by
  Step 2, per user, OQ4 option (a).
- 2026-08-09 Technical constraints & tradeoffs: Q Should this be a skill at all,
  given `domain-modeling` says merely reading `CONTEXT.md` is "a one-line habit
  any skill can do"? → A: yes, a skill. That quote was the reason OQ1 offered a
  no-skill option; the tiebreaker is that the three drift lenses are a shared
  definition of "what counts as drift" worth defining once for both consumers,
  where a bare read habit would let the reviewer-side and spec-master-side
  definitions diverge. Per user, OQ1 option (a).
- 2026-08-09 Terminology consistency: Q Does "the ubiquitous-language
  capability" mean the skill, the check, or the glossary discipline? → A
  (self-resolved): the **skill**, invoked in a new prose mode. Recorded because
  this plan is itself vulnerable to the drift it exists to prevent — cf. the
  "microworld" two-senses hazard logged at lines 1576-1579 of the Microworlds
  doc.
- 2026-08-09 Completion / acceptance signals: Q How do you machine-check that a
  *persona-body prose change* actually causes the behaviour? → A:
  mutation-proved fixture-driven behavioural test (Step 4), not grep-only, per
  the `028bc23` precedent. Per user, OQ5 option (a).

## Risks / dependencies

- **R1 — Timing window on #129.** #129 is unassigned with zero declared
  dependencies and could be grabbed at any moment, converting a cheap spec edit
  into a build-plus-revise. Mitigated by annotating #129's body to point here.
- **R2 — Vacuous acceptance criteria on a drift check.** Documented, repeated,
  and specific to this subject matter (`028bc23`, `8cedabd`, `22f5bb2`). Every
  criterion below must be provable by mutation — inject known drift, assert it
  is flagged; revert, assert clean — never by asserting exit 0 alone. The
  `! … | grep -qE …` form is **banned** here by name: `028bc23` proved it
  discards the exit code.
- **R3 — Dangling skill reference passes the merge gate.** `validate.sh` cannot
  catch it (see Context). Ordering is load-bearing: `spec-master`'s `skills:`
  line must not merge ahead of the skill directory. Guarded by Step 3's first
  criterion.
- **R4 — Self-referential scope creep.** A terminology check on `spec-master`'s
  own output can always find one more nit. Advisory-only (OQ2) bounds this; a
  gate would not.
- **R5 — Prior FAIL history is on the *criterion form*, not on any unit
  re-scoped here.** No `.fail` record exists for #129 (never built). But
  `028bc23`'s lineage is durable evidence that criterion-authoring in this exact
  area needs judgment: **Step 4 must not be tagged `haiku`**, and per the
  Microworlds plan's R7 no unit in that lineage is `haiku`-eligible either.
- **R6 — Cross-plan file contention on `CONTEXT.md`.** See the ordering contract
  above. Neither plan blocks the other; Step 2's criterion is baseline-
  independent by construction.
- **D1 — Ownership.** `CONTEXT.md` is owned by `scribe` (stated in its own
  header). Step 2 is a `scribe` unit; Steps 1, 3, 4 are `lead-programmer` units
  (`skills/`, `agents/`, `tests/`, `README.md` are plugin source, outside
  `scribe`'s write scope).

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every step carries a runnable command,
  and Step 4 is specifically a mutation-proof test rather than an exit-0
  assertion, per R2.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  `.claude/agents/spec-master.md` and `fileHashes` are regenerated via
  `bin/cli.js --update`, never hand-edited (G2). Deliberate boundary noted: the
  drift *check itself* is irreducibly an LLM judgment (it compares meanings), so
  P2 governs the plumbing, not the lens.
- P3 "Version-stamp discipline": satisfied — `agents/spec-master.md` and
  `agents/reviewer.md` are version-stamped, so every step carries the G1 triple
  (`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, plus
  `.claude/persona-config.json`'s `pluginVersion`).
- P4 "Optional personas degrade gracefully": satisfied — `spec-master`,
  `reviewer`, and `scribe` are all opt-out, so all new prose stays conditionally
  phrased; the skill no-ops when `CONTEXT.md` is absent; Step 2 must not assume
  `scribe` is selected in any prose it writes.
- P5 "`tests/validate.sh` is the merge gate": satisfied — `bash tests/validate.sh`
  is a criterion on every step and Step 4 extends it. Explicitly noted:
  validate.sh **cannot** catch R3 today, which is why Step 3 asserts the skill
  directory's existence directly rather than relying on the gate.

## Steps

> Every step also touches the G1 version-bump triple:
> `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
> `.claude/persona-config.json` (`pluginVersion`). Not repeated below.

### Step 1 — Build `skills/ubiquitous-language/SKILL.md` as dual-mode

Supersedes the skill definition in Microworlds Step 1 / issue #129. One shared
drift core, two input adapters.

The **core** is the three lenses verbatim from Microworlds lines 583-587 — (a) a
glossary term used with a different meaning, (b) a new synonym for an
already-defined term, (c) a load-bearing new domain term with no glossary entry
(reported as a suggestion for `scribe`, if present) — plus the absent-glossary
degradation from lines 591-593, unchanged. If a lens turns up nothing, it says so
briefly rather than omitting itself, so a reader can tell it ran.

- **Diff mode** (the #129 behaviour, preserved exactly): input is a diff;
  findings anchor on `file:line`; consumer is `reviewer`; emitted as ONE
  clearly-demarcated advisory section **after** the verdict line; never flips
  PASS/FAIL, never adds a FAIL ground, never substitutes for running the
  acceptance-criteria command; findings append to the `.pass` marker with the
  reviewer's other non-blocking notes.
- **Prose mode** (new): input is a natural-language request or a draft spec;
  findings anchor on a quoted span or the plan's own step/heading number;
  consumer is `spec-master`; advisory only.

Also amend `agents/reviewer.md`'s verdict bullet from "one advisory exception…
a single, clearly-demarcated `roast-work` advisory critique section" to advisory
**sections** (plural), with a fixed order after the verdict line: `roast-work`
first (if fired), then `ubiquitous-language` (if fired). The verdict remains the
first thing read. Add a new advisory-only bullet mirroring the existing
"`roast-work` is advisory, never gating" bullet, and leave that existing bullet
intact and verbatim.

**Affected files**
- `skills/ubiquitous-language/SKILL.md` (new)
- `agents/reviewer.md` (`skills:` frontmatter line; verdict-bullet wording; new
  advisory-only bullet)
- `.claude/agents/reviewer.md` (regenerated via `bin/cli.js --update`, G2)
- `.claude/persona-config.json` (`fileHashes`, written by `--update`, G2)
- `README.md` (skills list, alongside the existing `fail-triage` note)

**NOT touched, deliberately:** `package.json`'s `files` array and `bin/cli.js`'s
skill copy list — the skill resolves via the `antislop:` plugin namespace
(Microworlds Step 1's own recorded decision, lines 613-615). Neither adapter
port, neither parity map.

**Acceptance criteria**
- `bash tests/validate.sh` exits 0.
- `test -f skills/ubiquitous-language/SKILL.md` exits 0.
- `grep -q 'antislop:ubiquitous-language' agents/reviewer.md` exits 0.
- `grep -q 'antislop:ubiquitous-language' .claude/agents/reviewer.md` exits 0
  (proves `--update` propagated).
- Both modes are present as distinct documented sections: the file contains a
  heading matching `diff` and a heading matching `prose`, i.e.
  `grep -qiE '^#+ .*diff' skills/ubiquitous-language/SKILL.md` and
  `grep -qiE '^#+ .*prose' skills/ubiquitous-language/SKILL.md` both exit 0.
- `grep -c 'roast-work' agents/reviewer.md` is **≥ 4** (measured pre-change
  value on this working tree is exactly 4).
- `grep -qF '**`roast-work` is advisory, never gating**' agents/reviewer.md`
  exits 0 (the runnable form of "still exists verbatim").
- After `node bin/cli.js --update`: the command exits 0 **and**
  `git status --porcelain -uno` is non-empty for
  `.claude/persona-config.json`, proving `fileHashes` refreshed. Use this
  two-assertion form; the `! … | grep -qE …` form is banned per R2.

### Step 2 — Normalize `CONTEXT.md` to `CONTEXT-FORMAT.md` (owner: `scribe`)

Convert the flat `- **Term** — definition` list to the canonical shape defined
in `skills/domain-modeling/CONTEXT-FORMAT.md`: a `## Language` heading,
`**Term**:` entries with the definition on the following line, and — load-bearing
— `_Avoid_:` synonym lines, without which drift lens (b) has no input.

Definitions are preserved verbatim; this is a reshaping, not a rewrite. The
`_Avoid_` lines are the only genuinely new content, and are added only where a
real near-synonym exists (the Microworlds doc itself names one such pair at
lines 1214-1216: **microworld bundle vs escalation packet**).

**Affected files:** `CONTEXT.md`

**Acceptance criteria**
- `grep -q '^## Language' CONTEXT.md` exits 0.
- `grep -c '_Avoid_' CONTEXT.md` is **≥ 1** (the pre-change value is exactly
  **0**, so this cannot pass vacuously).
- **Term conservation (baseline-independent, per R6).** Every term present
  before the edit is present after it:
  ```
  # before the edit
  grep -o '^- \*\*[^*]*\*\*' CONTEXT.md \
    | sed 's/^- \*\*//; s/\*\*$//' | sort -u > /tmp/terms-before.txt
  # after the edit
  grep -o '^\*\*[^*]*\*\*:' CONTEXT.md \
    | sed 's/^\*\*//; s/\*\*:$//' | sort -u > /tmp/terms-after.txt
  comm -23 /tmp/terms-before.txt /tmp/terms-after.txt   # must print nothing
  ```
  This is correct whether Microworlds Step 8 has landed (38 terms) or not (32).
- `bash tests/validate.sh` exits 0.

### Step 3 — Wire `spec-master`'s consumption

Amend `agents/spec-master.md`:

- add `antislop:ubiquitous-language` to the `skills:` frontmatter line;
- ground category 8 by naming the glossary read explicitly — the raw request is
  checked in prose mode during grill-before-planning, and the finding informs
  category 8's Clear/Partial/Missing score;
- extend the Self-check bullet so the **draft plan** is checked in prose mode
  before handoff;
- state explicitly that findings are **advisory**: they inform the category-8
  score and may become a grilling question or an Open Question, but **never**
  block progression to `grill-me`, `to-spec`, or `task-master` handoff. No new
  gate, no new hook.
- read the glossary **once** per session and reuse it across both check points
  (non-functional, per Clarifications).

**Affected files**
- `agents/spec-master.md`
- `.claude/agents/spec-master.md` (regenerated via `bin/cli.js --update`, G2)
- `.claude/persona-config.json` (`fileHashes`, written by `--update`, G2)
- `README.md`

**NOT touched, deliberately:** `templates/persona-protocol.md` and both adapter
ports — this change lives in one persona body, so the parity maps stay out of
the blast radius. `agents/reviewer.md` (Step 1 owns it).

**Acceptance criteria**
- `test -d skills/ubiquitous-language` exits 0 **before** this step's `skills:`
  line lands (guards R3, which `validate.sh` structurally cannot).
- `grep -q 'antislop:ubiquitous-language' agents/spec-master.md` exits 0.
- `grep -q 'antislop:ubiquitous-language' .claude/agents/spec-master.md` exits 0.
- `grep -c 'CONTEXT.md' agents/spec-master.md` is **≥ 1** (the pre-change value
  is exactly **0**, so this cannot pass vacuously).
- The advisory-only property is stated in text: `agents/spec-master.md` contains
  a line matching both `advisory` and one of `never blocks` / `never gates` /
  `never gating` — `grep -qiE 'advisory.*(never (blocks|gates|gating))' agents/spec-master.md`
  exits 0.
- `grep -c 'roast-work' agents/reviewer.md` is unchanged from its post-Step-1
  value, proving no regression there.
- `bash tests/validate.sh` exits 0; after `node bin/cli.js --update` the command
  exits 0 and `git status --porcelain -uno` shows `.claude/persona-config.json`.

### Step 4 — Mutation-proved behavioural test for the drift check

Per R2 and the `028bc23` precedent, a fixture-driven test that **commits its
mutation** rather than asserting a bare exit code.

Fixture: a minimal `CONTEXT.md` in canonical format defining one term with an
`_Avoid_` synonym. Two prose inputs — one using the avoided synonym (drift
present), one using the canonical term (clean).

The test asserts **both** directions:
1. drift input → the check reports a lens-(b) finding naming the canonical term;
2. clean input → the check reports no finding.

And it is itself proved non-vacuous: with the check stubbed out, assertion 1
must fail. A test that still passes when the check is removed does not satisfy
this step.

**Affected files**
- `tests/ubiquitous-language.test.js` (new, name at implementer's discretion)
- `tests/validate.sh` (registration)

**Acceptance criteria**
- `bash tests/validate.sh` exits 0 with the new test registered, and its output
  names the new test (proving registration, not mere presence).
- **Non-vacuity demonstration (required, recorded in the unit's commit
  message):** the implementer runs the new test twice — once with the drift
  fixture intact, once with the check stubbed to return no findings — and
  records both outputs. The first must exit 0; the second must exit non-zero.
  A unit that cannot show the second output has not met this criterion.
- The clean-input assertion is present and distinct from the drift assertion —
  the test file contains both a positive and a negative case, not one only.

## Open Questions

None outstanding. OQ1-OQ5 were resolved by the user on 2026-08-09 and are
recorded in Clarifications above:

1. OQ1 → (a) supersede #129, build dual-mode.
2. OQ2 → (a) advisory only, never gates.
3. OQ3 → (a) check both request and draft, no new pipeline phase.
4. OQ4 → (a) normalize `CONTEXT.md` as a `scribe`-owned step in this spec.
5. OQ5 → (a) mutation-proved fixture-driven behavioural test.

## Self-check

- CHK1: Does the plan define what a drift finding looks like when the input has
  no `file:line`? — PASS (Clarifications "Domain entities"; Step 1 prose mode).
- CHK2: Do Steps 1 and 3 agree on whether the skill directory must exist before
  `spec-master`'s `skills:` line lands? — PASS (Step 3's first criterion states
  the ordering; Step 1 creates the directory).
- CHK3: Is this spec's dependency relationship to issue #129 defined? — PASS
  ("Relationship to #129"; OQ1 resolved to supersede).
- CHK4: Is it defined whether the check can block `spec-master` from reaching
  `to-spec`? — PASS (Step 3 states never blocks; OQ2).
- CHK5: Does the plan say whether a new pipeline phase is added? — PASS
  (Clarifications "User interaction flow": no new phase; OQ3).
- CHK6: Is behaviour defined for a `CONTEXT.md` that exists but doesn't match
  `CONTEXT-FORMAT.md`? — PASS (Step 2 fixes it at source; OQ4).
- CHK7: Does every step carry a criterion that would fail if the step were not
  done? — PASS after revision — revised in place; Steps 2, 3, 4 now each name a
  value provably different today (`_Avoid_` count 0, `grep -c 'CONTEXT.md'` 0,
  stub-out non-zero exit).
- CHK8: Do the Constitution check and the Steps agree that adapter ports are
  untouched? — PASS (P2 and Steps 1/3 "NOT touched" both scope to persona
  bodies).
- CHK9: Is the claim that line 1530's "own spec candidate" refers to
  `/explain-diff` rather than `ubiquitous-language` supported by cited text? —
  PASS (Context cites lines 1518-1531, items 2 and 4).
- CHK10: Is it defined how a prose persona-body change is verified as effective?
  — PASS (Step 4; OQ5).
- CHK11: Do Step 2 and Microworlds Step 8 agree on who writes `CONTEXT.md` and
  in what order? — PASS after revision — revised in place; the "Relationship to
  Microworlds Step 8" ordering contract plus R6, with a baseline-independent
  conservation criterion correct under either ordering.
- CHK12: Does the plan state which acceptance-criterion *form* is banned, given
  the `028bc23` precedent? — PASS after revision — revised in place; R2 names
  the `! … | grep -qE …` form explicitly, and Steps 1 and 3 use the
  two-assertion form instead.
- CHK13: Is Step 2's term-conservation criterion machine-checkable without
  knowing whether Microworlds Step 8 has landed? — PASS (the `comm -23` form
  compares before/after extractions, never a hard-coded count).

## Scribe update hint

On completion: add `ubiquitous-language`, **diff mode**, and **prose mode** to
`CONTEXT.md`'s glossary (noting that Step 2 reshapes that file's format, so new
entries follow the canonical shape with `_Avoid_` lines). Write one ADR
recording the supersession of #129's reviewer-only design by the dual-mode
design — it meets all three of `domain-modeling`'s tests: hard to reverse (a
published, labelled issue's design was changed before build), surprising without
context (a future reader finds #129 describing a narrower skill than the one
that exists), and the result of a real trade-off (supersede vs depend-on vs
no-skill, with the timing-window rationale in R1).
