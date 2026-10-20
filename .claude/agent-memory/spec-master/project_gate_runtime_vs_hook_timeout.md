---
name: gate-runtime-vs-hook-timeout
description: A testAndLintCommand slower than the 600 s hook timeout is cancelled silently, so the stop-gate enforces nothing; time a gate before trusting it.
metadata:
  type: project
---

On 2026-10-19 `bash tests/validate.sh` took 1729 s. About 882 s of that was a nested full re-run inside the
reviewed-dir leak guard. The stop-gate runs it as `testAndLintCommand` with no hook `timeout`. Claude Code's
default command-hook timeout is 600 s, and a hook that hits it is cancelled with no decision, so the stop-gate's
test check had been silently enforcing nothing. Spec docs/plans/validate-speed/spec.md made lanes the default
(230 s measured).

**Why:** a gate that exceeds its host's timeout fails open with no signal, the same class as a vacuous criterion.

**How to apply:** when a spec relies on a hook-run command, measure its wall time against the hook timeout. When a
suite gets slow, check first for self-re-running guards and mutant self-reruns (probe-hook-identity runs itself 5x)
before reaching for tiering. See [[verify-own-criteria-nonvacuous]].
