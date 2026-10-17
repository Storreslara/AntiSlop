Unit: abt-u09b

## Objective
E3 old-api-gone judges code, not lines: a comment (line, block over several lines, trailing) may name query( and a real call after a block comment, after a string with two slashes, or as a generator method is still found; comment-proof.sh resets each variant to a tag on the reference commit (no stacking) and prints nine variants and a stacked-variant count of 0; verify-checks still shows 2/5 and 0/5 for E3. One commit.

## Retrieval
GitHub issues: `gh issue view 612 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e03-rename-query/check.sh` (anchor: line matching `abt_check old-api-gone defect true`)
- `eval/abtest/checks/e03-rename-query/old-api.holdout.js` (anchor: new file)
- `eval/abtest/fixtures/e03-rename-query/comment-proof.sh` (anchor: line matching `commit -q -m reference`)

## Ordered edits
1. command: `test ! -e eval/abtest/checks/e03-rename-query/old-api.holdout.js && grep -c 'reset -q --hard HEAD' eval/abtest/fixtures/e03-rename-query/comment-proof.sh | grep -qx 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   anchor: line matching `commit -q -m reference`
   indent: 0
   insert-after:
~~~~
git -C "$T/w" tag reference
stacked=0
~~~~
3. file: `eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   anchor: line matching `reset -q --hard HEAD`
   before: `  git -C "$T/w" reset -q --hard HEAD`
   after: `  git -C "$T/w" reset -q --hard reference`
4. file: `eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   anchor: line matching `>> "$T/w/src/store.js"`
   before: `  printf '%s\n' "$line" >> "$T/w/src/store.js"`
   after: `  printf '%b\n' "$line" >> "$T/w/src/store.js"`
5. file: `eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   anchor: line matching `commit -q -m "variant $i"`
   indent: 0
   insert-after:
~~~~
  [ "$(git -C "$T/w" rev-parse HEAD~1)" = "$(git -C "$T/w" rev-parse reference)" ] || stacked=$((stacked + 1))
~~~~
6. file: `eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   anchor: line matching `a block comment line naming query(x)`
   indent: 0
   before:
~~~~
a line comment naming query(filterString)|// replaces query(filterString)
a block comment line naming query(x)| * query(x) is gone
a real call to store.query(x)|store.query(x);
VARIANTS
~~~~
   after:
~~~~
a line comment naming query(filterString)|// replaces query(filterString)
a block comment naming query(x)|/*\n * query(x) is gone\n */
an unstarred block comment body naming query(x)|/*\nold: query(x)\n*/
a trailing comment naming query(x)|module.exports.legacy = 1; // was query(x)
a real call to store.query(x)|store.query(x);
a real call after a block comment on one line|/* legacy */ store.query(x);
a real call after a block comment end|/*\nlegacy\n*/ store.query(x);
a generator method named query|class Legacy {\n  *query(f) { return f; }\n}
a real call after a string holding two slashes|const u = "http://x"; store.query(u);
VARIANTS
echo "variants stacked on another variant: $stacked"
~~~~
7. file: `eval/abtest/checks/e03-rename-query/old-api.holdout.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
// Usage: node old-api.holdout.js DIR...
// Prints "file:line: text" for every line of code that still calls query(, indexes ['query'] or builds
// a new Function, and exits 1 when it printed any. Comments are removed first (line comments, block
// comments over several lines, and trailing comments), so a comment may name the old API; strings are
// kept, so a "//" inside a string does not hide a call after it. Files that are not .js, .cjs or .mjs
// are read as plain text. Out of scope: a regular expression literal that holds a quote character.
const fs = require('node:fs');
const path = require('node:path');

const OLD = /\bquery\s*\(|\[.query.\]|new Function/;

function stripComments(src) {
  let out = '';
  let quote = '';
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    const d = src[i + 1];
    if (quote) {
      out += c;
      if (c === '\\') {
        out += d === undefined ? '' : d;
        i += 2;
        continue;
      }
      if (c === quote || (c === '\n' && quote !== '`')) quote = '';
      i += 1;
    } else if (c === '/' && d === '/') {
      while (i < src.length && src[i] !== '\n') i += 1;
    } else if (c === '/' && d === '*') {
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) {
        if (src[i] === '\n') out += '\n';
        i += 1;
      }
      i += 2;
      out += ' ';
    } else {
      if (c === '"' || c === "'" || c === '`') quote = c;
      out += c;
      i += 1;
    }
  }
  return out;
}

const hits = [];
function scan(file) {
  const raw = fs.readFileSync(file, 'utf8');
  const text = /\.(js|cjs|mjs)$/.test(file) ? stripComments(raw) : raw;
  text.split('\n').forEach((line, n) => {
    if (OLD.test(line)) hits.push(`${file}:${n + 1}: ${line.trim()}`);
  });
}
function walk(p) {
  if (!fs.existsSync(p)) return;
  if (fs.statSync(p).isDirectory()) {
    for (const name of fs.readdirSync(p).sort()) if (name !== 'node_modules') walk(path.join(p, name));
  } else {
    scan(p);
  }
}

process.argv.slice(2).forEach(walk);
if (hits.length > 0) {
  console.log(hits.join('\n'));
  process.exit(1);
}
~~~~
8. file: `eval/abtest/checks/e03-rename-query/check.sh`
   anchor: line matching `abt_check old-api-gone defect true`
   before: `abt_check old-api-gone defect true '! grep -rnE "\bquery\s*\(|\[.query.\]|new Function" src scripts test | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|/\*|\*)"'`
   after: `abt_check old-api-gone defect true 'node "$ABT_CHECKS_DIR/old-api.holdout.js" src scripts test'`
9. command: `git add eval/abtest/checks/e03-rename-query/check.sh eval/abtest/checks/e03-rename-query/old-api.holdout.js eval/abtest/fixtures/e03-rename-query/comment-proof.sh && git commit -m "fix(abt-u09b): E3 old-api-gone reads code instead of filtering lines, and the comment proof stops stacking variants (#612)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e03-rename-query/` files other than check.sh and the new script (the holdout tests and expected outputs do not change)
- `eval/abtest/fixtures/e03-rename-query/careless-proof.sh`, `build.sh`, `reference.patch` and `plant/` (the fixture and the reference stay as verified)
- `eval/abtest/checks/lib.sh` and `eval/abtest/verify-checks.sh` (the conventions do not change)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/fixtures/e03-rename-query/comment-proof.sh | grep ' pass$' | sed 's/^old-api-gone with //; s/: pass$//' | paste -sd';'`
   exit: 0
   stdout: `a line comment naming query(filterString);a block comment naming query(x);an unstarred block comment body naming query(x);a trailing comment naming query(x)`
   mutation: skip edit 8 (check.sh); the old filter fails the unstarred block body and the trailing comment and passes three real calls, so the list is different (five entries).
2. run: `bash eval/abtest/fixtures/e03-rename-query/comment-proof.sh | grep ' fail$' | sed 's/^old-api-gone with //; s/: fail$//' | paste -sd';'`
   exit: 0
   stdout: `a real call to store.query(x);a real call after a block comment on one line;a real call after a block comment end;a generator method named query;a real call after a string holding two slashes`
   mutation: skip edit 8; the old filter lets three of these real calls through, so the list is shorter.
3. run: `bash eval/abtest/fixtures/e03-rename-query/comment-proof.sh | grep -c 'variants stacked on another variant: 0$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (reset to the reference tag); each variant starts from the previous one, the line reads 8 and stdout is 0 (exit 1).
4. run: `bash eval/abtest/verify-checks.sh e03-rename-query`
   exit: 0
   stdout: `verify: e03-rename-query baseline-required-failures=2/5 reference-required-failures=0/5`
   mutation: skip edit 7 (the new script); node cannot load it, old-api-gone fails on the reference and the line reads reference-required-failures=1/5.
5. run: `node --check eval/abtest/checks/e03-rename-query/old-api.holdout.js && echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: skip edit 7; node exits 1 on the missing file and nothing prints.
6. run: `bash eval/abtest/verify-checks.sh --all | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 7; the E3 reference fails old-api-gone and the last line reads verify-checks: FAILED.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e03-rename-query/check.sh eval/abtest/checks/e03-rename-query/old-api.holdout.js eval/abtest/fixtures/e03-rename-query/comment-proof.sh`
   mutation: skip edit 9 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e03-rename-query/check.sh eval/abtest/checks/e03-rename-query/old-api.holdout.js eval/abtest/fixtures/e03-rename-query/comment-proof.sh | grep -vcE "^[a-z]+\(abt-u09b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/checks/e03-rename-query eval/abtest/fixtures/e03-rename-query`
   exit: 0
   stdout: empty
   mutation: skip edit 9; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no hidden-check configuration; criteria 1 to 3 compare the proof output and are red at HEAD (the stacked count line is absent and the lists differ)
blast-radius: eval/abtest/checks/lib.sh:59
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criteria 4 and 6 pass at HEAD (E3 verifies today) and stay green with the finished change; the scoped clean-tree check (the last criterion) passes at HEAD by design.
tokenizer: old-api.holdout.js removes comments with a small state machine (line comments, block comments over several lines, trailing comments) and keeps strings, so a double slash inside a string does not hide a later call; a regular expression literal that holds a quote character is out of scope. It reports the same six lines as the old grep on the baseline.
proof-format: each variant is a label, a bar and the text appended to src/store.js; the two characters backslash n inside the text become a line break (printf %b), so a multi-line comment is one variant.
no-real-claude: nothing here runs the claude CLI.
commit-message: fix(abt-u09b): E3 old-api-gone reads code instead of filtering lines, and the comment proof stops stacking variants (#612)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u09b (#612)
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
