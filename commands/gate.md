---
description: Switch review gating off or back on (`/antislop:gate off|on`); `on` means `reviewGating.mode` `enforce`. Edits the protected config through a human-confirmation prompt.
disable-model-invocation: true
---

Argument: `off` or `on`. `on` means `enforce`.

Run this from the main session only. It does nothing from a subagent, or under
a permission mode where `harness-integrity-gate.sh` denies rather than asks.

1. Read `reviewGating.mode` in `.claude/persona-config.json` and state the
   current value. An absent key, or any value other than `off`, means `enforce`.
2. List standing `.claude/.pending-review.*` flags and undecided escalation
   packets (directories under `.claude/human-review/` with no human decision
   file). Off mode never clears them. Stale flags and `.review-join.*` stamps
   left on disk apply again when you flip back to `enforce`, so tell the human
   to delete or resolve them first. Warn about an undecided packet before
   switching to `off`; do not refuse.
3. Apply the change with the `Edit` tool only, never Bash and no CLI write
   route. For `off`, set `reviewGating.mode` to `"off"`. For `on`, delete the
   key or set it to `"enforce"`. Tell the human a confirmation prompt will
   appear and that they approve it there.
4. Tell the human to commit `.claude/persona-config.json` themselves and start
   a new session. Until then the config-drift check reports a drift on every
   flip, off to enforce included; that is the tamper signal working, not a
   fault.
5. State what stays armed under `off`: `protected-paths.sh`,
   `harness-integrity-gate.sh` and config-drift detection,
   `reviewed-path-gate.sh`, the reviewer-dispatch identity and privileged-name
   guards, and the stop-gate test+lint check. Reviewer verdicts become
   advisory.
