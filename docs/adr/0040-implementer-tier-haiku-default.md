# ADR 0040: Implementer tier defaults to `haiku`, two attempts per tier

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
   the unit's ladder at the more capable of `sonnet` and the default tier.
   Ladder exhaustion is a FAIL-block count that reaches or exceeds the ladder's
   length.
4. The reviewer-gate ratchet (`hooks/scripts/reviewer-tier.sh`, ADR-0009) is
   unchanged. The exporter, the contract rubric and the audits stay.
5. Contract-score guard (amendment, csg-3): before every dispatch of a unit
   whose ladder starts at `haiku`, the orchestrator scores the unit's contract
   of record with `node bin/contract-guard.js` (rubric v2). Unless every row
   passes (lead shape: and the contract is not oversize), the unit uses the
   ladder that starts at `sonnet`. Scoring is pure, so the check re-runs on
   every dispatch; each demotion appends a `decision=contract-guard sonnet:`
   line to `.claude/orchestrator-rulings.log`.

## Forward rule (pre-registered)

**After ≥60 units dispatched under the `haiku` default** (units in a fresh
`node scripts/unit-outcomes.js` export with `terminal_ts` at or after the
**Haiku-default cutover** timestamp in `agents/orchestrator.md`, except the
`htd-` units of the haiku-default programme itself, which were dispatched on
`sonnet` before the flip and closed after the cutover, and except units with a
`decision=contract-guard sonnet:` line in `.claude/orchestrator-rulings.log`,
which the contract-score guard kept off `haiku`), all three must hold:

- fail-rate ≤ 0.35 (units with at least one FAIL block / units)
- escalation-rate ≤ 0.15 (units with at least two FAIL blocks, i.e. that left
  `haiku` / units)
- exhaustion-rate ≤ 0.02 (units with at least six FAIL blocks / units)

Early tripwire: while the population holds 20 to 59 units, an escalation-rate
above 0.30 or two exhausted units ends the trial early with the same
consequence. From 60 units only the three rates above decide; two exhausted
units then fail the rule only through the exhaustion-rate.

Audit command, run from the repository root (`<F>` the export file, `<T0>` the
cutover timestamp). It reads `.claude/orchestrator-rulings.log`, a per-clone
file, so it runs in the clone that dispatched the units; a missing log stops it
rather than counting guard-demoted units. The number of units it leaves out for
the guard is reported alongside, for information:
`grep -oE 'unit=[^ ]+ decision=contract-guard sonnet:' .claude/orchestrator-rulings.log | sort -u | wc -l`.

    jq -rs --arg t0 "<T0>" --rawfile r .claude/orchestrator-rulings.log '[$r | scan("(?m)^RULING \\S+ unit=(\\S+) decision=contract-guard sonnet:") | .[0]] as $g | [.[] | select(.terminal_ts >= $t0 and (.id | startswith("htd-") | not) and (.id as $i | $g | index([$i]) | not))] as $p | ($p|length) as $n | ($p|map(select(.fail_blocks>=1))|length) as $f1 | ($p|map(select(.fail_blocks>=2))|length) as $f2 | ($p|map(select(.fail_blocks>=6))|length) as $f6 | if $n < 20 then "insufficient" elif $n < 60 then (if ($f2/$n) > 0.30 or $f6 >= 2 then "tripwire" else "insufficient" end) elif ($f1/$n) <= 0.35 and ($f2/$n) <= 0.15 and ($f6/$n) <= 0.02 then "met" else "not-met" end' <F>

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

## Amendments

- 2026-10-08 (hdc-4, `docs/plans/2026-10-08-haiku-default-cleanup.md`): the
  legacy ladder starts at the more capable of `sonnet` and the default tier;
  ladder exhaustion is a count that reaches or exceeds the ladder length; the
  early tripwire is bounded to 20-59 units, matching the audit command; the
  forward-rule population excludes the `htd-` units, which ran on `sonnet` and
  closed after the cutover. No threshold changed.
- 2026-10-08 (csg-3, `docs/plans/2026-10-08-contract-score-guard.md`): Decision
  item 5 adds the contract-score guard; the forward-rule population also
  excludes the units the guard kept off `haiku`, which the audit command reads
  from `.claude/orchestrator-rulings.log`. No threshold changed.
