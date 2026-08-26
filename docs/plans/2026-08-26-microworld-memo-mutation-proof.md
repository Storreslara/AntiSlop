# Fix `_memo_setup`'s suite memo defeating mutation-proof bundles

**STATUS: FINAL** — all Open Questions resolved 2026-08-26. Two dispatchable
units; fast path (≤5 units), no `task-master` slicing, no tracker issue.

Date: 2026-08-26 · Author: spec-master · Source diagnosis:
`.claude/agent-memory/spec-master/project_microworld_memo_defeats_mutation_proofs.md`
(commit 82e0724, amended 2026-08-26 with the premise correction below)

---

## Goal

Make `_memo_setup`'s memoizing `bash` wrapper in
`hooks/scripts/lib/microworld-queue.sh` **correct for repeated invocations of
the same suite whose outcome can legitimately differ**, so mutation-proof
microworld bundles stop reporting false FAILs under the drain loop — while
keeping the suite-level dedup guarantee (AC-A4) that the memo exists to
provide.

Concretely, at the end of this work all five of these hold:

1. A bundle that invokes `bash tests/X.test.sh`, then re-invokes the *same*
   suite after changing something that alters its outcome, observes two
   *different* exit codes.
2. Three different bundles invoking `bash tests/X.test.sh` identically, with
   nothing changed between them, still execute that suite **exactly once**
   (AC-A4 unregressed).
3. A drain-loop **second pass** — which exists precisely because a new edit
   landed — re-executes the suite rather than serving the pass-1 result.
4. Guarantees 1 and 3 are each covered by a committed, machine-checkable
   regression test **proven non-vacuous** (reverting the corresponding fix
   turns exactly that case red).
5. `microworlds/rpg-canon-2/run.sh` and `microworlds/hdg-anchor-1/run.sh`
   exit 0 when run under a live `_memo_setup` wrapper, as they already do
   standalone.

Non-goals: redesigning the queue, coalescing, lock, or audit-log mechanisms
(reviewer-PASSed as spec2-unitA); removing memoization; adding a new
microworld bundle; touching spec2-unitB's `stop-gate-core.sh` work.

---

## Context

`_memo_setup` (`hooks/scripts/lib/microworld-queue.sh:58-80`) exports a shell
**function** named `bash`. Because a function shadows the external command for
a bare `bash …` invocation and `export -f` makes it visible to child bash
processes, every `bash tests/*.test.sh` call inside a bundle's `run.sh` is
intercepted; every other invocation falls through via `command bash`. The
wrapper caches the exit code in `$MICROWORLD_MEMO_DIR/results/<key>.rc` where

```sh
key="$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')"
```

— **the test file path, and nothing else.** No argv beyond `$1`, no
environment, no cwd, no content of the code under test.

`_memo_setup` is called once per drain loop, from `_drain_loop` (`:136`); the
memo dir is a `mktemp -d` torn down when the loop exits — and, critically, it
survives across the outer `while` at `:141`, so a *second* drain pass reuses
results computed against the pre-edit tree.

The memo's value is real: of the nine bundles in `microworlds/`, four
(`hdg-lexer-1`, `hdg-prose-2`, `hdg-prose-2-fix2`, `rpg-comment-3`) each
invoke the *same two* suites, so one drain pass collapses eight suite
executions into two.

### What the two affected bundles actually do (premise correction)

The recorded diagnosis proposed keying on "a content hash of the file(s) the
invoked suite actually exercises." **Measured: that would not fix either
affected bundle.** Neither mutates a file in the working tree. Both copy
`hooks/scripts/lib` into a `mktemp -d`, build a mutant *there*, and re-invoke
the suite with an environment prefix pointing at it:

- `microworlds/rpg-canon-2/run.sh:29` —
  `GATE_UNDER_TEST="$d/$site.sh" bash tests/reviewed-path-gate.test.sh`
  (twice, `site1` and `site2`), after an unmutated baseline call at `:9`.
- `microworlds/hdg-anchor-1/run.sh:31` —
  `GATE_UNDER_TEST="$d/mutant.sh" bash tests/human-decision-gate.test.sh`,
  after an unmutated baseline call at `:8`.

The repo tree is byte-identical across baseline and mutant runs. **The only
difference is the process environment.** A tree-content hash would compute the
same key for both and the bug would survive.

### Measurements taken while scoping (all at clean HEAD, 2026-08-26)

Reproduced in a scratch harness replicating `_memo_setup`'s wrapper verbatim:
three identical dedup bundles, then one mutation-proof bundle run *after* them,
so the cache is already populated by another bundle — the realistic ordering.

| Key variant | AC-A4 dedup (want 1 execution) | Mutation proof |
|---|---|---|
| current (`$1` only) | 1 ✓ | **BROKEN** — baseline rc 0, mutant rc 0 |
| argv + `env` digest | 1 ✓ | OK — baseline rc 0, mutant rc 3 |
| owner PID stored in the `.rc` file | 1 ✓ | **BROKEN** — the mutating bundle never becomes the entry's owner, so every one of its calls is a cross-owner hit |
| "one cache hit per shell per key" (`<key>.$$.seen`) | 1 ✓ | OK |
| **both digest + `.seen` guard (chosen)** | 1 ✓ | OK |

Further facts established by measurement rather than assumed:

- A variable-assignment prefix on a call to the exported `bash` **function**
  *is* visible inside the function body, *is* exported to the `command bash`
  child, and does *not* persist in the caller afterwards. So an env-derived
  key sees `GATE_UNDER_TEST` exactly when it must.
- The exported environment is byte-identical across bundle `run.sh`
  invocations under `_run_bundle`'s exact `( cd … && timeout … bash ./run.sh )`
  shape — including when the `run.sh` scripts differ and run different
  preceding commands. `_` reads as the digest helper's own path (`env`), so it
  is constant, not a divergence source. This is why an unfiltered `env` digest
  does not regress dedup, and why no exclusion list is needed.
- Digest cost: `{ printf '%s\n' "$@"; env | sort; } | cksum` measured at ~1 ms
  per call, against suite runtimes of seconds to minutes (`rpg-canon-2` alone
  runs 69 s against a 180 s manifest timeout).
- `cksum` is **not** a new dependency for the shipped hook set —
  `hooks/scripts/dispatch-hygiene.sh` already uses it at `:29`, `:132`, `:134`,
  `:136`, `:145`. `env` is POSIX. `env -0` is deliberately **rejected** (BSD/
  macOS `env` has no `-0`); plain `env | sort` was measured to work.
- No committed test references `_memo_setup` or `MICROWORLD_MEMO` by name;
  the memo is exercised only indirectly, through case `(i)` of
  `tests/microworld-rerun.test.sh`. There is no direct unit-test seam today,
  and this plan does not add one.

### Chosen design (pseudo-code — not production code)

```
bash():
  if $1 does not match tests/*.test.sh: run `command bash "$@"`; done

  key   = sanitize($1) + "." + digest(argv "$@" ++ `env | sort`)
  rc_f  = $MICROWORLD_MEMO_DIR/results/<key>.rc
  seen  = $MICROWORLD_MEMO_DIR/results/<key>.$$.seen

  if rc_f exists AND seen does NOT exist:      # first hit for THIS shell
      touch seen; return contents of rc_f      #   -> dedup, AC-A4
  touch seen                                   # this shell has now consumed it
  run `command bash "$@"`; rc = $?
  if rc_f does not exist: write rc to rc_f     # never overwrite: the first
                                               #   (unmutated) result is the
                                               #   one worth sharing
  return rc
```

and, in `_drain_loop`, at the top of each outer iteration (`:141`), before the
`*.pending` glob:

```
rm -rf "${memo_dir:?}/results"   # ":?" guards against an empty memo_dir
mkdir -p "${memo_dir}/results"
```

Three independent guards, each closing a distinct hole:

- the **digest** stops a *cross-bundle* entry computed under a different
  environment from being served here (the measured `rpg-canon-2` /
  `hdg-anchor-1` failure);
- the **`.$$.seen` guard** stops *any* repeat within one `run.sh` process from
  being served a cached result, whatever the mutation mechanism — including
  the in-tree `sed -i …; bash tests/X.test.sh; restore` shape that a digest
  over the environment alone would not catch. Without it, the most natural way
  to write a future mutation-proof bundle silently reintroduces this bug;
- the **per-pass flush** stops a pass-1 result, computed against the pre-edit
  tree, from being served in pass 2, which exists only because an edit landed.

`$$` is the invoking shell's PID and is stable across subshells, pipelines and
backgrounding within one `run.sh`, so the `.seen` guard is not defeated by
`( … )` or `|` in bundle code. Across passes the PIDs differ anyway, which is
exactly why the flush is a *separate* guard and not redundant with it.

Noted in passing (no action): `microworlds/gh347-1/run.sh:5` uses `exec bash
tests/…`, and `exec` bypasses shell-function lookup entirely, so that bundle
is already unmemoized. Harmless; recorded so nobody "fixes" it.

---

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

- 2026-08-26 Non-functional attributes: Q Does adding a per-invocation digest
  defeat the memo's own purpose (latency)? → A (self-resolved): no — measured
  ~1 ms per memoized call versus suite runtimes of seconds to minutes. The
  memo's saving is unaffected.
- 2026-08-26 External dependencies & integrations: Q Does an environment
  digest introduce a new external dependency into the shipped hook set, and is
  it portable? → A (self-resolved): no new dependency — `cksum` is already
  used by `hooks/scripts/dispatch-hygiene.sh` at five sites, and `env` is
  POSIX. `env -0` rejected on portability grounds (BSD/macOS `env` lacks
  `-0`); plain `env | sort` measured to work.
- 2026-08-26 Technical constraints & tradeoffs: Q What is the true artifact
  count for a change to this file? → A (self-resolved): **seven** — the source
  plus three byte-identical generated mirrors (`.claude/`, `adapters/codex/`,
  `adapters/cursor/`, all currently md5 `eaa1154764b2b992542a3b94f1d0ee8b`)
  plus three `fileHashes` entries in `.claude/persona-config.json` (`:215-217`,
  all currently sha256 `f3447a43…`). `tests/validate.sh:302` diffs
  `hooks/scripts` against `.claude/hooks/scripts`, and
  `tests/filehashes-currency.test.js` gates the baselines, so the source edit
  and the re-render **cannot** be split across units.
- 2026-08-26 Functional scope & success criteria: Q Is the diagnosis memo's
  proposed "content hash of the files the suite exercises" the right fix? → A
  (self-resolved): **no** — measured premise correction, see Context. Neither
  affected bundle mutates the tree; both mutate a temp copy and differentiate
  by environment. That direction would leave the bug in place.
- 2026-08-26 Functional scope & success criteria: Q Which correctness
  mechanism goes into the key (OQ1)? → A: **both** the argv+`env` digest and
  the `<key>.$$.seen` same-shell guard, per user. The explicit-opt-out
  alternative was rejected as opt-in-to-correctness.
- 2026-08-26 Domain entities / data model: Q What is the memo entry's on-disk
  shape after the fix? → A (self-resolved): unchanged in kind — still a plain
  file under `$MICROWORLD_MEMO_DIR/results/` whose contents are the exit code
  — but the filename gains a digest suffix, and a sibling zero-byte
  `<key>.$$.seen` marker is added per consuming shell. Both live and die with
  the drain loop's `mktemp -d`; nothing is added to `.claude/`.
- 2026-08-26 User interaction flow: Q Is there a user-facing surface? → A: no
  — the only "actor" is a future bundle author writing a `run.sh`, and the
  chosen fix keeps that contract implicit (correct by default). OQ1 option (d)
  would have made it explicit (an opt-out flag the author must know to set);
  the user rejected it, so this category is closed with no surface added.
- 2026-08-26 Edge cases / failure handling: Q What happens across drain-loop
  *passes* (the outer `while` at `:141`), where a new edit has landed since
  the cached result was computed (OQ2)? → A: **include the one-line flush in
  `_drain_loop`**, per user, with its own regression case and mutation proof
  (AC-1.9/AC-1.10).
- 2026-08-26 Completion / acceptance signals: Q Is "the two real bundles exit
  0 under the memo" a criterion, and does it belong in `tests/validate.sh`
  (OQ3)? → A: **required, reviewer-run, NOT added to `tests/validate.sh`**,
  per user — the merge gate already carries ~1700 checks and this adds ~2-3
  minutes.
- 2026-08-26 Completion / acceptance signals: Q Does this unit get its own
  microworld bundle (OQ4)? → A: **no**, per user — rely on the regression
  cases. Only 9 of ~400 units have a bundle, and one here would be exercised
  by the very drain loop under repair (R7).
- 2026-08-26 Terminology consistency: Q Do "mutation proof", "suite-level
  memoization" and "memoizing bash wrapper" have `CONTEXT.md` entries? → A
  (self-resolved): no. `CONTEXT.md:458-459` and `:470-471` *mention*
  "suite-level dedup" and "memoizing bash wrapper" inside the **drain loop**
  and **coalescing** entries, but neither is a defined term, and **mutation
  proof** — the repo's primary anti-vacuity mechanism, and the thing this bug
  breaks — has no entry at all. Closed by Step 2 within this plan. Drift lenses
  1 (redefined term) and 2 (new synonym) turned up nothing; only lens 3
  (undefined load-bearing term) fired.
- 2026-08-26 Functional scope & success criteria: Q Was this already known? →
  A (self-resolved): yes, partially — `.claude/reviewed/spec2-unitA.pass` note
  N6 already records "`:60-63` memo key from `$1` only" as an unresolved
  carried-forward finding. It shipped as a non-blocking note and nobody acted
  on it. Recorded in R1; it is why the mutation proofs are mandatory rather
  than advisory.

---

## Risks and dependencies

- **R1 — This finding already shipped once as a non-blocking note.**
  `spec2-unitA.pass` N6 names the exact defect and it was carried forward, not
  fixed. Treat "the reviewer already knows" as *no* evidence of coverage;
  AC-1.4 and AC-1.10 are the controls.
- **R2 — Protected path.** `hooks/scripts/lib/microworld-queue.sh` is a
  `protectedPaths` entry (`.claude/persona-config.json:112`). Human approval
  for this fix is already granted; the orchestrator lifts protection at
  dispatch. The lead-programmer must not edit the `protectedPaths` entry
  itself, or re-request approval.
- **R3 — Seven-artifact change.** Splitting the source edit from the mirror
  re-render breaks `tests/validate.sh:302` and
  `tests/filehashes-currency.test.js`. Step 1 is deliberately one unit.
- **R4 — Constitution P2.** The mirrors and `fileHashes` have a script-driven
  path. They must be produced by `node bin/cli.js --update --force-render`,
  never hand-copied or hand-edited.
- **R5 — The drift-check idiom is broken.** Do **not** gate on
  `node bin/cli.js --update --check | grep -qE ': (updated|created|pending)$'`;
  that pattern detects nothing. Use AC-1.6/AC-1.7 instead.
- **R6 — Do not "fix" the bundles.** `microworlds/rpg-canon-2/` and
  `microworlds/hdg-anchor-1/` are correct as written. Weakening either to make
  the queue green deletes real anti-vacuity coverage.
- **R7 — Verifying under the real queue is self-referential.** The drain loop
  that would run a bundle proving this fix is itself the thing under test.
  AC-1.1 therefore drives `_memo_setup` directly (sourcing the lib) rather
  than waiting on a live drain; AC-1.3 and AC-1.9 use the real end-to-end path
  but on synthetic fixture projects, never on this repo's own bundles.
- **R8 — Sourcing the lib sets shell options.**
  `hooks/scripts/lib/microworld-queue.sh:24` runs `set -euo pipefail` at top
  level, so anything sourcing it inherits `errexit`. Prior art:
  `hooks/scripts/lib/microworld-rerun-core.sh:43` sources it the same way.
  AC-1.1's harness must account for this or it will abort on the first
  non-zero.
- **R9 — Concurrent unit.** spec2-unitB's `stop-gate-core.sh` work is in
  flight. No file overlap; do not touch it.
- **R10 — Do not trust `.claude/microworld-audit.log` while verifying.**
  Before this fix, `result=fail` for a mutation-proof bundle is
  unconditionally wrong. Verify by the criteria below, never by reading that
  log.
- **R11 — Test-timing sensitivity in AC-1.9.** The two-pass case depends on
  re-enqueueing *while pass 1 is still running*. It must be made deterministic
  by polling for `.runner.lock` before the second enqueue and by giving the
  fixture bundle a long enough body — not by a bare `sleep` race. A case that
  can silently degrade into a single pass would be vacuous.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every load-bearing claim in Context
  (which bundles are affected, why a tree hash fails, that the env prefix
  reaches the wrapper, that the digest preserves dedup, that `cksum` is
  already shipped, the artifact count, the absence of a direct test seam) was
  measured, not inferred. AC-1.4 and AC-1.10 extend the same standard to the
  fix itself.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  three mirrors and three `fileHashes` entries are regenerated by
  `node bin/cli.js --update --force-render`; hand-editing them is forbidden in
  Step 1's `## Do NOT touch`.
- P3 "Version-stamp discipline": not triggered — `hooks/scripts/lib/*.sh`
  carries no version stamp and is neither `agents/*.md` nor a template. Same
  reading the reviewer recorded for spec2-unitA ("P3 not triggered").
- P4 "Optional personas degrade gracefully" (SHOULD): not triggered — no
  persona-conditional prose is added.
- P5 "`tests/validate.sh` is the merge gate": satisfied — AC-1.5 gates on a
  full `tests/validate.sh` run with no *new* FAIL relative to a baseline
  captured on the same tree.

---

## Steps

### Step 1 — Fix the memo key, flush per pass, and land two non-vacuous regression cases

**Affected files**
- `hooks/scripts/lib/microworld-queue.sh` — `_memo_setup` (`:58-80`) and
  `_drain_loop`'s outer loop (`:141`)
- `tests/microworld-rerun.test.sh` — two new lettered cases; existing case
  `(i)` (`:340-383`) left semantically intact
- `.claude/hooks/scripts/lib/microworld-queue.sh` — **generated**
- `adapters/codex/hooks/scripts/lib/microworld-queue.sh` — **generated**
- `adapters/cursor/hooks/scripts/lib/microworld-queue.sh` — **generated**
- `.claude/persona-config.json` `fileHashes` `:215-217` — **generated**
- `CHANGELOG.md` — one entry, no version bump (P3 not triggered)

**Acceptance criteria**

- **AC-1.1 (the bug is fixed on the real bundles, end-to-end).** A script that
  sources `hooks/scripts/lib/microworld-queue.sh`, calls `_memo_setup` on a
  fresh `mktemp -d`, and then runs `bash ./microworlds/rpg-canon-2/run.sh` and
  `bash ./microworlds/hdg-anchor-1/run.sh` from the repo root, **exits 0 for
  both**. Expect ~2-3 minutes total. Reviewer-run; **not** added to
  `tests/validate.sh`. Mind R8 (`set -euo pipefail` is inherited by sourcing).
- **AC-1.2 (AC-A4 dedup unregressed).** `bash tests/microworld-rerun.test.sh`
  exits 0 and its output still contains a line beginning `OK   (i) dedup:`
  reporting the suite ran exactly once with 3 per-bundle audit lines.
- **AC-1.3 (mutation-proof regression case).** `bash
  tests/microworld-rerun.test.sh` output contains a new `OK` line for a case
  that: builds a fixture project whose bundle `run.sh` invokes
  `bash tests/<suite>.test.sh` once plainly and once with a differing
  environment prefix; runs it through the real hook and drain loop using the
  existing `make_project` / `run_hook` / `wait_for_drain` helpers; asserts the
  two invocations returned **different** exit codes. The cache must be
  pre-populated by at least one *other* fixture bundle invoking the same suite
  **before** the mutation-proof bundle runs — the ordering that exposed the
  naive owner-PID variant during scoping.
- **AC-1.4 (AC-1.3 is non-vacuous).** With `_memo_setup`'s key/guard logic
  reverted to the pre-fix `key="$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')"`
  form and the `.seen` guard removed, nothing else changed, `bash
  tests/microworld-rerun.test.sh` **exits non-zero** and prints a `FAIL` line
  for the AC-1.3 case, while still printing `OK   (i) dedup:`. Restoring the
  fix returns it to exit 0. Both directions recorded in the unit report with
  actual command output.
- **AC-1.5 (merge gate, no new failures).** `bash tests/validate.sh` produces
  no FAIL line absent from a baseline run captured on the same tree
  immediately before the change. (`tests/protected-paths-gate.test.sh` Test 6
  is a known pre-existing FAIL attributed to spec2-unitE — baseline, not a
  regression.)
- **AC-1.6 (mirror parity).** `md5sum` of all four copies of
  `microworld-queue.sh` prints four identical digests, and `diff -rq
  hooks/scripts .claude/hooks/scripts` exits 0.
- **AC-1.7 (fileHashes currency).** `node tests/filehashes-currency.test.js`
  exits 0, and the three `microworld-queue.sh` `fileHashes` entries in
  `.claude/persona-config.json` have moved away from
  `f3447a43ec1dae4f3bb4e1641e1b9ec6704647da81d6a6fcf9a910d7eba498ec`.
- **AC-1.8 (blast radius).** `git diff --name-only` lists exactly: the four
  `microworld-queue.sh` copies, `.claude/persona-config.json`,
  `tests/microworld-rerun.test.sh`, `CHANGELOG.md` — and nothing else. In
  particular nothing under `microworlds/` and no `stop-gate-core.sh` copy.
- **AC-1.9 (per-pass flush regression case).** `bash
  tests/microworld-rerun.test.sh` output contains a second new `OK` line for a
  case that: builds a fixture bundle whose `run.sh` takes long enough to
  observe (≥2 s) and invokes `bash tests/<suite>.test.sh`, where that suite
  appends one line to a marker file; enqueues it; **polls until
  `<dot>/microworld-queue/.runner.lock` exists**; re-enqueues the same bundle
  so the second run lands in drain pass 2; waits for drain; then asserts
  **both** that the audit log holds exactly 2 lines for that slug (proving two
  passes really happened, per R11) **and** that the marker holds exactly 2
  lines (proving the suite re-executed in pass 2).
- **AC-1.10 (AC-1.9 is non-vacuous).** With only the `_drain_loop` flush
  removed and `_memo_setup` left fixed, `bash tests/microworld-rerun.test.sh`
  **exits non-zero** with a `FAIL` line for the AC-1.9 case reporting 2 audit
  lines but 1 marker line, while AC-1.2's and AC-1.3's cases still print `OK`.
  Restoring the flush returns it to exit 0. Both directions recorded with
  actual output. (This criterion is discriminating by construction: pass 1 and
  pass 2 run in different processes with identical environments, so neither
  the digest nor the `.seen` guard can produce the re-execution — only the
  flush can.)

### Step 2 — Record the terms and correct the standing guidance (scribe)

**Affected files**
- `CONTEXT.md` (glossary)
- `.claude/agent-memory/spec-master/project_microworld_memo_defeats_mutation_proofs.md`

**Acceptance criteria**

- **AC-2.1.** `CONTEXT.md` gains a `**mutation proof**:` glossary entry
  defining it as the repo's primary anti-vacuity mechanism (a bundle that
  mutates the code under test and re-invokes the same suite expecting a
  *different* exit code), cross-linked to `[[Microworld bundle]]` (the
  canonical entry name, `CONTEXT.md:976` — not "microworld bundles") and
  `[[drain loop]]`. Verifiable: `grep -c '^\*\*mutation proof\*\*:' CONTEXT.md`
  prints `1`.
- **AC-2.2.** `CONTEXT.md` gains a `**suite-level memoization**:` entry
  defining the exported-`bash`-function wrapper, its AC-A4 dedup purpose, its
  post-fix key composition (path + argv/environment digest, plus the
  per-shell `.seen` guard and the per-pass flush), and the drain-loop-scoped
  lifetime of `$MICROWORLD_MEMO_DIR`. Verifiable:
  `grep -c '^\*\*suite-level memoization\*\*:' CONTEXT.md` prints `1`.
- **AC-2.3.** The existing **drain loop** (`CONTEXT.md:451-463`) and
  **coalescing** (`:464-472`) entries reference `[[suite-level memoization]]`
  instead of describing the wrapper inline, with no remaining claim that
  contradicts the new entry. Verifiable: `grep -n 'suite-level memoization'
  CONTEXT.md` returns at least three line numbers, at least two of them inside
  the drain-loop/coalescing block (`:451-472` as it stands before this edit;
  allow for the block shifting if the new entries are inserted above it).
- **AC-2.4 (the standing guidance becomes wrong and must be corrected).** The
  diagnosis memo currently tells readers to treat *every* mutation-proof
  bundle's queue verdict as unconditionally wrong. After Step 1 that is false
  and would suppress a real regression. The memo must scope that instruction
  to commits **before** Step 1's fix commit, naming that sha. Verifiable: the
  file contains Step 1's commit sha and no longer contains an unqualified
  "unconditionally wrong" claim.
- **AC-2.5.** `bash tests/validate.sh` still exits with no new FAIL.

---

## Open Questions (all resolved 2026-08-26)

- **OQ1 — Which correctness mechanism goes into the key?** → **RESOLVED:
  both** the argv+`env` digest and the `<key>.$$.seen` same-shell guard.
  Alternatives rejected: digest-only (leaves in-tree mutation broken),
  guard-only (leaves cross-bundle env divergence reusable), explicit opt-out
  flag (opt-in-to-correctness). Folded into Step 1 and the Context design.
- **OQ2 — Flush the memo between drain-loop outer passes?** → **RESOLVED:
  yes**, one line in `_drain_loop`. Folded into Step 1; gated by AC-1.9 and
  AC-1.10. Closes CHK8.
- **OQ3 — Is AC-1.1 required, and does it go into `tests/validate.sh`?** →
  **RESOLVED: required, reviewer-run, not in `tests/validate.sh`.** Closes
  CHK9.
- **OQ4 — Add a microworld bundle for this unit?** → **RESOLVED: no.**

No open questions remain. Nothing in this plan is deferred to a named
assumption.

---

## Self-check

- **CHK1:** Does the plan state which of the nine `microworlds/` bundles are
  affected, and on what evidence? — PASS (Context: exactly `rpg-canon-2` and
  `hdg-anchor-1`, by file:line of their mutant invocations plus the recorded
  stable fail/pass split across four drains).
- **CHK2:** Does the plan resolve the conflict between the diagnosis memo's
  proposed fix (tree-content hash) and the fix it specifies? — PASS (Context
  "premise correction"; dated Clarifications line; the memo itself amended).
- **CHK3:** Is "preserve memoization for the non-mutation-proof case" backed
  by a machine-checkable criterion, not prose? — PASS (AC-1.2 gates on the
  existing `OK   (i) dedup:` line, which asserts exactly-one suite execution
  and 3 audit lines).
- **CHK4:** Is each new regression case protected against being vacuous? —
  PASS (AC-1.4 for the key/guard, AC-1.10 for the flush; each requires both
  directions with recorded output).
- **CHK5:** Do Step 1's affected-files list and AC-1.8 agree on the exact
  artifact set? — PASS (both name the four copies,
  `.claude/persona-config.json`, `tests/microworld-rerun.test.sh`,
  `CHANGELOG.md`; AC-1.8 additionally forbids anything else).
- **CHK6:** Is the reason the source edit and re-render cannot be split stated
  with a citation rather than asserted? — PASS (R3 cites
  `tests/validate.sh:302` and `tests/filehashes-currency.test.js`).
- **CHK7:** Is every taxonomy category that was ever scored Partial now
  represented by a dated Clarifications line? — PASS (categories 1, 2, 3, 6, 8
  and 9 each carry at least one dated line; 4, 5 and 7 carry lines too).
- **CHK8:** Does the plan say what happens to the memo across drain-loop
  passes? — FAIL (missing, in the provisional draft) — converted to Open
  Question **OQ2**, now resolved and folded into Step 1 (AC-1.9/AC-1.10).
- **CHK9:** Is "the two real bundles exit 0 under the memo" stated as a
  runnable command with a defined pass signal, or as prose? — FAIL
  (ambiguous, in the provisional draft) — revised in place; AC-1.1 names the
  sourcing, the `_memo_setup` call, both `run.sh` paths and the exit-0 signal,
  and its placement was settled by **OQ3**.
- **CHK10:** Does the plan prevent the "weaken the bundle to make the queue
  green" failure the diagnosis warns about? — PASS (R6 plus Step 1's `## Do
  NOT touch`, plus AC-1.8, which fails if any `microworlds/` file is touched).
- **CHK11:** Does Step 2 notice that Step 1 *invalidates* the currently
  recorded guidance? — PASS (AC-2.4).
- **CHK12:** Is the constitution check a real per-principle pass rather than a
  blanket claim? — PASS (five principles, each with a stated ground; P3 and P4
  explicitly marked not-triggered, with the reason).
- **CHK13:** Do Steps 1 and 2 disagree anywhere about the key's composition? —
  FAIL (conflicting, in the provisional draft, where AC-2.2 still described a
  tree-content hash) — revised in place; AC-2.2 now names the settled
  composition explicitly.
- **CHK14:** Can AC-1.9's case silently degrade into a one-pass run and pass
  anyway? — FAIL (ambiguous, first draft asserted only the marker count) —
  revised in place; AC-1.9 now requires the audit log to show exactly 2 lines
  for the slug *as well as* 2 marker lines, so a single-pass degradation fails
  rather than passes. R11 records the hazard.
- **CHK15:** Is AC-1.10 discriminating for the flush *specifically*, rather
  than being satisfiable by the digest or the `.seen` guard? — PASS (AC-1.10
  states the ground: pass 1 and pass 2 run in different processes with
  identical environments, so neither other guard can cause the re-execution).
- **CHK16:** Does the plan name a single mechanism for the memo key, rather
  than leaving the reader to pick among the measured variants? — FAIL
  (ambiguous, in the provisional draft, which listed four candidates) —
  converted to Open Question **OQ1**, now resolved: digest **and** `.seen`
  guard, stated once in Context "Chosen design" and referenced by Step 1 and
  the `memo-key-1` contract rather than restated.
- **CHK17:** Does the plan state whether this unit ships a microworld bundle
  of its own? — FAIL (missing, in the provisional draft) — converted to Open
  Question **OQ4**, now resolved: no bundle; recorded as a Goal non-goal and
  in the `memo-key-1` contract's `## Do NOT touch`.

---

## Dispatch contracts (fast path — orchestrator dispatches these directly)

### Unit: memo-key-1

**## Objective**
Fix `_memo_setup`'s suite memo in `hooks/scripts/lib/microworld-queue.sh` so
that repeated invocations of the same test suite whose outcome can
legitimately differ are no longer served a stale cached exit code, while
keeping AC-A4 suite-level dedup intact — and land two committed, mutation-
proved regression cases for it.

**## Retrieval**
No tracker issue exists for this unit. The authoritative spec is
`docs/plans/2026-08-26-microworld-memo-mutation-proof.md` in this repo — read
Goal, Context (especially "Chosen design"), Risks R1-R11, and Step 1 in full
before editing. The measurement table in Context tells you which variants were
already tried and which were measured broken; do not re-derive it.

**## Affected files**
- `hooks/scripts/lib/microworld-queue.sh` (source of truth) — `_memo_setup`
  `:58-80`, and `_drain_loop`'s outer `while` at `:141`
- `tests/microworld-rerun.test.sh` — two new lettered cases
- `.claude/hooks/scripts/lib/microworld-queue.sh` (generated)
- `adapters/codex/hooks/scripts/lib/microworld-queue.sh` (generated)
- `adapters/cursor/hooks/scripts/lib/microworld-queue.sh` (generated)
- `.claude/persona-config.json` — `fileHashes` `:215-217` (generated)
- `CHANGELOG.md`

**## Ordered edits**
1. Capture a baseline: run `bash tests/validate.sh` on the unmodified tree and
   save its FAIL lines. AC-1.5 is scored against this, not against zero.
2. Write the two new cases in `tests/microworld-rerun.test.sh` **first**
   (TDD), following the shape and helpers of the existing case `(i)`
   (`:340-383`) and case `(j)` (`:384-418`). Confirm both are RED against the
   unmodified lib. Case A = AC-1.3; case B = AC-1.9. Case B must poll for
   `<dot>/microworld-queue/.runner.lock` before its second enqueue (R11) and
   must assert both the audit-line count and the marker count.
3. Edit `_memo_setup` in `hooks/scripts/lib/microworld-queue.sh` per the
   Context pseudo-code: key = sanitized `$1` + a `cksum` digest over `"$@"`
   and `env | sort`; add the `<key>.$$.seen` per-shell guard; never overwrite
   an existing `.rc`. Use `cksum`, not `md5sum`/`sha256sum`; use `env | sort`,
   never `env -0`.
4. Add the two-line flush at the top of `_drain_loop`'s outer `while` body,
   before the `*.pending` glob, using the `"${memo_dir:?}"` guard form.
5. Update the `_memo_setup` header comment (`:46-57`) so it still describes
   what the function does — it currently says nothing about the key, and the
   key is now the interesting part.
6. Re-render the mirrors and hashes: `node bin/cli.js --update --force-render`.
   Do not hand-copy or hand-edit any of the four generated artifacts.
7. Add one `CHANGELOG.md` entry. Do **not** bump `.claude-plugin/plugin.json`
   (P3 not triggered — see Constitution check).
8. Run every acceptance criterion, including both mutation proofs, and record
   the actual output in your report.

**## Do NOT touch**
- Anything under `microworlds/` — in particular `microworlds/rpg-canon-2/` and
  `microworlds/hdg-anchor-1/`. They are correct as written; weakening either
  deletes real anti-vacuity coverage (R6).
- `hooks/scripts/lib/stop-gate-core.sh` or any of its mirrors — spec2-unitB is
  in flight on that file (R9).
- The `protectedPaths` entry at `.claude/persona-config.json:112`. Protection
  for this fix is already granted and the orchestrator lifts it at dispatch;
  do not edit the entry and do not re-request approval (R2).
- The queue's lock, coalescing, pending-file and audit-log mechanisms — out of
  scope, reviewer-PASSed as spec2-unitA.
- Case `(i)`'s assertions in `tests/microworld-rerun.test.sh`. You may move it
  in the file if ordering demands; you may not change what it asserts.
- Any generated mirror or `fileHashes` value by hand (P2, R4).

**## Acceptance criteria**
AC-1.1 through AC-1.10 as written in Step 1 of the spec. All ten are required.
AC-1.1 is reviewer-run and takes ~2-3 minutes; it is **not** to be added to
`tests/validate.sh`. AC-1.4 and AC-1.10 are mutation proofs and must be
reported with the actual output of both directions — a claim that they pass,
without the output, does not satisfy them.

**## Pre-resolved context** (established by measurement; do not re-derive)
- Both affected bundles mutate a `mktemp -d` copy, not the working tree, and
  differentiate the mutant run by a `GATE_UNDER_TEST=` env prefix
  (`rpg-canon-2/run.sh:29`, `hdg-anchor-1/run.sh:31`). A tree-content hash
  therefore does **not** fix this; do not implement one.
- An env-assignment prefix on a call to the exported `bash` *function* is
  visible inside the function and is exported to the `command bash` child.
- The exported environment is byte-identical across bundle `run.sh`
  invocations under `_run_bundle`'s shape, so an unfiltered `env | sort`
  digest does not regress dedup and no exclusion list is needed.
- Digest cost ~1 ms/call. `cksum` is already used by
  `hooks/scripts/dispatch-hygiene.sh` (`:29`, `:132`, `:134`, `:136`, `:145`),
  so it is not a new dependency. `env -0` is unavailable on BSD/macOS.
- Storing the owner PID in the `.rc` file was measured **broken** (a bundle
  taking a cross-owner hit never becomes the owner). The working form is
  "one cache hit per shell per key" via a `<key>.$$.seen` marker.
- `$$` is stable across subshells and pipelines within one `run.sh`.
- This is a seven-artifact change (see R3); the source edit and re-render
  cannot be split.
- No committed test references `_memo_setup` or `MICROWORLD_MEMO` by name;
  there is no direct unit-test seam and this unit does not add one.
- `tests/protected-paths-gate.test.sh` Test 6 is a known pre-existing FAIL
  attributed to spec2-unitE — baseline, not something you caused or fix.

**## Escalation**
Stop and report rather than improvising if: the `protectedPaths` block on
`hooks/scripts/lib/microworld-queue.sh` is still active at dispatch time; a
mutation proof (AC-1.4 or AC-1.10) cannot be made to go red, which would mean
the corresponding case is vacuous and the spec needs revising, not the code;
AC-1.9's two-pass sequencing cannot be made deterministic (R11); or
`node bin/cli.js --update --force-render` touches files beyond AC-1.8's list.
Do not weaken a criterion to make it pass, and do not modify any bundle. Per
the shared protocol, a second FAIL on this unit escalates to the human rather
than a third fix attempt.

---

### Unit: memo-key-2

**## Objective**
Record **mutation proof** and **suite-level memoization** in `CONTEXT.md` as
defined terms, re-point the existing **drain loop** and **coalescing** entries
at the new term, and correct the diagnosis memo's standing guidance, which
Unit `memo-key-1` renders false.

**## Retrieval**
No tracker issue exists. The authoritative spec is
`docs/plans/2026-08-26-microworld-memo-mutation-proof.md` — read Step 2 and
the Context section. Dispatch only **after** `memo-key-1` reaches reviewer
PASS; AC-2.4 needs that unit's commit sha.

**## Affected files**
- `CONTEXT.md`
- `.claude/agent-memory/spec-master/project_microworld_memo_defeats_mutation_proofs.md`

**## Ordered edits**
1. Read `CONTEXT.md:451-483` (the **drain loop** `:451`, **coalescing** `:464`
   and **pending file** `:473` entries) to match their house style — the
   `(unit, date) — …` opener and `[[wiki-link]]` cross-references. Note the
   canonical bundle entry is `**Microworld bundle**` at `:976`.
2. Add a `**mutation proof**:` entry (AC-2.1).
3. Add a `**suite-level memoization**:` entry (AC-2.2), describing the
   post-fix key composition, not the pre-fix one.
4. Rewrite the inline wrapper descriptions inside **drain loop** (`:458-459`)
   and **coalescing** (`:470-471`) to cross-reference
   `[[suite-level memoization]]` instead (AC-2.3).
5. Amend the diagnosis memo per AC-2.4, naming `memo-key-1`'s commit sha.
6. Run `bash tests/validate.sh` (AC-2.5).

**## Do NOT touch**
- Any file under `hooks/`, `tests/`, `microworlds/`, `adapters/`, or
  `.claude/persona-config.json`. This unit is documentation only.
- The existing definitions of **microworld bundles**, **watch-map**, **Tier A
  / Tier B**, **Microworld audit log** or **pending file** — cross-reference
  them, do not restate or redefine them.
- The `## Convergence follow-ups` mechanism or any ADR — no ADR is warranted
  here; this is a defect fix inside an already-ratified design.

**## Acceptance criteria**
AC-2.1 through AC-2.5 as written in Step 2 of the spec.

**## Pre-resolved context**
- Drift lenses 1 (a glossary term used with a different meaning) and 2 (a new
  synonym for a defined term) were run against this plan and turned up
  nothing. Only lens 3 fired: **mutation proof** and **suite-level
  memoization** are load-bearing terms with no entry.
- `CONTEXT.md:458-459` and `:470-471` currently *mention* "suite-level dedup"
  and "memoizing bash wrapper" inline without defining either. That inline
  description is what AC-2.3 replaces.
- No ADR renumbering is involved. ADR numbers are re-derived at execution time
  in this repo and there is a known numbering hole that must not be backfilled
  — irrelevant here only because no ADR is being written.

**## Escalation**
Stop and report if `memo-key-1` has not reached reviewer PASS (AC-2.4 cannot
be satisfied without its commit sha), or if the settled key composition in the
spec's Context section disagrees with what actually shipped in
`hooks/scripts/lib/microworld-queue.sh` — in that case the spec is stale and
routes back to `spec-master`, rather than being papered over in the glossary.

---

## Scribe update hint

Step 2 *is* the scribe work; dispatch it as unit `memo-key-2` after
`memo-key-1` reaches PASS. If `memo-key-1`'s PASS marker carries non-blocking
notes, harvest them into `memo-key-2` rather than letting them lapse — a
non-blocking note naming this exact defect is how it survived spec2-unitA
(R1).
