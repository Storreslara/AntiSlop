---
name: technique-replay-writer-scope-gate-offline
description: How to reproduce a writer-scope-gate block offline from a real subagent transcript, and the Set A read trap met on the way
metadata:
  type: reference
---

Reproduce a logged `BLOCKED (writer-scope-gate)` offline (worked 2026-10-29, tg-spec, 4 of 5 real blocks):
1. The log is `.claude/bookkeeping/scope-gate.log` (`agent=<id>`). The transcript is
   `~/.claude/projects/-home-sebas-AntiSlop/<session>/subagents/agent-<id>.jsonl` with a sibling `.meta.json`.
2. The gate's scope source is the transcript's FIRST user message (the dispatch message), not the contract file.
   Extract it with the gate's own jq (`map(select(.type == "user"))[0].message.content`), then run `us_section`,
   `us_entries` and `us_exclusions` from `hooks/scripts/lib/unit-scope.sh` on it.
3. For a full run: `git clone -q --local` the repo into a `mktemp -d` and `sed` the transcript's absolute repo
   paths to the clone. The gate keeps only Write/Edit paths under its project dir, so unrewritten paths are
   silently dropped. Then feed `{"agent_type":"lead-programmer","agent_transcript_path":…,"hook_event_name":
   "SubagentStop","agent_id":…,"cwd":<clone>}` with `CLAUDE_PROJECT_DIR=<clone>`.
   `.claude/reviewed/*.fail` is untracked, so the clone loses the `fail-record` class.
4. Put probe logic in a scratch script written with the Write tool. Bash command text is scanned by gates.

Gate traps met:
- harness-integrity-gate denies ANY Bash command whose text names the persona-selection config (Set A), even
  a read-only `grep -o` or `ls`. Read it with the Read tool.
- reviewed-path-gate treats `find` on `.claude/reviewed` as a writer. See [[technique_reviewed_dir_survey_without_pipes]].

Related: [[feedback_verify_own_criteria_nonvacuous]].
