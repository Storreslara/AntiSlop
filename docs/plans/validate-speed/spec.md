# validate.sh speed: from about 29 minutes to about 4, with nothing tested less

Plan slug: validate-speed. Units: vsp-1, vsp-2.

Status: FINAL (spec-master, 2026-10-19). **Two dispatchable units**, so this is
the **fast path**: the dispatch contracts are
[contracts/vsp-1.md](contracts/vsp-1.md) and [contracts/vsp-2.md](contracts/vsp-2.md),
and `task-master` is not needed.
Baseline: HEAD 00b55a75, version 0.31.181. **Neither unit is version-stamped:**
they touch `tests/`, `CONTRIBUTING.md` and `README.md` only, never
`agents/*.md` or `templates/*`, so no plugin.json bump, no CHANGELOG entry and
no `.claude/` mirror regeneration.

## Goal

`bash tests/validate.sh` is the per-unit review gate, the stop-gate's
`testAndLintCommand` and the CI job. It now takes about 29 minutes
(1729 s measured 2026-10-19 on this machine; 1696 s in the aof-u5 review).
Make it take a few minutes **without removing any check from any run**:

- G1 "the default run is parallel": `bash tests/validate.sh` runs its sections
  through the existing lane runner by default; `--serial` keeps today's serial
  run → vsp-1 AC1.1.
- G2 "it works where units are built": the default run also works from a
  linked git worktree → vsp-1 AC1.2.
- G3 "heaviest sections start first" → vsp-1 AC1.3.
- G4 "the real suite takes at most 6 minutes on this machine and every section
  runs" → vsp-1 AC1.4 and vsp-2 AC2.4 (`real-run.sh`).
- G5 "no nested full run": the reviewed-dir leak guard stops re-running the
  whole suite inside itself; the serial run guards leaks itself, and the
  caller's project directory can no longer receive a leak → vsp-2 AC2.1-AC2.3.
- G6 "the docs say what the default is" → vsp-1 AC1.6, vsp-2 AC2.5.

## Context

### Where the time goes (measured, read-only, 2026-10-19)

Sources: (R) the aof-u6 reviewer's full run 20:34:10-21:02:59 (1729 s, exit 1
on `abtest-runner`), section boundaries timestamped by polling its log once a
second; (S) a serial timing of every section, one at a time, in a throwaway tar
copy of the checkout (`CLAUDE_PROJECT_DIR` = the copy, nested guard skipped),
21:03-21:12, partly overlapping another full run (so slightly inflated).
In (S) the abtest suites failed fast because a concurrent abtest run held the
secrets lock on the real checkout while the copy was taken (see Risks R4), so
their figures come from (R) only.

| Rank | Section (header, short) | Seconds | Source |
|---:|---|---:|---|
| 1 | reviewed-dir leak guard: a **nested full validate.sh run** | ~882 | R (guard start ~212 s into the run, end 635.6 s before the end) |
| 2 | tests/abtest-runner.test.sh | 147.7 | R (78.4 in S, FAILed early) |
| 3 | scripts/probe-hook-identity.sh offline tests | 138.0 | S (137.7 in R) |
| 4 | tests/abtest-fixtures.test.sh | 124.6 | R |
| 5 | scripts/unit-outcomes.js | 97.5 | S (95.4 in R) |
| 6 | human-decision gate | 61.6 | S |
| 7 | tests/abtest-probe.test.sh | 41.2 | R |
| 8 | abtest-lock + score + blind + report + report-walk + report-grid + report-edges (combined; the poll saw them in one second) | 40.7 | R |
| 9 | harness-integrity-gate configless write-deny | 22.1 | S |
| 10 | reviewed-path gate | 21.6 | S |
| 11 | tests/abtest-checks.test.sh | 18.1 | R |
| 12 | bin/cli.js legacy-backfill | 14.6 | S |
| 13 | microworld reactive rerun hook | 13.4 | S |
| 14 | bin/contract-score.js | 10.3 | S |
| 15 | abtest-stream 6.7, agent-audit 6.4, rollout preflight 6.1, dispatch-hygiene 4.6, version-stamp-check 4.0, contract-files 4.0, testAndLint skip 4.0, ladder-tier 3.9 | 39.7 | S |
| - | the other 117 sections (99 of them under 1 s each, 19.9 s together) | ~60 | S |

141 sections. Without rank 1, the serial work is about **845 s** (sections
before the guard 210 s in S / 212 s in R; after it 635 s in R). With rank 1 it
is twice that, because the guard re-runs all of it.

Why the slow ones are slow (read from the code, not profiled):
- Rank 1: `tests/reviewed-dir-leak-guard.test.sh` runs `bash tests/validate.sh`
  again with a sandbox `CLAUDE_PROJECT_DIR`, only to see whether anything lands
  in the sandbox's `.claude/reviewed/`. It is the whole suite a second time.
- Rank 2: deliberate wall-clock behaviour (TIMEOUT_MIN=0.02, outer grace and
  KILL timers, `sleep 5`, a 25 s stubborn stub, signal tests). Sleep-bound, low
  CPU.
- Rank 3: the suite re-runs **itself** four times against mutants
  (I37, I42 x3), so it is five suite runs of about 27 s.
- Ranks 4-5: fixture proofs and git scratch repos with many node spawns.

### Alternatives compared

| # | Alternative | Wall saving (est.) | Coverage / guarantee lost | Risk | Effort | Testability | Verdict |
|---|---|---|---|---|---|---|---|
| A | **Drop the nested run** (rank 1): the serial run gives its own sections a sandbox `CLAUDE_PROJECT_DIR` and checks the sandbox afterwards | ~880 s serial (51%) | none: the nested run was exactly "every section with a sandbox CLAUDE_PROJECT_DIR"; the outer run now *is* that run, and the caller's real project dir can no longer receive a leak at all | low | small | stub trees, seconds | **chosen (vsp-2)** |
| B | **Parallel by default**: the existing lane runner (`tests/validate-lanes.sh`, each lane a private tar copy with its own `.git` and `.claude/`, per-section reviewed-dir fingerprint) becomes what `bash tests/validate.sh` does | 845 s of work in 6 lanes: bounded below by rank 2 (148 s); **measured 230.5 s** at 6 lanes | none: same sections, same assertions, same exit code; its per-section fingerprint is **stronger** than the nested guard (it also sees repo-root-relative writes, the guard's documented blind spot) | medium: timing-sensitive assertions under CPU load (R1); lane copies need a readable checkout (R4) | small-medium (wrapper switch, worktree support, order list) | stub trees + real runs | **chosen (vsp-1)** |
| C | Tiered / change-scoped gate (path-to-suite map; unknown path -> full) | after A+B, at most another ~2-3 min | every unmapped coupling is a silent skip: validate.sh is dominated by cross-file parity checks (mirrors, fileHashes, adapter byte-identity, doc links, glossary links), so a correct map is close to "everything"; the gain is small once A+B land | high (fail-open by omission) | medium-high, plus a mandatory release-boundary full-run guard | hard to prove complete | **rejected now**; revisit only if the default run exceeds 6 min after vsp-1/vsp-2 |
| D | Remove waste inside slow suites (rank 3 mutant self-reruns in parallel or scoped, rank 2 sleeps, profile ranks 4-5) | serial: ~80 s from rank 3 alone; parallel wall: ~0 unless ranks 2, 3 and 4 all shrink (rank 2 is a floor of deliberate timeouts) | none if the OK-line set is kept | medium per suite (rank 2 is the eval harness's own timeout logic) | medium, one unit per suite | per-suite OK-line diff | **deferred** (Out of Scope); worth it only after B, if the wall is still above target |
| E | Result cache keyed on content hashes of suite + dependencies | large on re-runs of an unchanged tree | per-suite dependency closures are undeclared, so a stale PASS is a fail-open; a whole-tree key only helps re-runs of the identical tree, and the reviewer must re-run checks itself (Writer/Reviewer split), so the reviewer could never use it | high | medium | hard | **rejected** |
| F | Move probe/stress suites to an opt-in tier | ~140-280 s serial | real coverage: ranks 2-4 are offline unit tests of shipped scripts, not stress tests | medium | small | easy | **rejected** (it reduces what is tested, the last resort per the operator's ordering) |

A + B together: **1729 s -> about 230 s** (6 lanes, measured; about 270 s
with another full run in parallel), with no section removed from any run.

### How the gate is consumed today, and what each consumer becomes

- **Contracts** state the review criterion as `` `bash tests/validate.sh` (exit 0) ``
  (aof-u1..u6 and the abt-u13* contracts; the explorer found no scoped `vsec`
  ranges in recent contracts). **Unchanged.** The string keeps its meaning and
  gets fast. Going forward, task-master and spec-master keep writing exactly
  that criterion, run with the Bash tool's timeout at 600000 ms; no contract
  needs a "do NOT run the full validate.sh" note any more, and no persona file
  changes.
- **reviewer.md, orchestrator.md, task-master.md, spec-master.md,
  lead-programmer.md** do not name `validate.sh` (explorer, grep over agents/
  and templates/: 0 hits). **No persona change.**
- **Stop-gate**: `.claude/persona-config.json` `testAndLintCommand` is
  `bash tests/validate.sh`. `hooks/scripts/lib/stop-gate-core.sh:654-672` runs
  it synchronously at every gated `SubagentStop` (gatedAgents: lead-programmer)
  and blocks on non-zero exit; hooks.json declares no hook `timeout`.
  Claude Code's default command-hook timeout is 600 s, and a timed-out hook is
  cancelled with no decision (claude-code-guide, citing
  https://code.claude.com/docs/en/hooks; that a timed-out Stop/SubagentStop
  hook lets the stop proceed is that agent's inference, not a quoted line).
  **Consequence: since the run passed 600 s, the stop-gate's test check has
  been silently cancelled on every gated stop, so it enforced nothing.** After
  vsp-1 it fits under 600 s again and enforces again. **The key stays
  `bash tests/validate.sh`** (no config change), now meaning the parallel run.
  If the run ever nears 600 s again, the same silent loss returns. Risks R2
  covers that.
- **CI** (`.github/workflows/validate.yml`, on every push and PR):
  `bash tests/validate.sh --verbose`. Unchanged file; it gets the parallel
  default (`nproc` lanes, at most 6, on the runner).
- **Release boundary**: no tier is introduced, so every unit review, every
  gated stop and every CI push runs every section. The "one mechanically
  enforced full run at release" requirement is met by construction; no new
  release guard is needed. (Had C been chosen, it would have needed one.)

### Prior work this builds on, and decisions it revises

- vlg-1..3 and vln-1..4 (2026-10-14, all PASS, no `.fail` record on these
  surfaces) built the lane runner and kept it **opt-in**, "serial
  `tests/validate.sh` stays the merge gate". That was a scope boundary of those
  plans (docs/plans/2026-10-14-validate-lanes-followups-2.md:34, 157-158), not
  an operator ruling. At the time the serial run took 476 s. It now takes
  1729 s and breaks the 600 s Bash cap and the 600 s hook timeout, so this
  plan revises it: **the lane runner becomes the default execution of the
  merge gate**, and the serial run stays available as `--serial`. The
  vlg plan already measured output parity between the two (vlg-2, 70458f7).
- Prior FAIL history: a full search of `.claude/reviewed/*.fail` for
  `validate-lanes` / `reviewed-dir-leak-guard` found only
  `item04-1-measure-footprint.fail`, which mentions the guard as an expected
  flag, not a defect in it. Nothing raises the tier of either unit.
- `bash bin/marker-audit.sh . --notes --surface=` sweep (best-effort; an empty
  sweep proves nothing):
  - `tests/validate.sh`: 8 untagged notes from long-dispatched units 124-149
    (mirror staleness, optional-persona phrasing, untested adapter scripts, a
    pre-existing WARN). None concerns the wrapper or section order; disposition:
    not affected.
  - `tests/validate-lanes.sh`: vlg-2 NOTE[spec] x2 (no regression test until
    vlg-3; "lane copy" missing from the glossary). Both since resolved
    (`tests/validate-lanes.test.sh` exists; `docs/harness-glossary.md` has
    **lane runner** and **lane copy**).
  - `tests/reviewed-dir-leak-guard.test.sh`: gh425-2 notes 2-5 and a vlg-1
    NOTE[spec]. Disposition, all in vsp-2: note 2 (`cd ... || exit 1`) is
    required in the rewritten test; note 3 (an overwrite of an existing marker
    name is invisible) stays fixed because the sandbox starts empty; note 4
    (the nested pass prints OK for a check that did not run) and note 5 (the
    nested exit code is discarded) become moot with no nested run; the vlg-1
    comment-label note becomes moot because the header comment is rewritten.
  - `tests/abtest-runner|probe|lock|checks.test.sh`: no untagged notes. The
    NOTE[spec] items (abt-u04/u04b/u05c/u07/u13) say a suite is "not yet
    registered in validate.sh", and all of them are registered now. abt-u17's
    NOTE[spec] (abtest-checks fails under an empty HOME with no git identity)
    does not apply, because lanes keep the caller's HOME. Neither unit edits
    these suites.
  - `CONTRIBUTING.md`: vlg-3 NOTE[spec] ("lane runner", "lane copy" and "merge
    gate" absent from CONTEXT.md) is resolved for the first two in
    docs/harness-glossary.md; "merge gate" goes to the Scribe update hint.
    The abt-u05e note is unrelated.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-19 Functional scope & success criteria: Q What may the speed-up cost in coverage? → A (self-resolved, from the operator's brief): nothing. The brief orders the options "remove waste and parallelize before reducing what is tested" and requires fail-closed scoping; A and B remove no section from any run, so tiering (C) and opt-in tiers (F) are not needed and are not built.
- 2026-10-19 Non-functional attributes (perf, security, scale): Q What wall time is the target, and on what machine? → A (self-resolved): at most 360 s for a real default run on this 20-core WSL2 machine (`real-run.sh`, `VSP_MAX_SECS=360`), which keeps the run under both the 600 s Bash cap and the 600 s hook timeout with margin; the measured figure is in the Verification record.
- 2026-10-19 Non-functional attributes (perf, security, scale): Q How many lanes by default? → A (self-resolved): min(6, `nproc`), at least 1, overridable with `ANTISLOP_VALIDATE_LANES` (the runner's own 1-8 bound still applies). Six covers the 845 s of work at about the rank-2 floor; each lane copies about 126 MB to TMPDIR.
- 2026-10-19 External dependencies & integrations: Q What does the stop-gate's testAndLintCommand become? → A (self-resolved): unchanged string `bash tests/validate.sh`; it becomes the parallel run. Evidence that it has been silently cancelled by the 600 s hook timeout is recorded in Context.
- 2026-10-19 External dependencies & integrations: Q Does CI need a change? → A (self-resolved): no; validate.yml calls `bash tests/validate.sh --verbose` and inherits the default.
- 2026-10-19 Edge cases / failure handling: Q What happens in a linked worktree, where the lane runner refuses today (exit 2)? → A (self-resolved): vsp-1 makes lanes work there with a private, standalone `.git` per lane built from the common git dir plus the worktree's own HEAD and index (feasibility shown by a scratch prototype; criterion vsp1-ac2.sh).
- 2026-10-19 Edge cases / failure handling: Q The operator said abtest suites must run one at a time; may lanes run two abtest sections at once? → A (self-resolved): yes, because each lane is a private copy. The constraint exists because the suites' secrets lock chmods `eval/abtest/{checks,fixtures}` of the checkout they run in (observed: the tar copy in this session was denied while another session's abtest-runner held the lock). In a lane that is the lane's own copy. Every run-matrix-invoking suite (runner, probe, lock, checks) sets a private `ABT_WORK`, `HOME` and `T`, and its pkill/pgrep patterns are scoped to `$T` or a session id (grep, 2026-10-19). The constraint still holds for direct runs in the shared checkout.
- 2026-10-19 Technical constraints & tradeoffs: Q Should the serial run stay available, and should the nested leak guard survive in it? → A (self-resolved): `--serial` (or `ANTISLOP_VALIDATE_SERIAL=1`) stays as the reference and debugging mode. The nested re-run goes (vsp-2): the serial run's own sections run under the sandbox, which is the same observation without the second pass.
- 2026-10-19 Terminology consistency: Q The glossary's **leak guard** (docs/harness-glossary.md:3419) is the eval's `abt_leak_guard`, not the validate.sh guard; what do we call ours? → A (self-resolved): always "reviewed-dir leak guard", the section header's own name. This plan never says "leak guard" alone.
- 2026-10-19 Terminology consistency: Q "merge gate" is used in the glossary entries **lane runner** and **quiet mode** ("serial tests/validate.sh remains the merge gate"); is it still true? → A (self-resolved): after vsp-1 the merge gate is `bash tests/validate.sh` in its default (parallel) mode; those two entries go to scribe (Scribe update hint).
- 2026-10-19 Completion / acceptance signals: Q How can criteria prove a 4-minute run without a 28-minute baseline? → A (self-resolved): stub-suite throwaway trees for semantics (seconds), plus `real-run.sh` (one real default run, at most 360 s, every section ran, exit 0); the serial run is not run for real by any criterion, because it takes about 845 s even after vsp-2.

## Risks / dependencies

- R1: **Timing-sensitive assertions under parallel load.** abtest-runner
  (`elapsed -lt 22`, `-lt 30`, a 5 s signal deadline), the PostToolUse latency
  budget section and timing-harness sections compare wall time. Six busy lanes
  could push one over. The vlg runs at 3 lanes passed, but the abtest suites
  did not exist then. Mitigation: AC1.5 needs two consecutive green real runs.
  A flake is reported, never fixed by widening a budget in this plan
  (Escalation).
- R2: **The stop-gate starts enforcing again.** A gated lead-programmer stop
  now waits about 3-4 minutes and is blocked on a red suite. That is the
  intended behaviour, but it is new in practice. If the default run ever nears
  600 s, the hook is cancelled silently again; the 360 s bound in AC1.4 is
  the guard.
- R3: **The baseline must be green.** The aof-u6 reviewer's first run at
  00b55a75 ended exit 1 on `tests/abtest-runner.test.sh`, and its second run
  ended exit 0. At 68235153 (aof-u1) `tests/writer-tier-consistency.test.js`
  FAILs in every run. AC1.4/AC1.5/AC2.4 need exit 0.
  If the baseline is still red when vsp-1 is dispatched, the implementer
  reports it (Escalation) rather than fixing another unit's suite.
- R4: **A lane copy needs a readable checkout.** While any process holds the
  abtest secrets lock on the real checkout (a real eval run, or an abtest
  suite run directly in the checkout), the lane runner's tar copy fails, and
  the run FAILs with "could not copy the checkout (tar exits: 2 ...)". This
  fails closed. The serial run would also fail on those suites. Not changed
  by this plan; see Out of Scope item 3.
- R5: **Disk.** About 126 MB per lane in TMPDIR, removed on exit (vln-1
  trap); 6 lanes is about 0.75 GB transient.
- Dependency: vsp-2 after vsp-1 (both edit the validate.sh wrapper block).
  One unit at a time.

## Constitution check (.claude/constitution.md v1.1.0)

- P1 "Verify, don't assume": satisfied. Timings are measured; every criterion
  script was run red at HEAD and green against a scratch prototype (Verification
  record).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. No
  `--update`-managed file is hand-edited; neither unit touches mirrors or
  `fileHashes`.
- P3 "Version-stamp discipline": satisfied. Neither unit touches `agents/*.md`
  or `templates/*`.
- P5 "`tests/validate.sh` is the merge gate": satisfied. The command stays the
  merge gate with every check, and becomes "cheap" again, which P5's own
  rationale assumes. The serial mode stays available.

## Steps

### Step 1 (vsp-1): the lane runner is the default run

Affected files: `tests/validate.sh` (wrapper block, lines 10-48 only),
`tests/validate-lanes.sh`, `tests/validate-lanes.test.sh`, `CONTRIBUTING.md`,
`README.md`.

Acceptance criteria (all from the repository root):
- AC1.1 run: `bash docs/plans/validate-speed/criteria/vsp1-ac1.sh` (exit 0,
  last line `all cases passed`). mutation: at HEAD, A1, A2, A5, A6 and A11 FAIL
  (observed); making `--serial` a no-op FAILs A3 (observed on the prototype).
- AC1.2 run: `bash docs/plans/validate-speed/criteria/vsp1-ac2.sh` (exit 0).
  mutation: at HEAD the runner exits 2 in a linked worktree and W1-W3 and W6
  FAIL (observed).
- AC1.3 run: `for h in abtest-runner abtest-fixtures probe-hook-identity unit-outcomes 'human-decision gate' abtest-probe; do grep -E "^heavy=" tests/validate-lanes.sh | grep -qF "$h" || { echo "missing: $h"; exit 1; }; done`
  (exit 0). mutation: at HEAD it prints `missing: abtest-runner` (observed).
- AC1.4 run: `bash docs/plans/validate-speed/criteria/real-run.sh` with the
  Bash tool's timeout at 600000 ms, on a quiet tree (exit 0, last line
  `real-run: PASS`). mutation: at HEAD the default run is serial, prints no
  `== lanes:` line, and takes over 600 s.
- AC1.5 run: `bash docs/plans/validate-speed/criteria/real-run.sh` twice more,
  in two separate commands (exit 0 both times): the R1 flake check.
- AC1.6 run: `bash tests/validate-lanes.test.sh` (exit 0) and
  `grep -qF 'By default it runs the sections in parallel lanes;' README.md && grep -qF 'runs the sections in parallel lanes by default' CONTRIBUTING.md && grep -qF -- '--serial' CONTRIBUTING.md && grep -qF -- 'runs them one after another' README.md && ! grep -qF 'is an opt-in parallel run' CONTRIBUTING.md`
  (exit 0). The two sentences are fixed verbatim in the vsp-1 contract, edit
  5. mutation: at HEAD the chain exits 1, because neither sentence exists
  (observed).

### Step 2 (vsp-2): the reviewed-dir leak guard without a nested run

Affected files: `tests/validate.sh` (wrapper block only),
`tests/lib/reviewed-dir-guard.sh` (new), `tests/reviewed-dir-leak-guard.test.sh`
(rewritten), `tests/validate-lanes.sh` (header comment and the
`REVIEWED_DIR_LEAK_GUARD_NESTED=1` assignment), `tests/validate-lanes.test.sh`
(the `-u REVIEWED_DIR_LEAK_GUARD_NESTED`), `CONTRIBUTING.md`.

Acceptance criteria:
- AC2.1 run: `bash tests/reviewed-dir-leak-guard.test.sh` (exit 0) and
  `! grep -nE '^[^#]*tests/validate\.sh' tests/reviewed-dir-leak-guard.test.sh`
  (exit 0). mutation: making `reviewed_guard_check` return 0 unconditionally
  makes the test exit 1; at HEAD the grep finds line 51.
- AC2.2 run: `bash docs/plans/validate-speed/criteria/vsp2-ac2.sh` (exit 0).
  mutation: at HEAD G1-G4 and G6 FAIL (observed); removing the sandbox
  `CLAUDE_PROJECT_DIR` assignment FAILs G2 and G3.
- AC2.3 run: `bash tests/validate-lanes.test.sh` (exit 0) and
  `! git grep -n REVIEWED_DIR_LEAK_GUARD_NESTED -- tests CONTRIBUTING.md README.md`
  (exit 0). mutation: at HEAD the git grep lists tests/validate-lanes.sh,
  tests/validate-lanes.test.sh and tests/reviewed-dir-leak-guard.test.sh.
- AC2.4 run: `bash docs/plans/validate-speed/criteria/real-run.sh`, timeout
  600000 ms, quiet tree (exit 0).
- AC2.5 run: `! grep -qF 'nested run' CONTRIBUTING.md` (exit 0). mutation: at
  HEAD CONTRIBUTING.md lines 38-39 say "It skips the leak guard's nested run".

## Open Questions

None. Every decision above was delegated by the operator's brief ("pick the
best") and is recorded in Clarifications. The operator may veto either of
these, and the veto changes the plan:

1. Parallel becomes the default of `bash tests/validate.sh` (revises the
   2026-10-14 "serial stays the merge gate" scope boundary). Default if no
   answer: yes.
2. The tiered or change-scoped gate (C) is not built. Default if no answer:
   not built; revisit if the default run exceeds 6 minutes.

## Out of Scope

1. A tiered or change-scoped gate (C), a result cache (E) and an opt-in tier
   for slow suites (F). See the alternatives table.
2. Waste removal inside suites (D): run probe-hook-identity's four mutant
   self-reruns concurrently or scoped (about 138 s -> about 55 s), and profile
   unit-outcomes (97 s) and abtest-fixtures (125 s). Worth a follow-up spec
   only if `real-run.sh` measures above 300 s after both units.
3. Making the abtest suites lock a private copy instead of the real checkout
   (R4). That needs `eval/abtest/run-matrix.sh` to honour a checks-root
   override (it hard-codes `$HERE/checks`), which is eval-harness code near the
   pre-registration and out of bounds here.
4. Any change to `testAndLintCommand`, hooks, or persona files.
5. The `abtest-runner` FAIL at the baseline (R3): it belongs to aof-u6.

## Self-check

- CHK1: Does every Goal clause map to a step criterion? — PASS (G1-G6 each
  name criteria, and every criterion is listed under its step)
- CHK2: Do steps 1 and 2 agree on who owns the validate.sh wrapper block and
  in what order? — PASS (Dependency in Risks: vsp-1 first; both contracts list
  the wrapper block; vsp-2's contract says it lands on top of vsp-1)
- CHK3: Is the default lane count defined for a machine with fewer than 6
  cores, and for `nproc` failing? — FAIL (missing) — revised in place
  (Clarifications: min(6, nproc), at least 1; AC1.1 A6 computes the same
  expression, with `nproc` failure read as 1)
- CHK4: Is "the real suite passed" defined in a way that a red baseline does
  not silently satisfy? — PASS (real-run.sh needs exit 0, all sections, and
  the last line; R3 and the Escalation sections route a red baseline to a
  report)
- CHK5: Is the serial run's leak-guard behaviour defined for quiet mode as
  well as `--verbose`? — PASS (vsp2-ac2 G4)
- CHK6: Is it defined what happens to a section that reads
  `CLAUDE_PROJECT_DIR` once the serial run sandboxes it? — PASS (Context,
  alternative A: the nested run already ran every section with exactly that
  sandbox, so no section depends on the caller's value)
- CHK7: Does any criterion depend on the full serial run (about 845 s, over
  the 600 s cap)? — PASS (none; only real-run.sh, which is the parallel
  default)
- CHK8: Is each criterion able to fail? — PASS (every mutation line was
  observed at HEAD or on the scratch prototype, except AC1.4's and AC2.4's,
  where HEAD's serial run is over 600 s by measurement, and AC2.1's
  helper mutation, which the implementer proves; see the Verification record)
- CHK9: Constitution P5: does the plan keep `tests/validate.sh` the merge gate
  with every check? — PASS
- CHK10: Is "leak guard" used unambiguously against the glossary? — FAIL
  (conflicting) — revised in place (the plan says "reviewed-dir leak guard"
  everywhere; Clarifications, Terminology)
- CHK11 (replay source): Does criterion AC1.6 still fail under its own
  `mutation:` line, given gh-286-docs's recorded class vacuous (README.md)?
  — FAIL (ambiguous) — revised in place. The first draft only grepped for
  `--serial` anywhere in the file, an existence check that cannot tell
  whether the prose is true. AC1.6 now greps for two sentences that the
  contract fixes verbatim. Both are absent at HEAD (observed). The same
  answer covers gh348-14 and readme-lean-rewrite-followup, which also
  touched README.md.
- CHK12 (replay source): Does criterion AC2.3 still fail under its own
  `mutation:` line, given gh-286-docs's recorded class vacuous (README.md is
  in its git-grep pathspec)? — PASS (at HEAD the git grep lists three files
  under tests/, observed; README.md is only in the pathspec, and the
  criterion does not depend on it)
- CHK13 (replay source): Do AC1.4 and AC2.4 (`real-run.sh` runs
  tests/validate.sh, which 14 recorded vacuous or host units touched, e.g.
  gh317, gh409, spec2-unitA) still fail under their mutation lines? — PASS.
  real-run.sh needs the lane runner's `sections: N` line to equal the header
  count, so it fails for the serial baseline (no such line) and for any run
  that skips a section. It also needs exit 0 and the closing line. Observed:
  the 6-lane run printed `sections: 141` against 141 headers.

## Verification record

At HEAD 00b55a75 (spec-master, 2026-10-19):
- `vsp1-ac1.sh`: A1, A2, A5, A6 and A11 FAIL, the rest ok (A11 took 12.0 s
  serially). `vsp1-ac2.sh` W1-W3 and W6 FAIL (exit 2, linked worktree refused).
  `vsp2-ac2.sh`: G1-G4 and G6 FAIL, G5 ok.
- Against a scratch prototype (a copy of `tests/validate.sh`,
  `tests/validate-lanes.sh` and `tests/lib/` in the session scratchpad, never
  committed): about 10 lines in the wrapper (a `--serial` flag, lanes default,
  min(6, nproc)), about 12 lines in the lane runner (linked worktree: tar of
  the common git dir without `worktrees/`, then the worktree's HEAD and index),
  and a 9-line guard helper. With these, all of vsp1-ac1, vsp1-ac2 and
  vsp2-ac2 passed (A11 took 2.1 s). Making `--serial` a no-op turned A3 red.
- Real lane runs of the current suite with the existing runner
  (`bash tests/validate-lanes.sh --lanes N`, the nested guard skipped as in
  vsp-1), timed with /proc/uptime:
  - 6 lanes at 00b55a75, quiet tree: **230.5 s, exit 0, 141 of 141 sections**
    (the abtest suites ran concurrently in separate lanes and all passed).
  - 8 lanes, while commit 68235153 (aof-u1) landed mid-run: 212.9 s, exit 1.
    Two FAILs come from aof-u1's content (`tests/writer-tier-consistency.test.js`,
    AC-P4 on agents/orchestrator.md). The third, `tests/abtest-arms.test.sh`,
    printed nothing and passed when run alone right after (108/108). It is not
    explained, and is recorded under R1/R4.
  - 6 lanes at 68235153, overlapping another session's serial validate.sh run:
    265.7 s, exit 1 on the same two aof-u1 FAILs only (abtest-arms passed).
  - Conclusion: about **230 s quiet, up to about 270 s under load**, against
    1729 s today (-85% to -87%). 8 lanes gains about 18 s over 6, so the
    default stays 6.

## Scribe update hint

After both units PASS: `docs/harness-glossary.md` **lane runner** (default
lane count and "opt-in" wording; "Serial tests/validate.sh remains the merge
gate" is no longer true), **lane copy** (linked-worktree lanes; the serial
guard's blind spot no longer applies to the default run), **quiet mode** (the
same merge-gate sentence). A new entry for the serial run's sandboxed
`CLAUDE_PROJECT_DIR` belongs under "reviewed-dir leak guard", never "leak
guard" (that term is the eval's). README/CONTRIBUTING are edited by the units
themselves.

## Dispatch (fast path)

- vsp-1: [contracts/vsp-1.md](contracts/vsp-1.md)
- vsp-2: [contracts/vsp-2.md](contracts/vsp-2.md) (after vsp-1 PASS)
