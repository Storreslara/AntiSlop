---
name: word-boundary-regex-escape-sequence
description: \bword\b bulk-rename regex silently skips matches preceded by a literal backslash-n/r escape sequence in JS source text
metadata:
  type: feedback
---

When bulk-renaming an identifier across a JS test file with
`re.sub(r'\bfoo\b', 'bar', source)`, matches inside string literals like
`'agent\nfoo: bar'` are silently skipped. The source text has the two
literal characters `\` and `n` before `foo` (not an actual newline byte),
and `n` is a word character, so there's no `\b` boundary between `n` and
`f` — the regex never fires there.

**Why:** discovered doing the quiz->examples rename across
`tests/dashboard-decision-block.test.js` / `dashboard-decision-run.test.js`
(examples-3 unit, `docs/plans/2026-08-20-quiz-to-worked-examples.md` Step 3)
— injection-payload fixtures like `by: 'agent\nquiz: passed-self-check'`
left `quiz:` untouched after the first bulk pass, caught only by a
follow-up `git grep -i quiz` sweep.

**How to apply:** after any `\bword\b`-based bulk substitution over JS
source text, always re-grep case-insensitively for the old term before
declaring the file clean — don't trust the regex pass alone. Escape
sequences (`\n`, `\r`, `\t`) preceded by a word char are the specific blind
spot; a targeted second pass replacing `\nword:` / `\rword:` (literal
backslash+letter) closes it.
