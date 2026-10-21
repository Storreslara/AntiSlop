Unit: rp-u4

## Objective
Finding E, operator ruling OQ4 (2026-10-20): `--knowledge-writes` is never silently ignored. After this unit,
in `bin/cli.js`:
- one helper, `parseKnowledgeWritesFlag(args)`, reads the flag for both `--update` and a fresh install.
  The space-separated form `--knowledge-writes <v>` (a bare `--knowledge-writes` argument) exits 2 with
  `--knowledge-writes takes the form --knowledge-writes=<scoped|apply>.` before anything is written. An
  invalid `=` value still exits 1 with the existing message.
- a fresh install (`--target=claude`, the default) honours `--knowledge-writes=<v>`: the new
  `persona-config.json` carries the key; with `--overwrite` over an existing install the key is set too.
  With `--target=cursor` or `--target=codex` the value is not used and a one-line note says so on stderr.
- `--update` keeps its behaviour, now pinned: the `Note: knowledgeWrites set to "<v>".` line prints before
  rendering, the value is saved even when a render unrelated to the flag fails (a pristine install with no
  recorded graph launch command), and the exit code is the render's, the same as the same run without the
  flag; `=scoped` on a project with no key writes the key explicitly.
`tests/knowledge-writes.test.sh` gains one case per form. This is spec Step 4.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 4 (rp-u4)" and
Clarifications (Open Question 4, ruled 2026-10-20). This file is the contract of record. Dispatch after st-u4
(`bin/cli.js` is shared with qw-u6, st-u1, st-u2 and st-u4; the anchor check found no shared line).

## Affected files
- `tests/knowledge-writes.test.sh` (anchor: line matching `for f in agents/scribe.md .claude/agents/scribe.md; do has "$f" 'Knowledge writes follow unit scope'; done`)
- `bin/cli.js` (anchors: line matching `async function runUpdate(args) {`; line matching `  const kwFlag = args.find((a) => a.startsWith('--knowledge-writes='));`; line matching `    return runWireMcp('arxiv', args);`; line matching `    existingPersonaConfig.pluginVersion = version;`; line matching `      defaultImplementerModel: 'haiku',`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md` (version stamps), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/knowledge-writes.test.sh`
   anchor: line matching `for f in agents/scribe.md .claude/agents/scribe.md; do has "$f" 'Knowledge writes follow unit scope'; done`
   indent: 0
   before: `for f in agents/scribe.md .claude/agents/scribe.md; do has "$f" 'Knowledge writes follow unit scope'; done`
   after:
~~~
# rp-u4: the space form is refused, a fresh install honours the flag, and --update's save and exit code are pinned.
before=$(sha256sum "$C" | cut -d' ' -f1)
err=$(cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes apply 2>&1 >/dev/null); rc=$?
[ "$rc" = 2 ] && ok "space form on --update exits 2" || bad "space form on --update exits 2 (got $rc)"
case "$err" in *'takes the form --knowledge-writes=<scoped|apply>'*) ok "space form names the = form" ;; *) bad "space form names the = form" ;; esac
[ "$(sha256sum "$C" | cut -d' ' -f1)" = "$before" ] && ok "space form leaves config unchanged" || bad "space form leaves config unchanged"
F1=$(mktemp -d); F2=$(mktemp -d); F3=$(mktemp -d); F4=$(mktemp -d); trap 'rm -rf "$T" "$F1" "$F2" "$F3" "$F4"' EXIT
for d in "$F1" "$F2" "$F3" "$F4"; do git -C "$d" init -q; done
(cd "$F1" && node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe --knowledge-writes=apply >/dev/null 2>&1)
[ "$(jq -r .knowledgeWrites "$F1/.claude/persona-config.json" 2>/dev/null)" = apply ] && ok "fresh install honours --knowledge-writes=apply" || bad "fresh install honours --knowledge-writes=apply"
(cd "$F2" && node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe --knowledge-writes apply >/dev/null 2>&1); rc=$?
[ "$rc" = 2 ] && [ ! -e "$F2/.claude" ] && ok "fresh-install space form exits 2 and writes nothing" || bad "fresh-install space form (rc=$rc)"
(cd "$F3" && node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe >/dev/null 2>&1)
(cd "$F4" && node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe >/dev/null 2>&1)
(cd "$F3" && node "$ROOT/bin/cli.js" --update >/dev/null 2>&1); rc_plain=$?
out=$(cd "$F4" && node "$ROOT/bin/cli.js" --update --knowledge-writes=scoped 2>&1); rc_flag=$?
[ "$rc_flag" = "$rc_plain" ] && ok "pristine --update exit code is the render's with or without the flag ($rc_flag)" || bad "exit code differs: plain $rc_plain flag $rc_flag"
[ "$(jq -r .knowledgeWrites "$F4/.claude/persona-config.json")" = scoped ] && ok "=scoped on a project with no key writes the key" || bad "=scoped on a project with no key writes the key"
case "$out" in *'Note: knowledgeWrites set to "scoped".'*) ok "pristine --update prints the Note line" ;; *) bad "pristine --update prints the Note line" ;; esac

for f in agents/scribe.md .claude/agents/scribe.md; do has "$f" 'Knowledge writes follow unit scope'; done
~~~
2. command: `bash -c 'bash tests/knowledge-writes.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `4` (space form on `--update`: exit code and message; fresh install honours the flag; fresh-install space form). The other new rows pass today: the space form is read as no flag, so the config is unchanged, and `--update`'s save, Note line and exit code are already as pinned.
3. file: `bin/cli.js`
   anchor: line matching `async function runUpdate(args) {`
   indent: 0
   before: `async function runUpdate(args) {`
   after:
~~~
// rp-u4: --knowledge-writes is read only in its `=` form, by --update and by a fresh install alike. A bare
// `--knowledge-writes` (the space form, whose value would otherwise be silently dropped) exits 2 before
// anything is written; an invalid `=` value exits 1. Returns the value or null.
function parseKnowledgeWritesFlag(args) {
  if (args.includes('--knowledge-writes')) {
    console.error('--knowledge-writes takes the form --knowledge-writes=<scoped|apply>.');
    process.exit(2);
  }
  const kwFlag = args.find((a) => a.startsWith('--knowledge-writes='));
  const value = kwFlag ? kwFlag.slice('--knowledge-writes='.length) : null;
  if (kwFlag && !['scoped', 'apply'].includes(value)) {
    console.error(`--knowledge-writes must be one of: scoped, apply (got "${value}").`);
    process.exit(1);
  }
  return value;
}

async function runUpdate(args) {
~~~
4. file: `bin/cli.js`
   anchor: line matching `  const kwFlag = args.find((a) => a.startsWith('--knowledge-writes='));` (inside `runUpdate`)
   indent: 2
   before:
~~~
  const kwFlag = args.find((a) => a.startsWith('--knowledge-writes='));
  const knowledgeWrites = kwFlag ? kwFlag.slice('--knowledge-writes='.length) : null;
  if (kwFlag && !['scoped', 'apply'].includes(knowledgeWrites)) {
    console.error(`--knowledge-writes must be one of: scoped, apply (got "${knowledgeWrites}").`);
    process.exit(1);
  }
~~~
   after: `  const knowledgeWrites = parseKnowledgeWritesFlag(args);`
5. file: `bin/cli.js`
   anchor: line matching `    return runWireMcp('arxiv', args);`
   indent: 2
   before:
~~~
  if (args.some((a) => a === '--wire-arxiv-mcp' || a.startsWith('--wire-arxiv-mcp='))) {
    return runWireMcp('arxiv', args);
  }

  const targetFlag = args.find((a) => a.startsWith('--target='));
  const target = targetFlag ? targetFlag.slice('--target='.length).trim() : 'claude';
~~~
   after:
~~~
  if (args.some((a) => a === '--wire-arxiv-mcp' || a.startsWith('--wire-arxiv-mcp='))) {
    return runWireMcp('arxiv', args);
  }

  const knowledgeWrites = parseKnowledgeWritesFlag(args);
  const targetFlag = args.find((a) => a.startsWith('--target='));
  const target = targetFlag ? targetFlag.slice('--target='.length).trim() : 'claude';
  if (knowledgeWrites && target !== 'claude') {
    console.error(`Note: --knowledge-writes applies only to --target=claude; ignored for --target=${target}.`);
  }
~~~
6. file: `bin/cli.js`
   anchor: line matching `    existingPersonaConfig.pluginVersion = version;`
   indent: 4
   before:
~~~
    existingPersonaConfig.pluginVersion = version;
    fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(existingPersonaConfig, null, 2) + '\n');
~~~
   after:
~~~
    existingPersonaConfig.pluginVersion = version;
    if (knowledgeWrites) existingPersonaConfig.knowledgeWrites = knowledgeWrites;
    fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(existingPersonaConfig, null, 2) + '\n');
~~~
7. file: `bin/cli.js`
   anchor: line matching `      defaultImplementerModel: 'haiku',`
   indent: 4
   before:
~~~
      defaultImplementerModel: 'haiku',
      pluginVersion: version,
      personaSelection,
      issueTracker: '',
    };
~~~
   after:
~~~
      defaultImplementerModel: 'haiku',
      pluginVersion: version,
      personaSelection,
      issueTracker: '',
      ...(knowledgeWrites ? { knowledgeWrites } : {}),
    };
~~~
8. command: `bash tests/knowledge-writes.test.sh`
   expect: 0
9. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected one above what st-u4 wrote, 0.31.201 to 0.31.202 with no fix rounds).
10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**`--knowledge-writes` is never silently ignored (rp-u4, VERSION).** bin/cli.js: the space form `--knowledge-writes <v>` now exits 2 with a usage line instead of being dropped; a fresh install honours `--knowledge-writes=<scoped|apply>` (and `--overwrite` sets it too); `--target=cursor|codex` prints a note that it is ignored there. `--update` is unchanged and now pinned: the value is saved and the Note line printed even when an unrelated render fails, and the exit code is the render's. New cases in tests/knowledge-writes.test.sh.
~~~
   Replace `VERSION` with the version that edit 9 wrote.
11. command: `node bin/cli.js --update`
   expect: 0
12. command: `git add -u && git commit -m "fix(rp-u4): --knowledge-writes is never silently ignored; space form refused, fresh install honours it"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `templates/persona-config.schema.json` (the enum is unchanged; criterion 4)
- `agents/scribe.md`, `agents/spec-master.md`, `agents/orchestrator.md` (the knowledgeWrites prose is unchanged; criterion 4)
- `README.md` (no `--knowledge-writes` documentation exists to update; criterion 4)

## Acceptance criteria
1. run: `bash -c 'bash tests/knowledge-writes.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: delete the `if (args.includes('--knowledge-writes')) { ... }` block in `parseKnowledgeWritesFlag`; the two space-form cases fail and stdout is `1`.
2. run: `bash -c 'grep -c "parseKnowledgeWritesFlag(args)" bin/cli.js; grep -c "args.find((a) => a.startsWith(.--knowledge-writes=.))" bin/cli.js'`
   exit: 0
   stdout: `3` then `1` (two lines: the definition and two calls; one `=` parse)
   mutation: keep the old parsing in `runUpdate` instead of edit 4; the second count is `2`.
3. run: `node -e "require('./bin/cli.js'); console.log('loads')"`
   exit: 0
   stdout: `loads`
   mutation: drop the closing brace of `parseKnowledgeWritesFlag`; node reports a SyntaxError and exits 1.
4. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u4): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u4): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/cli.js package.json tests/knowledge-writes.test.sh `
   mutation: also edit `README.md` in an rp-u4 commit; it joins the list.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u4): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u4): " | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: no`
   mutation: also edit `templates/persona-config.schema.json` in an rp-u4 commit with no bump; stdout reads `version-stamp-check: violation touched: yes`.
6. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/knowledge-writes.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds the cases; edit 2 shows them red before the code edits 3 to 7.
ruling: Open Question 4, 2026-10-20: the space form exits 2 with a usage line; a fresh install honours the flag; the exit code stays the render's. An invalid `=` value keeps exit 1 (the existing "bogus value exits non-zero" row).
scope: `main()` returns into `runUpdate` before edit 5's parse, so `--update` parses once, in `runUpdate`. `knowledgeWrites` in `main()` is in scope for both persona-config writes (the `--overwrite` branch and the skeleton), which sit in the same function.
proof: spec-master applied edits 1 to 8 to a scratch clone (8b931f0f plus rp-u1 to rp-u3; `bin/cli.js` is unchanged by them and by qw-u6, st-u1, st-u2 and st-u4 at these anchors), with a script that requires each `before:` payload to occur exactly once. every payload matched once; edit 2 printed `4`; edit 8 exited 0; after the commit criteria 1 to 5 printed the stated stdout (the pristine-install exit code is `1` with and without the flag); cli-backfill, cli-hook-propagation, cli-settings-backfill and default-implementer-model stayed green. validate.sh was not run by spec-master.
chained: qw-u6 edits `renderCleanBody`, the scaffold loop line and `module.exports`; st-u1 `CLAUDE_ONLY_HOOK_LIB_FILES`; st-u2 and st-u4 `BIN_HELPER_FILES`. No line of this unit's `before:` payloads occurs in theirs.
blast-radius: bin/cli.js:1173 (runUpdate), :1177-1182 (flag parse), :2367-2373 (main, target dispatch), :2622-2623 (overwrite branch), :2642-2648 (skeleton config); tests/knowledge-writes.test.sh:44. Line numbers are at 82844f70; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.193 at 82844f70; after rp-u1 to rp-u3, qw-u6 and st-u1 to st-u4 with no fix rounds they read 0.31.201; edit 9 adds one to whatever they read when the unit starts.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u4): --knowledge-writes is never silently ignored; space form refused, fresh install honours it
diagnosis: none
review-packet:
~~~
unit: rp-u4
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim (a queued unit may have edited a neighbouring line), stop and
report the current text. If the pristine-install exit codes differ between the flag and the plain run for a
reason other than the flag, quote both outputs and stop. If a gate blocks a command, report it and wait.
Anything outside "Affected files" goes to your report as a proposal.
