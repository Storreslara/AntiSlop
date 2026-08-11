# ADR 0007: Human-in-the-loop review enabled by default

Date: 2026-07-28
Status: Accepted (plan 2026-07-28-microworlds-ubiquitous-language-human-review, Step 8b)

## Context

AntiSlop's core mission is to slow down hyperscaling-by-default. Unchecked full automation produces slop, and agent-teams mode is precisely the full-autonomy gear where that risk concentrates. Human escalation exists to put friction back into the loop intentionally.

The question is not *whether* to offer human-in-the-loop escalation — that capability is the whole point of the third coupled ask in the microworlds plan — but *when* it fires by default.

## Decision

**`humanReviewMode` defaults to `critical`, not `off`.** This is an opt-out, not an opt-in. Units meeting the heavy-unit trigger (≥8 impacted files OR ≥400 changed lines; structural/cross-cutting change; or security-sensitive surface) will now block turn-end until a human decides, on every already-adapted project on its next plugin update, without any edit to the project's config.

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

### Why not "off" for this repo during the fix batch

This repo's own `.claude/persona-config.json` deliberately keeps `humanReviewMode: "off"` during a temporary **bootstrap window** (documented in `docs/plans/2026-08-11-human-decision-channel.md` Step 4). The human-decision resolution channel (the mechanism that *routes* escalations to humans) hasn't fully landed yet — with escalation on, this fix batch's own heavy-unit changes (hook code, security-sensitive) would escalate into a route that does not exist. Once the decision channel lands fully, this repo's own config will restore `humanReviewMode: "critical"`.

## Consequences

- **Immediate impact:** From this version onward, every already-adapted project with critical-weight units will experience escalation by default, without configuration changes.
- **Documentation is mandatory:** The feature and its default must be stated clearly in README and CHANGELOG, not softened or hidden.
- **Opt-out is real and easy:** Setting `"humanReviewMode": "off"` in `.claude/persona-config.json` silently disables the feature entirely, restoring the old behaviour.
- **New projects inherit on-by-default:** Fresh installs receive `humanReviewMode: "critical"` in their skeleton config.
- **Existing projects are preserved by default:** `bin/cli.js --update` does NOT add the field to existing configs (per R1 hazard avoidance), so the absent-key fallback in the reviewer is the mechanism that delivers the default.

## Related decisions

- **ADR 0004 "Heavy unit trigger":** The three criteria (file count, line count, security-sensitive surface) that identify when a unit escalates under `critical` mode. That ADR is the source of truth; this ADR does not restate the criteria.
- **R1 risk (unit #135, Step 6):** The encoding trap where a backfill-only default would have been silently off for every existing user. Closed by placing the default in the consumer's absent-key fallback, not in the `--update` path.
