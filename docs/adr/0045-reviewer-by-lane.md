# ADR 0045: Reviewer by lane

Date: 2026-11-01
Status: Accepted
Related: ADR-0043, ADR-0044

## Context

In the A/B harness the reviewer ran 43 dispatches and returned PASS 43 of 43 times. It cost $46.6, 37% of Arm B spend. Of 41 sampled defects, 41 of 41 were real and were caught elsewhere (by tests, the precheck or the scope gates), not by a reviewer verdict. No reviewer verdict changed an outcome, though the evals were five toy repos.

## Decision

- A unit in the `small` lane skips the reviewer. `medium` and `full` keep it, with its flag and the route gate unchanged. The lane is the one `bin/unit-size.sh` prints and records; sensitive paths are never small.
- A small unit gets `unit-bookkeeping.sh check` instead. Only `pass` means done. `fail` and `escalate` move the unit to medium (`unit-size.sh --at-least medium`), so the fix gets the flag, the reviewer and the FAIL ladder. The orchestrator may lift a lane, never lower it.
- In agent-teams mode every unit keeps the reviewer, because `task-gate.sh` refuses an `impl:` completion without a `.pass`.
- Small-lane units close no tracker issue by the scribe (no quoted reviewer PASS); the orchestrator lists the issue as open with the check line.

## Consequences

- A small unit gets no independent review. A defect that passes its own criteria and stays in scope ships without a second reader. The exemption mostly reaches docs, tests and non-sensitive `bin/` scripts.
- The check was hardened over three review rounds in rv-harden2. It is fail-closed with one `pass` path, and escalates on: no criteria, sensitive paths, a dirty or untracked tree, an empty range or bad baseline, a criteria-count mismatch, a second criteria heading, or any fence in the criteria section.
- rv-stopgate: only an exact `small` dispatch-lane record skips the pending-review flag. rv-mainstop made a small-lane trip of the forged-marker check write the flag anyway.
- rv-routemark: marking a flag `review-dispatched:` requires the reviewer's namespace to match the flag's grant. This narrows the contract's "every flag" wording.
- Accepted residuals:
  - A forged `review-dispatched:` flag acts like an unlogged `defer:`; the route gate still blocks the next dispatch.
  - A parallel hook that denies the reviewer spawn after marking leaves the flags marked, the same exposure as a sticky `defer:`.
  - The per-unit lane file is gitignored and unprotected; the dispatch-lane record is written at dispatch time, before the writer exists, and the first record wins. A writer that rewrites its transcript `.meta.json` id could join a forged record.
  - `--skip-worktree` files are missed by the dirty-tree test.
  - Marker audits may list small units as having no marker, and `dispatch-hygiene.sh` H3 cannot detect a re-dispatch of a finished small unit.
- Known stale text left for a later unit: `hooks/scripts/lib/stop-gate-core.sh` (~line 48) still prescribes a `defer:` redirect, and the protocol's "overwrite a flag" is loose because `flag` prepends.
