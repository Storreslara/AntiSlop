---
name: protected-paths-blocks-preapproved-edits
description: protected-paths.sh refuses Write/Edit on the two gate scripts even when the dispatch says the human pre-approved it; the only remedy is a human config change, so report and wait
metadata:
  type: project
---

`hooks/scripts/human-decision-gate.sh` and `hooks/scripts/reviewed-path-gate.sh`
are both in `.claude/persona-config.json` `protectedPaths`, and
`protected-paths.sh` (PreToolUse, `Write|Edit`) refuses them unconditionally
with "Requires explicit human approval". A dispatch packet stating that the
operator granted approval **in advance** does not clear it — the hook has no
channel to see that, and an agent message is never the permission system.

**Why:** the hook matches `Write|Edit` only, so a `cat > … <<'EOF'` heredoc
slips past it silently. That route is a self-authorized bypass, and dispatches
for these units name it as forbidden explicitly. It is also NOT the shared
protocol's Write/Edit-unavailable fallback, which covers the tool being
*disabled*, never a gate actively *refusing*.

**How to apply:** probe the block with the first real edit before investing in
the rest of the unit — one blocked `Edit` costs nothing, whereas discovering it
after writing 60 test cases leaves a red suite in a shared tree. On refusal,
stop with the tree clean and green, write a WIP sentinel, and report that the
human must clear it (remove the `protectedPaths` entry for the duration, or
apply the edit themselves). Precedent: `.claude/wip-audit.log` 2026-08-12,
agent `a3bc162d81334e5cf`, unit gh345-2, identical situation on the sibling
gate — the human removed the entry. Recurred 2026-08-24 on hdg-prose-2, and
`rpg-comment-3` will hit it next.

A subagent cannot read its own `agent_id`, so the sentinel path
`.claude/wip-handoff.<agent-id>` can only be guessed (the session UUID is the
`.session_id` fallback and is visible in the scratchpad path). Say in the
report which path you used, since a mis-keyed sentinel is inert litter — see
[[check-index-before-commit]] for the other shared-tree hazards.
