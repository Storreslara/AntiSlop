# task-master handoff: antislop-vs-fable-evals E1-E5 slice

Umbrella issue #567 (label `plan/antislop-vs-fable-evals`). Spec `docs/plans/antislop-vs-fable-evals.md`; operator overrides `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (OD-1..OD-9). Unit ids `abt-uNN`. Contract files `docs/plans/antislop-vs-fable-evals/contracts/<unit-id>.md`. All units tagged `Suggested model: haiku` (no `.fail` records exist for any abt unit). No unit touches a version-stamped file, so no bump and no CHANGELOG entry. Commit trailer for unit commits: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Done (contract committed, issue filed, contract-score 7/7, contract-guard haiku, replayed in a scratch worktree: every edit applies, every criterion red before and green after, every `skip edit N` mutation red)

| unit | issue | contract | depends on |
|---|---|---|---|
| abt-u00 commit the design doc | #568 | contracts/abt-u00.md | none |
| abt-u01 arm scripts + common.sh + fake claude + test + .gitignore | #569 | contracts/abt-u01.md | none |
| abt-u02 eval/abtest/lib/stream.py + 9 canned captures + test | #570 | contracts/abt-u02.md | none |

## Next unit to write: abt-u03, then in this order (each: issue first, then contract, replay, commit)

| unit | content | depends on |
|---|---|---|
| abt-u03 | `eval/abtest/lib/make-row.py`: stream summary + check results + git facts -> one row (spec 4.3 as amended by OD-4/OD-5: completion_status enum, tokens_* columns, `usage-limit` rows kept) + test | abt-u02 |
| abt-u04 | check conventions: `eval/abtest/checks/lib.sh` (emits the `checks` JSON array; `scope_lines` excludes `.claude/` and `docs/plans/`; commits counted from START not BASE), `eval/abtest/verify-checks.sh` (`<eval-id>` or `--all`: baseline must have >=1 required FAIL, baseline+reference.patch must have all PASS; fails on a check naming a path), a synthetic fixture under `tests/fixtures/abtest/`, `tests/abtest-checks.test.sh` | none |
| abt-u05 | T2 `notes-svc` template part 1: `eval/abtest/templates/notes-svc/{package.json,src/*}` (store with `query(filterString)` via `new Function`, auth, server, cli, format) | none |
| abt-u06 | T2 part 2: tests, `scripts/export.js` (string-keyed `store[fn]` caller), README route table, `CONTEXT.md` with `_Avoid_:` lines, `CLAUDE.md`, `docs/adr/0001-in-memory-store.md` | abt-u05 |
| abt-u07 | E1 `e01-ambiguous-tax`: T1 + plant, `build.sh`, prompt, checks, `reference.patch`, `allowed-paths.txt` | abt-u04 |
| abt-u08 | E2 `e02-preview-mutation`: T1 + per-line-rounding plant, prompt = `eval/tasks/feature-task.md` byte for byte, checks (reuse `feature-task.holdout.test.js` + rounding test), reference | abt-u04 |
| abt-u09 | E3 `e03-rename-query` | abt-u04, abt-u06 |
| abt-u10 | E4 `e04-search-injection` (`persona-config.overrides.json` with `protectedPaths: ["src/auth.js"]`; the Arm-B process check is optional, non-required) | abt-u04, abt-u06 |
| abt-u11 | E5 `e05-tags-feature` plant + prompt + reference (split plant/reference from checks if over 30000 bytes) | abt-u04, abt-u06 |
| abt-u12 | `eval/abtest/run-matrix.sh`: sequential A,B,B,A; resumable (done iff a row exists whose completion_status != usage-limit); `--pilot` (N=1) and `--reps N`; usage-limit -> row kept, stop, exit 75; `MAX_TURNS`/`TIMEOUT_MIN`; tested with the fake claude over the E1 fixture | abt-u01, abt-u03, abt-u07 |
| abt-u13 | `--probe-isolation` and `--probe-model uniform` modes in run-matrix.sh (output lines per spec C1.2/C1.3), tested with the fake claude | abt-u12 |
| abt-u14 | `eval/abtest/score.py` (4.4 verdicts with R_tokens/R_wall/R_turns, usage-limit rows excluded, `aggregate: not-evaluated`) + synthetic rows fixture + `tests/abtest-score.test.sh` | abt-u03 |
| abt-u15 | `eval/abtest/blind.sh` (E1 `ASSUMPTIONS.md` item only) + test | abt-u12 |
| abt-u16 | `docs/experiments/abtest-2026-10.md` pre-registration (hypothesis, prediction in direction + the 4.4 thresholds, baseline, the 4.5 text, the OD amendments) | abt-u14 |
| abt-u17 | `eval/abtest/README.md` (operator run guide) + register every `tests/abtest-*.test.sh` in `tests/validate.sh` + `bash tests/validate.sh` green | abt-u01, u02, u03, u04, u12, u13, u14, u15, u16 |
| abt-u18 | scribe: CONTEXT.md entries (Arm A / Arm B, holdout check, out-of-scope lines, overhead ratio, completion status incl. usage-limit, model policy) + `.claude/wiki/modules/eval-harness.md` paragraph | abt-u14 |
| abt-u19 | OPERATOR-RUN pilot N=1 per arm per eval (10 runs), smoke gate: isolation probe, model probe, verify-checks --all for E1-E5, no Arm B headless stall | abt-u17, abt-u18, abt-u07..u11 |
| abt-u20 | OPERATOR-RUN full N=5 for E1-E5, resumable; rerun the command after every usage-limit stop until 50 non-usage-limit rows exist | abt-u19 |
| abt-u21 | report + experiment-log result + `eval-finding` tickets for every not-superior eval (lead-programmer on local rows; ticket filing by the orchestrator) | abt-u20 |

`operator-run` units (abt-u19, abt-u20) get label `operator-run`, no `ready-for-agent`, and a first body line `OPERATOR-RUN UNIT: launched by the operator/orchestrator, never dispatched to lead-programmer.`

## Decisions taken that are not in a contract

- Interfaces already fixed by abt-u01/abt-u02 (later contracts must match): `arm-a.sh WT PROMPT STREAM ERR`; `arm-b.sh WT PROMPT STREAM ERR PLUGIN_ROOT [OVERRIDES_JSON]`; env `ABTEST_CONFIG_DIR` (required), `ABTEST_POLICY` (uniform|shipped), `ABTEST_MODEL` (default `fable`), `ABTEST_CLAUDE`, `MAX_TURNS` (100), `TIMEOUT_MIN` (45); stdout line `scaffold-sha: <sha>`; exit 124 on timeout, 3 on a refused worktree/scaffold, 2 on a bad policy; `stream.py summarize STREAM [--exit-code N] [--stderr FILE] [--escalated N]` prints keys `completion_status, result_subtype, result_text, num_turns, duration_api_ms, total_cost_usd, tokens_in, tokens_out, tokens_cache_write, tokens_cache_read, tokens_total, model_usage, hook_events, session_start_events, subagent_spawns, tool_calls, ask_user_attempts, permission_denials, escalated_markers, human_interventions_required`.
- `scope_lines` ignores `.claude/` and `docs/plans/` for both arms (pipeline artefacts; consistent with spec 2.6's blind-diff exclusion), and commit counts run from the post-scaffold sha, not the baseline, so Arm B's scaffold commit never counts.
- The persona-config file name is built from two parts inside scripts and tests so no Bash text names it; contracts tell executors to use Write/Edit, not heredocs.
- Fixture `build.sh DEST` must set fixed `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` and identity so two builds agree on the baseline sha (spec C2.1); its last stdout line is the sha.
- Counts from the doc are scaled to E1-E5 (5 fixtures/prompts/check dirs/references; 50 uniform rows).
- Open risks to flag to the operator, not gaps: `--max-turns` is not listed in `claude --help` 2.1.300 (the pilot, abt-u19, must prove it is accepted); the stream-json hook-event and rate-limit record shapes in stream.py are guesses the pilot confirms; `--plugin-dir` plus the scaffolded settings hooks may register hooks twice (the isolation probe shows hook-event counts); the E4 critical-mode sub-run and the E2/E5 shipped replicates are deferred (OD-7).
- Tools used to author and replay contracts (scratch applier + generator) are saved under `.claude/agent-memory/task-master/tools/`.
