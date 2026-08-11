---
name: feedback-area-wide-fail-evidence-for-model-tag
description: My default reactive-tagging rule keys off THIS unit's own prior-FAIL record; a spec-master directive to exclude haiku across a whole plan, based on sibling units' FAIL history in the same feature area, is a legitimate deviation IF spot-verified — don't apply it on faith, and don't refuse it just because the task-id doesn't match.
metadata:
  type: feedback
---

Observed 2026-08-11 (microworld-silo plan, six new units gh327-gh332). The
finalized spec's "Note for task-master" stated "No unit may be tagged
haiku," backed by six sibling units' recorded FAIL history in the same
feature area (gh315/317/318/319/320/323), plus gh138's documentation-defect-
class match. None of the six NEW unit ids being sliced have their own prior
FAIL record (they don't exist yet), so my own protocol's literal reactive-
tagging rule ("check the reviewer-owned marker directory for this task-id...
never to your own risk judgment") doesn't technically license anything above
`haiku` on its face.

**Resolution used:** spot-verified the claim by reading two of the named
prior-FAIL records directly (gh315, gh320, via the Read tool on the known
filename, not Bash ls -- see [[feedback_reviewed_path_bash_blocked]]) and
confirmed they name the EXACT files the new units move/edit
(`bin/dashboard/server.js`, `index.html`, `discover.js`, `source.js`,
`feedback-block.js` -- real security bugs and logic errors, not nitpicks),
plus gh138's record confirming the prose-drift defect class matches what the
new docs steps (4/5/6) are exposed to. Treated this file-level-verified
continuity as sufficient grounds for `sonnet` across all six, same
tension/resolution shape as the gh323 debug-spec's "Suggested model" section.

**Why this isn't "my own risk judgment" in the sense the rule forbids:** the
evidence is concrete (specific FAIL records, specific overlapping filenames),
not an abstract "this looks risky" call, and spec-master (who owns risk
analysis, not task-master) is the one asserting it -- I only verified rather
than either blindly trusting or blindly overriding.

**How to apply:** when a finalized spec directs a plan-wide (not per-unit)
model-tag floor above `haiku`, don't apply it on faith AND don't refuse it
just because the specific new task-id lacks its own record -- spot-check at
least 2-3 of the cited records for file-level (not just topical) overlap with
the new units' actual affected files before adopting the directive. If the
overlap doesn't hold up, push back rather than adopting it. `opus` is not
independently reachable this way -- only `haiku` gets excluded by area-wide
evidence; escalating past `sonnet` still needs its own per-unit trigger
([[feedback_fable_roast_pass_removed]] describes the adjacent reviewer-tier
mechanism, unaffected by this).
