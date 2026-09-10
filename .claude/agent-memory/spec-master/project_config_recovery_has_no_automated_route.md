---
name: config-recovery-has-no-automated-route
description: A deleted .claude/persona-config.json cannot be rebuilt by any bin/cli.js path without losing the judgment fields; git restore is the only lossless route. Measured 2026-08-26.
metadata:
  type: project
---

**A deleted `.claude/persona-config.json` has no automated recovery route.**
Never write a spec step, gate message, or runbook that says otherwise without
re-measuring first.

Measured 2026-08-26 against `bin/cli.js` v0.31.65 on throwaway fixtures:

- **`--update` refuses, by construction.** `runUpdate()` early-exits
  `process.exit(1)` when the config is absent (`bin/cli.js:1076-1083`) — it
  will not proceed *because* the file it would rebuild is missing, no matter
  which other adaptation witnesses survive. Tested `--update` alone and with
  `--force-render`, `--check`, `--dry-run`, `--allow-downgrade`, and all
  together: every one exits `1` and mutates zero bytes. **No bypass flag.**
- **The scaffold path rebuilds a strictly weaker config.**
  `node bin/cli.js --yes --overwrite` exits `0` and writes ten default-valued
  fields — `protectedPaths: []`, `testAndLintCommand: ""`, `issueTracker: ""`,
  `humanReviewMode: "critical"` — with **no `fileHashes`, `substitutions`,
  `dispatchHygiene` or `markerCommitCheck` keys at all**. Against this repo's
  live config that was 26 `protectedPaths` entries, both MCP substitutions and
  52 `fileHashes` rows gone.

  **Correction, re-measured 2026-09-09: this repo's live `protectedPaths` is
  now `[]`.** `jq -r '.protectedPaths | tojson' <config>` returns `[]` at
  `915acec`. The 26-entry figure above is frozen at 2026-08-26 and must not be
  planned against — a spec that assumes `hooks/**` is already protected by
  `protectedPaths` is wrong today. The rest of this note (the scaffold path
  writes a strictly weaker config, `--update` refuses, `git restore` is the
  only lossless route) re-verified as still true. Re-measure the array before
  citing a count; it is session-mutable (see the `gh419` note recording
  entries being lifted and restored mid-session).
- **It does not read `personaSelection` off disk.** A `--personas=reviewer`
  fixture (4 agent files) came back with all 7 optional personas selected and
  **6 agent files it had never selected newly written**. The blast radius is
  bigger than "overwrites what's there" — it *adds*.
- **Chaining does not heal it.** `--update` immediately after such a rebuild
  exits `1`, refusing to render `explorer.md` because the `substitutions`
  carrying its MCP launch command are gone.
- `--overwrite` **without** `--yes` is interactive (prompts on stdin); with
  empty stdin it exits `0` having written nothing. Never name bare
  `--overwrite` in an automated context.
- **`git restore` is the only lossless route.** The config is tracked, and it
  is absent from `OPERATIONAL_GITIGNORE_PATTERNS` (`bin/cli.js:155-170`), the
  single-sourced managed ignore list, so it is tracked for adopters too.

**Why:** discovered resolving gh416's C1.0 precondition in
`docs/plans/2026-08-25-harness-trust-gaps.md`, which had assumed `--update`
would reconstruct the file. Ratified as RD2a/D9 in that spec (commit
`10db5a0`).

**How to apply:** the judgment fields (`protectedPaths`, `gatedAgents`,
`humanReviewMode`, `testAndLintCommand`, `issueTracker`) have **no on-disk
witness**, so no amount of new `bin/cli.js` code can recover them — that kills
the "just add a narrow `--reconstruct-config`" option before you cost it out.
Two consequences worth carrying:
1. In a *security* context, a recovery route that writes `protectedPaths: []`
   completes the tamper it was meant to undo. Naming it in a fail-closed
   gate's refusal is a disarm recipe, not a recovery route.
2. "Exits 0 and a file appears at that path" is not "reconstructs the config."
   Check the *contents* against the pre-delete config, not just existence —
   the original C1.0 asserted only `gatedAgents` presence, which the useless
   blank-field rebuild would have satisfied.

Mutation-proof trap found here, generalizing
[[verify-own-criteria-nonvacuous]]: a criterion asserting `--update` exits `1`
is **vacuous alone**. A mutant with the early exit replaced by a config write
*still* exits 1, for a later reason. Only `test ! -e <path>` kills it. When
pinning "tool X refuses", assert the absence of the effect, never the exit
code.

See also [[validate-sh-is-a-mirror-parity-check]] for what `fileHashes` is
load-bearing for, and [[escalation-vs-protectedpaths]] for why
`protectedPaths` is a separate mechanism from `humanReviewMode`.
