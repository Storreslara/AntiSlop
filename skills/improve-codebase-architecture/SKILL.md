---
name: improve-codebase-architecture
description: >
  Scan a codebase for deepening opportunities and return them as a ranked markdown list with a top
  recommendation. Read-only: writes no file, opens no browser, asks no question.
---
<!-- Derived from mattpocock/skills skills/engineering/improve-codebase-architecture/SKILL.md @ e9fcdf9 (MIT, see skills/THIRD-PARTY-NOTICES.md); vendored original archived at docs/archive/skills/improve-codebase-architecture/ -->

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This skill is _informed_ by the project's domain model and built on a shared design vocabulary:

- Use the `codebase-design` skill for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion — don't drift into "component," "service," "API," or "boundary."
- The domain language in `CONTEXT.md` gives names to good seams; ADRs in `docs/adr/` record decisions this skill should not re-litigate.

You run as a one-shot subagent: you cannot ask a question, open a browser or wait for a reply. Do the exploration, then return the result as your final message.

## Process

### 1. Explore

**Scope before you scan — YAGNI.** Deepening a module pays off by making future changes to it easier, so put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look:

- If the dispatch named a direction — a module, a subsystem, a pain point — take it, and skip the inference below.
- Otherwise, walk back a good stretch of the commit history (`git log --oneline`) to find the codebase's hot spots — the files and areas that keep coming up — and let those paths pull your attention first. If the changes are scattered with no clear hot spot, widen the net.

Read the project's domain glossary (`CONTEXT.md`) and any ADRs in the area you're touching first.

Then walk the codebase. Use the `explorer` agent if it is present for the structural questions (callers, dependencies, blast radius); otherwise read the code directly. Never use the built-in `Explore` agent type. Don't follow rigid heuristics — explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Return the candidates

Return the candidates in your final message as a markdown list. No file is written, no browser is opened, no external asset is loaded and no question is asked. For each candidate give:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Benefits** — explained in terms of locality and leverage, and how tests would improve
- **Recommendation strength** — one of `Strong`, `Worth exploring`, `Speculative`

End with a **Top recommendation**: which candidate you'd tackle first and why.

**Use CONTEXT.md vocabulary for the domain, and the `codebase-design` vocabulary for the architecture.** If `CONTEXT.md` defines "Order," talk about "the Order intake module" — not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly in the candidate (e.g. _"contradicts ADR-0007 — but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

Do NOT propose interfaces yet.

### 3. Later dispatches (not part of this run)

Grilling a chosen candidate is a later, separate dispatch that uses the `grilling` and `domain-modeling` skills to walk the decision tree — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive — and to keep `CONTEXT.md` and the ADRs current as decisions crystallize. To compare alternative interfaces for a chosen candidate, a later dispatch can use the design-it-twice pattern in the `codebase-design` skill (`DESIGN-IT-TWICE.md`).
