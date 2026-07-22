---
name: feedback-scribe-write-scope
description: Scribe's write scope is specifically .claude/wiki/, CONTEXT.md, docs/adr/, and its own memory — NOT arbitrary repo-root docs like README.md. "Documentation, not code" is not the right test for routing a unit to scribe; check the persona's actual write-scope restriction.
metadata:
  type: feedback
---

Do not route a unit to `scribe` just because the change is "docs, not code."
`agents/scribe.md` states explicitly (present since the very first commit,
`e21c9ec`, not a recent tightening): "**Never modify source code** — only
`.claude/wiki/`, `CONTEXT.md`, `docs/adr/`, and your memory." README.md is
the repo's actual product documentation — it is not in that list, and scribe
correctly refused a Step 1 unit that asked it to restructure README.md's
Install section (issue #78 slicing, 2026-07-17: units #79/#80/#81, originally
routed scribe → had to be re-routed to `lead-programmer` after scribe
objected on exactly this ground, agents/scribe.md:32).

**Why:** "documentation-only" describes the *kind* of change (no
behavior/logic touched), not *which persona is allowed to write the target
file*. Those are separate axes. `[[cross_plan_version_coordination]]` already
established that write-scope checks matter for version-stamped files;
this is the same discipline applied to a different axis — the *persona's*
declared write boundary, not the file's version-stamp status.

**The CHANGELOG.md puzzle (worth knowing, not fully resolved):** in the same
session's prior slicing (issues #70, #73, #77 — the cli-plugin-coexistence-
guard and marketplace-precedence plans), units that asked scribe to add a
root `CHANGELOG.md` entry were accepted without objection, even though
`CHANGELOG.md` is *also* outside scribe's literal three-item allowlist (its
only changelog duty per its own prose is `.claude/wiki/changelog.md`, a
different file). No agent file or protocol doc carves out an explicit
CHANGELOG.md exception. The likely explanation: `CHANGELOG.md`'s name and
purpose closely mirror scribe's own explicit "record lead-programmer digests
into changelog.md (ISO-dated)" duty, so scribe's own self-check treated it as
close enough not to trigger a refusal — a semantic/naming overlap, not a real
rule. README.md has zero such overlap with wiki/CONTEXT.md/ADRs, so it
triggered a hard refusal instead. **Do not treat the CHANGELOG.md precedent
as a reliable green light** — it may simply be an inconsistency scribe never
caught, not a sanctioned carve-out. Treat both the same way going forward
(see "How to apply").

**How to apply:** before tagging any sliced unit for `scribe`, re-check the
*current* `agents/scribe.md` (or this project's copied
`.claude/agents/scribe.md`) `tools:`/prose write-scope line for the exact
allowed path set, rather than reasoning from "is this code or prose."
- `.claude/wiki/*`, `CONTEXT.md`, `docs/adr/*` → scribe, always fine.
- `README.md`, `CHANGELOG.md`, or any other repo-root/product-facing doc →
  route to `lead-programmer` instead, even though it's pure prose with no
  behavior change — same acceptance-criteria style (grep/line-count checks)
  works fine dispatched to lead-programmer, this is purely a routing choice,
  not a change to the unit's shape or ACs.
- If genuinely unsure whether a target path is in scribe's allowlist, don't
  guess — grep the persona's own file for its stated write scope before
  writing the dispatch prompt, the same way `[[cross_plan_version_coordination]]`
  says to verify against git state rather than assuming.
