---
name: dashboard-decision-surface-spec
description: Settled decisions for the four-touchpoint dashboard decision surface (#349) — which touchpoints need a new durable artifact, and the two places the request was deliberately not taken literally
metadata:
  type: project
---

Spec `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`, PRD-view
issue #349, five units, handed to `task-master`. Human answered both draft
Open Questions on 2026-08-13.

**Settled by the human:** four touchpoints in scope (escalation DECISION file;
milestone pre-audit checkpoint; milestone-auditor findings relay; pending-review
`defer:`/`skip:`), and **compose only, never write** — the dashboard renders the
ready-to-run command, a human runs it. The human-decision gate's trust anchor is
untouched.

**Settled by my own analysis (the architectural question):** the split falls out
of whether a decision is expensive to *read* or to *answer*.

| Touchpoint | Durable artifact today | Resolution |
|---|---|---|
| Escalation DECISION | yes | read + compose command |
| Milestone pre-audit checkpoint | inputs only | **read surface only**; answer stays in `AskUserQuestion` |
| Auditor findings relay | **no** | ONE new artifact (`.claude/milestone-audit/<plan-slug>/FINDINGS.md`, written by the auditor via Bash as a named bookkeeping exception) + paste-back block |
| Pending-review defer/skip | yes (`.claude/.pending-review.*`) | read + compose both commands |

Net new architecture: exactly one durable artifact.

**Why:** the orchestrator is the *main session*, so its turn-end already returns
control to the human — "async" costs no new blocking-wait or resume machinery.
That is what makes touchpoint 3 affordable. Touchpoint 2 still isn't worth it: a
quick gate deciding whether to spend one expensive audit dispatch would cost more
coordination than the thing it guards, and would make a gate depend on a browser.

**How to apply:** the two deliberate non-literal readings are recorded as R6
(touchpoint 2's answer stays synchronous) and R7 (touchpoint 3 composes a
message, not a command) rather than as Open Questions — both are stated plainly
and cheap to overrule additively. If the human pushes back, neither requires
redesigning anything else.

Facts worth not re-deriving:
- The dashboard has **zero** write calls across all 7 modules (re-measured
  2026-08-13). `GET /api/source` already reads any project-relative path
  including under `.claude/`, so only *enumeration* was ever missing.
- The seam is `feedback-block.js`'s shape: a dual-environment CommonJS module
  injected into `index.html` via a `__..._SOURCE__` placeholder. Client tests
  execute the inline script under `vm` against a stub DOM (prove rendered
  output, not source-text presence).
- An escalation packet usually has **no `manifest.json`** (the reviewer writes
  `PACKET.md` alone when a unit has no bundle), so `discoverPackets` marks it
  disabled. A decision surface must not route through bundle discovery.
- A pending-review flag is keyed by agent-id and its auto-created form carries
  no unit id; join to the newest `.claude/.review-join.<task-id>` stamp with no
  later `.pass`. Emit null rather than guess.
- See [[project_d8_decoupling_criterion_vacuous]] for the vacuous criterion
  found while scoping this.
- **Correction (2026-08-14):** the join-to-newest wording above was shipped
  (gh350, Step 1) literally — "newest" runs unconditionally, even with >1
  live stamp (invariant broken), and one computed value gets applied to
  every pending-review entry. Live in this repo the day it shipped: two
  concurrent reviews left two stamps standing, and both pending-review flags
  were mislabeled with the same (wrong for one of them) unit. R8 claimed
  "emit null rather than guess" was "already specified" for this case; it
  wasn't — only the zero-stamp case was. See
  [[feedback_review_join_null_only_covered_zero_stamp]] for the lesson and
  the fix spec.
