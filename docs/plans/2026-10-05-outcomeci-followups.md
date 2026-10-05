# OutcomeCI series-gate trial: follow-ups after ocig-1/1b/2/3 (2026-10-05)

Status: FINAL (fast path, 4 units). The operator authorized implementation
after this spec. Parent spec:
`docs/plans/2026-10-05-outcomeci-series-gate-trial.md` (cited, not repeated).
The parent now ends with a "Post-PASS amendments" section (A1-A5), which this
commit adds. Item C of the brief is closed there, along with the spec-text
halves of items D (AC2.3) and E (AC1.5, AC1.6).

## Goal

Close every open review note from units ocig-1, ocig-1b, ocig-2 and ocig-3 that
blocks a trustworthy Step 4 live run, then prepare that run:

| Goal clause | Unit | Criterion |
|---|---|---|
| A crafted journal field cannot inject lines or columns into a reviewer dispatch | ocigf-1 | AC-1.5 |
| A 0-byte journal prints no shell error. A present journal is never reported "absent". | ocigf-1 | AC-1.6 |
| A dangling-symlink journal is not read as absent | ocigf-1 | AC-1.7 |
| A run-id holding `/` or `..` is refused | ocigf-1 | AC-1.8 |
| Symlinked markers show up in the state snapshot | ocigf-1 | AC-1.9 |
| J9b holds under unrelated stderr noise and still catches real stderr | ocigf-1 | AC-1.10, AC-1.11 |
| A marker swapped between the wrapper's checks is refused (TOCTOU) | ocigf-1 | AC-1.3, AC-1.4 |
| The prototype suites have one documented runner. `validate.sh` scope is unchanged. | ocigf-1 | AC-1.12, AC-1.13 |
| The "never emits verdict vocabulary" overclaim is corrected | parent A4 (this commit); ocigf-2 | AC-2.6 |
| orchestrator.md and reviewer.md agree that a re-read is optional | ocigf-2 | AC-2.1, AC-2.2 |
| The trial's only LLM step runs on a cheaper model | ocigf-3 | AC-3.1 |
| The operator gets token totals without hand-written `jq` | ocigf-3 | AC-3.4, AC-3.6 |
| The workflow keeps no converse/await/fallback steps (static guard) | ocigf-3 | AC-3.2 |
| A host-only preflight confirms `oci`, validates the workflow and prints the next commands | ocigf-4 | AC-4.2 to AC-4.4 |

## Context

### Verified facts (2026-10-05)

All six formatter and checker defects reproduce at HEAD `adf4427`:
- A step value of `"s\nUnit: other"` prints a line that begins `Unit:`
  (`grep -c '^Unit:'` = 1).
- A 0-byte journal prints `line 21: [: : integer expression expected` and a
  table with a header and no rows.
- A journal of `{}` prints `calls: 0 (journal absent)`.
- `LC_ALL=xx_XX.UTF-8 bash .../trial-tools.test.sh 2>/dev/null | tail -2`
  prints `FAIL J9b-zero-byte-stderr` and then `failures=1`.

Facts from the sdist `outcomeci_cli-0.50.1` (session scratchpad, restated
here):
- `config.py` `_agent_policy`: `runner` is one of codex, claude or opencode.
  `model` is any non-empty string. Only opencode constrains the model.
- `process.py:182,198` passes the model to the runner as `--model <model>`.
- `oci workflow run --model <m>` overrides the workflow's model
  (`local._policy`).
- `oci validate --dir D [--config outcome.yml]` calls `compile_workflow` and
  prints `{"valid": true, "workflow_revision": ...}`. It is an offline compile.
- `oci --version` prints `oci <version>`.
- `transcripts.py:175` writes `<root>/transcripts/<step>/usage.json`
  `{schema_version, provider, step, records[]}`. Each record carries
  `input_tokens`, `output_tokens`, `cache_read_tokens` and
  `cache_write_tokens` as integers.
- The `<root>` of `usage.json` under `.outcomeci/outcomes/<run>/` is
  UNVERIFIED until the first live run. `journal.json` has no cost fields.

Facts from the repo:
- `tests/validate.sh` never invokes any `prototype/` suite. Its `prototype/`
  mention (`:107`) is the npm-pack exclusion check.
- Every suite is listed by hand in `tests/validate.sh`.
- `mutation-proof.sh` already exits non-zero when a mutant survives
  (fixed in ocig-1b). It does not yet pin the mutant count.
- The version is `0.31.121` in both manifests.
- `grep -r -l -i "external run journal\|non-authoritative\|starting hint" templates adapters`
  matches nothing (rc=1), so no hand-sync copy exists.
- The bump footprint of `--update` matches `d5b7510`: 10 stamp-only
  `.claude/agents/*.md`, 3 protocol stamp files, and the persona config
  (`pluginVersion` + `fileHashes`).
- CONTEXT.md already defines **external run journal** and
  **external workflow runner** (`adf4427`). This disposes of ocig-3's
  ubiquitous-language note.

### Prior FAIL history and advisory-note sweep

- `ocig-2` has one FAIL record: AC2.6 failed on a pre-existing dangling
  `[[verdict]]` link in CONTEXT.md, outside the unit's scope.
  **Disposition:** each unit below has a pre-dispatch check (Risks R1): the
  orchestrator confirms `tests/validate.sh` is green at the base before it
  dispatches, so an inherited red cannot be charged to the unit.
- `bin/marker-audit.sh . --notes`, swept over
  `prototype/outcomeci-series-gate`, `agents/orchestrator.md` and
  `agents/reviewer.md` (filtered to journal/ocig notes for the agents files),
  disposes of each note as follows:
  - ocig-3 `NOTE[code]` on journal-evidence escaping: ocigf-1.
  - ocig-3 `NOTE[code]` on the orchestrator/reviewer "may": ocigf-2.
  - ocig-3 `NOTE[spec]` on the glossary: already closed by `adf4427`.
  - ocig-2 `NOTE[spec]` on the AC2.5 range: parent A2.
- The full `.pass` notes of ocig-1, ocig-1b, ocig-2 and ocig-3 were read in
  full.
  - In scope: every item named in the brief, plus the ocig-1 note that
    `mutation-proof.sh` does not pin its count. That note is needed so
    `run-all.sh` can rely on exit codes.
  - Deferred, named in Out of scope: ocig-1 T5b/T8 assertion gaps, the
    `export -f` BASH_FUNC leak, ocig-1b "ok then FAIL" output ordering, and
    the T9 global-variable restore.
  - The sweep is best-effort. `.claude/reviewed/` is untracked state.

### Decisions (self-resolved; the brief delegated them)

- **D-A (formatter cells):** every copied cell is rendered as
  `tostring`, and each control character (U+0000-U+001F, U+007F) and each
  `|` is replaced by one space. The verdict vocabulary inside a cell is not
  scrubbed, because rewriting journal content would make the evidence lie.
  The wording is corrected instead (parent A4, CHANGELOG in ocigf-2).
- **D-B (formatter states):**

  | Journal state | stdout after the banner | stderr | exit |
  |---|---|---|---|
  | path absent (`! -e && ! -L`) | `calls: 0 (journal absent)` | empty | 0 |
  | 0 bytes, `{}`, `.calls` null/absent, `.calls` empty object or array | `calls: 0 (journal empty)` | empty | 0 |
  | ≥1 call | table | empty | 0 |
  | dangling symlink, a directory, malformed JSON, or `.calls` neither object, array nor null | nothing (no banner) | exactly one line, `journal-evidence: journal unreadable` | 1 |
  | run-id invalid | nothing | exactly one line, `journal-evidence: invalid run-id` | 64 |

- **D-C (run-id):** valid iff it matches `^[A-Za-z0-9_][A-Za-z0-9._-]*$` and
  does not contain `..`. Both `check-journal.sh` and `journal-evidence.sh`
  apply it. `check-journal.sh` exits 64 with nothing on stdout and the
  single stderr line `check-journal: invalid run-id`.
- **D-D (check-journal symlink):** a path that is a symlink (`-L`) counts as
  present. A dangling one therefore reads as `journal=invalid calls=0 bad=0`
  and exits 1, with or without `--allow-absent`.
- **D-E (snapshot symlinks):** `state-snapshot.sh` records symlinks
  (`-type l`) as well as regular files, and never follows them. A symlink's
  line is `link:<sha256 of the readlink target string>  <relpath>`. Regular
  files keep the `<sha256>  <relpath>` format, and both kinds count toward
  `snapshot-files=`. The `find` start path `.claude/reviewed` is itself
  recorded when it is a symlink.
- **D-F (TOCTOU):** the wrapper reads the marker **once** at R2. It keeps
  the content in a variable, takes line 1 for R3 and the cited commit from
  that variable, and records the content's sha256. A new check, R7, runs
  after R6 and before the allow line: it re-hashes the marker file, and if
  the hash differs the wrapper refuses with exit 70, reason
  `marker-changed`, sentinel `# CHECK:R7`. The helpers
  (`marker-commit-check.sh`, `marker-verify.sh`) still re-read the file. R7
  bounds that window to the R2-R7 span. It cannot close an
  A-B-A swap; that residual is accepted for the prototype.
- **D-G (merge-gate scope):** `tests/validate.sh` is NOT changed (P5 scope
  stays shipped code). A new `prototype/outcomeci-series-gate/tests/run-all.sh`
  runs every `tests/*.test.sh` in that directory plus `mutation-proof.sh`. It
  prints `<suite>: ok|FAIL` per suite and finishes with
  `suites=<n> failed=<m>`, exiting non-zero iff m>0. The README documents it
  as the command to run before any live run.
- **D-H (model):** `workflow/outcome.yml` sets `model: claude-haiku-4-5`,
  the cheapest current model for a one-line summary. It keeps the `claude`
  runner profile, so no API key and no cloud metering. The README tells the
  operator: if run 1 fails on the model, re-run with `--model claude-sonnet-5-5`
  after `workflow run`. That re-run counts against the 3-run cap (A4).
- **D-I (token report):** a new `token-usage.sh [--cap <n>] <usage.json>`
  prints one line,
  `records=<n> input=<n> output=<n> cache_read=<n> cache_write=<n> total=<input+output>`.
  A missing numeric field counts as 0. Exit codes:
  - 0: ok, or within the cap.
  - 1: under `--cap`, total > cap or records = 0.
  - 2: unreadable file, invalid JSON, or `.records` is not an array.
  - 64: usage error.

  The cap comparison line carries `# CHECK:CAP`.
- **D-J (preflight):** a new `preflight.sh [--unit <id>]` runs every check
  and reports each one. It exits with the code of the first failing check,
  in this order:

  | check | failing exit |
  |---|---|
  | `tools` (bash, git, jq on PATH) | 2 |
  | `oci` (on PATH) | 3 |
  | `oci-version` (`oci --version` = `oci 0.50.1`) | 4 |
  | `validate` (`oci validate --dir <temp copy of workflow/>` prints `"valid": true`) | 5 |
  | `docker` (`docker info` exits 0) | 6 |
  | `token` (`CLAUDE_CODE_OAUTH_TOKEN` non-empty; the value is never printed) | 7 |

  - It prints `check <name>=<value>` lines, then a `next:` block with the
    exact runbook commands, then a last line `preflight=ready` or
    `preflight=blocked reason=<first failing check>`.
  - `oci=missing` prints `pipx install outcomeci-cli==0.50.1` in the
    `next:` block.
  - With `--unit <id>`, the cited commit is read from the project's
    `.pass` line 1 (read-only) and substituted into the commands. Otherwise
    they show `<unit>` and `<sha>` placeholders.
  - It never invokes `oci` with arguments other than `--version` or
    `validate ...`. It never invokes curl, wget, pip or pipx, and never
    writes inside the repo.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-10-05 Domain entities / data model: Q How does a symlinked marker
  appear in the state snapshot without following it? → A (self-resolved):
  `link:<sha256 of target string>  <relpath>`, counted in snapshot-files (D-E)
- 2026-10-05 Non-functional attributes (perf, security, scale): Q Is
  reading the marker once enough to close the TOCTOU gap when helpers
  re-read it? → A (self-resolved): no. Read once, then re-hash at R7 and
  refuse `marker-changed` (70). The A-B-A residual is accepted (D-F).
- 2026-10-05 External dependencies & integrations: Q Which cheaper model,
  and by which mechanism, given the trial forbids keys and cloud metering?
  → A (self-resolved): `claude-haiku-4-5` in the workflow file under the
  `claude` runner profile, with a `--model claude-sonnet-5-5` override as
  the documented fallback (D-H). The sdist confirms the model string is
  passed through unvalidated.
- 2026-10-05 Edge cases / failure handling: Q What does the formatter print
  for empty, `.calls`-less, dangling-symlink and malformed journals? → A
  (self-resolved): the D-B table.
- 2026-10-05 Technical constraints & tradeoffs: Q Should `tests/validate.sh`
  start running the prototype suites? → A (self-resolved): no. Add
  `run-all.sh`, document it, and leave the merge-gate scope alone (D-G).
  Running a prototype in the plugin's merge gate would couple shipped
  releases to unshipped code.

## Risks / dependencies

- R1 (inherited red, from the ocig-2 FAIL): before dispatching each unit,
  the orchestrator confirms that `bash tests/validate.sh` exits 0 at the
  base. It may run in the section-aligned chunks prior reviewers used,
  because a whole run takes about 664 s, more than the 600 s tool ceiling.
  A red base goes to the human; it is not charged to the unit.
- R2 (order): ocigf-1 runs first. ocigf-3 and ocigf-4 both edit `README.md`
  and add suites that `run-all.sh` picks up, so they run after ocigf-1 and
  in the order 3, then 4. ocigf-2 is independent of the prototype units.
  The one-unit-at-a-time invariant still applies.
- R3 (stamped edit, P3): ocigf-2 is the only stamped unit. The version is
  re-derived at execution time as the current patch + 1 (0.31.122 if nothing
  lands first). Bump before `--update`. Commit staging follows the `d5b7510`
  / `efeaed7` precedent: `git add -A` after `git status` shows only the
  footprint. That is because the integrity gate refuses commands that name
  the persona config.
- R4 (D-H unverified): Claude Code accepting `claude-haiku-4-5` under the
  subscription token is assumed, not measured. The fallback is documented
  and costs one of the three runs.
- R5 (`usage.json` location unverified): the AC4.5 operator check uses a
  glob plus a `find` fallback. If neither finds a file, the trial report says
  so; that is not a failure of the gate trial.
- R6 (TOCTOU residual): see D-F. This is acceptable for a prototype that is
  not a Gate.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every defect was reproduced at
  `adf4427` before the criteria were written. Every new guard carries a
  mutation case (AC-1.4, AC-1.11, AC-3.5).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied.
  `token-usage.sh` replaces a hand-written `jq`, `preflight.sh` replaces
  manual checks, and `.claude/agents/` copies are regenerated by
  `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied. ocigf-1, ocigf-3 and ocigf-4
  touch only `prototype/` (AC-1.14, AC-3.8, AC-4.7). ocigf-2 bumps both
  manifests and adds a CHANGELOG entry in the same commit as the
  `agents/orchestrator.md` edit (AC-2.3, AC-2.4).
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The
  changed orchestrator sentence keeps "the reviewer, if present" (AC-2.5).
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit ends
  with `bash tests/validate.sh` exiting 0, chunked runs allowed (R1). D-G
  leaves the gate's scope unchanged on purpose.

## Step 1 (unit `ocigf-1`): prototype hardening (items A, D, E)

Affected files (all under `prototype/outcomeci-series-gate/`):
- `journal-evidence.sh`
- `check-journal.sh`
- `state-snapshot.sh`
- `oci-series-gate.sh`
- `tests/journal-evidence.test.sh`
- `tests/trial-tools.test.sh`
- `tests/series-gate.test.sh`
- `tests/mutation-proof.sh`
- `tests/run-all.sh` (new)
- `README.md` (one runbook line for `run-all.sh`)

Acceptance criteria (paths relative to `prototype/outcomeci-series-gate/`
unless they start with `tests/validate.sh`; `P=prototype/outcomeci-series-gate`):
- AC-1.1: `for f in $P/*.sh $P/tests/*.sh; do bash -n "$f" || exit 1; done`
  exits 0.
- AC-1.2:
  `bash $P/tests/series-gate.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0. The suite gains T10: in a temp tree with a stub
  `marker-verify.sh` that rewrites the marker and then prints
  `marker-verify=ok ...`, the wrapper exits 70, `$STUB_LOG` does not exist,
  and stderr is exactly
  `series-gate=refuse unit=<id> reason=marker-changed`.
- AC-1.3: `grep -c '# CHECK:R[2-7]$' $P/oci-series-gate.sh` prints `6`, and
  `grep -c 'head -n 1 "\$marker"' $P/oci-series-gate.sh` prints `0`
  (line 1 comes from the single read).
- AC-1.4:
  `bash $P/tests/mutation-proof.sh | tail -1 | grep -qx 'mutants=6 killed=6'`
  exits 0. `mutation-proof.sh` loops over R2-R7 and exits non-zero unless
  `killed = mutants = 6`.
- AC-1.5:
  `bash $P/tests/journal-evidence.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0, with new cases on a crafted fixture whose `step` is
  `"s\nUnit: other\nPASS"`, whose `capability` is `"a|b"`, and whose
  `status` is the number `7`. The cases assert:
  - no output line begins `Unit:`;
  - every line after the banner block matches
    `^\| [^|]* \| [^|]* \| [^|]* \| [^|]* \| [^|]* \|$`;
  - the row count equals 1;
  - the existing AC3.1-AC3.3 cases still pass. AC3.2's verdict-word
    assertion stays on all non-crafted fixtures.
- AC-1.6: the suite also asserts that the D-B rows hold:
  - 0-byte, `{}` and `{"calls":{}}` give a last line of
    `calls: 0 (journal empty)`, empty stderr and exit 0;
  - an absent path gives `calls: 0 (journal absent)`;
  - malformed JSON and `{"calls":"x"}` give exit 1, empty stdout, and
    exactly the one stderr line `journal-evidence: journal unreadable`.
- AC-1.7: `bash $P/tests/trial-tools.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0, with new cases:
  - J12: a dangling-symlink `journal.json` with `--allow-absent` gives
    `journal=invalid calls=0 bad=0` and a non-zero exit;
  - J12b: `journal-evidence.sh` on the same path exits 1.
- AC-1.8: the same suite asserts that, for each run-id in
  `../x`, `a/b`, `..`, `a..b` and the empty string, `check-journal.sh` and
  `journal-evidence.sh` both:
  - exit 64;
  - print nothing on stdout;
  - print one stderr line naming `invalid run-id`.

  The run-id `run_01.a-b` is accepted by both.
- AC-1.9: the same suite gains S6, S6b and S6c:
  - S6: replacing a fixture marker with a symlink to a file of identical
    content changes the snapshot, and the snapshot contains a line
    matching `^link:[0-9a-f]{64}  \./?\.claude/reviewed/`.
  - S6b: adding a dangling symlink under the fixture's `reviewed/`
    increments `snapshot-files=` by 1.
  - S6c: the snapshot does not follow links. A symlink to a file outside
    `.claude/` does not put that file's content hash in the output.
- AC-1.10:
  `LC_ALL=xx_XX.UTF-8 bash $P/tests/trial-tools.test.sh 2>/dev/null | tail -1 | grep -qx 'failures=0'`
  exits 0. Today it prints `failures=1` (J9b). Verified 2026-10-05.
- AC-1.11 (J9b non-vacuous):
  `m=$(mktemp) && sed 's# 2>/dev/null##g' $P/check-journal.sh > "$m" && CHECK_JOURNAL_BIN="$m" LC_ALL=xx_XX.UTF-8 bash $P/tests/trial-tools.test.sh 2>/dev/null | grep -c '^FAIL J9b'`
  prints at least `1`. This shows J9b still fails when the checker leaks
  jq's stderr.
- AC-1.12: `bash $P/tests/run-all.sh | tail -1` prints
  `suites=<N> failed=0`, where `N = $(ls $P/tests/*.test.sh | wc -l) + 1`,
  and the command exits 0. A temp copy of `run-all.sh`, placed next to a
  copy of the tests directory that holds an extra `zz-red.test.sh`
  containing `exit 1`, exits non-zero and prints
  `zz-red.test.sh: FAIL`. The suite runs this check itself, or it is a
  one-shot command in the lead's packet; either is fine, but the reviewer
  re-runs it.
- AC-1.13: `grep -c 'tests/run-all.sh' $P/README.md` is at least 1, and
  `git diff <base>..<last unit commit> -- tests/validate.sh` prints nothing.
- AC-1.14 (path scope, parent A2):
  `git diff --name-only <parent of first unit commit>..<last unit commit> | grep -v '^prototype/outcomeci-series-gate/'`
  prints nothing.
- AC-1.15 (repo state untouched, parent A1): run
  `bash $P/state-snapshot.sh . > "$s1"`, then AC-1.2, AC-1.4, AC-1.5 and
  AC-1.7, then `bash $P/state-snapshot.sh . > "$s2"`. `cmp "$s1" "$s2"`
  exits 0. The two snapshot files live in `mktemp`.
- AC-1.16: `bash tests/validate.sh` exits 0 (chunked runs allowed, R1).

## Step 2 (unit `ocigf-2`): persona wording, re-read is optional (item B; STAMPED)

Affected files:
- `agents/orchestrator.md`: the non-authoritative-inputs paragraph, ~L171-178.
- `.claude-plugin/plugin.json` and `package.json`: patch bump.
- `CHANGELOG.md`: a new entry at the top of `[Unreleased]`.
- Regenerated by `node bin/cli.js --update` after the bump: the
  `d5b7510` footprint.

`agents/reviewer.md` is NOT edited. Its "You may re-read" wording is the
target.

The edit replaces "which the reviewer, if present, checks against the
journal file itself and never counts as a met acceptance criterion" with
"which the reviewer, if present, may check against the journal file and its
stated sha256, and which never counts as a met acceptance criterion". The
line wrap is free.

The CHANGELOG entry names the unit `ocigf-2` and the new version. It
corrects the 0.31.121 entry: the formatter's own text never emits
reviewer-verdict vocabulary, while cells copied from the journal are
neutralized to one line and pipe-free (ocigf-1) and are otherwise verbatim.
The 0.31.121 entry itself is not rewritten.

Acceptance criteria (`<base>` = parent of the unit's first commit,
`<tip>` = the unit's last commit):
- AC-2.1:
  `for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr -s '\n' ' ' < "$f" | grep -o 'checks against the journal file' | wc -l; done`
  prints `0` twice.
- AC-2.2: the same loop with `'may check against the journal file and its stated sha256'`
  prints `1` twice. The same loop over `agents/reviewer.md` with
  `'You may re-read the journal file'` prints `1`.
- AC-2.3:
  `bash hooks/scripts/version-stamp-check.sh <base>..<tip> | grep -q '^version-stamp-check: ok '`
  exits 0, and `jq -r .version .claude-plugin/plugin.json` equals
  `jq -r .version package.json`.
- AC-2.4:
  `for c in $(git rev-list <base>..<tip> -- agents templates); do git show --name-only --format= "$c" | grep -qx CHANGELOG.md || exit 1; done`
  exits 0.
- AC-2.5:
  `git diff <base>..<tip> -- agents/orchestrator.md | grep '^+[^+]' | grep -i 'reviewer' | grep -vic 'if present'`
  prints `0`.
- AC-2.6:
  `awk '/^## \[Unreleased\]/{f=1;next} f&&/^\*\*/{print;exit}' CHANGELOG.md`
  prints a line containing `ocigf-2` and `0.31.121`, and
  `grep -c 'never emits reviewer-verdict vocabulary' CHANGELOG.md` still
  prints `1` (the old entry is unedited).
- AC-2.7: after the commit, `node bin/cli.js --update >/dev/null && git status --porcelain`
  prints nothing.
- AC-2.8: `git diff --stat <base>..<tip> -- hooks templates adapters` prints
  nothing, and
  `grep -r -l -i "journal file" templates adapters` exits 1.
- AC-2.9 (scope):
  `git diff --name-only <base>..<tip> | grep -vE '^(agents/orchestrator\.md|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/agents/[a-z-]+\.md|\.claude/persona-protocol(-slim)?\.md|\.claude/protocol-digest\.md|\.claude/persona-[a-z]+\.json|\.claude/agent-memory/.*)$'`
  prints nothing.
- AC-2.10: `node tests/adapter-protocol-parity.test.js` exits 0, and
  `bash tests/validate.sh` exits 0 (chunked runs allowed).

## Step 3 (unit `ocigf-3`): token spend (item F)

Affected files (under `prototype/outcomeci-series-gate/`):
- `workflow/outcome.yml`: model line plus header comment.
- `token-usage.sh` (new)
- `tests/token-usage.test.sh` (new)
- `README.md`: operator checks AC4.5 and AC4.6 plus the D-H fallback note.

The README states these as operator checks for Step 4, not repo CI:
- AC4.5: `f=$(ls -d "$OCI_TRIAL_DIR"/.outcomeci/outcomes/*/transcripts/summarize/usage.json 2>/dev/null | head -1); [ -n "$f" ] || f=$(find "$OCI_TRIAL_DIR/.outcomeci" -name usage.json | head -1); bash prototype/outcomeci-series-gate/token-usage.sh --cap "${OCI_TOKEN_CAP:-60000}" "$f"`
  exits 0. The cap is a placeholder, to be set after run 1. The path is
  marked UNVERIFIED.
- AC4.6: the static guard from AC-3.2.

Acceptance criteria:
- AC-3.1: `grep -c 'model: claude-haiku-4-5' $P/workflow/outcome.yml`
  prints `1`, and `grep -ci 'opus' $P/workflow/outcome.yml` prints `0`.
- AC-3.2:
  `grep -cE '^[[:space:]]+(converse|await):|fallback:' $P/workflow/outcome.yml`
  prints `0`, and the parent AC2.4 grep still prints `0`.
- AC-3.3: `bash -n $P/token-usage.sh && bash -n $P/tests/token-usage.test.sh`
  exits 0.
- AC-3.4:
  `bash $P/tests/token-usage.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0. The cases use inline fixtures:
  - U1: two records (100/20/5/1 and 50/10/0/0) give exactly
    `records=2 input=150 output=30 cache_read=5 cache_write=1 total=180`
    and exit 0.
  - U2: `--cap 180` on U1 exits 0.
  - U3: `--cap 179` exits 1.
  - U4: `{"records":[]}` with `--cap 10` exits 1; without a cap it exits 0
    with `records=0`.
  - U5: malformed JSON exits 2.
  - U6: `{"records":{}}` exits 2.
  - U7: a missing file exits 2.
  - U8: no argument exits 64.
  - U9: a record missing `output_tokens` counts it as 0.
- AC-3.5: the suite also runs an in-suite mutant that replaces the
  `# CHECK:CAP` line with `:` in a temp copy. U3 must fail against it; the
  suite counts this as a case.
- AC-3.6: `grep -c 'token-usage.sh --cap' $P/README.md` is at least 1,
  `grep -c 'UNVERIFIED' $P/README.md` is at least 1, and
  `grep -c 'claude-sonnet-5-5' $P/README.md` is at least 1.
- AC-3.7: AC-1.12 holds, with N now counting `token-usage.test.sh`.
- AC-3.8: path scope as in AC-1.14, for this unit's range.
- AC-3.9: `bash tests/validate.sh` exits 0 (chunked runs allowed).

## Step 4 (unit `ocigf-4`): Step 4 preflight (item G)

Affected files (under `prototype/outcomeci-series-gate/`):
- `preflight.sh` (new)
- `tests/preflight.test.sh` (new)
- `README.md`: a step 0 that runs the preflight.

Behaviour per D-J. Test fixtures prepend a stub directory to `PATH` that
holds:
- `oci`: logs its argv, answers `--version` with `$STUB_OCI_VERSION`
  (default `oci 0.50.1`), and answers `validate` with
  `$STUB_VALIDATE_OUT` (default `{"valid": true, "workflow_revision": "x"}`);
- `docker`: exits `$STUB_DOCKER_RC`;
- `curl`, `wget`, `pip` and `pipx`: each logs any call.

Acceptance criteria:
- AC-4.1: `bash -n $P/preflight.sh && bash -n $P/tests/preflight.test.sh`
  exits 0.
- AC-4.2:
  `bash $P/tests/preflight.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0. Cases:
  - P1: every stub is healthy and the token is set. The exit is 0, the
    last line is `preflight=ready`, and the `next:` block contains
    `oci-series-gate.sh --unit` and `state-snapshot.sh`.
  - P2: no `oci` on PATH gives exit 3, `check oci=missing`,
    `pipx install outcomeci-cli==0.50.1` in the output, and
    `preflight=blocked reason=oci`.
  - P3: version `oci 0.49.0` gives exit 4.
  - P4: validate output `{"valid": false}` gives exit 5.
  - P5: `STUB_DOCKER_RC=1` gives exit 6.
  - P6: an unset token gives exit 7. A token set to `SECRETVALUE` never
    appears in the output.
  - P7: in every case, the oci argv log lines match only `^--version$` or
    `^validate --dir `, and the curl/wget/pip/pipx log is empty.
  - P8: no line of the `next:` block contains `--cloud`.
  - P9: `--unit` naming a fixture project's `.pass` marker substitutes its
    cited commit into the `--sha` of the wrapper command.
  - P10: `git status --porcelain` of the repo is unchanged across the
    suite.
- AC-4.3 (live host smoke; this host has no `oci`):
  `PATH=/usr/bin:/bin bash $P/preflight.sh; echo rc=$?` prints a line
  `check oci=missing` and ends with `rc=3`, provided `oci` is absent from
  `/usr/bin:/bin`. If the host gains `oci`, this criterion is replaced by
  AC-4.2 P1 alone, and the reviewer notes the fact.
- AC-4.4: `grep -c 'preflight.sh' $P/README.md` is at least 1.
- AC-4.5: AC-1.12 holds, with N counting `preflight.test.sh`.
- AC-4.6: `bash $P/tests/run-all.sh` leaves the AC-1.15 `cmp` clean.
- AC-4.7: path scope as in AC-1.14, for this unit's range.
- AC-4.8: `bash tests/validate.sh` exits 0 (chunked runs allowed).

## Open Questions

None blocking. Named assumptions the operator can override before or
during dispatch:
1. D-H: the model is `claude-haiku-4-5` (from CHK7). Override: name another
   model and only AC-3.1's string changes.
2. D-G: `validate.sh` stays untouched (from CHK8). Override: wiring
   `run-all.sh` into `validate.sh` would be a follow-up with its own P5
   rationale and would add about 10 s.

## Out of scope

- ocig-5. Any cloud or API call. `humanReviewMode` changes.
- Running Step 4 (operator-run).
- Deferred ocig-1 and ocig-1b code notes:
  - T5b does not assert the stub ran, and T8 does not assert the allow
    line;
  - the `export -f` BASH_FUNC leak through `exec`;
  - the "ok then FAIL" output ordering;
  - T9's unrestored global.
- Scrubbing the verdict vocabulary out of journal cells (D-A).

## Self-check

- CHK1: Does every Goal-table clause map to a runnable criterion? — PASS
- CHK2: Is the formatter's behaviour defined for 0-byte, `.calls`-less,
  dangling-symlink and malformed journals? — PASS (D-B; AC-1.6, AC-1.7)
- CHK3: Do D-D and AC-1.7 agree on a dangling symlink under
  `--allow-absent`? — PASS (both say invalid, non-zero)
- CHK4: Do AC-1.3, AC-1.4 and the parent AC1.3/AC1.4 conflict on the
  mutant count? — FAIL (conflicting) — revised in place: AC-1.3 and
  AC-1.4 supersede them at 6, and D-F names R7.
- CHK5: Is J9b's fix shown to be non-vacuous? — FAIL (missing) — revised
  in place: AC-1.11 added.
- CHK6: Is the AC1.6 range ambiguity resolved for every new unit? — PASS
  (AC-1.14 and siblings use the unit's own commits; parent A2)
- CHK7: Is the cheaper model named, with a fallback for a refused model?
  — FAIL (ambiguous) — converted to Open Question 1 (assumption, default
  given)
- CHK8: Is the decision on `validate.sh` scope stated with a criterion that
  enforces it? — FAIL (missing) — revised in place: AC-1.13 asserts
  no diff to `tests/validate.sh`. The scope choice is recorded as Open
  Question 2.
- CHK9: Does each stamped edit carry the bump, CHANGELOG, `--update`
  regeneration and P4 checks? — PASS (AC-2.3 to AC-2.7)
- CHK10: Do the phrase-greps survive hard line wrapping? — PASS (AC-2.1
  and AC-2.2 flatten with `tr -s '\n' ' '`)
- CHK11: Is it defined that preflight never calls the network or `--cloud`?
  — PASS (AC-4.2 P7, P8)
- CHK12: Does every criterion that depends on the host say so? — PASS
  (AC-4.3 states its precondition)

Ubiquitous-language prose check (advisory), against CONTEXT.md:
- Lens 1 (a glossary term used with another meaning): none. "external run
  journal" is used as the glossary defines it.
- Lens 2 (a new synonym): none.
- Lens 3 (an undefined load-bearing term): "preflight" and "token usage
  report" are prototype tooling, not domain terms, so no glossary entry is
  suggested.

## Scribe update hint

- After ocigf-2: CHANGELOG is handled in-unit. No glossary change.
- After ocigf-4: the trial runbook README is the canonical operator doc.
  If scribe keeps a wiki page for the trial, link `preflight.sh` and
  `run-all.sh` from it.

## Dispatch contracts (fast path; 4 units)

Retrieval for all units: read this file,
`docs/plans/2026-10-05-outcomeci-followups.md`, the named Step section and
the Context decisions D-A to D-J. Read the parent
`docs/plans/2026-10-05-outcomeci-series-gate-trial.md` Steps 1-3 and its
"Post-PASS amendments" for the existing contracts. No tracker issue exists.

### Unit: ocigf-1 (Suggested model: opus; not stamped)
## Objective
Harden the prototype formatter, checker, snapshot and wrapper, and add a
single suite runner (Step 1).
## Retrieval
This file, Step 1 and D-A to D-G; the ocig-1, ocig-2 and ocig-3 `.pass`
notes in the review-marker directory (read-only).
## Affected files
The Step 1 list. Nothing else.
## Ordered edits
1. Make the five run-id cases of AC-1.8 and the D-B rows of AC-1.6 red in
   the suites. Then fix `journal-evidence.sh` (D-A, D-B, D-C) and
   `check-journal.sh` (D-C, D-D).
2. `state-snapshot.sh`: D-E, plus S6, S6b and S6c.
3. J9b: make it robust to unrelated stderr, for example by running the
   inner call under `LC_ALL=C`. Confirm AC-1.10 and AC-1.11.
4. `oci-series-gate.sh`: a single read plus R7 (D-F), and T10. Update
   `mutation-proof.sh` to R2-R7 and pin 6.
5. `tests/run-all.sh` (D-G) and its README line.
6. Run AC-1.1 to AC-1.16 and commit by explicit path.
## Do NOT touch
`tests/validate.sh`; anything outside `prototype/outcomeci-series-gate/`;
`hooks/`; the review-marker directory.
## Acceptance criteria
AC-1.1 to AC-1.16, as written in Step 1.
## Pre-resolved context
- `mutation-proof.sh` places the copy at `$work/prototype/outcomeci-series-gate/`
  with `$work/hooks` symlinked to the real hooks. T10 needs its own tree
  with stub helpers, built the same way, using `$SERIES_GATE_BIN` as the
  wrapper copy.
- The AC-1.10 locale reproducer is verified red at `adf4427`.
- validate.sh takes about 664 s, so chunk it (R1).
## Escalation
If R7 cannot be killed by a T10 that leaves the other cases green, stop
and report. Do not weaken D-F.

### Unit: ocigf-2 (Suggested model: opus; STAMPED: version bump + CHANGELOG + `--update`)
## Objective
Align `agents/orchestrator.md` with `agents/reviewer.md`: the journal re-read
is optional. Correct the 0.31.121 overclaim in a new CHANGELOG entry (Step 2).
## Retrieval
This file, Step 2; the `efeaed7` and `d5b7510` diffs as footprint
precedent.
## Affected files
The Step 2 list, plus the regenerated `--update` footprint.
## Ordered edits
1. Edit the orchestrator sentence as specified.
2. Bump both manifests (current patch + 1).
3. Add the CHANGELOG entry.
4. Run `node bin/cli.js --update`.
5. Check `git status`, then stage (R3) and commit once.
6. Run AC-2.1 to AC-2.10.
## Do NOT touch
`agents/reviewer.md`; `hooks/`; `templates/`; `adapters/`;
`prototype/`; the 0.31.121 CHANGELOG entry.
## Acceptance criteria
AC-2.1 to AC-2.10, as written in Step 2.
## Pre-resolved context
- The hand-sync grep is empty (verified 2026-10-05).
- The integrity gate refuses commands that name the persona config, so use
  `git add -A` after verifying the footprint.
## Escalation
If `--update` produces paths outside the AC-2.9 pattern, stop and report.

### Unit: ocigf-3 (Suggested model: sonnet; not stamped)
## Objective
Switch the trial's summarize step to `claude-haiku-4-5`, and add
`token-usage.sh` with its suite and the README operator checks (Step 3).
## Retrieval
This file, Step 3, D-H and D-I.
## Affected files
The Step 3 list.
## Ordered edits
1. Write the suite first (U1-U9 red).
2. Implement `token-usage.sh` with `# CHECK:CAP`.
3. Change the model line.
4. Update the README (AC4.5, AC4.6, the D-H fallback, the UNVERIFIED note).
5. Run AC-3.1 to AC-3.9 and commit by explicit path.
## Do NOT touch
`oci-series-gate.sh`; `check-journal.sh`; `journal-evidence.sh`;
`state-snapshot.sh`; anything outside `prototype/outcomeci-series-gate/`.
## Acceptance criteria
AC-3.1 to AC-3.9, as written in Step 3.
## Pre-resolved context
The `usage.json` record fields are verified from the sdist (Context). The
runner passes the model through unvalidated.
## Escalation
If `oci` is somehow available and `oci validate` rejects the model, stop
and report.

### Unit: ocigf-4 (Suggested model: sonnet; not stamped)
## Objective
A host-only Step 4 preflight that checks the tools, `oci` and its version,
`oci validate`, Docker and the token, then prints the next commands
(Step 4).
## Retrieval
This file, Step 4 and D-J; the parent's Step 4 and README runbook.
## Affected files
The Step 4 list.
## Ordered edits
1. Write the suite with PATH stubs (P1-P10 red).
2. Implement `preflight.sh`. `oci validate` runs on a `mktemp -d` copy of
   `workflow/`.
3. Add README step 0.
4. Run AC-4.1 to AC-4.8 and commit by explicit path.
## Do NOT touch
Any other prototype script. Do not install `oci`.
## Acceptance criteria
AC-4.1 to AC-4.8, as written in Step 4.
## Pre-resolved context
- `oci` is not installed on this host.
- `oci --version` prints `oci <ver>`.
- `oci validate --dir D` prints `{"valid": true, ...}`.
## Escalation
If a check cannot be done host-only, drop it to a printed manual step and
report. Never add a network call.
