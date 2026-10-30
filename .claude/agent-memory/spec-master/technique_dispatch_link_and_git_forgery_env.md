---
name: technique-dispatch-link-and-git-forgery-env
description: Link a PreToolUse(Agent) call to the subagent's SubagentStop via meta.json toolUseId; GIT_NO_REPLACE_OBJECTS does not disable grafts, a non-existent GIT_GRAFT_FILE does
metadata:
  type: reference
---

Measured 2026-10-29 (Claude Code 2.1.x, git 2.43.0), for the sgb plan (scope-gate baseline hardening):

- `<agent transcript>.meta.json` carries `toolUseId`. It equals the parent's PreToolUse `tool_use_id` for that Agent call: 2488/2488 metas on this machine, the oldest from 2026-09-23. The subagent's first user message equals `tool_input.prompt` up to trailing newlines (341/341). So a hook can key per-dispatch state by tool_use_id, and the SubagentStop side can find it.
- `GIT_NO_REPLACE_OBJECTS=1` neutralises `git replace` but NOT `.git/info/grafts`; `merge-base --is-ancestor` still follows a graft. `GIT_GRAFT_FILE=/dev/null` disables grafts but prints a deprecation `hint:` on stderr. `GIT_GRAFT_FILE=<non-existent path>` disables them silently.
- `git clean -fdX` deletes gitignored harness state (such as the reviewed-marker dir) without naming its path, so a text-scanning gate never sees it. Any "record missing → fall back" design is writer-triggerable. Fail closed instead.
- I guessed that a new line in dispatch-audit.log would break dispatch-hygiene's "log absent" assertions. Measured false: those payloads have no tool_use_id. Measure a rejection reason before writing it down ([[feedback-verify-own-criteria-nonvacuous]]).
