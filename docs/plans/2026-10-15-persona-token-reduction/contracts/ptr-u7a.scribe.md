Unit: ptr-u7a

## Objective
`docs/harness-glossary.md` carries the two entries `reviewed-path denial` and `decision-gate denial`, which keep the explanatory text the shortened gate messages dropped. This contract runs BEFORE the lead contract `ptr-u7a.md` (its shape cases read these two terms); it closes nothing.

## Retrieval
GitHub issues: `gh issue view 561 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, section "Step U7a".

## Glossary edits
1. file: `docs/harness-glossary.md`
   heading: `**census**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **reviewed-path denial**:
   (unit ptr-u7a, 2026-10-16) — the three-line stderr `hooks/scripts/reviewed-path-gate.sh` prints when it blocks a non-reviewer write to the reviewed-markers directory, on its Write/Edit branch and on its Bash branch: line 1 names what was blocked and why, line 2 gives the remedy (`grep -r` to search, `git commit -F <file>` to commit a message that names the path, a trailing `#` comment to narrate) and keeps the self-authorized bypass sentence, line 3 is `More: docs/harness-glossary.md — "reviewed-path denial"`, a pointer to this entry. At most 70 words, pinned by the denial-message-shape cases of `tests/reviewed-path-gate.test.sh`. The explanatory text the shortened message replaced, verbatim (Write/Edit branch): `BLOCKED: '${agent_type}' may not write '${subject}' - only the reviewer creates .pass/.fail/.blocked records in .claude/reviewed/ (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Every Write/Edit into that directory is a write by definition, so the read-only exemption that applies to Bash commands does not apply here.` Verbatim (Bash branch): `BLOCKED: '${agent_type}' may not write to .claude/reviewed/ via Bash - only the reviewer writes the PASS marker there (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Read-only inspection (ls, cat, grep, test ...) and text-only mentions of the path in a gh issue/pr comment ARE allowed; this command was recognized as neither, because it redirects, substitutes, runs a program that could write, or could not be lexed at all (an unbalanced quote, a backslash escape and a heredoc are never assumed benign). Note that 'git' and 'rg' are NOT allowlisted at all, whatever the subcommand - see program_allowed() for why. To land a commit whose MESSAGE discusses this path, put the message in a file and use 'git commit -F <file>'; to search the directory, use 'grep -r'. Any other route to this path is a self-authorized bypass whether or not this gate blocks it; if the sanctioned route does not fit, report the block and wait. A mention that only NARRATES the directory is allowed outright and needs no workaround: a trailing '#' comment naming it passes provided the rest of the command is itself allowlisted, since bash discards the comment but still runs everything else. What you hit is narrower - this command's text spells the path where bash would act on it (in code, in a quoted word, or as a redirection target), or it could not be lexed at all. A comment on a line of its OWN still fails closed; that is a ratified residual (issue #183), so keep the comment on the same line as the command.` The trigger logic is unchanged. Not the **decision-gate denial**.
   ~~~~
2. file: `docs/harness-glossary.md`
   heading: `**reviewed-path denial**:`
   placement: insert after the paragraph of the entry from item 1, separated by one blank line
   indent: 3
   text:
   ~~~~
   **decision-gate denial**:
   (unit ptr-u7a, 2026-10-16) — the three-line stderr `deny()` in `hooks/scripts/human-decision-gate.sh` prints when any agent identity tries to write the DECISION file of a human-review packet: line 1 names what was blocked and why, line 2 names the **sanctioned marker-write template**, keeps the `rm -rf` packet-discard route and the self-authorized bypass sentence, line 3 is `More: docs/harness-glossary.md — "decision-gate denial"`, a pointer to this entry. At most 70 words, pinned by the denial-message-shape cases of `tests/human-decision-gate.test.sh`. The explanatory text the shortened message replaced, verbatim (whitespace collapsed to single spaces): `BLOCKED: '%s' may not write .claude/human-review/<task-id>/DECISION - that file records the human's own resolution of a pending escalation and no agent identity may create or modify it, reviewer included. If you are writing a review marker whose body must quote that path verbatim, use the sanctioned marker-write template - this gate allows it: cat > .claude/reviewed/<task-id>.pass <<'EOF' <marker body; the delimiter is single-quoted, so nothing here expands> EOF Rules: the delimiter must be single-quoted, the target a bare literal .claude/reviewed/<id>.{pass,fail,directed,blocked,escalated}, and the terminator the last line of the command. >> works in place of >. The human records a decision in the terminal or the dashboard, or - from the main session only - by approving the exact decision heredoc at Claude Code's permission prompt, which this gate asks for and never grants by itself. Any other route to it is a self-authorized bypass whether or not this gate blocks it; if no sanctioned route fits, report and wait. That rule governs commands TARGETING this file. A mention that only narrates it is allowed outright and needs no workaround: prose inside a single 'git commit' message, a single-quoted read pattern, and a trailing '#' comment all pass. What you hit is narrower - this command's text spells the path itself, or a mention sits where bash would execute it. To discard a resolved packet, delete the whole directory with 'rm -rf .claude/human-review/<task-id>'.` The trigger logic is unchanged. Not the **reviewed-path denial**.
   ~~~~

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #561
- task-id: ptr-u7a
- marker first line: "PASS ptr-u7a "
- This contract runs before the lead contract, so no PASS marker exists yet: do not close the issue. Commit with the subject `docs(ptr-u7a): glossary entries for the two gate denial anchors (#561)` and the trailer line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`, staging only `docs/harness-glossary.md`. Commit your own memory notes separately (`docs(agent-memory): ...`), never in this commit.

## Do NOT touch
- `CONTEXT.md`, `docs/adr/` and `agents/`
- `hooks/` and `tests/` (the lead contract owns them)

## Acceptance criteria
1. run: `/usr/bin/grep -cE '^\*\*(reviewed-path|decision-gate) denial\*\*:$' docs/harness-glossary.md`
   exit: 0
   stdout: `2`
   mutation: skip both glossary edits; stdout `0`, exit 1.
2. run: `/usr/bin/grep -cF 'Every Write/Edit into that directory is a write by definition' docs/harness-glossary.md`
   exit: 0
   stdout: `1`
   mutation: skip glossary edit 1; stdout `0`, exit 1.
3. run: `/usr/bin/grep -cF 'To discard a resolved packet, delete the whole directory with' docs/harness-glossary.md`
   exit: 0
   stdout: `1`
   mutation: skip glossary edit 2; stdout `0`, exit 1.
4. run: `/usr/bin/grep -c 'denial\*\*' CONTEXT.md`
   exit: 1
   stdout: `0`
   mutation: add a `**reviewed-path denial**:` entry to CONTEXT.md; stdout `1` (a term must live in one glossary).
5. run: `node tests/context-glossary-links.test.js | tail -1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: add the link `[[no such term]]` to an entry; the test fails.
6. run: `node tests/ubiquitous-language.test.js | tail -1`
   exit: 0
   stdout: `passes all 4 structural/distinguishability checks`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero (it checks skills/ubiquitous-language/SKILL.md, not the entries).
   proof: `UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js` exits non-zero.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | tail -1); git diff --name-only "$c~1..$c"`
   exit: 0
   stdout: `docs/harness-glossary.md`
   mutation: also stage `CONTEXT.md`; the list gains that path.
   proof: scratch replay printed exactly that path.
8. run: `git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave the glossary edit unstaged; stdout is non-zero.
   proof: scratch replay printed 0.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap.
