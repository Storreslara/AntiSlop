Unit: abt-u05

## Objective
eval/abtest/templates/notes-svc/ holds the code half of template T2: package.json (npm test = node --test, Node 18, no dependencies) and src/{store,auth,server,cli,format,seed}.js, a working zero-dependency notes service whose store.query(filterString) compiles with new Function. One commit.

## Retrieval
GitHub issues: `gh issue view 573 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/templates/notes-svc/package.json` (anchor: new file)
- `eval/abtest/templates/notes-svc/src/store.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/src/auth.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/src/format.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/src/seed.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/src/server.js` (anchor: new file)
- `eval/abtest/templates/notes-svc/src/cli.js` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/templates && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/templates/notes-svc/package.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{
  "name": "notes-svc",
  "version": "1.0.0",
  "private": true,
  "description": "Zero-dependency notes service for the antislop comparison evals. Network-free on purpose.",
  "scripts": {
    "test": "node --test"
  },
  "engines": {
    "node": ">=18"
  }
}
~~~~
3. file: `eval/abtest/templates/notes-svc/src/store.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

// In-memory note store. A note is { id, owner, title, body, createdAt }.
function createStore() {
  const notes = new Map();
  let counter = 0;

  function add({ owner, title, body = '', id, createdAt }) {
    counter += 1;
    const note = {
      id: id || `n${counter}`,
      owner,
      title,
      body,
      createdAt: createdAt || 1700000000000 + counter,
    };
    notes.set(note.id, note);
    return note;
  }

  function all() {
    return Array.from(notes.values());
  }

  function get(id) {
    return notes.get(id) || null;
  }

  function remove(id) {
    return notes.delete(id);
  }

  // Page through one owner's notes in insertion order. The cursor is the id
  // of the last note of the previous page.
  function list({ owner, limit = 50, cursor = null } = {}) {
    let rows = all().filter((n) => !owner || n.owner === owner);
    if (cursor) {
      const at = rows.findIndex((n) => n.id === cursor);
      rows = at === -1 ? rows : rows.slice(at + 1);
    }
    const items = rows.slice(0, limit);
    const next = rows.length > limit ? items[items.length - 1].id : null;
    return { items, next };
  }

  // Filter notes with a JavaScript expression over `note`, for example
  // 'note.title === "x"'. The string is compiled, so callers must build it
  // with JSON.stringify for every value they interpolate.
  function query(filterString) {
    const predicate = new Function('note', `return (${filterString});`);
    return all().filter((n) => predicate(n));
  }

  return { add, get, remove, list, query };
}

module.exports = { createStore };
~~~~
4. file: `eval/abtest/templates/notes-svc/src/auth.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

// Bearer-token check shared by every route.
const USERS = { 'tok-alice': 'alice', 'tok-bob': 'bob' };

// Returns the user name for a valid `Authorization: Bearer <token>` header,
// or null.
function requireUser(req) {
  const header = req.headers.authorization || '';
  const match = /^Bearer (\S+)$/.exec(header);
  if (!match) return null;
  return USERS[match[1]] || null;
}

module.exports = { requireUser, USERS };
~~~~
5. file: `eval/abtest/templates/notes-svc/src/format.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

// Small output formatters used by the CLI and the export script.
function money(cents) {
  return `$${(cents / 100).toFixed(2)}`;
}

function date(ms) {
  return new Date(ms).toISOString().slice(0, 10);
}

module.exports = { money, date };
~~~~
6. file: `eval/abtest/templates/notes-svc/src/seed.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

const fs = require('node:fs');

// Load notes from a JSON file (an array of { owner, title, body }) into a
// store. Used by the CLI and the export script when NOTES_SEED names a file.
function loadSeed(store, file) {
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const row of rows) store.add(row);
  return store;
}

module.exports = { loadSeed };
~~~~
7. file: `eval/abtest/templates/notes-svc/src/server.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';

const http = require('node:http');
const { requireUser } = require('./auth');
const { createStore } = require('./store');

function send(res, status, payload) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(payload));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => { data += chunk; });
    req.on('end', () => {
      try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); }
    });
  });
}

function createServer(store = createStore()) {
  return http.createServer(async (req, res) => {
    const user = requireUser(req);
    if (!user) return send(res, 401, { error: 'unauthorized' });
    const url = new URL(req.url, 'http://localhost');
    try {
      if (req.method === 'GET' && url.pathname === '/notes') {
        const title = url.searchParams.get('title');
        if (title !== null) {
          const filter = `note.owner === ${JSON.stringify(user)} && note.title === ${JSON.stringify(title)}`;
          return send(res, 200, { items: store.query(filter), next: null });
        }
        const limit = Number(url.searchParams.get('limit')) || 50;
        const cursor = url.searchParams.get('cursor');
        return send(res, 200, store.list({ owner: user, limit, cursor }));
      }
      if (req.method === 'POST' && url.pathname === '/notes') {
        const body = await readBody(req);
        if (typeof body.title !== 'string' || body.title === '') {
          return send(res, 400, { error: 'title required' });
        }
        return send(res, 201, store.add({ owner: user, title: body.title, body: body.body || '' }));
      }
      const del = /^\/notes\/([\w-]+)$/.exec(url.pathname);
      if (req.method === 'DELETE' && del) {
        const note = store.get(del[1]);
        if (!note || note.owner !== user) return send(res, 404, { error: 'not found' });
        store.remove(note.id);
        return send(res, 200, { deleted: note.id });
      }
      return send(res, 404, { error: 'not found' });
    } catch (e) {
      return send(res, 400, { error: 'bad request' });
    }
  });
}

if (require.main === module) {
  createServer().listen(Number(process.env.PORT) || 3000);
}

module.exports = { createServer };
~~~~
8. file: `eval/abtest/templates/notes-svc/src/cli.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env node
'use strict';

const { createStore } = require('./store');
const { loadSeed } = require('./seed');
const { date } = require('./format');

// Usage: node src/cli.js list [--title <text>]
// With NOTES_SEED=<file> the store starts from that JSON file.
function main(argv) {
  const store = createStore();
  if (process.env.NOTES_SEED) loadSeed(store, process.env.NOTES_SEED);
  const [command, flag, value] = argv;
  if (command !== 'list') {
    console.error('usage: cli.js list [--title <text>]');
    return 2;
  }
  const rows = flag === '--title'
    ? store.query(`note.title === ${JSON.stringify(value)}`)
    : store.list({}).items;
  for (const n of rows) console.log(`${n.id}\t${n.owner}\t${date(n.createdAt)}\t${n.title}`);
  return 0;
}

process.exitCode = main(process.argv.slice(2));
~~~~
9. command: `git add eval/abtest/templates/notes-svc/package.json eval/abtest/templates/notes-svc/src/store.js eval/abtest/templates/notes-svc/src/auth.js eval/abtest/templates/notes-svc/src/format.js eval/abtest/templates/notes-svc/src/seed.js eval/abtest/templates/notes-svc/src/server.js eval/abtest/templates/notes-svc/src/cli.js && git commit -m "feat(abt-u05): notes-svc template code with the query seam (#573)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh` (other units own them)
- `eval/fixtures/toy-lib-template/` (template T1 stays as is)
- `eval/harness/` (the one-arm pilot harness stays untouched)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `cd eval/abtest/templates/notes-svc/ && node -e 'const {createStore}=require("./src/store");const s=createStore();s.add({owner:"a",title:"x"});s.add({owner:"b",title:"y"});const p=s.list({limit:1});console.log(s.query("note.title === \"y\"").length,p.items.length,p.next)'`
   exit: 0
   stdout: `1 1 n1`
   mutation: skip edit 3 (store.js); require fails, the exit is 1 and nothing prints.
2. run: `cd eval/abtest/templates/notes-svc/ && node -e 'const {createServer}=require("./src/server");const s=createServer();s.listen(0,async()=>{const u="http://127.0.0.1:"+s.address().port+"/notes";const r=await fetch(u);const a=await fetch(u,{headers:{authorization:"Bearer tok-alice"}});console.log(r.status,a.status);s.close()})'`
   exit: 0
   stdout: `401 200`
   mutation: skip edit 4 (auth.js); require fails inside server.js, the exit is 1 and nothing prints.
3. run: `cd eval/abtest/templates/notes-svc/ && node src/cli.js bogus 2>/dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=2`
   mutation: skip edit 8 (cli.js); node cannot find the file and prints exit=1.
4. run: `node -p "require('./eval/abtest/templates/notes-svc/package.json').scripts.test"`
   exit: 0
   stdout: `node --test`
   mutation: skip edit 2 (package.json); require fails, the exit is 1 and nothing prints.
5. run: `ls eval/abtest/templates/notes-svc/src | paste -sd" "`
   exit: 0
   stdout: `auth.js cli.js format.js seed.js server.js store.js`
   mutation: skip edit 6 (seed.js); the listing lacks seed.js.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/templates/notes-svc/package.json eval/abtest/templates/notes-svc/src/auth.js eval/abtest/templates/notes-svc/src/cli.js eval/abtest/templates/notes-svc/src/format.js eval/abtest/templates/notes-svc/src/seed.js eval/abtest/templates/notes-svc/src/server.js eval/abtest/templates/notes-svc/src/store.js`
   mutation: skip edit 9 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/templates/notes-svc/package.json eval/abtest/templates/notes-svc/src/store.js eval/abtest/templates/notes-svc/src/auth.js eval/abtest/templates/notes-svc/src/format.js eval/abtest/templates/notes-svc/src/seed.js eval/abtest/templates/notes-svc/src/server.js eval/abtest/templates/notes-svc/src/cli.js | grep -vcE "^[a-z]+\(abt-u05\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/templates`
   exit: 0
   stdout: empty
   mutation: skip edit 9; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no the template tests arrive in abt-u06; criteria 1-5 are runnable smoke checks that are red at HEAD
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 9 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI. The smoke checks start a local http server on port 0 and stop it.
design-note: store.query compiles its string with new Function on purpose (the planted seam for the E3 and E4 evals); do not make it safer. Server and CLI build filter strings with JSON.stringify.
commit-message: feat(abt-u05): notes-svc template code with the query seam (#573)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05 (#573)
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
