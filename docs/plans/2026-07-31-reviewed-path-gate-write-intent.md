# Marker-directory gate: narrow to write-intent, and close the Write/Edit hole

Date: 2026-07-31 | Author: spec-master | Source issue: **#155** (`Storreslara/AntiSlop`)
Status: **Finalized** — ready for `task-master` slicing.
Amended: 2026-07-31 (A1-A3, mid-flight — see Amendment log).

## Amendment log

Mid-flight spec amendments made by `spec-master` after `lead-programmer` opened
#177 and escalated an unsatisfiable acceptance criterion. `lead-programmer` and
the orchestrator correctly declined to self-authorize these; spec substance is
`spec-master`'s to own.

- **A1 — Step 1 criterion 2 was unsatisfiable as written.** It required
  `bash tests/agent-identity-namespace.test.sh` to pass with "S1/S2 unchanged
  and untouched", while Step 1's own required behaviour contradicts two S1
  assertions. **Ruling: the shared fixture at
  `tests/agent-identity-namespace.test.sh:79` changes from a read-only payload
  to a write-intent one.** Step 1's affected-files line and criterion 2 are
  amended to permit exactly that edit. Verified by re-running the suite: 2 FAIL
  before, and all six S1/S2 identity assertions hold under the write payload.
- **A2 — the benign check moves *before* the empty-`agent_type` fallback
  block.** `lead-programmer` had placed it after, per Step 1's literal
  "between the identity checks and the final block", which left a main session
  with an unset `agent_type` blocked on read-only commands. **Ruling: place it
  before that block.** Grounds and measurements in the new Clarifications entry
  and R9.
- **A3 — a third gap, found live during this ruling and not previously
  recorded.** Step 1's condition 1/2 scan the command text without regard to
  shell quoting, so a `>`, `;`, `|` or `&&` occurring **inside a quoted string
  literal** is read as an operator. This blocks benign prose that Goal item 1
  explicitly requires to be allowed (a `gh` issue body or `git commit -m`
  message containing `->`), and `2>&1` / `2>/dev/null` on an otherwise
  read-only command. **Ruling: Step 1 is NOT expanded** — the imprecision
  fails *closed* (measured, R8), so it is a false-positive residue, not a
  security hole. It is recorded as R8, pinned as Step 3 controls, and fixed by
  a new **Step 6**, sequenced *after* Step 3 so the risky matcher refinement
  lands with the regression suite already protecting it.

## Goal

Make the marker-directory gate check *what a command does* instead of *what
its text contains*, so that:

1. Benign Bash commands that merely mention the marker directory in prose (a
   `gh` issue body, a `git commit -m` message) are allowed.
2. Read-only inspection of the marker directory is allowed.
3. Actual writes to the marker directory are blocked for non-reviewer
   personas **on the Write/Edit tool path as well as the Bash path** — today
   the Write path is completely ungated.

The gate's invariant is unchanged and non-negotiable: **only the reviewer
persona creates a `.pass`/`.fail`/`.blocked` record** (ADR 0002), with the
documented no-reviewer fallback for the main session.

## Context

`hooks/scripts/reviewed-path-gate.sh` (PreToolUse/Bash) blocks any Bash
command whose raw text contains the literal substring for the marker
directory. It does not inspect what the command does. Issue #155 records four
personas — orchestrator, scribe, lead-programmer, and a task-master session —
independently rediscovering the same workaround (restructure prose to break
the substring, or move text into a file via `git commit -F`).

**All findings below were measured on 2026-07-31 by piping canned payloads to
the live hooks, not inferred from prose.**

| Command | Caller | Result |
|---|---|---|
| `gh issue close N --comment "…<markerdir>/N.pass"` | scribe | BLOCKED — no filesystem access at all |
| `ls -la <markerdir>/` | task-master | BLOCKED — read-only |
| `git commit -m "…<markerdir>…"` | lead-programmer | BLOCKED |
| `printf x > <markerdir>/9.pass` | lead-programmer | BLOCKED (correct) |
| `printf x > <markerdir>/9.pass` | reviewer | allowed (correct) |
| `d=.claude/re; printf x > ${d}viewed/9.pass` | lead-programmer | **ALLOWED — a real write** |
| Write **tool** → `<markerdir>/9.pass` | lead-programmer | **ALLOWED** |

### The finding that sets this plan's risk posture

Issue #155 frames "rewrite the matcher" as its riskiest direction, because the
gate is fail-closed security machinery. **The measurements above invert that.**
The gate is not currently a security boundary on either available path:

- The Bash matcher is defeated by a 20-character variable split (row 6).
- The Write/Edit path is entirely ungated (row 7). `hooks/hooks.json:13-18`
  wires only `protected-paths.sh` on `Write|Edit`, and that script is purely
  config-driven off `persona-config.json`'s `protectedPaths`, which in this
  repo lists only `.github/workflows/*` and `.claude/constitution.md`.

Narrowing the matcher therefore **cannot lose enforcement that does not
exist**. The real risk in this plan is implementation bugs in the new matcher,
which Step 3's regression suite exists to catch. Closing the Write hole
(Step 2) is a *net increase* in real enforcement, and is the reason this plan
is a security improvement overall rather than a relaxation.

### Two further defects found

- **The block message is actively wrong.** It advises "Read-only commands are
  blocked too - use the Read tool for that." The Read tool cannot list a
  directory, so this instruction is unfollowable for the exact case a
  task-master session hit. `spec-master`'s own protocol requires it to check
  `.fail` records, which this forbids.
- **"Document the actual behavior" is largely already done.**
  `docs/design.md:118-130` and `README.md:179` already describe the substring
  match and its bypass accurately. The stale prose is in the block message,
  the script header, and the wiki — not the design docs.

### Blast radius (measured, exact)

- `hooks/scripts/reviewed-path-gate.sh` is the only implementation and the
  **only hook in the repo that reads `tool_input.command`** — there is no
  existing shell-command-parsing helper to reuse. `dispatch-hygiene.sh`'s H3
  parses a structured `Unit:` line, not shell syntax; it is a precedent for
  scoping discipline, not reusable code.
- **Not ported to the adapters.** `adapters/cursor/hooks/scripts/` and
  `adapters/codex/hooks/scripts/` contain `reviewer-route-gate.sh` but **no**
  `reviewed-path-gate.sh`. No adapter port is in scope.
- `bin/cli.js:1686` copies `hooks/scripts/*.sh` wholesale into the standalone
  `.claude/hooks/scripts/` scaffold. **No manifest registration exists or is
  needed**, including for a new lib file.
- `tests/validate.sh:221-230`'s byte-identity check is hardcoded to
  `agent-identity.sh` only; a new lib file is not covered by it.
- **No matcher test exists today**, and the pre-existing coverage is **not**
  cleanly separable from the matcher. *(Corrected 2026-07-31 — see Amendment
  A1. This bullet previously read "Coverage in
  `tests/agent-identity-namespace.test.sh` (S1/S2) is identity-only." That
  premise was **false** and it is the root cause of Amendment A1.)* S1/S2 assert
  identity outcomes, but they do so **through** a shared fixture,
  `tests/agent-identity-namespace.test.sh:79`:

  ```
  marker_payload() { printf '{"agent_type":"%s","tool_input":{"command":"ls .claude/reviewed"}}' "$1"; }
  ```

  That payload is a **read-only** command. S1 uses it to assert rc=2 for
  `otherplugin:reviewer` (`:91`) and `antislop:lead-programmer` (`:98`) — i.e.
  it asserts that a read-only listing is *blocked*, which is exactly the
  behaviour Step 1 removes. The identity assertions and the matcher semantics
  are therefore entangled in one fixture, and Step 1 cannot be implemented
  without touching it.
- Merge gate is `bash tests/validate.sh`.
- Live versions are aligned at `0.15.0` (`.claude-plugin/plugin.json`,
  `package.json`, `persona-config.json`'s `pluginVersion`). The stale
  `0.13.17` drift recorded in the wip attack-order doc's C1 is resolved.

### Assumption flagged for readers of the wip attack-order doc

`docs/plans/wip/2026-07-30-master-cross-plan-attack-order.md`'s Wave 3 table
lists **#124 as "OPEN, not started"**. It is in fact **CLOSED and landed** —
the terminal-status-line rule is live in `templates/persona-protocol.md:82-87`
and in the persona mirrors. That doc's §1 warns "tracker state is not
completion state"; this is the same hazard in the opposite direction, and its
version-collision analysis (C1) is likewise stale. **Do not sequence from that
doc's tables without re-verifying against `gh` and the live files.** Fixing
that doc is *not* in this plan's scope.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-31 Functional scope & success criteria: Q Which of issue #155's three
  directions should be built — document-only, an escape hatch, or narrowing the
  matcher to write-intent? → A: (a) narrow to a write-intent allowlist, and fix
  the misleading block message.
- 2026-07-31 Technical constraints & tradeoffs: Q Should this spec also close
  the ungated Write/Edit path, or leave it to a follow-up? → A: yes, include it
  in this spec.
- 2026-07-31 User interaction flow: Q Should read-only access to the marker
  directory be allowed outright, or should only text-mentions be unblocked
  (preserving the deliberate read-block recorded in the script header,
  lines 23-29)? → A: allow read-only access outright.
- 2026-07-31 Non-functional attributes: Q Should the narrowed matcher be
  denylist-shaped (block on mutation operators) or allowlist-shaped (allow only
  provably-benign shapes)? → A (self-resolved): allowlist-shaped. A denylist
  fails **open** on any command form its authors did not enumerate; an
  allowlist fails **closed**, preserving the gate's current posture for
  everything unrecognized.
- 2026-07-31 Technical constraints & tradeoffs: Q The answer to OQ2 said "add
  the marker directory to `protectedPaths`" — is that mechanism sufficient? →
  A (self-resolved): **no, and this plan deliberately implements the intent by
  another route.** Measured: `protectedPaths` defaults to `[]` in all three
  `bin/cli.js` scaffolds (`:1088`, `:1463`, `:1772`) and `runUpdate` preserves
  it "exactly as recorded" (`:1752-1762`), so already-adapted downstream
  projects would **never** receive the new entry. `protected-paths.sh` also
  consults no agent identity, so it would block the reviewer too. Step 2
  therefore extends the identity-aware marker gate itself to `Write|Edit`,
  which reaches every project on `--update` because `bin/cli.js:1686` copies
  the script wholesale. Same outcome, actually delivered.
- 2026-07-31 Edge cases / failure handling: Q What happens to the residual
  obfuscation bypass (`d=.claude/re; …`) that defeats the substring trigger? →
  A (self-resolved): it remains open and stays documented as a known
  limitation, unchanged from today. Closing it requires resolving shell
  expansion, which no hook can do without executing the command. Step 3 pins it
  with an explicit control case so it is a *known* state rather than a
  surprise, and Step 4 keeps it named in `docs/design.md`.
- 2026-07-31 Edge cases / failure handling: Q Does the narrowed gate preserve
  the no-reviewer fallback and the reviewer GRANT unchanged on both tool
  paths? → A (self-resolved): yes — both are preconditions, asserted
  explicitly in Steps 1-3, and the existing S1/S2 cases in
  `tests/agent-identity-namespace.test.sh` must keep passing untouched.
- 2026-07-31 Non-functional attributes: Q Should the new behaviour ship
  plugin-wide to already-adapted projects on `--update`, and does it need a
  config knob (`warn`/`block`)? → A (self-resolved): ships plugin-wide, no
  knob — always block. Precedent: the token-hygiene dispatch gate shipped
  blocking-by-default plugin-wide and was accepted as-is. A knob here would let
  a project silently disable the review-ownership invariant.
- 2026-07-31 Domain entities / data model: Q Does the gate cover all three
  marker kinds? → A (self-resolved): yes — `.pass`, `.fail` and `.blocked`
  (`agents/reviewer.md:91,111,124`) all live in the same directory and are
  covered by a directory-level rule; no per-extension logic is needed.
- 2026-07-31 Completion / acceptance signals: Q What is the acceptance signal?
  → A (self-resolved): `bash tests/validate.sh` green, with the new
  `tests/reviewed-path-gate.test.sh` registered in it.
- 2026-07-31 Terminology consistency: Q Is the directory referred to
  consistently? → A (self-resolved): yes — "marker directory" in prose,
  `.claude/reviewed/` in code/config. This document deliberately writes
  `<markerdir>` in shell examples so that quoting a criterion from it does not
  itself trip the very gate under change.
- 2026-07-31 External dependencies & integrations: Q Does this unblock #154
  (scribe closing issues with an audit-trail comment)? → A (self-resolved):
  yes — that scenario is Step 3's criterion 2, so #154 becomes speccable.
  #154 itself stays out of scope. **Qualified by A3:** it is unblocked only for
  comment bodies free of `>`, `;`, `|`, `&&`; full delivery needs Step 6.

*Appended 2026-07-31 during the mid-flight amendment (A1-A3):*

- 2026-07-31 Completion / acceptance signals: Q Step 1 criterion 2 demands
  `tests/agent-identity-namespace.test.sh` pass "unchanged and untouched", but
  its `:79` fixture asserts a read-only command is blocked — the behaviour
  Step 1 removes. Amend the criterion, drop it, or defer the fixture edit to
  Step 3? → A (self-resolved): **amend the criterion and edit the fixture in
  Step 1.** Deferring leaves the suite red at the head of a five-unit chain,
  and dropping the criterion removes Step 1's only identity regression guard.
  Measured: baseline 0 FAIL; Step 1 applied → exactly 2 FAIL (both S1, at `:91`
  and `:98`); with the fixture switched to write-intent → all six S1/S2
  assertions (reviewer GRANT ×2, foreign-namespace denial, lead-programmer
  denial, main-session block, no-reviewer fallback) pass. The identity coverage
  is preserved verbatim and merely re-expressed in the new semantics.
- 2026-07-31 Edge cases / failure handling: Q Should a session with an empty
  `agent_type`, in a project that *does* have a reviewer selected, be allowed
  read-only access to the marker directory? → A (self-resolved): **yes —
  the benign check goes before the fallback block.** Three grounds. (i) The
  human's own earlier answer was "allow read-only access **outright**", and
  "outright" admits no identity carve-out. (ii) ADR 0002's invariant is about
  *write* ownership; a read cannot violate it, so blocking one identity class's
  reads protects nothing. (iii) Measured, and decisive: the main session's
  `agent_type` is empty exactly when `settings.json`'s `.agent` is unset
  (`docs/experiments/2026-07-probe-hook-payloads.md:255` records that an
  *adopted* orchestrator arrives as the bare string `orchestrator`, not as
  empty) — so the stricter placement penalises precisely the projects that did
  not adopt the optional `orchestrator` persona, inverting constitution P4.
  Verified: no S1/S2 assertion changes between the two placements. See R9.
- 2026-07-31 Functional scope & success criteria: Q The operator scan and
  segment split are quote-unaware, so benign prose containing `->` or `;` and
  read-only commands using `2>/dev/null` are still blocked — does Step 1 widen
  now, or is this a follow-up? → A (self-resolved): **follow-up, as a new
  Step 6 sequenced after Step 3.** The imprecision fails *closed* (R8, measured:
  six over-blocks, zero under-blocks), so nothing is unsafe in the interim.
  Widening the matcher mid-Step-1 would land the single riskiest edit in the
  plan — quote-aware shell lexing, the exact hazard class R2 names — with **no**
  regression suite in place, since Step 3 is what builds one. Sequencing it
  after Step 3 puts the safety net under the risky change instead of after it.
  The cost is honest and is stated rather than hidden: between Step 1 and
  Step 6, Goal items 1 and 2 are only partially delivered, and Step 3 cases
  20-22 assert that partial state explicitly so it reads as a known position
  rather than a bug.

## Risks / dependencies

- **R1 — This is fail-closed security machinery; a matcher bug that fails
  *open* is the main hazard.** The allowlist architecture is chosen precisely
  so the default for anything unrecognized is *block*. Any implementation that
  inverts this (enumerating bad commands rather than good ones) must be
  rejected at review.
- **R2 — Not `haiku`-eligible.** The adjacent agent-identity plan's R3 bans
  `haiku` for this logic outright, on the record that this exact matcher family
  has already produced two subtle under-match bugs that survived review. Step 1
  and Step 2 are shell-parsing security logic and carry the same hazard.
  (Per-unit model tagging is `task-master`'s call — this is defect history for
  it to weigh, not a tag.)
- **R3 — No prior `.fail` record exists for this work.** Checked: #155 has
  never been dispatched, so there is no durable FAIL history for a re-scope.
  R2's caution derives from the *sibling* identity plan, not from this unit.
- **R4 — Acceptance criteria must live in files, not command lines.** A
  criterion that spells the marker path inline is itself subject to the gate.
  All matcher assertions therefore live inside
  `tests/reviewed-path-gate.test.sh`, invoked as `bash tests/…` — a command
  whose own text is clean. The reviewer is GRANTed regardless, but a
  lead-programmer running its own tests is not.
- **R5 — Step 2 changes `hooks/hooks.json`, which is behaviour for every
  adapted project on `--update`.** Downstream projects gain a *new blocking
  gate on the Write/Edit path*. This is the intended, accepted increase in
  friction, and the CHANGELOG must lead with it (Step 5).
- **R6 — Ordering.** Step 3 depends on Steps 1 and 2 (it tests them).
  **Step 6 depends on Step 3** and must merge *after* it. Step 5 depends on all
  of 1-4 **and 6** and must merge last. Steps 1, 2 and 6 touch the same file and
  must not be split across concurrent sessions. *(Amended per A3. Note the
  merge order is 1 → 2 → 3 → 4 → 6 → 5; Step 6 is numbered last but sequenced
  before Step 5, because appending was preferred over renumbering four
  already-filed issues. Number order is not merge order — read this bullet, not
  the headings.)*
- **R8 — Residual false positives: the operator scan and the segment split are
  quote-unaware.** *(Added per A3, measured 2026-07-31 against the live hook.)*
  Conditions 1 and 2 of "provably benign" inspect the raw command text, so a
  `>`, `;`, `|` or `&&` **inside a quoted string literal** is read as an
  operator, and `2>&1` / `2>/dev/null` are read as writes. Measured
  consequences — all **over**-blocks:

  | Command | Spec says | Today |
  |---|---|---|
  | `gh issue close 9 --comment "<markerdir>/9.pass"` | allow | allow |
  | `gh issue close 9 --comment "<markerdir>/9.pass -> merged"` | allow | **block** |
  | `git commit -m "<markerdir>/9.pass -> done"` | allow | **block** |
  | `gh issue close 9 --comment "<markerdir>/9.pass; then merge"` | allow | **block** |
  | `ls <markerdir> 2>/dev/null` | allow | **block** |
  | `cat <markerdir>/9.fail 2>&1` | allow | **block** |

  **The direction of this imprecision is the reason it is tolerable
  short-term:** treating quoted text as operators can only ever find *more*
  operators and split into *more* segments than a real shell would, so every
  error is an extra chance to fail the allowlist. It fails **closed**. The same
  probe confirmed zero false negatives across `printf >`, `rm`, `git rm`, `tee`,
  compound-`rm`, and `rm` following quoted prose. This is a delivery gap against
  Goal items 1 and 2, **not** a weakening of R1's posture — which is precisely
  why it is Step 6 rather than an emergency widening of Step 1.
- **R9 — The benign check's placement relative to the no-reviewer fallback is
  load-bearing, and the two placements are behaviourally distinguishable by
  exactly one case.** *(Added per A2.)* Placed *after* the fallback block, a
  session whose `agent_type` is empty is blocked on read-only commands whenever
  a reviewer is selected. That is measured to matter: the main session's
  `agent_type` is empty precisely when `settings.json`'s `.agent` is **unset** —
  i.e. in projects that did *not* adopt the `orchestrator` persona. Those
  projects would get strictly worse behaviour than persona-adopting ones for a
  read-only command, which inverts constitution **P4** ("optional personas
  degrade gracefully"). Placed *before*, every S1/S2 assertion still holds
  (verified). Step 1 criterion 3 and Step 3 case 14b both pin the placement, so
  a future refactor cannot silently reintroduce it.
- **R7 — Version.** Live stamp is `0.15.0` everywhere; this plan takes
  `0.16.0`. **Confirm, do not assume** — re-read `.claude-plugin/plugin.json`
  at implementation time in case a sibling plan lands first.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — every premise in Context was
  measured against the live hooks, and Step 3 converts those measurements into
  a durable regression suite rather than leaving them as prose.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  no hand-editing of script-driven files; Step 5 uses `node bin/cli.js
  --update` to regenerate mirrors.
- P3 "Version-stamp discipline" (MUST): satisfied — Step 5 bumps
  `.claude-plugin/plugin.json` and adds a CHANGELOG entry.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the
  no-reviewer fallback is preserved unchanged and explicitly re-asserted in
  Steps 1-3, so a project without a `reviewer` persona is unaffected.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — Step 3
  registers the new suite in it; every step terminates in it.

---

## Step 1 — Narrow the Bash matcher to write-intent, and correct the block message

**Affected files:** `hooks/scripts/reviewed-path-gate.sh`, and — **per
Amendment A1** — exactly one line of `tests/agent-identity-namespace.test.sh`
(the `marker_payload` fixture on `:79`). No other line of that test file may
change.

Keep unchanged: the substring early-exit (it is a cheap hot-path filter, and
this hook fires on *every* Bash call), the reviewer GRANT via
`persona_matches_grant`, the no-reviewer fallback via `persona_matches_gate`,
and the `identity_drift_log` call placement after the early exit.

**Fixture change required by A1.** `tests/agent-identity-namespace.test.sh:79`
currently builds S1/S2's payload from a **read-only** command, and S1 asserts
that command is *blocked* for non-reviewers — the exact behaviour this step
removes. Change the fixture's command to a **write-intent** one (a redirect
into the marker directory, e.g. `printf x > .claude/reviewed/9.pass`). This
re-expresses every existing S1/S2 assertion in the new semantics without
weakening any of them; all six were verified to still hold. Change nothing
else in that file — the assertions, expectations and case labels stay as they
are.

**Placement, per Amendment A2.** Insert the new decision immediately **after**
the reviewer GRANT and **before** the `[ -z "$agent_type" ]` no-reviewer
fallback block — *not* after it. A read-only command must be allowed for
**every** identity, including a main session whose `agent_type` is empty in a
project that does have a reviewer selected. (The earlier wording "between the
identity checks and the final block" was ambiguous on this point and is
superseded.)

If the command is **provably benign**, allow it. Provably benign means all of:

1. The command contains none of `>`, `` ` ``, `$(`, and none of the words
   `eval`, `exec`, `source`. (`>` covers `>>`.)
2. Splitting the command on `;`, `&&`, `||`, `|` and newline, **every**
   segment's first word is in the allowlist below (a leading `VAR=value`
   assignment disqualifies the segment).

Allowlist — read-only or non-local-writing programs only:
`ls`, `cat`, `head`, `tail`, `wc`, `stat`, `file`, `test`, `[`, `grep`, `rg`,
`diff`, `cmp`, `sha256sum`, `md5sum`, `basename`, `dirname`, `readlink`,
`realpath`, `echo`, `printf`, `gh`; plus `git` restricted to the subcommands
`commit`, `log`, `show`, `diff`, `status`, `tag`, `blame`.

Deliberately excluded: `find` (its `-delete`/`-exec` forms mutate), `mkdir`,
`touch`, `rm`, `mv`, `cp`, `tee`, `sed`, `dd`, `truncate`, `install`, `ln`.

Rewrite the block message to describe what is actually checked, and **remove
the false "use the Read tool for that" advice**. It must state that read-only
and text-only mentions are allowed, and that this command was blocked because
it was not recognized as either.

**Acceptance criteria**

1. `bash -n hooks/scripts/reviewed-path-gate.sh` exits 0.
2. *(amended per A1 — supersedes "S1/S2 unchanged and untouched", which was
   unsatisfiable)* `bash tests/agent-identity-namespace.test.sh` exits 0 and
   prints no line starting with `FAIL`, **with every S1/S2 assertion,
   expectation and case label unchanged** — the only permitted edit to that
   file is the one-line `marker_payload` fixture on `:79`. Pin the confinement
   mechanically:

   ```
   test "$(git diff --numstat -- tests/agent-identity-namespace.test.sh | awk '{print $1"/"$2}')" = "1/1"
   ```

   (one line added, one removed — anything else means more than the fixture
   moved).
3. *(added per A2)* The benign check is placed **before** the no-reviewer
   fallback block, not after:

   ```
   b=$(grep -n 'if command_is_provably_benign' hooks/scripts/reviewed-path-gate.sh | cut -d: -f1)
   f=$(grep -n 'if \[ -z "\$agent_type" \]'   hooks/scripts/reviewed-path-gate.sh | cut -d: -f1)
   test -n "$b" && test -n "$f" && test "$b" -lt "$f"
   ```
4. `grep -c 'use the Read tool for that' hooks/scripts/reviewed-path-gate.sh`
   prints `0`.
5. `bash tests/validate.sh` exits 0.

---

## Step 2 — Extend the same gate to the Write/Edit tool path

**Affected files:** `hooks/scripts/reviewed-path-gate.sh`, `hooks/hooks.json`

Give the hook a second input shape rather than adding a second script: when
`tool_input.command` is absent, read `tool_input.file_path` and apply the
*same* identity rules (reviewer GRANT, no-reviewer fallback, otherwise block).
No allowlist applies on this path — a Write or Edit to the marker directory is
a write by definition.

Register the script on the existing `Write|Edit` PreToolUse matcher in
`hooks/hooks.json`, alongside `protected-paths.sh`. Leave `protected-paths.sh`
and `protectedPaths` untouched — see the Clarifications entry explaining why
the config route cannot reach already-adapted projects.

Normalize `file_path` against `CLAUDE_PROJECT_DIR` before matching, the same
way `protected-paths.sh:22-25` does, so an absolute path still matches.

**Acceptance criteria**

1. `jq -e '.hooks.PreToolUse[] | select(.matcher=="Write|Edit") | .hooks | map(.command) | any(endswith("reviewed-path-gate.sh"))' hooks/hooks.json` exits 0.
2. `jq -e . hooks/hooks.json` exits 0 (valid JSON).
3. `git diff --quiet HEAD -- hooks/scripts/protected-paths.sh` — that file is
   not modified by this step.
4. `bash tests/validate.sh` exits 0.

---

## Step 3 — Regression suite

**Affected files:** `tests/reviewed-path-gate.test.sh` (new),
`tests/validate.sh`

Follow the established harness shape: canned JSON piped over stdin to the
script, fixture `persona-config.json` under a `mktemp -d`, `pass`/`bad`
helpers, no `claude` CLI and no network — model it on
`tests/dispatch-hygiene.test.sh` and `tests/agent-identity-namespace.test.sh`.
Per R4, every assertion that spells the marker path lives **inside this file**.

Fixture hygiene, carried from the sibling suite: set `testAndLintCommand` to a
trivial command, never this repo's `bash tests/validate.sh`, since this suite
runs *from* validate.sh.

Required cases, at minimum:

*Now-allowed (the false positives from #155):*
1. `gh issue close N --comment "…<markerdir>/N.pass"` as scribe → allowed.
2. `gh issue create --body "…<markerdir>/N.pass…"` as orchestrator → allowed
   (this is #154's blocked scenario).
3. `ls -la <markerdir>/` as task-master → allowed.
4. `cat <markerdir>/N.fail` as spec-master → allowed.
5. `git commit -m "…<markerdir>…"` as lead-programmer → allowed.

*Still blocked (write intent):*
6. `printf x > <markerdir>/9.pass` as lead-programmer → blocked.
7. `rm <markerdir>/9.pass`, `mv`, `cp`, `tee`, `touch`, `mkdir -p`, `sed -i`
   forms as lead-programmer → each blocked.
8. `ls <markerdir>/ && rm <markerdir>/9.pass` → blocked (compound; second
   segment not allowlisted).
9. `ls <markerdir>/; printf x > <markerdir>/9.pass` → blocked (redirection).
10. `gh issue view 1 --json body > <markerdir>/9.pass` → blocked (redirection
    despite an allowlisted program).
11. `eval "…"`, `` `…` `` and `$(…)` forms naming the path → each blocked.
12. `git rm <markerdir>/9.pass` → blocked (non-allowlisted git subcommand).

*Identity rules preserved:*
13. Reviewer performing case 6 → allowed (GRANT intact).
14. *(amended per A2 — the command kind is now load-bearing and must be
    stated)* Empty `agent_type` performing **case 6's write-intent command**:
    with no reviewer in `personaSelection` → allowed (fallback intact); with a
    reviewer selected → blocked.
14b. *(added per A2)* Empty `agent_type` performing **case 3's read-only
    command**, with a reviewer selected in `personaSelection` → **allowed**.
    This is the placement assertion: read-only access is allowed outright, for
    every identity, and does not depend on the no-reviewer fallback. A suite
    that omits this case cannot tell A2's placement from the rejected one.

*Write/Edit path (Step 2):*
15. Write to `<markerdir>/9.pass` as lead-programmer → blocked.
16. Write to `<markerdir>/9.pass` as reviewer → allowed.
17. Write to an unrelated path as lead-programmer → allowed (no
    over-blocking).
18. Absolute-path form of case 15 → blocked (normalization works).

*Documented known limitations, pinned as controls:*
19. `d=.claude/re; printf x > ${d}viewed/9.pass` → **allowed**, asserted
    explicitly with a comment naming it as the accepted residual bypass from
    the Clarifications log, so a future reader sees a known state rather than
    a gap.

*(Cases 20-22 added per A3. These pin the quote-unaware residue described in
R8. They are **fail-closed over-blocks, not bypasses** — each is written with a
comment saying so and naming Step 6 as the fix. Step 6 flips all three to
`allowed`; until then the suite asserts the current, known state.)*

20. `gh issue close 9 --comment "<markerdir>/9.pass -> merged"` as scribe →
    **blocked today**. The `>` lives inside a quoted string, not in operator
    position. This is a miss against Goal item 1, which names `gh` issue
    bodies explicitly.
21. `ls <markerdir> 2>/dev/null` as task-master → **blocked today**. `2>&1` and
    `2>/dev/null` are fd redirections, not writes to the marker directory; this
    is a miss against Goal item 2.
22. `gh issue close 9 --comment "<markerdir>/9.pass; then merge"` as scribe →
    **blocked today**. Segment splitting is likewise quote-unaware, so `then`
    is read as a segment-leading program and fails the allowlist.

Register the suite in `tests/validate.sh` following the existing block shape
(compare `:251`).

**Acceptance criteria**

1. `bash tests/reviewed-path-gate.test.sh` exits 0 and prints no line starting
   with `FAIL`.
2. `grep -c 'tests/reviewed-path-gate.test.sh' tests/validate.sh` is `>= 1`.
3. `bash tests/validate.sh` exits 0 and its output contains
   `OK   tests/reviewed-path-gate.test.sh`.
4. Mutation control: reverting Step 1's allowlist block makes
   `bash tests/reviewed-path-gate.test.sh` exit non-zero (the suite actually
   detects the change it exists to protect).

---

## Step 4 — Correct the prose that describes the gate

**Affected files:** `hooks/scripts/reviewed-path-gate.sh` (header comment),
`docs/design.md`, `README.md`, `.claude/wiki/modules/hooks.md`, `CONTEXT.md`,
`docs/adr/0002-reviewed-dir-owned-by-reviewer.md`

- Script header lines 23-29 currently record read-only blocking as accepted
  collateral. That decision is reversed — rewrite to describe the allowlist,
  and keep the obfuscation bypass named as the residual limitation.
- `docs/design.md:118-130` — replace the "blocks any Bash command whose text
  merely *contains* the substring" sentence with the write-intent description;
  keep the obfuscation caveat; add that the Write/Edit path is now gated.
- `README.md:179` — "substring-match bypass" phrasing needs re-pointing at the
  residual limitation rather than the whole-match behaviour.
- `.claude/wiki/modules/hooks.md:16` — the row says "Blocks Bash commands
  whose text touches"; update to the new behaviour and both matchers.
- `CONTEXT.md:47` — check the gate's one-line description still holds.
- ADR 0002 — append a short "Superseded in part" note: its Consequences
  section says the gate is "stricter than the ADAPT skill's literal step 9
  wording ... this is intentional and correct". Under the new matcher
  `mkdir -p` is still blocked for non-reviewers, so the decision stands; record
  that the *reason* changed from substring-matching to write-intent.

Do **not** attempt to fix `skills/install-antislop/SKILL.md:392`'s
"regardless" wording — ADR 0002 flags it, but it is a separate pre-existing
defect and is out of scope here.

**Acceptance criteria**

1. `grep -rn 'merely \*contains\* the substring' docs/design.md` returns no
   matches.
2. `grep -c 'whose text touches' .claude/wiki/modules/hooks.md` prints `0`.
3. `grep -rniE 'write.intent|write intent' docs/design.md .claude/wiki/modules/hooks.md hooks/scripts/reviewed-path-gate.sh` returns at least one match per file.
4. `bash tests/validate.sh` exits 0.

---

## Step 5 — Version bump, mirror regeneration, CHANGELOG

**Affected files:** `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
`.claude/` mirrors (regenerated, not hand-edited)

Bump to `0.16.0` — **confirm the live stamp first** (R7). Run
`node bin/cli.js --update` to regenerate mirrors rather than hand-editing
(constitution P2).

The CHANGELOG entry must **lead** with the behaviour change for already-adapted
projects: *the Write/Edit tool path to the marker directory is now blocked for
non-reviewer personas, where it was previously ungated.* State it plainly as an
intentional increase in enforcement, not as a fix buried under "Changed". It
must also record the residual obfuscation bypass as still open.

**Acceptance criteria**

1. `jq -r '.version' .claude-plugin/plugin.json` equals `jq -r '.version' package.json`.
2. That version is strictly greater than `0.15.0`.
3. `grep -c '0\.16\.0' CHANGELOG.md` is `>= 1` (adjust if R7 forces a different
   number).
4. `node bin/cli.js --update && git status --porcelain .claude/ | wc -l` prints
   `0` after the regeneration is committed.
5. `bash tests/validate.sh` exits 0.

---

---

## Step 6 — Make the operator scan and segment split quote-aware

*(Added 2026-07-31 per Amendment A3. **Sequenced after Step 3 and before
Step 5** — see R6. Do not start until Step 3's suite is merged and green: this
step's whole safety argument is that the suite exists first.)*

**Affected files:** `hooks/scripts/reviewed-path-gate.sh`,
`tests/reviewed-path-gate.test.sh`

Close R8's residual false positives, which today block benign commands that
Goal items 1 and 2 require to be allowed. Two independent sub-changes:

**6a — quote-aware skeleton.** Before applying condition 1's operator scan and
condition 2's segment split, reduce the command to a *skeleton*: replace the
**contents** of every single- and double-quoted span with an inert placeholder,
leaving the quote characters themselves in place. Apply both conditions to the
skeleton. The allowlist check in condition 2 still reads the real first word of
each segment — only operator *detection* uses the skeleton. Text inside quotes
is an argument, never an operator, so this is a correctness fix, not a
loosening.

**Fail closed on anything the skeletonizer cannot fully resolve** — unbalanced
quotes, or a backslash-escaped quote character anywhere in the command. Such a
command is treated as **not** benign, with no attempt to guess. This preserves
R1: the allowlist's default for the unparseable stays *block*.

**6b — permit fd redirection and `/dev/null` only.** On the skeleton, condition
1's `>` test exempts exactly two closed forms: file-descriptor duplication
(`N>&M`, `>&N`, e.g. `2>&1`, `>&2`) and redirection whose target is literally
`/dev/null` (`>/dev/null`, `2>/dev/null`), where the target must be followed by
whitespace or end-of-command. Every other `>` still disqualifies. Enumerate
these as a closed set; do not generalize to "harmless-looking targets".

Neither sub-change touches the reviewer GRANT, the no-reviewer fallback, the
substring early-exit, the `identity_drift_log` placement, the program
allowlist, or A2's placement.

**Acceptance criteria**

1. `bash -n hooks/scripts/reviewed-path-gate.sh` exits 0.
2. Step 3 cases 20, 21 and 22 are flipped from `blocked` to `allowed` in
   `tests/reviewed-path-gate.test.sh`, and their "fixed by Step 6" comments are
   updated to record that Step 6 landed. **No other case's expectation changes**
   — in particular cases 6-12 and 19 keep their existing verdicts:

   ```
   test "$(git diff -- tests/reviewed-path-gate.test.sh | grep -c '^[-+].*blocked')" -le 6
   ```
3. `bash tests/reviewed-path-gate.test.sh` exits 0 and prints no line starting
   with `FAIL`.
4. `bash tests/agent-identity-namespace.test.sh` exits 0 (A1's fixture still
   holds — a write-intent payload must stay blocked under quote-awareness).
5. Fail-closed guard: a command with an unbalanced quote that names the marker
   directory is **blocked**. Asserted as a new case in
   `tests/reviewed-path-gate.test.sh` (per R4, inside the file).
6. `bash tests/validate.sh` exits 0.

---

## Open Questions

None outstanding. OQ1-OQ3 were answered by the human on 2026-07-31 and are
recorded in Clarifications; the remaining categories were self-resolved from
measured evidence, also recorded there.

**A3's sequencing is the one ruling a human may reasonably want to overturn**,
and it is flagged here rather than buried in Clarifications. Deferring the
quote-awareness fix to Step 6 means that between Step 1 and Step 6 landing, a
`gh` comment or commit message containing `->` or `;` is still blocked — the
#155 friction class, reduced but not eliminated. The recommended default (fix
in Step 6, after the suite exists) is taken because the alternative lands
quote-aware shell lexing with zero test coverage. If the interim friction is
judged worse than that risk, the counter-ruling is to fold 6a/6b into Step 1
and accept an untested matcher rewrite — **not** to leave the gap unrecorded.

## Self-check

- CHK1: Is "provably benign" defined precisely enough for two implementers to
  agree on the same behaviour? — PASS (Step 1 gives an explicit operator
  exclusion list, an explicit split set, and a closed allowlist)
- CHK2: Do Steps 1 and 2 agree on which callers are exempt? — PASS (both
  defer to the same reviewer GRANT and no-reviewer fallback; Step 3 case 14
  and 16 assert it on both paths)
- CHK3: Is the residual obfuscation bypass's disposition stated, rather than
  left implicit? — FAIL (missing) — revised in place; now carried in
  Clarifications, in Step 3 case 19 as a pinned control, and in Steps 4-5.
- CHK4: Does the plan say what happens to `protectedPaths`, given the human's
  answer named it explicitly? — FAIL (conflicting) — revised in place; the
  Clarifications entry records the measured reason the literal route fails and
  Step 2 states the substitute mechanism, so the plan no longer silently
  diverges from the instruction it was given.
- CHK5: Is every acceptance criterion a runnable command with a determinate
  result? — PASS (each is an exit-status or a `grep -c`/`jq -e` with a stated
  expected value)
- CHK6: Do the criteria avoid tripping the very gate under change? — FAIL
  (ambiguous) — revised in place; R4 now states the rule and Step 3 confines
  all path-spelling assertions to the test file.
- CHK7: Is the marker-kind coverage (`.pass`/`.fail`/`.blocked`) defined? —
  PASS (Clarifications; directory-level rule, no per-extension logic)
- CHK8: Do Steps 3 and 5 agree on the acceptance signal? — PASS (both
  terminate in `bash tests/validate.sh`)
- CHK9: Is P4 (optional personas degrade gracefully) addressed for a project
  with no reviewer persona? — PASS (fallback preserved; Step 3 case 14)
- CHK10: Is P3 (version-stamp discipline) satisfied with a concrete number and
  a confirm-don't-assume guard? — PASS (Step 5 + R7)
- CHK11: Does the plan state which steps may not be parallelized? — PASS (R6)
- CHK12: Is the mutation control specific enough to be checkable? — PASS
  (Step 3 criterion 4 names the exact reversion and the expected non-zero
  exit)

*Re-checked 2026-07-31 after amendments A1-A3. CHK13-17 are new; CHK1 and CHK5
were re-run against the amended text and still PASS.*

- CHK13: Does the plan state whether existing test files may be modified by
  Step 1, and if so which lines? — **FAIL (conflicting)** — the original text
  said "S1/S2 unchanged and untouched" in Step 1 while the Blast-radius bullet
  called that coverage "identity-only", and both contradicted Step 3 case 3.
  Revised in place (A1): Step 1's affected-files line now names the one
  permitted line, criterion 2 bounds the diff to `1/1` via `git diff --numstat`,
  and the false Blast-radius premise is struck and corrected in situ.
- CHK14: Is the benign check's position in the decision order defined
  unambiguously enough that two implementers would place it identically? —
  **FAIL (ambiguous)** — "between the identity checks and the final block"
  admits both placements, and they differ behaviourally. Revised in place (A2):
  Step 1 now names the two anchors explicitly, Step 1 criterion 3 pins the
  ordering mechanically, and Step 3 case 14b pins it behaviourally.
- CHK15: Do Step 1's "provably benign" conditions and Goal item 1 agree about
  whether a `gh` issue body containing shell metacharacters is allowed? —
  **FAIL (conflicting)** — Goal item 1 promises it; conditions 1-2 block it.
  Revised in place (A3): R8 records the divergence with a measured table,
  Step 3 cases 20-22 pin the interim state, Step 6 closes it, and the residual
  interim gap is surfaced in Open Questions rather than left implicit.
- CHK16: Does the plan say what happens when a command cannot be parsed
  (unbalanced quotes) once quote-awareness is introduced? — PASS (Step 6's
  fail-closed clause and criterion 5).
- CHK17: Do the step numbering and the required merge order agree, now that
  Step 6 is appended but must precede Step 5? — **FAIL (missing)** — appending
  created a heading order that contradicts the dependency order. Revised in
  place: R6 now states the merge order `1 → 2 → 3 → 4 → 6 → 5` explicitly and
  warns that number order is not merge order; Step 6's own heading repeats the
  constraint.

## Scribe update hint

- `.claude/wiki/modules/hooks.md` — the gate's row changes shape: one script,
  two PreToolUse matchers, allowlist semantics.
- A short wiki note worth its own entry: **fail-closed matchers should be
  allowlist-shaped, not denylist-shaped** — this plan's Clarifications record
  the reasoning, and the same choice recurs in `dispatch-hygiene.sh`.
- `CONTEXT.md` glossary — "marker directory" as the canonical term.
- Worth recording that the gate had false *negatives*, not just false
  positives; the "don't loosen a security gate" instinct was measurably
  misplaced here.

## Publication

Published to `Storreslara/AntiSlop` as a PRD comment on issue **#155** with the
`ready-for-agent` label, per the `to-spec` mapping (Goal → Problem Statement,
Context → Solution, Steps → User Stories, Constitution check → Implementation
Decisions, per-step criteria → Testing Decisions, Risks/deferrals → Out of
Scope, Clarifications + Self-check → Further Notes). This document remains the
canonical artifact.

## Amendment A4 — two ratified residuals of Step 6's matcher

Appended after issue #182 hit the 2-FAIL cap and was re-scoped by the debug spec
`docs/plans/2026-07-31-debug-182-step6-word-boundary.md` (tracker #183, step
6R-4). Nothing above this line is modified. Both items below are **decided**, not
open: they are known false positives that the gate keeps on purpose, and #181
should carry them into the CHANGELOG's "known limitations" line.

- **A4.1 — any backslash fails closed.** `command_skeleton()` refuses to lex a
  command containing ANY backslash, so `cat <marker>/a\ b` is blocked even
  though it only reads. An escaped space defeats the word-start test exactly as
  an escaped quote defeats quote pairing, and both fail-opens this epic already
  produced came from narrowly-scoped cleverness about bash's lexer. One broad
  rule is cheaper to trust than three narrow ones. **Workaround: quote the path
  instead of escaping it** — `cat "<marker>/a b"` is allowed. Pinned by cases
  27.1 and 27.2.
- **A4.2 — a trailing segment that is entirely a comment fails closed.**
  `ls <marker>` followed by a newline and `# note` is blocked, because once the
  comment is masked the final segment's first word is the `#` itself, which is
  not allowlisted. This was Open Question 1 in the debug spec and was resolved
  **as blocked** (human-confirmed 2026-07-31): the alternative is new masking
  logic in a function that has failed twice, and "model one more construct" is
  precisely the move that produced both failures. **Workaround: put the comment
  above the command, or omit it.** Pinned by case 27.3.

Both are recorded in `hooks/scripts/reviewed-path-gate.sh`'s `command_skeleton()`
header as well, so a reader of the source need not find this document. The
standing guard against a third fail-open of the same class is the differential
boundary-byte sweep (case 26 of `tests/reviewed-path-gate.test.sh`), which checks
the matcher against real bash across every byte `0x01`-`0x7F` rather than against
a fixture list.

---

## Amendment A5 — narrowing A4's completeness claim about case 26

Nothing above this line is modified. A5 supersedes one sentence of A4 rather
than editing it, preserving this document's append-only invariant (#182's
criterion 6R-4.4) and the historical record of what was believed on 2026-07-31.

**Superseded sentence, quoted verbatim from A4:**

> The standing guard against a third fail-open of the same class is the
> differential boundary-byte sweep (case 26 of
> `tests/reviewed-path-gate.test.sh`), which checks the matcher against real
> bash across every byte `0x01`-`0x7F` rather than against a fixture list.

**What is actually true.** Case 26 checks **filesystem effects under five fixed
payload shapes** (templates T1-T5, one per lexing decision point), for every byte
`0x01`-`0x7F`. It is therefore exhaustive in the **byte** dimension and
example-based in the **construct** dimension. It is not a check of "the matcher"
in general: it covers `command_skeleton()`'s comment word-start and terminator,
the two redirection-exemption trailing anchors, and the segment separator set —
and nothing else.

**Why the distinction is load-bearing, not pedantry.** Issue #184 found a third
fail-open of this same class — an ad-hoc word-boundary predicate — at a site case
26 does not cover at all: the flag scans inside `program_allowed()`. Every one of
case 26's five templates invokes `ls`, which carries no flag scan, so the sweep
was structurally incapable of ever reaching that code path. Its gate-allowed
count is identical (257 of 635) before and after #184's fix, which is the
measurement that demonstrates the non-coverage rather than merely asserting it.
A reader who took A4's sentence at face value would reasonably conclude the class
was already closed. It was not.

**What replaced it.** #184 added **case 28**, an exhaustive flag-boundary
assertion for `program_allowed()`. The two techniques are deliberately different
shapes, and the distinction is the reusable lesson:

- A **differential** sweep (case 26) needs the reference implementation to
  produce an observable effect in the sandbox. Where it cannot, a differential
  template is green forever regardless of the gate's behaviour — which is the
  defect a reviewer separately found in case 26's own T3/T4 templates, now
  tracked as issue #185.
- Where the effect *is* observable, the differential half is kept. Case 28 has
  one, on its `git` template. This corrects a measurement error made while
  specifying #184: `git diff --output=F` outside a git repository was recorded as
  writing nothing on the strength of its exit code (rc 128/129). The exit code is
  right and the inference was wrong — git parses `--output` and **opens, hence
  truncates,** the target before it discovers there is no repository. `git log
  --output=F` genuinely does not write, so the behaviour is per-subcommand.
- Where the effect is genuinely unobservable, the honest form is a
  **one-directional block assertion with an explicit mutation control**, not a
  differential test that can never fail.

**Standing guard, restated correctly.** There are now **two** regression
techniques on this file, not one, and neither subsumes the other: case 26 for
`command_skeleton()`'s lexing decisions, case 28 for `program_allowed()`'s flag
scans. This file has now produced three bugs of one class (#177, #182, #184), and
the enumerated ten-metacharacter set is the project's single answer to it.
