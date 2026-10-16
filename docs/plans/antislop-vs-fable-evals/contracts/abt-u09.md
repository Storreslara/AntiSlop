Unit: abt-u09

## Objective
The E3 eval exists: fixture e03-rename-query (template T2 plus a query-calling test helper), the rename prompt, required checks (behaviour unchanged against committed baseline outputs, store.where works and query is gone, old-API grep, scope) and a reference solution; bash eval/abtest/verify-checks.sh e03-rename-query prints verify-checks: ok. One commit.

## Retrieval
GitHub issues: `gh issue view 577 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/e03-rename-query/build.sh` (anchor: new file)
- `eval/abtest/fixtures/e03-rename-query/plant/test/helpers.js` (anchor: new file)
- `eval/abtest/fixtures/e03-rename-query/plant/test/helpers-a.test.js` (anchor: new file)
- `eval/abtest/fixtures/e03-rename-query/plant/test/helpers-b.test.js` (anchor: new file)
- `eval/abtest/fixtures/e03-rename-query/allowed-paths.txt` (anchor: new file)
- `eval/abtest/fixtures/e03-rename-query/reference.patch` (anchor: new file)
- `eval/abtest/tasks/e03-rename-query.prompt.md` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/check.sh` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/seed.json` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/expected-cli.txt` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/expected-cli-all.txt` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/expected-export.txt` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/http.holdout.test.js` (anchor: new file)
- `eval/abtest/checks/e03-rename-query/where.holdout.test.js` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/fixtures/e03-rename-query && test ! -e eval/abtest/checks/e03-rename-query && test -f eval/abtest/verify-checks.sh && test -f eval/abtest/templates/notes-svc/scripts/export.js && test "$(grep -cF 'Object.hasOwn(USERS' eval/abtest/templates/notes-svc/src/auth.js)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/e03-rename-query/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E3 fixture: template T2 (notes-svc) plus a shared test helper that calls
# store.query, used by two more test files. Usage: build.sh DEST.
# Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/abtest/templates/notes-svc/." "$dest/"
cp -r "$HERE/plant/." "$dest/"
abt_fixture_baseline "$dest"
~~~~
3. file: `eval/abtest/fixtures/e03-rename-query/plant/test/helpers.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

// Shared test helper: find notes by exact title through the store's filter.
function findByTitle(store, title) {
  return store.query(`note.title === ${JSON.stringify(title)}`);
}

module.exports = { findByTitle };
~~~~
4. file: `eval/abtest/fixtures/e03-rename-query/plant/test/helpers-a.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');
const { findByTitle } = require('./helpers');

test('findByTitle returns every note with that title', () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'dup' });
  store.add({ owner: 'bob', title: 'dup' });
  store.add({ owner: 'bob', title: 'other' });
  assert.equal(findByTitle(store, 'dup').length, 2);
});
~~~~
5. file: `eval/abtest/fixtures/e03-rename-query/plant/test/helpers-b.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');
const { findByTitle } = require('./helpers');

test('findByTitle returns nothing for an unknown title', () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'only' });
  assert.deepEqual(findByTitle(store, 'missing'), []);
});
~~~~
6. file: `eval/abtest/fixtures/e03-rename-query/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
src/store.js
src/server.js
src/cli.js
scripts/export.js
test
~~~~
7. file: `eval/abtest/fixtures/e03-rename-query/reference.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/scripts/export.js b/scripts/export.js
index 6a12326..313c650 100644
--- a/scripts/export.js
+++ b/scripts/export.js
@@ -8,6 +8,6 @@ const { date } = require('../src/format');
 
 const store = createStore();
 if (process.env.NOTES_SEED) loadSeed(store, process.env.NOTES_SEED);
-const fn = 'query';
-const rows = store[fn]('true');
+const fn = 'where';
+const rows = store[fn](() => true);
 console.log(JSON.stringify(rows.map((n) => ({ id: n.id, title: n.title, date: date(n.createdAt) }))));
diff --git a/src/cli.js b/src/cli.js
index dc5d91e..e4b3379 100644
--- a/src/cli.js
+++ b/src/cli.js
@@ -16,7 +16,7 @@ function main(argv) {
     return 2;
   }
   const rows = flag === '--title'
-    ? store.query(`note.title === ${JSON.stringify(value)}`)
+    ? store.where((n) => n.title === value)
     : store.list({}).items;
   for (const n of rows) console.log(`${n.id}\t${n.owner}\t${date(n.createdAt)}\t${n.title}`);
   return 0;
diff --git a/src/server.js b/src/server.js
index 6d68217..e6131e7 100644
--- a/src/server.js
+++ b/src/server.js
@@ -28,8 +28,8 @@ function createServer(store = createStore()) {
       if (req.method === 'GET' && url.pathname === '/notes') {
         const title = url.searchParams.get('title');
         if (title !== null) {
-          const filter = `note.owner === ${JSON.stringify(user)} && note.title === ${JSON.stringify(title)}`;
-          return send(res, 200, { items: store.query(filter), next: null });
+          const items = store.where((n) => n.owner === user && n.title === title);
+          return send(res, 200, { items, next: null });
         }
         const limit = Number(url.searchParams.get('limit')) || 50;
         const cursor = url.searchParams.get('cursor');
diff --git a/src/store.js b/src/store.js
index 88575da..05b13ef 100644
--- a/src/store.js
+++ b/src/store.js
@@ -43,15 +43,12 @@ function createStore() {
     return { items, next };
   }
 
-  // Filter notes with a JavaScript expression over `note`, for example
-  // 'note.title === "x"'. The string is compiled, so callers must build it
-  // with JSON.stringify for every value they interpolate.
-  function query(filterString) {
-    const predicate = new Function('note', `return (${filterString});`);
+  // Keep the notes a predicate function accepts.
+  function where(predicate) {
     return all().filter((n) => predicate(n));
   }
 
-  return { add, get, remove, list, query };
+  return { add, get, remove, list, where };
 }
 
 module.exports = { createStore };
diff --git a/test/helpers.js b/test/helpers.js
index b58a239..4565e88 100644
--- a/test/helpers.js
+++ b/test/helpers.js
@@ -1,8 +1,8 @@
 'use strict';
 
-// Shared test helper: find notes by exact title through the store's filter.
+// Shared test helper: find notes by exact title through the store's predicate filter.
 function findByTitle(store, title) {
-  return store.query(`note.title === ${JSON.stringify(title)}`);
+  return store.where((n) => n.title === title);
~~~~
8. file: `eval/abtest/fixtures/e03-rename-query/reference.patch`
   anchor: line matching `+  return store.where((n) => n.title === title);`
   indent: 0
   insert-after:
~~~~
 }
 
 module.exports = { findByTitle };
diff --git a/test/store.test.js b/test/store.test.js
index 0c19315..df1342d 100644
--- a/test/store.test.js
+++ b/test/store.test.js
@@ -27,9 +27,9 @@ test('list returns only the owner notes, paged by cursor', () => {
   assert.equal(second.next, null);
 });
 
-test('query filters with an expression over note', () => {
+test('where filters with a predicate over note', () => {
   const store = seeded();
-  const rows = store.query(`note.title === ${JSON.stringify('three')}`);
+  const rows = store.where((n) => n.title === 'three');
   assert.deepEqual(rows.map((n) => n.owner), ['bob']);
 });
 
~~~~
9. file: `eval/abtest/tasks/e03-rename-query.prompt.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
Refactor: replace `store.query(filterString)` with
`store.where(predicate)`, where `predicate` is a function
`(note) => boolean`. Remove the string-based query entirely and update
every caller in the repository so behaviour is unchanged. Keep the
public CLI and HTTP behaviour identical. Run `npm test` before you
finish.
~~~~
10. file: `eval/abtest/checks/e03-rename-query/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E3 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check behaviour-unchanged defect true 'export NOTES_SEED="$ABT_CHECKS_DIR/seed.json"; node src/cli.js list --title foo | diff - "$ABT_CHECKS_DIR/expected-cli.txt" && node src/cli.js list | diff - "$ABT_CHECKS_DIR/expected-cli-all.txt" && node scripts/export.js | diff - "$ABT_CHECKS_DIR/expected-export.txt" && cp "$ABT_CHECKS_DIR/http.holdout.test.js" test/ && node --test test/http.holdout.test.js'
abt_check where-works defect true 'cp "$ABT_CHECKS_DIR/where.holdout.test.js" test/ && node --test test/where.holdout.test.js'
abt_check old-api-gone defect true '! grep -rnE "\bquery\s*\(|\[.query.\]|new Function" src scripts test'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
11. file: `eval/abtest/checks/e03-rename-query/seed.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
[
  { "owner": "alice", "title": "foo", "body": "first" },
  { "owner": "bob", "title": "bar", "body": "second" },
  { "owner": "alice", "title": "foo2", "body": "third" },
  { "owner": "bob", "title": "foo", "body": "fourth" }
]
~~~~
12. file: `eval/abtest/checks/e03-rename-query/expected-cli.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
n1	alice	2023-11-14	foo
n4	bob	2023-11-14	foo
~~~~
13. file: `eval/abtest/checks/e03-rename-query/expected-cli-all.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
n1	alice	2023-11-14	foo
n2	bob	2023-11-14	bar
n3	alice	2023-11-14	foo2
n4	bob	2023-11-14	foo
~~~~
14. file: `eval/abtest/checks/e03-rename-query/expected-export.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
[{"id":"n1","title":"foo","date":"2023-11-14"},{"id":"n2","title":"bar","date":"2023-11-14"},{"id":"n3","title":"foo2","date":"2023-11-14"},{"id":"n4","title":"foo","date":"2023-11-14"}]
~~~~
15. file: `eval/abtest/checks/e03-rename-query/http.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

test('[holdout] GET /notes?title= still returns only the caller notes with that title', async () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'foo' });
  store.add({ owner: 'bob', title: 'foo' });
  store.add({ owner: 'alice', title: 'bar' });
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}/notes?title=foo`;
    const res = await fetch(url, { headers: { authorization: 'Bearer tok-alice' } });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body.items.map((n) => `${n.owner}:${n.title}`), ['alice:foo']);
    assert.equal(body.next, null);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
~~~~
16. file: `eval/abtest/checks/e03-rename-query/where.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');

function seeded() {
  const store = createStore();
  store.add({ owner: 'alice', title: 'x' });
  store.add({ owner: 'bob', title: 'x' });
  store.add({ owner: 'alice', title: 'y' });
  return store;
}

test('[holdout] where keeps the notes the predicate accepts', () => {
  const rows = seeded().where((n) => n.title === 'x');
  assert.deepEqual(rows.map((n) => n.id), ['n1', 'n2']);
});

test('[holdout] where accepts a closure over outside values', () => {
  const owner = 'alice';
  const rows = seeded().where((n) => n.owner === owner);
  assert.deepEqual(rows.map((n) => n.title), ['x', 'y']);
});

test('[holdout] where with an always-false predicate returns an empty list', () => {
  assert.deepEqual(seeded().where(() => false), []);
});

test('[holdout] the string-based query is gone', () => {
  assert.equal(typeof seeded().query, 'undefined');
});
~~~~
17. command: `git add eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e03-rename-query/plant/test/helpers.js eval/abtest/fixtures/e03-rename-query/plant/test/helpers-a.test.js eval/abtest/fixtures/e03-rename-query/plant/test/helpers-b.test.js eval/abtest/fixtures/e03-rename-query/allowed-paths.txt eval/abtest/fixtures/e03-rename-query/reference.patch eval/abtest/tasks/e03-rename-query.prompt.md eval/abtest/checks/e03-rename-query/check.sh eval/abtest/checks/e03-rename-query/seed.json eval/abtest/checks/e03-rename-query/expected-cli.txt eval/abtest/checks/e03-rename-query/expected-cli-all.txt eval/abtest/checks/e03-rename-query/expected-export.txt eval/abtest/checks/e03-rename-query/http.holdout.test.js eval/abtest/checks/e03-rename-query/where.holdout.test.js && git commit -m "feat(abt-u09): E3 rename-query fixture, prompt, checks and reference (#577)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/fixtures/` (templates stay untouched; this unit adds files beside them)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/templates/` (other units own them)
- `eval/abtest/templates/` (the template is read by build.sh and never edited here)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e03-rename-query`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 8 (reference.patch); verify reports reference failures, prints FAILED and exits 1.
2. run: `grep -ciE 'reviewer|spec-master|persona|holdout|hidden' eval/abtest/tasks/e03-rename-query.prompt.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 9 (the prompt); grep exits 2 on the missing file and prints nothing.
   proof: scratch run: a prompt containing the word hidden printed 1 with exit 0.
3. run: `sha256sum eval/abtest/tasks/e03-rename-query.prompt.md | cut -c1-16`
   exit: 0
   stdout: `f6d3810a1d69f3d9`
   mutation: skip edit 9; sha256sum fails on the missing file and prints nothing.
4. run: `ls eval/abtest/checks/e03-rename-query | paste -sd" "`
   exit: 0
   stdout: `check.sh expected-cli-all.txt expected-cli.txt expected-export.txt http.holdout.test.js seed.json where.holdout.test.js`
   mutation: skip edit 10 (check.sh); the listing lacks check.sh.
5. run: `grep -c 'store.query' eval/abtest/fixtures/e03-rename-query/plant/test/helpers.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (helpers.js); grep exits 2 on the missing file and prints nothing.
6. run: `wc -l < eval/abtest/checks/e03-rename-query/expected-cli.txt`
   exit: 0
   stdout: `2`
   mutation: skip edit 12 (expected-cli.txt); the shell reports no such file, the exit is 1 and nothing prints.
7. run: `ls eval/abtest/fixtures/e03-rename-query/plant/test | paste -sd" "`
   exit: 0
   stdout: `helpers-a.test.js helpers-b.test.js helpers.js`
   mutation: skip edit 5 (helpers-b.test.js); the listing lacks it.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e03-rename-query/check.sh eval/abtest/checks/e03-rename-query/expected-cli-all.txt eval/abtest/checks/e03-rename-query/expected-cli.txt eval/abtest/checks/e03-rename-query/expected-export.txt eval/abtest/checks/e03-rename-query/http.holdout.test.js eval/abtest/checks/e03-rename-query/seed.json eval/abtest/checks/e03-rename-query/where.holdout.test.js eval/abtest/fixtures/e03-rename-query/allowed-paths.txt eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e03-rename-query/plant/test/helpers-a.test.js eval/abtest/fixtures/e03-rename-query/plant/test/helpers-b.test.js eval/abtest/fixtures/e03-rename-query/plant/test/helpers.js eval/abtest/fixtures/e03-rename-query/reference.patch eval/abtest/tasks/e03-rename-query.prompt.md`
   mutation: skip edit 17 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 17; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u09\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e03-rename-query/plant/test/helpers.js eval/abtest/fixtures/e03-rename-query/plant/test/helpers-a.test.js eval/abtest/fixtures/e03-rename-query/plant/test/helpers-b.test.js eval/abtest/fixtures/e03-rename-query/allowed-paths.txt eval/abtest/fixtures/e03-rename-query/reference.patch eval/abtest/tasks/e03-rename-query.prompt.md eval/abtest/checks/e03-rename-query/check.sh eval/abtest/checks/e03-rename-query/seed.json eval/abtest/checks/e03-rename-query/expected-cli.txt eval/abtest/checks/e03-rename-query/expected-cli-all.txt eval/abtest/checks/e03-rename-query/expected-export.txt eval/abtest/checks/e03-rename-query/http.holdout.test.js eval/abtest/checks/e03-rename-query/where.holdout.test.js | grep -vcE "^[a-z]+\(abt-u09\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/fixtures/e03-rename-query eval/abtest/checks/e03-rename-query eval/abtest/tasks/e03-rename-query.prompt.md`
   exit: 0
   stdout: empty
   mutation: skip edit 17; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no no fixture and check files; the verifier is the red-then-green check (every required check set must fail on the baseline and pass on baseline plus reference.patch)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 11 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u04 (verifier), abt-u05b (the T2 baseline fixes: own-keys auth lookup, URL parse inside the try, cli main guard) and abt-u06 (template T2 with tests and scripts/export.js) must have landed; edit 1 checks for verify-checks.sh, the template and the abt-u05b auth fix and STOPs otherwise. The abt-u05b fixes change no output the E3 snapshots record (valid tokens and URLs only).
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: feat(abt-u09): E3 rename-query fixture, prompt, checks and reference (#577)
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
