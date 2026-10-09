# Backlog cleanup after the haiku-default and contract-score-guard stages (2026-10-09)

Status: FINAL (standard path: 7 dispatchable units plus 3 human-only units, so
task-master slices the 7 and writes their contracts; the 3 human-only units are
reports for the hook owner and are never dispatched to an agent). Written at
HEAD 94d6b22, version 0.31.147, after csg-1/csg-2 PASS and csg-3 committed.
Parents (cited, not restated): `docs/plans/2026-10-08-haiku-default-cleanup.md`
(hdc-1..hdc-6), `docs/plans/2026-10-08-contract-score-guard.md` (csg-1..csg-4),
`docs/plans/2026-10-07-final-cleanup.md` (process rules P1-P5).

## Goal

Close the twelve backlog items the hdc-1..hdc-6 reviews left behind. Each goal
clause maps to one unit and to that unit's criteria.

1. (G1) The hdc-3 migration guard can no longer skip silently: the check fails
   when lead-programmer's shipped frontmatter is not `haiku`. (blc-1, AC1.2)
2. (G2) The migrate-twice test proves idempotence on the full render loop, not
   on the "already current" early return. (blc-1, AC1.3, AC1.4)
3. (G3) A fix-round commit cannot escape a unit's range criteria: every unit
   commit carries the unit id as its subject scope, the range end is found with
   an anchored pattern, and contracts carry an untagged-tail criterion. (blc-5)
4. (G4) `templates/protocol-digest.md` keeps all six rules in at most 15
   non-empty body lines, and a test enforces the budget. (blc-6)
5. (G5) Ladder exhaustion is defined the same way in `agents/orchestrator.md`
   (At the 2-FAIL cap), the digest and `templates/persona-protocol.md`:
   the unit's FAIL-block count reaching or exceeding the ladder's length. (blc-6)
6. (G6) `commands/start-feature-team.md` says whether a same-tier retry reuses
   the teammate and what a fresh spawn is named. (blc-2)
7. (G7) CONTEXT.md's **defaultImplementerModel** entry says a `Suggested model`
   tag can only raise the tier. (blc-7)
8. (G8) The hdc-5 proof line no longer attributes hdc-4's measurement to hdc-5.
   (blc-4)
9. (G9) The Codex and Cursor ports keep the per-unit cap and say why: they have
   no implementer tiers. (blc-3)
10. (G10) The five finished stage plans of the haiku programme carry a closed
    status. (blc-4)
11. (G11) No `docs/plans/` contract still holds the model-name placeholder in
    its trailer line. (blc-4)
12. (G12) The three hook defects are filed as human-only reports with
    reproductions and acceptance-criteria shapes. (blc-h1, blc-h2, blc-h3)

## Context

### Sources

The items come from the reviewers' non-blocking notes on the hdc units and
from the user's own observations (item 12):

| item | source |
|---|---|
| 1 | hdc-3 PASS note: `tests/default-implementer-model.test.js:269` guard is conditional on `frontmatter === 'haiku'` |
| 2 | hdc-3 PASS note: the byte-identical assertion is met by `runUpdate`'s early return (`bin/cli.js:1485`) |
| 3 | hdc-5 PASS note: a fix-round commit without `(hdc-5)` after the last tagged commit is outside the range; fc-2 PASS note: `-F --grep='(<unit-id>)'` also matches a later commit that only mentions the id |
| 4 | hdc-2 PASS note: digest is 28 lines against its header's "under ~15 lines" |
| 5 | hdc-1 and hdc-2 PASS notes: `agents/orchestrator.md:362`, digest :18 and `templates/persona-protocol.md:708` say "second FAIL on the top tier"; `agents/orchestrator.md` (Check for a prior `.fail` record) and CONTEXT.md **ladder exhaustion** say "reaches or exceeds the ladder's length" |
| 6 | hdc-2 PASS note: `commands/start-feature-team.md:48-52` needs a fresh spawn per attempt and says nothing about same-tier reuse or the new name |
| 7 | hdc-1/hdc-5 notes and the hdc plan's Scribe update hint ("R5's **defaultImplementerModel** qualifier") |
| 8 | hdc-5 PASS note: proof line (plan :989) "dropping 789725d's printed `0 `"; 789725d is hdc-4 |
| 9 | hdc-2 PASS note: `adapters/cursor/agents/orchestrator.md:122`, `adapters/codex/agents/orchestrator.toml:126` keep "2 FAILs on the same unit" |
| 10 | user: older stage notes need status cleanup |
| 11 | the hdc plan's Ruling fixed the trailer line only for hdc-3 (and hdc-6 was written after it) |
| 12 | user observations, plus two reproductions measured while writing this plan (blc-h3) |

### Measured facts (2026-10-09, HEAD 94d6b22)

- **F1 (item 2).** A second `node bin/cli.js --update --force-render` after the
  migration runs the full loop (stdout `update complete`), leaves
  `persona-config.json` byte-identical and prints no migration note. Mutation
  measured in a scratch copy: inserting `if (config.defaultImplementerModel ===
  'haiku') config.defaultImplementerModel = 'opus';` before the migration
  assignment in `applyImplementerModelMigration` is **not** caught by a plain
  second `--update` (byte-identical: true, the early return discards it) and
  **is** caught by `--update --force-render` (byte-identical: false).
- **F2 (item 1).** With `model: sonnet` in a scratch copy of
  `agents/lead-programmer.md`, the check `--update applies
  migrateDefaultImplementerModel to an old-version "sonnet" config` prints `OK`
  today (the guard is skipped).
- **F3 (item 3).** `git log -E --grep='^[a-z]+\(hdc-5\): '` lists exactly
  b3cdba8 and 082ec3c, the same as the `-F` form for this unit, so the anchored
  form loses nothing on today's history while excluding commits that only
  mention the id.
- **F4 (item 4).** No test pins the digest's content. `tests/cli-backfill.test.js`
  pins only the path `.claude/protocol-digest.md`; `tests/filehashes-currency.test.js`
  guards the mirror hash. `hooks/scripts/session-start.sh:63-65` injects the
  whole mirror file, header comment included. `tests/protocol-doc-drift.test.js`
  is run by `tests/validate.sh:891`.
- **F5 (item 5).** No test pins "second FAIL on the ladder's top tier" or the
  digest's gloss. `tests/writer-tier-consistency.test.js:194` pins `At the 2-FAIL
  cap` and `**Escalation ladder.**` in `agents/orchestrator.md`; both stay.
  The template change reaches `.claude/persona-protocol.md` and the inlined
  protocol blocks of `.claude/agents/*.md` through `node bin/cli.js --update`.
- **F6 (item 9).** Every Cursor agent ships `model: inherit`
  (`docs/cursor-port-notes.md:66`, row 6: model-tier mapping not resolved), and
  the Codex agent files omit `model` (`adapters/codex/agents/lead-programmer.toml:12`).
  No test pins the ports' cap text; `tests/adapter-protocol-parity.test.js`
  asserts other literal strings, so it must still pass.
- **F7 (item 11).** `git grep 'your model name'` finds the placeholder only in
  `docs/plans/2026-10-08-haiku-default-cleanup.md`, lines 251 (hdc-1), 423
  (hdc-2), 780 (hdc-4) and 949 (hdc-5), all landed and PASSed. Their first
  commits (c759936, cd2c895, 789725d, b3cdba8) all carry
  `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>`; 082ec3c (hdc-5's
  fix round) carries `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- **F8 (item 10).** The five stage plans (`2026-10-06-rubric-gated-haiku-programme`,
  `2026-10-06-contract-hardening`, `2026-10-07-final-cleanup`,
  `2026-10-08-haiku-default-tier`, `2026-10-08-haiku-default-cleanup`) each
  have a line starting `Status: FINAL (` and no closed status. Their units are
  all reviewer-PASSed, except the rubric programme's Stage 4 (parked) and
  Stage 5 (superseded). Reviewer notes and plans cite line numbers in these
  files (for example `2026-10-07-final-cleanup.md:114-118`, hdc plan `:958-962`
  and `:989`), so the status edit must not shift any line.
- **F9 (item 12, premise correction).** `.claude/persona-config.json` has
  `"protectedPaths": []`: nothing mechanically stops a lead-programmer from
  editing `hooks/scripts/*`. The user's routing (hook defects are human-only
  units, not lead-programmer work) is kept as a decision, not as a mechanical
  fact.
- **F10 (blc-h3 reproductions).** While writing this plan, harness-integrity-gate
  denied two read-only spec-master Bash calls as "audit/config surface (Set A)":
  (a) `cd <repo>; node -e '<require of the persona config, console.log of two keys>' | cut -c1-900; grep -n ... hooks/scripts/harness-integrity-gate.sh | head -8; ...`
  and (b) `cd <repo>; grep -n "protectedPaths" -A3 <the persona config> | head -40`.
  Neither writes anything. `harness-integrity-gate.sh:288-296`: any command
  whose text names the config is denied unless `command_is_provably_benign` or
  `is_benign_jq_read` accepts it, and a compound command (a `cd ...;` prefix,
  a pipe) fails both.
- **F11.** csg-2 landed (c196719, 0.31.147): the contract-score guard runs
  before every `haiku` dispatch, and a contract below 7/7 sends the unit to the
  `sonnet` ladder. csg-3 (94d6b22) and csg-4 (c63cf7f, CONTEXT.md) were
  committed while this plan was written; their reviews were not yet recorded.
  blc-7 waits for csg-4's PASS, not just its commit.

### Decisions

- **D1 (item 1).** Make the guard loud: replace the `if (frontmatter ===
  'haiku')` block with an unconditional `assert.strictEqual(frontmatter,
  'haiku', ...)`. A deliberate change of the shipped default tier must then
  edit this check in the same change, which is the intent.
- **D2 (item 2).** The second run in the migrate-twice test passes
  `--force-render` and asserts stdout contains `update complete`, and the first
  run's result is asserted to be `haiku`. The existing byte-identical and
  no-note assertions stay.
- **D3 (item 3, plus the fc-2 note).** Three rules, all instruction-level, all
  in agents/*.md: (a) task-master's Range criteria find a unit's commits with
  `git log --format=%H -E --grep='^[a-z]+\(<unit-id>\): '` (`tail -1` for the
  start, `head -1` for the end), not `-F --grep='(<unit-id>)'`; (b) every
  commit of a unit, fix rounds included, carries `(<unit-id>)` as its subject
  scope, in task-master's fix contracts, in lead-programmer's no-contract fix
  turns and in scribe's no-contract commits; (c) every range contract adds an
  untagged-tail criterion run at review time over the unit's content files.
  No hook is added (OQ3 of the rubric programme, closed by csg-2: `dispatchHygiene`
  stays `warn`).
- **D4 (item 4).** The budget is mechanical: at most 15 non-empty lines after
  the header comment's closing `-->` (21 today). The trimmed body has 15. A new check in
  `tests/protocol-doc-drift.test.js` enforces it. All six rules stay.
- **D5 (item 5).** One phrase in all three places: "reaching or exceeding the
  ladder's length", glossed as normally the second FAIL on the ladder's top
  tier. The digest and the template are edited in the same unit as the
  orchestrator line, so items 4 and 5 are one unit (blc-6).
- **D6 (item 6).** A same-tier retry resumes the teammate that made the failed
  attempt with `SendMessage`; a tier change, or a teammate that is gone, gets a
  fresh spawn named `lead-programmer-<task-id>-<n+1>` (n = the unit's FAIL-block
  count). This matches the shared protocol ("prefer resuming the same
  lead-programmer session") and the command's own rule at :71-74 (resume an
  idle teammate with `SendMessage`, never re-invoke `Agent` by name).
- **D7 (item 9).** Record why not, do not port the ladder: the ports have no
  per-dispatch model choice (F6). Each of the four cap sites gains one
  sentence; each port-notes doc gains a short section.
- **D8 (item 10).** Status edits never shift a line (F8): the `Status: FINAL (`
  prefix becomes `Status: CLOSED 2026-10-09 (see the Status update at the end).
  FINAL (` on the same line, and a `## Status update (2026-10-09)` section is
  appended at the end of each file. Scope is the five plans of F8; older plans
  are out of scope.
- **D9 (item 11).** The four landed contracts get the trailer their first
  commit actually carries (F7), and the hdc plan's appended status section
  records the sweep. This supersedes the hdc Ruling's "left as it was" for the
  trailer text only, at the user's request; nothing else in those contracts
  changes.
- **D10 (item 12).** Three human-only units, one per defect. Each carries a
  reproduction (or the instruction to capture one), the suspected site and an
  acceptance-criteria shape. They are never dispatched to lead-programmer.
- **D11 (version chain).** The two stamped units run serially after csg-2:
  blc-5 bumps to 0.31.148, blc-6 to 0.31.149. If HEAD's version is not the
  predecessor's when a stamped unit is dispatched, task-master re-derives
  (`node -p "require('./.claude-plugin/plugin.json').version"`, patch +1) and
  the contract's version lines are rewritten before dispatch.
- **D12 (this plan's own contracts).** Rule D3 applies to this plan's contracts
  from the start: they use the anchored range pattern and the untagged-tail
  criterion, even though blc-5 has not landed when task-master writes them.

### Domain model (inline, per grill-with-docs)

No CONTEXT.md term is resolved or added by this session beyond blc-7's
qualifier. The new working terms ("fix round", "untagged-tail criterion",
"unit range") are harness mechanics: if scribe records them, they belong in
`docs/harness-glossary.md`, not CONTEXT.md. No decision here meets all three
ADR tests: D3 and D6 are reversible prose rules, D7 records a port limitation
already in the port notes.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-09 Functional scope & success criteria: Q item 10 says "older stage
  notes": which plans, and what is a status cleanup? → A (self-resolved): the
  five stage plans of the haiku programme (F8); a same-line `CLOSED` prefix plus
  an appended status section (D8).
- 2026-10-09 Functional scope & success criteria: Q item 11 asks to sweep the
  remaining contracts, but the hdc Ruling left the landed trailer text as it
  was: rewrite or annotate? → A (self-resolved): rewrite the placeholder with
  the measured trailer of each unit's first commit and record the sweep (D9).
- 2026-10-09 User interaction flow: Q in agent-teams mode, does a same-tier
  retry reuse the teammate, and what is a fresh spawn named? → A
  (self-resolved): reuse via `SendMessage`; fresh spawn on a tier change named
  `lead-programmer-<task-id>-<n+1>` (D6).
- 2026-10-09 External dependencies & integrations: Q should the Codex and
  Cursor ports get the Escalation ladder? → A (self-resolved): no; they have no
  model tiers (F6), so record why (D7).
- 2026-10-09 Edge cases / failure handling: Q a fix-round commit lacking the
  unit tag escapes range checks: fix by rule, by criterion or by hook? → A
  (self-resolved): rule plus anchored pattern plus untagged-tail criterion, no
  hook (D3).
- 2026-10-09 Edge cases / failure handling: Q item 1 says "fail loud or assert
  intentionally": which? → A (self-resolved): fail loud (D1).
- 2026-10-09 Technical constraints & tradeoffs: Q the digest header says
  "under ~15 lines": whole file or body? → A (self-resolved): at most 15
  non-empty lines after the header comment, enforced by a test (D4).
- 2026-10-09 Technical constraints & tradeoffs: Q items 4 and 5 both edit the
  digest, and the stamped units share plugin.json, package.json, CHANGELOG.md
  and the `.claude/` mirrors: how are they split? → A (self-resolved): items 4
  and 5 are one unit; the two stamped units run serially (D11).
- 2026-10-09 Technical constraints & tradeoffs: Q editing a status line shifts
  line numbers that other documents cite: how to avoid it? → A
  (self-resolved): same-line prefix plus an appended section (D8).
- 2026-10-09 Terminology consistency: Q the request says "per-unit cap" and
  "hook-owner": glossary terms? → A (self-resolved): the glossary's 2-FAIL cap
  is per tier; the ports' cap is described as the older per-unit cap, never as
  "the 2-FAIL cap"; "human-only unit" replaces "hook-owner unit".
- 2026-10-09 Completion / acceptance signals: Q what closes a human-only unit?
  → A (self-resolved): the hook owner's own commit with a failing-then-passing
  row in the gate's test suite and `bash tests/validate.sh` exit 0; the
  acceptance shapes are in each blc-h unit.
- 2026-10-09 Completion / acceptance signals: Q this plan has more than 5
  units: who writes the contracts? → A (self-resolved): task-master, standard
  path, every contract scoring 7/7 under rubric v2 (the csg guard otherwise
  moves the unit to the `sonnet` ladder).

## Risks / dependencies

- **R1 (coordinate-free).** Files owned by csg units are not touched:
  `bin/contract-guard.js`, `tests/contract-score.test.js`, the **Contract-score
  guard** paragraph of `agents/orchestrator.md`, `docs/adr/0040-implementer-tier-haiku-default.md`,
  and the csg-4 CONTEXT.md entries (**Contract-score guard**, and its edits to
  **default tier** and **Haiku-default cutover**). blc-6 edits a different
  paragraph of `agents/orchestrator.md` (At the 2-FAIL cap): Depends-on csg-2.
  blc-7 edits a different CONTEXT.md entry (**defaultImplementerModel**):
  Depends-on csg-4.
- **R2 (version anchor).** Every stamped unit's `--update` rewrites
  `.claude/persona-config.json` (pluginVersion, fileHashes) and the version-
  stamped mirrors. So blc-5 and blc-6 never run concurrently with each other or
  with any other unit that runs `--update`, and the human-only hook units, if
  their fixes touch `.claude/hooks/` mirrors and fileHashes, land outside the
  blc-5 → blc-6 window.
- **R3 (prior FAIL history).** No `blc-*.fail` exists. Units in the same files
  have FAILed before, with classes from the unit-outcome export: `vacuous` on
  `agents/orchestrator.md` (gh307, gh310, gh348-14, gh429), on
  `templates/persona-protocol.md` and both protocol ports (gh348-3, mw-step1..3),
  on `agents/lead-programmer.md`/`agents/scribe.md` (item17-3), on CONTEXT.md
  (gh303, gh354, gh409, spec2-unitA/B and others); `host` on CONTEXT.md
  (ci-fetch-depth-cleanup, gh426) and on the ports (examples-2). Every criterion
  below on those files carries a measured or stated mutation; task-master keeps
  them. No unit here is a re-scope of a FAILed unit, so no tier ratchet applies.
- **R4 (marker-audit sweep, best-effort).** `bash bin/marker-audit.sh .
  --notes --surface=<path>` was run for every surface. Eight of fourteen
  surfaces timed out at 60 s (`Terminated`), so the sweep is incomplete and an
  empty result proves nothing. Dispositions of what it returned:
  `agents/task-master.md` fc-2 NOTE[spec] on the `-F --grep` range end matching
  later mentions: **folded into blc-5** (D3a). fc-2 NOTE[spec] on the
  `## Dispatch contract` selector prefix and on the wrapped `- <ruling-id>:`
  literal: out of scope (not items of this backlog). `adapters` untagged notes
  (units 128, 144, 145) concern the hook ports and the parity probe strings:
  out of scope, but blc-3 must keep `tests/adapter-protocol-parity.test.js`
  green (unit 128's note: probe strings must exist in the port files).
  CONTEXT.md untagged notes (units 137, 165): out of scope.
- **R5 (tracker).** The htd slice recorded that `gh issue create` was denied
  by the permission classifier. If that recurs, task-master falls back to the
  plan file as the retrieval contract (as htd and hdc did) and says so.
- **R6 (validate.sh cost).** Each unit's last criterion is the full `bash
  tests/validate.sh` (about 11 minutes), run by the orchestrator in the main
  checkout. With parallel units, a red run is attributed by the reviewer from
  the failing check's file.
- **R7 (gate friction).** Authoring blc-4 and blc-7 may trip
  human-decision-gate or reviewed-path-gate on prose; the sanctioned routes
  are `git commit -F <file>` and Write/Edit, never rephrasing to dodge a scan.
  blc-h3's reproductions cannot be run by an agent at all: the gate denies
  them.
- **R8 (tombstones, observation only).** `.claude/` holds 87
  `.pending-review-cleared.*` tombstones (esf-flag-fix). Not an item here; may
  inform blc-h1.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied (F1, F2, F3 and F7 were measured; every criterion has a mutation, measured where stated)
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied (mirrors are regenerated only by `node bin/cli.js --update`; no hand edit of `.claude/` mirrors or `persona-config.json`)
- P3 "Version-stamp discipline": satisfied (blc-5 and blc-6 bump plugin.json and package.json and add a CHANGELOG entry in the same commit as the stamped edit, checked per commit; the other units touch no `agents/*.md` or `templates/*` file)
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied (blc-2's new paragraph names no optional persona in backticks; blc-5's scribe and task-master sentences sit inside those personas' own files)
- P5 "`tests/validate.sh` is the merge gate": satisfied (last criterion of every dispatchable unit)

## Steps

### Unit table and Depends-on graph

| unit | persona | items | files (content) | stamped | Depends-on |
|---|---|---|---|---|---|
| blc-1 | lead-programmer | 1, 2 | `tests/default-implementer-model.test.js` | no | none |
| blc-2 | lead-programmer | 6 | `commands/start-feature-team.md` | no | none |
| blc-3 | lead-programmer | 9 | `adapters/codex/agents-md-fragment.md`, `adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md`, `adapters/cursor/rules/persona-protocol.mdc`, `docs/codex-port-notes.md`, `docs/cursor-port-notes.md` | no | none |
| blc-4 | lead-programmer | 8, 10, 11 | the five plans of F8 | no | none |
| blc-5 | lead-programmer | 3 | `agents/task-master.md`, `agents/lead-programmer.md`, `agents/scribe.md` (+ plugin.json, package.json, CHANGELOG.md, `.claude/` via `--update`) | 0.31.148 | csg-2 (PASS) |
| blc-6 | lead-programmer | 4, 5 | `templates/protocol-digest.md`, `templates/persona-protocol.md`, `agents/orchestrator.md`, `tests/protocol-doc-drift.test.js` (+ version files, `.claude/`) | 0.31.149 | csg-2 (PASS), blc-5 |
| blc-7 | scribe | 7 | `CONTEXT.md` | no | csg-4 |
| blc-h1 | human-only | 12a | `hooks/scripts/stop-gate.sh` and/or `hooks/scripts/lib/stop-gate-core.sh`, `tests/pending-review-resurrection.test.sh` | n/a | none (R2 window) |
| blc-h2 | human-only | 12b | `hooks/scripts/human-decision-gate.sh`, `tests/human-decision-gate.test.sh` | n/a | none (R2 window) |
| blc-h3 | human-only | 12c | `hooks/scripts/harness-integrity-gate.sh`, `tests/harness-integrity-gate.test.sh` | n/a | none (R2 window) |

```
csg-2 (PASS) ──> blc-5 ──> blc-6
csg-4 ─────────> blc-7
blc-1, blc-2, blc-3, blc-4: no edges, dispatchable in parallel now
blc-h1, blc-h2, blc-h3: human-only; no edges, but not inside the blc-5/blc-6 window (R2)
```

The four parallel units and blc-5 are mutually file-disjoint in content
files. blc-5 and blc-6 share only the version files and `.claude/` mirrors,
hence the serial edge. blc-6 is the only unit that edits `agents/orchestrator.md`;
blc-7 is the only unit that edits CONTEXT.md (P3 analogue of the fc plan).

### Shared criteria for every dispatchable unit

`<id>` is the unit id. `<content>` is the unit's content files from the table
(never the version files or `.claude/`). `<issue>` is the issue number
task-master assigns. These replace the fc plan's P1 range form (D12). Every
bare `grep` in this plan's criteria is written `/usr/bin/grep` in the
contracts: an inline `grep` in an agent's Bash is a wrapper with different
regex semantics, and the BRE patterns here (a literal `(` in AC4.4) assume GNU
grep.

- S1 run: `U=$(git log --format=%H -E --grep='^[a-z]+\(<id>\): ' | head -1); B=$(git log --format=%H -E --grep='^[a-z]+\(<id>\): ' | tail -1)~1; git log --format=%s "$B..$U" | grep -vcE '^[a-z]+\(<id>\): .+ \(#<issue>\)$'`; exit 1; stdout `0`; mutation: a commit subject lacking ` (#<issue>)` prints `1`, exit 0.
- S2 run: the per-commit trailer form of the hdc Ruling over `$B..$U` (anchored pattern): `for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`; exit 0; stdout `1 `; mutation: drop one commit's trailer, prints `0 1 ` (or `0 `).
- S3 (untagged tail, D3c) run: `git log --format=%s "$U"..HEAD -- <content> | grep -vcE '^[a-z]+\(<id>\): '`, run at review time; exit 1; stdout `0`; mutation: add a fix commit touching a content file with subject `fix: <anything>`, prints `1`, exit 0.
- S4 run: `git diff --name-only "$B..$U" | grep -v '^\.claude/' | sort` equals the unit's file list (content plus, for stamped units, `.claude-plugin/plugin.json`, `CHANGELOG.md`, `package.json`); mutation: touch one extra file, the diff fails.
- S5 run: `git status --porcelain --untracked-files=no | wc -l`; exit 0; stdout `0`; mutation: leave a content file unstaged, prints `1`.
- S6 run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`; exit 0; stdout `validate-exit=0`; mutation: hand-edit one line of a `.claude/agents/*.md` mirror, prints `validate-exit=1`. Run by the orchestrator in the main checkout.
- Stamped units only (P4 of the fc plan): S7 `bash hooks/scripts/version-stamp-check.sh "$B..$U" | grep -c '^version-stamp-check: ok'` prints `1`; S8 the version-sync `node -e` check of the csg-2 contract, criterion 6, with the unit's version; S9 `git diff --name-only "$B..$U" -- .claude | wc -l` prints the mirror count task-master measures at slicing; S10 `node bin/cli.js --update` in the finished tree prints `already current`.

### Step 1 (blc-1): loud guard and real idempotence (items 1, 2)

Affected files: `tests/default-implementer-model.test.js` only. TDD: the edit
is the test; its red state is shown by the mutations, measured in F1/F2.

Edit 1.1, anchor: line matching `    if (frontmatter === 'haiku') {` (three lines):
```
    if (frontmatter === 'haiku') {
      assert.strictEqual(expected, 'haiku', 'lead-programmer ships model: haiku, so an old-version "sonnet" must migrate; IMPLEMENTER_HAIKU_DEFAULT_SINCE is disabled');
    }
```
becomes
```
    assert.strictEqual(frontmatter, 'haiku', 'agents/lead-programmer.md must ship model: haiku; if the shipped default tier changed on purpose, rewrite this check together with IMPLEMENTER_HAIKU_DEFAULT_SINCE');
    assert.strictEqual(expected, 'haiku', 'an old-version "sonnet" must migrate to "haiku"; if it does not, IMPLEMENTER_HAIKU_DEFAULT_SINCE is disabled');
```
Edit 1.2, anchor: line matching `    const afterFirst = fs.readFileSync(configPath, 'utf8');` (four lines from it):
```
    const afterFirst = fs.readFileSync(configPath, 'utf8');

    const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
```
becomes
```
    const afterFirst = fs.readFileSync(configPath, 'utf8');
    assert.strictEqual(JSON.parse(afterFirst).defaultImplementerModel, 'haiku', 'the first --update must apply the migration');

    // --force-render skips runUpdate's "already current" early return, so a
    // change the second run makes to the config is written and seen below.
    const second = spawnSync('node', [cliPath, '--update', '--force-render'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
    assert.ok(second.stdout.includes('update complete'), `the second --update must run the full render loop, got: ${second.stdout}`);
```
Check titles stay unchanged (AC1.2 greps one of them).

Acceptance criteria:
- AC1.1 run: `node tests/default-implementer-model.test.js > /dev/null 2>&1; echo exit=$?`; exit 0; stdout `exit=0`; mutation: skip edit 1.2 and add the F1 cli mutation, still `exit=0` (gap); with edit 1.2, `exit=1`.
- AC1.2 run: `D=$(mktemp -d) && git worktree add --detach -q "$D" HEAD && sed -i 's/^model: haiku$/model: sonnet/' "$D/agents/lead-programmer.md" && node "$D/tests/default-implementer-model.test.js" | grep -c '^FAIL --update applies migrateDefaultImplementerModel to an old-version'; git worktree remove --force "$D"`; exit 0; stdout `1`; mutation: skip edit 1.1, prints `0` (measured, F2).
- AC1.3 run: `grep -c "'--update', '--force-render'" tests/default-implementer-model.test.js`; exit 0; stdout `1`; mutation: skip edit 1.2, prints `0`, exit 1.
- AC1.4 run: `grep -c "if (frontmatter === 'haiku')" tests/default-implementer-model.test.js`; exit 1; stdout `0`; mutation: skip edit 1.1, prints `1`.
- S1-S6.

### Step 2 (blc-2): same-tier retry in agent-teams mode (item 6)

Affected files: `commands/start-feature-team.md` only. Not stamped (P3 covers
`agents/*.md` and `templates/*` only); no version bump.

Edit 2.1: in the **Writer/Reviewer split** paragraph, the clause "and pass that
tier as the `model` parameter of the `Agent` call that spawns the
lead-programmer teammate for the unit's next attempt." becomes "and, when the
next attempt needs a new teammate (**Same-tier retry** below), pass that tier
as the `model` parameter of the `Agent` call that spawns it." (task-master
gives the literal wrapped lines.)

Edit 2.2: insert after the paragraph ending `` `impl:*` from completing without a matching marker. ``:
```

**Same-tier retry.** A teammate's model is fixed when it spawns, so the next
attempt reuses or replaces the lead-programmer teammate by tier. When the
unit's next tier is the tier of the teammate that made the failed attempt (a
first FAIL on that tier), resume that teammate with `SendMessage`, carrying the
defect list or the fix contract; do not spawn a new one. When the tier changes,
or that teammate is gone (crashed or shut down), spawn a fresh lead-programmer
teammate with the new tier as the `model` parameter, named
`lead-programmer-<task-id>-<n+1>`, where n is the unit's FAIL-block count, so
no two attempts share a name.
```

Acceptance criteria:
- AC2.1 run: `for p in '**Same-tier retry.**' 'resume that teammate with' 'lead-programmer-<task-id>-<n+1>' 'needs a new teammate'; do tr '\n' ' ' < commands/start-feature-team.md | tr -s ' ' | grep -oF -- "$p" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 1 1 ` (edit 2.1's pointer has no period, so only edit 2.2's heading matches the first phrase; all four print `0` at HEAD 94d6b22); mutation: skip edit 2.2, prints `0 0 0 1 `; skip edit 2.1, prints `1 1 1 0 `.
- AC2.2 run: `tr '\n' ' ' < commands/start-feature-team.md | tr -s ' ' | grep -cF "call that spawns the lead-programmer teammate for the unit's next attempt"`; exit 1; stdout `0`; mutation: skip edit 2.1, prints `1`.
- S1-S6 (S6 includes `tests/validate.sh`'s P4 conditional-phrasing paragraph check over this file, line 255).

### Step 3 (blc-3): ports record why the cap stays per unit (item 9)

Affected files: the six of the table. Not stamped.

Edits (the sentence is identical except for the notes file it cites):
- 3.1 `adapters/codex/agents-md-fragment.md`, after the line ending `A unit that fails twice usually means the plan itself has a gap.`: append to that paragraph `This port keeps the cap per unit, not per implementer tier: its agents inherit the session's model, so there are no implementer tiers to climb and the Escalation ladder is not ported (see docs/codex-port-notes.md).` (wrapped at 80 columns).
- 3.2 `adapters/cursor/rules/persona-protocol.mdc`: the same, citing `docs/cursor-port-notes.md`.
- 3.3 `adapters/codex/agents/orchestrator.toml` and 3.4 `adapters/cursor/agents/orchestrator.md`: after the line `  defect history to the user instead of a third pass.` insert `  (Per unit: agents here inherit the session's model, so there are no implementer tiers to climb.)`
- 3.5 `docs/codex-port-notes.md` and 3.6 `docs/cursor-port-notes.md`: append
```

## Escalation ladder (not ported)

The Claude Code orchestrator moves a failing unit up an Escalation ladder of
implementer tiers (`haiku`, `sonnet`, `opus`), two attempts per tier. This
port does not: its agents inherit the session's model, so there are no
implementer tiers to climb. It keeps the older cap of 2 FAILs per unit, after
which the orchestrator stops and asks the user. Port the ladder only once the
model-tier mapping is decided.
```
  plus one more line. Cursor file: Every Cursor agent ships `model: inherit` (row 6 above).
  Codex file: The Codex agent files omit `model` (adapters/codex/agents/lead-programmer.toml).

Acceptance criteria:
- AC3.1 run: `for f in adapters/codex/agents-md-fragment.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md adapters/cursor/rules/persona-protocol.mdc docs/codex-port-notes.md docs/cursor-port-notes.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oF 'no implementer tiers to climb' | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 1 1 1 1 `; mutation: skip any one edit, its position prints `0`.
- AC3.2 run: `cat docs/codex-port-notes.md docs/cursor-port-notes.md | grep -c '^## Escalation ladder (not ported)$'`; exit 0; stdout `2`; mutation: skip 3.5, prints `1`.
- AC3.3 run: `node tests/adapter-protocol-parity.test.js > /dev/null 2>&1; echo exit=$?`; exit 0; stdout `exit=0`; mutation: delete a pinned probe string from a port, prints `exit=1`.
- AC3.4 run: `grep -c 'Cap at 2 FAILs per unit' adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc | tr '\n' ' '`; exit 0; stdout `adapters/codex/agents-md-fragment.md:1 adapters/cursor/rules/persona-protocol.mdc:1 ` (the cap itself is unchanged); mutation: rewrite the heading to per tier, prints `:0`.
- S1-S6.

### Step 4 (blc-4): plan records: proof line, closed status, trailer sweep (items 8, 10, 11)

Affected files: the five plans of F8. No line may be inserted or deleted
above an existing line (D8): every edit is either a same-line substitution
or an append at the end of the file.

- 4.1 (item 8) `docs/plans/2026-10-08-haiku-default-cleanup.md`, the `proof:`
  line of hdc-5 criterion 7: the substring `, dropping 789725d's printed `0 `.`
  becomes `, and over hdc-4's one-commit range (the same `run:` with `(hdc-4)` in place of `(hdc-5)`) dropping 789725d's trailer printed `0 `.`
- 4.2 (item 11) same file: each of the four occurrences of
  `Co-Authored-By: Claude <your model name> <noreply@anthropic.com>` becomes
  `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` (F7).
- 4.3 (item 10) each of the five files: the prefix `Status: FINAL (` of the
  status line becomes `Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (`.
- 4.4 (item 10, 11) append to each file a section `## Status update (2026-10-09)`
  with one paragraph:
  - rubric programme: "Closed. Stages 0-3 are reviewer-PASSed (rgh-u0-1, rgh-u0-2, rgh-u0-2b, rgh-u0-3, rgh-u0-4, rgh-u1-1, rgh-u2-1, rgh-u2-2, rgh-u3-1 .. rgh-u3-4). Stage 4 (U4-1..U4-3) is parked and Stage 5 is superseded, as the 2026-10-08 note under the status line says. No unit of this plan is left to dispatch."
  - contract hardening: "Closed. Every unit is reviewer-PASSed (rgh-h1, rgh-h1b, rgh-h2 .. rgh-h12; H13 ran as rgh-h13a and rgh-h13b). The status line's 'Stages 4-5 and gates G3/G4 of the parent are untouched' was true when written; since 2026-10-08 the parent's Stage 4 is parked and its Stage 5 is superseded by docs/plans/2026-10-08-haiku-default-tier.md."
  - final cleanup: "Closed. fc-1 .. fc-5 are reviewer-PASSed. It was not the last cleanup stage after all: docs/plans/2026-10-08-haiku-default-cleanup.md and docs/plans/2026-10-09-backlog-cleanup.md followed at the user's request. Rule P1's `-F --grep` range form is replaced by the anchored form of docs/plans/2026-10-09-backlog-cleanup.md, D3."
  - haiku-default tier: "Closed. htd-1 .. htd-7 are reviewer-PASSed. Follow-ups: docs/plans/2026-10-08-haiku-default-cleanup.md, docs/plans/2026-10-08-contract-score-guard.md and docs/plans/2026-10-09-backlog-cleanup.md."
  - haiku-default cleanup: "Closed. hdc-1 .. hdc-6 are reviewer-PASSed; hdc-5 passed after two FAILs, the second a contract defect (see the Ruling). The reviewers' remaining notes are carried by docs/plans/2026-10-09-backlog-cleanup.md. Trailer sweep (blc-4): the hdc-1, hdc-2, hdc-4 and hdc-5 contracts gave a placeholder instead of a model name in their trailer line; each now names the trailer its first commit carries (Claude Haiku 4.5 for all four, measured with git log). hdc-5's fix-round commit 082ec3c carries the Claude Sonnet 5.5 trailer: a fix round's trailer names the model of its own tier. No other docs/plans contract held the placeholder."

Acceptance criteria:
- AC4.1 run: `git grep -c 'your model name' -- docs/plans ':!docs/plans/2026-10-09-backlog-cleanup.md' | wc -l`; exit 0; stdout `0`; mutation: skip one 4.2 substitution, prints `1`. (This plan itself spells the placeholder, hence the exclusion; the appended status text never does.)
- AC4.2 run: `grep -c 'Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>' docs/plans/2026-10-08-haiku-default-cleanup.md`; exit 0; stdout `4`; mutation: skip one 4.2 substitution, prints `3`.
- AC4.3 run: `grep -cF "dropping 789725d's printed" docs/plans/2026-10-08-haiku-default-cleanup.md; grep -cF "one-commit range (the same" docs/plans/2026-10-08-haiku-default-cleanup.md`; exit 0; stdout `0` then `1`; mutation: skip 4.1, prints `1` then `0` (exit 1).
- AC4.4 run: `for f in docs/plans/2026-10-06-rubric-gated-haiku-programme.md docs/plans/2026-10-06-contract-hardening.md docs/plans/2026-10-07-final-cleanup.md docs/plans/2026-10-08-haiku-default-tier.md docs/plans/2026-10-08-haiku-default-cleanup.md; do grep -c '^Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (' "$f"; grep -c '^## Status update (2026-10-09)$' "$f"; done | tr '\n' ' '`; exit 0; stdout `1 1 1 1 1 1 1 1 1 1 `; mutation: skip 4.3 or 4.4 for one file, a `0` appears.
- AC4.5 (no line shift) run: `B=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | tail -1)~1; U=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | head -1); git diff --numstat "$B..$U" | sort -k3 | awk '{print $1"/"$2}' | tr '\n' ' '`; exit 0; stdout `5/1 5/1 5/1 10/6 5/1 ` (path order: contract-hardening, rubric-gated, final-cleanup, haiku-default-cleanup, haiku-default-tier). Each appended section is exactly four lines (blank, heading, blank, the paragraph as ONE line); each file ends with a newline today (measured), so a file gains 1 + 4 lines and loses its 1 status line; the hdc file also swaps the proof line and four trailer lines (deleted 6, added 10). mutation: wrap a paragraph over two lines or insert a line above the end, a count changes (for example `6/1`).
- S1-S6.

### Step 5 (blc-5): unit commits carry their scope; anchored range pattern (item 3)

Affected files: `agents/task-master.md`, `agents/lead-programmer.md`,
`adapters/cursor/agents/lead-programmer.md`,
`adapters/codex/agents/lead-programmer.toml` (hand-maintained ports; added by
ruling H-BLC5), `agents/scribe.md`; plus `.claude-plugin/plugin.json` and `package.json`
(0.31.148), `CHANGELOG.md`, and the `.claude/` mirrors via `node bin/cli.js
--update` (staged with `git add -u -- .claude`), all in one commit (P3).

- 5.1 `agents/task-master.md`, **Range criteria** (lines 199-201 at HEAD):
  "binds its end to the unit's own last commit, `git log --format=%H -F
  --grep='(<unit-id>)' | head -1`, never `HEAD`." becomes "binds its start and
  end to the unit's own first and last commits, found with `git log
  --format=%H -E --grep='^[a-z]+\(<unit-id>\): '` (`tail -1`, `head -1`), never
  `HEAD`; the anchored pattern matches only a subject whose scope is the unit,
  never a later commit that merely mentions it. That end holds only if every
  commit of the unit, fix rounds included, carries `(<unit-id>)` as its subject
  scope, so every `commit-message:` line of a contract or fix contract does,
  and every range contract adds one untagged-tail criterion, run at review
  time over the unit's content files (never the version files or `.claude/`):
  `git log --format=%s <end>..HEAD -- <content files> | grep -vcE
  '^[a-z]+\(<unit-id>\): '`, `exit: 1`, `stdout: 0`."
- 5.2 `agents/task-master.md`, **Fix contract** bullet: after "`diagnosis:
  none`:" clause's sentence, add "Its `commit-message:` subject carries
  `(<unit-id>)` as its scope, like the original contract's."
- 5.3 `agents/lead-programmer.md`, **Fix turns**: after "A defect-list
  re-dispatch without a contract (task-master absent) leaves them in force."
  add "Every fix commit's subject carries `(<task-id>)` as its scope, like the
  unit's first commit, with or without a contract, so the unit's range
  criteria see it." The same sentence goes, at the same anchor, into
  `adapters/cursor/agents/lead-programmer.md` and
  `adapters/codex/agents/lead-programmer.toml`: the Fix-turns sentence sits
  inside the **Contract precedence** bullet, which
  `tests/writer-tier-consistency.test.js` AC-A1 requires to read identically in
  `agents/lead-programmer.md` and both ports (ruling H-BLC5).
- 5.4 `agents/scribe.md`, after `on top of the contract.` (end of the
  **Contract-only doc edits** paragraph) add the sentence "Without a contract,
  every commit of a unit, fix rounds included, carries `(<task-id>)` as its
  subject scope."
- 5.5 CHANGELOG entry under `## [Unreleased]`, version lines, `--update`.

Acceptance criteria:
- AC5.1 run: `for p in "fix rounds included, carries" "untagged-tail criterion" "merely mentions it"; do tr '\n' ' ' < agents/task-master.md | tr -s ' ' | grep -oF -- "$p" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 1 `; mutation: skip 5.1, prints `0 0 0 `.
- AC5.2 run: `grep -cF -- "-F --grep='(<unit-id>)'" agents/task-master.md`; exit 1; stdout `0`; mutation: skip 5.1, prints `1`, exit 0.
- AC5.3 run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | grep -oF 'as its scope, like the original contract' | wc -l`; exit 0; stdout `1`; mutation: skip 5.2, prints `0`.
- AC5.4 run: `for f in agents/lead-programmer.md agents/scribe.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oE "Every fix commit's subject carries|fix rounds included, carries" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 `; mutation: skip 5.3 or 5.4, its position prints `0`.
- AC5.5 run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1; echo exit=$?`; exit 0; stdout `exit=0` (AC-P2/AC-P3 pins and AC-A1 port parity kept); mutation: drop `- **Contract precedence.**` from lead-programmer.md, prints `exit=1`; skip the Cursor-port half of 5.3, prints `exit=1` (AC-A1).
- AC5.6 run: `for f in .claude/agents/task-master.md .claude/agents/scribe.md .claude/agents/lead-programmer.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oE "fix rounds included, carries|Every fix commit's subject carries" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 1 `; mutation: skip `--update`, prints `0 0 0 `.
- AC5.7 run: `for f in adapters/cursor/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oF "Every fix commit's subject carries" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 `; mutation: skip either port half of 5.3, its position prints `0` (and AC5.5 fails on AC-A1). Added by ruling H-BLC5.
- S1-S10 (S7-S10 with 0.31.148; S9 `14`, see Step 6).

### Step 6 (blc-6): digest within budget; one definition of ladder exhaustion (items 4, 5)

Affected files: `templates/protocol-digest.md`, `templates/persona-protocol.md`,
`agents/orchestrator.md`, `tests/protocol-doc-drift.test.js`; plus plugin.json,
package.json (0.31.149), CHANGELOG.md and `.claude/` via `--update`, in one
commit. TDD: edit 6.1 first, see AC6.1 red, then 6.2.

- 6.1 `tests/protocol-doc-drift.test.js`: before the final `if (failures) {`
  block add
```
check('templates/protocol-digest.md stays within its budget: at most 15 non-empty lines after the header comment', () => {
  const text = fs.readFileSync(path.join(REPO_ROOT, 'templates', 'protocol-digest.md'), 'utf8');
  const end = text.indexOf('-->');
  assert.ok(end >= 0, 'the digest must keep its header comment');
  const body = text.slice(end + 3).split('\n').filter((l) => l.trim() !== '');
  assert.ok(body.length <= 15, `digest body has ${body.length} non-empty lines; trim it or mechanize the rule (a hook) instead`);
});
```
- 6.2 `templates/protocol-digest.md`: header line 4 "Keep this under ~15 lines - if it grows," becomes "Keep the body to at most 15 non-empty lines (tested) - if it grows," (at most, not under: the test allows 15 and the new body has exactly 15); everything after the header comment becomes exactly
```

# Protocol digest (post-compaction/resume reminder)

- Structural questions (definitions, callers, blast radius, coverage): spawn
  `explorer`; never invoke the code-review-graph skill directly.
- Only the orchestrator/team lead routes between lead-programmer and reviewer.
  "Done" = reviewer PASS (a critical unit may first route through
  ESCALATE-TO-HUMAN).
- 2 FAILs per implementer tier move the unit up the Escalation ladder; only
  ladder exhaustion (FAIL count reaching or exceeding the ladder's length)
  stops re-delegation and surfaces the full defect history to the user.
- WIP sentinel `.claude/wip-handoff.<agent-id>`: genuine mid-task pause only,
  with a stated reason (empty is ignored); never to dodge a fixable red suite.
- `.claude/.pending-review.<id>` blocks turn-end and the next implementation
  dispatch until the reviewer runs or it holds `defer: <reason>`/`skip: <reason>`.
- `memory:` auto-grants Read/Write/Edit; that is not license to edit outside
  your role's stated scope.
```
  (15 non-empty lines, the heading included; six rules.)
- 6.3 `agents/orchestrator.md` **At the 2-FAIL cap**: "At **ladder exhaustion**
  (the second FAIL on the ladder's top tier), stop" becomes "At **ladder
  exhaustion** (the unit's FAIL-block count reaching or exceeding the ladder's
  length: normally the second FAIL on the ladder's top tier, or any later FAIL
  after a human-directed re-dispatch), stop". Same line; nothing else in the
  file changes (the **Contract-score guard** paragraph is csg-2's).
- 6.4 `templates/persona-protocol.md` **Cap at 2 FAILs per tier**: "Only the
  second FAIL on the ladder's top tier,\nladder exhaustion, stops re-dispatch:"
  becomes "Only ladder exhaustion (the unit's FAIL count reaching or exceeding
  the ladder's length: normally the second FAIL on its top tier) stops
  re-dispatch:" (rewrapped).
- 6.5 CHANGELOG entry, version lines, `--update`.

Acceptance criteria:
- AC6.1 run: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`; exit 0; stdout `exit=0`; mutation: skip 6.2 (digest body 21 non-empty lines today), prints `exit=1`.
- AC6.2 run: `awk 'f && NF; /-->/{f=1}' templates/protocol-digest.md | wc -l`; exit 0; stdout `15`; mutation: skip 6.2, prints `21` (measured at HEAD 94d6b22).
- AC6.3 run: `for t in explorer code-review-graph ESCALATE-TO-HUMAN 'Escalation ladder' 'ladder exhaustion' wip-handoff .pending-review 'defer:' 'skip:' 'memory:'; do tr '\n' ' ' < templates/protocol-digest.md | tr -s ' ' | grep -oF -- "$t" | wc -l; done | sort -u | tr '\n' ' '`; exit 0; stdout `1 `; mutation: drop the memory rule, prints `0 1 `.
- AC6.4 run: `for f in agents/orchestrator.md templates/persona-protocol.md templates/protocol-digest.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oF "reaching or exceeding the ladder's length" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 1 `; mutation: skip 6.3, 6.4 or 6.2, its position prints `0`.
- AC6.5 run: `grep -cF "(the second FAIL on the ladder's top tier), stop" agents/orchestrator.md`; exit 1; stdout `0`; mutation: skip 6.3, prints `1`.
- AC6.6 run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1 && grep -c 'Contract-score guard' agents/orchestrator.md`; exit 0; stdout `1` (csg-2's paragraph and the pins intact); mutation: delete the csg-2 paragraph, prints `0`.
- AC6.7 run: `for f in .claude/protocol-digest.md .claude/persona-protocol.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oF "reaching or exceeding the ladder's length" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 `; mutation: skip `--update`, prints `0 0 `.
- S1-S10 (S7-S10 with 0.31.149; S9 `14`, as csg-2 measured: ten agent mirrors, the three protocol files and `.claude/persona-config.json`; re-measure if a mirror is added).

### Step 7 (blc-7, scribe): defaultImplementerModel tag only raises (item 7)

Affected files: `CONTEXT.md` only, entry **defaultImplementerModel** only
(csg-4's entries untouched). Scribe dispatch contract (rubric v2 scribe shape).

Glossary edit 7.1, heading `**defaultImplementerModel**:`: the text
"precedence order: (1) explicit per-dispatch `Suggested model:` tag (if
present)," becomes "precedence order: (1) explicit per-dispatch `Suggested
model:` tag (if present), which can only raise a unit's tier above its
ladder's entry, never lower it (see [[default tier]]),". ADR: none. Close
conditions: per task-master's scribe template (issue number, unit id, the
`"PASS blc-7 ..."` marker line).

Acceptance criteria:
- AC7.1 run: `awk '/^\*\*defaultImplementerModel\*\*:/,/^$/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | grep -oF 'can only raise a unit' | wc -l`; exit 0; stdout `1`; mutation: put the sentence in the **default tier** entry instead, prints `0` (the hdc-5 FAIL-1 class: wrong entry).
- AC7.2 run: `node tests/context-glossary-links.test.js > /dev/null 2>&1 && node tests/ubiquitous-language.test.js > /dev/null 2>&1; echo exit=$?`; exit 0; stdout `exit=0`; mutation: write `[[default-tier]]`, prints `exit=1`.
- AC7.3 run: `git diff --name-only "$B..$U"` lists only `CONTEXT.md`, and `git diff -U0 "$B..$U" -- CONTEXT.md | grep '^@@' | wc -l` prints `1` (one hunk, inside the entry); mutation: touch another entry, prints `2`.
- S1-S6.

### Step 8 (blc-h1, human-only): a pending-review flag survived a PASS (item 12a)

Not dispatched. For the hook owner.
- Known prior cause (2026-10-02, fixed by esf-flag-fix, 5d99bbe): the
  orchestrator's `defer:` printf re-created a flag the hook had just deleted;
  `tests/pending-review-resurrection.test.sh` covers that path with a
  tombstone.
- First step: read `.claude/review-audit.log` with the Read tool (Bash access
  is Set A, denied) around the PASS where the flag survived. Signature of the
  old cause: `cleared=1 remaining=1` twice, with `defer:` lines after the first
  clear. A different signature is a new path.
- Acceptance shape: a new case in `tests/pending-review-resurrection.test.sh`
  that reproduces the observed sequence and fails before the fix; after the
  fix, `bash tests/pending-review-resurrection.test.sh` exits 0 and `bash
  tests/validate.sh` exits 0; `node bin/cli.js --update` refreshes the
  `.claude/hooks/` mirrors and fileHashes in the same commit.
- Needs from the user: which unit and roughly when (Open Question 1).

### Step 9 (blc-h2, human-only): human-decision-gate glob over-block (item 12b)

Not dispatched. Suspected site: `glob_names_tokens` (`hooks/scripts/human-decision-gate.sh:430-446`,
F-1, esc-left-3). The gate already accepts measured over-blocks as `OB-` rows
(`docs/plans/2026-10-04-escalation-leftovers.md`: 42 of 9,377 real commands).
- First step: capture the over-blocked command verbatim.
- Decision for the hook owner: an over-block inside an accepted `OB-` family
  gets a pinned row and no code change; a new family gets a fix plus an
  `allowed` row in `tests/human-decision-gate.test.sh`, and
  `tests/hdg-differential-sweep.sh` shows no new allowance on the bypass
  families.
- Acceptance shape: the new row fails before and passes after;
  `bash tests/human-decision-gate.test.sh` and `bash tests/validate.sh` exit 0.
- Needs from the user: the command (Open Question 2).

### Step 10 (blc-h3, human-only): harness-integrity-gate false positives (item 12c)

Not dispatched. Reproductions: F10 (a) and (b), plus the user's heredoc case
(a heredoc whose body only names the persona config). Site:
`hooks/scripts/harness-integrity-gate.sh:197-296` (`set_a_mentioned`, then
`command_is_provably_benign` / `is_benign_jq_read`).
- Constraint: the family table in `tests/harness-integrity-gate.test.sh`
  (gate-hardening convention) must not lose a blocked row; widen read
  recognition, never the Set A literal match.
- Acceptance shape: new `allowed` rows for a read-only `grep`/`cat`/`node -e`
  read of the config with a `cd <dir>;` prefix and a `| head` pipe, and for a
  heredoc writing an unrelated file whose body names the config; every
  existing blocked row stays blocked; `bash tests/harness-integrity-gate.test.sh`
  and `bash tests/validate.sh` exit 0.
- Not needed from the user: the two reproductions are measured; the heredoc
  shape is the user's own report.

## Open Questions

None blocks the seven dispatchable units. Two block only the human-only units:

1. (blc-h1, from CHK11) Which unit's PASS left the flag standing, and roughly
   when? Recommended default: the hook owner reads `.claude/review-audit.log`
   for the hdc-1..hdc-6 and csg-1..csg-2 PASS windows (2026-10-08 to
   2026-10-09) and takes the first flag still standing after a reviewer PASS.
2. (blc-h2, from CHK12) What command did human-decision-gate over-block?
   Recommended default: the hook owner reruns `tests/hdg-differential-sweep.sh`
   against the last week's transcripts and treats the first new denial as the
   reproduction.

## Self-check

- CHK1: Does every Goal clause G1-G12 map to a unit and at least one criterion? — PASS
- CHK2: Do the unit table and Steps 1-10 agree on each unit's files? — PASS
- CHK3: Are the content files of blc-1, blc-2, blc-3, blc-4 and blc-5 pairwise disjoint? — PASS
- CHK4: Is every edge of the Depends-on graph stated in both the table and the diagram? — PASS
- CHK5: Do blc-5 and blc-6 agree with D11 on version numbers and order? — PASS
- CHK6: Is any csg-owned file or entry edited (R1)? — PASS (none; blc-6 names csg-2's paragraph only to pin it, AC6.6)
- CHK7: Is the digest budget defined machine-checkably (whole file or body)? — FAIL (ambiguous) — revised in place (D4, AC6.1, AC6.2: non-empty body lines after `-->`)
- CHK8: Is item 10's scope defined? — FAIL (missing) — revised in place (D8, F8: five plans)
- CHK9: Could blc-4's status edits shift lines that other documents cite? — FAIL (conflicting: a status line inserted at the top shifts every cited line) — revised in place (D8 same-line prefix plus appended section; AC4.5)
- CHK10: Is the item-11 sweep consistent with the hdc Ruling's "left as it was"? — FAIL (conflicting) — revised in place (D9 supersedes for trailer text only, recorded in Clarifications)
- CHK11: Is blc-h1's reproduction defined? — FAIL (missing) — converted to Open Question 1
- CHK12: Is blc-h2's reproduction defined? — FAIL (missing) — converted to Open Question 2
- CHK13: Is the range pattern this plan's own criteria use the same as the one blc-5 ships? — PASS (D12, S1-S3)
- CHK14: Does criterion AC1.1 still fail under its own `mutation:` line, given R3's recorded `vacuous` history on neighbouring test units? — PASS (F1 measured both sides)
- CHK15: Does criterion AC6.4 still fail under its own `mutation:` line, given gh307/gh310/gh348-14/gh429's recorded class vacuous on `agents/orchestrator.md`? — PASS (each position is per file; skipping one edit zeroes it)
- CHK16: Does criterion AC6.4 still fail under its own `mutation:` line, given gh348-3's and mw-step1..3's recorded class vacuous on `templates/persona-protocol.md`? — PASS (flattened grep; the wrap cannot hide the phrase)
- CHK17: Does criterion AC3.1 still fail under its own `mutation:` line, given examples-2's recorded class host and gh348-3's class vacuous on the protocol ports? — PASS (per-file count, flattened)
- CHK18: Does criterion AC5.4 still fail under its own `mutation:` line, given item17-3's recorded class vacuous on `agents/lead-programmer.md` and `agents/scribe.md`? — PASS (per-file count)
- CHK19: Does criterion AC7.1 still fail under its own `mutation:` line, given gh303/gh354/gh409/spec2-unitA/spec2-unitB's recorded class vacuous and ci-fetch-depth-cleanup/gh426's class host on CONTEXT.md? — PASS (entry-scoped awk; the wrong-entry mutation prints `0`)
- CHK20: Does criterion AC2.1 still fail under its own `mutation:` line, given gh307's recorded class vacuous on `commands/start-feature-team.md`? — PASS (per-phrase counts)
- CHK21: Does AC4.5 give an exact expected stdout? — FAIL (ambiguous: first draft deferred the per-file numstat to task-master) — revised in place (exact `5/1 5/1 5/1 10/6 5/1 `, one-line paragraphs, trailing newlines measured)
- CHK24: Do AC6.2 and D4 agree on the trimmed digest's line count? — FAIL (conflicting: first draft said 14, the payload has 15 with its heading) — revised in place (15, within the budget of 15)
- CHK25: Does AC4.1 exclude this plan, which itself spells the placeholder? — FAIL (missing) — revised in place (pathspec exclusion)
- CHK26: Does AC2.1's expected stdout match edit 2.1's pointer text? — FAIL (conflicting: the pointer has no period, so the heading phrase matches once, not twice) — revised in place (`1 1 1 1 `)
- CHK22: Is every MUST constitution principle checked? — PASS
- CHK23 (ubiquitous-language, prose mode, advisory): Lens 1: none. Lens 2: "per-unit cap" in the request is the ports' older cap, not a synonym for the glossary's 2-FAIL cap (per tier); the plan never calls it "the 2-FAIL cap". "hook-owner unit" replaced by "human-only unit". Lens 3: "fix round", "untagged-tail criterion", "unit range" are new, but harness mechanics: candidates for `docs/harness-glossary.md`, not CONTEXT.md. — PASS (advisory)

## Scribe update hint

blc-7 is the only CONTEXT.md edit. After blc-5 lands, scribe may add
**untagged-tail criterion** and **fix round** to `docs/harness-glossary.md`
(not CONTEXT.md) if a later unit needs them. No ADR.

## Handoff

Seven dispatchable units is more than the fast path's five: task-master
slices blc-1..blc-7 with `to-tickets`, writes each nine-element contract (lead
shape for blc-1..blc-6, scribe shape for blc-7) scoring 7/7 under
`node bin/contract-score.js --rubric=v2` with `"sizeOver":false`, assigns tags
(none needed: no `blc-*.fail` exists), and states the retrieval contract.
blc-h1..blc-h3 are filed as human-only issues (no `ready-for-agent` label)
or, if filing is denied (R5), left in this plan for the user.

---

# Dispatch contracts (standard path; the plan file is the retrieval contract)

Written by task-master on 2026-10-09 at HEAD 5720c5b, version 0.31.147, after the spec above was FINAL. Nothing above this rule is changed by the contracts.

## Retrieval contract

No per-unit issues exist (R5: none was filed; `gh issue create` was not attempted). The retrieval contract for every unit is this file, `docs/plans/2026-10-09-backlog-cleanup.md`, under `## Unit blc-<n>`: read the unit's `~~~~~~~markdown` block (its first line is `Unit: blc-<n>`), and the orchestrator's guard reads it with `node bin/contract-guard.js docs/plans/2026-10-09-backlog-cleanup.md --unit=blc-<n>` (add `--shape=scribe` for blc-7). The contract block outranks the plan prose above; a conflict is a spec gap: STOP. Every commit subject ends `(#529)`, the umbrella issue of the haiku-default and contract-score-guard stages (it is CLOSED; reused as hdc and csg did, so one `sed` replaces it if a new umbrella is wanted); scribe closes nothing and never closes #529.

## Dispatch table

Every unit is tagged `Suggested model: haiku`: no `blc-*.fail` record exists, and the tag is reactive. The reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff. `blc-h1`, `blc-h2` and `blc-h3` are human-only: they are recorded in Steps 8-10 above, have no contract and are never dispatched.

| unit | persona | Suggested model | Depends on | contract shape |
|---|---|---|---|---|
| blc-1 | lead-programmer | haiku | none | lead |
| blc-2 | lead-programmer | haiku | none | lead |
| blc-3 | lead-programmer | haiku | none | lead |
| blc-4 | lead-programmer | haiku | none | lead |
| blc-5 | lead-programmer | haiku | csg-2 (PASS recorded) | lead, stamped 0.31.148 |
| blc-6 | lead-programmer | haiku | blc-5 (PASS), csg-2 (PASS recorded) | lead, stamped 0.31.149 |
| blc-7 | scribe | haiku | csg-4 (PASS recorded) | scribe |
| blc-8 | lead-programmer | haiku | none | lead |
| blc-h1, blc-h2, blc-h3 | human-only | n/a | none (outside the blc-5 to blc-6 window, R2) | none |

Intersection table (shared files are content files that two units edit; the bump files and the paths `node bin/cli.js --update` changes are excluded by definition, and stamped units serialize on those):

| unit | shared files | depends on |
|---|---|---|
| blc-1 | none | none |
| blc-2 | none | none |
| blc-3 | none | none |
| blc-4 | none | none |
| blc-5 | none | none (first stamped unit; csg-2 PASSed) |
| blc-6 | none | blc-5 (serial stamped edit: each sets HEAD + 1) |
| blc-7 | none | none (csg-4 PASSed) |
| blc-8 | none | none |

blc-6 is the only unit that edits `agents/orchestrator.md` (the At the 2-FAIL cap line and the Contract-score guard caveat), so it is the only orchestrator.md unit and is already serialized after blc-5. **Dispatchable in parallel now: blc-1, blc-2, blc-3, blc-4, blc-7 and blc-8** (mutually file-disjoint; none runs `node bin/cli.js --update`). blc-5 is dispatchable too (H-BLC5 ruled) and blc-6 waits for blc-5 PASS (see Slice state); they run serially and alone (R2).

## Slice state

| unit | state | reason |
|---|---|---|
| blc-1, blc-2, blc-3, blc-4 | dispatchable | none |
| blc-5 | dispatchable | none (H-BLC5 ruled) |
| blc-6 | waiting | dispatch after blc-5 PASS (serial stamped edit) |
| blc-7, blc-8 | dispatchable | none |
| blc-h1, blc-h2, blc-h3 | human-only (not sliced) | reports for the hook owner; Open Questions 1 and 2 stay open |

No unit is held (H-BLC5 ruled 2026-10-09): blc-5 is dispatchable and blc-6 waits for blc-5 PASS. The contracts below are complete and score 7/7: they already carry the two port edits as the scratch fix that made AC5.5 pass (blc-5 edits 4 and 5). Slicing notes for spec-master (the spec text above is untouched):

1. Reviewer notes folded in (requested at slicing time). (a) `bin/contract-guard.js` exit 2 on extra arguments or unknown flags, the header note that a longer closing fence leaves a block open, and the `guard-plan-files` check reading a fixture copy: new unit **blc-8** (no existing unit touches those files). (b) The Contract-score guard caveat that "scoring is pure" assumes an unchanged contract of record, and a pin test for the guard paragraph: folded into **blc-6** as edits 8 and 9 (blc-6 already edits `agents/orchestrator.md`; the pin lives in `tests/writer-tier-consistency.test.js`). (c) Glossary: **contract of record** and **rubric v2** entries, and the **Rulings ledger** link, folded into **blc-7** as items 2-6 (the **Rulings ledger** entry already exists in `docs/harness-glossary.md`, so a `[[Rulings ledger]]` link in CONTEXT.md resolves; no duplicate entry is added).
2. **Spec gap H-BLC5 (blocks blc-5 and blc-6).** Step 5 omits two files. Replaying blc-5 in a scratch worktree of 5720c5b, `tests/writer-tier-consistency.test.js` AC-A1 (the Contract precedence paragraph must read the same in `agents/lead-programmer.md` and both ports) failed with only the files Step 5 lists; it passed once `adapters/cursor/agents/lead-programmer.md` and `adapters/codex/agents/lead-programmer.toml` got the same Fix-turns sentence. Ruling needed from spec-master: add those two files to Step 5 (affected files, edit 5.3, AC5.4) or rule otherwise. The plan's AC5.5 only cites AC-P2/AC-P3. Release: spec-master adds a line starting `- H-BLC5:` under `## Rulings` below; task-master then deletes the `HELD:` line of blc-5 and blc-6 (it never re-files a unit).
3. AC4.3 as written counts the old proof phrase over the whole hdc plan, but hdc-4's own criterion 7 carries the identical sentence at line 821 (correct for hdc-4's one-commit range, so it stays). The contract scopes the count to the hdc-5 block (`sed -n '/^Unit: hdc-5$/,$p'`) and edits line 989 by number behind a precondition; the expected output `0` then `1` is the plan's.
4. Step 6 prose says the digest header becomes "under 15 non-empty lines" while the test allows 15 and the new body has 15; the contract writes "at most 15".
5. The plan's shared S1 and S3 criteria pass vacuously before the unit's first commit (an empty range prints `0`); the contracts add a guard that exits 3 with `no-unit-commit` when the unit has no commit.

## Rulings

(spec-master adds one line per resolved gap, starting `- <ruling-id>:`.)

- H-BLC5: (2026-10-09, spec-master) Amend, not overrule. Step 5 now lists `adapters/cursor/agents/lead-programmer.md` and `adapters/codex/agents/lead-programmer.toml`; edit 5.3 puts the same Fix-turns sentence into both ports; AC5.5's mutation names AC-A1 and the new AC5.7 checks both ports. Verified at HEAD accec4c: the sentence's anchor (`without a contract (task-master absent) leaves them in force.`) sits inside the Contract precedence bullet in all three files (agents/lead-programmer.md:47, cursor port :51, codex port :52), and `tests/writer-tier-consistency.test.js:180` (AC-A1) requires that bullet to be identical across them, so the omission was a spec defect, not a contract overreach. The blc-5 contract of record (edits 4 and 5, Affected files, criteria 7, 10 and 11, commit `git add` list) already matches the amended Step 5 and is unchanged; blc-6's Do NOT touch now names the two ports (blc-5's files). The Step 6 wording gap is fixed in the same pass: edit 6.2 now reads "at most 15", matching blc-6 edit 3. blc-5 and blc-6 are released: task-master deletes both `HELD:` lines and flips their Slice state and Dispatch table rows; the only contract text this ruling changed is the one added blc-6 Do NOT touch line, and that edit is already made.

## Unit blc-1

~~~~~markdown
Unit: blc-1

## Objective
`tests/default-implementer-model.test.js` fails loudly when `agents/lead-programmer.md` does not ship `model: haiku`, and its migrate-twice test runs the second `--update` through the full render loop (`--force-render`) instead of the "already current" early return.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-1`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/default-implementer-model.test.js` (anchors below)

## Ordered edits
1. file: `tests/default-implementer-model.test.js`
   anchor: line matching `if (frontmatter === 'haiku') {`
   indent: 4
   before:
```
    if (frontmatter === 'haiku') {
      assert.strictEqual(expected, 'haiku', 'lead-programmer ships model: haiku, so an old-version "sonnet" must migrate; IMPLEMENTER_HAIKU_DEFAULT_SINCE is disabled');
    }
```
   after:
```
    assert.strictEqual(frontmatter, 'haiku', 'agents/lead-programmer.md must ship model: haiku; if the shipped default tier changed on purpose, rewrite this check together with IMPLEMENTER_HAIKU_DEFAULT_SINCE');
    assert.strictEqual(expected, 'haiku', 'an old-version "sonnet" must migrate to "haiku"; if it does not, IMPLEMENTER_HAIKU_DEFAULT_SINCE is disabled');
```
2. file: `tests/default-implementer-model.test.js`
   anchor: line matching `const afterFirst = fs.readFileSync(configPath, 'utf8');`
   indent: 4
   before:
```
    const afterFirst = fs.readFileSync(configPath, 'utf8');

    const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
```
   after:
```
    const afterFirst = fs.readFileSync(configPath, 'utf8');
    assert.strictEqual(JSON.parse(afterFirst).defaultImplementerModel, 'haiku', 'the first --update must apply the migration');

    // --force-render skips runUpdate's "already current" early return, so a
    // change the second run makes to the config is written and seen below.
    const second = spawnSync('node', [cliPath, '--update', '--force-render'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
    assert.ok(second.stdout.includes('update complete'), `the second --update must run the full render loop, got: ${second.stdout}`);
```
3. command: `git add tests/default-implementer-model.test.js && git commit -m "test(blc-1): migration guard fails loud; migrate-twice runs the full render loop (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/cli.js` (the mutation in criterion 1 is made in a scratch copy only)
- `tests/contract-score.test.js`
- `agents/` and `templates/` (no version bump is needed)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`, which this unit never runs)

## Acceptance criteria
1. run: `node tests/default-implementer-model.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: in a scratch copy of the finished change insert `if (config.defaultImplementerModel === 'haiku') config.defaultImplementerModel = 'opus';` as the first statement of `applyImplementerModelMigration` in `bin/cli.js`; it prints `exit=1`. With edit 2 skipped the same scratch mutation still prints `exit=0` (the early return discards it).
   proof: task-master ran the finished edits plus that insert in a scratch worktree of 5720c5b and got `exit=1`; the skip-edit-2 side is plan fact F1 (spec-master). This criterion already passes at HEAD; it must stay green after the edits.
2. run: `D=$(mktemp -d) && git worktree add --detach -q "$D" HEAD && sed -i 's/^model: haiku$/model: sonnet/' "$D/agents/lead-programmer.md" && node "$D/tests/default-implementer-model.test.js" | /usr/bin/grep -c '^FAIL --update applies migrateDefaultImplementerModel to an old-version'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0` (measured, plan fact F2). It prints `0` at HEAD.
3. run: `/usr/bin/grep -c "'--update', '--force-render'" tests/default-implementer-model.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`, exit 1.
4. run: `/usr/bin/grep -c "if (frontmatter === 'haiku')" tests/default-implementer-model.test.js`
   exit: 1
   stdout: `0`
   mutation: skip edit 1; it prints `1`, exit 0.
5. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-1\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
6. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
7. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- tests/default-implementer-model.test.js | /usr/bin/grep -vcE '^[a-z]+\(blc-1\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
8. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' tests/default-implementer-model.test.js | sort) && echo scope-blc-1-ok`
   exit: 0
   stdout: `scope-blc-1-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
9. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
10. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-1\): ' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: yes tests/default-implementer-model.test.js (the edit is the test; its red state is shown by the mutations of criteria 1 and 2)
blast-radius: tests/default-implementer-model.test.js:269, tests/default-implementer-model.test.js:289, bin/cli.js:1486
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-1)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: test(blc-1): migration guard fails loud; migrate-twice runs the full render loop (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-1 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit blc-2

~~~~~markdown
Unit: blc-2

## Objective
`commands/start-feature-team.md` says that a same-tier retry resumes the lead-programmer teammate that made the failed attempt with `SendMessage`, and that a tier change or a gone teammate gets a fresh spawn named `lead-programmer-<task-id>-<n+1>`.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-2`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `commands/start-feature-team.md` (anchors below)

## Ordered edits
1. file: `commands/start-feature-team.md`
   anchor: line matching `FAIL-block count, and pass that tier as the`
   indent: 0
   before:
```
FAIL-block count, and pass that tier as the `model` parameter of the `Agent` call
that spawns the lead-programmer teammate for the unit's next attempt. "Done" is enforced
```
   after:
```
FAIL-block count, and, when the next attempt needs a new teammate (**Same-tier
retry** below), pass that tier as the `model` parameter of the `Agent` call that
spawns it. "Done" is enforced
```
2. file: `commands/start-feature-team.md`
   anchor: line matching `from completing without a matching marker.`
   indent: 0
   insert-after:
```

**Same-tier retry.** A teammate's model is fixed when it spawns, so the next
attempt reuses or replaces the lead-programmer teammate by tier. When the
unit's next tier is the tier of the teammate that made the failed attempt (a
first FAIL on that tier), resume that teammate with `SendMessage`, carrying the
defect list or the fix contract; do not spawn a new one. When the tier changes,
or that teammate is gone (crashed or shut down), spawn a fresh lead-programmer
teammate with the new tier as the `model` parameter, named
`lead-programmer-<task-id>-<n+1>`, where n is the unit's FAIL-block count, so
no two attempts share a name.
```
3. command: `git add commands/start-feature-team.md && git commit -m "docs(blc-2): agent-teams same-tier retry resumes the teammate, fresh spawn naming (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/orchestrator.md` (its Escalation ladder paragraph is the source of the tier rule and stays as it is)
- `agents/lead-programmer.md`
- `templates/persona-protocol.md`
- `.claude/` (this file has no mirror; no `--update` is needed and no version bump applies)

## Acceptance criteria
1. run: `for p in '**Same-tier retry.**' 'resume that teammate with' 'lead-programmer-<task-id>-<n+1>' 'needs a new teammate'; do tr '\n' ' ' < commands/start-feature-team.md | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 1 `
   mutation: skip edit 2; it prints `0 0 0 1 `. Skip edit 1; it prints `1 1 1 0 `. At HEAD it prints `0 0 0 0 `.
2. run: `tr '\n' ' ' < commands/start-feature-team.md | tr -s ' ' | /usr/bin/grep -cF "call that spawns the lead-programmer teammate for the unit's next attempt"`
   exit: 1
   stdout: `0`
   mutation: skip edit 1; it prints `1`, exit 0.
3. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-2\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
4. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
5. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- commands/start-feature-team.md | /usr/bin/grep -vcE '^[a-z]+\(blc-2\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
6. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' commands/start-feature-team.md | sort) && echo scope-blc-2-ok`
   exit: 0
   stdout: `scope-blc-2-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
7. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
8. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-2\): ' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit in a command file; the checks are flattened-phrase greps and the validate.sh conditional-phrasing check (P4, line 255) over this file
blast-radius: commands/start-feature-team.md:51, commands/start-feature-team.md:56, tests/validate.sh:255
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 2's payload begins with one empty line, which is part of the text.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-2)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: docs(blc-2): agent-teams same-tier retry resumes the teammate, fresh spawn naming (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-2 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit blc-3

~~~~~markdown
Unit: blc-3

## Objective
The Codex and Cursor ports keep the per-unit cap of 2 FAILs and say why: their agents inherit the session's model, so there are no implementer tiers to climb. Four cap sites gain one sentence each and both port-notes documents gain an `## Escalation ladder (not ported)` section.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-3`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `adapters/codex/agents-md-fragment.md` (anchor: line matching `fix attempt. A unit that fails twice usually means the plan itself has a gap.`)
- `adapters/cursor/rules/persona-protocol.mdc` (anchor: line matching `fix attempt. A unit that fails twice usually means the plan itself has a gap.`)
- `adapters/codex/agents/orchestrator.toml` (anchor: line matching `defect history to the user instead of a third pass.`)
- `adapters/cursor/agents/orchestrator.md` (anchor: line matching `defect history to the user instead of a third pass.`)
- `docs/codex-port-notes.md` (anchor: line matching `replace the self-tracked counter in`)
- `docs/cursor-port-notes.md` (anchor: line matching `installs.`)

## Ordered edits
1. file: `adapters/codex/agents-md-fragment.md`
   anchor: line matching `fix attempt. A unit that fails twice usually means the plan itself has a gap.`
   indent: 0
   insert-after:
```
This port keeps the cap per unit, not per implementer tier: its agents inherit
the session's model, so there are no implementer tiers to climb and the
Escalation ladder is not ported (see docs/codex-port-notes.md).
```
2. file: `adapters/cursor/rules/persona-protocol.mdc`
   anchor: line matching `fix attempt. A unit that fails twice usually means the plan itself has a gap.`
   indent: 0
   insert-after:
```
This port keeps the cap per unit, not per implementer tier: its agents inherit
the session's model, so there are no implementer tiers to climb and the
Escalation ladder is not ported (see docs/cursor-port-notes.md).
```
3. file: `adapters/codex/agents/orchestrator.toml`
   anchor: line matching `defect history to the user instead of a third pass.`
   indent: 2
   insert-after:
```
  (Per unit: agents here inherit the session's model, so there are no
  implementer tiers to climb.)
```
4. file: `adapters/cursor/agents/orchestrator.md`
   anchor: line matching `defect history to the user instead of a third pass.`
   indent: 2
   insert-after:
```
  (Per unit: agents here inherit the session's model, so there are no
  implementer tiers to climb.)
```
5. file: `docs/codex-port-notes.md`
   anchor: line matching `replace the self-tracked counter in`
   indent: 0
   insert-after:
```

## Escalation ladder (not ported)

The Claude Code orchestrator moves a failing unit up an Escalation ladder of
implementer tiers (`haiku`, `sonnet`, `opus`), two attempts per tier. This
port does not: its agents inherit the session's model, so there are no
implementer tiers to climb. It keeps the older cap of 2 FAILs per unit, after
which the orchestrator stops and asks the user. Port the ladder only once the
model-tier mapping is decided.

The Codex agent files omit `model` (adapters/codex/agents/lead-programmer.toml).
```
6. file: `docs/cursor-port-notes.md`
   anchor: line matching `installs.`
   indent: 0
   insert-after:
```

## Escalation ladder (not ported)

The Claude Code orchestrator moves a failing unit up an Escalation ladder of
implementer tiers (`haiku`, `sonnet`, `opus`), two attempts per tier. This
port does not: its agents inherit the session's model, so there are no
implementer tiers to climb. It keeps the older cap of 2 FAILs per unit, after
which the orchestrator stops and asks the user. Port the ladder only once the
model-tier mapping is decided.

Every Cursor agent ships `model: inherit` (row 6 above).
```
7. command: `git add adapters/codex/agents-md-fragment.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md adapters/cursor/rules/persona-protocol.mdc docs/codex-port-notes.md docs/cursor-port-notes.md && git commit -m "docs(blc-3): ports record why the cap stays per unit (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/orchestrator.md` (the Claude Code ladder is not ported)
- `templates/persona-protocol.md`
- `tests/adapter-protocol-parity.test.js` (it must pass unchanged)
- `.claude/` (none of these six files has a mirror; no `--update` and no version bump apply)

## Acceptance criteria
1. run: `for f in adapters/codex/agents-md-fragment.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md adapters/cursor/rules/persona-protocol.mdc docs/codex-port-notes.md docs/cursor-port-notes.md; do tr '\n' ' ' < "$f" | tr -s ' ' | /usr/bin/grep -oF 'no implementer tiers to climb' | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 1 1 1 `
   mutation: skip any one of edits 1-6; its position prints `0`. At HEAD it prints `0 0 0 0 0 0 `.
2. run: `cat docs/codex-port-notes.md docs/cursor-port-notes.md | /usr/bin/grep -c '^## Escalation ladder (not ported)$'`
   exit: 0
   stdout: `2`
   mutation: skip edit 5; it prints `1`.
3. run: `node tests/adapter-protocol-parity.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: delete a probe string that the parity test pins from a port file; it prints `exit=1`. This already passes at HEAD and must stay green.
4. run: `/usr/bin/grep -c 'Cap at 2 FAILs per unit' adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc | tr '\n' ' '`
   exit: 0
   stdout: `adapters/codex/agents-md-fragment.md:1 adapters/cursor/rules/persona-protocol.mdc:1 `
   mutation: rewrite either heading to `Cap at 2 FAILs per tier`; that file prints `:0`. The cap itself is unchanged, so this passes at HEAD as well.
5. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-3\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
6. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
7. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- adapters/codex/agents-md-fragment.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md adapters/cursor/rules/persona-protocol.mdc docs/codex-port-notes.md docs/cursor-port-notes.md | /usr/bin/grep -vcE '^[a-z]+\(blc-3\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
8. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' adapters/codex/agents-md-fragment.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md adapters/cursor/rules/persona-protocol.mdc docs/codex-port-notes.md docs/cursor-port-notes.md | sort) && echo scope-blc-3-ok`
   exit: 0
   stdout: `scope-blc-3-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
9. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
10. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-3\): ' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1`. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edits to port documents; the checks are flattened-phrase greps plus the existing tests/adapter-protocol-parity.test.js
blast-radius: adapters/codex/agents-md-fragment.md:163, adapters/cursor/rules/persona-protocol.mdc:169, adapters/codex/agents/orchestrator.toml:127, adapters/cursor/agents/orchestrator.md:123, tests/adapter-protocol-parity.test.js:1
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edits 5 and 6 begin with one empty line, which is part of the text. The port notes use the term "cap of 2 FAILs per unit", never "the 2-FAIL cap" (that glossary term is per tier).
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-3)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: docs(blc-3): ports record why the cap stays per unit (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-3 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit blc-4

~~~~~~~markdown
Unit: blc-4

## Objective
The hdc-5 proof line stops attributing hdc-4's measurement to hdc-5; the four landed hdc contracts name the trailer their first commit carries instead of a model-name placeholder; and the five finished stage plans of the haiku programme carry a closed status, with no existing line moved.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-4`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `docs/plans/2026-10-08-haiku-default-cleanup.md` (anchors below)
- `docs/plans/2026-10-06-rubric-gated-haiku-programme.md` (anchors below)
- `docs/plans/2026-10-06-contract-hardening.md` (anchors below)
- `docs/plans/2026-10-07-final-cleanup.md` (anchors below)
- `docs/plans/2026-10-08-haiku-default-tier.md` (anchors below)

## Ordered edits
1. command: `sed -i '989s/, dropping 789725d.s printed /, and over hdc-4\x27s one-commit range (the same \x60run:\x60 with \x60(hdc-4)\x60 in place of \x60(hdc-5)\x60) dropping 789725d\x27s trailer printed /' docs/plans/2026-10-08-haiku-default-cleanup.md`
   expect: 0
2. command: `sed -i 's/Co-Authored-By: Claude <your model name> <noreply@anthropic.com>/Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>/' docs/plans/2026-10-08-haiku-default-cleanup.md`
   expect: 0
3. file: `docs/plans/2026-10-08-haiku-default-cleanup.md`
   anchor: line matching `Status: FINAL (`
   before: `Status: FINAL (`
   after: `Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (`
4. file: `docs/plans/2026-10-06-rubric-gated-haiku-programme.md`
   anchor: line matching `Status: FINAL (`
   before: `Status: FINAL (`
   after: `Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (`
5. file: `docs/plans/2026-10-06-contract-hardening.md`
   anchor: line matching `Status: FINAL (`
   before: `Status: FINAL (`
   after: `Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (`
6. file: `docs/plans/2026-10-07-final-cleanup.md`
   anchor: line matching `Status: FINAL (`
   before: `Status: FINAL (`
   after: `Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (`
7. file: `docs/plans/2026-10-08-haiku-default-tier.md`
   anchor: line matching `Status: FINAL (`
   before: `Status: FINAL (`
   after: `Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (`
8. file: `docs/plans/2026-10-06-rubric-gated-haiku-programme.md`
   anchor: line matching `harness-glossary:2939) and "haiku-safe".`
   indent: 0
   insert-after:
```

## Status update (2026-10-09)

Closed. Stages 0-3 are reviewer-PASSed (rgh-u0-1, rgh-u0-2, rgh-u0-2b, rgh-u0-3, rgh-u0-4, rgh-u1-1, rgh-u2-1, rgh-u2-2, rgh-u3-1 .. rgh-u3-4). Stage 4 (U4-1..U4-3) is parked and Stage 5 is superseded, as the 2026-10-08 note under the status line says. No unit of this plan is left to dispatch.
```
9. file: `docs/plans/2026-10-06-contract-hardening.md`
   anchor: line matching `"ready-for-review packet template", "defect block" and "executor".`
   indent: 0
   insert-after:
```

## Status update (2026-10-09)

Closed. Every unit is reviewer-PASSed (rgh-h1, rgh-h1b, rgh-h2 .. rgh-h12; H13 ran as rgh-h13a and rgh-h13b). The status line's 'Stages 4-5 and gates G3/G4 of the parent are untouched' was true when written; since 2026-10-08 the parent's Stage 4 is parked and its Stage 5 is superseded by docs/plans/2026-10-08-haiku-default-tier.md.
```
10. file: `docs/plans/2026-10-07-final-cleanup.md`
   anchor: line matching `glossary finding for fc-5 to batch.`
   indent: 0
   insert-after:
```

## Status update (2026-10-09)

Closed. fc-1 .. fc-5 are reviewer-PASSed. It was not the last cleanup stage after all: docs/plans/2026-10-08-haiku-default-cleanup.md and docs/plans/2026-10-09-backlog-cleanup.md followed at the user's request. Rule P1's `-F --grep` range form is replaced by the anchored form of docs/plans/2026-10-09-backlog-cleanup.md, D3.
```
11. file: `docs/plans/2026-10-08-haiku-default-tier.md`
   anchor: line matching `literals at dispatch per R3 and U4's pre-dispatch derivation.`
   indent: 0
   insert-after:
```

## Status update (2026-10-09)

Closed. htd-1 .. htd-7 are reviewer-PASSed. Follow-ups: docs/plans/2026-10-08-haiku-default-cleanup.md, docs/plans/2026-10-08-contract-score-guard.md and docs/plans/2026-10-09-backlog-cleanup.md.
```
12. file: `docs/plans/2026-10-08-haiku-default-cleanup.md`
   anchor: line matching `If any item cannot be applied exactly, STOP and report a spec gap. If the glossary tests reject the new text, STOP and report the failing check verbatim; do not reshape the entries.`
   indent: 0
   before:
```
If any item cannot be applied exactly, STOP and report a spec gap. If the glossary tests reject the new text, STOP and report the failing check verbatim; do not reshape the entries.
~~~~~
```
   after:
```
If any item cannot be applied exactly, STOP and report a spec gap. If the glossary tests reject the new text, STOP and report the failing check verbatim; do not reshape the entries.
~~~~~

## Status update (2026-10-09)

Closed. hdc-1 .. hdc-6 are reviewer-PASSed; hdc-5 passed after two FAILs, the second a contract defect (see the Ruling). The reviewers' remaining notes are carried by docs/plans/2026-10-09-backlog-cleanup.md. Trailer sweep (blc-4): the hdc-1, hdc-2, hdc-4 and hdc-5 contracts gave a placeholder instead of a model name in their trailer line; each now names the trailer its first commit carries (Claude Haiku 4.5 for all four, measured with git log). hdc-5's fix-round commit 082ec3c carries the Claude Sonnet 5.5 trailer: a fix round's trailer names the model of its own tier. No other docs/plans contract held the placeholder.
```
13. command: `git add docs/plans/2026-10-06-rubric-gated-haiku-programme.md docs/plans/2026-10-06-contract-hardening.md docs/plans/2026-10-07-final-cleanup.md docs/plans/2026-10-08-haiku-default-tier.md docs/plans/2026-10-08-haiku-default-cleanup.md && git commit -m "docs(blc-4): proof line, closed stage statuses, trailer sweep (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `docs/plans/2026-10-09-backlog-cleanup.md` (this plan and its contracts; AC1 excludes it from the placeholder sweep because it spells the placeholder)
- `docs/plans/2026-10-08-contract-score-guard.md`
- `agents/` and `templates/` (no version bump applies)
- `.claude/` (no mirror exists for a plan file)

## Acceptance criteria
1. run: `git grep -c 'your model name' -- docs/plans ':!docs/plans/2026-10-09-backlog-cleanup.md' | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip one substitution of edit 2 (leave one occurrence); it prints `1`. It prints `1` at HEAD.
2. run: `/usr/bin/grep -c 'Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>' docs/plans/2026-10-08-haiku-default-cleanup.md`
   exit: 0
   stdout: `4`
   mutation: skip one substitution of edit 2; it prints `3`. It prints `0` at HEAD.
3. run: `sed -n '/^Unit: hdc-5$/,$p' docs/plans/2026-10-08-haiku-default-cleanup.md | /usr/bin/grep -cF "dropping 789725d's printed"; sed -n '/^Unit: hdc-5$/,$p' docs/plans/2026-10-08-haiku-default-cleanup.md | /usr/bin/grep -cF "one-commit range (the same"`
   exit: 0
   stdout: `0` then `1` (two lines)
   mutation: skip edit 1; it prints `1` then `0`, exit 1.
   proof: the count is scoped to the hdc-5 block (from its `Unit: hdc-5` line to the end of the file) because hdc-4's own criterion 7 carries the same proof sentence at line 821, which is correct for hdc-4's one-commit range and stays; a whole-file count would print `1` after the edit.
4. run: `for f in docs/plans/2026-10-06-rubric-gated-haiku-programme.md docs/plans/2026-10-06-contract-hardening.md docs/plans/2026-10-07-final-cleanup.md docs/plans/2026-10-08-haiku-default-tier.md docs/plans/2026-10-08-haiku-default-cleanup.md; do /usr/bin/grep -c '^Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (' "$f"; /usr/bin/grep -c '^## Status update (2026-10-09)$' "$f"; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 1 1 1 1 1 1 1 `
   mutation: skip any one of edits 3-12 for one file; a `0` appears at that file's position.
5. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | tail -1)~1; git diff --numstat "$B..$U" | sort -k3 | awk '{print $1"/"$2}' | tr '\n' ' '`
   exit: 0
   stdout: `5/1 5/1 5/1 10/6 5/1 `
   mutation: wrap an appended paragraph over two lines, or insert a line above the end of a file; a count changes (for example `6/1`). Path order after `sort -k3`: contract-hardening, rubric-gated, final-cleanup, haiku-default-cleanup, haiku-default-tier.
   proof: spec-master measured that each file ends with a newline and that each appended section is four lines (blank, heading, blank, one-line paragraph); the hdc file also swaps the proof line (1 added, 1 deleted) and four trailer lines (4 added, 4 deleted), giving deleted 6, added 10. Not run end to end by task-master.
6. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-4\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
7. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
8. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- docs/plans/2026-10-06-rubric-gated-haiku-programme.md docs/plans/2026-10-06-contract-hardening.md docs/plans/2026-10-07-final-cleanup.md docs/plans/2026-10-08-haiku-default-tier.md docs/plans/2026-10-08-haiku-default-cleanup.md | /usr/bin/grep -vcE '^[a-z]+\(blc-4\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
9. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' docs/plans/2026-10-06-rubric-gated-haiku-programme.md docs/plans/2026-10-06-contract-hardening.md docs/plans/2026-10-07-final-cleanup.md docs/plans/2026-10-08-haiku-default-tier.md docs/plans/2026-10-08-haiku-default-cleanup.md | sort) && echo scope-blc-4-ok`
   exit: 0
   stdout: `scope-blc-4-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
10. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
11. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-4\): ' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file exactly once. Edits 1, 2 and 13 are commands and carry no anchor. On any mismatch STOP and report; do not adapt the text.
precondition: `sed -n 989p docs/plans/2026-10-08-haiku-default-cleanup.md | /usr/bin/grep -cF "dropping 789725d's printed"` prints `1` and `sed -n 984p docs/plans/2026-10-08-haiku-default-cleanup.md | /usr/bin/grep -cF "(hdc-5)"` prints `1`. Anything else: STOP (edit 1 addresses hdc-5's criterion 7 proof line by number because the identical hdc-4 sentence at line 821 must stay).
precondition: `/usr/bin/grep -o 'Co-Authored-By: Claude <your model name> <noreply@anthropic.com>' docs/plans/2026-10-08-haiku-default-cleanup.md | wc -l` prints `4`. Anything else: STOP.
tdd: no prose-only edits to plan documents; the checks are greps and a numstat shape that fixes every line count
blast-radius: docs/plans/2026-10-08-haiku-default-cleanup.md:3, docs/plans/2026-10-08-haiku-default-cleanup.md:989, docs/plans/2026-10-06-rubric-gated-haiku-programme.md:3, docs/plans/2026-10-06-contract-hardening.md:3, docs/plans/2026-10-07-final-cleanup.md:3, docs/plans/2026-10-08-haiku-default-tier.md:3
note: no edit may insert or delete a line above an existing line, because reviewer notes and plans cite line numbers in these files (for example docs/plans/2026-10-07-final-cleanup.md:114-118, docs/plans/2026-10-08-haiku-default-cleanup.md:958-962). Every edit here is a same-line substitution or an append at the end of the file.
note: payload fences sit at column 0 and hold the file's literal text; `indent: N` is the smallest leading-space count of the payload's non-empty lines (0 throughout), so nothing is stripped or added. Appended payloads begin with one empty line, which is part of the text, and each paragraph is ONE line.
note: edit 12 matches the last two lines of the hdc plan (a text line, then the closing fence `~~~~~`) because the closing fence line alone is not unique in that file.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-4)` as its subject scope. Gate friction on prose: commit with `git commit -F <file>` if a message scan blocks `-m`; never rephrase to dodge a gate.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: docs(blc-4): proof line, closed stage statuses, trailer sweep (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-4 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blc-5

~~~~~~~markdown
Unit: blc-5

## Objective
Every commit of a unit, fix rounds included, carries `(<unit-id>)` as its subject scope; `agents/task-master.md` finds a unit's first and last commits with the anchored pattern `^[a-z]+\(<unit-id>\): ` instead of `-F --grep='(<unit-id>)'`, and every range contract adds an untagged-tail criterion. Version 0.31.148; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-5`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/task-master.md` (anchors below)
- `agents/lead-programmer.md` (anchor: line matching `without a contract (task-master absent) leaves them in force.`)
- `adapters/cursor/agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml` (anchor: line matching `without a contract (task-master absent) leaves them in force.`)
- `agents/scribe.md` (anchor: line matching `on top of the contract.`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.147",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/task-master.md`
   anchor: line matching `**Range criteria.** A criterion over a commit range binds its end to the`
   indent: 2
   before:
```
  **Range criteria.** A criterion over a commit range binds its end to the
  unit's own last commit, `git log --format=%H -F --grep='(<unit-id>)' | head
  -1`, never `HEAD`. A red-set criterion over a test file that runs git uses a
```
   after:
```
  **Range criteria.** A criterion over a commit range binds its start and end
  to the unit's own first and last commits, found with `git log --format=%H -E
  --grep='^[a-z]+\(<unit-id>\): '` (`tail -1`, `head -1`), never `HEAD`; the
  anchored pattern matches only a subject whose scope is the unit, never a later
  commit that merely mentions it. That end holds only if every commit of the
  unit, fix rounds included, carries `(<unit-id>)` as its subject scope, so
  every `commit-message:` line of a contract or fix contract does, and every
  range contract adds one untagged-tail criterion, run at review time over the
  unit's content files (never the version files or `.claude/`): `git log
  --format=%s <end>..HEAD -- <content files> | grep -vcE
  '^[a-z]+\(<unit-id>\): '`, `exit: 1`, `stdout: 0`. A red-set criterion over a
  test file that runs git uses a
```
2. file: `agents/task-master.md`
   anchor: line matching `lookups. If it cannot determine the cause, it writes no fix`
   indent: 2
   before:
```
  `explorer` lookups. If it cannot determine the cause, it writes no fix
```
   after:
```
  `explorer` lookups. Its `commit-message:` subject carries `(<unit-id>)` as
  its scope, like the original contract's. If it cannot determine the cause, it
  writes no fix
```
3. file: `agents/lead-programmer.md`
   anchor: line matching `without a contract (task-master absent) leaves them in force.`
   indent: 2
   before:
```
  without a contract (task-master absent) leaves them in force.
```
   after:
```
  without a contract (task-master absent) leaves them in force. Every fix
  commit's subject carries `(<task-id>)` as its scope, like the unit's first
  commit, with or without a contract, so the unit's range criteria see it.
```
4. file: `adapters/cursor/agents/lead-programmer.md`
   anchor: line matching `without a contract (task-master absent) leaves them in force.`
   indent: 2
   before:
```
  without a contract (task-master absent) leaves them in force.
```
   after:
```
  without a contract (task-master absent) leaves them in force. Every fix
  commit's subject carries `(<task-id>)` as its scope, like the unit's first
  commit, with or without a contract, so the unit's range criteria see it.
```
5. file: `adapters/codex/agents/lead-programmer.toml`
   anchor: line matching `without a contract (task-master absent) leaves them in force.`
   indent: 2
   before:
```
  without a contract (task-master absent) leaves them in force.
```
   after:
```
  without a contract (task-master absent) leaves them in force. Every fix
  commit's subject carries `(<task-id>)` as its scope, like the unit's first
  commit, with or without a contract, so the unit's range criteria see it.
```
6. file: `agents/scribe.md`
   anchor: line matching `on top of the contract.`
   indent: 0
   before:
```
on top of the contract.
```
   after:
```
on top of the contract. Without a contract, every commit of a unit, fix rounds
included, carries `(<task-id>)` as its subject scope.
```
7. file: `.claude-plugin/plugin.json` (version 0.31.148)
   anchor: line matching `"version": "0.31.147",`
   before: `  "version": "0.31.147",`
   after: `  "version": "0.31.148",`
8. file: `package.json` (version 0.31.148)
   anchor: line matching `"version": "0.31.147",`
   before: `  "version": "0.31.147",`
   after: `  "version": "0.31.148",`
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Unit commits carry their scope (blc-5, 0.31.148).** `agents/task-master.md`: a unit's range criteria find its first and last commits with the anchored `git log --format=%H -E --grep='^[a-z]+\(<unit-id>\): '`, which no later commit that merely mentions the unit id can match, and every range contract adds an untagged-tail criterion (`exit: 1`, `stdout: 0`) so a fix-round commit outside the unit's scope is caught at review time; a fix contract's `commit-message:` carries the unit scope. `agents/lead-programmer.md` and its Cursor and Codex ports: every fix commit's subject carries `(<task-id>)`, with or without a contract. `agents/scribe.md`: without a contract, every commit of a unit, fix rounds included, carries `(<task-id>)`. No hook is added. Mirrors refreshed by `node bin/cli.js --update`.
```
10. command: `node bin/cli.js --update`
   expect: 0
11. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
12. command: `git add agents/task-master.md agents/lead-programmer.md adapters/cursor/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml agents/scribe.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(blc-5): unit commits carry their scope; anchored range pattern (0.31.148) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
    expect: 0
13. command: `git status --porcelain --untracked-files=no | wc -l`
    expect: 0
    stdout: `0`

## Do NOT touch
- `agents/orchestrator.md` (unit blc-6 edits it, serially after this unit)
- `templates/` (unit blc-6)
- `tests/` (the pinned substrings stay as they are)
- `hooks/` (no hook is added; `dispatchHygiene` stays `warn`)
- `docs/adr/` and `CONTEXT.md`

## Acceptance criteria
1. run: `for p in "fix rounds included, carries" "untagged-tail criterion" "merely mentions it"; do tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 `
   mutation: skip edit 1; it prints `0 0 0 `. It prints `0 0 0 ` at HEAD.
2. run: `/usr/bin/grep -cF -- "-F --grep='(<unit-id>)'" agents/task-master.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 1; it prints `1`, exit 0.
3. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -oF 'as its scope, like the original contract' | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`.
4. run: `for f in agents/lead-programmer.md agents/scribe.md; do tr '\n' ' ' < "$f" | tr -s ' ' | /usr/bin/grep -oE "Every fix commit's subject carries|fix rounds included, carries" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 `
   mutation: skip edit 3 or edit 6; that file's position prints `0`.
5. run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 4; it prints `exit=1` (AC-A1: the Contract precedence paragraph must read the same in agents/lead-programmer.md and both ports). Deleting the line `- **Contract precedence.**` from agents/lead-programmer.md also prints `exit=1` (AC-P3). This already passes at HEAD and must stay green.
6. run: `for f in .claude/agents/task-master.md .claude/agents/scribe.md .claude/agents/lead-programmer.md; do tr '\n' ' ' < "$f" | tr -s ' ' | /usr/bin/grep -oE "fix rounds included, carries|Every fix commit's subject carries" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 `
   mutation: skip edit 10 (`node bin/cli.js --update`); it prints `0 0 0 `.
7. run: `for f in adapters/cursor/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml; do tr '\n' ' ' < "$f" | tr -s ' ' | /usr/bin/grep -oF "Every fix commit's subject carries" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 `
   mutation: skip edit 4 or edit 5; that port's position prints `0` and criterion 5 fails on AC-A1.
8. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-5\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
9. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
10. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- agents/task-master.md agents/lead-programmer.md agents/scribe.md adapters/cursor/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml | /usr/bin/grep -vcE '^[a-z]+\(blc-5\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
11. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' agents/task-master.md agents/lead-programmer.md agents/scribe.md adapters/cursor/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml .claude-plugin/plugin.json CHANGELOG.md package.json | sort) && echo scope-blc-5-ok`
   exit: 0
   stdout: `scope-blc-5-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
12. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | tail -1)~1; bash hooks/scripts/version-stamp-check.sh "$B..$U" | /usr/bin/grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip the plugin.json bump; the line no longer reads `ok` and it prints `0`, exit 1 (the script itself exits 0 on a violation, so this gates on stdout).
13. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.148';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip the package.json bump; it prints `version-sync: mismatch`, exit 1.
14. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | tail -1)~1; git diff --name-only "$B..$U" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip `node bin/cli.js --update`; it prints `0`.
   proof: ten agent mirrors, three protocol files and `.claude/persona-config.json`, as csg-2 measured; re-measure if a mirror is added.
15. run: `node bin/cli.js --update | /usr/bin/grep -c 'already current'`
   exit: 0
   stdout: `1`
   mutation: leave a `.claude/` mirror stale; `--update` rewrites it and the line is absent (prints `0`, exit 1).
16. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
17. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.147`. Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1 and rewrites this contract's version lines before dispatch.
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
precondition: no other unit that runs `node bin/cli.js --update` is in flight (blc-6 starts after this unit's PASS), and the tree is clean.
tdd: no prose-only edits to persona instructions; the checks are flattened-phrase greps, the existing tests/writer-tier-consistency.test.js pins, and validate.sh mirror parity
blast-radius: agents/task-master.md:199, agents/task-master.md:98, agents/lead-programmer.md:46, adapters/cursor/agents/lead-programmer.md:51, adapters/codex/agents/lead-programmer.toml:52, agents/scribe.md:106, tests/writer-tier-consistency.test.js:180
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. The CHANGELOG payload begins with one empty line, which is part of the text; its entry is ONE line.
note: edits 4 and 5 (the two lead-programmer ports) are not in the plan's Step 5 file list; replaying the unit in a scratch worktree of 5720c5b showed tests/writer-tier-consistency.test.js AC-A1 fails without them (the Contract precedence paragraph must be identical in agents/lead-programmer.md and both ports), so they are folded in here. Spec-master should add them to Step 5.
note: edit 1's after-text ends mid-sentence ("uses a") on purpose: the next original line, which stays, starts with the code span `git worktree add --detach`.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-5)` as its subject scope; this unit is the first to state that rule, and its own range criteria already use the anchored pattern.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: feat(blc-5): unit commits carry their scope; anchored range pattern (0.31.148) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-5 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blc-6

~~~~~~~markdown
Unit: blc-6

## Objective
`templates/protocol-digest.md` keeps all six rules in at most 15 non-empty body lines and `tests/protocol-doc-drift.test.js` enforces that budget; `agents/orchestrator.md` (At the 2-FAIL cap), the digest and `templates/persona-protocol.md` define ladder exhaustion with the same phrase ("reaching or exceeding the ladder's length"); the orchestrator's Contract-score guard paragraph says its "scoring is pure" claim assumes an unchanged contract of record, and `tests/writer-tier-consistency.test.js` pins that paragraph. Version 0.31.149; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-6`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/protocol-doc-drift.test.js` (anchor: line matching `if (failures) {`)
- `templates/protocol-digest.md` (anchors below)
- `templates/persona-protocol.md` (anchor: line matching `human stop happens there. Only the second FAIL on the ladder's top tier,`)
- `agents/orchestrator.md` (anchors below)
- `tests/writer-tier-consistency.test.js` (anchor: line matching `hasAll('agents/lead-programmer.md', ['- **Contract precedence.**']);`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.148",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `tests/protocol-doc-drift.test.js`
   anchor: line matching `if (failures) {`
   indent: 0
   before:
```
if (failures) {
  console.log(`\n${failures} protocol-doc-drift check(s) FAILED.`);
```
   after:
```
check('templates/protocol-digest.md stays within its budget: at most 15 non-empty lines after the header comment', () => {
  const text = fs.readFileSync(path.join(REPO_ROOT, 'templates', 'protocol-digest.md'), 'utf8');
  const end = text.indexOf('-->');
  assert.ok(end >= 0, 'the digest must keep its header comment');
  const body = text.slice(end + 3).split('\n').filter((l) => l.trim() !== '');
  assert.ok(body.length <= 15, `digest body has ${body.length} non-empty lines; trim it or mechanize the rule (a hook) instead`);
});

if (failures) {
  console.log(`\n${failures} protocol-doc-drift check(s) FAILED.`);
```
2. command: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=1`
3. file: `templates/protocol-digest.md`
   anchor: line matching `Keep this under ~15 lines - if it grows,`
   indent: 0
   before:
```
Keep this under ~15 lines - if it grows,
```
   after:
```
Keep the body to at most 15 non-empty lines (tested) - if it grows,
```
4. file: `templates/protocol-digest.md`
   anchor: line matching `# Protocol digest (post-compaction/resume reminder)`
   indent: 0
   before:
```
# Protocol digest (post-compaction/resume reminder)

- Structural questions (where something's defined, what calls it, blast
  radius, test coverage): spawn `explorer`. Don't invoke the
  code-review-graph skill directly.
- Review ownership: lead-programmer never spawns or messages the reviewer
  directly, and the reviewer never spawns or messages the lead-programmer.
  Only the orchestrator/team lead routes between them. "Done" means the
  reviewer returned PASS, not "looks finished" - and on a critical unit PASS
  may first route through ESCALATE-TO-HUMAN.
- FAIL cap: 2 FAILs per implementer tier -> move the unit up the Escalation
  ladder; only at ladder exhaustion (the top tier's second FAIL) stop
  re-delegating and surface the full defect history to the user instead.
- The WIP sentinel (`.claude/wip-handoff.<agent-id>`) is for a genuine
  mid-task pause only - never to dodge a red suite you could otherwise fix.
  It must contain a stated reason; an empty sentinel is ignored.
- A gated agent's stop without review sets `.claude/.pending-review.<id>` -
  it blocks turn-end and the next implementation dispatch until the reviewer
  runs (clearing it) or you write `defer: <reason>`/`skip: <reason>` into it.
- `memory: <scope>` auto-grants Read/Write/Edit for memory files regardless
  of your declared `tools:` - that is not license to edit source code (or
  any file outside your role's stated scope) if your role says you never do.
```
   after:
```
# Protocol digest (post-compaction/resume reminder)

- Structural questions (definitions, callers, blast radius, coverage): spawn
  `explorer`; never invoke the code-review-graph skill directly.
- Only the orchestrator/team lead routes between lead-programmer and reviewer.
  "Done" = reviewer PASS (a critical unit may first route through
  ESCALATE-TO-HUMAN).
- 2 FAILs per implementer tier move the unit up the Escalation ladder; only
  ladder exhaustion (FAIL count reaching or exceeding the ladder's length)
  stops re-delegation and surfaces the full defect history to the user.
- WIP sentinel `.claude/wip-handoff.<agent-id>`: genuine mid-task pause only,
  with a stated reason (empty is ignored); never to dodge a fixable red suite.
- `.claude/.pending-review.<id>` blocks turn-end and the next implementation
  dispatch until the reviewer runs or it holds `defer: <reason>`/`skip: <reason>`.
- `memory:` auto-grants Read/Write/Edit; that is not license to edit outside
  your role's stated scope.
```
5. command: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
6. file: `agents/orchestrator.md`
   anchor: line matching `At **ladder exhaustion** (the second FAIL on the ladder's top tier), stop`
   indent: 0
   before:
```
(the second FAIL on the ladder's top tier), stop
```
   after:
```
(the unit's FAIL-block count reaching or exceeding the ladder's length: normally the second FAIL on the ladder's top tier, or any later FAIL after a human-directed re-dispatch), stop
```
7. file: `templates/persona-protocol.md`
   anchor: line matching `human stop happens there. Only the second FAIL on the ladder's top tier,`
   indent: 0
   before:
```
human stop happens there. Only the second FAIL on the ladder's top tier,
ladder exhaustion, stops re-dispatch: the orchestrator (or team lead) then
```
   after:
```
human stop happens there. Only ladder exhaustion (the unit's FAIL count
reaching or exceeding the ladder's length: normally the second FAIL on its top
tier) stops re-dispatch: the orchestrator (or team lead) then
```
8. file: `agents/orchestrator.md`
   anchor: line matching `ladder from n and the contract; it can only move a unit onto a more capable`
   indent: 0
   before:
```
ladder from n and the contract; it can only move a unit onto a more capable
```
   after:
```
ladder from n and the contract of record, provided it is unchanged (a plan
file revised between dispatches can demote a unit that passed earlier, even
mid-ladder); it can only move a unit onto a more capable
```
9. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `hasAll('agents/lead-programmer.md', ['- **Contract precedence.**']);`
   indent: 0
   before:
```
  hasAll('agents/lead-programmer.md', ['- **Contract precedence.**']);
});
```
   after:
```
  hasAll('agents/lead-programmer.md', ['- **Contract precedence.**']);
});

check('AC-P4: orchestrator.md keeps the Contract-score guard paragraph and its unchanged-contract caveat', () => {
  hasAll('agents/orchestrator.md', ['**Contract-score guard.**', 'node bin/contract-guard.js', 'contract-guard: haiku',
    '**guard demotion**', 'decision=contract-guard sonnet:', '--shape=scribe', 'provided it is unchanged']);
});
```
10. file: `.claude-plugin/plugin.json` (version 0.31.149)
   anchor: line matching `"version": "0.31.148",`
   before: `  "version": "0.31.148",`
   after: `  "version": "0.31.149",`
11. file: `package.json` (version 0.31.149)
   anchor: line matching `"version": "0.31.148",`
   before: `  "version": "0.31.148",`
   after: `  "version": "0.31.149",`
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Digest within budget; one definition of ladder exhaustion (blc-6, 0.31.149).** `templates/protocol-digest.md` keeps all six rules in 15 non-empty body lines and `tests/protocol-doc-drift.test.js` now fails when the body grows past 15. `agents/orchestrator.md` (At the 2-FAIL cap), the digest and `templates/persona-protocol.md` define ladder exhaustion the same way: the unit's FAIL count reaching or exceeding the ladder's length, normally the second FAIL on the top tier. `agents/orchestrator.md`: the Contract-score guard paragraph now says that its "scoring is pure" claim assumes an unchanged contract of record, and `tests/writer-tier-consistency.test.js` (AC-P4) pins that paragraph. Mirrors refreshed by `node bin/cli.js --update`.
```
13. command: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
14. command: `node bin/cli.js --update`
   expect: 0
15. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
16. command: `git add agents/orchestrator.md templates/protocol-digest.md templates/persona-protocol.md tests/protocol-doc-drift.test.js tests/writer-tier-consistency.test.js .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(blc-6): digest within budget; one definition of ladder exhaustion; guard paragraph pinned (0.31.149) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
17. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `bin/contract-guard.js` and `tests/contract-score.test.js` (unit blc-8)
- `CONTEXT.md` and `docs/harness-glossary.md` (unit blc-7; scribe owns them)
- `docs/adr/0040-implementer-tier-haiku-default.md`
- `agents/task-master.md`, `agents/lead-programmer.md`, `agents/scribe.md` (unit blc-5)
- `adapters/cursor/agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml` (unit blc-5, ruling H-BLC5)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 4 (the digest body is 21 non-empty lines today); it prints `exit=1`. Skip edit 1 as well and it prints `exit=0` (no budget check), which is why edit 2 shows the red state first.
2. run: `awk 'f && NF; /-->/{f=1}' templates/protocol-digest.md | wc -l`
   exit: 0
   stdout: `15`
   mutation: skip edit 4; it prints `21` (measured at 5720c5b).
3. run: `for t in explorer code-review-graph ESCALATE-TO-HUMAN 'Escalation ladder' 'ladder exhaustion' wip-handoff .pending-review 'defer:' 'skip:' 'memory:'; do tr '\n' ' ' < templates/protocol-digest.md | tr -s ' ' | /usr/bin/grep -oF -- "$t" | wc -l; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop the `memory:` rule from the digest; it prints `0 1 `.
4. run: `for f in agents/orchestrator.md templates/persona-protocol.md templates/protocol-digest.md; do tr '\n' ' ' < "$f" | tr -s ' ' | /usr/bin/grep -oF "reaching or exceeding the ladder's length" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 `
   mutation: skip edit 6, 7 or 4; that file's position prints `0`.
5. run: `/usr/bin/grep -cF "(the second FAIL on the ladder's top tier), stop" agents/orchestrator.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 6; it prints `1`, exit 0.
6. run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1 && /usr/bin/grep -c 'Contract-score guard' agents/orchestrator.md`
   exit: 0
   stdout: `1`
   mutation: delete the Contract-score guard paragraph from agents/orchestrator.md; the AC-P4 pin fails and nothing prints, exit 1.
7. run: `for f in .claude/protocol-digest.md .claude/persona-protocol.md; do tr '\n' ' ' < "$f" | tr -s ' ' | /usr/bin/grep -oF "reaching or exceeding the ladder's length" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 `
   mutation: skip edit 14 (`node bin/cli.js --update`); it prints `0 0 `.
8. run: `node tests/writer-tier-consistency.test.js 2>&1 | /usr/bin/grep -c '^OK   AC-P4: orchestrator.md keeps the Contract-score guard paragraph'`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; it prints `0`, exit 1.
9. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oF 'provided it is unchanged (a plan file revised between dispatches can demote a unit that passed earlier, even mid-ladder)' | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; it prints `0`. With edit 9 applied and edit 8 skipped, criterion 8 also prints `0`, so the pin is not vacuous.
10. run: `tr '\n' ' ' < .claude/agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oF 'provided it is unchanged (a plan file revised between dispatches' | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 14; it prints `0`.
11. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-6\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
12. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
13. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- templates/protocol-digest.md templates/persona-protocol.md agents/orchestrator.md tests/protocol-doc-drift.test.js tests/writer-tier-consistency.test.js | /usr/bin/grep -vcE '^[a-z]+\(blc-6\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
14. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' templates/protocol-digest.md templates/persona-protocol.md agents/orchestrator.md tests/protocol-doc-drift.test.js tests/writer-tier-consistency.test.js .claude-plugin/plugin.json CHANGELOG.md package.json | sort) && echo scope-blc-6-ok`
   exit: 0
   stdout: `scope-blc-6-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
15. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | tail -1)~1; bash hooks/scripts/version-stamp-check.sh "$B..$U" | /usr/bin/grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip the plugin.json bump; the line no longer reads `ok` and it prints `0`, exit 1 (the script itself exits 0 on a violation, so this gates on stdout).
16. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.149';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip the package.json bump; it prints `version-sync: mismatch`, exit 1.
17. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | tail -1)~1; git diff --name-only "$B..$U" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip `node bin/cli.js --update`; it prints `0`.
   proof: ten agent mirrors, three protocol files and `.claude/persona-config.json`, as csg-2 measured; re-measure if a mirror is added.
18. run: `node bin/cli.js --update | /usr/bin/grep -c 'already current'`
   exit: 0
   stdout: `1`
   mutation: leave a `.claude/` mirror stale; `--update` rewrites it and the line is absent (prints `0`, exit 1).
19. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
20. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.148` (unit blc-5 has landed). Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1 and rewrites this contract's version lines before dispatch.
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-6\): ' | wc -l` prints `0`, and `git log --format=%H -E --grep='^[a-z]+\(blc-5\): ' | wc -l` is at least `1` (the orchestrator confirms the blc-5 PASS marker before dispatch). Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
precondition: no other unit that runs `node bin/cli.js --update` is in flight, and the tree is clean.
tdd: yes tests/protocol-doc-drift.test.js (edit 1 adds the budget check, edit 2 shows it red against the 21-line digest, edit 5 shows it green); tests/writer-tier-consistency.test.js gains the AC-P4 pin
blast-radius: tests/protocol-doc-drift.test.js:1, templates/protocol-digest.md:7, templates/persona-protocol.md:708, agents/orchestrator.md:362, agents/orchestrator.md:503, tests/writer-tier-consistency.test.js:203, hooks/scripts/session-start.sh:63
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 12's payload begins with one empty line, which is part of the text and its entry is ONE line. Edit 4's before-text is the whole old digest body from its heading to its last line; the blank line before the heading stays.
note: edit 3 writes "at most 15 non-empty lines" where the plan's prose says "under 15", because the test allows 15 and the new body has exactly 15. Edits 8 and 9 (the guard caveat and its pin) were requested by the reviewers of csg-2 and are folded in here; the plan's Step 6 does not list them.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-6)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: feat(blc-6): digest within budget; one definition of ladder exhaustion; guard paragraph pinned (0.31.149) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-6 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blc-7

~~~~~~~markdown
Unit: blc-7

## Objective
CONTEXT.md says a `Suggested model` tag can only raise a unit's tier (entry **defaultImplementerModel**), defines **contract of record** and **rubric v2**, and links the **Contract-score guard** entry to them and to the **Rulings ledger** entry that docs/harness-glossary.md already defines.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-7`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Items 1, 2, 3 and 4 replace a substring of one line: each `before:` is that substring (no leading or trailing spaces, so the line's own spaces stay), and `text:` replaces exactly that substring. Items 5 and 6 add a new entry: insert one empty line and then the `text:` lines directly after the `_Avoid_:` line of the entry named by `heading:`; the empty line that already follows that entry stays after the new entry. Do items in the order given.
1. file: `CONTEXT.md`
   heading: `**defaultImplementerModel**:`
   before:
```
tag (if present),
```
   text:
```
tag (if present), which can only raise a unit's tier above its ladder's entry, never lower it (see [[default tier]]),
```
2. file: `CONTEXT.md`
   heading: `**Contract-score guard**:`
   before:
```
the unit's contract of record (its
```
   text:
```
the unit's [[contract of record]] (its
```
3. file: `CONTEXT.md`
   heading: `**Contract-score guard**:`
   before:
```
under rubric v2, and unless
```
   text:
```
under [[rubric v2]], and unless
```
4. file: `CONTEXT.md`
   heading: `**Contract-score guard**:`
   before:
```
is recorded in the orchestrator's Rulings ledger,
```
   text:
```
is recorded in the orchestrator's [[Rulings ledger]],
```
5. file: `CONTEXT.md`
   heading: `**Contract-score guard**:`
   text:
```
**contract of record**:
(unit blc-7, 2026-10-09) — the one contract block the [[Contract-score guard]]
  scores for a unit: its `Unit: <id>` dispatch contract in the plan file or
  issue body the dispatch cites, never a fix contract. Because the guard
  re-runs on every dispatch, a revision of that plan file between two
  dispatches replaces the contract of record, and the next run can score a
  different block than the one before it did.
_Avoid_: contract (alone: a fix contract is a different artifact), dispatch prompt
```
6. file: `CONTEXT.md`
   heading: `**contract of record**:`
   text:
```
**rubric v2**:
(unit blc-7, 2026-10-09) — the second scoring table of `bin/contract-score.js`,
  selected with `--rubric=v2`. A lead-programmer contract is scored on rows
  R1-R7 (ordered edits carry literal payloads, version-stamp obligations,
  criteria carry `exit:`, `stdout:` and `mutation:`, no host paths, a
  pre-resolved context with a review-packet template, a Do NOT touch list, and
  `diagnosis: none`); a scribe contract on rows S1-S7. The [[Contract-score
  guard]] scores under rubric v2 only; v1 stays for older contracts.
_Avoid_: rubric (alone), contract score (the number it yields)
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: blc-7
- marker first line: "PASS blc-7 "
- commit: one commit of CONTEXT.md (plus one per fix round after a FAIL), subject `docs(blc-7): glossary defaultImplementerModel tag, contract of record, rubric v2, Rulings ledger link (#529)`, then a second `-m` argument holding exactly the line `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` (a fix round on another tier names that tier's model). Every commit of this unit carries `(blc-7)` as its subject scope.
- precondition: the csg-4 PASS marker exists (the orchestrator confirms it before dispatch); `git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | wc -l` prints `0`; each `before:` substring appears in CONTEXT.md exactly once (`/usr/bin/grep -cF -- '<before text>' CONTEXT.md` prints `1`, or `tr` the file flat first for a wrapped one); the headings `**contract of record**:` and `**rubric v2**:` appear in neither CONTEXT.md nor docs/harness-glossary.md. Anything else: STOP and report a spec gap.
- if a glossary test rejects the new text, STOP and report the failing check verbatim; do not reshape the entries. If a message scan blocks `-m`, commit with `git commit -F <file>`; never rephrase to dodge a gate.
- the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.

## Do NOT touch
- every other entry of `CONTEXT.md` (in particular **default tier**, **Haiku-default cutover**, **Escalation ladder**, **ladder exhaustion**, **Suggested model vocabulary**)
- `docs/harness-glossary.md` (the **Rulings ledger** entry is already defined there and stays)
- `docs/adr/`, `agents/`, `templates/`, `tests/`, `bin/`

## Acceptance criteria
1. run: `awk '/^\*\*defaultImplementerModel\*\*:/,/^$/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -oF 'can only raise a unit' | wc -l`
   exit: 0
   stdout: `1`
   mutation: put the sentence in the **default tier** entry instead; it prints `0` (the class of the hdc-5 FAIL: wrong entry). It prints `0` at HEAD.
2. run: `/usr/bin/grep -c '^\*\*contract of record\*\*:$' CONTEXT.md; /usr/bin/grep -c '^\*\*rubric v2\*\*:$' CONTEXT.md`
   exit: 0
   stdout: `1` then `1` (two lines)
   mutation: skip item 5; it prints `0` then `1`, exit 1. Skip item 6; `1` then `0`.
3. run: `awk '/^\*\*Contract-score guard\*\*:/,/^_Avoid_/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -oE '\[\[(contract of record|rubric v2|Rulings ledger)\]\]' | sort | tr '\n' ' '`
   exit: 0
   stdout: `[[Rulings ledger]] [[contract of record]] [[rubric v2]] `
   mutation: skip item 4; the first link is missing. It prints nothing at HEAD.
4. run: `node tests/context-glossary-links.test.js 2>&1 | tail -n 1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: write `[[default-tier]]` in item 1; the link check names it as dangling and the last line changes.
5. run: `node tests/ubiquitous-language.test.js 2>&1 | tail -n 1`
   exit: 0
   stdout: `passes all 4 structural/distinguishability checks`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero (it checks skills/ubiquitous-language/SKILL.md, not the entries).
   proof: `UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js` exits non-zero. This criterion already passes at HEAD and must stay green.
6. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | tail -1)~1; git diff --name-only "$B..$U" | tr '\n' ' '; git diff -U0 "$B..$U" -- CONTEXT.md | /usr/bin/grep -c '^@@'`
   exit: 0
   stdout: `CONTEXT.md 5` (the file list, a space, then the hunk count)
   mutation: also edit another entry; the hunk count becomes `6`. Skip item 5 or item 6; it becomes `4`.
7. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-7\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
8. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
9. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- CONTEXT.md | /usr/bin/grep -vcE '^[a-z]+\(blc-7\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
10. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-7\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' CONTEXT.md | sort) && echo scope-blc-7-ok`
   exit: 0
   stdout: `scope-blc-7-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
11. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
12. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blc-8

~~~~~~~markdown
Unit: blc-8

## Objective
`bin/contract-guard.js` exits 2 on any extra argument or unknown flag (for example `--shape scribe` with a space) and documents in its header that a longer closing fence leaves a block open (the unit then falls to sonnet); `tests/contract-score.test.js` pins both, and its `guard-plan-files` check reads a fixture copy under `tests/fixtures/contract-score/` instead of the live plan (docs/plans is export-ignored, so it is absent from a `git archive`).

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-cleanup.md`, `## Unit blc-8`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP. This unit folds in three reviewer notes (csg-1 and csg-2 PASS notes) that no plan unit covered.

## Affected files
- `bin/contract-guard.js` (anchors below)
- `tests/contract-score.test.js` (anchor: line matching `check('guard-plan-files', () => {`)
- `tests/fixtures/contract-score/guard-plan-hdc.md` (new file, created by a command item)

## Ordered edits
1. file: `bin/contract-guard.js`
   anchor: line matching `const file = args.find((a) => !a.startsWith('--') || a === '-');`
   indent: 2
   before:
```
  const file = args.find((a) => !a.startsWith('--') || a === '-');
```
   after:
```
  const rest = args.filter((a) => !/^--(unit|shape)=/.test(a));
  if (rest.length > 1) usage(`unexpected argument(s): ${rest.slice(1).join(' ')}`);
  const file = rest[0];
```
2. file: `bin/contract-guard.js`
   anchor: line matching `and any non-zero exit, as`
   indent: 0
   insert-after:
```
//
// Any argument other than one <path|-> and the --unit=<id> / --shape=<lead|scribe> flags is a usage
// error (exit 2, empty stdout), for example `--shape scribe` written with a space.
//
// A fenced block opens on a run of three or more backticks or tildes and closes only on a line that
// holds exactly the same run. A longer closing fence therefore leaves the block open, it is never
// returned, and the unit falls to `reason=no-contract`, which fails safe to sonnet.
```
3. command: `git show 5720c5b:docs/plans/2026-10-08-haiku-default-cleanup.md | awk '/^## Unit hdc-(1|6)$/{p=1} /^## Unit hdc-(2|3|4|5)$/{p=0} p' > tests/fixtures/contract-score/guard-plan-hdc.md`
   expect: 0
4. file: `tests/contract-score.test.js`
   anchor: line matching `check('guard-plan-files', () => {`
   indent: 0
   before:
```
check('guard-plan-files', () => {
  const plan = 'docs/plans/2026-10-08-haiku-default-cleanup.md';
```
   after:
```
check('guard-usage-extra-args', () => {
  for (const args of [['-', '--unit=demo-2', '--shape', 'scribe'], ['-', '--unit=demo-2', '--bogus'], ['-', 'extra', '--unit=demo-2']]) {
    const r = guard(args, G_LEAD);
    assert.strictEqual(r.status, 2, `${args.join(' ')}: exit ${r.status}`);
    assert.strictEqual(r.stdout, '', `${args.join(' ')}: stdout ${r.stdout}`);
  }
});

check('guard-longer-closing-fence-leaves-block-open', () => {
  const doc = `~~~~~markdown\n${G_LEAD.trimEnd()}\n~~~~~~\n`;
  const line = gLine(guard(['-', '--unit=demo-2'], doc));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-2 shape=lead reason=no-contract');
});

check('guard-plan-files', () => {
  // A fixture copy of the hdc-1 and hdc-6 contracts (the plans directory is export-ignored, so a git archive lacks the live plan).
  const plan = `${FIX}/guard-plan-hdc.md`;
```
5. command: `node tests/contract-score.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
6. command: `git add bin/contract-guard.js tests/contract-score.test.js tests/fixtures/contract-score/guard-plan-hdc.md && git commit -m "fix(blc-8): contract guard rejects extra arguments; fence rule documented; plan-files check reads a fixture (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/contract-score.js` (the scorer is unchanged)
- `agents/orchestrator.md` (the guard paragraph is unit blc-6's; its call lines already pass only valid arguments)
- `docs/plans/2026-10-08-haiku-default-cleanup.md` (the fixture is a copy taken at 5720c5b; the plan itself stays as it is, unit blc-4 edits it)
- `.claude/` (bin/ and tests/ have no mirror; no `--update` and no version bump apply)

## Acceptance criteria
1. run: `node tests/contract-score.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 1; the new guard-usage-extra-args check fails and it prints `exit=1`. It prints `exit=0` at HEAD, and must stay green.
2. run: `node bin/contract-guard.js - --unit=demo-2 --shape scribe < tests/fixtures/contract-score/v2-all-pass.md > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=2`
   mutation: skip edit 1; it prints `exit=0` (the stray words are ignored). It prints `exit=0` at HEAD.
3. run: `tr '\n' ' ' < bin/contract-guard.js | tr -s ' ' | /usr/bin/grep -oF -e 'A longer closing fence therefore leaves the block open' -e 'which fails safe to sonnet' | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip edit 2; it prints `0`. It prints `0` at HEAD.
4. run: `/usr/bin/grep -c 'docs/plans' tests/contract-score.test.js; /usr/bin/grep -c 'guard-plan-hdc.md' tests/contract-score.test.js`
   exit: 0
   stdout: `0` then `1` (two lines)
   mutation: skip edit 4; it prints `1` then `0`, exit 1.
5. run: `node bin/contract-guard.js tests/fixtures/contract-score/guard-plan-hdc.md --unit=hdc-1 | cut -d' ' -f1-6; node bin/contract-guard.js tests/fixtures/contract-score/guard-plan-hdc.md --unit=hdc-6 --shape=scribe | cut -d' ' -f1-5`
   exit: 0
   stdout: `contract-guard: haiku unit=hdc-1 shape=lead score=7/7` then `contract-guard: sonnet unit=hdc-6 shape=scribe score=6/7` (two lines)
   mutation: skip edit 3; the fixture is missing, the guard exits 2 with no output and nothing prints.
6. run: `D=$(mktemp -d) && git worktree add --detach -q "$D" HEAD && rm -rf "$D/docs/plans" && node "$D/tests/contract-score.test.js" > /dev/null 2>&1; echo exit=$?; git worktree remove --force "$D"`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 4; the guard-plan-files check reads the missing live plan and it prints `exit=1`. It prints `exit=1` at HEAD.
7. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | tail -1)~1; git log --format=%s "$B..$U" | /usr/bin/grep -vcE '^[a-z]+\(blc-8\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
8. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | tail -1)~1; for c in $(git rev-list "$B..$U"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   mutation: drop one commit's trailer; it prints `0 1 ` (or `0 `).
9. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | tail -1)~1; git log --format=%s "$U"..HEAD -- bin/contract-guard.js tests/contract-score.test.js tests/fixtures/contract-score/guard-plan-hdc.md | /usr/bin/grep -vcE '^[a-z]+\(blc-8\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it exits 3.
10. run: `U=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | head -1); test -n "$U" || { echo no-unit-commit; exit 3; }; B=$(git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | tail -1)~1; diff <(git diff --name-only "$B..$U" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' bin/contract-guard.js tests/contract-score.test.js tests/fixtures/contract-score/guard-plan-hdc.md | sort) && echo scope-blc-8-ok`
   exit: 0
   stdout: `scope-blc-8-ok`
   mutation: touch one extra file in the unit's commit; diff exits 1.
11. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.
12. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of a `.claude/agents/*.md` mirror; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by task-master (about 11 minutes); the orchestrator runs it in the main checkout.

## Pre-resolved context
precondition: `git log --format=%H -E --grep='^[a-z]+\(blc-8\): ' | wc -l` prints `0`, and `git cat-file -t 5720c5b` prints `commit`. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: yes tests/contract-score.test.js (edit 4 adds the red-first checks guard-usage-extra-args and guard-longer-closing-fence-leaves-block-open; edit 1 turns the first one green; the second already passes because the guard fails safe)
blast-radius: bin/contract-guard.js:65, bin/contract-guard.js:7, tests/contract-score.test.js:297, tests/contract-score.test.js:289
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 2's payload is the lines to add after the anchor line; its first line is `//`.
note: edit 3 pins the source commit 5720c5b on purpose: the fixture must not move when blc-4 later edits the live plan. It keeps both contracts the existing check needs (hdc-1 lead, hdc-6 scribe) and nothing else.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blc-8)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 5720c5b; grep-derived, not graph-derived).
commit-message: fix(blc-8): contract guard rejects extra arguments; fence rule documented; plan-files check reads a fixture (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blc-8 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

