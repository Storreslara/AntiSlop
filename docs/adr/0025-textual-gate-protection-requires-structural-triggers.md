# ADR 0025: Textual-gate protection requires structural triggers, never word presence

Date: 2026-08-24

Status: Accepted (units hdg-lexer-1, hdg-prose-2, hdg-prose-2-fix2, rpg-comment-3, 2026-08-24)

## Context

This repo's protection gates guard files by inspecting command text — a
pre-execution safety check that cannot resolve runtime information like where a
variable points or what a function call does. Two gates rely on this strategy:

- `human-decision-gate.sh` protects `.claude/human-review/<task-id>/DECISION`
- `reviewed-path-gate.sh` protects `.claude/reviewed/<marker-id>.pass` and `.fail`

Both gates block writes by matching literal substrings in the raw command
text: `human-review` and `DECISION` in the first gate, `reviewed` and `pass`/`fail`
in the second. This textual matching is fast and stateless, but it faces a
fundamental hazard: **a gate triggered by the mere presence of words in text
necessarily triggers on prose mentions, not just write attempts**. A commit message
describing a security fix to the DECISION file (`git commit -m "fix(human-review-1):
guard the DECISION file"`) has both substrings but does not write anything.

## Problem

Without discipline, a textual-protection gate either:

1. **Over-blocks:** It denies reads, test code, and inert prose that happen to
   mention the protected path — forcing developers to rephrase around the
   gate, which is a "self-authorized bypass" escape valve and defeats the
   gate's purpose.

2. **Under-blocks:** It narrows the trigger to avoid false positives but then
   becomes bypassable by obfuscation — quoting the path components separately
   (`'re'viewed`), dot-segment traversal (`.claude/./reviewed`), or line
   continuation.

3. **Is not machine-checkable:** The gate cannot reason about runtime intent
   (does this variable hold the protected path?), so any guard that claims to
   "check what the command writes" must be verified by measurement, not
   assumption.

Two prior incidents in this repo validated this hazard. Unit gh345-1
(2026-08-11) discovered that `grep 'DECISION\|human-review' <file>` — a pure
read — was denied. Unit gh345-2 addressed it by adding a benign-command
allowlist, but the allowlist carved exceptions (e.g., allowing `git` to be used
in certain forms) that later review found questionable (#186) and that required
ongoing maintenance. Both units left the core problem unsolved: the gate's
trigger condition was based on text presence, not on whether a write could
actually occur.

## Decision

**A gate whose protection is textual must be triggered by path shape and program
identity, never by the presence of words alone.**

This decision has three implications:

### 1. Path shape is structural, not textual

A word's presence is textual; a path's spelling is structural. The gate must
require that *both trigger words appear in a contiguous run that resembles a
path*, and that run must survive into the command skeleton's executable (CODE)
positions — not masked by quoting, comments, or expansion. This closes the
false-positive (prose mention) hazard while remaining machine-checkable: a test
suite can enumerate every shape that does or does not resemble a path.

### 2. Program identity must anchor the decision

If the gate cannot measure what a program does (e.g., does `sh -c '…'` really
execute its argument?), then the gate may conditionally trust that program
identity. Only `git commit` with a prose-only message can be trusted to carry
inert text; `sh -c` always executes; `grep` reads but `sed -i` writes. This
gate-local recognizer is not a general-purpose allowlist — it is specific to
the one gate and the one program, so changes to it do not automatically apply
elsewhere.

### 3. Every narrowed condition must be mutation-proved

Removing any guard must flip at least one test case from denied to allowed.
If a guard's removal changes no verdict, it is vacuous and must be deleted.
This ensures that every part of the trigger condition is load-bearing and
verifiable by test mutation, not by reasoning alone.

## Consequences

- **False positives are eliminated**, not routed around. A developer no longer
  needs to rephrase a commit message to dodge the gate — the gate distinguishes
  prose from code.

- **The gate-local recognizers are visible and measurable.** Both gates declare
  their recognizers (prose-only commits, inert triggers, commented mentions) and
  their acceptance criteria in comment headers, so a reviewer can audit whether
  each recognizer is sound and measure its regressed through test mutation.

- **Obfuscation still fails.** Quote-splitting, dot-segments, and line
  continuation in path text are caught by the path-shape scan, which does not
  rely on word presence.

- **The gate can be extended cautiously.** A future recognizer for a new program
  (e.g., allowing `fzf -c` for interactive reads) can be added to this gate alone
  without changing the shared lexer, because the program condition anchors the
  decision locally.

## Related

- **Implemented by:** units hdg-lexer-1, hdg-prose-2, hdg-prose-2-fix2, rpg-comment-3
- **Resolves:** false-positive denials of reads and prose from units gh345-1 and
  gh345-2, per `docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md`
- **References:** [[narrate-versus-target distinction]], [[trigger token]],
  [[path-shaped run]], [[skeleton]], [[prose-only commit]] in `CONTEXT.md`
