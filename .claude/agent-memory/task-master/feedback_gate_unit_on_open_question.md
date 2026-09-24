---
name: gate-unit-on-open-question
description: How to slice and label a unit whose dispatch is gated on an unanswered spec Open Question (not a spec gap, not ready yet either)
metadata:
  type: feedback
---

When a spec ships with an explicit unresolved Open Question that gates one
step (spec-master already flagged it, orchestrator is relaying it to the
human in parallel with dispatch), slice and file that unit's ticket as
normal but:

- Do **not** apply the `ready-for-agent` label — it isn't grabbable yet.
  (This repo has no `blocked` label; a `[BLOCKED — pending <question>]`
  title prefix plus a banner at the very top of the issue body is the
  working substitute — confirmed against [[github-label-length-cap]]-style
  conventions on gh326-gh339.)
- Put a clearly-marked "DO NOT DISPATCH YET" banner as the *first* thing in
  the issue body, above the normal `Unit —` line, stating exactly what
  confirmation is needed before this ticket is dispatchable.
- Write the ticket's body against the spec's own *recommended default* for
  the open question (spec-master will have stated one), but say explicitly
  that this is what happens only if that branch is chosen — and name what
  happens if the other branch is chosen instead (usually: spec-master must
  revise the plan/add a Convergence-follow-up before task-master re-derives
  Ordered edits / Acceptance criteria for that branch; task-master never
  guesses which branch to slice for the unwritten branch).
- Still write the full nine-element dispatch contract underneath the
  banner — the ticket must be ready to fire the instant the gate clears,
  not something that needs re-writing after the fact.

**Why:** distinguishes this from a genuine spec gap (which routes back to
spec-master because the spec itself is broken) — here the spec is complete
and self-aware about the fork, it's just waiting on a human decision that's
already in flight. Filing it un-labeled-but-fully-specified means zero
re-work once the answer lands, instead of blocking the whole batch on
re-slicing after the fact.

**How to apply:** any spec with a stated "Open Question, gates Step N" whose
resolution is already being sought via a parallel channel (human relay,
async decision, etc.) at task-master dispatch time.

## Un-gating (the other half — confirmed 2026-09-23, gh473)

When spec-master comes back with the gap/question resolved *in the spec
itself*, the follow-up is an **in-place issue edit, never a re-slice** —
unit boundaries, blocking edges and unit ids all stay put. Do all four,
and say in the report that you did:

1. Delete the banner **and** the `## Spec gap` section outright; don't
   leave them as history. Replace them with a dated `## Amended <date>`
   section listing what changed, so a reader who saw the old body can
   diff it mentally.
2. Strip `[BLOCKED: …]` from the title, and re-title if the old title
   named the thing that was wrong (here: "no-stale-absolute sweep" was
   the over-claim being fixed).
3. **Add `ready-for-agent`** — the tracker's native blocking edges
   already hold it behind its dependencies, so the label is about
   spec-readiness, not ordering. Leaving it off after the gap closes
   silently blocks the unit for no recorded reason.
4. Re-run every baseline the amended spec quotes (`git grep -l` /
   `git grep -c`) **live** before restating it, and mark it as expiring
   — see [[recheck-baseline-counts-live]].

Say explicitly in the report whether the banner stays or goes. "Silently
leaving it in either state" is the failure mode the caller called out.
