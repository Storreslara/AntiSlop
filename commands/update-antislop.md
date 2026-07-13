---
description: Resync this project's adapted persona files against the current antislop plugin version (equivalent to /antislop:setup-personas --update, exposed as its own entry point).
---

Plugin-installed projects only — this command ships via the plugin's
`commands/` directory, which the npx CLI does not copy project-locally
(unlike `skills/setup-personas`). If this project was set up via the npx
route instead of the marketplace, run `/setup-personas --update` (bare, no
`antislop:` prefix) instead; it's the same underlying flow.

**Precondition**: check whether `.claude/persona-config.json` exists in this
project. If it does NOT, this project was never adapted — there is nothing to
resync. Stop and tell the user to run `/antislop:setup-personas` (a fresh
install) instead; do not improvise a setup here.

If it does exist: invoke the `/antislop:setup-personas` skill exactly as if
it had been called with the `--update` argument (don't try to locate and read
`skills/setup-personas/SKILL.md` by a project-relative path yourself — in a
plugin install that file lives under the plugin's own root, not this
project's working directory; invoking the skill is what resolves that
correctly). That skill's own routing (see its opening comment) sends
`--update` straight to **section 11 (`--update` mode)** followed by
**section 12 (report back)** — skipping section 0.5 and sections 1-10
entirely. Section 11 itself starts by comparing this project's
`persona-config.json` `pluginVersion` against the plugin's current version
and reports "already current" and stops if they match — don't skip past that
check into re-derivation work. Do not re-run persona selection, third-party
skill installs, the Code Review Graph build, the arXiv MCP wiring, CLAUDE.md
pruning, or hook verification — section 11 is deliberately narrower than a
fresh setup.
