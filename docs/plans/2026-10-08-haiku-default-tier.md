# Implementer tier defaults to haiku, with a two-attempts-per-tier escalation ladder (2026-10-08)

Status: FINAL (standard path: 7 units, so task-master slices it; no unit is
gated). Supersedes Stage 5 of `docs/plans/2026-10-06-rubric-gated-haiku-programme.md`
and parks its Stage 4 (see "Reconciliation with the rubric-gated programme").

## Goal

The user's rulings (2026-10-08, decided; not reopened here):

1. ADR-0026's forward rule is ruled **not met in spirit** ("it doesn't, we need
   more testing and long-term evidence"). The audit file records it.
2. The user **overrides** the rubric programme's Stage 4 replay verdict (gate G4)
   and the Stage 5 "beat both baselines" condition. G3 had not opened
   (`rubric_era=13 scored7=10`, against the 60/20 thresholds). The override is
   recorded in a new ADR. Measurement continues: the exporter, the contract
   rubric and the audits stay, and the new ADR pre-registers a fresh,
   machine-checkable forward rule with a stated consequence if it is not met.
3. A **flat `haiku` default** for lead-programmer (not the rubric-gated tag).
   scribe stays `haiku`.
4. The **escalation ladder**: FAIL 1 retries on `haiku` with the defect list;
   FAIL 2 moves to `sonnet` automatically (no human stop); `sonnet` gets its own
   two attempts; then `opus`; then the human via `AskUserQuestion`.
5. ADR-0026 gains only one `Superseded-in-part-by:` line. The tier tests move to
   the new regime.

| Goal clause | Unit(s) | Criterion |
|---|---|---|
| Spirit ruling recorded as `not-met`, user named as ruler | U1 | AC1.1, AC1.2 |
| New ADR amends ADR-0026; records the human override of G4 and Stage 5 | U1 | AC1.4, AC1.5 |
| New ADR pre-registers a machine-checkable forward rule and its consequence | U1 | AC1.5, AC1.6 |
| ADR-0026 gains exactly one `Superseded-in-part-by:` line | U1 | AC1.3 |
| Rubric programme's Stage 5 superseded and Stage 4 parked, explicitly | U1 | AC1.7 |
| `haiku` is a valid `defaultImplementerModel` value; unrecognised still means `opus` | U2 | AC2.1-AC2.4 |
| Projects carrying the old shipped `sonnet` default move to `haiku` once | U2, U4 | AC2.5, AC4.6, AC4.7 |
| The two-attempts-per-tier ladder replaces "Sonnet units escalate on first FAIL" | U3 | AC3.1-AC3.4 |
| The 2-FAIL cap becomes the per-tier move-up; only ladder exhaustion asks the human | U3, U5 | AC3.5, AC5.1-AC5.3 |
| Cross-session tier is recomputed from the FAIL-block count, fail-closed | U3, U4 | AC3.2, AC3.3, AC4.4 |
| Legacy (pre-cutover) FAIL blocks never route to a cheaper tier than wrote them | U4 | AC4.4, AC4.5 |
| lead-programmer frontmatter `model: haiku`; scribe stays `haiku` | U4 | AC4.1, AC4.9 |
| Tier tests pin the new regime; every changed literal listed | U3, U4, U6 | "Pinned-literal ledger", AC3.1, AC4.2, AC6.3 |
| Glossary states the new terms (Escalation ladder, ladder exhaustion) | U6 | AC6.1, AC6.2 |
| The exporter infers `haiku` for the new era, so the forward rule stays measurable | U7 | AC7.1-AC7.3 |

## Context

### Verified facts (2026-10-08, HEAD e0944bf, version 0.31.140)

- `agents/lead-programmer.md:4` `model: sonnet`; `agents/scribe.md:4` `model: haiku`;
  `agents/task-master.md:4` `model: sonnet`. The codex and cursor lead-programmer
  ports carry no tier (`adapters/cursor/agents/lead-programmer.md:4` `model: inherit`;
  `adapters/codex/agents/lead-programmer.toml:12` omits `model`).
- `bin/cli.js:338` `IMPLEMENTER_MODEL_TIERS = ['sonnet', 'opus']`;
  `templates/persona-config.schema.json:56` enum `["sonnet","opus"]`, `"default": "sonnet"`.
  `resolveDefaultImplementerModel` (`bin/cli.js:345`) returns `opus` for any present,
  unrecognised value, so a config `haiku` resolves to `opus` today
  (`tests/default-implementer-model.test.js:70` asserts it).
- **This repo's own config holds `defaultImplementerModel: "sonnet"`** (read with
  the Read tool, line 113). Precedence is tag > config > frontmatter
  (`agents/orchestrator.md:442-454`), so flipping only the frontmatter would
  change nothing here. `--update` backfills the key only when it is absent
  (`bin/cli.js:1270`), and the config is Set A (no agent may write it except
  through `node bin/cli.js --update`). Hence U2's one-time migration.
- `compareSemver` exists and is exported (`bin/cli.js:76`, exports at 2702). In
  `runUpdate`, `config.pluginVersion` still holds the OLD version at the backfill
  block (`bin/cli.js:1270`); it is overwritten at `bin/cli.js:1583`.
- The ladder rules live only in `agents/orchestrator.md` (Per-unit model routing,
  lines 429-474; At the 2-FAIL cap, 362-378; Fix-contract re-dispatch, 201-214;
  review gating off, 380-400) and in task-master's tag bullet
  (`agents/task-master.md:104-118`). `hooks/scripts/reviewer-tier.sh` (reviewer-gate
  ratchet) is untouched by this plan.
- The shared protocol states the cap at `templates/persona-protocol.md:704-713`
  ("Cap at 2 FAILs per unit"), plus two parentheticals at 373-374 and 526-527
  and the review-gating-off "done" sentence at 290-291. The paragraph is inlined
  into the orchestrator, lead-programmer and spec-master mirrors
  (`grep -l 'Cap at 2 FAILs per unit' .claude/agents/*.md`), and
  `agents/spec-master.md:238` quotes its label. The codex and cursor protocol
  ports (`adapters/codex/agents-md-fragment.md:160`,
  `adapters/cursor/rules/persona-protocol.mdc:166`) carry their own copy;
  `tests/adapter-protocol-parity.test.js` probes section headings only
  (`'Continuing after a FAIL verdict'`, line 106/128), not this paragraph.
- `bin/fail-count.sh` counts FAIL blocks with `grep -cE "^FAIL ${task_id} "`; the
  FAIL block format is pinned in CONTEXT.md (**FAIL block**). No persona calls it.
- `scripts/unit-outcomes.js:102-105` `eraTier`: before 2026-08-02 `sonnet`,
  2026-08-02..08-25 `haiku`, from 08-25 `sonnet`. Asserted by
  `tests/unit-outcomes.test.js:291-297` (fixtures `fx-era-1..3`).
- Sanity run of the forward-rule jq (below) on
  `docs/audits/unit-outcomes/2026-10-06.jsonl` with `t0=2026-08-25T00:00:00Z`:
  `met n=205 f1=63 f2=1 f6=0`; with `t0=2026-10-05T00:00:00Z`: `insufficient n=14`.
  The expression is non-vacuous on real data.
- `scripts/spend-accounting.sh --until=2026-10-08T00:00:00Z` reports per-model
  totals and two FAIL-rate periods only (before / from 2026-08-02); it cannot
  attribute spend to the implementer or to a unit.

### Reconciliation with the rubric-gated programme (2026-10-06 plan)

That plan's Draft ADR and U5-2 assumed a `sonnet` default plus a `haiku` tag
allowed only at contract score 7/7, with "Haiku units escalate on first FAIL" and
the cap count unchanged. All three assumptions are replaced:

| 2026-10-06 plan | This plan |
|---|---|
| Stage 5 U5-1 ADR "rubric-gated haiku tag" | Superseded: U1 lands a different ADR (`*-implementer-tier-haiku-default.md`) |
| U5-2 tag vocabulary + "Haiku units escalate on first FAIL" | Superseded: vocabulary `haiku\|sonnet\|opus` (U3), ladder of two attempts per tier (U3); that rule stays banned by AC-D7 |
| U5-2 "no change to `IMPLEMENTER_MODEL_TIERS`, schema, frontmatter" | Reversed by user ruling 3: U2 and U4 change all three |
| U5-3 fail-closed contract-score routing to haiku | Not adopted: the default is flat. `node bin/contract-score.js` stays task-master's pre-dispatch self-check (its U3-1) |
| Stage 4 (U4-1..U4-3) and gate G4 | Parked, not dispatched; G4 overridden by the user (U1 records it) |
| Stages 0-3, the exporter, the rubric, gate G3's query | Unchanged and still in force; G3 output becomes information only |

U1 writes this disposition into the old plan's status block, so a fresh reader of
either plan sees it.

### Decisions (self-resolved where the user left the choice to this plan)

- **D1 `defaultImplementerModel`.** `haiku` becomes a recognised value:
  `IMPLEMENTER_MODEL_TIERS = ['haiku', 'sonnet', 'opus']`, schema enum
  `["haiku","sonnet","opus"]`, schema default `"haiku"` (in U4, with the flip). The
  unrecognised-value rule stays: anything else present resolves to `opus`, still
  the most capable tier. Precedence is unchanged (tag > config > frontmatter); the
  resolved value is the **default tier**, where the ladder starts. A project that
  sets `sonnet` keeps a `sonnet`-first ladder; that is how a project opts out.
- **D2 one-time migration.** A config `"sonnet"` is either the old shipped default
  (scaffold or item18-2 backfill) or a deliberate choice; the config cannot tell
  them apart. `--update` migrates `"sonnet"` to `"haiku"` once, only when the
  config's recorded `pluginVersion` is older than `IMPLEMENTER_HAIKU_DEFAULT_SINCE`
  (the version that ships the flip) and the packaged frontmatter reads `haiku`. It
  prints a Note naming the change and how to set it back. A project updated past
  that version is never migrated again. The constant is `null` (migration
  disabled) until U4 sets it in the same commit as the frontmatter flip, so U2 can
  land first without changing behaviour.
- **D3 ladder.** The ladder is the tiers from the default tier upward in the
  order `haiku`, `sonnet`, `opus`, two entries each. Default `haiku`: `haiku`,
  `haiku`, `sonnet`, `sonnet`, `opus`, `opus`. With n = the unit's FAIL-block
  count, attempt n+1 runs on entry n+1; n equal to the ladder's length is
  **ladder exhaustion** and goes to the human. A `Suggested model` tag can raise
  the tier, never lower it.
- **D4 cross-session, fail-closed.** The ladder is a pure function of n and the
  default tier, so a fresh session computes the same tier as the session that
  saw the FAIL. Which tier wrote a block is never needed. If n cannot be read
  (grep error, or a `.fail` file with no block anchor), dispatch `opus`.
- **D5 ratchet expiry.** Unchanged wording; a record that has expired (a pass
  marker newer than the fail record) means n = 0.
- **D6 legacy blocks.** FAIL blocks older than the **Haiku-default cutover**
  timestamp (the UTC committer time of U4's baseline commit, written as a literal
  into `agents/orchestrator.md` by U4) were written under ADR-0026's `sonnet`
  default. Fail closed: a unit with any such block uses the ladder that starts at
  `sonnet` (`sonnet`, `sonnet`, `opus`, `opus`), whatever the default tier. Its
  next tier is therefore never cheaper than the tier that failed.
- **D7 after exhaustion.** A re-dispatch the human chooses under option (a) or
  (b) runs on `opus` unless the human names a tier; any FAIL after it returns to
  the human.
- **D8 review gating off.** The ladder applies with n = advisory FAILs counted in
  session; at ladder exhaustion the orchestrator lists the remaining findings and
  moves on (today's second-advisory-FAIL behaviour, moved to exhaustion).
- **D9 "Sonnet units escalate on first FAIL"** is deleted, not kept: under the
  ladder a `sonnet` attempt gets two tries. AC-D7 now bans it.
- **D10 ports.** The codex and cursor ports have no per-dispatch model routing
  (lead-programmer inherits its model), so their "Cap at 2 FAILs per unit"
  paragraph stays correct for those hosts and is not edited.
- **D11 the cutover unit itself.** The orchestrator's persona body is loaded at
  session start, so the new routing takes effect from the next session after U3
  and U4 land. Units dispatched in the session that lands them follow the body
  that session loaded.

### Draft ADR (U1 lands it; scribe numbers it)

File: `docs/adr/<NNNN>-implementer-tier-haiku-default.md`, where `<NNNN>` is the
next free number at execution time (re-derive it with
`ls docs/adr | grep -E '^[0-9]{4}-' | sort | tail -1`; 0040 at 2026-10-08; never
backfill a hole). Text, verbatim except `<NNNN>`:

~~~markdown
# ADR <NNNN>: Implementer tier defaults to `haiku`, two attempts per tier

Date: 2026-10-08
Status: Accepted
Amends: ADR-0026
Ratified by: user (repo owner), 2026-10-08

## Context

ADR-0026 (2026-08-25) set the implementer tier to `sonnet` and pre-registered a
forward rule. The audit `docs/audits/2026-10-06-adr0026-forward-rule.md` found
the letter of that rule met (n=205, FAIL rate 30.7% against 32.5%) and the spend
half unverifiable. The user ruled the spirit **not met** on 2026-10-08: "it
doesn't, we need more testing and long-term evidence".

The rubric-gated programme (`docs/plans/2026-10-06-rubric-gated-haiku-programme.md`)
would have changed the tier only after a replay verdict (gate G4) showed a
rubric-gated `haiku` tag beating both `sonnet` baselines. Its gate G3 had not
opened (`rubric_era=13 scored7=10`, against 60 and 20), so no replay ran.

## Human override

The user (repo owner) overrides, on 2026-10-08, the programme's Stage 4 replay
verdict (gate G4) and its Stage 5 condition that the `haiku` policy beat both
baselines. Stage 4 is parked, Stage 5 is superseded by this ADR, and no replay
evidence supports this decision. The pre-registered forward rule below is what
tests it.

## Decision

1. `agents/lead-programmer.md` frontmatter is `model: haiku`. scribe stays
   `haiku`.
2. `defaultImplementerModel` accepts `haiku`, `sonnet`, `opus`; any other present
   value still resolves to `opus`. The resolved value is the default tier. A
   recorded `"sonnet"` from before this change is migrated once to `"haiku"` by
   `--update`, with a printed note; a project that wants `sonnet` sets it again.
3. Escalation ladder: the tiers from the default tier upward (`haiku`, `sonnet`,
   `opus`), two attempts each. A tier's second FAIL moves the unit to the next
   tier automatically. Only the second FAIL on the top tier (ladder exhaustion)
   stops and asks the human. The next tier is computed from the unit's FAIL-block
   count, so a fresh session needs no record of which tier failed; an unreadable
   count dispatches `opus`. FAIL blocks older than the haiku-default cutover start
   the unit's ladder at `sonnet`.
4. The reviewer-gate ratchet (`hooks/scripts/reviewer-tier.sh`, ADR-0009) is
   unchanged. The exporter, the contract rubric and the audits stay.

## Forward rule (pre-registered)

**After ≥60 units dispatched under the `haiku` default** (units in a fresh
`node scripts/unit-outcomes.js` export with `terminal_ts` at or after the
**Haiku-default cutover** timestamp in `agents/orchestrator.md`), all three must
hold:

- fail-rate ≤ 0.35 (units with at least one FAIL block / units)
- escalation-rate ≤ 0.15 (units with at least two FAIL blocks, i.e. that left
  `haiku` / units)
- exhaustion-rate ≤ 0.02 (units with at least six FAIL blocks / units)

Early tripwire: from 20 units, an escalation-rate above 0.30 or two exhausted
units ends the trial early with the same consequence.

Audit command (`<F>` the export file, `<T0>` the cutover timestamp):

    jq -rs --arg t0 "<T0>" '[.[] | select(.terminal_ts >= $t0)] as $p | ($p|length) as $n | ($p|map(select(.fail_blocks>=1))|length) as $f1 | ($p|map(select(.fail_blocks>=2))|length) as $f2 | ($p|map(select(.fail_blocks>=6))|length) as $f6 | if $n < 20 then "insufficient" elif $n < 60 then (if ($f2/$n) > 0.30 or $f6 >= 2 then "tripwire" else "insufficient" end) elif ($f1/$n) <= 0.35 and ($f2/$n) <= 0.15 and ($f6/$n) <= 0.02 then "met" else "not-met" end' <F>

**If the rule prints `not-met` or `tripwire`,** the pre-committed action is to
restore ADR-0026's `sonnet` default (`model: sonnet` in lead-programmer's
frontmatter and `"default": "sonnet"` in the schema; the ladder then starts at
`sonnet` by itself). Keeping `haiku` instead needs an explicit user ruling
written into the audit file. This rule is revisited, not defended.

Spend is recorded alongside (`bash scripts/spend-accounting.sh --until=<cutoff>`)
for information only: the script cannot attribute spend to a unit or to the
implementer, and transcripts are pruned after about 30 days.

## Consequences

- More attempts per unit are possible (up to six before a human sees it), each
  with a reviewer pass; the bet is that most units finish on `haiku`.
- The forward rule needs no new tooling; the exporter's era inference learns the
  new era (`haiku` from the cutover).

## Related

- ADR-0026 (amended here: tier and ladder), ADR-0010 (the first `haiku`
  default, with first-FAIL escalation), ADR-0009 (reviewer tier, unchanged).
- Plan: `docs/plans/2026-10-08-haiku-default-tier.md`.
~~~

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-08 Domain entities / data model: Q Must `haiku` become a valid `defaultImplementerModel` value, and what happens to configs that already hold `"sonnet"` (this repo's does)? → A (self-resolved): yes, enum and `IMPLEMENTER_MODEL_TIERS` gain `haiku`; unrecognised still means `opus`; a pre-cutover `"sonnet"` is migrated once by `--update` (D1, D2). Without the migration the flip is inert here, because config outranks frontmatter
- 2026-10-08 User interaction flow: Q How many attempts does `opus` get before the human is asked? → A (self-resolved, confirm via Open Question 1): two, the same per-tier cap as `haiku` and `sonnet` ("sonnet gets its own cap of 2"); ladder exhaustion is the sixth FAIL. Changing it is a one-literal edit in U3
- 2026-10-08 User interaction flow: Q Under review gating `off`, does the ladder apply? → A (self-resolved): yes, counted in session; exhaustion lists findings and moves on (D8)
- 2026-10-08 Non-functional attributes: Q Is spend part of the new forward rule? → A (self-resolved): information only; `spend-accounting.sh` cannot attribute spend to a unit, and transcripts prune at ~30 days (the same reason ADR-0026's spend half was unverifiable)
- 2026-10-08 External dependencies & integrations: Q Do the codex/cursor ports and the shared protocol change? → A (self-resolved): the shared protocol (`templates/persona-protocol.md`) does (U5); the ports do not, since those hosts have no per-dispatch model routing (D10)
- 2026-10-08 Edge cases / failure handling: Q A fresh session cannot see which tier wrote a FAIL block: what is the fail-closed handling? → A (self-resolved): the tier is a function of the block count, so no tier record is needed (D4); an unreadable count dispatches `opus`; pre-cutover blocks start the ladder at `sonnet` (D6)
- 2026-10-08 Edge cases / failure handling: Q What tier does a re-dispatch after ladder exhaustion use? → A (self-resolved): `opus` unless the human names one (D7)
- 2026-10-08 Edge cases / failure handling: Q What becomes of "Sonnet units escalate on first FAIL" and the ratchet expiry? → A (self-resolved): the first is deleted and banned (D9); the expiry wording stays and means n = 0 (D5)
- 2026-10-08 Technical constraints & tradeoffs: Q Where does the cutover timestamp come from, given no unit knows its own commit time? → A (self-resolved): U4's baseline commit's UTC committer time, re-derived by the orchestrator at U4 dispatch and written as a literal (D6)
- 2026-10-08 Technical constraints & tradeoffs: Q Can the flip be split from the ladder without an incoherent intermediate state? → A (self-resolved): yes; U3 writes the ladder tier-neutrally ("from the default tier upward"), so with the default still `sonnet` it reads `sonnet`, `sonnet`, `opus`, `opus` and is coherent; U4 then flips the default
- 2026-10-08 Terminology consistency: Q What are the canonical names for the per-tier move-up and the final stop? → A (self-resolved): **Escalation ladder** and **ladder exhaustion**; "2-FAIL cap" stays the per-tier cap; avoid "handoff" (CONTEXT.md:476 and the wip-handoff sentinel already use it) and "first-FAIL escalation"
- 2026-10-08 Completion / acceptance signals: Q What machine-checkable rule replaces ADR-0026's forward rule, and what happens if it fails? → A (self-resolved): the three-threshold rule plus tripwire in the Draft ADR; on `not-met` or `tripwire` the `sonnet` default is restored unless the user rules otherwise in the audit file

## Risks / dependencies

- R1 Prior FAIL history on these surfaces (`.fail` records surveyed via the
  outcome snapshot). `spec2-unitD` (the ADR-0026 unit): package.json not bumped
  with plugin.json, AC-D5 missed CONTEXT.md, AC-D8 unpinned. Every persona unit
  here carries the package.json bump; the CONTEXT.md literal is moved by U6 with
  its own criterion. `item18-1-add-config-field`: the orchestrator prose stated
  the wrong fallback direction while the function was right. U3 keeps the two
  sentences `tests/default-implementer-model.test.js:92,107` pin, byte for byte
  (Do NOT touch). These are judgment-carrying surfaces: task-master must not tag
  any unit below the default tier, and U2, U3, U4 always draw an `opus` reviewer
  (`agents/`, `bin/cli.js` are `SENSITIVE_PATHS`).
- R2 Marker-note sweep (`bash bin/marker-audit.sh . --notes --surface=<path>`)
  over agents/orchestrator.md, agents/task-master.md, agents/lead-programmer.md,
  bin/cli.js: no `NOTE[spec]` lines; the untagged notes name dispatched units and
  need no action. The sweeps over tests/writer-tier-consistency.test.js and
  tests/default-implementer-model.test.js timed out (60 s). Best-effort; an empty
  result proves nothing. Carried forward from the 2026-10-06 plan: the
  item06-3 `NOTE[spec]` says AC-D9's banned-literal checks use stripWhitespace
  (strip-all). Disposition: U3 keeps stripWhitespace for every AC-D9 assertion it
  rewrites or adds.
- R3 Version order (assumes HEAD at 0.31.140 and no other bump in between):
  U2 0.31.141, U3 0.31.142, U4 0.31.143, U5 0.31.144. U1, U6, U7 set no version.
  If anything else bumps first, each later unit's literal becomes (HEAD version +
  1), and the orchestrator re-derives it in the contract before dispatch. U4's
  `IMPLEMENTER_HAIKU_DEFAULT_SINCE` literal MUST equal U4's own version (AC4.6).
- R4 Persona units land, in ONE commit: the edit, the plugin.json + package.json
  bump, a CHANGELOG `[Unreleased]` entry, and the `node bin/cli.js --update`
  output, staged with `git add -u -- .claude` (never by spelling the config's
  file name in Bash: harness-integrity-gate refuses any Bash text naming it).
  Bump before `--update`. U2 and U5 touch `templates/*`, so they follow the same
  rule.
- R5 Bash criteria must not spell the reviewed-marker directory or Set A names
  (both gates scan command text). The orchestrator TEXT added by U3 names the
  marker path inside prose only; no `run:` in this plan names it. AC4.7 reads the
  repo config from inside a test file (`node tests/...`), whose command text
  names nothing. If a lead-programmer has to fall back to Bash heredocs to edit
  that test, the gate will refuse a heredoc that spells the config's name: use
  the Edit tool, or report the block (never split the name to dodge the scan).
- R6 Transient prose staleness, accepted: between U3 and U5 the shared protocol
  still says the cap stops after the second FAIL per unit; between U4 and U6
  CONTEXT.md still says `sonnet`→`opus` on re-attempt. Both are prose only (no
  test breaks), and the dispatch order puts U5 and U6 directly after U4.
- R7 Downstream window: a project that runs `--update` later than the cutover has
  `sonnet`-era FAIL blocks newer than the cutover literal; for those, n=1 retries
  on `haiku` (cheaper than the tier that failed). Bounded to one retry per such
  unit; accepted and named in the ADR's legacy clause.
- R8 Deliberate `sonnet` downstream: D2 migrates it once. The Note line says how
  to set it back; the ADR records the trade-off.
- R9 spec-master's debug-spec bullet still says "between the first and second
  tries" (`agents/spec-master.md`); at ladder exhaustion there are up to six.
  Out of scope (prose only, the debug spec reads every block anyway); U5 edits
  only the label quote at line 238.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Each criterion names its command, its expected output and a mutation that makes it fail; the forward-rule jq was run on real data (Context).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The config moves only through `node bin/cli.js --update` (U2's migration); the ladder is a table lookup on a `grep -c` count; mirrors and `fileHashes` regenerate only via `--update`.
- P3 "Version-stamp discipline": satisfied. U2, U3, U4, U5 each bump plugin.json and package.json and add a CHANGELOG entry in the same commit; checked by `bash hooks/scripts/version-stamp-check.sh <B>..HEAD`. U1, U6, U7 touch no stamped path (AC1.8, AC6.4, AC7.4 check it).
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. New task-master prose points only at the orchestrator (always present); new orchestrator prose names task-master only inside the existing conditional Fix-contract paragraph.
- P5 "tests/validate.sh is the merge gate": satisfied. Every unit's criteria include `bash tests/validate.sh` exit 0.

## Conventions for every unit

- `<B>` is the unit's baseline SHA (the commit before its first commit). Every
  command runs from the repo root.
- **Flattened grep** of FILE for PHRASE means
  `tr '\n' ' ' < FILE | tr -s ' ' | grep -oF 'PHRASE' | wc -l`, so a hard wrap
  cannot make a phrase check pass vacuously. Write each pinned phrase in the file
  on as few lines as the surrounding wrap allows; the check is wrap-proof either
  way.
- **Persona-unit scope rule** (U2, U3, U4, U5; same as the 2026-10-06 plan):
  - AC-SCOPE-1: `git diff --name-only <B>..HEAD | grep -v '^\.claude/' | sort` equals the sorted list of the unit's own files + `.claude-plugin/plugin.json` + `CHANGELOG.md` + `package.json`.
  - AC-SCOPE-2: `git diff --name-only <B>..HEAD -- .claude | wc -l` = 14 (10 agent mirrors, the config, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`).
  - AC-SCOPE-3 (U2, U3, U4 only): `git diff -U0 <B>..HEAD -- .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/protocol-digest.md <one ':(exclude)' per own mirror> | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | grep -cvE '^[-+]<!-- antislop v[0-9]+\.[0-9]+\.[0-9]+ \| source: '` prints `0`. U5 changes the inlined protocol in several mirrors, so it uses `bash tests/validate.sh` mirror parity instead (AC5.6).

## Dispatch order and dependencies

U1 -> U2 -> U3 -> U4 -> U5 -> U6 -> U7.
- U2 has no dependency (it can run beside U1). U3 depends on U1 (AC3.6 reads the
  ADR). U4 depends on U2 and U3. U5 depends on U3 (it names the Escalation
  ladder). U6 depends on U4 and U5. U7 depends on U4 (it reads the cutover
  literal).
- Same-file serialisation: writer-tier test (U3, U4, U6); orchestrator.md (U3,
  U4); task-master.md (U3, U4); bin/cli.js and the schema (U2, U4); CONTEXT.md
  (U6 only).
- Implementer: U1 is a scribe unit (docs and ADR); U2-U7 are lead-programmer
  units. U6 edits a test, so it is not a scribe unit.

## Pinned-literal ledger (`tests/writer-tier-consistency.test.js` and `tests/default-implementer-model.test.js`)

Every pinned literal that changes, and the unit that changes it. Literals not
listed (AC-D6 "looks mechanical", AC-D8's three ADR-0026 substrings, AC-D9's
spec-master check, AC-D9b's agreement logic, AC-T1, AC-A1, AC-P2, AC-P3, and
`default-implementer-model.test.js:92` and `:104-112`) do not change.

| Check | Old literal / assertion | New literal / assertion | Unit |
|---|---|---|---|
| AC-D5 lead source | `frontmatterModel(agents/lead-programmer.md) === 'sonnet'` | `=== 'haiku'` | U4 |
| AC-D5 lead mirror | `frontmatterModel(.claude/agents/lead-programmer.md) === 'sonnet'` | `=== 'haiku'` | U4 |
| AC-D5 README | row matches `/\|\s*sonnet\s*\|/` | row matches `/\|\s*haiku\s*\|/` | U4 |
| AC-D5 task-master (required) | `` `sonnet` is\n  the default for every unit`` | `` `haiku` is\n  the default for every unit`` | U4 |
| AC-D5 task-master (banned) | `` `haiku` is\n  the default`` | `` `sonnet` is\n  the default`` | U4 |
| AC-D5 CONTEXT (required) | `` `sonnet`→`opus` on re-attempt`` | `` two attempts per tier, `haiku`→`sonnet`→`opus` `` | U6 |
| AC-D5 CONTEXT (banned) | `` `haiku`→`sonnet` on re-attempt`` | `` `sonnet`→`opus` on re-attempt`` | U6 |
| AC-D7 (required) | `/Sonnet units escalate on first FAIL/` | `/\*\*Escalation ladder\.\*\* Each implementer tier gets two attempts/` | U3 |
| AC-D7 (banned) | `/Haiku units escalate on first FAIL/` | both `/Haiku units escalate on first FAIL/` and `/Sonnet units escalate on first FAIL/` | U3 |
| AC-D9 ban 1 | `` `model: haiku` frontmatter is the`` | `` `model: sonnet` frontmatter is the`` | U3 |
| AC-D9 ban 2 | `haiku\|sonnet\|opus` banned | REMOVED; replaced by a required `` `Suggested model: haiku\|sonnet\|opus` `` | U3 |
| AC-D9 ban 3 | `haiku → FAIL` | `sonnet → FAIL → opus → FAIL` | U3 |
| AC-D9 ban 4 | `` never dispatch on `haiku` `` | unchanged | — |
| AC-P1 | requires `Sonnet units escalate on first FAIL` | requires `**Escalation ladder.**` (other five needles unchanged) | U3 |
| AC-D8b (new) | — | the haiku-default ADR has the forward-rule substrings; ADR-0026 has `^Superseded-in-part-by: ADR-\d{4} ` | U3 |
| AC-D10 (new) | — | this repo's config `defaultImplementerModel` resolves to the lead-programmer frontmatter value | U4 |
| AC-D11 (new) | — | orchestrator.md has exactly one `**Haiku-default cutover: <ISO-8601 Z>.**` line | U4 |
| d-i-m `:69-72` | `haiku` → `opus` (unrecognised) | `haiku` → `haiku` (recognised); `bogus-junk` → `opus` and `fable` → `opus` kept as the unrecognised cases | U2 |
| d-i-m (new) | — | `IMPLEMENTER_MODEL_TIERS` equals the schema enum; migration truth table; `--update` migration on an old-version fixture | U2 |

## Step U1 (scribe): spirit ruling, ADR, supersession lines

Affected files: `docs/audits/2026-10-06-adr0026-forward-rule.md`,
`docs/adr/<NNNN>-implementer-tier-haiku-default.md` (new),
`docs/adr/0026-writer-tier-reversed-to-sonnet.md`,
`docs/plans/2026-10-06-rubric-gated-haiku-programme.md`. No version-stamped path.

Ordered edits:
1. `docs/audits/2026-10-06-adr0026-forward-rule.md`, anchor: the last line.
   before: `spirit-ruling: PENDING-HUMAN`
   after (two lines):
   `spirit-ruling: not-met`
   `spirit-ruled-by: user (repo owner), 2026-10-08: "it doesn't, we need more testing and long-term evidence"`
2. `docs/adr/0026-writer-tier-reversed-to-sonnet.md`, insert-after the line
   `Ratified by: user (repo owner), 2026-08-25`, one line:
   `Superseded-in-part-by: ADR-<NNNN> (implementer tier defaults to haiku, two attempts per tier)`
   No other change to this file.
3. Create `docs/adr/<NNNN>-implementer-tier-haiku-default.md` with the Draft ADR
   text above (between the `~~~markdown` fences, fences excluded), `<NNNN>`
   replaced by the number. The four-space-indented `jq -rs` line stays one line.
4. `docs/plans/2026-10-06-rubric-gated-haiku-programme.md`, insert-before the
   first line `## Goal`, followed by one blank line:
   `Superseded in part (2026-10-08): Stage 5 (U5-1..U5-3 and the Draft ADR) is superseded by docs/plans/2026-10-08-haiku-default-tier.md and its ADR (*-implementer-tier-haiku-default.md); Stage 4 (U4-1..U4-3) is parked and not dispatched; gate G4 was overridden by the user on 2026-10-08. Stages 0-3, the exporter, the contract rubric and gate G3's query stay in force.`

Do NOT touch: `agents/`, `tests/`, `CONTEXT.md`, any other ADR, any other line of
ADR-0026, the audit file's other lines.

Acceptance criteria:
- AC1.1 run: `grep -c '^spirit-ruling: not-met$' docs/audits/2026-10-06-adr0026-forward-rule.md; grep -c 'PENDING-HUMAN' docs/audits/2026-10-06-adr0026-forward-rule.md` stdout: `1` then `0`. mutation: leave the PENDING-HUMAN line in place -> second count is 1.
- AC1.2 run: `grep -c '^spirit-ruled-by: user (repo owner), 2026-10-08' docs/audits/2026-10-06-adr0026-forward-rule.md; grep -cE '^spirit-ruling: (PENDING-HUMAN|met|not-met)$' docs/audits/2026-10-06-adr0026-forward-rule.md` stdout: `1` then `1`.
- AC1.3 run: `git diff <B>..HEAD -- docs/adr/0026-writer-tier-reversed-to-sonnet.md | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | grep -c .; git diff <B>..HEAD -- docs/adr/0026-writer-tier-reversed-to-sonnet.md | grep -c '^+Superseded-in-part-by: ADR-[0-9]\{4\} '` stdout: `1` then `1`. mutation: any second changed line in ADR-0026 -> first count 2.
- AC1.4 run: `ls docs/adr | grep -cE '^[0-9]{4}-implementer-tier-haiku-default\.md$'; ls docs/adr | grep -E '^[0-9]{4}-' | sort | tail -1 | grep -c 'implementer-tier-haiku-default'; test "$(ls docs/adr | grep -E 'implementer-tier-haiku-default' | cut -c1-4)" = "$(grep -o '^Superseded-in-part-by: ADR-[0-9]*' docs/adr/0026-writer-tier-reversed-to-sonnet.md | grep -o '[0-9]*$')"; echo $?` stdout: `1`, `1`, `0` (newest number, and ADR-0026's line names it).
- AC1.5 Flattened grep of the new ADR, each ≥ 1 (0 at `<B>`: the file does not exist): `Amends: ADR-0026`, `## Human override`, `docs/audits/2026-10-06-adr0026-forward-rule.md`, `≥60 units dispatched under the `haiku` default`, `fail-rate ≤ 0.35`, `escalation-rate ≤ 0.15`, `exhaustion-rate ≤ 0.02`, `tripwire`, `restore ADR-0026's `sonnet` default`, `rubric_era=13 scored7=10`.
- AC1.6 The pinned audit command runs. run: `A=$(ls docs/adr/*-implementer-tier-haiku-default.md); grep -E '^    jq -rs' "$A" | sed 's/^    //; s/<T0>/2026-08-25T00:00:00Z/; s#<F>#docs/audits/unit-outcomes/2026-10-06.jsonl#' | bash; grep -E '^    jq -rs' "$A" | sed 's/^    //; s/<T0>/2026-10-05T00:00:00Z/; s#<F>#docs/audits/unit-outcomes/2026-10-06.jsonl#' | bash` stdout: `met` then `insufficient`. mutation: in a scratch copy, `0.35` -> `0.30` makes the first print `not-met` (63/205 = 0.307).
- AC1.7 run: `grep -c '^Superseded in part (2026-10-08):' docs/plans/2026-10-06-rubric-gated-haiku-programme.md` stdout: `1`.
- AC1.8 run: `git diff --name-only <B>..HEAD | sort` stdout: exactly the four Affected-files paths (sorted). `node tests/writer-tier-consistency.test.js` exit 0 (AC-D8 still pins ADR-0026), `bash tests/validate.sh` exit 0.

## Step U2: `haiku` is a recognised `defaultImplementerModel`; one-time migration (disabled until U4)

Affected files: `bin/cli.js`, `templates/persona-config.schema.json`,
`tests/default-implementer-model.test.js`, `.claude-plugin/plugin.json`,
`package.json` (0.31.141), `CHANGELOG.md`, and the 14 `.claude/` paths from
`node bin/cli.js --update`.

Ordered edits:
1. `bin/cli.js`, anchor: the comment block above `const IMPLEMENTER_MODEL_TIERS`.
   before (lines 333-338):
   ```
   // Recognised `defaultImplementerModel` tier values — must stay in sync with
   // templates/persona-config.schema.json's `defaultImplementerModel` enum,
   // which (with CONTEXT.md's **Writer tier** entry) is what establishes that
   // only two tiers exist today, so "more capability" resolves unambiguously
   // to 'opus'.
   const IMPLEMENTER_MODEL_TIERS = ['sonnet', 'opus'];
   ```
   after:
   ```
   // Recognised `defaultImplementerModel` tier values, cheapest first — must
   // stay in sync with templates/persona-config.schema.json's
   // `defaultImplementerModel` enum. 'opus' is the most capable, so "more
   // capability" for an unrecognised value still resolves to 'opus'.
   const IMPLEMENTER_MODEL_TIERS = ['haiku', 'sonnet', 'opus'];

   // The first plugin version whose packaged agents/lead-programmer.md
   // frontmatter reads `model: haiku` (docs/plans/2026-10-08-haiku-default-tier.md).
   // null disables the migration below; the cutover unit sets it in the same
   // commit as the frontmatter flip.
   const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;

   // A recorded "sonnet" older than IMPLEMENTER_HAIKU_DEFAULT_SINCE is the old
   // shipped default (scaffold or item18-2 backfill) as far as this code can
   // tell, so --update moves it to "haiku" once. Returns the new value, or null
   // for no change.
   function migrateDefaultImplementerModel(value, oldPluginVersion, since, frontmatterDefault) {
     if (since == null || value !== 'sonnet' || frontmatterDefault !== 'haiku') return null;
     if (oldPluginVersion && compareSemver(oldPluginVersion, since) >= 0) return null;
     return 'haiku';
   }
   ```
2. `bin/cli.js`, insert-after the `  }` that closes `if (needsImplementerModelBackfill) {`
   in `runUpdate` (the block ending with the line
   `        '(agents/lead-programmer.md\'s frontmatter default).\n'`):
   ```

     const migratedImplementerModel = migrateDefaultImplementerModel(
       config.defaultImplementerModel, config.pluginVersion, IMPLEMENTER_HAIKU_DEFAULT_SINCE, implementerFrontmatterDefault());
     if (migratedImplementerModel) {
       config.defaultImplementerModel = migratedImplementerModel;
       console.log(
         `Note: persona-config.json defaultImplementerModel "sonnet" predates the haiku default (v${IMPLEMENTER_HAIKU_DEFAULT_SINCE}) ` +
           `— ${dryRun ? 'would migrate' : 'migrated'} to "haiku". Set it back to "sonnet" by hand to keep the old default.\n`
       );
     }
   ```
3. `bin/cli.js` `module.exports`, insert-after the line `  resolveDefaultImplementerModel,`:
   `  migrateDefaultImplementerModel,`, `  IMPLEMENTER_MODEL_TIERS,`, `  IMPLEMENTER_HAIKU_DEFAULT_SINCE,` (three lines).
4. `templates/persona-config.schema.json` line 56. before: `      "enum": ["sonnet", "opus"],` after: `      "enum": ["haiku", "sonnet", "opus"],`
5. `templates/persona-config.schema.json` line 58 (the description). before fragment:
   `An ABSENT key resolves to the frontmatter default (\"sonnet\" today)` after fragment:
   `An ABSENT key resolves to the packaged frontmatter default`. And before fragment
   (end of the string): `own absent/unrecognised-value fallback."` after fragment:
   `own absent/unrecognised-value fallback. A \"sonnet\" value recorded before the haiku default shipped is migrated once to \"haiku\" by --update (bin/cli.js migrateDefaultImplementerModel)."`
   `"default": "sonnet"` stays (U4 flips it).
6. `tests/default-implementer-model.test.js`, before (lines 69-72):
   ```
   check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {
     assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'haiku' }, 'sonnet'), 'opus');
     assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'bogus-junk' }, 'sonnet'), 'opus');
   });
   ```
   after:
   ```
   check('resolveDefaultImplementerModel: haiku is a recognised tier and passes through', () => {
     assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'haiku' }, 'sonnet'), 'haiku');
   });

   check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {
     assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'bogus-junk' }, 'sonnet'), 'opus');
     assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'fable' }, 'haiku'), 'opus');
   });

   check('IMPLEMENTER_MODEL_TIERS equals the schema enum', () => {
     const schema = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'templates', 'persona-config.schema.json'), 'utf8'));
     assert.deepStrictEqual(cli.IMPLEMENTER_MODEL_TIERS, schema.properties.defaultImplementerModel.enum);
   });

   check('migrateDefaultImplementerModel: only an old-version "sonnet" moves, only to haiku, only when enabled', () => {
     const m = cli.migrateDefaultImplementerModel;
     assert.strictEqual(m('sonnet', '0.31.140', '0.31.143', 'haiku'), 'haiku');
     assert.strictEqual(m('sonnet', '0.31.143', '0.31.143', 'haiku'), null);
     assert.strictEqual(m('sonnet', undefined, '0.31.143', 'haiku'), 'haiku');
     assert.strictEqual(m('opus', '0.31.140', '0.31.143', 'haiku'), null);
     assert.strictEqual(m('haiku', '0.31.140', '0.31.143', 'haiku'), null);
     assert.strictEqual(m('sonnet', '0.31.140', null, 'haiku'), null);
     assert.strictEqual(m('sonnet', '0.31.140', '0.31.143', 'sonnet'), null);
   });
   ```
7. `tests/default-implementer-model.test.js`, insert-after the closing `});` of the
   check `'--update preserves a deliberately-set non-default defaultImplementerModel value'`:
   ```

   check('--update applies migrateDefaultImplementerModel to an old-version "sonnet" config', () => {
     const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-migrate-'));
     try {
       const before = buildBaselineProject(tmp);
       before.defaultImplementerModel = 'sonnet';
       before.pluginVersion = '0.31.0';
       writeConfig(tmp, before);

       const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
       assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

       const frontmatter = frontmatterModel(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'lead-programmer.md'), 'utf8'));
       const expected = cli.migrateDefaultImplementerModel('sonnet', '0.31.0', cli.IMPLEMENTER_HAIKU_DEFAULT_SINCE, frontmatter) || 'sonnet';
       assert.strictEqual(readConfig(tmp).defaultImplementerModel, expected);
     } finally {
       fs.rmSync(tmp, { recursive: true, force: true });
     }
   });
   ```
   (With the constant `null` this expects `sonnet`; after U4 it expects `haiku`,
   which is when it becomes discriminating: AC4.7.)
8. `.claude-plugin/plugin.json` and `package.json`: `"version": "0.31.140"` -> `"version": "0.31.141"`.
9. `CHANGELOG.md`, insert-after `## [Unreleased]` and its blank line, then a blank line:
   `**haiku is a recognised implementer tier (htd-2, 0.31.141).** \`bin/cli.js\` \`IMPLEMENTER_MODEL_TIERS\` and the \`defaultImplementerModel\` schema enum gain \`haiku\`; any other unrecognised value still resolves to \`opus\`. A one-time \`--update\` migration of a pre-cutover \`"sonnet"\` to \`"haiku"\` is added but disabled (\`IMPLEMENTER_HAIKU_DEFAULT_SINCE = null\`) until the cutover unit.`
10. command: `node bin/cli.js --update` expect: 0. Then `git add -u -- .claude` and the files above; one commit.

Do NOT touch: `agents/`, `hooks/scripts/reviewer-tier.sh`, the schema's `"default"`
line, `resolveDefaultImplementerModel`'s body, `tests/default-implementer-model.test.js:89-113`.

Acceptance criteria:
- AC2.1 run: `node tests/default-implementer-model.test.js` exit 0, last line `All default-implementer-model checks passed.`
- AC2.2 run: `node -e "const c=require('./bin/cli.js');process.exit(c.resolveDefaultImplementerModel({defaultImplementerModel:'haiku'},'sonnet')==='haiku'&&c.resolveDefaultImplementerModel({defaultImplementerModel:'bogus'},'haiku')==='opus'?0:1)"` exit 0 (exit 1 at `<B>`). mutation: drop `'haiku'` from `IMPLEMENTER_MODEL_TIERS` -> exit 1.
- AC2.3 run: `node -e "const c=require('./bin/cli.js');const s=require('./templates/persona-config.schema.json');process.exit(JSON.stringify(c.IMPLEMENTER_MODEL_TIERS)===JSON.stringify(s.properties.defaultImplementerModel.enum)&&c.IMPLEMENTER_HAIKU_DEFAULT_SINCE===null&&s.properties.defaultImplementerModel.default==='sonnet'?0:1)"` exit 0. mutation: schema enum left at `["sonnet","opus"]` -> exit 1.
- AC2.4 run: `node -e "const m=require('./bin/cli.js').migrateDefaultImplementerModel;console.log(JSON.stringify([m('sonnet','0.31.140','0.31.143','haiku'),m('sonnet','0.31.143','0.31.143','haiku'),m('sonnet',undefined,'0.31.143','haiku'),m('opus','0.31.140','0.31.143','haiku'),m('sonnet','0.31.140',null,'haiku'),m('sonnet','0.31.140','0.31.143','sonnet')]))"` stdout: `["haiku",null,"haiku",null,null,null]`. mutation: `>= 0` -> `> 0` makes the second entry `"haiku"`.
- AC2.5 run: `grep -c 'migratedImplementerModel' bin/cli.js` stdout ≥ `2` (0 at `<B>`).
- AC2.6 run: `node tests/cli-backfill.test.js` exit 0; `node tests/writer-tier-consistency.test.js` exit 0; `bash hooks/scripts/version-stamp-check.sh <B>..HEAD` stdout starts `version-stamp-check: ok`; `bash tests/validate.sh` exit 0.
- AC2.7 AC-SCOPE-1 (own: `bin/cli.js`, `templates/persona-config.schema.json`, `tests/default-implementer-model.test.js`), AC-SCOPE-2, AC-SCOPE-3 (no exclusions); `git diff --quiet <B>..HEAD -- agents hooks/scripts/reviewer-tier.sh` exit 0.

## Step U3: the Escalation ladder (tier-neutral), tag vocabulary `haiku|sonnet|opus`

Affected files: `agents/orchestrator.md`, `agents/task-master.md`,
`tests/writer-tier-consistency.test.js`, bump files (0.31.142), `CHANGELOG.md`,
the 14 `.claude/` paths via `--update`. Depends on U1.

Ordered edits (orchestrator line numbers at e0944bf; anchor on the text):
1. `agents/orchestrator.md` (Fix-contract re-dispatch). before:
   `lead-programmer with that fix contract on the ratcheted tier. If task-master's`
   after: `lead-programmer with that fix contract on the tier the **Escalation ladder** gives. If task-master's`
2. `agents/orchestrator.md` (At the 2-FAIL cap), before (two lines):
   ```
   **At the 2-FAIL cap**: stop re-dispatching lead-programmer on this unit. Surface the full two-attempt
   defect history to the user (both `.fail` records and the fix-attempt commits), then ask the human how to proceed via `AskUserQuestion`. The orchestrator waits for the user's choice before proceeding:
   ```
   after:
   ```
   **At the 2-FAIL cap**: a tier's second FAIL below the top of the **Escalation ladder** is not a stop: dispatch the ladder's next entry automatically, with the full defect history, and do not ask the human. At **ladder exhaustion** (the second FAIL on the ladder's top tier), stop re-dispatching lead-programmer on this unit. Surface the full
   defect history to the user (every FAIL block in the `.fail` record and every fix-attempt commit), then ask the human how to proceed via `AskUserQuestion`. The orchestrator waits for the user's choice before proceeding:
   ```
3. `agents/orchestrator.md`, before: `diagnosis read from the latest `.fail` record and both fix-attempt commits, plus revised acceptance`
   after: `diagnosis read from the latest `.fail` record and the fix-attempt commits, plus revised acceptance`
4. `agents/orchestrator.md`, insert-after the line `marker is written and none is deleted.` (end of option (c)), a blank line and:
   `After ladder exhaustion, a re-dispatch under (a) or (b) runs on `opus` unless the human names a tier, and any FAIL after it comes back to this section.`
5. `agents/orchestrator.md` (review gating off), before (two lines):
   ```
   in this session (there are no `.fail` records). At the second advisory FAIL
   of a unit, do **not** stop for the human and do not offer the options above:
   ```
   after:
   ```
   in this session (there are no `.fail` records), and apply the **Escalation
   ladder** with n = that count. At ladder exhaustion, do **not** stop for the human and do not offer the options above:
   ```
6. `agents/orchestrator.md`, before: `reached its second advisory FAIL counts as reviewed. When you dispatch`
   after: `reached ladder exhaustion counts as reviewed. When you dispatch`
7. `agents/orchestrator.md` (## Per-unit model routing, first paragraph), before (lines 430-437, up to and including `surfaced as a re-derived dispatch; treat it as expected when it appears. Per Claude Code's per-invocation model override (env`):
   ```
   When dispatching a unit to `lead-programmer`, check its `Suggested model:
   sonnet|opus` tag and pass it as the dispatch's `model` parameter; omit
   it when absent, so lead-programmer's `model: sonnet` frontmatter is the
   default, not an absolute (ADR-0026 reversed the prior `haiku` default on
   2026-08-25). An `opus` tag passes through identically — it
   normally appears only after a unit hits the 2-FAIL cap (sonnet → FAIL →
   opus → FAIL) and the human chooses option (a) to pursue a debug spec,
   surfaced as a re-derived dispatch; treat it as expected when it appears. Per Claude Code's per-invocation model override (env
   ```
   after:
   ```
   When dispatching a unit to `lead-programmer`, pass the tier the **Escalation
   ladder** below gives as the dispatch's `model` parameter. A `Suggested model: haiku|sonnet|opus`
   tag can raise that tier, never lower it. You may omit the parameter only when
   that tier equals lead-programmer's frontmatter `model:`, which is the default,
   not an absolute (its value and history: CONTEXT.md's **Writer tier** entry). An
   `opus` dispatch after ladder exhaustion is expected when the human chose option
   (a) or (b) at **At the 2-FAIL cap**. Per Claude Code's per-invocation model override (env
   ```
8. `agents/orchestrator.md`, replace the three paragraphs from
   `**Implementer-tier fail ratchet expiry.**` through `above still applies.`
   (lines 456-474: the expiry paragraph, the `**Sonnet units escalate on first FAIL.**`
   paragraph with its fix-contract sentence, and the `**Check for a prior `.fail` record before ANY per-unit dispatch**` paragraph) with:
   ```
   **Escalation ladder.** Each implementer tier gets two attempts at a unit. The
   **default tier** is the `defaultImplementerModel` value resolved above, or
   lead-programmer's frontmatter `model:` when the key is absent. The ladder is
   the tiers from the default tier upward, in the order `haiku`, `sonnet`, `opus`,
   two entries each: from `haiku` it is `haiku`, `haiku`, `sonnet`, `sonnet`,
   `opus`, `opus`; from `sonnet`, `sonnet`, `sonnet`, `opus`, `opus`; from `opus`,
   `opus`, `opus`.

   **Check for a prior `.fail` record before ANY per-unit dispatch**, not only
   right after an in-session FAIL — a fresh session has no memory of a prior
   one's FAIL. Count the unit's FAIL blocks, n: n is 0 when
   `test -f .claude/reviewed/<task-id>.fail` fails, and otherwise
   `grep -c '^FAIL <task-id> ' .claude/reviewed/<task-id>.fail`. Dispatch
   attempt n+1 on the ladder's entry n+1. When n equals the ladder's length,
   that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
   cap**. The ladder depends only on n and the default tier, so a fresh session
   computes the same tier the session that saw the FAIL would have; which tier
   wrote a block is never needed. Fail closed: if n cannot be read (the grep
   errors, or the file exists and no line matches), dispatch on `opus`. Every
   re-dispatch carries the prior defect history; with a fix contract
   (**Fix-contract re-dispatch**), it carries the fix contract instead of the
   bare defect list. The **Implementer-tier ratchet** (CONTEXT.md's **Writer
   tier** and **Implementer-tier ratchet** entries) is this rule: never a tier
   cheaper than the ladder's entry.

   **Implementer-tier fail ratchet expiry.** A fail record for unit `X` stops
   disqualifying `X` from a cheaper implementer tier once a pass marker for `X`
   exists and is newer than the fail record. Until then it disqualifies
   unchanged; while a unit is mid-retry with no PASS yet, nothing expires. An
   expired record counts as n = 0.
   ```
   The line `**Escalation ladder.** Each implementer tier gets two attempts at a unit. The` must stay one line (AC-D7's regex is not wrap-proof).
9. `agents/task-master.md`, replace the bullet from `- **Per-unit model tag**:`
   through `  and is unchanged by this rule.` (lines 104-118) with:
   ```
   - **Per-unit model tag**: tag every sliced unit `Suggested model:
     haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `sonnet` is
     the default for every unit, and a unit you judge security-sensitive,
     structural, or otherwise hard-judgment still starts on the default tier —
     you never pre-emptively tag a unit above it, no matter how risky it looks.
     A higher tag is reachable only one way, reactive to something already on
     record, never to your own risk judgment: check
     `.claude/reviewed/<task-id>.fail` before tagging any unit, count its FAIL
     blocks, and tag the tier the orchestrator's **Escalation ladder** gives for
     that count (`agents/orchestrator.md`); a `.pass` marker newer than the
     `.fail` record means the count is 0, and at ladder exhaustion you tag
     `opus`. The orchestrator recomputes the ladder at dispatch, and your tag can
     raise its tier but never lower it.
   ```
   (`` `sonnet` is `` must end line 2 and `  the default for every unit` must start line 3: AC-D5 pins the line break; U4 changes only `sonnet` to `haiku` there.)
10. `tests/writer-tier-consistency.test.js`, replace the AC-D7 check (lines 73-83) with:
    ```
    check('AC-D7: orchestrator.md states the two-attempts-per-tier Escalation ladder, not a first-FAIL escalation', () => {
      const text = read('agents/orchestrator.md');
      assert.ok(/\*\*Escalation ladder\.\*\* Each implementer tier gets two attempts/.test(text), 'orchestrator.md does not state the Escalation ladder rule');
      assert.ok(!/Sonnet units escalate on first FAIL/.test(text), 'orchestrator.md still states the stale sonnet-first-FAIL escalation rule');
      assert.ok(!/Haiku units escalate on first FAIL/.test(text), 'orchestrator.md still states the stale haiku-first-FAIL escalation rule');
    });
    ```
11. `tests/writer-tier-consistency.test.js`, insert-after the AC-D8 check's closing `});`:
    ```

    check('AC-D8b: the haiku-default ADR pins its forward rule, and ADR-0026 names it', () => {
      const dir = path.join(REPO_ROOT, 'docs', 'adr');
      const hits = fs.readdirSync(dir).filter((f) => /^\d{4}-implementer-tier-haiku-default\.md$/.test(f));
      assert.strictEqual(hits.length, 1, `expected exactly one *-implementer-tier-haiku-default.md ADR, got ${hits.length}`);
      const text = fs.readFileSync(path.join(dir, hits[0]), 'utf8');
      for (const s of ['Amends: ADR-0026', '≥60 units dispatched under the `haiku` default', 'fail-rate ≤ 0.35',
        'escalation-rate ≤ 0.15', 'exhaustion-rate ≤ 0.02', 'tripwire']) {
        assert.ok(text.includes(s), `${hits[0]} does not state ${s}`);
      }
      assert.ok(/^Superseded-in-part-by: ADR-\d{4} /m.test(read('docs/adr/0026-writer-tier-reversed-to-sonnet.md')), 'ADR-0026 lacks its Superseded-in-part-by line');
    });
    ```
12. `tests/writer-tier-consistency.test.js`, the AC-D9 orchestrator check (lines 101-107) becomes:
    ```
    check('AC-D9: agents/orchestrator.md states the three-tier vocabulary and no stale default or ladder', () => {
      const text = stripWhitespace(read('agents/orchestrator.md'));
      assert.ok(!text.includes(stripWhitespace('`model: sonnet` frontmatter is the')), 'orchestrator.md still claims sonnet frontmatter is the default');
      assert.ok(text.includes(stripWhitespace('`Suggested model: haiku|sonnet|opus`')), 'orchestrator.md does not list the haiku|sonnet|opus Suggested model vocabulary');
      assert.ok(!text.includes(stripWhitespace('sonnet → FAIL → opus → FAIL')), 'orchestrator.md still states the ADR-0026 sonnet-first cap path');
      assert.ok(!text.includes(stripWhitespace('never dispatch on `haiku`')), 'orchestrator.md still contains the vacuous never-dispatch-on-haiku clause');
    });
    ```
13. `tests/writer-tier-consistency.test.js` AC-P1 (line 175): the needle `'Sonnet units escalate on first FAIL'` becomes `'**Escalation ladder.**'`; the other five needles stay.
14. Bump `0.31.141` -> `0.31.142` in `.claude-plugin/plugin.json` and `package.json`.
15. `CHANGELOG.md` entry (insert-after `## [Unreleased]` and its blank line):
    `**Escalation ladder: two attempts per implementer tier (htd-3, 0.31.142).** \`agents/orchestrator.md\`: "Sonnet units escalate on first FAIL" is replaced by the Escalation ladder (the tiers from the default tier upward, two attempts each); a tier's second FAIL moves the unit up automatically and only ladder exhaustion asks the human; the tier is recomputed from the FAIL-block count, and an unreadable count dispatches \`opus\`. \`agents/task-master.md\`: \`Suggested model: haiku|sonnet|opus\`, tagged from the ladder. The default tier is unchanged (\`sonnet\`).`
16. command: `node bin/cli.js --update` expect: 0; stage with `git add -u -- .claude`; one commit.

Do NOT touch: `agents/orchestrator.md`'s `**`defaultImplementerModel` config precedence.**`
paragraph (lines 442-454; `tests/default-implementer-model.test.js` pins two of its
sentences), the `**`fable` is excluded for `task-master`**` line, the "Reviewer gate
model selection" section, `hooks/scripts/reviewer-tier.sh`, `agents/lead-programmer.md`,
`agents/spec-master.md`, `CONTEXT.md`, `templates/`, `adapters/`.

Acceptance criteria:
- AC3.1 run: `node tests/writer-tier-consistency.test.js` exit 0, last line `All writer-tier-consistency checks passed.` mutation: re-insert the line `**Sonnet units escalate on first FAIL.**` anywhere in orchestrator.md -> exit 1 (AC-D7 and AC-P1).
- AC3.2 Flattened grep of `agents/orchestrator.md`, each = 1 (0 at `<B>`): `**Escalation ladder.** Each implementer tier gets two attempts at a unit.`, `from `haiku` it is `haiku`, `haiku`, `sonnet`, `sonnet`, `opus`, `opus`;`, `dispatch on `opus`. Every re-dispatch carries`, `An expired record counts as n = 0.`, `After ladder exhaustion, a re-dispatch under (a) or (b) runs on `opus``.
- AC3.3 Flattened grep of `agents/orchestrator.md`, each = 0: `Sonnet units escalate on first FAIL`, `on the ratcheted tier`, `full two-attempt`, `At the second advisory FAIL`, `reached its second advisory FAIL`, `both fix-attempt commits`. mutation: skip ordered edit 1 -> `on the ratcheted tier` = 1.
- AC3.4 Flattened grep of `agents/task-master.md`: `Suggested model: haiku|sonnet|opus` = 1, `first-FAIL escalation` = 0, `never lower it` = 1; and `node -e "const t=require('fs').readFileSync('agents/task-master.md','utf8');process.exit(t.includes('\`sonnet\` is\n  the default for every unit')?0:1)"` exit 0.
- AC3.5 Flattened grep of `agents/orchestrator.md` for `a tier's second FAIL below the top of the **Escalation ladder** is not a stop` = 1, and for `Unresolved advisory findings` ≥ 1 (unchanged).
- AC3.6 `node tests/default-implementer-model.test.js` exit 0 (the precedence and `opus`-fallback sentences intact).
- AC3.7 Mirrors: flattened grep of `.claude/agents/orchestrator.md` for `**Escalation ladder.** Each implementer tier gets two attempts` = 1, and of `.claude/agents/task-master.md` for `Suggested model: haiku|sonnet|opus` = 1.
- AC3.8 `bash hooks/scripts/version-stamp-check.sh <B>..HEAD` stdout starts `version-stamp-check: ok`; `bash tests/validate.sh` exit 0; AC-SCOPE-1 (own: `agents/orchestrator.md`, `agents/task-master.md`, `tests/writer-tier-consistency.test.js`), AC-SCOPE-2, AC-SCOPE-3 excluding `.claude/agents/orchestrator.md` and `.claude/agents/task-master.md`.

## Step U4: the cutover (frontmatter `haiku`, migration on, cutover timestamp)

Affected files: `agents/lead-programmer.md`, `agents/task-master.md`,
`agents/orchestrator.md`, `bin/cli.js`, `templates/persona-config.schema.json`,
`README.md`, `tests/writer-tier-consistency.test.js`, bump files (`<V4>`;
0.31.144 under the htd-5-before-htd-4 order confirmed in the ruling below),
`CHANGELOG.md`, the 14 `.claude/` paths via `--update` (the config's
`defaultImplementerModel` migrates in this commit). Depends on U2 and U3 (and,
by dispatch order only, lands after U5).

Ruling on SPEC-GAP H-htd4 (2026-10-08, spec-master):
- (a) U4 gains ordered edit 4a: the fresh-scaffold skeleton's
  `defaultImplementerModel` becomes the literal `'haiku'`, not a call to
  `implementerFrontmatterDefault()`. Reason: the first check in
  `tests/default-implementer-model.test.js` compares the scaffolded value
  against the frontmatter it reads itself. A skeleton that also read the
  frontmatter would compare the frontmatter with itself and could never fail,
  so it would stop catching drift. The existing code comment says the same
  ("asserted programmatically against that frontmatter, not hardcoded on both
  sides"). The `--update` backfill and the migration already read the
  frontmatter; only the skeleton keeps a literal, because the test needs it.
- (b) In the same edit, the comment above the line changes `model: sonnet` to
  `model: haiku`. Its "item18-2, not yet landed" clause is also out of date
  (the backfill exists), but no criterion covers it and it is outside this gap,
  so it stays as it is.
- (c) AC4.3 stays exactly as it was and gains a mutation line (proved below). It
  belongs in U4 and not U2 because the check passes only when the skeleton
  literal and the lead-programmer frontmatter agree. Flipping the skeleton in U2
  would break U2's own AC2.1, since the frontmatter still says `sonnet` there.
  So the skeleton and the frontmatter must flip in the same commit, and U4 is
  the commit where the frontmatter flips. AC4.10 adds an attributable grep for
  the comment, which no test reads.
- Task-master's judgment call 1 is confirmed: htd-2 writes the migration as the
  column-0 helper `applyImplementerModelMigration(config, dryRun)` plus one call
  line at the plan's insert point. It reads `config.pluginVersion` at the same
  point in `runUpdate`, before the version is rewritten. It prints the same Note
  text and keeps the `migratedImplementerModel` name (AC2.5 still counts at
  least 2). This plan specifies behaviour, not layout.
- Task-master's judgment call 2 is confirmed: htd-5 (U5) is dispatched before
  htd-4 (U4). U5 depends only on U3. Its ladder wording ("from the default tier
  upward: `haiku`, `sonnet`, `opus`") does not depend on any tier, the same as
  U3's, so it reads correctly while the default is still `sonnet`. The swap also
  shortens R6's U3-to-U5 prose-staleness window. The version chain is htd-2
  0.31.141, htd-3 0.31.142, htd-5 0.31.143, htd-4 0.31.144. This replaces R3's
  U4/U5 literals; the rule (HEAD version + 1, re-derived at dispatch) is
  unchanged. AC4.6 compares the constant with `package.json` at run time, so it
  holds for 0.31.144. The migration still fires in this repo, because the
  config records 0.31.143 after U5's `--update` and 0.31.143 is less than
  0.31.144.

Pre-dispatch derivation (orchestrator, immediately before dispatch; written into
the contract as literals): `<B>` = HEAD; `<T0>` =
`TZ=UTC git log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd <B>`;
`<V4>` = HEAD's `package.json` version + 1 patch (0.31.143 if R3 holds).

Ordered edits:
1. `agents/lead-programmer.md` line 4. before: `model: sonnet` after: `model: haiku`.
2. `agents/task-master.md`. before: `  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `sonnet` is`
   after: `  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `haiku` is`
3. `agents/orchestrator.md`, insert-after the line `cheaper than the ladder's entry.` (end of U3's "Check for a prior `.fail` record" paragraph), a blank line and:
   ```
   **Haiku-default cutover: <T0>.** FAIL blocks whose header timestamp is
   earlier than this were written under ADR-0026's `sonnet` default, and the
   count alone cannot say which tier wrote them. Fail closed: a unit with any
   such block uses the ladder that starts at `sonnet` (`sonnet`, `sonnet`,
   `opus`, `opus`), whatever the default tier.
   ```
4. `bin/cli.js`. before: `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;` after: `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = '<V4>';`
4a. `bin/cli.js`, fresh-scaffold skeleton config object (the object literal holding `humanReviewMode: 'critical',`). Two single-line replacements; each before-text occurs exactly once in the file (verified at 7fba8f9, and no earlier unit's contract touches either line):
   - before: ``      // Matches agents/lead-programmer.md's `model: sonnet` frontmatter today`` after: ``      // Matches agents/lead-programmer.md's `model: haiku` frontmatter today`` (only that word changes; 6-space indent kept).
   - before: `      defaultImplementerModel: 'sonnet',` after: `      defaultImplementerModel: 'haiku',` (a string literal; never a call to `implementerFrontmatterDefault()`, per the ruling above).
5. `templates/persona-config.schema.json` line 57. before: `      "default": "sonnet",` after: `      "default": "haiku",`
6. `README.md` line 53. before: `` | `lead-programmer` | sonnet | Always | `` after: `` | `lead-programmer` | haiku | Always | `` (rest of the row unchanged).
7. `tests/writer-tier-consistency.test.js`, the three AC-D5 lead/README checks (lines 37-50): every `'sonnet'` expected value and the regex `/\|\s*sonnet\s*\|/` become `'haiku'` and `/\|\s*haiku\s*\|/`; the titles read `model: haiku` / `as haiku`.
8. `tests/writer-tier-consistency.test.js`, the AC-D5 task-master check (lines 52-56) becomes:
   ```
   check('AC-D5: agents/task-master.md default tag is haiku, not sonnet', () => {
     const text = read('agents/task-master.md');
     assert.ok(text.includes('`haiku` is\n  the default for every unit'), 'task-master.md does not state haiku as the default tag');
     assert.ok(!text.includes('`sonnet` is\n  the default'), 'task-master.md still states sonnet as the default tag');
   });
   ```
9. `tests/writer-tier-consistency.test.js`, insert-after the AC-D8b check's closing `});`:
   ```

   check('AC-D10: this repo\'s own defaultImplementerModel resolves to the lead-programmer frontmatter default', () => {
     const cli = require(path.join(REPO_ROOT, 'bin', 'cli.js'));
     const config = JSON.parse(read(path.join('.claude', 'persona-config.json')));
     const fm = frontmatterModel(read('agents/lead-programmer.md'));
     assert.strictEqual(cli.resolveDefaultImplementerModel(config, fm), fm);
   });

   check('AC-D11: orchestrator.md states exactly one Haiku-default cutover timestamp', () => {
     const hits = read('agents/orchestrator.md').match(/\*\*Haiku-default cutover: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\.\*\*/g) || [];
     assert.strictEqual(hits.length, 1, `expected one cutover line, got ${hits.length}`);
   });
   ```
   Edit this file with the Edit tool (R5): a Bash heredoc spelling the config's file name is refused.
10. Bump HEAD's version (0.31.143 once U5 has landed) -> `<V4>` in `.claude-plugin/plugin.json` and `package.json`.
11. `CHANGELOG.md` entry:
    `**Implementer tier defaults to haiku (htd-4, <V4>).** \`agents/lead-programmer.md\` frontmatter is \`model: haiku\` and the \`defaultImplementerModel\` schema default is \`"haiku"\` (ADR <NNNN>, amending ADR-0026). \`--update\` migrates a recorded \`"sonnet"\` from before this version to \`"haiku"\` once and says so; set it back to keep a \`sonnet\`-first ladder. \`agents/orchestrator.md\` records the haiku-default cutover: FAIL blocks older than it start the unit's ladder at \`sonnet\`.`
12. command: `node bin/cli.js --update` expect: 0, stdout contains `migrated to "haiku"`. Stage with `git add -u -- .claude`; one commit.

Do NOT touch: `agents/scribe.md`, `hooks/scripts/reviewer-tier.sh`, `adapters/`,
`CONTEXT.md`, the orchestrator paragraphs U3 wrote other than the insertion point.

Acceptance criteria:
- AC4.1 run: `sed -n '1,12p' agents/lead-programmer.md | grep -c '^model: haiku$'; sed -n '1,12p' .claude/agents/lead-programmer.md | grep -c '^model: haiku$'; sed -n '1,12p' agents/scribe.md | grep -c '^model: haiku$'` stdout: `1`, `1`, `1` (the first two are `0` at `<B>`).
- AC4.2 run: `node tests/writer-tier-consistency.test.js` exit 0. mutation: revert ordered edit 1 -> exit 1 (AC-D5 and AC-D10).
- AC4.3 run: `node tests/default-implementer-model.test.js` exit 0; `node tests/cli-backfill.test.js` exit 0. mutation: skip the second bullet of ordered edit 4a, so the skeleton stays `'sonnet'` -> `node tests/default-implementer-model.test.js` exits 1, and its check `a fresh scaffold emits defaultImplementerModel agreeing with agents/lead-programmer.md frontmatter` prints `fresh-install skeleton must ship defaultImplementerModel: "haiku", got "sonnet"`. proof (spec-master, 2026-10-08, scratch copy of 7fba8f9): with only edit 1 applied, that check FAILed and the suite exited 1. With edit 1 plus the 4a literal applied, the check printed `OK`. Restored with `git checkout`.
- AC4.10 run: `grep -cF "agents/lead-programmer.md's \`model: haiku\` frontmatter today" bin/cli.js; grep -cF "agents/lead-programmer.md's \`model: sonnet\` frontmatter today" bin/cli.js; grep -c "^      defaultImplementerModel: 'haiku',$" bin/cli.js` stdout: `1`, `0`, `1` (at `<B>`: `0`, `1`, `0`). mutation: skip the first bullet of edit 4a -> the first two counts print `0`, `1`.
- AC4.4 run: `grep -cE '^\*\*Haiku-default cutover: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\.\*\*' agents/orchestrator.md .claude/agents/orchestrator.md` stdout: `:1` for both files.
- AC4.5 run: `grep -oE 'Haiku-default cutover: [0-9TZ:-]+' agents/orchestrator.md | grep -oE '[0-9]{4}[0-9TZ:-]+'` stdout equals `<T0>` from the contract, and `<T0>` equals `TZ=UTC git log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd <B>`.
- AC4.6 run: `node -e "const c=require('./bin/cli.js');process.exit(c.IMPLEMENTER_HAIKU_DEFAULT_SINCE===require('./package.json').version&&require('./templates/persona-config.schema.json').properties.defaultImplementerModel.default==='haiku'?0:1)"` exit 0. mutation: leave the constant `null` -> exit 1.
- AC4.7 The migration is live in this repo and discriminating. run: `node tests/writer-tier-consistency.test.js` (AC-D10) and `node tests/default-implementer-model.test.js` (U2's `--update applies migrateDefaultImplementerModel` check, which now expects `haiku`), both exit 0. mutation: with `IMPLEMENTER_HAIKU_DEFAULT_SINCE` left `null`, the `--update` of ordered edit 12 does not migrate, the committed config keeps `"sonnet"`, and AC-D10 fails (`sonnet` != `haiku`). The reviewer also reads the committed config with the Read tool (never Bash): `"defaultImplementerModel": "haiku"`.
- AC4.8 run: `grep -c '| `lead-programmer` | haiku |' README.md` stdout `1`.
- AC4.9 `bash hooks/scripts/version-stamp-check.sh <B>..HEAD` stdout starts `version-stamp-check: ok`; `bash tests/validate.sh` exit 0; AC-SCOPE-1 (own: the seven Affected source files), AC-SCOPE-2, AC-SCOPE-3 excluding `.claude/agents/lead-programmer.md`, `.claude/agents/task-master.md`, `.claude/agents/orchestrator.md`; `git diff --quiet <B>..HEAD -- adapters hooks/scripts/reviewer-tier.sh agents/scribe.md` exit 0.

## Step U5: shared protocol states the per-tier cap

Affected files: `templates/persona-protocol.md`, `agents/spec-master.md`,
`commands/start-feature-team.md`, bump files (0.31.144), `CHANGELOG.md`, the 14
`.claude/` paths via `--update`. Depends on U3.

Ordered edits:
1. `templates/persona-protocol.md` (Review ownership, review gating off). before:
   `means the reviewer returned an advisory PASS, or the unit reached its second`
   + next line `advisory FAIL and the orchestrator listed the remaining findings and moved`
   after: `means the reviewer returned an advisory PASS, or the unit reached ladder`
   + `exhaustion on advisory FAILs and the orchestrator listed the remaining findings and moved`
2. `templates/persona-protocol.md` (Third verdict). before:
   `the 2-FAIL cap (a unit stops being re-dispatched to `lead-programmer` after`
   + `its second `.fail` record) counts `.fail` records only, unchanged. When the reviewer`
   after: `the 2-FAIL cap (two FAILs per implementer tier, after which the unit moves up`
   + `the orchestrator's Escalation ladder, stopping only at ladder exhaustion) counts `.fail` records only, unchanged. When the reviewer`
3. `templates/persona-protocol.md` (Fourth verdict, Cap accounting). before:
   `2-FAIL cap (a unit stops being re-dispatched to `lead-programmer` after its`
   + `second `.fail` record) counts `.fail` records only, unchanged.`
   after: `2-FAIL cap (two FAILs per implementer tier, after which the unit moves up the`
   + `orchestrator's Escalation ladder, stopping only at ladder exhaustion) counts `.fail` records only, unchanged.`
4. `templates/persona-protocol.md` (Continuing after a FAIL verdict), replace the
   paragraph starting `**Cap at 2 FAILs per unit.**` and ending `will close it.` with:
   ```
   **Cap at 2 FAILs per tier.** Each implementer tier gets two attempts at a
   unit. A unit's second FAIL on one tier hands it, automatically, to the next
   tier of the orchestrator's **Escalation ladder** (the tiers from the default
   tier upward: `haiku`, `sonnet`, `opus`), with the full defect history; no
   human stop happens there. Only the second FAIL on the ladder's top tier,
   ladder exhaustion, stops re-dispatch: the orchestrator (or team lead) then
   surfaces the full defect history to the human and asks how to proceed,
   rather than spawning a further attempt on its own authority. Which choices
   the human is offered, and what each one does, are defined in one place
   only — the orchestrator's own "At the 2-FAIL cap" section — and are pointed
   at from here rather than restated, so a later amendment cannot leave two
   copies disagreeing. A unit that exhausts the ladder usually means the plan
   itself has a gap, not that one more automated pass will close it.
   ```
5. `agents/spec-master.md` (Debug spec bullet). before: `  cap ("Cap at 2 FAILs per unit") — a focused diagnostic artifact, never a`
   after: `  cap ("Cap at 2 FAILs per tier") — a focused diagnostic artifact, never a`
6. `commands/start-feature-team.md`. before (two lines):
   `2-FAIL cap: on a second FAIL for the same unit, stop re-delegating and`
   + `surface the full defect history to the user instead. "Done" is enforced`
   after (three lines):
   `2-FAIL cap, which is per implementer tier: a tier's second FAIL moves the unit up`
   + `the orchestrator's Escalation ladder, and only at ladder exhaustion do you stop`
   + `re-delegating and surface the full defect history to the user instead. "Done" is enforced`
7. Bump `<V4>` -> `<V4>+1` (0.31.144); CHANGELOG entry:
   `**Shared protocol: the 2-FAIL cap is per implementer tier (htd-5, 0.31.144).** \`templates/persona-protocol.md\`: "Cap at 2 FAILs per tier" — a tier's second FAIL moves the unit up the Escalation ladder; only ladder exhaustion reaches the human. Same wording in \`commands/start-feature-team.md\`; \`agents/spec-master.md\` quotes the new label. The codex and cursor ports keep their per-unit cap (no per-dispatch model routing there).`
8. command: `node bin/cli.js --update` expect: 0; stage with `git add -u -- .claude`; one commit.

Do NOT touch: `adapters/` (D10), `templates/persona-protocol-slim.md`,
`templates/protocol-digest.md`, any section heading in `templates/persona-protocol.md`
(the parity test probes headings), `agents/orchestrator.md`.

Acceptance criteria:
- AC5.1 Flattened grep of `templates/persona-protocol.md`: `**Cap at 2 FAILs per tier.**` = 1, `Cap at 2 FAILs per unit` = 0, `second `.fail` record` = 0 (2 at `<B>`), `reached its second advisory FAIL` = 0, `stopping only at ladder exhaustion` = 2. mutation: skip ordered edit 3 -> `second `.fail` record` = 1.
- AC5.2 run: `grep -l 'Cap at 2 FAILs per tier' .claude/agents/*.md | sort` stdout exactly `.claude/agents/lead-programmer.md`, `.claude/agents/orchestrator.md`, `.claude/agents/spec-master.md` (the three mirrors that inline the paragraph at e0944bf, verified), and `grep -c 'Cap at 2 FAILs per unit' .claude/agents/*.md | grep -vc ':0$'` stdout `0`. mutation: skip `node bin/cli.js --update` -> the first list is empty.
- AC5.3 Flattened grep of `agents/spec-master.md` for `("Cap at 2 FAILs per tier")` = 1; of `commands/start-feature-team.md` for `only at ladder exhaustion do you stop` = 1.
- AC5.4 `git diff --quiet <B>..HEAD -- adapters templates/persona-protocol-slim.md templates/protocol-digest.md` exit 0; `node tests/adapter-protocol-parity.test.js` exit 0.
- AC5.5 `node tests/writer-tier-consistency.test.js` exit 0 (AC-D9's spec-master check intact); `node tests/cli-backfill.test.js` exit 0.
- AC5.6 `bash hooks/scripts/version-stamp-check.sh <B>..HEAD` stdout starts `version-stamp-check: ok`; `bash tests/validate.sh` exit 0 (its mirror-parity checks fail on any hand-edited mirror); AC-SCOPE-1 (own: `templates/persona-protocol.md`, `agents/spec-master.md`, `commands/start-feature-team.md`), AC-SCOPE-2.

## Step U6: glossary for the ladder; AC-D5's CONTEXT literal

Affected files: `CONTEXT.md`, `docs/harness-glossary.md`,
`tests/writer-tier-consistency.test.js`. No version-stamped path, no bump.
Depends on U4 and U5. `<NNNN>` = the ADR number from U1.

Ordered edits:
1. `CONTEXT.md` **Implementer-tier ratchet** entry body. before:
   ```
     tier scaling. A unit's `.claude/reviewed/<task-id>.fail` record (from a
     prior FAIL verdict) permanently removes access to cheaper tiers, forcing
     `sonnet`→`opus` on re-attempt. This ratchet expires on a
   ```
   after:
   ```
     tier scaling. A unit's `.claude/reviewed/<task-id>.fail` record (from prior
     FAIL verdicts) forbids any tier cheaper than the [[Escalation ladder]] gives
     for its FAIL-block count: two attempts per tier, `haiku`→`sonnet`→`opus`. This ratchet expires on a
   ```
2. `CONTEXT.md` **Writer tier** entry. before:
   ```
   the lead-programmer's (implementer's) model tier, defaulting to
     `sonnet` as of ADR-0026 (reversing ADR-0010's earlier `haiku` default).
   ```
   after:
   ```
   the lead-programmer's (implementer's) model tier, defaulting to
     `haiku` as of ADR-<NNNN> (amending ADR-0026's `sonnet`, which had reversed ADR-0010's `haiku`).
   ```
   and before: `  applies when a unit fails: a `.fail` record forces `opus` on re-attempt.`
   after: `  applies when a unit fails: each tier gets two attempts before the next (the [[Escalation ladder]]).`
3. `CONTEXT.md` **Suggested model vocabulary**. before: `` `Suggested model: sonnet|opus`. Pinned as a cross-file invariant by``
   after: `` `Suggested model: haiku|sonnet|opus`. Pinned as a cross-file invariant by``; and before:
   `` `haiku` (pre-ADR-0026); see [[Writer tier]] and [[Implementer-tier ratchet]]`` after:
   `` `haiku` before ADR-0026 and was `sonnet|opus` under it; see [[Writer tier]] and [[Implementer-tier ratchet]]``
4. `CONTEXT.md` **defaultImplementerModel**. before: `(`defaultImplementerModel: "sonnet"|"opus"`)`
   after: `(`defaultImplementerModel: "haiku"|"sonnet"|"opus"`)`. Then, at the entry's
   last line, before: `  [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).`
   after: `` [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md). A recorded `"sonnet"` from before the haiku default shipped is migrated once to `"haiku"` by `--update` (ADR-<NNNN>).`` (keep the two leading spaces; the anchor is the occurrence directly above `**Reviewer-gate ratchet**:`).
5. `CONTEXT.md` new entries, inserted directly after the **Writer tier** entry (one blank line between entries):
   ```
   **Escalation ladder**:
   (ADR-<NNNN>, 2026-10-08) — the order of implementer tiers a unit moves
     through on FAIL: the tiers from the default tier upward (`haiku`, `sonnet`,
     `opus`), two attempts each. The next tier is a function of the unit's
     FAIL-block count alone, so a session with no memory of earlier FAILs
     computes the same tier. A unit with a FAIL block older than the
     haiku-default cutover starts its ladder at `sonnet`. See [[ladder
     exhaustion]] and [[Implementer-tier ratchet]].
   _Avoid_: handoff (names the cutoff handoff), first-FAIL escalation (the ADR-0026 rule this replaced)

   **ladder exhaustion**:
   (ADR-<NNNN>, 2026-10-08) — a unit's second FAIL on the top tier of its
     [[Escalation ladder]]: the only point at which the orchestrator stops
     re-dispatching and asks the human, offering the options of the 2-FAIL cap.
     A lower tier's second FAIL moves the unit up automatically.
   _Avoid_: "the 2-FAIL cap" for this stop alone (the 2-FAIL cap is per tier)
   ```
6. `CONTEXT.md` **review gating off**. before: `  stay armed. Absent or junk values mean `enforce`. At a unit's second`
   + `  advisory FAIL the orchestrator reports `Unresolved advisory findings` and`
   after: `  stay armed. Absent or junk values mean `enforce`. At a unit's [[ladder exhaustion]]`
   + `  on advisory FAILs the orchestrator reports `Unresolved advisory findings` and`
7. `CONTEXT.md` **parked unit**. before: `  at the 2-FAIL cap (see [[FAIL routing (post-reviewer)]]): the orchestrator`
   after: `  at [[ladder exhaustion]] (see [[FAIL routing (post-reviewer)]]): the orchestrator`;
   before: `  the two-attempt defect history standing. No marker is written and none is`
   after: `  the full defect history standing. No marker is written and none is`
8. `docs/harness-glossary.md` **FAIL routing (post-reviewer)**. before:
   `  `lead-programmer` (unchanged). At the 2-FAIL cap, the orchestrator surfaces`
   + `  the two-attempt defect history and asks the human (via `AskUserQuestion`) how`
   after: `  `lead-programmer` (unchanged); a tier's second FAIL moves the unit up the`
   + `  Escalation ladder. At ladder exhaustion, the orchestrator surfaces`
   + `  the full defect history and asks the human (via `AskUserQuestion`) how`
9. `tests/writer-tier-consistency.test.js`, the AC-D5 CONTEXT check (lines 58-62) becomes:
   ```
   check('AC-D5: CONTEXT.md Implementer-tier ratchet reads two attempts per tier, haiku→sonnet→opus', () => {
     const text = read('CONTEXT.md');
     assert.ok(text.includes('two attempts per tier, `haiku`→`sonnet`→`opus`'), 'CONTEXT.md does not state the two-attempts-per-tier ratchet');
     assert.ok(!text.includes('`sonnet`→`opus` on re-attempt'), 'CONTEXT.md still states the stale sonnet→opus re-attempt ratchet');
   });
   ```

Do NOT touch: `agents/`, `templates/`, any other glossary entry, ADR files.

Acceptance criteria:
- AC6.1 run: `grep -c '^\*\*Escalation ladder\*\*:$' CONTEXT.md; grep -c '^\*\*ladder exhaustion\*\*:$' CONTEXT.md` stdout `1`, `1` (0 at `<B>`).
- AC6.2 Flattened grep of `CONTEXT.md`: `two attempts per tier, `haiku`→`sonnet`→`opus`` = 1; `forcing `sonnet`→`opus` on re-attempt` = 0; `Suggested model: haiku|sonnet|opus` = 1; `"haiku"|"sonnet"|"opus"` = 1; `the two-attempt defect history` = 0. Flattened grep of `docs/harness-glossary.md`: `the two-attempt defect history` = 0, `At ladder exhaustion, the orchestrator surfaces` = 1.
- AC6.3 run: `node tests/writer-tier-consistency.test.js` exit 0. mutation: restore the old ratchet sentence in CONTEXT.md -> exit 1.
- AC6.4 `git diff --name-only <B>..HEAD | sort` stdout exactly `CONTEXT.md`, `docs/harness-glossary.md`, `tests/writer-tier-consistency.test.js`; `bash tests/validate.sh` exit 0.

## Step U7: the exporter infers `haiku` from the cutover

Affected files: `scripts/unit-outcomes.js`, `tests/unit-outcomes.test.js`,
`tests/fixtures/unit-outcomes/markers/fx-era-4.pass` (new). No version-stamped
path. Depends on U4.

Ordered edits:
1. `scripts/unit-outcomes.js`, before:
   ```
   // Implementer tier by era when no transcript meta exists (ADR-0010, ADR-0026).
   function eraTier(ts) {
     const t = Date.parse(ts);
     return t >= Date.parse('2026-08-02') && t < Date.parse('2026-08-25') ? 'haiku' : 'sonnet';
   }
   ```
   after:
   ```
   // The haiku-default cutover (ADR-<NNNN>), read from the orchestrator's own
   // literal so the two cannot drift; null if the line is absent.
   const HAIKU_CUTOVER = (() => {
     try {
       const text = fs.readFileSync(path.join(__dirname, '..', 'agents', 'orchestrator.md'), 'utf8');
       const m = text.match(/\*\*Haiku-default cutover: (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\.\*\*/);
       return m ? m[1] : null;
     } catch (_) {
       return null;
     }
   })();

   // Implementer tier by era when no transcript meta exists (ADR-0010, ADR-0026, ADR-<NNNN>).
   // Only the default tier of the era: a laddered unit's later tiers are not inferred.
   function eraTier(ts) {
     const t = Date.parse(ts);
     if (HAIKU_CUTOVER && t >= Date.parse(HAIKU_CUTOVER)) return 'haiku';
     return t >= Date.parse('2026-08-02') && t < Date.parse('2026-08-25') ? 'haiku' : 'sonnet';
   }
   ```
   (Confirm `fs` and `path` are already required at the top of the file; add the
   `require` only if missing.)
2. New file `tests/fixtures/unit-outcomes/markers/fx-era-4.pass`, one line:
   `PASS fx-era-4 2026-12-01T10:00:00Z commit: none criteria: fixture`
3. `tests/unit-outcomes.test.js`, insert-after the `'era from 08-25 sonnet'` check:
   a check `'era from the haiku-default cutover haiku'` that runs the exporter over
   the same fixture set with `--until=2027-01-01T00:00:00Z` (the existing `rows`
   helper takes the cutoff) and asserts `fx-era-4`'s `implementer_tiers` deep-equals
   `[{ tier: 'haiku', source: 'era-inferred' }]` and `fx-era-3`'s is still
   `[{ tier: 'sonnet', source: 'era-inferred' }]`. The existing `CUTOFF`
   (2026-09-15) runs exclude fx-era-4, so no existing assertion changes; if one
   does, STOP and report a spec gap.

Do NOT touch: the G3 gate code, `agents/`, the other era fixtures.

Acceptance criteria:
- AC7.1 run: `node tests/unit-outcomes.test.js` exit 0. mutation: delete the `if (HAIKU_CUTOVER && ...)` line -> exit 1.
- AC7.2 run: `node -e "const t=require('fs').readFileSync('agents/orchestrator.md','utf8');process.exit(/\*\*Haiku-default cutover: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\.\*\*/.test(t)?0:1)"` exit 0 (the literal the exporter reads exists).
- AC7.3 run: `git grep -c "2026-08-25" scripts/unit-outcomes.js` unchanged from `<B>` (the old era boundaries stay).
- AC7.4 `git diff --name-only <B>..HEAD | sort` stdout exactly the three Affected files; `bash tests/validate.sh` exit 0.

## Open Questions

1. (non-blocking named assumption; U3 uses the default) Does `opus` get two attempts before the human is asked, like `haiku` and `sonnet`? Recommended default: **yes, two** (uniform per-tier cap; ladder exhaustion is the sixth FAIL from a `haiku` default). Alternative: one `opus` attempt (exhaustion at the fifth FAIL): U3 edit 8's ladder lists end in one `opus`, and the ADR's exhaustion threshold becomes `fail_blocks>=5`. Origin: Clarifications cat. 3, CHK3.

## Self-check
- CHK1: Does every Goal-table clause map to a unit criterion? — PASS
- CHK2: Is the interaction between config precedence (this repo's `"sonnet"`) and the frontmatter flip defined, so the flip is not inert? — FAIL (missing) — revised in place (D1, D2, U2, AC4.7, AC-D10)
- CHK3: Is the number of `opus` attempts before the human defined? — FAIL (ambiguous: the user's wording names a sonnet cap only) — converted to Open Question 1
- CHK4: Do U3 and U4 agree on the AC-D5 task-master line break (`` `X` is\n  the default for every unit``)? — PASS (U3 edit 9 keeps the break; U4 edit 2 changes one word; ledger rows)
- CHK5: Is fail-closed handling defined for a fresh session, an unreadable count, and pre-cutover blocks? — PASS (D4, D6, U3 edit 8, U4 edit 3)
- CHK6: Is it defined what tier a re-dispatch after ladder exhaustion uses? — FAIL (missing) — revised in place (D7, U3 edit 4)
- CHK7: Do the two sentences `tests/default-implementer-model.test.js:92,107` pin survive U3? — PASS (Do NOT touch, AC3.6)
- CHK8: Does every persona/template unit carry the plugin.json + package.json bump, CHANGELOG, `--update`, and `version-stamp-check`? — PASS (U2, U3, U4, U5)
- CHK9: Is every pinned test literal that changes listed with its unit? — PASS (Pinned-literal ledger)
- CHK10: Does any `run:` spell the reviewed-marker directory or a Set A file name? — FAIL (conflicting: AC4.7 first read the config in Bash) — revised in place (AC-D10 reads it inside the test; the reviewer uses the Read tool)
- CHK11: Is the review-gating-off behaviour under the ladder defined? — PASS (D8, U3 edits 5-6, U5 edit 1, U6 edit 6)
- CHK12: Is the forward rule machine-checkable and its consequence stated? — PASS (Draft ADR; AC1.6 runs it on real data)
- CHK13: Are the codex/cursor ports' handling and the protocol amendment's reach defined? — PASS (D10, U5, AC5.2, AC5.4)
- CHK14: Is the old programme's Stage 4/5 disposition recorded where a fresh reader of that plan sees it? — PASS (U1 edit 4, AC1.7)
- CHK15 (replay, class vacuous: gh307, gh310, gh348-14, gh429 touched `agents/orchestrator.md`): Do AC3.2, AC3.3, AC4.4 still fail under their own `mutation:` lines? — PASS (each new phrase is 0 at `<B>`; AC3.3 names its mutation; AC4.4 is `:0` at `<B>`)
- CHK16 (replay, classes vacuous/host: gh348-4, gh360, gh377-5, gh409, gh413, item04-2-apply-drops, mw-step3 touched `bin/cli.js`): Do AC2.2, AC2.4, AC4.6 still fail under their own `mutation:` lines? — PASS (each names a mutation flipping its exit or output)
- CHK17 (replay, class vacuous: gh348-3, mw-step1, mw-step2, mw-step3 touched `templates/persona-protocol.md`): Does AC5.1 still fail under its `mutation:` line? — PASS
- CHK18 (replay, classes vacuous/host: gh-303, gh339, gh354, gh409, gh426, gh429, human-review-cleanup-1, spec2-unitA, spec2-unitB, ci-fetch-depth-cleanup touched `CONTEXT.md`): Does AC6.3 still fail under its `mutation:` line? — PASS
- CHK19 (replay, classes host/vacuous: adhoc-preload-tdd-skill, item17-3-wire-p3-check, mw-step1, mw-step3 touched `agents/lead-programmer.md`): Does AC4.2 still fail under its `mutation:` line? — PASS
- CHK20 (ubiquitous-language, advisory): Does the plan use "handoff" for the tier move-up? — PASS (only in the ADR's `_Avoid_` line and the user's quoted ruling context; the plan says "moves the unit up" / "hands it to the next tier")

## Out of scope / parked
- Recording the implementer tier inside FAIL blocks (marker format v3 is unchanged; D4 makes it unnecessary).
- A shipped `implementer-tier.sh` helper beside `reviewer-tier.sh` (eight touch points per the explorer; the table lookup on a `grep -c` count is deterministic enough). Revisit if AC-replays show orchestrator miscounts.
- Inferring a laddered unit's later tiers in the exporter (U7 infers the era's default tier only).
- spec-master's debug-spec wording "first and second tries" (R9).
- The rubric programme's Stage 4 (parked) and its G4 gate (overridden).
- Any change to `hooks/scripts/reviewer-tier.sh` or the reviewer-gate ratchet.
- Spend as a verdict-bearing term in the forward rule.

## Scribe update hint
After U1: nothing beyond the ADR itself. After U6 (which writes the glossary
entries in-unit, because AC-D5 couples CONTEXT.md to the test):
`docs/harness-glossary.md` may gain a **Haiku-default cutover** entry (the
orchestrator literal, its derivation from U4's baseline commit, and its two
readers: the legacy rule and the exporter). Avoid "handoff" for the tier move-up,
and "first-FAIL escalation" except when naming the ADR-0026 rule.

## Dispatch
Seven units, so this plan goes to `task-master` (standard path): it slices U1-U7
into issues under `plan/2026-10-08-haiku-default-tier`, tags each unit's
`Suggested model` (never below the default tier; R1), writes the nine-element
contracts (scribe shape for U1), and re-derives `<V*>`, `<NNNN>`, `<B>` and
`<T0>` literals at dispatch per R3 and U4's pre-dispatch derivation.
