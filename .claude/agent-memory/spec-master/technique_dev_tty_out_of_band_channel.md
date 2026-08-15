---
name: dev-tty-out-of-band-channel
description: MEASURED — /dev/tty is a real out-of-band channel an agent cannot read (ENXIO, no controlling terminal), and its openability, not stdout.isTTY, is the correct availability test
metadata:
  type: project
---

Measured 2026-08-15 across three launch contexts while designing the dashboard
Run button (#377):

| Launch context | `process.stdout.isTTY` | `open("/dev/tty","w")` |
|---|---|---|
| Agent `Bash` tool (stdout captured) | `false` | **fails, `ENXIO`** |
| Human terminal (pty) | `true` | succeeds |
| Human terminal, `> log.txt` | `false` | **succeeds** |

Two conclusions, both load-bearing:

1. **A `/dev/tty` write is genuinely out-of-band.** Verified with stdout
   redirected to a file: the `/dev/tty` write landed on the terminal and the
   redirect file contained only `stdout.isTTY=false devtty=true`. An agent
   capturing stdout — or reading the redirect file — never sees it. This is a
   channel separation, not a header check, and it is the only same-uid
   asymmetry I found that survives scrutiny.
2. **Test `/dev/tty` openability, never `stdout.isTTY`.** A human who
   redirects stdout still has a controlling terminal; gating on `isTTY` would
   lock out a legitimate user. The ENXIO branch is what actually identifies
   "no human at the other end".

**Residual, state it every time:** an agent can deliberately allocate a pty
(`script -qec` — I did exactly this while measuring). So this never *stops* a
determined same-uid attacker; it makes the bypass an unmistakably intentional
act with no plausible deniability. That is parity with
`human-decision-gate.sh`'s own bar, which is likewise defeated by re-spelling
a path — its block message says so. Parity is the ceiling at same-uid; claiming
more is dishonest.

**How to apply:** reach for this whenever a spec needs "only a human can
trigger X" on a loopback service. Reject the usual candidates first and say
why — Origin/Referer/`Sec-Fetch-Site` are forged by a same-machine `curl`, and
any nonce embedded in the served page is readable by anything that can fetch
the page. The rule that kills most designs: **an agent that can request the
page can read anything the page is sent**, so the second factor must never
appear in a response body.

See also [[project_dashboard_invoke_is_rce]] for why the channel alone is not
enough on this particular surface.
