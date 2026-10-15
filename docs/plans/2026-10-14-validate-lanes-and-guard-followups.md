# Leak guard follow-ups and an opt-in parallel validate.sh runner (lgc open notes 1-3)

Status: FINAL (spec-master 2026-10-14). Three fast-path units, `vlg-1`,
`vlg-2`, `vlg-3`. No open questions; every decision below is a stated
default. Criteria scripts live in `docs/plans/vlg-criteria/`.

## Goal

Close the three open notes left by lgc-1
(`.claude/agent-memory/scribe/project_epa2_completion.md`, "lgc closure"):

- G1 (note 1): `tests/reviewed-dir-leak-guard.test.sh` FAILs when its nested
  validate.sh run does not reach validate.sh's own closing summary, and does
  NOT fail when the nested run finishes with failing checks. Criteria:
  vlg-1 criteria 1-2; lgc-1's three criteria stay green (criteria 3-5).
- G2 (note 2): the repo-root-relative writer gap is closed where it is cheap
  (inside the new lane runner, where every lane is a private copy) and stays
  a documented accepted gap in the serial guard. Criteria: vlg-2 criterion 2
  (`relpath`, `toplevel` cases), vlg-3 criterion 3 (CONTRIBUTING.md claim),
  and the guard's header text in vlg-1 edit 1.
- G3 (note 3): `bash tests/validate-lanes.sh` runs the validate.sh sections in
  N parallel lanes (default 3), each in a private copy of the checkout (own
  `.claude/` state, own git index), with output and exit code shaped like
  validate.sh's. `bash tests/validate.sh` is untouched apart from one new
  section that runs the runner's regression test. Criteria: vlg-2 criteria
  1-4, vlg-3 criteria 1-2.

## Context

### Note 1: what "aborted" means, and why failing checks are not a FAIL

validate.sh ends every complete run with exactly one closing summary
(`tests/validate.sh:1284-1289`): exit 0 after `All checks passed.`, or exit
1 after `One or more checks FAILED.`. Anything else (another exit code, no
summary line, or a summary line that disagrees with the exit code) means
the run stopped before its end. Examples: a section calling `exit`, an
unbound variable under `set -u`, or a signal.

Chosen semantics for the guard:

| nested exit : last non-blank line | guard |
|---|---|
| `0 : All checks passed.` | no change (OK when no leak) |
| `1 : One or more checks FAILED.` | prints a `NOTE` line, does not FAIL |
| anything else | FAIL `the nested validate.sh run did not finish (exit N; last line: ...)` |

Why. A nested run that finishes with failing checks still ran every section,
so the leak check saw the whole suite. The failing checks are the outer
run's to report, and it does: the outer run executes the same sections.
Failing the guard as well would double-report them, and the dispatch asks
for exactly that not to happen. A nested run that stops part-way is
different: every suite after the stop point was never observed, and the
outer run may still be green. For example, an abort that only happens under
the nested environment (sandbox `CLAUDE_PROJECT_DIR`,
`REVIEWED_DIR_LEAK_GUARD_NESTED=1`) would never show up in the outer run.
That case is the silent shrink lgc-1's reviewer flagged.

Why not match the summary line anywhere in the output: two suites print the
same two lines themselves (`tests/eval-cases.test.sh:221/223`,
`tests/agent-auditor.test.sh:924/926`, explorer report). So the guard checks
the **last non-blank line**, paired with the exit code. To make that line
validate.sh's own, the guard sets `ANTISLOP_VALIDATE_INNER=1` on the nested
run. Otherwise a standalone `bash tests/reviewed-dir-leak-guard.test.sh`
would get validate.sh's skip-summary wrapper (`tests/validate.sh:10-26`),
whose `Skipped checks: N` lines come after the summary. Under the outer
validate.sh the variable is already inherited, so nothing changes there.
vlg-1 criterion 2 covers the standalone case.

Measured at 70458f7: the nested run with a sandbox `CLAUDE_PROJECT_DIR`
exits 0, prints `All checks passed.` last, leaks nothing, and takes 476 s.
So the reworked guard is green on the real suite (see merge gate G below).

lgc-1's criteria stubs printed no summary line, so after vlg-1 they would
read as aborted runs. `docs/plans/lgc-criteria/lib.sh` `mktree` now appends
`echo "All checks passed."` to every stub (committed with this plan; a
plan artifact, not unit scope). lgc1-ac1..ac3 were re-run green at HEAD and
with vlg-1 applied.

### Note 2: the repo-root-relative writer gap

Measured facts (explorer, grep-derived):

- `hooks/scripts/marker-commit-check.sh` is read-only (git log, rev-parse,
  cat-file, marker read). Its marker directory is `${2:-.}/.claude` (line
  12), so it ignores `CLAUDE_PROJECT_DIR`, but it writes nothing.
- `hooks/scripts/marker-verify.sh` resolves `${project_dir:-.}/.claude`
  (lines 24, 34). `--list` and `--notes` are read-only. `--execute` writes a
  `mktemp -d` and `git worktree add` metadata into the repo it is given
  (lines 188-189), never a marker.
- Every test that invokes either script passes a `mktemp` sandbox repo
  (`tests/marker-commit-check.test.sh:13,42,100`,
  `tests/marker-verify.test.sh:11-12`). Production callers
  (`bin/marker-audit.sh:36`, `bin/marker-commit-audit.sh:15`) are not run by
  validate.sh against the checkout.

So the two scripts named in the note are not marker writers. The gap is
real but has no known writer. Closing it in the serial guard would need the
nested run to execute in a full copy of the checkout. lgc-1 rejected that as
out of scope, and it would add ~480 s of copying and running to every serial
run. The lane runner (note 3) needs that copy anyway. There, a
per-section fingerprint of the lane copy's marker directory sees all three
routes: cwd-relative paths, `git rev-parse --show-toplevel` roots, and
`CLAUDE_PROJECT_DIR`. No live reviewer can race it, because nobody else
knows the lane copy exists. **Decision (self-resolved): close the gap in the lane
runner, keep it as a documented accepted gap in the serial guard** (vlg-1
edit 1 header, vlg-3 CONTRIBUTING.md bullet). No separate unit.

### Note 3: the lane runner

Feasibility was measured with the exact runner text in vlg-2 edit 1, on
a copy of the checkout at 70458f7:

- `bash tests/validate-lanes.sh --lanes 3`: exit 0, `All checks passed.`
  last, 115 sections, **177.8 s** monotonic. The serial run of the same
  sections (the nested-run measurement above) took 476 s, so lanes save
  **63%**.
- Parity with serial: both runs printed 3135 `OK ` lines, 114 `ok ` lines,
  0 `SKIP` and 0 `FAIL`. The only `OK `-line differences were fixture
  commit hashes in the marker-commit-check suite, which change with commit
  timestamps.
- No section changed a lane's marker directory. So the real suite has no
  repo-root-relative leak today.

Isolation design:

- Each lane is a `tar` copy of the checkout, including `.git` and all
  ignored state except `.claude/worktrees` (75 MB of agent worktrees; about
  50 MB per lane copy). This gives every lane its own `.claude/` (markers,
  flags, stamps, audit logs) and its own git index and refs, the two
  prerequisites named in the lgc notes. `CLAUDE_PROJECT_DIR` is set to
  the lane copy, so `${CLAUDE_PROJECT_DIR:-.}` writers stay in the lane.
- The runner refuses (exit 2) when `.git` is not a directory. In a linked
  worktree `.git` is a file pointing at a shared gitdir, so every lane copy
  would share one index.
- If `TMPDIR` lies inside the checkout, the runner's work directory is
  excluded from the copies. Without that, the copy recursed into itself
  (observed during prototyping).
- Sections are cut at the `echo "== ` headers. The last one ends before
  validate.sh's closing summary block (`^if [ "$fail" -eq 0 ]; then$`).
  Each section runs in a fresh `bash` with validate.sh's preamble (`set -uo
  pipefail`, `cd`, `fail=0`). This is the same extraction the merge gate's
  `vsec` ranges already rely on. The real-suite run proves every section
  runs on its own.
- A section records its own `$fail` only if it reaches its end. A section
  that exits early, with any exit code including 1, is reported as `FAIL
  section N aborted (exit N)`. This is the lane runner's version of
  note 1.
- Lanes claim sections from a shared order (known-heavy headers first: 109
  probe-hook-identity 136 s, 115 unit-outcomes 83 s, 49 human-decision gate
  62 s, 25 configless write-deny and 48 reviewed-path gate about 21 s each),
  using atomic `mkdir` claims. No lock tool is needed (portable). The heavy
  list is matched on header text, so a renumbering only costs balance,
  never correctness.
- Section 101 (the nested leak guard) runs with
  `REVIEWED_DIR_LEAK_GUARD_NESTED=1` and is a no-op, as in the merge gate's
  `vsec` ranges. Running it would put a 476 s serial run inside one lane.

Not in scope: making the lane runner the merge gate, changing `vsec`, or
changing the CI workflow. `bash tests/validate.sh` stays the merge gate
(constitution P5).

### Shared state the copies do not isolate

`$HOME` and `/tmp` stay shared. `/tmp` scratch names are per-run `mktemp`
since vtmp-1. The dashboard tests bind an ephemeral port
(`addr.port` after `listen`), not a fixed one. The only `$HOME` use found is
`tests/cli-backfill.test.js`, which uses a temporary HOME
(`tests/cli-backfill.test.js:2588`). None of these caused a difference in
the measured run. See Risks R4.

### Prior FAIL history and notes sweep

- `vlg-1..3` are new unit ids. No `.fail` record exists for them or for
  lgc-1.
- `bash bin/marker-audit.sh . --notes --surface=tests/reviewed-dir-leak-guard.test.sh`,
  2026-10-14: 6 notes (0 NOTE[spec], 2 NOTE[code], 4 untagged).
  Dispositions: gh425-2 notes 2, 3 and 5 were closed by lgc-1. gh425-2
  note 4 (the nested pass prints a green OK for a skipped check) stays
  **deferred** (cosmetic). The lane runner inherits the same no-op for
  section 101 and says so in its header. lgc-1 NOTE[code] (`-mindepth 1` is
  an equivalent mutant) is **not acted on**: the line is unchanged. rnf-2
  NOTE[code] (a full validate.sh run exceeds 600 s because of the nested
  run) is **addressed for the opt-in path** by the lane runner (177.8 s). The
  serial run is unchanged.
- `bash bin/marker-audit.sh . --notes --surface=tests/validate.sh`: 186
  notes (41 NOTE[spec], 48 NOTE[code], 97 untagged). vlg-3 only appends one
  section at the end of the file. None of the notes is about the file's
  section structure, the closing summary block, or the leak guard. They
  are about individual sections' content (version-sync, rollout-preflight
  baselines, frontmatter skips and so on). Disposition: **none in scope**.
  rnc-2's NOTE[code] (a foreground run that prints `^SKIP` could fail) is
  noted. The lane runner reports the same `Skipped checks:` count and does
  not change it.
- Replay source `docs/audits/unit-outcomes/2026-10-06.jsonl`: 12 recorded
  units with FAIL class vacuous or host touched `tests/validate.sh` (gh317,
  gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1, mw-step2,
  mw-step3, rollout-map-1, spec2-unitA, spec2-unitB). The only criterion
  whose `run:` names that file is vlg-3 criterion 4 (scope). See CHK14.
- The sweep is best effort (per-clone, gitignored records).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-10-14 Functional scope & success criteria: Q For note 2, close the gap or keep it as an accepted gap? → A (self-resolved): close it in the lane runner (per-section fingerprint of a private lane copy) and keep it documented as accepted in the serial guard; the two named scripts are not marker writers (Context, Note 2).
- 2026-10-14 Non-functional attributes (perf, security, scale): Q Does the lane runner deliver the expected speedup without new shared-state hazards? → A (self-resolved, measured): 177.8 s vs 476 s (63%) at 70458f7, output parity with serial, no lane marker change; the default lane count is 3, capped at 8 (each lane copies about 50 MB).
- 2026-10-14 Edge cases / failure handling: Q Which nested outcomes should FAIL the guard? → A (self-resolved): only a run that did not reach validate.sh's own closing summary (the table in Context, Note 1); a completed run with failing checks is a NOTE.
- 2026-10-14 Technical constraints & tradeoffs: Q Opt-in runner or change validate.sh's default? → A (self-resolved, per the dispatch): opt-in `tests/validate-lanes.sh`; validate.sh gains only a regression-test section; the merge gate stays serial (P5).
- 2026-10-14 Completion / acceptance signals: Q How can criteria prove the runner without a 10-minute run per check? → A (self-resolved): stub-suite throwaway git trees for semantics, isolation, leaks and parallelism (seconds each), plus one real-suite run (vlg-2 criterion 4, about 3 min).

## Risks / dependencies

- R1: Ordering. vlg-1 and vlg-2 touch disjoint files and can run in
  parallel in one tree: each stages only its own path, and each ends with
  `git diff --quiet HEAD -- <own file>`. vlg-3 depends on vlg-2. Its test
  copies `tests/validate-lanes.sh`, and its criterion 2 mutates that file's
  exact text. vlg-3 may run in parallel with vlg-1.
- R2: vlg-2 criterion 4 copies the working tree. If vlg-1 is mid-edit in
  the same tree, the lane copies include that half-edited guard. Section 101
  exits at its unchanged `REVIEWED_DIR_LEAK_GUARD_NESTED` check before
  reaching the edited lines, so this is harmless. If any other sibling edit
  makes it red, re-run it after the sibling commits.
- R3: The criteria scripts in `docs/plans/vlg-criteria/` and the
  `docs/plans/lgc-criteria/lib.sh` stub change are committed with this plan.
  They are read-only for the units. Unit commits are found by the subject
  scope `^[a-z]+\(vlg-N\): ` (`docs/plans/epf-criteria/scope.sh`,
  `range.sh`).
- R4: Shared `$HOME` and `/tmp` across lanes (Context). A future suite
  that writes a fixed path under either would race across lanes. It would
  show up as a lane-only failure, never as a silent pass.
- R5: Gates. The runner, its test and the guard all spell the marker
  directory path. `reviewed-path-gate.sh` blocks a Bash command whose
  text spells it, and a heredoc carrying these files is such a command.
  Author every file and edit with Write/Edit, which are path-checked
  only, and run criteria as `bash <script>`. If Write/Edit are unavailable,
  STOP and report. Rewording a command to get past the gate is a bypass.
- R6: The full serial validate.sh runs past the 600 s Bash cap because of
  section 101's nested run (476 s nested plus the outer run). Units never
  run it. The orchestrator's merge gate G (below) runs the reworked guard
  on its own.
- R7: Wall-clock jumps. During prototyping on WSL, `date +%s` jumped back
  2 s within a 12 s run. The criteria time with `/proc/uptime` (monotonic).
  The runner's own `wall:` line uses `date` and is informational only.

**G: merge gate for this plan** (orchestrator, after all three PASS; one
Bash call per item, each `timeout: 600000`): (1) the four `vsec` ranges of
`docs/plans/2026-10-13-escalation-packet-followups.md` "G", with `vsec 111
999`, which now also covers section 116. (2) `bash
tests/reviewed-dir-leak-guard.test.sh` on its own, with
`REVIEWED_DIR_LEAK_GUARD_NESTED` unset. It must exit 0 and print the `OK`
line (about 480 s; this is the only real run of the reworked guard).
(3) `bash docs/plans/vlg-criteria/vlg2-ac4.sh`.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion script was run red
  at the plan commit (on e13447a) and green with the exact edit texts applied (Verification
  record). The real-suite claims (476 s nested, 177.8 s in lanes, parity)
  were measured, not estimated.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  criteria are committed scripts, and every edit is literal (two new files
  and before/after or insert-after blocks).
- P3 "Version-stamp discipline": satisfied, vacuously. No `agents/*.md` or
  `templates/*` change.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona
  prose changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied. The serial run
  stays the gate, and the lane runner is opt-in. vlg-3 registers the
  runner's regression test in validate.sh. Units do not run the full file
  (R6). Merge gate G covers it.

## Steps

### Step 1: vlg-1, the leak guard FAILs a nested run that did not finish
**Affected files:** `tests/reviewed-dir-leak-guard.test.sh` only.
**Acceptance:** `vlg1-ac1.sh` (13 stub outcomes: clean, trailing blanks, red
is a NOTE, four kinds of abort, two summary/exit mismatches, a signal, and
leak combined with abort, red or clean); `vlg1-ac2.sh` (a standalone run is
not tripped by the skip-summary wrapper, and TMPDIR is left clean); lgc1-ac1..3
(leak detection unchanged); `bash -n`; scope; trailer; tail.

### Step 2: vlg-2, opt-in parallel lane runner
**Affected files:** `tests/validate-lanes.sh` (new).
**Acceptance:** `vlg2-ac1.sh` (exit code, summary last and once, header
order, aborted reporting including exit 1, `--lanes` contract, linked
worktree refused); `vlg2-ac2.sh` (cwd-relative, toplevel,
CLAUDE_PROJECT_DIR, overwrite and removal leaks FAIL the named section; the
source tree, its index and HEAD untouched; a concurrent reviewer write
harmless; TMPDIR clean); `vlg2-ac3.sh` (3 lanes really parallel);
`vlg2-ac4.sh` (real suite green in 3 lanes); `bash -n`; scope; trailer;
tail.

### Step 3: vlg-3, regression test, validate.sh registration, CONTRIBUTING.md
**Affected files:** `tests/validate-lanes.test.sh` (new),
`tests/validate.sh` (one section appended), `CONTRIBUTING.md` (one bullet).
**Acceptance:** `vlg3-ac1.sh` (test green, registered as last section 116,
and `vrun` green); `vlg3-ac2.sh` (five runner mutants each turn the test
red with the named case id); `vlg3-ac3.sh` (CONTRIBUTING.md bullet
verbatim); scope; trailer; tail.

## Open Questions

None. Every Partial category was self-resolved (Clarifications), and no
Self-check item was converted.

## Self-check
- CHK1: Does each Goal clause map to a criterion? — PASS (G1 → vlg-1 criteria 1-5; G2 → vlg-2 criterion 2 `relpath`/`toplevel`, vlg-3 criterion 3, vlg-1 edit 1 header; G3 → vlg-2 criteria 1-4, vlg-3 criteria 1-2)
- CHK2: Is "aborted" defined for every exit-code/last-line combination the guard can see? — PASS (Context table; vlg1-ac1 covers 0/1/2/3/143 and both mismatches)
- CHK3: Do Context and vlg-1 agree that a completed red nested run does not FAIL the guard? — PASS (table row 2; vlg1-ac1 `red` wants exit 0 and the NOTE line)
- CHK4: Is the summary-line collision with other suites addressed? — FAIL (missing): the first draft matched the summary line anywhere in the output — revised in place (last non-blank line paired with exit code; `mismatch1` case)
- CHK5: Is the standalone-run wrapper interaction defined? — FAIL (missing): the first draft did not set `ANTISLOP_VALIDATE_INNER` — revised in place (edit 2; vlg1-ac2)
- CHK6: Do lgc-1's committed criteria stay meaningful after vlg-1? — FAIL (conflicting): their stubs print no summary line, so lgc1-ac2/ac3 would turn red — revised in place (`lgc-criteria/lib.sh` stub appends the summary; Context)
- CHK7: Is note 2's decision stated with evidence that the named scripts are or are not writers? — PASS (Context, Note 2, file:line)
- CHK8: Is lane isolation of `.claude/` state and the git index each proven by a runnable check? — PASS (vlg2-ac2 `untouched`, `gitw`; vlg2-ac1 `linked`)
- CHK9: Is a section that exits early with exit 1 distinguishable from a failed check? — FAIL (ambiguous): the first prototype read the section exit code, so `exit 1` mid-section looked like `fail=1` — revised in place (rc file written only at the section end; vlg2-ac1 `abort`)
- CHK10: Does the runner survive TMPDIR inside the checkout? — FAIL (missing): the first prototype copied its own work dir recursively (observed) — revised in place (`work_rel` exclusion; every stub criterion runs with TMPDIR inside T)
- CHK11: Is the parallelism criterion immune to wall-clock jumps? — FAIL (conflicting): `date +%s` measured 10 s for a 12 s serial run on WSL — revised in place (`mono` from `/proc/uptime`; R7)
- CHK12: Does any criterion run the full serial validate.sh? — PASS (no; vlg2-ac4 runs the lane runner, about 3 min; the serial guard run is merge gate G only)
- CHK13: Does each `mutation:` line state what its criterion prints, observed? — PASS (Verification record)
- CHK14 (replay): Does vlg-3 criterion 4 (scope, `run:` names `tests/validate.sh`) still fail under its own `mutation:` line, given gh317, gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1, mw-step2, mw-step3, rollout-map-1, spec2-unitA and spec2-unitB's recorded class vacuous/host? — PASS (its mutation commits an extra file and the scope regex excludes it; prints `out of scope: ...`)
- CHK15: Do Steps 2 and 3 agree on the runner text that vlg3-ac2 mutates? — PASS (vlg3-ac2's five anchors each match exactly once in vlg-2 edit 1's file; checked by applying the plan's own text)
- CHK16: Are the parallel units' commits independent of each other's in-flight edits? — PASS (explicit-path `git add`; `git diff --quiet HEAD -- <own files>`; R1, R2)
- CHK17: Is each MUST principle answered? — PASS (Constitution check)
- CHK18: Does every contract reach 7/7 under `contract-guard`? — PASS (Verification record)

Glossary drift (prose mode, advisory). Lens 1: none. "merge gate" is used
as P5 defines it. Lens 2: none. Lens 3: "lane", "lane runner" and "leak
guard" are test-suite vocabulary, explained in the files themselves. Scribe
already ruled "leak guard" not load-bearing (lgc closure), and the same
reasoning applies here. No CONTEXT.md entry is proposed.

## Scribe update hint
After all three PASS, update the "lgc closure" open notes 1-3 in
`.claude/agent-memory/scribe/project_epa2_completion.md`:

- note 1 is closed by vlg-1: aborted nested runs FAIL, and completed red runs are a NOTE.
- note 2 is closed for the lane runner by vlg-2 and stays a documented
  accepted gap in the serial guard.
- note 3 is closed by vlg-2 and vlg-3: an opt-in `tests/validate-lanes.sh`,
  177.8 s vs 476 s.

The two marker scripts named in note 2 were found to be non-writers.

## Dispatch contracts (spec-master, fast path, 2026-10-14)

Three dispatchable units; none held.
**Retrieval contract.** No tracker issue exists for these units (fast path).
Fetch a unit's dispatch prompt by reading
`docs/plans/2026-10-14-validate-lanes-and-guard-followups.md` with the Read
tool, finding the `### Unit: <id>` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested
fences are payloads). Its first line is the literal `Unit: <id>`, and
`node bin/contract-guard.js docs/plans/2026-10-14-validate-lanes-and-guard-followups.md --unit=<id>`
finds the block. Commit subjects never carry an issue number.

| unit | files (exact) | shared with | depends on |
|---|---|---|---|
| vlg-1 | `tests/reviewed-dir-leak-guard.test.sh` | none | none |
| vlg-2 | `tests/validate-lanes.sh` (new) | none | none |
| vlg-3 | `tests/validate-lanes.test.sh` (new), `tests/validate.sh`, `CONTRIBUTING.md` | none | vlg-2 |

Dispatch order: vlg-1 and vlg-2 in parallel. vlg-3 after vlg-2 has passed
review, in parallel with vlg-1 if vlg-1 is still open.

**Suggested model:** `haiku` for all three. Every edit is a literal block (two
whole new files, the rest before/after or insert-after at unique anchors),
and no unit on these surfaces has FAIL history. The orchestrator recomputes
the Escalation ladder at dispatch; a tag can raise the tier but never lower
it. The reviewer tier is decided at dispatch by
`hooks/scripts/reviewer-tier.sh` over the actual diff.

**Verification record:** at the plan commit (e13447a plus this plan's files, in a fresh copy of the checkout; e13447a touches no file these units or criteria read) every new criterion was red as each `mutation:` line states, except vlg1-ac2, which is green before the unit on purpose. The three units were then applied by script from this file's own contract text (every anchor and `before:` block matched once) and committed with the contracts' own commands. After that, all criteria were green: vlg1-ac1/ac2, lgc1-ac1..ac3, vlg2-ac1..ac3, vlg3-ac1..ac3, the three `bash -n`, all three scope runs, trailer `1 ` for each, and tail `0`. vlg2-ac4 printed `wall: 169s` with 116 sections. Every `mutation:` line was observed in that copy. `node bin/contract-guard.js docs/plans/2026-10-14-validate-lanes-and-guard-followups.md --unit=<id>` printed `contract-guard: haiku unit=<id> shape=lead score=7/7` for vlg-1, vlg-2 and vlg-3.

### Unit: vlg-1

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 1.

``````
Unit: vlg-1

## Objective
Make `tests/reviewed-dir-leak-guard.test.sh` FAIL when its nested validate.sh run does not reach validate.sh's own closing summary (an aborted run silently shrinks what the guard observes), print a NOTE and not FAIL when the nested run finishes with failing checks (the outer run reports those), and document the repo-root-relative writer blind spot in its header. Two literal edits; nothing else changes.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`, section `### Unit: vlg-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/reviewed-dir-leak-guard.test.sh` (edit 1 inserts after line 15, edit 2 replaces lines 26-51; lines 1-25 stay byte-identical apart from the insertion)

## Ordered edits
1. file: `tests/reviewed-dir-leak-guard.test.sh` (header comment)
   anchor: line matching `# catches a leak that overwrites a marker name the project already has.`
   indent: 0
   insert-after:
~~~~
#
# The guard also FAILs when the nested run does not reach validate.sh's own
# closing summary (vlg-1): a run that aborts part-way would silently shrink
# what the guard observes. A nested run that finishes with failing checks is
# only a NOTE, because the outer run already reports those checks.
#
# Accepted blind spot (docs/plans/2026-10-14-validate-lanes-and-guard-followups.md,
# item 2): a writer that ignores CLAUDE_PROJECT_DIR and writes the marker
# directory relative to the repository root, or under an explicit repo-root
# argument, is not seen here.
~~~~
2. file: `tests/reviewed-dir-leak-guard.test.sh` (nested run and verdict)
   anchor: line matching `sandbox="$(mktemp -d)" || exit 1`
   indent: 0
   before:
~~~~
sandbox="$(mktemp -d)" || exit 1
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.claude/reviewed"

# The nested exit code is discarded on purpose: the outer run already checks
# every suite; this run exists only to observe what the suites write.
CLAUDE_PROJECT_DIR="$sandbox" REVIEWED_DIR_LEAK_GUARD_NESTED=1 \
  bash tests/validate.sh >/dev/null 2>&1 || true

if [ -d "$sandbox/.claude/reviewed" ]; then
  leaked="$(find "$sandbox/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"
else
  leaked="(the .claude/reviewed/ directory itself was removed)"
fi

if [ -z "$leaked" ]; then
  echo "OK   no suite wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ during a full validate.sh run"
  exit 0
fi

echo "FAIL a full validate.sh run wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ -"
echo "     a test suite leaked fixtures into the project directory instead of its"
echo "     own mktemp sandbox. Known past offender: tests/marker-write.test.sh"
echo "     (see docs/plans/2026-09-02-blocked-marker-scoping-gh425.md). Entries:"
printf '%s\n' "$leaked" | sed 's/^/     /'
exit 1
~~~~
   after:
~~~~
sandbox="$(mktemp -d)" || exit 1
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.claude/reviewed"

# The nested run's failing checks are not this guard's business: the outer
# run reports every suite itself. What the guard does need is a nested run
# that reached its own closing summary, because a run that aborts part-way
# silently stops observing the suites after the abort point (vlg-1).
# ANTISLOP_VALIDATE_INNER=1 skips validate.sh's skip-summary wrapper, so the
# closing summary line is the last line of the nested output.
nested_out="$sandbox/nested.out"
CLAUDE_PROJECT_DIR="$sandbox" REVIEWED_DIR_LEAK_GUARD_NESTED=1 ANTISLOP_VALIDATE_INNER=1 \
  bash tests/validate.sh >"$nested_out" 2>&1
nested_rc=$?
nested_last="$(grep -v '^[[:space:]]*$' "$nested_out" | tail -n 1)"

status=0
case "$nested_rc:$nested_last" in
  "0:All checks passed.") ;;
  "1:One or more checks FAILED.")
    echo "NOTE the nested validate.sh run reported failing checks (exit 1); the outer run reports them itself" ;;
  *)
    echo "FAIL the nested validate.sh run did not finish (exit $nested_rc; last line: ${nested_last:-(no output)}) -"
    echo "     an aborted run stops observing every suite after the abort point, so"
    echo "     the leak check below covers only part of the suite."
    status=1 ;;
esac

if [ -d "$sandbox/.claude/reviewed" ]; then
  leaked="$(find "$sandbox/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"
else
  leaked="(the .claude/reviewed/ directory itself was removed)"
fi

if [ -n "$leaked" ]; then
  echo "FAIL a full validate.sh run wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ -"
  echo "     a test suite leaked fixtures into the project directory instead of its"
  echo "     own mktemp sandbox. Known past offender: tests/marker-write.test.sh"
  echo "     (see docs/plans/2026-09-02-blocked-marker-scoping-gh425.md). Entries:"
  printf '%s\n' "$leaked" | sed 's/^/     /'
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "OK   no suite wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ during a full validate.sh run"
fi
exit "$status"
~~~~
3. command: `git add tests/reviewed-dir-leak-guard.test.sh && git commit -m "fix(vlg-1): leak guard fails a nested validate.sh run that did not finish" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
4. command: `git diff --quiet HEAD -- tests/reviewed-dir-leak-guard.test.sh`
   expect: 0

## Do NOT touch
- `tests/reviewed-dir-leak-guard.test.sh` lines 16-25 (the `set`/`cd` lines and the `REVIEWED_DIR_LEAK_GUARD_NESTED` early exit): byte-identical.
- `tests/validate.sh`: unchanged; section 101 keeps calling the guard as it does today.
- `tests/validate-lanes.sh`, `tests/validate-lanes.test.sh`, `CONTRIBUTING.md`: sibling units' files.
- `docs/plans/vlg-criteria/`, `docs/plans/lgc-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/vlg-criteria/vlg1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: write `  *":All checks passed.") ;;` in place of edit 2's `  "0:All checks passed.") ;;` (the exit code is ignored); prints `mismatch1: exit 0, want 1`, exit 1 (observed). Before the unit it prints `red: output does not contain NOTE the nested validate.sh run reported failing checks` (observed at the plan commit).
2. run: `bash docs/plans/vlg-criteria/vlg1-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; it keeps the new completion check from tripping on the skip-summary wrapper.
   mutation: delete ` ANTISLOP_VALIDATE_INNER=1` from edit 2's nested-run line; prints `wrapper: exit 1, want 0`, exit 1 (observed).
3. run: `bash docs/plans/lgc-criteria/lgc1-ac1.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; leak detection must not regress.
   mutation: delete the `status=1` line inside the `if [ -n "$leaked" ]` block; prints `fixture: guard exit 0, want 1`, exit 1 (observed).
4. run: `bash docs/plans/lgc-criteria/lgc1-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; a concurrent write into the project's own directory still does not FAIL.
   mutation: in edit 2's `leaked=` line write `find "$CLAUDE_PROJECT_DIR/` in place of `find "$sandbox/` (the guard watches the live directory again); prints `concurrent: guard exit 1, want 0`, exit 1 (observed).
5. run: `bash docs/plans/lgc-criteria/lgc1-ac3.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; the real gh425 leak is still caught.
   mutation: delete edit 2's `mkdir -p "$sandbox/.claude/reviewed"` line; prints `control: guard exit 1, want 0`, exit 1 (observed: the missing directory reads as removed).
6. run: `bash -n tests/reviewed-dir-leak-guard.test.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; it guards the file's syntax.
   mutation: delete the `esac` line of the new `case`; prints `line 63: syntax error near unexpected token`, exit 2 (observed).
7. run: `bash docs/plans/epf-criteria/scope.sh vlg-1 'tests/reviewed-dir-leak-guard\.test\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
8. run: `bash docs/plans/epf-criteria/range.sh vlg-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
9. run: `bash docs/plans/epf-criteria/range.sh vlg-1 tail tests/reviewed-dir-leak-guard.test.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no tests/reviewed-dir-leak-guard.test.sh (the file is itself a test; criteria 1-2 are the tests for this change, and criterion 1 was red before it)
blast-radius: tests/reviewed-dir-leak-guard.test.sh:1-51 (whole file; only caller tests/validate.sh:1111-1117, section 101); no shipped file names it.
commit-message: fix(vlg-1): leak guard fails a nested validate.sh run that did not finish
trailer: the trailer names the model you actually ran on.
gate: never type a Bash command whose text spells the marker directory path; reviewed-path-gate.sh blocks it by text. Apply edits 1-2 with Edit (path-checked only). If Edit is unavailable, STOP and report; do not use a heredoc.
measured: at e13447a the file is 51 lines and each anchor occurs once; criteria 1-5 finish in a few seconds; do NOT run the full tests/validate.sh or the guard on its own (about 480 s nested; the orchestrator's merge gate G does that).
diagnosis: none
review-packet:
~~~
unit: vlg-1 (plan docs/plans/2026-10-14-validate-lanes-and-guard-followups.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: vlg-2

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 2.

``````
Unit: vlg-2

## Objective
Add `tests/validate-lanes.sh`, an opt-in runner that executes the sections of `tests/validate.sh` in N parallel lanes (default 3), each lane in a private copy of the checkout (own `.claude/` state, own git index, `CLAUDE_PROJECT_DIR` pointed at the copy), reports aborted sections, and FAILs any section that changes the lane copy's marker directory (including repo-root-relative writes). `tests/validate.sh` itself is not changed. One new file with exactly the content below.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`, section `### Unit: vlg-2`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/validate-lanes.sh` (anchor: new file)

## Ordered edits
1. file: `tests/validate-lanes.sh`
   anchor: new file (create it with exactly this content, using the Write tool)
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Opt-in parallel runner for tests/validate.sh (vlg-2). The default merge gate
# is still `bash tests/validate.sh`, run serially; this file never changes it.
#
# Usage: bash tests/validate-lanes.sh [--lanes N]     (N: 1-8, default 3)
#
# Each lane gets its own full copy of this checkout (working tree and .git,
# minus .claude/worktrees), so every lane has a private .claude/ state tree
# and a private git index. CLAUDE_PROJECT_DIR is pointed at the lane copy,
# never at this checkout. Sections are cut out of tests/validate.sh at its
# `echo "== ` headers and claimed by whichever lane is free (heaviest first).
# Each section's output is printed in header order once every lane is done.
#
# Leak check: before and after every section, the lane copy's
# .claude/reviewed/ is fingerprinted (name, type, size and mtime of every
# entry). Any change is a FAIL naming the section. Because the copy is private to the lane, this
# sees leaks through CLAUDE_PROJECT_DIR AND writes relative to the repository
# root, with no race against a live reviewer. Section 101's nested leak guard
# is skipped here (REVIEWED_DIR_LEAK_GUARD_NESTED=1); it would re-run the
# whole suite serially inside one lane.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

lanes=3
while [ $# -gt 0 ]; do
  case "$1" in
    --lanes) lanes="${2:-}"; shift 2 || { echo "usage: bash tests/validate-lanes.sh [--lanes N]"; exit 2; } ;;
    --lanes=*) lanes="${1#--lanes=}"; shift ;;
    *) echo "usage: bash tests/validate-lanes.sh [--lanes N]"; exit 2 ;;
  esac
done
case "$lanes" in
  [1-8]) ;;
  *) echo "FAIL --lanes must be an integer from 1 to 8 (got: $lanes)"; exit 2 ;;
esac

if [ ! -d "$root/.git" ]; then
  echo "FAIL $root/.git is not a directory (a linked worktree or no repository);"
  echo "     a lane copy would share its git index. Run from a main checkout."
  exit 2
fi

suite="$root/tests/validate.sh"
count="$(grep -c '^echo "== ' "$suite")"
end_line="$(grep -n '^if \[ "\$fail" -eq 0 \]; then$' "$suite" | tail -n 1 | cut -d: -f1)"
if [ "$count" -lt 1 ] || [ -z "$end_line" ]; then
  echo "FAIL could not find the section headers or the closing summary block in tests/validate.sh"
  exit 2
fi

work="$(mktemp -d)" || exit 2
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
# When TMPDIR lies inside the checkout, keep the work dir out of the copies.
case "$work" in "$root"/*) work_rel="${work#"$root"/}" ;; *) work_rel= ;; esac
mkdir -p "$work/sec" "$work/out" "$work/rc" "$work/leak" "$work/claim"

# Cut section i (1-based header order) into $work/sec/i.body.
awk -v dir="$work/sec" -v endl="$end_line" '
  /^echo "== / { n++ }
  n > 0 && FNR < endl { print > (dir "/" n ".body") }
' "$suite"

# Claim order: known-heavy sections first (matched on header text, so a
# renumbering only costs balance, never correctness), then the rest in order.
heavy='probe-hook-identity|unit-outcomes|human-decision gate|configless write-deny|reviewed-path gate'
order="$(awk -v re="$heavy" '/^echo "== /{n++; if ($0 ~ re) print n}' "$suite")
$(seq 1 "$count")"

fingerprint() { # <lane-root>: name, type, size and mtime of every entry
  local d="$1/.claude/reviewed"
  if [ -d "$d" ]; then
    find "$d" -mindepth 1 -printf '%P %y %s %T@\n' | sort
  else
    echo "(the .claude/reviewed/ directory itself is missing)"
  fi
}

lane() { # <k>
  local k="$1" l="$work/lane$1" i before after rc
  mkdir -p "$l"
  tar -C "$root" --exclude=./.claude/worktrees ${work_rel:+"--exclude=./$work_rel"} -cf - . \
    | tar -C "$l" -xf - || { echo 2 > "$work/lane$k.copyfail"; return; }
  rm -f "$l/.git/index.lock"
  for i in $order; do
    mkdir "$work/claim/$i" 2>/dev/null || continue
    before="$(fingerprint "$l")"
    # The section records its own $fail only if it reaches its end; a section
    # that exits early (any exit code, 1 included) leaves no rc file.
    { printf 'set -uo pipefail\ncd %q || exit 2\nfail=0\n' "$l"
      cat "$work/sec/$i.body"
      printf '\necho "$fail" > %q\nexit "$fail"\n' "$work/rc/$i"; } > "$work/sec/$i.sh"
    (cd "$l" && CLAUDE_PROJECT_DIR="$l" REVIEWED_DIR_LEAK_GUARD_NESTED=1 ANTISLOP_VALIDATE_INNER=1 \
      bash "$work/sec/$i.sh") > "$work/out/$i" 2>&1
    rc=$?
    [ -f "$work/rc/$i" ] || echo "FAIL section $i aborted (exit $rc)" >> "$work/out/$i"
    after="$(fingerprint "$l")"
    if [ "$before" != "$after" ]; then
      { echo "FAIL section $i changed the lane copy's .claude/reviewed/ (a leak via CLAUDE_PROJECT_DIR or a repo-root-relative path):"
        diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/     /'; } >> "$work/out/$i"
      echo 1 > "$work/leak/$i"
    fi
  done
}

start=$(date +%s)
for k in $(seq 1 "$lanes"); do lane "$k" & done
wait

fail=0
for k in $(seq 1 "$lanes"); do
  [ -e "$work/lane$k.copyfail" ] && { echo "FAIL lane $k: could not copy the checkout"; fail=1; }
done
for i in $(seq 1 "$count"); do
  if [ ! -f "$work/out/$i" ]; then echo "FAIL section $i never ran"; fail=1; continue; fi
  cat "$work/out/$i"
  [ "$(cat "$work/rc/$i" 2>/dev/null)" = 0 ] || fail=1
  [ -f "$work/leak/$i" ] && fail=1
done

echo
echo "== lanes: $lanes, sections: $count, wall: $(( $(date +%s) - start ))s =="
echo "Skipped checks: $(cat "$work"/out/* 2>/dev/null | grep -c '^SKIP')"
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
~~~~
2. command: `git add tests/validate-lanes.sh && git commit -m "feat(vlg-2): opt-in parallel lane runner for tests/validate.sh" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
3. command: `git diff --quiet HEAD -- tests/validate-lanes.sh`
   expect: 0

## Do NOT touch
- `tests/validate.sh`: unchanged; the serial run stays the merge gate.
- `tests/reviewed-dir-leak-guard.test.sh`, `tests/validate-lanes.test.sh`, `CONTRIBUTING.md`: sibling units' files.
- `docs/plans/vlg-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/vlg-criteria/vlg2-ac1.sh`
   exit: 0
   stdout: empty
   mutation: write `[0-8])` in place of `[1-8])` in the `--lanes` value check; prints `lanes=0: exit 1, want 2`, exit 1 (observed). Write `n > 0 {` in place of `n > 0 && FNR < endl {` (the last section swallows the closing summary block); prints `green: exit 1, want 0` (observed). Before the unit it prints `cp: cannot stat` (observed).
2. run: `bash docs/plans/vlg-criteria/vlg2-ac2.sh`
   exit: 0
   stdout: empty
   mutation: write `CLAUDE_PROJECT_DIR="$root"` in place of `CLAUDE_PROJECT_DIR="$l"`; prints `envvar: exit 0, want 1`, exit 1 (observed). Symlinking each lane copy's `.git` to the source's prints `gitw: exit 1, want 0` (observed).
3. run: `bash docs/plans/vlg-criteria/vlg2-ac3.sh`
   exit: 0
   stdout: empty
   mutation: write `do lane "$k"; done` in place of `do lane "$k" & done`; prints `par: --lanes 3 took 12s, want <= 8`, exit 1 (observed).
4. run: `bash docs/plans/vlg-criteria/vlg2-ac4.sh`
   exit: 0
   stdout: one line matching `^wall: [0-9]+s$` (about 180 s; run it with the Bash tool's timeout at 600000 ms)
   mutation: before the unit it prints `runner exit 127, want 0`, exit 1 (observed at the plan commit); a lane-only failure prints its `FAIL` lines and exits 1.
5. run: `bash -n tests/validate-lanes.sh`
   exit: 0
   stdout: empty
   mutation: delete the `esac` line closing the `--lanes` value check; prints `line 37: syntax error near unexpected token`, exit 2 (observed).
6. run: `bash docs/plans/epf-criteria/scope.sh vlg-2 'tests/validate-lanes\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
7. run: `bash docs/plans/epf-criteria/range.sh vlg-2 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
8. run: `bash docs/plans/epf-criteria/range.sh vlg-2 tail tests/validate-lanes.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no tests/validate-lanes.sh (criteria 1-4 are the tests and are red before the unit, `cp: cannot stat` / `runner exit 127`; vlg-3 adds the in-repo regression test)
blast-radius: tests/validate-lanes.sh:1-131 (new file; no caller until vlg-3 adds tests/validate-lanes.test.sh); tests/validate.sh:1284 is the closing summary line the runner anchors on.
commit-message: feat(vlg-2): opt-in parallel lane runner for tests/validate.sh
trailer: the trailer names the model you actually ran on.
gate: the file's text spells the marker directory path, so author it with the Write tool only (path-checked). Never put its content in a Bash heredoc; reviewed-path-gate.sh blocks that by text, and rewording to get past it is a bypass. If Write is unavailable, STOP and report.
measured: at 70458f7 this exact text ran the real suite in 3 lanes in 177.8 s (serial 476 s), exit 0, output parity with serial; criteria 1-3 take about 20 s together; criterion 4 about 3 min; do NOT run the serial tests/validate.sh.
diagnosis: none
review-packet:
~~~
unit: vlg-2 (plan docs/plans/2026-10-14-validate-lanes-and-guard-followups.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: vlg-3

- Suggested model: `haiku`
- Depends on / blocked by: vlg-2 (its test copies `tests/validate-lanes.sh`; criterion 2 mutates that file's exact text)
- Spec step: Step 3.

``````
Unit: vlg-3

## Objective
Add `tests/validate-lanes.test.sh`, a stub-based regression test for the lane runner, register it as the last section of `tests/validate.sh` (section 116), and add one CONTRIBUTING.md bullet describing the opt-in runner and stating that `bash tests/validate.sh` stays the merge gate. Three literal edits; nothing else changes.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`, section `### Unit: vlg-3`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/validate-lanes.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `  echo "FAIL tests/unit-outcomes.test.js"`)
- `CONTRIBUTING.md` (anchor: line matching `  marketplace.json/plugin.json consistency.`)

## Ordered edits
1. file: `tests/validate-lanes.test.sh`
   anchor: new file (create it with exactly this content, using the Write tool)
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Regression tests for tests/validate-lanes.sh (vlg-3), the opt-in parallel
# runner for tests/validate.sh. Every case builds a throwaway git tree under
# a private mktemp root, with a copy of the runner and a stub validate.sh,
# so nothing here reads or writes this checkout's own .claude/ state.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
runner="$(pwd)/tests/validate-lanes.sh"
root="$(mktemp -d)" || exit 1
trap 'rm -rf "$root"' EXIT
failures=0

# tree <name> <sections>: a git tree holding the runner and a stub suite made
# of validate.sh's preamble, <sections> and its closing summary. Prints it.
tree() {
  local t="$root/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp"
  cp "$runner" "$t/tests/validate-lanes.sh"
  { printf '#!/usr/bin/env bash\nset -uo pipefail\ncd "$(dirname "$0")/.."\nfail=0\n'
    printf '%s\n' "$2"
    printf 'echo\nif [ "$fail" -eq 0 ]; then\n  echo "All checks passed."\nelse\n  echo "One or more checks FAILED."\nfi\nexit "$fail"\n'
  } > "$t/tests/validate.sh"
  printf 'PASS old x\n' > "$t/.claude/reviewed/old.pass"
  (cd "$t" && git init -q && git add tests \
    && git -c user.name=t -c user.email=t@t commit -qm init) >/dev/null 2>&1
  printf '%s\n' "$t"
}
sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "${2:-echo \"OK   s$1\"}"; }

# run <tree> [args]: run the tree's runner as the harness would. Sets RC, OUT.
run() {
  local t="$1"; shift
  OUT="$(cd "$t" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" bash tests/validate-lanes.sh "$@" 2>&1)"
  RC=$?
}

# check <id> <description> <want-rc> <substring>...: '!' prefix = must be absent.
check() {
  local id="$1" desc="$2" want="$3" s bad=""; shift 3
  [ "$RC" = "$want" ] || bad="exit $RC, want $want"
  for s in "$@"; do
    case "$s" in
      '!'*) case "$OUT" in *"${s#!}"*) bad="${bad:+$bad; }unexpected: ${s#!}" ;; esac ;;
      *) case "$OUT" in *"$s"*) ;; *) bad="${bad:+$bad; }missing: $s" ;; esac ;;
    esac
  done
  if [ -z "$bad" ]; then
    echo "ok   ($id) $desc"
  else
    echo "FAIL ($id) $desc: $bad"
    printf '%s\n' "$OUT" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}

t=$(tree green "$(sec 1; sec 2; sec 3)"); run "$t"
order=$(printf '%s\n' "$OUT" | grep -E '^== s[0-9] ==$' | tr -d '=s ' | tr -d '\n')
last=$(printf '%s\n' "$OUT" | grep -v '^[[:space:]]*$' | tail -n 1)
[ "$order" = 123 ] && [ "$last" = 'All checks passed.' ] || OUT="order=$order last=$last
$OUT"
check L1 'all sections pass: exit 0, header order kept, summary is the last line' 0 \
  '== lanes: 3, sections: 3,' "!order=" '!FAIL'

t=$(tree red "$(sec 1 'echo "FAIL s1"; fail=1'; sec 2)"); run "$t"
check L2 'a failing check: exit 1, later sections still run' 1 'FAIL s1' 'OK   s2' 'One or more checks FAILED.' '!All checks passed.'

t=$(tree abort "$(sec 1 'echo "half"; exit 1; echo "OK   tail"'; sec 2)"); run "$t" --lanes 2
check L3 'a section that exits early is reported as aborted, even with exit 1' 1 \
  'FAIL section 1 aborted (exit 1)' '!OK   tail' 'OK   s2'

t=$(tree rel "$(sec 1 'printf x > .claude/reviewed/relA.pass'; sec 2)"); run "$t"
check L4 'a repo-root-relative marker write is a FAIL naming the section' 1 \
  'FAIL section 1 changed' 'relA.pass' '!FAIL section 2 changed'
[ "$(ls -A "$t/.claude/reviewed")" = old.pass ] || { echo "FAIL (L4b) the source tree's marker directory changed"; failures=$((failures + 1)); }

t=$(tree env "$(sec 1 'printf x > "$CLAUDE_PROJECT_DIR/.claude/reviewed/envB.fail"'; sec 2 'echo "CPD=$CLAUDE_PROJECT_DIR"')"); run "$t"
check L5 'a CLAUDE_PROJECT_DIR marker write is a FAIL; the variable never names the source tree' 1 \
  'FAIL section 1 changed' 'envB.fail' "!CPD=$t
"
[ "$(ls -A "$t/.claude/reviewed")" = old.pass ] || { echo "FAIL (L5b) the source tree's marker directory changed"; failures=$((failures + 1)); }

g='git -c user.name=t -c user.email=t@t commit -qm lane --allow-empty || fail=1'
t=$(tree git "$(sec 1 "$g"; sec 2 "$g"; sec 3 "$g")"); head0=$(git -C "$t" rev-parse HEAD); run "$t"
[ "$(git -C "$t" rev-parse HEAD)" = "$head0" ] || OUT="source HEAD moved
$OUT"
check L6 'git commits in sections stay in the lane copies' 0 '!source HEAD moved' 'All checks passed.'

for bad in 0 9 x; do
  t=$(tree "bad$bad" "$(sec 1)"); run "$t" --lanes "$bad"
  check "L7-$bad" "--lanes $bad is refused" 2 '!All checks passed.'
done

t=$(tree linked "$(sec 1)"); rm -rf "$t/.git"; printf 'gitdir: /nonexistent\n' > "$t/.git"; run "$t"
check L8 'a linked worktree (.git is a file) is refused' 2 'is not a directory'

[ -z "$(find "$root"/*/tmp -mindepth 1 -print -quit)" ] \
  || { echo "FAIL (L9) the runner left files in TMPDIR"; failures=$((failures + 1)); }

echo
if [ "$failures" -eq 0 ]; then
  echo "All validate-lanes cases passed."
  exit 0
fi
echo "$failures validate-lanes case(s) FAILED."
exit 1
~~~~
2. file: `tests/validate.sh` (append section 116 after the unit-outcomes section)
   anchor: line matching `  echo "FAIL tests/unit-outcomes.test.js"`
   indent: 0
   before:
~~~~
  echo "FAIL tests/unit-outcomes.test.js"
  fail=1
fi
~~~~
   after:
~~~~
  echo "FAIL tests/unit-outcomes.test.js"
  fail=1
fi

echo
echo "== tests/validate-lanes.sh: opt-in parallel lane runner (Bash, vlg-3) =="
if bash tests/validate-lanes.test.sh; then
  echo "OK   tests/validate-lanes.test.sh"
else
  echo "FAIL tests/validate-lanes.test.sh"
  fail=1
fi
~~~~
3. file: `CONTRIBUTING.md` (bullet after the validate.sh bullet)
   anchor: line matching `  marketplace.json/plugin.json consistency.`
   indent: 0
   insert-after:
~~~~
- `bash tests/validate-lanes.sh` is an opt-in parallel run of the same
  sections (default 3 lanes, `--lanes N` for 1-8). Each lane works in a
  private copy of the checkout, and any section that changes the lane's
  `.claude/reviewed/` FAILs, including a write relative to the repository
  root, which the serial leak guard cannot see. It skips the leak guard's
  nested run, so `bash tests/validate.sh` stays the merge gate.
~~~~
4. command: `git add tests/validate-lanes.test.sh tests/validate.sh CONTRIBUTING.md && git commit -m "test(vlg-3): lane runner regression test, registered in validate.sh" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
5. command: `git diff --quiet HEAD -- tests/validate-lanes.test.sh tests/validate.sh CONTRIBUTING.md`
   expect: 0

## Do NOT touch
- `tests/validate-lanes.sh`: vlg-2's file; criterion 2 mutates copies of it, never the file.
- `tests/validate.sh` outside edit 2, including its closing summary block at the end: byte-identical.
- `tests/reviewed-dir-leak-guard.test.sh`: vlg-1's file.
- `docs/plans/vlg-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/vlg-criteria/vlg3-ac1.sh`
   exit: 0
   stdout: empty
   mutation: delete edit 2's new section from tests/validate.sh; prints `section count is 115, want 116`, exit 1 (observed). Before the unit it prints `test exit 127, want 0` (observed).
2. run: `bash docs/plans/vlg-criteria/vlg3-ac2.sh`
   exit: 0
   stdout: empty
   mutation: delete the test's `check L4 ...` call and its `L4b` line; prints `leakflag: test did not print FAIL (L4)`, exit 1 (observed). Before the unit it prints `tests/validate-lanes.test.sh missing` (observed).
3. run: `bash docs/plans/vlg-criteria/vlg3-ac3.sh`
   exit: 0
   stdout: empty
   mutation: delete the bullet's last line; prints `lane-runner bullet not present verbatim exactly once`, exit 1 (observed; also the output before the unit).
4. run: `bash docs/plans/epf-criteria/scope.sh vlg-3 'tests/validate-lanes\.test\.sh|tests/validate\.sh|CONTRIBUTING\.md'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate-lanes.sh`; prints `out of scope: tests/validate-lanes.sh`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh vlg-3 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh vlg-3 tail tests/validate-lanes.test.sh CONTRIBUTING.md`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on either file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/validate-lanes.test.sh (it is the regression test; criterion 2 proves it red against five runner mutants)
blast-radius: tests/validate.sh:1275-1282 (the last section, unit-outcomes; the new section goes after it and before the closing summary at :1284); CONTRIBUTING.md:30-33 (the validate.sh bullet the new bullet follows); tests/validate-lanes.test.sh is new.
commit-message: test(vlg-3): lane runner regression test, registered in validate.sh
trailer: the trailer names the model you actually ran on.
gate: the test file's text spells the marker directory path, so author it with the Write tool only (path-checked), and apply edits 2-3 with Edit. Never put the content in a Bash heredoc; reviewed-path-gate.sh blocks that by text, and rewording to get past it is a bypass. If Write/Edit are unavailable, STOP and report.
measured: at e13447a each anchor occurs once and validate.sh has 115 sections (116 after edit 2); the test takes about 0.35 s; criteria 1-3 about 3 s together (re-measured with /proc/uptime at 5178319 on 2026-10-14; the first estimate, 5 s and 40 s, was stale); do NOT run the full tests/validate.sh (the merge gate G covers section 116 through `vsec 111 999`).
diagnosis: none
review-packet:
~~~
unit: vlg-3 (plan docs/plans/2026-10-14-validate-lanes-and-guard-followups.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
