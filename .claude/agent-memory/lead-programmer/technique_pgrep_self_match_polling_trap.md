---
name: pgrep-self-match-polling-trap
description: an until-loop that pgreps for a command's own literal text (e.g. "tests/validate.sh") can match its own process line and never exit, since the harness runs each Bash call via an eval wrapper that embeds the command text verbatim.
metadata:
  type: technique
---

While waiting on a long-running `bash tests/validate.sh` that had auto-backgrounded
(hit the tool's default 120s/300s timeout), I ran a separate foreground
`until ! pgrep -f "tests/validate.sh" > /dev/null; do sleep 5; done` to
block until it finished. This loop never exits on its own: the harness
invokes every Bash call through an `eval '<command text>'` wrapper, so the
polling loop's own process listing contains the literal string
`tests/validate.sh` (from its own `pgrep -f` argument), and `pgrep -f`
matches it. The loop waits on itself forever until externally killed
(confirmed by `pgrep -fa` showing the loop's own PID matching the pattern).

**How to apply:** when polling for another process's exit via `pgrep -f
"<substring>"`, pick a substring that cannot also appear in the polling
command's own invocation text (e.g. add a distinguishing flag/redirect to
the target invocation, or match on a more specific token than the poller's
own arguments), or poll via the target's actual PID/output file instead of
a text substring. If you do launch such a loop and later realize the
self-match, kill it explicitly (`kill <pid>`) rather than leaving it to
consume a background task slot indefinitely.
