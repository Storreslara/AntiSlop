---
name: technique-length-prefixed-evidence-blocks
description: Forgery-resistant raw-text evidence in a graded markdown record — length-prefixed blocks parsed sequentially; how to isolate a forgery test so the mutant actually survives without it
metadata:
  type: project
---

When a record embeds raw captured text (tmux panes, dialogs) and a gate must grade from it, fence-toggling and last-marker rules can be beaten by the text itself (a line of ``` closes the fence early, and the last block can forge an earlier mode's heading). Instead, write each block as `### dialog: <mode> <N> lines, ...` + fence + exactly N lines + fence. Parse those blocks one after another, starting at a writer-only anchor (the first `^## Appendix`), and stop at the first line that isn't a block header. The content is skipped by count and never read as structure (esc-chat-1-evidence, scripts/probe-bash-ask.sh gate()).

**Why:** a "content read as structure" mutant SURVIVED my first forgery test because I put the forged acceptEdits block inside *default's* block. The mutant went RED anyway because default lost its own block, so the test could not tell it apart from the real gate.

**How to apply:** host a forged block inside a NON-graded mode's block (e.g. dontAsk), so the only difference between the real gate and the mutant is the forgery itself. Same rule as [[mutation-proof-needs-sole-denier]]. Also: `sed '1,/re/d' | grep EOF` already forces `re` to be present (a missing `re` deletes everything), so an explicit presence check for `re` is an equivalent mutant. Report it as equivalent; it is not a coverage gap.
