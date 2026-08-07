# Efficiency audit remediation — Pass 3 (control-plane trimming)

Author: `spec-master` | Date: 2026-08-03 | Baseline sha: `e5b908f`
Published spec issue: **#229** (`ready-for-agent`). This document is canonical;
the issue is its published view.

**Revision 2 — 2026-08-04.** `task-master` sliced this spec into units
#230–#244 and returned four defects in the spec's own acceptance criteria
(affecting #231, #233, #234, #238), correctly declining to patch them itself.
All four were reproduced live, fixed at the root, and recorded as CHK21–CHK24.

**Revision 3 — 2026-08-04.** `task-master` re-sliced 11 units against
Revision 2 and found **GAP-6** while verifying: Revision 2's R-G fix swept only
the sites that already carried a `tr`, leaving un-joined sites untouched — the
very failure mode it claimed to close. Fixed at the root. R-G now defines
**three** criterion shapes, because the single form Revision 2 mandated would
have *broken* two of them. Recorded as CHK25–CHK27. **Only unit #231 (Step 2)
changes, and it is a criteria-text-only swap** — see § "Revision 2/3 impact on
already-sliced units".

**Revision 4 — 2026-08-04.** The `spec-master` run on issue #245 found, during a
cross-spec file-overlap check, that unit **#235** (Step 6a) required a non-zero
diff in two adapter ports that **do not contain the section being compressed**.
Root cause was this spec's own affected-files list. Fixing it surfaced two more
6a defects: the slim-tier template had no criterion at all, and 6a's output
would have needed an immediate second edit from the #245 track. Recorded as
CHK28–CHK30. **Only #235 changes; the other 14 units are untouched.**

**Revision 5 — 2026-08-04.** `task-master` verified Revision 4 by substituting
the supplied reference text into the real templates and re-running criterion 1,
rather than trusting the stated line count — and found it returns **9**, failing
its own ceiling, because the measurement includes the blank separator line.
Resolved by shedding to 7 content lines (option (a); the other two options are
rejected on the record). Also corrected **R-D**, whose blanket "update both
adapter ports" wording contradicted criterion 9b and was the original source of
GAP-7. Recorded as CHK31–CHK32. **Still only #235; still a text-only update.**

**Revision 6 — 2026-08-06 (operator amendment, not a defect).** The human
corrected **F1 / Step 1 / unit #230**: `spec-master` stays opus|sonnet as
specified, but `milestone-auditor` **keeps fable** and gains a sonnet tier —
three tiers, not two. Because F1's finding was that fable eligibility was
*inverted*, fable is relocated from the old "mechanical end-to-end" condition to
a **size** condition (≥8 units, measured to fire on 25 % of this repo's
milestones), with judgment signals dominating. Five downstream claims that
assumed "fable is dispatched nowhere" are corrected, including two expected
counts that would otherwise have failed on a correct implementation. Recorded as
CHK33–CHK35. **Units #230 and #231 change; the other 13 are untouched.**

**Revision 7 — 2026-08-06.** `task-master` proved by simulation that a
Revision-6 tree with Step 1's **Change item 4** (the Escalation-symmetry edit)
left unapplied still passes all six greppable criteria and the not-in-this-step
control — Revision 6's correct narrowing of criterion 2 silently dropped the
incidental coverage Revision 5 had. Added paragraph-scoped **criterion 7**,
confirmed RED at baseline. Also recorded **R-M**, the measured 387-byte margin
on the template ceiling. Recorded as CHK36–CHK37. **Only #230 changes.**

**Revision 8 — 2026-08-06 (correction, not a defect in this spec's own logic).**
Skills-library spec #245's unit #246 renamed the placeholder skill name
`to-issues` to the real name `to-tickets` throughout `agents/spec-master.md`,
including inside the ADR-0003 disclaimer sentence this spec's Step 9 added
(now reads "You never run `to-tickets` on any path (ADR-0003 preserved)").
This left Step 9's criterion 3 (and its own descriptive prose) asserting a
now-stale literal against current `agents/spec-master.md`. Corrected in place
at Step 9's operative prose and criterion 3's regex (the "F7" finding's
self-resolution prose and the CHK11 checkpoint are left untouched as
historical record of the reasoning at spec-authoring time; ADR-0003's own
quoted text is likewise untouched — it is historical per this repo's
convention). No units re-slice; this is a criteria-text-only correction to an
already-PASSed step (#239).

Status: **FINALIZED — no steps blocked.** All five Open Questions were ruled on
by the operator on 2026-08-03 (see § Open Questions, retained as an audit
trail). Ready for `task-master` to slice.

**Operator ruling summary** — OQ1: **remove** the fable roast pass (option (b),
*against* spec-master's recommendation of (a) narrow); OQ2: no threshold change
(a); OQ3: implementer tiers only (a); OQ4: keep the audit mandatory (a); OQ5:
accept the proposed ceilings (a).

---

## Goal

Reduce tokens-per-unit-of-work in this repo's own persona/orchestration
control plane, by (a) removing model-tier routing that spends the most
expensive tier on the cheapest work, (b) collapsing duplicated persona
handoffs, and (c) compressing always-on prose for rarely-hit paths —
**without** weakening the Writer/Reviewer split, without new personas, and
without new hook scripts.

Scope is `agents/*.md`, `templates/persona-protocol*.md`,
`hooks/scripts/reviewer-tier.sh`, `bin/cli.js`'s protocol matrix, the two
adapter doc ports, and the `docs/adr/` + `CONTEXT.md` institutional record.
It is **not** a change to any target project's application code.

This is the "Pass 3" that `docs/plans/2026-08-01-efficiency-audit-remediation-pass2.md`
(§ "Deferred to Pass 3") explicitly reserved: Pass 2 deferred F4 (roast passes
fire too readily), F6 (the model-routing decision tree) and F9 (slim-tier
delivery) "for lack of a source", and its Step 8 Part B tasked a fresh Fable
audit with re-deriving them. **The audit this spec remediates is that
re-derivation.** Its F2 ≡ Pass-1/2's F4; its F8 ≡ Pass-1/2's F6.

---

## Context — what I verified, and what did not survive verification

Everything below was measured or read at `e5b908f`, not taken from the audit's
report. The audit is Fable-tier static analysis of file contents and was
explicitly not runtime-verified.

### Verified as filed

**F1 — the fable slot inverts cost against difficulty. VERIFIED.**
`agents/orchestrator.md` § "Opus|Fable routing for spec-master and
milestone-auditor" grants `model: fable` exactly when scope is already
enumerated, the change rides existing seams, and no interrogation is needed —
the easiest possible spec work. `templates/persona-protocol.md:287` states
"Fable is the single most expensive model tier available to this system"
(mirrored verbatim into 4 files). So the condition set selects the most
expensive tier for the least demanding work. `grep -c 'model: fable'
agents/orchestrator.md` = **4** at baseline.

**F2 — the trigger is broad enough to be a de-facto default. VERIFIED, but the
audit's *reason* is wrong.** See "Corrected" below.

**F4 — the ratchets are real and enumerable. VERIFIED.** Exactly five one-way
ratchets exist, and they are not equivalent:
| # | Ratchet | Where | Expires? |
|---|---|---|---|
| R1 | reviewer-tier `sonnet`→`opus` downgrade, never upgrade | `agents/orchestrator.md` § "Reviewer gate model selection"; ADR-0009 decision 3 | n/a — a per-dispatch judgment, not durable state |
| R2 | a `.fail` record permanently forces `opus` on that unit's **review** | `hooks/scripts/reviewer-tier.sh:73-75`; `agents/orchestrator.md` § "`.fail` disqualifier"; ADR-0006, ADR-0009 | never |
| R3 | a `.fail` anywhere among "the units a spec-master replan or milestone-auditor audit touches" disqualifies fable for that whole dispatch | `agents/orchestrator.md` § "A prior `.fail` record is an automatic disqualifier for fable" | never |
| R4 | haiku→sonnet on first FAIL, "never haiku again" | `agents/orchestrator.md` § "Haiku units escalate on first FAIL"; `agents/task-master.md` § "Per-unit model tag" | never |
| R5 | fable→opus escalation symmetry | `agents/orchestrator.md` § "Escalation symmetry" | never |

R1 is **not** a durable cost ratchet (it is re-decided per dispatch from a
fresh measurement) and this spec does not touch it. R3 and R5 become dead
prose once Step 1 lands. R2 and R4 are the real durable ratchets.

The repo already contains the counter-precedent this fix should mirror:
`templates/persona-protocol.md:293-303` ("Downgrade/expiry path") expires the
roast-pass trigger for a unit *class* after 3 clean passes, and says so in
exactly these terms — "so total system cost does not only ratchet up over the
repo's lifetime."

**F5 — the scribe fires twice per unit. VERIFIED.**
`agents/lead-programmer.md:43-49` ("Scribe updates (batched,
blocking-but-brief) … batch it at the END of each plan step"), plus
`agents/orchestrator.md` § "Scribe dispatch convention" (post-landing dispatch
carrying issue number + task-id), plus `agents/orchestrator.md` § "Default
feature pipeline" which explicitly says "lead-programmer (which updates the
scribe itself)". Two dispatches, overlapping payloads. The lead's call is
additionally **blocking** ("spawning it pauses you until it returns").

**F8 — always-on prose is heavy, and the largest offender is not the one the
audit named. VERIFIED with measurements.** Per-section byte sizes at baseline:

`agents/orchestrator.md` own body (30 839 B total, read every main-session turn):
| Section | Bytes | Lines |
|---|---|---|
| **Per-unit model routing** | **11 230** | **192** |
| Managing a long-running background dispatch | 3 852 | 64 |
| Review routing — you are the single owner | 4 543 | 70 |
| Milestone audit gate | 2 205 | 34 |
| Delegation contract | 1 754 | 30 |
| If Plan Mode is active | 1 101 | 19 |
| Dispatch hygiene | 812 | 15 |
| If a feature team is active | 581 | 10 |

`templates/persona-protocol.md` (19 185 B, inlined per full-tier persona):
| Section | Bytes | Lines |
|---|---|---|
| Review ownership — one unit, one review, single owner | 2 834 | 44 |
| Terminal status line | 2 394 | 43 |
| Reviewer roast-work advisory pass trigger | 1 890 | 32 |
| Pending-review flag | 1 461 | 21 |
| **Agent-teams mode** | **1 359** | **20** |
| Third verdict: insufficient-context | 1 394 | 23 |
| Continuing after a FAIL verdict | 1 250 | 20 |

"Per-unit model routing" alone is **36 % of the orchestrator's own body** —
larger than the agent-teams section multiplied across all six full-tier
personas. It is also Pass-1's deferred F6 ("the 14-subsection model-routing
decision tree … restated caveats (`CLAUDE_CODE_SUBAGENT_MODEL` ×3,
`.fail`-check ×3)"). Steps 1, 4 and 9 all edit this same section, so
compressing it is nearly free once they land.

'Agent-teams mode' sits in `bin/cli.js`'s `UNIVERSAL_PROTOCOL_CORE`
(`bin/cli.js:501-507`), so **every** full-tier persona carries it, and
`templates/persona-protocol-slim.md` carries it too — 7 copies.

**F9 — VERIFIED.** `agents/orchestrator.md` § "On an `INSUFFICIENT-CONTEXT`
verdict" ends "then re-dispatch the reviewer with that constraint added to the
packet". `reviewer` has `SendMessage` in `tools:`, and the same file already
documents resume-by-name via `SendMessage` twice (§ "Delegation contract",
§ "Managing a long-running background dispatch").

**F11 — VERIFIED.** `agents/lead-programmer.md:38-42` mandates a pre-edit
explorer spawn unconditionally; `agents/task-master.md` dispatch-contract
element 8 (`## Pre-resolved context`) already requires "whether an `explorer`
lookup is needed — with its answer already fetched". Direct overlap.

### Corrected — the audit's premise does not survive measurement

**F3 — REFUTED. The sonnet gate is reachable at ~13 %, which is what ADR-0009
predicted.** I ran `hooks/scripts/reviewer-tier.sh` against each of the last 60
real commits (`<sha>^..<sha>`, fresh task-ids with no `.fail` record):

```
sonnet = 8 / 60  (13.3 %)
opus   = 52 / 60
```

ADR-0009 § Consequences predicted "roughly 6–8 of the last 50 commits (~15 %)".
The measurement lands inside that band. The audit conflated the **successor**
scheme with the **predecessor** one: it was ADR-0006's prediction-time
`Suggested model: haiku` coupling that fired ~0 % of the time (ADR-0009 §
Context, measured at issue #190 finding F2). ADR-0009 *fixed* that, and the fix
works.

Attribution of the 52 `opus` verdicts:
```
blocked by sensitive path only : 9   (all small: ≤3 files, ≤38 lines)
blocked by size only           : 16
blocked by both                : 27
```
Of the 9 sensitive-path-only blocks, 4 touch `hooks/` or `stop-gate` —
precisely the class ADR-0009 § Context refuses to sonnet-gate ("over the last
50 commits, three of the smallest diffs (`1f 28L`, `2f 41L`, `1f 25L`) were
security-critical … **Size alone is unsafe**"). Raising size thresholds would
add at most the 16 size-only blocks, and those include a 2 299-line plan
document, a 529-line mirror regeneration, and three 294–304-line doc commits —
none of which anyone should want sonnet-gated on the strength of a line count.

**Therefore: the recommended default for F3 is no threshold change**, plus a
dated re-measurement recorded against ADR-0009 so a Pass 4 does not re-file
this. Raised as **OQ2**.

One smaller, genuinely-evidenced sub-finding survives: `.claude/agents/` is the
most-hit sensitive pattern (59 hits across 60 commits) and its contents are
*generated*, byte-derivable from `agents/*.md` + `templates/` via `node
bin/cli.js --update`. A mirror-regeneration diff is mechanically verifiable in
a way a hand-written diff is not. Pruning it is a coherent proposal, but it is
not free (it also un-guards a *hand-edited* mirror), so it is folded into OQ2
rather than assumed.

**F2 — the finding is real, the stated reason is not.** The audit says the
separate fable pass "duplicates the `roast-work` skill the reviewer already
runs inline". Structurally that is true — same rubric, same diff — but
ADR-0004 § Decision, Tension 2 is explicit that the delta was never *coverage*,
it was **model capability on a large surface**: "roast-work … is a
BULK-CONTEXT task — large surface coverage is exactly where fable's
bulk-context strength comes into play", and "**For routine/small units:** the
single opus reviewer runs roast-work inline … no separate fable pass". So
removing the pass is a capability reduction against an accepted ADR, not a
redundancy deletion.

What *is* miscalibrated is the trigger, and the defect is precise: **criteria 2
and 3 carry no size floor at all**, so they fire on a 2-line diff. In a repo
whose entire product is hooks (input parsers → criterion 3) and persona prose
(shared cross-persona surface → criterion 2), that is nearly everything.
Measured: only **8 of 60** recent commits are neither in a sensitive class nor
oversized. Criterion 1 alone (≥8 files OR ≥400 lines) fires on **7 of 60
(11.7 %)** — a genuinely rare exception, exactly as ADR-0004 intended.

spec-master's recommended default was **add a conjunctive size floor to criteria
2 and 3** rather than deleting the pass. Raised as **OQ1**.

**OPERATOR RULING (2026-08-03): REMOVE the pass entirely — option (b),
overriding spec-master's recommendation.** This is recorded as a *deliberate*
decision taken with the ADR-0004 tradeoff on the table, not an oversight. What
the operator accepted, explicitly:

- The system loses fable's bulk-context critique on genuinely large surfaces —
  the one thing ADR-0004 § Decision Tension 2 was designed to buy. The
  reviewer's **inline** `roast-work` pass (opus or sonnet, per the measured
  tier) is the accepted replacement and covers the same rubric on the same diff.
- ADR-0004 § Decision **Tension 2** (model routing) is therefore *superseded*,
  not merely amended. ADR-0004 § Decision **Tension 1** (roast-work is advisory,
  appended after the verdict, never gating) **survives unchanged** and is
  explicitly preserved by Step 2's anti-scope-creep control on
  `agents/reviewer.md`.
- Because the heavy trigger governed **only** the fable advisory pass
  (ADR-0009 § Preserved: "The heavy-unit trigger's own three criteria, which
  continue to govern the fable advisory pass only"), removing the pass makes the
  entire "heavy" concept dead. Step 2 therefore deletes the concept rather than
  leaving an orphaned definition — including `task-master`'s `Roast pass: fable`
  tag and its frontmatter `description:` mention.
- With Step 1, this leaves `fable` dispatched **nowhere** in the system. The
  standing exclusion guard in `agents/task-master.md` is deliberately *kept*
  (it is one line and prevents a future re-introduction on the wrong persona);
  only the dispatch paths go.

**F10 — the principle IS deliberate, so per the request's own instruction this
is an Open Question, not a silent reversal.** Traced to
`docs/plans/2026-07-13-persona-review-hardening.md:583`, with reasoning
attached: "The checkpoint is a quick human confirm pass; the auditor remains
the deeper automated adversarial pass — the former does not replace the latter,
and a clean checkpoint is not a reason to skip the audit." It also carries a
pinned acceptance criterion in that plan. Raised as **OQ4**.

**F7 — the fast path collides with ADR-0003, and the audit missed a downstream
break.** ADR-0003 § Decision states spec-master "Does NOT carry
`<MATTPOCOCK:to-issues>` — task-master owns slicing outright." Separately, if
no tracker issue is filed for a fast-pathed unit, then `agents/scribe.md`
§ "Issue closing" cannot fire (it requires "Both the issue number and task-id
were named in your dispatch"), and the retrieval contract has no tracker to
point at. Self-resolved: the fast path has spec-master emit the **nine-element
dispatch contract** directly (which `dispatch-hygiene.sh`'s H4 already
mechanically validates) **without** running `to-tickets` or filing tracker
issues; retrieval points at the `docs/plans/` path, and the scribe's
issue-closing duty correctly does not apply. ADR-0003 gains a back-pointer
rather than being contradicted.

### A live contradiction found during exploration (not in the audit)

`docs/adr/0004-...md:37` says a fable advisory pass is "cheap relative to
opus". `templates/persona-protocol.md:287` says "Fable is the single most
expensive model tier available to this system." Both are live; the second is
newer and governs. This contradiction is load-bearing for F1 *and* F2 — F1's
whole argument is that fable is the expensive tier. Step 3 records the
resolution against ADR-0004 (back-pointer, not rewrite — ADRs are historical).

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-03 Functional scope & success criteria: Q Are all eleven findings in
  scope, or only the named top five? → A (self-resolved): all eleven, sequenced
  as three milestones (F1/F2/F3+F4/F5/F8 → F6/F7 → F9/F10/F11), per the
  operator's "implement everything, top 5 first".
- 2026-08-03 Domain entities / data model: Q Is there any persisted data model
  in scope? → A (self-resolved): no. The only durable state touched is the
  marker files under `.claude/reviewed/` (`.pass` / `.fail` / `.blocked`), whose
  formats are frozen by this spec — no marker type is added, removed, or
  reformatted.
- 2026-08-03 User interaction flow: Q Does any change alter what a human sees
  or must do? → A (self-resolved): only F10 would (it makes an audit opt-in via
  `AskUserQuestion`), and F10 is deferred to OQ4. Every other change is
  persona-to-persona.
- 2026-08-03 Non-functional attributes: Q What is the target reduction — a
  percentage, a byte budget, or "as much as is safe"? → A (self-resolved): no
  target was given, so each compression step carries an explicit, measurable
  byte/line ceiling instead of an aggregate goal; see OQ5 for whether those
  ceilings are the right ones.
- 2026-08-03 External dependencies & integrations: Q How do edits to persona
  prose actually reach the running system? → A (self-resolved): verified
  directly. `agents/*.md` and `templates/*.md` are the edit source of truth;
  `.claude/agents/*.md` are generated mirrors carrying a `<!-- antislop vX.Y.Z
  | source: agents/<name>.md | ADAPT-substituted -->` stamp, produced by `node
  bin/cli.js --update`, which inlines the protocol between `<!--
  ANTISLOP:BEGIN persona-protocol -->` / `<!-- ANTISLOP:END persona-protocol
  -->`. Hand-editing a mirror is a constitution P2 violation.
- 2026-08-03 Edge cases / failure handling: Q Does expiring the `.fail`
  disqualifier re-open the hole ADR-0006 closed? → A (self-resolved): yes, for
  the reviewer *gate* specifically. ADR-0006 § Consequences: "a single confirmed
  miss removes sonnet eligibility for that unit forever." An expire-on-PASS rule
  applied to R2 would let sonnet→miss→opus-FAIL→fix→opus-PASS→sonnet-again
  cycle. Recommended default therefore expires only the *implementer*-side
  ratchets (R3, R4) and leaves R2 permanent. Confirmed as OQ3.
- 2026-08-03 Technical constraints & tradeoffs: Q "Don't invent new hook
  scripts" versus Pass 2's recorded direction that "F6 should follow Step 5's
  script-based precedent from Pass 1" → A (self-resolved): the operator's
  constraint governs. F8/Step 6 is prose compression only; no script is added.
  `hooks/scripts/reviewer-tier.sh` is edited in place at most (Step 3, gated on
  OQ2), never duplicated.
- 2026-08-03 Terminology consistency: Q Is fable cheaper or more expensive than
  opus in this system? → A (self-resolved): more expensive.
  `templates/persona-protocol.md:287` governs; `docs/adr/0004-...md:37`'s
  "cheap relative to opus" is stale and is corrected by back-pointer in Step 3.
- 2026-08-03 Completion / acceptance signals: Q What signals the whole
  programme is done? → A (self-resolved): each milestone ends with a release
  unit (version bump + mirror regeneration + CHANGELOG) whose criterion is
  `tests/validate.sh` exit 0 and `node bin/cli.js --update --check` exit 0. The
  programme is done when Milestone 3's release unit reaches reviewer PASS and
  the scribe unit (Step 15) has landed.

*Appended after the Open-Questions round-trip (operator answers, 2026-08-03):*

- 2026-08-03 Functional scope & success criteria: Q Should the fable roast-work
  advisory pass be narrowed with a size floor, or removed outright, given
  ADR-0004 bought it for bulk-context capability on large surfaces? → A: removed
  outright (OQ1 option (b)), overriding spec-master's recommendation of (a); the
  operator accepted the capability loss knowingly. Step 2 rewritten.
- 2026-08-03 Non-functional attributes (perf, security, scale): Q The
  `reviewer-tier.sh` sonnet gate measures 13.3 % reachable, inside ADR-0009's
  predicted band — change the thresholds anyway? → A: no threshold change (OQ2
  option (a)); record the re-measurement in the ADR trail only.
- 2026-08-03 Edge cases / failure handling: Q Does the `.fail` expiry-on-PASS
  reach the reviewer's own gate tier, re-opening the hole ADR-0006 closed? → A:
  no — implementer tiers only (OQ3 option (a)); `hooks/scripts/reviewer-tier.sh`
  stays untouched and R2 stays permanent.
- 2026-08-03 User interaction flow: Q Reverse "a clean checkpoint is not a
  reason to skip the audit", making the milestone audit opt-in? → A: no, keep it
  as-is (OQ4 option (a)); F1's fable→sonnet drop on clean mechanical milestones
  is the accepted savings mechanism. Step 12 closes as a no-change.
- 2026-08-03 Technical constraints & tradeoffs: Q Are the proposed compression
  ceilings and the four protected-rationale strings the right bound? → A: accept
  as proposed (OQ5 option (a)). *Consequence discovered while finalizing:* OQ1's
  removal deletes one of those four protected strings, so the list drops to
  three — see Step 6 and CHK16.

*Appended after the operator's Step 1 correction (2026-08-06):*

- 2026-08-06 Functional scope & success criteria: Q Should `milestone-auditor`
  lose fable eligibility along with `spec-master`, as the original F1 fix
  specified? → A: **no, per operator.** `spec-master` → opus|sonnet (fable
  removed, as specified); `milestone-auditor` → fable|opus|sonnet, adding a
  sonnet tier rather than deleting the fable one.
- 2026-08-06 Technical constraints & tradeoffs: Q If fable is kept for the
  auditor, on what condition — since F1's whole finding was that the existing
  fable condition was *inverted*? → A (self-resolved): fable moves from a
  "mechanical end-to-end" condition to a **size** condition (≥8 units).
  Preserving the old condition and adding sonnet beneath it would have kept the
  inversion intact; relocating fable to the one property ADR-0004 documents it
  as buying (bulk context on a large surface) resolves it. Ordering is
  opus → fable → sonnet, first match wins, with judgment signals dominating
  size.
- 2026-08-06 Non-functional attributes (perf, security, scale): Q Does keeping
  fable for the auditor invalidate F10's rejection rationale? → A
  (self-resolved): it **narrows one of its two legs, verdict unchanged.** The
  "already captured the saving" leg now holds only for milestones under 8 units
  (~75 % of them, measured); the deliberate-principle leg is untouched and is
  what OQ4 was actually ruled on. Corrected in Step 12 rather than left
  standing.

*Appended after `task-master`'s spec-gap round-trip (2026-08-04):*

- 2026-08-04 Completion / acceptance signals: Q Is this spec's own prescribed
  method for matching wrapped prose actually correct? → A (self-resolved, from
  four gaps `task-master` returned against units #231/#233/#234/#238): **no —
  R-G was half a fix and shipped two vacuous criteria.** Joining with
  `tr '\n' ' '` alone leaves the continuation line's indent in place, and some
  criteria did not join at all. R-G is rewritten to mandate
  `tr '\n' ' ' < file | tr -s ' '` and to ban any unjoined multi-word prose
  grep; all 36 join sites were corrected and every stated baseline re-verified
  against `git show e5b908f:<file>`.
- 2026-08-04 Terminology consistency: Q Where does the standing `fable`
  exclusion guard actually live? → A (self-resolved): `agents/orchestrator.md`
  § "task-master model routing" (`:258`). Step 2 said `agents/task-master.md`
  and Step 1 said `agents/orchestrator.md`; the two steps contradicted each
  other and Step 2 was wrong. The string `excluded` does not occur in
  `agents/task-master.md` at all.
- 2026-08-04 Edge cases / failure handling: Q Is Step 4's anti-regression
  control satisfiable given this spec's own mandated step ordering? → A
  (self-resolved): **no, as first written.** Step 2 lands first and edits two
  paragraphs of the very section Step 4 required to be byte-identical. Step 4's
  6c is re-scoped to the three safety paragraphs Step 2 provably does not
  touch.

---

## Risks / dependencies

- **R-A — `bin/cli.js --check` is not a dry run, and plain `--update` is often
  vacuous.** `--update --check` **writes** (it bypasses the "already current"
  fast-path at `bin/cli.js:711` and gates no write; `copyStampedBody` and both
  `persona-config.json` writes run unguarded). Plain `--update` returns before
  the render loop when `pluginVersion` matches and no stamp is stale. So: any
  criterion of the form "`--update` then assert no diff" is **vacuous**, and any
  criterion treating `--check` as read-only is **destructive**. Every
  regeneration criterion in this spec therefore (i) runs *after* a version bump,
  and (ii) asserts on `--update --check`'s **exit code** (0 clean, non-zero when
  a file has diverged from a fresh copy) plus its **per-file summary lines**,
  never on mtime and never on a plain double-run diff.
- **R-B — `.claude/persona-config.json` is git-tracked and rewritten by every
  render.** It belongs in every regeneration step's affected-files list.
- **R-C — the protocol matrix throws at load.**
  `assertProtocolMatrixComplete` (`bin/cli.js:659`) makes `bin/cli.js`
  *unloadable* if any canonical `## ` heading in `templates/persona-protocol.md`
  is not classified into `include` or `drop` in **every** row of
  `PROTOCOL_SECTIONS_BY_PERSONA` (six rows: orchestrator, lead-programmer,
  reviewer, spec-master, task-master, milestone-auditor). **Mitigation adopted
  throughout this spec: never add, remove, or rename a `## ` heading in that
  template — with exactly one sanctioned exception, Step 2.** Every other step
  compresses section *bodies* only and keeps its `bin/cli.js` blast radius at
  zero.

  **Step 2 is that exception, and it trips three guards at once.** Deleting
  `## Reviewer roast-work advisory pass trigger (fable heavy-lifting)` from
  `templates/persona-protocol.md` requires all three of the following in the
  same unit, or the repo does not load / does not test green:
  1. **`bin/cli.js` × 6 rows** — the heading is listed at `bin/cli.js:535` (orchestrator `include`), `:555` (lead-programmer `drop`), `:568` (reviewer `include`), `:591` (spec-master `drop`), `:602` (task-master `include`), `:626` (milestone-auditor `drop`). Leaving any one behind hits `assertProtocolMatrixComplete`'s *unknown-header* branch and makes `bin/cli.js` **unloadable** — every command, including `--update`, fails.
  2. **`tests/adapter-protocol-parity.test.js` × 4 sites** — the `ROAST` constant (`:28`), the `codexMap` entry, the `cursorMap` entry, and the dedicated `check('roast section is asserted PRESENT …')` block (`:122-127`). The maps are keyed by exact canonical header, and `checkPort` throws on a **stale key** as loudly as on a missing one, so a deleted section with a surviving map entry fails the test.
  3. **Both adapter ports** — `adapters/codex/agents-md-fragment.md` and `adapters/cursor/rules/persona-protocol.mdc` carry the ported section.

  `templates/persona-protocol-slim.md` does **not** carry this section
  (verified) and needs no change.
- **R-D — adapter ports carry parallel copies.**
  `templates/persona-protocol.md` is mirrored (as prose ports, not byte copies)
  into `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc`, guarded by
  `tests/adapter-protocol-parity.test.js` (section-presence parity, `:122-127`
  pinning a present-probe for the roast section).

  **The porting duty is per-section, and the parity map is what decides it —
  not a blanket rule.** Each canonical section is mapped in that test as either
  `{ probe }` (the port carries it; a step editing it **must** update both
  ports) or `{ deferred }` (the port deliberately omits it; a step editing it
  **must not** touch either port). Read the map before assuming.

  - **Roast trigger** — `{ probe }` in both ports → Step 2 updates both.
  - **Structural-questions section** — `{ probe }` in both → Step 13 updates both.
  - **Agent-teams mode** — **`{ deferred }` in both** → Step 6a must **not**
    touch either port, and criterion 9b enforces that with an empty
    `git diff --numstat`.

  > **Corrected 2026-08-04 (GAP-11).** Revisions 1–4 stated this as a blanket
  > "any step editing the roast trigger **or the agent-teams section** must
  > update both ports", which is false for the agent-teams half — neither port
  > has ever carried that section (`adapters/codex/agents-md-fragment.md:179`,
  > `adapters/cursor/rules/persona-protocol.mdc:171`). That blanket wording is
  > what produced GAP-7. Left uncorrected it would mislead the next step that
  > touches a `deferred` section, even though #235's own criterion 9b now
  > encodes the right behaviour directly. Same shape as GAP-6's lesson: **a
  > general rule with an unstated exception.**
- **R-E — `reviewed-path-gate.sh` blocks Bash commands mentioning the marker
  directory**, including read-only ones (two measured false positives are
  recorded in `.claude/agent-memory/antislop-spec-master/project_reviewed_path_gate_155.md`).
  Acceptance criteria in this spec deliberately avoid the literal marker-dir
  path inside shell commands (they grep for `reviewed/.*\.fail` instead). An
  executor that still trips the gate should use the documented escape hatch, not
  rewrite the criterion.
- **R-F — negated greps fail open.** `! grep …` turns grep's exit 2 (a bad
  pattern or unreadable file) into a pass, and an `&&`-compound hides a vacuous
  half. Every negative criterion below is written as `n=$(grep -c … || true);
  test "$n" -eq 0` and is paired with an **anti-sentinel** (proof the extraction
  is non-empty) and a **baseline value** (proof it was red before the change).
- **R-G — prose wraps at ~76 columns, and the naive fix for it is also wrong.**
  *Corrected 2026-08-04 after `task-master` returned four spec gaps against the
  first published version; the original R-G prescribed only half the fix and
  shipped two vacuous criteria as a result.* There are **two** distinct failure
  modes and every prose criterion in this spec must be immune to both:

  1. **No join at all.** A single-line `grep` for a phrase that spans a wrap
     matches nothing. Measured: `grep -c 'which updates the scribe itself'
     agents/orchestrator.md` returns **0** at `e5b908f`, not 1 — the phrase
     wraps as `(which` / `updates the scribe itself)` across
     `agents/orchestrator.md:173-174`.
  2. **Join without squeeze.** `tr '\n' ' '` replaces the newline with one
     space but leaves the continuation line's own leading indent intact, so a
     phrase wrapping into an indented line becomes `even<3 spaces>when` and
     still fails to match. Measured: `tr '\n' ' ' < agents/spec-master.md |
     grep -c 'even when nothing was Missing'` returns **0** at `e5b908f`;
     adding `| tr -s ' '` returns **1**.

  **Revision 3 correction (2026-08-04).** Revision 2 stated a *single* mandated
  form and claimed it closed both modes. That was wrong twice over: its rewrite
  pass only revisited sites that **already had** a `tr` (so mode 1 — sites with
  no join at all — was never swept, which is GAP-6), and applying the one form
  universally would have **broken** two other criterion shapes. A repo-wide
  empirical sweep on 2026-08-04 (line-based count vs wrap-safe count, every
  un-joined `grep` site in this document, run against the real files) found
  **three** distinct shapes that need three different treatments:

  **(A) Anchored structural match** — a pattern beginning `^## `, `^### `, or
  otherwise anchored to a line boundary. **Stays line-based; must NEVER be
  joined.** A markdown heading cannot wrap by construction, and joining
  collapses the file to one line so `^` stops matching entirely. Measured:
  `grep -c '^## Reviewer roast-work advisory pass trigger' templates/persona-protocol.md`
  → **1** line-based, **0** joined, on a file that plainly contains the heading.

  **(B) Prose presence/absence match** — any unanchored multi-word phrase in a
  markdown or comment file. **Must join and squeeze:**

  ```
  … | tr '\n' ' ' | tr -s ' ' | grep -q '<phrase>'
  ```

  For a **recursive** sweep there is no `grep -r` equivalent, so it must become
  an explicit per-file loop (see Step 2 criteria 2 and 3 for the canonical
  form). This is where GAP-6 lived: `grep -rl` is line-based and cannot be
  made wrap-safe by any flag.

  **(C) Occurrence-count match** — anything asserting *how many* times a string
  appears. **`grep -c` counts matching LINES, not occurrences**, so after a join
  it can only ever return 0 or 1 — silently turning "expect 2" into an
  unsatisfiable assertion. Use `grep -o … | wc -l`, and join only when the
  pattern may wrap:

  ```
  n=$(tr '\n' ' ' < <file> | tr -s ' ' | grep -o '<phrase>' | wc -l)
  ```

  Measured for the one live case, `model: fable` in `agents/orchestrator.md`:
  4 lines / 4 occurrences / 4 wrap-safe occurrences — they agree today, so the
  line-based form is *currently* correct, but it is written in the (C) form
  anyway because Steps 1 and 2 both assert an exact count against prose the
  executor is about to rewrite.

  **Sweep results, 2026-08-04.** All 36 pre-existing join sites carry the
  squeeze (Revision 2). Of the 16 un-joined `grep` sites, 12 were verified safe
  (shape A, or a phrase measurably not spanning a wrap), and 4 were defective:
  Step 2 criteria 2 and 3 (GAP-6), plus the two count criteria re-expressed in
  shape (C). Every stated baseline in this document was re-verified against
  `git show e5b908f:<file>` under the shape appropriate to its criterion.
- **R-H — prior FAIL history on this surface.** `.claude/reviewed/` currently
  holds `.fail` records including `205.fail` and `222.fail`. Two of the units in
  scope here touch the same class of surface those FAILs came from (protocol
  prose propagation, and adapter-port parity). Per my own operating rule, steps
  2, 6 and 13 must **not** be tagged `haiku` by `task-master`; the recorded
  defect pattern is that presence-greps stayed green through two consecutive
  FAILs because the amendment never propagated to the mirror/adapter copies.
- **R-I — `fable` survives, on exactly one dispatch path. SUPERSEDED
  2026-08-06 by the operator's Step 1 correction.** Revisions 1–5 stated that
  Steps 1 + 2 leave `fable` dispatched nowhere; that is now **false**. After
  both steps, `agents/orchestrator.md` retains **two** `model: fable`
  occurrences: `milestone-auditor`'s **tier-2** slot (a live dispatch path, on
  a ≥8-unit judgment-signal-free milestone) and `task-master`'s hard
  **exclusion** guard (not a dispatch). What Steps 1 + 2 actually remove is
  fable from `spec-master`'s dispatch and from the reviewer's advisory pass.
  Step 7's CHANGELOG entry must say **that**, not "fable is retired" — the
  earlier phrasing would now be a false record.
- **R-J — Step 2 deletes one of Step 6's protected-rationale strings.** The
  `Downgrade/expiry path` paragraph lives *inside* the section Step 2 removes.
  Step 6's protected list is therefore **three** strings, not four, and Step 2
  must run **before** Step 6 or Step 6's criterion 7 is unsatisfiable. Found
  during finalization (CHK16), not present in the pre-ruling draft.
- **R-M — the template byte ceiling clears by only 387 bytes, and only after
  Step 2.** Measured 2026-08-06 by applying both edits to a copy:
  `templates/persona-protocol.md` is 19 185 B at `e5b908f` → **17 273 B** after
  Step 2 removes the roast section (−1 912) → **16 413 B** after Step 6a's
  compression (−860). Against the 16 800 B ceiling (this spec's Step 6
  criterion 11, and the same number in issue #245's Step 8) that is a **387-byte
  margin**.

  Two consequences worth stating rather than leaving to be discovered:
  1. **Step 6a alone leaves the template at 18 325 B — over the ceiling.** The
     ceiling clears only once Step 2 has also landed. This spec's dependency
     order (Step 2 → Step 6) and #235's `Depends on` line both already encode
     that, so the chain holds transitively; this note exists so the margin is
     not mistaken for slack.
  2. **Nothing later in Step 6 reduces this file** — 6b and 6c both edit
     `agents/orchestrator.md`. The 387 bytes are the whole of the headroom, so
     a materially longer 6a replacement than the supplied reference text can
     breach the ceiling. An executor deviating from that text should re-measure
     rather than assume.

- **R-K — Step 2 shrinks the same files Step 6 has byte ceilings on, which can
  make those ceilings vacuous.** Step 2 removes ~1 890 B from
  `templates/persona-protocol.md` and ~2 500 B from `agents/orchestrator.md`.
  The pre-ruling ceilings (≤26 000 B / ≤18 400 B) would have been satisfied by
  Steps 1–2 alone, proving nothing about Step 6's own compression. Step 6's
  aggregate ceilings are re-derived below against the post-Step-2 state
  (CHK17).
- **R-L — dangling cross-references.** Pass 2 recorded "dangling
  cross-references in trimmed persona bodies … confirmed present in four
  mirrors during #191" as a deferred defect class. Step 2 deletes a section that
  `agents/orchestrator.md` and `agents/task-master.md` both point at *by name*,
  so it carries an explicit repo-wide no-dangling-reference criterion rather
  than relying on the editor to notice.
- **Dependency order**: Step 1 → Step 2 (both edit the fable routing surface;
  Step 1's `model: fable` count criterion assumes Step 2 has not run yet) →
  Step 4 (same orchestrator section) → Step 6 (R-J, R-K: compresses what
  1/2/4 leave behind); Steps 1–6 → Step 7 (release); Steps 8–9 → Step 10;
  Steps 11–13 → Step 14; everything → Step 15. Step 3 is independent of all of
  these and may run in parallel.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every finding above was re-measured at
  `e5b908f` (reviewer-tier sweep over 60 commits, per-section byte counts,
  matrix and parity-test reads); two of the audit's claims (F3, F2's stated
  reason) did not survive and are corrected rather than carried.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no step
  hand-edits a mirror under `.claude/agents/`; every mirror change is produced
  by `node bin/cli.js --update` in a dedicated release unit, and asserted via
  `--update --check`'s exit code.
- P3 "Version-stamp discipline": satisfied — each of the three milestones ends
  with a release unit bumping `package.json` **and** `.claude-plugin/plugin.json`
  (both, or `tests/validate.sh`'s version-sync check FAILs) plus a CHANGELOG
  entry.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — Step 5 moves
  the scribe digest into lead-programmer's ready-for-review packet, which is
  emitted unconditionally, so a project with no scribe loses nothing; Step 9's
  fast path is explicitly conditioned on task-master's presence.
- P5 "`tests/validate.sh` is the merge gate": satisfied — it is an acceptance
  criterion on every step that edits a version-stamped file.

---

# Milestone 1 — the top five

## Step 1 (F1) — Dispatch-model routing: `spec-master` opus|sonnet, `milestone-auditor` fable|opus|sonnet

> **AMENDED 2026-08-06 by operator correction (Revision 6).** The original Step 1
> removed `fable` from **both** slots. The operator has since specified:
> `spec-master` → **opus or sonnet** (unchanged from the original fix);
> `milestone-auditor` → **fable, opus, or sonnet** — fable is *kept* and a new
> sonnet tier is *added*, giving three tiers instead of two. Treated as a full
> amendment, not a wording tweak: the heading, the change text, four of five
> acceptance criteria, and five downstream claims elsewhere in this spec all
> move. See "Ripple effects" at the end of this step.

**Scope confirmation the operator asked for, stated explicitly:** this
correction is scoped to **`milestone-auditor`'s tier structure only**.
`spec-master`'s own dispatch-model conditions (the orchestrator's choice of what
model to run `spec-master` *on* — a separate concept from spec-master's internal
recommendations) resolve to **opus default, sonnet when conditions (a)+(b)+(c)
hold, fable never**, exactly as the original F1 fix specified. No three-tier
treatment is applied to `spec-master`.

**Affected files**
- `agents/orchestrator.md` — § `### Opus|Fable routing for spec-master and
  milestone-auditor` (baseline lines 210–248): the heading, the `spec-master`
  dispatch paragraph (`:219`), the `milestone-auditor` dispatch paragraph
  (`:232-236`), and the § "Escalation symmetry" paragraph.

Do **not** touch: `agents/spec-master.md` / `agents/milestone-auditor.md`
frontmatter (`model: opus` stays the default in both), the § "task-master model
routing" fable exclusion (`:258`), or the § "Reviewer roast-work advisory pass"
fable dispatch (that is Step 2's).

**Change**

1. Rename the heading to
   `### Dispatch-model routing for spec-master and milestone-auditor` — the old
   name is wrong for both personas now, and "Opus|Sonnet" would be wrong for the
   auditor.
2. **`spec-master`**: the `model: fable` slot becomes `model: sonnet`;
   conditions (a) scope already enumerated, (b) rides existing seams, (c) no
   interrogation needed are unchanged. Fable is never valid for this persona.
3. **`milestone-auditor`**: replace the single fable condition with three
   **ordered, mutually exclusive** tiers. Evaluate top-down and stop at the
   first match:

   | Order | Tier | Condition |
   |---|---|---|
   | 1 | `opus` | **Any judgment signal** in the milestone: a `.fail` record for any unit in it, a human challenge at the step-9 pre-audit checkpoint, or a carried-in `unconverged-requirement` follow-up. |
   | 2 | `fable` | No judgment signal **and** the milestone is **large — ≥8 units**. Bulk context across many units is what the audit needs, which is the one property ADR-0004 documents fable as buying. |
   | 3 | `sonnet` | Everything else: no judgment signal, fewer than 8 units. |

   Frontmatter `model: opus` remains the default; omit the `model` parameter
   only when tier 1 applies.

4. **Escalation symmetry** now covers both personas: a `spec-master` sonnet
   dispatch that returns a plan the human rejects, or whose Open Questions
   reveal ambiguity misjudged as absent, re-dispatches on **opus**; a
   `milestone-auditor` fable *or* sonnet dispatch that misses a premise gap a
   human then catches re-dispatches on **opus**. Never the same cheap tier twice.

Keep the `CLAUDE_CODE_SUBAGENT_MODEL` caveat and the "a persona cannot tag its
own upcoming invocation" sentence.

**Why fable moved conditions rather than simply staying put.** F1's finding was
not "fable is bad" — it was that fable eligibility was **inverted**: it fired
exactly when the work was most mechanical, which is the case sonnet handles for
less. Keeping the *old* condition ("mechanical end-to-end") as the fable tier
and bolting sonnet on beneath it would preserve that inversion verbatim, leaving
the defect F1 exists to fix. Relocating fable to a **size** condition resolves
it: fable now fires where its one documented strength (ADR-0004: "large surface
coverage is exactly where fable's bulk-context strength comes into play")
actually applies, and sonnet takes the mechanical cases F1 identified.

**Why "≥8 units" and not a diff-size measure.** Measured over this repo's plan
history — 12 milestones at 2, 3, 3, 4, 5, 6, 6, 6, 7, 8, 10, 10 units — a ≥8
threshold fires on **3 of 12 (25 %)**, keeping the most expensive tier a genuine
minority. A cumulative-**diff** measure was considered and rejected: Step 2
deletes the per-unit "heavy" trigger (≥8 files / ≥400 lines) and retires "heavy"
as a term, so a diff-size condition here would reintroduce the concept this spec
removes. Unit count is milestone-scoped, countable without `git`, and is a
different metric from the deleted one — no collision.

**One simplification the amendment makes possible.** The old condition listed
"a `sonnet`/untagged unit" as a judgment signal alongside "a FAIL". Under
ADR-0010 (`agents/task-master.md` § "Per-unit model tag") tagging is now
**reactive only** — `haiku` is the default and `sonnet`/`opus` are reachable
only *after* something is on record, in practice a prior `.fail`. The
tag-based clause is therefore redundant with the `.fail` clause and is dropped
rather than carried forward as dead prose.

**Acceptance criteria** (baselines measured at `e5b908f`; counts re-verified
2026-08-06 for the amendment)
1. `n=$(grep -c '^### Dispatch-model routing for spec-master and milestone-auditor$' agents/orchestrator.md); test "$n" -eq 1` → exit 0. *(baseline: 0)*
2. **spec-master's sub-block carries no fable** (the half of F1 that is
   unchanged), asserted on that paragraph alone rather than the whole section,
   since the auditor's paragraph legitimately retains fable. **The sed patterns
   below carry no backticks** — a backtick inside a markdown code span breaks
   copy-paste and every extractor:
   `s=$(sed -n '/spec-master. dispatch/,/milestone-auditor. dispatch/p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); test "${#s}" -gt 400; n=$(printf '%s' "$s" | grep -oi 'fable' | wc -l); test "$n" -eq 0` → exit 0.
   **Baseline: extraction 847 bytes / 14 lines, `fable` occurrences = 3.**
   *(Uses `grep -o … | wc -l`, not `grep -c`: on a joined single-line stream
   `grep -c` returns 1 for "present" regardless of how many occurrences there
   are — R-G shape (C). My first draft of this criterion said "baseline 2" from
   a `grep -ci` that can only ever return 0 or 1; both the shape and the number
   were wrong.)*
3. **All three auditor tiers are present, with the two discriminators that do
   not already exist at baseline.** `fable`, `sonnet`, `opus` and
   `judgment signal` are *all* present in the current paragraph, so asserting
   them alone would be green before any work is done; `8 units` and
   `first match` are the clauses that carry the redness:
   `s=$(sed -n '/milestone-auditor. dispatch/,/^\*\*Escalation symmetry/p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); test "${#s}" -gt 300; for k in 'fable' 'sonnet' 'opus' '8 units' 'first match'; do printf '%s' "$s" | grep -qi -- "$k" || exit 1; done` → exit 0.
   **Baseline: RED** — measured presence at `e5b908f` is `fable`=1, `sonnet`=1,
   `opus`=1, `judgment signal`=1, but **`8 units`=0 and `first match`=0**.
4. **Occurrence count of `model: fable` in the file** — R-G shape (C), `grep -o … | wc -l` not `grep -c`:
   `n=$(tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | grep -o 'model: fable' | wc -l); test "$n" -eq 3` → exit 0. **Baseline: 4.** *(Amended from `-eq 2`. The three survivors are the milestone-auditor tier-2 slot, `task-master`'s hard exclusion, and the roast-pass dispatch; Step 2 then removes the roast-pass one, taking it to **2** — not 1 as Revision 5 stated.)*
5. `s=$(sed -n '/^### Dispatch-model routing/,/^### /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); printf '%s' "$s" | grep -q 'CLAUDE_CODE_SUBAGENT_MODEL'` → exit 0 (regression guard: the caveat survived the rewrite).
6. **The dropped tag-clause is really gone**, not left as dead prose:
   `s=$(sed -n '/milestone-auditor. dispatch/,/^\*\*Escalation symmetry/p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); n=$(printf '%s' "$s" | grep -oi 'untagged' | wc -l); test "$n" -eq 0` → exit 0. **Baseline: 1.**
7. **Change item 4 — the Escalation-symmetry paragraph — has its own criterion**
   (added in Revision 7; see the note below for why nothing covered it before).
   Extraction is **paragraph-scoped via a blank-line delimiter**, deliberately
   not the whole section: a `sed` range ending at the *following* paragraph
   would break when Step 4 rewrites that paragraph, and a section-wide match
   would re-introduce the over-broad problem Revision 6 fixed.
   ```
   e=$(awk 'index($0,"**Escalation symmetry")==1{f=1} f&&/^$/{exit} f' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ')
   test "${#e}" -gt 200
   n=$(printf '%s' "$e" | grep -oi 'fable-run spec-master' | wc -l); test "$n" -eq 0
   printf '%s' "$e" | grep -qi 'auditor'
   printf '%s' "$e" | grep -qi 'sonnet'
   ```
   → exit 0. **Baselines at `e5b908f`, all measured:** extraction = 343 bytes
   (anti-sentinel passes, so a mis-scoped `awk` cannot make this vacuous);
   `fable-run spec-master` = **1**; `auditor` = **0**; `sonnet` = **0**.
   Confirmed **RED** at baseline by execution.

   The three assertions map one-to-one onto what Change item 4 must accomplish:
   the phrase `a fable-run spec-master` must go (this step makes it impossible —
   spec-master loses fable eligibility entirely), the paragraph must start
   covering `milestone-auditor` (which it does not today), and it must name
   `sonnet` as the cheap tier that escalates.
8. `bash tests/validate.sh` → exit 0.

> **Why this was missing (GAP-12, found by `task-master` while applying
> Revision 6).** Revision 5's criterion 2 ran `grep -ci 'fable'` over the
> **whole section**, which covered this paragraph *incidentally*. Revision 6
> correctly narrowed that to the `spec-master` paragraph alone — because the
> auditor's paragraph now legitimately retains fable — and nothing replaced the
> coverage the narrowing dropped. Proven by simulation: a tree with Change items
> 1–3 applied and item 4's target text left byte-identical to `e5b908f` passed
> all six greppable criteria **and** the not-in-this-step control. The surviving
> text would then be actively wrong, reading "a fable-run spec-master" — a state
> this same step makes unreachable.
>
> **The general lesson, recorded because it is the second instance:** narrowing
> an over-broad criterion silently deletes whatever that criterion was covering
> by accident. Revision 3's GAP-6 was the same shape from the other direction
> (a rule with an unstated exception). When a criterion's scope shrinks, the
> delta must be re-covered explicitly, not assumed still covered.

**Not-in-this-step control**: `git diff --numstat -- .claude/agents/ templates/ bin/cli.js hooks/` produces no output.

**Ripple effects of this amendment, all corrected in this revision**
- **Step 2 criterion 4a**: expected `model: fable` count after Step 2 changes
  from **1 → 2**.
- **R-I**: "F1 + F2 together leave `fable` dispatched nowhere" is now **false**
  and is rewritten.
- **Step 12 (F10)**: its rejection rationale cited the fable→sonnet drop as the
  captured saving; that now holds only for milestones under 8 units. Narrowed,
  verdict unchanged — see Step 12.
- **Step 15 / ADR-0012**: the required line "`fable` is dispatched by no persona
  and no pass" is rewritten.
- **Scribe update hint**: "retirement of `fable` from *all* dispatch paths" is
  rewritten.

---

## Step 2 (F2) — Remove the separate fable roast-work advisory dispatch and the "heavy" concept

**Resolved by OQ1 = (b) remove.** This step is the *removal* variant, written
after the operator overrode spec-master's narrow-the-trigger recommendation. The
ADR-0004 tradeoff is documented in § Context and in Step 15's ADR — this is a
recorded decision, not an oversight.

Because the heavy trigger governed **only** the fable advisory pass, removing
the pass makes "heavy" dead. This step deletes the concept whole rather than
leaving an orphaned definition. It is the single sanctioned protocol-heading
removal in this spec (R-C), and it is large enough that `task-master` may
reasonably slice it into two units (2A: template + `bin/cli.js` + parity test +
adapter ports; 2B: `agents/` + `CONTEXT.md`), provided **both** land before
Step 6.

**Affected files** (all six groups are required; see R-C for why partial
completion breaks the build)
- `templates/persona-protocol.md` — delete § "Reviewer roast-work advisory pass
  trigger (fable heavy-lifting)" entirely, heading and all 32 lines (including
  its "Downgrade/expiry path" paragraph — see R-J).
- `bin/cli.js` — remove the heading string from all six
  `PROTOCOL_SECTIONS_BY_PERSONA` rows (`:535`, `:555`, `:568`, `:591`, `:602`,
  `:626`).
- `tests/adapter-protocol-parity.test.js` — remove the `ROAST` constant (`:28`),
  the `codexMap` entry, the `cursorMap` entry, and the dedicated
  `check('roast section is asserted PRESENT …')` block (`:122-127`).
- `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc` — remove the ported section.
- `agents/orchestrator.md` — three edits, all required:
  1. Delete § "### Reviewer roast-work advisory pass (fable heavy-lifting)" in
     full.
  2. In § "Reviewer gate model selection", delete the
     `**"Sonnet-eligible" and "heavy" are different concepts**` paragraph — its
     referent is gone.
  3. In the same section, edit the `**Fable is never valid on the gate.**`
     paragraph: its first two sentences are a standing guard and **stay**; its
     closing sentence ("Fable stays confined to the separate advisory
     `Roast pass: fable` dispatch above — unchanged") must go, because criterion
     3 drives that literal to zero repo-wide. *(Added 2026-08-04 — the first
     published version omitted this edit from the affected-files list while
     criterion 3 silently required it, and Step 4's control assumed the
     paragraph was untouched. See CHK21/CHK22.)*

  § "task-master model routing" — including the `model: fable` exclusion guard
  at `:258` — is **not** touched by this step; criterion 4b asserts it survived.
- `agents/task-master.md` — delete the `Roast pass: fable` tag bullet **and**
  the clause in the YAML frontmatter `description:` reading "(and, on heavy
  units, an advisory `Roast pass: fable` marker)".
- `CONTEXT.md` — delete the "Roast-work routing (fable heavy lifting)" glossary
  entry; in "Measured reviewer tier", drop the trailing contrast against
  "heavy"; in the "`roast-work` skill" entry, state it is now **inline-only**.

**Do NOT touch — this is what the removal is trading on, and it must survive:**
- `agents/reviewer.md` in any respect — its `skills: … antislop:roast-work`
  frontmatter, its "`roast-work` is advisory, never gating" bullet, and its
  one-advisory-section verdict-format bullet. ADR-0004 § Decision **Tension 1**
  is preserved in full; only **Tension 2** (model routing) is superseded.
- `skills/roast-work/SKILL.md`.
- `templates/persona-protocol-slim.md` (verified: does not carry this section).
- `agents/task-master.md`'s standing `model: fable` **exclusion** guard (R-I).

**Acceptance criteria**
1. The canonical section is gone:
   `n=$(grep -c '^## Reviewer roast-work advisory pass trigger' templates/persona-protocol.md || true); test "$n" -eq 0` → exit 0. *(baseline: 1)*
2. **No dangling cross-reference anywhere in the live control plane** (R-L) —
   `docs/` and `CHANGELOG.md` are historical and deliberately excluded. **A
   `grep -r` cannot be made wrap-safe by any flag** (R-G shape B), so this is an
   explicit per-file loop:
   ```
   n=0
   for f in $(find agents templates bin tests adapters -type f) CONTEXT.md; do
     tr '\n' ' ' < "$f" | tr -s ' ' | grep -q 'Reviewer roast-work advisory pass trigger' && n=$((n+1))
   done
   test "$n" -eq 0
   ```
   → exit 0. **Baseline: 7 files** — `agents/orchestrator.md`,
   `agents/task-master.md`, `templates/persona-protocol.md`, `bin/cli.js`,
   `tests/adapter-protocol-parity.test.js`,
   `adapters/codex/agents-md-fragment.md`,
   `adapters/cursor/rules/persona-protocol.mdc`. *(Re-measured 2026-08-04. The
   Revision-1/2 form used `grep -rl` and found only **5**, missing
   `agents/orchestrator.md:285-286` and `agents/task-master.md:55-56`, where the
   phrase wraps across a 2-space-indented continuation. The stated baseline of
   "6 files" matched neither number.)*
3. Same shape, same reason:
   ```
   n=0
   for f in $(find agents templates bin tests adapters -type f) CONTEXT.md; do
     tr '\n' ' ' < "$f" | tr -s ' ' | grep -q 'Roast pass: fable' && n=$((n+1))
   done
   test "$n" -eq 0
   ```
   → exit 0. **Baseline: 4 files** — `agents/orchestrator.md`,
   `agents/task-master.md`, `CONTEXT.md`, **and
   `templates/persona-protocol.md`** (`:297-298`, wrapped as `Roast` /
   `pass: fable`). *(Re-measured 2026-08-04. The Revision-1/2 form found 3 and
   its named file list omitted the template entirely — the single most important
   file for this criterion, since the template is where the deleted section
   lives.)*

   > **Why these two criteria being blind mattered.** They are the *sole*
   > coverage for dangling references to the deleted "heavy unit" concept, and
   > the two files they were blind to — `agents/orchestrator.md` and
   > `templates/persona-protocol.md` — are exactly the two most likely to retain
   > one. Under the Revision-2 text an executor could have left the
   > orchestrator's trailing `**Trigger — see …**` paragraph in place and passed
   > every stated criterion. Found by `task-master` as GAP-6.
4. Fable survives only where it is meant to; the roast-pass dispatch is gone:
   - **4a.** `n=$(tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | grep -o 'model: fable' | wc -l); test "$n" -eq 2` → exit 0. **R-G shape (C)** — `grep -c` counts matching *lines*, so it caps at 1 on a joined stream and would make any "expect ≥2" assertion unsatisfiable; `grep -o … | wc -l` counts occurrences. Measured at `e5b908f`: 4 occurrences. *(**Amended 2026-08-06 from `-eq 1`.** After Step 1 the count is **3**, not 2, because the operator's correction keeps a `model: fable` slot for `milestone-auditor`. Step 2 removes only the roast-pass occurrence, leaving **2**: the auditor's tier-2 slot and `task-master`'s exclusion guard.)*
   - **4b.** The guard survived, checked **where it actually lives** —
     `agents/orchestrator.md` § "task-master model routing" (`:258` at
     `e5b908f`), **not** `agents/task-master.md`:
     `sed -n '/^### task-master model routing/,/^### /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -q 'is excluded for'` → exit 0. *(baseline: exit 0 — this is a survival guard on a deliberate non-deletion, green at baseline by design; 4a is what proves the step did its work. The match string deliberately carries no backticks, so the criterion survives copy-paste out of this markdown.)*

   > **Corrected 2026-08-04.** The first published version checked
   > `agents/task-master.md` for the string `excluded`, which **never occurs in
   > that file** — and every `fable` occurrence there (`:3`, `:54-61`) is
   > deleted by this same step, so the criterion was unsatisfiable. Step 1's
   > "Do not touch" list already pointed at `agents/orchestrator.md`; the two
   > steps disagreed. `agents/orchestrator.md` is correct.
5. **`bin/cli.js` still loads** — this is the criterion that catches a
   partially-completed matrix edit, because the assertion runs at module load:
   `node bin/cli.js --update --check` → exit 0. *(With any one of the six rows left un-edited this exits non-zero with "names sections absent from templates/persona-protocol.md".)*
6. `node tests/adapter-protocol-parity.test.js` → exit 0. *(Catches a stale `codexMap`/`cursorMap` key just as loudly as a missing one.)*
7. **Anti-scope-creep control — the inline roast pass is untouched**:
   `git diff --numstat -- agents/reviewer.md skills/roast-work/ templates/persona-protocol-slim.md` produces no output, AND
   `grep -q 'antislop:roast-work' agents/reviewer.md` → exit 0, AND
   `tr '\n' ' ' < agents/reviewer.md | tr -s ' ' | grep -q 'advisory, never gating'` → exit 0.
8. `bash tests/validate.sh` → exit 0 (its frontmatter check covers the edited
   `agents/task-master.md` `description:`).

**Mutation control** (required, per `differential-tests-need-effects` — a
repo-wide negative grep is green forever if mis-pathed): restore the heading
line alone into `templates/persona-protocol.md` and show that criterion 1 fails
with `n` = 1 **and** criterion 5 fails (the six now-missing matrix rows make
`bin/cli.js` unloadable in the opposite direction). Demonstrate both in the
ready-for-review packet.

**Model tag guidance for `task-master`**: not `haiku`. Per R-H, this surface has
a recorded two-FAIL history in which presence-greps stayed green because an
amendment never propagated to the mirror and adapter copies — which is exactly
this step's failure mode.

---

## Step 3 (F3 + the ADR-0004 contradiction) — Record the re-measurement; change no threshold

**Resolved by OQ2 = (a) no threshold change.** `hooks/scripts/reviewer-tier.sh`
is not edited; this step is record-only. Criterion 5 is therefore the
load-bearing one — it is what makes "we deliberately changed nothing" checkable
rather than merely asserted.

**Affected files**
- `docs/adr/0009-reviewer-tier-measured-eligibility.md` — append a dated
  "2026-08-03 re-measurement" subsection under § Consequences (append-only; the
  Decision is untouched).
- `docs/adr/0004-reviewer-roast-work-dual-model-routing.md` — § Related gains a
  back-pointer noting that its "cheap relative to opus" cost claim is
  superseded by `templates/persona-protocol.md`'s "single most expensive model
  tier" (ADRs are historical records — back-pointer, never a rewrite; this
  mirrors how ADR-0006 received its ADR-0009 pointer).
- `CONTEXT.md` — the "Measured reviewer tier" glossary entry gains the
  re-measured figure.
- `hooks/scripts/reviewer-tier.sh` — **unchanged** unless OQ2 says otherwise.

**Acceptance criteria**
1. `n=$(tr '\n' ' ' < docs/adr/0009-reviewer-tier-measured-eligibility.md | tr -s ' ' | grep -o '2026-08-03 re-measurement' | wc -l); test "$n" -eq 1` → exit 0. **Baseline: 0** *(R-G shape (C) — the executor writes this heading text, and it may wrap wherever their editor puts it)*.
2. `tr '\n' ' ' < docs/adr/0009-reviewer-tier-measured-eligibility.md | tr -s ' ' | grep -q '8 of the last 60'` → exit 0. *(baseline: exits 1)*
3. `tr '\n' ' ' < docs/adr/0004-reviewer-roast-work-dual-model-routing.md | tr -s ' ' | grep -q 'single most expensive model tier'` → exit 0. *(baseline: exits 1)*
4. Anti-regression — ADR-0004's and ADR-0009's Decision sections are byte-identical to baseline:
   `for f in docs/adr/0004-reviewer-roast-work-dual-model-routing.md docs/adr/0009-reviewer-tier-measured-eligibility.md; do diff <(git show e5b908f:"$f" | sed -n '/^## Decision/,/^## /p') <(sed -n '/^## Decision/,/^## /p' "$f") || exit 1; done` → exit 0.
5. The threshold is deliberately unchanged: `git diff --numstat -- hooks/scripts/reviewer-tier.sh` produces no output, AND `grep -q 'MAX_CHANGED_LINES=40' hooks/scripts/reviewer-tier.sh`, AND `grep -q 'MAX_CHANGED_FILES=3' hooks/scripts/reviewer-tier.sh` → all exit 0.
6. `bash tests/reviewer-tier.test.sh` → exit 0.
7. `bash tests/validate.sh` → exit 0.

---

## Step 4 (F4) — Expire the implementer-side `.fail` ratchets on a subsequent PASS

**Affected files**
- `agents/orchestrator.md` — § "Per-unit model routing", specifically the
  "Haiku units escalate on first FAIL" paragraph (R4), the "Check for a prior
  `.fail` record before ANY per-unit dispatch" paragraph, and the "A prior
  `.fail` record is an automatic disqualifier" paragraph (R3 — rewritten to
  scope to the *specific* failing unit, and to expire).
- `agents/task-master.md` — § "Per-unit model tag", the "never tag that unit
  `haiku`" clause gains the same expiry condition.

Do **not** touch (recommended default; see OQ3): `hooks/scripts/reviewer-tier.sh`,
`agents/orchestrator.md` § "Reviewer gate model selection" and its `.fail`
disqualifier, or § "Escalation". R2 stays permanent — ADR-0006 § Consequences
depends on it.

**Change — the expiry rule, stated once and referenced twice**: a `.fail`
record for unit `X` stops disqualifying `X` from a cheaper *implementer* tier
once a `.pass` marker for `X` exists **and is newer than** the `.fail` record
(i.e. the unit was subsequently fixed and independently verified). Until then it
disqualifies unchanged. The disqualification applies to unit `X` **only** —
never to sibling units that a spec or audit merely touches. The
**within-ladder** case is explicitly excluded: while a unit is mid-retry and has
not yet reached PASS, nothing expires.

**Acceptance criteria**
1. Anti-sentinel + positive, wrap-safe:
   `s=$(sed -n '/^## Per-unit model routing/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); test "${#s}" -gt 2000; printf '%s' "$s" | grep -q 'newer than'` → exit 0. *(baseline: the `grep` exits 1)*
2. The expiry is stated as conditional on an independently-verified PASS:
   `sed -n '/^## Per-unit model routing/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -Eq 'pass marker.*newer than.*fail|reviewed/[^ ]*\.pass.*newer'` → exit 0.
3. The within-ladder exclusion is explicit:
   `sed -n '/^## Per-unit model routing/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -q 'nothing expires'` → exit 0. *(baseline: exits 1)*
4. R3 is scoped to the failing unit — the old cross-unit phrasing is gone:
   `n=$(sed -n '/^## Per-unit model routing/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -c 'among the units a' || true); test "$n" -eq 0` → exit 0. *(baseline: 1)*
5. task-master carries the same expiry:
   `sed -n '/Per-unit model tag/,/Roast pass: fable/p' agents/task-master.md | tr '\n' ' ' | tr -s ' ' | grep -q 'newer than'` → exit 0. *(baseline: exits 1)*
6. **Anti-regression control — the reviewer gate was NOT loosened.** Three
   parts; 6c is **paragraph-scoped, not section-scoped** (see the correction
   note below):
   - **6a.** `git diff --numstat -- hooks/scripts/reviewer-tier.sh` produces no output.
   - **6b.** `bash tests/reviewer-tier.test.sh` → exit 0.
   - **6c.** The three safety paragraphs of § "Reviewer gate model selection"
     that Step 2 provably does not touch are byte-identical to `e5b908f`.
     Extract each by its bold lead and diff:
     ```
     for lead in 'Downgrade-only asymmetry' '`.fail` disqualifier' 'Escalation.'; do
       diff <(git show e5b908f:agents/orchestrator.md | awk -v L="$lead" 'index($0,"**"L)==1{f=1} f&&/^$/{if(n++)exit} f') \
            <(awk -v L="$lead" 'index($0,"**"L)==1{f=1} f&&/^$/{if(n++)exit} f' agents/orchestrator.md) || exit 1
     done
     ```
     → exit 0. *(The executor may substitute any extraction that isolates the
     same three paragraphs; what is pinned is their content, not the awk.)*

   > **Corrected 2026-08-04.** The first published version required the
   > **whole** section to be byte-identical to `e5b908f`. That is unsatisfiable
   > under this spec's own mandated ordering: Step 2 lands first and edits the
   > same section twice — it deletes the `**"Sonnet-eligible" and "heavy" are
   > different concepts**` paragraph (its referent is gone), and its criterion 3
   > independently forces the closing `Fable is never valid on the gate`
   > paragraph to change, because that paragraph contains the literal
   > `Roast pass: fable` which criterion 3 drives to zero repo-wide. Verified
   > at `e5b908f`: both strings are present inside this section.
   >
   > Scoping to the three untouched paragraphs preserves exactly what this
   > control exists to protect — the downgrade-only asymmetry, the `.fail`
   > disqualifier, and the escalation path (ADR-0006 / ADR-0009's safety
   > invariants) — while letting Step 2's sanctioned edits through.
   > My CHK2/CHK3 certified this pair as PASS and missed it: both items asked
   > whether the steps *agreed about which ratchets survive*, and neither asked
   > whether Step 4's criterion was still **satisfiable** after Step 2 ran. See
   > CHK22.
7. `bash tests/validate.sh` → exit 0.

---

## Step 5 (F5) — Collapse the two scribe dispatches into one post-PASS dispatch

**Affected files**
- `agents/lead-programmer.md` — delete the § "Scribe updates (batched,
  blocking-but-brief)" bullet (baseline lines 43–49); extend the "Don't grade
  your own work" bullet's advisory review packet to carry the **scribe digest**
  (affected files, changed APIs, new conventions) as a named element.
- `agents/orchestrator.md` — § "Scribe dispatch convention": state that the
  single scribe dispatch happens **after** the reviewer's PASS and carries the
  lead's digest **plus** the issue number **plus** the task-id; § "Default
  feature pipeline": remove "(which updates the scribe itself)".

Do **not** touch: `agents/scribe.md` (its § "Issue closing" four conditions are
unchanged and still fire on the same inputs).

**Acceptance criteria**
1. The lead's blocking scribe spawn is gone:
   `n=$(tr '\n' ' ' < agents/lead-programmer.md | tr -s ' ' | grep -c 'Scribe updates (batched' || true); test "$n" -eq 0` → exit 0. **Baseline: 1** *(verified identical line-based and wrap-safe at `e5b908f`; joined anyway per R-G shape (B), since a deletion check that silently matches nothing is exactly the Gap-3 failure)*.
2. `n=$(tr '\n' ' ' < agents/lead-programmer.md | tr -s ' ' | grep -c 'spawning it pauses you until it' || true); test "$n" -eq 0` → exit 0. *(baseline: 1)*
3. The digest survived, in the packet:
   `tr '\n' ' ' < agents/lead-programmer.md | tr -s ' ' | grep -q 'scribe digest'` → exit 0. *(baseline: exits 1)*
4. Anti-sentinel + the packet is still intact:
   `tr '\n' ' ' < agents/lead-programmer.md | tr -s ' ' | grep -q 'advisory review packet'` → exit 0.
5. The orchestrator's single dispatch is post-PASS and three-part:
   `s=$(sed -n '/^## Scribe dispatch convention/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); test "${#s}" -gt 300; printf '%s' "$s" | grep -q 'digest'; printf '%s' "$s" | grep -qi 'after the reviewer'` → exit 0. *(baseline: both greps exit 1)*
6. `n=$(sed -n '/^## Default feature pipeline/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -c 'which updates the scribe itself' || true); test "$n" -eq 0` → exit 0. **Baseline: 1** *(re-measured 2026-08-04 under the corrected join)*.
   Paired anti-sentinel, so a mis-pathed `sed` cannot make this pass by
   returning nothing: `sed -n '/^## Default feature pipeline/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -q 'Explore'` → exit 0.

   > **Corrected 2026-08-04.** The first published version ran a bare
   > single-line `grep -c 'which updates the scribe itself'`, which returns
   > **0** at `e5b908f`, not the 1 the spec claimed — the phrase wraps as
   > `(which` / `updates the scribe itself)` across
   > `agents/orchestrator.md:173-174`. As the sole coverage for this edit the
   > criterion could neither meaningfully pass nor fail. R-G failure mode 1.
7. Graceful degradation preserved (constitution P4): `bash tests/validate.sh` → exit 0 (its "optional-persona references must be phrased conditionally" check covers `scribe`).

---

## Step 6 (F8) — Compress always-on prose to stated ceilings, preserving guard rationale

**Resolved by OQ5 = (a) accept the proposed ceilings.** Sub-steps are
independently gradable and may be sliced into three units by `task-master`.

**Two finalization corrections forced by OQ1's removal ruling** (neither was in
the pre-ruling draft):
- **The protected list is now THREE strings, not four** (R-J). The
  `Downgrade/expiry path` paragraph lived inside the section Step 2 deletes, so
  pinning it here would make criterion 7 unsatisfiable. **Step 2 must land
  before this step.**
- **The aggregate ceilings are re-derived against the post-Step-2 state**
  (R-K). Step 2 alone removes ~1 890 B from the template and ~2 500 B from
  `agents/orchestrator.md`; the pre-ruling ceilings would have been satisfied by
  Steps 1–2 without this step compressing anything at all.

**Affected files**
- 6a: `templates/persona-protocol.md` § "Agent-teams mode (only relevant if you
  were spawned as a teammate)" **and** `templates/persona-protocol-slim.md`
  (byte-identical copy of the same section — verified 2026-08-04 via `diff`;
  one replacement text serves both). **Exactly two files.**

  > **Corrected 2026-08-04 (GAP-7).** The first three revisions also listed
  > `adapters/codex/agents-md-fragment.md` and
  > `adapters/cursor/rules/persona-protocol.mdc`. **Neither adapter carries an
  > Agent-teams section at all** — both explicitly record it as dropped
  > (`adapters/codex/agents-md-fragment.md:179` "Dropped for v1 (no Codex
  > equivalent shipped yet): agent-teams mode";
  > `adapters/cursor/rules/persona-protocol.mdc:171` "Dropped for v1 (no Cursor
  > equivalent): agent-teams mode"), and
  > `tests/adapter-protocol-parity.test.js` maps the section as `deferred` for
  > both ports rather than `probe`. `task-master` sliced my list faithfully into
  > a #235 criterion demanding a non-zero diff in each port, which is
  > unsatisfiable without a cosmetic edit. Found by the `spec-master` run on
  > issue #245 during a file-overlap check between the two specs.
- 6b: `agents/orchestrator.md` § "Managing a long-running background dispatch".
- 6c: `agents/orchestrator.md` § "Per-unit model routing" (after Steps 1 and 4
  have landed).

Do **not** touch: any `## ` heading text (R-C), `bin/cli.js`'s
`UNIVERSAL_PROTOCOL_CORE` or `PROTOCOL_SECTIONS_BY_PERSONA`, or any of the
**protected rationale** strings listed below.

**Protected rationale — must survive verbatim.** These exist specifically to
stop a future editor "fixing" the mechanism away, and are explicitly out of
scope for compression:
- `templates/persona-protocol.md` § "Terminal status line" — the paragraph
  beginning `**Why it exists** (stated as fact, so nobody later "fixes" it with
  a hook)` and its `zero content blocks` sentence.
- `hooks/scripts/reviewer-tier.sh` header — `NOT A HOOK` and `the missing
  registration is the design`.
- `agents/orchestrator.md` § "Reviewer gate model selection" — the
  `never upgrade` / downgrade-only asymmetry rationale.

*(The fourth string in the pre-ruling draft — `Downgrade/expiry path` — is
deliberately absent: Step 2 deletes the section containing it. See R-J.)*

**Change**: rules-only rewriting. Each retained rule keeps its imperative;
multi-paragraph explanation of *why* a rule exists is dropped **only** where the
rule is self-enforcing and the explanation is not a regression guard.

**Acceptance criteria**
1. 6a ceiling, **asserted on BOTH tiers** — a criterion naming only the full
   protocol would let the slim tier ship the old 20-line text and still pass:
   `for f in templates/persona-protocol.md templates/persona-protocol-slim.md; do test "$(sed -n '/^## Agent-teams mode/,/^## /p' "$f" | sed '$d' | wc -l)" -le 8 || exit 1; done` → exit 0. *(baseline: **20 in each**)*
2. 6a keeps the load-bearing facts, **on both tiers** (the three rules a
   teammate cannot derive):
   `for f in templates/persona-protocol.md templates/persona-protocol-slim.md; do s=$(sed -n '/^## Agent-teams mode/,/^## /p' "$f" | tr '\n' ' ' | tr -s ' '); printf '%s' "$s" | grep -q 'NOT applied' || exit 1; printf '%s' "$s" | grep -q 'SendMessage' || exit 1; printf '%s' "$s" | grep -qi 'nested' || exit 1; done` → exit 0.

   > **Corrected 2026-08-04 (GAP-8, found while fixing GAP-7).**
   > `templates/persona-protocol-slim.md` was an affected file of 6a with **no
   > criterion of any kind** — criteria 1 and 2 both named only
   > `templates/persona-protocol.md`. An executor could have compressed the full
   > tier, left the slim tier at 20 lines carrying the superseded text, and
   > passed every criterion. The two sections are byte-identical at `e5b908f`,
   > so this is a coverage gap, not extra work.

2b. **Cross-spec compatibility — the compressed text must satisfy issue #245's
   Step 8 as well**, so #235 does not land and immediately need a second edit.
   Asserted on **both tiers**:
   `for f in templates/persona-protocol.md templates/persona-protocol-slim.md; do s=$(tr '\n' ' ' < "$f" | tr -s ' '); printf '%s' "$s" | grep -q 'disable-model-invocation' || exit 1; n=$(printf '%s' "$s" | grep -c 'in your tools list' || true); test "$n" -eq 0 || exit 1; done` → exit 0.
   **Baselines, wrap-safe:** `disable-model-invocation` = **0** in each;
   `in your tools list` = **1** in each *(it wraps across `:48-49`, so a
   line-based `grep -c` reports 0 — see the note under "Coordination with issue
   #245" below)*.

**What criterion 1 actually counts — read this before writing the replacement.**
`sed -n '/^## Agent-teams mode/,/^## /p' … | sed '$d'` prints the heading, the
body, **and the mandatory blank separator line before the next `## ` heading**.
The baseline of 20 is therefore 19 content lines + 1 blank. **A ceiling of ≤8
means ≤7 content lines**, heading included. This is stated explicitly because
Revision 4 supplied an 8-content-line text that measured **9** and failed its
own criterion.

**Reference text for 6a (non-binding — the criteria above are what bind).**
Merges this spec's compression goal with #245 Step 8's supplied correction.
**Verified by substituting it into both real template files and re-running the
actual criteria**, not by counting the snippet: criterion 1 → **8** (≤8, PASS)
on both tiers; criteria 2 and 2b PASS on both tiers; longest line 76 columns, so
it respects the templates' existing wrap width.

```
## Agent-teams mode (only relevant if you were spawned as a teammate)
- `skills:`/`mcpServers:` frontmatter is NOT applied to a teammate; a skill
  marked `disable-model-invocation` is unreachable in any mode — read its
  `SKILL.md` directly, or ask the explorer via `SendMessage`.
- You CAN spawn foreground subagents; only nested TEAMS are barred.
- `SendMessage` is async, a spawned subagent blocks; report finished work by
  `SendMessage` to the name the lead spawned you under, never turn-text.
```

> **GAP-10 resolution (2026-08-04) — option (a) of the three offered, with the
> reasons the other two were rejected.**
>
> - **Chosen: shed content to 7 lines.** Preserves the ceiling exactly as the
>   operator ruled it in OQ5 and keeps every binding criterion of both specs.
>   The bullet merged was #245's "async vs blocking" and this spec's "report to
>   the lead" — they share a subject (`SendMessage` semantics) so the merge
>   loses no rule.
> - **Rejected: drop the blank-separator convention.** The blank line before a
>   `## ` heading is uniform across both templates and is the input shape
>   `bin/cli.js`'s `parseProtocolSections` reads. Changing it for one section
>   creates an inconsistency in a parser-visible format to win one line.
> - **Rejected: restate the ceiling as ≤9.** OQ5's ruling was "20 → ≤8", stated
>   against this exact command whose baseline is 20. Relaxing it to ≤9 would
>   change an operator-approved number without asking, to accommodate my own
>   drafting error. The measurement was not miscalibrated — my reading of it
>   was, which the note above now fixes permanently.
>
> Content deliberately dropped to reach 7 lines: the parenthetical examples
> ("e.g. explorer needs code-review-graph", "e.g. the explorer"), the
> "don't fall back to Grep/Glob" elaboration, and the `"main"` literal caveat.
> `idle_notification` is folded into "never turn-text". No **rule** is lost —
> all four facts and all four pinned strings survive, verified above.

   > #245's Step 8 supplied only the first bullet. Pasted alone it would **fail
   > this spec's criterion 2**, which pins `nested` as load-bearing: the
   > "you CAN still spawn ordinary foreground subagents, only nested TEAMS are
   > barred" rule exists to stop a teammate falling back to Grep/Glob. The
   > reference text above keeps it.
3. 6b ceiling: `sed -n '/^## Managing a long-running background dispatch/,/^## /p' agents/orchestrator.md | sed '$d' | wc -l` → ≤ 28. *(baseline: 64)*
4. 6b keeps the four-state resolution table:
   `s=$(sed -n '/^## Managing a long-running background dispatch/,/^## /p' agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); for k in 'Still running' 'Finished' 'Killed' 'Cut off'; do printf '%s' "$s" | grep -q "$k" || exit 1; done` → exit 0.
5. 6c ceiling: `sed -n '/^## Per-unit model routing/,/^## /p' agents/orchestrator.md | sed '$d' | wc -l` → ≤ 110. *(baseline: 192)*
6. 6c de-duplication is real, not cosmetic:
   `c=$(sed -n '/^## Per-unit model routing/,/^## /p' agents/orchestrator.md | grep -c 'CLAUDE_CODE_SUBAGENT_MODEL' || true); test "$c" -eq 1` → exit 0. *(baseline: 3)*
7. **Every protected string survives** — three strings, run as one command, exit 0:
   `tr '\n' ' ' < templates/persona-protocol.md | tr -s ' ' | grep -q 'stated as fact, so nobody later' && tr '\n' ' ' < templates/persona-protocol.md | tr -s ' ' | grep -q 'zero content blocks' && grep -q 'NOT A HOOK' hooks/scripts/reviewer-tier.sh && grep -q 'the missing registration is the design' hooks/scripts/reviewer-tier.sh && tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | grep -q 'never upgrade'`
8. `node bin/cli.js --update --check` → exit 0 (proves the matrix still partitions the template — R-C).
9. `node tests/adapter-protocol-parity.test.js` → exit 0. This is the **only**
   adapter-facing criterion for 6a, and it is a *non-regression* check, not a
   change requirement: the section stays mapped `deferred` in both ports and
   both ports are expected to be **untouched**.
9b. **Anti-scope-creep control — 6a must NOT touch either adapter port**
   (replaces the removed non-zero-diff requirement; see GAP-7):
   `git diff --numstat -- adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc` produces no output.
   A cosmetic edit made purely to satisfy a diff requirement is itself the
   defect this control now forbids.
10. `bash tests/validate.sh` → exit 0.
11. **Aggregate effect, measured against the post-Step-2 state** (R-K — these
    ceilings are *not* reachable by Steps 1–2 alone):
    `agents/orchestrator.md` ≤ **23 500 B** *(e5b908f baseline 30 839; ~28 200 expected after Steps 1+2+4, so this step must remove ≥4 700 B of its own)* and
    `templates/persona-protocol.md` ≤ **16 800 B** *(baseline 19 185; ~17 295 after Step 2, so this step must remove ≥495 B of its own)*.

**Mutation control**: reverting 6c's `CLAUDE_CODE_SUBAGENT_MODEL` de-duplication
alone must make criterion 6 fail with `c` = 3 **and** criterion 11's
orchestrator ceiling fail. Demonstrate both in the ready-for-review packet —
a byte ceiling that the preceding steps already satisfy proves nothing.

---

## Step 7 — Milestone 1 release: version bump, mirror regeneration, CHANGELOG

**Affected files**: `package.json`, `.claude-plugin/plugin.json`, `CHANGELOG.md`,
`.claude/agents/*.md` (all 9), `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/persona-config.json` (R-B).

**Change**: bump both manifests to the same new minor version; run `node
bin/cli.js --update --check` (which **writes** — R-A); commit the full
regenerated output; add a CHANGELOG entry naming F1, F2, F4, F5, F8 and, if
OQ1 resolved to removal, the fact that `fable` is no longer dispatched anywhere
(R-I).

**Acceptance criteria**
1. Both manifests agree — this is what `tests/validate.sh` checks and what a
   single-manifest bump silently fails:
   `test "$(node -p "require('./package.json').version")" = "$(node -p "require('./.claude-plugin/plugin.json').version")"` → exit 0, and the value differs from `0.22.0`.
2. `node bin/cli.js --update --check` → **exit 0**, and its stdout contains a
   per-file summary line for `.claude/agents/orchestrator.md` (this line is
   emitted only after the render loop actually reached that spec — mtime is
   **not** valid evidence).
3. Mirrors are regenerated, not hand-edited: after criterion 2 runs,
   `git status --porcelain -- .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/persona-config.json` produces no output (everything staged/committed), AND a second `node bin/cli.js --update --check` still exits 0.
4. Every mirror's stamp names the new version:
   `v=$(node -p "require('./package.json').version"); for f in .claude/agents/*.md; do grep -q "antislop v$v " "$f" || exit 1; done` → exit 0.
5. `grep -c "^## \[$(node -p "require('./package.json').version")\]" CHANGELOG.md` → ≥ 1 (adjust the heading pattern to CHANGELOG.md's actual convention, pinned by the executor from the existing 0.22.0 entry).
6. `bash tests/validate.sh` → exit 0.

---

# Milestone 2 — F6, F7

## Step 8 (F6) — Make spec-master's ceremony conditional on measured ambiguity, keep the load-bearing parts mandatory

*(Deliberately avoids the word "heavy" — Step 2 retires that term as a
trigger name, and reusing it here for "burdensome ceremony" would re-introduce
the terminology collision this spec is cleaning up.)*

**Affected files**: `agents/spec-master.md` only.

**Stays MANDATORY, unconditionally** (do not weaken):
- Machine-checkable acceptance criteria per step (shared-protocol rule).
- The finalized spec exists before any dispatch; the `docs/plans/` document
  remains the canonical artifact.
- The 9-line taxonomy **scorecard**. Rationale for deviating from the audit's
  wording here: the scorecard is what *produces* the Partial/Missing scoring
  that everything else is conditioned on, so it cannot be conditioned on its own
  output. It costs ~200 bytes.
- Open Questions, and the rule that a multi-interpretation choice is never made
  silently.
- The Constitution check, when `.claude/constitution.md` exists.

**Becomes CONDITIONAL**:
- **Dated `Q … → A …` lines**: required only for categories scored **Partial or
  Missing**. A category scored Clear needs no line. (Today every category needs
  one, including self-resolved Clear ones.)
- **Itemized `CHKn` self-check**: required when the plan has ≥3 steps **OR** any
  category scored Partial/Missing. Below that, a minimum of 3 items still
  applies — the section never disappears entirely, because a FAIL with no
  matching Open Question is the defect it exists to catch.
- **`to-spec` tracker publication**: required for multi-milestone specs and any
  spec resolving to ≥3 units; opt-in below that.

**Acceptance criteria**
1. Anti-sentinel: `wc -l agents/spec-master.md` → ≥ 150.
2. The scorecard stays mandatory:
   `tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -q '9-line scorecard'` → exit 0.
3. Dated lines are conditioned:
   `tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -Eq 'dated line.{0,120}(Partial|Missing)'` → exit 0. *(baseline: exits 1)*
4. The old unconditional phrasing is gone:
   `n=$(tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -c 'even when nothing was Missing' || true); test "$n" -eq 0` → exit 0. **Baseline: 1 under the corrected join** *(re-measured 2026-08-04; it was **0** under the broken join the first version specced, which made this criterion vacuous)*.

   > **Corrected 2026-08-04.** Two defects in one line. (i) The redirect was
   > mis-ordered — `tr '\n' ' ' < file` | tr -s ' ' feeds the file to the
   > *second* `tr`, leaving the first reading stdin; the form must be
   > `tr '\n' ' ' < file | tr -s ' '` (or `cat file | …`). (ii) Without the
   > squeeze the phrase never matched, because it wraps into a 2-space-indented
   > continuation line producing `even<3 spaces>when`. R-G failure mode 2, and
   > the instance that exposed the whole class.
5. CHKn is conditioned but floored:
   `s=$(tr '\n' ' ' < agents/spec-master.md | tr -s ' '); printf '%s' "$s" | grep -q 'minimum of 3 items'; printf '%s' "$s" | grep -Eq '(three|3) steps|≥3 steps'` → exit 0.
6. `to-spec` is opt-in below the threshold:
   `tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -Eq 'to-spec.{0,160}(opt-in|optional)'` → exit 0. *(baseline: exits 1)*
7. Machine-checkable criteria stayed mandatory (anti-regression):
   `tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -q 'machine-checkable-criteria rule'` → exit 0.
8. `bash tests/validate.sh` → exit 0.

---

## Step 9 (F7) — ≤2-unit fast path: spec-master emits dispatch contracts directly

**Affected files**
- `agents/orchestrator.md` — routing table entry for "Planning a non-trivial
  change", and § "Default feature pipeline".
- `agents/task-master.md` — the scope statement in the body's opening paragraph
  and § "Input", stating when task-master is mandatory.
- `agents/spec-master.md` — § "Hand off to `task-master`" gains the fast-path
  exception and the nine-element contract requirement.
- `docs/adr/0003-hivemind-split-spec-master-task-master.md` — § Related gains a
  back-pointer (append-only; the Decision is untouched).

**The rule, stated identically in all three persona files**: when a finalized
spec resolves to **≤2 dispatchable units**, spec-master emits the nine-element
dispatch contract for each unit directly and the orchestrator dispatches from
the `docs/plans/` document. **task-master remains mandatory** for: ≥3 units,
any debug-spec re-derivation, and any `## Convergence follow-ups` slice.
spec-master still does **not** run `to-tickets` and does **not** file tracker
issues (ADR-0003 preserved); on the fast path no tracker issue exists, the
retrieval contract points at the `docs/plans/` path, and `scribe`'s
issue-closing duty correctly does not fire (it requires an issue number in its
dispatch).

**Acceptance criteria**
1. The threshold and the three exceptions appear in all three files:
   `for f in agents/orchestrator.md agents/task-master.md agents/spec-master.md; do s=$(tr '\n' ' ' < "$f" | tr -s ' '); printf '%s' "$s" | grep -Eq '≤ ?2 (dispatchable )?units' || exit 1; printf '%s' "$s" | grep -q 'debug spec' || exit 1; printf '%s' "$s" | grep -q 'Convergence follow-ups' || exit 1; done` → exit 0. *(baseline: exits 1 on the first file)*
2. spec-master is required to emit all nine elements, named:
   `s=$(tr '\n' ' ' < agents/spec-master.md | tr -s ' '); for k in 'Objective' 'Retrieval' 'Affected files' 'Ordered edits' 'Do NOT touch' 'Acceptance criteria' 'Pre-resolved context' 'Escalation'; do printf '%s' "$s" | grep -q "$k" || exit 1; done; printf '%s' "$s" | grep -q 'Unit: <task-id>'` → exit 0.
3. ADR-0003 is not contradicted — spec-master still disclaims `to-tickets`:
   `tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -Eq 'never run.{0,40}to-tickets|do(es)? not (run|carry).{0,40}to-tickets'` → exit 0.
   And: `diff <(git show e5b908f:docs/adr/0003-hivemind-split-spec-master-task-master.md | sed -n '/^## Decision/,/^## /p') <(sed -n '/^## Decision/,/^## /p' docs/adr/0003-hivemind-split-spec-master-task-master.md)` → exit 0.
4. The emitted contract still satisfies the mechanical gate:
   `bash tests/dispatch-hygiene.test.sh` → exit 0 (H4 validates the nine-element contract regardless of which persona wrote it).
5. `bash tests/validate.sh` → exit 0.

---

## Step 10 — Milestone 2 release

Same shape and criteria as Step 7, with a CHANGELOG entry naming F6 and F7.

---

# Milestone 3 — F9, F10, F11

## Step 11 (F9) — Resume the same reviewer on `INSUFFICIENT-CONTEXT`

**Affected files**: `agents/orchestrator.md` § "On an `INSUFFICIENT-CONTEXT`
verdict" only.

**Change**: after fetching the named missing constraint (explorer, scribe, or
yourself), **resume the same reviewer session by name via `SendMessage`**,
quoting the constraint, instead of a fresh `Agent` dispatch. Keep unchanged: the
"does not count against the 2-FAIL cap" sentence, "does **NOT** re-dispatch
lead-programmer", and the standing pending-review flag.

**Acceptance criteria**
1. `s=$(sed -n "/On an .INSUFFICIENT-CONTEXT. verdict/,/^\*\*At the 2-FAIL cap/p" agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); test "${#s}" -gt 500; printf '%s' "$s" | grep -q 'SendMessage'` → exit 0. *(baseline: the grep exits 1)*
2. `n=$(sed -n "/On an .INSUFFICIENT-CONTEXT. verdict/,/^\*\*At the 2-FAIL cap/p" agents/orchestrator.md | tr '\n' ' ' | tr -s ' ' | grep -c 're-dispatch the reviewer' || true); test "$n" -eq 0` → exit 0. *(baseline: 1)*
3. Anti-regression — the three preserved facts:
   `s=$(sed -n "/On an .INSUFFICIENT-CONTEXT. verdict/,/^\*\*At the 2-FAIL cap/p" agents/orchestrator.md | tr '\n' ' ' | tr -s ' '); printf '%s' "$s" | grep -q '2-FAIL cap'; printf '%s' "$s" | grep -q 'lead-programmer'; printf '%s' "$s" | grep -q 'pending-review flag'` → exit 0.
4. `bash tests/validate.sh` → exit 0.

---

## Step 12 (F10) — Milestone-audit gate: CLOSED AS NO-CHANGE

**Resolved by OQ4 = (a) keep it as-is.** F10 is **rejected on assessment**, not
deferred and not unassessed. The principle "a clean checkpoint is not a reason
to skip the audit" is deliberate, with reasoning recorded at
`docs/plans/2026-07-13-persona-review-hardening.md:583` ("the checkpoint is a
quick human confirm pass; the auditor remains the deeper automated adversarial
pass — the former does not replace the latter").

> **Rationale re-checked 2026-08-06 after the Step 1 amendment — verdict
> unchanged, but one of its two supports is narrower than stated.** The
> rejection rested on two legs:
>
> - **Leg (i) — the principle is deliberate and reasoned.** Entirely unaffected
>   by the amendment. This is the load-bearing leg and it is what the operator
>   actually ruled on in OQ4.
> - **Leg (ii) — "Step 1 already drops a clean, FAIL-free, all-mechanical
>   milestone's audit from `fable` to `sonnet`, capturing F10's saving."**
>   **This is now true only for milestones under 8 units.** Under the amended
>   tier table a clean milestone of **≥8 units** audits on `fable`, not
>   `sonnet`. Measured over this repo's 12 milestones, ≥8 units describes
>   **3 (25 %)** — so the saving still lands on ~75 % of milestones, but the
>   blanket claim was wrong and is corrected here rather than left standing.
>
> **No regression against today's behaviour**, which is the fair comparison: at
> `e5b908f` a clean all-mechanical milestone audits on `fable` regardless of
> size. After the amendment, small clean milestones improve (fable → sonnet) and
> large clean ones are unchanged (fable → fable). The amendment costs nothing
> relative to the status quo; it forgoes a saving the *original* F1 fix would
> have captured on ~25 % of milestones.
>
> Leg (i) alone sustains the rejection, so F10 stays **rejected on assessment**.
> Recorded so a Pass 4 does not re-open it on the strength of the narrowed
> leg (ii).

**There is no implementation unit here** — `task-master` slices nothing for
Step 12. Its only artifact is a line in Step 15's ADR recording that F10 was
assessed and rejected, so a Pass 4 does not silently re-file it.

**Acceptance criteria** (verified as part of Step 15, not as a unit of its own)
1. The principle is intact: `n=$(tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | grep -c 'A clean checkpoint is not a reason to skip the audit' || true); test "$n" -eq 1` → exit 0. *(baseline: 1 — this criterion is green at baseline **by design**; it is a regression guard on a deliberate no-change, and Step 15 criterion 2 is what proves the rejection was recorded.)*
2. `git diff --numstat -- agents/orchestrator.md` shows no hunk inside § "Milestone audit gate":
   `diff <(git show e5b908f:agents/orchestrator.md | sed -n '/^## Milestone audit gate/,/^## /p') <(sed -n '/^## Milestone audit gate/,/^## /p' agents/orchestrator.md)` → exit 0.

---

## Step 13 (F11) — Reuse a forwarded blast-radius answer instead of re-deriving it

**Affected files**
- `templates/persona-protocol.md` § "Structural questions go to the explorer" —
  add one rule: when your dispatch packet already contains a blast-radius /
  structural answer, **verify** it rather than re-deriving from zero; spawn the
  explorer only to check the specific claim you doubt.
- `agents/lead-programmer.md` — the pre-edit explorer spawn becomes conditional
  on `## Pre-resolved context` not already answering it.
- `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc` — port the same rule (R-D).

**Do NOT touch — this is the Writer/Reviewer split and it is out of scope**:
`agents/reviewer.md`'s "still derive blast radius via the explorer and re-run
the checks yourself" and "The lead-programmer's advisory review packet is a
starting hint, not a source of truth". The reuse rule applies to
lead-programmer / spec-master / milestone-auditor **only**, and the protocol
text must say so explicitly.

**Acceptance criteria**
1. `s=$(sed -n '/^## Structural questions go to the explorer/,/^## /p' templates/persona-protocol.md | tr '\n' ' ' | tr -s ' '); test "${#s}" -gt 600; printf '%s' "$s" | grep -qi 'verify'; printf '%s' "$s" | grep -q 'reviewer'` → exit 0 (the rule exists **and** names the reviewer exception). *(baseline: both greps exit 1)*
2. `sed -n '/^## Structural questions go to the explorer/,/^## /p' templates/persona-protocol.md | tr '\n' ' ' | tr -s ' ' | grep -Eq 'never applies to the reviewer|reviewer .{0,60}(exempt|always re-derive)'` → exit 0.
3. lead-programmer's call is conditional:
   `tr '\n' ' ' < agents/lead-programmer.md | tr -s ' ' | grep -q 'Pre-resolved context'` → exit 0. *(baseline: exits 1)*
4. **Anti-scope-creep control — reviewer.md is untouched**:
   `git diff --numstat -- agents/reviewer.md` produces no output.
5. `node tests/adapter-protocol-parity.test.js` → exit 0.
6. `node bin/cli.js --update --check` → exit 0.
7. `bash tests/validate.sh` → exit 0.

---

## Step 14 — Milestone 3 release

Same shape and criteria as Step 7, CHANGELOG naming F9, F10 (or its
non-reversal), F11.

---

## Step 15 (scribe) — Institutional record

**Affected files**: `.claude/wiki/changelog.md`, `.claude/wiki/README.md`,
`CONTEXT.md`, a new `docs/adr/0012-*.md`, and
`.claude/agent-memory/antislop-task-master/roast-pass-class-ledger.md` (now
dead state — the class ledger tracked clean streaks for a trigger that no
longer exists; delete it or mark it retired).

**ADR-0012 must record, precisely:**
- **Supersedes ADR-0004 § Decision Tension 2** (model routing / the separate
  fable advisory dispatch). **ADR-0004 § Decision Tension 1** (roast-work is
  advisory, appended after the verdict, never gating) **survives unchanged** —
  say so explicitly, because a reader who sees "supersedes ADR-0004" will
  otherwise assume the advisory-only property went with it.
- The capability knowingly given up (fable's bulk-context critique on large
  surfaces) and the accepted replacement (the reviewer's inline `roast-work`),
  attributed to the operator's 2026-08-03 ruling on OQ1 against spec-master's
  recommendation.
- `fable` is removed from `spec-master`'s dispatch and from the reviewer's
  advisory pass, and **retained on exactly one path**: `milestone-auditor`
  tier 2 (a judgment-signal-free milestone of ≥8 units), per the operator's
  2026-08-06 correction. `task-master`'s exclusion guard is retained
  deliberately. Do **not** record this as "fable retired" — that would be a
  false institutional record.
- **Amends ADR-0009** with the 2026-08-03 re-measurement (13.3 %) and states the
  thresholds were deliberately left unchanged.
- **Preserves ADR-0006's reviewer-gate invariant**: the `.fail` expiry added by
  Step 4 applies to implementer tiers only.
- **F10 was assessed and rejected**, with its provenance
  (`docs/plans/2026-07-13-persona-review-hardening.md:583`), so a Pass 4 does
  not re-file it.

**Acceptance criteria**
1. `ls docs/adr/0012-*.md` → exit 0, exactly one match.
2. Every required element is present: `s=$(tr '\n' ' ' < docs/adr/0012-*.md | tr -s ' '); for k in 'ADR-0004' 'Tension 1' 'Tension 2' 'ADR-0006' 'ADR-0009' 'reviewer gate' 'implementer' '13.3' 'F10'; do printf '%s' "$s" | grep -q "$k" || exit 1; done` → exit 0.
3. ADR-0004's own Decision section is **not** rewritten (ADRs are historical):
   `diff <(git show e5b908f:docs/adr/0004-reviewer-roast-work-dual-model-routing.md | sed -n '/^## Decision/,/^## /p') <(sed -n '/^## Decision/,/^## /p' docs/adr/0004-reviewer-roast-work-dual-model-routing.md)` → exit 0.
4. `CONTEXT.md` no longer defines a dead concept:
   `n=$(tr '\n' ' ' < CONTEXT.md | tr -s ' ' | grep -c 'Roast-work routing' || true); test "$n" -eq 0` → exit 0 *(baseline: 1)*, AND `tr '\n' ' ' < CONTEXT.md | tr -s ' ' | grep -q 'inline-only'` → exit 0 *(baseline: exits 1)*.
5. The dead class ledger is retired: `test ! -f .claude/agent-memory/antislop-task-master/roast-pass-class-ledger.md || grep -qi 'retired' .claude/agent-memory/antislop-task-master/roast-pass-class-ledger.md` → exit 0.
6. `bash tests/validate.sh` → exit 0.

---

## Open Questions

**None outstanding — nothing blocks dispatch.** All five were ruled on by the
operator on 2026-08-03. Retained below in full, with each ruling marked, as an
audit trail of what was decided and by whom, so a later pass does not silently
re-open them. The recommended default is listed first in each; **OQ1 is the one
case where the operator chose against it.**

**OQ1 (blocks Step 2) — the fable roast-work advisory pass: narrow or remove?**
The audit says remove. My measurement supports the *problem* (criteria 2 and 3
have no size floor, so the "rare exception" fires on ~85 % of this repo's
commits) but not the *diagnosis* (ADR-0004's stated value was fable's
bulk-context strength on large surfaces, not extra rubric coverage).
- (a) RECOMMENDED — narrow. Make criteria 2 and 3 conjunctive with criterion 1's
  size floor. Measured effect: fires on 7/60 recent commits (11.7 %) instead of
  ~52/60. Keeps ADR-0004 intact.
- **(b) ← RULED 2026-08-03. Remove** the separate fable dispatch entirely; rely
  on the reviewer's inline `roast-work`. Simpler, cheaper, but supersedes
  ADR-0004 § Decision Tension 2 and — with Step 1 — leaves `fable` dispatched
  nowhere in the system.
- (c) Narrow now (a), and schedule removal for Pass 4 if the narrowed trigger
  still shows no Major/Critical findings over 3 consecutive fires.

> **Ruling: (b), against spec-master's recommendation.** The operator took the
> ADR-0004 bulk-context tradeoff knowingly. Step 2 is rewritten as a removal;
> § Context records the accepted losses; Step 15's ADR-0012 attributes the
> decision. Three consequences surfaced only *after* the ruling and are handled
> in R-J, R-K and R-L rather than left to the executor: the removal deletes one
> of Step 6's protected strings, makes two of Step 6's byte ceilings vacuous,
> and creates six dangling cross-references.

**OQ2 (blocks Step 3's threshold half) — F3's premise is refuted; proceed
anyway?** Measured: 8/60 commits (13.3 %) are sonnet-eligible today, inside
ADR-0009's predicted 6–8/50 (~15 %) band. The ~0 % figure belongs to the
*predecessor* scheme ADR-0009 already retired.
- **(a) ← RULED 2026-08-03. RECOMMENDED — no threshold change.** Record the
  re-measurement against ADR-0009 (Step 3 criteria 1–4) so a Pass 4 does not
  re-file this.
- (b) Prune only `^\.claude/agents/` from `SENSITIVE_PATHS`, on the grounds that
  those files are generated mirrors byte-derivable via `bin/cli.js --update`.
  Cost: also un-guards a *hand-edited* mirror, which is exactly the P2 violation
  the pattern was added to catch.
- (c) Raise `MAX_CHANGED_LINES` to 120 and `MAX_CHANGED_FILES` to 6. Adds ~7 of
  the 16 size-only blocks. Note ADR-0009 § Context measured three
  security-critical diffs at 25–41 lines, so this loosens the axis that ADR
  named unsafe.

**OQ3 (shapes Step 4) — does the `.fail` expiry-on-PASS reach the reviewer's
own tier?** The request says "let a `.fail`-based disqualifier expire once the
same unit subsequently reaches PASS". Applied to the reviewer gate, that
re-opens ADR-0006's closed hole (sonnet PASS → miss found → opus FAIL → fix →
opus PASS → sonnet again).
- **(a) ← RULED 2026-08-03. RECOMMENDED — implementer tiers only.** R3 and R4
  expire on a subsequent verified PASS; R2 (the reviewer gate) and
  `hooks/scripts/reviewer-tier.sh` stay permanent and untouched.
- (b) Expire R2 as well, and amend ADR-0006/ADR-0009 to record the reversal.
- (c) Expire R2 only after N (e.g. 3) consecutive clean PASSes on that unit,
  mirroring the roast-pass class downgrade already in the protocol.

**OQ4 (blocks Step 12) — reverse "a clean checkpoint is not a reason to skip the
audit"?** It is deliberate, with reasoning recorded at
`docs/plans/2026-07-13-persona-review-hardening.md:583` and a pinned acceptance
criterion in that plan: the checkpoint is a human confirm pass, the auditor is
the deeper adversarial pass, "the former does not replace the latter".
- **(a) ← RULED 2026-08-03. RECOMMENDED — keep it.** Step 1 already drops a
  clean, FAIL-free milestone of fewer than 8 units from `fable` to `sonnet`,
  capturing F10's cost saving without touching the principle. Step 12 closes as
  an assessed rejection with no implementation unit.
- (b) Make the audit opt-in via `AskUserQuestion` after a clean checkpoint on a
  FAIL-free milestone; record the reversal and its provenance in the section.
- (c) Keep it mandatory but bound its scope on a clean FAIL-free milestone
  (premises + goal-drift only, no unit-level re-derivation).

**OQ5 (blocks Step 6) — are the compression ceilings right?** Proposed:
agent-teams section 20 → ≤8 lines (×7 copies); background-dispatch section 64 →
≤28 lines; per-unit model routing 192 → ≤110 lines; aggregate
`agents/orchestrator.md` 30 839 → ≤26 000 B.
- **(a) ← RULED 2026-08-03. RECOMMENDED — accept as proposed.** ~4 800 B off
  every main-session turn plus ~800 B off every full-tier persona spawn.
  *Finalization note:* the protected-string list drops from four to **three**
  because OQ1's removal deletes the `Downgrade/expiry path` paragraph, and the
  aggregate ceilings are re-derived against the post-Step-2 state so they are
  not satisfied by Steps 1–2 alone (R-J, R-K).
- (b) More aggressive: also compress § "Review routing" (4 543 B) and § "Third
  verdict" (1 394 B). Higher regression risk — both encode gate mechanics.
- (c) Less aggressive: 6a and 6b only; defer 6c (per-unit model routing) to a
  Pass 4 once F1/F4/F9 have settled that section's shape.

---

## Self-check

*Re-run 2026-08-03 after the operator rulings. CHK1–CHK15 are the original
items, re-checked against the revised text; CHK16–CHK20 are new items the
OQ1 removal ruling made necessary.*

- CHK1: Is "heavy" defined identically in the template, both adapter ports, and
  orchestrator.md after Step 2? — PASS, **re-checked under the removal ruling**:
  the question is now moot in the form asked, because "heavy" ceases to exist.
  What replaces it is Step 2 criterion 2, which asserts **zero** occurrences of
  the section name across `agents/`, `templates/`, `bin/`, `tests/`,
  `adapters/` and `CONTEXT.md` — a stronger check than agreement between
  copies.
- CHK2: Do Steps 1 and 4 agree on which `.fail` disqualifiers survive? — PASS
  (Step 1 removes fable slots R3/R5 by making them dead prose; Step 4's
  criterion 4 asserts R3's cross-unit phrasing is gone and criterion 6 asserts
  R2 is byte-identical).
- CHK3: Is the reviewer-gate ratchet's fate stated unambiguously? — **now PASS**
  (was FAIL/ambiguous → Open Question 3, ruled (a) on 2026-08-03): Step 4's "Do
  not touch" names `hooks/scripts/reviewer-tier.sh` and § "Reviewer gate model
  selection" explicitly, and criterion 6 asserts both are byte-identical to
  baseline.
- CHK4: Is the exact regeneration command for mirrors defined, and is it
  distinguished from a dry run? — PASS (R-A; Step 7 criterion 2 asserts on
  `--update --check`'s exit code plus its per-file summary line, and explicitly
  rules out mtime and plain double-run diffs).
- CHK5: Does any step add, remove, or rename a `## ` heading in
  `templates/persona-protocol.md`? — PASS (R-C states the constraint; Step 6's
  "Do not touch" list names it; Step 6 criterion 8 catches a violation because
  `bin/cli.js` would throw at load).
- CHK6: Is the new heavy-trigger threshold number justified by data rather than
  asserted? — **moot under the removal ruling**; the 7/60 vs 52/60 measurement
  is retained in § Context as the evidence for *why* the trigger was
  miscalibrated, but no new threshold is introduced.
- CHK7: Is F3's proposed threshold change defined? — **now PASS** (was
  FAIL/missing → Open Question 2, ruled (a) on 2026-08-03): no threshold change;
  Step 3 criterion 5 makes the deliberate no-change checkable by pinning both
  constants and a zero-diff on the script.
- CHK8: Do Steps 5 and 15 agree on whether `agents/scribe.md` changes? — PASS
  (Step 5's "Do not touch" names it; Step 15 touches only wiki/CONTEXT/ADR).
- CHK9: Is "how far to trim" (F8) given a checkable bound rather than a
  judgment? — FAIL (ambiguous as filed) — revised in place: every 6a/6b/6c
  criterion now carries an explicit line or byte ceiling with its baseline, plus
  a protected-string criterion and a mutation control.
- CHK10: Is the F10 principle's provenance established before proposing a
  reversal? — PASS (traced to
  `docs/plans/2026-07-13-persona-review-hardening.md:583` with its reasoning
  quoted) — and the reversal itself is converted to Open Question 4.
- CHK11: Does the plan state who files tracker issues on Step 9's fast path? —
  FAIL (missing on first draft; ADR-0003 forbids spec-master running
  `to-issues`, and no-issue breaks `scribe`'s issue-closing preconditions) —
  revised in place: no tracker issue is filed, retrieval points at the
  `docs/plans/` path, and the scribe's duty correctly does not fire.
- CHK12: Is every negative grep criterion protected against grep's exit 2 and
  against prose line-wrapping? — FAIL (ambiguous on first draft) — revised in
  place: R-F and R-G, and every negative criterion is now
  `n=$(grep -c … || true); test "$n" -eq 0` with a `tr '\n' ' ' | tr -s ' '` join and a
  stated baseline value.
- CHK13: Does any step weaken the Writer/Reviewer split? — PASS (Step 13's "Do
  NOT touch" names both reviewer independence bullets and criterion 4 asserts
  `agents/reviewer.md` has zero changed lines; Step 4 criterion 6 asserts the
  reviewer gate section is byte-identical to baseline).
- CHK14: Is constitution P3 satisfied for every step that edits a
  version-stamped file? — PASS (three release units, each asserting both
  manifests match via Step 7 criterion 1).
- CHK15: Are the ceilings in Step 6 stated as numbers a command can check? —
  PASS (criteria 1, 3, 5, 11 are `wc -l` / `wc -c` comparisons with baselines).
- CHK16: Do Step 2 and Step 6 agree on whether the `Downgrade/expiry path`
  paragraph exists? — FAIL (conflicting — Step 2 deletes the section containing
  it while Step 6 pinned it as a protected string that must survive) — revised
  in place: Step 6's protected list reduced to three strings, R-J records why,
  and the dependency order now puts Step 2 before Step 6.
- CHK17: Are Step 6's aggregate byte ceilings reachable by the preceding steps
  alone? — FAIL (ambiguous — a ceiling already satisfied by Steps 1–2 measures
  nothing about Step 6) — revised in place: ceilings re-derived against the
  post-Step-2 state (23 500 B / 16 800 B) with the required own-contribution
  stated, plus a mutation control that must fail the ceiling.
- CHK18: Does the plan say what happens to every file that *names* the deleted
  protocol section? — FAIL (missing on the pre-ruling draft, which assumed the
  section survived) — revised in place: Step 2's affected-files list enumerates
  all six groups with line numbers, and criterion 2 is a repo-wide
  zero-occurrence sweep scoped to the live control plane.
- CHK19: Is it stated which half of ADR-0004 survives the supersession? — FAIL
  (missing) — revised in place: § Context, Step 2's "Do NOT touch", and Step 15's
  ADR requirements all state that Tension 1 (advisory-only) survives and only
  Tension 2 (model routing) is superseded; Step 15 criterion 2 greps for both
  literals.
- CHK20: Does Step 12's "no change" have a criterion that could ever fail? —
  PASS, with a caveat recorded in place: its criterion 1 is green at baseline
  **by design** (it guards a deliberate non-change), so criterion 2's
  section-level `diff` against `e5b908f` is what actually carries the check, and
  Step 15 criterion 2 is what proves the rejection was *recorded* rather than
  forgotten.

*Third run, 2026-08-04, after `task-master` returned four spec gaps against
units #231/#233/#234/#238. All four were reproduced live before being accepted
— none was taken on report.*

- CHK21: Do Steps 1 and 2 agree on where the standing `fable` exclusion guard
  lives? — FAIL (conflicting — Step 1's "Do not touch" said
  `agents/orchestrator.md`, Step 2's criterion 4b said `agents/task-master.md`;
  the latter is wrong, and the string it grepped for occurs nowhere in that
  file) — revised in place: 4b split into 4a/4b and re-pointed at
  `agents/orchestrator.md` § "task-master model routing".
- CHK22: Is every step's anti-regression control still **satisfiable** after the
  steps this spec orders before it have run? — FAIL (conflicting — Step 4's 6c
  demanded a section be byte-identical to `e5b908f`, while Step 2, mandated to
  land first, edits two of that section's paragraphs) — revised in place:
  6c re-scoped to the three untouched safety paragraphs. **CHK2 and CHK3 both
  covered this pair and both passed it**, because each asked whether the steps
  *agreed*, and neither asked whether the criterion could still be *satisfied*
  under the ordering. Satisfiability-after-ordering is now its own check.
- CHK23: Does every prose criterion survive the ~76-column wrap in the file it
  greps? — FAIL (ambiguous, one root cause with two modes — an unjoined grep
  (Step 5 c6) and a join without squeeze (Step 8 c4), both measurably vacuous at
  baseline) — revised in place at the root: R-G rewritten to mandate
  `tr '\n' ' ' < file | tr -s ' '` and to ban unjoined prose greps; all 36 join
  sites corrected; every stated baseline re-verified against `git show
  e5b908f:<file>`; exactly one baseline claim was wrong and is corrected.
- CHK24: Is every acceptance criterion in this document valid shell? — FAIL
  (missing — no such check existed, and the mechanical R-G repair itself
  introduced 19 mis-ordered redirects of the form `tr … | tr -s ' ' < file`,
  which feeds the file to the *second* `tr`, plus 4 dropped `;` separators) —
  revised in place: all 23 repaired, and **all 87 criteria in this document now
  pass `bash -n`**. This check is itself now part of the spec's own definition
  of done.

*Fourth run, 2026-08-04, after `task-master` returned GAP-6 against unit #231.
This is the second criterion-methodology defect to slip past my own self-check
on this spec, so the sweep was made mechanical rather than by inspection.*

- CHK25: Did Revision 2's R-G fix actually sweep *both* declared failure modes?
  — FAIL (missing — it rewrote only the 36 sites that **already had** a `tr`,
  and never swept sites with no join at all, which is mode 1: exactly the mode
  the rewrite claimed to close) — revised in place: every `grep` site in the
  document was enumerated programmatically and each measured line-based vs
  wrap-safe against the real files.
- CHK26: Is a single mandated join form correct for **every** criterion shape?
  — FAIL (conflicting — Revision 2 mandated one form universally, but applying
  it to two other shapes **breaks** them) — revised in place: R-G now defines
  three shapes. **(A)** anchored (`^## `) must stay line-based — measured, a
  join takes `grep -c '^## Reviewer roast-work…'` from 1 to **0** on a file that
  contains the heading. **(B)** unanchored prose must join+squeeze, and a
  recursive sweep must become an explicit per-file loop because `grep -r` cannot
  be made wrap-safe by any flag. **(C)** occurrence counts must use
  `grep -o … | wc -l`, because **`grep -c` counts matching lines** and silently
  caps at 1 on a joined stream, which would make Step 1's "expect 2"
  unsatisfiable.
- CHK27: Are Step 2's dangling-reference sweeps — the sole coverage for the
  deleted "heavy" concept — actually able to see the files most likely to retain
  a reference? — FAIL (missing, GAP-6) — revised in place. Measured at
  `e5b908f`: criterion 2's `grep -rl` found **5** files where the wrap-safe form
  finds **7** (blind to `agents/orchestrator.md:285-286` and
  `agents/task-master.md:55-56`), and the spec's stated baseline of "6" matched
  neither. Criterion 3 found **3** where the wrap-safe form finds **4**, and its
  named file list omitted `templates/persona-protocol.md:297-298` — the file the
  deleted section actually lives in. Under the Revision-2 text an executor could
  have left the orchestrator's trailing `**Trigger — see …**` paragraph in place
  and passed every criterion.

**Revision 3 sweep result.** 108 real criteria, **0 shell-syntax errors**;
3 correctly-unjoined anchored sites, 30 joined+squeezed, **0 unjustified
un-joined multi-word sites** (the single remaining match is inside a prose note
quoting the *old broken* form as documentation). All four newly-joined criteria
were executed at baseline and returned their stated values.

*Fifth run, 2026-08-04, after the `spec-master` run on issue #245 reported an
unsatisfiable criterion in unit #235 during a cross-spec file-overlap check.*

- CHK28: Does every file in an affected-files list actually contain the thing
  the step edits? — FAIL (missing, GAP-7 — 6a listed both adapter ports, and
  **neither carries an Agent-teams section**; both record it as dropped for v1,
  and the parity test maps it `deferred`, not `probe`. `task-master` sliced the
  list faithfully into a #235 criterion demanding a non-zero diff in each port,
  which no honest implementation can satisfy) — revised in place: the ports are
  removed from 6a, and criterion 9b now **forbids** touching them, so the
  cosmetic edit the old criterion invited is itself a failure.
- CHK29: Does every affected file have at least one criterion? — FAIL (missing,
  GAP-8, found while fixing GAP-7 — `templates/persona-protocol-slim.md` was an
  affected file of 6a with **no criterion at all**; criteria 1 and 2 named only
  the full template, so compressing one tier and leaving the other at 20 lines
  with superseded text would have passed) — revised in place: criteria 1, 2 and
  2b now loop over both tiers. Verified byte-identical at `e5b908f`, so this is
  coverage, not extra work.
- CHK30: Does 6a's output satisfy the *other* in-flight spec that edits the same
  section? — FAIL (missing — #245 Step 8 corrects the same paragraph, so #235
  would have landed and needed an immediate second edit) — revised in place:
  criterion 2b binds the cross-spec requirement, and reference text is supplied
  that satisfies both specs in one edit. Note #245's supplied bullet **alone**
  would fail this spec's criterion 2, which pins the `nested TEAMS` rule as
  load-bearing; the merged text keeps it.

**Revision 4 sweep.** 110 real criteria, **0 shell-syntax errors**. All three
new/changed 6a criteria executed at baseline and confirmed **RED** (c1 and c2b
fail as required; c9b is green because the ports are correctly untouched). The
supplied reference text was mechanically checked against criteria 1, 2 and 2b:
8 lines, all four required strings present, the banned string absent.

*Sixth run, 2026-08-04, after `task-master` verified Revision 4 by substituting
the supplied text into the real files and re-running the criterion — the check I
should have run myself.*

- CHK31: Was the supplied reference text verified by **running the criterion**,
  or by counting the snippet? — FAIL (missing, GAP-10 — I counted the snippet's
  own lines and reported "8 lines, PASS". Substituted into the real template the
  criterion returns **9**, because `sed -n '/start/,/^## /p' | sed '$d'` also
  prints the mandatory blank separator before the next heading. The text failed
  the very criterion it was supplied to satisfy) — revised in place: the
  reference text is now 7 content lines, verified by substitution into **both**
  real tiers with criteria 1, 2 and 2b re-run (criterion 1 → 8, PASS), and the
  spec now states outright that "≤8" means "≤7 content lines".
  **This is the third instance of the same root error** — checking my own
  statement instead of executing the command. CHK24 mandated `bash -n` on every
  criterion, which proves a command *parses*; it does not prove a supplied
  artifact *satisfies* it. Any text this spec supplies for an executor to paste
  must now be substituted and measured, not counted.
- CHK32: Does any general rule in Risks contradict a step's own criteria? —
  FAIL (conflicting, GAP-11 — R-D said "any step editing the roast trigger **or
  the agent-teams section** must update both adapter ports", while criterion 9b
  now forbids exactly that for the agent-teams case, because neither port has
  ever carried that section) — revised in place: R-D is now a per-section rule
  driven by the parity map's `{ probe }` / `{ deferred }` classification, with
  all three in-scope sections enumerated. The blanket wording is what produced
  GAP-7 in the first place; same shape as GAP-6's lesson, **a general rule with
  an unstated exception**.

**Revision 5 verification.** The reference text was substituted into
`templates/persona-protocol.md` **and** `templates/persona-protocol-slim.md`,
and criteria 1, 2 and 2b executed against both: all PASS, criterion 1 = 8.
Longest line 76 columns. Criterion 11's byte ceiling remains correctly unmet at
this point in the ordering (18 325 B; Step 2 removes ~1 890 B first, landing
~16 435 B ≤ 16 800), confirming the ceiling still measures Step 6's own work.

*Seventh run, 2026-08-06, after the operator's Step 1 correction. This run is
against an **amendment**, not a defect report, so the items interrogate whether
the amendment left the rest of the spec consistent.*

- CHK33: Does the amended fable condition still exhibit the inversion F1 was
  filed to fix? — FAIL (conflicting, caught while drafting — the option offered
  to me was to keep the existing "mechanical end-to-end" condition as the fable
  tier and add sonnet beneath it, which preserves the inversion **exactly**: the
  most expensive tier would still fire on the most mechanical milestones) —
  revised in place: fable is relocated to a **size** condition (≥8 units), the
  one property ADR-0004 documents it as buying, and sonnet takes the mechanical
  cases. Recorded with reasoning so the tier table is not "corrected" back later.
- CHK34: Does the ≥8-unit condition reintroduce the "heavy" concept Step 2
  deletes? — PASS, but only because it was deliberately designed not to: a
  cumulative-**diff** measure was considered and rejected, since Step 2 removes
  the per-unit ≥8-files/≥400-lines trigger and retires "heavy" as a term. Unit
  count is milestone-scoped and metrically distinct. Stated in Step 1 so the two
  steps are not read as contradicting.
- CHK35: Does every claim elsewhere in the spec that depended on "fable is
  dispatched nowhere" still hold? — FAIL (conflicting, five sites — Step 2
  criterion 4a's expected count, R-I, Step 12's leg (ii), Step 15's ADR-0012
  required content, and the Scribe update hint) — revised in place at all five,
  with the superseded wording quoted rather than deleted so the change is
  auditable. The count correction is the load-bearing one: Step 2's expected
  `model: fable` total moves **1 → 2**, and Step 1's moves **2 → 3**;
  leaving either would have made a criterion fail on a correct implementation.

**Revision 6 verification.** `model: fable` occurrences re-counted at `e5b908f`:
**4** (`:219` spec-master, `:232` milestone-auditor, `:258` task-master
exclusion, `:270` roast pass). Step 1 removes `:219` → **3**; Step 2 removes
`:270` → **2**. Milestone sizes measured across 12 milestones (2, 3, 3, 4, 5, 6,
6, 6, 7, 8, 10, 10 units) → ≥8 fires on **3 (25 %)**. Step 1's new criterion 3
confirmed RED at baseline (`sonnet` and `8 units` both absent from the auditor
paragraph).

*Eighth run, 2026-08-06, after `task-master` proved by simulation that a
Revision-6 tree with Change item 4 unapplied still passes every criterion.*

- CHK36: Does every numbered Change item in every step have at least one
  criterion that fails if that item is skipped? — FAIL (missing, GAP-12 — Step
  1's Change item 4, the Escalation-symmetry edit, had none. Revision 5's
  whole-section `grep -ci 'fable'` covered it *incidentally*; Revision 6
  correctly narrowed that criterion to the spec-master paragraph, and nothing
  replaced the coverage the narrowing dropped) — revised in place: new
  criterion 7, paragraph-scoped via a blank-line `awk` delimiter, with three
  assertions mapping one-to-one onto what item 4 must accomplish, all three
  baselines measured and the whole criterion confirmed RED by execution.
  **This is the same shape as GAP-6, from the other direction: narrowing an
  over-broad criterion silently deletes whatever it was covering by accident.**
  Standing rule added — when a criterion's scope shrinks, re-cover the delta
  explicitly; never assume it is still covered elsewhere.
- CHK37: Is the per-Change-item mapping now explicit enough for a reviewer to
  check it without re-deriving? — PASS: Step 1's Change items 1–4 map to
  criteria 1 (heading), 2 (item 2, spec-master), 3 and 6 (item 3, the auditor
  tiers), and 7 (item 4, escalation symmetry); criteria 4, 5 and 8 are
  cross-cutting counts and regression guards.

**Revision 7 verification.** New criterion 7 executed at `e5b908f` and confirmed
**RED**. Its three baselines measured directly from the paragraph: 343-byte
extraction, `fable-run spec-master` = 1, `auditor` = 0, `sonnet` = 0. Template
byte margin re-measured end-to-end by applying both edits to a copy: 19 185 →
17 273 (Step 2) → 16 413 (Step 6a), a **387-byte** margin under the 16 800
ceiling, with Step 6a alone leaving 18 325 B — over. Recorded as R-M.

**Tally.** Run 1: five FAILs — CHK3 → OQ3 and CHK7 → OQ2 (both since resolved by
operator ruling); CHK9 / CHK11 / CHK12 revised in place. Run 2 (post-ruling):
four new FAILs — CHK16–CHK19 — all revised in place. Run 3 (post-`task-master`
round-trip): four new FAILs — CHK21–CHK24 — all revised in place. No FAIL
remains unrepresented, and no Open Question lacks an originating CHKn.

**Honest note on this spec's own quality trend.** Three of the four gaps in run
3 were in criteria my run-1 self-check had already marked PASS. The pattern is
consistent: my checks tested whether the plan's *statements agreed with each
other*, not whether its *commands would actually run and actually fail on a
wrong implementation*. CHK24 (shell-validate every criterion) and CHK22
(satisfiability under the mandated ordering) exist to close that gap and should
be carried into future specs, not just this one.

---

## Revision 6 impact on already-sliced units (2026-08-06)

| Unit | Step | Change | Re-slice? |
|---|---|---|---|
| **#230** | 1 | **Substantive.** Heading renamed; the auditor's single fable condition becomes a three-tier ordered table; criteria go 5 → 7, with criteria 1–4 and 6 all new or changed. The unit boundary, affected file (`agents/orchestrator.md`) and "Do not touch" list are unchanged. | **Yes — re-read the whole step, do not diff criteria** |
| **#231** | 2 | **One number.** Criterion 4a's expected `model: fable` count moves **1 → 2**. Nothing else in Step 2 moves. | **Yes — one-line criteria update** |
| #232–#244 | 3–15 | Only Step 12's *rationale prose* and Step 15's ADR-0012 *required content* change; neither alters an acceptance criterion. Step 12 still has no implementation unit. | No |

**On whether #230 needs a full re-file rather than an in-place update:** an
in-place update is still correct — same unit boundary, same single affected
file, same section. But unlike the last five rounds this is a **scope** change,
not a criteria-text fix: what the executor must write is materially different.
`task-master` should re-read Step 1 in full rather than diffing the criteria
block, and #230's dispatch prompt's `## Ordered edits` element will need
rewriting, not patching.

**Model-tag guidance:** #230 is no longer a trivially mechanical edit — it now
introduces an ordered decision table with a measured threshold. Per R-H it
should not be tagged `haiku`.

## Coordination with issue #245 (skills-library remediation)

Both specs edit `templates/persona-protocol.md` § "Agent-teams mode". The other
`spec-master` resolved the sequencing on its side: **#235 lands first**, and its
Step 8 is verification-only against the templates. This spec accepts that
ordering and absorbs #245's correction into 6a's single edit (criterion 2b plus
the reference text), so #235 does not land and immediately require a second edit.

**One defect reported back to #245, not patched here** (it is that spec's unit,
and the same "never patch another owner's spec locally" rule applies to me):

> **#245 Step 8, criterion 4 is vacuous — it is already green at baseline.**
> It asserts `grep -c 'in your tools list' templates/persona-protocol.md` → `0`
> and the same for the slim tier. Measured at `e5b908f`: **both already return
> 0**, because the phrase wraps across `templates/persona-protocol.md:48-49`
> (`… if it's in` / `  your tools list; …`). The wrap-safe form
> (`tr '\n' ' ' < "$f" | tr -s ' ' | grep -c …`) returns **1** in each. As
> written the criterion cannot fail, so it cannot verify that #235 preserved the
> correction — which is precisely the job it was added to do. This is R-G
> failure mode 1, the same class as GAP-6. Recommended fix: adopt the wrap-safe
> form, baselines 1 → 0. Criterion 3 of that step already uses the correct
> `tr … | tr -s ' '` shape, so this looks like an inconsistency rather than a
> methodology disagreement.

Criterion 2b above deliberately uses the **wrap-safe** form and the corrected
baselines, so #235's own coverage is sound regardless of how #245 resolves this.

## Revision 3 impact on already-sliced units (2026-08-04)

**Confirmed: #231 needs a criteria-text update only.** `task-master`'s read is
correct. Step 2's unit boundary, affected-files list, "Do NOT touch" list,
mutation control and model-tag guidance are all unchanged by Revision 3. What
changed is the *text* of criteria 2, 3 and 4a, plus their stated baselines
(2: "6 files" → **7**; 3: 3 files → **4**, gaining
`templates/persona-protocol.md`; 4a: `grep -c` → `grep -o … | wc -l`). No new
file enters or leaves the unit's scope, and no acceptance bar is relaxed — all
three criteria got strictly *stricter*.

**Two other units carry a one-line criteria-text change**, both from the R-G
shape-(C) fix rather than from GAP-6 itself:
- **Step 1 / #230** — criterion 3 becomes an occurrence count
  (`grep -o … | wc -l`, baseline 4, expect 2). Necessary because `grep -c`
  counts matching *lines* and cannot express "expect 2" on a joined stream.
- **Steps 3, 5, 12, 15 (#232, #234, #243-adjacent, #244)** — one criterion each
  gains the join. All four were measured safe at `e5b908f` under both forms;
  they are joined for uniformity and because each asserts against text the
  executor is about to rewrite.

Everything else from Revision 2's table stands unchanged.

## Revision 2 impact on already-sliced units (2026-08-04)

**The re-slice scope is wider than the four blocked units.** `task-master`
blocked #231, #233, #234 and #238 — correctly, those are where the four
*reported* defects live. But fixing R-G **at its root**, as requested, changed
acceptance-criteria text in **eleven** steps, because the broken join pattern
was used throughout. Measured by diffing Revision 1 against Revision 2:

| Step | Unit | Changed lines | Nature of change | Re-slice? |
|---|---|---|---|---|
| 2 | #231 | 13 | **Material** — criterion 4 split 4a/4b and re-pointed; affected-files gained a third orchestrator edit | **Yes** |
| 4 | #233 | 40 | **Material** — criterion 6 split 6a/6b/6c; 6c re-scoped from section to three paragraphs | **Yes** |
| 5 | #234 | 14 | **Material** — criterion 6 rewritten (was vacuous), anti-sentinel added | **Yes** |
| 8 | #238 | 14 | **Material** — criterion 4 rewritten (was vacuous), baseline corrected 0→1 | **Yes** |
| 1 | #230 | 1 | Join hardening only | **Yes — criteria text changed** |
| 3 | #232 | 2 | Join hardening only | **Yes — criteria text changed** |
| 6 | #235/#236 | 3 | Join hardening only | **Yes — criteria text changed** |
| 9 | #239 | 3 | Join hardening only | **Yes — criteria text changed** |
| 11 | #241 | 3 | Join hardening only | **Yes — criteria text changed** |
| 13 | #242 | 3 | Join hardening only | **Yes — criteria text changed** |
| 15 | #244 | 2 | Join hardening only | **Yes — criteria text changed** |
| 7, 10, 12, 14 | — | 0 | Untouched (release units and the closed no-change) | No |

*(Unit numbers above are `task-master`'s mapping as reported and should be
re-confirmed against the tracker; the **step** numbers are authoritative.)*

**Why the "join hardening only" rows still need re-slicing, despite being
strictly-more-permissive corrections.** Every one of those criteria asserts
against prose **that does not exist yet** — text the executor will write in that
same unit, wrapping wherever its editor puts it. A unit carrying the Revision-1
join would therefore pass review on a check that silently matched nothing, which
is precisely how Gaps 3 and 4 reached the tracker. The correction is cheap
(one added `| tr -s ' '` per site) but it is not optional, and it cannot be
applied by the executor mid-unit without re-opening the "task-master never
patches a spec locally" rule.

**Nothing the unaffected units depend on has moved.** Verified explicitly for
the two structural fixes:
- **Gap 1's fix does not change Step 1 (#230).** Step 1's "Do not touch" list
  already named `agents/orchestrator.md` § "task-master model routing" as the
  guard's home, and its criterion 3 still expects `model: fable` count = 2 after
  Step 1. Only Step 2's criterion was wrong; Step 1 was right all along.
- **Gap 2's fix does not relax any safety invariant.** Step 4's control still
  pins the downgrade-only asymmetry, the `.fail` disqualifier and the escalation
  path against `e5b908f`, and still asserts `hooks/scripts/reviewer-tier.sh` has
  zero changed lines plus `tests/reviewer-tier.test.sh` green. What it no longer
  does is forbid Step 2's own sanctioned edits to two *other* paragraphs of the
  same section.

## Scribe update hint

Vocabulary **retired** from `CONTEXT.md` once Milestone 1 lands: **"heavy"** (as
a roast-pass trigger) and **"Roast-work routing (fable heavy lifting)"** — both
name a mechanism that no longer exists. The `roast-work` skill entry stays but
becomes **inline-only**.

Vocabulary **added**: **implementer-tier ratchet** vs **reviewer-gate ratchet**
(only the former expires on a subsequent verified PASS — this distinction is the
whole of OQ3's ruling and will be re-litigated if it isn't written down), and
the removal of `fable` from `spec-master`'s dispatch and from the roast pass,
and its **retention** on `milestone-auditor` tier 2 (≥8-unit,
judgment-signal-free milestones) per the operator's 2026-08-06 correction. The
`task-master` exclusion guard is deliberately retained. The three-tier auditor
routing (`fable`|`opus`|`sonnet`) and its ordering rule are new vocabulary.

`docs/adr/0012-*` is the new decision record. ADR-0004 § Tension 2 is
**superseded** while § Tension 1 survives; ADR-0006 and ADR-0009 gain
back-pointers. None of the three is rewritten.

---

# Debug spec — Step 7 (unit 237), 2-FAIL-cap escalation (2026-08-06)

**Append-only. Scope: Step 7 / issue #237 only.** No other step (#230–#236,
#238+) is touched by this pass, and nothing above this heading is rewritten or
renumbered. Where this section and Step 7's original text disagree, **this
section wins** for unit 237.

## Triage (`antislop:fail-triage`)

**1. VERIFY — reproduced live at `c96bad1`, 2026-08-06.**

| Check | Result |
|---|---|
| Step 7 criterion 6 as written (`tr '\n' ' ' < CHANGELOG.md \| grep -qi 'fable'`) | **exit 0 — GREEN at `c96bad1`, i.e. green on the failing tree** |
| Same command at baseline `e5b908f` (before the 0.23.0 entry existed) | **exit 0 — also green.** The criterion is *vacuous*: it matches the pre-existing 0.22.0 entry's own `fable` mentions and can never fail |
| Forbidden phrasing `no persona and no pass`, wrap-safe count over `CHANGELOG.md` | 0 — attempt 2 *did* close FAIL 1 |
| `grep -c milestone-auditor docs/adr/0004-*.md` | **0** |
| `grep -c spec-master docs/adr/0004-*.md` | **0** |
| Criteria 1–5, 7 | all green (independently re-verified in the FAIL record) |

Conclusion: **could-not-reproduce by criterion, confirmed by inspection.** Both
FAILs are real defects in `CHANGELOG.md`, and **neither is detectable by any
acceptance criterion this step carries.** Both verdicts rested entirely on
reviewer judgment — which is why two attempts could ship, each self-verified
green, and each still FAIL.

**2. CATEGORIZE — spec/criterion defect** (not a code defect). Three distinct
plan-level defects, in causal order:

- **D1 — the spec contradicts itself about the R-I claim.** `R-I` (line 600) was
  rewritten by **Revision 6** to say Steps 1+2 leave fable dispatched on
  `milestone-auditor` tier 2, and that *"Step 7's CHANGELOG entry must say
  **that**, not 'fable is retired'."* But **Step 7's own `**Change**` paragraph
  (line 1326–1328) was never updated** and still reads: *"…and, if OQ1 resolved
  to removal, the fact that `fable` is no longer dispatched anywhere (R-I)."*
  Attempt 1 followed Step 7's local text. It was not wrong to; the spec told it
  two different things and the nearer one was stale.
- **D2 — Revision 6's impact table under-scoped the blast radius.** The table
  (line 2007) rules `#232–#244 … No` re-slice, on the reasoning that no
  *acceptance criterion* changed. True but insufficient: unit #237's **Ordered
  edit 3** and **Objective** both carry the pre-Revision-6 sentence verbatim
  (`gh issue view 237`: *"must state plainly that after F1 and F2 the `fable`
  tier is dispatched by **no persona and no pass** anywhere in the system"*, and
  the now-stale `agents/orchestrator.md:258` citation). A revision that
  invalidates a *dispatch packet's instruction text* is a re-slice trigger even
  when it moves no criterion. D1 + D2 together fully explain FAIL 1: the
  executor was instructed, in three places, to write the false sentence.
- **D3 — the criterion left the ADR-0004 clause unpinned and unprotected, and
  the step carries no freeze on already-correct prose.** This is what produced
  FAIL 2, and it is a distinct failure mode from D1/D2:
  - Attempt 2 was dispatched to fix *one* sentence's premise. It rewrote the
    whole R-I paragraph (`git show c96bad1 -- CHANGELOG.md`: 16 insertions / 10
    deletions, one hunk) and, mid-rewrite, appended a per-persona carve-out to
    an **adjacent sentence that was already correct at `8374dd3`** — turning
    *"Tension 2 … is explicitly superseded by the review-centric approach"*
    into *"… superseded … for `spec-master` and the reviewer's advisory pass,
    but survives for `milestone-auditor`'s tier-2 dispatch."*
  - The over-correction is **not arbitrary** — it is the *predictable*
    reconciliation of two spec statements the plan never explicitly reconciled:
    "fable survives on `milestone-auditor` tier 2" **and** "ADR-0004 § Tension 2
    is superseded, unqualified." A reader asked to hold both will invent a
    carve-out. The spec's actual reconciliation exists (line 411: tier 2 targets
    *"the one property ADR-0004 **documents** it as buying"* — **documents**,
    not *decides*), but it sits in a Clarifications line under Step 1, not
    anywhere Step 7's executor reads.
  - Prose that is *already correct at the prior attempt's commit* had no
    protection: neither the criteria nor the `## Do NOT touch` list said "the
    ADR-0004 sentence is correct; do not restate it."

**Not the cause** (ruled out, on evidence): executor carelessness or scope
sprawl — `git diff --name-only 8374dd3..c96bad1` → `CHANGELOG.md` only, one
hunk, and every other criterion re-verified green at both attempts; and model
tier — the `Suggested model: haiku` tag is a contributing factor at most, since
FAIL 2 required a *plausible-sounding* synthesis that a stronger model is not
guaranteed to avoid when the spec itself never states the reconciliation.

## Revised Step 7 (supersedes only what it names)

**Superseded from Step 7 as written above:**
- The `**Change**` paragraph's clause *"the fact that `fable` is no longer
  dispatched anywhere (R-I)"* (line 1327–1328) — **replaced** by: *the fact that
  Steps 1+2 remove `fable` from `spec-master`'s dispatch and from the reviewer's
  advisory `roast-work` pass, while `milestone-auditor`'s tier-2 fable dispatch
  survives (R-I as amended by Revision 6).*
- **Acceptance criterion 6 in full** — replaced by criteria 6a–6g below.
- Revision 6's impact-table row for `#232–#244` (line 2007), **as it applies to
  #237 only**: #237 **does** require a re-slice — its Objective and Ordered
  edit 3 carry pre-Revision-6 text. Rows for other units are untouched.

**Added to Step 7's `## Do NOT touch` list:**
- **The ADR-0004 sentence is frozen.** It is correct as of `8374dd3` and is
  pinned byte-exact by criterion 6c. Do not paraphrase it, re-derive it, or
  "reconcile" it with the fable-survives claim. **ADR-0004 § Tension 2 is
  superseded without qualification** — there is no per-persona component of it
  to retain, because ADR-0004 names neither `spec-master` nor
  `milestone-auditor` (0 occurrences each, criterion 6g). What survives is a
  *documented property* (fable's bulk context on a large surface), which is what
  `milestone-auditor`'s ≥8-unit rule now targets — **not Tension 2 itself.** If
  you judge that property worth recording, the only sanctioned phrasing is:
  *"fable's documented bulk-context strength is what `milestone-auditor`'s
  tier-2 ≥8-unit rule now targets"* — and it must be a **separate sentence**,
  never a qualifier attached to the word *superseded*.
- **Any prose already correct at the prior attempt's commit.** On a re-dispatch,
  fix the named defect and nothing adjacent. Rewriting a paragraph to fix one
  clause is how FAIL 2 happened.

### Replacement acceptance criterion 6 (6a–6g)

All of 6a–6f operate on the **new entry's section only** — scoping is
load-bearing: the old criterion matched the 0.22.0 entry and was therefore green
at baseline. Backticks are stripped so patterns need no shell-quoting gymnastics;
the join is wrap-safe (`tr '\n' ' ' | tr -s ' '`, R-G).

Common prelude for 6a–6f:

```
V=$(node -p "require('./package.json').version")
SEC=$(awk -v v="$V" 'index($0,"## ["v"]")==1{f=1;next} /^## \[/{f=0} f' CHANGELOG.md \
     | tr '\n' ' ' | tr -s ' ' | tr -d '\140')
```

6. **(6a) Anti-sentinel / section located.** The criteria below are negative
   greps; without a floor they are all satisfiable by deleting the paragraph.
   `test "${#SEC}" -ge 800 && printf '%s' "$SEC" | grep -q 'R-I decision'` → exit 0.
   *(Measured: 2486 chars at `8374dd3`, 2848 at `c96bad1`, 0 at `e5b908f`.)*

   **(6b) Forbidden-phrasing sweep — the FAIL-1 mode.** Enumerated, not
   exemplified; every variant that asserts fable is dispatched nowhere:
   ```
   b=0
   for p in "no persona and no pass" "dispatched by no persona" \
            "final dispatch of fable anywhere" "no longer dispatched anywhere" \
            "fable is retired" "dispatched nowhere" "dispatched **nowhere**"; do
     n=$(printf '%s' "$SEC" | grep -o -F "$p" | wc -l)
     test "$n" -eq 0 || { b=1; printf 'hit: %s (%s)\n' "$p" "$n"; }
   done
   test "$b" -eq 0
   ```
   → exit 0. *(Measured RED at `8374dd3`: 3 of the 7 hit. GREEN at `c96bad1`.)*

   **(6c) The ADR-0004 sentence, pinned byte-exact — the FAIL-2 mode.** This is
   deliberately a transcription check, not a paraphrase check: the two attempts
   proved the clause cannot survive re-derivation. Write it exactly:

   > ADR-0004 § Decision Tension 2 (fable's bulk-context critique on large
   > surfaces) is explicitly superseded by the review-centric approach;
   > ADR-0004's Tension 1 (roast-work as advisory, never gating) survives
   > unchanged.

   Backticks around `fable`, `spec-master` etc. and line wrapping are free (both
   are normalised away); **every other byte is pinned**, including the semicolon
   and the second `ADR-0004's`. Check:
   ```
   PIN="ADR-0004 § Decision Tension 2 (fable's bulk-context critique on large surfaces) is explicitly superseded by the review-centric approach; ADR-0004's Tension 1 (roast-work as advisory, never gating) survives unchanged."
   printf '%s' "$SEC" | grep -q -F "$PIN"
   ```
   → exit 0. *(Measured RED at both prior attempts — `8374dd3` fails on `its
   Tension 1`, `c96bad1` fails on the per-persona carve-out. GREEN on a
   corrected copy. This is the one criterion that discriminates attempt 2
   exactly: at `c96bad1` it is the **only** failing sub-criterion.)*

   **(6d) No second, contradicting mention of either Tension.** Prevents 6c
   being satisfied by one correct sentence while a second sentence re-introduces
   the carve-out:
   ```
   t2=$(printf '%s' "$SEC" | grep -o -F "Tension 2" | wc -l)
   t1=$(printf '%s' "$SEC" | grep -o -F "Tension 1" | wc -l)
   test "$t2" -eq 1 && test "$t1" -eq 1
   ```
   → exit 0. *(`grep -o … | wc -l` counts occurrences, not lines — R-G shape
   (C); `grep -c` after a join can only ever return 0 or 1.)*

   **(6e) The positive R-I claim is present** (Revision 6's actual ruling — the
   half attempt 1 was missing):
   `printf '%s' "$SEC" | grep -q -F "milestone-auditor" && printf '%s' "$SEC" | grep -Eq 'tier.2'`
   → exit 0. *(Measured RED at `8374dd3`, GREEN at `c96bad1`.)*

   **(6f) The entry names all five findings:**
   `m=0; for k in F1 F2 F4 F5 F8; do printf '%s' "$SEC" | grep -q -F "$k" || m=1; done; test "$m" -eq 0`
   → exit 0.

   **(6g) Premise guard — the pin's own precondition.** 6c's wording is correct
   *because* ADR-0004 scopes Tension 2 entirely to the reviewer/orchestrator/
   task-master surface F2 removes in full. If that ever stops being true, the
   pin must be re-derived by `spec-master`, not silently edited by an executor:
   ```
   A=docs/adr/0004-reviewer-roast-work-dual-model-routing.md
   test "$(grep -c -F 'milestone-auditor' "$A")" -eq 0 && \
   test "$(grep -c -F 'spec-master' "$A")" -eq 0
   ```
   → exit 0. *(Measured 0 / 0 at `c96bad1`. If this criterion fails, **STOP and
   escalate** — do not adjust the CHANGELOG to match.)*

**Criteria 1, 2, 3, 4, 5, 7 are unchanged** and were independently re-verified
green at `c96bad1`; a third attempt must keep them green but need not
re-establish them from scratch beyond re-running them.

**Discrimination matrix** (all criteria run over each tree; this is the evidence
that the replacement is not vacuous):

| Tree | 6a | 6b | 6c | 6d | 6e | 6f | verdict |
|---|---|---|---|---|---|---|---|
| `e5b908f` (baseline, no entry) | FAIL | pass | FAIL | FAIL | FAIL | FAIL | RED |
| `8374dd3` (attempt 1) | pass | **FAIL** | **FAIL** | pass | **FAIL** | pass | RED — catches FAIL 1 |
| `c96bad1` (attempt 2, HEAD) | pass | pass | **FAIL** | pass | pass | pass | RED — catches FAIL 2, and only that |
| corrected copy | pass | pass | pass | pass | pass | pass | GREEN |

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every criterion above was executed
  against four real trees before being written down; the vacuity of the old
  criterion 6 was **measured** (green at `e5b908f`), not inferred.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — 6c
  replaces an LLM re-derivation of a sentence with a byte-exact transcription
  check, which is the direct fix for FAIL 2's mechanism.
- P3 "Version-stamp discipline": satisfied — untouched; criteria 1, 4, 5
  already enforce it and stay unchanged.
- P5 "`tests/validate.sh` is the merge gate": satisfied — criterion 7 unchanged,
  green at `c96bad1`.
- P4 (SHOULD) "Optional personas degrade gracefully": n/a — no shared persona
  prose is edited by this unit.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Missing
9. Completion / acceptance signals: Missing

- 2026-08-06 Edge cases / failure handling: Q What happens when a fix dispatch
  names one defective clause but the executor rewrites the surrounding
  paragraph? → A (self-resolved): unprotected today — that is exactly FAIL 2.
  Closed by the new `Do NOT touch` freeze plus criterion 6c's byte-exact pin.
- 2026-08-06 Technical constraints & tradeoffs: Q Should the ADR-0004 sentence
  be pinned verbatim, or forbidden from being touched at all? → A
  (self-resolved): **pinned verbatim.** "Do not touch" is unverifiable on a
  third attempt that legitimately re-edits the paragraph around it, and it is
  unenforceable if the fixer works from the spec rather than from a diff. A
  byte-exact pin is checkable from the file alone, independent of attempt
  history — the floor/ceiling/sentinel discipline applied to prose.
- 2026-08-06 Terminology consistency: Q Are "ADR-0004 § Tension 2 is
  superseded" and "`milestone-auditor` keeps fable" in conflict? → A
  (self-resolved): **no.** Tension 2 is a *routing decision* scoped entirely to
  the reviewer's advisory pass (ADR-0004:25–33); F2 deletes that surface in
  full, so it is superseded outright. What `milestone-auditor` tier 2 reuses is
  a *documented property* (bulk context on a large surface), not the decision.
  The spec said this only at line 411, under Step 1; it is now stated where
  Step 7's executor will read it.
- 2026-08-06 Completion / acceptance signals: Q Could the original criterion 6
  distinguish a correct CHANGELOG from either failing one? → A (self-resolved):
  **no** — measured green at `e5b908f`, `8374dd3` **and** `c96bad1`. It was a
  presence-grep over the whole file, so it was green before the entry existed.
  Replaced by 6a–6g, whose discrimination matrix is recorded above.

## Self-check

- CHK-D1: Does the revised step say what to do about Step 7's own stale
  `**Change**` paragraph, rather than only the criteria? — PASS (superseded
  explicitly under "Superseded from Step 7 as written above").
- CHK-D2: Do the replacement criteria fail on **both** prior attempts and pass
  on a corrected tree? — PASS (measured; discrimination matrix).
- CHK-D3: Is the replacement criterion non-vacuous at baseline — i.e. does it
  distinguish "entry written correctly" from "no entry at all"? — PASS (6a, 6c,
  6d, 6e, 6f all RED at `e5b908f`).
- CHK-D4: Are the negative greps (6b, 6d, 6g) protected against being satisfied
  by deletion? — PASS (6a floor at 800 chars, plus 6e/6f positive presence).
- CHK-D5: Is the exact required wording of the ADR-0004 sentence recoverable
  from the plan text alone, with no reference to an external commit? — PASS (6c
  quotes it in full; the `8374dd3` reference is corroboration, not the source).
- CHK-D6: Do 6c and the `Do NOT touch` freeze agree about whether the sentence
  may be edited? — FAIL (conflicting) — revised in place: the freeze now says
  "pinned byte-exact by criterion 6c", not "do not touch", so re-emitting the
  identical bytes during a legitimate paragraph edit is permitted and checkable.
- CHK-D7: Is the milestone-auditor / Tension-2 reconciliation stated in a place
  Step 7's executor reads? — FAIL (missing in the original plan) — revised in
  place: now stated in the `Do NOT touch` addition and in Clarifications.
- CHK-D8: Does any criterion depend on context not recorded in the plan (attempt
  order, capture timing, commit layout)? — PASS — 6a–6g all read only the
  working tree; the commit shas appear solely as measured baselines.
- CHK-D9: Is the re-scoped unit's prior defect history flagged against a `haiku`
  tag? — PASS (stated below; a FAIL record for 237 exists, and per R-H a unit
  with a recorded FAIL on this surface must not be re-tagged `haiku`).
- CHK-D10: Is every criterion shell-validated rather than written by
  inspection? — PASS (`bash -n` clean; all seven executed against four trees).

## Model-tag guidance for the re-dispatch (`task-master`)

Per R-H and this persona's own FAIL-record rule: **#237 must not be re-tagged
`haiku` on the third attempt.** The unit now carries a two-FAIL record, and both
defects were factual-consistency judgments across three documents (`CHANGELOG.md`,
`docs/adr/0004-*`, this spec) — not the mechanical release work the original
`haiku` tag was sized for. The mechanical half (criteria 1–5, 7) is already
landed and green; what remains is exactly the judgment half.

## Scribe update hint (delta only)

No new vocabulary. One correction for `CONTEXT.md` / the wiki if either records
the R-I decision: ADR-0004 § **Tension 2** is superseded **without any
per-persona qualifier**; `milestone-auditor`'s tier-2 fable slot reuses a
*documented property* of fable, not Tension 2 itself. `.claude/wiki/changelog.md:58`
already states the `spec-master` half correctly ("fable was never valid for that
persona per ADR-0004") and needs no change.

---

# Convergence follow-ups — Milestone 3 boundary (2026-08-07)

**Append-only. Scope: exactly the two `unconverged-requirement` findings the
human operator accepted at the Milestone 3 pre-audit checkpoint on 2026-08-07**
(units **#241, #242, #243** all reviewer-PASS; markers `241.pass`, `242.pass`,
`243.pass`, no `.fail` for any of them). Nothing above this heading is
rewritten, renumbered, or reworded — **including Step 15**, whose superseded
lines are *quoted* below rather than edited in place. No work beyond the two
named findings is added here.

Two new numbered steps: **Step 16** (Follow-up 1 — ADR renumber) and **Step 17**
(Follow-up 2 — CHANGELOG accuracy).

**Dispatchable-unit count: 1**, so this resolves on the **≤2-unit fast path**
that this spec's own Step 9 (F7) put in place — `task-master` is not invoked and
no `to-tickets` run happens. Step 16 is *not* a new unit: it is a correction to
the already-sliced, not-yet-dispatched unit **#244**, delivered as a re-issued
dispatch contract. Step 17 is the one new unit, **`229-CF2`** (named for
Follow-up 2 so the unit id and the finding number line up; there is deliberately
**no `229-CF1` unit**, because Follow-up 1 folds into #244).

## What I verified on disk before writing (2026-08-07, live, HEAD `c9e8f5b`)

| Claim | Verified | Result |
|---|---|---|
| Highest ADR on disk | `ls docs/adr/` | `0012-vendored-skill-declared-deviations.md` — landed by spec #245 at `e1dcab3`, pointers at `37abf72` |
| **`0013` is free** | `ls docs/adr/0013-*.md` | exit **2**, `wc -l` = **0**. No competing claim: `grep -rn "0013" --include=*.md .` returns **nothing** repo-wide |
| **`0007` is a hole, not a free slot** | `ls docs/adr/0007*`; `git log --all --diff-filter=AD -- 'docs/adr/0007*'` | File never existed in history. But `CONTEXT.md:178` links `[ADR 0007](docs/adr/0007-agent-identity-audit-logging-hardening.md)` — a **dangling reference to a different title**. Reusing 0007 would silently redirect that link. See OQ-CF1. |
| Numbering rule is explicit | `skills/domain-modeling/ADR-FORMAT.md:27-29` | *"Scan `docs/adr/` for the highest existing number and increment by one."* Highest = 0012 → **0013**. The rule says increment, **not** backfill gaps. |
| Every `0012` site in this spec | `grep -n "0012" <this file>` | **8 hits**: lines 864, 1572, 1577, 1602, 1603, 1638, 1956, 2151. Classified in Step 16. |
| Follow-up 2's premise | `agents/orchestrator.md:228-232` | Landed table: *"`opus` on any judgment signal …; `fable` if no judgment signal AND the milestone is 8+ units; `sonnet` otherwise."* A clean **≥8-unit** milestone audits on `fable`. **Finding confirmed.** |
| The defect is a *transcription* regression | This file, lines 861-863 and 1494-1518 | **The spec was already right.** Step 12 leg (ii) states the drop *"is now true only for milestones under 8 units"*, with the 3/12 = 25 % measurement. Unit #243 dropped the qualifier when transcribing Step 12 into the CHANGELOG. |
| Blast radius of the bad claim | `grep -rn "captured by F1\|F10's saving" --include=*.md .` | **One shipped site only**: `CHANGELOG.md:20-22`. `.claude/wiki/changelog.md` has **no** F10 entry. Nothing else to fix. |
| Version-stamp obligation | `.claude/constitution.md:18-22`; `.claude-plugin/plugin.json:3` | Neither follow-up touches `agents/*.md` or a template, so **no version bump** — `0.26.0` stands. |
| Gate applicability | `.claude/persona-config.json` `gatedAgents` | `["lead-programmer"]`. `229-CF2` is gated (nine-element contract required); #244 (scribe) is not, but is emitted in the same form anyway. |
| Baseline green | `bash tests/validate.sh` | exit **0** |

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-07 Domain entities / data model: Q Which number does this spec's new
  ADR take — the next-highest (`0013`), or the unfilled `0007` gap? → A
  (self-resolved): **`0013`**. `skills/domain-modeling/ADR-FORMAT.md:29` states
  the rule as "highest existing number, increment by one" — it does not
  backfill. Independently decisive: `CONTEXT.md:178` already links ADR-0007 to
  a *different* title, so reusing 0007 would repoint a live cross-reference at
  the wrong document — the exact false-institutional-record failure class
  Step 15 was written to avoid. Verified free, not assumed.
- 2026-08-07 External dependencies & integrations: Q Does closing these two
  findings require `task-master` and a `to-tickets` run? → A (self-resolved):
  **No.** One new dispatchable unit (`229-CF2`); Step 16 corrects an
  already-sliced unit rather than creating one. That is ≤2, so Step 9's fast
  path applies: spec-master emits the nine-element contracts directly,
  retrieval points at this `docs/plans/` path, and `scribe`'s issue-closing
  duty does not fire (no issue number in the dispatch). ADR-0003 is not
  contradicted — `to-tickets` is still never run by this persona.
- 2026-08-07 Edge cases / failure handling: Q What happens if #244 is
  dispatched from Step 15's own text, which this append is forbidden to edit?
  → A (self-resolved): the re-issued contract below is authoritative and says
  so in its first element; the orchestrator is told in the handoff to dispatch
  #244 **only** from it. The residual risk — that someone reads Step 15 in
  isolation — is raised as **OQ-CF2** rather than silently accepted, because
  the fix for it (a pointer line at the top of the document) is an edit above
  this heading and therefore not mine to make under an append-only instruction.
- 2026-08-07 Terminology consistency: Q The CHANGELOG's F10 sentence also says
  "all-mechanical", which is **not** a condition in the landed tier table
  (`agents/orchestrator.md:228-232` conditions on *judgment signal* and *unit
  count* only). Correct that too? → A (self-resolved): **No — out of scope,
  reported not patched.** The accepted finding is the missing size qualifier.
  "all-mechanical" is inherited verbatim from this spec's own Step 12 leg (ii),
  so changing it in the CHANGELOG alone would make the release note diverge
  from its source. It also errs *narrow* (understating which milestones
  qualify), the opposite direction from the size omission, so it is not a
  saving-overstatement. A Convergence follow-up must add no work beyond the
  named findings; recorded as **OBS-1** below for a Pass 4.
- 2026-08-07 Completion / acceptance signals: Q What machine-checkable
  criteria replace Step 14's presence-only checks, which is why the reviewer
  missed this? → A (self-resolved): Step 17's criteria assert the corrected
  *content* (both the "under 8 units" and "8 or more units" halves plus the
  25 % figure) **and** pin the untouched regions byte-for-byte against
  `c9e8f5b`, so the unit cannot pass by editing the right words in the wrong
  place. All five were executed against the live tree; baselines are recorded
  per criterion.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — `0013`'s availability, `0007`'s
  status, the tier table's wording, the single-site blast radius of the bad
  claim, and every criterion's baseline were each measured on disk at
  `c9e8f5b`, not inferred. The instruction explicitly said not to assume 0013;
  it was checked, and the check also surfaced the 0007 trap.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the ADR
  number is derived by the documented `ls`-and-increment rule rather than by
  judgment, and criterion 1 of the re-issued #244 contract re-runs that same
  check at execution time.
- P3 "Version-stamp discipline": satisfied — neither follow-up modifies
  `agents/*.md` or a template, so no `plugin.json` bump is owed. `0.26.0`
  remains correct; Step 17 corrects the *text* of an existing entry under that
  version rather than adding a new change to a version-stamped file.
- P5 "`tests/validate.sh` is the merge gate": satisfied — the final criterion
  of both units. Measured green at baseline (exit 0), so neither unit can pass
  by leaving it red.

## Step 16 (Follow-up 1) — this spec's new ADR is **`0013`**, not `0012`

**Supersedes only the ADR-number-bearing text of Step 15. Step 15's required
ADR *content*, its non-ADR affected files, and criteria 3, 4, 5 and 6 are
unchanged and are not restated here.** No new unit; this re-issues **#244**.

**Why:** Step 15 hardcodes `docs/adr/0012-<slug>.md`. Sibling spec #245 landed
`docs/adr/0012-vendored-skill-declared-deviations.md` at `e1dcab3` on
2026-08-07, before Milestone 3's units. Step 15's criterion 1
(`ls docs/adr/0012-*.md` → exactly one match) is therefore **already green at
baseline against a document this spec did not write** — vacuous, and worse,
executing #244 as written risks overwriting #245's ADR. This spec's own
§ "Coordination with issue #245" predates the landing and resolves only the
`persona-protocol.md` overlap; it never addressed ADR numbering.

**The corrected number is `0013`**, per `skills/domain-modeling/ADR-FORMAT.md:29`.
`0007` was considered and **rejected**: no `0007-*.md` has ever existed, but
`CONTEXT.md:178` links `[ADR 0007]` to `0007-agent-identity-audit-logging-hardening.md`,
so filling the gap would repoint a live cross-reference at an unrelated
document.

**All eight `0012` occurrences in this document, classified** (`grep -n "0012"`):

| Line | Text | Disposition |
|---|---|---|
| 864 | "Step 15 / ADR-0012: the required line … is rewritten" | **Historical** — a Revision-6 ripple note. Left as-is; renumbering a past revision note would falsify the audit trail. |
| 1572 | Affected files: `a new docs/adr/0012-*.md` | **Superseded → `docs/adr/0013-*.md`** |
| 1577 | "**ADR-0012 must record, precisely:**" | **Superseded → ADR-0013.** The bulleted content beneath is unchanged. |
| 1602 | Criterion 1: `ls docs/adr/0012-*.md` | **Superseded** (see below) |
| 1603 | Criterion 2: `tr … < docs/adr/0012-*.md` | **Superseded** (see below) |
| 1638 | "Step 15's ADR-0012 attributes the decision" | **Historical** — inside the OQ1 ruling block. Left as-is. |
| 1956 | CHK35's five conflict sites | **Historical** — a Self-check record. Left as-is. |
| 2022 | Revision-6 table row | **Historical.** Left as-is. |
| 2151 | Scribe update hint: "`docs/adr/0012-*` is the new decision record" | **Superseded → `docs/adr/0013-*`** (restated in the delta hint below) |

**Confirmed: no *other* step or unit in this spec hardcodes `0012`.** The five
superseded sites all sit inside Step 15 / #244 or its scribe hint; the four
historical sites are revision notes and self-check records that describe past
state and must not be rewritten.

**Superseding acceptance criteria for Step 15** (replace criteria 1 and 2 only;
3–6 stand verbatim):

1. `n=$(ls docs/adr/0013-*.md 2>/dev/null | wc -l); test "$n" -eq 1` → exit 0.
   *(baseline: `n` = 0.)*
2. Every required element is present:
   ```
   s=$(tr '\n' ' ' < docs/adr/0013-*.md | tr -s ' ')
   for k in 'ADR-0004' 'Tension 1' 'Tension 2' 'ADR-0006' 'ADR-0009' \
            'reviewer gate' 'implementer' '13.3' 'F10'; do
     printf '%s' "$s" | grep -q "$k" || exit 1
   done
   ```
   → exit 0. *(Unchanged from Step 15 except the path.)*
2b. **New — collision guard.** Spec #245's ADR is untouched and no `0012` is
   created by this unit:
   ```
   git diff --numstat c9e8f5b -- docs/adr/0012-vendored-skill-declared-deviations.md
   ```
   → **no output**, AND `n=$(ls docs/adr/0012-*.md | wc -l); test "$n" -eq 1`
   → exit 0. *(baseline: no output; `n` = 1.)* This criterion exists because
   the defect being corrected is precisely a collision risk; without it the
   unit could pass while having clobbered #245's record.

## Step 17 (Follow-up 2) — correct `CHANGELOG.md` `[0.26.0]`'s F10 entry

**New unit `229-CF2`.** Release-unit-owned content, so it cannot fold into #244
— unit #244's own "Do NOT touch" list already excludes `CHANGELOG.md`.

**The defect, precisely.** `CHANGELOG.md:20-22` (landed by #243 at `c9e8f5b`)
reads *"F10's saving is already captured by F1 (unit #230), which drops a
clean, FAIL-free, all-mechanical milestone's audit from `fable` to `sonnet`"* —
with no size qualifier. The landed tier table (`agents/orchestrator.md:228-232`)
drops to `sonnet` only when the milestone is **under 8 units**; a clean
milestone of **8 or more** still audits on `fable` (3 of this repo's 12
milestones, **25 %**). This is a **transcription regression, not a design
error**: this spec's Step 12 leg (ii) already carries the qualifier and the
measurement (lines 1501-1507). Step 14 reused Step 7's criteria, which check
only CHANGELOG *heading* and *finding-name* presence — never content
accuracy — which is why the reviewer PASSed it.

**One consequential clause travels with the qualifier, and is in scope.** Once
the saving is qualified, the sentence's own conclusion — *"that existing saving
was the basis for rejecting F10 outright"* — becomes false on its face: a
saving that lands on only ~75 % of milestones cannot be the basis for an
outright rejection. Step 12 is explicit that **leg (i) alone sustains the
rejection** and leg (ii) is the narrowed support. Correcting the qualifier
without correcting that clause would ship a *differently* inaccurate sentence,
so both move together. This is the minimum edit that makes the bullet true, not
an expansion of the finding.

**Model tag: `Suggested model: haiku`.** Per ADR-0010, every unit defaults to
`haiku` and nothing is pre-emptively escalated however delicate it looks. The
R-H / `.fail`-record exception does **not** apply: `.claude/reviewed/` holds no
`243.fail` and no `229-CF2.fail`. The replacement prose is given verbatim below,
so the unit is a mechanical substitution, and criteria 2-4 pin the untouched
regions byte-for-byte. Escalation, if needed, is reactive per the standard
first-FAIL rule.

## Dependency ordering: `229-CF2` **must land before** #244

Not independent, and not "after". Two reasons, both structural:

1. **#244 writes the institutional record for F10.** Step 15 requires ADR-0013
   to state *"F10 was assessed and rejected"* with its provenance. The scribe
   executing #244 will read the shipped `CHANGELOG.md` as the current record of
   that rejection. If the unqualified claim is still standing, the ADR is
   likely to reproduce it — and Step 15's criterion 2 checks only that the key
   `F10` is *present*, never that the surrounding claim is accurate. That is
   the identical presence-only gap that let the defect ship in the first place;
   ordering CF2 first closes it without adding a criterion to #244.
2. **ADRs are the harder record to correct.** This spec treats ADRs as
   historical and forbids rewriting them (Step 15 criterion 3 enforces exactly
   that for ADR-0004). A CHANGELOG line corrected *after* ADR-0013 has already
   cited it leaves the error frozen in the document that is by convention not
   rewritten. Cheap to sequence, expensive to undo.

**Dispatch order: `229-CF2` → reviewer PASS → #244 (re-issued).** #244 must not
be dispatched while `229-CF2` is pending review; the pending-review gate
enforces this mechanically in any case.

---

# Dispatch contracts (fast path — Step 9 / F7)

> **Retrieval for both**: this file,
> `docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md`, § "Convergence
> follow-ups — Milestone 3 boundary (2026-08-07)". No tracker issue is filed
> for `229-CF2`; #244's tracker issue exists but its criteria are superseded
> here. Paste each contract **starting at its `Unit:` line** — `dispatch-hygiene.sh`
> H3 reads the first non-blank line only.

## Contract A — `229-CF2` (dispatch first)

Unit: 229-CF2

#### Objective
Correct the `[0.26.0]` F10 bullet in `CHANGELOG.md` so it states the size
qualifier the landed milestone-auditor tier table actually implements. One
bullet, one file. Do not re-litigate F10 — it stays **rejected on assessment**.

#### Retrieval
`docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md`, § "Convergence
follow-ups — Milestone 3 boundary (2026-08-07)" → **Step 17**. Read Step 12
(same file, lines 1485-1518) for the authoritative wording this bullet
transcribes. Suggested model: **haiku**.

#### Affected files
- `CHANGELOG.md` — the F10 bullet only (currently lines 18-24). **Nothing else.**

#### Ordered edits
1. In `CHANGELOG.md`, replace the F10 bullet exactly:

   **From:**
   ```
     - **F10 — milestone-audit gate: assessed and rejected, not reversed.** The
       milestone-audit gate remains unconditional and mandatory; "a clean
       checkpoint is not a reason to skip the audit" is unchanged. F10's saving
       is already captured by F1 (unit #230), which drops a clean, FAIL-free,
       all-mechanical milestone's audit from `fable` to `sonnet` — that
       existing saving was the basis for rejecting F10 outright rather than
       implementing it. The audit itself was never made optional.
   ```

   **To:**
   ```
     - **F10 — milestone-audit gate: assessed and rejected, not reversed.** The
       milestone-audit gate remains unconditional and mandatory; "a clean
       checkpoint is not a reason to skip the audit" is unchanged. F10's saving
       is partly captured by F1 (unit #230), which drops a clean, FAIL-free,
       all-mechanical milestone's audit from `fable` to `sonnet` — but only for
       milestones **under 8 units**. A clean milestone of **8 or more units**
       still audits on `fable` (3 of this repo's 12 milestones, 25 %). That
       partial saving was the narrower of two supports for the rejection; the
       load-bearing one is that the principle is deliberate and reasoned. The
       audit itself was never made optional.
   ```
2. Nothing else. Do not add a new version heading, do not bump
   `.claude-plugin/plugin.json` (no version-stamped file is touched — see the
   Constitution check above), do not reflow neighbouring bullets.

#### Do NOT touch
- The F9 and F11 bullets, and every heading in `CHANGELOG.md`.
- `[0.25.0]` and every earlier entry.
- `.claude-plugin/plugin.json` (version stays `0.26.0`).
- `agents/orchestrator.md` — the tier table is **correct**; the CHANGELOG is
  what is wrong. Do not "fix" the table to match the old prose.
- The words "all-mechanical" — see OBS-1; deliberately retained.
- `docs/plans/*` — this spec is append-only and already correct.
- Any ADR, `CONTEXT.md`, or `.claude/wiki/*` — those are #244's surface.

#### Acceptance criteria
All five executed against the live tree at `c9e8f5b`; baselines recorded.

1. The qualifier and its measurement are present in the `[0.26.0]` section:
   ```
   s=$(sed -n '/^## \[0\.26\.0\]/,/^## \[0\.25/p' CHANGELOG.md | tr '\n' ' ' | tr -s ' ')
   printf '%s' "$s" | grep -q 'under 8 units' || exit 1
   printf '%s' "$s" | grep -q '8 or more units' || exit 1
   printf '%s' "$s" | grep -q '25 %' || exit 1
   ```
   → exit 0. *(baseline: exits 1 on the first check — all three absent.)*
2. The unqualified claim is gone:
   ```
   s=$(sed -n '/^## \[0\.26\.0\]/,/^## \[0\.25/p' CHANGELOG.md | tr '\n' ' ' | tr -s ' ')
   printf '%s' "$s" | grep -q "saving is already captured by F1" && exit 1
   printf '%s' "$s" | grep -q "was the basis for rejecting F10 outright" && exit 1
   exit 0
   ```
   → exit 0. *(baseline: exits 1 — both phrases present.)*
3. Everything from `[0.25.0]` down is byte-identical:
   `diff <(git show c9e8f5b:CHANGELOG.md | sed -n '/^## \[0\.25/,$p') <(sed -n '/^## \[0\.25/,$p' CHANGELOG.md)`
   → exit 0. *(baseline: exit 0 — this is a regression guard, green by design.)*
4. The F9 and F11 bullets are byte-identical:
   ```
   a=$(git show c9e8f5b:CHANGELOG.md | sed -n '/F9 — resume the same reviewer/,/F10 — milestone-audit/p' | head -n -1)
   b=$(sed -n '/F9 — resume the same reviewer/,/F10 — milestone-audit/p' CHANGELOG.md | head -n -1)
   [ "$a" = "$b" ] || exit 1
   c=$(git show c9e8f5b:CHANGELOG.md | sed -n '/F11 — reuse a forwarded/,/^## \[0\.25/p')
   d=$(sed -n '/F11 — reuse a forwarded/,/^## \[0\.25/p' CHANGELOG.md)
   [ "$c" = "$d" ]
   ```
   → exit 0. *(baseline: exit 0 — regression guard.)*
5. No file other than `CHANGELOG.md` is modified:
   `git diff --name-only -- . ':!CHANGELOG.md' ':!.claude/agent-memory'` → **no
   output**, AND `bash tests/validate.sh` → exit 0. *(baseline: no output;
   validate.sh exit 0.)*

> **Dispatch precondition for criterion 5.** This Convergence-follow-ups append
> must be **committed before `229-CF2` is dispatched**. It is deliberately kept
> strict (no `':!docs/plans'` exclusion) so that a stray plan edit by the
> implementer is caught — which means an *uncommitted* plan append would fail
> the criterion through no fault of the implementer. Verified 2026-08-07: with
> the append uncommitted, criterion 5 reports
> `docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md`; with it
> committed, no output. Same precondition applies to Contract B.

#### Pre-resolved context
Do **not** re-derive these; verify only a specific claim you actively doubt
(per F11 / Step 13).
- **The landed rule**, `agents/orchestrator.md:228-232`, verbatim: *"`opus` on
  any judgment signal (a `.fail` record for any unit in the milestone, a human
  challenge at the step-9 pre-audit checkpoint, or a carried-in
  `unconverged-requirement` follow-up); `fable` if no judgment signal AND the
  milestone is 8+ units; `sonnet` otherwise."*
- **The authoritative source wording** is Step 12 leg (ii), lines 1501-1507 of
  this file, including the 3/12 = 25 % measurement. The replacement prose above
  is derived from it — you do not need to re-measure the 12 milestones.
- **Blast radius is one site.** `grep -rn "captured by F1\|F10's saving"
  --include=*.md .` returns `CHANGELOG.md:20-21` and this spec's line 1502
  (which is the correct source and must not change).
  `.claude/wiki/changelog.md` has **no** F10 entry.
- **No version bump is owed** — `.claude/constitution.md:18-22` scopes P3 to
  `agents/*.md` and templates.

#### Escalation
Stop and report rather than improvising if: the F10 bullet does not match the
"From" block byte-for-byte (someone edited it after `c9e8f5b`); criterion 3 or 4
is red *before* you start (the baseline moved); or you conclude the tier table
rather than the CHANGELOG is what is wrong — that is a spec-level reversal and
routes back to `spec-master`, not a code fix.

## Contract B — #244 (dispatch **after** `229-CF2` PASSes)

Unit: 244

#### Objective
Execute **Step 15 — Institutional record** as written, with **one correction**:
the new ADR is **`docs/adr/0013-<slug>.md`**, not `0012`. **This contract
supersedes Step 15's criteria 1 and 2 and its ADR-path references. Do not
dispatch or execute #244 from Step 15's own text alone.** Everything else in
Step 15 — the required ADR content, the other affected files, criteria 3-6 —
stands verbatim.

#### Retrieval
`docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md`: read **Step 15**
(lines 1569-1609) for the full unit, then § "Convergence follow-ups — Milestone
3 boundary (2026-08-07)" → **Step 16** for the corrections that override it.
`skills/domain-modeling/ADR-FORMAT.md` for the ADR template.

#### Affected files
- `docs/adr/0013-<slug>.md` — **new** (was `0012-<slug>.md`).
- `.claude/wiki/changelog.md`, `.claude/wiki/README.md`, `CONTEXT.md` — as
  Step 15.
- `.claude/agent-memory/antislop-task-master/roast-pass-class-ledger.md` — as
  Step 15 (delete or mark retired).

#### Ordered edits
As Step 15, with every `0012` reference read as `0013`. Create the ADR at
`docs/adr/0013-<slug>.md`; its required content is Step 15's bullet list,
unchanged.

#### Do NOT touch
Step 15's own exclusions, **plus** these four, all landed by spec #245 and none
of them this unit's business:
- `docs/adr/0012-vendored-skill-declared-deviations.md` — another spec's ADR.
- `CONTEXT.md:124`'s `[ADR 0012]` pointer.
- `.claude/wiki/dependencies.md:29`'s `[ADR 0012]` pointer.
- `CHANGELOG.md` — release-unit-owned; `229-CF2` owns the F10 correction.

Also: do **not** create, rename, or backfill `docs/adr/0007-*`. The gap is
deliberate for this unit's purposes — see OBS-2.

#### Acceptance criteria
Step 15 criteria **3, 4, 5, 6 verbatim**, plus superseding **1, 2** and new
**2b** exactly as written in Step 16 above.

#### Pre-resolved context
- **`0013` is the correct number and is free**, measured 2026-08-07 at
  `c9e8f5b`: `ls docs/adr/` ends at `0012`; `ls docs/adr/0013-*.md` → exit 2;
  `grep -rn "0013" --include=*.md .` → no hits repo-wide. Rule:
  `skills/domain-modeling/ADR-FORMAT.md:29`.
- **`0012` is taken by spec #245** (`e1dcab3`, pointers at `37abf72`) — this is
  the whole reason for the renumber.
- **Do not use `0007`** even though no file occupies it: `CONTEXT.md:178` links
  ADR-0007 to a different, never-written title.
- The `229-CF2` correction has already landed by the time you run, so
  `CHANGELOG.md`'s F10 bullet is the accurate source for the ADR's "F10 was
  assessed and rejected" line.

#### Escalation
Stop and report if `ls docs/adr/0013-*.md` is **non-empty** when you start
(something else claimed the number — re-derive with the ADR-FORMAT rule and
report, do not guess), or if `229-CF2` has not yet reached PASS.

## Open Questions

1. **OQ-CF1 — should the `docs/adr/0007` gap be backfilled or formally
   retired?** `CONTEXT.md:178` links `[ADR 0007](docs/adr/0007-agent-identity-audit-logging-hardening.md)`,
   a file that has never existed in git history. Nothing in either follow-up
   depends on this and neither unit touches it.
   - **(a) RECOMMENDED — leave the gap, fix nothing now.** Out of scope for a
     Convergence follow-up; file it for a Pass 4. `0013` is unaffected either
     way.
   - (b) Fix the dangling link in `CONTEXT.md` as part of #244.
   - (c) Write the missing ADR-0007.
2. **OQ-CF2 — add a one-line "see Convergence follow-ups" pointer at the top of
   this document?** #245's plan carries exactly such a pointer at its line 10.
   It would remove the residual risk that someone dispatches #244 from Step 15
   in isolation and creates `0012` again. I did not add it because it is an
   edit *above* the append-only boundary I was given.
   - **(a) RECOMMENDED — yes, add it**, as a navigational line that changes no
     step, criterion, or revision note. Cheapest durable guard.
   - (b) No — rely on the re-issued contract plus the orchestrator's handoff.

## Observations (reported, not patched)

- **OBS-1 — "all-mechanical" is not a condition in the landed tier table.**
  `agents/orchestrator.md:228-232` conditions only on *judgment signal* and
  *unit count*. The phrase survives in both the CHANGELOG and this spec's
  Step 12 leg (ii) as a leftover of the pre-F1 trigger. It errs narrow
  (understates which milestones qualify), so it is not a saving-overstatement
  and is not part of the accepted finding. Correcting it means correcting Step 12
  too — a Pass 4 item.
- **OBS-2 — the ADR-0007 gap.** See OQ-CF1.
- **OBS-3 — the criteria gap that let this ship.** Step 14 reused Step 7's
  release criteria, which assert CHANGELOG *heading* and *finding-name*
  presence only. Any future release step that transcribes a narrowed or
  qualified claim needs a content assertion, not a presence assertion. Step 17
  criteria 1-2 are the pattern.

## Self-check

- CHK-C1: Is the corrected ADR number stated as a *verified* fact rather than
  an assumption, with the verification method recorded? — PASS (measured
  `ls docs/adr/`, `ls docs/adr/0013-*.md` → exit 2, repo-wide `grep "0013"` →
  no hits; rule cited at `ADR-FORMAT.md:29`).
- CHK-C2: Does the plan account for the possibility that the gap number `0007`
  is the "next free" one? — FAIL (missing on first pass) — **revised in place**:
  the `0007` case is now classified explicitly, rejected with a reason
  (`CONTEXT.md:178`'s dangling link), and carried into both the Clarifications
  log and #244's Pre-resolved context and Do-NOT-touch list.
- CHK-C3: Does the plan state, for every `0012` occurrence in this document,
  whether it is superseded or historical? — PASS (all 8 classified in Step 16's
  table; 5 superseded, 4 historical, 1 line — 2151 — restated in the delta
  scribe hint).
- CHK-C4: Do Step 16 and Contract B agree on which of Step 15's criteria
  survive? — PASS (both name criteria 3-6 as verbatim survivors and 1-2 as
  superseded, plus new 2b).
- CHK-C5: Is there a criterion that fails if #244 clobbers spec #245's ADR? —
  FAIL (missing on first pass; the renumber alone makes criterion 1 pass while
  saying nothing about `0012`) — **revised in place**: criterion 2b added, with
  a measured baseline.
- CHK-C6: Is the dependency direction between `229-CF2` and #244 stated with a
  reason, not merely asserted? — PASS (two reasons: the presence-only gap in
  Step 15 criterion 2, and ADR immutability under Step 15 criterion 3).
- CHK-C7: Does Step 17 define what happens to the clause "that existing saving
  was the basis for rejecting F10 outright", which the size qualifier
  falsifies? — FAIL (ambiguous on first pass — the finding named only the
  qualifier) — **revised in place**: the clause is now explicitly in scope, with
  the reason it must move, and the replacement prose is given verbatim so the
  unit stays mechanical.
- CHK-C8: Is "all-mechanical" resolved one way or the other, rather than left
  hanging? — PASS (resolved as out-of-scope with a stated reason, recorded in
  Clarifications, in Contract A's Do-NOT-touch list, and as OBS-1).
- CHK-C9: Is every acceptance criterion machine-checkable and baselined? —
  PASS (all five of Contract A and all three superseding criteria of Contract B
  were executed live at `c9e8f5b`; each carries its measured baseline, and the
  composite blocks are `bash -n` clean).
- CHK-C10: Do the criteria distinguish a genuine correction from an edit in the
  wrong place? — PASS (criteria 3-5 pin `[0.25.0]`-and-earlier, the F9/F11
  bullets, and the file set byte-for-byte, so a right-words-wrong-place edit
  fails).
- CHK-C11: Is the `haiku` tag defensible against the `.fail`-record rule? —
  PASS (`.claude/reviewed/` holds no `243.fail` and no `229-CF2.fail`;
  verbatim replacement prose supplied, so the unit is mechanical per ADR-0010's
  no-pre-emptive-escalation decision).
- CHK-C12: Does the append add any work beyond the two accepted findings? —
  PASS (OBS-1/2/3 are reported, not scheduled; no unit touches them).
- CHK-C13: Is the residual risk of dispatching #244 from Step 15's un-edited
  text represented somewhere actionable? — FAIL (missing on first pass) —
  **converted to Open Question 2 (OQ-CF2)**, with the interim guard stated in
  Contract B's Objective.

One revision pass was taken; CHK-C2, CHK-C5 and CHK-C7 were re-checked after
revision and now pass. CHK-C13 remains open by design and is represented in
Open Questions.

## Scribe update hint (delta only)

Two corrections to the Step 15 hint above, no new vocabulary:

1. **"`docs/adr/0012-*` is the new decision record" now reads `docs/adr/0013-*`.**
   `0012` belongs to spec #245 (`0012-vendored-skill-declared-deviations.md`)
   and is not this spec's record. The rest of that paragraph — ADR-0004
   § Tension 2 superseded while § Tension 1 survives, ADR-0006 and ADR-0009
   gaining back-pointers, none of the three rewritten — is unchanged.
2. **The F10 release note is corrected, not reversed.** F10 remains *rejected
   on assessment*. If `CONTEXT.md` or the wiki records the F1 saving, it must
   carry the size qualifier: the `fable` → `sonnet` drop applies to clean
   milestones **under 8 units**; clean milestones of **8 or more** still audit
   on `fable` (25 % of this repo's history). The load-bearing support for
   rejecting F10 is that the principle is deliberate, not the saving.
