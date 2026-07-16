# AntiSlop wiki

This is the AntiSlop plugin's own source repo, self-hosting the persona
system it ships to other projects (see `.claude/persona-config.json`).

Start here, then branch out:
- [architecture.md](architecture.md) — how the pieces fit together
- [conventions.md](conventions.md) — house rules for this repo specifically
- [dependencies.md](dependencies.md) — what this repo depends on (spoiler: almost nothing)
- [changelog.md](changelog.md) — dated log of lead-programmer work, distinct from the project's own `CHANGELOG.md`
- `modules/` — deeper notes on the meatier pieces (`cli.md`, `hooks.md`, `adapters.md`, `eval-harness.md`)

For "what does this repo do and why," also read the root `README.md` — it's
the user-facing pitch and is kept current independently of this wiki, which
exists for agent/contributor orientation instead.

No `api.md`: this repo ships a CLI (`bin/cli.js`) and Claude Code
plugin surface (agents/skills/hooks/commands), not a library with a
programmatic API. The CLI's flags are documented in
[modules/cli.md](modules/cli.md); the plugin surface (slash commands,
personas) is documented in root `README.md`'s "Personas" and "Using
AntiSlop" sections.
