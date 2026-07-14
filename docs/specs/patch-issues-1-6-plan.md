# Implementation plan for docs/specs/patch-issues-1-6.md

Status: plan only, produced by an Opus planning pass over the spec — no code
changes made yet. Ordered, with exact before/after wording for the
`SKILL.md` prose edits and a literal diff for `stop-gate.sh`.

## Shared-sweep decision

`A1` (mattpocock placeholder check) and `A2` (general placeholder sweep)
overlap — A2's regex `<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>` already matches
`<MATTPOCOCK:*>`. Define the sweep once, in step 12 (A2), and have step 3b
(A1) and section 0.5 (A4) reference it by name rather than restate the regex.

## Suggested order

1. **A2** — canonical placeholder sweep in step 12 (the anchor others reference).
2. **A1** — fix stale mattpocock names, make substitution disk-authoritative, add step 3b fail-fast referencing the A2 sweep.
3. **A4** — new section 0.5 (existing-config detection), option 2 references the A2 sweep.
4. **A3** — step 6 "verify testAndLintCommand before baking it in" (independent, any time).
5. **B** — `stop-gate.sh` unified Stop/SubagentStop branch + header comment + step-10 verification bullet (independent of A).
6. **C** (issue #5 heartbeat convention) — recommended to **defer** as a separate follow-up, not bundled into this patch (different files, different risk profile, and the spec itself scopes it as optional/low-priority).

## A2 — `skills/install-antislop/SKILL.md` step 12

Insert as the new first bullet of `## 12. Report back`, before the existing
"State: ..." paragraph:

> **Before writing any of the report below, run the placeholder sweep and
> confirm zero matches.** This is mandatory on every run — fresh install AND
> `--update`:
>
> `grep -rEn '<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>' .claude/agents/ .claude/persona-protocol.md .claude/protocol-digest.md`
>
> (This is the canonical "placeholder sweep" referenced by step 3b and
> section 0.5.) Any match is a HARD FAILURE. Do NOT report success until every
> match is either resolved by substituting the real value, or — if it
> genuinely can't be resolved — explicitly called out to the human as an
> unresolved gap. Never report "done" with a live placeholder still on disk.

Verify at implementation time that this regex doesn't false-positive on
legitimate content already in the shipped persona bodies (a quick grep
against `agents/` and `templates/` during implementation should show only
known placeholder tokens).

## A1 — `skills/install-antislop/SKILL.md` step 3 (three edits)

**A1-a (lines ~106-115):** rewrite the human-facing skill list to name
skills *by purpose*, not by an assumed literal name, and flag the two known
stale ones explicitly: "a 'turn work into tracker tickets' skill (registered
as `to-tickets` at the time of writing — NOT `to-issues`; verify on disk)"
and "a 'diagnose a bug' skill (registered as `diagnosing-bugs` — NOT
`diagnose`; verify on disk)," plus grill-me / tdd / improve-codebase-
architecture / setup-matt-pocock-skills with the same "verify on disk"
caveat.

**A1-b (lines ~120-131):** change substitution to read from the *discovered*
`name:` frontmatter of `.claude/skills/*/SKILL.md`, never from this file's
prose. Explicitly: "the placeholder label after the colon (e.g.
`<MATTPOCOCK:to-issues>`) is a slot marker, not necessarily the current
registered name — resolve the 'tickets' slot to the discovered `to-tickets`,
the 'diagnose' slot to the discovered `diagnosing-bugs`. If a purpose has no
matching discovered skill, STOP and surface it — do not substitute a guessed
name."

**A1-c (new step 3b, after step 3, before `## 4.`):**

> ### 3b. Fail-fast placeholder check (mattpocock scope)
>
> Immediately after the substitution above, run the canonical placeholder
> sweep from step 12, scoped to the agents directory:
>
> `grep -rEn '<MATTPOCOCK(:[a-zA-Z0-9_-]+)?>' .claude/agents/`
>
> Any match is a HARD FAILURE. Fix it (or surface an unresolvable one to the
> human) before doing any work in sections 4-12.

## A4 — `skills/install-antislop/SKILL.md` new section 0.5

Insert between section 0 (ends line 38) and `## 1. Persona selection`
(line 40):

> ## 0.5 Existing-config detection (only when NOT invoked with --update)
>
> Skip this section entirely if invoked with `--update` (go to section 11).
> Otherwise, before starting section 1:
> - Check whether `.claude/persona-config.json` already exists.
> - If not: genuine fresh install — proceed to section 1.
> - If it does: read its `pluginVersion` and compare to
>   `.claude-plugin/plugin.json`'s current version.
>   - Older: this looks like a stale install; `--update` (section 11) is the
>     right flow. Tell the user and ask (AskUserQuestion) before doing
>     anything.
>   - Matches: very likely a leftover partial/uncommitted run. Ask the user
>     (AskUserQuestion) to choose:
>     1. **Resume** — inspect which outputs already exist
>        (`.claude/agents/*.md`, `.claude/persona-protocol.md`,
>        `.claude/protocol-digest.md`, `.claude/settings.json`,
>        `.claude/persona-config.json`) and continue from the first
>        incomplete section.
>     2. **Patch gaps only** — run the step 12 placeholder sweep now, then
>        re-run only the sections whose output is missing or still contains
>        unresolved placeholders.
>     3. **Full restart** — re-run sections 1-10 from scratch, overwriting.
>   - Never silently clobber or ignore an existing config; always ask first.

## A3 — `skills/install-antislop/SKILL.md` step 6

Extend the `testAndLintCommand` bullet: after composing it, run it once
against the current clean tree. Exit 0 → write as-is. Non-zero → do NOT
silently bake in a perpetually-red gate; surface the failing command/output
to the human via AskUserQuestion and let them choose: (a) exclude the
failing sub-command and record the exclusion + reason in the step 12 report,
or (b) include it anyway, accepting the gate will BLOCK until the
pre-existing failure is fixed. Append one sentence to the closing
schema-validation paragraph: "This validation checks shape, not behavior — it
does NOT replace the 'run testAndLintCommand once' check above."

## B — `hooks/scripts/stop-gate.sh`

Replace the `SubagentStop`-only filter (current lines 38-47) with a unified
branch covering both `Stop` and `SubagentStop`:

```bash
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

`project_dir` is already defined above this block (line 29), so
`${project_dir}/.claude/settings.json` resolves correctly. Keep the
`|| echo orchestrator` fallback exactly as written so a missing/malformed
`settings.json` doesn't trip `set -euo pipefail`.

Also update the header comment (lines 1-7) to state: for plain `Stop` the
payload carries no `agent_type` (unlike `SubagentStop`), so gating keys off
the configured main agent (`settings.json`'s `.agent`, default
`"orchestrator"`) instead — the default config (main = orchestrator,
`gatedAgents = ["lead-programmer"]`) therefore skips the main-session check,
because the orchestrator has no Write/Edit tools and can't dirty the tree
itself.

Extend the step-10 verification bullet in SKILL.md (lines ~296-299, the
"stop-gate does NOT block a trivial explorer/repo-historian turn" bullet) to
also cover: pipe `{"hook_event_name":"Stop","session_id":"test"}` with a
dirty tree and default config, confirm exit 0 — the regression test for this
fix.

## Verification summary

- **Runnable now, no harness**: all of section B (5 stdin cases against
  `stop-gate.sh` directly — Stop/orchestrator/default-gated→ALLOW,
  Stop/lead-programmer-as-main-agent→BLOCK, SubagentStop cases unchanged,
  missing settings.json→defaults safely); A3's failure-mode demo (a red
  `testAndLintCommand` blocking a clean tree via the real hook).
- **Runnable with the scratch/ harness** (sets up the precondition only):
  A2 (regex catches raw tokens after a `bin/cli.js` fresh copy, empty after
  substitution), A4 (double-invoke to reach "config exists at same
  version").
- **Read-only correctness review** (the actual judgment `bin/cli.js` never
  performs): A1's disk-authoritative substitution, A3's ask-the-human
  branch, A4's AskUserQuestion routing — these are prose-precision checks,
  not runnable tests.

## Deferred: issue #5 (heartbeat convention)

Not part of this patch. Root cause is a Claude Code harness gap (no
cancel/liveness primitive for background Agent tool tasks) — file upstream
separately. The optional in-repo mitigation (a `.claude/heartbeat.<agent-id>`
convention in `lead-programmer.md`/`orchestrator.md`) is additive, touches
different files with a different risk profile than A/B, and should land as
its own change if wanted, not bundled here.
