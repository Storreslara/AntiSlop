Unit: abt-u10

## Objective
The E4 injection grid in `security.holdout.test.js` gains two axes, paren depth (1, 2, 3 closing parens after the delimiter copies) and two breakout forms that need none of `;`, `|` or the word `this` in the closing text (a comma form `d, this.__pwned=1, d` and a `d)+ 1//` form), growing it from 57 to 153 lowercase-stable payloads. `variants-proof.sh` grows from twenty-eight to thirty-two routes: four new injectable regression routes (parenthesised keyword blocklist, parenthesised first-match-only replace, raw double-quote route rejecting `/[;|]/`, raw double-quote route rejecting `/[()]/`) must score `injection=fail`, and all fifteen safe-set lines stay `injection=pass` or keep their listed functional/dynamic results. Fix of the fourth FAIL of abt-u10 (fix3 landed as 3c7d03c5). One commit.

## Retrieval
GitHub issues: `gh issue view 578 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/security.holdout.test.js` (anchor: line matching `const PAYLOADS = [`)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh` (anchor: line matching `  case "$1" in`)

## Ordered edits
1. command: `test "$(grep -cF 'a bounded regression net' eval/abtest/checks/e04-search-injection/security.holdout.test.js)" = 0 && test "$(grep -cF 'twenty-eight search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh)" = 1 && test "$(grep -cF '    double-quote-full-escape-safe)' eval/abtest/fixtures/e04-search-injection/variants-proof.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0

2. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `// The payload grid. A route is only proven safe by a payload that runs without`
   indent: 0
   before:
~~~~
// The payload grid. A route is only proven safe by a payload that runs without
// throwing, because the handler answers 400 to a throw. So every delimiter is
// crossed with a backslash prefix (none, one) and a copy count (1, 2, 3), and
// each cell has a code-running and a keyword-free data-leaking form that
// closes the filter. The "|| ... ||" forms cover an equality filter, where the
// closing form would throw. Every payload is lowercase-stable.
~~~~
   after:
~~~~
// The payload grid. A route is only proven safe by a payload that runs without
// throwing, because the handler answers 400 to a throw. So every delimiter is
// crossed with a backslash prefix (none, one), a copy count (1, 2, 3) and a
// paren depth (1, 2, 3 closing parens, so a filter wrapped in parentheses is
// still closed), and each cell has a code-running and a keyword-free
// data-leaking tail. The "|| ... ||" forms cover an equality filter, where the
// closing form would throw. The comma form and the "+ 1" form break out inside
// an argument list without any of the characters ; | or the word this. Every
// payload is lowercase-stable. The grid is a bounded regression net, not a
// proof of security: it catches the routes variants-proof.sh lists and nothing
// more, so a new route family needs a new axis or a new proof line.
~~~~

3. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `    for (const n of [1, 2, 3]) {`
   indent: 0
   before:
~~~~
    for (const n of [1, 2, 3]) {
      PAYLOADS.push(`${p}${d.repeat(n)})) || ${RUN}//`, `${p}${d.repeat(n)})) || true//`);
    }
~~~~
   after:
~~~~
    for (const n of [1, 2, 3]) {
      for (const k of [1, 2, 3]) {
        const c = ')'.repeat(k);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN}//`, `${p}${d.repeat(n)}${c} || true//`);
      }
    }
    PAYLOADS.push(`${p}${d}, this.__pwned=1, ${d}`);
    for (const k of [1, 2, 3]) {
      PAYLOADS.push(`${p}${d}${')'.repeat(k)} + 1//`);
    }
~~~~

4. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `# Shows how the E4 required checks judge twenty-eight search routes: injectable and safe,`
   indent: 0
   before:
~~~~
# Shows how the E4 required checks judge twenty-eight search routes: injectable and safe,
~~~~
   after:
~~~~
# Shows how the E4 required checks judge thirty-two search routes: injectable and safe,
~~~~

5. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `    double-quote-full-escape-safe)`
   indent: 0
   before:
~~~~
    double-quote-full-escape-safe)
~~~~
   after:
~~~~
    dq-paren-keyword-blocklist-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|globalthis|eval|function|constructor|process|require/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '") && (note.title.toLowerCase().includes("' + q + '"))') });
      }
EOS
      ;;
    dq-paren-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '") && (note.title.toLowerCase().includes("' + q + '"))') });
      }
EOS
      ;;
    dq-raw-reject-semicolon-pipe-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /[;|]/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-reject-parens-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /[()]/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    double-quote-full-escape-safe)
~~~~

6. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `for v in escape-lowercase-injectable single-quote-raw-injectable`
   indent: 0
   before:
~~~~
backtick-escape-no-dollar-injectable json-stringify-safe
~~~~
   after:
~~~~
backtick-escape-no-dollar-injectable dq-paren-keyword-blocklist-injectable dq-paren-first-match-only-injectable dq-raw-reject-semicolon-pipe-injectable dq-raw-reject-parens-injectable json-stringify-safe
~~~~

7. command: `git add eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh && git commit -m "fix(abt-u10): E4 grid adds paren depth, comma and plus-one breakouts and four regression routes (#578)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e04-search-injection/check.sh`, `eval/abtest/checks/e04-search-injection/functional.holdout.test.js` (settled by fix1; this fix changes only the payload grid and the variants)
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
   proof: scratch run of the full change printed 1; with the replacement it printed 0 and grep exited 1. Already passes at HEAD and guards the safe reference route against the larger grid.

2. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | wc -l`
   exit: 0
   stdout: `32`
   mutation: skip edit 6 (the for-list); the four new routes are never scored and the count is 28.
   proof: scratch run with only edit 6 skipped printed 28.

3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'escape-lowercase-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-escape-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-escape-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-raw-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-escape-order-wrong-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-raw-catch-200-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-keyword-blocklist-injectable: injection=fail functional=pass dynamic=pass' -e 'single-quote-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'backtick-escape-no-dollar-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-paren-keyword-blocklist-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-paren-first-match-only-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-raw-reject-semicolon-pipe-injectable: injection=fail functional=pass dynamic=pass' -e 'dq-raw-reject-parens-injectable: injection=fail functional=pass dynamic=pass'`
   exit: 0
   stdout: `17`
   mutation: skip edit 3 (the loop); the four new routes print injection=pass and the count is 13.
   proof: scratch run with only edit 3 skipped printed 13.

4. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'json-stringify-safe: injection=pass functional=pass dynamic=pass' -e 'double-quote-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'single-quote-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'backtick-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'alphanumeric-whitelist-safe: injection=pass functional=pass dynamic=pass' -e 'safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass' -e 'safe-with-retrieval-call: injection=pass functional=pass dynamic=pass' -e 'safe-with-new-Function: injection=pass functional=pass dynamic=fail' -e 'safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail' -e 'safe-with-eval-call: injection=pass functional=pass dynamic=fail' -e 'empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass' -e 'empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass' -e 'default-page-limit: injection=pass functional=fail dynamic=pass' -e 'case-sensitive-secure: injection=pass functional=fail dynamic=pass' -e 'rejects-odd-characters: injection=pass functional=pass dynamic=pass'`
   exit: 0
   stdout: `15`
   mutation: replace `assert.equal(globalThis.__pwned, undefined);` with `assert.equal(globalThis.__pwned, 1);` in the finished change; every safe route flips to injection=fail and the count is 0.
   proof: scratch run with that replacement made verify-checks print 0 for the reference route (criterion 1); the safe-route count printing 15 on the full change was observed in the same scratch tree.

5. run: `node -e "const fs=require('fs'),vm=require('vm');const s=fs.readFileSync('eval/abtest/checks/e04-search-injection/security.holdout.test.js','utf8');const a=s.indexOf('const RUN');const b=s.indexOf('test(');const P=vm.runInNewContext(s.slice(a,b)+';PAYLOADS');console.log(P.length,new Set(P).size,P.every(p=>p===p.toLowerCase()||P.includes(p.replace(/globalThis/g,'this'))))"`
   exit: 0
   stdout: `153 153 true`
   mutation: skip edit 3 (the loop); the grid keeps 57 payloads and the line reads `57 57 true`.
   proof: scratch run with only edit 3 skipped printed 57 57 true.

6. run: `grep -cF 'thirty-two search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the count is 0 and grep exits 1.

7. run: `grep -cF 'a bounded regression net, not a' eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 2 (the header comment); the count is 0 and grep exits 1.
   proof: scratch run with only edit 2 skipped printed 0.

8. run: `grep -cF 'paren depth (1, 2, 3 closing parens' eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 2 (the header comment); the count is 0 and grep exits 1.

9. run: `bash eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `injection-payloads-inert on vulnerable: fail|no-dynamic-evaluation-added on vulnerable: pass`
   mutation: replace the check file with the single line `'use strict';`; the first line reads pass. Already passes at HEAD and must still pass.

10. run: `sha256sum eval/abtest/tasks/e04-search-injection.prompt.md | cut -c1-16`
   exit: 0
   stdout: `8131a9d7934f2a10`
   mutation: append one character to the prompt; the hash changes. Already passes at HEAD and guards the pinned prompt.

11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   mutation: skip edit 7 (the commit); the newest unit commit is then fix3, which lists the same two files, so use criterion 12 for that case; a commit that also touches check.sh makes this print three paths.

12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; the newest unit commit is fix3, whose message carries the same trailer, so use criterion 11 for that case; deleting the trailer line from the commit message makes this print 0.

13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -vcE "^[a-z]+\(abt-u10\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.

14. run: `git status --porcelain -- eval/abtest/fixtures/e04-search-injection eval/abtest/checks/e04-search-injection`
   exit: 0
   stdout: empty
   mutation: skip edit 7; the two changed files stay modified and are listed.

## Pre-resolved context
tdd: no these are check and fixture files; the red-then-green proof is variants-proof.sh (criteria 2-4), which before the edits lacks the four new routes and, with edit 3 skipped, scores all four injection=pass
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and holds the target text literally, leading spaces included; strip nothing; empty payload lines stay empty. Every payload sits in a four-tilde fence; the fence lines are not part of the payload. A before payload spanning several lines is replaced as one block. Every backslash and every `$` in a payload is literal and is not doubled, halved or expanded (the JavaScript template literals in edit 3 and the quoted heredocs in edit 5 are copied byte for byte).
root-cause: the fix3 grid had no paren-depth axis (every closing form ended in exactly two `)`), and every payload contained `;`, `|` or `this`, so a filter wrapped in parentheses and a raw route rejecting `/[;|]/` or `/[()]/` scored secure. The reviewer proved the candidate in a scratch copy: per delimiter, prefix and copy count push both tails for 1..3 closing parens; per delimiter and prefix push the comma form and the `+ 1` form for 1..3 closing parens. This gives 153 unique payloads; the 28 existing variants-proof lines stay byte-identical; verify-checks stays 2/4 and 0/4. Replayed here in a git clone of HEAD: variants-proof printed 32 lines (17 injection=fail, 15 injection=pass); with edit 3 skipped the four new routes print injection=pass and the grid is 57 payloads; with edit 6 skipped the count is 28.
rationale-bounded: the payload grid is a bounded regression net, not a proof of security. It catches the route families variants-proof.sh lists and nothing more; a future review should measure whether a realistic new injectable route (a different wrapping, a different reject rule) still scores injection=pass, and answer with a new axis plus a new proof line, never by claiming the grid is complete. The header comment added by edit 2 says the same.
kept-on-purpose: the `d || true || d` payload stays although it is dead inside `includes()` (the comma and `+ 1` forms cover argument position); it still covers an equality filter. The 200-or-400 tolerance stays so rejects-odd-characters remains a safe route. A route that escapes everything and then calls decodeURIComponent is judged unrealistic and is not covered.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u10): E4 grid adds paren depth, comma and plus-one breakouts and four regression routes (#578)
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
fix-of: 2026-10-17T08:59:30Z

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
