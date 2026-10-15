---
name: ptr-u4a-sc follow-ups
description: ptr-u4a (U4a memory-index split) reviewer follow-ups: index link check gap, orphaned task-master topic files, cosmetic defects, parallel-review scratchpad hazard
metadata:
  type: project
---

ptr-u4a-sc PASS (marker 2026-10-15, commit 10e3ade); issue #548 closed; glossary commit 32748ba added "memory techniques" and "memory archive" and amended "agent-memory index" in CONTEXT.md. The reviewer's non-blocking follow-ups for the whole U4a split:

- (a) No test checks that every topic file is linked from MEMORY.md, ARCHIVE.md or TECHNIQUES.md, so most topic files are reachable only via ARCHIVE.md. A candidate validate.sh check could resolve every index link to an existing topic file. tests/doc-relative-links.test.js excludes .claude/agent-memory.
- (b) Scribe's MEMORY.md has five harmless leading blank lines (cosmetic; a later prune may collapse them).
- (c) One lead-programmer hook is cut inside an inline code span, leaving an unclosed backtick (cosmetic).
- (d) Task-master has two topic files indexed nowhere: feedback_acceptance_criterion_assumes_missing_cli_flag.md and feedback_ratified_but_unlanded_default_claim.md.
- (e) The full serial tests/validate.sh did not finish inside any reviewer's 600 s limit under concurrent load.
- (f) Parallel reviewers share one scratchpad directory; one overwrote another's fixed-name temp file mid-review.

**Why:** reviewer findings from the U4a PASS; none block the split, but (a) and (d) mean the index split can silently orphan files.

**How to apply:** before the next index reorganisation, check the reachability in (a) and (d) by hand; for parallel reviews, use `mktemp -d` per reviewer. Sibling U4a issues (#549, #550, #544) close in later scribe dispatches; this note does not close them.
