# Command-substitution and second-shell closure for the human-decision gate (2026-10-04)

Status: FINAL (spec-master, 2026-10-04). Two units, fast path (five or fewer
units): this document holds the dispatch contracts. There is no task-master
slicing and no tracker issue. Predecessors:
`docs/plans/2026-10-04-quoted-payload-closure.md` (qp-1/qp-2, both PASS),
whose `glob_scan_shell_payloads()` second-shell rule this spec extends, and
the reviewer records `rnc-1.pass`, `rnc-2.pass`, `qp-1.pass`, `esc-fu-1.pass`.

Scope rule from the user (2026-10-04): this spec is written **in general
terms only**. It names no concrete bypass spelling. The frozen family table,
the mutants and the over-block measurement are **implementer/operator
steps**, with runnable acceptance criteria below. Nothing was prototyped at
spec time. The spec session's Bash is under a safety classifier that refuses
to author bypass commands; where a fixture or mutant must be authored, that
is the implementer's step, and a classifier refusal is an escalation, never
a rephrasing (R5, Operator steps).

## Goal

Close three known under-blocks of `hooks/scripts/human-decision-gate.sh`'s
glob scan, and correct three stale doc/comment wordings, so a write to the
DECISION file that today the gate allows is instead denied, the same way an
unquoted glob already is.

The three under-blocks:

- **(U1) glob inside a command substitution.** A glob sitting inside a
  double-quoted command substitution is masked by `command_skeleton()`, so
  `glob_names_tokens()` never sees it and `glob_d` stays 0. The early exit
  then allows the command, while real bash runs the substitution and its
  glob expands to and overwrites the DECISION file (reviewer `rnc-1.pass`
  NOTE[spec]; measured in a scratch fixture; no suite row pins it and no
  declared residual covers it).
- **(U2) a quoted short-option `c` cluster.** The second-shell rule's
  `c`-cluster match (`qp-1`, gate `:469`) does not recognise the option
  cluster when it carries quote characters, so a second shell invoked with a
  quoted `c` cluster escapes the payload scan (`qp-1.pass` NOTE[spec] (a),
  operator step O2 of qp-1).
- **(U3) an escape-assembled payload.** When the outer command assembles the
  second shell's payload with backslash (or ANSI-C) escapes, the outer
  command fails to lex, `glob_names_tokens()` takes its lex-failure branch,
  and that branch never runs the second-shell payload scan — so the glob
  stays literal to the scan while the second shell sees it live
  (`qp-1.pass` NOTE[spec] (b), operator step O2 of qp-1; an R-5 analogue).

The three stale wordings (notes to fold in):

- **(W1)** the `glob_scan_shell_payloads()` header comment says the shell
  name is recognised "at a word start or after a `/`", which understates the
  real name-boundary rule — the regex accepts any preceding character that is
  not a letter, digit, `_`, `.` or `-` (`rnc-1.pass` NOTE[code]).
- **(W2)** the suite comment introducing the quoted-payload section must
  state the real mechanism and must not claim the payload is "masked in the
  joined text" — `joined` only deletes quote characters, so the command does
  spell `human-review`; the early exit fires because DECISION is never
  spelled and the glob scan skipped the masked glob (`esc-fu-1.pass`
  NOTE[spec]; already corrected by qp-1, so this is a standing invariant to
  preserve while new rows are added).
- **(W3)** the substring-test lead-in comment block (the `glob_names_tokens`
  summary above the two early-exit `case` blocks) must describe the newly
  closed forms and move U2/U3 out of the declared residual list.

## Context

### Measured mechanism (read from the code on disk, 2026-10-04)

- The early exit is at gate `:741-748`. `joined` (`:738-739`) deletes only
  quote characters, so a command whose packet path is spelled literally does
  name `human-review` in `joined`. It passes the early exit when DECISION is
  not spelled and `glob_d` is 0.
- `glob_names_tokens()` (`:430-449`) scans off the skeleton when the command
  lexes (`glob_scan_words()` + `glob_scan_shell_payloads()`), and off the
  quote-stripped raw text when it does not (`glob_scan_words()` only).
- **U1.** `command_skeleton()` (`lib/benign-command.sh:103-138`) masks the
  body of a double-quoted span to `X`, keeping the quote characters. A
  command substitution `"$(... glob ...)"` sits inside that span, so its glob
  is masked and never reaches `glob_scan_words()`. The raw-text (lex-failure)
  branch deletes quotes but does not model substitutions either. The `$(`
  guard in `triggers_are_inert()` / `command_is_provably_benign()` fires only
  **after** the early exit, so it never helps a command the early exit
  already allowed.
- **U2.** The `c`-cluster pattern `-[[:alpha:]]*c[[:alpha:]]*` at `:469`
  matches a word of letters only. In the skeleton, a quoted `c` cluster is
  either masked to `X` (a fully double-quoted option word) or interrupted by
  kept quote characters (empty single/double quotes), so the pattern fails
  and the shell invocation is not recognised as having a `-c`.
- **U3.** A backslash outside quotes makes `command_skeleton()` return
  non-zero (`lib/benign-command.sh:115-116`). `glob_names_tokens()` then
  takes the else branch, which does **not** call
  `glob_scan_shell_payloads()`. The raw scan deletes only `'` and `"`, so a
  backslash kept before a metacharacter or a glob leaves that glob literal to
  the scan, while the outer shell strips the escape and the second shell
  re-parses the glob live.
- **Monotonicity (design constraint).** A command that names a token only
  through a glob reaches the fail-closed branch (`:753-756`); only
  `is_sanctioned_marker_write()` can allow it there. Each new predicate in
  this spec may only **set** `glob_h`/`glob_d`, never clear them and never add
  an allow route, so it can only turn an allow into a deny — which is the
  `new_allowances=0` property the differential sweep checks.

### Notes folded in (read from the `.pass` records, 2026-10-04)

- `rnc-1.pass` NOTE[spec]: U1, with the scratch-fixture measurement.
- `rnc-1.pass` NOTE[code] (second item): W1 — the `glob_scan_shell_payloads`
  comment still says "at a word start or after a `/`".
- `qp-1.pass` NOTE[spec] (a): U2, the quoted `c` cluster, reachable, not in
  the R-QP-b examples.
- `qp-1.pass` NOTE[spec] (b): U3, the escape-assembled payload, reachable, an
  R-5 analogue.
- `esc-fu-1.pass` NOTE[spec]: W2 — the "neither token is spelled in the
  joined text" phrasing; qp-1 already removed it (current count 0), and this
  spec keeps it at 0.

### Prior defect history (`.fail` screen)

The whole `.claude/reviewed/` directory was listed. The `.fail` records for
this gate are `hdg-prose-2.fail`, `qp-1.fail` and `rnc-1.fail`:

- `hdg-prose-2.fail` hit the **2-FAIL cap on this same gate**, because an
  unbounded "blocks every spelling" criterion loops when a predicate misses
  one character dimension. Consequence: cmdsub-1 is **opus**, carries a
  frozen family table with one row per new predicate branch, each killed by
  its own mutant, and its family-table criterion is bounded to the branches
  introduced (never "blocks every command-substitution form"). A spelling
  outside the frozen table is a declared residual, never a FAIL ground.
- `qp-1.fail` and `rnc-1.fail` each FAILed once (not capped), on a missed
  shell-option dimension (qp-1) and a closed-vs-open-list prose reading
  (rnc-1). Consequence: cmdsub-1's new shell-rule branches each need a
  mutant, and cmdsub-2's prose must describe an **open-ended** residual list,
  never claim completeness.
- Neither cmdsub-1 nor cmdsub-2 has a `.fail` of its own, so the
  Implementer-tier ratchet does not apply.

### Marker-audit `--notes` sweep

`bash bin/marker-audit.sh . --notes --surface=<path>` was run at spec time
for the three touched surfaces (it is slow — the full-repo marker scan took
longer than one foreground window, so it was backgrounded to completion). The
counts: gate surface 5 `NOTE[spec]` / 5 `NOTE[code]` / 13 untagged; suite
surface 5 `NOTE[spec]` / 1 `NOTE[code]` / 7 untagged; glossary surface 32
`NOTE[spec]` / 25 `NOTE[code]` / 3 untagged (the glossary accumulates every
unit that ever touched it). Disposition: the three `NOTE[spec]` items this
spec acts on (U1/W1 from `rnc-1`, U2/U3 from `qp-1`, W2 from `esc-fu-1`) are
consumed by the edits below; the remainder belong to already-PASSed units and
stay out of scope. `.claude/reviewed/` is gitignored per-clone state, so an
absent note is not proof of none; **each unit's reviewer re-runs**
`bash bin/marker-audit.sh . --notes --surface=<path>` for its own surfaces
and records the disposition of every returned `NOTE[spec]` and `untagged`
line naming a step not yet dispatched.

### Prior art reused

- `tests/hdg-differential-sweep.sh <old> <new> <corpus.jsonl>` prints
  `total=N new_denials=D new_allowances=A`. The corpus recipe is in
  `docs/plans/2026-10-04-escalation-leftovers.md` `:487-493` (the Bash
  commands in the last 20 days of local transcripts). qp-1's sweep gave
  `new_allowances=0` with one new denial (OB-14).
- The suite's QP section (`:999-1049`), QPF family table (`:1051-1076`), and
  OB section (`:1078-1122`, OB-1..OB-14 with `ob_reasons` and the `OBEOF`
  `mapfile` block) are the patterns the new rows extend.
- `fg_overwrites()` (`:916-924`) and `qp_reach()` (`:1021-1030`) are the
  real-shell reachability helpers; their contracts stay unchanged for
  existing rows.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-04 Functional scope & success criteria: Q Which under-blocks does
  this spec close — all re-parse/expansion bypasses, or the three named? → A
  (self-resolved): exactly the three named (U1 command substitution, U2
  quoted `c` cluster, U3 escape-assembled payload), per the caller's item
  list. Any other re-parse bypass is a declared residual and an operator
  step, matching qp-1's bounded-scope discipline that avoided the
  hdg-prose-2 cap.
- 2026-10-04 Non-functional attributes: Q What over-block cost is acceptable?
  → A (self-resolved): `new_allowances=0` (guaranteed by monotonicity and
  checked by the sweep), and at most 10 new denials, each classified and
  pinned as an accepted over-block row from OB-15 on. If new denials exceed
  10, stop and escalate to the user. Same budget as qp-1; no caller input
  changed it.
- 2026-10-04 Edge cases / failure handling: Q U1's command-substitution scan
  cannot tell a read from a write — a read through a glob inside `$(...)`
  will now be denied. Accepted? → A (self-resolved): yes, accepted as a
  fail-closed over-block (the gate guards one file and cannot resolve a
  target). It is bounded by the sweep budget and surfaces as an OB class if
  reachable in the corpus. This matches the existing F-1 design, where the
  glob scan already cannot distinguish read from write.
- 2026-10-04 Edge cases / failure handling: Q May the spec enumerate concrete
  payload spellings or prototype the gate? → A: no to both, per the caller.
  The spec stays in general terms; the frozen table, mutants and sweep are
  implementer/operator steps with runnable criteria. A classifier refusal is
  an escalation, never a rephrasing.
- 2026-10-04 Technical constraints & tradeoffs: Q Where does the fix live —
  the gate or the shared `lib/benign-command.sh`? → A (self-resolved): the
  gate only. `lib/benign-command.sh` is shared with `reviewed-path-gate.sh`,
  whose F-1 variant is deferred, so editing the lib would widen the blast
  radius past this spec. `command_skeleton()` stays byte-unchanged; U1 reads
  substitution bodies from the raw command inside the gate.
- 2026-10-04 Technical constraints & tradeoffs: Q Must the second-shell
  payload scan also run on the lex-failure branch (to close U3)? → A
  (self-resolved): yes. U3 exists precisely because the else branch skips
  `glob_scan_shell_payloads()`. The scan must apply whether or not the outer
  command lexes, with escape-assembled payload words recognised.
- 2026-10-04 Terminology consistency: Q Does "payload" collide with an
  existing glossary term? → A (self-resolved): yes, advisorily. CONTEXT.md
  `:854` uses "payload" for an escalation packet's human-facing content,
  while this spec (inherited from qp-1) uses it for the string a second shell
  re-parses. Both are kept; the harness-mechanics sense lives only in
  `docs/harness-glossary.md`, not CONTEXT.md, so no domain-glossary edit is
  made. "command substitution" and "`c` cluster" are harness-mechanics terms
  (out of scope for the CONTEXT.md glossary). Advisory only; does not block.
- 2026-10-04 Completion / acceptance signals: Q What signals "done" beyond
  the suite passing? → A (self-resolved): every Goal clause maps to a named
  machine-checkable criterion below; the sweep summary and classified OB list
  are pasted into the commit message; each new predicate branch is killed by
  its own mutant. cmdsub-1 closes `rnc-1.pass` NOTE[spec] and qp-1 NOTE[spec]
  (a)/(b); cmdsub-2 makes the glossary agree.

## Assumptions
- AS1: The second shell for U2/U3 is the same `sh`/`bash`/`dash` set the
  qp-1 rule already recognises; this spec widens how that invocation is
  recognised (quoting, escaping) and where the scan runs (substitutions,
  lex-failure branch), not the shell set.
- AS2: The transcript corpus under
  `~/.claude/projects/-home-sebas-AntiSlop` exists at execution time. It is
  machine-local and may be pruned, so the commit message quotes the sweep
  results and does not depend on the corpus persisting.
- AS3: Any concrete classification baseline expires. The sweep is run at
  execution time; no count from this spec is pinned as absolute. Current
  on-disk anchors (version 0.31.120, OB count 14) are starting points, re-read
  at execution time.

## Risks / dependencies
- R1 **Over-block on every agent's Bash.** The gate runs on all Bash.
  Bounded three ways: the sweep enforces `new_allowances=0` and at most 10
  new denials, each classified and pinned; monotonicity (each new predicate
  only sets glob flags); and U1 only arms the gate when a substitution's glob
  could expand to `human-review`/`DECISION` (the existing `glob_match_path()`
  component check).
- R2 **Mutation proofs under the microworld queue report false FAILs**
  (memoization on test path). Run mutants standalone with
  `GATE_UNDER_TEST=<absolute path>`, copy `hooks/scripts/lib` beside the
  mutant, and read a case line of `rc=1` as "the mutant did not start", not a
  kill.
- R3 **The gate blocks the implementer's own Bash** when the command text
  names both tokens. Write the suite and scratch scripts with Edit/Write (or
  a `bash <path>` heredoc fallback for a teammate), run them as `bash
  <path>`, read markers with Read, and commit with `git commit -F <file>`.
  The reviewed-path gate refuses Bash text that spells the marker directory.
- R4 **`tests/validate.sh` takes about 10 minutes.** Run it in a clean
  worktree: `git worktree add /tmp/<unit>-v HEAD`, then `bash
  tests/validate.sh` there, foreground `timeout` at 600000. If it cannot
  finish, end with the WIP sentinel and the reason "no autonomous wake-up
  available — requires the dispatcher to resume me later". The reviewer
  re-runs it.
- R5 **The safety classifier may refuse to author or run a bypass fixture or
  mutant.** Do not rephrase around the refusal. Stop and report the refused
  row; the user decides. (Shared protocol, "Blocked by a gate you do not
  own".) This is why the three example spellings are described here, never
  reproduced.
- R6 **Residuals this spec does not close** (declared, never FAIL grounds):
  - (R-CS-a) a command substitution the extractor cannot delimit (deeply
    nested or otherwise unmodellable from the command text);
  - (R-QP-a) a pattern expanded by a program that is not a second shell
    re-parsing a string (pattern-matching utilities, language interpreters);
  - (R-QP-b, narrowed) a second-shell invocation the rule still cannot
    recognise from the command text after U2/U3 (e.g. a payload read from
    stdin rather than an argument);
  - the existing A3 (cwd-relative, `human-review` unspelled), R-4 (split
    variable), R-5 (backslash inside the protected token itself), and NL1
    (newline in the id).
- R7 **Dependencies:** cmdsub-2 depends on cmdsub-1 PASS; it cites the landed
  row ids, the OB count K and the family-table branch count.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every new row is credited only by a
  real-shell reachability check in a fixture or by its mutant; the over-block
  claim is credited only by the execution-time sweep; nothing is prototyped
  and the spec says so.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  mirror and `fileHashes` come from `node bin/cli.js --update`, never
  hand-edited.
- P3 "Version-stamp discipline": satisfied. cmdsub-1 bumps 0.31.120 to
  0.31.121, adds the CHANGELOG entry, and runs `--update`, all in its one
  commit; `version-stamp-check.sh` is a criterion. cmdsub-2 touches no
  `agents/` or `templates/`, and a criterion asserts the empty diff.
- P4 "Optional personas degrade gracefully": satisfied. No shared persona
  prose is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Both units carry a
  clean-worktree `validate.sh` criterion (R4).

## Dispatch order

Units are **serial**: cmdsub-1, then cmdsub-2, each after the previous one
has a reviewer PASS (the one-unit-at-a-time invariant).

Retrieval contract, for every unit: read this file,
`docs/plans/2026-10-04-gate-cmdsub-closure.md`, at the unit's section plus
Context, Clarifications and Risks. There is no tracker issue on the fast
path.

## Steps (dispatch contracts)

### Unit: cmdsub-1
Suggested model: opus. Depends on: none.

## Objective
Close U1, U2 and U3 in `hooks/scripts/human-decision-gate.sh`'s glob scan,
and fix the stale wordings W1, W2 (preserve) and W3. Prove the change with a
frozen family table, per-branch mutants and a differential sweep. Ship as
0.31.121.

## Retrieval
- This plan: Context, Clarifications, R1-R7, Constitution check.
- Gate: `hooks/scripts/human-decision-gate.sh` `:430-480` (glob scan and the
  second-shell rule), `:718-748` (substring-test lead-in and early exit).
- Lib (read-only; do NOT edit): `hooks/scripts/lib/benign-command.sh`
  `:103-138` (`command_skeleton`).
- Suite: `tests/human-decision-gate.test.sh` `:999-1076` (QP + QPF) and
  `:1078-1122` (OB).
- Sweep: `tests/hdg-differential-sweep.sh`. Corpus recipe:
  `docs/plans/2026-10-04-escalation-leftovers.md` `:487-493`.

## Affected files
- `hooks/scripts/human-decision-gate.sh`
- `tests/human-decision-gate.test.sh`
- `.claude-plugin/plugin.json` and `package.json` (0.31.120 to 0.31.121)
- `CHANGELOG.md`
- Regenerated by `node bin/cli.js --update` and committed in the **same
  commit**, never hand-edited: the
  `.claude/hooks/scripts/human-decision-gate.sh` mirror, the `fileHashes` in
  `.claude/persona-config.json`, and the version stamps.

## Ordered edits
1. **U1 — command-substitution scan (gate only).** Add a check to
   `glob_names_tokens()` (or a helper it calls) that, reading the **raw**
   command, finds each command substitution (`$(...)` and backtick
   `` `...` ``) and scans its body's globs as live, setting only
   `glob_h`/`glob_d`. It must fire whether or not the substitution sits
   inside double quotes (the quoted case is the open bypass). It must never
   clear a flag and never add an allow route. The substitution-delimiting
   rule is the implementer's design, frozen and documented in a comment above
   the new function, **not** an open-ended list claiming completeness; that
   comment names residual R-CS-a. `command_skeleton()` stays byte-unchanged.
2. **U2 — quoted `c` cluster (gate only).** Make the second-shell rule in
   `glob_scan_shell_payloads()` recognise the `-c` cluster (and the shell
   name and option words) when they carry quote characters. The result may
   only set glob flags. Matching stays case-insensitive and over-block-only.
3. **U3 — escape-assembled payload (gate only).** Make the second-shell
   payload scan apply on the lex-failure (else) branch of
   `glob_names_tokens()`, not only when the command lexes, and recognise a
   payload word assembled with backslash (or ANSI-C) escapes so its glob is
   scanned live. Only sets glob flags.
4. **W1 — `glob_scan_shell_payloads()` header comment.** Replace "at a word
   start or after a `/`" with the accurate boundary: the shell name is
   recognised when its preceding character, if any, is not a letter, digit,
   `_`, `.` or `-`. Keep the comment's residual list open-ended.
5. **W3 — substring-test lead-in comment block** (the `glob_names_tokens`
   summary above the two early-exit `case` blocks):
   - extend "counting as patterns only unquoted globs and globs in a quoted
     string handed to a second shell" so it also covers a glob in a command
     substitution and the newly recognised quoted/escaped second-shell forms;
   - move U2 (quoted `c` cluster) and U3 (escape-assembled payload) **out**
     of the R-QP-b declared-residual list (they are now closed), and add
     R-CS-a as a new declared residual; keep A3, R-4, R-5, NL1, R-QP-a, the
     narrowed R-QP-b, and the phrase `not the whole enumeration`;
   - cite `docs/plans/2026-10-04-gate-cmdsub-closure.md`.
6. **Suite — new rows and W2 (preserve).**
   - Add a command-substitution section (rows `CS-*`), each a form that hides
     a glob inside a substitution. Each row has a real-shell reachability
     line (overwrite expected, via `fg_overwrites()` or an equivalent helper)
     and a `blocked` verdict line, both beginning with the row id. Its
     section comment states the real mechanism: `command_skeleton()` masks
     the quoted substitution body, so the glob was hidden; `joined` still
     spells `human-review`; the early exit fired because DECISION was not
     spelled and the masked glob was skipped. The comment must **not** contain
     the phrase `neither token is spelled in the joined text` (W2 invariant,
     current count 0).
   - Extend the second-shell family table with rows for the U2 and U3 branches
     (reachability + `blocked`). A row that writes nothing by design carries a
     comment saying so and no reachability line.
   - **Frozen family table (implementer step).** One row per predicate branch
     introduced in edits 1-3, where "branch" means each distinct new
     condition. The table is frozen in this commit; the commit message holds a
     table mapping each new branch to its row id and its mutant. Do not add
     rows probing beyond the branches introduced (that is operator step O2).
7. **Mutants (implementer step).** For each branch in the edit-6 table, write
   one single-branch mutant (a scratch copy of the gate with `lib/` copied
   beside it, one replacement asserted to occur exactly once). Also write one
   whole-check mutant per under-block (U1, U2, U3) that disables that check
   entirely. The commit message pastes each mutant's replacement text and its
   FAIL lines.
8. **Differential sweep (operator/implementer step).**
   - Build the corpus with the esc-left-3 recipe.
   - Copy the HEAD gate plus `lib/` to a scratch "old" path.
   - Run `bash tests/hdg-differential-sweep.sh <old gate>
     hooks/scripts/human-decision-gate.sh <corpus>`.
   - If `new_denials` exceeds 10, **stop and escalate to the user**; do not
     narrow a rule on your own authority.
   - Otherwise classify every new denial and pin each distinct class as one
     row, `OB-15` onward: extend `ob_reasons` and the `OBEOF` block with one
     representative real command per class, and update the OB section header's
     range.
9. **Version, in the one commit (version first).** Bump 0.31.120 to 0.31.121,
   add a CHANGELOG entry (naming the closed classes U1/U2/U3 in general terms
   and the residuals R-CS-a and the narrowed R-QP-b; quoting no spelling),
   then run `node bin/cli.js --update`.

## Do NOT touch
- `hooks/scripts/lib/` (shared with `reviewed-path-gate.sh`),
  `hooks/scripts/reviewed-path-gate.sh`, `tests/hdg-differential-sweep.sh`.
- `scripts/probe-hook-identity.sh`, `tests/validate.sh`,
  `tests/probe-hook-identity.test.sh`.
- `docs/` (cmdsub-2 owns the glossary), `agents/`, `templates/`, `CONTEXT.md`.
- Existing suite rows other than the new CS/family rows, the new section
  header and comment, and the OB arrays and header. In particular
  `fg_overwrites()`, `qp_reach()`, and the FG, FP, FN, FC, QP and QPF rows,
  except where edit 6 explicitly adds the U2/U3 family rows.

## Acceptance criteria
- `bash tests/human-decision-gate.test.sh` exits 0, run standalone (R2).
- In that output:
  - `bash tests/human-decision-gate.test.sh | grep -cE '^OK +CS-[0-9]+ .*-> blocked$'`
    equals the CS row count stated in the commit message, which is ≥ 1;
  - `bash tests/human-decision-gate.test.sh | grep -cE '^OK +CS-[0-9]+ reachability'`
    equals that same CS row count;
  - `grep -cE '^FAIL ' <(bash tests/human-decision-gate.test.sh)` prints 0.
- W2 invariant:
  `grep -c 'neither token is spelled in the joined text' tests/human-decision-gate.test.sh`
  prints 0.
- Frozen family table:
  - `bash tests/human-decision-gate.test.sh | grep -cE '^OK +(CS|QPF)-[A-Za-z0-9]+ .*-> blocked$'`
    equals the total frozen-table row count N in the commit message's branch
    table (N ≥ 1 and N ≥ the number of new branches);
  - `bash tests/human-decision-gate.test.sh | grep -cE '^FAIL +(CS|QPF)-'`
    prints 0.
- Mutants, each run standalone with `GATE_UNDER_TEST=<absolute path>` and
  `lib/` copied beside it:
  - each single-branch mutant makes the suite exit non-zero, and the output
    holds a `FAIL` line for that branch's own row;
  - each whole-check mutant (U1, U2, U3) makes the suite exit non-zero, with
    a `FAIL` line for at least one row of the under-block it disables;
  - no case line in any mutant run reads `rc=1`;
  - the commit message pastes each mutant's replacement text and its FAIL
    lines.
- Sweep:
  - the summary line shows `new_allowances=0` and `new_denials` ≤ 10;
  - the commit message pastes the summary line, the corpus-build command, and
    the classified list (one class per new denial);
  - `bash tests/human-decision-gate.test.sh | grep -cE '^OK +OB-[0-9]+ '`
    equals 14 + K, where K is the number of distinct new classes stated in
    the commit message (K = 0 allowed).
- Gate header / lead-in (normalised; run the pipeline on both the raw and the
  mirror copy, with identical results):
  - `sed 's/^ *# *//' hooks/scripts/human-decision-gate.sh | tr '\n' ' ' | tr -s ' ' | grep -o 'word start or after a' | wc -l`
    prints 0 (W1 corrected);
  - the same pipeline with `grep -o 'not the whole enumeration'` prints 1;
  - `grep -c 'R-CS-a' hooks/scripts/human-decision-gate.sh` is ≥ 1;
  - `grep -c 'gate-cmdsub-closure.md' hooks/scripts/human-decision-gate.sh`
    is ≥ 1;
  - each pipeline gives the same result on
    `.claude/hooks/scripts/human-decision-gate.sh`.
- `cmp hooks/scripts/human-decision-gate.sh .claude/hooks/scripts/human-decision-gate.sh`
  exits 0, or differs only by the `--update` stamp; `bash tests/validate.sh`
  checks parity either way.
- `bash tests/reviewed-path-gate.test.sh` exits 0.
- `git diff --quiet HEAD~1 -- hooks/scripts/lib hooks/scripts/reviewed-path-gate.sh tests/hdg-differential-sweep.sh scripts/probe-hook-identity.sh tests/validate.sh tests/probe-hook-identity.test.sh agents templates docs CONTEXT.md`
  exits 0.
- `jq -r .version .claude-plugin/plugin.json package.json` prints `0.31.121`
  twice, and `grep -c '0.31.121' CHANGELOG.md` is ≥ 1.
- `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` reports ok.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- U1/U2/U3 mechanisms, the early-exit lines, the fail-closed branch and
  monotonicity were read from the code on disk (Context). Do not re-derive
  the blast radius from zero; verify the one claim you doubt.
- U1 overwrites DECISION via a quoted substitution; U2/U3 are reachable
  under real bash per `qp-1.pass` NOTE[spec]. If a measurement disagrees with
  this plan, escalate; do not redesign.
- Nothing in this spec was prototyped. The sweep and mutants are the
  measurement.
- The caller's bounds bind: the three named under-blocks only; no concrete
  bypass spellings in the plan; the budget is ≤ 10 new denials and 0 new
  allowances; `lib/` is untouched; the three probe/validate files are
  untouched.

## Escalation
- `new_denials` > 10, or `new_allowances` > 0: stop and report the sweep
  output to the user.
- Any branch whose mutant does not kill its own row: stop and report with the
  output.
- A classifier or gate refusal while authoring a fixture or mutant: stop and
  report (R5). Never rephrase to get past it.
- Closing U1/U2/U3 would need a change to `hooks/scripts/lib/`: stop and
  report (the lib is shared and out of scope).

### Unit: cmdsub-2
Suggested model: sonnet. Depends on: cmdsub-1 (PASS).

## Objective
Make the `docs/harness-glossary.md` claims that cmdsub-1 falsifies agree with
the landed pins. Docs only.

## Retrieval
- This plan: Context, Clarifications (terminology and completion lines), R6.
- cmdsub-1's commit message: the CS/family row ids, the OB count K, and the
  branch table.
- `docs/harness-glossary.md`: the `**frozen family table**` entry
  (`:2311-2362`), the `**accepted over-block (OB row)**` entry
  (`:2364-2378`), and the `**expansion-named token**` entry (`:2394-`).

## Affected files
- `docs/harness-glossary.md` only. It has no mirror.

## Ordered edits
1. In the `**frozen family table**` entry: state that, since cmdsub-1, a glob
   inside a command substitution is scanned as a pattern, and the second-shell
   rule also recognises a quoted `c` cluster (U2) and an escape-assembled
   payload (U3). Move U2/U3 out of the R-QP-b residual description; add R-CS-a
   as a new declared residual, in general terms, with no completeness claim.
   Name the new row ids. Do not add any concrete bypass spelling.
2. In the `**expansion-named token**` entry: add that a glob in a command
   substitution body, and the newly recognised quoted/escaped second-shell
   forms, count as expansion-named tokens.
3. In the `**accepted over-block (OB row)**` entry: change "There are 14
   (OB-1 to OB-14)" to the landed count, 14 + K. If K = 0, leave it unchanged.

## Do NOT touch
- `hooks`, `tests`, `scripts`, `agents`, `templates`, `CONTEXT.md`, ADRs.
- The esc-fu-2 "glossary tension" note and the long-line note. Both deferred.

## Acceptance criteria
All greps use the entry-scoped, whitespace-normalised helper:

```
entry() { awk -v h="**$1**:" 'index($0,h)==1{p=1;print;next} p&&/^\*\*[^*]+\*\*:/{exit} p' docs/harness-glossary.md | tr -s ' \n' ' '; }
```

- `entry 'frozen family table' | grep -cE 'command substitution'` is ≥ 1.
- `entry 'frozen family table' | grep -cE 'R-CS-a'` is ≥ 1.
- For each new CS/family row id listed in cmdsub-1's commit message:
  `entry 'frozen family table' | grep -c <id>` is ≥ 1, and the matching suite
  line `bash tests/human-decision-gate.test.sh | grep -cE '^OK +<id> .*-> blocked$'`
  prints 1. The commit message lists every pair's output.
- `entry 'expansion-named token' | grep -cE 'command substitution'` is ≥ 1.
- `entry 'accepted over-block (OB row)' | grep -c "OB-1 to OB-$((14+K))"`
  prints 1, with K taken from cmdsub-1's commit message.
- `node tests/context-glossary-links.test.js` exits 0, and
  `node tests/protocol-doc-drift.test.js` exits 0.
- `git diff --quiet HEAD~1 -- hooks tests scripts agents templates CONTEXT.md`
  exits 0.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- Docs units in this area FAIL on prose accuracy (esc-left-4, esc-chat-6/7,
  rnc-1). Every sentence you touch must be checkable against a named suite
  row, and every residual list must stay open-ended (never claim
  completeness).

## Escalation
- If cmdsub-1 landed different row ids or a different OB count, use the landed
  values and report the discrepancy.

## Operator steps (not units)
- O1: Build the sweep corpus at cmdsub-1 execution time (edit 8). The corpus
  is machine-local (AS2).
- O2 (bypass hunting): A hunt for further command-substitution, re-parse, or
  second-shell bypasses beyond cmdsub-1's frozen table is an **operator
  step**, run by a human outside agent sessions, because the session's safety
  classifier refuses to author bypass commands (R5). Procedure: build the
  transcript corpus (O1), run `tests/hdg-differential-sweep.sh` old-vs-new,
  and for any command the new gate still allows that writes DECISION under
  real bash in a scratch fixture, record it. Any finding becomes a new spec,
  not an amendment here.

## Out of scope
- R-CS-a, R-QP-a and the narrowed R-QP-b (declared residuals).
- `reviewed-path-gate.sh` F-1 (still deferred).
- The esc-fu-2 glossary tension and long-line notes.
- The probe-script notes; `scripts/probe-hook-identity.sh` and its test.
- Any CONTEXT.md "payload" terminology change (advisory only; harness sense
  stays in the harness glossary).

## Open Questions
None. The scope, over-block budget, fix location, and terminology were each
resolvable from the caller's brief plus the qp-1/qp-2 and rnc-1 prior art,
and are recorded as self-resolved lines in Clarifications. If the differential
sweep at execution time shows `new_denials` > 10 or `new_allowances` > 0,
cmdsub-1 escalates to the user then (Escalation), rather than this spec
pre-committing a narrower rule.

## Self-check
- CHK1: Does each Goal clause map to a step criterion? — PASS:
  U1 → CS greps; U2/U3 → family-table greps + mutants; W1 → `word start or
  after a` count 0; W2 → `neither token is spelled` count 0; W3 →
  `not the whole enumeration`/`R-CS-a`/`gate-cmdsub-closure.md` greps;
  sweep → summary + OB count; version → jq/CHANGELOG/version-stamp-check;
  glossary → cmdsub-2 entry greps.
- CHK2: Is the family-table criterion bounded (not "blocks every
  substitution form")? — PASS: N tied to the commit's branch table, outside
  spellings are residual R-CS-a and operator step O2 (guards against the
  hdg-prose-2 cap).
- CHK3: Is the over-block budget defined, including what happens past it? —
  PASS: `new_allowances=0`, ≤ 10 new denials, else escalate; OB-15 onward.
- CHK4: Do cmdsub-1 and cmdsub-2 agree on the OB count after cmdsub-1? —
  PASS: both key off 14 + K from the commit message.
- CHK5: Is the U3 "scan on the lex-failure branch too" requirement explicit,
  so the fix is not silently skipped the way qp-1 skipped it? — PASS: edit 3
  and the Clarifications technical line both state it.
- CHK6: Does the spec avoid listing concrete bypass spellings, per the
  caller? — PASS: the three examples are described, never reproduced; the
  operator step O2 carries the hunt.
- CHK7: Is the W2 phrasing defined as an invariant to preserve rather than a
  new correction (since qp-1 already fixed it)? — PASS: Context W2 and the
  count-0 criterion.
- CHK8: Is `command_skeleton()` protected from edits, given U1 is tempting to
  fix there? — PASS: Clarifications (fix location) and Do NOT touch keep
  `lib/` byte-unchanged; U1 reads substitutions from the raw command in the
  gate.
- CHK9: Is the marker-audit sweep disposition stated? — FAIL (missing) in the
  draft (the sweep did not finish) — revised in place: Context records it as
  incomplete-not-empty and hands the re-run to each reviewer.
- CHK10: Does P3 hold per commit? — PASS: cmdsub-1 bumps in its one commit;
  cmdsub-2 asserts the empty `agents`/`templates` diff.
- CHK11: Is an operator step for bypass hunting present, as the caller asked?
  — PASS: O2 under Operator steps.

## Scribe update hint
- After cmdsub-1: one wiki changelog line — "command-substitution glob
  hiding (U1) and quoted/escaped second-shell payloads (U2/U3) closed in the
  human-decision gate; residual R-CS-a".
- After cmdsub-2: no CONTEXT.md change. These are harness-glossary terms, not
  domain terms (the "payload" overlap at CONTEXT.md:854 is noted advisory
  only).
