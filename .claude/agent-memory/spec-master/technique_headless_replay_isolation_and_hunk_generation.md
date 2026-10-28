---
name: technique-headless-replay-isolation-and-hunk-generation
description: Isolating a headless `claude -p` eval run (allow rules are not a sandbox; use a PreToolUse guard + tripwire + fetch-by-sha clone), and generating contract-anchors-conformant hunks from a tested scratch diff
metadata:
  type: feedback
---

Learned while writing rfp-u2b (2026-10-27).

1. **`--allowedTools` is not a sandbox.** Per the Claude Code docs:
   - read-only Bash such as `cat` runs without a prompt in every mode;
   - a bare `Read` rule reaches any absolute path;
   - allow rules merge across setting scopes (this user's `~/.claude/settings.local.json` allows
     `Bash(python3 -c ' *)`).

   The enforcing layer is a PreToolUse hook passed with `--settings`: exit 2 blocks the call even over an
   allow rule. Add `--setting-sources local`, `--strict-mcp-config` and `--permission-mode dontAsk`. This
   CLI has no `default` mode. The docs do not say that `--settings` hooks fire in `-p` mode, so add a
   tripwire: abort if a run had `num_turns >= 2` and the hook logged nothing.
   **Why:** a leak-proof claim with no runnable proof is the vacuous-criterion trap.
   **How to apply:** test the non-dry path with a fake `claude` on `PATH` that calls the hook command
   from `--settings`.

2. **A history-limited clone:** `git init` + `git fetch --no-tags file://<repo> <sha>`, then delete
   `FETCH_HEAD`, which names the source path. On git 2.43 this fetches no later commit and writes no
   alternates.

3. **`eval/` is `export-ignore`**, so `git archive` silently drops it. Use `git show <rev>:<f>` per file
   to rebuild a baseline tree for a red-at-baseline criterion.

4. **Generate hunks; don't write them by hand.** For an existing file, difflib's grouped opcodes give one
   before/after item per hunk. Choose an anchor line that is unique or covered once by the hunk, and use
   ``` ``…`` ``` when the line has backticks. Assert that sequential application reproduces the tested
   file, then run `node bin/contract-anchors.js` until it reports `bad=0 unchecked=0`. Related:
   [[technique-whole-file-rewrite-and-trap-redirect]], [[technique-prove-contracts-on-a-clone]].
