---
name: hdg-prose-2-debug-spec
description: Debug spec for the human-decision-gate whitespace-task-id fail-open — settled remedy decision, the four premise corrections measurement forced, and the deferred F-1 glob class.
metadata:
  type: project
---

`hdg-prose-2` hit the 2-FAIL cap on 2026-08-24. Debug spec at
`docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md`; one unit,
`hdg-prose-2-fix2`, fast path.

**Why:** both FAILs were fail-opens in the SAME function
(`has_path_shaped_occurrence`), found the same way — varying a dimension the
spec's own definition of the predicate did not model. First quote boundaries
(bash concatenates adjacent fragments), then whitespace (a quoted bash word may
contain a space). The spec described the predicate as a *lexical run* instead of
an *assembled word*, so the implementer inherited the error twice. A third
implementation pass on the unchanged spec would not have closed it.

**Settled remedy (do not re-open):** neither reviewer-sketched remedy survives
measurement. Narrowing the Write/Edit branch's `*` glob to an id charclass is a
LOOSENING — measured, it unprotects nested paths as well as whitespace ids.
Pinning it as an accepted residual would ratify a *regression* under a
discipline (R-4/R-5) explicitly built for *pre-existing* holes. The fix is an
anchored companion condition OR-ed beside the run scan.

**How to argue "no new false positives" for a text-scanning gate.** A
differential sweep over a generated corpus (20 separators x 7 program shapes x
3 quotings = 420) diffing verdicts old-gate vs candidate: 22 new denials, all
inside the target class, 0 new allowances. That two-sided bound is far stronger
evidence than a hand-picked must-deny list, and it is cheap. Reuse it.

**How to apply:** four premises I asserted and measurement then reversed —
budget for this shape.
1. "Four id grammars exclude whitespace, so a whitespace task-id is
   impossible." FALSE. `dispatchHygiene.mode` is `warn` here, and `gatedAgents`
   defaults to `lead-programmer` only, so the REVIEWER — the persona that
   actually creates `.claude/human-review/<task-id>/` — is not gated at all.
   Grammar that is only warned about constrains nothing.
2. The parent plan's R-9 (`protectedPaths` blocks the gate edit) went STALE
   mid-flight: `99e393c` dropped both gate scripts. Re-read
   `.claude/persona-config.json`, never copy a risk forward.
3. The gate has never resisted multi-call chains: at the PRE-UNIT baseline, a
   three-command `mv` out / write / `mv` back forges a DECISION for a real id,
   every step individually ALLOWED. It is a single-command guard by
   construction. State severity honestly in both directions; it still does not
   excuse a regression.
4. A reviewed-path-gate probe fixture with no `persona-config.json` fails OPEN
   and every verdict reads ALLOW. Copy the config into the fixture, or the
   whole measurement is noise.

Deferred as **F-1**, pinned tracked-open (NOT accepted): the glob-metacharacter
early-exit miss — `[D]ECISION`, `?ECISION`, `DEC*`,
`.claude/human-rev[i]ew/...` all ALLOW and OVERWRITE an existing decision;
byte-identical since before the unit. `reviewed-path-gate.sh` shares only the
directory-component variant. A partial fix (strip `[`/`]`) is worse than none.

Related: [[pass-note-warnings-dont-propagate]] fired again here — `hdg-lexer-1`'s
PASS note N2 flagged a stale header "for unit 2", unit 2 skipped it, nothing
else would have surfaced it.
