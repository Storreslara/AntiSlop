Unit: abt-u11b

## Objective
The E5 hidden checks exist (check.sh with nine required checks, lib.holdout.js and four hidden tests); bash eval/abtest/verify-checks.sh e05-tags-feature prints baseline-required-failures=7/9 reference-required-failures=0/9 and verify-checks: ok. One commit.

## Retrieval
GitHub issues: `gh issue view 580 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e05-tags-feature/check.sh` (anchor: new file)
- `eval/abtest/checks/e05-tags-feature/lib.holdout.js` (anchor: new file)
- `eval/abtest/checks/e05-tags-feature/validation.holdout.test.js` (anchor: new file)
- `eval/abtest/checks/e05-tags-feature/filter.holdout.test.js` (anchor: new file)
- `eval/abtest/checks/e05-tags-feature/counts.holdout.test.js` (anchor: new file)
- `eval/abtest/checks/e05-tags-feature/migration.holdout.test.js` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/checks/e05-tags-feature/ && test -f eval/abtest/verify-checks.sh && test -f eval/abtest/fixtures/e05-tags-feature/reference.d/05-docs.patch && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e05-tags-feature/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E5 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
T='cp "$ABT_CHECKS_DIR"/lib.holdout.js test/ && cp "$ABT_CHECKS_DIR/%s" test/ && node --test test/%s'
abt_check tags-validation defect true "$(printf "$T" validation.holdout.test.js validation.holdout.test.js)"
abt_check tag-filter-http-and-cli defect true "$(printf "$T" filter.holdout.test.js filter.holdout.test.js)"
abt_check tags-counts defect true "$(printf "$T" counts.holdout.test.js counts.holdout.test.js)"
abt_check migration defect true "$(printf "$T" migration.holdout.test.js migration.holdout.test.js)"
abt_check readme-tags-route defect true 'grep -q "/tags" README.md'
abt_check readme-data-format-v2 defect true 'grep -qi "version.*2" README.md'
abt_check original-tests-still-pass defect true 'node --test test/store.test.js test/server.test.js test/cli.test.js' test/store.test.js test/server.test.js test/cli.test.js
abt_check commits-at-least-four process true 'n=$(git rev-list --count "$ABT_START..HEAD"); [ $((n - ${ABT_SNAPSHOT:-0})) -ge 4 ]'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
3. file: `eval/abtest/checks/e05-tags-feature/lib.holdout.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
// Shared helper for the E5 holdout tests: start the server on a port, call it.
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

const H = (user) => ({ authorization: `Bearer tok-${user}`, 'content-type': 'application/json' });

function post(base, user, body) {
  return fetch(`${base}/notes`, { method: 'POST', headers: H(user), body: JSON.stringify(body) });
}

module.exports = { withServer, H, post };
~~~~
4. file: `eval/abtest/checks/e05-tags-feature/validation.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { withServer, post } = require('./lib.holdout');

test('[holdout] valid tags are stored on the note', async () => {
  await withServer(async (base) => {
    const res = await post(base, 'alice', { title: 't', tags: ['a', 'b-1', 'x'.repeat(20)] });
    assert.equal(res.status, 201);
    assert.deepEqual((await res.json()).tags, ['a', 'b-1', 'x'.repeat(20)]);
  });
});

test('[holdout] omitted or empty tags give an empty list', async () => {
  await withServer(async (base) => {
    assert.deepEqual((await (await post(base, 'alice', { title: 't' })).json()).tags, []);
    assert.deepEqual((await (await post(base, 'alice', { title: 't', tags: [] })).json()).tags, []);
  });
});

test('[holdout] five tags are accepted and six are rejected', async () => {
  await withServer(async (base) => {
    assert.equal((await post(base, 'alice', { title: 't', tags: ['a', 'b', 'c', 'd', 'e'] })).status, 201);
    assert.equal((await post(base, 'alice', { title: 't', tags: ['a', 'b', 'c', 'd', 'e', 'f'] })).status, 400);
  });
});

test('[holdout] bad slugs and bad shapes are rejected with 400', async () => {
  await withServer(async (base) => {
    for (const tags of [['Bad'], ['has space'], ['under_score'], [''], ['x'.repeat(21)], 'solo', [1], [null], { a: 1 }]) {
      const res = await post(base, 'alice', { title: 't', tags });
      assert.equal(res.status, 400, JSON.stringify(tags));
    }
  });
});
~~~~
5. file: `eval/abtest/checks/e05-tags-feature/filter.holdout.test.js`
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
const { withServer, H, post } = require('./lib.holdout');

test('[holdout] GET /notes?tag= returns only the caller notes with that tag', async () => {
  await withServer(async (base) => {
    await post(base, 'alice', { title: 'one', tags: ['red', 'blue'] });
    await post(base, 'alice', { title: 'two', tags: ['blue'] });
    await post(base, 'alice', { title: 'three' });
    await post(base, 'bob', { title: 'four', tags: ['blue'] });
    const body = await (await fetch(`${base}/notes?tag=blue`, { headers: H('alice') })).json();
    assert.deepEqual(body.items.map((n) => n.title), ['one', 'two']);
    const none = await (await fetch(`${base}/notes?tag=green`, { headers: H('alice') })).json();
    assert.deepEqual(none.items, []);
  });
});

test('[holdout] the CLI list --tag prints only matching notes', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-tag-'));
  const seed = path.join(dir, 'seed.json');
  fs.writeFileSync(seed, JSON.stringify([
    { owner: 'alice', title: 'red one', tags: ['red'] },
    { owner: 'bob', title: 'blue one', tags: ['blue'] },
    { owner: 'alice', title: 'plain' },
  ]));
  const cli = path.join(__dirname, '..', 'src', 'cli.js');
  const run = (args) => spawnSync(process.execPath, [cli, ...args], { env: { ...process.env, NOTES_SEED: seed }, encoding: 'utf8' });
  const red = run(['list', '--tag', 'red']);
  assert.equal(red.status, 0);
  assert.equal(red.stdout.trim().split('\n').length, 1);
  assert.match(red.stdout, /red one/);
  assert.equal(run(['list', '--tag', 'green']).stdout.trim(), '');
  assert.equal(run(['list']).stdout.trim().split('\n').length, 3);
});
~~~~
6. file: `eval/abtest/checks/e05-tags-feature/counts.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { withServer, H, post } = require('./lib.holdout');

test('[holdout] GET /tags counts tags over the caller notes only', async () => {
  await withServer(async (base) => {
    await post(base, 'alice', { title: 'one', tags: ['a', 'b'] });
    await post(base, 'alice', { title: 'two', tags: ['a'] });
    await post(base, 'bob', { title: 'three', tags: ['a', 'c'] });
    const res = await fetch(`${base}/tags`, { headers: H('alice') });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { a: 2, b: 1 });
  });
});

test('[holdout] GET /tags is an empty object without tags and needs a token', async () => {
  await withServer(async (base) => {
    await post(base, 'alice', { title: 'plain' });
    assert.deepEqual(await (await fetch(`${base}/tags`, { headers: H('alice') })).json(), {});
    assert.equal((await fetch(`${base}/tags`)).status, 401);
  });
});
~~~~
7. file: `eval/abtest/checks/e05-tags-feature/migration.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.join(__dirname, '..');
const sha = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

// The v2 schema: version 2, and every note carries the v1 fields plus a tags array.
function validV2(dump) {
  if (dump.version !== 2 || !Array.isArray(dump.notes)) return false;
  return dump.notes.every((n) => ['id', 'owner', 'title', 'body', 'createdAt'].every((k) => k in n) && Array.isArray(n.tags));
}

test('[holdout] migrate-v1 converts the sample dump to a valid v2 dump', () => {
  const input = path.join(root, 'data', 'dump-v1.json');
  const before = sha(input);
  const out = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'notes-mig-')), 'dump-v2.json');
  const res = spawnSync(process.execPath, [path.join(root, 'scripts', 'migrate-v1.js'), input, out], { encoding: 'utf8' });
  assert.equal(res.status, 0, res.stderr);
  const v1 = JSON.parse(fs.readFileSync(input, 'utf8'));
  const v2 = JSON.parse(fs.readFileSync(out, 'utf8'));
  assert.equal(validV2(v2), true);
  assert.equal(v2.notes.length, v1.notes.length);
  assert.deepEqual(v2.notes.map((n) => n.tags), v1.notes.map(() => []));
  assert.deepEqual(v2.notes.map(({ tags, ...rest }) => rest), v1.notes);
  assert.equal(sha(input), before);
});
~~~~
8. command: `git add eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/checks/e05-tags-feature/lib.holdout.js eval/abtest/checks/e05-tags-feature/validation.holdout.test.js eval/abtest/checks/e05-tags-feature/filter.holdout.test.js eval/abtest/checks/e05-tags-feature/counts.holdout.test.js eval/abtest/checks/e05-tags-feature/migration.holdout.test.js && git commit -m "feat(abt-u11b): E5 hidden checks (#580)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/fixtures/` (the E5 fixture and reference series are unit abt-u11; verify-checks.sh is abt-u04)
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh` (unit abt-u04 owns the conventions)
- `eval/abtest/templates/`, `eval/fixtures/`, `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e05-tags-feature`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 7 (migration.holdout.test.js); the migration check fails on the reference, verify prints FAILED and exits 1.
2. run: `bash eval/abtest/verify-checks.sh e05-tags-feature`
   exit: 0
   stdout: `baseline-required-failures=7/9 reference-required-failures=0/9`
   mutation: skip edit 3 (lib.holdout.js); four checks cannot load their helper and fail on the reference, so the fragment reads 4/9.
3. run: `grep -c '^abt_check' eval/abtest/checks/e05-tags-feature/check.sh`
   exit: 0
   stdout: `9`
   mutation: skip edit 2 (check.sh); grep exits 2 on the missing file and prints nothing.
4. run: `ls eval/abtest/checks/e05-tags-feature/ | paste -sd" "`
   exit: 0
   stdout: `check.sh counts.holdout.test.js filter.holdout.test.js lib.holdout.js migration.holdout.test.js validation.holdout.test.js`
   mutation: skip edit 5 (filter.holdout.test.js); the listing lacks it.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/checks/e05-tags-feature/counts.holdout.test.js eval/abtest/checks/e05-tags-feature/filter.holdout.test.js eval/abtest/checks/e05-tags-feature/lib.holdout.js eval/abtest/checks/e05-tags-feature/migration.holdout.test.js eval/abtest/checks/e05-tags-feature/validation.holdout.test.js`
   mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u11b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e05-tags-feature/check.sh eval/abtest/checks/e05-tags-feature/lib.holdout.js eval/abtest/checks/e05-tags-feature/validation.holdout.test.js eval/abtest/checks/e05-tags-feature/filter.holdout.test.js eval/abtest/checks/e05-tags-feature/counts.holdout.test.js eval/abtest/checks/e05-tags-feature/migration.holdout.test.js | grep -vcE "^[a-z]+\(abt-u11b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/checks/e05-tags-feature/`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no hidden checks; criterion 1 is the red-then-green check (verify fails at HEAD because check.sh does not exist)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 8 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u04 (verifier with reference.d support) and abt-u11 (the E5 fixture and reference series) must have landed; edit 1 checks for them and STOPs otherwise.
no-real-claude: no command in this contract runs the real claude CLI. The hidden tests start local servers on port 0.
commit-message: feat(abt-u11b): E5 hidden checks (#580)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u11b (#580)
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
