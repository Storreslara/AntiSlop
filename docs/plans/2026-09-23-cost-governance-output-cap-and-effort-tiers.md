# Cost governance: Bash output cap + per-persona effort tiers

Status: **FINAL — LOCKED** (spec-master, 2026-09-23; lock-in revision same day)
Tracker: GitHub issue **#476** (PRD view; this document is authoritative)
Open Questions: **0** — all three answered by the user 2026-09-23; see the
Open Questions section, which now records them as settled decisions.
Dispatch readiness: **ready for `task-master`** (6 steps, standard path),
subject to the R1 sequencing dependency.
Origin: ad-hoc researcher brief (not tracker-filed) recommending two
cost-control techniques not yet covered by this repo's existing mechanisms
(code-review-graph MCP scoping, `heavy-trigger.sh`/`reviewer-tier.sh` model
tiering, per-unit/persona model routing, agent-teams off-by-default).

## Goal

Two related cost-governance additions, both resolved to a **feasible** design
after investigation:

1. **Bound noisy `Bash` output mechanically**, rather than relying solely on
   the shared protocol's "Scope Bash output before it enters context"
   instruction — which is forgettable and unenforced.
2. **Declare per-persona reasoning-effort tiers** where effort can safely be
   lowered, and pin a floor on the paths where it must never be lowered.

Both goals survived feasibility investigation, but **Goal 1's shape changed
substantially** from the brief's premise. The details are in Context; the
short version is that Claude Code cannot rewrite tool *output*, already
truncates Bash output mechanically at a default nobody in this repo has ever
hit, and the one rewrite mechanism that does exist (`PreToolUse` +
`updatedInput`) would silently break every acceptance-criteria exit code in
this repo.

## Context

### Premise corrections (all measured, not inferred)

Four claims in the originating brief are false or inverted. Each is corrected
here so no downstream unit re-derives them wrongly.

**PC1 — "this repo relies entirely on an instruction" is false.** Claude Code
ships a mechanical Bash output cap today: the `bashOutputMaxChars` setting,
*"How many characters of a successful Bash or PowerShell command's output
Claude receives inline (default 30000; values clamp to 4000-128000). Output
past this is saved to a file and Claude receives a short preview plus the
path."* (schema text, Claude Code 2.1.281). It is active right now — it fired
twice during this spec's own investigation. What is missing is not the
mechanism but a **deliberate value**: `git grep bashOutputMaxChars
BASH_MAX_OUTPUT_LENGTH` returns nothing repo-wide, so this project silently
inherits the platform default.

**PC2 — `PostToolUse` cannot rewrite tool output. Confirmed infeasible.**
The 2.1.281 binary contains **zero** occurrences of `updatedOutput`
(vs. 119 of `updatedInput` and 49 of `hookSpecificOutput`). A `PostToolUse`
hook can emit `additionalContext` (which *adds*), `systemMessage`, and
`terminalSequence` — nothing that substitutes the tool result. The result is
committed to context before the hook fires. **No design in this spec attempts
output rewriting.**

**PC3 — `PreToolUse` + `updatedInput` is feasible but is REJECTED here, on a
measured safety ground.** The mechanism exists and is Anthropic's own
documented cost pattern: a hook returns `{hookSpecificOutput:
{permissionDecision: "allow", updatedInput: {command: "<cmd> | head -100"}}}`.
It is rejected because **appending a pipe destroys the command's exit
status**, and this repo's entire review gate rests on acceptance-criteria exit
codes ("a test command, a build/lint exit code" — shared protocol,
*Machine-checkable criteria*). Measured in this repo's own Bash tool:

```
$ bash -c 'exit 7' | head -5 ; echo $?
0                      # the 7 is gone
$ echo "$SHELLOPTS" | tr ':' '\n' | grep -i pipe
(no output)            # pipefail is NOT set
```

A reviewer running `bash tests/validate.sh` under such a hook would see
truncated output **and exit 0 regardless of whether validate passed**. Worse,
Anthropic's published example matches on `^(npm test|pytest|go test)` —
precisely the command class this repo must never rewrite. Adopting the
documented pattern here would convert a passing gate into an unfalsifiable
one. This is the ADR-worthy decision of the spec (see Step 6).

**PC4 — the brief's asymmetry wording is inverted relative to this repo's.**
The brief says human judgment "can lower a tier/effort but never raise one
past a measured or default floor." The actual rule in
`agents/orchestrator.md` § *Reviewer gate model selection* reads: judgment may
**downgrade** the verdict `sonnet` → `opus`, and may **never upgrade**
`opus` → `sonnet`. In this repo's vocabulary "downgrade" moves the verdict
toward **more** capability. The invariant is therefore: *judgment may only
move toward more capability, never less.* Applied to effort: **judgment may
raise effort above a declared value; it may never lower it.** Every step below
uses the repo's direction, not the brief's.

### Goal 2 feasibility: the mechanism EXISTS, and it is a frontmatter field

Resolved definitively against the installed Claude Code (2.1.281), which
answers the spec brief's explicit open question ("new frontmatter field, or a
per-dispatch runtime flag the orchestrator sets?"):

- `effort` **is** a documented agent-definition frontmatter key, sibling to
  `model`/`tools`/`memory` in the same schema object:
  `effort: <string>.optional().describe("Thinking effort: `low`, `medium`,
  `high`, `max`, or an integer.")`
- Accepted values are pinned in the binary as
  `ad = ["low","medium","high","xhigh","max"]`, or an integer. The plugin
  agent-file loader validates it and emits *"Plugin agent file … has invalid
  effort '<v>'. Valid options: …"* on a bad value — so a typo is loud, not
  silent. (Note the same loader **rejects** `permissionMode`, `hooks`, and
  `mcpServers` in plugin agent files; `effort` is *not* in that rejected set.)
- There is **no per-dispatch effort parameter.** The `Agent` tool's own schema
  exposes only `description`, `prompt`, `subagent_type`, `model`, and
  `isolation`. The harness's own tool description states it outright: *"Each
  agent type's model, reasoning effort, and tools come from its definition
  (`.claude/agents/*.md` frontmatter or SDK `agents`)."*

**This asymmetry is a gift, and the spec leans on it.** Because effort cannot
be set per dispatch, an orchestrator has *no dispatch-time knob to weaken*.
The reviewer's floor is enforced **by construction**, not by prose — the only
way to lower it is to edit `agents/reviewer.md`, which is exactly the kind of
harness-control-surface edit the repo already guards. This is strictly
stronger than the `model`-tier precedent, where a dispatch-time `model`
parameter *does* exist and the asymmetry must be maintained by instruction.

**Corollary — there is a real hole open today.** With no `effort:` declared on
any persona (confirmed: the brief's explorer grep, re-confirmed here), every
persona inherits the session effort. A session-level `/effort low` (the
slash command and the `--effort <level>` CLI flag both exist in 2.1.281)
therefore silently lowers the **reviewer's** effort with no record anywhere.
Declaring `effort:` on `reviewer` closes that hole. Goal 2 is consequently a
**gate-hardening change that also saves cost**, not a cost change that risks
the gate.

### Goal 2 already has deferred intent in-repo

The Codex port already wrote down this exact policy and deferred it pending
"the project's tier-mapping decision":

- `adapters/codex/agents/reviewer.toml:23-24` — *"set `model_reasoning_effort`
  to a judgment tier (e.g. "high") once the project's tier-mapping decision
  (spec §2 row 6) is made."*
- `adapters/codex/agents/explorer.toml:17-18` — *"set `model_reasoning_effort`
  to a cheap tier (e.g. "low") …"*

**This spec is that deferred decision.** Step 5 resolves both TODOs rather
than leaving the Claude and Codex ports disagreeing.

### Measured baseline for the cap value (Goal 1)

Measured 2026-09-23 over this project's full transcript store
(`~/.claude/projects/-home-sebas-AntiSlop/`): **521 transcript files, 14,641
`Bash` tool results, 20,156,531 chars (~5.0M tokens) of Bash output that
entered an agent's context.**

| statistic | chars |
|---|---|
| p50 | 586 |
| p75 | 1,659 |
| p90 | 3,457 |
| p95 | 5,329 |
| p99 | 11,277 |
| max | 29,457 |

| cap | calls over | % of calls | chars deferred to file | % of all Bash output |
|---|---|---|---|---|
| 4,000 | 1,192 | 8.14% | 4,034,257 | 20.0% |
| 8,000 | 340 | 2.32% | 1,458,795 | 7.2% |
| 12,000 | 124 | 0.85% | 601,412 | 3.0% |
| 16,000 | 55 | 0.38% | 263,781 | 1.3% |
| 30,000 (current default) | 0 | 0.00% | 0 | 0.0% |

Two readings matter. First, **the platform default has never bound**: no
recorded result exceeds 30,000, so the inherited default is doing nothing.
Second, the distribution is extremely skewed — p50 is 586 chars, so a cap set
just above p99 touches under 1% of calls while capping the tail that the
protocol instruction was written to catch.

Caveat, stated so no one over-reads the table: this measures **chars that
entered context** (already post-cap), which is the quantity we want to bound,
but it therefore *understates* raw command output for any call that was
already truncated. It is the right metric for sizing the cap and the wrong one
for estimating raw command verbosity.

### Non-blocking notes from the investigation

- **`.claude/reviewed/` sweep**: no `.fail` record mentions `trust-model.md`,
  `persona-protocol`, or `orchestrator.md`. 20+ mention `hooks/scripts` —
  which is precisely why this spec lands **no new hook script** (see Risks R5).
- **A gate false positive was hit during this investigation** and is recorded
  as an observation, not a work item: `harness-integrity-gate.sh` blocked the
  *read-only* command `git diff --stat && git diff .claude/persona-config.json
  | head -40`. The gate's Bash branch is a text scan over Set A literals, so a
  read-only `git diff` naming a Set A path is denied exactly as a write would
  be. This is consistent with the documented ADR-0025 design (word-presence
  scanning necessarily over-fires) and was worked around by *not naming the
  path*, never by rephrasing to evade the scan. Filed here for the record.

## Clarifications

Scorecard as scored at authoring. **Convergence reached 2026-09-23**: every
category below that scored Partial or Missing is now resolved by a dated line
in this section, including the three that required the user (the final three
entries). No category remains open and no assumption is carried as a deferral.

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Missing
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-23 Non-functional attributes: Q Does a lower Bash output cap risk a
  net *increase* in cost, by forcing agents to `Read` the persisted overflow
  file? → A (self-resolved): yes, and that is why the cap is set just above
  the measured p99 (12,000) rather than aggressively, and why Step 3 amends
  the protocol to tell agents to re-query narrowly instead of reading the
  persisted file whole. The residual trade-off was escalated to the user and
  is now settled at **12,000** — see the dated entry below.
- 2026-09-23 External dependencies & integrations: Q Does `bin/cli.js
  --update` propagate a newly-added `templates/settings-fragment.json` key to
  an already-adapted project? → A (self-resolved): **No.** `--update` returns
  at `bin/cli.js:2188` (`return runUpdate(args)`) and never reaches the
  fragment merge at `bin/cli.js:2387`. The fragment path is scaffold-only.
  Step 2 therefore adds a backfill inside `runUpdate` or the key is inert for
  this repo. See Risk R3.
- 2026-09-23 Edge cases / failure handling: Q What happens if a persona
  declares an `effort:` value Claude Code does not accept? → A
  (self-resolved): the plugin agent-file loader emits *"Plugin agent file …
  has invalid effort '<v>'. Valid options: low, medium, high, xhigh, max or an
  integer"*. Failure is loud, not silent. Step 4 additionally pins the
  accepted set in a test so a bad value cannot reach a mirror.
- 2026-09-23 Technical constraints & tradeoffs: Q Can a hook truncate Bash
  output before it reaches the calling agent's context? → A (self-resolved):
  **No for output; yes for input.** `PostToolUse` has no output-substitution
  field (`updatedOutput`: 0 occurrences in 2.1.281). `PreToolUse` can rewrite
  the *command* via `updatedInput`, but doing so masks exit status (measured;
  see PC3) and is rejected. See ADR in Step 6.
- 2026-09-23 Technical constraints & tradeoffs: Q Is reasoning effort settable
  per subagent dispatch, or only per agent definition? → A (self-resolved):
  **only per agent definition**, via the `effort:` frontmatter key. No
  dispatch-time parameter exists. This resolves the brief's stated open
  question in favour of a new frontmatter field, not an `orchestrator.md`-only
  documentation change — though Step 5 adds the policy prose too.
- 2026-09-23 Terminology consistency: Q Does "downgrade" in this repo mean
  *toward cheaper* or *toward more capable*? → A (self-resolved): **toward
  more capable** (`sonnet` → `opus`). The brief's phrasing is inverted; see
  PC4. All steps use the repo's direction.
- 2026-09-23 Terminology consistency: Q Do the terms this spec introduces
  exist in `CONTEXT.md`? → A (self-resolved): no. `effort tier`, `Bash output
  cap`, and `effort floor` are load-bearing new domain terms with no glossary
  entry (`ubiquitous-language` lens 3). Lens 1 (a glossary term used with a
  different meaning) and lens 2 (a new synonym for a defined term) each turned
  up nothing, with one near-miss: "tier" is used in-repo for *model* tiers
  (`reviewer-tier.sh`), so "effort tier" must always carry its qualifier and
  never be shortened to "tier". Step 6 adds the entries.
- 2026-09-23 Non-functional attributes: Q What value should the Bash output cap
  (`bashOutputMaxChars`) take, given the cost/friction trade-off the census
  cannot quantify? → A: **12,000**, per user — matching the recommended default
  (just above the measured p99 of 11,277; 0.85% of calls, 3.0% of Bash output
  chars deferred to file). The alternatives 8,000, 4,000 and *leave unset* are
  **rejected**. Step 2 pins this value; **settled, not to be re-litigated.**
- 2026-09-23 Technical constraints & tradeoffs: Q Should `milestone-auditor`
  receive a lowered `effort:` tier, as the originating brief proposed? → A:
  **No — leave it undeclared; do not lower it**, per user, matching the
  recommended default and upholding the spec's dissent from the brief. Ground:
  its role is adversarial judgment hunting premise gaps the reviewer
  structurally cannot see, and effort is per-persona, not per-phase, so its one
  mechanical phase cannot be priced separately. Step 4's table is now final,
  not provisional; **settled, not to be re-litigated.**
- 2026-09-23 Non-functional attributes: Q Is a `runUpdate` settings backfill an
  acceptable trust-surface expansion, given `.claude/settings.json` is Set B of
  `harness-integrity-gate.sh`? → A: **Yes, acceptable**, per user, matching the
  recommended default. Grounds as recommended: the backfill is additive-only by
  `deepMerge` semantics (never overwrites a chosen value), it writes one
  non-gate key, and it follows the existing hook-registration backfill
  precedent at `bin/cli.js:1293-1303` rather than introducing a new pattern.
  Step 2's backfill is therefore **required**, not conditional; **settled, not
  to be re-litigated.**

## Risks / dependencies

- **R1 — an in-flight sibling unit collides with Steps 3 and 4.**
  **Status re-confirmed 2026-09-23 (revised — the original note's premise has
  moved, its conclusion has not).** The `cache-ttl-gapped-personas` unit
  touches 19 files that Steps 3 and 4 also touch:
  `agents/{reviewer,task-master}.md`, all 10 `.claude/agents/*.md` mirrors,
  `.claude/persona-config.json`, `.claude/persona-protocol{,-slim}.md`,
  `.claude/protocol-digest.md`, `CHANGELOG.md`, and both version files.
  **The blocker stands: Steps 3 and 4 must not be dispatched until that unit
  lands a PASS-reviewed commit.** What changed since this spec was authored:

  - Its **first attempt did commit**, as `66b9666`, bumping both version files
    0.31.74 → 0.31.75. So "uncommitted" as originally written is now wrong.
  - That attempt then **FAILed review** (`.claude/reviewed/cache-ttl-gapped-personas.fail`,
    2026-09-24T02:29:31Z, reviewing `66b9666`): `cacheTtl` was placed at the
    **top level** of the frontmatter, where Claude Code's strict agent schema
    silently discards it — the key is accepted **only** nested under
    `experimental:`. The unit was therefore a no-op. This is the same defect
    class this spec separately flagged.
  - A **fix is in flight and uncommitted** — present in the working tree at
    spec-revision time (the nesting corrected to `experimental:` / `cacheTtl:
    1h` in all four files, version bumped again to **0.31.76**), but **not yet
    landed and not yet re-reviewed**. There is no `.pass` marker for this unit.

  **Dependency for `task-master` to check at dispatch time** (not re-verified
  here, per the division of labour): before dispatching Step 3 or Step 4,
  confirm (a) `.claude/reviewed/cache-ttl-gapped-personas.pass` exists,
  (b) `git status --porcelain` is clean of that unit's 19 files, and (c) the
  **then-current** version in both version files — this spec's R2 bump
  obligation is *bump from whatever is current*, and the baseline has already
  moved twice (0.31.74 → 0.31.75 → 0.31.76 pending). Do **not** hardcode a
  target version into any Step 3/4 dispatch prompt. Do not re-scope the
  sibling unit; just sequence after it.
- **R2 — version-stamp ordering (constitution P3).** Steps 3, 4 and 5 all
  touch version-stamped paths (`agents/*.md`, `templates/`). Order edits
  **bump → CHANGELOG → `node bin/cli.js --update`**, and bump *both*
  `.claude-plugin/plugin.json` and `package.json` (`tests/validate.sh` asserts
  they are equal). `--update` short-circuits on an unchanged version and
  regenerates nothing; if an implementer reports *"already current"*, the bump
  did not land — that is an escalation, never something to work around.
- **R3 — the settings key is inert without a `runUpdate` backfill.** Per the
  Clarifications entry above, `--update` never reaches the settings-fragment
  merge. Step 2 is specified to add the backfill *and* to prove it, because a
  fragment-only change would pass a naive "the key is in the template" grep
  while doing nothing for this repo.
- **R4 — implementers cannot edit `.claude/settings.json` directly.** It is
  **Set B** in `harness-integrity-gate.sh` (denied on `Write`/`Edit`, for any
  identity, with no grant branch). Set B is deliberately absent from the gate's
  Bash branch per ADR-0025, so the sanctioned route is *running `bin/cli.js`
  via Bash* — which is exactly what Step 2 specifies. An implementer that tries
  to hand-edit the file will be blocked, and hand-editing would also violate
  constitution P2 (prefer deterministic scripts over hand-edits).
- **R5 — no new hook script lands in this spec, deliberately.** Consequently
  `docs/trust-model.md` needs **no new row** and
  `tests/trust-model-bijection.test.js`'s `EXPECTED_SELF_REPORTED_COUNT`
  (pinned at 10, line 27) is **not** touched. This is called out because the
  originating brief anticipated a new hook and its trust-model row; the
  investigation removed that need. If a later revision reintroduces a hook
  script, both obligations return.
- **R6 — `tests/validate.sh` performs frontmatter shape checks** (constitution
  P5 names this as the merge gate's purpose, and the historically-worst bug
  class is "malformed frontmatter silently breaking agent discovery"). Step 4
  adds a frontmatter key and must keep validate green.
- **R7 — effort-inheritance is high-confidence but not fully traced.** The
  claim "a persona with no `effort:` inherits the session effort" is supported
  by the binary's `sessionEffort` resolver (which carries an explicit
  `inherit` kind) and by `effort: w.effort` being read straight off the agent
  config at spawn. It is *not* traced end-to-end through the fallback. Step 4
  therefore carries an explicit empirical pin rather than asserting it. If the
  pin fails, Goal 2's *cost* half still stands and only the *hole-closing*
  framing in Context weakens — it does not invalidate any step.
- **R8 — adapter ports are hand-maintained.** The Codex and Cursor protocol
  and agent ports are **not** rendered by `bin/cli.js`; they are edited by
  hand, and `tests/adapter-protocol-parity.test.js` asserts section presence
  via **literal probes**, so a new clause with no probe drifts freely. Steps 3
  and 5 must add probes in the same unit that adds the prose.
- **R9 — adapter persona coverage is partial.** `adapters/codex/agents/` and
  `adapters/cursor/agents/` carry only `explorer`, `lead-programmer`,
  `orchestrator`, `reviewer`. There is no `task-master` port, so Step 5's
  adapter work covers `reviewer` and `explorer` only. Constitution P4
  (optional personas degrade gracefully) applies to the prose.
- **R10 — the declared Claude Code version floor is a fragmented surface, and
  Goal 2 has an undetermined floor of its own.** Added on the 2026-09-23
  lock-in revision, surfaced directly by the sibling unit's FAIL (DEFECT 2),
  which found `.claude-plugin/plugin.json` declaring `>=2.1.178` while the
  feature it shipped required `>=2.1.248`. Two consequences for this spec,
  neither previously recorded:
  1. **Step 4 inherits the same defect class.** `effort:` is a frontmatter key
     with its own introduction version, which this spec did **not** determine
     and cannot determine locally: only 2.1.277-2.1.281 are present under
     `~/.local/share/claude/versions/`, so there is nothing to bisect against.
     All `effort:` evidence in Context is measured on **2.1.281 only**. Step 4
     therefore carries an explicit floor criterion (**Step 4 criterion 8**)
     rather than inheriting the sibling's mistake, and `bashOutputMaxChars`
     gets the same treatment in **Step 2 criterion 8**.
  2. **The floor is stated in at least six places and they disagree today.**
     `README.md:67` and `.claude-plugin/plugin.json:4` (post-fix) say
     `2.1.248`; `skills/install-antislop/SKILL.md:27`, its
     `.claude/skills/...` mirror, `commands/start-feature-team.md:72`, and
     `templates/settings-fragment.json`'s `_comment` all still say `2.1.178`.
     The in-flight sibling fix updates **only** `plugin.json`. Step 2 edits
     `templates/settings-fragment.json`, whose `_comment` is one of the stale
     copies — so that step is touching a surface it should correct rather than
     leave contradicting the manifest. **Scoped deliberately**: this spec
     corrects only the floor statements in files its own steps already touch.
     A full six-surface reconciliation is a separate unit, named in Out of
     Scope rather than silently absorbed here.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every feasibility claim in Context is
  backed by a measurement (binary schema text, an empirical pipeline exit-code
  run, a 14,641-sample transcript census, a control-flow line number), not by
  inference. Steps 2 and 4 each carry a criterion that proves the change is
  *effective*, not merely *present*, specifically to avoid the vacuous-grep
  failure class.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 2
  routes the settings change through `bin/cli.js` rather than hand-editing
  `.claude/settings.json`, and Steps 3-5 regenerate mirrors via
  `--update` rather than hand-editing them.
- P3 "Version-stamp discipline": satisfied — see Risk R2; Steps 3, 4 and 5
  each carry the bump + CHANGELOG obligation in their acceptance criteria.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step's
  acceptance criteria include `bash tests/validate.sh`.
- P4 "Optional personas degrade gracefully" (SHOULD, not MUST): satisfied —
  Step 5's prose is conditionally phrased, and Risk R9 records that two of the
  four tiered personas have no adapter port.

## Steps

### Step 1 — Re-runnable Bash-output census

**Affected files**: `scripts/bash-output-census.js` (new),
`tests/bash-output-census.test.js` (new).

Build the measurement that produced the Context baseline into a re-runnable
script, so the cap value stays re-derivable rather than frozen as a number
nobody can reproduce. Reads the transcript store under
`~/.claude/projects/<project-slug>/`, pairs `tool_use` blocks named `Bash` to
their `tool_result` by `tool_use_id`, and reports percentiles plus
per-candidate-cap savings. Supports `--json`.

**Acceptance criteria**
1. `node scripts/bash-output-census.js --json` exits 0 and emits parseable
   JSON containing keys `count`, `totalChars`, `p50`, `p90`, `p99`, `max`, and
   a `caps` array.
2. `node tests/bash-output-census.test.js` exits 0. It runs the script against
   a **fixture** transcript directory (not the live store) with hand-computed
   expected percentiles, so the test is deterministic and does not depend on
   the operator's history.
3. The test includes a non-vacuity case: a fixture whose only `tool_result` is
   for a non-`Bash` tool yields `count: 0`, proving the Bash filter is real
   and the script is not counting every tool result.
4. `bash tests/validate.sh` exits 0.

### Step 2 — Set an explicit Bash output cap, and make it reach this repo

**Affected files**: `templates/settings-fragment.json`, `bin/cli.js`
(inside `runUpdate`, near the existing settings write sites at ~1245-1308),
`tests/cli-settings-backfill.test.js` (new or extended),
`CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`.

Add `bashOutputMaxChars: 12000` to the settings fragment **and** backfill it
in `runUpdate`, mirroring the existing hook-registration backfill pattern at
`bin/cli.js:1293-1303`. Use the established `deepMerge` semantics, which are
additive-only (`else if (!(key in target)) target[key] = source[key]`) — so a
project that already chose its own value is never overwritten.

**Both halves of this step are settled decisions, not options.** The value
**12,000** is final (user, 2026-09-23 — see Clarifications), and the
`runUpdate` backfill is an **approved** Set-B trust-surface expansion (user,
2026-09-23), so "leave the fragment scaffold-only" is no longer an available
implementation. An implementer must not substitute a different value or drop
the backfill.

Additionally, per R10: `templates/settings-fragment.json`'s `_comment`
currently states the plugin's version pin as `>=2.1.178`, which contradicts
the manifest and `README.md`. Correct that one statement in the same edit, and
state the floor that `bashOutputMaxChars` itself requires (or, if it cannot be
determined from the available installed versions, say so explicitly rather
than leaving a number that was never checked).

**Acceptance criteria**
1. `node -e 'const c=require("./templates/settings-fragment.json");
   process.exit(c.bashOutputMaxChars===12000?0:1)'` exits 0.
2. A test proves the **backfill**, not just the template: running the update
   path against a fixture project whose `.claude/settings.json` **lacks** the
   key results in that file containing `bashOutputMaxChars: 12000`.
3. A test proves **non-clobbering**: the same run against a fixture that
   already sets `bashOutputMaxChars: 4000` leaves it at `4000`.
4. **Mutation proof** (the criterion must be falsifiable): with the
   `runUpdate` backfill hunk reverted, criterion 2's test **fails**. A
   template-only change must not be able to pass this step.
5. The chosen value is inside Claude Code's documented clamp of 4,000-128,000.
   The value is **12,000** exactly; a test or `node -e` check pinning `12000`
   (criterion 1) is the falsifiable form of this — "some value in the clamp"
   does not satisfy it.
6. `bash tests/validate.sh` and `node tests/cli-backfill.test.js` exit 0.
7. Version bumped in both files, equal, with a CHANGELOG entry (P3). Bump from
   the **then-current** version, whatever it is — do not assume the value
   recorded anywhere in this document (R1).
8. **Version-floor statement (R10)**: `git grep -c "2\.1\.178" --
   templates/settings-fragment.json` returns **0**, and the `_comment`'s pin
   agrees with `.claude-plugin/plugin.json`'s declared floor. If the
   introduction version of `bashOutputMaxChars` could not be established from
   the installed versions available, the unit's report says so plainly (P1)
   rather than asserting an unverified number; that negative result does not
   block the step.

### Step 3 — Teach the protocol what the mechanical backstop does

**Affected files**: `templates/persona-protocol.md` (§ *Scope Bash output
before it enters context*, line ~45), `templates/persona-protocol-slim.md`
(line ~38), `adapters/cursor/rules/persona-protocol.mdc`,
`adapters/codex/agents-md-fragment.md`,
`tests/adapter-protocol-parity.test.js` (probes at lines ~76 and ~98),
then all generated mirrors via `--update`: `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, and all 10
`.claude/agents/*.md`. Plus `CHANGELOG.md`,
`.claude-plugin/plugin.json`, `package.json`.

The section currently reads as though self-policing is the only control. Amend
it to state that a mechanical cap exists, what overflow looks like, and — the
load-bearing addition — **what to do when you see it**: re-query narrowly,
rather than `Read`ing the persisted overflow file whole, which would re-incur
the entire cost the cap just saved.

This section is in `UNIVERSAL_PROTOCOL_CORE` (`bin/cli.js:676-683`), so it
reaches **all 10 personas** — no per-persona trim decision is needed, unlike
sections outside that list.

**Acceptance criteria**
1. The new guidance's distinctive sentence appears in **exactly** the
   enumerated surface set — verified by `git grep -l "<sentence>"` returning
   the 4 hand-maintained sources (`templates/persona-protocol.md`,
   `templates/persona-protocol-slim.md`,
   `adapters/cursor/rules/persona-protocol.mdc`,
   `adapters/codex/agents-md-fragment.md`) **plus** the 13 generated mirrors
   (2 protocol files, 1 digest, 10 agent files), and no others.
2. A literal probe for the new clause is added to
   `tests/adapter-protocol-parity.test.js`'s probe table, and
   `node tests/adapter-protocol-parity.test.js` exits 0 (R8: a clause with no
   probe drifts freely).
3. **Mutation proof**: deleting the clause from
   `adapters/codex/agents-md-fragment.md` alone makes the parity test fail.
4. The amended text states all three of: that a cap exists, that overflow is
   written to a file with a preview and path, and that the correct response is
   a narrower re-query rather than reading the persisted file whole.
5. `bash tests/validate.sh` exits 0; version bumped + CHANGELOG (P3).

### Step 4 — Declare `effort:` tiers on the Claude personas

**Affected files**: `agents/explorer.md`, `agents/task-master.md`,
`agents/reviewer.md` (frontmatter only), `tests/effort-tier-consistency.test.js`
(new), then `.claude/agents/*.md` mirrors via `--update`, plus
`.claude/persona-config.json` `fileHashes`, `CHANGELOG.md`,
`.claude-plugin/plugin.json`, `package.json`.

**Read but NOT edited**: `agents/milestone-auditor.md` and its mirror — the new
test asserts they *lack* an `effort:` key (criterion 7). **Direct line-level
collision (R1)**: the sibling `cache-ttl-gapped-personas` unit adds
`experimental:` / `cacheTtl: 1h` immediately after `model:` in the frontmatter
of `agents/reviewer.md` and `agents/task-master.md` — the same two frontmatter
blocks this step edits, within a line or two. This is not a merely overlapping
file set but an overlapping hunk, which is why R1's sequencing is a hard
prerequisite and not a preference.

Model this on the `cacheTtl: 1h` sibling's 19-file footprint (R1) and on
`tests/writer-tier-consistency.test.js`, which already asserts a frontmatter
`model:` value consistently across source and mirrors — the same shape this
test needs.

**Tiers — FINAL** (all four rows settled; the `milestone-auditor` row was
escalated and answered by the user on 2026-09-23, see Clarifications):

| persona | `effort:` | rationale |
|---|---|---|
| `explorer` | `low` | Mechanical traversal; returns distilled facts. The Codex port already specifies "a cheap tier (e.g. `low`)". |
| `task-master` | `medium` | Mechanical slicing against an already-finalized spec; it never revises spec substance. |
| `reviewer` | `high` | **A floor, not a tuning.** Closes the `/effort low` inheritance hole (see Context). |
| `milestone-auditor` | *(none — unchanged)* | Adversarial judgment hunting premise gaps the reviewer structurally cannot see. **Decided: leave undeclared, do not lower** (user, 2026-09-23), overriding the originating brief. Effort is per-persona, not per-phase, so its one mechanical phase cannot be priced separately. |

**Acceptance criteria**
1. Each named `agents/<persona>.md` declares the tabled `effort:` value, and
   the corresponding `.claude/agents/<persona>.md` mirror carries the same
   value — asserted by `node tests/effort-tier-consistency.test.js`, exit 0.
2. That test asserts every declared `effort:` value is a member of
   `["low","medium","high","xhigh","max"]` or an integer, so an invalid value
   cannot reach a mirror.
3. **Mutation proof**: changing `agents/reviewer.md`'s `effort:` to `low`
   makes the test fail, because the test pins `reviewer` to `high` explicitly
   as a floor — not merely "some valid value".
4. **Empirical pin for R7**: the unit records, in its report, an observed
   check that a persona declaring `effort:` is loaded without Claude Code
   emitting *"has invalid effort"*. If the inheritance behaviour cannot be
   observed, say so plainly rather than asserting it — this is a P1
   obligation, and a negative result does not block the step.
5. `bash tests/validate.sh` exits 0 (frontmatter shape unbroken — R6, P5).
6. Version bumped + CHANGELOG (P3), from the **then-current** version (R1);
   `fileHashes` regenerated by `--update`, never hand-edited (P2).
7. **`milestone-auditor` carries no `effort:` key.** Asserted positively by the
   test, not merely left unmentioned — `agents/milestone-auditor.md` and its
   mirror must both lack the key, so a later well-meaning "complete the table"
   edit fails CI. This pins the user's decision mechanically.
8. **Version-floor obligation (R10)** — the defect class the sibling
   `cache-ttl-gapped-personas` unit FAILed on, applied here before it can
   recur. `effort:` is a frontmatter key whose introduction version this spec
   did not establish; all evidence for it is measured on 2.1.281 only. The unit
   must either (a) establish the introduction version and confirm
   `.claude-plugin/plugin.json`'s declared floor is at or above it, raising the
   floor in the same commit if not, or (b) report plainly that the version
   could not be established from the installed versions available (only
   2.1.277-2.1.281 are present locally) and state the degradation for older
   versions in the CHANGELOG entry. Silently shipping a key whose floor was
   never checked is **not** an acceptable third option — that is exactly
   DEFECT 2 of the sibling FAIL.
9. **Prose must not overstate the effect (R10, sibling DEFECT 3).** The
   CHANGELOG entry and commit message may claim only what criterion 4's
   empirical pin actually observed. If inheritance could not be observed, the
   prose says the key is *declared*, not that effort is *demonstrably* floored.

### Step 5 — Write down the effort policy and resolve the Codex TODOs

**Affected files**: `agents/orchestrator.md` (new subsection adjacent to
*Reviewer gate model selection*), `adapters/codex/agents/reviewer.toml`
(lines ~23-24), `adapters/codex/agents/explorer.toml` (lines ~17-18),
`adapters/cursor/agents/{reviewer,explorer}.md`,
`tests/adapter-protocol-parity.test.js`, generated mirrors via `--update`,
`CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`.

Add an *Effort-tier policy* subsection to `orchestrator.md` stating: (a) effort
is declared in frontmatter and is **not** settable per dispatch, so there is no
dispatch-time knob; (b) the one-way rule, in this repo's direction — judgment
may **raise** a persona's effort above its declared value, never lower it
(PC4); (c) `reviewer` is a hard exclusion whose `high` is a floor, mirroring
*"Fable is never valid on the gate"*. Then replace the two Codex TODOs, whose
stated precondition ("once the project's tier-mapping decision … is made") this
spec satisfies, with the decided values.

**Acceptance criteria**
1. `agents/orchestrator.md` contains a heading matching `/Effort[- ]tier
   policy/`, and the section states the never-lower rule and names `reviewer`
   as the hard exclusion.
2. `git grep -c "once the project's tier-mapping decision"` over `adapters/`
   returns **0** — both deferred TODOs resolved, not just one.
3. `adapters/codex/agents/reviewer.toml` sets `model_reasoning_effort` to the
   judgment tier and `adapters/codex/agents/explorer.toml` to the cheap tier,
   consistent with Step 4's table.
4. A literal probe covering the new orchestrator clause is added and
   `node tests/adapter-protocol-parity.test.js` exits 0 (R8).
5. The prose is conditionally phrased for optional personas (P4), and covers
   only `reviewer`/`explorer` on the adapter side (R9) without implying a
   `task-master` port exists.
6. `bash tests/validate.sh` exits 0; version bumped + CHANGELOG (P3).

### Step 6 — ADRs and glossary (scribe)

**Affected files**: `docs/adr/00NN-bash-output-cap-not-command-rewriting.md`
(new), `docs/adr/00NN-effort-tiers-frontmatter-only-floor.md` (new),
`CONTEXT.md`.

Two decisions meet all three ADR tests (hard to reverse, surprising without
context, a real trade-off with genuine alternatives):

**ADR A — cap, don't rewrite.** Records that this repo declined Anthropic's
own documented `PreToolUse`/`updatedInput` cost pattern, and why: pipeline
exit-status masking versus a review gate built on exit codes (PC3). Without
this, a future reader finding the costs doc will reasonably ask why the
documented pattern was not adopted, and may adopt it.

**ADR B — effort is a frontmatter-only floor.** Records that effort is not
settable per dispatch, that this makes the reviewer's floor structural rather
than instruction-enforced, and that the one-way rule runs toward *more*
capability (PC4) — the opposite of the phrasing the originating brief used.

Glossary entries for the three new load-bearing terms (lens 3):
**effort tier**, **Bash output cap**, **effort floor**. Per the near-miss
recorded in Clarifications, "effort tier" must keep its qualifier and never be
shortened to "tier", which already denotes *model* tiers in-repo.

**Acceptance criteria**
1. Both ADR files exist, are numbered by incrementing from the highest
   existing ADR number **at execution time** (currently 0031; do not reuse the
   0007 hole, which `CONTEXT.md` links), and each carries Context / Decision /
   Consequences sections.
2. ADR A states the exit-status-masking ground explicitly and names the
   rejected mechanism (`PreToolUse` + `updatedInput`).
3. `CONTEXT.md` contains entries for all three terms, in the file's established
   `**term**:` format.
4. `node tests/trust-model-bijection.test.js` exits 0 **and
   `EXPECTED_SELF_REPORTED_COUNT` is still 10** — proving this spec landed no
   hook script (R5).
5. `bash tests/validate.sh` exits 0.

## Open Questions

**None remain. All three were answered by the user on 2026-09-23 and the spec
is LOCKED.** They are recorded here as decisions rather than deleted, so a
future reader can see what was asked, what was chosen, and what was rejected.
Each is also logged as a dated line in Clarifications. **These are settled and
must not be reopened** by `task-master`, a `lead-programmer`, or a reviewer; a
unit that believes one is wrong escalates to the human, it does not decide.

1. **Bash output cap value — RESOLVED: `12,000`.** The answer matched the
   recommended default: just above the measured p99 of 11,277, touching 0.85%
   of calls and deferring 3.0% of Bash output chars. **Rejected alternatives**:
   8,000 (2.32% of calls, 7.2% deferred — more saving, more overflow-file
   friction); 4,000 (8.14%, 20.0% — the clamp floor, likely net-negative once
   re-read cost is counted); and *leave unset* at the 30,000 default, which
   would have dropped Step 2 entirely and kept only the documentation half of
   Goal 1. Escalated originally because it traded measurable token savings
   against re-query friction the census cannot quantify. Pinned by Step 2
   criteria 1 and 5.
2. **`milestone-auditor` effort tier — RESOLVED: leave it undeclared, do not
   lower it.** The answer matched the recommended default, which **dissented
   from the originating brief**'s proposal to treat it as a cheap "mechanical
   end-to-end path". Ground: its role is adversarial judgment, hunting premise
   gaps and goal drift the reviewer *structurally cannot see*; the mechanical
   path is one phase of a judgment-heavy persona, and effort is per-persona,
   not per-phase, so there is no mechanism to lower it for only that phase.
   **Rejected alternative**: declare `effort: medium` and accept the risk.
   Pinned mechanically by Step 4 criterion 7, which asserts the key is
   *absent* rather than leaving its absence to convention.
3. **`runUpdate` settings backfill as a Set-B trust-surface expansion —
   RESOLVED: acceptable.** The answer matched the recommended default. Step 2
   has `bin/cli.js` write a key into `.claude/settings.json`, which is **Set B**
   of `harness-integrity-gate.sh` (the gate's own registration surface).
   Grounds: the backfill is additive-only by `deepMerge` semantics (never
   overwrites an existing value), it writes one non-gate key, and it follows
   the existing hook-registration backfill precedent at `bin/cli.js:1293-1303`
   rather than introducing a new pattern. **Rejected alternative**: leave the
   fragment scaffold-only and have the operator add the key by hand, accepting
   that this repo's own settings never receive it. Escalated originally because
   expanding what a script may write into a gate-registration surface is a
   trust-boundary decision, not a technical one. The backfill is consequently
   **mandatory**, and Step 2 criterion 4's mutation proof is what makes
   "mandatory" falsifiable.

## Out of Scope

- **A full reconciliation of the declared Claude Code version floor across all
  six surfaces that state it** (`README.md`, `.claude-plugin/plugin.json`,
  `skills/install-antislop/SKILL.md` and its `.claude/` mirror,
  `commands/start-feature-team.md`, and `templates/settings-fragment.json`'s
  `_comment`). Per R10, this spec corrects the floor **only** in files its own
  steps already touch; the remaining stale copies are a separate unit, named
  here so the partial fix is a recorded choice rather than an oversight.
- **`cacheTtl` frontmatter** — owned by the in-flight `cache-ttl-gapped-personas`
  unit and not re-scoped here (R1).
- Any `PreToolUse` command rewriting via `updatedInput` (rejected on the
  exit-status-masking ground, PC3, recorded as ADR A); any `PostToolUse` output
  filtering (mechanically impossible in 2.1.281, PC2); any new hook script and
  therefore any `docs/trust-model.md` row or `EXPECTED_SELF_REPORTED_COUNT`
  change (R5); per-phase effort; `MAX_THINKING_TOKENS` tuning.

## Self-check

- CHK1: Is it stated, unambiguously, whether a hook can rewrite Bash tool
  output? — PASS (PC2: no for output, yes for input, each with a measurement).
- CHK2: Does the plan say what happens if Goal 1's premise is false, rather
  than forcing the brief's design through? — PASS (PC1/PC3 correct the premise
  and reject the rewriting design on a measured ground).
- CHK3: Is the cap value justified by a measurement rather than chosen
  arbitrarily? — PASS (p99 = 11,277 → 12,000; full table in Context).
- CHK4: Do Steps 2 and 3 agree about which mechanism bounds output? — PASS
  (Step 2 sets the cap; Step 3 documents that same cap; neither introduces a
  hook).
- CHK5: Is "effort" defined as a frontmatter field or a dispatch parameter,
  consistently across all steps? — PASS (Context, Step 4, Step 5 and ADR B all
  say frontmatter-only, no dispatch parameter).
- CHK6: Does the plan use the repo's direction for the one-way asymmetry, not
  the brief's inverted phrasing? — FAIL (conflicting) — revised in place; PC4
  now states the correction explicitly and Step 5 criterion 1 pins the
  never-lower wording.
- CHK7: Is the trust-model / bijection-test obligation resolved either way? —
  FAIL (missing) — revised in place; R5 and Step 6 criterion 4 now state that
  no hook lands and that `EXPECTED_SELF_REPORTED_COUNT` stays 10.
- CHK8: Does every step have at least one criterion that would fail if the
  change were present-but-ineffective? — FAIL (ambiguous) — revised in place;
  mutation-proof criteria added to Steps 1, 2, 3 and 4.
- CHK9: Is the collision with the uncommitted sibling unit stated with its
  sequencing consequence? — PASS (R1: 19 files, must land after it commits).
- CHK10: Is it stated how the settings key reaches *this* repo, not just new
  adopters? — FAIL (missing) — revised in place; Clarifications records that
  `--update` returns at `bin/cli.js:2188` and never reaches the fragment merge
  at 2387, and Step 2 criteria 2 and 4 require the backfill.
- CHK11: Can an implementer edit `.claude/settings.json` directly? — PASS (R4:
  no, Set B; route through `bin/cli.js` via Bash).
- CHK12: Is the residual uncertainty about effort inheritance disclosed rather
  than asserted? — PASS (R7 and Step 4 criterion 4 both mark it unproven and
  say a negative result does not block).
- CHK13: Does every FAIL above have a resolution, and every Open Question a
  recommended default? — PASS (four FAILs, all revised in place; all three Open
  Questions carried a recommended default and named alternatives, and all three
  are now answered — none remain open).

Items added on the 2026-09-23 lock-in revision:

- CHK14: Is each of the three answered questions stated as a *decision* rather
  than a recommendation, in every place the plan mentions it? — PASS (Open
  Questions 1-3 now read RESOLVED with rejected alternatives named; Step 2's
  body states both halves are settled, not options; Step 4's tier table is
  headed FINAL and its `milestone-auditor` row records the decision; each has a
  dated Clarifications line).
- CHK15: Is the settled `milestone-auditor` decision enforced by something a
  machine can check, or only by prose? — FAIL (ambiguous) — revised in place;
  Step 4 criterion 7 now asserts the *absence* of the key in both the source
  and the mirror, so a later "complete the table" edit fails CI. A decision to
  *not* do something needs a positive assertion or it is unenforceable.
- CHK16: Does the plan state a Claude Code version floor for the frontmatter
  key Step 4 introduces? — FAIL (missing) — revised in place; R10 and Step 4
  criterion 8 now carry the obligation, with the honest admission that the
  `effort:` introduction version could not be determined locally (only
  2.1.277-2.1.281 installed) and that reporting that plainly is acceptable
  while shipping unchecked is not.
- CHK17: Does the plan say whether the stale `2.1.178` floor statements outside
  its own steps are in or out of scope? — FAIL (missing) — revised in place;
  R10 scopes the correction to files the steps already touch and the new
  Out of Scope section names the six-surface reconciliation as a separate unit.
- CHK18: Is the sequencing dependency stated precisely enough that a
  dispatcher can evaluate it without re-investigating? — PASS (R1 now names
  three checkable conditions — the `.pass` marker, a clean tree for the 19
  files, and reading the then-current version rather than a recorded one — and
  records that the collision is hunk-level, not merely file-level).
- CHK19: Do the plan's version-bump obligations agree about which baseline to
  bump from? — PASS (R1, Step 2 criterion 7 and Step 4 criterion 6 all say
  *then-current*; no step names a target version. The formerly-recorded
  "already at 0.31.75" was the one stale assertion and is removed).

## Scribe update hint

On completion: two ADRs (numbers assigned at execution time by incrementing
from the then-highest, currently 0031 — never backfill the 0007 hole);
`CONTEXT.md` entries for **effort tier**, **Bash output cap**, **effort
floor**; a CHANGELOG entry per version-stamped step. `docs/trust-model.md` is
**not** touched — no hook script lands (R5).

Two boundaries for the scribe specifically. First, **do not opportunistically
reconcile all six version-floor statements** (R10) — only the copies in files a
step already touches are in scope; the rest are a named separate unit in Out of
Scope, and sweeping them here would silently widen this spec. Second, the
CHANGELOG entry for the effort step may claim only what Step 4 criterion 4's
empirical pin actually observed: if inheritance was not observed, write that the
key is *declared*, not that effort is *demonstrably* floored (R7, and the
sibling unit's DEFECT 3 — shipped prose asserting an effect that does not
occur — is precisely the failure this avoids).

## Handoff

**The spec is locked and dispatch-ready.** 6 steps → ≥6 units → **standard
path**; it does not qualify for the ≤5-unit fast path, so `task-master` owns
slicing via `to-tickets`, per-unit `Suggested model` tagging, the retrieval
contract, and the per-unit dispatch prompts. No further `spec-master` input is
needed unless a unit surfaces a genuine spec gap, which routes back up here
rather than being decided in flight.

**Sequencing dependency for `task-master` to evaluate at dispatch time
(R1)** — carried forward deliberately, not resolved here:

- Steps 1, 2 and 6 have **no collision** and may be dispatched immediately.
  Step 1 creates two new files; Step 2 touches `templates/`, `bin/cli.js`, a
  test, `CHANGELOG.md` and the two version files; Step 6 touches `docs/adr/`
  and `CONTEXT.md`. None overlaps the sibling unit's 19 files except the
  version/CHANGELOG pair, which every version-stamped step contends for
  anyway and which R2's ordering already governs.
- **Steps 3, 4 and 5 are blocked** until `cache-ttl-gapped-personas` lands a
  PASS-reviewed commit. Step 4 in particular collides at **hunk** level, not
  just file level: the sibling edits the same two frontmatter blocks within a
  line or two of where Step 4 adds `effort:`. Step 5 touches
  `agents/orchestrator.md` and the adapter ports, which overlap the sibling's
  mirror regeneration.
- Check three things before dispatching any of 3/4/5: a
  `cache-ttl-gapped-personas` PASS marker exists; the working tree is clean of
  that unit's 19 files; and the **then-current** version in both version files
  is read fresh rather than taken from this document (the baseline has already
  moved 0.31.74 → 0.31.75 → 0.31.76-pending, so any recorded number is stale
  by construction).
- If the sibling's final landed file set turns out to differ from the 19 files
  recorded in R1 — for instance if its fix also touches a version-floor surface
  beyond `.claude-plugin/plugin.json` — treat the difference as a dispatch-time
  input to Steps 3/4/5's affected-file lists and to R10's scoping, and escalate
  to `spec-master` only if a step's affected-file list becomes wrong rather
  than merely narrower.
