# Lane runner and leak guard: close the vlg round's open reviewer notes (vln)

Status: FINAL (spec-master 2026-10-14). Four fast-path units, `vln-1`..`vln-4`.
No open questions; every decision below is a stated default. Criteria
scripts live in `docs/plans/vln-criteria/` (`lib.sh` plus one script per
criterion).

## Goal

Close the non-blocking reviewer notes left open after the vlg round
(`docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`, units vlg-1
7adddc1, vlg-2 4ed8fc9, vlg-3 5178319; scribe's "vlg closure" open notes in
`.claude/agent-memory/scribe/project_epa2_completion.md`):

- G1 (item 1, vlg-2 note): an interrupted `tests/validate-lanes.sh` (TERM or
  INT, during a lane's tar copy or during a section) leaves no process of
  its tree behind and still removes its work directory. Criteria: vln-1
  criterion 1; regression case L10 in vln-2 (criteria 1-2).
- G2 (item 2, vlg-3 notes): mutants prove that the test's cases L1, L6 and
  L9 can go red, and `tree()` stops the test (exit 99, a setup message, no
  case run) when a throwaway tree's git setup fails. Criteria: vln-2
  criteria 2-3.
- G3 (item 3, vlg-1 notes): the guard header cites "Note 2", and the nested
  run's output file lives outside the sandbox and is removed on exit, so a
  suite that deletes its project dir no longer destroys the completion
  evidence. Criteria: vln-3 criterion 1.
- G4 (item 4, vlg-3 note): the vlg plan's vlg-3 `measured:` line carries the
  re-measured timings. Criteria: vln-4 criterion 1.
- G5 (item 5, optional, vlg-2 note): a lane copy whose tar create side exits
  1 ("file changed as we read it") is copied again, up to 3 attempts, and
  is never accepted torn. Criteria: vln-1 criterion 2; regression case L11
  in vln-2 (criteria 1-2).

`bash tests/validate.sh` stays the serial merge gate. No file under
`agents/` or `templates/` changes, so there is no version bump.

## Context

### Item 1: what survives an interrupt today, and the fix

`tests/validate-lanes.sh:53` is `trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT`.
`jobs -p` lists only the lane subshells. Each lane's `tar | tar` pipeline
and each section's `bash` (and everything that section starts) are
grandchildren, and they keep running against a removed `$work`.
Measured at HEAD (`vln1-ac1.sh` against the committed runner): `section-TERM: pid N (bash) survived SIGTERM`,
`section-INT: pid N (bash) survived SIGINT` and `copy-TERM: pid N (bash) survived SIGTERM` (each case observed alone).

Fix (vln-1): start every lane in a process group of its own, by turning
job control on (`set -m`) for the spawn loop only and off again right after.
The EXIT trap then sends TERM to each lane's whole group
(`kill -TERM -- -<pid>`), waits for the lanes, and only then removes
`$work`. Three consequences, each covered:

- A job-controlled background job does not get `/dev/null` as stdin
  automatically, and a background process group that reads the terminal is
  stopped by SIGTTIN. So each lane is spawned with `< /dev/null`. Case
  `stdin` of `vln1-ac1.sh` runs the runner with a regular file as stdin and
  wants `/dev/null` inside a section.
- Turning `set -m` off right after the spawn loop keeps every later
  foreground command in the runner's own process group. Ctrl-C at a
  terminal therefore still reaches the runner (INT trap, exit 130). The
  lanes, in background groups, are reached by the EXIT trap.
- Residual (accepted, stated in the new comment): a process that leaves its
  lane's group (`setsid`, or its own `set -m` jobs) or ignores TERM is not
  reached. No section of `tests/validate.sh` does that today (all 116
  sections at the time ran green in lanes, Verification record).

Rejected alternative: walking the tree with `pkill -P` / `ps --ppid`. It races
with processes that fork while the walk runs, and it needs a recursive
helper. A process group is atomic and needs one `kill` per lane.

### Item 2: the vlg-3 test's unproven cases and its silent setup

`docs/plans/vlg-criteria/vlg3-ac2.sh` has five runner mutants (L3, L4, L5,
L7-9, L8). Measured at HEAD: the three mutants this plan adds for L1
(sections printed in reverse order), L6 (each lane's `.git` symlinked to the
source's) and L9 (the work dir kept) already turn the CURRENT test red
with the named id. So the cases were sound and only the proof was
missing. The proof is the new criterion `vln2-ac2.sh`. It is a plan
artifact and is committed with this plan. The test cases themselves
need no change.

`tree()` (`tests/validate-lanes.test.sh:24-25`) sends git init/commit output
to `/dev/null` and never checks the status, so a host where `git commit`
fails (commit signing) shows up as confusing L1/L6 failures. The vlg
criteria helper `ltree` echoes and `exit 99`s. But every caller runs it inside `$(...)`,
so that exit ends only the subshell: the helper has the same blind spot.
Fix (vln-2): `tree` prints its message on stderr and exits 99, and EVERY call
site ends `|| exit 99`. The new `docs/plans/vln-criteria/lib.sh` `ltree`
does the same (`t=$(ltree ...) || exit 1`). `vln2-ac3.sh` makes the host
failure real, not mocked. It switches commit signing on through git's
`GIT_CONFIG_COUNT` environment (git 2.43.0 here; the mechanism needs 2.31 or later)
with `gpg.program=false`. Before the fix the test exits 1 after
running cases against unborn trees.

vln-2 also adds two regression cases, so that the serial merge gate (its lane runner
section runs this test) covers vln-1's behaviour: L10 (SIGTERM mid-section
leaves no survivor) and L11 (a tar create exit 1 is retried and the run is
green). The L9 TMPDIR check moves to the end so it covers them too. The file
is rewritten whole with the Write tool. It spells the marker directory
path, and ten call sites change, so a whole-file write is less error-prone
than ten anchored edits.

### Item 3: the leak guard's evidence file

`tests/reviewed-dir-leak-guard.test.sh:46` puts `nested.out` inside
`$sandbox`, which is the nested run's `CLAUDE_PROJECT_DIR`. Measured at
HEAD: a stub suite that runs `rm -rf "$CLAUDE_PROJECT_DIR"` and then prints
`All checks passed.` makes the guard report `did not finish (exit 0; last
line: (no output))` as well as the removed directory. So one cause yields two
FAIL lines, and the completion signal is lost. Fix (vln-3): `nested_out` is a
second `mktemp` file, created right after the sandbox (if that fails, the
sandbox is removed before `exit 1`). One EXIT trap removes both. The header's
`item 2` becomes `Note 2`, the vlg plan's own label (its Context heading
"Note 2: the repo-root-relative writer gap").

### Item 4: the stale timings

Re-measured on 2026-10-14 with `/proc/uptime` (the test and the vlg-3
criteria are byte-identical to 5178319 at HEAD 64245e0): `tests/validate-lanes.test.sh` 0.35 s; vlg3-ac1 0.73 s,
vlg3-ac2 2.30 s, vlg3-ac3 0.02 s (criteria 1-3 together about 3 s). The
vlg plan's vlg-3 contract says "about 5 s" and "about 40 s". The other two
`measured:` lines in that plan are still accurate (vlg-2: criteria 1-3 took
0.50 + 3.44 + 16.16 s, about 20 s as stated; vlg-1: "a few seconds", measured
0.16-0.34 s each), so they are not touched. The edit keeps the vlg-3
contract at contract-guard 7/7 (`vln4-ac1.sh` checks it).

### Item 5 (optional): tar "file changed as we read it"

GNU tar's create side exits 1 when a file changed while tar read it. tar
documents status 1 for `--create` as "some files were changed while being
archived". Status 2 is a fatal error. Today the runner's `pipefail` turns that into a
lane copyfail, so a busy checkout reddens the run. **Decision (self-resolved):
include a retry, not acceptance.** When the pipeline's statuses are
exactly `1 0` (create 1, extract 0), the lane removes its copy and copies again,
up to 3 attempts in all. Each retry prints a `NOTE lane k: ...` line. Any
other status, or a third `1 0`, is a FAIL naming tar's exit statuses. A torn
copy is never used, so the fix cannot turn a red run green on bad data. Its
cost is at most two extra ~50 MB copies per lane under a busy tree. `vln1-ac2.sh`
proves it with a `tar` wrapper first on PATH that replaces the create side's
status: retried once and green; retried twice and still FAIL; a status of 2
is not retried. A non-GNU tar that uses exit 1 as a generic error is retried
twice and then FAILs as before, which is just as loud.

### Prior FAIL history and notes sweep

- `vln-1..4` are new unit ids. No `.fail` record exists for any vlg unit or
  for lgc-1 (directory listing, 2026-10-14).
- `bash bin/marker-audit.sh . --notes --surface=<path>` for each of the four
  touched files, 2026-10-14:
  - `tests/validate-lanes.sh`: 5 notes. vlg-2 NOTE[code] tar copyfail →
    **addressed** (item 5, vln-1). vlg-2 NOTE[code] EXIT trap → **addressed**
    (item 1, vln-1). vlg-2 NOTE[spec] no regression test → already closed by
    vlg-3. vlg-2 NOTE[spec] glossary → already closed (scribe added **lane
    runner**/**lane copy** to `docs/harness-glossary.md`). skr-2 NOTE[code]
    (the serial validate.sh exceeds the 600 s Bash ceiling at the nested
    leak guard) → **not in scope**: the serial merge gate's semantics stay
    untouched (dispatch boundary). The lane runner remains the opt-in fast path.
  - `tests/validate-lanes.test.sh`: 2 notes, vlg-3 NOTE[code] `tree()` →
    **addressed** (vln-2), and vlg-3's L1/L6/L9 mutant note → **addressed**
    (`vln2-ac2.sh`).
  - `tests/reviewed-dir-leak-guard.test.sh`: 8 notes (1 NOTE[spec], 3
    NOTE[code], 4 untagged). vlg-1 NOTE[code] nested.out and vlg-1
    NOTE[spec] "item 2" → **addressed** (vln-3). gh425-2 untagged notes 2, 3
    and 5 were closed by lgc-1. gh425-2 note 4 (the nested pass prints a green
    OK for a skipped check) stays **deferred** (cosmetic, as in the vlg
    plan). lgc-1 NOTE[code] (`-mindepth 1` is an equivalent mutant) is **not
    acted on**: the line is unchanged. rnf-2 NOTE[code] (the serial run
    exceeds 600 s) is **not in scope** (serial merge gate untouched). The
    untagged lines all belong to the completed unit gh425-2, so none names
    an undispatched step. The vlg-1 note on the exact-string coupling to
    validate.sh's closing summary (it names no file path, so the sweep does
    not list it) stays **deferred**: it is loud, it fails closed, and the
    dispatch's list does not include it.
  - `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`: 0 notes.
- Replay source `docs/audits/unit-outcomes/2026-10-06.jsonl`: 64 units carry
  FAIL class vacuous or host. None of them changed any of the four files
  this plan touches (`git diff --name-only`/`git show --name-only` per unit,
  2026-10-14), so no replay CHK item is added.
- The sweep is best effort (per-clone, gitignored records).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-10-14 Functional scope & success criteria: Q Does item 2's "add mutants" mean new cases in the test file, or a mutation proof of the existing cases? → A (self-resolved): a mutation proof (`vln2-ac2.sh`, a plan artifact). The existing L1/L6/L9 cases already go red under the three mutants (measured), so the test needs no new code for them. Item 5 is included as a retry (Context, item 5).
- 2026-10-14 Non-functional attributes (perf, security, scale): Q What do the new cases cost the merge gate? → A (self-resolved, measured): the test goes from 0.35 s to about 0.6 s (L10 waits for one section to start; L11 copies twice); `vln2-ac2.sh` takes about 13 s because the `oldtrap` mutant waits 10 s for survivors before failing.
- 2026-10-14 External dependencies & integrations: Q Which tool behaviours do the fixes rely on? → A (self-resolved): GNU tar's documented create exit 1; bash job control giving each `&` job its own process group; Linux `/proc` and `ps -o stat=` in the criteria and in L10 (the runner itself already needs GNU `find -printf`); git `GIT_CONFIG_COUNT` (2.31 or later) in `vln2-ac3.sh` only.
- 2026-10-14 Edge cases / failure handling: Q What still escapes the interrupt cleanup, and can a retried copy hide a real failure? → A (self-resolved): processes that leave the lane's process group or ignore TERM escape (comment in the runner; no section does that today). A retry never accepts a torn copy, and anything other than `1 0`, or a third `1 0`, is a FAIL.
- 2026-10-14 Technical constraints & tradeoffs: Q Process groups or an explicit tree walk? → A (self-resolved): process groups (`set -m` around the spawn loop only, stdin from `/dev/null`); a tree walk races with forking children (Context, item 1).

## Risks / dependencies

- R1: Ordering. vln-2 depends on vln-1. Its L10/L11 cases need vln-1's
  behaviour, and `vln2-ac2.sh`'s `oldtrap`/`noretry` mutants anchor on
  vln-1's exact text. Dispatch vln-2 only after vln-1 has passed review.
  vln-3 and vln-4 touch disjoint files. They may run in parallel with each
  other and with vln-1 or vln-2 in one tree. Each unit stages only its own
  path and ends with `git diff --quiet HEAD -- <own file>`.
- R2: vln-1 criterion 7 (`vlg2-ac4.sh`) copies the working tree. If vln-3 is
  mid-edit in the same tree, the lane copies include that half-edited
  guard. Section 101 exits at its unchanged `REVIEWED_DIR_LEAK_GUARD_NESTED`
  check first, so this is harmless. If any other sibling edit makes it red,
  re-run it after the sibling commits.
- R3: The criteria scripts in `docs/plans/vln-criteria/` are committed with
  this plan and are read-only for the units. Unit commits are found by the
  subject scope `^[a-z]+\(vln-N\): ` (`docs/plans/epf-criteria/scope.sh`,
  `range.sh`).
- R4: Gates. The runner, its test and the guard all spell the marker
  directory path, and `reviewed-path-gate.sh` blocks a Bash command whose
  text spells it (a heredoc carrying these files is such a command). Apply
  every edit with Edit, or Write for vln-2's whole file. Both are
  path-checked only. Run criteria as `bash <script>`. If Write/Edit are
  unavailable, STOP and report. Rewording a command to get past the gate is a
  bypass.
- R5: `vlg3-ac2.sh` (a vln-1 and vln-2 criterion) anchors five mutants on
  runner text that vln-1 must leave byte-identical:
  `      echo 1 > "$work/leak/$i"`,
  `CLAUDE_PROJECT_DIR="$l" REVIEWED_DIR_LEAK_GUARD_NESTED=1`, the
  `aborted (exit $rc)` line, `  [1-8]) ;;` and
  `if [ ! -d "$root/.git" ]; then`. vln-1's four edits touch none of them
  (checked by applying the plan's own text).
- R6: Unit criteria never run the full serial `tests/validate.sh`. Its nested
  section 101 alone takes about 480 s, and the whole run goes past the
  600 s Bash cap. Merge gate G below runs the reworked guard on its own.
- R7: Timing. Every deadline in the criteria and in L10 uses `/proc/uptime`
  (monotonic). On WSL the wall clock was seen to jump (vlg R7). The runner's
  `wall:` line stays informational.
- R8 (amended 2026-10-14, after vln-2's commit 3efa204): Section count is
  not stable. sfu-5 (1f50346, another plan) took `tests/validate.sh` from
  116 to 118 sections, and `vln2-ac1.sh` pinned 116, so it went red on a
  file the unit never touches. The criterion now asserts that exactly one
  section header names `opt-in parallel lane runner` and exactly one line
  runs `bash tests/validate-lanes.test.sh`, then runs that section with
  `vrun`. Prose that called it "section 116" now says "the lane runner
  section". Counts quoted from the vlg plan (vln-4's anchor) and the
  historical "all 116 sections" record stay as measured.
  `docs/plans/vlg-criteria/vlg3-ac1.sh` pins 116 the same way; it belongs to
  the vlg plan and is not changed here.

**G: merge gate for this plan** (orchestrator, after all four PASS; one Bash
call per item, each `timeout: 600000`):
(1) `bash docs/plans/vlg-criteria/vlg2-ac4.sh`. It runs every section in 3
lanes with the new runner, and the lane runner section runs the new test; want exit 0
and one `wall: Ns` line.
(2) `bash tests/reviewed-dir-leak-guard.test.sh` on its own, with
`REVIEWED_DIR_LEAK_GUARD_NESTED` unset. Want exit 0 and the `OK` line
(about 480 s; this is the only real run of the reworked guard).

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every new criterion was run red
  against HEAD's files and green with this plan's own edit text applied
  (Verification record). Every `mutation:` line that names an output was observed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  criteria are committed scripts, and every edit is literal: before/after
  blocks, plus one whole-file Write whose content is in the contract.
- P3 "Version-stamp discipline": satisfied, vacuously. No `agents/*.md` or
  `templates/*` change.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona
  prose changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied. `tests/validate.sh`
  is not edited at all. Its lane runner section keeps running the (extended) lane
  test, and the serial run stays the gate.

## Steps

### Step 1: vln-1, lane runner: interruption kills whole lanes; tar retry
**Affected files:** `tests/validate-lanes.sh` only.
**Acceptance:** `vln1-ac1.sh` (section-TERM, section-INT, copy-TERM leave no
survivor, exit 143/130, TMPDIR clean; a section's stdin is `/dev/null`);
`vln1-ac2.sh` (retry once green, three times FAIL, status 2 not retried);
`vlg2-ac1..ac3` and `vlg3-ac2` (unchanged behaviour, the old mutant anchors intact);
`vlg2-ac4` (the real suite in 3 lanes); `bash -n`; scope; trailer; tail.

### Step 2: vln-2, lane runner test: setup hard-exit, L10, L11
**Affected files:** `tests/validate-lanes.test.sh` only.
**Acceptance:** `vln2-ac1.sh` (test green with an ok line per case, the lane runner
section present once and green through `vrun`); `vln2-ac2.sh` (mutants for L1, L6, L9, L10, L11);
`vln2-ac3.sh` (real signing failure gives exit 99 and no case run); `vlg3-ac2`
(the old five mutants still red); `bash -n`; scope; trailer; tail.

### Step 3: vln-3, leak guard: evidence outside the sandbox; "Note 2"
**Affected files:** `tests/reviewed-dir-leak-guard.test.sh` only.
**Acceptance:** `vln3-ac1.sh`; `vlg1-ac1`, `vlg1-ac2`, `lgc1-ac1..ac3` (guard
semantics unchanged); `bash -n`; scope; trailer; tail.

### Step 4: vln-4, vlg plan: re-measured vlg-3 timings
**Affected files:** `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md` only.
**Acceptance:** `vln4-ac1.sh` (new text once, old text gone, vlg-3 contract
still 7/7); scope; trailer; tail.

## Open Questions

None. Every Partial category was self-resolved (Clarifications), and no
Self-check item was converted.

## Self-check
- CHK1: Does each Goal clause map to a criterion? — PASS (G1 → vln-1 criterion 1, vln-2 criteria 1-2 via L10; G2 → vln-2 criteria 2-3; G3 → vln-3 criterion 1; G4 → vln-4 criterion 1; G5 → vln-1 criterion 2, vln-2 criteria 1-2 via L11)
- CHK2: Is "interrupted" defined for both phases the note names (tar copy and section) and both signals? — FAIL (missing): the first draft tested only TERM mid-section — revised in place (`copy-TERM` with a sleeping tar wrapper, and `section-INT`, each red at HEAD when run alone)
- CHK3: Is the stdin side effect of `set -m` covered by a runnable check? — FAIL (missing): the first draft spawned lanes without `< /dev/null` — revised in place (edit 3; `vln1-ac1` case `stdin`, red under the mutation)
- CHK4: Can the interrupt criterion leave sleeps behind when it is red? — FAIL (missing): an early run left survivors — revised in place (`lib.sh` `reap` on EXIT; the test's own EXIT trap does the same for L10; after the red runs `pgrep -f 'sleep 300'` matched only the measuring shell)
- CHK5: Does "make tree() hard-exit" hold, given that tree runs inside `$(...)`? — FAIL (conflicting): `exit 99` inside a command substitution ends only the subshell; ltree has the same flaw — revised in place (every call site ends `|| exit 99`; `vln2-ac3` proves exit 99 with a real signing failure)
- CHK6: Do Steps 1 and 2 agree on the runner text `vln2-ac2` mutates? — PASS (its `oldtrap` and `noretry` anchors each match once in the file vln-1's edits produce; checked by applying the plan's own text)
- CHK7: Do vln-1's edits keep `vlg3-ac2`'s five anchors byte-identical? — PASS (R5; `vlg3-ac2` green with vln-1 applied)
- CHK8: Can the tar retry turn a red run green on a torn copy? — PASS (only `1 0` retries, and the copy is removed first; `vln1-ac2` `always` and `hard` cases)
- CHK9: Is every timing criterion monotonic? — PASS (`mono`/`past` from `/proc/uptime` in `lib.sh` and in the test; no `date` arithmetic in any criterion)
- CHK10: Does any unit change `tests/validate.sh`, `agents/` or `templates/`? — PASS (no; every scope regex names a single file outside them)
- CHK11: Are parallel units independent of each other's in-flight edits? — PASS (R1, R2; explicit-path `git add`; `git diff --quiet HEAD -- <own file>`)
- CHK12: Is each MUST principle answered? — PASS (Constitution check)
- CHK13: Does every contract reach 7/7 under `contract-guard`? — PASS (Verification record)
- CHK14: Does each `mutation:` line state what its criterion prints, observed? — PASS (Verification record)
- CHK15: Is vln-4's edit target unique, and does it leave the vlg-3 contract scoring 7/7? — PASS (the before-text occurs once; `vln4-ac1` runs contract-guard)

Glossary drift (prose mode, advisory). `CONTEXT.md` has no entry for "lane",
"process group" or "torn copy"; these are harness/test mechanics, and
`docs/harness-glossary.md` holds **lane runner** and **lane copy**. Lens 1:
none. Lens 2: none ("lane copy" is used as the harness glossary defines it).
Lens 3: none for CONTEXT.md. See the Scribe update hint for the harness
glossary's **lane copy** entry, which this plan makes stale.

## Scribe update hint
After all four PASS:

- `docs/harness-glossary.md` **lane copy**: replace "Run it on a quiet tree:
  tar "file changed as we read it" turns a run red." with the retry
  behaviour (a `1 0` copy is retried, up to 3 attempts, with a NOTE line; then FAIL).
  Add to **lane runner** that an interrupt (TERM/INT) takes every lane's
  whole process group with it (vln-1).
- `.claude/agent-memory/scribe/project_epa2_completion.md` "vlg closure":
  mark its open reviewer notes closed (EXIT trap → vln-1; tar → vln-1 retry;
  L1/L6/L9 mutants and `tree()` → vln-2; "item 2" and nested.out → vln-3;
  timings → vln-4).

## Dispatch contracts (spec-master, fast path, 2026-10-14)

Four dispatchable units; none held.
**Retrieval contract.** No tracker issue exists for these units (fast path).
Fetch a unit's dispatch prompt by reading
`docs/plans/2026-10-14-validate-lanes-followups-2.md` with the Read tool,
finding the `### Unit: <id>` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested
fences are payloads). Its first line is the literal `Unit: <id>`, and
`node bin/contract-guard.js docs/plans/2026-10-14-validate-lanes-followups-2.md --unit=<id>`
finds the block. Commit subjects never carry an issue number.

| unit | files (exact) | shared with | depends on |
|---|---|---|---|
| vln-1 | `tests/validate-lanes.sh` | none | none |
| vln-2 | `tests/validate-lanes.test.sh` | none | vln-1 |
| vln-3 | `tests/reviewed-dir-leak-guard.test.sh` | none | none |
| vln-4 | `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md` | none | none |

Dispatch order: vln-1, vln-3 and vln-4 in parallel. vln-2 after vln-1 has
passed review, in parallel with vln-3/vln-4 if either is still open.

**Suggested model:** `haiku` for all four. Every edit is a literal block (one
whole-file Write, the rest before/after at unique anchors), and no unit on
these surfaces has FAIL history. The orchestrator recomputes the Escalation
ladder at dispatch, and a tag can raise the tier but never lower it. The
reviewer tier is decided at dispatch by `hooks/scripts/reviewer-tier.sh`
over the actual diff.

**Verification record:** the check ran in a full tar copy of this checkout at 64245e0, with this plan and `docs/plans/vln-criteria/` committed on top. At that commit every new criterion was red as its `mutation:` line states: `vln1-ac1` `section-TERM: pid N (bash) survived SIGTERM` (`section-INT` and `copy-TERM` were each also red when run alone), `vln1-ac2` `once: exit 1, want 0`, `vln3-ac1` `wipe: output must not contain did not finish`, and `vln4-ac1` `the stale timing text is still present`. The four units were then applied by script from this file's own contract text, in the order vln-1, vln-3, vln-4, vln-2. Every before-block matched once, and the results were byte-identical to the prototypes. Each unit was committed with its contract's own commands, and each `git diff --quiet` gave 0. With vln-1 alone applied, its criteria 1-6 and 8-11 were green. With all four applied, every criterion of every unit was green: all `vln*`, `vlg1-ac1/ac2`, `vlg2-ac1..ac3`, `vlg3-ac2`, `lgc1-ac1..ac3`, the three `bash -n`, all four scope runs, trailer `1 ` for each, and tail `0` with exit 1 for each. Before vln-2 (vln-1 applied, the old test) `vln2-ac1/ac2/ac3` printed `no ok line for L10`, `oldtrap: test exit 0, want 1` and `signing: test exit 1, want 99`. Every `mutation:` line that names an output was applied and observed with that output. `vlg2-ac4.sh` (criterion 7 of vln-1, and G item 1) printed `wall: 170s` with all four units applied. The standalone guard (G item 2) printed its `OK` line, exit 0, in 456 s. The new test took 0.68 s. After all red runs, `pgrep -f 'sleep 300'` matched only the measuring shell. `node bin/contract-guard.js docs/plans/2026-10-14-validate-lanes-followups-2.md --unit=<id>` printed `contract-guard: haiku unit=<id> shape=lead score=7/7` for vln-1, vln-2, vln-3 and vln-4.

### Unit: vln-1

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 1.

``````
Unit: vln-1

## Objective
Make `tests/validate-lanes.sh` clean up its whole process tree when interrupted (every lane in its own process group; the EXIT trap sends TERM to each group, waits, then removes the work dir; lanes read stdin from `/dev/null`), and make a lane's copy retry, up to 3 attempts, when GNU tar's create side exits 1 ("file changed as we read it"), never using a torn copy. Four literal edits; nothing else changes.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-followups-2.md`, section `### Unit: vln-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/validate-lanes.sh` (edits 1-4 at four unique anchors; every other line stays byte-identical)

## Ordered edits
1. file: `tests/validate-lanes.sh` (EXIT trap)
   anchor: line matching `trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT`
   indent: 0
   before:
~~~~
work="$(mktemp -d)" || exit 2
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
~~~~
   after:
~~~~
work="$(mktemp -d)" || exit 2
# Every lane is started in a process group of its own (set -m around the
# spawn loop below), so on exit, TERM or INT the whole lane goes: its tar
# copy, its section's bash and their children. A process that leaves its
# lane's group (setsid) or ignores TERM is not reached.
trap 'for p in $(jobs -p); do kill -TERM -- "-$p" 2>/dev/null; done; wait; rm -rf "$work"' EXIT
~~~~
2. file: `tests/validate-lanes.sh` (the lane's copy)
   anchor: line matching `  local k="$1" l="$work/lane$1" i before after rc`
   indent: 2
   before:
~~~~
  local k="$1" l="$work/lane$1" i before after rc
  mkdir -p "$l"
  tar -C "$root" --exclude=./.claude/worktrees ${work_rel:+"--exclude=./$work_rel"} -cf - . \
    | tar -C "$l" -xf - || { echo 2 > "$work/lane$k.copyfail"; return; }
~~~~
   after:
~~~~
  local k="$1" l="$work/lane$1" i before after rc try st
  for try in 1 2 3; do
    rm -rf "$l"; mkdir -p "$l"
    tar -C "$root" --exclude=./.claude/worktrees ${work_rel:+"--exclude=./$work_rel"} -cf - . \
      | tar -C "$l" -xf -
    st="${PIPESTATUS[0]} ${PIPESTATUS[1]}"
    [ "$st" = "0 0" ] && break
    # GNU tar's create side exits 1 when a file changed while it was read (a
    # busy checkout). Copy again rather than run sections on a torn copy.
    if [ "$st" = "1 0" ] && [ "$try" -lt 3 ]; then
      echo "NOTE lane $k: a file changed during copy attempt $try; copying again" >> "$work/lane$k.note"
      continue
    fi
    echo "$st" > "$work/lane$k.copyfail"; return
  done
~~~~
3. file: `tests/validate-lanes.sh` (spawn loop)
   anchor: line matching `for k in $(seq 1 "$lanes"); do lane "$k" & done`
   indent: 0
   before:
~~~~
for k in $(seq 1 "$lanes"); do lane "$k" & done
wait
~~~~
   after:
~~~~
set -m
for k in $(seq 1 "$lanes"); do lane "$k" < /dev/null & done
set +m
wait
~~~~
4. file: `tests/validate-lanes.sh` (copy report)
   anchor: line matching `  [ -e "$work/lane$k.copyfail" ] && { echo "FAIL lane $k: could not copy the checkout"; fail=1; }`
   indent: 2
   before:
~~~~
  [ -e "$work/lane$k.copyfail" ] && { echo "FAIL lane $k: could not copy the checkout"; fail=1; }
~~~~
   after:
~~~~
  [ -e "$work/lane$k.note" ] && cat "$work/lane$k.note"
  [ -e "$work/lane$k.copyfail" ] && { echo "FAIL lane $k: could not copy the checkout (tar exits: $(cat "$work/lane$k.copyfail"))"; fail=1; }
~~~~
5. command: `git add tests/validate-lanes.sh && git commit -m "fix(vln-1): lane runner kills whole lanes on interrupt, retries a busy-tree copy" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
6. command: `git diff --quiet HEAD -- tests/validate-lanes.sh`
   expect: 0

## Do NOT touch
- `tests/validate-lanes.sh` outside edits 1-4 (in particular the five lines `vlg3-ac2.sh` anchors on: the leak-flag `echo 1 >` line, the `CLAUDE_PROJECT_DIR="$l"` line, the `aborted (exit $rc)` line, `  [1-8]) ;;`, `if [ ! -d "$root/.git" ]; then`): byte-identical.
- `tests/validate.sh`: unchanged; the serial run stays the merge gate.
- `tests/validate-lanes.test.sh`, `tests/reviewed-dir-leak-guard.test.sh`, `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`: sibling units' files.
- `docs/plans/vln-criteria/`, `docs/plans/vlg-criteria/` and `docs/plans/epf-criteria/`: read-only.
- `agents/` and `templates/`: no version-stamped file changes in this plan.

## Acceptance criteria
1. run: `bash docs/plans/vln-criteria/vln1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: delete edit 3's `set -m` line; prints `section-TERM: the runner did not exit within 20 s of SIGTERM`, exit 1 (observed). Restore the old trap text `kill $(jobs -p) 2>/dev/null; rm -rf "$work"`; prints `section-TERM: pid N (bash) survived SIGTERM`, exit 1 (observed; also the output before the unit). Delete ` < /dev/null` from edit 3; prints `stdin: output does not contain STDIN=/dev/null`, exit 1 (observed).
2. run: `bash docs/plans/vln-criteria/vln1-ac2.sh`
   exit: 0
   stdout: empty
   mutation: write `[ "$try" -lt 1 ]` in place of `[ "$try" -lt 3 ]`; prints `once: exit 1, want 0`, exit 1 (observed; also the output before the unit). Write `if [ "$try" -lt 3 ]; then` in place of `if [ "$st" = "1 0" ] && [ "$try" -lt 3 ]; then`; prints `hard: output must not contain NOTE lane 1`, exit 1 (observed).
3. run: `bash docs/plans/vlg-criteria/vlg2-ac1.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; runner semantics must not regress.
   mutation: write `[0-8])` in place of `[1-8])` in the `--lanes` value check; prints `lanes=0: exit 1, want 2`, exit 1 (observed).
4. run: `bash docs/plans/vlg-criteria/vlg2-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; lane isolation and leak detection must not regress.
   mutation: write `CLAUDE_PROJECT_DIR="$root"` in place of `CLAUDE_PROJECT_DIR="$l"`; prints `envvar: exit 0, want 1`, exit 1 (observed).
5. run: `bash docs/plans/vlg-criteria/vlg2-ac3.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; lanes must still run in parallel (about 16 s).
   mutation: write `do lane "$k" < /dev/null; done` in place of `do lane "$k" < /dev/null & done`; prints `par: --lanes 3 took 12s, want <= 8` (the seconds may differ), exit 1 (observed).
6. run: `bash docs/plans/vlg-criteria/vlg3-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; the five vlg-3 mutant anchors stay intact and the current test still catches them.
   mutation: duplicate the line `      echo 1 > "$work/leak/$i"`; prints `mutant anchor matched 2 times: '      echo 1 > "$work/leak/$i"'`, exit 1 (observed).
7. run: `bash docs/plans/vlg-criteria/vlg2-ac4.sh`
   exit: 0
   stdout: one line matching `^wall: [0-9]+s$` (about 170 s; run it with the Bash tool's timeout at 600000 ms)
   check: green before the unit on purpose; the real suite in 3 lanes.
   mutation: (vlg-2's observed mutation) a lane-only failure prints its `FAIL` lines and exits 1.
8. run: `bash -n tests/validate-lanes.sh`
   exit: 0
   stdout: empty
   mutation: delete the `  done` line that closes edit 2's `for try` loop; prints `syntax error`, exit 2 (observed).
9. run: `bash docs/plans/epf-criteria/scope.sh vln-1 'tests/validate-lanes\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
10. run: `bash docs/plans/epf-criteria/range.sh vln-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
11. run: `bash docs/plans/epf-criteria/range.sh vln-1 tail tests/validate-lanes.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no tests/validate-lanes.sh (criteria 1-2 are the tests for this change and are red before it; vln-2 adds regression cases L10/L11 to tests/validate-lanes.test.sh)
blast-radius: tests/validate-lanes.sh:52-55,81-86,108-110,113-115 (the four edit sites); only caller tests/validate-lanes.test.sh (validate.sh's lane runner section runs it); docs/plans/vlg-criteria/vlg3-ac2.sh anchors on five other lines (R5).
commit-message: fix(vln-1): lane runner kills whole lanes on interrupt, retries a busy-tree copy
trailer: the trailer names the model you actually ran on.
gate: the file's text spells the marker directory path, so apply edits 1-4 with the Edit tool only (path-checked). Never put its content in a Bash heredoc; reviewed-path-gate.sh blocks that by text, and rewording to get past it is a bypass. If Edit is unavailable, STOP and report.
measured: at 64245e0 each before-block occurs once; criteria 1-2 take about 1 s together, 3-6 about 23 s, 7 about 170 s; do NOT run the serial tests/validate.sh.
diagnosis: none
review-packet:
~~~
unit: vln-1 (plan docs/plans/2026-10-14-validate-lanes-followups-2.md)
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
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: vln-2

- Suggested model: `haiku`
- Depends on / blocked by: vln-1 (L10/L11 need its behaviour; criterion 2's `oldtrap`/`noretry` mutants anchor on its exact text)
- Spec step: Step 2.

``````
Unit: vln-2

## Objective
Rewrite `tests/validate-lanes.test.sh` so that `tree()` stops the test with exit 99 and a stderr message when a throwaway tree's git setup fails (every call site ends `|| exit 99`), and add regression cases L10 (SIGTERM mid-section leaves no process behind) and L11 (a tar create exit 1 is retried and the run is green). The L9 TMPDIR check moves to the end. One whole-file write with exactly the content below; nothing else changes.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-followups-2.md`, section `### Unit: vln-2`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/validate-lanes.test.sh` (anchor: whole file, replaced)

## Ordered edits
1. file: `tests/validate-lanes.test.sh`
   anchor: whole file (replace the entire content with exactly this, using the Write tool)
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Regression tests for tests/validate-lanes.sh (vlg-3, vln-2), the opt-in
# parallel runner for tests/validate.sh. Every case builds a throwaway git
# tree under a private mktemp root, with a copy of the runner and a stub
# validate.sh, so nothing here reads or writes this checkout's own .claude/
# state. Exit 0: every case passed; 1: a case FAILed; 99: a throwaway tree
# could not be set up (a host problem, e.g. git commit signing; no case ran
# against it).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
runner="$(pwd)/tests/validate-lanes.sh"
real_tar="$(command -v tar)" || exit 1
root="$(mktemp -d)" || exit 1
# Pids recorded by the interruption case (L10) are killed on exit, so a red
# run never leaves its sleeps behind.
trap 'for p in $(cat "$root"/*.pids 2>/dev/null); do kill -KILL "$p" 2>/dev/null; done; rm -rf "$root"' EXIT
failures=0

# tree <name> <sections>: a git tree holding the runner and a stub suite made
# of validate.sh's preamble, <sections> and its closing summary, plus an
# empty bin/ that run puts first on PATH. Prints it. When git setup fails it
# prints why on stderr and exits 99; every caller ends `|| exit 99`.
tree() {
  local t="$root/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp" "$t/bin"
  cp "$runner" "$t/tests/validate-lanes.sh"
  { printf '#!/usr/bin/env bash\nset -uo pipefail\ncd "$(dirname "$0")/.."\nfail=0\n'
    printf '%s\n' "$2"
    printf 'echo\nif [ "$fail" -eq 0 ]; then\n  echo "All checks passed."\nelse\n  echo "One or more checks FAILED."\nfi\nexit "$fail"\n'
  } > "$t/tests/validate.sh"
  printf 'PASS old x\n' > "$t/.claude/reviewed/old.pass"
  (cd "$t" && git init -q && git add tests \
    && git -c user.name=t -c user.email=t@t commit -qm init) >/dev/null 2>&1 \
    || { echo "tree: git setup failed in $t (no case ran against it)" >&2; exit 99; }
  printf '%s\n' "$t"
}
sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "${2:-echo \"OK   s$1\"}"; }

# run <tree> [args]: run the tree's runner as the harness would. Sets RC, OUT.
run() {
  local t="$1"; shift
  OUT="$(cd "$t" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" PATH="$t/bin:$PATH" bash tests/validate-lanes.sh "$@" 2>&1)"
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

# mono: monotonic seconds; past <start> <secs>: <secs> have passed since <start>.
mono() { cut -d' ' -f1 /proc/uptime; }
past() { awk -v a="$1" -v b="$(mono)" -v s="$2" 'BEGIN { exit !(b - a >= s) }'; }
# alive <pid>: the pid exists and is not a zombie.
alive() { case "$(ps -o stat= -p "$1" 2>/dev/null)" in Z*|'') return 1 ;; *) return 0 ;; esac; }

t=$(tree green "$(sec 1; sec 2; sec 3)") || exit 99; run "$t"
order=$(printf '%s\n' "$OUT" | grep -E '^== s[0-9] ==$' | tr -d '=s ' | tr -d '\n')
last=$(printf '%s\n' "$OUT" | grep -v '^[[:space:]]*$' | tail -n 1)
[ "$order" = 123 ] && [ "$last" = 'All checks passed.' ] || OUT="order=$order last=$last
$OUT"
check L1 'all sections pass: exit 0, header order kept, summary is the last line' 0 \
  '== lanes: 3, sections: 3,' "!order=" '!FAIL'

t=$(tree red "$(sec 1 'echo "FAIL s1"; fail=1'; sec 2)") || exit 99; run "$t"
check L2 'a failing check: exit 1, later sections still run' 1 'FAIL s1' 'OK   s2' 'One or more checks FAILED.' '!All checks passed.'

t=$(tree abort "$(sec 1 'echo "half"; exit 1; echo "OK   tail"'; sec 2)") || exit 99; run "$t" --lanes 2
check L3 'a section that exits early is reported as aborted, even with exit 1' 1 \
  'FAIL section 1 aborted (exit 1)' '!OK   tail' 'OK   s2'

t=$(tree rel "$(sec 1 'printf x > .claude/reviewed/relA.pass'; sec 2)") || exit 99; run "$t"
check L4 'a repo-root-relative marker write is a FAIL naming the section' 1 \
  'FAIL section 1 changed' 'relA.pass' '!FAIL section 2 changed'
[ "$(ls -A "$t/.claude/reviewed")" = old.pass ] || { echo "FAIL (L4b) the source tree's marker directory changed"; failures=$((failures + 1)); }

t=$(tree env "$(sec 1 'printf x > "$CLAUDE_PROJECT_DIR/.claude/reviewed/envB.fail"'; sec 2 'echo "CPD=$CLAUDE_PROJECT_DIR"')") || exit 99; run "$t"
check L5 'a CLAUDE_PROJECT_DIR marker write is a FAIL; the variable never names the source tree' 1 \
  'FAIL section 1 changed' 'envB.fail' "!CPD=$t
"
[ "$(ls -A "$t/.claude/reviewed")" = old.pass ] || { echo "FAIL (L5b) the source tree's marker directory changed"; failures=$((failures + 1)); }

g='git -c user.name=t -c user.email=t@t commit -qm lane --allow-empty || fail=1'
t=$(tree git "$(sec 1 "$g"; sec 2 "$g"; sec 3 "$g")") || exit 99; head0=$(git -C "$t" rev-parse HEAD); run "$t"
[ "$(git -C "$t" rev-parse HEAD)" = "$head0" ] || OUT="source HEAD moved
$OUT"
check L6 'git commits in sections stay in the lane copies' 0 '!source HEAD moved' 'All checks passed.'

for bad in 0 9 x; do
  t=$(tree "bad$bad" "$(sec 1)") || exit 99; run "$t" --lanes "$bad"
  check "L7-$bad" "--lanes $bad is refused" 2 '!All checks passed.'
done

t=$(tree linked "$(sec 1)") || exit 99; rm -rf "$t/.git"; printf 'gitdir: /nonexistent\n' > "$t/.git"; run "$t"
check L8 'a linked worktree (.git is a file) is refused' 2 'is not a directory'

# L10: TERM while a section waits on a child takes the whole lane with it.
# The runner is started with job control on, as a terminal would start it.
pids="$root/intr.pids"
t=$(tree intr "$(sec 1 "sleep 300 & echo \"\$\$ \$!\" >> $pids; wait"; sec 2)") || exit 99
set -m
(cd "$t" && exec env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
  TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" bash tests/validate-lanes.sh --lanes 2 < /dev/null) > /dev/null 2>&1 &
rp=$!
set +m
echo "$rp" >> "$pids"
OUT=""; s=$(mono)
until [ "$(cat "$pids" | wc -w)" -ge 3 ]; do
  past "$s" 20 && { OUT="the section never recorded its pids"; break; }
  sleep 0.1
done
kill -TERM "$rp"; s=$(mono)
while alive "$rp"; do past "$s" 20 && { OUT="${OUT:+$OUT; }the runner outlived SIGTERM by 20 s"; kill -KILL -- "-$rp"; break; }; sleep 0.1; done
wait "$rp"; RC=$?; s=$(mono)
for p in $(cat "$pids"); do
  while alive "$p"; do past "$s" 10 && { OUT="${OUT:+$OUT; }pid $p survived"; break; }; sleep 0.1; done
done
check L10 'SIGTERM takes the whole lane process tree with it' 143 '!survived' '!never recorded' '!outlived'

t=$(tree busy "$(sec 1; sec 2)") || exit 99; echo 0 > "$t/creates"
{ printf '#!/usr/bin/env bash\ncase " $* " in\n'
  printf '  *" -cf "*) n=$(( $(cat %q) + 1 )); echo "$n" > %q\n' "$t/creates" "$t/creates"
  printf '    %q "$@"; s=$?; [ "$n" -le 1 ] && exit 1; exit "$s" ;;\nesac\nexec %q "$@"\n' "$real_tar" "$real_tar"
} > "$t/bin/tar"; chmod +x "$t/bin/tar"; run "$t" --lanes 1
check L11 'a copy whose tar create exits 1 (file changed as read) is copied again' 0 \
  'NOTE lane 1: a file changed during copy attempt 1; copying again' 'All checks passed.' '!FAIL'

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
2. command: `git add tests/validate-lanes.test.sh && git commit -m "test(vln-2): lane runner test stops on setup failure, covers interrupt and copy retry" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
3. command: `git diff --quiet HEAD -- tests/validate-lanes.test.sh`
   expect: 0

## Do NOT touch
- `tests/validate-lanes.sh`: vln-1's file; criterion 2 mutates copies of it, never the file.
- `tests/validate.sh`: unchanged; its lane runner section (header `opt-in parallel lane runner`) keeps calling this test as it does today.
- `tests/reviewed-dir-leak-guard.test.sh`, `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`: sibling units' files.
- `docs/plans/vln-criteria/`, `docs/plans/vlg-criteria/` and `docs/plans/epf-criteria/`: read-only.
- `agents/` and `templates/`: no version-stamped file changes in this plan.

## Acceptance criteria
1. run: `bash docs/plans/vln-criteria/vln2-ac1.sh`
   exit: 0
   stdout: empty
   mutation: delete the L11 block (from `t=$(tree busy` through its `check L11` call); prints `no ok line for L11`, exit 1 (observed). Before the unit it prints `no ok line for L10` (observed). Duplicate the lane runner section header in a copy of `tests/validate.sh`; prints `lane runner section headers: 2, want 1`, exit 1 (observed, amended 2026-10-14).
2. run: `bash docs/plans/vln-criteria/vln2-ac2.sh`
   exit: 0
   stdout: empty
   mutation: delete the line `check L10 'SIGTERM takes the whole lane process tree with it' 143 '!survived' '!never recorded' '!outlived'`; prints `oldtrap: test exit 0, want 1`, exit 1 (observed; also the output before the unit, which has no L10).
3. run: `bash docs/plans/vln-criteria/vln2-ac3.sh`
   exit: 0
   stdout: empty
   mutation: in `tree()` delete ` \` and the `    || { echo "tree: git setup failed in $t (no case ran against it)" >&2; exit 99; }` line after it; prints `signing: test exit 1, want 99`, exit 1 (observed; also the output before the unit).
4. run: `bash docs/plans/vlg-criteria/vlg3-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; the five vlg-3 mutants must still turn the rewritten test red.
   mutation: delete the test's `check L4 ...` call and its `L4b` line; prints `leakflag: test did not print FAIL (L4)`, exit 1 (observed).
5. run: `bash -n tests/validate-lanes.test.sh`
   exit: 0
   stdout: empty
   mutation: delete the `done` line closing the `for bad in 0 9 x` loop; prints `syntax error`, exit 2 (observed).
6. run: `bash docs/plans/epf-criteria/scope.sh vln-2 'tests/validate-lanes\.test\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
7. run: `bash docs/plans/epf-criteria/range.sh vln-2 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
8. run: `bash docs/plans/epf-criteria/range.sh vln-2 tail tests/validate-lanes.test.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/validate-lanes.test.sh (it is the regression test; criterion 2 proves L1, L6, L9, L10 and L11 red against runner mutants, criterion 4 the other five)
blast-radius: tests/validate-lanes.test.sh:1-106 (whole file, replaced); only caller tests/validate.sh's lane runner section (`bash tests/validate-lanes.test.sh`); no shipped file names it.
commit-message: test(vln-2): lane runner test stops on setup failure, covers interrupt and copy retry
trailer: the trailer names the model you actually ran on.
gate: the file's text spells the marker directory path, so write it with the Write tool only (path-checked). Never put its content in a Bash heredoc; reviewed-path-gate.sh blocks that by text, and rewording to get past it is a bypass. If Write is unavailable, STOP and report.
measured: with vln-1 applied the test takes about 0.6 s; criteria 1 and 3 about 1 s each, criterion 2 about 13 s (its oldtrap mutant waits 10 s for survivors), criterion 4 about 3 s; do NOT run the serial tests/validate.sh.
diagnosis: none
review-packet:
~~~
unit: vln-2 (plan docs/plans/2026-10-14-validate-lanes-followups-2.md)
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

### Unit: vln-3

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 3.

``````
Unit: vln-3

## Objective
In `tests/reviewed-dir-leak-guard.test.sh`, keep the nested run's output in a second `mktemp` file outside the sandbox (removed by the same EXIT trap), so a suite that deletes its project directory no longer also destroys the completion evidence, and make the header cite the vlg plan's "Note 2" instead of "item 2". Three literal edits; nothing else changes.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-followups-2.md`, section `### Unit: vln-3`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/reviewed-dir-leak-guard.test.sh` (edit 1 at line 23, edit 2 at lines 36-37, edit 3 deletes line 46; every other line stays byte-identical)

## Ordered edits
1. file: `tests/reviewed-dir-leak-guard.test.sh` (header label)
   anchor: line matching `# item 2): a writer that ignores CLAUDE_PROJECT_DIR and writes the marker`
   indent: 0
   before:
~~~~
# item 2): a writer that ignores CLAUDE_PROJECT_DIR and writes the marker
~~~~
   after:
~~~~
# Note 2): a writer that ignores CLAUDE_PROJECT_DIR and writes the marker
~~~~
2. file: `tests/reviewed-dir-leak-guard.test.sh` (output file and trap)
   anchor: line matching `trap 'rm -rf "$sandbox"' EXIT`
   indent: 0
   before:
~~~~
sandbox="$(mktemp -d)" || exit 1
trap 'rm -rf "$sandbox"' EXIT
~~~~
   after:
~~~~
sandbox="$(mktemp -d)" || exit 1
# The nested run's output is kept OUTSIDE the sandbox (vln-3): a suite that
# removes or rewrites its project directory must not also destroy the
# evidence of whether the nested run finished.
nested_out="$(mktemp)" || { rm -rf "$sandbox"; exit 1; }
trap 'rm -rf "$sandbox" "$nested_out"' EXIT
~~~~
3. file: `tests/reviewed-dir-leak-guard.test.sh` (old output path)
   anchor: line matching `nested_out="$sandbox/nested.out"`
   indent: 0
   before:
~~~~
# closing summary line is the last line of the nested output.
nested_out="$sandbox/nested.out"
CLAUDE_PROJECT_DIR="$sandbox" REVIEWED_DIR_LEAK_GUARD_NESTED=1 ANTISLOP_VALIDATE_INNER=1 \
~~~~
   after:
~~~~
# closing summary line is the last line of the nested output.
CLAUDE_PROJECT_DIR="$sandbox" REVIEWED_DIR_LEAK_GUARD_NESTED=1 ANTISLOP_VALIDATE_INNER=1 \
~~~~
4. command: `git add tests/reviewed-dir-leak-guard.test.sh && git commit -m "fix(vln-3): leak guard keeps nested output outside the sandbox" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
5. command: `git diff --quiet HEAD -- tests/reviewed-dir-leak-guard.test.sh`
   expect: 0

## Do NOT touch
- `tests/reviewed-dir-leak-guard.test.sh` outside edits 1-3 (the `REVIEWED_DIR_LEAK_GUARD_NESTED` early exit, the `case` verdict and the leak check): byte-identical.
- `tests/validate.sh`: unchanged; section 101 keeps calling the guard as it does today.
- `tests/validate-lanes.sh`, `tests/validate-lanes.test.sh`, `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`: sibling units' files.
- `docs/plans/vln-criteria/`, `docs/plans/vlg-criteria/`, `docs/plans/lgc-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/vln-criteria/vln3-ac1.sh`
   exit: 0
   stdout: empty
   mutation: write `trap 'rm -rf "$sandbox"' EXIT` in place of edit 2's trap line; prints `wipe: files were left in TMPDIR`, exit 1 (observed). Write `nested_out="$sandbox/nested.out" ||` in place of `nested_out="$(mktemp)" ||`; prints `wipe: output must not contain did not finish`, exit 1 (observed; also the output before the unit). Skip edit 1; prints `header: the Note 2 line is not present exactly once`, exit 1 (observed).
2. run: `bash docs/plans/vlg-criteria/vlg1-ac1.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; the completion verdict must not regress.
   mutation: write `  *":All checks passed.") ;;` in place of `  "0:All checks passed.") ;;`; prints `mismatch1: exit 0, want 1`, exit 1 (observed).
3. run: `bash docs/plans/vlg-criteria/vlg1-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; a standalone run is not tripped by the skip-summary wrapper and leaves TMPDIR clean.
   mutation: delete ` ANTISLOP_VALIDATE_INNER=1` from the nested-run line; prints `wrapper: exit 1, want 0`, exit 1 (observed).
4. run: `bash docs/plans/lgc-criteria/lgc1-ac1.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; leak detection must not regress.
   mutation: delete the `status=1` line inside the `if [ -n "$leaked" ]` block; prints `fixture: guard exit 0, want 1`, exit 1 (observed).
5. run: `bash docs/plans/lgc-criteria/lgc1-ac2.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; a concurrent write into the project's own directory still does not FAIL.
   mutation: in the `leaked=` line write `find "$CLAUDE_PROJECT_DIR/` in place of `find "$sandbox/`; prints `concurrent: guard exit 1, want 0`, exit 1 (observed).
6. run: `bash docs/plans/lgc-criteria/lgc1-ac3.sh`
   exit: 0
   stdout: empty
   check: green before the unit on purpose; the real gh425 leak is still caught.
   mutation: delete the `mkdir -p "$sandbox/.claude/reviewed"` line; prints `control: guard exit 1, want 0`, exit 1 (observed).
7. run: `bash -n tests/reviewed-dir-leak-guard.test.sh`
   exit: 0
   stdout: empty
   mutation: delete the `esac` line of the verdict `case`; prints `syntax error`, exit 2 (observed).
8. run: `bash docs/plans/epf-criteria/scope.sh vln-3 'tests/reviewed-dir-leak-guard\.test\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
9. run: `bash docs/plans/epf-criteria/range.sh vln-3 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
10. run: `bash docs/plans/epf-criteria/range.sh vln-3 tail tests/reviewed-dir-leak-guard.test.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no tests/reviewed-dir-leak-guard.test.sh (the file is itself a test; criterion 1 is the test for this change and was red before it)
blast-radius: tests/reviewed-dir-leak-guard.test.sh:23,36-37,46 (the three edit sites); only caller tests/validate.sh section 101; no shipped file names it.
commit-message: fix(vln-3): leak guard keeps nested output outside the sandbox
trailer: the trailer names the model you actually ran on.
gate: the file's text spells the marker directory path, so apply edits 1-3 with the Edit tool only (path-checked). Never put its content in a Bash heredoc; reviewed-path-gate.sh blocks that by text, and rewording to get past it is a bypass. If Edit is unavailable, STOP and report.
measured: at 64245e0 the file is 82 lines and each before-block occurs once; criteria 1-6 finish in about 1 s together; do NOT run the full tests/validate.sh or the guard on its own (about 480 s nested; the orchestrator's merge gate G does that).
diagnosis: none
review-packet:
~~~
unit: vln-3 (plan docs/plans/2026-10-14-validate-lanes-followups-2.md)
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
criterion 10: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: vln-4

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 4.

``````
Unit: vln-4

## Objective
Replace the stale timing estimate in the vlg plan's vlg-3 `measured:` line (test "about 5 s", criteria 1-3 "about 40 s") with the re-measured monotonic figures (about 0.35 s and about 3 s, at 5178319). One literal edit to one line; nothing else in the plan changes, and its vlg-3 contract must still score 7/7.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-lanes-followups-2.md`, section `### Unit: vln-4`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md` (one line, the vlg-3 contract's `measured:` line; every other line stays byte-identical)

## Ordered edits
1. file: `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md` (vlg-3 measured: line)
   anchor: line matching `measured: at e13447a each anchor occurs once and validate.sh has 115 sections (116 after edit 2); the test takes about 5 s;`
   indent: 0
   before:
~~~~
measured: at e13447a each anchor occurs once and validate.sh has 115 sections (116 after edit 2); the test takes about 5 s; criteria 1-3 about 40 s together; do NOT run the full tests/validate.sh (the merge gate G covers section 116 through `vsec 111 999`).
~~~~
   after:
~~~~
measured: at e13447a each anchor occurs once and validate.sh has 115 sections (116 after edit 2); the test takes about 0.35 s; criteria 1-3 about 3 s together (re-measured with /proc/uptime at 5178319 on 2026-10-14; the first estimate, 5 s and 40 s, was stale); do NOT run the full tests/validate.sh (the merge gate G covers section 116 through `vsec 111 999`).
~~~~
2. command: `git add docs/plans/2026-10-14-validate-lanes-and-guard-followups.md && git commit -m "docs(vln-4): re-measured vlg-3 timings in the vlg plan" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if an index.lock file exists because a sibling unit is committing, wait a few seconds and retry)
   expect: 0
3. command: `git diff --quiet HEAD -- docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`
   expect: 0

## Do NOT touch
- `docs/plans/2026-10-14-validate-lanes-and-guard-followups.md` outside edit 1 (its other `measured:` lines are still accurate): byte-identical.
- `docs/plans/vlg-criteria/` and `docs/plans/lgc-criteria/`: committed criteria of a finished plan; read-only.
- `tests/validate-lanes.sh`, `tests/validate-lanes.test.sh`, `tests/reviewed-dir-leak-guard.test.sh`: sibling units' files.
- `docs/plans/vln-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/vln-criteria/vln4-ac1.sh`
   exit: 0
   stdout: empty
   mutation: write `0.4 s` in place of `0.35 s` in edit 1's after-line; prints `the re-measured timing text is not present exactly once`, exit 1 (observed). Before the unit it prints `the stale timing text is still present` (observed).
2. run: `bash docs/plans/epf-criteria/scope.sh vln-4 'docs/plans/2026-10-14-validate-lanes-and-guard-followups\.md'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
3. run: `bash docs/plans/epf-criteria/range.sh vln-4 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
4. run: `bash docs/plans/epf-criteria/range.sh vln-4 tail docs/plans/2026-10-14-validate-lanes-and-guard-followups.md`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no docs/plans/2026-10-14-validate-lanes-and-guard-followups.md (a plan document; criterion 1 checks the exact text and the contract score)
blast-radius: docs/plans/2026-10-14-validate-lanes-and-guard-followups.md:1018 (the vlg-3 contract's measured: line); read by bin/contract-guard.js for unit vlg-3 only.
commit-message: docs(vln-4): re-measured vlg-3 timings in the vlg plan
trailer: the trailer names the model you actually ran on.
gate: apply edit 1 with the Edit tool (old_string = the before-line, new_string = the after-line). If Edit is unavailable, STOP and report.
measured: at 64245e0 the before-line occurs once (line 1018); criterion 1 takes under 1 s.
diagnosis: none
review-packet:
~~~
unit: vln-4 (plan docs/plans/2026-10-14-validate-lanes-followups-2.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
