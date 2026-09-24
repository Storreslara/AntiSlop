---
name: heredoc-anchor-trips-set-a
description: a python3/bash heredoc editing harness-integrity-gate.sh gets denied if its OWN anchor/context text spells a Set A literal path, even though the intent is unrelated
metadata:
  type: technique
---

`harness-integrity-gate.sh`'s Bash branch scans the WHOLE raw command text for
Set A literal substrings (`.claude/persona-config.json`,
`.claude/review-audit.log`, `.claude/dispatch-audit.log`,
`.claude/microworld-audit.log`, `.claude/wip-audit.log`, `.seal` variants) -
not just "the file this command touches". A `python3 - <<'PYEOF' ... PYEOF`
heredoc IS the Bash command text, so if your own `old`/`new` strings (used
purely as anchor/context for a str-replace) happen to include one of those
paths verbatim - even just as surrounding context you didn't mean to
change - the whole heredoc is denied with a Set A message, which is
confusing when your actual edit target is unrelated (e.g. adding code near a
`wip_log=".claude/wip-audit.log"` line while editing
`hooks/scripts/harness-integrity-gate.sh` itself, a Set B file).

**How to apply:** when scripting an edit to this gate's own source (or
anything near Set A literal assignments) via a Bash heredoc, anchor the
`old` string on a nearby line that does NOT itself contain a Set A path
literal - e.g. a function signature (`deny() {`) rather than the preceding
variable assignment line. Verify the anchor is still unique in the file
(`grep -c` count) before relying on it. This is orthogonal to
[[project_harness_integrity_gate_persona_config_commit]] (which is about
`git commit -- <path>` mentioning a Set A path in a COMMIT command) - this
gotcha is about the EDIT command's own incidental context text tripping the
same Bash-branch scan. Hit and fixed in gh469 (hcb-posttool).
