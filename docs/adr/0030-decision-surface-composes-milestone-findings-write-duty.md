# ADR 0030: Decision surface composes only; the findings-record write duty stays with the Write-less auditor

Date: 2026-09-04
Status: Accepted (plan `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`, Step 5)

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

**The dashboard composes; it never writes — for any of the four
touchpoints, no exception.** `bin/microworld-dashboard/decision-block.js` is
a pure formatter: it returns command or message text and never calls
`fs.writeFile`/`appendFile`/`mkdir` and never issues a non-`GET` HTTP
request. This keeps the DECISION file's trust anchor mechanical:
`human-decision-gate.sh` infers "a human, not an agent, produced this file"
from the fact that no code path under agent control can produce it. A
compose-only dashboard adds no endpoint that accepts a decision, so there is
nothing for an agent with `Bash` to POST to, and the inference stands
verbatim.

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

The findings record is gitignored, joins the sibling operational markers
(escalation packets, pending-review flags), and is deleted by the
orchestrator once the human's decision has been acted on; a stale record is
a defect for the same reason a stale escalation packet is one — nothing else
globs that directory, so a human could otherwise mistake an old findings
list for a live one.

The dashboard's zero-write, zero-non-GET properties for all four touchpoints
are carried forward as standing regression criteria (`grep -rn
"writeFileSync\|writeFile\|appendFile\|createWriteStream\|mkdirSync\|rmSync\|unlinkSync\|mkdir"
bin/microworld-dashboard/` stays 0-hit), so a later well-meaning change that
adds a decision-accepting endpoint will be a loud, visible regression rather
than a silent one.

## Related decisions

- `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md` —
  the dashboard's original never-a-gate, human-facing-only premise that this
  decision surface preserves rather than narrows.
- `docs/adr/0015-commit-anchored-pass-markers.md` and
  `docs/adr/0016-per-unit-review-join.md` — the standing precedent for
  Write-less personas or restricted tools producing their own bookkeeping
  artifacts through a named exception rather than through an intermediary.
