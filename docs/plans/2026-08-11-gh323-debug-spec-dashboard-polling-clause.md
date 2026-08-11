# Debug spec — gh323 (Step D10) false "pull-on-request throughout" clause

**Artifact type:** debug spec (2-FAIL-cap escalation), per the shared persona
protocol. This is a focused diagnostic plus revised acceptance criteria for
one clause — **not** a replan of Step D10. Step D10's scope, deliverables,
routing, and its 14-check criteria block (revision 3) all stand unchanged;
this spec adds one corrective edit and one new criteria block on top.

- **Unit:** `gh323` — GitHub issue #323, repo `Storreslara/AntiSlop`
- **Spec of record:** `docs/plans/2026-08-10-microworld-dashboard.md`, Step
  D10 (revision 3, Milestone M3)
- **Latest FAIL record:** `.claude/reviewed/gh323.fail` (2026-08-11T20:31:44Z)
- **Commits under diagnosis:** `0f3a0e0` (build) → `9fe3021` (fix pass)
- **Cap status:** both 2-FAIL-cap slots consumed. See "Hard stop" below.

## Goal

Delete one false clause from `.claude/wiki/architecture.md:105` and replace it
with the mechanism that actually ships, so the wiki stops contradicting the
canonical glossary entry at `CONTEXT.md:854`; and replace the criteria that
structurally could not have caught it with a RED-verified block that can.

Blast radius: **one paragraph, one file.** A repo-wide sweep confirms the
false claim exists nowhere else — `grep -rniE 'pull-on-request|re-renders
live|never re-render' --include='*.md' .` returns exactly one non-memory hit,
`.claude/wiki/architecture.md:105`.

## `fail-triage` front-half (VERIFY → CATEGORIZE)

**VERIFY — could not reproduce via criteria; reproduced against source.**
Re-ran Step D10 revision 3's full C1–C14 block fresh against HEAD (`9fe3021`),
not read from the FAIL record's text:

```
C1..C14 all PASS, aggregate exit 0
```

So every acceptance criterion the unit was given is **green while the defect
stands**. The defect reproduces only against source:

```
$ grep -n setInterval bin/dashboard/index.html
570:    setInterval(pollBundles, 5000);
```

`pollBundles` (`index.html:573–579`) awaits `refreshBundles()` → `GET
/api/bundles` → `discover()` → `parseAuditLog()`, then calls
`renderLeftRail()` (`index.html:124`), which re-renders the audit-log-derived
status indicator this very paragraph documents. The wiki clause "Nothing
re-renders live or push-style; the dashboard is pull-on-request throughout"
is false as written, and directly contradicts `CONTEXT.md:854`
(**Microworld dashboard client**, unit #318, commit `c9b3e87`): "live status
indicator (pass/fail/timeout/unknown) polled every 5s via `setInterval`".

**CATEGORIZE — spec/criterion defect** (not a code defect). No shipped code
is wrong; the prose about it is wrong, and the criteria are incapable of
detecting that class of wrongness. Routes to this debug spec's revised-criteria
path, not back to `lead-programmer` as a normal FAIL.

## Root-cause diagnosis

### RC-A — Neither authoring round ever opened the client file (primary, unit-specific)

This was checked empirically rather than inferred, against the on-disk
transcript store (`~/.claude/projects/-home-sebas-AntiSlop/<session>/subagents/`),
counting tool calls whose input names `bin/dashboard/index.html`:

| Round | Agent | `index.html` tool calls |
|---|---|---|
| Build (`0f3a0e0`) | `scribe` | **0** |
| Fix pass (`9fe3021`) | `scribe` | **0** |
| Review round 1 | `reviewer` | 1 — grepped `fresh process\|no state\|independent` (the Cell/state claim), never render/push behaviour |
| Review round 2 | `reviewer` | 3 — read `555–585`, `90–120`, `118–132`; **found the defect** |

The finding is precise: **the client file was never read by the authoring
persona in either round**, and review round 1's single touch was scoped to a
different claim, which is why round 1's version of the paragraph (also wrong
about the client, per prior defect 4) survived that review. The fix pass then
did exactly what its evidence supported — it corrected the server-side facts
against `server.js`, `discover.js`, `audit-log.js`, and `microworld-rerun.sh`,
all correctly (7 of 8 defects genuinely resolved) — and then extended a
server-side observation into a **whole-system negative** ("throughout") about
the half of the system it had not opened.

The generalizable rule: a claim of the form *"nothing in the system does X"*
requires reading every component that could do X. Server-side evidence can
support "the server never pushes"; it can never support "nothing re-renders
live". The failure is one of **quantifier scope**, not of care.

### RC-B — Instance of RC1 from the gh138 debug spec (criteria orthogonal to deliverable)

`docs/plans/2026-08-11-gh138-debug-spec-wiki-accuracy.md` RC1 recorded that
existence-only criteria are structurally incapable of catching false prose.
This unit is a textbook second instance, and a sharper one: D10 revision 3's
criteria block was itself carefully built and RED-verified (C1–C7, C9–C13),
yet its only architecture.md check is `grep -qi 'dashboard'` (C12) — satisfied
by any prose whatsoever containing the word. The VERIFY step above is the
proof: C1–C14 aggregate to exit 0 with the false clause in place. Rigour in
*constructing* claim-anchored criteria does not help if no criterion is
anchored to the specific claim that turns out to be wrong.

### RC-C — Instance of RC3 (the wiki half draws less scrutiny than the gated half)

gh138's RC3 recorded that de-gated wiki sections draw materially less rigor.
Consistent here: `CONTEXT.md` and ADR-0019 carry eleven of the fourteen
criteria between them; `.claude/wiki/architecture.md` carries one, and it is
the weakest in the block. Both of this unit's FAILs landed in
`architecture.md`, and only there.

**Not a root cause:** the model tier. See "Suggested model" below.

## Context

- The paragraph under repair is the "Audit-log contract (bash producer, Node
  consumer)" paragraph, currently `.claude/wiki/architecture.md:105`.
- Everything in that paragraph *except* its final clause is verified correct
  by the FAIL record against source (producer, path, format, contract test,
  per-request consumption, the `fs.watch` no-op). The correction must be
  surgical: keep the correct server-side denial, replace only the false
  whole-system negative.
- `CONTEXT.md:854` is pre-existing canon from unit #318, untouched by this
  unit and not in dispute. The wiki moves to agree with it; the glossary does
  not move.
- Canonical vocabulary (`CONTEXT.md`), **verified headword-by-headword against
  the file, not taken from this unit's dispatch prose** — the dispatch that
  commissioned this debug spec referred to "Microworld dashboard client", and
  `grep -n 'Microworld dashboard client' CONTEXT.md` returns **nothing**. The
  three real headwords in this area are:
  - `CONTEXT.md:755` **Microworld dashboard** — the loopback HTTP server/UI
    process as a whole (server *and* client).
  - `CONTEXT.md:849` **D5 browser client** — the static single-file HTML client
    `bin/dashboard/index.html`. **This is the entry whose line 854 records the
    "polled every 5s via `setInterval`" fact**, and therefore the entry the
    wiki is being reconciled to.
  - `CONTEXT.md:543` **Microworld** — an individual bundle's rendered entry.

  The replacement clause must not mint a new bolded headword. "browser client"
  as plain descriptive prose is already the canonical wording *inside* the
  **D5 browser client** entry, so it is aligned rather than divergent; what
  would be a violation is introducing a competing bolded term (e.g.
  "**Microworld dashboard client**", "**frontend**") as if it were canon.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-11 Edge cases / failure handling: Q Does the same false claim appear
  anywhere else in the repo, making this a sweep rather than a one-line fix?
  → A (self-resolved): no — `grep -rniE 'pull-on-request|re-renders
  live|never re-render' --include='*.md' .` returns one non-memory hit,
  `.claude/wiki/architecture.md:105`. One clause, one file, no sweep needed.
- 2026-08-11 Terminology consistency: Q Does the replacement clause risk
  minting a synonym for an already-defined glossary term? → A (self-resolved):
  yes, and this spec's own first draft did it. The draft instructed `scribe`
  to use "the canonical glossary headword **Microworld dashboard client**" —
  a term that **does not exist in `CONTEXT.md`**, inherited unverified from
  this unit's own dispatch prose. `grep -n '^\*\*.*\*\*' CONTEXT.md | grep -iE
  'dashboard|client'` returns only **Microworld dashboard** (:755) and **D5
  browser client** (:849). Corrected in Context and in Step 2's boundaries.
  Noted without flinching: this is the same error class as the defect under
  repair — a claim about a file's contents asserted without opening it at the
  cited line. `ubiquitous-language` prose-mode lenses over this spec: lens 1
  (divergent meaning) — the *defect under repair* is exactly this, "live" used
  with the opposite polarity from `CONTEXT.md:854`; lens 2 (new synonym) —
  one, found and removed, described above; lens 3 (undefined new term) — none.
  The constraint stays stated in Step 2's boundaries rather than mechanically
  gated, since a wording gate would over-constrain a one-clause edit.
- 2026-08-11 Completion / acceptance signals: Q What criteria would have
  caught this, and are they non-vacuous? → A (self-resolved): the eight-check
  block in Step 3, each of C-N1..C-P4 confirmed RED against HEAD and C-G1/C-G2
  confirmed green, run before publication (transcript in Step 3).

## Risks and dependencies

- **R1 — prior FAIL history is durable.** `.claude/reviewed/gh323.fail`
  exists and records two rounds. `haiku` is excluded outright for the
  re-dispatch. This unit needed judgment the criteria could not supply, twice.
- **R2 — over-correction risk.** The fix must not delete or weaken the
  correct server-side statements the fix pass got right; C-G1 gates this.
- **R3 — line-number anchors go stale.** The replacement clause cites
  `index.html:570` and `index.html:124`. This is the wiki's established
  convention (the same paragraph already cites `microworld-rerun.sh:19-26`,
  `:22-24`), and staleness is an accepted, already-recorded cost of that
  convention (`CONTEXT.md`'s **Function location** entry records the same
  tradeoff). Not re-litigated here.
- **R4 — scope creep into the dashboard source.** `bin/dashboard/**`,
  `tests/**`, and `README.md` remain outside this unit, as in D10.
- **D1 — depends on nothing.** Step D10's other deliverables are landed and
  verified; this spec touches one paragraph of one already-modified file.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — and it is the principle the FAIL
  record cites as violated (defect 3). This spec's Step 2 requires the
  executing persona to read `bin/dashboard/index.html` first-hand before
  writing the clause, and Step 3's criteria were each executed against HEAD
  before publication rather than asserted.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  correction is gated by a runnable eight-check block, not by re-reading prose.
- P3 "Version-stamp discipline": satisfied — documentation-only correction
  inside an already-stamped unit; no version bump warranted, and inventing one
  would be the deviation.
- P4 "Optional personas degrade gracefully" (SHOULD): not applicable — no
  persona-optionality surface is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied — C-G3 re-runs it, and
  Step D10's full C1–C14 block is re-run as a regression gate.

## Steps

### Step 1 — Scope and boundaries (applies to all steps)

**Affected files (the complete list):**
- `.claude/wiki/architecture.md` — one paragraph, its closing clause only.

**Do NOT touch:** `CONTEXT.md` (its entry is correct canon and is what the
wiki is being reconciled *to*), `docs/adr/0019-*.md`,
`.claude/wiki/conventions.md`, any `bin/dashboard/**` source file, `tests/**`,
`README.md`, `docs/plans/2026-08-10-microworld-dashboard.md`, or any other
wiki page. No new file is created by this spec.

**Acceptance criterion (scope gate):**

```sh
test "$(git diff --name-only HEAD -- . | grep -v '^\.claude/agent-memory/' | tr '\n' ' ' | xargs)" = ".claude/wiki/architecture.md"
```

### Step 2 — Replace the false clause in the audit-log paragraph

**Affected files:** `.claude/wiki/architecture.md` (the `**Audit-log contract
(bash producer, Node consumer):**` paragraph, currently line 105).

**Required first action (P1, and the direct RC-A counterweight):** read
`bin/dashboard/index.html` around lines 560–585 (`init`, `pollBundles`) and
around line 124 (`renderLeftRail`) first-hand, before writing a word. Do not
write this clause from the FAIL record's summary or from this spec's prose
alone — the entire root cause of both FAILs is a claim about that file
written without opening it.

**The edit:** delete the clause `Nothing re-renders live or push-style; the
dashboard is pull-on-request throughout.` and replace it with prose that
(a) keeps the correct server-side denial, and (b) states the shipped
client-side mechanism with file:line anchors. Suggested text, for `scribe` to
adapt — the criteria gate the facts, not this exact wording:

> The server therefore never pushes. Keeping status fresh is the dashboard's
> browser client's job instead: after the initial render, `index.html:570`
> registers `setInterval(pollBundles, 5000)`, so the client re-issues `GET
> /api/bundles` every 5s and re-renders the left rail's audit-log-derived
> status indicator (`renderLeftRail`, `index.html:124`) with no user action —
> pull, but polled, not pull-on-request.

**Boundaries specific to this step:**
- Do not weaken or delete the preceding sentences — the producer hook, the
  log path, the `key=value` format, the contract test, "invoked **per
  request** ... never on startup", and the `fs.watch` no-op are all verified
  correct and must survive verbatim in substance.
- **Do not mint a new bolded glossary term.** "Microworld dashboard client"
  is **not** a headword in `CONTEXT.md` — do not use it. The real headwords
  are **Microworld dashboard** (`:755`, the whole process) and **D5 browser
  client** (`:849`, `bin/dashboard/index.html`, the entry whose line 854 is
  being reconciled to). Plain descriptive prose ("the dashboard's browser
  client") is fine and matches that entry's own wording; a new bolded term is
  not.
- Do not assert any new whole-system negative in the replacement. If a
  negative is genuinely needed, scope it to a named component ("the server
  never pushes"), never to "the dashboard" or "throughout".

**Acceptance criteria:** the C-N/C-P/C-G block in Step 3, aggregate exit 0.

### Step 3 — Revised acceptance criteria (RED-verified 2026-08-11)

Every command below was executed against HEAD (`9fe3021`) before this spec was
published. **C-N1, C-N2, C-P1, C-P2, C-P3, C-P4 were each confirmed RED (the
`p` helper printed FAIL)**, so none is vacuous. **C-G1 and C-G2 are stated
exceptions** — explicit non-regression guards, already green today, which must
stay green; this is the same guard pattern
`docs/plans/2026-08-11-gh138-debug-spec-wiki-accuracy.md` Step 6 uses.

Observed transcript at publication time:

```
C-N1 FAIL   C-N2 FAIL   C-P1 FAIL   C-P2 FAIL
C-P3 FAIL   C-P4 FAIL   C-G1 PASS   C-G2 PASS
```

```sh
set -u; fail=0
p(){ if [ "$2" -eq 0 ]; then echo "$1 PASS"; else echo "$1 FAIL"; fail=1; fi; }

W=.claude/wiki/architecture.md
# Paragraph-scoped extraction: headword line through the next blank line, so a
# reflowed paragraph still matches. Positives are scoped to this paragraph so
# they cannot be satisfied by polling prose written somewhere else in the file.
PARA=$(awk '/\*\*Audit-log contract/,/^[[:space:]]*$/' "$W")

# --- Negatives: the false claim is gone (whole file, not just the paragraph)
# C-N1  the "pull-on-request" whole-system claim is absent
! grep -qi 'pull-on-request' "$W"; p C-N1 $?
# C-N2  the "nothing re-renders" whole-system negative is absent
! grep -qiE 'nothing re-renders|never re-renders' "$W"; p C-N2 $?

# --- Positives: the real mechanism is stated, in this paragraph
# C-P1  the paragraph names polling
printf '%s' "$PARA" | grep -qi 'poll'; p C-P1 $?
# C-P2  the paragraph names the 5s interval
printf '%s' "$PARA" | grep -qE 'every 5s|5000|5 seconds'; p C-P2 $?
# C-P3  the paragraph carries the file:line anchor for the polling call
printf '%s' "$PARA" | grep -qF 'index.html:570'; p C-P3 $?
# C-P4  the paragraph names the route the client re-issues
printf '%s' "$PARA" | grep -qF 'GET /api/bundles'; p C-P4 $?

# --- Guards: green today, must stay green (R2 — no over-correction)
# C-G1  the correct server-side facts survive the edit
printf '%s' "$PARA" | grep -qF 'fs.watch' \
  && printf '%s' "$PARA" | grep -qF 'never on startup'; p C-G1 $?
# C-G2  the glossary canon this reconciles to is untouched
grep -qF 'polled every 5s' CONTEXT.md; p C-G2 $?
# C-G3  merge gate (constitution P5)
bash tests/validate.sh >/dev/null 2>&1; p C-G3 $?
exit $fail
```

**Additionally, re-run Step D10 revision 3's full C1–C14 block unchanged**
(`docs/plans/2026-08-10-microworld-dashboard.md`, Step D10, "Acceptance
criteria") — it must still aggregate to exit 0. It is a pure regression gate
here; it was green at the time of the FAIL and its greenness is precisely what
this block exists to supplement.

Two notes on shape:
- **The negatives are whole-file, the positives are paragraph-scoped.** A
  whole-file positive would let correct polling prose land in some other
  section while the audit-log paragraph stayed wrong; a paragraph-scoped
  negative would let the false clause survive by being moved.
- **C-P3 pins a file:line anchor, not just a mechanism word.** Per RC-A, the
  failure mode is asserting client behaviour without opening the client file;
  requiring the anchor makes the assertion cite its own evidence.

## Open Questions

None. Both categories scored Partial and the one scored Missing were resolved
against the filesystem and recorded in Clarifications; nothing here requires
information only the user has.

## Hard stop on the next verdict

This unit has now consumed **both** 2-FAIL-cap slots. Applying the same
convention used for gh138's cap-hit continuation: **a FAIL on the re-dispatch
produced from this debug spec is a hard stop for human review, not another
automated retry.** The orchestrator must not re-dispatch `scribe`, must not
commission a second debug spec, and must not route around the verdict — it
surfaces the full three-round defect history to the user and stops. A PASS
closes the unit normally.

## Routing — persona

**`scribe`.** Confirmed, unchanged from D10's established routing:
`.claude/wiki/` is inside `scribe`'s declared write scope, the deliverable is
institutional-knowledge prose, and no source, test, or build surface is
touched. There is no reason to move this to `lead-programmer` — the categorized
root cause is a spec/criterion defect over documentation, which is `scribe`'s
surface by definition.

## Suggested model — input to `task-master`'s dispatch decision

Model tagging is `task-master`'s call; this section supplies the evidence.

**Recommendation: `sonnet`.** `haiku` is **excluded outright** — R1, prior
FAIL history.

This is a **disclosed deviation** from the project rule "sonnet FAIL escalates
to opus", stated as a deviation rather than argued away. The rule's premise is
that the sonnet attempt proved insufficient *for the work it was given*. That
premise does not hold cleanly here:

- The `sonnet` fix pass (`9fe3021`) resolved seven of eight defects, each
  verified against source by an adversarial reviewer that re-derived rather
  than trusted — including the subtle ones (all four `result=` values
  reachable, the seven-field manifest schema matching the protocol exactly,
  the ADR link depth, the `shell: false` argv detail).
- The one miss is a **quantifier-scope error over an unread file** (RC-A), not
  a reasoning failure. The corrective information — which file, which lines,
  which functions, and the contradicting glossary line — is now handed over
  explicitly in Step 2, and Step 2 makes reading that file a required first
  action.
- The criteria that let it through are now closed mechanically (Step 3,
  RED-verified). The failure mode no longer depends on the model noticing
  anything: writing the wrong clause now fails a check.

Escalating to `opus` here would be paying for judgment on a task whose
judgment has been removed and replaced by a gate. The honest counterweight,
stated so the decision is made with both halves visible: **the cost of a third
FAIL is now maximal** (hard stop, human escalation, per above), and `opus` is
cheap insurance for a single-paragraph edit. If `task-master` weighs that
downside above the evidence, `opus` is a defensible override of this
recommendation and needs no further consultation with `spec-master`.

## Self-check

- CHK1: Is the exact false clause to be deleted identified verbatim, so the
  executing persona cannot delete the wrong sentence? — PASS
- CHK2: Do Step 2's boundaries and Step 3's C-G1 agree about which parts of
  the paragraph must survive? — PASS (C-G1 gates `fs.watch` and "never on
  startup"; Step 2's boundaries name the same set plus the producer/path/
  format sentences, which C-G1 does not gate — a deliberate, disclosed
  asymmetry, since gating every surviving sentence would forbid legitimate
  copy-editing).
- CHK3: Is every new criterion demonstrated non-vacuous rather than asserted
  to be? — PASS (Step 3 records the observed RED/green transcript, and the
  guards are labelled as stated exceptions).
- CHK4: Is the "one clause, one file" blast-radius claim backed by a run
  command, not an assumption? — FAIL (missing) — revised in place; the sweep
  command and its result are now in Goal and in the Clarifications log.
- CHK5: Does the spec say what happens if the re-dispatch FAILs? — FAIL
  (missing) — revised in place; "Hard stop on the next verdict" added.
- CHK6: Is the RC-A transcript claim ("neither round read the client file")
  stated as a measurement with a stated method, rather than an inference? —
  PASS (method and per-round counts tabulated).
- CHK7: Do the model recommendation and R1 agree about `haiku`? — PASS (both
  exclude it outright, on the same ground).
- CHK8: Is the terminology constraint from Clarifications item 8 actually
  carried into a step, or does it die in the Clarifications log? — FAIL
  (missing) — revised in place; Step 2's boundaries now name the constraint
  explicitly.
- CHK9: Does every glossary headword this spec instructs `scribe` to use
  actually exist in `CONTEXT.md`? — FAIL (missing) — revised in place. The
  first draft instructed `scribe` to use "**Microworld dashboard client**",
  which `grep` shows is not a headword anywhere in `CONTEXT.md`; the term was
  inherited unverified from this unit's dispatch prose. Context, Step 2, the
  suggested prose, and Clarifications item 8 all corrected to the two real
  headwords (**Microworld dashboard** `:755`, **D5 browser client** `:849`).
  Recorded rather than quietly fixed, because it is the same error class this
  spec exists to diagnose — see RC-A.

## Scribe update hint

After the re-dispatch reaches PASS, `scribe` should note in the changelog that
`.claude/wiki/architecture.md`'s audit-log paragraph was corrected to match
`CONTEXT.md:854` on the dashboard's polling behaviour, and that the correction
was gated by a claim-anchored criteria block rather than an existence grep.
No `CONTEXT.md` entry, ADR, or version bump is warranted by a one-clause wiki
correction — inventing one would be the deviation, per the P3 line above.
