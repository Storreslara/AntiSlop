# Debug spec — gh380 Step 3, 2-FAIL-cap escalation

**Scope:** a focused root-cause diagnosis plus revised acceptance criteria for
the failed step. Not a replan. Step 3's design (arm/confirm over `/dev/tty`,
server-side body composition, staleness binding, fail-closed availability) is
unchanged and stays; only the input-validation property and its criteria are
revised.

**Parent plan:** `docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`
§ "Step 3 — Server: arm/confirm decision-write endpoints over `/dev/tty`"
**Unit:** 380 · **FAIL records:** `.claude/reviewed/380.fail` (2nd fail; 1st
overwritten) · **Attempts:** `19a0cd0`, `e5a645f` (1st), `582407e` (2nd)

---

## fail-triage: verify → categorize

### 1. VERIFY — confirmed, and the blast radius is wider than reported

Re-run live, not read from the record. Arm-only probe (never writes a decision
artifact — a `200` with a forged composed body is already the defeat), real
marker grammar, `ttyWrite` stubbed, identical setup to the suite's own
`setupDecisionEnvironment`:

```
POST /api/decision/arm   {taskId:"380", route:"approve", escalationTimestamp:<real>, reason:"ok",
                          by: <shape of "agent\nquiz: passed-self-check\nnote: forged">}

  by as string   -> 400 {"error":"invalid request","message":"by may not contain a newline..."}
  by as array    -> 200 {"armed":true,"expiresInMs":120000}
  by as nested   -> 200 {"armed":true,"expiresInMs":120000}
  by as object   -> 200 {"armed":true,"expiresInMs":120000}
  by as number   -> 200 {"armed":true,"expiresInMs":120000}
  by as boolean  -> 200 {"armed":true,"expiresInMs":120000}
  by as null     -> 200 {"armed":true,"expiresInMs":120000}

  ... identical results for `reason` in all seven shapes.
```

The reviewer reported array and nested-array. The measured truth is broader:
**every JSON shape except `string` is accepted.** The guard is not "weak
against arrays" — it is skipped for the entire complement of
`typeof value === 'string'`. Composed body returned by
`composeEscalationDecisionBody` with the array `by`, `warnings: []`:

```
DECISION 380 <ts> route: approve escalation: 2026-08-15T10:00:00Z
by: agent
quiz: passed-self-check      <- forged attestation, never supplied
note: forged
via: dashboard
reason: ok
```

`server.js:452` writes that byte-for-byte. D3 reproduces on the same vector:
`by = ["agent\n2026-01-01T00:00:00Z decision-gate-denied identity=forged"]`
renders a second, attacker-chosen line into `.claude/review-audit.log` shaped
to mimic that file's real `decision-gate-denied` entries.

**Status: confirmed.** The spec's stated security property is still false.

### 2. CATEGORIZE — spec/criterion defect (not a plain code defect)

The normal FAIL route is "criterion right, code wrong → back to
lead-programmer." That is **not** this case, which is why two competent
attempts both landed short.

Step 3 has twelve acceptance criteria. **Not one of them constrains the type or
content of any field.** The security property was carried entirely by a prose
sentence in criterion 4's preamble:

> "The client never supplies file text — only the structured fields — so the
> endpoint can only ever write a protocol-shaped body."

That inference is false as written. "Structured fields" implies
"protocol-shaped body" **only if every field is individually constrained** —
and the plan never said so. So the implementer had no specified invariant to
build against, and both attempts were necessarily reactive: they patched the
reviewer's finding rather than implementing a property. Attempt 1 patched the
literal newline; attempt 2 patched the literal newline in strings. Neither was
ever asked for "no client-controlled value can add a line."

This is why the fix is a debug spec and not a third dispatch of the same
criteria.

---

## Root cause

### The named defect class: type confusion defeating a type-gated validator

`decision-block.js:52-53`:

```js
function assertNoNewline(value, label) {
  if (typeof value === 'string' && /[\r\n]/.test(value)) { throw ... }
}
```

The `typeof value === 'string' &&` conjunct was written as a *safety* guard
(don't call `.test` on a non-string). It is in fact a **validation bypass**:
for any non-string it short-circuits to `false`, the function returns normally,
and the caller reads that as "validated." The value then reaches template-literal
interpolation at `decision-block.js:95` (`` `by: ${by}` ``), `:124`
(`` `reason: ${reason}` ``) and `server.js:468` (audit line), where
`${arrayValue}` invokes `Array.prototype.toString()` and rejoins the elements
into a plain string — reconstituting the newline on the far side of the type
check.

This is the classic shape of the bug: **a validator gated on a type predicate
silently no-ops for every other type, while the sink coerces back to that type
anyway.** Validation is type-gated; the sink is type-agnostic. The guard and
the sink disagree about what a "string" is, and the gap between them is the
vulnerability. In JS this is most often seen with JSON-parsed request bodies,
because JSON is the cheapest way for a client to choose a value's *type*, not
just its content — the payload changes by one character (`"x"` → `["x"]`) and
the entire validation layer stops running.

**The generalizable rule:** a validator must **fail closed on unexpected type**,
never skip. `typeof value === 'string'` belongs in the *reject* condition, not
as a precondition on whether to check at all:

```
  WRONG:  if (typeof v === 'string' && isBad(v)) reject       // non-string: skipped
  RIGHT:  if (typeof v !== 'string') reject                   // non-string: rejected
          if (isBad(v)) reject                                // then content
```

### Why the tests never caught it (the second, independent root cause)

Both suites tested the *attack instance* rather than the *attack class*. Tests
13/14/15 (`tests/dashboard-decision-run.test.js:857-1057`) and the composer
tests (`tests/dashboard-decision-block.test.js:286-314`) each send exactly one
payload: a string containing `\n`. That pins the one shape the attacker will
not use once it stops working. A test written to confirm the fix works will
pass against the fix's own blind spot by construction; only a test written to
*search for a bypass of the fix's mechanism* can find one. This is the failure
mode the revised criteria attack directly (C7, C8).

### The design gap worth naming (from the reviewer's roast-work findings)

`by`/`reason` are the **only** two client-supplied fields on this endpoint
validated by a weaker discipline than their neighbours. Measured:

| field | discipline | non-string `["…"]` |
|---|---|---|
| `taskId` | explicit `typeof` + `ID_RE` | 400 |
| `route` | `ROUTES.indexOf()` allowlist | 400 |
| `quiz` | `QUIZ_TOKENS.indexOf()` allowlist | 400 |
| `via` | `VIA_ROUTES.indexOf()` allowlist | 400 (server-set) |
| `escalationTimestamp` | `!==` compare vs marker capture | 409 |
| **`by`** | **type-gated newline check** | **200 — accepted** |
| **`reason`** | **type-gated newline check, `via`-conditional** | **200 — accepted** |

Every allowlisted field is type-safe *by construction* — `.indexOf()` on an
array of string literals can never match a non-string, so those fields fail
closed without anyone having to think about types. `by`/`reason` are free text,
so they have no allowlist to inherit that property from, and the bolted-on
guard reintroduced exactly what the allowlists were giving away for free.

**The gap to close is the asymmetry, not the array instance.** Free-text fields
need an explicit type+content contract precisely *because* they cannot borrow
one from an allowlist.

### Same class, lower severity: `code` on `/api/decision/run`

Measured while sweeping siblings. Non-string `code` is *incidentally* safe
(409) via `code.length !== currentArm.code.length`, but `code: null` throws an
uncaught `TypeError` surfaced to the client as
`400 {"error":"invalid request","message":"Cannot read properties of null (reading 'length')"}` —
an internal exception message on a security endpoint, from the same
missing-type-check root. In scope as a same-class item, not as scope creep.

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-08-15 Functional scope & success criteria: Q Does this debug spec cover
  only `by`/`reason` on `/api/decision/arm`, or every client-supplied field on
  both endpoints? → A (self-resolved): every field on both endpoints, because
  the reviewer's asymmetry finding identifies the *field-class* discipline gap
  as the actual defect; scoping to `by`/`reason` would leave `code`'s
  same-class defect standing and would not close the gap that produced two
  FAILs. Verified by measurement that the other five fields already pass.
- 2026-08-15 Non-functional attributes: Q What exactly is the security property
  being asserted, stated so it is falsifiable? → A (self-resolved): "No
  client-supplied value, in any JSON type, can cause the composed DECISION body
  or the audit-log line to contain a line the client did not legitimately
  supply as a single-line string field." Prior phrasing ("only ever a
  protocol-shaped body") was unfalsifiable and is what let two attempts pass.
- 2026-08-15 Edge cases / failure handling: Q Must `undefined`, `null`, and `""`
  behave identically under a strict-type rule? → A (self-resolved): no, and this
  is the distinction most likely to be botched. Measured current behaviour:
  omitted (`undefined`) hits the destructuring default `by = ''` and is legal
  and depended upon; `""` is legal; but `null` bypasses the default and composes
  the literal text `by: null` into the artifact. Required: `undefined` and `""`
  stay 200; `null` becomes 400.
- 2026-08-15 Technical constraints & tradeoffs: Q Fix at the HTTP parse boundary,
  in the composer, or both? → A (self-resolved): both, and the criteria are
  written to be satisfied only by both. The composer is dual-environment (also
  injected into the browser page as a global) and is the last line of defence
  for any future caller; the server must *additionally* validate at parse time
  and store the *validated* value into `currentArm`, because the audit-log sink
  reads `currentArm.by` and not the composer's copy — leaving D3 closed only
  transitively otherwise, which is precisely what the current false comment at
  `server.js:464-466` claims.
- 2026-08-15 Completion / acceptance signals: Q What criterion would have caught
  both prior attempts? → A (self-resolved): a mutation proof (C8) — neutering
  the type guard must turn the suite red. Both prior suites stayed green with
  the endpoint exploitable, so "tests pass" was never evidence. C7 additionally
  forces the shape enumeration to be data-driven so a future field inherits
  coverage instead of needing a new hand-written test.

**Terminology (`ubiquitous-language`, prose mode, advisory, non-blocking):**
Lens 1 — no glossary term used divergently; `escalation packet`,
`ESCALATE-TO-HUMAN`, and `DECISION channel` are used per `CONTEXT.md:733-761`.
Lens 2 — no new synonym introduced; this spec says "arm"/"confirm" as Step 3
already does. Lens 3 — "JSON type confusion" is a new, now twice-load-bearing
defect-class term with no `CONTEXT.md` entry; suggest `scribe` add it when this
unit lands, since the repo now has a concrete instance to point at.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim above was re-measured live
  (seven type shapes × two fields, the sibling-field sweep, the
  `undefined`/`null`/`""` distinction, and the terminal multi-line path), not
  inferred from the FAIL record.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  generated file is hand-edited; this unit touches source and tests only.
- P3 "Version-stamp discipline": satisfied — no `templates/` edit, so no plugin
  version bump is required by this unit.
- P5 "`tests/validate.sh` is the merge gate": satisfied — C1 retains it.

---

## Revised acceptance criteria (replacing Step 3 criterion 3's security clause;
## criteria 1-2 and 4-12 of the parent plan stand unchanged and must stay green)

**The property under test, stated falsifiably:** no client-supplied value, in
any JSON type, can cause the composed DECISION body or the audit-log line to
contain a line the client did not legitimately supply as a single-line string
field.

**C1 — suites and gate green.** `node tests/dashboard-decision-run.test.js`,
`node tests/dashboard-server.test.js`, and
`node tests/dashboard-decision-block.test.js` each exit 0 and print
`All tests passed!`; `bash tests/validate.sh` prints `All checks passed.`

**C2 — the type matrix, the core criterion.** A test iterates the cross-product
of free-text fields `{by, reason}` × JSON shapes `{array-wrapped, nested-array,
plain object, number, boolean, null}` — 12 cases minimum — and for **each**
asserts all three of: (a) `POST /api/decision/arm` returns **400**; (b) the
response body does not contain `"armed":true`; (c) the `ttyWrite` stub received
**zero** messages for that request. The array-wrapped case MUST use the
reviewer's exact payload `["agent\nquiz: passed-self-check\nnote: forged"]`.

**C3 — string content check preserved and widened.** `by` or `reason` as a
*string* containing `\n` → 400, and separately as a string containing `\r` →
400. (`assertNoNewline` tests `/[\r\n]/`; the existing suite only ever sends
`\n`, so the `\r` half is currently unproven.)

**C4 — legal input regression guard, with the `undefined`/`null` split pinned
explicitly.** Tests assert: `by`/`reason` omitted entirely → **200** (the
destructuring default `= ''` is depended upon); `by: ""`/`reason: ""` → **200**;
ordinary single-line strings → **200**; and `by: null`/`reason: null` → **400**.
A fix that treats `null` and `undefined` alike fails this criterion in one
direction or the other.

**C5 — terminal path not collateral damage.** `composeEscalationDecisionBody`
with no `via` (or `via: 'terminal'`) and `reason: "line one\nline two"` still
composes successfully with both lines intact. Existing Test (e) in
`tests/dashboard-decision-block.test.js` must still pass **unmodified** — the
type check is unconditional, the *content* check stays `via: 'dashboard'`-only.

**C6 — D3 re-verified independently, not inherited.** Three parts, all required:
  - **(a) negative:** for each shape in C2, `.claude/review-audit.log` is
    byte-identical before and after the rejected arm, **and** a subsequent
    `POST /api/decision/run` for that `taskId` returns **409** — proving no arm
    record was created holding an unvalidated value.
  - **(b) positive/structural:** a legal arm→run cycle appends **exactly one**
    line — asserted as a newline-count delta of exactly 1 on
    `.claude/review-audit.log`, not as a substring match — matching
    `/^\S+ decision-write-via-dashboard task=\S+ route=\S+ by=.*$/`.
  - **(c) the false comment is gone:** both
    `git grep -c "cannot inject extra lines" bin/microworld-dashboard/server.js`
    and
    `git grep -c "passed the composer's newline validation" bin/microworld-dashboard/server.js`
    return **0**. Both currently return **1** — measured, so this criterion is
    non-vacuous. (Note the phrases are chosen to sit on a single source line:
    the full sentence "already passed the composer's newline validation" wraps
    across a comment line break and greps to 0 *today*, which would make the
    criterion trivially satisfied. Do not "simplify" these two greps back into
    one longer phrase.) The replacement comment must not claim a guarantee the
    code does not provide.

**C7 — anti-"we only tested the shape we knew about".** The shape list and the
field list are each defined **once** as shared constants in the test file and
iterated as a cross-product — not written out as hand-rolled one-off tests — so
that adding a future free-text field inherits full shape coverage by adding one
name to one array. Machine-checkable: a named constant (e.g. `NON_STRING_SHAPES`)
exists in `tests/dashboard-decision-run.test.js`, has ≥ 6 entries, and is
referenced by the iteration for **both** fields.

**C8 — mutation proof (the criterion that would have caught both prior
attempts).** With the new type guard neutered — revert `assertNoNewline`'s
reject-on-type to the current `typeof value === 'string' &&` form — 
`node tests/dashboard-decision-run.test.js` exits **non-zero**. The reviewer is
instructed to perform this mutation and restore afterwards. A suite that stays
green under this mutation is vacuous and the unit FAILs regardless of C1.

**C9 — sibling field `code`, same class.** `POST /api/decision/run` with `code`
as each shape in C2's list returns 4xx **and** the response `message` does not
contain internal exception text (specifically not
`Cannot read properties of`). Currently `code: null` leaks
`Cannot read properties of null (reading 'length')`.

**C10 — the asymmetry is closed, stated as a whole-endpoint property.** A test
enumerates every field the two handlers destructure from the parsed JSON
(`taskId, route, escalationTimestamp, by, reason, quiz` for arm; `taskId, code`
for run) and asserts each rejects a non-string with 4xx. This is the criterion
that generalizes the fix from "the array bug" to "the field-discipline gap," and
it is the one that must not be satisfied by inspection.

---

## Self-check

- CHK1: Does the spec state the security property in falsifiable terms rather
  than as the parent plan's unfalsifiable "protocol-shaped body" prose? — PASS
  (stated once above C1, and each of C2/C6/C10 asserts a measurable half of it)
- CHK2: Do C4 and C5 agree with C2 about which inputs must be *accepted*? — PASS
  (C2 covers only non-string shapes and `null`; C4 fixes `undefined`/`""`/plain
  strings as 200; C5 fixes the one multi-line string that stays legal, on the
  terminal path only — no shape appears in both an accept and a reject list)
- CHK3: Is every criterion machine-checkable? — PASS (each names an HTTP status,
  an exit code, a `git grep -c` value, a byte/newline-count comparison, or a
  literal-string absence; no criterion says "correctly" or "properly")
- CHK4: Is D3 verified independently of the `by`/`reason` fix rather than assumed
  to follow? — PASS (C6(a) asserts the audit file directly for every shape and
  proves no arm record exists; C6(b) asserts the line-count delta on the success
  path; C6(c) removes the comment asserting the unearned guarantee)
- CHK5: Would any criterion here have caught attempt 2 as written? — PASS (C2
  fails it outright at 12 of 12 cases; C8 fails it by mutation; C10 fails it on
  `by`/`reason`)
- CHK6: Is the `undefined` vs `null` edge case — scored Missing in the taxonomy —
  resolved in the criteria and not just the prose? — PASS (C4 pins both
  directions explicitly, and names why a fix conflating them fails)
- CHK7: Does the spec avoid handing the implementer a finished patch while still
  constraining the outcome? — PASS (the RIGHT/WRONG sketch in Root cause is
  illustrative pseudo-code of the general rule; placement, naming, and the
  error-message text are left open, but C6(a) and C10 can only be satisfied by
  validating at the boundary *and* storing the validated value)
- CHK8: Is P1 "Verify, don't assume" satisfied for the claims this spec itself
  makes? — PASS (the seven-shape table, the sibling sweep, the field-discipline
  table, and the `undefined`/`null`/`""`/terminal-path behaviours were each run
  and their output read; nothing above is carried over from the FAIL record
  without re-measurement)
- CHK10: Was every `git grep` criterion in this spec *run against the current
  tree* to confirm it is non-vacuous (i.e. that it does not already pass before
  any work is done)? — FAIL (ambiguous) — revised in place: C6(c) originally
  grepped `"already passed the composer's newline validation"`, which returns 0
  today because the sentence wraps across a comment line break — the criterion
  would have been satisfied by changing nothing. Replaced with two single-line
  phrases, each measured at 1 on the current tree.
- CHK9: Does any criterion depend on a test authored via a `Bash` heredoc that
  the decision gate would refuse? — FAIL (missing) — revised in place: added the
  `## Pre-resolved context` note instructing test authorship via `Write`/`Edit`,
  which the gate does not scan for content

## Scribe update hint

On landing: add a `CONTEXT.md` glossary entry for **JSON type confusion** (a
validator gated on `typeof` silently no-ops for other types while the sink
coerces back), citing this unit as the worked instance; and note in the
dashboard wiki page that free-text decision fields carry an explicit type+content
contract because they cannot inherit type-safety from an allowlist.

---

## Dispatch contract — fast path (1 unit, no `to-tickets`, no task-master)

**Unit:** `gh380-fix` (re-dispatch of unit 380, Step 3 of
`docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`)

### Objective
Close the JSON type-confusion defect class across every client-supplied field on
`POST /api/decision/arm` and `POST /api/decision/run`, so that validation fails
closed on unexpected type instead of silently skipping, and prove it with
adversarial multi-shape test coverage that goes red when the guard is removed.

### Retrieval
No tracker issue for this pass. Read this file —
`/home/sebas/AntiSlop/docs/plans/2026-08-15-gh380-debug-spec-type-confusion.md` —
in full, plus the parent Step 3 at
`/home/sebas/AntiSlop/docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`
lines 453-542, and the standing FAIL record at
`/home/sebas/AntiSlop/.claude/reviewed/380.fail`.

### Affected files
- `/home/sebas/AntiSlop/bin/microworld-dashboard/decision-block.js` (the
  `assertNoNewline` guard at :52-53 and its two call sites)
- `/home/sebas/AntiSlop/bin/microworld-dashboard/server.js` (arm handler
  :270-380, `currentArm` construction :359-368, audit-line comment and
  interpolation :464-468, run handler `code` handling :424-445)
- `/home/sebas/AntiSlop/tests/dashboard-decision-run.test.js` (Tests 13/14/15 at
  :857-1057 — extend, do not replace)
- `/home/sebas/AntiSlop/tests/dashboard-decision-block.test.js` (:286-314)

### Ordered edits
1. Make the type check a **reject**, not a precondition: non-string fails closed
   before any content test. Keep the content (`/[\r\n]/`) test after it, and keep
   the content test's existing `via: 'dashboard'` conditionality for `reason`.
   Preserve the `undefined` → `''` default (C4).
2. Validate `by`/`reason` types at the server's JSON-parse boundary and store the
   **validated** values into `currentArm`, so the audit-log sink at :468 reads a
   value that was validated rather than one that merely coincides with one.
3. Replace the false comment at :464-466 with one that states only what the code
   now guarantees (C6c).
4. Give `code` on the run handler an explicit string check before `.length`,
   returning a generic 4xx with no internal exception text (C9).
5. Extend both suites with the data-driven cross-product matrix (C2, C7, C9, C10)
   and the regression guards (C3, C4, C5).

### Do NOT touch
- The D1 staleness-binding fix (`server.js:305-312`) — verified genuinely fixed.
- The four advisory fixes confirmed fixed in `.claude/reviewed/380.fail`
  (tty fail-open ordering, audit-swallow reporting, falsy `ttyWrite` gating, fd
  leak / `ownsTtyFd`).
- Terminal-path multi-line `reason` semantics and existing Test (e).
- `index.html`, Step 4/5 scope, the `startServer` options-argument signature, R7
  (never `mkdir -p`), the `wx`-flag never-overwrite rule, and the one-arm-at-a-time
  model.
- Do not add endpoints, and do not widen `ROUTES`/`QUIZ_TOKENS`/`VIA_ROUTES`.

### Acceptance criteria
C1-C10 above, verbatim. C2, C6, C8 and C10 are the load-bearing ones; C8
(mutation proof) is non-negotiable and the reviewer will run it.

### Pre-resolved context
- **Do not re-derive the type-shape behaviour** — it is measured above: all seven
  shapes, both fields, plus the sibling sweep and the `undefined`/`null`/`""`
  split. Verify a specific claim only if you doubt it.
- **`composeEscalationDecisionBody` has exactly one production caller**
  (`server.js:319`) plus the test suite — confirmed by `git grep`. The browser
  page reaches `decision-block.js` as an injected global via `composeDecisionBlock`
  / `safeCompose` (`index.html:528`), whose `try`/`catch` renders a thrown error
  as a page warning rather than an uncaught error — so a new unconditional throw
  is safe on that path.
- **Author test files with `Write`/`Edit`, not `Bash` heredocs.**
  `human-decision-gate.sh` scans Bash *command text* and refuses any command
  spelling the packet path together with the decision filename — it blocked the
  reviewer's end-to-end repro script even though the target was a `mkdtemp`
  fixture. `Write`/`Edit` check only `file_path`, so test authorship is unaffected.
  Do not rephrase or split a path to get around the gate; if it refuses, report it.
- `startServer` returns `{ server, token }` and both endpoints require the
  `X-Antislop-Token` header — the suite's own helper already handles this.

### Escalation
This unit has already consumed **both** FAIL attempts under the shared protocol's
2-FAIL cap. A third FAIL must **not** be re-dispatched to `lead-programmer`:
stop, and surface to the human with the full three-attempt defect history. If any
criterion above proves unverifiable or wrong during implementation, stop and
report rather than reinterpreting it — a criterion reinterpreted to pass is the
exact failure mode that produced this escalation.
