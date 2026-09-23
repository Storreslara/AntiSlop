---
name: reviewer-changes-examples-lean-1 completion
description: Institutional knowledge recorded for four-copy protocol section hand-sync pattern in CONTEXT.md
metadata:
  type: project
---

Unit reviewer-changes-examples-lean-1 completion (2026-09-23)

**What happened:** Unit tightened `templates/persona-protocol.md`'s CHANGES.md/EXAMPLES.md escalation-packet authoring instructions for leanness. All three guard tests passed. Six non-blocking notes on the marker.

**Institutional knowledge recorded in CONTEXT.md:**

Added new glossary entry **Inlined protocol section exclusion** documenting the four-copy hand-sync pattern:

**Why:** The reviewer independently confirmed a structural fact not obvious from reading `templates/persona-protocol.md` alone: when `PROTOCOL_SECTIONS_BY_PERSONA` drops a section from a persona's inlined excerpt (e.g., reviewer's "Fourth verdict: escalate-to-human" section), that persona may carry its own hand-authored or hand-adapted copy of that content as an independently-maintained source, NOT generated from the template.

**The pattern:** Four separately-maintained copies of CHANGES.md/EXAMPLES.md instructions exist:
1. `templates/persona-protocol.md` — canonical source, but template-inlined-excluded for reviewer
2. `agents/reviewer.md` (~lines 247-311) — hand-authored, second-person copy
3. `adapters/codex/agents-md-fragment.md` — hand-adapted condensed copy
4. `adapters/cursor/rules/persona-protocol.mdc` — hand-adapted condensed copy

**Net effect:** Editing only the template **does NOT** change what the reviewer persona actually reads or produces at runtime. Coordinated hand-sync across all N copies required in follow-up units (e.g., unit reviewer-changes-examples-lean-2).

**Mechanism:** Inlining via `bin/cli.js` ~line 755 at scaffold/`--update --force-render` time. Not all dropped sections require this pattern — only those whose content the persona's own documentation surface needs to preserve.

**Location in CONTEXT.md:** New entry right after **Protocol excerpt**, linked back to that entry for context.

**Boundaries:** Documentation only — did not touch `templates/persona-protocol.md`, `agents/reviewer.md`, or adapter fragments (follow-up unit's job).
