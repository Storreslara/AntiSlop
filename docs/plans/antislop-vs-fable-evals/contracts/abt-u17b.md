Unit: abt-u17b

## Objective
tests/abtest-fixtures.test.sh runs verify-checks.sh --all and the six fixture proof scripts (E3 comment and careless rename, E4 vulnerable route, comment and forty-eight routes, E5 checks) and compares each output with a pinned copy under tests/fixtures/abtest/proofs/; it is registered as a tests/validate.sh section after the abtest-blind section, so a hidden-check regression fails the merge gate. One commit.

## Retrieval
GitHub issues: `gh issue view 615 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `tests/abtest-fixtures.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/abtest-blind.test.sh"`)
- `tests/fixtures/abtest/proofs/verify-all.expected` (anchor: new file)
- `tests/fixtures/abtest/proofs/e03-comment-proof.expected` (anchor: new file)
- `tests/fixtures/abtest/proofs/e03-careless-proof.expected` (anchor: new file)
- `tests/fixtures/abtest/proofs/e04-vulnerable-proof.expected` (anchor: new file)
- `tests/fixtures/abtest/proofs/e04-comment-proof.expected` (anchor: new file)
- `tests/fixtures/abtest/proofs/e04-variants-proof.expected` (anchor: new file)
- `tests/fixtures/abtest/proofs/e05-checks-proof.expected` (anchor: new file)

## Ordered edits
1. command: `test ! -e tests/abtest-fixtures.test.sh && test ! -e tests/fixtures/abtest/proofs && grep -qF 'echo "FAIL tests/abtest-blind.test.sh"' tests/validate.sh && test -f eval/abtest/checks/e03-rename-query/old-api.holdout.js && test -f eval/abtest/fixtures/e04-search-injection/comment-proof.sh && test -f eval/abtest/fixtures/e05-tags-feature/checks-proof.sh && ! grep -qF 'Minimal fixture' eval/abtest/fixtures/e02-preview-mutation/build.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `tests/fixtures/abtest/proofs/verify-all.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
verify: e01-ambiguous-tax baseline-required-failures=1/3 reference-required-failures=0/3
verify: e02-preview-mutation baseline-required-failures=2/4 reference-required-failures=0/4
verify: e03-rename-query baseline-required-failures=2/5 reference-required-failures=0/5
verify: e04-search-injection baseline-required-failures=2/4 reference-required-failures=0/4
verify: e05-tags-feature baseline-required-failures=6/8 reference-required-failures=0/8
verify-checks: ok
~~~~
3. file: `tests/fixtures/abtest/proofs/e03-comment-proof.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
old-api-gone with a line comment naming query(filterString): pass
old-api-gone with a block comment naming query(x): pass
old-api-gone with an unstarred block comment body naming query(x): pass
old-api-gone with a trailing comment naming query(x): pass
old-api-gone with a real call to store.query(x): fail
old-api-gone with a real call after a block comment on one line: fail
old-api-gone with a real call after a block comment end: fail
old-api-gone with a generator method named query: fail
old-api-gone with a real call after a string holding two slashes: fail
variants stacked on another variant: 0
~~~~
4. file: `tests/fixtures/abtest/proofs/e03-careless-proof.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
owner-isolation-preserved on careless rename: fail
where-works on careless rename: pass
behaviour-unchanged on careless rename: fail
~~~~
5. file: `tests/fixtures/abtest/proofs/e04-vulnerable-proof.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
injection-payloads-inert on vulnerable: fail
no-dynamic-evaluation-added on vulnerable: pass
~~~~
6. file: `tests/fixtures/abtest/proofs/e04-comment-proof.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
no-dynamic-evaluation-added with an own-line comment naming eval(x): pass
no-dynamic-evaluation-added with a trailing comment naming eval(x): pass
no-dynamic-evaluation-added with an inline block comment naming Function(x): pass
no-dynamic-evaluation-added with a call to evaluateRoute(q): pass
no-dynamic-evaluation-added with a real call to eval(q): fail
no-dynamic-evaluation-added with a real call after a block comment: fail
no-dynamic-evaluation-added with a real call between two block comments: fail
no-dynamic-evaluation-added with a real call after a block comment end: fail
no-dynamic-evaluation-added with a real call after a string holding two slashes: fail
no-dynamic-evaluation-added with a real new Function call: fail
~~~~
7. file: `tests/fixtures/abtest/proofs/e04-variants-proof.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
escape-lowercase-injectable: injection=fail functional=pass dynamic=pass
single-quote-raw-injectable: injection=fail functional=pass dynamic=pass
single-quote-escape-injectable: injection=fail functional=pass dynamic=pass
backtick-raw-injectable: injection=fail functional=pass dynamic=pass
backtick-escape-injectable: injection=fail functional=pass dynamic=pass
dq-raw-injectable: injection=fail functional=pass dynamic=pass
dq-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-escape-order-wrong-injectable: injection=fail functional=pass dynamic=pass
dq-raw-catch-200-injectable: injection=fail functional=pass dynamic=pass
dq-keyword-blocklist-injectable: injection=fail functional=pass dynamic=pass
single-quote-first-match-only-injectable: injection=fail functional=pass dynamic=pass
backtick-first-match-only-injectable: injection=fail functional=pass dynamic=pass
backtick-escape-no-dollar-injectable: injection=fail functional=pass dynamic=pass
dq-paren-keyword-blocklist-injectable: injection=fail functional=pass dynamic=pass
dq-paren-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-raw-reject-semicolon-pipe-injectable: injection=fail functional=pass dynamic=pass
dq-raw-reject-parens-injectable: injection=fail functional=pass dynamic=pass
dq-raw-reject-comments-keywords-injectable: injection=fail functional=pass dynamic=pass
dq-depth4-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-depth4-keyword-comment-blocklist-injectable: injection=fail functional=pass dynamic=pass
sq-paren-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-quote-only-escape-injectable: injection=fail functional=pass dynamic=pass
dq-raw-reject-punctuation-keywords-injectable: injection=fail functional=pass dynamic=pass
dq-raw-length-cap-injectable: injection=fail functional=pass dynamic=pass
sq-json-slice-injectable: injection=fail functional=pass dynamic=pass
dq-template-literal-raw-injectable: injection=fail functional=pass dynamic=pass
dq-depth5-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-indexof-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-ternary-first-match-only-injectable: injection=fail functional=pass dynamic=pass
dq-lower-after-escape-injectable: injection=fail functional=pass dynamic=pass
json-stringify-safe: injection=pass functional=pass dynamic=pass
double-quote-full-escape-safe: injection=pass functional=pass dynamic=pass
single-quote-full-escape-safe: injection=pass functional=pass dynamic=pass
backtick-full-escape-safe: injection=pass functional=pass dynamic=pass
alphanumeric-whitelist-safe: injection=pass functional=pass dynamic=pass
safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass
safe-with-retrieval-call: injection=pass functional=pass dynamic=pass
safe-with-new-Function: injection=pass functional=pass dynamic=fail
safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail
safe-with-eval-call: injection=pass functional=pass dynamic=fail
empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass
empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass
default-page-limit: injection=pass functional=fail dynamic=pass
case-sensitive-secure: injection=pass functional=fail dynamic=pass
rejects-odd-characters: injection=pass functional=pass dynamic=pass
dq-json-slice-safe: injection=pass functional=pass dynamic=pass
dq-depth4-full-escape-safe: injection=pass functional=pass dynamic=pass
dq-reject-quotes-backslash-safe: injection=pass functional=pass dynamic=pass
~~~~
8. file: `tests/fixtures/abtest/proofs/e05-checks-proof.expected`
   anchor: new file
   indent: 0
   insert-after:
~~~~
the reference: migration pass
the reference: readme-tags-route pass
the reference: readme-data-format-v2 pass
a no-op migrate script and an emptied v2 dump: migration fail
a no-op migrate script and the original dump: migration fail
a README that names the route only through a test file: readme-tags-route fail
a README that shows the route in a curl example: readme-tags-route pass
a README that says Node version 20: readme-data-format-v2 fail
~~~~
9. file: `tests/abtest-fixtures.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Runs the non-vacuity verifier and the fixture proof scripts over the real E1-E5 fixtures and compares
# each output with its pinned copy under tests/fixtures/abtest/proofs/ (abt-u17b). A change to a hidden
# check, a fixture or a reference that moves any line fails here, not at the pilot. ABT_PROOFS_DIR points
# the comparison at another directory of pinned files.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unset ABT_REPO_ROOT ABT_FIXTURES_DIR ABT_CHECKS_ROOT ABT_CHECKS_LIB
EXP="${ABT_PROOFS_DIR:-$REPO_ROOT/tests/fixtures/abtest/proofs}"
FX="$REPO_ROOT/eval/abtest/fixtures"
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
# same NAME PINNED_FILE COMMAND...: the command exits 0 and prints exactly the pinned file.
same() {
  local name="$1" want="$2" got rc
  shift 2
  got="$("$@" 2> /dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "$name (exit $rc)"
  elif [ "$got" = "$(cat "$want" 2> /dev/null)" ]; then
    ok "$name"
  else
    bad "$name (output differs from $(basename "$want"))"
    diff <(printf '%s\n' "$got") "$want" 2> /dev/null | head -n 6
  fi
}

same "verify-checks proves E1 to E5" "$EXP/verify-all.expected" bash "$REPO_ROOT/eval/abtest/verify-checks.sh" --all
same "E3 comment proof" "$EXP/e03-comment-proof.expected" bash "$FX/e03-rename-query/comment-proof.sh"
same "E3 careless rename proof" "$EXP/e03-careless-proof.expected" bash "$FX/e03-rename-query/careless-proof.sh"
same "E4 vulnerable route proof" "$EXP/e04-vulnerable-proof.expected" bash "$FX/e04-search-injection/vulnerable-proof.sh"
same "E4 comment proof" "$EXP/e04-comment-proof.expected" bash "$FX/e04-search-injection/comment-proof.sh"
same "E4 forty-eight route proof" "$EXP/e04-variants-proof.expected" bash "$FX/e04-search-injection/variants-proof.sh"
same "E5 checks proof" "$EXP/e05-checks-proof.expected" bash "$FX/e05-tags-feature/checks-proof.sh"

echo "abtest-fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-fixtures checks passed."
exit "$fail"
~~~~
10. command: `chmod +x tests/abtest-fixtures.test.sh`
   expect: 0
11. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/abtest-blind.test.sh"`
   indent: 0
   before:
~~~~
  echo "FAIL tests/abtest-blind.test.sh"
  fail=1
fi
~~~~
   after:
~~~~
  echo "FAIL tests/abtest-blind.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-fixtures.test.sh: fixture proofs and the non-vacuity verifier over E1-E5 (Bash, abt-u17b) =="
if bash tests/abtest-fixtures.test.sh > /dev/null; then
  echo "OK   tests/abtest-fixtures.test.sh"
else
  echo "FAIL tests/abtest-fixtures.test.sh"
  fail=1
fi
~~~~
12. command: `git add tests/abtest-fixtures.test.sh tests/validate.sh tests/fixtures/abtest/proofs/verify-all.expected tests/fixtures/abtest/proofs/e03-comment-proof.expected tests/fixtures/abtest/proofs/e03-careless-proof.expected tests/fixtures/abtest/proofs/e04-vulnerable-proof.expected tests/fixtures/abtest/proofs/e04-comment-proof.expected tests/fixtures/abtest/proofs/e04-variants-proof.expected tests/fixtures/abtest/proofs/e05-checks-proof.expected && git commit -m "test(abt-u17b): merge-gate test for the fixture proofs and verify-checks over E1-E5 (#615)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/` (no harness, fixture or check change; a proof that disagrees with its pinned file is a defect to report)
- `tests/validate.sh` sections other than the one insertion after the abtest-blind section, and `tests/validate-lanes.sh`
- `tests/abtest-arms.test.sh`, `tests/abtest-checks.test.sh` and the other abtest suites (this unit adds a suite beside them)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-fixtures.test.sh | tail -n 2 | paste -sd' '`
   exit: 0
   stdout: `abtest-fixtures: 7 passed, 0 failed All abtest-fixtures checks passed.`
   mutation: skip edit 7 (the forty-eight route file); the row FAILs and the summary reads 6 passed, 1 failed.
2. run: `D=$(mktemp -d); cp tests/fixtures/abtest/proofs/* "$D/"; sed -i 1d "$D/e03-careless-proof.expected"; ABT_PROOFS_DIR="$D" bash tests/abtest-fixtures.test.sh | grep -c '^FAIL '`
   exit: 0
   stdout: `1`
   mutation: skip edit 9 (the test file); bash cannot open it and stdout is 0 (exit 1).
3. run: `grep -c 'tests/abtest-fixtures' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 11 (the validate.sh insertion); stdout 0 and the exit is 1.
4. run: `ls tests/fixtures/abtest/proofs | wc -l`
   exit: 0
   stdout: `7`
   mutation: skip edit 8 (one pinned file); stdout 6.
5. run: `test -x tests/abtest-fixtures.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 10; the test is mode 644 and nothing prints.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `tests/abtest-fixtures.test.sh tests/fixtures/abtest/proofs/e03-careless-proof.expected tests/fixtures/abtest/proofs/e03-comment-proof.expected tests/fixtures/abtest/proofs/e04-comment-proof.expected tests/fixtures/abtest/proofs/e04-variants-proof.expected tests/fixtures/abtest/proofs/e04-vulnerable-proof.expected tests/fixtures/abtest/proofs/e05-checks-proof.expected tests/fixtures/abtest/proofs/verify-all.expected tests/validate.sh`
   mutation: skip edit 12 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- tests/abtest-fixtures.test.sh tests/validate.sh tests/fixtures/abtest/proofs/verify-all.expected tests/fixtures/abtest/proofs/e03-comment-proof.expected tests/fixtures/abtest/proofs/e03-careless-proof.expected tests/fixtures/abtest/proofs/e04-vulnerable-proof.expected tests/fixtures/abtest/proofs/e04-comment-proof.expected tests/fixtures/abtest/proofs/e04-variants-proof.expected tests/fixtures/abtest/proofs/e05-checks-proof.expected | grep -vcE "^[a-z]+\(abt-u17b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- tests/abtest-fixtures.test.sh tests/validate.sh tests/fixtures/abtest/proofs`
   exit: 0
   stdout: empty
   mutation: skip edit 12; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-fixtures.test.sh (criterion 1 is the red-then-green check; the test and the pinned files do not exist at HEAD)
blast-radius: tests/validate.sh:1484
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: the scoped clean-tree check (the last criterion) passes at HEAD by design.
slow: one run of the test takes about 100 seconds (the forty-eight route proof alone is about a minute) and criteria 1 and 2 each run it; do not shorten it.
depends-on: abt-u17 (the abtest sections in validate.sh), abt-u08b, abt-u09b, abt-u10b and abt-u11c (the proof scripts and checks whose output is pinned) must have landed; edit 1 checks for them and STOPs otherwise. abt-u21a inserts its own section after the same blind section, in either order.
pinned-files: each .expected file is the exact stdout of its command at the finished abt-u08b to abt-u11c state, produced by running the command; if a line differs on your machine, STOP and report a spec gap, never edit a pinned file to match.
no-real-claude: nothing here runs the claude CLI; the proofs build throwaway repositories in temporary directories.
commit-message: test(abt-u17b): merge-gate test for the fixture proofs and verify-checks over E1-E5 (#615)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u17b (#615)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
