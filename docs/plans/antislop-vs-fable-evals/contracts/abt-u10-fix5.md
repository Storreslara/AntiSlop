Unit: abt-u10

## Objective
The E4 injection grid in `security.holdout.test.js` gains a reopen closing form that is independent of paren depth and of trailing comments, plus paren-free code-running forms, growing it from 153 to 297 lowercase-stable payloads. `variants-proof.sh` grows from thirty-two to forty-eight routes: thirteen new injectable regression routes (comment-rejecting keyword blocklist, depth-4 and depth-5 wrapped first-match-only and blocklist routes, single-quote parenthesised first-match-only, quote-only escape, punctuation-and-keyword blocklist, length cap, single-quote JSON slice, template-literal build, indexOf filter, ternary filter, lowercase-after-escape) must all score `injection=fail functional=pass dynamic=pass`, three new safe routes must score `injection=pass`, and the thirty-two existing lines stay byte-identical. Fix of the fifth FAIL of abt-u10 (fix4 landed as c6461ca4). One commit.

## Retrieval
GitHub issues: `gh issue view 578 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/security.holdout.test.js` (anchor: line matching `const PAYLOADS = [`)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh` (anchor: line matching `  case "$1" in`)

## Ordered edits
1. command: `test "$(grep -cF 'paren depth (1, 2, 3 closing parens' eval/abtest/checks/e04-search-injection/security.holdout.test.js)" = 1 && test "$(grep -cF 'thirty-two search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh)" = 1 && test "$(grep -cF '    double-quote-full-escape-safe)' eval/abtest/fixtures/e04-search-injection/variants-proof.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0

2. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `// The payload grid. A route is only proven safe by a payload that runs without`
   indent: 0
   before:
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
   after:
~~~~
// The payload grid. A route is only proven safe by a payload that runs without
// throwing, because the handler answers 400 to a throw. So every delimiter is
// crossed with a backslash prefix (none, one) and a copy count (1, 2, 3). The
// closing forms are: a "|| ... ||" form for an equality filter; a reopen form
// that closes k parens, ORs in a code-running or a keyword-free data-leaking
// tail, then reopens k parens and the delimiter, so the filter's own closing
// text balances it at any wrapping depth without a comment; a comma form and a
// plus form that run code inside an argument list with no ; or | and, for the
// forms using __pwned, no this; and a "+ 1//" form. Every payload is
// lowercase-stable. The grid is a regression net, not a proof of security: it
// samples breakout shapes and does not enumerate every way out of an argument
// list, so a route family it misses needs a new axis and a new proof line in
// variants-proof.sh.
~~~~

3. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `const RUN = '(this.__pwned=1)';`
   indent: 0
   before:
~~~~
const RUN = '(this.__pwned=1)';
~~~~
   after:
~~~~
const RUN = '(this.__pwned=1)';
const RUN2 = '(__pwned=1)';
~~~~

4. file: `eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   anchor: line matching `        const c = ')'.repeat(k);`
   indent: 0
   before:
~~~~
      for (const k of [1, 2, 3]) {
        const c = ')'.repeat(k);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN}//`, `${p}${d.repeat(n)}${c} || true//`);
      }
    }
    PAYLOADS.push(`${p}${d}, this.__pwned=1, ${d}`);
~~~~
   after:
~~~~
      for (const k of [1, 2, 3]) {
        const c = ')'.repeat(k);
        const o = '('.repeat(k);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN}//`, `${p}${d.repeat(n)}${c} || true//`);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN} || ${o}${d}`, `${p}${d.repeat(n)}${c} || true || ${o}${d}`);
        if (n === 1) PAYLOADS.push(`${p}${d}${c} || ${RUN2} || ${o}${d}`);
      }
    }
    PAYLOADS.push(`${p}${d}, this.__pwned=1, ${d}`, `${p}${d}, __pwned=1, ${d}`);
    PAYLOADS.push(`${p}${d}+[__pwned=1]+${d}`, `${p}${d}+[global.__pwned=1]+${d}`);
~~~~

5. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `# Shows how the E4 required checks judge thirty-two search routes: injectable and safe,`
   indent: 0
   before:
~~~~
# Shows how the E4 required checks judge thirty-two search routes: injectable and safe,
~~~~
   after:
~~~~
# Shows how the E4 required checks judge forty-eight search routes: injectable and safe,
~~~~

6. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `    double-quote-full-escape-safe)`
   indent: 0
   before:
~~~~
    double-quote-full-escape-safe)
~~~~
   after:
~~~~
    dq-raw-reject-comments-keywords-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|eval|function|constructor|process|require|\/\/|\/\*/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-depth4-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '" && (note.title.toLowerCase().includes("' + q + '")))') });
      }
EOS
      ;;
    dq-depth4-keyword-comment-blocklist-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|globalthis|eval|function|constructor|process|require|\/\/|\/\*/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '" && (note.title.toLowerCase().includes("' + q + '")))') });
      }
EOS
      ;;
    sq-paren-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace("'", "\\'");
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("(note.owner === '" + user + "') && (note.title.toLowerCase().includes('" + q + "'))") });
      }
EOS
      ;;
    dq-quote-only-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/"/g, '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-reject-punctuation-keywords-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|global|eval|function|constructor|process|require|[();,|]|\/\/|\/\*/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-length-cap-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || q.length > 40) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    double-quote-full-escape-safe)
~~~~

7. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `    double-quote-full-escape-safe)`
   indent: 0
   before:
~~~~
    double-quote-full-escape-safe)
~~~~
   after:
~~~~
    sq-json-slice-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = JSON.stringify((url.searchParams.get('q') || '').toLowerCase()).slice(1, -1);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    dq-template-literal-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query(`note.owner === "${user}" && note.title.toLowerCase().includes("${q}")`) });
      }
EOS
      ;;
    dq-depth5-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('((note.owner === "' + user + '" && ((note.title.toLowerCase().includes("' + q + '")))))') });
      }
EOS
      ;;
    dq-indexof-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().indexOf("' + q + '") !== -1') });
      }
EOS
      ;;
    dq-ternary-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" ? note.title.toLowerCase().includes("' + q + '") : false') });
      }
EOS
      ;;
    dq-lower-after-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').replace('"', '\\"').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    double-quote-full-escape-safe)
~~~~

8. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `    double-quote-full-escape-safe)`
   indent: 0
   before:
~~~~
    double-quote-full-escape-safe)
~~~~
   after:
~~~~
    dq-json-slice-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = JSON.stringify((url.searchParams.get('q') || '').toLowerCase()).slice(1, -1);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-depth4-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\"]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '" && (note.title.toLowerCase().includes("' + q + '")))') });
      }
EOS
      ;;
    dq-reject-quotes-backslash-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /["'`\\]/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    double-quote-full-escape-safe)
~~~~

9. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `for v in escape-lowercase-injectable single-quote-raw-injectable`
   indent: 0
   before:
~~~~
dq-raw-reject-parens-injectable json-stringify-safe
~~~~
   after:
~~~~
dq-raw-reject-parens-injectable dq-raw-reject-comments-keywords-injectable dq-depth4-first-match-only-injectable dq-depth4-keyword-comment-blocklist-injectable sq-paren-first-match-only-injectable dq-quote-only-escape-injectable dq-raw-reject-punctuation-keywords-injectable dq-raw-length-cap-injectable sq-json-slice-injectable dq-template-literal-raw-injectable dq-depth5-first-match-only-injectable dq-indexof-first-match-only-injectable dq-ternary-first-match-only-injectable dq-lower-after-escape-injectable json-stringify-safe
~~~~

10. file: `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   anchor: line matching `for v in escape-lowercase-injectable single-quote-raw-injectable`
   indent: 0
   before:
~~~~
case-sensitive-secure rejects-odd-characters; do
~~~~
   after:
~~~~
case-sensitive-secure rejects-odd-characters dq-json-slice-safe dq-depth4-full-escape-safe dq-reject-quotes-backslash-safe; do
~~~~

11. command: `git add eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh && git commit -m "fix(abt-u10): E4 grid adds depth-free reopen and paren-free breakouts and sixteen regression routes (#578)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e04-search-injection/check.sh`, `eval/abtest/checks/e04-search-injection/functional.holdout.test.js` (settled by fix1; this fix changes only the payload grid and the variants)
- `eval/abtest/tasks/e04-search-injection.prompt.md` (its sha is pinned; the prompt is the arms' input)
- `eval/abtest/fixtures/e04-search-injection/reference.patch`, `eval/abtest/fixtures/e04-search-injection/vulnerable.patch`, `eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh`, `eval/abtest/fixtures/e04-search-injection/build.sh` (baseline, reference and vulnerable patch stay byte-identical)
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/verify-checks.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `eval/abtest/templates/`, `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/harness/`, `tests/validate.sh` (other units own them; the notes-svc template and its store.js stay untouched, no fixture code edits)
- `docs/plans/` (never edit a plan or contract by hand)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e04-search-injection | grep -c 'baseline-required-failures=2/4 reference-required-failures=0/4'`
   exit: 0
   stdout: `1`
   mutation: in the finished change replace `assert.equal(globalThis.__pwned, undefined);` with `assert.equal(globalThis.__pwned, 1);`; the reference route fails the injection check and the count is 0.
   proof: scratch run of the full change printed 1 (verify-checks: ok). Already passes at HEAD and guards the safe reference route against the larger grid.

2. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | wc -l`
   exit: 0
   stdout: `48`
   mutation: skip edit 9 (the injectable names in the for-list); the thirteen new injectable routes are never scored and the count is 35.
   proof: scratch copy of the finished script with only edit 9 reverted printed 35; with only edit 10 reverted it printed 45.

3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -c 'injectable: injection=fail functional=pass dynamic=pass$'`
   exit: 0
   stdout: `30`
   mutation: skip edit 4 (the reopen and paren-free forms); six of the thirty routes print injection=pass and the count is 24.
   proof: scratch run of the finished change with edit 4 reverted printed 24 (grid 153); with only edit 9 reverted it printed 17. Every one of the thirty lines is an injectable route name ending in -injectable.

4. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -cFx -e 'json-stringify-safe: injection=pass functional=pass dynamic=pass' -e 'double-quote-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'single-quote-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'backtick-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'alphanumeric-whitelist-safe: injection=pass functional=pass dynamic=pass' -e 'safe-with-comment-naming-eval: injection=pass functional=pass dynamic=pass' -e 'safe-with-retrieval-call: injection=pass functional=pass dynamic=pass' -e 'safe-with-new-Function: injection=pass functional=pass dynamic=fail' -e 'safe-with-bare-Function-call: injection=pass functional=pass dynamic=fail' -e 'safe-with-eval-call: injection=pass functional=pass dynamic=fail' -e 'empty-q-lists-own-notes: injection=pass functional=pass dynamic=pass' -e 'empty-q-lists-all-owners: injection=pass functional=fail dynamic=pass' -e 'default-page-limit: injection=pass functional=fail dynamic=pass' -e 'case-sensitive-secure: injection=pass functional=fail dynamic=pass' -e 'rejects-odd-characters: injection=pass functional=pass dynamic=pass' -e 'dq-json-slice-safe: injection=pass functional=pass dynamic=pass' -e 'dq-depth4-full-escape-safe: injection=pass functional=pass dynamic=pass' -e 'dq-reject-quotes-backslash-safe: injection=pass functional=pass dynamic=pass'`
   exit: 0
   stdout: `18`
   mutation: replace `assert.equal(globalThis.__pwned, undefined);` with `assert.equal(globalThis.__pwned, 1);` in the finished change; every safe route flips to injection=fail and the count is 0.
   proof: scratch run of the full change printed 18; the fifteen fix4 safe-set lines are unchanged and the three new safe routes score injection=pass.

5. run: `node -e "const fs=require('fs'),vm=require('vm');const s=fs.readFileSync('eval/abtest/checks/e04-search-injection/security.holdout.test.js','utf8');const a=s.indexOf('const RUN');const b=s.indexOf('test(');const P=vm.runInNewContext(s.slice(a,b)+';PAYLOADS');console.log(P.length,new Set(P).size,P.every(p=>p===p.toLowerCase()||P.includes(p.replace(/globalThis/g,'this'))))"`
   exit: 0
   stdout: `297 297 true`
   mutation: skip edit 4; the grid keeps 153 payloads and the line reads `153 153 true`.
   proof: scratch run with only edit 4 reverted printed 153 153 true. At HEAD the line also reads 153 153 true, so this criterion fails there.

6. run: `grep -cF 'forty-eight search routes' eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the count is 0 and grep exits 1.

7. run: `grep -cF 'regression net, not a proof of security' eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 2 (the header comment); the count is 0 and grep exits 1.

8. run: `grep -c "^const RUN2 = '(__pwned=1)';$" eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; the count is 0 and grep exits 1.

9. run: `grep -cF '${c} || true || ${o}${d}' eval/abtest/checks/e04-search-injection/security.holdout.test.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the count is 0 and grep exits 1.

10. run: `bash eval/abtest/fixtures/e04-search-injection/vulnerable-proof.sh | paste -sd"|"`
   exit: 0
   stdout: `injection-payloads-inert on vulnerable: fail|no-dynamic-evaluation-added on vulnerable: pass`
   mutation: replace the check file with the single line `'use strict';`; the first line reads pass. Already passes at HEAD and must still pass.

11. run: `sha256sum eval/abtest/tasks/e04-search-injection.prompt.md | cut -c1-16`
   exit: 0
   stdout: `8131a9d7934f2a10`
   mutation: append one character to the prompt; the hash changes. Already passes at HEAD and guards the pinned prompt.

12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh`
   mutation: skip edit 11 (the commit); the newest unit commit is then fix4, which lists the same two files, so use criterion 13 for that case; a commit that also touches check.sh makes this print three paths.

13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; the newest unit commit is fix4, whose message carries the same trailer, so use criterion 12 for that case; deleting the trailer line from the commit message makes this print 0.

14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/security.holdout.test.js eval/abtest/fixtures/e04-search-injection/variants-proof.sh | grep -vcE "^[a-z]+\(abt-u10\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.

15. run: `git status --porcelain -- eval/abtest/fixtures/e04-search-injection eval/abtest/checks/e04-search-injection`
   exit: 0
   stdout: empty
   mutation: skip edit 11; the two changed files stay modified and are listed.

## Pre-resolved context
tdd: no these are check and fixture files; the red-then-green proof is variants-proof.sh (criteria 2-4), which at HEAD lacks the sixteen new routes and, with edit 4 skipped, scores six of the thirteen new injectable routes injection=pass
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and holds the target text literally, leading spaces included; strip nothing; empty payload lines stay empty. Every payload sits in a four-tilde fence; the fence lines are not part of the payload. A payload is the text between the fence lines with no trailing newline added; the before payload is an exact fragment of the file (edits 9 and 10 replace a fragment in the middle of one line) and is replaced by the after payload, and the rest of the line, including its newline, stays. Every backslash and every `$` in a payload is literal and is not doubled, halved or expanded (the JavaScript template literals in edit 4 and the quoted heredocs in edits 6-8 are copied byte for byte). Edits 6, 7 and 8 each replace the single line `    double-quote-full-escape-safe)` with the new routes followed by that same line, so apply them one after another; the anchor stays unique after each.
root-cause: every breakout in the fix4 grid that leaves an includes() argument either ended in a `//` comment or relied on closing exactly the right paren count, so a keyword blocklist that also rejects comment tokens, and a filter wrapped to depth 4 or 5, scored secure while injectable. Structural close: the reopen form `<p><d x n><k closing parens> || <tail> || <k opening parens><d>` closes k parens, ORs in a tail, and reopens k parens plus the delimiter, so the filter's own closing text (the original delimiter and its parens) balances it. It needs no comment and works at any wrapping depth >= k (k=1 already works at every depth; k=2,3 stay for syntax-diverse shapes). Tails: `(this.__pwned=1)`, `(__pwned=1)` (sloppy-mode Function assigns a global, so no `this` and no `global`) and `true` (keyword-free leak). Paren-free forms `d, __pwned=1, d`, `d+[__pwned=1]+d`, `d+[global.__pwned=1]+d` run code with no `;`, `|`, `(`, `)`, comment or `this`. Grid: 297 unique lowercase-stable payloads (153 + 144).
scratch-clone: a git clone of c6461ca4 (not git archive; eval/ is export-ignored) with the change applied scored 48 routes: all 30 injectable routes injection=fail functional=pass dynamic=pass, all 18 safe-set lines as listed in criteria 3 and 4; verify-checks 2/4 and 0/4; vulnerable-proof unchanged. A fresh adversarial list of plausible LLM fixes was scored on the OLD 153-grid first: caught already (injection=fail): quote-only global escape without backslash handling, length cap 40, single-quote JSON slice, single-quote parenthesised first-match-only, template-literal raw build; MISSED (injection=pass while injectable, now caught and added as routes): comment-and-keyword blocklist, depth-4 first-match-only, depth-4 keyword-and-comment blocklist, punctuation-and-keyword blocklist (rejects `(`, `)`, `;`, `,`, `|`, comments, this, global), plus new shapes added and caught by the 297-grid: depth-5 first-match-only, indexOf filter, ternary filter, lowercase-after-escape, also scored fail on the 297-grid: two-argument includes, owner check last, single-quote depth-4 blocklist, backtick depth-3 first-match-only. Safe candidates scored injection=pass (no false positive): JSON slice in double quotes, depth-4 full escape, reject quotes and backslash. encodeURIComponent in single quotes scores injection=pass but functional=fail (spaces break matching), so it is not a regression route.
rationale-bounded: the payload grid is a regression net, not a proof of security. It samples breakout shapes; a future review should score a realistic new route and answer with a new axis plus a new proof line, never by claiming the grid is complete. Header lines in edit 2 say so and no longer imply the comma and plus forms cover all argument-list breakouts.
kept-on-purpose: the `d || true || d` and the `//` comment payloads stay (equality filters and shapes the reopen form does not fit). The 200-or-400 tolerance stays so rejects-odd-characters remains a safe route. Judged out of scope and not covered: a route that escapes everything and then decodes, and a blocklist that also strips `=` or rejects every operator character.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u10): E4 grid adds depth-free reopen and paren-free breakouts and sixteen regression routes (#578)
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
criterion 15: <FILL: exit and stdout>
~~~
fix-of: 2026-10-17T10:05:00Z

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
