# Spec: Port hivemind→spec-master/task-master split to Cursor + Codex adapters (issue #35)

## Goal
Bring the Cursor and Codex adapter orchestrator routing content in line with
the main Claude Code orchestrator's two-persona split — replace the two live
`hivemind` references in `adapters/cursor/agents/orchestrator.md` and
`adapters/codex/agents/orchestrator.toml` with the `spec-master` (produces the
finalized spec) → `task-master` (slices it into dispatch-ready units)
two-stage vocabulary, format-adapted per dialect, so no live routing/persona
content in this repo still names the retired `hivemind` persona.

## Context
GitHub issue #35 tracks deferred follow-up work from the 2026-07-14
threefold update (ADR 0003): the main orchestrator (`agents/orchestrator.md`)
migrated `hivemind` → `spec-master` + `task-master`, but the Cursor and Codex
adapter orchestrators were never updated and still route "Planning a
non-trivial change" to `hivemind`.

**Core determination (the question the task asked me to investigate): this is
a STRAIGHT VOCABULARY PORT, format-adapted per dialect — not a
capability-limited redesign.** Evidence:
- The two-stage flow requires only two *sequential* subagent dispatches from
  the orchestrator (dispatch spec-master, receive spec, then dispatch
  task-master) — the *same spawning depth* as the current single `hivemind`
  dispatch. It needs no nested subagent spawning. Both Cursor and Codex
  already spawn subagents today (that is how their orchestrators route to
  `lead-programmer`, `explorer`, and `reviewer`). There is therefore **no
  capability barrier** that would justify a different persona shape for these
  targets.
- Neither `spec-master` nor `task-master` ships in the Cursor/Codex MVP
  persona set (`CURSOR_MVP_PERSONAS`/`CODEX_MVP_PERSONAS` in `bin/cli.js` =
  `orchestrator, explorer, lead-programmer, reviewer` only). So both
  references are — and remain after this port — `if present` conditionals
  with a "sketch a short plan yourself" fallback, exactly like the existing
  `scribe` references in the same files. This mirrors the v0.10.0
  `repo-historian`→`scribe` rename port precedent, which was likewise a
  routing-vocabulary update and did *not* add a `scribe` agent file to the
  adapters.
- The adapter orchestrator files are **static templates copied verbatim** via
  `copyStamped` (`scaffoldCursor`/`scaffoldCodex` in `bin/cli.js`). No
  substitution/rendering logic touches the prose body. `migrateLegacyPersonaTokens`
  rewrites only the `personaSelection` *config array* (`planner`→`hivemind`→
  `spec-master`+`task-master`), never orchestrator prose — and since neither
  adapter's MVP selection ever contains `hivemind`, that migration path is
  irrelevant here. The correct fix is a direct hand-edit of the two template
  files (see Constitution check P2 — no deterministic-script path exists for
  this prose, so hand-editing is correct, not a violation).

**Exact live `hivemind` sites (whole-repo swept):** exactly two files, two
lines each.
- `adapters/cursor/agents/orchestrator.md`: L27 (routing table "Planning"
  row) and L82 (default feature pipeline).
- `adapters/codex/agents/orchestrator.toml`: L32 (routing table "Planning"
  row) and L88 (default feature pipeline), both inside the
  `developer_instructions = '''...'''` block.

All other repo `hivemind` occurrences are historical records that should
*retain* the name (ADR 0003, old plans/specs/changelog/wiki, `bin/cli.js`
legacy-migration logic + its `cli-backfill.test.js`, `docs/design.md` design
rationale). The only borderline non-orchestrator sites are two
current-state persona *enumeration* lines in the port-notes docs — see Open
Question 1 / Step 4.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-07-17 Functional scope & success criteria: Q Is the fix a vocabulary
  port or a capability-driven redesign for Cursor/Codex? → A (self-resolved):
  straight vocabulary port, format-adapted — no capability barrier exists (two
  sequential dispatches, same spawning depth as the current single hivemind
  dispatch; both targets already spawn subagents).
- 2026-07-17 Technical constraints & tradeoffs: Q Are the adapter orchestrator
  files rendered/substituted, or static templates? → A (self-resolved): static
  templates copied verbatim by copyStamped; no cli.js path touches the prose
  body, so a direct hand-edit is the correct mechanism (confirmed against
  scaffoldCursor/scaffoldCodex and migrateLegacyPersonaTokens).
- 2026-07-17 Functional scope & success criteria: Q Do the adapter
  `lead-programmer` files (named "if applicable" in the issue) also reference
  hivemind? → A (self-resolved): no — `grep -c hivemind` returns 0 for both
  `adapters/cursor/agents/lead-programmer.md` and
  `adapters/codex/agents/lead-programmer.toml`. Not applicable; no step for
  them.
- 2026-07-17 External dependencies & integrations: Q Does issue #78
  (`docs/plans/2026-07-17-git-based-install-convergence.md`) overlap these
  files? → A (self-resolved): no overlap — #78 touches only `README.md` (all
  its steps), and its own Risk section explicitly avoids `orchestrator.md`
  prose. Disjoint file sets.
- 2026-07-17 Edge cases / failure handling: Q What breakage modes must the
  port guard against? → A (self-resolved): (a) leaking the plugin source's
  unicode arrows (→) / em-dashes (—) into the adapters, which use ASCII `->`
  throughout (both files currently contain zero unicode arrows — verified);
  (b) corrupting the Codex TOML by editing inside the triple-quoted string —
  guarded by validate.sh's tomllib parse. Both covered by ACs below.
- 2026-07-17 Terminology consistency: Q Should the two stale "hivemind"
  persona-enumeration lines in the port-notes docs be updated too? → A: see
  Open Question 1 (recommended: yes, as Step 4).
- 2026-07-17 Completion / acceptance signals: Q What is the machine-checkable
  done signal? → A (self-resolved): `grep -c hivemind` = 0 on both orchestrator
  files, `spec-master`+`task-master` both present in each, and `bash
  tests/validate.sh` exit 0 (which includes the Codex TOML parse + Cursor
  frontmatter checks).

## Risks / dependencies
- **ASCII-arrow / dialect convention.** The plugin source
  (`agents/orchestrator.md`) uses unicode arrows (→) and em-dashes (—); the
  adapters deliberately use ASCII `->` and hyphens. The port must transcribe
  the *meaning*, not copy-paste the plugin's glyphs. AC5 guards this.
- **Codex TOML fragility.** The Codex edit lands inside a
  `developer_instructions = '''...'''` triple-quoted string. No TOML
  structural token may be disturbed; validate.sh's tomllib load (AC3/AC4) is
  the guard.
- **Constitution P3 (version-stamp discipline) is triggered.** The adapter
  files are version-stamped templates (`copyStamped`), so this change *must*
  bump `.claude-plugin/plugin.json` and add a CHANGELOG entry (Step 3) — this
  is mandatory, not optional. The `--update` mechanism depends on the version
  changing when content does.
- **No adapter↔plugin parity/sync test exists.** The only tests are
  `tests/validate.sh` (structural) and `tests/cli-backfill.test.js` (persona
  token backfill). Nothing auto-fails if the adapter orchestrator drifts from
  the plugin orchestrator, so correctness rests on the ACs here, not a
  pre-existing guard.
- No prior `.claude/reviewed/*.fail` record matches any unit in this spec
  (checked); no defect history to carry forward.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume" (MUST): satisfied — every step's acceptance
  criteria are runnable `grep`/`tests/validate.sh` commands, not visual
  inspection.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  there is *no* script-driven path for the orchestrator prose body
  (`migrateLegacyPersonaTokens` rewrites only the persona-config selection
  array, not template prose). Hand-editing the two static templates is the
  correct and only mechanism; extending `bin/cli.js` here would be wrong.
- P3 "Version-stamp discipline" (MUST): satisfied by Step 3 — the change to
  the version-stamped adapter templates bumps `.claude-plugin/plugin.json` and
  adds a CHANGELOG entry.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the ported
  text keeps both `spec-master` and `task-master` conditionally phrased ("both
  if present; otherwise sketch a short plan yourself"), preserving the
  fallback in adapters that don't ship these personas.
- P5 "tests/validate.sh is the merge gate" (MUST): satisfied — `bash
  tests/validate.sh` exit 0 is an acceptance criterion on every content step.

## Step 1 — Port the Cursor orchestrator routing vocabulary
Affected files: `adapters/cursor/agents/orchestrator.md` (two edit sites, no
other lines).

Site A — routing-table "Planning" row (currently L27-28):
- Replace the `hivemind`-based row with the two-stage phrasing, ASCII arrows,
  conditional fallback preserved. Target text:
  `- Planning a non-trivial change -> two-stage: \`spec-master\` (produces the
  finalized spec) -> \`task-master\` (slices it into dispatch-ready units),
  both if present; otherwise sketch a short plan yourself before delegating to
  lead-programmer`

Site B — default-feature-pipeline line (currently L81-84):
- Replace `-> hivemind (if present) ->` with `-> spec-master -> task-master
  (both if present) ->` in the `(researcher first ...) -> ... ->
  lead-programmer -> reviewer ...` chain.

Acceptance criteria (all must hold):
- AC1: `grep -c hivemind adapters/cursor/agents/orchestrator.md` returns `0`.
- AC2: `grep -q 'spec-master' adapters/cursor/agents/orchestrator.md && grep
  -q 'task-master' adapters/cursor/agents/orchestrator.md` exits 0.
- AC3: both personas kept conditional —
  `grep -q 'both if present' adapters/cursor/agents/orchestrator.md` exits 0.
- AC5 (shared): `! grep -qP '[→—]' adapters/cursor/agents/orchestrator.md`
  exits 0 (no unicode arrow/em-dash leaked in from the plugin source).
- AC6 (shared): `bash tests/validate.sh` exits 0 (Cursor frontmatter check
  covers this file).

## Step 2 — Port the Codex orchestrator routing vocabulary
Affected files: `adapters/codex/agents/orchestrator.toml` (two edit sites,
both inside the `developer_instructions = '''...'''` block; no TOML
structural change).

Site A — routing-table "Planning" row (currently L32-33) and Site B —
default-feature-pipeline line (currently L88): apply the *same* two
replacements as Step 1, transcribed with ASCII arrows, inside the
triple-quoted string. Do not alter any TOML key, quoting, or the surrounding
CODEX PORT NOTE comment.

Acceptance criteria (all must hold):
- AC1: `grep -c hivemind adapters/codex/agents/orchestrator.toml` returns `0`.
- AC2: `grep -q 'spec-master' adapters/codex/agents/orchestrator.toml && grep
  -q 'task-master' adapters/codex/agents/orchestrator.toml` exits 0.
- AC3: `grep -q 'both if present' adapters/codex/agents/orchestrator.toml`
  exits 0.
- AC4 (TOML integrity): `python3 -c "import tomllib; d=tomllib.load(open('adapters/codex/agents/orchestrator.toml','rb')); assert d['name'] and d['description'] and d['developer_instructions'].strip()"`
  exits 0.
- AC5 (shared): `! grep -qP '[→—]' adapters/codex/agents/orchestrator.toml`
  exits 0.
- AC6 (shared): `bash tests/validate.sh` exits 0 (Codex TOML-validity block
  covers this file).

## Step 3 — Version bump + CHANGELOG entry (Constitution P3, MANDATORY)
Affected files: `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- Bump `.claude-plugin/plugin.json` `"version"` from `0.13.4` to `0.13.5`
  (patch — prose/vocabulary correction, no behavior change; see Open Question
  2 if a different bump is preferred).
- Add a matching `## [0.13.5] - <date>` CHANGELOG section describing the
  Cursor/Codex adapter `hivemind`→`spec-master`+`task-master` routing port and
  citing "Fixes #35".

Acceptance criteria:
- AC1: `grep -q '"version": "0.13.5"' .claude-plugin/plugin.json` exits 0.
- AC2: `grep -q '\[0.13.5\]' CHANGELOG.md` exits 0.
- AC3: `grep -q '#35' CHANGELOG.md` exits 0.
- AC4: `python3 -m json.tool .claude-plugin/plugin.json >/dev/null` exits 0.

## Step 4 — (Conditional on Open Question 1; recommended: include) Sync stale port-notes persona enumerations
Affected files: `docs/cursor-port-notes.md` (L144), `docs/codex-port-notes.md`
(L117).
- Each doc has a "The optional personas (hivemind, scribe, milestone-auditor,
  researcher) are not ported in this MVP pass..." line. Replace the leading
  `hivemind` token with `spec-master, task-master` so the enumeration reflects
  current persona vocabulary. Do not touch historical `hivemind` references
  elsewhere (ADR 0003, design.md rationale, old plans/specs) — those correctly
  record history.

Acceptance criteria:
- AC1: `grep -c hivemind docs/cursor-port-notes.md docs/codex-port-notes.md`
  returns `0` for both files.
- AC2: `grep -q 'spec-master, task-master' docs/cursor-port-notes.md && grep
  -q 'spec-master, task-master' docs/codex-port-notes.md` exits 0.
- AC3: `bash tests/validate.sh` exits 0.

## Open Questions
1. **Port-notes scope (Step 4).** The issue's literal affected-files list
   names only the two orchestrator files, but `docs/cursor-port-notes.md`
   (L144) and `docs/codex-port-notes.md` (L117) each still enumerate
   `hivemind` as a currently-optional persona — now factually stale. Include
   the one-line-each fix (Step 4) in this pass, or leave port-notes for a
   separate docs sweep? **[RECOMMENDED: include as Step 4 — same rename class,
   trivial, keeps adapter docs internally consistent; it is isolated in its
   own step so it can be dropped without affecting Steps 1-3.]**
2. **Version bump target (Step 3).** `0.13.5` (patch) is the recommended bump
   for a prose/vocabulary correction with no behavior change. Confirm patch is
   right rather than a minor (`0.14.0`) — ADR 0003 called the split a "larger"
   change, but the *adapter port* itself adds no new capability.
   **[RECOMMENDED: 0.13.5 patch.]**

## Self-check
- CHK1: Is the port-vs-redesign question resolved with stated evidence? — PASS
- CHK2: Are all live `hivemind` sites enumerated with exact file+line anchors? — PASS
- CHK3: Does every content step carry a runnable acceptance criterion? — PASS
- CHK4: Is the ASCII-arrow convention preservation defined and checkable? — PASS (AC5, both steps)
- CHK5: Does the ported text keep `spec-master`/`task-master` conditionally phrased (Constitution P4)? — PASS (AC3, Steps 1-2)
- CHK6: Is Constitution P3 (version bump + CHANGELOG) covered by a step? — PASS (Step 3)
- CHK7: Is the port-notes scope decision represented in Open Questions? — PASS (OQ1 ↔ Step 4)
- CHK8: Is the #78 file-overlap question answered? — PASS (Clarifications; disjoint, README-only)
- CHK9: Is the adapter `lead-programmer` "if applicable" question resolved? — PASS (Clarifications; 0 refs, no step)

## Scribe update hint
No wiki/CONTEXT change needed — this is a vocabulary-parity correction, not a
new capability. The authoritative design record already exists at
`docs/adr/0003-hivemind-split-spec-master-task-master.md`; closing #35 makes
its "Adapter ports (cursor/codex) lag this release" note obsolete, so a scribe
pass could optionally strike that lag caveat from the ADR's Consequences.
