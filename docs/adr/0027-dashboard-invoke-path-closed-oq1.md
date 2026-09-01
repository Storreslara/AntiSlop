# ADR 0027: Close `/api/invoke` (OQ1 decision — dashboard launch-token exposure)

Date: 2026-08-31
Status: Accepted (plan `docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`, OQ1, resolved 2026-08-15, Step 5)
Ratified by: user (repo owner), 2026-08-15

## Context

The **Microworld dashboard** (`bin/microworld-dashboard/server.js`) exposes a
`POST /api/invoke` endpoint that executes arbitrary microworld bundles
**without human confirmation**, authenticated only by the per-launch token
printed to stdout by `bin/cli.js --dashboard`.

**Measured finding:** The launch token is not a read-only credential. An agent
holding the token can already:
- Read the dashboard's HTTP server output (stdout is captured by the agent's
  Bash tool)
- Scrape the token from stdout
- POST to `/api/invoke` to execute code as the dashboard user, with `cwd` =
  project root, `shell: false`, and no sandbox

This was reproduced end-to-end: a temporary directory with a `microworlds/`
entry yielded HTTP 200 and executed attacker-authored code.

**Consequence:** Any new security ceremony applied only to a different run
endpoint (e.g., a **Run command** button on the escalation-decision form) is
**theater** unless the launch-token exposure is addressed too — an attacker
takes the easier path.

This decision is the highest-stakes choice in the dashboard change plan
(`docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`, OQ1).

## Options considered

**(a) Recommended default — close `/api/invoke` (this decision):**
- Restrict the `/api/invoke` endpoint to refuse execution when the dashboard
  cannot access `/dev/tty` (the controlling terminal).
- Refuse to start `node bin/cli.js --dashboard` unless a controlling terminal
  is present, OR the `--dashboard-no-tty` flag is passed.
- When `--dashboard-no-tty` is passed, start the dashboard in **read-only mode**,
  refusing both `/api/invoke` and `/api/decision/*` (DECISION writes) because
  the launch token is an execution credential, not a read credential.

**Cost accepted by the human (2026-08-15):**
- An orchestrating agent can no longer start the dashboard in the background,
  scrape the token from captured stdout, and relay itself a working
  invoke-capable URL.
- Only a human-present session (one with a real terminal connected) can invoke
  bundles going forward.
- The phrase "nothing auto-starts it" (see **Microworld dashboard** entry in
  `CONTEXT.md`) is narrowed to: nothing auto-starts it, and it cannot be started in
  automation except in read-only mode.

**(b) Accept and document:**
- Leave `/api/invoke` as-is, document the hole in `README.md` and `CONTEXT.md`.
- Cheapest option, and honest.
- **Not chosen.** This option's weakness: Steps 3-4's guarantees then hold only
  against an attacker who does not know about `/api/invoke` — which is not a
  security property. Once documented and public, the hole is simply taken.

**(c) Sandbox bundle execution:**
- A correct fix, but far larger in scope and not attempted as part of this
  plan.

## Decision

**`/api/invoke` is now unreachable when the dashboard lacks access to a
controlling terminal.**

### Gating point: `bin/cli.js` `runDashboard()` function

The gate lives in the CLI launcher (`runDashboard()` in `bin/cli.js`), not in
`startServer()` in `bin/microworld-dashboard/server.js`. This is intentional:

- The `tests/dashboard-invoke.test.js` test suite calls `startServer()` directly
  (with no terminal context) and expects real bundle execution on HTTP 200.
- That suite runs as part of `tests/validate.sh` (the merge gate), which runs
  under agent conditions where `process.stdout.isTTY` is `false` and `/dev/tty`
  is inaccessible.
- If the gate were in `startServer()`, the merge gate would fail immediately.
- The real boundary being closed is: "an agent runs `node bin/cli.js --dashboard`,
  scrapes the token, and POSTs to `/api/invoke`" — this path runs entirely
  through `runDashboard()` in the CLI.

### Three launch scenarios

1. **With controlling terminal, no flag:**
   - `runDashboard()` successfully opens `/dev/tty` for writing.
   - `startServer()` is called with `{ ttyWrite: <open fd>, readOnly: false }`.
   - Both `/api/invoke` and `/api/decision/*` are permitted.

2. **Without controlling terminal, no flag:**
   - `runDashboard()` fails to open `/dev/tty`.
   - **Error:** dashboard refuses to start; user is instructed to pass
     `--dashboard-no-tty` if CI/container use is intended.

3. **Without controlling terminal, with `--dashboard-no-tty` flag:**
   - `runDashboard()` acknowledges the flag and passes `{ ttyWrite: null, readOnly: true }`.
   - `startServer()` runs with `readOnly: true`.
   - `/api/invoke` returns HTTP 403 "dashboard is running in read-only mode".
   - `/api/decision/arm` and `/api/decision/run` also return HTTP 403.
   - The dashboard operates as a read-only browser for existing state.

### Why the launch token is an execution credential, not a read credential

The token controls access to both the read endpoints (`GET /api/bundles`) and
the write/execute endpoints (`POST /api/invoke`, `POST /api/decision/*`). An
agent holding the token is authenticated to execute code, not merely to read.
If `/dev/tty` availability were gated only on *write* endpoints, it would imply
the token is safe to hand to automation for read-only use — but read-only + the
ability to scrape a launch token = write access via the easier path. Therefore,
the entire server (not just writes) is unreachable without a controlling
terminal, except via the explicit `--dashboard-no-tty` mode that disables
execution.

## Consequences

- **The pre-existing `/api/invoke` code-execution path is now blocked** when the
  dashboard is started by an agent (no controlling terminal), satisfying
  Open Question 1 of the plan.
- **Residual risk remains** (documented in `README.md`, Step 7):
  - An agent can still allocate a pty deliberately (`script -qec`, etc.) and
    thereby obtain a controlling terminal.
  - An agent sharing the human's terminal multiplexer can read confirmation codes
    and the dashboard URL via pane capture (`tmux capture-pane`).
  - The human pasting the dashboard URL or confirmation code into a chat message
    an agent reads.
  - Same-uid process memory inspection.
  None of these are *introduced* by this plan; all survive. The new guarantee is
  parity with `human-decision-gate.sh`'s own bar (which also does not stop
  deliberate pty allocation or shared-multiplexer attacks) — and that is reached
  and maintained going forward.
- **The two-mode split is explicit:** automation can now choose read-only access
  (`--dashboard-no-tty`), while human-present sessions get full access. The
  distinction is terminal-presence, not a secret or credential.

## Related decisions

- **ADR-0018** (human-in-the-loop review enabled by default) — the standing
  policy this decision's confirmation-code/controlling-terminal requirement
  enforces for the dashboard's write paths.
- **ADR-0019** (Microworld dashboard supersedes the fixture-only narrowing) —
  the decision that introduced the dashboard this ADR closes an exposure in.
- **ADR-0025** (textual-gate protection requires structural triggers, never
  word presence) — same family of reasoning applied here: the launch-token
  gate is structural (controlling-terminal presence), not a substring or
  secret check.
- **Step 5 of `docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`**
  (this decision's implementation); Step 7 (user-facing documentation of the
  modes and residual risks).
