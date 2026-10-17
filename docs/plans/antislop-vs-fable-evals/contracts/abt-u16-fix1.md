Unit: abt-u16

## Objective
docs/experiments/abtest-2026-10.md is amended in place, before any run, so that E2 lists mutant w8 as a limit (OD-15), every binding operator decision OD-1 to OD-16 that bears on the pre-registration is reflected, each prediction names its check ids and numbers, the scorer verdict rules cover every outcome (inconclusive, mixed, the OD-13 stall override) and the aggregate rule is copied from design 4.5. One commit.

## Retrieval
GitHub issues: `gh issue view 585 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`. This is fix round 1 of Unit abt-u16 (reviewer FAIL 2026-10-17T19:47:20Z); the failed attempt is commit 92dad262.

## Affected files
- `docs/experiments/abtest-2026-10.md` (anchors: the eight lines named in the ordered edits; HEAD is 92dad262, the failed attempt, 104 lines)

## Ordered edits
1. command: `test -f docs/experiments/abtest-2026-10.md && test "$(grep -c '^### E[1-5]:' docs/experiments/abtest-2026-10.md)" = 5 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `pilot rows are valid rep-1 rows while the harness, plugin and prompt stay the same (OD-14: after a fix the runner`
   indent: 0
   before:
~~~~
Common setup: uniform model policy (every persona on Fable), N=5 reps per arm per eval (a topped-up
N=10 only where the first pass is INCONCLUSIVE), Arm A is the baseline for every entry (bare Fable,
same fixture, same prompt, same turn and time caps), rows in `eval/abtest/results.jsonl`. The N=1
pilot rows are valid rep-1 rows while the harness, plugin and prompt stay the same (OD-14: after a fix the runner
repeats the stale rows and keeps them in results.superseded.jsonl). Rows with `completion_status: usage-limit` are excluded from every
count and the run is repeated. Cost is measured as tokens (input + output + cache write), turns and
wall time; the ratios are `R_tokens`, `R_wall` and `R_turns` over complete runs.
~~~~
   after:
~~~~
Common setup: uniform model policy (every persona on Fable; a headless stall counts as `run_pass` false
with a separate `stalled-human` tally, OD-6), N=5 reps per arm per eval, 50 uniform-policy rows in all
(5 evals x 2 arms x 5 reps, OD-1), with a topped-up N=10 only where the first pass is INCONCLUSIVE.
Arm A is the baseline for every entry (bare Fable, same fixture, same prompt, same caps). Runs are
sequential, one `claude` at a time, and an N=1 pilot per arm per eval runs first as a smoke gate (OD-3).
Both arms get the same main-session turn cap `MAX_TURNS` (default 100, `--max-turns`) and the same
wall-clock cap `TIMEOUT_MIN` (default 45); turns inside Arm B subagents are not counted by the turn cap
(OD-2, OD-9). Rows are in `eval/abtest/results.jsonl`. The N=1 pilot rows are valid rep-1 rows while the
harness, plugin and prompt stay the same (OD-14: after a fix the runner repeats the stale rows and keeps
them in results.superseded.jsonl). Rows with `completion_status: usage-limit` are excluded from every
count and the run is repeated (OD-4). Cost is measured as tokens (`tokens_total` = input + output + cache
write; cache reads are excluded, OD-5), turns and wall time over complete runs; the ratios are
`R_tokens` = median(`tokens_total` of Arm B) / median(`tokens_total` of Arm A), `R_wall` and `R_turns`,
with the design's thresholds unchanged. No dollar figure enters any verdict. Deferred (OD-7): the
shipped-policy replicates for E2 and E5, the E4 critical-mode process sub-run, and the aggregate verdict.
~~~~
3. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `the checkout; the measures are defence in depth, not a proof.`
   indent: 0
   before:
~~~~
the checkout; the measures are defence in depth, not a proof.
~~~~
   after:
~~~~
the checkout; the measures are defence in depth, not a proof.

Known limits (OD-15): the design's statement that a per-line round2 plant creates the rounding trap in E2
is withdrawn, because `applyDiscountPercent` already rounds each discounted unit price to whole cents.
Mutant `w8` passes all four E2 checks and is a known surviving mutant of E2; this pre-registration lists
`w8` as a limit of E2 until the operator adds a cart with non-whole-cent unit prices (not sliced).
~~~~
4. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `- **Prediction**: the mutation check ties near 5/5 in both arms (it passed 18 of 18 in the 2026-07-11`
   indent: 0
   before:
~~~~
- **Prediction**: the mutation check ties near 5/5 in both arms (it passed 18 of 18 in the 2026-07-11
  persona-only pilot); the rounding-sensitive check separates the arms by at least 2 runs in favour of
  Arm B. Both arms at 5/5 is logged as a ceiling TIE (`fixture-too-easy`).
~~~~
   after:
~~~~
- **Prediction**: `no-mutation-and-checkout-match` (the mutation check) passes in at least 4 of 5 runs in each
  arm (it passed 18 of 18 in the 2026-07-11 persona-only pilot); `rounding-sensitive-cart` passes in at
  least 2 more Arm B runs than Arm A runs, counted per check. A preview that scales the total gives 0.54
  and 53.06 where the per-item version gives 0.57 and 53.07, and that is the defect this check separates.
  `run_pass` at 5/5 in both arms (all four required checks) is logged as a ceiling TIE
  (`fixture-too-easy`). Known limit (OD-15): mutant `w8` passes all four E2 checks, so a pass on
  `rounding-sensitive-cart` does not show that non-whole-cent unit prices are rounded per item; `w8` stays
  a limit of E2 until the operator adds a cart that exposes it.
~~~~
5. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `is the base case (Fable's own grep finds the string-keyed`
   indent: 0
   before:
~~~~
- **Prediction**: a TIE on `run_pass` is the base case (Fable's own grep finds the string-keyed
  caller); Arm B passes at least 4 of 5; `R_tokens` between 2 and 6.
~~~~
   after:
~~~~
- **Prediction**: a TIE on `run_pass` is the base case (Fable's own grep finds the string-keyed
  caller); Arm B has `run_pass` in at least 4 of 5 runs; `R_tokens` between 2 and 6.
~~~~
6. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `- **Prediction**: both arms pass the injection and auth-untouched checks at 5/5 (a TIE; Fable alone is`
   indent: 0
   before:
~~~~
- **Prediction**: both arms pass the injection and auth-untouched checks at 5/5 (a TIE; Fable alone is
  expected to avoid `new Function`); `out_of_scope_lines` median 0 in both arms; no `stalled-human` row in
  Arm B; no `protected-paths` deny with `src/auth.js` changed. `R_tokens` between 2 and 6. The
  critical-mode process sub-run is deferred.
~~~~
   after:
~~~~
- **Prediction**: both arms pass `injection-payloads-inert`, `no-dynamic-evaluation-added` and
  `auth-file-untouched` in 5 of 5 runs (a TIE; Fable alone is expected to avoid `new Function`);
  `out_of_scope_lines` median 0 in both arms; no `stalled-human` row in Arm B; no `protected-paths` deny
  with `src/auth.js` changed (`no-protected-path-deny`, reported, not required). `R_tokens` between 2
  and 6. The critical-mode process sub-run is deferred.
~~~~
7. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `cost loss, labelled measured overhead if the outcome is a TIE). The shipped-policy replicate is deferred.`
   indent: 0
   before:
~~~~
- **Prediction**: Arm B passes the six part checks and the four-commits check in at least 4 of 5 runs,
  Arm A in fewer than 4 of 5 on the commits check; `R_tokens` above 3 and `R_wall` above 2 (an expected
  cost loss, labelled measured overhead if the outcome is a TIE). The shipped-policy replicate is deferred.
~~~~
   after:
~~~~
- **Prediction**: in Arm B each of `tags-validation`, `tag-filter-http-and-cli`, `tags-counts`, `migration`,
  `readme-tags-route` (the five required part checks) and `commits-at-least-four` passes in at least 4 of 5
  runs; Arm A passes `commits-at-least-four` in fewer than 4 of 5 runs. `readme-data-format-v2` (the sixth
  part, the README data-format section) is reported but not required (OD-11), so E5 has 8 required checks.
  `R_tokens` above 3 and `R_wall` above 2 (an expected cost loss, labelled measured overhead if the
  outcome is a TIE). The shipped-policy replicate is deferred.
~~~~
8. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `## Verdict rules (copied from the design, with the operator's token amendment)`
   indent: 0
   before:
~~~~
## Verdict rules (copied from the design, with the operator's token amendment)
~~~~
   after:
~~~~
## Verdict rules (copied from the design, with the operator's token amendment)

Two verdicts are kept apart here. The `**Verdict**` line of each entry above records whether the prediction
held (CONFIRMED, REFUTED or INCONCLUSIVE, per `docs/experiments/README.md`). The rules below define the
scorer's per-eval outcome (`WIN_B`, `WIN_A`, `TIE`, `INCONCLUSIVE`) and its scorer verdict (`superior`,
`not-superior`, `mixed`, `inconclusive`). They are different quantities and neither is written in place of
the other.
~~~~
9. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `- Aggregate: AntiSlop is superior overall iff superior on at least 6 of the 10 evals under the uniform`
   indent: 0
   before:
~~~~
- AntiSlop superior: `WIN_B`, or a `TIE` with a quality edge (strictly lower median `defects_escaped`
  and `out_of_scope_lines`) and `R_tokens <= 2`. AntiSlop not superior: `WIN_A`, a `TIE` with no
  quality edge, a `TIE` with `R_tokens > 3`, or any `stalled-human` row in Arm B on these evals.
- Aggregate: AntiSlop is superior overall iff superior on at least 6 of the 10 evals under the uniform
  policy, with no `WIN_A` on E2, E4 or E7, and the E9 overhead bound met under the shipped policy. It
  is NOT superior iff superior on 4 or fewer, or `WIN_A` on E2, E4 or E7, or the E9 bound is exceeded
  while E5 and E8 show no outcome gain. This pass runs E1-E5 only, so the aggregate is
  `not-evaluated (E6-E10 deferred)`; the report gives the per-eval verdicts and whether E2 and E4 avoided
  `WIN_A`.
~~~~
   after:
~~~~
- Scorer verdict, decided in this order: (1) outcome `WIN_A`, or any `stalled-human` row in Arm B, gives
  `not-superior`, whatever the outcome, including an undecided one (OD-13): a pilot (short N) or a 1-run gap
  with a stalled Arm B row reports `not-superior` while the outcome stays `INCONCLUSIVE` with its reason
  (for example "short N: A=1 B=1"); (2) an `INCONCLUSIVE` outcome without a stalled row gives `inconclusive`;
  (3) `WIN_B` gives `superior`, shown as `superior (directional, p=0.xx)` in the markdown when the Fisher p
  is not below 0.10 (OD-12); (4) a `TIE` with no quality edge, or with `R_tokens > 3`, gives `not-superior`;
  a `TIE` with a quality edge (strictly lower median `defects_escaped` and `out_of_scope_lines` in Arm B)
  and `R_tokens <= 2` gives `superior`; a `TIE` with a quality edge and `2 < R_tokens <= 3`, or with
  `R_tokens` not computable, gives `mixed`. AntiSlop is superior on an eval iff its scorer verdict is
  `superior`, and not superior iff it is `not-superior`.
- A `TIE` on E5 carries the label `measured-overhead`: it is `not-superior` by the rule above and is
  reported as the expected result, with `R_tokens` and `R_wall` as the numbers that matter.
- Aggregate rule (design 4.5, pre-registered before any run, edit only in a dated amendment; the design's
  `R_cost` reads `R_tokens` under OD-5):
  - AntiSlop is superior overall iff it is superior on at least 6 of the 10 evals under the `uniform`
    policy, is not inferior (`WIN_A` absent) on each of E2, E4, E7 (the defect-and-premise core), and the
    E9 overhead ratio satisfies `R_tokens <= 8` and `R_wall <= 6` under `shipped`.
  - AntiSlop is NOT superior iff any of: superior on at most 4 evals; `WIN_A` on any of E2, E4, E7; or the
    E9 overhead bound is exceeded while E5 and E8 show no outcome gain (overhead without a quality return).
  - Anything between is mixed, reported eval by eval with no headline claim; each not-superior eval becomes
    a ticket.
- This pass runs E1-E5 only, so the aggregate is `not-evaluated (E6-E10 deferred)` (OD-7); the report gives
  the per-eval verdicts and whether E2 and E4 avoided `WIN_A` (`core_no_win_a`).
~~~~
10. command: `git add docs/experiments/abtest-2026-10.md && git commit -m "docs(abt-u16): add the w8 limit, verdict coverage and falsifiable numbers to the pre-registration (#585)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `docs/experiments/README.md` and every other file under `docs/experiments/` (this unit edits one file beside them)
- `docs/plans/` (never edit a plan or contract by hand)
- `eval/`, `tests/`, `agents/`, `templates/` (this unit changes no code)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)

## Acceptance criteria
1. run: `echo "$(grep -c '^### E[1-5]:' docs/experiments/abtest-2026-10.md),$(grep -c '^## Verdict rules' docs/experiments/abtest-2026-10.md),$(grep -c '^- [*][*]\(Result\|Verdict\|Decision\)[*][*]: pending' docs/experiments/abtest-2026-10.md)"`
   exit: 0
   stdout: `5,1,15`
   mutation: change one `pending` line to `CONFIRMED` or delete the E5 heading; the counts read 5,1,14 or 4,1,15.
   proof: scratch run: sed on a copy of the finished file changed one Result line to CONFIRMED and printed 5,1,14; deleting the E5 heading printed 4,1,15. Green at HEAD by design (a regression guard on the entry shape).
2. run: `awk '/^### E2:/{s=1} /^### E3/{s=0} s' docs/experiments/abtest-2026-10.md | tr '\n' ' ' | tr -s ' ' | grep -o 'w8' | wc -l | tr -d ' '`
   exit: 0
   stdout: `2`
   mutation: skip edit 4; the E2 entry carries no w8 and stdout is 0.
3. run: `for p in 'per-line round2 plant creates the rounding trap in E2 is withdrawn' 'Mutant .w8. passes all four E2 checks and is a known surviving mutant' 'lists .w8. as a limit of E2 until the operator adds a cart'; do tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1`
   mutation: skip edit 3 (the Known limits paragraph); stdout 0,0,0.
4. run: `for p in 'passes in at least 4 of 5 runs in each arm' 'passes in at least 2 more Arm B runs than Arm A runs, counted per check' '.run_pass. at 5/5 in both arms .all four required checks. is logged as a ceiling TIE' 'ties near 5/5'; do awk '/^### E2:/{s=1} /^### E3/{s=0} s' docs/experiments/abtest-2026-10.md | tr '\n' ' ' | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1,0`
   mutation: skip edit 4; the old wording returns and stdout is 0,0,0,1.
5. run: `for p in 'Arm B has .run_pass. in at least 4 of 5 runs'; do awk '/^### E3:/{s=1} /^### E4/{s=0} s' docs/experiments/abtest-2026-10.md | tr '\n' ' ' | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the old wording returns and stdout is 0.
6. run: `for p in 'both arms pass .injection-payloads-inert., .no-dynamic-evaluation-added. and .auth-file-untouched. in 5 of 5 runs' '.no-protected-path-deny., reported, not required'; do awk '/^### E4:/{s=1} /^### E5/{s=0} s' docs/experiments/abtest-2026-10.md | tr '\n' ' ' | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1`
   mutation: skip edit 6; stdout 0,0.
7. run: `for p in 'readme-tags-route. .the five required part checks. and .commits-at-least-four. passes in at least 4 of 5' 'readme-data-format-v2. .the sixth part' 'is reported but not required .OD-11., so E5 has 8 required checks' 'six part checks'; do awk '/^### E5:/{s=1} /^## Verdict rules/{s=0} s' docs/experiments/abtest-2026-10.md | tr '\n' ' ' | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1,0`
   mutation: skip edit 7; the old wording returns and stdout is 0,0,0,1.
8. run: `for p in 'records whether the prediction held' 'and its scorer verdict' 'neither is written in place of the other'; do tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1`
   mutation: skip edit 8; stdout 0,0,0.
9. run: `for p in 'a pilot .short N. or a 1-run gap with a stalled Arm B row reports .not-superior. while the outcome stays .INCONCLUSIVE.' 'an .INCONCLUSIVE. outcome without a stalled row gives .inconclusive.' 'quality edge and .2 < R_tokens <= 3., or with .R_tokens. not computable, gives .mixed.' 'A .TIE. on E5 carries the label .measured-overhead.'; do tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1,1`
   mutation: skip edit 9; stdout 0,0,0,0.
10. run: `for p in 'E9 overhead ratio satisfies .R_tokens <= 8. and .R_wall <= 6. under .shipped.' 'is not inferior ..WIN_A. absent. on each of E2, E4, E7' 'superior on at most 4 evals; .WIN_A. on any of E2, E4, E7; or the E9 overhead bound is exceeded while E5 and E8 show no outcome gain' 'Anything between is mixed, reported eval by eval with no headline claim' 'aggregate is .not-evaluated .E6-E10 deferred..'; do tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1,1,1`
   mutation: skip edit 9; stdout 0,0,0,0,0.
11. run: `for p in 'MAX_TURNS. .default 100, .--max-turns.. and the same wall-clock cap .TIMEOUT_MIN. .default 45.' '50 uniform-policy rows' 'cache reads are excluded, OD-5' 'shipped-policy replicates for E2 and E5' 'turns inside Arm B subagents are not counted' 'stalled-human. tally, OD-6'; do tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | grep -cE "$p"; done | paste -sd, -`
   exit: 0
   stdout: `1,1,1,1,1,1`
   mutation: skip edit 2; stdout 0,0,0,0,0,0.
12. run: `grep -ci 'usd' docs/experiments/abtest-2026-10.md`
   exit: 1
   stdout: `0`
   mutation: add the word USD to the document; stdout 1 and the exit is 0.
   proof: scratch run: a copy of the finished document with one USD added printed 1 with exit 0; the finished file prints 0 with exit 1.
13. run: `grep -c '](' docs/experiments/abtest-2026-10.md`
   exit: 1
   stdout: `0`
   mutation: add a markdown link such as [x](y.md) to the document; stdout 1 and the exit is 0.
   proof: scratch run: a copy with one link added printed 1 with exit 0. This replaces the old link-checker criterion: tests/doc-relative-links.test.js does not scan docs/experiments/ (its SCOPE list omits it), so it could never fail for this file; the document uses backticked paths only, and this grep is the real no-link check.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u16\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); echo "$(echo "$L" | wc -l | tr -d ' ') commits; $(git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" ")"`
   exit: 0
   stdout: `2 commits; docs/experiments/abtest-2026-10.md`
   mutation: skip edit 10 (the commit); only the first unit commit exists and the run prints 1 commits.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u16\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(docs\(abt-u16\): add the w8 limit|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 10; the newest unit commit is the first one (a different subject), so only the trailer line matches and stdout is 1.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u16\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- docs/experiments/abtest-2026-10.md | grep -vcE "^[a-z]+\(abt-u16\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching the document after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
17. run: `git status --porcelain -- docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the edited document stays modified and is listed.

## Pre-resolved context
tdd: no a prose-only document; criteria 2 to 11 and 14 and 15 are red at HEAD
blast-radius: none
fix-of: 2026-10-17T19:47:20Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. Each edit replaces its before block (exact lines of the document at 92dad262) with its after block; the before text occurs once in the file at that edit's turn.
already-green: criteria 1, 12, 13, 16 and 17 pass at HEAD by design (entry shape, no USD, no link, no later untagged commit, a clean scoped tree); they turn red only when the shape is damaged, a USD or link is added, a later untagged commit lands or an edit is left uncommitted.
od-coverage: OD-1 (50 rows) and OD-2 and OD-9 (caps) and OD-3 and OD-4 and OD-5 and OD-6 and OD-7 in the common setup; OD-10 (E1, unchanged and already right); OD-11 in E5; OD-12 and OD-13 and OD-14 in the verdict rules; OD-15 in the Known limits paragraph and the E2 entry; OD-16 in the Isolation paragraph (unchanged and already right); OD-8 is a process rule (who launches runs) and needs no pre-registration text.
no-real-claude: no command in this contract runs the claude CLI.
commit-message: docs(abt-u16): add the w8 limit, verdict coverage and falsifiable numbers to the pre-registration (#585)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u16 (#585)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
