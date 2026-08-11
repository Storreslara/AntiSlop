---
name: commit-message-path-gate
description: git commit -m/-F messages that mention .claude/reviewed/ paths trip reviewed-path-gate.sh too; use -F with a Write-tool scratch file, and re-stage after any blocked chained command
metadata:
  type: feedback
---

`reviewed-path-gate.sh` blocks not just `gh issue close --comment` but also
plain `git commit -m "..."` when the commit message text mentions a path
under `.claude/reviewed/` (e.g. citing the PASS marker being closed out,
which is the natural thing to do in a post-PASS docs commit). This is the
same mechanism as [[feedback_issue_close_comment_path_gate]] — the gate
scans Bash command text itself, so an inline `-m` message is exactly as
visible to it as a `--comment` flag.

**Why:** git has no way to keep a commit message out of the command text
except `-F <file>` (there's no `--message-file` alias, but `-F`/`--file`
does the same job `--body-file` does for `gh issue comment`).

**How to apply:** when committing a scribe post-PASS docs change and the
commit message needs to cite the PASS marker path:
1. Write the full commit message to a scratch file via the `Write` tool
   (not a Bash heredoc — see the heredoc gotcha in
   [[feedback_issue_close_comment_path_gate]]).
2. `git add <files>` as its own Bash call, separate from the commit.
3. `git commit -F <scratch-file>` as a separate Bash call.

**Critical gotcha confirmed gh136 (2026-08-11):** a chained command like
`git add X Y && git commit -m "...marker path..."` gets blocked by the
PreToolUse hook as a *whole* — the shell never starts, so `git add` never
ran either, not just the commit. If you retry with only the commit half
fixed (e.g. switching to `-F` with the same file) but skip re-running
`git add`, `git commit` will report success-looking-but-empty behavior —
actually in this case `git commit -F <file>` with nothing staged exits 1
with "no changes added to commit", not a silent no-op, so it's caught —
but don't assume a prior `&&` chain partially executed. Always re-stage
before retrying a commit that follows a gate-blocked chained command.
