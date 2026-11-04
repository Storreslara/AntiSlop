# Reviewer-tier path rule and review gating off by default (2026-11-04)

Slug `tier-path-and-gate-default`. Plan dir `docs/plans/2026-11-04-tier-path-and-gate-default/` (contracts).
Baseline for every fact below: `57267561`. Two units, run in order: `tier-path-rule`, then `gate-default-off`.

## Goal

The operator decided both changes (2026-11-04). After this plan:
- G1 (`tier-path-rule`). `hooks/scripts/reviewer-tier.sh` prints `sonnet` for a diff whose every changed
  file is in the low-risk path class (docs, fixtures, tests), whatever its size. A FAIL record, a sensitive
  path and every unmeasurable input still print `opus`. A mixed diff gets the existing size rule (<=40
  lines, <=3 files).
- G2 (`gate-default-off`). A fresh install from `bin/cli.js` writes `reviewGating.mode: "off"` into the
  skeleton `.claude/persona-config.json`. The reader rule does not change: absent, unreadable or junk
  means `enforce`, so existing installs stay on `enforce`.

## Decisions

- **D1 The low-risk path class (G1).** Four patterns, matched against the numstat path:
  `'^docs/.*\.md$'`, `'^(README|CHANGELOG|CONTEXT|CONTRIBUTING)\.md$'`, `'^tests/'`,
  `'^eval/(.+/)?fixtures/'` (matches `eval/fixtures/` and `eval/abtest/fixtures/`). Left out on purpose:
  `CLAUDE.md` (loaded into every session), `templates/`, `skills/`, `commands/` (shipped prompt text),
  non-`.md` files under `docs/` (`docs/plans/*-criteria/` holds executable criteria scripts) and
  `eval/abtest/checks/` (holdout checks). `tests/validate.sh` matches `^tests/` but is sensitive, and the
  sensitive check runs first, so it stays `opus`.
- **D2 Evaluation order (G1).** Unchanged: FAIL record, range guards, then per file the C-quoted, sensitive
  and binary checks, then the zero-file guard. New: after the zero-file guard, `sonnet` if every file was
  low-risk. Otherwise the unchanged size rule counts every file and line, low-risk ones included. The new
  route only adds a way to reach `sonnet` after all existing `opus` exits. This matters because past FAILs
  on this script were all fail-open bugs (`192.fail`: rename and C-quoting; `gh413.fail`: id sanitizing;
  `224.fail`: marker path).
- **D3 One definition (G1).** `LOW_RISK_PATHS` and `touches_low_risk_path` go in
  `hooks/scripts/lib/sensitive-paths.sh`. That lib already ships to `.claude/` (`bin/cli.js:688`
  `CLAUDE_ONLY_HOOK_LIB_FILES`), so `bin/cli.js` does not change. `tests/scope-libs.test.sh` asserts the
  class is defined only there. `bin/unit-size.sh` and `bin/review-precheck.sh` also source the lib but do
  not use the new class (unit lanes do not change). `touches_low_risk_path` joins the `declare -F` guard.
  Without the guard, a missing function would return 127, clear the flag and fall back to the size rule,
  so the guard is for consistency, not safety.
- **D4 Size fixtures leave `docs/` (G1).** I measured a scratch prototype of D1+D2 at baseline. Cases (c),
  (d), (l), (o) and (ai) flip to `sonnet` because their fixtures are `docs/*.md`, and mc2, mc3 and mc9
  would then pass without testing anything. Every size-boundary fixture moves to `src/`. No existing
  `run_case`/`run_at` line changes or is removed.
- **D5 What G1 does not edit.** `agents/orchestrator.md:185` only names the script and does not state the
  rule, so it stays as is. `CONTEXT.md:213` is the **unit lane** entry (`bin/unit-size.sh`), and G1 does not
  change unit lanes. Reviewer-tier wording lives in `docs/harness-glossary.md` ("Measured reviewer tier",
  :1468), and that is where the new term goes (Open Question 2). No adapter carries `reviewer-tier.sh`.
- **D6 Skeleton only (G2).** Add `reviewGating: { mode: 'off' }` to the fresh-install `personaConfig`
  literal (`bin/cli.js:2657-2682`), with a comment that follows the `humanReviewMode` precedent. The
  `existingPersonaConfig` (`--overwrite`) branch and `--update` keep every field as is, with no backfill.
  The schema keeps `"default": "enforce"` (the reader's value) and its resolution sentence word for word;
  the description gains a fresh-install sentence. No hook, adapter, `commands/gate.md` or
  `bin/harness-integrity.sh` reader changes.
- **D7 ADR (G2).** I judged that an amendment section in ADR-0038 is enough, so there is no new ADR. The
  change is a default inside the same switch, it follows the precedent the `humanReviewMode` skeleton
  already set, and it leaves the decision recorded in 0038 unchanged.
- **D8 Drift (G2), measured with `bin/harness-integrity.sh` at baseline.** Baseline without the file, tree
  skeleton `off` → `config=ok` (nothing to compare). Skeleton `off` committed and unchanged → `ok`.
  Skeleton `off` → `enforce` → `drift fields=reviewGating.mode` (any change is drift). These are added as
  T20, T21 and T22. T5-T7 and T19 pin the reader default and stay untouched.
- **D9 Install skill gap (G2).** `skills/install-antislop/SKILL.md:286-290` writes the key "only for
  `off`" and merges into an existing file. On top of a skeleton, an `enforce` answer would leave `off` in
  place without anyone noticing. The fix: the skill writes the key for both answers (Open Question 1 covers
  which answer is recommended).
- **D10 Trust-model row 13, ordering, release (G2).** Row 13 says "forward reference … not yet landed", but
  the check exists (`bin/harness-integrity.sh:106`, T5). The row gets `bin/harness-integrity.sh` in its
  "Checked by" column and a note about the shipped default, and `tests/trust-model-bijection.test.js`
  changes `EXPECTED_EXEMPT_COUNT` from 2 to 1 (Open Question 3). `eval/abtest/arms/arm-b.sh:66` already
  writes `enforce` and overwrites the whole config, so it is unaffected. No version bump: each unit adds an
  `[Unreleased]` CHANGELOG bullet (P3 is per release).

## Cross-unit risks

- `tier-path-rule` edits `hooks/` (sensitive class), so its own review is `opus` and the new rule never
  applies to its own review. `gate-default-off` edits `bin/cli.js`, which is also sensitive.
- Both units edit `CHANGELOG.md` and run `node bin/cli.js --update`, which rewrites `.claude/` copies and
  `fileHashes` in `.claude/persona-config.json`. Run them one at a time, `tier-path-rule` first. Each
  unit's `--update` must leave this repo's `reviewGating` absent (criterion in both contracts).
- After `tier-path-rule`, docs-only and test-only units (including `gate-default-off`'s follow-ups) are
  reviewed on `sonnet`. The orchestrator can still raise the model to `opus` (ADR-0009, downgrade-only).

## Units

### 1. `tier-path-rule` — contract [`contracts/tier-path-rule.md`](2026-11-04-tier-path-and-gate-default/contracts/tier-path-rule.md)

Affected files: `hooks/scripts/lib/sensitive-paths.sh`, `hooks/scripts/reviewer-tier.sh` (header comment
too), `tests/reviewer-tier.test.sh`, `tests/scope-libs.test.sh`,
`docs/adr/0009-reviewer-tier-measured-eligibility.md`, `docs/harness-glossary.md`, `CHANGELOG.md`, and the
`.claude/` copies, which change only through `node bin/cli.js --update --force-render`.

New cases in `tests/reviewer-tier.test.sh`, each a `run_case`:
`(pr1)` `docs/big.md` 41 lines → sonnet; `(pr2)` 4 docs `.md` files → sonnet; `(pr3)` `tests/x.test.sh`
200 lines → sonnet; `(pr4)` `eval/abtest/fixtures/f.txt` 60 lines → sonnet; `(pr5)` `docs/a.md` 41 +
`src/a.js` 1 → opus; `(pr6)` `docs/a.md` 1 + `src/a.js` 1 → sonnet; `(pr7)` `docs/a.md` 1 +
`tests/validate.sh` 1 → opus; `(pr8)` docs-only with `unit-fail` → opus; `(pr9)` binary
`tests/fixtures/b.bin` → opus; `(pr10)` `CLAUDE.md` 41, `docs/s.sh` 41 and `templates/t.md` 41 lines
(three separate commits) → opus; `(pr11)` `hooks/x.sh` renamed to `docs/x.md` → opus. Mutations:
`(mc14)` the all-low-risk `sonnet` branch deleted → (pr1) flips to opus; `(mc15)` the condition weakened
from every file to any file → (pr5) flips to sonnet. In `tests/scope-libs.test.sh`: (b)'s `declare -F`
line updated, `(a2)` members `docs/x.md README.md tests/a.sh eval/abtest/fixtures/f` and non-members
`CLAUDE.md docs/x.sh templates/t.md eval/abtest/checks/c.js src/a.md`, `(b2)` reviewer-tier.sh defines no
`LOW_RISK_PATHS`. ADR-0009 gets a `### Amendment (2026-11-04): path rule` section listing the four
patterns, the order in D2 and the mixed-diff fallback. The glossary entry "Measured reviewer tier" names
the rule, and a new entry `**low-risk path class**:` lists the four patterns.

### 2. `gate-default-off` — contract [`contracts/gate-default-off.md`](2026-11-04-tier-path-and-gate-default/contracts/gate-default-off.md)

Affected files: `bin/cli.js` (skeleton literal only), `templates/persona-config.schema.json`
(`reviewGating.mode.description` only), `tests/cli-backfill.test.js`, `tests/harness-config-drift.test.sh`
(appended T20-T22 only), `tests/trust-model-bijection.test.js`, `docs/trust-model.md` (row 13),
`docs/adr/0038-review-gating-runtime-switch.md`, `CONTEXT.md` ("review gating off" entry),
`README.md` (config table row), `skills/install-antislop/SKILL.md` (the `reviewGating.mode` bullet),
`CHANGELOG.md`, and `.claude/` copies through `--update` only.
Criteria 4 and 5 run `criteria/gdo-reader.sh` and `criteria/gdo-docs.sh` in the plan dir (both print 0 doc
claims / an unchanged reader at baseline).

New checks in `tests/cli-backfill.test.js`, placed before the `failures > 0` exit: `(gdo-1)` `--yes` fresh
install writes `reviewGating.mode: "off"`; `(gdo-2)` `--update` on a config without the key (stale
`pluginVersion`, so the fast path does not run) leaves it absent; `(gdo-3)` `--overwrite --yes` on such a
config leaves it absent. ADR-0038 gets `## Amendment (2026-11-04): fresh installs ship off`, which names
`bin/cli.js`, says the reader rule is unchanged, and says that `--update`/`--overwrite` never add the key.
The `skills/install-antislop/SKILL.md` bullet contains the exact sentence `Always write the key: "off" or
"enforce".`

## Open Questions

1. **Install skill recommendation (D9).** Should `/install-antislop` list `off` first as the recommended
   answer, to match the new shipped default? Recommended: yes, list `off` first and always write the key.
   Options: (a) `off` recommended (default); (b) keep `enforce` recommended and still always write the key.
   The contract follows (a); with (b), only the order of the bullet's wording changes.
2. **CONTEXT.md for G1 (D5).** The dispatch named `CONTEXT.md:213`, but that is the unit-lane entry, which
   G1 does not change. Recommended: no CONTEXT.md edit in `tier-path-rule`; the term goes in the harness
   glossary. Options: (a) no edit (default); (b) add one sentence to the unit-lane entry saying the lane
   ignores the low-risk path class.
3. **Trust-model row 13 (D10).** Recommended: change "Checked by" to `bin/harness-integrity.sh` and the
   exempt count from 2 to 1. Options: (a) convert (default); (b) change the notes only and keep the row
   exempt.

## Scribe update hint

New harness-glossary term `low-risk path class` (written inside `tier-path-rule`). CONTEXT.md gets one
sentence in "review gating off" (written inside `gate-default-off`). There is no ADR number for scribe to
assign: both changes are dated amendments to existing ADRs (0009 and 0038).
