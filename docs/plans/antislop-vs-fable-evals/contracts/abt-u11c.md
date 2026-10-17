Unit: abt-u11c

## Objective
The E5 migration check restores data/dump-v1.json from the baseline before it runs (an arm cannot change the dump it reads), readme-tags-route accepts the route and refuses a README that only names a test file, readme-data-format-v2 accepts a version 2 note and refuses "Node version 20", checks-proof.sh prints one line per case and verify-checks still shows 6/8 and 0/8 for E5. One commit.

## Retrieval
GitHub issues: `gh issue view 611 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e05-tags-feature/check.sh` (anchor: line matching `abt_check migration defect true`)
- `eval/abtest/fixtures/e05-tags-feature/checks-proof.sh` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/fixtures/e05-tags-feature/checks-proof.sh && grep -c 'grep -q "/tags" README.md' eval/abtest/checks/e05-tags-feature/check.sh | grep -qx 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e05-tags-feature/check.sh`
   anchor: line matching `abt_check migration defect true`
   before: `migration.holdout.test.js migration.holdout.test.js)"`
   after: `migration.holdout.test.js migration.holdout.test.js)" data/dump-v1.json`
3. file: `eval/abtest/checks/e05-tags-feature/check.sh`
   anchor: line matching `abt_check readme-tags-route defect true`
   before: `'grep -q "/tags" README.md'`
   after: `'grep -qE "/tags([^[:alnum:]_.-]|\.([^[:alnum:]]|\$)|\$)" README.md'`
4. file: `eval/abtest/checks/e05-tags-feature/check.sh`
   anchor: line matching `abt_check readme-data-format-v2 docs false`
   before: `'grep -qi "version.*2" README.md'`
   after: `'grep -qiE "version\"?:? *2([^0-9]|\$)" README.md'`
5. file: `eval/abtest/fixtures/e05-tags-feature/checks-proof.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Shows three properties of the E5 hidden checks on the reference solution, one line per case
# ("<case>: <check> pass|fail"): the migration check does not read a dump the arm changed;
# readme-tags-route needs the route, not the name of a test file; and
# readme-data-format-v2 needs a version 2 note, not the words "Node version 20".
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
G=(git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid)
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
for p in "$HERE"/reference.d/*.patch; do
  "${G[@]}" apply --recount "$p"
  "${G[@]}" add -A
  "${G[@]}" commit -q -m reference
done
"${G[@]}" tag reference
show() {
  local label="$1" json
  shift
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e05-tags-feature/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};[print(sys.argv[2] + ":", k, "pass" if c[k] else "fail") for k in sys.argv[3:]]' "$json" "$label" "$@"
}
variant() {
  "${G[@]}" reset -q --hard reference
  "$@"
  "${G[@]}" add -A
  "${G[@]}" commit -q --allow-empty -m variant
}
noop_migrate() { printf '%s\n' "require('node:fs').copyFileSync(process.argv[2], process.argv[3]);" > "$T/w/scripts/migrate-v1.js"; }
tamper() { noop_migrate; empty_dump; }
empty_dump() { printf '%s\n' '{"version": 2, "notes": []}' > "$T/w/data/dump-v1.json"; }
readme_edit() { python3 -I -c 'import sys;p=sys.argv[1];s=open(p).read();exec(sys.argv[2]);open(p,"w").write(s)' "$T/w/README.md" "$1"; }
variant true
show "the reference" migration readme-tags-route readme-data-format-v2
variant tamper
show "a no-op migrate script and an emptied v2 dump" migration
variant noop_migrate
show "a no-op migrate script and the original dump" migration
variant readme_edit 's="\n".join(l for l in s.split("\n") if "/tags" not in l)+"\n| test | test/tags.test.js |\nTests: test/tags-counts.test.js\n"'
show "a README that names the route only through a test file" readme-tags-route
variant readme_edit 's="\n".join(l for l in s.split("\n") if "/tags" not in l)+"\nTry: curl localhost:3000/tags\n"'
show "a README that shows the route in a curl example" readme-tags-route
variant readme_edit 's=s[:s.index("## Data format v2")]+"Runs on Node version 20.\n"'
show "a README that says Node version 20" readme-data-format-v2
~~~~
6. command: `chmod +x eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/fixtures/e05-tags-feature/checks-proof.sh`
   expect: 0
7. command: `git add eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/fixtures/e05-tags-feature/checks-proof.sh && git commit -m "fix(abt-u11c): E5 migration check restores the dump, the route check wants the route, the v2 check wants version 2 (#611)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e05-tags-feature/` holdout files other than check.sh (the tests are not changed)
- `eval/abtest/checks/lib.sh` (abt_check already restores every path listed after the command)
- `eval/abtest/fixtures/e05-tags-feature/build.sh`, `reference.d/` and `plant/` (the reference stays as verified; its constructor-slug and duplicate-tag behaviour is a recorded limitation)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/fixtures/e05-tags-feature/checks-proof.sh | grep -c '^a no-op migrate script and an emptied v2 dump: migration fail$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2 (the restore path); the arm-edited dump is read, the line reads migration pass and stdout is 0 (exit 1).
2. run: `bash eval/abtest/fixtures/e05-tags-feature/checks-proof.sh | grep -c '^a README that names the route only through a test file: readme-tags-route fail$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the route pattern); the old grep accepts a test file name, the line reads pass and stdout is 0 (exit 1).
3. run: `bash eval/abtest/fixtures/e05-tags-feature/checks-proof.sh | grep -c '^a README that says Node version 20: readme-data-format-v2 fail$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the version pattern); the old grep accepts Node version 20, the line reads pass and stdout is 0 (exit 1).
4. run: `bash eval/abtest/fixtures/e05-tags-feature/checks-proof.sh | grep -c '^a README that shows the route in a curl example: readme-tags-route pass$'`
   exit: 0
   stdout: `1`
   mutation: replace the route pattern in check.sh by grep -qE "^[|][^|]*[|][^|]*/tags" README.md (a table-row-only pattern); the curl-example control stops passing and stdout is 0 (exit 1).
   proof: scratch run of that replacement in a clone with the finished change: the curl line read readme-tags-route fail, stdout 0 (exit 1).
5. run: `bash eval/abtest/verify-checks.sh e05-tags-feature`
   exit: 0
   stdout: `verify: e05-tags-feature baseline-required-failures=6/8 reference-required-failures=0/8`
   mutation: replace the route pattern in check.sh by grep -qE "^x" README.md; the reference now fails readme-tags-route and the line reads reference-required-failures=1/8.
   proof: scratch run of that replacement in a clone with the finished change: the line read reference-required-failures=1/8.
6. run: `test -x eval/abtest/checks/e05-tags-feature/check.sh && test -x eval/abtest/fixtures/e05-tags-feature/checks-proof.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 6; check.sh is mode 644 and the new script is not executable, nothing prints.
7. run: `git ls-files -s eval/abtest/checks/e05-tags-feature/check.sh | cut -c1-6`
   exit: 0
   stdout: `100755`
   mutation: skip edit 7 (the commit); the index still holds 100644.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/fixtures/e05-tags-feature/checks-proof.sh`
   mutation: skip edit 7 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/fixtures/e05-tags-feature/checks-proof.sh | grep -vcE "^[a-z]+\(abt-u11c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/checks/e05-tags-feature eval/abtest/fixtures/e05-tags-feature`
   exit: 0
   stdout: empty
   mutation: skip edit 7; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no hidden-check configuration; criteria 1 to 3 are red at HEAD (the proof script does not exist) and in the skip-edit builds they go red on the proof lines
blast-radius: eval/abtest/checks/lib.sh:59
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 5 passes at HEAD (E5 verifies today) and stays green with the finished change; the criteria that read the unit commit are red until the commit step runs, and the scoped clean-tree check (the last criterion) passes at HEAD by design.
route-pattern: the route pattern accepts a route written in a table row, a curl example or prose, and refuses a file name such as test/tags.test.js (the slash is followed by tags and then a dot and a letter, a hyphen, a digit or a letter). A table-row-only pattern was rejected on purpose: it would fail an arm that documents the route in prose, which is a measurement error on a required check.
version-pattern: version"?:? *2 followed by a non-digit or the end of the line; the reviewer suggestion without the trailing non-digit still matches Node version 20.
no-real-claude: nothing here runs the claude CLI.
commit-message: fix(abt-u11c): E5 migration check restores the dump, the route check wants the route, the v2 check wants version 2 (#611)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u11c (#611)
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
