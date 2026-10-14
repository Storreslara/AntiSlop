# validate.sh scratch files come from mktemp (vtmp-1)

Status: FINAL (spec-master, 2026-10-14). **One dispatchable unit**, so this is
the **fast path**: the nine-element dispatch contract is in the last section
of this file, and `task-master` is not needed.
Baseline: HEAD 12227b4, version 0.31.162. **The unit is not stamped:** it
touches only `tests/validate.sh`, not `agents/*.md` or `templates/*`, so it
bumps no version, adds no CHANGELOG entry and regenerates no `.claude/`
mirror.

## Goal

Make `tests/validate.sh` stop using fixed `/tmp/<name>` scratch files. Every
scratch file is created per run with `mktemp` and removed by the same
section. Section behaviour and every OK/FAIL/WARN message stay unchanged.
Goal clauses map to criteria:

- "no fixed `/tmp` path in validate.sh or the helper it sources" → vtmp-1
  criterion 1 (`vtmp1-ac1.sh`, first half).
- "per-run `mktemp` files, cleaned up" → criterion 1 (second half: one
  `mktemp` line and one `rm -f` line per name) and criterion 2 (no `tmp.*`
  file is left in TMPDIR).
- "the affected sections still pass, and no longer need a writable `/tmp`"
  → criterion 2 (sections 5-7, 10 and 67 with `/tmp` read-only) and
  criterion 4 (the same five section groups in a normal environment).
- "behaviour and failure messages unchanged" → criterion 3 (the unit's diff
  is exactly the mktemp substitution, checked byte for byte) and criterion 5
  (`bash -n`).
- "minimal change to the merge gate" → criteria 3 and 6 (one file only).

## Context

### Fixed /tmp paths: full inventory (measured at 12227b4)

`git grep -n '/tmp' -- tests/validate.sh tests/lib/` finds 15 lines, all in
`tests/validate.sh`. They are five names, each used three times (write, read,
`rm -f`). `tests/lib/claude-tag-filter.sh`, the only file validate.sh
sources, has none. The explorer's list of five was complete.

| Section (vsec index) | Header (line) | Fixed path | Used for |
|---|---|---|---|
| 5 | `== npm pack: …` (103) | `/tmp/npm_pack_err` | python's stderr, shown in the FAIL line |
| 6 | `== marketplace.json / plugin.json consistency ==` (123) | `/tmp/marketplace_err` | python's stderr, last line shown in the FAIL line |
| 7 | `== claude plugin tag (advisory …` (140) | `/tmp/claude_plugin_tag_out` | `claude plugin tag --dry-run` output, fed to the noise filter |
| 10 | `== agent frontmatter parses as valid YAML ==` (177) | `/tmp/frontmatter_yaml_err` | per-file python stderr, last line shown in the FAIL line |
| 67 | `== Codex adapter: TOML validity + name/description present ==` (782) | `/tmp/codex_toml_err` | per-file python stderr, last line shown in the FAIL line |

The only other temp file in validate.sh is the skip-summary log at line 15,
which already uses `mktemp` and an EXIT trap.

### Test files that sections call (checked, out of scope)

validate.sh calls 74 `tests/*.test.*` files. Five of them contain `/tmp`.
None is a fixed scratch file that two runs share:

| File | Occurrences | Why it is out of scope |
|---|---|---|
| `tests/human-decision-gate.test.sh` | 25 | Command **text** fed to the gate as fixture input (`"printf ok > /tmp/hdg-note.txt …"`). The gate only parses it; nothing executes it. |
| `tests/reviewed-path-gate.test.sh` | 1 (:947) | Same: `"printf x > /tmp/o.txt"` is an allow-case string. |
| `tests/harness-integrity-gate.test.sh` | 1 (:345) | Same: `'rm -rf /tmp/x/.claude/*'` is an over-block row. |
| `tests/microworld/dashboard-decision-block.test.js` | 2 (:683, :687) | Path strings passed to a pure function (`'/tmp/my proj'`); nothing is created. |
| `tests/microworld/dashboard-invoke.test.js` | 2 (:155, :183) | `/tmp/antislop-microworld-pwned` is a sentinel the test unlinks and then asserts is **absent**. Only a real shell-injection defect creates it, so two runs cannot clobber it. A per-run name would also need changing the injected payload string. Not trivial, and no race. |

`tests/probe-hook-identity.test.sh` sets `TMPDIR` to its own scratch
directories and has no fixed `/tmp` name.

### Premise correction: this unit does not explain watch item j

Watch item j is `validate.sh` once exiting 1 under about five concurrent
runs, never reproduced. The fixed names were suspected. Measured at 12227b4,
they **cannot change the exit code when all runs share one uid**:

- In sections 5, 6, 10 and 67, the exit code comes from python's or npm's
  exit status (`if python3 … 2>/tmp/x; then`). The file only feeds the text
  in parentheses on a FAIL line. A clobbered file gives a FAIL line the
  wrong (or an empty) reason. It cannot turn an OK into a FAIL.
- Section 7 is advisory and never sets `fail=1`.
- Probe: six concurrent runs of the five section groups through `vtargeted.sh`,
  five rounds, gave 30 of 30 exits 0. So a same-uid concurrency probe cannot
  be red at HEAD, and this plan has none (Clarifications, completion line).

The fixed names **do** flip the exit code when the fixed path cannot be
written. Two cases: `/tmp/<name>` is left by another uid (sticky `/tmp`), or
a sandbox allows writes only under its own TMPDIR. Measured with a read-only
`/tmp` in a private namespace, sections 5, 6, 10 and 67 print FAIL with an
empty reason (`FAIL npm pack tarball composition ()`). Section 7 is worse:
the write fails, the filter reads nothing, and it prints **OK** without
running any check. After the fix, all five pass there, and section 7's
output goes to a file it can read.

So the unit is still worth doing: wrong FAIL reasons under concurrency, and
false FAILs (plus one false OK) whenever `/tmp/<name>` is not writable. But
item j stays an open watch item. The scribe hint below says so.

### Design constraint: per-section mktemp, not one global scratch dir

The criteria helpers `vsec` and `vrun` (`docs/plans/epf-criteria/lib.sh`)
run a section **alone**. They cut it out of validate.sh by its `echo "== `
header, and the cut does not include the file's prelude (lines 1-27). A
global `mktemp -d` plus an EXIT trap in the prelude would leave the variable
unset in a cut-out section. Under `set -u` that is an "unbound variable"
error, and the section fails. So each section makes its own file with
`mktemp` on the line just after its header, and removes it with its
existing `rm -f` line. Section 67 makes its file inside its
`if python3 -c "import tomllib"` block, because its `rm -f` is inside that
block too. Section 7 makes its file before `if command -v claude`, because
its `rm -f` runs whether or not `claude` is on PATH.

### Prior FAIL history and notes sweep (Implementer-tier ratchet input)

- No `.fail` record names a `vtmp-*` unit (new id). The hyg-1..3 units that
  added the skip-summary prelude have `.pass` markers only.
- Notes sweep, `bash bin/marker-audit.sh . --notes --surface=tests/validate.sh`,
  2026-10-14: 23 lines. **Disposition:** most are "full validate.sh was not
  run / timed out at 590 s" notes. That is why this plan runs section
  groups, not the whole file (P5 line below). Two are relevant to item j and
  are recorded, not acted on. cost-governance-step5-effort-policy NOTE[code]:
  a transient exit 1 that did not reproduce. epf-4 NOTE[code]: an exit 1
  that could not be attributed because a concurrent run was going. Neither
  names a `/tmp` file. No NOTE[spec] concerns scratch files. The sweep is
  best effort (gitignored, per-clone records).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-10-14 Functional scope & success criteria: Q The brief asks to cover "ALL fixed /tmp paths" in validate.sh and its sourced helpers, and to decide on the called test files. Which are in? → A (self-resolved): the five names in validate.sh (the complete list; `tests/lib/claude-tag-filter.sh` has none). All `/tmp` mentions in called test files are out, with per-file reasons in the Context table. None is a shared scratch file.
- 2026-10-14 External dependencies & integrations: Q The behavioural criterion needs a read-only `/tmp` that does not disturb other runs. How? → A (self-resolved): `unshare -rm` (user + mount namespace, no root needed) mounts a read-only tmpfs over `/tmp` only inside the probe. It also mounts a private tmpfs on `/var/tmp` for TMPDIR and binds the checkout there, so a checkout under `/tmp` (a scratch worktree) still works. Measured available on this host. If it is missing, the script exits 2 with `unshare -rm unavailable`, never 0.
- 2026-10-14 Edge cases / failure handling: Q What if `mktemp` itself fails? → A (self-resolved): no new handling. The variable is then empty, the redirect `2>""` fails, and the section prints its existing FAIL line and sets `fail=1`, so it fails closed with the same message family. Adding a new message would break "messages unchanged".
- 2026-10-14 Edge cases / failure handling: Q A run killed mid-section leaves its `tmp.*` file behind. Add it to the EXIT trap? → A (self-resolved): no. The trap lives in the prelude, which `vsec`/`vrun` do not run, and the old fixed names were left behind the same way. One file per kill, in TMPDIR, is accepted.
- 2026-10-14 Technical constraints & tradeoffs: Q One global `mktemp -d` or one `mktemp` per section? → A (self-resolved): per section, for the vsec/vrun reason in Context. A global variable would make every cut-out section fail under `set -u`.
- 2026-10-14 Completion / acceptance signals: Q Is there a cheap, reliable concurrency probe that is red at HEAD? → A (self-resolved): no. Same-uid concurrency cannot change the exit code (30/30 green at HEAD), so such a probe would be vacuous. The read-only-`/tmp` probe (criterion 2) tests the real mechanism: no section writes a shared fixed path. The brief made the probe conditional ("if a cheap reliable one exists"), so this resolves it.

## Risks / dependencies

- R1: One unit, one file. No dependency.
- R2: The criteria are scripts in `docs/plans/vtmp-criteria/`, committed
  with this plan and read-only for the unit. They source
  `docs/plans/epf-criteria/lib.sh` and reuse `scope.sh`, `range.sh` and
  `vtargeted.sh`. The unit's commits are found by the subject scope
  `^[a-z]+\(vtmp-1\): `.
- R3: Criterion 2 needs `unshare -rm` (unprivileged user namespaces). On a
  host without them it exits 2, which is a FAIL of the criterion, not a
  skip. Report it as an environment gap; do not drop the criterion.
- R4: The full `bash tests/validate.sh` takes more than the 600 s Bash cap on
  this machine (notes sweep). The unit runs the five touched section groups
  (criterion 4) plus criterion 2. The orchestrator's normal merge-gate run
  covers the rest.
- R5: Do not paste a criterion as Bash text. Run `bash <script>`.
- R6: Item j stays a watch item (premise correction above). If validate.sh
  exits 1 under concurrency again after this unit lands, the cause is
  elsewhere.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion was run red at
  12227b4 (or marked `check:`) and green in a prototype worktree, and each
  `mutation:` line was observed there.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  criteria are committed scripts, and edit 1 is a single `sed` command.
- P3 "Version-stamp discipline": satisfied, vacuously. No `agents/*.md` or
  `templates/*` change.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona
  prose changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied with a scoped
  deviation. The unit runs `bash -n` and the five changed section groups,
  not the full file, which exceeds the 600 s Bash cap here (R4). No section
  is added or removed.

## Steps

### Step 1: vtmp-1, per-run mktemp scratch files in validate.sh
**Affected files:** `tests/validate.sh` only (sections 5, 6, 7, 10, 67).
**Acceptance:** `vtmp1-ac1.sh` (no `/tmp`; one mktemp and one rm per name);
`vtmp1-ac2.sh` (sections pass with `/tmp` read-only and leave no `tmp.*`);
`vtmp1-ac3.sh` (diff is exactly the substitution); the five section groups
through `vtargeted.sh`; `bash -n`; scope; trailer; tail.

## Open Questions

None. The brief made the concurrency probe conditional on a cheap,
reliable one existing. None does (premise correction; Clarifications), so
the condition resolves it. If you want a `check:` regression guard anyway
(six parallel `vtargeted.sh` runs, all exit 0, about 10 s), say so; it
would be green before and after the change.

## Self-check
- CHK1: Does the plan list every fixed `/tmp` path in validate.sh and its sourced helper, with a criterion that fails if one remains? — PASS (inventory table; `vtmp1-ac1.sh` greps `/tmp` over `tests/validate.sh tests/lib/*.sh`, red at 12227b4 with `fixed /tmp path remains:`)
- CHK2: Does every called test file with a `/tmp` mention get a disposition and a reason? — PASS (Context table, five files)
- CHK3: Is the requested concurrency probe either specified or excluded with a measured reason? — PASS (premise correction: 30/30 green at HEAD; Clarifications, completion line)
- CHK4: Is "messages unchanged" backed by a machine check, not prose? — PASS (`vtmp1-ac3.sh` undoes the substitution and compares with the pre-unit file byte for byte; a changed FAIL message prints `validate.sh differs beyond the mktemp substitution:`)
- CHK5: Do the Ordered edits and the vsec design constraint agree on where each mktemp line goes? — PASS (sections 5, 6, 10: after the header; section 7: before `if command -v claude`, since its `rm -f` runs either way; section 67: inside the tomllib block, where its `rm -f` is)
- CHK6: Does each `mutation:` line state what its own criterion prints? — FAIL (missing): the first draft's criteria 4, 5 and 6 named outputs that had not been observed — revised in place (all three observed in the prototype: `section group failed: marketplace.json / plugin.json consistency`; `syntax error near unexpected token`, exit 2; `out of scope: <file>`)
- CHK7: Is a mktemp line misplaced at the top of the file caught, given that criteria 1 and 3 would both pass? — PASS (criterion 2 and criterion 4 run sections cut out of the file; observed `sections 5 7 failed with /tmp read-only`)
- CHK8: Does criterion 2 avoid touching the real `/tmp` and other concurrent runs? — PASS (private user+mount namespace; Clarifications line 2)
- CHK9: Is the unit stamped? — PASS (no; P3 line)
- CHK10: Does the Goal's "cleaned up" clause map to a criterion? — PASS (criterion 1's rm-count half and criterion 2's `tmp.*` check; dropping one `rm -f` line prints `TMPDIR not cleaned: tmp.…`)
- CHK11: Does the contract reach 7/7 under `contract-guard`? — FAIL (conflicting): the first run printed `contract-guard: sonnet … score=6/7 failed=R6`, because one Do NOT touch bullet opened with prose, not a backticked path — revised in place (re-run: `contract-guard: haiku unit=vtmp-1 shape=lead score=7/7`)
- CHK12 (replay; units whose recorded FAIL class includes vacuous or host and whose diff touched `tests/validate.sh`: gh317, gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1, mw-step2, mw-step3, rollout-map-1, spec2-unitA, spec2-unitB): Does criterion 5 (`bash -n tests/validate.sh`) still fail under its own `mutation:` line? — PASS (it is a `check:` criterion, and deleting a closing `"` is a syntax error; observed)
- CHK13 (replay, same 12 units): Does criterion 6 (`scope.sh … 'tests/validate\.sh'`) still fail under its own `mutation:` line? — PASS (committing a second file prints `out of scope: <file>`, the shared helper's measured behaviour)
- CHK14 (replay, same 12 units): Does criterion 8 (`range.sh vtmp-1 tail tests/validate.sh`) still fail under its own `mutation:` line? — PASS (a later out-of-scope commit on the file prints `1`, exit 0)

Glossary drift (prose mode, advisory). Lens 1: none. Lens 2: none ("merge
gate" as in constitution P5). Lens 3: none load-bearing. "Scratch file" and
"section group" are test vocabulary, not domain terms.

## Scribe update hint
After vtmp-1 PASSes, update `.claude/agent-memory/scribe/project_epa2_completion.md`
item j: the fixed `/tmp` scratch names are gone (vtmp-1). Measured, they could
not flip the exit code under same-uid concurrency, so **j stays an open watch
item**. Only the unwritable-`/tmp` false FAIL/OK class is closed.

## Dispatch contracts (spec-master, fast path, 2026-10-14)

One dispatchable unit; none held.
**Retrieval contract.** No tracker issue exists for this unit (fast path).
Fetch the dispatch prompt by reading
`docs/plans/2026-10-14-validate-concurrency-tmpnames.md` with the Read tool,
finding the `### Unit: vtmp-1` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested fences
are payloads). Its first line is the literal `Unit: vtmp-1`, and
`node bin/contract-guard.js docs/plans/2026-10-14-validate-concurrency-tmpnames.md --unit=vtmp-1`
finds the block. Commit subjects never carry an issue number.

| unit | files (exact) | shared with | depends on |
|---|---|---|---|
| vtmp-1 | `tests/validate.sh` | none | none |

**Suggested model:** `haiku`. Every edit is written out literally (one `sed`
command plus five one-line inserts at unique anchors), and no unit on this
surface has FAIL history. The orchestrator recomputes the Escalation ladder
at dispatch; a tag can raise the tier but never lower it. The reviewer tier
is decided at dispatch by `hooks/scripts/reviewer-tier.sh` over the actual
diff.

**Verification record:** the three `vtmp1-*` scripts were run at 12227b4 and
were red: ac1 `fixed /tmp path remains:`, ac2 `sections 5 7 failed with /tmp
read-only`, ac3 `no-unit-commit: vtmp-1`. A scratch worktree got the criteria
committed, then edit 1 and edits 2-6 **applied by script from this file's
text** (each anchor matched once), committed as `fix(vtmp-1)`. All eight
criteria were green there. Mutations observed in the prototype: skip edit 6
(ac1 `codex_toml_err: mktemp lines=0 rm lines=1 (want 1 1)`, ac2 `sections
67 67 failed with /tmp read-only`); drop `rm -f "$npm_pack_err"` (ac1
`npm_pack_err: mktemp lines=1 rm lines=0 (want 1 1)`, ac2 `TMPDIR not
cleaned: tmp.…`); move the marketplace line to the top (ac1 and ac3 green, ac2
red); change a FAIL message (ac3 red); and criteria 4, 5 and 6's own `mutation:` lines (each prints what its line says).

### Unit: vtmp-1

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 1.

``````
Unit: vtmp-1

## Objective
Replace the five fixed `/tmp/<name>` scratch files in `tests/validate.sh` (sections 5, 6, 7, 10 and 67) with per-run `mktemp` files. Each section makes its own file on one new line, uses it through a quoted variable named like the old file, and removes it with its existing `rm -f` line. Section behaviour and every OK/FAIL/WARN message stay byte-identical. The only differences are the five new `<name>=$(mktemp)` lines and `/tmp/<name>` becoming `"$<name>"`.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-14-validate-concurrency-tmpnames.md`, section `### Unit: vtmp-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/validate.sh` (anchors: the five lines quoted in edits 2-6, each of which occurs exactly once; edit 1 rewrites the 15 lines that contain `/tmp/`)

## Ordered edits
1. command: `sed -i -E 's#/tmp/(npm_pack_err|marketplace_err|claude_plugin_tag_out|frontmatter_yaml_err|codex_toml_err)#"$\1"#g' tests/validate.sh`
   expect: 0
2. file: `tests/validate.sh` (section 5: make npm_pack_err)
   anchor: line matching `echo "== npm pack: dev-scratch dirs excluded, shipped dirs included =="`
   indent: 0
   before:
~~~~
echo "== npm pack: dev-scratch dirs excluded, shipped dirs included =="
~~~~
   after:
~~~~
echo "== npm pack: dev-scratch dirs excluded, shipped dirs included =="
npm_pack_err=$(mktemp)
~~~~
3. file: `tests/validate.sh` (section 6: make marketplace_err)
   anchor: line matching `echo "== marketplace.json / plugin.json consistency =="`
   indent: 0
   before:
~~~~
echo "== marketplace.json / plugin.json consistency =="
~~~~
   after:
~~~~
echo "== marketplace.json / plugin.json consistency =="
marketplace_err=$(mktemp)
~~~~
4. file: `tests/validate.sh` (section 7: make claude_plugin_tag_out before `if command -v claude`, because its `rm -f` runs either way)
   anchor: line matching `source tests/lib/claude-tag-filter.sh`
   indent: 0
   before:
~~~~
source tests/lib/claude-tag-filter.sh
~~~~
   after:
~~~~
source tests/lib/claude-tag-filter.sh
claude_plugin_tag_out=$(mktemp)
~~~~
5. file: `tests/validate.sh` (section 10: make frontmatter_yaml_err before the loop)
   anchor: line matching `echo "== agent frontmatter parses as valid YAML =="`
   indent: 0
   before:
~~~~
echo "== agent frontmatter parses as valid YAML =="
~~~~
   after:
~~~~
echo "== agent frontmatter parses as valid YAML =="
frontmatter_yaml_err=$(mktemp)
~~~~
6. file: `tests/validate.sh` (section 67: make codex_toml_err inside the tomllib block, where its `rm -f` is; two-space indent)
   anchor: line matching `if python3 -c "import tomllib" >/dev/null 2>&1; then`
   indent: 0
   before:
~~~~
if python3 -c "import tomllib" >/dev/null 2>&1; then
~~~~
   after:
~~~~
if python3 -c "import tomllib" >/dev/null 2>&1; then
  codex_toml_err=$(mktemp)
~~~~
7. command: `git add tests/validate.sh && git commit -m "fix(vtmp-1): validate.sh scratch files come from mktemp" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer)
   expect: 0
8. command: `git diff --quiet HEAD -- tests/validate.sh`
   expect: 0

## Do NOT touch
- `tests/validate.sh` outside the five inserted lines and the 15 lines edit 1 rewrites: every echo text, the python programs, the prelude (lines 1-27, including the skip-summary trap) and every other section stay byte-identical (`vtmp1-ac3.sh` checks this).
- `tests/validate.sh` prelude and traps: add no global temp dir, no EXIT trap entry and no `mktemp` failure message. Sections are run cut out of the file by `vsec`/`vrun`, which do not run the prelude.
- `tests/lib/claude-tag-filter.sh` and every `tests/*.test.*` file: their `/tmp` mentions are fixture strings, out of scope.
- `docs/plans/vtmp-criteria/` and `docs/plans/epf-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/vtmp-criteria/vtmp1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 6; prints `codex_toml_err: mktemp lines=0 rm lines=1 (want 1 1)`, exit 1 (observed). Skipping every edit prints `fixed /tmp path remains:` and the 15 lines (observed at 12227b4).
2. run: `bash docs/plans/vtmp-criteria/vtmp1-ac2.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 6; prints `sections 67 67 failed with /tmp read-only`, exit 1 (observed). At 12227b4 it prints `sections 5 7 failed with /tmp read-only`. Exit 2 with `unshare -rm unavailable` is an environment gap: report it, do not count it as a pass.
3. run: `bash docs/plans/vtmp-criteria/vtmp1-ac3.sh`
   exit: 0
   stdout: empty
   mutation: also change `FAIL npm pack tarball composition` to `FAIL npm pack composition` and commit; prints `validate.sh differs beyond the mktemp substitution:` and the differing lines, exit 1 (observed).
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'npm pack' 'marketplace.json / plugin.json consistency' 'claude plugin tag (advisory' 'agent frontmatter parses as valid YAML' 'Codex adapter: TOML validity'`
   exit: 0
   stdout: empty
   check: green at 12227b4 on purpose; it proves the five sections still pass in a normal environment (each header string matches exactly one section).
   mutation: move edit 3's `marketplace_err=$(mktemp)` line to just after `fail=0` near the top of the file; prints `section group failed: marketplace.json / plugin.json consistency`, exit 1.
5. run: `bash -n tests/validate.sh`
   exit: 0
   stdout: empty
   check: green at 12227b4 on purpose; it guards the whole file's syntax.
   mutation: delete the closing `"` of edit 1's `"$npm_pack_err"` on the `2>` line; prints a syntax error, exit 2.
6. run: `bash docs/plans/epf-criteria/scope.sh vtmp-1 'tests/validate\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/lib/claude-tag-filter.sh`; prints `out of scope: tests/lib/claude-tag-filter.sh`, exit 1.
7. run: `bash docs/plans/epf-criteria/range.sh vtmp-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
8. run: `bash docs/plans/epf-criteria/range.sh vtmp-1 tail tests/validate.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no tests/validate.sh (the file is the test suite; criteria 1-3 are the tests for this change and were red at 12227b4)
blast-radius: tests/validate.sh:103-154 (sections 5-7), :177-196 (section 10), :782-801 (section 67); run by the merge gate and cut out section by section by `docs/plans/epf-criteria/lib.sh` (`vsec`, `vrun`); no other file reads these lines.
commit-message: fix(vtmp-1): validate.sh scratch files come from mktemp
trailer: the trailer names the model you actually ran on.
quoting: edit 1's replacement is `"$\1"` inside single quotes: sed writes a literal `"$npm_pack_err"` (with the double quotes). Results: `2>"$npm_pack_err"`, `$(cat "$npm_pack_err")`, `>"$claude_plugin_tag_out" 2>&1`, `<"$claude_plugin_tag_out"`, `rm -f "$npm_pack_err"`.
measured: at 12227b4 `/tmp` occurs on exactly 15 lines of tests/validate.sh (five names x write, read, rm) and on none in tests/lib/; each anchor in edits 2-6 occurs once; the full validate.sh exceeds the 600 s Bash cap here, so do not run it whole.
diagnosis: none
review-packet:
~~~
unit: vtmp-1 (plan docs/plans/2026-10-14-validate-concurrency-tmpnames.md)
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
