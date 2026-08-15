---
name: negative-grep-substring-reorder
description: a claim-anchored negative grep for "stale phrasing" can match on a pure substring even after a correct semantic rewrite — reorder terms to break the substring, don't just extend the sentence
metadata:
  type: feedback
---

When an acceptance criterion pairs a positive grep (new content present) with
a negative grep (old phrasing gone), and the negative pattern is a short
substring like `'declared UNION (has memory'`, appending new content AFTER
that substring does not remove it — the substring is still there verbatim,
so the negative check still fires even though the rewrite is semantically
correct (gh343, Effective-tools formula: adding a third UNION term after the
old two-term prefix left the exact banned prefix intact).

**Why:** grep substring matching doesn't care about what surrounds it. A
"remove the stale N-term phrasing" instruction, read literally, is asking to
remove that literal substring, not just to make the paragraph say something
new and longer.

**How to apply:** when a criterion bans a short literal substring that
happens to be a prefix of your correct rewrite, reorder the clauses (union is
commutative for a formula like this) so the banned prefix no longer appears
contiguously, then re-run the actual `grep -q ... && exit 1` check yourself
before reporting ready-for-review — don't just eyeball that the new content
is present.

Separately noted same unit: `git commit -m "$(cat <<'EOF' ... EOF)" -- <path>` fails
with a pathspec error if `-- <path>` is written before `-m` — `git commit -- path -m "msg"`
treats `-m` and the message text as pathspecs. Always put `-m "..."` before `-- <paths>`.
