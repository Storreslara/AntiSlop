# spec-master memory index

- [enabledPlugins format uncertainty](project_enabledplugins_format_uncertainty.md) — docs say array, shipped #66-71 guard assumes object-of-booleans; verify before building further on the object form.
- [--update dedupe-hooks spec (#74)](project_update_dedupe_hooks_spec.md) — extends #66-73 guard to --update; warn-only default + opt-in --dedupe-hooks, claude-only, no new marker.
- [No forced changes](feedback_no_forced_changes.md) — "no change warranted" is a valid finalized answer; ground any change in a grep-verifiable gap, never manufacture a diff.
- [to-spec flag state changed](project_to_spec_slash_only.md) — was slash-only; unit #252 un-flagged it 2026-08-06. Check your live skills list before assuming either state.
- [reviewed-path-gate behavior](project_reviewed_path_gate_blocks_bash.md) — bare ls/cat/grep work; it ignores gatedAgents and blocks by command TEXT; use the placeholder+sed pattern to author docs.
- [ADR numbering: increment, never backfill](project_adr_numbering_increment_not_backfill.md) — the 0007 hole is not free (CONTEXT.md links it); re-derive ADR numbers at execution time, sibling specs collide.
- [Baselines expire](feedback_baselines_expire.md) — a baseline is a measurement with an expiry; untracked-file baselines need a recovery-source precondition. `git stash -u` hides files in a 3rd parent.
- [Verify own criteria are non-vacuous](feedback_verify_own_criteria_nonvacuous.md) — run every criterion you author before handoff; a recursive grep across 4 files matched only 1.
- [Specs publish as per-step issues](project_specs_publish_as_per_step_issues.md) — one issue per step under `plan/<slug>`, filed by task-master; never publish an umbrella to-spec PRD issue here.
- [Survey ALL .fail records, not a sample](feedback_survey_all_fail_records.md) — enumerate the whole directory before concluding "no prior FAIL"; a 6-of-22 sample inverted a plan's risk section.
- [Deferred issues decay](feedback_verify_deferred_issue_premises.md) — re-verify a deferred issue's premises against the tree; #185 had two stale ones, mooting a whole item.
