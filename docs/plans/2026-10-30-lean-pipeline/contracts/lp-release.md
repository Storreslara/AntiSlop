Unit: lp-release

## Objective
Release 0.32.0 under the per-release version rule (plan decision D3, step "U13 lp-release"). A release is one commit that bumps `version` in `.claude-plugin/plugin.json` and `package.json` from 0.31.227 to 0.32.0 and adds the CHANGELOG lines naming it: one summary bullet and the first `## [0.32.0] - <date>` heading, placed directly below `## [Unreleased]`. Everything already under `[Unreleased]` becomes 0.32.0 content. `node bin/cli.js --update` then re-stamps the `.claude/` mirrors and the config's `pluginVersion`, and those files go in the same commit. No other change.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U13 lp-release", decision D3, Risks R3. This file is the contract of record. Dispatch after lp-scribe has PASSed; it is the plan's last unit. Implementer tier: haiku if `node .claude/bin/contract-guard.js docs/plans/2026-10-30-lean-pipeline/contracts/lp-release.md --unit=lp-release` prints `contract-guard: haiku`, otherwise sonnet.

## Affected files
- `.claude-plugin/plugin.json` (anchor: line matching `"version": "0.31.227",`)
- `package.json` (anchor: line matching `"version": "0.31.227",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `.claude/` tracked files, written only by `node bin/cli.js --update` (edit 6)

## Ordered edits
1. command: `grep -q '"version": "0.31.227",' .claude-plugin/plugin.json && grep -q '"version": "0.31.227",' package.json && test "$(grep -cE '^## \[0\.32\.0\]' CHANGELOG.md)" = 0 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~

   **Release 0.32.0: the lean pipeline (plan 2026-10-30-lean-pipeline, lp-release).** The `task-master` persona is gone: spec-master writes one five-field contract per unit, the orchestrator writes fix contracts, and `task-master` in `--personas` or `personaSelection` maps to spec-master with a deprecation note. spec-master output is capped at 25,600 bytes and 400 lines per plan and 3,072 bytes per contract. The ESCALATE-TO-HUMAN verdict, its marker, packet, card and dashboard decision code, and `human-decision-gate.sh` are removed; the reviewer adds a `needs-human:` note instead, and `humanReviewMode` is ignored. `harness-integrity-gate.sh` and `reviewed-path-gate.sh` no longer scan Bash command text, and a writer whose dispatch left a new review marker is blocked at its stop. The stop gate checks one pending-review flag, and review-join stamps are gone. The writer packet, the reviewer verdict and the orchestrator's final message are shorter, the reviewer runs the full suite once per unit, and the version is bumped once per release (ADR-0044). Projects running `--update` receive content changes at releases only.
   ~~~
3. command: `python3 -c 'import datetime,pathlib; p=pathlib.Path("CHANGELOG.md"); t=p.read_text(); h="## [Unreleased]\n"; assert t.count(h)==1; p.write_text(t.replace(h, h+"\n## [0.32.0] - "+datetime.date.today().isoformat()+"\n", 1))'`
   expect: 0
4. file: `.claude-plugin/plugin.json`
   anchor: line matching `"version": "0.31.227",`
   before: `  "version": "0.31.227",`
   after: `  "version": "0.32.0",`
5. file: `package.json`
   anchor: line matching `"version": "0.31.227",`
   before: `  "version": "0.31.227",`
   after: `  "version": "0.32.0",`
6. command: `node bin/cli.js --update >/dev/null`
   expect: 0
7. command: `git add -- .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':!.claude/agent-memory'`
   expect: 0
8. command: `git commit -q -m "chore(lp-release): release 0.32.0" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/`, `templates/`, `skills/`, `commands/`, `adapters/`, `hooks/`, `bin/`, `tests/`, `docs/` (criterion 5)
- `.claude/persona-config.json` by hand; only edit 6 writes it
- `.claude-plugin/marketplace.json` (it carries no version)

## Acceptance criteria
1. run: `bash -c 'cat .claude-plugin/plugin.json package.json | grep -c "\"version\": \"0.32.0\","'`
   exit: 0
   stdout: `2`
   mutation: skip edit 5; stdout is `1`, and criterion 7 fails on the validate.sh version-sync check (today's tree: `0`, exit 1).
2. run: `bash -c 'grep -nE "^## \[" CHANGELOG.md | head -2 | sed -E "s/ - [0-9]{4}-[0-9]{2}-[0-9]{2}$/ - DATE/"; sed -n 7p CHANGELOG.md | cut -c1-16'`
   exit: 0
   stdout: `3:## [Unreleased]`, `5:## [0.32.0] - DATE`, `**Release 0.32.0`
   mutation: skip edit 3; the second line is `787:## [0.31.65] - DATE` or similar (today's tree prints `3:## [Unreleased]`, `787:## [0.31.65] - DATE`, and line 7 of the current file).
3. run: `bash -c 'c=$(git log --format=%H -F --grep="(lp-release)" | head -1); [ -n "$c" ] || { echo no-commit; exit 1; }; bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d" " -f1,2'`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edits 2 and 3, so the bump commit adds no CHANGELOG line naming 0.32.0; stdout is `version-stamp-check: violation` (today's tree: `no-commit`, exit 1).
4. run: `bash -c 'git grep -lE "antislop v0\.31\.|\"pluginVersion\": \"0\.31\." -- .claude | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: skip edit 6; stdout is the number of stamped `.claude/` files, 13 or more (today's tree: `14`).
5. run: `bash -c 'cs=$(git log --format=%H -F --grep="(lp-release)"); [ -n "$cs" ] || { echo no-commit; exit 1; }; echo "commits=$(echo "$cs" | wc -l | tr -d " ") other=$(for c in $cs; do git show --name-only --format= $c; done | sort -u | grep -vxE "\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/.+" | wc -l | tr -d " ")"'`
   exit: 0
   stdout: `commits=1 other=0`
   mutation: also stage `agents/scribe.md` in the release commit; stdout is `commits=1 other=1` (today's tree: `no-commit`, exit 1).
6. run: `bash -c 'node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters && echo clean'`
   exit: 0
   stdout: `clean`
   mutation: in edit 7, drop `git add -u -- .claude`; the mirrors stay modified and nothing is printed, exit 1.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 5; the package.json/plugin.json version-sync check fails and stdout is `1`. Run once, by the reviewer, after the final commit.

## Pre-resolved context
tdd: no release-only unit with no code; criteria 1 to 5 fail on today's tree and pass after the commit
blast-radius: tests/validate.sh:131 (version sync), hooks/scripts/version-stamp-check.sh (criterion 3), bin/cli.js --update (re-stamps `.claude/`)
measured: on 2026-10-30 (f56eba3d) the version is 0.31.226; lp-vsr moves it to 0.31.227 and no later unit bumps, so edit 1 expects 0.31.227. The first `## [x.y.z]` heading in CHANGELOG.md is at line 787 (0.31.65); later versions sit as bullets under `[Unreleased]`.
gate-refusal: if a hook refuses a command, STOP and report the refusal text; never reword or route around it.
commit-message: chore(lp-release): release 0.32.0
review-packet:
~~~
unit: lp-release
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criteria 1-6: <FILL: stdout of each>
~~~
diagnosis: none

## Escalation
If edit 1 does not exit 0 (the version is not 0.31.227, a 0.32.0 heading exists, or the tree is dirty), STOP and report what it found. If `node bin/cli.js --update` reports a diverged file or asks a question, STOP and report its output verbatim.
