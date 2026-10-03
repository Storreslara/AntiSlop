# ADR 0039: Escalation decisions may be completed in-session through a prompt-confirmed decision write (amends ADR-0036; narrows ADR-0034's Bash exclusion for one shape)

Date: 2026-10-03

Status: Accepted (units esc-chat-2, esc-chat-2b, esf-gate-bytes, esc-chat-3,
esc-chat-4; plan `docs/plans/2026-10-01-in-session-escalation-decision.md`,
FINAL, amended 2026-10-02). The esc-chat-1 record reads `Ship gate: GREEN`
(see "Measurement (the esc-chat-1 ship gate)" below). That section says what
the probe measured and what it did not; nothing in this ADR claims more.

## Context

When a unit is escalated (`ESCALATE-TO-HUMAN`), the human used to resolve it
only by writing the DECISION file themselves: a `printf` typed in the
terminal, or the Microworld dashboard's confirmation-code flow. The terminal
step breaks the flow of a review the operator otherwise values. Having a hook
transcribe an `AskUserQuestion` answer into the file was considered and
rejected (below): it leaves a forgeable oracle and depends on an undocumented
payload.

The 2026-08-11 plan (`docs/plans/2026-08-11-human-decision-channel.md`)
rejected Claude Code's permission prompt as a consent channel on three
grounds. This ADR answers them; it does not reverse them:

- **(a) A granted call looks the same whether a human or an allowlist
  approved it.** `docs/experiments/2026-09-23-probe-permission-mode-ask.md`
  records U1 `ask-still-prompts`: a hook's `ask` is not overridden by
  `permissions.allow`.
- **(b) Behaviour depends on the mode.** Answered by a frozen mode allowlist
  (below) and, for Bash specifically, by the esc-chat-1 measurement (below).
- **(c) A prompt lives inside one session.** The terminal and dashboard routes
  are unchanged, so a packet still outlives the session.

## Decision

`hooks/scripts/human-decision-gate.sh` emits `permissionDecision: "ask"`,
**never `allow`**, for exactly one strictly parsed Bash command: the
composer's heredoc (`bin/microworld-dashboard/decision-block.js`,
`composeDecisionBlock('escalation-decision', {via: 'prompt', projectDir})`
and `composeHeredocCommand`), of the form
`cat > <abs>/.claude/human-review/<ID>/DECISION <<'EOF'` followed by the body
and a final `EOF` line. This is the **prompt-confirmed decision write**
(CONTEXT.md). The predicate is `is_prompt_eligible_decision_write`; it holds
only when all of these hold:

- `<abs>` equals `$CLAUDE_PROJECT_DIR` exactly, `>` only (never `>>`),
  separators are space or tab only, the delimiter is exactly `'EOF'`, and the
  first line equal to `EOF` is the last line;
- **main session only**: the payload carries no `agent_id`. Whether an
  agent-teams teammate can arrive with no `agent_id` is still **unmeasured**;
  see `docs/plans/2026-10-02-escalation-followups.md` (R4). The operator ran
  `scripts/probe-hook-identity.sh` (record
  `docs/experiments/2026-10-03-probe-hook-identity.md`, self-reported, CLI
  2.1.288): the main session, with teams off and on, carried no `agent_id`,
  a subagent carried one, and the run's named "teammate" ran as a plain
  subagent (`Teammate check: subagent-shaped`; the interactive tmux retry
  captured no teammate lines). No genuine agent-teams teammate was observed,
  so the record reads `Outcome: D`: no gate change, and the conditional unit
  `esf-eid-gate` is not triggered. "Asks only from the main session" still
  rests on the unmeasured teammate premise;
- `permission_mode` is one of **default, acceptEdits, auto** (a frozen
  allowlist, not a denylist);
- a standing `.escalated` marker whose first line names this id and the
  timestamp the body cites, no existing DECISION file, and a packet directory
  that exists, with neither it nor `human-review/` a symlink;
- the body passes the grammar: header line, `by:`, `via: prompt`, then at
  most one `examples:` line (approve; the line may be omitted) or `reason:`
  plus continuation lines (reject/direct);
  no control, zero-width or bidi characters, no U+2028/U+2029, no non-ASCII
  byte before a continuation line's first ASCII letter or digit, and no
  continuation line that starts with a reserved key (`DECISION `, `by:`,
  `via:`, `examples:`, `reason:`; ASCII case-insensitive, leading spaces
  tolerated).

**Denied modes, each for its own reason:**

- **plan** is excluded by policy because plan mode is read-only, so there is
  no write approval for a human to make there (Amendment A1, 2026-10-02). This
  is a policy exclusion, not an inference from a measurement (the probe could
  not drive plan mode: the model never calls Bash there).
- **bypassPermissions** and **dontAsk** are excluded because a silent
  auto-approve there, now or after a future Claude Code change, would be an
  undetectable fabricated approval.
- An empty, absent or unknown mode denies too.

Everything else gets the gate's existing deny, and the orchestrator falls
back to the terminal `printf` template. The gate's `Write`/`Edit` branch still
always denies a DECISION target (under `reviewGating.mode` `enforce`). Under
`reviewGating.mode` `off` the gate exits 0 before any of this, unchanged: no
escalation exists in that mode.

**Narrowing ADR-0034.** ADR-0034 excluded Bash from the harness-integrity
gate's ask branch because a padded command could hide the write from the
human's eye. That reasoning does not apply to this one shape: the parser
accepts nothing but the heredoc, so the design premise is that the command
the human sees at the prompt is the file. ADR-0034 is otherwise untouched,
and the harness-integrity gate's Bash branch is unchanged.

**Amending ADR-0036.** ADR-0036's "keep as-is" is superseded for this one
branch only. The rest of the gate is still kept as-is.

## Measurement (the esc-chat-1 ship gate)

The operator ran `scripts/probe-bash-ask.sh` (@ b769d8e) and committed its
record, `docs/experiments/2026-10-01-probe-bash-ask.md` (self-reported; the
record states CLI `2.1.287`; the default pane's banner agrees, but the
acceptEdits, auto, dontAsk and bypassPermissions banners show v2.1.288,
probably a CLI auto-update during the run). It reads
`Ship gate: GREEN`. What it measured:

- a **probe** PreToolUse hook that always answers `ask` for Bash, in a scratch
  directory outside the repo (not `human-decision-gate.sh`);
- in **default, acceptEdits and auto**, a 7-line Bash heredoc rendered a
  permission prompt, the whole heredoc was visible in that prompt with no
  expansion keystroke, and declining left no file;
- dontAsk and bypassPermissions also rendered the prompt (informational: this
  ADR denies both by policy); plan was not driven (informational: the model
  never reaches Bash there);
- headless `-p` (a one-line `printf`, not the heredoc): the Bash call was
  denied (`permission_denials` names Bash, no file).

What it did not measure: the real gate end to end in a live escalation, any
Claude Code version other than this one run's (2.1.287/2.1.288), and
agent-teams teammates (see the identity probe under "main session only"
above). "The human sees the exact bytes" is therefore a measured property of
the prompt for one probe hook in one run, not of every version or run.

The decision rule the record was judged against stays as history; GREEN
triggered neither RED branch:

- **RED in default, or a heredoc that is not fully visible**: the design
  returns to spec-master.
- **RED in acceptEdits or auto only**: that mode is dropped from the allowlist.
- A material Claude Code upgrade re-runs the probe (R2, drift). This still
  applies.

## Consequences

- **The guarantee narrows.** Before: "if DECISION exists, no harness tool call
  created it". Now: "if DECISION exists, either a human wrote it outside the
  harness (terminal or dashboard), or a human approved its exact bytes at
  Claude Code's permission prompt". No agent can complete a DECISION write
  without a human approving its bytes; an agent can still *propose* one.
  No subagent can reach the ask (it carries an `agent_id`).
- **Audit before answer.** The gate appends a `decision-gate-asked` line to
  `.claude/review-audit.log` when it asks, before the human answers. An asked
  line with no DECISION file afterwards means the human declined, the ask
  was denied (including in a headless run, where no human answers), or the
  approved write failed; the line alone cannot say which. `via: prompt` lives
  in the file body, not in that line.
- **Approval fatigue** is mitigated, not removed, by a fixed prompt reason
  built only from the parsed route enum and task id.
- **Headless runs** have no human to answer; Claude Code denies an `ask` in
  `-p` (measured for Write in the 2026-09-23 record; for Bash, with the probe
  hook, in the esc-chat-1 record).
- **Residual, shared by every route:** an agent can add a hook in the
  unguarded `.claude/settings.local.json`. Documented, not fixed.
- **Known, non-security notes:** the composer's older command-substitution
  screen (`$(`, backtick, `${`) refuses more than the gate does, which fails
  closed to the terminal route. The gate screens bytes under `LC_ALL=C`,
  which matters only in non-UTF-8 multibyte locales (test case PG20-gb18030).

## Rejected alternatives

- **A PostToolUse hook on `AskUserQuestion` that writes DECISION.** The writer
  becomes an oracle any agent can call from Bash without spelling the path;
  the `tool_response` shape is undocumented (ADR-0034 blocker 3); answers may
  ride `updatedInput.answers`, which hooks can fill (an inference); and the
  human never sees the recorded bytes.
- **A `UserPromptSubmit` typed command.** The same oracle problem, and the
  human still types a grammar.
- **The dashboard's `/dev/tty` code reused in chat.** The human types a code,
  and any secret a hook holds is readable by agents.
- **Grant the orchestrator Write.** Widens the thin router; Bash is already in
  its tool list.

## Related

- [ADR-0034](0034-human-confirmation-branch-per-call-consent-not-escalation.md) (Bash exclusion, narrowed here for one shape)
- [ADR-0035](0035-hcb-branch-measured-disposition-unamortized-but-not-dead.md)
- [ADR-0036](0036-human-decision-gate-keep-as-is-mode-off.md) (amended here for one branch)
- `docs/plans/2026-08-11-human-decision-channel.md` (the original objections)
- `docs/experiments/2026-09-23-probe-permission-mode-ask.md` (U1 `ask-still-prompts`)
- [`docs/experiments/2026-10-01-probe-bash-ask.md`](../experiments/2026-10-01-probe-bash-ask.md) (the esc-chat-1 record, `Ship gate: GREEN`, produced by `scripts/probe-bash-ask.sh`)
- [`docs/experiments/2026-10-03-probe-hook-identity.md`](../experiments/2026-10-03-probe-hook-identity.md) (the identity record, `Outcome: D`, produced by `scripts/probe-hook-identity.sh`)
- `docs/plans/2026-10-01-in-session-escalation-decision.md` (this decision's plan)
- `docs/plans/2026-10-02-escalation-followups.md` (R4: the unmeasured teammate premise)
