# ADR-0026 forward-rule audit

> **After ≥60 units dispatched under the `sonnet` default, the FAIL rate
> must have fallen below the 32.5% haiku-era rate.** If not, the reversal
> has not delivered its predicted benefit and ADR-0010's amendment (this
> ADR) must be revisited rather than defended. Additionally, total spend
> must not materially worsen — a `sonnet` writer costs ~3× a `haiku` one
> per attempt, and the bet is that fewer opus re-reviews more than pay for
> that.

snapshot: docs/audits/unit-outcomes/2026-10-06.jsonl
population: units with terminal_ts >= "2026-08-25T00:00:00Z" (ADR-0026 ratification; capped units without a PASS are included and count as FAIL)
A unit dispatched before 2026-08-25 and finished after it is counted in the sonnet era, the same boundary effect ADR-0026's mtime basis had.
n-units: 205
reproduce: jq -s '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")] | length' docs/audits/unit-outcomes/2026-10-06.jsonl
units-with-fail: 63
reproduce: jq -s '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")] | map(select(.fail_blocks >= 1)) | length' docs/audits/unit-outcomes/2026-10-06.jsonl
fail-rate: 0.3073170731707317
reproduce: jq -s '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")] | (map(select(.fail_blocks >= 1)) | length) / length' docs/audits/unit-outcomes/2026-10-06.jsonl
fail-rate-basis: units-with-any-FAIL / units (as ADR-0026: 66/203)
Timestamp source differs: ADR-0026 used marker mtimes; this audit uses marker content timestamps.
threshold: 32.5%
reproduce: grep -o '32\.5%' docs/adr/0026-writer-tier-reversed-to-sonnet.md | head -1
letter-verdict: met
reproduce: jq -rs '[.[] | select(.terminal_ts >= "2026-08-25T00:00:00Z")] | if length < 60 then "insufficient" elif ((map(select(.fail_blocks >= 1)) | length) / length) < 0.325 then "met" else "not-met" end' docs/audits/unit-outcomes/2026-10-06.jsonl
spend-accounting-rate: 31.4% (period "from 2026-08-02"; the script's only post-08-02 boundary, not 2026-08-25)
reproduce: bash scripts/spend-accounting.sh --until=2026-10-06T00:00:00Z | jq -r '.per_period_fail_rate[] | select(.period == "from 2026-08-02") | .rate'
Context only: spend-accounting-rate is NOT compared against 32.5% and nothing is subtracted; the letter verdict uses only fail-rate.
spend-verdict: unverifiable (transcripts before 2026-09-01 are pruned, so spend before and after the reversal cannot be compared)
failing-command: bash scripts/spend-accounting.sh --until=2026-08-25T00:00:00Z (prints "no usage records found in corpus")
spirit-ruling: not-met
spirit-ruled-by: user (repo owner), 2026-10-08: "it doesn't, we need more testing and long-term evidence"
