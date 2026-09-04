# ADR 0030: Decision surface's composer writes nothing; the findings-record write duty stays with the Write-less auditor

Date: 2026-09-04
Status: Accepted (plan `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`, Step 5)

> Corrected 2026-09-04 (unit gh354 FAIL fix). The first draft of this ADR
> asserted that the dashboard "composes; it never writes — for any of the
> four touchpoints, no exception" and carried a zero-write regression
> criterion. Both were false when written: the source plan's compose-only
> premise was drafted 2026-08-13 and overtaken by gh380 on 2026-08-15, which
> shipped the two decision-write endpoints. The file name keeps its original
> slug; the claim below is the corrected one.

## Context

The Microworld dashboard gained a Decisions section covering four
human-facing decision touchpoints of this persona system: the
`ESCALATE-TO-HUMAN` DECISION file, the milestone pre-audit checkpoint, the
milestone-auditor findings relay, and the pending-review `defer:`/`skip:`
flag. Three of the four touchpoints already have a durable, gate-relevant
artifact (the DECISION file, the plan doc, the pending-review flag);
touchpoint 3 — the milestone-auditor's findings, previously reported only
into conversation scrollback — did not, which meant a spec-master
convergence follow-up had no citable record of what an auditor actually
found.

Two design questions had to be settled together, because getting either one
wrong would have reopened the laundering path the DECISION file's
`human-decision-gate.sh` closes: whether the dashboard should ever write to
disk on the human's behalf, and, if a new artifact is needed, who writes it.

## Decision

**The decision surface's own composer writes nothing; it does not add a
second write path beside the one the dashboard already has.**
`bin/microworld-dashboard/decision-block.js` is a pure formatter: it returns
command or message text and never calls
`fs.writeFile`/`appendFile`/`mkdir` and never issues a non-`GET` HTTP
request. That property belongs to the composer module, and this decision
deliberately does not generalize it to the dashboard as a whole, because the
dashboard as a whole is not compose-only.

Three of the four touchpoints (the milestone pre-audit checkpoint, the
milestone-auditor findings relay, and the pending-review `defer:`/`skip:`
flag) are compose-only end to end. The fourth — `ESCALATE-TO-HUMAN`
resolution — already had a write path when this surface was designed:
`POST /api/decision/arm` (`server.js:262`) and `POST /api/decision/run`
(`server.js:418`), added by gh380 (commit `19a0cd0`, 2026-08-15), write the
packet's DECISION file (`server.js:507`, `flag: 'wx'`, mode `0o600`) and
append a `decision-write-via-dashboard` line to `.claude/review-audit.log`
(`server.js:533`).

So the DECISION file's trust anchor is *not* the absence of an endpoint to
POST to. There are two distinct paths to that file, each with its own guard.
`human-decision-gate.sh` still blocks every agent identity — reviewer and
empty/main-session included, with no grant branch and no fallback — from
writing the file through a `Bash`/`Write`/`Edit` tool call. The dashboard
server is not an agent identity and is not a tool call, so it is not covered
by that hook; its guard is the terminal-delivered confirmation code instead.
`/api/decision/arm` generates the code and writes it to `/dev/tty` *before*
recording the arm (so a code the human never received cannot report
`armed: true`), and `/api/decision/run` compares the submitted code with
`crypto.timingSafeEqual` (`server.js:~480-500`) under a single-use,
120-second arm. Two further conditions narrow that path: read-only mode
refuses both endpoints outright, and the arm fails closed when there is no
controlling terminal. The human-presence proof, not an absent write path, is
what makes "a human resolved this" hold on the dashboard route. The residual
risks that follow from a real write path (pty allocation, tmux pane capture,
process-memory inspection) are documented in `README.md` and are not erased
by this decision.

**The one new durable artifact this surface introduces — the milestone
findings record at `.claude/milestone-audit/<plan-slug>/FINDINGS.md` — is
written by `milestone-auditor` itself, via `Bash`, not by the dashboard and
not by the orchestrator transcribing on the auditor's behalf.**
`milestone-auditor` has no `Write`/`Edit` tool by design (it audits the plan,
it does not change it) and does not gain one for this. Writing its own
findings via `Bash` is a **named bookkeeping exception**, the identical
carve-out the reviewer already holds for `.pass`/`.fail`/`.escalated`
markers: a record *about* the work, produced by the one party that actually
holds the judgment, is not the same category of action as a change *to* the
work that a Write-capable tool would make. The write duty staying with a
`Write`-less persona — rather than the dashboard rendering it, or the
orchestrator relaying it — is itself the point worth recording: it is the
mechanism that keeps "the auditor's findings" and "what got written down"
from ever diverging through an intermediary.

**Touchpoint 2 (the milestone pre-audit checkpoint) is not converted to an
async, dashboard-answered flow.** Its answer stays in the orchestrator's
existing synchronous `AskUserQuestion` call. The dashboard gains only a
read-only briefing (the plan doc's Goal, assumptions, Open Questions, and
the milestone's unit pass/fail history) that the orchestrator may
optionally point at.

## Alternatives rejected

**Orchestrator transcribes the auditor's findings into the record.**
Rejected for the same reason the reviewer transcribes a DECISION file
verbatim rather than paraphrasing it: an intermediary that re-states a
judgment can quietly alter it, and the auditor is the only party that
actually holds the findings. Routing the write through anyone but the
auditor reopens exactly the kind of drift the record exists to prevent.

**Converting touchpoint 2's answer to an async, dashboard-composed
response.** Rejected on two counts. First, the pre-audit checkpoint is a
quick yes/no gate over a long premise list — the decision is cheap to
*answer* and expensive only to *read*; converting the answer would add an
artifact, a wait, and a resume mechanism to save one Opus dispatch, so the
gate would cost more coordination than the thing it guards. Second, making
the gate's operation depend on the dashboard running would violate the
standing premise that the dashboard is never an acceptance criterion and no
gate may depend on it. Only the *reading* half was worth moving; the
*answering* half stays exactly where it was. This is a deliberate deviation
from the literal request (recorded as R6 in the source plan) rather than an
oversight, and it is cheap to overrule later as an additive follow-up if the
human wants the answer routed too.

## Consequences

The findings record is meant to join the sibling operational markers
(escalation packets, pending-review flags) as ignored working state, and to
be deleted by the orchestrator once the human's decision has been acted on; a
stale record is a defect for the same reason a stale escalation packet is one
— nothing else globs that directory, so a human could otherwise mistake an
old findings list for a live one. **Both halves of that are currently
unenforced**: as of 2026-09-04 `.claude/milestone-audit/` has no `.gitignore`
entry (`git check-ignore .claude/milestone-audit/x/FINDINGS.md` does not
match), and no hook, test, or gate checks that the directory is cleaned up.
Adding the ignore line and an enforcement check are open follow-ups, not
things this decision already delivered.

No "zero writes" or "zero non-`GET` endpoints" regression criterion is
asserted for `bin/microworld-dashboard/`, because such a criterion would be
red the moment it was written: the directory has three real writes
(`server.js:384` tty, `:507` DECISION, `:533` audit log) and three non-`GET`
endpoints (`POST /api/invoke` at `server.js:184`, plus the two decision
endpoints above). A criterion that fails at authoring time cannot make a
future regression loud — it is already indistinguishable from one.

The property actually worth guarding is narrower and is true today: the
composer module `decision-block.js` performs no write and issues no non-`GET`
request, and the *only* path that writes a DECISION file passes through the
confirmation-code check in `/api/decision/run`. A future change is a
regression if it lets a DECISION file be written without that check — not if
it merely adds a write somewhere under `bin/microworld-dashboard/`.

## Related decisions

- `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md` —
  the dashboard's original never-a-gate, human-facing-only premise that this
  decision surface preserves rather than narrows.
- `docs/adr/0015-commit-anchored-pass-markers.md` and
  `docs/adr/0016-per-unit-review-join.md` — the standing precedent for
  Write-less personas or restricted tools producing their own bookkeeping
  artifacts through a named exception rather than through an intermediary.
