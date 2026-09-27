# ADR 0037: Exclude agent-memory writes from the v3 PASS-marker clean-tree precondition

Date: 2026-09-27

Status: Accepted (amends [ADR-0015](0015-commit-anchored-pass-markers.md)'s
rationale's reach; does not change its mechanism)

## Context

The v3 PASS-marker format's On-PASS check requires `git diff --quiet HEAD` to
exit 0 before the reviewer writes a marker — no tracked file may carry an
uncommitted change. That whole-tree form was chosen deliberately, and its
own originating plan states why, verbatim
(`docs/plans/2026-08-07-commit-anchored-pass-markers.md:363-367`):

> `git diff --quiet HEAD` must exit 0 — no tracked file carries an
> uncommitted change. Deliberately *not* `git status --porcelain`: untracked
> scratch files and the gitignored marker write must not trip it. Safe as a
> whole-tree check because the protocol guarantees only one unit is ever
> mid-review (`templates/persona-protocol.md:158-163`).

**Why the unit-exclusivity invariant does not cover memory-scope writes.**
The rationale above rests entirely on that one invariant — the protocol
guarantees only one unit is ever mid-review at a time, so a whole-tree check
cannot see a *second* unit's stray edits bleeding into the one under review.
That invariant is about concurrent **review units**. It says nothing about a
persona's own memory bookkeeping, because a memory-scope write:

1. is never part of any unit's reviewed deliverable — no acceptance
   criterion for a normal unit names a path under `.claude/agent-memory/`;
2. is produced by personas that are not under review at all
   (`spec-master`, `task-master`, `scribe` — none of them writes code a
   reviewer verdicts); and
3. survives its author's session, outliving the review window entirely —
   it is written once and then sits in the tree indefinitely, unlike the
   transient state the unit-exclusivity invariant was designed to protect
   against.

Excluding `.claude/agent-memory/**` therefore removes a class the stated
rationale never contemplated. It weakens nothing the whole-tree check was
protecting, because that check's own justification never claimed to cover
this class in the first place.

Independently, this repo had already diagnosed the same defect once and left
it unactioned: unit #257 — the unit that introduced the v3 format — recorded
a marker-note reaching this identical conclusion ("Plan lines 363-367 chose
whole-tree deliberately ('only one unit is ever mid-review'), but that
reasoning covers concurrent units, not persona agent-memory writes. Suggest
scoping to the unit's affected paths.") roughly seven weeks before this ADR
acted on it.

## Decision

Narrow the reviewer's clean-tree check to exclude
`.claude/agent-memory/**`, conditionally:

```
git diff --quiet HEAD -- ':/' ':(exclude,top).claude/agent-memory'
```

**Conditional exception.** If the unit's own `## Affected files` set names a
path under `.claude/agent-memory/`, the exclusion does not apply — the
reviewer runs the unexcluded whole-tree `git diff --quiet HEAD` instead,
because in that case the memory file genuinely is the reviewed deliverable
and must not be allowed to slip past the check that exists to catch exactly
that kind of uncommitted state.

Alongside the narrowing, every memory-granted persona's protocol now states
a companion discipline rule: commit your own memory-scope writes before
ending your turn, in their own commit, staged by explicit path. The
narrowing alone would open an interval in which memory dirt no longer blocks
review but nothing requires memory to actually reach tracked history; the
discipline rule alone is unenforced prose that one missed turn silently
defeats. The two ship together for that reason.

### Options considered and rejected

**Gitignoring `.claude/agent-memory/` entirely — rejected.** The deciding
ground is that the harness injects a standing instruction into every
memory-granted persona's context asserting memory is "project-scope and
shared with your team via version control" — a instruction this project
cannot edit. Gitignoring the directory would make that harness-owned
sentence false for every future memory write, for no gain the narrower fix
does not already achieve. Three further grounds independently rule it out:
it would discard 218 tracked files and 210 commits of institutional
knowledge from every future clone with no recovery route; `.claude/agent-memory/`
is absent from `bin/cli.js`'s `OPERATIONAL_GITIGNORE_PATTERNS`, so adding it
is a cross-repo policy change for every consumer project's next `--update`,
not a local fix; and it fixes only one instance of a general class —
`docs/plans/**`, `CONTEXT.md` and `docs/harness-glossary.md` produce
identical blocking dirt and would still need Option 2's discipline rule
regardless.

**The reviewer auto-committing stray memory dirt on a unit's behalf —
rejected, decisively.** This would have the reviewer author a commit of
content it did not review, on behalf of another agent that may still be
mid-write. Two independent grounds rule it out. First, it breaches
[ADR-0002](0002-reviewed-dir-owned-by-reviewer.md), which scopes the
reviewer's write custody to `.claude/reviewed/` — committing arbitrary tree
state on another persona's behalf is outside that custody boundary.
Second, this repo has already measured the exact race such an auto-commit
would recreate: a shared-worktree stash race, where sweeping or stashing
another session's in-flight file corrupts or loses that session's own
uncommitted work. The discipline this repo already follows for that
measured race — never improvise, never stash someone else's state, write
the WIP sentinel and report the blocker up the chain — forbids the reviewer
doing silently, as a side effect of writing a marker, the exact thing that
discipline exists to prevent.

## Consequences

- A stray, uncommitted `.claude/agent-memory/**` file left by one persona's
  session can no longer block an unrelated, otherwise-correct unit's PASS.
- A unit whose own deliverable is genuinely a file under
  `.claude/agent-memory/` is unaffected — the exception restores the
  unexcluded whole-tree check for that case.
- Every memory-granted persona now carries an explicit, protocol-level
  obligation to commit its own memory-scope writes before its turn ends,
  rather than exporting that cost to whoever reviews next. Leaving them
  uncommitted is now named **ambient dirt** in the harness glossary — see
  `docs/harness-glossary.md`.
- `docs/plans/**`, `CONTEXT.md` and `docs/harness-glossary.md` are
  deliberately **not** excluded by this decision — for a documentation
  unit, those files *are* the reviewed deliverable, and excluding them
  would materially weaken the precondition rather than merely narrow it.
  They remain governed by the discipline rule alone.
- This decision is hard to reverse casually: a future reader re-tightening
  the check back to unconditional whole-tree would reintroduce the exact
  false-positive-FAIL class this ADR closes, unless they first re-derive
  this same reasoning.

## Related

- [ADR-0015](0015-commit-anchored-pass-markers.md) — introduced the v3
  marker format and the whole-tree clean-tree check this ADR narrows the
  reach of. This ADR amends ADR-0015's rationale's reach, not its
  commit-anchoring mechanism, which is unchanged.
- [ADR-0002](0002-reviewed-dir-owned-by-reviewer.md) — scopes the
  reviewer's write custody to `.claude/reviewed/`, the ground on which the
  reviewer-auto-commit option was rejected.
- `docs/plans/2026-08-07-commit-anchored-pass-markers.md:363-367` — source
  of the whole-tree rationale quoted verbatim above.
- `docs/plans/2026-09-27-agent-memory-dirt-blocks-pass.md` — the finalized
  spec this ADR records the decision from (Step 3).
