# Item 16: The hcb / ADR-0034 human-confirmation branch in `harness-integrity-gate.sh`

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 16 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (hcb / ADR-0034)
Disposition: **REJECT the "just use `permissions.ask`" alternative; ACCEPT the complexity concern.** Recommend consolidation, not removal.

## Goal

Evaluate whether the human-confirmation branch earns its footprint, and
record why the review's two proposed alternatives do not replace it.

## Context

The review's verdict: *"A gate that denies writing its own registration file
needed an 'ask a human' branch so `--update` could work… Over-engineered. Two
allowlisted permission-mode tiers, asked/completed audit-record pairing, a
'registration-presence assertion', six glossary entries. Alternative:
`permissions.ask` in `settings.json` for those five paths, or simply run
`bin/cli.js --update` outside the harness."*

Verified 2026-09-25 from the gate's own header:

- Five paths route through the branch: the persona-selection config (Set A's
  one ask-eligible member) plus Set B's four registration-surface literals
  (`hooks/hooks.json`, `.claude/settings.json`, and the gate script in both
  its source and mirror locations).
- Two mode tiers: Set A asks in `default|plan|acceptEdits|auto` (4 modes);
  Set B asks in `default|plan|auto` (3 — excluding `acceptEdits`).
- **Both tiers never emit `ask` from a subagent.**
- 20 of the last 40 commits touched this area (the review's count).

**Why `permissions.ask` does not replace it — the decisive point.** The
branch's tier distinction is not decoration: Set B deliberately excludes
`acceptEdits`, because in that mode an edit to the gate's own registration
surface would be auto-accepted, which is precisely the capture this gate
exists to prevent. `permissions.ask` in `settings.json` carries no
mode-awareness and, more importantly, **lives in `.claude/settings.json` —
which is itself one of the five protected paths.** A control that is
configured in the file it protects can be disabled by editing that file. The
current branch is hardcoded and configless specifically to avoid that
circularity, mirroring `human-decision-gate.sh`'s stated precedent.

So the alternative is not equivalent; it is strictly weaker in the one
dimension the gate exists for.

**Why "run `--update` outside the harness" does not replace it either.** That
is a valid *operator workaround*, not a mechanism — it requires the human to
remember, every time, and it silently fails closed into "the agent cannot
update the project" for any autonomous run. It also contradicts
`install-antislop`'s documented route, which the gate's own denial message
points at.

**Where the review is right.** The surface *is* large for what it does: two
mode tiers, an asked/completed audit-record pair, a registration-presence
assertion, and six glossary entries, for five paths. And the subagent
exclusion means the branch is unreachable for most of this framework's
actual work, since most work happens in subagents. That last point is
measurable and is Step 1's subject: **if the branch almost never fires, its
complexity is unamortized** — and unlike the review's framing, that is an
argument for consolidation rather than for the weaker alternative.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Technical constraints & tradeoffs: Q Can `permissions.ask`
  replace the branch? → A (self-resolved): **no** — it is configured in
  `.claude/settings.json`, one of the very paths protected, so it is
  disableable by the edit it guards against; and it carries no
  per-mode tiering.
- 2026-09-25 User interaction flow: Q How often does the branch actually
  fire? → A (self-resolved): **unmeasured, and likely rarely**, since it
  never emits `ask` from a subagent and most work here is subagent work.
  Step 1 measures it.
- 2026-09-25 Edge cases / failure handling: Q What happens when an agent hits
  a protected path in a subagent? → A (self-resolved): outright deny with the
  `--update` remediation message — reproduced live 2026-09-25 on three
  read-only commands. The deny path is well-exercised; the *ask* path is the
  unmeasured one.
- 2026-09-25 Non-functional attributes: Q Is the complexity load-bearing or
  incidental? → A (self-resolved): the mode tiering is load-bearing (it is
  the anti-capture property); the audit-record pairing and
  registration-presence assertion are candidates for consolidation, pending
  Step 1.

## Risks and dependencies

- **R1. Do not weaken the anti-capture property.** Any consolidation must
  preserve Set B's `acceptEdits` exclusion. This is the single thing that
  must survive.
- **R2. Recently-built, well-tested area.** `tests/harness-integrity-gate.test.sh`
  is 1,466 lines and includes an asymmetry mutation control that exists
  specifically to catch a regression in the Set A/Set B Bash asymmetry. Churn
  here is expensive and the tests will resist casual change — by design.
- **R3. This area has a 2-FAIL debug-spec history.** Per the
  `harness-integrity-gate-debug-spec` memory note, unbounded-universal
  acceptance criteria caused a FAIL loop here, and the remedy was to freeze a
  family table. **Any criteria in a follow-up spec must be bounded and
  enumerated** — do not write "no command of any shape may…". Any unit here
  must not be tagged `haiku`.
- **R4.** Item 20 interacts: if `humanReviewMode` changes, the surrounding
  human-in-the-loop posture changes, though this gate is independent of that
  mode (it is configless by design).

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the five paths, two tiers and the
  subagent exclusion read from the gate's own header; both alternatives
  tested rather than repeated.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  gate is configless and hardcoded by design; the review's alternative would
  move it into editable config, which is the wrong direction for P2.
- P3 "Version-stamp discipline": deviation — Step 1 modifies nothing; a
  follow-up consolidation would touch hook scripts, not version-stamped
  files. If prose in `agents/*.md` changes, P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — the gate is
  persona-independent.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Measure how often the ask branch fires

**Affected files:** none modified; findings in the report.

**Acceptance criteria**
- The report states the count of `asked` audit records and of `completed`
  audit records, and the date range covered.
- It states how many arose from a main session vs a subagent (expected: zero
  from subagents, per the header — confirm rather than assume).
- It states the disposition: **amortized** (the branch fires regularly) or
  **unamortized** (it rarely or never fires).
- Read audit logs via the `Read` tool: a Bash command naming one is blocked
  by this very gate (reproduced live 2026-09-25). Do not rephrase to evade.
- `git status --porcelain` is empty.

## Step 2 — Record the disposition as an ADR amendment

**Affected files:** an amendment to
`docs/adr/0034-human-confirmation-branch-per-call-consent-not-escalation.md`,
or a new superseding ADR; glossary.

Record the measurement and the evaluation of both alternatives, so this is
not re-raised at the next audit with the same two suggestions.

**Acceptance criteria**
- The ADR (or amendment) states why `permissions.ask` is not equivalent —
  specifically the circularity (`settings.json` is itself protected) and the
  absent mode tiering: `grep -c 'permissions.ask' <file>` ≥ 1.
- It states why "run `--update` outside the harness" is an operator
  workaround rather than a mechanism.
- It records Step 1's fire-count and the amortized/unamortized disposition as
  a number, not prose.
- If **unamortized**, it names the specific consolidation candidates (audit-
  record pairing, registration-presence assertion) and explicitly states that
  Set B's `acceptEdits` exclusion is **not** a candidate (R1).
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **If Step 1 reports unamortized, should the branch be consolidated?**
   Recommended default: **consolidate the audit-record pairing and the
   registration-presence assertion; keep the branch and both mode tiers.**
   The branch is what makes `--update` possible under the gate at all; the
   accounting built around it is what grew. Any consolidation spec must carry
   bounded, enumerated criteria per R3 — this area has already cost a 2-FAIL
   escalation from unbounded-universal criteria. Requires a human decision
   before a consolidation spec is authored.

## Self-check

- CHK1: Are both proposed alternatives evaluated rather than dismissed? —
  PASS (circularity and mode tiering for one; operator-workaround status for
  the other).
- CHK2: Is the review's complexity concern acknowledged? — PASS (the surface
  is agreed large; Step 1 measures whether it is amortized).
- CHK3: Is the anti-capture property protected from consolidation? — PASS
  (R1, and Step 2's explicit not-a-candidate criterion).
- CHK4: Does the spec account for this area's FAIL history? — PASS (R3 names
  the unbounded-criteria failure mode and forbids a `haiku` tag).
- CHK5: Does Step 1 respect the gate it is measuring? — PASS (names the
  permitted read route and forbids rephrasing).
- CHK6: Could Step 2 pass with a prose-only disposition? — PASS (the
  fire-count must be recorded as a number).

## Scribe update hint

The hcb work already added several glossary entries (`ask-eligible`, `asked
audit record`, `completed audit record`, `registration-presence assertion`).
Once Step 1 lands, annotate `ask-eligible` with the measured fire-count so
the branch's amortization is visible without re-deriving it. If item 3 has
landed, these are harness-glossary entries.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item16-hcb-human-confirmation-branch.md`.
Order: Step 1 → Step 2.

**Model tagging note:** neither unit may be tagged `haiku` (R3).

### Unit: item16-1-measure-ask-branch
- **Objective:** Measure how often the human-confirmation branch fires.
- **Retrieval:** Step 1.
- **Affected files:** none.
- **Ordered edits:** read audit logs via `Read` → count asked/completed records → classify by caller type → state amortized/unamortized.
- **Do NOT touch:** the gate, its tests, any log or seal.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** five ask-eligible paths; Set A asks in 4 modes, Set B in 3 (excluding `acceptEdits`); neither emits `ask` from a subagent. A Bash command naming an audit log is blocked by this gate — reproduced live 2026-09-25; `Read` succeeds.
- **Escalation:** if the logs carry no `asked` records at all, that is a valid "unamortized" finding, not a measurement failure — report it as such.

### Unit: item16-2-record-disposition-adr
- **Objective:** Record the evaluation so it is not re-raised identically.
- **Retrieval:** Step 2.
- **Affected files:** ADR-0034 amendment or a new superseding ADR; glossary.
- **Ordered edits:** record fire-count → evaluate `permissions.ask` (circularity + tiering) → evaluate the outside-the-harness workaround → name consolidation candidates if unamortized → state the `acceptEdits` exclusion as non-negotiable.
- **Do NOT touch:** the gate script; `tests/harness-integrity-gate.test.sh`; Set A/Set B membership.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item16-1. `.claude/settings.json` is itself one of the five protected paths — this circularity is the core reason `permissions.ask` is not equivalent. ADR numbering increments from max; never backfill 0007.
- **Escalation:** if the measurement suggests the branch should be removed entirely, report rather than specifying removal — that would drop `--update`'s only in-harness route.
