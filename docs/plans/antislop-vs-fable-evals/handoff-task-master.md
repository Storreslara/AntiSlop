# task-master handoff: antislop-vs-fable-evals E1-E5 slice

Umbrella issue #567 (label `plan/antislop-vs-fable-evals`). Spec `docs/plans/antislop-vs-fable-evals.md`; operator overrides `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (OD-1..OD-9). Unit ids `abt-uNN`. Contract files `docs/plans/antislop-vs-fable-evals/contracts/<unit-id>.md`. All units tagged `Suggested model: haiku` (no `.fail` records exist for any abt unit). No unit touches a version-stamped file, so no bump and no CHANGELOG entry. Commit trailer for unit commits: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Done (contract committed, issue filed, contract-score 7/7, contract-guard haiku, replayed in a scratch worktree: every edit applies, every criterion red before and green after, every `skip edit N` mutation red)

| unit | issue | contract | depends on |
|---|---|---|---|
| abt-u00 commit the design doc | #568 | contracts/abt-u00.md | none |
| abt-u01 arm scripts + common.sh + fake claude + test + .gitignore | #569 | contracts/abt-u01.md | none |
| abt-u02 eval/abtest/lib/stream.py + 9 canned captures + test | #570 | contracts/abt-u02.md | none |
| abt-u03 eval/abtest/lib/make-row.py + row fixtures + test | #571 | contracts/abt-u03.md | abt-u02 (#570) |
| abt-u04 checks/lib.sh, checks/scope.sh, fixtures/lib.sh, verify-checks.sh, 3 synthetic fixtures, tests/abtest-checks.test.sh | #572 | contracts/abt-u04.md | none |
| abt-u05 T2 notes-svc template code (package.json, src/*) | #573 | contracts/abt-u05.md | none |
| abt-u06 T2 template tests, scripts/export.js, README, CONTEXT.md, CLAUDE.md, ADR | #574 | contracts/abt-u06.md | abt-u05 (#573) |
| abt-u07 E1 fixture/prompt/checks/reference | #575 | contracts/abt-u07.md | abt-u04 (#572) |
| abt-u08 E2 fixture/prompt/checks/reference | #576 | contracts/abt-u08.md | abt-u04 (#572) |
| abt-u09 E3 fixture/prompt/checks/reference | #577 | contracts/abt-u09.md | abt-u04 (#572), abt-u06 (#574) |
| abt-u10 E4 fixture/prompt/checks/reference + vulnerable proof + arm-b.overrides.json | #578 | contracts/abt-u10.md | abt-u04 (#572), abt-u06 (#574) |
| abt-u11 E5 fixture/prompt/reference series (reference.d/01..05) | #579 | contracts/abt-u11.md | abt-u04 (#572), abt-u06 (#574) |
| abt-u11b E5 hidden checks (9 required) | #580 | contracts/abt-u11b.md | abt-u04 (#572), abt-u11 (#579) |
| abt-u12 eval/abtest/run-matrix.sh + tests/abtest-runner.test.sh | #581 | contracts/abt-u12.md | abt-u01 (#569), abt-u02 (#570), abt-u03 (#571), abt-u04 (#572), abt-u07 (#575) |

## Next unit to write: abt-u13, then in this order (abt-u03..u12 are done and removed from this table) (each: issue first, then contract, replay, commit)

| unit | content | depends on |
|---|---|---|
| abt-u13 | `--probe-isolation` and `--probe-model uniform` modes in run-matrix.sh (output lines per spec C1.2/C1.3), tested with the fake claude | abt-u12 |
| abt-u14 | `eval/abtest/score.py` (4.4 verdicts with R_tokens/R_wall/R_turns, usage-limit rows excluded, `aggregate: not-evaluated`) + synthetic rows fixture + `tests/abtest-score.test.sh` | abt-u03 |
| abt-u15 | `eval/abtest/blind.sh` (E1 `ASSUMPTIONS.md` item only) + test | abt-u12 |
| abt-u16 | `docs/experiments/abtest-2026-10.md` pre-registration (hypothesis, prediction in direction + the 4.4 thresholds, baseline, the 4.5 text, the OD amendments) | abt-u14 |
| abt-u17 | `eval/abtest/README.md` (operator run guide) + register every `tests/abtest-*.test.sh` in `tests/validate.sh` + `bash tests/validate.sh` green | abt-u01, u02, u03, u04, u12, u13, u14, u15, u16 |
| abt-u18 | scribe: CONTEXT.md entries (Arm A / Arm B, holdout check, out-of-scope lines, overhead ratio, completion status incl. usage-limit, model policy) + `.claude/wiki/modules/eval-harness.md` paragraph | abt-u14 |
| abt-u19 | OPERATOR-RUN pilot N=1 per arm per eval (10 runs), smoke gate: isolation probe, model probe, verify-checks --all for E1-E5, no Arm B headless stall | abt-u17, abt-u18, abt-u07..u11, abt-u11b, abt-u12 |
| abt-u20 | OPERATOR-RUN full N=5 for E1-E5, resumable; rerun the command after every usage-limit stop until 50 non-usage-limit rows exist | abt-u19 |
| abt-u21 | report + experiment-log result + `eval-finding` tickets for every not-superior eval (lead-programmer on local rows; ticket filing by the orchestrator) | abt-u20 |

`operator-run` units (abt-u19, abt-u20) get label `operator-run`, no `ready-for-agent`, and a first body line `OPERATOR-RUN UNIT: launched by the operator/orchestrator, never dispatched to lead-programmer.`

## Decisions taken that are not in a contract

- Interfaces already fixed by abt-u01/abt-u02 (later contracts must match): `arm-a.sh WT PROMPT STREAM ERR`; `arm-b.sh WT PROMPT STREAM ERR PLUGIN_ROOT [OVERRIDES_JSON]`; env `ABTEST_CONFIG_DIR` (required), `ABTEST_POLICY` (uniform|shipped), `ABTEST_MODEL` (default `fable`), `ABTEST_CLAUDE`, `MAX_TURNS` (100), `TIMEOUT_MIN` (45); stdout line `scaffold-sha: <sha>`; exit 124 on timeout, 3 on a refused worktree/scaffold, 2 on a bad policy; `stream.py summarize STREAM [--exit-code N] [--stderr FILE] [--escalated N]` prints keys `completion_status, result_subtype, result_text, num_turns, duration_api_ms, total_cost_usd, tokens_in, tokens_out, tokens_cache_write, tokens_cache_read, tokens_total, model_usage, hook_events, session_start_events, subagent_spawns, tool_calls, ask_user_attempts, permission_denials, escalated_markers, human_interventions_required`.
- `scope_lines` ignores `.claude/` and `docs/plans/` for both arms (pipeline artefacts; consistent with spec 2.6's blind-diff exclusion), and commit counts run from the post-scaffold sha, not the baseline, so Arm B's scaffold commit never counts.
- The persona-config file name is built from two parts inside scripts and tests so no Bash text names it; contracts tell executors to use Write/Edit, not heredocs.
- Fixture `build.sh DEST` must set fixed `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` and identity so two builds agree on the baseline sha (spec C2.1); its last stdout line is the sha.
- Counts from the doc are scaled to E1-E5 (5 fixtures/prompts/check dirs/references; 50 uniform rows).
- Contract-writing interfaces fixed by abt-u04 (fixture units must match): fixture dir `eval/abtest/fixtures/<eval-id>/{build.sh,reference.patch,allowed-paths.txt}` (build.sh sources `$ABT_REPO_ROOT/eval/abtest/fixtures/lib.sh`, `build.sh DEST` prints the baseline sha last); `eval/abtest/checks/<eval-id>/check.sh` called as `check.sh WORKTREE BASE START ALLOWED_FILE`, starts with `. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"`, uses abt_init/abt_check/abt_check_scope/abt_emit; verify with `bash eval/abtest/verify-checks.sh <eval-id>`. Template T2 lives at `eval/abtest/templates/notes-svc/` (abt-u05/u06): `NOTES_SEED=<json array file>` seeds CLI and export; tokens tok-alice/tok-bob; store.query via new Function; direct callers server.js (GET /notes?title=) and cli.js (list --title); string-keyed caller scripts/export.js; E3's plant adds test/helpers.js.
- Replay tooling: `REPLAY_PRE=<contract,...>` applies earlier contracts first (needed when a unit builds on an unlanded dependency).
- Fixture units are built with `tools/fx.py` (`fixture_unit(...)` in the memory tools dir): files are written in the scratch worktree and verified with `bash eval/abtest/verify-checks.sh <eval-id>` first. abt-u04's verifier applies reference.patch with `git apply --recount` because a contract payload collapses a one-space context line to an empty line (found replaying abt-u09); never put a trailing whitespace-only line in a payload that matters. Fixture plants are directories copied over the template (`plant/`), not plant.patch. The prompt files for E1-E3 are `eval/abtest/tasks/<eval-id>.prompt.md`; E2's is feature-task.md byte for byte. E3's expected CLI/export outputs are committed under its checks dir.
- Amended before dispatch (contracts re-committed): abt-u01 (arm-b.sh scaffold commit uses an explicit identity; fake-claude.sh gains FAKE_CLAUDE_TOUCH), abt-u04 (verify-checks.sh applies reference.patch with --recount and supports a `reference.d/*.patch` series applied one commit per patch; syn-vacuous/syn-badref are built inside the test; a syn-series fixture covers reference.d). Fixture overrides file is `arm-b.overrides.json` (not persona-config.*) so no Bash text names the gated config. E5 checks subtract `ABT_SNAPSHOT` (set by the runner when it committed a dirty tree) from the commit count.
- run-matrix.sh (abt-u12) contract: env ABT_RESULTS (default eval/abtest/results.jsonl), ABT_RUNS (default eval/abtest/.runs), ABT_PLUGIN_ROOT; flags --pilot, --reps N, --evals a,b, --policy, --dry-run; exit 75 on usage-limit; run dir `.runs/<eval>_<arm>_<policy>_<rep>/{stream.jsonl,stderr.log,arm.out,summary.json,checks.json,process.json,row.json,diff.patch[,snapshot]}`. abt-u13 adds `--probe-isolation` and `--probe-model uniform` to the SAME file (so it depends on abt-u12). process.persona_tokens stays null (the arms use --no-session-persistence, so no transcripts exist for agg.py); flag this to the operator.
- Open risks to flag to the operator, not gaps: `--max-turns` is not listed in `claude --help` 2.1.300 (the pilot, abt-u19, must prove it is accepted); the stream-json hook-event and rate-limit record shapes in stream.py are guesses the pilot confirms; `--plugin-dir` plus the scaffolded settings hooks may register hooks twice (the isolation probe shows hook-event counts); the E4 critical-mode sub-run and the E2/E5 shipped replicates are deferred (OD-7).
- Tools used to author and replay contracts (scratch applier + generator) are saved under `.claude/agent-memory/task-master/tools/`.
