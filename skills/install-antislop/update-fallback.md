# `--update` fallback: resolving one named gap

You're here because `node bin/cli.js --update` exited 1 and printed a
specific unresolved item — not because the whole project needs re-adapting.
The script already auto-backfilled everything it could deterministically
derive from disk; what's left is narrow. Read the exact message it printed
and match it to one of these cases:

## Case A — an unresolved `<MATTPOCOCK:slot>` substitution

The message names a file and a slot, e.g.:

> No recorded substitution for `<MATTPOCOCK:tdd>` in `.claude/agents/lead-programmer.md`

This happens when the project is old enough (or its persona-file prose has
been reworded across enough plugin versions) that the script's disk-diffing
couldn't match the slot's surrounding text automatically. Resolve it the same
way step 3 of `SKILL.md` originally would have:

1. List this project's installed mattpocock skills: read every
   `.claude/skills/*/SKILL.md` frontmatter `name:` field.
2. Match the named slot to one of those by PURPOSE (e.g. the `grill-me` slot
   → whichever installed skill challenges a plan's assumptions; `to-issues` →
   whichever turns work into tracker tickets — see `SKILL.md` step 3's
   purpose descriptions if the mapping isn't obvious). If a purpose has no
   installed match, STOP and surface it to the human — don't guess.
3. Add the resolved mapping to `.claude/persona-config.json`'s
   `substitutions.mattpocockSkills`, e.g.:
   ```json
   { "substitutions": { "mattpocockSkills": { "tdd": "mattpocock-skills:tdd" } } }
   ```
   (merge into the existing object — don't overwrite sibling keys.)
4. Re-run `node bin/cli.js --update`.

## Case B — an MCP launch command still needed

The message names `.claude/agents/explorer.md` or `.claude/agents/researcher.md`
still having its `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_*>` placeholder.
This means the Code Review Graph / arXiv MCP was never wired for this
project (not a backfill gap — genuinely never set up). Follow `SKILL.md`
step 4 (graph) or step 5 (arXiv) to install and register it in `.mcp.json`,
then run `node bin/cli.js --wire-graph-mcp` (or
`--wire-arxiv-mcp=<server-key>`), then re-run `--update`. If the project
deliberately has no graph/researcher (e.g. `researcher` was never selected),
this shouldn't happen — if it does, treat it as a real bug and surface it.

## Case C — anything else

If the printed message doesn't match either case above, don't improvise a
broader re-derivation. Show the human the exact message and ask how they
want to proceed — this fallback is deliberately scoped to the two known
gap types above, not a general-purpose escape hatch.

Once resolved and `bin/cli.js --update` exits 0, you're done — it already
updated `pluginVersion` and printed its own summary; relay that, don't
re-derive it.
