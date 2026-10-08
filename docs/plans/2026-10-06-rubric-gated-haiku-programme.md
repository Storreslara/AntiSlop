# Rubric-gated haiku programme: outcome export, contract rubric, replay gate (2026-10-06)

Status: FINAL (standard path, 19 units in 6 stages, including addendum unit U0-4 and follow-up U0-2b; Stage 5 is gated and must
not be sliced until gate G4 opens). Input artifact:
`docs/research/dream-irs-taskmaster-specmaster.md` (cited by section, not
repeated; §8.2 census, §8.3 rubric R1-R7 and policies pi-0/pi-1/pi-2, §8.4
contract moves, §8.5 change table, §8.7 shortlist, §8.8 open questions).
Note: that file is untracked at the time of writing (`?? docs/research/`); it
must be committed before Stage 0 dispatch or every citation below dangles in a
fresh clone (R9).

Superseded in part (2026-10-08): Stage 5 (U5-1..U5-3 and the Draft ADR) is superseded by docs/plans/2026-10-08-haiku-default-tier.md and its ADR (*-implementer-tier-haiku-default.md); Stage 4 (U4-1..U4-3) is parked and not dispatched; gate G4 was overridden by the user on 2026-10-08. Stages 0-3, the exporter, the contract rubric and gate G3's query stay in force.

## Goal

The user's goal: task-master does all the thinking; lead-programmer and scribe
run on the lightest workable model (haiku); task-master slices specs into
literal chunks a lightweight model can execute. User decisions: policy is
**pi-2, rubric-gated haiku with ladder haiku -> sonnet -> opus** (not flat
haiku); sequencing is **tier-neutral rubric first** so the contract effect is
measured apart from the model effect, and the tier changes only after a replay
score favours pi-2 over the incumbent.

| Goal clause | Unit(s) | Criterion |
|---|---|---|
| Unit outcomes are replayable (range, tiers, attempts, reviewer tier, FAIL classes, contract score) | U0-1, U0-2, U0-3 | AC0-1.*, AC0-2.*, AC0-3.* |
| (addendum 2026-10-06) spec-master and task-master run with `maxTurns: 120` and are told to write early, in few large writes | U0-4 | AC0-4.* |
| ADR-0026 forward rule is closed as an audit record | U1-1 | AC1-1.* |
| spec-master's criteria are replayed against recorded FAIL classes (S1) | U2-1 | AC2-1.* |
| Debug specs / convergence follow-ups keep the incumbent criterion as a non-regression baseline (S2) | U2-2 | AC2-2.* |
| Dispatch contracts are content-typed and carry every mechanical obligation, tier-neutrally (R1-R7; critic 1, 2, 7, 14, 15) | U3-1 | AC3-1.* |
| Slicing rules: tracker-skill precedence, sibling collisions, contract home/precedence, spec-gap state, commit messages (critic 5, 6, 9, 10, 11) | U3-2 | AC3-2.* |
| scribe has its own contract shape and follows it over its own judgment (critic 12, 3) | U3-3 | AC3-3.* |
| lead-programmer follows the contract over its own judgment duties (critic 3) | U3-4 | AC3-4.* |
| The contract effect is measured before any tier change | gate G3 | G3 query |
| pi-2 is scored against the incumbent on fixed history | U4-1, U4-2, U4-3 | AC4-*.* |
| Only a favourable score opens the tier change | gate G4 | G4 |
| (gated) haiku becomes a rubric-gated tag with the haiku -> sonnet -> opus ladder (critic 4) | U5-1, U5-2, U5-3 | AC5-*.* |
| (gated) haiku routing is fail-closed on the contract score; hook/scribe gating decided (critic 8) | U5-3 | AC5-3.* |

Terminology: this plan says **dispatch contract** for the nine-element prompt
task-master writes (agents/task-master.md:85-107). It never says "dispatch
packet": `docs/harness-glossary.md:2939` defines that term as an eval-case
artifact. **Contract rubric** = R1-R7 as made literal by U0-1. **Contract
score** = the scorer's 0-7 output. **Rubric era** = units whose contract was
written by task-master after U3-1's PASS commit.

## Context

### Verified facts (2026-10-06, HEAD b2da3cc)

- `bin/cli.js:338` `IMPLEMENTER_MODEL_TIERS = ['sonnet', 'opus']`;
  `templates/persona-config.schema.json:56` enum `["sonnet","opus"]`;
  `.claude/persona-config.json` has `defaultImplementerModel: "sonnet"`,
  `dispatchHygiene.mode: "warn"`, `gatedAgents: ["lead-programmer"]` (scribe is
  not gated, so H4 never inspects a scribe dispatch).
- Frontmatter (at b2da3cc; U0-4 later raised spec-master and task-master to `maxTurns: 120`): task-master `model: sonnet`, `effort: medium`, `maxTurns: 40`;
  lead-programmer `model: sonnet`, `maxTurns: 50`; scribe `model: haiku`;
  spec-master `model: opus`. `agents/orchestrator.md:454` excludes `fable` for
  task-master (kept by this plan; see Constitution check and Stage 5).
- `tests/writer-tier-consistency.test.js` pins: AC-D5 the literal
  `` `sonnet` is\n  the default for every unit`` in agents/task-master.md (line
  break included), `model: sonnet` in lead-programmer source and mirror, the
  README row, and CONTEXT.md's `` `sonnet`→`opus` on re-attempt``; AC-D6 bans
  "looks mechanical" in task-master/orchestrator/lead-programmer; AC-D7 requires
  "Sonnet units escalate on first FAIL"; AC-D8 pins ADR-0026's forward rule;
  AC-D9 bans `haiku|sonnet|opus`, `haiku → FAIL` (whitespace-stripped) in
  orchestrator.md; AC-D9b requires orchestrator/task-master vocabulary agreement.
  Both tier tests pass at HEAD (run 2026-10-06).
- `resolveDefaultImplementerModel` has no production caller; the orchestrator
  prose (agents/orchestrator.md:415-427) is the live resolution path
  (`.fail` record item18-1). A config value of `haiku` resolves to `opus`
  (tests/default-implementer-model.test.js:70).
- Version-stamped paths (hooks/scripts/version-stamp-check.sh:61,92):
  `agents/*.md`, `templates/*`. Every commit touching one bumps
  `.claude-plugin/plugin.json` **and** `package.json` (validate.sh:92 asserts
  equality; `.fail` spec2-unitD defect 1) and adds a CHANGELOG `[Unreleased]`
  entry, same commit (constitution P3, v1.1.0). Current version 0.31.122.
- Mirrors `.claude/agents/*.md` and `.claude/persona-config.json` `fileHashes`
  are regenerated only by `node bin/cli.js --update` (config is Set A:
  harness-integrity-gate blocks direct writes; also blocks Bash text that
  merely names Set A files, observed 2026-10-06). `agents/` and `bin/cli.js`,
  `tests/validate.sh` are reviewer-tier `SENSITIVE_PATHS`: those units always
  draw an opus reviewer.
- Recoverable history: 609 entries under the reviewed-marker directory; ≥200
  GitHub issues contain an `Ordered edits` section (durable historical
  contracts); 40 plans carry inline `### Unit:` contracts; the transcript store
  `~/.claude/projects/-home-sebas-AntiSlop/` spans 2026-09-01..2026-10-06 only
  (pruned ~30 days). Subagent `*.meta.json` carries `model` only when an
  override was passed (424 of 697 metas); absent means frontmatter default.
  No audit log records the reviewer tier or the dispatch prompt
  (`dispatch-audit.log` lines are `<ts> warned=H4 target=...`).
- `skills/to-tickets/SKILL.md` is vendored verbatim (line 5); line 33 sizes
  slices to "a single fresh context window", line 105 says to avoid file paths
  and code snippets. It must not be edited (vendor resync); precedence is
  stated in task-master.md instead.
- `agents/task-master.md:109-114` tells task-master never to paste artifact
  bodies. That conflicts with literal before/after edits (critic 1); U3-1
  reconciles it: literal *edit payloads* are required, *artifact bodies*
  (whole files, logs, specs) stay banned.

### Prior FAIL history on the touched surfaces (durable evidence, R8)

- `spec2-unitD` (the ADR-0026 unit itself): package.json not bumped with
  plugin.json; AC-D5 missed CONTEXT.md; AC-D8 unpinned. Every persona unit here
  carries the package.json bump and a CONTEXT.md check where tiers are named.
- `item18-1-add-config-field`: orchestrator prose stated the wrong fallback
  direction; the function nobody calls was right. Stage 5 treats the prose as
  production code.
- `item13-1-measure-split-cost`, `item04-1-measure-footprint` (hit the 2-FAIL
  cap): measurement units FAILed because the number was the deliverable and the
  report miscounted. U0-3, U1-1, U4-3 are measurement units; each criterion
  re-derives every reported number from a committed command.
- Marker-note sweep (`bash bin/marker-audit.sh . --notes --surface=<path>` over
  agents/task-master.md, spec-master.md, orchestrator.md, lead-programmer.md):
  no `NOTE[spec]` lines. Untagged notes all name already-dispatched units.
  Disposition: the gh-209 note "the nine-element contract does not scope whether
  it applies to scribe" is adopted by U3-3; the rest are historical and need no
  action. The sweep over the remaining surfaces did not finish in 120 s; it is
  best-effort, and an empty result proves nothing.
  The completed sweep found one `NOTE[spec]` (item06-3-ac-d9-hardening): AC-D9's
  banned-literal checks deliberately use stripWhitespace (strip-all, not
  collapse). Disposition: U5-2 keeps stripWhitespace for every rewritten AC-D9
  assertion, and no new banned-literal check may use collapse-to-space.

### Draft ADR (for Stage 5; scribe numbers and lands it in U5-1)

Title: *Implementer tier: rubric-gated haiku tag (amends ADR-0026)*. Passes all
three ADR tests (hard to reverse once units ship on haiku; surprising given
ADR-0026 decision 3 and dampeners plan Unit D's on-record rejection of
"haiku for task-master-tagged mechanical units"; real trade-off pi-0/pi-1/pi-2).
Decision: default stays `sonnet` (lead-programmer frontmatter and
`defaultImplementerModel` unchanged); task-master may tag `Suggested model:
haiku` only when the unit's contract scores 7/7 and the unit has no `.fail`
record; the orchestrator re-scores before dispatch and routes to `sonnet` on
any score below 7. Ladder: haiku FAIL -> sonnet; sonnet FAIL -> 2-FAIL cap
(count unchanged); opus is reached through the cap's human option (a) debug
spec, as today (agents/orchestrator.md:407-410). A haiku `.fail` found in a
fresh session (failed tier not recorded) -> `opus`, the fail-closed direction.
Why it differs from what Unit D rejected: eligibility is a mechanical property
of the contract task-master wrote (scored), not a judgment of difficulty.
Cites: U1-1 audit (with its human spirit ruling) and U4-3 replay verdict.
Reviewer-tier gate (ADR-0009) and the reviewer-gate ratchet are unchanged.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-10-06 Functional scope & success criteria: Q flat haiku (pi-1) or rubric-gated haiku (pi-2)? → A: pi-2 with ladder haiku -> sonnet -> opus, per user
- 2026-10-06 Functional scope & success criteria: Q change tier and rubric together, or rubric first? → A: tier-neutral rubric first; tier changes only after a favourable replay, per user
- 2026-10-06 Functional scope & success criteria: Q does Stage 5 add `haiku` to the `defaultImplementerModel` enum / `IMPLEMENTER_MODEL_TIERS`? → A (self-resolved): no. Under pi-2 haiku arrives only as a per-unit tag; an enum entry would enable pi-1 through config, which the user rejected. A config `haiku` keeps resolving to `opus`, now asserted as intended
- 2026-10-06 Domain entities / data model: Q are outcome exports tracked or per-clone? → A (self-resolved default, confirm via Open Question 1): tracked, derived-only snapshot under `docs/audits/unit-outcomes/`, carrying class labels and ids and no prompt or defect prose. Transcripts prune at ~30 days, so a per-clone export loses the replay pool for good
- 2026-10-06 Domain entities / data model: Q what is the unit's commit range when no packet recorded it? → A (self-resolved): baseline = parent of the oldest commit whose subject scope is `(<task-id>)`; `range_source` records `commit-scope|none`
- 2026-10-06 Non-functional attributes: Q do literal before/after payloads break H1/H2 budgets (critic 14)? → A (self-resolved): H2 is per fenced block, so an edit over 80 lines is split into several edits; H1 (30000 bytes) is the binding limit. A contract that cannot fit is a split signal (pathfinder), and the scorer reports bytes and the largest block
- 2026-10-06 Non-functional attributes: Q is task-master's 40 turns / effort medium enough for literal contracts at ≥6 units (critic 13)? → A (self-resolved, SUPERSEDED same day): measure at G3 and raise only after a cutoff
- 2026-10-06 Non-functional attributes: Q what is the turn cap for the planning personas? → A: raise to 120 unconditionally, per user (addendum). Scope default: BOTH spec-master and task-master, and no other persona (the user named no persona; one-line confirmation point, Open Question 5). `effort` is unchanged. G3 still reports task-master cutoffs, as information only
- 2026-10-06 External dependencies & integrations: Q may the vendored `to-tickets` skill be edited (critic 5)? → A (self-resolved): no (vendored verbatim). task-master.md states its precedence over to-tickets' user interaction, its no-paths rule and its context-window sizing
- 2026-10-06 Edge cases / failure handling: Q what state does a spec gap leave a partial slice in (critic 10)? → A (self-resolved): published issues stay; the gap unit and every unit transitively depending on it are not published; task-master's report ends with a `Slice state:` table (unit, published|held, reason). Re-invocation resumes from that table
- 2026-10-06 Edge cases / failure handling: Q who closes the ADR-0026 forward check, and is ≈30% vs 32.5% "fallen below" in spirit? → A (default, Open Question 2): U1-1 records the measured numbers and the letter result; the line `spirit-ruling: PENDING-HUMAN` stays until the user rules. Stage 5 cannot open while it reads PENDING-HUMAN
- 2026-10-06 Edge cases / failure handling: Q under the 2-FAIL cap, where is opus on the haiku ladder? → A (self-resolved): cap count unchanged (research §8.5); haiku -> sonnet uses both slots; opus via cap option (a) as today
- 2026-10-06 Technical constraints & tradeoffs: Q must H4 move from warn to block before haiku dispatch (critic 8)? → A (default, Open Question 3): no global flip (it would also arm H1-H3 blocking). Instead U5-3 makes haiku routing fail-closed on the scorer
- 2026-10-06 Technical constraints & tradeoffs: Q which incumbent must pi-2 beat? → A (default, Open Question 4): the better of pi-0 (pre-rubric sonnet) and pi-0' (rubric-era sonnet), so the model effect is isolated from the contract effect
- 2026-10-06 Terminology consistency: Q "packet" / "dispatch packet" / "haiku-safe"? → A (self-resolved): "dispatch contract", "contract rubric", "contract score"; "dispatch packet" is reserved by docs/harness-glossary.md:2939 for eval artifacts
- 2026-10-06 Completion / acceptance signals: Q what counts as a favourable replay? → A (default, Open Question 4): pre-registered rule in U4-2 (non-inferiority on shadow re-execution, cost ≤ incumbent, cap-hit rate ≤ incumbent, minimum N); anything else is `not-favourable` or `insufficient-evidence`, and both keep Stage 5 closed

## Risks / dependencies

- R1 Historical contracts predate the content-typed format and will mostly score
  below 7. That is expected: the score measures the new convention. Stage 4
  therefore takes its haiku evidence from shadow re-execution of rubric-era
  contracts (U4-1), not from historical scores.
- R2 Small N and confounds (research §8.2, §8.6). The G3/G4 minimums are
  pre-registered here, before any data is seen; a result under the minimum is
  `insufficient-evidence`, never "close enough".
- R3 Stage 3 raises task-master cost and turn use (critic 13). Measured at G3.
- R4 Shadow re-execution (U4-1) runs lead-programmer headless in a throwaway
  git worktree. It must write no marker, flag or audit line in the main
  checkout. AC4-1.3 proves it. If the probe shows hooks write to the main
  checkout, U4-1 stops and reports; it does not route around a gate.
- R5 Bash criteria must not spell Set A log names or the reviewed-marker
  directory (both gates scan command text). Scripts default those paths
  internally, and tests use fixture dirs under `tests/fixtures/` whose names
  contain neither string.
- R6 Stage 3 must not trip the tier tests: keep the AC-D5 literal line in
  task-master.md byte-identical, and never write "looks mechanical" (AC-D6).
  AC3-1.6 checks both.
- R7 Fast-path contracts (≤5-unit specs) are written by spec-master, not
  task-master, and are not rubric-bound by Stage 3. The exporter records
  `contract_author`, and G3/G4 count task-master-authored units only. Extending
  the rubric to spec-master's fast path is parked (Out of scope).
- R8 Prior FAIL history above: U0-3, U1-1, U4-3 are measurement units with a
  2-FAIL-cap precedent. task-master must not tag them below the default tier.
- R9 `docs/research/dream-irs-taskmaster-specmaster.md` is untracked; whoever
  owns it commits it before Stage 0 (not done here: not this persona's file).
- R10 Any unit editing agents/*.md lands, in ONE commit: the edit, the
  plugin.json + package.json bump, a CHANGELOG entry, and the
  `node bin/cli.js --update` output (precedent 712b23b; revised 2026-10-06, gap
  D). Bump before `--update`. Stage the output with `git add -u -- .claude`,
  never by spelling the config's file name in Bash. See "Persona-unit scope
  rule".

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every measurement criterion re-derives its numbers from a committed command, and the replay stage includes a real re-execution arm.
- P2 "Prefer deterministic scripts": satisfied. Mirrors and `fileHashes` change only via `node bin/cli.js --update`, the Set A config is never hand-edited, and scoring and export are scripts, not LLM re-derivation.
- P3 "Version-stamp discipline": satisfied. Every unit touching `agents/*.md` (U0-4, U2-1, U2-2, U3-1..U3-4, U5-2, U5-3) bumps plugin.json and package.json and adds a CHANGELOG entry in the same commit, checked by `version-stamp-check.sh <baseline>..HEAD` = `ok`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. New prose naming task-master, scribe or reviewer in shipped persona files is conditionally phrased ("if present"); AC3-3.5 and AC3-4.4 check it.
- P5 "tests/validate.sh is the merge gate": satisfied. Every code or persona unit's criteria include `bash tests/validate.sh` exit 0, and new tests are registered there.

## Stages and gates

| Stage | Units | Gate to leave the stage |
|---|---|---|
| 0 Outcome export (+ addendum) | U0-1, U0-2, U0-3, U0-4 | G0: all four PASS; snapshot committed (or per-clone, per OQ1). U0-4 has no dependency on the exporter or on any gate |
| 1 Forward-rule audit | U1-1 | G1: audit committed. Does not block Stages 2-4; blocks Stage 5 while `spirit-ruling: PENDING-HUMAN` |
| 2 spec-master S1+S2 | U2-1, U2-2 | G2: both PASS (prerequisite for R3 criteria quality) |
| 3 Tier-neutral contract rubric | U3-1..U3-4 | G3: `node scripts/unit-outcomes.js --gate=G3` prints `G3 open` (≥60 rubric-era task-master-authored units at PASS or cap, ≥20 of them scoring 7/7 under their own `rubric_version`, task-master cutoffs reported; amended 2026-10-06 by the user's ruling, see Gate G3) |
| 4 pi-2 replay | U4-1, U4-2, U4-3 | G4: `docs/audits/<date>-pi2-replay.md` line `verdict: favourable` AND G1 ruling is not PENDING-HUMAN |
| 5 (GATED) Tier change | U5-1, U5-2, U5-3 | none: programme end |

Persona-file serial order and version strings (fixed 2026-10-06; assumes HEAD
is at 0.31.122 and nothing else bumps in between). U0-4 goes FIRST and shifts
the others by one:

| Order | Unit | Sets version |
|---|---|---|
| 1 | U0-4 | 0.31.123 |
| 2 | U2-1 | 0.31.124 |
| 3 | U2-2 | 0.31.125 |
| 4 | U3-1 | 0.31.126 |
| 5 | U3-2 | 0.31.127 |
| 6 | U3-3 | 0.31.128 |
| 7 | U3-4 | 0.31.129 |

U2-1 and U3-1 each depend on U0-4. If any other unit bumps the version first,
each later unit's literal becomes (HEAD version + 1), and the orchestrator
re-derives it in the contract before dispatch. The already-published #496
(U2-1) and #497 (U2-2) must be amended from 0.31.123/0.31.124 to
0.31.124/0.31.125 and gain `Depends on: U0-4`.
Non-persona units (U0-1, U0-2, U0-3, U1-1) set no version and can interleave.

Dispatch order: U0-4 -> U0-1 -> U0-2 -> U0-3 -> {U1-1, U2-1 -> U2-2} -> U3-1 -> U3-2 ->
U3-3 -> U3-4 -> [wait G3] -> U4-1 -> U4-2 -> U4-3 -> [wait G4] -> U5-1 -> U5-2 ->
U5-3. task-master slices Stages 0-3 now; it is re-invoked for Stage 4 at G3
and for Stage 5 at G4. Same-file units are serialized by `Depends on` edges
(U0-4 before U2-1 on spec-master.md and before U3-1 on task-master.md, since all touch the same files; U2-1/U2-2 on spec-master.md; U3-1/U3-2/U3-3 on task-master.md; U5-2/U5-3 on
orchestrator.md).

Every criterion below runs from the repo root. `<B>` is the unit's baseline SHA
(the commit before its first commit). "Flattened grep" means
`tr '\n' ' ' < FILE | tr -s ' ' | grep -cF 'PHRASE'`, so a hard wrap cannot
make a phrase check pass vacuously.

## Persona-unit scope rule (uniform; gap D, 2026-10-06)

Applies to every unit that edits `agents/*.md`: U0-4, U2-1, U2-2, U3-1, U3-2,
U3-3, U3-4, U5-2, U5-3. It replaces every "only these files changed" check in
those units.

After a version bump, `node bin/cli.js --update` re-stamps every mirror. Its
complete expected output set is these 14 `.claude/` paths. task-master lists
them verbatim in each contract's Affected files, but never spells the config's
name inside a `run:`/`command:`, because harness-integrity-gate refuses any Bash
text naming it:
`.claude/agents/agent-auditor.md`, `.claude/agents/explorer.md`,
`.claude/agents/lead-programmer.md`, `.claude/agents/milestone-auditor.md`,
`.claude/agents/orchestrator.md`, `.claude/agents/researcher.md`,
`.claude/agents/reviewer.md`, `.claude/agents/scribe.md`,
`.claude/agents/spec-master.md`, `.claude/agents/task-master.md`,
`.claude/persona-config.json`, `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`.
Only the unit's OWN mirrors change in content. The other mirrors change only
their first-line stamp (`<!-- antislop vX.Y.Z | source: ... -->`), and the
config changes `pluginVersion` and `fileHashes`.

Three checks, with `<OWN>` = the unit's own source files (table below):
- AC-SCOPE-1 (non-.claude files): `git diff --name-only <B>..HEAD | grep -v '^\.claude/' | sort` equals, line for line, the sorted list of `<OWN>` + `.claude-plugin/plugin.json` + `CHANGELOG.md` + `package.json` + the unit's extra files from the table.
- AC-SCOPE-2 (.claude count): `git diff --name-only <B>..HEAD -- .claude | wc -l` = 14.
- AC-SCOPE-3 (the others are stamp-only): `git diff -U0 <B>..HEAD -- .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/protocol-digest.md ':(exclude).claude/agents/<name>.md' [one exclude per own mirror] | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | grep -cvE '^[-+]<!-- antislop v[0-9]+\.[0-9]+\.[0-9]+ \| source: '` prints `0`.
  Proven on 712b23b (ocigf-2): with `':(exclude).claude/agents/orchestrator.md'`
  it prints 0, and without the exclusion it prints 5 (non-vacuous). The config
  is not diffed line-wise, since naming it in Bash is refused; its `fileHashes`
  are covered by `bash tests/validate.sh`'s mirror-parity checks.

| Unit | `<OWN>` | Extra non-.claude files |
|---|---|---|
| U0-4 | `agents/spec-master.md`, `agents/task-master.md` | none |
| U2-1, U2-2 | `agents/spec-master.md` | none |
| U3-1, U3-2 | `agents/task-master.md` | none |
| U3-3 | `agents/task-master.md`, `agents/scribe.md` | none |
| U3-4 | `agents/lead-programmer.md` | `adapters/codex/agents/lead-programmer.toml`, `adapters/cursor/agents/lead-programmer.md` |
| U5-2 | `agents/task-master.md`, `agents/orchestrator.md` | `CONTEXT.md`, `tests/writer-tier-consistency.test.js` |
| U5-3 | `agents/orchestrator.md` | none (unless OQ3 = block) |

If a unit spans several commits, the checks run over the whole `<B>..HEAD`
range, and AC-SCOPE-2 still expects 14.

## Step U0-1: contract scorer `bin/contract-score.js`

Affected files: `bin/contract-score.js` (new, ships in npm `files`),
`tests/contract-score.test.js` (new), `tests/fixtures/contract-score/*.md`
(new), `tests/validate.sh` (register test, appended block in the same style as
lines 855-858).

Behaviour: read one contract (file argument, or `-` for stdin). `--shape=lead`
is the default; `--shape=scribe` is the alternative. Print exactly one JSON line
`{"shape":..,"score":N,"rows":{"R1":bool,..},"bytes":N,"maxBlockLines":N,"sizeOver":bool}`
and exit 0. Exit 2 when the input is unreadable. Sections are located by
`^## <Name>` headings. Lead-shape rows (literal rules, content-typed per critic 1):
- R1: every `^\d+\. ` item under `## Ordered edits` carries `file:` with a
  backticked path, `anchor:` non-empty, and one payload form: `before:`+`after:`,
  `insert-after:`+text, or `delete:`+text. Each payload is inline code or a fenced
  block. **Command items (Gap B, 2026-10-06):** an item may instead carry
  `command:` (inline code) plus `expect:` (an integer exit code, optionally
  followed by `stdout:` with a fragment); it needs no `file:`/`anchor:`. This
  form is how the contract orders `node bin/cli.js --update`, `git commit -F`,
  and the like. A command item that lacks `expect:` makes R1 false. R1 is false if the section matches
  `/as specified|see the (plan|issue|spec)|to reflect|as appropriate|as needed|update accordingly/i`.
- R2: if any `## Affected files` path matches `^agents/[^/]+\.md$|^templates/`,
  the contract contains `.claude-plugin/plugin.json` and `package.json` each on a
  line with a semver, `CHANGELOG.md` with an entry payload, the literal
  `node bin/cli.js --update`, and a criterion running `version-stamp-check.sh`.
  Otherwise R2 = true (n/a).
- R3: every `^\d+\. ` item under `## Acceptance criteria` has `run:` (inline
  code), `exit:` (integer), `stdout:` (non-empty fragment or the literal
  `empty`), and `mutation:` (non-empty).
- R4: no `run:` contains `/home/`, `/tmp/`, `~/` or `$HOME`. If any `run:`
  contains `command -v` or `which `, a `precondition:` item exists.
- R5: `## Pre-resolved context` has `tdd:` (`yes <path>` or `no <reason>`),
  `blast-radius:` with ≥1 `path:line` token or the literal `none`, and
  ≥1 `commit-message:` line.
- R6: `## Do NOT touch` has ≥2 bullets, each starting with a backticked path.
- R7: `## Pre-resolved context` has the line `diagnosis: none`.
Scribe-shape rows (critic 12): required non-empty sections `## Glossary edits`
(each item: `file:`, `heading:`, `text:`), `## ADR` (`\d{4} <title>` or `none`),
`## Close conditions` (issue `#\d+`, task-id, quoted marker first line),
`## Do NOT touch`, `## Acceptance criteria` (same item rule as R3); score = rows
true out of 5.

Acceptance criteria:
- AC0-1.1 `node tests/contract-score.test.js` exit 0, with last line `All contract-score checks passed.`
- AC0-1.2 Mutation-proof inside the test: `tests/fixtures/contract-score/all-pass.md` scores 7. For each row Rn there is a fixture `minus-Rn.md` that differs from all-pass by one edit and scores 6 with only `Rn` false (7 assertions; reverting any one rule to `true` fails the suite). Same for the scribe shape (5 fixtures).
- AC0-1.3b `all-pass.md` contains a command item (`command:` `node bin/cli.js --update`, `expect: 0`); a fixture `minus-R1-command.md` drops only its `expect:`, and its R1 is false.
- AC0-1.3 A fixture whose Ordered edits read "as specified in the plan" scores R1 false (critic 1's pointer-body case).
- AC0-1.4 `node bin/contract-score.js tests/fixtures/contract-score/oversize.md` prints `"sizeOver":true` (a 31000-byte fixture with an 81-line block).
- AC0-1.5 `bash tests/validate.sh` exit 0 and `grep -c 'contract-score.test.js' tests/validate.sh` ≥ 1.

## Step U0-2: outcome exporter `scripts/unit-outcomes.js`

Affected files: `scripts/unit-outcomes.js` (new; maintainer-only, not shipped),
`tests/unit-outcomes.test.js` (new), `tests/fixtures/unit-outcomes/`
(new: `markers/`, `transcripts/`, a scratch git repo built by the test),
`tests/validate.sh` (register).

Behaviour: read-only. Flags `--markers=<dir>` and `--transcripts=<dir>` default
to the repo's marker dir and `~/.claude/projects/<slug>/`; `--repo=<dir>`
defaults to cwd; `--out=<file>`; `--gate=G3`; `--until=<ISO-8601 UTC>` (Gap A).
`--until` semantics: a unit is included only if its **terminal event** is at or
before the cutoff. The terminal event is the first-line timestamp of its PASS
marker; for a unit with no PASS and ≥2 FAIL blocks (cap), it is the header
timestamp of the second FAIL block. Timestamps come from file content, never
from mtime. Units with neither (in flight) are excluded. For included units,
FAIL blocks, transcript records and commits after the cutoff are ignored.
Cap handling: `cap_hit` = FAIL-block count ≥ 2 (counted up to the cutoff);
`attempts` = FAIL blocks + (1 if a PASS exists at or before the cutoff);
`final_commit` = null when there is no PASS. Output is sorted by `id` and
carries no wall-clock field. `--until` defaults to the current time. One JSON line per unit:
`id, plan, contract_author (task-master|spec-master|unknown), contract_source
(issue#N|plan:<path>|transcript|none), contract_score (U0-1 output or null),
baseline, final_commit, range_source, implementer_tiers [{tier, source:
observed|frontmatter-inferred|era-inferred}], attempts (= FAIL blocks + 1),
reviewer_tiers [..same shape..], fail_classes [subset of: mirror, version,
vacuous, spec-gap, scope, host, unverified]` (the class regexes are research
§8.2's substrings), `cap_hit, task_master_cutoff (true|false|null)`,
`pass_ts` (the PASS marker's first-line timestamp, or null), `terminal_ts`
(`pass_ts`, or for a cap unit without a PASS the second FAIL block's header
timestamp; the same value `--until` filters on), and `fail_blocks` (integer)
(gap E, 2026-10-06). These are content timestamps, never mtime, and are not
wall-clock fields. Contract
text comes from transcripts first, then `gh issue view` bodies, then the plan's
`### Unit:` block. The output carries ids and labels only, never prompt or
defect prose.
`--gate=G3` prints `G3 open` or `G3 closed: <counts>` and exits 0.

Acceptance criteria:
- AC0-2.1 `node tests/unit-outcomes.test.js` exit 0. The fixtures cover: a unit with 2 FAIL blocks (`attempts` 3, `cap_hit` true), a meta with `model` (`observed`), one without (`frontmatter-inferred`), a commit-scope baseline, and no-range (`range_source` `none`).
- AC0-2.2 Non-vacuity: the test asserts `fail_classes` on a fixture `.fail` containing "vacuous" and "CHANGELOG" equals `["version","vacuous"]` (sorted), and a fixture with neither yields `[]`.
- AC0-2.3 Privacy: the test asserts that no output line contains any 40-character substring of a fixture prompt or defect text.
- AC0-2.3c Timestamp fields: for a fixture PASS marker whose first line reads `PASS fx-1 2026-09-01T10:00:00Z commit: ...`, the output has `pass_ts` "2026-09-01T10:00:00Z" and an equal `terminal_ts`. For the cap fixture, `pass_ts` is null, `terminal_ts` equals its second FAIL header timestamp, and `fail_blocks` is 2.
- AC0-2.3b `--until` fixtures: a unit whose PASS timestamp is after the cutoff is absent; a cap unit (2 FAIL blocks, no PASS) is present with `cap_hit` true, `attempts` 2 and `final_commit` null; a unit whose PASS file mtime is before the cutoff but whose content timestamp is after it is absent (proves content, not mtime).
- AC0-2.4 Read-only: the test snapshots `git status --porcelain` and the fixture dir checksums before and after the run, and asserts both are unchanged.
- AC0-2.5 `bash tests/validate.sh` exit 0.
- OQ1 delta: if the user chooses per-clone, the default `--out` becomes `.claude/unit-outcomes/<date>.jsonl`, the path is added to every gitignore scaffold list in `bin/cli.js` (and the unit becomes an opus-review SENSITIVE_PATHS unit), and AC0-3.1 changes to `git check-ignore` exit 0.

### U0-2b: exporter semantics amendments (2026-10-06, from #498 review notes)

These amendments supersede the conflicting U0-2 text above. They ship as a
follow-up unit **U0-2b**, dispatched after #498's PASS and before U0-3 (#504),
so the in-flight FAIL fix on #498 stays limited to its two listed code defects.
- **As-of-cutoff semantics (note 1).** Every event later than `--until` is
  ignored before anything is derived. `pass_ts` is the PASS first-line timestamp
  only if it is ≤ cutoff, else null. `fail_blocks` counts the FAIL headers
  ≤ cutoff. `terminal_ts` is the **earlier** of `pass_ts` and the second FAIL
  header (both ≤ cutoff), so a unit capped on 09-03 that passes on 09-20 has
  `terminal_ts` 09-03 at every cutoff ≥ 09-03. Inclusion is therefore monotone
  in the cutoff, and a fixed cutoff gives the same row before and after the
  PASS lands. `attempts` = `fail_blocks` + (1 if `pass_ts` is non-null);
  `cap_hit` = `fail_blocks` ≥ 2; `final_commit` = null when `pass_ts` is null.
  - AC0-2b.1 Fixture (FAIL 09-02, FAIL 09-03, PASS 09-20). At `--until=2026-09-10`: present, `pass_ts` null, `terminal_ts` 09-03, `fail_blocks` 2, `attempts` 2, `cap_hit` true. At `--until=2026-09-30`: `pass_ts` 09-20, `terminal_ts` 09-03, `attempts` 3. The 09-10 row is byte-identical whether or not the PASS file exists in the fixture.
- **Contract source order (note 2).** (1) The `~~~`-fenced block under
  `## Dispatch contract` in the unit's issue body gives `contract_author:
  task-master`. (2) Otherwise, the plan's `### Unit:` block gives
  `spec-master`. (3) Otherwise, a transcript prompt counts only if it contains
  `## Ordered edits`, with author `unknown`. A pointer dispatch ("Retrieval
  contract: gh issue view N") is never scored, and gives `contract_source: none`
  and score null. G3's "contract score" is the score of source (1): the contract
  as task-master wrote it. Since the 2026-10-06 user ruling it is scored under
  the unit's own `rubric_version` (see Gate G3; implemented by hardening unit
  H11).
  - AC0-2b.2 A fixture unit with both an issue Dispatch-contract block and a pointer transcript gets `contract_source` `issue#N`, author `task-master`, and the block's score. A pointer-only transcript gives `contract_source` `none`.
- **New field `contract_ts`.** The issue's `createdAt` for source (1), the
  plan block's first-commit date for (2), null otherwise.
- **G3 tightened (note 3).** Population: `contract_author == "task-master"` and
  `contract_ts` > U3-4's `pass_ts` (replacing the terminal_ts superset). The
  output must print the FAIL-class mix (count per class) for this population
  and for the pre-rubric sonnet era. The **pre-rubric sonnet era** is a
  complement (gap G, 2026-10-06): every unit with `terminal_ts` ≥
  "2026-08-25T00:00:00Z" that is NOT in the rubric-era population, including
  units whose `contract_ts` or `contract_author` is null or unknown. In jq:
  `select(.terminal_ts >= "2026-08-25T00:00:00Z" and ((.contract_author == "task-master" and .contract_ts != null and .contract_ts > $u34) | not))`.
  The two populations are disjoint, and their union is every sonnet-era unit.
  G3 prints `task_master_cutoffs=unmeasured` when every value is null,
  otherwise the count.
  - AC0-2b.3 Fixtures assert the `G3 open`/`G3 closed` boundary at exactly 60/20 and `unmeasured` when all cutoffs are null. For the class-mix lines, a fixture set holding one rubric-era unit (FAIL class `vacuous`), one sonnet-era unit with `contract_ts` null (class `version`), one sonnet-era unit with a task-master `contract_ts` before U3-4's PASS (class `scope`), and one pre-08-25 unit (class `host`) must print `rubric_classes=` containing only `vacuous=1`, and `pre_rubric_classes=` containing exactly `version=1` and `scope=1` (no `host`).
- **`era-inferred` rule (note 4).** Used for the implementer tier only when no
  transcript meta exists. The era is taken from the unit's earliest FAIL/PASS
  timestamp: before 2026-08-02 -> `sonnet`; 2026-08-02 up to (not including)
  2026-08-25 -> `haiku` (ADR-0010); from 2026-08-25 -> `sonnet` (ADR-0026). The
  reviewer tier is never inferred: with no meta, `reviewer_tiers` is the empty
  array `[]` (AC0-2b.4 is authoritative).
  - AC0-2b.4 Three fixtures, one per era, assert the inferred tier and `source: "era-inferred"`, and a fixture with no meta asserts `reviewer_tiers` is `[]`.
- Note only: the extra fixture file fixed in #498's commit 2 is accepted; no
  criterion change.

## Step U0-3: first outcome snapshot (measurement unit)

Affected files: `docs/audits/unit-outcomes/2026-10-NN.jsonl` (new, OQ1 default),
`docs/audits/unit-outcomes/README.md` (new: the command used, the field
dictionary, the coverage window, and the coverage table).

Acceptance criteria:
- AC0-3.1 `git ls-files docs/audits/unit-outcomes | wc -l` ≥ 2.
- AC0-3.2 Reproducibility: the README states the exact command, including `--until=<cutoff>`. Re-running that command to a scratch file and comparing `jq -cS 'del(.contract_score, .contract_source)'` of both files gives identical output (`diff` exit 0). `contract_score` must also match for every unit whose `contract_source` is not `issue#N` (issue bodies are live and can be edited after the cutoff, e.g. #496/#497).
- AC0-3.3b `jq -e 'has("pass_ts") and has("terminal_ts") and has("fail_blocks")'` holds for every line of the snapshot (`jq -s 'all(has("terminal_ts"))'` prints `true`).
- AC0-3.3 Each count in the README coverage table (units total; with contract text; with observed tier; with a range) equals `jq` over the committed JSONL, and the README lists those jq commands verbatim.
- AC0-3.4 `git diff --name-only <B>..HEAD` lists only `docs/audits/unit-outcomes/` paths.

## Step U0-4 (addendum 2026-10-06): turn caps to 120 and write-early guidance

Tier-neutral, independent of G3/G4 and of the exporter. The unit id is U0-4 so
the U0-1..U0-3 ids already being sliced do not change. Scope default (OQ5):
spec-master AND task-master only. Other personas keep their caps
(lead-programmer 50, reviewer 50, milestone-auditor 20, explorer 10,
agent-auditor 10).

Pinning survey (`git grep -n maxTurns`, 2026-10-06): the value 40 is pinned only
by `agents/spec-master.md:9`, `agents/task-master.md:12` and their mirrors.
`tests/cli-backfill.test.js:357-367` pins explorer's `maxTurns: 10` (a fixture
assumption), which is not touched. No schema, README, CONTEXT.md, glossary or
ADR cites 40 or the planning caps. `templates/persona-protocol.md:159` mentions
turn caps generically, and it stays unchanged.

Affected files: `agents/spec-master.md` (frontmatter `maxTurns:` line, plus one
guidance bullet after "Suggest saving plans to `docs/plans/YYYY-MM-DD-<slug>.md`"),
`agents/task-master.md` (frontmatter `maxTurns:` line, plus one guidance bullet
after the "Handoff on cutoff" bullet), `.claude-plugin/plugin.json` and
`package.json` (same version bump), `CHANGELOG.md` (`[Unreleased]` entry), all in
ONE commit, together with the full 14-path `node bin/cli.js --update` output
listed in the "Persona-unit scope rule" (staged with `git add -u -- .claude`,
never hand-edited; Set A).
Ordered edits (all mandatory, exact text; per the user's follow-up the
spec-master line is a firm requirement):
1. `agents/spec-master.md`, anchor: frontmatter line 9. before: `maxTurns: 40`, after: `maxTurns: 120`.
2. `agents/spec-master.md`, insert-after the line
   `` - Suggest saving plans to `docs/plans/YYYY-MM-DD-<slug>.md`. `` (line 265 at b2da3cc), as one line:
   `` - **Write early, in few large writes.** Write the plan skeleton to `docs/plans/` early in the session, then fill it in a few large writes rather than many small edits, so a turn cutoff still leaves a usable plan. ``
3. `agents/task-master.md`, anchor: frontmatter line 12. before: `maxTurns: 40`, after: `maxTurns: 120`.
4. `agents/task-master.md`, insert-before the line starting `- **Handoff on cutoff**:` (line 145 at b2da3cc), as one line:
   `` - **Write early, in few large writes.** Write the dispatch contracts early in the session and in a few large writes rather than many small edits, so a turn cutoff still leaves usable contracts. ``
Do NOT touch: any other persona's `maxTurns`, `effort:` lines, `model:` lines,
the AC-D5 literal in task-master.md, `tests/cli-backfill.test.js`.

Acceptance criteria:
- AC0-4.1 `grep -c '^maxTurns: 120$' agents/spec-master.md agents/task-master.md .claude/agents/spec-master.md .claude/agents/task-master.md` prints `:1` for all four files. At `<B>` each prints `:0`.
- AC0-4.2 `grep -c '^maxTurns: 40$'` over the same four files prints `:0` for each.
- AC0-4.3 Other caps unchanged: `git diff <B>..HEAD -- agents .claude/agents | grep -cE '^[-+]maxTurns'` = 8. Scope: AC-SCOPE-1/2/3 with the U0-4 row (AC-SCOPE-3 excludes `.claude/agents/spec-master.md` and `.claude/agents/task-master.md`).
- AC0-4.4 spec-master sentence (mandatory): `grep -cF 'Write the plan skeleton to `docs/plans/` early in the session, then fill it in a few large writes' agents/spec-master.md .claude/agents/spec-master.md` prints `:1` for both (`:0` at `<B>`). The line sits directly after the anchor: `grep -A1 -F 'Suggest saving plans to' agents/spec-master.md | grep -c 'Write early, in few large writes'` = 1.
- AC0-4.4b task-master sentence: `grep -cF 'Write the dispatch contracts early in the session and in a few large writes' agents/task-master.md .claude/agents/task-master.md` prints `:1` for both.
- AC0-4.5 `bash hooks/scripts/version-stamp-check.sh <B>..HEAD` prints a line starting `version-stamp-check: ok`. plugin.json and package.json carry the same new version (`bash tests/validate.sh` asserts equality).
- AC0-4.6 `node tests/writer-tier-consistency.test.js` exit 0, `node tests/cli-backfill.test.js` exit 0, `bash tests/validate.sh` exit 0.
- AC0-4.7 `grep -c 'maxTurns' CHANGELOG.md` is higher than at `<B>` (an entry names the change).

## Step U1-1: ADR-0026 forward-rule audit (measurement unit)

Affected files: `docs/audits/2026-10-NN-adr0026-forward-rule.md` (new).
Contents: the rule quoted from ADR-0026 lines 79-85. Sonnet-era FAIL rate from
the U0-3 snapshot, with n, defined as follows (gap E, 2026-10-06):
- **Population:** units with `terminal_ts >= "2026-08-25T00:00:00Z"` (the
  ADR-0026 ratification date; the default was `sonnet` from then on). That is
  `jq -s '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")]'` over the
  snapshot. Cap units without a PASS are included and count as FAIL. The audit
  states that a unit dispatched before 08-25 and finished after it is counted in
  the sonnet era (the same boundary effect ADR-0026's mtime basis had).
- **FAIL rate:** units with ≥1 FAIL block, divided by units in the population
  (`fail_blocks >= 1`). It is NOT FAIL blocks per attempt. This is the basis of
  the 32.5% threshold: ADR-0026 line 22 reads "203 units, 66 with FAIL records,
  32.5% FAIL rate" (66/203 = units with a FAIL record / units), and research
  §8.1's 133/424 uses the same basis. The comparison is therefore like-for-like
  in definition. The audit notes it is not like-for-like in timestamp source:
  ADR-0026 used marker mtimes, this uses content timestamps.
- For context only, the audit also reports `spend-accounting-rate:`, the
  `from 2026-08-02` row of `bash scripts/spend-accounting.sh --until=<cutoff>`
  (at `--until=2026-10-07T00:00:00Z`: 424 units, 133 FAIL, 31.4%). It is
  labelled as a **2026-08-02 boundary**, not 08-25, because the script splits
  only at 08-02. It is not compared against 32.5%. No subtraction is attempted
  (gap F, 2026-10-06). The 08-25 snapshot the research note subtracted cannot be
  regenerated: `--until=2026-08-25T00:00:00Z` returns
  `{"error": "no usage records found in corpus ..."}` because transcripts are
  pruned. The letter verdict uses only the exporter-based rate above.
A letter verdict (`met|not-met|insufficient (n<60)`). The spend half:
`spend-verdict: unverifiable`, with a `failing-command:` line giving the 08-25
run verbatim and its error output. Then the line `spirit-ruling: PENDING-HUMAN`. The
author records numbers only; the spirit ruling is the user's (OQ2).

Acceptance criteria:
- AC1-1.1 `grep -cE '^spirit-ruling: (PENDING-HUMAN|met|not-met)$' <file>` = 1.
- AC1-1.2 `grep -cE '^letter-verdict: (met|not-met|insufficient)' <file>` = 1, and `grep -c '^n-units: ' <file>` = 1.
- AC1-1.2b The `n-units:` and `fail-rate:` values equal `jq -s '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")] | length'` and `jq -s '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")] | (map(select(.fail_blocks >= 1)) | length) / length'` over the committed snapshot. The file contains the line `fail-rate-basis: units-with-any-FAIL / units (as ADR-0026: 66/203)`.
- AC1-1.3 Every numeric claim has a `reproduce:` line beneath it. The reviewer runs each one, and each must print the stated number.
- AC1-1.4 `node tests/writer-tier-consistency.test.js` exit 0 (AC-D8 still pins the rule; ADR-0026 is untouched: `git diff --quiet <B>..HEAD -- docs/adr` exit 0).

## Step U2-1: spec-master S1, criteria replay against FAIL classes

Affected files: `agents/spec-master.md` (Self-check bullet: insert directly
after the hard-wrapped sentence that ends "each MUST principle." at
agents/spec-master.md:156 at 7bf93d9, before "An item passes"; the line number
is unchanged by U0-4, whose edits sit at line 9 and after line 265), `.claude-plugin/plugin.json`,
`package.json`, `CHANGELOG.md`, then `.claude/agents/spec-master.md` and the
config `fileHashes` via `node bin/cli.js --update`.

Text to insert (pinned): "**Replay source.** When `docs/audits/unit-outcomes/`
exists, add one CHK item per step whose affected files appear in a recorded
unit with FAIL class `vacuous` or `host`: \"Does criterion <ACn> still fail
under the mutation recorded for <unit-id>?\" The item cites the unit id. An
absent or empty export proves nothing and adds no item."

Acceptance criteria:
- AC2-1.1 Flattened grep of `agents/spec-master.md` for `**Replay source.**` = 1, and for `An absent or empty export proves nothing` = 1. Both are 0 at `<B>`.
- AC2-1.2 `cmp agents/spec-master.md .claude/agents/spec-master.md` is not used (the mirror carries the inlined block). Instead: flattened grep of `.claude/agents/spec-master.md` for `**Replay source.**` = 1.
- AC2-1.3 `bash hooks/scripts/version-stamp-check.sh <B>..HEAD` prints a line starting `version-stamp-check: ok`.
- AC2-1.4 `node tests/writer-tier-consistency.test.js` exit 0, and `bash tests/validate.sh` exit 0.
- AC2-1.5 AC-SCOPE-1/2/3 (U2-1 row).

## Step U2-2: spec-master S2, incumbent non-regression for debug specs and convergence follow-ups

Affected files: as U2-1. Single insertion, in item 2 ("Revised spec step(s)") of
the debug-spec bullet. The pinned text's last sentence already covers
Convergence follow-ups, so the `**Convergence follow-ups**` bullet goes under
Do NOT touch (confirmed 2026-10-06). Depends on U2-1.

Text to insert (pinned): "**Incumbent baseline.** The revised step carries a
table with one row per defect block in `.claude/reviewed/<task-id>.fail`
(columns: block timestamp, defect, revised criterion that detects it, original
criterion kept as baseline). A row with no detecting criterion is a Self-check
FAIL. Convergence follow-ups carry the same table for each named finding."
(Authoring note for task-master: spell the marker-dir path in the contract via
an anchor and do not put it in a `run:` command; the reviewed-path gate scans
Bash text.)

Acceptance criteria:
- AC2-2.1 Flattened grep of `agents/spec-master.md` for `**Incumbent baseline.**` = 1, and for `A row with no detecting criterion is a Self-check FAIL` = 1.
- AC2-2.2 The same two greps against `.claude/agents/spec-master.md` = 1 each.
- AC2-2.3, AC2-2.4, AC2-2.5 as AC2-1.3, AC2-1.4, AC2-1.5 (U2-2 row).

## Step U3-1: task-master contract rubric, tier-neutral (critic 1, 2, 7, 14, 15)

Affected files: `agents/task-master.md` (the "Per-unit dispatch prompts" bullet,
lines 85-114 at b2da3cc), bump files, CHANGELOG, mirror via `--update`.
Do NOT touch: the `Per-unit model tag` bullet (lines 55-69) and the AC-D5 literal
inside it.

Content: (a) each element gets a content type matching U0-1's lead-shape rules:
R1 Ordered edits as `file:`/`anchor:`/`before:`/`after:` (or insert/delete);
R3 criteria as `run:`/`exit:`/`stdout:`/`mutation:`; R5 Pre-resolved context
with `tdd:`, `blast-radius:` (explorer answer pasted as `path:line`),
`commit-message:`; R7 `diagnosis: none` (a unit needing diagnosis is not
sliced to a contract and is reported as a spec gap). (b) R2 mechanical
obligations as numbered edits: the exact new version for plugin.json and
package.json, the CHANGELOG entry text, `node bin/cli.js --update`, and the
`version-stamp-check.sh` criterion (critic 2). (c) R6 Do NOT touch enumerated
as backticked paths. (d) Pre-dispatch self-check (critic 7): before handing off,
run `node bin/contract-score.js <contract>` on each contract. Require
`"score":7` and `"sizeOver":false`. Run every `run:` once at the current HEAD
(each is expected to fail before the edit, or, when it already passes, the
contract says why). Confirm each `anchor:` exists with `grep -n`. A contract
that cannot reach 7 is split or reported as a spec gap. (e) Replace lines 109-114
with a reconciliation (critic 1/14): literal edit payloads are required;
artifact bodies (whole files, logs, specs) stay banned; an edit payload over
`maxInlineBlockLines` splits into consecutive edits; a contract over
`maxPromptBytes` splits the unit. (f) Worked example: a 7/7 contract between the lines
`<!-- lead-contract-example:begin -->` and `<!-- lead-contract-example:end -->`
(each on a line of its own), ≤80 lines. The example includes a command item
(R1 command form) for `node bin/cli.js --update`. Gap C: the marker is
`lead-` prefixed, and every extraction is anchored to whole lines, so U3-3's
`scribe-contract-example` markers can never match it.
This is tier-neutral: no tag vocabulary change.

Acceptance criteria:
- AC3-1.1 `sed -n '/^<!-- lead-contract-example:begin -->$/,/^<!-- lead-contract-example:end -->$/p' agents/task-master.md | sed '1d;$d' | sed '1{/^```/d};${/^```/d}' | node bin/contract-score.js -` prints `"score":7`.
- AC3-1.2 Flattened grep of `agents/task-master.md` for each of `before:`, `mutation:`, `diagnosis: none`, `node bin/contract-score.js`, and `artifact bodies` returns ≥1. At `<B>` the counts for `mutation:` and `diagnosis: none` are 0.
- AC3-1.3 Flattened grep of `agents/task-master.md` for `never from pasting artifact bodies` = 0 (the conflicting sentence is gone), and for `splits into consecutive edits` = 1.
- AC3-1.4 Example block size: `sed -n '/^<!-- lead-contract-example:begin -->$/,/^<!-- lead-contract-example:end -->$/p' agents/task-master.md | wc -l` ≤ 82, and `grep -c '^<!-- lead-contract-example:begin -->$' agents/task-master.md` = 1.
- AC3-1.5 Mirror: flattened grep of `.claude/agents/task-master.md` for `diagnosis: none` ≥ 1.
- AC3-1.6 `node tests/writer-tier-consistency.test.js` exit 0 (AC-D5 literal intact; no "looks mechanical"; vocabulary still `sonnet|opus`).
- AC3-1.7 `version-stamp-check.sh <B>..HEAD` prints `ok`, and `bash tests/validate.sh` exit 0.
- AC3-1.8 AC-SCOPE-1/2/3 (U3-1 row).

## Step U3-2: task-master slicing rules (critic 5, 6, 9, 10, 11)

Affected files: as U3-1 (new bullets after "When pathfinder and to-tickets
disagree", line 50). Depends on U3-1.

Pinned rule labels and content:
- `**to-tickets precedence.**` task-master never asks the user anything that
  to-tickets would ask, always writes file paths and literal snippets in
  contracts (overriding to-tickets' avoid-paths rule), and sizes by pathfinder
  and contract budget, not by context window. (critic 5)
- `**Shared-file siblings.**` Two units touching the same file get a
  `Depends on` edge in dispatch order. The later unit's anchors are headings or
  symbols, never bare line numbers, or they are SHA-qualified and re-resolved by
  the orchestrator after the earlier unit's PASS commit. (critic 6)
- `**Contract home and precedence.**` On the standard path the contract lives in
  the issue body under `## Dispatch contract`; on the fast path, in the plan's
  `### Unit:` block. For the executor the contract outranks the issue prose,
  which outranks the plan. A conflict between them is a spec gap: STOP. (critic 9)
- `**Partial slice on a spec gap.**` Units already published stay. The gap unit
  and everything transitively depending on it are not published. The report
  ends with a `Slice state:` table (unit | published or held | reason).
  (critic 10)
- `**Commits.**` The contract's `commit-message:` lines fix the commit count and
  messages. The version bump and CHANGELOG ride in the same commit as the
  stamped edit, and so does the `--update` output (all 14 `.claude/` paths,
  staged with `git add -u -- .claude`). (critic 11)

Acceptance criteria:
- AC3-2.1 Flattened grep of `agents/task-master.md` for each of the five bold labels = 1 each (0 at `<B>`).
- AC3-2.2 Flattened grep for `Slice state:` ≥ 1, and for `Dispatch contract` ≥ 1.
- AC3-2.3 `git diff --quiet <B>..HEAD -- skills/to-tickets` exit 0 (vendored skill untouched).
- AC3-2.4 Mirror greps for the five labels = 1 each in `.claude/agents/task-master.md`.
- AC3-2.5 `writer-tier-consistency` exit 0, `version-stamp-check` `ok`, `validate.sh` exit 0.
- AC3-2.6 AC-SCOPE-1/2/3 (U3-2 row).

## Step U3-3: scribe contract and scribe precedence (critic 12, 3, gh-209 note)

Affected files: `agents/task-master.md` (scribe contract shape, after the nine
elements), `agents/scribe.md` (precedence paragraph after the close-conditions
list near lines 74-87), bump files, CHANGELOG, both mirrors via `--update`.
Depends on U3-2.

Content: task-master.md defines the scribe contract (`Unit:`, `## Objective`,
`## Retrieval`, `## Glossary edits`, `## ADR`, `## Close conditions`,
`## Do NOT touch`, `## Acceptance criteria`, `## Escalation`) with a worked
example between the whole-line markers `<!-- scribe-contract-example:begin -->` and `<!-- scribe-contract-example:end -->` that scores 5/5
under `--shape=scribe`. It states that the nine-element lead contract does not
apply to scribe (closes the gh-209 note). scribe.md gains a pinned paragraph:
"**Contract precedence.** When your dispatch carries a scribe dispatch contract
(if task-master is present), apply its glossary text, ADR number and close
conditions as written; your own judgment applies only where the contract is
silent. If an item cannot be applied exactly, STOP and report a spec gap."

Acceptance criteria:
- AC3-3.1 The scribe example, extracted with `sed -n '/^<!-- scribe-contract-example:begin -->$/,/^<!-- scribe-contract-example:end -->$/p'` and the same fence stripping as AC3-1.1, prints `"score":5` under `--shape=scribe`. AC3-1.1 and AC3-1.4 are re-run after U3-3 and still pass (no cross-match).
- AC3-3.2 Flattened grep of `agents/scribe.md` for `**Contract precedence.**` = 1, and for `your own judgment applies only where the contract is silent` = 1.
- AC3-3.3 The same greps in `.claude/agents/scribe.md` = 1, and in `.claude/agents/task-master.md` for `scribe-contract-example:begin` = 1.
- AC3-3.4 `frontmatter model` of `agents/scribe.md` is still `haiku`: `sed -n '1,12p' agents/scribe.md | grep -c '^model: haiku$'` = 1.
- AC3-3.5 P4: the new scribe.md paragraph contains `if task-master is present` (flattened grep = 1).
- AC3-3.6 `version-stamp-check` `ok` (two stamped files, one commit), `validate.sh` exit 0, `writer-tier-consistency` exit 0.
- AC3-3.7 AC-SCOPE-1/2/3 (U3-3 row; AC-SCOPE-3 excludes both own mirrors).

## Step U3-4: lead-programmer contract precedence (critic 3)

Affected files: `agents/lead-programmer.md` (after the "If the plan itself is
wrong, STOP" bullet, near line 28), bump files, CHANGELOG, mirror via `--update`,
AND the hand-maintained adapter ports `adapters/cursor/agents/lead-programmer.md`
(same anchor, line 32) and `adapters/codex/agents/lead-programmer.toml` (same
anchor text on line 33 per `grep -n`; the bullet's wrapped text ends on line
34, so the insertion goes after line 34; inside its prompt string; anchor on
the text, not the number). The same paragraph goes into each
port, because cursor/codex consumers run those ports. Adapters are not
version-stamped and not regenerated by `--update`, so they are edited by hand,
in the same commit as the source. Neither the orchestrator ports nor any
spec-master/task-master/scribe port carries the text touched by other units
(checked 2026-10-06), so only U3-4 touches adapters.

Pinned paragraph: "**Contract precedence.** When your dispatch is a dispatch
contract (written by task-master, if present, or by spec-master on the fast
path), its `tdd:`, `blast-radius:`, `commit-message:` and version lines are
decisions already made: follow them and do not re-derive them (no explorer
spawn, no TDD re-decision, no version choice). Your judgment duties apply only
where the contract is silent. Fill the ready-for-review packet template the
contract supplies. If any literal step cannot be applied exactly, STOP and
report a spec gap."

Acceptance criteria:
- AC3-4.1 Flattened grep of `agents/lead-programmer.md` for `**Contract precedence.**` = 1, and for `decisions already made` = 1 (0 at `<B>`).
- AC3-4.2 Mirror greps = 1 each in `.claude/agents/lead-programmer.md`, `adapters/cursor/agents/lead-programmer.md` and `adapters/codex/agents/lead-programmer.toml`; `node tests/adapter-protocol-parity.test.js` exit 0.
- AC3-4.3 `node tests/writer-tier-consistency.test.js` exit 0 (`model: sonnet` source and mirror kept; no "looks mechanical").
- AC3-4.4 P4: flattened grep for `task-master, if present` = 1.
- AC3-4.5 `version-stamp-check` `ok`, `validate.sh` exit 0.
- AC3-4.6 AC-SCOPE-1/2/3 (U3-4 row; the adapter ports are in the extra-files column).

### Gate G3 (no unit; checked by the orchestrator)
`node scripts/unit-outcomes.js --gate=G3` prints `G3 open`. The rule: counting
units whose contract_author is task-master and whose contract was written after
U3-4's PASS commit, ≥60 reached PASS or cap, and ≥20 of those scored 7/7.
**Amended 2026-10-06 (user ruling on hardening-plan Open Question 5).** The "≥20
scored 7/7" count uses, for each unit, its score under that unit's own
`rubric_version`: `v1` uses the v1 score (`contract_score`), and `v2` uses the
v2 score (`contract_score_v2`, added by hardening unit H11).
- A unit whose `rubric_version` is null has no contract (`contract_ts` null), so
  it is outside the population anyway.
- The population (task-master-authored, `contract_ts` after U3-4's `pass_ts`),
  the 60/20 thresholds, Stages 4-5 and the spirit-ruling gate are unchanged.
- Reason: v1 cannot parse `~~~` fences (`v2-all-pass.md` scores 6 under v1 and
  7 under v2, measured), so hardened contracts could never count otherwise.
- The hardening plan's `score-exception:` lines (rulings H-F and H-F2) are
  informational for G3: G3 reads `rubric_version` and the scores, never the
  exception line. The excepted contracts so far (H2, H1b) were written before
  `rgh-h2`'s PASS, so their `rubric_version` is `v1`. They keep their v1 score
  of 6 and do not count toward the 20.
The output also lists the rubric-era FAIL-class mix next to the pre-rubric
sonnet era (the contract effect) and the task-master cutoff count. That count is
informational: the turn cap was already raised to 120 by U0-4, per the user. A
cutoff count > 0 at G3 is reported to the user and changes nothing on its own.

## Step U4-1: shadow re-execution harness `scripts/shadow-replay.sh`

Affected files: `scripts/shadow-replay.sh` (new), `tests/shadow-replay.test.sh`
(new, dry-run mode), `tests/validate.sh` (register).
Behaviour: for each listed rubric-era unit with score 7: `git worktree add` at
its baseline; run the identical contract headless on haiku; then in that
worktree run each `run:` (compare `exit:`/`stdout:`), run
`version-stamp-check.sh baseline..HEAD`, and check the diff against
`## Do NOT touch`. Emit one JSON line per unit:
`{id, tier:"haiku", mech_pass:bool, failed:[...]}`. Apply the same mechanical
check to the unit's real first-attempt sonnet range (`tier:"sonnet"`). Remove
the worktree. `--dry-run` skips the model call. A probe precondition runs first
(R4).
Acceptance criteria:
- AC4-1.1 `bash tests/shadow-replay.test.sh` exit 0 (dry run on a fixture repo: a seeded passing diff yields `mech_pass:true`, a seeded Do-NOT-touch violation yields `false` with `scope` in `failed`).
- AC4-1.2 `git worktree list | wc -l` is the same before and after the test.
- AC4-1.3 Isolation probe: one live run on a no-op fixture leaves the main checkout's `git status --porcelain` and every main-checkout `.claude/*.log` byte size unchanged. The test asserts this with `stat -c %s` over a glob built inside the script, not spelled in the command.
- AC4-1.4 `validate.sh` exit 0.

## Step U4-2: replay scorer `scripts/policy-replay.js` (pre-registered rule)

Affected files: `scripts/policy-replay.js` (new), `tests/policy-replay.test.js`
(new), `tests/validate.sh` (register).
Inputs: the U0 export plus the U4-1 output. Candidates: pi-0 (pre-rubric sonnet,
measured), pi-0' (rubric-era sonnet, measured), pi-2 (haiku for 7/7 units at the
U4-1 haiku pass rate, sonnet for the residue). Cost per research §8.3: attempts
× tier price + reviews × reviewer price; a FAIL adds a one-rung-up attempt plus
an opus review; prices from `scripts/spend-accounting.sh`'s rate table. The
quality term is the cap-hit rate under the 2-FAIL cap with ladder
haiku -> sonnet -> cap.
**Pre-registered verdict (OQ4 default):** `favourable` iff (1) shadow N ≥ 20;
(2) haiku mech-pass rate ≥ sonnet mech-pass rate on the same units minus 5
points; (3) cost(pi-2) ≤ min(cost(pi-0), cost(pi-0')); (4) cap-hit(pi-2) ≤
min(cap-hit of the incumbents). It is `insufficient-evidence` if (1) fails, and
`not-favourable` otherwise.
Acceptance criteria:
- AC4-2.1 `node tests/policy-replay.test.js` exit 0, with one fixture per verdict and per failing condition (2), (3), (4), each flipping only that condition (sentinel fixtures; reverting any condition to `true` fails the suite).
- AC4-2.2 The test asserts the thresholds `20` and `5` are read from one named constant block, and that the plan-quoted values match it.
- AC4-2.3 `validate.sh` exit 0.

## Step U4-3: run the replay and record the verdict (measurement unit)

Affected files: `docs/audits/2026-NN-NN-pi2-replay.md` (new),
`docs/audits/unit-outcomes/<date>.jsonl` (refreshed snapshot).
Acceptance criteria:
- AC4-3.1 `grep -cE '^verdict: (favourable|not-favourable|insufficient-evidence)$'` = 1.
- AC4-3.2 The report lists the exact `shadow-replay.sh` and `policy-replay.js` commands. Re-running `policy-replay.js` on the committed inputs prints the same verdict line.
- AC4-3.3 Every number in the report's table equals a `jq` expression listed beneath it.
- AC4-3.4 `git diff --name-only <B>..HEAD` lists only `docs/audits/` paths.

### Gate G4
`grep -c '^verdict: favourable$' docs/audits/*-pi2-replay.md` ≥ 1 AND
`grep -cE '^spirit-ruling: (met|not-met)$' docs/audits/*-adr0026-forward-rule.md`
= 1. Otherwise Stage 5 stays closed and the programme ends with Stages 0-4 kept
(the rubric still stands on its own).

## Stage 5 (GATED: do not slice before G4)

### Step U5-1: ADR amending ADR-0026 (scribe)
Affected files: `docs/adr/00NN-rubric-gated-haiku-tag.md`. NN is the next free
number at execution time; re-derive it, never backfill a hole. Content is the
Draft ADR above, citing the U1-1 and U4-3 files by path.
- AC5-1.1 `ls docs/adr | grep -c 'rubric-gated-haiku'` = 1. The file contains `Amends: ADR-0026` and both audit paths (grep each = 1).
- AC5-1.2 ADR-0026 is unchanged, or gains only a `Superseded-in-part-by:` line (`git diff <B>..HEAD -- docs/adr/0026*` adds ≤1 line). `node tests/writer-tier-consistency.test.js` AC-D8 still passes.

### Step U5-2: tag vocabulary and ladder bundle (critic 4)
One unit, because AC-D9b couples task-master.md and orchestrator.md and AC-D5
couples CONTEXT.md. Affected: `agents/task-master.md` (Per-unit model tag
bullet: vocabulary `Suggested model: haiku|sonnet|opus`; `haiku` only when the
contract scores 7/7 and no `.fail` exists; `sonnet` stays the default),
`agents/orchestrator.md` (Per-unit model routing: vocabulary; new rule
"**Haiku units escalate on first FAIL** to `sonnet`"; keep "Sonnet units
escalate on first FAIL"; cap count unchanged; a cross-session haiku `.fail`
goes to `opus`; the `fable` exclusion line at :454 kept verbatim),
`tests/writer-tier-consistency.test.js` (AC-D5 task-master literal updated to
the new default sentence; AC-D7 adds the haiku rule; AC-D9 drops the
`haiku|sonnet|opus` ban and adds "never names haiku as a default"; AC-D9b
unchanged), `CONTEXT.md` (**Writer tier**, **Implementer-tier ratchet**
"one rung up", **Suggested model vocabulary**), bump files, CHANGELOG, mirrors
via `--update`. Not changed: lead-programmer frontmatter (`sonnet`),
`templates/persona-config.schema.json`, `bin/cli.js` `IMPLEMENTER_MODEL_TIERS`,
`.claude/persona-config.json` `defaultImplementerModel`, README row,
`hooks/scripts/reviewer-tier.sh`.
- AC5-2.1 `node tests/writer-tier-consistency.test.js` exit 0. Mutation: re-inserting `` `haiku` is the default`` into orchestrator.md makes it exit 1.
- AC5-2.2 `node tests/default-implementer-model.test.js` and `node tests/cli-backfill.test.js` exit 0, and `git diff --quiet <B>..HEAD -- bin/cli.js templates/persona-config.schema.json` exit 0.
- AC5-2.3 Flattened grep of `agents/orchestrator.md` for `Haiku units escalate on first FAIL` = 1, and for `` **`fable` is excluded for `task-master`**`` = 1.
- AC5-2.4 Mirrors carry the same greps; `version-stamp-check` `ok`; `validate.sh` exit 0; AC-SCOPE-1/2/3 (U5-2 row).

### Step U5-3: fail-closed haiku routing; hook and scribe gating (critic 8)
Affected: `agents/orchestrator.md` (before passing `model: haiku`, write the
prompt to a scratch file and run `node bin/contract-score.js`; if the score is
below 7 or the exit is non-zero, dispatch `sonnet` and say so). OQ3 default:
`dispatchHygiene.mode` stays `warn`, and scribe stays out of `gatedAgents`.
scribe dispatches are scored with `--shape=scribe`, and a score below 5 is
reported to the user, never silently dispatched on a cheaper tier than today.
If the user answers OQ3 "block", this unit adds instead a `node bin/cli.js
--update`-routed config change (Set A) plus an H4 substance test in
`tests/dispatch-hygiene.test.sh` (`hooks/` is SENSITIVE_PATHS: opus review).
- AC5-3.1 Flattened grep of `agents/orchestrator.md` for `node bin/contract-score.js` ≥ 1, and for `dispatch \`sonnet\`` in the same paragraph ≥ 1.
- AC5-3.2 `version-stamp-check` `ok`, `validate.sh` exit 0, `writer-tier-consistency` exit 0; AC-SCOPE-1/2/3 (U5-3 row).

## Critic-finding placement

| # | Finding | Placed |
|---|---|---|
| 1 | label-only elements; pointer bodies | U0-1 R1/R3 rules, U3-1 (a)(e) |
| 2 | version/CHANGELOG/mirror obligations | U0-1 R2, U3-1 (b) |
| 3 | judgment duties without precedence | U3-3 (scribe.md), U3-4 (lead-programmer.md) |
| 4 | tag vocabulary pinned | U5-2 |
| 5 | to-tickets contradictions | U3-2 |
| 6 | shared-file sibling collisions | U3-2 |
| 7 | no pre-dispatch self-check | U3-1 (d) |
| 8 | H4 labels-only, scribe ungated, warn mode | U5-3 (OQ3); before Stage 5 the scorer measures, nothing blocks |
| 9 | contract home and precedence | U3-2 |
| 10 | partial slice on spec gap | U3-2 |
| 11 | commit granularity | U0-1 R5 `commit-message:`, U3-2 |
| 12 | scribe has no contract | U0-1 scribe shape, U3-3 |
| 13 | task-master budget | U0-4: `maxTurns: 120` for task-master (and spec-master), unconditional, per the user's addendum. Supersedes the earlier "raise only if G3 shows cutoffs". G3 still reports cutoffs, for information only |
| 14 | maxInlineBlockLines vs literal payloads | U0-1 `sizeOver`, U3-1 (e) |
| 15 | R2/R3/R6/R7 missing in task-master | U3-1 |

## Open Questions

1. (critic-independent; blocks Stage 0 dispatch) Should outcome exports be tracked? Recommended default: **tracked, derived-only snapshot** under `docs/audits/unit-outcomes/` (ids and class labels, no prompt or defect prose). Alternative: per-clone `.claude/unit-outcomes/` (the gitignore delta is in U0-2). Origin: Clarifications cat. 2.
2. (blocks G4 only) Who rules on the ADR-0026 forward check's spirit, and does ≈30% vs 32.5% count as "fallen below"? Recommended default: **the user rules** after reading U1-1. Options: met / not-met. Until then `spirit-ruling: PENDING-HUMAN` holds Stage 5 closed. Origin: Clarifications cat. 6.
3. (blocks U5-3 only) Should H4 move from warn to block before any haiku dispatch? Recommended default: **no global flip; fail-closed scorer gate on haiku routing only** (U5-3). Alternative: block via a `--update`-routed config change plus an H4 substance test. Origin: Clarifications cat. 7, critic 8.
4. (blocks U4-2 only) The Stage 4 evidence standard. Recommended default: **pi-2 must beat the better of pi-0 and pi-0'; shadow re-execution included; N ≥ 20; non-inferiority margin 5 points; G3 at ≥60 rubric-era units.** Alternatives: compare against pi-0 only (as literally briefed), or drop the shadow arm (Stage 4 will then very likely return `insufficient-evidence`, R1). Origin: Clarifications cat. 9, CHK5.
5. (one-line confirmation; blocks U0-4 only if the answer differs) Does the 120 turn cap apply to both spec-master and task-master? Recommended default: **both, and no other persona**. Origin: Clarifications cat. 4 (addendum), CHK14.

## Self-check
- CHK1: Does every Goal-table clause map to a unit criterion or a gate? — PASS
- CHK2: Do U0-1's row rules and U3-1's content types use identical literals (`before:`, `run:`, `mutation:`, `diagnosis: none`)? — PASS
- CHK3: Is the export's tracked-vs-per-clone choice defined, including the alternative's criterion delta? — FAIL (missing) — converted to Open Question 1 (default and delta written into U0-2)
- CHK4: Is it defined who rules on the forward-rule spirit, and what blocks on it? — FAIL (missing) — converted to Open Question 2
- CHK5: Is "favourable" machine-checkable, with thresholds fixed before the data? — FAIL (ambiguous) — revised in place (U4-2 pre-registered rule); thresholds confirmed via Open Question 4
- CHK6: Do U3-1..U3-4 leave every tier-test literal intact (AC-D5 line break, no "looks mechanical", `model: sonnet`)? — PASS (AC3-1.6, AC3-4.3)
- CHK7: Is the 2-FAIL cap's interaction with the haiku ladder defined, including the cross-session case? — PASS (Draft ADR, U5-2)
- CHK8: Does every unit touching agents/*.md name the plugin.json + package.json bump, the CHANGELOG entry, `--update`, and the mirror check? — PASS
- CHK9: Is every critic finding placed or parked with a reason? — PASS (placement table)
- CHK10: Do any criteria spell the reviewed-marker dir or Set A log names in Bash text? — FAIL (conflicting: U2-2's pinned text names the marker path) — revised in place (the path appears only in inserted prose; the authoring note forbids it in `run:`)
- CHK11: Is the H4/H2 interaction with literal payloads defined? — PASS (U3-1 (e), U0-1 `sizeOver`)
- CHK12: Is the `fable` exclusion for task-master kept? — PASS (AC5-2.3)
- CHK14: Is the 120 turn cap's persona scope defined? — FAIL (ambiguous: the user named no persona) — converted to Open Question 5 (default: spec-master and task-master)
- CHK13: Are fast-path (spec-master) contracts in or out of the rubric measurement? — PASS (R7: out; `contract_author` filter)

## Out of scope / parked
- Applying the rubric to spec-master's own fast-path contracts (R7). Revisit after G3.
- S4, T1, T3, T4, S3, S5 (research §8.7 items 7-8).
- Editing the vendored `skills/to-tickets` (precedence is stated in task-master.md instead).
- Any change to `hooks/scripts/reviewer-tier.sh` or the reviewer-gate ratchet.
- A flat haiku default (pi-1): rejected by the user.
- The transcript-pruning policy versus spend accounting (research §8.8 Q4). U1-1 records the spend half as unverifiable.

## Scribe update hint
After U3-1: a `docs/harness-glossary.md` entry **dispatch contract (content-typed)**,
and **contract rubric / contract score** with R1-R7 pointing to
`bin/contract-score.js`. After U0-2/U0-2b: **unit-outcome export**,
**contract score** (if not already added after U3-1), and **terminal event**
(`terminal_ts`: the earlier of the PASS timestamp and the second FAIL header,
read as of the cutoff). These go in `docs/harness-glossary.md` (harness
vocabulary). The **terminal event** entry must state that it is distinct from
CONTEXT.md's **terminal status set** (CONTEXT.md:1125, OutcomeCI journal
statuses). After U3-2:
**slice state**. After U5-2 only: CONTEXT.md **Writer tier**,
**Implementer-tier ratchet**, **Suggested model vocabulary** (in U5-2 itself,
because of the AC-D5 coupling). Avoid "dispatch packet" (eval sense,
harness-glossary:2939) and "haiku-safe".
