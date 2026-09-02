# Advisory-note channel: routing a reviewer's PASS notes to spec-master (issue #295)

Date: 2026-09-01
Status: FINAL — ready for dispatch (fast path, **4 units** after Addendum A, no
`task-master` slicing). Amended 2026-09-01 by Addendum A: a new **Step 1b**
lands between Step 1 and Step 2, Step 2 gains two clauses, and AC1.8 is
superseded as a point-in-time snapshot. Read Addendum A before dispatching
`gh295-2`.
Issue: #295

## Goal

Give a reviewer's non-blocking notes on a **PASSing** review a deterministic,
on-demand route to `spec-master`, so spec/code divergence noticed at review
time is available to whoever writes the next spec instead of dying on a
marker nobody reads.

Concretely, three things must become true:

1. A reviewer writing a PASS marker **classifies** each non-blocking note as
   `NOTE[spec]:` (spec/code divergence, undocumented load-bearing behaviour,
   or a warning about a step not yet dispatched) or `NOTE[code]:` (everything
   else), under a required, greppable section heading.
2. A **deterministic script** can enumerate those notes across every marker
   and filter them by the file surfaces a new plan touches.
3. `spec-master` is **required to run that sweep** before writing a follow-up
   spec, the same way it already screens `.fail` records.

## Context

Issue #295 was raised by `milestone-auditor` on 2026-08-09 (Finding #7,
moderate). Two premise corrections matter before reading it:

**The issue's four sub-items are already closed.** A 2026-08-11 round fixed
them and recorded the deferral explicitly —
`docs/plans/2026-08-09-agent-auditor-persona.md:2030` reads: *"Issue #295's
systemic recommendation is deferred and NOT addressed here."* That round's own
decay table (`:1957-1960`) found two of the four already stale when checked.
Re-verified 2026-09-01: the effective-tools formula at `:269-272` now
documents three union terms including `SendMessage`, and
`scripts/agent-audit.sh:367-369,613-615` emits `status=executed|refused`. **The
live scope of #295 is the systemic half only.** Anyone citing the four
sub-items as evidence of a live defect is reading a stale issue body.

**The problem got worse after the issue was filed.** ADR-0024
(`docs/adr/0024-ceremony-reduction-solo-operator.md:28-41`, 2026-08-16) made
the milestone audit fire **only when the operator explicitly asks**. The
milestone audit was the sole backstop that ever caught these notes. #295 said
drift is "discoverable only by a milestone audit (which runs rarely)"; it is
now discoverable only by one that never runs unattended.

**The notes are real and plentiful.** Measured 2026-09-01 over
`.claude/reviewed/`: 300 `.pass` markers, **285 multi-line**, 266 containing
"non-blocking notes" case-insensitively, **232** matching a loosened
line-initial anchor `^[#> -]{0,4}[Nn]on-blocking [Nn]ote`, but only **80**
matching the exact `^Non-blocking notes:`. A parser anchored on the exact form
alone misses ~70% of note-carrying markers. **0 markers carry a `NOTE[` tag**
(`grep -rlF "NOTE[" .claude/reviewed/` returns nothing) — this is why the
sweep's tag filter defaults to `all`, not `spec` (see Step 1).

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-01 Functional scope & success criteria: Q Does "reaching
  spec-master" mean a queryable store, an auto-loaded one, or a filed issue?
  → A: a queryable store — `--notes` mode on the existing
  `marker-verify.sh`/`marker-audit.sh` pair, run on demand by `spec-master`.
  No new writer, no new automatic trigger (OQ1a, per user)
- 2026-09-01 Domain entities / data model: Q Is an advisory note a tagged
  line, a record, or an issue? → A: a tagged line on the existing `.pass`
  marker; `NOTE[spec]:` / `NOTE[code]:` prefix applied by the reviewer at
  write time (OQ2a, per user)
- 2026-09-01 User interaction flow: Q Who runs the channel and when? → A:
  the reviewer tags at PASS-write time; `spec-master` runs the sweep before
  writing any follow-up spec. Nothing runs automatically (OQ1a/OQ2a, per user)
- 2026-09-01 Non-functional attributes: Q What is the scale, and is automatic
  triggering acceptable? → A (self-resolved): 300 markers, ~232 note-carrying,
  trivially fast; ADR-0024 forbids new automatic triggering, so the channel is
  on-demand only. Durability resolved by OQ1a: the store stays gitignored and
  the sweep is explicitly best-effort (see R2)
- 2026-09-01 Edge cases / failure handling: Q How are legacy unstructured
  markers handled? → A: loose-anchor fallback, then an
  everything-after-line-1 fallback, both classified `untagged`; **no
  retroactive backfill** (OQ4a, per user)
- 2026-09-01 Technical constraints & tradeoffs: Q What may write where? →
  A (self-resolved): `.claude/reviewed/` is gitignored (`.gitignore:12`) and
  write-gated to the reviewer alone, so the sweep is read-only and no
  disposition ledger lives there; note-format edits are a five-artifact change
- 2026-09-01 Terminology consistency: Q Is "advisory note" a defined term? →
  A (self-resolved): no. `CONTEXT.md`'s `## Language` glossary defines
  **Reporter** (`:172`), **Gate** (`:166`) and **state-artifact species**
  (`:454`, which already lists `.pass` markers) but has **no entry** for an
  advisory note as a channel or artifact — a lens-3 finding. The issue and
  early drafts also alternated "advisory note" / "non-blocking note" for one
  thing (lens 2); the canonical form in the persona bodies is **non-blocking
  note**, and this plan uses it. Lens 1 turned up nothing: no glossary term is
  used here with a divergent meaning. Category 8 stays **Partial** until Step
  3 lands the glossary entry — advisory only, and it does not block dispatch.
- 2026-09-01 Completion / acceptance signals: Q What closes #295? → A
  (self-resolved): the channel existing and being consulted — *not* the four
  sub-items, which `plan:2030` already closed. Per-step criteria below are the
  acceptance signal.

## Risks and dependencies

- **R1 — Both Step 1 and Step 2 are mirror + `fileHashes` changes.**
  `.claude/hooks/scripts/marker-verify.sh` (`persona-config.json:250`),
  `.claude/agents/reviewer.md` (`:197`) and `.claude/agents/spec-master.md`
  (`:194`) are all managed entries. `bin/cli.js` rewrites the **whole**
  `fileHashes` map and cannot render a subset, and `--update --force-render`
  also re-stamps `.claude/persona-protocol.md`, `persona-protocol-slim.md` and
  `protocol-digest.md` whether or not their content changed. Each step must
  therefore run `node bin/cli.js --update --force-render` **inside its own
  unit** and commit everything it regenerates; those hunks are pre-authorized
  here so a reviewer does not FAIL them as out-of-scope. Steps are strictly
  sequential for this reason — two concurrently-open units would collide on
  the map. Prior defect history for this exact class is extensive:
  `gh385-2.fail`, `gh402.pass` note 1, `gh403.fail`, `mw-step3.fail`,
  `spec2-unitE.fail`. **No step here may be tagged `haiku`.**
- **R2 — The store is gitignored, so the sweep is best-effort, never an
  authority.** `.gitignore:12` excludes `.claude/reviewed/`; the markers are
  untracked per-clone state with no history and no recovery source. A note
  absent from a sweep may simply never have existed in this clone. Step 2's
  duty text must say this explicitly, so no future spec claims "swept,
  therefore clean."
- **R3 — Defaulting the tag filter to `spec` would ship a tool that returns
  nothing.** 0 of 300 markers carry a tag today. The default is `all`.
- **R4 — `marker-verify.sh`'s "always exactly one output line" contract.**
  Its header comment states it. `--notes` deliberately emits zero-or-more note
  lines plus one summary line; the header comment must be amended in the same
  edit or it becomes a false statement in the shipped file.
- **R5 — `marker-verify.sh` must never gain policy power.** Its header
  records a safety property: advisory only, always exits 0, MUST NEVER be
  registered in any hook. `--notes` preserves all three. It must also never
  execute a marker's criteria — Step 1 carries a sentinel test for this.
- **R6 — Adapter ports are out of scope, verified.** Neither
  `adapters/cursor/agents/reviewer.md` nor `adapters/codex/agents/reviewer.toml`
  carries the note-writing duty, and `tests/adapter-protocol-parity.test.js`
  has no probe matching it. No adapter edit and no new probe is required. This
  was confirmed by an `explorer` source-read of `bin/cli.js`'s render loop and
  by independent grep — **not** graph-derived; the graph indexes symbols, not
  a render loop's output set, so the render-fixed-point criterion in each step
  is what actually proves the file set, not this enumeration.
- **R7 — Nothing in this plan touches the PASS-marker v3 first line**, the
  `ESCALATE-TO-HUMAN` / `INSUFFICIENT-CONTEXT` routes, or
  `milestone-auditor`'s report format. Those were named boundaries.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every corpus figure in this plan was
  measured on 2026-09-01 and the command is named; the two stale premises in
  issue #295 were re-verified rather than inherited.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  channel is a script (`--notes` sweep), not an instruction to read markers
  carefully. This principle is the reason OQ1(d) (instruction-only) was
  rejected.
- P3 "Version-stamp discipline": satisfied — Step 3 bumps
  `.claude-plugin/plugin.json` and `package.json` together (both at 0.31.67
  today) in the order bump → CHANGELOG → `--update --force-render`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — in a project
  with no `reviewer` persona no marker is ever written, so the sweep returns
  an empty result and `spec-master`'s duty is a no-op. No error path.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step's final
  criterion is `bash tests/validate.sh` exit 0 in a pristine worktree at the
  step's own commit.

## Steps

### Step 1 — `--notes` mode on the marker-verify / marker-audit pair

Add note enumeration to the existing read-only sweep pair. No new script, no
new seam.

**`hooks/scripts/marker-verify.sh --notes <task-id> [project-dir]`** emits
zero or more note lines followed by exactly one summary line:

```
marker-note=<spec|code|untagged> unit=<id> <note text, whitespace-collapsed to one line>
marker-notes=<n> unit=<id> spec=<a> code=<b> untagged=<c>
```

Note-section location, in order, first match wins:
1. exact anchor — a line equal to `Non-blocking notes:`
2. loosened anchor — `^[#> -]{0,4}[Nn]on-blocking [Nn]ote`
3. fallback — every non-blank line after the marker's first line

A note runs from its own start line until the next note start or end of file;
its emitted text is those lines joined by single spaces. A note's tag is
`spec` or `code` when the line carries a `NOTE[spec]:` / `NOTE[code]:` prefix
(after optional list numbering and indentation), otherwise `untagged`.

**`bin/marker-audit.sh [project-dir] --notes [--tag=T] [--surface=S ...]`**
sweeps every `.pass` marker through that mode and prints a final aggregate
line `marker-notes-sweep=<total> markers=<m> spec=<a> code=<b> untagged=<c>`.
`--tag` defaults to `all`. `--surface=S` is repeatable and keeps only note
lines whose text contains the plain substring `S`.

**Affected files:** `hooks/scripts/marker-verify.sh` (add `--notes`; amend the
header comment per R4), `bin/marker-audit.sh` (add `--notes`, `--tag`,
`--surface` passthrough and the aggregate line; amend its header comment),
`tests/marker-verify.test.sh` (new cases), plus whatever
`node bin/cli.js --update --force-render` regenerates — expected to include
`.claude/hooks/scripts/marker-verify.sh` and `.claude/persona-config.json`'s
`fileHashes`, pre-authorized per R1.

**Acceptance criteria** (run in a pristine detached worktree at this step's
own commit — `git worktree add --detach <tmp> <sha>` — never the live tree):

- AC1.1 `bash tests/marker-verify.test.sh` exits 0.
- AC1.2 *(mutation proof, non-vacuity)* With the `--notes` branch in
  `hooks/scripts/marker-verify.sh` replaced by an immediate `exit 0`,
  `bash tests/marker-verify.test.sh` exits **non-zero**. Restore afterwards.
- AC1.3 *(fixture, exact)* A fixture marker whose body contains the exact
  anchor and one `NOTE[spec]:` note plus one `NOTE[code]:` note yields exactly
  two `marker-note=` lines, tagged `spec` and `code` respectively, and a
  summary line `marker-notes=2 unit=<id> spec=1 code=1 untagged=0`.
- AC1.4 *(fixture, loose anchor)* A fixture marker using ` - Non-blocking
  notes` (leading space and dash, no colon) still yields its notes, classified
  `untagged`.
- AC1.5 *(fixture, fallback)* A fixture marker with body lines but no anchor
  of either form yields its non-blank post-first-line content as `untagged`
  notes rather than zero notes.
- AC1.6 *(fixture, safety — R5)* A fixture marker whose `criteria:` field is
  `touch $TMPDIR/SENTINEL` produces **no** `SENTINEL` file when run under
  `--notes`, and `marker-verify.sh --notes` exits 0. Prior art: the existing
  SENTINEL case in `tests/marker-verify.test.sh`.
- AC1.7 *(fixture, surface filter)* Given two fixture markers whose notes
  mention `bin/cli.js` and `hooks/scripts/stop-gate.sh` respectively,
  `bin/marker-audit.sh <fixture> --notes --surface=bin/cli.js` emits exactly
  one `marker-note=` line, and it is the `bin/cli.js` one.
- AC1.8 *(live-corpus smoke, expiry-proof)* `bash bin/marker-audit.sh . --notes`
  exits 0 and its final line reports `spec=0 code=0` (no marker is tagged yet)
  with `untagged` **≥ 200**. Deliberately a floor, not a pin: the corpus grows.
- AC1.9 *(render fixed point)* `node bin/cli.js --update --force-render && git status --porcelain`
  emits **zero** lines.
- AC1.10 `bash tests/validate.sh` exits 0.

### Step 2 — Reviewer tags notes; spec-master consults the sweep

**Affected files:** `agents/reviewer.md`, `agents/spec-master.md`, plus
whatever `node bin/cli.js --update --force-render` regenerates — expected to
include `.claude/agents/reviewer.md`, `.claude/agents/spec-master.md`, the
three protocol/digest files and `fileHashes`, pre-authorized per R1.
`templates/persona-protocol.md` is **not** edited: its "the marker MAY carry
the reviewer's non-blocking notes" sentence stays true, and leaving it alone
keeps six inlined persona mirrors out of the blast radius.

In `agents/reviewer.md`, amend the existing note-appending sentence so that,
when the reviewer has any non-blocking notes, the section MUST open with a
line reading exactly `Non-blocking notes:` and every note MUST carry a
`NOTE[spec]:` or `NOTE[code]:` prefix, under this classification rule:

> `NOTE[spec]` if the note describes any one of: (a) a divergence between the
> shipped code and what a plan, spec, ADR or doc says; (b) a load-bearing
> input, flag, env var or behaviour that the plan does not document; or (c) a
> warning that applies to a step not yet dispatched. `NOTE[code]` otherwise.

In `agents/spec-master.md`, widen the existing bullet — "Check
`.claude/reviewed/` for `.fail` records before revising a plan" — to also
require, before writing any follow-up spec, one
`bash bin/marker-audit.sh . --notes --surface=<path>` run per file or
directory the new plan touches; every returned `NOTE[spec]` line, and every
`untagged` line naming a step not yet dispatched, is a required input whose
disposition is recorded in the plan's Context or Risks section. The bullet
must also state R2 verbatim in substance: the store is gitignored, so the
sweep is best-effort and never authority for "no note exists."

**Acceptance criteria** (pristine detached worktree at this step's own commit):

- AC2.1 *(branch agreement — the load-bearing criterion)* A check in
  `tests/marker-verify.test.sh` asserts that all three literals the parser
  matches on — `Non-blocking notes:`, `NOTE[spec]:` and `NOTE[code]:` — occur
  **both** in `hooks/scripts/marker-verify.sh` and in `agents/reviewer.md`.
  This is what catches the classic drift where the persona documents one
  anchor and the parser matches another; a plain existence grep in one file
  would gate nothing.
- AC2.2 *(mutation proof for AC2.1)* Changing the anchor literal in
  `agents/reviewer.md` alone (e.g. to `Non-blocking Notes:`) makes
  `bash tests/marker-verify.test.sh` exit non-zero. Restore afterwards.
- AC2.3 *(claim-anchored, not an existence grep)* The
  `bin/marker-audit.sh` invocation quoted in `agents/spec-master.md` is
  extracted and run as written, substituting a real path for the
  `--surface=` placeholder; it exits 0. A quoted command that does not run is
  a defect.
- AC2.4 `agents/spec-master.md` contains the gitignored/best-effort caveat —
  verified by a reviewer read against R2, not by grep alone.
- AC2.5 *(render fixed point)* `node bin/cli.js --update --force-render && git status --porcelain`
  emits **zero** lines.
- AC2.6 `bash tests/validate.sh` exits 0.

### Step 3 — Glossary entry, CHANGELOG, version bump (scribe)

Ordered strictly: bump → CHANGELOG → `--update --force-render` → commit.

**Affected files:** `.claude-plugin/plugin.json` and `package.json` (0.31.67 →
0.31.68, both, equal — `tests/validate.sh:80` asserts equality), `CHANGELOG.md`,
`CONTEXT.md`, plus everything `--update --force-render` re-stamps. `CONTEXT.md`
is **not** in `fileHashes` and is not managed by `bin/cli.js`; editing it is
free of the mirror machinery.

Add a `## Language` entry defining the **non-blocking note** as a channel:
what the two tags mean, the required anchor, that the sweep is the read side,
that the store is gitignored and best-effort, and that `.pass` markers are
already listed under **state-artifact species** (`CONTEXT.md:454`) — cross-link
rather than duplicate. Use the canonical term **non-blocking note**; do not
introduce "advisory note" as a second name for it.

**Acceptance criteria** (pristine detached worktree at this step's own commit):

- AC3.1 `.claude-plugin/plugin.json` and `package.json` both read `0.31.68`.
- AC3.2 `CHANGELOG.md` has a `0.31.68` entry naming the `--notes` sweep and
  the note-tagging requirement.
- AC3.3 *(branch agreement)* The `CONTEXT.md` entry contains the same three
  literals asserted in AC2.1, and the AC2.1 check is extended to include
  `CONTEXT.md` as a third file. Mutation proof: changing the anchor literal in
  `CONTEXT.md` alone makes `bash tests/marker-verify.test.sh` exit non-zero.
- AC3.4 *(render fixed point)* `node bin/cli.js --update --force-render && git status --porcelain`
  emits **zero** lines.
- AC3.5 `bash tests/validate.sh` exits 0.

## Open Questions

None blocking. OQ1–OQ4 were answered 2026-09-01 (recommended default taken in
every case) and are recorded in Clarifications. **Addendum A adds OQ-A1
(also non-blocking) — see A.7.** Two named assumptions:

1. **The channel is on-demand, not enforced.** No hook checks that
   `spec-master` actually ran the sweep. This is deliberate (ADR-0024's
   posture; ADR-0021 is the precedent for deferring a hook backstop as
   disproportionate) and it means the channel can still be skipped by a
   spec-master that ignores its own duty bullet. If that recurs after this
   lands, a `stop-gate.sh` branch is the starting point for future work.
2. **No retroactive backfill.** The ~232 existing note-carrying markers stay
   `untagged` forever; they remain findable by `--surface` but not by `--tag`.
   Retro-tagging is close to impossible anyway — the directory is gitignored
   and write-gated to the reviewer alone.

## Self-check

- CHK1: Is the note-section anchor defined identically everywhere it appears
  (parser, reviewer duty, glossary)? — PASS (AC2.1/AC3.3 assert it mechanically
  rather than by prose agreement)
- CHK2: Does every step have a criterion that fails before the change and
  passes after? — PASS (AC1.2, AC2.2, AC3.3 are explicit mutation proofs;
  AC1.9/AC2.5/AC3.4 fail loudly pre-fix with dirty-tree lines)
- CHK3: Do Steps 1 and 2 agree on the output format the spec-master duty
  consumes? — PASS (Step 2's duty names `NOTE[spec]` lines and `untagged`
  lines, both defined in Step 1's output grammar)
- CHK4: Is the tag-filter default stated, and consistent with the measured
  corpus? — FAIL (missing in first draft) — revised in place: default `all`,
  with R3 and AC1.8 recording the 0-of-300 measurement that forces it
- CHK5: Does any criterion pin a live-corpus number that will expire? — FAIL
  (ambiguous in first draft: AC1.8 originally pinned `markers=300`) — revised
  in place to a `≥ 200` floor with the exact assertions moved to fixtures
- CHK6: Is the `marker-verify.sh` one-line output contract addressed rather
  than silently broken? — FAIL (missing in first draft) — revised in place as
  R4, with the header-comment amendment in Step 1's affected files
- CHK7: Are the `fileHashes` and protocol-restamp hunks pre-authorized so a
  reviewer does not FAIL them as out-of-scope? — PASS (R1, and each step's
  affected-files list)
- CHK8: Does the plan claim the file enumeration is graph-derived when it is
  not? — PASS (R6 states plainly that it is grep- and source-read-derived, and
  names the render-fixed-point criterion as the real proof)
- CHK9: Is "advisory note" used as a synonym for "non-blocking note" anywhere
  in the shipped text? — PASS (title and issue quotes only; Step 3 pins the
  canonical term and forbids the synonym)

## Addendum A — 2026-09-01: reviewer advisory findings on `gh295-1`

`gh295-1` PASSed at `e00d48a`. Its PASS marker carried two non-blocking notes
the reviewer explicitly routed here. Both are accepted; this addendum records
what was re-measured, what changed, and what did not. **`gh295-1` is not
re-opened** — every change below is a new unit or a Step 2 clause.

### A.1 — Finding 1 re-measured: it is two defects, not one

The reviewer's item merged two independent mechanisms under one heading, and
attached the population figure of one to the illustration of the other.
Separated and re-measured 2026-09-01 at `7581ca6` over 301 `.pass` markers
(233 of which have a note section under the loose anchor):

**Defect A — tag *mis-attribution* via indented continuation.**
`hooks/scripts/marker-verify.sh:78` merges any line beginning with whitespace
into the current note. An indented, tagged line therefore never starts a note,
and inherits the *preceding* note's tag. Reproduced verbatim:

| body under the anchor | parsed today |
| --- | --- |
| `- NOTE[code]: a` then `  - NOTE[spec]: b` | **one** note, `tag=code`, text `- NOTE[code]: a - NOTE[spec]: b` |
| `  - NOTE[spec]: b` alone (first note in section) | one note, `tag=spec` — correct, because `have=0` so the merge branch never fires |

This is worse than tag loss: the note is reported under the **wrong** tag and
is invisible to `--tag=spec`. Population: **19 of 233** note sections carry an
indented list line. (The reviewer's "47 of 300" is the whole-marker count of
indented list lines, which also counts lines outside the note section; scoped
to note sections it is 19. The figure is real, the scope was wider than the
defect.)

**Defect B — tag *loss* via emphasis wrapper.**
`marker-verify.sh:85` strips exactly one leading list marker before the `case`.
Every row below was executed against the shipped classification logic:

| note line as written | tag today |
| --- | --- |
| `NOTE[spec]: x` | `spec` |
| `- NOTE[spec]: x` | `spec` |
| `* NOTE[code]: x` | `code` |
| `1. NOTE[spec]: x` / `1) NOTE[code]: x` | `spec` / `code` |
| `- **NOTE[spec]:** x` | **`untagged`** |
| `**NOTE[code]:** x` | **`untagged`** |
| ``- `NOTE[spec]:` x`` | **`untagged`** |
| `- __NOTE[code]:__ x` | **`untagged`** |
| `- _NOTE[spec]:_ x` | **`untagged`** |

Population: **79 of 233** note sections already contain a bold- or
backtick-led line — the *larger* of the two defects, and the one the reviewer
illustrated but did not measure. 12 sections carry both shapes.

**Severity ordering:** A yields a wrong tag (correctness); B yields `untagged`
(coverage). Both become live the moment Step 2 obliges reviewers to write tags.

### A.2 — Verdict: Step 2 needs amendment, and a new Step 1b lands first

Mandating the bare form in `agents/reviewer.md` and hoping for compliance is
**not sufficient**, for three measured reasons:

1. 79 of 233 (34%) of existing note sections already use the style that
   breaks. Bold and backtick emphasis is this corpus's house style, not an
   exotic edge case.
2. The failure is **silent**. A mis-parsed note emits no warning; it just
   reports `untagged`, or worse (Defect A) reports the wrong tag.
3. R2 plus Open-Questions assumption 2 make it **permanent**. The store is
   gitignored with no recovery source and there is no backfill, so a note
   mis-parsed at write time is mis-parsed forever.

So the parser is hardened to tolerate the forms reviewers actually write, and
the convention text is tightened as a second layer — belt and braces, not
either alone.

**Why a separate Step 1b rather than folding this into Step 2:**

- **Ordering.** Harden *before* mandating. If the tolerance landed after Step
  2, every note written in the window would be permanently mis-tagged (no
  backfill).
- **It does not re-open `gh295-1`.** New unit, same file, strictly additive
  behaviour. `gh295-1`'s PASS at `e00d48a` stands untouched.
- **It keeps Step 2's blast radius agent-files-only**, so AC2.1/AC2.5 survive
  exactly as designed instead of being re-derived around new script hunks.
- Unit count goes 3 → 4, still ≤ 5, so the **fast path holds** and
  `task-master` is still not involved.

Folding Step 1b into Step 2 as one larger unit is an acceptable alternative if
you prefer fewer dispatches; the ordering constraint is satisfied either way
because the parser change would land in the same commit as the mandate. It is
*not* acceptable to dispatch `gh295-2` first and defer the parser work.

### Step 1b — Parser tolerance for wrapped and indented tags

**Ordering: after Step 1 (`e00d48a`), before Step 2.** Sequential per R1.
Suggested model: **not `haiku`** (R1 — mirror + `fileHashes` change).

**B1 — wrapper tolerance.** Before tag classification, normalize a note's
first line by stripping, repeatedly until the line stops changing: leading
whitespace, one leading list marker (`-`, `*`, `N.`, `N)`, and the existing
`A1`-style token), and leading emphasis/code wrappers (`*`, `_`, `` ` ``).
Trailing wrappers need no handling — the existing `NOTE[spec]:*` glob already
tolerates them. Normalization is used **only** to decide the tag; the emitted
note text stays verbatim as today.

**B2 — an indented tagged line starts a new note.** An indented line that
normalizes to a `NOTE[spec]:` or `NOTE[code]:` prefix starts a **new** note
instead of merging as a continuation. An indented line that does **not**
normalize to a tag keeps merging exactly as today.

> Deliberate consequence, and the reason B2 is safe: the parse is
> **bit-identical** for every marker carrying no `NOTE[` tag anywhere — 300 of
> the 301 markers today — so no legacy `untagged` count and no legacy
> `--surface` result moves. Exactly one marker changes:
> `.claude/reviewed/gh295-1.pass`, the reviewer's own, whose tags are
> currently swallowed as continuations.

Amend `marker-verify.sh`'s header comment in the same edit (R4 discipline: the
header is a shipped claim, not a comment).

**Discretionary, per OQ-A1:** `bin/marker-audit.sh` adds `malformed=<d>` to its
aggregate line — the count of emitted `marker-note=` lines whose tag is
`untagged` yet whose text contains the substring `NOTE[`. Derived by the audit
script from lines it already receives, so `marker-verify.sh`'s per-unit output
grammar (R4) is untouched. This is the only mechanism that makes an unknown
future wrapper variant *visible* rather than silent.

**Affected files:** `hooks/scripts/marker-verify.sh`, `bin/marker-audit.sh`
(only if OQ-A1 is accepted), `tests/marker-verify.test.sh`, plus whatever
`node bin/cli.js --update --force-render` regenerates — expected to be
`.claude/hooks/scripts/marker-verify.sh` and `.claude/persona-config.json`'s
`fileHashes` (managed entry confirmed at `persona-config.json:250`),
pre-authorized per R1. `bin/marker-audit.sh` is **not** a managed entry and
carries no mirror.

**Acceptance criteria** (pristine detached worktree at this step's own commit —
`git worktree add --detach <tmp> <sha>` — never the live tree):

- **AC1b.1** *(classification table)* `tests/marker-verify.test.sh` asserts
  every row of A.1's Defect-B table as a fixture marker under the exact anchor,
  with the five `untagged` rows now required to yield `spec`/`code` as written,
  and the four already-passing rows unchanged. Prior art: the existing AC1.3
  cases using `write_marker_body` / `expect_exact`.
- **AC1b.2** *(over-match guards — tolerance must not become greedy)* These
  four lines must **still** classify `untagged`: `NOTE[spec] no colon x`,
  `see NOTE[spec]: mid-sentence`, `NOTE[other]: x`,
  `- Non-blocking: plain prose`. All four were measured `untagged` today; a
  tolerance change that flips any of them is a regression.
- **AC1b.3** *(Defect A fixed)* A fixture body of `- NOTE[code]: a` followed by
  `  - NOTE[spec]: b` yields **two** notes, `marker-notes=2 ... spec=1 code=1
  untagged=0`, in that order. Today it yields one note tagged `code`.
- **AC1b.4** *(Defect A fix is narrow)* A fixture body of `- NOTE[code]: a`
  followed by `  more prose about a` still yields **one** note,
  `tag=code`, text `- NOTE[code]: a more prose about a`. Untagged indented
  lines must keep merging.
- **AC1b.5** *(legacy-parse invariance, expiry-proof)* A fixture corpus of at
  least three legacy-shaped markers containing no `NOTE[` substring anywhere —
  one exact-anchor, one loose-anchor, one no-anchor fallback — produces
  **byte-identical** `bin/marker-audit.sh <fixture> --notes` output before and
  after the change. Fixture-based deliberately, not live-corpus: a live count
  here would be a decaying baseline (see A.3).
- **AC1b.6** *(mutation proof for B1)* Reverting the normalization to the
  single-list-marker `sed` alone makes `bash tests/marker-verify.test.sh` exit
  **non-zero**. Restore afterwards.
- **AC1b.7** *(mutation proof for B2, separate from AC1b.6)* Reverting only the
  indented-tagged-line rule — leaving B1 in place — makes
  `bash tests/marker-verify.test.sh` exit **non-zero**. Restore afterwards. Two
  separate proofs because one combined proof could be satisfied by either half
  alone.
- **AC1b.8** *(safety — R5, unchanged)* The existing SENTINEL case still
  passes: `--notes` never executes a marker's `criteria:` field and still exits
  0.
- **AC1b.9** *(only if OQ-A1 accepted)* A fixture marker whose note reads
  `- NOTE[bogus]: x` causes `bin/marker-audit.sh <fixture> --notes` to report
  `malformed=1` in its aggregate line, and a fixture with no such line reports
  `malformed=0`.
- **AC1b.10** *(live-corpus smoke — see A.3 for what may and may not be pinned)*
  `bash bin/marker-audit.sh . --notes` exits 0 and its final line reports
  `untagged` **≥ 200**. Do **not** assert `spec=0`, `code=0`, or a `markers=`
  value.
- **AC1b.11** *(render fixed point)* `node bin/cli.js --update --force-render && git status --porcelain`
  emits **zero** lines.
- **AC1b.12** `bash tests/validate.sh` exits 0.

### A.3 — Finding 2: AC1.8 is a point-in-time snapshot, now superseded

**AC1.8's `spec=0 code=0` half is a snapshot of the corpus on 2026-09-01. It
was satisfied and recorded at `gh295-1`'s PASS (`e00d48a`). Do not re-assert it
verbatim in any later unit, regression check or CI gate — it is not a survival
pin, and re-asserting it will FAIL on a correct, intended state change.**

Three corrections to how the reviewer framed it:

1. **It expires at Step 1b, not Step 2.** `gh295-1.pass` is the one marker of
   301 that already contains `NOTE[` lines. Measured today,
   `bash bin/marker-audit.sh . --notes` ends
   `marker-notes-sweep=2494 markers=301 spec=0 code=0 untagged=2494` — and
   `spec=0 code=0` holds **only because Defect A swallows those lines as
   continuations**. The instant B2 lands, they parse, and `spec`/`code` go
   non-zero at Step 1b's own commit. The criterion is currently true for the
   wrong reason.
2. **Only the `spec=0 code=0` half expires.** The `untagged ≥ 200` floor
   remains valid and may be re-asserted freely; it was deliberately written as
   a floor rather than a pin for exactly this reason (CHK5).
3. **The general rule for any later live-corpus smoke on this channel:** assert
   exit 0 and `untagged ≥ 200`, nothing else. Never `spec=`, never `code=`,
   never `markers=`. AC1b.10 above is the corrected form; copy that, not AC1.8.

No change is made to Step 1 or to `gh295-1`'s recorded PASS. This is an
annotation on a satisfied criterion, not a reopening of it.

### A.4 — Step 2 amendments (two, both small)

**A.4.1 — `agents/reviewer.md` gains a form clause** alongside the
classification rule already specified in Step 2:

> Write the tag **bare** at the start of the note's own line, at column 0
> beneath the anchor: no bold, italic or backtick emphasis around it, and no
> leading indentation. A line indented beneath a note is a **continuation** of
> that note, not a new note.

and a three-line worked example block showing one `NOTE[spec]:` note, one
`NOTE[code]:` note, and one indented continuation line.

**A.4.2 — new AC2.7** *(claim-anchored; prior art AC2.3)*: the worked example
block is extracted verbatim from `agents/reviewer.md`, written into a fixture
marker under the exact anchor, and run through
`hooks/scripts/marker-verify.sh --notes`. It must yield exactly two notes,
tagged `spec` and `code` in that order, with the indented line merged into its
parent note. A documented example the shipped parser mis-reads is a defect.
*Mutation proof:* changing the example's tag to `NOTE[specs]:` (or dropping its
colon) makes `bash tests/marker-verify.test.sh` exit non-zero. Note that
wrapping the example in `**` is **not** a valid mutation after Step 1b, since
B1 makes that parse correctly by design.

**AC2.1 is unaffected.** Step 1b leaves the three bare literals
(`Non-blocking notes:`, `NOTE[spec]:`, `NOTE[code]:`) in the parser's `case`
patterns, so the three-file branch-agreement check still works unchanged. The
same holds for AC3.3's extension to `CONTEXT.md`.

**Step 3 pickup:** the glossary entry should also define **emphasis wrapper**
and (if OQ-A1 is accepted) **malformed tag**, and state that the bare,
column-0 form is canonical while wrapped forms are tolerated by the parser.
This is a lens-3 finding from the `ubiquitous-language` prose check run over
this addendum; `CONTEXT.md` has no entry for either term today (it uses
"malformed" in five unrelated senses, at `:231`, `:277`, `:1235`, `:1333`,
`:2254`). Advisory only — it does not block dispatch.

### A.5 — Clarifications (appended, amendment scope)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-01 Edge cases / failure handling: Q Which wrapper forms must the
  parser tolerate, and which must keep classifying `untagged`? → A
  (self-resolved): tolerate leading list markers and leading `*`/`_`/`` ` ``
  emphasis in any repetition (B1); keep `untagged` for a missing colon, a
  mid-sentence tag, an unknown tag name, and plain prose (AC1b.2). All nine
  tolerated rows and all four guard rows were executed against the shipped
  logic before being written as criteria.
- 2026-09-01 Edge cases / failure handling: Q Should an unknown future wrapper
  variant fail loudly or silently? → A: **open** — see OQ-A1. Default
  recommendation is loudly, via a derived `malformed=` count.
- 2026-09-01 Terminology consistency: Q Do "emphasis wrapper" and "malformed
  tag" have glossary entries? → A (self-resolved): no; both are lens-3
  findings, routed to Step 3's existing glossary deliverable rather than
  creating a new unit. Lens 1 and lens 2 turned up nothing in this addendum —
  no glossary term is used with a divergent meaning, and no new synonym for
  **non-blocking note** was introduced.

### A.6 — Self-check (amendment scope)

- CHK10: Is every "before" value in A.1's classification table a measured
  observation rather than a reading of the regex? — PASS (all thirteen
  single-line rows and both multi-line cases were executed against a verbatim
  copy of `marker-verify.sh:66-94`)
- CHK11: Does the addendum's population figure for Defect A agree with the
  reviewer's, or explain the divergence? — FAIL (conflicting) — revised in
  place: A.1 now states both figures and names the scope difference
  (whole-marker 47 vs note-section 19)
- CHK12: Does Step 1b have a criterion that fails before the change and passes
  after, separately for each of its two behaviour changes? — PASS (AC1b.6 and
  AC1b.7 are separate mutation proofs, explicitly so that one cannot mask the
  other)
- CHK13: Does any criterion in Step 1b pin a live-corpus number that will
  expire? — FAIL (ambiguous in first draft: the legacy-invariance check was
  written against the live corpus) — revised in place: AC1b.5 is now
  fixture-based, and AC1b.10 pins only the `untagged ≥ 200` floor
- CHK14: Do Step 1b and Step 2 agree on which note forms are canonical versus
  merely tolerated? — PASS (B1/B2 define tolerated; A.4.1's form clause defines
  canonical; A.4.2 runs the canonical example through the tolerant parser)
- CHK15: Is it stated whether AC2.1's three-literal agreement check survives
  Step 1b? — FAIL (missing in first draft) — revised in place: A.4.2's closing
  paragraph states the literals stay in the `case` patterns
- CHK16: Is the claim that B2 leaves the legacy parse untouched actually
  verified, not asserted? — PASS (measured: exactly one marker of 301 contains
  `NOTE[`, and AC1b.5 makes the invariance mechanically checkable)
- CHK17: Does the addendum avoid re-opening or re-scoping `gh295-1`? — PASS
  (Step 1 and its ACs are unedited; A.3 annotates AC1.8 without reasserting or
  revoking it, and every behaviour change lands in a new unit)
- CHK18: Is the unresolved item represented in Open Questions with a
  recommended default? — PASS (OQ-A1, default "include", with AC1b.9 gated on
  it and every other criterion independent of it)

### A.7 — Open Questions (amendment scope)

**OQ-A1 — Should `bin/marker-audit.sh` report a `malformed=<d>` count?**
*Recommended default: yes, include it.*

- **(a) Include it (recommended).** Counts emitted note lines that are
  `untagged` yet contain `NOTE[`. Cost: a few lines in one unmanaged script
  plus AC1b.9. Benefit: it is the only thing that makes an *unanticipated*
  wrapper variant visible — B1 fixes the five forms we measured, but nothing
  else detects a sixth.
- **(b) Omit it.** Smaller unit; consistent with ADR-0024's ceremony
  reduction. Accepts that a future unknown variant fails silently and forever
  (no backfill).

Not blocking: if you dispatch `gh295-1b` without answering, drop AC1b.9 and
the `bin/marker-audit.sh` line from the affected-files list. Every other
criterion stands unchanged, and (a) can be added later as a trivial follow-up
since it touches no managed file.

### A.8 — Dispatch contract: `gh295-1b`

**Unit:** `gh295-1b`

**Objective.** Make `hooks/scripts/marker-verify.sh --notes` classify a note's
tag correctly when the tag is wrapped in markdown emphasis (B1) or written on
an indented list line (B2), without changing the parse of any marker that
carries no `NOTE[` tag.

**Retrieval.** No tracker issue exists for this unit (fast path). The
authoritative spec is this document —
`docs/plans/2026-09-01-advisory-note-channel-gh295.md`, Addendum A, section
"Step 1b". Read A.1 for the measured defect table and A.2 for why ordering
matters.

**Affected files.** `hooks/scripts/marker-verify.sh`,
`tests/marker-verify.test.sh`, `bin/marker-audit.sh` (only if OQ-A1 is
answered (a)), plus whatever `node bin/cli.js --update --force-render`
regenerates — expected `.claude/hooks/scripts/marker-verify.sh` and
`.claude/persona-config.json`'s `fileHashes`. Those regenerated hunks are
**pre-authorized** per R1; do not treat them as out-of-scope drift.

**Ordered edits.**
1. Add the failing test cases first (AC1b.1 through AC1b.5), using
   `write_marker_body` / `expect_exact` as prior art — the existing AC1.3
   cases at `tests/marker-verify.test.sh:132-136` are the template.
2. Implement B1 in the tag-normalization step (`marker-verify.sh:85`).
3. Implement B2 in the continuation branch (`marker-verify.sh:78`).
4. Amend the file's header comment to describe both, per R4.
5. If OQ-A1 is (a): add the derived `malformed=` field to
   `bin/marker-audit.sh`'s aggregate line and its header comment, plus AC1b.9.
6. Run `node bin/cli.js --update --force-render` and commit everything it
   regenerates in this same unit.

**Do NOT touch.** Step 1's `--notes` output grammar for the per-unit summary
line (`marker-notes=<n> unit=<id> spec=<a> code=<b> untagged=<c>`) — B1/B2
change classification, never the line shape. Do not touch the three-tier anchor
search, the PASS-marker v3 first line, `agents/reviewer.md`,
`agents/spec-master.md`, `CONTEXT.md`, `templates/persona-protocol.md`, or any
version number — those belong to Steps 2 and 3. Never write to
`.claude/reviewed/`; all test markers go in the test harness's own tmp repo.

**Acceptance criteria.** AC1b.1 through AC1b.12 above, run in a pristine
detached worktree at this unit's own commit.

**Pre-resolved context.** `marker-verify.sh` is a managed entry
(`.claude/persona-config.json:250`) so it is a mirror + `fileHashes` change;
`bin/marker-audit.sh` is not managed and has no mirror. The classification
logic is `marker-verify.sh:85-90`; the continuation branch is `:78`. There is
no `.fail` record for any `gh295` unit — the whole `.claude/reviewed/`
directory was enumerated on 2026-09-01 and `gh295-1.pass` is the only `gh295`
record present. Exactly one live marker contains a `NOTE[` substring
(`gh295-1.pass`), which is why AC1b.10 must not pin `spec=0 code=0`.

**Escalation.** If B1's normalization cannot be made to satisfy both AC1b.1 and
AC1b.2 simultaneously — tolerance versus over-match — stop and report rather
than relaxing AC1b.2's guards; that tension is a spec question, not an
implementation one. Cap at 2 FAILs per the shared protocol.

## Scribe update hint

After Step 3: the `CONTEXT.md` entry is Step 3's own deliverable. Also worth a
line in the wiki on the reviewer→spec-master path, and an ADR is **not**
warranted here — this implements an existing issue's suggested fix within the
posture ADR-0024 already set, and creates no new architectural decision.
