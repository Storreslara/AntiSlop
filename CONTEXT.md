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

**Persona**:
a subagent system prompt in `agents/*.md`. "Core" personas
  (orchestrator, explorer, lead-programmer) are always installed; "optional"
  personas (spec-master, task-master, scribe, reviewer, researcher,
  milestone-auditor, agent-auditor) are selected per-project during ADAPT. `spec-master`
  turns ambiguous goals into precise specs via grilling and publishes via
  `to-spec`; `task-master` reads finalized specs and writes dispatch
  instructions for `lead-programmer`, owns `to-tickets` slicing outright, tags
  per-unit models. `scribe` maintains institutional knowledge (wiki, CONTEXT.md,
  ADRs). `reviewer` is the independent verifier (the Writer/Reviewer split).
  `researcher` bridges academic literature and spec authoring. `milestone-auditor`
  hunts premise gaps at milestone boundaries after all units reach PASS. `agent-auditor`
  observes agent activity (tool calls, skills invoked) via `hooks/scripts/agent-audit.sh` and
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
  classifies outcomes as `ok`, `violation`, or `unknown` (an [[unmeasurable range]]),
  exiting 0 always (fail-open). Takes an explicit range because a unit's range is a per-unit input only the
  reviewer knows (a self-derived `HEAD~1` sees only the last commit); originally
  also motivated by CI's since-removed shallow clone. Mechanization covers the version-bump
  half of the discipline only; the CHANGELOG-entry half remains reviewer-inspection-only, now with a runnable command in the `antislop:version-stamp-discipline` skill.
  (unit version-stamp-check-roast-1, 2026-09-23) Widening the reviewed range past
  an offending commit no longer masks it: the script additionally checks every
  commit *within* the range that itself touches a version-stamped path against
  its own immediate parent, reporting `violation` if any one of them individually
  lacks a bump — even when the range's overall endpoints show a bump happened
  somewhere in between (e.g. a later, unrelated commit). The endpoint `old`/`new`
  fields in the output remain informational only. See row 25 of `docs/trust-model.md`.

**Substitution**:
a placeholder in a shipped persona file (e.g.
  `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>`) resolved to a real
  value at ADAPT time and recorded in `.claude/persona-config.json`'s
  `substitutions` field. The placeholder sits on a YAML comment line (so the
  shipped frontmatter parses) that the renderer replaces.

**The Writer/Reviewer split**:
the system's core safety property: the
  `lead-programmer` writes code, but only the independent `reviewer`
  (which did not write the code) can mark a unit done (`.claude/reviewed/*.pass`).
  Enforced mechanically by `stop-gate.sh` and `reviewer-route-gate.sh`, not
  just by persona instruction — **when `reviewGating.mode` is `enforce`**
  (the default). Under [[review gating off]] the split holds by persona
  prose only and the reviewer's verdict is an [[advisory verdict]]; see
  [ADR-0038](docs/adr/0038-review-gating-runtime-switch.md).

**review gating off** (everyday name: *gateless mode*):
(unit rgo-5, 2026-09-29) — the project state where `reviewGating.mode` in
  `.claude/persona-config.json` is exactly `off`. Reviewer verdicts are
  advisory, and the review-enforcement and human-escalation gates are inert;
  the protection gates (`protected-paths.sh`, `harness-integrity-gate.sh` and
  config-drift detection, `reviewed-path-gate.sh`, the reviewer-dispatch
  identity and privileged-name guards, and the stop-gate test+lint check)
  stay armed. Absent or junk values mean `enforce`. At a unit's second
  advisory FAIL the orchestrator reports `Unresolved advisory findings` and
  carries on; scribe closes issues on a quoted reviewer PASS labelled
  `advisory PASS (review gating off)`. _Avoid_: "gateless" in technical
  prose, because some gates stay armed.

**advisory verdict**:
(unit rgo-5, 2026-09-29) — the reviewer's verdict under [[review gating off]]:
  returned to the orchestrator, recorded in no marker, blocking nothing. It
  is the *only* reviewer's verdict and is non-binding, which distinguishes it
  from the [[advisory-reviewer axis]] (a *second* reviewer that owns no
  verdict). _Avoid_: "advisory reviewer" for this meaning.

**unit-exclusivity axis**:
(unit item10-1, 2026-09-26) — the invariant that at most one **unit** is
  ever mid-review; see [[The Writer/Reviewer split]]. Enforced by
  `reviewer-route-gate.sh`, which blocks the next gated dispatch while a
  pending-review flag stands. Distinct from the [[advisory-reviewer axis]] —
  the two govern different questions (how many units, vs. how many
  reviewers on one unit) and are not in tension with each other.

**advisory-reviewer axis**:
(unit item10-1, 2026-09-26) — orthogonal to the [[unit-exclusivity axis]]:
  the single unit under review may still carry a second, advisory reviewer
  (e.g. a Roast-work pass) that owns no verdict and writes no marker.
  [ADR-0016](docs/adr/0016-per-unit-review-join.md) names the liveness trap
  this axis closes for that advisory second reviewer; the harness mechanism
  admitting it is the [[review-join stamp]]. A 2026-09-25 adversarial review
  misread the two axes as contradictory ("pick one: allow concurrent
  reviews, or forbid them") — see
  `docs/plans/2026-09-25-item10-review-join-stack.md` for the rebuttal.
  [ADR-0028](docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md)'s
  related scoped-marker-relevance fix was caused by leaked test fixtures,
  not by concurrent reviewers, and is not evidence against this axis.

**Gate**:
a hook script that mechanically blocks an action rather than
  relying on a persona to comply (e.g. `stop-gate.sh`, `protected-paths.sh`,
  `reviewed-path-gate.sh`). Config-driven via `.claude/persona-config.json`.
_Avoid_: marker-directory gate

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

**lens-2** (finding):
(unit hcb-prose-history, 2026-09-24) — from this repo's `antislop:ubiquitous-language`
  terminology-check convention: a finding where an existing glossary term is used with its
  correct canonical meaning, but the surrounding prose's OTHER claims about the same subject
  have gone stale — distinct from **lens-1** (a term used with a wrong meaning) and
  **lens-3** (a load-bearing term missing an entry). Originated in sweep-closure analysis
  (e.g., row 1 of `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`
  identifies *"no grant branch"* as still literally true even after the human-confirmation
  branch ships; the amendment preserves this clause as lens-2 — the lens recognizes it is
  still correct, so it must not be deleted). Used to distinguish prose that is correctly
  stated but orphaned by surrounding changes, flagged for reconciliation to prevent false
  deletions of still-true claims.

**Protocol excerpt**:
the subset of `templates/persona-protocol.md`'s 19
  `## `-delimited canonical sections that a given full-tier persona's
  `.claude/agents/*.md` mirror actually inlines, per `bin/cli.js`'s
  `PROTOCOL_SECTIONS_BY_PERSONA` matrix (issue #190, 2026-08-01 efficiency
  pass, finding F1). Distinct from the [[Protocol tier]] (which file a
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

**Protocol tier** (also called **protocol delivery tier**):
(unit item04-3, 2026-09-26) — which of two canonical files `bin/cli.js`
  inlines into a persona's rendered body at generation time: the **full
  tier** (`templates/persona-protocol.md`, 685 lines, 19 `## `-delimited sections) or
  the **slim tier** (`templates/persona-protocol-slim.md`, a 90-line, 7-section
  subset). Full-tier personas: `orchestrator`, `lead-programmer`, `reviewer`,
  `spec-master`, `task-master`, `milestone-auditor`. Slim-tier personas
  (`SLIM_TIER_PERSONAS` in `bin/cli.js`): `explorer`, `researcher`, `scribe`,
  `agent-auditor` — lightweight personas that run frequently and need only
  the six sections of `UNIVERSAL_PROTOCOL_CORE` plus `## A note on \`memory\``,
  hand-maintained in the slim template rather than derived from the constant.
  Distinct from the [[Protocol excerpt]], which is a *further*
  trim applied only within the full tier: this term picks the file, the
  excerpt picks the subset of that file's sections a given full-tier persona
  actually keeps. See [protocol-delivery-tiers.md](.claude/wiki/protocol-delivery-tiers.md)
  for the rendering mechanics.

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

**Suggested model vocabulary**:
(units item06-3, 2026-09-25) — the canonical allowed-value list for the
  `Suggested model:` tag emitted by `task-master` during dispatch (and historically
  by `spec-master` before ADR-0009's reversal). Current vocabulary:
  `Suggested model: sonnet|opus`. Pinned as a cross-file invariant by
  tests/writer-tier-consistency.test.js AC-D9 (agreement guard between
  `agents/orchestrator.md` and `agents/task-master.md`). Historically included
  `haiku` (pre-ADR-0026); see [[Writer tier]] and [[Implementer-tier ratchet]]
  for the escalation semantics those tags trigger.

**defaultImplementerModel**:
(unit item18, 2026-09-25) — a persona-config field (`defaultImplementerModel: "sonnet"|"opus"`) 
  that sets the lead-programmer's model tier for a dispatch, subject to a fixed 
  precedence order: (1) explicit per-dispatch `Suggested model:` tag (if present), 
  (2) `defaultImplementerModel` config value (if present and recognized), (3) 
  persona frontmatter default (from the persona file's `model:` key). Absent or 
  unrecognized values in position (2) escalate to `opus` (higher capability), 
  while truly absent/nullish values fall through to position (3). Introduced via 
  `resolveDefaultImplementerModel(config, frontmatterDefault)` in `bin/cli.js`. 
  For already-adapted projects, the field is backfilled via `runUpdate` when 
  absent, using `implementerFrontmatterDefault()` to read the packaged 
  `agents/lead-programmer.md` frontmatter (ensuring the current project's 
  persona file override does not interfere). Cross-reference: [[inert-key defect]],
  [[Writer tier]], [ADR-0010](docs/adr/0010-haiku-as-default-implementer-model.md),
  [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).

**Reviewer-gate ratchet**:
the `.fail` disqualifier on the reviewer's own
  model eligibility. A unit's `.claude/reviewed/<task-id>.fail` record from the
  reviewer permanently forces `opus` on that unit's reviewer gate, regardless of
  whether a subsequent PASS marker exists. This ratchet never expires
  (unit #233, OQ3 ruling). The asymmetry (implementer tier expires, reviewer gate
  does not) preserves the core safety property: if a reviewer has once missed
  something on a cheaper tier, all future reviews run on the full-strength tier.
  Distinct from the implementer-tier ratchet.

**The graph**:
Code Review Graph, a third-party MCP server providing
  structural code queries (callers/callees, blast radius, architecture
  overview). Scoped to `explorer` alone, never project-wide — see
  [ADR 0001](docs/adr/0001-mcp-scoped-to-single-persona.md).

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

**domain glossary** (vs. **harness glossary**):
(unit consolidated-catch-up, 2026-09-26) — `CONTEXT.md` is the **domain glossary**,
  a shared-language reference for this project's own domain concepts (personas,
  gates, escalation workflow, model tiers, skills, spec language, dispatch
  plumbing) that a user of the plugin would encounter. Owned by `scribe`.
  Distinct from `docs/harness-glossary.md`, the **harness glossary**: a separate
  reference for terminology whose meaning requires knowing this repo's internal
  implementation (hooks, markers, gate-specific surfaces like Set A / Set B,
  dispatch-hygiene checks, audit-log formats). Both are canonical alongside
  `docs/adr/` and are kept current by `scribe`. Route terminology this way:
  **harness** if understanding it requires knowing this repo's hooks, markers,
  gates, or dispatch plumbing; **domain** if it describes the persona system's
  concepts as a user of the plugin would meet them. See both files' preambles.

**dangling link**:
(unit item03-2, 2026-09-24) — an undefined cross-reference (indicated by
  `[[term-not-yet-defined]]` or a reference to a term without a glossary entry)
  in documentation prose. The `tests/context-glossary-links.test.js` guard
  (item03-2's own test) flags these as defects during sweep closure: every
  `[[…]]` bracket reference in a document must either resolve to an existing
  glossary term or identify a term worth defining. A dangling link is distinct
  from a *stale* link (a reference to a deleted term) — both are defects but
  signal different problems. The guard enforces no orphaned `[[…]]` references
  in narrative prose remain unresolved by the time a step ships.

**default-unnamed dispatch rule**:
the standing convention that `Agent` tool calls should dispatch without a `name:` parameter by default, causing their result to auto-return on completion. Named dispatch is reserved only for cases requiring **mid-flight addressability** — querying or re-tasking a long-running subagent mid-way through. The one exception is the 2-FAIL-cap / debug-spec scenario in "Nested dispatches", where explicit naming is mandatory. Deferred companion: a **mechanical report-loss backstop** to detect named agents completing without reporting (see `docs/adr/0021-mechanical-report-loss-backstop-deferred.md`).

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

**Reviewer dispatch opening line**:
(unit #266, 2026-08-08, enforcement added)
  — Every reviewer dispatch must open with `Unit: <task-id>` as its literal
  first non-blank line. `reviewer-route-gate.sh` reads exactly that line for
  task-id extraction; omitting it causes silent open-fail (the gate accepts the
  dispatch but router routing breaks). Disciplined by lead-programmer dispatch
  instruction template, checked by `dispatch-hygiene.sh` H4.

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
  "Check the roster before resuming one by name" in `agents/orchestrator.md:167`
  (heading text and line corrected 2026-09-27, item14 catch-up batch — item14-1
  reworded the heading from "before dispatching" and the line moved; see
  `docs/plans/2026-09-25-item14-gh304-roster-check.md`).

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

**PASS marker**:
the file the reviewer writes at `.claude/reviewed/<task-id>.pass`
  on a PASS verdict, gating "done" for that unit (see [[The Writer/Reviewer split]]).
  First line: `PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria:
  <acceptance-criteria command(s) run>`, optionally followed by [[non-blocking note]]s.
  Sibling of the `.escalated` and `.directed` markers below, which cover the two
  other reviewer outcomes.

**FAIL record**:
(item12-1/item12-3/item12-4, 2026-09-26) — the file the reviewer writes at
  `.claude/reviewed/<task-id>.fail` on a FAIL verdict. Unlike the [[PASS marker]],
  this file can hold more than one [[FAIL block]]: each FAIL verdict for the
  same task-id appends a new block rather than overwriting the previous one,
  so the file is a chronological log of every fix attempt, not a single
  latest-only snapshot. Read by `bin/fail-count.sh` and by `fail-triage`/debug
  spec when a unit hits the 2-FAIL cap.

**FAIL block**:
(item12-1/item12-3/item12-4, 2026-09-26) — one FAIL verdict's contribution to
  a [[FAIL record]]: first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`,
  followed by the defect list verbatim, then a blank separator line.
  `bin/fail-count.sh` counts blocks by grepping the task-id-qualified anchor
  line (`^FAIL <task-id> `), which is what makes the 2-FAIL cap countable
  across sessions instead of relying on one agent's in-session memory.

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
  `--update` backfill path — the backfill additively merges new keys into
  already-adapted projects' configs (see `backfill`); absent `humanReviewMode`
  keys are seeded with their default values, but an already-present value is
  never overwritten. This repo's own config ran the [[bootstrap window]] override
  (`humanReviewMode: "off"`) only until the human-decision resolution channel
  landed at unit #136; the live value returned to `critical`, the same as any
  other adapted project, at that point. **Superseded 2026-08-16** by Step 1
  of the ceremony-reduction plan: this repo's config now runs
  `humanReviewMode: "off"` again, this time as a permanent [[solo-operator
  posture]], not a bootstrap window — see that entry and
  [ADR-0024](docs/adr/0024-ceremony-reduction-solo-operator.md). **Item 20
  (2026-09-25) reaffirmed this off setting** (Option B: leave off, accept the
  cost) rather than turning the mode on or removing the escalation path;
  `human-decision-gate.sh`, which guards the mode's write path, was found
  correct-and-dormant with `.claude/human-review/` at 0 packets and kept
  as-is rather than replaced or removed — see
  [ADR-0036](docs/adr/0036-human-decision-gate-keep-as-is-mode-off.md),
  since amended for one branch by
  [ADR-0039](docs/adr/0039-prompt-confirmed-decision-write.md) (the
  [[prompt-confirmed decision write]]).
  **Overridden by [[review gating off]] (2026-09-29):** when
  `reviewGating.mode` is `off`, human escalation is dropped regardless of
  this field and `human-decision-gate.sh` is inert; this field governs only
  under `enforce`. See
  [ADR-0038](docs/adr/0038-review-gating-runtime-switch.md).

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

**DECISION file**:
(unit #325, 2026-08-11, Step 1 of the human-decision-channel fix, issue #324;
  read and transcribed by the reviewer, Step 3/amended #136, 2026-08-11;
  refreshed esc-chat-4, 2026-10-03, ADR-0039) —
  the human-written file at `.claude/human-review/<task-id>/DECISION`, inside an
  [[Escalation packet]] directory, carrying the human's resolution of a pending
  `ESCALATE-TO-HUMAN` escalation. **No subagent can write it**: **the
  human-decision gate** (see below) denies every Write/Edit to it and every
  Bash command that targets it, for every identity, with one exception: the
  main session may make the [[prompt-confirmed decision write]], which the
  gate only ever *asks* about, so the file appears only after a human's Yes
  at Claude Code's permission prompt (that route is pending the esc-chat-1
  measurement). On a later re-dispatch the reviewer
  verifies it exists at the packet path, parses its first line, checks the
  task-id matches and the [[Staleness binding]] holds, then **transcribes** it
  — never re-reviews it — into one of three terminal routes (see [[DECISION
  channel]]). The DECISION file is the consent artifact: no agent can
  complete the write without a human approving its bytes, which is what makes
  its contents trustworthy as the human's own word, not an agent's
  paraphrase. There are three authoring paths: the human typing it in the
  terminal (no `via:` line), the dashboard (`via: dashboard`), and the
  prompt-confirmed decision write (`via: prompt`). The dashboard path is
  the **Microworld dashboard**'s human-driven, terminal-confirmed **dashboard-originated
  decision write** (see [[dashboard-originated decision write]]) that delivers
  the **confirmation code** over `/dev/tty` and writes the file with a `via:
  dashboard` line in the file body itself distinguishing it from the
  typed-terminal path (which carries no `via:` line at all); the write
  separately appends its own `decision-write-via-dashboard` line to the
  review audit log, which contains no `via:` token.

**prompt-confirmed decision write**:
(esc-chat-2/2b/3, landed 2026-10-02..03; named esc-chat-4, 2026-10-03,
  [ADR-0039](docs/adr/0039-prompt-confirmed-decision-write.md)) — the third
  authoring path for a [[DECISION file]], sibling of the
  [[dashboard-originated decision write]]: after the human answers an
  escalation in chat, the main session runs one exact Bash heredoc that
  writes the file with a `via: prompt` line in its body, and the
  human-decision gate answers that one shape with Claude Code's permission
  prompt (`ask`, never `allow`). It has **two disk effects**, at two
  locations: (1) the gate appends a `decision-gate-asked` line to
  `.claude/review-audit.log` **when it asks, before the human answers**, so
  the line is there for a decline too, and an asked line with no DECISION
  file afterwards means the human declined (or the approved write
  failed); (2) the DECISION file itself,
  written by the orchestrator's Bash call only after the human's Yes. `via:
  prompt` lives in the file body, never in the audit line. Eligible only from
  the main session (no `agent_id`; whether an agent-teams teammate can also
  lack one is unmeasured, see `docs/plans/2026-10-02-escalation-followups.md`
  R4), only in the default, acceptEdits and auto permission modes (plan
  denies because it is read-only, so there is no write approval to make;
  bypassPermissions and dontAsk deny because a silent auto-approve there
  would go undetected), and only against a standing `.escalated` marker with
  no DECISION file yet. Any deny falls back to the terminal route. The
  premise that the human sees the exact bytes at the prompt is **pending the
  esc-chat-1 measurement** (`scripts/probe-bash-ask.sh`); the route is not
  released until that record reads `Ship gate: GREEN`. See [[The
  human-decision gate]] and [[prompt-eligible]].
_Avoid_: prompt-gated in-session escalation decision write, main-session
  prompt route, prompt route, in-session decision write (all name this same
  path; use "prompt-confirmed decision write", and `via: prompt` only for the
  body line's value)

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
  See [[Microworld dashboard]], [[execution credential]], and [[read-only mode]] (`--dashboard-no-tty`).

**DECISION channel**:
(unit #326, 2026-08-11, named at Step 2 of #324; read and transcribed by the
  reviewer, Step 3/amended #136, 2026-08-11) — compact name for the resolution
  route [[DECISION file]] provides: `.claude/human-review/<task-id>/DECISION`,
  guarded by [[The human-decision gate]] (`human-decision-gate.sh`,
  Step 1/#325) so that no agent can complete a write to it without a human
  approving its bytes (see [[prompt-confirmed decision write]]). Named explicitly in `reviewed-path-gate.sh:113`'s block message
  as "the only route that resolves an escalation" once the no-reviewer fallback is
  suspended by a standing `.escalated` marker (see [[Escalation-laundering]]) — i.e.
  the fallback's block message points a human at this channel rather than leaving
  the escalation stuck with no legal way forward. The reviewer now reads and
  transcribes the channel (never re-reviews) into three terminal routes: approve
  → `.pass` with an appended human-attestation line, reject → `.fail` with the
  human's reason verbatim as the defect list, direct → [[`.directed` marker]]
  carrying the human's prescribed fix verbatim. Defined in
  `templates/persona-protocol.md`'s "Resolving an escalation" section.

**parked unit**:
(unit gh404, 2026-08-16, Step 4 of the ceremony-reduction plan) — option (c)
  at the 2-FAIL cap (see [[FAIL routing (post-reviewer)]]): the orchestrator
  stops re-dispatching `lead-programmer` on the unit and moves on, leaving
  the two-attempt defect history standing. No marker is written and none is
  deleted — a parked unit is distinguishable from any other unit only by the
  absence of further dispatch, never by a dedicated marker state. Contrast
  with (a) debug spec and (b) human-directed re-dispatch, the other two
  options offered by the same `AskUserQuestion` prompt.

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

**dispatch naming**:
(item14, 2026-09-26, `docs/plans/2026-09-25-item14-gh304-roster-check.md`
  Step 1) — the `name:` parameter on an `Agent` dispatch, omitted by
  default. Distinct from **resume addressing** (below): naming is optional
  on this path, so the unnamed-dispatch default has something to omit and
  therefore something to fix. See "`Agent` naming vs `SendMessage`
  addressing" in `agents/orchestrator.md`, and [[roster]] for the incident
  this distinction was drawn to clarify (gh-304).

**resume addressing**:
(item14, 2026-09-26, `docs/plans/2026-09-25-item14-gh304-roster-check.md`
  Step 1) — the mechanism `SendMessage` uses to reach an existing agent: by
  name, by construction. Distinct from **dispatch naming** (above): there is
  no "unnamed" `SendMessage`, so the unnamed-dispatch default that fixes the
  `Agent` path cannot apply here even in principle — the [[roster]] check is
  the only control on this path. Drawn out explicitly because a 2026-09-25
  adversarial review conflated the two and proposed deleting the roster-check
  paragraph on the false premise that the unnamed-dispatch default already
  covered it; see `docs/plans/2026-09-25-item14-gh304-roster-check.md`'s
  Context section for the verification that rejected the revert.
