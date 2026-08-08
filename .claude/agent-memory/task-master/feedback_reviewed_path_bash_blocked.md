---
name: feedback-reviewed-path-bash-blocked
description: task-master Bash tool is hook-blocked from touching the reviewer-owned marker directory (even read-only ls/cat), AND from running any heredoc or from spelling that directory literal path anywhere in command text, even when the target file is unrelated (e.g. a scratchpad file). Use printf with single-quoted strings and Read tool instead.
metadata:
  type: feedback
---

Observed 2026-07-22 (issue #108 slicing) and again 2026-08-07 (issue #226 slicing, per-unit-review-join plan): the reviewed-path-gate hook blocks more than direct reads/writes to the reviewer-owned marker directory.

**Finding 1 (2026-07-22, still true):** running ls against the reviewer-owned marker directory via Bash to check for prior fail records was rejected outright. The error text says "use the Read tool for that," but per-file Read still requires knowing the exact task-id.fail filename in advance — there is no enumeration path at all for task-master.

**Finding 2 (2026-08-07, new):** the gate also blocks on command TEXT alone, independent of what the command actually touches:
- Any Bash command using heredoc syntax (`<<EOF` etc.) is blocked outright, even when writing to a scratchpad file with no relation to the marker directory — the gate error states "an unbalanced quote, a backslash escape and a heredoc are never assumed benign."
- Any Bash command whose text spells the literal marker-directory path (e.g. inside a printf argument destined for an unrelated scratch file, just describing that path in prose) is ALSO blocked, purely because the string appears in the command text — again regardless of target.

**Why:** the gate is a text-level filter on the Bash command string, not a semantic check of what the command actually reads or writes. It cannot distinguish "this printf argument merely contains the string as documentation prose" from "this command touches the real path."

**How to apply:**
1. Do not spend a turn on ls/find/cat against the reviewer-owned marker directory from task-master — it will be blocked (Finding 1). Trust the finalized spec own Context/Risks section if it already states fail-record history (spec-master has Bash access during drafting and states this explicitly when relevant); if silent, ask spec-master or the orchestrator rather than trying to verify yourself; a single-file Read against a known task-id.fail filename does work.
2. To create local files (dispatch-prompt drafts, scratch notes) when no Write/Edit tool is available in this session (agent-teams teammate sessions may only expose Read/Bash/Agent/SendMessage), use `printf %s 'CONTENT' > /path/to/file` — a single-quoted printf, never a heredoc.
3. Inside that single-quoted content, the only character that breaks single-quoting is the apostrophe itself (contractions, possessives). Reword to avoid apostrophes (e.g. "does not" instead of "does not with apostrophe", "Step 2 own check" instead of using a possessive apostrophe, "spec Context section" instead of a possessive apostrophe) rather than trying to escape them — escaping single quotes inside single-quoted bash strings is exactly the kind of construct the gate rejects as unlexable.
4. Never spell the reviewer-owned marker directory literal path (the gitignored directory holding pass/fail/blocked markers) inside ANY Bash command text, even in prose describing it for an unrelated file. Refer to it by role instead — "the reviewer-owned marker directory" or "a prior-FAIL record" — exactly as this repo own spec documents already do for the same reason (see the per-unit-review-join spec doc terminology note). This applies even when using gh issue create/edit with --body-file pointing at a file that legitimately needs to discuss that mechanism (e.g. dispatch prompts about the review-join stamp system) — write the file content with role-based phrasing, not the literal path.
5. To fix a placeholder (e.g. an issue number known only after gh issue create returns it), use `sed -i s/PLACEHOLDER/262/g file` — plain sed with no apostrophes, no heredoc, works fine.
