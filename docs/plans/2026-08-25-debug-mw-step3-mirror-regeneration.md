# Debug spec — mw-step3 mirror regeneration (2-FAIL-cap escalation)

**Type:** debug spec (focused diagnostic + revised criteria), not a replan.
**Escalated unit:** `mw-step3` — "Step 3 — Reviewer authors and stamps the
escalation manifest", `docs/plans/2026-08-25-microworlds-workflow-redesign.md:469-509`.
**Scope guard:** the mirror-regeneration gap only. The five defects confirmed
fixed at `6b6a7a2` are not revisited, and no settled part of Step 3's design
(D6/D7/D8, AC3.1–AC3.9) is reopened.

## Goal

Land the managed-mirror regeneration that `6b6a7a2` omitted, so that (a) the
merge gate passes at the unit's own commit and (b) the AC3.2 selection rule
actually reaches the file a reviewer persona loads.

## Context

`6b6a7a2` edited two source artifacts subject to this repo's render step —
`agents/reviewer.md` and `templates/persona-protocol.md` — and did not
regenerate their managed mirrors. Four mirrors are consequently stale:
`.claude/agents/reviewer.md`, `.claude/agents/lead-programmer.md`,
`.claude/persona-protocol.md`, and `.claude/persona-config.json`'s
`fileHashes`.

CONTEXT.md:710-726 already records this exact hazard as a standing rule
("Source-artifact + render-step gating rule"). This is the **fourth** recorded
instance of the class in this repo: `gh385-2`, `gh403`, the 0.31.63 CHANGELOG
entry (the mirror-image — mirrors edited, sources not), and now `mw-step3`.

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

- 2026-08-25 Edge cases / failure handling: Q Does the live working tree
  reproduce the failure, so a fixer can verify in place? → A (self-resolved):
  No — measured. At `76c51a8` `node tests/cli-backfill.test.js` exits **0** in
  the live tree and **1** in a pristine worktree at the same commit, because
  `buildF2GitFixture` copies the real repo root verbatim and the live tree
  already carries an uncommitted regeneration. Every criterion below therefore
  mandates a pristine detached worktree at the fix commit.
- 2026-08-25 Technical constraints & tradeoffs: Q Is plain
  `node bin/cli.js --update` sufficient, as the CHANGELOG's 0.31.64 entry
  claims? → A (self-resolved): No, and the appearance that it works is an
  accident. Measured at `6b6a7a2` (pristine): plain `--update` prints
  "antislop v0.31.64 — already current … Nothing to update.", writes **zero**
  files, and `cli-backfill` still exits 1. At `76c51a8` plain `--update` *does*
  render — but only because a *different* open unit (`mw-step2`, commit
  `76c51a8`) left `session-start.sh`'s recorded hash stale, tripping the drift
  detector into a full render. Repairing `mw-step2` first would silently
  re-arm the fast path. The criteria therefore mandate `--force-render`, which
  CONTEXT.md:51 defines as the canonical force-the-loop control.
- 2026-08-25 Completion / acceptance signals: Q Which command is the
  completion signal, given Step 3 has no `validate.sh` criterion? → A
  (self-resolved): `bash tests/validate.sh` exit 0 in a pristine worktree at
  the fix commit — measured to pass after the render at `76c51a8`. See the
  "Do the existing criteria cover this?" section for why AC3.2/AC3.8/§5 do
  not supply this signal today.

Terminology note (`ubiquitous-language`, prose mode, against CONTEXT.md):
Lens 1 — no glossary term used with a divergent meaning. Lens 2 — the
escalation prose says "managed-mirror source file"; the canonical term is
**source artifact** (CONTEXT.md:713), used throughout this spec instead.
Lens 3 — no new load-bearing domain term; the hazard already has a
CONTEXT.md entry. Advisory only.

## Risks / dependencies

- **DR1 — The live tree masks the failure.** Highest-severity trap here.
  Verifying in the live working tree yields a false PASS. Pinned into every
  criterion below as an explicit pristine-worktree precondition.
- **DR2 — Cross-unit entanglement in the live tree.** The live working tree's
  uncommitted regeneration is *not* a clean `mw-step3` remediation: its
  `.claude/persona-config.json` diff also carries hash changes for
  `reviewer-route-gate.sh` and `stop-gate.sh`, plus six new `lib/*-core.sh`
  entries, all belonging to a concurrent gate unit whose sources are
  themselves uncommitted. A `git add` of the live mirrors would commit hashes
  for content not in the commit, producing a commit that is immediately
  drift-broken again. AC-R6 forbids it; the ordered edits require rendering
  from a clean checkout instead.
- **DR3 — One unavoidable out-of-scope hash line.** `bin/cli.js` rewrites the
  whole `fileHashes` map; it cannot render a subset. At `76c51a8` the render
  therefore also refreshes `.claude/hooks/scripts/session-start.sh`'s hash,
  which is `mw-step2`'s residue from `76c51a8`, not `mw-step3`'s. This is
  **pre-authorized** and must be named in the commit message so `mw-step2`'s
  reviewer is not confused by it. A reviewer must not FAIL `mw-step3` on it.
- **DR4 — No version bump.** The render lands under the existing 0.31.64.
  `--force-render` works at a matched version by design (measured, exit 0), so
  constitution §3 needs no second bump; AC3.9's bump already covered this
  unit's source edits.

## Constitution check (.claude/constitution.md v1.0.0)

- §1 "Verify, don't assume": satisfied — every claim here is a live
  measurement in a pristine worktree, including the two that *reversed* the
  escalation brief's premises (see Diagnosis).
- §2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  remedy is one deterministic script invocation, not hand-editing mirrors.
- §3 "Version-stamp discipline": satisfied — no new version; see DR4.
- §4 "Optional personas degrade gracefully": satisfied — not applicable; no
  persona-selection surface is touched.
- §5 "`tests/validate.sh` is the merge gate": **deviation, now corrected** —
  the parent plan's Constitution check binds §5 to AC1.6 and AC4.5 only, and
  Step 3 carries no `validate.sh` criterion at all. AC-R2 supplies it.

## Part 1 — Root-cause diagnosis

### `fail-triage` step 1: VERIFY

Reproduction confirmed, in a pristine detached worktree at `76c51a8` (current
`master`, three commits after `6b6a7a2` — the defect is still unfixed):

```
node tests/cli-backfill.test.js     # exit 1
```

```
FAIL F2 regression: shape B (mirror locally edited+committed) … the post-run
     tree comes back clean … got:  M .claude/agents/lead-programmer.md
FAIL --update --dry-run discriminates all three F2 drift shapes on exit code
     alone (C2.12): a genuinely current tree must exit 0, got 3
```

### `fail-triage` step 2: CATEGORIZE

**Spec/criterion defect**, not a code defect — with a code-shaped remedy.

The source edits at `6b6a7a2` are correct and are not being asked to change.
What is wrong is the *plan*: Step 3 directs edits to two source artifacts and
never names the render step, and its nine acceptance criteria contain nothing
that would detect the omission. This routes to the debug-spec revised-criteria
path.

### Diagnosis, and two corrections to the escalation brief

The escalation brief's account is **confirmed in substance**: `6b6a7a2` edited
source artifacts without regenerating mirrors; this fails the merge gate and
leaves the AC3.2 fix out of the operative rendered file. Both consequences are
reproduced above. Two details are **corrected**:

1. **Plain `--update` is not a safe remedy, and the brief's own
   `--force-render` instruction is load-bearing rather than incidental.** At
   `6b6a7a2` plain `--update` writes nothing at all (version-match fast path).
   It appears to work at `76c51a8` only because `mw-step2` left an unrelated
   hash stale. Any instruction that says "regenerate via `bin/cli.js --update`"
   is a trap at a version-matched state — including the one currently in
   CHANGELOG.md's own 0.31.64 entry (AC-R7).
2. **The remediation diffstat at HEAD is 4 files / 11 insertions / 7
   deletions**, not the brief's 10/6 — that figure was measured at `6b6a7a2`.
   The extra line is `session-start.sh`'s hash (DR3). Same four files either
   way.

Why the plan permitted this: the render step is invisible in Step 3's text.
`grep -n -i "force-render\|mirror\|regenerat\|\.claude/agents"` over
`docs/plans/2026-08-25-microworlds-workflow-redesign.md` returns **zero**
matches. `fd11a66` performed the render for the *first* attempt as an
undirected act of diligence by that implementer, not because any criterion
asked for it — so the fix-forward implementer at `6b6a7a2`, working from the
plan and the FAIL list, had nothing telling them to repeat it. The plan gap is
the root cause; the missing render is the symptom.

## Do the existing criteria cover this? (answer: no — new criteria needed)

Asked directly by the escalation. Verified, not inferred:

| Criterion | Covers the mirror gap? | Evidence |
|---|---|---|
| **AC3.2** | **No** | It is a `jq` assertion over a *packet* `manifest.json` — a runtime artifact, verified against fixture packets per R4. It never opens any persona instruction file, source or mirror. A fully stale `.claude/` tree satisfies it. |
| **AC3.8** | **No** | `tests/adapter-protocol-parity.test.js` contains **zero** occurrences of `.claude`. Its anchors are `templates/persona-protocol.md`, `templates/persona-protocol-slim.md`, `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`. It is a *source-to-adapter* parity test; the `.claude/` render is a different axis. |
| **AC3.9** | **No** | Covers the version bump and CHANGELOG entry only. |
| **Constitution §5** | **No** | The parent plan's Constitution check binds §5 to "AC1.6, AC4.5 and the zero-unregistered-test-files invariant". Step 3 has **no** `validate.sh` criterion among AC3.1–AC3.9, so the merge gate was never one of Step 3's acceptance signals. |

So the debug spec's job is **both**: add the missing process step to the
ordered edits *and* add machine-checkable criteria. Adding only the process
step would leave the omission undetectable a fourth time.

## Part 2 — Revised / supplementary acceptance criteria

Supplementary to AC3.1–AC3.9, which stand unchanged. All of AC-R1 through
AC-R4 run **in a pristine detached worktree at the fix commit**, never in the
live tree (DR1):

```
git worktree add --detach <tmp> <fix-sha> && cd <tmp>
```

- **AC-R1 (drift detection).** `node tests/cli-backfill.test.js` exits 0.
  *Non-vacuous:* exits 1 at both `6b6a7a2` and `76c51a8` (measured).
- **AC-R2 (merge gate, constitution §5).** `bash tests/validate.sh` exits 0
  and prints `All checks passed.`. *Non-vacuous:* exits 1 at `76c51a8`;
  measured to exit 0 once the render is applied. The `claude plugin tag
  --dry-run` frontmatter WARN on `agents/explorer.md` is pre-existing and
  explicitly advisory-only — not a failure of this criterion.
- **AC-R3 (the render was actually committed — strongest criterion).** In the
  same pristine worktree:
  ```
  node bin/cli.js --update --force-render && git status --porcelain
  ```
  produces **zero** lines of output. This asserts the committed tree is a
  render fixed point, which is exactly the property `6b6a7a2` lacked, and it
  cannot be satisfied by hand-editing one mirror. *Non-vacuous:* at `76c51a8`
  the same command emits exactly four ` M ` lines
  (`.claude/agents/lead-programmer.md`, `.claude/agents/reviewer.md`,
  `.claude/persona-config.json`, `.claude/persona-protocol.md`).
- **AC-R4 (the AC3.2 fix reaches the file agents load — claim-anchored).**
  Prose accuracy in the operative file is the deliverable here, so this is
  asserted on content, not just on existence. All three exit as stated:
  ```
  grep -c 'functionsAuthoredBy` is `"reviewer"`' .claude/agents/reviewer.md            # == 1
  grep -c '"functionsAuthoredBy": "reviewer" or "implementer-verified"' \
        .claude/agents/reviewer.md                                                      # == 0
  grep -c 'verifiedBy.functionsAuthoredBy` field records which case applied' \
        .claude/persona-protocol.md                                                     # == 1
  ```
  *Non-vacuous, proven by differential:* the same three commands return
  `1 / 0 / 1` in a rendered worktree and `0 / 1 / 0` at `6b6a7a2` (measured
  2026-08-25).
- **AC-R5 (standing rule for the remainder of this unit's scope).** The
  generalization the escalation asked for: **any** further edit in this unit's
  scope to a source artifact under `agents/` or `templates/` must be followed
  by `node bin/cli.js --update --force-render` and the resulting mirror
  changes committed *in the same commit as the source edit*. Mechanically this
  is already what AC-R3 enforces, evaluated at whatever the unit's final
  commit turns out to be — AC-R5 is the statement of intent that AC-R3 is the
  check for. Per CONTEXT.md:710-726 a source edit and its render can never be
  gated as separate commits under `tests/validate.sh`.
- **AC-R6 (scope containment).** `git show --stat <fix-sha> --name-only`
  names **exactly** these four paths, plus `CHANGELOG.md` if AC-R7 is taken,
  and nothing else:
  ```
  .claude/agents/lead-programmer.md
  .claude/agents/reviewer.md
  .claude/persona-config.json
  .claude/persona-protocol.md
  ```
  Specifically **no** `hooks/scripts/*`, `bin/cli.js`, `adapters/*`, or
  `tests/*` path may appear — those are a concurrent unit's uncommitted work
  in the live tree (DR2).
- **AC-R7 (CHANGELOG accuracy — small, recommended).** CHANGELOG.md's 0.31.64
  entry currently reads "regenerated via `node bin/cli.js --update` (G1/G2)".
  Change `--update` to `--update --force-render` in that line. Grounded, not
  cosmetic: plain `--update` demonstrably writes nothing at a version-matched
  state, so the line as written instructs a future maintainer to run a command
  that cannot do the job. Check:
  `grep -c 'regenerated via \`node bin/cli.js --update --force-render\`' CHANGELOG.md`
  returns ≥ 1, and the 0.31.64 section contains no bare
  ``regenerated via `node bin/cli.js --update` (G1/G2)``.

## Open Questions

None blocking. One judgment call recorded with its default, from the FAIL
record's closing NOTE:

1. *The FAIL record notes the CHANGELOG "will need a mirror-regeneration line
   too if the render is landed as a separate commit under the same version."*
   **Recommended default, taken here:** no new line is needed — the 0.31.64
   entry **already** carries `.claude/agents/*.md` / `.claude/persona-protocol*.md`
   / `.claude/protocol-digest.md` / `.claude/persona-config.json`'s `fileHashes`
   as regenerated. That claim was true at `fd11a66`, went false at `6b6a7a2`,
   and becomes true again the moment this unit lands. Only the *command named*
   in it is wrong, which AC-R7 corrects. Reverse this default only if the
   human wants the fix-forward called out as its own bullet.

## Self-check

- CHK1: Is the pristine-worktree precondition stated on every criterion whose
  result differs between the live and committed trees? — PASS (AC-R1–AC-R4
  each carry it; the shared `git worktree add` preamble sits above them).
- CHK2: Do AC-R3 and AC-R6 agree on the file set? — PASS (both name the same
  four paths; AC-R6 additionally admits `CHANGELOG.md` iff AC-R7 is taken, and
  AC-R3 is evaluated after that commit, where CHANGELOG.md is not a rendered
  file and so cannot appear in `git status --porcelain`).
- CHK3: Is every criterion machine-checkable, with a named command and a
  pass/fail signal? — PASS (AC-R1/R2 exit codes; AC-R3 empty output; AC-R4/R7
  `grep -c` equalities; AC-R6 a `--name-only` set equality). AC-R5 is prose
  intent explicitly delegated to AC-R3 for its check, and says so.
- CHK4: Has each criterion been proven non-vacuous by measurement, not
  assumed? — PASS (AC-R1, AC-R2, AC-R3 measured failing at `76c51a8` and
  passing post-render; AC-R4 proven by a 1/0/1-vs-0/1/0 differential).
- CHK5: Does the spec state whether AC3.2 / AC3.8 / §5 already cover the gap,
  as the escalation asked? — PASS ("Do the existing criteria cover this?",
  with per-row evidence rather than inference).
- CHK6: Is the unavoidable out-of-scope hash line (DR3) pre-authorized
  somewhere a reviewer will read before FAILing on it? — FAIL (missing on
  first draft) — revised in place: DR3 now states it explicitly, AC-R6's file
  list admits it implicitly (it lives inside `persona-config.json`), and the
  ordered edits require naming it in the commit message.
- CHK7: Does the spec avoid reopening the five confirmed-fixed defects or any
  settled Step 3 design decision? — PASS (AC3.1–AC3.9 are restated as
  unchanged; no D6/D7/D8 text is revised).
- CHK8: Is the escalation brief's own diagnosis verified rather than taken on
  faith, per the instruction? — PASS (confirmed in substance; two specific
  premises corrected in Diagnosis, both with measurements).

---

## Dispatch contract (≤5 units — fast path, no `task-master`)

One unit. Dispatch directly from this document.

**Unit: `mw-step3`**

Task-id is deliberately the *same* `mw-step3`, not a new id: this is the
closing fix for that unit, so its PASS marker must land at that unit's marker
path for the unit to be genuinely closed. Dispatch is authorized by the human
decision at the 2-FAIL cap that produced this debug spec, not on the
orchestrator's own authority.

### Objective

Regenerate the four managed mirrors that `6b6a7a2` left stale, and commit
them, so `mw-step3`'s tree is a render fixed point and the AC3.2 selection
rule reaches `.claude/agents/reviewer.md`. Optionally correct one CHANGELOG
line (AC-R7). **No source artifact is edited by this unit.**

### Retrieval

This spec is the dispatch source — no tracker issue exists for it. Read
`/home/sebas/AntiSlop/docs/plans/2026-08-25-debug-mw-step3-mirror-regeneration.md`
in full. Parent plan Step 3 (AC3.1–AC3.9, unchanged) is at
`/home/sebas/AntiSlop/docs/plans/2026-08-25-microworlds-workflow-redesign.md:469-509`.
The prior verdict record is at `.claude/reviewed/mw-step3.fail`.

### Affected files

Written by `bin/cli.js`, not by hand:
- `/home/sebas/AntiSlop/.claude/agents/reviewer.md`
- `/home/sebas/AntiSlop/.claude/agents/lead-programmer.md`
- `/home/sebas/AntiSlop/.claude/persona-protocol.md`
- `/home/sebas/AntiSlop/.claude/persona-config.json`

Hand-edited only if AC-R7 is taken:
- `/home/sebas/AntiSlop/CHANGELOG.md` (one line, 0.31.64 section)

### Ordered edits

1. **Do not work in the dirty live tree.** `git status --porcelain` currently
   shows a concurrent unit's uncommitted gate work plus an entangled
   regeneration (DR2). Create a clean detached worktree at current `master`
   and do all work there:
   `git worktree add --detach <tmp> <master-sha> && cd <tmp>`.
2. Run the render — this is the process step Step 3 was missing:
   `node bin/cli.js --update --force-render`.
   Use `--force-render` exactly. Plain `--update` writes nothing at a matched
   version (measured at `6b6a7a2`); it only appears to work right now by
   accident of `mw-step2`'s stale hash.
3. Confirm `git status --porcelain` shows exactly the four `.claude/` paths
   above and nothing else. If any other path appears, stop and escalate —
   something else drifted and it is not this unit's to fix.
4. Optional (AC-R7): edit CHANGELOG.md's 0.31.64 regeneration bullet,
   `--update` → `--update --force-render`.
5. Commit the four rendered files (plus CHANGELOG.md if step 4 was taken) in
   **one** commit. The message must (a) state that this completes `mw-step3`
   by landing the render `6b6a7a2` omitted, and (b) explicitly name the
   `.claude/hooks/scripts/session-start.sh` hash line inside
   `persona-config.json` as `mw-step2` residue swept in unavoidably, because
   `bin/cli.js` rewrites the whole `fileHashes` map (DR3).
6. Verify AC-R1 through AC-R4 in a **fresh** pristine worktree at the new
   commit — not the worktree you rendered in, whose cleanliness proves
   nothing about what you committed.

### Do NOT touch

- **Any file under `agents/`, `templates/`, or `adapters/`.** `6b6a7a2`'s
  source edits are confirmed correct; this unit only renders them.
- Any `hooks/scripts/*`, `bin/cli.js`, or `tests/*` path — concurrent unit.
- `.claude-plugin/plugin.json` / `package.json` — no version bump (DR4).
- Never hand-edit a mirror or a `fileHashes` entry. The only sanctioned writer
  of these four files is `bin/cli.js`.
- Do not `git add -A` or `git add .` anywhere near the live tree.

### Acceptance criteria

AC-R1, AC-R2, AC-R3, AC-R4, AC-R6 (all mandatory) and AC-R7 (if taken), as
specified above. AC3.1–AC3.9 continue to hold and were already verified at
`6b6a7a2`; re-running AC3.4/AC3.5/AC3.8 is cheap and recommended as a
regression check, but the render cannot plausibly break them.

**Every criterion runs in a pristine detached worktree at the fix commit.**
Running them in the live tree yields a false PASS — measured.

### Pre-resolved context

Do not re-derive these; they are measured, and verifying one costs a
worktree:

- Pristine at `76c51a8`: `node tests/cli-backfill.test.js` exits **1**;
  live dirty tree at the same commit exits **0**.
- Pristine at `6b6a7a2`: plain `node bin/cli.js --update` prints
  "antislop v0.31.64 — already current … Nothing to update." and writes zero
  files; `cli-backfill` still exits 1.
- Pristine at `76c51a8` + `--update --force-render`: rewrites exactly 4 files
  (11 insertions, 7 deletions); `cli-backfill` then exits 0 and
  `bash tests/validate.sh` exits 0 with `All checks passed.`.
- AC-R4's three greps return `1 / 0 / 1` rendered, `0 / 1 / 0` at `6b6a7a2`.
- `tests/adapter-protocol-parity.test.js` contains zero `.claude` references,
  which is why AC3.8 never caught this.
- `validate.sh:547` runs `tests/cli-backfill.test.js`, which is what makes
  `validate.sh` transitively a live-tree render-parity check.

### Escalation

This unit is already past the 2-FAIL cap. Do not attempt a third improvised
fix. Escalate to the human, rather than working around it, if:
- Step 3 of the ordered edits shows any path outside the four `.claude/` files;
- `--force-render` exits non-zero, or leaves `cli-backfill` failing;
- `bash tests/validate.sh` fails for any reason other than the pre-existing
  advisory `agents/explorer.md` frontmatter WARN;
- the concurrent gate unit lands between your render and your commit, changing
  the expected file set.

## Scribe update hint

Once this lands, CONTEXT.md's "Source-artifact + render-step gating rule"
(CONTEXT.md:710-726) should record `mw-step3` as its **fourth** instance, and
note the newly-measured refinement that the rule's failure mode is *masked in
the live working tree* — `buildF2GitFixture` copies the real repo root
verbatim, so an uncommitted regeneration makes the gate pass locally while it
fails at the commit. That masking is the reason the rule keeps recurring, and
it is not currently written down anywhere.
