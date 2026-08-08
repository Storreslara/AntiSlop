# Gate audit: case 26 T3/T4 vacuity, and the two deferred flag inventories

Issue: #185 ("Deferred from #184"). Canonical artifact for the three items
deferred out of #184's "Scoping call". Date: 2026-08-07.

---

## Goal

Close all three items #185 tracks, each with a measured verdict rather than an
inherited one:

1. **T3/T4 vacuity** — answer the research question ("is the redirection-anchor
   divergence reachable at all?") by measurement, then apply the fix shape that
   answer implies. **Answer: it is not reachable.** Convert T3/T4 from a
   differential sweep that cannot fail into a one-directional block assertion
   with an allow-control and a mutation control.
2. **`gh` flag inventory** — audit it. **A gap was found**, though not the one
   #185 predicted: no `gh` *flag* writes a caller-named local path, but
   `gh api` is a general-purpose authenticated HTTP client and is allowlisted
   whole. Narrow the allowlist.
3. **`rg` flag inventory** — audit it. **Moot, no change warranted**: #186
   removed `rg` from the allowlist outright, so there is no inventory left to
   audit. Recorded, with the verifying command, so it does not decay into
   folklore a second time.

Plus the stale non-vacuity comment #185's closing paragraph names.

---

## Context

Everything in this section is measured on this tree (gate at `f2d8d2d`,
`gh version 2.96.0`, suite runtime 11.5 s), not inherited. Commands that
reproduce each figure are given with the acceptance criteria.

### Two premises in #185's own text are stale, and both change the work

#185 was written on 2026-07-31, before #186 landed. Two of its statements no
longer describe the tree:

- **"`program_allowed()` gives `rg` and `git` an extra flag scan"** — it does
  not. Commit `0baaab6` (#186) deleted `git`, `rg`, *and the flag scan itself*.
  `hooks/scripts/reviewed-path-gate.sh:61-71` now carries a plain program
  allowlist with exactly one subcommand check (`gh`) and no flag scan anywhere.
  This is what makes item 3 moot, and it removes the "mirror the `rg`/`git`
  pattern" fix shape item 2 proposed — there is no such pattern left to mirror.
- **"the shape #184 used for case 28"** — case 28 no longer exists.
  `0baaab6` retired it along with the flag scans it asserted;
  `tests/reviewed-path-gate.test.sh` goes 27 -> 30, and lines 473-475 say so
  ("RELOCATED from the retired flag-boundary block"). **The live analogue in
  the same file is case 30** (`tests/reviewed-path-gate.test.sh:439-485`):
  one-directional block assertions, a set of allow-controls bounding the
  over-block, and a documented reviewer-run mutation control. That is the shape
  Step 1 mirrors, and the citation #185 intended.

### Item 1: the divergence is not reachable — three measurements

Case 26 (`tests/reviewed-path-gate.test.sh:318-408`) crosses five templates with
every byte `0x01`-`0x7F`. Per template, gate-allowed counts and observable
filesystem effects, measured by replaying the suite's own
`bash_run`/`sweep_differential` logic with the sandbox diff widened from the
marker directory to the **whole sandbox**:

| template | gate-allowed | allowed bytes | observable effect anywhere |
|---|---|---|---|
| T1 | 5 of 127 | `09 20 28 29 3C` | none |
| T2 | 124 of 127 | (most) | none |
| T3 | 5 of 127 | `09 20 28 29 3C` | none |
| T4 | 5 of 127 | `09 20 28 29 3C` | none |
| T5 | 118 of 127 | (most) | none |

Total 635 probes, **257** gate-allowed.

**(a) Both exemptions are sound over their entire masked domain.** Calling
`mask_inert_redirections()` in isolation, the mask fires on exactly **9 of 127**
bytes for each of the two forms (the metacharacter set minus `>`, which leaves a
surviving `>`). In **0** of those 18 cases does real bash create a file. The
`&[0-9]+` alternative can only mask a purely numeric word, which bash always
treats as a descriptor duplication (or a dup error), never a file redirect; the
`/dev/null` alternative can only mask a literal `/dev/null`. There is no byte at
which the gate believes "inert" and bash writes.

**(b) T3/T4 cannot fail even against a deliberately broken gate.** Widening the
anchor set in `mask_inert_redirections()` to the POSIX space class (adding VT
`0x0B`, FF `0x0C`, CR `0x0D`) — the mask-side analogue of case 26's own mutation
control, and a genuine fail-open — moves T3/T4 from 5 to **8** gate-allowed
bytes each. The differential half still observes **no effect at all**. A test
that stays green against a gate known to be wrong is vacuous by demonstration,
not by argument.

**(c) The root cause is the template family, not the sandbox.** This is the part
#182's debug spec left as "latent divergence" and it can now be stated
positively. In both templates the masked prefix is glued to the front of the
tail, so the filename bash would open under a fail-open is
`1<byte>.claude/reviewed/9.pass` or `/dev/null<byte>.claude/reviewed/9.pass` — never
`.claude/reviewed/9.pass`. The leading `&N` digit is mandatory for the fd mask to fire at
all, and `/dev/null` is mandatory for the other. **No payload in this template
family can write into the marker directory through these two exemptions**,
whatever the gate does. That is why no payload was constructible in #182: none
exists.

Amendment A5 of `docs/plans/2026-07-31-reviewed-path-gate-write-intent.md:882-884`
prescribes the fix for exactly this finding — "Where the effect is genuinely
unobservable, the honest form is a one-directional block assertion with an
explicit mutation control, not a differential test that can never fail."

**A5's own cautionary note applies to this spec and was honoured.** A5 records
that #184 wrongly inferred "writes nothing" for `git diff --output=F` from an
exit code, and that git in fact truncates the target. Every "no effect" above is
therefore a `find`-diff of the whole sandbox before and after real execution,
never an inference from a return code.

### Item 2: `gh`'s flag surface is clean; `gh api` is not

Enumerating every flag of every subcommand under `gh issue`, `gh pr`, `gh api`
and `gh search` (gh 2.96.0): **no flag writes to a caller-named local path.**
Every path-taking flag reads — `-F/--body-file`, `--input`, `-F key=@path`,
`-T/--template <file>`. (`-t/--template <string>` is a Go template expression,
not a file.) So the literal question #185 asked answers **no**.

The gap is one level up. `gh api` is a general-purpose authenticated HTTP client,
and the allowlist admits it by top-level subcommand with no further check, so
these are all **allowed** by the current gate (measured — gate verdicts only,
nothing executed against the network):

    ALLOW  gh api -X PUT repos/O/R/contents/.claude/reviewed/9.pass -f message=x -f content=<base64>
    ALLOW  gh api --method PUT repos/O/R/contents/.claude/reviewed/9.pass --input body.json
    ALLOW  gh api -X DELETE repos/O/R/contents/.claude/reviewed/9.pass -f message=x -f sha=<sha>

That is a write to a caller-chosen path, with the marker path spelled in plain
sight, through a fully allowlisted command — a fail-open of the allowlist, not
an instance of the documented substring-early-exit limitation (which is about
*obfuscating* the path; here nothing is hidden). It writes the marker into the
repository rather than onto local disk; an ordinary `git pull` afterwards, whose
own text need never spell the path and which is therefore never inspected,
completes the forgery.

**A flag scan cannot close this soundly**, which is why the fix shape #185
proposed is the wrong one even setting aside that its model no longer exists:

- `gh api`'s method is **implicit** — "the default HTTP request method is `GET`
  normally and `POST` if any parameters were added" (`gh api --help`). So
  `-f`/`-F`/`--field`/`--raw-field` are method-mutating with no `-X` present.
- `gh api graphql -f query='mutation{...}'` is a third write path that names no
  REST route at all.

Enumerating those is a denylist, which fails open on every form the enumeration
missed. #186 ratified the alternative for precisely this situation: "Validating
ambient state would mean enumerating a third-party program's entire
configuration surface - a denylist, which fails open on every key the
enumeration missed - so the surface was removed instead of inspected"
(`hooks/scripts/reviewed-path-gate.sh:50-53`). Step 2 applies that ruling.

**Removal is close to free.** `program_allowed()` is only ever consulted for a
command whose text already contains the marker path (the substring early-exit at
`reviewed-path-gate.sh:268-271` returns first otherwise). Dropping `api`
therefore changes the verdict on no `gh api` invocation except one that spells
the marker directory — which is the exact set that should be blocked.

**Audited and deliberately NOT fixed here:** `gh pr checkout <n>` materialises
whatever files a branch carries, including a forged marker, and its command text
need not spell the marker path — so it never reaches `program_allowed()` at all
and de-allowlisting `pr` would not change its verdict. This is the pre-existing
substring-early-exit limitation already documented at
`reviewed-path-gate.sh:28-31` and in README's "Known limitations", not a new
finding. Recorded in Step 3 so the next audit does not re-derive it.

### Item 3: no change warranted

`rg` is not on the allowlist. `grep -n "rg" hooks/scripts/reviewed-path-gate.sh`
matches only prose in the header explaining its removal, and case 30 pins
`rg pat <marker>` as blocked (`tests/reviewed-path-gate.test.sh:470-471`). There
is no flag inventory to complete because there is no `rg` entry to guard. The
honest output is a documented conclusion, not a diff.

### Prior-defect history (not `haiku`-eligible)

`.claude/reviewed/177.fail` and `.claude/reviewed/182.fail` are both defects in this same file's
word-boundary handling, and #184 was a third of the same class. `182.fail` in
particular is the record of the two-attempt escalation that produced the debug
spec #185 cites. Every unit below touches either that lexer's test coverage or
the allowlist it guards. **Do not tag any unit here `haiku`.**
(`.claude/reviewed/205.fail` also matches a grep for this filename but is a documentation
defect in `hooks.md`, unrelated to the gate's logic.)

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-07 Functional scope & success criteria: Q Item 1's fix shape is
  contingent on a research question #185 leaves open — is the redirection-anchor
  divergence reachable? → A (self-resolved): not reachable, established by the
  three measurements in Context (exemption soundness, survival against a broken
  gate, and the template-family argument). The contingency therefore resolves to
  #185's own stated fallback: convert to a block assertion. No differential fix
  is specced.
- 2026-08-07 Non-functional attributes: Q Does item 2's finding carry a
  disclosure constraint, and does the suite stay inside its runtime budget? → A:
  disclosure is Open Question 1 — this is a live fail-open in a security control
  in a public repository, and #186/#184 both withheld specifics from the public
  issue. Runtime: measured 11.5 s today; Step 1 removes 254 gate invocations
  from case 26 and adds 254 cheaper ones (no execution half), so the budget stays
  the 60 s figure #184 pinned.
- 2026-08-07 External dependencies & integrations: Q Is item 2's conclusion
  pinned to a `gh` version? → A (self-resolved): yes — measured on
  `gh version 2.96.0 (2026-07-02)`. The flag enumeration is a point-in-time
  inventory and Step 2's fix is deliberately shaped so it does not depend on it
  staying accurate: removing `api` is sound whatever flags gh adds later, which
  is the second reason to prefer removal over a scan.
- 2026-08-07 Edge cases / failure handling: Q Exactly which bytes must the
  converted T3/T4 assertion expect to be allowed rather than blocked? → A
  (self-resolved): exactly `0x09`, `0x20`, `0x28`, `0x29`, `0x3C` for both
  templates, measured. The other four anchor bytes (`0x0A`, `0x26`, `0x3B`,
  `0x7C`) mask the redirection but then split off a second segment whose first
  word is the marker path, which is not allowlisted, so the whole command is
  blocked. The assertion is stated over whole-command verdicts because that is
  what `bash_case` observes.
- 2026-08-07 Technical constraints & tradeoffs: Q Case 26's header says the
  sweep "never asserts that a probe is allowed, because doing so would freeze
  today's over-blocks in as required behaviour" — does Step 1's allow-control
  violate the file's own stated principle? → A (self-resolved): no, and the
  tension is deliberate and precedented. Case 30 already pairs block assertions
  with an explicit allow-control set for exactly this reason
  (`tests/reviewed-path-gate.test.sh:473-475`, "The over-block bound"). The
  principle case 26 states applies to a *differential sweep*, whose allowed set
  is incidental; a block-direction case needs an allow-control or it can pass by
  blocking everything. Step 1 requires the distinction be written into the new
  case's header so a reviewer does not open it as a finding.
- 2026-08-07 Terminology consistency: Q Does #185's own text name things that no
  longer exist? → A (self-resolved): yes, two — the `rg`/`git` flag scan and
  case 28. Both are corrected in Context above and both change the work, so this
  is not pedantry. Step 3 records the correction where a future reader will meet
  it.
- 2026-08-07 Completion / acceptance signals: Q What distinguishes "T3/T4 were
  converted" from "the converted assertion can actually fail"? → A
  (self-resolved): the mutation control in AC1.5, whose expected kill is
  measured, not predicted — 6 FAIL lines at bytes `0x0B`/`0x0C`/`0x0D` on both
  templates. Converting a vacuous test into a differently-vacuous one is the
  single most likely way to satisfy this spec's letter and miss its point.

---

## Risks and dependencies

- **RD1. Not `haiku`-eligible.** See "Prior-defect history". Three FAILs of one
  class on this file.
- **RD2. The mutation controls are reviewer-run and easy to void.** Both
  inherit case 26's and case 30's documented traps: `GATE_UNDER_TEST` must be an
  ABSOLUTE path or every case reads rc=127, and `lib/` must sit beside the
  mutated copy or the gate dies sourcing `lib/agent-identity.sh` and every case
  reads rc=1 — either failure looks like a kill and proves nothing. Both
  controls below restate this.
- **RD3. Step 2 is a behaviour-narrowing change that `--update` propagates.**
  `bin/cli.js` copies `hooks/scripts/*.sh` wholesale, so every adapted project
  gets the narrowing on update. #186 shipped the same shape as a MINOR bump
  under a `### Removed` heading (`CHANGELOG.md:309-318`); Step 3 mirrors that.
- **RD4. Disclosure.** Step 2's finding is exploitable as written. #184 and #186
  both kept technical specifics out of the public issue. Open Question 1.
- **RD5. Step 1 and Step 2 are independent** — different functions, different
  cases, no shared lines. They may be dispatched in either order or in parallel.
  Step 3 depends on both.
- **RD6. The non-vacuity floor must be re-measured, not re-derived.** Step 1
  changes the probe count, so the floor comment's figure changes with it. The
  expected value is given below, but AC1.3 requires the committed comment match
  the value the suite actually prints, so a wrong prediction here fails rather
  than propagates. This is the same stale-comment defect #185's closing
  paragraph reports ("255 of 635" vs a measured 257) being fixed at the root.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every Context claim carries a
  reproduction command, and the two inherited claims this spec could have taken
  on faith (#182's "no payload constructible", #185's "T3/T4 cannot fail") were
  independently re-measured rather than cited. A5's record of an exit-code
  inference that was wrong is why.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  file with a script-driven path is hand-edited; `hooks/scripts/*.sh` is copied
  by `bin/cli.js`, not templated.
- P3 "Version-stamp discipline": satisfied — Step 3 bumps the version and adds
  the CHANGELOG entry, mandatory because Step 2 changes a file `--update`
  propagates.
- P4 "Optional personas degrade gracefully": satisfied — no shared persona prose
  is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied — AC1.7, AC2.6 and
  AC3.4.

---

## Step 1 — convert case 26's T3/T4 into a block-direction case

**Affected files:** `tests/reviewed-path-gate.test.sh` (only).

Remove `T3` and `T4` from case 26's template loop, leaving `T1`, `T2`, `T5` and
the differential machinery otherwise untouched. Add a new **case 31**
immediately after case 30, asserting the two redirection-exemption trailing
anchors in the block direction, modelled on case 30's shape
(`tests/reviewed-path-gate.test.sh:439-485`). Its header must state, in prose:
why a differential form was abandoned (the effect is unobservable for this
template family — Context (c), stated as the reason, not as a measurement to be
re-run); that this is A5's prescribed form; and why asserting the allowed set
here does not contradict case 26's "never asserts that a probe is allowed"
(Clarifications, Technical constraints).

**Acceptance criteria**

- AC1.1 `bash tests/reviewed-path-gate.test.sh` exits 0.
- AC1.2 Case 26's own summary line reports **381** probes and **247**
  gate-allowed: the suite's output matches `case 26 sweep: 381 probes, gate
  ALLOWED 247`.
- AC1.3 The non-vacuity floor comment above that check names the value the suite
  actually prints for the new probe count, and no longer says `255 of 635`:
  `grep -c '255 of 635' tests/reviewed-path-gate.test.sh` is `0`, and
  `grep -c '247 of 381' tests/reviewed-path-gate.test.sh` is `1`. The `>= 200`
  floor itself is unchanged and still passes.
- AC1.4 Case 31 emits exactly **244** blocked assertions (122 non-anchor bytes x
  2 templates) and exactly **10** allow-controls (the 5 anchor bytes x 2
  templates):
  `bash tests/reviewed-path-gate.test.sh | grep -c '^OK   case 31 .* -> blocked'`
  is `244`, and
  `bash tests/reviewed-path-gate.test.sh | grep -c '^OK   case 31 .* -> allowed'`
  is `10`.
- AC1.5 **Mutation control (reviewer-run).** Widen the redirection anchor set to
  the POSIX space class in a scratch copy and point the suite at it:

      d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
      sed "s/pad meta=\$' \\\\t\\\\n;&|()<>'/pad meta=\$' \\\\t\\\\n\\\\v\\\\f\\\\r;\&|()<>'/" \
        hooks/scripts/reviewed-path-gate.sh > "$d/mutant.sh"
      grep -n "meta=" "$d/mutant.sh" | head -1
      GATE_UNDER_TEST="$d/mutant.sh" bash tests/reviewed-path-gate.test.sh; echo $?

  The `grep` line is part of the control, not decoration: confirm the mutation
  actually applied before trusting the run. Expected: exit 1 with **exactly 6**
  FAIL lines, all of them case 31, at bytes `0x0B`, `0x0C` and `0x0D` on each of
  the two templates, every one reading `rc=0` — the mutant allowed a payload the
  fixed gate blocks. `rc=1` means the mutant crashed and the run is void; see
  RD2 for the two traps.
- AC1.6 `time bash tests/reviewed-path-gate.test.sh` completes in under 60 s
  (11.5 s measured before this change).
- AC1.7 `bash tests/validate.sh` exits 0.

## Step 2 — remove `api` from `gh`'s subcommand allowlist

**Affected files:** `hooks/scripts/reviewed-path-gate.sh` (the `gh` arm of
`program_allowed()` and its comment), `tests/reviewed-path-gate.test.sh`
(new case 32).

Change the `gh` arm to admit `issue|pr|search` only. Replace its comment with
one that states why `api` is excluded: it is a general-purpose authenticated
HTTP client whose method is implicit (POST as soon as any `-f`/`-F` is present)
and which reaches GraphQL mutations naming no REST route, so no scan of the
command's text can bound what it writes — the same denylist-fails-open reasoning
recorded for `git` and `rg` immediately above it. Add **case 32** asserting the
blocked forms and an allow-control set, modelled on case 30.

**Acceptance criteria**

- AC2.1 `grep -n 'gh) case' hooks/scripts/reviewed-path-gate.sh` shows an arm
  matching `issue|pr|search` and not `api`.
- AC2.2 Case 32 asserts these are **blocked** (endpoint paths spelled with the
  marker directory via the suite's `$marker` variable, per the file's discipline
  that every assertion spelling the path lives in the test file):
  `gh api -X PUT repos/O/R/contents/$marker/9.pass -f message=x -f content=UEFTUwo=`,
  `gh api --method PUT repos/O/R/contents/$marker/9.pass --input body.json`,
  `gh api -X DELETE repos/O/R/contents/$marker/9.pass -f message=x -f sha=abc`,
  `gh api repos/O/R/contents/$marker/9.pass -f content=x`,
  `gh api graphql -f query=$marker`, and the bare read
  `gh api repos/O/R/contents/$marker/9.pass`. The bare read is included on
  purpose: it is the cost of the removal and must be pinned as a ratified
  over-block, not left to look like an oversight. Nothing in case 32 is executed
  against the network — the suite only ever feeds command strings to the gate.
- AC2.3 Case 32 asserts these remain **allowed** (the over-block bound):
  `gh issue close 9 --comment "see $marker/9.pass"`,
  `gh pr comment 9 --body "see $marker/9.pass"`,
  `gh search code --filename 9.pass $marker`,
  `cat $marker/9.pass`, `grep -r pat $marker`.
- AC2.4 `bash tests/reviewed-path-gate.test.sh` exits 0.
- AC2.5 **Mutation control (reviewer-run).** Point the reconciled suite at the
  pre-removal gate:

      d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
      git show HEAD:hooks/scripts/reviewed-path-gate.sh > "$d/unfixed.sh"
      GATE_UNDER_TEST="$d/unfixed.sh" bash tests/reviewed-path-gate.test.sh; echo $?

  (`HEAD` = the commit before this step lands.) Expected: exit 1 with FAIL lines
  covering **every** case 32 blocked form and no case 32 allow-control, each
  reading `rc=0`. RD2's two traps apply verbatim.
- AC2.6 `bash tests/validate.sh` exits 0.

## Step 3 — release hygiene and the durable record

**Affected files:** `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`, `README.md` ("Known limitations").

**Acceptance criteria**

- AC3.1 Version bumped to **0.28.0** in both `.claude-plugin/plugin.json` and
  `package.json` (MINOR, mirroring #186's 0.16.x -> 0.17.0 for the same kind of
  narrowing). `grep -c '"version": "0.28.0"'` is `1` in each.
- AC3.2 `CHANGELOG.md` gains a `## [0.28.0]` section with a `### Removed` entry
  naming `gh api`, stating that it is blocked for non-reviewer personas only in
  commands whose text spells the marker directory, and naming the documented
  workaround (`cat` to read a marker; `gh issue`/`gh pr` comments to discuss
  one). It must also record item 3's conclusion — that `rg`'s flag inventory is
  moot because #186 removed `rg` outright — so the audit result survives without
  a diff of its own.
- AC3.3 `README.md`'s "Known limitations" records the `gh pr checkout` residual
  from Context: a command that materialises a forged marker without its own text
  ever naming the marker directory is outside this gate's inspection scope by
  design, and de-allowlisting would not change that.
  `grep -c 'pr checkout' README.md` is `>= 1`.
- AC3.4 `bash tests/validate.sh` exits 0.

---

## Open Questions

1. **Disclosure for Step 2's public issue.** Step 2 fixes a live, currently
   exploitable fail-open in a security control, in a public repository. #184 and
   #186 both kept technical specifics out of the public tracker until the fix
   landed. **Recommended default: apply the same guardrail** — the per-step
   issue for Step 2 says only "narrow `gh`'s subcommand allowlist; technical
   detail and acceptance criteria in
   `docs/plans/2026-08-07-gate-audit-t34-vacuity-and-gh-inventory.md`", and the
   concrete `gh api` forms stay in this local document and in the test file until
   the fix is merged. Options: (a) redact per precedent [recommended];
   (b) publish in full, on the argument that the gate is self-described as
   advisory and the repo is single-maintainer; (c) hold Step 2 entirely until a
   human reviews the finding. This needs a human answer before `task-master`
   files anything.
2. **Should the `gh` allowlist go to leaf-subcommand granularity?** The current
   arm admits any verb under `issue`/`pr`/`search` — including `gh issue delete`
   and `gh pr merge` — because it only inspects the second word. None of them
   writes a caller-named path, so none is a gap for *this* gate, and the blast
   radius of leaf-level allowlisting is much larger. **Recommended default: no,
   out of scope for #185**; record it as an observation in Step 3's CHANGELOG
   entry rather than opening it here. Raised because a reviewer will notice the
   granularity while reading Step 2 and should find it already answered.

---

## Self-check

- CHK1: Is item 1's research question answered with a measurement rather than a
  citation of #182? — PASS (Context, three measurements, each with a
  reproduction; A5's exit-code cautionary note explicitly honoured)
- CHK2: Does the plan define exactly which bytes case 31 expects allowed vs
  blocked, or does it leave the implementer to derive them? — PASS (AC1.4 and
  the Clarifications line: 5 named bytes, 122 blocked, both counts asserted)
- CHK3: Do Step 1 and Step 2 agree about which case numbers they add? — PASS
  (31 and 32 respectively, both after the existing 30; no collision)
- CHK4: Is the converted assertion's ability to fail established, or asserted? —
  PASS (AC1.5's expected kill is measured on the mutant in Context (b), not
  predicted)
- CHK5: Does the plan say what the non-vacuity floor comment should read after
  the probe count changes? — FAIL (missing) — revised in place (AC1.3 now pins
  both the removed and the required string, and RD6 requires the committed
  figure match the printed one)
- CHK6: Is item 3's "no change" conclusion falsifiable, or just an assertion? —
  PASS (Context gives the two greps; AC3.2 requires it be recorded where a future
  auditor will meet it)
- CHK7: Does the plan resolve the apparent contradiction between case 31's
  allow-controls and case 26's stated "never asserts that a probe is allowed"? —
  FAIL (conflicting) — revised in place (Clarifications, Technical constraints;
  Step 1 requires the distinction be written into case 31's header)
- CHK8: P1 — is any Context claim unmeasured? — FAIL (ambiguous: "gh has no
  write flag" was an enumeration, not a verdict) — revised in place (the
  enumeration is now stated as point-in-time and pinned to gh 2.96.0, and
  Step 2's fix is explicitly shaped not to depend on it staying true)
- CHK9: Is it stated that no unit here is `haiku`-eligible, given the prior FAIL
  records on this file? — PASS (RD1 and "Prior-defect history", citing
  `177.fail` and `182.fail`, and disambiguating `205.fail`)
- CHK10: Does every step have at least one runnable command as its criterion? —
  PASS (AC1.1-1.7, AC2.1-2.6, AC3.1-3.4 are all greps, exit codes or counts)
- CHK11: Is the security finding's disclosure handling decided, or silently
  assumed? — FAIL (missing) — converted to Open Question 1
- CHK12: Does the plan avoid specifying work beyond #185's three items? — PASS
  (the `gh pr checkout` residual and the leaf-granularity question are both
  routed to a documentation line and Open Question 2 rather than to a step)

---

## Scribe update hint

After these units land: update `.claude/wiki/modules/hooks.md`'s
`reviewed-path-gate` section to describe **three** standing regression
techniques on this file, not two — case 26's differential byte sweep (now
T1/T2/T5 only), case 30's allowlist-removal block assertions, and case 31's
redirection-anchor block assertions — and record the reusable lesson in its
sharpest form: a differential template whose payload cannot *name* the protected
path under any gate behaviour is vacuous by construction, which is a stronger
statement than A5's "the reference implementation must produce an observable
effect" and closes the question A5 left open. Note that case 28 no longer exists
and that case 30 is the canonical block-direction shape, so the next reader of
#185 is not sent looking for it. Record that `gh api` joins `git` and `rg` as a
surface removed rather than inspected, and that the shared reason is the
denylist-fails-open ruling — that is now a three-instance pattern and deserves
naming.

**ADR:** no new ADR for Step 1 (it refines existing decisions about this file's
test technique). Step 2 extends the same ruling already recorded for `git`/`rg`;
if `scribe` judges a new ADR warranted, re-derive the next free number at
execution time rather than reusing any number quoted here — ADR-0015 is the
highest present today, and sibling specs in flight can collide.

---

## Publication

Per this repo's convention the canonical artifact is this document, and
`task-master` slices it into per-step issues labelled `ready-for-agent` +
`plan/2026-08-07-gate-audit-t34-vacuity-and-gh-inventory`. No umbrella PRD issue
is filed. **Open Question 1 must be answered before Step 2's issue is created.**
