# fableB: validate.sh group B (mirror drift, fileHashes, packaging, YAML, CI)

Working copy: `/private/tmp/claude-501/-Users-sebas/8f0fc331-889a-4cf0-9be4-9b1cff60da52/scratchpad/wsB`
Baseline commit there: `c0eec3c9 base` (= /Users/sebas/AntiSlop working tree incl. all uncommitted portability edits, committed on top of `e960c9be`).
Patch: `/private/tmp/claude-501/-Users-sebas/8f0fc331-889a-4cf0-9be4-9b1cff60da52/scratchpad/fableB.patch` (4 files; `git apply --check` clean against the baseline).
Variant without `.claude/persona-config.json`: `.../scratchpad/fableB-without-persona-config.patch` (see B2 for why the main patch includes it).

Environment: macOS, /bin/bash 3.2.57, node v26.0.0 / npm 12.0.1, Homebrew python 3.14.6 (no PyYAML; /usr/bin/python3 also lacks it), /usr/bin/ruby 2.6 with Psych 3.1.0, no yq, no node_modules / js-yaml.

Section runner used throughout: `/private/tmp/claude-501/-Users-sebas/8f0fc331-889a-4cf0-9be4-9b1cff60da52/scratchpad/runsec.sh <repo> "<header substring>"...` (extracts the `echo "== ... =="` section bodies out of tests/validate.sh, runs them under /bin/bash with `tests/lib/bsd-shims` on PATH, same preamble as validate.sh).

---

## B1 - `.claude/hooks/scripts` mirror diverged from `hooks/scripts`

**Symptom (exact):**
```
== this repo's hook-script mirror is at parity with hooks/scripts/ ==
Files hooks/scripts/human-decision-gate.sh and .claude/hooks/scripts/human-decision-gate.sh differ
FAIL .claude/hooks/scripts diverged from hooks/scripts (run `node bin/cli.js --update`)
```
**Where:** `tests/validate.sh:375` (`diff -rq hooks/scripts .claude/hooks/scripts`). The only differing file is `.claude/hooks/scripts/human-decision-gate.sh`; the diff is exactly the `_glob_names()` helper block at `hooks/scripts/human-decision-gate.sh:585-599` plus its two call sites (`:606`, `:609`), which the mirror lacks.

**Classification:** stale copy, not a render transform and not an unclassified file. Hook scripts are `kind: 'raw'` specs (no ADAPT stamp, byte copy) and every `hooks/scripts/lib/*.sh` is classified (`SHARED_HOOK_LIB_FILES` already lists `portable-tools.sh`; `assertHookLibDeclarationComplete()` at `bin/cli.js:674` would make cli.js unloadable otherwise). The source was edited again after the last `--update --force-render`.

**Why a plain re-render does not fix it:** `node bin/cli.js --update --force-render` reports
```
1 file(s) have diverged from a fresh copy:
--- .claude/hooks/scripts/human-decision-gate.sh ---
...
1 file(s) pending. Re-run with --accept=<path,path> ...
```
because the mirror's recorded `fileHashes` baseline (`c0e30e25...`, the pre-portability content) does not match the mirror's current on-disk content (`d427af97...`, the earlier re-render that was kept while persona-config.json was reverted). cli.js reads that as "local edit in the mirror + upstream change" and refuses to overwrite without `--accept`. Any time you re-render and then `git checkout .claude/persona-config.json`, you recreate this state for every file whose source changes afterwards.

**Fix (in patch):** regenerated the mirror with
```
node bin/cli.js --update --force-render --accept=.claude/hooks/scripts/human-decision-gate.sh
git checkout .claude/settings.json
```
Resulting diff: `.claude/hooks/scripts/human-decision-gate.sh` (+19/-2, byte-identical to the source) and the `fileHashes` block of `.claude/persona-config.json` (B2). The check itself is untouched.

**Verification:**
- before: `diff -rq hooks/scripts .claude/hooks/scripts` -> `Files ... differ`, rc=1
- after: same command -> silent, rc=0; `runsec.sh wsB "hook-script mirror is at parity"` -> `OK .claude/hooks/scripts is byte-identical to hooks/scripts`
- idempotence: a second `node bin/cli.js --update --force-render` reports every spec `already current` and changes nothing except `.claude/settings.json` (reverted; see B5).

**Same pattern elsewhere:** adapter shared-lib copies checked with `cmp` for all 12 `SHARED_HOOK_LIB_FILES` x {codex,cursor}: all byte-identical to `hooks/scripts/lib/`. `.claude/skills/*` parity section passes in the full run.

---

## B2 - `fileHashes` baselines stale (20 mismatches) / `tests/filehashes-currency.test.js`

**Symptom (exact):**
```
FAIL every fileHashes entry matches its file's stamp-stripped content hash: 20 mismatch(es), 0 missing file(s). Run `node bin/cli.js --update --force-render` and commit the resulting .claude/persona-config.json — never hand-edit fileHashes (constitution §2).
66 fileHashes entries examined.
FAIL tests/filehashes-currency.test.js
```
**Where:** `tests/validate.sh:398` -> `tests/filehashes-currency.test.js:100-118`; hashing is `sha256Hex(stripStamp(content))` from `bin/cli.js:288-297` (`STAMP_LINE_RE` strips the `<!-- antislop v... ADAPT-substituted -->` line; raw hook scripts carry no stamp, so for them it is the plain sha256 of the file).

**How fileHashes are generated:** only by `bin/cli.js` `--update` (render loop at `bin/cli.js:1522-1640`: `newFileHashes[relKey] = sha256Hex(cleanBody)` per spec, then `pruneStaleFileHashes`). There is no separate stamp script. The regeneration is deterministic (pure function of the source files' bytes); the exact command is the one in B1. It was stale because the earlier re-render's `persona-config.json` was reverted with `git checkout`.

**Root cause of each of the 20 mismatches - all portability edits, none for another reason:**

| mirror path (recorded != actual) | source | where the source changed |
|---|---|---|
| .claude/hooks/scripts/{agent-audit, harness-integrity-gate, human-decision-gate, marker-commit-check, marker-verify, reviewed-path-gate, reviewer-tier, version-stamp-check}.sh (8) | hooks/scripts/<same> | uncommitted working-tree edits (`git diff e960c9be --name-status -- hooks/scripts`) |
| {.claude,adapters/codex,adapters/cursor}/hooks/scripts/lib/{reviewer-route-gate-core, stop-gate-core}.sh (6) | hooks/scripts/lib/<same> | uncommitted working-tree edits |
| {.claude,adapters/codex,adapters/cursor}/hooks/scripts/lib/{audit-log, microworld-queue}.sh (6) | hooks/scripts/lib/<same> | commit `e960c9be fix(hooks): macOS/BSD compatibility` edited the sources (`_portable_sha256`, `_portable_timeout`) but did not re-render the mirrors; at e960c9be the 3 mirrors of each differed from the source by 8/10 lines respectively (`git diff e960c9be:hooks/scripts/lib/audit-log.sh e960c9be:.claude/hooks/scripts/lib/audit-log.sh`). The working-tree re-render caught them up. |

8 + 6 + 6 = 20. Every mirror's new content is byte-identical to its source (B1 `diff -rq` for `.claude`; `cmp` loop for the adapters), so no mirror changed for any reason other than tracking its source. The regenerated `persona-config.json` diff is **only** `fileHashes` lines: 20 updated values + 3 new entries for `portable-tools.sh` (`.claude`, codex, cursor; cli.js logs "3 hook script(s) had no recorded fileHashes baseline ... adopts their current on-disk content") -> 69 entries. No other key changes (`git diff .claude/persona-config.json | grep '^[-+]' | grep -v '"\.claude\|"adapters'` prints nothing beyond the file header).

**Fix (in patch):** the regenerated `.claude/persona-config.json` (fileHashes only). Note on the brief's conflict: the brief says both "include the regenerated result in the patch" and "exclude .claude/persona-config.json". The exclusion exists because `--update` also rewrites unrelated content; here the diff is exactly the fileHashes regeneration the test demands, and the test cannot pass without it, so the main patch includes it. `fableB-without-persona-config.patch` is the same patch minus that file if the caller prefers to regenerate with the command above.

**Verification:**
- before: `node tests/filehashes-currency.test.js` -> `20 mismatch(es), 0 missing`, exit 1
- after: `69 fileHashes entries examined. All filehashes-currency tests passed.`, exit 0

**Same pattern elsewhere:** `.claude/settings.json` is also rewritten by `--update` (adds 17 hook registrations) - reverted, not part of parity/fileHashes checks; see B5.

---

## B3a - `npm pack tarball composition` fails with `KeyError: 0` (npm 12 JSON shape, not PyYAML)

**Symptom (exact):**
```
FAIL npm pack tarball composition (Traceback (most recent call last):
  File "<string>", line 3, in <module>
    files = [f['path'] for f in json.load(sys.stdin)[0]['files']]
KeyError: 0)
```
**Where:** `tests/validate.sh:128-138`.

**Root cause:** this one is not a YAML problem. `npm pack --dry-run --json` under npm 12.0.1 (bundled with node 26) prints an **object keyed by package name** (`{"antislop": {"files": [...]}}`), whereas npm <= 11 printed a one-element **list** (`[{"files": [...]}]`). CI (ubuntu-latest, default node 20/22, npm 10) still gets the list.

**Fix (in patch):** accept both shapes, same assertions:
```python
data = json.load(sys.stdin)
pkg = data[0] if isinstance(data, list) else next(iter(data.values()))
files = [f['path'] for f in pkg['files']]
```
**Verification:** `runsec.sh wsB "npm pack:"` -> `OK npm pack tarball excludes dev-scratch dirs, includes shipped dirs`. Both shapes fed to the extracted snippet pass; a mutant payload containing `docs/x` and lacking hooks/templates/skills fails with `excluded-dirs-present=['docs/'] included-dirs-missing=[...]`, rc=1 (assertions intact).

**Same pattern elsewhere:** `grep -rn 'npm pack' tests scripts bin .github` -> only this site.

---

## B3b - `agents/*.md` / `templates/researcher.md.tmpl` frontmatter YAML check: `ModuleNotFoundError: No module named 'yaml'`

**Symptom (exact):** 10 lines `FAIL agents/<x>.md (ModuleNotFoundError: No module named 'yaml')` plus `FAIL templates/researcher.md.tmpl (...)`.

**Where:** `tests/validate.sh:203-223` (`python3 -c "import re, sys, yaml ... yaml.safe_load(...)"`).

**Root cause:** PyYAML is not installed; a missing parser was reported as a frontmatter failure.

**Choice made: ruby/Psych fallback, then SKIP.** Options weighed:
- SKIP only: honest but loses the #276 regression check on every macOS dev machine.
- Hand-written stdlib frontmatter parser: would not be YAML, so strictness could not be "identical".
- node js-yaml / yq: not present (`node_modules` absent, no global js-yaml, no yq).
- `/usr/bin/ruby -ryaml` (Psych, libyaml-based like PyYAML's C loader) is stock on macOS, parses all 10 frontmatters, and rejects the #276 shape with the same libyaml message (`mapping values are not allowed in this context at line 2 column 26`).

Implemented in `tests/validate.sh` (the section now selects the parser once): PyYAML when `python3 -c 'import yaml'` succeeds (the exact original command, unchanged), else `ruby -ryaml -rdate` running `YAML.safe_load(m[1], permitted_classes: [Date, Time, Symbol], aliases: true)` on the same `^---\n(.*?)\n---\n` block, else one `SKIP <file> (no YAML parser: ...)` line per file (counted by the skip summary, never OK).

**Verification:**
- after (this machine, ruby branch): `runsec.sh wsB "agent frontmatter parses"` -> 10 x `OK`, rc=0
- mutation (ruby branch): added `agents/zz-bad.md` with `description: foo ("agent": "orchestrator") bar` -> `FAIL agents/zz-bad.md ((<unknown>): mapping values are not allowed in this context at line 2 column 26)`, rc=1; file removed afterwards.
- python branch wiring (PyYAML unavailable here, so wired with a stub module on `PYTHONPATH`): stub `safe_load` raising -> 10 x `FAIL ... (ValueError: stub-raised)`; stub accepting -> 10 x `OK`.
- SKIP branch: a `ruby` shim that exits 127 placed first on PATH -> 10 x `SKIP ... (no YAML parser: python3 lacks the yaml module and ruby -ryaml is unavailable)`, rc=0.
- `bash tests/validate-quiet.test.sh` still passes (frozen filter regexes untouched; `SKIP` lines are in the keep set).

---

## B3c - other `import yaml` sites (located; two more needed treatment)

`grep -rn 'import yaml\|yaml\.' --include='*.py' --include='*.js' --include='*.sh' --include='*.yml' .` (excluding tmp/):

| site | run by validate.sh? | treatment |
|---|---|---|
| `tests/validate.sh:215` | yes (B3b) | ruby fallback / SKIP |
| `tests/cli-backfill.test.js:399` (python3 yaml inside the Node test, section "bin/cli.js legacy-backfill logic (Node)", `validate.sh:855`) | yes; it FAILed here (`FAIL rendered explorer frontmatter parses as YAML with the launch command: ModuleNotFoundError ... FAIL tests/cli-backfill.test.js`) | same ladder in Node: `yamlFrontmatterCommand()` returns the python3 command (unchanged string) if `import yaml` works, else an equivalent `ruby -ryaml -rdate -rjson` command, else the check prints `SKIP ... (no YAML parser ...)` and is not counted as a pass. Verified: ruby branch -> `All cli-backfill tests passed` (the assertion `JSON.parse(r.stdout) === 'node'` proves a real parse); fake-ruby PATH -> the SKIP line and the other checks still run. |
| `eval/harness/validate-cases.py:13` + `tests/eval-cases.test.sh:111-215` (seven `yaml.safe_load/safe_dump` heredocs), section `validate.sh:1188` | yes; it FAILed here (`FAIL validate-cases.py --registry ... (empty suites)`, `FAIL hand-built valid case unexpectedly rejected`, then dies) | the validator under test itself imports PyYAML, so there is no parser to swap without rewriting the product code; validate.sh now prints `SKIP tests/eval-cases.test.sh (python3 lacks the yaml module that eval/harness/validate-cases.py imports)` when `python3 -c 'import yaml'` fails, else runs the test exactly as before. Verified both branches (SKIP here; `elif` path unchanged). |
| `docs/plans/skr-criteria/skr-core.sh:25` | no (plan-local helper, nothing references it) | untouched |

CI impact: on ubuntu-latest `python3 -c 'import yaml'` succeeds (python3-yaml is on the GitHub Ubuntu image), so every one of these takes the original PyYAML path with identical strictness. validate.yml does not install PyYAML explicitly; see B5.

---

## B4 - CI workflow facts (`.github/workflows/validate.yml`, the only workflow)

- `runs-on: ubuntu-latest`, `actions/checkout@v4` with `fetch-depth: 0`, `sudo apt-get install -y jq`, then `bash tests/validate.sh --verbose`.
- So CI today = GNU/Linux, GNU bash 5.x, GNU coreutils/sed/awk, system python3 with PyYAML available implicitly, `claude` CLI absent (that section SKIPs), npm 10 (list-shape `npm pack --json`). Nothing in CI exercises bash 3.2 or BSD userland; the macOS shims under `tests/lib/bsd-shims` are activated only by the `uname = Darwin` line at `validate.sh:10`.
- Recommendation (not patched, cannot be verified from here): make the PyYAML dependency explicit (`sudo apt-get install -y jq python3-yaml`) so the YAML checks never silently SKIP if the runner image drops the package; optionally add a `macos-latest` job to keep the BSD port honest.

---

## B5 - Observations outside the patch

1. `.claude/settings.json`: `node bin/cli.js --update` adds 17 hook registrations (PreToolUse/Stop/SubagentStop/TaskCompleted/...), i.e. this repo's own settings are intentionally not the full rendered set. Reverted with `git checkout` as instructed; it is not covered by any validate.sh check. Each re-render will keep proposing it.
2. Exit 141 of the user's quiet-mode run: the outer wrapper pipes the inner script through `validate_quiet_filter` (BSD awk) which aborted on an invalid multibyte byte emitted by the reviewed-path-gate sweep (`awk: towc: multibyte conversion failure`); tee then got SIGPIPE, so the inner bash died with 141 and every later section never ran. Root-cause area is BSD awk + UTF-8 locale (`tests/lib/validate-quiet.sh`, fix shape `LC_ALL=C awk`), which is the other agent's lane; flagged here because it is why the user's log stopped at 119 lines. Verbose mode (`ANTISLOP_VALIDATE_VERBOSE=1`) bypasses the filter and completes.
3. Not fixed, out of scope: sed `:a;N;$!ba` BSD error (reviewer-route-gate caller allowlist), awk multibyte in reviewed-path gate, microworld-rerun failures.
4. No CHANGELOG entry added (repo convention is one narrative entry per change) to avoid colliding with the other agent's patch; suggested text: "validate.sh: npm 12 `pack --json` shape; YAML checks fall back to ruby/Psych or SKIP without PyYAML; mirrors and fileHashes regenerated. No version bump."

---

## Full-suite run after the patch

Command: `cd wsB && ANTISLOP_VALIDATE_VERBOSE=1 /bin/bash tests/validate.sh > ../full-run.log 2>&1` (log: `/private/tmp/claude-501/-Users-sebas/8f0fc331-889a-4cf0-9be4-9b1cff60da52/scratchpad/full-run.log`).

Before the B6 guard was added (patch state: B1-B3 only): exit=1, 175 sections, `OK=3268 FAIL=30 WARN=1 SKIP=2` (counted with `LC_ALL=C grep -a`; BSD grep/awk treat the log as binary because the reviewed-path sweep emits an invalid UTF-8 byte). Every FAIL is in two sections, neither in this group:
- `== microworld reactive rerun hook + relocation proof (Bash) ==` - 17 FAILs (other agent's lane).
- `== rollout wave-graph preflight checker (Bash, scaffolding) ==` - 13 FAILs, diagnosed and guarded below as B6.
The one WARN is the advisory `claude plugin tag --dry-run` (uncommitted changes); SKIPs: `locale (no localedef)` and the B3c eval-cases SKIP.
All six sections of this group pass: `OK npm pack tarball ...`, 10 x `OK agents/...|templates/researcher.md.tmpl`, `OK .claude/hooks/scripts is byte-identical to hooks/scripts`, `OK tests/filehashes-currency.test.js` (69 entries), `OK tests/cli-backfill.test.js`, `SKIP tests/eval-cases.test.sh (...)`.
After adding B6 the rollout section alone re-run via `runsec.sh wsB "rollout wave-graph preflight"` prints the SKIP line, rc=0; `bash tests/validate-quiet.test.sh` still passes. The remaining expected FAIL set for the full suite on this host is therefore only the microworld-rerun section.

---

## B6 - `tests/rollout-preflight.test.sh`: 12 wave assertions fail under /bin/bash 3.2 (surfaced only because the user's run died before reaching it)

**Symptom (exact):**
```
== rollout wave-graph preflight checker (Bash, scaffolding) ==
OK   syntax: bash -n passes
FAIL W0: did not report live CI conclusion (success)
FAIL W9: did not list all three predecessors (W3, W7, W8)
... (12 wave FAILs)
FAIL tests/rollout-preflight.test.sh
```
**Where:** `tests/validate.sh:1159-1166` -> `tests/rollout-preflight.test.sh:51` (`bash "$SCRIPT" W0`) -> `scripts/rollout-preflight.sh:16-23`.

**Root cause:** `scripts/rollout-preflight.sh` uses seven `declare -A` tables (78 subscript uses). The uncommitted portability edit deliberately added a guard: on bash < 4 it `exec`s `/opt/homebrew/bin/bash` or `/usr/local/bin/bash` if present, else prints `rollout-preflight.sh: needs bash >= 4 (macOS: brew install bash)` and exits 2. This host has only `/bin/bash` 3.2 (`which -a bash`), so every invocation in the test exits 2 with that one line, and all 12 output assertions fail. The script's own `bash -n` still passes, which is why only the behavioural rows fail. Rewriting the tables for bash 3.2 would be a 500-line scaffolding-script rewrite, out of proportion for a dev-only wave checker; the correct precondition is already encoded in the script.

**Fix (in patch, `tests/validate.sh` section only):** mirror the script's guard: if the running bash is >= 4, or either Homebrew bash path is executable, run the test exactly as before; otherwise print `SKIP tests/rollout-preflight.test.sh (scripts/rollout-preflight.sh needs bash >= 4; none found at /opt/homebrew/bin/bash or /usr/local/bin/bash)`. The test itself is untouched; CI (bash 5) is unaffected.

**Verification:**
- before: section rc=1 with the 13 FAIL lines above
- after: `runsec.sh wsB "rollout wave-graph preflight"` -> the SKIP line, rc=0 (the `elif` branch is the unchanged original command and could not be exercised here: no bash >= 4 on this host).

**Same pattern elsewhere:** `grep -rn 'declare -A\|mapfile\|readarray' --include='*.sh' hooks bin scripts tests adapters` - every other hit is a comment ("not `declare -A`: macOS ships bash 3.2"), the `_mapfile_compat` shim in `portable-tools.sh`, or converter fixture text in `tests/portable-convert.test.sh`; `scripts/rollout-preflight.sh` is the only live bash-4 dependency and the only one whose test runs it.
