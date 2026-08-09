# Microworlds, ubiquitous language, and human-in-the-loop review

Date: 2026-07-28 | Author: `spec-master` | Status: finalized, ready for
`task-master` slicing

**Revision 2 — 2026-07-28.** Open Questions 2, 3, and 4 answered by the
user. Question 3's answer (**bundles are gitignored, not committed**)
overrode this plan's recommended default and invalidated the premise that
made microworld bundles durable, so this revision reconciles the rest of the
spec with it: a durable escalation packet at `.claude/human-review/<task-id>/`
(Step 4), `run.sh` relocatability plus an executable relocation test
(Steps 2, 3), `.gitignore` coverage across all three scaffold lists **and**
`--update` (Step 3, R9), packet lifecycle across all three human-decision
routes (Step 7), and the accepted clone-fragility cost (R10, Step 8).
Question 1 (`.directed`) remains open with its default applied and does not
block slicing.

## Goal

Add three coupled capabilities to the antislop persona plugin, all shipped
to every ADAPT-ed downstream project (not just this repo):

1. **Ubiquitous language check** — a new advisory `antislop:ubiquitous-language`
   skill on the `reviewer` persona that reads the project's existing
   shared-language glossary (`CONTEXT.md`) and reports naming/terminology
   drift introduced by the diff, as non-blocking notes appended after the
   verdict. Never a FAIL ground.
2. **Microworlds** — per-unit runnable bundles (`microworlds/<unit>/`)
   carrying inputs + expected outputs, produced by `lead-programmer`,
   executed by `reviewer`, and **re-run reactively** on every source edit via
   the existing `PostToolUse(Edit|Write)` hook seam, so breakage surfaces on
   the fly instead of only at a one-shot review.
3. **Human-in-the-loop escalation** — a fourth reviewer verdict,
   `ESCALATE-TO-HUMAN`, with its own `.claude/reviewed/<task-id>.escalated`
   marker. On a *critical* unit the reviewer would otherwise PASS, it
   instead hands the unit's microworld to an actual human, who runs it live
   and returns one of three decisions: approve, reject-with-reason, or
   fixable-a-specific-way.

The three are deliberately coupled: (1) sharpens what the reviewer *says*,
(2) produces the artifact a human can actually *run*, and (3) is the routing
that puts a human in front of it.

## Context

### Why this exists (rationale — read before the steps)

The user's stated motivation for (3) is to **deliberately slow down
hyperscaling-by-default**: unchecked full automation produces slop, and this
system's agent-teams mode is precisely the full-autonomy gear where that
risk concentrates. Human escalation is friction *on purpose*.

**This ships on by default.** `humanReviewMode` defaults to `critical`, not
`off`. That is a real, intentional behaviour change for every
already-adapted project on its next plugin update: units meeting the
existing heavy-unit trigger will stop auto-PASSing and will block turn-end
until a human decides. This is an accepted, informed tradeoff chosen by the
user over the alternative (off-by-default, opt-in), not an oversight and not
something to soften in the CHANGELOG or the release note. The release note
must say plainly that the default is on.

### Design provenance — where "microworld" comes from

The word **microworld**, and the framing this plan sits inside, are taken from
a Geoffrey Litt (@geoffreylitt) thread written up from his AIE talk —
canonical tweet `https://x.com/geoffreylitt/status/2072522251300409556`,
archived at
`https://threadreaderapp.com/thread/2072522251300409556.html`. Cited so a
later reader can check this plan against its source instead of re-deriving the
intent from the word alone.

**The load-bearing claim is about why humans read code at all.** Litt
separates understanding *to verify* — a thumbs-up/thumbs-down on the agent's
work — from understanding *to participate*: holding enough fluency in a
system's concepts to have the next idea about it. His argument is that agents
keep getting better at the first, so the first is the weaker reason to stay in
the loop; the second is the durable one, and neglecting it accrues "cognitive
debt" (Storey / @simonw) that comes due later. This plan's own "Why this
exists" above is stated purely in verification terms — unchecked automation
produces slop. That is correct but partial: the participation half is the
stronger argument for ask #3, because escalation is the one point in this
system where a human is *required* to hold a model of what was built.

**The source's four techniques, mapped onto this plan:**

| Litt's technique | This plan |
|---|---|
| **Micro-worlds** — Papert's "Mathland": inhabit an environment and intuit the system by playing with it. His examples are a step-through Prolog debugger with time-scrubbing, and a "command center" UI where he ran a framework migration step by step with old and new sites side by side. | Ask #2, **deliberately narrowed** to a fixture bundle whose contract is `run.sh`'s exit code — see below. |
| **Shared spaces / shared vocabulary** — teams holding one mental model can "jam and riff" because the same word evokes the same image in both heads. | Ask #1, `antislop:ubiquitous-language`. Instantiated as a deterministic glossary-drift check against `CONTEXT.md` (constitution P2) rather than as a collaborative document surface, but it is the same idea and the same motive. **Not a gap.** |
| **Explanations** (`/explain-diff`) — background before the change, intuition before details, and a "literate diff" ordered as prose by concept rather than alphabetically by filename. | **No counterpart.** Explicitly *not* covered by ask #1: `ubiquitous-language` checks whether names are used consistently and says nothing about whether a change is *explained* well. Recorded as a gap — Step 10 below. |
| **Comprehension quizzes** — a handful of questions per explainer; his personal rule is not to ship code until he can pass them, framed as a "speed regulator" against the loop outrunning human understanding. | **No counterpart.** Recorded as a gap — Step 11 below. |

**The narrowing of "microworld", stated so it is not mistaken for a
misreading.** Litt's microworlds are *interactive* — their defining property
is that a human plays with them and the understanding is a by-product of the
play ("there's a big difference between making a tool for me to debug and
letting the agent debug"). Step 2's bundle is not that; it is a fixture
harness that returns a verdict. This is the user's explicit reinterpretation,
logged in Clarifications on 2026-07-28, and it is right for the two consumers
that dominate a bundle's life: the `reviewer` and the `PostToolUse` rerun hook
both want a binary result, not an environment. What the narrowing costs is
confined to the one path where a *human* is the consumer — see Step 9 below.

**Not from the source, and not claimed to be.** Reactive re-running on edit
(Step 3's `PostToolUse` hook), `ESCALATE-TO-HUMAN`, the marker state machine,
and the escalation packet are all this plan's own additions; the thread
describes no watch/rerun mechanism and no review-routing machinery.

**Unresolved in the source.** The thread's links to the `/explain-diff` skill
gist and to the blog-post version of the talk are truncated in the archived
transcript this plan was written against, and were not fetched. Steps 10 and
11 are therefore specified from the thread's prose description of each
technique, not from Litt's implementation of it.

### Bundle storage: gitignored scratch, plus a durable escalation packet

**Microworld bundles are gitignored, not committed.** This is the user's
decision, taken on 2026-07-28 against this plan's own earlier recommended
default of "committed" (former Open Question 3). It is a deliberate
override, not a confirmation, and the reasoning it overrides was real:
committing bundles made them survive process and session boundaries for
free. Gitignoring them does not, so the gap has to be closed explicitly
rather than absorbed quietly.

**What gitignoring actually costs.** A `microworlds/<unit>/` bundle becomes
**working-tree scratch**: it exists for the life of a checkout, is never
part of a commit, never appears in `git status` or `git diff`, is never
reviewed as code, and is destroyed by `git clean -fdx` or by cloning fresh.
Everything ask #2 needs still works — `lead-programmer` writes the bundle,
the `PostToolUse` rerun hook re-runs it on edits, and the `reviewer` executes
it — because all three happen in the same working tree. What breaks is ask
#3's *later-session* property: a human who is not available the moment
`ESCALATE-TO-HUMAN` fires has nothing left to run.

**Resolution — a durable escalation packet, not synchronous-only review.**
Of the two ways out (scope human review to same-session only, or persist the
escalated bundle specifically), this plan takes the second. When the reviewer
escalates, it **snapshots the unit's bundle** into
`.claude/human-review/<task-id>/` — untracked but persistent, deleted only
when the reviewer resolves the unit. Rationale, in order of weight:

1. **Synchronous-only review would defeat the point of the feature.** Ask #3
   exists to *slow the machine down* until a human looks (see "Why this
   exists" above). A human-review path that expires when the session ends
   converts "wait for a human" into "wait ~one session, then the evidence is
   gone", which is exactly the pressure toward rubber-stamping the friction
   was chosen to resist.
2. **It reuses a mechanism the plan already has**: markers already carry
   their own decision content as file bodies, and the `.escalated` marker
   already carries the run command, the input/expected-output description,
   and the reviewer's would-be verdict. The packet is that same
   "state lives in an untracked file on disk" idea extended from bytes of
   prose to the directory those bytes describe.
3. **It sits outside `.claude/reviewed/` on purpose.** Per the architectural
   fact below, `reviewed-path-gate.sh` blocks *any* Bash command whose text
   contains `.claude/reviewed`, read-only ones included, for every non-
   reviewer caller. A runnable packet under that path could not be run by
   the orchestrator or by a human working through the session.
   `.claude/human-review/` is ungated, so the human can actually run it.

**The tradeoff this buys, stated plainly rather than softened.** The packet
is untracked, so it is durable across *sessions* but not across *clones*:
`git clean -fdx`, a fresh clone, or a discarded worktree destroys a pending
escalation, and the unit then has an `.escalated` marker (also untracked,
also destroyed) and no packet. Nothing recovers it automatically; the
reviewer must re-review and re-escalate. This is accepted — the alternative
is committing review scratch into project history — and it ships documented
under README's "Known limitations" (Step 8), not discovered later.

**Second-order consequence for the reviewer:** because bundles are not in the
diff, the reviewer must never infer "no bundle was produced" from a clean
`git status`. Bundle presence is a **filesystem** check, not a diff check.
Steps 2 and 4 carry this explicitly.

### Architectural facts this plan is built on (verified, not assumed)

- **Shared-protocol sync is fail-closed.** Canonical
  `templates/persona-protocol.md`; hand-adapted ports at
  `adapters/cursor/rules/persona-protocol.mdc` and
  `adapters/codex/agents-md-fragment.md`;
  `tests/adapter-protocol-parity.test.js` derives the canonical `## ` section
  list from the template and **throws** on any section lacking an explicit
  `{probe}` or `{deferred}` entry in *both* `codexMap` and `cursorMap`, and
  also on a stale map key. Adding a canonical section without touching the
  parity maps is a guaranteed red test.
- **Protocol is inlined per-persona at scaffold time**, not imported.
  `bin/cli.js:34` sets `SLIM_TIER_PERSONAS = ['explorer','researcher','scribe']`
  (they get `persona-protocol-slim.md`); the other six —
  `orchestrator`, `lead-programmer`, `reviewer`, `spec-master`,
  `task-master`, `milestone-auditor` — carry the full
  `persona-protocol.md` inlined into their `.claude/agents/<name>.md` body.
  So a new **full**-protocol section propagates to 6 `.claude/agents/*.md`
  copies, regenerated by `bin/cli.js --update`, never hand-edited
  (constitution P2).
- **`agents/*.md` source files do NOT contain protocol text.** Only
  `.claude/agents/*.md` (the ADAPT-ed copies in this repo) do.
- **Marker/hook state machine.** `hooks/scripts/stop-gate.sh:90-102` is the
  reviewer-`SubagentStop` branch: it globs `.claude/reviewed/*.blocked`, and
  if any exists, logs `verdict=blocked flags-kept` and **keeps** the
  `.pending-review.*` flags standing (blocking turn-end via the `Stop`
  branch and the next gated dispatch via `reviewer-route-gate.sh`);
  otherwise it clears them and logs `cleared-by=reviewer`. This is the exact
  pattern `.escalated` mirrors.
- **`reviewer-route-gate.sh` needs no change for a new marker.** It keys off
  the `.pending-review.*` flags only, never the marker files — so any marker
  that keeps flags standing automatically inherits next-dispatch blocking.
  (`tests/stop-gate-blocked.test.sh` case (c) already asserts this for
  `.blocked`.)
- **Only the reviewer may write `.claude/reviewed/`.**
  `hooks/scripts/reviewed-path-gate.sh` blocks any Bash command whose text
  contains `.claude/reviewed` unless `agent_type == "reviewer"` (or the main
  session, *only* when `reviewer` is absent from `personaSelection`).
  Consequence for this plan: **the human's decision cannot be recorded by the
  human or the orchestrator directly** — it is relayed back through a
  reviewer re-dispatch that transcribes it. This is a constraint, not a
  choice.
- **`.claude/reviewed/` is already gitignored wholesale**
  (`bin/cli.js:1688-1695`), so `.escalated` and `.directed` need **no**
  `.gitignore` change.
- **The `reviewed-path-gate.sh` block is substring-based and covers
  read-only commands.** `hooks/scripts/reviewed-path-gate.sh:29` matches
  `*".claude/reviewed"*` against the *whole Bash command text* and blocks it
  for every caller except `agent_type == "reviewer"` (and the main session
  only when `reviewer` is absent from `personaSelection`). Its own header
  comment states the collateral is accepted: `cat .claude/reviewed/foo.pass`
  is blocked too. **Consequence for this plan, and it is load-bearing:** a
  human-runnable artifact must **not** live under `.claude/reviewed/`. If it
  did, the orchestrator — and therefore the human working through the
  session — could not `bash` it, which is the single thing ask #3 exists to
  enable. The marker stays there (it is read with the Read tool, which is
  ungated); the runnable packet does not.
- **`.gitignore` seeding lives in three separate `appendUnique` lists, and
  `--update` calls none of them.** `bin/cli.js:1688` (claude), `:1053`
  (cursor), `:1427` (codex) each seed their own ignore list at scaffold
  time. `runUpdate` (`bin/cli.js:534`) does **not** call `appendUnique` at
  all — it runs migrations (`migrateGlobalProtocolImport`,
  `removeStaleProtocolCopy`) and disk backfills instead. **A new ignore line
  added only to the scaffold lists therefore never reaches an
  already-adapted project.** This is structurally the same hazard as R1,
  applied to `.gitignore` rather than to a config default, and it is why
  Step 3 extends `runUpdate` with an idempotent `appendUnique` call rather
  than relying on the scaffold path alone.
- **Adapter stop-gate mirrors are hand-adapted, not identical copies.**
  `adapters/{cursor,codex}/hooks/scripts/stop-gate.sh` carry the same ordered
  decision logic with different payload extraction and header prose. Port
  the `.escalated` branch by hand in each port's own style; do not
  copy-paste the canonical file over them.
- **No reactive/watch mechanism exists anywhere in this codebase.** No
  entr/nodemon/chokidar/inotify, no npm dev script. The only reactivity is
  the synchronous `PostToolUse(Edit|Write)` hooks (`graph-update.sh`,
  `lint-on-edit.sh`), registered in `hooks/hooks.json`. Microworlds ride
  that seam. **No daemon is introduced** (constitution P2).
- **`CONTEXT.md` already exists and is the glossary.** Repo root, 82 lines,
  headed "Shared-language glossary for this repo… owned by `scribe`".
  `agents/scribe.md:16` names `CONTEXT.md` + `docs/adr/` as canonical and
  requires scribe to create starter versions if absent. The existing
  `antislop:domain-modeling` skill is the *authoring* side ("Merely reading
  `CONTEXT.md` for vocabulary is not this skill"). The new
  `ubiquitous-language` skill is the *consuming* side. Clean seam, no new
  document format, no overlap.
- **Skill delivery mechanics.** `bin/cli.js:1636-1637` copies only
  `install-antislop` and `coding-discipline` into `.claude/skills/`. Every
  other skill (`roast-work`, `pathfinder`, `fail-triage`, …) reaches a
  persona at runtime through the plugin-marketplace namespace
  `antislop:<name>` referenced from the persona's `skills:` frontmatter.
  A new skill therefore needs **neither** a `bin/cli.js` copy-list entry
  **nor** a `package.json` `files` entry.
- **`package.json`'s `files` array ships only 2 of 16 skills** — a latent,
  pre-existing gap that `validate.sh`'s npm-pack check structurally cannot
  detect (it asserts the `skills/` prefix is present, not that any specific
  skill is). **Do not "fix" it here**: the existing precedent is that skills
  reach users via the git/marketplace path, not npm. Stated explicitly so
  the omission is a recorded decision rather than an accident.
- **Confirmed as the user requested:** shipping `humanReviewMode`'s default
  as `critical` rather than `off` changes **nothing** about the
  npm-skill-packaging answer above. The default value is a
  `persona-config.json` / consumer-fallback concern; skill packaging is a
  plugin-resolution concern. Two independent mechanisms; the answer to one
  does not move the other.
- **`--update` preserves judgment-driven config fields.**
  `bin/cli.js:1700-1711` refreshes only `personaSelection` and
  `pluginVersion` on an existing `persona-config.json`; every other field is
  preserved verbatim. **A new `humanReviewMode` key will therefore NOT
  appear in already-adapted projects.** This is why the shipped default must
  be encoded as the **absent-key fallback in the consumers**
  (`reviewer` + `stop-gate.sh`), not merely as a value in the skeleton
  `bin/cli.js` writes for fresh installs. Getting this wrong is the single
  most likely way to ship "on by default" that is silently off for every
  existing user.
- **The protocol digest is capped.** `templates/protocol-digest.md` is 26
  lines and its own header comment says "Keep this under ~15 lines — if it
  grows, mechanize the rule (a hook) instead of making the digest longer."
  So this plan amends **one existing bullet in place** rather than adding a
  new one.
- **Version-bump coupling is a hard constraint** (see G1).

### Global constraints

**G1 — the version-bump triple.** Every unit in this plan touches a
version-stamped file (`agents/*.md`, `templates/*`, `hooks/*`, or a new
skill). Constitution P3 (MUST) requires a `.claude-plugin/plugin.json`
version bump plus a CHANGELOG entry for each; `tests/validate.sh:34-42`
(constitution P5, MUST) FAILs if `package.json`'s `version` differs from
`.claude-plugin/plugin.json`'s. Therefore **every** unit additionally
touches, without exception:

- `.claude-plugin/plugin.json` (`version`, patch bump)
- `package.json` (`version`, same value)
- `CHANGELOG.md` (an entry for that unit)
- `.claude/persona-config.json` (`pluginVersion`, same value)

Verified empirically against 3/3 recent version-bump commits. Each unit
bumps the patch level independently; no consolidation into a single release
is required.

**G2 — never hand-edit generated files.** `.claude/agents/*.md` (protocol
inlining, version stamps) and `persona-config.json`'s `fileHashes` have a
script-driven path (`bin/cli.js --update`). Constitution P2 (MUST) forbids
hand-editing them. Any unit changing a template or an `agents/*.md` source
must regenerate via `bin/cli.js --update` and let it update `fileHashes`.

**G3 — optional-persona phrasing.** `reviewer`, `scribe`, `spec-master`,
`task-master` are opt-out personas (constitution P4, SHOULD). All new prose
in `templates/persona-protocol.md` and the adapter ports referencing them
must be conditionally phrased ("if present, otherwise…").
`tests/validate.sh` has a paragraph-scoped checker that hard-fails on a bare
unconditional `reviewer`/`scribe`/`researcher` reference.

## Clarifications

Rescored 2026-07-28 (second pass) after the user answered Open Questions 2,
3, and 4. Categories 3 and 6 moved Partial → Clear; category 2 stays Partial
because Open Question 1 (the `.directed` marker mechanism) is the one item
still carrying an applied default rather than a user answer.

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-28 Functional scope & success criteria: Q Are all three asks in
  scope for one spec, and does "microworlds" mean literal Papert-style
  simulations? → A: all three in one coupled spec; microworlds are
  fixture-based per-unit runnable bundles (inputs + expected outputs), not
  literal simulations, per the user's reinterpretation of the Litt talk.
- 2026-07-28 Domain entities / data model: Q Where does the microworld
  artifact live, and does the "fixable in a specific way" route need its own
  durable record? → A (self-resolved): bundles at `microworlds/<unit>/` with
  a `manifest.json` + `run.sh` convention (Step 2); the fix-directive route
  gets its own `.claude/reviewed/<task-id>.directed` marker, because the
  2-FAIL cap counts `.fail` records only and a route with no durable record
  is invisible to a fresh spawn — the exact gap `.fail` records exist to
  close. Surfaced as Open Question 1 with this default already applied.
- 2026-07-28 User interaction flow: Q Who writes the marker that records the
  human's decision, given the human works through the main session? → A
  (self-resolved): the reviewer, always — `reviewed-path-gate.sh` blocks the
  main session from `.claude/reviewed/` whenever `reviewer` is in
  `personaSelection`, so the human's decision is relayed back through a
  reviewer re-dispatch that **transcribes** it without re-adjudicating.
- 2026-07-28 Non-functional attributes (perf, security, scale): Q Does the
  reactive test suite need a watch daemon? → A (self-resolved): no — it
  rides the existing `PostToolUse(Edit|Write)` hook seam; zero watcher
  precedent exists in this codebase and constitution P2 (MUST) prefers
  deterministic scripts over new machinery. Bounded by manifest-glob
  matching plus a timeout so per-edit cost stays near zero for unrelated
  edits.
- 2026-07-28 External dependencies & integrations: Q Must the new skill be
  added to `package.json`'s `files` array to reach users? → A
  (self-resolved): no — `bin/cli.js:1636-1637` copies only two skills
  locally; the rest resolve via the `antislop:` plugin namespace. Confirmed
  independently that shipping `humanReviewMode` on-by-default does not
  change this answer.
- 2026-07-28 Edge cases / failure handling: Q What happens when no human is
  present (CI / unattended run)? → A: hold the `.escalated` marker and
  require the existing `defer:`/`skip:` escape hatch on the pending-review
  flag — already-live machinery that leaves an audit trail — rather than
  silently auto-falling-back to the reviewer's own automated verdict, per
  user.
- 2026-07-28 Technical constraints & tradeoffs: Q Is `package.json` in the
  blast radius of a skill/agent/template change? → A (self-resolved): yes —
  its `version` field is, via `tests/validate.sh:34-42` (constitution P5)
  and constitution P3; only its `files` array is not. Verified empirically
  against 3/3 recent version-bump commits. Encoded as G1.
- 2026-07-28 Terminology consistency: Q How is a unit classified "critical",
  and does `.escalated` collapse into `.blocked`? → A: reuse the existing
  heavy-unit trigger verbatim from `templates/persona-protocol.md`'s
  "Reviewer roast-work advisory pass trigger" section (≥8 files / ≥400
  changed lines, structural/cross-cutting, or security-sensitive) — inventing
  a second near-duplicate risk taxonomy would itself be the
  terminology-inconsistency defect ask #1 exists to catch. `.blocked` and
  `.escalated` stay semantically distinct ("reviewer lacked context" vs
  "policy requires human eyes") and distinguishable in `review-audit.log`,
  per user.
- 2026-07-28 Completion / acceptance signals: Q What is the runnable
  acceptance criterion for a new protocol section? → A (self-resolved):
  `node tests/adapter-protocol-parity.test.js` exiting 0, which requires an
  explicit per-port `{probe}` or `{deferred}` entry in both `codexMap` and
  `cursorMap`; plus `bash tests/validate.sh` exiting 0 as the merge gate
  (constitution P5).

Appended 2026-07-28 (second pass — the user's answers to the surfaced Open
Questions, plus the decisions those answers forced):

- 2026-07-28 Domain entities / data model: Q Are `microworlds/` bundles
  committed to the repo, or gitignored? → A: **gitignored**, per user —
  overriding this plan's recommended default of "committed". Bundles are
  working-tree scratch; nothing in a commit, a fresh clone, or CI depends on
  one existing.
- 2026-07-28 Edge cases / failure handling: Q If bundles are gitignored, how
  does a human review an escalated unit in a *later* session, when they were
  not available the moment `ESCALATE-TO-HUMAN` fired? → A (self-resolved):
  the reviewer snapshots the escalated unit's bundle into
  `.claude/human-review/<task-id>/` — untracked but persistent — rather than
  scoping human review to same-session-only. Same-session-only was rejected
  because an expiring human-review path pressures toward rubber-stamping,
  which is the exact failure mode ask #3 exists to prevent. See Context,
  "Bundle storage".
- 2026-07-28 User interaction flow: Q Can the durable packet live under
  `.claude/reviewed/` alongside the marker? → A (self-resolved): no —
  `reviewed-path-gate.sh:29` blocks any Bash command whose text contains
  `.claude/reviewed` for every non-reviewer caller, read-only commands
  included, so neither the orchestrator nor a human working through the
  session could run it. The packet lives at the ungated
  `.claude/human-review/<task-id>/`; the authoritative marker stays gated.
- 2026-07-28 Technical constraints & tradeoffs: Q Does gitignoring bundles
  impose any new constraint on the bundle format itself? → A
  (self-resolved): yes — `run.sh` must resolve its own bundle-internal
  assets from its own directory rather than from a hard-coded
  `microworlds/<unit>/` prefix, because the escalation packet is a *copy* at
  a different path. Encoded as a Step 2 format requirement with a Step 3
  relocation test.
- 2026-07-28 External dependencies & integrations: Q Will the new
  `.gitignore` entries reach already-adapted projects? → A (self-resolved):
  not by default — `runUpdate` (`bin/cli.js:534`) never calls `appendUnique`,
  so scaffold-only ignore lines reach fresh installs only. Step 3 extends
  `runUpdate` with an idempotent `appendUnique` call; recorded as R9, the
  `.gitignore` analogue of R1.
- 2026-07-28 Edge cases / failure handling: Q Should a failing microworld
  surface via hook exit 2, or only via the audit log? → A: **exit 2 plus an
  audit line**, per user — confirming the default already applied in Step 3
  case (d). No change to the steps.
- 2026-07-28 Functional scope & success criteria: Q Does this repo author its
  own `microworlds/` bundles for Steps 3 and 5, or only ship the capability?
  → A: **ship only**, per user — confirming the default already applied.
  Steps 3 and 5's fixture-driven `.test.sh` files serve the same purpose for
  this repo's own units. No change to the steps.

## Risks and dependencies

- **R1 — "on by default" that is silently off.** If `humanReviewMode`'s
  default lives only in `bin/cli.js`'s fresh-install skeleton, every
  already-adapted project keeps a config with no such key, and
  `--update` will not add one (`bin/cli.js:1700-1711` preserves existing
  fields). The absent-key fallback in `reviewer` and `stop-gate.sh` MUST
  resolve to `critical`. Step 6 makes this a first-class, separately tested
  requirement.
- **R2 — stranded version stamps in `.claude/agents/*.md`.** Recent history
  (`e184e7d`, `dc46914`) shows agent copies repeatedly stranded at older
  versions, and `tests/validate.sh` has **no** stamp-sync check to catch it.
  Mitigation: every unit that changes a template or agent source ends with
  `node bin/cli.js --update` and asserts, as a criterion, that the expected
  `.claude/agents/*.md` copies and `fileHashes` actually changed.
- **R3 — parity test throws on a new protocol section.** Expected, not a
  surprise: Steps 2, 4 add canonical sections and must add matching entries
  to both `codexMap` and `cursorMap` in the same unit. A `{deferred}` entry
  is acceptable only with a written justification in the map value string.
- **R4 — microworld rerun noise during the TDD red phase.**
  `lead-programmer` is TDD-first and deliberately produces failing states.
  Mitigation: the microworld rerun hook is **advisory only** — it never
  blocks and never gates; a microworld result becomes authoritative only
  when the spec step's acceptance criteria names it (Step 2). Manifest-glob
  scoping keeps unrelated edits silent.
- **R5 — stale `.escalated` after `skip:` (accepted, pre-existing shape).**
  Writing `skip: <reason>` into a pending-review flag deletes the flag but
  not the marker file. At the next reviewer `SubagentStop`, the stale
  `*.escalated` glob would keep flags standing again. This hazard exists
  today, identically, for `*.blocked` — the glob is by filename. It fails
  **safe** (over-blocks, never under-blocks) and is resolved when the
  reviewer next resolves that unit and deletes the marker. Documented as a
  known limitation in Step 8, not fixed here.
- **R6 — reviewer re-adjudicating a human decision.** The reviewer is an AI;
  on the human-decision re-dispatch it must transcribe, not re-review, or
  the human-in-the-loop property is lost. Step 7 makes "transcription, not
  re-review" an explicit instruction with the human's text relayed verbatim.
- **R7 — no prior `.fail` records to weigh.** `.claude/reviewed/` is
  gitignored and this session cannot read it (`reviewed-path-gate.sh` blocks
  Bash access for `spec-master`). No prior FAIL history is known for any
  unit here. `task-master` should treat every unit in this plan as
  judgment-heavy: **no unit in this plan is `haiku`-eligible** — each one
  touches a fail-closed gate, a hand-adapted port, or a load-bearing default.
- **R8 — downstream-project variability.** Microworlds ship to every
  ADAPT-ed project, which may be any language. The bundle format must be
  language-agnostic (a `run.sh` exit code) and must degrade to a silent
  no-op when no `microworlds/` directory exists. Since bundles are
  gitignored, "no `microworlds/` directory" is now the **normal** state of a
  fresh clone rather than an edge case — the no-op path is the common path,
  not the exceptional one.
- **R9 — the `.gitignore` line that never lands** (the `.gitignore` analogue
  of R1). `runUpdate` (`bin/cli.js:534`) does not call `appendUnique`, so an
  ignore entry added only to the three scaffold lists reaches fresh installs
  and no one else. Every already-adapted project would then see
  `microworlds/` and `.claude/human-review/` as untracked noise in
  `git status` and would plausibly commit them — silently producing the
  exact "committed bundles" outcome the user overrode. Mitigation: Step 3
  extends `runUpdate` with an idempotent `appendUnique` call and asserts it
  with a test over an existing-project fixture.
- **R10 — escalation packets are untracked, therefore clone-fragile
  (accepted).** `.claude/human-review/<task-id>/` survives session
  boundaries but not `git clean -fdx`, a fresh clone, or a discarded
  worktree — and the `.escalated` marker, being under the already-gitignored
  `.claude/reviewed/`, is destroyed by the same events. A pending escalation
  is therefore lost together with its evidence, with no automatic recovery;
  the unit must be re-reviewed and re-escalated. Accepted rather than fixed:
  the alternative is committing review scratch into project history, which
  is what the user's gitignore decision rules out. Mitigations: the
  `.escalated` marker records the commit SHA at escalation time so a human
  can reproduce the state, and Step 8 documents the hazard under README's
  "Known limitations" alongside R5.
- **R11 — packet/marker drift.** The packet's `PACKET.md` is a verbatim copy
  of the `.escalated` marker body, so two artifacts describe one decision.
  Mitigation: they are written in the **same** reviewer action, the copy is
  byte-identical rather than re-summarised, and the **marker is
  authoritative** wherever they differ. Stated in Step 4 so a future reader
  does not treat `PACKET.md` as an independent record.

Dependencies: Steps 4→5→6→7 are ordered (verdict definition, then hook
branch, then config default, then routing). Step 2→3 are ordered. Step 1 is
independent and can land first. Step 8 lands last. Step 4's packet-snapshot
requirement depends on Step 2's bundle format (relocatable `run.sh`) and on
Step 3's `.gitignore`/`runUpdate` work, so Step 2→3→4 is now ordered
end-to-end rather than 2→3 alone.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every step below carries a runnable
  command as its acceptance criterion, and Steps 3, 5, 6 add fixture-driven
  tests that actually execute the hook rather than inspecting its source.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  `.claude/agents/*.md` and `fileHashes` are regenerated via
  `bin/cli.js --update`, never hand-edited (G2); microworld reruns are a
  deterministic shell hook, not a watcher daemon or an LLM pass;
  `humanReviewMode`'s default is a hard-coded consumer fallback rather than
  an LLM-driven config migration; and the new `.gitignore` entries reach
  already-adapted projects through an idempotent `appendUnique` call in
  `runUpdate` (Step 3, R9) rather than through a persona being told to
  remember to add them.
- P3 "Version-stamp discipline": satisfied — G1 makes the plugin.json bump
  plus CHANGELOG entry a mandatory part of every unit's affected-files list.
- P4 "Optional personas degrade gracefully": satisfied — G3; plus Step 1's
  skill no-ops when `CONTEXT.md` is absent, Step 3's hook no-ops when
  `microworlds/` is absent (which, since bundles are gitignored, is now the
  ordinary state of a fresh clone — R8), and Step 6's escalation path is
  inert when `reviewer` is not in `personaSelection`.
- P5 "`tests/validate.sh` is the merge gate": satisfied — `bash tests/validate.sh`
  is an acceptance criterion on every step, and Steps 3, 5 extend it.

## Steps

> Every step also touches the G1 version-bump triple:
> `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
> `.claude/persona-config.json` (`pluginVersion`). Not repeated below.

### Step 1 — `antislop:ubiquitous-language` skill on the reviewer

Create the advisory terminology-drift skill and wire it to the reviewer.
It **reads** `CONTEXT.md` (and, if a root `CONTEXT-MAP.md` exists, the
per-context `CONTEXT.md` files it points to — the same file structure
`skills/domain-modeling/SKILL.md` already documents); it never writes one.
Authoring stays with `scribe` + `antislop:domain-modeling`.

Skill behaviour, in the shape `roast-work` already establishes:
- Produces ONE clearly-demarcated advisory section, appended **after** the
  verdict line, never before or interleaved with it.
- Never flips PASS/FAIL, never adds a FAIL ground, never substitutes for
  running the acceptance-criteria command. The existing materiality filter
  (correctness / security / unmet-acceptance-criteria) remains the only gate.
- Checks: identifiers, type/module names, comments, and docs introduced or
  renamed by the diff against the glossary's defined terms — flagging (a) a
  glossary term used with a different meaning, (b) a new synonym for an
  already-defined term, (c) a load-bearing new domain term the diff
  introduces with no glossary entry (reported as a suggestion for `scribe`,
  if present).
- Every finding names `file:line`, states the drift in one sentence, and
  states the canonical term in one more. If a lens turns up nothing, say so
  briefly rather than omitting it, so a reader can tell it ran.
- **Degradation:** if no `CONTEXT.md` exists, emit a single line saying the
  glossary is absent and that `scribe` (if present) can seed one — then
  stop. Not a finding, not an error.
- Findings are appended to the `.pass` marker along with the reviewer's
  other non-blocking notes, per the existing PASS-marker notes rule.

Also amend `reviewer.md`'s verdict bullet: its current text allows exactly
"one advisory exception… a single, clearly-demarcated `roast-work` advisory
critique section". This becomes **advisory sections** (plural), with a fixed
order after the verdict line: `roast-work` first (if fired), then
`ubiquitous-language` (if fired). The verdict remains the first thing read.

**Affected files**
- `skills/ubiquitous-language/SKILL.md` (new)
- `agents/reviewer.md` (`skills:` frontmatter line; verdict-bullet wording;
  a new bullet stating the skill is advisory-only, mirroring the existing
  "`roast-work` is advisory, never gating" bullet)
- `.claude/agents/reviewer.md` (regenerated via `bin/cli.js --update`, G2)
- `.claude/persona-config.json` (`fileHashes[".claude/agents/reviewer.md"]`,
  written by `--update`, G2)
- `README.md` (skills list, alongside the existing `fail-triage` note)

**NOT touched, deliberately:** `package.json`'s `files` array and
`bin/cli.js`'s skill copy list — see Context; the skill resolves via the
`antislop:` plugin namespace.

**Acceptance criteria**
- `bash tests/validate.sh` exits 0 (this covers the new skill's
  `name:`/`description:` frontmatter via its `skills/*/SKILL.md` loop, the
  package/plugin version sync, and the optional-persona phrasing check).
- `grep -q 'antislop:ubiquitous-language' agents/reviewer.md` exits 0.
- `grep -q 'antislop:ubiquitous-language' .claude/agents/reviewer.md` exits 0
  (proves `--update` propagated).
- `grep -c 'roast-work' agents/reviewer.md` is unchanged from its
  pre-change value plus the new ordering sentence — i.e. the existing
  roast-work advisory-only bullet still exists verbatim.
- `git diff --name-only` includes `.claude/persona-config.json`, proving
  `fileHashes` was refreshed rather than left stale (R2).

### Step 2 — Microworld bundle format (canonical protocol section)

Define the artifact. Add a canonical section
`## Microworlds (per-unit runnable bundles)` to
`templates/persona-protocol.md`, hand-port a condensed equivalent into both
adapter ports in their own established style, and add matching entries to
both parity maps in the same unit (R3).

Format (language-agnostic by design, R8) — `microworlds/<unit-slug>/`:
- `manifest.json` — `{ "unit": "<unit-slug>", "watch": ["<project-relative
  glob>", …], "description": "<one line>", "timeoutSeconds": <int, default
  60> }`. `watch` is the set of source globs this microworld is sensitive
  to; the rerun hook (Step 3) uses it to decide whether an edit is relevant.
- `run.sh` — executable, takes no arguments, runs from the project root,
  exits 0 on pass and non-zero on fail. It is the *only* execution
  contract; anything else in the bundle is its own business.
  **Relocatability requirement (load-bearing, see Storage below):** `run.sh`
  must resolve its own bundle-internal assets (`inputs/`, `expected/`,
  anything else it ships) relative to **its own directory** — e.g.
  `bundle_dir="$(cd "$(dirname "$0")" && pwd)"` — and must **never**
  hard-code a `microworlds/<unit>/` prefix. Paths into the *code under test*
  stay project-root-relative, as before. This is what lets the escalation
  packet (Step 4) be a plain copy at a different path instead of needing
  rewriting.
- `inputs/` — the fixture inputs the piece is exercised with.
- `expected/` — the expected outputs `run.sh` compares against.
- `README.md` — one screen, written **for a human**: what this piece does,
  what the fixtures represent, what a correct result looks like, and what a
  reviewer or human should look at first. This is the packaging ask #3
  depends on; a bundle without it is incomplete.

**Storage — gitignored working-tree scratch** (per user; see Context,
"Bundle storage"). `microworlds/` is added to `.gitignore` in Step 3. State
all of the following in the protocol section itself, because every one of
them is a thing a persona would otherwise get wrong:
- A bundle is **never committed**, never appears in `git status` or
  `git diff`, and is **not part of the reviewed diff** — it is not itself
  subject to code review the way a test file is.
- Consequently the reviewer establishes bundle presence and contents by
  **looking at the filesystem** (`ls microworlds/<unit-slug>/`, reading its
  files), **never** by looking at the diff. A clean `git status` is not
  evidence that no bundle was produced, and a missing bundle is not visible
  as a deletion.
- A bundle is expected to be **absent** in a fresh clone and in CI. Nothing
  outside the current working tree may depend on one existing; no test, hook,
  or gate may fail because a bundle is missing (Step 3's hook already exits 0
  in that case).
- The one exception is the escalation packet (Step 4), which is copied to a
  durable untracked location precisely because the working copy is not
  durable enough for a human to come back to.

Roles:
- `lead-programmer` **produces** the bundle for each unit it implements, as
  part of the unit, not afterwards — as a working-tree artifact, not as part
  of the commit.
- `reviewer` **executes** `run.sh` as part of review, and locates the bundle
  on the filesystem rather than in the diff.
- **Authority rule:** a microworld result is *advisory* unless the spec
  step's acceptance criteria explicitly names the bundle's `run.sh` as a
  criterion, in which case it is authoritative like any other
  machine-checkable criterion. This keeps the existing machine-checkable-
  criteria rule intact and prevents R4 from turning TDD red phases into
  spurious FAILs.

**Affected files**
- `templates/persona-protocol.md` (new `## ` section)
- `adapters/cursor/rules/persona-protocol.mdc` (condensed hand-port)
- `adapters/codex/agents-md-fragment.md` (condensed hand-port)
- `tests/adapter-protocol-parity.test.js` (`codexMap` + `cursorMap` entries
  for the new header — `{probe}` for both)
- `agents/lead-programmer.md` (produce-the-bundle instruction)
- `agents/reviewer.md` (execute-the-bundle instruction + the authority rule)
- `.claude/agents/{orchestrator,lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  (regenerated by `bin/cli.js --update`, G2 — six full-protocol personas;
  the slim tier `explorer`/`researcher`/`scribe` is untouched)
- `.claude/persona-config.json` (`fileHashes` for the above, written by
  `--update`)

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0.
- `bash tests/validate.sh` exits 0.
- `grep -c 'Microworlds' adapters/cursor/rules/persona-protocol.mdc` ≥ 1 and
  the same for `adapters/codex/agents-md-fragment.md` (proves the ports were
  actually written, not just mapped).
- `grep -q 'Microworlds' .claude/agents/reviewer.md` **and**
  `grep -q 'Microworlds' .claude/agents/lead-programmer.md` exit 0, while
  `grep -q 'Microworlds' .claude/agents/explorer.md` exits **non-zero**
  (proves the full/slim tier split held).
- **Storage assertions** (these exist so the gitignore decision cannot be
  silently dropped in the prose — use these exact sentinel phrases):
  - `grep -q 'not part of the reviewed diff' templates/persona-protocol.md`
    exits 0, and the same grep against `.claude/agents/reviewer.md` exits 0
    (proves the diff-vs-filesystem rule propagated to the persona that acts
    on it).
  - `grep -q 'gitignored' templates/persona-protocol.md` exits 0.
  - `grep -q 'dirname' templates/persona-protocol.md` exits 0 (proves the
    `run.sh` relocatability idiom was written down, not just described).

### Step 3 — Reactive rerun hook (`microworld-rerun.sh`)

The "reacts on the fly" half. A new `PostToolUse(Edit|Write)` hook,
modelled on `hooks/scripts/lint-on-edit.sh`.

Logic, in order:
1. No `microworlds/` directory in the project → exit 0 silently (R8, P4).
2. Extract `tool_input.file_path`; normalise it against
   `CLAUDE_PROJECT_DIR` to a project-relative path. Empty or nonexistent →
   exit 0.
3. For each `microworlds/*/manifest.json`, match the edited path against
   that manifest's `watch` globs. No match → skip that bundle. **No bundle
   matches → exit 0 silently.** This is what keeps the per-edit cost at
   roughly one `jq` pass for unrelated edits.
4. For each matching bundle, run `run.sh` under `timeout
   <timeoutSeconds>` (default 60). Pass the file path as a positional
   parameter, never string-interpolated into `eval` — the same injection
   guard `lint-on-edit.sh` and `graph-update.sh` already document.
5. Append one line per run to `.claude/microworld-audit.log` (sibling of
   `review-audit.log` / `wip-audit.log`, same ISO-8601-prefixed format):
   `<ts> unit=<slug> result=pass|fail|timeout file=<path>`.
6. If any matching bundle failed or timed out, exit **2** with a terse
   stderr report naming the unit(s) and the audit-log path. On
   `PostToolUse`, exit 2 surfaces stderr to the model as feedback — the
   edit has already happened, so this reports, it does not block. Any other
   failure (missing `run.sh`, malformed `manifest.json`, absent `jq`) is
   logged and exits 0: **fail open**, because this hook is a reporter, not a
   gate (R4).

**Affected files**
- `hooks/scripts/microworld-rerun.sh` (new)
- `adapters/cursor/hooks/scripts/microworld-rerun.sh` (hand-adapted port)
- `adapters/codex/hooks/scripts/microworld-rerun.sh` (hand-adapted port)
- `hooks/hooks.json` (register on the existing `PostToolUse` `Edit|Write`
  matcher, appended after `graph-update.sh` and `lint-on-edit.sh`)
- the cursor and codex hook-registration manifests (whatever each adapter's
  equivalent of `hooks.json` is — locate before editing)
- `tests/microworld-rerun.test.sh` (new; fixture-driven, canned hook-input
  JSON piped to the script, modelled on `tests/stop-gate-blocked.test.sh`)
- `tests/validate.sh` (add the new test to whatever loop invokes the
  existing `.test.sh` files, and confirm the new script passes the bash
  syntax check)
- `tests/cli-backfill.test.js` (a new case for the `runUpdate` `.gitignore`
  append — see acceptance criteria; Step 6 adds its own separate cases to
  this same file)
- `.gitignore` (this repo's own — add `microworlds/`,
  `.claude/human-review/`, and `.claude/microworld-audit.log`, matching the
  existing `.claude/review-audit.log` / `.claude/wip-audit.log` entries)
- `bin/cli.js` — **three** `appendUnique` `.gitignore` lists, not one, each
  with its own adapter prefix:
  - `:1688` (claude) → `microworlds/`, `.claude/human-review/`,
    `.claude/microworld-audit.log`
  - `:1053` (cursor) → `microworlds/`, `.cursor/human-review/`,
    `.cursor/microworld-audit.log`
  - `:1427` (codex) → `microworlds/`, `.codex/human-review/`,
    `.codex/microworld-audit.log`

  `microworlds/` is project-root and therefore identical in all three; only
  the two dotted paths vary. Getting one list and not the others ships the
  gitignore decision to some adapters and not others.
- `bin/cli.js` — **`runUpdate` (`:534`) gains an idempotent `appendUnique`
  call** for the same claude-side lines (R9). Without it, no already-adapted
  project ever receives them, and `microworlds/` shows up as untracked noise
  that a maintainer will plausibly commit — silently reinstating the
  "committed bundles" outcome the user overrode. Site it alongside the
  existing migration calls (`migrateGlobalProtocolImport`,
  `removeStaleProtocolCopy`), which establish the precedent that `--update`
  may perform additive mechanical fixups; it must not touch any other
  `.gitignore` content, and re-running `--update` must be a no-op.
- `templates/persona-config.schema.json` — **no new field**; the bundle's
  own `manifest.json` carries the timeout, so no config surface is added.

**Acceptance criteria**
- `bash tests/microworld-rerun.test.sh` exits 0, with cases asserting:
  (a) no `microworlds/` dir → exit 0, no audit log written;
  (b) an edit matching **no** manifest `watch` glob → exit 0, no audit line;
  (c) an edit matching a bundle whose `run.sh` exits 0 → exit 0 and a
      `result=pass` audit line;
  (d) an edit matching a bundle whose `run.sh` exits 1 → exit **2**, stderr
      names the unit, and a `result=fail` audit line;
  (e) a bundle with a malformed `manifest.json` → exit **0** (fail open) and
      a logged line, proving it is a reporter and not a gate;
  (f) **relocation** — the *same* fixture bundle copied to a second path
      outside `microworlds/` (mimicking the Step 4 escalation packet) and
      invoked directly as `bash <copied-path>/run.sh` from the project root
      exits with the *same* status as the original. This is the executable
      proof of Step 2's relocatability requirement; without it the packet is
      an assumption rather than a verified mechanism.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `hooks/scripts/microworld-rerun.sh` and for both adapter mirrors.
- `python3 -c "import json;json.load(open('hooks/hooks.json'))"` exits 0 and
  `grep -c microworld-rerun hooks/hooks.json` is 1.
- **`.gitignore` coverage (R9):**
  - `git check-ignore -q microworlds/x/run.sh` exits 0 in this repo (proves
    the ignore rule is live here, not just written into the scaffold).
  - `grep -c '^microworlds/$' .gitignore` is 1 and
    `grep -c 'human-review' .gitignore` is 1.
  - `grep -c "'microworlds/'" bin/cli.js` is **4** — three scaffold lists
    plus the `runUpdate` call. A value of 3 means `runUpdate` was skipped and
    already-adapted projects will never receive the rule.
  - `node tests/cli-backfill.test.js` exits 0, including a case that runs
    `--update` against a fixture project whose `.gitignore` lacks
    `microworlds/`, asserts the line is present afterwards, asserts no other
    pre-existing `.gitignore` line was modified or reordered, and asserts a
    second `--update` leaves the file byte-identical (idempotence).

### Step 4 — Fourth verdict `ESCALATE-TO-HUMAN` (protocol + reviewer)

Add a canonical section
`## Fourth verdict: escalate-to-human` to `templates/persona-protocol.md`,
sited immediately after the existing `## Third verdict: insufficient-context`
section, plus condensed hand-ports and parity-map entries (R3).

Content:

**Verdict precedence** (explicit, because a fourth verdict makes ordering
ambiguous): `FAIL` > `INSUFFICIENT-CONTEXT` > `ESCALATE-TO-HUMAN` > `PASS`.
Escalation is a **gate on PASS**, never a replacement for FAIL — if the
reviewer found a real defect, that is a normal FAIL and no human is needed;
if it could not verify a criterion, that is INSUFFICIENT-CONTEXT. Only a
unit the reviewer *would have passed* escalates.

**Trigger.** Escalate when `humanReviewMode` (Step 6) is `all`, or is
`critical`/absent **and** the unit meets the existing heavy-unit trigger
already defined in this protocol's "Reviewer roast-work advisory pass
trigger" section — ≥ ~8 impacted files OR ≥ ~400 changed lines;
structural/cross-cutting change; or security-sensitive surface. **Reuse that
section by reference; do not restate or re-derive the criteria**, so a
future amendment to the trigger cannot leave two copies disagreeing.

**Marker.** `.claude/reviewed/<task-id>.escalated`, written by the reviewer
via Bash — the same named bookkeeping exception as `.pass`/`.fail`/`.blocked`,
not a change to the code under review. First line exactly:

```
ESCALATE-TO-HUMAN <task-id> <UTC ISO-8601 timestamp> trigger: <which heavy-trigger criterion> microworld: <packet path or "none">
```

`microworld:` names the **durable packet directory** (below), not the
working `microworlds/<unit-slug>/` path — the working copy is gitignored
scratch and may be gone by the time a human reads this.

Followed by, in order: the exact command to run the microworld (a
project-root-relative invocation of the packet's `run.sh`); the commit SHA
at escalation time, as `commit: <sha>`, so a human arriving later can tell
what the bundle was run against; a one-line description of the inputs and the
expected outputs; the reviewer's own would-be verdict and the criteria it
checked; and its non-blocking notes. This is the packet body the human reads
and acts on.

**Durable escalation packet** (this is the half that makes gitignored
bundles survivable — read Context, "Bundle storage", before implementing).
In the **same** action that writes the marker, the reviewer snapshots the
unit's bundle to `.claude/human-review/<task-id>/`:

- Copy `microworlds/<unit-slug>/` wholesale — `run.sh`, `manifest.json`,
  `inputs/`, `expected/`, `README.md` — preserving the executable bit on
  `run.sh`. Step 2's relocatability requirement is what makes the copy
  runnable at the new path; Step 3 case (f) is what proves it.
- Write `PACKET.md` into that directory: a **byte-identical verbatim copy**
  of the marker body, not a re-summary. The **marker remains authoritative**
  wherever the two differ (R11). `PACKET.md` exists so the packet directory
  is self-contained for a human working outside the session.
- If the unit has **no** bundle, write `microworld: none` in the marker,
  create the packet directory anyway, and put `PACKET.md` in it alone. A
  human still gets the reviewer's would-be verdict and criteria; they simply
  have nothing to run. Escalation is never skipped for want of a bundle.
- **The packet deliberately does not live under `.claude/reviewed/`.**
  `reviewed-path-gate.sh:29` blocks every Bash command whose text contains
  that substring for every non-reviewer caller, read-only ones included, so
  a packet sited there could not be run by the orchestrator or by a human
  working through the session. `.claude/human-review/` is ungated by design.
  Say this in the protocol text so a future reader does not "tidy" the
  packet under the marker directory and quietly break ask #3.
- Lifecycle: the packet is deleted by the reviewer at the same moment it
  deletes `.escalated`, in each of Step 7's three terminal transitions. It is
  untracked, so a `git clean -fdx` or a fresh clone destroys it along with
  the marker, unrecoverably (R10) — documented, not fixed.

**Distinctness from `.blocked`** (required, per user): `.blocked` means the
reviewer *lacked context* to verify; `.escalated` means policy requires
*human eyes on critical code*. They stay separate marker files and separate
`review-audit.log` tokens (Step 5), so an auditor can tell the two apart
after the fact.

**Cap accounting.** `.escalated` **never** consumes a 2-FAIL-cap slot — the
cap counts `.fail` records only, unchanged.

**Resolution.** The marker is always resolved by the reviewer, on a later
re-dispatch carrying the human's decision, into exactly one of three
terminal transitions (Step 7), each of which **deletes** `.escalated` as
part of writing its successor — mirroring the existing rule that a `.blocked`
marker is deleted when the reviewer resolves the unit.

Reviewer-persona changes: a new "On ESCALATE-TO-HUMAN (both modes)" bullet
mirroring the existing INSUFFICIENT-CONTEXT bullet, and the verdict bullet's
verdict list extended from three to four.

Also amend `templates/protocol-digest.md`'s **existing** "Review ownership"
bullet in place — `"Done" means the reviewer returned PASS, not "looks
finished."` gains `…and on a critical unit PASS may first route through
ESCALATE-TO-HUMAN.` **Do not add a new bullet**; the digest's own header caps
it at ~15 lines.

**Affected files**
- `templates/persona-protocol.md`
- `templates/protocol-digest.md` (one existing bullet amended in place)
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents-md-fragment.md`
- `tests/adapter-protocol-parity.test.js` (`codexMap` + `cursorMap` entries)
- `agents/reviewer.md`
- `.claude/agents/{orchestrator,lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  and `.claude/protocol-digest.md` (regenerated by `bin/cli.js --update`, G2)
- `.claude/persona-config.json` (`fileHashes`, written by `--update`)

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0.
- `bash tests/validate.sh` exits 0.
- `grep -q 'ESCALATE-TO-HUMAN' .claude/agents/reviewer.md` exits 0.
- `grep -c 'ESCALATE-TO-HUMAN' adapters/cursor/rules/persona-protocol.mdc`
  ≥ 1 and the same for `adapters/codex/agents-md-fragment.md`.
- `awk 'END{print NR}' templates/protocol-digest.md` returns a value no
  greater than its pre-change line count + 1 (proves the digest was amended
  in place, not grown).
- `grep -c '≥ ~8 impacted files' templates/persona-protocol.md` is 1 (proves
  the heavy trigger was referenced, not duplicated — the terminology-
  consistency defect ask #1 exists to catch).
- **Packet assertions:**
  - `grep -q '.claude/human-review/' templates/persona-protocol.md` exits 0
    and the same grep against `.claude/agents/reviewer.md` exits 0 (proves
    the packet path reached the persona that has to create it).
  - `grep -q 'PACKET.md' templates/persona-protocol.md` exits 0.
  - `grep -q 'commit:' templates/persona-protocol.md` exits 0 (the SHA line
    R10 relies on).
  - `grep -q 'human-review' .gitignore` exits 0 — i.e. Step 3 landed first;
    if this fails, the packet directory is about to be committed.

**Runtime-state note:** the packet directory is created at review time, not
checked in, so it adds **no** new file to this repo's tree and no new entry
to the affected-files list above beyond the `.gitignore` line Step 3 already
owns.

### Step 5 — `stop-gate.sh` `.escalated` branch + adapter mirrors

Extend the reviewer-`SubagentStop` branch at `hooks/scripts/stop-gate.sh:90-102`.
It currently globs `*.blocked`; it gains a parallel `*.escalated` glob with
identical flag-keeping semantics and a **distinct audit token**:

- `*.blocked` present → log `verdict=blocked flags-kept`, keep flags, exit 0
  (unchanged).
- `*.escalated` present → log `verdict=escalated flags-kept`, keep flags,
  exit 0.
- Both present → log both tokens (or a combined line naming both), keep
  flags. Never let one mask the other in the log.
- Neither → clear flags, log `cleared-by=reviewer`, exit 0 (unchanged).

`.directed` (Step 7) gets **no** branch — deliberately. Its absence from the
glob is what allows the flags to clear so the human-directed fix can be
dispatched. Say so in the script's header comment so a future reader does
not "fix" the omission.

`reviewer-route-gate.sh` needs **no** change: it keys off `.pending-review.*`
only, so kept flags automatically block the next gated dispatch. Assert this
in the test rather than assuming it, exactly as
`tests/stop-gate-blocked.test.sh` case (c) does for `.blocked`.

**Affected files**
- `hooks/scripts/stop-gate.sh` (branch + header-comment logic list, which
  documents steps 0/0.5/0.75/1/2/2.5/3/4 and must stay accurate)
- `adapters/cursor/hooks/scripts/stop-gate.sh` (hand-adapted port, in that
  port's own condensed style — these are **not** byte-identical mirrors)
- `adapters/codex/hooks/scripts/stop-gate.sh` (same)
- `tests/stop-gate-escalated.test.sh` (new, modelled on
  `tests/stop-gate-blocked.test.sh`)
- `tests/validate.sh` (register the new test)

**Acceptance criteria**
- `bash tests/stop-gate-escalated.test.sh` exits 0, with cases asserting:
  (a) reviewer `SubagentStop` with an active `.escalated` marker → exit 0,
      `.pending-review.*` flag still present, and `verdict=escalated
      flags-kept` in `.claude/review-audit.log`;
  (b) with **both** `.blocked` and `.escalated` present → both tokens appear
      in the audit log (proves they stay distinguishable, per user);
  (c) with **no** markers → flag cleared and `cleared-by=reviewer` logged
      (existing behaviour preserved);
  (d) with an `.escalated` marker standing, `reviewer-route-gate.sh` fed an
      orchestrator→lead-programmer dispatch exits **2**;
  (e) with only a `.directed` marker present → flags **cleared** and
      `cleared-by=reviewer` logged, proving the no-cap-slot fix route is not
      blocked.
- `bash tests/stop-gate-blocked.test.sh` still exits 0 (no regression).
- `bash tests/validate.sh` exits 0.

### Step 6 — `humanReviewMode` config field, defaulting to `critical`

Add the config surface. **Read R1 before implementing.**

- `templates/persona-config.schema.json` gains:
  `"humanReviewMode": { "type": "string", "enum": ["off","critical","all"],
  "default": "critical", "description": "…" }`. The description must state
  plainly that the shipped default is `critical` (on), that an absent key
  resolves to `critical`, and that `off` is the explicit opt-out.
- `bin/cli.js`'s fresh-install skeleton (`bin/cli.js:1713-1723`) gains
  `humanReviewMode: 'critical'`.
- **The load-bearing half:** the *consumers* must treat an absent key as
  `critical`, so already-adapted projects — whose configs `--update`
  preserves untouched — get the behaviour on their next plugin update. Two
  consumers: the reviewer persona (which reads the config to decide whether
  to escalate) and any hook-side read. Unrecognised values also resolve to
  `critical` (fail toward escalation, never toward silent auto-approval).
- **Degradation:** if `reviewer` is not in `personaSelection`, the whole
  escalation path is inert — no marker, no block. The reviewer is the only
  thing that writes `.escalated`, so this is structural, but state it
  explicitly (P4, G3).
- CHANGELOG entry for this step must lead with the behaviour change, in
  plain words: *the default is on; critical units will now block turn-end
  until a human decides; set `humanReviewMode: "off"` to restore the
  previous behaviour.* Do not bury it under "Added".

**Affected files**
- `templates/persona-config.schema.json`
- `bin/cli.js` (fresh-install skeleton only — **do not** add a backfill into
  the `existingPersonaConfig` branch at `bin/cli.js:1700-1711`; that branch
  deliberately preserves judgment-driven fields, and the consumer fallback
  is what carries the default instead)
- `agents/reviewer.md` (read the config; absent/unrecognised → `critical`)
- `.claude/agents/reviewer.md` (regenerated, G2)
- `.claude/persona-config.json` (`fileHashes`; **also** add an explicit
  `"humanReviewMode": "critical"` here so this repo dogfoods it)
- `tests/cli-backfill.test.js` (assert the fresh-install skeleton contains
  the field with value `critical`, and that an existing config **without**
  the field is left without it after `--update` — i.e. the preserve-fields
  contract still holds)
- `README.md` (document the field, its three values, and the on-by-default
  posture with its rationale)

**Acceptance criteria**
- `node tests/cli-backfill.test.js` exits 0, including a new case asserting
  a fresh-install `persona-config.json` contains
  `"humanReviewMode": "critical"`.
- `python3 -c "import json,sys; s=json.load(open('templates/persona-config.schema.json')); p=s['properties']['humanReviewMode']; sys.exit(0 if p['default']=='critical' and set(p['enum'])=={'off','critical','all'} else 1)"`
  exits 0.
- `grep -q 'humanReviewMode' agents/reviewer.md` exits 0 and the surrounding
  text states the absent-key fallback is `critical`
  (`grep -A3 humanReviewMode agents/reviewer.md | grep -qi 'absent'`).
- `bash tests/validate.sh` exits 0.
- Negative check for R1: a fixture config with **no** `humanReviewMode` key
  must not be treated as `off` — asserted by the reviewer-facing text check
  above plus Step 5's case (a) fixture, which carries no such key.

### Step 7 — Human-decision routing (the three routes + `.directed`)

Wire the loop that ask #3 actually describes. Add a canonical protocol
subsection under Step 4's new section (same `## ` header — **no new
top-level section**, so no additional parity-map entry is needed beyond
Step 4's; verify this by re-running the parity test) and the corresponding
orchestrator/reviewer instructions.

Flow:
1. Reviewer escalates; `.escalated` written **and** the durable packet
   snapshotted to `.claude/human-review/<task-id>/` (Step 4); flags kept
   (Step 5); turn-end blocked; orchestrator surfaces the marker's contents to
   the **human**, verbatim, including the exact microworld run command and
   the packet path.
2. Human runs the microworld — **from the packet, not from
   `microworlds/<unit-slug>/`** — and returns exactly one decision. Because
   the packet is untracked-but-persistent rather than session state, this
   step may happen in a **later session**, after a restart, or in the
   human's own terminal outside the session entirely; the orchestrator
   re-reads the marker with the Read tool (ungated) to re-surface the packet
   whenever the human comes back. Nothing about this flow assumes the human
   is available the moment escalation fires.

   The orchestrator must **not** run `run.sh` and pre-digest the result for
   the human — that would restore the automation the escalation exists to
   interrupt. It surfaces the command; the human runs it.
3. Orchestrator re-dispatches the **reviewer** with the human's decision
   relayed **verbatim**, because `reviewed-path-gate.sh` blocks anyone else
   from writing `.claude/reviewed/`. The reviewer's job on this dispatch is
   **transcription, not re-review** (R6) — it does not re-derive the verdict
   and does not override the human.

Routes:

| Human decision | Reviewer writes | `.escalated` | Packet | Cap slot | Next move |
|---|---|---|---|---|---|
| **Approve** | `.pass`, with an appended `human: approved by <name> <UTC ISO-8601>` attestation line after the required first line | deleted | deleted | — | unit done |
| **Reject with reason** | `.fail`, with the human's reason verbatim as the defect list | deleted | deleted | **consumes one** | back to `lead-programmer`, normal FAIL route |
| **Fixable a specific way** | `.directed`, first line exactly `DIRECTED <task-id> <UTC ISO-8601 timestamp> fix: <one-line human directive>`, followed by the human's full prescribed fix verbatim | deleted | deleted | **does not consume one** | dispatch `lead-programmer` with the directive, then re-review |

The packet (`.claude/human-review/<task-id>/`) is deleted in the **same**
reviewer action that deletes `.escalated`, in all three routes — it is
evidence for a pending decision, and the decision is no longer pending. A
re-escalation of the same unit later writes a fresh packet from the
then-current bundle. Leaving a stale packet behind is the packet-side
equivalent of R5's stale-marker hazard, but without R5's excuse: unlike the
marker, nothing globs the packet directory, so a stale one is silent clutter
that a human could mistake for a live escalation. Deleting it is therefore
mandatory, not tidiness.

Rationale for the cap asymmetry (per user): *reject-with-reason* is a
genuine defect the human found, so it counts like any other FAIL.
*Fixable-a-specific-way* is a **human-directed correction**, not
`lead-programmer` failing on its own automated attempt — the same logic that
keeps `INSUFFICIENT-CONTEXT` from consuming a slot. The cap's counting rule
is unchanged and needs no edit: it counts `.fail` records only, and
`.directed` is not one.

`.directed` intentionally gets **no** `stop-gate.sh` branch (Step 5), so
flags clear normally and the directed fix can actually be dispatched. It is
deleted by the reviewer when it next resolves the unit to PASS or FAIL, same
rule as `.blocked` and `.escalated`.

**Unattended / CI fallback** (per user): if no human is present, the
`.escalated` marker simply stands and turn-end stays blocked. There is **no**
silent auto-fallback to the reviewer's own automated verdict. The only way
through is the existing `defer: <reason>` / `skip: <reason>` escape hatch on
the pending-review flag — already-live machinery that logs to
`.claude/review-audit.log`, so bypassing human review always leaves a trail.
Note in the protocol text that `skip:` abandons the unit without deleting
the marker (R5) **or the packet** — both are left standing, which is the
fail-safe direction (evidence retained, nothing silently approved), but it
means a `skip:`-ed unit leaves a `.claude/human-review/<task-id>/` directory
that only a later reviewer resolution of that unit will clear.

Note also that "no human is present" is now a *timing* condition rather than
a terminal one: the packet outlives the session, so an unattended run that
blocks at escalation can be picked up by a human hours or days later without
re-running anything. That is the whole point of the packet, and it is why
this plan did not take the cheaper "human review is same-session only" route
(Context, "Bundle storage").

**Affected files**
- `templates/persona-protocol.md` (subsection under Step 4's `## ` header)
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents-md-fragment.md`
- `agents/reviewer.md` (the three transitions; transcription-not-re-review)
- `agents/orchestrator.md` (surface the marker to the human; relay the
  decision verbatim to the reviewer; the `.directed` → `lead-programmer`
  dispatch; **`(if present)` phrasing throughout**, G3)
- `agents/lead-programmer.md` (a `.directed` dispatch carries a human's
  prescribed fix — apply exactly that, do not re-plan around it)
- `agents/task-master.md` (cap accounting: `.directed` is not a FAIL)
- `.claude/agents/{orchestrator,lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  (regenerated, G2)
- `.claude/persona-config.json` (`fileHashes`)

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0 (confirming no new
  top-level section was introduced — if one was, the test throws and the
  step must add the parity-map entries).
- `bash tests/validate.sh` exits 0, including its optional-persona
  conditional-phrasing check over the new orchestrator prose.
- `grep -q 'DIRECTED' agents/reviewer.md` exits 0.
- `grep -q 'does not consume' agents/task-master.md` exits 0 (or an
  equivalent grep proving the cap rule reached task-master).
- `grep -q 'defer:' templates/persona-protocol.md` still exits 0 and the new
  text references the existing escape hatch rather than defining a new one.
- Step 5's case (e) (`.directed` → flags cleared) still passes.
- `grep -q 'human-review' agents/orchestrator.md` exits 0 (proves the packet
  path reached the persona that surfaces it to the human).
- `grep -c 'human-review' templates/persona-protocol.md` is ≥ 2 — Step 4's
  creation rule and this step's deletion rule — proving the packet has a
  stated lifecycle on both ends rather than only being created.

### Step 8 — Documentation, glossary, and known limitations

- `README.md`: document all three capabilities; the `humanReviewMode`
  values and its **on-by-default** posture with the rationale from this
  spec's Context section, stated plainly; the microworld bundle layout **and
  its gitignored-scratch storage** (including that a bundle is expected to be
  absent in a fresh clone and is never part of a reviewed diff); and, under
  "Known limitations", (a) R5's stale-marker-after-`skip:` hazard, noted as
  shared with the existing `.blocked` marker, (b) the `package.json`
  `files`-array skill-shipping gap as a **recorded decision** ("skills reach
  users via the git/marketplace path, not npm"), not a bug, and (c) **R10 —
  escalation packets are untracked**: `.claude/human-review/<task-id>/`
  survives sessions but not `git clean -fdx`, a fresh clone, or a discarded
  worktree; losing it loses the pending escalation and its evidence together,
  with no automatic recovery, and the unit must be re-reviewed and
  re-escalated. State this as an accepted consequence of keeping review
  scratch out of project history, not as a defect.
- `CONTEXT.md` (owned by `scribe`): add glossary entries for **Microworld**,
  **escalation packet**, **ESCALATE-TO-HUMAN**, **`.escalated` marker**,
  **`.directed` marker**, and **`humanReviewMode`** — each contrasting the
  new term with its nearest neighbour (`.escalated` vs `.blocked` above all;
  and **microworld bundle vs escalation packet** — the working, gitignored,
  per-unit original versus the durable per-escalation snapshot of it, which
  is precisely the kind of near-synonym pair ask #1's skill exists to catch).
  Dogfooding ask #1: the glossary the new skill reads must actually describe
  the terms this spec introduces.
- `docs/adr/`: **two** ADRs.
  1. The on-by-default decision — alternatives considered (off-by-default
     opt-in), why on-by-default was chosen (counteracting hyperscaling
     slop), and the accepted cost (a real behaviour change for every
     already-adapted project on update).
  2. The bundle-storage decision — that bundles are gitignored scratch
     rather than committed (the user's override of this plan's original
     recommendation), the survivability gap that created for ask #3, the two
     candidate resolutions (same-session-only human review vs a durable
     escalation packet), why the packet was chosen, and the accepted cost
     (R10). This is a decision a future maintainer is likely to try to
     reverse in either direction, so the reasoning needs a record that
     outlives this plan document.

**Affected files**
- `README.md`
- `CONTEXT.md`
- `docs/adr/<next-number>-human-in-the-loop-review-on-by-default.md` (new)
- `docs/adr/<next-number+1>-microworld-bundles-gitignored.md` (new)

**Acceptance criteria**
- `bash tests/validate.sh` exits 0.
- `grep -q 'Microworld' CONTEXT.md`, `grep -q 'ESCALATE-TO-HUMAN' CONTEXT.md`,
  and `grep -q 'escalation packet' CONTEXT.md` all exit 0.
- `grep -q 'humanReviewMode' README.md` exits 0 and the surrounding
  paragraph contains the string `default` and one of `on by default` /
  `on-by-default`.
- `ls docs/adr/*human-in-the-loop* | wc -l` returns 1.
- `ls docs/adr/*gitignored* | wc -l` returns 1.
- `grep -q 'human-review' README.md` exits 0 and appears under the "Known
  limitations" heading (`awk` from that heading to the next `##` and grep
  within it), proving R10 was documented as a limitation rather than only
  mentioned in passing.
- Cross-check for ask #1's own dogfooding: running the reviewer's new
  `ubiquitous-language` skill against this spec's own diffs reports no
  undefined load-bearing term — verified manually at review time; recorded
  as a note, not a gate.

## Open Questions

**Status as of 2026-07-28 (second pass): three of the original four are
resolved.** The user answered Open Questions 2, 3, and 4; their resolutions
are folded into the steps above and logged in Clarifications, and they are
recorded below as **RESOLVED** rather than deleted, so the reasoning behind
each remains legible to `task-master` and to a later reader.

Open Question 1 remains genuinely open. Like the original four, it carries a
recommended default that is **already applied** in the steps above, so it
does **not** block `task-master`; an answer would change the named mechanism
only, not the overall route.

1. **OPEN — Is `.claude/reviewed/<task-id>.directed` the right mechanism for
   the no-cap-slot fix route?** (Originating check: CHK4.)
   - **(a) Recommended — a distinct `.directed` marker**, as specified in
     Step 7. It is the minimal durable record: the 2-FAIL cap counts `.fail`
     records only, so a route with no marker is invisible to a fresh
     `spec-master`/orchestrator spawn — exactly the gap `.fail` records exist
     to close. Costs one filename and zero hook branches.
   - (b) No marker at all — delete `.escalated` and dispatch. Cheapest, but
     the human's directive leaves no trace in `.claude/reviewed/`.
   - (c) Reuse `.escalated` with a rewritten first line. Rejected: `stop-gate.sh`
     globs by filename, so the marker would keep flags standing and block the
     very dispatch the route exists to enable — it would need first-line
     parsing in three hand-adapted scripts.

2. **RESOLVED 2026-07-28 — Should a failing microworld surface via hook
   exit 2, or only via the audit log?** (Originating check: CHK6.)
   **Answer: (a), exit 2 plus an audit line** — the recommended default,
   confirmed by the user. No change to Step 3, whose case (d) already
   asserts exit 2 and a `result=fail` audit line.
   - **(a) CHOSEN — exit 2 plus an audit line**, as specified in Step 3.
     On `PostToolUse`, exit 2 surfaces stderr to the model as feedback
     without blocking (the edit already happened), which is what "shows
     breakage on the fly" requires.
   - (b) Rejected — audit log only (exit 0 always, mirroring
     `lint-on-edit.sh`'s silence). Quieter during TDD red phases, but
     nothing ever *reacts* — which forfeits ask #2's entire point.

3. **RESOLVED 2026-07-28 — Are `microworlds/` bundles committed to the repo,
   or gitignored?** (Originating check: CHK7.)
   **Answer: (b), gitignored** — the user **overrode** this plan's
   recommended default of "committed". This is the one place in this spec
   where the user chose against the recommendation, and the reasoning that
   recommendation rested on (bundles surviving session and process
   boundaries for free) was correct, so the gap it opened had to be closed
   explicitly rather than absorbed. Resolution: bundles are working-tree
   scratch, and the reviewer snapshots the escalated unit's bundle to a
   durable `.claude/human-review/<task-id>/` packet. Full reasoning in
   Context, "Bundle storage"; consequences threaded through Steps 2, 3, 4,
   7, 8; residual cost recorded as R10.
   - (a) Rejected — committed, like tests. Would have made bundles part of
     the reviewed diff and durable across clones, at the cost of carrying
     per-unit review scratch in project history permanently.
   - **(b) CHOSEN — gitignored as scratch.** Cheaper diffs and no scratch in
     history. The "human-run-it-live property breaks the moment the session
     ends" objection raised when this option was drafted is real and is what
     the escalation packet exists to answer; it is **not** left standing.

4. **RESOLVED 2026-07-28 — Does this repo dogfood microworlds on its own
   units in this spec, or only ship the capability?** (Originating check:
   CHK8.)
   **Answer: (a), ship only** — the recommended default, confirmed by the
   user. No change to the steps. Note this answer is reinforced, not merely
   unaffected, by Open Question 3's resolution: authoring bundles for this
   repo's own units would now produce gitignored artifacts that no commit,
   clone, or CI run would ever see, so dogfooding them would demonstrate the
   format to nobody.
   - **(a) CHOSEN — ship only**, as specified. Steps 3 and 5 already
     produce fixture-driven `.test.sh` files that serve the same purpose for
     this repo's own units, and adding bundles for them would duplicate
     coverage.
   - (b) Rejected — also author `microworlds/` bundles for Steps 3 and 5.
     Better dogfooding of the format; meaningfully larger diff; and, post-
     Open-Question-3, uncommittable.

## Self-check

- CHK1: Does the plan define how the shipped `humanReviewMode` default
  reaches a project already adapted at an older version, given `--update`
  preserves existing config fields? — PASS (Context "`--update` preserves
  judgment-driven config fields"; R1; Step 6's consumer-fallback
  requirement and its negative check).
- CHK2: Do Steps 4, 5, and 7 agree on which marker files keep the
  pending-review flags standing? — FAIL (conflicting) — revised in place.
  An earlier draft had `.directed` inheriting `.escalated`'s flag-keeping
  behaviour, which would have blocked the very `lead-programmer` dispatch
  that route exists to enable. Step 5 now states the omission is deliberate
  and asserts it with case (e); Step 7's table matches.
- CHK3: Is the precedence between the four verdicts defined for a unit that
  is both critical and defective? — FAIL (missing) — revised in place.
  Step 4 now states `FAIL > INSUFFICIENT-CONTEXT > ESCALATE-TO-HUMAN > PASS`
  and that escalation gates PASS rather than replacing FAIL.
- CHK4: Is the durable record for the "fixable a specific way" route
  defined, and is its cap-slot accounting stated? — FAIL (missing) —
  converted to Open Question 1 (default `.directed` applied in Step 7; the
  cap rule is stated in Step 7's table and rationale).
- CHK5: Is "critical" defined by exactly one source of truth? — PASS
  (Step 4 requires referencing the existing heavy-unit trigger by name, and
  its acceptance criterion greps for exactly one occurrence of the
  threshold string in `templates/persona-protocol.md`).
- CHK6: Is the channel by which a failing microworld surfaces to the agent
  specified, with a machine-checkable criterion? — **PASS** (was FAIL
  (ambiguous) → Open Question 2 → answered by the user 2026-07-28, confirming
  the applied default; Step 3's case (d) asserts exit 2 plus a `result=fail`
  audit line).
- CHK7: Does the plan say whether `microworlds/` bundles are version-
  controlled? — **PASS** (was FAIL (missing) → Open Question 3 → answered by
  the user 2026-07-28 **against** the applied default: gitignored, not
  committed. Re-checked on the new answer rather than assumed closed by it —
  which is what surfaced CHK19–CHK22 below).
- CHK8: Does the plan state whether this repo authors its own microworld
  bundles as part of these steps? — **PASS** (was FAIL (missing) → Open
  Question 4 → answered by the user 2026-07-28, confirming the applied
  default "ship only"; Steps 3 and 5 use `.test.sh` fixtures instead).
- CHK9: Does every step name at least one command that can be run and
  produce a pass/fail? — PASS (each step's acceptance criteria is a list of
  exit-code or `grep` assertions; no step relies on prose review, with the
  single explicitly-labelled exception of Step 8's final manual
  cross-check, which is stated as a note and not a gate).
- CHK10: Do the affected-files lists distinguish generated files from
  hand-edited ones, so no step silently violates constitution P2? — PASS
  (G2; every step listing `.claude/agents/*.md` marks it "regenerated by
  `bin/cli.js --update`", and Step 5 explicitly warns the adapter stop-gate
  mirrors are hand-adapted rather than byte-identical copies).
- CHK11: Is the constitution's P3/P5 version-bump coupling represented in
  every step's affected files? — PASS (G1, stated once with the four literal
  paths and referenced by the note above the Steps section).
- CHK12: Does the plan say what happens when the optional `reviewer` persona
  is not selected? — PASS (Step 6's degradation clause; G3; P4 line in the
  Constitution check).
- CHK13: Does the plan define what the human actually receives in order to
  make a decision? — PASS (Step 4's `.escalated` marker body: run command,
  inputs/expected-outputs description, the reviewer's would-be verdict and
  notes; plus Step 2's mandatory human-facing bundle `README.md`).
- CHK14: Do Step 1 and Step 8 agree on where domain terminology is authored
  versus consumed? — PASS (Step 1: the skill reads `CONTEXT.md` and never
  writes it, authoring stays with `scribe` + `antislop:domain-modeling`;
  Step 8: `scribe` adds the entries).
- CHK15: Is the on-by-default behaviour change stated as deliberate rather
  than softened? — PASS (Context "Why this exists"; Step 6's CHANGELOG
  instruction to lead with the behaviour change; Step 8's ADR requirement).

Second pass, 2026-07-28 — items CHK16–CHK23 were drawn by re-running the
checklist against the plan *after* folding in Open Question 3's answer
(bundles gitignored). Four of them failed, all four for the same underlying
reason: the original text assumed committed bundles and therefore never had
to say where a runnable artifact lives once the working tree moves on. All
four were revised in place; none needed to become a new Open Question.

- CHK16: Is it defined how a human reviews an escalated unit when the bundle
  is gitignored and the originating session has ended?
  — **FAIL (missing) — revised in place.**
  The plan previously relied on the committed bundle for
  this and said nothing once that premise was removed. Context "Bundle
  storage" now names the two candidate resolutions and why the durable
  escalation packet was chosen over same-session-only review; Step 4
  specifies the snapshot; Step 7 step 2 states the human may act in a later
  session.
- CHK17: Do Steps 2, 4, and 7 agree on which path a runnable artifact lives
  at, at each point in the flow? — PASS (Step 2: working bundle at
  `microworlds/<unit-slug>/`; Step 4: packet copy at
  `.claude/human-review/<task-id>/`, and the marker's `microworld:` field
  names the packet, not the working path; Step 7: the human runs the packet,
  stated explicitly).
- CHK18: Is the packet's deletion defined for every terminal route, and for
  the `skip:` escape hatch that has no terminal route? — PASS (Step 7's
  table carries a Packet column marking all three routes "deleted", plus the
  paragraph making deletion mandatory rather than tidiness; the unattended
  section states `skip:` leaves both marker and packet standing, and names
  that as the fail-safe direction).
- CHK19: Does the plan say how the new `.gitignore` entries reach a project
  adapted at an older version? — **FAIL (missing) — revised in place.** The
  first draft named a single `appendUnique` list. Verification found three
  such lists (`bin/cli.js:1688`/`:1053`/`:1427`) and that `runUpdate`
  (`:534`) calls none of them. Recorded as R9, with Step 3 extending
  `runUpdate` and asserting it via a `grep -c "'microworlds/'" bin/cli.js`
  count of 4 plus an idempotence case in `tests/cli-backfill.test.js`.
- CHK20: Is `run.sh`'s relocatability backed by a machine-checkable
  criterion rather than prose alone?
  — **FAIL (ambiguous) — revised in place.**
  Step 2 now states the `dirname` idiom as a format requirement,
  and Step 3 case (f) executes the same fixture bundle from a second path
  and asserts an identical exit status. Without case (f) the entire packet
  mechanism rested on an untested assumption.
- CHK21: Do the reviewer's instructions distinguish a filesystem check from
  a diff check for bundle presence, given a gitignored bundle never appears
  in `git status`? — **FAIL (missing) — revised in place.** Step 2's Storage
  block states the rule, and its acceptance criteria grep for the sentinel
  phrase `not part of the reviewed diff` in both
  `templates/persona-protocol.md` and `.claude/agents/reviewer.md`. Left
  unstated, a reviewer would have read a clean `git status` as "no bundle
  produced" and failed the unit for it.
- CHK22: Is `PACKET.md`'s relationship to the `.escalated` marker defined,
  so two records of one decision cannot drift?
  — **FAIL (missing) — revised in place.**
  R11 plus Step 4 now require a byte-identical verbatim copy
  written in the same action, and name the marker authoritative on any
  divergence.
- CHK23: Is the packet reachable by the persona that must run it, given
  `reviewed-path-gate.sh` blocks the `.claude/reviewed` substring for every
  non-reviewer caller including read-only commands? — PASS (Context's
  architectural fact establishes the constraint; the packet is sited at the
  ungated `.claude/human-review/`, and Step 4 requires the protocol text to
  say *why*, so the directory is not later "tidied" under the marker path).
- CHK24: Does the plan record why the user's override of a recommended
  default was accepted, rather than silently swapping the recommendation? —
  PASS (Open Question 3 marks (b) CHOSEN and states plainly that the
  rejected recommendation's reasoning was correct and that the gap it opened
  is closed by the packet rather than left standing; Step 8 requires a second
  ADR so the decision outlives this document).

## Scribe update hint

After the last step lands, `scribe` should:
- Add the six glossary entries from Step 8 to `CONTEXT.md` and confirm two
  contrasts are explicit: `.escalated` vs `.blocked`, and **microworld
  bundle vs escalation packet**.
- Write **both** ADRs under `docs/adr/`: the on-by-default decision and the
  bundle-storage decision (gitignored scratch + durable escalation packet,
  including the rejected same-session-only alternative).
- Update `.claude/wiki/architecture.md` with the marker state machine's new
  states (`.escalated`, `.directed`), the escalation packet's create/delete
  lifecycle, and the `PostToolUse` microworld-rerun hook; and
  `.claude/wiki/conventions.md` with the microworld bundle layout, its
  gitignored-scratch status, and the `run.sh` relocatability rule.
- Record in `.claude/wiki/changelog.md` that human review ships **on** at
  `critical`, with a pointer to the ADR — this is the single most likely
  thing a downstream maintainer will need to look up after an update.

## Convergence follow-ups — 2026-08-09 (design-provenance gap analysis)

**Origin.** A `spec-master` re-read of this plan against the source it took
"microworlds" from (see Context, "Design provenance"), requested 2026-08-09.
This is **append-only**: Steps 1–8 are unedited, unrenumbered, and unreopened,
and the already-published tracker issues (#122 for the spec, #129–138 for the
units) are untouched and remain valid exactly as written. Nothing here
invalidates any of them. Numbering continues at Step 9.

**Sequencing — read before dispatching.** Unlike this repo's previous
convergence rounds, these follow-ups extend work that has **not shipped yet**:
every one of them modifies a protocol section or a packet format that Steps 2,
4, and 7 create. Steps 9–11 are therefore blocked on the base units and must
not be picked up before them. They are also mutually ordered — Steps 10 and 11
both edit Step 4's `## Fourth verdict` section, and Step 11's questions are
drawn from the artifact Step 10 introduces. Order: **9 → 10 → 11**, all after
the base plan. See Open Question 5 for the alternative (folding them into
Steps 2/4/7 instead), which is *not* the recommended route.

### What is NOT a gap (stated explicitly, so no one re-litigates it)

1. **Step 2's bundle format is a deliberate narrowing, not a misreading, and
   is not being rewritten.** For its two dominant consumers — the `reviewer`
   adjudicating a unit and the `PostToolUse` hook re-running on every edit — a
   binary `run.sh` exit code is the *correct* contract, and an interactive
   environment would be actively wrong (a hook cannot wait for a human to
   play). The user reinterpreted "microworld" this way on purpose and logged
   it. Step 9 below does **not** touch that contract; it adds a strictly
   optional second entry point used only on the path where a human is the
   consumer.
2. **`antislop:ubiquitous-language` already is the source's "shared
   vocabulary" idea**, instantiated deterministically. No gap.
3. **`ubiquitous-language` does not overlap with `explain-diff`** — checked
   before calling the latter a gap. Step 1's skill compares names introduced
   by a diff against `CONTEXT.md`'s defined terms and emits `file:line`
   drift findings; it has no opinion on whether a change is *explained*.
   Different input, different output, different purpose. The gap is real.
4. **The full `/explain-diff` skill is out of scope** for these follow-ups:
   HTML/Notion rendering, interactive figures, and everyday use on *every*
   diff rather than only on escalations are a separate capability with its own
   surfaces. Step 10 takes only the literate-diff *principle* and applies it
   at the single point this plan already puts a human in front of a change. A
   standalone explainer skill is a candidate for its own spec, named here so
   the omission is a recorded decision rather than an oversight.
5. **The reactive rerun hook is not a source technique and is not drift** —
   it is this plan's own addition (Context, "Design provenance").
6. **The "verify vs. participate" framing needs no step of its own.** It is
   rationale; it is now recorded in Context, and Step 8's on-by-default ADR is
   where it belongs. Step 11 is its mechanism.

### Clarifications (this round)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-09 Domain entities / data model: Q What artifacts do the follow-ups
  introduce, given the request named gaps rather than mechanisms? → A
  (self-resolved): three, each a plain file inside an artifact this plan
  already creates — an optional `explore.sh` in the bundle (Step 9), and
  `CHANGES.md` plus `QUIZ.md`/`QUIZ-ANSWERS.md` in the escalation packet
  (Steps 10, 11). No new directory, no new marker, no new config key, no new
  hook.
- 2026-08-09 User interaction flow: Q Does the comprehension quiz *gate* the
  human's approval, and who grades it? → A (self-resolved): it is
  self-administered, recorded, and **never graded by the reviewer**. R6
  forces this — a reviewer that could mark a human's answers wrong and refuse
  their approval would re-adjudicate the human, inverting the exact property
  ask #3 exists to create. It is also faithful to the source, where the quiz
  is a personal rule rather than an external gate.
- 2026-08-09 External dependencies & integrations: Q Can the source's own
  `/explain-diff` implementation be used to pin Step 10's format? → A
  (self-resolved): no — the gist and blog-post links are truncated in the
  archived transcript and were not fetched, so Step 10 is specified from the
  thread's prose principles only. Recorded in Context, "Design provenance",
  under "Unresolved in the source" rather than guessed at.
- 2026-08-09 Edge cases / failure handling: Q What happens on a unit that has
  no bundle, or whose bundle has no explore mode? → A (self-resolved): both
  degrade to today's behaviour exactly. `explore: none` in the marker; the
  packet still carries `CHANGES.md` and `QUIZ.md` when there is nothing to
  run, which is the case where they matter *most* — the human otherwise has
  only a verdict to react to.
- 2026-08-09 Terminology consistency: Q "Microworld" now carries two senses —
  the source's interactive environment and this plan's fixture bundle. Is
  that a drift defect? → A (self-resolved): it is a drift *hazard*, closed by
  documentation rather than by renaming. Renaming now would invalidate eight
  open issues for a cosmetic gain. Step 8 already requires a **Microworld**
  glossary entry; Steps 9–11 each add their own contrasting entry, and
  Context's provenance table states the narrowing in the one place a reader
  looks for the word's origin.
- 2026-08-09 Completion / acceptance signals: Q Are these follow-ups
  dispatchable now, or blocked? → A: **blocked on Steps 2/4/7** — they extend
  formats that do not exist yet. Surfaced as Open Question 5 because the
  alternative (folding them into the not-yet-implemented base steps) is a
  routing decision the requester owns, not a spec ambiguity.

### Step 9 — F1: an optional explore mode for the human-facing path

**The gap.** Step 4 hands an escalated unit to a human and Step 7 tells the
orchestrator not to pre-digest the result — the human runs it themselves. But
what they run returns pass or fail. There is nothing to vary, no intermediate
state to look at, no way to ask "what if". That is precisely the property the
source treats as the whole point of a microworld, and it is load-bearing here
rather than decorative: an artifact that can only say PASS gives a human
nothing to do but agree with it, which is the rubber-stamping this plan
already names as the failure mode it is trying to prevent (Context, "Bundle
storage", rationale 1).

**The addition — `microworlds/<unit-slug>/explore.sh`, optional.** It extends
Step 2's format; it does not alter it.

- Same **relocatability rule** as `run.sh`: resolve bundle-internal assets
  from `$(cd "$(dirname "$0")" && pwd)`, never from a hard-coded
  `microworlds/<unit>/` prefix. This is what survives the packet copy.
- **It has no exit-code contract and asserts nothing.** Its job is to let a
  human vary an input and see what the piece does: take an input path or
  parameter as `$1`, default to a fixture under `inputs/` when absent, run
  the piece, and print the actual resulting state in human-legible form.
  A pass/fail summary is explicitly *not* its output — `run.sh` already does
  that.
- `manifest.json` gains an optional `"explore": { "description": "<one line:
  what a human can vary and what they will see>" }`. Absent key = no explore
  mode.
- The bundle `README.md` (already mandatory, Step 2) gains a required section
  naming the explore command and **at least one concrete thing to try**
  ("set `foo` in `inputs/a.json` to a negative number and re-run — the
  ordering should invert"). A prompt to explore with no suggested first move
  is not usable by someone who has never seen the code.

**Where it is deliberately NOT used** — state each in the artifact named:

- The **rerun hook** (Step 3) never invokes `explore.sh`. Put this in the
  script's header comment: running an interactive, unbounded, non-asserting
  script on every `Edit`/`Write` would convert a silent hook into a hang.
- The **reviewer** never runs it as part of adjudication. `run.sh` remains the
  sole execution contract and the sole thing an acceptance criterion may name.
  The reviewer's only new duty is to copy it into the packet and name it in
  the marker.
- The **orchestrator** never runs it either — the same rule Step 7 already
  applies to `run.sh`, for the same reason. It surfaces the command; the
  human runs it.

**Marker and packet.** The `.escalated` marker body gains one line, `explore:
<packet-relative command>` or `explore: none`. The packet copy (Step 4) is
already wholesale, so `explore.sh` travels with it; preserve its executable
bit alongside `run.sh`'s.

**Authoring policy — not mandatory per unit.** `lead-programmer` SHOULD author
an `explore.sh` for units meeting the heavy-unit trigger (the same trigger
that drives escalation, referenced not restated) and MAY skip it otherwise. A
mandatory interactive artifact on every unit is exactly the ceremony that gets
stubbed into a one-line `echo` and stops meaning anything.

**Affected files**
- `templates/persona-protocol.md` — extend the existing
  `## Microworlds (per-unit runnable bundles)` section. **No new `## `
  section**, therefore no new parity-map entry; the criterion below proves it.
- `adapters/cursor/rules/persona-protocol.mdc` (hand-port, that port's style)
- `adapters/codex/agents-md-fragment.md` (hand-port, that port's style)
- `agents/lead-programmer.md` (authoring policy)
- `agents/reviewer.md` (copy into the packet; name it in the marker; never run
  it to adjudicate)
- `agents/orchestrator.md` (surface the explore command beside the run
  command; never run it — `(if present)` phrasing, G3)
- `hooks/scripts/microworld-rerun.sh` + `adapters/{cursor,codex}/hooks/scripts/microworld-rerun.sh`
  (header comment only — the explicit non-goal)
- `tests/microworld-rerun.test.sh` (new case (g); extend case (f))
- `CONTEXT.md` (glossary: **explore mode**, contrasted with `run.sh` — the
  non-asserting human entry point versus the asserting machine one)
- `.claude/agents/{orchestrator,lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  and `.claude/persona-config.json` (regenerated by `bin/cli.js --update`, G2)
- G1 version-bump triple.

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0 — proves no new
  top-level section was introduced. If one was, this unit must add the
  `codexMap` and `cursorMap` entries in the same commit (R3).
- `bash tests/validate.sh` exits 0.
- `grep -q 'explore.sh' templates/persona-protocol.md`,
  `grep -q 'explore.sh' .claude/agents/reviewer.md`, and
  `grep -q 'explore.sh' .claude/agents/orchestrator.md` all exit 0 (proves it
  reached both personas that act on it, not just the template).
- `grep -q 'explore: none' templates/persona-protocol.md` exits 0 — proves the
  **absent** case's marker line form was written down, not only the present
  case. Without it a persona will invent its own spelling for "no explore
  mode" and the marker stops being parseable.
- `bash tests/microworld-rerun.test.sh` exits 0, including a new case (g):
  a fixture bundle whose `explore.sh` writes a sentinel file and exits 1, and
  whose `run.sh` exits 0 → an edit matching that bundle's `watch` glob exits
  **0**, and `test -e <sentinel>` exits **non-zero** afterwards. This proves
  by execution that the hook never invokes explore mode, rather than asserting
  it in prose.
- Case (f) (relocation) extended to `explore.sh`: with the fixture bundle
  copied outside `microworlds/`, `bash <copied-path>/explore.sh` exits 0 and
  its stdout contains the **copied** bundle's path and does **not** contain
  the original `microworlds/` path. A relocatable `run.sh` beside a
  non-relocatable `explore.sh` is a packet that half-works.
- `grep -q 'explore' hooks/scripts/microworld-rerun.sh` exits 0 (the non-goal
  is recorded where the next maintainer of that script will read it).
- `grep -q 'explore mode' CONTEXT.md` exits 0.
- `git diff --name-only` includes `.claude/persona-config.json` (R2).

### Step 10 — F2: a literate change summary in the escalation packet

**The gap.** At escalation the human receives a run command, a one-line
inputs/expected description, the reviewer's would-be verdict and its notes,
and the bundle `README.md` describing *the piece*. Nothing describes *the
change*. To form an opinion the human must read a raw diff — files in
alphabetical order with no explanation, which is exactly the artifact the
source argues is the worst available way to understand a change. The plan
already accepts the cost of stopping the machine for a human; making that
human start from an unordered diff wastes most of what the stop bought.

**The addition — `CHANGES.md`, written by the reviewer into
`.claude/human-review/<task-id>/`** in the same action that writes the marker
and `PACKET.md`. No new tool, no rendering pipeline, no HTML: the reviewer has
already read the diff to reach its would-be verdict, and this is that reading
written down.

Fixed four-section shape, so it cannot decay into a restated diff:

1. `## Background` — what already existed in this area, for a reader who has
   not been following. Mentions no part of the change.
2. `## What this change is for` — the goal in one paragraph, in the
   `CONTEXT.md` glossary's terms, before any code appears.
3. `## Walkthrough` — the diff in **conceptual** order, one subsection per
   idea, each naming the files that idea touches and quoting only the lines
   that carry it. **Not one subsection per file**, and not alphabetical.
4. `## What to look at first` — the two or three places the reviewer is least
   confident about.

Constraints:

- **`CHANGES.md` is comprehension material, never a verdict record.** Its
  first line must read exactly `Comprehension material only — the .escalated
  marker is the authoritative record.` This is the same authority rule R11
  gives `PACKET.md`, applied to a second derived artifact, and it is stated
  in the file itself so a later reader cannot mistake it for the review.
- It **quotes** the diff, it does not reproduce it; soft cap 400 lines.
- A unit with **no bundle** (`microworld: none`, already allowed by Step 4)
  still gets a `CHANGES.md` — that is the case where it carries the entire
  human-facing payload.
- Deleted with the packet in all three of Step 7's terminal routes, on the
  same rule and in the same action.

**Affected files**
- `templates/persona-protocol.md` — extend the existing
  `## Fourth verdict: escalate-to-human` section (creation) and Step 7's
  subsection (deletion). **No new `## ` section.**
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents-md-fragment.md`
- `agents/reviewer.md` (authorship, shape, the authority line, deletion)
- `agents/orchestrator.md` (surface `CHANGES.md` to the human and say to read
  it before the diff; `(if present)` phrasing, G3)
- `README.md` (packet contents)
- `CONTEXT.md` (glossary: **literate change summary**, contrasted with
  `PACKET.md` — the explanation of the change versus the copy of the decision
  record; another near-synonym pair of exactly the kind ask #1 exists to
  catch)
- `.claude/agents/{six full-protocol personas}.md` and
  `.claude/persona-config.json` (regenerated, G2)
- G1 version-bump triple.

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0 (no new top-level
  section).
- `bash tests/validate.sh` exits 0.
- `grep -q 'CHANGES.md' templates/persona-protocol.md`,
  `grep -q 'CHANGES.md' .claude/agents/reviewer.md`, and
  `grep -q 'CHANGES.md' .claude/agents/orchestrator.md` all exit 0.
- All four section headings appear verbatim in the protocol text — four
  separate greps against `templates/persona-protocol.md`, each exiting 0:
  `## Background`, `## What this change is for`, `## Walkthrough`,
  `## What to look at first`. A shape described only as "sections like…" is
  not a shape.
- `grep -q 'not one subsection per file' templates/persona-protocol.md` exits
  0 — the sentinel-phrase device Step 2 already uses for `not part of the
  reviewed diff`. This is the single instruction that separates a literate
  walkthrough from a re-narrated diff, so it is asserted rather than trusted
  to survive editing.
- `grep -q 'Comprehension material only' templates/persona-protocol.md` exits
  0 and the same grep against `.claude/agents/reviewer.md` exits 0 (the
  authority line reached the persona that must write it).
- `grep -c 'CHANGES.md' templates/persona-protocol.md` is **≥ 2** — the
  creation rule and the deletion rule — proving a stated lifecycle at both
  ends, the same both-ends check Step 7 applies to `human-review`.
- `grep -q 'literate change summary' CONTEXT.md` exits 0.
- `grep -q 'CHANGES.md' README.md` exits 0.
- `git diff --name-only` includes `.claude/persona-config.json` (R2).

### Step 11 — F3: a comprehension self-check on the approve route

**The gap.** Step 7's approve route records `human: approved by <name> <UTC
ISO-8601>` — an attestation with nothing behind it. Of the three routes it is
the only one a human can complete without demonstrating engagement:
reject-with-reason requires a reason, fixable-a-specific-way requires a
directive, approve requires a name. This plan's own justification for the
durable packet is that an expiring review path "pressures toward
rubber-stamping" (Context, "Bundle storage", rationale 1); the cheapest rubber
stamp in the design is this line. The source's answer is a comprehension quiz,
framed explicitly as a *speed regulator* — a mechanical prompt to ask "do I
actually understand this?" before signing off. That is the same argument this
plan makes for escalation, one level down.

**The authority constraint that shapes the whole design.** The quiz is
**self-administered, recorded, and never graded by the reviewer**, and it is
**never a gate**. R6 forces this: a reviewer able to mark a human's answers
wrong and withhold their approval would re-adjudicate the human, destroying
the property ask #3 exists to create. It matches the source, where the quiz is
a personal rule rather than an external check. Anything stronger than
"recorded" is out of bounds here, and the criteria below assert that
explicitly rather than leaving it to good intentions.

**The addition.** In the same action that writes the marker, `PACKET.md`, and
`CHANGES.md`, the reviewer writes into `.claude/human-review/<task-id>/`:

- `QUIZ.md` — 3 to 5 questions, each answerable from `CHANGES.md` and the
  bundle alone, and each about consequence rather than recall: *"what happens
  to X when Y is absent?"*, never *"what is the new function called?"*. Recall
  questions are answerable by skimming, which defeats the point.
- `QUIZ-ANSWERS.md` — the reviewer's answer key, in a separate file so the
  human can attempt first and self-check after.

Step 7's approve-route attestation line gains one required token recording
what the human actually did, exactly one of:

- `quiz: passed-self-check`
- `quiz: skipped`
- `quiz: none-offered` — only valid when no `QUIZ.md` was written.

**`quiz: skipped` is a first-class, legitimate outcome.** It must not block,
must not warn, and must not be retried. Its entire value is being *on the
record*: an auditor reading `.claude/reviewed/<task-id>.pass` can see which
approvals came with a self-check and which did not. A spec that names only the
success token has quietly built a gate.

**The quiz is offered on the approve route only.** Reject-with-reason and
fixable-a-specific-way already carry evidence of engagement. Say so in the
protocol text, so a later reader does not "harmonise" the three routes.

**Marker-format safety.** The token goes on the appended `human:` attestation
line, never on the marker's required first line. `task-gate.sh`'s
`marker_valid()` checks only line 1's `PASS <task-id> ` prefix and
non-emptiness (`templates/persona-protocol.md`, PASS marker format v3), so
this change cannot invalidate an existing or a future marker.

The orchestrator surfaces `QUIZ.md` to the human and relays their `quiz:`
token verbatim; it **must not answer the quiz on the human's behalf** — the
exact analogue of Step 7's existing rule that it must not run `run.sh` and
pre-digest the result. Both files are deleted with the packet in all three
routes.

**Affected files**
- `templates/persona-protocol.md` — extend the `## Fourth verdict:
  escalate-to-human` section (packet contents) and Step 7's subsection (the
  approve-route row and the deletion rule). **No new `## ` section.**
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents-md-fragment.md`
- `agents/reviewer.md` (author both files; transcribe the token; never grade)
- `agents/orchestrator.md` (surface the quiz; relay the token verbatim; never
  answer it — `(if present)` phrasing, G3)
- `README.md` (packet contents and the three token values)
- `CONTEXT.md` (glossary: **comprehension quiz**, including that it is
  recorded and never gating)
- `.claude/agents/{six full-protocol personas}.md` and
  `.claude/persona-config.json` (regenerated, G2)
- G1 version-bump triple.

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0 (no new top-level
  section).
- `bash tests/validate.sh` exits 0.
- `grep -q 'QUIZ.md' templates/persona-protocol.md`,
  `grep -q 'QUIZ.md' .claude/agents/reviewer.md`, and
  `grep -q 'QUIZ.md' .claude/agents/orchestrator.md` all exit 0.
- All three tokens are written down — three separate greps against
  `templates/persona-protocol.md`, each exiting 0:
  `quiz: passed-self-check`, `quiz: skipped`, `quiz: none-offered`. Naming
  only the first would make the self-check a gate by omission, which is the
  specific defect this step is most likely to ship.
- `grep -q 'never graded by the reviewer' templates/persona-protocol.md` exits
  0 **and** the same grep against `.claude/agents/reviewer.md` exits 0 (the
  non-gate rule reached the persona that would otherwise grade).
- `grep -q 'must not answer the quiz' .claude/agents/orchestrator.md` exits 0.
- `grep -q 'approve route only' templates/persona-protocol.md` exits 0.
- `grep -c 'QUIZ.md' templates/persona-protocol.md` is **≥ 2** (creation and
  deletion — both-ends lifecycle).
- `bash tests/stop-gate-escalated.test.sh` and
  `bash tests/stop-gate-blocked.test.sh` both still exit 0 — no regression in
  marker mechanics from the attestation-line change.
- `grep -q 'comprehension quiz' CONTEXT.md` exits 0.
- `git diff --name-only` includes `.claude/persona-config.json` (R2).

### Open Questions (this round)

5. **OPEN — Should Steps 9–11 ship as their own units, or be folded into the
   not-yet-implemented Steps 2, 4, and 7?** (Originating check: CHK25.)
   Unlike this repo's earlier convergence rounds, the base plan has not
   shipped, so folding is technically available. The recommended default is
   already applied above (three separate units, sequenced after the base
   plan), so this does **not** block `task-master`.
   - **(a) Recommended — three separate units, sequenced after the base
     plan.** #129–138 are already open and labelled `ready-for-agent`;
     folding would mean rewriting published issues and re-slicing a plan this
     revision was explicitly scoped not to disturb. Keeps the append-only
     contract intact and each follow-up independently reviewable. Cost: three
     extra version-bump triples and three extra passes over the same protocol
     sections and adapter ports.
   - (b) Fold into Steps 2, 4, and 7 before those units are picked up.
     Cheaper — one pass per file, three fewer bumps, no ordering constraint.
     Requires editing three open issues and re-opening #122's body, and loses
     the separation that lets a reviewer judge the comprehension additions on
     their own merits.
   - (c) Defer Steps 10 and 11 to a separate spec, taking only Step 9 now.
     Defensible if the packet's payload is judged already sufficient — but
     Step 11 is the only mechanism in the plan that puts any weight behind the
     approve attestation, so deferring it leaves the cheapest route through
     human review the least evidenced one.

### Self-check (this round)

- CHK25: Does this round say when Steps 9–11 may be dispatched, given they
  extend formats that do not exist yet? — FAIL (missing) — converted to Open
  Question 5, with the default (separate units, sequenced after the base plan)
  applied in the Sequencing paragraph above.
- CHK26: Do Steps 9, 10, and 11 agree on when the packet's files are deleted?
  — PASS. All three defer to Step 7's three terminal routes and state deletion
  "in the same action", and Steps 10 and 11 each carry a `grep -c … ≥ 2`
  both-ends lifecycle criterion rather than only a creation rule.
- CHK27: Is "the quiz never gates" backed by a machine-checkable criterion
  rather than prose? — FAIL (ambiguous) — revised in place. Step 11 now
  asserts all three tokens individually, including `quiz: skipped`, plus the
  `never graded by the reviewer` sentinel in both the template and the
  regenerated reviewer copy. Prose alone would have let a "helpful"
  implementation add a soft warning on skip, which is a gate.
- CHK28: Is it defined which persona may run `explore.sh` and which may not?
  — PASS. Step 9 names the hook, the reviewer, and the orchestrator
  individually as non-runners, and case (g) proves the hook's abstention by
  execution (sentinel file absent) rather than by inspection.
- CHK29: Do Steps 9–11 and the existing Steps 2–7 agree on what `run.sh`'s
  contract is? — PASS. Step 9 states `run.sh` remains the sole execution
  contract and the only artifact an acceptance criterion may name; nothing in
  Steps 10 or 11 touches execution.
- CHK30: Is "microworld" defined unambiguously, given the provenance section
  now documents a second, narrower meaning than the source's? — FAIL
  (ambiguous) — revised in place. Context's provenance table now states the
  narrowing where the word's origin is discussed, and Step 9's glossary entry
  contrasts explore mode against `run.sh` so the two senses are separable in
  `CONTEXT.md` rather than only in this document.
- CHK31: Does each new step name at least one command producing a pass/fail?
  — PASS. Each of Steps 9–11 lists exit-code or `grep` assertions only; Step 9
  additionally carries two executable cases in
  `tests/microworld-rerun.test.sh`.
- CHK32: Does this round claim any gap that the existing plan already covers?
  — PASS. The "What is NOT a gap" list checks each candidate against the
  shipped text before claiming it, and explicitly clears Step 2's format and
  ask #1's skill rather than manufacturing work against them.
- CHK33: Are the constitution's MUST principles represented in each new step's
  affected files? — PASS. G1's version-bump triple is named in all three (P3,
  P5); every step routes `.claude/agents/*.md` and `fileHashes` through
  `bin/cli.js --update` (P2); `(if present)` phrasing is required on the
  orchestrator prose in all three (P4, G3); and every criterion is a runnable
  command (P1).
- CHK34: Does the plan say what the source could **not** tell us? — PASS.
  Context's "Unresolved in the source" names the two truncated links and
  states that Steps 10 and 11 are specified from prose principles rather than
  from the author's implementation, so a later reader knows which parts to
  re-check if the links are ever resolved.

### Constitution check, this round (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every criterion in Steps 9–11 is a
  runnable command, and Step 9's hook-abstention claim is proven by an
  executed sentinel rather than by reading the script.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no new
  machinery is introduced; `.claude/agents/*.md` and `fileHashes` are
  regenerated via `bin/cli.js --update` in all three steps (G2). Note the
  deliberate boundary: `CHANGES.md` and `QUIZ.md` are LLM-authored *prose*,
  not derived state, and neither is authoritative for any decision — the
  marker is (R11).
- P3 "Version-stamp discipline": satisfied — G1 applies unchanged to all
  three units.
- P4 "Optional personas degrade gracefully": satisfied — all three additions
  are inert when `reviewer` is not in `personaSelection` (nothing writes the
  packet), and G3 `(if present)` phrasing is required on the new orchestrator
  prose in each step.
- P5 "`tests/validate.sh` is the merge gate": satisfied — `bash
  tests/validate.sh` is a criterion on all three steps.

### Scribe update hint (this round)

After Steps 9–11 land, `scribe` should add three `CONTEXT.md` glossary
entries — **explore mode**, **literate change summary**, **comprehension
quiz** — each contrasted with its nearest neighbour (`explore.sh` vs `run.sh`;
`CHANGES.md` vs `PACKET.md`; the recorded self-check vs a gate). Add to the
`docs/adr/` set an ADR recording that the comprehension quiz is deliberately
never graded and never gating, with R6 as the reason — this is the decision a
future maintainer is most likely to try to "strengthen", and the strengthening
is the bug. Update `.claude/wiki/conventions.md` with the packet's full
contents and `.claude/wiki/architecture.md` with the design provenance and the
narrowing of "microworld" against its source.
