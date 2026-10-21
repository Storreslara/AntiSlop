Unit: qw-u2

## Objective
Shrink the orchestrator prompt by moving incident narratives and rationale out of it, with every live rule
kept. Five narratives (N1 to N5) move verbatim to a new `docs/orchestrator-rationale.md`, which is not loaded
at runtime. The teams-only subsection "A missing roster row is not proof a teammate is dead" moves to
`commands/start-feature-team.md`, the file that governs teams mode. Rules O1, O2, O3, O5 and O6 stay in the
orchestrator, shortened where noted. A new `tests/prompt-diet-pins.test.sh` pins each survivor and each
absence. The installed `.claude/agents/orchestrator.md` shrinks by at least 3400 bytes (3759 measured on
the current text). This is spec Step 2 (b-1 i).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 2 (qw-u2)" and "Context,
b". This file is the contract of record. Dispatch it only after qw-u1 has reached PASS.

## Affected files
- `agents/orchestrator.md` (anchors: lines starting `**Dispatch naming for this project's reviewer (if present).**`, `**\`Agent\` naming vs \`SendMessage\` addressing`, `**Reviewer re-tasking discipline`, `### A missing roster row is not proof a teammate is dead`, `The auto-notification is **not**`, `**Why unnamed is the default`)
- `commands/start-feature-team.md` (anchor: its last line, `v2.1.178).`)
- `docs/orchestrator-rationale.md` (anchor: new file)
- `tests/prompt-diet-pins.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "== tests/persona-prose-pins.test.sh:`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/orchestrator.md` and the config's `fileHashes`

## Ordered edits
1. file: `tests/prompt-diet-pins.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# Prompt-diet pins (qw-u2, extended by qw-u3 and qw-u4): every live rule a diet unit moved or shortened is
# present where the spec's rule map says it survives, and the moved narrative is gone from the prompt.
# Each file is flattened (tr -s ' \n' ' ') first, so a phrase may wrap. Prints ok|FAIL <file> <phrase>.
set -u
cd "$(dirname "$0")/.."
fail=0
flat() { tr -s ' \n' ' ' < "$1"; }
has() { # <file> <phrase>
  if [ -f "$1" ] && flat "$1" | grep -qF -- "$2"; then echo "ok   $1 $2"; else echo "FAIL $1 $2"; fail=1; fi
}
hasnot() { # <file> <phrase>
  if [ -f "$1" ] && ! flat "$1" | grep -qF -- "$2"; then echo "ok   $1 (absent) $2"; else echo "FAIL $1 (present or missing) $2"; fail=1; fi
}

# qw-u2: orchestrator narrative trim. Rules O1-O3, O5, O6 stay; O4 moves to the teams command;
# narratives N1-N5 move to docs/orchestrator-rationale.md.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'dispatch the `reviewer` with no `name:` parameter'
  has "$f" 'it must be exactly `reviewer`'
  has "$f" '**Check the roster before resuming one by name**'
  has "$f" 'Only a fresh `Agent` dispatch whose first non-blank line is `Unit: <id>` writes the per-unit review-join stamp'
  has "$f" 'a persona that spawns its own subagent must collect the result explicitly'
  has "$f" 'defaults `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"0"`'
  hasnot "$f" 'The actual, unobserved residual is different'
  hasnot "$f" 'two different mechanisms'
  hasnot "$f" 'produced gh-304'
  hasnot "$f" 'This project has observed: three unnamed subagents'
  hasnot "$f" 'Quoting the docs directly'
  hasnot "$f" '### A missing roster row is not proof a teammate is dead'
done
has commands/start-feature-team.md '**A missing roster row is not proof a teammate is dead.**'
has commands/start-feature-team.md '`SendMessage` it by name first'
has commands/start-feature-team.md 'still lists that member as active'
for n in 'The actual, unobserved residual is different' 'two different mechanisms' 'produced gh-304' \
         'This project has observed: three unnamed subagents' 'Quoting the docs directly'; do
  has docs/orchestrator-rationale.md "$n"
done

# qw-u3 appends its rows below this line.

if [ "$fail" -eq 0 ]; then echo "All prompt-diet-pins checks passed."; else echo "prompt-diet-pins: FAILED"; fi
exit "$fail"
~~~
2. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 1
   The red step: the rationale doc does not exist and the narratives are still in the orchestrator.
3. file: `docs/orchestrator-rationale.md`
   anchor: new file
   indent: 0
   insert-after:
~~~
# Orchestrator rationale and incident notes

Moved out of `agents/orchestrator.md` by qw-u2 (2026-10-20, spec `docs/plans/antislop-quick-wins/spec.md`,
Step 2). These paragraphs explain why a rule exists; the rules themselves stay in the orchestrator prompt.
Nothing here is loaded at runtime.

## N1: reviewer dispatch naming, the unobserved residual (from "Dispatch naming for this project's reviewer")

`start-feature-team.md` enforces this discipline at team-creation time. Do not dispatch a reviewer under a custom name such as `rev-302` — the dispatch itself is refused. The actual, unobserved residual is different: `reviewer-route-gate.sh` only inspects the *requested* `tool_input.name` at dispatch time, never the harness's post-spawn `agent_type` — so a correctly-named `reviewer` dispatch can still end up running under a harness name-collision auto-suffix if a same-named agent is already active, a collision the gate cannot see. A session running under that suffixed identity loses marker-write and flag-clear privileges at the CONSERVATIVE grant sites (`reviewed-path-gate.sh`, `stop-gate.sh`); per `agents/reviewer.md`'s documented recovery, it reports the block, its completed verdict, and the marker body it would have written, so the failure surfaces rather than vanishing.

## N2: `Agent` naming vs `SendMessage` addressing

**`Agent` naming vs `SendMessage` addressing — two different mechanisms.** The unnamed-dispatch default above (omit `name:`) applies to `Agent` dispatch only, where a name is a parameter you can choose to pass or not. `SendMessage` has no such option: it addresses an existing agent *by name*, by construction — there is no "unnamed" `SendMessage`, so the default that fixes the `Agent` path cannot apply here even in principle. That is exactly why the roster check below is the control on the `SendMessage` path.

## N3: why the roster check exists (from "Reviewer re-tasking discipline")

This discipline prevents the practical incident that produced gh-304, where a bare-name `SendMessage` reached an idle session from an unrelated plan, which then performed a genuine review and wrote a conflicting verdict.

## N4: auto-notification is not reliable for nested dispatches (from "Default dispatch naming")

The auto-notification is **not** a property to rely on when a persona dispatches its own subagent. This project has observed: three unnamed subagents dispatched by a teammate all completed without notifying their dispatcher, each returning "had no active task" when later resumed. A persona that spawns its own subagent must therefore collect the result explicitly rather than waiting to be told, which is the same conclusion the shared protocol's "there is no self-wake" section already reaches for background `Bash`.

## N5: why unnamed is the default, full mechanism (from "Default dispatch naming")

**Why unnamed is the default (confirmed mechanism):** Anthropic's docs (https://code.claude.com/docs/en/agent-teams, "Claude spawns teammates instead of subagents") confirm that while `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled, any named subagent dispatch launches as a teammate, and a teammate's completion surfaces only as a content-free idle notification — not the auto-returned result an unnamed dispatch gets — unless it explicitly `SendMessage`s back. Quoting the docs directly: "An orchestration flow that waits on subagent results can stall." This is the confirmed root cause behind the auto-notification asymmetry described above, not just an observed quirk. For the same reason, this project's shipped `.claude/settings.json` now defaults `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"0"` — agent-teams mode is a deliberate per-task opt-in via `/antislop:start-feature-team`, not an always-on background setting a stray named dispatch could silently trip.
~~~
4. file: `agents/orchestrator.md`
   anchor: line starting `**Dispatch naming for this project's reviewer (if present).**` (rule O1 kept, narrative N1 moved)
   indent: 0
   before:
~~~
**Dispatch naming for this project's reviewer (if present).** In subagent-orchestrator mode, dispatch the `reviewer` with no `name:` parameter — an unnamed dispatch reports the bare persona name to the grant matcher and preserves all privileges. Where a name is unavoidable (agent-teams mode), it must be exactly `reviewer`; any other explicit name is refused outright by `reviewer-route-gate.sh` at dispatch time, before the `Agent` call even proceeds — not a silent failure, the block names the fix. `start-feature-team.md` enforces this discipline at team-creation time. Do not dispatch a reviewer under a custom name such as `rev-302` — the dispatch itself is refused. The actual, unobserved residual is different: `reviewer-route-gate.sh` only inspects the *requested* `tool_input.name` at dispatch time, never the harness's post-spawn `agent_type` — so a correctly-named `reviewer` dispatch can still end up running under a harness name-collision auto-suffix if a same-named agent is already active, a collision the gate cannot see. A session running under that suffixed identity loses marker-write and flag-clear privileges at the CONSERVATIVE grant sites (`reviewed-path-gate.sh`, `stop-gate.sh`); per `agents/reviewer.md`'s documented recovery, it reports the block, its completed verdict, and the marker body it would have written, so the failure surfaces rather than vanishing.
~~~
   after:
~~~
**Dispatch naming for this project's reviewer (if present).** In subagent-orchestrator mode, dispatch the `reviewer` with no `name:` parameter — an unnamed dispatch reports the bare persona name to the grant matcher and preserves all privileges. Where a name is unavoidable (agent-teams mode), it must be exactly `reviewer`; any other explicit name is refused outright by `reviewer-route-gate.sh` at dispatch time, before the `Agent` call even proceeds — not a silent failure, the block names the fix.
~~~
5. file: `agents/orchestrator.md`
   anchor: line starting `**\`Agent\` naming vs \`SendMessage\` addressing` (narrative N2 moved; delete this line and the blank line after it)
   indent: 0
   delete:
~~~
**`Agent` naming vs `SendMessage` addressing — two different mechanisms.** The unnamed-dispatch default above (omit `name:`) applies to `Agent` dispatch only, where a name is a parameter you can choose to pass or not. `SendMessage` has no such option: it addresses an existing agent *by name*, by construction — there is no "unnamed" `SendMessage`, so the default that fixes the `Agent` path cannot apply here even in principle. That is exactly why the roster check below is the control on the `SendMessage` path.
~~~
6. file: `agents/orchestrator.md`
   anchor: line starting `**Reviewer re-tasking discipline` (rules O2 and O3 kept, narrative N3 moved)
   indent: 0
   before:
~~~
**Reviewer re-tasking discipline: never re-task by message for a different unit.** Only a fresh `Agent` dispatch whose first non-blank line is `Unit: <id>` writes the per-unit review-join stamp — a `SendMessage` carries no unit id and cannot write one. Resuming a reviewer by message is correct for exactly one purpose: continuing the unit it was already dispatched for (see the `INSUFFICIENT-CONTEXT` path below for this documented exception); every other purpose requires a fresh `Agent` dispatch. **Check the roster before resuming one by name**: if an addressable agent already holds the reviewer's name in this session, a bare-name `SendMessage` resolves to its most recent holder — possibly a stale session from an unrelated plan — so confirm which unit the addressee was actually dispatched for (ask it by name) before reusing the name, and dispatch a fresh `Agent` call instead if it doesn't match. This discipline prevents the practical incident that produced gh-304, where a bare-name `SendMessage` reached an idle session from an unrelated plan, which then performed a genuine review and wrote a conflicting verdict.
~~~
   after:
~~~
**Reviewer re-tasking discipline: never re-task by message for a different unit.** Only a fresh `Agent` dispatch whose first non-blank line is `Unit: <id>` writes the per-unit review-join stamp — a `SendMessage` carries no unit id and cannot write one. Resuming a reviewer by message is correct for exactly one purpose: continuing the unit it was already dispatched for (see the `INSUFFICIENT-CONTEXT` path below for this documented exception); every other purpose requires a fresh `Agent` dispatch. **Check the roster before resuming one by name**: if an addressable agent already holds the reviewer's name in this session, a bare-name `SendMessage` resolves to its most recent holder — possibly a stale session from an unrelated plan — so confirm which unit the addressee was actually dispatched for (ask it by name) before reusing the name, and dispatch a fresh `Agent` call instead if it doesn't match.
~~~
7. file: `agents/orchestrator.md`
   anchor: line matching `### A missing roster row is not proof a teammate is dead` (rule O4 moved; delete from this heading through the blank line before `### Nested dispatches (a persona spawning its own subagent)`)
   indent: 0
   delete:
~~~
### A missing roster row is not proof a teammate is dead
This extends the four-state list above with a caveat specific to named
teammates under an active feature team (see "If a feature team is active"
below) — it describes when the roster's visual signal can't be trusted, not
a fifth liveness state. Anthropic's docs
(https://code.claude.com/docs/en/agent-teams, troubleshooting section
"Teammates not appearing") confirm: "A teammate row that disappeared after
sitting idle has been hidden, not stopped." Idle rows hide roughly 30
seconds after the whole panel goes idle and reappear on the teammate's next
turn; more than three idle teammates collapse into a single `N idle agents`
summary row. An absent roster row is therefore ambiguous, never by itself
evidence that the teammate terminated.

Diagnostic procedure: before concluding a named teammate is dead or
orphaned just because its row is absent from the roster, `SendMessage` it
by name first — a hidden-but-alive teammate resumes and its row reappears
on its next turn. Only escalate to filing a bug against
`anthropics/claude-code` if that `SendMessage` also fails (e.g. "no such
agent") *while* `~/.claude/teams/session-*/config.json` still lists that
member as active — attach that `config.json` snapshot to the filed issue as
evidence of the contradiction between the roster/`SendMessage` failure and
the team's own recorded membership.
~~~
8. file: `commands/start-feature-team.md`
   anchor: line matching `v2.1.178).` (the file's last line)
   indent: 0
   insert-after:
~~~

**A missing roster row is not proof a teammate is dead.** This caveat is about named teammates in this team:
it describes when the roster's visual signal can't be trusted, not a new liveness state. Anthropic's docs
(https://code.claude.com/docs/en/agent-teams, troubleshooting section
"Teammates not appearing") confirm: "A teammate row that disappeared after
sitting idle has been hidden, not stopped." Idle rows hide roughly 30
seconds after the whole panel goes idle and reappear on the teammate's next
turn; more than three idle teammates collapse into a single `N idle agents`
summary row. An absent roster row is therefore ambiguous, never by itself
evidence that the teammate terminated.

Diagnostic procedure: before concluding a named teammate is dead or
orphaned just because its row is absent from the roster, `SendMessage` it
by name first — a hidden-but-alive teammate resumes and its row reappears
on its next turn. Only escalate to filing a bug against
`anthropics/claude-code` if that `SendMessage` also fails (e.g. "no such
agent") *while* `~/.claude/teams/session-*/config.json` still lists that
member as active — attach that `config.json` snapshot to the filed issue as
evidence of the contradiction between the roster/`SendMessage` failure and
the team's own recorded membership.
~~~
9. file: `agents/orchestrator.md`
   anchor: line starting `The auto-notification is **not**` (rule O5 kept, narrative N4 moved)
   indent: 0
   before:
~~~
The auto-notification is **not** a property to rely on when a persona dispatches its own subagent. This project has observed: three unnamed subagents dispatched by a teammate all completed without notifying their dispatcher, each returning "had no active task" when later resumed. A persona that spawns its own subagent must therefore collect the result explicitly rather than waiting to be told, which is the same conclusion the shared protocol's "there is no self-wake" section already reaches for background `Bash`.
~~~
   after:
~~~
The auto-notification is **not** a property to rely on when a persona dispatches its own subagent: a persona that spawns its own subagent must collect the result explicitly rather than waiting to be told, which is the same conclusion the shared protocol's "there is no self-wake" section already reaches for background `Bash`.
~~~
10. file: `agents/orchestrator.md`
   anchor: line starting `**Why unnamed is the default` (rule O6 kept, narrative N5 moved)
   indent: 0
   before:
~~~
**Why unnamed is the default (confirmed mechanism):** Anthropic's docs (https://code.claude.com/docs/en/agent-teams, "Claude spawns teammates instead of subagents") confirm that while `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled, any named subagent dispatch launches as a teammate, and a teammate's completion surfaces only as a content-free idle notification — not the auto-returned result an unnamed dispatch gets — unless it explicitly `SendMessage`s back. Quoting the docs directly: "An orchestration flow that waits on subagent results can stall." This is the confirmed root cause behind the auto-notification asymmetry described above, not just an observed quirk. For the same reason, this project's shipped `.claude/settings.json` now defaults `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"0"` — agent-teams mode is a deliberate per-task opt-in via `/antislop:start-feature-team`, not an always-on background setting a stray named dispatch could silently trip.
~~~
   after:
~~~
**Why unnamed is the default:** while `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled, any named subagent dispatch launches as a teammate, whose completion surfaces only as a content-free idle notification unless it explicitly `SendMessage`s back. This project's shipped `.claude/settings.json` therefore defaults `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"0"` — agent-teams mode is a deliberate per-task opt-in via `/antislop:start-feature-team`.
~~~
11. file: `tests/validate.sh`
   anchor: line matching `echo "== tests/persona-prose-pins.test.sh:`
   indent: 0
   before:
~~~
echo "== tests/persona-prose-pins.test.sh: wave-7 prose pins for persona sources, mirrors and ports (Bash, ptr-u13b) =="
if bash tests/persona-prose-pins.test.sh > /dev/null; then
  echo "OK   tests/persona-prose-pins.test.sh"
else
  echo "FAIL tests/persona-prose-pins.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== tests/persona-prose-pins.test.sh: wave-7 prose pins for persona sources, mirrors and ports (Bash, ptr-u13b) =="
if bash tests/persona-prose-pins.test.sh > /dev/null; then
  echo "OK   tests/persona-prose-pins.test.sh"
else
  echo "FAIL tests/persona-prose-pins.test.sh"
  fail=1
fi

echo
echo "== tests/prompt-diet-pins.test.sh: rules moved or shortened by the prompt diet survive (Bash, qw-u2) =="
if bash tests/prompt-diet-pins.test.sh > /dev/null; then
  echo "OK   tests/prompt-diet-pins.test.sh"
else
  echo "FAIL tests/prompt-diet-pins.test.sh"
  fail=1
fi
~~~
12. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.188 to 0.31.189).
13. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Orchestrator narrative trim (qw-u2, VERSION).** agents/orchestrator.md loses five incident narratives and rationale paragraphs (moved verbatim to docs/orchestrator-rationale.md) and the teams-only "missing roster row" subsection (moved to commands/start-feature-team.md). No rule removed: each survivor is pinned by the new tests/prompt-diet-pins.test.sh. The installed orchestrator prompt is about 3759 bytes smaller.
~~~
   Replace `VERSION` with the version that edit 12 wrote.
14. command: `node bin/cli.js --update`
   expect: 0
15. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 0
16. command: `git add tests/prompt-diet-pins.test.sh docs/orchestrator-rationale.md && git add -u && git commit -m "feat(qw-u2): move orchestrator narratives to docs; every rule kept and pinned"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `adapters/codex/agents/orchestrator.toml` and `adapters/cursor/agents/orchestrator.md` (their condensed ports carry none of these narratives; criterion 3 checks they are unchanged)
- `templates/persona-protocol.md` (protocol text is qw-u3's)
- `CONTEXT.md` and `docs/harness-glossary.md` (they cite gh-304 as an incident, not this text; no edit needed)
- `.claude/agents/orchestrator.md` by hand (only `node bin/cli.js --update` writes it)
- `agents/orchestrator.md` ESCALATE-TO-HUMAN steps (qw-u4 moves them; leave them as they are)

## Acceptance criteria
1. run: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 8 (the roster text never reaches the command file); the `start-feature-team.md` pins fail and stdout is `1`.
2. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u2)" | tail -1); old=$(git show "$b^:.claude/agents/orchestrator.md" | wc -c); new=$(wc -c < .claude/agents/orchestrator.md); echo $(( old - new >= 3400 ))'`
   exit: 0
   stdout: `1`
   mutation: skip edits 7 and 10; the mirror shrinks by less than 3400 bytes and stdout is `0`.
3. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u2)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters templates hooks | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/agents/orchestrator.md` in a qw-u2 commit; stdout is at least `1`.
4. run: `bash -c 'node tests/writer-tier-consistency.test.js >/dev/null && node tests/adapter-protocol-parity.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the line `**Escalation ladder.** Each implementer tier gets two attempts` from agents/orchestrator.md; writer-tier-consistency fails and stdout is `1`.
5. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u2)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip the version-bump edit; stdout reads `version-stamp-check: violation touched: yes`.
6. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/prompt-diet-pins.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the pins test (edit 1) comes first and fails (edit 2); spec-master ran the edits on a copy and measured 3759 bytes saved.
blast-radius: agents/orchestrator.md:186, agents/orchestrator.md:188, agents/orchestrator.md:190, agents/orchestrator.md:673, agents/orchestrator.md:744, agents/orchestrator.md:752, commands/start-feature-team.md:89, tests/validate.sh:1442. Line numbers are at bce2ded2; earlier units shift them, so work from the anchors.
rule-map: O1 unnamed reviewer dispatch, exact name `reviewer`, gate refusal -> orchestrator (edit 4 keeps it). O2 roster check before resuming a reviewer by name -> orchestrator (edit 6 keeps it). O3 only a fresh `Agent` dispatch writes the review-join stamp; `SendMessage` only continues the same unit -> orchestrator (edit 6 keeps it). O4 a missing roster row is not proof of death; `SendMessage` first; file a bug only on a contradiction -> commands/start-feature-team.md (edit 8). O5 a persona that spawns a subagent collects its result explicitly -> orchestrator (edit 9). O6 a named dispatch under the agent-teams flag launches a teammate; the shipped default is `"0"` -> orchestrator (edit 10).
pins-searched: spec-master searched every phrase of the moved text in tests/ (45-character sliding window) and found no pin on it; criterion 4 re-runs the three prose-pin suites that touch agents/orchestrator.md.
four-copy: the codex and cursor orchestrator ports already omit all five narratives and the roster subsection, so they are not edited (criterion 3).
version: .claude-plugin/plugin.json and package.json read 0.31.188 after qw-u1 if no fix round bumped; edit 12 adds one (expected 0.31.189).
mirrors: `.claude/agents/orchestrator.md` changes only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(qw-u2): move orchestrator narratives to docs; every rule kept and pinned
diagnosis: none
review-packet:
~~~
unit: qw-u2
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
If a `before:` or `delete:` payload is not found verbatim, stop and report the current text; do not
improvise. If `node bin/cli.js --update` reports a diverged mirror, quote it and stop. If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes to your report as a proposal.
