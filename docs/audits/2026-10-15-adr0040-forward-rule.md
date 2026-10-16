# ADR-0040 forward-rule audit (implementer tier, record only)

Record of the implementer-tier evidence at 77 population units. Scope by user ruling (2026-10-15): record the audit and change nothing. No config, ADR rule or persona change follows from it. ADR-0040's forward rule is past its 60-unit threshold and prints its pass verdict, so the `haiku` default stands.

The export file is not committed (it is a local, per-clone artefact built from the transcript store and the markers, like `docs/audits/unit-outcomes/`). The commands below regenerate it.

cutover: 2026-10-08T17:28:48Z (the **Haiku-default cutover** line in `agents/orchestrator.md`)
pinned-until: 2026-10-15T06:00:00Z
repo-head-at-audit: caf53df

## Export

    node scripts/unit-outcomes.js --until=2026-10-15T06:00:00Z --out=<F>

`<F>` is any path. `--until` pins the export, so later units and later FAIL blocks do not enter it. The export took several minutes on this clone (transcript scan).

## Audit command (verbatim from ADR-0040, `<T0>` = the cutover above)

    jq -rs --arg t0 "2026-10-08T17:28:48Z" --rawfile r .claude/orchestrator-rulings.log '[$r | scan("(?m)^RULING \\S+ unit=(\\S+) decision=contract-guard sonnet:") | .[0]] as $g | [.[] | select(.terminal_ts >= $t0 and (.id | startswith("htd-") | not) and (.id as $i | $g | index([$i]) | not))] as $p | ($p|length) as $n | ($p|map(select(.fail_blocks>=1))|length) as $f1 | ($p|map(select(.fail_blocks>=2))|length) as $f2 | ($p|map(select(.fail_blocks>=6))|length) as $f6 | if $n < 20 then "insufficient" elif $n < 60 then (if ($f2/$n) > 0.30 or $f6 >= 2 then "tripwire" else "insufficient" end) elif ($f1/$n) <= 0.35 and ($f2/$n) <= 0.15 and ($f6/$n) <= 0.02 then "met" else "not-met" end' <F>

Output:

met

Counts, from the same filter printing `"n=\($n) f1=\($f1) f2=\($f2) f6=\($f6)"` instead of the verdict:

    n=77 f1=6 f2=2 f6=0

- fail-rate 6/77 = 0.078 (limit 0.35)
- escalation-rate 2/77 = 0.026 (limit 0.15)
- exhaustion-rate 0/77 = 0 (limit 0.02)

Guard demotions excluded: 13 units (`grep -oE 'unit=[^ ]+ decision=contract-guard sonnet:' .claude/orchestrator-rulings.log | sort -u | wc -l` prints 13). The log is a per-clone file; this audit ran in the clone that dispatched the units.

## Post-cutover all-units figure

The same population without the guard exclusion (still excluding `htd-`): 90 units, 6 with at least one FAIL block, so 6/90 = 0.067. The 13 demoted units had no FAIL block at all (0/13), so excluding them does not flatter the rule.

    jq -rs --arg t0 "2026-10-08T17:28:48Z" '[.[]|select(.terminal_ts>=$t0 and (.id|startswith("htd-")|not))] | "all n=\(length) f1=\(map(select(.fail_blocks>=1))|length)"' <F>

prints `all n=90 f1=6`.

## Per-path-class breakdown

Class of a unit: `sensitive` when any commit with the unit id in its subject scope (`type(<id>)`, optionally in a comma list) and committed at or before the pinned `--until` touches `hooks/`, `agents/` or `templates/`; otherwise `other`. All 90 units had at least one scoped commit, so no unit is unattributed. This is a scope-join, not a range diff: a unit committed without its id in the scope would be missed, and none was.

| population | class | n | f1 | f2 | f6 |
|---|---|---|---|---|---|
| rule population (77) | sensitive | 23 | 1 | 1 | 0 |
| rule population (77) | other | 54 | 5 | 1 | 0 |
| guard-demoted (13) | sensitive | 8 | 0 | 0 | 0 |
| guard-demoted (13) | other | 5 | 0 | 0 | 0 |

Failing units: blc-6 (sensitive, 2 FAIL blocks), blc-2, blc-3, blc-4, blc-8 (other, 1 each), hdc-5 (other, 2 FAIL blocks).

Reading, for a later sonnet-floor proposal and not a conclusion of this audit: the only `sensitive` unit that left `haiku` is one of 23 (4.3%), against 1 of 54 for the rest (1.9%) on escalation; at this n the difference is not distinguishable from noise. Eight of the 13 guard-demoted units were `sensitive`, so the guard has been keeping the riskier path class off `haiku`; the rule's own population is therefore already thinned of them.

Classification script (run from the repository root with `<F>` the pinned export; prints `id`, `fail_blocks`, population `pop` or `guard`, class):

    UNTIL=2026-10-15T06:00:00Z
    jq -rs --rawfile r .claude/orchestrator-rulings.log '[$r | scan("(?m)^RULING \\S+ unit=(\\S+) decision=contract-guard sonnet:") | .[0]] as $g | .[] | select(.terminal_ts >= "2026-10-08T17:28:48Z" and (.id|startswith("htd-")|not)) | "\(.id)\t\(.fail_blocks)\t\(if (.id as $i|$g|index([$i])) then "guard" else "pop" end)"' <F> | while IFS=$'\t' read id fb pop; do
      files=$(git log --until="$UNTIL" --format='%H' -E --grep="^[a-z]+\(([a-z0-9,-]+,)?${id}(,[a-z0-9,-]+)?\)" | while read h; do git show --no-renames --name-only --format= "$h"; done | sort -u)
      if [ -z "$files" ]; then c=none; elif echo "$files" | grep -qE '^(hooks|agents|templates)/'; then c=sensitive; else c=other; fi
      printf '%s\t%s\t%s\t%s\n' "$id" "$fb" "$pop" "$c"
    done

## Ruling

The rule printed its pass verdict, so the pre-committed action (restore `sonnet`) does not fire and nothing changes. The population is 77, above the 60-unit threshold, so this is a decision reading and not a tripwire reading. Spend is not recorded here: ADR-0040 lists it as information only and the script cannot attribute it to the implementer.
