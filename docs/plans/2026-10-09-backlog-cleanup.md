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
`agents/scribe.md`; plus `.claude-plugin/plugin.json` and `package.json`
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
  criteria see it."
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
- AC5.5 run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1; echo exit=$?`; exit 0; stdout `exit=0` (AC-P2/AC-P3 pins kept); mutation: drop `- **Contract precedence.**` from lead-programmer.md, prints `exit=1`.
- AC5.6 run: `for f in .claude/agents/task-master.md .claude/agents/scribe.md .claude/agents/lead-programmer.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -oE "fix rounds included, carries|Every fix commit's subject carries" | wc -l; done | tr '\n' ' '`; exit 0; stdout `1 1 1 `; mutation: skip `--update`, prints `0 0 0 `.
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
- 6.2 `templates/protocol-digest.md`: header line 4 "Keep this under ~15 lines - if it grows," becomes "Keep the body under 15 non-empty lines (tested) - if it grows,"; everything after the header comment becomes exactly
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
