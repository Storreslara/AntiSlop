Unit: abt-u10b

## Objective
E4 no-dynamic-evaluation-added stops failing correct solutions that hold a one-line or unclosed block comment, a comment with no space before the double slash, or a string naming eval or Function, and stops hiding a real call that follows a string, a template or a closing quote ending in two slashes; comment-proof.sh prints 32 variants (16 pass, 16 fail); the forty-eight-route digest stays ab566c5e0992b026; verify-checks still shows 2/4 and 0/4 for E4. One fix commit.

## Retrieval
GitHub issues: `gh issue view 613 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e04-search-injection/check.sh` (anchor: line matching `abt_check no-dynamic-evaluation-added security true`)
- `eval/abtest/fixtures/e04-search-injection/comment-proof.sh` (anchor: line matching `a real new Function call|const f = new Function(q);`)

## Ordered edits
1. command: `test "$(grep -c ABT_E4_STRIP eval/abtest/checks/e04-search-injection/check.sh)" = 0 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e04-search-injection/check.sh`
   anchor: line matching `abt_init "$1" "$2" "$3" "$4"`
   indent: 0
   insert-after:
~~~~
# The comment and string stripper for no-dynamic-evaluation-added, one sed command per line: quoted strings
# become empty, then block comments (one line, or an opener that closes later) go, then a trailing // comment
# goes unless the line holds a backtick, so a // inside a string or template never hides a call.
ABT_E4_STRIP=$(cat <<'SEDEOF'
s#"([^"\\]|\\.)*"#""#g
s#'([^'\\]|\\.)*'#''#g
s#/\*([^*]|\*+[^*/])*\*+/##g
s#/\*.*$##
/`/!s#//.*$##
SEDEOF
)
export ABT_E4_STRIP
~~~~
3. file: `eval/abtest/checks/e04-search-injection/check.sh`
   anchor: line matching `abt_check no-dynamic-evaluation-added security true`
   before: `| sed -E "s#/\*[^*]*\*/##g; s#(^|[[:space:]])//.*\$##" |`
   after: `| sed -E "$ABT_E4_STRIP" |`
4. file: `eval/abtest/fixtures/e04-search-injection/comment-proof.sh`
   anchor: line matching `a real new Function call|const f = new Function(q);`
   indent: 0
   insert-after:
~~~~
a one-line JSDoc naming eval(q)|/** Searches without eval(q). */
an indented one-line JSDoc naming eval(q)|    /** Searches without eval(q). */
a block comment naming eval(q) that closes on a later line|/* We never call eval(q) here,\n * because it is unsafe.\n */
a multi-line JSDoc naming eval(q)|/**\n * Searches without eval(q).\n */
a trailing comment with no space before the slashes|module.exports.legacy3 = 3;// not eval(x)
a trailing comment after a single-quoted string|const a = 'x'; // not eval(x)
a trailing comment after a double-quoted string|const b = "y"; // not Function(x)
a block comment and a trailing comment on one line|/* a */ module.exports.legacy4 = 4; // not eval(x)
a double-quoted string naming eval(x)|const t = "eval(x) is unsafe";
a single-quoted string naming Function(x)|const t2 = 'never Function(x)';
a JSDoc with a doubled closing star|/** not eval(x) **/ module.exports.legacy5 = 5;
a url string and a trailing comment naming eval(x)|const u2 = "http://x"; // not eval(x)
a real call after a one-line JSDoc|/** doc */ eval(q);
a real call after a single-quoted string ending in two slashes|const s2 = 'a //'; eval(q);
a real call after a double-quoted string ending in two slashes|const s3 = "a //"; eval(q);
a real call after a template literal ending in two slashes|const s4 = `a //`; eval(q);
a real call after a string holding a block comment opener|const s5 = "/*"; eval(q);
a real call inside a template interpolation|const s6 = `${eval(q)}`;
a real call before a trailing comment|eval(q); // done
a real new Function call after a block comment|/* c */ const g = new Function(q);
a real call after a string holding an escaped quote and two slashes|const s7 = "a \\" //"; eval(q);
a real Function call in a block|if (q) { Function(q)(); }
~~~~
5. command: `git add eval/abtest/checks/e04-search-injection/check.sh eval/abtest/fixtures/e04-search-injection/comment-proof.sh && git commit -m "fix(abt-u10b): E4 no-dynamic-evaluation-added strips strings and comments in order so correct code passes and no call is hidden (#613)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e04-search-injection/` files other than check.sh (the holdout tests do not change)
- `eval/abtest/fixtures/e04-search-injection/variants-proof.sh`, `vulnerable-proof.sh`, `vulnerable.patch`, `build.sh` and `reference.patch` (the fixture and its proofs stay as verified)
- `eval/abtest/checks/lib.sh` and `eval/abtest/verify-checks.sh` (the conventions do not change)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/fixtures/e04-search-injection/comment-proof.sh | grep ' pass$' | sed 's/^no-dynamic-evaluation-added with //; s/: pass$//' | paste -sd';'`
   exit: 0
   stdout: `an own-line comment naming eval(x);a trailing comment naming eval(x);an inline block comment naming Function(x);a call to evaluateRoute(q);a one-line JSDoc naming eval(q);an indented one-line JSDoc naming eval(q);a block comment naming eval(q) that closes on a later line;a multi-line JSDoc naming eval(q);a trailing comment with no space before the slashes;a trailing comment after a single-quoted string;a trailing comment after a double-quoted string;a block comment and a trailing comment on one line;a double-quoted string naming eval(x);a single-quoted string naming Function(x);a JSDoc with a doubled closing star;a url string and a trailing comment naming eval(x)`
   mutation: skip edit 3 (check.sh keeps the old sed expression).
   proof: scratch run in a clone with the finished change and HEAD's check.sh restored: seven of these variants (both one-line JSDoc forms, the later-line block comment, the no-space trailing comment, both string-naming variants, the doubled-star JSDoc) read fail, so the list is shorter.
2. run: `bash eval/abtest/fixtures/e04-search-injection/comment-proof.sh | grep ' fail$' | sed 's/^no-dynamic-evaluation-added with //; s/: fail$//' | paste -sd';'`
   exit: 0
   stdout: `a real call to eval(q);a real call after a block comment;a real call between two block comments;a real call after a block comment end;a real call after a string holding two slashes;a real new Function call;a real call after a one-line JSDoc;a real call after a single-quoted string ending in two slashes;a real call after a double-quoted string ending in two slashes;a real call after a template literal ending in two slashes;a real call after a string holding a block comment opener;a real call inside a template interpolation;a real call before a trailing comment;a real new Function call after a block comment;a real call after a string holding an escaped quote and two slashes;a real Function call in a block`
   mutation: skip edit 3.
   proof: scratch run in a clone with HEAD's check.sh restored: the single-quoted, double-quoted, template and escaped-quote string-ending-in-two-slashes variants read pass, so the list is shorter.
3. run: `bash eval/abtest/fixtures/e04-search-injection/variants-proof.sh | sha256sum | cut -c1-16`
   exit: 0
   stdout: `ab566c5e0992b026`
   mutation: in check.sh set ABT_E4_STRIP to s#^.*## on a line before the export (it blanks every line); the eval and Function routes stop failing dynamic.
   proof: scratch run of that replacement in a clone with the finished change: the digest read 6fc4404d950f6b3e.
4. run: `bash eval/abtest/verify-checks.sh e04-search-injection`
   exit: 0
   stdout: `verify: e04-search-injection baseline-required-failures=2/4 reference-required-failures=0/4`
   mutation: in check.sh set ABT_E4_STRIP to s#^.*#eval( on a line before the export; the reference fails no-dynamic-evaluation-added.
   proof: scratch run of that replacement in a clone with the finished change: the line read reference-required-failures=1/4.
5. run: `bash eval/abtest/verify-checks.sh --all | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: in check.sh set ABT_E4_STRIP to s#^.*#eval( on a line before the export; the last line reads verify-checks: FAILED.
   proof: scratch run of that replacement in a clone with the finished change: the last line read verify-checks: FAILED.
6. run: `grep -c ABT_E4_STRIP eval/abtest/checks/e04-search-injection/check.sh`
   exit: 0
   stdout: `3`
   mutation: skip edit 2 and 3; the count is 0 and grep exits 1.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10b\): ' | cut -d' ' -f1); c=$(echo "$L" | sed -n 1p); test "$c" != 84c32a390fa434d6aa851e364ae07c948c2e7ebd || { echo no-fix-commit; exit 3; }; git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e04-search-injection/check.sh eval/abtest/fixtures/e04-search-injection/comment-proof.sh`
   mutation: skip edit 5 (the commit); the newest unit commit is still 84c32a39 and the run prints no-fix-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10b\): ' | cut -d' ' -f1); c=$(echo "$L" | sed -n 1p); test "$c" != 84c32a390fa434d6aa851e364ae07c948c2e7ebd || { echo no-fix-commit; exit 3; }; git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u10b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e04-search-injection/check.sh eval/abtest/fixtures/e04-search-injection/comment-proof.sh | grep -vcE "^[a-z]+\(abt-u10b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/checks/e04-search-injection eval/abtest/fixtures/e04-search-injection`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the changed files stay modified and are listed.

## Pre-resolved context
tdd: no hidden-check configuration; criteria 1, 2 and 6 are red at HEAD (the lists differ and ABT_E4_STRIP does not exist)
blast-radius: eval/abtest/fixtures/e04-search-injection/variants-proof.sh:432
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty.
already-green: criteria 3 to 5 pass at HEAD and must stay green; criterion 3 takes about a minute and criteria 1 and 2 about half a minute each (they run 32 variants).
strip-design: the sed script runs per added line, after the own-line comment drop. Line 1 and 2 turn each double-quoted and single-quoted string (backslash escapes honoured) into an empty pair, so a double slash or a block-comment opener inside a string is gone before any comment strip. Line 3 removes a one-line block comment, star-aware, so a JSDoc with a second star goes. Line 4 removes an opener from the line end, which covers a block comment that closes on a later line. Line 5 removes a trailing double-slash comment, with or without a space before it, but only when the line holds no backtick, so a template literal ending in a double slash never hides a call.
safer-error: a false failure of this security check is the safer error than a missed call, so every unresolvable form is left failing. Known and accepted: a line holding a backtick plus a trailing comment naming eval( fails; a prose apostrophe in a block comment on a line that also holds a call can pair with a later apostrophe and hide the call; a call split as eval then newline then (q), window with a bracketed name, an alias such as const g = Function, and a continuation line that starts with a star followed by eval(q) are still missed, as before.
no-real-claude: nothing here runs the claude CLI.
commit-message: fix(abt-u10b): E4 no-dynamic-evaluation-added strips strings and comments in order so correct code passes and no call is hidden (#613)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
fix-of: the reviewer FAIL block for abt-u10b on commit 84c32a39
review-packet:
~~~
unit: abt-u10b (#613)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
