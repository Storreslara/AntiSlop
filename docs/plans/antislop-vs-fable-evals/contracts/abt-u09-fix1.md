Unit: abt-u09

## Objective
The E3 `old-api-gone` check ignores comment-only lines (a correct solution that leaves a comment naming `query(` no longer fails it) while a real `store.query(` call still fails; a new `comment-proof.sh` shows both. The stated output of `careless-proof.sh` is corrected to its three lines (the script itself is unchanged and correct). One commit.

## Retrieval
GitHub issues: `gh issue view 577 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e03-rename-query/check.sh` (anchor: line matching `abt_check old-api-gone defect true`)
- `eval/abtest/fixtures/e03-rename-query/comment-proof.sh` (anchor: new file)

## Ordered edits
1. command: `test -f eval/abtest/fixtures/e03-rename-query/careless-proof.sh && test ! -e eval/abtest/fixtures/e03-rename-query/comment-proof.sh && test "$(grep -cF 'src scripts test'"'"'' eval/abtest/checks/e03-rename-query/check.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e03-rename-query/check.sh`
   anchor: line matching `abt_check old-api-gone defect true`
   before: `abt_check old-api-gone defect true '! grep -rnE "\bquery\s*\(|\[.query.\]|new Function" src scripts test'`
   after: `abt_check old-api-gone defect true '! grep -rnE "\bquery\s*\(|\[.query.\]|new Function" src scripts test | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|/\*|\*)"'`
3. file: `eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Shows the E3 old-api-gone check ignores a comment line that names the old API and still
# catches a real call: the reference solution plus one appended line in src/store.js.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
git -C "$T/w" apply --recount "$HERE/reference.patch"
git -C "$T/w" add -A
git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
i=0
while IFS='|' read -r label line; do
  i=$((i + 1))
  git -C "$T/w" reset -q --hard HEAD
  printf '%s\n' "$line" >> "$T/w/src/store.js"
  git -C "$T/w" add -A
  git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "variant $i"
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e03-rename-query/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};print("old-api-gone with", sys.argv[2] + ":", "pass" if c["old-api-gone"] else "fail")' "$json" "$label"
done <<'VARIANTS'
a line comment naming query(filterString)|// replaces query(filterString)
a block comment line naming query(x)| * query(x) is gone
a real call to store.query(x)|store.query(x);
VARIANTS
~~~~
4. command: `chmod 755 eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   expect: 0
5. command: `git add eval/abtest/checks/e03-rename-query/check.sh eval/abtest/fixtures/e03-rename-query/comment-proof.sh && git commit -m "fix(abt-u09): old-api-gone ignores comment-only lines; careless-proof prints three lines (#577)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/fixtures/e03-rename-query/careless-proof.sh` (correct as it is; its three-line output is now the stated criterion)
- `eval/abtest/fixtures/e03-rename-query/reference.patch`, `eval/abtest/fixtures/e03-rename-query/build.sh`, `eval/abtest/fixtures/e03-rename-query/plant/` (the baseline and reference stay byte-identical)
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/verify-checks.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `docs/plans/` (never edit a plan or contract by hand; this fix contract supersedes criterion 8 of `abt-u09.md`)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)

## Acceptance criteria
1. run: `bash eval/abtest/fixtures/e03-rename-query/careless-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `owner-isolation-preserved on careless rename: fail|where-works on careless rename: pass|behaviour-unchanged on careless rename: fail`
   mutation: delete the `sed -i` line of careless-proof.sh in a scratch copy; the script prints a "still there" message to stderr, stdout is empty.
   proof: scratch run with the `sed -i` line deleted printed an empty line to stdout (exit 1 inside the pipe). This row corrects criterion 8 of `abt-u09.md` (three lines, not one) and already passes at HEAD because careless-proof.sh is unchanged.
2. run: `bash eval/abtest/fixtures/e03-rename-query/comment-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `old-api-gone with a line comment naming query(filterString): pass|old-api-gone with a block comment line naming query(x): pass|old-api-gone with a real call to store.query(x): fail`
   mutation: skip edit 2 (check.sh); the two comment variants print fail.
   proof: scratch run with the unchanged check.sh printed fail for all three variants.
3. run: `bash eval/abtest/verify-checks.sh e03-rename-query | grep -c 'baseline-required-failures=2/5 reference-required-failures=0/5'`
   exit: 0
   stdout: `1`
   mutation: edit 2 with the filter changed to `grep -vE "."`; the pipeline always passes, the baseline reads 1/5 and the count is 0.
   proof: scratch run with that filter printed baseline-required-failures=1/5 reference-required-failures=0/5.
4. run: `grep -cF 'grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|/\*|\*)"' eval/abtest/checks/e03-rename-query/check.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout 0, exit 1.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e03-rename-query/check.sh eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   mutation: skip edit 5 (the commit); the newest abt-u09 commit is the original and the list names its 15 files.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the newest abt-u09 commit is the original, whose stdout is also 1, so this row alone does not prove edit 5 (criterion 5 does).
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e03-rename-query/check.sh eval/abtest/fixtures/e03-rename-query/comment-proof.sh eval/abtest/fixtures/e03-rename-query/careless-proof.sh eval/abtest/fixtures/e03-rename-query/reference.patch | grep -vcE "^[a-z]+\(abt-u09\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/fixtures/e03-rename-query eval/abtest/checks/e03-rename-query`
   exit: 0
   stdout: empty
   mutation: skip edit 5; check.sh stays modified and comment-proof.sh untracked, both listed.

## Pre-resolved context
tdd: no fixture and check files; criterion 2 is red-then-green (the comment variants fail on the unchanged check.sh)
blast-radius: eval/abtest/checks/e03-rename-query/check.sh:8
fix-of: 2026-10-17T07:42:43Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. Inline-code payloads are literal.
why: the FAIL found criterion 8 of abt-u09 stating one output line while careless-proof.sh (correctly) prints three; the reviewer also noted old-api-gone greps comments, so a correct solution leaving a comment naming query( would fail it.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u09): old-api-gone ignores comment-only lines; careless-proof prints three lines (#577)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u09 (#577)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
