# Dashboard: pill-styled decision controls + a safe in-browser "Run command"

Status: **FINAL — unconditional.** Both Open Questions resolved by the human
on 2026-08-15; no question gates dispatch. Ready for `task-master`.
Date: 2026-08-15 (finalized 2026-08-15)
Author: spec-master
PRD-view issue: https://github.com/Storreslara/AntiSlop/issues/377

## Goal

Two changes to the microworld dashboard's escalation-decision view
(`bin/microworld-dashboard/index.html`, served by `.../server.js`):

1. Replace the Route and Quiz `<select>` dropdowns with checkbox-themed,
   pill-styled controls matching the existing `.copy-btn` visual theme —
   same mutually-exclusive single-select semantics, same three values each,
   Quiz still approve-route-only.
2. Add a **Run command** control that performs the composed DECISION-file
   write from the browser, **without** handing any Bash-capable agent a
   no-human-required path to write that file.

Change 2 is a security-boundary change, decided by the human and not
re-litigated here. This plan's job is to make it safe, to state the residual
risk honestly, and to fix the fact — established by measurement below — that
the boundary it appears to breach is **already open by a different route**.

## Context

### The mechanism this touches

`.claude/human-review/<task-id>/DECISION` is the *consent artifact* of the
DECISION channel. `hooks/scripts/human-decision-gate.sh` blocks **every** agent
identity — reviewer included — from writing it through Claude Code's Bash /
Write tools. `templates/persona-protocol.md:450-451` states the human writes it
"**in their own terminal**", and the friction of doing so is deliberate: a
speed regulator, "pressure against rubber-stamping"
(`CONTEXT.md:883`, the comprehension-quiz rationale).

The gate is a Claude Code `PreToolUse` hook. It has **no** adapter port
(measured: `adapters/*/hooks/scripts/` contains no `human-decision-gate.sh`,
matching that script's own header comment), so this protection is
claude-adapter-only today. It has no effect whatsoever on a plain Node
process such as the dashboard server.

### Measured finding: the bypass this plan is asked to prevent is already live

I attempted to prove the hazard rather than assume it (constitution P1).

**`POST /api/invoke`, authenticated with nothing but the per-launch token,
already executes attacker-authored code as the dashboard user with
`cwd` = the project root, with no hook anywhere in the path.**
`invoke.js:39-44` spawns a bundle-relative executable with `cwd: projectRoot`,
`shell: false`, and no sandbox. `discover.js` enumerates any directory under
`microworlds/` that carries a `manifest.json` — and `microworlds/` is
gitignored, ungated scratch that any agent can write.

Reproduced end-to-end in an isolated temp project root (neutral write target;
I did **not** write a DECISION file to prove this, and the gate correctly
blocked my first attempt when my command text spelled that path — see
Clarifications):

```
HTTP 200 {"ok":true,"exitCode":0,"stdout":"done\n",...}
--- resulting file ---
ARBITRARY-WRITE-BY-DASHBOARD-PROCESS pwd=<project root> uid=1000
```

Consequences that shape this whole plan:

- The launch token is **not** a read-only credential. It is, today, remote
  code execution as the user, and `server.js:239` prints it to stdout —
  which per `bin/cli.js --dashboard`'s own design is exactly what an
  orchestrating agent captures.
- Therefore an agent that has the launch token can **already** write the
  DECISION file with no human and no hook. The "Run command" button does not
  create this bypass class; it joins it.
- Therefore any ceremony applied only to a new run endpoint is **theater**
  unless the launch-token exposure is addressed too — an attacker takes the
  easier path. This is why Step 5 exists and why Open Question 1 is the
  highest-stakes decision in this plan.

### Measured finding: a genuine out-of-band channel exists

The design below rests on a channel separation I measured directly rather
than assumed:

| Launch context | `process.stdout.isTTY` | `open("/dev/tty","w")` |
|---|---|---|
| Agent `Bash` tool (stdout captured) | `false` | **fails, `ENXIO`** |
| Human terminal (pty) | `true` | succeeds |
| Human terminal, `> log.txt` | `false` | **succeeds** |

Two things follow. First, a write to `/dev/tty` reaches the human's terminal
and **does not** appear on stdout or in a stdout redirect — verified: with
stdout redirected to a file, the `/dev/tty` write landed on the terminal and
the file contained only `stdout.isTTY=false devtty=true`. Second, the correct
availability test is `/dev/tty` openability, **not** `isTTY` — a human who
redirects stdout still has a controlling terminal, and `isTTY` would wrongly
lock them out.

So there is a real asymmetry to build on: an agent whose I/O is tool-call
shaped has no controlling terminal at all, while the human running the
dashboard does. This is a channel separation, not a header check.

### What was rejected, and why

- **Origin / Referer / `Sec-Fetch-Site` checks** — a same-machine `curl -H`
  forges all of them. Included nowhere in this design as a boundary. Not
  worth adding even as "defense in depth": it would make the design read
  stronger than it is, which is worse than omitting it.
- **A CSRF-style nonce minted per page-load and embedded in the served HTML**
  — an agent holding the launch token can `GET /?t=<token>` and regex the
  nonce out of the response. Zero added strength against this attacker.
- **Any secret returned in an HTTP response body** — same defect,
  generalized. An agent that can request the page can read anything the page
  is sent. This is why the confirmation code below travels over `/dev/tty`
  and is *never* in a response body.
- **Sandboxing bundle execution** to close `/api/invoke` properly — correct,
  but far larger than this change and not attempted here.

### Existing invariants this plan must not break

- `tests/dashboard-decisions-client.test.js` Test (e) asserts **zero non-GET
  fetch calls across all four decision views**. It fires no clicks — it only
  renders. A Run control that POSTs *only on explicit click* leaves Test (e)
  passing **unmodified**, which is exactly the property worth preserving:
  rendering a decision view still never writes. Step 4 requires Test (e) to
  survive byte-unchanged.
- `tests/adapter-protocol-parity.test.js` compares
  `templates/persona-protocol.md` against `templates/persona-protocol-slim.md`
  and `adapters/cursor/rules/persona-protocol.mdc`. A protocol edit and its
  ports are therefore **one unit**, never two.
- `bash tests/validate.sh` is the merge gate (constitution P5). Baseline
  measured green today: `All checks passed.` All nine `tests/dashboard-*.test.js`
  suites are in it.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Missing
4. Non-functional attributes (perf, security, scale): Missing
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-15 Functional scope & success criteria: Q Does the Run control cover
  only the escalation DECISION touchpoint, or also the pending-review
  `defer:`/`skip:` commands, which share the compose-and-copy pattern? →
  A (self-resolved): escalation DECISION only. The pending-review flag has no
  gate protecting it and is already agent-writable, so a Run control there
  carries different (lower) stakes and different design constraints; bundling
  them would hide that difference. Out of scope, stated in Step 4.
- 2026-08-15 Domain entities / data model: Q What new durable state does the
  run path introduce? → A (self-resolved): exactly one piece of ephemeral,
  in-memory state (the single outstanding arm record) and one new body line
  (`via:`) in an existing artifact. No new file, no new directory, no schema.
- 2026-08-15 User interaction flow: Q What is the click-by-click flow, and
  what does the human see at each step? → A (self-resolved): specified as the
  seven-step arm/confirm flow in Step 3 and Step 4 rather than left to the
  implementer, because the flow *is* the security property here.
- 2026-08-15 Non-functional attributes (perf, security, scale): Q What
  attacker is this defending against, and what is the honest bar? →
  A (self-resolved): a Claude Code agent on the same machine, same uid, whose
  actions are all tool-call shaped, holding the launch token. A same-uid
  attacker can always win in principle (ptrace, pty allocation), so the bar
  is **parity with the existing gate**: no bare, unremarkable request
  suffices, and any bypass requires a step that is unmistakably intentional
  circumvention with no plausible deniability. Stated as R4 and measured
  against in Step 3.
- 2026-08-15 Edge cases / failure handling: Q Which failure modes must be
  specified rather than left to the implementer? → A (self-resolved): no
  controlling terminal; code expired; code wrong; code reused; packet
  directory absent; DECISION already present; escalation timestamp stale;
  form edited between arm and confirm; two escalations armed concurrently.
  Each is given a defined behaviour in Step 3 and a test in Step 3/4.
- 2026-08-15 Technical constraints & tradeoffs: Q Does this require editing
  version-stamped protocol files, and what does that pull in? →
  A (self-resolved): yes — `templates/persona-protocol.md:450-451` says the
  human writes the file "in their own terminal", which this change makes
  conditionally false. That pulls in the cursor/slim ports (parity test), a
  `.claude-plugin/plugin.json` version bump, and a CHANGELOG entry, per
  constitution P3. Step 6.
- 2026-08-15 Terminology consistency: Q Does the request's language diverge
  from `CONTEXT.md`? → A (self-resolved): yes, in three places — see the
  `ubiquitous-language` findings folded into R8 and Step 7. Advisory only;
  it did not block this plan.
- 2026-08-15 Completion / acceptance signals: Q What is the definition of
  done? → A (self-resolved): `bash tests/validate.sh` prints
  `All checks passed.` (measured green as a baseline before any change), plus
  the per-step criteria below. No criterion names the dashboard's rendered
  output as an adjudicator (see R3).
- 2026-08-15 Non-functional attributes (perf, security, scale): Q Should the
  pre-existing, unrelated `/api/invoke` code-execution path be closed as part
  of this change, or accepted and merely documented? → A: close it (OQ1
  option (a), the recommended default). Restrict the invoke path, refuse to
  start `--dashboard` without a real terminal, and add `--dashboard-no-tty`
  as a read-only mode for CI/agent use. The human explicitly accepted the
  cost: an agent can no longer start the dashboard and relay itself a
  working invoke-capable URL. Step 5, now unconditional.
- 2026-08-15 Technical constraints & tradeoffs: Q Is the residual risk that
  survives the `/dev/tty` mitigation (deliberate pty allocation, a shared
  terminal multiplexer, the human pasting the code into chat, same-uid memory
  inspection) acceptable, or does it need a stronger boundary before this
  ships? → A: accept and document. Parity with `human-decision-gate.sh`'s own
  bar is the target and is reached; the design ships as-is with the residual
  risks written down in `README.md` (Step 7) rather than treated as an open
  gap. See OQ2 below.

### Terminology findings (`ubiquitous-language`, prose mode, advisory)

- **Lens 1 — glossary term used with a different meaning.** `CONTEXT.md:967`
  defines **Microworld dashboard** as one that "Writes nothing to disk —
  invocation results live only as ephemeral, in-page **Cell**s." Item 2 makes
  that false. Canonical entry must be amended, not silently outgrown (Step 7).
- **Lens 1 (second).** `CONTEXT.md:1115` **DECISION file**: "its unwritability
  by any agent identity is what makes its contents trustworthy as the human's
  own word." Still true after this change — the dashboard is not an agent
  identity — but the sentence now needs the qualifier that a *human-driven,
  terminal-confirmed* dashboard write is the second sanctioned authoring path.
- **Lens 2 — new synonym for an already-defined term.** The request's
  "escalation-decision view" is the existing touchpoint 1 of the decision
  surface; "pill-style buttons" is `.copy-btn` / `--radius-pill`. Both are
  informal restatements, not drift worth minting a term for. No action.
- **Lens 3 — load-bearing new domain term with no glossary entry.** Two:
  the per-decision **confirmation code** delivered over the controlling
  terminal, and **dashboard-originated decision write** (the thing the audit
  trail must distinguish). Both are load-bearing and both need `CONTEXT.md`
  entries — Step 7, for `scribe`.

## Risks and dependencies

- **R1 — the pre-existing `/api/invoke` hole dominates the risk.** Measured
  live (see Context). Until Step 5 lands, Steps 3-4's ceremony is defeated by
  an easier route. Steps 3-4 are still worth landing on their own (they make
  the *new* surface safe and they are what the human asked for), but the
  security claim in Step 7's docs must not overstate what Steps 3-4 alone buy.
  **OQ1 resolved 2026-08-15: close it.** Step 5 is therefore mandatory, not
  optional, and Step 7's docs may state the boundary without the "except via
  `/api/invoke`" caveat **only after Step 5 has merged**. If Step 5 is ever
  dropped or deferred, Step 7's prose must be reopened — the two are bound.
- **R12 — Step 5's gating seam is the CLI, not `startServer`. Measured, and
  it contradicts the naive reading of the OQ1 resolution.** All eight
  `POST /api/invoke` cases in `tests/dashboard-invoke.test.js` call
  `startServer(tmpDir, 0)` and expect real bundle execution; that suite is in
  `tests/validate.sh`, and the whole suite runs in an agent context with **no
  controlling terminal**. So gating `/api/invoke` on tty-availability *inside*
  `startServer` would turn the merge gate red on day one. The gate must live
  in `runDashboard` (`bin/cli.js`), with `startServer` taking an explicit
  `readOnly` option that defaults to **false**. This is not a weakening: a
  caller who can `require('./server')` already has arbitrary code execution in
  the same process, so there is no boundary to defend on the library path. The
  boundary being closed is specifically *"an agent runs `node bin/cli.js
  --dashboard`, scrapes the token off stdout, and POSTs to `/api/invoke`"* —
  and that path runs entirely through `runDashboard`.
- **R2 — no prior `.fail` history on this surface.** I enumerated the whole
  of `.claude/reviewed/` (283 records) rather than sampling. There is no
  `.fail` for any dashboard decision-surface unit: the `.fail` records present
  are `gh343`, `gh346-1`, `gh346-2`, `gh348-3`, `gh348-4`, `gh348-14`,
  `gh355`, `gh360`, `gh361`, none of which is this surface. **No unit in this
  plan is a re-scope of previously-failed work**, so nothing here is
  disqualified from a cheap model tag on defect-history grounds — but Steps 3,
  5 and 6 are security- and protocol-critical and should not be tagged cheap
  on their own merits. Model tagging is `task-master`'s call, not mine.
- **R3 — the dashboard prohibition, settled reading.**
  `templates/persona-protocol.md:592` says the dashboard is "**never an
  acceptance criterion** — ... no acceptance criterion in this or any future
  spec may name it." Read literally that would bar acceptance criteria for any
  dashboard unit, which is absurd. The governing reading, fixed by precedent
  at `docs/plans/2026-08-13-dashboard-decision-approval-surface.md` R3: it bars
  the dashboard's **rendered output** from adjudicating a unit under review;
  it does **not** bar criteria that test dashboard **code**. Every criterion
  below tests code via `node tests/...`. Stated here so a fresh reviewer does
  not re-litigate it.
- **R4 — the honest security bar, stated as a limit not a boast.** A same-uid
  attacker can allocate a pty deliberately (I did so with `script -qec` while
  measuring) and thereby obtain a controlling terminal. This design does
  **not** claim to stop that. It claims: possessing the launch token is
  insufficient, and every remaining path requires an act that is unmistakably
  intentional circumvention — the same bar `human-decision-gate.sh` itself
  meets, since re-spelling the DECISION path across shell variables defeats it
  too (that script says so in its own block message). Parity with the existing
  boundary is the target; exceeding it is not achievable at same-uid.
- **R5 — residual risks that remain after everything in this plan.** Named so
  they are decided rather than discovered: (a) deliberate pty allocation
  (R4); (b) an agent sharing the human's terminal multiplexer —
  `tmux capture-pane` against the pane running the dashboard would read the
  confirmation code; (c) the human pasting their terminal contents, or the
  dashboard URL, into a chat message an agent reads; (d) `ptrace`/`/proc`
  memory inspection of the server process; (e) the whole DECISION protection
  being claude-adapter-only already, since `human-decision-gate.sh` has no
  cursor/codex port. None is introduced by this plan; (b) and (c) are made
  *relevant* by it and must be documented in Step 7.
- **R6 — the comprehension quiz is unaffected.** "Never graded, never a gate"
  survives: the run path never reads `QUIZ-ANSWERS.md`, never compares a
  human's answers, and never conditions the write, the arm, or any error on
  *which* `quiz:` token was chosen. All three tokens must behave identically.
  This is not asserted by inspection — Step 3 requires a test that arms and
  runs with each of the three tokens and asserts identical success. The Quiz
  control's default stays `skipped` (Step 1); changing it to
  `passed-self-check` would nudge, which is the same defect as grading.
- **R7 — packet survivability is unaffected.** The packet stays untracked and
  is still destroyed unrecoverably by `git clean -fdx` (ADR-0017 § R10). The
  run path writes *into* an existing packet directory and must **never**
  `mkdir -p` it: a missing packet directory means no live escalation, and
  creating one would manufacture the appearance of a decision on an
  escalation that no longer exists. Step 3 requires a refuse-with-error test
  for that case.
- **R8 — glossary divergence is real and must be closed by `scribe`, not by
  the implementer.** Two canonical entries become inaccurate on merge (see
  Terminology findings). Step 7 is not optional polish.
- **R9 — "checkbox-themed" is a visual instruction, not a semantic one.** The
  request itself says "same underlying single-select semantics". Step 1
  therefore ships a checkbox *look* (a check glyph on the selected option)
  with radio *semantics* (`role="radiogroup"` / `role="radio"` /
  `aria-checked`). Recording this as a deliberate reading rather than an Open
  Question: it is cheap to overrule additively and requires redesigning
  nothing else.
- **R10 — dependency order (re-derived on finalization; unchanged).** Step 2
  (body seam) blocks Step 3 (server) blocks Step 4 (client). Step 1 is
  independent but touches the same `renderEscalationView` function as Step 4,
  so Step 1 should land first to avoid a conflict. Steps 5, 6, 7 depend on
  the shape settled in Steps 2-4. Resolving OQ1 **did not change this order**:
  Step 5 acquired a hard dependency on Step 3 rather than a new one on
  anything earlier, because it extends the very options object Step 3
  introduces (`{ ttyWrite, readOnly }`), edits the same file (`server.js`),
  and its criterion 2 asserts on Step 3's decision endpoints. The serial
  order 1 → 2 → 3 → 4 → 5 → 6 → 7 therefore remains correct and safe.
  Optional parallelism, not a requirement: Steps 4 and 5 have no dependency
  on each other and touch disjoint files (Step 4: `index.html` +
  `dashboard-decisions-client.test.js`; Step 5: `bin/cli.js`, `server.js`,
  `dashboard-server.test.js`, `README.md`), so both may run concurrently once
  Step 3 has merged. `task-master` may exploit that or ignore it.
- **R11 — no new runtime dependencies.** `crypto`, `fs`, `path` are already
  required by `server.js`. `package.json` is unchanged.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the `/api/invoke` bypass, the
  `/dev/tty` channel asymmetry (all three launch contexts), the merge-gate
  baseline, and the non-vacuity of every grep criterion below were each run
  and their output read, not inferred.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 6
  edits `templates/` only and regenerates `.claude/persona-protocol.md` via
  `node bin/cli.js --update`, never by hand-editing the mirror.
- P3 "Version-stamp discipline": satisfied — Step 6 bumps
  `.claude-plugin/plugin.json` and adds a CHANGELOG entry, because it edits
  `templates/persona-protocol.md`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the protocol
  wording added in Step 6 refers to the dashboard as an alternative the human
  may use "if running", and names no persona as required.
- P5 "`tests/validate.sh` is the merge gate": satisfied — it is the top-level
  acceptance criterion of every step, and was measured green as a baseline
  before any change.

## Step 1 — Pill-styled, checkbox-themed Route and Quiz controls

**Affected files:** `bin/microworld-dashboard/index.html`,
`tests/dashboard-decisions-client.test.js`

Replace the two `<select>` elements in `renderEscalationView` with a
pill/checkbox-styled control group. Requirements:

- A `.pill-option` / `.pill-option.checked` CSS pair reusing the existing
  `--radius-pill`, `--gvx-green`, `--gvx-bg`, `--space-*` tokens; the checked
  option carries a check glyph. No new colour literals.
- Markup: `<div role="radiogroup" aria-label="Route">` containing one
  `<button type="button" role="radio" aria-checked="...">` per value.
- **Stable per-option ids** — `routeOption-approve|reject|direct` and
  `quizOption-skipped|passed-self-check|none-offered` — with listeners
  attached via `document.getElementById(...)`, matching how
  `attachEscalationListeners` already wires controls. This is required, not
  stylistic: the test harness's `getElementById` returns from a fixed
  `elementsById` map and its `contentArea.querySelectorAll()` returns `[]`, so
  a delegated or query-selector-based wiring cannot be driven by the existing
  suite without harness rework.
- Behaviour preserved exactly: single-select; clicking an option sets
  `escalationForm.route` / `.quiz` and re-renders; the Quiz group renders on
  the approve route only and disappears on reject/direct; the Quiz default
  remains `skipped` (R6).
- Rewrite Test (f)'s assertions to be **behavioural, not markup-shaped**: the
  current `innerHTML.includes('id="quizSelect"')` and
  `includes('value="skipped" selected')` greps must be replaced by assertions
  on the *composed command text* (that it carries `route: reject` after
  clicking the reject option, and `quiz: skipped` by default), plus presence/
  absence of the quiz group. Do not merely retarget the greps at new ids —
  that would preserve a markup assertion that cannot detect a broken control.

**Acceptance criteria**

1. `node tests/dashboard-decisions-client.test.js` exits 0 and prints
   `All tests passed!`.
2. `git grep -c 'select id="escalationRoute"' bin/microworld-dashboard/index.html`
   returns 0 (currently 1) and the same for `select id="quizSelect"`.
3. `git grep -c "pill-option" bin/microworld-dashboard/index.html` is ≥ 2
   (currently 0).
4. `git grep -c 'role="radiogroup"' bin/microworld-dashboard/index.html`
   returns 2.
5. A test asserts that after firing `click` on `quizOption-passed-self-check`,
   the composed command body contains the line `quiz: passed-self-check`; and
   that with no interaction it contains `quiz: skipped`.
6. A test asserts the quiz radiogroup is absent from `contentArea.innerHTML`
   after firing `click` on `routeOption-reject`.
7. `bash tests/validate.sh` prints `All checks passed.`

## Step 2 — Extract the DECISION body as a reusable seam, add `via:`

**Affected files:** `bin/microworld-dashboard/decision-block.js`,
`tests/dashboard-decision-block.test.js`

`composeEscalationDecision` currently returns a heredoc *command*. The server
must write the *file body*, and there must remain exactly **one**
implementation of that body's shape (the fewest-seams rule).

- Add `composeEscalationDecisionBody(context)` returning
  `{ body, warnings }` — the DECISION file contents, no heredoc wrapper.
  Refactor `composeEscalationDecision` to call it, so the copy path and the
  run path cannot drift.
- Export it from `module.exports` alongside `composeDecisionBlock`. It remains
  a pure function: no `fs`, no `child_process`, no network — the module's
  existing "never executes and never writes to disk" property is unchanged and
  must stay true of *this file*.
- Add a `via:` body line recording authorship route, emitted after `by:`:
  `via: terminal` when the body is composed for the copy/heredoc path,
  `via: dashboard` when composed for the run path. Selected by an explicit
  `via` field in `context`; when `via` is absent, **no `via:` line is
  emitted** — preserving the third, pre-existing state: a DECISION file typed
  by hand from the protocol's `printf` template carries no `via:` line at all.
  Absence therefore means "hand-authored", and is not a failure.
- `assertNoCommandSubstitution` and the heredoc-delimiter refusal continue to
  apply to the composed body.

**Acceptance criteria**

1. `node tests/dashboard-decision-block.test.js` exits 0 and prints
   `All tests passed!`.
2. `git grep -c "composeEscalationDecisionBody" bin/microworld-dashboard/decision-block.js`
   is ≥ 1 (currently 0 repo-wide).
3. A test asserts `composeEscalationDecisionBody({..., via: 'dashboard'})`
   produces a body whose lines include exactly one line equal to
   `via: dashboard`, and that omitting `via` produces a body containing no
   line beginning `via:`.
4. A test asserts the body returned by `composeEscalationDecisionBody` is
   byte-identical to the heredoc payload that `composeDecisionBlock(
   'escalation-decision', ...)` wraps, for the same context — proving the
   single-implementation property rather than assuming it.
5. `git grep -nE "require\(['\"](fs|child_process|http)" bin/microworld-dashboard/decision-block.js`
   returns no matches.
6. `bash tests/validate.sh` prints `All checks passed.`

## Step 3 — Server: arm/confirm decision-write endpoints over `/dev/tty`

**Affected files:** `bin/microworld-dashboard/server.js`,
`tests/dashboard-server.test.js` (or a new
`tests/dashboard-decision-run.test.js`)

Add the capability behind a channel an HTTP client cannot read.

**Availability.** At `startServer`, attempt `fs.openSync('/dev/tty', 'w')`.
On success, the decision-write capability is constructed and the file handle
retained; on failure (`ENXIO` — no controlling terminal, i.e. the
agent-launched case), it is **not constructed at all** and both routes below
respond `403` with
`{"error":"decision writes require a controlling terminal"}`. Fail closed.
`startServer` gains an options argument so tests can drive both branches
deterministically without needing a real tty — e.g.
`startServer(root, port, { ttyWrite })`, where `ttyWrite` defaults to the
real `/dev/tty` handle and is `null` when unavailable.

**`POST /api/decision/arm`** — body `{ taskId, route, escalationTimestamp,
by, reason, quiz }`. The server:

1. Validates `taskId` against `decision-block.js`'s existing `ID_RE` grammar
   (rejects `/` and leading dots, so no traversal is expressible).
2. Verifies `.claude/human-review/<taskId>/` exists — refuses `409` if not
   (R7: never `mkdir -p`).
3. Verifies the staleness binding: `escalationTimestamp` must equal the
   first-line timestamp of the standing `.claude/reviewed/<taskId>.escalated`
   marker. Refuses `409` on mismatch or missing marker.
4. **Composes the body server-side** via `composeEscalationDecisionBody` with
   `via: 'dashboard'`. The client never supplies file text — only the
   structured fields — so the endpoint can only ever write a
   protocol-shaped body.
5. Generates a 6-character code from `crypto.randomInt` over an alphabet with
   no visually ambiguous glyphs (no `0 O 1 I l`).
6. Replaces any prior arm with a single in-memory record
   `{ code, taskId, body, expiresAt: now + 120_000, used: false }` — at most
   **one** outstanding arm process-wide.
7. Writes to the retained `/dev/tty` handle only:
   `antislop: confirmation code for DECISION <taskId> is <CODE> (valid 120s)`.
8. Responds `{ armed: true, expiresInMs: 120000 }`. **The code appears in no
   response body, no log file, no stdout, and no error message.**

**`POST /api/decision/run`** — body `{ taskId, code }`. The server compares
the code with `crypto.timingSafeEqual` after a length check, requires the arm
to be unexpired, unused, and matching `taskId`; marks it `used` **before**
writing; writes the *stored* body with
`fs.writeFileSync(path, body, { flag: 'wx', mode: 0o600 })` so an existing
DECISION is never overwritten (`EEXIST` → `409`); appends one line to
`.claude/review-audit.log`:
`<UTC ISO-8601> decision-write-via-dashboard task=<taskId> route=<route> by=<name>`
— matching the existing `decision-gate-denied identity=` line shape in that
same file; then responds `{ written: true }`. Any failure discards the arm.

Note: the body is composed once, at arm time, so its `DECISION <timestamp>`
field is the moment of arming, up to 120s before the write. That is the
moment the human decided, and is the correct value.

**Acceptance criteria**

1. `node tests/dashboard-server.test.js` (and the new suite, if split) exits 0
   and prints `All tests passed!`.
2. `git grep -c "/dev/tty" bin/microworld-dashboard/server.js` is ≥ 1
   (currently 0 across all of `bin/`).
3. **The security property, tested directly**: a test arms a decision, then
   POSTs `/api/decision/run` with a *guessed* code while holding a valid
   launch token, and asserts the response is 4xx and that no file was written
   at the packet path. A second test asserts the `/api/decision/arm` response
   body, serialized to JSON, does **not** contain the code string that was
   sent to the tty channel.
4. With `ttyWrite` unavailable, both endpoints return 403 and no file is
   written — asserted by a test.
5. Replay/expiry: a test asserts the same code fails on second use (`used`),
   and a test asserts an arm older than its TTL fails.
6. Cross-task binding: a test asserts a code armed for task A cannot write
   task B.
7. R7: a test asserts that with the packet directory absent, arm returns 409
   and **no directory is created** (assert `fs.existsSync` is false after).
8. R7: a test asserts an existing DECISION file is not overwritten (409,
   original bytes intact).
9. Staleness binding: a test asserts a mismatched `escalationTimestamp` is
   refused.
10. **R6, tested not assumed**: a test loops over all three tokens
    (`passed-self-check`, `skipped`, `none-offered`), arming and running each,
    and asserts all three succeed identically and that the only difference in
    the written bodies is the `quiz:` line.
11. `git grep -c "decision-write-via-dashboard" bin/microworld-dashboard/server.js`
    is ≥ 1 (currently 0 repo-wide), and a test asserts the audit line is
    appended to `.claude/review-audit.log` on a successful write.
12. `bash tests/validate.sh` prints `All checks passed.`

## Step 4 — Client: the Run command control and confirm flow

**Affected files:** `bin/microworld-dashboard/index.html`,
`tests/dashboard-decisions-client.test.js`

Below the existing composed-command pane and `Copy Command` button (both of
which **remain** — the terminal path is never removed), add a `Run command`
pill button and the confirm flow:

1. Click `Run command` → `POST /api/decision/arm` with the structured form
   fields.
2. On `armed`, reveal a confirmation-code input and a `Confirm write` button,
   with instruction text naming where to look: *"Enter the 6-character code
   printed in the terminal running the dashboard."*
3. `Confirm write` → `POST /api/decision/run`. On success, replace the
   controls with a written-confirmation line naming the path. On failure,
   render the server's error inline and return to the un-armed state.
4. On a 403 (no controlling terminal), render an explanation that the
   dashboard was not launched from a terminal and that the `Copy Command`
   path remains available. The Run button should be visibly disabled in that
   state rather than failing on click.
5. Editing any form field while armed discards the arm client-side and
   returns to the un-armed state — the body was fixed at arm time, so a
   silently-stale arm would write something other than what is displayed.

Scope: escalation touchpoint only. The pending-review `defer:`/`skip:` and
findings views are untouched and keep compose-and-copy.

**Acceptance criteria**

1. `node tests/dashboard-decisions-client.test.js` exits 0 and prints
   `All tests passed!`.
2. **Test (e) still passes with its assertion body unmodified** — verified by
   `git diff` showing no change inside the Test (e) block. This is the
   load-bearing criterion of this step: rendering a decision view must still
   issue zero non-GET fetches, proving the write path is click-gated only.
3. A test fires `click` on the run button and asserts exactly one non-GET
   fetch occurred, to `/api/decision/arm`, and that **no** fetch to
   `/api/decision/run` occurred before the confirm click.
4. A test drives arm → enter code → confirm and asserts a `POST` to
   `/api/decision/run` carrying the entered code.
5. A test asserts that with the arm endpoint stubbed to 403, the rendered
   output contains the no-terminal explanation and no `/api/decision/run`
   fetch is ever issued.
6. A test asserts that changing the route after arming clears the armed state
   (no confirm control rendered).
7. `git grep -c "Copy Command" bin/microworld-dashboard/index.html` is ≥ 1 —
   the terminal path is not removed.
8. `bash tests/validate.sh` prints `All checks passed.`

## Step 5 — Close the launch-token exposure (OQ1 RESOLVED: close it)

**Affected files:** `bin/cli.js`, `bin/microworld-dashboard/server.js`,
`tests/dashboard-server.test.js`, `README.md`

This is the step that makes Steps 3-4 more than ceremony (R1). **No longer
conditional** — Open Question 1 was resolved on 2026-08-15 in favour of
option (a), close it, with the cost explicitly accepted by the human: an
orchestrating agent can no longer start the dashboard and relay itself a
working invoke-capable URL. Only a human-present session invokes bundles.

**Where the gate lives (R12 — read this before implementing).** The
tty requirement is enforced in `runDashboard` (`bin/cli.js`), **not** inside
`startServer`. `startServer` gains a `readOnly` option on the same options
object Step 3 introduces — `startServer(root, port, { ttyWrite, readOnly })`
— defaulting to `readOnly: false`, so the existing eight `/api/invoke` cases
in `tests/dashboard-invoke.test.js` keep passing byte-unchanged. Putting the
probe inside `startServer` instead would fail the merge gate immediately,
because the whole suite runs without a controlling terminal.

- `runDashboard` probes for a controlling terminal with
  `fs.openSync('/dev/tty', 'w')` — **not** `process.stdout.isTTY`, which
  wrongly locks out a human who redirects stdout (measured; see Context).
- **Terminal present:** the server starts with `readOnly: false`, and
  `runDashboard` writes the URL (and thus the token) to the retained
  `/dev/tty` handle. It reuses Step 3's handle rather than opening a second
  one.
- **No terminal, no flag:** `--dashboard` **refuses to start**, exits
  non-zero, and prints a message on stderr directing the caller to ask the
  human to run it in their own terminal. No server is listened on and no
  token is generated.
- **No terminal, `--dashboard-no-tty`:** the explicit, documented escape
  hatch for CI/container use. Starts with `readOnly: true`: `GET /`,
  `/api/bundles`, `/api/decisions`, `/api/status`, `/api/context` and
  `/api/source` are served (these six are the complete current GET surface,
  enumerated from `server.js`); `POST /api/invoke` and both Step 3 decision
  endpoints return 403 with
  `{"error":"dashboard is running in read-only mode"}`. The URL goes to
  stdout in this mode, which is correct — a read-only token grants nothing
  worth withholding.
- **Remove `console.log` from `startServer`** (currently `server.js:239`,
  the sole `console.log` in the file). It is what leaks the token to stdout
  today, and no test reads it: all nine dashboard suites take the token from
  `startServer`'s returned `{ server, token }`. Deleting it is therefore
  zero-blast-radius and is the actual fix — relocating the print into
  `runDashboard` without deleting this line would leave the hole open.
- `--dashboard-no-tty` is a modifier used **alongside** `--dashboard`
  (`bin/cli.js:2115` dispatches on an exact `args.includes('--dashboard')`).
  Passing `--dashboard-no-tty` alone is not a supported invocation and need
  not be special-cased.

**Acceptance criteria**

1. A test asserts that with `readOnly: true`, `POST /api/invoke` returns 403
   and the child process is never spawned (assert on an observable side
   effect of the bundle, e.g. a file the bundle would have written, not on
   spawn internals).
2. A test asserts that with `readOnly: true`, both Step 3 decision endpoints
   return 403.
3. A test asserts that with the default options (`readOnly` absent),
   `POST /api/invoke` still executes the bundle — i.e. the existing
   `tests/dashboard-invoke.test.js` passes with **no edits to its assertion
   bodies**, verified by `git diff` showing no change inside them. This is
   the load-bearing regression criterion of this step (R12).
4. `git grep -c "console.log" bin/microworld-dashboard/server.js` returns 0
   (currently 1, at line 239, printing the token).
5. A test asserts that when `runDashboard`'s tty probe fails, it exits
   non-zero, calls `startServer` **zero** times, and emits no string matching
   `?t=` on stdout or stderr. Drive this by injecting the probe (an options
   argument or an exported seam), not by manipulating the real terminal — the
   injected form is the portable one and is what gates the merge.
6. End-to-end confirmation of criterion 5 on this platform:
   `setsid -w node bin/cli.js --dashboard > out.txt 2>&1; echo $?` exits
   non-zero and `out.txt` contains no `?t=` substring. Use `setsid -w`
   (verified present: util-linux 2.39.3; verified to strip the controlling
   terminal and to propagate the child's exit code). Do **not** use
   `< /dev/null` for this — redirecting stdin does not detach the
   controlling terminal, so that form passes for an agent and fails for a
   human, which is not a test.
7. `git grep -l "dashboard-no-tty" -- bin/cli.js README.md | wc -l` returns
   `2` (currently 0 — the flag appears in neither file today). Phrased with
   `-l`/`wc -l` rather than `git grep -c` because `-c` over two pathspecs
   emits one prefixed count per matching file, which has no total to compare
   against.
8. `bash tests/validate.sh` prints `All checks passed.`

## Step 6 — Protocol amendment and its ports (one unit, never two)

**Affected files:** `templates/persona-protocol.md`,
`templates/persona-protocol-slim.md` (only if the parity test requires),
`adapters/cursor/rules/persona-protocol.mdc`, `.claude-plugin/plugin.json`,
`CHANGELOG.md`, `.claude/persona-protocol.md` (regenerated, not hand-edited)

- Amend the "The decision travels as a file, never as a chat message"
  paragraph (`templates/persona-protocol.md:450-457`). The sentence "The human
  writes `.claude/human-review/<task-id>/DECISION` **in their own terminal**"
  gains the second sanctioned path: the human may instead confirm the write in
  the Microworld dashboard, which requires a confirmation code delivered to
  the terminal running the dashboard. The surrounding constraints are
  **restated, not weakened**: no agent identity may write the file; the
  orchestrator still never writes it and never offers to.
- Document the `via:` body line and its three states (absent / `terminal` /
  `dashboard`), and extend the approve row's `human:` attestation line so the
  reviewer transcribes ` via: <value>` when the DECISION file carries one.
  Per the existing marker-format safety argument, this rides on the
  **appended** attestation line, never the required first line, so
  `task-gate.sh`'s `marker_valid()` is unaffected.
- Port to `adapters/cursor/rules/persona-protocol.mdc` in the **same commit**
  (the parity test gates this; a source edit must never be sliced apart from
  its shipped copy).
- Bump `.claude-plugin/plugin.json` and add a CHANGELOG entry (constitution
  P3).
- Regenerate `.claude/persona-protocol.md` with `node bin/cli.js --update`,
  never by hand (constitution P2).

**Acceptance criteria**

1. `node tests/adapter-protocol-parity.test.js` exits 0.
2. `bash tests/human-decision-gate.test.sh` exits 0 — the gate's own suite
   must be unaffected, since this plan changes no gate behaviour.
3. `git grep -c "in their own terminal" templates/persona-protocol.md` is ≥ 1
   and the surrounding paragraph also matches `git grep -c "confirmation
   code" templates/persona-protocol.md` ≥ 1.
4. `git diff --name-only` for this unit includes both
   `templates/persona-protocol.md` and
   `adapters/cursor/rules/persona-protocol.mdc`.
5. `.claude-plugin/plugin.json`'s `version` differs from its value at this
   plan's base commit, and `CHANGELOG.md` contains an entry naming that
   version.
6. `bash tests/validate.sh` prints `All checks passed.`

## Step 7 — Glossary and user documentation (`scribe`)

**Affected files:** `CONTEXT.md`, `README.md`

- Amend **Microworld dashboard** (`CONTEXT.md:960-984`): "Writes nothing to
  disk" is no longer true. Replace with the precise new statement — it writes
  exactly one file, the DECISION file, only on an explicit human confirmation
  carrying a code delivered over the controlling terminal, and only when
  launched with one.
- Amend **DECISION file** (`CONTEXT.md:1115`) to name the second sanctioned
  authoring path and to keep the "unwritable by any agent identity" property
  stated accurately.
- Mint the two new terms identified by the lens-3 check: the per-decision
  **confirmation code** and **dashboard-originated decision write**.
- Record the launch-mode change the OQ1 resolution introduces (added on
  finalization; a third lens-3 term). `CONTEXT.md:963` currently says only
  "nothing auto-starts it" — after Step 5 the dashboard additionally *cannot*
  be started without a controlling terminal except in **read-only mode**
  (`--dashboard-no-tty`), in which bundle invocation and decision writes are
  both refused. Name the two modes and say plainly why: the launch token is
  an execution credential, not a read credential.
- `README.md`'s "Microworld dashboard" section (`README.md:260`): document the
  Run flow, the terminal-code requirement, `--dashboard-no-tty`, and — plainly
  — the residual risks from R5, including that an agent sharing the human's
  terminal multiplexer can read the confirmation code, and that the DECISION
  protection is claude-adapter-only.

**Acceptance criteria**

1. `git grep -c "Writes nothing to disk" CONTEXT.md` returns 0 (currently 1).
2. `git grep -c "confirmation code" CONTEXT.md` is ≥ 1 and
   `git grep -c "dashboard-originated" CONTEXT.md` is ≥ 1 (both currently 0).
3. `git grep -c "dashboard-no-tty" README.md` is ≥ 1, and
   `git grep -c "read-only mode" CONTEXT.md` is ≥ 1 (currently 0).
4. `README.md`'s dashboard section contains a residual-risk subsection naming
   the terminal-multiplexer case — asserted by
   `git grep -c "capture-pane\|terminal multiplexer" README.md` ≥ 1.
5. Every `CONTEXT.md` claim added by this step is verifiable against shipped
   code — specifically, the prose must not claim the dashboard refuses writes
   in any case that Step 3/5 does not actually refuse. The reviewer should
   check each added sentence against a test, not against the plan.
6. `bash tests/validate.sh` prints `All checks passed.`

## Open Questions

**None outstanding.** Both questions below were resolved by the human on
2026-08-15, each confirming this plan's own recommended default. They are
retained in full, with the resolution recorded inline, so the reasoning that
produced the answer stays auditable — the convention used by
`docs/plans/2026-07-13-persona-review-hardening.md` and
`docs/plans/2026-07-14-threefold-update.md`.

**OQ1 — RESOLVED (2026-08-15, human decision — option (a), close it;
implemented by Step 5).** The human accepted the stated cost verbatim: an
agent can no longer start the dashboard and relay a working invoke-capable
URL to itself, and only a human-present session can invoke bundles going
forward. Step 5 is consequently unconditional and mandatory; R12 records the
one place its implementation shape had to move (the gate lives in
`runDashboard`, not `startServer`) once the blast radius on
`tests/dashboard-invoke.test.js` was measured. Original question and options,
for the record:

**Close the pre-existing `/api/invoke` code-execution path, or accept
it?** (Gated Step 5; Steps 1-4, 6, 7 could proceed either way.)

This is the highest-stakes decision here, because the answer determines
whether Steps 3-4 are a real boundary or ceremony around an open door (R1).

- **(a) Recommended default — close it.** Adopt Step 5 as written: the URL
  goes to `/dev/tty`, `--dashboard` refuses to start without a controlling
  terminal, and `--dashboard-no-tty` gives a read-only mode. Cost: an
  orchestrating agent can no longer start the dashboard and relay a working
  URL — the human runs one command themselves. `CONTEXT.md:963` already says
  "nothing auto-starts it", so this narrows a capability the design never
  promised.
- **(b) Accept and document.** Leave `/api/invoke` as-is, record the hole in
  `README.md` and `CONTEXT.md`. Cheapest, and honest, but Steps 3-4's
  guarantees then hold only against an attacker who does not know about
  `/api/invoke` — which is not a security property.
- **(c) Sandbox bundle execution.** Correct and much larger; not scoped here.

**OQ2 — RESOLVED (2026-08-15, human decision — accept and document; no code
change, discharged by Step 7's documentation duty).** The human accepted the
residual risk as assessed: the `/dev/tty` mitigation reaches parity with
`human-decision-gate.sh`'s own bar and no further, remains defeatable by
deliberate pty allocation (`script -qec`, re-verified during this pass), by a
shared terminal multiplexer capturing the pane, and by the human pasting the
code into chat — and that this is a real improvement over a bare
unauthenticated-by-humanness HTTP endpoint. Recorded as understood and
accepted, **not** as a gap awaiting further work. Item 2 ships as designed;
`Copy Command` is not dropped. Step 7's README residual-risk subsection is
what discharges the "document" half of this answer, which is why Step 7 is
not optional polish (R8). Original question, for the record:

**Sign-off on residual risk (R4, R5).** With Step 5 applied, this design
does **not** stop: deliberate pty allocation by an agent; an agent reading the
human's terminal through a shared multiplexer; the human pasting the URL or
the code into chat; or same-uid process-memory inspection. My assessment is
that this reaches **parity with `human-decision-gate.sh`'s own bar** and no
further, and that parity is the maximum achievable at same-uid — but the
human asked to make this call informed rather than have it assumed.
Recommended default: **accept**, with the risks documented in `README.md` per
Step 7. If the answer is "not acceptable", the only remaining move is to drop
item 2 and keep `Copy Command`, since no stronger same-uid boundary exists.

## Self-check

- CHK1: Is the attacker model stated explicitly, rather than left implicit in
  the mitigations? — PASS (Context; Clarifications, category 4; R4)
- CHK2: Is every claimed security property backed by a runnable test rather
  than by prose? — PASS (Step 3 criteria 3-11 each name an assertion)
- CHK3: Do Steps 3 and 4 agree on which side composes the DECISION body? —
  PASS (Step 3 composes server-side from structured fields; Step 4 sends only
  fields, never text; stated in both)
- CHK4: Is the behaviour when no controlling terminal exists defined for the
  server, the client, and the CLI? — PASS (Step 3 availability; Step 4
  criterion 5; Step 5)
- CHK5: Does the plan state what happens if the packet directory is absent? —
  FAIL (missing) — revised in place: R7 and Step 3 criterion 7 now specify
  refuse-with-409 and explicitly forbid `mkdir -p`
- CHK6: Is R6 (quiz never graded, never a gate) confirmed by something
  stronger than an assertion that it is unaffected? — FAIL (ambiguous) —
  revised in place: Step 3 criterion 10 now requires a three-token loop test,
  and Step 1 pins the `skipped` default
- CHK7: Is packet survivability — the concern the original request called
  "R10", carried here as **R7** under this plan's own numbering — explicitly
  addressed? — PASS (R7 and Step 3 criteria 7-8). Note the numbering collision
  deliberately: this plan's R10 is dependency order, *not* packet
  survivability.
- CHK8: Is the `/api/invoke` finding reflected in the acceptance criteria, or
  only in prose? — FAIL (missing) — revised in place: Step 5 criteria 1-4 now
  test it directly, and it is raised as Open Question 1
- CHK9: Do the plan's own greps distinguish "already true" from "will become
  true"? — PASS (every grep criterion was run against the current tree and its
  current value recorded inline)
- CHK10: Is the protocol edit sliced together with its ports? — PASS (Step 6,
  R10, and criterion 4 require both files in one diff)
- CHK11: Does any acceptance criterion name the dashboard's rendered output as
  an adjudicator, violating `persona-protocol.md:592`? — PASS (all criteria
  run `node tests/...` or `git grep` against code; R3 records the reading)
- CHK12: Is the residual risk that survives the mitigation named, or is the
  design presented as complete? — PASS (R4, R5, Open Question 2)
- CHK13: Do Step 1 and Step 4 agree about who owns `renderEscalationView`
  ordering? — FAIL (conflicting) — revised in place: R10 now fixes Step 1
  before Step 4
- CHK14: Is the `via:` line's third state (absent) defined, so a hand-typed
  DECISION file is not treated as malformed? — PASS (Step 2, Step 6)

### Finalization pass (2026-08-15, after both Open Questions were answered)

Re-ran the checklist against the newly-unconditional Step 5 rather than
assuming the OQ1 answer could be pasted in as-is. Four of these seven failed,
all within Step 5, and all were revised in place; none needed to become a new
Open Question.

- CHK15: Is every step's behaviour now defined without reference to an
  unresolved question? — PASS (Step 5 is the only step that was gated, and it
  now states a single shape; no other step's text is conditional)
- CHK16: Does Step 5, as finalized, preserve the eight existing
  `POST /api/invoke` cases that `tests/validate.sh` already runs? — FAIL
  (conflicting) — revised in place: the OQ1 answer read naively would gate
  `/api/invoke` inside `startServer`, which every one of those tests calls
  without a controlling terminal. R12 and Step 5's "where the gate lives"
  paragraph move the gate to `runDashboard` with a `readOnly: false` default,
  and criterion 3 now asserts the existing suite passes unedited
- CHK17: Is Step 5's "refuses to start without a terminal" criterion runnable
  with the same result for a human and for an agent? — FAIL (ambiguous) —
  revised in place: the previous `< /dev/null` form tested nothing (measured:
  redirecting stdin leaves the controlling terminal attached, so it passes for
  an agent and fails for a human). Criterion 5 is now an injected-probe test
  and criterion 6 uses `setsid -w`, verified to strip the controlling terminal
  and propagate the exit code
- CHK18: Is the token's actual stdout leak closed by a criterion, or only
  described in prose? — FAIL (missing) — revised in place: the leak is one
  `console.log` at `server.js:239`; criterion 4 now requires the file's
  `console.log` count to reach 0, and Step 5 states why deleting it is
  zero-blast-radius (all nine suites take the token from the return value)
- CHK19: Does a criterion phrased over two pathspecs yield a single number to
  compare against? — FAIL (ambiguous) — revised in place: `git grep -c`
  emits one prefixed count per file, so criterion 7 is now
  `git grep -l ... | wc -l` returning `2`
- CHK20: Is the human's answer to each resolved question recorded in
  Clarifications, and not only in the Open Questions section? — PASS (two
  dated lines added under categories 4 and 7)
- CHK21: Do R1 and Step 7 agree about when the documentation may drop the
  "except via `/api/invoke`" caveat? — PASS (R1 now says only after Step 5
  merges, and binds the two so that deferring Step 5 reopens Step 7's prose)

## Scribe update hint

On merge, `scribe` should: amend the **Microworld dashboard** and **DECISION
file** entries in `CONTEXT.md` (Step 7); mint **confirmation code** and
**dashboard-originated decision write**; and write — not merely "consider" —
an ADR recording the OQ1 decision, now that it is taken. "The dashboard
refuses to launch without a controlling terminal, and `--dashboard-no-tty`
starts it read-only" is an architectural constraint future work will trip
over rather than a detail, and the reasoning behind it (the launch token is
an execution credential, so an agent that reads stdout gains code execution)
is not recoverable from the diff. Derive the ADR number at execution time
from the highest existing `docs/adr/` entry — never reserve one now, since a
sibling spec may land first.

## Handoff

7 units → **standard path**. `task-master` slices via `to-tickets`, assigns
per-unit model tags, and writes the dispatch prompts. Suggested order:
1 → 2 → 3 → 4 → 5 → 6 → 7 — all seven unconditional, nothing gated on an
open question. Step 5 is no longer parenthesised: OQ1 resolved in favour of
closing the hole, so Step 5 is mandatory. Steps 4 and 5 may be run
concurrently after Step 3 if `task-master` wants the parallelism (R10).

Two notes for `task-master`, neither a slicing instruction:

- Steps 3, 5 and 6 are security- and protocol-critical and should not carry a
  cheap model tag on their own merits (R2 — there is no `.fail` history on
  this surface, so the caution is about the work, not about defect history).
- Step 6 must stay **one** unit: `templates/persona-protocol.md` and
  `adapters/cursor/rules/persona-protocol.mdc` are gated together by
  `tests/adapter-protocol-parity.test.js`, so slicing the source edit apart
  from its shipped port would fail the merge gate.
