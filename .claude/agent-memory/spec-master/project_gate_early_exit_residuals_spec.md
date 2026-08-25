---
name: gate-early-exit-residuals-spec
description: Settled decisions for the 2026-08-24 two-unit gate residual spec (hdg-anchor-1, rpg-canon-2) — the anchored arm beat the charclass widening 0 FPs to 97, and the one-site rpg fix is near-vacuous.
metadata:
  type: project
---

`docs/plans/2026-08-24-gate-early-exit-residuals.md`. Two units, fast path,
both `opus`: `hdg-anchor-1` then `rpg-canon-2` (strict order only because both
regenerate `persona-config.json` `fileHashes`).

**Why:** closes the two residuals disclosed by the adversarial reviews of
`hdg-prose-2-fix2` and `rpg-comment-3` — both pre-existing, both measured to
really write the protected file.

**How to apply** — four results that cost real measurement, so don't re-derive:

1. **The FP-budget tradeoff the fix2 report escalated is DEAD.** It measured
   widening the path-safe charclass to "anything but newline" and left the
   6-false-positive cost to the operator. A **structurally anchored** second arm
   — deny when the head between `human-review` and `/DECISION` **begins with
   `/`** and holds no newline — closes the identical 18/18 shapes and 126/126
   live holes with **0** prose denials, where the widening costs **97** over a
   234-command corpus. A dominated option is not a tradeoff. Don't hand the
   operator a choice that measurement can kill.
2. **Canonicalizing only `reviewed-path-gate.sh`'s early-exit closes 1 of 10
   shapes and passes all 412 existing assertions.** The second protected-path
   literal in `write_with_commented_mention()` re-tests the RAW string and lets
   the obfuscated command straight back out. The "extract a shared helper"
   maintenance suggestion is therefore *the fix*, not optional tidying.
3. **Make the canonicalization a union with the RAW test FIRST.** Normalizing
   alone erases the mention in `rm -rf .claude/reviewed/../x`, converting a
   denial into an allowance. Union-with-raw makes "0 new allowances" structural.
4. **`CONTEXT.md`'s gate glossary is factually wrong in five entries**, most
   seriously **path-safe charclass** (`:1565`), which is defined *inverted* — it
   claims the set excludes space and tab when the code's is the one that
   includes them. Also wrong: marker id charclass, run scan/companion scan,
   quote-joined text, path-shaped run. Read the code; both dispatches say so.

Open Questions (non-blocking, defaults already baked in): keep F-1 (glob
metacharacters) deferred rather than bundling it while `protectedPaths` is open;
let `scribe` fix the glossary after both units. Note `protectedPaths` currently
omits both gates — a temporary window that closes after `rpg-canon-2`.

Related: [[branch-agreement-criterion]] (the criterion that makes this class of
fail-open impossible to miss), [[hdg-prose-2-debug-spec]],
[[decision-gate-prose-false-positive]].
