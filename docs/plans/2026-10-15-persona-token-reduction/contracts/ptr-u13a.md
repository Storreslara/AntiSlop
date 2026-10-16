Unit: ptr-u13a

## Objective
`bin/ladder-tier.sh` resolves a present `defaultImplementerModel` that is not `haiku`, `sonnet` or `opus` (`""`, `null`, `false`) to `opus` and an absent key to the frontmatter model; `scripts/unit-outcomes.js` takes a unit's contract from the file its issue body names or from `docs/plans/*/contracts/<id>.md` and reports `contract_source` as `file:<path>`; the main-session section of `scripts/token-usage/agg2.py` honours `--since` and `--until`. Three commits, one per item, each with its CHANGELOG entry; no version bump.

## Retrieval
GitHub issues: `gh issue view 564 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, section "Step U13a".

## Affected files
- `bin/ladder-tier.sh` (anchor: line matching `v="$(jq -r '.defaultImplementerModel // empty' "$cfg" 2>/dev/null)" || return 1`)
- `tests/ladder-tier.test.sh` (anchor: line matching `BADJSON) printf '{ not json`)
- `scripts/unit-outcomes.js` (anchor: line matching `function contractFor(id, recs, opt) {`)
- `tests/unit-outcomes.test.js` (anchor: line matching `fs.writeFileSync(path.join(dir, 'agents', 'lead-programmer.md')`)
- `tests/fixtures/unit-outcomes/contracts/fx-cfile.md`, `tests/fixtures/unit-outcomes/contracts/fx-cfile2.md`, `tests/fixtures/unit-outcomes/markers/fx-cfile.pass`, `tests/fixtures/unit-outcomes/markers/fx-cfile2.pass`, `tests/fixtures/unit-outcomes/issues/fx-cfile.json` (anchor: new file)
- `scripts/token-usage/agg2.py` (anchor: line matching `if ctxs: rows.append((ctxs[0]`)
- `tests/token-usage.test.sh` (anchor: line matching `echo "token-usage: $passed/$total passed"`)
- `tests/fixtures/token-usage-main/m1.jsonl` (anchor: new file)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. command: `test ! -e tests/fixtures/token-usage-main && test ! -e tests/fixtures/unit-outcomes/contracts && git log --format=%s | grep -qE '^[a-z]+\(ptr-u7b-2\): ' && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `bin/ladder-tier.sh`
   anchor: line matching `v="$(jq -r '.defaultImplementerModel // empty' "$cfg" 2>/dev/null)" || return 1`
   before: `v="$(jq -r '.defaultImplementerModel // empty' "$cfg" 2>/dev/null)" || return 1`
   after: `v="$(jq -r 'if has("defaultImplementerModel") then (.defaultImplementerModel | if . == "haiku" or . == "sonnet" or . == "opus" then . else "opus" end) else "" end' "$cfg" 2>/dev/null)" || return 1`
3. file: `tests/ladder-tier.test.sh`
   anchor: line matching `BADJSON) printf '{ not json`
   indent: 3
   insert-after:
   ~~~~
       EMPTYSTR) printf '{"defaultImplementerModel":""}\n' > "$p/.claude/persona-config.json" ;;
       NULLVAL) printf '{"defaultImplementerModel":null}\n' > "$p/.claude/persona-config.json" ;;
       FALSEVAL) printf '{"defaultImplementerModel":false}\n' > "$p/.claude/persona-config.json" ;;
   ~~~~
4. file: `tests/ladder-tier.test.sh`
   anchor: line matching `check "bogus default n=2 is exhausted"`
   indent: 3
   insert-after:
   ~~~~
   p="$(mkproj EMPTYSTR)"
   check "empty-string default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
   p="$(mkproj NULLVAL)"
   check "null default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
   p="$(mkproj FALSEVAL)"
   check "false default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
   ~~~~
5. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~~

   **Ladder-tier default read tells a missing key from a bad value (ptr-u13a).** `bin/ladder-tier.sh` now reads `defaultImplementerModel` with one `jq` call that tells an absent key (the lead-programmer frontmatter model, as before) from a present key whose value is not the string `haiku`, `sonnet` or `opus` (`""`, `null`, `false`, a number), which resolves to `opus` as the orchestrator prose already says; `tests/ladder-tier.test.sh` gains three rows. Closes the ptr-u9a spec note on `bin/ladder-tier.sh`. No version bump.
   ~~~~
6. command: `git add bin/ladder-tier.sh tests/ladder-tier.test.sh CHANGELOG.md && git commit -m "fix(ptr-u13a): ladder-tier default read tells a missing key from a bad value (#564)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
7. command: `mkdir -p tests/fixtures/unit-outcomes/contracts && sed '1s/.*/Unit: fx-cfile/' tests/fixtures/contract-score/v2-all-pass.md > tests/fixtures/unit-outcomes/contracts/fx-cfile.md && sed '1s/.*/Unit: fx-cfile2/' tests/fixtures/contract-score/v2-all-pass.md > tests/fixtures/unit-outcomes/contracts/fx-cfile2.md`
   expect: 0
8. file: `tests/fixtures/unit-outcomes/markers/fx-cfile.pass`
   anchor: new file
   insert-after: `PASS fx-cfile 2026-09-05T12:00:00Z commit: none criteria: fixture`
9. file: `tests/fixtures/unit-outcomes/markers/fx-cfile2.pass`
   anchor: new file
   insert-after: `PASS fx-cfile2 2026-09-05T13:00:00Z commit: none criteria: fixture`
10. file: `tests/fixtures/unit-outcomes/issues/fx-cfile.json`
   anchor: new file
   indent: 3
   insert-after:
   ~~~~
   [
    {
     "number": 903,
     "title": "[fx-cfile] contract file fixture",
     "createdAt": "2026-09-03T09:00:00Z",
     "body": "Fixture unit.\n\nContract file (scribe, dispatch first): docs/plans/fx-plan/contracts/fx-cfile.scribe.md\nContract file: docs/plans/fx-plan/contracts/fx-cfile.md\n",
     "labels": []
    }
   ]
   ~~~~
11. file: `scripts/unit-outcomes.js`
   anchor: line matching `// An issue belongs to a unit only if its contract's Unit: token`
   indent: 3
   before:
   ~~~~
   // An issue belongs to a unit only if its contract's Unit: token or its title's first word is the exact id.
   function issueIsUnit(issue, id) {
     const block = contractBlock(issue.body || '');
     const u = block && /^Unit:\s*(\S+)/.exec(block);
     return (u && u[1] === id) || (issue.title || '').split(/\s+/)[0] === id;
   }
   ~~~~
   after:
   ~~~~
   // The contract file an issue body names: its first unqualified `Contract file: <path>` line, resolved
   // against --repo, when the file exists and its line 1 is exactly `Unit: <id>`; else null.
   function fileContract(body, id, opt) {
     const m = /^Contract file: (\S+)[ \t]*$/m.exec(body || '');
     return m ? readContract(m[1], id, opt) : null;
   }

   function readContract(rel, id, opt) {
     const abs = path.resolve(opt.repo, rel);
     if (!abs.startsWith(opt.repo + path.sep)) return null;
     try {
       const text = fs.readFileSync(abs, 'utf8');
       return text.split('\n')[0] === `Unit: ${id}` ? { rel: path.relative(opt.repo, abs), text } : null;
     } catch (e) { return null; }
   }

   // docs/plans/*/contracts/<id>.md (sorted, first) whose line 1 is `Unit: <id>`; null when none.
   function planContract(id, opt) {
     const dir = path.join(opt.repo, 'docs', 'plans');
     if (!fs.existsSync(dir)) return null;
     for (const d of fs.readdirSync(dir).sort()) {
       const c = readContract(path.join('docs', 'plans', d, 'contracts', `${id}.md`), id, opt);
       if (c) return c;
     }
     return null;
   }

   // Committer date of the oldest commit that touched the contract file; null when unknown.
   function fileTs(rel, opt) {
     try {
       const out = cp.execFileSync('git', ['log', '--format=%cI', '--', rel],
         { cwd: opt.repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
       return out.split('\n').filter(Boolean).pop() || null;
     } catch (e) { return null; }
   }

   // An issue belongs to a unit only if its contract's Unit: token, its title's first word (the exact id,
   // or `[<id>]`) or the contract file its body names is the exact id.
   function issueIsUnit(issue, id, opt) {
     const block = contractBlock(issue.body || '');
     const u = block && /^Unit:\s*(\S+)/.exec(block);
     const first = (issue.title || '').split(/\s+/)[0];
     return (u && u[1] === id) || first === id || first === `[${id}]` || fileContract(issue.body, id, opt) !== null;
   }
   ~~~~
12. file: `scripts/unit-outcomes.js`
   anchor: line matching `return JSON.parse(out).find((i) => issueIsUnit(i, id)) || null;`
   before: `return JSON.parse(out).find((i) => issueIsUnit(i, id)) || null;`
   after: `return JSON.parse(out).find((i) => issueIsUnit(i, id, opt)) || null;`
13. file: `scripts/unit-outcomes.js`
   anchor: line matching `// Source order: issue Dispatch-contract block, plan block`
   indent: 3
   before:
   ~~~~
   // Source order: issue Dispatch-contract block, plan block, transcript with `## Ordered edits`, none.
   function contractFor(id, recs, opt) {
     const issue = ghIssue(id, opt);
     const block = issue && contractBlock(issue.body || '');
     if (block !== null) {
       const label = (issue.labels || []).map((l) => l.name).find((n) => n.startsWith('plan/'));
       return { source: `issue#${issue.number}`, author: 'task-master', plan: label ? label.slice(5) : null,
   ~~~~
   after:
   ~~~~
   // Source order: the contract file the issue body names, docs/plans/*/contracts/<id>.md, the issue
   // Dispatch-contract block, plan block, transcript with `## Ordered edits`, none.
   function contractFor(id, recs, opt) {
     const issue = ghIssue(id, opt);
     const label = issue && (issue.labels || []).map((l) => l.name).find((n) => n.startsWith('plan/'));
     const named = issue && fileContract(issue.body, id, opt);
     if (named) {
       return { source: `file:${named.rel}`, author: 'task-master', plan: label ? label.slice(5) : null,
         text: named.text, ts: issue.createdAt || null };
     }
     const found = planContract(id, opt);
     if (found) {
       return { source: `file:${found.rel}`, author: 'spec-master', plan: found.rel.split(path.sep)[2],
         text: found.text, ts: fileTs(found.rel, opt) };
     }
     const block = issue && contractBlock(issue.body || '');
     if (block !== null) {
       return { source: `issue#${issue.number}`, author: 'task-master', plan: label ? label.slice(5) : null,
   ~~~~
14. file: `tests/unit-outcomes.test.js`
   anchor: line matching `fs.writeFileSync(path.join(dir, 'agents', 'lead-programmer.md')`
   indent: 3
   insert-after:
   ~~~~
     fs.mkdirSync(path.join(dir, 'docs', 'plans', 'fx-plan', 'contracts'), { recursive: true });
     ['fx-cfile', 'fx-cfile2'].forEach((n) => fs.copyFileSync(path.join(FIX, 'contracts', `${n}.md`),
       path.join(dir, 'docs', 'plans', 'fx-plan', 'contracts', `${n}.md`)));
   ~~~~
15. file: `tests/unit-outcomes.test.js`
   anchor: line matching `assert.strictEqual(R['fx-tilde5'].contract_score, 7);`
   indent: 3
   before:
   ~~~~
     assert.strictEqual(R['fx-tilde5'].contract_score, 7);
   });
   ~~~~
   after:
   ~~~~
     assert.strictEqual(R['fx-tilde5'].contract_score, 7);
   });
   check('contract file named by the issue body wins over a qualified line and the legacy block', () => {
     assert.strictEqual(R['fx-cfile'].contract_source, 'file:docs/plans/fx-plan/contracts/fx-cfile.md');
     assert.notStrictEqual(R['fx-cfile'].contract_score, null);
   });
   check('contract file found by plan scan when no issue exists', () => {
     assert.strictEqual(R['fx-cfile2'].contract_source, 'file:docs/plans/fx-plan/contracts/fx-cfile2.md');
     assert.strictEqual(R['fx-cfile2'].contract_author, 'spec-master');
     assert.strictEqual(R['fx-cfile2'].plan, 'fx-plan');
     assert.notStrictEqual(R['fx-cfile2'].contract_score, null);
   });
   ~~~~
16. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~~

   **Unit-outcomes export reads contract files (ptr-u13a).** `scripts/unit-outcomes.js` now takes a unit's contract from the file its issue body names (the first unqualified `Contract file: <path>` line, resolved against `--repo`) or else from `docs/plans/*/contracts/<id>.md`, before the legacy `## Dispatch contract` block; the row's `contract_source` reads `file:<path>`, and an issue titled `[<id>] ...` now counts as the unit's issue. Closes the ptr-u3b spec note on `scripts/unit-outcomes.js`. No version bump.
   ~~~~
17. command: `git add scripts/unit-outcomes.js tests/unit-outcomes.test.js tests/fixtures/unit-outcomes CHANGELOG.md && git commit -m "fix(ptr-u13a): unit-outcomes export reads contract files (#564)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
18. file: `tests/fixtures/token-usage-main/m1.jsonl`
   anchor: new file
   insert-after: `{"type":"assistant","timestamp":"2026-01-01T00:00:00Z","message":{"usage":{"input_tokens":10},"content":[]}}`
19. file: `scripts/token-usage/agg2.py`
   anchor: line matching `ctxs = []; n = 0`
   before: `ctxs = []; n = 0`
   after: `ctxs = []; n = 0; t0 = None`
20. file: `scripts/token-usage/agg2.py`
   anchor: line matching `u = (r.get('message') or {}).get('usage') or {}`
   indent: 3
   before: `u = (r.get('message') or {}).get('usage') or {}`
   after:
   ~~~~
   u = (r.get('message') or {}).get('usage') or {}
           if u and t0 is None: t0 = r.get('timestamp')
   ~~~~
21. file: `scripts/token-usage/agg2.py`
   anchor: line matching `if ctxs: rows.append((ctxs[0]`
   before: `if ctxs: rows.append((ctxs[0], med(ctxs), max(ctxs), len(ctxs), sum(ctxs)))`
   after: `if ctxs and in_range([{'timestamp': t0}], SINCE, UNTIL): rows.append((ctxs[0], med(ctxs), max(ctxs), len(ctxs), sum(ctxs)))`
22. file: `tests/token-usage.test.sh`
   anchor: line matching `echo "token-usage: $passed/$total passed"`
   indent: 3
   before: `echo "token-usage: $passed/$total passed"`
   after:
   ~~~~
   mroot=tests/fixtures/token-usage-main
   agg2m() { python3 -I scripts/token-usage/agg2.py --root "$mroot" 36500 "$@"; }

   agg2m --since 2026-01-02T00:00:00Z | grep -q 'sessions=0'
   check "agg2 main-session section: --since after the session's first usage record drops it" "$?"

   agg2m --since 2025-12-31T00:00:00Z | grep -q 'sessions=1 '
   check "agg2 main-session section: --since before the first usage record keeps it" "$?"

   agg2m --until 2026-01-01T00:00:00Z | grep -q 'sessions=0'
   check "agg2 main-session section: --until at the first usage record drops it" "$?"

   echo "token-usage: $passed/$total passed"
   ~~~~
23. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~~

   **Main-session window in agg2.py (ptr-u13a).** The main-session section of `scripts/token-usage/agg2.py` now applies the same `[since, until)` window as its subagent section, using the timestamp of the session's first assistant record that carries `usage`; with `--since` or `--until` given, a session with no such timestamp is excluded, and the mtime day cut is unchanged. `tests/token-usage.test.sh` gains three rows over the new `tests/fixtures/token-usage-main` root. Closes the ptr-u0b spec note on `agg2.py`. No version bump.
   ~~~~
24. command: `git add scripts/token-usage/agg2.py tests/token-usage.test.sh tests/fixtures/token-usage-main CHANGELOG.md && git commit -m "fix(ptr-u13a): agg2 main-session section honours the since/until window (#564)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/`, `templates/`, `.claude-plugin/plugin.json` and `package.json` (no persona file changes and no version bump in this unit; the prose is ptr-u13b and ptr-u13c)
- `tests/validate.sh` (the three suites are already registered at lines 708, 1343 and 1355)
- `tests/fixtures/token-usage/` (a separate fixture root is added so the existing pins do not move)
- `.claude/` and `docs/` (never edit a mirror or a plan by hand)

## Acceptance criteria
1. run: `bash tests/ladder-tier.test.sh > /dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 2 (the jq read); the three new rows FAIL and the line reads exit=1.
   proof: regression guard: the suite is green at HEAD before the rows exist, so criterion 2 is the red-then-green check; scratch run with edit 2 skipped printed exit=1.
2. run: `bash tests/ladder-tier.test.sh | grep -cE '^OK   (empty-string|null|false) default n=0 resolves to opus$'`
   exit: 0
   stdout: `3`
   mutation: skip edit 2; the three rows print FAIL, so stdout is 0 and the exit is 1.
3. run: `node tests/unit-outcomes.test.js | grep -cE '^(OK   contract file|All unit-outcomes checks passed)'`
   exit: 0
   stdout: `3`
   mutation: skip edit 13 (the contractFor edit, so branches 1 and 2 are gone); fx-cfile reports none, the two rows FAIL and stdout is 0.
4. run: `bash tests/token-usage.test.sh | grep -cE '^(ok   agg2 main-session section|token-usage: 9/9 passed)'`
   exit: 0
   stdout: `4`
   mutation: skip edit 21 (the window test); two rows FAIL and the summary reads 7/9, so stdout is not 4.
5. run: `test -f tests/fixtures/token-usage-main/m1.jsonl && python3 -I scripts/token-usage/agg2.py --root tests/fixtures/token-usage-main 36500 --since 2026-01-02T00:00:00Z | grep -c 'sessions=0'`
   exit: 0
   stdout: `1`
   mutation: skip edit 21; the session is kept, the output reads sessions=1, stdout is 0 and the exit is 1.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; echo "$L" | wc -l`
   exit: 0
   stdout: `3`
   mutation: skip edit 24 (the last commit); two commits remain, stdout 2.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 3p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `CHANGELOG.md bin/ladder-tier.sh tests/ladder-tier.test.sh`
   mutation: skip edit 6 (the first commit); the list is empty or another commit and the fragment is absent.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 2p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `CHANGELOG.md scripts/unit-outcomes.js tests/fixtures/unit-outcomes/contracts/fx-cfile.md tests/fixtures/unit-outcomes/contracts/fx-cfile2.md tests/fixtures/unit-outcomes/issues/fx-cfile.json tests/fixtures/unit-outcomes/markers/fx-cfile.pass tests/fixtures/unit-outcomes/markers/fx-cfile2.pass tests/unit-outcomes.test.js`
   mutation: skip edit 17 (the second commit); the middle commit is another item and the fragment is absent.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `CHANGELOG.md scripts/token-usage/agg2.py tests/fixtures/token-usage-main/m1.jsonl tests/token-usage.test.sh`
   mutation: skip edit 24 (the last commit); the newest commit is another item and the fragment is absent.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done | paste -sd" "`
   exit: 0
   stdout: `1 1 1`
   mutation: skip edit 24; only two commits exist and stdout reads 1 1.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -cE "^(agents/|templates/|[.]claude-plugin/|package[.]json|[.]claude/)"; done | paste -sd" "`
   exit: 0
   stdout: `0 0 0`
   mutation: skip edit 24; two commits remain and stdout reads 0 0.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- bin/ladder-tier.sh scripts/unit-outcomes.js scripts/token-usage/agg2.py | grep -vcE "^[a-z]+\(ptr-u13a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching scripts/unit-outcomes.js after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit makes grep -v count it, so stdout is 1.
13. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 24; the edits of item (f) stay uncommitted and stdout is non-zero.
14. run: `bash tests/validate-lanes.sh --lanes 4`
   exit: 0
   stdout: `All checks passed.`
   mutation: skip edit 2 (the jq read) before the first commit; the ladder-tier section prints FAIL and the run exits 1.
   proof: scratch run: the lanes gate over the replayed chain printed All checks passed.

## Pre-resolved context
tdd: yes tests/ladder-tier.test.sh tests/unit-outcomes.test.js tests/token-usage.test.sh (each item's rows are edits of the same commit; criteria 1-5 are the red-then-green checks)
blast-radius: bin/ladder-tier.sh:66 scripts/unit-outcomes.js:172 scripts/unit-outcomes.js:178 scripts/unit-outcomes.js:211 scripts/token-usage/agg2.py:114 tests/validate.sh:708 tests/validate.sh:1343 tests/validate.sh:1355 (grep-derived, no graph run)
gate-run: criterion 14 runs the lanes gate in the foreground (about 2-3 minutes; pass the 600000 ms timeout; never background it; it refuses a linked worktree, so use the normal checkout). If it fails only in tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5), both timing-flaky and unrelated, rerun that test alone and the lanes once more, and report both runs. `node tests/unit-outcomes.test.js` takes about 100 seconds on its own; pass the 600000 ms timeout to criterion 3.
gate-refusal: no command in this contract names the persona config file, and none needs to. If any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). The test payloads of edits 2 and 3 name that file inside a test script; apply them with the Edit tool, never with a Bash heredoc.
staging: each commit command stages explicit paths only; if criterion 11 shows an agent-memory path in a commit, STOP and report.
payload-indent: every fenced payload is written with the contract's own 3-space indent; strip exactly 3 leading spaces from each non-empty payload line (empty lines stay empty); a payload line that is indented further keeps its extra spaces. Use the Edit tool for every before/after and insert-after item; each `before:` is a verbatim run of lines from the file.
item order: items (a), (e) and (f) are three commits in that order; each CHANGELOG insert goes after the `## [Unreleased]` line, so the newest entry ends up on top.
commit-message: fix(ptr-u13a): ladder-tier default read tells a missing key from a bad value (#564)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
commit-message: fix(ptr-u13a): unit-outcomes export reads contract files (#564)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
commit-message: fix(ptr-u13a): agg2 main-session section honours the since/until window (#564)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u13a (#564)
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
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
