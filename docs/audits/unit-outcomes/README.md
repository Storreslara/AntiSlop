# Unit-outcome snapshot

First tracked snapshot of unit outcomes from `scripts/unit-outcomes.js`, one JSON line per unit, sorted by `id`. It holds ids, timestamps and class labels only, never prompt or defect text. Transcripts prune at about 30 days, so this file is the durable copy of outcome history that later replays read.

cutoff: 2026-10-06T00:00:00Z
reproduce-command: node scripts/unit-outcomes.js --until=2026-10-06T00:00:00Z

The snapshot was generated on 2026-10-06 (UTC) with `node scripts/unit-outcomes.js --until=2026-10-06T00:00:00Z --out=docs/audits/unit-outcomes/2026-10-06.jsonl`. The reproduce command prints to stdout. Its output must match the committed file except for `contract_score` and `contract_source` of issue-sourced units, because live issue text can be edited. Fields added after this snapshot (`rubric_version`, `contract_score_v2`) are absent from the committed file and are excluded from the comparison too.

## Counts

Each number is the output of the command printed next to it, run once over the committed file.

count: units total = 356 :: jq -s 'length' docs/audits/unit-outcomes/2026-10-06.jsonl
count: with contract text = 87 :: jq -s '[.[] | select(.contract_source != "none")] | length' docs/audits/unit-outcomes/2026-10-06.jsonl
count: with observed tier = 114 :: jq -s '[.[] | select(any(.implementer_tiers[]?; .source == "observed"))] | length' docs/audits/unit-outcomes/2026-10-06.jsonl
count: with a range = 181 :: jq -s '[.[] | select(.range_source == "commit-scope")] | length' docs/audits/unit-outcomes/2026-10-06.jsonl

## Field dictionary

- `id`: the unit id (marker file stem).
- `plan`: the plan stem (the `docs/plans/` file name without directory or `.md`), or null.
- `contract_author`: who wrote the unit's contract: `task-master`, `spec-master` or `unknown`.
- `contract_source`: where the contract text came from: `issue#N`, `plan:<path>`, `transcript` or `none`, tried in that order.
- `contract_score`: the `score` from `bin/contract-score.js` over the contract text, or null when there is no real contract.
- `contract_ts`: when the contract was written (issue `createdAt`, or the oldest plan commit adding the unit block), or null.
- `baseline`: the commit the unit's range starts from, or null.
- `final_commit`: the PASS marker's `commit:` value as written (48 are short SHAs in this snapshot), or null when the unit has no PASS or its marker reads `commit: none`.
- `range_source`: `commit-scope` when the range was recovered from commit scopes, else `none`.
- `implementer_tiers`: list of `{tier, source}` for the implementer, where `source` is `observed` (transcript meta), `frontmatter-inferred` or `era-inferred`.
- `attempts`: FAIL blocks plus one if the unit has a PASS.
- `reviewer_tiers`: list of `{tier, source}` for the reviewer, empty when no meta exists.
- `fail_classes`: canonical-order FAIL class labels (mirror, version, vacuous, spec-gap, scope, host, unverified) found across the unit's FAIL blocks.
- `cap_hit`: true when the unit has two or more FAIL blocks.
- `task_master_cutoff`: always null in this snapshot; the exporter does not yet measure cutoffs, and G3 prints `task_master_cutoffs=unmeasured`.
- `pass_ts`: the PASS marker's first-line timestamp if at or before the cutoff, else null.
- `terminal_ts`: the earlier of `pass_ts` and the second FAIL header timestamp, each only if at or before the cutoff.
- `fail_blocks`: the number of FAIL headers at or before the cutoff.
- `rubric_version`: `v1`, `v2` or null; see `RUBRIC_V2_UNIT` in `scripts/unit-outcomes.js`.
- `contract_score_v2`: the `score` under `bin/contract-score.js --rubric=v2`, or null when there is no real contract; G3 uses it for `rubric_version` `v2` units.

## Coverage window

Terminal-event dates present run from 2026-08-07 (earliest `terminal_ts`) to 2026-10-05 (latest `terminal_ts`), per `jq -s 'map(.terminal_ts) | [min, max]'` over the committed file. The transcript store spans only about 30 days, so `observed` tiers cover only that window; older units carry `frontmatter-inferred` or `era-inferred` tiers.
