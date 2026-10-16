Unit: abt-u05b

## Objective
The committed T2 code at eval/abtest/templates/notes-svc/ gains three fixes: src/auth.js accepts only own-property tokens (Bearer toString|constructor|valueOf|hasOwnProperty|__proto__ is a 401), src/server.js parses req.url inside its try (a malformed absolute-form request line is a 400, not a crash), and src/cli.js runs main() only when it is the entry point. One commit, no test file.

## Retrieval
GitHub issues: `gh issue view 593 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/templates/notes-svc/src/auth.js` (anchor: line matching `return USERS[match[1]] || null;`)
- `eval/abtest/templates/notes-svc/src/server.js` (anchor: line matching `const url = new URL(req.url, 'http://localhost');`)
- `eval/abtest/templates/notes-svc/src/cli.js` (anchor: line matching `process.exitCode = main(process.argv.slice(2));`)

## Ordered edits
1. command: `test "$(grep -cF 'return USERS[match[1]] || null;' eval/abtest/templates/notes-svc/src/auth.js)" = 1 && test "$(grep -cF "const url = new URL(req.url, 'http://localhost');" eval/abtest/templates/notes-svc/src/server.js)" = 1 && test "$(grep -cF 'process.exitCode = main(process.argv.slice(2));' eval/abtest/templates/notes-svc/src/cli.js)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/templates/notes-svc/src/auth.js`
   anchor: line matching `return USERS[match[1]] || null;`
   before: `return USERS[match[1]] || null;`
   after: `return Object.hasOwn(USERS, match[1]) ? USERS[match[1]] : null;`
3. file: `eval/abtest/templates/notes-svc/src/server.js`
   anchor: line matching `const url = new URL(req.url, 'http://localhost');`
   indent: 0
   before:
~~~~
const url = new URL(req.url, 'http://localhost');
    try {
~~~~
   after:
~~~~
try {
      const url = new URL(req.url, 'http://localhost');
~~~~
4. file: `eval/abtest/templates/notes-svc/src/cli.js`
   anchor: line matching `process.exitCode = main(process.argv.slice(2));`
   before: `process.exitCode = main(process.argv.slice(2));`
   after: `if (require.main === module) process.exitCode = main(process.argv.slice(2));`
5. command: `git add eval/abtest/templates/notes-svc/src/auth.js eval/abtest/templates/notes-svc/src/server.js eval/abtest/templates/notes-svc/src/cli.js && git commit -m "fix(abt-u05b): notes-svc template rejects prototype-key tokens, 400s a bad request URL, guards cli main (#593)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/templates/notes-svc/src/store.js`, `eval/abtest/templates/notes-svc/src/format.js`, `eval/abtest/templates/notes-svc/src/seed.js`, `eval/abtest/templates/notes-svc/package.json` (unchanged; store.query keeps its new Function seam on purpose)
- `eval/abtest/templates/notes-svc/test/` (no test file here: the T2 tests for these three fixes are written by abt-u06)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh` (other units own them)
- `tests/validate.sh`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `cd eval/abtest/templates/notes-svc/ && node -e 'const {createServer}=require("./src/server");setTimeout(()=>{console.log("timeout");process.exit(3)},15000).unref();const want="toString=401 constructor=401 valueOf=401 hasOwnProperty=401 __proto__=401 tok-alice=200 tok-bob=200 tok-carol=401";const s=createServer();s.listen(0,async()=>{const u="http://127.0.0.1:"+s.address().port+"/notes";const out=[];for(const t of ["toString","constructor","valueOf","hasOwnProperty","__proto__","tok-alice","tok-bob","tok-carol"]){const r=await fetch(u,{headers:{authorization:"Bearer "+t}});out.push(t+"="+r.status)}const got=out.join(" ");console.log(got);process.exitCode=got===want?0:1;s.close();if(s.closeAllConnections)s.closeAllConnections()})'`
   exit: 0
   stdout: `toString=401 constructor=401 valueOf=401 hasOwnProperty=401 __proto__=401 tok-alice=200 tok-bob=200 tok-carol=401`
   mutation: skip edit 2 (auth.js); the five prototype keys read 200, stdout differs and the exit is 1.
2. run: `cd eval/abtest/templates/notes-svc/ && node -e 'const net=require("node:net");const {createServer}=require("./src/server");setTimeout(()=>{console.log("timeout");process.exit(3)},15000).unref();const s=createServer();s.listen(0,async()=>{const port=s.address().port;const raw=await new Promise((res)=>{let buf="";const c=net.connect(port,"127.0.0.1",()=>c.write("GET http://[ HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer tok-alice\r\nConnection: close\r\n\r\n"));c.on("data",(d)=>{buf+=d});c.on("close",()=>res(buf));c.on("error",()=>res(buf))});const m=/^HTTP\/1\.1 (\d{3}) /.exec(raw);const after=await fetch("http://127.0.0.1:"+port+"/notes",{headers:{authorization:"Bearer tok-alice"}});const line="malformed="+(m?m[1]:"none")+" after="+after.status;console.log(line);process.exitCode=line==="malformed=400 after=200"?0:1;s.close();if(s.closeAllConnections)s.closeAllConnections()})'`
   exit: 0
   stdout: `malformed=400 after=200`
   mutation: skip edit 3 (server.js); the malformed request line crashes the process with an unhandled ERR_INVALID_URL, nothing prints and the exit is 1.
3. run: `cd eval/abtest/templates/notes-svc/ && node -e 'require("./src/cli.js");console.log("exitCode="+process.exitCode)' 2>&1`
   exit: 0
   stdout: `exitCode=undefined`
   mutation: skip edit 4 (cli.js); requiring the file runs main, prints the usage line to stderr (merged by 2>&1) and sets exitCode=2.
4. run: `cd eval/abtest/templates/notes-svc/ && printf '[{"owner":"a","title":"x"}]' | NOTES_SEED=/dev/stdin node src/cli.js list | tr '\t' ' '`
   exit: 0
   stdout: `n1 a 2023-11-14 x`
   mutation: invert the guard in cli.js to require.main !== module; running the file directly prints nothing and the stdout is empty.
   proof: scratch run: with the guard inverted the command printed 0 bytes (od -c showed an empty stream), so the criterion is red; it is green at HEAD by design (regression guard for the direct-run path).
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --shortstat "$c~1..$c" | sed 's/^ *//'`
   exit: 0
   stdout: `3 files changed, 3 insertions(+), 3 deletions(-)`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/templates/notes-svc/src/auth.js eval/abtest/templates/notes-svc/src/cli.js eval/abtest/templates/notes-svc/src/server.js`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/templates/notes-svc/src/auth.js eval/abtest/templates/notes-svc/src/server.js eval/abtest/templates/notes-svc/src/cli.js | grep -vcE "^[a-z]+\(abt-u05b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/templates/notes-svc/`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no the tests for these fixes are written in abt-u06 (its contract is amended to cover them); criteria 1-3 are runnable red-then-green checks
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing. The before/after payloads of edit 3 start mid-line on purpose (the four spaces before const url stay in the file, so the first payload line has no leading spaces); the second payload line keeps its own spaces (4 in before, 6 in after) because they are part of the text.
already-green: criterion 4 (the direct-run regression guard) and criterion 9 (the scoped clean-tree check) pass at HEAD by design; criterion 9 turns red only when the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI. Criteria 1 and 2 start a local http server on port 0 and stop it.
design-note: the three fixes change the baseline only where the baseline was wrong; each edit keeps the line count of the file (auth.js 15, server.js 63, cli.js 25) so the patch hunks that later fixtures apply to src/server.js and src/cli.js keep their context. Do not add a line, a helper or an export. Deliberate baseline traits stay: a negative ?limit is a 400, the CLI list caps at 50, format.date throws on an invalid timestamp.
defensive-criteria: every new check compares the whole expected stdout and also sets a non-zero exit on a mismatch, and each has a 15 second timer, so a crash, a hang or an empty output cannot read as success.
commit-message: fix(abt-u05b): notes-svc template rejects prototype-key tokens, 400s a bad request URL, guards cli main (#593)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05b (#593)
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
