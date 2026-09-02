---
name: gh295_surface_term_ambiguity_for_step3
description: "surface" term overload — reviewer flagged for Step 3 to resolve via glossary or rename
metadata:
  type: project
---

**What needs resolving:** Unit gh295-1 introduced `--surface=` flag in `marker-audit.sh` and `hooks/scripts/marker-verify.sh`, which filters notes by substring match. The term "surface" now has four distinct meanings in CONTEXT.md:

1. **"behavioural surface"** (existing, line 1434) — the observable behavior change of code
2. **"disarm surface"** (existing, line 2156) — the set of 9 config fields whose weakening disarms a trust gate
3. **gate's "audit/config surface"** (existing, implicit) — the exposed configuration surface of a gate
4. **"surface (in marker audit)"** (new, gh295-1) — a substring of a note's text used as a filter, typically a file path or keyword

**Source:** Reviewer's ubiquitous-language Lens 1 finding in PASS marker `.claude/reviewed/gh295-1.pass` (lines 85-90).

**Options for Step 3:**
- **Option A (add to glossary):** Create a `[[surface (in marker audit)]]` CONTEXT.md entry defining it precisely and cross-referencing the other uses to clarify the distinction
- **Option B (rename flag):** Rename `--surface=` to `--search`, `--filter`, or another term that doesn't overload "surface"

**Why it matters:** CONTEXT.md is the shared language glossary. Ambiguous terms in the glossary confuse future readers and future code review. Step 3 is already scoped to add glossary entries for "non-blocking note", the `marker-note=`/`marker-notes=`/`marker-notes-sweep=` output grammar, and tag vocabulary (spec/code/untagged). This "surface" decision should be made at the same time, not left for later.

**Who decides:** Step 3's scribe dispatch. The reviewer explicitly flagged this as "Suggest scribe pin the new sense in Step 3's entry, or rename" — it's a scribe call, not a blocker.

**Related:** gh295 plan doc `docs/plans/2026-09-01-advisory-note-channel-gh295.md`, unit gh295-1 PASS marker, changelog.md entry for 2026-09-01.
