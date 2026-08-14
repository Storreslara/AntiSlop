# Executable-bit regressions on directly-invoked hook scripts (issue #273)

Status: FINAL — ready for dispatch (fast path, 2 units)
Author: spec-master | Date: 2026-08-14 | Tracker: issue #273

## Goal

Make an executable-bit regression on a directly-invoked hook script
**mechanically detectable at merge time**, and close the technique-level root
cause that produced the regression twice during unit #262, so the failure mode
"a gate is silently off and nobody knows" cannot recur undetected.

## Context

### The premise checks out — the bit is load-bearing, not cosmetic

The dispatch brief asked me not to assume the issue title's framing is
correct. It is correct, and I verified it directly rather than inferring it:

- `hooks/hooks.json` invokes all 11 of its registered scripts as bare commands
  with **no `bash` prefix** (`hooks/hooks.json:7-61`). A file without `+x`
  fails with exit 126 / permission denied.
- Both adapter ports do the same: `adapters/codex/hooks/hooks.json:6-36` and
  `adapters/cursor/hooks/hooks.json:5-19`.
- The twelfth script, `hooks/scripts/reviewer-tier.sh`, is not in
  `hooks.json`, but `CONTEXT.md:221` documents it as invoked directly as a CLI
  (`hooks/scripts/reviewer-tier.sh <task-id> <git-range>`), so its bit is
  load-bearing too.

That is **24 files** whose executable bit is a live correctness property
(12 canonical + 6 codex + 6 cursor).

### But two sub-populations are NOT load-bearing, and the issue's suggested fix hits both

The issue's suggested command is
`find hooks/scripts -name '*.sh' ! -perm -u+x`. I ran it. It produces a
**false positive** today, because `find` recurses and `hooks/scripts/lib/*.sh`
is `644` **by design** — those files are `source`d, never executed
(`hooks/scripts/human-decision-gate.sh:37-38`,
`hooks/scripts/dispatch-hygiene.sh:84`, `hooks/scripts/stop-gate.sh:114`).
A non-recursing glob (`hooks/scripts/*.sh`) excludes them for free.

The issue also suggests covering "the executable test suites under
`tests/*.sh`". Evidence says no such population exists:

- `tests/validate.sh` invokes **every** shell test via
  `bash tests/<name>.test.sh` — 15 call sites covering 15 distinct test files,
  with no `./` invocation anywhere (e.g. `tests/validate.sh:100,271,316,352`).
- CI invokes the suite via `bash tests/validate.sh`
  (`.github/workflows/validate.yml:15`).
- 5 test scripts are **already `644`** in the index, each with a `#!` shebang
  (`human-decision-gate.test.sh`, `microworld-rerun.test.sh`,
  `reviewer-route-gate-caller.test.sh`, `stop-gate-blocked.test.sh`,
  `stop-gate-escalated.test.sh`).

So on `tests/*.sh` the bit is decorative, the current state is already
inconsistent, and asserting it would go red today against no real failure
mode. See Open Question 1 — this is the one point where the spec knowingly
departs from the issue text.

### `bin/cli.js` is not the root cause — it is the amplifier

I checked every write path that can land a `.sh` file. Both preserve mode
from the source file:

- `copyDirRecursive` chmods each copy from the source's `stat.mode`
  (`bin/cli.js:145-146`) — this is the path all three scaffolds use: cursor
  (`bin/cli.js:1484`), codex (`bin/cli.js:1883`), and the claude target
  copying `hooks/scripts` into `.claude/hooks/scripts` (`bin/cli.js:2180`).
- `writeSpecBody` chmods `raw` specs (the hook scripts) from the packaged
  source's mode (`bin/cli.js:461-462`), under a comment that states the intent
  outright: "'raw' specs (hook scripts) go out verbatim with the packaged
  file's mode, so a restored gate stays executable".

The consequence is the opposite of a `--update` bug, and it raises the stakes
rather than lowering them: **the repo's own mode is the single point of
truth, and a regression here propagates to every adapted project on its next
`--update`.** No `bin/cli.js` change is warranted or included.

### Root cause of the #262 loss

`.claude/reviewed/262.fail` and the issue body agree: a head/heredoc/tail
Bash splice — used because `Write`/`Edit` are unavailable in a teammate
dispatch — recreated `hooks/scripts/reviewer-route-gate.sh` and
`tests/validate.sh` via shell redirection. Shell redirection **creates a new
file at the umask default (`644`)**, discarding `755`.

That technique is not an improvisation: it is *prescribed* by
`templates/persona-protocol.md:67-70` ("fall back immediately to `Bash` — a
quoted heredoc (`cat > file << 'EOF'`) for whole-file authoring"), and that
prescription says nothing about mode. That silence is the root cause, and
Step 2 closes it.

### Why the detector alone is insufficient

Step 1 bounds the damage inside this repo. It cannot reach the case the
fable critique was actually worried about: an agent splicing a hook script
**inside a consumer project's `.claude/hooks/scripts/`**, where
`tests/validate.sh` does not exist. There, a dropped `+x` disables the gate
with no detector anywhere in the loop. Only Step 2 reaches that case.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-08-14 Functional scope & success criteria: Q Does the assertion cover
  `tests/*.sh`, as the issue's suggested fix says it should? → A
  (self-resolved): No. Every test is invoked via `bash`, CI invokes the suite
  via `bash`, and 5 test scripts are already `644` with shebangs — the bit is
  decorative there and asserting it would fail today against no real failure
  mode. Recorded as Open Question 1 because it departs from the issue text.
- 2026-08-14 Functional scope & success criteria: Q Does the assertion cover
  the adapter ports independently, or are they derived at build time? → A
  (self-resolved): Independently. Adapter port blobs are hand-adapted, not
  byte-identical copies (differing blob SHAs under `git ls-files -s`), their
  modes are separately committed, and their own `hooks.json` files invoke
  them directly. All three port directories are covered.
- 2026-08-14 Edge cases / failure handling: Q Should `hooks/scripts/lib/*.sh`
  be asserted executable? → A (self-resolved): No — they are `source`d, are
  `644` by design, and the issue's suggested `find` command flags them as a
  false positive. A non-recursing glob excludes them.
- 2026-08-14 Edge cases / failure handling: Q What happens when the check runs
  outside a git work tree (e.g. an extracted npm tarball), where
  `git ls-files` returns empty? → A (self-resolved): The index half prints a
  visible `SKIP` rather than silently passing on an empty enumeration; the
  working-tree half still runs. A per-directory non-empty guard prevents the
  glob half from going vacuous the same way.
- 2026-08-14 Technical constraints & tradeoffs: Q Assert the working-tree mode
  (`test -x`) or the git index mode (`git ls-files -s`)? → A (self-resolved):
  Both, as two independent halves. Mutation testing (see Step 1 acceptance
  criteria) shows they catch different states: a local `chmod 644` fails the
  working-tree half while the index still reads `100755`, and only the index
  half is immune to a checkout filesystem that cannot represent the bit.
- 2026-08-14 Technical constraints & tradeoffs: Q Should the fix stop at a
  detector, or also close the root cause? → A (self-resolved): Also close it.
  The detector cannot reach a splice performed inside a consumer project,
  which is the fail-open scenario that motivated prioritising this issue.
  Split into an independent Step 2 so it can be dropped without affecting
  Step 1.

Terminology (`antislop:ubiquitous-language`, prose mode, against
`CONTEXT.md`):
- Lens 1 (glossary term used differently): no drift. **Gate** is used per
  `CONTEXT.md:63` ("a hook script that mechanically blocks an action"). The
  distinct compound "merge gate" for `tests/validate.sh` is established by
  constitution P5 and is used only in that sense.
- Lens 2 (new synonym for a defined term): one avoided. The dispatch brief
  said "adapter-port mirrors"; this repo uses **adapter port** for
  `adapters/*` (`CONTEXT.md:83,156,159`) and reserves "mirror" for the
  rendered `.claude/` copies (`CONTEXT.md:502`). This spec keeps them
  distinct and does not introduce the merged term.
- Lens 3 (load-bearing new term with no entry): one. "**Mode assertion**" (a
  merge-gate check that a file's executable bit matches its invocation
  contract) has no `CONTEXT.md` entry. Suggested for `scribe` — see the
  Scribe update hint.

## Risks / dependencies

- **R1 — No prior `.fail` record exists for this work.** I enumerated all 55
  records under `.claude/reviewed/` (not a sample); none corresponds to issue
  #273. `.claude/reviewed/262.fail` is *adjacent* — it is the record that
  documents this defect being fixed inside unit #262 — but it is not a prior
  attempt at #273. No unit here should be tagged `haiku` on that basis alone;
  Step 2 in particular is protocol prose with a wide render fan-out.
- **R2 — Step 2 cuts against active compression pressure.** The gh348
  persona-efficiency audit has been compressing
  `templates/persona-protocol.md`. Step 2 adds lines to it. Mitigation: the
  addition is capped at 5 lines and must not add a `## ` header.
- **R3 — Step 2 is a source-artifact + render-step pair.** Per the
  "Source-artifact + render-step gating rule" (`CONTEXT.md:497-513`), editing
  `templates/persona-protocol.md` and regenerating its rendered copies
  **cannot be gated as separate units**. Step 2 is therefore a single unit
  covering source edit, regeneration, version bump, and CHANGELOG entry.
- **R4 — Step 2's blast radius is bounded, and this is load-bearing to
  verify, not assume.** `tests/adapter-protocol-parity.test.js` keys its
  parity map on **exact `## ` headers** with content probes
  (`tests/adapter-protocol-parity.test.js:42-76`), and
  `tests/protocol-doc-drift.test.js` compares **section counts**. Adding a
  bullet *inside* an existing section changes neither, so **no adapter port
  edit is required**. If a `## ` header were added, both go red and the unit
  balloons.
- **R5 — `templates/persona-protocol-slim.md` does not carry the target
  section** (verified: it has 7 `## ` sections and no "heredoc" occurrence).
  Slim-tier personas therefore will not receive the Step 2 guidance. That is
  the tier's existing design, not a defect introduced here; extending slim is
  out of scope.
- **R6 — Step 1 has no version-stamp dependency.** `tests/validate.sh` is not
  a version-stamped file under constitution P3, so Step 1 needs no version
  bump. Step 2 does.
- **R7 — Steps are independent and may be dispatched in either order or
  separately.** Step 1 touches only `tests/validate.sh`; Step 2 touches only
  the protocol source and its rendered copies. There is no shared file.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied. Every load-bearing claim in this spec
  was executed, not inferred — the invocation style was read out of all three
  `hooks.json` files, the `bin/cli.js` mode-preservation claim was read at its
  two chmod sites, and the proposed check block was run against the real tree
  and against four mutations (see Step 1 acceptance criteria).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Step 2
  regenerates the rendered copies with `node bin/cli.js --update` rather than
  hand-editing `.claude/agents/*.md`, which is exactly the hand-edit this
  principle forbids.
- P3 "Version-stamp discipline": satisfied. Step 2 edits a template and
  therefore bumps `.claude-plugin/plugin.json` + `package.json` and adds a
  CHANGELOG entry. Step 1 touches no version-stamped file and correctly bumps
  nothing.
- P5 "`tests/validate.sh` is the merge gate": satisfied — and this spec is an
  instance of it. The new check lands in `tests/validate.sh` rather than in a
  narrower or faster side file, which is what makes it binding.

## Step 1 — Mode assertion in `tests/validate.sh`

Add a check that every directly-invoked hook script is executable, in both
the working tree and the git index.

**Affected files:** `tests/validate.sh` (only).

**Placement:** immediately after the `== bash syntax ==` block
(`tests/validate.sh:11-19`), before `== JSON validity ==`. The suite uses a
flat sticky `fail=0` / `fail=1` accumulator gated once at
`tests/validate.sh:587-592`, so there is no "appended below the gate" vacuity
trap here; early placement is for fast feedback and matches the issue text.

**Shape** (the block was executed as written; reproduce this behaviour, not
necessarily this formatting):

```bash
echo
echo "== hook script executable bits =="
# hooks.json (and both adapter ports' hooks.json) invoke these scripts
# DIRECTLY, with no `bash` prefix, so a lost +x silently disables that gate
# (issue #273; regressed twice inside unit #262). */lib/*.sh are sourced,
# never executed, and are 644 by design - the non-recursing glob excludes
# them.
for d in hooks/scripts adapters/codex/hooks/scripts adapters/cursor/hooks/scripts; do
  n=0
  for f in "$d"/*.sh; do
    [ -e "$f" ] || break
    n=$((n + 1))
    if [ -x "$f" ]; then
      echo "OK   $f executable"
    else
      echo "FAIL $f is not executable (invoked directly; a lost +x disables this gate)"
      fail=1
    fi
  done
  if [ "$n" -eq 0 ]; then
    echo "FAIL no *.sh found under $d/ - executable-bit check would be vacuous"
    fail=1
  fi
done
# The git index is what actually ships, and it is immune to a checkout
# filesystem that cannot represent the bit.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  bad=$(git ls-files -s hooks/scripts adapters/codex/hooks/scripts adapters/cursor/hooks/scripts \
        | grep -v '/lib/' | awk '$1 != "100755" { print $1 "  " $4 }')
  if [ -z "$bad" ]; then
    echo "OK   git index records mode 100755 for every directly-invoked hook script"
  else
    echo "FAIL git index records a non-executable mode:"
    echo "$bad"
    fail=1
  fi
else
  echo "SKIP git index mode check (not inside a git work tree)"
fi
```

**Acceptance criteria** (all machine-checkable; A3-A6 are mutation tests that
prove the check is not vacuous — run them in a throwaway copy, e.g.
`git archive HEAD | tar -x -C <tmp>` then `git init` there, never against the
working repo):

- **A1** `bash -n tests/validate.sh` exits 0.
- **A2** `bash tests/validate.sh` exits 0 with zero `FAIL` lines against the
  unmodified tree, and its output contains the literal line
  `== hook script executable bits ==` and the literal string
  `git index records mode 100755`.
- **A3** (working-tree detection) In a throwaway copy, `chmod 644
  hooks/scripts/stop-gate.sh`, then `bash tests/validate.sh` exits non-zero
  and emits a `FAIL` line naming `hooks/scripts/stop-gate.sh`. Measured
  behaviour: the index half still reports OK at this point, which is the
  point of having two halves.
- **A4** (index detection) In that copy, commit the `644` mode, then
  `bash tests/validate.sh` exits non-zero and emits **both** a working-tree
  `FAIL` naming the script **and** a `FAIL` line containing `100644`.
- **A5** (vacuity guard) In that copy, remove every `*.sh` under
  `adapters/cursor/hooks/scripts/`, then `bash tests/validate.sh` exits
  non-zero with a `FAIL` line containing `would be vacuous`.
- **A6** (no-git degradation) In that copy, `rm -rf .git`, then
  `bash tests/validate.sh` emits a line containing
  `SKIP git index mode check` and the working-tree half still evaluates every
  file.
- **A7** (no false positive on sourced libs) `bash tests/validate.sh` emits no
  `FAIL` line containing `/lib/`, with `hooks/scripts/lib/*.sh` left at their
  current `644`.
- **A8** (scope is exactly the load-bearing set) `bash tests/validate.sh`
  emits no `FAIL` line containing `tests/`, with the 5 currently-`644` test
  scripts left untouched.
- **A9** `git diff --stat` for this unit lists `tests/validate.sh` and nothing
  else, and `git diff --summary HEAD~1 HEAD` reports **no** `mode change`
  entries (this unit must not itself regress a mode).

**Do NOT touch:** `bin/cli.js` (already mode-correct — see Context); any file
under `hooks/scripts/` or `adapters/*/hooks/scripts/`; the 5 `644` test
scripts; `templates/persona-protocol.md`.

## Step 2 — Close the root cause in the heredoc-fallback prescription

Add mode-preservation guidance at the exact point the protocol prescribes the
technique that dropped the bit.

**Affected files:**
- `templates/persona-protocol.md` (source edit — one added bullet)
- `.claude/agents/*.md` (10 files), `.claude/persona-protocol.md`,
  `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`,
  `.claude/persona-config.json` — all **regenerated**, never hand-edited
- `.claude-plugin/plugin.json`, `package.json` (version bump), `CHANGELOG.md`

This file set is the exact set touched by the repo's existing regeneration
commits (verified against `git show --stat e379ada`).

**Edit:** insert one bullet in `## Teammate Write/Edit fallback and gate
rephrasing doctrine`, immediately after the existing "fall back immediately
to `Bash`" bullet (`templates/persona-protocol.md:67-70`). Max 5 lines. Must
**not** introduce a `## ` header (see R4). Suggested text:

```
- A heredoc recreates the file at your umask default (usually `644`),
  silently dropping an executable bit the original had. Capture the mode
  first (`stat -c %a`), restore it after (`chmod`), or `chmod --reference` an
  untouched sibling — hook scripts are invoked directly, so a lost `+x`
  disables that gate outright.
```

**Regeneration:** `node bin/cli.js --update` (the deterministic path required
by constitution P2). Bump `.claude-plugin/plugin.json` and `package.json` in
lockstep and add a CHANGELOG entry, per P3.

**Acceptance criteria:**

- **B1** `grep -c '^## ' templates/persona-protocol.md` returns the same
  number before and after the edit (capture the pre-edit value first; do not
  hard-code it into the test).
- **B2** `grep -q 'chmod --reference' templates/persona-protocol.md` exits 0.
- **B3** `node tests/adapter-protocol-parity.test.js` exits 0.
- **B4** `node tests/protocol-cross-references.test.js` exits 0.
- **B5** `node tests/protocol-doc-drift.test.js` exits 0.
- **B6** The new bullet is present in the rendered copies of every persona
  whose protocol row keeps that section: for each such file,
  `grep -q 'chmod --reference' .claude/agents/<name>.md` exits 0. Derive the
  persona list from `PROTOCOL_SECTIONS_BY_PERSONA` (`bin/cli.js:588`) rather
  than hard-coding it, and assert the derived list is non-empty.
- **B7** `python3 -c "import json;
  a=json.load(open('package.json'))['version'];
  b=json.load(open('.claude-plugin/plugin.json'))['version'];
  assert a==b, (a,b)"` exits 0, and that version differs from the version at
  the unit's base commit.
- **B8** `CHANGELOG.md` contains an entry naming the new version.
- **B9** `bash tests/validate.sh` exits 0 with zero `FAIL` lines.
- **B10** `git diff --summary <base> HEAD` reports **no** `mode change`
  entries for this unit — the unit that fixes the mode-loss class must not
  commit a mode loss. (If Step 1 has already merged, `bash tests/validate.sh`
  enforces this independently.)

**Do NOT touch:** `.claude/agents/*.md` by hand (regenerate only);
`templates/persona-protocol-slim.md` (see R5); any adapter port
(`adapters/**`) — R4 establishes no port edit is required, and an edit there
would be unreviewable scope creep; `tests/validate.sh` (Step 1 owns it);
`bin/cli.js`.

## Open Questions

1. **Should `tests/*.sh` be in scope after all?** The issue's suggested fix
   says to cover "the executable test suites under `tests/*.sh` that are
   expected to stay directly runnable". Evidence says no such population
   exists today: everything is invoked via `bash`, and 5 test scripts are
   already `644`. **Recommended default (assumed by this spec): exclude
   `tests/` entirely** — assert only the 24 directly-invoked hook scripts.
   Options, if the default is wrong:
   (a) exclude `tests/` [default, specified above];
   (b) normalise — `chmod +x` the 5 `644` test scripts and extend the
   assertion to `tests/*.sh`, accepting that the bit stays decorative;
   (c) assert only `tests/validate.sh` itself, on the grounds that a human or
   reviewer may run it as `./tests/validate.sh` (as unit #262's reviewer did).
   Flipping to (b) or (c) is a ~2-line change to Step 1 plus a `chmod`; it
   does not restructure the spec. This question does **not** block dispatch.

2. **Is Step 2 wanted at all?** It is the only part that reaches a splice
   performed inside a *consumer* project, but it adds lines to a protocol
   under active compression pressure (R2) and carries a version bump plus a
   14-file regeneration. **Recommended default: do Step 2.** Dropping it
   leaves Step 1 fully valid and independently dispatchable (R7).

Neither question blocks Step 1. If both are answered "default", this spec is
executable as written.

## Self-check

- **CHK1:** Is the set of files the assertion covers stated exactly, rather
  than by a glob the reader must evaluate? — PASS (24 files: 12 canonical + 6
  codex + 6 cursor, with the `lib/` exclusion and its reason stated).
- **CHK2:** Do the Context section and Step 1 agree on whether `tests/*.sh`
  is in scope? — PASS (both exclude it; A8 asserts the exclusion mechanically
  rather than leaving it implicit).
- **CHK3:** Does the plan say what happens when `git ls-files` returns nothing
  because the check is running outside a work tree? — FAIL (missing) in the
  first draft, where the index half would have silently passed on an empty
  enumeration — the exact vacuity class this spec exists to prevent — revised
  in place (the `git rev-parse --is-inside-work-tree` guard, the per-directory
  `n -eq 0` guard, and criteria A5/A6).
- **CHK4:** Is every acceptance criterion runnable, with a pass/fail signal,
  rather than a prose assertion? — PASS (A1-A9 and B1-B10 are all commands
  with exit codes or literal-string greps).
- **CHK5:** Does the plan justify covering the adapter ports independently,
  rather than assuming it? — PASS (differing blob SHAs, separately committed
  modes, and their own `hooks.json` direct-invocation lines are all cited).
- **CHK6:** Does the plan state whether `bin/cli.js` needs changing, with
  evidence, rather than leaving it open? — PASS (two chmod sites cited; stated
  as amplifier, not cause; on both steps' "Do NOT touch" lists).
- **CHK7:** Do Step 1 and Step 2 disagree about which file owns the mode
  assertion? — PASS (Step 1 owns `tests/validate.sh`; Step 2's "Do NOT touch"
  names it explicitly).
- **CHK8:** Is Step 2's blast radius asserted or merely hoped for? — FAIL
  (ambiguous) in the first draft, which claimed "no adapter edits needed"
  without a mechanism — revised in place (R4 now cites the parity test's
  header-keyed map and the doc-drift test's section counts, and B1/B3/B5 turn
  the claim into runnable checks).
- **CHK9:** Does the plan define what "root cause" means here concretely
  enough that Step 2 has a specific insertion point? — PASS (shell redirection
  at umask default; insertion point given as
  `templates/persona-protocol.md:67-70`).
- **CHK10:** Is the departure from the issue's own suggested fix surfaced
  where a reader will see it, rather than buried? — FAIL (missing) in the
  first draft, which self-resolved it in Clarifications only — converted to
  Open Question 1, and additionally called out in Context.
- **CHK11:** Does the plan state whether a prior `.fail` record exists for
  this work, based on the full record set rather than a sample? — PASS (R1;
  all 55 records enumerated).
- **CHK12:** Does either step risk committing the very defect it fixes? — PASS
  (A9 and B10 assert no `mode change` entries in each unit's own diff).
- **CHK13:** Does the plan settle Step 2's cost/benefit — a version bump plus
  a 14-file regeneration, against compression pressure (R2) — rather than
  assuming a root-cause fix is automatically worth its blast radius? — FAIL
  (ambiguous) — the benefit is evidenced (it is the only part reaching a
  consumer-project splice) but the tradeoff is a scope decision no amount of
  repo evidence settles — converted to Open Question 2.

## Scribe update hint

After Step 1 merges, `CONTEXT.md` warrants a glossary entry for **Mode
assertion** (Lens 3 above): *a merge-gate check that a file's executable bit
matches its invocation contract — `755` for scripts invoked directly by a
`hooks.json` command entry or as a CLI, `644` for scripts that are only
`source`d.* Worth recording alongside it: the non-obvious fact that
`hooks/scripts/lib/*.sh` are `644` **by design**, which is the trap the
issue's own suggested `find` command fell into.

If Step 2 merges, the "Teammate Write/Edit fallback" doctrine's new
mode-preservation rule is a protocol-level behaviour change and belongs in
the wiki's protocol summary alongside the existing heredoc guidance.

## Publication note

Per the fast-path convention (≤2 dispatchable units), this document in
`docs/plans/` is the canonical artifact and no new tracker issues are cut —
**issue #273 is the tracker item**, and the dispatch contracts below point at
this file. `task-master` and `to-tickets` are deliberately not invoked.
