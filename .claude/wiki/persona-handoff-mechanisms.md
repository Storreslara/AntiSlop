# Persona handoff mechanisms

Three protocols enable clean handoffs when a dispatched persona ends its turn (either voluntarily or via a `maxTurns` cap):

## 1. WIP sentinel (voluntary mid-task pause)

When a persona genuinely needs to end its turn with work in progress — a TDD red phase that will be fixed in the next resume, a blocked report awaiting clarification, or a "the plan is wrong" escalation — it writes a sentinel file with a non-empty reason:

```bash
echo "TDD red phase, 3 tests intentionally failing" > .claude/wip-handoff.<your-agent-id>
```

**Enforcement:** The `stop-gate.sh` hook checks for this file at turn-end. If it exists and has non-empty content, the hook:
- Logs the reason (with timestamp) to `.claude/wip-audit.log`
- Deletes the sentinel file
- Allows that one turn to end

**Important:** An empty sentinel (bare `touch`) is deleted but **not** honored — the normal checks still run.

**Usage discipline:** This is strictly for legitimate pauses, not for evading a red suite you could fix. The audit log exists so that use is reviewable after the fact.

**Relationship to the status line:** A turn ended via the WIP sentinel must also end with `STATUS: incomplete — <the same reason written into the sentinel>` (see "Terminal status line" below).

---

## 2. Pending-review flag (gated-agent backstop)

In default (subagent-orchestrator) mode, when a gated agent (like `lead-programmer`) finishes work and its `SubagentStop` is **not** honored by a WIP sentinel, `stop-gate.sh` automatically writes:

```
.claude/.pending-review.<agent-id>
```

This marks a completed unit awaiting review.

**Enforcement:** While this flag exists:
- The main-session `Stop` hook blocks turn-end with exit 2: "a completed unit is awaiting review"
- `reviewer-route-gate.sh` blocks dispatching the next gated-agent unit
- Non-gated personas (like `explorer`) are still dispatchable

**Clearing the flag:** The reviewer's own `SubagentStop` clears all pending-review flags (whether it's a PASS or FAIL verdict) and logs `cleared-by=reviewer` to `.claude/review-audit.log`.

**Identity-drift lines in the audit log:** Occasionally you may see lines in `.claude/review-audit.log` like:
```
2026-07-30T10:15:42Z identity-drift class=unparseable hook=reviewed-path-gate identity=some%2Fbad%2Fvalue
2026-07-30T10:16:01Z identity-drift class=unrecognized-namespace hook=stop-gate identity=otherplugin%3Areviewer
```

These signal that a hook received an agent identity it could not recognize or parse. They are **not errors** and do **not** block execution — they are observability lines that flag a potential future problem:

- `class=unparseable` — The identity did not match the expected format (should be bare persona name or `namespace:persona-name`). This might indicate a Claude Code update changed the `agent_type` field format. **Action:** Read the full identity (percent-encoded; decode with `python3 -c 'import urllib.parse; print(urllib.parse.unquote(...))'`) and check whether Claude Code's dispatch mechanism has drifted.

- `class=unrecognized-namespace` — The identity carries a namespace that is not this project's recognized namespace. This is normal if you have a marketplace-installed plugin and are using a different adapter (Cursor, Codex, or a competing plugin), but it could also signal namespace confusion. **Action:** Verify that the namespace matches your installed plugin. If you see `otherplugin:` in identities but `otherplugin` is not installed, or if you see the wrong plugin name despite a fresh plugin install, escalate to the plugin vendor.

Both classes are deduplicated, so the log grows only with distinct drift events. Bare identities that are simply unrecognized persona names (e.g., `Explore`, `general-purpose`, `Plan`) are deliberately **not** logged — that is normal traffic, not drift.

**Escape hatches (both logged to the audit log, with reasons required):**
- Overwrite with `defer: <reason>` → flag kept, that Stop allowed, review still owed next turn
- Overwrite with `skip: <reason>` → flag deleted, unit explicitly abandoned

An empty overwrite is rejected just like an empty WIP sentinel.

**Scope:** This gate applies only in default mode (no agent-teams mode), and only to gated agents (configured in `.claude/persona-config.json`).

---

## 3. Terminal status line (every dispatched turn)

When any persona hands control back to a caller — a dispatched subagent returning to the orchestrator, or a teammate reporting to the lead via `SendMessage` in agent-teams mode — it must end its message with a machine-checkable terminal status line as the last non-empty line, exactly one of:

```
STATUS: complete
```

or

```
STATUS: incomplete — <one-line, non-empty reason>
```

(An ASCII hyphen `-` is an accepted substitute for the em dash `—`, for encoding robustness.)

**Why this exists (core facts — do not change this via a hook):**

- **F2 (harness opacity):** When a persona hits its `maxTurns` cap, the harness appends a `max_turns_reached` attachment to the Agent-tool result. This attachment renders as **zero content blocks** — the persona's final turn produces no visible error, no marker, and no indication anything was wrong. A truncated turn is therefore indistinguishable from a completed one, unless a finished one carries a signature.
  
- **F3 (no counter observable):** No turn counter is observable from inside a subagent at all — no environment variable, no tool, no system-reminder entry. `CLAUDE_CODE_MAX_TURNS` is an *input* that sets the cap; it does not report progress. So the pattern "self-checkpoint at N-5" is not implementable as a counted rule.
  
- **F5 (hook gap on cutoff):** `SubagentStop` almost certainly does **not** fire when the harness cuts off a mid-tool-loop dispatch. The mid-loop check returns before the stop-hook runner is invoked, and the official Claude Code docs confirm that hooks may not fire when the agent hits `maxTurns`.

Because the persona cannot detect it has been cut off (F2, F3) and the hook layer cannot either (F5), **cutoff detection must work on the parent side**: if every finished persona signs its final message, then a result lacking that signature was cut off, by construction.

This line is that signature. Its absence is the only available evidence of a cutoff.

**A false-positive is safer than a false-negative:** This converts a dangerous silent truncation (reads as success, breaks silently at runtime) into a safe false-positive (a persona legitimately finished but forgot the line, prompting an unnecessary resume). An unnecessary resume costs one cheap turn; a missed cutoff costs a silently-wrong result.

**Trigger condition:** Every turn-end where the persona hands control to a caller. Does **not** apply to the main-session `orchestrator` answering the user directly (there is no caller to signal; the orchestrator is deliberately uncapped; printing the line at the end of every user-facing reply would be noise).

**Not a substitute for the WIP sentinel:** The two are different mechanisms and co-occur. The sentinel is a **file** written before a voluntary pause; the status line is a **report line** emitted at every turn-end. A turn ended via the WIP sentinel is therefore:
```
STATUS: incomplete — <the same reason written into the sentinel>
```

**Not enforced by the harness, not a FAIL gate, not a defect:** This is an instruction-only convention. A persona will sometimes forget to emit the line; this is the accepted cost. A missing line is a prompt to resume, never a defect, never a `.fail` marker, never 2-FAIL-cap credit — cost one cheap resume, which is the entire point.

---

## Harness-version coupling (R5)

The facts above (F1–F9) were verified against **Claude Code v2.1.220**. If a future Claude Code release exposes a real termination-reason field on the Agent-tool result or on `SubagentStop`, this design should be revisited rather than kept forever. The mechanism is coupled to this specific version and that coupling should be documented in any CHANGELOG entry describing it.

The same live cutoff event that motivated this whole page (a `spec-master`
dispatch force-ended mid-task at `maxTurns: 30` on 2026-07-28) also carried a
bundled, **un-measured** change: raising `spec-master`/`task-master`'s
`maxTurns` from 30 to 40, shipped by product decision with no controlled
trial — no cost/turns/wall-time data, no holdout run. That's tracked as
entry **E6** in the self-improvement-loops experiment ledger; see
[experiment-ledger.md](experiment-ledger.md) for the full measured-vs-un-measured
breakdown (canonical source: `docs/self-improvement-loops.md`).

---

## Deferred probe (not abandoned)

A live probe of whether `SubagentStop` fires on a mid-tool-loop cutoff was originally proposed. It is **deferred, not abandoned** — it remains an open experiment for future work. The only reason to run it would be if hook-level enforcement of the status line is ever revisited, and the probe is the first thing that should run in that case because F4/F5 suggest the hook most likely never fires on the failing path (which would make hook-based enforcement a no-op).
