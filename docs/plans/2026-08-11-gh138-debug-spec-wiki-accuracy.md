# Debug spec — gh138 (Step 8b) wiki-accuracy defects D8/D9

**Type:** debug spec (2-FAIL-cap escalation artifact, per the shared protocol's
"Debug spec on 2-FAIL-cap escalation"). **Not** a replan.
**Date:** 2026-08-11
**Parent plan:** `docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`, Step 8
**Tracker:** issue #138 (`plan/2026-07-28-microworhs-human-review` label set), repo `Storreslara/AntiSlop`
**Escalated record:** `.claude/reviewed/gh138.fail` (latest; documents both rounds)
**Commits inspected:** `36a1cfb` (build), `81c197d` (version bump), `3bfa8eb` (round-1 fix pass)

---

## Goal

Close the two remaining blocking defects (D8, D9) plus two folded-in accuracy
notes from `.claude/reviewed/gh138.fail`, under acceptance criteria strong
enough to have caught them — replacing the unit's existence-only greps, which
were structurally incapable of detecting any of D1–D9.

Scope is **four prose corrections in three files**. The unit's shape
(CONTEXT.md glossary, two ADRs, wiki refresh) is not reopened.

---

## `fail-triage` front-half (VERIFY → CATEGORIZE)

**1. VERIFY — could-not-reproduce via the gated criteria; reproduced directly.**

Re-ran all six gated criteria fresh at current HEAD (clean tree):

| Criterion | Result |
|---|---|
| `bash tests/validate.sh` | exit 0 |
| `grep -q 'Microworld' CONTEXT.md` | exit 0 |
| `grep -q 'ESCALATE-TO-HUMAN' CONTEXT.md` | exit 0 |
| `grep -q 'escalation packet' CONTEXT.md` | exit 0 |
| `ls docs/adr/*human-in-the-loop* \| wc -l` | 1 |
| `ls docs/adr/*gitignored* \| wc -l` | 1 |

**All six GREEN.** The FAIL does not reproduce through any gated command — at
either FAIL verdict. It reproduces only by reading the claims:

- D8 confirmed live: `.claude/wiki/architecture.md:89-90` reads
  "delete `.escalated` and packet on / subsequent re-review completion".
  `templates/persona-protocol.md:419` reads "In all three routes the packet is
  deleted in the **same reviewer action** that / deletes `.escalated`", and the
  table at :417 marks both `deleted` for the *Fixable a specific way* row.
- D9 confirmed live: `.claude/wiki/conventions.md:33-34` reads
  "`lead-programmer` produces the bundle; `reviewer` / executes `run.sh`".
  `templates/persona-protocol.md:481` reads "Bundles are discovered and executed
  by `lead-programmer` during implementation; bundles are discovered and verified
  by the reviewer as a filesystem presence check (not a diff check), never by
  executing their entries."

**2. CATEGORIZE — spec/criterion defect** (primary), with a content defect
riding on it. The prose is wrong (content), but the reason two review rounds
were burned is that **no acceptance criterion in this unit tests a proposition**.
That routes to this debug spec's revised-criteria path, not to a plain
re-dispatch.

---

## Root-cause diagnosis

Three distinct causes, in decreasing order of leverage. They are not one gap
seen three ways.

### RC1 — The unit's acceptance criteria are orthogonal to its deliverable (primary)

Every gated criterion is an **existence check**: does a term appear, does a file
exist, does the suite exit 0. The unit's product is the **truth value of prose
about shipped mechanisms**. No existence check can fail on a false statement —
`grep -q 'escalation packet' CONTEXT.md` passes identically whether the
surrounding sentence describes the packet correctly or inverts its lifecycle.

Measured consequence: **all six criteria were GREEN at both FAIL verdicts.** The
gate had zero discriminating power across nine defects. The reviewer said so
itself in the record's opening ("FAIL is grounded on correctness of the
deliverable … not on the gated commands").

This is **not a gh138 one-off.** Surveying every `.fail` record in
`.claude/reviewed/` (43 files, 22 `.fail`), the same failure mode has now taken
three separate documentation units:

- `260.fail` — `docs/adr/0015-*.md:46,:116` state the H3 fail-direction rule
  **inverted** relative to `hooks/scripts/dispatch-hygiene.sh:296-300`.
- `gh-286-docs.fail` — user-facing docs advertise two capabilities
  `scripts/agent-audit.sh` does not have; the reviewer's own words: *"this is a
  documentation unit, so the accuracy of these strings IS the deliverable."*
- `gh138.fail` — D8/D9, wiki prose contradicting `templates/persona-protocol.md`.

Three units, one failure mode, three sets of existence-only criteria. The gap is
in how this repo writes acceptance criteria for docs units, and it is systemic.

### RC2 — The dispatch packet carried stale state assertions, and the build agent trusted them over the filesystem

Issue #138 was authored 2026-07-28 and executed 2026-08-11. Two of its
imperatives were **measurements with an expiry**, and both had expired:

- *"Next free numbers are `0007` and `0008` (`docs/adr/` currently holds
  `0001`–`0006`)"* — false by execution time. `docs/adr/` held through `0016`,
  and `0007` is a **deliberately preserved hole** documented by unit #260 /
  `docs/adr/0015-*.md:137` and `CONTEXT.md:412-415`. The agent backfilled `0007`
  exactly as instructed (D3).
- *"Add entries for Microworld, escalation packet, ESCALATE-TO-HUMAN,
  `.escalated` marker, `.directed` marker, `humanReviewMode`"* — **all seven
  target terms already had canonical entries** in `CONTEXT.md` before `36a1cfb`
  (verified: `git show 36a1cfb^:CONTEXT.md | grep -n '^\*\*'` lists every one at
  :528, :538, :564, :579, :589, :599, :637). Header count moved 75 → 82 on the
  build commit and back to 75 on the fix commit — seven appended near-duplicates,
  seven later merged in place (D5).

So D3 and D5 are **not** a generic "didn't look before writing" lapse. They are
one specific lapse: the agent executed a two-week-old packet's *state assertions*
as if they were current, without re-deriving either from the tree. That is the
`baselines expire` trap, and for ADR numbering specifically it is already a
recorded institutional lesson that the packet did not carry.

### RC3 — The de-gated wiki portion drew materially less rigor, in both rounds

Issue #138 labels the wiki refresh "hint-level scope … not separately gated" and
"the unit's PASS/FAIL turns on the gated criteria below". Two readings exist:
*this need not be verified as done* (intended) versus *this is held to a lower
standard* (taken). Evidence for the second:

- `36a1cfb` added 27 lines to `architecture.md` and 11 to `conventions.md`. Both
  D8 and D9 are in those lines.
- `3bfa8eb` (the fix pass) touched `.claude/wiki/` for **two single-character
  edits** (`changelog.md`, `probe-methodology.md`) and **never reopened
  `architecture.md` or `conventions.md` at all** — despite D7, in the same
  round, being the identical class of defect.
- The reviewer likewise missed both on round 1, catching them only on re-review
  and self-reporting the miss. Both sides of the writer/reviewer split
  de-prioritized the same de-gated files.

The record's framing is the correct rule and is worth promoting into the fix
dispatch verbatim: *the "hint-level scope" clause de-gates whether the wiki
refresh was DONE; it does not license shipping a statement about a shipped
mechanism that the canonical source refutes.*

### Not a root cause — the model-routing mistake, and the sonnet fix pass

Round 1 was dispatched on `scribe`'s `haiku` default when the tag was `sonnet`
(an orchestrator dispatch error). That is a real process defect and plausibly
contributed to RC2/RC3, but it is **not** what left D8/D9 standing after round 2.
The round-2 `sonnet` fix pass resolved D1–D7 completely — all seven independently
re-verified by the reviewer, none narration-accepted. It did not introduce D8/D9
and was never asked to look for them. **Sonnet delivered 100% of its dispatch
scope.** This matters for the model recommendation below.

### D10 is the class, not a fourth defect

`.claude/reviewed/gh138.fail`'s D10 (constitution P1, *Verify, don't assume*) is
the generalization of D8/D9, not an independent item. Closing D8 and D9 with the
cross-check ledger below closes D10. No separate step.

---

## Context

- `templates/persona-protocol.md` is the **canonical source** for the marker
  state machine and the microworld-bundle contract. `.claude/wiki/*.md` is a
  derived summary of it. Where they disagree, the template wins — always.
- This unit's own `CONTEXT.md:610-612` and `docs/adr/0017-*.md:53` already state
  both rules correctly. The wiki contradicts **files this same unit wrote**, so
  the correct text is available in-repo and needs no invention.
- D8 has a functional consequence, not just a stylistic one:
  `hooks/scripts/stop-gate.sh:241,249` globs `*.escalated` and keeps the
  pending-review flags standing while one exists. A reviewer following
  `architecture.md`'s bullet would leave `.escalated` in place and thereby block
  the very `lead-programmer` dispatch that same sentence prescribes — the exact
  deadlock `architecture.md:92-95` says `.directed`'s absence from that glob
  exists to prevent.
- **No G1 version bump is required.** Constitution P3 scopes the bump to
  version-stamped files (`agents/*.md`, templates); `.claude/wiki/*.md` carry no
  version stamp, `tests/validate.sh` enforces only `package.json` ↔
  `.claude-plugin/plugin.json` sync, and no hook gates wiki edits on a bump. The
  quartet is already consistent at `0.31.24`. Bumping again would drag in
  `bin/cli.js --update` regeneration noise for a four-clause prose fix.

---

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-08-11 Edge cases / failure handling: Q If the cross-check ledger (Step 4)
  surfaces a *third* wiki claim contradicting canonical source, does the fix
  agent correct it in this unit or report it out? → A (self-resolved): correct it
  in the same pass **only if** it is in `.claude/wiki/architecture.md` or
  `.claude/wiki/conventions.md` and the correction is ≤2 lines; anything larger,
  or in any other file, is reported in the ready-for-review message and left
  untouched. Rationale: the ledger is the whole point of the fix, so suppressing
  its findings would be self-defeating, but an open-ended correction mandate
  reintroduces the scope creep that produced RC2.
- 2026-08-11 Technical constraints & tradeoffs: Q Does a `.claude/wiki/`-only
  prose fix require a G1 version bump and `--update` regeneration? → A
  (self-resolved): no — see Context. Stated explicitly because the prior pass's
  reflex was to bump (`81c197d`), and an unnecessary bump here would produce a
  large regeneration diff around a four-clause fix.
- 2026-08-11 Completion / acceptance signals: Q This unit has consumed both
  2-FAIL-cap slots; does the post-debug-spec re-dispatch consume a third? → A
  (self-resolved): no. The shared protocol's cap text makes the debug-spec →
  `task-master` → re-dispatch route the *sanctioned continuation* after the cap
  is hit, not an extra attempt against it. A FAIL on **this** dispatch is a hard
  stop for human decision — it must not trigger another automated retry loop.

**Terminology check** (`antislop:ubiquitous-language`, prose mode, against
`CONTEXT.md`):
- Lens 1 (term used with a different meaning): none. `escalation packet`,
  `` `.escalated` marker ``, `` `.directed` marker ``, `microworld bundle`,
  `humanReviewMode`, `2-FAIL cap` are all used per `CONTEXT.md:528,571,596,614,630,670`.
- Lens 2 (new synonym for a defined term): one near-miss, disarmed. **claim-anchored
  criterion** is a *subtype* of the glossary's machine-checkable criterion
  (`CONTEXT.md:332`), not a competing name for it; it is labelled as a subtype at
  first use in Step 6 so no reader treats the two as synonyms.
- Lens 3 (load-bearing new term with no entry): two — **claim-anchored criterion**
  and **canonical-source cross-check ledger**. Both are load-bearing here.
  Suggested to `scribe` for `CONTEXT.md` **only if** Open Question 1 is answered
  "yes" and the pattern is adopted repo-wide; a glossary entry for a
  single-use-so-far term would be premature.

---

## Risks and dependencies

- **R1 — Prior FAIL history is durable.** `.claude/reviewed/gh138.fail` records
  two consecutive FAILs across nine defects. Per the shared protocol, this unit
  **must never be tagged `haiku`**, on this dispatch or any future re-scope.
- **R2 — The negative criteria are phrase-anchored.** C1/C6/C7 assert the
  absence of an exact wrong phrase. An agent could satisfy them by rewording
  without fixing the meaning; the paired positive criteria (C2/C4/C5/C8) and the
  Step-4 ledger exist to close that hole. Neither tier is sufficient alone.
- **R3 — Semantic prose correctness is not fully mechanizable.** Stated plainly
  rather than papered over; see Step 6's Tier 2 and its explicit limits.
- **R4 — Fix-agent scope creep.** RC2 was partly an over-broad "add all this"
  instruction meeting a stale packet. Step 1's `Do NOT touch` list and the Step-4
  ledger's ≤2-line cap are the counterweight.
- **Dependency:** none. All four corrections are independent, single-file, and
  the correct text already exists in-repo (`templates/persona-protocol.md`,
  `CONTEXT.md`, `docs/adr/0017-*.md`).

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): **satisfied, and this is the principle the
  unit failed.** Every criterion in Step 6 was executed against current HEAD and
  confirmed RED before publication (see Step 6's preamble and its script); the Step-4
  ledger is P1 applied to prose.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied. No
  hand-edit of any script-driven path; `.claude/persona-config.json` `fileHashes`
  and `.claude/agents/*.md` are on the `Do NOT touch` list.
- P3 "Version-stamp discipline" (MUST): satisfied vacuously — no version-stamped
  file is touched, so no bump is owed. See Context.
- P4 "Optional personas degrade gracefully" (SHOULD): **deviation — disclosed.**
  The D9 fix must reproduce `templates/persona-protocol.md:481`'s unconditional
  "`lead-programmer`" / "the reviewer" phrasing. Hedging it ("if present,
  otherwise…") would re-introduce exactly the paraphrase drift this unit is
  being fixed for. Canonical fidelity outranks a SHOULD here. The reviewer
  already logged this as advisory-only (G3) and noted `tests/validate.sh:140-142`
  does not scan any of this unit's files.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — retained as C9.

---

## Steps

### Step 1 — Scope and boundaries (applies to all steps)

**Owner:** `scribe` (see "Persona routing" below).

- Edit ONLY: `.claude/wiki/architecture.md`, `.claude/wiki/conventions.md`,
  `.claude/wiki/changelog.md`.
- Create nothing. Delete nothing.
- Do NOT touch: `CONTEXT.md`, `docs/adr/`, `templates/`, `agents/`,
  `.claude/agents/*.md`, `.claude/persona-config.json`, `hooks/`, `bin/`,
  `skills/`, `tests/`, `README.md`, `CHANGELOG.md`, `package.json`,
  `.claude-plugin/plugin.json`.
- Do NOT bump any version. Do NOT run `bin/cli.js --update`.
- Do NOT re-litigate any decision recorded in `docs/adr/0017-*.md` or
  `docs/adr/0018-*.md`. Do NOT renumber any ADR.
- **Standing rule, promoted from the FAIL record:** "hint-level scope" de-gates
  whether the wiki refresh was *done*; it never licenses a statement about a
  shipped mechanism that the canonical source refutes. `.claude/wiki/*.md` is a
  derived summary of `templates/persona-protocol.md`; on any disagreement the
  template wins.

**Acceptance:** `git status --porcelain` after the fix lists exactly the three
permitted files and nothing else.

### Step 2 — D8: `.claude/wiki/architecture.md` `direct`-route bullet

**Affected file:** `.claude/wiki/architecture.md:87-90`

Current text (verbatim, lines 87-90):

```
- **Direct a specific fix:** write `.directed` marker carrying the prescribed fix
  verbatim (does NOT consume a cap slot; same logic as `INSUFFICIENT-CONTEXT`),
  dispatch `lead-programmer` for re-review, delete `.escalated` and packet on
  subsequent re-review completion.
```

Required change: the bullet must state that `.escalated` **and the packet** are
deleted in the **same action** that writes the `.directed` marker, and that
`.directed` is the only thing surviving until the next resolution.

Canonical authority: `templates/persona-protocol.md:417` (table row, both columns
`deleted`) and `:419-421`. Corroborated in-repo by `CONTEXT.md:610-612` and
`agents/reviewer.md:233-238`.

Keep the rewritten bullet **within 6 lines of its `- **Direct a specific fix:**`
opener** (criterion C2's window; the current bullet is 4 lines, so there is
headroom). Do not edit the paragraph at :92-95 — it is already correct and is
what the bullet currently contradicts.

**Acceptance:** C1, C2 (Step 6).

### Step 3 — D9: `.claude/wiki/conventions.md` bundle role assignment

**Affected file:** `.claude/wiki/conventions.md:33-34`

Current text (verbatim): "``lead-programmer`` produces the bundle; ``reviewer``
executes ``run.sh``; the ``PostToolUse`` hook re-runs on every edit."

Required change, matching `templates/persona-protocol.md:481`:

- `lead-programmer` **executes** `run.sh` during implementation.
- `reviewer` **verifies bundle presence by filesystem check** (not a diff check)
  and **never executes** a bundle's entries.
- Leave the `PostToolUse` re-run clause as is — it is correct.

Corroborated in-repo by `docs/adr/0017-*.md:53` ("establishes bundle presence by
looking at the filesystem (`ls microworlds/<unit-slug>/`)"), written by this same
unit — the wiki and the ADR currently disagree about the same role.

Per Constitution P4 above: reproduce the canonical unconditional phrasing. Do
**not** hedge with "if present".

**Acceptance:** C3, C4, C5 (Step 6).

### Step 4 — Canonical-source cross-check ledger (the RC3 counterweight)

Before reporting ready-for-review, produce a **cross-check ledger** covering
every sentence this pass adds or edits in `.claude/wiki/*.md` that asserts a
behaviour of a shipped mechanism. One row per sentence:

| claim `file:line` | canonical `file:line` | verbatim canonical quote | claim follows from quote? |
|---|---|---|---|

Rules:
- The canonical citation must be `templates/persona-protocol.md` where the rule
  lives there. `CONTEXT.md`, `docs/adr/`, `agents/*.md` and hook source are
  acceptable corroborating citations but never a substitute for the template
  when the template speaks.
- A row whose last column is anything other than "yes" is a defect to fix, not a
  row to ship.
- The ledger goes in the ready-for-review message body. Do not create a report
  file for it.
- If the ledger surfaces a third contradicting claim, apply the Clarifications
  rule: correct it in-pass only if it is in one of the two wiki files and ≤2
  lines; otherwise report it and leave it alone.

**Acceptance:** C10 (Step 6).

### Step 5 — Folded-in accuracy notes (non-blocking in the FAIL record; gated here)

Both are one-clause fixes in files Steps 2–3 already open, so marginal cost is
near zero, and both are the same class of error the unit is being fixed for —
a false statement about this repo's own history. Gating them is proportionate.

**5a — `.claude/wiki/changelog.md:8`.** Currently: "Unit #138 … **added six
glossary entries** to `CONTEXT.md`". Both halves are wrong. Nothing was added —
all seven terms already had canonical entries before `36a1cfb`, the build
appended near-duplicates, and `3bfa8eb` merged every pair in place. And the count
is **seven**, not six (`grep -c '^\*\*' CONTEXT.md`: 75 → 82 → 75; the reviewer's
D5 note says "all seven pairs merged in place"). Replace with a clause stating
the entries were **amended in place**, correcting the count to seven.
*Acceptance: C6.*

**5b — `.claude/wiki/architecture.md:72`.** Currently: "(unit #138: defaults to
`critical`, on-by-default)". The `critical` default shipped at **unit #135**
(`119cd06`, `77f0847`; `bin/cli.js:2104`); #138 documented it. Re-attribute to
#135, optionally noting #138 recorded it. Do **not** additionally claim #138
flipped this repo's live config value — `81c197d` did carry that flip, but it
was the orchestrator's bootstrap-window restoration riding in #138's commit
(`.claude/wiki/changelog.md:110-123`), and conflating the two would introduce a
fresh inaccuracy while fixing one.
*Acceptance: C7, C8.*

### Step 6 — Revised acceptance criteria

Replacing the unit's existence-only gates. **Every criterion below was executed
against HEAD `3bfa8eb` on 2026-08-11 and confirmed RED** — each one currently
fails, so none is vacuous, and each would have caught its defect at build time.
The block was then extracted back out of this document and re-run verbatim, so
what is published is what was verified.

#### Tier 1 — claim-anchored criteria (fully mechanical, run from repo root)

A *claim-anchored criterion* is a subtype of this repo's machine-checkable
criterion (`CONTEXT.md:332`): it names one specific false proposition to be
absent and one specific canonical proposition to be present. Each defect gets
both halves; neither half is sufficient alone.

Run from the repo root. Verbatim and runnable as-is — C1–C8 each exit non-zero
today and must all exit zero after the fix; C9 is green today and must stay green.

```sh
set -u; fail=0
p(){ if [ "$2" -eq 0 ]; then echo "$1 PASS"; else echo "$1 FAIL"; fail=1; fi; }

# C1  D8 negative — the wrong deletion-timing phrase is gone
grep -q 'subsequent re-review completion' .claude/wiki/architecture.md; p C1 $((1-$?))
# C2  D8 positive — the direct bullet asserts same-action deletion
grep -A 6 'Direct a specific fix' .claude/wiki/architecture.md | grep -q 'same action'; p C2 $?
# C3  D9 negative — the reviewer is NOT said to execute run.sh
tr '\n' ' ' < .claude/wiki/conventions.md | grep -qE '`reviewer`[^.;]*executes `run\.sh`'; p C3 $((1-$?))
# C4  D9 positive — lead-programmer IS said to execute run.sh
tr '\n' ' ' < .claude/wiki/conventions.md | grep -qE '`lead-programmer`[^.;]*executes `run\.sh`'; p C4 $?
# C5  D9 positive — the reviewer's side is stated as a filesystem check
grep -q 'filesystem' .claude/wiki/conventions.md; p C5 $?
# C6  note 5a negative — the "added six" narrative is gone
grep -q 'added six glossary entries' .claude/wiki/changelog.md; p C6 $((1-$?))
# C7  note 5b negative — the #138 misattribution is gone
grep -q 'unit #138: defaults to' .claude/wiki/architecture.md; p C7 $((1-$?))
# C8  note 5b positive — #135 is credited
grep -q 'unit #135' .claude/wiki/architecture.md; p C8 $?

# C9  regression gate (constitution P5)
bash tests/validate.sh >/dev/null 2>&1; p C9 $?
exit $fail
```

Two notes on why the commands are shaped this way, both found by running them:

- **C3/C4 flatten newlines first.** The current text wraps mid-clause
  ("`` `lead-programmer` `` produces the bundle; `` `reviewer` `` / executes
  `` `run.sh` ``"), so a line-oriented grep for `` executes `run.sh` `` cannot
  tell the wrong subject from the right one — it matches either way.
- **The regex patterns must be single-quoted.** In double quotes, bash reads the
  backticks in `` `reviewer` `` and `` `lead-programmer` `` as **command
  substitution**: the pattern silently collapses to `[^.;]*executes ` and C4
  passes against the unfixed file. This was hit for real while verifying this
  spec, and it is the same vacuous-criterion failure the spec exists to fix —
  do not "tidy" the quoting.

#### Tier 2 — the cross-check ledger (partially mechanical; limits stated)

**A fully mechanical check for semantic prose correctness is not feasible, and
this spec does not pretend otherwise.** No command can decide whether an English
sentence follows from a cited paragraph. Inventing a gate that appears to do so
would repeat RC1 in a new costume. The strongest available verification is a
two-part procedure:

- **C10a (mechanical).** Every canonical citation in the Step-4 ledger must
  resolve: for each `file:line`, the file exists, the line exists, and the row's
  verbatim quote is a substring of that line. A reviewer can run this as a loop
  over the ledger rows — pass/fail, no judgment. This catches fabricated,
  transposed, and drifted-by-edit citations, which is the mechanical share of
  the failure mode.
- **C10b (procedural, reviewer-judged).** For each ledger row, the reviewer reads
  the quote and the claim and confirms the claim follows. This is the residual
  judgment C10a cannot absorb. It is *tractable* only because the ledger bounds
  the work to the sentences the pass actually touched and pairs each with its
  source — which is precisely what was missing in rounds 1 and 2, where 38 new
  wiki lines shipped with no source pairing at all.

Reporting ready-for-review without the ledger is itself a defect: C10a has
nothing to run against, and the unit reverts to the criteria posture that failed
twice.

---

## Persona routing

**`scribe`.** Preserved, and no reason was found to change it. `agents/scribe.md:16`
names `CONTEXT.md` and `docs/adr/` as scribe-canonical, and `.claude/wiki/` is
scribe's own surface. All four corrections are prose in scribe-owned files; the
unit adds no mechanism and changes no behaviour. Routing to `lead-programmer`
would put a code persona in the wiki for a four-clause edit and lose the
canonical-source ownership that Step 4 depends on.

Note for the orchestrator: dispatch on the **tagged** model, not on `scribe`'s
persona default. The round-1 dispatch fell through to `scribe`'s `haiku` default
against a `sonnet` tag, and that mistake is upstream of RC2/RC3.

## Suggested model — input to `task-master`'s dispatch decision

Model tagging is `task-master`'s call. This section supplies the evidence.

**Recommendation: `sonnet`.** `haiku` is **excluded outright** — R1, prior FAIL
history.

This is a **disclosed deviation from the project rule** "haiku escalates to
sonnet on first FAIL, sonnet FAIL escalates to opus", stated as a deviation
rather than argued away. The rule's premise is that the sonnet attempt proved
insufficient *for the work it was given*. That premise does not hold here:

- The `sonnet` fix pass (`3bfa8eb`) resolved D1–D7 completely — seven defects,
  all independently re-verified by the reviewer rather than accepted from the
  pass's own narration.
- D8/D9 were introduced by `36a1cfb`, the **`haiku`** build, and the sonnet pass
  was never asked to look at them. The reviewer states this outright and
  self-reports missing both on round 1.
- The remaining work is the least judgment-heavy dispatch this unit has had:
  four one-to-two-line prose corrections, with exact `file:line` anchors, exact
  canonical `file:line` sources, verbatim current text, eight pre-verified-RED
  criteria plus a regression gate, and the correct wording already present in-repo.

Escalating to `opus` would treat a haiku-introduced defect as evidence against
sonnet. The stronger lever here is the **criteria**, which this spec replaces
wholesale, not the model.

**Counter-argument, stated fairly:** the failure mode is semantic prose accuracy,
which is judgment-shaped, and a third FAIL is a hard human-decision stop (see
Clarifications) rather than another automated retry — so the cost of
under-resourcing is asymmetric. `opus` is a defensible no-argument fallback and
the orchestrator should feel free to take it; see Open Question 2.

---

## Open Questions

1. **Should the RC1 systemic gap get its own spec?** Three documentation units
   (`260`, `gh-286-docs`, `gh138`) have now failed on prose that contradicts
   shipped behaviour, each behind existence-only criteria. A reusable check —
   e.g. a `tests/` assertion that enumerated wiki↔`templates/persona-protocol.md`
   propositions agree, or a standing requirement that every docs-unit spec carry
   claim-anchored criteria — would attack the class rather than this instance.
   *Recommended default: yes, as a separate spec, not folded into this unit.*
   Options: (a) separate spec, later; (b) fold into this unit now; (c) drop.
   (b) is explicitly not recommended — it is the scope creep of RC2.
   **Not blocking:** this unit proceeds unchanged under (a) or (c).
2. **Override the model recommendation to `opus`?** See the counter-argument
   above. *Recommended default: no — dispatch `sonnet`.* Options: (a) `sonnet`;
   (b) `opus`. **Not blocking:** `task-master` owns the tag either way.
3. **Ledger retention.** The Step-4 ledger lives in the ready-for-review message
   and is not persisted. *Recommended default: leave it ephemeral* — the
   reviewer may append it to the `.pass` marker's non-blocking-notes section if
   it judges the pairing worth keeping, which is the existing mechanism for
   exactly this and needs no new artifact. **Not blocking.**

---

## Self-check

- CHK1: Is every acceptance criterion in Step 6 verified non-vacuous rather than
  asserted to be? — PASS (all nine executed against HEAD `3bfa8eb`; C1–C8 RED,
  C9 GREEN, aggregate exit 1)
- CHK2: Do the Goal, Step 1's file list, and Step 6's criteria agree on which
  files may change? — PASS (all three name exactly `.claude/wiki/architecture.md`,
  `conventions.md`, `changelog.md`; C9 is a repo-wide regression gate, not an
  edit permission)
- CHK3: Does the plan define what happens when the Step-4 ledger finds a defect
  beyond D8/D9? — PASS (Clarifications, edge-cases line; restated at Step 4's
  final bullet with the same ≤2-line and two-file bounds)
- CHK4: Is the "machine-checkable" claim honest, per this repo's own definition
  (something an agent can RUN for a pass/fail)? — FAIL (ambiguous) — revised in
  place: Tier 2 was originally written as a single "cross-check" criterion that
  read as mechanical but was not runnable. Split into C10a (runnable citation
  resolution) and C10b (explicitly reviewer-judged), with the infeasibility of a
  full mechanical check stated outright per the dispatch's own instruction not to
  invent a fake gate.
- CHK5: Do the diagnosis and the criteria agree on *why* the gated criteria
  failed to catch D1–D9? — PASS (RC1 states the orthogonality; the `fail-triage`
  VERIFY table shows all six GREEN at current HEAD; Step 6's preamble ties the
  replacement to it)
- CHK6: Is the attribution correction in C7/C8 verified, not transcribed from the
  FAIL record? — PASS (`git log -S` on `hooks/ bin/ templates/` returns
  `119cd06 feat(gh135): fresh-install skeleton ships humanReviewMode: critical`
  and `77f0847 feat(gh135): document humanReviewMode in the persona-config schema`;
  `bin/cli.js:2104` carries the default. #138's `81c197d` flipped this repo's own
  live config value — a distinct fact, and the reason `architecture.md:72`'s
  claim about the *default* is misattributed)
- CHK7: Is note 1's correction factually right about the count? — FAIL (missing) —
  revised in place: the FAIL record and `changelog.md:8` both say "six"; the
  actual number is **seven** (`grep -c '^\*\*' CONTEXT.md` = 75 before `36a1cfb`,
  82 after, 75 after `3bfa8eb`; the reviewer's own D5 note says "all seven pairs
  merged in place"). Step 5 now specifies seven-amended-in-place, so the
  correction does not ship a second wrong number.
- CHK8: Does the plan state whether a version bump is owed, given the prior pass
  bumped? — FAIL (missing) — revised in place: added to Context and to
  Constitution check P3, with the enforcement surfaces checked
  (`tests/validate.sh:34-40` covers only the package/plugin pair; no hook gates
  wiki edits).
- CHK9: Do the Constitution check and Step 3 agree on the P4 hedging question? —
  PASS (P4 records the disclosed deviation; Step 3's final line instructs
  canonical unconditional phrasing and forbids "if present"; no third statement
  contradicts either)
- CHK10: Is every Open Question traceable to a decision this spec declined to
  make unilaterally, and is each non-blocking? — PASS (OQ1 from RC1's systemic
  finding, OQ2 from the model-rule deviation, OQ3 from Step 4's artifact; all
  three marked not blocking, so `task-master` can slice without waiting)

- CHK11: Is the criteria block executable exactly as published, or only as it was
  drafted? — FAIL (ambiguous) — revised in place: Tier 1 was first written as a
  markdown table, whose cells contain both `|` and backticks; the C3/C4 patterns
  contain literal backticks, so the code spans terminated early and the published
  command was not the verified one. Replaced with a fenced `sh` block, which was
  then extracted from this document and re-run verbatim (C1–C8 FAIL, C9 PASS,
  aggregate exit 1). A related trap found by the same run is now documented under
  the block: double-quoting the patterns turns the backticks into command
  substitutions and makes C4 pass against the unfixed file.

Re-check of the four FAILs after the single revision pass: CHK4, CHK7, CHK8 and
CHK11 all PASS. No item remains failing, so no item needed conversion to an Open
Question.

---

## Out of scope

- **G3 / Constitution P4 advisory** — bare unconditional `reviewer` references at
  `docs/adr/0017-*.md:51-53` and in the two wiki files. Advisory in the FAIL
  record, and for the sentences Steps 2–3 rewrite it is actively counterproductive
  (Constitution check, P4). Not gated, not fixed.
- **`CHANGELOG.md:25`'s present-tense "keeps `humanReviewMode: off` for now"** —
  sits under the released `[0.31.22]` heading, correctly describes that release's
  state, pre-existing and not this unit's. The reviewer left it deliberately;
  so does this spec. Rewriting a dated release record to match today's state
  would be a defect, not a fix.
- **D1–D7** — resolved and independently re-verified in round 2. Not reopened.
- **`CONTEXT.md` and the two ADRs** — already correct on both D8's and D9's
  subject matter (`CONTEXT.md:610-612`, `docs/adr/0017-*.md:53`). They are the
  *reference* for this fix, not a target of it.
- **The RC1 systemic remedy** — Open Question 1; a separate spec if adopted.
- **Any version bump or `--update` regeneration** — see Context.

---

## Handoff

To `task-master`, for `to-tickets` slicing and per-unit dispatch-prompt
authoring, per this project's rule that any debug-spec re-derivation routes
through `task-master` regardless of unit count. This spec files no tracker issue
itself; issues are filed one-per-step under the `plan/<slug>` label by
`task-master`.

This document is the canonical artifact.

## Scribe update hint

Nothing for `scribe` beyond the fix itself — this debug spec introduces no
mechanism, no term that has earned a `CONTEXT.md` entry yet (see the
Clarifications terminology check, lens 3), and no decision warranting an ADR.
If Open Question 1 is answered "yes", the resulting spec — not this one — is
where `claim-anchored criterion` and `canonical-source cross-check ledger` would
earn glossary entries.
