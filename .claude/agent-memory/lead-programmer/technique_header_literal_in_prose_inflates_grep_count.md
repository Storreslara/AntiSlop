---
name: technique-header-literal-in-prose-inflates-grep-count
description: Grepping for a Markdown header literal (e.g. '## A note on `memory`') repo-wide can match an unrelated doc that merely quotes the header text in prose, not the header itself — scope the pathspec.
metadata:
  type: project
---

An unscoped `git grep -F -l '## A note on `memory`'` (memdirt-2, guarding
[[project_threefold_update]]'s sibling spec) matched not just the 11
intended protocol files but also
`docs/plans/2026-07-28-maxturns-cutoff-handoff.md:523`, which mentions the
header inside double-backticks as prose ("placed immediately before its
existing final section \`\`## A note on \`memory\` \`\`") rather than
carrying the header itself.

**Why:** `-F` (fixed-string) matching has no concept of "this is a
heading vs. a quotation of one" — any exact substring match counts,
including a doc merely describing/referencing the literal.

**How to apply:** when a validate.sh guard (or any acceptance criterion)
counts files containing a section-header literal, scope the pathspec to
the known universe of files that should carry it (here:
`templates/ .claude/agents/ .claude/persona-protocol.md
.claude/persona-protocol-slim.md`) rather than grepping the whole repo.
This is the same discipline as [[feedback_grep_acceptance_line_wrap]]'s
line-wrap scoping, but the failure mode is different: not a wrap break,
but an unrelated doc's prose quotation of the exact literal.
