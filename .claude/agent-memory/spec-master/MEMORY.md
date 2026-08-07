# spec-master memory index

- [enabledPlugins format uncertainty](project_enabledplugins_format_uncertainty.md) — docs say array, shipped #66-71 guard assumes object-of-booleans; verify before building further on the object form.
- [--update dedupe-hooks spec (#74)](project_update_dedupe_hooks_spec.md) — extends #66-73 guard to --update; warn-only default + opt-in --dedupe-hooks, claude-only, no new marker.
- [No forced changes](feedback_no_forced_changes.md) — "no change warranted" is a valid finalized answer; ground any change in a grep-verifiable gap, never manufacture a diff.
- [to-spec flag state changed](project_to_spec_slash_only.md) — was slash-only; unit #252 un-flagged it 2026-08-06. Check your live skills list before assuming either state.
- [reviewed-path-gate is narrower than I thought](project_reviewed_path_gate_blocks_bash.md) — plain read-only ls/cat/grep DO work; only redirects, substitutions, git and rg are blocked.
- [ADR numbering: increment, never backfill](project_adr_numbering_increment_not_backfill.md) — the 0007 hole is not free (CONTEXT.md links it); re-derive ADR numbers at execution time, sibling specs collide.
- [Baselines expire](feedback_baselines_expire.md) — a baseline is a measurement with an expiry; untracked-file baselines need a recovery-source precondition. `git stash -u` hides files in a 3rd parent.
