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

The auto-notification is **not** a property to rely on when a persona dispatches its own subagent. This project has observed: three unnamed subagents dispatched by a teammate all completed without notifying their dispatcher, each returning "had no active task" when later resumed. An unnamed dispatch returns its result to the orchestrator. A persona that spawns its own subagent must therefore collect the result explicitly rather than waiting to be told, which is the same conclusion the shared protocol's "there is no self-wake" section already reaches for background `Bash`.

## N5: why unnamed is the default, full mechanism (from "Default dispatch naming")

**Why unnamed is the default (confirmed mechanism):** Anthropic's docs (https://code.claude.com/docs/en/agent-teams, "Claude spawns teammates instead of subagents") confirm that while `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled, any named subagent dispatch launches as a teammate, and a teammate's completion surfaces only as a content-free idle notification — not the auto-returned result an unnamed dispatch gets — unless it explicitly `SendMessage`s back. Quoting the docs directly: "An orchestration flow that waits on subagent results can stall." This is the confirmed root cause behind the auto-notification asymmetry described above, not just an observed quirk. For the same reason, this project's shipped `.claude/settings.json` now defaults `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"0"` — agent-teams mode is a deliberate per-task opt-in via `/antislop:start-feature-team`, not an always-on background setting a stray named dispatch could silently trip.

## N6: why effort scales to the task (from "Scale effort to the task")

Over-delegating trivial work into the full Explore → Plan → Implement → Verify → Commit pipeline is the most commonly reported multi-agent failure mode, so it is never the default. The orchestrator has no Write/Edit tool, so even a trivial file change routes to the lead-programmer; its own narrow Bash writes (`.claude/.dispatch-override`, the `defer:`/`skip:` flag content) are sanctioned single-purpose sentinel writes, never a substitute for routing a real code or doc change.

## N7: why the scribe needs both the issue number and the task-id (from "Scribe dispatch convention")

These inputs are not interchangeable: the scribe's issue-closing logic uses both. Markers live at `.claude/reviewed/<task-id>.pass`, but the tracker issue is a separate number, so the task-id cannot be derived from the issue number.

## N8: what the rulings ledger is not (from "Rulings ledger")

The ledger is a lightweight, append-only log for the human audit trail. It is not a gate, no hook checks it, and it is not a substitute for the FAIL record or the `.claude/reviewed/` markers, which remain the authoritative record of verdicts. This project deliberately does not adopt the "never pause, just decide" philosophy some orchestration systems use: the ledger only records decisions the orchestrator was already authorized to make on its own (e.g. a downgrade-only tier override), and it never replaces an `AskUserQuestion` path.

## N9: why INSUFFICIENT-CONTEXT never re-dispatches the writer (from "Review routing")

The verdict means the reviewer could not confirm an acceptance criterion because a required constraint was neither in the dispatch packet nor reachable by its own exploration. The code isn't known-wrong; the reviewer merely couldn't confirm it, so re-running the writer would be wrong. The path does not count against the 2-FAIL cap, which counts `.fail` records only.

## N10: why a `.directed` marker can be dispatched at once (from "Review routing")

`.claude/reviewed/<task-id>.directed` has no `stop-gate.sh` branch, so the pending-review flags clear normally and the human's prescribed fix can actually be dispatched. A rejection-with-reason counts against the 2-FAIL cap; a human-directed correction does not.

## N11: why the no-reviewer case must be said every time (from "Review routing")

The Writer/Reviewer split is this system's core safety property. Silently degrading it without saying so would be worse than not having it, so the orchestrator's own sanity check is announced in every report where it applies.

## N12: reviewer tier selection, why from the repo root and why downgrade-only (from "Reviewer gate model selection")

No planning persona tags a reviewer tier: the plan exists before the diff does, so the tier is measured at reviewer-dispatch time. Running from the repo root matters: the script's sensitive-path patterns are anchored there, and it resolves the reviewed-marker directory under `CLAUDE_PROJECT_DIR` (default: cwd). It is fail-closed: anything unmeasurable, sensitive, or oversized prints `opus`. The script is a necessary condition, never a sufficient one; the one-way rule (judgment may move `sonnet` to `opus`, never back) is what keeps a measured tier from being a weakening of the gate. The tier line comes from the `--implementer-tier` flag alone, never from a stored value, so it cannot be stale.

## N13: why effort is a frontmatter decision (from "Effort-tier policy")

Effort is not settable per dispatch: the `Agent` tool's schema exposes only `description`, `prompt`, `subagent_type`, `model`, and `isolation`, so unlike `model` there is no dispatch-time effort knob. The one-way raise-only rule runs in the same direction as the `sonnet` → `opus` reviewer-model escalation, not the inverted "toward cheaper" reading a brief might suggest. Personas that declare no `effort:` key (e.g. `milestone-auditor`) are undeclared by design, not an oversight to fix.

## N14: why the orchestrator relays spec-master's questions (from "Relaying spec-master open questions")

spec-master returns "Open Questions" when a request needs interrogation it cannot do mid-subagent-run. Subagents can never use `AskUserQuestion`; the orchestrator can, because it runs as the main session.

## N15: graph freshness is a backstop (from "Graph freshness (backstop duty)")

The `PostToolUse` hook and the pre-commit hook are the primary, automatic updaters and keep the graph fresh on every file change. The orchestrator's duty only triggers on the explorer's own grep-fallback report (`agents/explorer.md`, fallback behavior), because a stale graph silently corrupts the explorer's blast-radius answers, which the reviewer depends on.

## N16: background and nested dispatch observations (from "Managing a long-running background dispatch")

`TaskStop` is graceful and may not stop a wedged task immediately. A subagent's own nested background `Bash` job has no self-resume and stays dormant at `SubagentStop` regardless of what it claimed. `ps` is valid only when dispatcher and subagent share a process namespace, which `isolation: "worktree"`/`"remote"` does not guarantee. A nested dispatch's `task-notification` can surface directly to the orchestrator carrying a task-id it never dispatched; check for a correlating signal (an intermediate persona's `idle_notification` naming it) before treating it as suspicious. `TaskOutput` does not reliably resolve a grandchild's task-id or a named top-level dispatch (both return "No task found"). Repeatedly resuming an intermediate persona to ask "are you done yet", or `TaskStop`-ing it and redispatching a fresh `-2`/`-3` sibling, is the passive-waiting failure mode: each resume costs a full turn and cannot detect completion any faster than waiting. A content-free `idle_notification` after a resume usually means "still working". Internal agentIds are never surfaced in a user-facing reply, so never ask an intermediate persona to paste one.

## N17: why Plan Mode must be exited (from "If Plan Mode is active")

The harness's built-in Plan Mode spawns the generic `Explore`/`Plan` subagent types. Its instructions are more specific and more recent than the routing table, so left unchecked they win and silently bypass the routing table, the Writer/Reviewer split, and the milestone gate for the whole turn.

## N18: why a missing STATUS line is treated as a cutoff (from "Delegation contract")

The harness gives no other signal: a cut-off turn's result is indistinguishable from a completed one's. Checking verifiable repo state first is cheaper than a resume and can confirm completion without one. Re-`Agent`-ing a persona to resume it spawns an unrelated sibling with no shared state, which is why resumption goes through `SendMessage` by name.

## N19: dispatch `model` precedence was measured (from "Per-unit model routing")

An explicit dispatch `model` and a persona's frontmatter `model:` take precedence over `CLAUDE_CODE_SUBAGENT_MODEL` (measured on CLI 2.1.302, A/B pilot 4). A fix contract is never scored for the tier because it can score back onto `haiku`. A fresh session gets the same ladder, provided it is unchanged; `ladder-tier.sh` holds the arithmetic.

## N20: why small-lane units skip the reviewer (from "Lane routing")

User decision, 2026-11-01: the reviewer runs on medium and full units only. In the 2026-10-31 A/B, Arm B's reviewer ran 43 times and returned PASS 43 of 43; it cost $46.6, 37% of Arm B spend (about $1.08 and 88 s per dispatch), and changed no outcome. Its findings elsewhere were real (41 of 41 sampled defects), so it stays where the risk is. `unit-bookkeeping.sh check` replaces it on a small unit: a mechanical, fail-closed run of `review-precheck.sh` that prints `pass` only on positive evidence and writes no marker. The exemption is limited to subagent-orchestrator mode because in agent-teams mode `task-gate.sh` refuses to complete an `impl:` task without a valid `.pass`, which only the reviewer writes. A lane lift must be followed by a fresh `Agent` dispatch because `dispatch-hygiene.sh` writes the dispatch-lane record only at an `Agent` dispatch; a `SendMessage` resume keeps the old `small` record, so the stop gate would write no pending-review flag for the fix. After a lift, the writer dispatch is a fresh `Agent` call so its dispatch-lane record has the new lane. Plan: `docs/plans/2026-11-01-reviewer-by-lane.md`.
