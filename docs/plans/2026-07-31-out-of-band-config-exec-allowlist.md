# Out-of-band configuration execution in the Bash write-intent allowlist

**Status:** finalized spec, ready for `task-master` slicing — **but see Open
Questions 1-3**, which are genuine human decisions. The plan is dispatchable
under the recommended defaults; OQ1 in particular is one a human may
reasonably overturn, and overturning it changes Step 1 wholesale.

**Tracker:** issue **#186**. **Not** part of #182, #183, #184, #185, or the
`docs/plans/2026-07-31-reviewed-path-gate-write-intent.md` epic (#181, v0.16.0,
shipped).

**Sibling docs (context, not scope):**
`docs/plans/2026-07-31-program-allowed-flag-boundary.md` (#184),
`docs/plans/2026-07-31-debug-182-step6-word-boundary.md` (#183),
`docs/plans/2026-07-31-reviewed-path-gate-write-intent.md` (#181 epic).

**Disclosure posture.** This document is the canonical artifact and is **local
and uncommitted-by-convention**; it carries full technical detail. Nothing in
it — no configuration key name, no environment variable name, no payload — goes
into the GitHub issue body, an issue comment, the CHANGELOG, or the README while
this is unfixed. #186's issue body is deliberately redacted; Step 3's public
prose describes the **class** abstractly and names no mechanism (subject to
OQ2). Every measurement below was taken in `mktemp -d` fixtures or as a
pure gate-exit-code probe. **Nothing was executed against any real path under
the marker directory, and no configuration was armed anywhere that persists.**

---

## Goal

Decide and implement the correct response to a bypass class that **no
improvement to command-text scanning can reach**: an allowlisted program in
`program_allowed()` executes a caller-chosen program because of configuration
that appears **nowhere in the command line** — it is read from ambient state
(persisted repository/user configuration on disk, or the process environment)
that a *separate, earlier* command established, and that separate command never
mentions the marker directory, so the gate's substring early-exit never inspects
it either.

Two outcomes, both required:

1. **Remove the reachable surface.** The allowlist must not contain a program
   whose behaviour is steerable to arbitrary program execution by ambient
   state that the gate cannot see.
2. **Correct the claim the project makes about this gate.** The gate is
   currently documented as an allowlist that decides "what a command does". It
   does not, and cannot: it decides what a *program name* is, and a name is not
   a program. Step 3 makes that limit explicit rather than leaving a reader to
   infer a boundary that does not exist.

**Non-goal, stated up front.** This spec does **not** try to detect the arming
step, does not add stateful tracking across tool calls, and does not add a
config-inspection precondition. Sections "Why the obvious fixes fail" and
"Is this fixable at all?" record, with measurements, why each was rejected.

---

## Context

### The site

`hooks/scripts/reviewed-path-gate.sh:79-104`, `program_allowed()`. Past the
`.claude/reviewed` substring early-exit, a Bash command is allowed only if every
segment's first word is on a closed allowlist. Two entries carry an extra
flag-scan because the program is read-only *except* under a specific option:

```
rg)  form="$(flag_scan_form "$1")" || return 1
     case "$form" in *' --pre '*|*' --pre='*|*' --hostname-bin'*) return 1 ;; esac
     return 0 ;;
git) case "$3" in
       commit|log|show|diff|status|tag|blame)
         form="$(flag_scan_form "$1")" || return 1
         case "$form" in *' -o'*|*' --output'*) return 1 ;; esac
         return 0 ;;
     esac ;;
```

Every guard in this file — the substring early-exit, `command_skeleton()`,
`mask_inert_redirections()`, `flag_scan_form()`, the segment split — reads the
**text of the command it is handed**. `#177`, `#182` and `#184` were all
failures of that reading. **#186 is not.** The reading is correct here and it
does not matter, because the decisive input is not in the text.

### Established evidence — taken as given, deliberately not re-derived

Two reviewers (one opus, one fable) independently reproduced arbitrary program
execution through this class in isolated `mktemp -d` sandboxes during #184's
review, and bisected it as **byte-for-byte pre-existing** — identical gate
behaviour before and after #184's fix landed. The opus reviewer's assessment
("arguably higher severity than #184's bug ... no correctness improvement inside
`program_allowed()`'s flag-text scan can reach it") is treated as **established
and is not re-demonstrated in this session**, per the same discipline #184's
spec applied to its own inherited severity claim. No arming payload was
constructed, executed, or written down during this spec's work.

### The two mechanisms, and why they are not equally reachable

Both allowlisted programs consult ambient configuration before doing anything:

| program | ambient source | persists how | reachable in-session? |
|---|---|---|---|
| `git` | repository-local, user-global and system configuration **files on disk**, plus a set of environment variables | **on disk**, effective on the very next invocation | **Yes** |
| `rg` | a configuration file whose location is named **only** by an environment variable; ripgrep has no default config path | environment only | **No** — see below |

**Measured this session (2026-07-31), and it is decisive for the fix's shape:**
shell state does **not** survive a Bash tool call. An `export` in one call is
gone in the next — probed directly (set in call A, read as `UNSET` in call B),
and independently doc-confirmed ("Environment variables don't persist. An
`export` in one command won't be available in the next", Claude Code tools
documentation). Working directory persists; shell functions and aliases persist
**from the startup files sourced at session start**, not from a previous
command.

So the environment half of this class requires a **session boundary** (a startup
file, or the `env` block in `settings.json`) or a harness mechanism outside this
gate's reach. The **disk-configuration half does not**: it is armed by an
ordinary command in one tool call and is live in the next. `git` is therefore in
a strictly more reachable tier than `rg`, and that asymmetry is the whole
content of OQ1's option (b).

### What is *already* blocked, so the delta is exact

Measured by piping canned payloads to the live gate in a `mktemp -d` fixture
(exit code only — the gate never executes anything):

| command | live gate |
|---|---|
| `git -c <key>=<val> log <M>` | blocked (`-c` is not an allowlisted subcommand) |
| `git --exec-path=/tmp log <M>` | blocked (same reason) |
| `<VAR>=<val> git log <M>` | blocked (a leading assignment disqualifies the segment) |
| `<VAR>=<val> rg pat <M>` | blocked (same) |
| `git config <key> <val>; git log <M>` | blocked (`config` is not allowlisted) |

**Every single-command form is already correctly blocked.** The gap is entirely
the two-step shape, and the arming step is invisible to this gate by
construction: it does not name the marker directory, so the substring early-exit
(`reviewed-path-gate.sh:301-304`) returns before any allowlist logic runs.

The trigger shapes, all currently **ALLOWED** (measured):

`git log --oneline -- <M>` · `git diff --stat HEAD -- <M>` ·
`git status <M>` · `git show HEAD -- <M>` · `git blame <M>/9.pass` ·
`git commit -m "note about <M>"` · `rg pat <M>`

### `git commit` is unsound independently of any arming step

Measured in this repository: `.git/hooks/pre-commit` exists and is executable
(it is this project's own code-review-graph pre-commit check), and
`core.hooksPath` is unset. `git commit` therefore **executes a repository-
controlled script by design**, with no configuration arming required at all. Any
proposal that keeps `git commit` on the allowlist while dropping the other
subcommands is unsound on this ground alone, before configuration is considered.
This is why OQ1 has no "keep `git commit` only" option.

### Why the obvious fixes fail — measured, not asserted

**(i) Enumerate and refuse the dangerous configuration keys.** A naive scan of
`git-config(5)` on git 2.43.0 for descriptions containing "command to run" /
"is executed" / "program to" and similar yields **44** distinct key patterns.
The list is not the point; two properties of it are:

- It is **open-ended and version-dependent**. git adds configuration keys every
  release. A key the enumeration does not know is a key the gate allows —
  i.e. this is a **denylist**, which the epic's R1 forbids in exactly these
  words: "a denylist fails **open** on any command form its authors did not
  enumerate; an allowlist fails **closed**". This file has now produced three
  bugs of one class; a fourth mechanism arriving in a future git release, with
  no test that could catch it, is the predictable outcome.
- It is **subcommand-scoped**, so the enumeration is not even a single list —
  it differs for `commit` vs `log` vs `status`, and getting that scoping wrong
  in either direction is either a fail-open or an over-block.

**(ii) Invert it: allowlist the *benign* keys and refuse on anything unknown.**
This is allowlist-shaped and therefore posture-correct, and it is
**measurably unusable**. This machine's effective configuration carries 12
distinct keys (8 repository-local, 6 user-global), and two of the global ones
are `credential.<url>.helper` entries installed by ordinary `gh` authentication
— i.e. **a stock, correctly-configured developer machine already carries
execution-capable configuration in global scope**. A fail-closed key allowlist
blocks `git` outright on such a machine. Since this gate ships plugin-wide via
`bin/cli.js --update`, downstream configuration variance is unbounded. The
result is a gate that blocks `git` for most users, unpredictably — functionally
equivalent to removing `git` from the allowlist, but with worse ergonomics, a
per-invocation subprocess on the hook path, and a maintenance burden.

**(iii) Neutralize the configuration by rewriting the command.** Mechanically
available: a `PreToolUse` hook **can** replace the tool's arguments via
`hookSpecificOutput.updatedInput.command` for Bash. It is not soundly
*completable*:

- Clearing the environment is allowlist-shaped and fine (`env -i` plus an
  explicit `PATH`).
- Two of git's three configuration scopes can be blanket-neutralized by
  pointing them at `/dev/null`.
- **The repository-local scope cannot.** git has no "ignore all configuration"
  switch, so the local scope still needs per-key `-c` overrides — mechanism (i)
  again, with all of its fail-open properties — plus `--no-verify` for the
  hooks surface above.
- And it would introduce a command-rewriting output mode into a fail-closed
  script that has produced three bugs in one week. The risk/benefit against
  "delete two lines" is not close.

**(iv) Detect the arming step.** This would require the gate to abandon its
substring early-exit and inspect **every** Bash call in the session for
arming-shaped commands. That is a denylist over arming forms (fails open under
the same obfuscation the epic already ratified as residual), it puts real work
on a hook that fires on every Bash call, and it would block ordinary `git
config` use project-wide. Rejected.

### Is this fixable at all? — the direct answer

**It is not a stateful-hook problem, and the "two separate tool calls" framing
is a red herring.** The gate does not need to observe the arming command. The
armed state is *ambient at trigger time* — on disk for the configuration half,
in the process environment for the environment half — and a `PreToolUse` hook
can read both. A single-shot hook is sufficient in principle.

**The obstacle is different, and it is not architectural in the harness — it is
epistemic.** Validating or neutralizing that ambient state requires an
**open-ended enumeration of a third-party program's configuration surface**,
which is a denylist by construction and fails open on everything the enumeration
missed. There is no closed, checkable predicate for "this `git` invocation
cannot execute a program of the caller's choosing."

So the sound response is **to remove the surface rather than inspect it** — the
same allowlist-shaped reasoning the epic used to choose an allowlist over a
denylist in the first place, applied one level up: instead of enumerating which
*commands* are benign, stop claiming that a *program name* is.

### The deeper premise failure, and the residual nothing closes

`program_allowed()` matches a program **name**. What executes is decided by name
resolution (shell functions and aliases sourced at session start, then `PATH`)
and by the resolved program's own ambient configuration. The gate sees neither.

A benign, live demonstration measured in this very session: in a Bash tool call,
`grep` is **not** `/usr/bin/grep`. It is a shell function installed by the
harness that runs the `claude` binary in ugrep mode, falling back to the real
binary only for certain option shapes. GNU grep 3.11 is also present at
`/usr/bin/grep`. Nothing is wrong here — the point is that the allowlist entry
`grep` did not determine which program ran, and the gate had no way to know.

Consequences that **no option in OQ1 closes**, and that Step 3 must therefore
state plainly rather than leave implicit:

- **R-a — name resolution.** Every allowlisted entry, including the coreutils,
  is a name. `PATH` and startup-file functions/aliases decide the binary.
- **R-b — cross-session environment.** Environment arming needs a session
  boundary (measured: `export` does not persist between Bash calls), which puts
  it outside this gate's reach entirely rather than inside it.
- **R-c — unaudited inventories.** `gh`'s subcommand allowlist carries no flag
  scan, and `rg`'s flag inventory beyond `--pre`/`--hostname-bin` is unaudited;
  both are already tracked on **#185**. Add to that list, for #185 and not for
  this unit: `grep` is allowlisted with no flag scan at all, and at least one
  widely-packaged alternative `grep` implementation carries both a
  run-an-external-program option and a write-a-file option. **Recorded as an
  inventory item; deliberately not investigated, reproduced, or developed here.**
- **R-d — the ratified obfuscation residual** (splitting the marker path across
  a shell variable defeats the substring early-exit) is unchanged.

The honest statement of the gate's strength, which Step 3 must publish: **the
Bash write-intent allowlist is a guardrail against careless or accidental
writes by a cooperating agent. It is not a security boundary against a caller
that controls its own environment.** ADR 0002's review-ownership invariant is
unaffected — it is a policy about who *should* write markers, and this gate is
one of several imperfect enforcements of it.

### Prior-defect history (per the `.fail`-record rule)

`.claude/reviewed/` carries durable FAIL records for **both** units that have
previously edited this file: `177.fail` and `182.fail`. #182 additionally hit
the shared protocol's 2-FAIL cap and needed a debug spec (#183) after three
attempts. Recorded so `task-master` **never** tags this unit `haiku`. Reviewer
mandatory; `fable` roast pass advised.

Note the shape of the defect history is different this time, and a reviewer
should hold it differently: #177/#182/#184 were *matcher* bugs, where the fix
was a sharper predicate and the risk was getting the predicate wrong. This unit
is a *deletion*, where the risk is not a subtle predicate at all — it is
over-deleting (breaking read-only inspection that must keep working) and
under-reconciling the suite (leaving assertions that pass **vacuously**, the
defect #184's own Amendment A5 was written about). Step 1's criteria are built
around those two risks, not around boundary correctness.

### Blast radius (exact, measured)

- **Production change is single-file.** `grep -rln 'program_allowed'` over the
  tree (excluding `.git`/`node_modules`) returns
  `hooks/scripts/reviewed-path-gate.sh` and `CHANGELOG.md` (prose only). There
  is **no** `.claude/` mirror and **no** `adapters/{cursor,codex}` copy of this
  script; the adapter trees carry `graph-update.sh`, `lint-on-edit.sh`,
  `protected-paths.sh`, `reviewer-route-gate.sh` and `stop-gate.sh` only.
- `bin/cli.js` copies `hooks/scripts/*.sh` wholesale, so the change reaches
  every already-adapted project on `--update`. This is what makes the version
  bump constitutionally required (P3), not bookkeeping.
- `flag_scan_form()` has exactly **two** call sites, both inside the `rg` and
  `git` branches (`reviewed-path-gate.sh:86` and `:98`). Removing both branches
  makes it dead code.
- **The suite reconciliation is the large part of this unit.** Measured against
  the live suite at 622 lines, 102 `OK`, 0 `FAIL`:

  | candidate | OK | FAIL | where the FAILs are |
  |---|---|---|---|
  | remove `git` + `rg`, suite untouched | 93 | **221** | 215 × case 28, 4 × case 29 allow-controls, case 5, case 12f |
  | remove `git` only, suite untouched | 96 | **112** | 108 × case 28, 3 × case 29, case 5 |
  | remove `git` + `rg`, suite reconciled | **90** | **0** | — (rc 0, 14.77 s wall clock, suite 622 → 451 lines) |

  Case 28 (#184's exhaustive flag-boundary byte sweep) and cases 29.a-o exist
  **solely** to guard `program_allowed()`'s `git`/`rg` flag scans. With those
  programs off the allowlist, every 29.x fixture still reports `blocked` — but
  **vacuously**, because the program name misses the allowlist, not because any
  flag scan works. Leaving them in place would ship precisely the never-failing
  test that #184's Amendment A5 diagnosed. They must be **deleted**, not
  re-expected. Case 26 (`command_skeleton()`'s differential sweep) is
  **untouched** — it invokes `ls`, not `git`/`rg`.

- Merge gate is `bash tests/validate.sh`. Live version stamp is **0.16.1** in
  both `.claude-plugin/plugin.json` and `package.json`.
- Tool versions measured against: git 2.43.0, ripgrep 14.1.1, gh 2.96.0.

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Missing
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-31 Functional scope & success criteria: Q Is the deliverable a code
  fix, a documentation-only residual, or an architectural change? → A
  (self-resolved, **subject to OQ1**): a code fix that *removes surface* plus a
  documentation correction — **not** a detection mechanism. Grounds in "Why the
  obvious fixes fail" (four rejected approaches, each with a measurement) and
  "Is this fixable at all?".
- 2026-07-31 Technical constraints & tradeoffs: Q Can a `PreToolUse` hook
  neutralize environment or configuration for the command it gates, and does a
  two-step attack across two tool calls require stateful tracking? → A
  (self-resolved): **no stateful tracking is needed and none is proposed.** The
  armed state is ambient at trigger time and a single-shot hook can read it.
  The harness does support command rewriting
  (`hookSpecificOutput.updatedInput.command`, Bash) but offers no direct
  environment scrubbing for `PreToolUse`. Rewriting is rejected on soundness,
  not availability: git's repository-local configuration scope has no
  blanket-neutralize switch, so a rewrite still needs a per-key enumeration.
- 2026-07-31 Technical constraints & tradeoffs: Q Should the fix inspect ambient
  configuration before allowlisting, rather than removing the programs? → A
  (self-resolved): **no.** Measured: as a denylist of dangerous keys it fails
  open on 44+ documented and future keys; as an allowlist of benign keys it
  blocks `git` on a stock machine, because ordinary `gh` authentication installs
  execution-capable configuration in global scope (2 such keys present here).
- 2026-07-31 Edge cases / failure handling: Q What remains open after the fix,
  and must that be stated rather than implied? → A (self-resolved): R-a through
  R-d above. Name resolution (`PATH` and startup-file shell functions) is the
  deepest one and applies to **every** allowlisted entry; it is demonstrated
  benignly in this session by `grep` resolving to a harness-installed shell
  function rather than `/usr/bin/grep`. Step 3 publishes the class abstractly;
  the mechanism detail stays in this local document.
- 2026-07-31 Edge cases / failure handling: Q Can `git commit` be kept on the
  allowlist for the text-only-mention case that epic Goal item 1 names? → A
  (self-resolved): **no.** Measured: this repository has an executable
  `.git/hooks/pre-commit`, so `git commit` executes a repository-controlled
  script by design, independent of any configuration arming. Documented
  workaround for the lost case is `git commit -F <file>` — the command text then
  never names the marker directory, so the gate's substring early-exit returns
  before any allowlist logic runs.
- 2026-07-31 Non-functional attributes: Q Does the change cost anything on the
  hook's hot path, and what is the suite's runtime after reconciliation? → A
  (self-resolved): the hot path gets **cheaper** (two `case` branches and one
  helper removed; no subprocess is added — which any config-inspection option
  would have required). Suite measured at **14.77 s** with the reconciled
  candidate, against the 60 s budget #182 and #184 both pinned.
- 2026-07-31 External dependencies & integrations: Q Does this depend on
  anything the suite does not already use, or on unverified harness behaviour? →
  A (self-resolved): no new tool — `bash`, `jq`, `mktemp` only. Two harness
  facts are load-bearing and were **measured**, not assumed: `export` does not
  persist between Bash tool calls, and `.git/hooks/pre-commit` is present and
  executable here. The `updatedInput` capability is documentation-sourced, and
  since the plan **rejects** the approach that would use it, nothing in the
  steps depends on it being correct.
- 2026-07-31 Functional scope & success criteria: Q Does this unit touch #185's
  inventory questions (`gh`'s missing flag scan, `rg`'s unaudited flags), or the
  new `grep` inventory observation? → A (self-resolved): **no.** All three are
  inventory-completeness questions, orthogonal to this surface-removal change,
  and #185 already exists for the first two. Step 3 adds the third to #185 as a
  one-line note with no reproduction detail.
- 2026-07-31 Domain entities / data model: Q Are "segment", "word", "flag scan",
  "allowlist" and "marker directory" used as in the sibling specs? → A
  (self-resolved): yes, inherited unchanged. One term is added: **out-of-band
  configuration** — configuration consulted by a program at run time that
  appears nowhere in the command line the gate inspects.
- 2026-07-31 User interaction flow: Q What is the observable contract? → A
  (self-resolved): unchanged — hook exit 0 = allowed, exit 2 + non-empty stderr
  = blocked. Step 1 changes the block **message text** (it currently names two
  programs as allowed that will no longer be), not the contract.
- 2026-07-31 Terminology consistency: Q Does any existing prose become false? →
  A (self-resolved): yes, in four places, all handled by Step 3 — the gate's own
  header comment (`:23-31`, cites `git commit -m` as an allowed example), the
  live block message (`:345`, same), `docs/design.md`'s write-intent
  description, and `README.md`'s "Known limitations" section.
- 2026-07-31 Completion / acceptance signals: Q What is the acceptance signal? →
  A (self-resolved): `bash tests/validate.sh` green, with
  `tests/reviewed-path-gate.test.sh` at 0 `FAIL` **and** the anti-vacuity
  mutation control of AC1.8 demonstrably failing against the unfixed gate.

---

## Risks / dependencies

- **RD1 — Two durable FAIL records on this file (`177.fail`, `182.fail`), and a
  2-FAIL-cap escalation (#182 → #183).** **Not `haiku`-eligible** under any
  slicing. Reviewer mandatory; `fable` roast pass advised. See "Prior-defect
  history" for why this unit's risk profile nevertheless differs from those.
- **RD2 — The dominant risk is a vacuous suite, not a wrong predicate.** After
  the removal, every `git`/`rg` fixture in cases 12c, 12e, 28 and 29 reports
  `blocked` for a reason that has nothing to do with what it was written to
  test. An implementer who "keeps the tests green" by leaving them in place
  ships 100+ assertions that cannot fail. AC1.4 and AC1.5 exist to fail that
  implementation; AC1.8's mutation control is what proves the replacement can
  fail at all.
- **RD3 — Deleting #184's machinery one day after it landed is deliberate, and
  is a loss of *technique*, not of coverage.** Case 28 and cases 29.a-o guard
  flag scans that will no longer exist. The reusable lesson (differential sweep
  vs. one-directional block assertion with a mutation control) must survive in
  the wiki — Step 3's scribe hint — and the code itself remains recoverable from
  git history and from #184's spec doc. Do not "preserve" it as skipped or
  commented-out test code; a disabled test is a maintenance liability that
  asserts nothing (see OQ3).
- **RD4 — This *reduces delivered function* against the epic's Goal item 1.**
  Six commands that #181 deliberately unblocked become blocked again. Stated
  plainly rather than softened: `git commit -m` naming the marker directory,
  `git log`/`git diff`/`git show`/`git status`/`git blame` scoped to it, and
  `rg` searching it. Workarounds are real but are workarounds: `git commit -F
  <file>` for the message case, and `grep -r` (already allowlisted, and
  unaffected) for the search case. There is **no** workaround for `git log --
  <markerdir>`; that capability is simply withdrawn from non-reviewer personas.
  This is the substance of OQ1 and the reason it goes to a human.
- **RD5 — Do not widen scope.** Any diff touching the reviewer GRANT, the
  no-reviewer fallback, the substring early-exit, `normalize_path()`,
  `command_skeleton()`, `mask_inert_redirections()`, `identity_drift_log`
  placement, the Write/Edit path, case 26, or the `gh` subcommand allowlist is
  out of scope by construction. The only production function that may change is
  `program_allowed()`, plus the deletion of `flag_scan_form()` and the block
  message/header prose.
- **RD6 — `.claude/reviewed` in command text (epic R4 / #184 RD6).** Every
  assertion that spells the marker directory lives **inside**
  `tests/reviewed-path-gate.test.sh` and is built from the existing `$marker`
  variable, never a literal on a command line. This rule is load-bearing and was
  re-confirmed the hard way during this spec's own work: two probe commands
  written inline were correctly blocked by the very gate under change.
- **RD7 — Ordering.** Step 1 → Step 2 → Step 3. Step 2's public prose must not
  land before Step 1's fix (it would describe the gate as narrowed while it is
  not), and Step 3's version bump must land last. Steps 1 and 2 touch the same
  two files and must not be split across concurrent sessions.
- **RD8 — Version.** Live stamp is `0.16.1` in both files. This plan takes
  **`0.17.0`** — a minor bump, not a patch: it *removes* previously-allowed
  behaviour for every adapted project on `--update`, exactly as #181's
  enforcement increase took `0.16.0`. **Confirm, do not assume** — re-read
  `.claude-plugin/plugin.json` at implementation time.
- **RD9 — No dependency on the `updatedInput` capability.** It appears in this
  document only as part of the rationale for *rejecting* the rewriting approach.
  If that documentation-sourced fact turns out to be wrong, nothing in Steps 1-3
  changes.

---

## Constitution check (.claude/constitution.md v1.0.0)

- **P1 "Verify, don't assume" (MUST): satisfied.** Every Context claim was
  measured this session against the live gate, the live suite, and scratch
  candidates: the 12-row gate-verdict probe table, the three-candidate suite
  matrix (102/93/96/90 `OK`), the 14.77 s runtime, the 8-FAIL mutation control,
  `export` non-persistence across tool calls, the presence of an executable
  `.git/hooks/pre-commit`, this machine's 12-key effective git configuration,
  and the `grep`-is-a-shell-function observation. The one inherited claim — the
  reviewers' severity finding — is **explicitly labelled as established and
  deliberately not re-derived**, with the safety reason stated.
- **P2 "Prefer deterministic scripts over LLM re-derivation" (MUST):
  satisfied.** Verified by `grep -rln` and `find` that this script has no
  `.claude/` mirror and no adapter copy, so no script-driven path is
  hand-edited. Step 3 regenerates mirrors via `node bin/cli.js --update`.
- **P3 "Version-stamp discipline" (MUST): satisfied.** Step 3 bumps both
  `.claude-plugin/plugin.json` and `package.json` to `0.17.0` and adds a
  CHANGELOG entry. Required because `bin/cli.js --update` copies
  `hooks/scripts/*.sh` wholesale.
- **P4 "Optional personas degrade gracefully" (SHOULD): satisfied.** No
  persona-conditional prose is added or changed; the reviewer GRANT and the
  no-reviewer fallback are untouched (RD5) and re-asserted by AC1.6.
- **P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied.** AC1.9,
  AC2.4 and AC3.6 each terminate in it.

---

## Step 1 — Remove `git` and `rg` from the write-intent allowlist

*(Shape assumes OQ1's recommended default (a). Under (b) the `rg` branch,
`flag_scan_form()`, and case 28's `R` template survive; under (c) or (d) this
step does not exist in this form and the spec must come back to `spec-master`.)*

**Affected files (exact):**
- `hooks/scripts/reviewed-path-gate.sh` — `program_allowed()`,
  `flag_scan_form()` and its header comment block, the script header comment
  (`:23-31`), and the final Bash block message (`:345`). **No other function's
  body.**
- `tests/reviewed-path-gate.test.sh` — deletions plus one new case block.

### Normative contract

**Removal.** `program_allowed()` must contain no `git` and no `rg` branch. The
remaining allowlist is unchanged and closed:

> `ls` `cat` `head` `tail` `wc` `stat` `file` `test` `[` `grep` `diff` `cmp`
> `sha256sum` `md5sum` `basename` `dirname` `readlink` `realpath` `echo`
> `printf`; plus `gh` restricted to subcommands `issue` `pr` `api` `search`.

**Dead code goes with it.** `flag_scan_form()` has no other caller and must be
deleted along with its header comment. Do **not** leave it in place "in case it
is needed later" — an unreferenced fail-closed helper in a security script is a
future reader's trap, and its content is recoverable from git history and from
`docs/plans/2026-07-31-program-allowed-flag-boundary.md`.

**Rationale must be recorded at the site.** `program_allowed()`'s header comment
must state, in its own words, the reason the two entries are absent: an
allowlisted program that consults out-of-band configuration can be steered to
execute a caller-chosen program, and no scan of the command's own text can see
it. Without this, the single most likely regression is a future pass helpfully
"restoring" `git log` as a read-only convenience.

**Message and header prose must stop naming the removed programs.** The block
message at `:345` currently reads in part "text-only mentions of the path (gh,
git commit -m) ARE allowed"; the script header at `:23-31` gives the same
example. Both become false. The message must instead name `gh` as the
text-only example and state the `git commit -F <file>` workaround, so a blocked
caller can act on it rather than re-deriving it (this is the same defect the
epic's Step 1 fixed when it removed the unfollowable "use the Read tool for
that" advice).

**Suite reconciliation — delete, do not re-expect.** These lose their subject
and must be **removed**, not flipped:

| region | why |
|---|---|
| case 5 (`git commit -m` allow-control) | subject removed |
| case 12c (`git --output=`), case 12e (`rg --pre`) | now blocked by name, not by flag scan — vacuous |
| case 12f (`rg --pretty` over-block control) | subject removed |
| case 28 (entire block, both `G` and `R` templates) | asserts a byte-exact blocked set for flag scans that no longer exist; the set is `all bytes` after removal, so the criterion is meaningless |
| cases 29.a-o (all fixtures **and** the `git`/`rg` allow-controls) | every blocked fixture passes vacuously; the four `git`/`rg` allow-controls now fail |

**Case 26 is not touched** (it invokes `ls`). The `gh`, `cat` and `ls`
allow-controls inside case 29's block must be **preserved** — relocate them into
the new case 30 rather than deleting them with their neighbours.

### Acceptance criteria

**Fix**

1. `bash -n hooks/scripts/reviewed-path-gate.sh` exits 0.
2. `grep -c 'flag_scan_form' hooks/scripts/reviewed-path-gate.sh` prints `0`,
   and `grep -cE '^[[:space:]]+(git|rg)\)' hooks/scripts/reviewed-path-gate.sh`
   prints `0`.
3. The removal rationale is recorded at the site:
   `grep -ciE 'out-of-band|configuration the gate cannot see' hooks/scripts/reviewed-path-gate.sh`
   prints `>= 1`, within `program_allowed()`'s comment block.
4. The block message no longer advertises a removed program and does offer the
   workaround:
   `grep -c 'git commit -m' hooks/scripts/reviewed-path-gate.sh` prints `0`, and
   `grep -c 'git commit -F' hooks/scripts/reviewed-path-gate.sh` prints `>= 1`.

**Suite: the removal is asserted, and the vacuous assertions are gone**

5. **New case 30, built from `$marker`** (per RD6), asserting **blocked** for
   all eight of: `git log --oneline -- <M>`, `git diff --stat HEAD -- <M>`,
   `git show HEAD -- <M>`, `git status <M>`, `git blame <M>/9.pass`,
   `git tag -l -- <M>`, `git commit -m "note about <M>"`, `rg pat <M>`.
   Seven of the eight are the exact subcommands the old allowlist named; the
   eighth is `rg`. Measured against the candidate: all eight blocked.
6. **Case 30 allow-controls**, asserting **allowed** for all eight of:
   `grep -r pat <M>`, `ls -la <M>`, `cat <M>/9.pass`, `head -1 <M>/9.pass`,
   `wc -l <M>/9.pass`, `test -f <M>/9.pass`, `sha256sum <M>/9.pass`,
   `gh issue close 9 --comment "see <M>/9.pass"`. This is the over-block bound:
   read-only inspection and `gh` text-mentions must be **untouched** by the
   removal. Measured against the candidate: all eight allowed.
7. The deleted regions are actually gone, not disabled:
   `grep -cE 'case (28|29|12c|12e|12f|5 )' tests/reviewed-path-gate.test.sh`
   prints `0`, and
   `grep -ciE '^\s*#\s*bash_case|skip|disabled' tests/reviewed-path-gate.test.sh`
   prints `0` (no commented-out or skipped cases were left behind).

**Anti-vacuity**

8. **Mutation control, written as a comment above case 30 and re-runnable by the
   reviewer.** Running the *reconciled* suite against the **unfixed** gate via
   the suite's existing `GATE_UNDER_TEST` variable must exit non-zero with
   **exactly 8** `FAIL` lines — all eight from case 30's blocked forms, and
   **every one of them must read `rc=0`** (a real fail-open), never `rc=1`
   (which would be a void run). The exact command and the expected count go in
   that comment, mirroring cases 26 and 28's existing mutation-control blocks.
   Measured this session, with an absolute `GATE_UNDER_TEST` path:
   82 `OK`, 8 `FAIL`, every FAIL line `rc=0`.

   ```
   GATE_UNDER_TEST=/abs/path/to/unfixed/reviewed-path-gate.sh \
     bash tests/reviewed-path-gate.test.sh; echo $?
   ```

   Note the absolute path: the suite resolves `GATE_UNDER_TEST` as given, and a
   relative path yields `rc=127` on every case — which reads as a catastrophic
   failure rather than a control. This cost a false reading during this spec's
   own measurement and is recorded so the reviewer does not repeat it.

**Budget and gate**

9. `bash tests/reviewed-path-gate.test.sh` exits 0, prints **no** line starting
   `FAIL`, and its `OK` count is **>= 88** (measured with the reconciled
   candidate: exactly 90, down from a 102 baseline). It completes in **under
   60 seconds** wall clock (measured: 14.77 s).
10. `bash tests/validate.sh` exits 0.
11. `bash tests/agent-identity-namespace.test.sh` exits 0 — the reviewer GRANT
    and the no-reviewer fallback are untouched (RD5).

---

## Step 2 — Correct the prose that describes what this gate can do

**Affected files (exact):** `docs/design.md`, `README.md`,
`.claude/wiki/modules/hooks.md`, `CONTEXT.md`,
`docs/adr/0002-reviewed-dir-owned-by-reviewer.md`.

Two separate corrections, and the second is the more important one.

**2a — the allowlist's membership changed.** `docs/design.md`'s write-intent
description and `.claude/wiki/modules/hooks.md`'s gate row both enumerate or
imply the old allowlist. Update them, and state the `git commit -F <file>`
workaround where the lost capability is described.

**2b — the gate's *claim* changed, and this is the deliverable.** Add, to
`README.md`'s "Known limitations" and to `docs/design.md`, an explicit statement
of the class and the residual — **abstractly, naming no program, no
configuration key and no environment variable** (OQ2's recommended default):

> An allowlisted program can be steered by configuration it reads at run time
> that appears nowhere in the command line, established by an earlier command
> that never names the marker directory. No text-scanning improvement can
> detect this. More generally, the allowlist matches a program *name*, while
> what actually executes is decided by name resolution and by that program's own
> ambient configuration — neither of which this hook can see. **The Bash
> write-intent allowlist is a guardrail against careless or accidental writes by
> a cooperating agent; it is not a security boundary against a caller that
> controls its own environment.**

ADR 0002 gets a short appended note: its review-ownership decision **stands
unchanged** — it is a policy about who should write markers — but the note must
record that this gate is one imperfect enforcement of it and must not be read as
the boundary itself.

`CONTEXT.md`'s one-line description of the gate must be checked and, if it
implies write-intent detection is complete, corrected.

**Do not** restate anything from this document's Context in a committed file.

### Acceptance criteria

1. `grep -rniE 'not a security boundary' README.md docs/design.md` returns at
   least one match in **each** file.
2. `grep -c 'git commit -m' .claude/wiki/modules/hooks.md docs/design.md`
   prints `0` for both (the old allowed-example is gone).
3. `grep -rniE 'git commit -F' README.md docs/design.md .claude/wiki/modules/hooks.md`
   returns `>= 1` (the workaround is discoverable outside the block message).
4. **Disclosure check — the redaction discipline is machine-checkable.** None of
   the committed files names a mechanism. Over the diff of this step,
   `git diff -- README.md docs/design.md .claude/wiki/modules/hooks.md CONTEXT.md docs/adr/0002-reviewed-dir-owned-by-reviewer.md CHANGELOG.md`
   must contain **zero** matches for
   `grep -ciE 'core\.pager|core\.editor|core\.fsmonitor|core\.hooksPath|diff\.external|textconv|GIT_[A-Z_]+|RIPGREP_[A-Z_]+|--pre=|hostname-bin'`.
5. `docs/adr/0002-reviewed-dir-owned-by-reviewer.md` gains an appended note and
   loses nothing: `git diff --numstat -- docs/adr/0002-reviewed-dir-owned-by-reviewer.md`
   shows `0` deletions.
6. `bash tests/validate.sh` exits 0.

---

## Step 3 — Release hygiene, and the two tracker updates

**Affected files (exact):** `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`, `.claude/` mirrors (regenerated, never hand-edited),
`docs/plans/2026-07-31-program-allowed-flag-boundary.md` (**append-only**).

- **Version `0.16.1` → `0.17.0`** (RD8 — confirm the live stamp first).
- **CHANGELOG** must **lead** with the behaviour removal for already-adapted
  projects, in the plain form of RD4: named commands that v0.16.0 deliberately
  unblocked are blocked again for non-reviewer personas, with the `git commit
  -F` and `grep -r` workarounds stated. It must describe the *reason* at the
  abstract level of Step 2b and must satisfy AC2.4's disclosure check. It must
  also record that #184's flag-boundary machinery was removed with its subject,
  so a reader of the `0.16.1` entry is not left believing it is still in force.
- **#184's spec doc gets an appended amendment**, not an edit — that document's
  own convention (Amendments A5, B: "Nothing above this line is modified").
  One short section recording that its Step 1 fix and its cases 28/29 were
  superseded by the removal of their subject, and that the *technique*
  distinction it established (differential sweep vs. one-directional block
  assertion with a mutation control) survives it and is carried into the wiki.
- **#185 gets one comment**, adding the `grep` inventory observation to its
  existing list, at the abstract level of Step 2b: the allowlist's `grep` entry
  carries no flag scan, and the entry is a *name* that is not guaranteed to
  resolve to the implementation the allowlist assumes. **No reproduction detail,
  no option names.**
- **#186 gets one strictly administrative comment**: the spec is finalized, the
  canonical document is local at
  `docs/plans/2026-07-31-out-of-band-config-exec-allowlist.md`, and it is not
  published while unfixed. **No technical detail whatsoever.** #186's issue body
  is **not** edited.

### Acceptance criteria

1. `jq -r '.version' .claude-plugin/plugin.json` equals
   `jq -r '.version' package.json`, and both are `0.17.0` (adjust if RD8 forces
   a different number).
2. `grep -c '0\.17\.0' CHANGELOG.md` is `>= 1`, and the entry's first bullet
   names the removed capability rather than the fix.
3. `git diff --numstat -- docs/plans/2026-07-31-program-allowed-flag-boundary.md`
   shows `0` deletions (append-only preserved).
4. `node bin/cli.js --update && git status --porcelain .claude/ | wc -l` prints
   `0` after the regeneration is committed (P2 — mirrors regenerated, not
   hand-edited).
5. AC2.4's disclosure check re-run over `CHANGELOG.md` returns `0` matches.
6. `bash tests/validate.sh` exits 0.

---

## Open Questions

**All three are real human decisions. The plan is dispatchable under the
recommended defaults (1a, 2a, 3a); OQ1 is the one most likely to be
overturned, and overturning it rewrites Step 1.**

### OQ1 — Which posture? (the load-bearing question)

The cost is not the code. It is that six commands #181 deliberately unblocked
become blocked again (RD4), and that #184's regression machinery is deleted one
day after it landed (RD3).

- **(a) Remove both `git` and `rg` — recommended default.** The only
  allowlist-shaped, fail-closed option: it removes the surface instead of
  enumerating it. Measured cost: suite 622 → 451 lines, `OK` 102 → 90, 0 `FAIL`,
  14.77 s. Loses `git commit -m`/`log`/`diff`/`show`/`status`/`blame` and `rg`
  against the marker directory for non-reviewer personas. Workarounds exist for
  two of the seven (`git commit -F`, `grep -r`); `git log -- <markerdir>` is
  simply withdrawn.
- **(b) Remove `git` only; keep `rg` and its flag scan.** Defensible on the
  measured asymmetry: `rg`'s vector needs an environment variable, and `export`
  does not persist between Bash tool calls, so arming it requires a session
  boundary. Keeps `rg pat <markerdir>` working and preserves half of case 28.
  Measured cost against the untouched suite: 112 `FAIL` instead of 221. **Cost:**
  the gate then rests on a subtle "this one is only reachable across a session
  boundary" distinction — and every bug this file has produced came from a
  subtle distinction eroding. `grep` already covers `rg`'s use case, so the
  functional gain is small.
- **(c) Keep both and build the config-pinning rewrite.** Mechanically possible
  (`updatedInput.command` exists). Rejected as a default on soundness, not
  ambition: git's repository-local configuration scope cannot be blanket-
  neutralized, so it still needs a per-key enumeration that fails open. Also the
  largest change this file has ever taken, on a file with two `.fail` records.
  If chosen, this is a multi-unit epic, not this spec.
- **(d) Document only; change no code.** Cheapest and honest about the residual,
  but leaves live the one variant that is armed on disk and effective on the
  very next tool call — the most reachable member of the class. Step 2 is
  required under *every* option, so (d) is strictly a subset of (a).

### OQ2 — How explicit should the public prose be?

- **(a) Describe the class abstractly; name no program, key, or variable —
  recommended default.** Matches #184's and #186's existing redaction posture,
  and is enough for a reader to calibrate trust in the gate. Encoded as the
  machine-checkable AC2.4.
- **(b) Full detail in the CHANGELOG once the fix ships.** Defensible for a
  fixed bug, but the *class* is not fully fixed — R-a through R-d stay open, so
  detail would be a live roadmap rather than a post-mortem.
- **(c) Minimal — a version note only.** Rejected: leaving the "checks what a
  command does" claim uncorrected is the specific harm Step 2b exists to
  prevent, and is the same overclaim shape as #184's Amendment A5.

### OQ3 — What becomes of #184's technique?

- **(a) Delete the code; carry the lesson into the wiki, and record the
  supersession as an appended amendment on #184's spec doc — recommended
  default.** Encoded as Step 3 and the scribe hint. A disabled or commented-out
  test asserts nothing and rots.
- **(b) Keep cases 28/29 in a skipped block for future reuse.** Rejected as a
  default (RD3): it reintroduces exactly the never-failing test shape #184's
  Amendment A5 was written about.
- **(c) File a follow-up issue re-examining the gate's premise** — that
  name-based allowlisting can bound behaviour at all — as a roadmap item rather
  than a limitation note. **This is compatible with (a) and worth doing if the
  human wants the premise question tracked rather than ratified.** Not folded
  into the default because filing an issue that nobody intends to action is
  worse than the wiki note.

---

## Self-check

- CHK1: Does the plan state, in its own text, whether a `PreToolUse` hook can
  neutralize state affecting a *later* tool call — the orchestrator's explicit
  question? — PASS ("Is this fixable at all?" answers it directly: no stateful
  tracking is needed, because the state is ambient at trigger time; the obstacle
  is the open-ended enumeration, not the hook lifecycle)
- CHK2: Is each rejected fix approach rejected with a measurement rather than an
  assertion? — PASS ("Why the obvious fixes fail": 44 documented keys for (i);
  12 effective keys including 2 execution-capable global ones for (ii); the
  repository-local-scope gap for (iii); the early-exit and hot-path cost for
  (iv))
- CHK3: Is the acceptance criterion for "the fix worked" distinguishable from
  "the tests are green"? — FAIL (missing) — revised in place; AC1.8 now requires
  the reconciled suite to produce **exactly 8** `FAIL` lines against the unfixed
  gate with **every line reading `rc=0`**, which green tests alone cannot
  satisfy
- CHK4: Does the plan say what happens to the assertions that would pass
  vacuously after the removal? — FAIL (missing) — revised in place; the Blast
  radius table names each region, the Step 1 contract says **delete, do not
  re-expect**, and AC1.7 checks mechanically that nothing was left commented-out
  or skipped
- CHK5: Do the Blast-radius numbers and Step 1's criteria agree on the expected
  suite size? — PASS (both cite 90 `OK` measured, AC1.9 floors at `>= 88`)
- CHK6: Is the lost functionality stated plainly, or softened? — PASS (RD4
  enumerates all seven lost commands, states that two have workarounds and that
  `git log -- <markerdir>` has none, and OQ1(a) repeats it rather than burying
  it)
- CHK7: Is "out-of-band configuration" defined before it is used? — PASS
  (Clarifications, Domain entities entry)
- CHK8: Does the plan distinguish what this fix closes from what it does not? —
  PASS (R-a through R-d, and Step 2b publishes the distinction rather than
  leaving it in this doc)
- CHK9: Is the disclosure discipline checkable, or only stated as an intention?
  — FAIL (ambiguous) — revised in place; AC2.4 is now a `grep -ciE` over the
  step's own diff with an expected count of `0`, re-run over `CHANGELOG.md` by
  AC3.5
- CHK10: Do Steps 1, 2 and 3 agree on which files they touch, and is the union
  closed? — PASS (each step's affected-files line is exact; RD5 states what may
  not be touched; the unions are disjoint except for `CHANGELOG.md`, owned by
  Step 3)
- CHK11: P1 — is any Context claim unmeasured? — PASS (the one inherited claim,
  the reviewers' severity finding, is explicitly labelled as established and
  deliberately not re-derived, with the safety reason; every other claim carries
  its own measurement)
- CHK12: P3 — does the plan name a version and justify major/minor/patch? — PASS
  (RD8 and AC3.1: `0.17.0`, minor because behaviour is removed, with the #181
  precedent and a confirm-don't-assume guard)
- CHK13: P5 — does every step terminate in `tests/validate.sh`? — PASS (AC1.10,
  AC2.6, AC3.6)
- CHK14: P4 — is the reviewer GRANT / no-reviewer fallback preserved, and
  asserted? — PASS (RD5 forbids touching them; AC1.11 runs the identity suite)
- CHK15: Is it stated that this unit is not `haiku`-eligible, with the record
  behind it? — PASS (RD1, citing `177.fail`, `182.fail` and the #182 → #183
  escalation)
- CHK16: Is the mutation control's invocation stated precisely enough that a
  reviewer running it gets a meaningful result on the first try? — FAIL
  (ambiguous) — revised in place; AC1.8 now requires an **absolute**
  `GATE_UNDER_TEST` path and records that a relative one yields `rc=127` on
  every case, which was a real false reading during this spec's measurement
- CHK17: Does the plan say who decides between the postures, rather than
  silently picking one? — PASS (OQ1 lists four with costs; every step that
  depends on the choice says so in its own heading or preamble)
- CHK18: Is the new `grep` inventory observation routed somewhere, rather than
  dropped or expanded here? — PASS (R-c and Step 3: one abstract comment on
  #185, explicitly not investigated in this unit)

*Re-check of the four FAILs after the single revision pass: CHK3, CHK4, CHK9 and
CHK16 all now PASS against the revised text. No item remains failing, so nothing
is carried into Open Questions from the Self-check. OQ1-OQ3 originate from the
taxonomy's Partial/Missing categories (functional scope, technical constraints,
edge cases), not from a failed check.*

---

## Scribe update hint

After this unit lands:

- `.claude/wiki/modules/hooks.md` — the gate's row changes twice over: the
  allowlist's membership, and the gate's *claim*. The second matters more.
  Record the guardrail-not-boundary sentence verbatim.
- **A wiki entry worth its own heading: an allowlist over program *names* is not
  an allowlist over *behaviour*.** This file produced three bugs of one class
  (#177, #182, #184) by getting text-scanning predicates wrong, and then a
  fourth (#186) that no predicate could have caught, because the decisive input
  was never in the text. The enumerated ten-metacharacter set was the project's
  answer to the first three; there is no equivalent answer to the fourth, and
  the honest response was to shrink what the allowlist claims.
- **Carry #184's technique lesson forward even though its code is deleted:** a
  *differential* sweep needs the reference implementation to produce an
  observable effect in the sandbox; where it cannot, the honest form is a
  one-directional block assertion with an explicit mutation control. That
  distinction now survives only in the wiki, in #184's spec doc, and in case
  26 — it is no longer demonstrated by live code.
- `CONTEXT.md` glossary — add **out-of-band configuration**.
- No new ADR. This refines ADR 0002's enforcement story rather than making a new
  decision; ADR 0002's own decision is untouched.

---

## Publication

Tracked as **https://github.com/Storreslara/AntiSlop/issues/186**, already
labelled `ready-for-agent`. Per the disclosure posture at the top of this
document, the `to-spec` publish step is **deliberately reduced to an
administrative pointer**: the issue body stays redacted and is not edited, and
no PRD comment carrying Problem Statement / Solution / User Stories detail is
posted while this is unfixed, because under this spec's own mapping those
sections would carry the mechanism detail the redaction exists to withhold.
This document is the canonical artifact and the dispatch source;
`task-master` slices from it directly.
