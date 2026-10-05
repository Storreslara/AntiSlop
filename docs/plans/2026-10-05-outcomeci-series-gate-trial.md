# OutcomeCI "Design A: series gate" local-only trial (2026-10-05)

Status: FINAL (2026-10-05). All 4 Open Questions were answered by the human
and are recorded under "Resolved decisions". Author: spec-master. Path: fast
path, 3 dispatchable units (`ocig-1`, `ocig-2`, `ocig-3`), plus one
operator-run step (Step 4). A 4th unit, `ocig-5`, is dispatched only if the
Phase 1 gate fires.

## Goal

Run a local-only trial of Design A. In Design A, an OutcomeCI workflow run
that could externalize (push, PR, issue-close, Slack) may start only after
the AntiSlop reviewer has written a valid PASS marker for the unit. That
marker's cited commit must also be the commit being externalized. The two
authorities stay separate:

- The reviewer stays the only authority for "done" (PASS marker).
- OutcomeCI policy review is the authority only for "may this leave the
  machine" (`allow` / `revise` / `deny`).
- A policy decision is never mapped to PASS / FAIL / INSUFFICIENT-CONTEXT /
  ESCALATE-TO-HUMAN, and it never uses up a 2-FAIL-cap slot.

Phase 0 builds this with no OutcomeCI patch. It uses an **externalization
precondition wrapper**: a host-side script. It verifies the marker, and only
then `exec`s `oci`. Phase 1 is a patched OutcomeCI fork in a directory
outside this repo. It is optional and has its own decision gate. Companion C
attaches the OutcomeCI broker journal to the reviewer dispatch as
non-authoritative evidence only.

Goal clause to criterion map (so no Goal clause ships without a check):

| Goal clause | Checked by |
|---|---|
| wrapper refuses missing / invalid / SHA-mismatched marker before `oci` runs | Step 1 AC1.2–AC1.4 |
| wrapper allows a valid marker | Step 1 AC1.2 (T7, T8) |
| read-only first workflow, no grants / connections / cloud | Step 2 AC2.4; Step 4 AC4.1 |
| journal records every call with a status | Step 2 AC2.3; Step 4 AC4.3 |
| nothing writes marker / flag / human-review paths | Step 1 AC1.5; Step 2 AC2.2; Step 4 AC4.2 |
| journal shown to the reviewer as non-authoritative | Step 3 AC3.1–AC3.3 |
| policy decisions never rendered as verdicts | Step 3 AC3.2 |
| Phase 1 optional and kept separate | Step 5 entry condition + AC5.1 |

## Context

### Verified facts (re-verified 2026-10-05 against the sdist at the scratchpad path below)

Sdist root:
`/tmp/claude-1000/-home-sebas-AntiSlop/55830157-947f-4638-838a-3b2d1e64e965/scratchpad/outcomeci_cli-0.50.1`
(this path is scratch storage; anything a unit depends on is restated here).

- **F1. Steps cannot run local commands.** `src/outcomeci/v1.py:37`
  `STEP_FIELDS` allows only the `agent` / `await` / `converse` kinds, and
  none of them has a command field. If an agent step "reads" a marker, an
  LLM does the reading, so it is not deterministic. This is why the
  Q1 answer ("a step should run marker-verify as a precondition; patch it if
  not") lands in Phase 1, while Phase 0 does the check outside the run.
- **F2. Local runs execute inside a container.** README "Run a workflow":
  `oci workflow run` runs inside the runner container and needs Docker. The
  default image is `ghcr.io/outcomeci/outcome-runner:<cli version>`
  (`workflow_run.py:56,694`). `--image` overrides it (`cli.py:256`).
  `Dockerfile.runner` builds the CLI from `src` into the image. **So a
  patched host install does not change the broker that runs.** A Phase 1
  fork must also build and pass its own runner image. That is consistent
  with the README, but nobody has run it yet.
- **F3. Journal location and status values.**
  `.outcomeci/.broker/<run>/journal.json` sits under `--dir` (README;
  `local.py:189`). Each call carries `status` in {`reviewing`, `pending`,
  `confirmed`, `denied`, `unsent`, `uncertain`} (`policy.py:446,529,538,597,611`).
  A policy review records `call.review.decision` in {`allow`, `revise`,
  `deny`} (`policy.py` ~508). Denials also append a `permission.denied`
  event (`policy.py:262`).
- **F4. Not every call is journaled.** `PolicyExecutor.execute`
  (`policy.py:359`) returns early, before any journal write, when the step has
  no inline `policy` **and** the integration has no `max_requests`. v1
  compiles `max_requests` from the connector contract
  (`v1.py:458`), so v1 API calls are journaled whenever that contract
  value is non-zero. The connectors source was not read, so the contract
  values are unverified (see R5).
- **F5. A workflow with zero APIs is legal.** An API binding with no `auth`
  is legal only for a keyless connector (`v1.py:436-441`, auth kind
  `none`). Which connectors are keyless is unknown (connectors source
  unread). With no `apis`, no broker call happens, so `journal.json` is
  empty or absent. **This makes the "journal records every call" check
  vacuous** (resolved by D3: accepted and stated).
- **F6. The agent sandbox cannot reach the journal.** `process.py:284-300`
  mounts a tmpfs over each `outcomes/*/.broker`, so the agent cannot read or
  forge the journal. This is the property Companion C's evidence value
  depends on.
- **F7. Phase 1 patch point.** The patch would go in
  `PolicyExecutor.execute`, after the budget check (`policy.py:431-439`) and
  before the call record and the review (`policy.py` ~440-480). The deny
  path is `self._deny(state, step, capability, msg)` followed by
  `raise IntegrationError(..., category="policy")`. This matches the brief's
  estimate.
- **F8. AntiSlop marker tooling already exists. Compose it, don't
  re-implement it.**
  - `hooks/scripts/marker-commit-check.sh` prints
    `marker-commit-check=<ok|mismatch|unverifiable>`, always exits 0, and
    reports whether the cited commit belongs to the unit.
  - `hooks/scripts/marker-verify.sh <id> <dir> --execute` re-runs the
    marker's `criteria:` in a throwaway worktree at the cited commit. It
    prints `marker-verify=<ok|mismatch|unverifiable>` and always exits 0.
    Its header (lines 7-9) says it "MUST NEVER be registered in any hook".
    The wrapper is not a hook registration, so it stays within that rule.
    It does inherit the reason behind it, though: `--execute` `eval`s
    whatever text the marker's criteria field holds (R1).
- **F9. Where the marker state lives.** `hooks/scripts/lib/state-access.sh`:
  `.claude/reviewed/<id>.<ext>` (:36), `.claude/.review-join.<id>` (:82),
  `.claude/.pending-review.<agent>` and `.pending-review-cleared.<agent>`
  (:111,:133), `.claude/wip-handoff.<agent>` (:181), plus
  `.claude/human-review/`.
- **F10. `prototype/` is excluded from the shipped package**
  (`tests/validate.sh:107`, package.json `files`). It also has precedent
  (`prototype/protocol-mcp/`), and `version-stamp-check.sh:61,92` does not
  stamp it. **So Steps 1-3a carry no P3 obligation.** Only Step 3b
  (persona text) does.
- **F11. Where the Companion C text would go** (explorer, grep-fallback;
  each claim re-verified by direct read):
  - `agents/orchestrator.md:171-177` holds the "explicitly
    **non-authoritative** inputs" paragraph of the reviewer dispatch.
  - `agents/reviewer.md:81-85` holds the "advisory review packet is a
    starting hint, not a source of truth" bullet.
  - Neither passage has a copy in `adapters/codex/` or `adapters/cursor/`
    (a grep for `non-authoritative` and `starting hint` there returned 0).
    **So no hand-sync to the adapters is needed.**
  - `.claude/agents/{orchestrator,reviewer}.md` are generated copies, and
    `node bin/cli.js --update` refreshes them.
  - `tests/adapter-protocol-parity.test.js` asserts neither passage.

### Premise corrections to the brief

- **PC1.** The brief says `outcomeci-connectors` 0.10.0. But `outcomeci-cli`
  0.50.1 pins `outcomeci-connectors>=0.8,<0.9` (`pyproject.toml:19`). The
  trial therefore runs connectors **0.8.x**, and 0.10.0's license and
  behaviour are irrelevant to it. The licensing check applies to the 0.8.x
  that pip actually resolves.
- **PC2.** "Marker SHA == pushed SHA" conflicts with how this repo works.
  The marker's `commit:` is the unit's own final commit, never HEAD at the
  time the marker is written. Scribe and agent-memory commits routinely
  land after it (for example, HEAD `af604ab` is a `memory(scribe)` commit
  that follows `3ddfa45`, the poc-1 fix). So strict equality against HEAD
  will refuse in the common case. Resolved by D1.
- **PC3.** A read-only trial never exercises OutcomeCI's LLM policy review.
  `_review` runs only for calls that have a side effect (`policy.py:160-161`
  docstring; reads skip review). So Phase 0 proves the precondition
  mechanics and the journal plumbing. It does **not** prove that
  `allow` / `revise` / `deny` behaves as Design A assumes. That proof needs
  a write grant, which this trial excludes.
- **PC4.** "Gate" in this design's name drifts from the glossary. In
  CONTEXT.md, `Gate` means a hook script that mechanically blocks an action.
  The wrapper is not a hook, and an operator can bypass it by calling `oci`
  directly. This doc uses "Design A (series gate)" only as the design's
  name. It calls the artifact the **externalization precondition wrapper**
  and never just "gate" (see Scribe update hint).

### Prior FAIL history and advisory-note sweep

- **Every** `.fail` record was enumerated with `grep -r -l --include=*.fail
  CHANGELOG`: 56 records cite a missing CHANGELOG entry or version bump.
  These include `reviewer-changes-examples-lean-2.fail`, the four-copy
  reviewer edit. Its measured mechanism is that `bin/cli.js` sets
  `needsRender` from a stamp check only, so a stamped persona edit without a
  bump never reaches `--update`. **Disposition:** Step 3b carries explicit
  per-commit P3 criteria (AC3b.2, AC3b.3) and the bump-before-`--update`
  order. Any unit touching `agents/*.md` must not be tagged below sonnet.
- `bin/marker-audit.sh . --notes --surface=` was run for
  `agents/reviewer.md` (70 notes, untagged or historical) and
  `agents/orchestrator.md`. The only note still relevant comes from unit
  125/137: constitution P4 (optional personas degrade gracefully) flagged
  unconditional `reviewer` mentions. **Disposition:** AC3b.4 requires
  conditional phrasing for any new `reviewer` mention.
- No `NOTE[spec]` lines were returned for `prototype/` or
  `hooks/scripts/marker-verify.sh` in the portion that ran. The sweep is
  best-effort and ran long, so its absence here does not prove no note
  exists.
- A ticket-style grep for an existing deliverable (`git grep -i
  "outcomeci\|series gate\|externaliz"`) returned 0 hits. Nothing like this
  exists yet.

### Named assumptions

- **A1.** The first real externalization would be scribe's `gh issue close`
  (the brief's default proposal). It is **not exercised** in this trial,
  because the trial is read-only. It is recorded for the follow-up spec
  that adds a write grant.
- **A2.** The trial `--dir` (`$OCI_TRIAL_DIR`) is a directory **outside**
  this repo with no `.claude/` in it. The container then cannot see
  AntiSlop's markers, flags, or hooks at all. It also keeps the image's
  in-container Claude Code (2.1.280, `Dockerfile.runner`) from loading
  AntiSlop's `.claude/settings.json` hooks.
- **A3.** The wrapper considers only `.pass`. A unit holding only
  `.escalated` or `.directed`, or nothing at all, is refused. Under
  `reviewGating.mode=off` no markers are written, so the wrapper refuses
  every unit. That is acceptable for a trial and is documented in the
  runbook.
- **A4.** The trial is capped at 3 live runs. Each one uses the
  `CLAUDE_CODE_OAUTH_TOKEN` subscription.
- **A5.** CONTEXT.md is not edited by this spec (brief boundary). This
  overrides `domain-modeling`'s "update CONTEXT.md inline". The new terms
  are handed to scribe instead (Scribe update hint).
- **ADR:** none now. "Policy review is authoritative only for
  externalization, never for done" meets the three ADR tests only if the
  trial graduates out of `prototype/`. Re-evaluate at that point.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Missing
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-05 Functional scope & success criteria: Q Is scribe's `gh issue
  close` the first gated externalization, and does that matter for this
  trial? → A (self-resolved): default proposal accepted as A1. It does not
  matter here, because the trial is read-only and externalizes nothing.
- 2026-10-05 Functional scope & success criteria: Q What makes the wrapper
  "insufficient", the condition that opens Phase 1? → A (self-resolved):
  three named, reproducible insufficiencies I1–I3 plus explicit human
  approval (Step 5). No automatic trigger.
- 2026-10-05 Domain entities / data model: Q How must the marker's cited
  commit relate to the commit being externalized? → A (human, D1): exact
  full-SHA equality with `--sha`, where `--sha` defaults to HEAD. The
  operator passes `--sha <unit commit>` explicitly when later doc or memory
  commits exist.
- 2026-10-05 User interaction flow: Q Who installs OutcomeCI, pulls the
  image, and performs the live runs? → A (human, D2): the human operator,
  following the Step 4 runbook. Agents build and test the tooling offline
  only, with a stub `oci`.
- 2026-10-05 Non-functional attributes (perf, security, scale): Q Should the
  wrapper run `marker-verify.sh --execute`, which `eval`s marker text? → A
  (self-resolved): yes, per the human's Q1 answer ("run marker-verify as
  precondition"). It runs last, after the cheap structural checks. The
  execution risk is recorded as R1.
- 2026-10-05 External dependencies & integrations: Q Which API does the
  read-only workflow call, given that no GitHub or Slack connection is
  allowed? → A (human, D3): zero APIs. The journal check runs with
  `--allow-absent`, and the trial report states that the check is vacuous.
- 2026-10-05 External dependencies & integrations: Q Which connectors
  version is in play? → A (self-resolved): 0.8.x, as pinned by the CLI
  (PC1).
- 2026-10-05 Edge cases / failure handling: Q What happens with `commit:
  none`, a short SHA, a marker whose criteria fail on re-run, an `oci`
  non-zero exit, or `reviewGating.mode=off`? → A (self-resolved): defined
  in the Step 1 refusal table and A3. `oci`'s exit code passes through
  unchanged.
- 2026-10-05 Terminology consistency: Q Is the wrapper a "gate"? → A
  (self-resolved): no. A glossary Gate is a hook script. The artifact is
  named the externalization precondition wrapper (PC4).
- 2026-10-05 Completion / acceptance signals: Q Is "journal records every
  call with status" checkable when the workflow makes zero calls? → A
  (human, D3): only vacuously. That is accepted, and the trial report must
  say so.
- 2026-10-05 Completion / acceptance signals: Q Should Companion C ship as
  persona text now? → A (human, D4): yes, ship Step 3b now. This is not the
  recommended default. The P3 version bump and the CHANGELOG entry land in
  the same commit as the persona edits.

## Risks / dependencies

Residual risks (brief requirement 7):

- **R1. Marker forgery versus LLM policy.**
  - The wrapper trusts whatever sits at `.claude/reviewed/<id>.pass`.
    `reviewed-path-gate.sh` blocks non-reviewer Bash writes there by
    command text. But the gate has known residuals: Write/Edit checks only
    `file_path`, and there are path-obfuscation routes. Its own
    documentation says it is not a cryptographic seal.
  - `--execute` then `eval`s the forged marker's `criteria:`. **So marker
    forgery turns into arbitrary command execution in the wrapper's shell.**
  - The LLM policy review is no backstop. It is prompt-injectable by
    construction: it reads untrusted trigger and API data, and its own
    prompt only asks it to treat that data as untrusted. It is not a
    deterministic check.
  - Mitigations in scope: the wrapper's structural checks run before
    `--execute`, and the commit-attribution check (`marker-commit-check`
    must be `ok`) runs before it too. Not mitigated: an attacker who can
    write a well-formed marker that cites a real unit commit.
- **R2. Cloud boundary.**
  - The wrapper sits on the host. `oci workflow run --cloud` and cloud
    triggers (webhook, email) start runs where no wrapper exists.
  - Whether a cloud runner honours a patched broker is unknown, and is
    likely "no", because cloud runs use OutcomeCI's managed image (F2).
  - The trial forbids `--cloud`. Step 4 AC4.1 checks this in the
    invocation log. Any cloud use needs a new spec.
- **R3. Hook portability.**
  - AntiSlop's own enforcement (reviewed-path-gate, stop-gate, the
    reviewer `agent_type` grants) keys on Claude Code's hook payload
    `agent_type`.
  - Inside the runner container, agents run as Codex, Claude Code 2.1.280,
    or OpenCode, and none of them carries AntiSlop's hooks (A2).
  - So nothing inside an OutcomeCI run is covered by AntiSlop gates. The
    wrapper and the marker are the only coupling.
- **R4. Licensing hygiene.**
  - The sdist declares `License: Apache-2.0` (PKG-INFO; `pyproject.toml:11`)
    but ships **no LICENSE file**.
  - The connectors license (0.8.x, PC1) is unconfirmed.
  - Rules for the trial:
    - Never copy OutcomeCI code into this MIT repo (not even `prototype/`).
    - A Phase 1 fork lives outside the repo (Step 5).
    - Before any redistribution of the fork (a public push), add the
      Apache-2.0 text, keep any NOTICE, and mark the modified files
      (Apache-2.0 §4).
    - Confirm the connectors license before patching or redistributing it.
- **R5. Unverified connector contract.** `max_requests` per connector and
  which connectors are keyless are unknown (F4, F5). This shaped D3 and
  whether a non-zero-API workflow's calls are journaled at all.
- **R6. Cost.**
  - Each live run consumes the Claude subscription through
    `CLAUDE_CODE_OAUTH_TOKEN` inside the container.
  - The `--execute` re-run costs whatever the marker's criteria cost (some
    units' criteria run `tests/validate.sh`).
  - Capped by A4 (at most 3 runs). Step 4 records each run's duration.
- **R7. Time-of-check versus time-of-use.** The wrapper verifies the marker
  and then `exec`s `oci`. Nothing binds the run's later actions to the
  verified SHA. This is harmless while the trial is read-only. It is
  insufficiency I2 for Phase 1.
- **R8. Concurrent sessions.** Another session may legitimately write
  markers or flags during a live run, and Step 4's before/after state
  snapshot would then show a diff. Mitigation: run the trial when no unit is
  mid-review. A diff is reported to the human, never auto-attributed to
  OutcomeCI.

Dependencies:

- Docker, `pipx`, `jq`, and `python3` are present on the host (checked
  2026-10-05 with `command -v`). OutcomeCI is not installed.
- The runner image is pulled from ghcr.io. That is network access but no
  signup.

Non-goals (brief requirement 5):

- No change to:
  - reviewer verdict logic;
  - any marker format, `.fail` record, or review-join stamp;
  - the 2-FAIL cap;
  - any hook, `hooks/hooks.json`, or the hooks' fail-open behaviour.
- No mapping of policy decisions onto verdicts. The wrapper's exit codes
  and the Step 3 formatter never print the verdict words.
- Design B (policy text compiled from artifacts) is deferred.
- No cloud signup, no `--cloud`, no GitHub or Slack connection, no write
  grant.

## Constitution check (.claude/constitution.md v1.1.0)

- P1 "Verify, don't assume": satisfied. Every step has runnable criteria.
  Step 1 adds a mutation proof so the refusal tests are shown to be
  non-vacuous.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied.
  Phase 0 exists to replace an LLM-mediated marker read (F1) with a
  deterministic host script. Step 3b regenerates the `.claude/agents/`
  copies with `node bin/cli.js --update` and never hand-edits them.
- P3 "Version-stamp discipline": satisfied.
  - Steps 1, 2 and 3a touch only `prototype/`, which is not stamped (F10),
    and AC1.6 / AC2.5 / AC3.4 assert that.
  - Step 3b (approved, D4) touches `agents/orchestrator.md` and
    `agents/reviewer.md`. It bumps `.claude-plugin/plugin.json` and
    `package.json` and adds a CHANGELOG entry **in the same commit**
    (AC3b.2, AC3b.3).
- P4 "Optional personas degrade gracefully": satisfied. Any new `reviewer`
  mention in Step 3b prose is conditionally phrased (AC3b.4).
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit's
  criteria end with `bash tests/validate.sh` exiting 0.

## Step 1 (unit `ocig-1`): externalization precondition wrapper (Phase 0)

Affected files (all new):
- `prototype/outcomeci-series-gate/oci-series-gate.sh`
- `prototype/outcomeci-series-gate/tests/series-gate.test.sh`
- `prototype/outcomeci-series-gate/tests/mutation-proof.sh`

Interface:
`oci-series-gate.sh --unit <task-id> [--project-dir <dir>] [--sha <rev>] -- <args for oci>`.
`--project-dir` defaults to the repo root that contains the script. `--sha`
defaults to `HEAD` of `--project-dir`. AntiSlop helper scripts are resolved
relative to the wrapper's own location (`../../hooks/scripts/`).

Checks run in this order, cheapest first. The first failure refuses. Every
refusal prints exactly one stderr line, `series-gate=refuse unit=<id>
reason=<r>`, and exits **without ever invoking `oci`**:

| # | Check | Exit | reason |
|---|---|---|---|
| R1 | `--unit` present, `--` separator present | 64 | `usage` |
| R2 | `<project>/.claude/reviewed/<id>.pass` exists and is non-empty | 65 | `marker-missing` |
| R3 | line 1 matches `^PASS <id> [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z commit: [0-9a-f]{7,40} criteria: .+$` (so `commit: none` is refused) | 66 | `marker-invalid` |
| R4 | `marker-commit-check.sh <id> <project>` prints `marker-commit-check=ok` | 67 | `commit-attribution` |
| R5 | per D1 (`git rev-parse --verify <cited>^{commit}` == `git rev-parse --verify <--sha>^{commit}`, full SHAs) | 68 | `sha-mismatch` |
| R6 | `marker-verify.sh <id> <project> --execute` prints `marker-verify=ok` | 69 | `criteria-mismatch` or `criteria-unverifiable` |

If all checks pass, the wrapper prints `series-gate=allow unit=<id>
commit=<full-sha>` to stderr, then `exec oci "$@"`, so `oci`'s exit code
passes through unchanged. The wrapper writes no file of its own anywhere.
Each guard line carries the trailing sentinel comment `# CHECK:R<n>`, which
the mutation proof targets.

The test suite builds every fixture in `mktemp -d`: a throwaway git repo
with fixture `.pass` markers inside **the fixture's own** `.claude/`, plus a
stub `oci` prepended to `PATH` that appends its argv to `$STUB_LOG` and
exits `$STUB_RC` (default 0). The suite runs the wrapper path given in
`$SERIES_GATE_BIN` (default: the real wrapper). Cases:
- T1: no `--unit` gives 64.
- T2: no marker gives 65.
- T3: malformed line 1 gives 66.
- T3b: `commit: none` gives 66.
- T4: the cited commit's message does not reference the id and there are no
  candidates, which gives 67.
- T5: HEAD has advanced one commit past the cited commit and `--sha` is
  omitted, which gives 68.
- T5b: the same repo with `--sha <cited>` is allowed.
- T6: `criteria: false` gives 69.
- T7: a valid marker gives 0, and `$STUB_LOG` contains `workflow run`.
- T8: valid marker with `STUB_RC=7` gives 7.

In T1–T6, `$STUB_LOG` must not exist. The suite ends by printing
`failures=<n>` and exits non-zero iff n>0.

Acceptance criteria:
- AC1.1:
  `bash -n prototype/outcomeci-series-gate/oci-series-gate.sh && bash -n prototype/outcomeci-series-gate/tests/series-gate.test.sh && bash -n prototype/outcomeci-series-gate/tests/mutation-proof.sh`
  exits 0.
- AC1.2:
  `bash prototype/outcomeci-series-gate/tests/series-gate.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0.
- AC1.3:
  `bash prototype/outcomeci-series-gate/tests/mutation-proof.sh | tail -1 | grep -qx 'mutants=5 killed=5'`
  exits 0. The proof disables each of the R2–R6 guards in turn in a temp
  copy (it replaces the `# CHECK:R<n>` line with `:`), runs the suite
  against the copy, and counts a mutant as killed iff the suite exits
  non-zero.
- AC1.4:
  `grep -c '# CHECK:R[2-6]$' prototype/outcomeci-series-gate/oci-series-gate.sh`
  prints `5`.
- AC1.5: `git status --porcelain -- .claude` gives byte-identical output
  before and after running AC1.2. The lead captures both outputs, and the
  reviewer re-runs the same comparison.
- AC1.6:
  `git diff --name-only <base>..HEAD | grep -v '^prototype/outcomeci-series-gate/'`
  prints nothing.
- AC1.7: `bash tests/validate.sh` exits 0.

## Step 2 (unit `ocig-2`): read-only workflow, state snapshot, journal checker, runbook

Affected files (all new, under `prototype/outcomeci-series-gate/`):
- `state-snapshot.sh`
- `check-journal.sh`
- `workflow/outcome.yml`
- `workflow/.outcomeci/instructions/summarize.md`
- `README.md` (the runbook)
- `tests/trial-tools.test.sh`

- `state-snapshot.sh <project-dir>`: read-only. It prints sorted
  `<sha256>  <relpath>` lines for every regular file under the project's
  `.claude/reviewed/` and `.claude/human-review/`, plus top-level
  `.claude/.pending-review*`, `.claude/.review-join.*` and
  `.claude/wip-handoff.*` (F9). The last line is `snapshot-files=<n>`.
- `check-journal.sh [--allow-absent] <trial-dir> <run-id>`: uses `jq`. It
  prints one line, `journal=<ok|absent|invalid> calls=<n> bad=<n>`. The
  result is `ok` iff:
  - the file parses;
  - `.calls` is an object;
  - every call has `status` in the terminal set {`confirmed`, `denied`,
    `unsent`, `uncertain`} (F3; `reviewing` or `pending` after a finished
    run counts as bad).

  It exits 0 iff the result is `ok`, or the result is `absent` and
  `--allow-absent` was given.
- `workflow/outcome.yml`: `apiVersion: outcomeci.workflow/v1`,
  `trigger: manual`, one `reasoning.default` (a claude runner), one agent
  step (`reason: summarize.md`, `from: trigger`,
  `returns: {summary: string}`). It has **no** `secrets`, `apis`, `can` or
  `policy` keys (D3).
- `README.md` runbook. The operator steps of Step 4, in order:
  1. Install with `pipx install outcomeci-cli==0.50.1` (note PC1).
  2. Copy `workflow/` into `$OCI_TRIAL_DIR`, which lies outside this repo
     (A2).
  3. Take a "before" snapshot.
  4. Run through the wrapper with `-- workflow run --dir $OCI_TRIAL_DIR`
     (never `--cloud`).
  5. Take an "after" snapshot, then diff and check the journal.
  6. Respect the 3-run cap (A4) and the A3 note.
  7. Read the licensing note (R4).

Acceptance criteria:
- AC2.1: every new `.sh` passes `bash -n`.
- AC2.2:
  `bash prototype/outcomeci-series-gate/tests/trial-tools.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0. Cases:
  - Two snapshots of an unchanged temp project are identical.
  - Adding a fixture file under the temp project's `reviewed/` changes the
    snapshot.
  - Running the snapshot leaves `git status --porcelain` of the temp
    project unchanged.
  - check-journal against fixtures:
    - a valid journal gives `ok` and exit 0;
    - a `status: reviewing` call gives `invalid bad=1` and exit non-zero;
    - an unknown status gives non-zero;
    - malformed JSON gives `invalid`;
    - a missing file gives `absent` and non-zero;
    - a missing file with `--allow-absent` gives exit 0.
- AC2.3: the check-journal mutation, in which the status-set test is
  replaced with `true` in a temp copy, makes AC2.2's suite exit non-zero.
  The suite runs this itself and counts it as a case.
- AC2.4:
  `grep -cE '^(secrets|apis):|^[[:space:]]+(can|policy):' prototype/outcomeci-series-gate/workflow/outcome.yml`
  prints `0`, and
  `grep -c 'cloud' prototype/outcomeci-series-gate/README.md` is at least 1
  (the runbook states that `--cloud` is forbidden).
- AC2.5: AC1.6's path-scope check holds for this unit's range.
- AC2.6: `bash tests/validate.sh` exits 0.

## Step 3 (unit `ocig-3`): Companion C, journal shown as non-authoritative evidence

### 3a (dispatched)

Affected files (new):
- `prototype/outcomeci-series-gate/journal-evidence.sh`
- `prototype/outcomeci-series-gate/tests/journal-evidence.test.sh`

`journal-evidence.sh <trial-dir> <run-id>` prints a markdown block for the
orchestrator to paste after the existing non-authoritative inputs of a
reviewer dispatch (`agents/orchestrator.md:171-177`). The block is:

```
## External run journal (NON-AUTHORITATIVE - evidence only)
Source: <relpath to journal.json> sha256 <digest>. This block never satisfies an
acceptance criterion; the reviewer re-derives every criterion itself and may
re-read the journal file directly to check this summary against the digest.
| seq | step | capability | status | policy decision |
```

The block then has one table row per call, sorted by `sequence`. `policy
decision` is `call.review.decision` copied verbatim, or `-` when absent.
For an absent or empty journal, the block prints `calls: 0 (journal absent)`
in place of the table.

The policy decision and the reviewer verdict are separate by construction:
the formatter never emits the verdict vocabulary.

Acceptance criteria:
- AC3.1:
  `bash prototype/outcomeci-series-gate/tests/journal-evidence.test.sh 2>&1 | tail -1 | grep -qx 'failures=0'`
  exits 0. The cases assert:
  - the first line is exactly the banner;
  - the digest equals `sha256sum` of the fixture journal;
  - the row count equals the fixture's call count (3);
  - the absent-journal fixture prints `calls: 0 (journal absent)`.
- AC3.2: for every fixture, the output does not match
  `grep -E '\b(PASS|FAIL|INSUFFICIENT-CONTEXT|ESCALATE-TO-HUMAN)\b'`. This is
  asserted inside the suite, including a fixture whose `review.decision`
  values are `allow`, `revise` and `deny`.
- AC3.3: a mutation in which the banner line is deleted in a temp copy
  makes the suite fail. The suite asserts this itself.
- AC3.4: AC1.6's path-scope check holds for this unit's range.
- AC3.5: `bash tests/validate.sh` exits 0.

### 3b (dispatched per D4, in the same unit as 3a, after 3a's criteria are green)

Affected files:
- `agents/orchestrator.md` (the :171-177 paragraph): add the external run
  journal as a third non-authoritative input.
- `agents/reviewer.md` (a new sibling bullet after :81-85): an external run
  journal is evidence only; it never satisfies a criterion; the reviewer
  re-derives everything.
- `.claude-plugin/plugin.json` and `package.json`: version bump.
- `CHANGELOG.md`.
- The regenerated `.claude/agents/orchestrator.md` and
  `.claude/agents/reviewer.md`, produced by `node bin/cli.js --update`
  **after** the bump.
- Hand-sync across the template and the codex and cursor copies is
  required only where a copy of an edited passage exists. Re-verified
  2026-10-05: `grep -r -l -i "non-authoritative\|starting hint" templates adapters`
  matches nothing (exit 1). So no template or adapter file is edited.
  AC3b.8 re-checks this at execution time. If the check finds a copy, that
  copy must get the same edit in the same commit.

Acceptance criteria:
- AC3b.1:
  `grep -c 'external run journal' agents/orchestrator.md agents/reviewer.md .claude/agents/orchestrator.md .claude/agents/reviewer.md`
  gives at least 1 in each file.
- AC3b.2:
  `bash hooks/scripts/version-stamp-check.sh <base>..HEAD | grep -q '^version-stamp-check: ok '`
  exits 0.
- AC3b.3: the per-commit CHANGELOG check below exits 0, and
  `jq -r .version .claude-plugin/plugin.json` equals `jq -r .version package.json`.

  ```
  for c in $(git rev-list <base>..HEAD -- agents templates); do
    git show --name-only --format= "$c" | grep -qx CHANGELOG.md || exit 1
  done
  ```
- AC3b.4: every line added to `agents/orchestrator.md` that mentions the
  reviewer is conditionally phrased. The check below prints `0`.
  `agents/reviewer.md`'s self-references are exempt (P4 concerns other
  personas' prose).

  ```
  git diff <base>..HEAD -- agents/orchestrator.md \
    | grep '^+[^+]' | grep -i 'reviewer' | grep -vic 'if present'
  ```
- AC3b.5: `node bin/cli.js --update` run a second time reports no drift
  (idempotent).
- AC3b.6: `node tests/adapter-protocol-parity.test.js` exits 0, and
  `bash tests/validate.sh` exits 0.
- AC3b.7: `git diff <base>..HEAD --stat -- hooks` prints nothing. No hook
  is changed (non-goal).
- AC3b.8 (hand-sync): the check below exits 0. Any template or adapter copy
  that matches the passage text must also match the new phrase. Today the
  first `grep` matches nothing, so the loop is a no-op.

  ```
  for f in $(grep -r -l -i "non-authoritative\|starting hint" templates adapters); do
    grep -qi 'external run journal' "$f" || exit 1
  done
  ```

## Step 4 (operator-run, not a dispatched unit): live read-only trial

The human runs this after `ocig-1` and `ocig-2` have reached PASS (D2). Pick `<unit>` as any unit with a valid PASS marker whose cited
commit is reachable. For example, `poc-1` cites `3ddfa45`; pass
`--sha 3ddfa45` per D1. Then:

1. `bash prototype/outcomeci-series-gate/state-snapshot.sh . > "$OCI_TRIAL_DIR/before.txt"`
2. `bash prototype/outcomeci-series-gate/oci-series-gate.sh --unit <unit> --sha <sha> -- workflow run --dir "$OCI_TRIAL_DIR" --auto-continue 2> "$OCI_TRIAL_DIR/gate.log"`
3. `bash prototype/outcomeci-series-gate/state-snapshot.sh . > "$OCI_TRIAL_DIR/after.txt"`

Acceptance criteria:
- AC4.1:
  `grep -qx 'series-gate=allow unit=<unit> commit=<full-sha>' "$OCI_TRIAL_DIR/gate.log"`
  succeeds, and `grep -c -- '--cloud' "$OCI_TRIAL_DIR/gate.log"` prints 0.
- AC4.2: `diff "$OCI_TRIAL_DIR/before.txt" "$OCI_TRIAL_DIR/after.txt"`
  exits 0. Any diff goes to the human (R8).
- AC4.3:
  `bash prototype/outcomeci-series-gate/check-journal.sh --allow-absent "$OCI_TRIAL_DIR" <run-id>`
  exits 0. Under D3 the expected line is `journal=absent` or
  `calls=0`, and the trial report must say that the journal check was
  vacuous.
- AC4.4: a negative run with an unreviewed unit id leaves `oci` unexecuted.
  `bash prototype/outcomeci-series-gate/oci-series-gate.sh --unit no-such-unit -- workflow run --dir "$OCI_TRIAL_DIR"; echo rc=$?`
  prints `rc=65`, and no new directory appears under
  `$OCI_TRIAL_DIR/.outcomeci/outcomes/`.

## Step 5 (unit `ocig-5`, OPTIONAL): Phase 1 patched fork, behind a decision gate

**Entry condition (machine-checkable plus a human decision).** This unit is
dispatched only if both of the following hold:

(a) At least one of these insufficiencies has a recorded, reproducible
demonstration:
- **I1:** the externalizing run must start from a non-manual trigger
  (webhook or email), where no host wrapper can sit.
- **I2:** a reproduction exists where the externalized commit differs from
  the wrapper-verified SHA within one run (R7).
- **I3:** one run performs more than one externalization, and each needs
  its own marker binding.

(b) The human approves Phase 1 explicitly. Absent (b), this step is not
dispatched, and that is a valid final state.

Scope sketch (a full spec is re-derived when the gate fires; this is not
dispatch-ready):
- The fork lives at `$HOME/outcomeci-fork/` (outside this repo, with its
  own git history and the Apache-2.0 text added, per R4).
- The patch goes at F7.
  - Before `_review`, for capabilities on a configured externalizing list,
    it reads `<marker-root>/<id>.pass` line 1.
  - It compares the cited commit with the proposal's commit.
  - On mismatch it calls `self._deny(...)` and raises
    `IntegrationError(category="policy")`.
- Running `marker-verify --execute` from inside the broker is out of
  scope, because it needs a new config field and a host command inside the
  container (F2).
- A locally built runner image from `Dockerfile.runner` is passed with
  `--image` (F2).
- **Tension to resolve in that spec.** The broker runs in the container, so
  the marker must be visible inside the container. That conflicts with A2,
  which keeps `.claude/` out of the container. The minimum is a read-only
  bind of one copied marker file, never the repo.

Acceptance criterion:
- AC5.1: `git -C /home/sebas/AntiSlop status --porcelain` shows no path
  under `prototype/` or elsewhere from Phase 1. All Phase 1 artifacts live
  in the fork directory, and `git grep -il outcomeci -- ':!docs/plans' ':!prototype'`
  prints nothing.

## Resolved decisions (human, 2026-10-05; replaces Open Questions)

- **D1 (was OQ1, from CHK1): SHA binding.** Chosen: (a), exact full-SHA
  equality between the marker's cited commit and `--sha`, which defaults to
  HEAD. The operator passes the unit commit explicitly when later doc or
  memory commits exist. This matches Step 1's R5 and T5/T5b as written, so
  no change was needed.
- **D2 (was OQ2, from CHK4): who runs the live trial.** Chosen: (a). The
  human runs Step 4 by hand: pipx install 0.50.1 (connectors 0.8.x), pull
  the ghcr image, and use their own `CLAUDE_CODE_OAUTH_TOKEN`. Agents build
  and test only against a stub `oci`. This matches Steps 1, 2 and 4 as
  written, so no change was needed.
- **D3 (was OQ3, from CHK2): the read-only workflow's API.** Chosen: (a),
  zero APIs. The journal check (AC4.3, `--allow-absent`) is vacuous, and the
  trial report must say so. A real journal check is deferred to the
  follow-up spec that adds a grant. This matches Step 2 and AC4.3 as
  written.
- **D4 (was OQ4, from CHK5): Companion C persona text.** Chosen: (b), ship
  Step 3b now. This is not the recommended default. The P3 bump of
  `.claude-plugin/plugin.json` and `package.json`, plus the CHANGELOG entry,
  land in the same commit as the persona edits (AC3b.2, AC3b.3). Hand-sync
  to the template, codex and cursor copies applies where a copy of the
  edited passage exists. Today none does, and AC3b.8 re-checks this. ocig-3
  is re-tagged opus.

## Self-check

- CHK1: Is the SHA binding rule defined for HEAD advanced past the cited
  commit by later doc or memory commits? FAIL (missing). Converted to Open
  Question 1, resolved as D1.
- CHK2: Is "journal records every call with status" non-vacuous for the
  zero-API default workflow? FAIL (ambiguous). Converted to Open Question 3, resolved as D3.
- CHK3: Do Step 2's runbook, A2 and Step 4 agree that `--dir` is outside
  this repo and has no `.claude/`? PASS.
- CHK4: Is it defined who installs OutcomeCI and performs live runs? FAIL
  (missing). Converted to Open Question 2, resolved as D2.
- CHK5: Is Companion C's persona-edit scope defined, and if it ships, does
  it carry per-commit P3 criteria? FAIL (missing). The P3 half was revised
  in place (AC3b.2/AC3b.3). The scope half was converted to Open Question 4, resolved as D4.
- CHK6: Does every wrapper refusal R2–R6 have both a test case and a
  mutation that kills it? PASS (T2–T6, AC1.3, AC1.4).
- CHK7: Is the Phase 1 trigger machine-checkable rather than "if the wrapper
  seems insufficient"? FAIL (ambiguous). Revised in place (I1–I3 plus
  explicit approval).
- CHK8: Can any dispatched step write into this repo's `.claude/`? PASS
  (AC1.5, AC2.2, AC1.6/AC2.5/AC3.4 path scope).
- CHK9: Do Step 3a's banner and AC3.2 agree that policy decisions are never
  rendered as verdict words? PASS.
- CHK10: Does every Goal clause map to a step criterion? PASS (Goal table).
- CHK11: Does any step rely on a marker-verify exit code, when that script
  always exits 0? FAIL (conflicting, in the first draft). Revised in place:
  R4 and R6 parse the printed state line.

Prose-mode `ubiquitous-language` check (advisory):

- Lens 1: "gate" in "series gate" diverges from the glossary's Gate (a hook
  script). Handled by PC4.
- Lens 2: "marker SHA" is a new synonym for the PASS marker's `commit:`
  field. This doc uses "the marker's cited commit". "Policy verdict" was
  avoided; the doc uses "policy decision".
- Lens 3: these load-bearing new terms are absent from the glossary:
  externalization, externalization precondition wrapper, broker journal,
  policy decision. See the Scribe update hint.

## Dispatch contracts (fast path; final per D1-D4)

### Unit: ocig-1 (Suggested model: opus)
## Objective
Build the Phase 0 externalization precondition wrapper and its test and
mutation suites, exactly per Step 1.
## Retrieval
Read `docs/plans/2026-10-05-outcomeci-series-gate-trial.md` (Context F8-F10,
A3, Step 1). There is no tracker issue (fast path).
## Affected files
The three new files listed in Step 1, only.
## Ordered edits
1. Write `tests/series-gate.test.sh` with the stub `oci` and cases T1-T8
   (TDD red).
2. Write the wrapper, guards R1-R6 in table order, each carrying
   `# CHECK:R<n>`.
3. Write `mutation-proof.sh`.
4. Run AC1.1-AC1.7.
## Do NOT touch
`hooks/` (call `marker-verify.sh` and `marker-commit-check.sh`, never edit
them), `agents/`, `templates/`, `adapters/`, `CONTEXT.md`, the real
`.claude/`, and any marker or flag. Do not install OutcomeCI or run a real
`oci`.
## Acceptance criteria
AC1.1-AC1.7 as written in Step 1.
## Pre-resolved context
- `marker-verify.sh` and `marker-commit-check.sh` always exit 0. Parse their
  single output line.
- `marker-verify.sh` sources `lib/state-access.sh` relative to itself and
  takes the project dir as an argument, so a temp fixture project works.
- **Author the test files with the Write tool, not Bash heredocs.**
  `reviewed-path-gate.sh` blocks Bash command text that spells the
  `.claude/reviewed` path. Write/Edit check only `file_path`.
- Build fixture paths in the scripts from parts (for example
  `"$fx/.claude/$rv"`) so that your own Bash invocations never spell the
  path.
## Escalation
If R4 cannot be satisfied by a fixture commit whose message names the unit
id, or if the gate blocks running the suite, stop. Report with the
`STATUS: incomplete` line and do not work around the gate.

### Unit: ocig-2 (Suggested model: sonnet)
## Objective
Build the read-only trial tooling, workflow, and runbook per Step 2.
## Retrieval
Read the same plan doc: F3, F5, F9, A2-A4, R4, Step 2, Step 4.
## Affected files
The six new files listed in Step 2, only.
## Ordered edits
1. Write `tests/trial-tools.test.sh` (red).
2. Write `state-snapshot.sh`.
3. Write `check-journal.sh`.
4. Write `workflow/outcome.yml` and `summarize.md`.
5. Write `README.md`, with the runbook steps in Step 4's order.
6. Run AC2.1-AC2.6.
## Do NOT touch
The same list as ocig-1, plus `oci-series-gate.sh` (owned by ocig-1).
## Acceptance criteria
AC2.1-AC2.6.
## Pre-resolved context
- The journal schema is in F3: `.calls` is an object keyed by fingerprint,
  each call has a `status`, and `review.decision` is optional.
- `jq` is at `~/.local/bin/jq`.
- Snapshot only regular files, and sort by relpath with `LC_ALL=C`.
## Escalation
If the workflow v1 schema rejects a zero-API workflow when the human later
runs `oci validate`, stop. That is not a unit defect: route it back to
spec-master (it bears on D3).

### Unit: ocig-3 (Suggested model: opus; D4 puts stamped persona edits in scope, and 56 FAIL records cite the P3 class)
## Objective
Build the Companion C journal formatter (Step 3a). Then ship the persona
text that presents the external run journal to the reviewer as
non-authoritative evidence (Step 3b, per D4). P3 discipline is checked
per commit.
## Retrieval
Read `docs/plans/2026-10-05-outcomeci-series-gate-trial.md`: F3, F11, Step 3
(3a and 3b), D4, Constitution check P3/P4, and the Prior FAIL history
section. There is no tracker issue (fast path).
## Affected files
- 3a (new):
  - `prototype/outcomeci-series-gate/journal-evidence.sh`
  - `prototype/outcomeci-series-gate/tests/journal-evidence.test.sh`
- 3b:
  - `agents/orchestrator.md` (the non-authoritative-inputs paragraph,
    ~:171-177)
  - `agents/reviewer.md` (a new sibling bullet after the "starting hint"
    bullet, ~:81-85)
  - `.claude-plugin/plugin.json` and `package.json` (version bump, kept
    equal)
  - `CHANGELOG.md`
  - the generated `.claude/agents/orchestrator.md` and
    `.claude/agents/reviewer.md` (via `node bin/cli.js --update` only)
  - any `templates/`, `adapters/codex/` or `adapters/cursor/` file that
    AC3b.8's grep finds holding a copy of an edited passage. There are none
    as of 2026-10-05.
## Ordered edits
1. Commit A (3a, prototype only; no P3 obligation, F10):
   1. Write the test with fixtures: 3 calls whose `review.decision` values
      are allow, revise and deny, plus an absent journal (red).
   2. Write the formatter, which emits the banner exactly as in Step 3a.
   3. Run AC3.1-AC3.5 and commit.
2. Commit B (3b), one commit holding everything below:
   1. Bump `.claude-plugin/plugin.json` and `package.json` to the next
      patch version, **first**.
   2. Add the CHANGELOG entry for that version.
   3. Edit `agents/orchestrator.md`: add the external run journal as a
      third non-authoritative input. Use conditional reviewer phrasing ("if
      present").
   4. Edit `agents/reviewer.md`: an external run journal is evidence only,
      never satisfies an acceptance criterion, and the reviewer re-derives
      every criterion itself.
   5. Run AC3b.8's grep. Apply the same edit to every template or adapter
      copy it finds.
   6. Run `node bin/cli.js --update` to regenerate the `.claude/agents/`
      copies.
   7. Stage everything by explicit path and commit once.
3. Run AC3b.1-AC3b.8 with `<base>` = the parent of commit A.
## Do NOT touch
- `hooks/` and `hooks/hooks.json`;
- `CONTEXT.md`;
- any marker, flag, stamp, or `.claude/reviewed/` and `.claude/human-review/`
  content;
- the reviewer's verdict, marker, FAIL-record and 2-FAIL-cap sections;
- `oci-series-gate.sh` and the ocig-2 files;
- any `templates/` or adapter file that AC3b.8's grep does not select.

Never hand-edit `.claude/agents/*`, because P2 requires the script-driven
path.
## Acceptance criteria
- AC3.1-AC3.5 (3a).
- AC3b.1-AC3b.8 (3b), including:
  - the per-commit P3 checks (AC3b.2: `version-stamp-check.sh <base>..HEAD`
    reports `ok`; AC3b.3: every commit touching `agents/` or `templates/`
    also touches `CHANGELOG.md`, and plugin.json version == package.json
    version);
  - the hand-sync check (AC3b.8).
## Pre-resolved context
- Neither persona passage has a copy in `templates/` or the adapters
  (re-verified 2026-10-05 with a recursive grep, exit 1). So hand-sync is
  expected to be a no-op, and AC3b.8 proves it at execution time.
- `bin/cli.js` re-renders stamped personas only when the version stamp
  changes (`lean-2` FAIL record mechanism), so bump **before** running
  `--update`.
- `version-stamp-check.sh` always exits 0; parse its output line.
- `tests/adapter-protocol-parity.test.js` asserts neither passage.
- Author any file whose text names the marker directory with Write/Edit,
  not Bash heredocs, because `reviewed-path-gate.sh` scans Bash command
  text.
## Escalation
- If `--update` reports drift on files other than the two persona copies,
  stop and report. Do not reconcile unrelated drift.
- If AC3b.8 finds a copy whose surrounding text differs enough that the
  edit is not a direct transplant, stop and report with
  `STATUS: incomplete`.

### Unit: ocig-5
Not dispatch-ready. Its contract is written only after the Step 5 entry
condition fires.

## Publication

This doc is a single milestone with at most 4 units, so publishing via
`to-spec` is optional. It is not published, because this run was scoped to
write only this document. If it is published later, the to-spec mapping is:
- Goal → Problem Statement
- Context → Solution
- Steps → User Stories
- Constitution check → Implementation Decisions
- AC commands → Testing Decisions
- Non-goals and Step 5 → Out of Scope
- Clarifications and Self-check → Further Notes

This `docs/plans/` document stays canonical.

## Scribe update hint

Glossary candidates for CONTEXT.md, to be added only if the trial
graduates (this spec does not edit CONTEXT.md, A5):

- **externalization**: an action that makes a unit's effects leave the
  machine (push, PR, issue close, chat post).
- **externalization precondition wrapper**: a host script that refuses to
  start an externalizing run unless the unit's PASS marker is valid and
  bound to the commit. Not a Gate: it is not a hook, and it can be bypassed
  by calling the tool directly.
- **broker journal**: OutcomeCI's per-run record of every brokered call and
  its status.
- **policy decision**: `allow`, `revise` or `deny` from OutcomeCI policy
  review. It is never a verdict, and it never counts toward the 2-FAIL cap.

_Avoid_ "series gate" for the artifact itself.

ADR candidate only on graduation: "OutcomeCI policy review is authoritative
for externalization only, never for done."
