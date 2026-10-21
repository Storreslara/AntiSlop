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
