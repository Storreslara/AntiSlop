# ADR 0018: Human-in-the-loop review enabled by default

Date: 2026-08-11
Status: Accepted (plan 2026-07-28-microworlds-ubiquitous-language-human-review, Step 8b)

## Context

AntiSlop's core mission is to slow down hyperscaling-by-default. Unchecked full automation produces slop, and agent-teams mode is precisely the full-autonomy gear where that risk concentrates. Human escalation exists to put friction back into the loop intentionally.

The question is not *whether* to offer human-in-the-loop escalation — that capability is the whole point of the third coupled ask in the microworlds plan — but *when* it fires by default.

## Decision

**`humanReviewMode` defaults to `critical`, not `off`.** This is an opt-out, not an opt-in. Units meeting the heavy-unit trigger (see [ADR 0004](0004-reviewer-roast-work-dual-model-routing.md) § "Heavy unit trigger", as amended by [ADR 0013](0013-fable-removed-from-roast-work-advisory-pass.md) — not restated here, see "Related decisions" below) will now block turn-end until a human decides, on every already-adapted project on its next plugin update, without any edit to the project's config.

This is a **deliberate, informed behaviour change**. Setting `"humanReviewMode": "off"` in `.claude/persona-config.json` restores the previous behaviour (fully automatic PASSing).

## Rationale

### Why on-by-default, not off-by-default

**Off-by-default (opt-in) was rejected because:**
- It trades friction for convenience. Projects that skip the config step get the old "always auto-pass" behaviour by accident.
- It inverts the risk surface: projects that *should* have human review but don't know to opt in silently remain unreviewed.
- It is the single most likely way to ship "on by default" that is actually off for every existing user — an encoding trap the spec explicitly avoids (R1, "on by default" that is silently off).

**On-by-default (opt-out) was chosen because:**
- It makes the default protective. A project that forgets to opt out gets the conservative posture.
- It is explicit and honest: the CHANGELOG and README state plainly that the default is on, and that opt-out requires an edit.
- It closes the R1 gap: a consumer-side absent-key fallback in the reviewer (not a backfill in `bin/cli.js --update`) means the default lands immediately without rewrites of existing config.

### Cost: a real behaviour change for every already-adapted project

This is not an oversight and not something to soften in release notes. Projects that were previously auto-PASSing heavy units will now have those units block turn-end until a human resolves them. That is the tradeoff:

**Gained:** Units touching security-sensitive code, or structural changes, or large diffs, no longer ship without a human reading them.

**Cost:** Workflow friction. Each escalated unit requires a human to run the microworld and decide: approve, reject with reason, or direct a specific fix.

This cost is accepted and intentional.

## Accepted limitations and alternatives

### Why not "all escalate" by default

The `humanReviewMode: "all"` setting exists and is useful for teams that want every single unit reviewed by a human. It was not chosen as the default because:
- It is too strict for most workflows.
- The heavy-unit trigger already identifies the highest-risk changes (security, structural, large diffs).
- Escalating *everything* converts the feature into a hard gate that defeats automation entirely, rather than a friction point on high-risk work.

The default `critical` mode balances human oversight with automation: small, mechanical units still auto-PASS; high-risk units wait for a human.

### Why this repo ran "off" during the fix batch (bootstrap window, now closed)

This repo's own `.claude/persona-config.json` temporarily held `humanReviewMode: "off"` during a **bootstrap window** (documented in `docs/plans/2026-08-11-human-decision-channel.md` Step 4) while the human-decision resolution channel — the mechanism that *routes* escalations to humans — was still being built. With escalation on, the fix batch's own heavy-unit changes (hook code, security-sensitive) would have escalated into a route that did not yet exist. The decision channel landed at unit #136 (issue #324); this repo's own config now runs at the default `humanReviewMode: "critical"`, the same as any other adapted project.

### Update 2026-08-16 — this repo now runs the documented opt-out locally (solo-operator posture)

**This annotation does not reverse this ADR's decision.** The shipped
default for every other adapted project remains `humanReviewMode: "critical"`
(on-by-default), unchanged.

Separately from the bootstrap window described above (which closed at unit
#136 and reverted this repo's config to `critical`), this repo's own
`.claude/persona-config.json` now runs `humanReviewMode: "off"` again — this
time as a **permanent, deliberate local posture** for a single, unsupervised
developer, not a temporary workaround held open for a landing mechanism. It
was set by Step 1 of `docs/plans/2026-08-15-ceremony-reduction-solo-operator.md`
(Open Question 1, resolved 2026-08-15: local posture only — the alternative
of changing the shipped default, which would have required reversing this
ADR, was explicitly declined). Risk R1 — heavy units ship on reviewer PASS
with no forced human comprehension pause — is accepted knowingly, per this
ADR's own "Opt-out is real and easy" consequence below. See
[ADR-0024](0024-ceremony-reduction-solo-operator.md) and `CONTEXT.md`'s
"solo-operator posture" glossary entry.

## Consequences

- **Immediate impact:** From this version onward, every already-adapted project with critical-weight units will experience escalation by default, without configuration changes.
- **Documentation is mandatory:** The feature and its default must be stated clearly in README and CHANGELOG, not softened or hidden.
- **Opt-out is real and easy:** Setting `"humanReviewMode": "off"` in `.claude/persona-config.json` silently disables the feature entirely, restoring the old behaviour.
- **New projects inherit on-by-default:** Fresh installs receive `humanReviewMode: "critical"` in their skeleton config.
- **Existing projects are preserved by default:** `bin/cli.js --update` does NOT add the field to existing configs (per R1 hazard avoidance), so the absent-key fallback in the reviewer is the mechanism that delivers the default.

## Related decisions

- **ADR 0004 "Heavy unit trigger":** The three criteria (file count, line count, security-sensitive surface) that identify when a unit escalates under `critical` mode. That ADR is the source of truth; this ADR does not restate the criteria.
- **R1 risk (unit #135, Step 6):** The encoding trap where a backfill-only default would have been silently off for every existing user. Closed by placing the default in the consumer's absent-key fallback, not in the `--update` path.
