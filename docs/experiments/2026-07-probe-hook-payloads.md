# Probe: hook payload shapes (2026-07-13)

Empirical probes for the persona-review-hardening plan
(`docs/plans/2026-07-13-persona-review-hardening.md`, step 1), following the
repo's "confirmed empirically, not assumed" practice already used for
`reviewer-route-gate.sh:6-13`. The probe wiring itself (temporary logging
hooks) was never added to this repo — it was registered only in a disposable
scratch fixture built by `eval/harness/scaffold.sh` outside the working tree,
and deleted after capture. This document is the only durable artifact.

## Method

1. Scaffolded a fresh fixture with `eval/harness/scaffold.sh` (installs
   explorer, lead-programmer, planner, reviewer via `bin/cli.js`).
2. Appended two temporary hook entries to the scaffolded fixture's own
   `.claude/settings.json` (not this repo's `hooks/hooks.json`):
   - `PreToolUse` matcher `Bash` → a probe script that appends its raw stdin
     payload to `.claude/probe-pretooluse-bash.jsonl` and exits 0.
   - `SubagentStop` (no matcher, alongside the existing `stop-gate.sh` entry)
     → a probe script that appends its raw stdin payload to
     `.claude/probe-subagentstop.jsonl` and exits 0.
3. Ran one headless task (`claude -p`, `--model sonnet`,
   `--permission-mode acceptEdits`) instructing the main session
   (`orchestrator`) to spawn `lead-programmer` via the `Agent` tool to run the
   Bash command `git status` and report back — never running the command in
   the main session itself, so any captured `Bash` PreToolUse payload is
   necessarily subagent-issued.
4. Captured the resulting JSONL files, then discarded the whole scratch
   fixture (including the probe hook scripts and settings.json edits).

## Probe A — does subagent-issued `Bash` PreToolUse carry `agent_type`?

Raw captured payload (one `PreToolUse` event, `tool_name: "Bash"`, fired
while `lead-programmer` executed `git status`):

```json
probe-a-payload
{"session_id":"c1660582-2afa-43ff-b657-07d0d00acaf9","transcript_path":"/home/user/.claude/projects/-tmp-claude-1000--home-sebas-seb-claude-setup-25cd00be-2665-422e-8b29-27bb3ec75763-scratchpad-probe-fixture/c1660582-2afa-43ff-b657-07d0d00acaf9.jsonl","cwd":"/tmp/claude-1000/-home-sebas-seb-claude-setup/25cd00be-2665-422e-8b29-27bb3ec75763/scratchpad/probe-fixture","prompt_id":"370c349c-343b-4a05-86d0-985b31a255fc","permission_mode":"acceptEdits","agent_id":"a18677c5b7c94db1a","agent_type":"lead-programmer","effort":{"level":"high"},"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status","description":"Show working tree status"},"tool_use_id":"toolu_019kBMrmi3YHs4mtFBwAcvKY"}
```

The top-level `agent_type` key is present and set to `"lead-programmer"` (the
caller's identity), exactly mirroring the already-confirmed `PreToolUse`
(`Agent`) shape at `reviewer-route-gate.sh:6-13`. `tool_input.command` also
carries the literal command string, which step 4's design needs for the
substring match on `.claude/reviewed`.

Probe A verdict: agent_type present

Branch decision for step 4: build `reviewed-path-gate.sh` on the
`agent_type`-present branch — attribute the caller from the top-level
`agent_type` field and apply the allow/block rules keyed on it (reviewer →
allow, empty + no-reviewer-fallback → allow, any other persona → block).

## Probe B — does `SubagentStop` carry a final-message field?

Raw captured payload (the `SubagentStop` event for the same
`lead-programmer` invocation):

```json
probe-b-payload
{"session_id":"c1660582-2afa-43ff-b657-07d0d00acaf9","transcript_path":"/home/user/.claude/projects/-tmp-claude-1000--home-sebas-seb-claude-setup-25cd00be-2665-422e-8b29-27bb3ec75763-scratchpad-probe-fixture/c1660582-2afa-43ff-b657-07d0d00acaf9.jsonl","cwd":"/tmp/claude-1000/-home-sebas-seb-claude-setup/25cd00be-2665-422e-8b29-27bb3ec75763/scratchpad/probe-fixture","prompt_id":"370c349c-343b-4a05-86d0-985b31a255fc","permission_mode":"acceptEdits","agent_id":"a18677c5b7c94db1a","agent_type":"lead-programmer","effort":{"level":"high"},"hook_event_name":"SubagentStop","stop_hook_active":false,"agent_transcript_path":"/home/user/.claude/projects/-tmp-claude-1000--home-sebas-seb-claude-setup-25cd00be-2665-422e-8b29-27bb3ec75763-scratchpad-probe-fixture/c1660582-2afa-43ff-b657-07d0d00acaf9/subagents/agent-a18677c5b7c94db1a.jsonl","last_assistant_message":"On branch master\nUntracked files:\n  (use \"git add <file>...\" to include in what will be committed)\n\t.claude/probe-pretooluse-bash.jsonl\n\nnothing added to commit but untracked files present (use \"git add\" to track)","background_tasks":[],"session_crons":[]}
```

Keys present: `session_id`, `transcript_path`, `cwd`, `prompt_id`,
`permission_mode`, `agent_id`, `agent_type`, `effort`, `hook_event_name`,
`stop_hook_active`, `agent_transcript_path`, `last_assistant_message`,
`background_tasks`, `session_crons`.

`last_assistant_message` carries the subagent's final assistant-turn text
verbatim (here, the `git status` output the task asked it to relay back) —
a usable field for a literal "ready-for-review" substring check.

Probe B verdict: field present (last_assistant_message)

This is a refinement, not a dependency, per the plan (step 5 does not
require this): step 5's flag-setting logic MAY additionally suppress the
pending-review flag when `last_assistant_message` does not match
`ready-for-review`, since the field exists and is populated in practice.
Given step 5's own scope note ("a refinement, not a dependency"), and to
keep the mechanism simple and hard to silently defeat (an agent could phrase
its final message to dodge a substring check), step 5 as implemented in this
pass does NOT add the suppression refinement — the flag is set for every
gated-agent stop not exempted by a WIP sentinel, exactly as the
no-refinement fallback the plan describes.

## Cleanup

The scratch fixture (hook scripts, settings.json edits, captured `.jsonl`
files, git history) was deleted after this capture. Nothing under
`hooks/`, `.claude/`, or any other repo-tracked path in this repository was
touched by the probe.
