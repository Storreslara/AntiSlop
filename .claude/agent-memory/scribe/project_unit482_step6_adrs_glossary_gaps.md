---
name: unit482-step6-adrs-glossary-gaps
description: Unit cost-governance-step6-adrs-glossary (issue #482) completion — ADR-0032/0033, floor-to-override rename, shared-tree hazard encountered
metadata:
  type: project
---

PASS 2026-09-24 (commit 48483aa). Step 6 of
cost-governance-output-cap-and-effort-tiers (parent #476).

**ADRs added**: 0032 (bash-output-cap-not-command-rewriting) and 0033
(effort-tiers-frontmatter-only-**override**) — renamed from the issue's
literal suggested filename ending `-floor.md`. [[gh480_effortoverride_gaps]]
had already corrected "floor" to "override" in CONTEXT.md (commit 6b76a6b);
minting a brand-new ADR titled "...-floor" would have reintroduced the exact
error a prior unit just fixed. Reasoning: "override" is bidirectional
(reviewer's `high` must never silently drop; explorer's `low` must never
silently rise either) while "floor" only describes the one-sided reviewer
case — a distinction worth checking whenever a dispatch prompt's suggested
filename/title embeds domain terminology that a sibling unit corrected after
the dispatch was written.

**Glossary reconciliation, not duplication**: issue #482 asked for three
CONTEXT.md terms (effort tier, Bash output cap, effort floor). Two already
existed under merged headings from prior units (**bashOutputMaxChars / the
Bash-output cap**, unit #478; **effort override / effort tier**, unit #480).
Did not duplicate — added ADR cross-references to both existing entries
instead, and for the third ("effort floor") added an explicit terminology
note to the existing override entry explaining why floor is superseded
rather than minting a separate, now-wrong glossary heading. When a dispatch's
requested term is itself stale per a just-landed sibling correction, folding
a "why this term is superseded" note into the existing entry is preferable to
either duplicating or silently ignoring the ask.

**Shared uncommitted working tree hazard**: mid-unit, `git status` showed ~24
unrelated modified files (plugin.json, package.json, CHANGELOG.md, all
`.claude/agents/*.md` mirrors, adapter ports, `agents/orchestrator.md`) —
evidently a concurrent Step 5 (cost-governance-step5-effort-policy) dispatch
running in parallel, uncommitted. Confirmed via `git log` these weren't yet a
commit. Resolved by `git add`-ing only my three specific files by exact path
(never `git add -A`/`git add .`) before committing, and diffing each staged
file individually to confirm no unrelated hunks rode along. Worth checking
`git status --short` before any commit in this repo's dispatch model, even
mid-task, since sibling units can be running concurrently against the same
working tree.

**R7 empirical-pin discipline**: the dispatch explicitly asked me to phrase
Step 4's R7 empirical result "exactly as that unit's own report states it,"
not reassert a stronger claim. Found the exact wording in `git log -1
9109f35` and cross-checked it matched the corrected CHANGELOG.md 0.31.79
entry before writing ADR-0033's Consequences section — both said the same
thing (declared/loads confirmed; end-to-end silent inheritance unproven), so
no further reconciliation was needed, but the double-check would have caught
drift if the commit message and CHANGELOG had disagreed.

See also [[project_unit480_effortoverride_gaps]], [[project_unit479_cost_governance_step3_prose_gaps]].
