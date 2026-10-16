# Memory index





- [Verify plan premise freshness](feedback_verify_plan_premise_freshness.md) — gh354 FAIL: a plan's invariant is dated evidence; re-measure negative claims and check sibling glossary entries before minting
- [Self-referential criterion quoting](feedback_self_referential_criterion_quoting.md) — copying a "must not contain X" grep pattern verbatim into the artifact it checks reintroduces X and self-poisons the check; break contiguity with `[…]`

- [Multifile sweep criterion defect](feedback_multifile_sweep_criterion_defect.md) — grep -o emits filename prefix; must handle bare trailing `:` not just `:<digits>` suffixes
- [Dispatch hygiene: mutation-command escaping](feedback_dispatch_hygiene_mutation_commands.md) — extract mutation-control reproduction commands verbatim from spec docs, not by retyping
- [PASS-marker comment gate workaround](feedback_pass_marker_comment_gate_workaround.md) — heredoc quoting a `.pass` marker path trips reviewed-path-gate; write body to scratchpad, use `--body-file`
- [CONTEXT.md commit before reviewer dispatch](feedback_context_commit_before_reviewer.md) — recurring pattern: commit CONTEXT.md updates before reviewer stage to avoid dirty tree issues
- [Verify each disk sink and field location](feedback_verify_each_disk_sink_and_field_location.md) — gh377-7 FAIL: don't generalize one confirmed write claim to adjacent unverified ones
- [ptr-u1 completion](project_ptr_u1_completion.md) — PASS 720b542 closed #543; five carry-forward gaps (no EXIT trap, vacuous miss=0, serial gate never run end to end)
- [Archive](ARCHIVE.md) — closed-plan and project notes; grep it before concluding none exists
- [ptr-u7c completion](project_ptr_u7c_completion.md) — PASS cb62b9c closed #551; orchestrator.md stale 'Bash refused' claim and unpinned default semantics open
