# Stale `.blocked` marker jams every reviewer's flag-clearing (gh425)

**Status:** COMPLETE — all four units (gh425-1, gh425-2, gh425-3, gh425-4) plus ancillary unit (protectedpaths-test-fix) reviewer-PASSed as of 2026-09-03. Two follow-on items tracked elsewhere: `state_append_audit_log()` Set-A bypass hole and `protectedPaths` policy decision.
**Author:** spec-master, 2026-09-02
**Dispatch order:** `gh425-2` → `gh425-1` → `gh425-3` → `gh425-4`
(step *numbers* are authoring order; the leak fix ships before the cleanup so
nothing re-plants the strays — see R5)

---

## Goal

Two coupled defects, one symptom:

1. **Scoping defect.** The reviewer's-own-`SubagentStop` branch keeps
   pending-review flags standing whenever *any* `.blocked`/`.escalated` marker
   exists anywhere in `.claude/reviewed/`, regardless of whether that marker
   belongs to a unit the stopping reviewer was dispatched for. One irrelevant
   marker therefore disables flag-clearing project-wide, indefinitely.
2. **Fixture leak.** `tests/marker-write.test.sh` writes its fixtures into the
   **real** `.claude/reviewed/` whenever `CLAUDE_PROJECT_DIR` is set in the
   environment — exactly the condition under which the harness itself runs the
   suite. That leak planted the marker triggering (1).

After this change: an irrelevant `.blocked`/`.escalated` marker no longer blocks
an unrelated reviewer's flag-clearing; a genuine one still does; and the test
suite can no longer write outside its own `mktemp` root.

## Context

### Verified findings (all re-derived independently this session)

**F1 — the early-return is unconditional and unscoped.**
`hooks/scripts/lib/stop-gate-core.sh:326-341`: `blocked_markers=(
"${dot}"/reviewed/*.blocked )` and the `.escalated` equivalent are globbed over
the whole directory; if either is non-empty the branch logs and `allow`s,
returning *before* `review_join_state "$dot"` (line 345) is ever called. The
per-unit scoping information exists but is not consulted until after the point
of no return.

**F2 — exactly one stray marker, and it is a test fixture.**
`.claude/reviewed/unitC.blocked`, 77 bytes, mtime 2026-09-01 23:06 local, first
line `BLOCKED unitC 2026-09-02T04:06:46Z missing: criterion X could not be
reached`. Zero `.escalated` markers exist. `unitC` is not a real unit id; it is
the AC-C4 fixture at `tests/marker-write.test.sh:75`.

**F3 — the leak is environmental, and it leaked four files, not one.**
`hooks/scripts/marker-write.sh:27` sets `dot="${CLAUDE_PROJECT_DIR:-.}/.claude"`
*unconditionally*, overriding both the process cwd and any inherited `dot`.
`tests/marker-write.test.sh` isolates by `cd` only (`run_helper() { ( cd "$proj"
&& "$helper" "$@" ); }`, line 45) and never pins `CLAUDE_PROJECT_DIR` for the
helper — though it does pin it for the *gate* invocations at line 140, the
asymmetry that hid the bug. Reproduced this session: with `CLAUDE_PROJECT_DIR`
pointed at a sandbox, the suite wrote `unitA.pass`, `unitB.fail`,
`unitC.blocked` and `spec2-unitC.pass` into that sandbox's `.claude/reviewed/`
instead of its `mktemp` root — the exact four-name set found in the real
directory, all four sharing the single timestamp `2026-09-02T04:06:46Z`.

**F4 — the leak also destroyed a genuine audit record.** `spec2-unitC` *is* a
real unit (it landed `hooks/scripts/marker-write.sh`). Its genuine reviewer PASS
marker was overwritten by the line-188 fixture and is now 86 bytes reading
`commit: abc123`, against sibling markers of 4752/3095/6716/2468 bytes.
`.claude/reviewed/` is gitignored, so the original content is **unrecoverable**.
`unitB.fail` additionally pollutes the FAIL-record namespace a fresh
`spec-master` consults for prior-defect history.

**F5 — the global glob was deliberate, and its stated justification no longer
holds.** `hooks/scripts/stop-gate.sh:35-47` documents step 0.5: a `.blocked`
marker records an INSUFFICIENT-CONTEXT verdict and must keep flags standing
"until a real PASS/FAIL resolves the unit (the reviewer deletes the `.blocked`
marker then)". `templates/persona-protocol.md` grounds its safety in the
**one-unit-at-a-time invariant** — "there is never a second unit's flag to
confuse with the blocked one". A leaked fixture belonging to *no* unit violates
that invariant's premise without violating the invariant itself, which is
precisely why the global glob fails here. The intent is real and must be
preserved for genuinely-relevant units.

**F6 — nothing ever deletes a `.blocked`/`.escalated` marker automatically.**
`session-start.sh:74-93` only *warns* about orphaned `.escalated` markers whose
human-review packet directory is missing; it deletes nothing, and does not look
at `.blocked` at all. The reviewer is the sole documented resolver
(`reviewed-path-gate.sh:247`, `persona_matches_grant ... reviewer`).

**F7 — the asymmetry ADR-0016 did not anticipate.** ADR-0016 ("No stale-stamp
sweeper and no stamp TTL") justifies leaving leaked *stamps* uncollected because
"an unconsumed stamp is inert: a stop is allowed whenever any stamp is
satisfied, so a leaked stamp can never deadlock a reviewer that did its job."
That reasoning is sound for stamps and **inverts for markers**: a leaked
`.blocked` marker is not inert — it is absorbing. This defect is the missing
half of that ADR's analysis, not a contradiction of it.

**F8 — live confirmation.** `.claude/review-audit.log` records
`2026-09-02T04:25:10Z verdict=blocked flags-kept` with no subsequent
`cleared-by=reviewer`.

### Post-execution findings (added 2026-09-02, after gh425-1/gh425-2 PASSed)

**F9 — this was the SECOND occurrence, and the defect had already been
correctly root-caused once.** `tmp/gh413-gh414-handoff.md:92-105` records the
identical four-file leak firing at **2026-08-31T22:12:03Z**. The human cleaned
it up by hand on 2026-09-01, backing the files up to
`/tmp/reviewed-anomaly-backup-20260901/`. A reviewer dispatched then
root-caused the freeze **precisely**, naming
`hooks/scripts/lib/stop-gate-core.sh:327` and stating the early-exit "is
directory-wide, not per-unit, so one stray `.blocked` file anywhere suppresses
every unit's flag-clear" — concluding it was "a real, still-unfixed defect
(worth its own small unit someday)". That recommendation was never actioned,
and the same failure fired again 30 hours later. **F3's narrative therefore
undercounts the incident: 2026-09-02 is a recurrence, not a first occurrence.**
This is another instance of the pattern in
`feedback_pass_note_warnings_do_not_propagate` — a correct diagnosis recorded
in a side artifact that no later dispatch was obliged to read.

**F10 — measured blast radius of the jam (corrects the relayed figure).** The
clearing event at `2026-09-02T19:46:16Z`, immediately after `unitC.blocked` was
deleted, consumed **eight** review-join stamps in a single
`cleared-by=reviewer`: `gh295-1`, `gh295-1b`, `gh377-4`, `gh377-5`, `gh377-6`,
`gh377-6a`, `gh377-7`, `gh425-2`. Broken down by originating plan:

- **1 of 8** — `gh425-2` — belongs to this plan.
- **2 of 8** — `gh295-1`, `gh295-1b` — belong to the #295 advisory-note-channel
  plan, the units whose review exposed the defect in the first place.
- **5 of 8** — `gh377-4`, `gh377-5`, `gh377-6`, `gh377-6a`, `gh377-7` — belong
  to a third plan with no involvement in the discovery at all. These are the
  ones that had been silently jammed with nobody watching.

So **seven of the eight belong to plans other than gh425**, and five to a plan
nobody was looking at. (Relayed as "three pending-review flags" — both are true
and measure different things: flags are agent-keyed, stamps are unit-keyed. The
stamp count is the one that shows how many *units* were affected, so it is the
figure the ADR should cite.)

*Correction, 2026-09-03:* this finding first read "six of those eight belong to
a completely unrelated plan" while enumerating only five, and seven is the
correct count of non-gh425 units. Caught by the gh425-4 reviewer; it had already
propagated verbatim into ADR-0028, which `scribe` corrected on its side. The
error is instructive: it appeared in the very finding whose purpose was to
correct someone else's count.

**F11 — `spec2-unitC`'s genuine review is independently attested, though its
marker body is not.** `.claude/review-audit.log` retains
`2026-08-27T18:54:38Z marker-commit-check=ok unit=spec2-unitC` and the matching
`join-consumed=spec2-unitC`. So a real review did complete, and its `commit:`
field named a reachable commit belonging to the unit. The marker *body* remains
unrecoverable (R6 stands): the backup at `/tmp/reviewed-anomaly-backup-20260901/`
was taken on 2026-09-01, **after** the 2026-08-31 clobber, and its
`spec2-unitC.pass` is the same 86-byte fixture — **do not spend time attempting
restoration from it.**

**F12 — a cleanup unit has no reachable BLOCKED verdict (shape note).**
gh425-1's own AC2 required zero `.blocked`/`.escalated` markers to remain, so
writing `gh425-1.blocked` would both violate its own criterion and re-create the
exact jam the plan exists to remove. The reviewer reached a genuine PASS
(`commit: none`, correct — the unit touched only the gitignored
`.claude/reviewed/` and made no commit) rather than deadlocking. Recorded
because this "cleanup unit whose success condition forbids its own BLOCKED
marker" shape will recur: any future marker-hygiene unit should either state
`commit: none` as expected up front, or scope AC2 to markers *other than its
own*.

### Existing behaviour that MUST survive (measured, not assumed)

| Case | File | Stamps present | Assertion |
|---|---|---|---|
| (a) | `stop-gate-blocked.test.sh` | **none** | `.blocked` for `task-a` keeps flag + logs `verdict=blocked flags-kept` |
| (u3) | `stop-gate-blocked.test.sh` | 1, **same unit** | `.blocked` for `unit-x` keeps flag, stamp untouched |
| (b) | `stop-gate-blocked.test.sh` | none | no marker -> flag cleared |
| (a) | `stop-gate-escalated.test.sh` | **none** | `.escalated` keeps flag + `verdict=escalated flags-kept` |
| (b) | `stop-gate-escalated.test.sh` | **none** | both markers -> both tokens logged, neither masks the other |
| (e) | `stop-gate-escalated.test.sh` | none | `.directed` alone -> flags CLEARED (deliberate omission) |
| (g) | `stop-gate-escalated.test.sh` | none | codex + cursor ports carry the same branch |

**The decisive observation: every existing flag-keeping case except (u3) has
zero review-join stamps.** A naive "scope to the stamped units" fix clears the
flag in all of them and turns five green assertions red. This is the trap
recorded in `feedback_review_join_null_only_covered_zero_stamp`, inverted: here
the zero-stamp path is the one that must *not* change. Q1 preserves it.

### Hard constraints on how the fix may be written

- **C1.** `tests/stop-gate-escalated.test.sh:119-121` greps for the exact
  literal `escalated_markers=( "${dot}"/reviewed/*.escalated )` expecting
  **exactly one** match (verified: 1 today), then `sed`s
  `^\( *\)escalated_markers=(.*$`. That literal must survive verbatim, exactly
  once, on its own line, in the zero-scope fallback branch.
- **C2.** `tests/state-distinctions-manifest.test.sh:50` (D9) requires the
  substring `blocked_markers=` to remain present in `stop-gate-core.sh`.
- **C3.** `tests/stop-gate-blocked.test.sh` (v) and
  `tests/adapter-stop-gate-parity.test.sh:263` both `grep -cxF` for the exact
  whole line `    review_join_state "$dot"` (four-space indent) expecting
  **exactly 1** (verified: 1 today). The call **moves** under Q2 — so the
  original call site at line 345 must be **deleted**, not duplicated, or the
  count becomes 2 and both mutation controls break.
- **C4.** This is a **five-artifact change**: `hooks/scripts/lib/stop-gate-core.sh`
  plus three byte-identical copies (`.claude/hooks/scripts/lib/`,
  `adapters/codex/...`, `adapters/cursor/...`; all four currently md5
  `528e12c0e5b46743d0eb54e6876c232f`) plus `persona-config.json`'s `fileHashes`.
  Regenerate with `node bin/cli.js --update --force-render` — never plain
  `--update` (fast-path trap), never a hand-edit.
- **C5.** An inline `Bash` reproduction is refused by `reviewed-path-gate.sh`,
  which matches on command *text* rather than resolved target, even for a
  sandbox path. Regression proof must live inside a test script (which the gate
  allows, since `bash tests/foo.sh` does not spell the path). Do **not** reword
  a command to evade the scan — that is a self-authorized bypass.
- **C6.** Bash is 5.2.21 and `set -euo pipefail` is in force; empty-array
  expansion (`"${a[@]}"`) is safe here (verified this session).

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-02 Functional scope & success criteria: Q How far should the leak fix
  go — test-only, or also harden the helper and add a standing guard? → A: all
  three (Q4), per user.
- 2026-09-02 Edge cases / failure handling: Q With zero review-join stamps,
  should a `.blocked`/`.escalated` marker anywhere still keep flags standing? →
  A: yes, preserve today's global behaviour at zero stamps (Q1), per user.
- 2026-09-02 Edge cases / failure handling: Q Should the unit id be read from
  the stamp's `unit=` field or its filename? → A: the `unit=` field, reusing
  `review_join_state()`'s traversal-guarded parse; reorder that call ahead of
  the early-return (Q2), per user.
- 2026-09-02 Edge cases / failure handling: Q What happens when stamps exist but
  **all** are malformed, so the well-formed unit set is empty? → A
  (self-resolved): treat it identically to zero stamps and take the global
  fallback. This follows directly from Q1's stated principle — when there is no
  usable scoping information, preserve today's behaviour rather than rule a
  marker irrelevant. It also collapses the fix to a single condition (**the
  well-formed stamped-unit set is empty**), since `review_join_state` returns
  with both unit arrays empty in both situations.
- 2026-09-02 Completion / acceptance signals: Q Is the corrupted
  `spec2-unitC.pass` part of "done"? → A: yes — the reviewer rewrites it as a
  format-valid marker documenting that the original was destroyed by the leak
  (Q3), per user.
- 2026-09-02 Domain entities / data model: Q Which artifacts are in play and who
  owns each? → A (self-resolved): `.blocked`/`.escalated`/`.pass`/`.fail`
  markers (unit-keyed, reviewer-owned), `.review-join.<unit-id>` stamps
  (unit-keyed, route-gate-written), `.pending-review.<agent-id>` flags
  (agent-keyed). All already defined in CONTEXT.md; no new entity.
- 2026-09-02 User interaction flow: Q Is any human-facing surface affected? → A
  (self-resolved): no. The change is entirely inside a `SubagentStop` hook
  branch; the only observable deltas are audit-log tokens and whether flags clear.
- 2026-09-02 Non-functional attributes: Q Does moving `review_join_state`
  earlier risk the hook latency budget? → A (self-resolved): no. It is a bounded
  loop over `.review-join.*` (7 stamps live today) doing one `head -n1` and up to
  two `stat` calls each; `tests/hook-latency-budget.test.sh` is the standing
  guard and is an acceptance criterion in Step 3.
- 2026-09-02 Technical constraints & tradeoffs: Q What limits how the fix may be
  spelled? → A (self-resolved): constraints C1–C6, each measured against the
  actual test sources this session.
- 2026-09-02 Terminology consistency: Q Does the plan's vocabulary match
  CONTEXT.md? → A (self-resolved): yes — "review-join stamp", "pending-review
  flag", "`.escalated` marker" and the Unit/Agent state domains are used with
  their glossary meanings. One genuinely new concept ("marker relevance
  scoping") has no glossary entry; routed to `scribe` in Step 4, advisory only.

## Risks / dependencies

- **R1 — a wrong fix silently disarms an escalation gate.** If scoping is too
  aggressive, a genuine INSUFFICIENT-CONTEXT or ESCALATE-TO-HUMAN verdict stops
  keeping flags standing and the pipeline proceeds past a unit a human was meant
  to adjudicate. Mitigated by Q1 (zero-scope path unchanged) and by cases
  (a)/(u3)/(b) staying green **unmodified**.
- **R2 — mutation controls are load-bearing and brittle.** C1/C2/C3 are
  literal-text greps. A cosmetically-reasonable refactor turns them red or,
  worse, leaves them green but no longer binding. Step 3 must re-run each and
  confirm it still *fails* against a mutant.
- **R3 — the four copies drift.** Prior FAIL history on exactly this class:
  `gh385-2`, `gh403`, `mw-step3`, `spec2-unitE` (the last being the
  `fileHashes`-only sub-shape). Mitigated by the render-fixed-point criterion.
- **R4 — prior FAIL on the adjacent unit.** `.claude/reviewed/gh295-1b.fail`
  exists; `gh295-1b` is one of the two units whose review exposed this defect.
  Read it before dispatching Step 3. **Step 3 must not be tagged `haiku`.**
- **R5 — re-leak between Step 2 and Step 1.** If the strays are deleted before
  the test is fixed, any harness-invoked `validate.sh` re-plants them. Dispatch
  order is therefore `gh425-2` → `gh425-1`.
- **R6 — `spec2-unitC.pass`'s original content is gone.** No step restores it;
  Q3 decides only how to represent the loss honestly.
- **R7 — the leak has a self-announcing symptom that was missed.** When the leak
  fires, the suite's own assertions go red (they read the `mktemp` path while
  writes went elsewhere). `validate.sh` was failing at 2026-09-02T04:06:46Z and
  that signal reached nobody. Step 2's guard must make the failure name its own
  cause; Step 3's `marker-out-of-scope` token serves the same purpose at runtime.

## Steps

### Step 2 (`gh425-2`) — Stop `tests/marker-write.test.sh` writing outside its `mktemp` root

**Dispatched first.** Actor: `lead-programmer`.

**Affected files:** `tests/marker-write.test.sh`, `hooks/scripts/marker-write.sh`,
`.claude/hooks/scripts/marker-write.sh` (mirror), `tests/validate.sh` (guard
registration), plus a new guard test file.

**Ordered edits:**
1. Pin `CLAUDE_PROJECT_DIR` to the per-case project root on every helper
   invocation — `run_helper()` (line 45), `reject_case()` (line 94) and the real
   invocation at line 188 — mirroring what line 140 already does for gate calls.
2. Harden `hooks/scripts/marker-write.sh:27` to
   `: "${dot:=${CLAUDE_PROJECT_DIR:-.}/.claude}"`, matching `state-access.sh:8`,
   so an explicitly-exported `dot` is respected rather than overwritten.
3. Add a standing guard test asserting the real `.claude/reviewed/` entry list is
   unchanged across a full `validate.sh` run, failing with a message that names
   the leaking suite.

**Acceptance criteria:**
- `CLAUDE_PROJECT_DIR=$(mktemp -d) bash tests/marker-write.test.sh` exits 0 **and**
  leaves that directory with no `.claude/reviewed/` entries. (Today: exits
  non-zero and plants four files — verified this session.)
- `bash tests/marker-write.test.sh` with `CLAUDE_PROJECT_DIR` unset exits 0.
- The guard fails when run against a deliberately reverted copy of edit 1
  (mutation control), and passes against the fixed tree.
- `bash tests/validate.sh` exits 0.

### Step 1 (`gh425-1`) — Remove the leaked fixtures and repair the corrupted marker

**Dispatched second, after `gh425-2` lands.** Actor: **`reviewer` only** — the
sole identity granted write access by `reviewed-path-gate.sh:247`
(`persona_matches_grant ... reviewer`). The orchestrator and lead-programmer are
both refused; this is not delegable.

**Affected files:** `.claude/reviewed/unitA.pass`, `.claude/reviewed/unitB.fail`,
`.claude/reviewed/unitC.blocked`, `.claude/reviewed/spec2-unitC.pass`.

**Ordered edits:**
1. Delete the three pure-fixture markers (`unitA.pass`, `unitB.fail`,
   `unitC.blocked`) — no real unit bears these ids.
2. Rewrite `spec2-unitC.pass` as a format-valid PASS marker whose body states
   that the original reviewer content was destroyed by the 2026-09-02 fixture
   leak and is unrecoverable, citing this plan. Do **not** leave the false
   `commit: abc123` claim standing.
3. Append a one-line reason to `.claude/review-audit.log`.

**Acceptance criteria:**
- `ls .claude/reviewed/unitA.pass .claude/reviewed/unitB.fail
  .claude/reviewed/unitC.blocked` exits non-zero for all three (absent).
- `grep -rl "" --include="*.blocked" --include="*.escalated" .claude/reviewed/`
  prints nothing.
- `spec2-unitC.pass` first line still matches `PASS spec2-unitC ` (format-valid
  per `marker_format_valid`), its body names the leak, and it no longer asserts
  `commit: abc123`.
- The deletion is recorded in `.claude/review-audit.log`.

### Step 3 (`gh425-3`) — Scope the `.blocked`/`.escalated` early-return to the stopping reviewer's own units

**Dispatched third.** Actor: `lead-programmer`. **Not `haiku`** (R4).

**Affected files:** `hooks/scripts/lib/stop-gate-core.sh` + three mirrors;
`.claude/persona-config.json` (`fileHashes`, regenerated only);
`tests/stop-gate-blocked.test.sh`; `tests/stop-gate-escalated.test.sh`.

**Design (settled by Q1/Q2):** move `review_join_state "$dot"` ahead of the
marker check (deleting its original call site — C3), then build the scoped unit
set as the union of `JOIN_SATISFIED_UNITS` and `JOIN_UNSATISFIED_UNITS`:

- **scoped unit set empty** (zero stamps, or every stamp malformed) -> preserve
  today's global glob **verbatim**, including C1's exact literal;
- **non-empty** -> consider only `<unit>.blocked` / `<unit>.escalated` for units
  in that set.

When scoping is active and an out-of-scope `.blocked`/`.escalated` marker is
skipped, log `marker-out-of-scope=<unit>` (one line per skipped marker) so this
class of jam is diagnosable from the audit log rather than by inspection (R7).

**Acceptance criteria:**
- All existing cases in `tests/stop-gate-blocked.test.sh` and
  `tests/stop-gate-escalated.test.sh` pass with their existing assertions
  **unmodified**.
- New case (**the live defect**): stamp for `unit-a` satisfied by a format-valid
  `.pass`, **plus** an unrelated `strayunit.blocked` -> exit 0, flags
  **cleared**, `cleared-by=reviewer` logged, **no** `verdict=blocked flags-kept`
  line, and one `marker-out-of-scope=strayunit` line. Must fail against
  unpatched code.
- New case: same shape with `.escalated`.
- New case (**multi-stamp**, per
  `feedback_review_join_null_only_covered_zero_stamp`): stamps for `unit-a` and
  `unit-b`, `.blocked` for `unit-b` -> flags **kept**, `verdict=blocked
  flags-kept` logged — proving scoping is not merely "ignore everything".
- New case (**all-stamps-malformed**): one stamp whose `unit=` field is absent,
  plus an unrelated `strayunit.blocked` -> flags **kept** (global fallback).
- New mutation control: force the scoped unit set to always be empty; the first
  new case must then revert to keeping the flag.
- C1/C2/C3 re-verified: `grep -cF 'escalated_markers=( "${dot}"/reviewed/*.escalated )'`
  == 1, `grep -cxF '    review_join_state "$dot"'` == 1, `blocked_markers=`
  present; and each existing mutation control still flips behaviour.
- In a pristine detached worktree at the fix commit,
  `node bin/cli.js --update --force-render && git status --porcelain` emits
  **zero lines**.
- `bash tests/validate.sh` and `bash tests/hook-latency-budget.test.sh` exit 0.

### Step 4 (`gh425-4`) — Record the decision

**Dispatched last.** Actor: `scribe`.

**Affected files:** a new ADR (increment from the highest existing number; do
**not** backfill the 0007 hole), `hooks/scripts/stop-gate.sh` step-0.5 header
comment, `templates/persona-protocol.md`'s one-unit-at-a-time sentence,
`CONTEXT.md`, `CHANGELOG.md`.

**Acceptance criteria:**
- The ADR records the F7 asymmetry (leaked stamp inert, leaked marker
  absorbing), the zero-scope fallback, and supersedes/annotates ADR-0016's
  "no stale-stamp sweeper" reasoning rather than contradicting it.
- `hooks/scripts/stop-gate.sh`'s step 0.5 comment describes the scoped
  behaviour; no surviving sentence claims the globs are directory-wide.
- `templates/persona-protocol.md` no longer rests the mechanism's safety solely
  on the one-unit-at-a-time invariant.
- CONTEXT.md gains a glossary entry for marker relevance scoping and the
  `marker-out-of-scope` audit token.
- `bash tests/validate.sh` exits 0 (transitively checks mirror parity — so any
  edit to `templates/persona-protocol.md` must be accompanied by
  `node bin/cli.js --update --force-render` in the same unit).

## Open Questions

None. Q1–Q4 answered 2026-09-02; the malformed-stamp edge case was self-resolved
under Q1's principle and is recorded in Clarifications.

## Self-check

- CHK1: Does the plan state, for each existing flag-keeping test case, whether
  its assertion changes? — PASS (the survival table + Step 3's "unmodified"
  criterion).
- CHK2: Is the zero-stamp case distinguished from the multi-stamp case in the
  acceptance criteria, rather than only the general shape? — PASS (Step 3 names
  zero-scope, single-relevant, single-irrelevant, multi-stamp and
  all-malformed cases).
- CHK3: Is "who deletes the stray marker" answered with a named actor rather
  than an assumption? — PASS (Step 1: the reviewer, per `reviewed-path-gate.sh:247`).
- CHK4: Do Steps 1 and 2 agree on ordering, given the re-leak risk? — FAIL
  (conflicting) — revised in place: dispatch order is stated in the header and
  in R5, and each step's heading names its position.
- CHK5: Is the artifact count for the `stop-gate-core.sh` edit stated as five,
  not four? — PASS (C4).
- CHK6: Does every step have a runnable check? — PASS.
- CHK7: Is the original intent of the global glob stated, and is preservation of
  it verifiable? — PASS (F5; the unmodified-assertions and multi-stamp criteria
  verify it).
- CHK8: Is the corrupted `spec2-unitC.pass` represented in an actionable step
  rather than only narrated? — FAIL (missing) — revised in place: Step 1 edit 2
  plus its own criterion (was Open Question 3, now answered).
- CHK9: Does the plan say how the fix's mutation controls stay binding? — PASS
  (R2 + Step 3's C1/C2/C3 re-verification criterion with expected counts).
- CHK10: Is the latency impact of reordering `review_join_state` addressed? —
  PASS (Clarifications + `hook-latency-budget.test.sh` criterion).
- CHK11: Does the plan avoid asserting a reproduction method the repo's own
  gates refuse? — FAIL (ambiguous) — revised in place: C5.
- CHK12: Does the plan say what happens to the *original* `review_join_state`
  call site when the call moves? — FAIL (missing) — revised in place: C3 now
  states it must be deleted, not duplicated, with the expected grep count.
- CHK13: Is the all-stamps-malformed case defined, and does the plan's stated
  rule cover it without a second branch? — PASS (Clarifications self-resolved
  entry + Step 3's single "scoped unit set empty" condition + its own test case).

## Dispatch contracts

### Unit: gh425-2

**## Objective** — Stop `tests/marker-write.test.sh` writing marker fixtures
into the real `.claude/reviewed/`, harden the helper against the same class of
mistake, and add a standing guard so a recurrence fails by name.

**## Retrieval** — No tracker issue. Read
`docs/plans/2026-09-02-blocked-marker-scoping-gh425.md` (this file), Step 2 and
findings F3/F4/R7.

**## Affected files** — `tests/marker-write.test.sh`;
`hooks/scripts/marker-write.sh` and its `.claude/hooks/scripts/` mirror; a new
guard test; `tests/validate.sh` (register the guard).

**## Ordered edits** — (1) pin `CLAUDE_PROJECT_DIR` to the per-case project root
in `run_helper()` (line 45), `reject_case()` (line 94) and the direct invocation
at line 188; (2) change `marker-write.sh:27` to
`: "${dot:=${CLAUDE_PROJECT_DIR:-.}/.claude}"`; (3) add the guard test and
register it in `validate.sh`; (4) regenerate mirrors with
`node bin/cli.js --update --force-render`.

**## Do NOT touch** — `hooks/scripts/lib/stop-gate-core.sh` (that is gh425-3);
anything under `.claude/reviewed/` (that is gh425-1, reviewer-only); the AC-C6
pinned-hash block at `tests/marker-write.test.sh:198-207`.

**## Acceptance criteria** — as Step 2 above, verbatim.

**## Pre-resolved context** — The leak mechanism is fully diagnosed: the test
isolates by `cd` only, while `marker-write.sh:27` reads `CLAUDE_PROJECT_DIR`
unconditionally. Line 140 already pins it for gate calls — copy that pattern. Do
not re-derive; reproduce once to confirm, then fix.

**## Escalation** — If the guard cannot be made to fail against a reverted copy
(i.e. it would be vacuous), stop and report rather than shipping it.

### Unit: gh425-1

**## Objective** — Remove the three leaked fixture markers and rewrite the
corrupted `spec2-unitC.pass` so it no longer asserts a false commit.

**## Retrieval** — No tracker issue. Read
`docs/plans/2026-09-02-blocked-marker-scoping-gh425.md`, Step 1 and findings
F2/F4/F6.

**## Affected files** — `.claude/reviewed/unitA.pass`,
`.claude/reviewed/unitB.fail`, `.claude/reviewed/unitC.blocked`,
`.claude/reviewed/spec2-unitC.pass`; `.claude/review-audit.log`.

**## Ordered edits** — as Step 1 above.

**## Do NOT touch** — any other marker in `.claude/reviewed/`; any source file.
This unit is data hygiene only.

**## Acceptance criteria** — as Step 1 above, verbatim.

**## Pre-resolved context** — Actor is the **reviewer**, mandatorily: the
orchestrator and lead-programmer are both refused by `reviewed-path-gate.sh:247`.
Dispatch only **after** gh425-2 has landed, or a harness-invoked `validate.sh`
re-plants the same four files (R5). `spec2-unitC`'s original content is
unrecoverable — do not attempt restoration from git; the directory is gitignored.

**## Escalation** — If any of the three fixture markers is absent, or
`spec2-unitC.pass` no longer matches the 86-byte fixture shape, stop and report:
something else has written to the directory since this plan was authored.

### Unit: gh425-3

**## Objective** — Scope the reviewer-`SubagentStop` `.blocked`/`.escalated`
early-return to the units named by that reviewer's own review-join stamps,
preserving today's behaviour when the scoped unit set is empty.

**## Retrieval** — No tracker issue. Read
`docs/plans/2026-09-02-blocked-marker-scoping-gh425.md`, Step 3, constraints
C1–C6, the survival table, and R1/R2/R3. Also read
`.claude/reviewed/gh295-1b.fail` before starting (R4).

**## Affected files** — `hooks/scripts/lib/stop-gate-core.sh` and its three
byte-identical copies; `.claude/persona-config.json` (`fileHashes`, regenerated
only); `tests/stop-gate-blocked.test.sh`; `tests/stop-gate-escalated.test.sh`.

**## Ordered edits** — (1) delete the `review_join_state "$dot"` call at line 345
and re-place it ahead of the marker check at the same four-space indent, keeping
exactly one occurrence; (2) build the scoped unit set from
`JOIN_SATISFIED_UNITS` + `JOIN_UNSATISFIED_UNITS`; (3) branch — empty set keeps
the existing globs verbatim (C1 literal intact), non-empty set tests only
`<unit>.blocked`/`<unit>.escalated`; (4) emit `marker-out-of-scope=<unit>` per
skipped marker; (5) add the five new test cases and the new mutation control;
(6) regenerate all mirrors and `fileHashes` with
`node bin/cli.js --update --force-render`.

**## Do NOT touch** — any existing assertion in
`tests/stop-gate-blocked.test.sh` or `tests/stop-gate-escalated.test.sh` (add
cases only); the `.directed` omission; `reviewer-route-gate.sh`; anything under
`.claude/reviewed/`.

**## Acceptance criteria** — as Step 3 above, verbatim.

**## Pre-resolved context** — Counts verified this session:
`grep -cxF '    review_join_state "$dot"'` == 1 and
`grep -cF 'escalated_markers=( "${dot}"/reviewed/*.escalated )'` == 1; all four
copies md5 `528e12c0e5b46743d0eb54e6876c232f`; bash 5.2.21 with `set -euo
pipefail`, empty-array expansion safe. `review_join_state` initializes both unit
arrays empty and returns early at zero stamps, so "scoped unit set empty" is one
condition covering both zero-stamp and all-malformed. An inline Bash repro is
refused by `reviewed-path-gate.sh` — put it in a test (C5).

**## Escalation** — If preserving C1's literal and implementing the branch prove
mutually exclusive, stop and report rather than editing the mutation control to
fit; that control is what proves case (a) binding.

### Unit: gh425-4

**## Objective** — Record the leaked-stamp/leaked-marker asymmetry and the new
scoped behaviour in the durable docs.

**## Retrieval** — No tracker issue. Read
`docs/plans/2026-09-02-blocked-marker-scoping-gh425.md`, Step 4 and finding F7;
plus `docs/adr/0016-per-unit-review-join.md`.

**## Affected files** — a new ADR; `hooks/scripts/stop-gate.sh` step-0.5 comment;
`templates/persona-protocol.md`; `CONTEXT.md`; `CHANGELOG.md`.

**## Ordered edits** — as Step 4 above, then
`node bin/cli.js --update --force-render` to re-render protocol mirrors.

**## Do NOT touch** — `hooks/scripts/lib/stop-gate-core.sh` logic (gh425-3 owns
it); ADR-0016's existing text beyond an annotation pointing at the new ADR.

**## Acceptance criteria** — as Step 4 above, plus:
- The ADR cites **F9** (2026-09-02 was the second firing; the first was
  2026-08-31T22:12:03Z, and the defect was already correctly root-caused to
  `stop-gate-core.sh:327` on 2026-09-01 before recurring) and states that the
  standing guard added in gh425-2 is what converts a silent recurrence into a
  loud one.
- The ADR cites **F10**'s measured impact — eight review-join stamps consumed in
  the single `cleared-by=reviewer` at `2026-09-02T19:46:16Z`, six of them from an
  unrelated plan — as evidence the jam was project-wide, not incident-local.
  Cite the stamp count, not the flag count.
- The ADR notes **F12**'s shape (a marker-hygiene unit cannot terminate BLOCKED
  without violating its own criterion), so future cleanup units are scoped with
  that in mind.

**## Pre-resolved context** — ADR numbers increment; never backfill the 0007
hole (CONTEXT.md links it). Re-derive the next number at execution time — a
sibling spec may have taken it. Editing `templates/persona-protocol.md` requires
mirror regeneration **in this same unit** or `validate.sh` exits 1. Findings
F9–F12 are already verified against `tmp/gh413-gh414-handoff.md` and
`.claude/review-audit.log` — cite them, do not re-derive.

**## Escalation** — If the protocol amendment would need to reach a persona
whose inlined protocol block is trimmed to exclude this section, report the
fan-out rather than silently amending only one surface.

## Explicitly out of scope — follow-up needed (do NOT fix in gh425)

**`state_append_audit_log()` bypasses `harness-integrity-gate.sh`'s Set-A scan.**
Found by the gh425-1 reviewer while investigating a *correct* block (the audit
log is Set A with no grant branch — not even for the reviewer), and explicitly
**declined** rather than used. Verified independently this session:

`hooks/scripts/lib/state-access.sh:248-259` takes a bare log *name* and resolves
it internally to `${dot}/${log_name}`. `harness-integrity-gate.sh`'s
`set_a_mentioned()` (lines 101-127) matches on the literal path substring
`.claude/review-audit.log`, and short-circuits with `return 1` when the command
contains no `.claude` substring at all. So a Bash command spelling only
`review-audit.log` never matches, and the gate exits 0 — while the function it
calls writes to the protected file.

Suggested fix for the follow-up spec: `audit_append`/`state_append_audit_log`
should resolve their target and refuse Set-A paths themselves, rather than the
protection depending on the caller's command text containing a particular
spelling. **This is a real hole in a trust-critical gate and should be filed as
its own spec** — it is not a gh425 defect, and no gh425 unit should touch it.
Recorded here only so it is not lost.

## Scribe update hint

On completion: new ADR covering the leaked-stamp/leaked-marker asymmetry (F7);
CONTEXT.md glossary entries for marker relevance scoping and the
`marker-out-of-scope` audit token; CHANGELOG entry noting that a stale
`.blocked` marker no longer jams unrelated reviewers.
