Unit: aof-u5

## Objective
Make the A/B harness count a run's tokens over the whole run, then record the change as dated amendment
OD-22. Today `eval/abtest/lib/stream.py` reads `usage` from the last `result` record only. Arm B emits one
result record per main-session segment, and each record's `usage` covers that segment's main thread only, so
B's `tokens_total` was understated by 40 to 260 times. The fix: take all four token fields from the last
result record's cumulative `modelUsage`, summed over models, and fall back to summing `usage` over every result
record when `modelUsage` is absent or empty. `num_turns` is also per segment, so it is summed over every
result record. `duration_api_ms` was verified to be already cumulative (the same value on every record), so
it stays read from the last record and is not summed. This is spec Step 5 (P5, alt 5B, operator ruling
OQ3 = a, with the premise correction recorded in the spec). It is a harness change; no product file is
touched.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-overhead-fixes/spec.md`, "Step 5 (aof-u5)" and
"Context, P5". The verbatim OD-22 text and experiment-doc amendment text are in the spec under Step 5. This
file is the contract of record, re-issued on 2026-10-19 after the operator's ruling on Open Question 3. aof-u6
depends on this unit: OD-23 appends after the OD-22 that this unit writes.

## Affected files
- `eval/abtest/lib/stream.py`: `summarize()` (anchor: line matching `def summarize(path, exit_code, stderr_text, escalated):`; the token block is the 5 lines starting `usage = (result or {}).get("usage") or {}`)
- `tests/abtest-stream.test.sh`: new checks next to the anchor line matching `check "tokens_total is input plus output plus cache write"`
- `tests/fixtures/abtest/streams/multi-result.jsonl` and `tests/fixtures/abtest/streams/multi-result-no-mu.jsonl` (new; this is `$FX`, tests/abtest-stream.test.sh:7)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md`: append OD-22 after the last OD-21 line
- `docs/experiments/abtest-2026-10.md`: insert the amendment paragraph after the OD-21 amendment paragraph, which ends with "the streams." (currently line 66), and before the blank line that precedes "Known limits (OD-15)"

## Ordered edits
1. In `summarize()`, keep `result` as the last result record and also collect `results`, the list of every
   `type == "result"` record. Replace the token block with this pseudo-code:
   ```
   mu = (result or {}).get("modelUsage") or {}
   if isinstance(mu, dict) and mu:
       tok_in = sum(int(v.get("inputTokens") or 0) for v in mu.values() if isinstance(v, dict))
       tok_out = sum(... "outputTokens" ...)
       tok_cw = sum(... "cacheCreationInputTokens" ...)
       tok_cr = sum(... "cacheReadInputTokens" ...)
   else:
       sum the four `usage` fields over every record in `results` (same keys as today)
   ```
   `tokens_total` stays `tok_in + tok_out + tok_cw`. Set `num_turns` to the sum of `num_turns` over every
   record in `results`, treating a missing or null value as 0. If no record has a numeric `num_turns`, keep
   `None`, as today. Leave `duration_api_ms`, `total_cost_usd` and `model_usage` read from the last record:
   they are already cumulative. Add a one-line comment saying so, citing OD-22.
2. Add fixture `multi-result.jsonl`. It has 3 lines of
   `{"type":"result","subtype":"success","is_error":false,"result":"ok","num_turns":<k>,"duration_api_ms":500,"usage":{"input_tokens":1,"output_tokens":2,"cache_creation_input_tokens":3,"cache_read_input_tokens":0}}`,
   with `<k>` = 1, 2 and 3 on lines 1, 2 and 3. The last line also carries
   `"modelUsage":{"m1":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400},"m2":{"inputTokens":1,"outputTokens":2,"cacheCreationInputTokens":3,"cacheReadInputTokens":40}}`.
3. Add fixture `multi-result-no-mu.jsonl`: 2 result lines with usage (1,2,3,0) and (4,5,6,0) and no
   `modelUsage`.
4. In `tests/abtest-stream.test.sh`, add these checks with the file's existing `check`/`field` helpers:
   - `multi-result.jsonl`: `tokens_total` 66, `tokens_in` 11, `tokens_out` 22, `tokens_cache_write` 33,
     `tokens_cache_read` 440, `num_turns` 6, `duration_api_ms` 500;
   - `multi-result-no-mu.jsonl`: `tokens_total` 21.

   The existing `complete.jsonl` check (60) must still pass. If that fixture carries a `modelUsage` that
   disagrees with its `usage`, report it; do not edit the fixture.
5. Append OD-22 to `operator-decisions.md`, using the verbatim text from the spec under "OD-22 text" (the
   finalized version, which covers tokens and `num_turns`).
6. Insert the experiment-doc amendment paragraph verbatim from the spec under "Experiment-doc amendment"
   (the OD-22 one) after the OD-21 paragraph.
7. Commit with the subject `fix(aof-u5): whole-run token and turn count (OD-22)`.

## Do NOT touch
- `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/tasks/`, `checks/scope.sh`, any
  `allowed-paths.txt`, `score.py`'s verdict rules or thresholds, `make-row.py`, `report.py`, `run-matrix.sh`,
  the arm scripts. OD-22 changes measurement only.
- `duration_api_ms` handling: it is already cumulative, and summing it would multiply it by the record count.
- OD-23 and anything about model policy (aof-u6).
- `eval/abtest/results.jsonl` and `results.superseded.jsonl`: do not rewrite past rows. The runner supersedes
  them under OD-14.
- Any product file (`agents/`, `hooks/`, `bin/`, `templates/`).

## Acceptance criteria
- AC5.1 run: `bash tests/abtest-stream.test.sh` (exit 0). mutation: restoring last-record `usage` reading
  makes `multi-result.jsonl` report 6 (expected 66) and `multi-result-no-mu.jsonl` report 15 (expected 21);
  restoring last-record `num_turns` gives 3 (expected 6); summing `duration_api_ms` gives 1500 (expected 500).
- AC5.2 run: `bash tests/abtest-row.test.sh && bash tests/abtest-score.test.sh` (exit 0). The
  `tokens_total = in + out + cw` invariant at score.py:88-90 holds.
- AC5.3 run: `grep -q '^- OD-22 (2026-10-19' docs/plans/antislop-vs-fable-evals/operator-decisions.md && grep -q '^Amendment 2026-10-19 (OD-22' docs/experiments/abtest-2026-10.md`.
  mutation: a missing entry fails it.
- AC5.4 run: a regression over the real pilot-4 stream (the signature was verified as
  `summarize(path, exit_code, stderr_text, escalated)`, and the current code returns 3205):
  `python3 -I -c "import sys; sys.path.insert(0,'eval/abtest/lib'); import stream; s=stream.summarize('eval/abtest/.runs/e05-tags-feature_B_uniform_1/stream.jsonl',0,'',0); assert (s['tokens_total'],s['num_turns'],s['duration_api_ms'])==(831801,53,1253697), (s['tokens_total'],s['num_turns'],s['duration_api_ms'])"`
  exits 0. mutation: the old code gives (3205, 2, 1253697).
- AC5.5 run: `bash tests/validate.sh` (exit 0).

## Pre-resolved context
- Measured by spec-master on 2026-10-19 over the pilot-4 streams, as in+out+cw for E1 to E5 B:

  | Count | E1 | E2 | E3 | E4 | E5 |
  |---|---|---|---|---|---|
  | last record | 4075 | 3606 | 3774 | 4678 | 3205 |
  | sum of `usage` | 71693 | 81994 | 44879 | 39493 | 129663 |
  | last-record `modelUsage` | 285138 | 227318 | 197667 | 154522 | 831801 |

  The sum of `usage` equals the `claude-fable-5-1` entry exactly, so it counts the main thread only. The A
  streams have one record each, and all three counts agree.
- `total_cost_usd` on the last record is already cumulative: E5 B's 8.31 equals the sum of the per-model
  `costUSD`.
- Re-pilot success-criteria script (reference for the operator; not part of this unit):
  ```
  python3 -I - <<'EOF'
  import json,glob,re
  for d in sorted(glob.glob('eval/abtest/.runs/*_B_uniform_1')):
      find=stall=sens=stop2=0
      for l in open(d+'/stream.jsonl'):
          r=json.loads(l); s=json.dumps(r)
          if r.get('type')=='system' and r.get('subtype')=='hook_response' and r.get('hook_event')=='Stop' and r.get('exit_code')==2: stop2+=1
          for c in ((r.get('message') or {}).get('content') or []) if isinstance(r.get('message'),dict) and isinstance((r.get('message') or {}).get('content'),list) else []:
              if isinstance(c,dict) and c.get('type')=='tool_use' and c.get('name')=='Bash' and 'find /' in c['input'].get('command',''): find+=1
              if isinstance(c,dict) and c.get('type')=='tool_result':
                  t=json.dumps(c.get('content'))
                  stall+='did not complete within its 120s timeout' in t; sens+='which is a sensitive file' in t
      print(d.split('/')[-1], dict(find=find, stall=stall, sensitive=sens, stop_exit2=stop2))
  EOF
  ```
  Join this with `results.jsonl` fields `wall_clock_ms`, `out_of_scope_files`, the `scope-outside-allowed`
  check, `subagent_spawns`, `process.units`, `tokens_total` and `model_usage` for S3 to S7.

## Escalation
If `tests/abtest-stream.test.sh` locates its fixtures somewhere other than `$FX`, follow the file's own
convention and report the path. If the existing `complete.jsonl` expectation (60) changes under the new
rule, stop and report: that would mean the fixture's `modelUsage` disagrees with its `usage`, which is an
operator question. If a gate blocks an edit to the docs, report it and wait.
