# Item 12: The 2-FAIL cap cannot count to 2 — append `.fail` records

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 12 of 19
Source: Fable adversarial review 2026-09-25, Gating Complaint 5 Alt A
Disposition: **ACCEPT — append, don't overwrite.** Defect confirmed by direct code read.

## Goal

Make the shared protocol's "Cap at 2 FAILs per unit" mechanically countable
across sessions, by appending FAIL blocks to a unit's `.fail` record instead
of truncating it.

## Context

Verified 2026-09-25 by reading the write path, not the prose:

`hooks/scripts/lib/state-access.sh:52-61`, `state_write_unit_marker()`, ends
with a **truncating redirect**:

```
printf '%s\n' "$content" > "$marker_file"
```

`marker-write.sh:66-69` routes the `FAIL` verdict through that same function.
So a second FAIL for a unit overwrites the first. The count is destroyed at
exactly the moment it becomes decision-relevant.

This matches what the personas already say — spec-master's own protocol text
states *"a second FAIL overwrites the first at that same path — no
append/rotation mechanism exists"* — and it is precisely why the cap is
enforceable only inside one session's memory. A fresh session reading an
existing `.fail` cannot tell a first failure from a second, so it either
under-escalates (spawning a third fix attempt) or over-escalates (surfacing
at the first FAIL). The shared protocol says a unit that fails twice
"usually means the plan itself has a gap" — that judgment is unavailable if
the record cannot be counted.

The fix is small and local: append a delimited block, and count blocks.

**Why this is not merely cosmetic.** The `.fail` record is the *only* bridge
for a session with no memory — the protocol says so explicitly. Its whole
stated purpose is durability across spawns, and truncation defeats that
purpose specifically in the repeat-failure case the cap exists to catch.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-25 Domain entities / data model: Q What delimits one FAIL block
  from the next, given consumers parse line 1? → A (self-resolved): keep the
  **most recent** block first is rejected (it breaks append-only atomicity);
  instead append chronologically and require each block to begin with the
  existing exact first-line form `FAIL <task-id> <UTC ISO-8601 timestamp>`.
  Block count = count of lines matching that anchor. This preserves every
  existing line-1 reader.
- 2026-09-25 Edge cases / failure handling: Q What happens to an existing
  single-block `.fail` written before this change? → A (self-resolved): it is
  already a valid one-block record under the new format — no migration, no
  grace period (see item 9 for why grace periods rot).
- 2026-09-25 Technical constraints & tradeoffs: Q Should PASS/BLOCKED also
  append? → A (self-resolved): **no.** Only `.fail` is counted. PASS is a
  terminal state and BLOCKED is resolved-and-deleted by design; appending
  either would change semantics no consumer asked for.
- 2026-09-25 Terminology consistency: Q Is "FAIL record" one file or one
  block, after this change? → A (self-resolved): the **file** is the FAIL
  record; a **FAIL block** is one attempt within it. Both terms need glossary
  entries, since the protocol currently uses "record" for both.

## Risks and dependencies

- **R1. Line-1 consumers must not break.** `task-gate.sh`'s `marker_valid()`
  checks line 1's prefix and non-emptiness; `dispatch-hygiene.sh` H3 reads a
  `commit:` field on `.pass`. Appending keeps line 1 stable **only if new
  blocks go at the end**. This is why chronological append is mandatory, not
  a style preference.
- **R2. Non-vacuity.** A test that writes two FAILs and asserts a count of 2
  must be proven to fail against the current truncating implementation.
  Per `verify-own-criteria-nonvacuous`, prove by mutation before claiming
  done.
- **R3. Shared-function blast radius.** `state_write_unit_marker()` is used
  for **all** marker types. Changing it wholesale would alter `.pass`
  behaviour too. The change must be scoped to the FAIL path only.
- **R4. Prose propagation.** At least three documents state the
  overwrite behaviour as fact (spec-master's protocol text, the shared
  protocol's FAIL-record section, and the `fail-triage` skill, which says
  "a second FAIL overwrites the first… there is no append/rotation
  mechanism"). All must be corrected or they will contradict the code. Per
  `protocol-amendments-do-not-propagate`, enumerate surfaces rather than
  assuming a single edit propagates.
- **R5.** No prior `.fail` record known for this unit (new work); the
  marker-directory sweep is Bash-gated for this persona.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the defect was confirmed by reading
  the redirect, not by trusting the review.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — this
  replaces a count held in model memory with a countable artifact.
- P3 "Version-stamp discipline": **applies** — Step 3 edits
  `templates/persona-protocol.md` and persona bodies, which are
  version-stamped. Bump `.claude-plugin/plugin.json` and add a CHANGELOG
  entry. Two prior units FAILed for omitting exactly this
  (`version-stamp-discipline-gap` memory note).
- P4 "Optional personas degrade gracefully": satisfied — Step 3 wording stays
  conditionally phrased.
- P5 "`tests/validate.sh` is the merge gate": satisfied — asserted per step.

## Step 1 — Append FAIL blocks instead of truncating

**Affected files:** `hooks/scripts/lib/state-access.sh` and/or
`hooks/scripts/marker-write.sh`, plus every mirror copy (confirm set at
execution time; `stop-gate-core.sh` was measured at 4 copies — source,
`.claude/`, and both adapters — so expect the same shape here).

Scope the change to the FAIL path. Each new block begins with the existing
exact first line `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by the
defect list verbatim, then a blank separator line.

**Acceptance criteria**
- Writing two FAILs for one task-id yields a file where
  `grep -cE '^FAIL <task-id> ' <file>` equals **2**, and the **first** line of
  the file is still the first FAIL's anchor line.
- `.pass` behaviour is unchanged: writing two PASSes for one task-id yields a
  file with exactly **1** `PASS` anchor line (proving the change did not leak
  into the shared path).
- Non-vacuity proven by mutation: revert the append change, re-run the
  two-FAIL test, confirm it reports **1**, restore, confirm **2**. Record both
  observations in the ready-for-review report.
- `bash tests/marker-write.test.sh` exits 0 and `bash tests/validate.sh`
  exits 0.
- Mirror parity holds (validate.sh asserts it).

## Step 2 — Make the count readable by a fresh session

**Affected files:** `hooks/scripts/marker-verify.sh` or a small helper under
`bin/`; tests.

Provide a deterministic way to obtain a unit's FAIL count without an agent
parsing prose — this is the P2 point of the whole item.

**Acceptance criteria**
- A command exists that, given a task-id, prints the integer FAIL-block count
  and exits 0; it prints `0` for a unit with no record.
- For a two-block fixture it prints exactly `2`; for a one-block fixture,
  `1`.
- `bash tests/validate.sh` exits 0.

## Step 3 — Correct the prose that states the overwrite behaviour

**Affected files:** `templates/persona-protocol.md` § "FAIL record";
`skills/fail-triage/SKILL.md`; `agents/spec-master.md`; regenerated
`.claude/` copies and affected persona bodies;
`.claude-plugin/plugin.json`; `CHANGELOG.md`; `CONTEXT.md`.

**Acceptance criteria**
- `grep -rc 'a second FAIL overwrites the first' templates/ agents/ skills/`
  totals **0**.
- `grep -rc 'no append/rotation mechanism exists' templates/ agents/ skills/`
  totals **0**.
- Every surface that previously stated overwrite now states append: assert
  per-file, not in aggregate, so a missed surface cannot hide behind a
  passing total.
- `.claude-plugin/plugin.json` version is strictly greater than at `HEAD`, and
  `CHANGELOG.md` names that version.
- `CONTEXT.md` gains distinct entries for **FAIL record** (the file) and
  **FAIL block** (one attempt).
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should the cap remain at 2, or be replaced by an always-ask prompt?**
   The review's Alt B proposes dropping the cap and surfacing after *every*
   FAIL with a one-question `AskUserQuestion` (retry / escalate / park),
   arguing that for a solo operator (ADR-0024's stated posture) that is less
   machinery and more control. This spec deliberately fixes the counting
   defect **without** deciding this, because a working count is a
   precondition for either policy and is useful under both. Recommended
   default: **fix the count now (this spec), evaluate Alt B separately once
   the count is real** — the current data cannot support the comparison,
   since no reliable per-unit FAIL counts exist yet. Requires a human
   decision.

## Self-check

- CHK1: Does the spec preserve line-1 readers? — PASS (Step 1 asserts the
  first line is still the first FAIL's anchor; R1 explains why append order
  is mandatory).
- CHK2: Do the Context and Step 1 agree on what delimits a block? — PASS
  (both use the existing exact `FAIL <task-id> <timestamp>` anchor).
- CHK3: Is the change prevented from leaking into `.pass`? — PASS (Step 1
  carries an explicit one-PASS-anchor criterion).
- CHK4: Is the prose-propagation surface enumerated or assumed? — FAIL
  (missing) — revised in place: R4 now names three surfaces and Step 3
  asserts per-file rather than in aggregate.
- CHK5: Is the cap's *value* being changed by this spec? — PASS (it is not;
  the question is isolated into Open Question 1).
- CHK6: Is the new test proven non-vacuous? — PASS (Step 1 requires a
  mutate-revert observation recorded in the report).

## Scribe update hint

Add **FAIL record** (the file, now multi-block) and **FAIL block** (one
attempt) to `CONTEXT.md` as distinct terms — the protocol currently uses
"record" for both, which is the terminology drift this change makes
load-bearing.

## Dispatch contract (fast path — 3 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item12-fail-marker-append.md`.
Order: Step 1 → Step 2 → Step 3.

### Unit: item12-1-append-fail-blocks
- **Objective:** Append FAIL blocks instead of truncating.
- **Retrieval:** Step 1.
- **Affected files:** `hooks/scripts/lib/state-access.sh` and/or `marker-write.sh` + mirrors.
- **Ordered edits:** scope to FAIL path → append with anchor + blank separator → mutate-prove → propagate mirrors → validate.
- **Do NOT touch:** the `.pass`/`.blocked` write paths; line-1 format.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** truncating redirect is `state-access.sh:60`, `printf '%s\n' "$content" > "$marker_file"`; FAIL routes there via `marker-write.sh:66-69`. `state_write_unit_marker()` is shared by all marker types — scope carefully.
- **Escalation:** if scoping to FAIL requires changing the shared function's signature, report the blast radius before proceeding.

### Unit: item12-2-fail-count-command
- **Objective:** Make FAIL count readable deterministically.
- **Retrieval:** Step 2.
- **Affected files:** `hooks/scripts/marker-verify.sh` or a `bin/` helper; tests.
- **Ordered edits:** implement count → test 0/1/2 fixtures → validate.
- **Do NOT touch:** marker write paths (item12-1 owns those).
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item12-1's block format. Note `marker-verify.sh` already parses line 2 as a note (per `persona-audit-11-findings` memory note) — do not break that.
- **Escalation:** if counting collides with marker-verify's existing note parsing, report rather than changing note semantics.

### Unit: item12-3-correct-overwrite-prose
- **Objective:** Correct every surface stating the overwrite behaviour.
- **Retrieval:** Step 3, **as amended by Amendment A below** (two amendments;
  the objective is unchanged).
- **Affected files:** `templates/persona-protocol.md`, `skills/fail-triage/SKILL.md`, `agents/spec-master.md`, regenerated `.claude/` copies, `.claude-plugin/plugin.json`, `CHANGELOG.md`, `CONTEXT.md`.
- **Ordered edits:** enumerate surfaces → correct each → regenerate → bump version → CHANGELOG → glossary.
- **Do NOT touch:** the cap's value (still 2).
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** version-stamped files are touched, so P3 applies — two prior units FAILed for omitting the bump. The inlined protocol block is trimmed per persona; verify propagation only on personas whose matrix row includes the FAIL-record section.
- **Escalation:** if a fourth surface states the overwrite behaviour, add it rather than reporting the criterion as unsatisfiable.

---

## Amendment A — 2026-09-26: the real `.fail` write path was never repointed

Status of this amendment: **FINAL.** Raised by item12-1's reviewer as a
post-PASS finding; re-derived independently here rather than accepted on the
quote. Append-only — Steps 1-3 above are not renumbered and item12-1's landed
work is not reopened.

### The finding, re-derived

**Confirmed.** `hooks/scripts/marker-write.sh` is not on the reviewer's
documented path, so item12-1's `state_append_unit_marker()` is dormant for
every real `.fail` write and the item's Goal is unachieved end-to-end.

Evidence, measured 2026-09-26 at `e5e880a`:

1. **The helper is unreferenced by any instruction surface.** `git grep -n
   "marker-write" -- agents/ templates/ skills/ .claude/agents/
   .claude/persona-protocol.md docs/harness-glossary.md CONTEXT.md` returns
   only (a) the phrase "at marker-write time" inside the protocol's PASS-marker
   sentence, (b) `tests/marker-write.test.sh` named in an ADR-0028
   cross-reference, and (c) `agents/reviewer.md:401`'s prose "if the
   marker-write attempt is refused". **Zero** of them name the script as a
   command to run. `marker-write.sh` itself says so in its own header: "NOT A
   HOOK. Deliberately unregistered in hooks/hooks.json" — it is registered in
   no `settings.json` hook either.
2. **The documented shape is a hand-authored truncating write — and for
   `.fail`, there is no documented command literal at all.** Measured:
   `grep -c "cat >" agents/reviewer.md` is **0**, as is the same grep over both
   adapter reviewer ports. `agents/reviewer.md:126-128` gives the PASS literal
   as `mkdir -p .claude/reviewed` then
   `printf '...' > .claude/reviewed/<task-id>.pass`; `:171-177` tells the
   reviewer to write the `.fail` record "via Bash" with "First line exactly
   `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by the same defect
   list … verbatim" — a *content* spec with no command shape and no helper
   named. `templates/persona-protocol.md:312-320` § "FAIL record" likewise
   names no mechanism.

   This is the mechanism behind finding (3) below. The reviewer infers a shape
   from the two nearest examples, and **both truncate**: the PASS `printf >`
   literal one bullet above, and `docs/harness-glossary.md:2048-2063`, whose
   **sanctioned marker-write template** entry documents the template as
   `cat > .claude/reviewed/<id>.pass <<'EOF' … EOF` and never mentions that
   `>>` is equally permitted. So the fix is not "flip `>` to `>>`" — it is
   *supplying the missing literal*, and correcting the glossary entry that
   currently under-states what the gate allows.

   **One correction to the originating finding:** it stated that "the gate's
   only sanctioned shape is a truncating heredoc (`docs/harness-glossary.md`
   :2048-2055)". The *gate* sanctions both `>` and `>>` (see the decision
   below); it is the *glossary prose* that documents only `>`. The finding's
   conclusion is unaffected, but the remedy lands on the prose, not the gate.
3. **Behaviour in the field matches (2), not the helper.** Over this project's
   own transcript store (`~/.claude/projects/-home-sebas-AntiSlop/`), Bash
   commands writing a `.fail` marker are **75** occurrences of the truncating
   `cat > …/<id>.fail` heredoc against **16** of the appending `cat >> …` form.
   Every observed `marker-write.sh` invocation belongs to its own development
   and test history (`spec2-unitC`, `gh413`) — none to a routine verdict.
4. **The damage is observable on disk.** `.claude/reviewed/150.fail` records,
   in prose, "attempt 2 (this is the SECOND FAIL for this unit)" — a reviewer
   hand-noting a count the file itself had just destroyed. Across all 122
   existing `.fail` records, exactly one (`gh-eval-step1.fail:26`) carries a
   genuine second task-id-qualified anchor, appended by hand.

### The decision: change the reviewer's documented write shape (not the helper it never calls)

**Chosen: option (b)** — teach the *documented sanctioned marker-write
template* to append, by switching the reviewer's `.fail` literal from
`cat > …` to `cat >> …`. **Option (a) is rejected**, on three measured
grounds:

- **The gate already permits it, so option (b) costs no security surface.**
  `hooks/scripts/human-decision-gate.sh:77`'s
  `is_sanctioned_marker_write()` regex opens `^cat[[:space:]]+>>?` — the
  `>>?` has been there since the template's introduction (commit `2a71911`,
  gh345-1) and is unchanged through `18c40c2`, `780ca6a`, `a3aa7ee`. The
  appending form is *already* sanctioned; only the prose ever said otherwise.
  Option (b) therefore changes no gate.
- **Option (a) re-opens the quoting hazard the heredoc exists to close.** A
  `.fail` body is multi-line, prose-heavy defect text — measured at 10-70
  lines in real records — routinely containing apostrophes ("`task-gate.sh`'s"),
  backticks, `$` and em dashes. Passing that as `marker-write.sh`'s fourth
  *argv slot* makes single-quoting impossible and double-quoting unsafe. The
  heredoc's single-quoted delimiter is bash's own guarantee of an inert body,
  which is precisely the property the gate's header cites as one of its four
  safety properties.
- **Option (a) cannot even be a universal instruction.** `agents/reviewer.md:368`
  routes a human `reject` decision to "write `.fail` per the FAIL rules above,
  with the body's reason" — so a `.fail` body *can* quote the DECISION path.
  `is_sanctioned_marker_write()` recognizes **only** the `cat`-heredoc shape,
  so a `marker-write.sh` invocation would be denied in exactly that case.
  Option (a) would need a second, conditional shape; option (b) keeps one.

**item12-1 is not wasted work.** `marker-write.sh` remains a sanctioned
alternate path, and after item12-1 both paths append. The gap was never that
`state_append_unit_marker()` is wrong — it is that the *primary* path bypasses
it. Amendment A closes that, and Step 4's format-parity criterion pins the two
paths to the same on-disk shape.

**A third option was considered and rejected:** giving `marker-write.sh` a
stdin mode so the reviewer could pipe a heredoc into it. It fails the same
DECISION-body test as option (a) (the gate's regex requires `cat` as the
first word), and it would require editing item12-1's already-PASSed file.

### Blast radius: multi-block `.fail` files are safe for every machine consumer

Verified via `explorer` (graph-derived) plus direct grep, 2026-09-26. No hook
or script parses a `.fail` **body**:

- `hooks/scripts/lib/stop-gate-core.sh` `marker_format_valid()` — `head -n 1`
  only; safe, and line 1 stays the *first* block's anchor under chronological
  append (R1).
- `bin/fail-count.sh:23` (item12-2) — `grep -cE "^FAIL ${task_id} "`, i.e. it
  counts anchors and is designed for multi-block.
- `hooks/scripts/task-gate.sh`, `lib/reviewer-route-gate-core.sh:137`,
  `dispatch-hygiene.sh`, `marker-verify.sh`, `marker-commit-check.sh`,
  `bin/human-review-cleanup.sh:96` — existence and/or mtime only.
- `bin/marker-audit.sh` does not read `.fail` at all (its `--notes` sweep is
  `.pass`-only).

**One measured hazard, recorded for item12-2's reviewer rather than specced
here (item12-2 is in flight and owns it):** the *unqualified* anchor `^FAIL `
over-counts. Six of the 122 existing records contain a body line beginning
"FAIL " from prose wrapping (`238.fail:3` "FAIL — unit 238…",
`hcb-step5-measure.fail:5` "FAIL is on prose correctness…",
`128.fail:3`, `150.fail:3`, `gh138.fail:8`, plus `gh-eval-step1.fail:26`).
`bin/fail-count.sh` already uses the **task-id-qualified** anchor, which
correctly rejects all five prose lines and accepts the one genuine second
block — so today's baseline is: 121 records count 1, `gh-eval-step1` counts 2.
That baseline is a ready-made regression fixture.

### Step 4 — Make the reviewer's documented `.fail` write append

**Affected files:** `agents/reviewer.md` (source, § "On FAIL (both modes)");
`.claude/agents/reviewer.md` (regenerated mirror, via `node bin/cli.js
--update`); `adapters/cursor/agents/reviewer.md:70-73`;
`adapters/codex/agents/reviewer.toml:73-76` (both hand-maintained — not
rendered by `bin/cli.js`); `docs/harness-glossary.md` § "sanctioned
marker-write template" (:2048-2063); `tests/reviewed-path-gate.test.sh`;
`tests/human-decision-gate.test.sh`; a format-parity test;
`.claude-plugin/plugin.json`; `CHANGELOG.md`.

Change the reviewer's documented `.fail` literal to the **appending** form of
the sanctioned marker-write template, keeping the `mkdir -p` prelude and the
single-quoted heredoc delimiter, and require the heredoc body to end with one
blank line so the on-disk block separation matches
`state_append_unit_marker()`'s `printf '%s\n\n'`. State explicitly that the
append happens **exactly once per verdict** — a retry after an append already
known to have succeeded must not repeat it, or the count inflates. `.pass` and
`.blocked` literals are untouched; the `rm -f` of a stale `.blocked` is
untouched.

**Acceptance criteria**
- **C4.1 (source shape, per-file).** `grep -cF "cat >> .claude/reviewed/<task-id>.fail" agents/reviewer.md`
  equals **1**. Measured baseline: **0** today (the file contains no
  `cat`-redirect literal at all), so this criterion is non-vacuous by
  construction. Paired regression guard, explicitly **not** evidence of this
  change: `grep -cF "cat > .claude/reviewed/<task-id>.fail" agents/reviewer.md`
  equals **0** — it is already 0 at baseline, so it proves nothing here and
  exists only to catch a later regression. (The two patterns are disjoint: the
  appending literal does not contain the truncating one.)
- **C4.2 (adapter ports, per-file, own dot-dirs).**
  `grep -cF "cat >> .cursor/reviewed/<task-id>.fail" adapters/cursor/agents/reviewer.md`
  equals **1**; `grep -cF "cat >> .codex/reviewed/<task-id>.fail" adapters/codex/agents/reviewer.toml`
  equals **1**. Assert per file — a passing total must not be able to hide a
  missed port.
- **C4.3 (once-per-verdict instruction is present).** `agents/reviewer.md`
  matches `grep -cE 'exactly once per verdict' agents/reviewer.md` equals **1**,
  and the sentence it sits in names the consequence of repeating it (an
  inflated count). Verify by reading, not by the grep alone.
- **C4.4 (the documented literal is actually permitted, under the reviewer
  identity).** Add cases to `tests/reviewed-path-gate.test.sh` building the
  command from that suite's existing `$marker` variable (per its own R4
  rule that every assertion spelling the marker directory lives in that file):
  the documented appending heredoc with `agent_type` `antislop:reviewer`
  → gate exits **0**; the same command with `agent_type`
  `antislop:lead-programmer` → gate **blocks**. The second case is what makes
  the first non-vacuous.
- **C4.5 (the DECISION-body case, which is why the shape matters).** Add a case
  to `tests/human-decision-gate.test.sh`: the documented appending heredoc
  whose body quotes a `.claude/human-review/<id>/DECISION` path → gate exits
  **0** (recognized by `is_sanctioned_marker_write()`); a non-`cat` variant
  naming the same path → **blocked**.
- **C4.6 (format parity between the two write paths).** In a scratch `dot`
  (never the real marker directory — ADR-0028; `tests/marker-write.test.sh`
  leaked fixtures once already): apply the documented heredoc twice for one
  unit id, and apply `bash hooks/scripts/marker-write.sh FAIL <id> - '<body>'
  <path>` twice for another. Assert `bash bin/fail-count.sh` prints **2** for
  both, `grep -c '^$'` is **equal** for both, and `head -n 1` of each is still
  its own first block's anchor. Byte-identity is deliberately *not* asserted
  (the helper generates its own timestamp).
- **C4.7 (non-vacuity, proven by mutation, both directions).** Revert C4.1's
  literal to `cat > ` and confirm C4.1 fails; restore and confirm it passes.
  Separately, mutate `human-decision-gate.sh`'s `>>?` to `>` in a scratch copy
  and confirm C4.5's append case fails; restore. Record both observations in
  the ready-for-review report.
- **C4.8 (P3 version-stamp discipline).** `agents/reviewer.md` matches
  `version-stamp-check.sh`'s stamped set (`agents/*.md|templates/*`), and that
  check is **per-commit** — so this unit carries its own bump:
  `.claude-plugin/plugin.json` version strictly greater than at `HEAD` (now
  `0.31.91`), and `CHANGELOG.md` names that version. Two prior units FAILed
  for omitting exactly this.
- **C4.9 (`bash tests/validate.sh` exits 0)** — it carries the mirror-parity
  and adapter-protocol-parity checks, so a stale `.claude/agents/reviewer.md`
  or a `fileHashes` mismatch fails here.
- **C4.10 (do-NOT-touch, machine-checked).** This unit's own diff
  (`git diff --name-only` over its commits) contains none of
  `hooks/scripts/lib/state-access.sh`, `hooks/scripts/marker-write.sh`
  (item12-1), `bin/fail-count.sh`, `tests/fail-count.test.sh` (item12-2), or
  `templates/persona-protocol.md` (item12-3).
- **C4.11 (the glossary entry stops under-stating the gate).**
  `docs/harness-glossary.md`'s **sanctioned marker-write template** entry
  states that the redirect may be either `>` or `>>`, and that the appending
  form is what a `.fail` record uses. Asserted as a grep for `>>` **within
  that entry's own span** (not file-wide — the file mentions `>>` elsewhere).
  Measured baseline: the entry currently shows only `cat > …`.

### Step 3 amendments (two; its objective is unchanged)

- **A3.1.** Step 3's criteria grep only `templates/ agents/ skills/`, and
  `templates/persona-protocol.md` § "FAIL record" **never stated the overwrite
  behaviour** — so its edit there is an *addition* with no anchoring criterion.
  Add one: `templates/persona-protocol.md`'s § "FAIL record" must contain a
  sentence stating that the record **appends** a block per FAIL verdict and
  that the count is therefore readable across sessions, asserted as a
  per-file grep, plus the regenerated `.claude/persona-protocol.md` and the
  six persona mirrors that carry the trimmed block.
- **A3.2 (ordering dependency, asserted).** Step 4 must land **before** Step 3.
  If Step 3 ships first, the protocol says "appends" while
  `agents/reviewer.md` still documents a truncating `cat > ` — a reviewer would
  then believe it appended while truncating, which is strictly worse than
  today's consistent-but-wrong state. The reverse order is harmless (correct
  behaviour, merely stale-pessimistic prose). Add to Step 3 a precondition
  criterion: `grep -cF "cat >> .claude/reviewed/<task-id>.fail"
  agents/reviewer.md` equals **1** before Step 3's own edits begin.
- **Not changed, deliberately:** the two adapter protocol ports
  (`adapters/codex/agents-md-fragment.md:96`,
  `adapters/cursor/rules/persona-protocol.mdc:103`) say the record exists "so a
  completely fresh spawn … still sees that a unit already failed once." That is
  a purpose statement and remains true of a multi-block record; it makes no
  overwrite claim. Recorded here so a reviewer does not read its survival as a
  missed surface.
- **Inventory for Step 3, measured:** the overwrite claim exists on exactly two
  source surfaces — `agents/spec-master.md:231-232` and
  `skills/fail-triage/SKILL.md:18-19` — plus the one mirror
  `.claude/agents/spec-master.md:232-233`. `skills/` is **not** mirrored into
  `.claude/skills/` (only the six bundled skills are there), so
  `skills/fail-triage/SKILL.md` has no mirror to regenerate. `CONTEXT.md`
  currently has **no** "FAIL record" or "FAIL block" entry, and it already
  carries marker vocabulary (`PASS marker`, `non-blocking note`,
  `marker-directory gate`), so Step 3's glossary criterion is consistent with
  that file's existing scope — it is not harness-mechanics vocabulary
  misfiled out of `docs/harness-glossary.md`.

### Revised dispatch order

`item12-1` (PASSed) → `item12-2` (in flight) → **`item12-4`** → `item12-3`.
Retrieval contract unchanged: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item12-fail-marker-append.md`.

### Unit: item12-4-reviewer-append-shape
- **Objective:** Repoint the reviewer's *documented* `.fail` write at the
  appending form of the sanctioned marker-write template, so the primary write
  path appends and the 2-FAIL cap becomes countable end-to-end.
- **Retrieval:** Amendment A, Step 4, in this document.
- **Affected files:** as Step 4.
- **Ordered edits:** switch the `.fail` literal in `agents/reviewer.md` to
  `cat >>` with a trailing blank body line and the once-per-verdict sentence →
  same change in both adapter reviewer ports, each with its own dot-dir →
  correct the glossary's sanctioned-marker-write-template entry to state `>`
  or `>>` (C4.11) → add the two gate cases (C4.4, C4.5) →
  add the format-parity test (C4.6) →
  mutation-prove both directions (C4.7) → `node bin/cli.js --update` to
  regenerate the `.claude/` mirror and `fileHashes` → bump
  `.claude-plugin/plugin.json` + `CHANGELOG.md` → `bash tests/validate.sh`.
- **Do NOT touch:** `hooks/scripts/lib/state-access.sh` and
  `hooks/scripts/marker-write.sh` (item12-1, PASSed);
  `bin/fail-count.sh`/`tests/fail-count.test.sh` (item12-2, in flight);
  `templates/persona-protocol.md` and the overwrite-claim prose (item12-3);
  the `.pass`/`.blocked` documented literals; `is_sanctioned_marker_write()`
  itself — it already permits `>>`, and no gate change is in scope; **the
  cap's value, which stays 2**.
- **Pre-resolved context:** `human-decision-gate.sh:77`'s regex is
  `^cat[[:space:]]+>>?[[:space:]]*[.]claude/reviewed/…[[:space:]]+<<'<DELIM>'$`,
  and `>>` has been permitted since `2a71911` — verify, do not re-derive.
  `tests/reviewed-path-gate.test.sh` already has the harness you need (canned
  hook-input JSON over stdin, `cfg_reviewer`, every command built from
  `$marker`). `agents/*.md` is version-stamped and `version-stamp-check.sh`
  runs **per commit**, so this unit needs its own bump even though item12-3
  also bumps. Adapter reviewer ports are hand-maintained; `bin/cli.js` will
  not render them for you.
- **Escalation:** you are `lead-programmer` and `reviewed-path-gate.sh` blocks
  you from writing to `.claude/reviewed/` by Bash **and** by Write/Edit — every
  fixture must live under a scratch `dot` (`mktemp -d`), per ADR-0028. If a
  criterion appears to require writing a real marker, report that rather than
  finding a route around the gate. If the adapter ports turn out to be
  generated after all, report the generator rather than hand-editing both.

### Scribe update hint (extended by Amendment A)

Beyond Step 3's **FAIL record** / **FAIL block** entries in `CONTEXT.md`:
`docs/harness-glossary.md`'s **sanctioned marker-write template** entry
under-states the gate it describes — it documents `cat > …` only, while
`is_sanctioned_marker_write()` has permitted `cat >> …` since `2a71911`. The
entry should state both redirect forms and note that a `.fail` record uses the
appending one. Scribe-owned per that file's own header; landed by item12-4
under the same precedent by which Step 3 lands its `CONTEXT.md` entries.

### Clarifications (appended by Amendment A)

- 2026-09-26 Functional scope & success criteria: Q Does the item's Goal hold
  end-to-end once Steps 1-3 land? → A (self-resolved): **no** — measured; the
  primary documented write path bypasses `state_append_unit_marker()`
  entirely. Step 4 added; this is the gap the original Self-check missed
  because every CHK item interrogated the *library* change, none the *caller*.
- 2026-09-26 External dependencies & integrations: Q Does making the reviewer
  append require a gate change? → A (self-resolved): **no** —
  `is_sanctioned_marker_write()`'s regex has permitted `>>` since `2a71911`.
  The gate was never the constraint; the documented literal was.
- 2026-09-26 Edge cases / failure handling: Q What stops a retried append from
  double-counting one verdict? → A (self-resolved): an explicit
  once-per-verdict instruction (C4.3). The same hazard exists on the helper
  path and is not newly introduced by the heredoc form.
- 2026-09-26 Technical constraints & tradeoffs: Q Repoint the reviewer at the
  helper, or teach the documented template to append? → A (self-resolved):
  teach the template — the defect body is multi-line prose with apostrophes
  and backticks that cannot survive an argv slot, and a `reject`-derived body
  may quote the DECISION path, which only the `cat`-heredoc shape is
  sanctioned to carry.

### Self-check (Amendment A)

- CHK-A1: Does the amendment say which of Steps 1-3 it reopens? — PASS (none;
  it is append-only, adds Step 4, and amends Step 3's criteria only).
- CHK-A2: Is the claim "the gate already allows `>>`" verified rather than
  assumed? — PASS (`human-decision-gate.sh:77` plus four commits of
  `git log -L` history).
- CHK-A3: Do Step 4 and Step 3 agree on who owns the version bump? — FAIL
  (conflicting) — revised in place: C4.8 and A3.2 now state that
  `version-stamp-check.sh` is per-commit, so each unit bumps independently.
- CHK-A4: Is every Step 4 criterion runnable? — PASS (each is a grep with a
  stated count, a test-suite case with a stated exit status, or a mutation
  observation).
- CHK-A5: Is Step 4's "documented literal is permitted" criterion proven
  non-vacuous? — PASS (C4.4's lead-programmer control and C4.7's `>>?`→`>`
  gate mutation).
- CHK-A6: Is the surface list for the reviewer instruction enumerated or
  inferred? — FAIL (missing) — revised in place: Step 4 now names both
  hand-maintained adapter reviewer ports with line numbers, and the Step 3
  amendments record the two adapter protocol ports as deliberately unchanged.
- CHK-A7: Does the amendment change the cap's value? — PASS (it does not; the
  do-NOT-touch list says so explicitly, preserving item12-3's constraint).
- CHK-A8: Does the amendment leave a defined order for the two undispatched
  units? — PASS (A3.2 states Step 4 before Step 3, with the asymmetric-harm
  argument and an asserted precondition).
- CHK-A9: Is the `^FAIL ` over-count hazard assigned to an owner? — PASS
  (recorded for item12-2's reviewer, explicitly not specced here, since
  `bin/fail-count.sh` already uses the qualified anchor).
- CHK-A10: Was every criterion this amendment authors measured against its own
  baseline before handoff? — FAIL (ambiguous) — revised in place: baselines
  measured (`cat >` literals = 0 in `agents/reviewer.md` and both adapter
  ports; "exactly once per verdict" = 0), which exposed that C4.1's *negative*
  half is already satisfied at baseline. C4.1 now labels that half a
  regression guard rather than evidence, and the finding's framing is
  corrected from "the literal truncates" to "there is no literal".
- CHK-A11: Does the amendment name who owns `docs/harness-glossary.md`? — FAIL
  (missing) — revised in place, not escalated: that file states in its own
  header that it is "owned by `scribe`, same custody as `CONTEXT.md`", and
  Step 3 of this very plan already assigns `CONTEXT.md` edits to its
  implementing unit with a Scribe update hint recording them. C4.11 follows
  that settled precedent rather than opening a question the plan has already
  answered for the sibling file. The Scribe update hint below is extended
  accordingly.
