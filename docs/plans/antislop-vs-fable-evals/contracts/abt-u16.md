Unit: abt-u16

## Objective
docs/experiments/abtest-2026-10.md pre-registers the E1-E5 predictions in the docs/experiments entry shape (Result, Verdict and Decision pending), states the common setup and the verdict rules with the operator token amendment, and says the aggregate is not evaluated. One commit.

## Retrieval
GitHub issues: `gh issue view 585 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `docs/experiments/abtest-2026-10.md` (anchor: new file)

## Ordered edits
1. command: `test ! -e docs/experiments/abtest-2026-10.md && test -f docs/experiments/README.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `docs/experiments/abtest-2026-10.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# AntiSlop vs bare Fable: E1-E5 pre-registration (2026-10)

Pre-registered before any run. Design: `docs/plans/antislop-vs-fable-evals.md`; operator overrides:
`docs/plans/antislop-vs-fable-evals/operator-decisions.md` (Max subscription, sequential runs,
usage-limit rows are not outcomes, tokens instead of dollars, E1-E5 only). The predictions below are
drafted from the design's expected directions and the verdict thresholds of its section 4.4; the
operator may edit them in a dated amendment before the first run, never after.

Common setup: uniform model policy (every persona on Fable), N=5 reps per arm per eval (a topped-up
N=10 only where the first pass is INCONCLUSIVE), Arm A is the baseline for every entry (bare Fable,
same fixture, same prompt, same turn and time caps), rows in `eval/abtest/results.jsonl`. The N=1
pilot rows are valid rep-1 rows. Rows with `completion_status: usage-limit` are excluded from every
count and the run is repeated. Cost is measured as tokens (input + output + cache write), turns and
wall time; the ratios are `R_tokens`, `R_wall` and `R_turns` over complete runs.

### E1: ambiguous spec resolved from repo evidence (e01-ambiguous-tax)

- **Hypothesis**: H3. Spec grilling resolves the tax ambiguity from `CONTEXT.md` and the README
  before code is written.
- **Prediction**: the premise check (ASSUMPTIONS.md recorded) passes in at least 4 of 5 Arm B runs;
  the two defect checks are a likely tie at 5/5 in both arms; `run_pass` favours B by at least 2 runs
  (WIN_B) only if Arm A misses the premise check twice. If the arms tie, `R_tokens` is expected above 2.
- **Change**: none (a comparison, not a variant).
- **Baseline**: Arm A rows for `e01-ambiguous-tax`, same rep count.
- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E2: planted trap a self-review misses (e02-preview-mutation)

- **Hypothesis**: H1. The reviewer runs the checks itself and catches a preview that diverges from a
  per-item-rounded checkout.
- **Prediction**: the mutation check ties near 5/5 in both arms (it passed 18 of 18 in the 2026-07-11
  persona-only pilot); the rounding-sensitive check separates the arms by at least 2 runs in favour of
  Arm B. Both arms at 5/5 is logged as a ceiling TIE (`fixture-too-easy`).
- **Change**: none.
- **Baseline**: Arm A rows for `e02-preview-mutation`.
- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E3: refactor with blast radius (e03-rename-query)

- **Hypothesis**: H1 and H2. Blast-radius lookup and reviewer caller checks find the string-keyed caller.
- **Prediction**: a TIE on `run_pass` is the base case (Fable's own grep finds the string-keyed
  caller); Arm B passes at least 4 of 5; `R_tokens` between 2 and 6.
- **Change**: none.
- **Baseline**: Arm A rows for `e03-rename-query`.
- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E4: security-sensitive change (e04-search-injection)

- **Hypothesis**: H1, H6 and H2. The reviewer's security lens and the protected-path gate keep the
  search route injection-free and `src/auth.js` untouched.
- **Prediction**: both arms pass the injection and auth-untouched checks at 5/5 (a TIE; Fable alone is
  expected to avoid `new Function`); `out_of_scope_lines` median 0 in both arms; no `stalled-human` row in
  Arm B; no `protected-paths` deny with `src/auth.js` changed. `R_tokens` between 2 and 6. The
  critical-mode process sub-run is deferred.
- **Change**: none.
- **Baseline**: Arm A rows for `e04-search-injection`.
- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E5: multi-unit feature needing decomposition (e05-tags-feature)

- **Hypothesis**: H4 and H8. The six-part feature lands complete and in separate commits; the
  pipeline's cost is the price of that.
- **Prediction**: Arm B passes the six part checks and the four-commits check in at least 4 of 5 runs,
  Arm A in fewer than 4 of 5 on the commits check; `R_tokens` above 3 and `R_wall` above 2 (an expected
  cost loss, labelled measured overhead if the outcome is a TIE). The shipped-policy replicate is deferred.
~~~~
3. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `  cost loss, labelled measured overhead if the outcome is a TIE). The shipped-policy replicate is deferred.`
   indent: 0
   insert-after:
~~~~
- **Change**: none.
- **Baseline**: Arm A rows for `e05-tags-feature`.
- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

## Verdict rules (copied from the design, with the operator's token amendment)

- Per eval: `WIN_B` if `k_B - k_A >= 2` at N=5 (Fisher exact p < 0.10 at N=10), `WIN_A` symmetrically,
  else `TIE`; `INCONCLUSIVE` for a 1-run gap or two or more `turn-cap`, `timeout` or `error` rows in
  either arm.
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
4. command: `git add docs/experiments/abtest-2026-10.md && git commit -m "docs(abt-u16): pre-register the E1-E5 predictions (#585)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `docs/experiments/README.md` and every other file under `docs/experiments/` (this unit adds one file beside them)
- `docs/plans/` (never edit a plan or contract by hand)
- `eval/`, `tests/`, `agents/`, `templates/` (this unit changes no code)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)

## Acceptance criteria
1. run: `grep -c '^### E[1-5]:' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `5`
   mutation: delete the E5 heading line from the document; stdout 4 and the exit is 0.
   proof: scratch run: sed deleting the E5 heading line left a file for which the grep printed 4.
2. run: `grep -c '^## Verdict rules' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the last part of the document); the heading is gone, stdout 0 and the exit is 1.
3. run: `grep -c '^- [*][*]Result[*][*]: pending' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `5`
   mutation: skip edit 3; grep exits 2 on the missing file and prints nothing.
4. run: `grep -c 'R_tokens' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `7`
   mutation: skip edit 3; grep exits 2 on the missing file and prints nothing.
5. run: `grep -ci 'usd' docs/experiments/abtest-2026-10.md`
   exit: 1
   stdout: `0`
   mutation: add the word USD to the document; stdout 1 and the exit is 0.
   proof: scratch run: a copy of the document with one USD added printed 1 with exit 0; the finished file prints 0 with exit 1.
6. run: `grep -c 'not-evaluated' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; grep exits 2 on the missing file and prints nothing.
7. run: `node tests/doc-relative-links.test.js | tail -n 1`
   exit: 0
   stdout: `doc-relative-links: ok`
   mutation: add a markdown link to a missing file to the document; the checker prints a FAIL line and the tail is not ok.
   proof: scratch run: the checker is green at HEAD and after the file lands; a dangling relative link in the document made it exit non-zero.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u16\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md`
   mutation: skip edit 4 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u16\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u16\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- docs/experiments/abtest-2026-10.md | grep -vcE "^[a-z]+\(abt-u16\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: empty
   mutation: skip edit 4; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no a prose-only document; criteria 1-6 are red at HEAD because the file does not exist
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 7 (the link checker) and criterion 11 (the scoped clean-tree check) pass at HEAD by design; they turn red only if a dangling link is added or the commit step is skipped.
depends-on: abt-u14 should have landed first so the document and the scorer agree; nothing in this unit reads the scorer.
no-real-claude: no command in this contract runs the claude CLI.
commit-message: docs(abt-u16): pre-register the E1-E5 predictions (#585)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
