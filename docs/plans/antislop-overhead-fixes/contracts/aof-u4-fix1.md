Unit: aof-u4

## Objective
Fix round 1 for aof-u4 (fix-of: 2026-10-21T00:44:41Z). `node bin/cli.js --update --knowledge-writes=<scoped|apply>` persists the value on an already-current project too, because a changed `knowledgeWrites` no longer takes the "already current" early return. `tests/knowledge-writes.test.sh` runs the flag against an already-current fixture (apply, scoped revert, bogus value, `--dry-run`), and its bogus-value sha256 check now fails when the value check is removed. No version bump: this edits `bin/cli.js` and a test only, and `hooks/scripts/version-stamp-check.sh` stamps only `agents/*.md` and `templates/*`.

## Retrieval
Fast path, no tracker issue. Original issue: #633. Original contract: `docs/plans/antislop-overhead-fixes/contracts/aof-u4.md`, which stays unedited. This file is the fix contract of record. Spec: `docs/plans/antislop-overhead-fixes/spec.md`, "Step 4 (aof-u4)". Run `bash tests/validate.sh` once, in the foreground, after the commit (about 3 to 4 minutes).

## Affected files
- `bin/cli.js` (anchors: line matching `if (knowledgeWrites && config.knowledgeWrites !== knowledgeWrites) {` and line matching `&& !forceRender && !migratedClaudeMd && !needsRender) {`)
- `tests/knowledge-writes.test.sh` (anchors: line matching `ok "fresh install has no knowledgeWrites" || bad "fresh install has no knowledgeWrites"` and line matching `ok "bogus value leaves config unchanged" || bad "bogus value leaves config unchanged"`)
- Version files are NOT touched: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md` stay as they are, and `node bin/cli.js --update` is not run for this unit (no stamped file changes, so no mirror or `fileHashes` change).

## Ordered edits
1. file: `bin/cli.js`
   anchor: line matching `if (knowledgeWrites && config.knowledgeWrites !== knowledgeWrites) {`
   before:
   ~~~
     if (knowledgeWrites && config.knowledgeWrites !== knowledgeWrites) {
   ~~~
   after:
   ~~~
     const knowledgeWritesChanged = Boolean(knowledgeWrites) && config.knowledgeWrites !== knowledgeWrites;
     if (knowledgeWritesChanged) {
   ~~~
   indent: 2
2. file: `bin/cli.js`
   anchor: line matching `&& !forceRender && !migratedClaudeMd && !needsRender) {`
   before: `&& !forceRender && !migratedClaudeMd && !needsRender) {`
   after: `&& !forceRender && !migratedClaudeMd && !needsRender && !knowledgeWritesChanged) {`
3. file: `tests/knowledge-writes.test.sh`
   anchor: line matching `ok "fresh install has no knowledgeWrites" || bad "fresh install has no knowledgeWrites"`
   insert-after:
   ~~~
   # A recorded graph launch command keeps explorer.md renderable, so --dry-run can reach its exit code.
   jq '.substitutions.graphMcpLaunch = {"command":"npx","args":["code-review-graph-mcp"]}' "$C" > "$C.tmp" && mv "$C.tmp" "$C"
   # Reach an already-current project: the first --update bootstraps hashes, the second may still write files.
   (cd "$T" && node "$ROOT/bin/cli.js" --update >/dev/null 2>&1)
   (cd "$T" && node "$ROOT/bin/cli.js" --update >/dev/null 2>&1)
   cur=$(cd "$T" && node "$ROOT/bin/cli.js" --update 2>&1)
   case "$cur" in *'already current'*) ok "fixture is already current" ;; *) bad "fixture is already current" ;; esac
   tree_sum() { (cd "$T" && find . -path ./.git -prune -o -type f ! -name persona-config.json -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1); }
   tree_before=$(tree_sum)
   ~~~
   indent: 0
4. file: `tests/knowledge-writes.test.sh`
   anchor: line matching `ok "bogus value leaves config unchanged" || bad "bogus value leaves config unchanged"`
   insert-after:
   ~~~
   [ "$(jq -r .knowledgeWrites "$C")" = apply ] && ok "bogus value leaves the stored value apply" || bad "bogus value leaves the stored value apply"
   [ "$(tree_sum)" = "$tree_before" ] && ok "already-current flag run touches no other file" || bad "already-current flag run touches no other file"
   (cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes=scoped >/dev/null 2>&1)
   [ "$(jq -r .knowledgeWrites "$C")" = scoped ] && ok "--knowledge-writes=scoped reverts on an already-current project" || bad "--knowledge-writes=scoped reverts on an already-current project"
   before=$(sha256sum "$C" | cut -d' ' -f1)
   dry=$(cd "$T" && node "$ROOT/bin/cli.js" --update --dry-run --knowledge-writes=apply 2>&1); rc=$?
   [ "$rc" = 3 ] && ok "dry-run of a changing flag exits 3" || bad "dry-run of a changing flag exits 3 (got $rc)"
   case "$dry" in *'would be set to "apply"'*) ok "dry-run says would be set" ;; *) bad "dry-run says would be set" ;; esac
   [ "$(sha256sum "$C" | cut -d' ' -f1)" = "$before" ] && ok "dry-run writes nothing" || bad "dry-run writes nothing"
   (cd "$T" && node "$ROOT/bin/cli.js" --update --dry-run --knowledge-writes=scoped >/dev/null 2>&1) && ok "dry-run of an unchanged flag exits 0" || bad "dry-run of an unchanged flag exits 0"
   ~~~
   indent: 0
5. command: `bash tests/knowledge-writes.test.sh`
   expect: 0
6. command: `git add bin/cli.js tests/knowledge-writes.test.sh && git commit -m "fix(aof-u4): --knowledge-writes persists on an already-current project (#633)" -m "<append the trailer lines the dispatch gives>"`
   expect: 0
7. command: `bash tests/validate.sh`
   expect: 0

## Do NOT touch
- `.claude/persona-config.json`: never edited by hand and never named in a Bash command (integrity gate). The test script reads and rewrites only its own `mktemp -d` fixture copy. To check this repo's own setting use the `Read` tool on the file; criterion AC4.2 of the original contract is not re-run here because `jq` on that path names it, and nothing in this fix changes it.
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`: no bump (see Objective).
- `agents/`, `templates/`, `.claude/agents/` and every `.claude/` mirror: no edit, and `node bin/cli.js --update` is not run.
- `adapters/codex/agents/orchestrator.toml` and `adapters/cursor/agents/orchestrator.md`: follow-up 1 below, not in this commit.
- `tests/validate.sh`: the test is already registered.

## Acceptance criteria
1. run: `bash tests/knowledge-writes.test.sh`
   exit: 0
   stdout: `ok   --knowledge-writes=scoped reverts on an already-current project`
   mutation: skip edit 2 (the early return stays); the apply, stored-value and scoped-revert checks print FAIL and the script exits 1.
   proof: replayed in a scratch `git worktree add --detach` checkout with edit 2 reverted; four FAIL lines (sets key, stored value apply, scoped reverts, dry-run of an unchanged flag exits 0).
2. run: `bash tests/knowledge-writes.test.sh | grep -c '^ok'`
   exit: 0
   stdout: `22`
   mutation: skip edit 2; stdout `18`.
3. run: `/usr/bin/grep -cF 'knowledgeWritesChanged' bin/cli.js`
   exit: 0
   stdout: `3`
   mutation: skip edit 2; stdout `2`.
4. run: `bash -c 'W=$(mktemp -d)/wt; git worktree add --detach -q "$W" HEAD && sed -i "s/!\[.scoped., .apply.\]\.includes(knowledgeWrites)/false/" "$W/bin/cli.js" && (cd "$W" && bash tests/knowledge-writes.test.sh | grep -c "^FAIL bogus value leaves config unchanged"); git worktree remove --force "$W"'`
   exit: 0
   stdout: `1`
   mutation: revert edit 2 in HEAD before running; stdout `0` (the sha256 assertion no longer catches a persisted bogus value).
   proof: the sed above removes the value check in a scratch worktree; replayed with edits 1 to 4 applied, stdout `1`.
5. run: `git log -1 --format=%s`
   exit: 0
   stdout: `fix(aof-u4): --knowledge-writes persists on an already-current project (#633)`
   mutation: commit with any other subject; stdout differs.
6. run: `git show --name-only --format= HEAD | sort | tr '\n' ' '`
   exit: 0
   stdout: `bin/cli.js tests/knowledge-writes.test.sh`
   mutation: also stage `CHANGELOG.md`; the list gains a path.
7. run: `git log -1 --format=%B | /usr/bin/grep -c '^Co-Authored-By: '`
   exit: 0
   stdout: `1`
   mutation: commit without the trailer lines; exit 1, stdout `0`.
8. run: `bash tests/validate.sh | tail -1`
   exit: 0
   stdout: `All checks passed.`
   mutation: make edit 3 drop its closing `esac` line; the test exits non-zero, validate.sh prints `One or more checks FAILED.`

## Pre-resolved context
tdd: yes tests/knowledge-writes.test.sh
blast-radius: bin/cli.js:1206 bin/cli.js:1532 bin/cli.js:1642 bin/cli.js:1662
- Cause: the config write sits after the "already current ... Nothing to update." early return at `bin/cli.js:1532`; a changed `knowledgeWrites` set in memory at line 1206 is never persisted on a current project. The fix keeps the early return for every other case and adds `!knowledgeWritesChanged` to its condition, so a changed value falls through to the existing single config write (`writeConfigOrReport`, line 1662) and no second writer is added. The render loop is a no-op on a current project; the test pins this (`already-current flag run touches no other file`).
- `--dry-run`: `forceRender` already includes `dryRun`, so a dry run never takes the early return and already exits 3 through `writeConfigOrReport` when the value would change. The reviewer's claim that dry-run exits 0 does not reproduce in a clean fixture (it exits 1 in the old fixture only because explorer.md has an unrecorded launch command, an unrelated condition that edit 3's `jq` line removes). The dry-run checks in edit 4 are regression pins, green before and after the fix; the exit-3 and "would be set" behaviour needs no cli.js change.
- (d) was vacuous because the old flow returned early without writing; after edit 2 a bogus value with the check removed reaches the write, so the sha256 half now fails on its own (criterion 4).
- Version rule: constitution P3 and `version-stamp-check.sh` fire only for `agents/*.md` and `templates/*`. This commit touches neither, so the expected version stays 0.31.187 and the CHANGELOG is untouched.
- Replayed in a scratch worktree: with edits 1 to 4 applied, `bash tests/knowledge-writes.test.sh` prints 22 `ok` lines and exits 0; with edit 2 reverted it prints 4 FAIL lines.
- Fixture note: the first `--update` after a fresh install bootstraps hashes and may exit non-zero; the test ignores those two exit codes and asserts the third run prints `already current`.
commit-message: fix(aof-u4): --knowledge-writes persists on an already-current project (#633)
- Append the trailer lines the dispatch gives after the commit message.
- Follow-ups, listed only and NOT done here: (1) `adapters/codex/agents/orchestrator.toml:96-98` and `adapters/cursor/agents/orchestrator.md:90-92` still say "When you dispatch scribe for a unit, quote the reviewer's PASS verdict line..." and disagree with `agents/orchestrator.md`; the original contract's "no scribe convention text" premise was wrong. It needs its own unit (adapter files are outside this scope and may carry pinned port tests). (2) `--knowledge-writes` is silently ignored in fresh-install mode and in the space-separated form `--knowledge-writes apply`; a warning or error needs its own unit and a decision on which. (3) The orchestrator's scribe skip rule does not depend on `knowledgeWrites`, and batching leaves the issues of passed units open if a later unit never passes. Not to be fixed here.
diagnosis: none
review-packet:
~~~
unit: aof-u4 (#633)
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
