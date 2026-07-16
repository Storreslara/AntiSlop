# ADR 0002: `.claude/reviewed/` is owned exclusively by the reviewer persona (or the main session, only when no reviewer is selected)

Date: 2026-07-14
Status: Accepted (already the shipped design; documented here after this
repo's own ADAPT run hit the gate live and had to work around it)

## Context
`install-antislop`'s step 9 instructs ADAPT to run
`mkdir -p .claude/reviewed` unconditionally, so the reviewer's PASS-marker
`printf` succeeds on its very first real run instead of erroring on a
missing directory. But `reviewed-path-gate.sh` (a PreToolUse Bash hook)
blocks any Bash command whose text contains `.claude/reviewed` unless the
caller's `agent_type` is `reviewer` — or, in the documented no-reviewer
fallback, the main session/team lead. When this repo selected `reviewer`
during its own ADAPT, the installing main session tried the literal
`mkdir -p .claude/reviewed` from step 9 and was blocked by its own
just-installed gate.

## Decision
When a project selects the `reviewer` persona, ADAPT does **not**
pre-create `.claude/reviewed/`. The directory is created lazily by the
reviewer's own first real PASS-marker write
(`mkdir -p .claude/reviewed && printf ... > .claude/reviewed/<task-id>.pass`,
per `reviewer.md`'s documented workflow) — that command runs with
`agent_type: reviewer` and passes the gate cleanly. Step 9's "regardless of
whether reviewer was selected" instruction only applies literally when no
reviewer was selected (the gate's own no-reviewer fallback permits the
main session to touch the path directly in that case).

## Consequences
- The gate's enforcement is stricter than the ADAPT skill's literal step 9
  wording for reviewer-enabled projects — this is intentional and correct,
  not a bug to route around.
- A project's very first review still works correctly: the reviewer
  creates the directory itself on demand, per its own documented
  procedure, no pre-seeding needed.
- Future ADAPT runs (or a future revision of `install-antislop`) should
  treat step 9's `.claude/reviewed/` creation as conditional on
  `personaSelection` NOT containing `reviewer`, matching the gate's actual
  fallback logic, rather than "regardless."
