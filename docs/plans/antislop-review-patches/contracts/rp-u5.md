Unit: rp-u5

## Objective
Finding F, operator ruling OQ2 (2026-10-20). `agents/orchestrator.md` "Scribe dispatch convention"
dispatches the scribe once, after the last unit of a plan reaches PASS, so a plan that stops at ladder
exhaustion never closes the issues of the units that did pass. After this unit the convention also says:
- if the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), the
  orchestrator dispatches the scribe once for the units that already reached PASS before it surfaces the
  stop, with the same three inputs for each;
- under `knowledgeWrites: apply` the knowledge files are always in scope, so only the first skip condition
  (no tracker issue to close) can skip the scribe dispatch.
`tests/prompt-diet-pins.test.sh` pins both sentences in the source and its mirror. The codex and cursor
ports carry no scribe dispatch convention, so they are unchanged. This is spec Step 5.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 5 (rp-u5)" and
Clarifications (Open Question 2, ruled 2026-10-20). This file is the contract of record. Dispatch after st-u4
(both edit `agents/orchestrator.md`) and after rp-u3 (same pins file).

## Affected files
- `tests/prompt-diet-pins.test.sh` (anchor: line matching `# Later units append their rows below this line.`)
- `agents/orchestrator.md` (anchor: line matching `Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's digest reports a`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/prompt-diet-pins.test.sh`
   anchor: line matching `# Later units append their rows below this line.`
   indent: 0
   insert-after:
~~~

# rp-u5: the scribe still runs for the passed units when a plan stops early, and knowledgeWrites apply
# leaves only the no-issue condition to skip it.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch the scribe once for the units that already reached PASS before you surface the stop'
  has "$f" 'under `knowledgeWrites: apply` the knowledge files are always in scope, so only the first condition can skip it.'
  has "$f" 'Skip the scribe dispatch entirely when no unit has a tracker issue to close'
done
~~~
2. command: `bash -c 'bash tests/prompt-diet-pins.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `4` (two new rows for each of the two files).
3. file: `agents/orchestrator.md`
   anchor: line matching `Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's digest reports a`
   indent: 0
   before:
~~~
Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's digest reports a
changed API or new convention whose knowledge file is in unit scope. Relay every `Knowledge proposals:` and
~~~
   after:
~~~
If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch
the scribe once for the units that already reached PASS before you surface the stop, with the same three
inputs for each. Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's
digest reports a changed API or new convention whose knowledge file is in unit scope; under
`knowledgeWrites: apply` the knowledge files are always in scope, so only the first condition can skip it.
Relay every `Knowledge proposals:` and
~~~
4. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected one above what rp-u4 wrote, 0.31.202 to 0.31.203 with no fix rounds).
5. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Scribe on an early stop (rp-u5, VERSION).** agents/orchestrator.md "Scribe dispatch convention": when a plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), the orchestrator dispatches the scribe once for the units that already passed before surfacing the stop, so their issues still close; under `knowledgeWrites: apply` only "no tracker issue to close" can skip the scribe. Pinned in tests/prompt-diet-pins.test.sh.
~~~
   Replace `VERSION` with the version that edit 4 wrote.
6. command: `node bin/cli.js --update`
   expect: 0
7. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 0
8. command: `git add -u && git commit -m "feat(rp-u5): the scribe runs for passed units before an early stop; skip rule under knowledgeWrites apply"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md` (no scribe dispatch convention there; criterion 4)
- `agents/scribe.md` (the scribe's own close rule is unchanged; criterion 4)
- `tests/knowledge-writes.test.sh` (its `Skip the scribe dispatch entirely when` row must keep passing unedited; criterion 3)

## Acceptance criteria
1. run: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 6 (`--update`); the two mirror rows fail and stdout is `1`.
2. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr -s " \n" " " < "$f" | grep -c "dispatch the scribe once for the units that already reached PASS before you surface the stop"; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 `
   mutation: skip edit 3; stdout is `0 0 `.
3. run: `bash -c 'bash tests/knowledge-writes.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: reword "Skip the scribe dispatch entirely when" in edit 3's text; its row fails and stdout is `1`.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u5)" | tail -1); l=$(git log --format=%H --grep="(rp-u5)" | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md package.json tests/prompt-diet-pins.test.sh `
   mutation: also edit `agents/scribe.md` in an rp-u5 commit; it joins the list.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u5)" | tail -1); l=$(git log --format=%H --grep="(rp-u5)" | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 4; stdout reads `version-stamp-check: violation touched: yes`.
6. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/prompt-diet-pins.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds the rows; edit 2 shows them red (`4`) before edit 3.
ruling: Open Question 2, 2026-10-20: dispatch the scribe for the already-passed units before surfacing a ladder-exhausted or human stop.
proof: spec-master applied edits 1 to 8 to a scratch clone (8b931f0f plus rp-u1 to rp-u4) with a script that requires each `before:` payload to occur exactly once: the payload matched once, edit 2 printed `4`, edit 7 exited 0, and criteria 1 to 5 printed the stated stdout. st-u4's edits 6 to 8 anchor at "Planning a non-trivial change", "## Delegation contract" and "For a lead-programmer dispatch that carries no dispatch contract", none inside this unit's lines; qw-u6 edits only the frontmatter. validate.sh was not run by spec-master.
blast-radius: agents/orchestrator.md:59-60 ("Scribe dispatch convention"); pins: tests/knowledge-writes.test.sh `Skip the scribe dispatch entirely when`, tests/prompt-diet-pins.test.sh. Line numbers are at 82844f70; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.193 at 82844f70 and, with no fix rounds, 0.31.202 after rp-u4; edit 4 adds one to whatever they read when the unit starts.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(rp-u5): the scribe runs for passed units before an early stop; skip rule under knowledgeWrites apply
diagnosis: none
review-packet:
~~~
unit: rp-u5
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
If the `before:` payload is not found verbatim (st-u4 or a fix round may have rewrapped the convention),
stop and report the current text. If `node bin/cli.js --update` reports a mirror as diverged, quote it and
stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes to your report
as a proposal.
