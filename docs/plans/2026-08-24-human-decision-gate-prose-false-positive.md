# human-decision-gate.sh: close the prose-mention, backslash-read and inert-comment false positives

Status: **FINAL — dispatch-ready** (spec-master, 2026-08-24). All four
originating questions and both follow-up questions (A, B) answered by the
operator on 2026-08-24. Resolves to **three units**, fast path. Extends — does
not
supersede — `docs/plans/2026-08-12-human-decision-gate-false-positive.md`,
whose narrow-recognizer precedent this follows, and **reverses** that
document's Open Question 2 (P13/P16 left deliberately open) on the operator's
explicit instruction.

Every verdict in this document was executed live against the real gates this
session, patched and unpatched, and every number is measured.

## Goal

Make `hooks/scripts/human-decision-gate.sh` distinguish **"this command could
write the DECISION file"** from **"this command merely mentions the words
`human-review` and `DECISION` as inert text"** — in a commit message, in a
single-quoted `grep` pattern, or in a shell comment — while preserving the
invariant that no agent identity, orchestrator included, can create or modify
`.claude/human-review/<task-id>/DECISION` by any command shape.

## Context

### The trigger, and why it recurs forever

`human-decision-gate.sh:122-129` fires when a Bash command's text contains
**both** literal substrings `human-review` and `DECISION`, anywhere, in any
position. It then allows only `command_is_provably_benign()` (read-only
allowlist, rejects every write, excludes `git` per issue #186) or
`is_sanctioned_marker_write()` (one `cat > .claude/reviewed/<id>.pass <<'EOF'`
shape). Everything else is denied.

A task-id containing `human-review` supplies the first substring in its own
conventional-commit scope; any honest description supplies the second. There is
no rephrasing escape valve, because this gate's refusal names rephrasing a
`self-authorized bypass`.

### Measured baselines (live probe harness, 2026-08-24)

| Probe | Command shape | Before |
|---|---|---|
| B1 | `git commit -m "fix(human-review-cleanup-1): … unreadable DECISION file"` | **DENY** |
| B2 | the *same* `git commit`, message carrying neither trigger word | **ALLOW** |
| B3 | `git commit -m "fix: guard the DECISION read"` (one trigger only) | **ALLOW** |
| B4 | `git commit -F /tmp/msg.txt` (the forbidden rephrasing move) | **ALLOW** |
| P13 | `grep -n 'DECISION\|human-review' <file>` — a pure read | **DENY** |
| P16 | unrelated write, both tokens in a trailing comment | **DENY** |

B1 vs B2 is load-bearing: the verdict on a `git commit` turns **entirely on
message prose**, never on what the command can write.

### The marginal-security argument, measured on both halves

`git` was removed from `program_allowed()` because it consults out-of-band
configuration and runs repository hooks. Both halves were re-measured:

- A `core.hooksPath` `pre-commit` hook **does** run on a plain
  `git commit -m "probe2"` whose message contains neither trigger word — a
  command the gate **already allows**. The ambient capability is therefore
  **message-independent**, so denying B1 while allowing B2 removes no
  capability at all.
- A git alias **cannot** shadow the built-in `commit` (an
  `alias.commit = !printf PWNED > …` never executed; the real commit ran).

`.gitignore:26` also ignores `.claude/human-review/`, so DECISION is never
tracked and `git checkout`/`restore`/`stash` cannot recreate it. `git apply`
still can, and stays denied on path shape.

### The decisive negative result: no program-agnostic fix exists

Three framings were prototyped and falsified:

1. **"Only fire when the write target resolves to the DECISION path."** The
   gate can never resolve a target — it is purely textual, which is exactly why
   the split-variable residual (R-2, pinned as test N21) is allowed today.
2. **Skeleton-based narrowing.** Falsified by measurement: the shared lexer's
   skeletons of `git commit -m '…'` and `sh -c '…'` are **shape-identical** —
   `git commit -m 'XXXX…'` versus `sh -c 'XXXX…'`. The first is inert prose;
   the second executes its argument.
3. **Path-shape-only trigger.** Would fix P13/P16 for free, but **regresses**
   the invariant: `cd .claude/human-review/u1 && printf x > DECISION` writes
   the file with no contiguous path run, and is denied today.

Separating the false positive from `sh -c` therefore **requires a program-name
judgment**, ratified by the operator (Q1) as a gate-local recognizer.

### Bash semantics the lexer change models (measured, not assumed)

| Fact | Measured behaviour | Consequence |
|---|---|---|
| Backslash inside **single** quotes | literal; span still ends at the next `'` | **safe to permit** — this is P13 |
| `$'…'` (ANSI-C) | honours `\'`, which keeps the span **open** | **must fail closed** |
| `$"…"` (locale) | same escape handling | **must fail closed** |
| `\"` inside **double** quotes | keeps the span open (`"a\" ; echo PWNED"` is one word) | **must fail closed** |
| Trailing `\` in a `#` comment | does **not** continue the comment | backslash in a comment is safe |

Today `command_skeleton()` rejects **any** backslash. The change narrows that
to: permit a backslash only inside a single-quoted span or a comment; keep
failing closed outside quotes, inside double quotes, and for `$'`/`$"`.

### The three allowances (all prototyped end-to-end)

Gate-local, consulted only **after** `command_is_provably_benign()` declines,
strictly additive to the allow set, reusing `benign-command.sh` read-only.

- **`has_path_shaped_occurrence()`** — true when some contiguous run of
  non-whitespace, non-quote characters holds both trigger tokens. Catches every
  spelled path in any quoting, including dot-segments, `..` traversal and
  repeated slashes. **Must be implemented without word splitting or pathname
  expansion** (see the measured hazard below).
- **`triggers_are_inert()`** — shared precondition: no substitution, no
  path-shaped run, must lex, and no trigger may survive into the **code** text
  of the skeleton (quoted spans and comments are masked, so a surviving trigger
  sat where bash would execute it or use it as a redirection target).
- **`write_with_inert_triggers()`** (closes P16) — identical to
  `command_is_provably_benign()` except the write test is replaced by the two
  conditions above. This gate guards one file; a write that provably cannot
  name it is not its business. The program allowlist still applies, which is
  what keeps `sh -c 'cd … && printf x > DECISION'` denied.
- **`is_prose_only_commit()`** (closes FP-B) — adds: no redirection, exactly
  one segment, first word `git`, second word `commit`.

### Measured deltas — both gates, patched vs unpatched

**Existing suites, test files unmodified, zero regressions:**

| Suite | Before | After |
|---|---|---|
| `tests/human-decision-gate.test.sh` | 43 OK / 0 FAIL | **43 OK / 0 FAIL** |
| `tests/reviewed-path-gate.test.sh` | 364 OK / 0 FAIL | **364 OK / 0 FAIL** |

**`human-decision-gate.sh`, 61 adversarial cases — 14 changed, all intended:**

- Flipped to ALLOW (8): the operator's exact commit; single-quoted; `-am`;
  `--amend`; two `-m` parts; multi-line message; apostrophe inside a
  double-quoted message; a bare `*` in the message.
- Flipped to ALLOW (3, P13): `grep -n 'DECISION\|human-review' <file>`;
  `grep -nE 'DECISION\b' <the file itself>`; `grep -rn 'DECISION\|approve'`
  over the packet directory.
- Flipped to ALLOW (3, P16): write elsewhere with a trailing comment naming
  both tokens; no space after `#`; a comment that *describes* a cd-relative
  write (still only a comment, so bash discards it).
- **Unchanged DENY (30)** — direct redirect, `sh -c` single-quoted write,
  `sh -c` cd-relative write, bare cd-relative write, `node -e`, `python3 -c`,
  `tee`, `cp`, `sed -i`, `git apply`, commit-then-write via `&&`/`;`/
  cd-relative, commit with stdout or stderr redirected at the path, `$( )` and
  backtick in the message, `-F` at the path bare and quoted, `git -c
  core.hooksPath=… commit`, `env` prefix, pipeline into `tee`, `sh -c "commit
  …"`, leading command before `git`, dot-segment / traversal / double-slash /
  quoted path targets, `$HOME` in the message, `xargs`.
- **Unchanged DENY (11 new backslash attacks)** — ANSI-C quoted write; ANSI-C
  escaped-quote pairing; backslash ending a single-quoted span followed by a
  real write; escaped quote inside a double-quoted span; locale-quoted write;
  escaped space in the target; line continuation; a comment ending at the
  newline before a real write; a quoted `#` that is not a comment; `eval` with
  a quoted payload; a single-quoted backslash followed by a real write.
- **Unchanged ALLOW (5 pinned residuals)** — split-variable write (R-2);
  commit with no trigger words; sanctioned marker template; `rm -rf` the packet
  directory; plain read of the file.

**`reviewed-path-gate.sh` (the shared-lexer blast radius), 18 cases — exactly
2 changed:** `grep -n 'PASS\|FAIL' .claude/reviewed/u1.pass` and
`grep -rn 'commit\|criteria' .claude/reviewed/` flip DENY→ALLOW, both the
intended P13 class. All 15 write-attack shapes stay denied, including the five
new backslash vectors and `sed -i 's/a\/b/c/'`.

### Measured implementation hazard

A naive path-shape tokenizer written as `for w in $(printf '%s' "$cmd" | tr …)`
**is glob-unsafe**: a bare `*` in a commit message expanded to 22 repository
filenames. Condition must be implemented as a pure-bash scan with no word
splitting and no pathname expansion — the same class of unmodelled-lexing
defect that cost issue #182 two failed attempts in this very lexer.

### Cost already incurred

`.claude/reviewed/human-review-cleanup-1.fail` note (a) records that the
reviewer's empirical fixture "was blocked by human-decision-gate.sh
(documented substring false-positive) and I did NOT rephrase to dodge it" — so
a real residual defect shipped as "derived by reasoning, not measured". The
`.pass` adds that the same reviewer hit it twice more **while grepping** (the
P13 class). The gate degrades review quality, and correct agent behaviour is
what makes it degrade.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-24 Non-functional attributes: Q What is the security budget for
  admitting a program `program_allowed()` deliberately excludes? → A: ratified
  by the operator — a **gate-local** recognizer only, shared
  `program_allowed()` untouched, on the measured zero-marginal-capability
  evidence (an identical commit with different prose is already allowed; the
  pre-commit hook runs regardless of message text; an alias cannot shadow the
  built-in).
- 2026-08-24 Functional scope & success criteria: Q How wide should the
  program condition be? → A: **single `git commit` segment only**, no leading
  `git add` allowance. Chaining is what keeps the commit-then-write attacks
  denied; running `git add` as a separate call neither hides nor spells the
  protected path.
- 2026-08-24 Technical constraints & tradeoffs: Q Close P13/P16 too, accepting
  a shared-lexer change? → A: **yes**, against this spec's own prior
  recommendation, reversing the 2026-08-12 deferral. Measured outcome: the
  change is confined to backslash handling, both suites pass unchanged
  (43/364), and `reviewed-path-gate.sh`'s delta is exactly the two intended
  read allowances.
- 2026-08-24 User interaction flow: Q Should the deny message's absolute
  anti-rephrasing rule be scoped? → A: keep it absolute, **add one clarifying
  sentence** that it governs commands *targeting* the protected path, and that
  prose mentions, single-quoted read patterns and comments are now allowed
  outright — so the rule stops reading as a trap without weakening it.
- 2026-08-24 Edge cases / failure handling: Q Which adversarial shapes must
  prove the invariant survives? → A (self-resolved): the 61 + 18 enumerated
  above, each executed against both the patched and unpatched gates, headed by
  the three that falsified the simpler mechanisms and the five bash-semantics
  traps the lexer change must fail closed on.
- 2026-08-24 Functional scope & success criteria: Q Extend the allowance to
  `reviewed-path-gate.sh` (follow-up A)? → A: **yes, as a third unit, the
  comment-only-mention allowance ONLY — not the `git commit` recognizer**,
  since that gate's `git commit -F <file>` workaround is sanctioned there, so
  the commit case traps nobody. Measured to close the asymmetry with zero
  marginal capability (see R-13).
- 2026-08-24 Edge cases / failure handling: Q Pin or close the `DECISIO\N`
  escape residual (follow-up B)? → A: **pin it** as a documented, accepted
  ALLOW test, the same treatment N21 gives the split-variable residual. No
  gate-logic change; it becomes a tracked limitation rather than an accident.
- 2026-08-24 Terminology consistency: Q Does the request or the glossary drift
  against `CONTEXT.md`? → A (self-resolved, three lenses, all ran). **Lens 1**
  — two findings. The originating phrase "write target actually **resolves
  to** a … path" ascribes runtime path resolution to a purely textual gate
  (`CONTEXT.md:1394`'s "substring early-exit"); and `CONTEXT.md:1391` still
  asserts "Reads stay allowed for both gates", the exact claim unit gh345-1
  measured false, still open from that unit's marker note N2 — and this round
  makes it *nearly* true for the first time, so it must be rewritten rather
  than merely deleted. **Lens 2** — one minor finding:
  `human-decision-gate.sh:49` says "22-case attack suite" while the suite
  already runs 43 assertions; same count-drift class as gh345-1 note N7.
  **Lens 3** — **sanctioned marker-write template** is load-bearing since
  2026-08-12 and still has no `CONTEXT.md` entry; this round adds a second
  load-bearing concept (a mention that only *narrates* the path versus one
  that *targets* it). Both routed to the Scribe update hint. Category stays
  Partial because the fix lands with `scribe`, not in these units.

## Risks / dependencies

- **R-1 — admitting `git commit` contradicts a standing instruction.**
  `benign-command.sh:12-14` says "do not re-add either one". That governs the
  **shared** `program_allowed()`, which unit 2 does not touch — the recognizer
  is gate-local, exactly as `is_sanctioned_marker_write()` is. Ratified under
  Q1; cite this line in the unit's commit message so a reviewer does not FAIL
  it against the shared-lexer rule.
- **R-2 — a denylist would fail open, and is not on the table.** Any mechanism
  phrased as "allow unless the program is `sh`/`bash`/`node`/…" fails open on
  every interpreter missed — the exact ground `benign-command.sh:20-25` gives
  for removing `git`/`rg`. The program condition is allowlist-shaped, one entry.
- **R-3 — the shared lexer now has a real behavioural change**, unlike the
  2026-08-12 round (R-4 there). `reviewed-path-gate.sh` is transitively
  affected, so `tests/reviewed-path-gate.test.sh` passing **unchanged** is a
  binding criterion, and unit 1 adds its own cases there for the new allow/deny
  boundary.
- **R-4 — split-variable residual (R-2 of the 2026-08-12 doc) stays open**,
  unchanged, still pinned by test N21.
- **R-5 — newly discovered residual of the same class; PINNED per decision B.**
  `printf x > .claude/human-review/u1/DECISIO\N` is **allowed today and stays
  allowed** — bash resolves `\N` to `N` and writes the file, while the raw text
  never contains the substring `DECISION`, so the early-exit fires first.
  Measured ALLOW on both the patched and unpatched gates, so it is **not a
  regression** — but it is a previously undocumented bypass in the same family
  as R-4, found while building this round's suite. Unit 2 pins it as an
  explicit ALLOW case with a comment naming it an accepted residual, exactly as
  N21 pins the split-variable case. Closing it would require normalizing
  backslash escapes *before* the substring early-exit on every Bash command in
  the session, and still would not close R-4.
- **R-11 — the comment allowance covers TRAILING comments only, on both
  gates.** Measured: a comment occupying its **own line** still fails closed,
  because the skeleton splits segments on newlines and `segment_allowed()` then
  reads a bare `#` as the segment's program. That is the ratified issue-#183
  residual (`benign-command.sh` header, `docs/plans/2026-07-31-debug-182-step6-word-boundary.md`
  step 6R-4), not a defect introduced here, and it is deliberately **not**
  fixed in this round. Both units must assert it as a must-stay-DENIED case so
  a later implementer does not mistake it for an oversight.
- **R-12 — `benign-command.sh`'s header documents a workaround that does not
  work.** It says a comment-only trailing segment fails closed, so "put the
  comment above the command, or omit it". Measured on a purely read-only
  command: a trailing same-line comment is benign, but a comment on its own
  line — **whether above or below** — is not. Only "omit it", or keeping it on
  the same line, actually works. Unit 1 already rewrites this header and must
  correct the false half of the claim.
- **R-13 — unit 3 grants zero marginal capability, measured.** The worry is a
  cd-relative write whose only mention sits in a comment
  (`printf x > u1.pass # writes into .claude/reviewed`). Measured: the same
  command **without** the comment (`printf x > u1.pass`) is **already allowed
  today**, so the comment cannot enable a write that was not already reachable.
  This is the same argument shape as B1/B2 for `git commit`, re-measured for
  this gate rather than assumed by analogy.
- **R-6 — hard mirror parity.** `tests/validate.sh:302` runs
  `diff -rq hooks/scripts .claude/hooks/scripts`, and
  `.claude/persona-config.json` pins both files' content hashes (all four
  copies are byte-identical today). Source edit and regenerated mirror **must
  land in the same unit**. Hook scripts are content-hash-tracked since 0.31.28,
  so `node bin/cli.js --update` syncs them without a version bump.
- **R-7 — no version bump is owed, and bumping would break the boundary.**
  Constitution P3 scopes to `agents/*.md` and templates; these units touch only
  `hooks/`, `tests/` and the hook mirror. This is the precise conflict that
  produced gh345-1's marker note N8, where a Do-NOT-touch list and a
  believed-mandatory G1 triple could not both be honoured. **Do not bump**, and
  confirm no `agents/*.md` is modified.
- **R-8 — no adapter port is owed.** `adapters/{codex,cursor}/hooks/scripts/
  lib/` contain `agent-identity.sh` only — neither gate nor the shared lexer —
  measured this session. The shipped mirror `.claude/hooks/scripts/lib/
  benign-command.sh` **does** exist and is covered by R-6.
- **R-9 — `protected-paths.sh` will block unit 2's edit, by design.**
  `hooks/scripts/human-decision-gate.sh` and `hooks/scripts/reviewed-path-gate.sh`
  are in `protectedPaths`, and that hook refuses Write/Edit with "Requires
  explicit human approval — ask the user before editing this file." It matches
  `Write|Edit` **only**, so a Bash heredoc would slip past it — **that would be
  a self-authorized bypass** and is forbidden. Unit 2 must carry the operator's
  explicit go-ahead, or stop and ask. `hooks/scripts/lib/benign-command.sh` is
  **not** protected, so unit 1 dispatches cleanly.
- **R-10 — escalation will NOT fire; my earlier note was wrong.**
  `.claude/persona-config.json` sets `humanReviewMode: "off"` (ADR-0024
  solo-operator posture; ADR-0018 records this repo returning to `off`).
  ESCALATE-TO-HUMAN is driven by that setting (`agents/reviewer.md:167`,
  `templates/persona-protocol.md:329`), **not** by `protectedPaths`. The
  gh345-1 escalation happened because the key was absent then and defaulted to
  `critical`; it is now explicitly `off`. The two mechanisms are unrelated:
  R-9 still applies, R-10 replaces my prior claim.
- **Prior defect history.** No `.fail` exists for gh345-1 or gh345-2.
  `human-review-cleanup-1.fail` exists but its sole ground was a
  dirty-working-tree marker precondition, not a code defect ("SUBSTANTIVE
  RESULT: both acceptance criteria are GREEN … Do NOT redo the code"). Neither
  unit is `haiku`-eligible: security invariant, shared lexer, judgment
  throughout. Both `opus`.
- **Ordering:** unit 1 → unit 2. Unit 2's suite includes backslash-bearing
  commit messages that only lex once unit 1 lands.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — all five bash-semantics facts, both
  suite baselines, the 61 + 18 adversarial verdicts, the glob hazard, the
  adapter inventory, and `humanReviewMode` were executed live, not inferred.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  mirror and `fileHashes` regenerate via `node bin/cli.js --update` only.
- P3 "Version-stamp discipline": **not applicable, deliberately** — see R-7.
  No version-stamped file is touched, so no bump is owed and none may be made.
- P4 "Optional personas degrade gracefully": satisfied — both gates are
  identity-blind on these paths.
- P5 "`tests/validate.sh` is the merge gate": satisfied — both suites are
  already wired (`tests/validate.sh:401` and the reviewed-path-gate entry), and
  the mirror-parity check at `:302` is itself part of the gate.

## Steps

### Step 1 — model backslash escapes in the shared lexer (closes P13, both gates)

In `hooks/scripts/lib/benign-command.sh`, replace `command_skeleton()`'s
blanket backslash rejection with the measured model: permit a backslash inside
a single-quoted span (bash performs no escaping there) and inside a `#` comment
(which ends at the newline regardless); keep failing closed on a backslash
outside quotes, on a backslash inside a double-quoted span, and add explicit
rejection of `$'…'` and `$"…"`, both of which honour `\'` and would otherwise
mis-pair every quote that follows. Keep the `<<` heredoc rejection. Update the
function's header comment, which currently documents the blanket rule as a
ratified residual.

Extend `tests/reviewed-path-gate.test.sh` with the 18 measured cases: the 2
newly-allowed reads and the 15 write shapes that must stay denied (including
ANSI-C, locale-quoted, escaped-quote-in-double-quotes, escaped space, line
continuation, and `sed -i` with escapes), plus a plain-read control.

Affected files: `hooks/scripts/lib/benign-command.sh`,
`tests/reviewed-path-gate.test.sh`, `tests/human-decision-gate.test.sh` (P13
cases), `.claude/hooks/scripts/lib/benign-command.sh` (regenerated),
`.claude/persona-config.json` `fileHashes` (regenerated).

Do NOT touch: `hooks/scripts/human-decision-gate.sh`,
`hooks/scripts/reviewed-path-gate.sh`, any `agents/*.md`, any version file.

Acceptance criteria (from repo root):

```
bash tests/reviewed-path-gate.test.sh     # exit 0
bash tests/human-decision-gate.test.sh    # exit 0
bash tests/validate.sh                    # exit 0 (includes the diff -rq mirror parity check)
node bin/cli.js --update --check          # exit 0
git diff --quiet -- hooks/scripts/human-decision-gate.sh hooks/scripts/reviewed-path-gate.sh   # exit 0
git diff --name-only | grep -q '^agents/' # exit 1 (no agent file restamped)
```

Newly-ALLOWED cases (RED today, each measured DENY before the change):
`grep -n 'PASS\|FAIL' .claude/reviewed/u1.pass`;
`grep -rn 'commit\|criteria' .claude/reviewed/`;
`grep -n 'DECISION\|human-review' <file>`;
`grep -nE 'DECISION\b' .claude/human-review/u1/DECISION`;
`grep -rn 'DECISION\|approve' .claude/human-review/`.

Must-stay-DENIED cases (each measured DENY before and after — these bind the
new fail-closed branches; deleting any one of the three guards must flip its
case to allowed, which is the mutation proof the implementer must run):
`sh -c $'printf x > <path>'`; `sh -c $"printf x > <path>"`;
`echo "a\" ; printf x > <path>"`; `printf 'a\' ; printf x > <path>`;
`printf x > <path>\ b`; a line continuation before the redirect;
`sed -i 's/a\/b/c/' <path>`; `eval 'printf x > <path>'`.

### Step 2 — the three gate-local allowances (closes FP-B and P16)

In `hooks/scripts/human-decision-gate.sh`, add `has_path_shaped_occurrence()`,
`triggers_are_inert()`, `write_with_inert_triggers()` and
`is_prose_only_commit()` exactly as specified in Context, wired **after**
`command_is_provably_benign()` and **before** `is_sanctioned_marker_write()`.
Implement the path-shape scan with no word splitting and no pathname expansion
(measured hazard). Update the gate's header comment, including the stale
"22-case attack suite" count. Add the Q4 clarifying sentence to the deny
message: the anti-rephrasing rule governs commands *targeting* the protected
path; prose mentions, single-quoted read patterns and comments are allowed
outright and need no workaround.

Extend `tests/human-decision-gate.test.sh` with all 61 measured cases, keeping
every existing case byte-identical (the additive-allow evidence).

Affected files: `hooks/scripts/human-decision-gate.sh`,
`tests/human-decision-gate.test.sh`,
`.claude/hooks/scripts/human-decision-gate.sh` (regenerated),
`.claude/persona-config.json` `fileHashes` (regenerated).

Do NOT touch: `hooks/scripts/lib/benign-command.sh` (unit 1 owns it),
`hooks/scripts/reviewed-path-gate.sh`, any `agents/*.md`, any version file.

Acceptance criteria:

```
bash tests/human-decision-gate.test.sh    # exit 0
bash tests/reviewed-path-gate.test.sh     # exit 0, unchanged (R-3)
bash tests/validate.sh                    # exit 0
node bin/cli.js --update --check          # exit 0
git diff --quiet -- hooks/scripts/lib/benign-command.sh   # exit 0 (unit 1's file untouched)
```

All 61 cases must live **inside the suite file**, never as inline shell
criteria — an inline payload spells both substrings and is denied by the gate
under test. Deny-message assertions are suite cases reading captured stderr,
following the existing N22/N23/N23b pattern.

Pin, as an explicit ALLOW case commented as an accepted residual (decision B,
R-5): `printf x > .claude/human-review/u1/DECISIO\N`. Also assert as
must-stay-DENIED the own-line comment shape from R-11.

### Step 3 — the same comment allowance for `reviewed-path-gate.sh`

Close the asymmetry decision A names: after Step 2, a mention inside a trailing
comment is allowed by the human-decision gate but still denied by the
marker-directory gate, which is the same false-positive class.

Add two gate-local functions to `hooks/scripts/reviewed-path-gate.sh`:
`mask_comments_only()` (length-preserving mask of every `#` comment body,
leaving quoted spans **intact**, delegating every fail-closed rule to
`command_skeleton()` rather than restating them) and
`write_with_commented_mention()` (identical to `command_is_provably_benign()`
except the write test is replaced by "the marker-directory mention does not
survive comment-masking"; the program allowlist still applies). Wire it
immediately after the existing `command_is_provably_benign()` branch, Bash-path
only. Add the Q4-equivalent clarifying sentence to that gate's deny message.

**The `git commit` recognizer must NOT be ported here** (decision A): that
gate's `git commit -F <file>` workaround is sanctioned, so no agent is trapped.
Measured confirmation that it does not leak: `git commit -m "fix: touch
.claude/reviewed/u1.pass"` and the `-am` form both stay DENIED.

Affected files: `hooks/scripts/reviewed-path-gate.sh`,
`tests/reviewed-path-gate.test.sh`, plus the regenerated
`.claude/hooks/scripts/reviewed-path-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

Do NOT touch: `hooks/scripts/lib/benign-command.sh`,
`hooks/scripts/human-decision-gate.sh`, any `agents/*.md`, any version file.

Acceptance criteria:

```
bash tests/reviewed-path-gate.test.sh     # exit 0
bash tests/human-decision-gate.test.sh    # exit 0, unchanged
bash tests/validate.sh                    # exit 0
node bin/cli.js --update --check          # exit 0
git diff --quiet -- hooks/scripts/lib/benign-command.sh hooks/scripts/human-decision-gate.sh   # exit 0
```

Newly-ALLOWED (RED today, both measured DENY before): a write elsewhere whose
trailing comment names the marker directory; the same with no space after `#`.

Must-stay-DENIED (each measured DENY before and after, 20 cases): direct
redirect and append; redirect with an unrelated comment; quoted target with a
comment; `sh -c` write with a comment decoy; bare and commented cd-relative
writes; `tee`; `cp`; `node -e`; `python3 -c`; `eval`; a quoted `#` that is not
a comment; a comment ending at the newline before a real write; command
substitution and `$VAR` targets; a backslash outside quotes; ANSI-C quoting;
`sed -i`; a mention appearing only in a quoted argument; and the R-11 own-line
comment. Plus the R-13 control pair: `printf x > u1.pass` is already allowed
today, which is why its commented twin grants nothing new.

## Resolved decisions

Both follow-up questions were answered by the operator on 2026-08-24, matching
this document's recommendations. Recorded here so a reviewer sees the
reasoning, not just the outcome.

- **A — extend to `reviewed-path-gate.sh`: YES, comment-only allowance, as a
  third unit; the `git commit` recognizer is NOT ported.** The line is
  principled: that gate's refusal already claims "text-only mentions … ARE
  allowed", which a trailing shell comment plainly is, so the comment allowance
  closes a documented-intent gap; whereas its `git commit -F` workaround is
  sanctioned there, so the commit case traps nobody the way the incident
  trapped an agent at the other gate.
- **B — `DECISIO\N` residual: PINNED, not closed.** Tracked as an accepted
  limitation via an explicit ALLOW test (R-5), so a later decision to close it
  is deliberate and visible rather than accidental.

## Self-check

- CHK1: Is "no program-agnostic fix exists" demonstrated or asserted? — PASS
  (three mechanisms prototyped and falsified, identical-skeleton output
  recorded verbatim).
- CHK2: Is every must-stay-denied case backed by a runnable assertion? — PASS
  (61 + 18 cases, each executed against both patched and unpatched gates).
- CHK3: Does the plan prove the shared-lexer change is safe for the OTHER
  gate, not just the one being fixed? — FAIL (missing) — revised in place: the
  reviewed-path-gate delta table (exactly 2 intended changes, 15 write shapes
  unchanged) and the 364-assertion baseline were added after the operator's Q3
  answer widened scope.
- CHK4: Are the bash semantics being modelled measured, or assumed? — FAIL
  (ambiguous) — revised in place: all five were executed, and two ($'…' and
  \" inside double quotes) turned out to be traps that a naive "permit
  backslashes" change would have mis-lexed.
- CHK5: Do Steps 1 and 2 agree on which file owns `benign-command.sh`? — PASS
  (unit 1 owns it; unit 2 carries a `git diff --quiet` criterion binding it).
- CHK6: Does the plan state whether a version bump is owed? — FAIL
  (conflicting) — revised in place as R-7: P3 does not apply, bumping is
  forbidden, and the criterion asserts no `agents/` file is restamped. This is
  the exact conflict gh345-1's note N8 recorded.
- CHK7: Are the prototype's own implementation hazards recorded? — PASS (the
  glob-unsafe tokenizer, measured expanding `*` to 22 filenames; and my own
  patch's unbalanced-quote bug, which is why the `$'` guard is specified as an
  escaped-character pattern rather than a quoted one).
- CHK8: Is the claim that this unit escalates to human review still true after
  the scope change? — FAIL (conflicting) — revised in place as R-10: it is
  **false**, and was false when I first wrote it. `humanReviewMode` is `off`,
  and escalation keys on that, not on `protectedPaths`. R-9 preserves the
  separate, real `protected-paths.sh` block.
- CHK9: Is every newly discovered residual either closed or explicitly pinned?
  — PASS (R-5 is measured as pre-existing, not a regression, and is pinned as
  an explicit ALLOW test per resolved decision B).
- CHK10: Is the prior-defect history surveyed in full rather than sampled? —
  PASS (all `.fail` records enumerated; the three relevant units' markers read
  in full).
- CHK11: Does the plan avoid re-proposing a mechanism this project rejected
  without saying so? — PASS (the 2026-08-12 Open Question 2 deferral is named
  and explicitly reversed on the operator's instruction, not silently
  overturned).
- CHK12: Is unit 3's safety argued from measurement, or by analogy to unit 2? —
  FAIL (missing) — revised in place as R-13: the cd-relative-write worry is
  specific to a gate protecting a *directory* rather than one file, so the
  zero-marginal-capability control was re-measured for this gate
  (`printf x > u1.pass` is already allowed today) instead of being inherited.
- CHK13: Does the plan say what the comment allowance does NOT cover, so a
  later implementer cannot mistake a ratified residual for a bug? — FAIL
  (missing) — revised in place as R-11: own-line comments still fail closed on
  both gates (issue #183), and both units now assert it as a denied case.
- CHK14: Does every claim the units will re-state in a header comment hold? —
  FAIL (conflicting) — revised in place as R-12: `benign-command.sh`'s
  "put the comment above the command" workaround was measured **false**, so
  unit 1 must correct it rather than copy it forward.
- CHK15: Does each unit name a `Suggested model` and a retrieval-contract
  line? — PASS (all three are `opus`; the fast path files no tracker issue, so
  the retrieval contract points at this document by path).

## Scribe update hint

After both units land: rewrite `CONTEXT.md:1391`'s "Reads stay allowed for both
gates" — false since gh345-1, and *nearly* true again for the first time, so it
needs the precise new boundary rather than deletion. Add glossary entries for
**sanctioned marker-write template** (still absent, carried from gh345-1 note
N6) and for the narrate-versus-target distinction this round introduces.
Correct the gate header's stale attack-suite count. ADR-worthy: "a gate whose
protection is textual must be triggered by path shape and program identity,
never by the presence of words."

## Dispatch note (fast path)

Resolves to **three dispatchable units** — within the ≤5 fast-path threshold,
so `task-master` is not involved, no `to-tickets` slicing happens, and no
tracker issue is filed. The orchestrator dispatches from this document.

**Retrieval-contract line (verbatim, all three units):** *No tracker issue
exists for this work — it is dispatched on the fast path. Read the unit's spec
directly from `docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md`
in this repository, at the Step and Risk anchors named in the unit's
`## Retrieval` section. Do not run `gh issue list` for this work; there is
nothing to fetch.*

| Unit | Suggested model | Ordering |
|---|---|---|
| `hdg-lexer-1` | `opus` | first |
| `hdg-prose-2` | `opus` | after 1 |
| `rpg-comment-3` | `opus` | after 2 |

All three are `opus`, none `haiku`-eligible: a shared security lexer, two
PreToolUse gate invariants, and judgment throughout. Ordering is strict —
unit 2's suite contains backslash-bearing commit messages that only lex once
unit 1 lands, and unit 3 reuses the lexer guarantees unit 1 establishes.

Escalation to human review will **not** fire for any of these
(`humanReviewMode: "off"`, R-10). Units 2 and 3 will each hit
`protected-paths.sh`; the operator has approved both edits in advance (R-9).

### Unit: hdg-lexer-1

**## Suggested model:** `opus`

**## Objective**
Model backslash escapes in the shared lexer so a pure read carrying a
backslash inside single quotes stops being denied by both gates, without
widening either gate's write surface.

**## Retrieval**
No tracker issue exists for this work — it is dispatched on the fast path.
Read the spec directly from
`docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md` in this
repository: **Step 1**, plus the Context subsections "Bash semantics the lexer
change models" and "Measured deltas — both gates", and **R-3, R-6, R-7, R-8,
R-11, R-12**. Do not run `gh issue list` for this work; there is nothing to
fetch.

**## Affected files**
`hooks/scripts/lib/benign-command.sh`, `tests/reviewed-path-gate.test.sh`,
`tests/human-decision-gate.test.sh`, plus the regenerated
`.claude/hooks/scripts/lib/benign-command.sh` and
`.claude/persona-config.json` `fileHashes`.

**## Ordered edits**
1. Narrow `command_skeleton()`'s backslash handling to the five measured
   semantics; add explicit `$'` and `$"` rejection; keep `<<` rejection.
2. Rewrite the function's header comment — it currently ratifies the blanket
   backslash rejection as a permanent residual, **and it documents a
   workaround that does not work** (R-12: "put the comment above the command"
   was measured false; only omitting it, or keeping it on the same line,
   works). Correct both halves.
3. Add the 18 reviewed-path-gate cases and the P13 human-decision-gate cases,
   including the R-11 own-line-comment case as must-stay-DENIED.
4. Run `node bin/cli.js --update` to regenerate the mirror and `fileHashes`.

**## Do NOT touch**
Either gate script, any `agents/*.md`, `.claude-plugin/plugin.json`,
`package.json`, `CHANGELOG.md`, or `.claude/persona-config.json`'s
`pluginVersion`. No version bump is owed (R-7) and making one would restamp
files this unit must not touch.

**## Acceptance criteria**
Step 1's criteria block verbatim.

**## Pre-resolved context**
Do not re-derive: the five bash semantics, the two suite baselines (43 and
364), the reviewed-path-gate delta (exactly 2 intended changes), and the
adapter inventory are all measured in Context. Note two traps found the hard
way — `$'…'` honours `\'` and keeps a single-quoted span open, and a naive
`case` pattern written with a quoted `$'` will itself unbalance the file's
quoting; write it as an escaped-character pattern.

**## Escalation**
If any existing assertion in either suite changes verdict, stop and report —
this unit is defined as behaviour-preserving for every non-backslash command.

### Unit: hdg-prose-2

**## Suggested model:** `opus`

**## Objective**
Add the three gate-local allowances so a commit message, a single-quoted read
pattern, or a comment that merely mentions the protected path is allowed, while
every shape that could write it stays denied.

**## Retrieval**
No tracker issue exists for this work — it is dispatched on the fast path.
Read the spec directly from
`docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md` in this
repository: **Step 2**, plus the Context subsections "The decisive negative
result", "The three allowances" and "Measured implementation hazard", and
**R-1, R-2, R-5, R-9, R-11**. Do not run `gh issue list` for this work; there
is nothing to fetch.

**## Affected files**
`hooks/scripts/human-decision-gate.sh`, `tests/human-decision-gate.test.sh`,
plus the regenerated `.claude/hooks/scripts/human-decision-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

**## Ordered edits**
1. Add the four functions; wire them after `command_is_provably_benign()` and
   before `is_sanctioned_marker_write()`.
2. Update the header comment, including the stale attack-suite count.
3. Add the Q4 clarifying sentence to the deny message.
4. Extend the suite to all 61 cases, keeping existing cases byte-identical.
   Include the R-5 pin (`DECISIO\N`, asserted ALLOW, commented as an accepted
   residual alongside N21) and the R-11 own-line comment as DENY.
5. Run `node bin/cli.js --update`.

**## Do NOT touch**
`hooks/scripts/lib/benign-command.sh` (unit 1 owns it),
`hooks/scripts/reviewed-path-gate.sh`, any `agents/*.md`, any version file.

**## Acceptance criteria**
Step 2's criteria block verbatim, plus its two pinned assertions (the R-5
`DECISIO\N` ALLOW pin and the R-11 own-line-comment DENY case). All 61 cases
must live inside `tests/human-decision-gate.test.sh`; none may be written as
an inline shell criterion, because an inline payload spells both trigger
substrings and is denied by the gate under test.

**## Pre-resolved context**
The recognizer's seven conditions are settled — implement them, do not
redesign. `git` must NOT be added to the shared `program_allowed()`; the
program condition is local to this file (R-1). The path-shape scan must not
word-split or glob (measured: a `*` in a message expanded to 22 filenames).

**## Escalation**
`protected-paths.sh` guards this file and will refuse Write/Edit with
"Requires explicit human approval" (R-9). **The operator granted that approval
in advance on 2026-08-24 for this specific path and this unit** — so if the
hook still refuses at call time, report it and wait; do not treat the standing
approval as license to route around the block. That hook matches `Write|Edit`
only, so a Bash heredoc (`cat > … <<'EOF'`) would slip past it silently:
**that route is forbidden here.** It is a self-authorized bypass, and it is
specifically NOT the sanctioned Write/Edit-unavailable fallback in the shared
protocol, which covers the tool being disabled — never a gate refusing. Use
the Write/Edit tools only.

Separately: if the recognizer cannot satisfy the newly-allowed and
must-stay-denied sets simultaneously, stop and report — that would be a spec
defect, not an implementation one. Never widen a condition to make a test pass.

### Unit: rpg-comment-3

**## Suggested model:** `opus`

**## Objective**
Close the asymmetry unit 2 creates: allow a write whose only mention of the
marker directory sits in a trailing `#` comment, without porting the
`git commit` recognizer to this gate.

**## Retrieval**
No tracker issue exists for this work — it is dispatched on the fast path.
Read the spec directly from
`docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md` in this
repository: **Step 3**, plus **Resolved decision A**, and **R-9, R-11, R-13**.
Do not run `gh issue list` for this work; there is nothing to fetch.

**## Affected files**
`hooks/scripts/reviewed-path-gate.sh` (new functions above `input="$(cat)"`;
new branch immediately after the existing `command_is_provably_benign()`
branch; deny-message string), `tests/reviewed-path-gate.test.sh`, plus the
regenerated `.claude/hooks/scripts/reviewed-path-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

**## Ordered edits**
1. Add `mask_comments_only()` — length-preserving, masks comment bodies only,
   leaves quoted spans intact, delegates all fail-closed rules to
   `command_skeleton()`.
2. Add `write_with_commented_mention()` — `command_is_provably_benign()` with
   the write test replaced by "the mention does not survive comment-masking";
   keep the program allowlist, the substitution rejection, and the
   `eval`/`exec`/`source` scan.
3. Wire it as a second branch after the existing benign check, Bash-path only.
4. Add the clarifying sentence to this gate's deny message, mirroring unit 2.
5. Extend the suite with the 2 newly-allowed and 20 must-stay-denied cases,
   plus the R-13 control pair.
6. Run `node bin/cli.js --update`.

**## Do NOT touch**
`hooks/scripts/lib/benign-command.sh` (unit 1 owns it),
`hooks/scripts/human-decision-gate.sh` (unit 2 owns it), any `agents/*.md`,
any version file. **Do not port `is_prose_only_commit()` to this gate** —
decision A excludes it deliberately.

**## Acceptance criteria**
Step 3's criteria block verbatim.

**## Pre-resolved context**
Do not re-derive: the 22-case delta, the proof that the `git commit`
recognizer does not leak (`git commit -m`/`-am` prose both measured DENY), and
the zero-marginal-capability control (R-13 — `printf x > u1.pass` is already
allowed today, so its commented twin adds nothing). The own-line comment case
(R-11) stays denied by the ratified issue-#183 residual — assert it, do not
try to fix it.

**## Escalation**
Same `protected-paths.sh` situation as unit 2, for
`hooks/scripts/reviewed-path-gate.sh`: approval granted in advance, the Bash
heredoc route is forbidden, report and wait if the hook still refuses. If
closing this asymmetry turns out to require touching the shared lexer, stop
and report — that would mean unit 1 under-delivered, which is a spec defect.
