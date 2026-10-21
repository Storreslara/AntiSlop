---
name: technique-prove-contracts-on-a-clone
description: Prove a gate/helper contract's test against a scratch implementation in a `git clone --local` under the scratchpad; traps found that way (sourced set -e, gate-blocked heredocs, chained anchors)
metadata:
  type: feedback
---

Before handing off a contract whose deliverable is a hook or bin helper, implement it once in a
`git clone --local` of the repo under the session scratchpad and run the contract's own test there. Then
generate the contract from those exact files with a Python script, never retyped.

**Why:** structural-stage st-u1 to st-u3 (2026-10-20) found three defects this way that the contract text
alone could not show.
- `hooks/scripts/lib/agent-identity.sh` sources `audit-log.sh`, which runs `set -euo pipefail`, so a new
  hook that sources it silently gets errexit, and its no-match greps exit 1. Fix: `set +e` after sourcing.
- A test asserted a fenced token was an entry when the parser correctly skipped it.
- Adding a hook script needs a `docs/trust-model.md` row (trust-model-bijection C8.2). abtest-arms only
  passes on a committed clone (it reads `git archive HEAD`).

**How to apply:**
- Use the Write tool, not a Bash heredoc, for any scratch file whose text spells the reviewed-markers path
  or the persona-config filename: reviewed-path-gate and harness-integrity-gate scan Bash command text,
  even for scratch paths.
- Run an anchor-exists check (each `line matching` anchor and `before:` payload, found in the file or in an
  earlier contract's after-payload) over the whole chain before committing; qw-u1 shipped a `{DOTDIR}` vs
  `{{DOTDIR}}` miss. See [[verify-own-criteria-nonvacuous]].
