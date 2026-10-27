# macOS compatibility: finish `validate.sh` and harden for the future

Status: PARTLY IMPLEMENTED (as of 2026-10-27). U0 (patch set) is on master (commits `46162924`, `228f6012`, fixes through `be6f6907`, unit `macos-merge`), along with `scripts/portable-convert.py` and `tests/lib/bsd-shims/`. Verified NOT landed: U2 (no macOS job in `.github/workflows/validate.yml`), U3's validate.sh section (no `portable-convert` in `tests/validate.sh`), U6 (no "Shell portability contract" in `CONTRIBUTING.md`). Other units are not verified and not claimed here.
Audience: Sonnet implementation agents. Every unit is self-contained: goal, files, exact steps, acceptance commands.
Evidence: `diagnosis-userland-locale.md`, `diagnosis-drift-yaml-pack.md` (both in this directory, written by Fable diagnosis agents; read the relevant finding before touching its unit).
Patches: `patches/` in this directory (all verified with `git apply --check`; see "Patch set").

## 0. Ground rules (apply to every unit)

1. **Do not commit, push, or `git add`** unless the unit says so. The user commits.
2. **Always test with macOS bash 3.2:** run scripts as `/bin/bash tests/<x>.test.sh`, never bare `bash` (Homebrew bash 5 may shadow it). `/bin/bash --version` must say `3.2.57`.
3. **Shims:** on Darwin put `tests/lib/bsd-shims` first on `PATH` when running a test by hand: `PATH="$PWD/tests/lib/bsd-shims:$PATH" /bin/bash tests/x.test.sh`. `tests/validate.sh` already does this itself. Never add a `timeout` shim (hooks must work without one).
4. **bash 3.2 + BSD rules** (the contract; `scripts/portable-convert.py` encodes it): no `mapfile`/`readarray`, `declare -A`, `${v,,}`/`${v^^}`, `${v@Q}`, `[[ -v ]]`; no `$'\047'` or `$'\042'` inside `${v//pat/}`; guard empty arrays under `set -u` as `${a[@]+"${a[@]}"}`; no `case` inside `$( )` or `<( )`; `sed` needs `;` before `}` and `-i ''`; `paste` needs a trailing `-`; no `find -printf`, `grep -P`, `readlink -f`, `/proc`, `date -d` without a `date -r` fallback, `stat -c` without a `stat -f` fallback (GNU first: GNU `stat -f` is filesystem-status and can exit 0 with junk).
5. **After editing any file under `hooks/scripts/`** the mirrors (`.claude/hooks/scripts`, `adapters/codex/hooks/scripts`, `adapters/cursor/hooks/scripts`) and `.claude/persona-config.json` `fileHashes` are stale. Regenerate with:
   `node bin/cli.js --update --force-render` (add `--accept=<path>` if it says a mirror "is pending"), then **`git checkout .claude/settings.json`** (the render appends hook registrations we do not want) and check `git diff --stat .claude/persona-config.json` shows only `fileHashes` lines. Never hand-edit a mirror.
6. **Never weaken a check** to make it pass: no deleting assertions, no `|| true` on a failing check, no loosening expected strings. If you believe a check is wrong, stop and report with proof.
7. After any change run `python3 -I scripts/portable-convert.py --check` (must print `0 fix(es) pending`) and `/bin/bash tests/portable-convert.test.sh`.
8. Report format for each unit: files changed, commands run with their exit codes, anything skipped and why.

## 1. What is wrong today (diagnosis summary)

`bash tests/validate.sh` on macOS (bash 3.2, BSD userland) before any patch: it aborts with exit 141 and ~30 FAIL lines. Root causes, all verified by Fable diagnosis agents:

| id | symptom | root cause | fixed by |
|----|---------|-----------|----------|
| A1 | suite dies, exit 141, truncated counts (OK=1837) | BSD awk in `tests/lib/validate-quiet.sh` aborts (`towc: multibyte conversion failure`) on a lone `0xC2` byte printed by test PG20; `tee`/inner bash then take SIGPIPE | `LC_ALL=C` on that one awk |
| A2 | `sed: unused label 'a;N;$!ba…'` | GNU-only one-liner in `tests/reviewer-route-gate-caller.test.sh:166`; BSD sed silently leaves the file unjoined | awk join |
| A3 | `tests/microworld/microworld-rerun.test.sh` 17 FAIL | macOS has no `timeout`; `_portable_timeout` returned 125 so **every** microworld bundle logged `result=fail` (a real product defect, not test noise) | pure bash-3.2 watchdog fallback in `hooks/scripts/lib/portable-tools.sh` + 3 mirrors |
| A4 | shim-dependent sections fail under `tests/validate-lanes.sh` | lane preamble lacks the Darwin `PATH` shims | preamble adds them |
| A7 | `reviewed-dir-leak-guard` passed **vacuously** | `find -printf` prints nothing on BSD, so the leak check compared empty to empty | portable prefix strip |
| A8/B6 | `rollout-preflight` tests fail | `scripts/rollout-preflight.sh` (scheduled for deletion) needs bash >= 4 and we made it say so | SKIP-by-name when no bash >= 4 (see U1: two overlapping guards) |
| B1 | `.claude/hooks/scripts diverged from hooks/scripts` | `human-decision-gate.sh` gained `_glob_names()` after the last render; the renderer refuses to overwrite a mirror whose recorded hash was reverted | `--update --force-render --accept=…` |
| B2 | `fileHashes … 20 mismatch`, `filehashes-currency` fail | 14 from uncommitted hook edits, 6 from commit `e960c9be` (sources edited, never re-rendered) | regenerate hashes (step order matters, U0) |
| B3a | `npm pack tarball composition (… KeyError: 0)` | not PyYAML: npm 12 (node 26) emits an object keyed by package name, npm <= 11 a list | `validate.sh` accepts both shapes |
| B3b/c | `No module named 'yaml'` (agents/*.md, templates, cli-backfill) | PyYAML not installed on macOS | Ruby/Psych fallback (stock macOS), else SKIP by name; PyYAML path unchanged |
| A5 | "case 26 sweep: 381 probes, gate ALLOWED 248" | by design: documented measured value, floor assertion passes | no change |
| A6 | `cut`/`sed` "illegal byte sequence" | not a suite defect: only appears when post-processing the log with BSD tools under UTF-8 | no change |

Also fixed by hand earlier in this effort (already in the working tree, uncommitted): bash-3.2 crashes in the gates (`'`/`"` inside `${v//…/}`), `${1,,}` in `marker-commit-check.sh`, empty-array expansions, BSD `sed` brace in `bin/ladder-tier.sh`, and the `[[:upper:]]`-under-`nocasematch` fail-OPEN in `human-decision-gate.sh` (`_glob_names`).

## 2. Patch set

All paths are relative to `docs/plans/2026-10-23-macos-compat/patches/`. Each was created against a snapshot of the working tree as of 2026-10-23 (uncommitted portability edits included) and `git apply --check` passes against it.

| file | contents | use |
|------|----------|-----|
| `00-combined.patch` | 10 + 20 together **plus** regenerated mirrors and `persona-config.json` `fileHashes`. 13 files, ~300 insertions. | the one to apply (U0) |
| `10-userland-locale-timeout.patch` | A1, A2, A3, A4, A7, A8 (9 files: `tests/lib/validate-quiet.sh`, `tests/reviewer-route-gate-caller.test.sh`, `tests/validate-lanes.sh`, `tests/reviewed-dir-leak-guard.test.sh`, `tests/rollout-preflight.test.sh`, `hooks/scripts/lib/portable-tools.sh` + 3 mirrors) | reference / partial apply |
| `20-drift-yaml-pack.patch` | B1, B3, B6 (`.claude/hooks/scripts/human-decision-gate.sh`, `tests/validate.sh`, `tests/cli-backfill.test.js`); **no** `fileHashes` | reference / partial apply |

Do not apply 10 and 20 on top of 00. If you need only one, apply it, then redo ground-rule 5 (render + revert settings) because `fileHashes` depend on the mirrors.

## 3. Work units

Order: **U0 first. U1 next. Then U2, U3, U4 in parallel (disjoint files). U5-U10 after U0, any order unless a `Depends on` says otherwise.**

---

### U0 - Apply the verified patches (size S)

Goal: the working tree passes `tests/validate.sh` apart from the failures listed under "Known remaining" below.

Steps:
1. `cd ~/AntiSlop && git apply --check docs/plans/2026-10-23-macos-compat/patches/00-combined.patch && git apply docs/plans/2026-10-23-macos-compat/patches/00-combined.patch`
2. Re-render and confirm hashes settle (idempotent): `node bin/cli.js --update --force-render 2>&1 | tail -5; git checkout .claude/settings.json`
3. `git diff --stat .claude/persona-config.json` must show `fileHashes` lines only (`git diff .claude/persona-config.json | grep '^[+-]' | grep -v fileHashes` should list nothing except hash lines).
4. Run: `/bin/bash tests/validate.sh > /tmp/validate.log 2>&1; echo rc=$?` (about 25 min; run it in the background and poll; the nested `reviewed-dir-leak-guard` section is slow by design).

Acceptance:
- `python3 -I scripts/portable-convert.py --check` prints `0 fix(es) pending`.
- `/bin/bash tests/microworld/microworld-rerun.test.sh` exits 0 (27 OK).
- `/bin/bash tests/filehashes-currency.test.js` equivalent: `node tests/filehashes-currency.test.js` exits 0.
- In the `validate.sh` run, no `FAIL` line other than "Known remaining".

Known remaining (acceptable at the end of U0, each is an environment limit, not a defect):
- eval-case validation needs PyYAML: SKIP by name, not FAIL.
- `claude plugin tag` advisory WARN.
- If the machine has no bash >= 4: `rollout-preflight` SKIP by name.

---

### U1 - Resolve the overlapping/judgement hunks (size S, depends on U0)

Two verified decisions need a human-grade look; do both and report.

1. **Double SKIP guard for `rollout-preflight`.** Patch 10 (A8) makes `tests/rollout-preflight.test.sh` find a bash >= 4 or emit a precondition SKIP; patch 20 (B6) makes `tests/validate.sh` SKIP that section by name when no bash >= 4 exists. Keep ONE. Recommended: keep the one in `tests/rollout-preflight.test.sh` (the test owns its precondition) and delete the `validate.sh` guard, unless that makes `validate.sh` print a FAIL on bash 3.2. Verify: `/bin/bash tests/rollout-preflight.test.sh; echo $?` is 0 with a line starting `SKIP`.
2. **Ruby/Psych YAML fallback is exactly as strict as PyYAML.** Read the diff of `tests/validate.sh` and `tests/cli-backfill.test.js` in `patches/20-…`. Confirm with a mutant: take one `agents/*.md`, introduce the malformed frontmatter shape the check exists to reject (issue #276: see the comment next to the check), and show the check FAILS on the Ruby path. Also confirm that when `python3 -c 'import yaml'` succeeds the PyYAML branch runs unchanged. If the fallback is weaker in any case, tighten it; do not accept it.

Acceptance: both findings written up (3 lines each) in your report; `/bin/bash tests/validate.sh` sections `agent frontmatter` and `rollout-preflight` produce OK or SKIP-by-name, never FAIL.

---

### U2 - macOS CI job with bash 3.2 forced (size S)

Goal: every bug class in section 1 is caught by CI, not by a user.

Facts: `.github/workflows/validate.yml` today is one job, `ubuntu-latest`, apt jq, `bash tests/validate.sh --verbose`. GitHub's macOS images put Homebrew bash 5 first on `PATH`, so a naive job would test bash 5 and miss every 3.2 bug. A Linux "bash 3.2" container adds nothing a macOS job does not (wrong userland).

Change: edit `.github/workflows/validate.yml` to this matrix (keep the existing step names for the ubuntu leg):

```yaml
jobs:
  validate:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Install jq (Linux)
        if: runner.os == 'Linux'
        run: sudo apt-get update && sudo apt-get install -y jq python3-yaml
      - name: Force macOS system bash 3.2 first on PATH
        if: runner.os == 'macOS'
        run: |
          mkdir -p "$RUNNER_TEMP/bin3"
          ln -sf /bin/bash "$RUNNER_TEMP/bin3/bash"
          echo "$RUNNER_TEMP/bin3" >> "$GITHUB_PATH"
      - name: Assert bash 3.2 on macOS
        if: runner.os == 'macOS'
        run: |
          bash --version | head -1
          bash --version | head -1 | grep -q 'version 3\.2' || { echo "bash is not 3.2"; exit 1; }
      - name: Run validate.sh
        run: bash tests/validate.sh --verbose
```

macOS runners already have `jq`, `ruby`, `python3`. Do not install PyYAML on macOS (we want the Ruby fallback path exercised there).

Acceptance (local, since CI cannot run here): `ruby -ryaml -e 'YAML.load_file(".github/workflows/validate.yml")'` exits 0; `git diff --stat` shows only that file. State in your report that the macOS leg is unproven until it runs on GitHub.

---

### U3 - Portability section in `tests/validate.sh` + pre-commit (size S, depends on U0)

Goal: a new GNU-ism cannot land.

Steps:
1. In `tests/validate.sh`, add a new section (use the file's existing `echo "== name =="` header convention and `pass`/`bad` helpers; copy the nearest section's style) named `== portability (bash 3.2 / BSD contract) ==` that:
   - runs `python3 -I scripts/portable-convert.py --check --quiet-manual --no-syntax`; FAIL if it exits non-zero (pending fixes). Manual findings stay advisory: run it once more without `--quiet-manual` and print the count as a `WARN`/note line, not a FAIL, until U10 triages them.
   - runs `/bin/bash -n` over every tracked `*.sh` (use `git ls-files '*.sh'`, excluding `docs/` and `prototype/`): FAIL naming each file that does not parse. The three existing `bash -n` loops in this file (`grep -n "bash -n" tests/validate.sh`, currently lines ~54, 306, 347) should call `/bin/bash -n` only when `/bin/bash` exists and reports 3.x, else `bash -n`.
   - runs `bash tests/portable-convert.test.sh` as a registered test (it is currently not registered anywhere).
2. Add `.githooks/pre-commit`? **No**: do not install hooks. Instead document, in the section's comment, the two-command fast check: `python3 -I scripts/portable-convert.py --check && git ls-files '*.sh' | xargs -n1 /bin/bash -n`.

Acceptance:
- `/bin/bash tests/validate.sh` shows the new section with OK lines and no FAIL.
- Mutant proof (required, on a scratch copy only, never the real tree): copy the repo to `$TMPDIR`, append the line `x=( "${arr[@]}" )` to `hooks/scripts/dispatch-hygiene.sh` in the copy, run the new section there, show it FAILS naming that file, then delete the copy.

---

### U4 - Gates fail CLOSED on unexpected errors (size M, highest value)

Goal: a runtime bash/BSD error inside a PreToolUse gate yields exit 2 (deny), never exit 1 (non-blocking = allow). Today the gates use `set -euo pipefail`, so an unexpected command failure exits with that command's status, usually 1, which Claude Code treats as a non-blocking hook error: the tool call proceeds. This is exactly how the `[[:upper:]]` bug fell open.

Gates (PreToolUse entries in `hooks/hooks.json`): `protected-paths.sh`, `reviewed-path-gate.sh`, `human-decision-gate.sh`, `harness-integrity-gate.sh`, `reviewer-route-gate.sh`, `dispatch-hygiene.sh`. (Read `hooks/hooks.json` to confirm; if a gate is listed there that is not in this list, include it. Do NOT touch PostToolUse/Stop/SessionStart scripts; they have different contracts.)

Design (do it exactly; do not invent):
1. In `hooks/scripts/lib/harness-arm.sh` (already sourced by the gates; it has `set -euo pipefail`) add one function:

   ```bash
   # gate_fail_closed <gate-name>: turn an unexpected non-zero exit of a PreToolUse gate into a DENY (exit 2).
   # Exit 1 is a non-blocking hook error in Claude Code, i.e. the tool call would be allowed.
   gate_fail_closed() {
     _gate_name="${1:-gate}"
     trap '_rc=$?; [ "$_rc" -eq 0 ] || [ "$_rc" -eq 2 ] || { echo "BLOCKED: ${_gate_name} failed unexpectedly (rc=${_rc}); denying fail-closed" >&2; exit 2; }' EXIT
   }
   ```
   (An `EXIT` trap, not `ERR`: `ERR` is not inherited into functions/subshells without `set -E` and does not fire for failures inside `if`/`&&` lists, so it would both miss errors and be hard to reason about. An `EXIT` trap sees the final status in every case.)
2. In each gate, immediately after its `set -euo pipefail` line and before any other command, add `source "${lib_dir}/harness-arm.sh"` only if it is not already sourced before that point (several gates source it later, after reading stdin; move the `lib_dir=` and `source` up only if no earlier command can fail) and then `gate_fail_closed <script-name>`. Gates must still exit 0 on allow and 2 on deny exactly as before; every intentional `exit 1`? Search each gate for `exit 1`/`return 1` at top level: intentional non-zero exits other than 2 must be reported to the user, not silently converted.
3. Re-render mirrors (ground-rule 5).

Tests (add `tests/gate-fail-closed.test.sh`, register it in `tests/validate.sh`): for each gate, run it with a poisoned environment that forces an internal failure and assert exit 2 and the `BLOCKED:` text. Poison method that works on every gate: put a fake `jq` first on `PATH` that does `exit 7` (all gates parse the payload with `jq`). Also assert the happy path is unchanged: with real `jq` and a benign payload (`{"tool_name":"Bash","tool_input":{"command":"ls"},"cwd":"<tmp project>","session_id":"s"}` and `CLAUDE_PROJECT_DIR=<tmp project>`) exit stays 0 for the Bash-matcher gates.

Acceptance:
- `/bin/bash tests/gate-fail-closed.test.sh` exits 0 (6 gates x {poisoned -> 2, benign -> unchanged}).
- All existing gate suites still pass: `human-decision-gate`, `harness-integrity-gate`, `reviewed-path-gate`, `protected-paths-gate`, `reviewer-route-gate-caller`, `dispatch-hygiene`, `adapter-stop-gate-parity` (run each as `PATH="$PWD/tests/lib/bsd-shims:$PATH" /bin/bash tests/<name>.test.sh`).
- Mirror diff clean (`node bin/cli.js --check` or the `validate.sh` mirror sections).
- Report any gate where the benign/poisoned behaviour surprised you; do not "fix" it by loosening the test.

---

### U5 - Mirror drift can't be silent (size S, depends on U0)

Goal: stale `.claude/` or adapter copies fail CI with a clear message.

Facts: `tests/validate.sh` diffs `.claude/hooks/scripts` against `hooks/scripts` (around line 375) but across adapters it only compares `agent-identity.sh` (around line 360). `bin/cli.js` has `SHARED_HOOK_LIB_FILES`, `CLAUDE_ONLY_HOOK_LIB_FILES`, and `assertHookLibDeclarationComplete()` (about line 674) that throws at load when `hooks/scripts/lib/` has an unclassified file; today a missing classification crashes the installer instead of failing a named check.

Steps:
1. Add a one-line CLI helper to `bin/cli.js`: `--print-shared-lib` prints `SHARED_HOOK_LIB_FILES` one per line and exits 0 (must not require the assertion to pass first; place the flag handling before `assertHookLibDeclarationComplete()` runs, or catch its error and print the error text to stderr with exit 3).
2. In `tests/validate.sh`: replace the single-file adapter compare with a loop over `node bin/cli.js --print-shared-lib`, `cmp -s hooks/scripts/lib/$f adapters/$a/hooks/scripts/lib/$f` for `a in codex cursor`. Add a step that runs `node bin/cli.js --print-shared-lib >/dev/null` and FAILs with its stderr if it exits non-zero ("unclassified lib file"). Never hardcode the file list.
3. Add a `.gitattributes` line marking generated trees `linguist-generated` for `.claude/hooks/**` and `adapters/*/hooks/**` (check `.gitattributes` first; append only if absent).

Acceptance: mutant proof in a scratch copy: (a) `echo '# x' >> adapters/cursor/hooks/scripts/lib/stop-gate-core.sh` -> section FAILs naming that file; (b) `cp hooks/scripts/lib/portable-tools.sh hooks/scripts/lib/zz-new.sh` -> section FAILs with the "not classified" message; both on a copy, delete after.

---

### U6 - Write the contract down (size S)

Add a short "Shell portability contract" section to `CONTRIBUTING.md` (after "Making changes"): states the baseline (bash 3.2 + BSD-safe subset, supported on macOS, Linux, WSL), lists ground-rule 4 verbatim, tells contributors to run `python3 -I scripts/portable-convert.py` (dry run), `--write` to apply, and that `scripts/portable-convert.py`'s module docstring is the normative rule list. State the policy decision: we **do not** require bash >= 4 or re-exec (a PreToolUse hook that cannot start fails open). Mention `# portable-ok` as the line-level escape hatch and that it needs a reason comment.

Acceptance: `grep -c 'portable-convert' CONTRIBUTING.md` >= 2; no other file changed.

---

### U7 - Tests that don't need shims (size M, depends on U0)

Goal: the shims (`tests/lib/bsd-shims`) become a convenience, not a crutch, and Linux/WSL stay untouched.

Steps:
1. List the tests that rely on shim behaviour: `python3 -I scripts/portable-convert.py --quiet-manual` does not show them; instead run `grep -lE 'sed -i|touch -d|date -d|wc -l' tests/*.sh tests/microworld/*.sh`. Fix each use to a portable form: `sed -i` -> write to a temp file and `mv`, or `perl -pi -e`; `touch -d '<ISO>'` -> a helper `set_mtime <file> <epoch-or-ISO>` in a new `tests/lib/portable-test-utils.sh` (GNU `touch -d`, else `touch -t` with `TZ=UTC` when the string ends in `Z`: copy the logic from `tests/lib/bsd-shims/touch`); `$(wc -l <f)` comparisons -> pipe through `tr -d ' '`.
2. Change the Darwin PATH line in `tests/validate.sh` (line ~10) to opt-in: only when `ANTISLOP_BSD_SHIMS=1`. Update `tests/lib/bsd-shims/README` and the line in `tests/validate-lanes.sh` (A4 added the same PATH there) the same way.
3. Keep `tests/lib/bsd-shims/` in the repo as the opt-in fallback.

Acceptance: `PATH` without shims, on macOS: `/bin/bash tests/validate.sh` has the same OK/FAIL/SKIP counts as with `ANTISLOP_BSD_SHIMS=1` (compare the final `Counts:` line). If the counts differ, list which tests still need shims.

---

### U8 - Mutation tests stop pinning whole source lines (size M)

Problem: several tests mutate a throwaway copy of a hook by exact-string match (for example `tests/stop-gate-blocked.test.sh` `scope_line=`, `tests/stop-gate-deferred-microworld.test.sh`, `tests/stop-gate-microworld-skip.test.sh`, `tests/dispatch-hygiene.test.sh`, `tests/adapter-stop-gate-parity.test.sh` `fixed_call`/`old_call`). Any harmless portability edit to the pinned line breaks them (it did, twice).

Steps:
1. Add a helper `tests/lib/mutate.sh` exposing `mutate <file> <id> <sed-replacement>`: it finds exactly one line containing the marker `# MUT:<id>` in `<file>`, applies the substitution to that line only, and fails (exit 1, message) if the marker is absent or appears more than once.
2. Put a trailing `# MUT:<id>` comment on each mutated source line in `hooks/scripts/**` (ids like `stop-gate-scope`, `dispatch-h4-fire`), switch the tests to `mutate`, and keep each test's "mutation control did not discriminate" assertion as is.
3. Add `tests/mut-anchors.test.sh`: for every `mutate <file> <id>` call in `tests/`, assert the id occurs exactly once in the source file; register it in `validate.sh`.
4. Re-render mirrors (ground-rule 5).

Acceptance: the five tests above still pass; editing the pinned lines' code (not the marker) no longer breaks them (demonstrate by reformatting one pinned line in a scratch copy and rerunning that test).

---

### U9 - Cross-interpreter differential sweep for the fail-open functions (size M, depends on U4)

Goal: semantic (non-crash) differences between bash 3.2 and bash >= 4 in the gates are caught.

Targets (functions whose wrong answer = a gate allowing something): in `hooks/scripts/human-decision-gate.sh`: `glob_names_tokens`, `_glob_names`, `glob_match_path`; in `hooks/scripts/lib/benign-command.sh`: `command_skeleton`, `command_is_provably_benign`, `normalize_path`; in `hooks/scripts/reviewed-path-gate.sh`: `mentions_marker_dir`, `mask_comments_only`; in `hooks/scripts/harness-integrity-gate.sh`: `set_a_mentioned`, `is_benign_jq_read`; in `hooks/scripts/lib/stop-gate-core.sh`: `review_join_state`.

Steps: generalise `tests/hdg-differential-sweep.sh` (it already diffs old-vs-new) into `tests/lib/interp-diff.sh <corpus-file> <bashA> <bashB>` that runs each probe command through the whole gate under both interpreters (payload via stdin as in the existing sweep) and reports any pair whose exit code differs. Corpus: the existing probe lists in the gate test suites plus 30 hand-written adversarial globs (`[[:upper:]]ECISION`, `{D,d}ECISION`, `?ECISION`, quoted/unquoted variants). When only one interpreter exists on the machine, the test prints `SKIP: need a second bash` and exits 0. The real 3.2-vs-5 comparison needs both on one machine (a Mac with Homebrew bash installed); CI cannot run it (the macOS leg has only 3.2 forced, the ubuntu leg only bash 5), so say so in the test's header comment and run it locally.

Acceptance: sweep prints `0 differing verdicts` on this machine (macOS /bin/bash 3.2 vs any bash >= 4 if present, else SKIP).

---

### U10 - Triage manual findings, then promote to FAIL (size L, last)

Run `python3 -I scripts/portable-convert.py --no-syntax` (without `--quiet-manual`); it prints `manual:` findings (about 100 repo-wide). For each: fix it, or justify it with `# portable-ok: <reason>` on the line (reason mandatory), or confirm it is in a script that is intentionally non-portable (probe/prototype scripts needing `timeout`/`claude`) and add its path to a new `MANUAL_ALLOW` tuple in the tool with a comment. Then change U3's section so manual findings are a FAIL (`--strict`).

Acceptance: `python3 -I scripts/portable-convert.py --check --strict` exits 0; `/bin/bash tests/portable-convert.test.sh` passes (add a test case for `MANUAL_ALLOW` and for `# portable-ok:` requiring a reason); the full `validate.sh` is green apart from "Known remaining".

## 4. Dependency graph

```
U0 ──┬─ U1
     ├─ U3 ── U10
     ├─ U5
     ├─ U7
     └─ U4 ── U9
U2, U6, U8 : independent of U0 (U8 and U4 both re-render mirrors: do them sequentially, not in parallel)
```

Parallel-safe sets: {U2, U3, U6} then {U4, U5}; run U8 after U4 (same hook files). U7 touches many tests: run it alone.

## 5. Verification status of this spec

- Patches 00/10/20: `git apply --check` clean against the 2026-10-23 working tree; 00 applied and a full `/bin/bash tests/validate.sh` run was started on a scratch copy (result recorded below when it finishes).
- Units U2-U10 are designs from a Fable architecture review and have NOT been implemented; their acceptance commands are the proof obligation.

## 6. Result of the full run on `00-combined.patch`

Run: `/bin/bash tests/validate.sh` on a scratch copy of the 2026-10-23 working tree with `00-combined.patch` applied, macOS, bash 3.2.57, no PyYAML, no bash >= 4, no `timeout`.

First run (scratch copy whose git history had been replaced by one commit): `Counts: OK=3258 FAIL=9 WARN=1 SKIP=5`, exit 1. Before any patch the same suite aborted with exit 141 at about OK=1837 and 31 FAIL.

All 9 FAILs were artefacts of that scratch copy, not defects: they need the real git history (commit `d807630` for the `[C1.11]` baseline, `[C4.1c]` "modified by this unit" diffs, the `(ptr-u8)` commit subject in `ladder-tier`, `skr-archive-verify`) and `stop-gate-microworld-skip` is a latency budget that was measured while the suite ran as a background job. Re-run on a copy that keeps the real `.git` with the patch applied:

| test | result |
|------|--------|
| `tests/harness-integrity-gate.test.sh` (covers C1.11, C4.1c) | rc 0, 0 FAIL |
| `tests/ladder-tier.test.sh` | rc 0, 0 FAIL |
| `tests/stop-gate-microworld-skip.test.sh` | rc 0, 0 FAIL |
| `docs/plans/skr-criteria/skr-archive-verify.sh` | rc 0 |

Not re-run end to end after that: the 5 SKIPs (locale, AC-C6 unreachable commit, `rollout-preflight` needs bash >= 4, eval-cases needs PyYAML, SIGINT test needs a foreground shell) are environment limits and are the expected "Known remaining" set for U0. A complete single run of `validate.sh` with the real `.git` and the patch applied has NOT been done; U0's last step does it, and its result is the real acceptance gate.
