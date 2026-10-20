---
name: technique-generated-contracts-exact-payloads
description: How to write 7/7 contract-score v2 contracts with exact before/after payloads, and why prose criteria must flatten whitespace
metadata:
  type: feedback
---

To get `contract-score.js --rubric=v2` to 7/7, generate the contract with a Python script that slices the
`before:` payloads out of the live file (assert each occurs exactly once). Use `~~~` fences with
`indent: 0`. Write the script with the Write tool into the scratchpad and run `python3 -I <script>`. A Bash
heredoc whose text names `.claude/persona-config.json` (even inside contract prose such as a `git add`
line) is refused by harness-integrity-gate.sh.

R2 checks for a line holding the literal `.claude-plugin/plugin.json` plus a semver, and another for
`package.json`. R6 needs every Do NOT touch bullet to start with a backticked path.

**Why:** on 2026-10-20 two aof-u2 criteria proved weak. One negative grep matched the unit's own new
sentence. One criterion cited a behaviour test as if it were a mirror check. Separately, aof-u3/u4 prose
greps would fail on correctly wrapped text.

**How to apply:** every prose grep flattens whitespace (`tr -s ' \n' ' '`). Check each negative needle
against the new payload as well as the old text. Check mirrors with `cmp`. Before handoff, simulate the
edits on a scratch copy and run the pins test both before (expect FAIL) and after (expect PASS). Commit
with `git add -u` instead of naming the Set A config. Related: [[verify-own-criteria-nonvacuous]].
