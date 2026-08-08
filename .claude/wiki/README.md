# AntiSlop wiki

This is the AntiSlop plugin's own source repo, self-hosting the persona
system it ships to other projects (see `.claude/persona-config.json`).

Start here, then branch out:
- [architecture.md](architecture.md) — how the pieces fit together
- [conventions.md](conventions.md) — house rules for this repo specifically
- [dependencies.md](dependencies.md) — what this repo depends on (spoiler: almost nothing)
- [changelog.md](changelog.md) — dated log of lead-programmer work, distinct from the project's own `CHANGELOG.md`
- [probe-methodology.md](probe-methodology.md) — lessons on empirical probe design (from #139)
- [protocol-delivery-tiers.md](protocol-delivery-tiers.md) — how the shared persona protocol is inlined into persona bodies (full vs. slim tier, per-persona section selection)
- [persona-handoff-mechanisms.md](persona-handoff-mechanisms.md) — the WIP sentinel, pending-review flag, and terminal status line that let a dispatched persona hand control back cleanly, including the `maxTurns`-cutoff detection problem (`max_turns_reached`, harness version v2.1.220) they exist to solve
- [experiment-ledger.md](experiment-ledger.md) — mirror of `docs/self-improvement-loops.md`'s E1-E6 hypothesis ledger, marking which persona/hook changes were measured via the controlled eval harness vs. shipped un-measured by decision (e.g. E6, the `spec-master`/`task-master` `maxTurns` 30→40 raise)
- `modules/` — deeper notes on the meatier pieces (`cli.md`, `hooks.md`, `adapters.md`, `eval-harness.md`)

For "what does this repo do and why," also read the root `README.md` — it's
the user-facing pitch and is kept current independently of this wiki, which
exists for agent/contributor orientation instead.

**Key recent decisions:**
- [ADR 0013](../../docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md) — Efficiency audit remediation (Pass 3): fable removed from roast-work advisory pass, ADR-0006's reviewer-gate ratchet preserved unchanged, F9/F11/F10-rejection findings recorded (2026-08-07).

No `api.md`: this repo ships a CLI (`bin/cli.js`) and Claude Code
plugin surface (agents/skills/hooks/commands), not a library with a
programmatic API. The CLI's flags are documented in
[modules/cli.md](modules/cli.md); the plugin surface (slash commands,
personas) is documented in root `README.md`'s "Personas" and "Using
AntiSlop" sections.
