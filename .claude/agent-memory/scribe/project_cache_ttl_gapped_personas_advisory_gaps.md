---
name: cache-ttl-gapped-personas-advisory-gaps
description: Three advisory gaps from unit cache-ttl-gapped-personas (PASS 2026-09-23) for future maintenance
metadata:
  type: project
---

## Unit cache-ttl-gapped-personas advisory gaps

**PASS 2026-09-23** — unit raised compatibility floor from `2.1.178` to `2.1.248` (for `experimental.cacheTtl` support in agents/reviewer.md and agents/task-master.md). Reviewer identified three non-blocking follow-up gaps, documented for maintenance but NOT fixed as part of this unit (out of scribe scope):

**Gap 1: Stale floor prose in setup files**
- **Files**: `commands/start-feature-team.md:72` and `templates/settings-fragment.json:2`'s `_comment`
- **Status**: Cite old `2.1.178` floor in prose, now stale relative to raised `2.1.248` floor
- **Why**: Setup guidance refers to outdated minimum version
- **How to apply**: When next updating setup prose, audit these two prose cites and correct to `2.1.248`

**Gap 2: Adapt-time compatibility check lag**
- **File**: `skills/install-antislop/SKILL.md:27` (and its `.claude/skills/` mirror)
- **Status**: Still requires only `v2.1.178+`, creating a version gap where users on Claude Code 2.1.178–2.1.247 pass setup but silently get dropped `experimental.cacheTtl` field
- **Why**: Functional defect — setup succeeds but feature silently misses, not just stale documentation
- **How to apply**: Update adapt-time check to require `>=2.1.248` to prevent silent feature loss in gap range

**Gap 3: Validate.sh nesting-check fragility**
- **File**: `tests/validate.sh`'s new nesting-check for `experimental.cacheTtl` placement
- **Status**: Greps whole file rather than isolating YAML frontmatter block first; currently not vacuous but fragile
- **Why**: Stray prose mention of `cacheTtl` outside frontmatter could accidentally satisfy criterion
- **How to apply**: Refactor check to scan only the YAML frontmatter block (lines before first non-`---` content) to harden against prose false positives

**Related**: [[cache-ttl-gapped-personas PASS entry]] in completed units; glossary entry "compatibility floor" added to CONTEXT.md under this unit.
