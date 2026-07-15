---
description: Resync this project's adapted persona files against the current antislop plugin version. Runs a deterministic script (bin/cli.js --update) with zero LLM/token cost in the common case — only escalates to you when a file has genuinely diverged from a fresh copy.
---

Plugin-installed projects only — this command ships via the plugin's
`commands/` directory, which the npx CLI does not copy project-locally. If
this project was set up via the npx route instead, run `node
<path-to-your-clone>/bin/cli.js --update` yourself from the project root
instead (same script, no plugin/skill needed).

1. Run, via Bash, from the project root:

   ```
   node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" --update
   ```

   Check the exit code:

   - **0** — done. Either "already current" or "update complete", with a
     per-file summary already printed. Relay that summary to the user
     verbatim and stop; don't re-derive or duplicate it in prose.
   - **1** — hard stop, read the printed message; it's one of two cases:
     - No `.claude/persona-config.json` found: tell the user to run
       `/antislop:install-antislop` (a fresh install) instead — do not
       improvise a setup here.
     - A specific file or substitution slot named as unresolvable: the script
       already auto-backfills legacy `substitutions`/`fileHashes` from disk on
       its own (zero tokens) — this exit only happens for a genuinely narrow
       remaining gap it couldn't derive (e.g. an MCP launch command never
       wired). Invoke the
       `/antislop:install-antislop` skill exactly as if called with `--update`;
       its own routing runs the script again first, then reads
       `skills/install-antislop/update-fallback.md` to resolve just that one
       gap — not a full re-adapt.
   - **2** — N file(s) diverged from a fresh copy; their diffs are already
     printed to stdout. For each one:
     - Show the user its diff (already printed above — don't re-derive or
       re-summarize it) and ask, via AskUserQuestion, whether to take the
       plugin's fresh version or keep their local edit.
     - Once you have a decision for every pending file, re-run once:
       `node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" --update --accept=<comma-separated paths to overwrite> --keep=<comma-separated paths to keep>`
       (omit whichever flag has no paths). This may exit 2 again if new
       drift shows up — loop until it exits 0.
     - Never decide accept/keep yourself; only relay the human's choice —
       that's the entire reason this step isn't fully automatic.

2. Report back what the script did. Its own printed output (from step 1) is
   the report — don't re-run anything to re-derive it.
