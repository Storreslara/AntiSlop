# Ceremony-reduction follow-ups: shared-protocol cap paragraph + publish-threshold glossary

Date: 2026-08-16
Status: **FINAL** 2026-08-16 — 2 dispatchable units, below the ≤5 fast-path
threshold, so the nine-element dispatch contracts are emitted directly at the
bottom of this document and `task-master` is not involved. Also below the ≥6
publish threshold, so no tracker `[spec]` issue is filed; **this document is
the retrieval contract**.
Author: `spec-master`.
Origin: two non-blocking reviewer findings left behind by the
`2026-08-15-ceremony-reduction-solo-operator` milestone (umbrella issue #395,
closed; all 5 steps PASSed). Finding 1 is note 1 of
`.claude/reviewed/gh404.pass`; finding 2 is the last advisory bullet of
`.claude/reviewed/gh403.fail`, which Step 5 (`gh405`) was expected to close
and did not.

---

## Goal

Close two documentation-accuracy gaps the ceremony-reduction milestone left
behind, without touching behaviour and without expanding into a broader
protocol audit:

1. **G1** — `templates/persona-protocol.md`'s "Cap at 2 FAILs per unit"
   paragraph must stop asserting the *old* automatic-spawn behaviour, so that
   `.claude/agents/orchestrator.md` no longer carries two contradicting
   statements about the same mechanism in one system prompt.
2. **G2** — `CONTEXT.md`'s glossary must define the **publish threshold**
   term and state its current value (**≥6** dispatchable units), so that half
   of the coupled OQ-3 decision is findable by name.
3. **G3** — the shipped tree must remain green: `bash tests/validate.sh` exits
   0, mirrors are regenerated in the same unit as their source, and
   constitution P3's version-bump/CHANGELOG obligation is met.

Non-goals are enumerated under "Out of scope" so no clause of this Goal is
left unmapped to a criterion (see Self-check CHK1).

---

## Context

### What was verified live (2026-08-16, at `602ca46`)

Everything the relaying brief asserted was re-derived from the tree rather
than trusted. Three of its claims were **wrong or stale** and are corrected
here:

| Brief's claim | Live finding |
|---|---|
| Stale automatic-spawn text present in 7 named files including the two adapters and the prototype | **False for 3 of them.** `git grep -n 'spawns \`spec-master\` to produce a debug spec'` returns exactly **6** hits: `templates/persona-protocol.md:576` (the only source file) and 5 generated mirrors — `.claude/persona-protocol.md:577`, `.claude/agents/{orchestrator:820, lead-programmer:380, spec-master:506, milestone-auditor:328}.md`. `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`, and `prototype/protocol-mcp/rules/continuing-after-fail.md` each already read *"asks how to proceed, rather than spawning a third fix attempt"* — i.e. they are **already correct**, and already in the deferring form this plan adopts. The reviewer's list matched on the `**Cap at 2 FAILs per unit.**` heading string, not on the stale claim. |
| `CONTEXT.md`'s glossary "only documents the fast-path half" | **False.** `CONTEXT.md` has **no glossary entry for either half.** The 100 `**term**:` entries contain neither "fast-path threshold" nor "publish threshold". The value `≤5` appears in `CONTEXT.md` only *inside* the **FAIL routing (post-reviewer)** entry (lines 586-588), as an incidental mention, not a definition. Commit `b94f21e` (Step 5) added four glossary entries — `on-demand milestone audit`, `solo-operator posture`, `parked unit`, `operator` — and neither threshold was among them. |
| Publish threshold "currently stated inline at `agents/spec-master.md` around lines 165/190" | **Correct, and there is a third occurrence the brief did not name, which is stale.** `agents/spec-master.md:164` (`≥6 units` → publish) and `:189` (`Standard path (≥6 units...)`) are current. But `:175` still reads *"For smaller specs (single-milestone, **<3 units**), publishing via `to-spec` is optional."* — a `≤2`/`≥3`-era leftover. See G2-bis below. |

### G1 — why the shared paragraph exists in two places at all

The two documents describe the same mechanism from different vantage points:

- **`agents/orchestrator.md:249-266`** owns the *mechanics* — `AskUserQuestion`,
  the three discrete options (a) debug spec / (b) human-directed re-dispatch /
  (c) park, the marker semantics of each, and the ≤5/≥6 routing of a returned
  debug spec.
- **`templates/persona-protocol.md:573-581`** is the *shared* block, physically
  inlined by `bin/cli.js`'s `inlineProtocolBlock` into the four full-tier
  personas whose `PROTOCOL_SECTIONS_BY_PERSONA` row includes
  `'Continuing after a FAIL verdict'`: `orchestrator`, `lead-programmer`,
  `spec-master`, `milestone-auditor` (verified against `bin/cli.js:594+`).
  Three of those four do not own the mechanics and only need to know the cap
  exists and that a human decides.

**Investigation result on "which is the single source of truth":**
`agents/orchestrator.md` is, and this repo already has a documented convention
for exactly this shape. The `Fourth verdict: escalate-to-human` section states
its own rule verbatim — the heavy-unit trigger is *"defined in one place only
… referenced by pointer, never restated here, so a later amendment cannot
leave two copies disagreeing."* The stale paragraph is a live demonstration of
what happens when that convention is not applied: Step 4 amended one copy and
the other drifted. Independently, the Codex/Cursor/prototype ports **already**
carry the condensed, non-enumerating form, so adopting it in the canonical
template converges four artifacts on one wording instead of creating a fifth.

**Decision: pointer, not duplication.** The shared paragraph is rewritten to
say the orchestrator surfaces the history and asks the human how to proceed,
and to point at the orchestrator's own "At the 2-FAIL cap" section as the sole
definition of the option set. The three options are **not** enumerated in the
shared block. No information is lost for any of the four consumers:

- `spec-master` already carries its own **Debug spec on 2-FAIL-cap escalation**
  bullet (`agents/spec-master.md:204-235`), including the ≤5/≥6 routing.
- `orchestrator` already carries the full mechanics at `:249-266`.
- `lead-programmer` and `milestone-auditor` never acted on the removed detail;
  verified that neither file references "debug spec" anywhere outside the
  inlined protocol block, so no dangling back-reference is created.

### G2 — the glossary gap, and a terminology collision worth recording

Two lenses of `antislop:ubiquitous-language` (prose mode, run against
`CONTEXT.md`) fired on the raw request:

- **Lens 2 (synonym for a defined-elsewhere term).** The concept is spelled
  three ways in the live tree: `publish threshold` (`docs/adr/0024:43,104`),
  `tracker-publish threshold` (`CHANGELOG.md:5,10`; `docs/adr/0024:54`), and
  `publish-threshold` (`docs/adr/0024:115`). The glossary entry must name one
  canonical spelling and record the others as aliases, or it will be the
  fourth variant rather than the resolution.
- **Lens 1 (a term used with a different meaning).** "fast path" is already
  load-bearing in `CONTEXT.md` for something else entirely — `bin/cli.js
  --update`'s **version-match fast path** (`CONTEXT.md:52,77`). A bare
  "fast path" entry would collide. The new entry must disambiguate explicitly.
- **Lens 3 (load-bearing new term, no entry).** Both `fast-path threshold` and
  `publish threshold` — which is the gap this plan closes.

Because the publish threshold's definition is inseparable from its coupling to
the fast-path threshold (OQ-3 raised them together *by design*, and ADR-0024:104
records that moving one **must** move the other), an entry for one that links
to a non-existent entry for the other would ship a dangling `[[...]]` link.
**Decision: two cross-linked entries**, following the existing
`Prose mode` / `Diff mode` precedent in this same glossary — complementary
entries that each name the other. Adding the fast-path entry is not scope
creep; it is the link target the publish entry requires, and `gh403.fail`'s
own closing advisory asked for it by name.

### G2-bis — the stale `<3 units` branch (scope addition, see Open Question 1)

`agents/spec-master.md:175` still says publishing is optional for
`<3 units`. Combined with `:164`'s `≥6 units`, a spec resolving to **3, 4, or
5 units falls into neither branch** — genuinely undefined behaviour in a
persona body. Step 3's own criterion AC3.8 ("no `≥3 units` threshold survives
anywhere in `agents/`") passed **vacuously** against it, because the literal
on disk is `<3 units`, not `≥3 units`.

This is in scope because the glossary entry G2 adds would otherwise state
`≥6` while the source it documents still says `<3` — publishing a glossary
that contradicts its own subject. The corrected text makes the two branches
complementary and exhaustive: `≥6` → publish; `≤5` → optional.

### G3 — the mirror-parity trap that already cost this milestone a FAIL

`.claude/reviewed/gh403.fail` is a durable record that **this exact class of
unit already FAILed once in this milestone.** Its blocking defect: Step 3
edited `agents/*.md` and `templates/persona-protocol.md` without regenerating
the `.claude/` mirrors, which made `node bin/cli.js --update --dry-run` exit
3, which failed `tests/cli-backfill.test.js`, which failed `bash
tests/validate.sh` — the constitution P5 merge gate. The plan's premise that
"validate.sh does not check `agents/` ↔ `.claude/agents/` content parity" was
false; it checks it transitively.

**Consequence for this plan: a source edit and its mirror regeneration are
never split across units.** Unit 1 carries the source edits, the mirror
regeneration, the version bump and the CHANGELOG entry as one atomic unit.
Plain `--update` is insufficient (stamp-not-content fast path);
`--force-render` is required and is named literally in the ordered edits.

---

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-16 Domain entities / data model: Q Should the publish threshold get
  its own glossary entry, or be folded into an existing fast-path entry? →
  A (self-resolved): two cross-linked entries. The brief's premise that a
  fast-path entry already exists is false — neither exists — so "folding in"
  was never available. Two entries follow the glossary's own
  `Prose mode`/`Diff mode` precedent and avoid a dangling `[[...]]` link.
- 2026-08-16 Edge cases / failure handling: Q What happens if the source edit
  lands without regenerating the mirrors? → A (self-resolved): `bash
  tests/validate.sh` goes red via `cli-backfill.test.js`, breaching
  constitution P5. This already happened once in this milestone
  (`gh403.fail`). Mitigated by keeping source + mirror regen in one unit and
  naming `--force-render` literally in the ordered edits.
- 2026-08-16 Technical constraints & tradeoffs: Q Should the shared protocol
  paragraph describe the human-gated flow directly, or defer to the
  orchestrator's own section? → A (self-resolved): defer by pointer, do not
  enumerate. Grounded in three live facts — the repo's own stated anti-drift
  convention in the `Fourth verdict` section, the fact that the three adapter/
  prototype ports already use the deferring form, and the fact that the
  duplicate enumeration is precisely what drifted in the first place.
- 2026-08-16 Terminology consistency: Q Which spelling of the publish-threshold
  term is canonical, and does "fast path" collide with an existing entry? →
  A (self-resolved): canonical is **publish threshold** (ADR-0024's body
  spelling); `tracker-publish threshold` and `publish-threshold` are recorded
  as aliases. "fast path" **does** collide with `--update`'s version-match
  fast path (`CONTEXT.md:52,77`), so the new entry is titled **fast-path
  threshold** and must state the disambiguation explicitly.

---

## Risks / dependencies

- **R1 — prior-FAIL history in this exact area.** `.claude/reviewed/gh403.fail`
  records a FAIL on the sibling unit for the mirror-parity trap described in
  G3 above. **Neither unit of this plan may be dispatched on `haiku`**, and the
  gh403 defect history must be relayed in Unit 1's dispatch. A re-scoped step
  in a known-defect area is not `haiku` work.
- **R2 — the four inlined mirrors are generated, never hand-edited.**
  Constitution P2 forbids hand-editing a file with a script-driven path.
  `.claude/agents/*.md`, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`
  and `.claude/persona-config.json`'s `fileHashes` are all `--force-render`
  output. A unit that edits them directly is a P2 violation even if the
  resulting bytes are identical.
- **R3 — the adapters and the prototype are already correct and must not be
  touched.** Editing them to "match" would regress three artifacts that
  already say the right thing, and would produce a diff the acceptance
  criteria cannot distinguish from the intended one. They are listed under
  `## Do NOT touch`.
- **R4 — `tests/adapter-protocol-parity.test.js` probes the section by header
  string only** (`'Continuing after a FAIL verdict': { probe: 'Continuing after
  a FAIL verdict' }`), and `tests/protocol-doc-drift.test.js` asserts only the
  `## `-delimited section *count*. Neither is disturbed by a within-section
  body edit that adds no heading. Verified empirically: both exit 0 against
  the candidate text.
- **R5 — `bin/cli.js`'s `assertNoDanglingCrossReferences` throws at load** if a
  kept section's text names a header the same persona row drops. The proposed
  replacement quotes `"At the 2-FAIL cap"`, which is **not** a `## `-delimited
  canonical protocol header (it is a paragraph in `agents/orchestrator.md`), so
  the guard does not fire. Verified empirically: `bin/cli.js` loaded and
  `tests/protocol-cross-references.test.js` exited 0 against the candidate text.
- **R6 — deliberately deferred, not missed.** `gh404.pass` note 4 flags
  `agents/orchestrator.md:262` / `CONTEXT.md:589` saying "operator-supplied
  correction" where `:247` / `:894` say "human-directed correction". Left
  alone: Step 5 shipped an `operator` glossary entry declaring it an explicit
  synonym of `human`, which defuses the drift, and fixing it would widen this
  plan into the protocol-wide terminology audit the operator excluded.
  `gh404.pass` notes 2 and 3 (option (b)'s undefined third-FAIL behaviour;
  the loose `AskUserQuestion` invocation spec) are likewise out of scope —
  both are behavioural, not prose-accuracy, gaps.
- **D1 — sequencing.** Unit 2 must land **after** Unit 1. Unit 1 changes
  `agents/spec-master.md`'s below-threshold branch from `<3` to `≤5`; Unit 2's
  glossary entry documents that branch. Landing Unit 2 first would publish a
  glossary that contradicts its own subject for the length of one commit.
  There is no file overlap between them, so the ordering is semantic, not
  mechanical.
- **D2 — no tracker issue exists.** This plan is below the ≥6 publish
  threshold. `scribe`'s issue-closing duty does not fire (it requires an issue
  number in its dispatch) and must not be invented.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every quoted line, line number and
  occurrence count in this plan was re-derived live at `602ca46`, and three of
  the relayed brief's claims were corrected as a result (see the Context
  table). Every acceptance criterion below was executed against both a
  pre-edit baseline and a post-edit scratch worktree; the recorded
  baseline/target values are measured, not predicted.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — all
  `.claude/` mirrors are produced by `node bin/cli.js --update --force-render`,
  named literally in Unit 1's ordered edits. No mirror is hand-edited. AC1.9
  asserts this by checking the tree is clean after a *second* `--force-render`.
- P3 "Version-stamp discipline": satisfied — Unit 1 changes two
  version-stamped files (`templates/persona-protocol.md`,
  `agents/spec-master.md`), and therefore bumps
  `.claude-plugin/plugin.json` + `package.json` `0.31.59` → `0.31.60` and adds
  a `CHANGELOG.md` entry, both asserted by AC1.10/AC1.11. Unit 2 touches only
  `CONTEXT.md` and `.claude/wiki/`, neither version-stamped, so it carries no
  bump — deliberately, not by omission.
- P4 "Optional personas degrade gracefully": satisfied — the replacement
  paragraph refers to *"the orchestrator's own 'At the 2-FAIL cap' section"*,
  a persona-relative reference, rather than a repo path like
  `agents/orchestrator.md`, which would be wrong in an adapted downstream
  project where the file lives at `.claude/agents/orchestrator.md`. The
  existing conditional phrasing around `lead-programmer` is preserved verbatim.
- P5 "`tests/validate.sh` is the merge gate": satisfied — carried as AC1.8 on
  Unit 1 and AC2.6 on Unit 2, and **verified achievable in advance**: a
  detached scratch worktree carrying both units' source edits plus
  `--force-render` plus the version bump ran `bash tests/validate.sh` to exit
  0. This is the explicit remediation of the false premise that produced
  `gh403.fail`.

---

## Step 1 — Reconcile the shared protocol's 2-FAIL-cap paragraph, fix the stale publish branch, and re-render

**Affected files** (exactly 18; the `.claude/**` entries are `--force-render`
output, not hand edits — this list was captured from `git status --porcelain
-uno` in the verification worktree):

- `templates/persona-protocol.md` — source edit 1
- `agents/spec-master.md` — source edit 2
- `.claude-plugin/plugin.json`, `package.json` — version bump
- `CHANGELOG.md` — new `## [0.31.60]` entry
- generated: `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`,
  `.claude/protocol-digest.md`, `.claude/persona-config.json`,
  `.claude/agents/{orchestrator,lead-programmer,spec-master,milestone-auditor,
  reviewer,task-master,scribe,researcher,agent-auditor,explorer}.md`

**Acceptance criteria** (all run from the repo root; each was executed against
a pre-edit baseline and a post-edit scratch worktree, and the measured values
are recorded so a reviewer can prove non-vacuity by reverting):

- **AC1.1** — the stale automatic-spawn claim is gone from the canonical
  paragraph. Baseline `1`, target `0`:
  ```
  n=$(sed -n '/^\*\*Cap at 2 FAILs per unit\.\*\*/,/^$/p' templates/persona-protocol.md \
      | tr '\n' ' ' | grep -ciE 'spawns? +`?spec-master`? +to produce'); [ "$n" -eq 0 ]
  ```
- **AC1.2** — the paragraph states the human-ask. Baseline `0`, target `1`:
  ```
  n=$(sed -n '/^\*\*Cap at 2 FAILs per unit\.\*\*/,/^$/p' templates/persona-protocol.md \
      | tr '\n' ' ' | tr -s ' ' | grep -ciE 'asks? +(the +human +)?how to proceed'); [ "$n" -ge 1 ]
  ```
- **AC1.3** — the paragraph *defers* rather than duplicating: none of the
  orchestrator's option mechanics leak into the shared block. Baseline `0`
  (the old text also scored 0 on this pattern — it is a guard against the
  rejected alternative, not a change-detector), target `0`:
  ```
  n=$(sed -n '/^\*\*Cap at 2 FAILs per unit\.\*\*/,/^$/p' templates/persona-protocol.md \
      | tr '\n' ' ' | grep -ciE 'park the unit|AskUserQuestion|debug spec'); [ "$n" -eq 0 ]
  ```
- **AC1.4** — the paragraph names the orchestrator's own section as the single
  definition. Baseline `0`, target `1`:
  ```
  n=$(sed -n '/^\*\*Cap at 2 FAILs per unit\.\*\*/,/^$/p' templates/persona-protocol.md \
      | tr '\n' ' ' | grep -cF 'At the 2-FAIL cap'); [ "$n" -eq 1 ]
  ```
- **AC1.5** — the stale claim survives nowhere in any shipped persona surface.
  Baseline `6`, target `0`:
  ```
  n=$(git grep -c 'spawns `spec-master` to produce a debug spec' -- \
      agents/ templates/ adapters/ prototype/ .claude/agents/ .claude/persona-protocol.md | wc -l); [ "$n" -eq 0 ]
  ```
- **AC1.6** — the corrected text reached all five rendered surfaces (four
  persona mirrors plus the untrimmed `.claude/persona-protocol.md`). Baseline
  `1`, target `5`. The baseline is **1, not 0**: `.claude/agents/orchestrator.md`
  already carries the literal as its own `**At the 2-FAIL cap**:` heading from
  Step 4 (`663c54a`), so this criterion measures the four *newly* covered
  surfaces on top of that pre-existing one:
  ```
  n=$(git grep -lF 'At the 2-FAIL cap' -- .claude/agents/ .claude/persona-protocol.md | wc -l); [ "$n" -eq 5 ]
  ```
- **AC1.7** — the stale `<3 units` branch is gone and the below-threshold
  branch is now `≤5`, complementary to `:164`'s `≥6`. Baselines `2` and `0`,
  targets `0` and `1`:
  ```
  n=$(git grep -c '<3 units' -- agents/ .claude/agents/ | wc -l); [ "$n" -eq 0 ]
  n=$(sed -n '/^- \*\*Publish via `to-spec`/,/^- \*\*Hand off/p' agents/spec-master.md \
      | tr '\n' ' ' | tr -s ' ' | grep -cF '(single-milestone, ≤5 units), publishing via `to-spec` is optional'); [ "$n" -eq 1 ]
  ```
  The `tr -s ' '` is load-bearing and must not be dropped: the sentence spans a
  line break followed by two spaces of list indentation, so without the squeeze
  the joined text contains three spaces and the `grep -F` scores `0` even on a
  correct fix. Measured both ways before this plan was finalized.
- **AC1.8** — `bash tests/validate.sh` exits 0. Run in a **clean detached
  worktree at the unit's own final commit**, not the working tree — this is
  how `gh403.fail` was diagnosed and how it must be re-confirmed:
  ```
  git worktree add --detach /tmp/wt-ac18 HEAD && (cd /tmp/wt-ac18 && bash tests/validate.sh); echo $?
  ```
- **AC1.9** — mirrors are genuinely current (P2 / idempotence). Both must
  hold, the second proving `--force-render` reached a fixed point:
  ```
  node bin/cli.js --update --dry-run; [ $? -eq 0 ]
  node bin/cli.js --update --force-render >/dev/null && [ -z "$(git status --porcelain -uno)" ]
  ```
- **AC1.10** — version bumped in lockstep (P3):
  ```
  [ "$(jq -r .version .claude-plugin/plugin.json)" = "0.31.60" ]
  [ "$(jq -r .version package.json)" = "0.31.60" ]
  n=$(grep -L "antislop v0.31.60" .claude/agents/*.md .claude/persona-protocol.md | wc -l); [ "$n" -eq 0 ]
  ```
- **AC1.11** — a `CHANGELOG.md` entry exists for `0.31.60` and names both
  fixes rather than one. All three must hold:
  ```
  grep -qF '## [0.31.60]' CHANGELOG.md
  s=$(sed -n '/## \[0.31.60\]/,/## \[0.31.59\]/p' CHANGELOG.md | tr '\n' ' ' | tr -s ' ')
  printf '%s' "$s" | grep -qF 'templates/persona-protocol.md'
  printf '%s' "$s" | grep -qF 'agents/spec-master.md'
  ```
- **AC1.12** — scope containment: the diff touches exactly the 18 files listed
  above and no adapter, prototype, `CONTEXT.md`, or `docs/` file:
  ```
  n=$(git diff --name-only HEAD~1 | grep -cE '^(adapters/|prototype/|CONTEXT\.md|docs/)'); [ "$n" -eq 0 ]
  n=$(git diff --name-only HEAD~1 | wc -l); [ "$n" -eq 18 ]
  ```

---

## Step 2 — Add the coupled threshold glossary entries and record the pass

**Affected files** (exactly 2):

- `CONTEXT.md` — two new glossary entries
- `.claude/wiki/changelog.md` — the institutional record of this pass

**Acceptance criteria:**

- **AC2.1** — a `publish threshold` glossary entry exists, in the file's own
  `**term**:` form. Baseline `0`, target `1`:
  ```
  n=$(grep -cE '^\*\*publish threshold\*\*:' CONTEXT.md); [ "$n" -eq 1 ]
  ```
- **AC2.2** — a `fast-path threshold` entry exists (the link target AC2.4
  requires). Baseline `0`, target `1`:
  ```
  n=$(grep -cE '^\*\*fast-path threshold\*\*:' CONTEXT.md); [ "$n" -eq 1 ]
  ```
- **AC2.3** — each entry states its current numeric value. Both must hold:
  ```
  s=$(sed -n '/^\*\*publish threshold\*\*:/,/^$/p' CONTEXT.md | tr '\n' ' '); printf '%s' "$s" | grep -qF '≥6'
  s=$(sed -n '/^\*\*fast-path threshold\*\*:/,/^$/p' CONTEXT.md | tr '\n' ' '); printf '%s' "$s" | grep -qF '≤5'
  ```
- **AC2.4** — the two entries cross-link, in the glossary's own `[[...]]`
  convention, so neither can be read (or later amended) without the other:
  ```
  sed -n '/^\*\*publish threshold\*\*:/,/^$/p' CONTEXT.md | tr '\n' ' ' | grep -qF '[[fast-path threshold]]'
  sed -n '/^\*\*fast-path threshold\*\*:/,/^$/p' CONTEXT.md | tr '\n' ' ' | grep -qF '[[publish threshold]]'
  ```
- **AC2.5** — the two ubiquitous-language findings are actually discharged in
  the prose, not merely noted in this plan. Both must hold:
  ```
  s=$(sed -n '/^\*\*publish threshold\*\*:/,/^$/p' CONTEXT.md | tr '\n' ' '); printf '%s' "$s" | grep -qF 'tracker-publish threshold'
  s=$(sed -n '/^\*\*fast-path threshold\*\*:/,/^$/p' CONTEXT.md | tr '\n' ' '); printf '%s' "$s" | grep -qiE 'version-match fast path|--update'
  ```
- **AC2.6** — `bash tests/validate.sh` exits 0 in a clean detached worktree at
  this unit's final commit.
- **AC2.7** — scope containment; `CONTEXT.md` and `.claude/wiki/changelog.md`
  and nothing else:
  ```
  [ "$(git diff --name-only HEAD~1 | sort | tr '\n' ',')" = ".claude/wiki/changelog.md,CONTEXT.md," ]
  ```
  (The expected string is the sorted, comma-joined form — verified by running
  `printf '.claude/wiki/changelog.md\nCONTEXT.md\n' | sort | tr '\n' ','`.)
- **AC2.8** — no version bump was made (P3 does not apply; asserting the
  *absence* prevents a well-meaning re-bump that would desynchronise the
  mirrors Unit 1 just rendered):
  ```
  [ "$(jq -r .version .claude-plugin/plugin.json)" = "0.31.60" ]
  ```

---

## Open Questions

1. **Include the `<3 units` fix (G2-bis) in Unit 1? — RESOLVED BY DEFAULT:
   yes. Proceed without a round-trip unless the operator objects.**
   *Recommended default:* include. It is the same term as Follow-up 2, it is a
   one-token edit in a file Unit 1 already opens, and leaving it means Unit 2
   publishes a glossary saying `≥6`/`≤5` while the persona it documents still
   says `<3` — with 3-, 4- and 5-unit specs matching neither branch.
   *If the operator declines:* drop ordered edit 2 and criterion AC1.7 from
   Unit 1, change AC1.12's file count from 18 to 17, and add a sentence to
   Unit 2's glossary entry recording the known contradiction. Nothing else in
   this plan changes — the fix was deliberately isolated to one ordered edit
   and one criterion so it is removable without restructuring.

No other question requires operator input; every other decision point is
recorded as self-resolved in Clarifications with the evidence it rests on.

---

## Self-check

- **CHK1: Is every clause of the Goal mapped to at least one acceptance
  criterion?** — PASS. G1 → AC1.1-AC1.6; G2 → AC2.1-AC2.5; G3 → AC1.8, AC1.9,
  AC1.10, AC1.11, AC2.6.
- **CHK2: Do Steps 1 and 2 agree on which file owns the publish threshold's
  numeric value?** — PASS. Step 1 fixes it in `agents/spec-master.md` (the
  normative source); Step 2 documents it in `CONTEXT.md` (the glossary).
  D1 states the ordering that keeps them consistent, and AC1.7 / AC2.3 assert
  the same value (`≤5` below / `≥6` at-or-above) from each side.
- **CHK3: Is "the stale claim" defined precisely enough that a reviewer can
  tell a fix from a near-miss?** — FAIL (ambiguous) — revised in place. The
  first draft said only "remove the stale paragraph". Now pinned by a
  four-way assertion: AC1.1 (old claim absent), AC1.2 (new claim present),
  AC1.3 (the *rejected* alternative — enumerating the options — also absent),
  AC1.4 (the pointer present). AC1.3 in particular is what distinguishes the
  chosen resolution from the duplicate-the-enumeration one.
- **CHK4: Is it defined what happens to the adapters and the prototype?** —
  FAIL (missing) — revised in place. The relayed brief implied all seven files
  needed the same edit. The Context table now records that three of them are
  already correct, R3 states they must not be touched, AC1.12 asserts the diff
  excludes them, and they appear in Unit 1's `## Do NOT touch`.
- **CHK5: Does the plan say how the mirror files get updated, given
  constitution P2 forbids hand-editing them?** — PASS. Unit 1's ordered edit 4
  names `node bin/cli.js --update --force-render` literally; R2 states the
  prohibition; AC1.9's second command asserts idempotence, which a hand-edit
  would not survive.
- **CHK6: Does the plan state a machine-checkable signal for every Partial
  taxonomy category?** — PASS. Cat. 2 → AC2.1/AC2.2 (entry shape);
  cat. 6 → AC1.8/AC1.9 (the mirror-parity failure mode);
  cat. 7 → AC1.3/AC1.4 (defer-not-duplicate);
  cat. 8 → AC2.5 (both drift lenses discharged in the shipped prose, not just
  noted here).
- **CHK7: Is each constitution MUST principle backed by an assertion rather
  than a claim?** — PASS. P1 → the recorded baseline/target values, all
  measured; P2 → AC1.9; P3 → AC1.10 + AC1.11; P5 → AC1.8 + AC2.6.
- **CHK8: Are the criteria demonstrably non-vacuous?** — FAIL (ambiguous) —
  revised in place. Executing the drafted criteria rather than eyeballing them
  caught two that were silently broken: AC1.6's baseline is `1`, not `0`
  (`.claude/agents/orchestrator.md` already carries the literal from `663c54a`),
  and AC1.7's second command scored `0` even against a correctly-fixed fixture
  until `tr -s ' '` was added, because the sentence wraps across a line break
  plus two spaces of list indentation. Both are corrected and re-measured.
  After the revision, every grep-based criterion carries a measured pre-edit
  baseline that differs from its target (AC1.1 `1`→`0`, AC1.2 `0`→`1`,
  AC1.4 `0`→`1`, AC1.5 `6`→`0`, AC1.6 `1`→`5`, AC1.7 `2`→`0` and `0`→`1`,
  AC2.1/AC2.2 `0`→`1`). The one exception is declared as such in AC1.3's own
  text: it scores `0` both before and after, because it guards against the
  rejected alternative rather than detecting the change.
- **CHK9: Does the plan state whether a tracker issue exists, so `scribe` does
  not attempt to close one?** — FAIL (missing) — revised in place. Added D2
  and the status line at the top: 2 units is below the ≥6 publish threshold,
  no `[spec]` issue is filed, this document is the retrieval contract, and
  `scribe`'s issue-closing duty does not fire.
- **CHK10: Does the plan account for the prior `.fail` record in this area?**
  — PASS. `.claude/reviewed/gh403.fail` is read and named in G3, R1 (no
  `haiku` dispatch, relay the defect history), P5's constitution line, and
  Unit 1's `## Pre-resolved context`.

No failed item remains unrepresented: CHK3, CHK4, CHK8 and CHK9 were each
revised in place during the single revision pass, and the re-check found all
four passing. No item was converted to an Open Question — Open Question 1 is a
scope decision, not a Self-check failure.

---

## Out of scope

- Editing `adapters/codex/agents-md-fragment.md`,
  `adapters/cursor/rules/persona-protocol.mdc`, or
  `prototype/protocol-mcp/rules/continuing-after-fail.md` — verified already
  correct (R3).
- The broader protocol-paragraph audit the operator excluded. `gh404.pass`
  notes 2, 3 and 4 are recorded in R6 as deliberately deferred, with reasons.
- Any behavioural change to the 2-FAIL cap itself. `agents/orchestrator.md`'s
  mechanics are correct as of `663c54a` and are not touched by either unit.
- Filing a tracker issue (D2), and re-opening or re-closing #395.

---

## Scribe update hint

After Unit 2 lands, `.claude/wiki/changelog.md` should record: (a) that the
shared protocol block now *points at* the orchestrator's 2-FAIL-cap section
rather than restating it, and that this is the same pointer-not-restate
convention the `Fourth verdict` section already documents; (b) that the
Codex/Cursor/prototype ports were already correct and were deliberately left
alone — so a future reader does not "discover" them as an unfixed gap; (c) that
`agents/spec-master.md`'s `<3 units` leftover made 3-5-unit specs match neither
publish branch, and that Step 3's AC3.8 passed vacuously against it because the
literal on disk was `<3 units`, not `≥3 units`. Item (c) is the reusable
lesson: a "no stale value survives" criterion must grep the *old literal*, not
the old concept.

---

# Dispatch contracts

Two units, below the ≤5 fast-path threshold: dispatched directly from this
document, no `task-master`, no `to-tickets`, no tracker issue.

## Unit: adhoc-2026-08-16-cap-paragraph-reconcile

### Objective
Rewrite `templates/persona-protocol.md`'s "Cap at 2 FAILs per unit" paragraph
so it describes the human-gated cap and points at the orchestrator's own
section instead of asserting the removed automatic `spec-master` spawn; fix the
stale `<3 units` publish branch in `agents/spec-master.md`; regenerate all
mirrors; bump the version and add the CHANGELOG entry.

### Retrieval
`docs/plans/2026-08-16-ceremony-reduction-followups.md`, Step 1. No tracker
issue exists for this unit — do not search for one and do not create one.

### Affected files
`templates/persona-protocol.md`, `agents/spec-master.md`,
`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, and the 13
`--force-render` outputs listed in Step 1 (`.claude/agents/*.md` ×10,
`.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`,
`.claude/protocol-digest.md`, `.claude/persona-config.json`) — 18 files total.

### Ordered edits

1. **`templates/persona-protocol.md`** — replace the paragraph at lines
   573-581 in full. Match on the exact existing text and assert it occurs
   exactly once before replacing. Old:
   ```
   **Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the
   orchestrator (or team lead) stops re-dispatching `lead-programmer` — it
   surfaces the full defect history across both attempts to the user, then
   spawns `spec-master` to produce a debug spec (a focused root-cause diagnosis
   plus revised acceptance criteria for the failed step(s), never a
   from-scratch replan), which then routes through the same ≤5-unit fast path
   spec-master already owns for any other spec before re-dispatch. A unit that
   fails twice usually means the plan itself has a gap, not that one more
   automated pass will close it.
   ```
   New (this exact text was run against all of AC1.1-AC1.6 and `validate.sh`
   in a scratch worktree; deviating from it risks failing AC1.2 or AC1.4):
   ```
   **Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the
   orchestrator (or team lead) stops re-dispatching `lead-programmer` — it
   surfaces the full defect history across both attempts to the human and asks
   how to proceed, rather than spawning a third fix attempt on its own
   authority. Which choices the human is offered, and what each one does, are
   defined in one place only — the orchestrator's own "At the 2-FAIL cap"
   section — and are pointed at from here rather than restated, so a later
   amendment cannot leave two copies disagreeing. A unit that fails twice
   usually means the plan itself has a gap, not that one more automated pass
   will close it.
   ```
2. **`agents/spec-master.md:174-175`** — one-token fix, changing `<3 units` to
   `≤5 units` so the two publish branches become complementary. Old:
   `with the `ready-for-agent` label. For smaller specs (single-milestone,` /
   `  <3 units), publishing via `to-spec` is optional.` — new: identical but
   with `≤5 units)` in place of `<3 units)`. (Drop this edit **only** if the
   operator declines Open Question 1; see its "if the operator declines" note.)
3. **Version bump** — `.claude-plugin/plugin.json` and `package.json`,
   `0.31.59` → `0.31.60`.
4. **Regenerate mirrors** — `node bin/cli.js --update --force-render`. Plain
   `--update` is **not** sufficient: it takes a stamp-not-content fast path and
   will leave the mirrors stale, which is the exact mechanism that FAILed
   `gh403`. Run this **after** edits 1-3 so the new version stamp is rendered
   in the same pass.
5. **`CHANGELOG.md`** — new `## [0.31.60] - 2026-08-16` section above
   `## [0.31.59]`, following the existing entry's shape (summary paragraph then
   a `### Changed` list). It must name `templates/persona-protocol.md` and
   `agents/spec-master.md` explicitly (AC1.11), state that the shared paragraph
   now points at the orchestrator's section rather than restating it, and note
   that the Codex/Cursor/prototype ports already carried the correct wording
   and were not touched.

### Do NOT touch
- `adapters/**` and `prototype/**` — already correct; editing them regresses
  three good artifacts and breaks AC1.12.
- `agents/orchestrator.md` — its 2-FAIL-cap mechanics at `:249-266` are the
  single source of truth this unit points at, and are correct as of `663c54a`.
- `CONTEXT.md` and `.claude/wiki/**` — Unit 2's scope.
- Any `.claude/` mirror by hand. They are `--force-render` output only
  (constitution P2). Editing one directly fails AC1.9's idempotence check.
- `tests/**` — no test needs changing; `adapter-protocol-parity`,
  `protocol-doc-drift` and `protocol-cross-references` were all verified to
  pass unchanged against this exact text.

### Acceptance criteria
AC1.1 through AC1.12 in Step 1 above, verbatim. Run **all** of them; each
carries a measured baseline so a reviewer can prove non-vacuity by reverting.
AC1.8 must be run in a clean detached worktree at this unit's own final commit,
not in the working tree.

### Pre-resolved context
- **The occurrence list is exact and already derived — do not re-derive it.**
  `git grep -n 'spawns \`spec-master\` to produce a debug spec'` returns 6
  hits: 1 source (`templates/persona-protocol.md:576`) and 5 generated mirrors.
  Editing the one source and running `--force-render` clears all 6. The
  adapters and prototype are **not** among them.
- **Blast radius of the template edit:** `bin/cli.js`'s
  `PROTOCOL_SECTIONS_BY_PERSONA` (at `bin/cli.js:594`) inlines
  `'Continuing after a FAIL verdict'` into exactly four persona mirrors —
  `orchestrator`, `lead-programmer`, `spec-master`, `milestone-auditor` — plus
  the untrimmed `.claude/persona-protocol.md`. That is the 5 in AC1.6.
  `templates/persona-protocol-slim.md` does not carry this section.
- **No dangling reference is created.** Neither `agents/lead-programmer.md` nor
  `agents/milestone-auditor.md` mentions "debug spec" outside the inlined
  block, and both `agents/orchestrator.md:249-266` and
  `agents/spec-master.md:204-235` retain their own full statements of the
  routing this paragraph stops restating. Verified.
- **`bin/cli.js`'s load-time guard does not fire.** `assertNoDanglingCrossReferences`
  matches only `## `-delimited canonical protocol headers; `"At the 2-FAIL cap"`
  is a paragraph in `agents/orchestrator.md`, not a protocol header.
- **Prior FAIL in this exact area:** `.claude/reviewed/gh403.fail` FAILed the
  sibling unit for editing `agents/*.md` + `templates/persona-protocol.md`
  without regenerating the mirrors, which made `--update --dry-run` exit 3 →
  `cli-backfill.test.js` fail → `validate.sh` exit 1. Ordered edit 4 is the
  remediation. **Do not dispatch this unit on `haiku`.**
- **The whole unit was verified achievable in advance.** In a detached
  worktree at `602ca46`, edits 1-4 plus the bump produced: `--force-render`
  exit 0, `--update --dry-run` exit 0, `bash tests/validate.sh` exit 0, all 18
  files as listed, and every AC1.x at its target value.

### Escalation
If any instruction cannot be followed exactly as written — the `old` text does
not occur exactly once, `--force-render` leaves the tree dirty on a second run,
or `validate.sh` is red in a clean worktree — **STOP and report a block or spec
gap upward. Do not improvise and do not widen the diff.** `gh403` was FAILed
specifically for not taking this exit.

---

## Unit: adhoc-2026-08-16-publish-threshold-glossary

### Objective
Add two cross-linked `CONTEXT.md` glossary entries — **publish threshold**
(≥6 units) and **fast-path threshold** (≤5 units) — that make the coupled
OQ-3 decision findable by name, resolve the three competing spellings of the
publish term, and disambiguate "fast path" from `--update`'s unrelated
version-match fast path. Record the pass in the wiki.

### Retrieval
`docs/plans/2026-08-16-ceremony-reduction-followups.md`, Step 2. No tracker
issue exists for this unit — do not search for one, do not create one, and do
not attempt to close #395 (already closed).

### Affected files
`CONTEXT.md`, `.claude/wiki/changelog.md`. Exactly two.

### Ordered edits

1. **`CONTEXT.md`** — insert both entries immediately after the existing
   **`to-spec` skill** entry (which ends just before ``**`pathfinder` skill**:``),
   matching the file's flat `**term**:` + indented-continuation format exactly.
   Content requirements:
   - **`fast-path threshold`** — ≤5 dispatchable units: `spec-master` emits the
     nine-element dispatch contract directly, `task-master` and `to-tickets`
     are bypassed, and the orchestrator dispatches from the `docs/plans/`
     document, which is then the retrieval contract. Raised from ≤2 to ≤5 by
     Step 3 of the ceremony-reduction plan (ADR-0024, amending ADR-0003).
     **Must explicitly disambiguate** from `bin/cli.js --update`'s
     *version-match fast path* (see this glossary's `--force-render` /
     `--dry-run` entries), which is an unrelated mechanism sharing the words
     "fast path". Must link `[[publish threshold]]`.
   - **`publish threshold`** — ≥6 dispatchable units (or any multi-milestone
     spec): `spec-master` maps the finished plan onto the `to-spec` PRD
     template and publishes it to the issue tracker with the `ready-for-agent`
     label. At ≤5 units publishing is optional; the `docs/plans/` document
     remains the canonical artifact either way. **Must record**
     `tracker-publish threshold` (used in `CHANGELOG.md` and `docs/adr/0024`)
     and `publish-threshold` as aliases of this canonical spelling. **Must
     state the coupling invariant** from ADR-0024: this threshold and
     `[[fast-path threshold]]` were raised together by design (OQ-3) and
     moving one requires moving the other — a decoupled pair would let a
     4-unit spec skip `task-master` while still filing a tracker issue nobody
     slices from. Must link `[[fast-path threshold]]`.
2. **`.claude/wiki/changelog.md`** — a dated entry recording both units of this
   plan, covering the three points in the "Scribe update hint" section above.

### Do NOT touch
- `agents/**`, `templates/**`, `.claude/agents/**`, `.claude/persona-*.md` —
  Unit 1's scope, already landed. Re-rendering them here would produce an
  out-of-scope diff and fail AC2.7.
- `.claude-plugin/plugin.json` / `package.json` — no bump. Neither file this
  unit touches is version-stamped, and a bump here would desynchronise the
  mirrors Unit 1 rendered (AC2.8 asserts the version is unchanged).
- The existing **FAIL routing (post-reviewer)**, **`to-spec` skill**, and
  **operator** entries — additive insertion only; do not restructure
  neighbouring entries.

### Acceptance criteria
AC2.1 through AC2.8 in Step 2 above, verbatim.

### Pre-resolved context
- **Neither term currently has a glossary entry.** Verified: `CONTEXT.md`'s 100
  `**term**:` entries contain neither. The relayed brief's premise that a
  fast-path entry already exists, into which the publish entry could be folded,
  is false. Both entries are new.
- **`≤5` already appears in `CONTEXT.md`** at lines 586-588, but only inside
  the **FAIL routing (post-reviewer)** entry as an incidental mention. That is
  not a definition and does not satisfy AC2.2. Leave that entry alone.
- **The three competing spellings are enumerated** in the Context section
  above with file and line for each — you do not need to re-derive them.
- **`CONTEXT.md` is a flat glossary** under a single `## Language` heading;
  there is no sub-section to place entries within, and no alphabetical order to
  maintain. The insertion point in ordered edit 1 is chosen for topical
  adjacency to the `to-spec` entry.
- **No automated validation exists for `CONTEXT.md` glossary structure**
  (`gh405.pass`, final note). `validate.sh` will pass regardless of content
  quality here, so AC2.1-AC2.5 are the only real gate — run each one literally
  rather than eyeballing the result.

### Escalation
If the `to-spec` skill entry cannot be located as described, or if AC2.7's
file-set assertion cannot be met without touching a third file, **STOP and
report a block upward rather than widening the diff.**
