---
name: dashboard-invoke-is-rce
description: MEASURED — the dashboard's POST /api/invoke is arbitrary code execution as the user with the launch token alone, which already defeats human-decision-gate.sh; the "zero write calls" claim is true of the modules and false of the process
metadata:
  type: project
---

Reproduced end-to-end 2026-08-15 in an isolated temp project root while scoping
issue #377.

`POST /api/invoke`, authenticated by nothing but the per-launch token, spawns a
bundle-relative executable with `cwd: projectRoot`, `shell: false`, no sandbox
(`bin/microworld-dashboard/invoke.js:39-44`). `discover.js` enumerates any
directory under `microworlds/` carrying a `manifest.json` — and `microworlds/`
is gitignored, ungated scratch any agent can write. So: write a bundle, POST
invoke, and the dashboard process runs your script as you.

**Why this matters beyond the dashboard.** `server.js:239` prints the token to
stdout, which per `bin/cli.js --dashboard`'s own design is exactly what an
orchestrating agent captures. So an agent that has the token already has an
unhooked path to write **any** file, including
`.claude/human-review/<task-id>/DECISION`. `human-decision-gate.sh` is a Claude
Code PreToolUse hook and has no effect on a plain Node process.

**Correction to [[project_dashboard_decision_surface_spec]]**, which records
"the dashboard has zero write calls across all 7 modules". That remains true of
the *module source* and is the wrong unit of analysis: the process spawns
children that write freely. Never again cite the zero-write-calls measurement
as evidence the dashboard cannot write.

**How to apply:** any future spec that adds a write capability to the dashboard
must state that this path already exists, or its mitigations are theater — an
attacker takes the easier route. The fix that closes both at once is stopping
the token from reaching agent-readable stdout; see
[[technique_dev_tty_out_of_band_channel]]. Scoped as Step 5 / Open Question 1
of `docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`.

**RESOLVED 2026-08-15 (human): close it.** The dashboard now refuses to start
without a controlling terminal, the URL goes to `/dev/tty`, and
`--dashboard-no-tty` starts a read-only mode. Accepted cost, stated explicitly:
an agent can no longer start the dashboard and relay itself a working
invoke-capable URL.

**The trap when implementing that (measured, cost me a defect):** do **not**
put the tty probe inside `startServer`. All eight `POST /api/invoke` cases in
`tests/dashboard-invoke.test.js` call `startServer(tmpDir, 0)` and expect real
execution, that suite is in `tests/validate.sh`, and the whole suite runs with
no controlling terminal — so gating there turns the merge gate red on day one.
The gate belongs in `runDashboard` (`bin/cli.js`), with `startServer` taking a
`readOnly` option defaulting to **false**. Not a weakening: a caller who can
`require()` the server module already has code execution in-process, so there
is no boundary on the library path. The path actually being closed is
"agent runs the CLI → scrapes token off stdout → POSTs invoke".

Related: `< /dev/null` does **not** detach a controlling terminal, so it is
useless for testing the refusal — use `setsid -w` (verified: strips the
controlling terminal, propagates the child exit code). See
[[technique_dev_tty_out_of_band_channel]].

Also worth not re-deriving: `human-decision-gate.sh` has **no adapter port**
(`adapters/*/hooks/scripts/` has none, matching its own header comment), so the
DECISION protection is claude-adapter-only already.
