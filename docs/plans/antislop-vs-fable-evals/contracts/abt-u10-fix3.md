Unit: abt-u10

## Objective
The E4 injection check stops depending on a hand-picked payload list. `security.holdout.test.js` builds its payloads as a grid (delimiter `"`, `'` or backtick, crossed with no or one backslash prefix and one, two or three copies of the delimiter, each with a code-running and a keyword-free data-leaking tail, plus `||` forms for equality filters and `${}` template forms), all lowercase-stable, with a test that audits that. `variants-proof.sh` grows from sixteen to twenty-eight routes: thirteen injectable routes (partial escapes, first-match-only replaces, wrong escape order, try/catch answering 200, a keyword blocklist) that must score `injection=fail`, and every safe route (full escape per delimiter, JSON.stringify, whitelist, case-sensitive, parameterised) must score `injection=pass`. Fix of the third FAIL of abt-u10 (fix2 landed as 7d2212fa). One commit.

## Retrieval
GitHub issues: `gh issue view 578 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/security.holdout.test.js` (anchor: line matching `const PAYLOADS = [`)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh` (anchor: line matching `  case "$1" in`)

## Ordered edits
1. command: `test "$(grep -cF 'judge sixteen search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh)" = 1 && test "$(grep -cF 'const PAYLOADS = [' eval/abtest/checks/e04-search-injection/security.holdout.test.js)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `const PAYLOADS = [`
   indent: 0
   before:
~~~~
const PAYLOADS = [
  '"; globalThis.__pwned=1; "',
  'x" || (globalThis.__pwned=1) || "',
  "'); globalThis.__pwned=1; ('",
  '${globalThis.__pwned=1}',
  '")) || (this.__pwned=1)//',
  '\\")) || (this.__pwned=1)//',
  "')) || (this.__pwned=1)//",
  "\\')) || (this.__pwned=1)//",
  '`)) || (this.__pwned=1)//',
  '\\`)) || (this.__pwned=1)//',
];
~~~~
   after:
~~~~
// The payload grid. A route is only proven safe by a payload that runs without
// throwing, because the handler answers 400 to a throw. So every delimiter is
// crossed with a backslash prefix (none, one) and a copy count (1, 2, 3), and
// each cell has a code-running and a keyword-free data-leaking form that
// closes the filter. The "|| ... ||" forms cover an equality filter, where the
// closing form would throw. Every payload is lowercase-stable.
const RUN = '(this.__pwned=1)';
const PAYLOADS = [
  '"; this.__pwned=1; "',
  '"; globalThis.__pwned=1; "',
  "'); this.__pwned=1; ('",
  "'); globalThis.__pwned=1; ('",
  '${this.__pwned=1}',
  '\\${this.__pwned=1}',
];
for (const d of ['"', "'", '`']) {
  PAYLOADS.push(`${d})) || (globalThis.__pwned=1)//`);
  for (const p of ['', '\\']) {
    PAYLOADS.push(`${p}${d} || ${RUN} || ${d}`, `${p}${d} || true || ${d}`);
    for (const n of [1, 2, 3]) {
      PAYLOADS.push(`${p}${d.repeat(n)})) || ${RUN}//`, `${p}${d.repeat(n)})) || true//`);
    }
  }
}

test('[holdout] every payload is unique and survives lowercasing', () => {
  assert.equal(new Set(PAYLOADS).size, PAYLOADS.length);
  for (const p of PAYLOADS) {
    if (p !== p.toLowerCase()) assert.ok(PAYLOADS.includes(p.replace(/globalThis/g, 'this')), p);
  }
});
~~~~
3. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `# Shows how the E4 required checks judge sixteen search routes: injectable and safe,`
   indent: 0
   before:
~~~~
# Shows how the E4 required checks judge sixteen search routes: injectable and safe,
~~~~
   after:
~~~~
# Shows how the E4 required checks judge twenty-eight search routes: injectable and safe,
~~~~
4. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `  case "$1" in`
   indent: 0
   before:
~~~~
route() {
  case "$1" in
~~~~
   after:
~~~~
route() {
  case "$1" in
    dq-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-escape-order-wrong-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/"/g, '\\"').replace(/\\/g, '\\\\');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-catch-200-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        try {
          return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
        } catch (e) {
          return send(res, 200, { items: [] });
        }
      }
EOS
      ;;
    dq-keyword-blocklist-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|globalthis|eval|function|constructor|process|require/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
~~~~
5. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `    single-quote-raw-injectable)`
   indent: 0
   before:
~~~~
    single-quote-raw-injectable)
~~~~
   after:
~~~~
    single-quote-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace("'", "\\'");
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    backtick-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('`', '\\`').replace('$', '\\$');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    backtick-escape-no-dollar-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\`]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    double-quote-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\"]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    single-quote-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\']/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    backtick-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\`$]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    alphanumeric-whitelist-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[^a-z0-9 ]/g, '');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    single-quote-raw-injectable)
~~~~
6. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `for v in escape-lowercase-injectable single-quote-raw-injectable`
   indent: 0
   before:
~~~~
for v in escape-lowercase-injectable single-quote-raw-injectable single-quote-escape-injectable backtick-raw-injectable backtick-escape-injectable json-stringify-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters; do
~~~~
   after:
~~~~
for v in escape-lowercase-injectable single-quote-raw-injectable single-quote-escape-injectable backtick-raw-injectable backtick-escape-injectable dq-raw-injectable dq-first-match-only-injectable dq-escape-order-wrong-injectable dq-raw-catch-200-injectable dq-keyword-blocklist-injectable single-quote-first-match-only-injectable backtick-first-match-only-injectable backtick-escape-no-dollar-injectable json-stringify-safe double-quote-full-escape-safe single-quote-full-escape-safe backtick-full-escape-safe alphanumeric-whitelist-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters; do
~~~~
7. command: `git add eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh && git commit -m "fix(abt-u10): E4 injection check uses a payload grid and a 28-route sanitiser family (#578)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e04-search-injection/check.sh`, `eval/abtest/checks/e04-search-injection/functional.holdout.test.js` (fix1 settled them; this fix changes only the payload list and the variants)
- `eval/abtest/tasks/e04-search-injection.prompt.md` (its sha is pinned; the prompt is the arms' input)
- `eval/abtest/fixtures/e04-search-injection/reference.patch`, `eval/abtest/fixtures/e04-search-injection/vulnerable.patch`, `eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh`, `eval/abtest/fixtures/e04-search-injection/build.sh` (baseline, reference and vulnerable patch stay byte-identical)
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/verify-checks.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `eval/abtest/templates/`, `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/harness/`, `tests/validate.sh` (other units own them)
- `docs/plans/` (never edit a plan or contract by hand)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e04-search-injection | grep -c 'baseline-required-failures=2/4 reference-required-failures=0/4'`
   exit: 0
   stdout: `1`
   mutation: in the finished change replace `assert.equal(globalThis.__pwned, undefined);` with `assert.equal(globalThis.__pwned, 1);`; the reference route fails the injection check and the count is 0.
   proof: a scratch run of the full change printed 1 (it already passes at HEAD, where it guards against a grid payload the safe reference route trips on); with the replacement the count printed 0 and grep exited 1.
2. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `escape-lowercase-injectable: injection=fail functional=pass dynamic=pass|single-quote-raw-injectable: injection=fail functional=pass dynamic=pass|single-quote-escape-injectable: injection=fail functional=pass dynamic=pass|backtick-raw-injectable: injection=fail functional=pass dynamic=pass|backtick-escape-injectable: injection=fail functional=pass dynamic=pass|dq-raw-injectable: injection=fail functional=pass dynamic=pass|dq-first-match-only-injectable: injection=fail functional=pass dynamic=pass|dq-escape-order-wrong-injectable: injection=fail functional=pass dynamic=pass|dq-raw-catch-200-injectable: injection=fail functional=pass dynamic=pass|dq-keyword-blocklist-injectable: injection=fail functional=pass dynamic=pass|single-quote-first-match-only-injectable: injection=fail functional=pass dynamic=pass|backtick-first-match-only-injectable: injection=fail functional=pass dynamic=pass|backtick-escape-no-dollar-injectable: injection=fail functional=pass dynamic=pass|json-stringify-safe: injection=pass functional=pass dynamic=pass|double-quote-full-escape-safe: injection=pass functional=pass dynamic=pass|single-quote-full-escape-safe: injection=pass functional=pass dynamic=pass|backtick-full-escape-safe: injection=pass functional=pass dynamic=pass|alphanumeric-whitelist-safe: injection=pass functional=pass dynamic=pass|safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass|safe-with-retrieval-call: injection=pass functional=pass dynamic=pass|safe-with-new-Function: injection=pass functional=pass dynamic=fail|safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail|safe-with-eval-call: injection=pass functional=pass dynamic=fail|empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass|empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass|default-page-limit: injection=pass functional=fail dynamic=pass|case-sensitive-secure: injection=pass functional=fail dynamic=pass|rejects-odd-characters: injection=pass functional=pass dynamic=pass`
   mutation: skip edit 2 (the payload grid); five injectable lines print injection=pass and the output differs.
   proof: scratch run with only edit 2 skipped printed injection=pass for dq-first-match-only-injectable, dq-keyword-blocklist-injectable, single-quote-first-match-only-injectable, backtick-first-match-only-injectable and backtick-escape-no-dollar-injectable.
3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | wc -l`
   exit: 0
   stdout: `28`
   mutation: skip edit 6 (the for-list); the twelve new routes are never scored and the count is 16.
   proof: scratch run with only edit 6 skipped printed 16.
4. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'escape-lowercase-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-escape-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-escape-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-escape-order-wrong-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-raw-catch-200-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-keyword-blocklist-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-escape-no-dollar-injectable: injection=fail functional=pass dynamic=pass'`
   exit: 0
   stdout: `13`
   mutation: skip edit 2 (the payload grid); five of the thirteen injectable routes print injection=pass and the count is 8.
   proof: scratch run with only edit 2 skipped printed 8.
5. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'json-stringify-safe: injection=pass functional=pass dynamic=pass' -e 'double-quote-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'single-quote-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'backtick-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'alphanumeric-whitelist-safe: injection=pass functional=pass dynamic=pass' -e 'safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass' -e 'safe-with-retrieval-call: injection=pass functional=pass dynamic=pass' -e 'safe-with-new-Function: injection=pass functional=pass dynamic=fail' -e 'safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail' -e 'safe-with-eval-call: injection=pass functional=pass dynamic=fail' -e 'empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass' -e 'empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass' -e 'default-page-limit: injection=pass functional=fail dynamic=pass' -e 'case-sensitive-secure: injection=pass functional=fail dynamic=pass' -e 'rejects-odd-characters: injection=pass functional=pass dynamic=pass'`
   exit: 0
   stdout: `15`
   mutation: replace `assert.equal(globalThis.__pwned, undefined);` with `assert.equal(globalThis.__pwned, 1);` in the finished change; every safe route flips to injection=fail and the count is 0.
   proof: scratch run with that replacement printed 0 and grep exited 1.
6. run: `node -e "const fs=require('fs'),vm=require('vm');const s=fs.readFileSync('eval/abtest/checks/e04-search-injection/security.holdout.test.js','utf8');const a=s.indexOf('const RUN');const b=s.indexOf('test(');const P=vm.runInNewContext(s.slice(a,b)+';PAYLOADS');console.log(P.length,new Set(P).size,P.every(p=>p===p.toLowerCase()||P.includes(p.replace(/globalThis/g,'this'))))"`
   exit: 0
   stdout: `57 57 true`
   mutation: skip edit 2; `const RUN` is absent, indexOf returns -1 and the command exits non-zero.
   proof: scratch run with only edit 2 skipped exited 1 with empty stdout.
7. run: `grep -c 'judge twenty-eight search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; the count is 0.
8. run: `grep -cF "survives lowercasing" eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the count is 0 and grep exits 1.
9. run: `bash eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `injection-payloads-inert on vulnerable: fail|no-dynamic-evaluation-added on vulnerable: pass`
   mutation: replace security.holdout.test.js with the single line `'use strict';`; the first line reads pass.
   proof: scratch run with that file printed `injection-payloads-inert on vulnerable: pass|no-dynamic-evaluation-added on vulnerable: pass`. Already passes at HEAD and must still pass.
10. run: `sha256sum eval/abtest/tasks/e04-search-injection.prompt.md | cut -c1-16`
    exit: 0
    stdout: `8131a9d7934f2a10`
    mutation: append one character to the prompt; the hash changes. Already passes at HEAD and guards the pinned prompt.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
    exit: 0
    stdout: `eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
    mutation: skip edit 7 (the commit); the newest unit commit is fix2 and lists the same two files, so use criterion 12 for that case; a commit that also touches check.sh makes this print three paths.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
    exit: 0
    stdout: `1`
    mutation: skip edit 7; the newest unit commit is fix2, whose message carries the same trailer, so use criterion 11 for that case; deleting the trailer line from the commit message makes this print 0.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -vcE "^[a-z]+\(abt-u10\): "`
    exit: 1
    stdout: `0`
    mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
    proof: same grep -v counting as the fix2 criterion 12, whose scratch run printed 0 with exit 1 and 1 after a later untagged commit.
14. run: `git status --porcelain -- eval/abtest/fixtures/e04-search-injection eval/abtest/checks/e04-search-injection`
    exit: 0
    stdout: empty
    mutation: skip edit 7; the two changed files stay modified and are listed.

## Pre-resolved context
tdd: no these are check and fixture files; the red-then-green proof is variants-proof.sh (criteria 2-5), which before the edits lacks the twelve new routes and scores five of the existing-payload-evading routes injection=pass
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and holds the target text literally, leading spaces included; strip nothing; empty payload lines stay empty. Every payload sits in a four-tilde fence; the fence lines are not part of the payload. A before payload spanning several lines is replaced as one block. Every backslash and every `$` in a payload is literal and is not doubled, halved or expanded (the JavaScript template literals in edit 2 and the quoted heredocs in edits 4 and 5 are copied byte for byte).
root-cause: the earlier fixes each added the payload one FAIL named; this fix replaces the list with a grid so that every (delimiter, prefix, copy count, tail) cell exists, and replaces the one-route-per-FAIL proof with a route family. A route is proven safe only by a payload that does not throw (the handler answers 400 to a throw), so each cell has a non-throwing closing form and a `||` form for equality filters. Each grid axis was shown necessary in a scratch run: with copy counts limited to 1 the three first-match-only routes print injection=pass; with the `true` tails removed the keyword-blocklist route prints injection=pass; at HEAD (before this change) five of the new injectable routes print injection=pass.
decision-recorded: the 200-or-400 tolerance in the injection test is kept on purpose: rejects-odd-characters (reject the request with 400) is a genuinely safe route and must keep passing. Soundness comes from the grid, the lowercase audit and the injectable family in criteria 2-5, not from forbidding 400. The keyword-free leak tails (`true`) are what catch a keyword blocklist.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u10): E4 injection check uses a payload grid and a 28-route sanitiser family (#578)
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
fix-of: 2026-10-17T08:38:33Z

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
