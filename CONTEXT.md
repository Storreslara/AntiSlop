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
  refreshing ADAPT-stamped files. Crucially, the `--check` flag is a
  force-the-loop control, not a dry-run: `--check` still writes files via
  `copyStampedBody` and still rewrites `persona-config.json`, unlike
  `scripts/resync-vendored-skills.sh --check` which is genuinely read-only.
  Stamps self-heal automatically: `--update` refreshes a mirror's
  `<!-- antislop vX.Y.Z -->` stamp whenever the resolved plugin version
  differs from the stamp on disk, even when the mirror's body content is
  unchanged, retiring the prior hand-patch workaround.

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
  `persona-config.json`'s `dispatchHygiene` (default mode `block`); single-use
  escape hatch `.claude/.dispatch-override`. H3 is anchored by a `commit:`
  field in the PASS marker (v3 format, see [ADR-0015](docs/adr/0015-commit-anchored-pass-markers.md)) that
  records the commit at which the unit was marked done: a marker from an
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
the subset of `templates/persona-protocol.md`'s 16
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

**Harness**:
Claude Code the product — the IDE plugin and surrounding runtime
  infrastructure that hosts all personas, hook scripts, and agent dispatches.
  Distinct from "hook infrastructure" or "this repo's own gates" — the harness
  is the shared platform, not this project's local adaptation of it. When hook
  logic fails at the harness level (e.g., named dispatch defeating
  `agent_type` privilege checks, or `Write`/`Edit` grant rejection at
  tool-call time), mitigation is via protocol documentation or harness
  upgrade, not repo-side code.

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
the standing convention that `Agent` tool calls should dispatch without a `name:` parameter by default, causing their result to auto-return on completion. Named dispatch is reserved only for cases requiring **mid-flight addressability** — querying or re-tasking a long-running subagent mid-way through. The one exception is the 2-FAIL-cap / debug-spec scenario in "Nested dispatches", where explicit naming is mandatory. Deferred companion: a **mechanical report-loss backstop** to detect named agents completing without reporting (recorded in agents/orchestrator.md for future implementation when needed).

**FAIL routing (post-reviewer)**:
normal FAIL routes the defect list to
  `lead-programmer` (unchanged). At the 2-FAIL cap, the orchestrator routes to
  `spec-master` to produce a debug spec (diagnosis using the latest `.fail`
  record plus git log/git diff over fix-attempt commits, revised steps) then
  `task-master` re-derives dispatch instructions from the corrected spec.
  `task-master` is never a re-plan owner. Mid-flight "spec gap" signals also
  route back to `spec-master`.

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
(unit #314, 2026-08-10) — the gitignored `microworlds/<unit-slug>/`
  directory holding a check's canonical definition: `manifest.json` (with
  `functions[]` array, `location`, `watch`, `timeoutSeconds`, `inputs/`,
  `expected/` paths), `run.sh` (the entry-point executable), and `README.md`.
  Ship-time output of a spec/lead-programmer unit; consumed at review time and
  (in D2+) rendered into a dashboard entry for human exploration. Distinct from
  the rendered **microworld** (the UI) and from **function entry** (an individual
  named executable in the bundle's `functions[]`).

**Microworld**:
(unit #314, 2026-08-10, forward-looking) — the dashboard entry a human
  explores, rendering the canonical definition from a **microworld bundle**.
  The dashboard itself is a D2+ artifact not yet built; this term is normative
  in protocol prose but the dashboard's own glossary entries may differ once
  authored. Coordinate with the step owning the dashboard if clarification is
  needed. Distinct from **microworld bundle** (the gitignored directory).

**Function entry**:
(unit #314, 2026-08-10) — a named, invocable executable declared in a
  **microworld bundle**'s `functions[]` array in `manifest.json`. Each entry
  defines the executable name, location (relative path), optional watch list,
  timeout, and input/expected paths. One bundle may declare many function
  entries; each corresponds to an executable the lead-programmer or reviewer
  can invoke during development and validation.

**Relocatable run.sh**:
(unit #132, 2026-08-10) — a **microworld bundle** requirement and proven
  property: the bundle's `run.sh` must behave identically whether invoked
  from inside `microworlds/<unit-slug>/` or copied elsewhere (e.g. into a
  future escalation packet). File paths reach `run.sh` as a single positional
  parameter, never `eval`-interpolated, enforcing safe path injection. This
  property is proven executably by test cases (gh132 `tests/microworld-rerun.test.sh`
  cases (f)/(f2)), not merely assumed — a dependency for Step D8 (microworld escalation)
  in the separate dashboard plan.

**The dashboard**:
(unit #314, 2026-08-10, forward-looking) — the D2+ UI entry point for human
  exploration of **microworld** bundles (defined normatively in protocol at
  `templates/persona-protocol.md:338` but the dashboard itself and its own
  glossary entries are not yet built). Use in protocol is forward-looking;
  future protocol amendments may refine terminology once the dashboard design
  is complete.

**Bundle source**:
(unit #315, 2026-08-10) — the `source` field in a microworld bundle object,
  indicating the origin of the bundle. Currently defined value: `"working"` for
  bundles enumerated from the local `microworlds/` directory. Forward-looking:
  `"packet"` namespace is reserved for bundles sourced from external origins in
  later steps (D8+). Trust boundary marker: `source: "working"` bundles are
  subject to repo-own validation and live within the same trust domain as the
  repository itself.
_Avoid_: bundle origin (use "bundle source" for clarity)

**Bundle id namespace**:
(unit #315, 2026-08-10) — the prefix scheme for **microworld bundle** ids,
  enabling forward-compatible routing of bundles from different sources without
  collision. Defined values: `working:<unit-slug>` for bundles discovered from
  local `microworlds/<unit-slug>/` directories; `packet:<task-id>` reserved for
  bundles sourced from external origins in later steps (D8+). The directory
  slug (not the manifest's `unit` field) is used for the working: namespace to
  establish a stable, collision-resistant canonical id. Distinct from the
  **source** field: a bundle's `id` is namespaced (machine routing), while
  `source` is the semantic origin marker (human understanding / trust boundary).
  Unit #317 adds a `dirSlug` field to discovered bundle objects, holding the
  canonical directory slug used by `server.js` to resolve invocation paths,
  eliminating the discovery/invocation path-mismatch defect.
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

