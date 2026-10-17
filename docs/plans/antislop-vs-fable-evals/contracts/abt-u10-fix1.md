Unit: abt-u10

## Objective
The E4 required checks no longer let an injectable lowercasing-and-escaping route pass, no longer fail a safe route that lists the caller's own notes for an empty `q`, and no longer score a comment or an identifier such as `retrieval(` as dynamic evaluation; they also catch a missing `limit: Infinity` and accept a safe route that rejects odd input with 400. A new `variants-proof.sh` prints one line per route variant. This fix contract supersedes the check files of `abt-u10.md` (fix of the FAIL block of the abt-u10 review); the prompt, reference.patch, vulnerable.patch and vulnerable-proof.sh stay byte-identical. One commit.

## Retrieval
GitHub issues: `gh issue view 578 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/check.sh` (anchor: line matching `abt_check no-dynamic-evaluation-added security true`)
- `eval/abtest/checks/e04-search-injection/security.holdout.test.js` (anchor: line matching `assert.deepEqual(body.items, []);`)
- `eval/abtest/checks/e04-search-injection/functional.holdout.test.js` (anchor: line matching `an empty q is a 400 or an empty list`)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh` (anchor: new file)

## Ordered edits
1. command: `test -f eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh && test ! -e eval/abtest/fixtures/e04-search-injection/variants-proof.sh && test "$(grep -cF 'an empty q is a 400 or an empty list' eval/abtest/checks/e04-search-injection/functional.holdout.test.js)" = 1 && test "$(grep -cF 'assert.deepEqual(body.items, []);' eval/abtest/checks/e04-search-injection/security.holdout.test.js)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e04-search-injection/check.sh`
   anchor: line matching `abt_check no-dynamic-evaluation-added security true`
   indent: 0
   before:
~~~~
abt_check no-dynamic-evaluation-added security true '! git diff "$ABT_START..HEAD" -- src | grep -qE "^\+.*(new Function|eval\()"'
~~~~
   after:
~~~~
abt_check no-dynamic-evaluation-added security true '! git diff "$ABT_START..HEAD" -- src | grep -E "^\+" | grep -vE "^\+[[:space:]]*(//|/\*|\*)" | grep -qE "\b(eval|Function)[[:space:]]*\("'
~~~~
3. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `  '${globalThis.__pwned=1}',`
   indent: 0
   insert-after:
~~~~
  '")) || (this.__pwned=1)//',
  '\\")) || (this.__pwned=1)//',
~~~~
4. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `assert.deepEqual(body.items, []);`
   indent: 0
   before:
~~~~
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.deepEqual(body.items, []);
      assert.equal(globalThis.__pwned, undefined);
    }
    const alive = await fetch(`${base}/notes/search?q=alpha`, { headers: alice });
    assert.equal(alive.status, 200);
~~~~
   after:
~~~~
      assert.ok(res.status === 200 || res.status === 400);
      if (res.status === 200) assert.deepEqual((await res.json()).items, []);
      assert.equal(globalThis.__pwned, undefined);
      const alive = await fetch(`${base}/notes/search?q=Alpha`, { headers: alice });
      assert.equal(alive.status, 200);
    }
~~~~
5. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `assert.deepEqual(body.items.map((n) => n.owner), ['alice']);`
   indent: 0
   before:
~~~~
    const body = await (await fetch(`${base}/notes/search?q=alpha`, { headers: alice })).json();
    assert.deepEqual(body.items.map((n) => n.owner), ['alice']);
~~~~
   after:
~~~~
    const body = await (await fetch(`${base}/notes/search?q=Alpha`, { headers: alice })).json();
    assert.deepEqual(body.items.map((n) => n.owner), ['alice']);
~~~~
6. file: `eval/abtest/checks/e04-search-injection/functional.holdout.test.js`
   anchor: line matching `an empty q is a 400 or an empty list`
   indent: 0
   before:
~~~~
test('[holdout] an empty q is a 400 or an empty list', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/notes/search?q=`, { headers: alice });
    if (res.status === 200) assert.deepEqual((await res.json()).items, []);
    else assert.equal(res.status, 400);
~~~~
   after:
~~~~
test('[holdout] an empty q is a 400, an empty list or only the caller notes', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/notes/search?q=`, { headers: alice });
    if (res.status === 200) {
      const got = JSON.stringify(titles(await res.json()).sort());
      assert.ok(got === '[]' || got === '["Alpha note","beta plan"]');
    } else assert.equal(res.status, 400);
~~~~
7. file: `eval/abtest/checks/e04-search-injection/functional.holdout.test.js`
   anchor: line matching `test('[holdout] the other routes still work', async () => {`
   indent: 0
   before:
~~~~
test('[holdout] the other routes still work', async () => {
~~~~
   after:
~~~~
test('[holdout] search returns all matches, not only the first 50', async () => {
  await withServer(async (base) => {
    for (let i = 0; i < 51; i += 1) {
      await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title: `bulk ${i}` }) });
    }
    const body = await (await fetch(`${base}/notes/search?q=bulk`, { headers: alice })).json();
    assert.equal(body.items.length, 51);
  });
});

test('[holdout] the other routes still work', async () => {
~~~~
8. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Shows how the E4 required checks judge twelve search routes: injectable and safe,
# prompt-literal and defective, and safe routes that merely mention eval. Each route is
# inserted into the baseline server.js and scored by check.sh; one line per route.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
OPEN="      if (req.method === 'GET' && url.pathname === '/notes/search') {"
safe() {
  printf '%s\n' "$OPEN"
  if [ -n "${1:-}" ]; then printf '        %s\n' "$1"; fi
  cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        const filter = 'note.owner === ' + JSON.stringify(user) + ' && note.title.toLowerCase().includes(' + JSON.stringify(q) + ')';
        return send(res, 200, { items: store.query(filter) });
      }
EOS
}
route() {
  case "$1" in
    escape-lowercase-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        let q = url.searchParams.get('q') || '';
        if (q === '') return send(res, 400, { error: 'q required' });
        q = q.toLowerCase().replace(/["'`$]/g, (c) => '\\' + c);
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    json-stringify-safe) safe ;;
    safe-with-comment-naming-eval) safe '// Do not use new Function or eval( here: q is user input.' ;;
    safe-with-retrieval-call) safe 'const r = (function retrieval(x) { return x; })(url.pathname);' ;;
    safe-with-new-Function) safe 'const f = new Function("return 1");' ;;
    safe-with-bare-Function-call) safe 'const f = Function("return 1");' ;;
    safe-with-eval-call) safe 'const f = eval("1");' ;;
    empty-q-lists-own-notes)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        const { items } = store.list({ owner: user, limit: Infinity });
        return send(res, 200, { items: items.filter((n) => n.title.toLowerCase().includes(q)) });
      }
EOS
      ;;
    empty-q-lists-all-owners)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        const rows = q === '' ? store.list({ limit: Infinity }).items : store.list({ owner: user, limit: Infinity }).items.filter((n) => n.title.toLowerCase().includes(q));
        return send(res, 200, { items: rows });
      }
EOS
      ;;
    default-page-limit)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        const { items } = store.list({ owner: user });
        return send(res, 200, { items: items.filter((n) => n.title.toLowerCase().includes(q)) });
      }
EOS
      ;;
    case-sensitive-secure)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = url.searchParams.get('q') || '';
        if (q === '') return send(res, 400, { error: 'q required' });
        const { items } = store.list({ owner: user, limit: Infinity });
        return send(res, 200, { items: items.filter((n) => n.title.includes(q)) });
      }
EOS
      ;;
    rejects-odd-characters)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /["'`\\$]/.test(q)) return send(res, 400, { error: 'bad q' });
        const { items } = store.list({ owner: user, limit: Infinity });
        return send(res, 200, { items: items.filter((n) => n.title.toLowerCase().includes(q)) });
      }
EOS
      ;;
  esac
}
for v in escape-lowercase-injectable json-stringify-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters; do
  git -C "$T/w" reset -q --hard "$base"
  route "$v" > "$T/snippet"
  python3 -I - "$T/w/src/server.js" "$T/snippet" <<'PYEOF'
import sys
path, snip = sys.argv[1:3]
anchor = "      if (req.method === 'POST' && url.pathname === '/notes') {\n"
s = open(path).read()
assert s.count(anchor) == 1
open(path, 'w').write(s.replace(anchor, open(snip).read() + anchor))
PYEOF
  git -C "$T/w" add -A
  git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "variant $v"
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e04-search-injection/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:("pass" if x["pass"] else "fail") for x in json.loads(sys.argv[1])};print(sys.argv[2] + ": injection=" + c["injection-payloads-inert"] + " functional=" + c["functional-search"] + " dynamic=" + c["no-dynamic-evaluation-added"])' "$json" "$v"
done
~~~~
9. command: `chmod 755 eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   expect: 0
10. command: `git add eval/abtest/checks/e04-search-injection/check.sh eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/checks/e04-search-injection/functional.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh && git commit -m "fix(abt-u10): E4 checks catch backslash breakout, accept own-notes empty q, ignore comments (#578)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
    expect: 0

## Do NOT touch
- `eval/abtest/tasks/e04-search-injection.prompt.md` (its sha is pinned; the prompt is the arms' input)
- `eval/abtest/fixtures/e04-search-injection/reference.patch`, `eval/abtest/fixtures/e04-search-injection/vulnerable.patch`, `eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh`, `eval/abtest/fixtures/e04-search-injection/build.sh` (the baseline, reference and vulnerable patch stay byte-identical)
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/verify-checks.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `eval/abtest/templates/`, `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/harness/`, `tests/validate.sh` (other units own them)
- `docs/plans/` (never edit a plan or contract by hand; this fix contract supersedes the check files of `abt-u10.md`)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e04-search-injection | grep -c 'baseline-required-failures=2/4 reference-required-failures=0/4'`
   exit: 0
   stdout: `1`
   mutation: in the finished change change `assert.equal(body.items.length, 51);` to `52` (edit 7); the reference fails and the count is 0.
   proof: scratch run with 52 printed 0. Already passes at HEAD (the reference and baseline are unchanged); it guards against edits that break the reference.
2. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `escape-lowercase-injectable: injection=fail functional=pass dynamic=pass|json-stringify-safe: injection=pass functional=pass dynamic=pass|safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass|safe-with-retrieval-call: injection=pass functional=pass dynamic=pass|safe-with-new-Function: injection=pass functional=pass dynamic=fail|safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail|safe-with-eval-call: injection=pass functional=pass dynamic=fail|empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass|empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass|default-page-limit: injection=pass functional=fail dynamic=pass|case-sensitive-secure: injection=pass functional=fail dynamic=pass|rejects-odd-characters: injection=pass functional=pass dynamic=pass`
   mutation: skip edit 8 (variants-proof.sh); bash cannot open the script and stdout is empty.
3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx 'escape-lowercase-injectable: injection=fail functional=pass dynamic=pass'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the two new payloads); the reviewer's injectable route passes the injection check and the count is 0.
   proof: scratch run with only edit 3 reverted printed `escape-lowercase-injectable: injection=pass functional=pass dynamic=pass`.
4. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'json-stringify-safe: injection=pass functional=pass dynamic=pass' -e 'safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass' -e 'safe-with-retrieval-call: injection=pass functional=pass dynamic=pass'`
   exit: 0
   stdout: `3`
   mutation: skip edit 2 (check.sh); the comment and the retrieval( variants score dynamic=fail and the count is 1.
   proof: scratch run with only edit 2 reverted printed dynamic=fail for both and a count of 1. For the safe JSON.stringify route alone: changing `assert.equal(globalThis.__pwned, undefined);` to `assert.equal(globalThis.__pwned, 1);` in the finished change made `json-stringify-safe` print injection=fail.
5. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'safe-with-new-Function: injection=pass functional=pass dynamic=fail' -e 'safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail' -e 'safe-with-eval-call: injection=pass functional=pass dynamic=fail'`
   exit: 0
   stdout: `3`
   mutation: skip edit 2 (check.sh); the bare `Function(` variant passes dynamic and the count is 2.
   proof: scratch run with only edit 2 reverted printed dynamic=pass for safe-with-bare-Function-call and a count of 2.
6. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass' -e 'empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass'`
   exit: 0
   stdout: `2`
   mutation: skip edit 6 (the empty-q test); the prompt-literal route fails functional and the count is 1.
   proof: scratch run with only edit 6 reverted printed functional=fail for empty-q-lists-own-notes (count 1). The other line's must-fail direction: replacing the `assert.ok(got === ...)` line of edit 6 with `assert.ok(true);` printed `empty-q-lists-all-owners: injection=pass functional=pass dynamic=pass` (count 1).
7. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx 'default-page-limit: injection=pass functional=fail dynamic=pass'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7 (the 51-note test); the missing `limit: Infinity` goes undetected and the count is 0.
   proof: scratch run with only edit 7 reverted printed `default-page-limit: injection=pass functional=pass dynamic=pass`.
8. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'case-sensitive-secure: injection=pass functional=fail dynamic=pass' -e 'rejects-odd-characters: injection=pass functional=pass dynamic=pass'`
   exit: 0
   stdout: `2`
   mutation: skip edit 5 (the Alpha isolation query) or skip edit 4 (the 400-tolerant loop); the first makes case-sensitive-secure print injection=fail, the second makes rejects-odd-characters print injection=fail, and the count is 1 either way.
   proof: scratch runs with only edit 5 reverted and with only edit 4 reverted each printed injection=fail on the named variant and a count of 1.
9. run: `bash eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `injection-payloads-inert on vulnerable: fail|no-dynamic-evaluation-added on vulnerable: pass`
   mutation: replace security.holdout.test.js with the single line `'use strict';`; the first line reads pass.
   proof: scratch run with that file printed `injection-payloads-inert on vulnerable: pass|no-dynamic-evaluation-added on vulnerable: pass`. Already passes at HEAD and must still pass after the edits.
10. run: `sha256sum eval/abtest/tasks/e04-search-injection.prompt.md | cut -c1-16`
    exit: 0
    stdout: `8131a9d7934f2a10`
    mutation: append one character to the prompt; the hash changes. Already passes at HEAD and guards the pinned prompt.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
    exit: 0
    stdout: `eval/abtest/checks/e04-search-injection/check.sh eval/abtest/checks/e04-search-injection/functional.holdout.test.js eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
    mutation: skip edit 10 (the commit); the newest unit commit is still the original one and lists ten other files.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
    exit: 0
    stdout: `1`
    mutation: skip edit 10; the newest unit commit is the original one, whose trailer names a different model, and the count is 0.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/check.sh eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/checks/e04-search-injection/functional.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -vcE "^[a-z]+\(abt-u10\): "`
    exit: 1
    stdout: `0`
    mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
    proof: same grep -v counting as the original abt-u10 criterion 10, whose scratch run printed 0 with exit 1 and 1 after a later untagged commit.
14. run: `git status --porcelain -- eval/abtest/fixtures/e04-search-injection eval/abtest/checks/e04-search-injection`
    exit: 0
    stdout: empty
    mutation: skip edit 10; the four changed files stay modified or untracked and are listed.

## Pre-resolved context
tdd: no these are check and fixture files; the red-then-green proof is variants-proof.sh (criteria 2-8), which scores twelve routes against the checks and, before the edits, shows the injectable route and the prompt-literal route scored wrongly
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and holds the target text literally, leading spaces included; strip nothing; empty payload lines stay empty. A before payload spanning several lines is replaced as one block.
decision-recorded: item 2 of the FAIL block (the empty-q gap) is resolved by the orchestrator's ruling not to change the pinned prompt: the check accepts a 400, a 200 with an empty list, or a 200 with exactly the caller's own two notes. Items 1 and 3 are fixed as the reviewer prescribed; the roast items on the 400-tolerant injection check, the Alpha-cased isolation query, the 51-note test and the liveness check after every injection input are included because each has a scratch proof above. The roast note on check.sh reading only the dispatch audit log is not acted on (the process check is recorded, not required).
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u10): E4 checks catch backslash breakout, accept own-notes empty q, ignore comments (#578)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u10 (#578)
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
~~~
fix-of: 2026-10-17T08:08:08Z

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
