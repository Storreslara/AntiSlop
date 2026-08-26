# Debug spec — `spec2-unitE`: stale `fileHashes` baselines after a managed-mirror render

**Date:** 2026-08-26
**Escalated unit:** `spec2-unitE` ("Unit E — `protected-paths.sh` coverage vs.
risk class", `docs/plans/2026-08-25-agent-throughput-performance-dampeners.md`)
**Trigger:** shared-protocol 2-FAIL cap.
**Type:** focused debug spec (diagnosis + revised/supplementary criteria).
**Not** a from-scratch replan — Unit E's own scope (AC-E1..AC-E4, E8) is
unchanged and is not re-derived here.

---

## Goal

Close the second FAIL's blocking defect and stop this failure class from
recurring a fourth time, in one unit:

1. Confirm the stale `fileHashes` baselines are genuinely gone (they are —
   a sibling commit swept them; see Diagnosis D5), rather than asserting it
   from the escalation brief.
2. Re-establish `bash tests/validate.sh` exit 0 as Unit E's completion signal
   at a commit that is Unit E's own.
3. Add a **standing** guard for the "recorded hash disagrees with on-disk
   content" defect — the one this session has now hit three times — so it is
   caught *directly and by name* at the merge gate, instead of surfacing as a
   misattributed assertion inside `tests/cli-backfill.test.js`.

---

## Context

Unit E is a hook-gate coverage unit. Every hook change in this repo is a
**four-copy change** (`hooks/scripts/` source artifact plus the `.claude/`,
`adapters/codex/` and `adapters/cursor/` managed mirrors), and the three
mirrors are content-hash-tracked in `.claude/persona-config.json`'s
`fileHashes` map. `bin/cli.js` owns that map end to end: `sha256Hex` computes
entries, `backfillFileHashesFromDisk` seeds them, and the `--update` render
loop compares each mirror's on-disk content against its recorded baseline to
decide *updated / already current / pending / healed*.

The first FAIL was a genuine security defect (a jq fail-open in
`protected-paths-core.sh` on legacy string-shaped `protectedPaths` entries).
Commit `9832876` fixed it correctly in all four copies. The second FAIL is
entirely a bookkeeping consequence of that fix: the mirrors moved, the
baselines did not.

---

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-08-26 Non-functional attributes: Q What runtime budget may a new
  standing check consume, given the plan's own warning (spec lines 666-669)
  that every suite registered in `tests/validate.sh` runs inside the 102.56 s
  stop-gate command? → A (self-resolved): measured — `bash tests/validate.sh`
  at `ed19d88` takes **1 m 51 s** wall; the proposed check runs in **84 ms**
  (0.08 %). Budget is a non-issue, and AC-F4 pins it so a future
  reimplementation cannot quietly turn it into a repo-copying check.
- 2026-08-26 Edge cases / failure handling: Q Does a naive
  "`sha256sum <file>` vs recorded `fileHashes` value" check produce false
  positives? → A (self-resolved): **yes — 13 of 52 entries at a known-green
  HEAD.** Every `kind !== 'raw'` entry (the ten `.claude/agents/*.md` files
  plus `persona-protocol.md`, `persona-protocol-slim.md`,
  `protocol-digest.md`) records the hash of the *stamp-stripped* body, per
  `bin/cli.js:476`. The check MUST route through `stripStamp` before hashing.
  Measured with it: **52/52 clean, 0 mismatches**. This is the single most
  load-bearing correction in this spec — see D6.
- 2026-08-26 Technical constraints & tradeoffs: Q Should the standing guard
  be the render-fixed-point command (CONTEXT.md:1937) or a read-only hash
  comparison? → A (self-resolved): a read-only hash comparison. The
  render-fixed-point form (`node bin/cli.js --update --force-render && git
  status --porcelain`) *would* catch this defect, but it **mutates the tree**
  and presupposes a clean one, so it can only ever be a per-unit criterion,
  never a standing gate. That is precisely why `mw-step3`'s AC-R3 did not
  generalize. See D7 for the third candidate (`--update --dry-run`) and the
  two measured reasons it was rejected.
- 2026-08-26 Completion / acceptance signals: Q What is the completion signal,
  given Unit E's own AC-E1..AC-E4 say nothing about `validate.sh`? → A
  (self-resolved): `bash tests/validate.sh` exit 0 at the unit's final commit,
  per constitution §5. Measured at `ed19d88`: **exit 0, 1719 OK, zero FAIL**
  (one advisory `WARN` from `claude plugin tag --dry-run`, which
  `tests/validate.sh:130` explicitly does not fail on).

Terminology note (`ubiquitous-language`, prose mode, against `CONTEXT.md`):
Lens 1 — no glossary term is used with a divergent meaning; **render fixed
point** (CONTEXT.md:1937) and the **source-artifact + render-step gating
rule** (CONTEXT.md:898) are both used in their canonical senses. Lens 2 — no
new synonym introduced; this spec says **managed mirror** throughout, matching
CONTEXT.md:1945, rather than "mirror copy" or "shipped copy". Lens 3 — one
load-bearing new term with no glossary entry: **hash baseline currency** (a
`fileHashes` entry agreeing with its file's stamp-stripped content hash).
It is *not* a synonym for render fixed point — this unit is the proof they
are separable, since the content was correct and only the baseline was stale.
Suggested for `scribe` to add to `CONTEXT.md`; not a blocker for this unit.

---

## Risks / dependencies

- **R1 — Prior defect history on this unit.** `.claude/reviewed/spec2-unitE`'s
  FAIL record is the *second* for this unit; there is no third attempt
  available under the shared protocol. This unit must not be tagged `haiku`
  when dispatched. The first FAIL was a security fail-open, the second a
  four-copy bookkeeping miss — both required judgment the model tier has to
  support.
- **R2 — Concurrent siblings are landing in the same tree.** `spec2-unitA`
  (`stop-gate-core.sh`) and `spec2-unitB` (`ed19d88`) both touched
  `persona-config.json`'s `fileHashes` while Unit E was in review, and
  `ed19d88` is what actually swept Unit E's stale entries. **Every
  verification for this unit must run in a detached worktree**, not the live
  tree, or a sibling's uncommitted state will be misattributed to Unit E —
  exactly the confusion the second FAIL record had to disclaim.
- **R3 — Blast radius of a new standing gate.** Adding a check to
  `tests/validate.sh` makes it a merge gate for *every* future unit, not just
  this one. Measured today at 0 false positives across all 52 entries; the
  one theoretical false-positive shape (`--update --keep=<path>`, which
  deliberately leaves a baseline stale, `bin/cli.js:1438-1448`) is recorded as
  Assumption A1 below.
- **R4 — Constitution §2 forbids hand-editing `fileHashes`.** It names the
  field explicitly. The remedy for a stale baseline is therefore always
  `node bin/cli.js --update --force-render`, never editing the JSON — which is
  what `ed19d88` did, and what AC-F3's failure message must tell a future
  maintainer to do.
- **D — Depends on nothing.** No sibling unit blocks this; `ed19d88` is
  already at `HEAD`.

---

## Constitution check (.claude/constitution.md v1.0.0)

- §1 "Verify, don't assume": satisfied — every claim in this document is a
  live measurement in a detached worktree, including the two that **correct**
  the escalation brief (D5, D6).
- §2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  new check is read-only and never writes `fileHashes`; the prescribed remedy
  for a failure is the deterministic `--force-render`, not a hand-edit. The
  already-landed correction at `ed19d88` came from a `--force-render` run, so
  no deviation was incurred there either.
- §3 "Version-stamp discipline": satisfied, no bump needed — this unit touches
  only `tests/`, and no file under `tests/` is version-stamped or present in
  `fileHashes` (verified: all 52 keys are under `.claude/` or `adapters/`).
- §4 "Optional personas degrade gracefully": satisfied — not applicable; no
  persona prose changes.
- §5 "`tests/validate.sh` is the merge gate": satisfied and strengthened —
  the deliverable *is* a new merge-gate check, and AC-F5 requires the gate be
  green at the unit's final commit.

---

## Part 1 — Root-cause diagnosis

`antislop:fail-triage` step 1 (VERIFY) — **confirmed, live, not read off the
record.** In a detached worktree at `9832876`:

```
node tests/cli-backfill.test.js   # exit 1, 2 test(s) failed
```

The two failures are `F2 regression: shape B ... must leave the working tree
clean post-run, got:  M .claude/persona-config.json` and `--update --dry-run
discriminates all three F2 drift shapes on exit code alone (C2.12): a
genuinely current tree must exit 0, got 3`.

`antislop:fail-triage` step 2 (CATEGORIZE) — **spec/criterion defect**, not a
code defect. The production change at `9832876` is correct and stays. What
failed is the plan: Unit E's criteria (AC-E1..AC-E4) never required the
four-copy change's *baseline* half, and nothing at the merge gate names it.

### D1 — The mechanism, confirmed at `bin/cli.js:1396-1431`

For each managed mirror the `--update` loop computes three values:

| value | source | at `9832876` |
|---|---|---|
| `cleanHash` | `sha256Hex(renderCleanBody(spec, config))` — a fresh render from the source artifact | `ece14a6d…` |
| `sha256Hex(currentStripped)` | the mirror actually on disk | `ece14a6d…` |
| `recordedHash` | `config.fileHashes[relKey]` | `519b6223…` |

`noLocalEdits` (line 1399) is `recordedHash && sha256Hex(currentStripped) ===
recordedHash` → **false**, because the baseline is stale. So the `already
current` (1401) and `updated` (1416) branches are both skipped, and control
reaches line 1427:

```js
// Even if recordedHash is stale, if the actual current content already
// matches a fresh clean regeneration, there's no real divergence — just
// silently heal the stale hash and move on.
if (currentStripped === cleanBody) {
  newFileHashes[relKey] = cleanHash;
  summary.push(`  ${relKey}: hash ${dryRun ? 'would be healed' : 'healed'} (content unchanged, hash was stale)`);
  continue;
}
```

The heal writes `newFileHashes`, which line 1487-1489 flushes back to
`persona-config.json`. **That write is the defect's whole visible surface**:
a run that should have been a no-op mutates the tree. The brief's diagnosis is
correct on every point.

### D2 — Why `9832876` produced this state

The commit is four files, `hooks/scripts/lib/protected-paths-core.sh` and its
three managed mirrors, `.pattern` → `.pattern?`. Its message states the
mirrors were regenerated with `node bin/cli.js --update --force-render`. That
command *does* refresh `fileHashes` — but `.claude/persona-config.json` was
then left out of the commit. The four-copy constraint (spec lines 644-651) is
really a **five-artifact** constraint: three managed mirrors plus the baseline
map that tracks them.

### D3 — Why the merge gate did not say so

`tests/validate.sh:302` runs `diff -rq hooks/scripts .claude/hooks/scripts`.
That is a **content** parity check, and at `9832876` it passed — the content
*was* correct. Nothing in `validate.sh` looks at `fileHashes` at all. The only
thing that noticed was `tests/cli-backfill.test.js`, and it noticed by
accident: `buildF2GitFixture` (line 1154-1171) does `cp -r` of the **entire
real repo** into a temp git repo, so the repo's own stale baselines became a
property of the fixture. The resulting message —

> `shape B must leave the working tree clean post-run (no self-heal write for
> a pending file), got:  M .claude/persona-config.json`

— names a synthetic drift shape, not the real cause. The true cause appears
only as three `hash would be healed (content unchanged, hash was stale)` lines
buried in an ~80-line dry-run summary. **This misattribution is the process
defect**, and it is what turned a one-line correction into three separate
multi-hour detours.

### D4 — Third occurrence, confirmed by record, not by assertion

- `mw-step3` — FAIL record cites `.claude/agents/lead-programmer.md` and
  `.claude/persona-config.json` (`fileHashes`) "stale by the same render";
  required its own debug spec, `docs/plans/2026-08-25-debug-mw-step3-mirror-regeneration.md`.
- `mw-step2` — PASS record notes a residual entry "recorded `b7bc181d…`,
  actual `1e714a4e…`", `cli.js` reporting `hash would be healed (content
  unchanged, hash was stale)`; pre-authorized as DR3 in the mw-step3 debug
  spec and later swept by `9b1e768`.
- `spec2-unitE` — this one.

**The remedy already existed and did not generalize.** The mw-step3 debug spec
invented the render-fixed-point criterion (AC-R3, now canonical at
CONTEXT.md:1937) — and it would have caught `9832876`. But AC-R3 is a *per-unit
acceptance criterion*, applied only to the one unit that happened to draw it,
because the command mutates the tree and cannot stand as a repo-wide gate.
Nothing carried the lesson forward, so Unit E reproduced the class 24 hours
later. That is the case for a durable fix, and it is why the fix must take a
**read-only** form.

### D5 — CORRECTION to the escalation brief: the narrow defect is already fixed

Verified independently, not taken from the coordinator's note.
`ed19d88` ("feat(spec2-unitB): cheapen the redundant stop-gate
testAndLintCommand run") ran its own `--force-render` and swept Unit E's three
stale entries as a side effect; its commit message says so explicitly. At
`HEAD` = `ed19d88`, with a clean tree:

- all three entries record `ece14a6d…`, matching the actual sha256 of all four
  copies of `protected-paths-core.sh`;
- `node tests/cli-backfill.test.js` → **exit 0**, 122 OK, zero FAIL;
- `node bin/cli.js --update --dry-run` → **exit 0**, writes nothing;
- `bash tests/validate.sh` → **exit 0**, 1719 OK, zero FAIL.

So the revised criteria below are **verification, not remediation**. No
`fileHashes` edit is to be authored by hand (constitution §2); if AC-F1 is
already green on arrival, that is the expected outcome, not a reason to
manufacture a diff.

Second, smaller correction: the FAIL record says the live tree's uncommitted
`persona-config.json` was entangled with "Unit A's stop-gate-core.sh changes
**and its removal of the `hooks/scripts/lib/stop-gate-core.sh`
`protectedPaths` entry**". The entanglement was real (three of six changed
lines were Unit A's `stop-gate-core.sh` baselines), but the `protectedPaths`
removal was not: the diff touched `fileHashes` only, six lines, no
`protectedPaths` hunk. That entry is present at `HEAD`
(`.claude/persona-config.json:117`). Immaterial to the verdict; recorded so
the next reader does not chase it.

### D6 — CORRECTION to the proposed process fix: the obvious check is wrong

The escalation brief proposes catching "a hook-lib-mirror file's content hash
doesn't match its recorded `fileHashes` entry". Implemented literally with
`sha256sum`, that check **fails 13 of 52 entries at a known-green `HEAD`**:

```
MISMATCH .claude/agents/orchestrator.md  recorded=4aefafae…  actual=85ab2381…
MISMATCH .claude/agents/explorer.md      recorded=0a148a47…  actual=88d99067…
… 11 more (the other 8 agents, persona-protocol.md,
  persona-protocol-slim.md, protocol-digest.md)
```

Every `kind !== 'raw'` artifact carries an ADAPT version stamp, and
`bin/cli.js:476` records the hash of the **stamp-stripped** body:
`config.fileHashes[relKey] = sha256Hex(stripStamp(fs.readFileSync(destAbsPath, 'utf8')))`.
A check that hashes the raw bytes is therefore comparing two different things
for 13 entries, and would have shipped a permanently-red merge gate.

Both `sha256Hex` and `stripStamp` are already exported from `bin/cli.js`
(module.exports, ~line 2530). Routing through them — rather than
reimplementing sha256 in Bash — is what makes the check both correct and
immune to drift if the stamp format ever changes. Measured that way:
**52/52 clean, 0 mismatches, 84 ms**, and it correctly covers the ten
`.claude/agents/*.md` files too, which is *broader* than the brief's
hook-lib-only scope at no extra cost.

### D7 — Why not `node bin/cli.js --update --dry-run`?

It is read-only (measured: writes nothing), it exits 0 at `HEAD` and 3 at
`9832876`, and it would be a one-line addition. It was still rejected, for two
measured reasons:

1. **Version-bump coupling.** `bin/cli.js:1359`'s fast path requires
   `config.pluginVersion === version`. After a constitution-§3 version bump but
   before `--update` re-stamps the mirrors, line 1403-1409 sets
   `wouldMutate = true` for every stamped artifact, and line 1508
   (`if (dryRun && wouldMutate) process.exit(3)`) turns the merge gate red for
   a reason that has nothing to do with hash currency. §3 makes that transient
   state mandatory on every stamped change.
2. **Invoking-machine dependence.** The registration-backfill write sites
   (~lines 1169/1179/1193) read the real `~/.claude/settings.json`. This is a
   documented hazard — `tests/cli-backfill.test.js:1179-1194` had to introduce
   `buildF2Home` specifically because the behaviour differs between a dev box
   with the marketplace plugin enabled and a CI runner with no `~/.claude` at
   all. A merge gate whose verdict depends on the runner's home directory is a
   worse gate than none.

The hash check has neither property: `stripStamp` makes it stamp-invariant, and
it reads nothing outside the repo.

---

## Part 2 — Revised and supplementary acceptance criteria

These **replace nothing** in Unit E's AC-E1..AC-E4/E8. They are the additional
conditions for this unit to reach PASS. Every command is stated with its
measured outcome, so a reviewer can distinguish "green because fixed" from
"green because vacuous".

- **AC-F1 (hash baseline currency — the escalated defect, verification form).**
  Every `fileHashes` entry agrees with its file's stamp-stripped content hash.
  Run from the repo root in a detached worktree at the unit's final commit:

  ```
  node tests/filehashes-currency.test.js   # exit 0
  ```

  *Measured today:* exit 0 at `ed19d88` (52 entries, 0 mismatches). Because
  `ed19d88` already swept the three stale entries (D5), this criterion is
  expected to be green on arrival. **Do not hand-edit `fileHashes` to satisfy
  it** — constitution §2 names that field explicitly; if it is ever red, the
  remedy is `node bin/cli.js --update --force-render` plus committing the
  resulting `persona-config.json`.

- **AC-F2 (AC-F1 is non-vacuous — historical replay against the real defect).**
  The new check must fail on the commit that actually carried the defect. Copy
  the script into a detached worktree at `9832876` and run it there:

  ```
  git worktree add --detach <tmp> 9832876
  cp tests/filehashes-currency.test.js <tmp>/tests/
  cd <tmp> && node tests/filehashes-currency.test.js
  ```

  Must exit **1** and name **exactly three** paths —
  `.claude/hooks/scripts/lib/protected-paths-core.sh`,
  `adapters/codex/hooks/scripts/lib/protected-paths-core.sh`,
  `adapters/cursor/hooks/scripts/lib/protected-paths-core.sh` — each reporting
  `recorded=519b6223…` against `actual=ece14a6d…`. *Measured with a prototype:
  exit 1, exactly those three, those two hashes.* This is a stronger proof than
  a synthetic mutation: it is the real regression, replayed.

- **AC-F3 (no false positive on stamped artifacts — the D6 trap, pinned).**
  The check must route through `bin/cli.js`'s exported `stripStamp` before
  hashing, and must not special-case or skip any entry to achieve AC-F1. Two
  parts, both required:
  1. The script covers **all** `fileHashes` keys — assert the count it
     examines equals `Object.keys(config.fileHashes).length` (52 at `HEAD`),
     with no path-prefix filter that would exclude `.claude/agents/*.md`.
  2. A self-test inside the script (operating on an in-memory or temp-dir
     fixture, never on the real `persona-config.json`) proves it fires on a
     corrupted baseline for **both** artifact kinds: one raw hook script and
     one stamped `.md`. *Measured with a prototype:* corrupting
     `.claude/agents/reviewer.md`'s baseline to all-zeros yields exit 1 with
     `actual=45d03327…` — i.e. the stripped hash reproduces the original
     recorded value exactly, which is the property AC-F3 exists to pin.

  A missing `fileHashes` key whose file does not exist on disk is a failure,
  not a skip (all 52 keys are git-tracked at `HEAD`; verified).

- **AC-F4 (the check is read-only and cheap).** The script writes nothing and
  spawns no subprocess that could. Both parts:

  ```
  git status --porcelain            # unchanged across the run
  ```
  and its wall time is **under 1 s** on the repo. *Measured with a prototype:
  84 ms, tree unchanged.* This criterion exists because the two rejected
  designs (D7, and the render-fixed-point form) both violate it, and a future
  reimplementation could silently regress into one of them — `validate.sh`
  already costs 1 m 51 s, and a repo-copying check would be a material tax on
  every unit in every sibling spec.

- **AC-F5 (registered at the merge gate, and the gate is green).** The new
  script is invoked from `tests/validate.sh` in the repo's existing idiom
  (`if node tests/… ; then echo "OK   …" ; else echo "FAIL …"; fail=1; fi`),
  placed adjacent to the existing content-parity check at `tests/validate.sh`
  line 298-307 so the two read as the pair they are — that one guards mirror
  **content**, this one guards mirror **baselines**. Then:

  ```
  bash tests/validate.sh    # exit 0
  ```

  in a detached worktree at the unit's final commit. *Measured at `ed19d88`
  before this unit's change: exit 0, 1719 OK, zero FAIL.* Constitution §5;
  this is Unit E's completion signal, and its absence is what the second FAIL
  record called out.

- **AC-F6 (Unit E's original criteria still hold at the new HEAD).** The second
  FAIL verified AC-E1/E2/E3/E4/E8 at `9832876`; the tree has since moved to
  `ed19d88` plus this unit's commit. Re-run at the unit's final commit:

  ```
  node tests/protected-paths-coverage.test.js   # exit 0
  bash tests/protected-paths-gate.test.sh       # exit 0
  ```

  and confirm all four copies of `protected-paths-core.sh` remain
  byte-identical and still contain `.pattern?` (not `.pattern`). *Measured at
  `ed19d88`: all four sha256 `ece14a6d…`; both suites green inside
  `validate.sh`.* This is a guard against the fix-forward silently regressing
  under a sibling's `--force-render`, which is exactly how `ed19d88` was able
  to touch Unit E's files in the first place.

- **AC-F7 (scope containment).** `git show --stat <fix-sha> --name-only` names
  **exactly** two paths and nothing else:

  ```
  tests/filehashes-currency.test.js
  tests/validate.sh
  ```

  No `fileHashes` edit, no hook-script edit, no `plugin.json` bump
  (constitution §3 does not apply — nothing under `tests/` is version-stamped
  or tracked in `fileHashes`; verified against all 52 keys).

### Reference shape (intent only — `lead-programmer` authors the real script)

Not production code; this is the measured prototype that produced every figure
above, included because the `stripStamp` call is the load-bearing detail
(D6) and prose alone kept understating it.

```
require bin/cli.js → { sha256Hex, stripStamp }
read .claude/persona-config.json → fileHashes
for each [relPath, recordedHash]:
    if file missing            → report MISSING, count as failure
    actual = sha256Hex(stripStamp(readFile(relPath)))
    if actual !== recordedHash → report MISMATCH relPath, recorded, actual
report the count examined (must equal the key count)
exit 1 if any failure, else 0
on failure, the message must name the remedy:
    "run `node bin/cli.js --update --force-render` and commit the resulting
     .claude/persona-config.json — never hand-edit fileHashes (constitution §2)"
```

---

## Part 3 — Recommendation on the durable process fix

**Recommended: yes, add it — as AC-F1/AC-F3/AC-F4/AC-F5 above, one small
script plus a five-line registration, inside this unit.** The reasoning, in
the terms the brief asked for:

- **The existing detection is real but misattributed.** `cli-backfill.test.js`
  catches this only because its fixture `cp -r`s the whole repo; the assertion
  that fires is about a synthetic drift shape, and the true cause is three
  lines inside an 80-line summary (D3). Three occurrences, three detours, each
  one spent rediscovering the same one-line correction. The value here is not
  additional detection — it is *attribution*.
- **The remedy was already invented and still did not stick.** mw-step3's
  render-fixed-point criterion would have caught `9832876`, but it is
  structurally confined to per-unit use because it mutates the tree (D4, D7).
  A read-only check is the form that can actually stand at the gate.
- **It is genuinely small and genuinely cheap.** ~25 lines reusing two
  existing `bin/cli.js` exports, 84 ms against a 1 m 51 s gate, zero new
  dependencies, zero false positives across all 52 entries.
- **It is complementary, not duplicative.** `tests/validate.sh:302` guards
  mirror *content*; nothing guards mirror *baselines*. The two are separable —
  this unit is the proof, since content parity was green throughout.

**Deliberately not recommended**, so a future maintainer does not "improve"
the check into one of them: adding `--update --dry-run` to the gate (D7),
adding the render-fixed-point command to the gate (mutating), or narrowing the
check to `hooks/scripts/**` only (the broader form is measured at 0 false
positives and additionally covers the ten agent mirrors).

---

## Open Questions

None blocking. One named assumption, carried deliberately:

1. **A1 — `--update --keep=<path>` is not a supported state in this repo.**
   `bin/cli.js:1438-1448` deliberately leaves a baseline pointing at the old
   pre-edit value when a file is `--keep`-ed, so a `--keep`-ed artifact would
   fail AC-F1. Recommended default (taken): **treat it as a hard FAIL, not a
   WARN.** Grounds: `tests/validate.sh:302` already forbids
   `.claude/hooks/scripts` from diverging from `hooks/scripts` at all, so a
   kept local edit there is independently a merge-gate failure today; and a
   measured 0 of 52 entries are in that state. If a legitimate `--keep` need
   ever arises, the narrowing is one line (skip entries listed in a declared,
   reasoned exemption list — the same shape AC-E1 already uses for
   `protectedPaths` coverage), not a redesign. Flagged rather than silently
   assumed because it is the only way this check can ever produce a false red.

---

## Self-check

- CHK1: Is the escalated defect's current status stated as a measurement
  rather than inherited from the brief? — PASS (D5: four commands, each with
  its exit code, at `ed19d88` in a detached worktree)
- CHK2: Does AC-F1 have a runnable pass/fail command? — PASS
- CHK3: Is AC-F1 proved non-vacuous against the *actual* regression rather
  than a synthetic one? — PASS (AC-F2 replays `9832876` and pins the three
  paths and both hash prefixes)
- CHK4: Does the spec state what happens if AC-F1 is already green on arrival?
  — FAIL (missing) — revised in place; AC-F1 now says green-on-arrival is the
  expected outcome and forbids manufacturing a diff, and D5 says the criteria
  are verification rather than remediation.
- CHK5: Do the diagnosis and the criteria agree on which command is the
  completion signal? — PASS (`bash tests/validate.sh` exit 0, in the
  Clarifications log, in the §5 constitution line, and in AC-F5)
- CHK6: Is the false-positive risk of the recommended process fix quantified
  rather than asserted? — PASS (D6: 13/52 for the naive form, 0/52 for the
  recommended form, both measured)
- CHK7: Is the runtime cost of the new gate check bounded by a criterion? —
  PASS (AC-F4, under 1 s, measured 84 ms against a 1 m 51 s gate)
- CHK8: Do the criteria say which artifact kinds the check must cover, so a
  narrower implementation cannot pass? — PASS (AC-F3 part 1 pins the count to
  the key count and forbids a path-prefix filter; AC-F3 part 2 requires a
  both-kinds mutation self-test)
- CHK9: Is the `--keep` false-positive shape represented somewhere, rather
  than silently assumed away? — FAIL (missing) — converted to Open Question 1
  (Assumption A1).
- CHK10: Does the spec state whether constitution §3 requires a version bump?
  — PASS (Constitution check §3 and AC-F7; nothing under `tests/` is stamped
  or in `fileHashes`, verified against all 52 keys)
- CHK11: Do the Risks section and the dispatch contract agree that
  verification must happen in a detached worktree? — PASS (R2 and the
  Acceptance criteria both say so, for the same stated reason)
- CHK12: Is the "third occurrence" claim sourced, or asserted? — PASS (D4
  cites `mw-step3`'s FAIL record, `mw-step2`'s PASS record, and this unit's
  FAIL record by name)

---

## Scribe update hint

Two entries worth recording once this lands:

1. **`CONTEXT.md` glossary — "Hash baseline currency"**: a `fileHashes` entry
   agreeing with its file's *stamp-stripped* content hash. Distinct from
   **Render fixed point** (CONTEXT.md:1937), which covers content; this unit
   is the proof they are separable. Note the `stripStamp` trap (D6) in the
   entry itself, since the naive reading is wrong for 13 of 52 entries.
2. **`CONTEXT.md:898` "Source-artifact + render-step gating rule"**: extend it
   to say the four-copy change is really a **five-artifact** change — the
   three managed mirrors *plus* `persona-config.json`'s `fileHashes` — and
   that `tests/validate.sh` now checks the fifth directly.

Not this unit's work; routed to `scribe` separately.

---

## Dispatch contract (≤5 units — fast path, no `task-master`)

### Unit: `spec2-unitE-fix`

#### Objective

Add a standing, read-only merge-gate check that every `.claude/persona-config.json`
`fileHashes` entry agrees with its file's stamp-stripped content hash, and
verify that the escalated defect (three stale
`protected-paths-core.sh` baselines) is gone and Unit E's original criteria
still hold. **No `fileHashes` value is to be hand-edited** — a sibling commit
already corrected them via `--force-render`.

#### Retrieval

There is no tracker issue for this unit. The authoritative spec is this file:
`/home/sebas/AntiSlop/docs/plans/2026-08-26-debug-spec2-unite-stale-hash-baselines.md`
Read Part 1 (diagnosis) and Part 2 (AC-F1..AC-F7) before starting. The parent
unit's spec is
`/home/sebas/AntiSlop/docs/plans/2026-08-25-agent-throughput-performance-dampeners.md`,
"Unit E" (lines 618-628) and AC-E1..AC-E4 (lines 866-878).

#### Affected files

- `tests/filehashes-currency.test.js` — **new**.
- `tests/validate.sh` — registration only, ~5 lines, adjacent to the existing
  content-parity check at lines 298-307.

Nothing else. In particular **not** `.claude/persona-config.json`, **not** any
`protected-paths-core.sh` copy, **not** `.claude-plugin/plugin.json`.

#### Ordered edits

1. Write `tests/filehashes-currency.test.js`. Require `sha256Hex` and
   `stripStamp` from `../bin/cli.js` (both are already exported). Read
   `.claude/persona-config.json`, iterate **every** `fileHashes` key, and
   compare `sha256Hex(stripStamp(<file contents>))` against the recorded
   value. Report each mismatch with the path and both hashes; report a missing
   file as a failure. Print the number of entries examined. Exit 1 on any
   failure, 0 otherwise. On failure, print the remedy: run
   `node bin/cli.js --update --force-render` and commit the resulting
   `.claude/persona-config.json`; never hand-edit `fileHashes` (constitution
   §2). See the "Reference shape" block in Part 2 for intent.
2. Add the both-kinds self-test required by AC-F3 part 2, operating on a
   temp-dir or in-memory fixture — never on the real `persona-config.json`.
   Follow the mutation-proof convention used elsewhere in `tests/` (e.g. the
   `mutation control` cases in `tests/cli-backfill.test.js`).
3. Register it in `tests/validate.sh` immediately after the existing
   `== this repo's hook-script mirror is at parity with hooks/scripts/ ==`
   block (lines 298-307), using the same `if … then echo "OK   …" else echo
   "FAIL …"; fail=1; fi` idiom as line 583. Give it a heading that names what
   it guards, e.g.
   `== persona-config fileHashes baselines match on-disk content ==`.
4. Verify AC-F1..AC-F7. Commit both files in one commit.

#### Do NOT touch

- `.claude/persona-config.json` — constitution §2 forbids hand-editing
  `fileHashes`, and the entries are already correct at `HEAD`.
- Any copy of `protected-paths-core.sh`, or `protected-paths.sh` — Unit E's
  production change is done and correct.
- `.claude-plugin/plugin.json` / `CHANGELOG.md` — no version bump applies.
- `tests/cli-backfill.test.js` — its F2/C2.12 assertions are correct as
  written; the new check sits alongside them, it does not replace them.
- Do not widen the check into `--update --dry-run` or the render-fixed-point
  command; both were measured and rejected (D7).

#### Acceptance criteria

AC-F1 through AC-F7 in Part 2, verbatim. Run every one of them **in a detached
worktree at your final commit**, not in the live tree — concurrent sibling
units are landing in this repo and their uncommitted state will otherwise be
misattributed to this unit (R2):

```
git worktree add --detach <tmp> <your-final-sha>
```

The completion signal is `bash tests/validate.sh` exit 0 there (AC-F5).

#### Pre-resolved context

Do not re-derive these; they are measured, in a detached worktree, 2026-08-26.
Verify only a specific claim you actually doubt.

- `HEAD` is `ed19d88`. `bash tests/validate.sh` there is **exit 0**, 1719 OK,
  zero FAIL (the one `WARN` is `claude plugin tag --dry-run`, advisory by
  design at `tests/validate.sh:130`). Wall time **1 m 51 s**.
- The three stale baselines are **already corrected** at `HEAD` by `ed19d88`;
  all four copies of `protected-paths-core.sh` hash to
  `ece14a6db8fccd707bdfe5f9508ddee24ab983d47195a0eef3fd123be0f29656`.
  `node tests/cli-backfill.test.js` at `HEAD` is exit 0 (122 OK).
- `.claude/persona-config.json` has **52** `fileHashes` entries; all 52 are
  git-tracked; **13** of them are stamped artifacts (ten `.claude/agents/*.md`
  plus `persona-protocol.md`, `persona-protocol-slim.md`,
  `protocol-digest.md`) whose baselines are stamp-stripped hashes.
- `bin/cli.js` exports both `sha256Hex` and `stripStamp` (module.exports,
  ~line 2530). `stripStamp` is `body.replace(STAMP_LINE_RE, '')`
  (`bin/cli.js:293-295`); `bin/cli.js:476` is the site that establishes the
  stripped-hash convention.
- The self-heal branch is `bin/cli.js:1427-1431`; the config flush that
  dirties the tree is `bin/cli.js:1487-1489`.
- A prototype of the check measured **52/52 clean / exit 0 / 84 ms** at `HEAD`,
  and **exit 1 naming exactly the three `protected-paths-core.sh` mirrors** at
  `9832876`.
- `tests/validate.sh:302` is the existing content-parity check
  (`diff -rq hooks/scripts .claude/hooks/scripts`); `tests/validate.sh:583` is
  the registration idiom to copy.

#### Escalation

This unit's parent already consumed both attempts under the 2-FAIL cap, so it
carries no defect budget of its own. Stop and report rather than improvising
if any of these occur:

- AC-F1 is **red** on arrival — that means a fourth occurrence landed while
  this unit was being dispatched. Report it; do not hand-edit `fileHashes`,
  and do not run `--force-render` as part of this unit without saying so
  first, since that would silently widen the diff past AC-F7.
- AC-F3's all-entries requirement and AC-F1's exit-0 requirement cannot both
  be met — i.e. a genuine mismatch exists that `--force-render` does not
  resolve. That is a new defect class, not this one; report it.
- `bash tests/validate.sh` is red at your final commit for a reason unrelated
  to your two files (a concurrent sibling unit). Name the failing suite and
  the commit; do not fix a sibling's work inside this unit.
