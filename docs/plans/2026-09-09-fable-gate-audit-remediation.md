# Fable gate-audit remediation — 18 findings (2 Critical, 9 Moderate, 7 Minor)

Status: **FINALIZED — no open questions.** All four Open Questions were
answered by the human on 2026-09-09; see "Resolved decisions" below, and the
Steps they govern (6, 7, 8) now state the decided design directly. Every step
is written against the human-directed fix for its finding; where a directed
fix was not implementable as literally stated, the correction is recorded in
"Spec-time corrections" and the decision that replaced it in "Resolved
decisions".

Date: 2026-09-09
Author: spec-master
Canonical artifact (retrieval contract): this file.

---

## Goal

Close the 18 findings a fable-model audit raised against this repo's
enforcement gates (`hooks/scripts/**`) and `agents/orchestrator.md`, using the
human-directed fix for each, so that:

1. a dispatch cannot forge a privileged agent identity through the `name:`
   field (C1);
2. deleting `.claude/` is detected as tampering rather than read as
   "unadapted" (C2);
3. the review-join coupling that makes a PASS marker mean something cannot be
   suppressed by a pre-existing marker, by an advisory dispatch, or by
   same-turn dispatch batching (M1-M3);
4. the remaining grant-surface, charset-drift, protected-set and
   normalization gaps (M4-M9, m1-m7) are closed with a passing test each.

Nothing beyond these 18 items is in scope.

---

## Context

- All 18 cited locations were re-read at `915acec` (master, clean). **17 of 18
  still say exactly what the audit claims.** The one correction is recorded in
  "Spec-time corrections" below; two findings gained material detail that
  changes their fix, recorded in the same section.
- Two of the findings' premises were reproduced **live during this spec
  session**, not merely read: `m6` (a read-only `jq ... | head` probe of the
  persona-selection config was denied by `harness-integrity-gate.sh`) and the
  known `human-decision-gate.sh` prose false positive (a `git grep` for
  `human-review` + the decision-file token was denied). Those two are
  measured, not inferred.
- `.claude/persona-config.json` **is tracked** in this repo
  (`git ls-files` confirms), so C2's Fix C has a live witness here.
- `protectedPaths` in this repo's live config is **`[]`** (measured). A
  spec-master memory note claiming 26 entries is stale; do not plan around it.
  Consequence: `hooks/scripts/lib/*.sh` is today freely `Write`/`Edit`-able,
  so M7 is a genuine tightening, not a duplicate of an existing protection.
- `humanReviewMode` is `off` and `gatedAgents` is `["lead-programmer"]`.
- Prior FAIL history on the exact surfaces this spec touches (durable evidence
  from `.claude/reviewed/`, full-directory sweep, not a sample):
  `harness-integrity-gate-hardening.fail` (a 2-FAIL-cap escalation; its
  remedy was the frozen family table), `hdg-prose-2.fail` (the
  human-decision-gate prose false-positive escalation),
  `gh425-3.fail`/`gh425-4.fail` (review-join scoping),
  `spec2-unitE.fail`/`gh403.fail`/`mw-step3.fail`/`gh385-2.fail` (the
  mirror/`fileHashes` regeneration class), `gh320.fail` (vacuous criteria).
  **No step in this plan may be tagged `haiku`.** Every step touches a gate
  that has already produced at least one FAIL, and three touch gates that
  produced a 2-FAIL-cap escalation.
- Non-blocking-note sweep (`bash bin/marker-audit.sh . --notes
  --surface=hooks/scripts`) surfaced four notes that are inputs to this plan,
  each dispositioned below:
  - `gh355`: the dead grace-period branch in `task-gate.sh` (lines 35, 94-99)
    plus its `.claude/hooks/scripts/` mirror was already recorded as a natural
    follow-up cleanup unit. **Disposition: this is exactly `m5`; Step 13 owns
    it, including the mirror.**
  - `gh416` note 1: `lib/harness-arm.sh:16`'s header comment claims the
    refusal "names `git restore`" while the shipped message says "restore the
    file from version control". **Disposition: Step 2 edits that header;
    correct the claim in passing (comment-only, no message change).**
  - `gh416` note 2: `harness_arm_or_deny` sits ahead of `stop-gate.sh`'s
    `stop_hook_active` step-0 guard, so a "tampered" verdict blocks the
    main-session `Stop` on every retry with **no in-session escape by
    design**. **Disposition: this is the intended posture and Step 2 makes
    that state newly reachable — recorded as Risk R2, not changed.**
  - `gh422` notes: `docs/trust-model.md` is bijection-guarded by
    `tests/trust-model-bijection.test.js` with `EXPECTED_SELF_REPORTED_COUNT`
    pinned at 9. **Disposition: cross-cutting requirement CC5.**
- The sweep is best-effort: `.claude/reviewed/` is gitignored, untracked
  per-clone state with no recovery source. An absent note is not proof no note
  existed.

### Spec-time corrections (verification found the code no longer/never
matched the claim)

- **M8, substitution half — the described fix is not implementable as
  stated.** The claim ("its early-exit at line 231 runs before the `$(`
  substitution rejection") is **true**: `reviewed-path-gate.sh:231` exits 0
  before `command_is_provably_benign` (`lib/benign-command.sh:188`) or
  `write_with_commented_mention` (`:170`) ever reject a substitution. But
  moving that rejection ahead of the early exit denies **every** Bash command
  containing `$(`, a backtick or `<(` from every non-reviewer identity — the
  fall-through path has no allow branch for such a command. That would break
  this repo's own routine commands. See **Open Question 1**.
- **M8, brace-collapse half — not directly portable.** `set_a_mentioned`'s
  brace collapse (`harness-integrity-gate.sh:156-168`) is meaningful only
  because it feeds a *glob match against whole-path literals*
  (`[[ "$lit" == $g ]]`). `mentions_marker_dir` has no such step: it does a
  substring test for a **directory prefix**, so collapsing `{...}` to `*`
  changes no verdict on its own. Porting the collapse requires also porting a
  glob-match arm, which as a side effect closes the `F-1` glob-metacharacter
  residuals currently pinned as tracked-open at the end of
  `tests/reviewed-path-gate.test.sh`. See **Open Question 2**.
- **M6 — three of the six named patterns have documented, gate-recommended
  agent-write routes.** `.pending-review.*` and `.config-drift-override.*`
  are written by agents via the `defer:`/`skip:` escape that
  `lib/stop-gate-core.sh:500` and `:595` print as remediation and that
  `templates/persona-protocol.md` documents as a *sanctioned exit*;
  `.dispatch-override` is written by the orchestrator via the exact
  `printf 'override: <reason>\n' > .claude/.dispatch-override` that
  `agents/orchestrator.md:111` prescribes. Adding those three to Set A
  (denied on the Bash branch, no exemption) removes three sanctioned exits and
  would push agents toward self-authorized bypasses. See **Open Question 3**.
- **M7 — `hooks/scripts/lib/*` in Set B is a real lockout, with precedent.**
  Set B denies `Write`/`Edit` for every identity with no exemption. After M7,
  the only route to a gate library is a surgical `Bash` edit — and for
  `lib/benign-command.sh` specifically, its own text spells `.claude//reviewed`
  and `.claude/./reviewed` (lines 207-209), so a *whole-file* heredoc rewrite
  of it is additionally denied by `reviewed-path-gate.sh`. This is not novel:
  `hooks/scripts/harness-integrity-gate.sh` is already in Set B **and** its own
  text spells a Set A literal (`review_log=".claude/review-audit.log"`, line
  53), so it has been in exactly this state since Set B existed and has been
  maintained through surgical Bash edits (e.g. commit `f52bec2`). See
  **Open Question 4**.
- **`human-decision-gate.sh` is not a `harness_arm_or_deny` adopter** (the
  seven adopters are `dispatch-hygiene.sh`, `protected-paths.sh`,
  `reviewed-path-gate.sh`, `reviewer-route-gate.sh`, `stop-gate.sh`,
  `task-gate.sh`, and the library itself). C2's Fix C therefore does not
  change that gate's behaviour after a `.claude/` deletion. It is also
  configless, so it stays armed regardless. C2's citation of
  `human-decision-gate.sh:338-345` is accurate as an *instance of the
  pattern* but needs no code change; Step 2 does not touch it.
- **C2 closes detection, not prevention.** Fix C makes the *next* gated action
  after a `.claude/` deletion fail closed. It does not deny the `rm -rf`
  itself — `set_a_mentioned` does not match a bare `.claude` chunk (verified:
  `g=".claude"` glob-matches no Set A literal). No step in this plan adds such
  a denial; do not read C2 as preventing the delete.

### Where the fixes land

| Finding | Canonical file(s) | Port-invariant? |
|---|---|---|
| C1 | `hooks/scripts/lib/reviewer-route-gate-core.sh` | yes (shared lib) |
| C2 | `hooks/scripts/lib/harness-arm.sh` | yes (shared lib) |
| M1, M2 | `lib/reviewer-route-gate-core.sh`, `lib/stop-gate-core.sh` | yes |
| M3 | `lib/stop-gate-core.sh` | yes |
| M4 | `hooks/scripts/reviewed-path-gate.sh` | Claude-only |
| M5 | `lib/state-access.sh` + 8 call sites across 7 files (incl. `lib/stop-gate-core.sh`; census corrected 2026-09-10) | partly |
| M6, M7, m1, m2, m6 | `hooks/scripts/harness-integrity-gate.sh` | Claude-only |
| M8, m1, m2, M4 | `hooks/scripts/reviewed-path-gate.sh` | Claude-only |
| M9 | `lib/stop-gate-core.sh`, `agents/orchestrator.md` | yes + doc |
| m2, m7 | `hooks/scripts/human-decision-gate.sh` | Claude-only |
| m1 | `lib/protected-paths-core.sh` | yes |
| m3 | `hooks/scripts/reviewer-tier.sh` | Claude-only |
| m4 | `hooks/hooks.json` | Claude-only |
| m5 | `hooks/scripts/task-gate.sh` + new test | Claude-only |

"Port-invariant" means the file is in `bin/cli.js`'s `SHARED_HOOK_LIB_FILES`
and its `adapters/{codex,cursor}/hooks/scripts/lib/` copies are **generated**;
they are regenerated by CC1, never hand-edited.
`lib/benign-command.sh` is `CLAUDE_ONLY_HOOK_LIB_FILES` and has no adapter
copy.

---

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial *(re-scored 2026-09-10 — was
   Clear; Step 5's criterion 2 proved unsatisfiable, see issue `#452`)*

- 2026-09-09 Domain entities / data model: Q Where does M5's shared unit-id
  helper live, given `bin/cli.js`'s `assertHookLibDeclarationComplete` throws
  at load time on any undeclared file in `hooks/scripts/lib/`? → A
  (self-resolved): in the existing `hooks/scripts/lib/state-access.sh`, which
  is already declared in `SHARED_HOOK_LIB_FILES` and already owns unit-keyed
  marker paths. A new lib file would require editing `bin/cli.js`, widening
  the unit for no benefit.
- 2026-09-09 Domain entities / data model: Q Which direction resolves M5's
  `#` drift — reject `#` everywhere, or accept it everywhere? → A
  (self-resolved): accept it everywhere. Four of the six sites already accept
  it and write real files containing it; only the two sanitizing sites
  transform it. Rejecting would additionally turn a malformed id into a
  *missing review-join stamp*, which fails OPEN. See Step 5.
- 2026-09-09 Non-functional attributes: Q Does `m2`'s case-folding go on the
  hot path? → A (self-resolved): no. `reviewed-path-gate.sh` and
  `harness-integrity-gate.sh` fire on every `Bash` call in the session, and
  `hdg-prose-2-fix2`'s measured note records a 195 KB command already costing
  74 s. Case-folding is therefore an **additional disjunct evaluated only
  after the existing raw arms miss**, never a replacement for them. See
  Step 10.
- 2026-09-09 Non-functional attributes: Q Does C2's new witness cost anything
  on the hot path? → A (self-resolved): no. `harness_armed` returns 0 at
  `lib/harness-arm.sh:40` whenever the config is present and parseable, before
  any witness logic runs. The `git ls-files` fork is reachable only on the
  already-abnormal path.
- 2026-09-09 Edge cases / failure handling: Q What un-blocks M9's new
  `Stop` block, so it cannot deadlock? → A (self-resolved): three
  independent resolutions, any one of which suffices — the human's decision
  file for that unit, a `.directed` marker for that unit, or a `.pass`/`.fail`
  marker for that unit newer than the `.escalated` marker. See Step 9.
- 2026-09-09 Edge cases / failure handling: Q What happens to M1's
  "always stamp" when the reviewer is dispatched for a unit that already holds
  a valid PASS and legitimately reaches the same verdict? → A (self-resolved):
  it must re-write the PASS marker, giving it a newer mtime, which satisfies
  the stamp. That is M1's intent — the coupling is what makes the second PASS
  attributable. Recorded as Risk R4 because it changes reviewer workflow.
- 2026-09-09 Technical constraints & tradeoffs: Q Is the `.claude/hooks/scripts/`
  mirror re-sync out of scope or `task-master`'s concern (the dispatching
  question)? → A (self-resolved): **neither — it is a per-unit deliverable.**
  `tests/validate.sh:302` diffs the mirror, and `tests/cli-backfill.test.js`
  (run by `validate.sh:520`) makes the live tree transitively a render-parity
  check, so deferring regeneration makes a `validate.sh exit 0` criterion
  unsatisfiable within the deferring unit's own write scope. This is
  cross-cutting requirement CC1 and it is a **five**-artifact change, not
  four. Four prior FAILs in this repo are this exact class.
- 2026-09-09 Technical constraints & tradeoffs: Q Does M7 have to land last?
  → A (self-resolved): yes. Once `hooks/scripts/lib/*` is in Set B, every
  later step editing a gate library must use surgical Bash edits. Ordering
  M7 last costs nothing and keeps the other steps on the ordinary
  `Write`/`Edit` path. See Sequencing.
- 2026-09-09 Terminology consistency: Q Does this plan introduce terms that
  drift from `CONTEXT.md`'s glossary? → A (self-resolved): three new
  load-bearing terms, none conflicting. `git-index witness` (C2),
  `advisory review-join stamp` (M2) and `bounded flag clearing` (M3) have no
  glossary entry. `advisory` is reused in its existing repo sense — the
  `Mode: advisory` dispatch already recognized at
  `lib/reviewer-route-gate-core.sh:81` and logged as `advisory-dispatch=` —
  not `CONTEXT.md`'s separate "advisory review section, never gates" sense; the
  two senses coexist today and this plan adds no third. Routed to the Scribe
  update hint, advisory only.

**Re-scored 2026-09-10 for the Step 5 correction (issue `#452`).** The
mid-flight gap re-opened three categories that had been scored Clear or
Partial on 2026-09-09; the lines below close them. Scope of the re-score is
Step 5 alone — no other step's clarifications are revisited, and the
scorecard above is unchanged for every category the correction did not touch.

- 2026-09-10 Domain entities / data model: Q Is `[^a-zA-Z0-9._-]` a unit-id
  grammar wherever it appears under `hooks/scripts/`? → A (self-resolved):
  **no.** Five occurrences; only two (`task-gate.sh:56`, `reviewer-tier.sh:72`)
  sanitize a unit id. The other three sanitize `agent_id` or `session_id`,
  which key the WIP-sentinel and session-baseline filenames. They are a
  **different id domain and out of scope**: migrating them would newly admit
  `#` into those filenames, a behaviour change M5 does not ask for and no
  criterion in this plan covers. Four further alphanumeric-charclass sites
  (`dispatch-hygiene.sh:143`, `human-decision-gate.sh:202`,
  `lib/agent-identity.sh:18`/`:134`) are likewise other domains. Enumerated in
  Step 5's out-of-scope table.
- 2026-09-10 Domain entities / data model: Q How many unit-id sites are
  there, and in how many spellings? → A (self-resolved): **eight call sites
  across seven files, in three spellings**, not the six the original text
  claimed. Two sites were omitted (`dispatch-hygiene.sh:369`, a second copy of
  the same `Unit:` ERE in the same file; and `lib/stop-gate-core.sh:260`, the
  `unit=` stamp read-back). A third spelling — `human-decision-gate.sh:76`'s
  `[A-Za-z0-9_][A-Za-z0-9_#.-]*` — was matched by neither grep behind the
  original criterion 2, so that criterion could not have detected its own
  scope. Frozen as Step 5's census table.
- 2026-09-10 Technical constraints & tradeoffs: Q Does
  `lib/stop-gate-core.sh:260` belong to Step 5's shared-grammar refactor or to
  Step 3, which already owns that file? → A (self-resolved): **Step 5.** A
  unit's acceptance criteria must be satisfiable within its own write scope
  (the rule that produced CC1); criterion 2 is a claim about all of
  `hooks/scripts/`, so moving the site to Step 3 would leave Step 5 unable to
  make its own central criterion pass. The edits are disjoint — Step 3 changes
  `review_join_state`'s semantics, Step 5 swaps one ERE. Cost: a serialization
  edge, Step 3 before Step 5, recorded in Sequencing. Step 3's own scope and
  criteria are unchanged.
- 2026-09-10 Edge cases / failure handling: Q Does interpolating the shared
  grammar into `human-decision-gate.sh:76` change what that gate accepts? → A
  (self-resolved): it would, if done naively — substituting the whole
  `UNIT_ID_RE` newly rejects a leading-`_` id and caps length at 64, inside a
  *sanctioned-write allowance*. That denies a marker write that succeeds
  today. Decision: **interpolate the tail character class only**, leaving that
  ERE's own leading class and unbounded quantifier alone, and pin the
  no-tightening property as criterion 5. The residual divergence
  (`is_sanctioned_marker_write` accepts a leading-`_` id that `unit_id_valid`
  rejects) is pre-existing, is now recorded deliberately, and M5 neither
  widens nor narrows it.
- 2026-09-10 Completion / acceptance signals: Q Can criterion 2 be expressed
  as a count at all? → A (self-resolved): **no — replaced with a file/line
  allowlist per spelling.** A count is satisfiable by the wrong edit: reaching
  "three remaining" for spelling B by touching an `agent_id` line instead of a
  unit-id line would pass a bare count while doing the opposite of the fix.
  Criterion 2b therefore asserts the assigned-variable name on each surviving
  line, 2c pairs its emptiness check against deletion-of-the-allowance, 2d
  makes all three standing tests rather than transcript assertions, and 2e
  requires a mutation control on the three sites the original criterion was
  blind to.

---

## Risks / dependencies

- **R1 — C1's premise depends on `name:` → `agent_type`.** This repo's own
  gate message (`lib/reviewer-route-gate-core.sh:58`) asserts that a dispatch
  `name:` "will report an `agent_type` of '$dispatch_name'", and a spec-master
  memory note records that a *colliding* name auto-suffixes. Step 1's
  acceptance criteria therefore assert the **deny at the gate**, which is what
  this repo controls, and never assert a downstream `agent_type` value.
- **R2 — C2 converts a silent no-op into a total, operator-only lockout.**
  After Fix C, a project whose tracked config is missing from the working tree
  gets `exit 2` from all seven adopters, including the main-session `Stop`
  ahead of its `stop_hook_active` step-0 guard (`gh416` note 2). There is no
  in-session escape and that is the ratified design (`RD2a`). The existing
  refusal text already names version-control restore. Do not add a rebuild
  route; `lib/harness-arm.sh:16-21` explicitly forbids it.
- **R3 — M4 must not land before C1.** M4 grants the marker-write fallback to
  `agent_type` resolving to `orchestrator`. Without C1, any persona holding
  `Agent` could obtain that identity by dispatching with `name: "orchestrator"`.
  C1 is a hard prerequisite, not a preference.
- **R4 — M1 changes reviewer workflow.** A reviewer re-dispatched for a unit
  that already holds a valid PASS must now write a *newer* verdict or be
  blocked at `SubagentStop`. `agents/reviewer.md` is not edited by this plan;
  if the block message does not make the requirement self-evident, that is a
  follow-up, not a silent widening of this scope.
- **R5 — the `fileHashes` commit route is itself gated.** `.claude/persona-config.json`
  is a Set A literal, so `git commit -- <paths>` naming it is denied. Use
  `git add -A` then a plain `git commit -m`, per the lead-programmer memory
  note `project_harness_integrity_gate_persona_config_commit.md`. That note's
  *retracted* glob-spelling workaround must not be revived.
- **R6 — verify in a pristine worktree, never in place.** `cli-backfill`'s
  fixture copies the repo root verbatim including uncommitted files, so an
  in-flight regeneration gives a false PASS. `git worktree add --detach`.
  Concurrent agent-memory writes also dirty the tree and can fail the
  marker's clean-tree precondition.
- **R7 — `bin/cli.js` rewrites the whole `fileHashes` map** and cannot render
  a subset, so a step's commit may unavoidably carry hash lines belonging to
  other open units. This is pre-authorized; the commit message must name them.
- **R8 — m2 widens a known false-positive surface.** Lowercasing
  `human-decision-gate.sh`'s `*DECISION*` arm makes it fire on the lowercase
  word in prose. That gate already has a live FP history
  (`hdg-prose-2.fail`). Step 10's criteria therefore include the suite's own
  differential sweep with a **zero new false positives** bar; a new FP is a
  FAIL, not a note.
- **R9 — the frozen family table is a FAIL tripwire.** `harness-integrity-gate.sh`'s
  closure condition is a bounded table, kept in two-directional parity with a
  lead-programmer memory note by `tests/harness-integrity-gate.test.sh`, and
  the suite fails on unbounded phrasing ("any spelling", "every spelling",
  "no glob can", …). The 2-FAIL escalation that produced that machinery was
  caused by writing an unbounded claim. Steps 6, 7, 10, 14 must add table rows,
  never universals.
- **R10 — `docs/trust-model.md` is bijection-guarded** with a pinned
  self-reported count of 9. M1 and M9 in particular may convert a row from
  self-reported to mechanically checked.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every cited location was re-read at
  `915acec`; two premises (`m6`, the hdg prose FP) were reproduced live; the
  `protectedPaths` and tracked-config facts were measured, not recalled. Every
  step's criteria are runnable commands.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — CC1
  mandates `node bin/cli.js --update --force-render` for all mirror and
  `fileHashes` regeneration and forbids hand-editing either.
- P3 "Version-stamp discipline": satisfied — CC4 requires a
  `.claude-plugin/plugin.json` bump and a CHANGELOG entry for any step editing
  `agents/*.md` or `templates/*.md`. **Step 9 is the only step that does** —
  the OQ3 decision (branch split) preserves every documented escape, so no
  edit to `templates/persona-protocol.md` or `agents/orchestrator.md`'s
  escape-hatch prose is needed for Step 6.
- P4 "Optional personas degrade gracefully": satisfied — Step 4 (M4) and
  Step 9 (M9) both key on `personaSelection`/marker presence, and Step 9's
  new `Stop` branch is inert in a project with no reviewer, since only the
  reviewer writes `.escalated`.
- P5 "`tests/validate.sh` is the merge gate": satisfied — CC3 makes a
  pristine-worktree `bash tests/validate.sh` exit 0 a criterion of every step.

---

## Cross-cutting requirements (apply to every step)

- **CC1 (five-artifact rule).** Any step editing `hooks/scripts/**` must, in
  the same commit, run `node bin/cli.js --update --force-render` and commit:
  `.claude/hooks/scripts/**`, the `adapters/{codex,cursor}/hooks/scripts/lib/`
  copies of any SHARED lib it touched, and `.claude/persona-config.json`
  (`fileHashes`). *Criterion*: in a pristine detached worktree at the step's
  own commit, `node bin/cli.js --update --force-render && git status
  --porcelain` emits **zero** lines. Plain `--update` is not a substitute —
  its version fast path can no-op.
- **CC2 (commit route).** Never name `.claude/persona-config.json` (or an
  audit-log sibling) in a `git commit --`/`-o` pathspec. `git add -A` +
  `git commit -m`.
- **CC3 (merge gate).** `bash tests/validate.sh` exits 0, verified in a
  pristine detached worktree at the step's own commit.
- **CC4 (constitution §3).** A step editing `agents/*.md` or `templates/*.md`
  bumps `.claude-plugin/plugin.json` and adds a CHANGELOG entry.
- **CC5 (trust model).** If the step changes whether a `docs/trust-model.md`
  row is mechanically checked, update the doc and
  `tests/trust-model-bijection.test.js`'s `EXPECTED_SELF_REPORTED_COUNT`.
  *Criterion*: `node tests/trust-model-bijection.test.js` exits 0.
- **CC6 (family table).** A step changing `harness-integrity-gate.sh`'s
  Bash-branch matching adds a row to the frozen family table in
  `tests/harness-integrity-gate.test.sh` **and** the matching table in
  `.claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md`
  (parity is asserted in both directions), and introduces no
  unbounded-universal phrasing in either.
- **CC7 (residual pins).** A step changing `mentions_marker_dir` re-classifies
  the affected `tracked open` pins at the end of
  `tests/reviewed-path-gate.test.sh`. A pin still asserting `allowed` for a
  shape the step now denies is a suite failure, by construction.
- **CC8 (glossary).** `CONTEXT.md`'s Set A / Set B entry and its review-join
  stamp entry enumerate specifics; a step changing those specifics updates the
  entry in the same commit.
- **CC9 (no self-authorized bypass while implementing).** Editing a file in
  Set A or Set B requires a **surgical** Bash edit whose command text avoids
  every Set A literal, `.claude/reviewed`, and the human-review decision
  tokens. Rewording a command to dodge a gate's scan is a bypass, not a
  workaround; if no sanctioned route fits, report and wait.

---

## Sequencing

```
Step 1 (C1) ──► Step 4 (M4)          [hard dependency, R3]
Step 3 (M1+M2+M3) ──► Step 5 (M5)    [file conflict, added 2026-09-10]
Steps 2, 6, 8, 9, 10, 11, 12, 13, 14, 15      [independent]
                                   ...all of the above ──► Step 7 (M7)  [LAST]
```

Step 7 (M7) lands last because it removes the `Write`/`Edit` route to
`hooks/scripts/lib/*` for every later step.

**Step 3 ──► Step 5 (added 2026-09-10, issue `#452`).** Step 5's corrected
affected-files list adds `hooks/scripts/lib/stop-gate-core.sh:260`, which
Step 3 also edits (`review_join_state`). The two must not be dispatched
concurrently. Step 3 lands **first**, because it restructures that function
while Step 5 only swaps one ERE inside it: with Step 3 second, its rewrite
could reintroduce an inline unit-id spelling that Step 5's already-PASSed
criterion 2 would never re-check. With Step 3 first, Step 5's pin is the last
word. Criterion 2d additionally makes the pin a standing test, so a
later-step regression fails **CC3** regardless of order — the ordering edge is
the primary control and 2d is the backstop, not a substitute for it. This is
an ordering constraint only: it does **not** change Step 3's own scope,
affected files, or acceptance criteria, which are untouched by this
correction.

---

## Step 1 — C1: unconditional dispatch-`name:` identity check

**Affected files**
- `hooks/scripts/lib/reviewer-route-gate-core.sh` (the check)
- `tests/reviewer-route-gate-caller.test.sh` (new cases)
- CC1 artifacts (this is a SHARED lib: both adapter copies regenerate)

**What to build**

In the core, **before** the existing `target_type`-keyed blocks, add an
unconditional check:

```
PRIVILEGED_PERSONAS=(reviewer orchestrator)   # see the drift test below
if [ -n "$dispatch_name" ]; then
  dispatch_persona = identity_persona_name(dispatch_name)
  if dispatch_persona ∈ PRIVILEGED_PERSONAS
     and NOT persona_matches_gate(target_type, dispatch_persona):
        deny (exit 2) with a message naming the forged name, the actual
        subagent_type, and the rule
fi
```

The existing reviewer-targeted `name:` check at `:54-61` stays; it is
narrower (it also rejects a *non*-privileged name on a reviewer dispatch) and
this new check does not subsume it.

The privileged set must not drift. Add to
`tests/reviewer-route-gate-caller.test.sh` a **derivation test**: the array's
members must equal the union of (a) every bare literal appearing as the second
argument of `persona_matches_grant` anywhere under `hooks/scripts/`, and
(b) every bare literal appearing as the second argument of
`persona_matches_gate` in a caller-allowlist position in
`hooks/scripts/reviewer-route-gate.sh`. Today that union is
`{reviewer, orchestrator}`; the test computes it rather than restating it.

No other gate needs this check: `name` exists only on the `Agent` PreToolUse
payload, `reviewer-route-gate.sh` is registered on the `Agent` matcher and so
sees every dispatch, and the `Bash`/`Stop` payloads that reach the grant sites
carry no `name` field.

**Acceptance criteria**
1. **Bypass reproduction, now denied.** A payload with
   `tool_input.subagent_type = "explorer"` and `tool_input.name = "reviewer"`
   makes `hooks/scripts/reviewer-route-gate.sh` exit **2**. Same for
   `name = "orchestrator"`. Both cases added to
   `tests/reviewer-route-gate-caller.test.sh`.
2. **Mutation control.** Reverting only the new block (leaving `:54-61`
   intact) makes case (1) exit **0** — i.e. the new block is the sole denier.
   Run as a copied mutant via the suite's existing `GATE_UNDER_TEST` mechanism
   (absolute path; `lib/` beside the copy).
3. **No over-block.** All of these still exit 0: `subagent_type: "reviewer"`
   with `name: "reviewer"`; `subagent_type: "reviewer"` with no `name`;
   `subagent_type: "lead-programmer"` with `name: "lp-2"`;
   `subagent_type: "explorer"` with no `name`;
   `subagent_type: "antislop:reviewer"` with `name: "antislop:reviewer"`.
4. **Namespace handling.** `name: "antislop:reviewer"` with
   `subagent_type: "explorer"` exits 2 (the check compares persona names, not
   raw identities).
5. The derivation test above passes, and fails if `orchestrator` is removed
   from the array.
6. `bash tests/reviewer-route-gate-caller.test.sh` exits 0.
7. `bash tests/review-join.test.sh` and
   `bash tests/adapter-stop-gate-parity.test.sh` exit 0.
8. CC1, CC3.

---

## Step 2 — C2: git-index witness in `harness_armed`

**Affected files**
- `hooks/scripts/lib/harness-arm.sh`
- `tests/harness-arm.test.sh`
- CC1 artifacts (SHARED lib)

**What to build**

In `harness_armed()`, before the `return 1` at `:48` (missing `agents/*.md`)
and before the `return 1` at `:56` (missing second witness), add a **git-index
witness**: if `git -C "$project_dir" ls-files --error-unmatch
"${dot_label}/persona-config.json"` succeeds while `${dot}/persona-config.json`
is absent from the working tree, return **2** (tampered) with
`HARNESS_ARM_STATE="absent"` and `HARNESS_ARM_WITNESSES` naming the git index.

Constraints:
- The witness runs only on the already-abnormal path — never before the
  `:40` armed return. No hot-path cost.
- A repo with no git, no `.git`, or where the file was never committed must
  still return **1** (unadapted). `ls-files` failing for any reason means
  "no witness", never "tampered".
- Do not read the config's *content* anywhere in this function; the D1 rule
  ("the file that may have been deleted cannot also be the evidence that it
  should exist") still holds — the witness is the git index, not the file.
- Correct the header comment at `:16` per the `gh416` note: the refusal names
  version-control restore, not the literal string `git restore`. Comment only;
  the message text is unchanged.
- `_harness_arm_message` must render sensibly for the new witness string.

**Acceptance criteria**
1. **Bypass reproduction, now tampered.** In a git fixture where
   `<dot>/persona-config.json` is committed and then deleted from the working
   tree *along with* `<dot>/agents/`, `harness_armed` returns **2** (before
   this fix it returns 1). New case in `tests/harness-arm.test.sh`.
2. **Downstream fail-closed.** With that same fixture, at least two adopters
   exit 2 with the disarmed refusal on stdin they would previously have waved
   through: `hooks/scripts/reviewed-path-gate.sh` and
   `hooks/scripts/reviewer-route-gate.sh`.
3. **`rm -rf .claude` end-to-end.** A fixture that deletes the whole dot-dir
   (config, markers, audit logs) still yields `harness_armed` → 2.
4. **No false tamper.** All return **1**: a fixture with no `.git` at all; a
   fixture that is a git repo where the config was never added; a fixture
   where `git` is not on `PATH`. Assert the exact return code, not just
   "not 2".
5. **Still armed.** A fixture with a present, parseable config returns **0**,
   and does so **without** invoking `git` — assert via a `PATH` shim that
   makes `git` fail loudly, or a call-count probe.
6. `bash tests/harness-arm.test.sh` exits 0.
7. `bash tests/adapter-stop-gate-parity.test.sh` exits 0 (the codex/cursor
   `harness-arm.sh` copies are regenerated by CC1 and use their own
   `dot_label`; the `.codex` dot-label case at `tests/harness-arm.test.sh:145`
   must still pass).
8. CC1, CC3.

---

## Step 3 — M1 + M2 + M3: review-join stamp semantics

These three are one unit: all three change `review_join_state()` and the
single `state_clear_all_pending_review` call site, and splitting them would
make each one's test suite assert against a half-migrated stamp format.

**Affected files**
- `hooks/scripts/lib/reviewer-route-gate-core.sh` (stamp writing)
- `hooks/scripts/lib/stop-gate-core.sh` (`review_join_state`, the clear site)
- `tests/review-join.test.sh`
- possibly `docs/trust-model.md` + `tests/trust-model-bijection.test.js` (CC5)
- `CONTEXT.md` review-join stamp entry (CC8)
- CC1 artifacts (both are SHARED libs)

**What to build**

**M1 — always stamp, record prior.** Remove the
`if [ "$pass_valid" = false ]` guard at `lib/reviewer-route-gate-core.sh:95`.
The stamp is written unconditionally for a well-formed `Unit:` line. When a
valid PASS already exists, record `prior=pass` and `prior_mtime=<that
marker's mtime>`. The existing `fail`/`blocked` prior branches are unchanged,
and the existing consumer at `lib/stop-gate-core.sh:286-303` already enforces
"a marker strictly newer than `prior_mtime`", so no consumer change is needed
for M1 itself.

**M2 — advisory stamp variant.** Replace the bare
`exit 0` for a `Mode: advisory` dispatch (`:81-84`) with: write an advisory
stamp at `${dot}/.review-join.<unit>.advisory` whose first line carries
`unit=<id> mode=advisory`, keep the existing `advisory-dispatch=` audit line,
then exit 0. The distinct filename is load-bearing — it must not overwrite a
real `.review-join.<unit>` stamp for the same unit — while still matching the
`.review-join.*` glob that `review_join_state` iterates.

In `review_join_state`, classify a stamp carrying `mode=advisory` into a new
`JOIN_ADVISORY_UNITS` array. Advisory stamps: **do** count toward
`JOIN_STAMP_COUNT` (so an advisory-only reviewer turn no longer falls into the
bootstrap path), **do** enter `scoped_units` (so gh425 marker scoping keeps
working), are consumed/deleted like satisfied stamps, and are **never**
counted as satisfied for the flag-clearing decision below.

**M3 — bounded flag clearing.** Replace `state_clear_all_pending_review` at
`lib/stop-gate-core.sh:425` with bounded clearing: clear **at most**
`${#JOIN_SATISFIED_STAMPS[@]}` pending-review flags, oldest first by mtime,
and append one audit line naming how many were cleared and how many remain.
The `JOIN_STAMP_COUNT == 0` bootstrap path (`:374-377`) keeps today's
clear-all behaviour verbatim — that is an explicitly ratified fail-open and
this step does not change it.

**Acceptance criteria**
1. **M1 bypass reproduction, now stamped.** Fixture: a valid `<u>.pass` marker
   exists before the reviewer is dispatched for `<u>`. After the route gate
   runs, `${dot}/.review-join.<u>` **exists** and its first line contains
   `prior=pass` and a numeric `prior_mtime`. (Pre-fix: no stamp is written.)
2. **M1 coupling.** With that stamp standing and the marker's mtime unchanged,
   the reviewer's `SubagentStop` **blocks** (exit 2) naming `<u>` as having no
   new verdict. After rewriting the marker (newer mtime), the same
   `SubagentStop` allows.
3. **M2 bypass reproduction.** Fixture: two pending-review flags standing,
   zero stamps, then an advisory reviewer dispatch (`Mode: advisory`) for
   `<u>`. Post-fix, the reviewer's `SubagentStop` clears **zero** flags and
   both flags still exist. (Pre-fix: both are cleared via bootstrap.)
4. **M2 no-clobber.** With a real `.review-join.<u>` present, an advisory
   dispatch for the same `<u>` leaves the real stamp byte-identical.
5. **M2 scoping preserved.** A `.blocked` marker for a unit named only by an
   advisory stamp is still treated as in-scope (`flags-kept` logged), not
   ruled out-of-scope.
6. **M3 bypass reproduction.** Fixture: two flags, one satisfied stamp. After
   the reviewer's `SubagentStop`, exactly **one** flag remains, and
   `.claude/review-audit.log` gains a line naming the remaining count.
   (Pre-fix: zero remain.)
7. **M3 bootstrap unchanged.** Zero stamps + two flags → both cleared, and
   the `marker-check=bootstrap` audit line is still written.
8. `bash tests/review-join.test.sh` exits 0.
9. `bash tests/stop-gate-blocked.test.sh`,
   `bash tests/stop-gate-escalated.test.sh`,
   `bash tests/stop-gate-config-drift.test.sh`,
   `bash tests/stop-gate-deferred-microworld.test.sh`,
   `bash tests/stop-gate-microworld-skip.test.sh`,
   `bash tests/adapter-stop-gate-parity.test.sh`,
   `bash tests/reviewer-route-gate-caller.test.sh` all exit 0.
10. `bash tests/state-access-constraints.test.sh` and
    `bash tests/state-distinctions-manifest.test.sh` exit 0 (a new artifact
    species is being introduced; if the manifest enumerates species, the
    advisory stamp must be added there).
11. CC1, CC3, CC5, CC8.

---

## Step 4 — M4: orchestrator identity in the no-reviewer fallback

**Depends on Step 1** (R3). Do not dispatch before Step 1 has a PASS marker.

**Affected files**
- `hooks/scripts/reviewed-path-gate.sh` (`:263`)
- `tests/reviewed-path-gate.test.sh`
- CC1 artifacts

**What to build**

Change the fallback condition at `:263` from `[ -z "$agent_type" ]` to
`[ -z "$agent_type" ] || persona_matches_gate "$agent_type" orchestrator`.
The liberal (gate) matcher is correct here and matches the existing comment's
reasoning at `:19-21`: a miss only makes the main session's write allowed.
Everything inside the branch — the `personaSelection` reviewer probe and the
standing-`.escalated` refusal at `:272-283` — is unchanged and now also
applies to the `orchestrator` identity.

**Acceptance criteria**
1. **Unreachable-path reproduction, now reachable.** Fixture:
   `personaSelection` without `reviewer`, no `.escalated` markers,
   `agent_type = "orchestrator"`, a Bash command writing a marker. Post-fix
   the gate exits **0**; pre-fix it exits 2 with the grant-denied message.
   Same for `agent_type = "antislop:orchestrator"`.
2. **The escalation refusal still fires.** Same fixture plus one standing
   `.escalated` marker → exits **2** with the standing-escalation message.
3. **No widening when a reviewer IS selected.** `personaSelection` containing
   `reviewer`, `agent_type = "orchestrator"` → exits **2**.
4. **No widening for other identities.** `agent_type = "lead-programmer"`
   under a reviewer-less config → still exits 2.
5. **The remediation text is now true.** `hooks/scripts/task-gate.sh:71`'s
   "(or the no-reviewer fallback lead)" and `agents/orchestrator.md`'s
   no-reviewer paragraph describe a path a test now exercises — assert by
   citing the new test case, not by editing prose.
6. `bash tests/reviewed-path-gate.test.sh` and
   `bash tests/reviewed-dir-leak-guard.test.sh` exit 0.
7. CC1, CC3.

---

## Step 5 — M5: one shared unit-id grammar and marker-path derivation

> **Corrected 2026-09-10** after `task-master` reported a mid-flight gap
> against criterion 2 (issue `#452`). The affected-files list gained two
> previously-omitted unit-id sites, criterion 2 was rewritten from an
> unsatisfiable count pin into an enumerated allowlist assertion, and the
> unit-id / non-unit-id domain boundary is now stated explicitly. Steps 1-4
> and 6-15 are unchanged; the only edit outside this step is the new
> Step 3 → Step 5 edge in Sequencing.

**Affected files**
- `hooks/scripts/lib/state-access.sh` (the helpers)
- `hooks/scripts/dispatch-hygiene.sh` (`:321` **and `:369`** — the same
  `Unit:` ERE appears twice in this file: once for H3's marker lookup, once
  for H4's dispatch-contract check. Both migrate.)
- `hooks/scripts/marker-write.sh` (`:31`)
- `hooks/scripts/lib/reviewer-route-gate-core.sh` (`:68`)
- `hooks/scripts/lib/stop-gate-core.sh` (`:260` — the `unit=` read-back inside
  `review_join_state`. **Added 2026-09-10**; see "Unit-id site census" and the
  Step 3 file-conflict note below.)
- `hooks/scripts/human-decision-gate.sh` (`:76`)
- `hooks/scripts/task-gate.sh` (`:56`)
- `hooks/scripts/reviewer-tier.sh` (`:72`)
- `tests/state-access-*.test.sh`, `tests/marker-write.test.sh`,
  `tests/dispatch-hygiene.test.sh`, `tests/reviewer-tier.test.sh`,
  `tests/human-decision-gate.test.sh`, new `tests/task-gate.test.sh`
  (created by Step 13 — if Step 13 has not landed, create it here and Step 13
  extends it)
- CC1 artifacts (`state-access.sh` and `reviewer-route-gate-core.sh` are
  SHARED)

**What to build**

In `lib/state-access.sh` (chosen because it is already in
`SHARED_HOOK_LIB_FILES` and already owns unit-keyed paths; a new lib file
would make `bin/cli.js` unloadable via `assertHookLibDeclarationComplete`):

- `UNIT_ID_CHARCLASS` — the single source of truth, `A-Za-z0-9._#-`.
- `UNIT_ID_RE` — `^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$`, built from it.
- `unit_id_valid <id>` — returns 0 iff the id matches `UNIT_ID_RE` **and**
  contains no `/` and no `..` (the traversal guard, re-applied centrally).
- `unit_id_sanitize <raw>` — replaces every character outside
  `UNIT_ID_CHARCLASS` with `_`. **`#` is preserved** (this is the whole fix).
- `unit_id_marker_path <id> <ext>` — the one derivation, no further
  transformation.

#### Unit-id site census (measured at `915acec`, corrected 2026-09-10)

The original text said "six sites". The measured count is **eight call sites
across seven files**, in three drifting spellings. This table is the frozen
scope of the step — a site not on it is out of scope by construction.

| # | Site | Spelling | Migrates to |
|---|---|---|---|
| 1 | `dispatch-hygiene.sh:321` | A — `[A-Za-z0-9][A-Za-z0-9._#-]{0,63}` | `UNIT_ID_RE` |
| 2 | `dispatch-hygiene.sh:369` | A | `UNIT_ID_RE` |
| 3 | `lib/reviewer-route-gate-core.sh:68` | A | `UNIT_ID_RE` |
| 4 | `lib/stop-gate-core.sh:260` | A | `UNIT_ID_RE` |
| 5 | `marker-write.sh:31` (`UNIT_ID_RE=`) | A | sourced; local definition deleted |
| 6 | `task-gate.sh:56` | B — `[^a-zA-Z0-9._-]` sanitizer | `unit_id_sanitize` |
| 7 | `reviewer-tier.sh:72` | B | `unit_id_sanitize` |
| 8 | `human-decision-gate.sh:76` | C — `[A-Za-z0-9_][A-Za-z0-9_#.-]*` | tail class only (see below) |

Sites 2 and 4 were absent from the original affected-files list. Spelling C
is matched by neither grep the original criterion 2 used.

#### Out of scope — a different id domain (decided 2026-09-10)

Spelling B's literal `[^a-zA-Z0-9._-]` also appears at three **non**-unit-id
sites, and the broader "alphanumeric charclass" family at several more.
**None of them are in scope.** They sanitize or validate a different id
domain, and folding them into `unit_id_sanitize` would newly admit `#` into
filenames M5 says nothing about:

| Site | Domain | Why out of scope |
|---|---|---|
| `lib/stop-gate-core.sh:527` | `agent_id` | feeds the WIP-sentinel filename `.claude/wip-handoff.<agent-id>` |
| `lib/stop-gate-core.sh:548` | `session_id` | feeds `.claude/.session-baseline.<sid>` |
| `session-start.sh:35` | `session_id` | same baseline filename |
| `dispatch-hygiene.sh:143` | `target_type` (persona type) | different grammar; `:` is deliberately in-class |
| `human-decision-gate.sh:202` | path-head safety class | not an id at all — the prose-FP guard's inert-character set |
| `lib/agent-identity.sh:18`, `:134` | identity token | persona identity, not unit id |
| `lib/stop-gate-core.sh:393`, `marker-verify.sh:80` | neither | unrelated parse fragments |

`lib/stop-gate-core.sh:24`'s comment describes the `agent_id`/`session_id`
strip; it stays as written.

#### Site-specific notes

- Sites 6 and 7 (`task-gate.sh:56`, `reviewer-tier.sh:72`) switching from
  their inline sanitizers to `unit_id_sanitize` **is** the behaviour change
  that closes the drift.
- Site 8 (`human-decision-gate.sh:76`) cannot call a function from inside its
  whole-line ERE, so it interpolates `UNIT_ID_CHARCLASS`. **Interpolate the
  tail character class only** — keep that ERE's own leading `[A-Za-z0-9_]`
  and its unbounded `*`. Substituting the whole `UNIT_ID_RE` would newly
  reject a leading-`_` id and cap length at 64 inside a *sanctioned-write
  allowance*, i.e. it would deny a marker write that succeeds today. That is
  a tightening of an escape route, outside M5's scope. The resulting
  residual — `is_sanctioned_marker_write` accepts a leading-`_` id that
  `unit_id_valid` rejects — is a **known, deliberate** leftover: it is the
  pre-existing state, and M5 neither widens nor narrows it.
- `unit_id_sanitize` must spell its complement as `[^${UNIT_ID_CHARCLASS}]`,
  never as a restated literal. This is load-bearing for criterion 2b.

Direction rationale (recorded because it is a judgment call): `#` is accepted
everywhere rather than rejected everywhere. Five of the eight sites already
accept it and write real files containing it; rejecting would additionally
turn a malformed id into a *missing* review-join stamp, which fails OPEN.

#### File conflict with Step 3 (`hooks/scripts/lib/stop-gate-core.sh`)

Site 4 keeps `lib/stop-gate-core.sh` in **Step 5's** scope even though Step 3
also edits that file. The two edits are disjoint in both line and concern:
Step 3 changes `review_join_state`'s *classification and clearing semantics*
(advisory stamps, bounded clearing); Step 5 swaps one inline ERE at `:260`
for the shared `UNIT_ID_RE`. Step 3's body is **not** amended by this
correction.

Site 4 stays in Step 5 rather than moving to Step 3 because criterion 2 is a
single-source-of-truth claim over all of `hooks/scripts/`, and a unit's
acceptance criteria must be satisfiable **within that unit's own write
scope** — the same rule that produced CC1. Moving site 4 to Step 3 would
leave Step 5 holding a central criterion it cannot make pass at its own
commit.

Two consequences, both handled:
- **Sequencing.** Steps 3 and 5 must not be dispatched concurrently, and
  Step 3 lands first. See Sequencing.
- **Durability.** Criterion 2 is encoded as a *test*, not a one-off shell
  assertion, so a later step reintroducing an inline spelling fails the merge
  gate rather than slipping past an already-PASSed unit. See criterion 2d.

**Acceptance criteria**
1. **Drift reproduction, now round-trips.** For `unit_id = "gh#348"`:
   `hooks/scripts/marker-write.sh FAIL 'gh#348' - 'defect' '.claude/reviewed/gh#348.fail'`
   writes `<dot>/reviewed/gh#348.fail`; `hooks/scripts/reviewer-tier.sh 'gh#348'
   <range>` prints `opus` (the FAIL ratchet fires); and `task-gate.sh`'s
   `marker_valid` finds a matching `gh#348.pass`. Pre-fix, the ratchet looks
   up `gh_348.fail` and prints `sonnet`.
2. **Single source of truth — three spellings, allowlisted not counted.**
   *(Rewritten 2026-09-10. The original "exactly one occurrence of each
   charclass" pin was unsatisfiable: three of spelling B's five occurrences
   are non-unit-id sanitizers that must not change, and spelling C was
   matched by neither grep. See issue `#452`.)*

   All three greps below are scoped to the pathspec **`hooks/scripts/`
   only** — never `.claude/hooks/scripts/` and never `adapters/`, whose
   copies are generated and are covered by CC1 instead. Each asserts a
   **file/line allowlist**, not a bare total, so a moved line does not
   silently satisfy it.

   **2a — spelling A (`A-Za-z0-9._#-`) has exactly one home.**
   ```sh
   git grep -c -F 'A-Za-z0-9._#-' -- hooks/scripts/
   ```
   Expected post-fix, verbatim and as the *entire* output:
   `hooks/scripts/lib/state-access.sh:1` — the `UNIT_ID_CHARCLASS`
   assignment. Measured pre-fix (RED): four files, five lines —
   `dispatch-hygiene.sh:2`, `lib/reviewer-route-gate-core.sh:1`,
   `lib/stop-gate-core.sh:1`, `marker-write.sh:1`.

   **2b — spelling B (`[^a-zA-Z0-9._-]`) survives only outside the unit-id
   domain.**
   ```sh
   git grep -n -F '[^a-zA-Z0-9._-]' -- hooks/scripts/
   ```
   Expected post-fix: exactly **three** lines, and they must be exactly the
   `agent_id`/`session_id` sanitizers named in the out-of-scope table —
   `lib/stop-gate-core.sh` (two lines), `session-start.sh` (one line).
   Assert the file set and the assigned-variable name on each line
   (`agent_id`, `session_id`, `session_id`), not just the count. Measured
   pre-fix (RED): five lines, the two extra being `reviewer-tier.sh:72` and
   `task-gate.sh:56`. **A run that reaches three by editing an `agent_id` or
   `session_id` line instead of the two unit-id lines fails this criterion**
   — that is what the variable-name assertion catches.
   `lib/state-access.sh` must **not** appear in this output at all:
   `unit_id_sanitize` spells its complement `[^${UNIT_ID_CHARCLASS}]`.

   **2c — spelling C (`A-Za-z0-9_#.-`) is eliminated.**
   ```sh
   git grep -l -F 'A-Za-z0-9_#.-' -- hooks/scripts/
   ```
   Expected post-fix: **empty**. Measured pre-fix (RED):
   `hooks/scripts/human-decision-gate.sh`. Paired assertion, because 2c
   alone would also be satisfied by deleting the allowance outright:
   `human-decision-gate.sh:76`'s ERE still contains the literal
   `[A-Za-z0-9_]` (its unchanged leading-character class and its heredoc
   delimiter class) and still contains `${UNIT_ID_CHARCLASS}` interpolated.

   **2d — encoded as a test, not a one-off.** 2a, 2b and 2c are added as
   cases in `tests/state-access-constraints.test.sh` (already run by
   `tests/validate.sh:877`, hence by **CC3** on every later step). A one-off
   shell assertion in the dispatch transcript does **not** satisfy this
   criterion. Rationale: Step 3 edits the same function as site 4 and lands
   first; without a standing test, a later step reintroducing an inline
   spelling would never re-trip Step 5's already-PASSed pin.

   **2e — mutation control.** Reverting any single one of the eight site
   migrations in the census table must make 2a, 2b or 2c fail. Demonstrate
   for at least sites 2, 4 and 8 (the three the original criterion could not
   see), so the assertion is proven non-vacuous rather than assumed so.
3. **Traversal still rejected.** `unit_id_valid` returns non-zero for
   `../x`, `a/b`, `a..b`, `.hidden`, a 65-character id, and the empty string.
   The existing per-site `*/*|*..*` guards stay (they are documented
   deliberate redundancy at `dispatch-hygiene.sh:323-327`) and must still be
   present — assert by grep.
4. **No behaviour change for `#`-free ids.** `bash tests/marker-write.test.sh`,
   `bash tests/dispatch-hygiene.test.sh`, `bash tests/reviewer-tier.test.sh`,
   `bash tests/human-decision-gate.test.sh`,
   `bash tests/reviewer-route-gate-caller.test.sh` all exit 0 unchanged.
5. **Site 8 is not tightened.** *(Added 2026-09-10.)* Two new cases in
   `tests/human-decision-gate.test.sh`, both asserting the verdict is the
   **same before and after** this step:
   - a leading-underscore id — `cat > .claude/reviewed/_u1.pass <<'EOF'` …
     `EOF` — is still accepted by `is_sanctioned_marker_write` (the gate does
     not deny it). Interpolating the whole `UNIT_ID_RE` rather than just the
     tail class would flip this to a deny; that is the regression this case
     exists to catch.
   - a 70-character id is likewise still accepted at this site, even though
     `unit_id_valid` rejects it. The divergence is the deliberate residual
     recorded under "Site-specific notes".
   Also assert the drift fix reached site 8: a `gh#348.pass` marker write is
   accepted, and a `#`-bearing id is not rewritten on the way through.
6. **Site 4's edit does not disturb Step 3's semantics.** *(Added
   2026-09-10.)* `bash tests/review-join.test.sh`,
   `bash tests/stop-gate-blocked.test.sh` and
   `bash tests/adapter-stop-gate-parity.test.sh` exit 0 — the same three
   suites Step 3 relies on, re-run here because Step 5 also edits
   `lib/stop-gate-core.sh`. Plus a positive case: a `.review-join.<unit>`
   stamp whose first line carries `unit=gh#348` is parsed with the `#`
   intact by `review_join_state` and is **not** discarded by the traversal
   guard at `:265-271`.
7. `bash tests/state-access-constraints.test.sh`,
   `bash tests/state-access-capability-regression.test.sh`,
   `bash tests/state-access-concurrency.test.sh` exit 0.
8. CC1, CC3.

---

## Step 6 — M6: lifecycle state files in the protected set

**Decided (OQ3 → option (a), 2026-09-09): branch split.** The three patterns
with no existing escape route go into Set A (Write/Edit **and** Bash); the
three with a documented `defer:`/`skip:`/`override:` route go into Set B
(Write/Edit only), preserving the escape hatch.

**Affected files**
- `hooks/scripts/harness-integrity-gate.sh`
- `tests/harness-integrity-gate.test.sh` (incl. the family table)
- `.claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md`
  (CC6 parity)
- `CONTEXT.md` Set A / Set B entry (CC8)
- CC1 artifacts

**What to build**

Add prefix literals for the six lifecycle files, split by branch according to
whether a *documented, gate-recommended* agent-write route exists:

- **Set A** (denied on Write/Edit **and** Bash) — no sanctioned agent-write
  route exists: `.claude/.session-baseline.`, `.claude/.review-join.`,
  `.claude/.microworld-results-reported`.
- **Set B** (denied on Write/Edit **only**) — a sanctioned Bash escape is
  documented and must keep working:
  `.claude/.pending-review.`, `.claude/.config-drift-override.`,
  `.claude/.dispatch-override`.

Implementation notes:
- These are **prefix** literals, not whole-path literals. Add them to
  `set_a_mentioned`'s three substring arms (raw, quote/backslash-stripped,
  normalized-chunk). Do **not** add them to the `for lit ... [[ "$lit" == $g ]]`
  glob-match fallback, whose contract is whole-path equality; record that as a
  new family-table row `state-file-glob:residual` (CC6) rather than as a
  silent gap.
- The Write/Edit branch's `case` takes glob patterns naturally
  (`.claude/.session-baseline.*`), matching the existing `case` structure.
- Set B stays absent from the Bash branch. That asymmetry is ADR-0025 and has
  its own mutation control; do not "fix" it.

**Acceptance criteria**
1. **Bypass reproduction, now denied.** A `Bash` payload
   `printf 'deadbeef' > .claude/.session-baseline.abc` exits **2**; the same
   via `Write` with that `file_path` exits **2**. Both are allowed pre-fix.
   Repeat for `.claude/.review-join.u1` and
   `.claude/.microworld-results-reported`.
2. **Baseline-rewrite attack, end-to-end.** A fixture that rewrites
   `.session-baseline.<sid>` to the current HEAD (which would suppress the
   `moved` and config-drift checks in `lib/stop-gate-core.sh:551-570`) is
   denied at the gate.
3. **The three sanctioned escapes still work.** All exit **0**:
   `printf 'defer: waiting on X\n' > .claude/.pending-review.agent_1`;
   `printf 'skip: abandoned\n' > .claude/.config-drift-override.agent_1`;
   `printf 'override: one-off\n' > .claude/.dispatch-override`.
   *This criterion is the whole point of the branch split — it must be a
   named test case, not an assumption.*
4. **Set B half denies the Write/Edit route for those same three.** A `Write`
   with `file_path = ".claude/.pending-review.agent_1"` exits **2**.
5. **No over-block on prose.** A `Bash` command mentioning
   `.claude/.review-join.` inside an allowlisted read (`grep -rn review-join
   .claude/`) still exits 0 via the benign-command path.
6. **Hot path unchanged.** `bash tests/hook-latency-budget.test.sh` exits 0.
7. CC6 (family-table row + memory-note parity, both directions, no unbounded
   phrasing), CC8, CC1, CC3.
8. `bash tests/harness-integrity-gate.test.sh` and
   `bash tests/harness-config-drift.test.sh` exit 0.

---

## Step 7 — M7: extend Set B to the gate libraries and the installed mirror

**MUST LAND LAST.** See Sequencing.

**Decided (OQ4 → option (a), 2026-09-09): apply in full, sequenced last.**
The self-referential lock on `lib/benign-command.sh` (Set B blocks
`Write`/`Edit`; its own text spells `.claude//reviewed`, so a whole-file
heredoc rewrite is additionally blocked by `reviewed-path-gate.sh`) is
accepted, on the double-gating precedent `harness-integrity-gate.sh` already
establishes. Later maintenance of that file uses surgical Bash edits whose
command text avoids lines 207-209's literals (CC9).

**Affected files**
- `hooks/scripts/harness-integrity-gate.sh` (Set B only)
- `tests/harness-integrity-gate.test.sh`
- `CONTEXT.md` Set A / Set B entry (CC8)
- `docs/trust-model.md` if a row's "checked by" changes (CC5)
- CC1 artifacts

**What to build**

Extend **Set B** (Write/Edit-only deny) with:
`hooks/scripts/lib/*`, the `.claude/hooks/scripts/**` glob, and
`.claude/settings.local.json`. Set B remains absent from the Bash branch.

The Write/Edit branch matches after `normalize_path` + project-dir strip;
express the two new entries as `case` glob patterns
(`hooks/scripts/lib/*`, `.claude/hooks/scripts/*`), consistent with m1's
suffix-matching change if Step 10 has landed.

**Acceptance criteria**
1. **Bypass reproduction, now denied.** `Write`/`Edit` payloads with
   `file_path` = `hooks/scripts/lib/benign-command.sh`,
   `hooks/scripts/lib/stop-gate-core.sh`,
   `.claude/hooks/scripts/reviewed-path-gate.sh`,
   `.claude/hooks/scripts/lib/agent-identity.sh`, and
   `.claude/settings.local.json` each exit **2** with the Set B message. All
   exit 0 pre-fix.
2. **Absolute paths too.** The same five with a `$CLAUDE_PROJECT_DIR`-prefixed
   absolute path exit 2.
3. **Set B stays off the Bash branch.** `cat > hooks/scripts/lib/foo.sh <<'EOF'`
   is **not** denied by *this* gate (it may be denied by another). The
   existing asymmetry mutation control must still pass — assert it explicitly.
4. **The regeneration path is unaffected.** `node bin/cli.js --update
   --force-render` still rewrites `.claude/hooks/scripts/**` (it writes via
   node, not via the `Write` tool). Demonstrated by CC1 passing on this
   step's own commit.
5. **No over-block on non-lib hook scripts.** A `Write` to
   `hooks/scripts/reviewer-tier.sh` still exits 0 (it is not in Set A or
   Set B, before or after this step).
6. `bash tests/harness-integrity-gate.test.sh` exits 0.
7. CC5, CC8, CC1, CC3.

---

## Step 8 — M8: `mentions_marker_dir` obfuscation hardening

**Decided (2026-09-09).** OQ1 → option (a): the substitution-reordering half
is **dropped**, and command substitution is documented and pinned as a
residual in the same ratified class as the existing shell-variable and
`cd`-relative residuals. OQ2 → option (a): port the backslash strip **and**
the brace collapse **plus** a two-segment glob-match arm, accepting that this
also closes the `F-1` glob-metacharacter residuals and reclassifies their
pins.

**Affected files**
- `hooks/scripts/reviewed-path-gate.sh` (`mentions_marker_dir`, and the
  header's STILL-OPEN enumeration at `:33-41`)
- `tests/reviewed-path-gate.test.sh` (residual pins, CC7)
- CC1 artifacts

**What to build**

1. **Backslash strip.** Add `rest="${rest//\\/}"` alongside the existing quote
   strips at `:96`, mirroring `set_a_mentioned:108` byte-for-byte.
2. **Brace collapse + glob-match arm.** In the per-chunk fallback, after the
   existing `normalize_path` substring test, add: re-anchor at the chunk's
   first `.claude` (`g=".claude${norm#*.claude}"`), collapse `{...}` groups to
   `*` innermost-first to a fixpoint using the sentinel-delimited block
   copied verbatim from `harness-integrity-gate.sh:157-162`, truncate `g` to
   its first two `/`-separated segments, then `[[ ".claude/reviewed" == $g2 ]]`
   → mention. The two-segment truncation is what adapts the sibling's
   whole-path matching to this gate's directory-prefix problem.
3. **Header honesty.** Update the STILL-OPEN enumeration at `:33-41` to move
   backslash escapes and glob metacharacters from "still open" to closed, and
   to keep shell variables, `$'...'` quoting, `cd`-relative writes, and
   command substitution as the remaining residuals.

**Acceptance criteria**
1. **Bypass reproduction, now denied — backslash family.** These two,
   currently pinned as `allowed` (tracked open) at the end of
   `tests/reviewed-path-gate.test.sh`, must flip to **blocked** for
   `lead-programmer`, and their pins must be re-classified (CC7):
   `printf x > .cl\aude/reviewed/9.pass` and
   `printf x > .claude/re\viewed/9.pass`.
2. **Bypass reproduction, now denied — glob family.** These three, currently
   pinned as `allowed`, flip to **blocked** and their pins re-classify:
   `printf x > .claude/revie[w]ed/9.pass`,
   `printf x > .claude/?eviewed/9.pass`,
   `printf x > .claude/revi*/9.pass`.
3. **Brace family.** `printf x > .claude/{reviewed,agents}/9.pass` and a
   nested `printf x > .claude/{revi{ewed,x},agents}/9.pass` are both blocked,
   and a 200-deep nesting completes within 5s (mirroring the sibling suite's
   fixpoint-termination property test).
4. **Real-write control for every new deny.** For each command in (1)-(3),
   the suite's existing `mutates_marker` control must confirm real bash
   actually alters the marker directory — a deny with no real write is
   vacuous.
5. **Residuals stay pinned and stay honest.** The remaining tracked-open
   pins — shell-variable split (case 19), `$'...'`, `cd`-relative, and command
   substitution (newly pinned, per the OQ1 decision) — remain asserted as
   `allowed`, and the
   header's enumeration matches the pin list exactly. Assert the
   correspondence mechanically (every residual named in the header has a pin,
   and vice versa).
6. **No read/prose regression.** All ten read/prose/comment shapes in the
   existing "case 38 allow" block still exit 0, and the `raw-disjunct binder`
   case (`rm -rf <marker>/../x` blocked) and the `transit spelling` case still
   hold their current verdicts.
7. **Both mutation controls still pass.** The suite's two documented
   site-mutation controls (site 1: the Bash-path early exit; site 2:
   `write_with_commented_mention`) must each still produce exit 1 with case
   38.1 reading rc=0.
8. **Hot path.** `bash tests/hook-latency-budget.test.sh` exits 0.
9. `bash tests/reviewed-path-gate.test.sh` and
   `bash tests/reviewed-dir-leak-guard.test.sh` exit 0.
10. CC7, CC1, CC3.

---

## Step 9 — M9: main-session `Stop` blocks on an unresolved escalation

**Affected files**
- `hooks/scripts/lib/stop-gate-core.sh` (new `Stop` branch)
- `tests/stop-gate-escalated.test.sh`
- `agents/orchestrator.md` (`:184-185`, plus the resolution list)
- `.claude-plugin/plugin.json` + `CHANGELOG.md` (CC4, because a persona file
  changes)
- `docs/trust-model.md` + `tests/trust-model-bijection.test.js` (CC5 — this
  step converts a self-reported claim into a mechanical check)
- CC1 artifacts

**What to build**

Add a `Stop`-event branch keyed on the **marker**, not on the pending-review
flag, and evaluated independently of the flag branch at `:459-504` (so a
`skip:` deletion or another unit's clearing cannot drop it):

for each `${dot}/reviewed/*.escalated`, the unit is **unresolved** unless at
least one of these holds —
- (a) the human's decision file exists for that unit under
  `${dot}/human-review/<unit>/` (the file `human-decision-gate.sh` protects);
- (b) `${dot}/reviewed/<unit>.directed` exists;
- (c) `${dot}/reviewed/<unit>.pass` or `<unit>.fail` exists with mtime
  strictly newer than the `.escalated` marker.

If any unit is unresolved, `block` with a message naming each unresolved unit,
its packet path, and the three resolutions. Otherwise fall through unchanged.

The three-way resolution test is what prevents a deadlock: (a) is the normal
route, (b) covers the "fixable a specific way" outcome
`agents/orchestrator.md` already documents, and (c) covers a re-review that
supersedes the escalation. Requiring (a) alone would re-block permanently
once the packet directory is discarded with the documented
`rm -rf` route.

Update `agents/orchestrator.md:184-185` so the prose states what is now
enforced, and add the three resolutions to the escalation section.

**Acceptance criteria**
1. **Bypass reproduction, now blocked.** Fixture: one `<u>.escalated` marker,
   no decision file, no `.directed`, no newer verdict, and **no**
   pending-review flag at all. Main-session `Stop` exits **2**. Pre-fix it
   exits 0.
2. **`skip:` no longer drops the block.** Fixture: one `<u>.escalated` plus a
   `.pending-review.<id>` containing `skip: abandoned`. Post-fix, `Stop`
   exits **2** (the flag is still deleted and logged; the escalation block is
   independent). Pre-fix it exits 0.
3. **Another unit's clearing no longer drops the block.** Fixture: two units,
   one escalated and one whose reviewer cleared its flag → `Stop` exits 2.
4. **Each resolution un-blocks.** Three separate fixtures, one per
   resolution (a)/(b)/(c), each making `Stop` exit **0**. The (c) fixture must
   assert the *strictly newer* requirement by also testing an older marker,
   which must still block.
5. **Inert without a reviewer.** A project with no `.escalated` marker exits
   0 on `Stop` with no new audit noise; a `personaSelection` with no reviewer
   never produces the marker in the first place (P4).
6. **SubagentStop behaviour unchanged.** The existing reviewer-side
   `flags-kept` behaviour at `:364-372` and its gh425 scoping are untouched —
   `bash tests/stop-gate-escalated.test.sh` and
   `bash tests/review-join.test.sh` exit 0.
7. **Doc/code agreement.** `agents/orchestrator.md`'s escalation paragraph
   names all three resolutions and the block; assert by grepping the doc for
   each of the three, so the prose cannot silently drift from the branch.
8. `bash tests/stop-gate-blocked.test.sh`,
   `bash tests/human-review-cleanup.test.sh`,
   `bash tests/adapter-stop-gate-parity.test.sh` exit 0.
9. `node tests/protocol-cross-references.test.js` and
   `node tests/protocol-doc-drift.test.js` exit 0.
10. CC1, CC3, CC4, CC5.

---

## Step 10 — m1 + m2: path normalization and case-folding

One unit: both change *how a path is matched* in the same three gates, and
splitting them would have Step 10a's new family-table rows immediately
rewritten by Step 10b.

**Affected files**
- `hooks/scripts/lib/protected-paths-core.sh` (`:20-37`) — m1
- `hooks/scripts/harness-integrity-gate.sh` (`:78-88`, `:105`) — m1, m2
- `hooks/scripts/reviewed-path-gate.sh` (`:95`) — m2
- `hooks/scripts/human-decision-gate.sh` (`:338-345`) — m2
- `tests/protected-paths-gate.test.sh`,
  `tests/protected-paths-coverage.test.js`,
  `tests/harness-integrity-gate.test.sh`,
  `tests/reviewed-path-gate.test.sh`, `tests/human-decision-gate.test.sh`
- CC1 artifacts (`protected-paths-core.sh` is SHARED)

**What to build**

**m1 (a) — normalization in protected-paths.** Apply `normalize_path` to
`rel_path` before the pattern `case` at `lib/protected-paths-core.sh:30`.
`normalize_path` lives in `lib/benign-command.sh`, which is CLAUDE-ONLY and
is **not** available to the codex/cursor copies of `protected-paths-core.sh`.
Do not add a cross-lib source. Instead, add a self-contained
`normalize_path`-equivalent to `lib/state-access.sh` (already SHARED) or
inline the lexical resolver in `protected-paths-core.sh` itself; whichever is
chosen, `bash -n` must pass for all three copies and
`tests/adapter-*` parity must hold. *(This constraint is a spec-time finding —
the audit's one-line fix is not portable as written.)*

**m1 (b) — suffix matching for Set A/B.** In `harness-integrity-gate.sh`'s
Write/Edit branch (`:78-88`), match Set A and Set B as a **path suffix**
(mirroring `reviewed-path-gate.sh`'s substring approach) rather than requiring
an exact match after the `CLAUDE_PROJECT_DIR` prefix strip. Anchor the suffix
at a `/` boundary so `xx.claude/settings.json` does not match
`.claude/settings.json` — a bare substring test would over-match.

**m2 — case-folding.** In all three gates, add a **lowercased disjunct
evaluated only after the existing raw arms miss**. Never replace a raw arm,
and never lowercase before the cheap prefilter — see the Clarifications entry
on hot-path cost. Both sides are lowered (`${var,,}` and lowercase literals).
For `human-decision-gate.sh` this means the `*human-review*` and `*DECISION*`
arms at `:338-345` gain lowercase twins.

**Acceptance criteria**
1. **m1(a) reproduction.** With a `protectedPaths` pattern `hooks/*`, all of
   `hooks//x.sh`, `hooks/./x.sh`, `hooks/lib/../x.sh` are blocked. Pre-fix
   they pass.
2. **m1(a) no over-block.** `hooks/lib/x.sh` under pattern `hooks/*` behaves
   exactly as today (the `case` glob semantics are unchanged);
   `notahook/x.sh` is not blocked.
3. **m1(b) reproduction.** A `Write` whose `file_path` is
   `/some/other/root/.claude/settings.json` (not under
   `CLAUDE_PROJECT_DIR`, so the prefix strip does not apply) is denied
   post-fix. **Note** this deliberately closes the `foreign-claude-dir`
   family, currently a declared **over-block** row in the family table —
   re-classify that row (CC6) rather than leaving it stale.
4. **m1(b) boundary.** `xx.claude/settings.json` and
   `my.claude/settings.json` are **not** denied (the `/`-anchored suffix, not
   a bare substring).
5. **m2 reproduction, three gates.** Each denied post-fix, allowed pre-fix:
   `printf x > .CLAUDE/Reviewed/9.pass` (reviewed-path-gate);
   `printf x > .Claude/Persona-Config.json` (harness-integrity-gate);
   a `Write` to `.claude/Human-Review/u1/decision` (human-decision-gate).
6. **m2 zero new false positives.** Run the human-decision-gate suite's
   existing differential command sweep (the ~420-command corpus its prose-FP
   work established). The count of newly-denied commands in that corpus must
   be **0**. A single new FP is a FAIL, not a note (R8).
7. **m2 hot path.** `bash tests/hook-latency-budget.test.sh` exits 0, and the
   suite's large-command timing pins do not regress.
8. `bash tests/protected-paths-gate.test.sh`,
   `node tests/protected-paths-coverage.test.js`,
   `bash tests/harness-integrity-gate.test.sh`,
   `bash tests/reviewed-path-gate.test.sh`,
   `bash tests/human-decision-gate.test.sh` all exit 0.
9. CC6 (new/re-classified family rows for `case-variant` and
   `foreign-claude-dir`, memory-note parity, no unbounded phrasing), CC7,
   CC1, CC3.

---

## Step 11 — m3: reviewer-tier derives its own commit range

**Affected files**
- `hooks/scripts/reviewer-tier.sh` (`:80-89`)
- `tests/reviewer-tier.test.sh`

**What to build**

Derive a range internally from the session baseline instead of trusting only
the caller's: glob `${dot}/.session-baseline.*`; if **exactly one** exists and
its content is a resolvable sha, the derived range is `<sha>..HEAD`.

Combine, do not choose: measure **both** the caller-supplied range and the
derived range through the existing `files`/`lines`/sensitive-path pipeline and
take the **fail-closed maximum** — if either range is unmeasurable, touches a
sensitive path, or exceeds a size cap, print `opus`. Zero or multiple baseline
files means the derived range is unavailable; that alone does not force
`opus` (the caller-supplied range is still measured), but it is logged.

Log the actually-measured ranges via `audit_append` to
`.claude/review-audit.log`: `reviewer-tier ranges=<arg-range>,<derived-range>
files=<n> lines=<n>`. `stdout` must still be exactly `sonnet` or `opus` —
that contract is pinned by the existing suite.

**Acceptance criteria**
1. **Reproduction.** Fixture: a caller-supplied range covering one 5-line
   non-sensitive commit, while the session baseline reveals a *wider* range
   that also touches `hooks/`. Post-fix the script prints `opus`; pre-fix it
   prints `sonnet`.
2. **Inverse.** A derived range that is small and non-sensitive while the
   caller-supplied one is oversized still prints `opus` (fail-closed maximum
   in both directions).
3. **Baseline unavailable.** Zero baseline files, or two, or one holding a
   non-sha: behaviour is exactly today's (measured from the argument alone),
   and an audit line records the derived range as unavailable.
4. **Contract preserved.** `stdout` is exactly `sonnet\n` or `opus\n` in
   every case, exit 0. Assert byte-exactly.
5. **Audit line.** `.claude/review-audit.log` gains exactly one
   `reviewer-tier ` line per invocation, naming both ranges.
6. `bash tests/reviewer-tier.test.sh` exits 0.
7. CC1, CC3.

---

## Step 12 — m4: hook ordering

**Affected files**
- `hooks/hooks.json` (the `Agent` matcher array)
- `tests/dispatch-hygiene.test.sh` or `tests/review-join.test.sh` (ordering
  assertion), plus `tests/cli-hook-propagation.test.js` if it pins order
- CC1 artifacts

**What to build**

Swap the two entries under the `PreToolUse` `Agent` matcher so
`dispatch-hygiene.sh` runs **before** `reviewer-route-gate.sh`, so a hygiene
denial cannot leave an orphaned, never-satisfiable review-join stamp written
by the route gate at `lib/reviewer-route-gate-core.sh:109-112`.

`hooks/hooks.json` is a Set B literal — edit it via a surgical Bash edit
(CC9), not `Write`/`Edit`.
The codex/cursor `hooks/hooks.json` files register no `dispatch-hygiene.sh`
and need no change.

**Acceptance criteria**
1. **Order assertion.** A test asserts that in `hooks/hooks.json`, within the
   `PreToolUse` entry whose `matcher` is `Agent`, the index of
   `dispatch-hygiene.sh` is **less than** the index of
   `reviewer-route-gate.sh`. Parsed with `jq`, not grepped.
2. **Mirror parity.** The same assertion holds for
   `.claude/settings.json`'s equivalent registration if it carries one;
   otherwise assert explicitly that it does not.
3. **Orphan reproduction.** A dispatch that `dispatch-hygiene.sh` denies (e.g.
   an H4 contract violation on a gated target) leaves **no**
   `${dot}/.review-join.<unit>` stamp behind. Pre-fix a stamp exists.
   Exercised by invoking the two hooks in the registered order against one
   payload.
4. `bash tests/dispatch-hygiene.test.sh`,
   `bash tests/review-join.test.sh`,
   `node tests/cli-hook-propagation.test.js` exit 0.
5. `jq -e . hooks/hooks.json` exits 0.
6. CC1, CC3.

---

## Step 13 — m5: delete the expired grace period, add a task-gate test file

**Affected files**
- `hooks/scripts/task-gate.sh` (`:30-35` constant, `:79-86`
  `warn_and_allow_legacy`, `:94-99` branch, `:74` reject-message line, and the
  header paragraph at `:14-22` that describes the grace period)
- new `tests/task-gate.test.sh`
- `tests/validate.sh` (register the new suite)
- `CHANGELOG.md` (the `gh355` note records a live CHANGELOG-vs-code
  contradiction at `CHANGELOG.md:13`; correct it here)
- CC1 artifacts (including the `.claude/hooks/scripts/task-gate.sh` mirror,
  which the `gh355` note names explicitly)

**What to build**

Delete `GRACE_PERIOD_END`, `warn_and_allow_legacy()`, the `today <
GRACE_PERIOD_END` branch, and the grace-period sentence in `reject()`. A
missing/invalid marker now always rejects. Trim the header comment to describe
the shipped behaviour.

Create `tests/task-gate.test.sh` covering the gate's core behaviour, and
register it in `tests/validate.sh` in the same style as the neighbouring
suites.

**Acceptance criteria**
1. **Dead code gone.** `git grep -c GRACE_PERIOD_END -- hooks/ .claude/hooks/`
   returns 0, and `git grep -c warn_and_allow_legacy -- hooks/ .claude/hooks/`
   returns 0.
2. **New suite exists and is registered.** `bash tests/task-gate.test.sh`
   exits 0, and `tests/validate.sh` invokes it (assert by grep in
   `validate.sh`, and by the suite name appearing in `bash tests/validate.sh`
   output).
3. **Coverage — the suite must include all of:** a non-`impl:` task passes
   ungated; an `impl:` task with a format-valid v3 `.pass` marker is accepted
   and appends a `marker-accepted` audit line; an `impl:` task with a
   zero-byte marker is rejected (exit 2); an `impl:` task with a marker whose
   first line is malformed is rejected; an `impl:` task with **no** marker is
   rejected; an `impl:` task with an empty `task.id` exits 0; and the
   harness-disarmed precondition exits 2 on a tampered fixture.
4. **Date-independence.** The rejection cases pass with `TZ`/`date` shimmed to
   a date *before* the old `2026-07-27` cutoff — proving the branch is gone
   rather than merely unreachable today. This is the criterion that would fail
   pre-fix.
5. **CHANGELOG contradiction closed.** `CHANGELOG.md:13`'s claim about the
   grace-period constant is corrected to describe history, not current
   behaviour.
6. CC1, CC3.

---

## Step 14 — m6: per-segment `jq` for `harness-integrity-gate.sh`

**Affected files**
- `hooks/scripts/lib/benign-command.sh` (`program_allowed`)
- `hooks/scripts/harness-integrity-gate.sh` (`is_benign_jq_read` → per-segment)
- `tests/harness-integrity-gate.test.sh`, `tests/reviewed-path-gate.test.sh`,
  `tests/human-decision-gate.test.sh`
- CC1 artifacts (`benign-command.sh` is CLAUDE-ONLY; no adapter copy)

**What to build**

Add an opt-in extension point to `program_allowed`: a global
`BENIGN_EXTRA_PROGRAMS` (default empty, space-separated) consulted after the
existing `case`. `harness-integrity-gate.sh` sets
`BENIGN_EXTRA_PROGRAMS="jq"` before calling `command_is_provably_benign`, and
its bespoke whole-command `is_benign_jq_read` is removed. The other two gates
never set it, so their behaviour is bit-identical.

This keeps every existing safety property: the `$(`/backtick/`<(` rejection,
the `>` scan over the skeleton (with only the two inert redirection forms
masked), the `eval|exec|source` scan, and the per-segment allowlist all still
apply — `jq` becomes an allowed *program*, not an allowed *command shape*.

**Acceptance criteria**
1. **Reproduction — the exact probe denied during this spec session.**
   `jq -r '.protectedPaths[]? | .pattern? // .' .claude/persona-config.json | head -40`
   exits **0** post-fix. It exits 2 pre-fix (measured live, 2026-09-09).
2. **Multi-segment reads.** `jq -r .gatedAgents .claude/persona-config.json &&
   echo done` and `cat .claude/persona-config.json | jq .` both exit 0.
3. **Writes still denied.** All exit **2**:
   `jq . .claude/persona-config.json > /tmp/x`;
   `jq . .claude/persona-config.json >> .claude/persona-config.json`;
   `jq . .claude/persona-config.json && rm -rf .claude/persona-config.json`;
   `jq -n '1' && printf x > .claude/review-audit.log`;
   `eval "jq . .claude/persona-config.json"`;
   `jq . "$(echo .claude/persona-config.json)"`.
4. **`jq` writing through its own surface.** `jq --rawfile f
   .claude/persona-config.json ...` with any redirection is denied; a bare
   `jq` with no redirection is allowed. (`jq` cannot write without a
   redirection; the criterion pins that the `>` scan is what enforces it.)
5. **No leakage to the other two gates.** `jq . .claude/reviewed/u1.pass`
   from `lead-programmer` is still denied by `reviewed-path-gate.sh`, and a
   `jq` command mentioning the human-review decision path is still denied by
   `human-decision-gate.sh`. Assert both explicitly — this is the criterion
   that catches an accidental widening of the shared allowlist.
6. `bash tests/harness-integrity-gate.test.sh`,
   `bash tests/reviewed-path-gate.test.sh`,
   `bash tests/human-decision-gate.test.sh` exit 0.
7. CC6 if any family-table row changes; CC1, CC3.

---

## Step 15 — m7: `human-decision-gate.sh` fails closed on an empty `file_path`

**Affected files**
- `hooks/scripts/human-decision-gate.sh` (`:311-323`)
- `tests/human-decision-gate.test.sh`
- CC1 artifacts

**What to build**

On the Write/Edit path, if `has_path` is true but `file_path` is empty, call
`deny` (exit 2) before `normalize_path`, matching
`reviewed-path-gate.sh:210-216` and `harness-integrity-gate.sh:73-77`. The
`deny` message should name the empty-target reason, as the two sibling gates
do. A payload with **no** `file_path` key at all still exits 0 — that
distinction is deliberate in all three gates and must be preserved.

**Acceptance criteria**
1. **Reproduction.** A Write payload with `tool_input.file_path = ""` exits
   **2** post-fix, **0** pre-fix. Same for a `file_path` of `null`
   (`// "" | tostring` renders it empty).
2. **Key-absent distinction preserved.** A payload whose `tool_input` has no
   `file_path` key (e.g. `notebook_path`) still exits **0**.
3. **Unreadable payload preserved.** A payload `jq` cannot parse still
   exits **0** (the `|| exit 0` precondition is unchanged).
4. **Three-gate consistency.** The same empty-`file_path` payload exits 2 from
   all three of `reviewed-path-gate.sh`, `harness-integrity-gate.sh` and
   `human-decision-gate.sh`. Assert as one table-driven case, so the doctrine
   ("a write whose target cannot be established fails closed") is enforced
   rather than asserted in prose.
5. `bash tests/human-decision-gate.test.sh` exits 0.
6. `bash tests/refusal-disclosure.test.sh` exits 0 (a new denial message is
   being added; that suite governs what denial text may disclose).
7. CC1, CC3.

---

## Resolved decisions (formerly Open Questions)

All four were answered by the human on **2026-09-09**, each taking the
recommended option. The questions are preserved verbatim below so the
reasoning behind each decision survives; the **Decision** line under each is
what governs, and Steps 6, 7 and 8 already state the decided design.

> **Decision summary (2026-09-09):**
> **OQ1 → (a)** drop the substitution half, pin it as a residual.
> **OQ2 → (a)** port the collapse plus the two-segment glob-match arm,
> accepting the `F-1` reclassification.
> **OQ3 → (a)** branch split — three into Set A, three into Set B.
> **OQ4 → (a)** apply M7 in full, sequenced last, accepting the double-gating
> precedent.

**OQ1 (from CHK12) — M8, substitution rejection.** Moving the `$(`/backtick/`<(`
rejection ahead of `reviewed-path-gate.sh`'s early exit, as the finding
describes, denies **every** command containing a substitution from every
non-reviewer identity — the fall-through path has no allow branch for such a
command, so `git commit -m "$(cat msg)"` and this repo's own test invocations
would all be blocked. Which do you want?
- **(a) RECOMMENDED — drop the substitution half.** Implement only the
  backslash/brace hardening; record command substitution as a documented
  residual in the same ratified class as the shell-variable and
  `cd`-relative residuals the gate's header already names
  (`reviewed-path-gate.sh:33-41`), with its own tracked-open pin. Rationale:
  a substituted path is resolved by bash from text the command does not
  state, which the gate's own header already declares unclosable by any text
  scan.
- **(b) Scope it — substitution + a partial mention.** Bypass the early exit
  only when the command contains a substitution **and** contains `.claude`
  after quote/backslash stripping. Closes `rm -rf ".claude/$(echo
  reviewed)"`, but blocks ordinary commands like
  `CLAUDE_PROJECT_DIR=$(pwd) .claude/hooks/scripts/x.sh`.
- **(c) As literally described.** Reject all substitutions past the early
  exit. Not recommended; measured blast radius above.

**Decision (2026-09-09): (a).** Drop the substitution half; document and pin
command substitution as a residual in the same ratified class as the existing
shell-variable and `cd`-relative residuals. Governs Step 8.

**OQ2 (from CHK13) — M8, brace collapse.** `set_a_mentioned`'s brace collapse is
meaningful only because it feeds a glob match against *whole-path* literals;
`mentions_marker_dir` tests a substring for a *directory prefix*, so
collapsing braces alone changes no verdict. Porting it usefully requires
adding a glob-match arm, which as a side effect also closes the `F-1`
glob-metacharacter residuals (`[w]`, `?`, `*`) currently pinned as tracked
open.
- **(a) RECOMMENDED — port the collapse plus a two-segment glob-match arm**,
  accepting that `F-1` closes as a consequence and re-classifying its pins.
  This is the faithful port and it makes the brace half non-vacuous.
- **(b) Backslash strip only.** Skip the brace half entirely; record it as
  not portable. Smallest diff, but leaves `{reviewed,agents}` open.

**Decision (2026-09-09): (a).** Port the brace collapse **and** add the
two-segment glob-match arm, accepting the `F-1` glob-metacharacter residual
reclassification as a side effect. Governs Step 8.

**OQ3 (from CHK14) — M6, three sanctioned escapes.** Three of the six patterns
(`.pending-review.*`, `.config-drift-override.*`, `.dispatch-override`) have
documented, gate-recommended agent-write routes: the `defer:`/`skip:` escape
that `lib/stop-gate-core.sh` itself prints as remediation and that
`templates/persona-protocol.md` names a *sanctioned exit*, and the
`printf 'override: …' > .claude/.dispatch-override` that
`agents/orchestrator.md:111` prescribes. Adding them to Set A removes all
three.
- **(a) RECOMMENDED — branch split.** The three with no sanctioned route go
  into Set A (Write/Edit **and** Bash); the three with one go into Set B
  (Write/Edit only), which is the existing machinery for exactly this
  asymmetry. Closes the "rewritten baseline suppresses the drift check"
  attack the finding actually names, and keeps every documented exit working.
- **(b) All six into Set A**, and additionally build a narrow
  `defer:`/`skip:`/`override:` recognizer (the shape
  `human-decision-gate.sh`'s `is_sanctioned_marker_write` already models) so
  the escapes survive. More code, more surface, same end state.
- **(c) All six into Set A, escapes removed.** Requires a matching edit to
  `templates/persona-protocol.md`, `agents/orchestrator.md` and three gate
  remediation messages. Not recommended — it converts three audited exits
  into deadlocks.

**Decision (2026-09-09): (a).** Branch split — the three patterns with no
existing escape route into Set A (Write/Edit **and** Bash); the three with a
documented `defer:`/`skip:`/`override:` route into Set B (Write/Edit only),
escape hatch preserved. Governs Step 6.

**OQ4 (from CHK15) — M7, gate-library lockout.** Adding `hooks/scripts/lib/*` to Set B
means every future edit to a gate library must be a surgical `Bash` edit;
for `lib/benign-command.sh` specifically, a whole-file heredoc rewrite is
additionally denied by `reviewed-path-gate.sh` because that file's own text
spells `.claude//reviewed` (lines 207-209). There is precedent —
`harness-integrity-gate.sh` has been in exactly this state since Set B
existed and has been maintained this way (`f52bec2`) — but it is a real
ongoing maintenance cost.
- **(a) RECOMMENDED — apply M7 in full, sequenced last.** Accept the cost;
  it matches the existing precedent and the finding's core worry (a single
  Write to a sourced library neuters multiple gates) is exactly about
  `hooks/scripts/lib/*`.
- **(b) Mirror and settings only.** Add `.claude/hooks/scripts/**` and
  `.claude/settings.local.json`; leave `hooks/scripts/lib/*` out and record
  the canonical-library gap as a documented residual. Guts the finding.
- **(c) Apply in full and additionally add `hooks/scripts/lib/*` to
  `protectedPaths`** (currently `[]`), so the block surfaces as
  "requires explicit human approval" rather than an absolute deny. Note this
  is a config change, not a gate change, and `protected-paths.sh` still
  exits 2 — the difference is the message and the audit trail.

**Decision (2026-09-09): (a).** Apply M7 in full, sequenced last, accepting
the double-gating precedent `harness-integrity-gate.sh` already establishes.
`protectedPaths` is **not** modified by this plan. Governs Step 7.

---

## Self-check

- CHK1: Is every one of the 18 findings assigned to exactly one step? — PASS
  (C1→1, C2→2, M1/M2/M3→3, M4→4, M5→5, M6→6, M7→7, M8→8, M9→9, m1/m2→10,
  m3→11, m4→12, m5→13, m6→14, m7→15; 18 findings, 15 steps, no finding in two
  steps).
- CHK2: Does every step have at least one criterion that a machine runs and
  that would FAIL before the fix? — PASS (each step's criterion 1 is a
  reproduction stating both the post-fix and pre-fix verdict).
- CHK3: Is the `.claude/hooks/scripts/` re-sync question the human asked
  answered unambiguously? — PASS (Clarifications entry + CC1: a per-unit
  deliverable, five artifacts, verified as a render fixed point in a pristine
  worktree).
- CHK4: Do Steps 1 and 4 agree about who may hold the `orchestrator`
  identity? — PASS (Step 1 denies forging it at dispatch; Step 4 grants it the
  fallback; R3 states the ordering dependency and Step 4 carries the "do not
  dispatch before Step 1 passes" line).
- CHK5: Do Steps 6, 7 and 10 agree about what is in Set A vs Set B? — PASS
  (Step 6 adds three prefixes to A and three to B, Step 7 adds three globs to
  B only, Step 10 changes only the *matching* of both sets, not membership;
  CC8 makes all three update the same `CONTEXT.md` entry).
- CHK6: Is "the escalation block cannot deadlock" defined with a machine
  check? — PASS (Step 9 criterion 4: three fixtures, one per resolution, each
  asserting exit 0, plus the strictly-newer negative case).
- CHK7: Is the advisory-stamp filename defined precisely enough that it cannot
  clobber a real stamp? — PASS (Step 3: `${dot}/.review-join.<unit>.advisory`,
  with criterion 4 asserting the real stamp is byte-identical afterward).
- CHK8: Is M5's resolution direction (`#` accepted, not rejected) stated with
  its reason? — PASS (Clarifications entry + Step 5's "Direction rationale"
  paragraph).
- CHK9: Does the plan say where M5's helper lives, given `bin/cli.js` throws
  on an undeclared lib file? — PASS (Step 5: `lib/state-access.sh`,
  with the `assertHookLibDeclarationComplete` reason stated).
- CHK10: Is m1's `normalize_path` reachable from `protected-paths-core.sh` in
  all three ports? — **FAIL (missing)** — the audit's one-line fix is not
  portable (`normalize_path` lives in the CLAUDE-ONLY
  `lib/benign-command.sh`). — revised in place (Step 10 now states the
  constraint and the two acceptable resolutions, both testable).
- CHK11: Is m2's hot-path cost bounded? — **FAIL (missing)** — the finding
  says "lowercase both sides" with no placement rule, and a measured note
  records a 195 KB command already costing 74 s. — revised in place
  (Clarifications entry + Step 10's "additional disjunct evaluated only after
  the raw arms miss" rule + criterion 7).
- CHK12: Is M8's substitution half implementable as written? — **FAIL
  (ambiguous)** — measured blast radius is every command containing `$(`. —
  converted to Open Question 1; answered (a) 2026-09-09, folded into Step 8.
- CHK13: Is M8's brace-collapse half non-vacuous as written? — **FAIL
  (ambiguous)** — collapsing braces changes no verdict without a glob-match
  arm. — converted to Open Question 2; answered (a) 2026-09-09, folded into
  Step 8.
- CHK14: Does M6 as written preserve the documented `defer:`/`skip:`/
  `override:` exits? — **FAIL (conflicting)** — it removes three sanctioned
  exits the gates' own remediation text prescribes. — converted to Open
  Question 3; answered (a) 2026-09-09, folded into Step 6.
- CHK15: Does M7 leave a maintainable route to the gate libraries? — **FAIL
  (ambiguous)** — a route exists (surgical Bash edits, with precedent) but the
  cost is unstated and one file is doubly gated. — converted to Open
  Question 4; answered (a) 2026-09-09, folded into Step 7.
- CHK16: Does every step editing `hooks/scripts/**` carry the five-artifact
  rule? — PASS (CC1 is stated once and every step's criteria reference it).
- CHK17: Is the family-table discipline (the 2-FAIL-escalation remedy) carried
  into every step that touches `harness-integrity-gate.sh`'s Bash branch? —
  PASS (CC6; Steps 6, 10, 14 reference it, Step 7 is Write/Edit-only and does
  not).
- CHK18: Does the plan avoid claiming C2 *prevents* `rm -rf .claude`? — PASS
  (Spec-time corrections state explicitly that it closes detection, not
  prevention, and that no step adds such a denial).
- CHK19: Are all six FAIL items above represented in Open Questions or
  revised in place, with no orphans in either direction? — PASS (CHK10/CHK11
  revised in place; CHK12→OQ1, CHK13→OQ2, CHK14→OQ3, CHK15→OQ4; each OQ cites
  its originating CHK, and all four now carry a dated Decision line).
- CHK20: Does any step still describe its design as conditional on an
  unanswered question? — PASS (re-swept after the 2026-09-09 answers: Steps 6,
  7 and 8 state decided designs; the strings "recommended variant" and
  "Blocked on Open Question" no longer appear).

### Re-check, 2026-09-10 (Step 5 correction, issue `#452`)

Scoped to Step 5 and the Sequencing edge. CHK1-CHK20 were **not** re-run;
nothing in this correction touches the steps or cross-cutting requirements
they interrogate. CHK8 and CHK9 (the two existing M5 items) still read PASS
against the corrected text — the `#`-accepted direction and the
`state-access.sh` helper location are unchanged.

- CHK21: Does Step 5 enumerate every site carrying a unit-id grammar, and can
  a reader tell an in-scope site from an out-of-scope one without re-deriving
  it? — **FAIL (missing)** — the original text said "six sites" with no
  enumeration and no domain boundary, so two sites and a whole spelling went
  unnoticed until dispatch — revised in place (the census table and the
  out-of-scope table).
- CHK22: Is Step 5's criterion 2 satisfiable by an implementation that
  follows the rest of Step 5? — **FAIL (conflicting)** — it demanded a count
  of one for a literal that legitimately survives three times in another id
  domain, and named `lib/state-access.sh` as the home of a sanitizer literal
  that the step's own design does not put there — revised in place
  (criterion 2a/2b/2c).
- CHK23: Can criterion 2 be satisfied by an edit that does the opposite of
  the fix? — **FAIL (ambiguous)** — a bare count is reachable by editing an
  `agent_id` line instead of a unit-id line — revised in place (2b asserts
  the assigned-variable name; 2e adds a mutation control on sites 2, 4, 8).
- CHK24: Do Steps 3 and 5 agree about who edits
  `hooks/scripts/lib/stop-gate-core.sh`, and in what order? — **FAIL
  (missing)** — Step 5 did not name the file at all while Sequencing listed
  both steps as independent — revised in place (Step 5's file-conflict note
  and the new Step 3 ──► Step 5 edge). Step 3's own scope, affected files and
  acceptance criteria are unchanged, and were re-read to confirm none of them
  reference the ERE at `:260`.
- CHK25: Does the plan say what happens to `human-decision-gate.sh:76`'s
  *leading-character* class and length bound, as distinct from its tail
  class? — **FAIL (missing)** — "interpolates `UNIT_ID_CHARCLASS` into that
  regex" left the whole-`UNIT_ID_RE` reading open, which silently tightens a
  sanctioned-write allowance — revised in place (Site-specific notes plus
  criterion 5, which pins the before/after verdict as equal).
- CHK26: Is every criterion added by this correction one that a machine runs
  and gets pass/fail from? — PASS (2a-2c are `git grep` invocations with
  expected output stated; 2d names the suite file and the `validate.sh` line
  that runs it; 2e and criteria 5-6 name test files and concrete fixtures).
- CHK27: Are all five FAIL items above represented, with no orphans in either
  direction? — PASS (CHK21-CHK25 each revised in place; this correction opens
  no new Open Question, because every gap was resolvable from measurement
  rather than from information only the human holds).
- CHK28: Does this correction leave the other 14 steps, the Resolved
  decisions section and the Cross-cutting requirements byte-unchanged? — PASS
  (the only edits outside Step 5 are the Clarifications append, the
  category-9 re-score, this Self-check append, and the Sequencing edge — all
  four are explicitly in the correction's remit).

---

## Retrieval contract

**This document is the canonical artifact.** There is no tracked issue for it
yet.

- `task-master` reads `/home/sebas/AntiSlop/docs/plans/2026-09-09-fable-gate-audit-remediation.md`
  and slices Steps 1-15 with `to-tickets` into GitHub issues on
  `Storreslara/AntiSlop` (`gh issue create`), labelled
  `plan/fable-gate-audit-remediation` plus the tracker's default
  `ready-for-agent`.
- Each `lead-programmer` / `reviewer` dispatch fetches its unit with
  `gh issue list --label plan/fable-gate-audit-remediation` and reads full
  detail from **this file's** correspondingly-numbered Step, plus the
  Cross-cutting requirements section, which is not repeated per issue and must
  be quoted into each dispatch packet by reference to its heading.
- 15 units ≥ 6, so this is the standard path. The PRD view was published via
  `to-spec` on 2026-09-09, once Open Questions 1-4 were answered, as
  **`Storreslara/AntiSlop#439`** (`[spec]`, labelled `ready-for-agent`).
  That umbrella issue is a **view**, not the source of truth — where it and
  this file disagree, this file wins, and per-step detail lives only here.

---

## Scribe update hint

After the plan lands, `scribe` should consider:
- `CONTEXT.md` glossary entries for three load-bearing new terms:
  **git-index witness** (C2), **advisory review-join stamp** (M2), **bounded
  flag clearing** (M3).
- Updating the existing **Set A / Set B** entry (`CONTEXT.md:172-181`) —
  membership changes in Steps 6 and 7, matching semantics change in Step 10.
- Updating the **review-join stamp** entry (`CONTEXT.md:517-534`) — Step 3
  changes when a stamp is written and adds a variant.
- Carrying forward the still-open glossary suggestions recorded in prior
  non-blocking notes and not addressed here: "survival pin", "STILL OPEN"
  header convention, "single-/double-quoted span", "skeleton" /
  `command_skeleton`, "trigger token", "quote-joined text", "path-safe
  charclass". Advisory only.
- `CONTEXT.md:373`'s `stop-gate.sh:276,284` line references are stale
  (measured); Step 3 touches that mechanism and is the natural moment to fix
  them.
