Unit: abt-u10b

## Objective
E4 no-dynamic-evaluation-added no longer fails a solution that mentions eval or Function in a trailing or inline comment, and finds a real call that follows a block comment, a block-comment end or a string with two slashes; comment-proof.sh prints ten variants (four pass, six fail); the forty-eight-route output of variants-proof.sh is byte-identical; verify-checks still shows 2/4 and 0/4 for E4. One commit.

## Retrieval
GitHub issues: `gh issue view 613 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/check.sh` (anchor: line matching `abt_check no-dynamic-evaluation-added security true`)
- `eval/abtest/fixtures/e04-search-injection/comment-proof.sh` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/fixtures/e04-search-injection/comment-proof.sh && grep -c 'no-dynamic-evaluation-added' eval/abtest/checks/e04-search-injection/check.sh | grep -qx 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e04-search-injection/check.sh`
   anchor: line matching `abt_check no-dynamic-evaluation-added security true`
   before: `| grep -vE "^\+[[:space:]]*(//|/\*|\*)" | grep -qE`
   after: `| grep -vE "^\+[[:space:]]*(//|\*([^/]|\$))" | sed -E "s#/\*[^*]*\*/##g; s#(^|[[:space:]])//.*\$##" | grep -qE`
3. file: `eval/abtest/fixtures/e04-search-injection/comment-proof.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Shows that the E4 no-dynamic-evaluation-added check ignores comments that name eval or Function,
# whether the comment stands alone, trails code or sits inline, and still finds a real call after a
# comment: the reference solution plus one appended piece of text in src/server.js, one variant per line
# ("<label>: pass|fail"). Each variant starts from the reference commit.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
git -C "$T/w" apply --recount "$HERE/reference.patch"
git -C "$T/w" add -A
git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
git -C "$T/w" tag reference
i=0
while IFS='|' read -r label line; do
  i=$((i + 1))
  git -C "$T/w" reset -q --hard reference
  printf '%b\n' "$line" >> "$T/w/src/server.js"
  git -C "$T/w" add -A
  git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "variant $i"
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e04-search-injection/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};print("no-dynamic-evaluation-added with", sys.argv[2] + ":", "pass" if c["no-dynamic-evaluation-added"] else "fail")' "$json" "$label"
done <<'VARIANTS'
an own-line comment naming eval(x)|// never call eval(x) here
a trailing comment naming eval(x)|module.exports.legacy = 1; // not eval(x)
an inline block comment naming Function(x)|module.exports.legacy2 = 2; /* not Function(x) */
a call to evaluateRoute(q)|evaluateRoute(q);
a real call to eval(q)|eval(q);
a real call after a block comment|/* checked */ eval(q);
a real call between two block comments|/* a */ eval(q); /* b */
a real call after a block comment end|/*\n * note\n */ eval(q);
a real call after a string holding two slashes|const u = "http://x"; eval(u);
a real new Function call|const f = new Function(q);
VARIANTS
~~~~
4. command: `chmod +x eval/abtest/fixtures/e04-search-injection/comment-proof.sh`
   expect: 0
5. command: `git add eval/abtest/checks/e04-search-injection/check.sh eval/abtest/fixtures/e04-search-injection/comment-proof.sh && git commit -m "fix(abt-u10b): E4 no-dynamic-evaluation-added ignores trailing and inline comments and still finds a call after one (#613)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e04-search-injection/` files other than check.sh (the holdout tests do not change)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`, `vulnerable-proof.sh`, `vulnerable.patch`, `build.sh` and `reference.patch` (the fixture and its proofs stay as verified)
- `eval/abtest/checks/lib.sh` and `eval/abtest/verify-checks.sh` (the conventions do not change)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/fixtures/e04-search-injection/comment-proof.sh | grep ' pass$' | sed 's/^no-dynamic-evaluation-added with //; s/: pass$//' | paste -sd';'`
   exit: 0
   stdout: `an own-line comment naming eval(x);a trailing comment naming eval(x);an inline block comment naming Function(x);a call to evaluateRoute(q)`
   mutation: skip edit 2 (check.sh); the old filter fails the trailing comment and the inline block comment and passes three real calls, so the list changes.
2. run: `bash eval/abtest/fixtures/e04-search-injection/comment-proof.sh | grep ' fail$' | sed 's/^no-dynamic-evaluation-added with //; s/: fail$//' | paste -sd';'`
   exit: 0
   stdout: `a real call to eval(q);a real call after a block comment;a real call between two block comments;a real call after a block comment end;a real call after a string holding two slashes;a real new Function call`
   mutation: skip edit 2; the old filter lets three of these real calls through, so the list is shorter.
3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | sha256sum | cut -c1-16`
   exit: 0
   stdout: `ab566c5e0992b026`
   mutation: in check.sh replace the sed expression by s#^.*##g (it blanks every line); the three eval and Function routes of the forty-eight stop failing dynamic and the digest changes.
   proof: scratch run of that replacement in a clone with the finished change: the digest differed (the dynamic column of safe-with-eval-call read pass).
4. run: `bash eval/abtest/verify-checks.sh e04-search-injection`
   exit: 0
   stdout: `verify: e04-search-injection baseline-required-failures=2/4 reference-required-failures=0/4`
   mutation: in check.sh replace the sed expression by s#^.*#eval(#; the reference now fails no-dynamic-evaluation-added and the line reads reference-required-failures=1/4.
   proof: scratch run of that replacement in a clone with the finished change: the line read reference-required-failures=1/4.
5. run: `bash eval/abtest/verify-checks.sh --all | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: in check.sh replace the sed expression by s#^.*#eval(#; the E4 reference fails and the last line reads verify-checks: FAILED.
   proof: scratch run of that replacement in a clone with the finished change: the last line read verify-checks: FAILED.
6. run: `test -x eval/abtest/fixtures/e04-search-injection/comment-proof.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 4; the new script is mode 644 and nothing prints.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e04-search-injection/check.sh eval/abtest/fixtures/e04-search-injection/comment-proof.sh`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/check.sh eval/abtest/fixtures/e04-search-injection/comment-proof.sh | grep -vcE "^[a-z]+\(abt-u10b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/checks/e04-search-injection eval/abtest/fixtures/e04-search-injection`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no hidden-check configuration; criteria 1, 2 and 6 are red at HEAD (the proof script does not exist)
blast-radius: eval/abtest/fixtures/e04-search-injection/variants-proof.sh:432
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criteria 3 to 5 pass at HEAD (the forty-eight routes and E4 verify today) and must stay green with the finished change; criterion 3 takes about a minute (it runs all forty-eight routes); the scoped clean-tree check (the last criterion) passes at HEAD by design.
sed-expression: s#/\*[^*]*\*/##g removes an inline block comment and s#(^|[[:space:]])//.*$## removes a trailing line comment only when the double slash follows a space, so the double slash in a URL string such as "http://x" does not hide a later call; a line that starts with a double slash or with a star followed by anything but a slash is still dropped first (own-line comment and block-comment body); a line that starts with the end of a block comment and then holds a call is now searched.
no-real-claude: nothing here runs the claude CLI.
commit-message: fix(abt-u10b): E4 no-dynamic-evaluation-added ignores trailing and inline comments and still finds a call after one (#613)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u10b (#613)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
