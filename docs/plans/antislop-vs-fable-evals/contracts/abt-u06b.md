Unit: abt-u06b

## Objective
The T2 template suite has 16 passing tests: a cross-owner GET /notes?title= test (bob never sees alice's notes), DELETE covered by the prototype-key token test, a socket timeout and per-test timeouts so a non-responding server fails instead of hanging, a port read that parses a whole line, and cli tests that remove their temp directories; scripts/export.js no longer comments that it is the string-keyed caller; CONTEXT.md limits owner isolation to the HTTP routes and no longer forbids the word search; eval/abtest/checks/lib.sh ends a check command after ABT_CHECK_TIMEOUT_S seconds (default 120) and records it as failed, with a test row. One commit.

## Retrieval
GitHub issues: `gh issue view 600 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/templates/notes-svc/test/server.test.js` (anchor: line matching `test('POST without a title is a 400'`)
- `eval/abtest/templates/notes-svc/test/hardening.test.js` (anchor: line matching `function rawRequest(port, text) {`)
- `eval/abtest/templates/notes-svc/test/cli.test.js` (anchor: line matching `function run(args) {`)
- `eval/abtest/templates/notes-svc/scripts/export.js` (anchor: line matching `this script is the string-keyed caller of the store.`)
- `eval/abtest/templates/notes-svc/CONTEXT.md` (anchor: line matching `predicate string, search.`)
- `eval/abtest/checks/lib.sh` (anchor: line matching `bash -c "$cmd" ) > /dev/null 2>&1 || rc=$?`)
- `tests/abtest-checks.test.sh` (anchor: line matching `echo "abtest-checks: $pass passed, $fail failed"`)

## Ordered edits
1. command: `test -f eval/abtest/templates/notes-svc/test/hardening.test.js && test -f eval/abtest/checks/lib.sh && grep -q abt_leak_guard eval/abtest/fixtures/lib.sh && ! grep -q "never shows another owner" eval/abtest/templates/notes-svc/test/server.test.js && ! grep -q ABT_CHECK_TIMEOUT_S eval/abtest/checks/lib.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/templates/notes-svc/test/server.test.js`
   anchor: line matching `test('POST without a title is a 400'`
   indent: 0
   before:
~~~~
test('POST without a title is a 400', async () => {
~~~~
   after:
~~~~
test('GET /notes?title= never shows another owner\'s notes', async () => {
  await withServer(async (base) => {
    for (const headers of [alice, bob]) {
      await fetch(`${base}/notes`, { method: 'POST', headers, body: JSON.stringify({ title: 'shared' }) });
    }
    const mine = await (await fetch(`${base}/notes?title=shared`, { headers: alice })).json();
    assert.deepEqual(mine.items.map((n) => n.owner), ['alice']);
    const theirs = await (await fetch(`${base}/notes?title=shared`, { headers: bob })).json();
    assert.deepEqual(theirs.items.map((n) => n.owner), ['bob']);
  });
});

test('POST without a title is a 400', async () => {
~~~~
3. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: line matching `test('prototype-key tokens are rejected on every route'`
   before: `test('prototype-key tokens are rejected on every route', async () => {`
   after: `test('prototype-key tokens are rejected on every route', { timeout: 20000 }, async () => {`
4. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: line matching `{ method: 'POST', headers, body })).status, 401, token);`
   indent: 0
   insert-after:
~~~~
      assert.equal((await fetch(`${base}/notes/n1`, { method: 'DELETE', headers })).status, 401, token);
~~~~
5. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: line matching `function rawRequest(port, text) {`
   indent: 0
   before:
~~~~
function rawRequest(port, text) {
  return new Promise((resolve) => {
    let buf = '';
    const socket = net.connect(port, '127.0.0.1', () => socket.write(text));
    socket.on('data', (d) => { buf += d; });
    socket.on('close', () => resolve(buf));
    socket.on('error', () => resolve(buf));
  });
}
~~~~
   after:
~~~~
function rawRequest(port, text) {
  return new Promise((resolve) => {
    let buf = '';
    const socket = net.connect(port, '127.0.0.1', () => socket.write(text));
    // A server that never answers ends the request after 5 seconds with what it sent (nothing), so the assertion fails.
    socket.setTimeout(5000, () => socket.destroy());
    socket.on('data', (d) => { buf += d; });
    socket.on('close', () => resolve(buf));
    socket.on('error', () => resolve(buf));
  });
}
~~~~
6. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: line matching `test('a malformed request URL is a 400 and the server keeps serving'`
   before: `test('a malformed request URL is a 400 and the server keeps serving', async () => {`
   after: `test('a malformed request URL is a 400 and the server keeps serving', { timeout: 30000 }, async () => {`
7. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: line matching `const port = await new Promise((resolve, reject) => {`
   indent: 0
   before:
~~~~
    const port = await new Promise((resolve, reject) => {
      child.stdout.once('data', (d) => resolve(Number(String(d).trim())));
      child.once('exit', () => reject(new Error('server exited before it listened')));
    });
~~~~
   after:
~~~~
    const port = await new Promise((resolve, reject) => {
      let out = '';
      child.stdout.on('data', (d) => {
        out += d;
        const line = /^(\d+)\r?\n/m.exec(out);
        if (line) resolve(Number(line[1]));
      });
      child.once('exit', () => reject(new Error('server exited before it listened')));
    });
~~~~
8. file: `eval/abtest/templates/notes-svc/test/hardening.test.js`
   anchor: line matching `server.listen(0, () => console.log(server.address().port));`
   before: `server.listen(0, () => console.log(server.address().port));`
   after: `server.listen(0, () => { console.log('ready'); console.log(server.address().port); });`
9. file: `eval/abtest/templates/notes-svc/test/cli.test.js`
   anchor: line matching `function run(args) {`
   indent: 0
   before:
~~~~
function run(args) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-cli-'));
  const seed = path.join(dir, 'seed.json');
  fs.writeFileSync(seed, JSON.stringify([
    { owner: 'alice', title: 'foo' },
    { owner: 'bob', title: 'bar' },
  ]));
  return spawnSync(process.execPath, [cli, ...args], { env: { ...process.env, NOTES_SEED: seed }, encoding: 'utf8' });
}
~~~~
   after:
~~~~
function run(args) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-cli-'));
  try {
    const seed = path.join(dir, 'seed.json');
    fs.writeFileSync(seed, JSON.stringify([
      { owner: 'alice', title: 'foo' },
      { owner: 'bob', title: 'bar' },
    ]));
    return spawnSync(process.execPath, [cli, ...args], { env: { ...process.env, NOTES_SEED: seed }, encoding: 'utf8' });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
~~~~
10. file: `eval/abtest/templates/notes-svc/scripts/export.js`
   anchor: line matching `// this script is the string-keyed caller of the store.`
   indent: 0
   before:
~~~~
// Print every note as JSON. The store method is looked up by name on purpose:
// this script is the string-keyed caller of the store.
~~~~
   after:
~~~~
// Print every note as JSON.
~~~~
11. file: `eval/abtest/templates/notes-svc/CONTEXT.md`
   anchor: line matching `**owner**: the user whose bearer token created a note;`
   before: `**owner**: the user whose bearer token created a note; only the owner can read or delete it.`
   after: `**owner**: the user whose bearer token created a note; the HTTP routes show a note only to its owner.`
12. file: `eval/abtest/templates/notes-svc/CONTEXT.md`
   anchor: line matching `predicate string, search.`
   before: `_Avoid_: predicate string, search.`
   after: `_Avoid_: predicate string.`
13. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `bash -c "$cmd" ) > /dev/null 2>&1 || rc=$?`
   before: `  ( cd "$copy" && ABT_WT="$copy" bash -c "$cmd" ) > /dev/null 2>&1 || rc=$?`
   after: `  ( cd "$copy" && ABT_WT="$copy" timeout -k 5s "${ABT_CHECK_TIMEOUT_S:-120}s" bash -c "$cmd" ) > /dev/null 2>&1 || rc=$?`
14. file: `tests/abtest-checks.test.sh`
   anchor: line matching `echo "abtest-checks: $pass passed, $fail failed"`
   indent: 0
   before:
~~~~
echo "abtest-checks: $pass passed, $fail failed"
~~~~
   after:
~~~~
# --- check timeout (abt-u06b): a hung check command is ended and recorded as failed ---
cat > "$T/lib-timeout.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check hangs defect false 'sleep 30'
abt_check fast defect false 'true'
abt_emit
EOS
tstart=$SECONDS
tjson="$(ABT_CHECK_TIMEOUT_S=1 ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" bash "$T/lib-timeout.sh" "$R" "$BASE" "$BASE" "$T/allowed")"
telapsed=$((SECONDS - tstart))
check "a check that hangs is ended well before it would finish" "$([ "$telapsed" -lt 20 ] && echo fast || echo "slow:$telapsed")" "fast"
check "the hung check is recorded as failed with exit 124" "$(printf '%s' "$tjson" | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d[0]["id"],d[0]["pass"],d[0]["exit"])')" "hangs False 124"
check "a fast check next to it still passes" "$(printf '%s' "$tjson" | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d[1]["id"],d[1]["pass"],d[1]["exit"])')" "fast True 0"
echo "abtest-checks: $pass passed, $fail failed"
~~~~
15. command: `git add eval/abtest/templates/notes-svc/test/server.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/checks/lib.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u06b): T2 tests fail instead of hanging, cover owner isolation and DELETE tokens, comments stop hinting (#600)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/templates/notes-svc/src/` and `eval/abtest/templates/notes-svc/package.json` (no source or manifest change; the abt-u05b and abt-u05c edits stay as landed)
- `eval/abtest/templates/notes-svc/test/store.test.js`, `eval/abtest/templates/notes-svc/README.md`, `eval/abtest/templates/notes-svc/CLAUDE.md` (CLAUDE.md already says to avoid the CONTEXT.md avoid words; nothing in it changes)
- `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh` (other units own them)
- `tests/validate.sh` (the checks test is already registered by abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `cd eval/abtest/templates/notes-svc/ && npm test 2>&1 | grep -E '^# (pass|fail)' | paste -sd' '`
   exit: 0
   stdout: `# pass 16 # fail 0`
   mutation: skip edit 2 (the cross-owner test); the suite runs 15 tests and prints # pass 15.
   proof: mutation matrix, run in a scratch copy of the finished change: S1 remove the owner clause at src/server.js line 31, npm test exits 1 (the new cross-owner test fails); H1 make the server swallow the malformed request without answering, npm test exits 1 after about 6 seconds (the socket timeout turns the silence into a failed assertion); H1b the same silent server with the socket timeout AND the per-test timeout removed hangs past 40 seconds, which shows those two timeouts are what make it fail; H3 restore the old once-data port parser, the hardening test exits 1 (the child now prints a ready line before the port); C1 remove the finally rmSync, three notes-cli- directories are left in a private TMPDIR (the finished file leaves 0); L1 remove the timeout wrapper in checks/lib.sh, tests/abtest-checks.test.sh exits non-zero (the hang row reports slow:29 and exit 0).
2. run: `cd eval/abtest/templates/notes-svc/ && grep -c "never shows another owner" test/server.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout 0 and the exit is 1.
3. run: `cd eval/abtest/templates/notes-svc/ && grep -c 'timeout: ' test/hardening.test.js`
   exit: 0
   stdout: `2`
   mutation: skip edit 3 (the per-test timeout on the first test); the count is 1.
4. run: `cd eval/abtest/templates/notes-svc/ && grep -c "method: 'DELETE', headers" test/hardening.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the DELETE assertion); stdout 0 and the exit is 1.
5. run: `cd eval/abtest/templates/notes-svc/ && grep -c "console.log('ready')" test/hardening.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 8 (the banner line before the port); stdout 0 and the exit is 1.
6. run: `cd eval/abtest/templates/notes-svc/ && grep -c 'socket.setTimeout' test/hardening.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (the socket timeout); stdout 0 and the exit is 1.
7. run: `cd eval/abtest/templates/notes-svc/ && grep -c 'rmSync' test/cli.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 9 (the cleanup); stdout 0 and the exit is 1.
8. run: `d=$(mktemp -d); (cd eval/abtest/templates/notes-svc/ && TMPDIR="$d" node --test test/cli.test.js > /dev/null 2>&1) && ls "$d" | grep -c "^notes-cli-"`
   exit: 1
   stdout: `0`
   mutation: drop the finally rmSync from run(); each cli test leaves a notes-cli- directory in the private TMPDIR and stdout is above 0.
   proof: scratch run (mutation C1): with the cleanup removed the listing counted 3 leftover directories after one cli test run; the finished file counts 0 with exit 1.
9. run: `cd eval/abtest/templates/notes-svc/ && grep -c 'string-keyed' scripts/export.js`
   exit: 1
   stdout: `0`
   mutation: skip edit 10 (the comment); stdout 1 and the exit is 0.
10. run: `cd eval/abtest/templates/notes-svc/ && grep -c 'search' CONTEXT.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 12 (the avoid-list edit); stdout 1 and the exit is 0.
11. run: `cd eval/abtest/templates/notes-svc/ && grep -c 'only the owner can read' CONTEXT.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 11 (the owner wording); stdout 1 and the exit is 0.
12. run: `grep -c 'ABT_CHECK_TIMEOUT_S' eval/abtest/checks/lib.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 13 (the timeout wrapper); stdout 0 and the exit is 1.
13. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 13; the hang row reports slow, the script exits non-zero and the fragment is absent.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u06b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/lib.sh eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/test/server.test.js tests/abtest-checks.test.sh`
   mutation: skip edit 15 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u06b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 15; no unit commit exists and the exit is 3.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u06b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/templates/notes-svc/test/server.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/checks/lib.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u06b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
17. run: `git status --porcelain -- eval/abtest/templates/notes-svc/test/server.test.js eval/abtest/templates/notes-svc/test/hardening.test.js eval/abtest/templates/notes-svc/test/cli.test.js eval/abtest/templates/notes-svc/scripts/export.js eval/abtest/templates/notes-svc/CONTEXT.md eval/abtest/checks/lib.sh tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 15; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes eval/abtest/templates/notes-svc/test/server.test.js (criterion 1 is the red-then-green check: the cross-owner test does not exist at HEAD) and tests/abtest-checks.test.sh (criterion 13)
blast-radius: eval/abtest/templates/notes-svc/src/server.js:31
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 8 (the leftover-directory count passes at HEAD only because no earlier run left directories in its private TMPDIR; it is a guard proven by mutation C1) and criterion 17 (the scoped clean-tree check) pass at HEAD by design.
depends-on: abt-u06 and abt-u05c must have landed; edit 1 checks for the hardening test, the leak guard and the absence of the new test and STOPs otherwise.
extends-landed-code: every edit is an insertion or a small replacement anchored on lines that exist at 976df39e; no file is rewritten. The T2 suite grows from 15 to 16 tests (one new test in server.test.js).
suite-size: contracts that cite the T2 suite size move with it: abt-u11 (# pass 22 becomes 23, 21 becomes 22).
fail-closed: a hung server or a hung check now FAILS the test or the check instead of hanging npm test or the verifier; the temp directories the cli test makes are removed.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u06b): T2 tests fail instead of hanging, cover owner isolation and DELETE tokens, comments stop hinting (#600)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u06b (#600)
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
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
