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

**Substitution**:
a placeholder in a shipped persona file (e.g.
  `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>`) resolved to a real
  value at ADAPT time and recorded in `.claude/persona-config.json`'s
  `substitutions` field.

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

**Reporter**:
(unit #132, 2026-08-10) — a hook script that observes and logs an
  action without blocking it; the formal antonym of **Gate**. Unlike a gate,
  which refuses an action, a reporter permits it and records metadata in an
  audit trail. Example: `microworld-rerun.sh` is a reporter that captures
  microworld bundle execution results (pass/fail/timeout) and infrastructure
  failures, logging to `.claude/microworld-audit.log`. Exit codes: 2 signals a
  genuine bundle failure (surfaces stderr to the model, does not block); 0
  covers both "nothing matched" and "infrastructure broke" (fail-open). The
  reporter/gate distinction is a formal semantic pairing; never conflate them.

**grant-denied**:
an append-only audit-log record class written to
  `.claude/review-audit.log` by `reviewed-path-gate.sh` and `stop-gate.sh`
  (both main hooks and both adapter ports) whenever a privilege is denied to
  a non-reviewer **Agent identity**. Unlike a **Gate** (which blocks an
  action), `grant-denied` is a side-effect log line that makes a previously
  invisible privilege denial visible in the audit trail — the gate still
  fires, but the denial is now recorded. Completes Finding R3 from the
  orchestration-dispatch-identity-defects spec (unit #307).

**Microworld audit log**:
(unit #132, 2026-08-10) — an append-only log file at
  `.claude/microworld-audit.log` (+ per-adapter equivalents
  `.cursor/microworld-audit.log`, `.codex/microworld-audit.log`) recording
  execution results of **microworld bundle** invocations. Written by the
  `microworld-rerun.sh` **Reporter** hook on every `PostToolUse` for
  `Edit|Write` operations. Line format: `<ts> unit=<slug> result=pass|fail|timeout file=<path>` for real bundle runs, and `<ts> unit=<slug> result=error ... file=<path> reason=<...>` for infrastructure failures (malformed manifest, missing `run.sh`, absent `jq`, etc.). Never gates; logged failures surface stderr to the model on `PostToolUse` but do not block the edit. Complements `.claude/review-audit.log` and `.claude/wip-audit.log` as a fourth sibling log class.

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
  is a consumed interface because `bin/dashboard/audit-log.js` is a dedicated
  parser on the other side of that contract. Naming a format as "consumed"
  surfaces the bidirectional coupling: changes to the emitter require coordinated
  changes to the parser, and the test contract test (`tests/microworld-audit-contract.test.js`)
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
  runs but does not block), `block` (audit line written, classifier runs and blocks on
  `mismatch` at stop-gate.sh:290). Parallel to [[Dispatch hygiene]]'s `dispatchHygiene.mode`
  posture. Consumed by `stop-gate.sh:276,284` in its review-join validation loop.

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

**Adapter behavioural parity**:
(issue #202, 2026-08-01 efficiency pass 2,
  Step 4) — a merge-gate check that the adapter ports' *scripts* produce the
  same observable behaviour as the main Claude Code hook, not merely that
  the same *text* is present. `tests/adapter-stop-gate-parity.test.sh`
  drives `hooks/scripts/stop-gate.sh` and both adapter ports
  (`adapters/{codex,cursor}/hooks/scripts/stop-gate.sh`) through the same
  `defer:`-dedupe scenarios *and* the empty-after-colon `defer:`/`skip:`
  rejection scenario, asserting the same audit-log record count and exit
  code from each, scoped to those two scenarios — not a general
  behavioural-parity guarantee for every hook. Do not conflate with the
  other two parity mechanisms in this repo: **byte-parity**
  (`tests/validate.sh`'s check that the three copies of
  `hooks/scripts/lib/agent-identity.sh` are byte-identical, since that file
  derives its behaviour from its own on-disk location rather than any
  per-platform input) and **document/section-presence parity**
  (`tests/adapter-protocol-parity.test.js`, which checks that canonical
  protocol *sections* are accounted for in the Codex/Cursor doc ports —
  presence, not runtime behaviour). See
  [modules/adapters.md](.claude/wiki/modules/adapters.md) and
  [modules/hooks.md](.claude/wiki/modules/hooks.md).

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
  unit currently under review, written by `reviewer-route-gate.sh` when a
  reviewer is dispatched and consumed by `stop-gate.sh` when that unit's verdict
  marker is found. Contains a single line with timestamp, unit id, and optional
  prior marker metadata for concurrency detection. Replaces the global
  clear-watermark; enables per-unit verdict coupling without cross-dispatch
  interference. See [ADR-0016](docs/adr/0016-per-unit-review-join.md) for design
  and [modules/hooks.md](.claude/wiki/modules/hooks.md) for implementation.
_Avoid_: clear-watermark

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
  `sonnet`→`opus` or `haiku`→`sonnet` on re-attempt. This ratchet expires on a
  subsequent verified PASS marker for that unit (unit #233). Distinct from the
  reviewer-gate ratchet.

**Reviewer-gate ratchet**:
the `.fail` disqualifier on the reviewer's own
  model eligibility. A unit's `.claude/reviewed/<task-id>.fail` record from the
  reviewer permanently forces `opus` on that unit's reviewer gate, regardless of
  whether a subsequent PASS marker exists. This ratchet never expires
  (unit #233, OQ3 ruling). The asymmetry (implementer tier expires, reviewer gate
  does not) preserves the core safety property: if a reviewer has once missed
  something on a cheaper tier, all future reviews run on the full-strength tier.
  Distinct from the implementer-tier ratchet.

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
  `files` array intentionally ships only 2 of 17 skills to npm:
  `skills/coding-discipline` and `skills/install-antislop`. All other
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
  property is proven executably by test cases (gh132 `tests/microworld-rerun.test.sh`
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
  `## What to look at first`. Quotes the diff, never reproduces it; soft cap 400
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
  `tests/dashboard-markdown-lite.test.js`, not by design assumption — verify
  against shipped test cases, not by re-reading this entry.

**Microworld dashboard**:
(unit #314, 2026-08-10, forward-looking; built and documented unit #322,
  2026-08-11) — the loopback-only HTTP server/UI process itself, started via
  `node bin/cli.js --dashboard` (nothing auto-starts it), that lets a human
  browse and invoke **microworld bundles** without manual CLI invocation. Binds
  to `127.0.0.1` on an ephemeral port; every request requires a per-launch
  token via `?t=<token>` or `X-Antislop-Token` (see `server.js:21`/`:45-47`).
  Writes nothing to disk — invocation results live only as ephemeral, in-page
  **Cell**s. Documented in `README.md`'s "Microworld dashboard" section
  (`README.md:177`). Distinct from **Microworld** (an individual bundle's
  rendered dashboard entry a human explores) and **Microworld bundle** (the
  gitignored `microworlds/<unit-slug>/` directory the dashboard renders) — this
  entry is the process/UI as a whole, the other two are what it displays.
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
  does not consult `bin/dashboard/audit-log.js`'s live rerun-status parsing,
  so packets render as a static snapshot with no pass/fail/timeout indicator,
  unlike `source: "working"` bundles.
_Avoid_: bundle origin (use "bundle source" for clarity); "working bundle" as
  a synonym for the gitignored `microworlds/<unit-slug>/` directory itself —
  that directory is the canonical **microworld bundle** (see entry above);
  "working" is only the `source` field's value when a bundle of that kind is
  discovered. `tests/dashboard-packets.test.js`, `bin/dashboard/index.html`'s
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
(unit #318, 2026-08-10) — the static single-file HTML client (`bin/dashboard/index.html`)
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
  word, not an agent's paraphrase.

**The human-decision gate** (`human-decision-gate.sh`):
(unit #325, 2026-08-11, Step 1 of #324) — the new `PreToolUse` hook (`Write|Edit`
  and `Bash` matchers) that blocks **every** agent identity from writing a
  [[DECISION file]] — reviewer included, empty/main-session `agent_type` included.
  Contrast with `reviewed-path-gate.sh`: that gate has a grant branch (the reviewer
  may write `.claude/reviewed/*.pass`, and a no-reviewer fallback exists for the
  main session); this gate has no grant branch and no fallback — no identity may
  ever write a DECISION file, full stop. Reads stay allowed for both gates. The
  two gates share their read-only/text-only command classifier, extracted in this
  same unit into `hooks/scripts/lib/benign-command.sh` (previously private to
  `reviewed-path-gate.sh`). The sanctioned way to discard a resolved escalation
  packet is `rm -rf .claude/human-review/<task-id>` (the whole directory) — its
  command text never spells `DECISION`, so it clears the gate's substring
  early-exit; a per-file `rm .../DECISION` is blocked for every identity, reviewer
  included, by design. No adapter port exists, the same precedent already set by
  `reviewed-path-gate.sh`.

**Escalation-laundering**:
(unit #326, 2026-08-11, Step 2 of the human-decision-channel fix, issue #324) —
  the specific attack this unit closes: deselecting the reviewer persona (removing
  `reviewer` from `.claude/persona-config.json`'s `personaSelection`) to
  unconditionally re-arm `reviewed-path-gate.sh`'s no-reviewer fallback for
  `.claude/reviewed/`, even while a standing `.escalated` marker exists — letting
  the main session/team lead silently discard a pending `ESCALATE-TO-HUMAN`
  escalation with zero human artifact, since only the reviewer ever writes
  `.escalated` and a standing one under a reviewer-less config proves the
  deselection post-dates the escalation. Contrast with the legitimate no-reviewer
  fallback (`reviewed-path-gate.sh:96-117`), which this unit preserves unchanged
  when no `.escalated` marker stands. Closed by the branch at
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

