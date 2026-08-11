---
name: specs-publish-as-per-step-issues
description: Step-level issues under plan/<slug> are filed by task-master; an umbrella "[spec] ..." PRD-view issue is ALSO current again as of #324 (2026-08-11), reversing my earlier never-publish note.
metadata:
  type: project
---

The tracker carries **two** issue shapes, and both are current:

1. **Step-level issues** — `[plan] Step N — <persona>: <objective>`, labelled
   `ready-for-agent` + `plan/<plan-doc-slug>`, filed by `task-master` running
   `to-tickets`. One per independently-grabbable unit. This is what the whole
   dispatch pipeline (retrieval contract, H3, `.pass` markers keyed to unit
   ids) is built on.
2. **An umbrella `[spec] …` issue** — the PRD view of the whole plan, labelled
   `ready-for-agent` (no `plan/` label of its own is required).

**Correction, 2026-08-11:** I previously recorded "never publish an umbrella
to-spec PRD issue here," based on an 2026-08-07 sample of #248–#255 and the
belief that #122/#123 were a superseded 2026-07-28 pattern. That is now wrong.
Issue **#324** (`[spec] Human-decision channel …`, 2026-08-11) is an umbrella
spec issue whose body opens with, verbatim: *"Canonical spec:
`docs/plans/2026-08-11-human-decision-channel.md` (authoritative; this issue is
the PRD view)."* Its steps are #325/#326 under
`plan/2026-08-11-human-decision-channel`. So the umbrella and the step-level
issues coexist by design.

**Why the shape works:** the umbrella issue is explicitly *not* the source of
truth — it names the `docs/plans/` doc as authoritative and calls itself "the
PRD view." That keeps the one-issue-per-grabbable-unit model intact (nobody
dispatches the umbrella) while giving the plan a single citable tracker id.

**How to apply:**
- The `docs/plans/YYYY-MM-DD-<slug>.md` document is still the canonical
  artifact. Write it first — the `plan/<slug>` label is derived from its
  filename.
- For a multi-step plan, publishing an umbrella `[spec]` issue via `to-spec` is
  fine; open its body with the same "Canonical spec: … (this issue is the PRD
  view)" line #324 uses, so nobody mistakes it for the source of truth.
- Still let `task-master` own the step-level slicing — never file the
  `[plan] Step N` issues yourself.
- **Never publish while Open Questions are unresolved.** A published spec is
  read as agreed; hold the publish, return the OQs, publish after answers land.
- On a fast path (≤2 units) no tracker issue is needed at all; the retrieval
  contract points at the `docs/plans/` path. Related:
  [[to-spec-slash-only]].
