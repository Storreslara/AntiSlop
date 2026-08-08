# Protocol delivery tiers

The shared persona protocol exists in two canonical versions — **full tier** and **slim tier** — which are inlined into persona bodies at generation time. This dual-tier approach is not documented in `templates/` metadata and is easy to miss, but it silently determines whether a protocol change reaches a persona at all.

Since the 2026-08-01 efficiency-remediation pass (issue #190, finding F1),
delivery is not just a tier — full-tier personas also each get a
**per-persona section selection** within that tier. See "Per-persona
section selection within the full tier" below.

## Why two tiers exist

The protocol consists of shared rules (structural questions go to explorer, agent-teams mode semantics, terminal status lines, etc.) that apply to all personas. However:

- **Explorer, researcher, and scribe** are lightweight personas that run frequently and must return distilled answers. A full protocol section on "how to write long documentation" or detailed review discipline is out-of-scope for them.
  
- **Orchestrator, spec-master, task-master, lead-programmer, reviewer, milestone-auditor** carry full responsibility and need the complete shared ruleset.

Rather than having two separate protocols maintained in parallel (which defeats the purpose of "shared"), the `bin/cli.js` generation machinery inlines one of two canonical files into each persona's final body at `.claude/agents/*.md` generation time.

## The two files

**Full tier** (`templates/persona-protocol.md`): 300 lines
- Target personas: `orchestrator`, `lead-programmer`, `spec-master`, `task-master`, `reviewer`, `milestone-auditor`
- 16 sections: Structural questions → explorer, Answer shape, Scope Bash output, Agent-teams mode, WIP sentinel, Terminal status line, Running acceptance-criteria commands, Retrieval contract, Machine-checkable criteria, Review ownership, Pending-review flag, FAIL record, Third verdict (insufficient-context), Continuing after a FAIL verdict, Reviewer roast-work advisory pass trigger, A note on `memory`

  For what the WIP sentinel, pending-review flag, and terminal status line
  sections actually say and enforce (this page only tracks which persona
  *receives* them, not their substance), see
  [persona-handoff-mechanisms.md](persona-handoff-mechanisms.md).

**Slim tier** (`templates/persona-protocol-slim.md`): 83 lines
- Target personas: `explorer`, `researcher`, `scribe`
- 6 sections: Structural questions → explorer, Answer shape, Scope Bash output, Agent-teams mode, Terminal status line, A note on `memory`

## How inlining works

**No `@import`:** The protocol is not pulled via a Claude Code `@import` directive (that was proven not to resolve inside a subagent body in issue #121 Step 2). Instead:

1. `bin/cli.js:34-38` defines `SLIM_TIER_PERSONAS` as `['explorer', 'researcher', 'scribe']`
2. At generation time (`cli.js:466-490`, `renderCleanBody` and `inlineProtocolBlock`), for each persona:
   - If it's in `SLIM_TIER_PERSONAS`, inline the contents of `templates/persona-protocol-slim.md`
   - Otherwise, inline the contents of `templates/persona-protocol.md`
3. The inlined text is inserted verbatim into the persona's final body
4. The persona is stamped with its content hash (for `--update` idempotency)

**Deterministic and version-controlled:** The inlining is deterministic — a given persona always receives the same text, every time the CLI runs. Both canonical files are committed to the repo, so any protocol change is a git commit and subject to review.

## Per-persona section selection within the full tier

The full/slim split answers "which canonical file does this persona get";
it does not answer "which sections of that file". Since issue #190 (the
2026-08-01 efficiency-remediation pass, finding F1), `bin/cli.js` answers
the second question too, for full-tier personas only: each one inlines
just the subset of `templates/persona-protocol.md`'s 16 `## `-delimited
sections that mechanically applies to its role, instead of the full
document regardless of role.

**The mechanism** (`bin/cli.js`):
- `PROTOCOL_SECTIONS_BY_PERSONA` is a map from persona name to an
  **exhaustive** `{ include, drop }` classification of every canonical
  section — exhaustive on purpose, so a section later added to the
  template forces a per-persona decision instead of silently reaching
  everyone (cost) or no one (a lost rule). `assertProtocolMatrixComplete`
  enforces this at module load, per row, not just as a union check (a
  union check would miss a header quietly dropped from one row while
  another row still witnesses it).
- `selectProtocolSections(name, tier, gatedAgents)` reads that map and
  returns the headers a given persona's mirror should carry, in template
  order.
- `orchestrator` is deliberately left untrimmed (`include: [...all 16],
  drop: []`) — it routes every one of these mechanisms and is the one
  persona that genuinely executes on all of them.
- Measured, currently-shipped savings (words dropped from the full
  16-section total, measured directly from the generated
  `.claude/agents/*.md` mirrors against the current
  `templates/persona-protocol.md`): `reviewer` ~16% (450 words),
  `lead-programmer` 597 words/17%, `task-master` ~28%, `spec-master` ~30%,
  `milestone-auditor` saves the most, ~41% (1,157 words). Re-measure from
  the live mirrors rather than trusting any hardcoded percentage here —
  these numbers drift whenever a section's prose changes (e.g. Step 7 of
  the same pass added ~48 words to "Pending-review flag", which changed
  every trimmed persona's savings that drops that section).

**Three fail-closed behaviours** (all required, not optional — this is
what makes trimming defensible rather than taste, per the pass's risk R1
that trimming can silently drop a rule a persona needs):
1. **Unknown persona name → all sections.** `selectProtocolSections`
   returns every canonical header if `name` has no row in the matrix, so a
   persona the matrix doesn't know about is never silently starved.
2. **A matrix entry naming a header that doesn't exist in the template →
   throw.** Renaming a canonical `## ` heading without updating every row
   that references it crashes `bin/cli.js` at load (via
   `assertProtocolMatrixComplete`) rather than silently dropping that
   persona's coverage of the renamed section.
3. **Any persona listed in `.claude/persona-config.json`'s `gatedAgents` →
   force-include "WIP sentinel" and "Pending-review flag" regardless of
   its matrix row.** This is `GATED_AGENT_SECTIONS`, checked separately by
   `assertGatedSectionsCanonical` (same rename-safety argument as above,
   applied to this smaller override list). It's why `lead-programmer` (the
   one gated persona today) keeps "Pending-review flag" even though its
   row's `drop` list still names it — config wins over the row, so the
   matrix can never go stale against `gatedAgents`. (An earlier fix-round
   on this same pass — issue #191 — found the config-driven override had
   only been wired into the `--update` render path, not the fresh-scaffold
   path; both call sites now thread `gatedAgents` through.)
4. **Slim tier is untouched by all of the above** — `selectProtocolSections`
   only applies section selection when `tier === 'full'`; a slim-tier
   persona still gets its entire canonical file, unchanged.

**Claude-Code-only by construction.** Both adapter ports —
`adapters/cursor/rules/persona-protocol.mdc` and
`adapters/codex/agents-md-fragment.md` — are hand-adapted condensed
rewrites with no per-persona seam (a single project-wide rule file /
`AGENTS.md` fragment, not one body per persona), so `bin/cli.js` never
regenerates them and they keep carrying the union regardless of role. See
[modules/adapters.md](modules/adapters.md). The adapter-parity test
(`tests/adapter-protocol-parity.test.js`) is unaffected: it derives
canonical sections from the template's `## ` headers, and trimming
*selects* sections per persona at Claude Code's inline time — it never
adds, removes, or renames a canonical header, so both parity maps stay
accurate.

**`.claude/persona-protocol.md` is back on disk, deliberately.** An
earlier decision (`OQ11=DROP`, issue #121-era) deleted this file on every
`--update`, on the premise that "nothing reads it at runtime" once every
full-tier persona carried the complete protocol inline. Trimming breaks
that premise: a persona whose excerpt drops a rule now needs somewhere to
read it. `bin/cli.js` reverses `OQ11=DROP` — the file is regenerated,
version-stamped, and restored by `--update` as the complete, untrimmed
reference copy. Nothing auto-loads it (zero tokens per dispatch); it
exists purely for a trimmed persona (or a human) to read on demand.

## Critical consequence for maintainers

**Adding a new protocol section to the full tier is a minimum four-file change:**

1. Edit `templates/persona-protocol.md` (the full tier)
2. Add an entry to both adapter parity maps (`codexMap` and `cursorMap` in `tests/adapter-protocol-parity.test.js`), deciding whether the section is:
   - `probe: '<content that must appear in the port>'` (the section reaches the port), or
   - `deferred: '<reason why this port omits it>'` (an acceptable gap for that platform)
3. If the new section applies to lightweight personas (explorer, researcher, scribe), also add it to `templates/persona-protocol-slim.md`
4. Regenerate all mirrors: `node bin/cli.js --update` (this updates `.claude/agents/*.md`)

**Do not hand-edit `.claude/agents/*.md` files.** They are generated mirrors (P2 in the constitution). Hand-editing them will either:
- Be silently overwritten on the next `--update`, losing the edit
- Cause the `--update` command to refuse to proceed (if the file diverges from what it expects)

## How parity testing works

`tests/adapter-protocol-parity.test.js` runs as part of `bash tests/validate.sh` (the merge gate). It validates that:

1. **Canonical → Adapter mapping:** Every section in `templates/persona-protocol.md` (the full tier) has a corresponding entry in the Codex and Cursor adapter protocol maps. Each entry must set either:
   - `probe: '<string that must appear in the port>'` (the section is present on that platform)
   - `deferred: '<reason>'` (an explicit, documented gap that platform is allowed to omit)
2. **No stale map entries:** Every key in `codexMap` and `cursorMap` corresponds to a current section in the full tier — stale entries are detected and rejected
3. **Present-probes are verified:** If a section's map entry is a probe, that string must actually appear in the port file

**Slim tier coverage is minimal:** The test has only one hardcoded check (lines 134–140) that verifies the `## Terminal status line (every dispatched turn)` section exists in `templates/persona-protocol-slim.md` with the grammar `STATUS: complete`. No other sections in the slim file are validated by this test.

The comment in the test itself (lines 130–133) is explicit: "Nothing else in the repo reads the slim file's section list." This means adding a new section to the full tier but forgetting to add it to the slim tier will not be caught by the parity test — the slim tier must be kept in sync manually by whoever edits the protocol files.

## Common mistakes

**"I added a section to persona-protocol.md and the tests pass"** — The parity test only passes if you also added an entry to `codexMap` and `cursorMap` (with either `probe` or `deferred`). If the test passes, you likely did that. But the slim tier is **not validated by the test** — if the new section should reach explorer/researcher/scribe, you must manually add it to `templates/persona-protocol-slim.md` as well.

**"The change isn't reaching explorer"** — Check whether:
  - The section is in `templates/persona-protocol-slim.md`? If not, add it.
  - Is the wording exactly the same in both files? The inlining is character-for-character, so even whitespace mismatches can break the cargo-cult copy-paste.

**"I hand-edited `.claude/agents/explorer.md` and my change disappeared"** — Yes, the next `--update` regenerated it from the canonical template. Edit the template instead and re-run `--update`.

**"I thought the parity test validated the slim tier"** — It validates the full tier against the Codex/Cursor adapter ports. The slim tier has only one hardcoded check for the terminal status line section. Slim-tier parity is enforced by code review and manual testing, not by automation.
