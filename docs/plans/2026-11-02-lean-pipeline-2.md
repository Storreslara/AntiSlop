# Lean pipeline 2: A/B items 2, 4, 5, 6, 8 and the open follow-ups (2026-11-02)

Slug `2026-11-02-lean-pipeline-2`, unit prefix `l2-`. Appendix:
`docs/plans/2026-11-02-lean-pipeline-2/appendix.md`.

## Goal

User request (2026-11-01, authoritative): "close out follow ups and items 2, 4, 5, 6 and 8". The items are
the Q4 rows of the 2026-10-31 A/B waste investigation. The follow-ups are the open PASS notes and tidy items
of the lean-pipeline and reviewer-by-lane plans. After this plan:
- G1 (item 2). The reviewer has no `experimental.cacheTtl: 1h`.
- G2 (item 4). The deployed reviewer and lead-programmer bodies carry only the protocol sections their own
  text needs. The reviewer preloads one skill instead of two. No behavioural rule is lost (D3 table).
- G3 (item 5). In a small repo the medium lane skips the explorer, decided by a script.
- G4 (item 6). The reviewer of a medium or full unit reads the gating mode and constitution presence from
  its dispatch header, gets the blast radius from the precheck it runs, and runs the full suite once. It
  still runs the precheck and every deferred criterion itself.
- G5 (item 8). e03 and e05 accept `CONTEXT.md`, and a run whose only stall cause is a permission denial
  scores `run_pass` true when every required check passes. Unit l2-h4 drops the H4 size warning.
- G6. The follow-ups that are still open and need no new design are closed (units 9-15), and stop-gate
  hardening (a)-(c) lands (units 10a, 10b). The rest are under Risks. The work ships as 0.34.0.

## Decisions

- **D1 Item 2 evidence (measured from `eval/abtest/.runs/*_B_*/stream.jsonl`).** Each subagent's first API
  call: the lead-programmer (5m TTL) read the same 20,347-token prefix on 19 of 19 repeat dispatches in a
  run (gaps 190-363 s), so 5m hits a prefix reused within minutes. The reviewer (1h) read a 23,800-token
  prefix on 37 of 43 dispatches; 18 were in-run repeats (gaps 169-312 s) that 5m would also hit. But 19 of
  its 25 first-in-run dispatches hit an entry written by the previous run's reviewer, 14 of them more than
  300 s later (up to 1,642 s); 5m loses those. Net saving about $10.1 - 14 x 23.8K x $12.25/MTok ($4.1) =
  $6.0 over 25 runs (about 4.7% of Arm B, not 8%). The cross-run hits come from back-to-back eval runs.
  The 12K persona tail missed 43 of 43 times under 1h too. Decision: drop it. Only pin:
  `tests/validate.sh:277-290`. Adapters carry none. The 2.1.248 floor and its stated reasons stay (Risks).
- **D2 Item 4, the least risky cut.** Keep both personas on the full protocol tier (the slim tier lacks
  marker format, FAIL record and dispatch contract) and drop whole sections from their rows of
  `PROTOCOL_SECTIONS_BY_PERSONA` in `bin/cli.js`. `assertNoDanglingCrossReferences` and
  `assertProtocolMatrixComplete` run at load, so a dropped section that a kept one names makes
  `bin/cli.js` unloadable. `gatedAgents` still force-includes WIP sentinel and Pending-review flag for
  lead-programmer. The reviewer's `antislop:ubiquitous-language` becomes on-demand (its output is advisory
  only, `agents/reviewer.md:167-172`). Lead-programmer keeps both preloads: `antislop:tdd` and
  `antislop:coding-discipline` are "follow" rules for every edit (`agents/lead-programmer.md:54-67`), and
  an on-demand load depends on the model invoking it. Prior FAIL: `lp-slim` (2026-10-31, sonnet)
  left contradictory reviewer prose, so l2-slim gets opus and a no-contradiction criterion.
- **D3 Section table (evidence from each persona's own text; bytes from `templates/persona-protocol.md`).**

| section (bytes) | lead-programmer | reviewer |
|---|---|---|
| Structural questions (2,532) | **drop**: no Agent tool; body :83-85 states its exception, :33-35 the doubted-claim rule | keep: spawns explorer (:42, :265) |
| Answer shape (355), Scope Bash (953), Terminal status (1,778) | keep | keep |
| Agent-teams mode (541) | keep: teammate SendMessage (:102-104) | keep: SendMessage tool |
| Teammate Write/Edit fallback (1,772) | keep: writes files | **drop**: no Write/Edit tool, no `memory:`; marker writes are Bash (:208, :296); its one Bash-relevant rule (rewording a command to dodge a scan is a bypass) moves into the body's gate bullet (:330-342) |
| WIP sentinel (986) | keep (gated) | dropped already |
| Blocked by a gate (1,903) | keep | keep: named at :334 |
| Running criteria (1,266), Machine-checkable (352), Dispatch contract (749), Review ownership (1,345) | keep | keep |
| Retrieval contract (266) | keep (:16) | dropped already |
| Review markers (4,475), FAIL record (1,414) | dropped already | keep: writes markers |
| Pending-review flag (2,021) | kept by `gatedAgents` force-include | **drop**: orchestrator-facing; the flag clearing it relies on is restated in kept Review markers |
| Third verdict, Microworld bundles | dropped already | dropped already |
| Continuing after a FAIL (1,929) | **drop**: addressed to the re-delegator and the cap owner; LP's FAIL rule is body :118-119, fix turns :43-50, memory :17-24 and :41-42 | dropped already |
| A note on `memory` (1,257) | keep (`memory: project`) | dropped already |

  Deployed: lead-programmer 29,325 → about 24,900 bytes; reviewer 45,799 → about 42,100, and 3,500 less
  preloaded.
- **D4 Item 5.** New `unit-bookkeeping.sh repo` prints `repo: small files=<n> lines=<n>` when the tracked
  files outside `.claude/` and `docs/plans/` number 10 or fewer or hold fewer than 1,000 lines, else
  `repo: large ...`; anything it cannot measure is `large`. The orchestrator skips the explorer in the
  medium lane only on `repo: small`. The byte cap is met by the cuts in unit 6.
- **D5 Item 6.** The review header gains `Review gating: <enforce|off>` (the reviewer's own jq rule) and
  `Constitution: <present|absent>`, after `Reviewer model:`. A wrong header is harmless: an `off` that is
  false only withholds markers, which the gates then miss (fail closed). `review-precheck.sh
  --blast-radius` appends `blast-radius.sh`'s output with each line prefixed `br `; `check` never passes
  it, so its packet parse does not change. The reviewer counts that as its blast-radius run, and a deferred
  criterion that runs the test command as its one full-suite run. Adapters have no header or precheck and
  do not change.
- **D6 Item 8.** `run_pass` is decided in `eval/abtest/lib/make-row.py:74`, not in `stream.py` or
  `score.py`. When the summary is `stalled-human` with `permission_denials` > 0, `ask_user_attempts` 0
  and `escalated_markers` 0, and every required check passed, the row says `completion_status: complete`
  and `run_pass: true`; the denial count stays in the row. `stream.py` and `score.py` do not change.
  e02_B_4 (1 denial, all checks pass) becomes a pass; e05_B_1 (1 denial, a check failed) stays a fail.
  `tests/abtest-arms.test.sh` pins none of this and is not touched. Old rows are not edited: every row
  carries `harness_commit` = HEAD, so the next run of `run-matrix.sh` moves them to
  `results.superseded.jsonl` itself.
- **D7 Follow-ups.** Each was verified open at 127e22b1 and maps to units 5, 9-15 (the fixed ones are in
  the appendix). The reviewer-by-lane plan's D5 wording is amended there by this commit.
- **D8 Lanes and order.** Lanes are `unit-size.sh`'s output. l2-ckhard edits `check` itself
  (prior FAILs qw-u1, rv-harden2): dispatch it with `--at-least medium` so it gets the reviewer. Every
  unit that edits `bin/unit-bookkeeping.sh` or `bin/review-precheck.sh` starts at sonnet (qw-u1, st-u2
  were haiku FAILs). Each unit leaves the system working: tooling lands before the prose that uses it
  (3, 4 before 5; 3 before 6), and a new header line or flag is ignored by readers that predate it.
- **D9 Contracts.** Affected files are full repo-relative paths with no `:NN` suffix or brace form (the
  precheck mis-reads both until unit 12). Content units add one `[Unreleased]` CHANGELOG bullet and bump
  no version (P3). Mirrors change only through `node bin/cli.js --update --force-render`.
- **D10 Not built.** The `ABTEST_POLICY=shipped` matrix is a recommendation only (Recommendations).

## Units

Tier is a hint (`ladder-tier.sh` decides). Files are hand-edited files, CHANGELOG included; generated
mirrors are extra. Each unit's last criterion is `bash tests/validate.sh` once after its final commit.

| # | id | files | lane | tier | depends on |
|---|---|---|---|---|---|
| 1 | l2-ttl | 3 | full | sonnet | - |
| 2 | l2-slim | 5 | full | opus (highest risk) | 1 |
| 3 | l2-bkhdr | 3 | small | sonnet | - |
| 4 | l2-prebr | 3 | small | sonnet | - |
| 5 | l2-revprose | 4 | full | sonnet | 2, 3, 4 |
| 6 | l2-orch | 4 | full | sonnet | 3 |
| 7 | l2-abfix | 7 | medium | sonnet | - |
| 8 | l2-h4 | 3 | full | haiku | - |
| 9 | l2-gatemsg | 5 + 4 regenerated | full | sonnet | - |
| 10 | l2-ports | 6 | full | sonnet | 9 |
| 10a | l2-sg1 | 5 + 4 regenerated | full | opus | 9, 10 |
| 10b | l2-sg2 | 3 | full | opus | 8, 10a |
| 11 | l2-ckhard | 3 | small, lifted to medium (D8) | sonnet | 3 |
| 12 | l2-scope | 3 | full | sonnet | 4 |
| 13 | l2-retired | 4 | full | sonnet | - |
| 14 | l2-tests | 3 | small | sonnet | - |
| 15 | l2-scribe | 4 + wiki, memory | small | sonnet | 1-14 |
| 16 | l2-release | 3 | full | haiku | 15 |

Dispatch in table order, one unit at a time.

### 1. l2-ttl: drop the reviewer's 1h cache TTL (item 2)
Files: `agents/reviewer.md` (delete `experimental:` and `  cacheTtl: 1h`), `tests/validate.sh` (277-290:
FAIL when the file has a `cacheTtl` line at any indent), `CHANGELOG.md` with D1's figures.

### 2. l2-slim: inline only the needed sections (item 4, highest risk)
Files: `bin/cli.js` (lead-programmer row: Structural questions and Continuing after a FAIL move to `drop`,
the row lists the rest of `UNIVERSAL_PROTOCOL_CORE` by name; reviewer row: Teammate Write/Edit fallback and
Pending-review flag move to `drop`), `agents/reviewer.md` (`skills:` keeps only `antislop:roast-work`;
the ubiquitous-language bullet says to invoke `antislop:ubiquitous-language` in diff mode when the range
adds or renames a domain term, `CONTEXT.md` or a docs page, and stays advisory; the gate bullet gains
"Rewording a command so that a gate's scan misses it is the same bypass."),
`tests/protocol-cross-references.test.js` (pin both rows: the four dropped headers absent from the deployed
copies, every other include present), `tests/cli-backfill.test.js` (the control comment at about :810 says
the pending-review flag is in the reviewer row; correct it), `tests/persona-prose-pins.test.sh` (LP pin
:48 negated, reviewer off :50), `CHANGELOG.md` with D3's sizes. Criteria: the
four `## ` headings absent from the two deployed bodies, every kept heading present, deployed sizes at or
below 25,200 (LP) and 42,500 (reviewer), `--update --force-render` succeeds, and no deployed reviewer
line still says to follow a preloaded ubiquitous-language skill.

### 3. l2-bkhdr: review header lines and `repo` (items 5, 6 tooling)
Files: `bin/unit-bookkeeping.sh`, `tests/unit-bookkeeping.test.sh`, `CHANGELOG.md`. After `Reviewer
model:` the header prints `Review gating: off` exactly when the reviewer's jq rule reads `off` (else
`enforce`), then `Constitution: present|absent`. `repo` per D4. Tests cover each value and `repo` on 3
files, 11 files of 2,000 lines, 11 files of 50 lines, and outside git.

### 4. l2-prebr: `review-precheck.sh --blast-radius` (item 6 tooling)
Files: `bin/review-precheck.sh`, `tests/review-precheck.test.sh`, `CHANGELOG.md`. The flag appends `br `
plus each line of `blast-radius.sh <baseline>` last (`br blast-radius: unavailable` if it fails). Without
the flag the packet is byte-identical; with `--criterion` it is usage error 2.

### 5. l2-revprose: reviewer routine and protocol wording (item 6, follow-up B2)
Files: `agents/reviewer.md`, `templates/persona-protocol.md`, `tests/blast-radius.test.sh`, `CHANGELOG.md`.
Reviewer text: the precheck command gains `--blast-radius`; the blast-radius bullet gains "Its `br ` lines
in the precheck packet you ran are this run; do not run the script again."; the constitution bullet gains
"The dispatch header's `Constitution:` line answers whether it exists."; the gating bullet reads the
header's `Review gating:` line first and the jq command only when the line is absent; the run-the-checks
bullet gains "A deferred criterion that runs the full suite, run with `--criterion <n>`, is that one run."
and "Do not inspect `.claude/bin`, `.claude/hooks` or `.claude/persona-config.json` for what the header
states." Protocol: after the pinned blast-radius sentence add "Its `review-precheck.sh --blast-radius` run
counts."; the escape-hatch text says `flag defer <reason>` puts `defer: <reason>` on the first line of a
flag that currently exists and keeps the rest (no "overwrite"); the small-lane exception reads "a pending-
review flag left by its writer's stop, a `fail`, an `escalate` or no `check:` line moves the unit to
`medium`, so it gets the reviewer". The existing (j) pins stay; new pins for each added sentence.

### 6. l2-orch: small-repo explorer skip (item 5)
Files: `agents/orchestrator.md`, `docs/orchestrator-rationale.md`, `tests/unit-size.test.sh`,
`CHANGELOG.md`. Exact text (old → new):
- medium bullet, after "one lead-programmer per step.": add " If `bash .claude/bin/unit-bookkeeping.sh
  repo` prints `repo: small`, no explorer either, as in small (N21)."
- "for its dispatch with no contract," → "for its dispatch with no contract and no `repo: small`," (the
  pinned "outside the small lane (see "Lane routing"), spawn `explorer` first" stays).
- "their tests and, outside the small lane, the explorer's blast radius." → "their tests and, when the
  explorer ran, its blast radius."
- "(N1-N20)" → "(N1-N21)".
Cuts (unpinned per `git grep -nF` over `tests/`, `scripts/`): delete " Every re-dispatch carries the
defect history or the fix contract." and " You have no Write/Edit tool: every file change goes to the
lead-programmer." (stated elsewhere); both move verbatim to N21.
Rationale gains N21: the A/B figures (10 explorer dispatches on 460-line repos, $0.60 and 33 s each) and
D4's thresholds. Pin `(l2-o1)` the new sentence in both copies. Source at most 16,384 bytes, deployed at
most 40,960.

### 7. l2-abfix: A/B fixture and scoring (item 8)
Files: `eval/abtest/fixtures/e03-rename-query/allowed-paths.txt`,
`eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt` (each gains the line `CONTEXT.md`),
`eval/abtest/lib/make-row.py` (D6), `eval/abtest/README.md` (the sentence at :107 that any denial
scores a row `stalled-human` gains D6's exception), `tests/abtest-row.test.sh`,
`tests/fixtures/abtest/row/summary-denied.json`, `CHANGELOG.md`; follow-up: `eval/abtest/lib/stream.py`,
`tests/abtest-stream.test.sh` (emits `is_error`, `exit_code`; overrides D6's stream.py clause). Tests: denial-only plus all checks →
`[True, 'complete']`; denial-only plus one failed check → `[False, 'stalled-human']`; denial plus an ask
→ stalled; the existing "a stall fails the run with every check passing" case is unchanged.
`eval/abtest/results.jsonl`, `results.superseded.jsonl`, `eval/reports/` and `tests/abtest-arms.test.sh`
are not touched.

### 8. l2-h4: drop the H4 size warning (literal item 8)
Files: `hooks/scripts/dispatch-hygiene.sh` (delete the `prompt_bytes -gt 3072` warning and its header
comment line; H1's `maxPromptBytes`, default 30,000, still bounds prompts), `tests/dispatch-hygiene.test.sh`
(T49c: a 3,073-byte five-field prompt exits 0 with no `H4` on stderr and no `warned=H4-size`),
`CHANGELOG.md`. This also ends the hook-versus-protocol "3072" mismatch (follow-up 8h): the protocol's
"A contract is at most 3072 bytes" is a contract rule for spec-master and stays.

### 9. l2-gatemsg: stop-gate message, join tests, route-mark mode (B1, B3, B4)
Files: `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/lib/reviewer-route-gate-core.sh`,
`tests/stop-gate.test.sh`, `tests/reviewer-route-gate-caller.test.sh`, `CHANGELOG.md`; adapter cores
regenerated. The unrecognized-namespace message (:48) names `bash ${dot_label}/bin/unit-bookkeeping.sh
flag defer|skip <reason>` when `${dot}/bin/unit-bookkeeping.sh` exists, else keeps today's text (as rule 3
does). The route core runs `chmod 644 "$tmp"` before `mv`, so a marked flag keeps mode 644. Tests:
`(l2-g1)`/`(l2-g2)` the message with and without the script; `(l2-g3)` an earlier record with another
tool_use_id and `lane=small` and the writer's own record `lane=medium` → flag written; `(l2-g4)` two
records with the writer's id, `medium` first and `small` second → flag written; `(l2-g5)` a `.claude`
made unwritable (`chmod 555`, skipped when run as root) → the flag stays plain and the main Stop blocks;
`(l2-g6)` a marked flag has mode 644.

### 10. l2-ports: port-side lane guard and dead extraction (B4, follow-up 5)
Files: `adapters/codex/hooks/scripts/stop-gate.sh`, `adapters/cursor/hooks/scripts/stop-gate.sh` (each
sets `writer_lane=""` just before sourcing the core, so an exported variable is ignored),
`adapters/codex/hooks/scripts/reviewer-route-gate.sh`, `adapters/cursor/hooks/scripts/reviewer-route-gate.sh`
(delete the unused `prompt="$(...)"` line, :60), `tests/adapter-stop-gate-parity.test.sh` (`(l2-p1)` per
port: with `writer_lane=small` exported, a gated writer stop still writes the flag), `CHANGELOG.md`.

### 10a. l2-sg1: stop-gate hardening (a) and (c), fail closed
Files: `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/lib/state-access.sh`, `tests/stop-gate.test.sh`,
`tests/state-access-constraints.test.sh`, `CHANGELOG.md`; adapter copies regenerated. (a) On a gated
SubagentStop the D6 marker check runs before the WIP sentinel. On a trip the sentinel is deleted, not
honoured, and logged `<ts> wip-ignored d6-trip agent=<id>` to `wip-audit.log`; rule 6 then writes the flag
and blocks. Untripped, the sentinel works as today. (c) New `state_replace_pending_review` writes the flag
through a `mktemp` file in the dot-dir, `chmod 644`, `mv -f`, so an existing file or symlink at the flag
path is replaced, never kept or followed; rule 6 uses it. If that fails, it `rm -f`s the path and creates
the file; if that fails too, the stop blocks naming the path. `state_write_pending_review` and its
CONSTRAINT 3 test stay. Adversarial tests: `(l2-s1)` forged `.pass` newer than the stamp plus a non-empty
sentinel → rc 2, flag present, sentinel gone, log line; `(l2-s2)` sentinel alone → rc 0, no flag; `(l2-s3)`
a pre-made `skip: x` flag → replaced, and the main Stop blocks; `(l2-s4)` the flag path a symlink to an
outside file → target unchanged, flag a regular file, mode 644; `(l2-s5)` an untripped small-lane stop
still writes none; `(l2-s6)` the reviewer's stop still clears every flag.

### 10b. l2-sg2: writer-dispatch stamp only on an allowed dispatch (b)
Files: `hooks/scripts/dispatch-hygiene.sh`, `tests/dispatch-hygiene.test.sh`, `CHANGELOG.md`. Today
`dispatch-hygiene.sh:177-179` touches the stamp before any check, so a blocked dispatch moves it later and
a marker forged earlier stops tripping D6. The gated-target match now only sets a variable; an `EXIT`
trap touches the stamp when the hook exits 0 (mode off, override, warn, no check fired), never on exit 2
or a crash (a stale stamp trips more, fail closed). Adversarial tests: `(l2-d1)` a gated dispatch blocked
by H4 leaves the stamp's mtime unchanged; `(l2-d2)` an allowed one touches it; `(l2-d3)` mode off and an
override each touch it; `(l2-d4)` a forged marker, then a blocked dispatch, then the writer's stop →
`stop-gate.sh` rc 2; `(l2-d5)` a non-gated target never touches it. After l2-h4 (same file).

### 11. l2-ckhard: two `check` gaps (rv-harden2 notes)
Files: `bin/unit-bookkeeping.sh`, `tests/unit-bookkeeping.test.sh`, `CHANGELOG.md`. In `check_declared`, a
contract path with a `..` segment escalates `criteria-mismatch` before any read (the precheck folds `..`
lexically; a symlinked directory makes the two reads differ). In `check_tree`, after C2a, `git ls-files
-v` printing any line whose tag is lowercase or `S` (assume-unchanged or skip-worktree) escalates
`index-flags`. Both fail toward the reviewer. Tests `(l2-k1)`, `(l2-k2)` (each flag), and a clean repo
still passes. Dispatch with `unit-size.sh l2-ckhard --at-least medium` (D8).

### 12. l2-scope: `:NN` and brace entries in scope lists
Files: `hooks/scripts/lib/unit-scope.sh`, `tests/review-precheck.test.sh`, `CHANGELOG.md`; the `.claude`
copy regenerated. `us_entries` strips one trailing `:<digits>` or `:<digits>-<digits>` from an entry and
expands one non-nested `{a,b,...}` group into one entry per member; any other brace form stays literal
(it matches nothing, so the path is `scope: out`, fail closed). Affects `review-precheck.sh`,
`unit-size.sh` (more entries can only raise a lane) and `writer-scope-gate.sh` (the listed paths are the
ones the author meant). Tests: `` `bin/x.sh:48` `` and `` `hooks/{a,b}.sh` `` in a contract give `scope: ok`
for those files; `` `a/{b,{c,d}}.sh` `` gives `scope: out`.

### 13. l2-retired: trust row 20 and the escalated-marker refusal
Files: `hooks/scripts/reviewed-path-gate.sh`, `docs/trust-model.md`, `tests/reviewed-path-gate.test.sh`,
`CHANGELOG.md`. The :95 refusal no longer names the DECISION channel: it says the `.escalated` marker is
left from a version before 0.32.0, nothing resolves it any more, and a human deletes it at their own
terminal. Row 20 says `human-decision-gate.sh` is a stub since 0.32.0 (ADR-0044) that allows every call,
registered only for A/B harness parity. A test pins the new refusal and that it has no "DECISION".

### 14. l2-tests: test tidy
Files: `tests/marker-write.test.sh` (check markers with `hooks/scripts/task-gate.sh`'s own
`marker_valid`, extracted by `sed -n '/^marker_valid() {/,/^}/p'` and sourced, instead of the local copy;
the "staying BLOCKED above" comment says the gates allow Bash since 0.32.0),
`tests/escalation-retired.test.sh` (check (d) reads the whole `BIN_HELPER_FILES` array, `const` line to
`];`), `CHANGELOG.md` ("the comment sections (case 25)" → "the two comment sections (both case 25)").

### 15. l2-scribe: knowledge text
Files: `CONTEXT.md` ("Arm A / Arm B": the Bash gate relaxation is a no-op since 0.32.0; the DECISION
channel and DECISION file entries at about :1068-1321 marked retired in 0.32.0), `docs/harness-glossary.md`
("reviewed-path denial": its Bash branch is gone; new entries **A/B harness parity**, **writer-dispatch
stamp**, **marker check**, **fix-of**, **Output caps**, **plan appendix**, **small repo**),
`docs/adr/0020-write-edit-content-not-scanned.md` and
`docs/adr/0025-textual-gate-protection-requires-structural-triggers.md` (a "Superseded in part by ADR-0044"
status note each), `.claude/wiki/architecture.md` (the escalation text at about :73-94 marked retired), and
the agent-memory notes that name `benign-command.sh`, `command_skeleton` or `mentions_marker_dir` (7 files,
`git grep -l` over `.claude/agent-memory`): one line each saying the file or function was deleted in 0.32.0.

### 16. l2-release: 0.34.0
Files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, and `--update` re-stamps. One commit,
0.33.0 → 0.34.0, `## [0.34.0] - <date>` below `## [Unreleased]`.

## Risks

- **Item 4 can change behaviour.** The table rests on each persona's own text; a teammate reviewer never
  had Write/Edit either.
- **Item 2.** A reviewer resumed over 5 minutes after INSUFFICIENT-CONTEXT re-writes about 50K tokens
  ($0.6); the corpus had none. `plugin.json` and the install skill still name `cacheTtl` as a floor reason.
- **l2-scope widens the scope gate's listed set** to what authors meant; a brace list naming a sensitive
  path makes the unit heavier, never lighter.
- **Follow-up:** `scripts/token-usage/{agg,agg2,cache}.py` key the reviewer on two preloaded skills; after
  l2-slim a reviewer transcript (roast-work only) counts as `other`.
- **l2-ckhard** escalates every small unit in a sparse checkout (skip-worktree bits); fails closed.
- **Accepted residual (user, 2026-11-01):** a writer can `rm` its own flag before its stop; the stop
  rewrites it (unit 10a), but not when the writer's Bash removes it after its last stop.
- **Left, no decision needed:** the `Mode: advisory` convention has no mechanical reader (pinned by
  `tests/reviewer-dispatch-line-order.test.js`); the views lost with `decisions.js` (plan excerpt
  browser, milestone-auditor paste-back, defer/skip composer); `agents/spec-master.md:190-211` still shows
  `## Self-check` in the plan template.

## Recommendations (not built)

- After 0.34.0, re-run `eval/abtest/run-matrix.sh --policy uniform`; the runner supersedes every old row.
  Then run `--policy shipped` into the same results file as a second matrix: subagent spend is 73% of Arm
  B and the shipped ladder (haiku/sonnet writers, sonnet/opus reviewer) is what users run. Report the two
  policies separately; `score.py` already splits by policy.

## Open Questions

None open. The user answered on 2026-11-01: (1) do both units 7 and 8; (2) `eval/reports/` is committed
(90a3a5b2), so small-lane checks see a clean tree; (3) hardening (a)-(c) as units 10a and 10b, (d)
accepted (Risks). The four rules the lp-orch cut deleted were intended.

## Dispatch

Contracts: `docs/plans/2026-11-02-lean-pipeline-2/contracts/<id>.md`, written in the next spawns (three per
spawn) and committed before dispatch. Dispatch from the contract only.

## Scribe update hint

Knowledge proposals are unit 15's list. No ADR: no decision meets all three ADR tests.
