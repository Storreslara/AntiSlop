---
name: claude-cli-num-turns-counts-tool-results
description: claude -p's num_turns on a finished run is 1 + tool results (one user message each), not loop turns; a --max-turns cut also reports cap+1 but has no result text. Gate rules on num_turns measure tool calls.
metadata:
  type: reference
---

`claude -p --output-format json` reports `num_turns` two ways (read from the bundled source of 2.1.312, 2026-10-28):
- `subtype: "success"`: `num_turns` starts at 1 and adds 1 per `user`-type message, and Claude Code writes one user
  message per tool result, even for calls batched in one API turn (2,388 transcript tool results, each alone).
  So it is 1 plus tool calls, refused calls included.
- `subtype: "error_max_turns"`: `num_turns` is cap+1 (the loop iteration count), and there is **no `result`** text.

**Why:** Gate G of the refutation-pass plan failed with `max-turns=11` under `--max-turns 10`. Everyone assumed
the run had been cut off, but the 11-turn rows carried parsed answers, so it had finished after 10 tool calls.

**How to apply:** when a spec puts a gate on `num_turns`, say whether it means a tool-call budget or the
turn cap. Record `subtype` to detect a real cap hit. In the brief, "batch calls in parallel" saves turns, not
`num_turns`. Find the source by grepping the binary for byte offsets (`grep -a -b -o 'type:"max_turns_reached"'`),
then `dd` around them. A plain `grep -o` with wide context over the 290 MB binary times out. Related:
[[headless-replay-isolation-and-hunk-generation]].
