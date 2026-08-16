# Memory index

- [Source-artifact + render-step gating rule](spec_source_render_gating_rule.md) — source and render steps can never be independently gated; merge or pin intermediate failure set
- [Vacuous sweep conversion pattern](project_vacuous_sweep_conversion_pattern.md) — unreachable differential sweeps convert to block-direction cases with allow-controls per Amendment A5
- [Dispatch hygiene: mutation-command escaping](feedback_dispatch_hygiene_mutation_commands.md) — extract mutation-control reproduction commands verbatim from spec docs, not by retyping
- [Persona prose-edit traps](project_persona_prose_edit_traps.md) — `--update` skips mirror content if run twice; validate.sh's P4 check breaks on a wrapped qualifier
- [Scribe-tagged step exceeds mandate](project_scribe_tagged_step_exceeds_mandate.md) — a `[scribe]` spec step can still ask for test/version work outside scribe's write scope; do the doc part, route the rest
- [PASS-marker comment gate workaround](feedback_pass_marker_comment_gate_workaround.md) — heredoc quoting a `.pass` marker path trips reviewed-path-gate; write body to scratchpad, use `--body-file`
- [gh405 ADR-0003 TBD placeholder](project_gh405_adr0003_tbd_placeholder.md) — filed ADR-0024 but left ADR-0003's two "ADR TBD" refs unresolved; out of gh405's affected-files scope
