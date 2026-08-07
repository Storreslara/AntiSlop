# Commit-anchored PASS markers (marker format v3)

Date: 2026-08-07
Author: spec-master
Status: finalized, ready for `task-master`
Amends: marker format v2 (`templates/persona-protocol.md` "Review ownership",
`agents/reviewer.md`) and H3 (`hooks/scripts/dispatch-hygiene.sh`).

> **Provenance.** This document was authored by a `spec-master` dispatch whose
> report was lost to a dispatch-channel failure; the artifact itself landed on
> disk (untracked) and was recovered on 2026-08-07. A subsequent `spec-master`
> dispatch re-verified every load-bearing claim independently rather than
> re-deriving the plan, and made three corrections — R5/R7 (prior-defect
> history), two vacuous Step 5 criteria, and a stale baseline SHA — each
> recorded in the Self-check as CHK14-CHK16. The plan is otherwise unchanged
> and its structure is the original author's.

> Terminology note: this document refers to the reviewer-owned marker
> directory (the gitignored `reviewed` directory under `.claude/`) by role
> rather than by literal path, because this repo's own Bash gate refuses to
> lex any command whose text spells that path.

## Goal

Close the class of defect in which a reviewer PASS marker truthfully attests to
acceptance criteria that were satisfied by an **uncommitted working tree**, and
then survives the loss of the work it attested to — with `dispatch-hygiene.sh`'s
H3 check actively blocking the correction.

Two independent halves, both required:

- **Half A — attestation.** A `.pass` marker must record the commit SHA its
  criteria were checked against, and the reviewer must confirm the reviewed
  state is actually committed before writing it. An uncommitted tree becomes a
  FAIL ground, not a PASS.
- **Half B — re-validation.** H3 must stop trusting a marker unconditionally
  and forever. When a marker names a commit that is no longer reachable from
  `HEAD`, H3 declines to fire, so a lost unit becomes re-dispatchable without
  manual intervention.

**Honest scoping, stated up front so ADR-0015 does not overclaim:** Half A is
what would have caught unit #165 (nothing was ever committed, so the reviewer
could not have written a valid v3 marker). Half B catches the *different*
case — a commit that existed at review time and later vanished via rebase,
`reset --hard`, or a dropped branch. Neither half alone covers both. Half B
does **not** retroactively catch #165-shaped markers, because a legacy v2
marker carries no SHA to invalidate.

## Context

Verified facts this plan rests on. Provenance is grep/read-derived, not
graph-derived (the `explorer` dispatch for the same structural map did not
return in time).

**Baseline: commit `e2bcc6a`.** The facts below were first derived at
`37abf72` and **independently re-verified at `e2bcc6a`** on 2026-08-07 — the
two `#165` redo commits (`ff26d4c`, `e2bcc6a`) landed after the original
derivation, so `37abf72` was already a stale baseline. Every claim below still
holds at `e2bcc6a`; the counts (6 mirrors, 0 `git init` in the hook test
harness, ADR `0014` highest with the `0007` hole intact, no
`dispatch-hygiene.sh` anywhere under `adapters/`) were re-measured, not
carried forward. Re-measure again if this plan is executed after further
commits land.

- `hooks/scripts/dispatch-hygiene.sh:279-281` — H3 fires purely on
  `[ -f "${reviewed_dir}/${unit_id}.pass" ]`. File existence, nothing else. No
  content is ever read, so a marker is trusted permanently by construction.
- `hooks/scripts/task-gate.sh:57-64` — `marker_valid()` matches only
  `"PASS ${task_id} "*` as a **prefix**, plus non-emptiness. Any field inserted
  after the timestamp and before `criteria:` is therefore backward-compatible
  without touching that gate. This is load-bearing for the whole v3 design.
- `hooks/scripts/stop-gate.sh:106,130-146` — reads `.pass`/`.fail` by glob and
  mtime only; never parses the first line. Its `:156` help text spells the v2
  printf and is prose-only.
- `hooks/scripts/reviewer-tier.sh:71` — resolves the marker directory only;
  does not parse marker content.
- The reviewer-owned marker directory is **gitignored** (see `.gitignore`'s
  "antislop persona-system operational logs" block). Markers are local-only
  state, never committed. Two consequences: (a) a marker can never be recovered
  from git, and (b) the marker write itself can never dirty a `git diff HEAD`
  check.
- 129 marker files currently exist there, all v2 or older. The corrected
  `165.pass` (2026-08-07) already records
  `criteria: ... git status --short; git diff --numstat ff26d4c..e2bcc6a` —
  the hand-rolled precedent this plan mechanises.
- `templates/persona-protocol.md:165-176` is the canonical source of the
  marker-format paragraph. It is physically inlined into **6** full-tier
  mirrors under `.claude/agents/` (milestone-auditor, task-master,
  lead-programmer, orchestrator, reviewer, spec-master), all tracked.
  `templates/persona-protocol-slim.md` carries **no** marker text, so slim-tier
  mirrors (explorer, researcher, scribe) are unaffected.
- Regeneration of those mirrors is `node bin/cli.js --update --check` from the
  repo root. Per
  `.claude/agent-memory/antislop-lead-programmer/project_cli_check_is_a_write.md`,
  `--check` is a **forced render, not a dry run** — which is exactly why it is
  the correct regeneration command here, and why a plain `--update`
  (version-match fast path) would silently render nothing.
- `agents/lead-programmer.md:22-24` — the implementer commits per step, and its
  advisory packet (`:54-55`) already carries the `baseline..HEAD` range. A
  commit is therefore expected to exist at review time; this plan adds no new
  obligation on the implementer.
- `adapters/codex/` and `adapters/cursor/` have **no** `dispatch-hygiene.sh`
  (confirmed via `ls adapters/*/hooks/scripts/`). Half B has nothing to land in
  there. `tests/adapter-protocol-parity.test.js:5-17` is a **section-level**
  drift guard, so amending an existing section's body does not trip it.
- `tests/dispatch-hygiene.test.sh` (778 lines) is the established fixture
  pattern: canned hook-input JSON over stdin, project dirs seeded under
  `mktemp -d`, thresholds pinned per fixture. Its `make_project()` does **not**
  `git init`, so every existing fixture is a non-git directory — which the v3
  design must leave behaving exactly as today.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-07 Functional scope & success criteria: Q The dispatch listed four
  candidate surfaces (task-master authoring convention, reviewer marker-write
  verification, marker re-validation, `.fail`/2-FAIL-cap interaction) — which
  are in scope? -> A (self-resolved): reviewer marker-write verification
  (Half A) and H3 re-validation (Half B) only. The task-master
  authoring-convention change is **deliberately rejected** — see "Deliberate
  non-changes". The `.fail` and 2-FAIL-cap surfaces need no change.
- 2026-08-07 Domain entities / data model: Q What is the exact v3 first-line
  shape and where does the new field sit? -> A (self-resolved):
  `PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <commands>`.
  `commit:` must precede `criteria:` because `criteria:` runs free-form to
  end-of-line. Verified backward-compatible against `task-gate.sh`'s
  prefix-only `marker_valid()`.
- 2026-08-07 User interaction flow: Q What does the reviewer do when the tree
  is dirty at PASS time — FAIL, INSUFFICIENT-CONTEXT, or write the marker
  anyway? -> A (self-resolved): FAIL. An uncommitted change is an
  unmet-acceptance-criteria defect, which `agents/reviewer.md:25-30`'s
  materiality filter already admits as a FAIL ground. It is not
  INSUFFICIENT-CONTEXT, because nothing is missing or unreachable — the state
  is legible and simply wrong.
- 2026-08-07 Non-functional attributes: Q Is adding `git` subprocess calls to a
  PreToolUse gate acceptable latency? -> A (self-resolved): yes. At most three
  short-circuiting plumbing commands (`rev-parse --is-inside-work-tree`,
  `cat-file -e`, `merge-base --is-ancestor`), and only on the narrow path where
  a `.pass` marker already exists for a gated dispatch's `Unit:` id.
- 2026-08-07 External dependencies & integrations: Q Do the Codex/Cursor
  adapters get the v3 port? -> A (self-resolved, carried as Open Question 2):
  no. They have no `dispatch-hygiene.sh`, so Half B has nowhere to land, and
  shipping Half A's prose alone would give them a format with no gate behind
  it. Recorded as an explicit deferred gap in ADR-0015.
- 2026-08-07 Edge cases / failure handling: Q What are the failure branches for
  H3's re-validation, and which direction does each fail? -> A (self-resolved):
  six branches, enumerated in Step 1. The governing rule is that **anything
  unverifiable preserves today's behaviour (H3 fires)**, and only a
  *positively-proven-stale* SHA suppresses H3. This keeps all 129 existing
  legacy markers protected and makes the change strictly additive.
- 2026-08-07 Terminology consistency: Q "commit-anchored" vs "marker format
  v3" — which term is canonical? -> A (self-resolved): **marker format v3** is
  the canonical noun for the artifact (parallel to the existing "marker format
  v2"); **commit-anchored** is the adjective for the property. Both appear in
  ADR-0015; only `Marker format v3` is used as a greppable token in acceptance
  criteria.
- 2026-08-07 Completion / acceptance signals: Q What is the acceptance signal
  for the change as a whole? -> A (self-resolved): `bash tests/validate.sh`
  exits 0 with the new `tests/dispatch-hygiene.test.sh` fixtures included, plus
  the per-step greppable criteria below. `tests/validate.sh` is the repo's
  declared merge gate (constitution P5).

## Risks / dependencies

- **R1 — regenerating the six mirrors is a live-repo write.** This repo
  dogfoods its own plugin: `.claude/agents/*.md` are tracked and load-bearing
  for the session doing the work. `node bin/cli.js --update --check` from the
  repo root is the intended command and *will* also rewrite
  `.claude/persona-config.json`. Per
  `.claude/agent-memory/lead-programmer/feedback_never_scaffold_live_repo.md`,
  every *other* cli.js invocation (any `--target=` scaffold, any verification
  run) must be subshell-`cd`'d into a throwaway directory. Step 4 must end with
  a working-tree review of exactly what the render touched.
- **R2 — measuring the render is trap-laden.** A plain `--update` on a clean
  tree takes the version-match fast path and writes nothing, so "run it and
  diff" proves nothing. Use `--update --check` and assert on file *content*
  (the `Marker format v3` token), never on mtime.
- **R3 — SHA reaching a shell command.** The marker is local-only, but the
  extracted token is still interpolated into `git` invocations. It must be
  validated against `^[0-9a-f]{7,40}$` (or the literal `none`) before use;
  anything else falls to the legacy branch. Same hygiene posture as
  `dispatch-hygiene.sh:269-277`'s existing traversal guard.
- **R4 — `set -euo pipefail` is active in the hook** (`:70`). Every new `git`
  call must be wrapped so a non-zero exit is captured, never propagated. The
  file's existing convention (`|| true`, `|| rc=$?`, `2>/dev/null`) applies.
- **R5 — heavy prior-FAIL history on exactly this plan's two riskiest
  surfaces.** *(Corrected 2026-08-07 on re-verification; the original R5
  claimed six `.fail` records and concluded no escalation applied. Both the
  count and the conclusion were wrong.)* The reviewer's records directory holds
  **22** `.fail` records, not six: 124, 128, 150, 177, 182, 191, 192, 197, 205,
  220, 222, 223, 224, 225, 231, 237, 238, 244, plus `gh-140-hardening`,
  `gh-212-version-bump`, `gh-215-institutional-record` and `gh-216-merge-gate`.
  Filtering them by the surfaces this plan touches:
  - **8 records name `dispatch-hygiene.sh`** — 150, 205, 220, 222, 224, 225,
    `gh-215-institutional-record`, `gh-216-merge-gate`. That is **Step 1's**
    surface.
  - **9 records name `bin/cli.js` or the `.claude/agents/` mirrors** — 124,
    128, 191, 192, 197, 224, 225, 237, 238. That is **Step 4's** surface.

  Unit 165's own `.fail` was consumed by its corrected `.pass`, so it does not
  appear above; it is separately covered by R6.

  **Consequence for `task-master`: Steps 1 and 4 must NOT be tagged `haiku`.**
  This is durable, on-record evidence that both surfaces need more judgment
  than a mechanical executor brings, per `agents/task-master.md`'s reactive
  tagging rule and the shared protocol's `.fail`-record convention. Steps 2, 3
  and 6 carry no such history and may take the normal `haiku` default.
- **R7 — a prior FAIL on Step 4's surface is an instance of the very defect
  class this plan exists to close.** `224.fail` records that
  `bash tests/validate.sh` passed *only inside the lead-programmer's dirty
  working tree*, where uncommitted files masked a real failure, and that
  `node bin/cli.js --update` output was "only partially committed" — leaving
  `.claude/persona-config.json` stamped at a stale `pluginVersion` while the
  mirrors had moved. `225.fail` independently records unrelated dirty state
  landing in the wrong commit. Step 4 is that same surface, and its criteria
  must therefore be read against committed state, not the working tree — the
  plan's own thesis, applied to the plan's own execution. `220.fail` is the
  matching warning for Step 1: a `set -u` arithmetic-expansion abort in this
  exact hook that `||` could not catch, silently disarming H1-H4 with no audit
  trace. R4 anticipates that trap; R7 records that it has already been sprung
  once here.
- **R6 — unit #165 is direct prior-defect evidence for the *documentation*
  surface.** Its corrected marker records a first-pass false PASS followed by a
  FAIL on the CONTEXT.md glossary entry. Step 5 touches that same entry.
  `task-master` should weigh that history when tagging Step 5, notwithstanding
  the absence of a live `.fail` file.
- **D1** — Step 4 depends on Step 3 (the mirror render must carry the finished
  template wording).
- **D2** — Steps 5 and 6 depend on Steps 1-4 (docs and CHANGELOG describe
  landed behaviour).
- **D3** — Step 1 is independent of Steps 2-3 and may run in parallel.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim in Context was run or
  read, not inferred; the Goal explicitly refuses to overclaim that Half B
  would have caught #165.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 4
  regenerates the six mirrors via `node bin/cli.js --update --check` and
  explicitly forbids hand-editing any `.claude/agents/*.md`.
- P3 "Version-stamp discipline": satisfied — Step 6 bumps
  `.claude-plugin/plugin.json` and `package.json` (which `tests/validate.sh`
  cross-checks) to `0.27.0` and adds the CHANGELOG entry. Declared sequencing
  detail: the bump lands in the final step rather than the first, so
  intermediate commits on this branch are momentarily unstamped; the branch as
  a whole satisfies P3.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — no new
  cross-persona reference is introduced; the text amended in Step 2 already
  sits inside reviewer-conditional prose.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step carries
  `bash tests/validate.sh` as a criterion, and Step 1 extends the suite that
  gate runs.

## Deliberate non-changes

Stated explicitly so a later reader does not read them as oversights, and so
`task-master` does not slice units for them.

1. **No `task-master` authoring-convention change.** The dispatch proposed
   requiring commit-anchored criteria at authoring time. Rejected: H4 checks
   *labels, not substance* (`dispatch-hygiene.sh:55-58`), so no gate can ever
   enforce such a convention; it would be unenforceable prose duplicating a
   check that Step 2 makes mechanical. The obligation belongs at exactly one
   place — marker-write time — where the reviewer already has the working tree
   in hand.
2. **No change to `.fail` records or the 2-FAIL cap.** Nothing gates on a
   `.fail` record, so anchoring it buys nothing. H3 *declining to fire* is not
   a verdict and consumes no FAIL slot; Step 1 must not touch that accounting.
3. **No bulk audit or backfill of the 128 other pre-existing v2 markers.** See
   Open Question 1.
4. **No adapter port.** See Open Question 2.
5. **No general marker-expiry / TTL mechanism.** Staleness is defined solely as
   "the attested commit is unreachable from HEAD" — a fact, not a clock. A
   time-based expiry would invalidate correct markers on quiet repos.

## Step 1 — H3 re-validates a marker's commit anchor

**Affected files**

- `hooks/scripts/dispatch-hygiene.sh` — the H3 block at `:251-284` (between the
  `unit_id` traversal guard `case` and the H4 block opening at `:286`), plus
  the file-header logic summary at `:41-44` and the "H3 is reduced protection
  by construction" note at `:51-53`.
- `tests/dispatch-hygiene.test.sh` — new fixtures appended, following the
  existing `make_project` / `payload` / `run` harness at `:24-50`.

**Behaviour**

Where H3 today fires on bare file existence, it must first read the marker's
first line and decide. Extract the anchor with
`[[ $first =~ commit:[[:space:]]+([0-9a-f]{7,40}|none)([[:space:]]|$) ]]`.
Six branches, each with a fixed verdict:

| # | Condition | H3 |
|---|-----------|-----|
| 1 | marker's first line has no `commit:` field (legacy v2) | **fires** |
| 2 | `commit: none` | **fires** |
| 3 | `commit:` token fails the `^[0-9a-f]{7,40}$` shape | **fires** |
| 4 | project dir is not a git work tree, or `git` is unavailable | **fires** |
| 5 | SHA resolves to a commit **and** is an ancestor of `HEAD` | **fires** |
| 6 | SHA does not resolve, **or** resolves but is not an ancestor of `HEAD` | **does NOT fire** |

Branch 6 additionally writes one stderr line naming the unit id and the
unreachable SHA and stating that the unit is re-dispatchable because its
attested commit is gone, plus one audit line via the existing `log_line` helper
in the form `h3-stale-marker=<unit_id> commit=<sha> target=<target>`.

Implementation constraints:

- Three git calls only, short-circuiting in order:
  `git -C "$project_dir" rev-parse --is-inside-work-tree`,
  `git -C "$project_dir" cat-file -e "${sha}^{commit}"`,
  `git -C "$project_dir" merge-base --is-ancestor "$sha" HEAD`.
- Every one wrapped so a non-zero exit is captured, never propagated (R4).
- The `.fail` / 2-FAIL-cap accounting is untouched; branch 6 is not a verdict.
- H4 (`:286-305`) is untouched — it must still run for the same dispatch
  whether or not H3 fired.

**Acceptance criteria**

```
bash -n hooks/scripts/dispatch-hygiene.sh                                  # exit 0
bash tests/dispatch-hygiene.test.sh                                        # exit 0
for n in h3-legacy-no-commit-field h3-commit-none h3-commit-malformed-sha \
         h3-not-a-git-repo h3-commit-reachable h3-commit-unreachable; do \
  grep -q "$n" tests/dispatch-hygiene.test.sh || { echo "MISSING $n"; exit 1; }; \
done                                                                       # exit 0
grep -q 'h3-stale-marker=' hooks/scripts/dispatch-hygiene.sh               # exit 0
grep -q 'merge-base --is-ancestor' hooks/scripts/dispatch-hygiene.sh       # exit 0
bash tests/validate.sh                                                     # exit 0
```

The six fixture names are mandatory literal strings, one per branch in the
table above. Branches 1-5 must assert the hook exits 2 with `H3` in stderr;
branch 6 must assert it exits 0 with no `H3` in stderr. The two git-repo
fixtures (`h3-commit-reachable`, `h3-commit-unreachable`) must `git init` their
own `mktemp -d` project directory and create real commits — never touching this
repo's tree or its reviewer-owned marker directory, per the suite's stated
fixture hygiene at `:9-11`.

## Step 2 — reviewer writes marker format v3 and verifies the commit first

**Affected files**

- `agents/reviewer.md` — the "**On PASS (both modes)**" bullet at `:88-110`
  (specifically the printf at `:91`), and the "**Run the checks yourself**"
  bullet at `:51-53`.

**Behaviour**

Amend the On-PASS bullet so that, before writing the marker, the reviewer
establishes that the reviewed state is committed:

1. `git diff --quiet HEAD` must exit 0 — no tracked file carries an
   uncommitted change. Deliberately *not* `git status --porcelain`: untracked
   scratch files and the gitignored marker write must not trip it. Safe as a
   whole-tree check because the protocol guarantees only one unit is ever
   mid-review (`templates/persona-protocol.md:158-163`).
2. For each file the reviewer inspected in order to satisfy a criterion,
   `git ls-files --error-unmatch <path>` must exit 0 — it is tracked, not a
   never-added new file that `git diff HEAD` cannot see.
3. `sha="$(git rev-parse HEAD)"`.

If (1) or (2) fails, the verdict is **FAIL**, not PASS, with the defect stated
as "the unit's changes are not committed; the criteria were satisfied against
an uncommitted working tree" plus the offending paths. Explicitly *not*
INSUFFICIENT-CONTEXT — nothing is unreachable, the state is simply wrong.

If the project is not a git repository (`git rev-parse --git-dir` fails), the
reviewer writes `commit: none` and says so in the verdict line.

The new printf template must appear as a **single unwrapped line** in the
source so it stays greppable, and reads:

`printf 'PASS <task-id> %s commit: %s criteria: <acceptance-criteria command(s) run>\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse HEAD)"`

redirected to the unit's `.pass` marker path exactly as before.

Unchanged, and must be restated as unchanged: the `<task-id>` precedence rules
(`:105-110`), the appended non-blocking notes (`:99-102`), the `.blocked`
cleanup (`:103-104`), the `.fail` bullet (`:111-117`), and the materiality
filter (`:25-30`).

**Acceptance criteria**

```
grep -q 'commit: %s criteria:' agents/reviewer.md                # exit 0
! grep -q 'PASS <task-id> %s criteria:' agents/reviewer.md       # exit 0 (v2 printf gone)
grep -q 'git diff --quiet HEAD' agents/reviewer.md               # exit 0
grep -q 'git ls-files --error-unmatch' agents/reviewer.md        # exit 0
grep -q 'commit: none' agents/reviewer.md                        # exit 0
grep -q 'marker format v3' agents/reviewer.md                    # exit 0 (case-sensitive)
bash tests/validate.sh                                           # exit 0
```

## Step 3 — protocol block declares marker format v3

**Affected files**

- `templates/persona-protocol.md` — the "Review ownership" section's
  marker-format paragraph at `:165-176`. Do **not** touch `:191-193` (the
  v0.6.0 legacy grace period, which is about `task-gate.sh` and is unrelated),
  the FAIL-record section (`:218-225`), or the third-verdict section
  (`:227-241`).
- `templates/persona-protocol-slim.md` — **not** modified; it carries no marker
  text (verified: the only match for `PASS|marker` is the unrelated
  `max_turns_reached` line at `:61`).

**Behaviour**

Change "Marker format v2" to "Marker format v3" and state the first line as
`PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <acceptance-criteria command(s) run>`.
Add one sentence stating both facts a reader needs:

- `task-gate.sh`'s `marker_valid()` checks only line 1's `PASS <task-id> `
  prefix and non-emptiness, so v2 markers remain valid and are never
  retroactively rejected;
- `dispatch-hygiene.sh`'s H3 reads the `commit:` field and declines to fire
  when the named commit is unreachable from `HEAD`, so a marker whose work was
  lost no longer blocks its own correction.

Do **not** add a new top-level heading — `tests/adapter-protocol-parity.test.js`
is a section-level drift guard (`:5-17`), and a new canonical section would
force a present-or-deferred decision in both adapter ports, which Open
Question 2 defers.

**Acceptance criteria**

```
grep -q 'Marker format v3' templates/persona-protocol.md              # exit 0
! grep -q 'Marker format v2' templates/persona-protocol.md            # exit 0
grep -q 'commit: <sha' templates/persona-protocol.md                  # exit 0
node tests/adapter-protocol-parity.test.js                            # exit 0
git diff --numstat -- templates/persona-protocol-slim.md | wc -l      # outputs 0
bash tests/validate.sh                                                # exit 0
```

## Step 4 — regenerate the six full-tier mirrors

**Affected files**

- `.claude/agents/reviewer.md`, `.claude/agents/spec-master.md`,
  `.claude/agents/task-master.md`, `.claude/agents/lead-programmer.md`,
  `.claude/agents/orchestrator.md`, `.claude/agents/milestone-auditor.md` — all
  six regenerated, **never hand-edited** (constitution P2).
- `.claude/persona-config.json` — incidentally rewritten by the render; review
  its diff, do not revert it selectively.

**Behaviour**

From the repo root, run `node bin/cli.js --update --check`. This is a forced
render that bypasses the version-match fast path; a plain `--update` would take
that fast path and write nothing (R2). Then inspect `git status --short` and
confirm the only paths touched are the six mirrors, the three slim mirrors
(`scribe`, `explorer`, `researcher` — version re-stamp only, no marker text),
and `.claude/persona-config.json`. Any `.cursor/`, `.codex/`, `CLAUDE.md`, or
`.gitignore` change is a defect — stop and report (R1).

**Acceptance criteria**

```
[ "$(grep -rl 'Marker format v3' .claude/agents/ | wc -l)" -eq 6 ]        # exit 0
! grep -rq 'Marker format v2' .claude/agents/                             # exit 0
git status --porcelain -- .cursor .codex CLAUDE.md .gitignore | wc -l     # outputs 0
node tests/cli-backfill.test.js                                           # exit 0
bash tests/validate.sh                                                    # exit 0
```

The count `6` is measured, not assumed: it is the exact set that carried
`Marker format v2` before this plan, re-measured at commit `e2bcc6a`
(lead-programmer, milestone-auditor, orchestrator, reviewer, spec-master,
task-master). The three slim-tier mirrors — `explorer`, `researcher`,
`scribe` — carry no marker text and must stay at 0.

## Step 5 — sync help text, comments, and institutional docs

**Affected files**

- `hooks/scripts/task-gate.sh` — header comment `:9-14` and `reject()`'s help
  line `:67`. **`marker_valid()` at `:57-64` must not change** — its
  prefix-only match is what makes v3 backward-compatible, and altering it would
  reject all 129 existing markers.
- `hooks/scripts/stop-gate.sh:156` — the printf help text.
- `commands/start-feature-team.md:47-48` — the no-reviewer-fallback printf.
- `skills/install-antislop/hook-verification.md:52` — the smoke-test printf.
- `docs/adr/0015-commit-anchored-pass-markers.md` — **new**. Next free number
  is 0015 (0014 is the highest present). The 0007 hole is **not** free — it is
  linked from CONTEXT.md and must never be backfilled.
- `CONTEXT.md` — the "Dispatch hygiene" glossary entry (the same entry unit
  #165 rewrote; see R6).
- `.claude/wiki/modules/hooks.md` — the H3 description.

**ADR-0015 must record**, at minimum: the v3 first-line shape; the Half A /
Half B split and the explicit statement that Half B would *not* have caught
#165; the fail-direction rule (anything unverifiable preserves today's
behaviour); the five Deliberate non-changes; and the adapter port as an
**explicit deferred gap** with its reason (no `dispatch-hygiene.sh` exists in
`adapters/*/hooks/scripts/`).

**Acceptance criteria**

```
test -f docs/adr/0015-commit-anchored-pass-markers.md                     # exit 0
! ls docs/adr/0007-* >/dev/null 2>&1                                      # exit 0 (hole preserved)
git show HEAD:hooks/scripts/task-gate.sh | sed -n '/^marker_valid()/,/^}/p' \
  | grep -qF '"PASS ${task_id} "*) return 0 ;;'                            # exit 0
diff <(git show <base-sha>:hooks/scripts/task-gate.sh | sed -n '/^marker_valid()/,/^}/p') \
     <(git show HEAD:hooks/scripts/task-gate.sh       | sed -n '/^marker_valid()/,/^}/p')  # exit 0
! grep -q 'PASS <task-id> %s criteria:' hooks/scripts/stop-gate.sh        # exit 0
grep -q 'commit: %s criteria:' hooks/scripts/stop-gate.sh                 # exit 0
grep -q 'commit: %s criteria:' hooks/scripts/task-gate.sh                 # exit 0
grep -q 'commit:' commands/start-feature-team.md                          # exit 0
grep -q 'commit:' skills/install-antislop/hook-verification.md            # exit 0
grep -q 'commit:' CONTEXT.md                                              # exit 0
grep -q 'ADR-0015' CONTEXT.md                                             # exit 0
grep -q 'unreachable' .claude/wiki/modules/hooks.md                       # exit 0
bash tests/validate.sh                                                    # exit 0
```

`<base-sha>` is the commit this unit branched from; `task-master` substitutes
the literal SHA when it writes the dispatch prompt, and the reviewer records
that same SHA in the marker's `commit:` field. Do not leave it as a
placeholder — an unsubstituted `<base-sha>` makes `git show` fail and the
criterion unrunnable.

**Why these two `marker_valid()` criteria are shaped this way** *(corrected
2026-08-07)*: the original pair was
`grep -q 'marker_valid' hooks/scripts/task-gate.sh` and
`git diff HEAD -- hooks/scripts/task-gate.sh | grep -q 'marker_valid()' && exit 1 || exit 0`.
Both were **vacuous**, and the second one vacuous in precisely the way this
whole plan exists to prevent: `git diff HEAD` measures the *working tree*
against HEAD, so it is empty on any clean tree. Measured on the current tree,
the criterion exits 0 having proven nothing — and once the implementer commits
its `task-gate.sh` edits (as it is required to), it exits 0 whether or not
`marker_valid()` was changed. A criterion that a commit silently satisfies is
the #165 failure mode wearing a `git` prefix. The replacements read committed
blobs on both sides via `git show`, and the second compares the function body
across a named commit range rather than against the mutable tree.

## Step 6 — version bump and CHANGELOG

**Affected files**

- `.claude-plugin/plugin.json` — `version` -> `0.27.0`.
- `package.json` — `version` -> `0.27.0` (`tests/validate.sh:34-40`
  cross-checks the two).
- `CHANGELOG.md` — new `## [0.27.0] - 2026-08-07` section.

Minor bump, not patch: this changes a documented protocol format and a hook's
blocking behaviour.

**Acceptance criteria**

```
python3 -c "import json;assert json.load(open('.claude-plugin/plugin.json'))['version']=='0.27.0'"  # exit 0
python3 -c "import json;assert json.load(open('package.json'))['version']=='0.27.0'"                # exit 0
grep -q '^## \[0.27.0\] - 2026-08-07' CHANGELOG.md                                                  # exit 0
grep -q 'marker format v3' CHANGELOG.md                                                             # exit 0
bash tests/validate.sh                                                                              # exit 0
```

## Open Questions

Both carry a recommended default. **The plan proceeds on those defaults** — a
different answer amends Step 5 and adds units; it does not block Steps 1-4.

1. **Should the 128 other pre-existing v2 markers be audited against git
   history, or backfilled with `commit:` anchors?**
   *Recommended default, assumed by this plan: neither — grandfather them.*
   They are gitignored local dev state; retro-deriving a SHA per unit means
   reconstructing which commits each unit produced, which is expensive and, for
   units whose work is plainly present in the repo today, unactionable. Branch
   1 of Step 1's table keeps them protected exactly as today. If the answer is
   "audit them," that is a separate one-off unit, not a change to Steps 1-4.

2. **Should `adapters/codex` and `adapters/cursor` receive the v3 marker
   format?**
   *Recommended default, assumed by this plan: no — deferred, documented in
   ADR-0015.* Neither adapter has a `dispatch-hygiene.sh`, so Half B has
   nowhere to land, and shipping Half A's prose alone would give those
   platforms a format with no mechanism behind it. Their stop-gates read
   markers by glob and mtime only, so they are unaffected by the format change,
   and `tests/adapter-protocol-parity.test.js` will not fail because Step 3
   adds no new top-level section. If the answer is "port them," it is two
   additional units touching `adapters/*/agents/reviewer.md`,
   `adapters/codex/agents-md-fragment.md`, and
   `adapters/cursor/rules/persona-protocol.mdc`.

## Self-check

- CHK1: Is the exact v3 first-line field order defined, including why `commit:`
  must precede `criteria:`? — PASS
- CHK2: Do Steps 2 and 3 agree on the literal first-line shape? — FAIL
  (conflicting: Step 2's printf declared `<sha>` while Step 3 declared
  `<sha|none>`) — revised in place; the format declaration now reads
  `<sha|none>` in both, and Step 2's printf substitutes the live value.
- CHK3: Is the behaviour for a non-git project defined on **both** the write
  side and the read side? — PASS (Step 2 writes `commit: none`; Step 1
  branches 2 and 4 both fire H3).
- CHK4: Does the plan define what happens to the 129 existing markers? — PASS
  (Step 1 branch 1, plus Open Question 1's stated default).
- CHK5: Is every H3 branch's fail direction stated as a machine-checkable
  assertion rather than prose? — PASS (Step 1's six-row table, each row bound
  to a mandatory literal fixture name in the acceptance criteria).
- CHK6: Does the plan state which half of the fix would have caught unit #165,
  without overclaiming? — PASS (Goal states Half A catches it and Half B does
  not; Step 5 requires ADR-0015 to record the same).
- CHK7: Is the mechanism for regenerating `.claude/agents/*.md` named, and is
  hand-editing explicitly forbidden? — PASS (Step 4 names
  `node bin/cli.js --update --check` and cites constitution P2).
- CHK8: Do the steps agree on whether `task-gate.sh` changes behaviour? — FAIL
  (ambiguous: Step 5 listed `task-gate.sh` as affected without saying whether
  `marker_valid()` was in or out of scope) — revised in place; Step 5 now
  states `marker_valid()` must not change and carries a criterion asserting
  the diff does not touch it.
- CHK9: Is "which files the reviewer inspected" (Step 2's check 2) defined
  precisely enough to be actionable without parsing the dispatch packet? —
  PASS (Step 2 scopes it to the reviewer's own working set, explicitly not to
  the dispatch contract's `## Affected files`, so no parsing dependency is
  introduced).
- CHK10: Does the plan say whether a task-master authoring-convention change is
  in scope? — PASS (Deliberate non-changes item 1, with its reason; also
  recorded in Clarifications).
- CHK11: Is the ADR number justified against the existing numbering, including
  the 0007 hole? — PASS (Step 5 states 0015 is next and that 0007 must never be
  backfilled; a criterion asserts the hole survives).
- CHK12: Does the plan define an acceptance signal for the change as a whole? —
  PASS (`bash tests/validate.sh` exits 0, carried as a criterion on every step;
  recorded in Clarifications).

- CHK13: Is Step 5's "old printf is gone" criterion non-vacuous for every file
  it claims to cover? — FAIL (ambiguous) — revised in place. Self-reported: this
  one was NOT found by reading the plan, it was found by running the criterion
  against the current tree afterwards (constitution P1). The recursive grep
  `grep -rq 'PASS <task-id> %s criteria:' hooks/scripts/ commands/ skills/`
  matches only `hooks/scripts/stop-gate.sh`; `commands/start-feature-team.md`
  wraps the same printf across two lines and
  `skills/install-antislop/hook-verification.md` writes `PASS test %s criteria:`,
  so both would have satisfied the criterion while remaining un-updated. Replaced
  with five per-file criteria, each asserted against a string that is present in
  that specific file today.

- CHK14: Does the plan's prior-defect survey (R5) actually enumerate the
  `.fail` records present, and is its conclusion supported by them? — FAIL
  (missing) — revised in place. R5 named 6 records and concluded "no
  prior-defect escalation applies." The directory holds **22**; 8 name
  `dispatch-hygiene.sh` (Step 1's surface) and 9 name `bin/cli.js` or the
  `.claude/agents/` mirrors (Step 4's surface). The conclusion was not merely
  incomplete, it was inverted: the two surfaces with the heaviest documented
  defect history in this repo are exactly the two this plan modifies. R5 now
  carries the full enumeration and an explicit "Steps 1 and 4 must NOT be
  tagged `haiku`" directive; R7 was added for the specific prior instances.
- CHK15: Is every acceptance criterion non-vacuous — does each one actually
  fail on the pre-change tree? — FAIL (ambiguous) — revised in place. All
  criteria were executed against the tree at `e2bcc6a`. Steps 2, 3, 4 and the
  five per-file Step 5 greps are sound (each asserts a string absent today).
  Two Step 5 criteria were vacuous, one of them thematically: `git diff HEAD --
  hooks/scripts/task-gate.sh | grep -q 'marker_valid()' && exit 1 || exit 0`
  exits 0 on any clean tree, proving nothing, and keeps exiting 0 after the
  implementer commits — a working-tree criterion that a commit silently
  satisfies, i.e. the #165 mechanism reproduced inside this plan's own
  verification. Both replaced with `git show`-based criteria that read
  committed blobs on both sides.
- CHK16: Is the baseline commit the plan's measurements were taken at still
  current? — FAIL (missing) — revised in place. The plan asserted provenance
  at `37abf72`; HEAD is `e2bcc6a` (`37abf72` is an ancestor, two `#165` redo
  commits later). Every load-bearing count was re-measured at `e2bcc6a` and
  all still hold, so no downstream step changed — but the stated baseline was
  stale and is now correct, with an explicit instruction to re-measure if
  execution is deferred.

Six FAILs across three passes. CHK2 and CHK8 were resolved in the single
permitted revision pass. CHK13 was a second, verification-driven pass.
CHK14-CHK16 are a third pass, performed when this document was recovered and
re-verified (see the Provenance note at the head of this file) — all three were
found by *running* the plan's claims and criteria against the tree rather than
by re-reading the plan, which is the only way the CHK13 and CHK15 defects were
ever going to surface. All six are re-checked and now passing. No unresolved
failure remains, so nothing from this checklist was converted to an Open
Question; Open Questions 1 and 2 are pre-existing scope decisions, not
Self-check escalations.

## Scribe update hint

After Step 5 lands: `CONTEXT.md`'s "Dispatch hygiene" glossary entry gains the
commit-anchor clause; `.claude/wiki/modules/hooks.md`'s H3 section gains the
six-branch table; `.claude/wiki/changelog.md` gains a v0.27.0 line. ADR-0015 is
new and should be linked from `CONTEXT.md` alongside the existing ADR pointers,
and from `.claude/wiki/` wherever ADR-0014 is already referenced. No
`docs/dependencies.md` change is expected — no dependency is added.

## Handoff

Six dispatchable units, so this is the **standard path**: `task-master` slices
these steps with `to-tickets`, assigns each unit's `Suggested model` tag, states
the retrieval contract, and writes the per-unit dispatch prompts. `spec-master`
emits no dispatch contract for this plan.
