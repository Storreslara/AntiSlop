# `bin/cli.js --update` never propagates hook scripts (standalone-mode security gap)

Date: 2026-08-12
Slug: `standalone-hook-propagation-gap`
Origin: side-finding R-7 / Open Question 3 of
`docs/plans/2026-08-12-human-decision-gate-false-positive.md`, re-verified
live and found to be **materially wider** than that record states.

## Goal

Make `bin/cli.js --update` — the advertised, zero-token resync path that
`/antislop:update-antislop` runs — deliver hook **scripts** and their
**hooks.json registrations** to already-installed standalone projects, so a
project that installed AntiSlop before a gate existed actually receives that
gate. Then bring this repo's own frozen `.claude/hooks/scripts/` mirror back
to parity and gate it in `tests/validate.sh` so it can never silently drift
again.

## Context

All claims below were measured live on 2026-08-12 against the working tree
at `f2654dc`, not inferred.

**The finding as reported (R-7) is true but understates the defect.** R-7
says the shipped copy at `.claude/hooks/scripts/` contains neither
`human-decision-gate.sh` nor `lib/benign-command.sh`. Confirmed. But the
cause is not a missing entry in a file list — it is that **no file list
exists**. `buildFileSpecs()` (`bin/cli.js:452-498`), the sole source of
truth for what `--update` refreshes, contains exactly eight to eleven
`.claude/agents/*.md` entries plus three protocol documents. It contains
**zero hook scripts**. `runUpdate()` (`bin/cli.js:827-1132`) touches
`hooks` only to *strip* duplicate registrations under `--dedupe-hooks`; it
never copies a script file and never merges a registration.

**Measured consequence (live experiment, scratch fixture):** a project
scaffolded from the current plugin, then mutated to look like a
pre-`human-decision-gate` install — the three newest files deleted and
`stop-gate.sh` overwritten with the literal text `STALE` — was run through
`node bin/cli.js --update`. The command reported nine persona files
"already current", one "updated", one "created", exited on an unrelated
explorer-placeholder note, and left **every one of the four mutations
untouched**: the three deleted files were not restored, and `stop-gate.sh`
still read `STALE`.

**The registration half fails identically.** A second fixture had the
`human-decision-gate.sh` and `microworld-rerun.sh` entries stripped from its
`.claude/settings.json`. Before `--update`: zero occurrences of
`human-decision-gate` in settings.json. After `--update`: still zero. So
even a hand-copied script would sit inert.

**Scaffold is not affected.** A fresh `node bin/cli.js --yes` into an empty
repo delivered all 14 files including `human-decision-gate.sh` and
`lib/benign-command.sh`, via the unconditional
`copyDirRecursive(PKG_ROOT/hooks/scripts, …)` at `bin/cli.js:2007`, and (with
`--force-hooks`) registered all 11 registered scripts. The bug is
exclusively on the *upgrade* path. `--overwrite` also re-copies correctly —
but see Risks: using `--overwrite` as the propagation mechanism is what
produced the gh308 FAIL.

**Full blast radius — 7 of 14 files, not 3.** `diff -rq hooks/scripts
.claude/hooks/scripts` on this repo exits 1 with:

| file | mirror state |
|---|---|
| `human-decision-gate.sh` | **missing** |
| `microworld-rerun.sh` | **missing** |
| `lib/benign-command.sh` | **missing** |
| `dispatch-hygiene.sh` | diverged |
| `reviewed-path-gate.sh` | diverged (16428 B on disk vs 7987 B packaged) |
| `reviewer-route-gate.sh` | diverged |
| `stop-gate.sh` | diverged |
| the other 7 | byte-identical |

The four diverged files are the more serious half of the finding: they are
not merely old, they predate landed security fixes (gh274, gh277, gh278-279,
gh307 all touched gates in this set). A standalone install is therefore
frozen at its scaffold-time gate versions **forever**, receiving neither new
gates nor patches to existing ones, while `--update` truthfully reports its
persona files are current.

**Security consequence, stated precisely.** In a standalone-mode install,
`human-decision-gate.sh` is the only mechanism preventing any agent identity
— reviewer included — from writing
`.claude/human-review/<task-id>/DECISION`, the human's exclusive channel for
resolving an `ESCALATE-TO-HUMAN` verdict. Absent that gate and its
registration, the DECISION file is writable by any agent, and the
human-in-the-loop escalation feature is defeated for that install.

**Scope boundary — adapters are a different thing and stay out.** Neither
`adapters/cursor/hooks/scripts/` nor `adapters/codex/hooks/scripts/`
contains `human-decision-gate.sh`; both also lack `reviewed-path-gate.sh`,
`dispatch-hygiene.sh`, `task-gate.sh`, and `reviewer-tier.sh`. That is the
deliberate no-adapter-port precedent documented in
`hooks/scripts/human-decision-gate.sh:9-11`, not this defect. Separately,
Cursor/Codex have no `--update` path at all (`main()` routes `--update`
before `--target=`, so `--target=cursor --update` runs the Claude updater);
their only resync is `--target=cursor --overwrite`, which does re-copy
scripts. Reported, not fixed here.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-12 User interaction flow: Q When `--update` finds a hook script
  missing versus locally modified, should it behave the same way? → A
  (self-resolved): no — an absent file has no user edit to protect, so it is
  created unconditionally and silently; a *present but differing* file goes
  through the existing divergence flow. This split matters because it means
  the named security gap (an absent `human-decision-gate.sh`) closes under
  either answer to Open Question 1.
- 2026-08-12 Edge cases / failure handling: Q What happens on the first
  `--update` after this change, when no hook script has ever had a
  `fileHashes` entry recorded? → A (self-resolved): the existing
  `backfillFileHashesFromDisk` bootstrap records the on-disk hash as the
  clean baseline, so a stale-but-unmodified script compares equal to its own
  recorded hash, is correctly judged "no local edits", and is refreshed. This
  is the same one-time bootstrap the CLI already warns about for personas;
  no new mechanism is needed. See Risks R-3 for the residual hazard.
- 2026-08-12 Edge cases / failure handling: Q Must registration backfill
  respect the marketplace-plugin guard? → A (self-resolved): yes,
  unconditionally. This repo itself is plugin-mode; a `--update` here that
  merged registrations would double-register every hook and reproduce the
  "Ran 2 stop hooks" defect that the existing guard (`detectMarketplacePlugin`,
  `bin/cli.js:1485`) was built to prevent. Encoded as an adversarial
  criterion (AC1.5), not left to reviewer judgment.
- 2026-08-12 Technical constraints & tradeoffs: Q Should the fix be "make
  `--update` copy hooks" or "document that users must run `--overwrite`"? →
  A (self-resolved): the former. Constitution P2 mandates deterministic
  scripts over re-derivation, `/antislop:update-antislop` runs `--update`
  and never `--overwrite`, and the `.claude/reviewed/gh308.fail` record
  documents that propagating via `--overwrite` skipped the `fileHashes`
  bookkeeping `--update` performs and left the tree in a state where
  `--update` exited 2 on a non-existent difference.
- 2026-08-12 Terminology consistency: Q Do "standalone mode" and "plugin
  mode" have canonical glossary entries? → A (self-resolved): no. Both are
  load-bearing throughout this plan and neither appears in `CONTEXT.md`.
  Flagged for `scribe` under Scribe update hint; not blocking.

## Risks / dependencies

- **R-1 — the registration guard is the highest-risk surface.** Getting
  AC1.5 wrong turns a security fix into a double-fire regression across every
  plugin-mode install. The guard already exists and is correct; the
  requirement is to *reuse* `detectMarketplacePlugin` verbatim, not to write
  a second detector.
- **R-2 — Unit 2 depends on Unit 1.** The mirror must be regenerated by
  running the fixed `node bin/cli.js --update`, not by `cp` and not by
  `--overwrite` (see gh308 above). Unit 2 cannot start until Unit 1 lands.
- **R-3 — first-run bootstrap can mask a genuine local edit.** If a
  standalone project hand-edited a hook script before this change, the
  one-time `fileHashes` backfill records that edited content as the clean
  baseline and the file is then overwritten with the packaged version without
  a divergence prompt. This is unavoidable — no prior hash exists to compare
  against — and is the same caveat the CLI already prints for personas. The
  fix must print an equivalent one-time note naming the hook-script paths.
- **R-4 — `tests/validate.sh` is the merge gate (Constitution P5).** Unit 2
  adds a parity check to it. If the check landed while the mirror were still
  stale, validate.sh would go RED and block all merges. Regeneration and the
  new check must therefore land in the **same** unit — this is the
  "don't gate a source edit apart from its shipped copy" rule.
- **R-5 — do not use the `--update --check | grep` drift idiom.** It is
  known-broken in this repo (it detects nothing) and `--check` is a
  force-the-loop control that still writes, per `CONTEXT.md`'s "`--update`
  semantics" entry. Idempotence (`--update` twice, second run leaves the
  tree clean) is the criterion shape to use instead.
- **Prior defect history.** 47 `.fail` records exist. Four bear directly on
  this area: **gh308** (propagation via `--overwrite` skipped `fileHashes`
  bookkeeping and left `--update` exiting 2 on a phantom difference — the
  single most relevant precedent), **gh315** (a version bump that did not
  restamp mirrors), **gh309** (a corrupted template faithfully propagated to
  every mirror), and **gh307** (a defect reviewed *at* the
  `.claude/hooks/scripts/` mirror path, confirming the mirror is treated as
  reviewable shipped code). Neither unit below is `haiku`-eligible: both
  touch `bin/cli.js` and a security gate, and the propagation path has
  already produced one FAIL.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim in Context was measured
  live in scratch fixtures this session, and both acceptance-criteria
  families were executed and confirmed RED before being written down.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  entire fix moves work *into* `--update`'s deterministic path, and Unit 2
  forbids hand-copying the mirror.
- P3 "Version-stamp discipline": satisfied — Unit 1 requires a
  `.claude-plugin/plugin.json` + `package.json` bump and a CHANGELOG entry.
  Note hook scripts are **not** version-stamped files (verified: no
  `antislop v` stamp in any `hooks/scripts/*.sh`); they are tracked by
  content hash only, so no stamp-insertion logic is added.
- P4 "Optional personas degrade gracefully": satisfied — no persona prose
  changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied — both units
  terminate in `bash tests/validate.sh` exiting 0, and Unit 2 strengthens it.

## Step 1 — teach `--update` to propagate hook scripts and registrations

**Affected files:** `bin/cli.js` (`buildFileSpecs`/`runUpdate` and the
registration merge), `tests/cli-hook-propagation.test.js` (new),
`tests/validate.sh` (wire the new test in), `.claude-plugin/plugin.json`,
`package.json`, `CHANGELOG.md`.

**Acceptance criteria**

- AC1.1 `node tests/cli-hook-propagation.test.js` exits 0.
- AC1.2 (RED today) That test scaffolds a temp project, deletes
  `.claude/hooks/scripts/human-decision-gate.sh` and
  `.claude/hooks/scripts/lib/benign-command.sh`, runs `bin/cli.js --update`,
  and asserts both files exist and are byte-identical to their
  `hooks/scripts/` originals.
- AC1.3 (RED today) The test asserts that after `--update`, **every** path
  under `hooks/scripts/**` (including `lib/`) exists in the temp project's
  `.claude/hooks/scripts/` and is byte-identical — enumerated from the
  packaged directory at runtime, never a hardcoded list, so a future hook
  is covered without editing the test.
- AC1.4 (RED today) Registration backfill: with the marketplace plugin **not**
  detected, a temp project whose `.claude/settings.json` has had the
  `human-decision-gate.sh` and `microworld-rerun.sh` entries stripped
  regains both after `--update`.
- AC1.5 (adversarial, guard) With the marketplace plugin detected as
  **enabled**, `--update` adds zero hook registrations: the `hooks` key of
  `.claude/settings.json` is byte-identical before and after.
- AC1.6 (adversarial, local edit — see Open Question 1) A hook script that is
  present, differs from the packaged version, **and** whose recorded
  `fileHashes` entry differs from its on-disk hash is not silently
  overwritten; `--update` reports it as diverged and exits non-zero, and
  `--accept=<path>` overwrites it while `--keep=<path>` preserves it.
- AC1.7 The one-time bootstrap note (R-3) is printed when a hook script has
  no recorded `fileHashes` entry, and names hook-script paths specifically.
  Asserted on the command's stdout.
- AC1.8 `bash tests/validate.sh` exits 0 and its output contains a line
  naming `tests/cli-hook-propagation.test.js`.
- AC1.9 `.claude-plugin/plugin.json` and `package.json` carry a version
  greater than `0.31.25`, and `CHANGELOG.md`'s top entry names that version.

## Step 2 — restore this repo's mirror and gate it in `tests/validate.sh`

**Affected files:** `.claude/hooks/scripts/**` (regenerated: 3 created, 4
updated), `.claude/persona-config.json` (`fileHashes`), `tests/validate.sh`.

**Acceptance criteria**

- AC2.1 (RED today — exits 1 with 3 "Only in" and 4 "differ" lines)
  `diff -rq hooks/scripts .claude/hooks/scripts` exits 0.
- AC2.2 (mutation proof) `tests/validate.sh` contains a check that runs that
  comparison and fails the gate on divergence: deleting any one file under
  `.claude/hooks/scripts/` makes `bash tests/validate.sh` exit non-zero, and
  restoring it makes it exit 0 again. The unit's report must state which file
  was deleted for this proof.
- AC2.3 `bash tests/validate.sh` exits 0 on the fixed tree.
- AC2.4 (bookkeeping, per gh308) The mirror was regenerated by running
  `node bin/cli.js --update`; running it a **second** time afterwards leaves
  `git status --porcelain .claude/hooks/scripts/ .claude/persona-config.json`
  empty (idempotence). Do not substitute the known-broken
  `--update --check | grep` drift idiom.

## Open Questions

1. **Should a locally-modified hook script block a security patch?**
   AC1.6 encodes the recommended default — treat hook scripts exactly like
   persona files: a genuine local edit causes `--update` to report divergence
   and exit non-zero until the user passes `--accept=` or `--keep=`. This is
   consistent with the existing contract and with Constitution P2.
   The alternative is that hook scripts are *safety infrastructure* and
   should be refreshed unconditionally, on the argument that a user's local
   edit must never be able to hold back a security fix. Note the stakes are
   bounded: under either answer, an **absent** gate is created
   unconditionally, so the reported `human-decision-gate.sh` gap closes
   regardless. Only the four already-diverged files are affected by the
   choice. Recommended default: as written in AC1.6 (respect local edits).
2. **Should the four diverged files in this repo's mirror be re-reviewed as
   shipped code?** `.claude/reviewed/gh307.fail` recorded defects *at* the
   mirror path, which suggests the mirror is treated as reviewable shipped
   code rather than a generated artifact. Recommended default: no — Unit 2
   regenerates them mechanically from already-reviewed sources via
   `--update`, so the content was reviewed at its source path; re-reviewing
   the mirror would be reviewing a copy.

## Self-check

- CHK1: Is the difference between "missing file" and "diverged file"
  behaviour defined for `--update`? — PASS (Clarifications line 1 and AC1.6
  together define both).
- CHK2: Do Step 1 and Step 2 agree on how the mirror is regenerated? — PASS
  (both say `bin/cli.js --update`; Step 2 AC2.4 forbids the alternatives).
- CHK3: Is every acceptance criterion runnable and pass/fail? — PASS (each is
  a command exit code, a byte comparison, or an asserted stdout line).
- CHK4: Is the claim "these criteria are RED today" verified rather than
  asserted? — PASS (AC1.2, AC1.3, AC1.4 and AC2.1 were each executed this
  session; their observed failing output is quoted in Context).
- CHK5: Does the plan say what happens on the very first `--update` when no
  hook script has a recorded hash? — FAIL (missing) — revised in place
  (Clarifications line 2, R-3, and AC1.7 added).
- CHK6: Does the plan prevent the new parity gate from turning
  `tests/validate.sh` RED at merge time? — FAIL (missing) — revised in place
  (R-4 added; regeneration and the check are bound into one unit).
- CHK7: Does the plan address whether the fix could double-register hooks in
  a plugin-mode project like this repo? — FAIL (missing) — revised in place
  (AC1.5 added as an adversarial criterion, R-1 added).
- CHK8: Is the adapter scope boundary stated so a reader cannot conflate the
  standalone gap with the no-adapter-port precedent? — PASS (Context's final
  paragraph, citing `human-decision-gate.sh:9-11`).
- CHK9: Does the plan avoid the known-broken drift-check idiom? — PASS (R-5
  names it and AC2.4 forbids it).
- CHK10: Is P3 satisfiable given hook scripts carry no version stamp? — FAIL
  (ambiguous) — revised in place (the Constitution check now states hook
  scripts are hash-tracked, not stamped, and no stamp logic is added).

## Scribe update hint

`CONTEXT.md` needs three touches once this lands: (a) add glossary entries
for **standalone mode** and **plugin mode**, neither of which is defined
today despite both being load-bearing; (b) widen the **`--update`
semantics** entry, which currently scopes `--update` to "refreshing
ADAPT-stamped files" — after this change it also refreshes unstamped,
hash-tracked hook scripts and backfills hook registrations; (c) note under
**Version-stamped file** that hook scripts are deliberately *not* stamped
and are tracked by content hash instead. Terminology used consistently
throughout this plan: **mirror** (not "shipped copy"), **gate**, **reporter**.
