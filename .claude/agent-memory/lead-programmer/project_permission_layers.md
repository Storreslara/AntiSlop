---
name: permission-layers
description: The auto-mode classifier is a SEPARATE layer from permissions.allow — an allow-list entry does not satisfy it, so "add it to permissions.allow" is not a working unblock for a classifier denial
metadata:
  type: project
---

Claude Code's **auto-mode classifier** and `settings.local.json`'s
`permissions.allow` are **independent layers**. An allow-list entry does
not satisfy the classifier.

**Why:** measured on gh345-1 (2026-08-12). Editing
`.claude/persona-config.json` to temporarily remove a `protectedPaths` entry
was refused with "denied by the Claude Code auto mode classifier / Reason:
Blocked by classifier". The human then added `Edit(.claude/persona-config.json)`
to `permissions.allow`; I verified it on disk with `jq`, retried the identical
edit, and got the **identical refusal**. Only the human editing the file
directly unblocked it.

**How to apply:**
- When a classifier denial blocks you, do NOT propose "add a permissions.allow
  rule" as the fix — it will burn a round trip and fail. Ask the human to
  perform the action directly, or to apply the patch themselves.
- Distinguish the two denial texts. `Reason: Blocked by classifier` is
  substantive — treat it as final and escalate. `Stage 2 classifier error -
  blocking based on stage 1 assessment (usually transient — retrying often
  succeeds)` is explicitly transient — retry once; it usually works. Both
  happened in the same session and only the first was real.
- The classifier objects to the **act** (here: removing a security protection
  from config), not to who authorized it. A relayed approval from the
  orchestrator does not change its answer, and per persona-protocol only the
  permission system or the user's own message is consent anyway. See
  [[reviewed-path-gate-false-positive-report-and-wait]].
- Restoring a protection afterwards was NOT blocked — the asymmetry is
  weakening-vs-strengthening, so a "human unlocks, agent re-locks" split works.
