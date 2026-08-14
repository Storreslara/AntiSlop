# `bin/cli.js --update` flag surface: additive `--personas=` (#289) and an honest write/no-write split (#291)

Date: 2026-08-11
Issues: Storreslara/AntiSlop#289 (enhancement), Storreslara/AntiSlop#291 (bug)
Author: spec-master

## Goal

Close two defects in `bin/cli.js`'s `--update` command-line surface, together,
because they touch adjacent argument-parsing code in the same high-risk file:

1. **#289** — give `--update` a CLI-native, *additive* way to add a
   newly-registered optional persona to an already-adapted project, so nobody
   has to hand-edit `personaSelection` (which this repo's own constitution P2
   forbids) or reach for `--overwrite --personas=` (replacement semantics that
   can silently drop an already-selected persona).
2. **#291** — make the `--update` flag surface honest about which flags write.
   Add a genuine no-write `--dry-run`, rename today's misleadingly-named
   `--check` to `--force-render`, and keep `--check` working as a deprecated
   alias that loudly says it writes.

Every Goal clause maps to a step criterion: clause 1 → Step 1 (C1.3–C1.12);
clause 2's dry-run → Step 2 (C2.3–C2.6, C2.10–C2.12); clause 2's rename →
Step 2 (C2.7–C2.9); clause 2's "honest" documentation surface → Step 3
(C3.2–C3.3, C3.6).

## Context

Line numbers below are as measured at 2026-08-11 against `bin/cli.js`
(2205 lines). This file changes often — **re-locate by content, not by
number**, before editing.

**The `--update` path.** `main()` (`bin/cli.js:1814`) routes on
`args.includes('--update')` at `bin/cli.js:1817` and returns `runUpdate(args)`
(`bin/cli.js:827`) *before* the scaffold path ever parses its own flags. That
single fact answers issue #289's "does this interact with `--overwrite`?"
question: **no.** `--overwrite` is parsed only at `bin/cli.js:1263` (cursor),
`:1663` (codex) and `:1845` (claude scaffold), all downstream of the
`--update` early return. The two flags are orthogonal and there is no
interaction to design.

**How a persona addition actually reaches disk.** `runUpdate` reads
`config.personaSelection` (`bin/cli.js:874`), migrates legacy tokens
(`:877`), and passes the result to `buildFileSpecs` (`:908`). `buildFileSpecs`
(`:452`) intersects the selection with `OPTIONAL_PERSONAS` (`:26`) and appends
a `researcher` spec when selected. The render loop's `!fs.existsSync` branch
(`:1034`) then *creates* any missing managed destination. Verified against the
scaffold path (`:1971`–`:1986`): adding a persona involves **no** per-persona
work beyond copying its `.claude/agents/<name>.md` — settings.json, hooks,
skills and `.gitignore` are all persona-independent. So expanding
`personaSelection` before `buildFileSpecs` is a *complete* addition, and the
pre-scan at `:987` will set `needsRender = true` for the new file, so the
version-match fast path at `:1005` will not wrongly bail out.

**Why `--check` is not a dry-run.** `checkFlag` (`bin/cli.js:975`) appears in
exactly one expression — the fast-path condition at `:1005`. The render loop
never consults it, so once the loop runs it writes exactly like a plain
`--update`. This is already documented as a known gotcha in `CONTEXT.md:39-49`
("the `--check` flag is a force-the-loop control, not a dry-run"), which is
itself evidence the name has been confusing people for a while. The incident
in #291 (a lead-programmer session writing `.claude/agents/orchestrator.md`
under the old version stamp while believing it was investigating read-only) is
the documented consequence.

**Complete write-site inventory on the `--update` path** — a `--dry-run` that
misses one of these is worse than no `--dry-run` at all:

> **Revised 2026-08-14 (gh338 escalation, finding F-A).** This table was
> measured at 2026-08-11 and listed **eleven** sites. Commit `d1f232f`
> (2026-08-13, "propagate hook scripts and registrations on --update") added a
> **twelfth** — site 12 below — two days after the measurement. The
> 2026-08-11 numbers had also drifted by ~+140 lines, so the live column is
> re-measured against `bin/cli.js` at v0.31.49. Re-locate by the anchor text,
> never by either number.

| # | 2026-08-11 | Live 2026-08-14 | Anchor text | Write |
|---|---|---|---|---|
| 1 | `:882` | `:1025` | `if (fs.existsSync(legacyPath)) fs.unlinkSync(legacyPath)` | deletes a legacy persona's agent file |
| 2 | `:886` | `:1029` | `const migratedClaudeMd = migrateGlobalProtocolImport(CWD)` | rewrites `CLAUDE.md` |
| 3 | `:894` | `:1037` | first `appendUnique(path.join(CWD, '.gitignore'), …)` | appends dispatch-hygiene entries |
| 4 | `:902` | `:1045` | second `appendUnique(path.join(CWD, '.gitignore'), …)` | appends microworld/human-review entries |
| 5 | `:948` | `:1107` | `fs.writeFileSync(settingsPath, JSON.stringify(cleaned, …))` | strips standalone hook registrations — only under `--dedupe-hooks` |
| 6 | `:1035` | `:1231` | `writeSpecBody(…)` in the `!fs.existsSync` branch | render loop — `created` |
| 7 | `:1049` | `:1245` | `copyStampedBody(…)` in the stamp branch | render loop — `stamp refreshed` |
| 8 | `:1061` | `:1257` | `writeSpecBody(…)` in the `noLocalEdits` branch | render loop — `updated (no local edits detected)` |
| 9 | `:1068` | `:1273` | `writeSpecBody(…)` in the `acceptAll \|\| acceptList` branch | render loop — `overwritten (--accept)` |
| 10 | `:1098` | `:1303` | `fs.writeFileSync(configPath, …)` in the `pending \|\| unresolvedRender` branch | rewrites `persona-config.json` |
| 11 | `:1117` | `:1322` | `fs.writeFileSync(configPath, …)` on the success path | rewrites `persona-config.json` (+ `pluginVersion`) |
| **12** | *(did not exist)* | **`:1139`** | `fs.writeFileSync(settingsPath, JSON.stringify(merged, …))` inside `if (settings && !pluginState.enabled)` (`:1136-1148`) | **hook-registration backfill** — merges missing packaged hook registrations into `.claude/settings.json` |

**Site 12 is not an edge case.** It fires on a **bare `--update`, no flags**,
on any standalone project that has a `.claude/settings.json` and is missing a
packaged hook registration. Measured 2026-08-14 on a throwaway fixture: it
grew `.claude/settings.json` from 3 bytes (`{}`) to **2669 bytes**, printing
`added 14 missing antislop hook registration(s)`, **and the run still exited
`0`**. Two conditions skip it — `settings` being null (no
`.claude/settings.json` on disk at all) and `pluginState.enabled` — and both
are load-bearing for the fixture shape; see C2.13.

Note also a render-loop summary shape the 2026-08-11 vocabulary list missed:
`hash healed (content unchanged, hash was stale)` (`:1267`). It writes no
file, but it *does* mutate `newFileHashes`, which sites 10/11 then persist —
so it is a would-be mutation of `persona-config.json` and must be reported and
counted like one.

Two of these helpers *compute the answer as a side effect of writing it*:
`appendUnique` (`:151`) returns early when nothing is missing, and
`migrateGlobalProtocolImport` (`:817`) returns `false` when there is nothing
to strip — and its return value feeds `migratedClaudeMd` into the fast-path
condition at `:1005`. A naive `if (!dryRun)` wrapped around either call
silently drops both the write **and** the report line. Each needs a
no-write variant that still returns what it *would* have done.

**Every one of the twelve has a cheap no-write predicate** — this was checked
site by site on 2026-08-14, because the exit-code rule below is only
implementable if it is true. Sites 5 and 12 already compute their answer
non-destructively before writing (`stripStandaloneHookRegistrations` and
`mergeNestedHooksJson` both build a new object and compare, at `:1106` and
`:1137-1138`), so only the `writeFileSync` needs suppressing. Site 1's
predicate is the `fs.existsSync(legacyPath)` already guarding it. Sites 10/11
reduce to `JSON.stringify(config, null, 2) + '\n' !== <current file bytes>`.
Sites 2, 3 and 4 are the two helpers named above. Sites 6-9 are the render
loop, which already computes `cleanHash` before deciding. No site requires a
speculative write to learn its own answer.

**The exit-code contract as first drafted is not honest — measured, not
inferred (finding F-B, 2026-08-14).** Behaviour item 7 originally read "`0`
nothing would change; `3` at least one file would be created/updated/
stamp-refreshed or would be pending a decision". Those four outcomes are
*render-loop* outcomes (sites 6-9 plus `pending`). **Eight of the twelve sites
cannot produce any of them**, so a literal implementation exits `0` — "nothing
would change" — while the live run writes. Two throwaway fixtures, measured
2026-08-14 with `HOME` isolated:

| Fixture | Live `--update` mutated | Non-`already current` summary lines | Live exit code |
|---|---|---|---|
| baseline with three `fileHashes` entries dropped, `.gitignore` pre-populated | `.claude/persona-config.json` **only** | 0 | **0** |
| baseline with an empty `.claude/settings.json`, marketplace plugin disabled | `.claude/settings.json` (3 → 2669 bytes) | 0 in the render summary | **0** |

A genuinely-current baseline (hashes intact, `.gitignore` present, no
`.claude/settings.json`) was measured in the same session at exit `0` with a
whole-tree snapshot **unchanged** — under both plain `--update` and `--check`
— so tightening the rule does not cost the "genuinely current → 0" row that
C2.12 pins. That is what makes the reformulation in behaviour item 7 safe as
well as correct.

**Blast radius of renaming `--check`** (measured repo-wide, 2026-08-11):
`bin/cli.js:975`; six call sites in `tests/cli-backfill.test.js` (`:860`,
`:871`, `:882`, `:897`, `:1022`, `:1086`, `:1116`); and the `CONTEXT.md:39-49`
glossary entry. **Zero** references in `agents/`, `templates/`, `adapters/`,
`commands/`, `skills/`, `.claude/agents/`, `hooks/`, or `.github/workflows/`.
Historical `docs/plans/*.md` and `.claude/agent-memory/*` also mention it;
those are dated records and are explicitly not to be rewritten.
`scripts/resync-vendored-skills.sh --check` is an unrelated, genuinely
read-only flag on a different script and is out of scope.

**A genuine `--dry-run` closes a verification gap this repo already measured
and could not close.** `docs/plans/2026-08-09-agent-auditor-persona.md:1454-1493`
(finding F2, 2026-08-09) established that the drift-check idiom
`! node bin/cli.js --update --check 2>&1 | grep -qE ': (updated|created|pending)$'`
"cannot detect what it claims to detect" — the anchored regex matches exactly
one of six emitted summary shapes, and the pipe discards the exit code. F2 then
*corrected the audit's own proposed remedy*: a bare exit-code check would not
work either, measured on a throwaway clone. Its table:

| Drift shape | real exit code | broken grep form | bare exit-code check | exit code **and** post-run tree clean |
|---|---|---|---|---|
| none (genuinely current) | 0 | GREEN | GREEN | **GREEN** (correct) |
| A — source edited, mirror stale (**the #291 shape**) | **0** | GREEN | **GREEN** | **RED** (correct) |
| B — mirror carries local edits | **2** | GREEN | RED | **RED** (correct) |

Shape A goes undetected by every single-signal check precisely *because*
`--check` is not a dry run: it silently self-heals the drift it was asked to
report, then exits 0. F2's only correct verification needs two signals (exit
code **and** a post-run working-tree assertion).

`--dry-run`'s exit-code contract collapses that back to one signal, because the
tree is guaranteed clean by construction: shape A renders as "would be updated"
→ exit 3 (RED, correct); shape B renders as "would be pending a decision" →
exit 3 (RED, correct); baseline → exit 0 (GREEN, correct). This is not a
side benefit — it is a second, independently-measured justification for
choosing the dry run over a rename alone, and Step 2's C2.12 pins the table.

**Existing test seam.** `tests/cli-backfill.test.js` (2164 lines) already
spawns the real `node bin/cli.js --update` as a subprocess against throwaway
temp projects (helper at `:1065` returns `{ tmp, git, porcelain, cli }`).
That is the highest existing seam and the right one for all new tests — no new
seam is proposed. The suite is run from `tests/validate.sh:396`;
`persona-config.json`'s `testAndLintCommand` is `bash tests/validate.sh`.

**R2 risk record.** 21 of the 47 `.fail` records under `.claude/reviewed/`
mention `bin/cli.js` (the issue cites 12; the record has grown since filing).
Two failure modes from that record shape this plan directly:

- **`191.fail`** — a change threaded into the `--update` render path but not
  the fresh-scaffold path made the two paths emit different bodies for
  identical inputs. Both units here touch the `--update` path only; the
  scaffold path's *replacement* `--personas=` semantics (`bin/cli.js:1891-1899`)
  must stay exactly as they are, and C1.11 pins that behaviorally.
- **`gh308.fail`** — a commit regenerated two mirrors without updating their
  `fileHashes` entries in `.claude/persona-config.json`, leaving every
  downstream `--update` exiting 2 on a non-existent difference. Step 3 bumps
  the plugin version, which restamps every mirror; C3.5 pins the
  regenerate-and-commit dance that `gh308` skipped.

`tests/reviewer-tier.test.sh:102` already routes any diff touching
`^bin/cli\.js$` to an **opus** reviewer, so Steps 1 and 2 get the strongest
available review automatically.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-11 Functional scope & success criteria: Q Issue #291 offers two
  directions (genuine dry-run, or rename). Which, and is a rename allowed to
  break existing callers? → A (self-resolved): **both**, in one unit — a
  genuine `--dry-run` supplies the missing capability, and `--force-render`
  supplies the honest name; `--check` survives as a warning-emitting
  deprecated alias so nothing breaks. Full reasoning under "Recommendation
  for #291" below. The residual fork — deprecate-with-alias vs. hard-refuse —
  is Open Question 1, and Step 2's dispatch is gated on it.
- 2026-08-11 Domain entities / data model: Q What exactly is the union
  operand set, and in what order is the result written? → A (self-resolved):
  the valid token set is `OPTIONAL_PERSONAS ∪ {researcher} ∪ CORE_PERSONAS`;
  only the first two are recordable in `personaSelection` (core personas are
  always installed and are accepted as no-ops). The union result preserves the
  recorded selection's existing order and appends newly-added entries in
  `OPTIONAL_PERSONAS` declaration order with `researcher` last, so repeated
  runs produce a byte-stable `persona-config.json` diff.
- 2026-08-11 User interaction flow: Q What does `--dry-run` print, and what
  does it exit with? → A (self-resolved): the same per-file vocabulary as a
  live run but in the conditional voice (`would be created`, `would be
  updated`, `stamp would be refreshed`, `already current`), specifically so
  the repo's established drift-check idiom `grep -qE ': (updated|created|pending)$'`
  cannot false-positive on dry-run output. Exit codes: `0` nothing would
  change, `3` something would change, `1` a file could not be rendered. `3` is
  chosen because `0`/`1`/`2` are all already load-bearing in `runUpdate`
  (`bin/cli.js:1112`) and overloading `2` ("pending, needs `--accept`/`--keep`")
  would re-create exactly the semantic-overload problem #291 is about.
- 2026-08-11 Edge cases / failure handling: Q What happens on an unknown
  persona name, an empty `--personas=`, a core-persona name, a legacy token,
  and `--personas=researcher` with no arXiv launch command recorded? → A
  (self-resolved): unknown → exit 1 with the offending token(s) and the full
  valid set, **having written nothing** (validation is hoisted ahead of the
  first write at `bin/cli.js:882`, mirroring the downgrade guard's own
  "must sit ahead of any file write" discipline at `:847-848`); empty →
  exit 1 the same way (a typo must not degrade into a silent no-op);
  core-persona name → accepted, no-op, informational note, not recorded;
  legacy token → migrated first via `migrateLegacyPersonaTokens`, *then*
  validated, *then* unioned; `researcher` with no `substitutions.arxivMcpLaunch`
  → **superseded, see the 2026-08-14 correction below**; `personaSelection`
  *does* record the addition (matching how `hadLegacyToken` already mutates
  the config at `:879` and relies on the same later write).
- 2026-08-14 Edge cases / failure handling **(correction — supersedes the
  final clause of the 2026-08-11 entry above)**: Q What actually happens on
  `--personas=researcher` with no `substitutions.arxivMcpLaunch` recorded?
  → A (self-resolved, verified live against `bin/cli.js` and against two
  already-passing tests): the 2026-08-11 answer was **wrong**. It assumed an
  `unresolvedRender` refusal path that does not exist for the `arxiv` file
  kind. `renderCleanBody`'s `arxiv` branch tests the launch command for
  `null` *or* `undefined` and, in either case, delegates to
  `applyArxivFallback`, which **succeeds**: it strips the `mcpServers:`
  block and inserts the note `<!-- No working arXiv MCP found at ADAPT time
  — operating in WebFetch/WebSearch fallback mode. -->`. `researcher.md` is
  therefore **written**, and `--update` exits **0**. The refusal via
  `applyMcpPlaceholder`'s throw is reachable only for the `graph` kind
  (`explorer.md`, missing `graphMcpLaunch`) — never for `arxiv`, because the
  fallback branch intercepts first. This is deliberate, not a bug: the arXiv
  MCP is optional at ADAPT time, `researcher` degrades to its `WebFetch`/
  `WebSearch` tools, and `tests/cli-backfill.test.js:51` and `:1320` both
  pass `arxivMcpLaunch: null` and already require a successful render. The
  spec is corrected to match the code; the code is **not** to be changed to
  match the spec. Verified 2026-08-14 by direct `renderCleanBody` calls
  (missing key, explicit `null`, and absent `substitutions` — all three
  render) and by an end-to-end `--update` run on a temp project.
- 2026-08-14 Edge cases / failure handling **(correction, second pass —
  propagates the entry above into Step 2)**: Q Did the same wrong assumption
  reach any other criterion, and what fixture *does* produce exit `1`?
  → A (self-resolved, verified live): yes — **C2.5**'s third exit-code clause
  carried the identical stale premise and is corrected in place to require a
  missing `graphMcpLaunch`. Two temp projects measured end-to-end: one with
  `graphMcpLaunch` recorded and `arxivMcpLaunch` absent exits **0** (first
  pass and under `--check`), rendering `researcher.md` in fallback mode with
  no `^mcpServers:` line; one freshly scaffolded with neither key exits **1**
  naming `.claude/agents/explorer.md` as the single unrendered file. A third
  measurement found a trap not previously recorded: deleting `graphMcpLaunch`
  from an *already-wired* project does **not** reproduce exit `1`, because
  `backfillSubstitutionsFromDisk` re-derives it from the rendered
  `explorer.md`; that constraint is now pinned in C2.5's fixture
  requirement. Step 2's behaviour item 7 and the Context line stating "`1` a
  file could not be rendered" are generically true and unchanged.
- 2026-08-14 Functional scope & success criteria **(gh338 escalation, finding
  F-B — the substantive semantic ruling of this revision)**: Q Should
  `--dry-run` exit `3` on **any** would-be write, or only on the four
  render-loop outcomes the original rule enumerated? → A (self-resolved):
  **exit `3` on any of the twelve sites; exit `0` if and only if a live run
  would leave the tree byte- and mode-identical.** Reasoning, recorded because
  this is a real semantic decision and not a mechanical fix: (1) exit `0` is
  the signal CI greps, so an exit `0` that coexists with a live write
  reproduces `--check`'s exact dishonesty and defeats the unit's purpose;
  (2) the Context section already promised a *single-signal* contract, which
  is only sound as a biconditional; (3) the enumerated form contradicted C2.3,
  which already asserts over the whole tree, three bullets above it; (4) an
  enumerated rule makes every future write site invisible to exit `0` by
  default — precisely how site 12 went unnoticed — whereas a site-agnostic
  rule fails safe as `bin/cli.js` grows. Implementability was verified rather
  than assumed (all twelve have a cheap non-destructive predicate), and the
  "genuinely current → 0" row was measured to survive the tightening.
- 2026-08-14 Edge cases / failure handling **(gh338 escalation, finding
  F-A)**: Q How should the twelfth write site — the hook-registration backfill
  added by `d1f232f` after this inventory was measured — be covered? → A
  (self-resolved): as a first-class inventory entry with its own no-write
  treatment (behaviour item 9) and its own criterion (C2.13), whose fixture
  shape is **prescriptive**, because the obvious fixture is vacuous. Measured
  2026-08-14: with an ambient `HOME` the marketplace plugin reads as enabled,
  the branch is skipped, and the test passes without reaching site 12 at all.
  C2.13 therefore mandates `HOME` isolation, an explicitly disabled plugin, a
  present `.claude/settings.json`, **and** a live-run mutation control.
- 2026-08-14 Non-functional attributes **(gh338 escalation, finding F-D)**:
  Q Should the mode-aware snapshot helper be folded into this unit, deferred
  to the #273 exec-bit spec, or ruled out of scope? → A (self-resolved):
  **folded in, at C2.3.** The change is confined to a test helper this step
  already owns and modifies — no production code, no new seam. #273 answers a
  different question (*is the shipped mode correct?* versus *did the mode
  change?*) and is still in flight, so deferring would block this step on
  another spec or ship C2.3 blind to `writeSpecBody`'s `chmodSync` and to
  `mkdirp`'s empty directories. C2.15 guards Step 1's three existing call
  sites.
- 2026-08-14 Technical constraints & tradeoffs **(gh338 escalation, finding
  F-E)**: Q Should `printUnifiedDiff`'s two `os.tmpdir()` writes be suppressed
  under `--dry-run`? → A (self-resolved): **no — keep as-is.** They are
  outside the project root, are cleaned up by the function itself, and produce
  the diff that *is* the pending report. Behaviour item 3 is rescoped from
  "zero writes anywhere" to "zero writes under the project root" so this is a
  stated scope boundary rather than an unstated exception to an absolute
  claim.
- 2026-08-11 Technical constraints & tradeoffs: Q Does adding a persona to
  `personaSelection` require any work beyond creating its agent file? → A
  (self-resolved): no — verified against the scaffold path at
  `bin/cli.js:1971-1986`; every other scaffold artifact is persona-independent.
- 2026-08-11 Terminology consistency: Q Does this spec's vocabulary agree with
  `CONTEXT.md`'s `## Language` glossary? → A (self-resolved): partially, and
  the gaps are Step 3's deliverable. Lens 1 (glossary term used with a
  different meaning): `CONTEXT.md:41` currently defines `--check` as "a
  force-the-loop control, not a dry-run" — Step 2 deliberately falsifies that
  sentence, which is why Step 3 exists rather than being optional polish.
  Lens 2 (new synonym for a defined term): none introduced — `personaSelection`
  is used throughout as the canonical field name, never "persona list" or
  "selection list", and `--force-render` is named as the flag for the
  already-defined "force-the-loop control" concept rather than as a rival
  concept. Lens 3 (load-bearing new term with no entry): two — a `--update`
  **dry-run**, and `--update --personas=` **additive-union** semantics. Both
  are routed to `scribe` in Step 3 (C3.3). Advisory only; nothing here blocks
  handoff.
- 2026-08-11 Completion / acceptance signals: Q What is the merge gate? → A
  (self-resolved): `bash tests/validate.sh` exit 0, per
  `.claude/persona-config.json`'s `testAndLintCommand` and constitution P5.
  It runs `tests/cli-backfill.test.js` at `tests/validate.sh:396`.

### Recommendation for #291 (stated explicitly, per the request)

**Do both, in one unit: add `--dry-run`, rename `--check` → `--force-render`,
and keep `--check` as a deprecated alias that warns.** Reasoning:

- *A dry-run alone is not enough.* It supplies the missing capability but
  leaves the misleading name in place. The next investigator types `--check`,
  because that is still the flag that sounds read-only, and the #291 incident
  repeats with a safe alternative sitting unused one flag away.
- *A rename alone is not enough.* It removes the trap but adds no read-only
  capability, so the next investigator has nothing safe to reach for — and the
  most likely thing they reach for instead is `--force-render`, whose name at
  least fails honestly but still writes. The issue itself calls the dry-run
  "the harder, more valuable fix"; skipping it leaves the capability gap that
  caused the incident.
- *Keeping `--check` as a warning alias is what makes this non-breaking.*
  A hard removal would break six live call sites in `tests/cli-backfill.test.js`
  plus at least two `docs/plans/` runbooks that use `--update --check` as the
  protocol-mirror regeneration command (`docs/plans/2026-08-07-per-unit-review-join.md:122`,
  `:347`, `:429`, `:1002`) and the acceptance-criterion form at
  `docs/plans/2026-08-09-agent-auditor-persona.md:1078`. The alias keeps every
  one of those working while the warning converts a silent hazard into a loud
  one printed before any write happens.
- *The dry-run closes a verification gap this repo already measured and gave
  up on.* Finding F2 (Context) proved that no single-signal check can
  distinguish "genuinely current" from "source edited, mirror stale" while
  `--check` silently self-heals the second case and exits 0. `--dry-run`'s
  exit code discriminates all three shapes on its own. A rename cannot do
  this; only a mode that does not write can.
- *The dry-run is provable, which is why it is worth the extra risk.* A
  whole-tree `path → (sha256, mode)` snapshot compared before and after,
  **paired with a mutation control** proving the same fixture genuinely mutates
  without `--dry-run`, is a single assertion that covers all **twelve** write
  sites at once without enumerating them — strictly stronger than twelve
  per-site assertions that could each be quietly satisfied by a stale fixture.

  This site-agnostic property is exactly what made the 2026-08-14 gh338
  escalation cheap to absorb: a twelfth site appearing two days after the
  inventory was measured required **no change to C2.3's assertion**, only a
  fixture that arms the new site. It is also the argument behaviour item 7 now
  applies to the exit code, which had been written in the enumerating style
  this bullet rejects.

## Risks and dependencies

- **R1 — an incomplete write barrier.** The highest-probability defect is a
  `--dry-run` that suppresses the render-loop writes and misses `.gitignore`,
  `CLAUDE.md`, or the `persona-config.json` write. Mitigated by the write-site
  inventory in Context and by C2.3's whole-tree snapshot, which does not care
  which site was missed.
- **R2 — silent report loss.** Wrapping `appendUnique` /
  `migrateGlobalProtocolImport` in `if (!dryRun)` suppresses the write *and*
  the knowledge of whether it would have happened, producing an incomplete
  report and (for `migrateGlobalProtocolImport`) a wrong `migratedClaudeMd`
  fast-path term. Called out in Context; C2.4 partially pins it.
- **R3 — two-render-path divergence.** The `191.fail` class. Both code units
  touch the `--update` path only; C1.11 behaviorally pins that the scaffold
  path's replacement semantics are unchanged.
- **R4 — stale `fileHashes` after the Step 3 version bump.** The `gh308.fail`
  class, which blocked every downstream consumer of this repo. C3.5 pins it.
- **R5 — vacuous new tests.** `tests/cli-backfill.test.js` terminates in an
  `if (failures > 0) process.exit(1)` gate at its very end; any `check(...)`
  appended *below* that gate can never fail the suite. C1.2/C2.2 pin
  placement mechanically.
- **R6 — historical documents rewritten.** `docs/plans/*` and
  `.claude/agent-memory/*` mention `--check` as a record of what was true at
  the time. Rewriting them destroys the record and inflates the diff. Listed
  in every step's "Do NOT touch".
- **Dependency:** Step 2 depends on Step 1 (it reuses Step 1's snapshot
  helper and adds an interaction criterion over Step 1's flag). Step 3
  depends on Step 2 (it documents the flags Step 2 introduces). Strictly
  sequential; no parallel dispatch.
- **Dependency:** Step 2's dispatch is gated on Open Question 1 being
  answered. Step 1 is not gated and can dispatch immediately.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — every acceptance criterion is
  a runnable command, and C2.3 carries a mandatory mutation control so the
  no-write proof cannot pass vacuously.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied,
  and directly served — issue #289 exists precisely because the only current
  way to add a persona is to hand-edit `persona-config.json`, which is the
  thing P2 forbids. Step 1 replaces that hand-edit with a script path.
- P3 "Version-stamp discipline" (MUST): satisfied. No version-stamped file
  (`agents/*.md`, `templates/*`) is modified by any step, so P3's bump
  requirement is not triggered by content change. Step 3 nonetheless bumps
  `plugin.json` + `package.json` and adds a CHANGELOG entry to follow the
  repo's release convention, and C3.5 requires the resulting restamp to be
  regenerated and committed.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — Step 1's
  validation accepts every optional persona name whether or not the project
  selected it, and the unknown-token error lists the full valid set rather
  than only the currently-selected ones.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — `bash
  tests/validate.sh` exit 0 is criterion 1 of every step.

---

## Step 1 — `--update --personas=` additive union (#289)

**Suggested model constraint:** NOT haiku. Sonnet minimum. (Binding, per
issue #289's explicit instruction and the 21-record R2 history.)

**Affected files**
- `bin/cli.js` — `runUpdate` only (`:827`–`:1131`).
- `tests/cli-backfill.test.js` — new cases, plus a reusable whole-tree
  snapshot helper.

**Behaviour**

1. Parse `args.find((a) => a.startsWith('--personas='))` inside `runUpdate`.
   Absent → behaviour byte-identical to today.
2. Split on `,`, trim, drop empties.
3. Migrate legacy tokens with the existing `migrateLegacyPersonaTokens(...,
   { logNote: true })` **before** validating, so `--personas=hivemind`
   resolves to `spec-master` + `task-master` rather than being rejected.
4. Validate every resulting token against
   `OPTIONAL_PERSONAS ∪ {'researcher'} ∪ CORE_PERSONAS`. Any token outside →
   print the offending token(s) and the full valid set to stderr and
   `process.exit(1)`. This validation, and the exit, must sit **ahead of the
   first filesystem write** in `runUpdate` (currently the legacy-agent
   `fs.unlinkSync` at `:882`), exactly as the downgrade guard at `:844-866`
   does and for the same stated reason.
5. An empty value (`--personas=`, or only separators) is an error with the
   same shape.
6. Core-persona tokens are accepted, are a no-op, are **not** recorded in
   `personaSelection`, and produce an informational note.
7. Apply the union after the recorded selection's own legacy migration
   (`:877`) and before `buildFileSpecs` (`:908`):
   `personaSelection = recorded ∪ (requested ∩ (OPTIONAL_PERSONAS ∪ {researcher}))`,
   recorded order preserved, additions appended in `OPTIONAL_PERSONAS`
   declaration order with `researcher` last.
8. Nothing is ever removed.
9. Already-selected tokens are a no-op with an informational note naming them.
10. Assign the union into `config.personaSelection` in memory; persistence
    happens through `runUpdate`'s existing config writes at `:1098` and
    `:1117`, exactly as the `hadLegacyToken` path already does at `:879`.
11. Print a summary line naming what was added, e.g.
    `  personaSelection: added agent-auditor (union with --personas=; nothing removed)`.
12. Add a comment at the flag's parse site recording that `--overwrite` is
    never read on this path (`main()` returns at `:1817` before the scaffold
    parses it), so the orthogonality is not re-derived by the next reader.

**Acceptance criteria** (run from the repo root)

- **C1.1** `bash tests/validate.sh` exits 0.
- **C1.2** Every new `check(...)` case sits above the suite's terminal
  failure gate:
  ```
  node -e 'const s=require("fs").readFileSync("tests/cli-backfill.test.js","utf8").split("\n");const g=s.findIndex(l=>l.startsWith("if (failures > 0)"));const last=s.map((l,i)=>[l,i]).filter(([l])=>/^check\(/.test(l)).pop()[1];if(!(last<g&&g>-1))process.exit(1);console.log("ok")'
  ```
- **C1.3** Union adds without removing: in a temp project whose
  `personaSelection` is `["reviewer","scribe"]`,
  `node bin/cli.js --update --personas=agent-auditor` exits 0; afterwards
  `personaSelection` contains all three of `reviewer`, `scribe`,
  `agent-auditor`, and `.claude/agents/agent-auditor.md` exists.
- **C1.4** Already-selected is a no-op: on that same project,
  `--personas=reviewer` exits 0, `personaSelection` is deep-equal to its prior
  value, and stdout names `reviewer` as already selected.
- **C1.5** Unknown token errors and writes nothing:
  `--personas=not-a-persona` exits 1; stderr contains `not-a-persona`; and a
  whole-tree snapshot (`relPath → sha256`, plus the sorted path list) of the
  project is deep-equal before and after.
- **C1.6** Mixed valid+invalid fails atomically:
  `--personas=agent-auditor,bogus` exits 1, the snapshot is deep-equal before
  and after, and `agent-auditor` is **not** added to `personaSelection`.
- **C1.7** Legacy token migrates then unions: `--personas=hivemind` on a
  project lacking both exits 0 and leaves `personaSelection` containing both
  `spec-master` and `task-master`.
- **C1.8** Empty value errors: `--personas=` exits 1 and the snapshot is
  deep-equal before and after.
- **C1.9** Core-persona token is a no-op: `--personas=explorer` exits 0,
  `personaSelection` is deep-equal to its prior value (`explorer` is not
  added), and stdout says `explorer` is a core persona.
- **C1.10** No-flag regression: on an up-to-date project, plain
  `node bin/cli.js --update` still prints `already current` and exits 0.
- **C1.11** Scaffold path unchanged (guards the `191.fail` class): a fresh
  `node bin/cli.js --yes --personas=reviewer` in an empty temp dir still
  produces `personaSelection` deep-equal to `["reviewer"]` exactly —
  replacement semantics, **not** union.
- **C1.12** Researcher without an arXiv launch command renders in **fallback
  mode** and does *not* refuse (corrected 2026-08-14 — the original criterion
  described a refusal path that does not exist for the `arxiv` file kind; see
  the dated correction in Clarifications). In a temp project whose
  `substitutions` records a `graphMcpLaunch` but has **no** `arxivMcpLaunch`
  key, `node bin/cli.js --update --personas=researcher`:
  1. exits **0**;
  2. prints **no** `could not be rendered` line;
  3. leaves `.claude/agents/researcher.md` **existing**, containing
     `No working arXiv MCP found at ADAPT time` and matching **no** line
     `^mcpServers:`;
  4. leaves `personaSelection` containing `researcher`.

  **The fixture MUST record a `graphMcpLaunch`.** With `substitutions` absent
  (or that key missing), `explorer.md` fails to render for an *unrelated*
  reason — its own missing `graphMcpLaunch` — producing exit 1 and a `could
  not be rendered` line for the **wrong file**. Verified 2026-08-14: that
  mistake is exactly what makes the superseded version of this criterion look
  satisfiable, so a fixture without `graphMcpLaunch` would have "passed" it
  for a reason having nothing to do with `researcher`.

  Do **not** implement a refusal to satisfy this. The fallback is deliberate
  and load-bearing: `tests/cli-backfill.test.js:51` and `:1320` both pass
  `arxivMcpLaunch: null` and require a successful `researcher.md` render.
  Breaking either to manufacture a refusal is an automatic FAIL for this
  unit; C1.1 (`bash tests/validate.sh`, which runs `cli-backfill.test.js`)
  keeps them green.

**Do NOT touch**
- The scaffold `--personas=` handling at `bin/cli.js:1891-1899` or any code
  below `runUpdate`'s closing brace at `:1131`.
- The cursor (`:1258`+) and codex (`:1428`+) target paths.
- Anything under `docs/plans/` or `.claude/agent-memory/`.
- `.claude/reviewed/`.

---

## Step 2 — genuine `--dry-run`, and `--check` → `--force-render` (#291)

**Suggested model constraint:** NOT haiku. Sonnet minimum; **opus
recommended** — this is the write-barrier unit and the one whose failure mode
is silent data loss. (`tests/reviewer-tier.test.sh:102` already forces an opus
*reviewer* for any `bin/cli.js` diff; this constraint is about the *writer*.)

**Gated on Open Question 1.** Do not dispatch until OQ1 is answered. The
behaviour below encodes OQ1's recommended default (deprecated alias + warning).

> **Revised 2026-08-14 — gh338 escalation.** A `lead-programmer` dispatch on
> this unit escalated before writing any code, having found two blocking gaps.
> Both were independently re-verified against live `bin/cli.js` (v0.31.49)
> before this revision was written:
> - **F-A** — a **twelfth** `--update` write site (`:1136-1148`, the
>   hook-registration backfill) landed in commit `d1f232f` on 2026-08-13, two
>   days after this plan's write-site inventory was measured. Site 12 is now
>   in the Context inventory; behaviour item 9 and **C2.13** cover it, with a
>   prescriptive fixture shape because the obvious fixture passes vacuously.
> - **F-B** — the exit-code rule was under-determined. The escalation named
>   six uncovered sites; re-measurement found **eight** (sites 10/11, the
>   `persona-config.json` rewrite, were also uncovered and were demonstrated
>   mutating a tree on a live exit-`0` run). Behaviour item 7 is rewritten over
>   *mutations* rather than report vocabulary, and **C2.14** pins it.
> - **F-D** (advisory, accepted) — folded into **C2.3**: `snapshotTree` is
>   widened to be mode- and directory-aware. **C2.15** guards Step 1.
> - **F-E** (advisory, declined — keep as-is) — recorded as an explicit scope
>   carve-out in behaviour item 3.
>
> The escalation was correct and cost nothing: no code was written against a
> spec that would have shipped a `--dry-run` reporting "nothing would change"
> for two separate real mutations.

**Affected files**
- `bin/cli.js` — `runUpdate` and its helpers `appendUnique` (`:159`),
  `migrateGlobalProtocolImport`, and the twelve write sites in the Context
  inventory. Site 12's branch (`:1136-1148`) and `writeSpecBody`
  (`:455-463`) both post-date the 2026-08-11 measurement.
- `tests/cli-backfill.test.js` — new cases (C2.13-C2.15); the **widened
  `snapshotTree`** helper (`:1665-1681`, per C2.3's F-D ruling); and six
  existing `--check` call sites migrated. **Line numbers re-measured
  2026-08-14** — the six are `:849`, `:970`, `:996`, `:1121`, `:1185`,
  `:1215`. (The superseded list gave seven stale numbers — `:860`, `:871`,
  `:882`, `:897`, `:1022`, `:1086`, `:1116` — while correctly calling them
  "six"; locate by `'--check'` content, not by number.) At least one is
  deliberately retained on `--check` to pin the alias.

**Behaviour**

1. `--force-render` is the new canonical name for today's `checkFlag`
   (`bin/cli.js:975`), with identical behaviour.
2. `--check` continues to work as a deprecated alias for `--force-render`,
   and prints to **stderr**, as the first output of the run and before any
   write:
   `WARNING: --check is deprecated and is NOT a dry-run — it writes files (it renders mirrors and rewrites persona-config.json). Use --force-render for the same behaviour under an honest name, or --dry-run for a genuine no-write report.`
3. `--dry-run` performs **zero** filesystem writes **anywhere under the
   project root** on the `--update` path — all **twelve** sites in the Context
   inventory, re-located by anchor text, not by line number.

   *Scope carve-out (finding F-E, ruled 2026-08-14: keep as-is).*
   `printUnifiedDiff` (`bin/cli.js:902-915`) writes two temp files under
   `os.tmpdir()` and `fs.rmSync`s the directory afterwards. These are
   **outside the project root**, are cleaned up by the function itself, and
   exist to produce the pending-report diff, which is the entire point of the
   dry-run report. They are deliberately **not** suppressed. Item 3 is scoped
   to the project root precisely so this stays true rather than being an
   unstated exception to an absolute claim — an earlier draft said "zero
   filesystem writes anywhere", which contradicted this ruling. A reviewer
   should not re-litigate this; it is a recorded decision.
4. `--dry-run` implies the force: it bypasses the version-match fast path at
   `:1005` exactly as `--force-render` does. (Without this, a dry run on a
   current project reports nothing and is useless.)
5. `--dry-run` reports the same per-target set a live run would act on, in the
   conditional voice. **The vocabulary must cover all twelve sites, not just
   the render loop** — the 2026-08-11 list below the line covered only sites
   6-9, which is the reporting half of the same gap finding F-B found in the
   exit code.

   | Sites | Conditional phrase |
   |---|---|
   | 6 | `would be created` |
   | 7 | `stamp would be refreshed` |
   | 8 | `would be updated` |
   | 9 | `would be overwritten (--accept)` |
   | 6-9, no change | `already current` |
   | 6-9, `--keep` | `would be kept as-is` |
   | 6-9, divergent | `would be pending a decision` |
   | 6-9, stale hash | `hash would be healed` |
   | 1 | `would be removed` (naming the legacy agent path) |
   | 2 | `would remove the legacy global @.claude/persona-protocol.md import` (naming `CLAUDE.md`) |
   | 3, 4 | `would be appended to` (naming `.gitignore`) |
   | 5 | `would remove N standalone antislop hook registration(s)` (naming `.claude/settings.json`) |
   | 10, 11 | `would be rewritten` (naming `.claude/persona-config.json`) |
   | 12 | `would add N missing antislop hook registration(s)` (naming `.claude/settings.json`) |

   The exact wording of each phrase is the implementer's to choose; what is
   **required** is that (a) every site that would fire emits at least one line
   naming its target path, (b) that line is in the conditional voice, and
   (c) no dry-run line anywhere uses an indicative/past-tense write verb.
   C2.4 pins (c) mechanically and C2.14 pins (a).
6. `appendUnique` (sites 3, 4) and `migrateGlobalProtocolImport` (site 2)
   each gain a no-write mode
   (or a sibling predicate) that still returns what it *would* have done, so
   the dry-run report is complete and `migratedClaudeMd` still computes
   correctly for the fast-path term at `:1005`.
7. **`--dry-run` exit codes — defined over *mutations*, not over report
   vocabulary** (rewritten 2026-08-14 per finding F-B; see the measured table
   in Context):

   - **`1`** — one or more files could not be rendered (`unresolvedRender`
     non-empty). Unchanged.
   - **`0`** — **if and only if** a live `--update` run, with the same
     arguments on the same tree, would leave every path under the project
     root byte-identical and mode-identical, and would create no new path.
   - **`3`** — otherwise: **any** of the twelve sites would fire with an
     effect (a file created, updated, deleted, stamp-refreshed, appended to,
     rewritten, or left pending a decision).

   **Why this formulation and not an enumeration of outcome names.** The rule
   is stated over the *effect on the tree* rather than over a list of summary
   phrases, for four reasons:

   1. This unit exists to kill false reassurance. Exit `0` is the most
      consumable signal there is — it is what a CI drift check greps. If exit
      `0` can coexist with a live run that writes, `--dry-run` reproduces
      `--check`'s exact dishonesty in a new place, and the unit fails at its
      own purpose.
   2. Context already commits to a single-signal contract: "`--dry-run`'s
      exit-code contract collapses that back to one signal, because the tree
      is guaranteed clean by construction." That is only sound if exit `0` ⟺
      the tree would be untouched. The enumerated form breaks the
      biconditional; this form *is* the biconditional.
   3. It removes an internal contradiction inside this very step. C2.3's
      no-write proof already asserts over the **whole tree** — `.gitignore`,
      `.claude/settings.json` and `.claude/persona-config.json` included. An
      exit-code rule covering only four render-loop outcomes contradicts the
      criterion sitting three bullets above it.
   4. **It fails safe as `bin/cli.js` grows.** An enumerated rule makes every
      future write site invisible to exit `0` *by default* — which is exactly
      how site 12 went unnoticed for two days. A site-agnostic rule makes the
      default the other way round.

   **Restated as one machine-checkable sentence:** exit `0` is a promise that
   C2.3's snapshot predicate would hold across a **live** run. That is not a
   loose paraphrase — it is the definition, and C2.14 tests it directly by
   running the live run and comparing.

   *Implementability was verified, not assumed:* see "Every one of the twelve
   has a cheap no-write predicate" in Context. *Convergence:* a project that
   exits `3` only because of the sites 10/11 config rewrite returns to `0`
   after one live `--update`; it does not exit `3` forever.
8. `--dry-run` and `--force-render` together are accepted (the dry run
   already forces); `--dry-run` wins on the write question.
9. **Site 12 — the hook-registration backfill (`bin/cli.js:1136-1148`) — gets
   its own no-write treatment** (added 2026-08-14 per finding F-A). This site
   post-dates the original inventory and is the cheapest of the twelve to
   handle correctly, because it *already* computes its answer without
   writing:

   ```
   if (settings && !pluginState.enabled) {
     const merged = mergeNestedHooksJson(deep-copy of settings, readStandaloneHooksConfig());
     if (JSON.stringify(merged.hooks) !== JSON.stringify(settings.hooks)) {
       fs.writeFileSync(settingsPath, …);   // <-- suppress ONLY this
       const added = …;
       settings = merged;                   // <-- KEEP (see below)
       console.log('… added N missing …');  // <-- conditional voice
     }
   }
   ```

   Three requirements, in order of how easy they are to get wrong:
   - Suppress **only** the `fs.writeFileSync`. The `mergeNestedHooksJson`
     call is already non-destructive (it merges into a `JSON.parse(JSON.stringify(settings))`
     deep copy), so the predicate is free.
   - **Keep the in-memory `settings = merged` assignment.** Dropping it
     alongside the write is the `appendUnique` trap in a new place: any later
     code reading `settings` would then see a state neither the live run nor
     the dry run ever has. Suppress the write, not the computation.
   - The `added` count and the report line must still be produced, in the
     conditional voice (behaviour 5), and the site must contribute to the
     exit-`3` decision (behaviour 7). Site 12 firing alone is a measured
     exit-`0` case today; that is precisely what must change.

**Acceptance criteria** (run from the repo root)

- **C2.1** `bash tests/validate.sh` exits 0.
- **C2.2** The C1.2 placement check still passes.
- **C2.3** No-write proof **with mutation control**, both assertions in one
  test. Arm a temp project — call this the **all-twelve fixture**, reused by
  C2.4, C2.13 and C2.14 — so that a live run demonstrably mutates it via
  **every one of the twelve sites**: a legacy persona token recorded in
  `personaSelection` with its agent file present (site 1), a bare
  `@.claude/persona-protocol.md` line added to `CLAUDE.md` (site 2),
  `.gitignore` stripped of the managed entries (sites 3, 4), a standalone
  antislop hook registration in `.claude/settings.json` (site 5, exercised
  under `--dedupe-hooks` by C2.11), one managed mirror deleted (site 6), a
  stale `pluginVersion` (site 7), one managed mirror's body corrupted while
  its recorded hash still matches the old body (site 8), one mirror locally
  edited and named in `--accept` (site 9), three `fileHashes` entries dropped
  (sites 10, 11), and the `HOME`-isolated/plugin-disabled shape from C2.13
  (site 12). Then:
  (a) `node bin/cli.js --update --dry-run --dedupe-hooks --accept=all` leaves
  a whole-tree snapshot **deep-equal** to the snapshot taken immediately
  before it; and
  (b) on a byte-identical fresh copy of the same fixture, the same command
  with `--force-render` in place of `--dry-run` leaves the snapshot **not**
  deep-equal.
  Assertion (b) is what makes (a) non-vacuous and is not optional.

  **The snapshot must be mode-aware and directory-aware** (finding F-D, ruled
  2026-08-14: fold in here, do **not** defer to #273). `snapshotTree`
  (`tests/cli-backfill.test.js:1665-1681`) currently records `relPath →
  sha256` plus the sorted **file** path list. Two classes of write are
  therefore invisible to it, both of which live inside `writeSpecBody`
  (`bin/cli.js:455-463`), which three of the four render-loop branches call:
  - `fs.chmodSync(destAbsPath, …)` (`:462`) — a dry run that suppressed the
    `writeFileSync` but kept the chmod would still pass a content-only
    deep-equal.
  - `mkdirp(path.dirname(destAbsPath))` (`:460`, and `:448` in
    `copyStampedBody`) — an empty directory left behind contributes **no**
    entry to a file-only path list.

  Widen the existing helper to record `mode & 0o777` alongside each content
  hash, and to include directory paths in the sorted path list. Keep the
  `.git` skip.

  *Why fold in rather than defer:* C2.3 is this unit's central proof, and a
  no-write proof blind to a class of writes is the vacuous-criterion trap this
  plan is otherwise careful about. The fix is confined to a **test helper this
  step already owns and already modifies** — no production code, no new seam,
  no blast radius outside `tests/cli-backfill.test.js`. Issue #273's exec-bit
  spec answers a different question (*is the shipped mode correct?*) from this
  one (*did the mode change?*), and it is still in flight, so deferring would
  either block this step on another spec's schedule or ship the hole. The
  helper's own comment already anticipates this: "Reusable by a later step
  (dry-run) — do not duplicate."

  *Boundary note:* `snapshotTree` was introduced by Step 1, which has already
  PASSed. Widening it is a Step 2 edit to a file Step 2 already lists as
  affected; it does **not** reopen Step 1's plan text or its shipped
  behaviour. C2.15 pins that Step 1's three call sites still pass.
- **C2.4** Report vocabulary: on that armed fixture, `--update --dry-run`
  stdout contains `would be created` for the deleted mirror, and
  `node bin/cli.js --update --dry-run 2>&1 | grep -qE ': (updated|created|pending)$'`
  exits **non-zero**. Rationale, stated precisely so nobody mistakes it: that
  grep idiom is *already known-broken* (finding F2, see Context) and is not
  being preserved as a working contract. The criterion exists so that dry-run
  output cannot be read — by a human or by one of the existing criteria still
  carrying that idiom — as a record of writes that happened.
- **C2.5** Exit codes (all three under `--update --dry-run`): `3` on the armed
  fixture; `0` on a project brought current by a preceding live `--update`;
  `1` on a project with **no `substitutions.graphMcpLaunch`** recorded
  (corrected 2026-08-14 — the superseded text named a missing
  `substitutions.arxivMcpLaunch` on a project whose `personaSelection`
  includes `researcher`; that project exits **0**, not `1`, because the
  `arxiv` kind has no refusal path at all. See C1.12 and the dated correction
  in Clarifications).

  **The exit-1 fixture MUST be a never-wired project**: `.claude/agents/explorer.md`
  still containing the literal `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>`
  placeholder, **and** `substitutions.graphMcpLaunch` absent. Both halves are
  load-bearing; each was verified live 2026-08-14 against `bin/cli.js`:
  1. Naming `arxivMcpLaunch` here is the same **wrong-file trap** C1.12
     documents. A fixture missing *both* keys does exit `1` — but for
     `explorer.md`'s missing `graphMcpLaunch`, nothing to do with
     `researcher` — so the superseded text was satisfiable only by accident.
  2. Deleting `graphMcpLaunch` from an *already-wired* project is **not**
     enough. `backfillSubstitutionsFromDisk` (`bin/cli.js:386-409`)
     reverse-engineers the field back out of the rendered `explorer.md` via
     `deriveMcpLaunchFromDisk` and the run exits `0`; measured, that fixture
     ends with `graphMcpLaunch` re-recorded in `persona-config.json`. Only an
     intact placeholder makes the backfill decline (`bin/cli.js:399`).

  Assert exit `1` **and** a `could not be rendered` line naming
  `.claude/agents/explorer.md` — the exit code alone cannot distinguish this
  from any other exit-1 cause. Baseline measured 2026-08-14 with today's
  `--check` (the `--force-render`/`--dry-run` precursor), which already exits
  `1` on this fixture and `0` on the `arxiv`-only one; `--dry-run` must not
  change that, since both share `runUpdate`'s single `unresolvedRender` exit
  at `bin/cli.js:1278`.
- **C2.6** Dry-run implies the force: on a project whose `pluginVersion`
  matches and whose mirrors are all current except one corrupted body,
  `--update --dry-run` names that file (it did not take the `:1005` fast path).
- **C2.7** `--force-render` is behaviourally identical to today's `--check`:
  the existing case at `tests/cli-backfill.test.js:1107` (re-measured
  2026-08-14; the superseded `:1008` is stale) ("`--update --check`
  catches drift past the version-match fast-path that a plain `--update`
  misses") passes verbatim with `--check` replaced by `--force-render`.
- **C2.8** The alias still works and warns: on two byte-identical copies of
  the armed fixture, `--update --check` and `--update --force-render` produce
  the same exit code and deep-equal post-run snapshots, and the `--check`
  run's **stderr** contains both `--check is deprecated` and `--dry-run`.
- **C2.9** The alias stays covered: `grep -c -- "'--check'" tests/cli-backfill.test.js`
  is ≥ 1, so a later hard removal cannot land silently.
- **C2.10** Step-1 interaction: on a project without `agent-auditor`,
  `node bin/cli.js --update --personas=agent-auditor --dry-run` exits 3,
  reports `.claude/agents/agent-auditor.md` as `would be created`, and leaves
  the whole-tree snapshot deep-equal — in particular `personaSelection` in
  `persona-config.json` is unchanged on disk.
- **C2.11** The `--dedupe-hooks` write is suppressed too: arm a temp project
  with `.claude/settings.local.json` containing
  `{"enabledPlugins": {"<MARKETPLACE_PLUGIN_KEY>": true}}` (object-of-booleans
  form, per `bin/cli.js:1511-1513`) plus at least one standalone antislop hook
  registration in `.claude/settings.json`. Then
  `node bin/cli.js --update --dry-run --dedupe-hooks` leaves
  `.claude/settings.json` byte-identical and reports what it would remove.
  If this fixture proves impossible to arm, escalate rather than dropping the
  criterion — the `--dedupe-hooks` write (site 5, `:948` at 2026-08-11, live
  `:1107`) is one of the twelve sites.

  **`HOME` must be isolated here too**, for the same reason as C2.13 but with
  the opposite polarity: this fixture needs the marketplace plugin **enabled**
  (that is what makes `hooksCollision` true), so it must not inherit an
  ambient `HOME` that could disagree. Set `env.HOME` to the temp project
  explicitly and write the `enabledPlugins` state into the fixture rather than
  relying on the developer's own configuration.
- **C2.12** Drift-shape discrimination, on exit code alone (closes finding
  F2). Build the three fixtures from F2's table and assert
  `node bin/cli.js --update --dry-run`:
  - baseline, genuinely current → exit **0**;
  - shape A, plugin source edited so a mirror's clean render differs while the
    mirror itself carries no local edits → exit **3**;
  - shape B, mirror body locally edited away from its recorded hash → exit
    **3**.
  Each of the three must additionally leave a whole-tree snapshot deep-equal
  across the run. Shape A is the load-bearing case: it is the #291 shape, and
  today's `--check` returns 0 on it *after silently repairing it*.

- **C2.13** *(new 2026-08-14, finding F-A)* **Site 12 — the
  hook-registration backfill — is suppressed, reported, and counted.** The
  fixture shape is prescriptive because the obvious fixture passes
  **vacuously**; all three conditions below were measured on 2026-08-14.

  Fixture requirements:
  1. **`HOME` must be isolated** — pass `env: { ...process.env, HOME: tmp }`
     to `spawnSync`. Measured: with the ambient developer `HOME`, the
     marketplace plugin is detected as **enabled**, `pluginState.enabled`
     short-circuits the branch, `.claude/settings.json` stays at 3 bytes and
     the test passes **without ever reaching site 12**. This is the single
     easiest way to ship a green, meaningless test here.
  2. **The marketplace plugin must be explicitly disabled** for the fixture —
     the `if (settings && !pluginState.enabled)` guard is the branch
     condition. Note this is the exact **inverse** of C2.11's fixture, which
     sets `pluginState.enabled = true`; the two criteria cannot share one
     fixture, and C2.11's cannot be reused here.
  3. **`.claude/settings.json` must exist** — `buildBaselineProject`
     (`tests/cli-backfill.test.js:595-625`) never writes it, leaving
     `settings` null, which is the *other* condition that skips the branch.
     An empty `{}` is sufficient and is what the 3 → 2669 byte measurement
     used.

  Assertions, on that fixture:
  (a) `node bin/cli.js --update --dry-run` leaves `.claude/settings.json`
  **byte-identical**;
  (b) its stdout reports the backfill in the conditional voice, naming
  `.claude/settings.json`;
  (c) it exits **3** (not `0` — see C2.14);
  (d) **mutation control, not optional:** on a byte-identical fresh copy, a
  live `node bin/cli.js --update` leaves `.claude/settings.json` **not**
  byte-identical and grows it past 2000 bytes. Without (d), all of (a)-(c)
  are satisfiable by a fixture that never reached the branch at all — which
  is exactly failure mode 1 above.

- **C2.14** *(new 2026-08-14, finding F-B)* **Exit `0` means the live run
  would be a no-op — tested against the live run itself.** This is behaviour
  item 7's biconditional, stated as a runnable check rather than as prose.

  For each fixture in the table below, build **two byte-identical copies**.
  Run `node bin/cli.js --update --dry-run` on copy A and record its exit
  code; run the corresponding **live** `node bin/cli.js --update` on copy B
  and record whether its whole-tree snapshot (the widened, mode-aware one
  from C2.3) changed. Assert the biconditional holds: dry-run exit `0` **iff**
  the live snapshot is unchanged.

  | Fixture | Live run mutates | Required `--dry-run` exit |
  |---|---|---|
  | genuinely current (hashes intact, `.gitignore` populated, no `.claude/settings.json`) | nothing | **0** |
  | three `fileHashes` entries dropped, `.gitignore` populated | `.claude/persona-config.json` only | **3** |
  | empty `.claude/settings.json`, plugin disabled, `HOME` isolated | `.claude/settings.json` only | **3** |
  | `.gitignore` stripped of the managed entries | `.gitignore` only | **3** |
  | legacy persona token recorded, its agent file present | that agent file deleted | **3** |
  | bare `@.claude/persona-protocol.md` line in `CLAUDE.md` | `CLAUDE.md` only | **3** |

  Rows 2 and 3 are the regression pins for finding F-B: **both were measured
  at live exit `0` on 2026-08-14** with zero non-`already current` summary
  lines, and both are the false-reassurance case this unit exists to prevent.
  Row 1 is the non-vacuity control — without it, an implementation that simply
  always exits `3` passes every other row. Row 1 was independently measured
  clean (snapshot unchanged, exit `0`) on 2026-08-14 under both plain
  `--update` and `--check`, so it is known to be satisfiable.

- **C2.15** *(new 2026-08-14, finding F-D)* **Widening `snapshotTree` does not
  weaken Step 1.** Its three existing call sites
  (`tests/cli-backfill.test.js:1727/1731`, `:1741/1744`, `:1774/1777` — the
  C1.5-C1.8 "writes nothing" assertions) still pass unmodified, with the
  mode-and-directory-aware helper in place.

  **Measured, not assumed (2026-08-14).** A scratch copy of
  `tests/cli-backfill.test.js` with `snapshotTree` widened exactly as C2.3
  requires — appending `mode & 0o777` to each entry and adding a `DIR:` entry
  per directory — was run in full against the current tree: **the entire suite
  passed**, not merely the three call sites. So the widening is known to be
  compatible before the implementer starts, and a failure here is a signal
  that something *else* in the unit went wrong, not that the helper change was
  a bad idea. (The mechanism is as expected: those runs abort on invalid
  `--personas=` tokens before any write, so they create no directories and
  change no modes.)

**Do NOT touch**
- `scripts/resync-vendored-skills.sh` and its unrelated, genuinely read-only
  `--check`.
- `docs/plans/*.md` and `.claude/agent-memory/*` — historical records that
  cite `--update --check`; leave every one of them exactly as written.
- `CONTEXT.md` — that is Step 3's deliverable, dispatched to `scribe`.
- The scaffold, cursor and codex paths.
- `.claude/reviewed/`.

---

## Step 3 — document the new flag surface and release it (scribe)

**Suggested model constraint:** NOT haiku. Sonnet minimum.

**Affected files**
- `CONTEXT.md` — the `## Language` glossary.
- `commands/update-antislop.md`.
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`.
- Regenerated mirrors under `.claude/` plus `.claude/persona-config.json`'s
  `fileHashes`, as a consequence of the version bump.

**Behaviour**

1. Rewrite the `**`--update` semantics**` glossary entry (currently
   `CONTEXT.md:39-49`) so it names `--force-render` as the force-the-loop
   control, names `--dry-run` as the genuine no-write mode with its exit-code
   contract, and records `--check` as a deprecated alias that still writes.
   The existing contrast with `scripts/resync-vendored-skills.sh --check`
   stays useful and should be kept, re-pointed.
2. Add glossary entries for the two load-bearing new terms surfaced by the
   ubiquitous-language check: the `--update` **dry-run**, and `--update
   --personas=` **additive-union** semantics (union with the recorded
   `personaSelection`, never replacement, never removal — explicitly
   contrasted with the scaffold path's replacement semantics).
3. Add `--dry-run` to `commands/update-antislop.md` as the safe way to
   investigate before running a real update.
4. Bump `.claude-plugin/plugin.json` and `package.json` to the next patch
   version (kept in sync — `tests/validate.sh:33-41` checks this) and add a
   matching `CHANGELOG.md` entry covering both issues.
5. Run `node bin/cli.js --update` from the repo root to restamp every mirror
   at the new version, and commit the refreshed mirrors **together with**
   `.claude/persona-config.json`'s updated `fileHashes`. Skipping the second
   half of that is exactly the `gh308.fail` defect.

**Acceptance criteria** (run from the repo root)

- **C3.1** `bash tests/validate.sh` exits 0.
- **C3.2** The stale claim is gone and the new one is present:
  `grep -q -- '--force-render' CONTEXT.md` and
  `grep -q -- '--dry-run' CONTEXT.md` and `grep -qi 'deprecated' CONTEXT.md`
  all succeed, **and** `grep -q 'the `--check` flag is a' CONTEXT.md` fails
  (that exact clause at `CONTEXT.md:41` must not survive verbatim).
- **C3.3** Both new glossary entries exist as glossary-shaped bold terms:
  `grep -qE '^\*\*.*dry-run.*\*\*:' CONTEXT.md` and
  `grep -qE '^\*\*.*--personas.*\*\*:' CONTEXT.md` both succeed.
- **C3.4** Release metadata is consistent:
  ```
  node -e 'const p=require("./package.json"),g=require("./.claude-plugin/plugin.json"),c=require("fs").readFileSync("CHANGELOG.md","utf8");if(p.version!==g.version)process.exit(1);if(!c.startsWith("# Changelog\n\n## ["+p.version+"]"))process.exit(1);if(p.version==="0.31.24")process.exit(1);console.log("ok")'
  ```
- **C3.5** The restamp is committed, not pending (the `gh308.fail` class):
  after committing, `node bin/cli.js --update --dry-run` exits 0 and
  `git status --porcelain` produces no output.
- **C3.6** `grep -q -- '--dry-run' commands/update-antislop.md` succeeds.
- **C3.7** Prose accuracy (reviewer-verified, not grep-verified): no sentence
  anywhere in `CONTEXT.md` or `commands/update-antislop.md` still describes
  `--check` as the current or canonical flag, and no sentence claims
  `--force-render` is read-only. The reviewer must read both changed sections
  in full and confirm this; the greps in C3.2 gate the presence of the new
  wording, not the absence of a contradictory sentence elsewhere.

**Do NOT touch**
- `bin/cli.js` or `tests/cli-backfill.test.js` — Steps 1 and 2 own those.
- `docs/plans/*.md` and `.claude/agent-memory/*`.
- Any `agents/*.md` or `templates/*` **source** file (only their generated
  `.claude/` mirrors change, and only as a mechanical consequence of the
  version bump — no hand-edits).
- `.claude/reviewed/`.

---

## Open Questions

1. **(#291, gates Step 2) Should `--check` survive as a warning-emitting
   deprecated alias, or be hard-refused?**
   - **(a) Recommended default — deprecated alias that still works and
     warns.** Non-breaking: the six live test call sites, the
     `docs/plans/2026-08-07-per-unit-review-join.md` regeneration runbook and
     the `docs/plans/2026-08-09-agent-auditor-persona.md:1078` acceptance-criterion
     form all keep working, and the warning printed before any write is the
     actual mitigation for the #291 incident.
   - (b) Hard refusal — `--check` exits 1, writes nothing, and prints the two
     replacements. Eliminates the hazard completely and is trivially provable,
     but breaks every existing caller. All known callers are inside this repo
     and are mechanically fixable in Step 2; the residual risk is external
     clones with their own runbooks (this package is `private: true` and
     unpublished, so users clone it — external usage is plausible but
     unmeasurable from here).
   - If (a): should the alias carry a removal target (e.g. "removed in
     v0.33.0") in the warning text, or stay indefinite? Recommended default:
     **indefinite** — a dated promise nobody schedules is worse than none, and
     C2.9 keeps the alias covered by a test either way.

   *(Originating check: CHK1. If (b) is chosen, Step 2's C2.8 and C2.9 must be
   rewritten before dispatch, and Step 2's blast radius grows to include the
   two `docs/plans/` runbooks — which the current "Do NOT touch" list forbids
   — so this is not a decision the lead-programmer can make mid-unit.)*

## Self-check

- **CHK1**: Is the plan's choice between #291's two suggested directions
  stated with reasoning rather than picked silently? — FAIL (ambiguous, on
  the residual alias-vs-refusal fork only) — converted to Open Question 1.
  The dry-run-vs-rename fork itself is resolved and reasoned in
  "Recommendation for #291".
- **CHK2**: Is "makes no filesystem writes" backed by a criterion that cannot
  pass on a fixture where nothing would have changed anyway? — PASS (C2.3(b)
  is a mandatory mutation control).
- **CHK3**: Do Steps 1 and 2 agree on where `--personas=` validation sits
  relative to the first write? — PASS (Step 1 behaviour 4 hoists it ahead of
  `bin/cli.js:882`; Step 2 adds no earlier write, and C2.10 asserts the
  dry-run leaves `personaSelection` unchanged on disk).
- **CHK4**: Is the outcome of `--personas=researcher` on a project with no
  arXiv launch command defined? — PASS (Clarifications, and C1.12 pins exit
  code, stdout, file absence, and the `personaSelection` value).
- **CHK5**: Is the `--dry-run` exit-code contract defined for all three
  outcomes, and does it collide with an existing code? — PASS (Step 2
  behaviour 7 and C2.5; `0`/`1`/`2` are in use in `runUpdate` at
  `bin/cli.js:1112`, `3` is unused).
- **CHK6**: Do the steps agree on who owns `CONTEXT.md`? — FAIL
  (conflicting: an earlier draft had Step 2 updating the glossary while Step 3
  also claimed it) — revised in place; `CONTEXT.md` is now named in Step 2's
  "Do NOT touch" and is Step 3's sole deliverable.
- **CHK7**: Does every step have a criterion that a machine can run and get a
  pass/fail from? — PASS for C1.\*, C2.\*, C3.1–C3.6. **C3.7 is deliberately
  reviewer-verified prose accuracy**, declared as such, because grep can gate
  the presence of new wording but not the absence of a contradictory sentence
  elsewhere in the document — this repo has three prior FAILs where a docs
  unit's existence-grep criteria gated nothing while prose accuracy *was* the
  deliverable.
- **CHK8**: Is the constitution's P3 stamp-discipline question answered rather
  than assumed? — PASS (Constitution check states no version-stamped file
  changes, so P3's bump is not content-triggered; Step 3 bumps anyway for
  release convention, and C3.5 pins the restamp).
- **CHK9**: Does the plan say whether `--overwrite` interacts with
  `--update --personas=`, which issue #289 explicitly asks? — PASS (Context:
  `main()` returns at `bin/cli.js:1817` before any scaffold flag is parsed;
  Step 1 behaviour 12 requires a code comment recording it).
- **CHK10**: Are new test cases guaranteed to be able to fail? — PASS
  (C1.2's placement check against the terminal `failures > 0` gate, re-asserted
  as C2.2).
- **CHK11**: Does the plan cite an existing repo idiom as a working contract
  when that idiom has already been measured as broken? — FAIL (conflicting:
  the first draft's C2.4 rationale described the
  `grep -qE ': (updated|created|pending)$'` form as an idiom worth protecting,
  while `docs/plans/2026-08-09-agent-auditor-persona.md:1454-1493` records it
  as "structurally broken") — revised in place; C2.4's rationale now states
  the idiom is known-broken and explains what the criterion is actually for,
  and the finding is added to Context, to the #291 recommendation, and as the
  new criterion C2.12.
- **CHK12**: Was every machine-checkable criterion in this plan run against
  the tree as authored, to confirm it has the expected polarity *today*? —
  PASS (run 2026-08-11: C1.2/C2.2's placement check returns `ok`; C3.2's
  stale-clause grep succeeds and its `--force-render` grep fails; C3.3's two
  glossary greps both fail; C3.4's release-metadata check exits 1; C3.6's
  grep fails; C2.9's alias count is 5. Every one of them therefore changes
  state when its step lands, and none is vacuously satisfied already.)
- **CHK13** *(added 2026-08-14)*: Do C1.12 and C2.5 agree with each other, and
  with the code, about which missing substitution key produces exit `1`? —
  FAIL (conflicting: both were authored against an `arxiv` refusal path that
  does not exist, and CHK12's 2026-08-11 sweep did not actually run either of
  them — its enumeration lists neither, so the "every criterion" claim
  overstated its own coverage) — revised in place, in two passes: C1.12 first,
  then C2.5's third exit-code clause, both now naming `graphMcpLaunch` and
  both carrying an explicit fixture requirement against the wrong-file trap.
  Both corrected criteria were run against the tree in the CHK12 sense and
  have the expected polarity today.
- **CHK14** *(added 2026-08-14, gh338 escalation)*: Is the write-site
  inventory complete against the **current** `bin/cli.js`, rather than against
  the tree as it stood when the inventory was measured? — FAIL (missing: a
  twelfth site, `:1136-1148`, landed in `d1f232f` on 2026-08-13, two days
  after the 2026-08-11 measurement; the 2026-08-11 line numbers had also
  drifted by roughly +140) — revised in place: the Context table is rebuilt
  with a live column and anchor text, behaviour item 9 and C2.13 cover site
  12, and the table now carries an explicit re-measurement banner. **Root
  cause worth recording:** the inventory was pinned to a date, and the plan
  told readers to "re-locate by content" without giving them the content to
  re-locate by. The rebuilt table carries anchor text per row so the next
  drift is cheap to absorb.
- **CHK15** *(added 2026-08-14, gh338 escalation)*: Do behaviour item 7's
  exit codes and C2.3's no-write proof agree about which writes count? —
  FAIL (conflicting: C2.3 asserted over the whole tree while item 7 enumerated
  four render-loop outcomes, leaving **eight** of twelve sites able to produce
  exit `0` on a run that writes; two such cases were measured live) — revised
  in place: item 7 is restated over mutations as a biconditional, and C2.14
  tests it against an actual live run rather than against report vocabulary.
- **CHK16** *(added 2026-08-14, gh338 escalation)*: Can C2.3's no-write proof
  actually observe every class of write it claims to cover? — FAIL (missing:
  `snapshotTree` records content hashes and a file-only path list, so
  `writeSpecBody`'s `fs.chmodSync` and `mkdirp`'s empty directories are both
  invisible to it) — revised in place: C2.3 now requires a mode- and
  directory-aware snapshot, with C2.15 guarding Step 1's three existing call
  sites against the widening.
- **CHK17** *(added 2026-08-14, gh338 escalation)*: Is C2.13's site-12 fixture
  specified tightly enough that it cannot pass without reaching site 12? —
  PASS, but only after revision: the vacuity mode is real and was measured
  (with an ambient `HOME` the branch is skipped entirely and the assertions
  still hold), so C2.13 mandates `HOME` isolation, an explicitly disabled
  plugin, a present `.claude/settings.json`, and a live-run mutation control.
  C2.11 gained the inverse `HOME` requirement for the same reason.
- **CHK18** *(added 2026-08-14, gh338 escalation)*: Does behaviour item 3's
  "zero filesystem writes" claim survive the F-E ruling that
  `printUnifiedDiff`'s tmpdir writes stay? — FAIL (conflicting: an absolute
  "anywhere" claim alongside a decision to keep two writes) — revised in
  place: item 3 is rescoped to the project root, with the carve-out stated and
  marked as a recorded decision so a reviewer does not re-litigate it.
- **CHK19** *(added 2026-08-14, gh338 escalation)*: Is the rewritten exit-code
  rule actually implementable, or does it demand a predicate some site cannot
  supply without writing? — PASS (checked site by site on 2026-08-14 and
  recorded in Context: sites 5 and 12 already compute their answer into a deep
  copy before writing, sites 10/11 reduce to a string comparison against the
  file's current bytes, site 1's predicate is the `existsSync` already
  guarding it, sites 2-4 are the two helpers behaviour item 6 already covers,
  and sites 6-9 already compute `cleanHash` before deciding. No site needs a
  speculative write to learn its own answer.)
- **CHK20** *(added 2026-08-14, gh338 escalation)*: Does tightening exit `0`
  break the "genuinely current → 0" row C2.12 already pins? — PASS (measured
  2026-08-14: a baseline with hashes intact, `.gitignore` populated and no
  `.claude/settings.json` exits `0` with a whole-tree snapshot unchanged,
  under both plain `--update` and `--check`. C2.14 row 1 re-pins it as the
  non-vacuity control, without which an implementation that always exits `3`
  would pass every other row.)

## Scribe update hint

After Step 3 lands, `CONTEXT.md`'s `## Language` section is the canonical
record for this change; no ADR is warranted (this is a CLI-surface fix, not an
architectural decision, and it does not reverse a recorded one). If Open
Question 1 resolves to **(b) hard refusal**, that *does* warrant an ADR —
removing a working flag from a shipped CLI is a compatibility decision with a
rejected alternative worth recording. Per the repo's own numbering rule,
re-derive the next free ADR number at execution time and never backfill the
deliberately-preserved `0007` hole.

## Handoff

Three dispatchable units, strictly sequential (Step 1 → Step 2 → Step 3).
Above the ≤2-unit fast-path threshold, so `task-master` slices this with
`to-tickets`, assigns per-unit model tags, and writes the per-unit dispatch
prompts.

**Binding constraint on `task-master`:** no unit here may be tagged `haiku`.
Sonnet is the floor for all three; opus is recommended for Step 2. This is
issue #289's explicit instruction, backed by 21 `.fail` records mentioning
`bin/cli.js` out of 47 total.

**Step 2 must not be dispatched until Open Question 1 is answered.**
