# Leak guard without false FAILs under concurrent marker writes (watch item j)

Status: FINAL (spec-master 2026-10-14). One fast-path unit, `lgc-1`.
Open Question 1 has a recommended default; the unit is dispatchable under it.

## Goal

`tests/reviewed-dir-leak-guard.test.sh` (validate.sh section 101, gh425) must
stop turning a legitimate marker write by a live reviewer or implementer into
a validate.sh exit 1, and must keep failing when a validate.sh suite leaks
fixture entries through `CLAUDE_PROJECT_DIR` into a project's marker
directory. Goal clauses and the criteria that carry them:

- G1 "a legitimate concurrent add or remove no longer FAILs": criterion 2.
- G2 "a fixture-named leak still FAILs": criteria 1 (stub leaks) and 3 (the
  real gh425 leak, reproduced from a reverted `tests/marker-write.test.sh`).
- G3 "criteria never read, list or write the checkout's own marker
  directory": every criterion runs the guard inside a throwaway tree (lib.sh).

## Context

### What the guard does today (read at 4f92d37)

`tests/reviewed-dir-leak-guard.test.sh`, 33 lines: lists the checkout's own
marker directory (line 18), runs a full nested `bash tests/validate.sh` with
`CLAUDE_PROJECT_DIR="$(pwd)"` and `REVIEWED_DIR_LEAK_GUARD_NESTED=1`, output
and exit discarded (19-20), lists again (21), and exits 1 with a diff if the
two listings differ (23-33). The nested run takes minutes, so any marker a
reviewer writes or removes in that window makes the outer run exit 1. That is
the most likely cause of watch item j. Whether it fired in the original
incident cannot be checked (output not kept). It needs a live concurrent
write, so the 30/30 green concurrent runs (vtmp-1 plan) do not contradict it.

Called once, from `tests/validate.sh:1111-1117` (section header `reviewed-dir
leak guard`). No shipped file (`bin/ hooks/ templates/ agents/ adapters/
skills/`) names it. `protectedPaths` is empty and `fileHashes` does not hash
it.

### What actually leaks, and how (measured 2026-10-14)

The only leak on record is gh425 (F3): `hooks/scripts/marker-write.sh:27`
writes under `${CLAUDE_PROJECT_DIR:-.}/.claude`, and
`tests/marker-write.test.sh` isolated by `cd` only. Fixed by f3dca44, which
pins `CLAUDE_PROJECT_DIR="$proj"` / `"$gproj"` on each helper call. The
mechanism is the environment variable, not the cwd.

Reverting those pins in a temp copy and running the suite with
`CLAUDE_PROJECT_DIR` pointed at a sandbox leaks **unitA.pass, unitB.fail,
unitC.blocked, unitG.fail** today. gh425 F3 listed spec2-unitC.pass instead
of unitG.fail. The suite now has `set -e` aborting at item12-1 (a `grep -c`
on the missing unitG.fail), before the spec2-unitC call. Criterion 3 asserts
the measured set.

### Option chosen: (3) relocate the nested run into a sandbox project

The nested run gets `CLAUDE_PROJECT_DIR=<mktemp -d sandbox>` with an empty
`.claude/reviewed/` pre-created inside it. Afterwards the guard FAILs if the
sandbox marker directory has any entry, or has been removed. It never lists
the checkout's own marker directory.

- **Why it removes the false FAIL:** the guard's only observation point is a
  directory that no reviewer, implementer or other session knows exists.
  Concurrent writes to the live directory are not observed at all.
- **Why it keeps the purpose:** a suite that leaks through the inherited
  `CLAUDE_PROJECT_DIR` (the gh425 mechanism, and the `${CLAUDE_PROJECT_DIR:-.}`
  pattern every hook uses) now leaks into the sandbox, where the guard sees
  it. Criterion 3 reproduces the real leak and gets exit 1 naming all four
  fixtures.
- **Strictly stronger in one way:** the sandbox starts empty, so a leak that
  overwrites a name the project already has is caught. The listing diff
  could not see that. It was the gh425 F4 harm (spec2-unitC.pass destroyed)
  and gh425-2's PASS note 3. Criterion 1's `overwrite` case is red at HEAD.
- **Pre-created directory:** a leaking suite that writes without `mkdir -p`
  would fail silently into a missing directory, so the guard creates it.
  Criterion 1's `fixture` case writes with no mkdir. Removing the guard's
  `mkdir -p` line makes it print `fixture: output does not name
  unitC.blocked` (observed).

Rejected:

- **(1) fail only on fixture-named new entries.** Fixture names are
  arbitrary and collide with real unit ids. spec2-unitC is both a gh425
  fixture and a real unit (F4). A name filter also still reads the live
  directory, so a concurrent reviewer marker that happens to match the pattern
  still races. The pattern list would also need updating for every new suite.
- **(2) attribute entries by mtime window or a marker.** A concurrent
  reviewer write lands inside the same window as the nested run, so mtime
  cannot separate them. A distinguishing marker would mean changing every
  suite's fixture writer, which is a much bigger change.
- **(3') drop the nested run.** That loses the only standing regression guard
  for a leak that recurred once already (gh425 F9).

**Coverage given up (Open Question 1):** the old guard would also have caught
a suite that writes the literal path relative to the repository root and
ignores `CLAUDE_PROJECT_DIR`. The new guard does not. No such writer is on
record. Catching one without also catching concurrent reviewer writes would
need the nested run to execute in a full copy of the checkout, which is out
of scope here. Criterion 2's stand-in reviewer writes by path into the tree's
own directory, so the criterion makes this trade explicit.

### Merge gate does not exercise this guard

The project's merge-gate runs (the four `vsec` ranges in
`docs/plans/epf-criteria/lib.sh`) set `REVIEWED_DIR_LEAK_GUARD_NESTED=1`, so
section 101 is a no-op there. They never exercise the guard, before or after
this unit. The unit's criteria therefore run the guard directly. Each
criterion builds a throwaway tree T (guard copy in `T/tests/`, stub
`T/tests/validate.sh`, T's own `.claude/reviewed/` holding `old.pass`). The
guard `cd`s to its own `..`, so it runs against T, with
`CLAUDE_PROJECT_DIR=T` as the harness would set it. No criterion runs the
real full validate.sh. Each one finishes in under a second (criterion 3
measured 0.33 s).

### Prior FAIL history and notes sweep

- `lgc-1` is a new unit id. No vacuous/host replay item applies: none of the
  recorded units in `docs/audits/unit-outcomes/2026-10-06.jsonl` with FAIL
  class vacuous or host touched the guard, `epf-criteria/scope.sh`,
  `range.sh` or `lib.sh` (computed 2026-10-14).
- `bash bin/marker-audit.sh . --notes --surface=tests/reviewed-dir-leak-guard.test.sh`,
  2026-10-14: 5 notes (0 NOTE[spec], 1 NOTE[code], 4 untagged, all from
  gh425-2 or rnf-2). Dispositions:
  - gh425-2 note 2 (`cd` without `|| exit 1`): **taken**, edit 1 adds it.
  - gh425-2 note 3 (a content overwrite is invisible): **closed** by the
    empty sandbox; criterion 1 `overwrite`.
  - gh425-2 note 4 (nested pass prints a green OK for a skipped check):
    **deferred**, out of scope. It is cosmetic, and the nested output is
    discarded anyway.
  - gh425-2 note 5 (`|| true` undocumented): **taken**, edit 2 comments it.
  - rnf-2 NOTE[code] (a full validate.sh exceeds 600 s because of this
    nested run): **recorded, not acted on**. Runtime is unchanged by this
    unit; see Risks R3.
  The sweep is best effort (per-clone, gitignored records).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-10-14 Functional scope & success criteria: Q Which of the three candidate options? → A (self-resolved): option 3 (sandbox project for the nested run), per Context; options 1 and 2 still read the live directory and race, and option 1's names collide with real unit ids (spec2-unitC).
- 2026-10-14 Edge cases / failure handling: Q What if a suite removes the marker directory itself, or writes into it without mkdir? → A (self-resolved): the guard pre-creates the sandbox directory, and a missing directory afterwards is a FAIL with the message `(the .claude/reviewed/ directory itself was removed)`; criterion 1 `fixture` and `removal` cases.
- 2026-10-14 Technical constraints & tradeoffs: Q The new guard no longer sees a cwd-relative write into the live directory. Accept? → A (self-resolved, default; confirm via Open Question 1): accept; no such writer is on record, and detecting one without also detecting concurrent reviewer writes needs a full-checkout copy.
- 2026-10-14 Completion / acceptance signals: Q How can criteria prove "still catches a real leak" without the real full validate.sh (over 600 s doubled) and without touching the live directory? → A (self-resolved): throwaway tree with a stub validate.sh. Criterion 3 runs a copy of `tests/marker-write.test.sh` with f3dca44 reverted, plus an unreverted control.

## Risks / dependencies

- R1: One unit, one file (`tests/reviewed-dir-leak-guard.test.sh`). No
  dependency. `tests/validate.sh` is unchanged.
- R2: The criteria are scripts in `docs/plans/lgc-criteria/`, committed with
  this plan and read-only for the unit. They also use
  `docs/plans/epf-criteria/scope.sh` and `range.sh`. The unit's commits are
  found by the subject scope `^[a-z]+\(lgc-1\): `.
- R3: The full validate.sh still runs the suite twice (about 435 s nested,
  over the 600 s Bash cap together). This unit does not change that, and the
  unit must not run the whole file (P5 line).
- R4: Never type a command whose text spells the marker directory path:
  `reviewed-path-gate.sh` blocks it by text. Run `bash <script>`. Apply the
  edits with Edit/Write (path-checked only). If Edit/Write are unavailable,
  STOP and report. A Bash heredoc carrying this file's content spells the
  path and is blocked; rewording it to dodge the gate is a bypass.
- R5: Criterion 3 depends on `tests/marker-write.test.sh` still carrying the
  f3dca44 pins. If a later unit removes them, criterion 3 prints
  `marker-write.test.sh no longer carries the f3dca44 pin` rather than
  passing vacuously.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. All three `lgc1-*` scripts were run
  at 4f92d37 (ac1 and ac2 red, ac3 green on purpose) and green with the
  edits applied in a scratch worktree, and each `mutation:` line was
  observed there.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  criteria are committed scripts, and the edits are literal before/after
  blocks.
- P3 "Version-stamp discipline": satisfied, vacuously. No `agents/*.md` or
  `templates/*` change.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona
  prose changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied with a scoped
  deviation. The guard is run directly through stubs, and the full file is
  not run (R3). The merge gate's `vsec` ranges skip section 101 by design
  (Context).

## Steps

### Step 1: lgc-1, the leak guard watches a sandbox project
**Affected files:** `tests/reviewed-dir-leak-guard.test.sh` only.
**Acceptance:** `lgc1-ac1.sh` (stub leaks still FAIL: fixture name with no
mkdir, overwrite of an existing name, directory removal); `lgc1-ac2.sh` (a
concurrent add+remove in the tree's own directory passes, and TMPDIR is left
clean); `lgc1-ac3.sh` (the reverted gh425 suite FAILs, naming four fixtures;
the unreverted control passes); `bash -n`; scope; trailer; tail.

## Open Questions

1. (From Clarifications, technical tradeoffs.) The new guard sees only leaks
   that go through `CLAUDE_PROJECT_DIR`. A suite that writes the literal
   marker path relative to the repository root would no longer be caught.
   The old guard caught that, at the price of the false FAIL. **Recommended
   default: accept.** It is the only route on record, and every hook uses
   `${CLAUDE_PROJECT_DIR:-.}`, whose fallback never fires while the nested
   run has the variable set. Alternative: the nested run executes inside a
   full copy of the checkout (for example `git worktree add`), with the
   guard watching that copy's directory. That catches both routes, but adds
   worktree management, a dirty-tree question and a larger unit. The unit
   below implements the default. If you choose the alternative, it is a
   re-spec, not a contract edit.

## Self-check
- CHK1: Does each Goal clause map to a criterion? — PASS (G1 → criterion 2; G2 → criteria 1 and 3; G3 → lib.sh builds T under its own mktemp root and every criterion goes through it)
- CHK2: Is the chosen option justified against the guard's own failure cases, with the rejected options named? — PASS (Context, "Option chosen" and "Rejected")
- CHK3: Is a fixture-named leak proven to still FAIL, and a legitimate concurrent entry proven to no longer FAIL, each by a runnable check? — PASS (criterion 1 `fixture` writes unitC.blocked; criterion 2 adds gh999-1.pass and removes old.pass; criterion 2 is red at 4f92d37 with `concurrent: guard exit 1, want 0`)
- CHK4: Does any criterion read, list or write the checkout's own marker directory? — PASS (lib.sh `cd`s to the toplevel only to copy the guard; all directory operations are under `$LGC_ROOT`)
- CHK5: Is the merge gate's skipping of section 101 stated, with criteria that run the guard directly? — PASS (Context, "Merge gate does not exercise this guard")
- CHK6: Does any criterion run the real full validate.sh? — PASS (no; stub validate.sh in every tree)
- CHK7: Does criterion 3's expected fixture set match what the suite leaks today? — FAIL (conflicting): the first draft asserted gh425 F3's set including spec2-unitC.pass, and the run printed `reverted: output does not name spec2-unitC.pass` — revised in place (measured set unitA/unitB/unitC/unitG; Context explains the item12-1 `set -e` stop)
- CHK8: Is the removed-directory case defined? — PASS (edit 2 message; criterion 1 `removal`)
- CHK9: Does each `mutation:` line state what its criterion prints, observed? — PASS (all observed in the scratch worktree, Verification record)
- CHK10: Is the coverage the fix gives up named and routed to the user? — PASS (Context; Clarifications line 3; Open Question 1)
- CHK11: Is the unit stamped? — PASS (no; P3 line)
- CHK12: Does the contract reach 7/7 under `contract-guard`? — PASS (see Verification record)
- CHK13 (replay): Does any vacuous/host unit in the export intersect a criterion's files? — PASS (none; Context, prior FAIL history)

Glossary drift (prose mode, advisory). Lens 1: none. Lens 2: none ("PASS
marker" and "merge gate" are used as defined). Lens 3: none load-bearing.
"Sandbox project" is test vocabulary, not a domain term.

## Scribe update hint
After lgc-1 PASSes, update item j in
`.claude/agent-memory/scribe/project_epa2_completion.md`: the most likely cause
(the leak guard's live-directory diff racing a concurrent marker write) is
closed by lgc-1. The original incident cannot be attributed (output not
kept), so record j as "closed by likely cause; reopen if validate.sh exits 1
under concurrency again".

## Dispatch contracts (spec-master, fast path, 2026-10-14)

One dispatchable unit; none held.
**Retrieval contract.** No tracker issue exists for this unit (fast path).
Fetch the dispatch prompt by reading
`docs/plans/2026-10-14-leak-guard-concurrency.md` with the Read tool,
finding the `### Unit: lgc-1` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested fences
are payloads). Its first line is the literal `Unit: lgc-1`, and
`node bin/contract-guard.js docs/plans/2026-10-14-leak-guard-concurrency.md --unit=lgc-1`
finds the block. Commit subjects never carry an issue number.

| unit | files (exact) | shared with | depends on |
|---|---|---|---|
| lgc-1 | `tests/reviewed-dir-leak-guard.test.sh` | none | none |

**Suggested model:** `haiku`. Both edits are literal before/after blocks at
unique anchors in a 33-line file, and no unit on this surface has FAIL
history. The orchestrator recomputes the Escalation ladder at dispatch; a tag
can raise the tier but never lower it. The reviewer tier is decided at
dispatch by `hooks/scripts/reviewer-tier.sh` over the actual diff.

**Verification record:** at 4f92d37, ac1 printed `overwrite: guard exit 0,
want 1`, ac2 printed `concurrent: guard exit 1, want 0`, and ac3 exited 0 (the
old guard does catch the env leak, so ac3 guards against regressing it). In a
scratch worktree with edits 1-2 applied, all three were green and `bash -n`
passed. Mutations observed there: delete the `mkdir -p "$sandbox/...` line
(ac1 `fixture: output does not name unitC.blocked`; ac2 and ac3 also red);
point the nested run at `"$(pwd)"` instead of `"$sandbox"` (ac1 `fixture:
guard exit 0, want 1`, ac3 `reverted: guard exit 0, want 1`); delete the
`trap` line (ac2 `TMPDIR not cleaned: tmp.…`); delete the `fi` after the
`leaked=` else branch (`bash -n` exit 2, `unexpected end of file`). Edits 1-2
were applied by script from this file's text (each `before:` block matched
once), and the result was byte-identical to the prototype.
`node bin/contract-guard.js docs/plans/2026-10-14-leak-guard-concurrency.md --unit=lgc-1`
printed `contract-guard: haiku unit=lgc-1 shape=lead score=7/7`.

### Unit: lgc-1

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 1.

``````
Unit: lgc-1

## Objective
Rework `tests/reviewed-dir-leak-guard.test.sh` so its nested validate.sh run gets a fresh mktemp project root as `CLAUDE_PROJECT_DIR`, holding an empty pre-created marker directory, and the guard FAILs if anything appears there or the directory is removed. The guard must no longer list this checkout's own marker directory, so a reviewer writing a marker during the run cannot cause a false FAIL. Two literal edits; nothing else changes.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-leak-guard-concurrency.md`, section `### Unit: lgc-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/reviewed-dir-leak-guard.test.sh` (edit 1 replaces lines 1-9, edit 2 replaces lines 18-33; lines 10-17, the recursion comment and `REVIEWED_DIR_LEAK_GUARD_NESTED` check, stay byte-identical)

## Ordered edits
1. file: `tests/reviewed-dir-leak-guard.test.sh` (header comment and cd line)
   anchor: line matching `# Standing guard (gh425): a full tests/validate.sh run must not leave the`
   indent: 0
   before:
~~~~
#!/usr/bin/env bash
# Standing guard (gh425): a full tests/validate.sh run must not leave the
# real .claude/reviewed/ directory's entry list changed. Regression guard for
# the tests/marker-write.test.sh leak, which planted fixtures into the real
# directory whenever CLAUDE_PROJECT_DIR was set - exactly the condition under
# which the harness runs the suite. See
# docs/plans/2026-09-02-blocked-marker-scoping-gh425.md, F3/F4/R7.
set -uo pipefail
cd "$(dirname "$0")/.."
~~~~
   after:
~~~~
#!/usr/bin/env bash
# Standing guard (gh425, reworked by lgc-1): a full tests/validate.sh run must
# not write into the .claude/reviewed/ directory of the project that
# CLAUDE_PROJECT_DIR names. Regression guard for the tests/marker-write.test.sh
# leak, which planted fixtures there whenever CLAUDE_PROJECT_DIR was set -
# exactly the condition under which the harness runs the suite. See
# docs/plans/2026-09-02-blocked-marker-scoping-gh425.md, F3/F4/R7.
#
# The nested run gets a fresh mktemp project root as its CLAUDE_PROJECT_DIR,
# holding an empty .claude/reviewed/, and the guard fails if anything appears
# there or the directory goes away. It never reads this checkout's own marker
# directory, so a reviewer writing or removing a marker while the nested run
# is in flight cannot cause a false FAIL (watch item j; see
# docs/plans/2026-10-14-leak-guard-concurrency.md). Starting empty also
# catches a leak that overwrites a marker name the project already has.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
~~~~
2. file: `tests/reviewed-dir-leak-guard.test.sh` (listing, nested run and verdict)
   anchor: line matching `before="$(ls -1 .claude/reviewed 2>/dev/null | sort)"`
   indent: 0
   before:
~~~~
before="$(ls -1 .claude/reviewed 2>/dev/null | sort)"
CLAUDE_PROJECT_DIR="$(pwd)" REVIEWED_DIR_LEAK_GUARD_NESTED=1 \
  bash tests/validate.sh >/dev/null 2>&1 || true
after="$(ls -1 .claude/reviewed 2>/dev/null | sort)"

if [ "$before" = "$after" ]; then
  echo "OK   .claude/reviewed/ entry list unchanged across a full validate.sh run"
  exit 0
fi

echo "FAIL .claude/reviewed/ entry list changed across a full validate.sh run -"
echo "     a test suite leaked fixtures into the real project directory instead"
echo "     of its own mktemp sandbox. Known past offender: tests/marker-write.test.sh"
echo "     (see docs/plans/2026-09-02-blocked-marker-scoping-gh425.md). Diff:"
diff <(echo "$before") <(echo "$after") | sed 's/^/     /'
exit 1
~~~~
   after:
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
3. command: `git add tests/reviewed-dir-leak-guard.test.sh && git commit -m "fix(lgc-1): leak guard watches a sandbox project, not the live marker dir" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer)
   expect: 0
4. command: `git diff --quiet HEAD -- tests/reviewed-dir-leak-guard.test.sh`
   expect: 0

## Do NOT touch
- `tests/reviewed-dir-leak-guard.test.sh` lines 10-17 (the recursion comment and the `REVIEWED_DIR_LEAK_GUARD_NESTED` early exit): byte-identical.
- `tests/validate.sh`: unchanged; section 101 keeps calling the guard as it does today.
- `tests/marker-write.test.sh` and `hooks/scripts/marker-write.sh`: unchanged; criterion 3 copies them, it does not edit them.
- `docs/plans/lgc-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/lgc-criteria/lgc1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: delete edit 2's `mkdir -p "$sandbox/...` line; prints `fixture: output does not name unitC.blocked`, exit 1 (observed). At 4f92d37 it prints `overwrite: guard exit 0, want 1` (observed).
2. run: `bash docs/plans/lgc-criteria/lgc1-ac2.sh`
   exit: 0
   stdout: empty
   mutation: delete edit 2's `trap` line; prints `TMPDIR not cleaned: tmp.` followed by a random suffix, exit 1 (observed). At 4f92d37 it prints `concurrent: guard exit 1, want 0` (observed).
3. run: `bash docs/plans/lgc-criteria/lgc1-ac3.sh`
   exit: 0
   stdout: empty
   check: green at 4f92d37 on purpose; the old guard also catches the env leak, and this criterion keeps the new guard from losing that.
   mutation: in edit 2 write `CLAUDE_PROJECT_DIR="$(pwd)"` instead of `CLAUDE_PROJECT_DIR="$sandbox"`; prints `reverted: guard exit 0, want 1`, exit 1 (observed).
4. run: `bash -n tests/reviewed-dir-leak-guard.test.sh`
   exit: 0
   stdout: empty
   check: green at 4f92d37 on purpose; it guards the file's syntax.
   mutation: delete the closing `fi` after the `leaked=` else branch; prints a syntax error, exit 2.
5. run: `bash docs/plans/epf-criteria/scope.sh lgc-1 'tests/reviewed-dir-leak-guard\.test\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
6. run: `bash docs/plans/epf-criteria/range.sh lgc-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
7. run: `bash docs/plans/epf-criteria/range.sh lgc-1 tail tests/reviewed-dir-leak-guard.test.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no tests/reviewed-dir-leak-guard.test.sh (the file is itself a test; criteria 1-2 are the tests for this change and were red at 4f92d37)
blast-radius: tests/reviewed-dir-leak-guard.test.sh:1-33 (whole file; only caller tests/validate.sh:1111-1117, section 101); no shipped file names it.
commit-message: fix(lgc-1): leak guard watches a sandbox project, not the live marker dir
trailer: the trailer names the model you actually ran on.
gate: never type a Bash command whose text spells the marker directory path; reviewed-path-gate.sh blocks it by text. Apply edits 1-2 with Edit (path-checked only). If Edit is unavailable, STOP and report; do not use a heredoc.
measured: at 4f92d37 the file is 33 lines; each anchor occurs once; all criteria finish in under a second; do NOT run the full tests/validate.sh (the guard doubles it past the 600 s cap), and the merge gate's vsec ranges skip this section, so criteria 1-3 are the only runs of the guard.
diagnosis: none
review-packet:
~~~
unit: lgc-1 (plan docs/plans/2026-10-14-leak-guard-concurrency.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
