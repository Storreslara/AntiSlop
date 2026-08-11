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
- [Don't gate a source edit apart from its shipped copy](feedback_dont_slice_units_across_a_parity_test.md) — validate.sh asserts the shipped copies; merge the pair, and sweep ALL such pairs, not just the one that escalated.
- [maxTurns-cutoff spec (#123)](project_maxturns_cutoff_spec.md) — settled decisions + two-tier protocol fan-out finding; recovered 2026-08-08 from a lost stash, verified shipped intact.
- [Claude transcript store](reference_claude_transcript_store.md) — agent dispatches/tools/skills are ALREADY on disk under ~/.claude/projects/; check before speccing new hook instrumentation.
- [Goal prose vs step table drift](feedback_goal_prose_vs_step_table_drift.md) — map every Goal clause to a step criterion; unmapped clauses ship silently, reviewers cannot see them.
- [Heavy trigger is in ADR-0004, not the protocol](project_heavy_trigger_not_in_protocol.md) — the 2026-07-28 plan says otherwise and ships an unsatisfiable grep; fix #133 before dispatch.
- [Measure unread files in a debug spec](technique_debug_spec_measure_unread_files.md) — count per-round tool calls naming the file the false claim is about; zero = retrieval gap, not capacity gap.
- [Docs units need claim-anchored criteria](feedback_docs_units_need_claim_anchored_criteria.md) — existence greps gate nothing when prose accuracy IS the deliverable; 3 units have FAILed this way.
