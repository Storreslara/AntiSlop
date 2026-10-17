Unit: abt-u10

## Objective
The E4 injection check no longer passes an injectable route just because the template's handler answers 400 to the exception a single-quote or backtick breakout throws: the payload list gains one non-throwing breakout per delimiter (`'`, backslash-then-`'`, backtick, backslash-then-backtick), and `variants-proof.sh` gains four injectable routes (raw and escape-only, single-quote and backtick) that must score `injection=fail`, for sixteen routes in all. Fix of the second FAIL of abt-u10 (fix1 landed as 7d09d59a); fix1's behaviour and the twelve existing variant scores stay unchanged. One commit.

## Retrieval
GitHub issues: `gh issue view 578 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/security.holdout.test.js` (anchor: line matching `  '\\")) || (this.__pwned=1)//',`)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh` (anchor: line matching `  case "$1" in`)

## Ordered edits
1. command: `test "$(grep -cF 'judge twelve search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh)" = 1 && test "$(grep -cF 'this.__pwned=1' eval/abtest/checks/e04-search-injection/security.holdout.test.js)" = 2 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
1. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `  '\\")) || (this.__pwned=1)//',`
   indent: 0
   before:
~~~~
  '\\")) || (this.__pwned=1)//',
];
~~~~
   after:
~~~~
  '\\")) || (this.__pwned=1)//',
  "')) || (this.__pwned=1)//",
  "\\')) || (this.__pwned=1)//",
  '`)) || (this.__pwned=1)//',
  '\\`)) || (this.__pwned=1)//',
];
~~~~
2. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `# Shows how the E4 required checks judge twelve search routes: injectable and safe,`
   indent: 0
   before:
~~~~
# Shows how the E4 required checks judge twelve search routes: injectable and safe,
~~~~
   after:
~~~~
# Shows how the E4 required checks judge sixteen search routes: injectable and safe,
~~~~
3. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
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
    single-quote-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    single-quote-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/'/g, "\\'");
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    backtick-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    backtick-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[`$]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
~~~~
4. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `for v in escape-lowercase-injectable json-stringify-safe`
   indent: 0
   before:
~~~~
for v in escape-lowercase-injectable json-stringify-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters; do
~~~~
   after:
~~~~
for v in escape-lowercase-injectable single-quote-raw-injectable single-quote-escape-injectable backtick-raw-injectable backtick-escape-injectable json-stringify-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters; do
~~~~
5. command: `git add eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh && git commit -m "fix(abt-u10): E4 injection check adds non-throwing single-quote and backtick breakouts (#578)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
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
   proof: a scratch run of the full change printed 1 (already passes at HEAD; it guards against a payload the safe reference route trips on).
2. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `escape-lowercase-injectable: injection=fail functional=pass dynamic=pass|single-quote-raw-injectable: injection=fail functional=pass dynamic=pass|single-quote-escape-injectable: injection=fail functional=pass dynamic=pass|backtick-raw-injectable: injection=fail functional=pass dynamic=pass|backtick-escape-injectable: injection=fail functional=pass dynamic=pass|json-stringify-safe: injection=pass functional=pass dynamic=pass|safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass|safe-with-retrieval-call: injection=pass functional=pass dynamic=pass|safe-with-new-Function: injection=pass functional=pass dynamic=fail|safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail|safe-with-eval-call: injection=pass functional=pass dynamic=fail|empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass|empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass|default-page-limit: injection=pass functional=fail dynamic=pass|case-sensitive-secure: injection=pass functional=fail dynamic=pass|rejects-odd-characters: injection=pass functional=pass dynamic=pass`
   mutation: skip edit 1 (the payloads); the four new routes print injection=pass and the output differs.
   proof: scratch run with only edit 1 skipped printed `single-quote-raw-injectable: injection=pass functional=pass dynamic=pass` and the same pass for the other three new routes.
3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | wc -l`
   exit: 0
   stdout: `16`
   mutation: skip edit 4 (the for-list); the four new routes are never scored and the count is 12.
   proof: scratch run with only edit 4 skipped printed 12.
4. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'single-quote-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-escape-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-escape-injectable: injection=fail functional=pass dynamic=pass'`
   exit: 0
   stdout: `4`
   mutation: skip edit 1 (the payloads); every new route passes the injection check and the count is 0.
   proof: scratch run with only edit 1 skipped printed 0.
5. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'escape-lowercase-injectable: injection=fail functional=pass dynamic=pass' -e 'json-stringify-safe: injection=pass functional=pass dynamic=pass' -e 'safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass' -e 'safe-with-retrieval-call: injection=pass functional=pass dynamic=pass' -e 'safe-with-new-Function: injection=pass functional=pass dynamic=fail' -e 'safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail' -e 'safe-with-eval-call: injection=pass functional=pass dynamic=fail' -e 'empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass' -e 'empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass' -e 'default-page-limit: injection=pass functional=fail dynamic=pass' -e 'case-sensitive-secure: injection=pass functional=fail dynamic=pass' -e 'rejects-odd-characters: injection=pass functional=pass dynamic=pass'`
   exit: 0
   stdout: `12`
   mutation: replace `assert.equal(globalThis.__pwned, undefined);` with `assert.equal(globalThis.__pwned, 1);` in the finished change; every route that was injection=pass flips to fail and the count is 1.
   proof: scratch run with that replacement printed a count of 1 (all 16 lines injection=fail).
6. run: `grep -c 'this.__pwned=1' eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `6`
   mutation: skip edit 1; the count is 2.
7. run: `grep -c 'judge sixteen search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the count is 0.
8. run: `bash eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `injection-payloads-inert on vulnerable: fail|no-dynamic-evaluation-added on vulnerable: pass`
   mutation: replace security.holdout.test.js with the single line `'use strict';`; the first line reads pass.
   proof: scratch run with that file printed `injection-payloads-inert on vulnerable: pass|no-dynamic-evaluation-added on vulnerable: pass`. Already passes at HEAD and must still pass.
9. run: `sha256sum eval/abtest/tasks/e04-search-injection.prompt.md | cut -c1-16`
   exit: 0
   stdout: `8131a9d7934f2a10`
   mutation: append one character to the prompt; the hash changes. Already passes at HEAD and guards the pinned prompt.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
    exit: 0
    stdout: `eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
    mutation: skip edit 5 (the commit); the newest unit commit is fix1 and lists check.sh, functional.holdout.test.js, security.holdout.test.js and variants-proof.sh.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
    exit: 0
    stdout: `1`
    mutation: skip edit 5; the newest unit commit is fix1, whose message carries the same trailer, so use criterion 10 for that case; deleting the trailer line from the commit message makes this print 0.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -vcE "^[a-z]+\(abt-u10\): "`
    exit: 1
    stdout: `0`
    mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
    proof: same grep -v counting as the fix1 criterion 13, whose scratch run printed 0 with exit 1 and 1 after a later untagged commit.
13. run: `git status --porcelain -- eval/abtest/fixtures/e04-search-injection eval/abtest/checks/e04-search-injection`
    exit: 0
    stdout: empty
    mutation: skip edit 5; the two changed files stay modified and are listed.

## Pre-resolved context
tdd: no these are check and fixture files; the red-then-green proof is variants-proof.sh (criteria 2-5), which before the edits scores the four new routes injection=pass
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and holds the target text literally, leading spaces included; strip nothing; empty payload lines stay empty. A before payload spanning several lines is replaced as one block; every backslash in a payload is literal and is not doubled or halved (edit 1 adds a source line holding two backslashes before the quote, inside a single-quoted or double-quoted JavaScript string, exactly as shown).
decision-recorded: the reviewer's structural idea (assert no code ran after every payload) and the trailing `//` comment roast are not acted on: the four payloads suffice and stripping trailing comments would let `'http://x'; eval(q)` hide an eval. The bare-JSON-array response note predates and the template convention is {items}.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u10): E4 injection check adds non-throwing single-quote and backtick breakouts (#578)
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
~~~
fix-of: 2026-10-17T09:05:00Z

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
