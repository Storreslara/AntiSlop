---
name: refresh-not-rebuild-derived-corpus
description: a corpus built from growing per-clone records cannot be rebuilt with the same ids; add an in-place refresh mode matched by key + prefix. Also: check which values a runner writes before claiming which gate rule sees a failure.
metadata:
  type: feedback
---

Changing how a committed corpus derives a field (rfp-u2f: whole claims instead of a 300-char cut) is not a rebuild.
`build-corpus.py` selects from `.claude/reviewed/`, which keeps growing (57 candidates at build, 58 a day later),
so a rebuild changes the sampled ids. Its build mode also rewrites `labels.tsv` to `unknown`, which would erase
human labels. The fix is an in-place `--refresh-claims` mode: find each row's source block by its stored key
`(unit, fail_ts)`, then find the defect by cite plus "the new text starts with the stored text". Require exactly
one match, fail closed and write nothing otherwise, never touch labels, and make it idempotent. Criteria: the
fields other than the changed one are equal, the new value starts with the old one, the hash of the label file is
pinned, and a fresh refresh of the pre-unit file `cmp`s equal to the committed one.

A second lesson from the same spawn: revision 3 claimed that a capped run "shows only as NONE rows, which only the
unanswered rule sees". But `run.sh` writes the result's `num_turns` (cap+1) on every row, so the turn rule saw
it too. Before writing "rule X is the only one that sees failure Y", trace the exact values the runner writes
for Y.

**Why:** the user required the same 41 ids and a byte-identical `labels.tsv`. The obvious step ("regenerate the
corpus") would have broken both. The false premise was put to the user as a question.

**How to apply:** whenever a spec says "regenerate" for a committed artifact that comes from untracked or growing
inputs, rebuild it into a scratch file first and diff the keys. Related:
[[claude-cli-num-turns-counts-tool-results]], [[baselines-expire]].
