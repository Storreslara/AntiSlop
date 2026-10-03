---
name: edit-tool-unicode-escape-and-placeholder-re
description: Edit tool turns a typed  /  escape into the literal char (breaks a JS regex literal); `<VT>`-style text in a hook comment trips cli.js PLACEHOLDER_RE
metadata:
  type: feedback
---

Two traps hit in esc-chat-2b (2026-10-02):

1. Writing ` ` / ` ` inside new_string via the Edit tool landed the
   LITERAL line-separator characters in the file, not the six-char escape. In a
   JS regex literal that is a line terminator, so the module failed to load
   ("missing /"). `\u0085`, `\x1b`, `\x7f` survived as escapes.
   **How to apply:** after any Edit that types a Unicode escape, check with
   python (`s.count(' ')`) and re-escape via a python str.replace.
   **Recurred esf-gate-bytes (2026-10-03), wider:** the WRITE tool does it too,
   for EVERY typed unicode escape (U+0000, U+00A0, U+200B, U+FEFF, ...). Fix:
   spell escapes as a placeholder (`@U200b@`) and have python re.sub it to
   chr(92)+'u'+hex; then grep -nP for non-ASCII in the target.

2. `node bin/cli.js --update` warns "unresolved placeholder(s)" for any
   `<[A-Z0-9_]{2,}>` in a shipped hook script, comments included (PLACEHOLDER_RE,
   bin/cli.js:63). A comment like `cat<VT>> <path>` tripped it.
   **How to apply:** spell control chars as `\v` etc. in comments, never `<VT>`.
