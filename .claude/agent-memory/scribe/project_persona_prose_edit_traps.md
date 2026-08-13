---
name: persona-prose-edit-traps
description: Two traps when editing agents/*.md prose — `--update`'s version-match fast path silently skips mirror content propagation if you already ran it, and validate.sh's optional-persona check joins wrapped lines so a line break inside "this project" defeats the qualifier
metadata:
  type: project
---

Editing `agents/<persona>.md` prose and landing it has two failure modes that
both look like the edit worked.

**1. `--update` propagates content only once per version bump.**
`bin/cli.js:1091` early-returns `"already current ... Nothing to update."`
(exit 0) when `config.pluginVersion === version` and no stamp drift. That
check looks at **stamp versions, not source content**. So the sequence "bump
version → `--update` → edit `agents/foo.md` → `--update`" leaves the mirror
holding the **old** prose, while the second run exits 0 and reports success.
A mirror-parity criterion then fails after you thought you were done.

**Why:** content propagation happens in the per-spec loop *below* the fast
path, where `cleanHash` (rendered from source) is compared to the recorded
hash. The fast path never reaches it.

**How to apply:**
- Order the unit as: all source edits first → bump the version triple →
  `node bin/cli.js --update` **last**. One run then carries both.
- If you must edit after an `--update`, force the re-render with
  `node bin/cli.js --update --check`. `--check` gates **no writes** (it is
  referenced only at `bin/cli.js:1052` and `:1091`); its sole effect is
  bypassing the fast path, which is why it writes despite the name. It prints
  `<path>: updated (no local edits detected)`. Follow with a plain `--update`
  if a criterion demands that exact command exit 0.
- Never assume `--update` exit 0 means the mirror matches the source. Diff
  them, or grep the mirror for the new text.

**2. `validate.sh`'s optional-persona check is paragraph-scoped and
whitespace-literal.** For `scribe`/`reviewer`/`researcher`/`agent-auditor`, any
paragraph containing the backticked persona token must also contain one of
`if present`, `this project`, `it exists`, `otherwise`, `if no `, etc.
(`tests/validate.sh:167-188`). It joins wrapped lines with
`awk -v RS='' '{gsub(/\n/, " ")}'` — which keeps the **leading indent**, so a
qualifier split across a line break becomes `this    project` (multiple
spaces) and the literal substring match **misses**. My paragraph carried the
qualifier and still failed P4.

**How to apply:** keep the qualifier phrase unbroken on one physical line, and
prefer an explicit `(if present)` next to the backticked token over relying on
an incidental `this project's ...`. Note `spec-master`/`task-master` are
deliberately excluded from this loop. Unbackticked prose mentions
(``a nested reviewer``) are not matched — but reach for that only when the
sentence genuinely is not a persona reference, not to dodge the check.
