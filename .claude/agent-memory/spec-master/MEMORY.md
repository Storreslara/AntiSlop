# spec-master memory index

- [No forced changes](feedback_no_forced_changes.md) — "no change warranted" is a valid finalized answer; ground any change in a grep-verifiable gap, never manufacture a diff.
- [Baselines expire](feedback_baselines_expire.md) — untracked-file baselines, absolute byte-pins, AND live-sweep classification tables all expire; late arrival vs narrow-category look identical; remedy by artifact kind.
- [Verify own criteria are non-vacuous](feedback_verify_own_criteria_nonvacuous.md) — run every criterion you author before handoff; 13 traps, incl. signals attributable to the wrong file, and fixtures the tool self-repairs via backfill.
- [Survey ALL .fail records, not a sample](feedback_survey_all_fail_records.md) — enumerate the whole directory before concluding "no prior FAIL"; a 6-of-22 sample inverted a plan's risk section.
- [Deferred issues decay](feedback_verify_deferred_issue_premises.md) — re-verify a deferred issue's premises against the tree; #185 had two stale ones, mooting a whole item.
- [Don't gate a source edit apart from its shipped copy](feedback_dont_slice_units_across_a_parity_test.md) — validate.sh asserts the shipped copies; merge the pair, and sweep ALL such pairs, not just the one that escalated.
- [Goal prose vs step table drift](feedback_goal_prose_vs_step_table_drift.md) — map every Goal clause to a step criterion; unmapped clauses ship silently, reviewers cannot see them.
- [Docs units need claim-anchored criteria](feedback_docs_units_need_claim_anchored_criteria.md) — existence greps gate nothing when prose accuracy IS the deliverable; 3 units have FAILed this way.
- [Review-join null only covered zero-stamp](feedback_review_join_null_only_covered_zero_stamp.md) — an R-item's "already specified" claim wasn't; verify the referenced criterion covers the NAMED scenario, not just the general shape.
- [PASS-note warnings don't propagate](feedback_pass_note_warnings_do_not_propagate.md) — harvest sibling `.pass` notes AND `tmp/*handoff*.md` before calling anything a first occurrence; gh402 and gh425 both had the fix written down already.
- [Reproduce advisory figures at defect scope](feedback_reproduce_advisory_figures_at_defect_scope.md) — a reviewer's "47 of 300" was whole-file, was 19 at the real scope, and the unmeasured sibling defect was 79.
- [Grep for the deliverable before speccing it](feedback_grep_for_the_deliverable_before_speccing_it.md) — a shipped detector can meet 6/7 criteria while the goal fails because NOTHING invokes it; also: enumerate the shipped set, don't trust the glob.
- [Techniques](TECHNIQUES.md) — how-to notes (bash, gates, tests); grep it by keyword before solving a mechanics problem
- [Archive](ARCHIVE.md) — closed-plan and project notes; grep it before concluding none exists
