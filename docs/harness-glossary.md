# Harness glossary

Harness-mechanics vocabulary for this repo's own hooks, markers, gates, and dispatch plumbing — terms whose meaning requires knowing this repo's internal implementation, not just using the plugin. Canonical alongside `docs/adr/`; owned by `scribe`, same custody as `CONTEXT.md` (the domain glossary). If you're looking for a persona-system concept a plugin user would meet (personas, gates in general, escalation workflow, model tiers, skills), see `CONTEXT.md` instead.

## Language

**achievable reduction**:
(unit item04-1, 2026-09-26) — one of two classification grounds for determining 
  whether a protocol section is a **candidate-for-drop** in the item04 matrix-trimming 
  pass. An **achievable reduction** is when a section's presence in a persona's 
  rendered mirror measurably saves tokens (e.g., the section is 200+ words of prose 
  that a persona can execute its mandate without), making the removal viable and 
  justified. Contrasted with "zero-value removal" — when a section simply does not 
  apply to that persona at all — both are grounds for dropping, but only achievable 
  reductions are tracked as deliberate cost-governance decisions. See also 
  [[candidate-for-drop]].

**ask-eligible** (synonym: **human-confirmable path**):
(unit hcb-branch, 2026-09-24) — the 5-path subset of Set A ∪ Set B in
  `harness-integrity-gate.sh` that can actually reach the `ask` branch when
  `agent_id` is absent and `permission_mode` is in the frozen [[permission-mode allowlist]].
  Comprised of: 1 Set A path (`.claude/persona-config.json`) and 4 Set B paths
  (`hooks/hooks.json`, `.claude/settings.json`, `hooks/scripts/harness-integrity-gate.sh`,
  `.claude/hooks/scripts/harness-integrity-gate.sh`). Distinct from the full 9-path Set A
  (persona-config + 4 audit logs + their 4 `.seal` sidecars, of which only persona-config
  is ask-eligible; the other 8 stay unconditional deny even under an allowlisted mode)
  and the full 4-path Set B. The ask-eligible subset is the gate's exactly-five-paths-wide
  surface pinned by acceptance criterion C1.7 in the unit spec. The term **human-confirmable path**
  appears as an in-code synonym in `hooks/scripts/harness-integrity-gate.sh:59` (comment for
  the `completed()` function). Note: test code (`tests/harness-integrity-gate.test.sh`) uses
  "Set A"/"Set B" labels loosely; future prose-reconciliation work should tighten these labels
  to the canonical [[ask-eligible]] term where precision is needed (not in scribe's scope for
  this unit — code-comment refinement owned by later prose-reconciliation step).

**asked audit record**:
(unit hcb-branch, 2026-09-24) — the `PreToolUse` half of the `asked`/`completed` pair,
  written by `harness-integrity-gate.sh`'s `ask()` function (line 126) when a human
  confirms a permission prompt on one of the 5 [[ask-eligible]] paths. An `asked` line
  has format `<timestamp> asked hook=harness-integrity-gate set=<A|B> subject=<path>`.
  Together with a matching [[`completed` audit record]], the pair verifies that a human
  approved a write (asked) and the write then succeeded (completed), keeping
  `docs/trust-model.md` row 11 verifiable — a harness-integrity-gate write-deny is
  functioning if the gate's registration surface remains unmodified. See also
  [[U5 pairing ambiguity]] for the asymmetric interpretation of `asked` without
  matching `completed` between Set A and Set B.

**Attested commit**:
(unit #386, 2026-08-15) — the commit recorded in a [[PASS marker]]'s
  `commit:` field (v3 format), representing the unit's own final commit — the
  exact point in history at which the unit's work, as reviewed and accepted,
  concluded. Distinct from marker-write-time HEAD, which may have moved by the
  time the marker is consulted (e.g., after a rebase or force push). The
  attested commit is what dispatch-hygiene's H3 gate tests for reachability (see
  [[Dispatch hygiene]], [[Commit attribution]], [[`.escalated` marker]], and
  [ADR-0023](docs/adr/0023-marker-commit-attribution.md)).

**candidate-for-drop**:
(unit item04-1, 2026-09-26) — a protocol section proposed for removal from a 
  full-tier persona's rendered body via a matrix entry in 
  `PROTOCOL_SECTIONS_BY_PERSONA`. A section becomes a candidate for drop when 
  either: (1) it provides zero value to that persona (the section's content simply 
  does not apply), or (2) it represents an **achievable reduction** (the section's 
  presence is correct but removable without breaking the persona's core mandate, 
  saving tokens measurably). The two drop grounds are NOT interchangeable — dropping 
  a zero-value section is cost-free clarity; dropping an achievable reduction is a 
  deliberate speed/capability trade-off. Item04-1's methodology distinguishes both. 
  Candidates are tested via mutation controls: a reversal of the `drop[]` entry 
  (including the section when it would normally be dropped) must fail a mutation 
  test to prove the drop is materially correct. See [[achievable reduction]].

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

**cell space**:
(unit hcb-regcheck, 2026-09-24) — a literal, hardcoded enumeration of
  `(hook_event_name, subject, permission_mode, agent_id-state)` tuples used to compare
  multiple mutation-testing controls against a single shared coordinate system, rather
  than each control inventing its own private accounting of what it tests. The cell space
  serves as the fixed reference frame in [[kill-set relation table]]s: every cell is a
  coordinate in this space, and a mutation control's behavior is characterized by its
  kill set (the set of cells whose verdict differs from the shipped implementation).
  Cells are derived from a literal matrix of all combinations, ensuring no measurement
  gap where an untested coordinate is implicitly assumed correct. See [[kill set]],
  [[kill-set relation table]], [[tier isolation]].

**completed audit record**:
(unit hcb-posttool, 2026-09-24) — the `PostToolUse` half of the `asked`/`completed` pair,
  written by `harness-integrity-gate.sh`'s `completed()` function (line 63) when a write
  to one of the 5 [[ask-eligible]] paths succeeds and the `PostToolUse` hook fires.
  A `completed` line has format `<timestamp> completed hook=harness-integrity-gate set=<A|B> subject=<path>`.
  Together with a matching [[asked audit record]], the pair verifies that a human approved
  a write (asked) and the write then succeeded (completed), keeping `docs/trust-model.md`
  row 11 verifiable — a harness-integrity-gate write-deny is functioning if the gate's
  registration surface remains unmodified. See also [[U5 pairing ambiguity]] for the
  asymmetric interpretation of `asked` without matching `completed` between Set A and Set B.

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
(unit hcb-step5-measure, 2026-09-24; shipped in unit hcb-branch, 2026-09-24) — the ordered list of `permission_mode` values
  (`default`, `plan`, `acceptEdits`, `auto`; explicitly excluding `dontAsk`,
  `bypassPermissions`, and unrecognized modes) that `harness-integrity-gate.sh`'s
  `ask_allowed()` branch (documented in
  `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`) checks before emitting `ask` from a hook. Distinct from [[Set A / Set B]]
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

**sweep closure / Cat 1 / Cat 2 / Cat 3 / Cat 4**:
(unit hcb-prose-history, 2026-09-24) — a repo-wide grep-based classification proving
  every file matching a stale/superseded claim's search pattern has been accounted for,
  in both directions: an unclassified [[hit-bearing file]] is red, and a classified file
  with zero actual hits is also red (preventing the table from rotting into a stale
  allowlist). The classification is keyed on FILE, not line number (line numbers shift
  when amendment notes are added), making [[hit-bearing file]] the unit of classification.
  Originated in `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`'s
  "Sweep closure" subsection (1339–1557) and reused as a convention for prose-reconciliation
  sweeps throughout this repo.
  The four-category taxonomy classifies every hit-bearing file into exactly one of:
  **Cat 1** — not about the thing being swept (a different gate/feature); **Cat 2** — the
  claim was made false, needs a dated amendment note; **Cat 3** — the claim is still
  literally true, gets NO note (annotating it would falsely imply it changed) — this
  category must have a non-empty membership or the check is vacuous; **Cat 4** — the whole
  file is excluded from the sweep by a separate, recorded ruling (e.g. ADR-0029's
  historical-citation rule for CHANGELOG.md). See [[documented residual]] for how Cat 4
  exclusions are recorded, and [ADR-0025](docs/adr/0025-textual-gate-protection-requires-structural-triggers.md)
  for the ADR-driven exclusion precedent.

**hit-bearing file**:
(unit hcb-prose-history, 2026-09-24) — a file that matches a [[sweep closure]]'s search
  pattern at least once; the unit of classification in a sweep-closure table (never keyed
  on line number or hit count, since those shift when amendment notes are added or prose is
  edited). Named as such to emphasize that the classification is file-scoped, not
  line-scoped. A file with zero hits on a [[sweep closure]] table is red (indicating table
  rot or stale exclusion), whereas a listed file with zero hits is treated as vacuous.

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

**guarded change**:
(unit orchestrator-effort-policy-prose-fix, 2026-09-24) — an edit to a persona's 
  definition file (`agents/<persona>.md`), particularly its frontmatter fields like 
  `effort:`, `model:`, or `tools:`. This is a durable, definitional change that 
  permanently alters the persona's traits and applies to all future dispatches of 
  that persona. Contrasted with transient, per-invocation changes (e.g., per-dispatch 
  runtime flags, which do not exist for effort). Currently enforced as a **normative 
  convention only** (part of this project's discipline for persona definition edits), 
  not mechanically: `agents/*.md` files are explicitly excluded from both Set A and 
  Set B of [[Set A / Set B]] in `harness-integrity-gate.sh`, and the project's 
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
  `microworld_skip_ok` to compute `git diff` from that baseline to `HEAD`, in order to
  determine which files have been modified since the session began. Distinct from
  **session baselines** (see [[Sweep]]), which refers to `.claude/baseline-*.json`
  files that track fileHashes currency across different artifacts. The session baseline
  commit's core contract (unit spec2-unitB): must be reachable in the working repository's
  git history — if history is rewritten, pruned, or a baseline file is carried over from
  another clone where the commit is unreachable, the changed-file enumeration fails and
  `microworld_skip_ok` returns 1 (fail closed) rather than silently misrepresenting
  "couldn't compute" as "no changes" (see AC-B2 / [[unreachable baseline]]).

**two-tier allowlist**:
(unit hcb-branch, 2026-09-24) — the frozen `permission_mode` allowlist that gates ask-eligibility
  differently per set in `harness-integrity-gate.sh`. **Set A's tier** includes `default`, `plan`, 
  `acceptEdits`, and `auto`. **Set B's tier** includes `default`, `plan`, and `auto`, explicitly 
  excluding `acceptEdits` (a silent auto-approve on Set B's write paths would cost the gate's own 
  registration surface, so it must not be auto-eligible). The two-tier structure is the exact point 
  defended by acceptance criterion C1.3(b) ("tier-collapse" mutation proof): collapsing the two tiers 
  into one is the specific regression that proof exists to catch. See [[permission-mode allowlist]], 
  [[ask-eligible]], and [[Set A / Set B]].

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
  based on an incomplete or empty changed-file list (see AC-B5d and `microworld_skip_ok`).

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

**offending commit** / the **`offenders:` field**:
(unit item17-4-name-p3-offenders, 2026-09-25) — the commit(s)/path(s) named
  by a `violation` verdict from `hooks/scripts/version-stamp-check.sh`.
  Surfaced as a sixth, trailing, always-present field in the script's output
  line (`offenders: <short-sha>:<path>[,<short-sha>:<path>...]`), computed
  inside the existing per-commit loop from whichever commits it already finds
  to have `cold == cnew` (touched a version-stamped path without a version
  bump). Distinct from the five pre-existing positional fields (the
  `ok`/`violation`/`unknown` verdict itself, `touched:`, `old:`, `new:`),
  which the new field trails without displacing or renumbering. Reads `-` for
  every `ok` and every `unknown` ([[unmeasurable range]]) verdict — populated
  only on `violation`. Closes the one Step 2 criterion the shipped script
  previously failed: a caller no longer has to hand-write a `rev-list` loop
  to find which commit and path actually violated.

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
  its `.claude/` mirror must be kept in sync, and parity is enforced
  mechanically by `tests/validate.sh` (skills mirror parity section). See also [[version-stamped
  file]], [[`--update` semantics]].

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

**Set A / Set B** (harness-integrity-gate sets):
(unit harness-integrity-gate-hardening, 2026-09-09; amended units hcb-branch and
  hcb-prose-context, 2026-09-24) — the two disjoint
  categories of protected file paths in `hooks/scripts/harness-integrity-gate.sh`.
  **Set A** (the persona-config path, can reach `ask` on Write/Edit — via the
  [[human-confirmation branch]] — when `agent_id` is absent and `permission_mode`
  is in [[permission-mode allowlist]]; otherwise denied on both Write/Edit and
  Bash): the harness's own config and
  audit-log surfaces (`.claude/persona-config.json`, `.claude/review-audit.log`,
  `.claude/dispatch-audit.log`, `.claude/microworld-audit.log`,
  `.claude/wip-audit.log`, and their `.seal` sidecars). **Set B** (can reach `ask`
  on Write/Edit — the same [[human-confirmation branch]] mechanism — for exactly
  four paths when `agent_id` is absent and `permission_mode` is in the [[two-tier
  allowlist]] excluding `acceptEdits`; outside that allowlisted-mode-and-path
  combination, denied on Write/Edit; deliberately absent from the Bash branch
  entirely (ADR-0025)): the gate's own registration
  surface (`hooks/hooks.json`, `.claude/settings.json`,
  `hooks/scripts/harness-integrity-gate.sh`, `.claude/hooks/scripts/harness-integrity-gate.sh`). Set B is excluded from the Bash
  branch by [ADR-0025](docs/adr/0025-textual-gate-protection-requires-structural-triggers.md)
  because a text-only gate triggered by mere word presence in Bash commands would
  necessarily fire on prose mentions, not just write attempts — the asymmetry is
  ratified, not an oversight. Introduced together as a pair, not independently. The frozen two-tier `permission_mode` allowlist gates ask-eligibility: see [[two-tier allowlist]] for the distinction between Set A's tier (includes `acceptEdits`) and Set B's tier (excludes it).
  Beyond the allowlist, the two sets' shared [[human-confirmation branch]] differs
  in prompt wording too: Set B carries its own fixed `permissionDecisionReason`
  literal naming the cost of approving a write to the gate's own registration
  surface, distinct from Set A's. So the two sets diverge in **allowlist and
  prompt wording**, not only in the pre-existing ADR-0025 Bash-coverage asymmetry
  described above. See [ADR-0034](docs/adr/0034-human-confirmation-branch-per-call-consent-not-escalation.md)
  for why Set B is a narrower tier of the branch rather than a clone of Set A's.

**human-confirmation branch**:
(unit hcb-prose-context, 2026-09-24) — the branch of `harness-integrity-gate.sh`'s
  `Write`/`Edit` path that, for the persona-selection config (Set A) and the gate's
  own registration surface (Set B) — see [[Set A / Set B]] — and only within a
  frozen per-set allowlist of session shapes (see [[two-tier allowlist]]), returns
  `permissionDecision: "ask"` instead of exiting 2, so Claude Code's own permission
  prompt decides, not the agent. The two sets share this one mechanism and differ
  in their allowlist and their prompt wording, never in whether the mechanism
  itself exists. It never returns `allow`, and it never emits `ask` from a
  subagent. Distinct from a grant branch (an identity-scoped, unilateral
  exemption — this branch hands nobody a unilateral capability) and from an
  override artifact — a file such as `.claude/.dispatch-override` left behind on
  disk — since this branch is a synchronous per-call prompt with no artifact of
  its own. See
  [ADR-0034](docs/adr/0034-human-confirmation-branch-per-call-consent-not-escalation.md).
_Avoid_: escape hatch, grant branch

**amortized / unamortized**:
(unit item16-1-measure-ask-branch, 2026-09-25; disposition recorded in
  [ADR-0035](docs/adr/0035-hcb-branch-measured-disposition-unamortized-but-not-dead.md),
  amending [ADR-0034](docs/adr/0034-human-confirmation-branch-per-call-consent-not-escalation.md))
  — the disposition pair item16-1 used to describe whether the
  [[human-confirmation branch]]'s complexity (two mode tiers, the
  [[asked audit record]]/[[completed audit record]] pairing, and the
  [[registration-presence assertion]]) earns its footprint given how rarely
  the branch actually fires. **amortized**: the branch fires often enough
  that real usage repays its accounting overhead. **unamortized**: it rarely
  or never fires — measured 2026-09-26: 21 `asked` audit records (all
  confirmed synthetic/probe-generated, not organic), 0 `completed` records,
  0 organic fires, across ~60 days of recorded history. **Important nuance —
  do not read "unamortized" as "useless":** ADR-0035's critical reframing is
  that a near-zero fire rate has two indistinguishable explanations: dead
  weight nobody exercises, or a working deterrent that successfully keeps
  agents on the sanctioned `bin/cli.js --update` route, which writes via a
  child-process filesystem call that structurally bypasses `PreToolUse`
  entirely and so never trips the branch at all. Fire-count alone cannot
  distinguish the two, so "unamortized" here names the measurement, not a
  verdict that the mechanism should be removed or shrunk.

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
  [[documented residual]], [[bypass family]], [[family table]]; the
  per-command form, one pinned real command per row, is
  [[accepted over-block (OB row)]].

**kill set**:
(unit hcb-regcheck, 2026-09-24) — for a given mutant and [[cell space]], the subset of
  cells whose verdict differs between the mutant and the shipped (correct) implementation.
  A cell's verdict is derived the same way a normal caller derives it: exit code AND
  response body together (never exit code alone). Kill sets are the foundation of
  [[kill-set relation table]]s: by comparing the kill sets of multiple mutation controls
  within a shared cell space, a test proves that each control is orthogonal (disjoint) or
  properly nested (one is a strict subset of another) according to the intended invariant.
  Contrasted with "test killed a mutant" (casual language for "mutant failed"), kill set
  is a formal technical term denoting the precise cells in the coordinate system where a
  mutant's behavior diverges from baseline. See [[cell space]], [[tier isolation]].

**kill-set relation table**:
(unit hcb-regcheck, 2026-09-24) — a hardcoded literal table (not derived from measurement
  — doing so reproduces R11's exact defect: deriving a test's own expected verdicts from
  the code under test) stating the expected set-relation (DISJOINT, NESTED, EQUAL, etc.)
  between every pair of a family of mutation controls. Used when blanket pairwise
  disjointness is not the right invariant — for example, when one mutant's [[kill set]]
  is a strict superset of another's by design, or when the scopes are properly hierarchical.
  A [[kill-set relation table]] anchors the test's invariant claims to a fixed coordinate
  system ([[cell space]]), making the relationship between controls provable rather than
  implicit. Each row names two control identifiers and states their expected relation.
  Entries use machine-checkable predicates (e.g., `{c1_kill_set} ⊂ {c2_kill_set}`, read
  as "c1's cells are a proper subset of c2's cells"). See [ADR-0032](docs/adr/0032-bash-output-cap-not-command-rewriting.md) context for the history of why measurement-derived expectation is unsafe.

**tier isolation**:
(unit hcb-regcheck, 2026-09-24) — a property distinct from [[kill set]] containment: that
  a narrower mutant's effect is confined to its intended tier/subset and does not leak into
  cells outside it. Exemplified in test code: a Set-B-only tier-collapse mutant must leave
  every Set A cell's verdict bit-identical to the shipped gate (proving the gate correctly
  isolates tiers and doesn't accidentally cross-couple them). Tier isolation is proven via
  positive assertion (all cells in the other tier remain green) rather than just absence
  of regression. Distinct from the three other senses of "tier" in this glossary
  ([[effort override / effort tier]], [[Tier A / Tier B bundle classification]]) — here
  it refers to the conceptual boundary between functional layers or permission scopes (e.g.,
  Set A vs. Set B in the harness-integrity-gate). Violations of tier isolation are caught
  by mutation controls that have "narrower" scope in their title or comments but whose
  [[kill set]] unexpectedly includes cells outside that scope. See [[cell space]],
  [[kill set]], [[kill-set relation table]].

**registration-presence assertion**:
(unit hcb-regcheck, 2026-09-24) — the fixed-literal-table test (criterion C7 in
  `tests/harness-integrity-gate.test.sh`) that mechanically verifies `hooks/hooks.json`
  still registers `harness-integrity-gate.sh` on all three event/matcher pairs
  (`PreToolUse Write|Edit`, `PreToolUse Bash`, `PostToolUse Edit|Write`) as a standalone
  check. Distinguished by being hardcoded in the test, NOT derived from `hooks/hooks.json`
  itself, which would reproduce the vacuous-expectation defect (see test comment citing
  `tests/cli-hook-propagation.test.js:147-159` and R11). This assertion is the out-of-band
  reconciliation mechanism for the Set B [[U5 pairing ambiguity]]: when an `asked` audit
  record exists but no matching `completed` record (because a Set B write suppressed its own
  completion log), the registration-presence assertion proves whether the gate's surface
  remains intact (write was denied) or vanished (write was approved and disabled the gate).
  See [ADR-0034](docs/adr/0034-human-confirmation-branch-per-call-consent-not-escalation.md) and
  `docs/trust-model.md` row 11 for the asymmetry bounded here.

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
  [[watch-map]] and [[Microworld bundle]]s.

**orphaned bundle**:
(unit item19-1-classify-orphans, 2026-09-25) — a bundle directory under
  `microworlds/` with no `tests/watch-map.json` entry and not recorded as a
  [[retired bundle]] either — genuinely unregistered and unaccounted-for, so
  nothing watches its files and nothing runs it. Item 19 began from a Fable
  adversarial review's counting-error claim ("10 bundles, 1 watch-map entry",
  a 10% utilization reading); the corrected count is 7 of 10 registered
  (70%), leaving exactly 3 orphaned bundles at the time of measurement
  (`hdg-anchor-1`, `rev-gh377-5-probe`, `rpg-canon-2`), all since dispositioned
  by item19-3. **The counting trap that originated this term:**
  `jq '.entries|length'` (correct — 7, the array nested under the top-level
  `entries` key) vs. `jq 'keys|length'` (wrong — 1, because it counts the
  single top-level `entries` key itself, not its contents). Any future
  measurement of watch-map registration must use the former.

**retired bundle**:
(unit item19-3-close-registration-gap, 2026-09-25) — a bundle directory
  under `microworlds/` deliberately excluded from the [[orphaned bundle]] /
  registration-gap check by a recorded entry in `tests/watch-map.json`'s
  top-level `retired[]` array (each entry: `{"id": "<bundle-slug>", "reason":
  "<why>"}`). Used for `rev-gh377-5-probe`, retired with reason "one-shot
  probe (item19); run.sh set to mode 644 (item19-3) to prevent dashboard
  invocation". **Retirement is a bookkeeping label — it does NOT block
  execution by itself.** `bin/microworld-dashboard/discover.js`'s invoke path
  gates solely on whether a bundle's entry file (`run.sh`) is executable; it
  performs no check against `tests/watch-map.json` or the `retired[]` array
  at all. Actually disabling a retired bundle therefore requires a separate,
  required action: stripping the executable bit (e.g. `chmod 644 run.sh`) —
  a `retired[]` entry with no matching `chmod` is cosmetic only, per
  item19-1/19-3's finding that the microworld dashboard's invoke path is
  gated on the executable bit alone, not on watch-map or retired-list
  membership.

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

**content-typed contract**:
(unit rgh-u3-1, 2026-10-06) — a dispatch contract whose elements carry literal
  content rather than pointers: [[edit item]]s supply inline `before:`/`after:` or
  `insert-after:` payloads, [[command item]]s supply expected `exit:` and optional
  `stdout:`, and **Acceptance criteria** items name explicit [[mutation proof]]s
  (e.g., "skip edit 3"; the edit that makes the check fail). Contrasted with a
  pointer dispatch, which references steps or sections without reproducing their
  content (e.g., "as specified in the plan", now banned). The term originates in
  the `agents/task-master.md` **Per-unit dispatch prompts** section: "Each element is
  content-typed, and `node bin/contract-score.js` scores a contract against rows R1-R7."
  See
  [[edit payload / artifact body]] for the payload vs. body distinction, [[contract
  score]], and [[mechanical obligations (R2)]].

**contract score**:
(unit rgh-u0-2b, 2026-10-06) — the R1-R7 lead / S1-S5 scribe rubric score
  computed by `bin/contract-score.js` for a dispatch contract. The scorer is
  read-only; it is not the responsibility of `scripts/unit-outcomes.js` to verify
  or adjust scores, only to record them. See [[unit-outcome export]], [[content-typed
  contract]].

**contract self-check**:
(unit rgh-u3-1, 2026-10-06) — the pre-dispatch verification task task-master runs
  via `node bin/contract-score.js <contract>` to confirm a dispatch contract reaches
  `"score":7` and `"sizeOver":false` before handing off to `lead-programmer`. Distinct
  from spec-master's Self-check step (which replays recorded FAIL classes); this
  term refers specifically to task-master's mechanical validation of the nine-element
  dispatch contract's structure. Documented in the `agents/task-master.md` **Pre-dispatch
  self-check** section. Run via CLI invocation requiring every `run:` criterion to
  pass at current HEAD or already pass-correctly at baseline, and every `anchor:` to
  be grep-verifiable.

**edit item / command item**:
(unit rgh-u3-1, 2026-10-06) — the two types of numbered items under the
  `## Ordered edits` (R1) section of a [[content-typed contract]]. An **edit item**
  carries `file:` (a backticked path), `anchor:` (non-empty prose description of
  a heading, symbol name, or line range qualified by commit SHA), and one payload
  form: `before:` + `after:`, `insert-after:`, or `delete:`, each holding the
  literal text inline or in a fenced block (see [[edit payload / artifact body]]).
  A **command item** carries `command:` (inline code) and `expect:` (exit code
  integer, optionally `stdout:` fragment or `empty`), with no `file:`, `anchor:`,
  or payload fields. Neither form allows pointer bodies such as "as specified".
  Documented in the `agents/task-master.md` **Per-unit dispatch prompts** section
  under the "5. `## Ordered edits` (R1)" subheading.

**edit payload / artifact body**:
(unit rgh-u3-1, 2026-10-06) — a critical distinction in [[content-typed contract]]
  authoring. An **edit payload** is the literal, required text of one [[edit item]],
  either inline or in a fenced block (`before:`, `after:`, `insert-after:`, or
  `delete:` field contents). An **artifact body** is a whole source file, log dump,
  spec section, or similar large artifact pasted into the prompt — now banned from
  dispatch contracts (reference by path instead). The payload must be inline-sized,
  and any payload exceeding `maxInlineBlockLines` (default 80 interior lines) splits
  into consecutive edit items. Documented in the `agents/task-master.md` **Edit
  payloads versus artifact bodies** section within **Per-unit dispatch prompts**.

**mechanical obligations (R2)**:
(unit rgh-u3-1, 2026-10-06) — the version-stamped-path sub-rules within R2 of a
  [[content-typed contract]]'s `## Ordered edits` section. When an affected file is
  `agents/*.md` or under `templates/`, R2 obligates the contract to include five
  numbered items: (1) update `.claude-plugin/plugin.json`'s `version` field to the
  exact new version; (2) update `package.json`'s `version` field to match; (3) add
  a `CHANGELOG.md` entry under the `## [Unreleased]` heading; (4) run
  `node bin/cli.js --update` as a [[command item]]; (5) stage and commit via `git add -A
  agents CHANGELOG.md package.json .claude-plugin && git add -u -- .claude && git commit`.
  The acceptance-criteria set must include one run of `bash hooks/scripts/version-stamp-check.sh`
  verifying the range is `ok`. Defined in the `agents/task-master.md` **Mechanical
  obligations (R2)** section within **Per-unit dispatch prompts**. See
  [[content-typed contract]], [[edit item / command item]].

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
  violations are logged, not blocked); escape hatch
  `.claude/.dispatch-override` (single use plus a bounded 10-second replay;
  see [[replay window]]). H3 is anchored by a `commit:`
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

**replay window**:
(unit item11-3, 2026-09-26) — the 10-second idempotency window in
  `hooks/scripts/dispatch-hygiene.sh`'s dispatch-override escape hatch: after
  `.claude/.dispatch-override` is read and its sentinel deleted once, a
  second invocation whose payload key matches is honoured again as a replay
  (logged `override-replay=`, the stamp not re-consumed) if it arrives within
  the 10-second window of the first honouring. The payload key is a `cksum` over `subagent_type` plus the prompt.
  Exists because a doubly-registered `PreToolUse` hook was measured
  double-firing per tool call — 100% failure rate sequential, 15% (3/20)
  parallel — before the window existed. See
  [ADR-0011](docs/adr/0011-dispatch-override-idempotency-window.md).

**description collision**:
(unit gwd-2, 2026-09-11, [ADR-0031](docs/adr/0031-grill-with-docs-model-invocable.md)) —
  the condition where two or more [[Preloaded skill]]s with near-identical descriptions
  are both model-invocable, creating ambiguity: a user request like "grill me" might invoke
  either `grill-me` ("A relentless interview to sharpen a plan or design.") or `grill-with-docs`
  ("A relentless interview to sharpen a plan or design, which also creates docs (ADR's and
  glossary) as we go.") depending on the harness's selection order. The descriptions cannot
  be edited to disambiguate because both are **drift-tracked skills** — their descriptions
  are reconstructed byte-for-byte from upstream by the `fm-noflag` declared-deviation type,
  and editing the descriptions would break the `fm-noflag` declared-deviation class check.
  The only available mitigation is explicit prose naming of the intended skill in the persona
  or dispatch context (e.g., in `agents/spec-master.md`'s instructions to use `grill-with-docs`
  rather than bare "grilling"), since descriptions themselves cannot be used as a
  disambiguation surface.

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

**agent-memory write** (synonym: **memory-scope write**):
(unit #288, 2026-08-11) — a `Write` or `Edit` tool_use whose `file_path`
  targets the agent-memory directory tree: `.claude/agent-memory/` or
  `.claude/projects/*/memory/`. Distinct from general filesystem writes;
  specifically observes memories saved by agents during their work. Recorded
  by `hooks/scripts/agent-audit.sh`'s A8 section (Agent-memory writes) as an
  informational audit event (never gating, never a finding). "Memory-scope
  write" is the term used in the agent-memory-dirt-blocks-pass spec
  (2026-09-27) for this same event; the two are synonyms, not distinct
  concepts. See [[gh-304 dual-marker incident]] for the concurrency defect
  that motivated tracking memory writes. **Historical:** concurrent writes to
  `.claude/agent-memory/` used to dirty the git tree and fail the reviewer's
  whole-tree clean-tree precondition, blocking an unrelated unit's PASS —
  fixed by narrowing that precondition to exclude
  `.claude/agent-memory/**` conditionally; see
  [ADR-0037](docs/adr/0037-agent-memory-excluded-from-clean-tree-precondition.md)
  and [[clean-tree precondition]].

**clean-tree precondition**:
(unit memdirt-3, 2026-09-27) — the reviewer's On-PASS requirement, before
  writing a `.pass` marker, that no tracked file carries an uncommitted
  change: `git diff --quiet HEAD` must exit 0 (`agents/reviewer.md:57-58`,
  `:115-116`). Named here for the first time even though it was implemented
  by [ADR-0015](docs/adr/0015-commit-anchored-pass-markers.md) — that ADR
  never defined the check as a standalone term. Narrowed by
  [ADR-0037](docs/adr/0037-agent-memory-excluded-from-clean-tree-precondition.md)
  to exclude `.claude/agent-memory/**` conditionally: the exact command is
  `git diff --quiet HEAD -- ':/' ':(exclude,top).claude/agent-memory'`, and
  the exclusion does not apply when the reviewed unit's own affected-files
  set names a path under `.claude/agent-memory/`, in which case the
  unexcluded whole-tree form still applies. See [[agent-memory write]] and
  [[ambient dirt]].

**ambient dirt**:
(unit memdirt-3, 2026-09-27) — uncommitted working-tree residue left behind
  by a different persona's session (most commonly an
  [[agent-memory write]]'s note file or `MEMORY.md` index line) that a
  later, unrelated agent must notice, attribute to its true owner, and get
  cleared before its own unit's review can be signed off. The
  agent-memory-dirt-blocks-pass spec (2026-09-27) named and closed this: the
  fix is not to sweep or stash someone else's ambient dirt (that recreates a
  measured shared-worktree stash race), but for every memory-granted persona
  to commit its own memory-scope writes before its turn ends, per the
  protocol's `## A note on \`memory\`` section. See
  [ADR-0037](docs/adr/0037-agent-memory-excluded-from-clean-tree-precondition.md)
  and [[clean-tree precondition]].

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
  (unkeyed/global): dispatch override (`.dispatch-override` escape hatch,
  single use plus a bounded 10-second replay — see [[replay window]]) and its
  consumed marker (`.dispatch-override.consumed`, with
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
  avoid duplicate reporting. Implemented in `microworld-queue.sh`, `stop-gate-core.sh`,
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
  the ownership changed (mutation-proof direction does not hold). Core to
  [[Mutation-proved]] effectiveness — a bundle with a vacuous direction test will always
  pass, masking regression, so the direction must be verified by reverting the criterion
  and observing it flip. See mutation discipline in the spec governance context.

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
  glob-based scan each iteration; files are deleted after processing. See `microworld-queue.sh`.

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

**inert-key defect**:
(unit item18-2, 2026-09-25; first instance resolved in unit #476) — a failure mode 
  where a new persona-config or `.claude/settings.json` key is added to the 
  `templates/` scaffold but remains permanently silent/inert in already-adapted 
  projects because `bin/cli.js --update` branches before reaching the fragment 
  merge step at line 2387 (the branch occurs at line 2188). A new key thus 
  passes acceptance criteria for the fragment template (e.g., `git grep '<newKey>'`) 
  and all scaffold tests, yet never reaches existing installations. **Prevention pattern:** 
  any new config key must include (a) the template fragment change, (b) an explicit 
  backfill in the `runUpdate` block using the additive-merge pattern (see 
  [[bashOutputMaxChars]]), and (c) a mutation proof (revert the backfill hunk and 
  re-run the test to verify it fails). Examples: `bashOutputMaxChars` (unit #478, 
  backfill at `bin/cli.js:1293`), `humanReviewMode` (earlier precedent), 
  `defaultImplementerModel` (unit item18-2, backfill at `bin/cli.js:349-353`). 
  Glossary and precedent documented at `.claude/agent-memory/spec-master/cli-update-never-reaches-settings-fragment.md`.

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
  escalation process. (2) **Orchestrator ruling**
  — a self-authorized judgment call by the orchestrator, recorded in the **Rulings ledger**
  and prefixed with the `RULING` token. The two senses refer to different actors
  (human vs. orchestrator) and different recording mechanisms (escalation packet vs.
  advisory log). Context determines which is meant; when ambiguous, prefix with
  "human" or "orchestrator" to clarify.

**rubric era**:
(unit rgh-u0-2b, 2026-10-06) — the set of task-master-authored units whose
  `contract_ts` is after U3-4's `pass_ts` (units created after the rubric-contract
  protocol was implemented). Distinguished from [[pre-rubric sonnet era]] (units
  predating rubric adoption) to segregate rubric-era dispatch patterns (includes
  contract score, **era-inferred** tier when transcript missing) from pre-rubric
  patterns. The two are disjoint and together cover every sonnet-era unit. See
  [[pre-rubric sonnet era]], [[era-inferred]], [[unit-outcome export]].

**pre-rubric sonnet era**:
(unit rgh-u0-2b, 2026-10-06) — the complement of the [[rubric era]] within the
  sonnet era of this repo: units whose `contract_ts` is absent, null, or before
  U3-4's `pass_ts` (units predating the rubric-contract protocol implementation).
  Distinguished from [[rubric era]] (units authored after rubric adoption) to
  segregate pre-rubric dispatch patterns (no contract score, **era-inferred** tier)
  from rubric-era patterns. The two are disjoint and together cover every sonnet-era
  unit. See [[rubric era]], [[era-inferred]], [[unit-outcome export]].

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

**threshold-crossing rate**:
(unit item13-1-measure-split-cost, 2026-09-25) — the measured proportion of
  specs in `docs/plans/` that cross the [[publish threshold]] (≥6
  dispatchable units — see `CONTEXT.md`'s **publish threshold** and
  **fast-path threshold** entries), the gate on whether `task-master` and
  `to-tickets` are exercised at all. Measured 2026-09-25: 14/94
  [[confirmed-crossing]] (≈14.9%), rising to a 23/94 ceiling (≈24.5%) once
  [[ceiling-only]] specs are counted optimistically, and 6/48 (≈12.5%) when
  restricted to [[post-era]] specs only. Produced to answer whether
  `task-master`'s ≥6-unit gate is "rarely exercised", as a Fable adversarial
  review claimed. See [[confirmed-crossing / ceiling-only]] and
  [[pre-era / post-era]] for the two classification schemes behind these
  numbers.

**confirmed-crossing / ceiling-only**:
(unit item13-1-measure-split-cost, 2026-09-25) — the two-bucket
  classification item13-1 used to bound its [[threshold-crossing rate]]
  measurement, since not every spec in `docs/plans/` states a countable unit
  total. **confirmed-crossing**: a spec self-reports an explicit unit count
  (e.g. a "Dispatchable units" line or a dispatch contract listing) that is
  ≥6, so the crossing is directly countable from the document itself.
  **ceiling-only**: a spec was merely routed to `task-master` — i.e. treated
  as above the fast-path threshold — with no confirmable unit count stated
  anywhere in the document; counted toward the upper ceiling bound only, not
  the confirmed rate, since the actual count could sit anywhere at or above
  the threshold. The split keeps the measurement honest about what is
  verified versus merely assumed.

**pre-era / post-era**:
(unit item13-1-measure-split-cost, 2026-09-25) — the partition of
  `docs/plans/` specs by the 2026-08-15 date the fast-path threshold moved
  from ≥3 to ≥6 dispatchable units (per
  `docs/plans/2026-08-15-ceremony-reduction-solo-operator.md:985`, Step 3,
  [ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md)). **pre-era**
  specs were written under the old ≥3 threshold and would misclassify if
  measured against the current ≥6 line; **post-era** specs were written
  after the move and are the only specs item13-1 could safely compare
  against ≥6 without conflating two different rules under one count. Used to
  produce the narrower, post-era-only 6/48 (≈12.5%) figure in
  [[threshold-crossing rate]] alongside the repo-wide, mixed-era figure.

**F9 convention**:
(unit #241) — resume-by-name on `INSUFFICIENT-CONTEXT`: when
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
(2026-09-11, unit gwd-1) — the `fm-noflag` declared-deviation class (stripping the
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

**U5 pairing ambiguity**:
(unit hcb-posttool, 2026-09-24) — the documented, deliberate asymmetry in interpreting
  a missing [[`completed` audit record]] after an [[asked audit record]] for an [[ask-eligible]]
  write. **For Set A** (persona-config path), an `asked` line with no matching `completed`
  line means unambiguous denial — the user rejected the permission prompt, so the write
  never reached `PostToolUse` and never logged completion. **For Set B** (gate-registration
  paths), the same situation is AMBIGUOUS: an `asked` with no `completed` could mean denial
  (user rejected), OR it could mean the write was approved and succeeded, but then the write
  itself disabled the gate's own ability to log completion (e.g., by removing the hook's
  `hooks.json` registration). The ambiguity is deliberate, not a bug — the test suite has an
  enumerated-file-list assertion documenting that nothing in the repo claims otherwise. This
  asymmetry exists because Set B is the gate's own registration surface: a successful write
  to Set B can unregister the hook that logs the completion. Named "U5" after the unit number
  scheme (`U` = unit finding, `5` = the fifth criterion affected by this pairing rule).

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

**drift-tracked skills**:
(unit gwd-1, 2026-09-11) — the set of vendored mattpocock skills whose
  content is byte-diffed against upstream by `scripts/resync-vendored-skills.sh`.
  All drift-tracked skills are checked via either the `fm` (frontmatter) or
  `fm-noflag` reconstruction type (see `fm-noflag` declared-deviation class).
  As of unit gwd-1, there are 9 drift-tracked skills: `grill-me`, `grill-with-docs`,
  `grilling`, `handoff`, `tdd`, `diagnosing-bugs`, `improve-codebase-architecture`,
  `codebase-design`, and `domain-modeling`. The `--check` flag on the resync script
  reports per-skill status (`[OK]` for match, or drift details if changed). Distinct
  from the separate `REPOINT_SKILLS` set (skills pulled from upstream via live
  `skills@latest` rather than pinned to a specific commit). See `docs/maintenance/resync-vendored-skills.md`.

**hook block event**:
(unit #288, 2026-08-11) — a transcript event (a `tool_result` entry in
  `message.content[]` with `is_error: true`) matching the pattern
  `PreToolUse:<Tool> hook error: [<path>/<hook>.sh]: BLOCKED:`, signaling
  that a `PreToolUse` hook refused a tool call. Distinct from the existing
  **grant-denied** term, which is an append-only log record in
  `.claude/review-audit.log` (not a transcript event). Hook block events are
  recorded by `hooks/scripts/agent-audit.sh`'s A7 section (Hook block events) as
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

**gh-304 dual-marker incident**:
(unit #307, 2026-08-09) — a defect case
  where a bare-name `SendMessage` reached an idle reviewer session from an
  unrelated spec/plan, causing that session to perform a genuine review and
  write a conflicting marker for a different unit. Motivated the "Reviewer
  re-tasking discipline" rule: a different unit always requires a fresh `Agent`
  dispatch (writing its own review-join stamp), never a message-resume. See
  `agents/orchestrator.md:137` and the history at commit `b9764de` (unit #311).

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
  which only deletes [[Resolved packet]]s. Packets remain in this
  state while awaiting human review and decision. Distinct from the reviewer's existing
  cleanup mechanism (which deletes both marker and packet when escalation is resolved
  via the [[DECISION channel]]); the sweep is a supplementary manual operation for
  orphaned/leftover packets (e.g. after a crash).

**Sweep**:
(unit human-review-cleanup-1, 2026-08-24; broadened unit #409, 2026-08-25) — the
  operation performed by `bin/human-review-cleanup.sh`: a retention-gated pass
  over five artifact classes in `.claude/`, identifying and deleting stale items
  in each. Sweeps: (1) [[Resolved packet]]s from `.claude/human-review/`,
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

**The human-decision gate** (`human-decision-gate.sh`):
(unit #325, 2026-08-11, Step 1 of #324; extended units hdg-lexer-1, hdg-prose-2,
  hdg-prose-2-fix2, 2026-08-24) — the new `PreToolUse` hook (`Write|Edit` and
  `Bash` matchers) that blocks **every** agent identity from writing a [[DECISION
  file]] — reviewer included, empty/main-session `agent_type` included. Contrast
  with `reviewed-path-gate.sh`: that gate has a grant branch (the reviewer may
  write `.claude/reviewed/*.pass`, and a no-reviewer fallback exists for the main
  session or the orchestrator persona); this gate has no grant branch and no fallback — no identity
  is ever granted a DECISION write; the single exception, an `ask` that leaves the
  write to a human approving its exact bytes at Claude Code's permission prompt (never an `allow`), is in the amendment below. **Reads are allowed** in both gates, including
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
  `reviewed-path-gate.sh`. The decision to keep this gate as-is (no grant
  branch, no size reduction) rather than narrow it further is recorded, with
  its rationale, in `docs/adr/0036-human-decision-gate-keep-as-is-mode-off.md`
  (ADR-0036).
  **Amended (esc-chat-2/2b, esf-gate-bytes; recorded esc-chat-4, 2026-10-03,
  [ADR-0039](docs/adr/0039-prompt-confirmed-decision-write.md)):** the gate
  still has no grant branch, but it now has one **ask** branch. For the
  [[prompt-confirmed decision write]] only, when [[prompt-eligible]] holds, it
  emits `permissionDecision: "ask"` (never `allow`) and appends a
  [[`decision-gate-asked` audit line]] first. Eligible modes are default,
  acceptEdits and auto; plan denies because it is read-only, so there is no
  write approval to make; bypassPermissions, dontAsk, an empty and an unknown
  mode deny. "Main session only" means "no `agent_id`", a premise that is
  unmeasured for agent-teams teammates
  (`docs/plans/2026-10-02-escalation-followups.md` R4): the identity probe
  (`docs/experiments/2026-10-03-probe-hook-identity.md`, `Outcome: D`)
  observed no genuine teammate, so no gate change followed. The `Write`/`Edit`
  branch always denies a DECISION target. Config: the gate reads exactly one
  field, `reviewGating.mode`; under `off` it exits 0 (inert). Whether Claude
  Code's Bash prompt shows the full heredoc was measured with a probe hook,
  not this gate, on claude 2.1.288 (default) and 2.1.289 (acceptEdits,
  auto) (see [[Ship gate]]). A closed note:
  at 60b454f, `is_sanctioned_marker_write`'s `[[:space:]]` separators also
  matched Unicode spaces under a UTF-8 locale (under C.UTF-8: U+1680,
  U+2000-200A except U+2007, U+2028, U+2029, U+205F and U+3000; measured in
  bash), so a reviewer's marker write spelled with one reached allow. 9b98f10
  (esf-hardening-3) closed it with `local LC_ALL=C` in that function; only
  space and tab still reach allow, and PG23 in `tests/human-decision-gate.test.sh` is
  the regression test.

**dashboard-originated decision write**:
(unit #377, Step 7, 2026-08-31) — a **DECISION file** write that originates from
  the **Microworld dashboard** server, as opposed to the classic path where a human
  types the file manually in their terminal. Characterized by two properties: (1) the
  write is gated on a human-entered **confirmation code** delivered over the
  controlling terminal (`/dev/tty`), ensuring the human is present and the action is
  intentional; (2) the written **DECISION file** carries a `via: dashboard` line in
  the file body itself (`decision-block.js:126`, fed by `server.js:362`) — not in
  the audit log, which instead gets its own, separate `decision-write-via-dashboard`
  line (`server.js:525`) with no `via:` token. **Update (esc-chat-4,
  2026-10-03):** a third value, `via: prompt`, now occurs: it is in
  `VIA_ROUTES`, `composeDecisionBlock` composes it when called with
  `via: 'prompt'`, the orchestrator's in-session template writes it, and the
  human-decision gate requires it, all for the [[prompt-confirmed decision
  write]] (the in-session sibling of this path); the two-state
  description that follows predates it. As of unit #377 only two `via:` states actually
  occurred: **absent** (both the hand-typed-in-terminal path and the copy/heredoc
  dashboard path pass no `via` field, so `decision-block.js:122` omits the line
  entirely) and **`via: dashboard`** (the confirmed-write path above). `via:
  terminal` exists only as an unused entry in `decision-block.js`'s `VIA_ROUTES`
  allowlist — no current code path emits it. Both authoring paths satisfy the [[DECISION file]]'s
  property that no agent can complete the write without a human — the dashboard is not an agent identity, and the
  confirmation-code gate and TTY delivery mechanism enforce the same human-presence
  requirement as the terminal path, just via a different channel. Exists only when
  the dashboard is started with a controlling terminal (not `--dashboard-no-tty`);
  [[read-only mode]] explicitly refuses `/api/decision/arm` and `/api/decision/run`
  because the launch token is an [[execution credential]], not a read credential. See
  [[confirmation code]], [[Microworld dashboard]], and [[DECISION file]].

**prompt-eligible**:
(esc-chat-2/2b, esf-gate-bytes; named esc-chat-4, 2026-10-03, ADR-0039) — the
  predicate `is_prompt_eligible_decision_write` in `human-decision-gate.sh`:
  true only when a Bash command is exactly the [[prompt-confirmed decision
  write]] heredoc (`cat > <abs>/.claude/human-review/<ID>/DECISION <<'EOF'`,
  `<abs>` equal to `$CLAUDE_PROJECT_DIR`, space/tab separators, `>` only, the
  sole `EOF` line last), from a payload with no `agent_id`, in
  `permission_mode` default, acceptEdits or auto, with a body that passes the
  grammar (including the [[reserved-key screen]] and the
  [[lookalike lead-in]] screen), a standing `.escalated` marker whose first
  line names the same id and timestamp, no existing DECISION, and neither the
  packet nor `human-review/` a symlink. True means `ask`, never `allow`.
  Distinct from [[ask-eligible]] (the harness-integrity gate's five paths) and
  from that gate's [[permission-mode allowlist]], which is a different list.

**reserved-key screen**:
(esc-chat-2b; named esc-chat-4, 2026-10-03) — the check that refuses a
  reason continuation line starting with a body key (`DECISION `, `by:`,
  `via:`, `examples:`, `reason:`), so a reason cannot forge a second key line.
  ASCII case-insensitive, tolerating leading and pre-colon spaces; the gate's
  `reserved_re` and the composer's `RESERVED_KEY_RE` match the same set.

**lookalike lead-in**:
(esf-gate-bytes; named esc-chat-4, 2026-10-03) — a non-ASCII byte before a
  continuation line's first ASCII letter or digit (NBSP, U+3000 and similar),
  which could render as an indent or key the file does not hold. Refused by
  the gate's LEAD-NONASCII screen in `forbidden_bytes()` (run under
  `LC_ALL=C`) and the composer's `LEAD_NONASCII_RE`; the refusal fails closed
  to the terminal route. Non-ASCII text after an ASCII letter or digit still
  asks. The `LC_ALL=C` setting only matters in a non-UTF-8 multibyte locale
  (test case PG20-gb18030).

**`decision-gate-asked` audit line**:
(esc-chat-2; named esc-chat-4, 2026-10-03) — the line
  `<ts> decision-gate-asked identity=<agent_type> task=<id> route=<route> mode=<permission_mode>`
  that `human-decision-gate.sh`'s `ask_decision()` appends to
  `.claude/review-audit.log` **before** the human answers the prompt. An asked
  line with no DECISION file afterwards means the human declined, the ask
  was denied (including in a headless run, where no human answers), or the
  approved write failed. There is no PostToolUse partner line; unlike the
  harness-integrity gate's [[asked audit record]], the evidence of completion
  is the DECISION file itself, whose body carries `via: prompt`.

**Ship gate**:
(esc-chat-1-fix; named esc-chat-4, 2026-10-03) — the final
  `Ship gate: GREEN|RED` line that `scripts/probe-bash-ask.sh` writes into the
  esc-chat-1 record (`docs/experiments/2026-10-01-probe-bash-ask.md`). GREEN
  needs, for each of default, acceptEdits and auto, an observed prompt, an
  observed fully visible heredoc and an observed decline that left no file,
  plus three passing cleanup checks; the gate re-checks default, acceptEdits
  and auto against each mode's own [[dialog block]] and each mode's own
  [[decline block]] (an `out.txt: absent` line, no `out.txt: present` line,
  no `out.txt` in the listing). **History:** the first record (cbb918e) was
  graded GREEN by the script but review FAILed it on evidence (no dialog
  text saved; the run spanned 2.1.287 and 2.1.288). The fixed script
  (253106e) was re-run (@ 39f0850); that record (229138e) read GREEN and
  passed review, but its Decline rows had no on-record evidence. The script
  was fixed again (6d30470) to save and gate on decline blocks and to list
  plan files under Side effects; the operator's third record (7e04acd,
  self-reported) reads `Ship gate: GREEN` and passed review. Both earlier
  records are superseded. **Measured**, per the record's Version note
  (default 2.1.288; acceptEdits and auto 2.1.289; never restate it as one
  version): in default, acceptEdits and auto, the probe's own always-`ask`
  hook (not `human-decision-gate.sh`) on a Bash heredoc rendered a
  permission dialog showing the full multi-line command, and declining
  created no file; headless `-p` denied the call; dontAsk and
  bypassPermissions also prompted and plan was not driven (all
  informational). **Not measured:** the real gate end to end, other CLI
  versions, teammate identity. **Evidence limits:** each dialog block has a
  stray " settings.json to update hooks" render fragment (harmless); the
  plan run wrote a plan file outside the scratch dir, which the record lists
  under Side effects (not cleaned up, not gated). The RED rules, which
  this result did not trigger: RED in default (or a heredoc that is not
  fully visible) returns the design to spec-master; RED in acceptEdits or
  auto drops that mode (ADR-0039). The second "Interrupted" line in the
  auto post-decline pane is analysed in
  `docs/experiments/2026-10-04-auto-double-interrupt.md` (cause not
  determined; grading unaffected). A material CLI upgrade re-runs the probe.

**dialog block**:
(esc-chat-1-evidence; named esc-chat-5, 2026-10-03) — a block at the top of
  the esc-chat-1 record's appendix holding one mode's permission dialog
  text (from the ` Bash command` header to "Do you want to proceed?"),
  captured by `scripts/probe-bash-ask.sh` before the decline key is sent.
  Headed `### dialog: <mode> <N> lines, claude <version>`; the line count
  is a length prefix, so the script's `gate()` reads each block by its
  declared length and never parses the dialog text as record structure. The
  Display row is graded from that text, and `gate()` re-checks default,
  acceptEdits and auto against their own blocks. It exists because the
  first record saved panes only after the decline, when the dialog was
  gone (see [[Ship gate]]).

**decline block**:
(esc-chat-1-evidence2; named esc-chat-7, 2026-10-03) — a block in the
  esc-chat-1 record's appendix, after the [[dialog block]]s, holding one
  mode's Decline evidence: the filesystem check made after the decline key
  is sent, `out.txt: absent` or `out.txt: present`, then the `ls -Aq`
  listing of the scratch dir. Headed `### decline: <mode> <N> lines`, the
  line count again a length prefix. The Decline row is derived from that
  saved text, and `gate()` re-checks default, acceptEdits and auto against
  their own blocks; it requires exactly one decline block per gated mode
  (default, acceptEdits, auto), so a missing or duplicate block gives RED;
  the dontAsk and bypassPermissions blocks are written but not graded
  (parsed for structure only). It is not pane text: the post-decline pane
  in the appendix is context only. It exists because the 229138e record graded
  Decline from a check it never saved (see [[Ship gate]]).

**subagent-shaped**:
(esf-eid-probe; named esc-chat-5, 2026-10-03) — the `Teammate check:` value
  that `scripts/probe-hook-identity.sh` gives a would-be teammate whose hook
  payload looks exactly like a subagent's: it has an `agent_id`, the lead's
  `session_id`, a `SubagentStop` with that `agent_id` and `session_id`, and
  no payload key the subagent control lacks. Such a candidate is not counted
  as a genuine agent-teams teammate, so the record's outcome is D (no gate
  change). The 2026-10-03 identity record
  (`docs/experiments/2026-10-03-probe-hook-identity.md`) reads
  `Teammate check: subagent-shaped`, `Outcome: D`. Limit, stated by the
  script: a real in-process teammate that carries those same fields cannot
  be told from a subagent, which is conservative because both gates already
  deny any non-empty `agent_id`. Not evidence about whether a teammate can
  lack an `agent_id` (that premise stays unmeasured; followups plan R4).

**flag tombstone**:
(esf-flag-fix; named esc-chat-4, 2026-10-03) — the file
  `.pending-review-cleared.<agent-id>` that the hook writes whenever it
  deletes that id's pending-review flag (reviewer clearing, an honoured
  `skip:`). It
  records that the hook, not something else, removed the flag. Re-arming the
  flag through the hook's own writer removes the tombstone; nothing else ever
  garbage-collects one. See [[flag resurrection]].

**flag resurrection** / **resurrected-flag drop**:
(esf-flag-fix; named esc-chat-4, 2026-10-03) — a pending-review flag that
  stands at a path that also has a [[flag tombstone]], meaning something other
  than the hook's own writer re-created it after the hook deleted it. The
  drop (`state_drop_resurrected_flags`) deletes each such flag and logs
  `flag-resurrected-dropped=<id>` to `.claude/review-audit.log`. It runs at
  every main-session `Stop` except a re-entrant one (`stop_hook_active`
  true, which `stop-gate.sh` allows early, before the drop's
  `stop-gate-core.sh` is sourced) and at every `Agent` dispatch the reviewer-route
  gate sees (when the persona config exists and the dispatch names a
  target), including under review gating off. Related, same unit:
  the reviewer's `SubagentStop` clears one flag per satisfied review-join
  stamp (oldest first) and clears all flags only on the zero-stamp bootstrap
  path. Flags are not bound to units.

**dead-but-available text**:
(unit item04-2, 2026-09-26) — a canonical protocol section (marked `## ` in 
  `templates/persona-protocol.md`) that no persona row includes via 
  `PROTOCOL_SECTIONS_BY_PERSONA`, making it "dead" — not inlined into any persona's 
  final body at generation time. Distinguished from **Inlined protocol section exclusion** 
  (a section that is inlined into SOME personas but not others) by being orphaned 
  entirely: all persona rows have it in their `drop[]` lists, or no persona's mandate 
  includes it at all. The section remains accessible on disk as part of the uncommitted 
  `.claude/persona-protocol.md` reference copy (item04-3 restored it per `OQ11=DROP` 
  reversal), but it is unreached at generation time. The term distinguishes from mere 
  "unused" prose (which could mean anything) by precision: specifically a **protocol 
  section** that is **canonically defined** but currently **inlined nowhere** because 
  every persona dropped it. Today (item04-2, 2026-09-26), exactly 2 of 19 sections 
  fall into this category: "Third verdict: insufficient-context" and "Fourth verdict: 
  escalate-to-human". Distinct from the [[Inlined protocol section exclusion]] pattern, 
  which names sections dropped selectively per persona but still inlined elsewhere.

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

**era-inferred**:
(unit rgh-u0-2b, 2026-10-06) — the implementer-tier source used when no
  transcript record exists. Applied to units in the [[rubric era]] and
  [[pre-rubric sonnet era]] when the unit-outcomes exporter cannot find a
  lead-programmer or reviewer transcript entry to determine tier. Populated via
  era-based heuristics in `scripts/unit-outcomes.js` rather than transcript
  inspection. See [[rubric era]], [[pre-rubric sonnet era]], [[unit-outcome export]].

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
  (`printf x > .claude/human-review/id/DECISION`) is denied. In
  [[The human-decision gate]], with review gating on, the one exception is a
  lone strictly parsed DECISION heredoc from the main session, which the gate
  turns into an `ask`, see [[prompt-eligible]]; every other command that
  carries both [[trigger token]]s, spelled or as an
  [[expansion-named token]], and that no allowance clears is denied. A
  command arms the gate only when both tokens are present in one of those
  two forms; the declared residuals that escape are listed under
  [[frozen family table]]. Under `reviewGating.mode: off` that gate exits 0
  and denies nothing. Both [[The human-decision gate]] and
  `reviewed-path-gate.sh` apply this distinction via gate-local allowances that
  check whether tokens survive into the command skeleton's CODE text (prose,
  single-quoted spans, and comments are masked and ignored). This is the design
  principle that closes false-positive denials of reads and inert narration while
  preserving each gate's own write rule: with review gating on, no agent can
  complete a DECISION write without a human approving its bytes (ADR-0039),
  within the residuals declared under [[frozen family table]];
  `.claude/reviewed/` is not human-approved but granted, since
  `reviewed-path-gate.sh` lets the reviewer write there, and the main session
  or the orchestrator persona too when no reviewer persona is selected,
  unless a `.escalated` marker stands (see [[The human-decision gate]]).

**frozen family table**:
(esc-left-3, esc-left-4, 2026-10-04) — the fixed list of F-1 spellings that
  [[The human-decision gate]] closed in esc-left-3: unquoted glob and brace
  words that expand to the `human-review` directory or the DECISION file
  without the text spelling them, so each token is an
  [[expansion-named token]] (families F-1a to F-1g, in
  `docs/plans/2026-10-04-escalation-leftovers.md`, Context Item 4). It is a
  [[family table]] with one rule: it is closed only for what it lists.
  Each row is a `FG-<family>-<n>` case in
  `tests/human-decision-gate.test.sh` (FG-c-6 is the comment-carried
  spelling), and is credited as blocked only after a real-bash check in a
  fixture shows that spelling overwrites an existing DECISION (27 of 27
  did). Outside the table, a spelling is claimed blocked only where a
  suite row pins it, such as FP-ext-1 (extglob words), FP-nc-1, Q20 and
  the qp-1 rows below; that list is not exhaustive. No unpinned spelling
  outside the table is claimed closed, and the esc-left-3 reviewer did
  not probe beyond it.
  **Declared residuals**,
  each still allowed: a cwd-relative write that never spells
  `human-review` (assumption A3, no suite pin), R-4 (split variable, pin
  N21), R-5 (backslash, pin R5), and NL1 (newline in the packet id; the only
  `TRACKED-OPEN` pin); A4 groups R-4, R-5 and NL1. A3, R-4 and R-5
  escape the early exit because one token is neither spelled nor
  expansion-named; NL1 spells both and is missed later, because newline
  breaks the gate's path recognizers. Since qp-1, a glob inside a quoted
  string handed to a [[second shell]] counts as a pattern (that entry
  gives the rule). QP-1 (`bash -c`, writes) and QP-2 (`sh -c` with
  `tee`, writes) are `blocked`; QP-3 (`sh -c` redirect) is `blocked` as
  an accepted fail-closed over-block that writes nothing (`/bin/sh` here
  is dash, which does not glob a redirect target non-interactively; the
  suite's `QP-3 literal:` check shows it created a literal file named
  `D*`). Rows QPF-1 to QPF-8 pin the branches of that rule, each
  reachable by real bash and `blocked`. **Declared residuals of that
  rule**, no completeness claim: R-QP-a (a pattern expanded by a program
  that is not a second shell re-parsing a string) and R-QP-b (a
  second-shell invocation the rule cannot recognise from the command
  text). Q20 (`DECISIO{N,}`)
  moved from accepted residual to blocked, because the gate cannot tell a
  redirect target (ambiguous, writes nothing) from a `tee` argument
  (FG-f-3, writes). The `reviewed-path-gate.sh` variant of F-1 is
  deferred. See [[accepted over-block (OB row)]],
  [[differential sweep]].

**accepted over-block (OB row)**:
(esc-left-3, esc-left-4, 2026-10-04) — a `blocked` row named `OB-<n>` in
  `tests/human-decision-gate.test.sh` that pins one real command the
  esc-left-3 predicate denies although it writes nothing to DECISION.
  There are 14 (OB-1 to OB-14), each with a one-line reason: mostly
  heredoc or backslash text that fails the lexer so the raw scan reads
  every metacharacter as live, plus unquoted `adapters/*/agents/*`-style
  globs that name both tokens while the surrounding segment is not
  provably benign; OB-14 (added by qp-1) is a `sh -c` / `bash -c`
  payload whose scratch path can name both tokens. The cap was 25 new
  denials outside the table. It is the per-command form of
  [[accepted over-block]]; narrowing it is a later unit's choice, not a
  defect. The reviewer's own rebuilt corpus gave 14
  new denials, the 14th an over-block that is not a write; still under the
  cap.

**differential sweep**:
(esc-left-3, esc-left-4, 2026-10-04) — running an old and a new gate over
  the same corpus of real commands and comparing verdicts, via
  `tests/hdg-differential-sweep.sh <old-gate> <new-gate> <corpus.jsonl>`,
  which prints `total=N new_denials=D new_allowances=A`. The corpus is the
  Bash commands in the last 20 days of local transcripts (10,194 at
  esc-left-3). The acceptance rule: `new_allowances=0`, and every new
  denial is a [[frozen family table]] member or an OB row. The result was
  `new_denials=13 new_allowances=0`. It is a review tool, not wired into
  `tests/validate.sh`, and it feeds each command as lead-programmer, so it
  never exercises the main-session `ask` route (the PG rows cover that).
  The corpus is machine-local and may be pruned; the committed result is
  the summary line.

**expansion-named token**:
(esc-left-3, esc-left-4, 2026-10-04) — a [[trigger token]] the command
  text does not spell but names as a pattern: an unquoted glob or brace
  word that could expand to it, or, since qp-1, a glob in a quoted string
  handed to a [[second shell]], such as `h*` for
  `human-review` or `D*` and `D{E,}CISION` for DECISION. Since esc-left-3,
  [[The human-decision gate]] counts it as present (`glob_names_tokens()` in
  `hooks/scripts/human-decision-gate.sh`), so `printf x > .claude/h*/u1/D*`
  arms the gate with neither token spelled (pin FG-c-1, blocked), and
  `printf x > .claude/human-review/u1/[D]ECISION` with one spelled (FG-a-1,
  blocked). A command with either token expansion-named fails closed: past
  the prompt route and the benign-command check, only the sanctioned
  marker-write recognizer may allow it. When the command lexes, a quoted
  glob names nothing unless it is in the word that follows text the
  second-shell rule recognises (see [[second shell]]). That rule
  reads the text alone, so `echo sh -c` before a quoted glob names its
  tokens too, although no second shell runs. Coverage is claimed for the
  [[frozen family table]], the qp-1 rows and other rows pinned outside
  the table, such as FP-ext-1 (extglob words) and FP-nc-1 (a lowercase
  glob under nocaseglob); no unpinned spelling is claimed.

**second shell**:
(qp-1, qp-2, 2026-10-04) — a shell that [[The human-decision gate]]
  assumes will re-parse a quoted string: an unquoted `sh`, `bash` or
  `dash` name with a `-c` option, whose next word is its payload. The
  gate recognises one from the command text alone
  (`glob_scan_shell_payloads()` in `hooks/scripts/human-decision-gate.sh`),
  reading the text with quoted strings masked, so a quoted name is not
  recognised. The name's preceding character, if any, is not a letter,
  digit, `_`, `.` or `-` (so a blank, `/`, `=`, `$` or a quote
  qualifies); then come any option words that start with `-` or `+`, the
  last a short-option cluster holding `c` (`-c`, `-ec`); words are
  separated by blanks, and matching is case-insensitive. It also matches
  a name that is only an argument, as in `echo sh -c` before a quoted
  glob, although no second shell runs; both widenings can only
  over-block. The gate's glob scan reads the payload with its quote
  characters deleted and every metacharacter live, so a glob there can
  make an [[expansion-named token]]. The rule decides which globs count,
  not which tokens are spelled: the quote-joined text deletes only quote
  characters, so a token spelled inside any quoted string is present
  whether or not a second shell is recognised. The rule applies when the
  command lexes; when it does not, the gate scans the raw text with every
  glob live anyway. Suite rows pin it, such as QP-1, QP-2 and QPF-1 to
  QPF-8; its declared residuals, R-QP-a and R-QP-b, carry no completeness
  claim (see [[frozen family table]]).

**trigger token**:
(units hdg-lexer-1, hdg-prose-2, 2026-08-24; esc-left-3, 2026-10-04) — one of two strings
  whose co-occurrence arms [[The human-decision gate]] and (in asymmetric
  form) other text-protection gates. In `human-decision-gate.sh`, the two
  triggers are `human-review` and `DECISION`. A token counts as present
  when the quote-joined text contains it as a substring, or when it is an
  [[expansion-named token]] (since esc-left-3; since qp-1 that includes a
  glob in a quoted string handed to a second shell). The gate exits early,
  allowing the command, unless both tokens are present in one of those
  forms. This "both tokens must appear" rule is the gate's early exit (a
  fast check before deeper gate logic). See [[narrate-versus-target
  distinction]] for when a command carrying both tokens is allowed anyway
  (when they are inert to execution).

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

**unit-outcome export**:
(unit rgh-u0-2b, 2026-10-06) — the read-only per-unit JSONL produced by
  `scripts/unit-outcomes.js`: structured records of `id`, `tiers` (lead/scribe
  pair, **era-inferred** when no transcript), `attempts` (attempt count for
  scoring), FAIL classes, PASS/terminal timestamps, contract source/score/timestamp,
  and `terminal_ts`. Privacy: no prompt text is included. Invocable via
  `node scripts/unit-outcomes.js --until <ISO8601-ts>`. See [[contract score]],
  [[rubric era]], [[pre-rubric sonnet era]], [[terminal event]].

**`UNIVERSAL_PROTOCOL_CORE`**:
(unit item04-3, 2026-09-26) — a constant in `bin/cli.js` (line ~1344) naming 
  the six canonical sections of the slim-tier protocol: "Structural questions → explorer", 
  "Answer shape", "Scope Bash output", "Agent-teams mode", "Blocked by a gate you do not own", 
  and "Terminal status line". The slim template (`templates/persona-protocol-slim.md`) 
  hand-maintains these 6 sections plus `## A note on \`memory\`` (7 total), NOT derived 
  from the constant itself — the constant is load-bearing in domain prose (`CONTEXT.md:280`) 
  but is an informational reference, not a code-driven render source. Documented in this 
  glossary entry because it appears in CONTEXT.md as a named anchor for the slim tier's 
  content, and readers should understand that the 6-section set is fixed (not auto-minted 
  at render time) and hand-maintained in the template.

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
  functions in `has_path_shaped_occurrence()` (see [[command_skeleton]]) that
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
  `is_sanctioned_marker_write()` since 2026-08-12; corrected item12-4,
  2026-09-26) — a narrowly-scoped exception to [[The human-decision gate]]'s
  write block: the one command shape that every agent identity may use to
  create a `.claude/reviewed/<id>.pass` or `.claude/reviewed/<id>.fail`
  marker file. The template is a heredoc-based marker creation, and the
  redirect may be either the truncating `cat > .claude/reviewed/<id>.pass
  <<'EOF' … EOF` or the appending `cat >> .claude/reviewed/<id>.fail <<'EOF'
  … EOF` — `is_sanctioned_marker_write()`'s regex has permitted both since
  the template's introduction. A `.fail` record uses the appending form, so a
  second FAIL block is kept rather than destroying the first. Both forms
  read from standard input and write to a single explicit marker file path.
  This is the **only** pair of write shapes the gate allows, and it is
  unconditional across all identities (reviewer, main session, orchestrator).
  The restriction to these two shapes (no piping, no redirection to other
  files, no `tee`, no `cp`) closes a class of attacks that use marker-write
  privileges to access other protected files. The gate recognizes the
  template syntactically (via a dedicated function) and performs no
  capability delegation — a bare `cat > .claude/reviewed/id.pass` (without
  the heredoc) is denied.

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
  and used by both [[The human-decision gate]] and `reviewed-path-gate.sh`) —
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
  including the absent → `"off"` transition on `reviewGating.mode` — does
  not get silently normalized away. `reviewGating.mode` is **live**
  (2026-09-29, ADR-0038) with values `enforce|off`; spec 6's `warn` was not
  adopted, and absent or junk values resolve to `enforce` at the consuming
  gates (`bin/harness-integrity.sh` compares a junk value as-is, so it shows
  as drift).
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
(unit gh415, 2026-08-26; consumer and severity mapping added by item15-2,
  2026-09-26) — the append-only sidecar `<log>.seal` maintained
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
  evidence against carelessness, not a defense against intent. **The
  guarantee in one sentence: seals detect modification of a log's already-
  sealed content; deletion of the log itself is detected by its absence,
  not by the seal.** See [[sanctioned rotation]] for the one operation that
  legitimately rewrites a sealed log without tripping this detector, and
  `docs/trust-model.md` row 12 for how this feeds the broader trust map.
  `bin/harness-integrity.sh` maps `missing-seal` on an existing, non-empty
  log to the same `tampered` severity as `truncated`/`absent` (item15-2):
  deleting the sidecar is the cheaper first move in a truncate-and-reseal
  attack, so it must not read as a weaker verdict than the truncation it
  usually precedes. Item15-1 found `audit_seal_verify`'s result was
  computed by `bin/harness-integrity.sh` but discarded by both its hook
  call sites (`hooks/scripts/session-start.sh:167`,
  `hooks/scripts/lib/stop-gate-core.sh:613` check only `config=drift`,
  never `logs=`) — write-only. Item15-2 adds the first real consumer,
  `bin/audit-seal-verify.sh`, wired into `tests/validate.sh`; it turns the
  `logs=` field into a real exit code (0 intact, non-zero naming the bad
  file) but does not change what the two hook call sites check, so a
  drifted/tampered log still does not block a session today outside
  `validate.sh`. `adapters/codex/` and `adapters/cursor/` each ship
  `audit_seal_verify` in their own `hooks/scripts/lib/audit-log.sh` copy
  with **no caller at all** — `bin/harness-integrity.sh` and
  `bin/audit-seal-verify.sh` are not mirrored into either adapter port — so
  the seal mechanism stays write-only-absolute there; a known,
  separately-tracked gap, not silently left asymmetric.

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
  `reviewed-path-gate.sh`) restricts who may write it, and RD5 records
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

**pointer dispatch**:
(unit rgh-u0-2b, 2026-10-06) — an orchestrator dispatch that only points at the
  issue contract instead of containing it (the dispatch prompt is generated
  only as a pointer to the issue's dispatch contract, not by copying it).
  Pointer dispatches are never scored by `bin/contract-score.js`; they exist
  only for routing and issue correlation, not for contract assessment. See
  [[contract score]], [[unit-outcome export]].

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

**terminal event**:
(unit rgh-u0-2b, 2026-10-06) — a unit's PASS timestamp, or for a unit that hit
  the 2-FAIL cap without a PASS, the second FAIL block's header timestamp.
  `terminal_ts` in the [[unit-outcome export]] is the earlier of `pass_ts` and
  the second FAIL header, evaluated as of the `--until` cutoff timestamp. Distinct
  from **terminal status set** (CONTEXT.md, OutcomeCI journal statuses `confirmed`,
  `denied`, `unsent`, `uncertain`) — this term refers to a unit's own lifecycle
  event timestamp, not a workflow status. See `scripts/unit-outcomes.js` source
  and unit-outcomes test fixtures for timestamp derivation.

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

**shared-file siblings**:
(unit rgh-u3-2, 2026-10-06) — the term in task-master for two or more units in a
  dispatch that touch the same file. Units that are siblings are serialized in
  dispatch order via `Depends on` edges: the later unit waits for the earlier
  unit's completion before running. The later sibling unit's anchors in the
  dispatch contract must be stable (headings or symbol names, never bare line
  numbers), or they must be SHA-qualified and re-resolved by the orchestrator
  after the earlier unit's PASS commit. Defined in `agents/task-master.md` bullet
  **Shared-file siblings** within the task-master input section.

**held unit**:
(unit rgh-u3-2, 2026-10-06) — a unit that is not published in the sliced dispatch
  because it is behind a **spec gap** (an ambiguity or under-specified part of the
  finalized spec). When a spec gap is encountered, task-master publishes all
  already-sliced units and halts; the gap unit and everything transitively
  depending on it remain unpublished (held) and are reported in the
  **`Slice state:` table** with state "held" and the gap reason. The table format
  is: unit | published or held | reason. Defined in `agents/task-master.md` bullet
  **Partial slice on a spec gap** within the task-master input section. See
  **Slice state: table**, **spec gap**.

**Slice state: table**:
(unit rgh-u3-2, 2026-10-06) — the summary table that task-master appends to its
  report when a partial slice occurs (i.e., when a spec gap prevents publishing
  all units). The table rows correspond to units with columns: `unit` (task-id),
  `state` (published or held), and `reason` (explanation if held). Units in
  the "published" state are routed to dispatch; units in the "held" state are
  retained for re-work after the spec gap is resolved. Defined in
  `agents/task-master.md` bullet **Partial slice on a spec gap** within the
  task-master input section. See **held unit**, **partial slice**.

**standard path**:
(unit rgh-u3-2, 2026-10-06) — the execution path task-master takes when a
  finalized spec contains ≥6 dispatchable units or any `## Convergence follow-ups`
  slice. On this path, task-master runs (the fast path with ≤5 units bypasses
  task-master entirely and has spec-master emit the contract directly). The
  dispatch contract lives in the issue body under `## Dispatch contract` on the
  standard path, whereas on the fast path it lives in the plan's `### Unit:`
  block. Counterpart to [[fast-path threshold]] in CONTEXT.md. The executor
  consults the contract according to its home: the contract outranks the issue
  prose, which outranks the plan. A conflict between them is a spec gap. Defined
  in `agents/task-master.md` bullet **Contract home and precedence** within the
  task-master input section.

