---
name: gh469-hcb-posttool-completion
description: hcb-posttool (issue #469) implementation state - PostToolUse registration + hook_event_name completion branch on harness-integrity-gate.sh
metadata:
  type: project
---

Implemented 2026-09-24, ready-for-review (not yet PASSed as of this write).
Commits: baa8a2f (gate + hooks.json registration), 74f4cd8 (tests),
9275119 (regenerated mirror + fileHashes). `bash tests/harness-integrity-gate.test.sh`
147/147 OK, `bash tests/validate.sh` green, `node bin/cli.js --update --check`
clean, `node --test tests/cli-hook-propagation.test.js` unaffected.

**Non-obvious design points:**
- The `completed()` helper and the `hook_event_name` branch are placed
  BEFORE `deny()`'s definition (right after the path literals), not after
  `ask()` as the dispatch's own anchor list might suggest - either placement
  satisfies "before the command= extraction", since function *definitions*
  cause no execution; only the call-site ordering matters under `set -e`.
- `completed()`'s subject arg is always an exact case-match against one of
  the five literals by the time it's called, so the reused `tr '\n\r'`
  flattening is defensive/never actually exercised on this call site (unlike
  the Bash branch's `deny A` call, where `$command` is raw agent-controlled
  text). Don't read this as dead code to remove - it's cheap insurance
  against a future loosening of the exact-match.
- A newline embedded in `file_path` cannot forge a second audit line,
  because the case match is exact equality against a literal - the injected
  text just fails to match and nothing is logged (fails closed). Verified as
  its own case (C2.3 case r3) rather than assumed.
- C2.4(a)/(b)'s "N new audit lines" pairing checks are vacuous unless you
  also assert the LAST line's content (`completed ... set=X`) - a naive
  count-only check passes even pre-implementation, because the current
  Write/Edit deny fallback also writes exactly one line for the same
  PostToolUse-shaped payload. Caught this by noticing the count checks
  stayed green in the RED run and tightened them to check content, not just
  count.
- Committing `.claude/persona-config.json` used the sanctioned
  `git add -A` + `git restore --staged <unrelated paths>` + plain
  `git commit -m` route: `git add -A` avoids spelling any Set A literal in
  the Bash command text, then `git restore --staged` unstages pre-existing
  unrelated dirt (this session's own `MEMORY.md` and untracked memory notes
  from the PRIOR unit) by path - safe, since none of those paths are Set A
  literals. See [[project_harness_integrity_gate_persona_config_commit]] for
  the base technique and [[technique_heredoc_anchor_trips_set_a]] for a
  related gotcha hit while editing the gate script itself.
