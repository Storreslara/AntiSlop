---
name: pathfinder
description: >
  Apply when slicing a finalized spec into dispatch-ready units and publishing
  them to the project issue tracker (task-master's job). Sizing, naming,
  ordering and publishing guardrails for reliable, unambiguous
  lead-programmer/scribe dispatch — not a planning or grilling skill.
---
Derived from mattpocock/skills `wayfinder` and `to-tickets` @ e9fcdf9 (MIT, see `skills/THIRD-PARTY-NOTICES.md`; original of the latter: `docs/archive/skills/to-tickets/`), adapted for task dispatch:
wayfinder charts foggy work as a map of decision tickets; pathfinder narrows
that idea to task-master's actual job — turning an already-finalized spec
into dispatch-ready units, never deciding what to build.

Four rules:

1. ONE UNIT, ONE DECISION — size each sliced issue to a single vertical
   slice a lead-programmer session can execute end-to-end: one file set, one
   acceptance check, one commit. If a unit bundles two independent decisions
   or touches unrelated surfaces, split it before filing — don't let "small
   enough to review" become "small enough to argue about."
2. REFER BY NAME, NOT BY BARE ID — in dispatch prompts, retrieval-contract
   lines, and ordering notes, name units by their title (e.g. "Step 2.3 —
   author pathfinder skill"), not a bare issue number. The id still travels
   alongside for fetching, but the name is what a reader keys off; a wall of
   #27, #28, #29 is illegible.
3. EXPLICIT BLOCKING, NEVER IMPLICIT ORDER — when unit B needs unit A done
   first, say so directly (a `Depends on / blocked by:` line pointing at A by
   name, on the tracker's native dependency field if it has one). Don't rely
   on file order in a plan doc or reading order in a dispatch prompt to imply
   sequencing — a unit is only independently grabbable if its blockers are
   stated, not inferred.
4. STATE IT PRECISELY OR IT'S NOT READY TO TICKET — the same bar as this
   project's machine-checkable-criteria rule: an acceptance criterion is only
   valid if it's something an agent can RUN and get a pass/fail from, not
   "works correctly." If you can't state a unit's criterion that precisely,
   that's a spec gap, not a slicing problem — report it back to spec-master
   rather than papering over it with a vaguer ticket. A unit whose question
   isn't sharp yet doesn't get a placeholder ticket; it stays unsliced until
   the spec resolves it.

Scope: slicing, dispatch-prompt authoring and publishing the units. This skill carries none of
wayfinder's user-facing ticket types (research, prototype, grilling) —
task-master never grills, spec-master already did — and none of its
transitive skill dependencies (grilling, domain-modeling, prototype).

## Publishing

Read the tracker from the `issueTracker` field of `.claude/persona-config.json` with the `Read` tool (a Bash command naming that file can be refused by `harness-integrity-gate.sh`), together with the retrieval-contract line; never assume a tracker. The finalized spec stands in for user approval, so there is no quiz and no approval loop: publish the sliced units directly.

- **Local files** -> write one file per unit under the directory the `issueTracker` line names (if it names none, `.scratch/<feature-slug>/issues/`), as `<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers or titles it depends on. One unit per file, never a single combined file; use the template below.
- **A real issue tracker** (GitHub, Linear, ...) -> publish one issue per unit in dependency order (blockers first), so each unit's blocking edges can reference real identifiers. Use the platform's native blocking or sub-issue relationship where it has one; otherwise set each unit's "Blocked by" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise.

Work the frontier: any unit whose blockers are all done. For a purely linear chain that is top to bottom. Do NOT close or modify any parent issue.

### Wide refactors: expand, migrate, contract

A wide refactor is one mechanical change (rename a column, retype a shared symbol) whose blast radius fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Do not force it into one unit; sequence it as expand-contract. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites in batches sized by blast radius (per package, per directory), each batch its own unit blocked by the expand, keeping the build green because the old form still exists. Finally contract: delete the old form once no caller remains, in a unit blocked by every migrate batch. When even the batches cannot stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify unit.

### Local-file template

```markdown
# <NN> — <Unit title>

**What to build:** the end-to-end behaviour this unit makes work, not a layer-by-layer list.

**Blocked by:** the numbers or titles of the units that gate this one, or "None — can start immediately".

**Status:** ready-for-agent

- [ ] Acceptance criterion 1 (a command an agent can run, with its expected exit and output)
```
