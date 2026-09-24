# ADR 0032: Cap Bash output mechanically instead of rewriting commands

Date: 2026-09-24
Status: Accepted

## Context
The cost-governance brief that opened this spec
(`docs/plans/2026-09-23-cost-governance-output-cap-and-effort-tiers.md`)
proposed two candidate mechanisms for controlling the cost of oversized Bash
tool output entering an agent's context: (1) a `PreToolUse` hook that
rewrites the incoming command via `updatedInput`, transparently appending a
truncation pipeline (e.g. piping through `head`) before the command runs, or
(2) a purely mechanical, harness-level output cap (`bashOutputMaxChars`) that
spills overflow to a file and hands the model a preview plus a path, with no
rewriting of the command the agent asked to run.

The rewriting approach has a fatal defect specific to this project's Bash
tool: it masks exit status. Piping a command's output through `head` (or any
downstream consumer) replaces the original command's exit code with the pipe
consumer's own — `false | head` exits 0, not the caller's non-zero — and this
repo's Bash tool does not set `pipefail`, so a `PreToolUse`-injected pipeline
would silently convert a failing command into an apparently-successful one.
Every reviewer/gate script in this repo (`stop-gate.sh`, `task-gate.sh`,
`marker-write.sh`, and the rest) depends on exit-code fidelity from the
commands it runs to decide PASS/FAIL; transparently rewriting the command
text would corrupt that contract for any script whose output happened to
exceed the cap.

## Decision
Reject `PreToolUse` + `updatedInput` command rewriting as the cost-control
mechanism. Adopt the mechanical `bashOutputMaxChars` setting alone (Step 2):
a harness-level cap that spills output over the threshold to an
[[overflow file]] and returns a preview plus the file's path, without
altering the command the agent submitted or its real exit code in any way.
See `CONTEXT.md`'s **bashOutputMaxChars / the Bash-output cap** entry for the
mechanism's shape and its `narrower re-query` counterpart, added by the
sibling units in this same spec.

## Consequences
- No hook script lands from this decision — `bashOutputMaxChars` is a
  settings key the harness itself enforces, not a project-authored
  `PreToolUse` hook. This keeps `docs/trust-model.md`'s hook inventory and
  `EXPECTED_SELF_REPORTED_COUNT` unchanged (Step 6 of this spec touches
  neither).
- The review gate's exit-code contract stays intact: no script that inspects
  a Bash command's exit status can be silently fooled by an
  automatically-injected pipeline, because no such injection exists.
- The cost-control burden shifts entirely to the *model's* discipline in
  responding to an overflow (the [[narrower re-query]] pattern) rather than
  to a transparent, unaccountable rewrite of what the agent asked to run.
