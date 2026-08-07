# Skills-library remediation (audit findings C1, C2, M3–M11)

Status: **REVISION 5 — finalized.** All 5 Open Questions resolved by the human
2026-08-04; eight defects found during slicing/execution are fixed here.
Author: spec-master | Date: 2026-08-04 | Source: Opus-tier read-only skills audit

> **Steps 1–10 are complete** (units #246–#255, all reviewer PASS). One
> `unconverged-requirement` finding from the 2026-08-07 post-milestone audit is
> appended as **Step 11 / unit `245-CF1`** — see
> [Convergence follow-ups](#convergence-follow-ups) at the end of this document.
> Steps 1–10 and their criteria are unchanged.

## Revision log

**Revision 5 (2026-08-06)** — one **mid-flight** gap, found by `lead-programmer`
while executing Step 7 as unit **#249**. Blocking for that unit only:

- **G7 (Step 7, whole premise)** — **confirmed, and the cause is identified.**
  Step 7 assumes each of the four `.claude/skills/*/` directories holds **two**
  files: a tracked lowercase `skill.md` and an untracked uppercase `SKILL.md`.
  As of 2026-08-06 only the **four lowercase** files exist; the uppercase copies
  are absent from the working tree entirely. The implementer correctly invoked
  the unit's Escalation clause instead of fabricating them.

  **Root cause: `git stash --include-untracked`, not a deletion.** Stash
  `stash@{0}` (`bf561cd0`, created 2026-08-06 16:36:50) is a **three-parent**
  commit — the third parent `a0d90e59` is the untracked-files tree, and it
  contains all four uppercase `SKILL.md` files plus 115 other untracked files.
  The `.claude/skills/*/` directory mtimes are `Aug 6 16:36`, matching the stash
  timestamp exactly. `git stash -u` *removes* untracked files from the working
  tree; the stash was never popped, so they are still there and still recoverable.

  **The files' content is unchanged and still authoritative** — re-verified
  byte-for-byte against `a0d90e59`: 27/28/28/29 lines, `_tool` counts 4/4/7/4,
  kebab-case `name:` matching each directory, zero non-suffixed occurrences of
  the four core tool names. They satisfy the existing criteria 4 and 5 exactly.
  **Fixed** by making Step 7 restore from the stash's untracked parent before
  relocating tracking — not by regenerating, and emphatically not by authoring.

  Two further defects were found while fixing G7 and are also fixed here:
  **criteria 1 and 3's `-iname`/`ls-files` counts are now green at baseline as
  well as post-change** (both measure `4` before *and* after), making them
  vacuous; and **nothing in the step protected the stash**, whose accidental
  `pop` would dump 119 unrelated files into the tree. New criteria 2b, 3c and 7
  close all three. Self-check CHK29 and CHK30 make both a standing check.

**Revision 4 (2026-08-06)** — one further gap, non-blocking:

- **G6 (Step 6b, prescribed wording)** — **confirmed.** The replacement
  parenthetical Revision 3 prescribed violated **two of this same step's own
  criteria**: it added a `§3` form to criterion 7's frozen cross-reference
  multiset, and it re-introduced the literal `third-party skill installs` that
  criterion 6 drives to a file-wide count of `0`. `task-master` proved it by
  mutation and correctly declined to invent replacement wording. **Fixed** with
  wording that contains no numerals at all (the number is spelled "three") and
  avoids the forbidden phrase — **verified by mutation in both directions**
  before prescribing it, with the old wording retained as a negative control
  proving the two criteria genuinely detect the violation.
  **This is the third instance of this defect class in this spec** (after G1 in
  Steps 4 and 5): me authoring prescribed prose that contains a literal one of
  my own criteria forbids. Self-check CHK28 now makes it a standing check.

**Revision 3 (2026-08-04)** — two further gaps, both re-verified before fixing:

- **G4 (Step 8, criterion 4)** — **confirmed vacuous.** `grep -c 'in your tools
  list'` measures **`0` at baseline in both tiers**; the phrase wraps
  (`persona-protocol.md:48-49`, `persona-protocol-slim.md:51-52`), and a
  line-oriented grep cannot see it. The criterion could never fail, defeating
  its sole purpose — verifying #235 preserved the correction. **Fixed** with the
  wrap-safe `tr | grep -o | wc -l` form (baseline `1`, target `0`), matching
  #235's own criterion 2b. This is the third instance of this defect class in
  this spec (after G3 and #250); Self-check CHK25 now covers it generally.
- **G5 (Step 6, criterion 7)** — **confirmed**: the criterion would catch only
  **3 of 33** cross-references, missing range/conjunction forms entirely.
  **Fixed by removing the cause, not patching the check: the renumbering in 6b
  is WITHDRAWN.** Two measured reasons — (a) ~30 references would silently
  resolve to the *wrong* section, which in an install runbook is worse than a
  numbering gap; (b) the doc already ships `## 0.5` and `## 6.5`, so
  stable-labels-with-gaps is its own existing convention, and a gap-free integer
  sequence was never a property it maintained. The real half of M8 (the
  inaccurate `description`) is still fixed. Criteria 5 and 7 become freeze
  assertions — heading set and cross-reference multiset byte-identical
  before/after — which cover all 33 references and protect line 488's external
  reference by construction.

**Revision 2 (2026-08-04)** — four gaps `task-master` correctly declined to
patch itself, all independently re-verified before fixing:

- **G1 (Step 4)** — criteria 2 and 4 were mutually unsatisfiable (whole-file
  count of `disable-model-invocation` expected `0` *and* `≥1`). Root cause: the
  provenance-header note was specified to contain the same literal the
  frontmatter assertion forbids. **Fixed** by requiring header wording that
  avoids the literal ("model-invocation block removed"), which makes the
  whole-file assertion clean. The identical hazard in **Step 5**'s `fm-noflag`
  header sketch is fixed the same way.
- **G1b (spec-wide)** — **confirmed and load-bearing.** Skills resolve from a
  versioned *plugin cache copy*, not this working tree; the cache is at 0.13.18
  while the repo is at 0.22.0, and `bin/cli.js` never writes it. **Fixed** by
  adding **Step 10** (cache refresh + post-restart verification) and moving both
  reachability probes into it. Scope turned out narrower than feared: only Steps
  4 and 5 make reachability claims — see Step 10's per-step table.
- **G2 (Step 6c)** — the "3 bare `/code-review` references" **do not exist**;
  all matches are `code-review-graph` URL/package/directory substrings. My own
  false positive, from the same regex trap this spec excludes elsewhere. **6c is
  withdrawn**, and its already-vacuous criterion 8 is replaced with a guard that
  the graph's real names survive unchanged.
- **G3 (Step 8)** — there are **4** occurrence sites, not 3, and the stated
  baseline of `3` was wrong (raw `grep -c` measures `2` because two occurrences
  wrap; the collapsed count is `4`). The 4th site (reviewer, 93-94) is
  **correct as written** — its skills are unflagged — so it is deliberately
  retained and the post-change target is `1`, not `0`.

Revision 1 was published as issue **#245** and sliced into units #246–#251;
see "Impact on already-filed units" below.

## Goal

Make the skills library's *declared* wiring actually reachable by the personas
that declare it, and re-sync the skill/install documentation to what is
genuinely on disk — without regressing the vendored-skill drift contract
(`scripts/resync-vendored-skills.sh --check`, currently exit 0).

## Context

### What I verified independently (fresh session, live probes)

**C1 confirmed, and escalated.** `Skill(antislop:to-spec)` →
`cannot be used with Skill tool due to disable-model-invocation`. But the flag
does not merely block the `Skill` tool — it removes the skill from the agent
entirely. Measured via a within-persona differential: a dispatched `task-master`
(frontmatter `skills: antislop:to-tickets, antislop:pathfinder`) introspecting
its own context before using any tool reported:

| declared skill | flag | body preloaded? | in skills list? | `Skill` tool |
|---|---|---|---|---|
| `pathfinder` | none | **yes** | yes | succeeds |
| `to-tickets` | `disable-model-invocation: true` | **no** | **no** | fails |

The same holds in spec-master's own context: of `grill-me`, `to-spec`,
`fail-triage`, only the unflagged `fail-triage` is present.

So the audit's "breaks agent-teams mode entirely" understates it: **a flagged
skill is unreachable by its persona in every mode, including the default one.**
Frontmatter preload is not merely unhelpful — it is inert. Consequences:

| persona | declares | actually reachable (before this spec) |
|---|---|---|
| `spec-master` | grill-me, to-spec, fail-triage | **fail-triage only** |
| `task-master` | to-tickets, pathfinder | **pathfinder only** |
| `scribe` | improve-codebase-architecture | **none** |
| `lead-programmer` | coding-discipline, handoff | **coding-discipline only** |
| `milestone-auditor` | grill-me | **none** |
| `reviewer` | coding-discipline, roast-work | both |

**The flag is upstream's, not antislop's.** All six skills were fetched from
mattpocock/skills at pinned SHA `e9fcdf95`; every one carries the flag upstream.
AntiSlop inherited it by vendoring verbatim. Upstream assumes human-typed slash
commands; antislop invokes agent-to-agent. That mismatch is the whole bug, and
it is the same class of adaptation as the already-precedented
`/setup-matt-pocock-skills` repoint.

**C2 confirmed, with two corrections.** `Skill(antislop:to-issues)` →
`Unknown skill` (a distinct error from C1's, proving absence rather than
blocking). It appears **12 lines / 14 occurrences across exactly 4 files** —
`agents/{spec-master,task-master}.md` and their `.claude/agents/` mirrors.
**`orchestrator.md` contains zero occurrences**; the audit's file list is wrong.

**The drift contract is the binding constraint.** `resync --check` is exit 0
today, all 9 verbatim skills `[OK]`. Of the six flagged skills:
`to-spec`/`to-tickets` are in `REPOINT_SKILLS` and **never diffed** (free to
edit); `grill-me`/`handoff`/`implement`/`improve-codebase-architecture` are in
the drift-checked verbatim 9.

**M7's premise is void.** `improve-codebase-architecture` is not preloaded into
`scribe` spawns — it is flagged, therefore never loaded. There is no token cost
to reclaim; the real defect is the inverse. Only `fail-triage` (2.3KB into every
`spec-master` spawn) is genuinely preloaded. **This inverts once Step 5 lands** —
see Decision D1.

**M5's "9 dead skills" needs splitting.** `code-review`, `codebase-design`,
`domain-modeling`, `grilling` and all 4 project-local skills **are** listed and
model-invocable — any persona with the `Skill` tool can self-trigger them from
their `description`. They are unwired, not dead. `implement` alone is unwired
**and** flagged, hence unreachable in every mode by every persona.

**M6 measured precisely: 13 actionable cross-skill slash references**, of which
**12 sit inside drift-checked files** and one (`skills/to-tickets/SKILL.md:108`)
is free. Line-1 and line-5/6 `/name` matches are provenance-header *paths*, not
slash commands — excluded from that count.

**OQ5 fact-finding (explorer, live MCP query, graph-derived).** The
`code-review-graph` server is live (graph built at HEAD `e5b908f`, 207 nodes,
4564 edges). Every tool it exposes is prefixed `mcp__code-review-graph__` **and
carries the `_tool` suffix** — `semantic_search_nodes_tool`, `query_graph_tool`,
`detect_changes_tool`, `get_impact_radius_tool`, plus `apply_refactor_tool`,
`refactor_tool`, `get_architecture_overview_tool`, `list_communities_tool`,
`get_affected_flows_tool`, all confirmed present. **The untracked uppercase
`SKILL.md` copies use the correct convention; the tracked lowercase `skill.md`
copies are outdated.** This settles OQ5 on verified fact.

### Facts that shape the acceptance criteria

- `bin/cli.js --update`'s fast path (`bin/cli.js:965`) returns early when
  `pluginVersion` matches and every managed file is present and current-stamped.
  **A version bump is the mechanism that makes propagation happen**, not
  bookkeeping.
- `--update --check` **writes**; it is not a dry run.
- The absent-file blindness recorded in prior memory **has since been fixed**
  (`needsRender` pre-scan, `bin/cli.js:946-962`, catches absence *and* stale
  stamps). That memory was stale and has been corrected.
- `.claude/persona-config.json` is git-tracked and rewritten by every render.
- Because mirror regeneration is deferred to a single release step (Step 9), no
  earlier step may assert anything about `.claude/agents/*.md` — a forced render
  legitimately differs from on-disk mirrors for every step before it, making
  such a criterion unsatisfiable regardless of correctness. **Steps 1–8 assert
  only on source files.**
- `tests/validate.sh:119-127` validates `skills/*/SKILL.md` frontmatter via a
  glob (deleting a skill directory is safe); `:34-42` fails if `package.json`
  and `.claude-plugin/plugin.json` versions diverge.
- `.claude-plugin/plugin.json` has **no per-skill list**, and `package.json`'s
  `files` array ships only `skills/coding-discipline` and
  `skills/install-antislop`. Deleting a skill needs no packaging edit.
- **Neither adapter port contains an Agent-teams section.** Both
  `adapters/codex/agents-md-fragment.md:179` and
  `adapters/cursor/rules/persona-protocol.mdc:171` state agent-teams mode is
  *dropped for v1*. The dead Skill-tool advice exists only in
  `templates/persona-protocol.md:45` and `templates/persona-protocol-slim.md:48`.
- `.claude/skills/*/SKILL.md` (uppercase) is **not gitignored** (`git check-ignore`
  exits 1), and `skill.md` (lowercase) is tracked. **Corrected in Revision 5
  (G7):** as of 2026-08-06 the uppercase copies are no longer *in the working
  tree at all* — being untracked is exactly what made them vulnerable, and
  `git stash --include-untracked` swallowed them. They live in `stash@{0}`'s
  untracked parent `a0d90e59`. Step 7 restores them from there; once tracked,
  this class of loss cannot recur, which is a second, previously unstated
  reason the step is worth doing.
- The **live installer is `code-review-graph` 2.3.7** (pipx). Its
  `skills.py` writes `.claude/skills/<name>/SKILL.md` — **uppercase**, with the
  inline comment "Claude Code expects skills at `.claude/skills/<name>/SKILL.md`"
  — and its templates use the `_tool` suffix (6 matches for
  `semantic_search_nodes_tool`, zero for the backticked non-suffixed form). The
  tracked lowercase files are therefore legacy output from an **older installer
  version**, committed once in `cf182d0` and never refreshed. This is
  independent corroboration of OQ5, arrived at without touching the disputed
  files.

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

- 2026-08-04 Functional scope & success criteria: Q Which findings are in scope
  for mechanical fixing versus a human scope call? → A (self-resolved): C2, M4,
  M8, M10, M11 and the non-drift-checked half of C1/M6 were specified directly;
  the rest were routed to OQ1–OQ5 and are now all resolved (below).
- 2026-08-04 Domain entities / data model: Q What governs a skill's
  reachability? → A (self-resolved): solely the `disable-model-invocation`
  frontmatter flag, measured above — not the `skills:` frontmatter list, which
  is inert for flagged skills.
- 2026-08-04 User interaction flow: Q Is any human-facing flow affected? →
  A (self-resolved): no. Flagged skills remain human-invocable as
  `/antislop:<name>`; every change concerns agent-to-agent reachability.
- 2026-08-04 Non-functional attributes: Q Is M7's preload token cost real, and
  does un-flagging introduce risk? → A (self-resolved): the cost was not real
  (flagged skills never load), but **un-flagging makes it real for the first
  time** — see Decision D1. Un-flagging also enables autonomous self-triggering,
  which is why `implement` is deleted rather than un-flagged.
- 2026-08-04 External dependencies & integrations: Q What is the vendoring
  contract and does it hold? → A (self-resolved): 12 skills pinned at
  `e9fcdf95`; 9 byte-diffed, 3 repointed and never diffed. Measured baseline
  `--check` exit 0, all 9 `[OK]`.
- 2026-08-04 Edge cases / failure handling: Q What breaks if a drift-checked
  skill's frontmatter is edited? → A: **resolved by OQ1** — `--check` would
  return exit 1, so the script is taught the deviation declaratively (Step 5)
  rather than losing coverage.
- 2026-08-04 Technical constraints & tradeoffs: Q Can reachability and the
  byte-verbatim vendoring guarantee both be preserved? → A: yes, per **OQ1**
  answer — strip the flag from `handoff` and `improve-codebase-architecture`
  and teach `resync-vendored-skills.sh` that this exact deviation is intentional,
  keeping full drift coverage on every other line and on companion docs.
- 2026-08-04 Terminology consistency: Q Which names are authoritative? →
  A (self-resolved): `to-tickets` (not `to-issues`); `grilling` holds the actual
  procedure; `SKILL.md` (not `skill.md`) is what Claude Code discovers.
- 2026-08-04 Completion / acceptance signals: Q What is the authoritative green
  signal? → A (self-resolved): `bash tests/validate.sh` exit 0 **and**
  `bash scripts/resync-vendored-skills.sh --check` exit 0, plus per-step greps
  each with a measured pre-change baseline.
- 2026-08-04 Technical constraints & tradeoffs (OQ2): Q Delete/merge `grill-me`,
  or keep and repoint? → A: keep `skills/grill-me/` on disk untouched and change
  only the two frontmatter references to `antislop:grilling`, which already
  works. Zero drift, zero registry churn.
- 2026-08-04 Functional scope & success criteria (OQ3): Q Delete `implement`? →
  A: yes — the one genuinely dead+flagged skill, and its "commit your work to
  the current branch" body is actively unsafe for this system's reviewer-PASS
  gating if ever reached.
- 2026-08-04 Functional scope & success criteria (OQ4): Q Fates of the
  unwired-but-reachable skills? → A: wire `domain-modeling` into `scribe` only.
  Leave `code-review`, `codebase-design` and the rest as-is — no boundary
  statement, no deletions this pass.
- 2026-08-04 Domain entities / data model (OQ5): Q Which `.claude/skills/` copy
  is authoritative? → A: dispatch `explorer` to report the live server's tool
  names first, then keep the matching copy. **Done** — the `_tool` suffix is
  correct, so the uppercase `SKILL.md` copies are kept and the lowercase
  `skill.md` copies deleted.
- 2026-08-06 Edge cases / failure handling (G7): Q Step 7's premise says two
  files per directory; only the four lowercase ones exist. Were the uppercase
  copies deleted, never generated, or is the premise simply wrong? →
  A (self-resolved): none of those — they were **swallowed by
  `git stash --include-untracked`** on 2026-08-06 16:36:50 and are intact in
  that stash's untracked parent `a0d90e59`. Proven by the stash being a
  three-parent commit whose third parent lists exactly those four paths, and by
  the directory mtimes matching the stash timestamp to the minute. Step 7 now
  restores rather than regenerates.
- 2026-08-06 Domain entities / data model (OQ5 re-verification): Q Is the
  `_tool`-suffix finding still true two days on, given that the step's *other*
  premise just went stale? → A (self-resolved): yes — re-confirmed by a second
  live `explorer` MCP roster query (2026-08-06 14:45 UTC, graph-derived, not
  grep fallback). All **28** tools carry the suffix and **no non-suffixed form
  exists**. Corroborated independently by installer 2.3.7's own templates. The
  "keep uppercase" decision stands unchanged.
- 2026-08-06 Technical constraints & tradeoffs (G7): Q Restore from the stash,
  re-run the installer, or copy from a sibling checkout? →
  A (self-resolved): **restore from the stash.** It is the only option with
  in-repo provenance and byte-exact fidelity to what OQ5 verified; re-running
  the installer mutates unrelated project files and pins content to whatever
  version happens to be installed later; a sibling checkout is machine-specific
  and unreproducible for anyone else. Installer regeneration is retained as a
  documented fallback for the case where the stash is gone.

## Decisions made while finalizing (reversible; flagged for the checkpoint)

- **D1 — `improve-codebase-architecture` is dropped from `scribe`'s `skills:`
  frontmatter (Step 3), not merely joined by `domain-modeling`.** OQ1 un-flags
  it, which for the first time makes it genuinely preload — 6.25KB into every
  spawn of a `model: haiku` persona invoked after every plan step. Combined with
  OQ4's `domain-modeling` (3.6KB) that would be ~10KB of new recurring preload
  on the highest-frequency persona, while a cost-cutting spec is concurrently in
  flight to remove exactly this kind of weight. Once un-flagged, the skill is
  reachable **on demand** via the `Skill` tool, which is precisely what scribe's
  body already specifies ("Use `improve-codebase-architecture` when asked").
  So scribe's frontmatter carries `domain-modeling` alone (~3.6KB), and nothing
  is lost. **This is the one judgment call not directly dictated by an OQ
  answer; reverting it is a one-line frontmatter change.**

## Risks / dependencies

- **R1 — Concrete collision with issue #235, now identified.** The in-flight
  cost-cutting spec's unit **#235** ("Step 6a (F8) — Compress the Agent-teams
  mode section to <=8 lines") rewrites the *same section* this spec must
  correct, and imposes a `<=8` line ceiling plus a `<=16800` byte ceiling on
  `templates/persona-protocol.md`. Resolution is stated in full under
  **Sequencing decision** below: the template edit is **merged into #235**;
  this spec's Step 8 verifies the outcome and owns only the design docs.
- **R2 — Version-bump contention.** Both specs bump
  `.claude-plugin/plugin.json` + `package.json`. Step 9 bumps from whatever is
  current at execution time; its criterion is "strictly greater than the
  pre-edit version", never a literal number.
- **R3 — Un-flagging enables autonomous self-triggering.** Mitigated for the
  dangerous case by deleting `implement` (Step 5) rather than un-flagging it.
  `handoff` and `improve-codebase-architecture` become self-triggerable; both
  descriptions are narrow, and the tradeoff was accepted under OQ1.
- **R4 — No mechanical test for teams mode.** Preload-off for teammates is
  enforced by Claude Code, not antislop (`commands/start-feature-team.md` is
  documentation only). **No criterion here asserts teams-mode behaviour** — all
  are static assertions or single-agent reachability probes.
- **R5 — No prior `.fail` record exists** for any skills-library unit (the
  marker directory holds only numbered-issue records, newest `225`). Nothing in
  this spec is a re-scope of previously-failed work, so no step should be
  model-tagged on the assumption of prior difficulty.
- **R6 — Observation for the coordinator, not a task in this spec: issue #235
  appears defective.** Its affected-files list claims a "ported agent-teams
  section" exists in `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc`, and its criterion 9 requires
  `git diff --numstat` to show **two non-zero rows** for those files. Measured:
  neither adapter has such a section — both carry a single line stating
  agent-teams mode is *dropped for v1*. There is nothing to compress, so
  criterion 9 is unsatisfiable without a cosmetic edit. Route this back to the
  cost-cutting track's owner; this spec does not modify another spec's units.

- **R8 — The surviving uppercase copies are *more* accurate, not fully accurate
  (Revision 5, G7). Explicitly out of scope; do not "fix" it inside Step 7.**
  The live roster shows all 28 tools carry the `_tool` suffix, but the installer's
  own templates still write five names without it — `get_flow`,
  `list_graph_stats`, `get_community`, `list_flows`, `find_large_functions`
  (in `debug-issue`, `explore-codebase` and `refactor-safely`). That is an
  **upstream installer content bug**, inherited identically by every project the
  installer touches. Step 7's job is relocating tracking of already-verified
  content, and its Do-NOT-touch list forbids editing `SKILL.md` bodies — so
  correcting these belongs in a separate unit filed against the installer's
  output, not here. Recorded so a future audit does not re-flag it as a Step 7
  miss, and so criterion 4 is not misread as certifying whole-file accuracy.
  Note `callers_of`, `callees_of`, `imports_of` and `children_of` are **query
  patterns, not tool names**, and are correct unsuffixed — a plausible
  false-positive trap for anyone who does pick this up later.

- **R9 — `stash@{0}` is load-bearing until Step 7 lands, and holds 119 untracked
  files plus tracked modifications across `.claude/agent-memory/` and
  `.claude/wiki/`.** Step 7 must extract **four paths** from it and nothing
  else. `git stash pop`/`apply`/`drop` are forbidden in that unit — a pop would
  dump 115 unrelated files into the tree and silently widen the diff far beyond
  the step's ceiling. Step 7 criterion 7 asserts the stash is byte-identical
  afterwards, so a violation fails the unit rather than being discovered later.

- **R7 — Skills resolve from the installed plugin cache, not this repo
  (Revision 2, G1b).** `~/.claude/plugins/cache/antislop-marketplace/antislop/0.13.18/`
  is a *copy* taken at install time; the repo is at 0.22.0. No repo edit changes
  what `Skill()` loads until `claude plugin update antislop@antislop-marketplace`
  runs **and the session restarts**. `bin/cli.js --update` does **not** do this —
  it scaffolds a project's `.claude/`, a different mechanism entirely. Any
  criterion of the form "edit the skill, then probe `Skill()`" is unsatisfiable
  in the editing session and would fail on a *correct* implementation. All
  reachability proof is therefore concentrated in **Step 10**.

## Impact on already-filed units (#246–#251)

Revision 1 was sliced into 6 units before these defects were found. Effect of
Revision 2:

| unit | step | status under Revision 2 |
|---|---|---|
| #246–#251 (Steps 1, 2, 3, 6a/6b, 7, 9) | — | **substance unchanged**; Step 9's criterion 7 is deleted (moved to Step 10), and the Step 6 unit must drop 6c and take the replacement criterion 8 |
| Step 4 unit | 4 | **criteria replaced** (G1 + G1b): criterion 2 whole-file, criterion 4 re-worded, criterion 6 deferred to Step 10 |
| Step 5 unit | 5 | **header wording + criterion 2 changed** (G1 hazard) |
| Step 8 unit | 8 | **baseline and target counts corrected** (G3); the reviewer site is now explicitly out of scope |
| **new** | 10 | **new human-gated unit** — cache refresh + post-restart verification |

`task-master` should re-slice Steps 4, 5, 6, 8 and file the new Step 10 unit;
Steps 1, 2, 3, 7 need no change. **No unit is invalidated** — G1b narrowed to
Steps 4/5 rather than affecting every step, because `grilling` and
`domain-modeling` (Step 3's targets) are already unflagged in the live cache.

### Revision 3 impact on the 10 filed units (#246–#255)

**Both fixes are criteria-and-body text updates. No re-file, no unit
renumbering, no new unit** — matching the pattern `task-master` has used for
defects at this stage on the sibling spec:

| unit | change |
|---|---|
| **#254** (Step 8) | **criterion 4 replaced in place** with the wrap-safe form; its baseline corrected from `0` to `1` per tier. Nothing else in the unit moves. |
| **#253** (Step 6) | **body + criteria updated in place**: 6b's renumbering withdrawn (description fix retained); criterion 5 becomes a heading-set freeze; criterion 7 becomes a cross-reference-multiset freeze; new 7b anti-vacuity floor. `task-master`'s census remains valuable — it is now the *justification* for freezing, rather than a stopgap instruction for renumbering safely. |
| #246–#252, #255 | **unchanged.** |

Note #253 gets **smaller**, not larger: withdrawing the renumbering removes the
riskiest operation in that step, so its `Suggested model` tag may warrant a
downgrade on re-read.

### Revision 4 impact on the filed units

**#253 only, and it is an addition rather than a change**: the two literal
prohibitions `task-master` already wrote into its `Ordered edits` stay exactly
as they are — Revision 4 supplies the missing replacement wording they were
written to constrain. No other unit is touched; **no re-file, no new unit**, and
#253 remains dispatchable as currently written (the prohibitions alone were
sufficient to keep an implementer safe; this just removes the guesswork).

### Revision 5 impact on the filed units

**#249 (Step 7) only, and it is blocking for that unit** — unlike Revisions 3
and 4, this one changes what the implementer actually does, not just how it is
checked. The unit gains a recovery sub-step (7a), a mandatory operation order,
two forbidden git operations, and three new criteria (1c, 7, 8); criteria 1, 2
and 3 are corrected for baselines that no longer hold.

| unit | change |
|---|---|
| **#249** (Step 7) | **body + criteria updated in place.** Re-dispatch required — the version already dispatched is unexecutable, since its criterion 1 baseline of `8` can never be met. No re-file and no new unit: the step's goal, scope and affected files are unchanged. |
| #246–#248, #250–#255 | **unchanged.** |

#249 gets **larger and more delicate**, not smaller: restoring from a specific
stash parent without disturbing the stash is a narrower operation than the
straightforward `git rm` + `git add` it replaces. If its `Suggested model` tag
was set low on the assumption that Step 7 was mechanical file bookkeeping,
`task-master` should re-read it — the failure mode here (an errant
`git stash pop`) is destructive and wide, and **R5's "no prior `.fail` record"
note no longer tells the whole story for this unit**: #249 has no `.fail` record
(it never reached review), but it *has* already been escalated once for a
premise defect, which is evidence about the step, not about the implementer.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — both central claims re-probed
  live; the flag's provenance confirmed by fetching upstream at the pinned SHA;
  preload behaviour established by a within-persona differential; the `--check`
  baseline measured (exit 0); OQ5 settled by a live MCP roster query rather than
  by choosing a convention. Step 5 additionally carries a mutation control so
  the new drift-check path cannot pass vacuously. **Revision 5 strengthens this
  principle rather than deviating from it**: Step 7's stale premise was caught
  because the implementer measured instead of assuming, and the fix was adopted
  only after (a) locating the files' actual cause of absence in the stash's
  untracked parent, (b) re-running the OQ5 roster query live rather than reusing
  the two-day-old answer, and (c) mutation-testing the revised criteria in a
  throwaway worktree — where two of the pre-existing criteria were found to be
  green at baseline and were replaced.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  mirror regeneration goes through `bin/cli.js --update` in Step 9; no step
  hand-edits `.claude/agents/*.md`.
- P3 "Version-stamp discipline" (MUST): satisfied — Step 9 bumps both manifests
  and adds a CHANGELOG entry; the bump is also what defeats `--update`'s vacuous
  fast path.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — no step adds
  an unconditional reference to an optional persona; `tests/validate.sh`'s
  conditional-phrasing check stays green.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — every step
  carries `bash tests/validate.sh` exit 0.

## Sequencing decision (answer to the coordinator's item 4)

**The two protocol edits must be MERGED into #235, not raced or ordered.**

Both this spec's original Step 6 and #235 rewrite the body of the same 20-line
`## Agent-teams mode` section. Two sequential wholesale rewrites of the same
lines is waste and a guaranteed conflict; worse, the ordering is a trap in both
directions:

- If the correction lands *first*, #235 then rewrites the section to <=8 lines
  and may silently drop the corrected content while still passing all of its own
  criteria (none of which mention `disable-model-invocation`).
- If #235 lands *first*, a later correction adds lines to a section just capped
  at 8 and a file just capped at 16 800 bytes, silently breaking both ceilings
  with nobody re-checking them.

**Therefore:**

1. **#235's issue body must be amended before it is dispatched**, to (a) delete
   the dead Skill-tool fallback advice as part of its compression, and (b) add
   the corrected semantics to its criterion-2 list of retained literal strings.
   The exact replacement text is given in Step 8 below. This costs #235 nothing
   — it is already rewriting those lines, and the correction is *shorter* than
   the text it replaces, which helps its byte ceiling.
2. **#235 lands first.** This spec's Step 8 then runs, owning only
   `docs/persona-design-notes.md` (which #235 does not touch) and carrying a
   **verification-only** criterion on the two templates. If #235's implementer
   drops the correction, Step 8 fails and routes back — the guard is explicit
   rather than trusting the merge.
3. No other step in this spec touches any file the cost-cutting spec touches.
   Steps 1–7 and 9 may proceed independently of #235.

---

## Step 1 — `agents/spec-master.md`: C2 rename + `grill-me` → `grilling` (C2, OQ2)

**Affected files:** `agents/spec-master.md` only.

Replace all 3 occurrences of the non-existent `to-issues` with `to-tickets`.
Change the frontmatter `skills:` line from
`antislop:grill-me, antislop:to-spec, antislop:fail-triage` to
`antislop:grilling, antislop:to-spec, antislop:fail-triage`. Body prose may keep
"grill-me" as the *process* name; add one clause noting the skill invoked is
`grilling`. Do not touch `docs/`, `CHANGELOG.md`, ADRs or wiki files — those are
historical records.

**Acceptance criteria** (baselines measured 2026-08-04 at `e5b908f`):
1. Pre-change baseline: `grep -c to-issues agents/spec-master.md` → `3`.
2. Post-change: `grep -c to-issues agents/spec-master.md` → `0` (assert the
   count equals 0; never assert a negated exit status, which returns success on
   grep's exit 2).
3. `grep -c 'antislop:grilling' agents/spec-master.md` → `1`, and
   `grep -c 'antislop:grill-me' agents/spec-master.md` → `0`.
4. Frontmatter still lists three skills:
   `grep -c '^skills: antislop:grilling, antislop:to-spec, antislop:fail-triage$' agents/spec-master.md` → `1`.
5. Ceiling control: `git diff --numstat -- agents/` lists only
   `agents/spec-master.md`.
6. `bash tests/validate.sh` exit 0.

---

## Step 2 — `agents/task-master.md`: C2 rename + `pathfinder`/`to-tickets` boundary (C2, M11)

**Affected files:** `agents/task-master.md` only.

Replace all 3 occurrences of `to-issues` with `to-tickets`, **including in the
`description:` frontmatter field**. Add one short body paragraph fixing the
division of labour: **`pathfinder` governs sizing, naming and ordering;
`to-tickets` governs tracker publishing shape (ticket bodies, blocking edges,
labels). Where they disagree on how big a unit should be, `pathfinder` wins.**
Rationale to state inline: `pathfinder` is the antislop-native tailored skill.

**Acceptance criteria:**
1. Pre-change baseline: `grep -c to-issues agents/task-master.md` → `3`.
2. Post-change: `grep -c to-issues agents/task-master.md` → `0`.
3. The `description:` field is fixed too:
   `sed -n '3p' agents/task-master.md | grep -c 'to-tickets'` → `1`.
4. Precedence rule present and directional (the `tr` guards against the ~76-col
   wrap in `agents/*.md`, which would otherwise split the phrase across lines):
   `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | grep -cE 'pathfinder (wins|governs|takes precedence)'` ≥ `1`.
5. Both skills named in one paragraph: a single whitespace-collapsed 400-char
   window contains both `pathfinder` and `to-tickets`.
6. Ceiling control: `git diff --numstat -- agents/` lists only
   `agents/task-master.md`.
7. `bash tests/validate.sh` exit 0.

---

## Step 3 — Persona frontmatter rewiring: `milestone-auditor` + `scribe` (OQ2, OQ4, D1)

**Affected files:** `agents/milestone-auditor.md`, `agents/scribe.md`.

- `agents/milestone-auditor.md:7`: `skills: antislop:grill-me` →
  `skills: antislop:grilling`. This gives the persona its first working skill.
- `agents/scribe.md:8`: `skills: antislop:improve-codebase-architecture` →
  `skills: antislop:domain-modeling` (see **Decision D1** — ICA is dropped from
  preload, not lost; once Step 5 un-flags it, scribe reaches it on demand).
- `agents/scribe.md` body (~line 18): the sentence "Use
  `improve-codebase-architecture` when asked" must be extended to say it is
  invoked **on demand via the `Skill` tool**, and a parallel sentence added for
  `domain-modeling` as the format guidance for the `CONTEXT.md` / `docs/adr/`
  files scribe already owns.

**Depends on Step 5** for the claim "reachable on demand" to be true; land
Step 5 first or in the same batch.

**Acceptance criteria:**
1. `grep -c '^skills: antislop:grilling$' agents/milestone-auditor.md` → `1`;
   `grep -c 'antislop:grill-me' agents/milestone-auditor.md` → `0`.
2. `grep -c '^skills: antislop:domain-modeling$' agents/scribe.md` → `1`.
3. The frontmatter line specifically no longer names ICA:
   `sed -n '8p' agents/scribe.md | grep -c 'improve-codebase-architecture'` → `0`.
4. ICA is still referenced in the body as an on-demand skill (guards against a
   blanket delete that removes the capability instead of the preload):
   `tr '\n' ' ' < agents/scribe.md | tr -s ' ' | grep -c 'improve-codebase-architecture'` ≥ `1`.
5. `domain-modeling` is explained in the body, not only declared:
   `tr '\n' ' ' < agents/scribe.md | tr -s ' ' | grep -c 'domain-modeling'` ≥ `2`
   (once in frontmatter, at least once in body).
6. Ceiling control: `git diff --numstat -- agents/` lists exactly
   `agents/milestone-auditor.md` and `agents/scribe.md`.
7. `bash tests/validate.sh` exit 0.

---

## Step 4 — Un-flag the two free skills + drop the dead `/implement` ref (C1 partial, M6 partial)

**Affected files:** `skills/to-spec/SKILL.md`, `skills/to-tickets/SKILL.md`.

Delete the `disable-model-invocation: true` line from both. Both are in
`REPOINT_SKILLS` and **never diffed**, so this costs nothing against the drift
contract. Append a note to each file's existing provenance header sentence
(which already documents the setup-wizard repoint) recording the removal. In
`skills/to-tickets/SKILL.md:108`, the bare `/implement` reference must be
**removed entirely** rather than repointed — `implement` is deleted in Step 5.

**The header note must NOT contain the literal string
`disable-model-invocation`** — use wording such as "with the upstream
model-invocation block removed so antislop personas can load it". Revision 2
fix (G1): the previous criteria demanded a whole-file count of `0` for that
literal *and* a collapsed-text count of `≥1` for the same literal, which is
unsatisfiable. Keeping the literal out of the header makes the whole-file
assertion clean and unambiguous, and removes the identical hazard from Step 5's
header sketch.

**Acceptance criteria:**
1. Pre-change baselines: `grep -c disable-model-invocation skills/to-spec/SKILL.md`
   → `1`; `skills/to-tickets/SKILL.md` → `1`;
   `grep -c '/implement' skills/to-tickets/SKILL.md` → `1`.
2. Post-change, the literal is gone from the file **entirely** (frontmatter and
   header alike): `grep -c disable-model-invocation skills/to-spec/SKILL.md` →
   `0`; `skills/to-tickets/SKILL.md` → `0`;
   `grep -c '/implement' skills/to-tickets/SKILL.md` → `0`.
3. Frontmatter still valid — `bash tests/validate.sh` exit 0, with both files
   still `OK` under its `skills/*/SKILL.md` name/description check.
4. The removal is recorded in the header, using the non-colliding wording: for
   each file,
   `tr '\n' ' ' < <file> | tr -s ' ' | grep -ci 'model-invocation block removed'` → `1`.
   This is compatible with criterion 2 because the phrase does not contain the
   `disable-` prefix the literal requires.
5. `bash scripts/resync-vendored-skills.sh --check` exit 0, still printing
   `[VENDORED] to-spec` and `[VENDORED] to-tickets` in the not-diffed section.
6. **Cache-side reachability (see Step 10 and R7) — NOT verifiable in the
   editing session.** Editing this repo does not change what `Skill()` loads;
   skills resolve from the installed plugin cache. The reachability proof for
   this step is deferred to **Step 10**, which refreshes the cache and then
   asserts on the refreshed copy. Do not write an in-session `Skill()` probe
   here — it would fail on a *correct* implementation.

---

## Step 5 — Vendoring registry overhaul: un-flag `handoff` + `improve-codebase-architecture`, delete `implement` (OQ1, OQ3)

**Affected files:** `skills/handoff/SKILL.md`,
`skills/improve-codebase-architecture/SKILL.md`, `skills/implement/` (deleted),
`scripts/resync-vendored-skills.sh`, `docs/maintenance/resync-vendored-skills.md`,
`skills/THIRD-PARTY-NOTICES.md`, `README.md` (line ~255),
`.claude/wiki/dependencies.md` (line ~21).

**5a — Teach the script the intentional deviation.** Add a new reconstruction
type `fm-noflag` alongside `fm`/`doc`/`raw` in `check_one_file`. It performs the
identical `fm` awk header insertion, then removes the
`disable-model-invocation: true` line from the *expected* content, and uses a
distinct provenance header naming the deviation. Sketch (pseudo-code, intent
only):

```
fm|fm-noflag)
  hdr="$header"
  if [ "$type" = "fm-noflag" ]; then
    hdr="<!-- Vendored from mattpocock/skills $upstream_path @ $SHA, with the
         upstream model-invocation block removed so antislop personas can load
         it (see docs/maintenance/resync-vendored-skills.md). MIT (c) 2026 Matt
         Pocock - see skills/THIRD-PARTY-NOTICES.md. -->"
  fi
  awk -v header="$hdr" '...' "$upstream_file" >"$expected"
  [ "$type" = "fm-noflag" ] && sed -i '/^disable-model-invocation: true$/d' "$expected"
  ;;
```

**Revision 2 fix (G1 hazard).** The header text deliberately does **not**
contain the literal `disable-model-invocation` — an earlier draft's sketch did,
which would have tripped this step's own criterion 2 if pasted verbatim. The
`sed` deletion pattern must of course still contain the literal; that lives in
`scripts/resync-vendored-skills.sh`, which criterion 2 does not assert on.

Change the `FILES` rows for `handoff` and `improve-codebase-architecture`'s
`SKILL.md` from `fm` to `fm-noflag`. **`improve-codebase-architecture`'s
`HTML-REPORT.md` row stays `doc`** — companion-doc drift coverage is retained,
which is the entire reason OQ1 chose this option over moving the skills into the
never-diffed set.

**5b — Strip the flag** from `skills/handoff/SKILL.md` and
`skills/improve-codebase-architecture/SKILL.md`, and update each file's
provenance header to the `fm-noflag` wording so it matches what the script now
reconstructs.

**5c — Delete `skills/implement/`** and remove its `FILES` row and its
`SKILL_ORDER` entry. Remove it from the runbook table, the NOTICES table (row
11 — **renumber the remaining rows and check the prose that references row
numbers or counts, not just the table rows**), `README.md`'s 12-name list, and
`.claude/wiki/dependencies.md`'s 12-name list. Counts change: 12 vendored → 11;
9 diffed → 8. The runbook's "first 9 are byte-verbatim" prose and its `--check`
exit-code table ("`0` = all 9 verbatim skills `[OK]`") must both become 8, with
the two flag-stripped skills described as intentional deviations.

**Acceptance criteria:**
1. Pre-change baselines: `grep -c disable-model-invocation skills/handoff/SKILL.md`
   → `1`; `skills/improve-codebase-architecture/SKILL.md` → `1`;
   `test -f skills/implement/SKILL.md` exit 0;
   `bash scripts/resync-vendored-skills.sh --check` exit 0 listing **9** `[OK]`.
2. Post-change, the literal is gone from both SKILL.md files entirely —
   `grep -c disable-model-invocation skills/handoff/SKILL.md` → `0` and
   `skills/improve-codebase-architecture/SKILL.md` → `0` (the new header wording
   avoids the literal, so this is a clean whole-file assertion); and
   `test -e skills/implement` exit 1.
2b. Each rewritten header records the removal:
   `tr '\n' ' ' < skills/handoff/SKILL.md | tr -s ' ' | grep -ci 'model-invocation block removed'` → `1`,
   same for `skills/improve-codebase-architecture/SKILL.md`.
3. `bash scripts/resync-vendored-skills.sh --check` exit **0**, printing `[OK]`
   for exactly **8** skills, including `handoff` and
   `improve-codebase-architecture`, and no `implement` line at all:
   `bash scripts/resync-vendored-skills.sh --check | grep -c '^\[OK\]'` → `8`,
   and `... | grep -c implement` → `0`.
4. **Mutation control (mandatory — proves `fm-noflag` is not vacuously
   passing).** In a throwaway worktree, re-insert `disable-model-invocation: true`
   into `skills/handoff/SKILL.md`'s frontmatter and re-run `--check`: it must
   report `[DRIFTED] handoff` and exit **1**. Then discard the worktree. Without
   this control, a reconstruction bug that strips the line from *both* sides
   would leave the check green forever.
5. Companion-doc coverage retained:
   `grep -c 'improve-codebase-architecture:doc:' scripts/resync-vendored-skills.sh` → `1`.
6. `FILES`/`SKILL_ORDER` stay in sync — the script's own desync guard must not
   fire: `bash scripts/resync-vendored-skills.sh --check 2>&1 | grep -c 'appears in FILES'` → `0`.
7. Registry counts updated in all four registry files
   (`docs/maintenance/resync-vendored-skills.md`,
   `skills/THIRD-PARTY-NOTICES.md`, `README.md`,
   `.claude/wiki/dependencies.md`): `implement` no longer appears in the
   vendored-skill list. Record each file's pre-change baseline first and scope
   the assertion to the vendored-list lines — `README.md` and the wiki use the
   word "implement" in unrelated prose, so a whole-file `grep -c ... → 0` would
   be wrong.
8. NOTICES table renumbering is internally consistent: the `| N |` column is a
   gap-free `1..11` sequence, asserted programmatically, **and** no prose
   elsewhere in the file references a now-shifted row number.
9. `bash tests/validate.sh` exit 0.

---

## Step 6 — `install-antislop` overhaul: §4 reality re-sync, missing §3, description (M4, M8, M6 partial)

**Affected files:** `skills/install-antislop/SKILL.md` only.

**6a (M4).** §4 states the graph installer generates
`.claude/skills/code-review-graph/` containing `build-graph`/`review-delta`/
`review-pr` workflow skills. That directory does not exist; what ships is four
differently-named directories (`debug-issue`, `explore-codebase`,
`refactor-safely`, `review-changes`). Rewrite that bullet to name what actually
ships, retaining the existing "don't wire them into `explorer.md`" guidance and
the "this integration has changed shape before" caveat.

**6b (M8) — REVISED in Revision 3 (G5): the renumbering is WITHDRAWN; only the
description is fixed.**

M8 has two halves. The `description:` promising "third-party skill installs" as
covered scope, with no section covering it, is a **real inaccuracy** — vendoring
removed that scope for real. Fix it: drop the phrase.

The missing §3 is **cosmetic, and closing it is now judged net-negative.** Two
measured reasons:

1. **The renumbering endangers 33 in-document cross-references to save nothing.**
   `task-master`'s census (authoritative, reproduced 2026-08-04) shows a uniform
   down-shift would leave only the 3 references to the vanishing §12 detectably
   broken; the other ~30 would still resolve — silently, to the **wrong**
   section. In an install runbook, a cross-reference that points confidently at
   the wrong step is worse than a gap in the numbering. Three reference forms
   (`sections 1-10` line 69, `step 4 and/or 5's` line 226, `steps 2-5` line 290)
   are ranges/conjunctions that a naive extractor misses entirely, and line 488's
   `the convergence plan's Step 4` points at an **external document** and must
   never be renumbered at all.
2. **A gap-free integer sequence was never this doc's convention.** It already
   ships `## 0.5` and `## 6.5` — fractional numbers used deliberately to insert
   a section *without* renumbering its successors. That is the same stable-label
   discipline that says a removed section leaves a gap and that is fine. Closing
   the §3 gap would contradict the doc's own established practice.

**Instead:** leave every heading number exactly as-is and add one short
numbering note as body prose in the tail of the section preceding the gap. That
converts an unexplained gap into a documented one, which is what actually stops
a future audit re-flagging it — renumbering would not have.

**Use this exact wording (Revision 4, G6 — mutation-verified, see below):**

```
> **Numbering note.** The section numbers in this document are stable labels,
> not a contiguous sequence — the fractional headings above exist precisely so
> that inserting material never shifts an existing number. The number three is
> unused: the material it once carried covered installing skills sourced from
> outside this repository, which became unnecessary once those skills were
> vendored first-party under `skills/`. The gap is deliberate — do not renumber
> to close it.
```

**Two literal prohibitions this wording satisfies, and why they are not
optional.** Revision 3 prescribed prose that violated this step's own criteria —
`task-master` proved it by mutation. Any replacement wording MUST:

1. **Contain no `§N` / `step N` / `section N` form** (no numeral preceded by
   `§`, `step(s)` or `section(s)`). Criterion 7 freezes the cross-reference
   multiset; the earlier wording's `§3` added a `1 §3` row and made the diff
   non-empty. The wording above spells the number as the word "three" and
   contains **no numerals at all**, so the multiset is untouched.
2. **Not contain the phrase `third-party skill install`** (case-insensitive).
   Criterion 6 drives that phrase to a file-wide count of `0`; the earlier
   wording re-introduced it. The wording above says "skills sourced from outside
   this repository" instead.

**Verified by mutation before prescribing it** (both directions, 2026-08-06,
against a copy with 6b's description fix already applied):

| check | new wording | earlier wording (negative control) |
|---|---|---|
| crit 6 — `grep -ci 'third-party skill install'` → `0` | **0** ✅ | `1` ❌ |
| crit 7 — ref-multiset `diff` empty | **identical** ✅ | `19a20 > 1 §3` ❌ |
| crit 5 — heading-set `diff` empty | **identical** ✅ | identical |

The negative control matters as much as the positive one: it proves criteria 6
and 7 actually detect this violation rather than passing vacuously.

This reverses my own Revision 1 recommendation ("Option (b) is recommended").
The recommendation predated the cross-reference census; with it, the risk/benefit
inverts. Reversible if the human prefers a gap-free sequence, but then the
renumbering needs its own dedicated unit with a per-reference mapping table, not
a bundled sub-step here.

**6c — WITHDRAWN in Revision 2 (G2). Do not perform.** Revision 1 claimed 3 bare
`/code-review` slash-command references at lines ~134, 142, 158. **They do not
exist.** Re-measured 2026-08-04: every `code-review` match in this file is part
of the string `code-review-graph` — a GitHub URL (`github.com/tirth8205/code-review-graph`,
line 134), a pipx package name (line 139), and `.claude/skills/code-review-graph/`
directory paths (lines 142, 148, 158, 162). Zero bare slash-command references.

This was my own false positive: the regex `/code-review` matches
`/code-review-graph`, the identical provenance-path trap this spec explicitly
excludes elsewhere in its own M6 count. **The withdrawal is load-bearing, not
cosmetic** — an implementer told to "repoint 3 `/code-review` references" here
would most likely rewrite the graph tool's real URL or its real directory names,
breaking §4 (which Step 6a is simultaneously fixing to name those very
directories correctly).

Consequence: **M6 is fully discharged by Step 4 alone** (the single free
`/implement` reference in `skills/to-tickets/SKILL.md:108`). The remaining 12 M6
references all sit in drift-checked files and stay deferred, as Revision 1
already stated.

**Acceptance criteria:**
1. Pre-change baselines: `grep -c 'skills/code-review-graph' skills/install-antislop/SKILL.md` ≥ `1`;
   `grep -cE '^## 3\.' skills/install-antislop/SKILL.md` → `0`.
2. §4's false claim is gone:
   `grep -c 'skills/code-review-graph' skills/install-antislop/SKILL.md` → `0`.
3. All four real directory names appear: for each of `debug-issue`,
   `explore-codebase`, `refactor-safely`, `review-changes`,
   `grep -c "<name>" skills/install-antislop/SKILL.md` ≥ `1`.
4. The caveat survives (regression guard on a deliberate non-removal):
   `tr '\n' ' ' < skills/install-antislop/SKILL.md | tr -s ' ' | grep -c 'stays accurate forever'` → `1`.
5. **REPLACED in Revision 3 (G5). Headings are frozen, not renumbered.** The
   heading set must be **byte-identical** before and after:
   `grep -E '^## [0-9]+(\.5)?' skills/install-antislop/SKILL.md` produces output
   identical to the pre-change capture (`diff` of the two captures is empty).
   The §3 gap is retained deliberately — see 6b. This replaces the old
   "sequence is gap-free" criterion, which asserted the outcome of the
   now-withdrawn renumbering.
6. `grep -ci 'third-party skill install' skills/install-antislop/SKILL.md` → `0`.
   *(This is the one half of M8 that remains in scope.)*
7. **REPLACED in Revision 3 (G5) — cross-references frozen, not re-resolved.**
   The old criterion checked only that no reference pointed at a *vanished*
   number, which `task-master`'s census showed would catch **3 of 33**
   references; the other ~30 would resolve to the wrong section undetected, and
   range/conjunction forms were invisible to its extractor entirely. Since 6b no
   longer renumbers, the correct and fully-covering assertion is that **no
   cross-reference changes at all**. Capture the multiset before and after and
   require them identical (order- and line-number-independent, so the added
   parenthetical in 6b cannot perturb it):

   ```
   grep -oE '(§|[Ss]teps?|[Ss]ections?) ?[0-9]+(\.5)?( ?(-|to|and/or|and) ?[0-9]+(\.5)?)?' \
     skills/install-antislop/SKILL.md | sort | uniq -c
   ```

   must produce byte-identical output pre- and post-change. This covers all 33
   references including the three range/conjunction forms (lines 69, 226, 290)
   **and** automatically protects line 488's external `the convergence plan's
   Step 4` reference, which is left untouched by construction rather than by an
   exclusion rule that could be mis-transcribed.
7b. **Anti-vacuity floor for criterion 7** (a mis-typed regex matching nothing
   would make "identical output" trivially true): the capture must be non-empty
   and of the expected size — the pre-change capture has
   `grep -coE '(§|[Ss]teps?|[Ss]ections?) ?[0-9]+' skills/install-antislop/SKILL.md`
   ≥ `30` matching lines. Record the exact baseline at execution time.
8. **Anti-regression guard replacing withdrawn 6c (Revision 2, G2).** The old
   criterion (`grep -cE '...(/code-review)\b' → 0`) was already `0` at baseline,
   so it provided no coverage while inviting an implementer to "fix" the graph's
   real names. Replace it with a guard that those names survive **unchanged**:
   `grep -c 'github.com/tirth8205/code-review-graph' skills/install-antislop/SKILL.md` → `1`
   **and** `grep -c 'pipx install code-review-graph' skills/install-antislop/SKILL.md` → `1`
   **and** `grep -c 'code-review-graph install --platform claude-code' skills/install-antislop/SKILL.md` → `1`.
   These are the graph tool's real URL, package and CLI invocation; none may be
   renamed by this step.
9. Ceiling control: `git diff --numstat -- skills/` lists only
   `skills/install-antislop/SKILL.md`.
10. `bash tests/validate.sh` exit 0 and
    `bash scripts/resync-vendored-skills.sh --check` exit 0 (this file is
    first-party, so the check must be unaffected).

---

## Step 7 — Resolve the `.claude/skills/` duplicates (M3, OQ5)

**REVISED in Revision 5 (G7). The premise changed under the unit: there are no
longer two files per directory to choose between — there is one, and the copy
this step must keep has to be recovered from a stash first.** The *decision* is
untouched (uppercase wins, on the re-verified `_tool` roster); only the
mechanics change. Read the recovery sub-step below before touching anything.

**Affected files:** in each of
`.claude/skills/{debug-issue,explore-codebase,refactor-safely,review-changes}/`:
delete `skill.md` (tracked, lowercase), and restore-then-**git-add** `SKILL.md`
(uppercase) from `stash@{0}`'s untracked parent.

Grounded in the explorer's live MCP roster, re-verified 2026-08-06 (see
Context): the server's 28 tools all carry the `_tool` suffix and no non-suffixed
form exists, which is the uppercase copies' convention. The lowercase copies'
non-suffixed names are legacy output from an older installer and would not
resolve. Keeping one file per directory also removes the cross-platform hazard
where the two names collide into one file on case-insensitive filesystems.

**7a — Recover the uppercase copies (new in Revision 5).** They are **not**
missing-and-must-be-recreated; they are parked in a stash. Restore exactly four
paths from the stash's untracked-files parent:

```
git checkout a0d90e5969982168b323b58d876fdd4c636cd81c -- .claude/skills/
```

That commit's tree contains **only** those four `SKILL.md` files under
`.claude/skills/`, so the pathspec cannot over-restore; the command both writes
and stages them. Use the **full SHA**, not `stash@{0}^3` — a stash index shifts
if anything else is stashed in the meantime.

**Do NOT `git stash pop`, `apply`, or `drop`.** That stash holds 119 untracked
files plus tracked edits across `.claude/agent-memory/` and `.claude/wiki/`;
popping it dumps 115 unrelated files into the tree (see **R9**). Criterion 7
fails the unit if the stash is disturbed.

**Ordering is mandatory: delete the lowercase files FIRST, then restore.** On a
case-insensitive filesystem the two names are the same file, so restoring first
would write `SKILL.md` onto `skill.md`'s inode and the subsequent `git rm` would
delete the very content being kept. Delete-first is correct on both filesystem
kinds.

**Do NOT author, regenerate, or hand-edit `SKILL.md` content.** The content is
already verified correct — this step relocates tracking, nothing else. It is
also *incompletely* accurate in a way that is deliberately out of scope; see
**R8** before "improving" anything.

**Fallback if the stash no longer exists** (it does as of 2026-08-06; verify with
criterion 1c before assuming otherwise): regenerate with `code-review-graph`
**2.3.7+** into a *scratch* directory and copy only the four `SKILL.md` files
across — never run the installer against this repo root, which would rewrite
unrelated project files. Whichever source is used, criteria 4 and 5 are the
acceptance gate on content, so a wrong-version regeneration fails rather than
silently landing.

**Acceptance criteria** (all re-measured and mutation-tested in a throwaway
worktree 2026-08-06; the *pre-fix* column is the negative control proving each
one can actually fail):

1. Pre-change baselines, **corrected in Revision 5** — the old baseline of `8`
   for criterion 1 described a working tree that no longer exists:
   `find .claude/skills -maxdepth 2 -name 'skill.md' | wc -l` → `4` (lowercase,
   case-**sensitive**); `find .claude/skills -maxdepth 2 -name 'SKILL.md' | wc -l`
   → `0`; `git ls-files .claude/skills/ | grep -c 'SKILL.md'` → `0`.
   1c. The recovery source is present before starting:
   `git rev-parse --verify a0d90e5969982168b323b58d876fdd4c636cd81c^{tree}` exit 0
   **and** `git ls-tree -r --name-only a0d90e5969982168b323b58d876fdd4c636cd81c | grep -c '^\.claude/skills/.*/SKILL\.md$'` → `4`.
   If this fails, use the regeneration fallback above — do not improvise.
2. Post-change: exactly one file per directory —
   `find .claude/skills -maxdepth 2 -iname 'skill.md' | wc -l` → `4`.
   **Vacuity warning (Revision 5):** this `-iname` form now measures `4` at
   baseline **and** `4` post-change, so it proves only the "one file per
   directory" invariant and is **not** evidence the change happened. The
   discriminating assertions are 2b and 3b/3c.
   2b. Case-**sensitive**, and therefore discriminating:
   `find .claude/skills -maxdepth 2 -name 'SKILL.md' | wc -l` → `4` (was `0`)
   **and** `find .claude/skills -maxdepth 2 -name 'skill.md' | wc -l` → `0`
   (was `4`).
3. All four are tracked: `git ls-files .claude/skills/ | wc -l` → `4`.
   **Also non-discriminating** — it measures `4` before and after, since four
   lowercase files were already tracked. The weight sits in 3b and 3c:
   3b. `git ls-files .claude/skills/ | grep -c 'SKILL.md'` → `4` (was `0`).
   3c. `git ls-files .claude/skills/ | grep -c '/skill\.md$'` → `0` (was `4`) —
   asserts on the count, never on a negated exit status.
4. The surviving copies use the verified convention:
   `grep -c '_tool' .claude/skills/debug-issue/SKILL.md` → `4` (was `0`), and no
   non-suffixed form of the four core names remains anywhere:
   ``grep -cE '`(semantic_search_nodes|query_graph|detect_changes|get_impact_radius)`' .claude/skills/*/SKILL.md`` → `0` for every file.
   Expected `_tool` totals per file, as a transcription guard: `debug-issue` 4,
   `explore-codebase` 4, `refactor-safely` 7, `review-changes` 4.
   **Scope note:** this certifies the four core names only, not the whole file —
   see **R8**.
5. `name:` fields are kebab-case and match their directory: for each dir,
   `grep -c "^name: <dirname>$" .claude/skills/<dirname>/SKILL.md` → `1` (was
   `0` — the lowercase copies carried Title Case names such as `Debug Issue`).
6. `bash tests/validate.sh` exit 0. **Note:** its skill-frontmatter check globs
   `skills/*/SKILL.md` only and does **not** cover `.claude/skills/`, so this is
   a non-regression check — criteria 4 and 5 carry the actual weight.
7. **Stash integrity (new in Revision 5, per R9).** The stash is untouched:
   `git rev-parse stash@{0}` equals its pre-change value
   (`bf561cd07d8389b7661abd41feef171fb4d1afeb` as of 2026-08-06) **and**
   `git stash list | wc -l` equals its pre-change value (`1`). Capture both
   before starting.
8. **Blast-radius ceiling (new in Revision 5).** Nothing outside the four
   directories is staged:
   `git diff --cached --name-only | grep -v '^\.claude/skills/' | wc -l` → `0`.
   Piping to `wc -l` rather than using `grep -vc` keeps the exit status clean,
   per CHK13. Expect exactly four staged entries; git will likely report them as
   renames (`R070`-ish similarity), which is normal and not a defect.

---

## Step 8 — Correct the design docs; verify #235's template fix (C1 docs)

**Affected files:** `docs/persona-design-notes.md` (lines 34, 64, 117, 131-132).
**Verification-only, not edited here:** `templates/persona-protocol.md`,
`templates/persona-protocol-slim.md` — owned by issue #235 per the Sequencing
decision. **Runs after #235 lands.**

**Revision 2 correction (G3) — there are 4 occurrence sites, and one of them
must NOT be changed.** Re-measured 2026-08-04:

| line | persona | skills named | flagged? | action |
|---|---|---|---|---|
| 34 | spec-master | `grill-me`, `to-spec` | **yes** | rewrite |
| 64 | task-master | `to-issues` (nonexistent) | **yes** (`to-tickets`) | rewrite |
| 93-94 | **reviewer** | `coding-discipline`, `roast-work` | **NO** | **leave unchanged** |
| 131-132 | scribe | `improve-codebase-architecture` | **yes** | rewrite |

The reviewer site at 93-94 was missed in Revision 1. It is **factually correct
as written**: both `coding-discipline` and `roast-work` are unflagged (verified
`0` in the live plugin cache), so a teammate genuinely can invoke them via the
`Skill` tool, and preloading genuinely does not apply to teammates. This spec's
rewrite rationale — "the invocation fails for a flagged skill" — simply does not
apply there. Editing it would replace a true sentence with a misleading one.

Rewrite the **three** flagged-skill sites (34, 64, 131-132): the invocation fails
for a flagged skill, and the limitation is not teams-mode-specific. Also fix line
117's "`Skill` carries `grill-me`" claim (now `grilling`).

**Exact replacement text to be merged into #235's compression** (supplied here
so it can be pasted into that issue; it is shorter than the two lines it
replaces, which helps #235's byte ceiling):

> - Your `skills:`/`mcpServers:` frontmatter is NOT applied to a teammate. A
>   skill marked `disable-model-invocation` is unreachable to any agent in any
>   mode — read its `SKILL.md` directly instead; otherwise ask the explorer
>   teammate via `SendMessage`.

**Acceptance criteria:**
1. **Pre-change baseline — wrap-safe counting is mandatory here (Revision 2,
   G3).** Revision 1 stated a baseline of `3`; that was wrong twice over. Raw
   `grep -c "since preloading doesn't apply to teammates" docs/persona-design-notes.md`
   measures **2**, because two of the four occurrences wrap across a line break
   (93-94 and 131-132) and `grep -c` counts *matching lines*, not occurrences.
   The correct baseline is taken collapsed:
   `tr '\n' ' ' < docs/persona-design-notes.md | tr -s ' ' | grep -o "since preloading doesn't apply to teammates" | wc -l` → **`4`**.
   Use `grep -o | wc -l`, never `grep -c`, for every count in this step.
2. Post-change, the collapsed count is **`1`, not `0`** — the reviewer site at
   93-94 is deliberately retained (see the table above):
   `tr '\n' ' ' < docs/persona-design-notes.md | tr -s ' ' | grep -o "since preloading doesn't apply to teammates" | wc -l` → `1`.
2b. The one survivor is the reviewer's, not a missed rewrite — assert it sits in
   the sentence naming the two unflagged skills:
   `tr '\n' ' ' < docs/persona-design-notes.md | tr -s ' ' | grep -c 'coding-discipline and roast-work explicitly, since preloading'` → `1`.
2c. The corrected framing is present for the three rewritten sites:
   `grep -c 'disable-model-invocation' docs/persona-design-notes.md` ≥ `1`.
3. Line 117's stale skill name is fixed:
   `tr '\n' ' ' < docs/persona-design-notes.md | tr -s ' ' | grep -c 'carries .grill-me.'` → `0`;
   `... | grep -c 'carries .grilling.'` ≥ `1`.
4. **Verification that #235 preserved the correction — both tiers asserted
   separately, WRAP-SAFE (corrected in Revision 3, G4).** A criterion naming
   only the full protocol leaves the slim tier shipping the wrong instruction.

   **The previous form was vacuous.** `grep -c 'in your tools list'` measures
   **`0` at baseline in both tiers** — the phrase straddles a line break
   (`persona-protocol.md:48-49` and `persona-protocol-slim.md:51-52`: "…if it's
   in" / "your tools list; …"), and a line-oriented grep cannot see it. The
   assertion could therefore never fail, regardless of whether #235 preserved
   the correction — which is the only reason this criterion exists. Wrap-safe
   baseline is **`1`** in each tier. This matches the shape #235's own criterion
   2b already uses for the identical assertion.

   Post-change, for **each** of `templates/persona-protocol.md` and
   `templates/persona-protocol-slim.md`:
   ```
   s=$(tr '\n' ' ' < <file> | tr -s ' ')
   printf '%s' "$s" | grep -o 'in your tools list' | wc -l   # -> 0 (baseline 1)
   ```
   **and** `grep -c 'disable-model-invocation' <file>` ≥ `1` for each. (This
   second half is sound as-is: it is a single unhyphenated token that cannot
   wrap, and its baseline is `0`.)
5. #235's own ceilings still hold (non-regression):
   `test "$(sed -n '/^## Agent-teams mode/,/^## /p' templates/persona-protocol.md | sed '$d' | wc -l)" -le 8` exit 0, and
   `test "$(wc -c < templates/persona-protocol.md)" -le 16800` exit 0.
6. Ceiling control: this step's own commit touches only
   `docs/persona-design-notes.md` — `git diff --numstat -- docs/ templates/`
   lists exactly that one file.
7. `bash tests/validate.sh` exit 0.

---

## Step 9 — Release: version bump, mirror regeneration, CHANGELOG

**Affected files:** `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
all regenerated `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
`.claude/protocol-digest.md`, `.claude/persona-config.json`.

Bump both manifests to the next minor above whatever is current at execution
time (R2 — never a literal number, since the cost-cutting track also bumps).
Add a CHANGELOG entry recording the capability change: `disable-model-invocation`
makes a skill unreachable to agents in **all** modes; `implement` deleted;
`handoff`/`improve-codebase-architecture`/`to-spec`/`to-tickets` un-flagged;
`grill-me` superseded by `grilling` in persona wiring. Then run
`node bin/cli.js --update` and **commit what it produces**.

**Acceptance criteria:**
1. Versions equal and strictly greater than pre-edit:
   `python3 -c "import json;a=json.load(open('package.json'))['version'];b=json.load(open('.claude-plugin/plugin.json'))['version'];assert a==b"` exit 0,
   and the value differs from the recorded pre-edit version.
2. Mirrors actually regenerated — the version stamp is the proof, **not mtime**
   (the "already current" branch performs no write, so an mtime assertion fails
   on a correct implementation): for every file in `.claude/agents/*.md`,
   `grep -c "antislop v$NEW_VERSION"` → `1`.
3. The rewired frontmatter reached the mirrors:
   `grep -c 'antislop:grilling' .claude/agents/spec-master.md` → `1`;
   `grep -c 'antislop:domain-modeling' .claude/agents/scribe.md` → `1`; and no
   mirror retains the dead name —
   `grep -rl to-issues .claude/agents/ | wc -l` → `0`.
4. `.claude/persona-config.json` is committed if the render changed it (it is
   git-tracked and rewritten by every render).
5. CHANGELOG entry exists for the new version:
   `grep -c "^## \[$NEW_VERSION\]" CHANGELOG.md` → `1`.
6. `bash tests/validate.sh` exit 0;
   `bash scripts/resync-vendored-skills.sh --check` exit 0;
   `node tests/adapter-protocol-parity.test.js` exit 0.
7. **MOVED to Step 10 in Revision 2 (G1b).** The end-to-end reachability probe
   cannot run in this step: `bin/cli.js --update` does not touch the plugin
   cache, and a cache refresh requires a session restart. See Step 10.

---

## Step 10 — Refresh the plugin cache, then verify reachability (Revision 2, G1b)

**NEW in Revision 2.** Runs last, after Step 9's version bump.

**Affected files:** none in this repo. This step performs an installed-plugin
refresh and a post-restart verification.

### Why this step exists (independently verified 2026-08-04)

`task-master`'s finding is confirmed, and is broader than a Step 4 problem.
Measured facts:

- The plugin is installed as `antislop@antislop-marketplace` into a **versioned
  cache copy** at
  `~/.claude/plugins/cache/antislop-marketplace/antislop/0.13.18/`, pinned at
  `gitCommitSha b55dfba` (installed 2026-07-23, last updated 2026-07-30) —
  per `~/.claude/plugins/installed_plugins.json`.
- The marketplace source *is* this repo
  (`known_marketplaces.json` → `{"source":"directory","path":"/home/sebas/AntiSlop"}`),
  but installation **copied** it. The cache is a snapshot, not a live view.
- **The cache is at 0.13.18 while the repo is at 0.22.0** — nine minor versions
  stale. The cached `skills/grill-me/SKILL.md` still carries
  `disable-model-invocation: true`.
- **`bin/cli.js` never writes the cache.** Grepping it for
  `plugins/cache`/`installed_plugins` returns nothing; it scaffolds a *project's*
  `.claude/` directory. `bin/cli.js:821` already states the correct ordering in
  its own user-facing message: "Update the plugin first with `claude plugin
  update antislop@antislop-marketplace`".
- The refresh command exists: `claude plugin update <plugin>` — "Update a plugin
  to the latest version **(restart required to apply)**", per its own `--help`.

So `antislop:*` skills resolve from the cache, and **editing this repo does not
change what `Skill()` loads until the cache is refreshed and the session
restarts.**

### Which steps this actually affects (narrower than feared)

| step | affected? | why |
|---|---|---|
| 1, 2 | **no** | pure text renames in `agents/*.md`; assert no skill resolution |
| 3 | **no** | repoints to `grilling` and `domain-modeling`, both **already unflagged in the live 0.13.18 cache** (verified `0`), so they resolve today |
| 4, 5 | **yes** | un-flagging only takes effect after a cache refresh |
| 6, 7 | **no** | 6 is a first-party doc; 7 edits `.claude/skills/`, which are **project-level** skills read from the project dir, not the plugin cache |
| 8 | **no** | documentation only |
| 9 | **no** | `.claude/agents/` mirrors are project-level and override plugin agents |

Only Steps 4 and 5 make reachability claims, and both now defer their proof
here. Steps 1–3 and 6–9 are unaffected, so **no already-filed unit needs its
substance changed on account of G1b** beyond Step 4's criterion 6.

### Procedure

1. Run `claude plugin update antislop@antislop-marketplace`.
2. Restart the session (the CLI's own help states a restart is required).
3. Run the verification criteria below in the fresh session.

**Acceptance criteria:**
1. A new cache directory exists matching Step 9's bumped version:
   `test -d ~/.claude/plugins/cache/antislop-marketplace/antislop/$NEW_VERSION`
   exit 0, and
   `python3 -c "import json;d=json.load(open('$HOME/.claude/plugins/installed_plugins.json'));assert d['plugins']['antislop@antislop-marketplace'][0]['version']=='$NEW_VERSION'"`
   exit 0.
2. The refreshed cache carries the un-flagged skills — this is the criterion the
   repo-side greps cannot provide. With
   `C=~/.claude/plugins/cache/antislop-marketplace/antislop/$NEW_VERSION/skills`:
   `grep -c disable-model-invocation $C/to-spec/SKILL.md` → `0`; same for
   `to-tickets`, `handoff`, `improve-codebase-architecture` → `0` each.
3. The deleted skill is gone from the cache too:
   `test -e $C/implement` exit 1.
4. **Anti-vacuity floor** (guards against asserting on a stale or wrong
   directory, which would make criteria 2–3 pass against a path that does not
   exist): `grep -c disable-model-invocation $C/grill-me/SKILL.md` → `1`.
   `grill-me` is deliberately left flagged by OQ2, so a cache that is genuinely
   the new one returns exactly `1` here while returning `0` for criterion 2's
   four skills. A mis-pathed `$C` fails this criterion instead of silently
   passing everything.
5. **End-to-end reachability probe** (moved from Step 9, and now actually
   satisfiable). In the restarted session, dispatch `scribe` and
   `milestone-auditor`; each reports at least one skill body present in its own
   context (`domain-modeling` and `grilling` respectively). At baseline both had
   **zero** working skills, so this is the one criterion proving the Goal was met
   rather than that files changed.
6. `Skill(antislop:to-tickets)` succeeds rather than returning
   `cannot be used with Skill tool due to disable-model-invocation` — the exact
   probe that failed at baseline.

**Dispatch note.** Criteria 1–4 are mechanical and agent-runnable. Criteria 5–6
require the post-restart session, so this step is **not** a normal
`lead-programmer` unit — it needs a human-run plugin update plus a restart, then
a verification pass. Slice it as a human-gated unit, not an autonomous one.

---

## Open Questions

**None — all five were resolved by the human on 2026-08-04** and are recorded in
the Clarifications log above. One judgment call made while finalizing is flagged
separately as **Decision D1**, and one observation about another spec's unit is
recorded as **R6**; neither blocks slicing.

## Self-check

- CHK1: Is the actual scope of `disable-model-invocation` defined, rather than
  assumed from the audit's description? — PASS (measured via within-persona
  differential; the probe result is recorded in Context).
- CHK2: Do the Context table and Step 4 agree about which skills are free to
  edit without drift cost? — PASS (both name exactly `to-spec` and `to-tickets`,
  on the basis of `REPOINT_SKILLS`).
- CHK3: Is the `to-issues` occurrence count stated precisely enough to write a
  criterion against? — FAIL (ambiguous: the audit conflated lines with
  occurrences and named a file with zero) — revised in place (Context states 12
  lines / 14 occurrences across exactly 4 files; Steps 1–2 assert per-file).
- CHK4: Does every step that edits `agents/*.md` say how the mirror propagates,
  and is that criterion non-vacuous? — FAIL (missing in the first draft) —
  revised in place (regeneration consolidated into Step 9, which uses the
  version stamp as proof and explicitly rejects mtime).
- CHK5: Do any two steps edit the same file, risking a conflict once sliced into
  independently-grabbable units? — FAIL (conflicting in the first draft:
  `agents/spec-master.md` and `agents/task-master.md` were each touched by two
  separate steps) — revised in place (steps are now one-file-scoped for
  `agents/`, and every step carries a `git diff --numstat` ceiling control).
- CHK6: Do the Sequencing decision and R1 agree about who owns the template
  edit? — PASS (both assign it to #235, with Step 8 verifying rather than
  editing).
- CHK7: Is the fate of each of the 6 flagged skills accounted for exactly once?
  — PASS (`to-spec`/`to-tickets` → Step 4; `handoff`/`improve-codebase-
  architecture` → Step 5; `implement` → deleted in Step 5; `grill-me` → left on
  disk, frontmatter repointed in Steps 1 and 3).
- CHK8: Is M7's claim about preload cost verified rather than inherited? — FAIL
  (conflicting: the audit asserts a 6.25KB per-spawn cost, the measurement shows
  zero) — revised in place (Context records the premise as void; Decision D1
  records that Step 5 *makes it real*, which is why scribe's frontmatter drops
  it).
- CHK9: Is "unwired" distinguished from "unreachable" everywhere either word is
  used? — PASS (Context defines the split; OQ4's answer applies it).
- CHK10: Does any criterion assert agent-teams-mode behaviour, which cannot be
  mechanically tested here? — PASS (R4 forbids it; all criteria are static
  assertions or single-agent probes).
- CHK11: Is the authoritative tool-name set for the M3 duplicates defined? —
  FAIL (missing; no on-disk ground truth existed) — resolved by dispatching
  `explorer` for a live MCP roster query; Step 7 now cites the verified `_tool`
  convention.
- CHK12: Are the constitution's MUST principles each addressed, including P3's
  non-obvious coupling to propagation? — PASS (Constitution check section; P3's
  dual role is stated in Context and used in Step 9).
- CHK13: Does every negated-grep criterion avoid the `!`-inverts-exit-2 trap? —
  FAIL (ambiguous in the first draft) — revised in place (criteria assert on
  counts via `grep -c` / `wc -l` equal to `0`, never on a negated exit status).
- CHK14: Is there a criterion that would fail if the new `fm-noflag` drift path
  silently stopped detecting drift? — FAIL (missing in the first draft) —
  revised in place (Step 5 criterion 4 is a mandatory mutation control that
  re-inserts the flag and requires `[DRIFTED]` plus exit 1).
- CHK15: Does the plan state a definitive answer to the coordinator's sequencing
  question, rather than merely describing the risk? — PASS (Sequencing decision
  names the merge, the amendment to #235, and the landing order, with the
  failure mode of each alternative ordering).
- CHK16: Is there a criterion proving the Goal was met, not merely that files
  changed? — FAIL (missing in the first draft) — revised in place (Step 9
  criterion 7 probes `scribe` and `milestone-auditor`, which had zero working
  skills at baseline).
- CHK28: Does any **prose this spec prescribes for insertion** contain a literal
  that one of this spec's own criteria forbids or freezes? — FAIL (conflicting,
  three times: Step 4's and Step 5's header notes contained
  `disable-model-invocation`, which their criterion 2 drives to `0`; Step 6b's
  parenthetical contained both `§3` and `third-party skill installs`, which
  criteria 7 and 6 respectively forbid) — revised in place (Revision 4, G6).
  **Standing rule for this spec and any successor: prescribed insertion text
  must be mutation-tested against every criterion in its own step before it is
  written into the plan** — apply the text to a scratch copy, run the step's
  criteria, and keep the rejected wording as a negative control proving those
  criteria actually detect the violation. Asserting compatibility by reading is
  what failed all three times.
- CHK29: Does every step's stated **pre-change baseline still describe the
  working tree as it is now**, rather than as it was when the baseline was
  measured? — FAIL (missing: Step 7's criterion 1 asserted a baseline of `8`
  files that had dropped to `4` before the unit was dispatched, making the unit
  unexecutable as written) — revised in place (Revision 5, G7). **Standing rule:
  a baseline is a measurement with an expiry, not a fact.** Any criterion whose
  baseline depends on *untracked* files is especially perishable — untracked
  state is invisible to `git log`, so nothing in the history records its loss,
  and routine commands (`git stash -u`, `git clean`) remove it silently. Where a
  step depends on untracked content, the step must name a recovery source and
  carry a criterion asserting that source exists **before** the work starts
  (Step 7's criterion 1c), so a stale baseline surfaces as a clean precondition
  failure rather than as a mid-flight escalation.
- CHK30: Is every criterion **discriminating** — does it measure differently
  before and after the change, rather than merely being true afterwards? — FAIL
  (missing: Step 7's criteria 1 and 3 both measure `4` at baseline *and* `4`
  post-change once the premise shifted, so they could not distinguish a
  completed unit from an untouched one) — revised in place (Revision 5: 2b, 3b
  and 3c added as the case-sensitive, discriminating forms, with the vacuous
  originals retained and explicitly labelled as invariant checks). This is the
  same defect class as CHK26's anti-vacuity floor, arrived at from the opposite
  direction: CHK26 guards a criterion that matches *nothing*, CHK30 guards one
  that was *already green*. **Standing rule: every criterion in this spec must
  be mutation-tested against a negative control** — apply it to the pre-change
  tree and confirm it fails there — which is how both defects were caught.
- CHK24: Does every criterion that greps a **multi-word phrase** use the
  wrap-safe `tr '\n' ' ' | tr -s ' ' | grep -o | wc -l` form rather than a
  line-oriented `grep -c`? — FAIL (missing: Step 8's criterion 4 greped
  `in your tools list` raw, which measures `0` at baseline in both tiers because
  the phrase straddles a line break, making the assertion unfailable) — revised
  in place (Revision 3, G4). Audited every other criterion in this spec at the
  same time: Steps 4, 5, 6-crit-4, 8-crit-2/2b/3 already use the wrap-safe form;
  Steps 1, 2, 3, 9 grep single-line frontmatter or single tokens that cannot
  wrap; Step 6's new criterion 8 greps three phrases verified to sit on one line
  each (134, 139, 140). No further instances.
- CHK25: When a criterion is found to under-cover a risky operation, does the
  plan patch the check or remove the risk? — FAIL (ambiguous: Step 6's
  criterion 7 covered 3 of 33 cross-references, and the first instinct was a
  larger verification harness) — revised in place (Revision 3, G5: the
  renumbering that created the risk is withdrawn; criteria 5 and 7 become freeze
  assertions, which cover all 33 references and protect the external reference
  at line 488 by construction rather than by an exclusion rule).
- CHK26: Does any freeze/"identical output" criterion have an anti-vacuity
  floor? — PASS (Step 6's new criterion 7b requires the capture be non-empty and
  ≥30 matching lines, so a mis-typed regex matching nothing cannot make
  "identical before and after" trivially true).
- CHK27: Does the plan ever contradict a target document's own established
  convention? — FAIL (conflicting: Revision 1's renumbering assumed a gap-free
  integer sequence, but `install-antislop` ships `## 0.5` and `## 6.5`,
  i.e. deliberate fractional inserts that exist precisely to avoid renumbering)
  — revised in place (Revision 3, G5: gaps are the doc's own convention, so the
  §3 gap is documented rather than closed).
- CHK18: Can any two criteria within a single step be satisfied simultaneously?
  — FAIL (conflicting: Step 4's criteria 2 and 4 asserted `0` and `≥1` for the
  same literal in the same file) — revised in place (Revision 2, G1: the header
  wording no longer contains the literal, so both assertions hold).
- CHK19: Does the plan distinguish where a skill file is *edited* from where it
  is *loaded*? — FAIL (missing: Revision 1 assumed a repo edit changes what
  `Skill()` resolves) — revised in place (Revision 2, G1b: R7 states the cache
  indirection, Step 10 performs the refresh, and both reachability probes moved
  there).
- CHK20: Is every "N references exist" claim backed by a match count that
  excludes substring false positives? — FAIL (missing for Step 6c: `/code-review`
  matched `/code-review-graph`) — revised in place (Revision 2, G2: 6c withdrawn
  and replaced with a survival guard on the graph's real names).
- CHK21: Does every baseline count state whether it was measured raw or
  wrap-collapsed? — FAIL (missing: Step 8's baseline of `3` matched neither —
  raw is `2`, collapsed is `4`) — revised in place (Revision 2, G3: the step now
  mandates `grep -o | wc -l` and states both numbers).
- CHK22: Does any step demand editing text that is factually correct? — FAIL
  (conflicting: Step 8's old "count → 0" target would have forced a rewrite of
  the reviewer site, whose skills are unflagged and whose sentence is true) —
  revised in place (Revision 2, G3: target is `1`, with criterion 2b pinning the
  survivor to the reviewer sentence).
- CHK23: Is Step 10's cache assertion protected against passing vacuously on a
  wrong path? — PASS (criterion 4 requires `grill-me` to still return `1`, which
  a mis-pathed or stale `$C` cannot satisfy alongside criterion 2's four zeros).
- CHK17: Does Step 5's "remove `implement` from the registry files" criterion
  survive the fact that "implement" is a common English word? — FAIL (ambiguous:
  a whole-file `grep -c implement → 0` would be unsatisfiable on `README.md`) —
  revised in place (criterion 7 now scopes the assertion to the vendored-list
  lines and requires a per-file pre-change baseline).

## Scribe update hint

Record in `.claude/wiki/changelog.md` that `disable-model-invocation` makes a
skill unreachable to agents in **all** modes (not just agent-teams), and that
this was inherited from upstream mattpocock rather than chosen by antislop.
Update `.claude/wiki/dependencies.md`'s vendored-skill list to 11 skills and
note the two intentional `fm-noflag` deviations. `CONTEXT.md:126`'s `grill-me`
mention needs updating to `grilling`. **A new ADR is warranted** — Step 5
changes what "vendored verbatim" means by introducing a declared-deviation
class, which supersedes part of ADR-0005.

---

## Convergence follow-ups

### 2026-08-07 — post-milestone audit (`milestone-auditor`, spec #245, units #246–#255 all PASS)

**Append-only.** Steps 1–10 above and their acceptance criteria are unchanged
and un-renumbered. This section adds exactly one new step (**Step 11**) closing
exactly one accepted finding. No work beyond that finding is added here.

**The finding, verbatim in substance:** `unconverged-requirement` — *missing ADR
for the `fm-noflag` declared-deviation class.* `docs/adr/` ends at ADR-0011 and
none of the eleven concerns vendoring deviations, while
`docs/adr/0005-vendor-mattpocock-skills.md` still reads `Status: Accepted` with
no amendment note. Unit **#248** (Step 5) shipped a declared-deviation class
that changes what Decision 1's word "verbatim" means. The *operational* record
(`scripts/resync-vendored-skills.sh`, the runbook, NOTICES, README, wiki) was
updated per Step 5 criterion 7; the *architectural* record was not. Accepted by
the human operator 2026-08-07 and routed back here rather than to a new spec.

**This plan's own Scribe update hint (above) already called for it** — the
finding is therefore a delivery gap, not a discovery, which is why it resolves
as an append rather than a replan.

#### What I re-verified on disk before writing Step 11 (2026-08-07, live)

The auditor's finding is accurate but under-specifies the *scope* of the
deviation, and Step 11's value is mostly in getting that scope right. Measured
directly, `grep -c '^disable-model-invocation: true$'` and `grep -c
'model-invocation block removed'` per vendored `SKILL.md`:

| skill | upstream flag stripped? | drift-tracked as | in the script's `FILES`? |
|---|---|---|---|
| `handoff` | yes | **`fm-noflag`** | yes, byte-diffed |
| `improve-codebase-architecture` | yes | **`fm-noflag`** | yes, byte-diffed |
| `to-spec` | yes | *nothing* | no — `REPOINT_SKILLS`, report-only |
| `to-tickets` | yes | *nothing* | no — `REPOINT_SKILLS`, report-only |
| `code-review` | n/a (never flagged upstream) | *nothing* | no — `REPOINT_SKILLS` |
| `grill-me` | **no — still flagged** | `fm` (byte-verbatim) | yes, byte-diffed |

So: **four** skills carry the deviation, but only **two** are machine-enforced
by it. `to-spec`/`to-tickets` were un-flagged by Step 4 and sit in the
never-diffed repoint set, so nothing would detect the flag silently returning
there on a re-pin. `grill-me` is the control — vendored, still flagged, still
byte-verbatim, deliberately left alone per CHK7. An ADR that says only
"`fm-noflag` applies to `handoff` and `improve-codebase-architecture`" would be
true-but-misleading; Step 11's criteria force the asymmetry to be recorded.

Also re-measured, and unchanged by this follow-up: `bash
scripts/resync-vendored-skills.sh --check` → exit 0, **8** `[OK]`, 3
`[VENDORED]`; highest existing ADR → `0011`; `.claude-plugin/plugin.json`
version → `0.25.0`; no `.claude/reviewed/248.fail` exists (Step 5 passed first
try, so no prior-defect history constrains the model tier here).

**Numbering note:** `docs/adr/` has no `0007` — an earlier plan reserved that
number and the ADR ultimately shipped as `0009`. Per
`skills/domain-modeling/ADR-FORMAT.md` ("scan for the highest existing number
and increment"), the next number is **0012**; the `0007` gap is left alone.

#### Clarifications (this follow-up only)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-07 Edge cases / failure handling: Q ADR-0005 lines 82–84 assert "this
  repo has no established `Superseded by ADR-000X` marker convention (checked
  0001–0004)" — does adding an in-place note to ADR-0005 contradict its own
  recorded reasoning? → A (self-resolved): no, because the claim is now stale.
  The convention **has** since been established twice — ADR-0004's `## Related`
  carries `- **Amended by ADR-0006:**` and ADR-0006's carries `- **Amended by
  ADR-0009:**`. Step 11 therefore records the note in place *and* requires the
  new bullet to say so explicitly, so the two statements resolve against each
  other instead of contradicting. The 2026-07-15 prose itself is **not**
  rewritten — it was accurate when written, and rewriting shipped ADR reasoning
  is a worse defect than leaving a dated claim dated.
- 2026-08-07 Technical constraints & tradeoffs: Q Which of this repo's two
  in-place amendment patterns applies — ADR-0002's dedicated `## Superseded in
  part (YYYY-MM-DD)` section, or ADR-0004/0006's `## Related` bullet? →
  A (self-resolved): the `## Related` bullet. ADR-0002 used a dedicated section
  precisely because it has no `## Related` section; ADR-0005 does have one, so
  the bullet is the closer precedent. Reinforced with a `Status:`-line
  reference, which is `ADR-FORMAT.md`'s own named mechanism for revisited
  decisions and matches ADR-0006/0009's `Status: Accepted (amends ADR-NNNN…)`
  shape. Two touchpoints, both precedented, both greppable.
- 2026-08-07 Terminology consistency: Q Is this a "declared-deviation class"
  (the auditor's and this plan's word) or a "reconstruction type" (the script's
  and the registry files' word)? → A (self-resolved): both, at different
  layers, and the ADR must say so once rather than pick a winner —
  `fm-noflag` is the *mechanical* reconstruction type in
  `scripts/resync-vendored-skills.sh`'s `FILES` table; "declared deviation" is
  the *architectural* class it implements. Pinning only one would leave the
  other five on-disk usages looking like a different concept.
- 2026-08-07 Completion / acceptance signals: Q Does an architectural-record
  change need a CHANGELOG entry and a version bump? → A (self-resolved):
  a CHANGELOG pointer **yes**, a version bump **no**. Constitution P3 triggers
  only on version-stamped files (`agents/*.md`, templates) and Step 11 touches
  none; but ADR-0005's own Consequences set the precedent ("Recorded in
  `CHANGELOG.md` [0.12.0] alongside this ADR"). The pointer is appended to the
  existing `[0.25.0]` "Skills library remediation" entry, which is where the
  work this ADR documents already shipped. **Reversible** — if the operator
  prefers a fresh version section, that is a one-line change to Step 11's
  criterion 8 and does not disturb the ADR itself.

#### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every fact Step 11 requires the ADR to
  state was measured live above, and criterion 4 makes the implementer re-derive
  the same facts from disk rather than copying this table on trust.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  script-driven path is hand-edited. `scripts/resync-vendored-skills.sh` is
  read-only input to this unit and is on the Do-NOT-touch list.
- P3 "Version-stamp discipline": satisfied by non-trigger, and the non-trigger
  is asserted rather than assumed — criterion 9 proves no version-stamped file
  was touched, and criterion 8 pins the version at `0.25.0`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the ADR
  describes vendored-skill files and a drift script, naming no persona as a
  precondition.
- P5 "`tests/validate.sh` is the merge gate": satisfied — criterion 7.

#### Risks / dependencies (this follow-up only)

- **R8 — documentation-only unit, so most guards are freeze assertions.** The
  real risk is not breakage but an ADR that is vague enough to pass a loose
  grep while still failing to record the asymmetry. Criteria 3 and 4 exist
  specifically to make vagueness fail: 3 requires a per-skill table row, 4
  re-derives every row from disk.
- **R9 — CHK28 standing rule applied.** Every literal string Step 11 prescribes
  for insertion (`Amended by ADR-0012`, `has since been established`, the ADR
  slug) was measured against this step's own criteria at baseline: all return
  `0` before the change and none is driven to `0` by any criterion in this step
  or in Steps 1–10. Step 5's criterion 2 (`disable-model-invocation` → `0`) is
  scoped to two `SKILL.md` files and is not endangered by the ADR text.
- **R10 — out of scope, recorded not fixed.**
  `docs/maintenance/resync-vendored-skills.md:3` still reads "vendors 12 skills"
  while the same file's line 131 reads "all 11 skills", `README.md:255` reads
  11, and `skills/THIRD-PARTY-NOTICES.md`'s table has 11 rows. Line 3 is a
  residual stale count from Step 5's 12→11 change that criterion 7 of that step
  did not cover (it asserted only that `implement` had left the list). This is a
  real defect but **not** part of the accepted finding, so Step 11 does not fix
  it and lists that file under Do-NOT-touch. Surfaced here for the operator to
  route separately.

---

## Step 11 — ADR for the `fm-noflag` declared-deviation class; amend ADR-0005 (Convergence follow-up, 2026-08-07)

**Affected files:** `docs/adr/0012-vendored-skill-declared-deviations.md`
(new), `docs/adr/0005-vendor-mattpocock-skills.md` (additive + one `Status:`
line), `CHANGELOG.md` (one pointer under the existing `[0.25.0]` entry).
Exactly three files, no more.

**11a — Write `docs/adr/0012-vendored-skill-declared-deviations.md`.** Follow
the house shape used by ADR-0003/0004/0005/0006/0009/0010: a `# ADR 0012: …`
title line, a single-line `Date:`, a single-line `Status:`, then `## Context`,
`## Decision`, `## Consequences`, `## Related`. It must record:

- **What the class is** — that antislop vendors mattpocock/skills content
  byte-verbatim by default, and that a *declared deviation* is a documented,
  machine-reconstructed departure from that default; `fm-noflag` is the
  reconstruction type in `scripts/resync-vendored-skills.sh`'s `FILES` table
  that implements it for the one deviation that currently exists (removing
  upstream's model-invocation block).
- **Why Step 5 introduced it** — un-flagging the two drift-checked skills was
  required to make them reachable at all (the flag removes a skill from a
  persona's context in every mode), but an undeclared edit would have turned
  `--check` red and the alternative, dropping them from the diffed set, would
  have lost drift coverage entirely. Declaring the deviation keeps both.
  Cite spec **#245** and unit **#248**.
- **Which skills it applies to, including the asymmetry** — a table with one
  row per skill covering `handoff`, `improve-codebase-architecture`, `to-spec`,
  `to-tickets` and `grill-me`, distinguishing the two that are drift-tracked as
  `fm-noflag` from the two that carry the same deviation *untracked* (they live
  in `REPOINT_SKILLS`, which the script reports but never diffs) and from
  `grill-me`, which is still flagged and still byte-verbatim.
- **The consequence that follows from that asymmetry** — on a re-pin, the flag
  silently returning to `to-spec` or `to-tickets` would not be detected by
  `--check`; that gap is stated, not fixed, by this ADR.
- **`## Related`** — links to ADR-0005, the runbook, NOTICES, and this plan.

**11b — Amend ADR-0005.** Two additive touchpoints, both matching existing
repo precedent:

1. Extend its single-line `Status:` to reference ADR-0012 (the shape ADR-0006
   and ADR-0009 use). **Keep `Status:` on one physical line** — criterion 5
   greps it line-wise, and ADR-0005's is single-line today.
2. Add one bullet to `## Related`, led `- **Amended by ADR-0012:**`, matching
   ADR-0004's `- **Amended by ADR-0006:**` form. The bullet must (a) state that
   Decision 1's "verbatim" is qualified, not withdrawn — the vendoring decision
   itself stands — and (b) contain the phrase **`has since been established`**,
   noting that the "no established `Superseded by ADR-000X` marker convention"
   observation recorded in this ADR's own Consequences was true in 2026-07-15
   but no longer is, which is why this note is recorded in place.

**Do not rewrite ADR-0005's Context, Decision or Consequences prose.** The
2026-07-15 text stays as written; criterion 6 enforces this with a deletion
ceiling.

**11c — CHANGELOG pointer.** Append a reference to the new ADR inside the
existing `[0.25.0]` "Skills library remediation" bullet. Do **not** open a new
version section and do **not** bump `.claude-plugin/plugin.json`.

**Acceptance criteria** (baselines below were measured live 2026-08-07; per
CHK29 they are measurements with an expiry — re-measure before starting, and
if any baseline no longer holds, escalate rather than proceeding):

1. **Numbering, discriminating.** Baseline:
   `ls docs/adr/*.md | sed 's#.*/##' | cut -c1-4 | sort -n | tail -1` → `0011`.
   Post-change → `0012`, and
   `test -f docs/adr/0012-vendored-skill-declared-deviations.md` exit 0.
2. **House shape.** In the new file: line 1 matches `^# ADR 0012: `
   (`head -1 … | grep -c '^# ADR 0012: '` → `1`); `grep -c '^Date: '` → `1`;
   `grep -c '^Status: '` → `1`; and each of `^## Context$`, `^## Decision$`,
   `^## Consequences$`, `^## Related$` → `1`.
3. **Per-skill table rows, discriminating.** In the new file, each of these
   returns `1`:
   `grep -cE '^\| *`handoff` *\|'`,
   `grep -cE '^\| *`improve-codebase-architecture` *\|'`,
   `grep -cE '^\| *`to-spec` *\|'`,
   `grep -cE '^\| *`to-tickets` *\|'`,
   `grep -cE '^\| *`grill-me` *\|'`.
   Additionally the asymmetry must be visible *in the rows themselves*: the
   `handoff` and `improve-codebase-architecture` rows each contain `fm-noflag`
   (`grep -E '^\| *`handoff` *\|' … | grep -c 'fm-noflag'` → `1`, same for the
   other), while the `to-spec`, `to-tickets` and `grill-me` rows each contain
   it `0` times. A row-shape-only check would pass on a table that flattened
   the asymmetry, which is the exact failure this criterion exists to catch.
4. **Table cross-checks disk, not this plan.** Re-derive and confirm the rows
   are true, all measured against the live tree:
   `grep -c '^disable-model-invocation: true$' skills/<s>/SKILL.md` → `0` for
   each of `handoff`, `improve-codebase-architecture`, `to-spec`, `to-tickets`,
   and → `1` for `grill-me`;
   `grep -c 'model-invocation block removed' skills/<s>/SKILL.md` → `1` for the
   first four and `0` for `grill-me`;
   `grep -o 'fm-noflag' scripts/resync-vendored-skills.sh | wc -l` → `5`.
   If any of these disagrees with the ADR's table, the ADR is wrong — fix the
   ADR, never the measured file.
5. **ADR-0005 `Status:` amended, wrap-safe by construction.**
   `grep -c '^Status:' docs/adr/0005-vendor-mattpocock-skills.md` → `1` (still
   exactly one, on one line) and
   `grep -c '^Status:.*ADR-0012' docs/adr/0005-vendor-mattpocock-skills.md`
   → `1`. Baseline for the second: `0`.
6. **ADR-0005 `## Related` bullet, additive only.** Using the wrap-safe form
   `tr '\n' ' ' < docs/adr/0005-vendor-mattpocock-skills.md | tr -s ' ' |
   grep -o '<phrase>' | wc -l`: `Amended by ADR-0012` → `1` (baseline `0`) and
   `has since been established` → `1` (baseline `0`). **Deletion ceiling:**
   `git diff --numstat <base> -- docs/adr/0005-vendor-mattpocock-skills.md`
   shows deletions ≤ `1` (the single rewritten `Status:` line), proving the
   2026-07-15 prose was not rewritten.
7. **Merge gate (invariant/regression guard, not discriminating).**
   `bash tests/validate.sh` exit 0, and
   `bash scripts/resync-vendored-skills.sh --check` exit 0 with
   `… | grep -c '^\[OK\]'` → `8` — unchanged from baseline, proving the ADR
   work did not disturb the drift contract.
8. **CHANGELOG pointer, no version churn.**
   `grep -c '0012-vendored-skill-declared-deviations' CHANGELOG.md` → `1`
   (baseline `0`); `grep -m1 '^## \[' CHANGELOG.md` still returns
   `## [0.25.0] - 2026-08-06` (no new version section);
   `git diff --numstat <base> -- .claude-plugin/plugin.json` → no output
   (version stays `0.25.0`).
9. **P3 non-trigger, asserted.**
   `git diff --name-only <base> -- agents/ templates/ | wc -l` → `0`.
10. **Diff ceiling (surgical-diff control).**
    `git diff --name-only <base> | sort` lists **exactly** these three paths and
    nothing else: `CHANGELOG.md`,
    `docs/adr/0005-vendor-mattpocock-skills.md`,
    `docs/adr/0012-vendored-skill-declared-deviations.md`. `<base>` is the
    commit recorded with `git rev-parse HEAD` **before** the first edit.

---

### Dispatch contract — unit `245-CF1` (fast path)

This follow-up resolves to a single dispatchable unit, so per the ≤2-unit fast
path it is **not** sliced by `task-master` and **no tracker issue is filed**;
the contract below is dispatched directly from this document.

**Unit: `245-CF1`**

#### Objective
Close the accepted `unconverged-requirement` finding from the 2026-08-07
`milestone-auditor` audit of spec #245 by writing ADR-0012 for the `fm-noflag`
declared-deviation class and amending ADR-0005 to point at it. Documentation
only — no code, no script, no skill file changes.

#### Retrieval
No tracker issue exists for this unit. The authoritative source is this
document: `/home/sebas/AntiSlop/docs/plans/2026-08-04-skills-library-remediation.md`,
section **"Convergence follow-ups → Step 11"** plus this contract. Read Step 5
(same file) for the change ADR-0012 documents, and
`skills/domain-modeling/ADR-FORMAT.md` for the numbering rule.

#### Affected files
- `docs/adr/0012-vendored-skill-declared-deviations.md` — new.
- `docs/adr/0005-vendor-mattpocock-skills.md` — `Status:` line + one
  `## Related` bullet. Additive apart from that one line.
- `CHANGELOG.md` — one pointer inside the existing `[0.25.0]` "Skills library
  remediation" bullet.

#### Ordered edits
1. `git rev-parse HEAD` → record as `<base>` for criteria 6, 8, 9, 10.
2. Re-measure every baseline named in the criteria. Any mismatch → escalate,
   do not proceed (CHK29).
3. Write ADR-0012 per 11a. Verify criteria 1–4 before touching anything else.
4. Amend ADR-0005 per 11b. Verify criteria 5–6.
5. Add the CHANGELOG pointer per 11c. Verify criterion 8.
6. Run criteria 7, 9, 10 as the closing sweep.

#### Do NOT touch
- `scripts/resync-vendored-skills.sh`, `docs/maintenance/resync-vendored-skills.md`,
  `skills/THIRD-PARTY-NOTICES.md`, `README.md`, `.claude/wiki/*`, `CONTEXT.md`
  — the operational record was already updated by Step 5 and this unit only
  adds the architectural one. **Specifically including R10's stale "vendors 12
  skills" line at `docs/maintenance/resync-vendored-skills.md:3`** — it is a
  real defect, it is not this finding, and fixing it here would breach both the
  append-only convergence rule and criterion 10.
- Any file under `skills/`, `agents/`, `templates/`, `.claude-plugin/`.
- ADR-0005's `## Context`, `## Decision`, `## Consequences` prose, and ADRs
  0001–0004 and 0006–0011 in their entirety.

#### Acceptance criteria
Step 11's criteria 1–10 above, in full. All ten must pass literally; per the
#255 review note, a criterion whose literal form fails must not be reported as
passing "in intent."

#### Pre-resolved context
- Next ADR number is **0012**; the missing `0007` is a deliberate historical
  gap, not an available slot.
- ADR-0005's claim that no supersession-marker convention exists is **stale** —
  ADR-0004 and ADR-0006 both carry `- **Amended by ADR-NNNN:**` bullets in
  `## Related`. That is the pattern to follow, and criterion 6 requires the new
  bullet to say the convention has since been established.
- The deviation covers **four** skills but is machine-enforced for **two**;
  the verified table is in "What I re-verified on disk" above. Do not copy it on
  trust — criterion 4 requires re-deriving it.
- Constitution P3 does not trigger (no version-stamped file); do not bump the
  plugin version.
- No `.claude/reviewed/248.fail` exists — Step 5 passed first attempt, so there
  is no prior-defect history on this material. Model tiering is the
  orchestrator's call, but note for that call that this unit is judgment-bearing
  prose work with a scope subtlety (the 2-vs-4 asymmetry) that a purely
  mechanical pass would flatten.

#### Escalation
Escalate to the orchestrator rather than improvising if: any baseline in
criterion 1, 5, 6 or 8 no longer holds; criterion 4's disk re-derivation
disagrees with the table above (that means the tree changed since 2026-08-07
and the finding needs re-scoping); or satisfying any criterion appears to
require editing a Do-NOT-touch file.

### Self-check (this follow-up only)

- CHK31: Does the plan say which ADR number to use, and is that number derived
  from a stated rule rather than from counting files? — PASS (`0012`, via
  `ADR-FORMAT.md`'s "highest existing + 1"; the `0007` gap is explicitly
  addressed so the next reader doesn't re-litigate it).
- CHK32: Does the plan resolve the contradiction between amending ADR-0005 in
  place and ADR-0005's own statement that no such convention exists? — FAIL
  (conflicting, in the first draft: the follow-up simply prescribed an in-place
  note and left the 2026-07-15 claim standing beside it) — revised in place
  (11b requires the new bullet to carry `has since been established`, and
  criterion 6 asserts it; the original prose is preserved under a deletion
  ceiling).
- CHK33: Is "which skills it currently applies to" defined precisely enough to
  write a criterion against? — FAIL (ambiguous, in the first draft: the finding
  names two skills, but four carry the deviation and only two are drift-tracked)
  — revised in place (the verified table plus criteria 3 and 4, which require
  five rows and require the asymmetry to be visible in the row contents).
- CHK34: Is every discriminating criterion actually discriminating — does it
  measure differently before and after? — PASS (criteria 1, 3, 5, 6, 8 were all
  measured at baseline on 2026-08-07 and return `0011`/`0`/`0`/`0`/`0`;
  criterion 7 is labelled an invariant guard rather than passed off as
  discriminating, per CHK30's distinction).
- CHK35: Does any text this follow-up prescribes for insertion trip one of its
  own criteria, or one of Steps 1–10's? — PASS (R9: the three prescribed
  literals were each measured at `0` baseline and none is driven to `0` by any
  criterion in this plan; Step 5's `disable-model-invocation` → `0` assertion is
  scoped to two `SKILL.md` files, which this unit does not touch).
- CHK36: Do Step 11 and the dispatch contract agree on the file set? — PASS
  (both name exactly the same three paths, and criterion 10 asserts the set
  programmatically rather than by inspection).
- CHK37: Does the follow-up add work beyond the accepted finding? — FAIL
  (missing, in the first draft: the stale "vendors 12 skills" count was
  discovered during verification and there was no stated home for it) — revised
  in place (recorded as R10 and named on the Do-NOT-touch list explicitly, so it
  is surfaced to the operator without being smuggled into this unit's scope).
- CHK38: Is the CHANGELOG/version decision defensible from the constitution
  rather than from habit, and is it reversible if the operator disagrees? —
  PASS (Clarifications item 9 derives it from P3's version-stamped-file trigger
  and ADR-0005's own precedent; criteria 8 and 9 assert the non-trigger rather
  than assuming it; the reversal is named as a one-line criterion change).

### Open Questions

**None.** All four Partial categories resolved against verified on-disk fact or
an explicitly precedented repo convention; the one genuine judgment call
(CHANGELOG placement, Clarifications item 9) is recorded as reversible with its
reversal cost stated, not left silent.

### Scribe update hint (follow-up)

Once `245-CF1` passes review: `CONTEXT.md`'s "Skills-library remediation
completed" entry should gain a pointer to ADR-0012, and
`.claude/wiki/dependencies.md`'s `fm-noflag` sentence should cite it as the
architectural record. Neither is part of `245-CF1` — both are ordinary scribe
work after the fact.
