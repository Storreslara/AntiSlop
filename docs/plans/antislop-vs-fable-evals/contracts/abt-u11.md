Unit: abt-u11

## Objective
The E5 fixture exists: build.sh (template T2 plus data/dump-v1.json and a README Data format v1 section), allowed-paths.txt, the six-part tags prompt, and a five-patch reference series reference.d/01..05 that, applied commit by commit, leaves the notes-svc suite at 23 passing tests. One commit.

## Retrieval
GitHub issues: `gh issue view 579 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/e05-tags-feature/build.sh` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/plant/data/dump-v1.json` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/plant/README.fragment.md` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/reference.d/01-tag-validation.patch` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/reference.d/02-tag-filter.patch` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/reference.d/03-tag-counts.patch` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/reference.d/04-migrate-v1.patch` (anchor: new file)
- `eval/abtest/fixtures/e05-tags-feature/reference.d/05-docs.patch` (anchor: new file)
- `eval/abtest/tasks/e05-tags-feature.prompt.md` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/fixtures/e05-tags-feature/ && test -f eval/abtest/templates/notes-svc/src/server.js && test "$(grep -cF 'Object.hasOwn(USERS' eval/abtest/templates/notes-svc/src/auth.js)" = 1 && test -f eval/abtest/fixtures/lib.sh && grep -q _abt_leak_scan eval/abtest/fixtures/lib.sh && grep -q _abt_leak_hist eval/abtest/fixtures/lib.sh && grep -q "never shows another owner" eval/abtest/templates/notes-svc/test/server.test.js && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/e05-tags-feature/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E5 fixture: template T2 (notes-svc) plus a v1 data dump and a README section
# that describes the v1 format. Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/abtest/templates/notes-svc/." "$dest/"
cp -r "$HERE/plant/data" "$dest/"
cat "$HERE/plant/README.fragment.md" >> "$dest/README.md"
abt_fixture_baseline "$dest"
~~~~
3. file: `eval/abtest/fixtures/e05-tags-feature/plant/data/dump-v1.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{
  "version": 1,
  "notes": [
    { "id": "n1", "owner": "alice", "title": "first", "body": "hello", "createdAt": 1700000000001 },
    { "id": "n2", "owner": "bob", "title": "second", "body": "", "createdAt": 1700000000002 },
    { "id": "n3", "owner": "alice", "title": "third", "body": "x", "createdAt": 1700000000003 }
  ]
}
~~~~
4. file: `eval/abtest/fixtures/e05-tags-feature/plant/README.fragment.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~

## Data format v1

A dump file is JSON: `{"version": 1, "notes": [...]}` where each note holds `id`, `owner`, `title`, `body` and `createdAt`. `data/dump-v1.json` is a sample.
~~~~
5. file: `eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
src
scripts
test
README.md
data
~~~~
6. file: `eval/abtest/fixtures/e05-tags-feature/reference.d/01-tag-validation.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/src/server.js b/src/server.js
index 6d68217..cd4f517 100644
--- a/src/server.js
+++ b/src/server.js
@@ -4,6 +4,13 @@ const http = require('node:http');
 const { requireUser } = require('./auth');
 const { createStore } = require('./store');
 
+const SLUG = /^[a-z0-9-]{1,20}$/;
+
+// Zero to five lowercase slugs.
+function validTags(tags) {
+  return Array.isArray(tags) && tags.length <= 5 && tags.every((t) => typeof t === 'string' && SLUG.test(t));
+}
+
 function send(res, status, payload) {
   res.writeHead(status, { 'content-type': 'application/json' });
   res.end(JSON.stringify(payload));
@@ -40,7 +47,9 @@ function createServer(store = createStore()) {
         if (typeof body.title !== 'string' || body.title === '') {
           return send(res, 400, { error: 'title required' });
         }
-        return send(res, 201, store.add({ owner: user, title: body.title, body: body.body || '' }));
+        const tags = body.tags === undefined ? [] : body.tags;
+        if (!validTags(tags)) return send(res, 400, { error: 'tags must be 0-5 lowercase slugs' });
+        return send(res, 201, store.add({ owner: user, title: body.title, body: body.body || '', tags }));
       }
       const del = /^\/notes\/([\w-]+)$/.exec(url.pathname);
       if (req.method === 'DELETE' && del) {
diff --git a/src/store.js b/src/store.js
index 88575da..5457121 100644
--- a/src/store.js
+++ b/src/store.js
@@ -5,13 +5,14 @@ function createStore() {
   const notes = new Map();
   let counter = 0;
 
-  function add({ owner, title, body = '', id, createdAt }) {
+  function add({ owner, title, body = '', tags = [], id, createdAt }) {
     counter += 1;
     const note = {
       id: id || `n${counter}`,
       owner,
       title,
       body,
+      tags,
       createdAt: createdAt || 1700000000000 + counter,
     };
     notes.set(note.id, note);
diff --git a/test/tags-validation.test.js b/test/tags-validation.test.js
new file mode 100644
index 0000000..b84dddb
--- /dev/null
+++ b/test/tags-validation.test.js
@@ -0,0 +1,32 @@
+'use strict';
+const test = require('node:test');
+const assert = require('node:assert/strict');
+const { createServer } = require('../src/server');
+
+async function post(body) {
+  const server = createServer();
+  await new Promise((resolve) => server.listen(0, resolve));
+  try {
+    return await fetch(`http://127.0.0.1:${server.address().port}/notes`, {
+      method: 'POST',
+      headers: { authorization: 'Bearer tok-alice', 'content-type': 'application/json' },
+      body: JSON.stringify(body),
+    });
+  } finally {
+    await new Promise((resolve) => server.close(resolve));
+  }
+}
+
+test('valid tags are stored', async () => {
+  const res = await post({ title: 't', tags: ['a', 'b-1'] });
+  assert.equal(res.status, 201);
+  assert.deepEqual((await res.json()).tags, ['a', 'b-1']);
~~~~
7. file: `eval/abtest/fixtures/e05-tags-feature/reference.d/01-tag-validation.patch`
   anchor: line matching `+  assert.deepEqual((await res.json()).tags, ['a', 'b-1']);`
   indent: 0
   insert-after:
~~~~
+});
+
+test('more than five tags is a 400', async () => {
+  assert.equal((await post({ title: 't', tags: ['a', 'b', 'c', 'd', 'e', 'f'] })).status, 400);
+});
+
+test('a bad slug is a 400', async () => {
+  assert.equal((await post({ title: 't', tags: ['Bad Tag'] })).status, 400);
+});
~~~~
8. file: `eval/abtest/fixtures/e05-tags-feature/reference.d/02-tag-filter.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/src/cli.js b/src/cli.js
index dc5d91e..f76a76f 100644
--- a/src/cli.js
+++ b/src/cli.js
@@ -5,19 +5,19 @@ const { createStore } = require('./store');
 const { loadSeed } = require('./seed');
 const { date } = require('./format');
 
-// Usage: node src/cli.js list [--title <text>]
+// Usage: node src/cli.js list [--title <text> | --tag <slug>]
 // With NOTES_SEED=<file> the store starts from that JSON file.
 function main(argv) {
   const store = createStore();
   if (process.env.NOTES_SEED) loadSeed(store, process.env.NOTES_SEED);
   const [command, flag, value] = argv;
   if (command !== 'list') {
-    console.error('usage: cli.js list [--title <text>]');
+    console.error('usage: cli.js list [--title <text> | --tag <slug>]');
     return 2;
   }
   const rows = flag === '--title'
     ? store.query(`note.title === ${JSON.stringify(value)}`)
-    : store.list({}).items;
+    : store.list({ tag: flag === '--tag' ? value : null }).items;
   for (const n of rows) console.log(`${n.id}\t${n.owner}\t${date(n.createdAt)}\t${n.title}`);
   return 0;
 }
diff --git a/src/server.js b/src/server.js
index cd4f517..5a29f0f 100644
--- a/src/server.js
+++ b/src/server.js
@@ -40,7 +40,8 @@ function createServer(store = createStore()) {
         }
         const limit = Number(url.searchParams.get('limit')) || 50;
         const cursor = url.searchParams.get('cursor');
-        return send(res, 200, store.list({ owner: user, limit, cursor }));
+        const tag = url.searchParams.get('tag');
+        return send(res, 200, store.list({ owner: user, limit, cursor, tag }));
       }
       if (req.method === 'POST' && url.pathname === '/notes') {
         const body = await readBody(req);
diff --git a/src/store.js b/src/store.js
index 5457121..42655cd 100644
--- a/src/store.js
+++ b/src/store.js
@@ -33,8 +33,8 @@ function createStore() {
 
   // Page through one owner's notes in insertion order. The cursor is the id
   // of the last note of the previous page.
-  function list({ owner, limit = 50, cursor = null } = {}) {
-    let rows = all().filter((n) => !owner || n.owner === owner);
+  function list({ owner, limit = 50, cursor = null, tag = null } = {}) {
+    let rows = all().filter((n) => (!owner || n.owner === owner) && (!tag || n.tags.includes(tag)));
     if (cursor) {
       const at = rows.findIndex((n) => n.id === cursor);
       rows = at === -1 ? rows : rows.slice(at + 1);
diff --git a/test/tags-filter.test.js b/test/tags-filter.test.js
new file mode 100644
index 0000000..f25e4c2
--- /dev/null
+++ b/test/tags-filter.test.js
@@ -0,0 +1,13 @@
+'use strict';
+const test = require('node:test');
+const assert = require('node:assert/strict');
+const { createStore } = require('../src/store');
+
+test('list keeps only notes carrying the tag', () => {
+  const store = createStore();
+  store.add({ owner: 'alice', title: 'one', tags: ['red'] });
+  store.add({ owner: 'alice', title: 'two', tags: ['blue'] });
+  store.add({ owner: 'alice', title: 'three' });
+  assert.deepEqual(store.list({ tag: 'red' }).items.map((n) => n.title), ['one']);
+  assert.equal(store.list({}).items.length, 3);
+});
~~~~
9. file: `eval/abtest/fixtures/e05-tags-feature/reference.d/03-tag-counts.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/src/server.js b/src/server.js
index 5a29f0f..e0ee02e 100644
--- a/src/server.js
+++ b/src/server.js
@@ -43,6 +43,13 @@ function createServer(store = createStore()) {
         const tag = url.searchParams.get('tag');
         return send(res, 200, store.list({ owner: user, limit, cursor, tag }));
       }
+      if (req.method === 'GET' && url.pathname === '/tags') {
+        const counts = {};
+        for (const note of store.list({ owner: user, limit: Infinity }).items) {
+          for (const tag of note.tags) counts[tag] = (counts[tag] || 0) + 1;
+        }
+        return send(res, 200, counts);
+      }
       if (req.method === 'POST' && url.pathname === '/notes') {
         const body = await readBody(req);
         if (typeof body.title !== 'string' || body.title === '') {
diff --git a/test/tags-counts.test.js b/test/tags-counts.test.js
new file mode 100644
index 0000000..ff1e0c1
--- /dev/null
+++ b/test/tags-counts.test.js
@@ -0,0 +1,20 @@
+'use strict';
+const test = require('node:test');
+const assert = require('node:assert/strict');
+const { createServer } = require('../src/server');
+const { createStore } = require('../src/store');
+
+test('GET /tags counts the caller tags', async () => {
+  const store = createStore();
+  store.add({ owner: 'alice', title: 'one', tags: ['a', 'b'] });
+  store.add({ owner: 'alice', title: 'two', tags: ['a'] });
+  store.add({ owner: 'bob', title: 'three', tags: ['a'] });
+  const server = createServer(store);
+  await new Promise((resolve) => server.listen(0, resolve));
+  try {
+    const res = await fetch(`http://127.0.0.1:${server.address().port}/tags`, { headers: { authorization: 'Bearer tok-alice' } });
+    assert.deepEqual(await res.json(), { a: 2, b: 1 });
+  } finally {
+    await new Promise((resolve) => server.close(resolve));
+  }
+});
~~~~
10. file: `eval/abtest/fixtures/e05-tags-feature/reference.d/04-migrate-v1.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/scripts/migrate-v1.js b/scripts/migrate-v1.js
new file mode 100644
index 0000000..2460e76
--- /dev/null
+++ b/scripts/migrate-v1.js
@@ -0,0 +1,23 @@
+#!/usr/bin/env node
+'use strict';
+
+// Usage: node scripts/migrate-v1.js <in> <out>
+// Converts a version 1 dump to version 2: every note gains tags: [].
+const fs = require('node:fs');
+
+function migrate(dump) {
+  if (dump.version !== 1) throw new Error('expected a version 1 dump');
+  return { ...dump, version: 2, notes: dump.notes.map((n) => ({ ...n, tags: [] })) };
+}
+
+if (require.main === module) {
+  const [input, output] = process.argv.slice(2);
+  if (!input || !output) {
+    console.error('usage: migrate-v1.js <in> <out>');
+    process.exit(2);
+  }
+  const dump = JSON.parse(fs.readFileSync(input, 'utf8'));
+  fs.writeFileSync(output, `${JSON.stringify(migrate(dump), null, 2)}\n`);
+}
+
+module.exports = { migrate };
diff --git a/test/migrate-v1.test.js b/test/migrate-v1.test.js
new file mode 100644
index 0000000..ac72a10
--- /dev/null
+++ b/test/migrate-v1.test.js
@@ -0,0 +1,14 @@
+'use strict';
+const test = require('node:test');
+const assert = require('node:assert/strict');
+const { migrate } = require('../scripts/migrate-v1');
+
+test('migrate adds empty tags and bumps the version', () => {
+  const out = migrate({ version: 1, notes: [{ id: 'n1', title: 't' }] });
+  assert.equal(out.version, 2);
+  assert.deepEqual(out.notes, [{ id: 'n1', title: 't', tags: [] }]);
+});
+
+test('migrate rejects a dump that is not version 1', () => {
+  assert.throws(() => migrate({ version: 2, notes: [] }));
+});
~~~~
11. file: `eval/abtest/fixtures/e05-tags-feature/reference.d/05-docs.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/README.md b/README.md
index e70e421..abbb76f 100644
--- a/README.md
+++ b/README.md
@@ -6,8 +6,9 @@ A zero-dependency notes service (Node 18 or newer, no install step).
 
 | Method | Path | Behaviour |
 |---|---|---|
-| GET | `/notes` | The caller's notes, paged with `limit` and `cursor`; `title=<text>` keeps exact matches |
-| POST | `/notes` | Create a note from a JSON body `{title, body}`; 400 without a title |
+| GET | `/notes` | The caller's notes, paged with `limit` and `cursor`; `title=<text>` keeps exact matches; `tag=<slug>` keeps notes with that tag |
+| GET | `/tags` | `{tag: count}` over the caller's notes |
+| POST | `/notes` | Create a note from a JSON body `{title, body, tags}` (0 to 5 slugs matching `[a-z0-9-]{1,20}`); 400 without a title or with bad tags |
 | DELETE | `/notes/:id` | Delete one of the caller's notes; 404 for any other id |
 
 Every route needs `Authorization: Bearer <token>`; a missing or unknown token is a 401.
@@ -16,9 +17,13 @@ Every route needs `Authorization: Bearer <token>`; a missing or unknown token is
 
 - `npm test` runs the test suite.
 - `node src/server.js` serves on `PORT` (default 3000).
-- `node src/cli.js list [--title <text>]` lists notes; `NOTES_SEED=<file>` seeds the store from a JSON array.
+- `node src/cli.js list [--title <text> | --tag <slug>]` lists notes; `NOTES_SEED=<file>` seeds the store from a JSON array.
 - `node scripts/export.js` prints all notes as JSON.
 
 ## Data format v1
 
 A dump file is JSON: `{"version": 1, "notes": [...]}` where each note holds `id`, `owner`, `title`, `body` and `createdAt`. `data/dump-v1.json` is a sample.
+
+## Data format v2
+
+Version 2 adds `tags` (an array of slugs) to every note and sets `"version": 2`. Convert a v1 dump with `node scripts/migrate-v1.js <in> <out>`.
~~~~
12. file: `eval/abtest/tasks/e05-tags-feature.prompt.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
Add tags to notes, end to end:
1. `POST /notes` accepts `tags` (array of 0–5 lowercase slugs matching
   /^[a-z0-9-]{1,20}$/; reject otherwise with 400).
2. `GET /notes?tag=<slug>` filters by tag; `node src/cli.js list --tag
   <slug>` does the same.
3. `GET /tags` returns `{tag: count}` for the caller's notes.
4. `scripts/migrate-v1.js <in> <out>` converts a v1 dump to v2 (adds
   `tags: []` to every note and sets `"version": 2`).
5. Update README.md's route table and data-format section.
6. Tests for each of the above.
Keep each part small and committed separately. Run `npm test` before
you finish.
~~~~
13. command: `git add eval/abtest/fixtures/e05-tags-feature/build.sh eval/abtest/fixtures/e05-tags-feature/plant/data/dump-v1.json eval/abtest/fixtures/e05-tags-feature/plant/README.fragment.md eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt eval/abtest/fixtures/e05-tags-feature/reference.d/01-tag-validation.patch eval/abtest/fixtures/e05-tags-feature/reference.d/02-tag-filter.patch eval/abtest/fixtures/e05-tags-feature/reference.d/03-tag-counts.patch eval/abtest/fixtures/e05-tags-feature/reference.d/04-migrate-v1.patch eval/abtest/fixtures/e05-tags-feature/reference.d/05-docs.patch eval/abtest/tasks/e05-tags-feature.prompt.md && git commit -m "feat(abt-u11): E5 tags-feature fixture, prompt and reference series (#579)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/` (the hidden checks are unit abt-u11b; verify-checks.sh and the check conventions are abt-u04)
- `eval/abtest/templates/` (the template is read by build.sh and never edited here)
- `eval/fixtures/`, `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `d=$(mktemp -d); bash eval/abtest/fixtures/e05-tags-feature/build.sh "$d/w" > /dev/null && for p in eval/abtest/fixtures/e05-tags-feature/reference.d/*.patch; do git -C "$d/w" apply --recount "$PWD/$p" && git -C "$d/w" add -A && git -C "$d/w" -c user.name=t -c user.email=t@t.invalid commit -q -m x || exit 1; done; cd "$d/w" && npm test 2>&1 | grep -E "^# (pass|fail)" | paste -sd" "`
   exit: 0
   stdout: `# pass 23 # fail 0`
   mutation: skip edit 9 (the counts patch); the series still applies but the suite runs 22 tests, so the fragment reads # pass 22.
2. run: `ls eval/abtest/fixtures/e05-tags-feature/reference.d/ | paste -sd" "`
   exit: 0
   stdout: `01-tag-validation.patch 02-tag-filter.patch 03-tag-counts.patch 04-migrate-v1.patch 05-docs.patch`
   mutation: skip edit 11 (the last patch); the listing lacks 05-docs.patch.
3. run: `python3 -I -c "import json;print(json.load(open('eval/abtest/fixtures/e05-tags-feature/plant/data/dump-v1.json'))['version'])"`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the sample dump); open() raises, the exit is 1 and nothing prints.
4. run: `grep -c 'Data format v1' eval/abtest/fixtures/e05-tags-feature/plant/README.fragment.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the README plant); grep exits 2 on the missing file and prints nothing.
5. run: `grep -ciE 'reviewer|spec-master|persona|holdout|hidden' eval/abtest/tasks/e05-tags-feature.prompt.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 12 (the prompt); grep exits 2 on the missing file and prints nothing.
   proof: scratch run: a prompt containing the word hidden printed 1 with exit 0.
6. run: `sha256sum eval/abtest/tasks/e05-tags-feature.prompt.md | cut -c1-16`
   exit: 0
   stdout: `23b3c4c78efc1a2e`
   mutation: skip edit 12; sha256sum fails on the missing file and prints nothing.
7. run: `ls eval/abtest/fixtures/e05-tags-feature/ | paste -sd" "`
   exit: 0
   stdout: `allowed-paths.txt build.sh plant reference.d`
   mutation: skip edit 2 (build.sh); the listing lacks build.sh.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt eval/abtest/fixtures/e05-tags-feature/build.sh eval/abtest/fixtures/e05-tags-feature/plant/README.fragment.md eval/abtest/fixtures/e05-tags-feature/plant/data/dump-v1.json eval/abtest/fixtures/e05-tags-feature/reference.d/01-tag-validation.patch eval/abtest/fixtures/e05-tags-feature/reference.d/02-tag-filter.patch eval/abtest/fixtures/e05-tags-feature/reference.d/03-tag-counts.patch eval/abtest/fixtures/e05-tags-feature/reference.d/04-migrate-v1.patch eval/abtest/fixtures/e05-tags-feature/reference.d/05-docs.patch eval/abtest/tasks/e05-tags-feature.prompt.md`
   mutation: skip edit 13 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 13; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/e05-tags-feature/build.sh eval/abtest/fixtures/e05-tags-feature/plant/data/dump-v1.json eval/abtest/fixtures/e05-tags-feature/plant/README.fragment.md eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt eval/abtest/fixtures/e05-tags-feature/reference.d/01-tag-validation.patch eval/abtest/fixtures/e05-tags-feature/reference.d/02-tag-filter.patch eval/abtest/fixtures/e05-tags-feature/reference.d/03-tag-counts.patch eval/abtest/fixtures/e05-tags-feature/reference.d/04-migrate-v1.patch eval/abtest/fixtures/e05-tags-feature/reference.d/05-docs.patch eval/abtest/tasks/e05-tags-feature.prompt.md | grep -vcE "^[a-z]+\(abt-u11\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/fixtures/e05-tags-feature/ eval/abtest/tasks/e05-tags-feature.prompt.md`
   exit: 0
   stdout: empty
   mutation: skip edit 13; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no fixture files; criterion 1 builds the fixture and replays the five-patch series (red at HEAD because nothing exists)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 11 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u05c (the T2 leak guard) and abt-u06b (T2 hardening: the T2 suite is now 16 tests), abt-u04 (eval/abtest/fixtures/lib.sh), abt-u05b (the T2 baseline fixes) and abt-u06 (template T2) must have landed; edit 1 checks for them and STOPs otherwise. The checks that use this fixture are abt-u11b; abt-u05d (the neutral baseline and scaffold identity and the git-history scan) and abt-u05e (the hardened file scan) must also have landed; edit 1 checks for _abt_leak_scan and _abt_leak_hist in eval/abtest/fixtures/lib.sh and STOPs otherwise.
no-real-claude: no command in this contract runs the real claude CLI. Criterion 1 runs the template tests, which start local servers on port 0.
patch-files: every reference.d patch is applied with git apply --recount, so a context line that holds a single space may be an empty line; do not add trailing spaces to a payload.
commit-message: feat(abt-u11): E5 tags-feature fixture, prompt and reference series (#579)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u11 (#579)
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
