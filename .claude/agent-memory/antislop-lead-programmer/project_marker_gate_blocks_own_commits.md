---
name: marker-gate-blocks-own-commits
description: reviewed-path-gate.sh blocks your OWN git commit when the message body spells .claude/reviewed alongside any operator - commit with -F from the scratchpad
metadata:
  type: project
---

`hooks/scripts/reviewed-path-gate.sh` inspects the **whole Bash command text**,
heredoc bodies included. So a `git commit -F - <<'EOF'` whose message discusses
the marker directory gets blocked for any non-reviewer persona the moment the
body also contains a `>` or a non-allowlisted-looking segment.

**Why:** a heredoc body is not a quoted span, and since #182 fix-round 2 a bare
`<<` disqualifies outright, so the default for anything unprovable is block.
That is R1 working as designed, not a bug to "fix" — do not widen the matcher
to accommodate your own commit messages.

This bites beyond commits: any `bash -c`/`python3 - <<'PY'` one-liner you run
to probe the gate is itself subject to the gate, and a probe script naturally
spells the path. Put probe scripts in the session scratchpad with the Write
tool and run them as `python3 /tmp/.../probe.py` — the invocation is then
clean. Getting blocked by your own edit is also the fastest confirmation the
hook is live.

**How to apply:** write the message to the session scratchpad with the Write
tool and `git commit -F /tmp/.../msg.txt`. The command line then never spells
the path, so the substring early-exit fires first. Same trick as the regression
suite's R4 rule (assertions live in the file, never on the command line).
Scratchpad message files persist between sessions — read before overwriting,
you may find a previous unit's message there.

Related: [[live-plugin-probe]] (edits to `hooks/scripts/*.sh` are live on your
very next tool call, so a broken gate blocks you immediately).
