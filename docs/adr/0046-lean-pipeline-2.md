# ADR 0046: Lean pipeline 2, the stop gate's marker check outranks the WIP sentinel

Date: 2026-11-02
Status: Accepted
Related: ADR-0043, ADR-0044, ADR-0045

## Context

lean-pipeline-2 (plan `docs/plans/2026-11-02-lean-pipeline-2.md`) landed units 1-14 before this docs unit. Each of its decisions D1-D6 and the stop-gate sentinel change was put through the three ADR tests: hard to reverse, surprising without its context, the result of a real trade-off.

- D1 (drop the reviewer's 1h cache TTL, `tests/validate.sh:277-286`), D2 and D3 (drop protocol sections from two persona rows, `bin/cli.js:817-880`), D4 (`unit-bookkeeping.sh repo`, `bin/unit-bookkeeping.sh:224-241`), D5 (the `Review gating:` and `Constitution:` header lines, `bin/unit-bookkeeping.sh:74-80`) and D6 (the A/B denial-only rule, `eval/abtest/lib/make-row.py:61-87`) each fail the first test: reverting is a small, test-pinned edit. No ADR for them; the changelog section holds their evidence.
- l2-sg1's sentinel deletion passes all three, so it is recorded here.

## Decision

On a gated writer's `SubagentStop`, the stop gate runs its marker check before it reads the WIP sentinel.

- A `*.pass`, `*.fail` or `*.blocked` marker newer than the writer-dispatch stamp trips the check (`hooks/scripts/lib/stop-gate-core.sh:98-104`). A trip deletes any sentinel, empty or not, unread and logs `wip-ignored d6-trip` to `wip-audit.log` (`hooks/scripts/lib/stop-gate-core.sh:105-107`), then writes the pending-review flag and blocks, naming the marker (`hooks/scripts/lib/stop-gate-core.sh:119-129`). Without a trip the sentinel works as before (`hooks/scripts/lib/stop-gate-core.sh:108-117`).
- The flag is written by `state_replace_pending_review`, which replaces whatever stands at the path (a file or a symlink, never followed) with a mode-644 file on the main path; the fallback create after a mktemp or mv failure uses the umask (`hooks/scripts/lib/state-access.sh:112-125`). If nothing can be written there the stop blocks naming the path (`hooks/scripts/lib/stop-gate-core.sh:123-124`).
- The writer-dispatch stamp is touched from an `EXIT` trap, and only when `dispatch-hygiene.sh` exits 0 (`hooks/scripts/dispatch-hygiene.sh:174-185`). A blocked dispatch or a crash leaves the stamp where it was, so a later check trips more, not less.

## Why it passes the three tests

- Hard to reverse: the order lives in the shared core that the Claude, codex and cursor stop gates all source (`hooks/scripts/lib/stop-gate-core.sh:1-2`), and the codex and cursor scripts also pin `writer_lane` (`adapters/codex/hooks/scripts/stop-gate.sh:102`, `adapters/cursor/hooks/scripts/stop-gate.sh:72`). Before l2-sg1 a non-empty sentinel was read first and allowed the stop before the stamp comparison ran (commit 5296a937), so a writer that forged a marker and left a sentinel stopped unchecked; putting the sentinel back first reopens that path.
- Surprising: the protocol presents the WIP sentinel as a legitimate handoff, yet the gate deletes it unread on a trip.
- A real trade-off: the alternatives were to honour the sentinel (the old order), or to keep an existing flag. The cost of the chosen order is that a genuine handoff that coincides with a newer marker is blocked, and its reason is lost: the `wip-ignored d6-trip` line records the agent, not the reason (`hooks/scripts/lib/stop-gate-core.sh:107`).

## Consequences

- The reviewer's own `SubagentStop` still clears every pending-review flag whatever its verdict (`hooks/scripts/lib/stop-gate-core.sh:44-51`).
- `unit-bookkeeping.sh check` was hardened in the same plan. It escalates `index-flags` for an assume-unchanged or skip-worktree file (`bin/unit-bookkeeping.sh:122`) and `criteria-mismatch` for a contract path with a `..` segment (`bin/unit-bookkeeping.sh:171`). A dirty or untracked tree is `fail uncommitted`, not an escalate (`bin/unit-bookkeeping.sh:120`). This closes ADR-0045's accepted residual about skip-worktree files.
- Accepted or open residuals, each checked against the code:
  - A `SIGTERM`, `SIGINT` or `SIGHUP` that reaches `dispatch-hygiene.sh` in the middle of a blocked gated dispatch still moves the stamp. The trap reads `$?` and sees 0 after a fatal signal (measured with bash 5.2.21 on this machine: a script with only an `EXIT` trap that signals itself reports `rc=0`), so the touch at `hooks/scripts/dispatch-hygiene.sh:179-181` runs. Before l2-sg2 the stamp moved on every gated dispatch, blocked or not, so this narrows the exposure and adds no capability. Closed by rs-stamp: TERM, INT and HUP traps clear the stamp-due flag.
  - An assume-unchanged or skip-worktree edit inside a submodule passes `check`. The superproject's `git ls-files -v` shows the submodule as one `H` entry and `git status --porcelain` stays clean (reproduced with git 2.43.0), so `bin/unit-bookkeeping.sh:119-122` cannot see it. Closed by rs-check: `check` escalates `submodule` when `git ls-files -s` lists a mode-160000 entry or fails.
  - Correction to the plan's D5 (`docs/plans/2026-11-02-lean-pipeline-2.md:69-71`), which calls a false `Review gating: off` harmless because it "only withholds markers, which the gates then miss (fail closed)". In default mode a false `off` makes the reviewer run no marker write of any kind (`agents/reviewer.md:181-189`). The missing `.fail` record matters beyond the gates: the fix contract takes its `fix-of:` timestamp from the latest `.fail` record (`agents/orchestrator.md:121-122`) and the 2-FAIL cap count reads `.fail` history (`templates/persona-protocol.md:307-309`). The verdict text is still the reviewer's own, so a false `off` never turns a FAIL into a PASS. Closed by rs-prose: the reviewer runs the `jq` read when the header says `off` as well as when it is absent. The header is printed from the config by the script (`bin/unit-bookkeeping.sh:75-79`), so it is wrong only if the orchestrator alters it. Accepted.
  - `hooks/scripts/lib/stop-gate-core.sh:30` still says the stamp is touched "at each gated dispatch"; it is touched at each allowed one. Lib text. Closed by rs-corelib.
  - `scripts/token-usage/agg.py:73`, `scripts/token-usage/agg2.py:47` and `scripts/token-usage/cache.py:41` identify the reviewer by the pair `roast-work` plus `ubiquitous-language`. Since l2-slim the reviewer preloads `roast-work` only (`agents/reviewer.md:8`), so new reviewer transcripts are not attributed to it. Closed by rs-tokens: a transcript whose only skill is `roast-work` maps to the reviewer.
  - No pre-block on Bash writes to protected paths. Accepted (2026-11-03 residuals plan).
  - A writer deleting its own pending-review flag after its last stop. Accepted (2026-11-03 residuals plan).
  - `check`'s total run time (precheck plus deferred re-runs, 590 s each) can pass the 600 s Bash ceiling; the cancelled call prints no `check:` line, which the protocol routes to `medium`, so it fails closed. Accepted (2026-11-03 residuals plan).
  - The dashboard views lost with `decisions.js` (plan excerpt browser, milestone-auditor paste-back, defer/skip composer) are not trivially restorable, since commit 2c1e5a2a also rewrote `discover.js` and 647 lines of `index.html`. Accepted (2026-11-03 residuals plan).
