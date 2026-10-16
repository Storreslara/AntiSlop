Unit: ptr-u13c

## Objective
The shared protocol template and its Codex and Cursor ports tell `lead-programmer` it has no `Agent` tool and never spawns the explorer, the template limits "you CAN spawn foreground subagents" to a persona that has the `Agent` tool, and the gate-refusal sentence points at the glossary entry a denial's `More:` line names; `agents/lead-programmer.md` and its two ports say "No researcher" and the ports lose the "Scribe updates" bullet; `tests/persona-prose-pins.test.sh` pins all of it (tools line, absent phrases, edit-6 rows); version 0.31.181, CHANGELOG entry, mirrors refreshed by `node bin/cli.js --update`. One commit.

## Retrieval
GitHub issues: `gh issue view 566 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, section "Step U13c".

## Affected files
- `templates/persona-protocol.md` (anchor: line matching `grep-derived, not authoritative.`)
- `adapters/codex/agents-md-fragment.md` (anchor: line matching `purpose, not just by discipline.`)
- `adapters/cursor/rules/persona-protocol.mdc` (anchor: line matching `grep-derived, not authoritative.`)
- `agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml`, `adapters/cursor/agents/lead-programmer.md` (anchor: line matching `(not under a dispatch contract) when you need to`)
- `tests/persona-prose-pins.test.sh` (anchor: line matching `# ptr-u13c appends its rows below this line.`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.180",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `.claude/agents/*.md`, `.claude/persona-protocol.md` and the other mirrors `node bin/cli.js --update` rewrites (regenerated, never edited by hand)

## Ordered edits
1. command: `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = 0.31.180 && git log --format=%s | grep -qE '^[a-z]+\(ptr-u13b\): ' && test -f tests/persona-prose-pins.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `templates/persona-protocol.md`
   anchor: line matching `grep-derived, not authoritative.`
   indent: 3
   before: `grep-derived, not authoritative.`
   after:
   ~~~~
   grep-derived, not authoritative. `lead-programmer` is the exception: it has no
   `Agent` tool, never spawns the explorer, takes structure from its dispatch's
   `## Pre-resolved context`, and names what is missing in its report.
   ~~~~
3. file: `templates/persona-protocol.md`
   anchor: line matching `only to check that claim. This reuse rule`
   indent: 3
   before:
   ~~~~
   doubt, spawning the `explorer` only to check that claim. This reuse rule
   ~~~~
   after:
   ~~~~
   doubt, spawning the `explorer` only to check that claim (`lead-programmer`,
   which cannot spawn, names the doubted claim in its report instead). This reuse rule
   ~~~~
4. file: `templates/persona-protocol.md`
   anchor: line matching `- You CAN spawn foreground subagents; only nested TEAMS are barred.`
   indent: 3
   before: `- You CAN spawn foreground subagents; only nested TEAMS are barred.`
   after:
   ~~~~
   - If your persona has the `Agent` tool, you CAN spawn foreground subagents; only
     nested TEAMS are barred.
   ~~~~
5. file: `templates/persona-protocol.md`
   anchor: line matching `heredoc, read its refusal text before doing anything else: both gates print`
   indent: 3
   before:
   ~~~~
     heredoc, read its refusal text before doing anything else: both gates print
     their complete remediation — the sanctioned heredoc template, when
     rephrasing a path is allowed, and when it isn't — at the moment they
     refuse. Rewording
   ~~~~
   after:
   ~~~~
     heredoc, read its refusal text and the glossary entry its `More:` line names
     before doing anything else: the refusal names the sanctioned route, and the
     entry (`reviewed-path denial` or `decision-gate denial` in
     `docs/harness-glossary.md`) holds the full remediation, including when
     rephrasing a path is allowed and when it isn't. Rewording
   ~~~~
6. file: `adapters/codex/agents-md-fragment.md`
   anchor: line matching `purpose, not just by discipline.`
   indent: 3
   before: `purpose, not just by discipline.`
   after:
   ~~~~
   purpose, not just by discipline. `lead-programmer` is the exception: it has no
   `Agent` tool, never spawns the explorer, takes structure from its dispatch's
   `## Pre-resolved context`, and names what is missing in its report.
   ~~~~
7. file: `adapters/codex/agents-md-fragment.md`
   anchor: line matching `only to check that claim. This reuse rule`
   indent: 3
   before:
   ~~~~
   doubt, spawning the `explorer` only to check that claim. This reuse rule
   ~~~~
   after:
   ~~~~
   doubt, spawning the `explorer` only to check that claim (`lead-programmer`,
   which cannot spawn, names the doubted claim in its report instead). This reuse rule
   ~~~~
8. file: `adapters/cursor/rules/persona-protocol.mdc`
   anchor: line matching `grep-derived, not authoritative.`
   indent: 3
   before: `grep-derived, not authoritative.`
   after:
   ~~~~
   grep-derived, not authoritative. `lead-programmer` is the exception: it has no
   `Agent` tool, never spawns the explorer, takes structure from its dispatch's
   `## Pre-resolved context`, and names what is missing in its report.
   ~~~~
9. file: `adapters/cursor/rules/persona-protocol.mdc`
   anchor: line matching `only to check that claim. This reuse rule`
   indent: 3
   before:
   ~~~~
   doubt, spawning the `explorer` only to check that claim. This reuse rule
   ~~~~
   after:
   ~~~~
   doubt, spawning the `explorer` only to check that claim (`lead-programmer`,
   which cannot spawn, names the doubted claim in its report instead). This reuse rule
   ~~~~
10. file: `agents/lead-programmer.md`
   anchor: line matching `(not under a dispatch contract) when you need to`
   indent: 3
   before:
   ~~~~
   - Spawn `researcher` (not under a dispatch contract) when you need to
     understand a technique rather than guessing, if this project has one;
     otherwise use WebSearch yourself.
   ~~~~
   after:
   ~~~~
   - **No researcher**: you cannot spawn `researcher` and have no WebSearch tool.
     When a technique is unclear, say so in your report; the orchestrator can
     dispatch `researcher`.
   ~~~~
11. file: `adapters/cursor/agents/lead-programmer.md`
   anchor: line matching `(not under a dispatch contract) when you need to`
   indent: 3
   before:
   ~~~~
   - Spawn `researcher` (not under a dispatch contract) when you need to
     understand a technique rather than guessing, if this project has one;
     otherwise use WebSearch yourself.
   ~~~~
   after:
   ~~~~
   - **No researcher**: you cannot spawn `researcher` and have no WebSearch tool.
     When a technique is unclear, say so in your report; the orchestrator can
     dispatch `researcher`.
   ~~~~
12. file: `adapters/codex/agents/lead-programmer.toml`
   anchor: line matching `(not under a dispatch contract) when you need to`
   indent: 3
   before:
   ~~~~
   - Spawn `researcher` (not under a dispatch contract) when you need to
     understand a technique rather than guessing, if this project has one;
     otherwise search the web yourself.
   ~~~~
   after:
   ~~~~
   - **No researcher**: you cannot spawn `researcher` and have no WebSearch tool.
     When a technique is unclear, say so in your report; the orchestrator can
     dispatch `researcher`.
   ~~~~
13. file: `adapters/cursor/agents/lead-programmer.md`
   anchor: line matching `**Scribe updates (batched, blocking-but-brief)**`
   indent: 3
   delete:
   ~~~~
   - **Scribe updates (batched, blocking-but-brief)**: if this project has a
     `scribe` (check `.cursor/agents/`), spawning it pauses you until it
     returns - batch it at the END of each plan step, not each edit, with a
     compact digest (affected files, changed APIs, new conventions) so the pause
     stays short. If there's no scribe, skip this - nothing else depends on it.
   ~~~~
14. file: `adapters/codex/agents/lead-programmer.toml`
   anchor: line matching `**Scribe updates (batched, blocking-but-brief)**`
   indent: 3
   delete:
   ~~~~
   - **Scribe updates (batched, blocking-but-brief)**: if this project has a
     `scribe` (check `.codex/agents/`), spawning it pauses you until it
     returns - batch it at the END of each plan step, not each edit, with a
     compact digest (affected files, changed APIs, new conventions) so the pause
     stays short. If there's no scribe, skip this - nothing else depends on
     it.
   ~~~~
15. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `# ptr-u13c appends its rows below this line.`
   indent: 3
   insert-after:
   ~~~~
   for f in agents/lead-programmer.md .claude/agents/lead-programmer.md; do
     tl="$(sed -n '1,12p' "$f" | grep -E '^tools:' | head -1)"
     if [ -n "$tl" ] && ! printf '%s' "$tl" | grep -q 'Agent'; then echo "ok   $f tools line has no Agent"; else echo "FAIL $f tools line missing or names Agent"; fail=1; fi
   done
   for f in agents/lead-programmer.md .claude/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md; do
     hasnot "$f" 'Spawn `researcher`'
     hasnot "$f" 'Scribe updates'
     hasnot "$f" 'You CAN spawn foreground'
   done
   has .claude/agents/lead-programmer.md 'is the exception: it has no'
   has .claude/agents/lead-programmer.md 'If your persona has the'
   for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/lead-programmer.md .claude/agents/reviewer.md .claude/agents/spec-master.md .claude/agents/task-master.md; do
     hasnot "$f" 'print their complete remediation'
     has "$f" 'the glossary entry its `More:` line names'
   done
   ~~~~
16. file: `.claude-plugin/plugin.json` (version 0.31.181)
   anchor: line matching `"version": "0.31.180",`
   before: `"version": "0.31.180",`
   after: `"version": "0.31.181",`
17. file: `package.json` (version 0.31.181)
   anchor: line matching `"version": "0.31.180",`
   before: `"version": "0.31.180",`
   after: `"version": "0.31.181",`
18. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~~

   **No spawn language on the lead-programmer surface (ptr-u13c, 0.31.181).** `templates/persona-protocol.md` now says that `lead-programmer` has no `Agent` tool and never spawns the explorer (it takes structure from its dispatch's `## Pre-resolved context` and names what is missing in its report), that "you CAN spawn foreground subagents" holds only for a persona that has the `Agent` tool, and that a gate refusal's full remediation lives in the glossary entry its `More:` line names, not in the refusal text; the Codex and Cursor protocol ports carry the first two sentences. `agents/lead-programmer.md` and its two ports replace the "Spawn `researcher`" bullet with "No researcher", and both ports drop the "Scribe updates" bullet. `tests/persona-prose-pins.test.sh` gains the `tools:` pin and the absent-phrase rows.
   ~~~~
19. command: `node bin/cli.js --update`
   expect: 0
20. command: `git add templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md tests/persona-prose-pins.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git reset -q -- .claude/agent-memory && git commit -m "docs(ptr-u13c): lead-programmer has no spawn language and a tools pin (0.31.181) (#566)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/cli.js` (the fix is a one-clause exception in the shared text, not a protocol-matrix change)
- `templates/persona-protocol-slim.md` (the slim tier is not in the spec's file list; its Agent-teams line stays)
- `agents/orchestrator.md`, `agents/task-master.md`, `agents/spec-master.md` and `agents/reviewer.md` (ptr-u13b is the orchestration-prose unit)
- `CONTEXT.md`, `docs/harness-glossary.md` and `docs/adr/` (the scribe lands any glossary change after PASS)
- `.claude/` except what `node bin/cli.js --update` rewrites; never edit a mirror by hand

## Acceptance criteria
1. run: `bash tests/persona-prose-pins.test.sh > /dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 2 (the protocol exception sentence); the mirror misses `is the exception: it has no`, a FAIL line prints and the line reads exit=1.
   proof: green at HEAD (the ptr-u13b rows pass before this unit appends its rows); criteria 3 and 4 are the red-then-green checks.
2. run: `bash tests/persona-prose-pins.test.sh | tail -1`
   exit: 0
   stdout: `All persona-prose-pins checks passed.`
   mutation: skip edit 4 (the Agent-teams clause); the mirror misses `If your persona has the` and the last line reads persona-prose-pins: FAILED.
   proof: green at HEAD (the ptr-u13b rows pass before this unit appends its rows); criteria 3 and 4 are the red-then-green checks.
3. run: `bash tests/persona-prose-pins.test.sh | grep -c '^ok'`
   exit: 0
   stdout: `54`
   mutation: skip edit 5 (the gate-refusal sentence); the six edit-6 rows print FAIL and stdout is not 54.
4. run: `for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/*.md; do tr -s ' \n' ' ' < "$f" | /usr/bin/grep -c 'print their complete remediation'; done | grep -vc '^0$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 5; the template and the mirrors still carry the old sentence and stdout is not 0.
5. run: `sed -n '1,12p' agents/lead-programmer.md | grep -E '^tools:' | grep -c 'Agent'`
   exit: 1
   stdout: `0`
   mutation: append `, Agent` to the tools: line of agents/lead-programmer.md; stdout 1 and exit 0.
   proof: green at HEAD (ptr-u12 dropped Agent); scratch run: with `, Agent` appended the pin test printed a FAIL line for the tools row and exited 1, and this command printed 1.
6. run: `tr -s ' \n' ' ' < .claude/agents/lead-programmer.md | /usr/bin/grep -c 'You CAN spawn foreground'`
   exit: 1
   stdout: `0`
   mutation: skip edit 4 (the Agent-teams clause); the mirror keeps the old line and stdout is 1.
7. run: `node tests/protocol-cross-references.test.js | tail -1`
   exit: 0
   stdout: `All protocol-cross-references checks passed.`
   mutation: delete a cross-referenced section heading from templates/persona-protocol.md; the last line no longer reads that sentence.
   proof: green at HEAD (a regression guard); scratch run: with the heading "Retrieval contract" renamed the suite aborted with an error and a non-zero exit.
8. run: `node tests/adapter-protocol-parity.test.js && node tests/adapter-skill-parity.test.js`
   exit: 0
   stdout: `OK   adapters/cursor/agents/reviewer.md inlines roast-work`
   mutation: edit a protocol port to drop its Fourth-verdict header; the parity test exits 1.
   proof: green at HEAD (a parity guard carried over from ptr-u8 criterion 14); scratch run: with the line `## Fourth verdict: escalate-to-human` deleted from adapters/codex/agents-md-fragment.md the parity test printed 1 adapter-protocol-parity check(s) FAILED and exited 1.
9. run: `node tests/writer-tier-consistency.test.js | tail -1`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: delete the words `provided it is unchanged` from the Contract-score guard paragraph of agents/orchestrator.md; the last line reads `1 check(s) failed.`
   proof: green at HEAD (a regression guard for the lead-programmer ports, whose AC-A1 paragraph this unit leaves alone); scratch run: with those words deleted the suite printed 1 check(s) failed.
10. run: `node tests/cli-backfill.test.js | tail -1`
   exit: 0
   stdout: `All cli-backfill tests passed.`
   mutation: skip edit 19 (`node bin/cli.js --update`); the mirror assertions fail and the last line no longer reads that sentence.
   proof: green at HEAD (a mirror guard); scratch run: with the mirror left stale the suite failed.
11. run: `W=$(mktemp -d)/wt; git worktree add --detach "$W" HEAD >/dev/null 2>&1 && (cd "$W" && node bin/cli.js --update >/dev/null 2>&1; git status --porcelain | wc -l); git worktree remove --force "$W"`
   exit: 0
   stdout: `0`
   mutation: skip edit 19 before the commit; the throwaway worktree then shows a non-zero count.
   proof: green at HEAD (a mirror guard); scratch run: with the mirror left stale the worktree after --update showed a non-zero count.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c" | head -1; done`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 16 (the plugin.json bump) before the commit; the line reads `violation`.
13. run: `node -p "require('./.claude-plugin/plugin.json').version"`
   exit: 0
   stdout: `0.31.181`
   mutation: skip edit 16; stdout 0.31.180.
14. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 17; nothing prints, exit 1.
   proof: green at HEAD (the two versions agree before and after); the mutation breaks the agreement.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; echo "$L" | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 20 (the commit); no unit commit exists and the criterion stops with no-unit-commit.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -vE "^[.]claude/" | LC_ALL=C sort | paste -sd" "; done`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md adapters/codex/agents-md-fragment.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md adapters/cursor/rules/persona-protocol.mdc agents/lead-programmer.md package.json templates/persona-protocol.md tests/persona-prose-pins.test.sh`
   mutation: skip edit 15 (the test rows); the list loses tests/persona-prose-pins.test.sh and the fragment is absent.
   proof: scratch run: the committed replay printed exactly that list.
17. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done`
   exit: 0
   stdout: `1`
   mutation: omit the second -m argument of the commit command; stdout 0 and exit 1.
   proof: scratch run: the replayed commit message carried the trailer line once.
18. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -cE "^[.]claude/(agent-memory/|reviewed/)"; done`
   exit: 1
   stdout: `0`
   mutation: drop the `git reset -q -- .claude/agent-memory` step of the commit command while a memory file is dirty; stdout 1.
   proof: scratch run: the replayed commit touched no agent-memory path.
19. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- templates/persona-protocol.md agents/lead-programmer.md | grep -vcE "^[a-z]+\(ptr-u13c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching agents/lead-programmer.md after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit makes grep -v count it, so stdout is 1.
20. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 20; the edits stay uncommitted and stdout is non-zero.
   proof: green at HEAD (the tree is clean before the unit); the mutation leaves tracked edits uncommitted.
21. run: `bash tests/validate-lanes.sh --lanes 4`
   exit: 0
   stdout: `All checks passed.`
   mutation: skip edit 19 and edit 2; the pins disagree with the sources and the run exits 1.
   proof: scratch run: the lanes gate over the replayed chain printed All checks passed.

## Pre-resolved context
tdd: yes tests/persona-prose-pins.test.sh (the rows are edit 15, applied after the prose edits and before the commit; criteria 1-4 are the checks)
blast-radius: templates/persona-protocol.md:12 templates/persona-protocol.md:30 templates/persona-protocol.md:65 templates/persona-protocol.md:82 agents/lead-programmer.md:79 adapters/codex/agents/lead-programmer.toml:69 adapters/cursor/agents/lead-programmer.md:68 adapters/codex/agents-md-fragment.md:12 adapters/cursor/rules/persona-protocol.mdc:17 tests/adapter-protocol-parity.test.js:1 (grep-derived, no graph run)
gate-run: criterion 21 runs the lanes gate in the foreground (about 2-3 minutes; pass the 600000 ms timeout; never background it; it refuses a linked worktree, so use the normal checkout). If it fails only in tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5), both timing-flaky and unrelated, rerun that test alone and the lanes once more, and report both runs.
gate-refusal: no command in this contract names the persona config file, and none needs to. If any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround).
staging: the commit command stages explicit paths, then `git add -u -- .claude` for what `--update` rewrites (10 agent mirrors, the config, persona-protocol.md, persona-protocol-slim.md and protocol-digest.md), and unstages agent-memory; if criterion 18 shows an agent-memory path in the commit, STOP and report.
payload-indent: every fenced payload is written with the contract's own 3-space indent; strip exactly 3 leading spaces from each non-empty payload line (empty lines stay empty); a payload line that is indented further keeps its extra spaces. Use the Edit tool for every before/after, insert-after and delete item (each `before:` and `delete:` is a verbatim run of lines, or a verbatim part of one line, from the file); a `delete:` removes the listed lines together with their line breaks.
order: run `node bin/cli.js --update` only after every file edit, then commit once; the version moves 0.31.180 -> 0.31.181.
commit-message: docs(ptr-u13c): lead-programmer has no spawn language and a tools pin (0.31.181) (#566)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u13c (#566)
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
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
criterion 21: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
