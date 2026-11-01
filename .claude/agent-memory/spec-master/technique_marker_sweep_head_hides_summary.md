---
name: technique-marker-sweep-head-hides-summary
description: piping marker-audit.sh --notes through grep|head -N can drop the marker-notes-sweep summary line; a missing summary is not "no note"
metadata:
  type: feedback
---

`bin/marker-audit.sh . --notes --surface=<p>` prints its `marker-notes-sweep=... spec=N` summary LAST. A loop that filters with `grep -E 'NOTE\[spec\]|untagged' | head -3` drops it whenever there are more matches than the head limit. On 2026-11-01 a spawn recorded "no summary line, so no note found" for 5 surfaces. A full re-sweep then found 1, 1, 4, 77 and 30 NOTE[spec] lines.

**Why:** the plan appendix stated that no note existed, and that was false. The reason was the output filter, not the sweep.

**How to apply:** use `grep -E 'NOTE\[spec\]|^marker-notes-sweep'` with no `head`, send it to a scratchpad file, and record spec/code/untagged from the summary line. The sweep takes about 2 minutes per surface (about 10 for `agents/orchestrator.md`), so run it in the background and wait on its PID with `timeout 590 tail --pid=<pid> -f /dev/null`. Also check `git log` before you commit the appendix, because a parallel spawn may have committed a change to it.
