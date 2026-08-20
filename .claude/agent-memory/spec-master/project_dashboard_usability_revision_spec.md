---
name: dashboard-usability-revision-spec
description: Settled decisions, premise corrections, and fast-path slicing for the 2026-08-18 microworld dashboard usability spec (rail IA, markdown rendering, USER_NAME) — issue #406
metadata:
  type: project
---

Spec doc: `docs/plans/2026-08-18-dashboard-usability-revision.md`. Published
as `[spec]` issue **#406** (`ready-for-agent`). 5 units → fast path, dispatch
contracts inline in the doc, **no `task-master`**, no per-step issues; units
retrieve from the doc path, not a tracker issue.

**Why:** operator gave three verbatim requirements; a Fable usability critic
produced the design baseline. My job was finalization, not re-critique.

**How to apply:** if re-invoked on this surface, these are settled — do not
re-litigate:

- Rail IA: `Review (N)` / `Plans & Specs (N)` / `Microworlds (N)`, that
  order, non-empty-only, all three counted. `&` written bare. Row prefixes
  only inside Review (`Escalation:`/`Packet:`/`Findings:`/`Pending review:`).
  "Decisions" removed as a *label* only — `data-decision-*`, `decision-item`,
  `decisionCopyBtn` all stay.
- Auto-select: escalations promoted above working bundles; nothing else
  re-ranked.
- Six document panes get markdown; six verbatim panes must not
  (`renderPendingReviewView` contributes **two** command panes, not one —
  the critique undercounted).
- Server-side `by = ''` default stays. `USER_NAME` is a form pre-fill only.

**Four premise corrections I had to make against the tree** (the critique had
read the code in full and still got these wrong — re-verify before trusting
any future critique of this surface):

1. `/api/source` **already returns `totalLines`** → truthful truncation
   marker needs no server change. And `MAX_LINES = 400` is a *server-side*
   cap, so raising the client's `endLine` returns no more lines.
2. `index.html`'s `escapeHtml` is **DOM-dependent** (`document.createElement`)
   → a dual-env CommonJS module can never reuse it; it must carry its own
   pure escape. This is the trap that makes "just reuse escapeHtml" plans
   unimplementable.
3. The client **already fetches `/api/context`**, lazily inside
   `doCopyFeedback` — not in `init()`. A new `init()` fetch must be guarded:
   that endpoint 500s in a non-git root, which would blank the whole client.
4. `tests/dashboard-decisions-client.test.js` **hard-asserts** `Working
   Bundles` / `Escalation Packets` / `Decisions` — any rail relabel breaks
   it. Blast radius no critique named.

Related: [[dashboard-decision-surface-spec]], [[sentinel-stub-single-impl-proof]],
[[verify-own-criteria-nonvacuous]], [[docs-units-need-claim-anchored-criteria]].
