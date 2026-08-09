---
name: bash-jq-tsv-pitfalls
description: Two silent-failure gotchas hit while writing scripts/agent-audit.sh - IFS=$'\t' read collapses consecutive tabs, and jq's `X // empty` inside an if/comparison silently suppresses all output rather than falling through.
metadata:
  type: project
---

Two bash/jq pitfalls found while building `scripts/agent-audit.sh` (issue
#281, agent-auditor Step 1) that cost significant debugging time and will
recur in any script that emits/parses TSV rows from jq output or builds
jq filters with fallback defaults.

**1. `IFS=$'\t' read -r a b c` does NOT preserve empty fields.** Tab is one
of the three "IFS whitespace" characters (space, tab, newline). Bash's
`read` treats *consecutive* IFS-whitespace characters as a single
delimiter, even when IFS is set to a lone tab - this is different from
comma/pipe/other non-whitespace delimiters, which split literally.
Concretely: a TSV row `a\tb\t\td` (empty third field) read with
`IFS=$'\t' read -r a b c d` assigns `c=d`'s intended value to `c` and
leaves `d` empty, silently shifting every field after the empty one.
**How to apply:** before emitting a TSV row from a script, guarantee NO
field can ever be empty (substitute a placeholder like `"-"` for anything
that might be missing/empty) rather than relying on `read` to preserve an
empty field between two tabs. Discovered because a `jq` filter (see #2
below) produced empty output for a field that should have been `"0"`.

**2. `X // empty` inside `if COND then ... end` or bound via `as` silently
suppresses the WHOLE expression's output, it does not fall through.** In
jq, `empty` is the zero-output generator, not an empty string. `.foo //
empty` when `.foo` is null/false produces literally nothing at that point
in the pipeline - and jq's generator semantics mean any `if`/`as` wrapped
around a zero-output sub-expression itself produces zero outputs for that
input, not "false" or `""`. Concretely,
`if (.taskKind // empty) == "in_process_teammate" then "1" else "0" end`
does NOT fall through to `else "0"` when `.taskKind` is absent - it
produces NO output at all, exit code 0, which combined with pitfall #1
above corrupted every downstream TSV field. **How to apply:** use `// ""`
(or another literal default) instead of `// empty` whenever the result
feeds a comparison, an `if`, or an `as` binding and you want a normal
fallback value. Reserve `// empty` for `select()`/filter contexts where
"produce nothing for this input" is the actually-intended behavior.

Both bugs were invisible from `bash -n` and from spot-checking the first
few dispatches - they only manifested on a specific meta.json (no
`taskKind` key at all) partway through the 642-dispatch corpus, so any
similar script needs to be run against the FULL live corpus, not a small
sample, before trusting it. See also [[transcript-store-quirks]].
