# `--update` fallback: resolving one named gap

You're here because `node bin/cli.js --update` exited 1 and printed a
specific unresolved item — not because the whole project needs re-adapting.
The script already auto-backfilled everything it could deterministically
derive from disk; what's left is narrow. Read the exact message it printed
and match it to one of these cases:

## Case A — an MCP launch command still needed

The message names `.claude/agents/explorer.md` or `.claude/agents/researcher.md`
still having its `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_*>` placeholder.
This means the Code Review Graph / arXiv MCP was never wired for this
project (not a backfill gap — genuinely never set up). Follow `SKILL.md`
step 4 (graph) or step 5 (arXiv) to install and register it in `.mcp.json`,
then run `node bin/cli.js --wire-graph-mcp` (or
`--wire-arxiv-mcp=<server-key>`), then re-run `--update`. If the project
deliberately has no graph/researcher (e.g. `researcher` was never selected),
this shouldn't happen — if it does, treat it as a real bug and surface it.

## Case B — anything else

If the printed message doesn't match the case above, don't improvise a
broader re-derivation. Show the human the exact message and ask how they
want to proceed — this fallback is deliberately scoped to the one known
gap type above, not a general-purpose escape hatch.

Once resolved and `bin/cli.js --update` exits 0, you're done — it already
updated `pluginVersion` and printed its own summary; relay that, don't
re-derive it.
