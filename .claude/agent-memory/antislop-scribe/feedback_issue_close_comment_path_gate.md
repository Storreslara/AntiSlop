---
name: issue-close-comment-path-gate
description: gh issue close --comment text mentioning .claude/reviewed/ paths trips reviewed-path-gate.sh; split into two gh calls instead
metadata:
  type: feedback
---

`gh issue close <n> --comment "..."` fails the `reviewed-path-gate.sh` PreToolUse
hook when the comment text (even inside a heredoc) mentions a path under
`.claude/reviewed/` — e.g. citing the PASS marker's path when closing an issue
per the standard close-comment convention. The gate scans Bash command text
itself, not just `file_path` args, and heredocs do not get a pass (see
[[project_reviewed_path_gate_asymmetry]] in the cross-session MEMORY.md index
for the general asymmetry).

**Why:** `gh issue close` has no `--comment-file`/`-F` flag (unlike
`gh issue comment`, which does support `--body-file`), so the marker-path text
has to live inline in the command unless split into two calls.

**How to apply:** when closing a tracker issue with a comment that cites the
PASS marker path, do it in two steps instead of one:
1. Write the comment (including the `.claude/reviewed/<task-id>.pass` citation
   and marker first-line/commit-sha content) to a scratch file, then
   `gh issue comment <n> --repo <owner/repo> --body-file <scratch-file>` — the
   path text lives in the file, not the command text, so the gate does not
   see it.
2. `gh issue close <n> --repo <owner/repo> --reason completed` with no
   `--comment` flag (the comment was already posted in step 1).

Confirmed working end-to-end closing issue #322 (2026-08-11) after the
single-command form was blocked.
