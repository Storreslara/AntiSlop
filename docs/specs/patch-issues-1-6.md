# Patch spec: issues #1-#6

Status: spec only — no code changes yet. Written to hand off to a planning
pass (Opus) that turns this into an ordered implementation plan. Each section
names the exact file(s)/line(s) affected, the defect, and the proposed fix.
Issue numbers refer to this repo's GitHub issue tracker.

Source issues (all filed 2026-07-12, all against plugin v0.5.3): #1, #2, #3,
#4, #5, #6.

## Grouping

- **A. `skills/setup-personas/SKILL.md`** — #1, #2, #3, #6 (all in the
  judgment-driven ADAPT flow).
- **B. `hooks/scripts/stop-gate.sh`** — #4 (main-session Stop gating).
- **C. Harness-level gap, no in-repo fix possible** — #5. Documented
  workaround only.

---

## A1. Issue #1 — MATTPOCOCK placeholder names don't match real package

**File**: `skills/setup-personas/SKILL.md`, step 3 (lines ~100-131).

**Defect**: Step 3 tells the agent which mattpocock/skills names to have the
human select (`grill-me`, `to-issues`, `tdd`, `diagnose`,
`improve-codebase-architecture`, `setup-matt-pocock-skills`) and then
substitute into `<MATTPOCOCK:name>` placeholders. Two of those assumed names
are wrong against the currently-installed package: the real registered names
are `to-tickets` (not `to-issues`) and `diagnosing-bugs` (not `diagnose`).
Because the substitution step trusts the assumed names rather than checking
disk, a literal reading either substitutes a nonexistent name or leaves the
placeholder unresolved, with no error until a persona tries to invoke it.

**Fix**:
1. Don't hardcode assumed names as ground truth. After the human confirms the
   mattpocock installer is done, require the substitution step to *discover*
   real names by listing `.claude/skills/*/SKILL.md` frontmatter `name:`
   fields (already partially instructed — "Check the skill list and record
   the exact names" at line 120 — but this instruction is currently
   downstream of, and subordinate to, the specific assumed names given
   earlier in the same section, which is the actual bug). Reorder: name
   *categories* of skill by purpose ("to-tickets"-equivalent, "TDD"-equivalent,
   "diagnose"-equivalent, etc.) in the human-facing ask, then always resolve
   the concrete `<MATTPOCOCK:*>` substitution value from the discovered
   frontmatter `name:`, never from the prose list.
2. Update the specific stale names in the human-facing prompt text itself
   (line 107-108) to the currently-correct `to-tickets` / `diagnosing-bugs`,
   since re-verifying against upstream per section 3's own preamble is cheap
   and the prompt text is what a human actually reads.
3. Add a hard-failure check at the end of step 3: `grep -rn "MATTPOCOCK"
   .claude/agents/` must return nothing before moving to step 4. (This
   overlaps with A2/#2's more general sweep — implement once, in section 10
   or as new step 3b, and have both issues' fixes point at the same check
   rather than duplicating it.)

## A2. Issue #2 — no automated placeholder sweep before reporting done

**File**: `skills/setup-personas/SKILL.md`, step 12 (report, lines ~360-370),
plus section 10 (hook verification, lines ~262-329).

**Defect**: Nothing in the flow greps for leftover `<PLACEHOLDER>` tokens
(`<MATTPOCOCK:*>`, `<REAL_LAUNCH_COMMAND_FROM_SETUP_PERSONAS_STEP_4>`, etc.)
before the agent reports success in step 12. Two real, independent defects in
one adapt run (issue #1's stale mattpocock names, and a leftover MCP
launch-command placeholder) went undetected until a human manually grepped.

**Fix**: Add a new mandatory sub-step, run unconditionally right before step
12's report (regardless of whether it's a fresh install or `--update`):

```
grep -rEn '<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>' .claude/agents/ .claude/persona-protocol.md .claude/protocol-digest.md
```

Any match is a **hard failure** — the agent must not report "done" in step 12
until it resolves every match or explicitly flags it to the human as an
unresolved gap (mirroring the "don't guess" precedent already in the skill).
Fold this into step 12's own text as its first bullet ("Before reporting,
run the placeholder sweep below and confirm zero matches") so it can't be
skipped by an agent that jumps straight to summarizing.

## A3. Issue #3 — `testAndLintCommand` written without verifying it passes

**File**: `skills/setup-personas/SKILL.md`, step 6 (lines ~192-217).

**Defect**: Step 6 composes `testAndLintCommand` from the repo's documented
commands (package.json/Makefile/etc.) and writes it straight into
`persona-config.json`. Nothing checks the composed command actually exits 0
on the current tree. Since this exact string is what `stop-gate.sh` runs on
every gated-agent turn end (`hooks/scripts/stop-gate.sh:86-95`), a
composed command that includes a sub-check with pre-existing, unrelated
failures (e.g. `make type-check` failing on 25 old mypy errors) permanently
red-gates every `lead-programmer` turn, indistinguishable from a real
regression because the hook doesn't (and by design can't) distinguish
pre-existing debt from newly introduced breakage.

**Fix**: After composing `testAndLintCommand` in step 6, add a mandatory
"run it once" sub-step before writing the config:
1. Execute the composed command against the current (clean) tree.
2. If it exits 0: write it as-is (current behavior).
3. If it exits non-zero: do not silently bake in a perpetually-red gate.
   Either (a) drop the failing sub-command from the composed string and
   record the exclusion + reason in `persona-config.json` generation notes /
   the step 12 report, or (b) surface the failing command and its output to
   the human as an explicit choice (include anyway and accept the gate will
   block until fixed, vs. exclude it) — don't decide unilaterally which of
   (a)/(b) without asking, since it's a judgment call about the project's
   tolerance for pre-existing debt.
4. Extend "don't guess" (already present elsewhere in the skill) to state
   explicitly: "don't assume a documented command currently passes — verify
   it before it becomes a gate."

## A4. Issue #6 — no detection/resume guidance when config exists but not `--update`

**File**: `skills/setup-personas/SKILL.md`, section 0 (lines ~23-38).

**Defect**: Section 0 only handles the Claude Code version gate. There's no
branch for "a `.claude/persona-config.json` already exists at the *current*
plugin version, and this invocation is plain `/antislop:setup-personas` (not
`--update`)." The skill falls straight through to the fresh 12-section flow,
which silently ignores or clobbers a prior partial/uncommitted run, forcing
the running agent to invent an ad hoc `AskUserQuestion` disambiguation that
isn't part of the documented flow. (Note: the doc comment at line 20-21
already handles the case where `--update` *was* explicitly passed — this gap
is specifically the non-`--update` invocation against an existing config.)

**Fix**: Add a new section 0.5 immediately after section 0:

```
## 0.5 Existing-config detection (only when NOT invoked with --update)

- Before starting section 1, check whether `.claude/persona-config.json`
  already exists.
- If it doesn't: proceed to section 1 (genuine fresh install), nothing to do
  here.
- If it does: read its `pluginVersion`.
  - If `pluginVersion` is OLDER than this plugin's current version: tell the
    user this looks like a stale install and that `--update` (section 11) is
    the right flow, not a fresh run. Ask before proceeding either way.
  - If `pluginVersion` MATCHES the current version: this is very likely a
    leftover partial/uncommitted run, not a genuine fresh install. Ask the
    user (AskUserQuestion, not a guess) which of these they want:
    1. Resume from the last completed section (inspect which files exist —
       `.claude/agents/*.md`, `.claude/persona-protocol.md`,
       `.claude/settings.json`, etc. — to infer how far the prior run got).
    2. Patch only the detected gaps (run the placeholder sweep from #2/A2
       now, and re-run only the sections whose output is missing or
       incomplete).
    3. Full restart (re-run sections 1-10 from scratch, overwriting).
```

This turns the previously-invented, undocumented `AskUserQuestion` step into
a first-class, specified part of the flow.

---

## B. Issue #4 — main-session `Stop` always full-checks a dirty tree

**File**: `hooks/scripts/stop-gate.sh` (lines 38-47 for the existing
`SubagentStop`-only filter; the gap is the absence of an equivalent filter
on plain `Stop`).

**Defect**: `gatedAgents` filtering (lines 38-47) only applies when
`hook_event_name == "SubagentStop"`. The plain `Stop` event (main session)
has no such filter and always falls through to the dirty-tree / test-lint
check (lines 65-95). Per `templates/settings-fragment.json:3`
(`"agent": "orchestrator"`), the main session in a properly-adapted antislop
project *always* runs as the orchestrator persona, which — per
`agents/orchestrator.md`'s own `tools:` frontmatter — has no Write/Edit/Skill
tools and structurally cannot be the source of a dirty tree itself. A dirty
tree at orchestrator-Stop time can only mean a dispatched subagent (e.g.
`lead-programmer`) is mid-flight — and that subagent is *already* gated
independently at its own `SubagentStop`. So the main-Stop check in this
situation is provably redundant, not defense-in-depth, yet it still forces a
fresh WIP sentinel on every single orchestrator turn-end while a background
task runs (observed 4+ times in one session).

Confirmed empirically (per the script's own header comment, line 7) that the
`Stop` payload does **not** carry `agent_type` the way `SubagentStop` does —
so the fix cannot key off the payload the same way #4's suggested "allowlist"
would for SubagentStop. It must key off which persona is configured as the
session's main agent instead, which is static, not per-event.

**Fix**: Read `.claude/settings.json`'s `.agent` field (default to
`"orchestrator"` if unset/missing, matching the shipped fragment's default)
once, near the top of the script. Reuse the exact same `gatedAgents`
membership check currently scoped to the `SubagentStop` branch (lines 38-47)
for the plain `Stop` event too, using this main-agent value in place of the
payload's `agent_type`:

```
if [ "$hook_event" = "Stop" ] || [ "$hook_event" = "SubagentStop" ]; then
  [ -f "$config" ] || exit 0
  gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
  [ -n "$gated" ] || gated="lead-programmer"

  if [ "$hook_event" = "SubagentStop" ]; then
    check_name="$agent_type"
  else
    settings="${project_dir}/.claude/settings.json"
    check_name="$(jq -r '.agent // "orchestrator"' "$settings" 2>/dev/null || echo orchestrator)"
  fi

  match=false
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" = "$check_name" ] && match=true
  done <<< "$gated"
  [ "$match" = true ] || exit 0
fi
```

This collapses the two branches into one shared check instead of adding a
second allowlist concept, and preserves the existing behavior for any project
that (unusually) sets `"agent"` to something other than `orchestrator` in
`settings.json` — e.g. a project that made `lead-programmer` the main agent
would still correctly get gated on every plain `Stop`, since `gatedAgents`
still defaults to including it.

**Caution**: this makes the *default* configuration (main agent =
orchestrator, `gatedAgents = ["lead-programmer"]`) skip the main-session
check unconditionally. Section 10's hook-verification sub-bullet "Confirm the
stop-gate does NOT block a trivial explorer or repo-historian turn even with
a dirty tree" (line 296-299) should be extended to also cover: "confirm the
stop-gate does NOT block a trivial *main-session (orchestrator)* turn even
with a dirty tree from an in-flight subagent" — this is the regression test
for this exact fix.

---

## C. Issue #5 — no cancel primitive / liveness signal for background Agent tasks

**SUPERSEDED.** Everything below this line was the original assessment
(harness gap, no in-repo fix, heartbeat-file convention proposed as the only
available mitigation). A follow-up Opus root-cause investigation found that
assessment was wrong on the central claim: the harness gap was **already
closed** at the reported Claude Code version, and the actual root cause of
the session failure was an in-repo config bug. See the amendment below the
original text; the heartbeat-file proposal was NOT implemented.

### Amendment (root-cause investigation, supersedes the below)

`TaskStop(task_id)` (cancel) and `TaskOutput(task_id, block=false)`
(non-blocking liveness poll) exist in the harness and work cross-agent —
official changelog entry 2.1.187 fixed exactly this case ("TaskStop and
TaskOutput failing to find background agents spawned by another agent"),
twenty patch releases before the issue's reported version (2.1.207). The
official subagents docs' tool-exclusion list (`AskUserQuestion`,
`EnterPlanMode`, `ExitPlanMode`, `ScheduleWakeup`, `WaitForMcpServers`) does
**not** withhold `TaskStop`/`TaskOutput` from subagents.

The real cause of the reported failure: `agents/orchestrator.md`'s `tools:`
field is an allowlist that **replaces** the inherited toolset, and it never
included `TaskStop`/`TaskOutput` — so the orchestrator that hit this in a
real session was cut off from the very primitives that would have solved
it, regardless of what the harness supports.

**Fix applied** (not part of the original A/B patch, landed separately):
added `TaskStop, TaskOutput` to `agents/orchestrator.md`'s `tools:` line,
plus a new "Managing a long-running background dispatch" body section
instructing it to poll via `TaskOutput(block=false)` before ever reaching
for `TaskStop`, and noting `TaskStop` is graceful (waits for the current
tool call/step to finish) — not a hard kill, so a task wedged mid-tool-call
may not stop instantly. `lead-programmer.md` was deliberately left
unchanged: nothing in its current body dispatches its own background/async
subagents (its `explorer`/`researcher`/`repo-historian` spawns are all
synchronous, "pauses you until it returns"), so it doesn't have the same
gap today — revisit if a future revision gives it async dispatches of its
own.

Residual, not fully closed: `TaskStop`'s graceful (not hard-kill) semantics
mean a task stuck mid-tool-call, as opposed to merely slow, may still not
stop promptly. There is also an open upstream reliability bug tail
(`anthropics/claude-code#75314`, `#20236`) around background-agent
cancellation. Neither is an antislop-side fix.

---

### Original assessment (superseded, kept for record)

**Scope**: This is a Claude Code harness gap (the `Agent` tool itself has no
cancel/kill primitive and no cheap liveness/heartbeat surface for a
background task), not a defect in any antislop-shipped file. There is no
in-repo code change that fixes the root cause — it can only be reported
upstream.

**Mitigation available in this repo**: `agents/orchestrator.md` and
`agents/lead-programmer.md` currently have no heartbeat convention at all
(confirmed by grep — no hits for "heartbeat"/"liveness"/"stall" in either
file). The existing WIP-sentinel mechanism
(`.claude/wip-handoff.<agent-id>`, `hooks/scripts/stop-gate.sh:53-63`) is
write-once-on-turn-end, not a running heartbeat, so it doesn't help while a
subagent is still mid-task.

Proposed mitigation (separate from, and not a substitute for, the upstream
report): add a documented convention — not a hook, since there's no event
that fires *during* a long subagent turn to drive one — instructing
long-running `lead-programmer` spawns to periodically touch a heartbeat file
(e.g. `.claude/heartbeat.<agent-id>`, whatever cadence is natural per
step/tool-call) so the orchestrator has an actual mtime signal to poll
("last activity N seconds ago") instead of guessing from target-file mtimes
or unreliable `ps` output. This goes in `agents/lead-programmer.md` (touch
the file at natural checkpoints) and `agents/orchestrator.md` (how to
interpret a stale heartbeat: still not a cancel primitive, but turns "is this
dead or just slow" from a guess into a bounded wait-and-check).

**Action** (superseded — no longer the plan): file the cancel/liveness gap
upstream against Claude Code separately; treat the heartbeat-file convention
as an optional, low-priority antislop-side mitigation, not a fix for the
reported issue.
