---
name: feedback-reviewed-path-bash-blocked
description: task-master Bash tool is hook-blocked from touching the reviewer-owned marker directory (even read-only ls/cat), AND from any command whose text spells that directory literal path, even when the target file is unrelated (e.g. a scratchpad file). Plain heredocs with no such path mention DO work. Use printf with single-quoted strings, or a path-free heredoc, and the Read tool.
metadata:
  type: feedback
---

Observed 2026-07-22 (issue #108 slicing), 2026-08-07 (issue #226 slicing, per-unit-review-join plan), and 2026-08-07 again (issue #185 slicing, gate-audit-t34-vacuity-and-gh-inventory plan).

**Finding 1 (2026-07-22, still true):** running ls against the reviewer-owned marker directory via Bash to check for prior fail records was rejected outright. The error text says "use the Read tool for that," but per-file Read still requires knowing the exact task-id.fail filename in advance -- there is no enumeration path at all for task-master.

**Finding 2 (2026-08-07, revised 2026-08-07):** the gate blocks on command TEXT alone, independent of what the command actually touches -- but the trigger is the literal marker-directory path appearing in the text, NOT heredoc syntax by itself.
- A Bash heredoc (`cat > file << EOF ... EOF`) whose body spells the literal marker-directory path anywhere (even describing it in prose, destined for an unrelated scratch file) IS blocked.
- A plain multi-line Bash heredoc with NO such path mention in its body succeeds normally -- directly re-tested 2026-08-07 while drafting long GitHub-issue-body scratch files for the gate-audit-t34 spec slice: heredocs containing hundreds of lines about this same gate script, including its line numbers and function names, went through fine once every literal marker-directory path mention was removed or replaced with role-based phrasing. Do not assume heredoc syntax itself is the trigger -- it is the path text.
- Something about the earlier blocked heredoc likely also involved other unlexable constructs (nested quotes/backslash escapes) alongside the path mention, but the path-text trigger alone is sufficient and is the one to design around.

**Why:** the gate is a text-level filter on the Bash command string, not a semantic check of what the command actually reads or writes. It cannot distinguish "this heredoc body merely contains the string as documentation prose" from "this command touches the real path."

**How to apply:**
1. Do not spend a turn on ls/find/cat against the reviewer-owned marker directory from task-master -- it will be blocked (Finding 1). Trust the finalized spec own Context/Risks section if it already states fail-record history (spec-master has Bash access during drafting and states this explicitly when relevant); if silent, ask spec-master or the orchestrator rather than trying to verify yourself; a single-file Read against a known task-id.fail filename does work.
2. A plain heredoc (`cat > file << 'EOF' ... EOF`) works fine for drafting long scratch/dispatch-prompt files, AS LONG AS its body never spells the reviewer-owned marker-directory literal path. This is usually the easier option over single-quoted printf for multi-paragraph content.
3. If the content must discuss the marker-directory mechanism (e.g. a dispatch prompt about pass/fail markers), use role-based phrasing instead of the literal path -- "the reviewer-owned marker directory," "a prior-FAIL record" -- exactly as this repo own spec documents already do for the same reason.
4. If a heredoc still gets blocked despite no obvious path mention, fall back to `printf %s 'CONTENT' > /path/to/file` (single-quoted, never double) -- the only character that breaks single-quoting is the apostrophe itself; reword to avoid apostrophes rather than trying to escape them.
5. To fix a placeholder (e.g. an issue number known only after gh issue create returns it), use `sed -i s/PLACEHOLDER/262/g file` -- plain sed with no apostrophes, no heredoc, works fine.
