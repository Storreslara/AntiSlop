---
name: commit-msgfile-must-exist
description: a denied compound Bash call never created its heredoc'd -F message file; recreate with Write before retrying git commit -F (esc-chat-1-record)
metadata:
  type: technique
---

When a compound command (printf msgfile; git add; git commit -F) is denied by the harness, none of it ran, so the `-F` file does not exist on retry (`fatal: could not read log file`). Write the message file with the Write tool first, then retry the commit.

**Why:** the retry after the esc-chat-1-record denial failed with exit 128 for this reason, not a new denial.
**How to apply:** after any denied compound call, re-check every file the call was supposed to create.
