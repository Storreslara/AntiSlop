# Contributing

This is a personal Claude Code setup shared with friends — contributions are
welcome but kept lightweight.

## Filing an issue

Use the bug report template. It'll ask for three things that matter more than
usual for this repo:

1. **Claude Code version** (`claude --version`).
2. **The plugin's current version vs. this project's adapted version.** Check
   `.claude-plugin/plugin.json`'s `version` against
   `.claude/persona-config.json`'s `pluginVersion` in the project where the
   bug happened. A mismatch is the root cause of a large fraction of reports
   — if you see one, run `/antislop:update-antislop` (or `/setup-personas
   --update` on the npx path) first and see if the bug persists before
   filing.
3. **Whether the failure was in a plugin-shipped file or an ADAPT-copied
   project file.** Plugin files live wherever you cloned this repo (e.g.
   `~/antislop`, per the README's clone example — the directory name is
   arbitrary) or wherever Claude Code's plugin cache put it after a
   marketplace install; ADAPT-copied files live in the affected project's
   `.claude/agents/`, `.claude/persona-protocol.md`, etc. This distinction
   determines whether the fix belongs in this repo or is a one-off local
   customization.

## Making changes

- Run `bash tests/validate.sh` before committing — it checks bash syntax,
  JSON validity, agent/skill frontmatter, and that optional-persona
  references stay conditionally phrased.
- If you touch a hook script, a persona body, or `setup-personas`, re-run the
  empirical smoke test described in README.md's Install section
  (`claude --plugin-dir`) — this plugin has already had real bugs that only
  showed up when actually run against Claude Code, not from reading the
  files.
- Bump `.claude-plugin/plugin.json`'s `version` and add a `CHANGELOG.md`
  entry for anything more than a typo fix — the version-stamp/`--update`
  mechanism depends on the version actually changing when the content does.
