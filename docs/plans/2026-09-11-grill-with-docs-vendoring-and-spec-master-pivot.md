# Vendor `grill-with-docs`, make it and `grill-me` model-invocable, and pivot `spec-master`'s interrogation step onto it

Date: 2026-09-11
Status: FINAL — dispatchable under the recommended defaults; OQ1's answer
swaps exactly one ordered edit in Step 4 (marked inline).
Fast path: 4 dispatchable units (≤5), so the nine-element dispatch
contracts are emitted at the end of this document and `task-master` /
`to-tickets` are bypassed. This document IS the retrieval contract.

## Goal

1. Vendor upstream `grill-with-docs` into `skills/grill-with-docs/SKILL.md`
   at the already-pinned SHA `e9fcdf95b402d360f90f1db8d776d5dd450f9234`,
   following the existing `SKILL.md`-shaped provenance-header convention.
2. Apply ADR-0012's `fm-noflag` declared-deviation class to **both**
   `grill-me` and the new `grill-with-docs`, so both become reachable in
   every mode (the user's "auto-fire"; see Clarifications category 8 for
   why this plan says *model-invocable* instead). This reverses ADR-0012's
   explicit "`grill-me` is the control ... deliberately left alone"
   decision, so it is recorded in a new ADR with a reciprocal
   `Amended by ADR-0031` bullet on ADR-0012.
3. Pivot `spec-master`'s "Grill before planning" step from bare `grilling`
   onto `grill-with-docs`, which itself runs `grilling` plus
   `domain-modeling`, so the interrogation produces `CONTEXT.md`/ADR side
   effects rather than Q&A alone.
4. Land the bookkeeping the vendoring convention requires: the
   THIRD-PARTY-NOTICES per-skill table, the drift script's `FILES` table,
   the re-sync runbook's "What's vendored" table, README/CONTEXT counts,
   and a `CHANGELOG.md` entry with the constitution-§3 version bump.

## Context

- **Vendoring is governed by ADR-0005 (vendor the closure byte-verbatim)
  and ADR-0012 (`fm-noflag` declared deviations).** The operational
  runbook is `docs/maintenance/resync-vendored-skills.md`; the mechanical
  check is `scripts/resync-vendored-skills.sh --check`. Measured at HEAD
  `23b0fb4` on 2026-09-11: `--check` exits **0**, reporting `[OK]` for all
  8 drift-tracked skills and `[VENDORED]` for the 3 repoint skills.
  Upstream fetch works from this machine (~4 s, `raw.githubusercontent.com`).
- **Upstream content is confirmed at the pin.** `curl` of
  `skills/engineering/grill-with-docs/SKILL.md` @ the pinned SHA returns
  **245 bytes**, trailing newline present, body a single line:
  `Run a \`/grilling\` session, using the \`/domain-modeling\` skill.`
  It carries `disable-model-invocation: true`.
- **`domain-modeling` needs no content change.** It is already vendored
  byte-verbatim, already targets `CONTEXT.md` + `docs/adr/` natively, and
  is *already* preloaded by `scribe` (`agents/scribe.md`'s `skills:` line).
  This plan adds it to `spec-master`'s preload line as well.
- **`grill-me` is currently the byte-verbatim control** — `fm` type in the
  script's `FILES`, `disable-model-invocation: true` intact,
  `© … —` (UTF-8) provenance header. Converting it to `fm-noflag` changes
  **two** things in the file: the header text switches to the ASCII
  `fm-noflag` variant (`MIT (c) 2026 Matt Pocock - see …`) and the flag
  line is deleted. Both are required for `--check` to stay green;
  forgetting the header swap is the likeliest way this unit FAILs.
- **`grill-me` was deliberately repointed to `grilling` in unit
  grilling-fix-1 / spec #245**, precisely *because* it was unreachable
  (`CONTEXT.md:907`, `CHANGELOG.md:866`). This plan reverses the cause, not
  the repoint: `spec-master` moves on to `grill-with-docs`, not back to
  `grill-me`.
- **Blast radius is small and was measured, not inferred.** No test
  asserts any persona's `skills:` line, no test asserts `spec-master`'s
  body prose, no test or hook greps `grill`, `protectedPaths` is `[]`,
  `fileHashes` contains **zero** `skills/` entries, and `.claude/skills/`
  mirrors only `install-antislop` + `coding-discipline` (`bin/cli.js:2380-2381`),
  never the vendored set. The only mirror of `agents/spec-master.md` is
  `.claude/agents/spec-master.md`; there is no cursor/codex port of persona
  bodies.
- **Prior-defect history on these exact surfaces** (all three inform the
  criteria below):
  - `.claude/reviewed/grilling-fix-1.fail` — the last unit to edit
    `agents/spec-master.md`'s grill prose FAILed on constitution §3: no
    version bump, no CHANGELOG entry, and mirrors committed carrying a
    stamp (`v0.31.61`) that existed nowhere in the manifest. Step 4 below
    is shaped directly around that record.
  - `.claude/reviewed/gh-286-docs.fail` — a docs unit whose criteria were
    all membership greps; every one passed while the prose asserted
    capabilities that did not exist. Steps 1-3 therefore use
    claim-anchored counts and cross-file agreement checks, not `grep -q`.
  - `.claude/reviewed/gh403.fail` and the `spec2-unitE` / `mw-step3`
    family — `tests/validate.sh` is transitively a source↔mirror parity
    check via `tests/cli-backfill.test.js`'s F2/C2.12, and a plain
    `--update` can silently no-op. Step 4 mandates `--force-render` and
    pristine-worktree verification.
- **Non-blocking notes swept** (`bash bin/marker-audit.sh . --notes
  --surface=…` over `agents/spec-master.md`, `skills/`,
  `scripts/resync-vendored-skills.sh`, `docs/adr/`,
  `skills/THIRD-PARTY-NOTICES.md`), with disposition:
  - `unit=251`: "`.claude/agents/spec-master.md:37` … awkward parenthetical
    `run the grill-me (the skill invoked is grilling) session next` —
    source-side wording, out of this unit's scope." → **resolved by this
    plan**; Step 4 deletes that parenthetical entirely.
  - `unit=gh359`: "nothing asserts a `skills:` entry names a real skill.
    Fix would be one loop in `tests/validate.sh` over every `agents/*.md`
    `skills:` line asserting each `antislop:<x>` has a
    `skills/<x>/SKILL.md`." → **adopted** into Step 4 (it is the only
    mechanical guarantee this plan's central wiring claim is real).
    Verified today that all 15 current `antislop:<x>` references across
    the 6 personas resolve, so the loop is green pre-change and
    non-vacuous post-change.
  - `unit=245-CF1`: ADR-0012:33's "five skills descended from this
    decision" phrasing "invites the question" because `REPOINT_SKILLS`
    also holds `code-review`. → **not fixed here**; ADR bodies are not
    rewritten in this repo (see Risk R5). ADR-0031 states the new set size
    plainly instead.
  - `unit=readme-lean-rewrite` (`NOTE[spec]`): `README.md:122-123` still
    tells the reader to run `npx skills@latest add mattpocock/skills`,
    contradicting `README.md:213-215`. Pre-existing, unrelated to this
    change. → **out of scope, recorded** (Risk R6); Step 3 touches only
    line 225's count.
  - `unit=gh404`: the stale "Cap at 2 FAILs … spawns spec-master"
    contradiction across mirrors. → unrelated surface, **out of scope**.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-11 User interaction flow: Q When `grill-with-docs` resolves a
  term or a decision during a `spec-master` grilling session, does
  `spec-master` itself write `CONTEXT.md` and `docs/adr/`, or does it draft
  and hand off to `scribe`? → A **OPEN — see Open Question 1.** The user
  settled *where* the writes target (this repo's real `CONTEXT.md` +
  `docs/adr/`), not *who holds the pen*; `agents/scribe.md` and ADR-0003
  currently give `scribe` exclusive custody, and ADR numbering collides
  across concurrent authors. Recommended default carried through this plan:
  `spec-master` writes `CONTEXT.md` glossary entries directly, and *drafts*
  ADRs into the plan document for `scribe` to number and land.
- 2026-09-11 User interaction flow: Q Should `antislop:grilling` be
  replaced by, or supplemented with, `antislop:grill-with-docs` on
  `spec-master`'s `skills:` line? → A (self-resolved): **supplemented**, and
  `antislop:domain-modeling` added alongside. `grill-with-docs`'s entire
  body is `Run a /grilling session, using the /domain-modeling skill.`, so
  both referents must be loadable for the pivot to mean anything;
  preloading all three resolves the delegation with zero extra `Skill`
  calls. Cost is negligible — `grill-with-docs` is 1 body line and
  `domain-modeling/SKILL.md` is 3,628 bytes. (The user explicitly delegated
  this decision to me.)
- 2026-09-11 Edge cases / failure handling: Q What happens to the four
  other `grill-me` references in `agents/spec-master.md` (lines 39-41, 143,
  183) and to the byte-identical sentence in
  `skills/ubiquitous-language/SKILL.md:62`? → A (self-resolved): all are
  repointed in the same unit. `grep -c 'grill-me' agents/spec-master.md` →
  0 is a Step 4 criterion, so a partial repoint cannot pass.
- 2026-09-11 Edge cases / failure handling: Q Does `agents/milestone-auditor.md:24`'s
  `grill-me` (the skill invoked is grilling)` parenthetical need the same
  edit? → A (self-resolved): **no.** After the un-flagging its statement is
  still literally true — `milestone-auditor`'s own `skills:` line declares
  only `antislop:grilling`, so `grilling` remains the skill it invokes.
  Editing it would be unrequested scope and would force a second
  version-stamped file into Step 4. Recorded as Risk R4.
- 2026-09-11 Technical constraints & tradeoffs: Q Which ADR number, and
  does ADR-0012's body table get rewritten? → A (self-resolved): **0031**
  (highest existing is 0030; the 0007 hole is not free — it is linked from
  `CONTEXT.md`). ADR-0012's body is **not** rewritten; the correction rides
  on a `## Related` `Amended by ADR-0031` bullet plus a `Status:` note,
  exactly the pattern ADR-0005↔ADR-0012 and ADR-0004↔ADR-0006 already use,
  and exactly the phrasing ADR-0005 used for its own now-false sentence
  ("was true when written … but has since been …").
- 2026-09-11 Technical constraints & tradeoffs: Q The `2 of 17 skills`
  count in `CONTEXT.md:935` and `docs/adr/0022-*.md:5` becomes false at 18.
  Fix both, one, or neither? → A (self-resolved): reword **`CONTEXT.md`
  only**, dropping the brittle absolute count rather than incrementing it;
  leave ADR-0022's body untouched as a dated decision record, per the same
  non-rewrite convention as above. This removes the two-copy disagreement
  by removing the count from the live surface, rather than creating a
  second number to keep in sync.
- 2026-09-11 Technical constraints & tradeoffs: Q Should `tests/validate.sh`
  gain the `skills:`-resolves-to-a-real-skill loop? → A (self-resolved):
  **yes**, per the `unit=gh359` note. Without it this plan's central claim
  (`spec-master` now loads `grill-with-docs`) has no standing check, and a
  one-character typo in the frontmatter would ship green. Measured today:
  all 15 current references resolve, so the loop is green pre-change.
- 2026-09-11 Terminology consistency: Q Does the request's vocabulary
  diverge from `CONTEXT.md`? → A (self-resolved): one lens-2 finding
  (advisory). The request's **"auto-fire"** is a new synonym for concepts
  the glossary already defines — `CONTEXT.md:1027` **`disable-model-invocation`
  flag** ("entirely unreachable … in all modes") and `CONTEXT.md`
  **Preloaded skill**. This plan therefore uses *model-invocable* /
  *reachable in every mode* / *preloaded* throughout and never "auto-fire"
  outside the Goal's parenthetical. Lens 1: none found. Lens 3:
  **`grill-with-docs`** itself is a load-bearing new term with no glossary
  entry — Step 3 mints one.

## Risks / dependencies

- **R1 (highest — recurring, twice-FAILed class).** Step 4 edits a
  version-stamped file. Per constitution §3 *and*
  `.claude/reviewed/grilling-fix-1.fail`, the same commit must bump
  `.claude-plugin/plugin.json` **and** `package.json`, add the CHANGELOG
  entry, and regenerate mirrors with `node bin/cli.js --update
  --force-render` — never plain `--update`, which short-circuits at
  `bin/cli.js:1269`/`:1359` when `pluginVersion === version` and silently
  propagates nothing. Verification must run in a **pristine detached
  worktree at the unit's own commit**, because `buildF2GitFixture` copies
  the live repo root including uncommitted files and will report a false
  PASS in place.
- **R2 (scope hazard, pre-authorized).** `bin/cli.js` rewrites the *whole*
  `fileHashes` map and re-stamps every mirror on a version bump. Step 4's
  commit will therefore touch all ten `.claude/agents/*.md`,
  `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`,
  `.claude/protocol-digest.md` and `.claude/persona-config.json` even
  though only `spec-master` changed substantively. **This is expected and
  pre-authorized**; the commit message must say so. A reviewer must not
  FAIL the unit for those hunks.
- **R3 (behavioural, accepted by the user's own request).** Once both are
  un-flagged, `grill-me` ("A relentless interview to sharpen a plan or
  design.") and `grill-with-docs` ("A relentless interview to sharpen a
  plan or design, which also creates docs (ADR's and glossary) as we go.")
  are two model-invocable skills with near-identical descriptions. Nothing
  prevents the harness from selecting `grill-me` when the user says "grill
  me", yielding interrogation with no docs side effect. The descriptions
  **cannot** be disambiguated locally: both files are drift-tracked, and
  `fm-noflag` reconstructs the upstream description byte-for-byte, so any
  edit to a description turns `--check` red. The only mitigation available
  is `spec-master`'s prose naming `grill-with-docs` explicitly (Step 4) —
  which is why the pivot is a prose change and not merely a frontmatter
  change. Recorded in ADR-0031's Consequences.
- **R4.** `agents/milestone-auditor.md:24`'s "(the skill invoked is
  grilling)" parenthetical was authored (`CHANGELOG.md:161`) on the
  rationale that "`grill-me` is a disabled, non-invocable pointer". That
  *rationale* dies here even though the *sentence* stays true. Deliberately
  not edited (see Clarifications); ADR-0031 records the now-stale rationale
  so a future reader does not mistake the sentence for a live claim about
  reachability.
- **R5.** ADR-0012's asymmetry table (`docs/adr/0012-*.md:36-44`) will
  contain a row that is false after Step 1 (`grill-me | no — still flagged
  | fm (byte-verbatim) | yes`). This is accepted, not fixed: this repo does
  not rewrite ADR bodies. Step 2's `Amended by ADR-0031` bullet must name
  that specific row so the falsity is discoverable from the file itself.
- **R6.** `README.md:122-123` tells the reader to run `npx skills@latest
  add mattpocock/skills`, contradicting `README.md:213-215`. Pre-existing
  (recorded in `readme-lean-rewrite`'s `NOTE[spec]`), untouched here.
- **R7.** Step 1's acceptance depends on network egress to
  `raw.githubusercontent.com`. `--check` distinguishes fetch failure
  (exit 2) from drift (exit 1); an exit 2 is **not** a pass and **not** a
  FAIL — it means re-run. Measured working today.
- **R8.** `spec-master` carries `maxTurns: 40`. Folding a
  `domain-modeling` pass into every grilling session consumes turns that
  previously went to planning. No evidence yet that 40 is insufficient, so
  no change is proposed; flagged so a later cutoff is diagnosed as this and
  not as a persona defect.
- **Dependency order is strict**: 1 → 2 → 3 → 4. Step 4's new merge-gate
  loop fails unless `skills/grill-with-docs/SKILL.md` already exists
  (Step 1). Step 3's glossary entry links ADR-0031 (Step 2).

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the pinned upstream file was
  fetched and byte-counted, `--check` was run to establish an exit-0
  baseline, the 15-reference `skills:` resolution sweep was executed, and
  every criterion below names a command whose pre-change value was
  measured.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 4 regenerates mirrors and `fileHashes` via `bin/cli.js --update
  --force-render`; the "Do NOT touch" list bars hand-editing any `.claude/`
  mirror or `fileHashes` entry.
- P3 "Version-stamp discipline": satisfied — Step 4 is the only step
  touching a version-stamped file (`agents/spec-master.md`) and it carries
  the bump + CHANGELOG entry in the same commit. Steps 1-3 touch
  `skills/`, `scripts/`, `docs/`, `README.md` and `CONTEXT.md`, none of
  which is version-stamped, so no bump is due for them and none is
  proposed (deliberate, per ADR-0024's ceremony reduction).
- P4 "Optional personas degrade gracefully": satisfied — `spec-master` is
  an optional persona and all prose added by this plan lives inside
  `agents/spec-master.md` itself; the `CONTEXT.md` and ADR text added in
  Steps 2-3 refers to `spec-master` and `scribe` conditionally.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step
  carries `bash tests/validate.sh` exit 0, and Step 4 strengthens the gate
  itself with the `skills:`-resolution loop.

## Steps

### Step 1 — Vendor `grill-with-docs`, convert `grill-me` to `fm-noflag`, teach the drift script (unit `gwd-1`)

Affected files: `skills/grill-with-docs/SKILL.md` (new),
`skills/grill-me/SKILL.md`, `scripts/resync-vendored-skills.sh`,
`skills/THIRD-PARTY-NOTICES.md`.

The THIRD-PARTY-NOTICES row rides in this unit rather than Step 3 because
attribution is a licensing obligation that should not lag the vendored
bytes, and because the new file's own provenance header points at that
table.

Acceptance criteria: see the `gwd-1` dispatch contract below.

### Step 2 — ADR-0031 and the reciprocal amendment on ADR-0012 (unit `gwd-2`)

Affected files: `docs/adr/0031-grill-with-docs-model-invocable.md` (new),
`docs/adr/0012-vendored-skill-declared-deviations.md` (`Status:` line and
`## Related` bullet only).

Acceptance criteria: see the `gwd-2` dispatch contract below.

### Step 3 — Runbook, README and CONTEXT.md bookkeeping (unit `gwd-3`)

Affected files: `docs/maintenance/resync-vendored-skills.md`, `README.md`,
`CONTEXT.md`.

Acceptance criteria: see the `gwd-3` dispatch contract below.

### Step 4 — Pivot `spec-master`, harden the merge gate, bump, regenerate (unit `gwd-4`)

Affected files: `agents/spec-master.md`,
`skills/ubiquitous-language/SKILL.md`, `tests/validate.sh`,
`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, and the
generated set (`.claude/agents/*.md`, `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`,
`.claude/persona-config.json`).

Acceptance criteria: see the `gwd-4` dispatch contract below.

## Open Questions

**OQ1 — Who holds the pen when `grill-with-docs` produces docs?**
`grill-with-docs` delegates to `domain-modeling`, whose instructions say
"update `CONTEXT.md` right there" and "offer to create an ADR". But
`agents/scribe.md` is this repo's declared "keeper of institutional
knowledge — maintains the wiki, `CONTEXT.md`, and ADRs", it *already*
preloads `antislop:domain-modeling`, and ADR-0003 splits these
responsibilities on purpose. After this change two personas hold the same
docs-writing skill. ADR numbering is the concrete hazard: numbers are
allocated by "highest + 1" with no locking, so a `spec-master` minting an
ADR mid-grill while a `scribe` unit is in flight produces a collision (a
recorded failure mode — sibling specs have collided on ADR numbers here
before).

Options:
- **(b) — recommended default, carried through this plan.** `spec-master`
  writes `CONTEXT.md` glossary entries directly during grilling (cheap,
  additive, low collision risk), but only *drafts* ADRs into the plan
  document's Context/Constitution-check section, leaving numbering and
  landing to `scribe`. Preserves ADR-0003's split where it is load-bearing
  and relaxes it where it is not.
- (a) `spec-master` writes both directly, including numbered ADRs. Maximum
  fidelity to upstream `domain-modeling`; accepts the numbering-collision
  risk and the erosion of `scribe`'s custody.
- (c) `spec-master` writes neither; it drafts both into the plan document
  and `scribe` lands them. Safest for ADR-0003, but reduces
  `grill-with-docs` to `grilling` plus note-taking, which is arguably not
  what was asked for.

Impact if unanswered: exactly one ordered edit in the `gwd-4` contract
(edit 4.7, marked `[OQ1]`) and one sentence of ADR-0031's Consequences.
Everything else in this plan is unaffected. The plan is dispatchable as-is
under (b).

## Self-check

- CHK1: Is the exact expected byte content of `skills/grill-with-docs/SKILL.md`
  determined by the plan, rather than left for the implementer to guess? —
  PASS (the `gwd-1` contract inlines it verbatim, and the 245-byte upstream
  source plus the reconstruction rule are both stated).
- CHK2: Does the plan state that converting `grill-me` to `fm-noflag`
  changes the provenance **header text** as well as deleting the flag
  line? — FAIL (missing, first draft) — revised in place (Context bullet 4
  and ordered edit 1.2 now both state it, including the ASCII `(c)` / `-`
  substitution).
- CHK3: Do Steps 1 and 3 agree on how many skills the drift script
  byte-diffs after the change? — PASS (9 in both; criterion C3.7 asserts
  the runbook's stated count equals `grep -c ':fm-noflag:'`-derived reality
  rather than restating a literal).
- CHK4: Is every acceptance criterion machine-checkable — a command with a
  pass/fail? — PASS (each criterion in all four contracts is a command
  plus an expected exit code or an expected numeric value; no "works
  correctly" criteria).
- CHK5: Is the plan's claim that no test asserts `spec-master`'s prose
  supported by a stated measurement rather than an assumption? — PASS
  (Context records the `grill` sweep over `tests/ hooks/ scripts/ bin/
  adapters/ templates/ commands/`, whose only hit is
  `scripts/resync-vendored-skills.sh`).
- CHK6: For the categories scored Partial, does the plan say what happens
  if the interrogation side effect collides with `scribe`'s ownership? —
  FAIL (missing, first draft) — converted to Open Question 1.
- CHK7: Do the criteria distinguish "the doc mentions the thing" from "the
  doc's claim is true"? — FAIL (ambiguous, first draft: Step 3 originally
  used `grep -q` membership checks, the exact shape that let
  `gh-286-docs` ship false prose) — revised in place; Step 3's criteria are
  now derived counts and cross-file agreement checks.
- CHK8: Does the plan state, for each criterion that could pass vacuously,
  how vacuity is disproved? — PASS (C1.5 and C4.6 are explicit mutation
  proofs with both exit codes required in the ready-for-review packet;
  C1.4's `[OK]` count changes 8 → 9, which a merely-present file would not
  move).
- CHK9: Is the version-bump/mirror obligation attached to the one step
  that triggers it, and stated as a same-commit requirement? — PASS (R1,
  constitution check P3, and the `gwd-4` contract all say same-commit, name
  `--force-render`, and require pristine-worktree verification).
- CHK10: Does any step's "Do NOT touch" list contradict a criterion in the
  same step? — PASS (checked pairwise; in particular `gwd-4` does **not**
  forbid the `.claude/` mirrors it is required to regenerate, it forbids
  only *hand-editing* them — the exact distinction that made `gh403`'s
  criterion unsatisfiable).
- CHK11: Does every numeric threshold in an acceptance criterion match the
  measured pre-change value of the command that produces it? — FAIL
  (conflicting, first draft: C4.3 assumed five `grill-me` occurrences in
  `agents/spec-master.md`; the measured value is six) — revised in place.
  All other thresholds were executed against HEAD `23b0fb4` and returned
  their stated baselines: runbook table 11, NOTICES rows 11, `fm-noflag`
  rows 2, stale-count sweep 5, README `11 skills` 1, `skills/*/` dirs 17,
  `8 verbatim` 2, non-`v0.31.70` stamps 0, `--check` exit 0.

## Scribe update hint

On completion, `scribe` should record: the `grill-with-docs` glossary entry
(minted in Step 3, so verify rather than re-mint); a `CONTEXT.md` note that
the `fm-noflag` set is now four skills, superseding the "grill-me is the
control" framing; the ADR-0031 ↔ ADR-0012 amendment pair; and, if OQ1
resolves to (a) or (b), a `CONTEXT.md` entry recording the new
`spec-master` / `scribe` boundary for glossary and ADR authorship. The
wiki's `dependencies.md:21` vendored-skill list also needs
`grill-with-docs` appended.

---

# Dispatch contracts (fast path, 4 units)

## Unit: gwd-1

### Objective
Vendor upstream `grill-with-docs` as a `fm-noflag` declared deviation,
convert the existing `grill-me` from byte-verbatim `fm` to `fm-noflag`, and
teach `scripts/resync-vendored-skills.sh` to drift-check both — so that
after this unit the drift script byte-diffs **9** skills, all `[OK]`, and
neither grill skill carries `disable-model-invocation`.

### Retrieval
`docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`
(this document) is the canonical and authoritative source. There is no
tracker issue for this unit. Read `docs/adr/0012-vendored-skill-declared-deviations.md`
and `docs/maintenance/resync-vendored-skills.md` §"Vendored file shapes"
before editing.

### Affected files
- `skills/grill-with-docs/SKILL.md` (new)
- `skills/grill-me/SKILL.md`
- `scripts/resync-vendored-skills.sh`
- `skills/THIRD-PARTY-NOTICES.md`

### Ordered edits
**1.1** Create `skills/grill-with-docs/SKILL.md` with exactly this content
(4 elements: frontmatter without the flag, the ASCII `fm-noflag` provenance
header immediately after the closing `---`, a blank line, the one-line
body; file ends with a single newline):

```
---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
---
<!-- Vendored from mattpocock/skills skills/engineering/grill-with-docs/SKILL.md @ e9fcdf95b402d360f90f1db8d776d5dd450f9234, with the upstream model-invocation block removed so antislop personas can load it (see docs/maintenance/resync-vendored-skills.md). MIT (c) 2026 Matt Pocock - see skills/THIRD-PARTY-NOTICES.md. -->

Run a `/grilling` session, using the `/domain-modeling` skill.
```

Do not hand-type the body from this document — the authoritative bytes are
what `check_one_file()` reconstructs. If C1.3 disagrees, `diff` your file
against the script's own reconstruction rather than adjusting the criterion.

**1.2** Edit `skills/grill-me/SKILL.md`, **two** changes, both required:
(a) delete the `disable-model-invocation: true` line from the frontmatter;
(b) replace the provenance header line with the `fm-noflag` variant — note
this is not a suffix append, the whole line changes, and the `fm-noflag`
header uses ASCII `(c)` and `-` where the `fm` header uses `©` and `—`:

```
<!-- Vendored from mattpocock/skills skills/productivity/grill-me/SKILL.md @ e9fcdf95b402d360f90f1db8d776d5dd450f9234, with the upstream model-invocation block removed so antislop personas can load it (see docs/maintenance/resync-vendored-skills.md). MIT (c) 2026 Matt Pocock - see skills/THIRD-PARTY-NOTICES.md. -->
```

**1.3** In `scripts/resync-vendored-skills.sh`, change the `grill-me` row
in `FILES` from `grill-me:fm:` to `grill-me:fm-noflag:` and add, directly
after it:
`grill-with-docs:fm-noflag:skills/grill-with-docs/SKILL.md:skills/engineering/grill-with-docs/SKILL.md`

**1.4** Add `grill-with-docs` to `SKILL_ORDER` (line 59), keeping its
position consistent with its `FILES` position. Omitting this is exit 2, not
a silent pass — the parallel-list safety net at :131-139 catches it.

**1.5** Add the missing `fm-noflag` line to the type legend at :38-40:
`#       fm-noflag = as fm, but the upstream disable-model-invocation line is`
`#                   stripped from the expected content before diffing (ADR-0012)`

**1.6** Replace every "8 verbatim skills" / "8 verbatim vendored skills"
phrase with a count-free or corrected phrase: the usage block at :8-11 and
the `DRIFT DETECTED` message at :169. Recommended wording: "the 9
drift-tracked skills". There must be zero occurrences of `8 verbatim` left.

**1.7** In `skills/THIRD-PARTY-NOTICES.md`, append a row `| 12 |
\`grill-with-docs\` | \`skills/engineering/grill-with-docs\` |` to the
vendored-skills table, and rewrite the deviation sentence at :30 so it
names all four flag-stripped skills (`handoff`,
`improve-codebase-architecture`, `grill-me`, `grill-with-docs`) instead of
the current two. Leave the repoint sentence and the MIT text untouched.

### Do NOT touch
`agents/`, `.claude/` (any file), `docs/` (any file — the runbook and ADRs
belong to units gwd-2 and gwd-3), `README.md`, `CONTEXT.md`,
`CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`,
`tests/validate.sh`, any `skills/*` directory other than `grill-me` and
`grill-with-docs`, and the pinned SHA (this is not a re-pin).

### Acceptance criteria
- **C1.1** `test -f skills/grill-with-docs/SKILL.md` → exit 0.
- **C1.2** `grep -c '^disable-model-invocation' skills/grill-me/SKILL.md
  skills/grill-with-docs/SKILL.md` → `0` for both files.
- **C1.3** `bash scripts/resync-vendored-skills.sh --check` → **exit 0**.
  (Baseline measured 2026-09-11 at HEAD `23b0fb4`: exit 0 with 8 `[OK]`.
  Exit **2** means an upstream fetch failed — re-run; it is neither a pass
  nor a FAIL. Exit 1 is genuine drift.)
- **C1.4** `bash scripts/resync-vendored-skills.sh | grep -c '^\[OK\] '` →
  **9** (was 8). This is what proves the new skill is actually diffed
  rather than merely present on disk.
- **C1.5 (mutation proof, both exit codes must be reported in the
  ready-for-review packet).** Temporarily re-insert
  `disable-model-invocation: true` into `skills/grill-me/SKILL.md`, run
  `bash scripts/resync-vendored-skills.sh --check` → must be **exit 1**;
  revert and re-run → must be **exit 0**. Without this, C1.3 cannot be
  distinguished from a vacuous pass.
- **C1.6** `grep -c '8 verbatim' scripts/resync-vendored-skills.sh` → `0`.
- **C1.7** `grep -c ':fm-noflag:' scripts/resync-vendored-skills.sh` → `4`.
- **C1.8** The NOTICES table has 12 data rows:
  `grep -cE '^\| [0-9]+ \| `' skills/THIRD-PARTY-NOTICES.md` → `12`.
- **C1.9** The NOTICES deviation sentence names all four: for each of
  `handoff`, `improve-codebase-architecture`, `grill-me`,
  `grill-with-docs`, `grep -c "<name>" skills/THIRD-PARTY-NOTICES.md` ≥ 1
  **and** all four appear within the same sentence — verify by reading the
  rewritten sentence and quoting it in the packet.
- **C1.10** `bash tests/validate.sh` → exit 0 (its `skills/*/SKILL.md`
  frontmatter loop must accept the new file).
- **C1.11** `git status --porcelain` after commit → zero lines; the commit
  touches exactly the 4 files listed above
  (`git show --name-only --format= HEAD | sort` to confirm).

### Pre-resolved context
- The upstream file at the pinned SHA is 245 bytes and was fetched and
  verified on 2026-09-11; its body is a single line. It ships with
  `disable-model-invocation: true`, which is why `fm-noflag` applies.
- The reconstruction the script performs for `fm-noflag` is: insert the
  header immediately after the closing frontmatter `---` (awk, :83-87),
  then delete `^disable-model-invocation: true$` from the *expected*
  content (sed, :88). Your local file must equal that result.
- `protectedPaths` is `[]` and no `fileHashes` entry starts with `skills/`,
  so `Write`/`Edit` on these paths is not gated and no mirror regeneration
  is owed by this unit.
- `.claude/skills/` mirrors only `install-antislop` and `coding-discipline`
  (`bin/cli.js:2380-2381`); it is **not** a mirror of the vendored set. Do
  not create `.claude/skills/grill-with-docs/`.
- No test asserts a skill count or a skill-name list, so C1.4 is the only
  count guard in this unit.

### Escalation
If `--check` reports drift on a skill this unit did not touch, stop — that
is pre-existing content drift (the runbook calls it "a content defect in
whichever step vendored it, not something to silence in the script") and is
out of this unit's scope. Report it rather than editing the script to
exclude it. If the `fm-noflag` header reconstruction cannot be made to
match, report the exact `diff` output; do not relax C1.3 or move the skill
into `REPOINT_SKILLS`.

---

## Unit: gwd-2

### Objective
Record, as a new ADR, the reversal of ADR-0012's "`grill-me` is the
control … deliberately left alone" decision, and attach the reciprocal
`Amended by ADR-0031` marker to ADR-0012 using this repo's established
amendment convention.

### Retrieval
`docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`
(this document). Read `docs/adr/0012-vendored-skill-declared-deviations.md`
in full, plus ADR-0005's `Status:` line and `## Related` bullet and
ADR-0004's `## Related` bullet — those two are the amendment-convention
exemplars to copy.

### Affected files
- `docs/adr/0031-grill-with-docs-model-invocable.md` (new)
- `docs/adr/0012-vendored-skill-declared-deviations.md`

### Ordered edits
**2.1** Create `docs/adr/0031-grill-with-docs-model-invocable.md` with the
repo-standard shape: `# ADR 0031: <title> (amends ADR-0012)`, `Date:
2026-09-11`, `Status: Accepted (amends ADR-0012; does not supersede it)`,
then `## Context`, `## Decision`, `## Consequences`, `## Related`.

**2.2** `## Context` must state: ADR-0012 placed `grill-me` in the
byte-verbatim `fm` class as the deliberate control, and `grill-with-docs`
was never vendored at all; `spec-master`'s interrogation step is being
pivoted onto `grill-with-docs` so that grilling produces glossary/ADR side
effects, which is impossible while the skill carries
`disable-model-invocation` (that flag removes a skill from context in every
mode, `CONTEXT.md:1027`); and the operator additionally asked for
`grill-me` itself to be model-invocable.

**2.3** `## Decision` must state: `grill-with-docs` is vendored as a
`fm-noflag` declared deviation, `grill-me` is converted from `fm` to
`fm-noflag`, and the `fm-noflag` set is therefore **four** skills —
`handoff`, `improve-codebase-architecture`, `grill-me`,
`grill-with-docs` — all still byte-diffed by `--check`. State explicitly
that ADR-0012's *mechanism* is unchanged and is being applied, not
replaced; only its per-skill asymmetry is amended.

**2.4** `## Consequences` must record, at minimum: (a) the description
collision between `grill-me` and `grill-with-docs` and why the descriptions
cannot be disambiguated locally (both are drift-tracked; `fm-noflag`
reconstructs the upstream description byte-for-byte), with
`spec-master`'s prose as the only available mitigation; (b) that
`agents/milestone-auditor.md:24`'s "(the skill invoked is grilling)"
parenthetical remains *true* but its original rationale
(`CHANGELOG.md:161`, "`grill-me` is a disabled, non-invocable pointer") no
longer holds; (c) that ADR-0012's `to-spec`/`to-tickets` never-diffed blind
spot is untouched by this ADR; (d) [OQ1-dependent, one sentence] the
`spec-master` ↔ `scribe` boundary now that both personas hold
`domain-modeling`.

**2.5** `## Related` must link ADR-0012, ADR-0005, ADR-0003, this plan
document, and `docs/maintenance/resync-vendored-skills.md`.

**2.6** In `docs/adr/0012-*.md`, extend the `Status:` line (line 4) to read
`Status: Accepted (amended by ADR-0031)` — matching ADR-0005's line-4
pattern.

**2.7** In `docs/adr/0012-*.md`'s `## Related`, append a bullet beginning
`- **Amended by ADR-0031:**` that (i) names the specific table row now
false — the `| \`grill-me\` | no — still flagged | \`fm\` (byte-verbatim) |
yes |` row at :42 and the "grill-me is the control" sentence at :53-54 —
(ii) states it was true when written (2026-08-07) and has since been
reversed, and (iii) states the ADR's mechanism itself stands. Copy
ADR-0005's `## Related` phrasing as the template. **Do not edit the table
or the Decision prose** — this repo records ADR corrections by annotation,
never by rewriting the body.

### Do NOT touch
`docs/adr/0012-*.md`'s `## Context`, `## Decision` (including the
asymmetry table), and `## Consequences` sections; any other ADR;
`skills/`, `scripts/`, `agents/`, `.claude/`, `CHANGELOG.md`,
`CONTEXT.md`, `README.md`, `package.json`,
`.claude-plugin/plugin.json`.

### Acceptance criteria
- **C2.1** Exactly one file matches `docs/adr/0031-*.md`
  (`ls docs/adr/0031-* | wc -l` → `1`), and no other ADR file begins with
  `0031`.
- **C2.2** `grep -cE '^## (Context|Decision|Consequences|Related)$'
  docs/adr/0031-*.md` → `4`; `grep -qE '^Date: 2026-09-11$'` → exit 0;
  `grep -qE '^Status: ' docs/adr/0031-*.md` → exit 0.
- **C2.3** ADR-0031 names all four `fm-noflag` skills: for each of
  `handoff`, `improve-codebase-architecture`, `grill-me`,
  `grill-with-docs`, `grep -q "<name>" docs/adr/0031-*.md` → exit 0.
- **C2.4** ADR-0031 confronts the superseded framing rather than merely
  restating the new state: `grep -qi 'control' docs/adr/0031-*.md` → exit
  0, and the matching sentence must reference ADR-0012 (quote it in the
  packet).
- **C2.5** `grep -q 'Amended by ADR-0031'
  docs/adr/0012-vendored-skill-declared-deviations.md` → exit 0.
- **C2.6** `sed -n '4p' docs/adr/0012-vendored-skill-declared-deviations.md
  | grep -q 'ADR-0031'` → exit 0.
- **C2.7** ADR-0012's body is unmodified apart from line 4 and the
  appended `## Related` bullet: `git diff HEAD~1 -- docs/adr/0012-*.md`
  must show **no** deletions other than the old line 4, and must not touch
  any line between the `## Context` and `## Related` headings. Verify with
  `git diff --stat` plus a read of the hunk; quote it in the packet.
- **C2.8** `bash tests/validate.sh` → exit 0.
- **C2.9** `git status --porcelain` after commit → zero lines; commit
  touches exactly 2 files.

### Pre-resolved context
- **ADR number is 0031.** Highest existing is `0030-dashboard-decision-surface-...`.
  The `0007` gap is **not** free — `CONTEXT.md` links it. Do not backfill.
  Re-derive the number at execution time (`ls docs/adr/`) in case a sibling
  unit landed one first; if `0031` is taken, take the next free number and
  say so in the packet rather than overwriting.
- The amendment convention in this repo is exactly two artifacts: a
  `Status:` parenthetical on the amended ADR and an `Amended by ADR-NNNN`
  bullet in its `## Related`. Precedents: ADR-0004→0006, ADR-0005→0012,
  ADR-0006→0009, ADR-0010→0026.
- ADR-0005's own `## Related` contains the template sentence for "this was
  true when written but has since changed" — reuse its shape.
- No test asserts ADR filenames, numbering, or headings, so C2.1/C2.2 are
  this unit's only structural guards.

### Escalation
If ADR-0012's asymmetry table looks like it *must* be corrected for the
record to be coherent, stop and report rather than editing it — that would
contradict this repo's non-rewrite convention and is a plan-level decision,
not an implementation one.

---

## Unit: gwd-3

### Objective
Bring the human-facing vendoring documentation back into agreement with
reality after unit `gwd-1`: the runbook's table and counts, README's
credit line, and `CONTEXT.md`'s glossary (including a new
`grill-with-docs` entry and the now-false npm count).

### Retrieval
`docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`
(this document). Depends on `gwd-1` (the script must already list 9
skills) and `gwd-2` (ADR-0031 must exist to be linked).

### Affected files
- `docs/maintenance/resync-vendored-skills.md`
- `README.md`
- `CONTEXT.md`

### Ordered edits
**3.1** `docs/maintenance/resync-vendored-skills.md:3` — "vendors 11
skills" → "vendors 12 skills".

**3.2** Add a `grill-with-docs` row to the "What's vendored" table
(:12-24): `| \`grill-with-docs\` | \`skills/engineering/grill-with-docs\` |
verbatim (flag stripped) |`. Place it adjacent to the `grill-me` row.

**3.3** Rewrite the paragraph at :26 so it states that the first **9** are
byte-verbatim aside from their provenance header, **with four intentional
deviations** — `handoff`, `improve-codebase-architecture`, `grill-me`,
`grill-with-docs` — all tracked as the `fm-noflag` reconstruction type.

**3.4** Exit-code table at :97 — "all 8 verbatim skills `[OK]`" → "all 9
drift-tracked skills `[OK]`".

**3.5** :105 — "drift on one of the 8 verbatim skills" → "9 drift-tracked
skills". :131 — "across all 11 skills" → "across all 12 skills". :134 —
"`[OK]` for all 8 verbatim skills" → "all 9 drift-tracked skills".

**3.6** `README.md:225` — "— 11 skills vendored first-party" → "— 12
skills vendored first-party". Change nothing else in README.

**3.7** `CONTEXT.md` — add a glossary entry for **`grill-with-docs`
skill** in the same `**Term**:` shape as its neighbours. It must say: a
vendored mattpocock skill whose entire body delegates to `grilling` plus
`domain-modeling`; preloaded by `spec-master` as its interrogation entry
point (unit `gwd-4`); model-invocable because the
`disable-model-invocation` flag is stripped under the `fm-noflag` declared
deviation; and it must link `docs/adr/0031-...`. Cross-link the existing
[[`disable-model-invocation` flag]] and [[Preloaded skill]] entries.

**3.8** `CONTEXT.md:935` — reword the npm-distribution entry to drop the
absolute count: "ships only `skills/coding-discipline` and
`skills/install-antislop`; every other skill is excluded" (the literal
"only 2 of 17 skills" must not survive, and must **not** be replaced with
"2 of 18" — the count is deliberately removed, not incremented).
`docs/adr/0022-*.md`'s identical sentence is a dated decision record and is
**not** edited.

### Do NOT touch
`docs/adr/` (any file), `skills/`, `scripts/`, `agents/`, `.claude/`,
`CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`,
`README.md:122-123` (the pre-existing `npx skills@latest` contradiction —
out of scope, see the plan's R6), and `CONTEXT.md:905-917` (the dated
"Skills-library remediation completed" entry — historical record, left
intact; the new entry supersedes it by addition).

### Acceptance criteria
- **C3.1** The runbook's "What's vendored" table has 12 data rows:
  `awk '/^\| skill \| upstream path \| shape \|/{f=1;next} f&&/^\|---/{next}
  f&&/^\|/{n++} f&&!/^\|/{exit} END{print n+0}'
  docs/maintenance/resync-vendored-skills.md` → `12` (pre-change value:
  `11`).
- **C3.2** No stale counts survive:
  `grep -cE '8 verbatim|all 11 skills|vendors 11 skills'
  docs/maintenance/resync-vendored-skills.md` → `0`.
- **C3.3 (cross-file agreement, not a literal restatement).** The number of
  `fm-noflag` rows in the script equals the number of skills the runbook
  names as deviations: `grep -c ':fm-noflag:' scripts/resync-vendored-skills.sh`
  → `4`, and the runbook's deviation sentence names exactly those same four
  skill names — verify by extracting both lists and quoting them in the
  packet.
- **C3.4** `grep -cE '^- \*\*\[mattpocock/skills\].*— 12 skills' README.md`
  → `1`, and `grep -c '11 skills' README.md` → `0`.
- **C3.5** `grep -q 'grill-with-docs' CONTEXT.md` → exit 0 **and** the
  entry links the ADR: `grep -A8 'grill-with-docs' CONTEXT.md | grep -q
  '0031'` → exit 0.
- **C3.6** `grep -c 'only 2 of 17 skills' CONTEXT.md` → `0` and
  `grep -c '2 of 18 skills' CONTEXT.md` → `0` (the count is removed, not
  incremented), while `grep -c 'only 2 of 17 skills' docs/adr/0022-*.md` →
  `1` (ADR body deliberately unchanged).
- **C3.7 (claim-anchored truth check, not a membership grep).** The
  runbook's stated total must equal reality:
  `test "$(ls -d skills/*/ | wc -l)" -eq 18` and the 12 table rows must
  each name an existing directory — for every skill name in the table,
  `test -d skills/<name>` → exit 0. Report the loop's output.
- **C3.8** `bash scripts/resync-vendored-skills.sh --check` → exit 0 (this
  unit must not disturb `gwd-1`'s green).
- **C3.9** `bash tests/validate.sh` → exit 0.
- **C3.10** `git status --porcelain` after commit → zero lines; commit
  touches exactly 3 files.

### Pre-resolved context
- The runbook's shape column currently uses `verbatim` / `**repointed**`.
  `grill-me` today reads `verbatim`; after `gwd-1` it is flag-stripped, so
  both grill rows should read `verbatim (flag stripped)` — keep the two
  rows consistent with each other.
- `ls -d skills/*/ | wc -l` was **17** before `gwd-1` and is **18** after.
- This repo does **not** rewrite dated historical entries in `CONTEXT.md`
  or in ADR bodies; it supersedes them by adding new entries. That is why
  3.8 rewords a live policy entry but leaves `docs/adr/0022-*.md` alone,
  and why the "Skills-library remediation completed" entry stays.
- Prior FAIL on this exact unit shape: `.claude/reviewed/gh-286-docs.fail`
  — a docs unit passed six membership greps while asserting capabilities
  the tool did not have. The reviewer's own summary: "not one asserts that
  any documented capability corresponds to real behaviour, so the criteria
  set cannot distinguish accurate documentation from confident fiction."
  C3.1/C3.3/C3.7 exist specifically to close that gap; do not substitute
  `grep -q` for them.

### Escalation
If the runbook's "first 8 are byte-verbatim" sentence cannot be rewritten
without also describing the `REPOINT_SKILLS` set (which this unit is not
scoped to change), report the wording problem rather than expanding scope
into the repoint paragraph.

---

## Unit: gwd-4

### Objective
Pivot `spec-master`'s interrogation step from bare `grilling` to
`grill-with-docs`, wire the two supporting skills into its preload line,
add the merge-gate guard that makes the wiring claim checkable, and land
the constitution-§3 obligations (version bump, CHANGELOG, `--force-render`
mirror regeneration) **in the same commit**.

### Retrieval
`docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`
(this document). Depends on `gwd-1` (the skill directory must exist or the
new merge-gate loop fails) and `gwd-3` (the `CONTEXT.md` entry it aligns
with). Read `.claude/reviewed/grilling-fix-1.fail` in full before starting
— it is the last FAIL on this exact file for this exact reason.

### Affected files
- `agents/spec-master.md`
- `skills/ubiquitous-language/SKILL.md`
- `tests/validate.sh`
- `.claude-plugin/plugin.json`, `package.json`
- `CHANGELOG.md`
- Generated, via `bin/cli.js` only: `.claude/agents/*.md` (all ten),
  `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`,
  `.claude/protocol-digest.md`, `.claude/persona-config.json`

### Ordered edits
**4.1** `agents/spec-master.md:8` — replace the `skills:` line with:
`skills: antislop:grill-with-docs, antislop:grilling, antislop:domain-modeling, antislop:to-spec, antislop:fail-triage, antislop:ubiquitous-language`
(`grilling` is **supplemented, not replaced**: `grill-with-docs`'s body
delegates to it by name, as does `domain-modeling`.)

**4.2** `:21` — `before running \`grill-me\` (the skill invoked is
grilling), score the request` → `before running \`grill-with-docs\` (which
runs \`grilling\` and \`domain-modeling\` together), score the request`.

**4.3** `:39-41` — `Carry Partial/Missing categories into \`grill-me\` as
coverage targets — grill-me itself is unchanged; …` → same sentence with
`grill-with-docs` in both positions.

**4.4** `:41-42` — `For any non-trivial task, run the \`grill-me\` (the
skill invoked is grilling) session next` → `For any non-trivial task, run
the \`grill-with-docs\` session next`. This deletes the awkward
parenthetical flagged as a non-blocking note on unit `251`.

**4.5** `:143` — `never blocks progression to \`grill-me\`, \`to-spec\`, or
\`task-master\` handoff` → `grill-with-docs`.

**4.6** `:183` — `it explicitly does not interview the user — that's
\`grill-me\`'s job, already done by this point` → `grill-with-docs`'s.

**4.7 [OQ1]** In the same "Grill before planning" bullet, add **one**
sentence stating what the `domain-modeling` half of `grill-with-docs` does
with its output. Default wording (OQ1 option b):
> `grill-with-docs` also sharpens the domain model as it interrogates:
> when a term is resolved, write the `CONTEXT.md` glossary entry inline;
> when a decision meets `domain-modeling`'s three ADR tests, draft the ADR
> into this plan's Context section and leave numbering and landing to
> `scribe`, whose custody of `docs/adr/` is unchanged.

If OQ1 resolves to (a), replace the second clause with direct ADR
authorship; if (c), with "draft both into the plan document for `scribe`".

**4.8** `skills/ubiquitous-language/SKILL.md:62` — `block progression to
\`grill-me\`, \`to-spec\`, or \`task-master\` handoff` → `grill-with-docs`.
(Keeps the skill and the persona saying the same thing; this file is
first-party, not vendored, so it is not drift-checked.)

**4.9** `tests/validate.sh` — add a check section, in the same style as the
existing `== skill frontmatter has name: and description: ==` block:
for every `agents/*.md` with a `skills:` frontmatter line, every
`antislop:<x>` token must have a matching `skills/<x>/SKILL.md`; print
`OK`/`FAIL` per token and set `fail=1` on a miss. (Measured 2026-09-11: all
15 current tokens across 6 personas resolve, so this is green before the
change too.)

**4.10** Bump `.claude-plugin/plugin.json` **and** `package.json` from
`0.31.70` to `0.31.71`.

**4.11** Add a `CHANGELOG.md` entry under `## [Unreleased]`, in the
established `**0.31.71 — <summary>.**` + `### Changed` shape, covering all
four units of this plan (vendoring, the `fm-noflag` reversal, ADR-0031, the
docs bookkeeping, and this unit's rewiring). Name the pre-authorized
mirror/`fileHashes` regeneration explicitly.

**4.12** Regenerate: `node bin/cli.js --update --force-render`. **Never
plain `--update`** — it short-circuits when `pluginVersion === version` and
will rewrite nothing while reporting success.

**4.13** Commit everything in **one** commit. The message must state that
the whole-`fileHashes`-map rewrite and the re-stamp of every
`.claude/agents/*.md` are expected output of `--force-render`, not
hand-edits.

### Do NOT touch
`agents/milestone-auditor.md` (its "(the skill invoked is grilling)"
parenthetical stays — see plan R4), any other `agents/*.md`,
`skills/grill-me/SKILL.md`, `skills/grill-with-docs/SKILL.md`,
`skills/domain-modeling/`, `skills/grilling/`,
`scripts/resync-vendored-skills.sh`, `docs/adr/`, `README.md`,
`CONTEXT.md`, and `spec-master`'s `maxTurns`/`model`/`tools` frontmatter
fields. Do **not** hand-edit any `.claude/` mirror or any `fileHashes`
entry — regenerating them via `bin/cli.js --force-render` is required and
is not "touching" them in the prohibited sense.

### Acceptance criteria
All of the following are verified in a **pristine detached worktree at this
unit's own commit** (`git worktree add --detach <tmp> <sha>`), never in the
live tree — an uncommitted file in the live root silently turns C4.5 green.
- **C4.1** `grep -c 'grill-me' agents/spec-master.md` → `0`, and
  `grep -c 'grill-me' skills/ubiquitous-language/SKILL.md` → `0`.
- **C4.2** `sed -n '8p' agents/spec-master.md` contains all six of
  `antislop:grill-with-docs`, `antislop:grilling`,
  `antislop:domain-modeling`, `antislop:to-spec`, `antislop:fail-triage`,
  `antislop:ubiquitous-language`.
- **C4.3** `grep -c 'grill-with-docs' agents/spec-master.md` ≥ `6`.
  Derivation: `grep -c 'grill-me' agents/spec-master.md` is **6** at HEAD
  (lines 21, 39, 40, 41, 143, 183 — measured 2026-09-11, note that edit 4.3
  covers three of them), so the expected post-change value is 1 frontmatter
  token + 6 repointed prose occurrences + edit 4.7's new sentence = 8; the
  floor is set at 6 to allow one occurrence to be absorbed by rewording.
- **C4.4 (propagation, the grilling-fix-1 defect).**
  `grep -q 'antislop:grill-with-docs' .claude/agents/spec-master.md` →
  exit 0, and `grep -c 'grill-me' .claude/agents/spec-master.md` → `0`.
  The source edit is worthless if the mirror did not move.
- **C4.5** `bash tests/validate.sh` → exit 0.
- **C4.6 (mutation proof — report both exit codes in the packet).** Change
  `antislop:grill-with-docs` to `antislop:grill-with-docs-typo` in
  `agents/spec-master.md`, run `bash tests/validate.sh` → must be **exit
  1** with a `FAIL` line naming the token; revert → **exit 0**. Without
  this, C4.5 does not distinguish a working guard from an inert one.
- **C4.7 (render fixed point).** In the pristine worktree:
  `node bin/cli.js --update --force-render && git status --porcelain` →
  **zero lines**. Pre-fix this emits several ` M ` lines, so it is
  non-vacuous.
- **C4.8 (version agreement, all four places).** `.claude-plugin/plugin.json`
  `.version` == `package.json` `.version` == `.claude/persona-config.json`
  `.pluginVersion` == `0.31.71`, **and** every `.claude/agents/*.md` stamp
  line reads `antislop v0.31.71` — `grep -h 'antislop v' .claude/agents/*.md
  .claude/persona-protocol.md .claude/protocol-digest.md | grep -vc
  'v0.31.71'` → `0`. (The committed-stamp-with-no-matching-manifest
  mismatch is precisely the second defect in `grilling-fix-1.fail`.)
- **C4.9** `grep -q '0.31.71' CHANGELOG.md` → exit 0, and the entry names
  `grill-with-docs`, `grill-me`, and ADR-0031.
- **C4.10** `bash scripts/resync-vendored-skills.sh --check` → exit 0
  (this unit must not disturb `gwd-1`'s green).
- **C4.11** `git status --porcelain` after commit → zero lines.

### Pre-resolved context
- **Blast radius, measured — do not re-derive.** The only mirror of
  `agents/spec-master.md` is `.claude/agents/spec-master.md`. There is no
  cursor/codex/`templates/` port of persona bodies (adapter ports exist
  only for the protocol, not for persona bodies). No test asserts any
  persona's `skills:` line or `spec-master`'s prose; a `grill` sweep over
  `tests/ hooks/ scripts/ bin/ adapters/ templates/ commands/` returns
  exactly one hit, `scripts/resync-vendored-skills.sh`, which this unit
  does not touch.
- **Why `--force-render` and not `--update`.** `bin/cli.js:1269`/`:1359`
  return early when `config.pluginVersion === version` and the pre-scan
  compares the *stamp*, not the content. The fast path is intermittent —
  it has been observed both no-opping and fully rendering on adjacent
  commits — so a successful plain `--update` on one machine proves
  nothing.
- **`validate.sh` is transitively a mirror-parity check** via
  `tests/cli-backfill.test.js`'s `buildF2GitFixture` (copies the real repo
  root, including uncommitted files) and its C2.12 assertion. That is why
  C4.5 and C4.7 must run in a detached worktree.
- `agents/scribe.md` already preloads `antislop:domain-modeling`; adding it
  to `spec-master` is a second holder, not a move. Do not remove it from
  `scribe`.
- `protectedPaths` is `[]`, so `Write`/`Edit` on `agents/spec-master.md` is
  not gated. If a `Bash` heredoc is needed instead, preserve file modes.
- Expect the commit to carry ~15 generated files beyond the 6 hand-edited
  ones. That is R2, pre-authorized.

### Escalation
If C4.7 cannot reach zero `git status` lines because `fileHashes` entries
belonging to another in-flight unit are being healed, report the specific
entries and stop — do not hand-edit `persona-config.json` to suppress them
(constitution P2). If OQ1 has not been answered when this unit is
dispatched, implement edit 4.7's default wording verbatim and say so in the
ready-for-review packet.
