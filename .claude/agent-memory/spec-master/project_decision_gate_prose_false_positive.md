---
name: decision-gate-prose-false-positive
description: human-decision-gate.sh denies git commits whose MESSAGE prose spells both trigger words; measured proof that no program-agnostic fix exists, and why git commit is safe to admit gate-locally.
metadata:
  type: project
---

`human-decision-gate.sh` fires on an AND of two bare substrings
(`human-review` + `DECISION`) anywhere in a Bash command's text. Any task-id
containing "human-review" therefore poisons every honest commit message that
unit ever writes. Measured 2026-08-24, live probes:

- `git commit -m "fix(human-review-cleanup-1): ... DECISION ..."` → **DENY**
- the SAME commit, message lacking a trigger word → **ALLOW**
- `git commit -m "...DECISION..."` (only one trigger) → **ALLOW**
- `git commit -F msgfile` (the move the gate's own text calls a bypass) → **ALLOW**

**Why:** Do not propose "just narrow the regex to a real write target." The
gate cannot resolve targets — it is purely textual, which is why the
split-variable residual is allowed. Three mechanisms were prototyped and
falsified: (1) target resolution is not computable here; (2) skeleton-based
narrowing is impossible because `command_skeleton()` renders
`git commit -m '…'` and `sh -c '…'` **byte-identically** (both
`<prog> <flag> 'XXXX'`), and the second executes its argument; (3) a
path-shape-only trigger regresses `cd .claude/human-review/u1 && printf x >
DECISION`, which is denied today. Separating the false positive from `sh -c`
**requires naming the program** — allowlist-shaped, never a denylist (a
denylist fails open on every interpreter missed, the exact ground
`benign-command.sh` gives for removing `git`/`rg`).

Admitting `git commit` in a **gate-local** recognizer grants zero marginal
capability, measured both halves: a `core.hooksPath` pre-commit hook runs on a
plain `git commit -m` whose message has no trigger words (already allowed), and
a git alias **cannot** shadow the built-in `commit`. Also `.gitignore:26`
ignores `.claude/human-review/`, so DECISION is never tracked.

**How to apply:** mirror `is_sanctioned_marker_write()`'s precedent — gate-local,
consulted only after `command_is_provably_benign()` declines, additive-only,
shared `program_allowed()` untouched (that would change reviewed-path-gate.sh
transitively). Implement the path-shape scan glob-safely: a naive
`for w in $(… | tr …)` expanded a `*` in a commit message to 22 repo filenames.
Cost already incurred: see [[survey-all-fail-records]] — the
`human-review-cleanup-1` reviewer downgraded a real defect to "derived by
reasoning, not measured" because this gate blocked its fixture, and correctly
refused to reword around it.

**Backslash half (P13), measured 2026-08-24 — operator ratified closing it.**
`command_skeleton()` rejected ANY backslash. Safe narrowing: permit one only
inside a single-quoted span (bash does no escaping there; the span still ends at
the next quote) and inside a `#` comment (a trailing `\` does NOT continue it).
Keep failing closed outside quotes and inside double quotes, and ALSO reject
`$'…'`/`$"…"` — both honour `\'`, which keeps a single-quoted span OPEN and
mis-pairs every quote after it. Patched-vs-unpatched result: both suites pass
byte-identically (43 and 364 assertions), reviewed-path-gate's whole delta is 2
intended read allowances, and 11 new backslash attacks all stay denied. P16 is
NOT a lexer bug — it is the `>` test; fix it by re-testing triggers against the
skeleton's CODE text (comments/quotes masked) plus the program allowlist.
Writing the `$'` guard as a quoted `case` pattern unbalances the file's own
quoting — use an escaped-character pattern (`*\$\'*`).

**Comments are only inert when TRAILING (both gates).** A comment on its own
line still fails closed: the skeleton splits segments on newlines, so
`segment_allowed()` reads a bare `#` as that segment's program (ratified issue
#183 residual). Related measured doc defect: `benign-command.sh`'s header tells
you to "put the comment above the command" — that does NOT work either; only
omitting it, or keeping it on the same line, does.

Design record: `docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md`;
precedent `docs/plans/2026-08-12-human-decision-gate-false-positive.md`.
Parity: `tests/validate.sh:302` runs `diff -rq hooks/scripts .claude/hooks/scripts`
and `fileHashes` pins the mirror — see [[validate-sh-is-a-mirror-parity-check]].
