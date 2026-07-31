# ADR 0008: Agent-identity normalization contract — GATE/GRANT asymmetry

**Date**: 2026-07-30  
**Status**: Accepted  
**Context**: Normalization of agent identities in the review-gating hook layer to handle both bare and namespaced dispatch forms (plan #139, issue #150)

## Problem

When a persona is dispatched with a namespace prefix (`antislop:reviewer`), the `agent_type` field in hook payloads carries that prefix verbatim as an agent identity. The gate-layer scripts then perform exact string equality comparisons against **bare** persona names (`reviewer`), so every namespaced dispatch silently misses the matching logic — a live authorization defect.

The naive fix — strip any syntactically valid namespace everywhere — is **dangerous at privilege-grant sites** (writing PASS markers, clearing review flags). A foreign namespace like `otherplugin:reviewer` should not inherit authority to write to `.claude/reviewed/` or clear review flags for this project. Yet the same liberal approach must be used at **gate sites** (flag-creation checks), where a miss currently fails open and under-matching is the bug to avoid.

## Solution

Implement **asymmetric matching**: two distinct matcher functions in `hooks/scripts/lib/agent-identity.sh`, each failing in its appropriate direction.

- **`persona_matches_gate` — LIBERAL matcher** (lines 85–90)
  Used at GATE sites where a miss fails open and under-matching is the defect:
  - Extracts the persona-name suffix from both identities (bare form unchanged; `otherplugin:reviewer` → `reviewer`)
  - Compares suffixes only
  - Applied at 9 GATE sites: S2, S4–S6, S8, S9, S11, S12, S13 (see deployment table below)

- **`persona_matches_grant` — CONSERVATIVE matcher** (lines 92–105)
  Used at GRANT sites where a miss fails closed but over-matching hands authority to a foreign namespace:
  - Accepts only exact match (`candidate = want`) OR
  - Namespaced match with a recognized namespace (`namespace(candidate) == identity_recognized_namespace() AND persona_name(candidate) = want`)
  - The `<expected>` arg (the `want` parameter) MUST always be a bare script literal — no namespace is ever expected in the want side
  - Applied at 4 GRANT sites: S1, S3, S7, S10 (see deployment table below)

The recognized namespace is derived from the plugin's own on-disk location by `identity_recognized_namespace()` — reading `.name` from the first readable of `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.codex-plugin/plugin.json`, with a fallback to `antislop`.

## Asymmetry rationale

This asymmetry is **deliberate and load-bearing**, not an inconsistency to be cleaned up:

### GATE sites (liberal matching)

- **Miss direction**: A false negative (failing to match a valid dispatch) leaves the gate open — the check fails to create a flag or fails to block, and the wrong caller gets through.
- **Cost of over-matching**: An extra gate check fires, which is advisory and recoverable.
- **Worst case**: Over-matching a foreign namespace means one harmless extra flag check. Under-matching a namespaced dispatch means an authorization boundary is not checked at all.
- **Decision**: Liberal matching minimizes the defect (false negatives).

### GRANT sites (conservative matching)

- **Miss direction**: A false negative (failing to reject a foreign namespace) hands authority to a different plugin's persona — they can write to `.claude/reviewed/` or clear our review flags.
- **Cost of rejecting it**: The flag is NOT cleared or the marker is NOT written, which is loud and recoverable via the clear-all-flags escape hatch or the `defer:` / `skip:` escape.
- **Worst case**: Conservative matching makes foreign namespaces fail closed and visible. Liberal matching at these sites would let any `otherplugin:reviewer` write PASS markers.
- **Decision**: Conservative matching prioritizes the genuinely protected boundary (PASS-marker authority).

## Deployment table

The assignment below is normative and does not re-derive — task-master must dispatch all sites atomically (see Risk R1 of the plan). Note: Site S13 (dispatch-hygiene.sh:148) was added post-spec in v0.15.0 and is included here for completeness:

| Site | File:line | Decision | Matcher | Miss direction |
|---|---|---|---|---|
| S1 | `hooks/scripts/reviewed-path-gate.sh:52` | may caller write PASS markers | **GRANT** | fails CLOSED |
| S2 | `hooks/scripts/reviewed-path-gate.sh:60` | `personaSelection` contains `reviewer` | GATE | fails OPEN |
| S3 | `hooks/scripts/stop-gate.sh:106` | reviewer stop clears pending flags | **GRANT** | fails CLOSED |
| S4 | `hooks/scripts/stop-gate.sh:170` | is this agent gated (flag creation or main agent) | GATE | fails OPEN |
| S5 | `hooks/scripts/reviewer-route-gate.sh:40,41` | lead-programmer may not spawn reviewer | GATE | fails OPEN |
| S6 | `hooks/scripts/reviewer-route-gate.sh:56` | block next gated dispatch | GATE | fails OPEN |
| S7 | `adapters/cursor/hooks/scripts/stop-gate.sh:61` | reviewer stop clears flags | **GRANT** | fails CLOSED |
| S8 | `adapters/cursor/hooks/scripts/stop-gate.sh:125` | is this agent gated | GATE | fails OPEN |
| S9 | `adapters/cursor/hooks/scripts/reviewer-route-gate.sh:49` | block next gated dispatch | GATE | fails OPEN |
| S10 | `adapters/codex/hooks/scripts/stop-gate.sh:101` | reviewer stop clears flags | **GRANT** | fails CLOSED |
| S11 | `adapters/codex/hooks/scripts/stop-gate.sh:167` | is this agent gated | GATE | fails OPEN |
| S12 | `adapters/codex/hooks/scripts/reviewer-route-gate.sh:51` | block next gated dispatch | GATE | fails OPEN |
| S13 | `hooks/scripts/dispatch-hygiene.sh:148` | H3 gatedAgents check (re-dispatch gate) | GATE | fails OPEN |

**GRANT sites (4 total)**: S1, S3, S7, S10  
**GATE sites (9 total)**: S2, S4–S6, S8, S9, S11, S12, S13

## Open Question 1: Should flag-clearing sites be liberal too?

**Status: OPEN, with option (a) as the implemented default**

Conservative matching at S3/S7/S10 reintroduces a residual deadlock: an identity in an *unrecognized* namespace (e.g., `otherplugin:lead-programmer`) creates a pending-review flag that the same namespace's reviewer (`otherplugin:reviewer`) cannot clear, because `persona_matches_grant` rejects the foreign namespace on the flag-clearing path.

### Option (a) — Keep conservative at S3/S7/S10 (recommended, **implemented**):

- **Honors the stated policy**: Clearing a review flag is a privilege that should only be granted to *this* project's reviewer.
- **Residual deadlock is bounded**:
  - `stop-gate.sh:115` clears **all** `.pending-review.*` flags when any recognized reviewer runs, recovering the state.
  - The `defer:` / `skip:` escape hatch remains available.
  - Step 2/5 add a stderr note naming the recovery option plus an audit line logging the unrecognized namespace.
- **Worst case**: A project whose *only* reviewer is foreign-namespaced (or a Cursor/Codex install whose namespace differs from the manifest name) deadlocks until a human reads the error message and uses the escape hatch.

### Option (b) — Make S3/S7/S10 liberal too:

- **Eliminates the deadlock class entirely**, since both creation and clearing would accept foreign namespaces.
- **The supporting argument is stronger than it first looks**:
  - The pending-review flags are **not** a protected resource — `reviewed-path-gate.sh` guards only `.claude/reviewed/`, and `stop-gate.sh:86-87` explicitly concedes that `rm -f .claude/.pending-review.*` via Bash "remains possible; `.claude/review-audit.log` is the deterrent, not a guarantee."
  - A conservative matcher at S3 therefore defends a boundary the codebase already documents as undefended.
  - The *genuinely* protected boundary (S1, the PASS-marker directory) stays conservative either way.
- **Recommended against** only because it overrides an explicit policy decision — but if the deadlock in (a) is judged worse than the theoretical grant, (b) is the coherent choice.

### Option (c) — Widen "recognized namespace" to a set:

Recommended against: re-introduces exactly the failure mode being fixed — an unanticipated identity form silently missing a hard-coded set — and adds per-hook config-reading cost.

**If Open Question 1 is resolved to option (b), sites S3, S7, and S10 flip to GATE (liberal) together and nothing else changes.**

## Implications

- The asymmetry is a **deliberate policy, not an implementation detail**. Any future maintainer attempting to unify the matchers should read this ADR and option (b) before concluding it's redundant.
- Per-site matcher assignment (the deployment table) is normative and part of the acceptance criteria — changes to it require amending this ADR or escalating to spec-master, not just editing the scripts.
- Both matchers respect empty `agent_type` unchanged — a bare identity and an empty `agent_type` both pass through without conversion or error (per the plan's "empty input contract").

## References

- **Plan**: `docs/plans/2026-07-28-agent-identity-namespace-gate-fix.md` — full context, rationale, risks, and acceptance criteria
- **Probe lesson**: `.claude/wiki/probe-methodology.md` — how this defect was discovered: a probe that checked presence but not value space
- **Library implementation**: `hooks/scripts/lib/agent-identity.sh` (header comment lines 6–21 restate this contract)
- **Concrete usage**: `hooks/scripts/reviewed-path-gate.sh` lines 52 (GRANT) and 60 (GATE) show both matchers in one script
