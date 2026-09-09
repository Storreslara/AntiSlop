---
name: bash-brace-class-expansion-trap
description: ${var//[{}]/*} silently truncates at the } inside the bracket expression — bash brace-counting ignores bracket expressions, so the tail becomes literal text
metadata:
  type: project
---

`${g//[{}]/*}` does NOT do what it reads as. Bash matches the `${...}`
closing brace by counting braces and does not exempt a `[...]` bracket
expression, so it terminates the expansion at the `}` *inside* `[{}]`. The
remainder — `]/*}` — is appended to the result as literal text.

Use two separate substitutions with escaped braces instead:

```bash
g="${g//\{/*}"; g="${g//\}/*}"
```

(`${g//[\{\}]/*}` also works, but the two-step form has no bracket/brace
ambiguity left to reason about.)

**Why it matters:** the failure is silent and non-local. In
`hooks/scripts/harness-integrity-gate.sh` this appended `]/*}` to *every*
candidate path, so the whole glob-match fallback stopped matching and ~30
previously-green cases flipped to ALLOWED at once. It reads as "my change
broke everything", which sends you hunting for a control-flow error rather
than a quoting one.

**How to apply:** when a one-line parameter-expansion edit makes a wide,
unrelated set of cases fail together, print the transform's output for one
input before debugging the logic — the value itself names the bug. And never
put a literal brace inside a bracket expression in `${var//pat/repl}`.
See [[bash-word-assembly-in-gates]].
