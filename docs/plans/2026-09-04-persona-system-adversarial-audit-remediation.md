# Persona-system adversarial audit — remediation of 11 findings

Status: FINAL (ready for `task-master` slicing)
Date: 2026-09-04
Author: spec-master
Spec issue (PRD view): https://github.com/Storreslara/AntiSlop/issues/428
Slice label to create: `plan/2026-09-04-persona-system-adversarial-audit-remediation`

## Goal

Close all 11 triaged findings from the Fable-model adversarial audit of the
ten `.claude/agents/*.md` personas plus the shared inlined protocol block.
Each finding already has ONE human-selected remediation; this plan turns each
into a dispatchable step with machine-checkable acceptance criteria. No
finding is re-litigated and no new remediation is invented.

The 11 findings, by theme:

- **Deadlocks and dead affordances in the gate layer** (F1 advisory-dispatch
  deadlock, F6 WIP sentinel unreachable for the reviewer).
- **Contradictions between what a persona is told and what a hook does**
  (F2 marker-for-lack-of-id vs. advisory carve-out, F5 "no hook gate depends
  on it", F4 2-FAIL cap not durably countable).
- **Factually stale or false prose** (F3 model-tier ladder, F7 tool-isolation
  exclusivity claim, F11 line-number citations).
- **Missing affordances / missing per-unit evidence** (F8 auto-delegation
  precondition, F9 undocumented `marker-write.sh`, F10 no per-unit record of
  the resolved `humanReviewMode`).

## Context

Everything below was measured against the working tree at `4e90227`, not
inferred.

**The gate topology the findings live in.** `hooks/scripts/reviewer-route-gate.sh`
(Claude entry) sources `hooks/scripts/lib/reviewer-route-gate-core.sh`
(port-invariant). The entry script carries two Claude-only blocks — the
"lead-programmer may not spawn the reviewer" refusal and a **fail-closed
caller allowlist** — because only Claude's `PreToolUse` payload carries the
calling agent's identity. The core writes `.claude/.review-join.<id>` when a
reviewer dispatch's first non-blank line matches `Unit: <id>` and the unit
holds no format-valid `.pass`. `hooks/scripts/lib/stop-gate-core.sh` then
blocks the reviewer's `SubagentStop` unless a format-valid `.pass` or `.fail`
exists for each stamped unit.

**Three ports, five artifacts.** `bin/cli.js`'s `buildAdapterLibSpecs()`
generates `adapters/{codex,cursor}/hooks/scripts/lib/*.sh` from
`hooks/scripts/lib/*.sh`; all three copies of `reviewer-route-gate-core.sh`,
`stop-gate-core.sh` and `state-access.sh` are byte-identical today (verified).
`tests/validate.sh:302` asserts `.claude/hooks/scripts` is byte-identical to
`hooks/scripts`, and `tests/cli-backfill.test.js` (F2/C2.12) makes
`validate.sh` transitively a mirror-parity check. So a step touching a hook
lib or a persona/template source is a **five-artifact change**: the source,
the `.claude/**` mirror, the two adapter copies, and
`.claude/persona-config.json`'s `fileHashes` map.

**The adapter PROTOCOL ports are hand-maintained**, unlike the hook libs:
`adapters/codex/agents-md-fragment.md` and
`adapters/cursor/rules/persona-protocol.mdc` are not rendered by `bin/cli.js`.
Both carry the "FAIL record" section and the marker-format description
verbatim; neither carries the "Structural questions go to the explorer"
Skill-isolation sentence (verified by `git grep -l`).

**The protocol block is trimmed per persona.** `templates/persona-protocol.md`
is inlined by `bin/cli.js` into `.claude/agents/*.md` as a per-persona subset,
never wholesale, and never into the `agents/*.md` sources. Measured surfaces:
the F5 sentence exists in 9 files (3 hand-edited sources + 6 generated); the
F7 sentence exists in 3 (1 hand-edited source, 1 generated set, 1 frozen
prototype copy).

**Existing test seams, all currently green and all wired into
`tests/validate.sh`** (verified by running each): `tests/review-join.test.sh`
(route-gate stamping, incl. adapter ports), `tests/adapter-stop-gate-parity.test.sh`
(the reviewer `marker=MISSING` block across all three ports),
`tests/marker-write.test.sh`, `tests/marker-verify.test.sh`,
`tests/writer-tier-consistency.test.js` (pins the sonnet ladder literals),
`tests/protocol-cross-references.test.js`, `tests/dispatch-hygiene.test.sh`.
Every step below extends an existing seam; **no new test file is created**.

**Prior FAIL history in this area.** `.claude/reviewed/` was enumerated in
full (not sampled): 60+ `.fail` records exist, including `gh425-3.fail` and
`gh425-4.fail` on the immediately adjacent marker-scoping work, `gh403.fail`
and `spec2-unitE.fail` on the mirror/fileHashes class this plan is squarely
inside, and `mw-step3.fail` on the same. Three of those four are the same
failure class: **a source edited without regenerating its mirrors in the same
unit**. That history is why the cross-cutting constraints below are stated as
hard requirements rather than reminders, and it is why no step in this plan
may be tagged as low-judgment mechanical work.

**Advisory-note sweep.** `bash bin/marker-audit.sh . --notes --surface=<path>`
was not run per-surface for this plan; the enumeration above was performed
directly against `.claude/reviewed/`. `.claude/reviewed/` is gitignored,
untracked per-clone state with no recovery source, so its contents are
evidence of what happened in *this* clone and never proof of what did not.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-04 Domain entities / data model: Q F4's chosen fix offers two
  on-disk shapes ("rotate existing `.fail` to `.fail.1`" or "append a new
  header block to a single growing file") — which? → A (self-resolved):
  **append to a single growing file**. Measured rationale: appending keeps
  every existing consumer working unchanged, because (a)
  `stop-gate-core.sh`'s `marker_format_valid()` and `task-gate.sh`'s
  `marker_valid()` check only that line 1 begins `FAIL <unit-id> `, and with
  append the oldest record stays on line 1 and stays valid; (b)
  `stop-gate-core.sh`'s review-join satisfaction compares the marker's mtime
  against the stamp's `prior_mtime`, and an append refreshes mtime, so a
  second FAIL still satisfies its stamp; (c) `scripts/spend-accounting.sh`
  and `bin/human-review-cleanup.sh` glob `*.fail` and use existence/mtime
  only. Rotation to `.fail.1` would instead require editing every
  glob-based consumer, and would create a marker filename that
  `human-review-cleanup.sh`'s sweep does not match.
- 2026-09-04 Domain entities / data model: Q What is the exact grammar of the
  advisory token, and where must it appear? → A (self-resolved): the
  **second** non-blank line of the dispatch prompt, immediately after
  `Unit: <id>`, matching `^Mode:[[:space:]]+advisory[[:space:]]*$`. The core
  already scans for the first non-blank line, so extending the same scan to
  the second is the minimal unambiguous change; anchoring it positionally
  prevents a quoted `Mode: advisory` example in a prompt body from
  suppressing a real stamp (the same defect shape `dispatch-hygiene.sh`'s H3
  guards against by reading the first non-blank line only).
- 2026-09-04 User interaction flow: Q On a sentinel-honored reviewer
  turn-end (F6), what happens to the review-join stamp and the
  pending-review flags? → A (self-resolved): **neither is touched**. The
  stamp is not consumed and the flags are not cleared, so the verdict stays
  owed and the next turn is still blocked until it is written. The sentinel
  itself IS consumed (deleted after logging), matching the one-shot
  semantics of the existing lead-programmer sentinel branch. Honoring the
  sentinel unblocks exactly one turn-end and nothing else.
- 2026-09-04 User interaction flow: Q What does F2's "carried at least one
  runnable acceptance-criteria command" mean operationally, and how does it
  relate to F1's `Mode: advisory`? → A (self-resolved): they are the same
  concept from two directions, and the plan unifies them under one glossary
  term, **advisory dispatch**. `Mode: advisory` is the machine-readable
  declaration the route-gate reads; "no runnable acceptance-criteria command
  in the dispatch" is the condition the reviewer evaluates for itself when
  the token is absent. Both resolve to: no marker, no verdict vocabulary,
  text report only.
- 2026-09-04 External dependencies & integrations: Q Which surfaces must each
  protocol-text fix reach? → A (self-resolved): enumerated per step by
  `git grep -l` rather than assumed. Each sentence exists in **9 files**, but
  the hand-edited subsets differ: F5 has 3 hand-edited sources
  (`templates/persona-protocol.md` plus both adapter protocol ports) and 6
  generated copies; F7 has 1 hand-edited source
  (`templates/persona-protocol.md`), 7 generated copies, and 1 frozen
  prototype copy — the adapter ports do not carry the F7 sentence at all, and
  `prototype/protocol-mcp/` is excluded. All generated copies follow from
  `node bin/cli.js --update --force-render`.
- 2026-09-04 Edge cases / failure handling: Q Can a verdict-owning dispatch be
  mislabeled `Mode: advisory` to dodge the coupling? → A (self-resolved):
  **the requested caller restriction already exists upstream** and needs no
  new code. `hooks/scripts/reviewer-route-gate.sh`'s caller allowlist fails
  CLOSED for reviewer-targeted dispatches: only the orchestrator or the bare
  main session can dispatch the reviewer at all, so every dispatch that
  reaches the stamping code is already provably from the verdict-owning
  caller. The residual risk is the orchestrator mislabeling its own
  dispatch, which no gate can detect; that is why the step requires an
  `advisory-dispatch=<id>` audit-log line, making every use reviewable after
  the fact. On codex/cursor the caller allowlist is already instruction-only
  (their payloads carry no caller identity), so advisory inherits exactly the
  posture those ports already document for reviewer dispatch generally.
- 2026-09-04 Technical constraints & tradeoffs: Q F3 says "strip the concrete
  tier names from orchestrator.md's prose" — literally all of them? → A
  (self-resolved): **no, and doing so would break a currently-passing test.**
  `tests/writer-tier-consistency.test.js` (AC-D7) requires the literal
  `Sonnet units escalate on first FAIL` to be present in
  `agents/orchestrator.md`, and the `Suggested model:` tag vocabulary is real
  grammar `task-master` emits. F3 is therefore scoped to the four *false*
  claims only, with the default pointed at CONTEXT.md's `**Writer tier**`
  entry. See Open Question 1.
- 2026-09-04 Technical constraints & tradeoffs: Q F10 places a new
  `human-review-mode:` line in the marker's notes area — does anything parse
  that area? → A (self-resolved): **yes, and it would be misparsed.**
  `hooks/scripts/marker-verify.sh`'s `run_notes_mode()` computes
  `start_line=$(( anchor_line > 0 ? anchor_line + 1 : 2 ))`, so on a marker
  with no `Non-blocking notes:` anchor, note extraction begins at **line 2** —
  exactly where the new line sits — and `extract_notes()` classifies any
  untagged line there as `marker-note=untagged`. That would emit one spurious
  untagged note per PASS marker into `bin/marker-audit.sh --notes`, the sweep
  spec-master itself consumes. Step 4 therefore includes a parser guard in
  the same unit. Established by reading the code; not reproduced with a live
  fixture, because building one requires a Bash command spelling
  `.claude/reviewed/` in a write position, which `reviewed-path-gate.sh`
  correctly refuses (routing around that refusal would be a self-authorized
  bypass). The step's acceptance criterion delegates the reproduction to
  `tests/marker-verify.test.sh`, whose existing `seed_marker` helper already
  writes such fixtures legally from inside a test file.
- 2026-09-04 Terminology consistency: Q Does this plan introduce
  load-bearing terms the glossary does not define? → A (self-resolved): yes,
  one — **advisory dispatch** — which the request itself flags as in scope to
  define. `ubiquitous-language` prose mode over this plan against
  `CONTEXT.md` reports: lens 1 (glossary term used with a different meaning)
  — nothing found; the plan uses **review-join stamp**, **PASS marker**,
  **Writer tier**, **Implementer-tier ratchet** and **scoped unit set** with
  their canonical meanings. Lens 2 (new synonym for a defined term) — one
  finding: the plan uses "unit id", "task-id" and "unit-slug" for the same
  identifier, inherited from the persona corpus itself; the human explicitly
  scoped that reconciliation out, so this plan uses `<task-id>` in marker
  paths and `<unit-id>` in stamp/dispatch contexts exactly as the existing
  files do, and introduces no third spelling. Lens 3 (load-bearing new term
  with no entry) — one finding: **advisory dispatch**, defined in Step 1.

## Risks / dependencies

- **R1 — Serialization is mandatory.** `bin/cli.js` rewrites the *whole*
  `fileHashes` map and cannot render a subset, so two units regenerating
  concurrently will collide and a unit's commit may legitimately carry hash
  lines belonging to another open unit. Every unit in this plan must be
  dispatched, reviewed and committed **strictly sequentially**, and a
  reviewer must not FAIL a unit solely for hash lines the regen produced.
- **R2 — `--update` alone silently does nothing.** Its fast path returns
  early when `pluginVersion` matches and stamps match, printing "already
  current". Every regeneration in this plan must use
  `node bin/cli.js --update --force-render`. If an implementer reports
  "already current", the regen did not happen — that is an escalation, never
  something to work around. This is the class behind `mw-step3.fail`,
  `gh403.fail` and `spec2-unitE.fail`.
- **R3 — The live tree gives a FALSE PASS on `validate.sh`.**
  `tests/cli-backfill.test.js`'s `buildF2GitFixture` copies the real repo
  root *including uncommitted files*, so an in-flight regeneration makes
  `validate.sh` exit 0 locally while the same commit exits 1 in a pristine
  checkout. Every `validate.sh` criterion in this plan must be verified in a
  clean detached worktree at the unit's own commit
  (`git worktree add --detach <tmp> <sha>`), never in place.
- **R4 — `reviewed-path-gate.sh` blocks marker fixtures written inline.** A
  Bash command whose *text* spells `.claude/reviewed/` in a write position is
  refused for every non-reviewer identity. Marker fixtures therefore belong
  in test **files** (`Write`/`Edit` checks `file_path` only, and the test
  file's own path is not under `.claude/reviewed/`), never in an inline
  heredoc. Steps 4 and 5 depend on this.
- **R5 — Steps 2, 3 and 4 edit overlapping anchors** (the "On PASS" and "On
  FAIL" bullets of `agents/reviewer.md`). They must be sliced as one unit, or
  dispatched in strict 2 → 3 → 4 order with each re-reading the file. Step 5
  also edits the "On FAIL" bullet and must follow them.
- **R6 — F1's H3 interaction is knowingly left open.** An advisory dispatch
  naming a unit that already holds a `.pass` still trips
  `dispatch-hygiene.sh`'s H3 re-dispatch check. This repo runs
  `dispatchHygiene.mode: "warn"`, so it warns; the shipped default is
  `block`, where it would refuse. Step 1 documents the advisory case in
  `dispatch-hygiene.sh`'s header but deliberately does not change H3's
  behavior. See Open Question 2.
- **R7 — The adapter protocol ports are already stale on marker format**
  (they describe the v2 first line, with no `commit:` field). Steps 4 and 7
  edit those files for their own named clauses only and must not attempt to
  reconcile the v2/v3 divergence, which is pre-existing and out of scope.
- **R8 — No test asserts adapter protocol-port prose parity for these
  clauses.** `tests/adapter-protocol-parity.test.js` checks section
  *presence* via a hand-maintained probe list, not clause content, so a
  clause added to `templates/persona-protocol.md` and forgotten in the two
  adapter ports drifts silently. Steps 4 and 7 must therefore assert each
  port by explicit grep, not by running that suite.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every premise in this plan was
  measured against the tree, every acceptance criterion below was executed at
  authoring time, and each is recorded with its measured baseline. Two
  premises the audit supplied were corrected by measurement (see Open
  Questions 1 and 3).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 3
  replaces a hand-typed two-step `printf` with the existing
  `marker-write.sh`; Step 4's resolution rule is a fixed `jq` expression, not
  a judgment call.
- P3 "Version-stamp discipline": deviation — no step bumps
  `.claude-plugin/plugin.json` / `package.json`. Regeneration uses
  `--force-render`, which does not require a version bump, and a per-unit
  bump across ten sequential units would produce ten meaningless versions.
  A single release-hygiene bump after the batch is the correct unit and is
  explicitly out of scope here.
- P4 "Optional personas degrade gracefully": satisfied — Steps 1, 4 and 6
  change reviewer-specific behavior; in a project that selected no `reviewer`
  persona, no reviewer is dispatched, no stamp is written and no marker
  exists, so every added path is inert rather than broken.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step carries
  `bash tests/validate.sh` exit 0 as a criterion, verified per R3 in a
  pristine worktree.

---

## Step 1 — F1: advisory-dispatch token in the route gate

**Affected files**

- `hooks/scripts/lib/reviewer-route-gate-core.sh` — the first-non-blank-line
  block (the `if [[ $first_line =~ ^Unit:... ]]` region).
- `agents/orchestrator.md` — `## Review routing — you are the single owner`,
  the sentence beginning "One deliberate exception, not an omission to fix".
- `hooks/scripts/dispatch-hygiene.sh` — the header comment block only.
- `CONTEXT.md` — `## Language`, new `**advisory dispatch**` entry.
- `tests/review-join.test.sh` — new fixture cases.
- Regenerated (do not hand-edit): `.claude/hooks/scripts/**`,
  `adapters/{codex,cursor}/hooks/scripts/lib/reviewer-route-gate-core.sh`,
  `.claude/agents/orchestrator.md`, `.claude/persona-config.json`.

**Intent.** In the core, after `first_line` is extracted and the `Unit: <id>`
match succeeds, also extract the **second** non-blank line. If it matches
`^Mode:[[:space:]]+advisory[[:space:]]*$`, write **no** stamp, emit
`audit_append "$review_audit" "advisory-dispatch=$unit_id"`, and fall through
to `exit 0`. All existing traversal guards on `unit_id` apply before the
audit line is written. No caller check is added — the entry script's
fail-closed allowlist already restricts every reviewer dispatch to the
orchestrator (see Clarifications). Document the second no-stamp case in
`orchestrator.md` alongside the existing already-PASSed exception, and in
`dispatch-hygiene.sh`'s header. Define **advisory dispatch** in `CONTEXT.md`
as a reviewer dispatch that carries no acceptance-criteria command and owns
no verdict, declared by `Mode: advisory`, ending with a text report and no
marker.

**Acceptance criteria**

```sh
# 1. New route-gate cases pass (case names are mandatory literals).
bash tests/review-join.test.sh                      # exit 0
grep -c 'route-gate-advisory-mode-no-stamp' tests/review-join.test.sh        # >= 1
grep -c 'route-gate-advisory-mode-wrong-position' tests/review-join.test.sh  # >= 1
# 2. The core recognizes the token and logs it. (The match expression's exact
#    spelling is the implementer's choice; only the token and the audit key
#    are pinned, so a legitimate regex variant cannot fail the unit.)
grep -c 'advisory-dispatch=' hooks/scripts/lib/reviewer-route-gate-core.sh   # 1
grep -c 'advisory' hooks/scripts/lib/reviewer-route-gate-core.sh            # >= 2
# 3. All three ports carry the identical core (generated, not hand-edited).
diff -q hooks/scripts/lib/reviewer-route-gate-core.sh \
        adapters/codex/hooks/scripts/lib/reviewer-route-gate-core.sh   # exit 0
diff -q hooks/scripts/lib/reviewer-route-gate-core.sh \
        adapters/cursor/hooks/scripts/lib/reviewer-route-gate-core.sh  # exit 0
# 4. Prose surfaces name the new case.
grep -c 'Mode: advisory' agents/orchestrator.md          # >= 1
grep -c 'Mode: advisory' hooks/scripts/dispatch-hygiene.sh  # >= 1
grep -c 'advisory dispatch' CONTEXT.md                   # >= 1
# 5. Merge gate, verified in a pristine worktree at this unit's commit.
bash tests/validate.sh                                   # exit 0
```

The two mandatory fixture cases: `route-gate-advisory-mode-no-stamp` —
prompt `Unit: adv-1` then `Mode: advisory`, reviewer target, no prior marker
→ stamp count 0, exit 0, and `advisory-dispatch=adv-1` present in
`.claude/review-audit.log`. `route-gate-advisory-mode-wrong-position` —
`Mode: advisory` on the third non-blank line instead of the second → stamp
count 1, exit 0 (the token must be positionally anchored).

**Measured baseline (RED).** `grep -c 'advisory-dispatch=' hooks/scripts/lib/reviewer-route-gate-core.sh`
= 0; `grep -c 'Mode: advisory' agents/orchestrator.md` = 0;
`grep -c 'advisory dispatch' CONTEXT.md` = 0;
`bash tests/review-join.test.sh` = exit 0 today (so criterion 1 is a
regression guard on the existing cases and a change-proof only via the two
new case-name greps — labelled accordingly).

---

## Step 2 — F2: condition the marker duty on acceptance criteria

**Affected files**

- `agents/reviewer.md` — the "On PASS (marker format v3)" bullet, the
  sentence "never skip the marker for lack of an id".
- Regenerated: `.claude/agents/reviewer.md`, `.claude/persona-config.json`.

**Intent.** Make the never-skip-for-lack-of-id rule conditional. If the
dispatch carried at least one runnable acceptance-criteria command, the rule
stands unchanged: derive a `<task-id>` from the unit's slug, say so in the
verdict line, and write the marker. If the dispatch carried **no** acceptance
criteria at all — an advisory dispatch, per Step 1's glossary entry — the
reviewer ends with a text report only: no marker of any kind, no PASS/FAIL/
INSUFFICIENT-CONTEXT/ESCALATE-TO-HUMAN vocabulary. State the condition
explicitly and reference `Mode: advisory` as its machine-readable form.

**Acceptance criteria**

```sh
# 1. The conditional is stated, and the unconditional rule is gone.
grep -c 'never skip the marker for lack of an id' agents/reviewer.md   # 1 (survival pin)
grep -c 'no acceptance-criteria command' agents/reviewer.md            # >= 1
grep -c 'Mode: advisory' agents/reviewer.md                            # >= 1
# 2. The source and its inlined mirror agree.
grep -c 'no acceptance-criteria command' .claude/agents/reviewer.md    # >= 1
# 3. Merge gate.
bash tests/validate.sh                                                 # exit 0
```

Note on criterion 1: the first grep is a **survival pin**, not a deletion
check. The rule itself must survive — only its scope becomes conditional. A
criterion demanding that string reach 0 would delete the rule it protects.

**Measured baseline.** `grep -c 'never skip the marker for lack of an id' agents/reviewer.md`
= 1 (already green — a survival guard).
`grep -c 'no acceptance-criteria command' agents/reviewer.md` = 0 (RED).
`grep -c 'Mode: advisory' agents/reviewer.md` = 0 (RED).

---

## Step 3 — F9: document `marker-write.sh` as the preferred marker writer

**Affected files**

- `agents/reviewer.md` — the "On PASS", "On FAIL", "On INSUFFICIENT-CONTEXT"
  and "On ESCALATE-TO-HUMAN" bullets.
- Regenerated: `.claude/agents/reviewer.md`, `.claude/persona-config.json`.

**Intent.** Teach `hooks/scripts/marker-write.sh` as the preferred way to
write a verdict marker, with the raw `mkdir -p` + `printf` two-step demoted to
a documented fallback for when the helper is unavailable. The helper's real
signature, read from the file (do not re-derive):

```
marker-write.sh <PASS|FAIL|BLOCKED> <unit-id> <commit> <detail> <marker-path>
```

`<commit>` is required for PASS (a sha, or `none`); pass `-` for FAIL and
BLOCKED. `<marker-path>` is a required argument that must equal
`.claude/reviewed/<unit-id>.<pass|fail|blocked>` — deliberately so, because
the invoking command's own text must spell the path for
`reviewed-path-gate.sh`'s reviewer-only grant to fire.

**Two constraints the step must honor, both measured:**

1. **The helper has no `ESCALATE` verdict.** It accepts only PASS, FAIL and
   BLOCKED, and its `usage_die` rejects anything else. The
   "On ESCALATE-TO-HUMAN" bullet must therefore keep its raw `printf`
   instructions and say plainly that the helper does not cover this verdict —
   not imply the helper works everywhere.
2. **The helper writes only the marker's required first line** (plus a FAIL
   defect list). Non-blocking notes, the `Non-blocking notes:` anchor, and
   Step 4's `human-review-mode:` line are still appended separately.

**Acceptance criteria**

```sh
# 1. The helper is documented in the reviewer's marker instructions.
grep -c 'marker-write.sh' agents/reviewer.md          # >= 3 (PASS, FAIL, BLOCKED)
grep -c 'marker-write.sh' .claude/agents/reviewer.md  # >= 3
# 2. The raw form survives as a documented fallback, not as the only route.
#    NOTE: pin `mkdir -p` ALONE. A criterion quoting the marker directory
#    path is refused outright by reviewed-path-gate.sh for every non-reviewer
#    identity (the path appears in a quoted word), so an implementer
#    verifying its own work physically could not run it. Measured, not
#    assumed — the gate refused this exact grep during authoring.
grep -c 'mkdir -p' agents/reviewer.md                   # >= 1 (survival pin)
# 3. The ESCALATE limitation is stated, not glossed.
grep -ci 'does not cover' agents/reviewer.md            # >= 1
# 4. The documented signature matches the real one.
grep -c 'PASS|FAIL|BLOCKED' hooks/scripts/marker-write.sh  # >= 1 (unchanged)
bash tests/marker-write.test.sh                            # exit 0
# 5. Merge gate.
bash tests/validate.sh                                     # exit 0
```

**Measured baseline (RED).** `grep -rc 'marker-write.sh' agents/` = 0 across
every file in `agents/`. `bash tests/marker-write.test.sh` = exit 0 today
(criterion 4's second half is an unrelated-regression guard: the step changes
no helper behavior, and this proves it).

---

## Step 4 — F10: record the resolved `humanReviewMode` on every PASS marker

**Affected files**

- `agents/reviewer.md` — the "On PASS (marker format v3)" bullet.
- `templates/persona-protocol.md` — the marker-format description in the
  `## Review ownership — one unit, one review, single owner` section.
- `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc` — the same description
  (hand-edited; these are not generated).
- `hooks/scripts/marker-verify.sh` — `run_notes_mode()` / `extract_notes()`.
- `tests/marker-verify.test.sh` — new case.
- Regenerated: `.claude/agents/*.md`, `.claude/persona-protocol.md`,
  `.claude/hooks/scripts/**`, `.claude/persona-config.json`.

**Intent.** Require every `.pass` marker to carry, on the line **immediately
after** the required first line and **before** any `Non-blocking notes:`
anchor, a line reading exactly `human-review-mode: <resolved>`. The resolved
value is what `agents/reviewer.md` already specifies for the escalation
decision: read `.humanReviewMode` from `.claude/persona-config.json`; an
absent key resolves to `critical`, and so does any unrecognized value; only
`off`, spelled exactly, is `off`. So `<resolved>` is always one of `off`,
`critical`, `all`.

**And, in the same unit, guard the parser.** `marker-verify.sh`'s
`run_notes_mode()` starts note extraction at line 2 when no
`Non-blocking notes:` anchor is present, so the new line would be emitted as
`marker-note=untagged` and counted in `untagged=` — polluting
`bin/marker-audit.sh --notes`, the sweep spec-master consumes. Skip a line
matching `^human-review-mode:` during note classification. This is one
condition; it must not otherwise change note parsing.

**Acceptance criteria**

```sh
# 1. The requirement is stated on all four prose surfaces (R8: assert each).
grep -c 'human-review-mode:' agents/reviewer.md                        # >= 1
grep -c 'human-review-mode:' templates/persona-protocol.md             # >= 1
grep -c 'human-review-mode:' adapters/codex/agents-md-fragment.md      # >= 1
grep -c 'human-review-mode:' adapters/cursor/rules/persona-protocol.mdc # >= 1
grep -c 'human-review-mode:' .claude/persona-protocol.md               # >= 1
# 2. The parser guard exists and is proven by a test case.
grep -c 'human-review-mode' hooks/scripts/marker-verify.sh             # >= 1
grep -c 'human-review-mode' tests/marker-verify.test.sh                # >= 1
bash tests/marker-verify.test.sh                                       # exit 0
# 3. Merge gate.
bash tests/validate.sh                                                 # exit 0
```

The mandatory test case: seed a `.pass` marker whose line 2 is
`human-review-mode: off` and which has **no** `Non-blocking notes:` anchor;
assert `marker-verify.sh <id> <dir> --notes` reports `untagged=0` and emits
no `marker-note=` line for it. Seed it with the file's existing
`seed_marker`-style helper — never an inline Bash heredoc (R4). This case
fails on the unpatched parser, which is what makes it a change-proof rather
than a guard.

**Measured baseline (RED).** `grep -rc 'human-review-mode:' agents/ templates/`
= 0 in every file. `hooks/scripts/marker-verify.sh:135` currently reads
`start_line=$(( anchor_line > 0 ? anchor_line + 1 : 2 ))`, and
`extract_notes()` tags any untagged line at/after `start_line` as
`untagged` — the defect this step closes.

---

## Step 5 — F4: make the FAIL record append, so the 2-FAIL cap is countable

**Affected files**

- `hooks/scripts/lib/state-access.sh` — add a FAIL-specific append operation
  alongside `state_write_unit_marker` (do not change that function's
  overwrite semantics; `.pass`, `.blocked`, `.escalated` and `.directed` all
  depend on it).
- `hooks/scripts/marker-write.sh` — the `FAIL)` branch.
- `agents/reviewer.md` — the "On FAIL (both modes)" bullet.
- `templates/persona-protocol.md` — the `## FAIL record` section.
- `adapters/codex/agents-md-fragment.md`,
  `adapters/cursor/rules/persona-protocol.mdc` — their `FAIL record` sections
  (hand-edited).
- `agents/orchestrator.md` — the `**At the 2-FAIL cap**` paragraph.
- `agents/spec-master.md` — the "Debug spec on 2-FAIL-cap escalation" bullet
  and the `.fail`-record-check bullet, both of which currently assert "there
  is only ever a single, most-recent `.fail` record … no append/rotation
  mechanism exists".
- `skills/fail-triage/SKILL.md` — step 1, which repeats the same claim.
- `tests/marker-write.test.sh` — new case.
- Regenerated: `.claude/**`, `adapters/{codex,cursor}/hooks/scripts/lib/state-access.sh`,
  `.claude/persona-config.json`.

**Intent.** A FAIL appends rather than overwrites. Each record is a header
line `FAIL <task-id> <UTC ISO-8601 timestamp>` followed by that attempt's
defect list verbatim; records after the first are preceded by a blank line.
The 2-FAIL cap is then counted, not assumed:

```sh
grep -cE "^FAIL <task-id> [0-9]{4}-" .claude/reviewed/<task-id>.fail
```

Two invariants the implementation must preserve, both measured:

1. **Line 1 stays a valid header.** Appending leaves the oldest record on
   line 1, so `stop-gate-core.sh`'s `marker_format_valid()` and
   `task-gate.sh`'s `marker_valid()` — which check only that line 1 begins
   `FAIL <unit-id> ` — keep passing. No change is needed in either.
2. **A defect line must never begin with `FAIL <task-id> `**, or it would be
   counted as a record. The reviewer's instructions must say so, and the
   counting command above is anchored on a following `[0-9]{4}-` date to make
   an accidental collision harder.

**Consumers confirmed unaffected** (state this in the unit, do not re-derive):
`scripts/spend-accounting.sh` globs `*.fail` and counts unique task-ids with
≥1 record — its own comment already contemplates a unit failing twice;
`bin/human-review-cleanup.sh` globs `*.fail` and prunes by mtime;
`hooks/scripts/reviewer-tier.sh` tests existence only;
`hooks/scripts/lib/reviewer-route-gate-core.sh` uses existence and mtime;
`hooks/scripts/dispatch-hygiene.sh` reads `.pass`, never `.fail`.

**Prose corrections in the same unit.** `orchestrator.md`'s "both `.fail`
records" becomes a count-the-headers instruction naming the command above.
`spec-master.md`'s and `fail-triage/SKILL.md`'s "a second FAIL overwrites the
first / no append-or-rotation mechanism exists" claims become their opposite —
these are now false and must not survive the step.

**Acceptance criteria**

```sh
# 1. Append semantics exist in the lib and the helper; .pass overwrite intact.
grep -c 'state_append_unit_marker' hooks/scripts/lib/state-access.sh  # >= 2 (def + export)
grep -c 'state_write_unit_marker' hooks/scripts/lib/state-access.sh   # 2 (guard: unchanged)
bash tests/state-access-constraints.test.sh                           # exit 0
bash tests/marker-write.test.sh                                       # exit 0
grep -c 'two consecutive FAIL' tests/marker-write.test.sh             # >= 1
# 2. The stale single-record claims are gone (these ARE the defect text).
#    NOTE: pin the short, single-line fragment. The longer phrase
#    "no append/rotation mechanism" WRAPS in both files, so a line-oriented
#    grep for it returns 0 today and would be vacuous. Measured, not assumed.
grep -c 'second FAIL overwrites the first' agents/spec-master.md      # 0
grep -c 'second FAIL overwrites the first' skills/fail-triage/SKILL.md # 0
grep -c 'both `.fail` records' agents/orchestrator.md                 # 0
# 3. The countable cap is documented where the cap is enforced.
grep -c 'grep -cE' agents/orchestrator.md                              # >= 1
# 4. All four protocol surfaces describe append (R8).
grep -ci 'append' templates/persona-protocol.md                        # >= 1
grep -ci 'append' adapters/codex/agents-md-fragment.md                 # >= 1
grep -ci 'append' adapters/cursor/rules/persona-protocol.mdc           # >= 1
# 5. Existing gate behavior is unchanged by the format change.
bash tests/adapter-stop-gate-parity.test.sh                            # exit 0
bash tests/review-join.test.sh                                         # exit 0
# 6. Merge gate.
bash tests/validate.sh                                                 # exit 0
```

The mandatory `marker-write.test.sh` case (name containing
`two consecutive FAIL`): two successive FAIL invocations for one unit-id
leave a file with exactly two header lines, both defect lists present
verbatim, and line 1 still satisfying the extracted `marker_format_valid()`
the test already sources from `stop-gate-core.sh`.

**Measured baseline (RED).** `grep -c 'second FAIL overwrites the first'` = 1
in `agents/spec-master.md` and 1 in `skills/fail-triage/SKILL.md`;
`grep -c 'both \`.fail\` records' agents/orchestrator.md` = 1;
`grep -c 'state_append_unit_marker' hooks/scripts/lib/state-access.sh` = 0;
`hooks/scripts/lib/state-access.sh:32` is `printf '%s\n' "$content" > "$marker_file"`
(overwrite, one function, two references incl. its `export -f`). Criteria 5's
two suites are exit 0 today and are labelled **regression guards** — they
prove the format change did not break the review-join coupling.

---

## Step 6 — F6: honor the WIP sentinel in the reviewer branch of the stop gate

**Affected files**

- `hooks/scripts/lib/stop-gate-core.sh` — the reviewer `SubagentStop` branch,
  specifically the `else` arm that calls
  `block "No verdict is recorded for the unit(s) you were dispatched for…"`.
- `templates/persona-protocol.md` — `## WIP sentinel (mid-task handoff, not a
  bypass)`, and the `## Blocked by a gate you do not own` section's sentinel
  paragraph.
- `adapters/codex/agents-md-fragment.md`,
  `adapters/cursor/rules/persona-protocol.mdc` — their WIP sentinel sections
  (hand-edited; both carry it).
- `CONTEXT.md` — the WIP-sentinel mention that still spells it
  `touch .claude/.wip`; correct it to the real
  `.claude/wip-handoff.<agent-id>` non-empty-reason form and note the
  reviewer branch now honors it.
- `tests/adapter-stop-gate-parity.test.sh` — new cases.
- Regenerated: `.claude/**`, both adapter hook-lib copies,
  `.claude/persona-config.json`.

**Intent.** Before the reviewer branch blocks for a missing verdict, consult
the per-agent sentinel. If `.claude/wip-handoff.<agent-id>` exists and is
non-empty: log the reason to `.claude/wip-audit.log` exactly as the existing
lead-programmer branch does, additionally log a distinguishable
`verdict-deferred-by-wip unit=<id>` line to `.claude/review-audit.log`, delete
the sentinel (one-shot), and allow the turn to end. If it exists and is
**empty**: delete it, do not honor it, and block as today.

**Three hard constraints:**

1. **Do not consume the review-join stamp** and **do not clear pending-review
   flags.** The verdict stays owed; only this one turn-end is unblocked. A
   sentinel must never substitute for, or fabricate, a verdict.
2. **`agent_id` is currently computed at the bottom of the file**, below the
   reviewer branch. The implementer must make the sanitized id available to
   the reviewer branch without changing the existing lead-programmer sentinel
   behavior — the sanitization rule (`${raw_agent_id//[^a-zA-Z0-9._-]/_}`)
   must stay identical in both places.
3. The existing lead-programmer sentinel path, the `.blocked`/`.escalated`
   flags-kept paths, and the `marker-check=bootstrap` fail-open path must all
   behave exactly as before.

**Acceptance criteria**

```sh
# 1. New port-parity cases pass on all three ports.
bash tests/adapter-stop-gate-parity.test.sh                       # exit 0
grep -c 'verdict-deferred-by-wip' tests/adapter-stop-gate-parity.test.sh  # >= 1
# 2. The core honors a non-empty sentinel and ignores an empty one.
grep -c 'verdict-deferred-by-wip' hooks/scripts/lib/stop-gate-core.sh     # >= 1
diff -q hooks/scripts/lib/stop-gate-core.sh \
        adapters/codex/hooks/scripts/lib/stop-gate-core.sh        # exit 0
diff -q hooks/scripts/lib/stop-gate-core.sh \
        adapters/cursor/hooks/scripts/lib/stop-gate-core.sh       # exit 0
# 3. The protocol says the REVIEWER branch is covered (R8: assert each port).
#    NOTE: a bare 'wip-handoff' grep is already 1 in both ports today, so it
#    is a guard, not a change-proof. Pin the new claim instead: the sentinel
#    now also applies to a reviewer that owes a verdict.
grep -c 'verdict is still owed' templates/persona-protocol.md            # >= 1
grep -c 'verdict is still owed' adapters/codex/agents-md-fragment.md     # >= 1
grep -c 'verdict is still owed' adapters/cursor/rules/persona-protocol.mdc # >= 1
grep -c 'wip-handoff' adapters/codex/agents-md-fragment.md        # >= 1 (guard)
grep -c 'wip-handoff' adapters/cursor/rules/persona-protocol.mdc  # >= 1 (guard)
# 4. The stale glossary spelling is gone.
grep -c 'touch .claude/.wip' CONTEXT.md                           # 0
grep -c 'wip-handoff' CONTEXT.md                                  # >= 1
# 5. Neighbouring gate behavior unchanged.
bash tests/stop-gate-blocked.test.sh                              # exit 0
bash tests/stop-gate-escalated.test.sh                            # exit 0
bash tests/review-join.test.sh                                    # exit 0
# 6. Merge gate.
bash tests/validate.sh                                            # exit 0
```

Three mandatory cases in `adapter-stop-gate-parity.test.sh`, one per port at
minimum for the first: (i) reviewer `SubagentStop`, one unsatisfied stamp,
non-empty sentinel present → exit 0, stamp still on disk, pending-review flag
still on disk, `verdict-deferred-by-wip` logged, sentinel deleted; (ii) same
but the sentinel is empty → blocked exactly as today, `marker=MISSING`
logged; (iii) no sentinel → blocked exactly as today.

**Measured baseline (RED).** `grep -c 'verdict-deferred-by-wip' hooks/scripts/lib/stop-gate-core.sh`
= 0. `grep -c 'verdict is still owed'` = 0 in all three prose surfaces.
`grep -c 'touch .claude/.wip' CONTEXT.md` = 1 (CONTEXT.md:1038), and
`grep -c 'wip-handoff' CONTEXT.md` = 3 (so criterion 4's second half is a
guard, and only the first half is a change-proof).
`hooks/scripts/lib/stop-gate-core.sh` computes `agent_id` at line 527, below
the reviewer branch that ends at line 442 — the ordering constraint is real.
Criteria 5's three suites are exit 0 today and are labelled regression guards.

---

## Step 7 — F5 + F7: two false sentences in the shared protocol

Bundled because both are single-sentence corrections inside
`templates/persona-protocol.md` requiring one regeneration pass; splitting
them would force two full five-artifact regenerations for two sentences.

**Affected files**

- `templates/persona-protocol.md` — the `## FAIL record` section's sentence
  beginning "No hook gate depends on it", and the
  `## Structural questions go to the explorer` section's sentence "Only the
  orchestrator has no `Skill` tool at all".
- `adapters/codex/agents-md-fragment.md`,
  `adapters/cursor/rules/persona-protocol.mdc` — the F5 sentence only; both
  carry it, neither carries the F7 sentence (verified).
- Regenerated: `.claude/persona-protocol.md`, `.claude/agents/*.md`,
  `.claude/persona-config.json`.
- **Do NOT touch:** `prototype/protocol-mcp/rules/explorer-routing.md`, which
  also carries the F7 sentence but is a frozen prototype, not a shipped
  surface.

**Intent (F5).** The claim "No hook gate depends on it" is false:
`stop-gate-core.sh` satisfies a review-join stamp via a format-valid `.pass`
**or** `.fail`, so a FAIL verdict whose record is never written **does** block
`SubagentStop` — which the immediately preceding "Pending-review flag"
paragraph already describes correctly. Replace the sentence with one stating
that coupling, cross-referencing the preceding paragraph, and keep the
surviving true half: the record also exists so a completely fresh spawn sees
that a unit already failed. If Step 5 lands first, this sentence must also be
consistent with append semantics.

**Intent (F7).** Replace the false exclusivity claim. `researcher.md`
(`tools: Read, Bash, Grep, WebFetch, WebSearch, SendMessage`) and
`agent-auditor.md` (`tools: Read, Grep, Glob, Bash`) also omit `Skill`.
Reword to "any persona whose `tools:` list omits `Skill`" (or equivalent),
preserving the underlying mechanical-vs-instruction distinction.

**Acceptance criteria**

```sh
# 1. Both false sentences are gone from every surface that carried them.
git grep -c 'No hook gate depends on it'            # no output / exit 1
git grep -c 'Only the orchestrator has no'          # only prototype/ may match
# 2. The corrected claims are present at the template and both adapter ports.
grep -ci 'or `.fail`' templates/persona-protocol.md                    # >= 1
grep -ci 'omits `Skill`' templates/persona-protocol.md                 # >= 1
grep -ci 'stop-gate' adapters/codex/agents-md-fragment.md              # >= 1
grep -ci 'stop-gate' adapters/cursor/rules/persona-protocol.mdc        # >= 1
# 3. The frozen prototype was not touched.
grep -c 'Only the orchestrator has no' prototype/protocol-mcp/rules/explorer-routing.md  # 1
# 4. The rendered mirrors picked the corrections up (proves regeneration ran).
grep -c 'No hook gate depends on it' .claude/agents/reviewer.md        # 0
grep -c 'Only the orchestrator has no' .claude/agents/reviewer.md      # 0
# 5. Cross-reference and parity guards.
node tests/protocol-cross-references.test.js                           # exit 0
node tests/adapter-protocol-parity.test.js                             # exit 0
# 6. Merge gate.
bash tests/validate.sh                                                 # exit 0
```

**Measured baseline (RED).** Both sentences are present in 9 files each.
F5: `templates/persona-protocol.md`, `.claude/persona-protocol.md`,
5 × `.claude/agents/*.md`, and both adapter protocol ports.
F7: `templates/persona-protocol.md`, `.claude/persona-protocol.md`,
6 × `.claude/agents/*.md`, and the excluded `prototype/` copy — so after this
step `git grep -c 'Only the orchestrator has no'` must match **exactly one
file**, the prototype, which is what criterion 3 pins. Criterion 5's two suites are exit 0 today; per the probe-list
caveat in R8, `adapter-protocol-parity.test.js` asserts section *presence*
only and does **not** cover these clauses — it is listed as an
unrelated-regression guard, never as evidence the corrections landed.

---

## Step 8 — F3: correct the model-tier ladder

**Affected files**

- `agents/orchestrator.md` — `## Per-unit model routing` (the
  `Suggested model:` vocabulary line, the `model: haiku` default claim, the
  `(haiku → FAIL → sonnet → FAIL)` ladder), and the
  "**Check for a prior `.fail` record**" paragraph's "never dispatch on
  `haiku`" clause.
- `agents/spec-master.md` — the `.fail`-record-check bullet's "so
  `task-master` never tags the re-scoped step `haiku`" clause.
- `tests/writer-tier-consistency.test.js` — extend with the new pins.
- Regenerated: `.claude/agents/{orchestrator,spec-master}.md`,
  `.claude/persona-config.json`.

**Intent.** Correct four false claims, and point the default at
`CONTEXT.md`'s `**Writer tier**` entry as the single source of truth rather
than restating a tier name inline:

1. "lead-programmer's `model: haiku` frontmatter is the default" — the actual
   frontmatter is `model: sonnet` (ADR-0026, reversing ADR-0010).
2. `Suggested model: haiku|sonnet|opus` — `agents/task-master.md` states the
   tag vocabulary is `sonnet|opus`; `haiku` is not a value task-master emits.
3. `(haiku → FAIL → sonnet → FAIL)` — the real ratchet is sonnet → FAIL →
   opus.
4. "never dispatch on `haiku`" in the prior-`.fail` paragraph — vacuous now
   that haiku is neither the default nor a tag value; restate as the
   Implementer-tier ratchet (`sonnet`→`opus`), which CONTEXT.md already
   defines.

In `spec-master.md`, remove the haiku clause outright; the surviving
instruction is that a prior FAIL is flagged so the re-scoped step is not
tagged for a cheaper tier, per CONTEXT.md's ratchet.

**Do NOT strip every tier name from `agents/orchestrator.md`.** See Open
Question 1: `tests/writer-tier-consistency.test.js` (AC-D7) pins the literal
`Sonnet units escalate on first FAIL` in that file, and AC-D5 pins
`model: sonnet` in the lead-programmer frontmatter. Those must survive.

**Acceptance criteria**

```sh
# 1. The four false claims are gone.
grep -c 'model: haiku` frontmatter is the' agents/orchestrator.md   # 0
grep -c 'haiku → FAIL →' agents/orchestrator.md                     # 0
grep -c 'never dispatch on `haiku`' agents/orchestrator.md          # 0
grep -c 'never tags the re-scoped step' agents/spec-master.md       # 0
# 2. The tag vocabulary matches what task-master actually emits.
grep -c 'haiku|sonnet|opus' agents/orchestrator.md                  # 0
grep -c 'sonnet|opus' agents/task-master.md                         # >= 1 (unchanged)
# 3. CONTEXT.md is cited as the source of truth for the default.
grep -c 'Writer tier' agents/orchestrator.md                        # >= 1
# 4. The pins the existing suite already owns must survive (guards).
grep -c 'Sonnet units escalate on first FAIL' agents/orchestrator.md # 1
node tests/writer-tier-consistency.test.js                           # exit 0
grep -c 'AC-D9' tests/writer-tier-consistency.test.js                # >= 1
# 5. Mirrors picked it up.
grep -c 'haiku → FAIL →' .claude/agents/orchestrator.md             # 0
# 6. Merge gate.
bash tests/validate.sh                                              # exit 0
```

The new `AC-D9` check in `writer-tier-consistency.test.js` must assert that
neither `agents/orchestrator.md` nor `agents/spec-master.md` names `haiku`
as a default, a tag value, or a ladder rung — so this correction cannot
silently regress the way the last one did.

**Measured baseline (RED).** All four criterion-1 greps return 1 today.
`grep -c 'haiku|sonnet|opus' agents/orchestrator.md` = 1.
`grep -c 'Writer tier' agents/orchestrator.md` = 0.
Criterion 4's first two are **guards** (already green — they prove scope was
not exceeded); `grep -c 'AC-D9'` = 0 is the change-proof.

---

## Step 9 — F8: state the operator-request precondition on the auditor's description

**Affected files**

- `agents/milestone-auditor.md` — frontmatter `description:` field only.
- Regenerated: `.claude/agents/milestone-auditor.md`,
  `.claude/persona-config.json`.

**Intent.** `orchestrator.md`'s "Milestone audit gate" says the auditor runs
only on an explicit operator ask, but the frontmatter `description` — the
field Claude Code's description-based auto-delegation actually reads — says
only "Invoke at milestone boundaries (not per-task)…". Add the precondition
to the description so an expensive opus-tier dispatch cannot auto-fire off a
stray mention of a milestone boundary. Change **only** the `description`
value; `name`, `model`, `color`, `tools`, `skills` and `maxTurns` are
untouched, and the body is untouched.

**Acceptance criteria**

```sh
# 1. The precondition is in the frontmatter description, not merely the body.
sed -n '/^---$/,/^---$/p' agents/milestone-auditor.md | grep -ci 'explicitly asks'  # >= 1
sed -n '/^---$/,/^---$/p' .claude/agents/milestone-auditor.md | grep -ci 'explicitly asks'  # >= 1
# 2. Nothing else in the frontmatter moved.
sed -n '/^---$/,/^---$/p' agents/milestone-auditor.md | grep -c '^model: opus'     # 1
sed -n '/^---$/,/^---$/p' agents/milestone-auditor.md | grep -c '^maxTurns: 20'    # 1
sed -n '/^---$/,/^---$/p' agents/milestone-auditor.md | grep -c '^tools:'          # 1
# 3. Merge gate.
bash tests/validate.sh                                                             # exit 0
```

Criterion 1 is deliberately **section-scoped to the frontmatter** via `sed`,
not a whole-file grep: the body already discusses milestone boundaries, so a
whole-file grep would be satisfiable without touching the field that matters.

**Measured baseline (RED).** The frontmatter `description` currently reads
"Invoke at milestone boundaries (not per-task) after all of a milestone's
units have already reached reviewer PASS." and contains no operator-request
condition; the criterion-1 greps return 0.

---

## Step 10 — F11: replace line-number citations with greppable anchors

**Affected files** — exactly 14 citations in 7 source files, enumerated by
`git grep -nE '[A-Za-z0-9_/.-]+\.(sh|md)\.?[a-z]*:[0-9]+(-[0-9]+)?' -- agents templates hooks/scripts commands skills`:

- `agents/orchestrator.md` — 1 (`agents/explorer.md:34-36`).
- `hooks/scripts/dispatch-hygiene.sh` — 4.
- `hooks/scripts/harness-integrity-gate.sh` — 4.
- `hooks/scripts/human-decision-gate.sh` — 1.
- `hooks/scripts/reviewed-path-gate.sh` — 2.
- `hooks/scripts/session-start.sh` — 1.
- `hooks/scripts/task-gate.sh` — 1.
- Regenerated: `.claude/agents/orchestrator.md`, `.claude/hooks/scripts/**`,
  `.claude/persona-config.json`.

**Intent.** Convert each to a distinctive greppable anchor — a function name,
a section heading, or a quoted phrase from the cited region — so the citation
survives edits to the cited file. Six were verified to be already stale
(three cite line numbers **past the target file's current EOF**:
`stop-gate.sh:186-189` and `stop-gate.sh:176` against a 159-line file, and
`protected-paths.sh:22-25` against a 22-line file; three more name content
that has moved, including `task-gate.sh`'s citation of a
"content-validation precedent at stop-gate.sh:75-85" where those lines are
now about pending-review escape hatches). Convert all 14 regardless of
current accuracy — the point is that a line number is the wrong citation
form here, not that six happen to be wrong today.

**Do NOT touch** `agents/reviewer.md`'s `src/routes/notes.js:42` — that is a
fictional `file:line` inside a worked example of reviewer output, not a
citation into this repo, and converting it would damage the example.

**Acceptance criteria**

```sh
# 1. Zero line-number citations remain in the audited scope.
git grep -cE '[A-Za-z0-9_/.-]+\.(sh|md)\.?[a-z]*:[0-9]+(-[0-9]+)?' \
  -- agents templates hooks/scripts commands skills   # no output / exit 1
# 2. The illustrative example is untouched.
grep -c 'src/routes/notes.js:42' agents/reviewer.md   # 1
# 3. The replacements are real anchors, not deletions — each file still
#    cross-references its neighbour by name.
grep -c 'reviewer-route-gate.sh' hooks/scripts/dispatch-hygiene.sh   # >= 1
grep -c 'stop-gate' hooks/scripts/dispatch-hygiene.sh                # >= 3
grep -c 'reviewed-path-gate.sh' hooks/scripts/harness-integrity-gate.sh  # >= 2
grep -c 'benign-command.sh' hooks/scripts/human-decision-gate.sh     # >= 1
grep -c 'protected-paths.sh' hooks/scripts/reviewed-path-gate.sh     # >= 1
grep -c 'harness-integrity.sh' hooks/scripts/session-start.sh        # >= 1
grep -c 'stop-gate' hooks/scripts/task-gate.sh                       # >= 1
grep -c 'agents/explorer.md' agents/orchestrator.md                  # >= 1
# 4. The mirror picked up the hook-script edits.
git grep -cE '\.sh:[0-9]+' -- .claude/hooks/scripts                  # no output / exit 1
# 5. Merge gate.
bash tests/validate.sh                                               # exit 0
```

Criterion 3 exists because criterion 1 alone is satisfiable by **deleting**
every cross-reference — the deletion-vs-survival trap. Each file must still
name its neighbour; only the `:NN` form goes away.

**Measured baseline (RED).** The criterion-1 command returns **7 per-file
count lines today** (`agents/orchestrator.md:1`,
`hooks/scripts/dispatch-hygiene.sh:4`,
`hooks/scripts/harness-integrity-gate.sh:4`,
`hooks/scripts/human-decision-gate.sh:1`,
`hooks/scripts/reviewed-path-gate.sh:2`, `hooks/scripts/session-start.sh:1`,
`hooks/scripts/task-gate.sh:1`), totalling 14 citations. Post-fix it must
produce no output and exit 1.
Criterion 2 returns 1 (a guard). Criterion 3's greps are mostly already ≥ the
stated counts (guards proving the conversion did not degenerate into
deletion) — they are labelled as such, not as change-proofs.

---

## Cross-cutting constraints (apply to EVERY step)

State these verbatim in each dispatch packet:

1. **Regenerate in the same unit.** Any step touching `agents/*.md`,
   `templates/*.md`, or `hooks/scripts/**` must run
   `node bin/cli.js --update --force-render` and commit the resulting
   `.claude/**` mirrors, `adapters/{codex,cursor}/hooks/scripts/lib/**`, and
   `.claude/persona-config.json` `fileHashes` **in that same commit**.
   Deferring makes the unit's own `bash tests/validate.sh` criterion
   unsatisfiable (R2, R3).
2. **Never hand-edit a mirror or `fileHashes`.** The surviving prohibition is
   narrow but absolute. `adapters/codex/agents-md-fragment.md` and
   `adapters/cursor/rules/persona-protocol.mdc` are the exception — those two
   are hand-maintained sources, not mirrors.
3. **Verify `validate.sh` in a pristine detached worktree** at the unit's own
   commit (`git worktree add --detach <tmp> <sha>`), never in the live tree
   (R3).
4. **The regen may carry hash lines belonging to other open units** — this is
   pre-authorized; name them in the commit message rather than reverting them
   (R1).
5. **Never spell `.claude/reviewed/` in a write position inside a Bash
   command.** Marker fixtures go in test files (R4).
6. **No step bumps the plugin version** (Constitution P3 deviation, above).

## Open Questions

1. **F3's "strip the concrete tier names" is applied non-literally, by
   necessity.** Stripping every tier name from `agents/orchestrator.md`
   would break `tests/writer-tier-consistency.test.js` AC-D7, which pins the
   literal `Sonnet units escalate on first FAIL` in that exact file, and
   would delete the real `Suggested model:` tag grammar. Step 8 therefore
   corrects the four false claims and points the *default* at CONTEXT.md,
   while preserving the ratchet sentences the test owns. **Recommended
   default, already applied: proceed as scoped.** Reverse only if you
   intend to also amend that test.
2. **F1's dispatch-hygiene change is documentation-only.** An advisory
   dispatch naming an already-PASSed unit still trips H3, which refuses under
   the shipped `block` default (this repo runs `warn`). Step 1 documents the
   advisory case in the header but does not give H3 a `Mode: advisory`
   carve-out. **Recommended default, already applied: documentation-only
   now**, with the H3 carve-out as a follow-up if an advisory pass on a
   PASSed unit is ever refused in practice. Reverse if you want the carve-out
   in this batch.
3. **F1's "restrict to legitimate callers" needs no new code** — the
   fail-closed caller allowlist in `hooks/scripts/reviewer-route-gate.sh`
   already admits only the orchestrator/main session for reviewer-targeted
   dispatches. Step 1 adds the `advisory-dispatch=<id>` audit line as the
   after-the-fact review surface instead. **Recommended default, already
   applied: no new caller check.** Flagged because the finding's wording
   implies new code that measurement showed to be redundant.
4. **F4's rotate-vs-append choice was made by measurement, not by the human.**
   Append was selected because it leaves all six existing `.fail` consumers
   working unchanged, where rotation would require editing the glob-based
   ones. **Recommended default, already applied: append.** Reverse only if
   you specifically want one file per attempt on disk.

None of the four blocks dispatch; each records a decision already taken, with
the evidence, so it can be reversed deliberately rather than discovered later.

## Self-check

- CHK1: Is the exact on-disk shape of the new `.fail` record defined
  (separator, header format, counting command)? — PASS
- CHK2: Do Steps 2, 3, 4 and 5 agree about which bullets of
  `agents/reviewer.md` each one owns? — FAIL (conflicting) — revised in
  place; R5 now states the overlap and the required slicing/ordering.
- CHK3: Is "advisory dispatch" defined once, in one place, and used
  consistently by Steps 1 and 2? — FAIL (missing) — revised in place; Step 1
  now owns the `CONTEXT.md` glossary entry and Step 2 references it rather
  than re-defining it.
- CHK4: Does every step name every surface its prose change must reach,
  including the hand-maintained adapter ports? — PASS (enumerated per step by
  `git grep -l`, not assumed).
- CHK5: Does any acceptance criterion assert a `git diff` against a
  working tree that will be committed and clean when the reviewer runs it? —
  PASS (none; all criteria are content assertions or command exit codes).
- CHK6: Is every criterion labelled as either a change-proof (currently RED)
  or a guard (currently green)? — FAIL (missing) — revised in place; each
  step now carries a "Measured baseline" paragraph distinguishing the two.
- CHK7: Does the plan state how the 2-FAIL cap is counted after Step 5, at
  the place the cap is enforced? — PASS (Step 5 criterion 3 pins the counting
  command into `agents/orchestrator.md`).
- CHK8: Does Step 4 account for every consumer of the marker's notes area? —
  FAIL (missing) — revised in place; the `marker-verify.sh` parser guard and
  its test case are now inside Step 4 rather than assumed harmless.
- CHK9: Do the F3 criteria conflict with any currently-passing test? — FAIL
  (conflicting) — converted to Open Question 1, and Step 8 now carries
  explicit survival guards for the pinned literals.
- CHK10: Is the F1 caller restriction specified as new code or as existing
  behavior? — FAIL (ambiguous) — converted to Open Question 3.
- CHK11: Does any step's criterion demand deletion of a string that is
  itself the rule being protected? — PASS (checked; Steps 2, 3 and 10 use
  survival pins where the audit's wording implied a deletion check, and each
  says so).
- CHK12: Is the regeneration/serialization requirement stated where an
  implementer will actually read it? — PASS (R1, R2, R3 plus the
  Cross-cutting constraints block, which each dispatch packet must carry
  verbatim).
- CHK13: Was every acceptance criterion in this plan executed against the
  tree before handoff, and is its measured baseline recorded? — FAIL
  (missing) — revised in place. Executing them found **five** defective
  criteria I had authored, all now corrected: (a) Step 5's stale-claim greps
  pinned a phrase that WRAPS in both target files, so both returned 0 and
  were vacuous; (b) Step 5's `state_(append|write)_unit_marker` alternation
  already matched twice today, so its `>= 2` was green before any work; (c)
  Step 1 pinned a literal bash regex spelling, over-constraining the
  implementation; (d) Step 3's survival pin quoted the marker directory path,
  which `reviewed-path-gate.sh` refuses for any non-reviewer identity — the
  implementer could not have run it; (e) Step 6's port assertions greped a
  token both ports already contain. Each was found by running the command,
  not by re-reading the plan.
- CHK14: Does any step assert a process-level signal (a suite's exit code) as
  evidence about a change that suite does not probe? — PASS —
  `tests/adapter-protocol-parity.test.js` in Step 7 and
  `tests/marker-write.test.sh` in Step 3 are both explicitly labelled
  unrelated-regression guards, with R8 recording that the parity suite checks
  section presence via a hand-maintained probe list and does not cover these
  clauses.

## Scribe update hint

After the batch lands: add `**advisory dispatch**` to `CONTEXT.md`'s
`## Language` (Step 1 writes the first version — confirm wording); update the
`**review-join stamp**` entry to mention the advisory no-stamp case; correct
the WIP-sentinel spelling and note the reviewer branch (Step 6); and consider
an ADR for the `.fail` append format, since it changes a marker contract that
`docs/adr/0016-per-unit-review-join.md` and ADR-0023 both depend on. The
`unit id` / `task-id` / `unit-slug` synonymy remains undefined and was
explicitly scoped out of this batch — it is the strongest remaining glossary
gap.
