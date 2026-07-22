# spec-master memory index

- [enabledPlugins format uncertainty](project_enabledplugins_format_uncertainty.md) — docs say array, shipped #66-71 guard assumes object-of-booleans; verify before building further on the object form.
- [--update dedupe-hooks spec (#74)](project_update_dedupe_hooks_spec.md) — extends #66-73 guard to --update; warn-only default + opt-in --dedupe-hooks, claude-only, no new marker.
- [No forced changes](feedback_no_forced_changes.md) — "no change warranted" is a valid finalized answer; ground any change in a grep-verifiable gap, never manufacture a diff.
- [to-spec is slash-only](project_to_spec_slash_only.md) — to-spec (and maybe grill-me) is disable-model-invocation; a subagent must apply its template manually, not via Skill tool.
- [reviewed-path-gate blocks Bash](project_reviewed_path_gate_blocks_bash.md) — spec-master can't ls/cat .claude/reviewed/ via Bash; Read the exact .fail path instead.
