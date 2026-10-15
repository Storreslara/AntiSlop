# Token-usage baseline, 2026-10-15

Measured on 2026-10-15 over a 21-day window (963 subagent transcripts) at HEAD `3dfdf2f` (plugin 0.31.171), with the scripts that `scripts/token-usage/` now vendors. The source is the spec `docs/plans/2026-10-15-persona-token-reduction.md`.

Command lines, run from the repository root (the default `--root` is `~/.claude/projects/-home-sebas-AntiSlop`, expanded at run time):

- `python3 -I scripts/token-usage/agg.py 21`
- `python3 -I scripts/token-usage/agg2.py 21`
- `python3 -I scripts/token-usage/cache.py 21`

After a wave lands, repeat with `--since <ISO-8601 time of the wave's landing commit>`. A target is read only at the minimum sample: lead-programmer 20 dispatches, reviewer 20, scribe 10, spec-master 5, task-master 3. The after-measurement is confounded by workload mix, so read medians with that caution.

| Persona | n | first-turn ctx (median) | cumulative input (median) | turns (median) | validate.sh runs / dispatch | gate blocks / dispatch |
|---|---|---|---|---|---|---|
| lead-programmer | 256 | 47,498 | 2,788,051 | 38 | 0.46 | 0.04 |
| reviewer | 297 | 40,001 | 3,448,887 | 49 | 2.98 | 1.09 |
| spec-master | 50 | 48,476 | 12,038,910 | 100 | 3.83 | 3.00 |
| task-master | 10 | 43,956 | 38,256,190 | 194 | - | - |
| scribe | 107 | 27,473 | 1,479,087 | 35 | 0.60 | 0.21 |

Share of cumulative input in the window: lead-programmer 29.4%, reviewer 24.2%, spec-master 20.3%, task-master 12.4%, scribe 7.0%.
