---
name: cli-update-never-reaches-settings-fragment
description: `--update` returns at bin/cli.js:2188 and never reaches the templates/settings-fragment.json merge at 2387 — a new fragment key is scaffold-only and inert for already-adapted projects unless runUpdate backfills it.
metadata:
  type: project
---

Measured at 0.31.75 (2026-09-23) while scoping the Bash-output-cap unit of
issue #476.

## The trap

`templates/settings-fragment.json` looks like the obvious place to add a new
`.claude/settings.json` key. It is — **for new adopters only.**

`main()` branches at `bin/cli.js:2187-2189`:

```js
if (args.includes('--update')) {
  return runUpdate(args);
}
```

The fragment is read at `bin/cli.js:2387` and merged at ~2395, both **far
below** that early return. So `node bin/cli.js --update` never sees a new
fragment key. An already-adapted project (including this repo) never receives
it.

**Why this is easy to ship broken:** a criterion like `git grep
'<newKey>' templates/settings-fragment.json` passes, and so does
`bash tests/validate.sh`. Nothing fails. The key is simply inert. Same vacuous
class as [[drift-check-idiom-broken]].

## What actually works

`runUpdate` DOES write `.claude/settings.json` — the hook-registration
backfill at `bin/cli.js:1293-1303` (plus the standalone-hook dedupe at 1264).
A new settings key needs a parallel backfill there. Follow that precedent
rather than inventing a pattern.

`deepMerge` (`bin/cli.js:232-254`) is **additive-only** for scalars:
`else if (!(key in target)) target[key] = source[key];` — it backfills where
absent and never clobbers an existing value. That is usually the semantics you
want, but it also means **you cannot change an already-set value via the
fragment**, only seed an absent one.

## Two constraints on who may do the write

- `.claude/settings.json` is **Set B** of `harness-integrity-gate.sh`, no grant branch.
  **Corrected (2026-09-24):** it is no longer denied on `Write`/`Edit`
  unconditionally — the main session, under an allowlisted permission mode,
  now reaches a human-confirmation `ask` instead (never from a subagent). An
  implementer still cannot hand-edit it either way; only a human approving
  that prompt can.
- Set B is **deliberately absent from the gate's Bash branch** (ADR-0025), so
  *running `bin/cli.js` via Bash is the sanctioned route*. Hand-editing would
  also break constitution P2 (prefer deterministic scripts over hand-edits).

**How to apply:** any spec adding a `.claude/settings.json` key needs (a) the
fragment change, (b) a `runUpdate` backfill, and (c) a mutation proof that
reverting the backfill hunk fails the test — otherwise the fragment-only half
passes review while doing nothing. Related:
[[verify-own-criteria-nonvacuous]], [[config-recovery-has-no-automated-route]].
