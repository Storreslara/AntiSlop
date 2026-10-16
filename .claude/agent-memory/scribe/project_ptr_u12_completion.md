---
name: ptr-u12-completion
description: ptr-u12 PASS closed #555; Agent dropped from lead-programmer; seven open follow-ups for spec-master (stale spawn instructions, unpinned tools line)
metadata:
  type: project
---

PASS 1443ae6 closed #555 (0.31.176). lead-programmer has no Agent tool; no-contract dispatches are pre-resolved by the orchestrator (`## Pre-resolved context`). No glossary change (existing pre-resolved context entries cover it).

Open follow-ups (not fixed; for spec-master):
- a) agents/lead-programmer.md ~79 "Spawn researcher" bullet and port twins still say spawn.
- b) Shared protocol still says spawn explorer: "Structural questions go to the explorer", "Reuse over re-derivation", agent-teams "You CAN spawn foreground subagents" (in lead-programmer's inlined copy).
- c) Codex/Cursor orchestrator ports lack the new Delegation contract paragraph (spec rules them out).
- d) Codex/Cursor lead-programmer "Scribe updates" bullet still says spawn scribe (Claude copy routes via scribe digest).
- e) agents/orchestrator.md ~420-425 pointer to "Review ownership" stale since ptr-u5 (list is now in "Review markers and gate mechanics (owner-facing)"); same item as ptr-u5's orchestrator-pointer note.
- f) No test pins lead-programmer's tools line; re-adding Agent goes uncaught.
- g) Orchestrator paragraph is two sentences vs plan's one (immaterial).

**Why:** reviewer notes, deliberately left for later units.
**How to apply:** check before concluding lead-programmer spawn rules are consistent.
