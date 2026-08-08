---
name: edit-tool-unavailable-fallback
description: Edit tool call errored "not enabled in this context" despite being in declared toolset; use Bash+python3 for precise string-replace edits instead
metadata:
  type: feedback
---

In at least one team-agent-teams session (unit #272, 2026-08-08), the `Edit`
tool was declared in my persona's tools list but calling it errored `No such
tool available: Edit. Edit exists but is not enabled in this context.` This
can happen in some spawn contexts even though the persona frontmatter lists
Edit/Write.

**Why:** unclear (harness/session config), but it's not worth debugging
mid-task — just route around it.

**How to apply:** if Edit/Write error this way, fall back to `Bash` running a
`python3 - <<'PYEOF' ... PYEOF` heredoc that reads the file, does an exact
`str.count(old) == 1` assertion before replacing, then writes it back. This
gives the same "surgical, exact-match" guarantee Edit provides, unlike sed
(which the persona instructions otherwise prefer to avoid for edits).

**Gotcha inside the fallback:** watch Python's own string-escaping rules when
the replacement text itself needs literal backslash-newline line-continuations
(e.g. bash `for c in "a" \` multi-line lists). A single `\` immediately before
a newline inside a Python string literal is itself an escape (line-continuation,
eats the newline) — it will silently collapse the bash continuation onto one
line. Use `\\` (double backslash) before the newline in the Python string to
emit a literal `\` followed by a real newline. Always re-Read the written
region afterward to confirm line breaks survived, don't just trust "no
exception raised".
