---
name: feedback-verify-ordering-against-criteria
description: A finalized spec's own Handoff/ordering summary (e.g. "these two step-groups are internally parallelizable") can understate real dependencies — always re-derive Depends-on lines from each step's actual acceptance-criteria commands, not just the spec's prose ordering claim.
metadata:
  type: feedback
---

Observed 2026-08-09 (agent-auditor-persona slicing, issues #280-287,
docs/plans/2026-08-09-agent-auditor-persona.md): the finalized spec's own
Handoff section stated "Steps 1-3 (script, persona file, test) are
independent of Steps 4-5 (registration, mirrors) and may run in parallel."
Taken at face value this implies zero cross-group dependency. But Step 4's
own acceptance criterion 3 (`node bin/cli.js --yes
--personas=agent-auditor` scaffold-and-verify) can only succeed if
`agents/agent-auditor.md` — Step 2's deliverable, in the supposedly
"independent" other group — already exists on disk for `bin/cli.js` to read
as its persona source. Reading the acceptance criteria literally revealed a
real hard dependency (Step 4 depends on Step 2) that the spec's own
plain-English ordering summary did not surface.

**Why:** a spec author's ordering summary is a holistic judgment call made
before every acceptance-criteria command is scrutinized line by line; it can
be right about the *bulk* of the work (most of Step 4 genuinely doesn't
touch Step 2's file) while still missing one criterion that quietly
threads the two together. Trusting the summary alone would have let an
orchestrator dispatch Step 4 before Step 2 landed, producing an
unreproducible failure at review time.

**How to apply:** treat a spec's Handoff-stated parallelism claim as a
starting hypothesis, not a given — for every step, mechanically walk its
own acceptance-criteria commands (per [[feedback_content_reference_vs_hard_dependency]]'s
"does this literally read/execute the other step's output" test) even when
the spec's own ordering prose already says the steps are independent. Add
the hard `Depends on` line to the dispatch-ready ticket when the check
reveals a real dependency, and do not silently defer to the spec's
higher-level framing over what the runnable commands actually require. This
is not a spec-gap report (the ordering summary being loose is not itself an
error worth escalating back to spec-master) — it is exactly the ordering
diligence task-master is expected to apply when writing `Depends on /
blocked by` lines, per the shared protocol's dispatch-contract element 4.
