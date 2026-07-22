---
name: reviewed-path-gate-blocks-bash
description: spec-master cannot inspect .claude/reviewed/ via Bash (even read-only ls/cat); the reviewed-path-gate hook blocks it. Use another route to check .fail records.
metadata:
  type: project
---

The persona-protocol tells spec-master to check `.claude/reviewed/<task-id>.fail`
before revising a plan, but the `reviewed-path-gate.sh` PreToolUse hook BLOCKS
any Bash command that touches `.claude/reviewed/` for spec-master — including
read-only `ls`/`cat`/`grep`. The Read tool can't list a directory either.

**Why:** only the reviewer writes/reads that path; the gate enforces review
ownership mechanically for everyone but the reviewer.

**How to apply:** to check for a specific `.fail` record, use the Read tool on
the exact file path `.claude/reviewed/<task-id>.fail` (Read on a known file is
not blocked, only Bash and directory-listing are). If you only need to know
whether a unit previously failed, rely on the orchestrator's briefing / the
task context rather than trying to enumerate the directory. See
[[to-spec-slash-only]] for the other spec-master tooling-access quirk.
