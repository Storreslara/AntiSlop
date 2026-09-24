---
name: cost-governance-spec
description: Settled decisions for issue #476 (Bash output cap + per-persona effort tiers) — LOCKED 2026-09-23 with 0 open questions; the measured transcript baseline, the four premise corrections, why no hook script lands, and the frontmatter version-floor defect class.
metadata:
  type: project
---

Issue **#476**, plan doc
`docs/plans/2026-09-23-cost-governance-output-cap-and-effort-tiers.md`.
Finalized 2026-09-23 from an ad-hoc researcher brief (not tracker-filed).
Mechanism-level facts live in
[[claude-code-hook-and-effort-primitives]]; this file is the *decisions*.

## Settled

- **No new hook script.** So `docs/trust-model.md` gains no row and
  `tests/trust-model-bijection.test.js`'s `EXPECTED_SELF_REPORTED_COUNT` stays
  **10**. The brief anticipated both obligations; investigation removed them.
- **Goal 1 = set the cap that already exists**, not build a truncating hook.
  `bashOutputMaxChars: 12000` recommended, chosen as *just above the measured
  p99*. Three-part delivery: fragment key + `runUpdate` backfill + protocol
  amendment telling agents to re-query narrowly rather than `Read` the
  persisted overflow file whole.
- **Goal 2 = a new `effort:` frontmatter field**, not an `orchestrator.md`-only
  doc change — because no per-dispatch effort parameter exists. Tiers:
  `explorer: low`, `task-master: medium`, `reviewer: high` (**a floor**),
  `milestone-auditor` undeclared.
- **A per-Bash-call audit hook was considered and dropped**: it would add a
  second hook to a hot path that already fires `harness-integrity-gate.sh` on
  every Bash call, to produce a number the transcript store already yields
  offline and retrospectively.

## Measured baseline (re-derivable, will drift)

521 transcript files under `~/.claude/projects/-home-sebas-AntiSlop/`,
**14,641 Bash tool results, 20,156,531 chars (~5.0M tokens)** that entered
agent context. p50 **586**, p90 3,457, p95 5,329, p99 **11,277**, max
**29,457**.

| cap | % of calls over | % of output deferred |
|---|---|---|
| 4,000 | 8.14% | 20.0% |
| 8,000 | 2.32% | 7.2% |
| 12,000 | 0.85% | 3.0% |
| 30,000 (default) | 0.00% | 0.0% |

**The platform default has never bound** — no recorded result exceeds 30,000.
Caveat: this measures chars that *entered context* (already post-cap), so it
understates raw output for calls that were already truncated. Right metric for
sizing a cap, wrong one for estimating command verbosity. Per
[[baselines-expire]], re-run before reusing these figures.

## Four premise corrections the brief got wrong

1. "Relies entirely on an instruction" — **false**, `bashOutputMaxChars`
   already caps mechanically at 30,000.
2. `PostToolUse` output rewriting — **impossible**, no substitution field.
3. `PreToolUse` `updatedInput` — **possible but rejected**; appending a pipe
   masks exit status and the review gate is built on exit codes.
4. "Judgment can lower a tier but never raise one past a floor" — **inverted**;
   this repo's "downgrade" means `sonnet` → `opus`, toward MORE capability.

## Escalated → all three ANSWERED 2026-09-23 (spec LOCKED, 0 open questions)

Each answer matched my own recommended default. Do not reopen:

1. **Cap value = 12,000.** Rejected 8,000 / 4,000 / leave-unset.
2. **`milestone-auditor`: leave undeclared, do not lower.** Upholds the spec's
   dissent from the brief. Now pinned by a test asserting the key is *absent* —
   a decision *not* to do something needs a positive assertion or it is
   unenforceable and a later "complete the table" edit undoes it.
3. **`runUpdate` settings backfill = acceptable** Set-B trust-surface
   expansion. So the backfill is *mandatory*, not conditional.

## Version-floor defect class (learned from the sibling's FAIL)

A frontmatter key has its own Claude Code introduction version, and
`.claude-plugin/plugin.json`'s description states the declared floor. The
sibling `cache-ttl-gapped-personas` FAILed partly on exactly this (declared
`>=2.1.178`, feature needed `>=2.1.248`). **Any spec adding a frontmatter key
must carry a floor criterion.** Two traps:

- The floor is stated in **six** disagreeing places: `README.md`,
  `.claude-plugin/plugin.json`, `skills/install-antislop/SKILL.md` + its
  `.claude/` mirror, `commands/start-feature-team.md`, and
  `templates/settings-fragment.json`'s `_comment`. Only the first two read
  `2.1.248`; the rest still say `2.1.178`.
- You cannot bisect an introduction version locally — only ~4 recent versions
  live under `~/.local/share/claude/versions/`. Report that honestly rather
  than asserting an unchecked number.

## Sequencing (re-confirmed 2026-09-23 — premise moved, conclusion did not)

Steps 3/4/5 collide with the `cache-ttl-gapped-personas` sibling (19 files: 2
source agents, 10 mirrors, persona-config, 2 protocol files, digest, CHANGELOG,
both version files). Step 4 collides at **hunk** level — the sibling adds
`experimental:`/`cacheTtl` within a line of where `effort:` goes.

History: first attempt **committed** as `66b9666` (0.31.74 → 0.31.75), then
**FAILed** (top-level `cacheTtl` is silently discarded; the strict agent schema
accepts it only under `experimental:`), fix in flight at 0.31.76, no PASS
marker yet. **Never hardcode a target version into a dispatch prompt** — this
baseline moved twice in one day. Version-stamped steps order
**bump → CHANGELOG → `--update`** per
[[protocol-amendments-do-not-propagate]]; see also [[baselines-expire]].
