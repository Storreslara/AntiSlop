# Item 15: gh415 `.seal` sidecars on audit logs an agent can `rm`

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 15 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (gh415)
Disposition: **PARTIALLY ACCEPT** — the review's "tamper evidence on rm-able files is theater" is too strong, but the seals' actual guarantee is undocumented and worth either strengthening or stating honestly.

## Goal

Decide whether the `.seal` sidecars earn their footprint, and — whichever way
— make the guarantee they actually provide explicit, so neither an operator
nor a future auditor over-trusts them.

## Context

The review's verdict: *"Tamper-evidence for logs an agent can `rm`… Revert.
If you want tamper evidence, append to a git-tracked file and let the
pre-commit hook sign it, or ship logs to `~/.claude`. Seals on rm-able files
are theater."*

Measured 2026-09-25. Four audit logs each carry a `.seal` sidecar:
`.claude/review-audit.log`, `dispatch-audit.log`, `microworld-audit.log`,
`wip-audit.log`. `harness-integrity-gate.sh`'s header states the seals are in
**Set A** — denied on both the Write/Edit and the Bash branch — *"since a
denial the gate itself logs sits in Set A too"*.

**Why "theater" overstates it.** Deletion and undetected modification are
different threats. A seal does not prevent `rm`, but it does mean a
*modified* log fails verification — and a *missing* log is itself loud, since
its absence is trivially visible. So the seal converts "silently edit one
line" into "delete the whole file and be obvious about it". That is a real,
if narrow, escalation of cost.

**Why the review's complaint still lands.** Two gaps, both verified:

1. **The guarantee is nowhere stated.** Nothing in the repo says "seals
   detect modification, not deletion; deletion is detected by absence." An
   auditor reading "tamper evidence" reasonably infers more than is
   delivered. This is the same over-trust problem as item 1's Set A
   read-asymmetry.
2. **Nothing verifies the seals routinely.** A tamper-evidence mechanism that
   is never checked provides evidence to nobody. If no scheduled or gated
   verification exists, the seals are write-only — which *is* close to the
   review's characterisation, though for a different reason than it gives.

Point 2 is the decisive one and is Step 1's subject: the value of the whole
mechanism turns on whether anything ever reads a seal.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-25 Non-functional attributes: Q What threat do the seals actually
  address? → A (self-resolved): **undetected modification**, not deletion.
  Deletion is detected by the file's absence. The review conflates the two;
  the repo never distinguishes them, which is the real defect.
- 2026-09-25 User interaction flow: Q Who verifies a seal, and when? → A
  (self-resolved): **not established** — this is Step 1. If the answer is
  "nobody", the mechanism is write-only and the review is effectively right.
- 2026-09-25 Edge cases / failure handling: Q What happens if a seal and its
  log disagree today? → A (self-resolved): unknown without Step 1; if no
  consumer exists, nothing happens at all.
- 2026-09-25 Terminology consistency: Q Is "tamper evidence" the right term
  for what this provides? → A (self-resolved): **too broad.**
  "Modification-evidence" is accurate; "tamper evidence" implies coverage of
  deletion it does not have. Worth a glossary correction either way.

## Risks and dependencies

- **R1. Do not remove a working control on a mischaracterisation.** If
  Step 1 finds a real consumer, the seals are functioning and removal would
  be a regression.
- **R2. The git-tracked alternative has a conflict.** The review proposes
  appending to a git-tracked file signed by the pre-commit hook. But audit
  logs are high-churn and currently gitignored; tracking them would add
  commit noise to every run and make the working tree dirty mid-unit — which
  this repo already knows breaks the PASS-marker precondition (a recorded
  incident: concurrent memory writes dirtying the tree failed the v3 marker
  check). Not a drop-in.
- **R3. The `~/.claude` alternative loses project-locality** and interacts
  with Set A, which is defined in project-relative paths.
- **R4.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — seal membership and the gate's
  stated rationale read directly; the "theater" claim tested against the
  modification-vs-deletion distinction rather than accepted.
- P2 "Prefer deterministic scripts over LLM re-derivation": engaged by
  Step 2 — a verification command is exactly the deterministic artifact
  missing today.
- P3 "Version-stamp discipline": deviation — Steps 1–2 touch hook scripts,
  tests and docs, none version-stamped. If prose in `agents/*.md` changes,
  P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — untouched.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Establish whether anything consumes a seal

**Affected files:** none modified; findings in the report.

**Acceptance criteria**
- The report names every consumer that reads or verifies a `.seal`, with
  file and line, or states definitively that **none exists**.
- It states when verification occurs (a hook event, `validate.sh`, a manual
  command, or never).
- It states the disposition: **functioning** (a consumer exists) or
  **write-only** (none does).
- `git status --porcelain` is empty.

## Step 2 — Act on the disposition

**Affected files:** depend on Step 1's result; in all branches,
`CONTEXT.md` or `docs/harness-glossary.md`.

- **If write-only:** add a verification command (`bin/` or `validate.sh`)
  that checks each log against its seal and reports mismatches. Adding a
  consumer is strictly cheaper than removing the mechanism and re-deriving
  tamper evidence later, and it converts the review's objection into a
  closed gap.
- **If functioning:** leave the mechanism alone.

In **both** branches, document the guarantee honestly.

**Acceptance criteria**
- The glossary states, in one sentence, that seals detect **modification**
  and that deletion is detected by absence — the over-trust gap closes
  regardless of branch.
- The term `tamper evidence` is either replaced with a precise term or
  qualified at every occurrence: assert
  `grep -rc 'tamper evidence' hooks/ docs/ CONTEXT.md` and require each
  remaining occurrence to be accompanied by the modification/deletion
  distinction — report each occurrence's disposition.
- If a verification command was added: it exits 0 on intact logs, and
  **non-zero naming the file** on a mutated one. Prove by mutation — append a
  line to a log copy, confirm the check reports, restore, confirm it passes.
  Record both observations. Operate on **copies**, never the live logs (Set A
  denies writes to them, and attempting one is a gate violation to report,
  not to work around).
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **If Step 1 reports write-only, should the seals be removed instead of
   given a consumer?** Recommended default: **give them a consumer.** The
   mechanism already exists, is already protected by Set A, and its removal
   would itself be a multi-file change touching the gate's Set A definition
   and its asymmetry mutation control — more work than adding a checker, for
   less safety. The review's alternatives (git-tracked, `~/.claude`) both
   carry real problems (R2, R3) and neither is a drop-in. Requires a human
   decision only if the operator wants removal regardless.

## Self-check

- CHK1: Is "theater" tested rather than adopted? — PASS (the
  modification-vs-deletion distinction shows a narrow but real guarantee).
- CHK2: Does the spec decide before measuring? — PASS (Step 1 establishes
  consumers; Step 2 branches on the result).
- CHK3: Are the review's alternatives evaluated? — PASS (R2 and R3 give
  concrete conflicts for each).
- CHK4: Does the spec close the over-trust gap in every branch? — PASS
  (Step 2's glossary criterion is unconditional).
- CHK5: Could Step 2's mutation proof violate Set A? — FAIL (missing) —
  revised in place: the criterion now requires operating on copies and states
  that a Set A denial is to be reported, not worked around.

## Scribe update hint

Correct **tamper evidence** to name what the seals do and do not cover, or
replace it with a precise term. Record the Set A membership rationale (a
denial the gate logs is itself in Set A) so the seals' inclusion is not
re-litigated as redundant.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item15-seal-sidecars.md`.
Order: Step 1 gates Step 2's branch.

### Unit: item15-1-find-seal-consumers
- **Objective:** Determine whether anything verifies a `.seal`.
- **Retrieval:** Step 1.
- **Affected files:** none.
- **Ordered edits:** sweep for seal readers → identify verification timing → state functioning/write-only.
- **Do NOT touch:** any log, seal, or gate.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** four logs carry seals (`review-audit`, `dispatch-audit`, `microworld-audit`, `wip-audit`); all are Set A, denied on both Write/Edit and Bash branches. A Bash command naming a log is blocked — reproduced live 2026-09-25; `Read` succeeds. Use `Read` or `grep -r` over source, and never rephrase to evade a gate.
- **Escalation:** if a consumer is ambiguous (e.g. reads the seal but ignores mismatches), classify as write-only and explain.

### Unit: item15-2-document-and-verify
- **Objective:** Close the over-trust gap; add a verifier if none exists.
- **Retrieval:** Step 2.
- **Affected files:** glossary (`CONTEXT.md` or `docs/harness-glossary.md`); possibly a new `bin/` or `validate.sh` check.
- **Ordered edits:** document the modification-vs-deletion guarantee → audit `tamper evidence` occurrences → if write-only, add verifier → mutate-prove on copies.
- **Do NOT touch:** live audit logs or seals; the gate's Set A definition; the asymmetry mutation control in `tests/harness-integrity-gate.test.sh`.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item15-1. If item 3 has landed, seal terminology is harness-glossary content — do not create a duplicate entry in both files.
- **Escalation:** if mutating even a copy trips a gate, report and wait — that is the documented report-and-wait case.
