# Memory index

- [Source-artifact + render-step gating rule](spec_source_render_gating_rule.md) — source and render steps can never be independently gated; merge or pin intermediate failure set
- [Vacuous sweep conversion pattern](project_vacuous_sweep_conversion_pattern.md) — unreachable differential sweeps convert to block-direction cases with allow-controls per Amendment A5
- [Dispatch hygiene: mutation-command escaping](feedback_dispatch_hygiene_mutation_commands.md) — extract mutation-control reproduction commands verbatim from spec docs, not by retyping
- [Persona prose-edit traps](project_persona_prose_edit_traps.md) — `--update` skips mirror content if run twice; validate.sh's P4 check breaks on a wrapped qualifier
- [Scribe-tagged step exceeds mandate](project_scribe_tagged_step_exceeds_mandate.md) — a `[scribe]` spec step can still ask for test/version work outside scribe's write scope; do the doc part, route the rest
- [PASS-marker comment gate workaround](feedback_pass_marker_comment_gate_workaround.md) — heredoc quoting a `.pass` marker path trips reviewed-path-gate; write body to scratchpad, use `--body-file`
- [gh405 ADR-0003 TBD placeholder](project_gh405_adr0003_tbd_placeholder.md) — filed ADR-0024 but left ADR-0003's two "ADR TBD" refs unresolved; out of gh405's affected-files scope
- [Unit #408 advisory cleanup](project_gh408_advisory_cleanup.md) — stale dashboard prose and test assertions remain after removing findings pane reader; non-blocking degradation confirmed
- [Unit #411 documentation updates](project_gh411_documentation_updates.md) — refreshed Adapter behavioural parity description, added four new glossary entries for core-file extraction work
- [CONTEXT.md commit before reviewer dispatch](feedback_context_commit_before_reviewer.md) — recurring pattern: commit CONTEXT.md updates before reviewer stage to avoid dirty tree issues
- [Filehashes-currency test coverage gaps](project_filehashes_currency_test_coverage_gaps.md) — two known test-robustness gaps; not urgent or security-critical, noted for future maintenance
- [gh413 state model documentation](gh413_state_model_documentation.md) — unit gh413 scribe dispatch added three CONTEXT.md glossary entries for 5-domain state model and unified state-access.sh seam
- [gh424 spec 1 completion](project_gh424_spec1_completion.md) — 5 glossary terms all matched shipped code exactly; two distinct sanctioned-rotation call sites noted
- [Verify each disk sink and field location](feedback_verify_each_disk_sink_and_field_location.md) — gh377-7 FAIL: don't generalize one confirmed write claim to adjacent unverified ones
- [gh295-1 state-access.sh sourcing trap](gh295_state_access_sh_trap.md) — hook functions sourcing state-access.sh with set -euo pipefail must guard non-zero returns with `|| true` or fail silently
- [gh295 "surface" term for Step 3](gh295_surface_term_for_step3.md) — marker-audit flag introduces fourth meaning of "surface"; Step 3 scribe should resolve via glossary entry or rename
- [gh295-2 note classification feature](gh295_2_note_classification_feature.md) — reviewer now tags non-blocking notes NOTE[spec]/NOTE[code], spec-master sweeps them; five gaps flagged for future maintenance
