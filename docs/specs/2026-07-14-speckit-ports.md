# Spec-kit ports: constitution, clarification taxonomy, plan self-check, convergence check

Status: spec only — nothing below is implemented. Written against plugin
v0.8.0. All four features are plugin-source edits (plus one new
per-project file), so shipping them means: edit the files named below, bump
the plugin version (MINOR) in `.claude-plugin/plugin.json`, and let adapted
projects pick the changes up through the existing `bin/cli.js --update`
resync — every touched agent file is already hash-tracked in
`persona-config.json`'s `fileHashes`, so the resync stays deterministic.

## Why this exists

A comparison pass against GitHub's spec-kit (Spec-Driven Development
toolkit) found four techniques worth porting: a project constitution,
a fixed ambiguity taxonomy for clarification, a requirements-quality
self-check before implementation starts, and an explicit spec-vs-reality
convergence check after it ends. Each fills a gap AntiSlop's current flow
has (detailed per feature below); each is adapted to AntiSlop's idiom —
prose instructions in existing persona files, conditional "if present"
wiring, human-terminated findings — rather than ported as new commands or
personas. Spec-kit is the source of the ideas, not the justification;
each feature's own gap is.

## Feature 1 — Project constitution (`.claude/constitution.md`)

**Gap.** `.claude/persona-config.json` holds mechanical config (commands,
protected paths); the `coding-discipline` skill holds universal LLM
pitfalls. Nothing captures *project-specific principles* (e.g. "test-first,
no exceptions", "no new dependencies without an ADR", "prefer boring
stdlib solutions") that plans and reviews get checked against.

**What changes.** A new, opt-in, per-project file at
`.claude/constitution.md`, created during `install-antislop`. It is
project-authored content, NOT a plugin template copy: no version-stamp
comment, no `fileHashes` entry, never touched by `bin/cli.js --update`,
no `persona-config.json` schema change. Presence on disk is the only
switch — every persona reference below is conditional ("if
`.claude/constitution.md` exists"), matching the existing "if present,
otherwise fallback" idiom that lets a plain copy degrade gracefully.

File format (the setup skill writes this shape; headings under
`## Principles` are whatever fits the project — the spec-kit defaults are
examples to offer, not a fixed list):

```
# Project constitution
Version: 1.0.0 | Ratified: YYYY-MM-DD | Last amended: YYYY-MM-DD

## Principles
### 1. <Short name> (MUST | SHOULD)
<1-3 sentences: the rule and why this project holds it.>

## Amendment log
- 1.0.0 (YYYY-MM-DD): ratified.
```

**Versioning** (deliberately lighter than spec-kit's — no auto-editing of
persona files, no template propagation): semver bumped by whoever edits the
file. MAJOR = a principle removed or redefined incompatibly; MINOR = a
principle added or materially expanded; PATCH = wording/typo clarification.
Every amendment appends one Amendment-log line ending with a short
"worth a look:" list — files a human might want to re-check against the
new text (typically: open plans in `docs/plans/` not yet fully executed,
and in-flight tracker issues). That list is surfaced to the human in the
editing agent's report; nothing acts on it automatically.

**Files touched/created:**
- `skills/install-antislop/SKILL.md` — new section **6.5 "Project
  constitution (opt-in)"** between steps 6 and 7 (a new subsection avoids
  renumbering 7-12). Contents: ask via AskUserQuestion whether the project
  wants a constitution (skipping is a plain "no", unlike the reviewer's
  typed confirmation — this is additive, not a safety property). If yes:
  elicit 3-7 principles from the user, seeding suggestions from an actual
  repo scan (existing test setup, docs, dependency posture), not from a
  canned list; write the file at Version 1.0.0; then ask whether to add
  `.claude/constitution.md` to `protectedPaths` in
  `persona-config.json` (recommended — it makes constitution edits require
  explicit human approval via the existing protected-paths hook, no new
  hook needed). Step 12's report states "constitution created (vX)" or
  "constitution skipped".
- `agents/hivemind.md` — one new bullet: if `.claude/constitution.md`
  exists, read it before drafting; the plan output format (see its
  existing "Plan output format" bullet) gains a **Constitution check**
  line after Risks — for each MUST principle, either "satisfied" or a
  named **deviation** with justification; an unjustifiable deviation goes
  to Open Questions instead. Silently violating a principle is a plan
  defect, same standing as a step with no runnable check.
- `agents/reviewer.md` — one new bullet amending the materiality filter:
  if `.claude/constitution.md` exists, a diff that violates a MUST
  principle *with no recorded deviation in the plan* is a FAIL reason,
  cited as `constitution vX.Y.Z / <principle name>`; SHOULD violations
  and plan-recorded deviations go in the non-blocking notes list, never
  the verdict.
- `agents/milestone-auditor.md` — one clause added to the existing
  premise-grilling bullet: constitution principles count as plan premises;
  findings that rest on one cite it the same `constitution vX.Y.Z /
  <name>` way.
- `README.md` — add `.claude/constitution.md` to the "Removing AntiSlop"
  list and one row/mention in the "What ships vs. what setup writes"
  table (per-project column).

**Existing adapted projects:** `--update` will refresh their agent files
(which now carry the conditional references) but never creates the
constitution itself; they opt in by writing `.claude/constitution.md` by
hand in the format above. One line saying exactly that goes in the
CHANGELOG/release note for the version bump.

**Acceptance criteria:**
- `grep -c 'constitution' agents/hivemind.md agents/reviewer.md agents/milestone-auditor.md` — each ≥ 1, and every match sits in a sentence conditioned on the file existing.
- `grep -n '6.5' skills/install-antislop/SKILL.md` matches a "Project constitution" section header; the section contains an AskUserQuestion instruction and the `protectedPaths` offer.
- `grep -q 'constitution' README.md` — both the removal list and the ships-vs-setup table mention it.
- No change to `templates/persona-config.schema.json`; `grep -q constitution templates/persona-config.schema.json` finds nothing.
- The v1.0.0 file shape above appears verbatim (as a template block) in SKILL.md section 6.5.

## Feature 2 — Clarification taxonomy folded into hivemind's grill step

**Gap.** hivemind's grill-me pass is open-ended: coverage depends on what
the model thinks to ask. And answers obtained during grilling leave no
durable record in the plan — milestone-auditor later can't distinguish
"genuinely ambiguous, resolved with the user" from "the plan just missed
it".

**What changes.** A fixed 9-category ambiguity scorecard hivemind runs
*before* grill-me (grill-me is an external mattpocock skill AntiSlop
doesn't own — this is a coverage/audit layer on top, never a
replacement), plus a durable dated **## Clarifications** section in the
plan output. The categories, one terse line each, inline in
`agents/hivemind.md` (it's fully loaded per spawn; 9 lines is the budget —
do not paste spec-kit's prose):

1. Functional scope & success criteria
2. Domain entities / data model
3. User interaction flow
4. Non-functional attributes (perf, security, scale)
5. External dependencies & integrations
6. Edge cases / failure handling
7. Technical constraints & tradeoffs
8. Terminology consistency
9. Completion / acceptance signals

**Mechanics** (all in `agents/hivemind.md`, extending the existing
"Grill before planning" bullet — not a new bullet cluster):
- Before invoking grill-me, mark each category **Clear / Partial /
  Missing** against the request plus exploration done so far. Carry the
  Partial/Missing ones into the grill session as coverage targets.
- At most **5 questions total** may go to the user, prioritized by
  impact × uncertainty. Each question carries a **recommended default**
  and, where the answer space is discrete, multiple-choice options. This
  maps onto the existing one-shot-subagent constraint unchanged: the
  questions ARE the plan's Open Questions section; the orchestrator's
  existing AskUserQuestion relay (orchestrator.md "Relaying hivemind open
  questions") already turns discrete options into structured questions —
  the recommended default becomes the first-listed option. No
  orchestrator.md change required for this feature.
- Plan output format gains **Clarifications** (between Context and
  Risks): the 9-line scorecard, then one dated line per resolved Q&A —
  `- YYYY-MM-DD <category>: Q <question> → A <answer>` — appended
  incrementally, including when hivemind is re-delegated with the user's
  answers after an Open Questions round-trip (record the answer into
  Clarifications, don't just consume it).
- `agents/milestone-auditor.md` — one clause: read the plan's
  Clarifications section when grilling assumptions; a premise that was
  never scored or asked despite a Missing category mark is a finding in
  itself ("plan missed it"), distinct from one the user explicitly
  resolved.

**Files touched:** `agents/hivemind.md`, `agents/milestone-auditor.md`.

**Acceptance criteria:**
- All 9 category names appear in `agents/hivemind.md`; `grep -c` for each is ≥ 1.
- `grep -q 'Clear / Partial / Missing' agents/hivemind.md` and `grep -qi 'at most 5' agents/hivemind.md` (or equivalent exact phrasing) succeed.
- hivemind.md's "Plan output format" bullet lists `Clarifications` between Context and Risks.
- The dated line format (`YYYY-MM-DD`, category, Q→A) is specified verbatim in hivemind.md.
- `grep -qi 'clarifications' agents/milestone-auditor.md` succeeds and the sentence distinguishes resolved-vs-missed.
- grill-me remains invoked; no text removes or replaces the `<MATTPOCOCK:grill-me>` skill reference.

## Feature 3 — Requirements-quality self-check before slicing to issues

**Gap.** The first quality gate a plan meets today is human approval; the
first *adversarial* one is milestone-auditor — which fires only after every
unit has already reviewer-PASSed, i.e. after code exists. Nothing checks
the plan's own requirements quality before implementation starts.

**What changes.** A final drafting step in `agents/hivemind.md`, run on
its OWN plan after drafting and before returning it for approval (and
therefore before any `to-issues` slicing): a short checklist of "unit
tests for the spec". Items interrogate the *writing*, not the future
system — phrased "Is X defined for scenario Y?", "Do steps N and M agree
about Z?", never "does X work?". Sources for items: each numbered step's
acceptance criteria, the feature-2 scorecard's Partial/Missing categories,
and (if present) each constitution MUST principle.

**Pass/fail definition** (this goes in hivemind.md, terse): an item
**passes** only if the plan's own text answers it — no outside knowledge,
no charitable inference. An item **fails** in exactly three ways:
**missing** (the plan doesn't say), **conflicting** (two parts of the plan
say different things), or **ambiguous** (the plan says something with no
machine-checkable criterion behind it — the shared protocol's existing
"Machine-checkable criteria" rule, applied to the plan wholesale).

**On failure:** hivemind revises its own plan — it owns the plan and this
is pre-approval, so self-revision is in-role. **One revision pass, then
re-check the failed items only.** Anything still failing after that either
(a) needs information only the user has → convert it to an Open Question
(with a recommended default, per feature 2), or (b) reveals the request
itself is underspecified → return Open Questions as the primary output,
the existing escalation path. A plan is never handed off for approval with
a failed item that is not represented in Open Questions.

**Record:** plan output format gains a final **Self-check** section (after
Open Questions, before the Historian update hint): each item, its verdict,
and for failures the resolution taken (revised in place / converted to
Open Question). This lands in the saved `docs/plans/YYYY-MM-DD-<slug>.md`
where milestone-auditor can later read it.

**Files touched:** `agents/hivemind.md` only.

**Acceptance criteria:**
- hivemind.md contains a self-check bullet naming the three failure modes `missing`, `conflicting`, `ambiguous`.
- The phrasing rule ("Is X defined…", not "does X work") appears.
- The one-revision-pass cap and the failed-item → Open Question conversion are both stated.
- "Plan output format" lists `Self-check` after Open Questions.
- The self-check is ordered before `to-issues` in the file (the Handoff bullet still comes after it).
- No new persona file, no new command file, no skill file created.

## Feature 4 — Convergence check inside milestone-auditor

**Gap.** milestone-auditor already hunts goal drift ("scope trimmed
mid-plan"), which is judgment-based. What it lacks is the mechanical
half: a requirement-by-requirement diff of "what the plan said we'd
build" against "what the codebase actually contains". Today that
comparison happens implicitly, if at all.

**What changes.** An explicit, named **Convergence check** bullet in
`agents/milestone-auditor.md` — inside the existing audit pass, NOT a new
persona or command:
- Enumerate the requirement list from the plan itself: the Goal, each
  step's acceptance criteria, and each resolved Clarifications answer
  (feature 2) — a closed list, no invented requirements.
- For each, check the *actual* state via the tools it already holds:
  `Bash` against real artifacts, `explorer` for structural facts —
  never a closer reading of the plan's prose (its existing rule).
- Each unmet requirement becomes a finding tagged with a new, distinct
  category — **`unconverged-requirement`** — alongside the existing
  premise-gap and goal-drift findings, carrying: the requirement, its
  plan citation (step number / Clarifications line), the evidence of
  absence, and a severity. The existing materiality filter applies; "all
  requirements converged" is a valid complete result.
- **Append-only discipline stays with hivemind, not the auditor.** The
  auditor never appends tasks, never edits the plan, never routes
  anything — unchanged from today ("only a findings list relayed to the
  human"). Closing an accepted finding is a human decision relayed
  through the orchestrator.

Two one-line supporting edits:
- `agents/hivemind.md` — when re-invoked to close accepted
  `unconverged-requirement` findings, append new numbered steps under a
  dated **## Convergence follow-ups** heading in the existing plan doc —
  append-only, never rewriting or renumbering existing steps, never
  adding work beyond the named findings. Follow-up units flow through
  `to-issues` and the normal review pipeline like any other step.
- `agents/orchestrator.md` — in the "Milestone audit gate" section's
  findings-relay sentence, note that `unconverged-requirement` findings
  the human accepts route back to `hivemind` for append-only follow-ups
  (a re-plan-lite, distinct from the step-3 full re-plan on a challenged
  premise).

**Files touched:** `agents/milestone-auditor.md`, `agents/hivemind.md`,
`agents/orchestrator.md`.

**Acceptance criteria:**
- `grep -q 'unconverged-requirement' agents/milestone-auditor.md agents/hivemind.md agents/orchestrator.md` — hits in all three.
- milestone-auditor.md's convergence bullet names the closed requirement-source list (Goal, step acceptance criteria, Clarifications) and states the auditor never appends tasks.
- hivemind.md contains the `## Convergence follow-ups` heading convention and the words "append-only" (or an unambiguous equivalent).
- milestone-auditor.md still contains its "No PASS/FAIL verdict" and no-Write/Edit properties untouched — the diff adds bullets, it doesn't relax any existing constraint.

## Cross-cutting implementation notes

- **Token budget.** All four features together should add well under ~60
  lines across the persona files — v0.6.5 deliberately trimmed
  always-loaded prompt bloat; don't undo that. The 9-category list, the
  three failure modes, and the findings category are the irreducible
  content; everything else is a clause on an existing bullet.
- **Ship order** matches the numbering above: 1 is standalone; 2 feeds 3
  and 4 (both read the Clarifications section); 4's convergence list
  cites 2's output but degrades fine without it (falls back to Goal +
  acceptance criteria only — say so in the auditor bullet).
- **Version bump:** MINOR (behavioral additions, no breaking format
  change). Update `pluginVersion` handling needs nothing new — the
  changed agent files resync via the existing hash-tracked `--update`
  path.
- **Eval hook (optional, later):** the `eval/` harness's variant-overlay
  pattern (see `docs/specs/2026-07-13-hardening-eval-spec.md`) could
  test feature 3 by injecting a plan with a known-conflicting pair of
  steps and asserting the Self-check section flags it. Out of scope
  here; noted so the implementer doesn't design against it.

## Non-goals (rejected spec-kit imports)

- **Extensions/presets/bundles marketplace** — Claude Code's own
  plugin/marketplace system plus the deterministic `bin/cli.js --update`
  resync already cover this; a second extensibility layer is redundant.
- **Numbered `specs/{NNN-slug}/` directories + numbering script** —
  AntiSlop's dated `docs/plans/YYYY-MM-DD-<slug>.md` / `docs/specs/...`
  slugs avoid the sequential-numbering merge conflicts that script
  exists to solve; not worth replacing.
- **30+ coding-agent abstraction layer** — AntiSlop is Claude-Code-
  specific by design.
- **A standalone `/analyze` command or persona** — folded into features
  3 and 4 above; the README stresses keeping the persona surface small,
  and 8 is already a lot.
