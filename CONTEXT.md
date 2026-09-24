# CONTEXT

Shared-language glossary for this repo. Canonical alongside `docs/adr/`;
owned by `scribe` — keep current, don't let the wiki and this
drift apart.


## Language

**ADAPT**:
the one-time per-project setup process that turns the
  plugin's generic personas/hooks/templates into a project-specific
  `.claude/` config. Split into a mechanical half (`bin/cli.js`, zero LLM
  cost in the common case) and a judgment half
  (`skills/install-antislop/SKILL.md`).

**Attested commit**:
(unit #386, 2026-08-15) — the commit recorded in a [[PASS marker]]'s
  `commit:` field (v3 format), representing the unit's own final commit — the
  exact point in history at which the unit's work, as reviewed and accepted,
  concluded. Distinct from marker-write-time HEAD, which may have moved by the
  time the marker is consulted (e.g., after a rebase or force push). The
  attested commit is what dispatch-hygiene's H3 gate tests for reachability (see
  [[Dispatch hygiene]], [[Commit attribution]], [[`.escalated` marker]], and
  [ADR-0023](docs/adr/0023-marker-commit-attribution.md)).

**characterization record**:
(unit hcb-step5-measure, 2026-09-24) — the artifact class instantiated by
  `docs/experiments/2026-09-23-probe-hook-payloads.md` and now
  `docs/experiments/2026-09-23-probe-permission-mode-ask.md`: a dated,
  **self-reported** probe record with greppable per-row verdict lines, used to make
  live/observed harness behavior machine-checkable for acceptance criteria without
  claiming the behavior is mechanically re-derivable. Distinguished from a **Microworld
  bundle** (which re-runs code and is memoized) by being a one-time measurement of live
  harness behavior under real conditions, recorded as prose/tables with self-attested
  verdicts. See **self-reported** for the evidence-label semantics.

**self-reported** (as a formal evidence label, distinct from a mechanical check):
(unit hcb-step5-measure, 2026-09-24) — a classification of evidence that explicitly
  marks a recorded artifact (e.g., a [[characterization record]]) as self-attested
  by a human operator rather than mechanically re-derived by the repo's test suite.
  Documented in `docs/trust-model.md`'s trust matrix (see row on self-report-vs-mechanical
  distinction). When a record is labelled **self-reported**, it signals that no acceptance
  criterion in the repo re-derives the recorded values — the record's verdicts are taken
  as stated, not re-verified by continuous integration. This label prevents accidental
  citation of a self-attested record as if it were mechanically checked. Exemplified by
  `docs/experiments/2026-09-23-probe-permission-mode-ask.md`'s per-row verdicts (U1, R4, C5.4),
  each marked as self-reported and dated. The counter-label is "mechanical" or "mechanically
  checked" (re-derived by test or criterion on every merge).

**permission-mode allowlist**:
(unit hcb-step5-measure, 2026-09-24) — the ordered list of `permission_mode` values
  (`default`, `plan`, `acceptEdits`, `auto`; explicitly excluding `dontAsk`,
  `bypassPermissions`, and unrecognized modes) that `harness-integrity-gate.sh`'s
  designed `ask_allowed()` branch (documented in
  `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`, unshipped as of
  this unit) checks before emitting `ask` from a hook. Distinct from [[Set A / Set B]]
  (the gate's protected *file-path* categories, keyed by path glob). The allowlist
  constrains *which permission modes* may reach an `ask` decision; Set A/B constraint
  *which paths* the gate protects. Terminology: this allowlist is not the permission
  system's own `permissions.allow` field (which overrides individual grants); it is a
  gate-internal filter on `permission_mode` values as a prerequisite to emitting `ask`.

**Bash-output census**:
(unit #477, 2026-09-23) — the re-runnable measurement tool at
  `scripts/bash-output-census.js` that recursively walks the **transcript store**
  (the nested `~/.claude/projects/<slug>/` layout), parses transcript `.jsonl` files,
  pairs `tool_use`/`tool_result` by id, filters to `Bash` calls, and reports
  count/totalChars/percentiles (using the **nearest-rank convention**) and a `caps`
  array over candidate output-truncation thresholds. Authority for re-deriving the
  output-truncation cap value used by Step 2 (issue #478). Invocable via command line
  with `--dir` flag to specify the project root (defaults to git-toplevel-derived,
  not raw cwd). See [[transcript store]], [[nearest-rank convention]].

**bashOutputMaxChars / the Bash-output cap**:
(unit #478, 2026-09-23) — a user-facing settings key (`bashOutputMaxChars: 12000`) 
  that mechanically bounds Bash tool output (the "cap") via spill-to-file: when output 
  exceeds the cap, the [[overflow file]] is persisted and the model receives a short 
  preview plus the file path instead of silent truncation, derived from the [[Bash-output 
  census]]'s percentile analysis. The locked value of 12,000 characters represents the 
  cost-governance threshold identified in Step 1. The cap is the mechanical enforcement 
  half of the cost-governance work (Steps 4-5 implement the model tier and token-budget 
  adjustments that adapt to this cap). Setup-time template value is in 
  `templates/settings-fragment.json`; for already-adapted projects, the backfill mechanism 
  in `bin/cli.js`'s `runUpdate` block additively merges `bashOutputMaxChars` into 
  `.claude/settings.json` only when the key is absent (never clobbers an existing value).
  See [[Bash-output census]] for the measurement authority, and
  [ADR-0032](docs/adr/0032-bash-output-cap-not-command-rewriting.md) for why a
  `PreToolUse`/`updatedInput` command-rewriting mechanism was rejected in
  favor of this mechanical cap.

**effort override / effort tier**:
(unit #480, 2026-09-24) — a frontmatter key (`effort:`) declared in `agents/*.md` files 
  that overrides (pins) a dispatched persona's effort level independent of the ambient 
  session effort setting. Valid values are `low`, `medium`, `high`, `xhigh`, `max`, or 
  an integer. Current assignments in this project: `explorer` declares `effort: low` 
  (mechanical traversal is cost-minimized), `task-master` declares `effort: medium` 
  (mechanical slicing against an already-finalized spec), `reviewer` declares `effort: high` 
  (adversarial judgment requires sustained engagement), and `milestone-auditor` deliberately 
  carries no `effort:` key at all (its per-persona adversarial judgment is independent of 
  the phase-scoped effort model, per 2026-09-23 user decision). Semantics: an `effort:` 
  value in a persona definition supersedes ambient session effort in both directions — 
  preventing weaker effort from a low-effort main session carrying into the persona, and 
  preventing stronger effort from a high-effort main session accidentally inflating the 
  persona's tier. This is an **override**, not a minimum/floor. Note: the term "tier" 
  carries three senses in this glossary — here it refers to effort level (low/medium/high/…), 
  distinct from [[Tier A / Tier B bundle classification]] (personas included in release 
  artifacts) and the protocol delivery tiers (full vs. slim). See `tests/effort-tier-consistency.test.js` 
  for the declared schema and mutation-proof assertions. Terminology note: earlier spec drafts
  called this an "effort floor" — a one-sided term (blocks going under, permits going over)
  that fits only the `reviewer` half-case (declared `high`, must never silently drop) and
  mischaracterizes the `explorer` half-case (declared `low`, must never silently rise, either).
  "Override" is used throughout this project instead; "effort floor" is not a separate
  glossary term and should not be reintroduced. See
  [ADR-0033](docs/adr/0033-effort-tiers-frontmatter-only-override.md) for the frontmatter-only,
  no-per-dispatch-parameter decision and the corrected raise-never-lower direction for editing
  a persona's declared value over time.

**effort floor**:
superseded terminology — see [[effort override / effort tier]].

**guarded change**:
(unit orchestrator-effort-policy-prose-fix, 2026-09-24) — an edit to a persona's 
  definition file (`agents/<persona>.md`), particularly its frontmatter fields like 
  `effort:`, `model:`, or `tools:`. This is a durable, definitional change that 
  permanently alters the persona's traits and applies to all future dispatches of 
  that persona. Contrasted with transient, per-invocation changes (e.g., per-dispatch 
  runtime flags, which do not exist for effort). Currently enforced as a **normative 
  convention only** (part of this project's discipline for persona definition edits), 
  not mechanically: `agents/*.md` files are explicitly excluded from both Set A and 
  Set B of [[Set A / Set B|harness-integrity-gate.sh]], and the project's 
  `protectedPaths` configuration is empty, so no tool-layer gate currently blocks or 
  logs persona-definition edits. This distinction (norm vs. mechanism) is load-bearing 
  for future operator decisions: a gate that does not exist today is a deliberate 
  design choice, not an oversight. See [[effort override / effort tier]] for the 
  exemplar case and [ADR-0033](docs/adr/0033-effort-tiers-frontmatter-only-override.md) 
  for the decision that effort is frontmatter-only.

**overflow file**:
(unit cost-governance-step3-protocol-prose, 2026-09-24) — the persisted file that 
  receives Bash tool output exceeding the [[bashOutputMaxChars / the Bash-output cap]] 
  limit. When the [[narrower re-query]] pattern is followed, the model receives a short 
  preview plus the overflow file's path, enabling re-query with more targeted filtering 
  rather than re-running the same command unfiltered, which would re-incur the same cost. 
  The protocol explicitly forbids reading the overflow file whole, as this defeats the 
  cost-governance purpose. Cross-linked to [[narrower re-query]].

**narrower re-query**:
(unit cost-governance-step3-protocol-prose, 2026-09-24) — the correct response pattern 
  when a Bash tool call's output overflows the [[bashOutputMaxChars / the Bash-output cap]] 
  limit and is spilled to an [[overflow file]]. Instead of reading the overflow file in 
  whole (which re-incurs the full cost), the model issues a narrower command — using 
  `head`/`tail`/`wc -l`/targeted `grep`, or the tool's own quiet/summary flag — to fetch 
  only the portion actually needed. This pattern enforces the cost-governance principle: 
  investigate the problem rather than re-running at full scale.

**baseline currency**:
(unit spec2-unitE, 2026-08-26) — the property that a fileHashes baseline's
  recorded hashes remain synchronized with the actual mirror content on disk.
  Distinct from mirror *content* drift (where semantic content changes); baseline
  currency tracks whether hashes are stale relative to content that may still be
  content-correct. The **filehashes-currency test** (`tests/filehashes-currency.test.js`)
  verifies this as a standing merge gate, catching regressions of the "stale
  fileHashes after mirror regen" bug class (occurred 3× in 2026-08). Implemented
  using `sha256Hex()` and `stripStamp()` functions exported from `bin/cli.js`.
  Known limitations (not required fixes, noted for maintenance): unguarded
  empty-fileHashes-map path would pass vacuously if ever emptied; slightly-early
  counter increment weakens "examined === keyCount" completeness assertion.

**session baseline commit**:
(unit spec2-unitB, 2026-08-26) — the git commit SHA stored in `.claude/.session-baseline.<session_id>`
  that marks the starting point for this session's changed-file enumeration. Used by
  [[microworld_skip_ok]] to compute `git diff` from that baseline to `HEAD`, in order to
  determine which files have been modified since the session began. Distinct from
  **session baselines** (see [[Sweep]]), which refers to `.claude/baseline-*.json`
  files that track fileHashes currency across different artifacts. The session baseline
  commit's core contract (unit spec2-unitB): must be reachable in the working repository's
  git history — if history is rewritten, pruned, or a baseline file is carried over from
  another clone where the commit is unreachable, the changed-file enumeration fails and
  `microworld_skip_ok` returns 1 (fail closed) rather than silently misrepresenting
  "couldn't compute" as "no changes" (see AC-B2 / [[unreachable baseline]]).

**unreachable baseline**:
(unit spec2-unitB, 2026-08-26) — the condition where a [[session baseline commit]]
  SHA cannot be verified as present in the working repository's git history (e.g. via
  `git rev-parse --verify`). This occurs when: (1) a session baseline file is copied
  from another clone or branch where the commit has since been deleted/rewritten,
  (2) the current repository's history has been force-pushed or rebased and the baseline
  commit is no longer reachable, or (3) the baseline file contains a corrupted or invalid
  SHA. When a session baseline is unreachable, `_mw_changed_files` returns 1 (failure),
  signaling to `microworld_skip_ok` that the changed-file enumeration could not be
  completed — this forces a fail-closed return (return 1) rather than granting a skip
  based on an incomplete or empty changed-file list (see AC-B5d and [[microworld_skip_ok]]).

**unmeasurable range**:
(unit version-stamp-guard-1, 2026-09-23; amended version-stamp-check-roast-1, 2026-09-23) — a git commit range for which a
  deterministic measurement cannot be derived, classified as the `unknown` verdict
  by `hooks/scripts/version-stamp-check.sh` and other reviewer-invoked measurement
  helpers (`heavy-trigger.sh`, `reviewer-tier.sh`). Causes: the range argument is
  malformed or missing, the range endpoints reference commits that do not exist in
  the working repository, a key artifact (`.claude-plugin/plugin.json`) is absent or
  unparseable at one or both range endpoints, a [[per-commit semantics]] comparison
  at one or more commits within the range fails (e.g., missing parent, divergent
  history), or the shallow clone or history limitations prevent measurement. Handlers: `version-stamp-check.sh` and similar
  measurement scripts exit 0 (fail-open) on unmeasurable ranges and output `unknown`
  (paired with placeholder dashes for derived fields), leaving the judgment to the
  reviewer. Contrast with [[unreachable baseline]], which is the analogous fail-closed
  condition for different measurement contexts.

**Persona**:
a subagent system prompt in `agents/*.md`. "Core" personas
  (orchestrator, explorer, lead-programmer) are always installed; "optional"
  personas (spec-master, task-master, scribe, reviewer, researcher,
  milestone-auditor, agent-auditor) are selected per-project during ADAPT. `spec-master`
  turns ambiguous goals into precise specs via grilling and publishes via
  `to-spec`; `task-master` reads finalized specs and writes dispatch
  instructions for `lead-programmer`, owns `to-issues` slicing outright, tags
  per-unit models. `scribe` maintains institutional knowledge (wiki, CONTEXT.md,
  ADRs). `reviewer` is the independent verifier (the Writer/Reviewer split).
  `researcher` bridges academic literature and spec authoring. `milestone-auditor`
  hunts premise gaps at milestone boundaries after all units reach PASS. `agent-auditor`
  observes agent activity (tool calls, skills invoked) via `scripts/agent-audit.sh` and
  surfaces observations; read-only and non-gating, it issues no verdict unlike `reviewer`
  and never audits the plan itself unlike `milestone-auditor`.

**Version-stamped file**:
any ADAPT-copied file carrying a
  `<!-- antislop vX.Y.Z | source: ... | ADAPT-substituted -->` comment,
  which lets `bin/cli.js --update` tell "plugin's current version" from
  "what's on disk" and detect local edits via `fileHashes` without an LLM.
  Distinct from **version-stamped path** (a synonym used in the script and
  some prose, referring to the canonical source paths `agents/*.md`, `templates/`
  that trigger a version-bump obligation under the [[version-stamp discipline]] —
  prefer the canonical term "version-stamped file" going forward).

**scaffold-only mirror**:
(unit install-antislop-floor-sweep, 2026-09-24) — a `.claude/` mirror file
  (e.g., `.claude/skills/install-antislop/SKILL.md`) that is copied from its
  source (e.g., `skills/install-antislop/SKILL.md`) ONLY at one-time ADAPT
  scaffold time by `copyDirRecursive()` in `bin/cli.js`'s `main()` function.
  Contrasts with **version-stamped file** mirrors (e.g., `agents/*.md`,
  `persona-protocol*.md`), which are regenerated on every `bin/cli.js --update`
  run. Because scaffold-only mirrors are never automatically regenerated, any
  edit to their source file must be manually hand-synced to the mirror, or the
  mirror will silently drift out of sync. Currently in this category: all files
  under `.claude/skills/` (mirrored from `skills/`). Operational implication:
  treat edits to `skills/` as requiring a dual-site commit: the source file and
  its `.claude/` mirror must be kept in sync, and parity is enforced only by
  process (code review) rather than mechanically. See also [[version-stamped
  file]], [[`--update` semantics]].

**`--update` semantics**:
`bin/cli.js --update` is the mechanism for
  refreshing ADAPT-stamped files. `--force-render` is the canonical
  force-the-loop control: it bypasses the version-match fast path and
  re-renders every managed file regardless of whether the stamped version
  already matches, writing via `copyStampedBody` and rewriting
  `persona-config.json` exactly like a plain `--update` that found drift.
  `--check` is a **deprecated alias** for `--force-render` — same
  behaviour, kept only for backward compatibility with existing callers —
  and prints a stderr warning naming itself non-read-only before any write
  happens. Neither is a dry run. The genuine no-write mode is
  **`--dry-run`** (see its own entry below); unlike either of the above, it
  is unrelated to `scripts/resync-vendored-skills.sh --check`, which is a
  different script's flag and genuinely read-only. Stamps self-heal
  automatically: a live `--update` refreshes a mirror's
  `<!-- antislop vX.Y.Z -->` stamp whenever the resolved plugin version
  differs from the stamp on disk, even when the mirror's body content is
  unchanged, retiring the prior hand-patch workaround.

**`--update --dry-run`**:
the genuine no-write investigation mode for
  `bin/cli.js --update`. It performs zero filesystem writes anywhere under
  the project root across all twelve write sites on the `--update` path
  (render-loop writes, `.gitignore` appends, `CLAUDE.md` migration, the
  legacy-persona-file deletion, `persona-config.json` rewrites, and the
  hook-registration backfill), reporting the same per-target summary a live
  run would produce but in the conditional voice (`would be created`,
  `would be updated`, …). It implies `--force-render` — without bypassing
  the version-match fast path, a dry run on an already-current project
  would report nothing and be useless. Exit codes are defined over the
  *mutation a live run would cause*, not over report vocabulary: `0` if
  and only if a live `--update` with the same arguments would leave the
  whole tree byte- and mode-identical; `3` if any write site would fire
  with an effect; `1` if one or more files could not be rendered. This is
  what closes the verification gap `--check` could not: `--check` silently
  self-heals drift and exits `0` while having written, whereas `--dry-run`'s
  exit code is a direct promise about the tree, provable with a single
  before/after snapshot.

**`--update --personas=` additive-union**:
the semantics of adding an
  optional persona to an already-adapted project via
  `bin/cli.js --update --personas=<a,b,c>`. The result is the recorded
  `personaSelection` **unioned** with the requested tokens — recorded order
  preserved, new tokens appended in declaration order — and nothing is ever
  removed: an already-selected persona named again is a no-op, not an
  error. This is deliberately the opposite of the fresh-scaffold path's
  `--personas=` semantics (`node bin/cli.js --yes --personas=...` on a new
  project), which is **replacement**: the scaffold path has no prior
  selection to preserve, so it simply sets `personaSelection` to the
  requested list. Conflating the two was the failure mode `--update`'s
  additive union exists to close — a project owner reaching for
  `--overwrite --personas=` on an existing project to add one persona would
  silently drop every other already-selected one.

**version-stamp discipline**:
(constitution P3; unit reviewer-changes-examples-lean-2, 2026-09-23) — a
  merge-gate procedural rule requiring that any edit to an `agents/*.md` or
  `templates/` file must be accompanied by a version bump (incrementing
  `version` in `.claude-plugin/plugin.json`) and a CHANGELOG entry, all in
  the *same* commit. The rule exists because `bin/cli.js --update` uses a
  version-stamp comparison for already-adapted persona files (checking the
  `<!-- antislop vX.Y.Z | ... -->` comment in each file) to determine whether
  a refresh is needed — it never performs a content diff for version-stamped
  files (`bin/cli.js:1357`). Therefore, a content-only edit with no version
  bump causes the stamp to remain unchanged, and downstream projects running
  `--update` will silently skip the refresh, never receiving the code change.
  This is a silent data-loss failure mode, hence the discipline: version is
  the only signal `--update` observes for already-adapted files. Mechanized by
  `hooks/scripts/version-stamp-check.sh`, a reviewer-invoked helper (not
  hook-registered, following the pattern of `heavy-trigger.sh` and
  `reviewer-tier.sh`) that reads an explicit `<commit-range>` argument and
  classifies outcomes as `ok`, `violation`, or [[`unknown`|unmeasurable range]],
  exiting 0 always (fail-open). Sidesteps CI's shallow-clone limitations that
  made a `HEAD~1`-based check unreliable. Mechanization covers the version-bump
  half of the discipline only; the CHANGELOG-entry half remains reviewer-inspection-only.
  (unit version-stamp-check-roast-1, 2026-09-23) Widening the reviewed range past
  an offending commit no longer masks it: the script additionally checks every
  commit *within* the range that itself touches a version-stamped path against
  its own immediate parent, reporting `violation` if any one of them individually
  lacks a bump — even when the range's overall endpoints show a bump happened
  somewhere in between (e.g. a later, unrelated commit). The endpoint `old`/`new`
  fields in the output remain informational only. See row 25 of `docs/trust-model.md`.

**per-commit semantics**:
(unit version-stamp-check-roast-1, 2026-09-23) — a measurement discipline where a
  property or invariant is checked against each individual commit within a range
  against its own immediate parent, rather than comparing only the range's two
  endpoints. Applied to the [[version-stamp discipline]]: instead of checking whether
  `.claude-plugin/plugin.json`'s version differs between the range's start and end,
  the script checks *every* commit within the range that touches a version-stamped
  path against that commit's immediate parent. This catches violations that endpoint-only
  comparison could mask (e.g., an earlier commit lacks a version bump, but a later
  unrelated commit bumps the version, hiding the violation). Per-commit semantics
  enables `version-stamp-check.sh` to report a `violation` even when the overall range
  endpoints show a bump happened somewhere in between, provided any one individual
  commit within the range individually lacks a bump compared to its parent.

**Substitution**:
a placeholder in a shipped persona file (e.g.
  `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>`) resolved to a real
  value at ADAPT time and recorded in `.claude/persona-config.json`'s
  `substitutions` field.

**`{{DOTDIR}}` placeholder token**:
(unit #408, 2026-08-25) — a parameterization token in the [[Operational ignore list]]
  and other canonicalized patterns, substituted at render time to target a
  specific dot-dir (`.claude`, `.cursor`, `.codex`). Allows a single canonical
  array of operational patterns to serve all three adapters without
  hand-maintaining separate copies per target. Rendered via
  `renderIgnorePatterns()` in `bin/cli.js` for each scaffold and the `--update`
  backfill step. Example: `'{{DOTDIR}}/reviewed/'` renders to
  `.claude/reviewed/`, `.cursor/reviewed/`, or `.codex/reviewed/` depending on
  target.

**The Writer/Reviewer split**:
the system's core safety property: the
  `lead-programmer` writes code, but only the independent `reviewer`
  (which did not write the code) can mark a unit done (`.claude/reviewed/*.pass`).
  Enforced mechanically by `stop-gate.sh` and `reviewer-route-gate.sh`, not
  just by persona instruction.

**Gate**:
a hook script that mechanically blocks an action rather than
  relying on a persona to comply (e.g. `stop-gate.sh`, `protected-paths.sh`,
  `reviewed-path-gate.sh`). Config-driven via `.claude/persona-config.json`.
_Avoid_: marker-directory gate

**Set A / Set B** (harness-integrity-gate sets):
(unit harness-integrity-gate-hardening, 2026-09-09) — the two disjoint
  categories of protected file paths in `hooks/scripts/harness-integrity-gate.sh`.
  **Set A** (denied on both Write/Edit and Bash): the harness's own config and
  audit-log surfaces (`.claude/persona-config.json`, `.claude/review-audit.log`,
  `.claude/dispatch-audit.log`, `.claude/microworld-audit.log`,
  `.claude/wip-audit.log`, and their `.seal` sidecars). **Set B** (denied on
  Write/Edit only, deliberately absent from Bash): the gate's own registration
  surface (`hooks/hooks.json`, `.claude/settings.json`,
  `hooks/scripts/harness-integrity-gate.sh`). Set B is excluded from the Bash
  branch by [ADR-0025](docs/adr/0025-textual-gate-protection-requires-structural-triggers.md)
  because a text-only gate triggered by mere word presence in Bash commands would
  necessarily fire on prose mentions, not just write attempts — the asymmetry is
  ratified, not an oversight. Introduced together as a pair, not independently.

**git-index witness** (synonymous with **directory witness**):
(unit gh441, 2026-09-10) — a detection mechanism in `harness_armed()` that
  identifies when a project's configuration file (`.claude/persona-config.json`
  or equivalent per dot-dir) is missing from the working tree but still tracked
  in git (e.g., after `rm -rf .claude`, `git clean -fdx`, or `mv .claude .claude.bak`).
  One of two independently-sufficient routes that lead to a "tampered" verdict
  (verdict 2). The other route is: presence of **adaptation witnesses**
  (agents/*.md files and either hooks/scripts/ or reviewed/ directories) combined
  with config absent/empty/unparseable. Note: the terms "adaptation witnesses"
  and "directory witness" are synonyms—both refer to the directory artifacts
  checked by `harness_armed()` before invoking the git-index check; the code
  comment at `hooks/scripts/lib/harness-arm.sh:8-19` uses both names across four
  lines, an inconsistency noted for future cleanup but non-blocking. `harness_armed()`
  returns: 0 (armed — config present and parseable), 1 (unadapted — no witnesses
  found), 2 (tampered — adaptation witnesses found but config missing/bad, OR
  git-index witness alone). See [ADR-0015](docs/adr/0015-commit-anchored-pass-markers.md).

**bypass family**:
(unit harness-integrity-gate-hardening, 2026-09-09) — a class of obfuscation
  techniques that could evade a textual-protection gate by disguising the true
  form of a protected path. Examples: brace expansion (`{a,b}`), backslash escape
  (`\*`), glob patterns (`*.json`), absolute/prefixed paths (`/abs/path/.claude/…`
  or `$VAR/.claude/…`), variable indirection (`F=.claude/x; git add $F`), and
  working-directory manipulation (`cd .claude; rm -f x`). A **family** is an
  enumerated set of related spellings that share a common obfuscation principle.
  Each family is either *closed* (all reachable instances blocked), *residual*
  (deliberately left out of scope, documented as known limitation), or
  *over-blocking* (blocked although unreachable in this project). See [[family table]],
  [[documented residual]], [[accepted over-block]].

**family table**:
(unit harness-integrity-gate-hardening, 2026-09-09) — a frozen, machine-checked
  enumeration of **bypass family** closure status (closed, residual, or over-block)
  serving as the security gate's formal guarantee, replacing unbounded universal
  claims ("detects everything") that were disproven by counterexamples. A **family table**
  is specific to a particular gate and a particular unit; it names each family slug,
  supplies a representative spelling that exhibits the obfuscation technique, and
  documents why (if applicable) the family sits outside the gate's scope. The table's
  slug tokens serve as shared identifiers between the gate's test suite (e.g.,
  `tests/harness-integrity-gate.test.sh:187-194`) and its documentation (e.g.,
  lead-programmer memory note `project_harness_integrity_gate_persona_config_commit.md:74-96`),
  enabling machine-checked parity in both directions. Introduced by the principle
  that a security gate cannot claim to prevent "everything" — instead it must
  enumerate exactly which **bypass families** it does block, which it leaves residual,
  and which it over-blocks. See [ADR-0025](docs/adr/0025-textual-gate-protection-requires-structural-triggers.md).

**documented residual**:
(unit harness-integrity-gate-hardening, 2026-09-09) — a known, deliberate, and
  recorded **bypass family** that lies outside the scope of a particular security-gate
  hardening unit, left as an accepted limitation rather than closed. Sits in the
  **family table** as a row with slug, representative spelling, and a written
  explanation of why the family sits out of scope (e.g., "requires modeling
  working-directory state, a different axis from glob detection"). Distinguished
  from a *false negative* (missed bypass) by being explicitly named in the table
  and documented as intentional. Example: `wd-relative` in harness-integrity-gate's
  family table (working-directory manipulation spellings like `cd .claude; rm -f x`)
  is documented as residual because a text-scanning hook would require shell-state
  modeling to close it, deferred to a follow-up spec. A documented residual is
  *expected to pass* (ALLOWED verdicts) in the test suite, not treated as a test
  failure. See [[accepted over-block]], [[bypass family]], [[family table]].

**accepted over-block**:
(unit harness-integrity-gate-hardening, 2026-09-09) — a **bypass family** that a
  security gate blocks (returns BLOCKED verdict) even though the spellings in that
  family cannot reach the protected file(s) in this specific project, hence the gate
  is "over-blocking" in practice. Distinguished from a *false positive* (a legitimate
  write incorrectly denied) by being intentional, documented in the **family table**,
  and test-verified to actually reach the gate's trigger (the gate genuinely blocks
  it). Justification: the gate's logic is simpler, more general, or more robust if
  it treats the family identically to reachable bypasses, even though this project's
  specific directory structure makes it unreachable. Example: `foreign-claude-dir`
  in harness-integrity-gate's family table (`rm -rf ~/.claude/*`, `rm -rf /tmp/x/.claude/*`)
  is blocked because it names a `.claude`-containing path, though this project's
  Set A is confined to the repo's own `.claude/` directory, not `~/.claude/`. See
  [[documented residual]], [[bypass family]], [[family table]].

**Reporter**:
(unit #132, 2026-08-10) — a hook script that observes and logs an
  action without blocking it; the formal antonym of **Gate**. Unlike a gate,
  which refuses an action, a reporter permits it and records metadata in an
  audit trail. Example: `microworld-rerun.sh` is a reporter that enqueues
  microworld bundles and watch-map entries for **deferred result surfacing** via
  an async **drain loop** (unit A, 2026-08-25), logging to `.claude/microworld-audit.log`.
  It returns immediately (exit 0 on success, 2 on infrastructure failures like missing
  `run.sh` or timeout parsing errors) without waiting for the actual bundle run,
  which executes asynchronously via the **drain loop**. Results are surfaced in
  the **same session** by `stop-gate.sh`'s deferred-result reader (primary channel)
  or `session-start.sh`'s backstop reader (for results from prior sessions). See
  [[deferred result surfacing]], [[drain loop]], [[results-reported cursor]].
  The reporter/gate distinction is a formal semantic pairing; never conflate them.

**grant-denied**:
an append-only audit-log record class written to
  `.claude/review-audit.log` by `reviewed-path-gate.sh` and `stop-gate.sh`
  (both main hooks and both adapter ports) whenever a privilege is denied to
  a non-reviewer **Agent identity**. Unlike a **Gate** (which blocks an
  action), `grant-denied` is a side-effect log line that makes a previously
  invisible privilege denial visible in the audit trail — the gate still
  fires, but the denial is now recorded. Completes Finding R3 from the
  orchestration-dispatch-identity-defects spec (unit #307).

**watch-map** / **watch-map entry**:
(introduced mw-step1, unit #313) — the committed reactive-check source at
  `tests/watch-map.json`, defining a second namespace of checks alongside
  **microworld bundles**. Each entry carries an `.id` (the entry id, distinct
  namespace from bundle slugs), a `.watch[]` array of glob patterns that
  trigger re-runs, `.location` and `.startLine`/`.endLine` for source
  verification, and `inputs`/`expected`/output contract paths. Watch-map
  entries are classified as **Tier A** checks; **microworld bundles** are
  **Tier B** (see those entries). The audit log's `unit=` field now carries
  both bundle slugs and watch-map entry ids; see [[Microworld audit log]].

**Tier A / Tier B bundle classification**:
(introduced mw-step1, unit #313) — a pair of mechanisms for microworld
  checks. **Tier A** = committed watch-map-driven checks (defined in
  `tests/watch-map.json`, sourced via `git ls-files`, one fixed watch-set
  per entry id). **Tier B** = the pre-existing gitignored
  `microworlds/<bundle-slug>/` bundles (dynamically discovered from disk,
  varying per working tree, carry the microworld dashboard UI). Both are
  monitored by the microworld reporter hook; the audit log records both
  in the same append-only format. Tier A enables committed, versioned
  reactive checks; Tier B enables explorer-driven escalations. See
  [[watch-map]] and [[Microworld bundles]].

**Microworld audit log**:
(unit #132, 2026-08-10) — an append-only log file at
  `.claude/microworld-audit.log` (+ per-adapter equivalents
  `.cursor/microworld-audit.log`, `.codex/microworld-audit.log`) recording
  execution results of **microworld bundle** invocations and **watch-map**
  entries. Populated asynchronously by the **drain loop** (not synchronously
  on `PostToolUse`; see [[deferred result surfacing]], unit A, 2026-08-25).
  The `microworld-rerun.sh` **Reporter** hook enqueues bundles via `PostToolUse`
  (exit 0 on success, 2 on infrastructure failures), then the drain loop writes
  results lines as it processes the async queue. Line format: `<ts> unit=<slug|entry-id> result=pass|fail|timeout file=<path>`
  for real runs, and `<ts> unit=<slug|entry-id> result=error ... file=<path> reason=<...>`
  for infrastructure failures (malformed manifest, missing `run.sh`, absent `jq`, etc.).
  The `unit=` field carries both bundle slugs (**Tier B**) and watch-map entry ids
  (**Tier A**). Failures are surfaced to the model by `stop-gate.sh` (primary) or
  `session-start.sh` (backstop) via the **results-reported cursor**, never blocking
  edits. Complements `.claude/review-audit.log` and `.claude/wip-audit.log` as a
  fourth sibling log class. See [[Consumed interface]].

**Commit attribution**:
(unit #386, 2026-08-15) — the mechanism of recording which commit a unit was
  completed at, captured in a [[PASS marker]]'s `commit:` field (v3 format).
  The field's semantic meaning (see [[Attested commit]]) is the unit's own
  final commit, not the state of HEAD at marker-write time. This attribution
  enables dispatch-hygiene's H3 gate to detect work lost to history (unreachable
  commits allow re-dispatch; reachable commits remain protected). On
  escalation approval, the field is copied verbatim from the standing
  [[`.escalated` marker]] rather than re-derived. See
  [ADR-0023](docs/adr/0023-marker-commit-attribution.md) for the semantic
  clarification and [ADR-0015](docs/adr/0015-commit-anchored-pass-markers.md)
  for the technical mechanism.

**compatibility floor**:
(unit cache-ttl-gapped-personas, 2026-09-23) — the minimum Claude Code version
  required by this plugin or project, stated in `.claude-plugin/plugin.json`'s
  `description` field and `README.md`'s Requirements section (e.g.,
  `>=2.1.248`). Raising the floor is a real compatibility decision, not merely
  documentation, because a user running an older version will receive features
  or configuration options that are silently dropped if the harness version is
  below the floor. Frontmatter fields like `experimental.cacheTtl` depend on
  specific platform versions — if the floor is not updated to match, users in
  the gap range (e.g., 2.1.178–2.1.247) will pass setup checks but silently
  miss the feature. The floor value is checked at ADAPT time by
  `skills/install-antislop/SKILL.md` and enforced as a plugin-level constant.

**Consumed interface**:
(unit #316, 2026-08-10) — a formal label for a wire contract or data format
  that is explicitly documented as being read/parsed by a downstream system.
  Example: the microworld audit-log line format (emitted by `microworld-rerun.sh`)
  is a consumed interface because `bin/microworld-dashboard/audit-log.js` is a dedicated
  parser on the other side of that contract. Naming a format as "consumed"
  surfaces the bidirectional coupling: changes to the emitter require coordinated
  changes to the parser, and the test contract test (`tests/microworld/microworld-audit-contract.test.js`)
  exercises both sides to prevent drift. This term appears in protocol prose
  (e.g., `hooks/scripts/microworld-rerun.sh:10`) when a hook's header documents
  its output as a consumed interface, clarifying that the format is not arbitrary.

**marker-commit-check**:
(unit #385, 2026-08-15) — the executable script at `hooks/scripts/marker-commit-check.sh`
  (mode 755) that reads a [[PASS marker]]'s `commit:` field and classifies it as one of
  three [[Marker classifier states]]. Output: exactly one line per marker; always exits 0
  (fail-open interface). Proven via 10 pinned test cases in `tests/marker-commit-check.test.sh`
  (mutation-verified). Not yet wired to a consumer gate (Step 7, gh385-7, handles that
  integration). Sibling gate-adjacent tooling: [[Dispatch hygiene]], **stop-gate.sh**,
  **DECISION channel**.

**Marker classifier states**:
(unit #385, 2026-08-15) — the three-state classification result from `marker-commit-check.sh`
  when verifying a [[PASS marker]]'s `commit:` field against git history. Defined values:
  `ok` (commit is reachable and valid in unit-id context), `mismatch` (commit is reachable
  but fails unit-id context validation), `unverifiable` (commit cannot be verified — missing
  from git, malformed format, or context ambiguous). Key semantic: `unverifiable` is
  **fail-open** ("not proven wrong", safe to proceed) rather than fail-closed. Step 7
  consumes these states as trigger conditions for audit logging to `.claude/review-audit.log`.
_Avoid_: classifier result (use specific state names or "Marker classifier states")

**Marker audit-log states**:
(unit #385, 2026-08-15) — the set of possible state values written to `.claude/review-audit.log`
  when `marker-commit-check.sh` is consulted. Superset of [[Marker classifier states]];
  includes three states from the classifier (`ok`, `mismatch`, `unverifiable`) plus a
  fourth caller-side state: `unavailable` (the classifier could not be consulted — missing
  script, execution failure, or preconditions unmet). Key distinction: `unavailable` means
  "could not even run the classifier" (a system state), while `unverifiable` means "the
  classifier ran but couldn't decide" (a classification result). Audit-log records emitted
  by `stop-gate.sh` when running in `warn` or `block` mode per [[markerCommitCheck.mode]].

**markerCommitCheck.mode**:
(unit #385, 2026-08-15) — configuration key in `.claude/persona-config.json` (schema:
  `templates/persona-config.schema.json`, paths: `dispatchHygiene` sibling) controlling
  `stop-gate.sh`'s behavior when `marker-commit-check.sh` runs. Defined modes: `off`
  (no audit line written, classifier not invoked), `warn` (audit line written, classifier
  runs but does not block), `block` (audit line written, classifier runs and blocks when
  the verdict cites a commit that does not appear to belong to the unit). Parallel to
  [[Dispatch hygiene]]'s `dispatchHygiene.mode` posture. Consumed by the marker-commit-check
  classification block at `stop-gate-core.sh:401-424` (in the SubagentStop block) after
  satisfied stamps are identified in the review-join validation loop.

**Removed rather than inspected**:
(unit #272, 2026-08-08, three-instance
  pattern named) — a standing principle for `reviewed-path-gate.sh`'s
  program-allowlist design: any external program whose write/mutation surface
  cannot be fully characterized by text-based scanning of its command-line
  arguments (due to implicit default behaviors, sub-protocols carrying mutations
  outside the route name, environment-dependent effects, or runtime token
  expansion) is removed from the allowlist entirely rather than partially
  inspected with a flag-scan or allowlist of sub-commands. Three instances now
  embody this rule: `git` (implicit remotes/detach), `rg` (implicit cwd-relative
  effects on certain flags), and `gh api` (default GET→POST, GraphQL mutations
  in the body, token-substitution). A text-based gate that misses any of these
  forms creates a false sense of security without actually bounding the surface;
  removal is the sound choice. See `docs/plans/2026-08-07-gate-audit-t34-vacuity-and-gh-inventory.md`
  for specifics per program (not repeated here to avoid exploit-adjacent detail).

**Dispatch hygiene**:
the **Gate** applied at the `PreToolUse`/`Agent`
  seam by `hooks/scripts/dispatch-hygiene.sh`: it checks a dispatch prompt
  *before* the spawn happens, rather than a turn's output at its end like
  `stop-gate.sh` does. Four checks: H1 an oversize prompt, H2 an inlined
  artifact as a large fenced code block, H3 re-dispatch of a unit (gated
  **Persona**s only, default `lead-programmer`) whose `Unit:` line names an id
  that already holds a `.claude/reviewed/<id>.pass` marker, and H4 a gated
  dispatch missing any of the nine dispatch-contract elements (the `Unit:
  <id>` first line plus eight `## `-headings `agents/task-master.md` defines)
  — checked by presence only, not content. Configured via
  `persona-config.json`'s `dispatchHygiene` (default mode `block`; this
  repo's own config runs `warn` as part of its [[solo-operator posture]] —
  violations are logged, not blocked); single-use
  escape hatch `.claude/.dispatch-override`. H3 is anchored by a `commit:`
  field in the PASS marker (v3 format, see [ADR-0015](docs/adr/0015-commit-anchored-pass-markers.md)) that
  records the unit's own final commit (see [[Commit attribution]]): a marker from an
  unreachable commit is treated as void, allowing re-dispatch of units whose
  work was lost to history. H3 is only as good as the reviewer's marker id
  matching the dispatch's `Unit:` line, and issue #153 originally flagged
  that discipline as unreliable; the specific gap #153 named — a reviewer
  clearing pending-review flags with no marker written at all — is now
  mechanically closed by the review-join stamp mechanism
  ([ADR-0016](docs/adr/0016-per-unit-review-join.md), `hooks/scripts/stop-gate.sh`),
  which blocks a reviewer's flag-clear when no verdict marker is found for that
  unit (`marker=MISSING`, `hooks/scripts/stop-gate.sh`). That does not itself
  prove every written marker's id matches the unit being dispatched, so H3 is still
  best-effort rather than provably airtight — but the silent no-marker-at-all
  failure mode #153 documented is now closed, not merely aspirational.

**description collision**:
(unit gwd-2, 2026-09-11, [ADR-0031](docs/adr/0031-grill-with-docs-model-invocable.md)) —
  the condition where two or more [[Preloaded skill]]s with near-identical descriptions
  are both model-invocable, creating ambiguity: a user request like "grill me" might invoke
  either `grill-me` ("A relentless interview to sharpen a plan or design.") or `grill-with-docs`
  ("A relentless interview to sharpen a plan or design, which also creates docs (ADR's and
  glossary) as we go.") depending on the harness's selection order. The descriptions cannot
  be edited to disambiguate because both are **drift-tracked skills** — their descriptions
  are reconstructed byte-for-byte from upstream by the `fm-noflag` declared-deviation type,
  and editing the descriptions would break the [[`fm-noflag` declared-deviation class]] check.
  The only available mitigation is explicit prose naming of the intended skill in the persona
  or dispatch context (e.g., in `agents/spec-master.md`'s instructions to use `grill-with-docs`
  rather than bare "grilling"), since descriptions themselves cannot be used as a
  disambiguation surface.

**`grill-with-docs` skill**:
(unit gwd-1, 2026-09-11) — a vendored mattpocock skill whose entire body
  delegates to `grilling` plus `domain-modeling` (`Run a /grilling session,
  using the /domain-modeling skill.`). Preloaded by `spec-master` as its
  interrogation entry point (unit gwd-4), pivoting the "Grill before
  planning" step off bare `grilling` so interrogation produces `CONTEXT.md`
  glossary entries (written directly by `spec-master`) and drafts ADRs into
  the plan document (with numbering and landing left to `scribe`, whose custody
  of `docs/adr/` is unchanged). Model-invocable because the
  [[`disable-model-invocation` flag]] is stripped under the `fm-noflag`
  declared-deviation class, alongside `grill-me`. Recorded in
  [ADR-0031](docs/adr/0031-grill-with-docs-model-invocable.md). See also
  [[Preloaded skill]] and **description collision**.

**Adapter behavioural parity**:
(issue #202, 2026-08-01 efficiency pass 2,
  Step 4, refreshed unit #411) — a merge-gate check that verifies the
  adapter ports' **thin entry scripts** correctly translate their native
  payloads into the shared **core file**'s contract, and that the core's
  decision logic is genuinely shared (byte-identical) across all three ports.
  `tests/adapter-stop-gate-parity.test.sh` verifies two things: (1) each
  **thin entry script** correctly populates all variables the core expects
  (payload-shape translation, input wiring), proven by running the full
  review-join scenario suite once on Claude and a two-case wiring smoke test
  on both adapter ports; (2) codex-only mutation controls prove the core's
  logic is actually exercised, not bypassed. Complement: **byte-parity**
  (`tests/validate.sh`'s check that declared-shared files are byte-identical
  across ports) proves the core files themselves match exactly. Do not
  conflate with the third parity mechanism: **document/section-presence
  parity** (`tests/adapter-protocol-parity.test.js`, which checks that
  canonical protocol *sections* are accounted for in the Codex/Cursor doc
  ports — presence, not runtime behaviour). See [[thin entry script]],
  [[core file]], [[payload-shape translation]], [[declared-shared set]],
  [modules/adapters.md](.claude/wiki/modules/adapters.md) and
  [modules/hooks.md](.claude/wiki/modules/hooks.md).

**core file**:
(unit #411, 2026-08-25) — a reusable, port-invariant logic module at
  `hooks/scripts/lib/<name>-core.sh` (e.g. `stop-gate-core.sh`,
  `reviewer-route-gate-core.sh`) containing decision logic that is sourced
  (never executed directly) by per-port **thin entry scripts**. The core
  file is byte-identical across all three ports (Claude, Codex, Cursor),
  enforced by **byte-parity** tests. It defines a contract of input
  variables (set by the caller before sourcing) and, for scripts that need
  differing control-flow per port, caller-defined functions like
  `block()`/`allow()` that the core invokes at decision points. Introduced
  in unit #410 for `graph-update` and extended in unit #411 to `stop-gate`
  and `reviewer-route-gate`. See [[thin entry script]] and [[Adapter
  behavioural parity]].

**declared-shared set**:
(unit #411, 2026-08-25) — the list of files in `hooks/scripts/lib/` that
  are mirrored byte-for-byte to both adapter ports (Codex and Cursor), as
  declared in `bin/cli.js`'s `SHARED_HOOK_LIB_FILES` array. These files
  include all **core files** plus `agent-identity.sh`, which derives
  behaviour from its on-disk location rather than per-port input. Files in
  `CLAUDE_ONLY_HOOK_LIB_FILES` (e.g. `benign-command.sh`) are NOT in the
  declared-shared set and exist only in Claude's tree. The `--update`
  mechanism enforces the declaration: any new file in `hooks/scripts/lib/`
  that is not classified into one of the two lists causes an error.

**payload-shape translation**:
(unit #411, 2026-08-25) — the per-port work a **thin entry script** must
  perform to convert its native hook payload into the normalized form
  expected by the **core file**'s contract. Examples: Codex provides
  `.agent_id`, Cursor provides `.subagent_type`, Claude provides
  `.agent_type` — each **thin entry script** normalizes its native field
  into the shared variable name the core expects. Cursor's hook events come
  as lowercase/camelCase (`"stop"`, `"subagentStop"`), while the core
  expects Pascal case (`"Stop"`, `"SubagentStop"`) — translation happens in
  the **thin entry script** before sourcing. Payload-shape translation is
  proven by **adapter behavioural parity** tests to happen correctly for
  each port.

**thin entry script**:
(unit #411, 2026-08-25) — a per-port hook wrapper at
  `adapters/{codex,cursor}/hooks/scripts/<name>.sh` (or the Claude main at
  `hooks/scripts/<name>.sh`) that is responsible for payload translation and
  sourcing the shared **core file**. Called "thin" because it contains no
  decision logic of its own — all branching lives in the core. The **thin
  entry script** is the only per-port variant; the **core file** it sources
  is byte-identical across all three ports. Replaces the term "shim" for
  clarity. See [[core file]], [[payload-shape translation]], and [[Adapter
  behavioural parity]].

**agent-memory write**:
(unit #288, 2026-08-11) — a `Write` or `Edit` tool_use whose `file_path`
  targets the agent-memory directory tree: `.claude/agent-memory/` or
  `.claude/projects/*/memory/`. Distinct from general filesystem writes;
  specifically observes memories saved by agents during their work. Recorded
  by `scripts/agent-audit.sh`'s A8 section (Agent-memory writes) as an
  informational audit event (never gating, never a finding). See [[gh-304
  dual-marker incident]] for the concurrency defect that motivated tracking
  memory writes (concurrent writes to `.claude/agent-memory/` can dirty the
  git tree and fail marker preconditions).

**clear-watermark**:
**[Retired in 0.28.0; see review-join stamp below.]**
  Historically, `.claude/.last-review-clear` was a zero-byte file whose mtime
  marked when the reviewer's flag-clear path (via `stop-gate.sh`'s SubagentStop
  grant branch) last succeeded, used as the reference point for detecting whether
  a marker had been written since the previous review. It coupled the reviewer's
  flag-clear to a marker-write requirement via `marker_since_last_clear`, which
  returned 2 on bootstrap (no watermark), 0 when a PASS or FAIL marker was newer
  than the watermark, and 1 otherwise. The mechanism was defer-immune by design
  (immune to the dispatch-time `defer:` convention). In 0.28.0, it was replaced
  by the **review-join stamp** (see below, and [ADR-0016](docs/adr/0016-per-unit-review-join.md))
  to close concurrency defects and unify marker validation. The old file becomes
  inert once nothing reads it and requires no migration.

**review-join stamp**:
(0.28.0+) `.claude/.review-join.<unit-id>`, one per
  unit currently under review. Written unconditionally by `reviewer-route-gate.sh`
  for any non-advisory reviewer dispatch carrying a well-formed `Unit:` line, and
  consumed at `stop-gate-core.sh:425` (in the SubagentStop block) when that unit's
  verdict marker is found. The `review_join_state()` function (stop-gate-core.sh:239-330)
  only deletes malformed and advisory stamps; satisfied stamps are consumed separately
  at line 425. When a valid PASS marker already exists, the stamp records `prior=pass`
  and `prior_mtime=<marker-mtime>` for concurrency detection; this ensures a
  re-dispatched reviewer must write a newer verdict or be blocked at `SubagentStop`.
  Replaces the global clear-watermark; enables per-unit verdict coupling without
  cross-dispatch interference. See [ADR-0016](docs/adr/0016-per-unit-review-join.md)
  for design and [modules/hooks.md](.claude/wiki/modules/hooks.md) for implementation.

**advisory review-join stamp** (M2, Step 3): a variant `.claude/.review-join.<unit-id>.advisory`
  written by the route gate when a `Mode: advisory` dispatch is made (no ordinary PASS).
  First line carries `unit=<id> mode=advisory`. Distinct filename prevents overwriting
  a real stamp for the same unit while matching the `.review-join.*` glob. Advisory
  stamps count toward `JOIN_STAMP_COUNT` and enter the [[scoped unit set]], but are
  never counted as "satisfied" for pending-review flag clearing (M3).
_Avoid_: clear-watermark

**scoped unit set** / **marker relevance scoping**:
(ADR-0028, gh425-3) — the set of unit ids that a stopping reviewer is
  responsible for, derived from that reviewer's own [[review-join stamp]]
  files at stop time. Used to determine which `.blocked` / `.escalated` markers
  are relevant to this reviewer's flag-clear operation. When the scoped unit set
  is non-empty, only markers for units in that set can hold pending-review flags;
  markers for units outside the set are logged as `marker-out-of-scope` instead
  of silently blocking. When the scoped unit set is empty (no stamps exist or
  all stamps are malformed), the marker check falls back to the directory-wide
  glob to preserve the original safety semantics for reviewers dispatched without
  a `Unit:` line. Introduced to close the gap identified in
  [ADR-0028](docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md) where
  a stray `.blocked` marker for an unrelated unit could jam unrelated reviewers'
  operations.

**marker-out-of-scope** (audit log token):
(ADR-0028, gh425-3) — an audit-log entry emitted by `stop-gate.sh` when a
  `.blocked` or `.escalated` marker exists but is not relevant to the stopping
  reviewer's [[scoped unit set]]. Format in `.claude/review-audit.log`:
  `marker-out-of-scope=<unit>` (one line per out-of-scope marker). Introduced
  to make marker-based flag-clearing jams diagnosable from the audit log rather
  than requiring inspection of `.claude/reviewed/` directory contents. Complements
  the `marker=MISSING unit=<U>` token for unsatisfied stamps.

**non-blocking note**:
(issue #295, gh295-1/1b/2/3) — a tagged, optional message attached to a
  [[PASS marker]] by the reviewer, signaling a minor finding that does not prevent
  approval. Each note carries one of two tags: `NOTE[spec]:` (a divergence between
  code and documentation, undocumented load-bearing behaviour, or a warning about
  a step not yet dispatched) or `NOTE[code]:` (everything else — style nits,
  minor risks, or observations). Notes are written by the reviewer under a required
  section anchor `Non-blocking notes:` (exact match, at column 0 if present), with
  each note's tag prefixing its own line. The deterministic read side is a two-part
  sweep: `bash hooks/scripts/marker-verify.sh --notes <unit-id>` (per-unit enumeration)
  and `bash bin/marker-audit.sh . --notes [--tag=all|spec|code] [--surface=S ...]`
  (aggregate across all markers), both advisory only (always exit 0, never execute
  a marker's criteria, never block). The `.claude/reviewed/` directory storing markers
  is gitignored (`.gitignore:12`), so the sweep is best-effort and never proof of
  "swept, therefore clean" — an empty sweep may mean no note was written or may mean
  the clone never held it. Tag classification tolerates markdown emphasis (`*`, `_`,
  `` ` ``) and list-marker prefixes (`-`, `*`, `N.`, `N)`) on the tag line itself.
  `spec-master` is obligated to run `marker-audit.sh . --notes --surface=<path>` before
  writing any follow-up spec; found `NOTE[spec]:` and `untagged` lines naming undispatchable
  steps are required inputs. See [[state-artifact species]] for the `.pass` marker's
  role in the state model; this channel is the scoped variant for spec/code divergence
  routing.

**state-artifact species**:
(unit gh413, 2026-08-31) — an individual marker type, flag file, log, or
  other filesystem artifact that encodes persistent state in the harness.
  Examples: `.pass` markers, `.pending-review.<agent-id>` flags,
  `wip-handoff.<agent-id>` handoff files, `.session-baseline.<session-id>`
  baseline commits, `.dispatch-override` escape hatches, the sealed audit logs
  (review-audit.log, wip-audit.log, microworld-audit.log, dispatch-audit.log),
  and the human-review packet. Prior to unit gh413, these species were
  individually manipulated throughout 12+ hook scripts; gh413 consolidated
  them into a unified access layer organized by **5 key domains**. Note: the
  **Rulings ledger** is a fifth advisory log, distinct from this sealed family
  (see [[Rulings ledger]]).
_Avoid_: state object, artifact type, marker type (be specific about what
  you're referring to; "state-artifact species" names the general taxonomy)

**5 key domains** (or **Five key domains**):
(unit gh413, 2026-08-31) — the organizational model into which all
  **state-artifact species** are consolidated by their access pattern and
  keying scheme. Each domain serves a distinct role in the harness. **Unit
  domain** (keyed by unit id): markers (`.pass`, `.fail`, `.blocked`,
  `.escalated`, `.directed`), review-join stamps (`.review-join.<unit-id>`),
  human-review packets (`.claude/human-review/<id>/` directory), and DECISION
  files. Per-unit keying preserves ADR-0016's invariant that each review
  cycle is isolated from concurrent siblings. **Agent domain** (keyed by agent
  id): pending-review flags (`.pending-review.<agent-id>`, created on dispatch,
  cleared by reviewer's SubagentStop) and WIP handoff files
  (`wip-handoff.<agent-id>`, consumed-on-read semantics). **Session domain**
  (keyed by session id): session baseline commits (`.session-baseline.<session-id>`,
  create-only-if-absent, used for changed-file enumeration). **One-shot domain**
  (unkeyed/global): dispatch override (`.dispatch-override` single-use escape
  hatch) and its consumed marker (`.dispatch-override.consumed`, with
  content-embedded epoch and dispatch hash for lifecycle management).
  **Log domain** (unkeyed, append-only): the sealed audit logs
  (review-audit.log, wip-audit.log, microworld-audit.log, dispatch-audit.log),
  each with a `.seal` sidecar for integrity verification. The orchestrator's
  **Rulings ledger** (`.claude/orchestrator-rulings.log`) is a fifth log in the
  Log domain, explicitly unhooked and advisory-only, distinct from the sealed
  audit-log family (see [[Rulings ledger]]). Access across all domains is
  provided by the [[state-access seam]]; glob/enumeration operations (listing
  all pending reviews, sweeping old baselines, etc.) remain in calling scripts,
  not in the seam itself. See [ADR-0016](docs/adr/0016-per-unit-review-join.md)
  for the per-unit-keying invariant that this model preserves.

**state-access seam**:
(unit gh413, 2026-08-31) — the unified shell library at
  `hooks/scripts/lib/state-access.sh` that provides the single sourced
  interface for all state-touching hook scripts to read, write, and sweep
  (prune) artifacts. Consolidates what were previously hand-rolled
  read/write/delete operations scattered across 12+ hook scripts into
  named entry points organized by **5 key domains**. Exported functions
  include `state_read_unit_marker`, `state_write_unit_marker`,
  `state_read_pending_review`, `state_write_pending_review`,
  `state_delete_pending_review`, `state_read_session_baseline`,
  `state_write_session_baseline`, `state_read_dispatch_override`,
  `state_write_dispatch_override`, `state_append_audit_log`,
  `state_sweep_wip_handoffs`, `state_sweep_session_baselines`, and
  `state_sweep_dispatch_overrides`. The seam preserves all 10 ordering and
  atomicity constraints, all 15 distinctions (e.g., `.directed`'s deliberate
  exclusion from stop-gate's glob check, create-only-if-absent semantics on
  `.pending-review` and `.session-baseline`, `.consumed`'s content-embedded
  epoch, the DECISION zero-identity write ban, per-unit file granularity per
  ADR-0016). Does NOT own glob or enumeration operations — those remain as
  direct filesystem globs in the calling scripts, since enumeration wasn't
  part of the seam's contract. Mirrored byte-for-byte to adapter ports
  (Codex, Cursor) as part of the **declared-shared set**; each adapter port's
  own **thin entry script** wraps the seam with port-specific payload
  translation. **Important note on adopting repos:** this repo self-hosts the
  plugin it ships and has stopped *populating* these artifacts locally as of
  unit gh413, per sibling spec 6's adoption. The shipped product continues to
  create and manage these artifacts in every adopting project; this repo's own
  operations no longer validate this surface end-to-end, but the seam itself
  is still shipped and must work correctly when other projects use it.

**results-reported cursor**:
(unit A, 2026-08-25) — a line-count watermark at `.claude/.microworld-results-reported`
  (one per port: `.cursor/`, `.codex/`, `.claude/`) that tracks which lines of the
  **Microworld audit log** have already been surfaced to the user. Distinct from the
  retired [[clear-watermark]] (a timestamp-based global flag) and the per-unit [[review-join stamp]].
  This cursor enables "exactly-once" reporting of **deferred result surfacing** by both
  `stop-gate.sh` (primary channel, runs at every Stop/SubagentStop) and `session-start.sh`
  (backstop channel, runs once at session start). The reader that sees a new audit-log
  line first advances the cursor; the other reader checks the cursor and skips already-reported
  lines. See [[deferred result surfacing]].

**deferred result surfacing**:
(unit A, 2026-08-25) — the mechanism by which asynchronous microworld bundle
  and watch-map entry results are reported to the user after they complete. The
  `microworld-rerun.sh` **Reporter** enqueues bundles on `PostToolUse` and returns
  immediately; results are logged asynchronously by the **drain loop** and surfaced
  via two channels: `stop-gate.sh` (primary, runs at Stop/SubagentStop events in the
  same session) and `session-start.sh` (backstop, runs once per session start for
  results from prior sessions). Both channels use the **results-reported cursor** to
  avoid duplicate reporting. Implemented in [[microworld-queue.sh]], [[stop-gate-core.sh]],
  and `session-start.sh`. See [[drain loop]], [[coalescing]], [[pending file]].

**mutation proof**:
(memo-key-2, 2026-08-26) — the repo's primary anti-vacuity mechanism: a
  **[[Microworld bundle]]** that mutates the code under test (by environment prefix,
  file modification, or equivalent mechanism) and re-invokes the same test suite,
  expecting a *different* exit code than the unmutated baseline run. Regression tests
  for **mutation proof** bundles are themselves mutation-proved (AC-1.3, AC-1.4 in
  the plan). Enabled by **[[suite-level memoization]]**, which keys on code state
  changes; prior to commit 194add2, the memoization was keyed on test path alone and
  defeated this mechanism. See [[drain loop]].

**mutation-proof direction**:
(unit rollout-preflight-bump-18, 2026-09-23) — a property of a test or criterion
  that evaluates to `true` if the measurement genuinely *binds to* its baseline value
  and responds to mutations of that value, and `false` if the measurement *derives*
  its expected value (e.g., by computing `actual + 1`) and thus never registers
  divergence. Exemplified in `tests/rollout-preflight.test.sh` AC6b: `--owner reviewed-path-gate.sh`
  hardcodes expected spec set `{1, 2, 3}` from the ownership table and fails when the table
  is mutated (e.g., removing spec 1 from the entry). A vacuous counter-example would derive
  `expected = all_specs - [spec_3]` from the output itself, passing regardless of whether
  the ownership changed (mutation-proof direction does not hold). Core to [[mutation-proof]]
  effectiveness — a bundle with a vacuous direction test will always pass, masking
  regression, so the direction must be verified by reverting the criterion and
  observing it flip. See [[mutation discipline]] in the spec governance context.

**flip unit**:
(unit rollout-a24-remechanize-1, 2026-09-23) — the Phase 2 disablement-flip commit
  specified in `docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`'s A24 criterion,
  which will assert "no scripts deleted from `hooks/scripts/`" via `git diff --diff-filter=D`
  scoped to that commit. Used in `scripts/rollout-preflight.sh:407` as a **flip unit comment** (a spec-coupled contract string);
  also appears in `tests/rollout-preflight.test.sh:251` where `--reverify 6` greps for the
  literal phrase "flip unit" to verify A24's skip reason is correctly stated. Forward reference:
  the flip unit does not yet exist in the repo (it is a future, authored-separately commit),
  so A24 remains a documented skip (never approximated by a hardcoded script count that would
  require bumping — see [[treadmill]]). See A24 in the rollout-sequencing spec.

**drain loop**:
(unit A, 2026-08-25) — the async background process body that consumes queued
  microworld bundles and watch-map entries from **pending file**s and executes them,
  logging results to the **Microworld audit log**. Implemented in `hooks/scripts/lib/microworld-queue.sh`'s
  `_drain_loop()` function: runs as a detached child (`&` spawn) after `start_async_runner()`
  acquires the lock, processes all pending entries in a defensive loop with a 1000-iteration
  cap, and terminates when no pending files are found. A single drain loop instance
  enforces at-most-one-in-flight per bundle (AC-A5) and provides suite-level dedup (AC-A4)
  via the **coalescing** of edits and [[suite-level memoization]]. The lock file
  `.claude/microworld-queue/.runner.lock` (created via `mkdir`) ensures only one drain loop
  runs at a time; multiple enqueue attempts just overwrite pending files while the loop is
  active, adding new work to the same drain pass.

**coalescing**:
(unit A, 2026-08-25) — the queueing strategy where multiple enqueued runs of the same
  bundle from a single edit (or multiple edits in rapid succession) are collapsed into a
  single execution within one **drain loop** pass. Implemented via **pending file** overwrites:
  a new `enqueue_bundle()` call just writes over the old `.pending` file for that slug,
  so the drain loop only sees the latest rel_path. Satisfies AC-A4 (dedup) and AC-A5
  (at-most-one-in-flight + at-most-one-queued). Suite-level dedup is additionally provided
  by [[suite-level memoization]].

**pending file**:
(unit A, 2026-08-25) — a state file in `.claude/microworld-queue/` (or `.cursor/`/`.codex/`)
  that records a bundle or watch-map entry awaiting a run. Named `<slug>.pending` for
  **microworld bundle**s (e.g., `mytest.pending`) or `.wm.<id>.pending` for watch-map entries
  (e.g., `.wm.check-1.pending`). Contains a single line: the relative path to the changed
  file that triggered the enqueue. Written by `enqueue_bundle()` and `enqueue_watchmap()`
  (overwriting on subsequent enqueues, implementing [[coalescing]]). Consumed by the **drain loop**'s
  glob-based scan each iteration; files are deleted after processing. See [[microworld-queue.sh]].

**suite-level memoization**:
(memo-key-1, 2026-08-26; AC-A4 control, expanded memo-key-2) — the exported-`bash`-function
  wrapper (`_memo_setup` in `hooks/scripts/lib/microworld-queue.sh`, :58-80) that memoizes
  `bash tests/*.test.sh` calls to avoid redundant suite executions within a **drain loop** pass.
  Implements AC-A4 (dedup) across multiple **[[Microworld bundle]]**s and edits that invoke the
  same suite identically. **Post-fix key composition** (commit 194add2): the sanitized test
  file path (`$1`) plus a `cksum` digest over argv (`"$@"`) and environment (`env | sort`),
  combined as `key="<sanitized-path>.<digest-value>"`. **Per-shell guard**: a `<key>.$$.seen`
  zero-byte marker (where `$$` is the invoking shell's PID) ensures each shell consumes a cached
  result at most once, preventing in-process [[mutation proof]] bundles from seeing stale results
  across independent suite invocations. **Per-pass flush**: results are cached in
  `$MICROWORLD_MEMO_DIR/results/` (a drain-loop-scoped `mktemp -d`), and this directory is
  cleared at the top of each outer **drain loop** iteration (before the `*.pending` glob), so
  pass-2 results are never served from pass-1 cache. Cache never overwrites an earlier result
  (the unmutated baseline is always the authority). See [[drain loop]], [[mutation proof]].

**timing harness**:
(unit A, 2026-08-25) — a reusable latency-measurement framework at `tests/lib/timing-harness.sh`
  that invokes a real hook with canned stdin, records wall-clock elapsed times over N iterations,
  and computes p50/p99 percentiles. Sourced by budget tests (e.g., `tests/hook-latency-budget.test.sh`
  for AC-A1). Exported functions: `measure_latencies()` (returns one float per line, invocation order),
  `percentile()` (reads sorted latencies, computes p-th percentile), `assert_budget()` (measures,
  reports, and returns nonzero if either p50 or p99 exceeds budget). Used by Unit B's AC-B1
  to measure SubagentStop latency gates; **forward note:** `assert_budget()` currently treats any
  nonzero exit as a budget blowout, but Unit B's AC-B1 will legitimately exit 2 when stop-gate.sh
  has deferred results to report — a future `expected-rc` parameter is needed to avoid false failures.

**latency budget** / **p50/p99 budget**:
(unit A, 2026-08-25) — performance target thresholds (in seconds) specified for a hook test,
  enforced by the [[timing harness]]'s `assert_budget()` function. Format: `p50_budget` (median
  latency upper bound) and `p99_budget` (99th percentile latency upper bound). Example:
  `assert_budget "stop-gate" 0.100 0.200 50 "$json" -- stop-gate.sh` measures 50 invocations
  and requires p50 ≤ 0.1s and p99 ≤ 0.2s, returning nonzero if either is exceeded. Gates used
  by AC-A1 (Unit A) and will be used by AC-B1 (Unit B).

**nearest-rank convention**:
(unit #477, 2026-09-23) — the percentile calculation convention implemented independently
  in two tools: the `percentile()` function in `tests/lib/timing-harness.sh` (shell) and the
  percentile calculation in `scripts/bash-output-census.js` (Node). Both use the same
  method to compute the p-th percentile of a sorted dataset, enabling consistent percentile
  reporting across measurements. Readers grepping "percentile" will find both implementations
  under this canonical term. See [[bash-output census]], [[timing harness]].

**Transcript store**:
(unit #477, 2026-09-23) — the nested directory layout at `~/.claude/projects/<slug>/`,
  where a Claude Code session stores transcript `.jsonl` files. The layout is NESTED: the
  majority (~88%) of transcript files are located at `<session-uuid>/subagents/*.jsonl`,
  with only ~12% at the top level. This nesting structure is critical to understanding the
  scope of transcript operations: single-directory scans miss the vast majority of
  transcripts. The [[bash-output census]] tool walks this nested structure recursively
  to enumerate and measure all bash output across the full transcript store. See
  [[bash-output census]].

**treadmill** (maintenance burden):
(unit rollout-a24-remechanize-1, 2026-09-23) — the recurring manual burden that arises
  when a spec criterion measures a hardcoded baseline (e.g., "`hooks/scripts/` contains exactly
  17 files") instead of deferring to a future commit's git-diff range. Each time new code adds
  a matching item (a new `hooks/scripts/*.sh` file), the hardcoded baseline drifts and must be
  manually bumped — this happened 4 times (gh418, gh420, spec2-unitC, version-stamp-guard-1).
  A24's conversion to a documented skip (referencing the **flip unit**) permanently ends the
  treadmill by eliminating the hardcoded count; cited in `scripts/rollout-preflight.sh:405`
  (the skip reason) and `tests/rollout-preflight.test.sh:258` (the property being tested —
  "adding a hooks/scripts/*.sh file must not change A24's report"). Contrast with measurements
  that *can* derive fresh expectations (e.g., "count existing files now") — a treadmill is
  specifically the cost of hardcoding baseline values that diverge from reality. See [[flip unit]].

**Protocol excerpt**:
the subset of `templates/persona-protocol.md`'s 19
  `## `-delimited canonical sections that a given full-tier persona's
  `.claude/agents/*.md` mirror actually inlines, per `bin/cli.js`'s
  `PROTOCOL_SECTIONS_BY_PERSONA` matrix (issue #190, 2026-08-01 efficiency
  pass, finding F1). Distinct from the full/slim **tier** (which file a
  persona gets): the excerpt is which sections *within* the full tier. Three
  fail-closed rules govern it: an unknown persona name gets every section;
  a matrix row naming a non-existent heading throws at load; any persona in
  `gatedAgents` force-includes "WIP sentinel" and "Pending-review flag"
  regardless of its row. Claude-Code-only by construction — the Cursor and
  Codex adapter ports have no per-persona seam and keep carrying the union.
  `.claude/persona-protocol.md` exists on disk as the full, untrimmed
  reference copy a trimmed persona can read on demand (reversing the
  earlier `OQ11=DROP` decision, whose premise stopped holding once excerpts
  were trimmed). See [protocol-delivery-tiers.md](.claude/wiki/protocol-delivery-tiers.md).

**Inlined protocol section exclusion**:
(unit reviewer-changes-examples-lean-1, 2026-09-23) — when a `templates/persona-protocol.md`
  section is dropped from a persona's [[Protocol excerpt]] via
  `PROTOCOL_SECTIONS_BY_PERSONA` (e.g., reviewer's "Fourth verdict: escalate-to-human"
  in its `drop[]` list), that persona may instead carry its own hand-authored or
  hand-adapted copy of that content as an independently-maintained source, not
  generated from the template. Example: `agents/reviewer.md` (~lines 247-311)
  maintains a hand-authored, second-person copy of CHANGES.md/EXAMPLES.md
  authoring instructions; the adapter ports (`adapters/codex/agents-md-fragment.md`
  and `adapters/cursor/rules/persona-protocol.mdc`) carry hand-adapted condensed
  copies. This creates **four separately-maintained copies** of the same rules:
  template (canonical but inlining-dropped), reviewer-local (hand-authored),
  and two adapter fragments (hand-adapted). Editing the template section does
  **not** update these persona-local or adapter-specific copies — coordinated
  hand-sync across all N copies is required in follow-up units (e.g., unit
  reviewer-changes-examples-lean-2). Not all dropped sections follow this pattern:
  only sections whose content the persona's own documentation surface needs to
  preserve; other drops are simply omitted entirely. Inlining occurs at
  `bin/cli.js` ~line 755 during scaffold/`--update --force-render`. See
  [[Protocol excerpt]].

**Measured heavy-unit surface**:
a measured heavy-unit surface is the reviewer's mechanized read of ADR-0004
  criterion 1 (changed-surface size), computed by
  `hooks/scripts/heavy-trigger.sh <git-range>` (issue #373/#374), which prints
  `surface: heavy|light|unknown files: <n|-> lines: <n|->`. Run once per unit,
  over the unit's own review range, before the reviewer settles a verdict.
  `surface: heavy` is **sufficient, never necessary** for the escalate-to-human
  heavy-unit trigger — it mechanizes only criterion 1 of ADR-0004's three
  ANY-of criteria, so `surface: light` means just that criterion 1 is unmet;
  criteria 2 (structural/cross-cutting) and 3 (security-sensitive) remain
  reviewer judgment either way. `surface: unknown` (an unmeasurable range) is
  treated as `heavy`. A `heavy` reading the reviewer PASSes through anyway is
  recorded as `heavy-surface override: <reason>`, appended to the `.pass`
  marker's notes. Contrast with **Measured reviewer tier** immediately below,
  which is measured the same way (a deterministic script, fail-closed) but
  picks the reviewer's *model*, never whether to escalate.

**Measured reviewer tier**:
the reviewer's `sonnet`/`opus` model is
  decided at reviewer-*dispatch* time (not pre-implementation) by
  `hooks/scripts/reviewer-tier.sh <task-id> <git-range>`, a deterministic,
  fail-closed script (not a registered hook — deliberately absent from
  `hooks/hooks.json`; it's an orchestrator-invoked helper). It prints
  `sonnet` only when the diff is ≤40 changed lines AND ≤3 changed files AND
  touches no sensitive path class; otherwise `opus`. Replaces the earlier
  ADR-0006 scheme where `task-master` guessed reviewer tier from its own
  pre-implementation `Suggested model: haiku` tag — a prediction that was
  reachable roughly 0% of the time in practice. This was ADR-0009's historical
  rationale, measured at issue #190 (finding F2): no unit in this repo was
  tagged `haiku`. The orchestrator's judgment
  may **downgrade** `sonnet` → `opus` but may **never upgrade** `opus` →
  `sonnet`; `fable` stays permanently excluded from the gate (ADR-0004) and
  a prior `.fail` record still forces `opus`. Measured on 2026-08-03 at 8/60
  commits (13.3%), inside the predicted band. See
  [ADR 0009](docs/adr/0009-reviewer-tier-measured-eligibility.md), which
  amends [ADR 0006](docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md).

**Mutation-proved**:
(unit #305, 2026-08-09) — a test or acceptance
  criterion whose non-vacuity has been verified by running it against a
  deliberately corrupted ("mutated") copy of the artifact. The mutated copy's
  test failures prove the check detects real problems, preventing acceptance
  criteria from passing while detecting nothing. Traces back to a defect
  lineage (commits `028bc23`, `8cedabd`, `22f5bb2`) where prior tests passed
  without catching actual failures.
_Avoid_: vacuous test, untested criterion

**Implementer-tier ratchet**:
the `.fail` disqualifier on lead-programmer
  tier scaling. A unit's `.claude/reviewed/<task-id>.fail` record (from a
  prior FAIL verdict) permanently removes access to cheaper tiers, forcing
  `sonnet`→`opus` on re-attempt. This ratchet expires on a
  subsequent verified PASS marker for that unit (unit #233). Distinct from the
  reviewer-gate ratchet.

**Writer tier**:
the lead-programmer's (implementer's) model tier, defaulting to
  `sonnet` as of ADR-0026 (reversing ADR-0010's earlier `haiku` default).
  Synonym for "implementer tier" in the context of the writer/implementer
  executing a spec. The reactive escalation rule (the **Implementer-tier ratchet**)
  applies when a unit fails: a `.fail` record forces `opus` on re-attempt.
  See [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).

**Reviewer-gate ratchet**:
the `.fail` disqualifier on the reviewer's own
  model eligibility. A unit's `.claude/reviewed/<task-id>.fail` record from the
  reviewer permanently forces `opus` on that unit's reviewer gate, regardless of
  whether a subsequent PASS marker exists. This ratchet never expires
  (unit #233, OQ3 ruling). The asymmetry (implementer tier expires, reviewer gate
  does not) preserves the core safety property: if a reviewer has once missed
  something on a cheaper tier, all future reviews run on the full-strength tier.
  Distinct from the implementer-tier ratchet.

**Rulings ledger**:
(unit orch-rulings-wait-heuristic, 2026-09-12) — the advisory log at
  `.claude/orchestrator-rulings.log`, an append-only record where the orchestrator
  documents self-authorized judgment calls (e.g., downgrade-only reviewer-tier
  overrides). Format: `RULING <UTC ISO-8601 timestamp> unit=<task-id|n/a> decision=<summary>`.
  This log is **not** a gate, **not** checked by any hook, and **not** a substitute
  for PASS/FAIL markers (which remain authoritative). It records only decisions the
  orchestrator was already authorized to make alone; it is never a substitute for
  `AskUserQuestion` or `ESCALATE-TO-HUMAN` escalation paths. The log is a **fifth
  member of the Log domain** (see [[5 key domains]]), explicitly distinct from the
  sealed audit-log family (review-audit.log, wip-audit.log, microworld-audit.log,
  dispatch-audit.log). Disambiguate from **ruling** (human operator's decision,
  see [[ruling / rulings disambiguation]]).

**ruling / rulings disambiguation**:
(unit orch-rulings-wait-heuristic, 2026-09-12) — the term "ruling" appears in two
  distinct senses in the codebase, referring to decisions by different actors.
  (1) **Human ruling** — a judgment by a human operator on a unit (e.g., "unit #233,
  OQ3 ruling" in the context of **Reviewer-gate ratchet**), made via the human-review
  escalation process (see [[Escalation to human review]]). (2) **Orchestrator ruling**
  — a self-authorized judgment call by the orchestrator, recorded in the **Rulings ledger**
  and prefixed with the `RULING` token. The two senses refer to different actors
  (human vs. orchestrator) and different recording mechanisms (escalation packet vs.
  advisory log). Context determines which is meant; when ambiguous, prefix with
  "human" or "orchestrator" to clarify.

**Forward-verification rule**:
(ADR-0026, unit spec2-unitD, 2026-08-25) — the pre-registered criterion for
  validating whether the **Writer tier** reversal (from haiku to sonnet default)
  delivers its predicted benefit. Stated as: "After ≥60 units dispatched under
  the `sonnet` default, the FAIL rate must have fallen below the 32.5% haiku-era
  rate. If not, the reversal has not delivered its predicted benefit and must be
  revisited rather than defended." Measurement is mandatory, not optional; the
  rule is recorded in the decision record itself, not as a post-hoc intention.
  Verified via `scripts/spend-accounting.sh --until=<cutoff>`. Coupled with
  **spend-neutrality** — both conditions must hold for the reversal to remain valid.

**Spend-neutrality**:
(ADR-0026, unit spec2-unitD, 2026-08-25) — the cost-accounting condition for
  validating the **Writer tier** reversal. The rule states: total spend must not
  materially worsen. A `sonnet` writer costs ~3× a `haiku` one per attempt; the
  bet is that fewer opus re-reviews more than pay for that per-attempt cost
  increase. Not a hard threshold (no numeric tolerance is specified in ADR-0026),
  but a materiality judgment to be rendered at verification time using
  `scripts/spend-accounting.sh` output. Coupled with the **Forward-verification
  rule** — both conditions must hold for the reversal to remain valid.

**F9 convention (unit #241) — resume-by-name on `INSUFFICIENT-CONTEXT`:**:
When
  a reviewer dispatch encounters a missing constraint and signals
  `INSUFFICIENT-CONTEXT`, the orchestrator resumes the same reviewer session by
  name via `SendMessage`, quoting the constraint, instead of spawning a fresh
  dispatch. This does not count against the 2-FAIL cap, does not re-dispatch
  lead-programmer, and the standing pending-review flag stays in place.

**F11 convention (unit #242) — reuse-over-re-derivation by role:**:
When a
  dispatch packet already contains a `## Pre-resolved context` blast-radius or
  structural answer, personas verify the specific doubted claim via `explorer`
  rather than re-deriving from scratch. Applies to lead-programmer,
  spec-master, and milestone-auditor only — the reviewer is explicitly exempt
  and always re-derives blast radius independently.

**The graph**:
Code Review Graph, a third-party MCP server providing
  structural code queries (callers/callees, blast radius, architecture
  overview). Scoped to `explorer` alone, never project-wide — see
  [ADR 0001](docs/adr/0001-mcp-scoped-to-single-persona.md).

**Skills-library remediation completed**:
(2026-08-07, spec #245 / unit #255) —
  all persona-declared skills are now reachable in every mode. The `disable-model-invocation`
  flag was stripped from `to-spec`, `to-tickets`, `handoff`, and
  `improve-codebase-architecture`; `grill-me` repointed to `grilling`; `implement`
  deleted; `domain-modeling` wired into `scribe`. Plugin cache refreshed to
  v0.25.0 and reachability verified live post-restart. **All reachability claims
  (Steps 4/5) are now verified live, not just by file-content grep.** The `fm-noflag`
  declared-deviation class (stripping the model-invocation flag from `handoff` and
  `improve-codebase-architecture`) is now formally documented in [ADR 0012](docs/adr/0012-vendored-skill-declared-deviations.md);
  [ADR 0005](docs/adr/0005-vendor-mattpocock-skills.md) amended to reference it.
  See `docs/plans/2026-08-04-skills-library-remediation.md` Revision 5.

**fm-noflag set now four skills**:
(2026-09-11, unit gwd-1) — the [[`fm-noflag` declared-deviation class]] (stripping the
  upstream `disable-model-invocation` flag from vendored skills) now applies to four
  skills: `handoff`, `improve-codebase-architecture`, `grill-me`, and `grill-with-docs`.
  This supersedes the earlier framing that "`grill-me` is the control, deliberately left
  alone" ([ADR 0012](docs/adr/0012-vendored-skill-declared-deviations.md) as of 2026-08-07).
  The reversal is formally recorded in [ADR 0031](docs/adr/0031-grill-with-docs-model-invocable.md),
  which amends ADR 0012. All four skills are byte-diffed by `scripts/resync-vendored-skills.sh --check`
  as part of the [[drift-tracked skills]] set.

**Upstream MCP tool naming gap**:
(recorded 2026-08-06) — code-review-graph
  installer templates contain five MCP tool names lacking the `_tool` suffix
  that the live MCP server actually exposes: `get_flow`, `list_graph_stats`,
  `get_community`, `list_flows`, `find_large_functions`. Seven occurrences in
  shipped SKILL.md files (`debug-issue`, `explore-codebase`, `refactor-safely`).
  Root cause is upstream installer content bug, not antislop defect. Now that
  these SKILL.md files are tracked/shipped, the gap is more visible and should
  be fixed in the installer itself.

**This repo's own ADAPT state**:
this repo self-hosts the plugin it
  ships (dogfooding). Its `.claude/persona-config.json` documents exactly
  which personas and substitutions this repo itself uses.

**npm distribution strategy**:
(unit #137, 2026-08-15, policy decision) — the project's `package.json`
  `files` array intentionally ships only `skills/coding-discipline` and
  `skills/install-antislop`; every other skill is excluded. All other
  skills (vendored, optional, project-specific) are distributed via git
  clone or the plugin marketplace instead. See [ADR-0022](docs/adr/0022-npm-distribution-skills-excluded.md)
  for rationale and distribution paths.

**`to-spec` skill**:
vendored first-party skill (originally from Matt
  Pocock's `skills` repo, see `skills/THIRD-PARTY-NOTICES.md`), wired to
  `spec-master` via `antislop:to-spec`. Turns a finalized spec
  conversation into a single published spec (Problem Statement / Solution /
  User Stories / Implementation Decisions / Testing Decisions / Out of Scope)
  on the issue tracker, no further interview. Complements `grill-me`
  sequentially: grill to resolve ambiguity, then to-spec to synthesize and
  publish. The template LAYERS on top of the v0.9.0 spec-kit format (Goal →
  Context → Clarifications → …), not replacing it.

**fast-path threshold**:
≤5 dispatchable units in a finalized spec. Below
  it, `spec-master` emits the nine-element dispatch contract directly from
  the `docs/plans/` document — `task-master` and `to-tickets` are bypassed,
  and the `docs/plans/` document is itself the retrieval contract. Raised
  from ≤2 to ≤5 by Step 3 of the 2026-08-16 ceremony-reduction plan
  ([ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md), amending
  [ADR-0003](docs/adr/0003-hivemind-split-spec-master-task-master.md)). Not
  to be confused with `bin/cli.js --update`'s *version-match fast path*
  (see this glossary's `--force-render` / `--dry-run` entries) — an
  unrelated mechanism that happens to share the words "fast path". See
  [[publish threshold]].

**publish threshold**:
≥6 dispatchable units in a finalized spec (or any
  multi-milestone spec). At or above it, `spec-master` maps the finished
  plan onto the `to-spec` PRD template and publishes it to the issue
  tracker with the `ready-for-agent` label. Below it (≤5), publishing is
  optional and the `docs/plans/` document remains the canonical artifact
  either way. Also spelled `tracker-publish threshold` (`CHANGELOG.md`,
  `docs/adr/0024`) and `publish-threshold` (`docs/adr/0024`) — this entry's
  heading is the canonical spelling. Coupled to [[fast-path threshold]] by
  design ([ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md),
  OQ-3): the two thresholds move together, never independently — a
  decoupled pair would let a 4-unit spec skip `task-master` while still
  filing a tracker issue nobody slices from.

**`pathfinder` skill**:
first-party skill for `task-master`, derived from
  Matt Pocock's `wayfinder` (adapted for dispatch, not a passthrough). Helps
  `task-master` build reliable, detailed, unambiguous dispatch tasks: one
  decision/one unit per ticket, refer-by-name, explicit blocking/ordering
  edges, precise acceptance criteria (enforces the machine-checkable-criteria
  rule). Ships via plugin-source `skills/pathfinder/SKILL.md` path.

**`roast-work` skill**:
first-party skill for `reviewer`, a detail-driven
  critique rubric (contradictions, missing parts, logic gaps, security
  vulnerabilities, actionable feedback) written to Matt Pocock's quality bar.
  Advisory and non-gating only — PASS/FAIL stays determined by the
  acceptance-criteria command + the existing materiality filter; roast-work
  never flips a verdict. Appended as a clearly-demarcated advisory section
  after the verdict line. Runs inline-only, as part of the single reviewer
  dispatch — there is no separate fable advisory pass.

**`ubiquitous-language` skill**:
a registered skill that detects
  terminology drift against the canonical glossary (`CONTEXT.md`) using three
  lenses: (a) a glossary term used with a different meaning, (b) a new
  synonym for an already-defined term, (c) a load-bearing new domain term
  with no glossary entry. Advisory only; never gates. Available in two input
  modes: `diff mode` (for `reviewer`) and `prose mode` (for `spec-master`).
  Replaces the spec-only definition at
  `docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md` lines
  568-629 (issue #129) by adding `prose mode` and wiring both modes into
  `spec-master`'s workflow (issues #130-131).

**Prose mode**:
input mode for the `ubiquitous-language` skill,
  operating on natural-language requests or draft specs. Consumes the input,
  applies the three drift lenses, and reports findings anchored on quoted
  spans or step/heading references. Advisory only; never blocks progression
  through `grill-me`, `to-spec`, or handoff to `task-master`. Used by
  `spec-master` at two pipeline points: category-8 ("Terminology
  consistency") grilling and Self-check on the draft plan. Complementary to
  **Diff mode**.

**Diff mode**:
input mode for the `ubiquitous-language` skill,
  operating on a git diff (file changes). Consumes changed code/docs, applies
  the three drift lenses, and reports findings anchored on `file:line`
  references. Advisory only; never flips PASS/FAIL and never adds a new FAIL
  ground. Used by `reviewer` as a post-verdict advisory section, appended
  after the verdict line. Complementary to **Prose mode**.

**`disable-model-invocation` flag**:
a hard, mode-independent skill
  configuration flag that removes a skill from context in every mode
  (direct invocation, teams mode, subagent context). A skill carrying
  `disable-model-invocation: true` in its frontmatter is entirely
  unreachable — not just in teams mode, but in all modes. This is distinct
  from skill *licensing*, which gates based on permission levels or
  operational mode; this flag is a blanket removal. See unit #254 (2026-08-07)
  for the correction to this repo's prior documentation, which had stated
  the weaker (false) version: "not in teams mode only."

**drift-tracked skills**:
(unit gwd-1, 2026-09-11) — the set of vendored mattpocock skills whose
  content is byte-diffed against upstream by `scripts/resync-vendored-skills.sh`.
  All drift-tracked skills are checked via either the `fm` (frontmatter) or
  `fm-noflag` reconstruction type (see [[`fm-noflag` declared-deviation class]]).
  As of unit gwd-1, there are 9 drift-tracked skills: `grill-me`, `grill-with-docs`,
  `grilling`, `handoff`, `tdd`, `diagnosing-bugs`, `improve-codebase-architecture`,
  `codebase-design`, and `domain-modeling`. The `--check` flag on the resync script
  reports per-skill status (`[OK]` for match, or drift details if changed). Distinct
  from the separate [[REPOINT_SKILLS]] set (skills pulled from upstream via live
  `skills@latest` rather than pinned to a specific commit). See `docs/maintenance/resync-vendored-skills.md`.

**Preloaded skill**:
a skill declared in a [[Persona]]'s `skills:` frontmatter, loaded into
  context automatically at dispatch time. Contrasts with an on-demand skill,
  which a persona must explicitly invoke via the `Skill` tool when needed.
  The distinction is **mode-sensitive**: `skills:` frontmatter preloading
  applies in normal subagent dispatch but NOT in agent-teams mode (see the
  "Agent-teams mode" section of `.claude/persona-protocol.md`). **Example:**
  `lead-programmer` preloads `antislop:coding-discipline`,
  `antislop:handoff`, and `antislop:tdd`; it invokes `antislop:diagnosing-bugs`
  on demand only. Contrast with [[`disable-model-invocation` flag]], which
  removes a skill from all contexts regardless of mode — preloading is
  context-dependent, not absolute.

**Harness**:
Claude Code the product — the IDE plugin and surrounding runtime
  infrastructure that hosts all personas, hook scripts, and agent dispatches.
  Distinct from "hook infrastructure" or "this repo's own gates" — the harness
  is the shared platform, not this project's local adaptation of it. When hook
  logic fails at the harness level (e.g., named dispatch defeating
  `agent_type` privilege checks, or `Write`/`Edit` grant rejection at
  tool-call time), mitigation is via protocol documentation or harness
  upgrade, not repo-side code.

**hook block event**:
(unit #288, 2026-08-11) — a transcript event (a `tool_result` entry in
  `message.content[]` with `is_error: true`) matching the pattern
  `PreToolUse:<Tool> hook error: [<path>/<hook>.sh]: BLOCKED:`, signaling
  that a `PreToolUse` hook refused a tool call. Distinct from the existing
  **grant-denied** term, which is an append-only log record in
  `.claude/review-audit.log` (not a transcript event). Hook block events are
  recorded by `scripts/agent-audit.sh`'s A7 section (Hook block events) as
  informational audit observations (never gating, never a finding). Named in
  [ADR-0020](docs/adr/0020-write-edit-content-not-scanned.md) as the event
  class that detection mechanisms exist to observe for bypass-detection.

**JSON type confusion**:
(unit #380, 2026-08-15) — a vulnerability class where a validator is gated on
  a type predicate (e.g., `typeof value === 'string'`) that silently no-ops for
  every other type, while the sink (where the value is used) coerces back to
  that type anyway. Validation is type-gated; the sink is type-agnostic, and the
  gap between them is the vulnerability. Classic example: a check like
  `if (typeof value === 'string' && /[\r\n]/.test(value))` written as a safety
  guard actually permits non-string JSON shapes (arrays, objects, booleans,
  numbers, null) to pass validation entirely; they then reach a template-literal
  sink (e.g., `` `by: ${value}` ``) where `Array.prototype.toString()` or
  similar coercion reconstitutes the prohibited content on the far side of the
  type check. **The fix:** validators must **fail closed on unexpected type**,
  never skip—put the type check in the **reject** condition, not as a
  precondition on whether to validate content. Free-text fields without an
  allowlist inheritance path need explicit type+content contracts precisely
  because they cannot borrow type-safety from field-level constraints. See
  `docs/plans/2026-08-15-gh380-debug-spec-type-confusion.md` for the worked
  instance and [ADR-0020](docs/adr/0020-write-edit-content-not-scanned.md) for
  the related security audit context.

**Agent identity**:
in hook payloads' `agent_type` and `subagent_type` fields,
  this field can take two forms: for unnamed (default) dispatch, it is the
  possibly-namespaced persona name `[<namespace>:]<persona-name>`; for named
  dispatch, it is the raw dispatch name given in the dispatch prompt (which is
  not a persona name). The gate hooks normalize identities to handle both forms,
  using asymmetric matching: liberal matching (any namespace) at sites where a
  miss fails open, conservative matching (recognized namespace only) at
  privilege-grant sites. Notably, `persona_matches_grant` (also called the
  "grant matcher") requires the first form (persona-derived); a raw dispatch
  name does not match. See plan #139 /
  `docs/plans/2026-07-28-agent-identity-namespace-gate-fix.md`; the shared
  library is `hooks/scripts/lib/agent-identity.sh`, replicated identically
  across all three platform ports. The audit-logging hardening for identity
  drift (percent-encoding, injective sanitize/dedupe key, append-only log,
  degrade-on-write-failure) is already shipped, not a future item — see
  `hooks/scripts/lib/agent-identity.sh:107-184`. The `ADR-0007` number itself
  is unused/retired: no such document exists or is planned (OQ-CF1,
  `docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md:2908-2917`,
  explicitly deferred out of scope for unit #244).
_Avoid_: persona name (only the persona-derived form is a persona name; named dispatch form is not)

**default-unnamed dispatch rule**:
the standing convention that `Agent` tool calls should dispatch without a `name:` parameter by default, causing their result to auto-return on completion. Named dispatch is reserved only for cases requiring **mid-flight addressability** — querying or re-tasking a long-running subagent mid-way through. The one exception is the 2-FAIL-cap / debug-spec scenario in "Nested dispatches", where explicit naming is mandatory. Deferred companion: a **mechanical report-loss backstop** to detect named agents completing without reporting (see `docs/adr/0021-mechanical-report-loss-backstop-deferred.md`).

**FAIL routing (post-reviewer)**:
normal FAIL routes the defect list to
  `lead-programmer` (unchanged). At the 2-FAIL cap, the orchestrator surfaces
  the two-attempt defect history and asks the human (via `AskUserQuestion`) how
  to proceed, offering three discrete options: **(a) Debug spec** — dispatch
  `spec-master` to produce a diagnostic artifact (diagnosis using the latest
  `.fail` record plus git log/git diff over fix-attempt commits, revised steps),
  which then routes through the same ≤5-unit fast path as any other spec:
  `task-master` re-derives dispatch instructions only if the debug spec itself
  resolves to ≥6 units; a debug spec resolving to ≤5 units skips `task-master`
  and spec-master emits the dispatch contract directly. **(b) Re-dispatch with
  human directive** — re-dispatch `lead-programmer` on the same unit with an
  operator-supplied correction (this option does not count against the 2-FAIL
  cap). **(c) Park the unit** — stop work on it and move on without modifying
  the defect-history marker (see [[parked unit]]). `task-master` is never a re-plan owner. Mid-flight
  "spec gap" signals also route back to `spec-master`.

**Blocked by a gate you do not own**:
(unit #265, 2026-08-08, protocol section
  added) — When a hook or gate blocks you and the resolution is not yours to give,
  there are exactly two legal responses: do what the gate asks (if that is your
  call) or report and wait. Metadata-only workarounds — `touch` to satisfy an
  existence check, mtime bumps, deleting/editing a gate's own state file,
  re-running with a disarming flag — are violations regardless of intent or
  disclosure. Exceptions are sanctioned: the WIP sentinel (`touch .claude/.wip`)
  and `defer:`/`skip:` escapes in pending-review flags have their own audit
  trail and are documented exits, not bypasses. If a gate's premise looks false,
  that is evidence of a gate defect and reporting it is the fix, not routing
  around it.

**self-authorized bypass**:
(unit #288, 2026-08-11) — a violation class where an agent identity routes
  around a gate that blocked it, without waiting for or obtaining authorization
  to bypass the gate. Examples include: using shell-variable substitution to split
  a marker-path literal so the gate's substring scan never sees it contiguously,
  or using string concatenation and `python3` to assemble a forbidden path at
  runtime. Never self-authorize a bypass; the correct response to a gate block is
  "report and wait" per the **Blocked by a gate you do not own** protocol
  section. Named in [ADR-0020](docs/adr/0020-write-edit-content-not-scanned.md)
  as the violation class that detection mechanisms (like A7 hook-block events)
  exist to observe.

**Privileged persona**:
(unit gh440, 2026-09-10) — a persona (`reviewer`, `orchestrator`) whose dispatch
  name cannot be forged. The `PRIVILEGED_PERSONAS` array in
  `hooks/scripts/lib/reviewer-route-gate-core.sh:55,61` enumerates these personas;
  the reviewer-route-gate unconditionally checks every dispatch's `name:` field against
  this set. If a `name:` resolves to a privileged persona (via `identity_persona_name`)
  but the dispatch's `subagent_type` does not match it, the dispatch is denied (exit 2).
  Membership is maintained by derivation test in `tests/reviewer-route-gate-caller.test.sh`
  (grep-derived union of `persona_matches_grant`/`persona_matches_gate` call-site literals,
  compared against the actual array), so a future grant or caller addition that omits
  a privileged persona from the array will surface as a test mismatch. Known caveat:
  derivation test anchors `\$[A-Za-z_]+`, so digit-suffixed or brace-form variable
  spellings would be silently missed. See [[Identity forgery]].

**Identity forgery**:
(unit gh440, 2026-09-10) — an attack distinct from [[self-authorized bypass]]: forging
  a dispatch's identity by supplying a `name:` field that names a [[Privileged persona]]
  (e.g., `name: "reviewer"`) while pairing it with a `subagent_type` that doesn't match
  that persona (e.g., `subagent_type: general-purpose`). The forger attempts to bypass
  the gate's persona-identity checks, which are normally gated on the `subagent_type` field,
  by creating a mismatch the gate can detect. Whereas [[self-authorized bypass]] happens
  after a gate blocks (routing around the block without permission), identity forgery
  happens at dispatch time, before any gate runs—it is the premise the privileged-persona
  check in reviewer-route-gate-core.sh exists to prevent. Denied by `reviewer-route-gate.sh`
  (exit 2) before target_type-keyed blocks, not gated on persona-config.json.

**reviewer-dispatch caller allowlist**:
(unit gh347, 2026-08-13) — the rule that only the main session (the
  `orchestrator`) may spawn the `reviewer` via the `Agent` tool, enforced in
  `reviewer-route-gate.sh`. The allowlist admits exactly two caller identities:
  an empty `agent_type` (the main session with `settings.json`'s `.agent`
  unset) and `orchestrator` (the same session with it set, which ADAPT always
  does). Unlike every other gate site in that file, this one deliberately fails
  **closed** — an unrecognized caller is refused rather than admitted — because
  the invariant is positive ("only the orchestrator dispatches the reviewer")
  and a blocklist would have to enumerate every generic identity forever. The
  closed direction applies only when the dispatch target is `reviewer`.
  Motivating failure: an `Agent` call omitting `subagent_type` defaults to
  `general-purpose`, which can never receive an instruction-level rule, and
  which twice answered the resulting marker-write block by spawning a nested
  reviewer — the **self-authorized bypass** class. Distinct from the
  **default-unnamed dispatch rule**, which governs the `name:` parameter rather
  than the caller, and from the `name:`-mismatch refusal in the same hook.
  Complements the mechanical half of **The Writer/Reviewer split**.

**Reviewer dispatch opening line**:
(unit #266, 2026-08-08, enforcement added)
  — Every reviewer dispatch must open with `Unit: <task-id>` as its literal
  first non-blank line. `reviewer-route-gate.sh` reads exactly that line for
  task-id extraction; omitting it causes silent open-fail (the gate accepts the
  dispatch but router routing breaks). Disciplined by lead-programmer dispatch
  instruction template, checked by `dispatch-hygiene.sh` H4.

**Review-join stamp condition**:
(unit #266, 2026-08-08, prose corrected) —
  The reviewer's flag-clear path (via `stop-gate.sh`'s SubagentStop branch on
  `clear: true`) is now conditional on the dispatched unit holding a verdict.
  The `.claude/.review-join.<task-id>` stamp from the review-join sequence (issues
  #262-264) marks when a unit has received independent reviewer scrutiny; only
  when this stamp exists is flag-clear permitted. This binds flag-clearing to a
  measurement of review completeness rather than just a SubagentStop event,
  closing the gap where a reviewer could auto-clear flags between re-runs of a
  fresh dispatch without having rendered a verdict. Enforced by
  `stop-gate.sh:188-198` when `$verdict_gate_mode` is `on` (the default).

**Source-artifact + render-step gating rule**:
(unit #265-267, 2026-08-08,
  institutional lesson recorded) — A spec plan step that edits a source artifact
  (e.g., `templates/persona-protocol.md`) and a separate step that regenerates
  or ports its shipped copy (e.g., `.claude/agents/*.md` mirrors) **can never be
  gated independently** under this repo's `tests/validate.sh`. The mirror
  assertions cannot tolerate intermediate non-render commits between the two
  steps: they enforce bijection across all declared sections, so an edit-only
  commit fails the suite and a render-only commit fails differently (it rewrites
  the mirrors). When planning specs that touch source + render pairs, either (1)
  merge them into a single unit up-front, or (2) pin the intermediate failure
  set in the spec (as `docs/plans/2026-08-07-per-unit-review-join.md` did at
  lines 442-469) and audit that all mirror-vs-shipped checks sweep **every**
  such pair, not just the first. This is a standing rule for all future specs,
  not specific to the review-join feature. See `docs/plans/2026-08-07-per-unit-review-join.md`
  CHK18 (line 1249) for the generalization.

**Guidance-only**:
a change that improves documentation, protocol prose, or
  instruction without altering any shipped code or hook enforcement logic. The
  inverse of **enforcement code**. Guidance-only changes prevent future
  mistakes (by making intent/boundaries explicit) but do not themselves block
  or detect violations — only enforcement code does that.

**Enforcement code**:
a code change in hooks, gates, or validators that
  mechanically blocks, detects, or prevents a specific failure mode at
  runtime. The inverse of **guidance-only**. Examples: `stop-gate.sh` blocking
  a non-reviewer from altering markers, `dispatch-hygiene.sh` rejecting an
  oversized prompt, `reviewer-route-gate.sh` refusing a named reviewer
  dispatch. An enforcement code change is the only mechanism that guarantees
  compliance; guidance can be ignored or misunderstood.

**message-resume**:
compact synonym for "resume-by-name via `SendMessage`" — the mechanism for
  continuing work with an existing agent by sending it a message instead of
  spawning a fresh `Agent` dispatch. Disciplined by unit-dispatch rules (see
  [[F9 convention]] and "Reviewer re-tasking discipline" in `agents/orchestrator.md`).
_Avoid_: resume-by-name via SendMessage (use the compact form in the glossary context)

**roster**:
the collection of addressable **Agent** entities currently active in a
  session, identified by name. A bare-name `SendMessage` resolves to the most
  recent holder of that name. Before re-using a name to message an existing
  agent, confirm its dispatch unit via direct query rather than via a disk
  lookup (review markers are keyed by unit id, not agent name). See
  "Check the roster before dispatching" in `agents/orchestrator.md:139`.

**gh-304 dual-marker incident**:
(unit #307, 2026-08-09) — a defect case
  where a bare-name `SendMessage` reached an idle reviewer session from an
  unrelated spec/plan, causing that session to perform a genuine review and
  write a conflicting marker for a different unit. Motivated the "Reviewer
  re-tasking discipline" rule: a different unit always requires a fresh `Agent`
  dispatch (writing its own review-join stamp), never a message-resume. See
  `agents/orchestrator.md:137` and the history at commit `b9764de` (unit #311).

**Microworld bundles (format and the check contract)**:
(unit #314, 2026-08-10) — the canonical protocol section defining
  microworld-bundle format, execution contract, and hand-ported adapter
  sections. Terminology renamed: "microworld" now means the **dashboard entry**
  a human explores; the gitignored directory + its `run.sh` is now called the
  "**microworld bundle**". See `templates/persona-protocol.md` section
  `## Microworld bundles` and related entries below.

**Microworld bundle**:
(unit #314, 2026-08-10; refreshed unit #138, 2026-08-11) — the gitignored
  `microworlds/<unit-slug>/` directory holding a check's canonical definition:
  `manifest.json` (with `functions[]` array, `location`, `watch`,
  `timeoutSeconds`, `inputs/`, `expected/` paths), `run.sh` (the entry-point
  executable), and `README.md`. Ship-time output of a spec/lead-programmer
  unit; consumed at review time and rendered into a dashboard entry for human
  exploration by the **Microworld dashboard** (built unit #322). **Gitignored
  scratch**: never committed, destroyed by `git clean -fdx` or a fresh clone,
  expected to be absent in CI and fresh checkouts. Distinct from the rendered
  **Microworld** (the UI), **function entry** (an individual named executable
  in the bundle's `functions[]`), and the **escalation packet** (a durable,
  untracked snapshot of this bundle made at escalation time, since this bundle
  itself is not durable).

**Microworld**:
(unit #314, 2026-08-10, forward-looking; dashboard built unit #322, 2026-08-11;
  refreshed unit #138, 2026-08-11) — the rendered dashboard entry a human
  explores, showing inputs/outputs and invocation history for a unit's work,
  rendering the canonical definition from a **microworld bundle**. Rendered by
  the **Microworld dashboard** (the server/UI process as a whole — see that
  entry). Distinct from **microworld bundle** (the gitignored
  `microworlds/<unit-slug>/` directory) and from **Microworld dashboard** (the
  process rendering this entry, not the entry itself).

**Function entry**:
(unit #314, 2026-08-10) — a named, invocable executable declared in a
  **microworld bundle**'s `functions[]` array in `manifest.json`. Each entry
  defines the executable name, location (relative path), optional watch list,
  timeout, and input/expected paths. One bundle may declare many function
  entries; each corresponds to an executable the lead-programmer or reviewer
  can invoke during development and validation.

**The check**:
(unit #323, 2026-08-11) — the prose noun for a **microworld bundle**'s
  `run.sh`: the sole, machine-facing, exit-code contract consumed by the
  `reviewer` (filesystem-presence check only, never executed) and the
  `microworld-rerun.sh` **Reporter** hook (0 = pass, non-zero =
  fail/timeout, logged to the **Microworld audit log**). Contrast with
  **Function entry**: the check is the one asserting entry point a bundle
  has, and the only thing any gate or hook may ever consult; a function
  entry is a non-asserting, human-invoked probe whose exit code carries no
  verdict (`POST /api/invoke` never inspects it). The **Microworld
  dashboard** renders function entries for human exploration but never
  runs or displays the check's own exit code as a verdict — the dashboard
  is a human-facing exploration surface and **never an acceptance criterion**: 
  no hook registers it, no gate consults it, and no acceptance criterion in 
  this or any future spec may name it. `run.sh`
  keeps its filename; only the prose noun "the check" is new (Open
  Question 5, 2026-08-10) — there was never a file rename.

**Function location**:
(unit #323, 2026-08-11) — a **function entry**'s optional `location`
  field in `manifest.json` (`{ file, startLine, endLine }`), naming where
  in the repo the code that function entry exercises actually lives. Contrast
  with the **code-review graph** (`explorer`'s MCP-backed structural index,
  which auto-updates on every file change via hooks): `location` is a static,
  hand-authored pointer with an accepted stale risk. Author-declared by
  `lead-programmer` at bundle-authoring time; consumed by the dashboard's
  **Source excerpt** pane (`GET /api/source`) and copied verbatim into a
  **Feedback block**'s metadata lines, or the literal string `location: not
  declared` when absent. A `location.file`/`startLine`/`endLine` can silently
  go stale when code moves (R9, `docs/plans/2026-08-10-microworld-dashboard.md`),
  and nothing revalidates it automatically. Mitigation, not a fix: a copied
  feedback block carries the commit SHA at copy time, so a receiving agent can
  re-derive the real location.

**Relocatable run.sh**:
(unit #132, 2026-08-10) — a **microworld bundle** requirement and proven
  property: the bundle's `run.sh` must behave identically whether invoked
  from inside `microworlds/<unit-slug>/` or copied elsewhere (e.g. into a
  future escalation packet). File paths reach `run.sh` as a single positional
  parameter, never `eval`-interpolated, enforcing safe path injection. This
  property is proven executably by test cases (gh132 `tests/microworld/microworld-rerun.test.sh`
  cases (f)/(f2)), not merely assumed — a dependency for Step D8 (microworld escalation)
  in the separate dashboard plan.

**Watch globs**:
(unit #137, 2026-08-15) — the set of glob patterns in a **microworld bundle**'s
  `manifest.json` `watch` array that determines whether a source file edit
  is relevant to that bundle and should trigger the **reactive rerun hook**.
  Authored by `lead-programmer` at bundle creation time; consumed by the
  `microworld-rerun.sh` hook on every `PostToolUse` operation (`Write`/`Edit`).
  A bundle with an empty or absent `watch` array triggers on no edits; a bundle
  with `watch: ["src/**/*.ts"]` triggers only when edits match that glob.

**Reactive rerun hook**:
(unit #137, 2026-08-15) — the `PostToolUse` hook (`hooks/scripts/microworld-rerun.sh`)
  that monitors source-file edits and automatically reruns **microworld bundles**
  whose **watch globs** match the changed file. Invoked after every `Write` or
  `Edit` operation; queries the bundle manifest's `watch` array and reruns `run.sh`
  if any edit path matches. Results logged to the **Microworld audit log** with
  exit code, duration, and any infrastructure failures. Fail-open by design: even
  if rerun fails (timeout, missing `run.sh`, jq failure), it surfaces stderr to
  the model but never blocks the edit itself.

**Escalation packet**:
(unit #131, 2026-08-10, mechanism defined in unit #133, 2026-08-10; refreshed
  unit #138, 2026-08-11) — a directory structure created when a reviewer
  signals `ESCALATE-TO-HUMAN` on a unit, containing a snapshot of the unit's
  microworld bundle (if any) plus a durable `PACKET.md` file, a
  `CHANGES.md` **literate change summary** (unit #299), and `EXAMPLES.md`'s
  **worked example** illustrations (unit #300, renamed from the retired
  **comprehension quiz** in the 2026-08-20 quiz-to-worked-examples plan).
  Written by the
  reviewer in the same action as the `.escalated` marker, sited at
  `.claude/human-review/<task-id>/` (distinct from the reviewed-markers
  directory). The `PACKET.md` is a byte-identical copy of the `.escalated`
  marker body (marker remains authoritative on divergence); a unit with no
  bundle still receives a packet directory containing `PACKET.md` and
  `CHANGES.md` alone.
  Packets sit outside the reviewed-markers directory by design:
  `hooks/scripts/reviewed-path-gate.sh` blocks execution of anything under
  that path for non-reviewer callers, making a packet sited there unrunnable
  by the orchestrator or a human. Distinct from the working **microworld
  bundle** (gitignored, local, may be gone by the time a human reads it) — the
  packet exists precisely because bundles are gitignored. Untracked in
  `.gitignore`, so escalated packets are destroyed **unrecoverably** by
  `git clean -fdx` or a fresh clone — the commit SHA recorded in the paired
  `.escalated` marker does not help, since that marker is itself gitignored
  and never enters git history (documented, not fixed; see ADR 0017 § R10).
  Consumed by the **DECISION channel** (unit #325 human-decision gate, unit
  #326 escalation-laundering close, unit #136/#324 reviewer transcription) to
  route units to human review — landed, not a forward-looking mechanism.
  Deleted by the reviewer in the same action that resolves the escalation.

**Resolved packet**:
(unit human-review-cleanup-1, 2026-08-24) — a state of an [[Escalation packet]]
  defined by the presence of a non-empty `DECISION` file whose first line reads
  `DECISION <task-id> ...` where `<task-id>` matches that packet's directory name.
  The **packet-only** deletion operation `bin/human-review-cleanup.sh` targets only
  resolved packets, distinct from the reviewer's existing cleanup (which deletes both
  marker and packet). Packets transition to this state when a human decision is written
  to resolve an escalation. Packets in this state are safe to delete because their
  DECISION resolution has already been transcribed into the corresponding `.pass` marker.

**Pending packet**:
(unit human-review-cleanup-1, 2026-08-24) — a state of an [[Escalation packet]]
  defined by the absence of a `DECISION` file, or the presence of a `DECISION` path
  that is unreadable, non-regular (e.g. a directory or FIFO), malformed, or mismatched
  (first line not matching `DECISION <task-id> ...`). Such packets are left
  untouched by the **sweep** operation `bin/human-review-cleanup.sh`,
  which only deletes [[Resolved packet|resolved packets]]. Packets remain in this
  state while awaiting human review and decision. Distinct from the reviewer's existing
  cleanup mechanism (which deletes both marker and packet when escalation is resolved
  via the [[DECISION channel]]); the sweep is a supplementary manual operation for
  orphaned/leftover packets (e.g. after a crash).

**Sweep**:
(unit human-review-cleanup-1, 2026-08-24; broadened unit #409, 2026-08-25) — the
  operation performed by `bin/human-review-cleanup.sh`: a retention-gated pass
  over five artifact classes in `.claude/`, identifying and deleting stale items
  in each. Sweeps: (1) [[Resolved packet|resolved packets]] from `.claude/human-review/`,
  (2) reviewed markers (`.claude/reviewed/*.pass`, `.claude/reviewed/*.fail`, etc.),
  (3) **session baselines** — `.claude/baseline-*.json` files, distinct from [[session baseline commit]] —
  (4) WIP handoffs (`.claude/wip-handoff-*.json` files), and (5) **log rotation** (see
  [[Log rotation / archive]]) on append-only audit logs. Runs in dry-run mode by
  default (reporting what would be deleted), with `--apply` flag to perform actual
  deletion. Items 1-4 are retention-gated; item 5 (logs) rotates unconditionally
  since they are append-only and in active use. Distinct from the reviewer's own
  cleanup mechanism (which deletes both marker and packet during escalation
  resolution). Cross-references: [[Escalation packet]], [[Resolved packet]],
  [[Pending packet]], [[Log rotation / archive]].

**Log rotation / archive**:
(unit #409, 2026-08-25) — the mechanism in `bin/human-review-cleanup.sh:187-196,209-212`
  that archives append-only audit logs (`.claude/review-audit.log`, `.claude/dispatch-audit.log`,
  `.claude/microworld-audit.log`, `.claude/wip-audit.log`) as part of the
  **Sweep** operation. Archive filename shape: `<log>.<UTC-compact-timestamp>[.N]`,
  where the timestamp is ISO-8601 compact format (`YYYYMMDDTHHMMSSz`) and the
  `.N` counter suffix (e.g. `.1`, `.2`) appears only on same-second collision to
  prevent clobbering when multiple `--apply` runs occur within the same second.
  Rotation is unconditional (not retention-gated) because these logs are
  append-only and in active use; their mtime is always recent and retention
  gating would block rotation. Advisory note: archives are unswept by any
  retention gate, so they may accumulate indefinitely; this is a known gap in
  the artifact-leaking prevention (unit #409, non-blocking observation).
  Cross-references: [[Sweep]], [[Microworld audit log]].

**ESCALATE-TO-HUMAN**:
(unit #133, 2026-08-10; refreshed unit #138, 2026-08-11) — the fourth reviewer
  verdict, signaling that a unit the reviewer would otherwise pass requires
  human review before a final decision. Verdict precedence is: `FAIL` >
  `INSUFFICIENT-CONTEXT` > `ESCALATE-TO-HUMAN` > `PASS`. Escalation gates PASS
  (only a unit the reviewer would have passed escalates), never replaces FAIL,
  and is never a substitute for `INSUFFICIENT-CONTEXT` (unverifiable criteria
  are that, not this). Marked via `.escalated` marker file under
  `.claude/reviewed/`. Always paired with an escalation packet (see
  [[Escalation packet]]). Triggers when `humanReviewMode` is `all`, or is
  `critical` (the default when the key is absent) and the unit meets the
  heavy-unit trigger — see [ADR 0004](docs/adr/0004-reviewer-roast-work-dual-model-routing.md)
  § "Heavy unit trigger", as amended by [ADR 0013](docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md)
  (not restated here). Resolved via the **DECISION channel** (landed at unit
  #325/#326/#136) through one of three terminal transitions (approve, reject
  with reason, direct with a prescribed fix), each deleting the `.escalated`
  marker and its packet. Never consumes a 2-FAIL-cap slot.

**`.escalated` marker**:
(unit #133, 2026-08-10; refreshed unit #138, 2026-08-11) — file written by the
  reviewer at `.claude/reviewed/<task-id>.escalated` when issuing an
  `ESCALATE-TO-HUMAN` verdict, carrying the marker body as fixed-shape text.
  First line: `ESCALATE-TO-HUMAN <task-id> <UTC ISO-8601 timestamp> trigger:
  <criterion> microworld: <packet path or "none">`. Followed by the packet's
  `run.sh` invocation, `commit: <sha>` (see [[Commit attribution]] — this field is copied verbatim during approval), inputs/expected-outputs description,
  the would-be verdict and criteria checked, and non-blocking notes. Distinct
  from `.blocked` (reviewer *lacked context* to verify a criterion) — this
  marker means *policy requires human eyes* on critical code instead: separate
  marker files, **distinct audit tokens** (`.blocked` logs `verdict=blocked
  flags-kept`; `.escalated` logs `verdict=escalated flags-kept`). Authoritative
  over the paired [[PACKET.md]] on divergence. Kept standing until a human
  decision via the **DECISION channel** resolves the escalation, at which
  point both marker and packet are deleted in the same reviewer action.

**`.directed` marker**:
(unit #136, 2026-08-11, Step 7 of the human-decision-channel fix, issue #324) —
  file written by the reviewer at `.claude/reviewed/<task-id>.directed` when
  transcribing a human `route: direct` [[DECISION file]] resolution. First line
  byte-exact: `DIRECTED <task-id> <UTC ISO-8601 timestamp> fix: <one-line human
  directive>`, followed by the human's full prescribed fix verbatim from the
  DECISION body. Contrast with `.blocked` and `.escalated`: both of those keep
  the unit's pending-review flag standing at the reviewer's SubagentStop, so
  `stop-gate.sh` keeps blocking further progress until resolved — `.directed`
  is DELIBERATELY absent from that same glob check, since its whole purpose is
  the opposite: letting the human-directed fix actually get dispatched to
  `lead-programmer` for a normal re-review, not freezing the unit. Does NOT
  consume a 2-FAIL-cap slot — same logic as `INSUFFICIENT-CONTEXT`: it is a
  human-directed correction, not lead-programmer failing on its own. Deleted
  by the reviewer in the same action as the next resolution once re-review
  completes.

**Staleness binding**:
(unit #136, 2026-08-11, Step 7 of the human-decision-channel fix, issue #324) —
  the rule that a [[DECISION file]]'s `escalation:` timestamp field must
  exactly equal the standing `.escalated` marker's own first-line timestamp
  before the reviewer will transcribe the DECISION into a resolution. Defined
  in `templates/persona-protocol.md`'s "Resolving an escalation" section: the
  reviewer checks the task-id matches and this timestamp equality holds; on a
  missing, malformed, or stale `DECISION`, it reports and waits rather than
  transcribing. Ties a given human decision to the one specific escalation
  event it was written in response to, so a DECISION file left over from an
  earlier escalation of a unit cannot resolve a later, different escalation of
  that same unit.

**PACKET.md**:
(unit #133, 2026-08-10; refreshed unit #138, 2026-08-11) — file written by the
  reviewer inside the escalation packet directory
  (`.claude/human-review/<task-id>/PACKET.md`) as a byte-identical copy of
  the `.escalated` marker body. Exists to allow the packet to be consulted outside the
  reviewed-markers directory (which is blocked by `reviewed-path-gate.sh` for non-reviewer
  callers). The `.escalated` marker remains authoritative; if the two diverge, the marker
  is correct. Consumed by the **DECISION channel** (landed at unit #325/#326/#136)
  when routing escalated units to human review.

**literate change summary**:
(unit #299, 2026-08-15, Step 10 of the human-review convergence follow-ups) —
  the `CHANGES.md` file the reviewer writes into the escalation packet
  directory (`.claude/human-review/<task-id>/CHANGES.md`) in the same action as
  the `.escalated` marker and [[PACKET.md]]. Explains **the change** to the
  human who must now judge it, so they do not start from a raw alphabetically
  ordered diff. Fixed four-section shape, asserted by exact-heading greps rather
  than trusted to prose: `## Background`, `## What this change is for`,
  `## Walkthrough` (the diff in conceptual order, one subsection per idea —
  explicitly **not one subsection per file**, and not alphabetical), and
  `## What to look at first`. Quotes the diff, never reproduces it; soft cap 120
  lines. First line byte-exact:
  `Comprehension material only — the .escalated marker is the authoritative record.`
  Contrast with [[PACKET.md]], the near-synonym it is easiest to confuse it
  with: `PACKET.md` is a *copy of the decision record* (byte-identical to the
  marker body), while this is an *explanation of the change* and carries no
  verdict at all. Neither is authoritative — the `.escalated` marker is. Written
  **after** the would-be verdict is reached and never gates or influences it. A
  unit with `microworld: none` still receives one, and there it is the entire
  human-facing payload. Deleted with the rest of the packet in all three
  terminal routes of the **DECISION channel**, in the same reviewer action.
  Defined in `templates/persona-protocol.md`'s
  "Fourth verdict: escalate-to-human" section.
_Avoid_: change summary, walkthrough doc, CHANGES doc (use "literate change
  summary", or name the file `CHANGES.md` directly)

**comprehension material**:
(unit #299, 2026-08-15) — a standing designation for explanatory or reference
  material that aids understanding but carries no authority or decision weight.
  Marked in byte-exact authority lines: "Comprehension material only — the
  .escalated marker is the authoritative record." Used in both [[PACKET.md]]
  and the [[literate change summary]] to signal that these derived documents
  (explaining the change or carrying decision metadata) do not decide anything —
  the `.escalated` marker alone is authoritative. The phrase appears at the head
  of both documents' content. Never conflate with authoritative decision records;
  comprehension material is explanatory only.
_Avoid_: reference material, explanatory material, supporting material (use "comprehension material")

**comprehension quiz**:
**[Retired in 0.31.62; see worked example below.]**
(unit #300, 2026-08-15, Step 11 of the human-review convergence follow-ups) —
  the `QUIZ.md` / `QUIZ-ANSWERS.md` pair the reviewer writes into the escalation
  packet directory (`.claude/human-review/<task-id>/`) in the same action as the
  `.escalated` marker, [[PACKET.md]], and the [[literate change summary]].
  `QUIZ.md` carries 3 to 5 questions, each answerable from `CHANGES.md` and the
  bundle alone and each about **consequence rather than recall** (*"what happens
  to X when Y is absent?"*, never *"what is the new function called?"* — a
  recall question is answerable by skimming); `QUIZ-ANSWERS.md` carries the
  reviewer's answer key, deliberately in a **separate file** so the human can
  attempt the questions before self-checking. A *speed regulator*, not a test:
  it exists because the approve route is the only one of the DECISION channel's
  three a human can complete without demonstrating engagement (reject needs a
  reason, direct needs a directive, approve needs only a name).
  **Self-administered, recorded, and never graded by the reviewer — and never a
  gate.** The reviewer sets the questions and the key and stops there: it never
  reads the human's answers, never marks them, and never conditions a verdict,
  marker, or route on them, because a reviewer that could mark a human wrong and
  withhold approval would re-adjudicate the human (R6). What is recorded is one
  required `quiz:` token on the `.pass` marker's appended `human:` attestation
  line — exactly one of `quiz: passed-self-check`, `quiz: skipped`, or
  `quiz: none-offered` (that last only when no `QUIZ.md` was written), stated by
  the human as a `quiz: <token>` body line in the [[DECISION file]] and
  transcribed by the reviewer. **`quiz: skipped` is a first-class legitimate
  outcome**: it must not block, warn, or be retried, and an absent `quiz:` line
  transcribes as a skip rather than stalling — naming only the success token
  would build a gate by omission. The token rides on the *appended* attestation
  line, never the marker's required first line, so it cannot affect
  `task-gate.sh`'s `marker_valid()` (PASS marker format v3). Offered on the
  **approve route only**. Both files are deleted with the rest of the packet in
  all three terminal routes, in the same reviewer action. Defined in
  `templates/persona-protocol.md`'s "Fourth verdict: escalate-to-human" section.
_Avoid_: quiz gate, comprehension check, reviewer quiz (it is neither a gate nor
  the reviewer's check on the human — use "comprehension quiz", or name
  `QUIZ.md` / `QUIZ-ANSWERS.md` directly)

**worked example**:
(units #299/#300 renamed 2026-08-20, examples-1/2/3 of the
  quiz-to-worked-examples plan) — a subtype of [[comprehension material]],
  alongside the [[literate change summary]], and the replacement for the
  retired **comprehension quiz** above. `EXAMPLES.md` carries **3 to 5 worked
  examples**, each a **behavioural before/after** ("before this change, X did
  Y; after, X does Z"), each grounded in `CHANGES.md` and the bundle alone,
  and each about **consequence rather than recall** (*"what happens to X when
  Y is absent?"*, never *"what is the new function called?"*).
  **When needed.** Written whenever the change has an **observable
  behavioural consequence**; skipped for changes with no behavioural surface —
  pure docs, formatting, comments, pure renames. **Auditable skip:** the
  `.escalated` marker body carries one `examples:` line — `examples: <count>`
  when `EXAMPLES.md` was written, or `examples: none — <one-line reason>`
  when it was not, so a skip is a written record rather than a silent
  absence. [[PACKET.md]], a byte-identical copy of the marker body, inherits
  this line automatically.
  **Self-administered, recorded, and never graded by the reviewer — and never
  a gate.** The reviewer writes the worked examples and stops there: it never
  reads, judges, or scores the human's engagement with them, and never
  conditions a verdict, marker, or route on them — a reviewer that could mark
  a human's engagement wrong and withhold approval would re-adjudicate the
  human (R6). Authored **after** the would-be verdict is settled, never gating
  or influencing it. What is recorded is one required `examples:` token on the
  `.pass` marker's appended `human:` attestation line — exactly one of
  `examples: reviewed`, `examples: skipped`, or `examples: none-offered` (that
  last only when no `EXAMPLES.md` was written), stated by the human as an
  `examples: <token>` body line in the [[DECISION file]] and transcribed by
  the reviewer. **`examples: skipped` is a first-class legitimate outcome**:
  it must not block, warn, or be retried, and an absent `examples:` line
  transcribes as a skip rather than stalling — naming only the success token
  would build a gate by omission. The token rides on the *appended*
  attestation line, never the marker's required first line, so it cannot
  affect `task-gate.sh`'s `marker_valid()` (PASS marker format v3). Offered on
  the **approve route only** — reject-with-reason and direct-a-fix already
  carry evidence of engagement. `EXAMPLES.md` is deleted with the rest of the
  [[Escalation packet]] in all three terminal routes, in the same reviewer
  action. Defined in `templates/persona-protocol.md`'s "Fourth verdict:
  escalate-to-human" section.
_Avoid_: example, sample, demo, examples quiz (none of these name the
  behavioural-illustration concept precisely — use "worked example", or name
  `EXAMPLES.md` directly)

**humanReviewMode**:
(unit #133, 2026-08-10, forward-looking; shipped unit #135, 2026-08-11;
  refreshed unit #138, 2026-08-11) — configuration field in
  `.claude/persona-config.json` (or the adapted equivalent path) controlling
  when `ESCALATE-TO-HUMAN` verdicts fire. Declared in
  `templates/persona-config.schema.json` with `enum: ["off","critical","all"]`
  and `default: "critical"` (on by default). Read by the reviewer persona
  (`agents/reviewer.md`): an **absent key or any unrecognised value** both
  resolve to `critical` (fail toward escalation, never toward silent
  auto-approval); only `off`, spelled exactly, disables escalation entirely.
  `all` escalates every unit; `critical` escalates only units meeting the
  heavy-unit trigger (ADR-0004 § "Heavy unit trigger", as amended by
  ADR-0013). When `reviewer` is absent from `personaSelection`, the escalation
  path is inert regardless of the mode. The on-by-default posture is encoded
  as this absent-key fallback in the consumer, not in the `bin/cli.js`
  `--update` backfill path — the backfill deliberately leaves an
  already-adapted project's existing config untouched, so encoding the
  default there instead would have silently left every existing user opted
  out. This repo's own config ran the [[bootstrap window]] override
  (`humanReviewMode: "off"`) only until the human-decision resolution channel
  landed at unit #136; the live value returned to `critical`, the same as any
  other adapted project, at that point. **Superseded 2026-08-16** by Step 1
  of the ceremony-reduction plan: this repo's config now runs
  `humanReviewMode: "off"` again, this time as a permanent [[solo-operator
  posture]], not a bootstrap window — see that entry and
  [ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md).

**bootstrap window**:
(unit #135, 2026-08-11; closed unit #136/#138, 2026-08-11) — a temporary,
  deliberate, and committed config override held open to let a fix batch's own
  units land without recursively triggering a resolution mechanism those same
  units are still building. Concrete instance (now closed): this repo's own
  `.claude/persona-config.json` held `"humanReviewMode": "off"` rather than
  `"critical"` (see [[humanReviewMode]]) while the human-decision resolution
  channel (amended #136, Step 7) had not yet landed — with the default
  `critical` mode live, the fix batch's own heavy-unit changes (hook code,
  security-sensitive) would each have escalated into a route that did not yet
  exist. Defined and tracked in `docs/plans/2026-08-11-human-decision-channel.md`
  Step 4.1. Closed (override reverted to `critical`) once the decision channel
  landed at unit #136 — restoration ownership was a plan/runbook tracking
  concern, not implied by the term itself, and is recorded here as complete.
_Avoid_: temporary override, escape hatch (use "bootstrap window" for this specific,
  documented, plan-tracked pattern)

**`.claude/human-review/` (human-review directory)**:
(unit #131, 2026-08-10) — the gitignored directory path within the claude adapter
  reserved for escalation packets. Parallel directories exist for other adapters:
  `.cursor/human-review/`, `.codex/human-review/`. The directory is preemptively
  ignored in `.gitignore` (matching the pattern `**/human-review/` in the claude adapter
  case, or adapter-specific equivalents) to prevent committed artifacts. Packages created
  at this location by the reviewer when issuing an `ESCALATE-TO-HUMAN` verdict (see
  [[Escalation packet]]).
_Avoid_: review directory, human review folder (use "human-review directory" with the
  dot-path for clarity about adapter specificity)

**Document pane**:
(unit #322, 2026-08-11; terminology recorded unit #400, 2026-08-18) — a
  content pane in the **Microworld dashboard** that displays rendered markdown
  (e.g., a documentation excerpt or a literate change summary), distinct from a
  **verbatim pane** (which displays clipboard-destined text unchanged, such as
  a composed command or a source-code excerpt). The dashboard renders five
  document panes via `renderMarkdown`: (1) Escalation `CHANGES.md` body, (2)
  Escalation `PACKET.md` body, (3) Escalation `EXAMPLES.md` body (renamed from
  the retired `QUIZ.md` body and `QUIZ-ANSWERS.md` lazy reveal, which the
  2026-08-20 quiz-to-worked-examples plan collapsed from two panes into one and
  removed the lazy-fetch reveal entirely), (4) Briefing / plan-doc excerpt, and
  (5) Milestone findings `finding.body`. The six verbatim panes (composed commands,
  paste-back blocks, `defer`/`skip` commands, source-code excerpts, and notebook
  stdout/stderr cells) use `escapeHtml` and remain byte-identical to their
  source. Naming note: the `Review` rail-section header uses "review" in a
  UI-grouping sense (artifacts awaiting human attention) distinct from the
  `reviewer`-verdict sense (the PASS/FAIL marker role) used elsewhere in this
  glossary — the two meanings now coexist in this codebase and are disambiguated
  here to prevent silent confusion by a future reader.

**Markdown-lite renderer**:
(unit #401, 2026-08-18) — the module at `bin/microworld-dashboard/markdown-lite.js`,
  a vendored, dependency-free, dual-environment markdown renderer that works both
  as a CommonJS `require()`-able module (for unit tests) and injected verbatim as
  a browser global (for page rendering). XSS-safe via escape-first design: every
  text span is escaped before the renderer wraps it in a fixed, renderer-generated
  tag set, so raw inline HTML in the markdown source can never reach the page as
  markup. Supports: headings (`#`..`######`), bold, italic, inline code, fenced
  code blocks, unordered and ordered lists, blockquotes, links, horizontal rule,
  paragraphs. Link `href`s are restricted to `http:`, `https:`, or relative
  targets; `javascript:` and other schemes render as plain text with no anchor
  emitted. Non-string input fails closed (returns a string, never throws, never
  emits markup from coercion). Covers the construct set attested by
  `tests/microworld/dashboard-markdown-lite.test.js`, not by design assumption — verify
  against shipped test cases, not by re-reading this entry.

**Microworld dashboard**:
(unit #314, 2026-08-10, forward-looking; built and documented unit #322,
  2026-08-11) — the loopback-only HTTP server/UI process itself, started via
  `node bin/cli.js --dashboard` (nothing auto-starts it), that lets a human
  browse and invoke **microworld bundles** without manual CLI invocation. Binds
  to `127.0.0.1` on an ephemeral port; every request requires a per-launch
  token via `?t=<token>` or `X-Antislop-Token` (see `server.js:21`/`:45-47`).
  Writes the **DECISION file** and appends a line to the review audit log
  (`.claude/review-audit.log`, `server.js:533`), only when a human submits an
  escalation-decision form with a **confirmation code** delivered over the
  controlling terminal (see [[confirmation code]]). Invocation results live only
  as ephemeral, in-page **Cell**s. The dashboard cannot be started without a
  controlling terminal, except via the `--dashboard-no-tty` flag, which starts
  it in [[read-only mode]] — refusing both bundle invocation (`/api/invoke`) and
  decision writes (`/api/decision/*`). This launch-mode split exists because the
  launch token is an [[execution credential]], not a read credential. Documented in
  `README.md`'s "Microworld dashboard" section (`README.md:263`). Distinct from
  **Microworld** (an individual bundle's rendered dashboard entry a human
  explores) and **Microworld bundle** (the gitignored `microworlds/<unit-slug>/`
  directory the dashboard renders) — this entry is the process/UI as a whole,
  the other two are what it displays.
  Also distinct from the `microworld-rerun.sh` **Reporter** hook (see that
  entry and **Microworld audit log**): the dashboard is the standing,
  human-facing viewer a user starts and stops; the reporter is the
  synchronous, per-edit machine process that never renders anything a
  human sees, and never gates on the dashboard's behalf. (Naming note: a
  new headword "microworld rerun hook" was considered and rejected for
  this contrast — see this plan's D10 "Rerun-hook naming decision" — to
  avoid minting an avoidable synonym for the already-named reporter.)
  The left rail is organized into three sections, each header carrying a count
  and displayed only when non-empty: `Review (N)` contains escalations, packet
  bundles, findings, and pending-review flags; `Plans & Specs (N)` contains
  briefings (plan-doc entries); `Microworlds (N)` contains working bundles.
  Packet bundles within the Review section are prefixed with `Packet: ` in their
  row title, a UI abbreviation of the canonical **escalation packet** term.
_Avoid_: "the dashboard" alone in glossary cross-references now that this
  entry exists — link explicitly to disambiguate from the individual
  **Microworld** entry (dashboard *entries*) and **D5 browser client**
  (the specific static-HTML implementation of this process's UI).

**Microworld silo**:
(plan `docs/plans/2026-08-11-microworld-silo.md`, Step 6, 2026-09-04) — the
  namespaced-directories-plus-canonical-index shape the microworld feature
  area occupies: code under `bin/microworld-dashboard/`, tests under
  `tests/microworld/`, the reporter hook staying at
  `hooks/scripts/microworld-rerun.sh` (hooks are located by `hooks.json`
  registration, not by feature area), and docs/ADRs staying in their
  standing homes, all tied together by the canonical index at
  `docs/microworld/README.md`. Decided over two rejected alternatives — a
  full physical silo (would desynchronize the hook's tracked and adapter
  mirrors) and leaving everything flat (a `microworld` grep would still miss
  the old *bin/dashboard/*) — see `docs/adr/0029-microworld-silo-namespaced-directories.md`.
  Distinct from the **Microworld dashboard** (the process/UI the silo's code
  half implements), the **Microworld bundle** (the gitignored per-unit
  artifact the dashboard renders), and the **Reporter** (the hook that stays
  outside the silo by design). See [[Microworld dashboard]], [[Microworld
  bundle]], [[Reporter]].
_Avoid_: "the dashboard directory" — ambiguous between the silo as a whole
  and `bin/microworld-dashboard/` specifically; name the path or say "the
  microworld silo".

**confirmation code**:
(unit #377, Step 7, 2026-08-31) — the per-decision, time-limited code delivered
  over the controlling terminal (`/dev/tty`) during a **Microworld dashboard**
  escalation-decision write. Generated when a human arms a decision form (via
  `/api/decision/arm`); must be entered into the confirm step to complete the
  write (via `/api/decision/run`). Time-to-live is 120 seconds; the code cannot
  be reused and expires after one confirmation attempt. Exists to make the
  decision-write flow unmistakably intentional (a deliberate, terminal-confirmed
  action) rather than something an HTTP request alone could trigger. Distinct
  from the **DECISION file**'s body content; the confirmation code gates the
  ability to write, not the file's semantic contents. See [[Microworld dashboard]],
  [[dashboard-originated decision write]], and [[DECISION file]].

**Bundle source**:
(unit #315, 2026-08-10; `"packet"` value implemented unit #321, 2026-08-11) —
  the `source` field in a microworld bundle object, indicating the origin of
  the bundle. Defined values: `"working"` for bundles enumerated from the
  local `microworlds/` directory (trust boundary: subject to repo-own
  validation, same trust domain as the repository itself); `"packet"` for
  bundles enumerated from `.claude/human-review/` **escalation packets** (see
  [[Escalation packet]]) — a distinct trust posture, since a packet is a
  snapshot written at review time, not a live bundle. A `source: "packet"`
  bundle's `status` is always `null` in `GET /api/bundles`: `discoverPackets()`
  does not consult `bin/microworld-dashboard/audit-log.js`'s live rerun-status parsing,
  so packets render as a static snapshot with no pass/fail/timeout indicator,
  unlike `source: "working"` bundles.
_Avoid_: bundle origin (use "bundle source" for clarity); "working bundle" as
  a synonym for the gitignored `microworlds/<unit-slug>/` directory itself —
  that directory is the canonical **microworld bundle** (see entry above);
  "working" is only the `source` field's value when a bundle of that kind is
  discovered. `tests/microworld/dashboard-packets.test.js`, `bin/microworld-dashboard/index.html`'s
  "Working Bundles" section header, and `CHANGELOG.md` all use "working
  bundle" informally as UI/test shorthand for "a microworld bundle with
  `source: "working"`" — acceptable as a UI label, but do not treat it as a
  second glossary term.

**Bundle id namespace**:
(unit #315, 2026-08-10; `packet:` namespace implemented unit #321, 2026-08-11)
  — the prefix scheme for **microworld bundle** ids, enabling collision-free
  routing of bundles from different sources. Defined values: `working:<dirSlug>`
  for bundles discovered from local `microworlds/<dirSlug>/` directories;
  `packet:<task-id>` for bundles discovered from `.claude/human-review/<task-id>/`
  **escalation packets**. The directory/task-id slug (not the manifest's
  `unit` field) is used in both namespaces to establish a stable,
  collision-resistant canonical id. Distinct from the **source** field: a
  bundle's `id` is namespaced (machine routing), while `source` is the
  semantic origin marker (human understanding / trust boundary). Unit #317
  added a `dirSlug` field to discovered bundle objects, holding the canonical
  directory slug `server.js` uses to resolve invocation paths; unit #321
  extends the same field to packet bundles (holding the task-id there),
  eliminating the discovery/invocation path-mismatch defect for both sources.
  **Collision design:** a `working:<slug>` and a `packet:<slug>` sharing the
  same slug (e.g. a unit that both has a local bundle AND was escalated) are
  distinct ids and coexist in `GET /api/bundles` without merging or shadowing
  each other — proven end-to-end at unit #321 review time with a live
  same-slug fixture pair (`microworlds/rev-probe/` and
  `.claude/human-review/rev-probe/`), both discovered and both independently
  invocable via `POST /api/invoke`.
_Avoid_: microworld namespace (too vague; specify "bundle id namespace" or "source namespace" to clarify)

**`POST /api/invoke` endpoint**:
(unit #317, 2026-08-10) — the security-sensitive dashboard endpoint spawning
  one **function entry** invocation with human-supplied inputs. Request body:
  `{ id, functionId, inputs: {<name>: <value>} }` (all required). Response:
  `{ ok, exitCode, stdout, stderr, durationMs, timedOut, truncated }`. Same
  token-auth contract as other dashboard routes (`?t=` query or
  `X-Antislop-Token` header; missing/wrong → 401). **Execution contract:**
  `child_process.spawn()` with argv array, never shell (`shell: false`).
  Inputs serialized to a single JSON object on child stdin (never command-line,
  never shell-interpolated). Environment: `MICROWORLD_BUNDLE_DIR` set to the
  bundle's absolute path. Timeout: `timeoutSeconds` from the manifest (default
  60); enforced via process-group kill (`detached: true` + `process.kill(-pid)`)
  with SIGKILL escalation at 500ms if SIGTERM doesn't land. Output: stdout/stderr
  each capped at 1 MiB; `truncated: true` flag if either stream exceeds cap.
  Non-blocking advisory notes: server-shutdown orphaning (long-running entries
  survive terminal Ctrl-C because child runs in its own pgid; cheap fix: track
  live pids and group-kill from `process.on('exit')`/SIGINT handler); path
  traversal via `manifest.entry` (pre-existing, measured at pre-fix commit, not a
  D4 defect because manifest is agent-authored local input inside trust domain;
  flagged as follow-up candidate for hardening via `fs.realpathSync` guard).

**D5 browser client**:
(unit #318, 2026-08-10) — the static single-file HTML client (`bin/microworld-dashboard/index.html`)
  for the microworld dashboard. Rewritten from D2 placeholder into the real client with
  inline `<script type="module">` (no framework/build step/CDN). Consumes only existing
  `GET /api/bundles` (D3/D4) and `POST /api/invoke` (D4) routes. **Left rail:** one entry
  per microworld bundle, live status indicator (pass/fail/timeout/unknown) polled every 5s
  via `setInterval`. **Nested tabs:** group tier → function tier within selected group;
  bundles with no `functions[]` show status + "no function entries declared" note.
  **Input form:** generated from `inputs[]` (string/number/json/file), `default` prefills
  (handles falsy defaults `0`/`false`/`""` via `!== undefined` check, not truthy check),
  `description` labels. **Output pane:** stdout/stderr/exit code/duration, explicit
  banners for `timedOut`/`truncated`. Exit code rendered neutrally (no verdict color).
  **Empty state:** names what a microworld bundle is, path/files, origin; distinct from
  auth-error state. **HTML escaping:** `escapeHtml()` now escapes `"`/`'` in addition to
  `&`/`<`/`>`, applied to `data-*` id attribute interpolations for bundle/function ids
  (manifest-author-controlled, not scored as security issue given manifest is already in
  trust domain, but hardening captures the convention). **No server-side route added:**
  uses only D3/D4 endpoints. **Version:** 0.31.12 (original build), no version bump on
  fix pass.

**Feedback block**:
(unit #320, 2026-08-10) — the fixed-shape markdown artifact produced by the
  "Copy feedback" button on the microworld dashboard (per-function or per-cell),
  containing function id/group/location/commit/bundle/comment and, when copied
  from a cell, a `### Last run` section with cell execution metadata. Markdown shape:
  `## Microworld feedback — <unit-slug> / <function label>`, metadata lines (function id,
  group, location or "location: not declared", git SHA, bundle path), `### Comment`
  section (verbatim, user-entered text), optional `### Last run` section (cells only,
  never emitted with empty fields). Deliberately not named "handoff" (that term is
  reserved for an existing shipped skill/artifact). Distinct from **Source excerpt**
  (the dashboard's pane for reading source code).

**Source excerpt**:
(unit #320, 2026-08-10) — the bounded, root-confined, symlink-safe read of
  `location.file` lines `startLine..endLine` served by `GET /api/source`, rendered
  read-only in the dashboard's excerpt pane. Implemented via `fs.realpathSync.native`
  containment check (no symlinks escape the project root), returns 400 on path
  traversal attempt (absolute or relative `../`), returns 404 with stated reason
  on file/line errors. Distinct from **Feedback block** (the dashboard's copy button
  output artifact).

**Cell**:
(unit #319, 2026-08-10) — an in-page record of one `POST /api/invoke` result,
  storing `{ cellId, functionId, inputs, startedAt, result }`. Cells are appended
  (never overwritten) when a function is invoked; re-running the same function appends
  a new cell. Cells are never persisted to disk, localStorage, sessionStorage, or
  indexedDB — they exist only in-memory and are lost on page refresh. Each cell
  renders with controls to edit-and-re-run (prefilling the input form from the cell's
  stored inputs), collapse/expand its output, and remove it. The UI displays a
  permanent warning "each cell runs in a fresh process" to clarify that cell
  executions share no state. Distinct from **Notebook** (the per-function ordered
  list of cells).

**Notebook**:
(unit #319, 2026-08-10) — the per-function ordered list of **Cell** records rendered
  in the output pane of the microworld dashboard. Each function entry maintains its
  own notebook, keyed by `functionId` in the client-side state, and persists the list
  in-memory across tab switches but loses it on page refresh. Notebooks are purely
  client-side state; no server-side persistence or route. Distinct from **Cell**
  (a single invocation record).

**DECISION file**:
(unit #325, 2026-08-11, Step 1 of the human-decision-channel fix, issue #324;
  read and transcribed by the reviewer, Step 3/amended #136, 2026-08-11) —
  the human-written file at `.claude/human-review/<task-id>/DECISION`, inside an
  [[Escalation packet]] directory, carrying the human's resolution of a pending
  `ESCALATE-TO-HUMAN` escalation. The file is made agent-unwritable by **the
  human-decision gate** (see below); on a later re-dispatch the reviewer
  verifies it exists at the packet path, parses its first line, checks the
  task-id matches and the [[Staleness binding]] holds, then **transcribes** it
  — never re-reviews it — into one of three terminal routes (see [[DECISION
  channel]]). The DECISION file is the consent artifact: its unwritability by
  any agent identity is what makes its contents trustworthy as the human's own
  word, not an agent's paraphrase. A second, sanctioned authoring path exists via
  the **Microworld dashboard**: a human-driven, terminal-confirmed **dashboard-originated
  decision write** (see [[dashboard-originated decision write]]) that delivers
  the **confirmation code** over `/dev/tty` and writes the file with a `via:
  dashboard` line in the file body itself distinguishing it from the
  typed-terminal path (which carries no `via:` line at all); the write
  separately appends its own `decision-write-via-dashboard` line to the
  review audit log, which contains no `via:` token.

**The human-decision gate** (`human-decision-gate.sh`):
(unit #325, 2026-08-11, Step 1 of #324; extended units hdg-lexer-1, hdg-prose-2,
  hdg-prose-2-fix2, 2026-08-24) — the new `PreToolUse` hook (`Write|Edit` and
  `Bash` matchers) that blocks **every** agent identity from writing a [[DECISION
  file]] — reviewer included, empty/main-session `agent_type` included. Contrast
  with `reviewed-path-gate.sh`: that gate has a grant branch (the reviewer may
  write `.claude/reviewed/*.pass`, and a no-reviewer fallback exists for the main
  session or the orchestrator persona); this gate has no grant branch and no fallback — no identity may ever
  write a DECISION file, full stop. **Reads are allowed** in both gates, including
  read-only commands (e.g. `grep`, file read, stat), [[prose mention]]s of the
  protected paths in commit messages, **single-quoted patterns** in grep and other
  read commands, and trailing shell comments — but only when these represent
  inert mentions rather than write attempts (see the [[narrate-versus-target
  distinction]]).
  The two gates share their read-only/text-only command classifier, extracted in
  this same unit into `hooks/scripts/lib/benign-command.sh` (previously private to
  `reviewed-path-gate.sh`). The sanctioned way to discard a resolved escalation
  packet is `rm -rf .claude/human-review/<task-id>` (the whole directory) — its
  command text never spells `DECISION`, so it clears the gate's substring
  early-exit; a per-file `rm .../DECISION` is blocked for every identity, reviewer
  included, by design. No adapter port exists, the same precedent already set by
  `reviewed-path-gate.sh`.

**dashboard-originated decision write**:
(unit #377, Step 7, 2026-08-31) — a **DECISION file** write that originates from
  the **Microworld dashboard** server, as opposed to the classic path where a human
  types the file manually in their terminal. Characterized by two properties: (1) the
  write is gated on a human-entered **confirmation code** delivered over the
  controlling terminal (`/dev/tty`), ensuring the human is present and the action is
  intentional; (2) the written **DECISION file** carries a `via: dashboard` line in
  the file body itself (`decision-block.js:126`, fed by `server.js:362`) — not in
  the audit log, which instead gets its own, separate `decision-write-via-dashboard`
  line (`server.js:525`) with no `via:` token. Today only two `via:` states actually
  occur: **absent** (both the hand-typed-in-terminal path and the copy/heredoc
  dashboard path pass no `via` field, so `decision-block.js:122` omits the line
  entirely) and **`via: dashboard`** (the confirmed-write path above). `via:
  terminal` exists only as an unused entry in `decision-block.js`'s `VIA_ROUTES`
  allowlist — no current code path emits it. Both authoring paths satisfy the [[DECISION file]]'s "unwritable by any
  agent identity" property — the dashboard is not an agent identity, and the
  confirmation-code gate and TTY delivery mechanism enforce the same human-presence
  requirement as the terminal path, just via a different channel. Exists only when
  the dashboard is started with a controlling terminal (not `--dashboard-no-tty`);
  [[read-only mode]] explicitly refuses `/api/decision/arm` and `/api/decision/run`
  because the launch token is an [[execution credential]], not a read credential. See
  [[confirmation code]], [[Microworld dashboard]], and [[DECISION file]].

**execution credential**:
(unit #377, Step 7, 2026-08-31) — a credential that authenticates to both
  read-only and write/execute endpoints, not merely to read-only endpoints. The
  per-launch **Microworld dashboard** token is an execution credential: an agent
  holding it can read bundle listings *and* invoke (`POST /api/invoke`) or write
  decisions (`POST /api/decision/*`). This is why the dashboard cannot be started
  without a controlling terminal in the normal case — the token would otherwise be
  an easy hand-off to automation with full write access. When the dashboard is
  started with `--dashboard-no-tty` (**read-only mode**), the entire server becomes
  unreachable (not just write endpoints), closing the "scrape the token and POST"
  attack vector. See [[Microworld dashboard]], [[read-only mode]], and [[DECISION file]].

**read-only mode**:
(unit #377, Step 7, 2026-08-31) — the operational mode of the **Microworld dashboard**
  when started with the `--dashboard-no-tty` flag, blocking both bundle execution
  (`/api/invoke`, HTTP 403) and decision writes (`/api/decision/arm` and
  `/api/decision/run`, HTTP 403). Used in automation, CI, or container contexts where
  a human cannot be present and no controlling terminal is available. In this mode,
  the dashboard remains accessible for read-only browsing of existing microworld bundles,
  escalation packets, and review artifacts, but cannot modify state. Exists because
  the launch token is an **execution credential**, not a read credential — a mode that
  restricts read-only access prevents exposing the execution capability to automation.
  See [[Microworld dashboard]], [[execution credential]], and [[--dashboard-no-tty]].

**Escalation-laundering**:
(unit #326, 2026-08-11, Step 2 of the human-decision-channel fix, issue #324) —
  the specific attack this unit closes: deselecting the reviewer persona (removing
  `reviewer` from `.claude/persona-config.json`'s `personaSelection`) to
  unconditionally re-arm `reviewed-path-gate.sh`'s no-reviewer fallback for
  `.claude/reviewed/`, even while a standing `.escalated` marker exists — letting
  the main session/team lead (or orchestrator persona) silently discard a pending `ESCALATE-TO-HUMAN`
  escalation with zero human artifact, since only the reviewer ever writes
  `.escalated` and a standing one under a reviewer-less config proves the
  deselection post-dates the escalation. Contrast with the legitimate no-reviewer
  fallback (unit #453, 2026-09-10: `reviewed-path-gate.sh:263`), which this unit preserves unchanged
  when no `.escalated` marker stands and now extends to both the main session and orchestrator persona. Closed by the branch at
  `hooks/scripts/reviewed-path-gate.sh:105-116`: before the fallback's `exit 0`,
  it globs `.claude/reviewed/*.escalated` and blocks (`exit 2`) if any marker is
  found, naming the [[DECISION channel]] as the resolution route. Fixed at commit
  `8803252`, tests at `a828742` (cases (j)-(n) in `tests/reviewed-path-gate.test.sh`),
  PASSed at `13841aa`. See `.claude/reviewed/gh326.pass`.

**DECISION channel**:
(unit #326, 2026-08-11, named at Step 2 of #324; read and transcribed by the
  reviewer, Step 3/amended #136, 2026-08-11) — compact name for the resolution
  route [[DECISION file]] provides: `.claude/human-review/<task-id>/DECISION`,
  guarded unwritable-by-any-agent by [[The human-decision gate]] (`human-decision-gate.sh`,
  Step 1/#325). Named explicitly in `reviewed-path-gate.sh:113`'s block message
  as "the only route that resolves an escalation" once the no-reviewer fallback is
  suspended by a standing `.escalated` marker (see [[Escalation-laundering]]) — i.e.
  the fallback's block message points a human at this channel rather than leaving
  the escalation stuck with no legal way forward. The reviewer now reads and
  transcribes the channel (never re-reviews) into three terminal routes: approve
  → `.pass` with an appended human-attestation line, reject → `.fail` with the
  human's reason verbatim as the defect list, direct → [[`.directed` marker]]
  carrying the human's prescribed fix verbatim. Defined in
  `templates/persona-protocol.md`'s "Resolving an escalation" section.

**Mode assertion**:
(units gh273-1/gh273-2, 2026-08-14, issue #273) — a merge-gate
  check that a file's executable bit matches its invocation contract: `755`
  for scripts invoked directly by a `hooks.json` command entry or as a CLI,
  `644` for scripts that are only `source`d. Enforced by `tests/validate.sh`'s
  "hook script executable bits" block (added by gh273-1), which asserts both
  the working-tree mode and the git index mode across `hooks/scripts/`,
  `adapters/codex/hooks/scripts/`, and `adapters/cursor/hooks/scripts/`.
  Non-obvious: `hooks/scripts/lib/*.sh` are `644` by design — they are
  `source`d, never executed directly — which is the trap the issue's own
  suggested `find` command fell into (its unbounded recursion flagged them as
  false positives; a non-recursing glob excludes them). Paired with mode
  preservation, the companion discipline gh273-2 added to
  `templates/persona-protocol.md`'s Teammate Write/Edit fallback doctrine: a
  heredoc recreates a file at the umask default (usually `644`), silently
  dropping an executable bit the original had, so the doctrine now instructs
  capturing the mode first (`stat -c %a`) and restoring it after (`chmod`, or
  `chmod --reference` an untouched sibling). Together the two close the same
  defect class at two points — detection at merge time, prevention at the
  authoring technique that caused the #262 regression.

**Marker state summary**:
(unit #385-9, 2026-08-16) — a one-line summary printed by `bin/marker-commit-audit.sh`
  reporting aggregate state counts across an enumerated set of `.pass` markers, in the
  format `ok=N mismatch=N unverifiable=N`. Each count represents the number of markers
  in that state from a single classification run. This is a consumed interface distinct
  from individual per-marker outputs: the classifier emits one line per marker (see
  [[Marker classifier states]]); the audit script aggregates results and reports
  per-state totals. Used to surface marker health at a glance — in this repo, the
  initial audit run over all 234 `.pass` markers reported `ok=106 mismatch=15
  unverifiable=113`. Note: the audit script silently degrades both `unavailable`
  (classifier missing/non-executable) and `unverifiable` (classifier ran but couldn't
  decide) into the unverifiable_count bucket; see [[Marker audit-log states]] for the
  semantic distinction between these two system states.

**on-demand milestone audit**:
(unit gh402, 2026-08-16, Step 2 of the ceremony-reduction plan) — the
  `## Milestone audit gate` in `agents/orchestrator.md` no longer fires
  automatically once a milestone's units all reach reviewer PASS; it now runs
  only when the operator explicitly asks (the literal greppable trigger
  string). A non-gating reminder that a release boundary is a good moment to
  ask for one is retained, but reaching one no longer triggers the gate by
  itself. Every other property of the gate — never per-task, never a
  replacement for the reviewer, the human-flagged-premises pass-through, the
  findings-relay protocol, the challenged-premise re-plan route, and the
  `unconverged-requirement` → `## Convergence follow-ups` route — is
  unchanged; this is a change in *when* the gate fires, not what it does.
  Distinct from `agent-auditor`, which was already on-demand before this
  change and needed no edit. See
  [ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md).

**solo-operator posture**:
(unit gh401, 2026-08-16, Step 1 of the ceremony-reduction plan) — this
  repo's own `.claude/persona-config.json` running two documented opt-outs at
  once, as a deliberate standing configuration for a single, unsupervised
  developer rather than a team: `humanReviewMode: "off"` (no forced human
  comprehension pause on heavy-unit PASS, see [[humanReviewMode]] — this
  supersedes that entry's now-closed [[bootstrap window]] statement that the
  live value returned to `critical`) and `dispatchHygiene.mode: "warn"`
  (hygiene violations are logged, not blocked, see [[Dispatch hygiene]]).
  Both values are each mechanism's own shipped opt-out path, not a
  workaround; the shipped defaults (`critical` / `block`) are unchanged for
  every other adapted project. Risks R1 (no forced human pause) and R3 (H3
  coverage loss under `warn`) are accepted deliberately, stated plainly in
  `CHANGELOG.md`, not softened. See
  [ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md).

**parked unit**:
(unit gh404, 2026-08-16, Step 4 of the ceremony-reduction plan) — option (c)
  at the 2-FAIL cap (see [[FAIL routing (post-reviewer)]]): the orchestrator
  stops re-dispatching `lead-programmer` on the unit and moves on, leaving
  the two-attempt defect history standing. No marker is written and none is
  deleted — a parked unit is distinguishable from any other unit only by the
  absence of further dispatch, never by a dedicated marker state. Contrast
  with (a) debug spec and (b) human-directed re-dispatch, the other two
  options offered by the same `AskUserQuestion` prompt.

**Operational ignore list**:
(unit #408, 2026-08-25) — the canonical, single-sourced array of operational
  ignore patterns (lines 155-170 in `bin/cli.js`) representing every managed
  state-file pattern any target's scaffold or `--update` backfill needs to keep
  out of version control. Expressed relative to the [[`{{DOTDIR}}`  placeholder token]]
  so one array serves `.claude/.cursor/.codex` alike via `renderIgnorePatterns()`
  substitution, eliminating four hand-maintained copies that previously drifted
  independently. Patterns include marker directories, audit logs, session
  baselines, dispatch-override state, and microworld bundles. Consumed by
  every adaptor port and this repo's own `.gitignore` — a change to the list
  propagates everywhere in one edit, closing the measurement from unit #408's A3-A4
  acceptance criteria.

**operator**:
(unit gh405, 2026-08-16, Step 5 of the ceremony-reduction plan) — an
  explicit synonym for **human** throughout this glossary and this repo's
  persona prose (e.g. `ESCALATE-TO-HUMAN`, [[The human-decision gate]],
  [[humanReviewMode]], and the [[on-demand milestone audit]] trigger's
  literal `only when the operator explicitly asks`). Recorded here because
  that literal is now shipped in `agents/orchestrator.md` but "operator" did
  not otherwise appear among this glossary's defined terms. Not a distinct
  role: do not read "operator" as narrower than, or different from, "human"
  anywhere in this document.

**narrate-versus-target distinction**:
(units hdg-prose-2, hdg-prose-2-fix2, rpg-comment-3, 2026-08-24) — a gate-design
  principle distinguishing whether a command **narrates** (mentions or describes)
  a protected path as inert text, versus actually **targeting** it as a write
  destination. A command that narrates a path in a commit message (`git commit -m
  "fix(task-id): guard the DECISION file"`), a single-quoted read pattern
  (`grep 'DECISION\|human-review' <file>`), or a trailing shell comment (`echo x
  > other.pass # avoid touching .claude/reviewed/`) may be allowed even if the
  raw text contains both [[trigger token]]s, because these contexts are inert to
  bash execution. In contrast, a command that targets the path for a write
  (`printf x > .claude/human-review/id/DECISION`, `sh -c 'printf x > DECISION'`)
  is denied unconditionally. Both [[The human-decision gate]] and
  [[reviewed-path-gate.sh]] apply this distinction via gate-local allowances that
  check whether tokens survive into the command skeleton's CODE text (prose,
  single-quoted spans, and comments are masked and ignored). This is the design
  principle that closes false-positive denials of reads and inert narration while
  preserving the invariant that no agent can write the protected paths.

**trigger token**:
(units hdg-lexer-1, hdg-prose-2, 2026-08-24) — one of two literal substrings
  whose co-occurrence arms [[The human-decision gate]] and (in asymmetric form)
  other text-protection gates. In `human-decision-gate.sh`, the two triggers are
  `human-review` and `DECISION`. A command is blocked only if its raw text
  contains both substrings anywhere; either trigger alone allows the command
  through. This "both tokens must appear" rule is the gate's substring early-exit
  (a fast check before deeper gate logic). See [[narrate-versus-target
  distinction]] for when a command carrying both tokens is allowed anyway (when
  they are inert to execution).

**marker id charclass**:
(units hdg-prose-2, hdg-prose-2-fix2, 2026-08-24, defined in
  `human-decision-gate.sh:97`) — the set of characters allowed in a task id that
  appears in the packet path `.claude/human-review/<marker-id>/`. The charclass
  is defined as `[a-zA-Z0-9_-]`, plus `/`, space, and tab (both whitespace
  characters are path-safe when a task id spans them, which is uncommon). A id
  holding a space, tab, or unprintable character triggers additional scans (see
  [[path-safe charclass]]) to distinguish prose mentions from write targets.

**path-safe charclass**:
(units hdg-prose-2, hdg-prose-2-fix2, 2026-08-24) — a strict subset of the
  [[marker id charclass]] used to separate [[prose mention]]s from actual path
  targets. Defined as `[a-zA-Z0-9_-.]` (alphanumeric, underscore, hyphen, dot),
  this subset excludes space, tab, and shell metacharacters. A [[marker id
  charclass]] id that holds a space or tab (e.g. `"my task"`) requires the run
  scan (see [[run scan]]) to confirm both [[trigger token]]s appear in a
  contiguous non-whitespace run — if they span different words or sit in separate
  quoted regions, the id is allowed even if it contains both tokens.

**unit-id charclass** / **unit-id grammar**:
(unit gate-audit-step5, 2026-09-10) — the canonical character restrictions for
  unit ids used by gate scripts (`dispatch-hygiene.sh`, `marker-write.sh`,
  `reviewer-route-gate-core.sh`, `stop-gate-core.sh`, `human-decision-gate.sh`,
  `task-gate.sh`, `reviewer-tier.sh`). The grammar is: first character
  `[A-Za-z0-9]` (alphanumeric), remaining characters `[A-Za-z0-9._#-]` (plus
  underscore, period, hash, and hyphen), maximum 64 characters total. The
  **`UNIT_ID_CHARCLASS`** = `A-Za-z0-9._#-` is the canonical character class for
  the tail; the **`UNIT_ID_RE`** = `^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$` is the
  full regex. Deliberately includes **`#`** (the hash character) to permit ids
  like `gh#348` without substitution. Defined as canonical helpers in
  `hooks/scripts/lib/state-access.sh` (shared across all three adapter ports) and
  exported via `unit_id_valid()` (traversal guard + regex validation),
  `unit_id_sanitize()` (replace invalid chars with `_`), and `unit_id_marker_path()`
  (derive marker file paths). Distinct from [[marker id charclass]] and
  [[path-safe charclass]], which govern a different domain (the human-decision
  gate's prose false-positive filtering for `.claude/human-review/` packet ids)
  and are not interchangeable with this grammar.

**path-shaped run**:
(units hdg-prose-2, hdg-prose-2-fix2, 2026-08-24) — a contiguous sequence of
  non-whitespace characters in the command text that contains both [[trigger
  token]]s and resembles a file path. The [[run scan]] in `has_path_shaped_occurrence()`
  checks whether such a run exists — if both tokens appear together in one
  unbroken word-like span (e.g. `.claude/human-review/id/DECISION` or
  `human-review-task-DECISION`), the gate treats it as a potential write target
  and denies the command. If the tokens are separated by whitespace or safe
  punctuation (see [[marker id charclass]] and [[path-safe charclass]]), no
  path-shaped run is found and the gate may allow the command. This is a
  structural property of the text, not merely word presence.

**run scan** / **companion scan**:
(units hdg-prose-2, hdg-prose-2-fix2, 2026-08-24) — two tandem gate-logic
  functions in `has_path_shaped_occurrence()` (see [[command skeleton]]) that
  determine whether both [[trigger token]]s appear in a form that could name an
  actual file path. The **run scan** checks whether some contiguous run of
  non-whitespace characters holds both tokens (the [[marker id charclass]] proof).
  The **companion scan** (added in hdg-prose-2-fix2) checks whether unsafe
  characters (`:!,;()[]="@+%~^&*?\` and newline) sit between the two tokens,
  which escape the run — if unsafe characters are present between them, the scan
  rejects the shape as a false-positive prose mention. Both scans use no word
  splitting and no pathname expansion (a measured hazard: a bare `*` in commit
  text once expanded to repository filenames).

**quote-joined text**:
(units hdg-prose-2, hdg-prose-2-fix2, 2026-08-24) — a textual normalization
  applied before the [[run scan]]: concatenating adjacent quoted and unquoted
  spans (e.g. `.claude/'re'viewed` → `.claude/reviewed`) so that quote-split
  obfuscations of the marker directory do not bypass the gate. Implemented in
  `human-decision-gate.sh` as a loop that joins sequences of single-quoted,
  double-quoted, and unquoted tokens into single words before scanning for the
  path shape.

**sanctioned marker-write template**:
(units gh345-1 note N6, hdg-prose-2, 2026-08-24, implemented in
  `is_sanctioned_marker_write()` since 2026-08-12) — a narrowly-scoped
  exception to [[The human-decision gate]]'s write block: the one command shape
  that every agent identity may use to create a `.claude/reviewed/<id>.pass` or
  `.claude/reviewed/<id>.fail` marker file. The template is a heredoc-based
  marker creation: `cat > .claude/reviewed/<id>.pass <<'EOF' … EOF`, which reads
  from standard input and writes to a single explicit marker file path. This is
  the **only** write shape the gate allows, and it is unconditional across all
  identities (reviewer, main session, orchestrator). The restriction to this
  single shape (no piping, no redirection to other files, no `tee`, no `cp`)
  closes a class of attacks that use marker-write privileges to access other
  protected files. The gate recognizes the template syntactically (via a
  dedicated function) and performs no capability delegation — a bare `cat >
  .claude/reviewed/id.pass` (without the heredoc) is denied.

**single-quoted span** / **double-quoted span**:
(units hdg-lexer-1, 2026-08-24, refined in gate lexing via `command_skeleton()`
  in `hooks/scripts/lib/benign-command.sh`) — a quoted region in bash command
  text where escaping rules differ. A **single-quoted span** (e.g. `'text\n'`)
  treats all characters literally — even backslash is literal, so `\` inside
  single quotes poses no escaping hazard and is safe to permit. A
  **double-quoted span** (e.g. `"text\n"`) honors backslash escapes (`\"` becomes
  `"`), so a backslash inside double quotes is dangerous and must fail closed (a
  `\"` at span's end could close an unrelated quote). The lexer models these
  separately; a backslash outside both quote types and within `$'…'` or `$"…"`
  (ANSI-C or locale quoting, which honor escapes) must also fail closed.

**skeleton** / **command_skeleton**:
(units hdg-lexer-1, earlier, implemented in `hooks/scripts/lib/benign-command.sh`
  and used by both [[The human-decision gate]] and [[reviewed-path-gate.sh]]) —
  a representation of a bash command that masks (replaces with whitespace) all
  quoted spans, comments, and variable expansions, leaving only the bare
  executable structure. The skeleton is what gate logic scans to determine whether
  a command can write a protected path — by looking at which words survived into
  CODE text (vs. being masked as inert quoted/commented/expanded regions). The
  lexer that builds the skeleton is shared between both gates and must fail
  closed on every bash quoting and escaping rule; the two units hdg-lexer-1 and
  hdg-prose-2 hardened this lexer against seventeen measured escape hazards
  (ANSI-C quoting, locale quoting, escaped quotes in double-quoted spans, line
  continuation, `$'…'`, `$"…"`, and backslash in various contexts).

**prose mention**:
(units hdg-prose-2, 2026-08-24) — a reference to a protected path that appears
  only in inert textual contexts: a git commit message (the `-m` flag's argument),
  a single-quoted read pattern (as in `grep 'DECISION' file`), or a shell comment
  (trailing `# text`). Prose mentions are allowed by [[The human-decision gate]]
  even if they carry both [[trigger token]]s, because they do not execute and
  cannot be used to write the protected path. Contrast with a write target (see
  [[narrate-versus-target distinction]]).

**inert triggers**:
(units hdg-prose-2, 2026-08-24) — a condition checked by `triggers_are_inert()`
  in `human-decision-gate.sh`: both [[trigger token]]s are present in the command
  text, but neither survives into the skeleton's CODE section (both are masked by
  quoting, comments, or expansion). Inert triggers pass the gate's second allowance
  branch because they are absent from executable positions where bash would use
  them as redirection targets or command names.

**prose-only commit**:
(units hdg-prose-2, 2026-08-24, checked by `is_prose_only_commit()` in
  `human-decision-gate.sh:183-195`) — a `git commit` command that carries only
  a commit message (`git commit -m`), with no redirection, no file arguments
  beyond the message text, and no leading commands (e.g. `cd` then `commit` is
  denied, but a bare `git commit -m …` is allowed). This is a gate-local
  recognizer that permits commits whose text contains both [[trigger token]]s,
  because the message is inert and the message is the *only* place those tokens
  can appear in a prose-only commit. The condition is strict: `git add` is not
  allowed alongside the commit (chaining is what enables commit-then-write
  attacks), and this recognizer applies only to the `git commit` program, not to
  other programs.

**Capability register**:
(introduced mw-step4, unit #322) — the demand-gated HTTP API inventory
  documented at `docs/microworld-dashboard-capabilities.md`, classifying each
  `/api/*` route served by `bin/microworld-dashboard/server.js` as
  **load-bearing** (required for a real escalation or debug session) or
  **speculative** (exploratory, not yet demanded). Load-bearing routes must
  cite an actual escalation, debugging session, or protocol entry (e.g. ADR
  0018); speculative routes must state a rationale. The gate is enforced by
  review discipline: any new capability flagged in review must have a
  corresponding register row before merging. Complements the microworld
  dashboard's protocol obligations (see [[Microworld dashboard]]).

**verifiedBy** / **functionsAuthoredBy**:
(introduced mw-step3, stamped into escalation packets) — a provenance block
  in an escalation packet's `manifest.json` (added by the reviewer) that
  records which party authored the `functions[]` array and how it was
  verified. The `verifiedBy` object carries `agent: "reviewer"`,
  `timestamp`, `commit`, and `functionsAuthoredBy` (either `"reviewer"` if
  the reviewer authored the array outright because the escalating unit had
  none, or `"implementer-verified"` if it was carried over from the unit
  and the reviewer verified/corrected its locations). This distinction marks
  the reviewer's provenance stamp on escalation packets, load-bearing across
  the persona protocol and both adapter ports (Codex and Cursor). See
  `agents/reviewer.md` step R2 for stamping discipline.

**Render fixed point**:
(property asserted by mw-step3's AC-R3) — the idempotency property
  of `bin/cli.js --update --force-render`: after running the command followed
  by `git status --porcelain`, the output must be zero lines (or only
  `.claude/` autogenerated files if the repo itself touches them). This
  property detects **stale managed mirrors** — commits that leave ADAPT-stamped
  files (e.g. `templates/persona-protocol.md` or shipped persona mirrors)
  out of sync. A render-fixed-point failure signals that the mirrors need
  re-rendering or the source stamp needs updating. Related to **managed
  mirror** copies and the stamp-refresh mechanism in `--update` semantics.

**disarm surface**:
(unit gh423, 2026-08-27) — the config field set whose weakening turns a
  trust gate off. Defined exactly by `normalize_disarm_surface()` in
  `bin/harness-integrity.sh` as nine `.claude/persona-config.json` fields:
  `gatedAgents`, `protectedPaths`, `personaSelection`,
  `dispatchHygiene.mode`, `dispatchHygiene.requireContract`,
  `markerCommitCheck.mode`, `humanReviewMode`, `testAndLintCommand`, and
  `reviewGating.mode`. Each field is normalized to its **effective** value
  (an absent key maps to the same documented default its consuming gate
  already falls back to, per D6) before comparison, so an absent key and an
  explicit default-valued key compare equal while a genuine weakening —
  including the absent → `"off"` transition on `reviewGating.mode` D
  introduces — does not get silently normalized away.
  `fileHashes`/`pluginVersion`/`substitutions` are deliberately excluded:
  `--update` rewrites them routinely and they carry no gating authority.
  The comparison runs against the **session baseline commit** (D4, not live
  `HEAD`), is reported (never blocks) from `session-start.sh`, and hard
  **blocks** only at a gated agent's own `SubagentStop` inside
  `stop-gate.sh` — never at main-session `Stop` (RD3) — via a
  `defer:`/`skip:` override file mirroring the pending-review escape hatch.
  See [[audit seal]] (the parallel mechanism for the four gitignored audit
  logs, which are not tracked by git and so need a sidecar rather than a
  git-baseline comparison) and `docs/trust-model.md` for the broader
  self-report-vs-mechanical map this closes row 13 of.

**audit seal**:
(unit gh415, 2026-08-26) — the append-only sidecar `<log>.seal` maintained
  alongside each of the four gitignored `.claude/*-audit.log` files by
  `hooks/scripts/lib/audit-log.sh`, holding a single line
  `lines=<N> sha256=<hash>` — `N` is the log's line count and `hash` is the
  sha256 of the whole file at the moment of the last reseal. `audit_append`
  appends a line then reseals unconditionally; `audit_seal_verify` reports
  `ok` only when the log has at least `N` lines AND the sha256 of exactly
  its first `N` lines matches the sealed hash — `truncated`, `missing-seal`,
  `absent`, or `unverifiable` otherwise. Per the library's own header
  comment (its "what the seal does and does not prove" section, stated
  candidly rather than overclaimed here): it **detects** accidental
  truncation, a crashed/partial write, a `git clean` that removed the log,
  and an out-of-band edit by a tool that doesn't know the seal exists; it
  does **not detect** an adversary who truncates the log AND reseals —
  resealing is one `sha256sum` plus a two-line rewrite, and nothing in the
  library stops a determined agent from doing both. The seal prices that
  attack (turns a one-call truncation into a two-step operation that must
  also model the seal format) and catches accidents reliably; it is
  evidence against carelessness, not a defense against intent. See
  [[sanctioned rotation]] for the one operation that legitimately rewrites
  a sealed log without tripping this detector, and `docs/trust-model.md`
  row 12 for how this feeds the broader trust map.

**sanctioned rotation**:
(unit gh415, 2026-08-26) — a log rotation that ends by leaving the sealed
  log's new content and its `.seal` sidecar consistent, so `audit_seal_verify`
  reads the result as `ok` rather than `truncated` — which is otherwise
  indistinguishable from a truncate-and-not-reseal attack against the
  [[audit seal]]. Two call sites both qualify, and neither predates the
  other's reseal discipline: `audit_rotate()` in
  `hooks/scripts/lib/audit-log.sh` (invoked by `bin/harness-integrity.sh
  --rotate`) moves the log to `<dot-dir>/audit-archive/<utc>-<name>.log`,
  starts a fresh log whose first line records the archived file's name,
  line count and sha256, and reseals it. `bin/human-review-cleanup.sh`'s
  pre-existing `rotate_log()` (its own, older archival shape — it preserves
  the log's last line as the new file's sole content, for defer-dedup
  continuity, rather than writing `audit_rotate`'s header line) was extended
  by this unit to drop the stale `.seal` left over from the archived content
  and call `_audit_reseal` directly on the fresh file, rather than switching
  to `audit_rotate`'s incompatible archive-naming scheme. Either path is
  "sanctioned"; a rotation that moves or truncates a sealed log through any
  other route (e.g. a bare `mv`/`: >`) leaves a stale `.seal` behind and
  will read as tampering.

**countersign**:
(unit gh417, 2026-08-26) — an optional marker a reviewer writes at
  `.claude/reviewed/<slug>.countersign`, one line:
  `COUNTERSIGN <slug> <UTC ISO-8601> runsh: <sha256 of
  microworlds/<slug>/run.sh>`. Writing one attests that the reviewer **read
  and re-derived** the bundle's `run.sh` checks — never that they
  re-authored it, and never a claim of authorship. Like every marker under
  `.claude/reviewed/`, it is not self-declarable: the directory's own
  write-identity grant (see [[The Writer/Reviewer split]],
  [[reviewed-path-gate.sh]]) restricts who may write it, and RD5 records
  that its loss fails safe to the honest `self` default rather than silently
  granting authority. It is optional — an uncountersigned bundle simply
  stays at the honest default (see [[authority]]) — and it is **automatically
  invalidated** the moment `run.sh` is edited after countersigning: the
  hash recorded in the marker no longer matches the file's current hash,
  which is exactly the comparison [[authority]] performs. See
  `docs/trust-model.md` for the canonical self-report-vs-mechanical
  framing this marker converts one row of.

**authority**:
(unit gh417, 2026-08-26) — a `self`/`reviewer` provenance field appended
  to a **microworld bundle**'s result line in the **Microworld audit log**
  (`... authority=self` or `... authority=reviewer`), derived by
  `_bundle_authority()` in `hooks/scripts/lib/microworld-queue.sh`. It is
  never self-declarable and never read from a bundle's own `manifest.json`:
  it is `reviewer` if and only if a matching [[countersign]] marker exists
  at `.claude/reviewed/<slug>.countersign` AND its recorded `runsh:` sha256
  equals `run.sh`'s **current** hash (computed fresh, never cached); any
  mismatch — no countersign, a malformed or absent `runsh:` field, or
  `run.sh` edited since the countersign was written — falls back to `self`.
  The microworld dashboard renders anything other than `authority=reviewer`
  with an explicit `unverified — implementer-authored check` text label
  (never a colour alone) at every place a bundle's status is shown, closing
  the F5 gap where a self-graded pass looked identical to any other green
  signal. See `docs/trust-model.md` row 10 and, for the fuller
  self-report-vs-mechanical distinction this term is one instance of, that
  document generally — restated here only to the extent needed to define
  the field itself, not forked.

**decision surface**:
(unit gh354, 2026-09-04) — the Decisions section of the Microworld dashboard
  (`bin/microworld-dashboard/decisions.js` + `GET /api/decisions`) that reads
  and renders the four human-facing decision touchpoints of this persona
  system: the `ESCALATE-TO-HUMAN` DECISION file, the milestone pre-audit
  checkpoint (read-only — see below), the milestone-auditor findings relay,
  and the pending-review `defer:`/`skip:` flag. Three of those four — the
  pre-audit checkpoint, the milestone-auditor findings relay, and the
  pending-review `defer:`/`skip:` flag — are **compose-only**: the surface
  renders command or message text for a human to run or paste, and has no
  write path of its own. The fourth — `ESCALATE-TO-HUMAN` resolution — has a write
  path *through the dashboard itself*: `POST /api/decision/arm` and
  `POST /api/decision/run` (`server.js:262`, `:418`; added by gh380, commit
  `19a0cd0`, 2026-08-15) write the DECISION file with `flag: 'wx'` and append a
  `decision-write-via-dashboard` line to `.claude/review-audit.log`. The trust
  anchor on that path is the terminal-delivered [[confirmation code]] compared
  with `crypto.timingSafeEqual` — *not* the absence of a write path; see
  [[dashboard-originated decision write]] for the full property and
  [[read-only mode]], which refuses both endpoints outright. Do not restate
  this surface as "never writes": that was true only before gh380 shipped, and
  the composer module `decision-block.js` being a pure formatter does not
  extend to the dashboard as a whole. The decision surface remains a distinct
  concept from the **DECISION file** / **DECISION channel** (the artifact a
  human's decision produces) and is never used as a synonym for it. Not every
  touchpoint is fully routed: the pre-audit checkpoint's *answer* deliberately stays in
  `AskUserQuestion` (R6, `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`)
  because the decision is cheap to answer and expensive only to read, so
  only the reading is worth moving. See [[composed decision command]] and
  [[milestone findings record]].

**milestone findings record**:
(unit gh354, 2026-09-04) — the one new durable artifact this decision surface
  introduces, at `.claude/milestone-audit/<plan-slug>/FINDINGS.md`, first line
  exactly `FINDINGS <plan-slug> <UTC ISO-8601 timestamp> count: <n>` followed
  by the findings list verbatim. Written by `milestone-auditor` itself via
  `Bash`, as a **named bookkeeping exception** — the same carve-out the
  reviewer already has for `.pass`/`.fail`/`.escalated` markers, for the same
  reason: a record *about* the work, not a change *to* the work. This is
  deliberate: `milestone-auditor` has no `Write`/`Edit` tool by design, and
  does not gain one. See [ADR-0030](docs/adr/0030-decision-surface-composes-milestone-findings-write-duty.md).
  Intended to join the sibling operational markers as ignored working state,
  but as of 2026-09-04 `.claude/milestone-audit/` has no `.gitignore` entry
  (`git check-ignore` does not match it) — the intent is recorded, the
  mechanism is not yet in place. The orchestrator deletes the directory once
  the human's decision on the findings has been acted on; a stale record is a
  defect, not untidiness, for the same reason a stale escalation packet is.
  That cleanup duty is likewise **currently unenforced** — specified in prose
  only, with no hook, test, or gate checking it.

**composed decision command**:
(unit gh354, 2026-09-04) — a ready-to-run shell command, or (for the
  milestone-findings touchpoint only) a copyable paste-back markdown block,
  that the [[decision surface]]'s single composer module
  (`bin/microworld-dashboard/decision-block.js`) renders but never executes
  and never POSTs anywhere. Three of the four touchpoints compose a command
  (`ESCALATE-TO-HUMAN` resolution; pending-review `defer:`; pending-review
  `skip:`); the milestone-auditor findings relay composes a message instead
  of a command — a deliberate deviation (R7) from the literal "compose the
  exact ready-to-run command" request, because that touchpoint's recipient is
  the conversation, not the filesystem. Composition safety is a correctness
  requirement, not polish: no command substitution in composed content,
  multi-line bodies use a single-quoted heredoc that refuses a body
  containing a line equal to its own delimiter, and interpolated ids are
  validated against the protocol's id grammar before use.

**advisory dispatch**:
(unit gh429, 2026-09-04) — a reviewer dispatch that carries no
  acceptance-criteria command and owns no verdict: it exists to produce a
  text report, not a PASS/FAIL/INSUFFICIENT-CONTEXT/ESCALATE-TO-HUMAN
  judgment. Declared by a `Mode: advisory` second non-blank line (the
  machine-readable form `reviewer-route-gate-core.sh` reads), immediately
  after the dispatch's `Unit: <id>` first line. On recognizing this token
  the route gate writes no [[review-join stamp]], logs
  `advisory-dispatch=$unit_id` to the review audit log, and exits 0 —
  distinct from every other reviewer dispatch shape, all of which end in a
  marker file under `.claude/reviewed/`.

**eval registry**:
(unit gh-eval-step1, 2026-09-11) — the YAML registry file at
  `eval/registry/reviewer-verdict.yaml` defining all available evaluation
  suites for reviewer behavior regression testing. Each entry names a suite id,
  specifies the cases directory path, and maps to one or more suite definitions
  (e.g. `reviewer-verdict.gold.v1`, `reviewer-verdict.grader.v1`). The suite id
  uses OpenAI evals naming convention: `<name>.<split>.<version>` where the
  `<split>` component encodes the suite type — `gold` for ground-truth labeled
  cases, `grader` for calibration/grading cases. See [[gold split]], [[grader split]].

**gold split**:
(unit gh-eval-step1, 2026-09-11) — one of two suite types in the eval
  registry, containing ground-truth labeled test cases with immutable gold
  verdicts. A gold-split case (e.g. `reviewer-verdict.gold.v1`) is the
  canonical oracle for reviewer behavior: each case specifies a code change
  (`change.patch`), a dispatch packet (`packet.md`), and an authoritative
  verdict (`gold.verdict`: PASS or FAIL) plus defect list. Gold labels are
  immutable within a suite version — changes require a new `.v<n+1>` version.
  See [[gold label immutability]], [[grader split]], [[eval registry]].

**grader split**:
(unit gh-eval-step1, 2026-09-11) — one of two suite types in the eval
  registry, containing calibration cases paired with hand-written reviewer
  messages for grading. A grader-split case (e.g. `reviewer-verdict.grader.v1`)
  does not name a code fixture or patch (those live in the paired gold case);
  instead it references a gold case's defects and captures an actual reviewer's
  message and expected identification accuracy. Used to calibrate grader tools
  and measure whether automated verdict assessment can match human judgment on
  the same input. See [[gold split]], [[eval registry]].

**class tag**:
(unit gh-eval-step1, 2026-09-11) — one of the required metadata taxonomy labels
  in a case's `tags` array, categorizing what kind of defect or behavioral case
  it represents. Distinct from [[size tag]]. FAIL-class tags include:
  `input-mutation`, `boundary`, `unmet-criterion`, `silent-behavior-change`,
  `vacuous-test`, `security`, `unhandled-input`, `skipped-test`. PASS-class
  tags include: `clean`, `style-decoy`, `robustness-decoy`, `refactor`,
  `unrelated-touch`. Each case must carry at least one class tag; a case with
  only size tags (e.g., `size:small`) is rejected (`tag-class-missing`).

**size tag**:
(unit gh-eval-step1, 2026-09-11) — one of the optional metadata taxonomy
  labels in a case's `tags` array, classifying case scope by lines and files
  changed. Defined values: `size:small` (≤40 lines, ≤3 files) and `size:large`
  (larger). Distinct from [[class tag]], which is required and categorizes
  defect/behavioral type. Size tags are purely advisory metadata; validator
  never rejects a case for absent or misspelled size tags.

**gold label immutability**:
(unit gh-eval-step1, 2026-09-11) — the rule that a gold-split case's expected
  verdict and defect list must never be edited in-place within a suite version;
  the gold label is immutable within the version (e.g. `reviewer-verdict.gold.v1`).
  Any correction or change to a gold verdict, defect, or patch semantics requires
  publishing a new suite version (e.g. `.v2`) with a new case directory. This
  discipline ensures reproducibility: anyone re-running `reviewer-verdict.gold.v1`
  today or a year from now sees the same cases and verdicts. Enforced by the
  validator as a documentation and audit requirement (not mechanically prevented
  in the filesystem).

**reason class**:
(unit gh-eval-step1, 2026-09-11) — a categorization of validator rejection
  reasons into two groups. The **missing-field family** (8 variants) is generated
  by removing each required field (`id`, `suite`, `fixture`, `task`, `patch`,
  `packet`, `gold`, `tags`) from a case, yielding 8 reasons of the form
  `missing-field:<name>`. The **individually-named reasons** (12 variants)
  cover all other rejection conditions: `id-mismatch`, `duplicate-id`,
  `bad-suite`, `bad-verdict`, `defects-required`, `defects-forbidden`,
  `defect-file-not-in-patch`, `patch-does-not-apply`, `packet-missing`,
  `packet-lacks-unit-line`, `packet-leaks-gold`, `tag-class-missing`. Together,
  these 8 + 12 = 20 distinct error conditions map to 13 distinct reason string
  values: the 8 variants compress to the `missing-field:` pattern, yielding 1 +
  12 = 13 canonical reasons. The distinction enables reason classification
  without enumerating all 8 variants redundantly.

**decoys**:
(unit gh-eval-step1, 2026-09-11) — an optional metadata field in a gold-split
  case's `case.yaml`, listing non-material nits present in a PASS case on
  purpose. Each decoy is a one-line description (e.g., `- "naming inconsistency in helper function"`).
  Decoys document intentional, acceptable shortcomings that a reviewer may or
  may not flag — they are present to test reviewer judgment on material vs.
  non-material findings. The `decoys` field is forbidden for FAIL cases (validator
  rejects it as `defects-forbidden` if defects list is non-empty) and optional
  for PASS cases. Known v1 gap: decoys are documented in the README but not yet
  validator-enforced; full JSON-Schema validation is deferred to Step 3.

**dispatch packet**:
(unit gh-eval-step1, 2026-09-11) — in eval context, the `.md` file given to a
  reviewer under test, containing a dispatch prompt with unit objective,
  acceptance criteria, and related task metadata. Distinct from the operational
  artifacts **Escalation packet** (human-review escalation bundle),
  **Resolved packet** (archived escalation history), and **Pending packet**
  (pending-review state artifact) in [[5 key domains]]. A dispatch packet in
  eval cases (`eval/cases/reviewer-verdict/*/packet.md`) contains a `Unit: eval-<id>`
  line and must not leak the `gold:` label that the case author knows but the
  reviewer under test should not see. Prefer explicit "dispatch packet" phrasing
  to distinguish this sense from existing packet terminology.

**turn-end** / **natural turn boundaries**:
(unit orch-rulings-followup-1, 2026-09-12) — two related but distinct concepts in
  dispatch and polling guidance. **turn-end** is the specific protocol event marking
  the conclusion of a dispatched turn, where control returns to a caller. This is the
  subject of the **Terminal status line** section in the **Shared persona protocol**,
  which requires every dispatched turn to end with a `STATUS:` line. **natural turn
  boundaries** is a broader concept: natural transition points in ongoing work where
  one activity concludes and another begins. This includes turn-ends, but also other
  natural breaking points (e.g., completion of a task before moving to the next, or
  any point where you're naturally pausing work). Used in `agents/orchestrator.md`'s
  "Managing a long-running background dispatch" section to advise: "Space polls out
  across your natural turn boundaries (e.g. after other work, or the next time
  you're about to act) rather than checking in a tight loop." Every turn-end is a
  natural turn boundary; the converse does not hold. When ambiguous in context,
  clarify which sense is intended.

