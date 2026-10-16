Unit: abt-u06

## Objective
eval/abtest/templates/notes-svc/ gains test/{store,server,cli,hardening}.test.js (15 passing node:test tests, 3 of them in hardening.test.js covering the abt-u05b fixes), scripts/export.js (store[fn] string-keyed caller), README.md route table, CONTEXT.md (3 glossary entries with _Avoid_ lines), CLAUDE.md and docs/adr/0001-in-memory-store.md. One commit.

## Retrieval
GitHub issues: `gh issue view 574 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/templates/notes-svc/test/store.test.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/test/server.test.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/test/cli.test.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/test/hardening.test.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/scripts/export.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/README.md` (anchor: new file)
- `eval/abtest/templates/notes-svc/CONTEXT.md` (anchor: new file)
- `eval/abtest/templates/notes-svc/CLAUDE.md` (anchor: new file)
- `eval/abtest/templates/notes-svc/docs/adr/0001-in-memory-store.md` (anchor: new file)

## Ordered edits
1. command: `test -f eval/abtest/templates/notes-svc/src/store.js && test "$(grep -cF 'Object.hasOwn(USERS' eval/abtest/templates/notes-svc/src/auth.js)" = 1 && test ! -e eval/abtest/templates/notes-svc/test && test ! -e eval/abtest/templates/notes-svc/README.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/templates/notes-svc/test/store.test.js`
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
  store.add({ owner: 'alice', title: 'one' });
  store.add({ owner: 'alice', title: 'two' });
  store.add({ owner: 'bob', title: 'three' });
  return store;
}

test('add assigns sequential ids and get returns the note', () => {
  const store = seeded();
  assert.equal(store.get('n1').title, 'one');
  assert.equal(store.get('missing'), null);
});

test('list returns only the owner notes, paged by cursor', () => {
  const store = seeded();
  const first = store.list({ owner: 'alice', limit: 1 });
  assert.deepEqual(first.items.map((n) => n.title), ['one']);
  assert.equal(first.next, 'n1');
  const second = store.list({ owner: 'alice', limit: 1, cursor: first.next });
  assert.deepEqual(second.items.map((n) => n.title), ['two']);
  assert.equal(second.next, null);
});

test('query filters with an expression over note', () => {
  const store = seeded();
  const rows = store.query(`note.title === ${JSON.stringify('three')}`);
  assert.deepEqual(rows.map((n) => n.owner), ['bob']);
});

test('remove deletes a note', () => {
  const store = seeded();
  assert.equal(store.remove('n1'), true);
  assert.equal(store.get('n1'), null);
});
~~~~
3. file: `eval/abtest/templates/notes-svc/test/server.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

async function withServer(fn) {
  const store = createStore();
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base, store);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

const alice = { authorization: 'Bearer tok-alice', 'content-type': 'application/json' };
const bob = { authorization: 'Bearer tok-bob', 'content-type': 'application/json' };

test('every route requires a bearer token', async () => {
  await withServer(async (base) => {
    assert.equal((await fetch(`${base}/notes`)).status, 401);
    assert.equal((await fetch(`${base}/notes`, { headers: { authorization: 'Bearer nope' } })).status, 401);
  });
});

test('POST then GET returns only the caller notes', async () => {
  await withServer(async (base) => {
    const made = await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title: 'hello' }) });
    assert.equal(made.status, 201);
    await fetch(`${base}/notes`, { method: 'POST', headers: bob, body: JSON.stringify({ title: 'secret' }) });
    const mine = await (await fetch(`${base}/notes`, { headers: alice })).json();
    assert.deepEqual(mine.items.map((n) => n.title), ['hello']);
  });
});

test('GET /notes?title= filters by exact title', async () => {
  await withServer(async (base) => {
    for (const title of ['a', 'b']) {
      await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title }) });
    }
    const hit = await (await fetch(`${base}/notes?title=b`, { headers: alice })).json();
    assert.deepEqual(hit.items.map((n) => n.title), ['b']);
  });
});

test('POST without a title is a 400', async () => {
  await withServer(async (base) => {
    const bad = await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({}) });
    assert.equal(bad.status, 400);
  });
});

test('DELETE removes an own note and refuses a foreign one', async () => {
  await withServer(async (base) => {
    const note = await (await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title: 'x' }) })).json();
    assert.equal((await fetch(`${base}/notes/${note.id}`, { method: 'DELETE', headers: bob })).status, 404);
    assert.equal((await fetch(`${base}/notes/${note.id}`, { method: 'DELETE', headers: alice })).status, 200);
  });
});
~~~~
4. file: `eval/abtest/templates/notes-svc/test/cli.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const cli = path.join(__dirname, '..', 'src', 'cli.js');

function run(args) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-cli-'));
  const seed = path.join(dir, 'seed.json');
  fs.writeFileSync(seed, JSON.stringify([
    { owner: 'alice', title: 'foo' },
    { owner: 'bob', title: 'bar' },
  ]));
  return spawnSync(process.execPath, [cli, ...args], { env: { ...process.env, NOTES_SEED: seed }, encoding: 'utf8' });
}

test('list prints every seeded note', () => {
  const out = run(['list']);
  assert.equal(out.status, 0);
  assert.equal(out.stdout.trim().split('\n').length, 2);
});

test('list --title prints only the matching note', () => {
  const out = run(['list', '--title', 'foo']);
  assert.equal(out.status, 0);
  assert.match(out.stdout, /\tfoo\n$/);
  assert.equal(out.stdout.trim().split('\n').length, 1);
});

test('an unknown command exits 2', () => {
  assert.equal(run(['bogus']).status, 2);
});
~~~~
5. file: `eval/abtest/templates/notes-svc/scripts/export.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

// Print every note as JSON. The store method is looked up by name on purpose:
// this script is the string-keyed caller of the store.
const { createStore } = require('../src/store');
const { loadSeed } = require('../src/seed');
const { date } = require('../src/format');

const store = createStore();
if (process.env.NOTES_SEED) loadSeed(store, process.env.NOTES_SEED);
const fn = 'query';
const rows = store[fn]('true');
console.log(JSON.stringify(rows.map((n) => ({ id: n.id, title: n.title, date: date(n.createdAt) }))));
~~~~
6. file: `eval/abtest/templates/notes-svc/README.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# notes-svc

A zero-dependency notes service (Node 18 or newer, no install step).

## Routes

| Method | Path | Behaviour |
|---|---|---|
| GET | `/notes` | The caller's notes, paged with `limit` and `cursor`; `title=<text>` keeps exact matches |
| POST | `/notes` | Create a note from a JSON body `{title, body}`; 400 without a title |
| DELETE | `/notes/:id` | Delete one of the caller's notes; 404 for any other id |

Every route needs `Authorization: Bearer <token>`; a missing or unknown token is a 401.

## Commands

- `npm test` runs the test suite.
- `node src/server.js` serves on `PORT` (default 3000).
- `node src/cli.js list [--title <text>]` lists notes; `NOTES_SEED=<file>` seeds the store from a JSON array.
- `node scripts/export.js` prints all notes as JSON.
~~~~
7. file: `eval/abtest/templates/notes-svc/CONTEXT.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# notes-svc glossary

**note**: one titled entry owned by one user, with an id, a body and a creation time.
_Avoid_: item, record, memo.

**owner**: the user whose bearer token created a note; only the owner can read or delete it.
_Avoid_: author, account.

**filter**: a JavaScript expression over `note` that selects notes in the store's `query`.
_Avoid_: predicate string, search.
~~~~
8. file: `eval/abtest/templates/notes-svc/CLAUDE.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# notes-svc

- Run the tests with `npm test`. Run them before you finish any change.
- Zero dependencies: use only Node built-ins. Do not add a package.
- Tests live in `test/` and use `node:test`.
- Keep changes small and in the files the task needs.
- `CONTEXT.md` is the glossary; use its terms and avoid the words it lists under `_Avoid_`.
~~~~
9. file: `eval/abtest/templates/notes-svc/docs/adr/0001-in-memory-store.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# 1. In-memory note store

Status: accepted

The service keeps notes in a `Map` inside the process. There is no database and no file persistence; a restart empties the store. This keeps the service dependency-free and the tests fast. A durable store would be a new decision.
~~~~
10. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { createServer } = require('../src/server');

const SRC = path.join(__dirname, '..', 'src');

test('prototype-key tokens are rejected on every route', async () => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const token of ['toString', 'constructor', 'valueOf', 'hasOwnProperty', '__proto__']) {
      const headers = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };
      assert.equal((await fetch(`${base}/notes`, { headers })).status, 401, token);
      const body = JSON.stringify({ title: 'x' });
      assert.equal((await fetch(`${base}/notes`, { method: 'POST', headers, body })).status, 401, token);
    }
    const good = await fetch(`${base}/notes`, { headers: { authorization: 'Bearer tok-alice' } });
    assert.equal(good.status, 200);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

// The server runs in a child process so a crash is a failed test, not a dead runner.
const SERVE = `const { createServer } = require(${JSON.stringify(path.join(SRC, 'server'))});
const server = createServer();
server.listen(0, () => console.log(server.address().port));`;

function rawRequest(port, text) {
  return new Promise((resolve) => {
    let buf = '';
    const socket = net.connect(port, '127.0.0.1', () => socket.write(text));
    socket.on('data', (d) => { buf += d; });
    socket.on('close', () => resolve(buf));
    socket.on('error', () => resolve(buf));
  });
}

test('a malformed request URL is a 400 and the server keeps serving', async () => {
  const child = spawn(process.execPath, ['-e', SERVE], { stdio: ['ignore', 'pipe', 'ignore'] });
  let exited = false;
  child.on('exit', () => { exited = true; });
  try {
    const port = await new Promise((resolve, reject) => {
      child.stdout.once('data', (d) => resolve(Number(String(d).trim())));
      child.once('exit', () => reject(new Error('server exited before it listened')));
    });
    const head = 'GET http://[ HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer tok-alice\r\nConnection: close\r\n\r\n';
    assert.match(await rawRequest(port, head), /^HTTP\/1\.1 400 /);
    assert.equal(exited, false);
    const after = await fetch(`http://127.0.0.1:${port}/notes`, { headers: { authorization: 'Bearer tok-alice' } });
    assert.equal(after.status, 200);
  } finally {
    child.kill();
  }
});

test('requiring cli.js does not run main', () => {
  const code = `require(${JSON.stringify(path.join(SRC, 'cli.js'))}); console.log('exitCode=' + process.exitCode);`;
  const out = spawnSync(process.execPath, ['-e', code], { encoding: 'utf8' });
  assert.equal(out.stdout, 'exitCode=undefined\n');
  assert.equal(out.stderr, '');
  assert.equal(out.status, 0);
});
~~~~
11. command: `git add eval/abtest/templates/notes-svc/test/store.test.js eval/abtest/templates/notes-svc/test/server.test.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/README.md eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/templates/notes-svc/CLAUDE.md eval/abtest/templates/notes-svc/docs/adr/0001-in-memory-store.md && git commit -m "feat(abt-u06): notes-svc template tests, export script and docs (#574)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/templates/notes-svc/src/` and `eval/abtest/templates/notes-svc/package.json` (units abt-u05 and abt-u05b own the code half; the hardening tests assert its fixed behaviour, never edit it to make them pass)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh` (other units own them)
- `eval/harness/` (the one-arm pilot harness stays untouched)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `cd eval/abtest/templates/notes-svc/ && npm test 2>&1 | grep -E '^# (pass|fail)' | paste -sd' '`
   exit: 0
   stdout: `# pass 15 # fail 0`
   mutation: skip edit 2 (store.test.js); the suite runs 11 tests and prints # pass 11 # fail 0.
2. run: `ls eval/abtest/templates/notes-svc/test | paste -sd" "`
   exit: 0
   stdout: `cli.test.js hardening.test.js server.test.js store.test.js`
   mutation: skip edit 3 (server.test.js); the listing lacks server.test.js.
3. run: `grep -c '_Avoid_' eval/abtest/templates/notes-svc/CONTEXT.md`
   exit: 0
   stdout: `3`
   mutation: skip edit 7 (CONTEXT.md); grep exits 2 on the missing file and prints nothing.
4. run: `grep -c '^| [A-Z]' eval/abtest/templates/notes-svc/README.md`
   exit: 0
   stdout: `4`
   mutation: skip edit 6 (README.md); grep exits 2 on the missing file and prints nothing.
5. run: `grep -c 'store\[fn\]' eval/abtest/templates/notes-svc/scripts/export.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (export.js); grep exits 2 on the missing file and prints nothing.
6. run: `grep -c "npm test" eval/abtest/templates/notes-svc/CLAUDE.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 8 (CLAUDE.md); grep exits 2 on the missing file and prints nothing.
7. run: `test -f eval/abtest/templates/notes-svc/docs/adr/0001-in-memory-store.md && echo adr-ok`
   exit: 0
   stdout: `adr-ok`
   mutation: skip edit 9 (the ADR); nothing prints and the exit is 1.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u06\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/templates/notes-svc/CLAUDE.md eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/templates/notes-svc/README.md eval/abtest/templates/notes-svc/docs/adr/0001-in-memory-store.md eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/test/server.test.js eval/abtest/templates/notes-svc/test/store.test.js`
   mutation: skip edit 11 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u06\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u06\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/templates/notes-svc/test/store.test.js eval/abtest/templates/notes-svc/test/server.test.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/README.md eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/templates/notes-svc/CLAUDE.md eval/abtest/templates/notes-svc/docs/adr/0001-in-memory-store.md | grep -vcE "^[a-z]+\(abt-u06\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/templates/notes-svc/test eval/abtest/templates/notes-svc/scripts eval/abtest/templates/notes-svc/README.md eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/templates/notes-svc/CLAUDE.md eval/abtest/templates/notes-svc/docs`
   exit: 0
   stdout: empty
   mutation: skip edit 11; the new files stay untracked and are listed.
12. run: `cd eval/abtest/templates/notes-svc/ && node --test test/hardening.test.js 2>&1 | grep -E '^# (pass|fail)' | paste -sd' '`
   exit: 0
   stdout: `# pass 3 # fail 0`
   mutation: skip edit 10 (hardening.test.js); node reports a missing test file, the grep matches nothing and the stdout is empty.
13. run: `d=$(mktemp -d); L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05\): ' | cut -d' ' -f1); b=$(echo "$L" | tail -1); test -n "$b" || { echo no-baseline; exit 3; }; git worktree add --detach -q "$d/w" "$b" && mkdir -p "$d/w/eval/abtest/templates/notes-svc/test" && cp eval/abtest/templates/notes-svc/test/hardening.test.js "$d/w/eval/abtest/templates/notes-svc/test/" && (cd "$d/w/eval/abtest/templates/notes-svc/" && node --test test/hardening.test.js 2>&1 | grep -E '^# (pass|fail)' | paste -sd' '); git worktree remove --force "$d/w"; rm -rf "$d"`
   exit: 0
   stdout: `# pass 0 # fail 3`
   mutation: skip edit 10 (hardening.test.js); the cp fails, nothing is run and the stdout is empty.
   proof: non-vacuity: the file is run against the abt-u05 commit (before the abt-u05b fixes); all three tests fail there and pass at HEAD (criterion 12). Scratch run printed # pass 0 # fail 3.

## Pre-resolved context
tdd: yes eval/abtest/templates/notes-svc/test/store.test.js (and the two other test files; criterion 1 is the red-then-green check, red at HEAD because no test exists)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 11 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u05 and abt-u05b must have landed before this unit runs (src/ exists and src/auth.js uses Object.hasOwn); edit 1 checks both and STOPs otherwise.
amended-2026-10-16: test/hardening.test.js covers the three abt-u05b fixes (prototype-key tokens, malformed request URL, cli.js require guard); its server crash test runs the server in a child process so a regression fails one test instead of killing the runner. The suite total is 15 tests.
no-real-claude: no command in this contract runs the real claude CLI. The server tests listen on port 0 and close the server.
commit-message: feat(abt-u06): notes-svc template tests, export script and docs (#574)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u06 (#574)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
