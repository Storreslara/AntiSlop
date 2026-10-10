# Reviewer-note cleanups after blf-1..8 (2026-10-09)

Status: FINAL (spec-master, 2026-10-09, tip 475f7c8, version 0.31.153). Unit prefix `rnf`
(`rnc` is taken: commits 218b7d2..fcfcc47). Fast path (3 units): the nine-element dispatch
contracts are below and the orchestrator dispatches from this file. Hook scripts
(`hooks/scripts/*`), `hooks/scripts/marker-write.sh` and every blc-h* item are human-only and
out of scope.

## Goal

Close the reviewer notes left by `docs/plans/2026-10-09-backlog-followups.md` (blf-1..8, all
PASS) that the request names:

- G1 (item 1). `agents/orchestrator.md` no longer tells a reviewer dispatch to put
  `Implementer tier: <t>` second without qualification. A verdict-owning reviewer dispatch
  carries it as its second non-blank line. An advisory dispatch keeps `Mode: advisory` second,
  the position `hooks/scripts/lib/reviewer-route-gate-core.sh:100-108` reads, and moves the tier
  line to third. Prose only.
- G2 (item 2). `templates/persona-protocol.md:354` and `agents/reviewer.md:224` say
  "FAIL-block count". Both mean the record's block count.
- G3 (item 3). `templates/persona-protocol.md` and `templates/protocol-digest.md` define
  ladder exhaustion with the "any later FAIL after a human-directed re-dispatch" case, as
  `agents/orchestrator.md:363` does. The digest stays within its 15-line budget.
- G4 (item 4). `agents/task-master.md` **Range criteria** defines `<end>`.
- G5 (item 5). A test registered in `tests/validate.sh` fails when one of the four adapter ports
  drops the FAIL block tier clause.
- G6 (item 6). The `CONTEXT.md` **FAIL block** entry names the `tier:` second line.
  `docs/harness-glossary.md` has no FAIL block entry (F9), so it is not edited.

## Context

### Sources and note dispositions

`bash bin/marker-audit.sh . --notes --surface=<path>` could not be run: `reviewed-path-gate.sh`
blocks a spec-master Bash command that names that directory. The eight `blf-*.pass` markers
were read whole with Read instead, which covers more than the sweep would. No `blf-*.fail` or
`rnf-*` marker exists. No rnf unit re-scopes a unit that failed. The sweep is best-effort: the
reviewed directory is gitignored per-clone state, so an empty result proves nothing.

Every `NOTE[spec]` on a surface this plan touches, and its disposition:

| Note | Disposition |
|---|---|
| blf-8 n1: rule 3's line-2 sentence conflicts with `Mode: advisory` | rnf-1 edits 1-3 (G1) |
| blf-8 n2: the sentence sits in rule 3 (gated agents only); no test pins the line-2 shape | placement: rnf-1 edits 1-2 move it to **Review routing**. Test: deferred (it would exercise the hook; the request is prose only) |
| blf-8 n3 (code): "the `model`" vs a tier name; no rule for a dispatch without `model` | rnf-1 edit 2 (`<t>` is a tier name; the line is omitted without a `model`) |
| blf-7 n3 (code): no test pins the port tier clause | rnf-2 (G5) |
| blf-7 n4, blf-6 n5: CONTEXT.md FAIL block lacks `tier:` | rnf-3 item 1 (G6) |
| blf-7 n5: `marker-write.sh` emits no tier line | out of scope (human-only) |
| blf-7 n6: ports omit "copied from ... / ladder never reads it" | deferred: the gap is fidelity only, and the request does not name it |
| blf-6 n4, blf-3 n5: "FAIL count" at persona-protocol.md:354, reviewer.md:224 | rnf-1 edits 4 and 7 (G2). The same wording in the two reviewer ports goes to rnf-2 edits 3-4 (D3) |
| blf-6 n6: reject-route FAIL write always gets `tier: unknown` | no change; consistent with the fallback |
| blf-6 n7, blf-3 n4, blf-1 n5: `tr '\n' ' '` leaves a trailing space | this plan's list criteria use `paste -sd' ' -` |
| blf-3 n6 (code): template and digest lack the ladder clause | rnf-1 edits 5-6 (G3) |
| blf-2 n4: `<end>` lost its definition | rnf-1 edit 8 (G4) |
| blf-2 n6 (code): no test pins the Range criteria prose | deferred (not requested) |
| blf-4 n3: **fix round** and **fix turns** do not link | deferred (not requested) |
| blf-4 n4: "fix attempt" (an `_Avoid_` term) in the **FAIL record** entry | rnf-3 item 2, which the note assigned to this amendment. `docs/harness-glossary.md:868` is left as is (that file is outside CONTEXT.md's _Avoid_ scope) |
| blf-1 n3/n4, blf-5 n4-n7 (code: guard and rubric test robustness) | deferred (not requested) |

### Measured facts (2026-10-09, HEAD 475f7c8, version 0.31.153)

- F1. `agents/orchestrator.md:115-116` (Dispatch hygiene rule 3): "A reviewer dispatch's second
  line is `Implementer tier: <t>`: the `model` the unit's latest implementer dispatch ran on."
  Lines 160-163 (Review routing) say an advisory dispatch puts `Mode: advisory` as the literal
  second non-blank line. `reviewer-route-gate-core.sh:100-108` takes the second non-blank line
  and matches only `^Mode:[[:space:]]+advisory`. Rule 3 covers dispatches to a gated agent,
  and the reviewer is not one.
- F2. `agents/reviewer.md:216-219` and `templates/persona-protocol.md:350-352` read the tier by
  its label (`the dispatch's Implementer tier: value`), not by line position, so a tier line in
  third position is still read. When the line is missing the reviewer writes `unknown`. No test
  pins the orchestrator sentence (`git grep "Implementer tier" -- tests` is empty).
- F3. "FAIL count" appears once in `templates/persona-protocol.md` (354) and once in
  `agents/reviewer.md` (224). After flattening line breaks the two files hold 2 matches. It
  also appears in `adapters/codex/agents/reviewer.toml:88` and
  `adapters/cursor/agents/reviewer.md:85` ("or the FAIL count inflates"). In all four places
  it means the record's block count. `CONTEXT.md:385-386` keeps "FAIL count" only for the
  in-session advisory count. No test pins any of these phrases.
- F4. `templates/persona-protocol.md:710-712`: "normally the second FAIL on its top tier)". The
  later-FAIL case is missing. `templates/protocol-digest.md:14-16` has no example list at all.
  `tests/protocol-doc-drift.test.js:85-91` caps the digest body at 15 non-empty lines, and it
  has exactly 15 today, so the clause must fit in the bullet's existing three lines.
  `templates/persona-protocol-slim.md` has no ladder sentence, and no adapter port carries one.
- F5. `agents/task-master.md:211-214` uses `<end>..HEAD` in the untagged-tail criterion. blf-2
  (5b88378) removed the sentence that bound the end to the unit's last commit. The list it
  defines is newest-first, so `head -1` is the last commit. Every blf contract computes
  `U=$(echo "$L" | head -1)`.
- F6. All four ports carry `then a second line \`tier: <haiku|sonnet|opus|unknown>\`
  (\`unknown\` when the dispatch names no implementer tier)` once after flattening whitespace.
  `tests/adapter-protocol-parity.test.js:103,125` probe only the FAIL record heading.
  `node bin/cli.js --update` does not manage any of the four ports (its 68-line report names
  none of them).
- F7. The replay of all three units (scratch worktree of 475f7c8, in order rnf-1, rnf-2, rnf-3)
  showed the following. `node bin/cli.js --update` changes 14 `.claude` paths. Afterwards
  `--update --dry-run` reports 0 non-current entries, and still 0 after rnf-2 and rnf-3. These
  tests stay green: protocol-doc-drift, writer-tier-consistency, protocol-cross-references,
  adapter-protocol-parity, adapter-skill-parity, contract-examples, context-glossary-links,
  cli-backfill, ubiquitous-language and marker-verify. Every criterion below gave its stated
  result after the edits and its red result at HEAD. The digest-budget mutation (16 lines)
  makes protocol-doc-drift exit 1.
- F8. `.claude/constitution.md` v1.1.0. P3 applies to `agents/*.md` and `templates/*` only.
  The ports, `tests/`, `CONTEXT.md` and `CHANGELOG.md` are not stamped.
- F9. `CONTEXT.md:876` **FAIL record** and `:885` **FAIL block** are the only FAIL block
  entries. `docs/harness-glossary.md` has none: its only FAIL heading is **FAIL routing
  (post-reviewer)** at line 1716.

### Decisions

- D1 (item 1). The line-order rule moves out of rule 3 into **Review routing**, which already
  holds the first-line and `Mode: advisory` rules. Rule 3 keeps one pointer sentence. Order:
  `Unit:` first. Then `Implementer tier: <t>` for a verdict-owning dispatch, or `Mode: advisory`
  followed by `Implementer tier: <t>` for an advisory one. `<t>` is the tier name (`haiku`,
  `sonnet`, `opus`) of the latest implementer dispatch's `model`. The line is omitted when that
  dispatch passed no `model`, so the reviewer's `unknown` fallback (F2) applies. No hook,
  reviewer or protocol text changes for this item.
- D2 (items 1-4 merged). One stamped unit, rnf-1, holds every `agents/*.md` and `templates/*`
  edit. It takes one version (0.31.154), does one `--update` run and gets one review. The four
  items share the version files, `CHANGELOG.md` and the `.claude/` mirrors, so as separate
  units they would run serially anyway; splitting them buys no parallelism. Items 2 and 3 also
  share `templates/persona-protocol.md`. Open Question 2 covers the three-unit alternative.
- D3 (item 2 extension). The two reviewer ports carry the same "FAIL count inflates" phrase
  (F3). They are hand-maintained, unstamped copies of `agents/reviewer.md:224`, so the change
  rides in rnf-2. rnf-2 already owns the ports' FAIL-record text through its pin test.
- D4 (item 3). Persona-protocol: append the orchestrator's clause verbatim inside the
  parenthesis. Digest: rewrap the bullet in three lines, using `>=` for "reaching or
  exceeding" and dropping "full" and "to the user" phrasing (the new text says "shows the user
  the defect history"). Open Question 3 covers the alternative of raising the budget.
- D5 (item 4). `<end>` is the unit's last commit, the list's `head -1`.
- D6 (item 5). New file `tests/adapter-fail-tier-pin.test.js`, registered in
  `tests/validate.sh` after the blf-5 block. It flattens whitespace and requires both halves of
  the clause in each port. Its mutation proofs run in a `git worktree add --detach` copy.
- D7 (item 6). The tier line goes into **FAIL block** in the template's words. In **FAIL
  record**, "every fix attempt" becomes "every failed attempt": a block exists for every FAIL
  verdict, the first attempt included, so **fix round** would be wrong there.
- D8. rnf-2 and rnf-3 bump nothing, add no CHANGELOG entry and never run `--update`. The
  three units are file-disjoint. Commit subjects end `(#529)`, the umbrella the blf stages
  reused (closed). scribe closes no issue.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-09 Functional scope & success criteria: Q The two reviewer ports say "FAIL count
  inflates" too; is that in scope? → A (self-resolved): yes, in rnf-2 (D3); same defect as
  item 2 in hand-maintained copies.
- 2026-10-09 Functional scope & success criteria: Q Does item 6 also edit
  docs/harness-glossary.md? → A (self-resolved): no, it has no FAIL block entry (F9).
- 2026-10-09 User interaction flow: Q In an advisory reviewer dispatch, where does the tier
  line go: third, or omitted? → A (self-resolved): third (D1); recorded as Open Question 1.
- 2026-10-09 Edge cases / failure handling: Q What does the orchestrator write when the
  implementer dispatch passed no `model`? → A (self-resolved): it omits the line, and the
  reviewer writes `tier: unknown` (D1, F2).
- 2026-10-09 Edge cases / failure handling: Q The digest is at its 15-line budget; how does
  the clause fit? → A (self-resolved): rewrap in three lines (D4); recorded as Open Question 3.
- 2026-10-09 Technical constraints & tradeoffs: Q Three serial stamped units or one? → A
  (self-resolved): one, rnf-1 (D2); recorded as Open Question 2.
- 2026-10-09 Terminology consistency: Q Is "FAIL count" at the two named sites the record's
  count? → A (self-resolved): yes at both, and at the two port sites (F3).
- 2026-10-09 Terminology consistency: Q Should the **FAIL record** entry's "fix attempt" (an
  _Avoid_ term) become "fix round"? → A (self-resolved): no, "failed attempt" (D7).

## Risks / dependencies

- R1. rnf-1 rewrites `.claude/` through `--update`. Do not run it at the same time as any
  other unit that runs `--update`. rnf-2 and rnf-3 do not run it.
- R2. The digest wording is constrained by the 15-line test. If a later edit grows the bullet
  to four lines, protocol-doc-drift fails. That is intended.
- R3. While rnf-1 is in flight, an advisory reviewer dispatch built from the old rule-3 text
  would get a real review-join stamp (blf-8 n1). Do not dispatch an advisory reviewer until
  rnf-1 has PASSed.
- R4. Prior FAIL history on these surfaces (replay units below) is all `vacuous`/`host`
  criteria, and none of it is a blf or rnf unit. Every criterion here was run red at HEAD and
  green after the replay (F7). The Implementer-tier ratchet does not apply.
- R5. `tests/validate.sh` (P5) takes about 11 minutes and is not a unit criterion. The
  orchestrator runs it once after each unit merges, as in blf.
- R6. Concurrent agent-memory writes: clean-tree criteria exclude `.claude/agent-memory`.
- Deferred / out of scope: hook scripts, `marker-write.sh`, blc-h*. Also the notes marked
  deferred in the table above, and a test pinning the reviewer dispatch line order.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. F1-F9 were measured at 475f7c8, and the three units
  were replayed with every criterion run (F7).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors come from
  `node bin/cli.js --update` only.
- P3 "Version-stamp discipline": satisfied. rnf-1 bumps 0.31.153 → 0.31.154 with a CHANGELOG
  entry in the same commit, and its criterion 14 checks every commit of the unit. rnf-2 and
  rnf-3 touch no stamped path, and rnf-2 criterion 9 checks that.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The tier line stays optional,
  with the `unknown` fallback.
- P5 "`tests/validate.sh` is the merge gate": satisfied. rnf-2 registers its test, and R5
  assigns the run.

## Steps

### Unit table

| Unit | Items | Persona | Content files | Version | Depends on | Group |
|---|---|---|---|---|---|---|
| rnf-1 | 1, 2, 3, 4 | lead-programmer | `agents/orchestrator.md`, `agents/reviewer.md`, `agents/task-master.md`, `templates/persona-protocol.md`, `templates/protocol-digest.md` (+ version files, `CHANGELOG.md`, `.claude/` mirrors) | 0.31.154 | none | S (sole stamped unit) |
| rnf-2 | 5 (+ D3) | lead-programmer | `tests/adapter-fail-tier-pin.test.js` (new), `tests/validate.sh`, `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` | none | none | P |
| rnf-3 | 6 | scribe | `CONTEXT.md` | none | none | P |

The three file sets are disjoint, and no unit reads a file another one writes in a way its
criteria depend on. Exception: rnf-1's untagged-tail criterion covers only rnf-1's own files.
All three may be dispatched at once in separate worktrees. rnf-1 must still be the only
`--update` run in flight (R1). Under the one-unit-at-a-time review invariant, reviews still go
one at a time.

### Step 1 (rnf-1): items 1-4

Edits 1-3 `agents/orchestrator.md` (D1); 4-5 `templates/persona-protocol.md` (G2, G3); 6
`templates/protocol-digest.md` (D4); 7 `agents/reviewer.md` (G2); 8 `agents/task-master.md`
(D5); 9-11 version and CHANGELOG; then `--update`. Criteria: contract below (21 items).

### Step 2 (rnf-2): adapter tier pin test

New test (D6), validate.sh registration, two port wording edits (D3). Criteria: contract below
(14 items).

### Step 3 (rnf-3): glossary

**FAIL block** gains the tier line and **FAIL record** loses "fix attempt" (D7). Criteria:
contract below (11 items).

## Open Questions

1. (From CHK4.) Advisory reviewer dispatch: is the `Implementer tier:` line put third (the
   default the plan is written to), or omitted? An advisory dispatch writes no marker, so the
   line is unused there, but keeping it means every reviewer dispatch carries it. Choosing
   "omit" changes only rnf-1 edit 3's `after:` text and criterion 3's phrase.
2. (From CHK6.) Stamped work as one unit rnf-1 (default) or three serial units (orchestrator
   0.31.154; persona-protocol + digest + reviewer 0.31.155; task-master 0.31.156)? The split
   isolates a FAIL to one item but costs two more bumps, `--update` runs and reviews.
3. (From CHK8.) Digest: accept the three-line rewrap with `>=` and shorter closing words (the
   default), or raise the budget to 16 lines in `tests/protocol-doc-drift.test.js`? The test
   comment says to mechanize instead of growing the digest, so the default respects it.

## Self-check

- CHK1: Do Goal G1 and rnf-1 edits 1-3 agree on where the tier line goes in both dispatch
  kinds? — PASS (D1; criteria 1-3).
- CHK2: Is the value of `<t>` defined for an implementer dispatch without `model`? — FAIL
  (missing) — revised in place (edit 2 says to omit the line; F2 gives the reviewer fallback).
- CHK3: Does any rnf-1 edit touch a hook script or the gate's parsing? — PASS (Do NOT touch
  lists `hooks/`; criterion 20 fixes the file list).
- CHK4: Is the advisory tier-line choice a user decision the plan cannot settle? — FAIL
  (missing) — converted to Open Question 1.
- CHK5: Do G2 and F3 agree on how many "FAIL count" sites exist? — FAIL (conflicting: the
  request names two, and F3 found four) — revised in place (D3 puts the port pair in rnf-2;
  rnf-1 criterion 6 and rnf-2 criterion 7 cover them).
- CHK6: Does the unit table's version column agree with D2 and the constitution check? — PASS
  (one stamped unit, 0.31.154). The split alternative is a user decision — FAIL (missing) —
  converted to Open Question 2.
- CHK7: Is the digest's 15-line budget checked by a criterion? — PASS (rnf-1 criterion 9,
  mutation measured in F7).
- CHK8: Does the digest wording keep the glossary term "reaching or exceeding"? — FAIL
  (conflicting: D4 writes `>=`) — converted to Open Question 3.
- CHK9: Is `<end>` defined in the same terms the blf contracts compute? — PASS (F5, D5).
- CHK10: Does rnf-2's test fail when a port drops either half of the clause? — PASS
  (criteria 3 and 4 are worktree mutations, one per half, measured).
- CHK11: Does item 6's scope agree with F9 (no harness-glossary entry)? — PASS.
- CHK12: Does every list criterion avoid the trailing-space mismatch the blf notes flagged?
  — PASS (`paste -sd' ' -`).
- CHK13 (P3): Does the one stamped unit carry a per-commit version-stamp criterion, and do
  the unstamped units prove they stay unstamped? — PASS (rnf-1 c14; rnf-2 c9; rnf-3 c10
  file list).
- CHK14 (P5): Is the new test registered in validate.sh, and is a validate.sh run assigned?
  — PASS (rnf-2 c5-c6; R5).
- CHK15 (replay; gh310, gh348-14, gh429, gh307 vacuous; `agents/orchestrator.md`): do rnf-1
  criteria 1-4 still fail under their own `mutation:` lines? — PASS (each prints `0` at HEAD,
  measured; criterion 2 prints `1` at HEAD).
- CHK16 (replay; mw-step1/2/3, gh348-3, memdirt-1 vacuous; `agents/reviewer.md`,
  `templates/persona-protocol.md`, `adapters/cursor/agents/reviewer.md`): do rnf-1 criteria
  5-7 and rnf-2 criterion 7 still fail under their own `mutation:` lines? — PASS (HEAD values
  0, 2, 0 and 0, measured).
- CHK17 (replay; gh-303, gh339, gh354, gh409, spec2-unitA/B, human-review-cleanup-1 vacuous;
  `CONTEXT.md`): do rnf-3 criteria 1-3 still fail under their own `mutation:` lines? — PASS
  (`0`, `0`, `fix attempt` at HEAD).
- CHK18 (replay; gh317, gh320, gh346-2, gh413, rollout-map-1 vacuous; `tests/validate.sh`):
  does rnf-2 criterion 5 still fail under its own `mutation:` line? — PASS (`0` at HEAD).
- CHK19 (replay; gh288-1, gh313, gh360, item17-3, reviewer-changes-examples-lean-2 and others
  vacuous; `CHANGELOG.md`, version files): do rnf-1 criteria 12-15 still fail under their own
  `mutation:` lines? — PASS (`0`, `0`, `no-unit-commit`, `version-sync: mismatch` at HEAD).
- CHK20 (replay; gh385-2, gh426, ci-fetch-depth-cleanup, item17-4, mw-step5 host): does any
  `run:` use a host path other than `mktemp` and `/usr/bin/grep`? — PASS (the scorer's R4
  row is true for rnf-1 and rnf-2; a grep of rnf-3's `run:` lines for `/tmp/`, `/home/`,
  `~/` and `$HOME` finds none).

Ubiquitous-language prose check (advisory, against CONTEXT.md). Lens 1: the request's "FAIL
count" at the two named sites is the record's count, so it is renamed to the canonical
**FAIL-block count**. Lens 2: "fix attempt" in **FAIL record** is the _Avoid_ synonym of
**fix round**, but it means "failed attempt" there (D7). Lens 3: "advisory dispatch" (a
reviewer dispatch whose second line is `Mode: advisory`) has no entry. It differs from
**advisory verdict** and **advisory-reviewer axis**. Scribe may add it (hint below).

## Scribe update hint

After rnf-1 PASS, amend the `CONTEXT.md` **Reviewer dispatch opening line** entry with the line
order: `Unit:` first; then `Implementer tier: <t>`, or `Mode: advisory` then the tier line. Also
consider an **advisory dispatch** entry that cross-links **advisory verdict** and
**advisory-reviewer axis**. Close no issue: there is no per-unit tracker issue, and #529 is
the closed umbrella.

## Handoff

Fast path: 3 units, so the contracts are emitted directly below and `task-master` is not
involved. Retrieval contract: this file. The Open Questions have defaults, and the plan is
dispatchable as written.

---

# Dispatch contracts (fast path; this file is the retrieval contract)

## Retrieval contract

No per-unit issue exists. The retrieval contract for every unit is this file,
`docs/plans/2026-10-09-reviewer-note-cleanups.md`, under `## Unit rnf-<n>`: read the unit's
`~~~~~~~markdown` block, whose first line is `Unit: rnf-<n>`. The orchestrator's guard reads it
with `node bin/contract-guard.js docs/plans/2026-10-09-reviewer-note-cleanups.md --unit=rnf-<n>`
(add `--shape=scribe` for rnf-3). The contract outranks the plan prose above. A conflict is a
spec gap: STOP.

## Dispatch table

| unit | persona | shape | content files | version | parallel/serial | guard |
|---|---|---|---|---|---|---|
| rnf-1 | lead-programmer | lead, stamped | 5 agent/template files + version files, `CHANGELOG.md`, 14 `.claude` mirrors | 0.31.154 | the only stamped unit; the only `--update` in flight | 7/7 |
| rnf-2 | lead-programmer | lead | `tests/adapter-fail-tier-pin.test.js`, `tests/validate.sh`, 2 reviewer ports | none | parallel (worktree) | 7/7 |
| rnf-3 | scribe | scribe | `CONTEXT.md` | none | parallel (worktree) | 7/7 |

**Dispatchable now: all three.** Reviews go one at a time. Dispatch no advisory reviewer
before rnf-1 PASS (R3).

## Rulings

(spec-master adds one line per resolved gap, starting `- <ruling-id>:`.)

## Unit rnf-1

~~~~~~~markdown
Unit: rnf-1

## Objective
`agents/orchestrator.md` moves the reviewer-dispatch tier-line rule out of Dispatch hygiene rule 3 into **Review routing**. A verdict-owning reviewer dispatch has `Implementer tier: <t>` as its second non-blank line. An advisory one keeps `Mode: advisory` second and moves the tier line to third. `<t>` is a tier name, and the line is omitted when the implementer dispatch passed no `model`. `templates/persona-protocol.md` and `agents/reviewer.md` say "FAIL-block count" where the record's count is meant. `templates/persona-protocol.md` and `templates/protocol-digest.md` add the ladder-exhaustion case "any later FAIL after a human-directed re-dispatch", and the digest stays within 15 lines. `agents/task-master.md` defines `<end>`. Version 0.31.154; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-reviewer-note-cleanups.md`, `## Unit rnf-1`. No per-unit issue exists. Umbrella (closed): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchors: line matching `A reviewer dispatch's second line is`, line matching `gated dispatch — not merely somewhere in the body.` and line matching `dispatch up front: add `)
- `templates/persona-protocol.md` (anchors: line matching `one, so the FAIL count is readable across sessions.` and line matching `tier) stops re-dispatch: the orchestrator (or team lead) then`)
- `templates/protocol-digest.md` (anchor: line matching `- 2 FAILs per implementer tier move the unit up the Escalation ladder; only`)
- `agents/reviewer.md` (anchor: line matching `or the FAIL count inflates. If a`)
- `agents/task-master.md` (anchor: line matching `  `exit: 1`, `stdout: 0`. A red-set criterion over`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.153",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `A reviewer dispatch's second line is`
   indent: 3
   before:
```
   ≤64 chars. A reviewer dispatch's second line is `Implementer tier: <t>`: the
   `model` the unit's latest implementer dispatch ran on.
```
   after:
```
   ≤64 chars. **Review routing** below sets a reviewer dispatch's later lines.
```
2. file: `agents/orchestrator.md`
   anchor: line matching `gated dispatch — not merely somewhere in the body.`
   indent: 0
   before:
```
gated dispatch — not merely somewhere in the body.
```
   after:
```
gated dispatch — not merely somewhere in the body. Unless the dispatch is
advisory (below), its second non-blank line is `Implementer tier: <t>`, where
`<t>` is the tier (`haiku`, `sonnet` or `opus`) of the `model` the unit's latest
implementer dispatch ran on; omit the line when that dispatch passed no `model`
(the reviewer then writes `tier: unknown`).
```
3. file: `agents/orchestrator.md`
   anchor: line matching `dispatch up front: add `
   indent: 0
   before:
```
dispatch up front: add `Mode: advisory` as the **literal second non-blank
line**, immediately after `Unit: <id>`. `reviewer-route-gate.sh` recognizes
```
   after:
```
dispatch up front: add `Mode: advisory` as the **literal second non-blank
line**, immediately after `Unit: <id>`, and move the `Implementer tier:` line
to third. `reviewer-route-gate.sh` recognizes
```
4. file: `templates/persona-protocol.md`
   anchor: line matching `one, so the FAIL count is readable across sessions.`
   indent: 0
   before:
```
one, so the FAIL count is readable across sessions. This is a
```
   after:
```
one, so the FAIL-block count is readable across sessions. This is a
```
5. file: `templates/persona-protocol.md`
   anchor: line matching `tier) stops re-dispatch: the orchestrator (or team lead) then`
   indent: 0
   before:
```
reaching or exceeding the ladder's length: normally the second FAIL on its top
tier) stops re-dispatch: the orchestrator (or team lead) then
```
   after:
```
reaching or exceeding the ladder's length: normally the second FAIL on its top
tier, or any later FAIL after a human-directed re-dispatch) stops re-dispatch:
the orchestrator (or team lead) then
```
6. file: `templates/protocol-digest.md`
   anchor: line matching `- 2 FAILs per implementer tier move the unit up the Escalation ladder; only`
   indent: 0
   before:
```
- 2 FAILs per implementer tier move the unit up the Escalation ladder; only
  ladder exhaustion (FAIL-block count reaching or exceeding the ladder's length)
  stops re-delegation and surfaces the full defect history to the user.
```
   after:
```
- 2 FAILs per implementer tier climb the Escalation ladder; ladder exhaustion
  (FAIL-block count >= its length, or any later FAIL after a human-directed
  re-dispatch) alone stops re-delegation and shows the user the defect history.
```
7. file: `agents/reviewer.md`
   anchor: line matching `or the FAIL count inflates. If a`
   indent: 2
   before:
```
  to have succeeded must not repeat it, or the FAIL count inflates. If a
```
   after:
```
  to have succeeded must not repeat it, or the FAIL-block count inflates. If a
```
8. file: `agents/task-master.md`
   anchor: line matching `  `exit: 1`, `stdout: 0`. A red-set criterion over`
   indent: 2
   before:
```
  `exit: 1`, `stdout: 0`. A red-set criterion over
```
   after:
```
  `exit: 1`, `stdout: 0`, where `<end>` is the unit's last commit (the list's
  `head -1`). A red-set criterion over
```
9. file: `.claude-plugin/plugin.json` (version 0.31.154)
   anchor: line matching `"version": "0.31.153",`
   before: `  "version": "0.31.153",`
   after: `  "version": "0.31.154",`
10. file: `package.json` (version 0.31.154)
   anchor: line matching `"version": "0.31.153",`
   before: `  "version": "0.31.153",`
   after: `  "version": "0.31.154",`
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Reviewer-note cleanups after blf-1..8 (rnf-1, 0.31.154).** `agents/orchestrator.md`: the `Implementer tier: <t>` rule moves from Dispatch hygiene rule 3 to **Review routing**; a verdict-owning reviewer dispatch carries it as its second non-blank line, an advisory one keeps `Mode: advisory` second (the position `reviewer-route-gate.sh` reads) and moves the tier line to third; `<t>` is a tier name, and the line is omitted when the implementer dispatch passed no `model`. `templates/persona-protocol.md` and `agents/reviewer.md` say FAIL-block count where the record's count is meant. `templates/persona-protocol.md` and `templates/protocol-digest.md` add the ladder-exhaustion case of any later FAIL after a human-directed re-dispatch, as `agents/orchestrator.md` has it. `agents/task-master.md` **Range criteria** defines `<end>` as the unit's last commit. Mirrors refreshed by `node bin/cli.js --update`.
```
12. command: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1 && node tests/writer-tier-consistency.test.js > /dev/null 2>&1 && node tests/protocol-cross-references.test.js > /dev/null 2>&1 && node tests/adapter-protocol-parity.test.js > /dev/null 2>&1 && node tests/contract-examples.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
13. command: `node bin/cli.js --update`
   expect: 0
14. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
15. command: `git add agents/orchestrator.md agents/reviewer.md agents/task-master.md templates/persona-protocol.md templates/protocol-digest.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(rnf-1): reviewer-note cleanups after blf-1..8 (0.31.154) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
16. command: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `hooks/scripts/lib/reviewer-route-gate-core.sh`, `hooks/scripts/marker-write.sh` and every other file under `hooks/` (human-only; this unit is prose only)
- `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` and the other adapter ports (unit rnf-2 owns their wording)
- `CONTEXT.md` (unit rnf-3) and `docs/harness-glossary.md`
- `tests/protocol-doc-drift.test.js` (the 15-line digest budget stays; edit 6 fits it)
- `commands/start-feature-team.md` (agent-teams dispatch is unchanged; the `unknown` fallback covers it)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cE 'advisory \(below\), its second non-blank line is .Implementer tier: <t>.'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`, exit 1. It prints `0` at HEAD.
2. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cF "A reviewer dispatch's second line is"`
   exit: 1
   stdout: `0`
   mutation: skip edit 1; the unqualified sentence stays and it prints `1`, exit 0. It prints `1` at HEAD.
3. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cE 'immediately after .Unit: <id>., and move the .Implementer tier:. line to third'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; it prints `0`, exit 1.
4. run: `tr '\n' ' ' < .claude/agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cE 'immediately after .Unit: <id>., and move the .Implementer tier:. line to third'`
   exit: 0
   stdout: `1`
   mutation: skip edit 13 (`node bin/cli.js --update`); the mirror keeps the old words and it prints `0`, exit 1.
5. run: `cat templates/persona-protocol.md agents/reviewer.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -oE 'so the FAIL-block count is readable across sessions|or the FAIL-block count inflates' | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip edit 4 or edit 7; it prints `1`. It prints `0` at HEAD.
6. run: `cat templates/persona-protocol.md agents/reviewer.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -o 'FAIL count' | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 4; it prints `1`. It prints `2` at HEAD.
7. run: `tr '\n' ' ' < templates/persona-protocol.md | tr -s ' ' | /usr/bin/grep -cF 'normally the second FAIL on its top tier, or any later FAIL after a human-directed re-dispatch) stops re-dispatch'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; it prints `0`, exit 1.
8. run: `tr '\n' ' ' < templates/protocol-digest.md | tr -s ' ' | /usr/bin/grep -cF '(FAIL-block count >= its length, or any later FAIL after a human-directed re-dispatch) alone stops re-delegation'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; it prints `0`, exit 1.
9. run: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: wrap edit 6's bullet onto four lines; the digest body has 16 non-empty lines and it prints `exit=1` (measured). It already passes at HEAD and must stay green.
10. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -cE "where .<end>. is the unit's last commit \(the list's .head -1.\)"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; it prints `0`, exit 1.
11. run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1 && node tests/protocol-cross-references.test.js > /dev/null 2>&1 && node tests/adapter-protocol-parity.test.js > /dev/null 2>&1 && node tests/contract-examples.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: a claim check that the prose edits leave these tests green; it already passes at HEAD and must stay green. proof: `node tests/adapter-protocol-parity.test.js` prints `OK   negative case: an absent-phrase present in the port is REJECTED`, so the suite can fail.
12. run: `cat .claude-plugin/plugin.json package.json | /usr/bin/grep -c '"version": "0.31.154"'`
   exit: 0
   stdout: `2`
   mutation: skip edit 9 or 10; it prints `1`.
13. run: `/usr/bin/grep -cF '(rnf-1, 0.31.154)' CHANGELOG.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; it prints `0`, exit 1.
14. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | /usr/bin/grep -vc '^version-stamp-check: ok touched: yes '`
   exit: 1
   stdout: `0`
   mutation: skip edit 9; the line reads `violation` and it prints `1`, exit 0 (the script exits 0 on a violation, so this gates on stdout).
15. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.154';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 10; it prints `version-sync: mismatch`, exit 1.
16. run: `node bin/cli.js --update --dry-run 2>&1 | /usr/bin/grep -E '^  ' | /usr/bin/grep -vc ': already current$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 13; the mirrors are non-current and it prints a count above `0`, exit 0 (a stale scratch copy printed `2`). It prints `0` at HEAD and must stay `0`.
17. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(rnf-1\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
18. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
19. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- agents/orchestrator.md agents/reviewer.md agents/task-master.md templates/persona-protocol.md templates/protocol-digest.md | /usr/bin/grep -vcE '^[a-z]+\(rnf-1\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
20. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -v '^\.claude/' | LC_ALL=C sort -u | paste -sd' ' -`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md agents/reviewer.md agents/task-master.md package.json templates/persona-protocol.md templates/protocol-digest.md`
   mutation: touch one extra file (for example a hook script) in the unit's commit; the list gains that path.
21. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.153`. Anything else: STOP; the orchestrator re-derives the version as HEAD version + 1 and rewrites this contract's version lines before dispatch.
precondition: `git log --format='%H %s' | /usr/bin/grep -cE '^[0-9a-f]+ [a-z]+\(rnf-1\): '` prints `0`, the tree is clean, and no other unit that runs `node bin/cli.js --update` is in flight. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file (measured at 475f7c8: all print `1`). On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edits of agent and template files (criteria 1, 3, 5, 7, 8 and 10 count phrases absent at HEAD; criterion 9 runs the existing digest-budget test)
blast-radius: agents/orchestrator.md:115, agents/orchestrator.md:149, agents/orchestrator.md:160, templates/persona-protocol.md:354, templates/persona-protocol.md:711, templates/protocol-digest.md:14, agents/reviewer.md:224, agents/task-master.md:214, hooks/scripts/lib/reviewer-route-gate-core.sh:100, tests/protocol-doc-drift.test.js:85
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 1's payload keeps the three leading spaces and the unicode `≤`; edit 2's keeps the unicode em dash. Edit 11's payload begins with one empty line, which is part of the text, and its entry is ONE line.
note: edit 6 must stay three lines: the digest body is at its 15-line budget (`tests/protocol-doc-drift.test.js:85-91`).
note: the gate reads the second non-blank line for `Mode: advisory` only; a verdict-owning dispatch whose second line is the tier line is stamped normally. No hook changes.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(rnf-1)` as its subject scope.
explorer: not needed (provenance: grep and read by spec-master at 475f7c8, and a full replay in a scratch worktree; grep-derived, not graph-derived).
commit-message: feat(rnf-1): reviewer-note cleanups after blf-1..8 (0.31.154) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: rnf-1 (#529)
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
criterion 21: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit rnf-2

~~~~~~~markdown
Unit: rnf-2

## Objective
A new test `tests/adapter-fail-tier-pin.test.js`, registered in `tests/validate.sh`, fails when any of the four adapter ports (`adapters/codex/agents/reviewer.toml`, `adapters/codex/agents-md-fragment.md`, `adapters/cursor/agents/reviewer.md`, `adapters/cursor/rules/persona-protocol.mdc`) drops either half of the FAIL block tier clause. The two reviewer ports say "FAIL-block count inflates" instead of "FAIL count inflates". No version bump (no `agents/*.md` or `templates/*` file changes).

## Retrieval
Plan file: `docs/plans/2026-10-09-reviewer-note-cleanups.md`, `## Unit rnf-2`. No per-unit issue exists. Umbrella (closed): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/adapter-fail-tier-pin.test.js` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `  echo "FAIL tests/rubric-doc-parity.test.js"`)
- `adapters/codex/agents/reviewer.toml` (anchor: line matching `or the FAIL count inflates.`)
- `adapters/cursor/agents/reviewer.md` (anchor: line matching `or the FAIL count inflates.`)

## Ordered edits
1. file: `tests/adapter-fail-tier-pin.test.js`
   anchor: new file (create it with exactly this content)
   indent: 0
   insert-after:
```
#!/usr/bin/env node
'use strict';

// Adapter FAIL-block tier pin (rnf-2): each hand-maintained adapter port that
// describes the reviewer's FAIL record says a block's second line is the `tier:`
// line, with `unknown` when the dispatch names no implementer tier. Whitespace is
// flattened first, so rewrapping a port does not break the check.

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const PORTS = [
  'adapters/codex/agents/reviewer.toml',
  'adapters/codex/agents-md-fragment.md',
  'adapters/cursor/agents/reviewer.md',
  'adapters/cursor/rules/persona-protocol.mdc',
];
const PHRASES = [
  'then a second line `tier: <haiku|sonnet|opus|unknown>`',
  '(`unknown` when the dispatch names no implementer tier)',
];

let failures = 0;
for (const rel of PORTS) {
  const flat = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');
  for (const phrase of PHRASES) {
    if (flat.includes(phrase)) {
      console.log(`OK   ${rel}: ${phrase}`);
    } else {
      console.log(`FAIL ${rel}: missing ${phrase}`);
      failures++;
    }
  }
}

console.log(failures === 0
  ? 'All adapter-fail-tier-pin checks passed.'
  : `${failures} adapter-fail-tier-pin check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
```
2. file: `tests/validate.sh`
   anchor: line matching `  echo "FAIL tests/rubric-doc-parity.test.js"`
   indent: 0
   before:
```
  echo "FAIL tests/rubric-doc-parity.test.js"
  fail=1
fi
```
   after:
```
  echo "FAIL tests/rubric-doc-parity.test.js"
  fail=1
fi

echo
echo "== adapter ports pin the FAIL block tier line (Node, rnf-2) =="
if node tests/adapter-fail-tier-pin.test.js; then
  echo "OK   tests/adapter-fail-tier-pin.test.js"
else
  echo "FAIL tests/adapter-fail-tier-pin.test.js"
  fail=1
fi
```
3. file: `adapters/codex/agents/reviewer.toml`
   anchor: line matching `or the FAIL count inflates.`
   indent: 2
   before:
```
  blank line. Do this exactly once per verdict, or the FAIL count inflates.
```
   after:
```
  blank line. Do this exactly once per verdict, or the FAIL-block count inflates.
```
4. file: `adapters/cursor/agents/reviewer.md`
   anchor: line matching `or the FAIL count inflates.`
   indent: 2
   before:
```
  blank line. Do this exactly once per verdict, or the FAIL count inflates.
```
   after:
```
  blank line. Do this exactly once per verdict, or the FAIL-block count inflates.
```
5. command: `node tests/adapter-fail-tier-pin.test.js > /dev/null 2>&1 && node tests/adapter-protocol-parity.test.js > /dev/null 2>&1 && node tests/adapter-skill-parity.test.js > /dev/null 2>&1 && bash -n tests/validate.sh; echo exit=$?`
   expect: 0
   stdout: `exit=0`
6. command: `git add tests/adapter-fail-tier-pin.test.js tests/validate.sh adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md && git commit -m "test(rnf-2): adapter ports pin the FAIL block tier line; FAIL-block count wording (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `adapters/codex/agents-md-fragment.md` and `adapters/cursor/rules/persona-protocol.mdc` (the test reads them; they already carry the clause)
- `agents/` and `templates/` (unit rnf-1 owns the Claude surfaces; this unit changes no stamped file: no version bump, no CHANGELOG entry, no `node bin/cli.js --update`)
- `tests/adapter-protocol-parity.test.js` and `tests/fail-marker-format-parity.test.sh` (unchanged; the new test is separate)
- `hooks/scripts/marker-write.sh` and every other file under `hooks/` (human-only)
- `.claude/` (no mirror applies to the ports or tests)

## Acceptance criteria
1. run: `node tests/adapter-fail-tier-pin.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 1; the file is missing and it prints `exit=1` (measured at HEAD).
2. run: `node tests/adapter-fail-tier-pin.test.js | /usr/bin/grep -c '^OK '`
   exit: 0
   stdout: `8`
   mutation: remove one entry from `PORTS`; it prints `6`.
3. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/then a second$/then a 2nd/' "$D/adapters/cursor/agents/reviewer.md"; node "$D/tests/adapter-fail-tier-pin.test.js" 2>&1 | /usr/bin/grep -c '^FAIL adapters/cursor/agents/reviewer.md: missing then a second line'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; the scratch copy has no test and it prints `0` (measured at HEAD). The scratch copy is the only file changed; the checked-out tree stays clean.
4. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/^implementer tier), followed by the$/implementer tiers), followed by the/' "$D/adapters/codex/agents-md-fragment.md"; node "$D/tests/adapter-fail-tier-pin.test.js" 2>&1 | /usr/bin/grep -c '^FAIL adapters/codex/agents-md-fragment.md: missing (.unknown. when'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1, or drop the second entry of `PHRASES`; it prints `0`. This proves the second half of the clause is checked.
5. run: `/usr/bin/grep -c 'node tests/adapter-fail-tier-pin.test.js' tests/validate.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`, exit 1.
6. run: `bash -n tests/validate.sh && echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: delete the `fi` line of the new block; bash reports a syntax error and prints nothing, exit 2. It already passes at HEAD and must stay green.
7. run: `cat adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -o 'or the FAIL-block count inflates' | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip edit 3 or edit 4; it prints `1`. It prints `0` at HEAD.
8. run: `node tests/adapter-protocol-parity.test.js > /dev/null 2>&1 && node tests/adapter-skill-parity.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: a claim check that the port wording change leaves the parity tests green; it already passes at HEAD and must stay green. proof: `node tests/adapter-protocol-parity.test.js` prints `OK   negative case: an absent-phrase present in the port is REJECTED`, so the test can fail.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -cE '^(agents|templates|\.claude-plugin|\.claude)/|^package\.json$|^CHANGELOG\.md$'`
   exit: 1
   stdout: `0`
   mutation: touch `agents/reviewer.md` in a unit commit; it prints `1` and exits 0.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(rnf-2\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
12. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- tests/adapter-fail-tier-pin.test.js tests/validate.sh adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md | /usr/bin/grep -vcE '^[a-z]+\(rnf-2\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | paste -sd' ' -`
   exit: 0
   stdout: `adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md tests/adapter-fail-tier-pin.test.js tests/validate.sh`
   mutation: touch one extra file in the unit's commit; the list gains that path.
14. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `git log --format='%H %s' | /usr/bin/grep -cE '^[0-9a-f]+ [a-z]+\(rnf-2\): '` prints `0`, `test -e tests/adapter-fail-tier-pin.test.js && echo exists` prints nothing, and the tree is clean. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:` other than `new file`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file (measured at 475f7c8: all print `1`). On any mismatch STOP and report; do not adapt the text.
tdd: yes tests/adapter-fail-tier-pin.test.js (the new test is the deliverable; it passes at HEAD's ports, so criteria 3 and 4 are its red proofs in a scratch copy)
blast-radius: adapters/codex/agents/reviewer.toml:84, adapters/codex/agents/reviewer.toml:88, adapters/cursor/agents/reviewer.md:81, adapters/cursor/agents/reviewer.md:85, adapters/cursor/rules/persona-protocol.mdc:130, adapters/codex/agents-md-fragment.md:123, tests/validate.sh:1229
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 2's `before:` lines are the end of the blf-5 block; the new block follows them after one empty line, and the existing empty line and `echo` that follow stay.
note: this unit may run in a worktree in parallel with units rnf-1 and rnf-3 (file-disjoint); it bumps nothing. `node bin/cli.js --update` does not manage the ports (measured), so rnf-1's `--update` cannot overwrite edits 3 and 4.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(rnf-2)` as its subject scope.
explorer: not needed (provenance: grep and read by spec-master at 475f7c8, and a full replay in a scratch worktree; grep-derived, not graph-derived).
commit-message: test(rnf-2): adapter ports pin the FAIL block tier line; FAIL-block count wording (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: rnf-2 (#529)
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
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit rnf-3

~~~~~~~markdown
Unit: rnf-3

## Objective
The `CONTEXT.md` **FAIL block** entry says a block's second line is `tier: <haiku|sonnet|opus|unknown>`, the tier the failed attempt ran on. The line is copied from the reviewer dispatch's `Implementer tier:` line, and the Escalation ladder never reads it. The **FAIL record** entry says "every failed attempt" instead of the _Avoid_ term "fix attempt". No other entry changes.

## Retrieval
Plan file: `docs/plans/2026-10-09-reviewer-note-cleanups.md`, `## Unit rnf-3`. No per-unit issue exists. Umbrella (closed): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Each item replaces a substring inside the entry named by `heading:`. The `before:` text is that substring, with no leading or trailing spaces, so the line's own leading spaces stay. `text:` replaces exactly that substring. In item 1 the `text:` spans four lines, and its lines after the first carry their own two leading spaces.
1. file: `CONTEXT.md`
   heading: `**FAIL block**:`
   before:
```
followed by the defect list verbatim, then a blank separator line.
```
   text:
```
second line `tier: <haiku|sonnet|opus|unknown>`, the tier the failed attempt
  ran on (copied from the reviewer dispatch's `Implementer tier:` line; the
  [[Escalation ladder]] never reads it), followed by the defect list verbatim,
  then a blank separator line.
```
2. file: `CONTEXT.md`
   heading: `**FAIL record**:`
   before:
```
every fix attempt, not a single
```
   text:
```
every failed attempt, not a single
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the closed umbrella and no per-unit issue exists: close nothing, and never close #529
- task-id: rnf-3
- marker first line: "PASS rnf-3 "
- commit: one commit of `CONTEXT.md` (plus one per fix round after a FAIL), made with `git add CONTEXT.md && git commit -m "docs(rnf-3): FAIL block entry names the tier line (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"` (a fix round on another tier names that tier's model). Every commit of this unit carries `(rnf-3)` as its subject scope.
- precondition: `git log --format='%H %s' | /usr/bin/grep -cE '^[0-9a-f]+ [a-z]+\(rnf-3\): '` prints `0`; the tree is clean; each `before:` substring appears in `CONTEXT.md` exactly once (`/usr/bin/grep -cF -- '<before text>' CONTEXT.md` prints `1`); the headings `**FAIL block**:` and `**FAIL record**:` each appear exactly once at the start of a line (measured at 475f7c8: all `1`). Anything else: STOP.
- if a glossary test rejects the new text, STOP and report the failing check verbatim; do not reshape the entries. If a message scan blocks `-m`, commit with `git commit -F <file>`; never rephrase to dodge a gate.
- this unit may run in a worktree in parallel with rnf-1 and rnf-2 (file-disjoint); it bumps nothing.
- the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.

## Do NOT touch
- every other entry of `CONTEXT.md` (in particular **FAIL-block count**, **fix round**, **ladder exhaustion** and **Reviewer dispatch opening line**; the scribe hint for the last one waits for rnf-1 PASS)
- `docs/harness-glossary.md` (it has no FAIL block entry; its "fix attempt" at line 868 stays)
- `docs/adr/`, `agents/`, `templates/`, `tests/`, `adapters/`, `.claude/`

## Acceptance criteria
1. run: `awk '/^\*\*FAIL block\*\*:$/,/^$/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -cE 'timestamp>., second line .tier: <haiku[|]sonnet[|]opus[|]unknown>., the tier the failed attempt ran on'`
   exit: 0
   stdout: `1`
   mutation: skip item 1; it prints `0`, exit 1. It prints `0` at HEAD.
2. run: `awk '/^\*\*FAIL block\*\*:$/,/^$/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -cF '[[Escalation ladder]] never reads it), followed by the defect list verbatim'`
   exit: 0
   stdout: `1`
   mutation: skip item 1, or drop its link brackets; it prints `0`, exit 1.
3. run: `awk '/^\*\*FAIL record\*\*:$/,/^$/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -o 'fix attempt\|every failed attempt' | paste -sd' ' -`
   exit: 0
   stdout: `every failed attempt`
   mutation: skip item 2; it prints `fix attempt` (measured at HEAD).
4. run: `node tests/context-glossary-links.test.js 2>&1 | tail -n 1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: misspell `[[Escalation ladder]]` in item 1 as `[[Escalation ladders]]`; the link check names it as dangling and the last line changes. It already passes at HEAD and must stay green.
5. run: `node tests/ubiquitous-language.test.js 2>&1 | /usr/bin/grep -c 'passes all 4 structural/distinguishability checks'`
   exit: 0
   stdout: `1`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero and prints `0`. It already passes at HEAD and must stay green.
6. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show -U0 --format= "$c" -- CONTEXT.md | /usr/bin/grep -c '^@@'; done | paste -sd' ' -`
   exit: 0
   stdout: `2`
   mutation: also edit another entry; the count rises above `2`. Skip item 2; it falls to `1`. With one unit commit the output is that one count.
7. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(rnf-3\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- CONTEXT.md | /usr/bin/grep -vcE '^[a-z]+\(rnf-3\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches `CONTEXT.md` with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | paste -sd' ' -`
   exit: 0
   stdout: `CONTEXT.md`
   mutation: touch one extra file in the unit's commit; the list gains that path.
11. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap; do not improvise.
~~~~~~~
