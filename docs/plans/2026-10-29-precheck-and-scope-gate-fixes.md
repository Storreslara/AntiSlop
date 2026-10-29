# Precheck multi-line stdout specs and writer-scope-gate listed-file blocks

Date: 2026-10-29. Author: spec-master (unit tg-spec). Plan slug: `2026-10-29-precheck-and-scope-gate-fixes`.
Written at commit 080b49da.

## Goal
Fix two harness tooling bugs that made reviewers and leads work around the tools by hand on the
refutation-pass units:

- G1 (tg-u1). `bin/review-precheck.sh` grades a criterion whose `stdout:` is "`A` then `B`" (an expected stdout
  of two or more lines) as a false `fail`. After the fix such a spec passes exactly when the output is
  `A`, newline, `B`, and every other spec shape keeps its old verdict.
- G2 (tg-u2). `hooks/scripts/writer-scope-gate.sh` blocks a lead-programmer stop over files the dispatch
  does list. After the fix it reads the two dispatch shapes that caused the blocks, and it still blocks a
  file that neither the dispatch message nor the unit's own contract file lists.

## Context

### Bug 1: what the precheck does today (verified, not inferred)
`run_one()` (`bin/review-precheck.sh:87-98`) matches the spec against three shapes: `empty`, `` `*` ``
(a spec that starts and ends with a backtick, whose outer backticks are stripped once), and anything else,
which is `judge`. Run in a scratch repo at 080b49da:

| spec | output | verdict today |
|---|---|---|
| `` `0` then `rc=0` `` | `0`, `rc=0` | `fail stdout want=0` then `rc=0 got=0` (false fail: the literal keeps its inner backticks) |
| `` `1` then `1` then `1` `` | three lines | false fail, same cause |
| `` `0` then `1` (two lines) `` | two lines | `judge` (it does not end in a backtick) |
| `` `a then b` `` | `a then b` | pass (single literal) |

So the pure form is a false FAIL, not a judge. The repo holds 13 plan or contract files that use the form. On the
real contracts at HEAD, the current precheck fails all seven of the pure-form criteria in rfp-u2 to rfp-u5:
rfp-u2#3, rfp-u3#1, #4, #8, rfp-u4#1, #3 and rfp-u5#1. Of these, rfp-u2#3 also fails on its merits today:
`report.jsonl` has moved on to `real=41`.

### Bug 2: reproduced, root cause stated with evidence
The gate logged six blocks in `.claude/bookkeeping/scope-gate.log`, all `persona=lead-programmer`, on five
agents: a43f7407 (rfp-u1), a72ccb81, a0262e6d and a946994b (two blocks) (label-ui), and a60f6542 (rfp-u2e). The gate takes its
scope from the dispatch's **first user message** in the transcript (the *dispatch message*; it is not the
contract file). In an offline replay I ran the gate's own extraction on each transcript's dispatch message:
`us_section`, `us_entries`, the fallback contract regex at `writer-scope-gate.sh:154` and `us_exclusions`.
I then ran the real gate in a scratch clone with the transcripts' paths rewritten to the clone. The real
gate blocks 4 of the 5 again. The fifth, a72ccb81, the first label-ui dispatch, does not block at today's
HEAD. Its dispatch message has the same shape as the next two, which do block, and I did not look into it
further.

There are two independent root causes, both in how the gate builds its listed set (lines 150-157). None of the
candidate causes the request named is the cause: annotations, `## Do NOT touch` matches, the unit-id cap and
ordering are all ruled out.

- **R1: bare-path bullets are invisible** (label-ui x3, rfp-u2e). The dispatch message's `## Affected
  files` lists paths without backticks, for example `- eval/refutation-replay/label-ui.py (new, mode 755): the generator`
  and `- tests/refutation-replay-isolation.test.sh`. `us_entries` (`hooks/scripts/lib/unit-scope.sh:23-26`)
  keeps only backtick-quoted tokens, so the listed set is empty. These dispatches cite no contract file, so the
  fallback finds nothing either, and every changed file is judged by the remaining classes alone. Evidence: for all
  four dispatch messages, `us_entries` printed nothing and the fallback regex matched nothing. With the label-ui
  `.fail` record present, `label-ui.py` passed as class `fail-record` and the test file (named nowhere) was
  `out`. That is why the log shows only the test file blocked in the later label-ui rounds. For rfp-u2e,
  `run.sh` was edited through Bash with no commit line, so the gate could not attribute it, and only the test
  file was judged.
- **R2: one stray backticked token suppresses the contract fallback** (rfp-u1). The dispatch message's
  `## Affected files` was prose that pointed at the contract file: "Exactly the files the contract's
  `` `## Affected files` `` section lists (… including the generated `` `.claude/` `` mirrors …)". `us_entries`
  returns `.claude/` (it holds a `.`). The listed set is therefore non-empty, so the `if [ ! -s "$W/listed" ]`
  fallback at line 153 never reads `docs/plans/2026-10-27-refutation-pass/contracts/rfp-u1.md`. That contract
  lists both blocked files (`bin/refutation-brief.sh`, `tests/refutation-brief.test.sh`, at its lines 23-24).
  The fallback regex itself does match the absolute path the message cited. It is never reached.

### Fix design (prototyped in a scratch clone; all criteria and mutations below were run there)
- tg-u1: before the `case`, a spec matching `` ^`[^`]*`( then `[^`]*`)+$ `` is split on `` ` then ` ``. Its
  outer backticks are stripped, the parts are joined with newlines and compared with `[ "$got" = … ]`, as in the
  single-literal case. A mismatch prints `criterion <n>: fail stdout want=<spec> got=<output lines rendered as
  `l1` then `l2`>`, on one line. A part may not contain a backtick, so the split is unambiguous. A literal that
  contains the word `then` without the surrounding backticks never matches, and text after the last part (the
  `(two lines)` form) never matches either. Both keep their old verdicts.
- tg-u2, all inside `writer-scope-gate.sh`, with no library change:
  1. R1: every bullet line (`- ` or `* ` at column 0) of the dispatch message's `## Affected files`
     contributes its first word to the listed set when that word, with backticks and a trailing `,:;` removed,
     contains a `/` or a `.` and is made only of path characters. It is the bullet's subject, read the way a
     person reads it. A path that appears later in the bullet's prose is not listed.
  2. R2: the `Unit:` line is read first. When the dispatch message cites `docs/plans/…/contracts/<unit>.md`
     for **its own unit id**, that contract's entries are added to the listed set and its exclusions to the
     excluded set, whatever the message's own section produced. Any other cited contract keeps today's
     behaviour, which is to fall back to the first one only when nothing was listed. So citing another unit's
     contract for context never widens the scope.

  This matches the gate to review-precheck, which takes a unit's scope from its contract file's `## Affected
  files`. A file in neither list is still `out`. The contract's `## Do NOT touch` now also applies when the
  message lists the file, which makes the gate stricter there.

  **Corrected after tg-u2 FAIL 1 (2026-10-29).** The first draft read the cited contract from the working tree
  and claimed "no weaker for unlisted files". That was false: the gate exempts `docs/plans/*`, so a writer could
  edit or create its own contract, add a file to its `## Affected files` (or drop a `## Do NOT touch` entry),
  and the gate, which for a dispatch that lists its files never read the contract before, now accepted the
  edit. Fix (`contracts/tg-u2-fix1.md`): every cited contract is read as the baseline commit holds it
  (`git show "$start:<path>"`; a contract committed before the dispatch is at `$start`, and one the baseline
  lacks is ignored), and a cited path counts only as a clean `docs/plans/<slug>/contracts/<id>.md` with no
  `.`, `..` or empty segment. The gate is then looser than before only in the way the dispatch itself asks
  for, by naming its own contract; a writer's own edit of that contract never widens its scope.

### Gates and the operator authorisation (checked, not assumed)
- `protectedPaths` in the persona config is `[]`, so `protected-paths.sh` asks about none of these files.
- `harness-integrity-gate.sh` Set A (denied on Write/Edit and Bash text) is the persona-selection config and
  the four audit logs. Set B (Write/Edit only) is `hooks/hooks.json`, `.claude/settings.json` and the
  integrity gate itself. None of the authorised files is in either set. One trap is real: a Bash command whose
  text names the persona-selection config is denied, and I hit it twice while exploring. A lead must
  therefore never `git add` that file by name. The precedent (rfp-u1 edit 10) is `git add -u -- .claude
  ':(exclude).claude/agent-memory'` after `node bin/cli.js --update`, the route the gate's own refusal text
  names.
- `reviewed-path-gate.sh` covers `.claude/reviewed/` only. Neither unit writes there.
- The live SubagentStop hook is this repository's `hooks/scripts/writer-scope-gate.sh` (the plugin is loaded
  from this directory: gate refusals print `/home/sebas/AntiSlop/hooks/scripts/…`). An edit to it changes the
  gate that judges every writer's stop at once, and a syntax error makes it exit 2 for every writer. See R-3.
- The operator's authorisation (this session) covers `hooks/scripts/writer-scope-gate.sh`,
  `bin/review-precheck.sh`, their `.claude/` copies and their two test files only. No other gate, no
  `hooks.json` and no library is touched. Both tests are already registered in `tests/validate.sh`
  (lines 879 and 888), so no registration edit is needed.

### Mirrors and version
- Neither file is version-stamped: `version-stamp-check.sh` checks `agents/*.md` and `templates/*` only, so
  P3 requires no bump. The default is no bump and no CHANGELOG entry (Open Question 2), following d8d7b47d,
  which edited both copies of this gate with no bump.
- `node bin/cli.js --update` resyncs a raw copy whenever its content drifts, with no version change needed
  (`bin/cli.js:1544-1558`). It rewrites every drifted copy and the config's `fileHashes`. It cannot be
  scoped, so each unit runs it once, in the commit that changes its source. **Amended 2026-10-29 (tg-u1 FAIL 1):**
  the first draft said `.claude/bin` is checked for presence only, so tg-u1 could commit its source without its
  mirror. That was false: `tests/cli-backfill.test.js` (F2 shape B, C2.12) runs `--update --dry-run` on the tree
  and fails when `bin/review-precheck.sh` differs from `.claude/bin/review-precheck.sh` or the config's
  `fileHashes` (`tests/validate.sh` OK=3442 FAIL=0 at ddc04caf, OK=3439 FAIL=3 at 9306b7d9). tg-u1's fix round
  (`contracts/tg-u1-fix1.md`) therefore runs `--update` and commits the bin mirror and the config. tg-u2's
  `--update` then changes the gate mirror and the config only, and `tests/validate.sh:426` byte-compares
  `hooks/scripts` with `.claude/hooks/scripts`.

### Prior FAIL history and notes
- The `.fail` survey (`grep -rlE '^FAIL (tg-u[0-9]|rfp-u1|label-ui|rfp-u2e) '` over `.claude/reviewed/`,
  the route the reviewed-path gate names) found no record for `tg-*`, rfp-u1 or rfp-u2e. `label-ui.fail`
  exists. It concerns label-ui's own code, and it is why `label-ui.py` passed as class `fail-record` in the
  later label-ui blocks. No unit of this plan has a prior FAIL, so no tier ratchet applies. The
  over-ruled false fails on rfp-u2 to rfp-u5 were never recorded as `.fail` defects against the precheck.
- Results of the notes sweep (`bash bin/marker-audit.sh . --notes --surface=<path>`, run on each of the four
  files). It is best-effort, and an empty sweep proves nothing:
  - `NOTE[spec]` on rfp-u2 and rfp-u3 ("a false fail in the precheck (run_one …:94-95) … reads the stdout spec
    "`A` then `B`" as one literal"): this is bug 1 itself. **Closed by tg-u1.**
  - `NOTE[spec]` on st-u2 (a relative `--contract` is resolved against the repo top, not cwd): a different
    behaviour, **out of scope** and unchanged.
  - Two `NOTE[code]` on st-u2 (`top_rel` is lexical; `--fix-contract` is read from the working tree): **out
    of scope** and unchanged.
  - `NOTE[code]` on st-u3 (writer-scope-gate.sh:44, one malformed line empties the Write/Edit paths):
    **stale**. rp-u15 replaced it with per-line parsing (now line 72, test case (s)).
  - No `untagged` line and no note on either test file.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-29 Non-functional attributes (perf, security, scale): Q Does widening the gate's listed set weaken
  it against real out-of-scope edits? → A (self-resolved, corrected after tg-u2 FAIL 1): it would have, as first
  written (the contract was read from the working tree, which the writer can edit; the first answer "no" was
  wrong). Now only the unit's own contract file as the baseline commit holds it is added, and only a bullet's
  first word. Tests (ac) 2, 4, 5 and 6 pin that unlisted, prose-named, excluded and other-contract files are
  still blocked, and tests (ac) 7 to 11 pin that a contract the writer edits (uncommitted or committed),
  creates, or cites through `..` never widens the scope, each with a mutation.
- 2026-10-29 External dependencies & integrations: Q How do the `.claude/` copies get regenerated, and by
  whom? → A (self-resolved, amended after tg-u1 FAIL 1): `node bin/cli.js --update`, once in each unit's own
  commit (tg-u1 fix round for `.claude/bin/review-precheck.sh`, tg-u2 for the gate mirror), never in a commit
  that changes a source without its mirror. The
  persona-selection config is staged with `git add -u -- .claude ':(exclude).claude/agent-memory'`, never by
  name.
- 2026-10-29 Edge cases / failure handling: Q Should the `` `A` then `B` (two lines) `` form (text after the
  last part) also be split? → A (self-resolved, offered as Open Question 3): no. It stays `judge`, as today,
  because the request names only the pure form and the reviewer reads such specs by hand already.
- 2026-10-29 Edge cases / failure handling: Q What about a bullet whose first word looks like a path but is
  prose, such as `- e.g. …`? → A (self-resolved): it is listed and is harmless. `e.g.` names no tracked
  file. A real path that appears later in a bullet's prose is never listed (test (ac) 2).
- 2026-10-29 Technical constraints & tradeoffs: Q Can tg-u1 and tg-u2 be built at the same time? → A
  (self-resolved, offered as Open Question 1): their hand-edited files are disjoint, but two shared-tree
  hazards remain. An uncommitted `hooks/scripts` edit makes validate.sh's parity check fail for everyone in
  the tree, and the live gate is the file being edited. The default is therefore tg-u1 first, then tg-u2.
  Running them in parallel is safe only with tg-u2 in its own worktree.
- 2026-10-29 Technical constraints & tradeoffs: Q Bump the plugin version? → A (self-resolved, offered as
  Open Question 2): no. Neither file is stamped, and `--update` resyncs raw copies on content drift.
- 2026-10-29 Terminology consistency: Q The request says "dispatch prompt" for the text the gate reads, and
  CONTEXT.md lists "dispatch prompt" as an _Avoid_ synonym of "contract file". Which artifact is meant? → A
  (self-resolved): the gate reads the dispatch's first user message, which is not the contract file. This plan
  calls it the *dispatch message* and keeps "contract file" for `docs/plans/<slug>/contracts/<id>.md`.

## Risks/dependencies
- R-1 (tg-u2 depends on tg-u1 for its last edit). tg-u2's `--update` copies whatever `bin/review-precheck.sh`
  holds at that moment into `.claude/bin/`. After tg-u1's fix round that copy is already current, so tg-u2's
  `--update` leaves it alone and changes the gate mirror and the config only. Its edit 6 keeps its checked
  precondition (a `(tg-u1): ` commit is on HEAD and tg-u1's two files are clean); if not met, the lead stops
  with `STATUS: incomplete` and does not run `--update`.
- R-2 (validate.sh runtime). My memory records a 1729 s validate.sh run, longer than the 600 s ceiling. tg-u2
  criterion 7 is the full suite, marked long. I timed it on this tree: see Self-check CHK7.
- R-3 (live gate). tg-u2 edits the hook that judges every writer's stop, so a syntax error would block all
  writers. tg-u2's edits replace one whole hunk and are followed at once by `bash -n` (edit 3). The dispatch
  message for tg-u2 must list its files backticked under `## Affected files`. The old gate and the new one
  both read that shape, so tg-u2's own stop is judged correctly whichever version is live.
- R-4 (replay criterion depends on the tree). tg-u1 criterion 3 compares old and new verdicts on the same tree,
  so shared state cancels out. Its `fixed=ok` threshold is 5, not 7: rfp-u2#3 fails on its merits, and
  rfp-u3#8 depends on the untracked `report.jsonl`. Criterion 4 pins the five that do not depend on that state.
- R-5 (scope of the R1 parse). It applies to the dispatch message only, never to a contract file. A contract
  file keeps the backtick rule, so the gate and review-precheck (which reads only contract files) agree on
  every contract.
- No hard exclusion is touched: no other hook or gate, no `hooks.json`, no `protected-paths.sh`,
  `harness-integrity-gate.sh` or `reviewed-path-gate.sh`, no `hooks/scripts/lib/`, no `labels.tsv`,
  `corpus.jsonl` or `report.jsonl`, and nothing under `.claude/reviewed/`.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Both bugs were reproduced on real inputs before the fix was designed,
  and every criterion and mutation was run on a scratch prototype.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The `.claude/` copies change only
  through `node bin/cli.js --update` (tg-u2 edit 6). Both contracts list them as never edited by hand.
- P3 "Version-stamp discipline": satisfied. No stamped path (`agents/*.md`, `templates/*`) is touched. tg-u2
  criterion 6 runs `version-stamp-check.sh`.
- P5 "`tests/validate.sh` is the merge gate": satisfied. tg-u1's commit leaves the hook mirrors untouched and
  `tests/cli-backfill.test.js` fails on a source that differs from its mirror or the config record (amended: it
  is not presence-only). tg-u1's fix round and tg-u2 each commit a source edit together with its regenerated
  mirror and config, and each unit's criteria run the full suite.

## Steps

### Step 1 (tg-u1): precheck reads "`A` then `B`" as a multi-line literal
Affected files: `bin/review-precheck.sh`, `tests/review-precheck.test.sh`.
Acceptance criteria: see `contracts/tg-u1.md` (suite green with 6 new (m) cases; old-vs-new replay over
rfp-u2 to rfp-u5 prints `bad=0 fixed=ok`; the five stable multi-part criteria print `5 pass`; scope count 0).

### Step 2 (tg-u2): writer-scope-gate reads bare-bullet lists and the unit's own contract
Affected files: `hooks/scripts/writer-scope-gate.sh`, `tests/writer-scope-gate.test.sh`; generated by
`--update`: `.claude/hooks/scripts/writer-scope-gate.sh`, the config's `fileHashes` (amended: the
`.claude/bin/review-precheck.sh` mirror is tg-u1's).
Acceptance criteria: see `contracts/tg-u2.md` (suite green with 6 new (ac) cases; both mirrors byte-equal;
scope count 0; version-stamp ok; validate.sh 0).

No third (scribe) unit: neither fix changes a documented behaviour that a glossary entry or the README states
(the hint below is optional).

## Dispatch
- Order: tg-u1, then tg-u2 after tg-u1's PASS (Open Question 1 offers parallel dispatch with tg-u2 in a worktree).
- Tier: `node bin/contract-guard.js <contract> --unit=<id> --shape=lead` prints `contract-guard: sonnet …
  score=3/7 failed=R1,R5,R6,R7` for both units, so both go on sonnet. That suits tg-u2 anyway, since it
  edits the live gate.
- [tg-u1 contract](2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u1.md)
- [tg-u2 contract](2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md)
- Each dispatch message's `## Affected files` must copy the contract's backticked list verbatim, not prose.
  Prose is the R2 shape and still blocks under the old gate, which is live until tg-u2 lands.

## Open Questions
1. Concurrency. Default: **sequential** (tg-u1 to PASS, then tg-u2). Options: (a) sequential; (b) parallel,
   with tg-u2 dispatched with `isolation: "worktree"` and its edit 6 run only once tg-u1's commits are merged
   into its branch; (c) parallel in the shared tree (not recommended: R-3, and the validate.sh parity check
   fails for tg-u1's lead while tg-u2's hook edit is uncommitted).
2. Version bump. Default: **none** (no stamped path changes, and `--update` resyncs raw copies on drift).
   Option: tg-u2 also bumps the patch version and adds a CHANGELOG entry for both fixes, so marketplace
   consumers who update by version pick them up. It is a mirror-regenerating change either way, so it stays
   in tg-u2.
3. The `` `A` then `B` (two lines) `` form (text after the last part). Default: **stays judge**. Option: also
   strip a trailing ` (…)` annotation and split. Ten such specs exist in older plans
   (`2026-10-09-backlog-cleanup.md`, `antislop-review-patches/`).

## Self-check
- CHK1: Is the expected precheck line defined for every spec shape tg-u1's tests use (pass, mismatch, three-part, a literal holding `then`, annotated, short output)? — PASS
- CHK2: Do Step 1 and tg-u1 criterion 3 agree about which real criteria may change verdict (exactly rfp-u2#3, rfp-u3#1/#4/#8, rfp-u4#1/#3, rfp-u5#1, and only fail to pass)? — PASS
- CHK3: Is it defined, for the bare-bullet parse, which word of a bullet becomes an entry (first word only), and is there a test with a mutation for the prose-path case? — PASS
- CHK4: Is it defined which cited contract the gate reads (own unit id only, otherwise the old first-match fallback), and is there a test where another unit's contract does not widen the scope? — PASS
- CHK5: Do the two contracts agree about who runs `node bin/cli.js --update` (amended: each unit, in its own commit; tg-u1's fix round first) and when? — PASS
- CHK6: Is the way to stage the persona-selection config defined without naming it in a Bash command (the Set A trap)? — PASS
- CHK7: Is tg-u2 criterion 7 (full `tests/validate.sh`) runnable within the 600000 ms ceiling? — PASS (timed on this tree on 2026-10-29: rc=0 in 261 s, no FAIL line)
- CHK8 (constitution P5): Does every commit either unit makes leave `tests/validate.sh`'s mirror-parity check green? — PASS after amendment (FAIL 1 of tg-u1 showed the first draft was wrong: tg-u1's source commit broke `tests/cli-backfill.test.js`. tg-u1's fix round and tg-u2 edit 7 each commit the source with its mirror and config)
- CHK9 (replay source, `docs/audits/unit-outcomes/2026-10-06.jsonl`): Does criterion tg-u2 AC7 still fail under its own `mutation:` line, given that gh317, gh320, mw-step1, mw-step2, mw-step3, rollout-map-1, spec2-unitA and spec2-unitB were recorded `vacuous`, and gh346-2, gh409, gh413 and human-review-cleanup-1 `vacuous,host` (each changed `tests/validate.sh`)? — PASS. The mutation (skipping `--update`) trips the parity check at `tests/validate.sh:426`. That check sets `fail=1`, the inner run exits with it, and the lane runner returns it as `inner_rc`, so stdout is `1`.
- CHK10 (replay source): Does criterion tg-u2 AC6 still fail under its own `mutation:` line, given that ci-fetch-depth-cleanup and item17-4-name-p3-offenders were recorded `host` (each changed `hooks/scripts/version-stamp-check.sh`)? — PASS. The mutation edits a stamped path with no bump, and AC6 reads the script's verdict word (`touched: yes`), not only its exit code, which is always 0.
- CHK11: Is every Goal clause mapped to a criterion? G1 "every other spec shape keeps its old verdict" → tg-u1 criterion 1 (cases 4 and 5) and criterion 3 (`bad=0`); G2 "still blocks a file that neither … lists" → tg-u2 criterion 2 (cases 2, 4, 5 and 6). — PASS
- CHK12: Are the payloads in the contracts the ones that were tested? — PASS (a script compared all eight before/after blocks with the tested scratch payloads: all identical; spec-master's end-to-end clone run of edits 1 to 7 printed every criterion's stated stdout)

## Scribe update hint
Optional, harness vocabulary (belongs in `docs/harness-glossary.md`, not CONTEXT.md): "multi-part stdout
spec": a criterion's `stdout:` of the form `` `A` then `B` ``, graded by review-precheck as the exact
multi-line output. Also "dispatch message" (the first user message of a dispatched writer's transcript,
which writer-scope-gate reads; not the contract file). Neither is a CONTEXT.md entry, and no knowledge file
is written by this plan.
