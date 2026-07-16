# Plan: three-fold persona-system update (2026-07-14)

**Issue-retrieval contract (per shared protocol):** issues live in GitHub
issues (repo `Storreslara/AntiSlop`, `gh` CLI authenticated). File each unit
with `gh issue create --label plan/2026-07-14-threefold-update`; fetch with
`gh issue list --label plan/2026-07-14-threefold-update`. (Source:
`.claude/persona-config.json` `issueTracker`.) Slicing into issues happens
via `to-tickets` only AFTER this plan is approved and the Open Questions
below are resolved.

## Goal
Ship three loosely-coupled changes to the antislop persona-system plugin,
each as its own milestone/track:
1. Rename the `repo-historian` persona to `scribe` everywhere it is
   referenced (identity rename, not a behavior change).
2. Wire the existing published `to-spec` skill from the `mattpocock/skills`
   package into the persona system as a 6th `<MATTPOCOCK:slot>`, consumed by
   `spec-master`. (RESOLVED — no first-party authoring, no new export path;
   same install-antislop TUI flow as the other 5 mattpocock slots.)
3. Split the `hivemind` persona into two personas — `spec-master` (owns
   spec authoring + grilling) and `task-master` (owns dispatch-instruction
   authoring for `lead-programmer` and `scribe`) — retiring
   `hivemind.md`.
4. Author a new FIRST-PARTY skill `pathfinder` — a tailored derivative of
   mattpocock's `wayfinder` (NOT a passthrough) — scoped to help
   `task-master` build reliable, detailed, unambiguous dispatch tasks. Ships
   via the plugin-source `skills/` + `plugin.json` path (like
   `coding-discipline`), wired into `task-master.md`'s `skills:` frontmatter.
   (This relocates wayfinder's underlying idea to the persona it actually
   fits — resolving the OQ7 semantic-mismatch concern — and sidesteps
   wayfinder's missing transitive deps since we adapt content, not install
   the skill.)
5. Author a new FIRST-PARTY skill `roast-work` for `reviewer` — a
   detail-driven critique rubric (contradictions, missing parts, logic gaps,
   security vulnerabilities, thoughtful actionable feedback) written to the
   mattpocock/skills quality bar (NOT derived from any single skill — no
   packaged skill fit). Ships via the same plugin-source `skills/` +
   `plugin.json` path as `pathfinder`, wired into `reviewer.md`'s `skills:`
   frontmatter. **Carefully bounded so it does NOT weaken reviewer's
   machine-checkable-criteria PASS gate — advisory/non-gating only; see
   Track 4's two resolved tensions (option (a) + opus-gate/fable-heavy-lifting
   routing).**

## Context
This repo IS the antislop plugin source AND self-hosts it (dogfoods). That
produces **two copies of every persona**:
- **Plugin source** — `agents/*.md`, `templates/*`, `adapters/{cursor,codex}/*`
  (the files shipped to and adapted for consumer projects).
- **Adapted copies** — `.claude/agents/*.md`, `.claude/persona-protocol.md`
  (this repo's own ADAPT output, version-stamped, hash-tracked in
  `.claude/persona-config.json`).

Both must change for items 1 and 3. `bin/cli.js` already carries a proven
persona-rename pattern: `LEGACY_PERSONA_MAP = { planner: 'hivemind' }` from
the v0.6.0 `planner`→`hivemind` rename, plus `OPTIONAL_PERSONAS` and the
selection-wizard descriptions. The rename and the split both extend that
machinery.

**Living-vs-historical scoping rule (applies to all tracks):** rename/split
edits touch *living* surfaces only — persona files (both copies), templates,
adapters, `bin/cli.js`, `.claude/persona-config.json`, config schema, hooks,
commands, `README.md`, `CONTEXT.md`, `.claude/wiki/*`, `.claude/constitution.md`,
`.claude-plugin/plugin.json`, and a *new* `CHANGELOG.md` entry. Point-in-time
records are **left as written** (rewriting them would falsify history):
`docs/specs/*`, `docs/plans/*` (including this file's own historical refs),
`prototype/*`, `RnD/*`, and existing `CHANGELOG.md` entries for prior
versions. The `LEGACY_PERSONA_MAP` deliberately *retains* the old tokens.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-14 Functional scope & success criteria: Q Does item 1 mean the
  full mechanical rename across all references? → A: yes, full mechanical
  rename as scoped (coordinator).
- 2026-07-14 Functional scope & success criteria: Q What concrete content
  should the "Matt Pocock skill" contain? → A: RESOLVED (coordinator) — the
  existing published `to-spec` skill from `mattpocock/skills`, consumed by
  spec-master (via `<MATTPOCOCK:slot>`); plus a 4th add-on that evolved across
  rounds into authoring a NEW first-party `pathfinder` skill (derived from
  `wayfinder`) for task-master (OQ7-final — see below), NOT a wayfinder
  passthrough on reviewer.
- 2026-07-14 User interaction flow: Q Does spec-master or task-master own
  the grilling / Open-Questions interrogation? → A: spec-master grills
  during spec authoring; task-master receives a finalized, non-ambiguous
  spec and never grills the user (coordinator).
- 2026-07-14 User interaction flow: Q Is `hivemind.md` kept as a thin
  dispatcher or removed? → A: split/removed; replaced by `spec-master.md`
  and `task-master.md` (coordinator).
- 2026-07-14 External dependencies & integrations: Q What is the "install
  target" / export path? → A: RESOLVED — moot once item 2 became the existing
  published `to-spec` skill; it ships via the same install-antislop TUI +
  `<MATTPOCOCK:slot>` mechanism as the other 5 mattpocock skills, no new
  export path. (Investigation had shown no path exports repo-authored
  `.claude/skills/` content to consumers — no longer relevant.)
- 2026-07-14 Technical constraints & tradeoffs: Q Do the item-2/4 skills fit
  their target personas? → A: RESOLVED — `to-spec` vs grill-me is clean
  (complementary/sequential); `to-spec`'s template LAYERS on top of the
  v0.9.0 spec-kit machinery (OQ6 → layer, don't replace); and the
  wayfinder-on-reviewer mismatch (OQ7) was resolved by dropping it and
  instead authoring a first-party `pathfinder` derivative for task-master.
- 2026-07-14 Edge cases / failure handling: Q Who owns re-plan after a
  reviewer FAIL, and can task-master bounce back to spec-master mid-flight?
  → A: not covered by user — carried to Open Questions 3 and 4 with
  recommended defaults.
- 2026-07-14 Technical constraints & tradeoffs: Q Do both the plugin-source
  and adapted persona copies need editing (plus adapters/templates)? → A
  (self-resolved): yes — the repo self-hosts; both copies are live. Adapter
  ports scoped per Open Question 5.
- 2026-07-14 Terminology consistency: Q Confirmed names? → A (self-resolved):
  `scribe`, `spec-master`, `task-master` (from coordinator/task brief).
- 2026-07-14 Non-functional attributes: Q Model tiers for the new personas?
  → A (self-resolved): spec-master heavyweight (opus, fable when
  well-scoped — criteria transfer from hivemind, see Track 3 Step 8);
  task-master sonnet|opus, fable excluded (given).
- 2026-07-14 Completion / acceptance signals: Q What is the machine
  check? → A (self-resolved): `bash tests/validate.sh` exit 0 +
  `node bin/cli.js --update` exit 0 + targeted grep sweeps returning 0 on
  living surfaces + `node --test tests/cli-backfill.test.js`.
- 2026-07-15 Completion / acceptance signals: Q Step 3.3's `validate.sh exit
  0` criterion is unsatisfiable at 3.3 because `tests/cli-backfill.test.js`
  still reads the just-deleted `agents/hivemind.md` (the fixture rewrite was
  mis-scoped to Step 3.6) — how to resolve the ordering defect? → A
  (self-resolved, post-3.3-review): drop `validate.sh` from Step 3.3's own
  gate (its file changes are already reviewer-verified) and insert Step 3.3b —
  permanently fix the `:40` round-trip list (safe, deletion-consistent, no 3.4
  dependency) while deferring ONLY the 3.4-coupled `:140` legacy fixture to its
  official owner Step 3.6 via an explicit `TODO(Step 3.6)` skip. Keeps
  `validate.sh exit 0` intact as a real gate at 3.3b/3.4/3.5 rather than
  blanket-relaxing it. Full verdict at `.claude/reviewed/3.3.fail`.

## Risks / dependencies
- **Track ordering:** Track 1 (rename) and Track 3 (split) edit an
  overlapping file set (`orchestrator.md`, `lead-programmer.md`,
  `persona-protocol.md`, `bin/cli.js`, `README.md`, `.claude/wiki/*`,
  `CONTEXT.md`, `plugin.json`, config). Run **Track 1 fully before Track
  3** — task-master's dispatch prose must reference `scribe`, not
  `repo-historian`. Do not parallelize these two tracks (write-race + churn).
- **Track 2 is Open-Question-gated** and independent of 1/3 at the file
  level; it can start only once OQ1 (content) and OQ2 (export path) resolve.
- **Deterministic-config risk (Constitution P2):** `.claude/persona-config.json`
  `personaSelection` and `fileHashes` must be regenerated via
  `node bin/cli.js --update`, NOT hand-edited. Renaming/adding/removing a
  persona file is a structural change `--update` may not auto-handle from
  `personaSelection` alone — the cli.js registry edits (Track 1 Step 4,
  Track 3 Step 4) must land and be unit-tested *before* the config
  regeneration step in each track.
- **Version discipline (Constitution P3):** all three tracks touch
  version-stamped files, so the release bumps `.claude-plugin/plugin.json`
  (and `package.json`) to **0.10.0** with a CHANGELOG entry (final
  consolidation unit). Re-stamp every edited version-stamped file's
  `<!-- antislop vX.Y.Z ... -->` line to 0.10.0.
- **Frontmatter-first constraint:** persona files MUST begin with the `---`
  frontmatter delimiter as the very first bytes; the version-stamp comment
  goes immediately AFTER the closing `---` (install-antislop step 2). A new
  `spec-master.md`/`task-master.md`/`scribe.md` that leads with a comment
  silently breaks agent discovery with no error.
- **hivemind fable-example dependency:** v0.9.0 shipped worked fenced-code
  examples for every literal-format requirement (Clarifications scorecard,
  Self-check list, Constitution check) because prose-only instructions
  degraded under fable/opus (CHANGELOG v0.9.0 "Verification methodology").
  Track 3 MUST carry those worked examples verbatim into `spec-master.md`,
  or the split silently regresses fable-tier compliance.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume" (MUST): satisfied — every acceptance criterion
  is a runnable check (validate.sh / cli.js exit code / grep count / node
  --test), never "looks renamed."
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST):
  satisfied — `personaSelection`/`fileHashes` regenerated via
  `bin/cli.js --update`; the rename/split add a `LEGACY_PERSONA_MAP` entry
  rather than hand-migrating.
- P3 "Version-stamp discipline" (MUST): satisfied — dedicated 0.10.0
  version-bump + CHANGELOG unit; all edited stamped files re-stamped.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — new
  persona references in shared prose stay conditionally phrased ("if
  present, otherwise…"); note the constitution's own P4 text (line 25)
  enumerates the persona names and is itself in the edit set (Track 1 Step
  7, Track 3 Step 7).
- P5 "tests/validate.sh is the merge gate" (MUST): satisfied — every unit
  includes `bash tests/validate.sh` exit 0.

---

## Track 1 — Rename `repo-historian` → `scribe`
Ordering: **do this track first.** Each step's acceptance criteria assume
prior steps landed. "Scribe"/"scribe" replaces "repo-historian"/"historian"
in living prose (including capitalized prose like "Historian updates" →
"Scribe updates" and "Historian update hint" → "Scribe update hint").

### Step 1.1 — Rename the persona file + identity (plugin source)
- Affected: `agents/repo-historian.md` → `agents/scribe.md` (git mv);
  frontmatter `name: repo-historian` → `name: scribe`; update the
  `description:` self-reference; body self-references.
- `Suggested model: haiku`
- Acceptance: `test -f agents/scribe.md && ! test -f agents/repo-historian.md`;
  `grep -m1 '^name: scribe$' agents/scribe.md`;
  `grep -rniI 'repo-historian\|historian' agents/scribe.md` returns 0;
  `bash tests/validate.sh` exit 0.

### Step 1.2 — Rename the adapted copy
- Affected: `.claude/agents/repo-historian.md` → `.claude/agents/scribe.md`
  (git mv); same frontmatter/body edits; keep the version-stamp comment line
  (re-stamped to 0.10.0 in the final unit).
- `Suggested model: haiku`
- Acceptance: `test -f .claude/agents/scribe.md && ! test -f
  .claude/agents/repo-historian.md`; `grep -rniI 'repo-historian\|historian'
  .claude/agents/scribe.md` returns 0; `bash tests/validate.sh` exit 0.

### Step 1.3 — Update cross-referencing persona prose (both copies)
- Affected: `agents/lead-programmer.md` + `.claude/agents/lead-programmer.md`
  (5 refs each incl. "Historian updates" bullet and "spawning it pauses
  you"), `agents/orchestrator.md` + `.claude/agents/orchestrator.md` (routing
  row "what does the repo do", Default-feature-pipeline note "which updates
  the historian itself"), `agents/hivemind.md` + `.claude/agents/hivemind.md`
  ("Historian update hint" — NOTE: hivemind.md is removed in Track 3; still
  fix it here so Track 1 is internally consistent and the git history is
  clean). Keep all references conditionally phrased (Constitution P4).
- `Suggested model: sonnet` (cross-file consistency + conditional-phrasing
  judgment)
- Acceptance: `grep -rniI 'repo-historian\|historian' agents/ .claude/agents/`
  returns 0; `bash tests/validate.sh` exit 0.

### Step 1.4 — Update `bin/cli.js` persona registry + migration map
- Affected: `bin/cli.js` — `OPTIONAL_PERSONAS` (`repo-historian`→`scribe`);
  extend `LEGACY_PERSONA_MAP` with `'repo-historian': 'scribe'` (so
  already-adapted consumer projects migrate on `--update`, mirroring the
  `planner`→`hivemind` precedent); selection-wizard description strings
  (lines ~1306); any other literal `repo-historian` token.
- `Suggested model: sonnet` (migration-map correctness; consumer upgrade
  path)
- Acceptance: `grep -n "'scribe'" bin/cli.js` present in `OPTIONAL_PERSONAS`
  and `LEGACY_PERSONA_MAP`; `node --check bin/cli.js` exit 0;
  `node --test tests/cli-backfill.test.js` exit 0 (update fixtures in Step
  1.6 first if they assert the old token); `bash tests/validate.sh` exit 0.

### Step 1.5 — Update shared protocol, hooks, commands, config schema
- Affected: `.claude/persona-protocol.md` + `templates/persona-protocol.md`
  (any historian ref), `hooks/scripts/task-gate.sh` (comment line 26 —
  cosmetic but in scope), `commands/start-feature-team.md` (4 refs),
  `templates/persona-config.schema.json` (2 refs in `gatedAgents`/
  `personaSelection`/`fileHashes` description strings).
- `Suggested model: haiku`
- Acceptance: `grep -rniI 'repo-historian\|historian'
  .claude/persona-protocol.md templates/persona-protocol.md
  hooks/scripts/task-gate.sh commands/start-feature-team.md
  templates/persona-config.schema.json` returns 0; `bash tests/validate.sh`
  exit 0 (validates JSON + bash syntax).

### Step 1.6 — Update tests, eval harness, and test fixtures
- Affected: `tests/validate.sh` (2 refs — likely a list of expected persona
  files), `tests/cli-backfill.test.js` (1 historian ref, plus hivemind
  refs left for Track 3), `eval/harness/scaffold.sh` (persona list).
- `Suggested model: sonnet` (test assertions must track the rename without
  masking a real regression)
- Acceptance: `bash tests/validate.sh` exit 0;
  `node --test tests/cli-backfill.test.js` exit 0;
  `grep -rniI 'repo-historian' tests/ eval/` returns 0 (the
  `LEGACY_PERSONA_MAP` string in a test asserting migration is allowed —
  scope it to `scribe`-target assertions).

### Step 1.7 — Update living docs + constitution + this-repo config
- Affected: `README.md` (persona table row + prose, 5 refs), `CONTEXT.md`
  (2 refs — glossary "Persona" line lists optional personas, ownership line
  "owned by repo-historian"), `.claude/constitution.md` (P4 line 25 name
  list), `.claude/wiki/architecture.md`, `.claude/wiki/changelog.md`,
  `.claude/wiki/dependencies.md` (1 ref each), `.claude-plugin/plugin.json`
  (1 ref — agent list/description). Then regenerate this repo's own config:
  update `.claude/persona-config.json` `personaSelection`
  (`repo-historian`→`scribe`) and rerun the deterministic path.
- `Suggested model: sonnet` (docs + the deterministic-config regeneration
  interplay; `.claude/constitution.md` is a protected path)
- Acceptance: `grep -rniI 'repo-historian\|historian' README.md CONTEXT.md
  .claude/constitution.md .claude/wiki/ .claude-plugin/plugin.json` returns
  0; `grep -c 'repo-historian' .claude/persona-config.json` returns 0
  except within any deliberately-retained legacy note;
  `node bin/cli.js --update` exit 0 (regenerates `fileHashes`);
  `bash tests/validate.sh` exit 0.
- Note: `.claude/constitution.md` is in `protectedPaths` — editing it
  requires the human-approval path; flag in the dispatch.

### Step 1.8 — Rename in the cursor/codex adapters (OQ5b final — rename now)
- Affected: `adapters/cursor/agents/orchestrator.md` (1 historian ref),
  `adapters/cursor/agents/lead-programmer.md` (4 refs),
  `adapters/codex/agents/orchestrator.toml` (1 ref),
  `adapters/codex/agents/lead-programmer.toml` (4 refs),
  `docs/cursor-port-notes.md` + `docs/codex-port-notes.md` (1 ref each — port
  notes are living docs, not point-in-time specs). The `repo-historian`→
  `scribe` rename only; the hivemind-split port is Step 3.8's deferred
  follow-up.
- `Suggested model: sonnet` (two adapter dialects incl. TOML; keep phrasing
  conditional per Constitution P4)
- Acceptance: `grep -rniI 'repo-historian\|historian' adapters/` returns 0;
  `bash tests/validate.sh` exit 0 (validates the TOML/frontmatter shape).

### Step 1.9 — Rename in the `install-antislop` skill (enumeration gap found in execution)
Added after Step 1.7's review surfaced that the original 8-step enumeration
omitted the consumer-facing install skill — a LIVE surface (per OQ0's scope
decision), not historical docs. Two files slipped through:
- Affected: `skills/install-antislop/SKILL.md` (5 refs — persona-selection
  bullet L80, placeholder-substitution list L188 where `repo-historian.md`→
  `scribe.md` ONLY, the `hivemind.md` on that same line stays for Step 3.6;
  wiki-seeding bullet L452; hook-verification sub-bullets L485-486) and
  `skills/install-antislop/hook-verification.md` (1 ref — L13
  "repo-historian turn even with a dirty tree" → "scribe turn"). Keep all
  references conditionally phrased (Constitution P4).
- `Suggested model: haiku` (mechanical token rename against an exact grep
  criterion)
- Acceptance: `grep -rniI 'repo-historian\|historian' skills/install-antislop/`
  returns 0; `bash tests/validate.sh` exit 0.

### Step 1.10 — Refresh stale `fileHashes` baseline (config hygiene, found in execution)
Added after Step 1.7's `node bin/cli.js --update` surfaced that
`.claude/persona-config.json`'s recorded `fileHashes` for
`.claude/agents/{orchestrator,lead-programmer,hivemind}.md` are STALE —
predating Steps 1.3-1.6's edits. No live bug (current content is
byte-identical to a fresh render; diffs empty) — the `--update` "already
current" fast-path (`pluginVersion === version && !hadLegacyToken &&
!backfilled`) treats version-equality as a proxy for hash-freshness and so
skipped recomputation. Refresh the baseline NOW while diffs are empty, rather
than letting C.1's version bump turn it into a noisier mixed-diff decision.
- Affected: `.claude/persona-config.json` (`fileHashes` for the three files).
- `Suggested model: haiku` (single deterministic command).
- Acceptance: run `node bin/cli.js --update
  --accept=.claude/agents/orchestrator.md,.claude/agents/lead-programmer.md,.claude/agents/hivemind.md`;
  then a follow-up `node bin/cli.js --update` exits 0 reporting no divergence
  for those files; `bash tests/validate.sh` exit 0.
- Note: superseded content-wise by C.1's 0.10.0 re-stamp+regen, but doing it
  now isolates the stale-baseline fix from the version bump (reviewer's
  rationale). The issue body also documents the underlying cli.js design gap
  (version-equality-as-hash-freshness proxy) for whoever later hardens
  `--update` — documentation only, not a fix requested here.

---

## Track 2 — Skills for the planning personas (`to-spec` → spec-master; new `pathfinder` → task-master)
Two mechanisms: `to-spec` is wired via the existing `<MATTPOCOCK:slot>`
substitution (Steps 2.1/2.2); `pathfinder` is a genuinely first-party
authored skill shipped via the plugin-source `skills/` + `plugin.json` path
like `coding-discipline` (Step 2.3). `reviewer` gets NOTHING new (the earlier
wayfinder→reviewer idea was dropped per OQ7-final).

### `to-spec` → `spec-master`
RESOLVED (was OQ-gated). `to-spec` is an existing published skill in the
`mattpocock/skills` package
(github.com/mattpocock/skills → skills/engineering/to-spec/SKILL.md). Its
own description: *"Turn the current conversation into a spec and publish it
to the project issue tracker — no interview, just synthesis of what you've
already discussed."* It carries its own PRD template (Problem Statement /
Solution / User Stories / Implementation Decisions / Testing Decisions / Out
of Scope / Further Notes) and publishes to the tracker with the
`ready-for-agent` label. **Integration mechanism = the already-established
`<MATTPOCOCK:slot>` substitution** used for the other 5 skills — no
first-party skill file, no `.claude/skills/` or source `skills/` addition, no
`plugin.json` registration, no new export code. This track depends on Track 3
(the slot lives in `spec-master.md`, created in Track 3 Step 3.1), so run it
**after Track 3 Step 3.1**, or fold it into that step.

**Finding — `to-spec` vs `grill-me` (coordinator's overlap question):** NO
overlap or subsumption. `grill-me` interrogates the user to resolve
ambiguity; `to-spec` explicitly does the opposite ("Do NOT interview the
user"). They are complementary and sequential — spec-master runs `grill-me`
to resolve ambiguity, THEN `to-spec` to synthesize the resolved conversation
into a published spec. Both belong on spec-master side by side.

**Finding — `to-spec` DOES overlap two OTHER things → Open Question 6:** its
template + its "publish to the issue tracker" behavior collide with (a)
spec-master's existing hivemind-inherited plan-output format (Goal → Context
→ Clarifications → … → Self-check) and (b) the `to-issues`/`to-tickets`
slicing role. This is an unresolved design decision, surfaced as OQ6 below —
do NOT assume `to-spec` silently replaces or coexists with the existing
format without a decision.

### Step 2.1 — Add the `to-spec` slot to the mattpocock substitution surface
- Affected: `.claude-plugin/plugin.json` credits/skill-list mention if any;
  `README.md` credits section (lists the 5 mattpocock skills — add the 6th,
  respecting the documented "registered names drift between package
  versions" caveat); `skills/install-antislop/SKILL.md` step 3 (the
  by-purpose skill list the human is told to select in the TUI — add a
  "turn conversation into a spec" purpose → `to-spec`);
  `templates/persona-config.schema.json` if it enumerates the mattpocock
  slots; the `substitutions.mattpocockSkills` map in
  `.claude/persona-config.json` (add `"to-spec": "to-spec"`, subject to the
  name-drift caveat). The actual `<MATTPOCOCK:to-spec>` placeholder is added
  to `spec-master.md`'s `skills:` frontmatter in Track 3 Step 3.1.
- `Suggested model: sonnet` (touches the substitution contract + the
  install-antislop human-facing instructions; must stay consistent with the
  existing 5-slot pattern)
- Acceptance: `grep -rniI 'to-spec' skills/install-antislop/SKILL.md
  README.md` present; `grep -c '"to-spec"' .claude/persona-config.json` ≥ 1;
  `node bin/cli.js --update` exit 0 (the substitution resolves cleanly,
  `applyMattpocockSubs` leaves no `<MATTPOCOCK:to-spec>` residue);
  `grep -rEn '<MATTPOCOCK(:[a-zA-Z0-9_-]+)?>' .claude/agents/` returns 0;
  `bash tests/validate.sh` exit 0.

### Step 2.2 — (folded into Track 3 Step 3.1) place the `to-spec` placeholder
- The `<MATTPOCOCK:to-spec>` placeholder is added to `spec-master.md`'s
  `skills:` line alongside `<MATTPOCOCK:grill-me>` only (`<MATTPOCOCK:to-issues>`
  is task-master's, not spec-master's — OQ5a final) — see Track 3 Step 3.1.
  Listed here only for traceability; no separate acceptance criterion.

### New first-party skill `pathfinder` → `task-master` (item 4, OQ7-final)
**Source & rationale:** `wayfinder`
(github.com/mattpocock/skills → skills/engineering/wayfinder/SKILL.md,
already fetched/read this session) is a decision-mapping planning skill —
chart a big foggy effort as a `wayfinder:map` of decision tickets, one
decision per session, "Plan, don't do," referring to tickets by name,
native blocking edges to render a frontier, fog-of-war for not-yet-specifiable
work. `pathfinder` is a NEW, first-party TAILORED derivative — not a
passthrough and not the `<MATTPOCOCK:slot>` mechanism — scoped narrowly to
`task-master`'s job: turning a finalized spec into **reliable, detailed,
unambiguous dispatch tasks** for `lead-programmer`/`scribe`. The useful
transplants: one-decision/one-unit-per-ticket sizing, refer-by-name over bare
ids, explicit blocking/ordering edges, and "state the question/criterion
precisely or it's not ready to ticket" (maps directly onto the
machine-checkable-criteria rule). It deliberately drops wayfinder's
user-facing grilling/prototype/research ticket types (task-master never
grills — spec-master already did) and its transitive skill deps
(`grilling`/`domain-modeling`/`prototype`), which is exactly why relocating
the idea here rather than installing wayfinder resolves OQ7's mismatch.

### Step 2.3 — Author `pathfinder` skill + wire into task-master
- **Depends on Track 3 Step 3.2** (task-master.md must exist to receive the
  `skills:` reference). Author `skills/pathfinder/SKILL.md` under the plugin
  SOURCE `skills/` dir (same location/pattern as `skills/coding-discipline`),
  register it in `.claude-plugin/plugin.json`, and add `antislop:pathfinder`
  to `task-master.md`'s (both copies) `skills:` line alongside
  `<MATTPOCOCK:to-issues>`. Include a provenance note in the skill body:
  "Derived from mattpocock/skills `wayfinder`, adapted for task dispatch" (it
  is third-party-derived content — traceability required). No
  `<MATTPOCOCK:slot>`, no `substitutions.mattpocockSkills` entry, no
  `.claude/skills/` copy (plugin-source skills reach consumers via the normal
  plugin-ship path, like `coding-discipline`).
- `Suggested model: sonnet` (content synthesis — interpreting another skill's
  content and tailoring it to a new persona's job; judgment-heavy authoring)
- Acceptance: `test -f skills/pathfinder/SKILL.md`;
  `grep -m1 '^name: pathfinder' skills/pathfinder/SKILL.md`;
  `grep -niI 'derived from.*wayfinder\|wayfinder' skills/pathfinder/SKILL.md`
  present (provenance note); `grep -niI 'pathfinder' .claude-plugin/plugin.json`
  present (registration); `grep -n 'antislop:pathfinder' agents/task-master.md
  .claude/agents/task-master.md` present on the `skills:` line;
  `grep -rEn '<MATTPOCOCK(:[a-zA-Z0-9_-]+)?>' .claude/agents/` returns 0;
  `bash tests/validate.sh` exit 0.
- **`reviewer` is untouched by this track** — it keeps only
  `antislop:coding-discipline`; the sole reviewer.md edit remains Track 3
  Step 3.6's hivemind→spec-master rename.

---

## Track 3 — Split `hivemind` → `spec-master` + `task-master`
Ordering: **after Track 1.** Retires `hivemind.md` (both copies) in favor of
two new personas.

**Responsibility allocation (FINAL — all OQ5 boundaries resolved):**

| Current hivemind responsibility | New owner |
|---|---|
| 9-category taxonomy scorecard | spec-master |
| grill-me interrogation (≤5 Qs) | spec-master |
| Open Questions return + relay | spec-master |
| Clarifications section (scorecard + dated lines) | spec-master |
| Check `.claude/reviewed/*.fail` before revising | spec-master |
| Constitution check | spec-master |
| Goal / Context / Risks / numbered Steps + acceptance criteria | spec-master |
| Self-check ("unit tests for the spec") | spec-master |
| Save spec to `docs/plans/` + publish via `to-spec` | spec-master |
| **Debug spec on 2-FAIL-cap escalation** (see Step 3.1b) | spec-master |
| `Suggested model: haiku\|sonnet` per-unit tags | task-master (dispatch decision) |
| `to-tickets`/`to-issues` slicing into grabbable units | **task-master outright** (OQ5a final) |
| Retrieval-contract line | task-master |
| Detailed per-dispatch prompts for lead-programmer + scribe | task-master |
| Convergence follow-ups (append plan steps) | spec-master |

Note the two tracker-publishing roles are distinct and non-overlapping:
`to-spec` (spec-master) publishes the **spec/PRD artifact**; `to-issues`
(task-master) slices that finalized spec into **executable per-unit
tickets**. This is the OQ5a-final division.

### Step 3.1 — Author `spec-master.md` (plugin source)
- Affected: new `agents/spec-master.md`. Move hivemind's spec-owning body
  verbatim (taxonomy scorecard, grill-me, Clarifications, `.fail` check,
  constitution check, Goal/Context/Risks/Steps, Self-check, Open Questions,
  save-to-docs/plans). **Carry every v0.9.0 worked fenced-code example
  verbatim** (Clarifications two-pass example, Self-check itemized example,
  Constitution-check example) — the CHANGELOG documents these are
  empirically required for fable/opus compliance. Frontmatter: `name:
  spec-master`, `model: opus`, `memory: project`, tools mirror hivemind,
  `skills:` = `<MATTPOCOCK:grill-me>, <MATTPOCOCK:to-spec>` ONLY —
  `<MATTPOCOCK:to-issues>` is NOT on spec-master (task-master owns slicing
  outright, OQ5a final). Header comment AFTER the frontmatter delimiter only.
- `Suggested model: sonnet` (careful faithful transfer of the highest-value
  persona; example fidelity is load-bearing)
- Acceptance: `grep -m1 '^name: spec-master$' agents/spec-master.md`;
  `grep -c '```' agents/spec-master.md` ≥ 6 (the worked examples survived);
  `grep -o '<MATTPOCOCK:[a-z-]*>' agents/spec-master.md | sort -u` yields
  exactly `<MATTPOCOCK:grill-me>` and `<MATTPOCOCK:to-spec>` (no to-issues);
  `bash tests/validate.sh` exit 0; file's first byte is `-`.

### Step 3.1b — Define the "debug spec" artifact (spec-master, OQ3 final)
- Affected: `agents/spec-master.md` body (a new dedicated section). Define
  the debug-spec artifact spec-master produces **only** when the
  orchestrator escalates a unit that hit the 2-FAIL cap (per
  persona-protocol "Cap at 2 FAILs per unit"). Shape — a FOCUSED artifact,
  not a from-scratch rewrite:
  1. **Root-cause / diagnosis** — built from the two verbatim defect lists
     durably recorded at `.claude/reviewed/<task-id>.fail` (persona-protocol
     FAIL-record rule): why did two fix attempts fail to close the gap — is
     it a plan gap, an ambiguous/unverifiable acceptance criterion, missing
     context in the dispatch, or the wrong test seam? This is
     **planning-level** diagnosis — the same reproduce→narrow→hypothesize
     pattern as lead-programmer's `<MATTPOCOCK:diagnose>` skill, but one
     level up (diagnosing the SPEC, not the code).
  2. **Revised spec section / steps** — the specific step(s) rewritten with
     corrected acceptance criteria, re-checked against the taxonomy /
     constitution / self-check, flowing back through task-master → dispatch.
  **No new mattpocock skill is warranted** for this (flagged per
  coordinator): spec-master already has Read/Grep/Glob/Bash and the `.fail`
  records; the diagnosis is prose reasoning over durable text, not a code
  repro loop. Adding a `diagnose` slot to spec-master would duplicate a
  code-level skill for a planning-level task — do NOT.
- `Suggested model: sonnet`
- Acceptance: `grep -niI 'debug spec' agents/spec-master.md` present;
  `grep -niI '\.fail' agents/spec-master.md` present (it cites the FAIL
  records as the debug-spec input); `grep -o '<MATTPOCOCK:diagnose>'
  agents/spec-master.md` returns 0 (no new diagnostic skill added);
  `bash tests/validate.sh` exit 0.

### Step 3.2 — Author `task-master.md` (plugin source)
- Affected: new `agents/task-master.md`. Body: reads a finalized spec →
  writes detailed dispatch instructions for `lead-programmer` and `scribe`;
  **owns `to-issues`/`to-tickets` slicing outright** (OQ5a final), per-unit
  model tags, and the retrieval-contract line. Explicitly: does NOT grill the
  user (spec is pre-finalized); if it finds a spec gap mid-flight it returns
  a "spec gap" signal upward to spec-master via the orchestrator and never
  fills the gap itself (OQ4 final). Does NOT own post-FAIL re-plan — a
  reviewer FAIL routes defects to lead-programmer per the existing protocol;
  only a 2-FAIL-cap escalation goes to spec-master's debug spec (OQ3 final).
  Frontmatter: `name: task-master`, `model: sonnet` (opus-eligible, fable
  excluded — given), `skills: <MATTPOCOCK:to-issues>` at THIS step (the
  first-party `antislop:pathfinder` reference is added by Track 2 Step 2.3,
  which depends on this file existing), tools include `Skill` (for `to-issues`
  + `pathfinder`) + `SendMessage`. Header comment after frontmatter only.
- `Suggested model: sonnet` (new persona design; handoff-contract prose)
- Acceptance: `grep -m1 '^name: task-master$' agents/task-master.md`;
  `grep -niI 'grill' agents/task-master.md` returns 0 (task-master never
  grills); `grep -o '<MATTPOCOCK:to-issues>' agents/task-master.md` present;
  `bash tests/validate.sh` exit 0; first byte is `-`.

### Step 3.3 — Create adapted copies + remove hivemind
- Affected: copy both new files to `.claude/agents/spec-master.md` and
  `.claude/agents/task-master.md` with 0.10.0 version stamps (after
  frontmatter); `git rm agents/hivemind.md .claude/agents/hivemind.md`.
- `Suggested model: haiku` (mechanical copy + delete against specced files)
- Acceptance: `test -f .claude/agents/spec-master.md && test -f
  .claude/agents/task-master.md && ! test -f .claude/agents/hivemind.md &&
  ! test -f agents/hivemind.md`. (The `bash tests/validate.sh` exit 0 check
  that was originally here is MOVED to Step 3.3b — see the "Added after Step
  3.3's review" note there. Deleting `hivemind.md` necessarily reddens
  `tests/cli-backfill.test.js`, whose fixtures still read the deleted file, so
  this step's own gate is the file-existence assertion only; validate.sh green
  is restored one step later in 3.3b.)

### Step 3.3b — Unblock `validate.sh` after the hivemind deletion (test-fixture ordering fix)
Added after Step 3.3's review surfaced a plan step-ordering defect (verdict at
`.claude/reviewed/3.3.fail`): Step 3.3 deletes `agents/hivemind.md` +
`.claude/agents/hivemind.md`, but `tests/cli-backfill.test.js` (run inside
`tests/validate.sh`) still reads the deleted source in two subtests, so
`validate.sh` — originally required exit 0 by Steps 3.3/3.4/3.5 — could not
pass until Step 3.6, where the fixture update was (mis-)scoped. The two failing
subtests are NOT symmetric, so they get different treatment here. This is a
deliberate third option over the reviewer's reorder-vs-relax pair: a single
narrowly-scoped test-level deferral keeps `validate.sh exit 0` intact as a real
gate across 3.3b/3.4/3.5 (instead of blanket-relaxing the criterion on three
steps), while letting the trivially-correct list fix land immediately with the
deletion. Scope is ONLY the two subtests below — NOT Step 3.6's wider
cross-file hivemind sweep, and NOT `bin/cli.js`.
- **`tests/cli-backfill.test.js:40` round-trip persona list** — PERMANENT fix
  here. Replace the retired `'hivemind'` token in the round-trip list with the
  two new personas that now exist on disk (e.g. list becomes
  `['scribe', 'milestone-auditor', 'lead-programmer', 'spec-master', 'task-master']`).
  Both new source files carry a `<MATTPOCOCK:>` slot (verified), so this is
  genuine round-trip coverage, not a no-op-return case. This edit does NOT
  depend on Step 3.4 — it merely makes the deletion internally consistent.
- **`tests/cli-backfill.test.js:140` legacy-fixture test** — DEFERRED to Step
  3.6 (its official owner), NOT substantively fixed here. Its fixture reads
  `agents/hivemind.md` and its `buildFileSpecs(['hivemind'])` /
  `fileHashes['.claude/agents/hivemind.md']` assertions exercise the legacy
  one-to-two migration path that Step 3.4 redesigns (`LEGACY_PERSONA_MAP`). A
  substantive fix here would either pull 3.4's migration design forward or
  build a fixture against pre-3.4 `cli.js` that Step 3.4 immediately breaks —
  the exact rework churn the reviewer flagged. Instead, neutralize ONLY this
  one subtest (e.g. swap its `check(...)` invocation for a no-op `skip(...)`
  helper, or comment out the invocation) and leave an inline `TODO(Step 3.6):`
  marker naming the legacy-fixture rewrite that is owed. Do NOT alter any other
  subtest.
- `Suggested model: sonnet` (must correctly distinguish which of the two
  subtests is safe to fix versus must be deferred; a low-judgment mechanical
  patch risks "fixing" `:140` and manufacturing the Step 3.4 rework. Note this
  unit derives from Step 3.3's prior FAIL — `.claude/reviewed/3.3.fail` — which
  is durable evidence it needs more judgment than a `haiku` tag implies.)
- Acceptance: `node tests/cli-backfill.test.js` exit 0 (this is exactly what
  `tests/validate.sh` gates on at line 188); `bash tests/validate.sh` exit 0;
  `grep -q "'spec-master'" tests/cli-backfill.test.js` AND `grep -q
  "'task-master'" tests/cli-backfill.test.js` (the `:40` list now names both
  new personas); `grep -q 'TODO(Step 3.6)' tests/cli-backfill.test.js` (the
  `:140` deferral is explicitly marked for its Step 3.6 un-skip).

### Step 3.4 — Update `bin/cli.js` persona registry + migration
- Affected: `bin/cli.js` — `OPTIONAL_PERSONAS` (remove `hivemind`, add
  `spec-master`, `task-master`); extend `LEGACY_PERSONA_MAP` to map the
  retired `hivemind` token (and the already-mapped legacy `planner`) — note
  a one-to-two split cannot be a plain string map: decide whether legacy
  `hivemind` selection expands to BOTH new personas (recommended) and
  implement accordingly; selection-wizard descriptions (lines ~1305);
  `applyMattpocockSubs` still resolves `<MATTPOCOCK:*>` in the two new files.
- `Suggested model: sonnet` (one-to-two migration is the subtlest cli.js
  change in the plan; non-obvious blast radius)
- Acceptance: `node --check bin/cli.js` exit 0;
  `node tests/cli-backfill.test.js` exit 0 (the `:40` round-trip list was
  already fixed in Step 3.3b; the `:140` legacy fixture remains skipped here
  and is un-skipped/rewritten in Step 3.6 — this step's new legacy-resolution
  test below is the forward semantics); `grep -n 'spec-master\|task-master'
  bin/cli.js` present in
  `OPTIONAL_PERSONAS`; a test asserts legacy `hivemind` selection resolves
  to the new persona set; `bash tests/validate.sh` exit 0.

### Step 3.5 — Rewrite orchestrator routing (both copies)
- Affected: `agents/orchestrator.md` + `.claude/agents/orchestrator.md` (20
  hivemind refs each). Specifically:
  - Routing table "Planning a non-trivial change → hivemind" → two-stage:
    `spec-master` (spec) → `task-master` (dispatch instructions).
  - "Default feature pipeline": the Plan node becomes `spec-master →
    task-master`.
  - "Per-unit model routing" header + "Opus|Fable routing for hivemind and
    milestone-auditor" → "for spec-master and milestone-auditor"; keep the
    three fable conditions (a/b/c) for spec-master with the label change
    only (they transfer as-is — grilling-centric condition (c) is even more
    central for a spec-only persona). Add a NEW subsection "task-master
    model routing": sonnet default, opus-eligible, **fable excluded**.
  - "Relaying hivemind open questions" → "Relaying spec-master open
    questions" (spec-master grills).
  - **FAIL routing (OQ3/OQ4 final):** a normal reviewer FAIL still routes
    the defect list to `lead-programmer` (unchanged). At the **2-FAIL cap**,
    instead of only surfacing to the user, the orchestrator routes to
    **spec-master to produce a debug spec** (Step 3.1b), then task-master
    re-derives dispatch instructions from the revised spec. A mid-flight
    "spec gap" signal from task-master also routes to spec-master (never
    task-master fixing it). task-master is never a re-plan/re-dispatch owner.
  - "Milestone audit gate" step 1 (fetch plan Goal/assumptions/OQ) →
    spec-master's spec; convergence `unconverged-requirement` "route it back
    to hivemind" → **route back to spec-master** (owns the spec + follow-ups).
- `Suggested model: sonnet` (highest-judgment file; two-stage pipeline
  design must stay internally consistent)
- Acceptance: `grep -rniI 'hivemind' agents/orchestrator.md
  .claude/agents/orchestrator.md` returns 0; `grep -c 'task-master model
  routing' .claude/agents/orchestrator.md` ≥ 1; `grep -niI 'fable'
  .claude/agents/orchestrator.md` shows task-master explicitly excluded;
  `grep -niI 'debug spec' .claude/agents/orchestrator.md` present (2-FAIL-cap
  routing to spec-master); `bash tests/validate.sh` exit 0.

### Step 3.6 — Update protocol, lead-programmer, milestone-auditor, reviewer, researcher, tests
- Affected (both copies where they exist): `.claude/persona-protocol.md` +
  `templates/persona-protocol.md` (3 refs — retrieval contract line 84
  "hivemind's plan states…" → task-master's dispatch/slicing owns this;
  FAIL-cap "plan itself has a gap" line 153 → **spec-master writes a debug
  spec** (OQ3 final, Step 3.1b), not a bare surface-to-user; "hivemind never
  writes production code" line 177 → both spec-master AND task-master never
  write production code); `agents/lead-programmer.md` +
  `.claude/agents/lead-programmer.md` ("executes hivemind's plan", "report
  up so hivemind can revise" → spec-master); `agents/milestone-auditor.md` +
  `.claude/agents/milestone-auditor.md` (4 refs incl. description
  "overrides… hivemind" → spec-master, convergence route-back →
  spec-master);
  `agents/reviewer.md` + `.claude/agents/reviewer.md` (1 ref);
  `.claude/agents/researcher.md` + `templates/researcher.md.tmpl` ("briefs
  for hivemind" → spec-master); `hooks/scripts/task-gate.sh` (comment "future
  hivemind/orchestrator spawns"); `skills/install-antislop/SKILL.md` (the
  consumer-facing install skill — the persona-selection wizard prose and the
  placeholder-substitution list at L188 must offer `spec-master`+`task-master`
  instead of `hivemind`; NOTE the grep scope originally OMITTED `skills/`, the
  same enumeration gap Step 1.9 fixes for the rename — this is a substantive
  edit, the ADAPT wizard now selects two personas where it selected one);
  `tests/cli-backfill.test.js`, `tests/validate.sh`, `eval/harness/scaffold.sh`
  (fixtures/persona lists). **Includes un-skipping the `:140` legacy-fixture
  test that Step 3.3b deferred here** (remove the `TODO(Step 3.6)` marker and
  the no-op skip): rewrite that fixture so it no longer reads the deleted
  `agents/hivemind.md` and so its `buildFileSpecs`/`fileHashes` assertions
  reflect Step 3.4's redesigned one-to-two `LEGACY_PERSONA_MAP` migration
  (legacy on-disk `hivemind.md` → the new spec-master+task-master specs).
- `Suggested model: sonnet` (cross-cutting FAIL-routing + convergence
  ownership decisions land here; must match OQ3/OQ4 resolution; the
  install-wizard one-to-two persona change is non-mechanical)
- Acceptance: `grep -rniI 'hivemind' .claude/ agents/ templates/ hooks/
  commands/ tests/ eval/ skills/install-antislop/` returns 0 (excluding
  `bin/cli.js` `LEGACY_PERSONA_MAP` retained token and historical docs);
  `node tests/cli-backfill.test.js` exit 0; `grep -c 'TODO(Step 3.6)'
  tests/cli-backfill.test.js` returns 0 (Step 3.3b's deferral marker is gone
  and the `:140` test runs again, not skipped); `bash tests/validate.sh`
  exit 0.

### Step 3.7 — Update living docs + constitution + this-repo config
- Affected: `README.md` (persona table: replace hivemind row with two rows,
  update prose 5 refs), `CONTEXT.md` (glossary "Persona" optional list),
  `.claude/constitution.md` (P4 line 25 name list), `.claude/wiki/*`
  (architecture, changelog, dependencies, modules/cli), `commands/
  start-feature-team.md` (4 refs — team roster). Then regenerate this repo's
  own `.claude/persona-config.json` `personaSelection`
  (`hivemind`→`spec-master`,`task-master`) via the deterministic path.
- `Suggested model: sonnet` (docs + protected-path constitution + config
  regeneration interplay)
- Acceptance: `grep -rniI 'hivemind' README.md CONTEXT.md
  .claude/constitution.md .claude/wiki/ commands/` returns 0;
  `node bin/cli.js --update` exit 0; `bash tests/validate.sh` exit 0.

### Step 3.8 — File the adapter hivemind-split port as a tracked follow-up (OQ5b final)
The `repo-historian`→`scribe` rename in the adapters lands in THIS release
(Track 1 Step 1.8). The larger `hivemind`→`spec-master`+`task-master` port
of the cursor/codex adapters is DEFERRED to a follow-up.
- Affected: file one GitHub issue (no adapter code changes this release).
- `Suggested model: haiku` (mechanical issue filing against a fixed body)
- Acceptance: `gh issue create --label plan/2026-07-14-threefold-update
  --title "Port hivemind→spec-master/task-master split to cursor+codex
  adapters"` succeeds and returns a URL; the body names the affected files
  (`adapters/cursor/agents/orchestrator.md`,
  `adapters/codex/agents/orchestrator.toml`) and notes the ports lag plugin
  v0.10.0 until closed; `gh issue list --label plan/2026-07-14-threefold-update`
  shows it.

---

## Track 4 — New first-party `roast-work` critique skill for `reviewer`
Author `roast-work` (first-party, plugin-source `skills/` + `plugin.json`,
same mechanism as `pathfinder`) to make the reviewer a detail-driven critique:
contradictions, missing parts, logic gaps, security vulnerabilities, and
thoughtful actionable feedback — written to the mattpocock quality bar. It is
NOT a derivative of any one packaged skill (the researcher's survey found no
direct fit), so — unlike `pathfinder` — it carries no "derived from X"
provenance note.

**Grounding finding (decisive for both tensions):** the current
`.claude/agents/reviewer.md` ALREADY contains most of roast-work's substance:
- "**Refute, don't rubber-stamp**" already hunts edge cases, unhandled
  errors, race conditions, and "security holes (injection, authz, leaked
  secrets, unsafe input)."
- The "**Materiality filter**" already makes **"correctness, security, and
  unmet-acceptance-criteria" three distinct FAIL grounds** — so a security or
  correctness defect is ALREADY a FAIL even when the acceptance-criteria
  command passes. FAIL is already NOT command-only.
- A non-blocking "**notes**" list already exists for everything that isn't a
  blocking defect (style, nice-to-haves).
- "**Verdict — terse, verdict-first, no exceptions**": the final message is
  ONLY the verdict — no prose summary.

### Tension 1 (prose critique vs machine-checkable PASS gate) — RESOLVED, option (a): advisory only
User decision: `roast-work` is **supplementary/advisory, never gating.** It
produces an additional prose critique section attached to the verdict, but
does NOT itself determine PASS/FAIL — the gate stays strictly the
acceptance-criteria command per the existing hard rule. Concretely:
- **Core safety property untouched:** PASS/FAIL is determined exactly as
  today — the machine-checkable acceptance-criteria command plus the existing
  materiality filter (correctness / security / unmet-acceptance-criteria).
  roast-work's critique never flips a verdict, never substitutes for running
  the command; the v2 PASS marker still records `criteria: <command(s) run>`.
- **Output home:** roast-work's critique is a clearly-demarcated ADVISORY
  section appended AFTER the verdict line — an explicit, bounded expansion of
  the reviewer's existing non-blocking "notes" list. Step 4.1 updates
  reviewer.md's "verdict-first, only the verdict" bullet to permit exactly
  this one advisory section and nothing else, so the discipline that the
  verdict line comes first and is never obscured is preserved.
- **No new blocking category:** roast-work does not expand what FAIL means
  (the coordinator's option (b) is explicitly NOT taken). A security or
  correctness defect still FAILs via the EXISTING materiality filter,
  independently of roast-work; roast-work merely narrates/surfaces detail
  advisorily.

### Tension 2 (model routing, "have fable review") — RESOLVED, opus default + fable for heavy lifting
User policy: reviewer's frontmatter `model: opus` is **unchanged as the
default**; **fable is invoked specifically for "heavy lifting."**

**Settled mechanical fact:** the dispatch model is chosen ONCE per subagent
invocation (orchestrator.md "Per-unit model routing": env var > per-call
param > frontmatter). A persona cannot switch models mid-run per skill — so
any fable use is a per-DISPATCH choice the orchestrator makes at spawn time.

**Flagged inversion (do not silently normalize):** this repo's existing
fable-eligibility (spec-master/milestone-auditor) reserves fable for the
LIGHT, well-scoped, mechanical, low-judgment case, with opus the default for
anything needing judgment. The user's "fable for heavy lifting" is the
OPPOSITE characteristic — fable for the MORE demanding work. This is
reconcilable and NOT a true contradiction of the existing principle, because
here fable is used for a DIFFERENT purpose: the non-gating, high-volume
ADVISORY critique sweep across a large surface (where a bulk-context capability
matters), NOT the judgment-critical PASS/FAIL gate. The judgment-critical
gate still follows the existing principle: it stays on **opus, always**. That
is what keeps the core safety property intact while honoring the user's
policy — the weak-tier model is never put on the authoritative gate, only on
the advisory sweep.

**Proposed concrete "heavy lifting" trigger (DEFAULT — stated with reasoning,
tagged like the `Suggested model` per-unit pattern):** the authoritative
opus acceptance-criteria review runs on every unit as today; the orchestrator
ADDITIONALLY dispatches a separate, non-authoritative **fable roast-work
advisory pass** for a unit whose review is "heavy" — defined as meeting ANY
of:
1. **Large surface** — blast radius ≥ ~8 impacted files OR diff ≥ ~400
   changed lines (fable earns its place here on bulk-context handling, per
   the coordinator's hypothesis, not on judgment).
2. **Structural / cross-cutting change** — e.g. a persona split, an
   orchestrator routing rewrite, or a `bin/cli.js` migration (the
   Track-3-scale units in THIS very plan).
3. **Security-sensitive surface** — auth, input parsing/validation, secret
   handling, or migrations touched.
For routine/small units none of these fire: the single opus reviewer runs
roast-work inline (it is a preloaded skill regardless of model), no separate
fable pass. task-master tags heavy units with a `Roast pass: fable` marker
(advisory), mirroring the `Suggested model: haiku|sonnet` per-unit
mechanism, and the orchestrator honors it at dispatch.

Reasoning for the separate-pass shape over "run the whole heavy review on
fable": because the model is fixed per dispatch, the only way to get fable's
heavy-lifting on the critique WITHOUT running the authoritative gate on the
weak tier is a distinct advisory dispatch. This costs an extra fable pass on
heavy units only — cheap relative to the opus gate — and never risks the
safety gate. (User may override to "whole heavy review on fable" if they
accept the gate running on fable; not the default here.)

### Step 4.1 — Author `roast-work` skill + wire into reviewer (model-agnostic)
- Depends on Track 3 Step 3.6 having done reviewer.md's hivemind→spec-master
  rename (sequence after it, or bundle the reviewer.md edits, to avoid a
  write-race). Author `skills/roast-work/SKILL.md` (plugin-source dir, like
  `skills/coding-discipline`); register in `.claude-plugin/plugin.json`; add
  `antislop:roast-work` to `reviewer.md`'s (both copies) `skills:` line
  (currently `antislop:coding-discipline`). ALSO edit reviewer.md's body:
  (i) update the "Verdict — terse, verdict-first" bullet to permit ONE
  clearly-demarcated advisory roast-work critique section appended AFTER the
  verdict line; (ii) add a bullet stating roast-work is advisory/non-gating —
  PASS/FAIL stays determined by the acceptance-criteria command + the existing
  materiality filter, and roast-work never flips a verdict. Skill content: the
  critique rubric (contradictions / missing parts / logic gaps / security
  vulnerabilities / actionable feedback) at the mattpocock detail bar; NO
  third-party-derivation provenance note (it is not adapted from a specific
  skill).
- `Suggested model: sonnet` (safety-critical persona; content-authoring +
  precise reconciliation prose that must not weaken the gate)
- Acceptance: `test -f skills/roast-work/SKILL.md`;
  `grep -m1 '^name: roast-work' skills/roast-work/SKILL.md`;
  `grep -niI 'roast-work' .claude-plugin/plugin.json` present (registration);
  `grep -n 'antislop:roast-work' agents/reviewer.md .claude/agents/reviewer.md`
  present on the `skills:` line; `grep -niI 'advisory\|non-gating\|never
  flips' .claude/agents/reviewer.md` confirms the advisory/non-gating bullet
  landed; `grep -c 'PASS only when every machine-checkable criterion passes'
  .claude/agents/reviewer.md` ≥ 1 (the existing PASS-gate sentence is
  preserved verbatim, not weakened); `grep -rEn '<MATTPOCOCK(:[a-zA-Z0-9_-]+)?>'
  .claude/agents/` returns 0; `bash tests/validate.sh` exit 0.

### Step 4.2 — Orchestrator "heavy lifting" fable routing for the roast-work advisory pass
- Affected: `agents/orchestrator.md` + `.claude/agents/orchestrator.md` — add
  a "Reviewer roast-work advisory pass (fable heavy-lifting)" subsection
  under the model-routing area encoding the trigger above: opus authoritative
  gate always; an ADDITIONAL fable advisory roast pass when a unit is heavy
  (≥8 files / ≥400-line diff / structural / security-sensitive); the fable
  pass is non-authoritative (never writes the PASS/FAIL marker). Also document
  the `Roast pass: fable` per-unit tag task-master emits (Step 3.2 body gets
  one line noting task-master may set it).
- `Suggested model: sonnet` (routing consistency; must not let the advisory
  pass be read as authoritative)
- Acceptance: `grep -niI 'roast.*fable\|fable.*roast\|heavy' 
  .claude/agents/orchestrator.md` present; `grep -niI 'advisory\|non-authoritative'
  .claude/agents/orchestrator.md` present (the fable pass never gates);
  `grep -c 'model: opus' .claude/agents/reviewer.md` ≥ 1 (frontmatter default
  unchanged); `bash tests/validate.sh` exit 0.

---

## Final consolidation unit (after Tracks 1, 2, 3, and 4)
### Step C.1 — Version bump + CHANGELOG + fileHashes
- Affected: `.claude-plugin/plugin.json` + `package.json` → `0.10.0`;
  re-stamp every edited version-stamped file's `<!-- antislop v0.10.0 ... -->`
  line; new `CHANGELOG.md` [0.10.0] entry describing the `repo-historian`→
  `scribe` rename, the `hivemind` split, the `to-spec`→spec-master slot, the
  two new first-party skills (`pathfinder`→task-master, `roast-work`→reviewer
  advisory + fable heavy-lifting routing), and the `LEGACY_PERSONA_MAP`
  migration entries; final `node bin/cli.js --update` to reconcile
  `fileHashes`.
- `Suggested model: sonnet` (release hygiene; Constitution P3)
- Depends on all tracks: Steps 1.8, 1.9, 1.10, 2.1, 2.3, 3.8, 4.2.
- Acceptance: `grep -c '0.10.0' .claude-plugin/plugin.json package.json` ≥ 1
  each; `grep -c '\[0.10.0\]' CHANGELOG.md` ≥ 1; `node bin/cli.js --update`
  exit 0 (no unresolved diffs); `bash tests/validate.sh` exit 0;
  `grep -rEn '<MATTPOCOCK(:[a-zA-Z0-9_-]+)?>' .claude/agents/` returns 0.
  **Final live-surface sweep backstop** (added after two files slipped the
  original 8-step enumeration): `grep -rniI 'repo-historian\|hivemind'
  agents/ .claude/agents/ templates/ commands/ hooks/ skills/install-antislop/
  README.md CONTEXT.md .claude/wiki/ .claude/constitution.md` returns 0,
  EXCEPT the intentional `bin/cli.js` `LEGACY_PERSONA_MAP` tokens and allowed
  test migration-assertions (historical docs/specs/plans/prototype and prior
  CHANGELOG entries are out of scope).

---

## Open Questions
1. **(Track 2) RESOLVED** — the skill is the existing published `to-spec`
   from `mattpocock/skills`, wired via the `<MATTPOCOCK:to-spec>` slot,
   consumed by `spec-master`. No first-party authoring.
2. **(Track 2) RESOLVED / MOOT** — no new export path needed; `to-spec`
   ships via the same install-antislop TUI + `<MATTPOCOCK:slot>` mechanism as
   the other 5 mattpocock skills.
3. **(Track 3) RESOLVED** — Post-FAIL routing: a normal reviewer FAIL routes
   defects to `lead-programmer` (unchanged); at the **2-FAIL cap** the
   orchestrator routes to **spec-master to produce a debug spec** (Step 3.1b,
   diagnosis over the two `.fail` records → revised steps), then task-master
   re-derives dispatch instructions. task-master is never a re-plan owner. No
   new mattpocock diagnostic skill added to spec-master (existing tools + the
   `.fail` records suffice; a code-level `diagnose` skill would be the wrong
   altitude).
4. **(Track 3) RESOLVED** — yes: task-master returns a "spec gap" signal
   upward (orchestrator → spec-master) on a discovered spec gap and never
   fills it itself, mirroring lead-programmer's "report up so spec-master can
   revise." Encoded in Step 3.2.
5. **(Track 3) RESOLVED (both sub-questions):** (a) `to-issues`/`to-tickets`
   slicing lives on **task-master outright** — spec-master does NOT carry the
   `to-issues` slot (Steps 3.1/3.2 updated; allocation table finalized).
   (b) **Rename ports to adapters in THIS release** (Track 1 Step 1.8) but
   **defer the hivemind→split port** to a tracked follow-up issue filed via
   `gh` (Step 3.8) — a full two-persona port is materially larger and ports
   may lag the plugin.
6. **(Track 2 / Track 3) RESOLVED — layer (a).** How `to-spec` reconciles
   with spec-master's existing format: `to-spec` carries its OWN PRD template
   (Problem Statement / Solution / User Stories / Implementation Decisions /
   Testing Decisions / Out of Scope) and publishes ONE spec to the tracker;
   spec-master (inheriting hivemind) has the elaborate Goal → Context →
   Clarifications → Constitution check → Steps → Self-check format. Confirmed
   by coordinator: **layer** `to-spec`'s template on top of the v0.9.0
   spec-kit machinery, do NOT replace it (Track 3 Step 3.1). Option (c)
   ("publish replaces slicing") was mooted by OQ5a-final — task-master slices
   via `to-issues`, distinct from `to-spec`'s single-spec publish.
7. **(Track 2 item 4) RESOLVED — scope changed.** `wayfinder` is NOT wired
   into `reviewer` (the semantic-mismatch concern was accepted). Instead a
   new first-party skill `pathfinder` — a tailored derivative of wayfinder —
   is authored for `task-master` (Track 2 Step 2.3, shipped via the
   plugin-source `skills/` + `plugin.json` path). This sidesteps wayfinder's
   missing transitive deps (not installing it, adapting its content) and
   relocates the idea to the persona it fits. (`reviewer` gains a DIFFERENT
   first-party skill, `roast-work`, in Track 4 — but not wayfinder.)
8. **(Track 4 tension 1) RESOLVED — advisory only (option a).** `roast-work`
   produces a supplementary prose critique section attached to the verdict
   but never determines PASS/FAIL; the gate stays strictly the
   acceptance-criteria command + existing materiality filter. Core
   machine-checkable-criteria safety property untouched. Encoded in Step 4.1
   (incl. the reviewer.md verdict-format + advisory/non-gating bullets).
9. **(Track 4 tension 2) RESOLVED — opus default, fable for heavy lifting.**
   Reviewer frontmatter stays `model: opus` (authoritative gate always opus).
   The orchestrator additionally dispatches a non-authoritative fable
   roast-work advisory pass for HEAVY units — concrete trigger: ≥~8 impacted
   files OR ≥~400-line diff OR structural/cross-cutting change OR
   security-sensitive surface; tagged `Roast pass: fable` by task-master like
   the `Suggested model` pattern. Inversion vs the existing
   fable=light-work pattern is flagged and reconciled (fable does the
   non-gating bulk critique, never the judgment-critical gate). Encoded in
   Step 4.2.

## Self-check
- CHK1: Is item 2's skill content defined enough to write acceptance
  criteria? — PASS (resolved: existing published `to-spec` skill, wired via
  the `<MATTPOCOCK:to-spec>` slot; Step 2.1 has runnable criteria).
- CHK2: Does the plan define a working export path for the skill to reach
  consumers? — PASS (resolved: same install-antislop TUI + slot mechanism as
  the other 5 mattpocock skills; no new path).
- CHK3: Do Tracks 1 and 3 agree on edit order for the files they both touch
  (orchestrator, lead-programmer, protocol, cli.js, README, config)? — PASS
  (Risks section mandates Track 1 fully before Track 3; no parallelization).
- CHK4: Is the post-FAIL re-plan owner unambiguously assigned? — PASS
  (resolved: normal FAIL → lead-programmer; 2-FAIL cap → spec-master debug
  spec, Step 3.1b; task-master never re-plans — Steps 3.5/3.6 determinate).
- CHK5: Is the spec-master vs task-master boundary defined for every current
  hivemind responsibility? — PASS (resolved: `to-issues` slicing is
  task-master's outright; allocation table finalized, Steps 3.1/3.2 updated).
- CHK6: Does every implementation step carry a runnable acceptance criterion
  (Constitution P5 / machine-checkable rule)? — PASS (every executable step
  lists a grep/validate.sh/node exit-code check; Step 2.2 is a traceability
  pointer folded into Step 3.1, not a separate executable step).
- CHK11: Is spec-master's output-format prose determinate given `to-spec`
  brings its own template + tracker-publish behavior? — PASS (resolved OQ6:
  layer `to-spec` on top of the v0.9.0 spec-kit machinery; Step 3.1 default).
- CHK12: Is item 4's skill placement consistent with the target persona's
  role? — PASS (resolved OQ7: dropped wayfinder→reviewer; author first-party
  `pathfinder` for task-master via the plugin-source path — Step 2.3 has
  runnable criteria incl. a provenance-note check).
- CHK7: Does the plan preserve the v0.9.0 worked-example fenced blocks when
  moving spec content into spec-master? — PASS (Step 3.1 mandates verbatim
  carry + a `grep -c '```' ≥ 6` check).
- CHK8: Is the version-bump/CHANGELOG obligation (Constitution P3) covered
  for a release that touches version-stamped files? — PASS (Step C.1).
- CHK9: Does the plan keep the deterministic-config path (Constitution P2)
  for `fileHashes`/`personaSelection` instead of hand-editing? — PASS (Steps
  1.7, 3.7, C.1 regenerate via `node bin/cli.js --update`; cli.js registry
  edits precede regeneration).
- CHK10: Are new persona references kept conditionally phrased (Constitution
  P4)? — PASS (Steps 1.3, 3.5, 3.6 state "conditionally phrased"; the
  constitution's own P4 line is in the edit set).
- CHK13: Does Track 4 preserve reviewer's machine-checkable-criteria PASS
  gate (core safety property)? — PASS (Tension 1 resolved advisory-only;
  Step 4.1 acceptance greps that the "PASS only when every machine-checkable
  criterion passes" sentence is preserved verbatim and that roast-work is
  marked non-gating; the fable pass in Step 4.2 is explicitly
  non-authoritative and never writes the PASS marker).
- CHK14: Is the "heavy lifting" fable trigger concretely defined (not vague)?
  — PASS (Step 4.2 / OQ9 give a runnable-ish threshold: ≥~8 files OR ≥~400
  lines OR structural OR security-sensitive, tagged `Roast pass: fable`;
  authoritative gate stays opus).

- CHK15 (post-3.3-review amendment): Is every step that requires
  `validate.sh exit 0` (3.3b, 3.4, 3.5) actually satisfiable at its own point
  in the sequence? — was FAIL (conflicting: 3.3/3.4/3.5 required validate.sh
  green while the cli-backfill fixture fix was scoped downstream to 3.6) —
  revised in place: Step 3.3's own gate drops validate.sh (file-existence
  only); new Step 3.3b fixes the `:40` list now and defers the 3.4-coupled
  `:140` fixture to 3.6 with a marked skip; Steps 3.4/3.6 notes and acceptance
  greps corrected to match. See `.claude/reviewed/3.3.fail`.

**All CHK items now PASS.** Every Self-check FAIL raised during planning
(CHK1/CHK2 item-2 content/export; CHK4/CHK5 FAIL-routing/persona-boundary;
CHK11 spec format; CHK12 item-4 skill placement) was resolved through the
Open-Questions round-trips with the coordinator. No FAIL remains; every Open
Question is RESOLVED. The plan is ready to slice.

## Scribe update hint
On completion, the renamed `scribe` should record in `.claude/wiki/changelog.md`
and `CONTEXT.md`: (1) the `repo-historian`→`scribe` rename and its
`LEGACY_PERSONA_MAP` migration entry; (2) the `hivemind`→`spec-master`+
`task-master` split, the responsibility-allocation table, and the resolved
handoff contract (OQ3/OQ4 answers); (3) the `to-spec` mattpocock slot on
spec-master, the new first-party `pathfinder` skill on task-master (derived
from `wayfinder`), the resolution of the `to-spec`/format-layering question
(OQ6), and the new first-party `roast-work` advisory-critique skill on
reviewer with its opus-gate / fable-heavy-lifting routing (OQ8/OQ9). Add an
ADR under `docs/adr/` for the hivemind split (it's a structural
persona-architecture decision on the order of ADR 0001/0002); consider a
second short ADR for the reviewer advisory-critique / dual-model-routing
decision, since it touches the core safety property. Bump
`.claude/constitution.md` only if a principle's persona-name list changed
materially (it did — P4).
