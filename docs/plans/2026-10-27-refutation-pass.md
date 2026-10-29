# Refutation pass: challenge the reviewer's judgment defects before a FAIL verdict

Status: **revision 3, 2026-10-28** (spec-master): Gate G run 1 failed, and the brief is revised (see
"Revision 3"). Revision 2 (2026-10-27) applied the four user decisions and the critic's review. Follow-up
units rfp-u2b, rfp-u2c, rfp-u2d and rfp-u2e came after it. Amended 2026-10-28 with unit rfp-u2f, after the
user answered Open Questions 4 to 7.
- **Done:** rfp-u1, rfp-u2, rfp-u2b, rfp-u2c, rfp-u2d, rfp-u2e (2bf3ac51) and rfp-u1b (4ec89dae) have reviewer
  PASS markers. Gate G1 is done: all 41 labels are `real` (user, option A, 5f0c28de).
- **Gate G run 1:** G2 ran, and G3 printed `fail`. Only the turn rule failed. Its report is evidence only: an
  uncommitted, in-place mutant of `run.sh` produced it (rfp-u2e PASS note).
- **Next:** rfp-u2f, the replay tooling fixes for run 2 (Step 2f). Its contract is written. Then Gate G run 2.
- **Blocked:** rfp-u3 to rfp-u5 stay blocked until run 2's G3 prints `pass`.
- **Open Questions:** 4 to 7 are resolved, each to its recommended option (a). 1 keeps its applied default. 2
  and 3 are resolved. 8 is open, with a default (Step 6).
- **Step 6 (2026-10-29):** rfp-u1 to rfp-u5 have PASS markers and Gate G run 2 passed. Hardening units
  rfp-u6a, rfp-u6b (lead-programmer) and rfp-u6c (scribe) clear the open review notes; their contracts are
  written.
- **Step 7 (2026-10-29, spec-master at b9bcdf92):** rfp-u6a to rfp-u6c have PASS markers. Five file-disjoint
  units clear the review notes those PASSes left: rfp-u7b (the only version-stamped one), rfp-u7c, rfp-u7d and
  rfp-u7e may be built at the same time, and rfp-u7a (scribe) comes after rfp-u7b's PASS. Contracts rfp-u7b, rfp-u7c
  and rfp-u7d are written; rfp-u7a and rfp-u7e are specified in Step 7 and are written by the next spec-master
  spawn (checkpoint). Open Question 8 is resolved (rfp-u7d); 9 and 10 are open, each with a default.

## Units and order

Each unit is dispatched only after every unit in its "after" column has a reviewer PASS marker (Gate G: after
G3 printed `replay-gate: pass`). One unit is mid-review at a time.

| unit | owner | after | contract |
|---|---|---|---|
| rfp-u1 | lead-programmer | (none) | [rfp-u1](2026-10-27-refutation-pass/contracts/rfp-u1.md): the brief script |
| rfp-u2 | lead-programmer | rfp-u1 (its `run.sh` dry-run calls the brief script) | [rfp-u2](2026-10-27-refutation-pass/contracts/rfp-u2.md): the replay corpus and gate tooling |
| rfp-u2b | lead-programmer | rfp-u2 (it hardens rfp-u2's files) | [rfp-u2b](2026-10-27-refutation-pass/contracts/rfp-u2b.md): per-id gate scoring, the history-limited replay clone and the guard hook |
| rfp-u2c | lead-programmer | rfp-u2b (same directory; G1 needs the tool) | [rfp-u2c](2026-10-27-refutation-pass/contracts/rfp-u2c.md): the Gate G1 labeling server; retires `label-ui` |
| rfp-u2d | lead-programmer | rfp-u2c | no contract file (Open Question 3 (a)): `guard.py` refuses `-O` inside a bundle of short options. PASS at a6ecb429 |
| rfp-u2e | lead-programmer | rfp-u2d | no contract file: `run.sh` reads its groups on fd 3 and `claude` gets no stdin (2bf3ac51). PASS 2026-10-28 |
| Gate G run 1 | the human operator | rfp-u2e (committed) | none. G1 done (41 real). G3 printed `fail` on the turn rule only (Revision 3). Its report came from an in-place mutant of `run.sh`, so it is evidence only |
| rfp-u1b | lead-programmer | rfp-u2e's review has returned (one unit mid-review at a time); Open Questions 4 and 5 answered or their defaults accepted | [rfp-u1b](2026-10-27-refutation-pass/contracts/rfp-u1b.md): the brief's tool-call budget. PASS at 4ec89dae |
| rfp-u2f | lead-programmer | Open Questions 4 to 7 answered (done: all (a)). No file in common with rfp-u1b, so the two may go in either order; one unit mid-review at a time | [rfp-u2f](2026-10-27-refutation-pass/contracts/rfp-u2f.md): `run.sh` records the CLI `subtype`, `score.py` fails a capped run (`capped=`), the corpus keeps whole claims (`--refresh-claims`), and `run.sh` parses whole before running (Step 2f) |
| Gate G run 2 | the human operator (G2), anyone (G3) | rfp-u1b **and** rfp-u2f, both with PASS markers | none: G1's labels stand; G2 re-runs all 24 groups on the committed tooling, unchanged otherwise; G3 must print `pass` with `capped=0` |
| rfp-u3 | lead-programmer | rfp-u1b, rfp-u2, Gate G run 2 | [rfp-u3](2026-10-27-refutation-pass/contracts/rfp-u3.md): the reviewer pass and the FAIL-record format |
| rfp-u4 | lead-programmer | rfp-u3 (its edit 0 checks the protocol text) | [rfp-u4](2026-10-27-refutation-pass/contracts/rfp-u4.md): the task-master fix-contract bullet and the milestone-auditor sample |
| rfp-u5 | scribe | rfp-u3 and rfp-u4 (its criteria read both; `no-source` otherwise) | [rfp-u5](2026-10-27-refutation-pass/contracts/rfp-u5.md): glossary entries and ADR 0043. PASS at 57ec2d70 |
| rfp-u6a | lead-programmer | rfp-u5 (done). No file in common with rfp-u6b or rfp-u6c: any order, one unit mid-review at a time | [rfp-u6a](2026-10-27-refutation-pass/contracts/rfp-u6a.md): the reviewer's Verdict bullet names the `refutation:` line; the refutation sample's greps anchored at line start; `held` defined (Step 6) |
| rfp-u6b | lead-programmer | as rfp-u6a | [rfp-u6b](2026-10-27-refutation-pass/contracts/rfp-u6b.md): the label page's pointer rule counts from the click; `score.py` bad input exits 2; `guard.py` `-S`/`-G`/`-L` values; the multi-match refresh test (Step 6) |
| rfp-u6c | scribe | as rfp-u6a | [rfp-u6c](2026-10-27-refutation-pass/contracts/rfp-u6c.md): **mechanical ground** entry; **refutation outcome** mixed-FAIL clause; "refutation verifier" on the avoid list (Step 6) |
| rfp-u7b | lead-programmer | rfp-u6c (done). The only Step 7 unit with a version bump, a CHANGELOG entry or `--update`; may be built at the same time as rfp-u7c to rfp-u7e (no file in common) | [rfp-u7b](2026-10-27-refutation-pass/contracts/rfp-u7b.md): the Verdict bullet bounds the verdict block; an INSUFFICIENT-CONTEXT keeps its REFUTED defects in the `refutation` section; refutation-sample case (d) checks whole lines (Step 7 items 4 to 6) |
| rfp-u7c | lead-programmer | as rfp-u7b (concurrent) | [rfp-u7c](2026-10-27-refutation-pass/contracts/rfp-u7c.md): `score.py`'s docstring, and only parsing maps to bad input (Step 7 item 7) |
| rfp-u7d | lead-programmer | as rfp-u7b (concurrent) | [rfp-u7d](2026-10-27-refutation-pass/contracts/rfp-u7d.md): `label.py` refuses a broken `score.py` or a non-int `MIN_REAL` in one line (Step 7 item 8; Open Question 8) |
| rfp-u7e | lead-programmer | as rfp-u7b (concurrent) | contract pending (next spec-master spawn): `guard.py` refuses a `..` path segment after a `:` (Step 7 item 9) |
| rfp-u7a | scribe | rfp-u7b's PASS (its criteria read rfp-u7b's new reviewer sentence) | contract pending (next spec-master spawn): **FAIL ground** and **refutation sample** entries; the **refutation outcome** qualifier moved and its INSUFFICIENT-CONTEXT clause (Step 7 items 1 to 3) |

If Gate G3 prints `fail` or `insufficient`, rfp-u3 to rfp-u5 are not dispatched (Open Question 2). Run 1 did
exactly that.

Revision 1's `rfp-u2` (scribe) is withdrawn and renumbered rfp-u5. Nothing from revision 1 was dispatched.

## Revision 3: Gate G run 1 failed (2026-10-28)

Run 1's G3 printed `replay-gate: fail real=41 refuted-real=0 confirmed-real=27 uncertain-real=14 unanswered=0
bogus=0 refuted-bogus=0 max-turns=11 mean-cost-usd=0.070 missing=0 dup-conflict=0 foreign=0` and exited 1.
- Three thresholds hold: 41 ≥ 30 real, 0 ≤ 1 refuted-real, and 0 unanswered (the limit is 20%).
- Only "no run exceeded 10 turns" failed: `max-turns=11`.

The report is untracked at `eval/refutation-replay/report.jsonl`. The user keeps a copy at
`/tmp/claude-1000/-home-sebas-AntiSlop/05a6765a-da13-4deb-9a15-1128b5ee3d15/scratchpad/report-run1-gatefail.jsonl`.
Per Open Question 2 (a), rfp-u3 to rfp-u5 stay blocked, and the brief is revised (rfp-u1b). **No threshold is
changed or reinterpreted here.** Open Question 4 puts the turn rule to the user.

D1 to D8 stand. The evidence forces none of them to change. D4 (the cap of 3) was checked against the data
under diagnosis 2, and it stands.

### Diagnosis 1: what `num_turns` counts (verified, not guessed)

spec-master read the installed Claude Code 2.1.312 binary's bundled source. It ran no model.
- **The `--max-turns` cap counts loop iterations.** After an iteration's tools have run, the loop sets
  `gr=tn+1`. If `gr` is above the cap, the run stops with `subtype: "error_max_turns"` and `num_turns: gr`.
  That result carries `errors` and no `result` text.
- **A run that finishes reports `num_turns: Je`** (`subtype: "success"`). `Je` starts at 1 and adds 1 for each
  `user`-type message in the stream.
- **One user message per tool result.** Four local session transcripts hold 2,388 tool results. Each one sits
  alone in its own user message, including those after the 405 API turns that issued several tool calls at
  once.

So on a finished run, `num_turns` is 1 plus the run's tool calls, refused calls included. It is not the
number of turns, and calls batched in parallel each count.

The report shows the success path. Both 11-turn rows (esc-left-4@2026-10-04T04:23:11Z, D1 and D2) carry parsed
answers with artifacts. A cut-off run has no `result` text, so `run.sh:101` would have written `NONE` rows,
and run 1 has `unanswered=0`. **No run hit the cap.** esc-left-4 finished after 10 tool calls. A capped run
also reports `num_turns` 11, so `num_turns` alone cannot tell the two apart; only the answers can, or the
`subtype`, which `run.sh` does not record.

What this means for the plan:
- The Cost model's sentence "the replay records `num_turns` and fails the gate on any run that exceeds 10, so
  this estimate is checked before enabling" rests on a false premise.
- As written, the rule caps each run at 9 tool calls. It does not check the cap.
- A capped run would show only as `NONE` rows, which only the 20% unanswered rule sees.

That is Open Question 4.

*Correction (2026-10-28, rfp-u2f contract spawn).* The bullet above is wrong as written. A capped run's result
carries `num_turns` equal to the loop's turn count, 11 under `--max-turns 10`, and `run.sh` writes that value on
every one of its `NONE` rows. So the turn rule as written fails a capped run too (`max-turns=11`). What no rule
could do was tell a cap hit from a finished run of 10 tool calls: both read 11. rfp-u2f records `subtype`, so
`capped=` names the cause. It also keeps the check if the cap or `MAX_TURNS` ever changes. The user's answer
(Open Question 4 (a)) stands either way.

| defects per group | runs | tool calls per run (min to max, mean) | tool calls per defect (mean) |
|---|---|---|---|
| 1 | 13 | 3 to 7, 4.5 | 4.5 |
| 2 | 5 | 4 to 10, 7.0 | 3.5 |
| 3 | 6 | 4 to 9, 6.5 | 2.2 |

The runs at or near the line:
- esc-left-4: 2 defects, 10 calls. It cites `docs/harness-glossary.md`, 2,892 lines at the reviewed commit,
  and ADR 0039.
- abt-u21a: 2 defects, 9 calls.
- gh288-1: 3 defects, 9 calls.
- gh348-14: 3 defects, 8 calls.

Three things drive the count:
- The brief asks for three kinds of call per defect: the whole file, its callers and the baseline.
- On defects in docs, the model added cross-reference reads of other docs, ADRs and plans.
- A long file costs one Read per page.

Group size is not the driver: calls per defect fall as groups grow. Total cost was $1.571 for 24 runs, or
$0.065 per run. score.py's `mean-cost-usd=0.070` is per defect row, so a 3-defect group counts three times.

### Diagnosis 2: what the brief can change without weakening refutation

Adopted in rfp-u1b (Step 1b):
- **A stated budget:** at most 9 tool calls in all, and `9 / n` per defect (9, 4 or 3). Every call counts,
  refused and parallel calls included. 9 is what the rule as written allows (`num_turns` ≤ 10).
- **UNCERTAIN once a defect's share is spent,** naming the open question. Running out never yields REFUTED,
  so the costly direction is not touched.
- **The large-file rule** (Open Question 5, default applied). When a whole file would go over the share, the
  explorer reads the cited region plus the places grep finds for the cited code, and says so.
- **No line break inside an answer.** rnc-1's artifact stops at "Two things stop me confirming:", because the
  rest of the answer went on the next line, which `run.sh` does not parse.
- **The exact cap stays stated** ("at most 10 turns"). The brief already said it, so a missing cap statement
  was not the cause.

Rejected:
- **A "q1=no, so REFUTED" short-circuit.** Cited lines drift between commits. Run 1's abt-u10 artifact found
  the defect at :71, not the cited :36. The short-circuit would push answers toward REFUTED, the costly
  direction.
- **A lower defect cap (re-opening D4).** The 10-call group had 2 defects, and calls per defect are highest in
  1-defect groups, so a cap of 2 would not have kept esc-left-4 under the line.
- **Re-ordering the three questions.** The order already goes cited file (q1), baseline (q2), mitigation
  (q3). The budget is what binds.

The effect on refutation quality: the budget can only cut exploration, and a cut ends in UNCERTAIN, which
keeps the defect in a FAIL (D1). So it cannot raise `refuted-real`, and run 2 measures that again. It can
lower `r` (a refutation that needs a fifth call in a 2-defect group goes unfound). This corpus is all real,
so the replay cannot measure that loss (R12).

### Diagnosis 3: the UNCERTAIN rate (14 of 41, 34%)

spec-master read every UNCERTAIN artifact:

| cause, as the artifact states it | rows |
|---|---|
| the claim text is cut off in the brief | 7: gh-303, abt-u10, rp-u5, rgh-u0-2 D2, abt-u13g, gh-eval-step1, rgh-u0-2b |
| it needed to run code, and the replay's Bash allows only `git show`, `git diff` and `git log` | 2: abt-u12 D1 and D2 (abt-u10 and gh-eval-step1 also say so) |
| it needed data that is not in the history-limited clone (untracked results, real transcripts) | 2: gh288-1 D1 and D2 (abt-u13g also says so) |
| the answer broke across lines (diagnosis 2) | 1: rnc-1 |
| a judgment call: an ambiguous spec, a partial mitigation | 2: gh315 D2 and D3 |

So 12 of the 14 have their cause in the replay or the answer format, not in the defect.

- **Clipped claims.** `build-corpus.py` keeps only the first physical line of a wrapped defect bullet
  (`:63`), and it cuts the claim at 300 characters (`:88`). 37 of the 41 claims end mid-sentence: 31 at the
  300-character cut, and 6 short ones that lost the continuation lines of a wrapped bullet. Several of the
  dropped tails are the defect's own `Repro:` text. That is Open Question 6.
- **"No repro" is structural in the replay.** rfp-u2b limits Bash to three git verbs so that answers cannot
  leak. So a model that follows "when unsure, answer UNCERTAIN" correctly answers UNCERTAIN on a runtime
  claim. The brief already allows a quoted file:line as the artifact, and the 27 CONFIRMED answers used one.
  No brief change is proposed here. The live explorer has full claims, its own Bash and the whole working
  tree, so its UNCERTAIN rate should be lower, but nothing has measured it.
- **Gate effect: none.** UNCERTAIN counts as answered and is not a gate criterion.
- **Live effect** (D1, D7, the verdict table under "Per-defect protocol"):
  - 7 of the 24 runs (29%) would end UNCERTAIN-only, so INSUFFICIENT-CONTEXT and a round trip, though every
    one of their defects is real. Each of the 7 has a cause in the table above.
  - 4 runs (17%) would FAIL with at least one `[unconfirmed]` defect.
  - 13 runs would FAIL clean.
  - None would PASS.
  - The Cost model gains these numbers ("Measured in Gate G run 1"), and the kill rule goes to Open Question
    7.

### Carried open items (recorded so they are not lost; not fixed in this revision)

- **(a) rfp-u2e is not reviewed yet** (2bf3ac51). The real run printed one stray stderr line,
  `run.sh: line 116: <group data>: File name too long`, at the `done 3<<< "$groups"` line, although all 24
  groups ran. In the committed file, `done 3<<< "$groups"` is line 115 and the summary `echo` is line 116, so
  the reviewer should find which line raised it. The dispatcher hands this to rfp-u2e's reviewer. rfp-u1b
  waits for that review.
  - *Closed 2026-10-28:* rfp-u2e PASS. Its reviewer found the cause. The human's run started before 2bf3ac51
    was committed, while a lead's in-place mutant of `run.sh` (` < /dev/null` removed) was on disk. The lead
    restored the file in place during the run, and after the loop bash read the next command at the old
    offset (`< "$groups"`). So run 1's report came from that mutant, not from 2bf3ac51: it is evidence, not a
    gate record. rfp-u2f wraps `run.sh` in `main` so this cannot recur, and gives case (q) the test it lacked.
- **(b) rfp-u2c's PASS notes stay advisory.**
  - B12 covers the stationary re-click only for the first write on a page: two `label_page.html` mutants stay
    green from the second write on.
  - The wheel re-arm has no test.
  - A pointer move made while a POST is in flight is not counted.
  - A `score.py` that lacks `MIN_REAL`, or has a syntax error, makes `label.py` exit 1 with a traceback, not
    2 with one line.

  No unit is planned for them. G1 is done, so they do not touch run 2.
- **rfp-u2d's note "no live PreToolUse invocation was exercised" is closed by run 1.**
  - abt-u15b's artifact says "the replay guard blocked running Python".
  - abt-u10's says "the replay guard blocks shell operators".
  - `run.sh`'s exit-3 tripwire did not fire.

  abt-u13g's artifact says that the guard blocked a baseline `git show`. The guard log is deleted with the
  scratch directory, so run 1 cannot show which command it was. A refused call still counts against the
  budget.

## Goal

A FAIL defect the reviewer found by reading code (a **judgment defect**) reaches the lead-programmer only
after a fresh-context `explorer` subagent on `sonnet` has tried to disprove it against the real code: the
whole file, its callers and the baseline. The reviewer then re-checks each artifact itself and says, in its
own words, why the artifact proves or defeats the claim.

- If every defect is refuted, the unit passes and no FAIL block is written, so no Escalation-ladder attempt
  is used up.
- A defect left UNCERTAIN in a FAIL that happens anyway stays in the defect list, tagged `[unconfirmed]`.
- Every FAIL block ends with a `refutation:` telemetry line.
- The pass is enabled only after an offline replay of past real defects shows that it almost never refutes
  a real one (Gate G). After that, the milestone auditor samples live refutations.
- Mechanical FAIL grounds are never re-checked. The pass writes no marker. The one-unit-one-review
  invariant, the route gate, the stop gate and the ladder arithmetic are unchanged.

## Resolved decisions (revision 2)

| # | Decision | Source |
|---|---|---|
| D1 | Mixed FAIL: UNCERTAIN defects stay in the FAIL defect list, prefixed `[unconfirmed]`. A fix reproduces an `[unconfirmed]` defect before changing code, and reports one that does not reproduce instead of fixing it. | user, option (c) |
| D2 | The explorer spawn carries `model: sonnet` | user |
| D3 | FAIL-side telemetry now. The last line of every FAIL block is `refutation: confirmed=<a> refuted=<b> uncertain=<c>`, or `refutation: skipped=<mechanical\|over-cap\|resume\|no-subagent>` | user. The skipped grammar is spec-master's |
| D4 | Defect cap is 3, not 5 | critic. The turn budget cannot be passed per spawn (see Cost model) |
| D5 | Replay-corpus gate before enabling (Gate G), plus a milestone-auditor sample of `refuted:` notes | critic BLOCKER. The design is spec-master's |
| D6 | The reviewer states why each artifact defeats or proves the claim. It may keep a defect standing with a reason. For a mitigation, the re-check confirms that the guard stops the defect on the defect's own path. Revision 1's sentence that the reviewer "may not argue away a refutation" is deleted. | critic MAJOR |
| D7 | On the INSUFFICIENT-CONTEXT resume: FAIL a defect the reviewer now reproduces itself. A defect it cannot reproduce becomes a `NOTE[code]: unconfirmed:` line. | critic MAJOR |
| D8 | The explorer brief is a shipped script (`bin/refutation-brief.sh`). Both the reviewer and the replay use it, so the replay tests exactly the brief that ships. This also shrinks the reviewer bullet. | spec-master, from D5 |

## Context

### Where things live (verified at 1073743d)

- **Reviewer rules.**
  - `agents/reviewer.md`: "Verdict" :127-143 ("PASS only when … found no refutation" :137-138; the
    advisory-section order :140-143), "On FAIL" :241-256, "On INSUFFICIENT-CONTEXT" :257-269.
  - `.claude/agents/reviewer.md` is generated by `node bin/cli.js --update`.
- **FAIL-record format.** The canonical text is `templates/persona-protocol.md` "FAIL record" :343-356. It
  is inlined by cli.js into the orchestrator, lead-programmer, reviewer, spec-master and task-master
  mirrors (`bin/cli.js:803-894`), so task-master and the lead-programmer learn the `[unconfirmed]` rule
  from the same section.
- **Hand-synced ports that carry the format.** These are exactly the four files
  `tests/adapter-fail-tier-pin.test.js:12-17` pins:
  - `adapters/codex/agents/reviewer.toml:93`
  - `adapters/codex/agents-md-fragment.md:126`
  - `adapters/cursor/agents/reviewer.md:90`
  - `adapters/cursor/rules/persona-protocol.mdc:132`

  The ports have no verified way to spawn a subagent, so they write `refutation: skipped=no-subagent`.
- **Other writers.** `hooks/scripts/marker-write.sh` writes `<detail>` verbatim after the header, so the
  telemetry line passes through it unchanged. Its fixtures in `tests/fail-marker-format-parity.test.sh` are
  hard-coded and stay valid.
- **Glossary.** `CONTEXT.md` "FAIL block" :1077 spells the block format (rfp-u5 updates it).
  `docs/harness-glossary.md` lists neither the format nor the advisory order. rfp-u5 adds a
  "refutation line" entry there, because that file holds harness-mechanics terms.

### FAIL-record readers: why the new line is safe (verified)

| reader | what it reads | effect of a last-line `refutation:` and `[unconfirmed]` prefix |
|---|---|---|
| `bin/fail-count.sh`, `bin/ladder-tier.sh` (n), `bin/ladder-tier.sh --census` | `^FAIL <id> ` header count | none |
| `bin/escalation-card.sh:25-29` | header, `tier:`, then the **first** non-empty line | none while `refutation:` is the **last** line (rfp-u3 fixture test case b; the mutation moves it first and the test fails) |
| `hooks/scripts/reviewer-tier.sh`, `bin/unit-size.sh:107` | whether the record exists | none |
| `scripts/unit-outcomes.js:11-19,136-139` | substring classes over the block text | none if the line's words avoid every class substring. `refutation`, `confirmed`, `refuted`, `uncertain`, `skipped`, `mechanical`, `over-cap`, `resume`, `no-subagent` and `[unconfirmed]` match none (rfp-u3 fixture test case c reads the live `CLASSES` table) |
| task-master fix contract (`agents/task-master.md:98-107`) | the latest block, verbatim | it must not treat `refutation:` as a defect, and must reproduce `[unconfirmed]` defects first: the protocol section (rfp-u3) plus a task-master bullet (rfp-u4) |
| the reviewer fix-round scope rule (`agents/reviewer.md:62-63`) | paths named in a defect | `[unconfirmed]` defects keep their paths, and the telemetry line has none |

### Gate interaction (verified by running the gates' tests)

- **Route gate.** A reviewer may spawn `explorer` and no review-join stamp is written
  (`hooks/scripts/lib/reviewer-route-gate-core.sh:78`, scoped to `reviewer` targets). spec-master ran the
  new case in a scratch copy, and its mutation made it fail. A reviewer may not spawn a `reviewer`
  (`tests/reviewer-route-gate-caller.test.sh:66`).
- **Markers.** `hooks/scripts/reviewed-path-gate.sh:249` grants reviewer identities only, and `explorer`
  has no Write/Edit tool.
- **Stop gate.** The explorer's `SubagentStop` adds one `grant-denied … identity=explorer` audit line while
  the reviewer's flag stands, as every reviewer-to-explorer spawn already does (R4).
- **State after a refutation.** A PASS reached through a refutation writes exactly the state of any other
  PASS: the same v3 `.pass` first line, the same review-join stamp consumption and the same bounded flag
  clearing. Only its notes differ. A prevented FAIL writes no `.fail` block. An UNCERTAIN-only outcome
  writes `.blocked`, as any INSUFFICIENT-CONTEXT does. No new state file exists.
- **Reviewer-run commands.** When the reviewer reproduces a defect itself with a command, that defect
  becomes mechanical and the pass is skipped for it. This is intended: the defect already has its artifact.

### ADR draft (rfp-u5 numbers and lands it)

> **ADR-draft: the refutation pass runs inside the reviewer's turn, and is enabled only behind a replay
> gate.**
>
> *Context.* A hallucinated or already-mitigated FAIL defect uses up an Escalation-ladder attempt, because
> `n` is the FAIL-block count.
>
> *Decision.* Before returning FAIL, the reviewer spawns one foreground, unnamed `explorer` on `sonnet`. Its
> prompt comes from `bin/refutation-brief.sh` and asks it to disprove each of at most 3 judgment defects.
> The reviewer re-checks each artifact, states its own reason, and may keep a defect standing. Only defects
> that survive reach the FAIL record, which now ends with a `refutation:` telemetry line. The reviewer
> instructions ship only after a replay of past real defects passes a recall threshold.
>
> *Alternatives rejected.*
> - (C) An orchestrator-dispatched refuter after the FAIL. `n` has already gone up, so undoing it needs a
>   new marker or a `ladder-tier.sh` change, plus fix-contract filtering and a second route-gate shape.
> - A nested `Mode: advisory` reviewer. The caller allowlist refuses it.
> - A new `refuter` persona. It costs a persona file, ports, personaSelection and cli.js lists, and buys
>   nothing over `explorer`.
>
> *Consequences.* No hook, marker, ladder or orchestrator change. The FAIL-record format gains a last line.
> The pass's verdict is evidence; the verdict stays the reviewer's.
>
> The three ADR tests: hard to reverse (moving to (C) needs state machinery, and the telemetry format would
> be in consumer records), surprising (a "second gate" is not a second dispatch), and a real trade-off.

### Per-defect protocol

The reviewer pipes one `D<n>: <file:line> <claim>` line per deduplicated judgment defect (1 to 3) into
`bash .claude/bin/refutation-brief.sh <baseline>`. The script refuses 0, more than 3, malformed or
duplicated lines, and a bad baseline. It prints a fixed brief: the baseline, the changed files, the three
questions, the answer grammar `D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=… q2=… q3=… — artifact: …`, and the
rules: when unsure, answer UNCERTAIN, never CONFIRMED; a verdict with no artifact is UNCERTAIN; a
mitigation's artifact is the guard itself plus why it stops this defect on this path.

The reviewer spawns `explorer` once with that brief as the prompt.

| explorer answer, after the reviewer's own re-check | result |
|---|---|
| REFUTED, and the reviewer confirms the artifact defeats the claim (for a guard: it stops the defect on the defect's path) and states why | dropped. PASS: `NOTE[code]: refuted: D<n> <claim> — <artifact> — <why>`. FAIL: the `refutation` advisory section |
| REFUTED, but the reviewer finds a reason the artifact does not defeat it | **stands**. The reason goes in the `refutation` section |
| REFUTED as already at the baseline (`git show <baseline>:<file>`), not an unmet criterion | dropped as REFUTED |
| CONFIRMED with an artifact that reproduces | stays a defect |
| UNCERTAIN, or an answer with no artifact | `[unconfirmed]` in a FAIL that happens anyway; see the table below |
| artifact does not reproduce, no answer line, or the explorer was truncated | **stands as found** (today's behaviour) |

| standing or CONFIRMED | UNCERTAIN | verdict | FAIL block's last line |
|---|---|---|---|
| ≥1 | any | FAIL: the standing and CONFIRMED defects, plus each UNCERTAIN one prefixed `[unconfirmed]` | `refutation: confirmed=<a> refuted=<b> uncertain=<c>` (`a` counts standing and CONFIRMED) |
| 0 | ≥1 | INSUFFICIENT-CONTEXT, `missing:` naming the evidence. On the resume there is no second pass: a defect the reviewer now reproduces is a FAIL (`refutation: confirmed=…`), and one it cannot reproduce is `NOTE[code]: unconfirmed:` | none, unless the resume FAILs |
| 0 | 0 | the PASS rules, escalation included | none (no FAIL) |
| pass skipped | – | as today | `refutation: skipped=<mechanical\|over-cap\|resume\|no-subagent>` |

**Why UNCERTAIN-only maps to INSUFFICIENT-CONTEXT and not ESCALATE-TO-HUMAN.** ESCALATE-TO-HUMAN gates a
would-be PASS only (`agents/reviewer.md:272`), and it spends a human. INSUFFICIENT-CONTEXT uses no cap slot,
keeps the review blocking, and already has the fetch-and-resume path (`agents/orchestrator.md:276-292`).

**The "PASS is one line" rule** (`agents/reviewer.md:127-131`) governs the verdict line. The `refuted:`
notes go into the marker's non-blocking notes, written by Bash, as every note does. The `refutation`
section is a third advisory section after the verdict, in the order roast-work, ubiquitous-language,
refutation, so the verdict stays the first thing read.

**The word collision** at :137-138 ("found no refutation", meaning a refutation of the *change*) is removed
by rewording it to "found no defect that survived the refutation pass". The glossary (rfp-u5) records that
"Refute, don't rubber-stamp" (:46) still means attacking the change.

### Safety: what can go wrong in each direction, and how each is caught

- **Wrongly confirmed** (the risk the research names): a needless fix, recovered cheaply. This is unchanged
  from today.
- **Wrongly refuted, and the unit passes.** The reviewer's PASS is the terminal gate, so this is the costly
  direction. The critic is right that the `refuted:` count only counts wins. Three layers catch it:
  1. **Before enabling: Gate G (replay).** rfp-u2 builds a seeded corpus of 41 past judgment defects in 24
     groups, drawn from 57 candidates whose unit was later fixed and passed. The proxy label "real" means a `(<unit>)` commit after the FAIL touched the
     cited file and the unit later holds a `.pass`. A human confirms each label (`labels.tsv`) and runs the
     replay: `bin/refutation-brief.sh` at the reviewed commit, headless `claude -p --model sonnet
     --max-turns 10` with read-only tools. `score.py --gate` passes only if:
     - at least 30 confirmed-real defects were replayed;
     - at most 1 of them was answered REFUTED with an artifact;
     - at most 20% of defects got no answer line;
     - no run exceeded 10 turns.

     rfp-u3 carries `score.py --gate` on the committed report as an acceptance criterion, so the reviewer
     instructions cannot reach PASS without a passing replay.

     *Statistical honesty:* 1 miss in 30 bounds the true raw miss rate at about 17% (95% upper, exact
     binomial). 0 in 30 bounds it at about 10%. The replay measures the explorer stage alone. The
     reviewer's own re-check (D6) is a second filter that is not measured, so the live miss rate is at most
     the measured one. Open Question 1 offers a larger corpus.
  2. **After enabling: milestone-auditor sample (rfp-u4).** At each milestone boundary, the auditor
     re-verifies up to 3 `NOTE[code]: refuted:` lines from that milestone's `.pass` markers. A refutation
     that does not hold is a finding, which goes to the human decision the auditor already ends in.
  3. **Downstream:** a later review, unit or audit that hits the defect again. This is unchanged.
- **What is not testable mechanically.** The live reviewer's judgment, and whether a given live refutation
  was right, can only be sampled (layer 2). The prose pins in rfp-u3 prove the instruction text shipped,
  not that it is followed. The behaviour-bearing checks are:
  - the route-gate case (the nested spawn is admitted, with no stamp);
  - the brief script's fixture test (caps, grammar, determinism);
  - the FAIL-record fixture test (the readers are unaffected);
  - the replay gate (the explorer stage on real past defects);
  - the scorer and builder fixture tests.

### Cost model (with base rates from this repo's own records)

**Base rate.** spec-master classified all 193 FAIL blocks in the 174 `.fail` records (a keyword classifier
over each block's defect lines; the script and its output are reproducible by `eval/refutation-replay/`'s
builder):

| class | blocks | share |
|---|---|---|
| any mechanical ground (precheck lines, version-stamp, uncommitted, scope, a criterion's exit or stdout) | 143 | 74% |
| judgment only, 1-3 defects (**eligible at cap 3**) | 37 | 19% |
| judgment only, 4-5 defects | 7 | 4% |
| judgment only, more than 5 | 6 | 3% |

The classifier over-counts "mechanical": defect prose that merely mentions an exit code matches it. So 19%
of FAILs is a floor. With 708 PASS markers, reviews number about 901, so **eligible runs are about 4% of all
reviews** (37 over the project's history to date). The 4-5 band adds only 7 blocks, which is part of why the
cap moves to 3 (D4).

**Turn budget.** The `Agent` tool has no per-spawn turn parameter (its schema is description, prompt,
subagent_type, model, isolation, effort and run_in_background). The explorer's frontmatter `maxTurns: 10`
therefore binds, and `sonnet` does not raise it. Each defect needs about 2 to 3 tool rounds (the whole file
and its callers in parallel, then the baseline), so 3 defects take about 7 to 9 rounds including the
answer. 5 did not fit. The replay records `num_turns` and fails the gate on any run that exceeds 10, so this
estimate is checked before enabling. *(Revision 3 correction: on a finished run, `num_turns` is 1 plus the
run's tool calls, not its turns, so the gate checks a 9-call limit and not the cap. See Revision 3, diagnosis
1, and Open Question 4. The sentence stays as the rule's original intent; its threshold is unchanged.)*

**Per run (eligible FAIL only).** One sonnet `explorer` with up to 10 turns and a brief under 2 KB. Plus
reviewer overhead: one script call, one spawn turn, and one re-check per defect, run in parallel; about 3 to
6 reviewer turns out of 50. Latency is one subagent round-trip on the FAIL path. The replay reports the
measured mean `total_cost_usd` and turns, which replace these estimates.

**UNCERTAIN-only round trip.** One orchestrator turn, one explorer or scribe fetch dispatch, and the resumed
reviewer's turns. It is bounded to once per review, because the resume runs no second pass. It is still
cheaper than a fix round, which contains a full review.

**Standing cost.** The bullet in `agents/reviewer.md` is about 35 lines, roughly 450 tokens per reviewer
dispatch, cached by `cacheTtl: 1h`. The brief text lives in the script, not the persona.

**Break-even** (estimates; the replay measures `Cp`):
- `Cp` = per-run cost, about 50k sonnet tokens.
- `Cf` = cost of the fix round a refutation saves: task-master, an implementer attempt and a full sonnet or
  opus review, about 400k tokens.
- `E` = eligible fraction of reviews, about 4%.
- `r` = fraction of eligible FAILs the pass prevents.
- `Cs` = standing cost per review, about 450 tokens.

The pass pays off when `E·r·Cf > Cs + E·Cp`. With these figures that is `r > ~15%`. The **standing cost
alone is not worth carrying if `E < Cs / (r·Cf − Cp)`**. At `r = 20%` that threshold is about 1.5% of
reviews, against an observed floor of about 4%.

**Kill or re-scope criterion** (made computable by D3): after 20 eligible runs, `r` = prevented FAILs over
eligible runs. Prevented FAILs are `.pass` markers carrying `NOTE[code]: refuted:`. Eligible runs are those
plus FAIL blocks whose last line starts `refutation: confirmed=`. If `r < 10%`, open a follow-up to retire or
re-scope the pass. rfp-u4's milestone-auditor bullet prints this ratio as part of its sample.

**Measured in Gate G run 1 (2026-10-28, revision 3).** The economics need updating, and this paragraph does it.
- `Cp`: $1.571 for 24 sonnet runs, so **$0.065 per run**. The runs averaged 5.5 tool calls (3 to 10). The
  50k-token figure stays an estimate, because the report records dollars and not tokens.
- `r` cannot be measured by this replay. All 41 defects are real, so no FAIL could rightly be prevented.
- The break-even above leaves out the UNCERTAIN-only round trip. Let:
  - `u` = the fraction of eligible runs that end UNCERTAIN-only. Run 1 measured 7 of 24, or 29%.
  - `Ci` = the cost of that round trip: one orchestrator turn, one fetch dispatch and a resumed reviewer. This
    is an estimate of about 130k tokens.

  The pass pays off when `E·r·Cf > Cs + E·(Cp + u·Ci)`. With the other figures unchanged:
  - `u = 0` gives `r > ~15%`, as before;
  - `u = 10%` gives `r > ~19%`;
  - `u = 29%` (run 1) gives `r > ~25%`.
- Run 1's `u` is an upper estimate: all 7 UNCERTAIN-only runs had a replay or answer-format cause (Revision 3,
  diagnosis 3).
- The kill rule above counts only `r`, and it does not see round trips. Whether to add a `u` trigger is Open
  Question 7. The user chose (a): it is decided after run 2, and until then the kill rule stands as written.

**Deliberately not skipped:**
- A single defect: one refutation turns FAIL into PASS, the highest-value case.
- Opus-tier units: the most expensive fix rounds, closest to ladder exhaustion.
- `reviewGating.mode: off`: in-session advisory FAILs still drive the ladder count and fix rounds. With no
  record, the `refutation:` line goes in the verdict text.

### Prior FAIL history and audit sweep (dispositions)

- 21 of the 174 `.fail` records name `agents/reviewer.md`, and 27 cite version-stamp/P3 defects. Every unit
  that touches `agents/` or `templates/` bumps the version and adds its CHANGELOG entry **in each commit**
  (criterion `version-stamp-check.sh` over the unit's range). This includes fix rounds.
- `bin/marker-audit.sh --notes`: blf-6 `NOTE[spec]` says to write "FAIL-block count", never "FAIL count"
  (honoured). Untagged 124 is unaffected. The others are historical.
- No re-scoped unit has a prior `.fail`.
- rfp-u2b (2026-10-27):
  - rfp-u1 and rfp-u2 hold PASS markers and no `.fail`.
  - Every non-blocking note in `rfp-u2.pass` has a disposition in the Step 2b table, including the
    dry-run `worktree prune`.
  - `marker-audit.sh --notes` finds no note on `eval/refutation-replay`.
  - On `tests/validate.sh` the sweep finds only historical notes. The relevant two are vsp-1 (the lane
    runner) and vtmp-1 (the 600 s cap); criterion 9 handles both with `ANTISLOP_VALIDATE_LANES=4` and the
    600000 ms timeout.
  - The sweep is best-effort: `.claude/reviewed/` is per-clone.
- rfp-u2c (2026-10-28):
  - **`label-ui` is superseded by rfp-u2c.** label-ui was an unplanned labeling-page unit (commits a541f157,
    476297ad, ae614188). Its `.fail` record holds 3 blocks (tiers sonnet, sonnet, opus). All three are one
    defect class: a write path other than a mouse click on a visible button. It is a keyboard shortcut on a
    hidden card, a re-snap to an off-screen card, or a focused button re-fired by Space or Enter, plus
    scroll-before-refresh. A 4th attempt was cancelled with uncommitted edits to both files. Its ladder is
    spent and it is not re-dispatched. Its commits stay in history, and rfp-u2c deletes the files (contract
    edit 6) after porting the WIP's `D\d+` and rename-aware numstat fixes (edit 0).
  - Because of that history, rfp-u2c is tagged for **opus** and the full lane. Its design removes every
    non-click write path instead of guarding it, and its real-browser probe checks the invariant after every
    step.
  - `rfp-u2b.pass` notes: the `guard.py` `-O` bundling `NOTE[spec]` is not rfp-u2c's scope; it becomes Open
    Question 3, before G2. The "`unknown` ids count in the unanswered denominator" `NOTE[spec]` is moot once G1
    holds, because G1 requires `unlabeled=0`. A line under Gate G now says so. The two `NOTE[code]` items stay
    advisory.
  - `marker-audit.sh --notes` on `eval/refutation-replay`, `tests/validate.sh` and
    `tests/refutation-label-ui.test.sh` adds nothing beyond the notes above (see the Self-check). The sweep is
    best-effort.
- rfp-u1b (2026-10-28):
  - No `.fail` record names rfp-u1 or rfp-u1b. rfp-u1 passed first time, so nothing forces a higher tier.
    The task tagging is task-master's, or the orchestrator's on the fast path.
  - `marker-audit.sh --notes` on `bin/refutation-brief.sh` and `tests/refutation-brief.test.sh` returns
    three rfp-u1 `NOTE[code]` lines.
    - The empty-stdout asserts are closed by rfp-u1b edits 4 to 8.
    - The trailing CR is closed by edit 11 and case (m).
    - D10 to D99 reading `malformed` is kept as designed.
  - The same sweep on `eval/refutation-replay` returns one rfp-u2c `NOTE[code]` (`__pycache__`). rfp-u1b
    never imports `label.py`, so it does not apply.
  - The rfp-u2c and rfp-u2d notes the task names are dispositioned under Revision 3, "Carried open items".
  - The sweep is best-effort: the markers directory is per-clone.
- rfp-u2f (2026-10-28):
  - The plan's review records are PASS markers for rfp-u1, rfp-u1b, rfp-u2, rfp-u2b, rfp-u2c, rfp-u2d and
    rfp-u2e, plus `rfp-u2c.fail` (dispositioned above). No `.fail` names rfp-u2, rfp-u2b or rfp-u2e, the
    units whose files rfp-u2f edits, so nothing forces a higher tier.
  - `marker-audit.sh --notes` on `eval/refutation-replay` returns three `NOTE[code]` lines:
    - rfp-u2c's `__pycache__` note. The contract says not to import an `eval/` module in place, and criterion
      12 fails on a stray cache.
    - rfp-u2e's label-suite snapshot note: a report written during that suite turns it red. It is recorded
      in the contract's context, and no change is needed.
    - rfp-u2e's process note, with the optional `main` wrapper. The wrapper is folded in (edits 30 and 37,
      case t), and the process half is now a hard rule in the contract's Escalation.
  - On the two replay suites the sweep returns nothing.
  - `rfp-u2e.pass` has two notes the sweep did not tag to these paths:
    - The `< /dev/null` half has no failing test. Folded in: case (q) gets a sentinel stdin.
    - Children inherit fd 3. Folded in as `3<&-` and case (u): one token plus one assertion in files this
      unit already edits.
  - `rfp-u1b.pass` notes 2 and 3 (a 2-defect share of 4, and a 3-call floor per defect against a share of 3)
    are for reading run 2's results. They need no rfp-u2f change (Gate G, "Run 2").
  - The rfp-u2c advisory notes (Revision 3, carried item b) are not folded in: they touch only the label
    server, which G1 no longer needs. Out of scope 10.
  - The sweep is best-effort: the markers directory is per-clone.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-27 Functional scope & success criteria: Q Are the orphan check and the Integrity rubric in
  scope? → A (self-resolved): no, both are named follow-ups.
- 2026-10-27 Domain entities / data model: Q Which defects are refutable, and what are the per-defect
  states? → A (self-resolved): only judgment defects. The states are REFUTED, CONFIRMED and UNCERTAIN,
  with an artifact required for the first two. A missing, malformed or non-reproducing answer means the
  defect "stands as found".
- 2026-10-27 User interaction flow: Q Who dispatches the refuter? → A (self-resolved): the reviewer, as a
  nested foreground unnamed `explorer`. The orchestrator flow is unchanged.
- 2026-10-27 Edge cases / failure handling: Q Where do UNCERTAIN defects go in a mixed FAIL? → A: they stay
  in the FAIL list, prefixed `[unconfirmed]` (option c, per user, 2026-10-27).
- 2026-10-27 Non-functional attributes (perf, security, scale): Q On what model does the explorer run? →
  A: `sonnet` (per user, 2026-10-27).
- 2026-10-27 Completion / acceptance signals: Q Is FAIL-side telemetry added now? → A: yes. Every FAIL
  block ends with a `refutation:` line (per user, 2026-10-27).
- 2026-10-27 Completion / acceptance signals: Q How is the safety of a refutation measured? → A
  (self-resolved, from the critic's BLOCKER): Gate G replay with a recall threshold, plus the
  milestone-auditor sample.
- 2026-10-27 External dependencies & integrations: Q Can the replay run without an LLM? → A
  (self-resolved): no. It is headless `claude -p` at the human's cost. The builder, scorer and dry-run are
  deterministic and tested.
- 2026-10-27 Technical constraints & tradeoffs: Q Is 5 defects within the explorer's 10 turns, and can a
  per-spawn budget be passed? → A (self-resolved): no per-spawn parameter exists. The cap is 3, and the
  replay enforces the turn limit.
- 2026-10-27 Edge cases / failure handling: Q What happens on the INSUFFICIENT-CONTEXT resume? → A
  (self-resolved, critic): FAIL a defect the reviewer reproduces itself; a non-reproduced one becomes a
  `NOTE[code]: unconfirmed:` line.
- 2026-10-27 Terminology consistency: Q Does "refutation" collide with existing reviewer prose? → A
  (self-resolved): yes, at :46 and :137-138. :138 is reworded, :46 is kept and acknowledged in the
  glossary, and `refuter` stays avoided.
- 2026-10-27 Terminology consistency: Q How does a fix round name an `[unconfirmed]` defect that does not
  reproduce, when the FAIL block numbers no defect? → A (self-resolved, contract spawn):
  `not-reproduced: <the defect line, without the prefix>`; `D<n>` exists only in the brief.
- 2026-10-27 Technical constraints & tradeoffs: Q Can the milestone auditor's counts be one command? → A
  (self-resolved, contract spawn): no. `reviewed-path-gate.sh` refuses a `$(…)` substitution around the
  reviewed-markers path, so the auditor runs two plain counts and adds them; the fixture test runs exactly
  those commands.
- 2026-10-27 Domain entities / data model: Q Who numbers the ADR, given that the scribe-contract shape needs
  a number? → A (self-resolved, contract spawn): the contract names 0043; the scribe takes the next free
  number if it is gone, and criterion 7 checks "highest before the unit + 1" instead of a literal.
- 2026-10-27 Completion / acceptance signals: Q How do rfp-u5's criteria avoid passing on word presence? → A
  (self-resolved, contract spawn): each reads its claim's value from the live source (reviewer, protocol,
  auditor, unit commits) and fails, printing `missing:` or `no-source`, when the two disagree.
- 2026-10-27 Functional scope & success criteria: Q Are rfp-u2's PASS-note findings on the Gate G measurement
  fixed before the paid replay, and what stays fixed? → A: yes, as unit rfp-u2b before Gate G. Thresholds,
  labels and the corpus stay unchanged, and no paid `claude -p` run happens (per user, 2026-10-27).
- 2026-10-27 Domain entities / data model: Q What does `score.py` count, and how are repeated, unknown and
  absent ids treated? → A (self-resolved): it scores distinct ids. Ids not in `labels.tsv` are `foreign`
  and ignored. An identical repeat counts once, and a repeat that differs in answer or artifact is a
  `dup-conflict`, which fails the gate. Any id labelled real or bogus with no row is `missing`, which makes
  the result `insufficient`. The user asked for real ids; bogus ids are added so that dropping their
  `NONE` rows cannot shrink the unanswered denominator.
- 2026-10-27 Edge cases / failure handling: Q What does `run.sh` write for a group whose setup fails? → A:
  one `NONE` row per defect, tagged `setup: clone|brief` (per user, 2026-10-27).
- 2026-10-27 External dependencies & integrations: Q How is answer leakage prevented, and how is that tested
  without a paid run? → A (self-resolved, rfp-u2b contract spawn):
  - a fresh repository per group, fetched by commit id up to the reviewed commit (spec-master tested this
    on git 2.43 at 0.5 s per group);
  - `--setting-sources local` and `--strict-mcp-config`;
  - `guard.py` as a PreToolUse hook;
  - a fake `claude` on `PATH` in the fixture suite.

  The one claim no offline test reaches, that a `--settings` hook fires in `-p` mode, gets the `run.sh`
  exit-3 tripwire.
- 2026-10-27 Non-functional attributes (perf, security, scale): Q Do `--allowedTools` rules alone restrict
  the replay to `git show`, `git diff` and `git log`? → A (self-resolved, Claude Code docs via
  `claude-code-guide`): no. Read-only commands such as `cat` run without a prompt in every mode, a bare
  `Read` rule reaches any absolute path, and allow rules merge across setting scopes. The user's
  `settings.local.json` allows `Bash(python3 -c ' *)`. A blocking PreToolUse hook overrides allow rules, so
  the guard is the enforcement.
- 2026-10-27 Technical constraints & tradeoffs: Q Fix the `--labels` diffstat in the code or in the
  docstring? → A (self-resolved): the docstring, which is cheaper and leaves the labelling output alone.
  The 300-character cut is stated in the docstring and the README.
- 2026-10-27 Completion / acceptance signals: Q How do rfp-u2b's criteria avoid the precheck's two-line
  literal quirk? → A (self-resolved): every expected stdout is one line (harness note under Step 2b).
- 2026-10-28 Functional scope & success criteria: Q Is the Gate G1 labeling tool a throwaway page or a
  permanent tool in the repository? → A: permanent. It is a localhost server shipped in the repository that
  serves the page from memory and writes each label click straight into `labels.tsv`, with no export step.
  Only a human click may write, and it binds to 127.0.0.1 only (per user, 2026-10-28). It becomes unit
  rfp-u2c, and `label-ui` is superseded.
- 2026-10-28 User interaction flow: Q Do keyboard shortcuts set labels? → A: no. Labeling is mouse-only, and
  r/b/u are removed. j/k, filters, search, groups, the progress panel and the evidence stay. A
  keyboard-synthesised click (`e.detail === 0`, Enter/Space on a focused button) never writes, and buttons
  never keep focus (per user, 2026-10-28).
- 2026-10-28 Domain entities / data model: Q What is one label write? → A (self-resolved): one POST carrying
  `id`, `value` and `version`. `id` must be in the corpus, `value` in `real|bogus|unknown`, and `version` must
  be the sha256 of the file's current bytes (otherwise 409, and the page reloads). Exactly that id's line is
  replaced under a lock, by temp file, fsync and rename, so the header, the order and every other byte are
  kept.
- 2026-10-28 Non-functional attributes (perf, security, scale): Q Which localhost protections, and what do
  they not cover? → A (self-resolved):
  - bind 127.0.0.1; refuse a foreign Host (DNS rebinding) and a foreign or missing Origin;
  - a per-launch token, required in the URL for the page and in a header for every write;
  - POST only, JSON only, a 1024-byte cap, exact paths, no CORS, no file serving, no shell, and a strict CSP.
  These do not stop a local process that reads the URL, the token or the file itself, an agent included. The
  human's commit is the record.
- 2026-10-28 Edge cases / failure handling: Q Is extra evidence of a human session warranted, and is a
  committed marker? → A (self-resolved): a local append-only write log (`.git/refutation-label-writes.log`: one
  JSON line per POST with Origin and User-Agent, never the token, never tracked) is warranted, because it is
  cheap. A committed marker is out of scope (Out of scope 8): any process that can run the tool could forge
  it.
- 2026-10-28 Technical constraints & tradeoffs: Q Keep a read-only export, or the old generator, next to the
  server? → A (self-resolved): neither. The user chose the server only. The labels are already a plain file in
  the working tree that `git diff` shows, and `build-corpus.py --labels` stays the text checklist.
- 2026-10-28 External dependencies & integrations: Q How is the real-browser probe run without a network
  install? → A (self-resolved): Node playwright, found through `PLAYWRIGHT_PATH`, then `node_modules`, then
  the drivers in local Python environments (this machine: two miniforge envs). It uses playwright's cached
  Chromium. With none found it prints a loud `SKIP !!!` line, which validate.sh's skip summary counts, and it
  fails when `LABEL_UI_REQUIRE_BROWSER` is set.
- 2026-10-28 Completion / acceptance signals: Q How do rfp-u2c's criteria avoid passing vacuously when the
  writer authors both the code and the tests? → A (self-resolved): the contract fixes anchor comments on the
  exact lines of the eight checks. Criterion 3 deletes or moves each line in a scratch copy and requires the
  named case to go red. It prints `noanchor` if the anchor is missing, `green` if the suite misses the
  mutation, and `base=fail` if the unmutated suite is not all-pass.
- 2026-10-28 Terminology consistency: Q What do "on screen" and "target" mean, given that label-ui's FAILs
  hinged on them? → A (self-resolved): "target" is the j/k navigation card (`target`, an id or null). A card is
  "on screen" when it is displayed and its top edge lies between the sticky header's bottom edge and the
  viewport's bottom edge. The page and the probe share this one definition (contract edit 2).
- 2026-10-28 Domain entities / data model: Q Are the Gate G1 labels settled? → A: yes, all 41 `real` (option A,
  per user), committed at 5f0c28de.
- 2026-10-28 Edge cases / failure handling: Q What did Open Questions 2 and 3 resolve to? → A: Open Question 2
  is (a), per user (this re-dispatch: "stop, return the report to spec-master to revise the brief, then replay
  again"). Open Question 3 was implemented as rfp-u2d (a6ecb429, PASS), which is option (a). spec-master saw
  that answer as a commit, not as a user message.
- 2026-10-28 Completion / acceptance signals: Q Which criterion failed in Gate G run 1, and did any run hit the
  10-turn cap? → A (self-resolved, from the CLI's bundled source, four local transcripts and the report): only
  the turn rule failed. No run hit the cap. On a finished run, `num_turns` is 1 plus the run's tool calls
  (Revision 3, diagnosis 1).
- 2026-10-28 Terminology consistency: Q What does "turn" mean in Gate G? → A (self-resolved): two things. A
  **turn** is one loop iteration, which `--max-turns` and the explorer's `maxTurns` cap. `num_turns` is the
  CLI's result field, which on a finished run counts 1 plus every tool result. The plan writes `num_turns`
  for the field and "turn" only for the iteration.
- 2026-10-28 Technical constraints & tradeoffs: Q Which brief changes cut tool use without weakening
  refutation? → A (self-resolved): a 9-call budget split per defect, UNCERTAIN once a share is spent, the
  large-file rule and one-line answers. Rejected: a q1 short-circuit (it pushes toward REFUTED on line drift),
  a lower defect cap (the data does not support it) and re-ordering the questions (Revision 3, diagnosis 2).
- 2026-10-28 Edge cases / failure handling: Q What does the explorer answer when a defect's share is spent? →
  A (self-resolved): UNCERTAIN, naming the open question; never REFUTED and never CONFIRMED.
- 2026-10-28 Non-functional attributes (perf, security, scale): Q Is the 34% UNCERTAIN rate a brief problem,
  and do the economics change? → A (self-resolved): 12 of 14 come from the replay or the answer format. The
  Cost model gains the measured `Cp` and `u` and a revised break-even. The kill rule goes to Open Question 7.
- 2026-10-28 Functional scope & success criteria: Q Does the evidence force a change to D1 to D8? → A
  (self-resolved): no. D4 was checked against the data and stands.
- 2026-10-28 Technical constraints & tradeoffs: Q Does a changed `bin/refutation-brief.sh` need a version bump
  to install? → A (self-resolved): no. `--update` re-renders a raw helper on content drift
  (`bin/cli.js:1546-1550`). rfp-u1b bumps anyway, so its CHANGELOG entry carries a version, as rfp-u1's did.
- 2026-10-28 Completion / acceptance signals: Q Does the Gate G turn rule change, and is a cut-off run checked?
  → A: the rule stays exactly as written (no run over 10 by `score.py`'s `num_turns`), and one check is added:
  no run may end `error_max_turns`. `run.sh` records the CLI result's `subtype` and `is_error`. `score.py
  --gate` fails on a capped run and appends `capped=<p>` after `foreign=`. Every threshold is unchanged (Open
  Question 4 (a), per user, 2026-10-28). It becomes unit rfp-u2f.
- 2026-10-28 Technical constraints & tradeoffs: Q Does a long file's per-defect share beat the Goal's "whole
  file"? → A: yes, the share wins, as rfp-u1b already ships (Open Question 5 (a), per user, 2026-10-28).
- 2026-10-28 Domain entities / data model: Q Are the corpus claims re-extracted before run 2, and does that
  change the ids or labels? → A: yes. The builder keeps whole claims, and the corpus is regenerated with the
  same 41 ids. `labels.tsv` stays byte-identical, which a criterion checks against its committed hash (Open
  Question 6 (a), per user, 2026-10-28).
- 2026-10-28 Completion / acceptance signals: Q Does the kill rule gain a `u` trigger now? → A: no. Decide
  after run 2, before rfp-u3 is dispatched. rfp-u2f does nothing for it beyond not blocking it (Open Question 7
  (a), per user, 2026-10-28).
- 2026-10-28 Domain entities / data model: Q What exactly is a "whole claim"? → A (self-resolved, rfp-u2f
  contract spawn): the whole defect item, meaning the bullet line plus every indented line after it, across
  blank lines, up to the next bullet or unindented line. It is whitespace-collapsed into one line and cut at 8000
  characters. Selection still reads the bullet line alone, so the kept defects do not change. Why: the live
  reviewer pipes its whole defect, uncut, as one `D<n>:` line. Of the 41 rows, only gh-303 D1 depends on
  crossing blank lines (315 against 1,483 characters), and its later paragraphs hold the Reproduce text that
  its UNCERTAIN answer missed.
- 2026-10-28 Non-functional attributes (perf, security, scale): Q Why a cut at 8000 and not none, and does the
  brief's input limit bind? → A (self-resolved): `run.sh` passes the brief as one `claude -p` argument, which
  Linux caps at 128 KiB. 8000 keeps a 3-defect brief near 27 KB at worst, and no current claim reaches it (the
  longest `dline` is 1,915). The brief reads lines with `read -r` and has no length or stdin limit. All 24 run-2
  briefs built with rfp-u1b's script exit 0, and the largest is 4,710 bytes.
- 2026-10-28 Technical constraints & tradeoffs: Q Rebuild the corpus, or refresh its claims? → A
  (self-resolved): refresh. A rebuild on today's FAIL records selects from 58 candidates and changes the ids,
  and the build mode rewrites `labels.tsv` to all `unknown`. `--refresh-claims` rewrites only `dline`, matched by
  block, cite and claim prefix. It is idempotent and never writes labels.
- 2026-10-28 Edge cases / failure handling: Q Does the turn rule as written already fail a capped run? → A
  (self-resolved, the CLI's bundled source): yes. `num_turns` is 11 on a capped run, and `run.sh` writes it on
  each row. Diagnosis 1's bullet saying "only the unanswered rule sees it" is corrected in place. `capped=`
  names the cause and survives a future change of the cap.
- 2026-10-28 External dependencies & integrations: Q Which result subtypes exist, and which count as capped?
  → A (self-resolved): `success`, `error_max_turns`, `error_max_budget_usd` and `error_during_execution`; the
  three errors set `is_error: true`. Only `error_max_turns` counts in `capped`, because the user named the turn
  cap. The other two are recorded but not gated (Out of scope 9).
- 2026-10-28 Functional scope & success criteria: Q Which carried review items fold into rfp-u2f? → A
  (self-resolved): the case (q) sentinel stdin, the `main` wrapper and `3<&-`. All three sit in `run.sh` and the
  isolation suite, which rfp-u2f already edits, and each has its own case. The rfp-u2c label-server notes stay
  out (Out of scope 10).
- 2026-10-28 User interaction flow: Q What does Gate G run 2 reuse, and what becomes of run 1's report? → A
  (self-resolved): run 2 uses the committed tooling as it stands after rfp-u1b and rfp-u2f, with no other
  change. Run 1's report is evidence only, because an in-place mutant of `run.sh` produced it. Whether to
  commit its copy, and where, stays the user's call (Gate G).
- 2026-10-29 Functional scope & success criteria: Q The coordinator said "decide: fix or document" for the
  in-flight click; which? → A (self-resolved): fix. The written rule ("the pointer has not left the click point
  of that write") already allows the click; the code lagged it. Documenting would have changed the rule.
- 2026-10-29 Technical constraints & tradeoffs: Q How far may `guard.py`'s bundle scan relax? → A
  (self-resolved): stop only at `-S`, `-G` and `-L`, whose value is the rest of the token on git 2.43; every
  other letter stays scanned, so the remaining over-blocks are in the safe direction.
- 2026-10-29 Technical constraints & tradeoffs: Q `score.py` bad input exits 2, the same code as `--gate`'s
  `insufficient`; acceptable? → A (self-resolved): yes, the coordinator named exit 2; both mean "not a pass",
  and stdout tells them apart (no `replay-gate:` line on bad input).
- 2026-10-29 Edge cases / failure handling: Q Does an undecidable sampled refutation count toward `held`? → A
  (self-resolved): no; it counts toward `sampled` only, and it is already an informational finding.
- 2026-10-29 Terminology consistency: Q Which glossary words change? → A: "refutation verifier" replaces bare
  "verifier" on the refutation pass avoid list, and **mechanical ground** gets its own entry, per the
  coordinator's rfp-u5 items (verified against `CONTEXT.md` at 57ec2d70).
- 2026-10-29 Functional scope & success criteria: Q Does the route-gate test gain a `model: sonnet` check? → A
  (self-resolved): no, dropped; no hook reads `model`, so the check would be vacuous (Step 6 item 7).
- 2026-10-29 Functional scope & success criteria: Q Is `label.py`'s traceback on a broken `score.py` in Step
  6? → A: open, Open Question 8 (default: no).
- 2026-10-29 Functional scope & success criteria: Q Is Open Question 8 now in scope? → A: yes. The coordinator's
  Step 7 dispatch names it as item 8, so it is rfp-u7d (Step 7 scorecard: functional scope, data model,
  non-functional and completion Clear; user flow, integrations, edge cases, tradeoffs and terminology Partial,
  resolved below).
- 2026-10-29 User interaction flow: Q Which Step 7 units may be built at the same time, and what is serial? → A
  (self-resolved): no file appears in two units. rfp-u7b, rfp-u7c, rfp-u7d and rfp-u7e may be built concurrently.
  rfp-u7b alone bumps the version, edits `CHANGELOG.md` and runs `--update`. rfp-u7a follows rfp-u7b's PASS. Each
  dirty-tree criterion names only its own unit's files.
- 2026-10-29 External dependencies & integrations: Q Does git take `--orderfile=<file>`? → A (self-resolved, git
  2.43 run in a scratch repo): no. `--orderfile`, `--orderf` and `--ord` are usage errors in `diff`, `log` and
  `show`; only `-O<file>` exists. Item 9's first half is dropped.
- 2026-10-29 Edge cases / failure handling: Q Where do REFUTED defects go when the verdict is
  INSUFFICIENT-CONTEXT? → A (self-resolved): in the `refutation` advisory section, as in a mixed FAIL; the
  least-change reading of the existing bullets. What becomes of them on the resume is a design choice: Open
  Question 9.
- 2026-10-29 Technical constraints & tradeoffs: Q Move the **refutation outcome** qualifier to right after
  "REFUTED:" as worded, or keep the pinned phrases? → A (self-resolved): keep the pins. The qualifier goes in
  the sentence just before "REFUTED:", which removes the ambiguity without breaking the phrases that rfp-u5
  criterion 4 and rfp-u6c criterion 3 pin ("REFUTED: the defect is dropped and recorded as …").
- 2026-10-29 Technical constraints & tradeoffs: Q Narrow `score.py`'s `try` how? → A (self-resolved): split
  `load()` (arguments, both files, and the numeric conversions of labelled rows) from `score()`, and put only
  `load()` in the `try`. A broken pipe or a code bug after parsing now ends in a traceback; tested with
  `/dev/full` and with `score.score` replaced by a function that raises.
- 2026-10-29 Terminology consistency: Q Where do **FAIL ground** and **refutation sample** go? → A
  (self-resolved): both in `CONTEXT.md`, by rfp-u5's split: reviewer and auditor concepts go in `CONTEXT.md`
  (**judgment defect**, **mechanical ground**), the grammar of a line in `docs/harness-glossary.md`
  (**refutation line**). The sample's four counts are defined inside its one entry.

## Risks / dependencies

- **R1: wrong refutations.** See Safety: Gate G before enabling, the milestone sample after, and recovery
  downstream.
- **R2: replay fidelity.** The replay runs headless `claude -p` with read-only tools, not the `explorer`
  persona body, and without its graph MCP. It reproduces the brief exactly (D8) but not the persona prose.
  This is stated in the replay README. The persona adds instructions; it removes none of the brief's rules.
  Since rfp-u2b, each run also sees only a clone holding the history up to the reviewed commit. It loads
  no user, project or plugin settings, and its Bash is limited to `git show`, `git diff` and `git log`.
  The live explorer has the whole repository, so the replay is stricter than live use in this respect.
- **R3: proxy labels.** "Fixed and later passed" can label a bogus defect "real" if the implementer complied
  with a non-defect. The human confirmation in `labels.tsv` exists for this. That bias would only make the
  gate stricter, because a bogus defect counted as real and then refuted counts as a miss.
- **R4: audit noise.** One `grant-denied` line per pass. Out of scope.
- **R5: ordering.** As in "Units and order": rfp-u1, then rfp-u2 (its `run.sh` needs the brief script), then
  rfp-u2b (it hardens rfp-u2's files), then rfp-u2c (the G1 labeling tool), then Gate G (human: G1 labels, G2
  the paid replay, G3 the score), then rfp-u3, then rfp-u4, then rfp-u5 (after both rfp-u3 and rfp-u4). The
  branch has other units in flight, so each bump is +1 on the version current at dispatch.
- **R10: the labeling tool writes ground truth.** The server must never be a label source of its own. It has
  no default, bulk or startup write, and every write is one validated, version-checked line from a trusted
  mouse click. Server cases S01 to S16 check this, and so does the browser probe, whose invariant is checked
  after every step of a seeded random sequence (rfp-u2c B09). What the server cannot stop: a local process
  with the token, or with write access to the file, can change labels. The human's review of `git diff` and
  their own commit remain the control (README, rfp-u2c edit 8).
- **R11: rfp-u2c's criteria were not run green by spec-master.** No payload exists to run them on (the
  contract specifies behaviour, not code). Each was checked with `bash -n`, the runnable ones fail on today's
  tree as stated, and the mutation commands were run on dummy anchor lines. The reviewer's run of criterion 3
  is the first full proof.
- **R12: the budget's arithmetic and its blind spot.**
  - The 9-call budget assumes that, after the first message, only tool results add to `num_turns`. A
    `user`-type message injected for another reason (a hook's feedback, a queued command) would add to it.
    Run 1 shows no sign of one: its lowest count, 4, matches 3 calls.
  - A run that keeps the budget exactly reports `num_turns` 10, which is at the line. Run 2 is the proof.
  - The budget can lower `r` by leaving some refutations unfound. An all-real corpus cannot measure that.
    The milestone-auditor sample (rfp-u4) and the kill rule are the only checks after enabling.
- **R13: the replay's UNCERTAIN rate is not the live rate.**
  - Clipped claims, Bash limited to three git verbs, and the missing untracked data all push the replay
    toward UNCERTAIN (Revision 3, diagnosis 3).
  - The live explorer has full claims and the whole working tree, so the replay's `u` (29%) is an upper
    estimate. rfp-u2f removes the clipped-claim cause (Open Question 6 (a)), so run 2's `u` is closer to the
    live rate.
  - Nothing measures the live `u` before the milestone auditor's sample.
- **R14: the corpus refresh reads per-clone state.** `--refresh-claims` and rfp-u2f's criterion 4 read the
  FAIL records, which are untracked and exist only in the main checkout. In a linked worktree or a fresh clone
  they cannot run, and the regenerated `corpus.jsonl` is then the record, as it was for rfp-u2. FAIL blocks are
  only ever appended, so the refresh stays reproducible in the main checkout. If a block is ever edited, the
  refresh fails closed (exit 1, nothing written).
- **R15: a capped run is now visible twice.** On a capped run, the turn rule and `capped=` both fail. That is
  deliberate: `capped` names the cause. A report written before rfp-u2f has no `subtype`, so `capped=0`
  proves nothing for it. Gate G's G3 step therefore checks that every row of run 2's report has a `subtype`.
- **R8: gate-safe commands.** The milestone auditor's sample commands and the range criteria must pass
  `reviewed-path-gate.sh` and `harness-integrity-gate.sh` as written. spec-master probed them: plain `grep -r`
  piped to `sort` or `wc -l` passes; a `$(…)` substitution around the reviewed-markers path is refused, and so
  is any Bash text naming the persona config file. rfp-u4 keeps two plain counts and matches `^\.claude/`.
- **R9: the `not-reproduced:` report has no consumer yet.** The reviewer of the fix round re-judges each
  defect as it does today; a defect it still reproduces FAILs normally. No orchestrator change is planned
  (Out of scope 5).
- **R6: parity seams.** rfp-u3 merges the protocol edit, its four ports, the reviewer source and its
  regenerated mirrors into one gate (spec-master memory: never slice across a parity test).
- **R7: rfp-u3 is large** (about 14 files). It stays one unit by necessity (R6). If the contract-score guard
  demotes it, the ladder handles that.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Artifacts are required and re-checked. The replay gate measures
  before enabling. spec-master ran the base-rate classifier, the route-gate mutation and the pin phrases on
  scratch copies.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The brief is a script (D8), the
  builder and scorer are deterministic, and the mirrors come from `--update` only.
- P3 "Version-stamp discipline": satisfied. rfp-u3 and rfp-u4 touch `agents/` and `templates/` and bump in
  each commit. rfp-u1 bumps too: it touches no stamped path, but `--update` installs a new helper.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every lead unit has a validate.sh criterion, and
  rfp-u1, rfp-u2, rfp-u2b and rfp-u2c register their new suites. rfp-u2b and rfp-u2c touch no stamped path
  and need no bump. rfp-u2c's browser probe skips loudly without a browser, and validate.sh's skip summary
  counts that line.
- Revision 3 (rfp-u1b):
  - P1: satisfied. The `num_turns` premise was checked in the CLI's bundled source and the transcripts, not
    assumed, and every rfp-u1b criterion was run on a scratch payload.
  - P2: satisfied. The budget is computed by the script, not written per run.
  - P3: not required, because no stamped path is touched. The bump keeps the CHANGELOG entry versioned.
  - P5: satisfied (rfp-u1b criterion 8).
- rfp-u2f:
  - P1: satisfied. The CLI result shape was read from the installed 2.1.312 bundle. spec-master ran the claim
    rule, the refresh, every criterion and every mutation on a scratch clone, and built all 24 run-2 briefs.
  - P2: satisfied. The claims come from a deterministic, idempotent `--refresh-claims`, never by hand, and
    `capped` comes from the CLI's own field.
  - P3: not required, because no stamped path is touched. No bump and no CHANGELOG entry, as for rfp-u2b
    to rfp-u2e (criterion 9 refuses `plugin.json`, `package.json` and `CHANGELOG.md`).
  - P5: satisfied (rfp-u2f criterion 11; both suites are already registered).
- Step 7 (rfp-u7a to rfp-u7e):
  - P1: satisfied. Every item was checked against b9bcdf92 first; the `--orderfile` premise was tested on
    git 2.43 and dropped; spec-master ran every criterion and the mutations it names on a scratch clone.
  - P2: satisfied. Mirrors come from `--update` only (rfp-u7b), and the hunks were generated from the
    scratch commits and replayed byte for byte.
  - P3: satisfied. rfp-u7b is the only unit touching a stamped path, and it bumps in each commit (its
    criterion 5); rfp-u7a, rfp-u7c, rfp-u7d and rfp-u7e touch none.
  - P5: satisfied. rfp-u7b criterion 7 runs `validate.sh`, which passed on the scratch clone with all five
    units committed; the edited suites are already registered.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. `explorer` is a core persona, and a spawn
  failure degrades to `skipped=no-subagent`.

## Step 1 (rfp-u1, lead-programmer): `bin/refutation-brief.sh`

Affected files:
- `bin/refutation-brief.sh`
- `tests/refutation-brief.test.sh`
- `bin/cli.js` (`BIN_HELPER_FILES`)
- `tests/bin-helpers-scaffold.test.sh`
- `tests/validate.sh`
- the version bump files
- generated `.claude/bin/refutation-brief.sh`

Criteria: see the contract (fixture suite, scaffold, cmp, scope, validate).

## Step 1b (rfp-u1b, lead-programmer, after Gate G run 1): the brief's tool-call budget

Dispatch rfp-u1b after rfp-u2e's review has returned, and after Open Questions 4 and 5 are answered or their
defaults accepted. Revision 3 explains why. [Contract](2026-10-27-refutation-pass/contracts/rfp-u1b.md).

Affected files:
- `bin/refutation-brief.sh`
- `tests/refutation-brief.test.sh`
- the version bump files and `CHANGELOG.md`
- generated: `.claude/bin/refutation-brief.sh`, which `run.sh` does not use (it calls the checkout's
  `bin/`). cmp keeps the two byte-identical.

Not touched: `eval/` in full, so the thresholds, labels, corpus and report stay as they are. Persona text is
not touched either, so no `agents/`, `templates/`, `hooks/` or `adapters/` path changes. The defect grammar,
the cap of 3, the questions and the answer grammar line stay byte-identical (criterion 7).

Criteria (9, each with one stdout line):
- the suite;
- the new cases red on rfp-u1's script (`ajklm`);
- cmp with the installed copy;
- the installed copy's per-count shares (`943`);
- both replay suites through `run.sh` (`0 0`);
- per-commit scope;
- grammar preservation;
- `validate.sh` at 4 lanes;
- a clean tree.

spec-master ran each one on a scratch payload, and each mutation turns it red. The hunks reproduce the tested
payload byte for byte, and `contract-anchors.js` reports `ok checks=31 bad=0 unchecked=0`.

**rfp-u3's reviewer text.** It needs no change under the default answers. The reviewer bullet pipes the
defects into the script and treats "no answer line" as "stands as found", and the budget lives only in the
script.

Two answers would change rfp-u3 or rfp-u4 before dispatch:
- Open Question 7 (b) tags the INSUFFICIENT-CONTEXT `missing:` line in rfp-u3 and counts it in rfp-u4.
- Open Question 4 (c) or (d) changes what Gate G checks, and rfp-u3 criterion 8 reads its verdict. Its
  `cut -d" " -f1-2` stays valid if the scorer only appends fields, as rfp-u2b did (CHK34).

**rfp-u2f.** The user answered Open Questions 4 (a) and 6 (a), so rfp-u2f exists. See Step 2f. Revision 3's
draft of this paragraph said "cut at 1,000 characters". The contract cuts at 8000 instead, a bound no claim
reaches (Clarifications, 2026-10-28).

## Step 2 (rfp-u2, lead-programmer): the replay corpus, runner and scorer

Affected files:
- `eval/refutation-replay/{README.md,build-corpus.py,run.sh,score.py,corpus.jsonl,labels.tsv}`
- `tests/refutation-replay.test.sh`
- `tests/validate.sh`

No stamped path. Criteria: the fixture suite, `--check` on the committed corpus, the vacuity guard on an
empty report, `--dry-run` flags, scope, validate.

## Step 2b (rfp-u2b, lead-programmer, after rfp-u2): Gate G hardening

rfp-u2 reached PASS at 6c8b4b1a. Its reviewer's non-blocking notes show that the Gate G measurement could be
weak or gamed. The user chose to fix that before the paid replay (G2).

| finding (rfp-u2 PASS note) | fix | case in the new suite |
|---|---|---|
| `score.py:35` counts rows, so one real id repeated 30 times passes | score distinct ids; ignore `foreign` ids; a conflicting repeat fails the gate; every id labelled real or bogus must have a row (otherwise `insufficient`) | a, b, c, e, f |
| the worktree shares refs, and Read or grep reach the main checkout's FAIL records and `labels.tsv` | a fresh repository fetched up to the reviewed commit only; `--setting-sources local`, `--strict-mcp-config`, `--permission-mode dontAsk`, `--tools Read,Grep,Glob,Bash`; `guard.py` as a PreToolUse hook refuses paths outside the clone; exit 3 if the hook is not wired | g, h, i, l, m |
| `run.sh:30` `Bash(git *)` is not read-only | pre-approve only `git show`, `git diff` and `git log`, and the guard refuses every other Bash command (`git -c`, aliases, `--output`, `--no-index`, shell operators) | g, j, n, o |
| `run.sh:56,58` drop a group whose worktree or brief fails | one `NONE` row per defect, tagged `setup` | k |
| `build-corpus.py:10` promises a diffstat; the 300-character cut at `:87` is undocumented | fix the docstring (cheaper than changing the labelling output); state the cut in the docstring and the README | p |
| `run.sh:45` prunes worktrees on `--dry-run` too | gone with the worktree: the EXIT trap only removes the scratch directory | n |

Affected files:
- `eval/refutation-replay/{guard.py (new),score.py,run.sh,build-corpus.py,README.md}`
- `tests/refutation-replay-isolation.test.sh` (new)
- `tests/validate.sh` (registration)

No stamped path, so no version bump. `corpus.jsonl` and `labels.tsv` are untouched: no builder logic changes,
and the labels stay `unknown` for G1. The thresholds are unchanged, and no paid run happens (the suite fakes
`claude`).

Criteria:
- both suites pass;
- the new suite fails exactly 14 named cases against rfp-u2's files (red at baseline);
- the corpus and labels are unchanged and there is no report;
- the scorer line on the absent report;
- the dry-run flags on the committed corpus;
- a per-commit scope check;
- file modes;
- `validate.sh` with `ANTISLOP_VALIDATE_LANES=4`.

Every criterion has a single-line expected stdout (see the harness note below).

The contract is about 48 KB. `contract-score.js` gives it score 3 with `sizeOver`, the same as rfp-u2's 32 KB
contract, which reached PASS. Its bulk is the tested payload: two new files, and ten hunks generated
from the scratch diff.

**Harness note (not a unit).** `review-precheck.sh` `run_one` compares a criterion's whole stdout with one
backtick literal. A two-line expected stdout written as `` `A` then `B` `` can never match: rfp-u2 criterion 3
hit this, and its reviewer overrode the false fail by hand. Until the precheck learns two-line literals,
contract criteria should print one line, or the reviewer must override.

## Step 2c (rfp-u2c, lead-programmer, after rfp-u2b): the Gate G1 labeling server

The human needs a usable way to set 41 labels. The unplanned `label-ui` page generator failed review 3 times
on one defect class and is superseded (Context, "Prior FAIL history", rfp-u2c). The user chose a permanent,
mouse-only localhost server in the repository that writes clicks straight into `labels.tsv` (Clarifications,
2026-10-28).

- **What ships.** `eval/refutation-replay/label.py serve` and its page template `label_page.html`. The server
  binds 127.0.0.1 on a random or given port, serves one in-memory page behind a per-launch token, and accepts
  one write shape: `POST /label`. Each write is token-, Host- and Origin-checked, validated against the corpus,
  version-checked (409, and the page reloads), and written as one atomic line under a lock. Every POST is
  logged to `.git/refutation-label-writes.log`. It runs headless with `--no-open`, and otherwise tries
  `wslview`, `explorer.exe` or `xdg-open` and never fails if none works.
- **The page.** Labeling is mouse-only: no key writes, buttons never take focus, and untrusted or
  `detail === 0` clicks are dropped. It keeps j/k, filters, search, groups, the progress panel (at least 30 real,
  at most 11 bogus, read from `score.py`) and the evidence (claim, fix commit, numstat, a hint that is never a
  label, and a capped diff). `refresh()` runs before any scroll, and a hidden target becomes `null`.
- **Retired.** `label-ui.py` and `tests/refutation-label-ui.test.sh` are deleted. Their WIP `D\d+` and rename
  fixes are ported first. There is no export and no import.
- **Tests.**
  - The server suite (S01 to S16) uses stdlib only, runs in-process on fixtures, and never opens the real
    files.
  - A headless-Chromium probe (B01 to B11) uses trusted input and a seeded random sequence, and checks after
    every step that the file changed only through a mouse click on an on-screen label button.
  - A docs case (D01).
  - Criterion 3 applies eight anchored mutations: token, Host, Origin, version, non-atomic write, a
    re-enabled key label, `detail === 0` allowed, and scroll-before-refresh. Each must turn its named case
    red.

Affected files:
- `eval/refutation-replay/{label.py (new), label_page.html (new), README.md}`
- `eval/refutation-replay/label-ui.py` (deleted)
- `tests/{refutation-label.test.sh, refutation-label-server.py, refutation-label-browser.js}` (new)
- `tests/refutation-label-ui.test.sh` (deleted)
- `tests/validate.sh` (registration)

No stamped path, so no version bump. `labels.tsv`, `corpus.jsonl`, `score.py` and its thresholds are
untouched, and no model runs. Expected tier: opus, full lane. Criteria (12, each with a single-line stdout):
- the suite with a browser required, and its exact case inventory;
- the mutation matrix;
- a real-corpus smoke on copies (41 rows, nothing written, clean SIGTERM);
- retirement and no model text;
- README step 1 claims against `--help`;
- per-commit scope;
- labels and corpus untouched;
- the loud-skip path;
- file modes;
- `validate.sh` at 4 lanes;
- a clean `eval` and `tests` tree.

## Step 2f (rfp-u2f, lead-programmer, after Open Questions 4 to 7): the replay tooling for run 2

[Contract](2026-10-27-refutation-pass/contracts/rfp-u2f.md). The user answered Open Questions 4 (a) and
6 (a), so run 2 needs two tooling changes. Two cheap hardening items from rfp-u2e's review come with them.

| item | change | case |
|---|---|---|
| capped runs (Open Question 4 (a)) | `run.sh` writes the CLI result's `subtype` and `is_error` on every row (`none`/`true` without a result). `score.py --gate` fails when a scored id's run is `error_max_turns` and appends `capped=<p>` after `foreign=`. The thresholds are byte-identical | isolation r, s, e |
| whole claims (Open Question 6 (a)) | the claim is the whole defect item (bullet line plus indented lines, across blank lines), cut at 8000. Selection still reads the bullet line. `--refresh-claims` rewrites only `dline` in the committed corpus, which is regenerated (41 ids; `labels.tsv` byte-identical) | replay k, l, m; isolation p |
| case (q) has no failing test for ` < /dev/null` (rfp-u2e note) | `run.sh` gets a sentinel stdin in case (q); the draining fake records it; `timeout 60` | isolation q |
| `run.sh` re-read mid-run (rfp-u2e note; run 1's stray line) | the body becomes `main() { … }`, and the last line is `main "$@"; exit` | isolation t |
| fd 3 inherited (rfp-u2e note) | `3<&-` on the `claude` call | isolation u |
| docs | the builder and scorer docstrings and the README state the claim rule, the refresh and the capped rule | isolation p, v |

Affected files:
- `eval/refutation-replay/{run.sh,score.py,build-corpus.py,README.md}`
- `eval/refutation-replay/corpus.jsonl` (regenerated by `--refresh-claims` only)
- `tests/refutation-replay.test.sh`
- `tests/refutation-replay-isolation.test.sh`

No `tests/validate.sh` edit: both suites are registered. No stamped path, so no bump and no CHANGELOG entry.
`labels.tsv`, `report.jsonl`, `bin/refutation-brief.sh`, `guard.py` and the label server are in "Do NOT
touch".

Criteria (12, each with one stdout line):
- both suites;
- the new cases red on the pre-unit files (`replay=k,l,m isolation=e,r,s,t,u,v`);
- corpus ids and fields kept, claims only extended (`longer=40`);
- the committed corpus equals a fresh `--refresh-claims`;
- the `labels.tsv` committed hash and `--check`;
- the scorer's field order with `capped` last;
- the thresholds and flags byte-identical;
- the dry-run identical to the pre-unit `run.sh`;
- per-commit scope;
- file modes;
- `validate.sh` at 4 lanes;
- a clean tree.

spec-master ran every criterion and mutation on a scratch clone at 4ec89dae. The 42 hunks reproduce the
tested payload byte for byte, and `contract-anchors.js` prints `contract-anchors: ok checks=89 bad=0
unchecked=0`. `contract-score.js` scores it 3 with `sizeOver` (53 KB), as it scores rfp-u2b's 48 KB contract,
which reached PASS. Six range criteria print `no-commits` on the real tree.

## Gate G (human, between Step 2c and Step 3; not a dispatchable unit)

Ordering: Gate G started after rfp-u2c's PASS. *(Revision 3: the user confirmed all 41 labels `real`, option
A, and they were committed at 5f0c28de. G1 is done.)* G1 requires `unlabeled=0`, so no `unknown` id reaches
G3's unanswered denominator (`rfp-u2b.pass` `NOTE[spec]` 2).

| step | what | who | how to check it |
|---|---|---|---|
| G1 | confirm or reject each of the 41 proxy labels: run `python3 eval/refutation-replay/label.py serve`, click real or bogus on each card (the clicks land in `eval/refutation-replay/labels.tsv` in the working tree), review `git diff`, and commit `labels.tsv`. `build-corpus.py --labels` stays the text checklist | the human operator (an agent labelling would grade its own kind) | `python3 eval/refutation-replay/build-corpus.py --check` prints `unlabeled=0` |
| G2 | `bash eval/refutation-replay/run.sh`: 24 headless sonnet runs at 958f557e (one per group), each capped by `--max-budget-usd 1`; commit `report.jsonl` | the human operator, or the orchestrator on the human's explicit instruction | the report exists, one row per corpus defect |
| G3 | `python3 eval/refutation-replay/score.py --gate eval/refutation-replay/report.jsonl` | anyone | first line `replay-gate: pass …`, exit 0. On `fail` or `insufficient`, do not dispatch rfp-u3; return the report to spec-master |

**Run 1 (2026-10-28): `fail`, on the turn rule only** (Revision 3). G2's report was not committed. It is
evidence only, not a gate record: the human's run started before 2bf3ac51 was committed, while a lead's
uncommitted in-place mutant of `run.sh` (` < /dev/null` removed) was on disk, and the lead restored the file
in place during the run (rfp-u2e PASS note). The copy is at
`/tmp/claude-1000/-home-sebas-AntiSlop/05a6765a-da13-4deb-9a15-1128b5ee3d15/scratchpad/report-run1-gatefail.jsonl`.
Scored by rfp-u2f's `score.py`, it prints `… foreign=0 capped=0` and exits 1. It has no `subtype`, so
`capped=0` proves nothing for it (R15).

**Run 2** comes after both rfp-u1b (PASS, 4ec89dae) and rfp-u2f have reviewer PASS markers, in either order.
It uses the committed tooling as those two units leave it, with no other change: no edit to `run.sh`,
`score.py`, `corpus.jsonl`, `labels.tsv` or the brief between rfp-u2f's PASS and G3, and no edit to any of
them while G2 runs.

| step | what | who | how to check it |
|---|---|---|---|
| G1 (rerun) | nothing to label. rfp-u2f kept the 41 ids and `labels.tsv` byte-identical. The human may re-read the full claims in `label.py serve`, which writes only on a click | — | `python3 eval/refutation-replay/build-corpus.py --check` prints `corpus: rows=41 groups=24 units=24 unlabeled=0 real=41 bogus=0 errors=0` |
| G2 (rerun) | first keep run 1's copy (above): `run.sh` empties `report.jsonl` when a real run starts. Then `bash eval/refutation-replay/run.sh --dry-run` (24 `group=` lines), then `bash eval/refutation-replay/run.sh`: 24 headless sonnet runs, about $1.6, each capped by `--max-budget-usd 1` and `--max-turns 10`. Commit `report.jsonl` | the human operator, or the orchestrator on the human's explicit instruction | the report has 41 rows, one per corpus id, and every row has a `subtype`: `python3 -c 'import json; r=[json.loads(l) for l in open("eval/refutation-replay/report.jsonl")]; print(len(r), sum("subtype" in x for x in r))'` prints `41 41` |
| G3 (rerun) | `python3 eval/refutation-replay/score.py eval/refutation-replay/report.jsonl --gate` | anyone | first line `replay-gate: pass …`, ending `capped=0`, exit 0. Every threshold is unchanged: at least 30 real, at most 1 refuted-real, at most 20% unanswered, no run over 10 by `num_turns`, and now no capped run. On `fail` or `insufficient`, do not dispatch rfp-u3; return the report to spec-master. Open Question 7 (the kill rule) is decided after this step, before rfp-u3 |

Reading run 2 (`rfp-u1b.pass` notes 2 and 3): a 2-defect group has a share of 4, so its 9th call is unusable
by design. A 3-defect group's share of 3 equals the brief's floor of whole file, callers and baseline, so one
refused call forces UNCERTAIN. Count per-group calls with that in mind.

Whether to commit run 1's copy, and where, is the user's call. The plan cites its numbers in Revision 3.

## Step 3 (rfp-u3, lead-programmer, after Gate G): the refutation pass and the FAIL-record format

Affected files:
- `agents/reviewer.md`
- `templates/persona-protocol.md`
- the four adapter ports above
- `tests/persona-prose-pins.test.sh`
- `tests/reviewer-route-gate-caller.test.sh`
- `tests/adapter-fail-tier-pin.test.js`
- `tests/fail-record-refutation.test.sh` (new)
- `tests/validate.sh`
- the version bump files
- the regenerated `.claude/` mirrors

Criteria include `score.py --gate`.

## Step 4 (rfp-u4, lead-programmer, after rfp-u3): downstream readers

Affected files:
- `agents/task-master.md`: the fix-contract bullet. A defect prefixed `[unconfirmed]` gets a reproduce-first
  `command:` edit and a criterion that holds whether it was fixed or never reproduced; if it does not
  reproduce, the lead-programmer makes no edit for it and reports
  `not-reproduced: <the defect line, without the prefix>`. (Revision 2 said `D<n>`; FAIL defect lines carry
  no D-number, which exists only in the brief.) The `refutation:` line is never a defect.
- `agents/milestone-auditor.md`: a refutation sample of up to 3 `refuted:` notes per milestone, plus the
  counts behind the `r` ratio from the Cost model, printed as
  `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`, and the kill-criterion finding.
- `tests/refutation-sample.test.sh` (new): the auditor's three grep commands on a fixture with decoys, and a
  check that the persona and its mirror ship them verbatim.
- `tests/persona-prose-pins.test.sh`, `tests/validate.sh`
- the version bump files and the mirrors

No hand-synced port carries task-master or milestone-auditor. Criteria: prose pins, the fixture test,
per-file diff budgets, a per-commit scope check, a per-commit version-stamp check, a clean tree, validate.

## Step 5 (rfp-u5, scribe, after rfp-u3 and rfp-u4): glossary and ADR

Affected files:
- `CONTEXT.md`: new entries **refutation pass** (it acknowledges the :46 "Refute" sense), **judgment
  defect** and **refutation outcome**; the **FAIL block** entry updated for the last-line `refutation:` and
  the `[unconfirmed]` prefix.
- `docs/harness-glossary.md`: a **refutation line** entry with its grammar.
- `docs/adr/0043-refutation-pass-inside-reviewer-turn.md`. The scribe-contract shape needs a number, so the
  contract names 0043 (next free at 3bd60f56); the scribe takes the next free number if 0043 is gone by
  dispatch, and criterion 7 computes the expected number from the tree before the unit's first commit.

Criteria check each claim against its live source: the cap and the model from `agents/reviewer.md`, the
grammar from `templates/persona-protocol.md`, the sample size from `agents/milestone-auditor.md`, and the
ADR's "no hook, marker, ladder or orchestrator change" from the commits of rfp-u1 to rfp-u4.

## Step 6 (rfp-u6a, rfp-u6b, rfp-u6c, after rfp-u5): hardening from the review notes (2026-10-29)

The open advisory notes of the rfp-u2b, rfp-u2c, rfp-u2d, rfp-u2f, rfp-u3, rfp-u4 and rfp-u5 PASS markers,
each verified against the tree at 57ec2d70 before a criterion was written. Fifteen hand-edited files in all,
over the 10-file line, so the step is three units with no file in common (the coordinator's split rule). Each
unit's payload was built and tested in a scratch clone of 57ec2d70 by spec-master; `tests/validate.sh` with
all three applied exited 0 (4 lanes).

| item | source note | unit | disposition |
|---|---|---|---|
| 1 | rfp-u3 PASS: the Verdict bullet's "and nothing more" vs the `refutation:` line | rfp-u6a | fixed in `agents/reviewer.md` and its mirror. The codex and cursor ports are **dropped**: they run no pass, and their FAIL record adds `refutation: skipped=no-subagent` after "the same defect list you return in your verdict", so their two bullets agree. No `templates/` file carries the sentence |
| 2 | rfp-u4 PASS: unanchored `-F` list and prevented greps; `held` undefined | rfp-u6a | both greps anchored (`'^NOTE\[code]: refuted: '`), mid-line decoy in the fixture; one sentence: an undecidable refutation counts toward `sampled`, never `held` |
| 3 | rfp-u2c PASS: B12 second write; in-flight click dropped; no wheel re-arm test | rfp-u6b | **fixed**, not documented: the rule as written ("the pointer has not left the click point of that write") already covers a move during the POST, so the code is brought to the rule (`label_page.html`; `label.py` is unchanged). B12 extended, new B14 |
| 4 | rfp-u2f PASS: `score.py` capped over scored ids untested; bad input traceback | rfp-u6b | bad input exits 2 with `score.py: bad input: <reason>` and no stdout; cases (o) and (p) |
| 5 | rfp-u2d PASS: `-SObject` over-blocked; no long-option case; docstring | rfp-u6b | bundle scan stops at `-S`, `-G`, `-L` (`-[^-SGL]*O`); cases incl. `--grep=FOO`; docstring states the bundle rule and the fail-closed wrapper |
| 6 | rfp-u2f PASS: `build-corpus.py:211` multi-match untested | rfp-u6b | case (n); no code change |
| 7 | rfp-u3 PASS: the route-gate explorer case does not check `model: sonnet` | none | **dropped**: no hook reads a dispatch's `model` field (`reviewer-route-gate.sh` and `dispatch-hygiene.sh` grep empty for it), so a gate test fed `model: sonnet` exits 0 for any model: vacuous. A real check needs a hook edit (excluded). The instruction itself is pinned at `tests/persona-prose-pins.test.sh:60` |
| 8 | rfp-u5 PASS: **refutation outcome** says REFUTED is recorded on the PASS | rfp-u6c | mixed-FAIL clause added. ADR 0043 is **dropped**: it never says where a REFUTED defect is recorded |
| 9 | rfp-u5 PASS: "verifier" on the avoid list vs `CONTEXT.md:57` | rfp-u6c | narrowed to "refutation verifier" |
| 10 | rfp-u5 PASS: "mechanical ground" has no entry | rfp-u6c | new entry after **judgment defect**; both related entries link it |

rfp-u6a touches `agents/`, so it bumps the plugin version and adds a CHANGELOG entry (P3); rfp-u6b touches only
`eval/` and `tests/` and rfp-u6c only `CONTEXT.md`, so neither does. The rfp-u5 wording that rfp-u5's criteria
4 and 5 pin is kept verbatim; rfp-u6c's criteria re-check those phrases.

## Step 7 (rfp-u7a to rfp-u7e, after rfp-u6c): the rfp-u6 review notes (2026-10-29)

The coordinator's nine follow-up items, each taken from an rfp-u6a, rfp-u6b or rfp-u6c PASS note and checked
against the tree at b9bcdf92 before a criterion was written. The rule that shapes the slicing: **no file
appears in two units**, mirrors and version-stamped files included, so that the units can be built in parallel.
spec-master built and tested every payload in a scratch clone of b9bcdf92, with one commit per unit. With all
five committed, `ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh` exited 0 (OK=3442 FAIL=0 WARN=2, about 6
minutes).

| item | source note | unit | disposition |
|---|---|---|---|
| 1 | rfp-u6c PASS: the **refutation outcome** "unless the re-check finds a reason…" reads as qualifying the gating-off clause | rfp-u7a | fixed: the qualifier moves into the sentence before `REFUTED:` ("after the reviewer's own re-check, which keeps a defect standing when it finds a reason the artifact does not defeat the claim. REFUTED: …"), not to just after `REFUTED:`, so that the phrases pinned by rfp-u5 criterion 4 and rfp-u6c criterion 3 stay intact. Clarifications record why |
| 2 | rfp-u6c PASS: "FAIL ground" has no entry | rfp-u7a | new **FAIL ground** entry in `CONTEXT.md`, before **judgment defect**; **mechanical ground** links it. The placement follows rfp-u5: reviewer concepts go in `CONTEXT.md`, line grammars in `docs/harness-glossary.md` |
| 3 | rfp-u6a and rfp-u6c PASS: "refutation sample" and its counts have no entry | rfp-u7a | one new **refutation sample** entry, after **refutation outcome**, which defines `sampled`, `held`, `prevented` and `eligible` inline (one entry, not five) from `agents/milestone-auditor.md` as it stands |
| 4 | rfp-u6c PASS: where do REFUTED defects go when the rest are UNCERTAIN and the verdict is INSUFFICIENT-CONTEXT? | rfp-u7b | the least-change rule, not an operator decision: they go, with their reasons, in the `refutation` advisory section, as in a mixed FAIL, which the Verdict bullet already allows after any verdict line. Only `agents/reviewer.md` carries the Refutation pass bullet (no template or port does). What happens to them on the resume is a real design choice: Open Question 9 |
| 5 | rfp-u6a PASS (and unit 124's untagged note): "and nothing more" vs the advisory sections and the STATUS line | rfp-u7b | FAIL ends "and nothing more in the FAIL block", and one sentence says that each "nothing else" or "nothing more" bounds the verdict block itself. The codex and cursor ports have the same tension (an inlined roast-work section and the protocol STATUS line follow their verdict): Open Question 10 |
| 6 | rfp-u6a PASS: refutation-sample case (d) flattens before `grep -F` | rfp-u7b | case (d) greps the file itself. Mutation: a command split onto two lines in `agents/milestone-auditor.md` passes the old case (d) and fails the new one (spec-master ran both). It goes in rfp-u7b because the test reads the mirror that rfp-u7b's `--update` regenerates, and so that Step 7 stays at five units |
| 7 | rfp-u6b PASS: `score.py` docstring; the `try` covers all of `score()` | rfp-u7c | docstring fixed; parsing moves into `load()`, and only `load()` is inside the `try`. Cases (o) cost, (o2) and (o3), each red on b9bcdf92 or under a widening mutant |
| 8 | rfp-u2c PASS via Open Question 8: `read_min_real` traceback, `MIN_REAL = True` accepted | rfp-u7d | fixed: any load error is a `LabelError` (exit 2, one line), and `type(v) is int`. S13 gains five variants. Open Question 8 is resolved: the coordinator put it in scope |
| 9a | rfp-u6b PASS: `--orderfile` is not in `BAD_OPT` | none | **dropped**: git 2.43 has no `--orderfile` option. `git diff --orderfile=of` exits 129 (usage), `git log -1 --orderfile=of -p` and `--ord=of` exit 128, and `git show --orderfile=of` exits 128, while `-Oof` exits 0. Only `-O<file>` and the `diff.orderFile` config exist, and `-O` is already refused, in a bundle too. Adding a dead option would test nothing |
| 9b | rfp-u6b PASS: `..` right after `:` in `-L1,2:../x` | rfp-u7e | fixed. It is not an exploitable leak: git refuses it ("'../x' is outside repository"), and META keeps the cwd at the clone root. But the guard's docstring promises to refuse any argument with a `..` path segment, so code and doc disagree. `UP` becomes `(^|[/:])\.\.(/|$)`. Still allowed: `-L1,2:src/IO.c`, `-SObject`, `-G[O]`, `--grep=FOO`, `HEAD~1..HEAD`, `..HEAD`, `HEAD:src/a.sh` |
| - | rfp-u6b PASS note 7 (the B12 mutation was checked by verdict line only) | none | not one of the coordinator's items; it is about how a mutation was checked, not a defect in the tree |

**Concurrency and order.** File sets (each unit's scope criterion pins its own):
- rfp-u7b: `agents/reviewer.md`, `tests/persona-prose-pins.test.sh`, `tests/refutation-sample.test.sh`,
  `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, and the `--update`-generated `.claude/` files.
- rfp-u7c: `eval/refutation-replay/score.py`, `tests/refutation-replay.test.sh`.
- rfp-u7d: `eval/refutation-replay/label.py`, `tests/refutation-label-server.py`.
- rfp-u7e: `eval/refutation-replay/guard.py`, `tests/refutation-replay-isolation.test.sh`.
- rfp-u7a: `CONTEXT.md`.

rfp-u7b, rfp-u7c, rfp-u7d and rfp-u7e may be built at the same time. rfp-u7b is the only unit that may bump the
version, edit `CHANGELOG.md` or run `--update`, so it is never run twice at once. rfp-u7a is file-disjoint, but
it is dispatched after rfp-u7b's PASS, because its **refutation outcome** text and its criterion 2 source check
use rfp-u7b's new INSUFFICIENT-CONTEXT sentence (before that, the criterion prints `no-source: …`). Reviews stay
one unit at a time. The cross-reads are all read-only and stable: `label.py` and S15 read `score.py`'s
`MIN_REAL` line, which rfp-u7c keeps byte-identical; the isolation suite runs `score.py`; case (d) reads the
milestone-auditor mirror, whose body `--update` does not change. Each unit's dirty-tree criterion names only
its own files, so a sibling's work in progress in the same tree does not fail it. rfp-u7b's `validate.sh`
criterion runs every suite, so it needs a tree where no sibling has uncommitted edits, or its own worktree.
Dispatch order: rfp-u7b, rfp-u7c, rfp-u7d and rfp-u7e in any order (rfp-u7b first if review must be serial and
rfp-u7a is to follow soon), then rfp-u7a.

**Model tier.** `node .claude/bin/contract-guard.js` prints `contract-guard: sonnet … score=3/7` for rfp-u7b,
rfp-u7c and rfp-u7d. rfp-u7a and rfp-u7e are scored when their contracts are written.

**Payload for the two contracts still to write** (verified on the scratch clone; the next spawn copies it into
the contract shapes of rfp-u6c and rfp-u6b).

rfp-u7a, scribe, `CONTEXT.md` only (`knowledgeWrites` is `apply`), commit subject
`docs(rfp-u7a): FAIL ground and refutation sample entries; refutation outcome qualifier moved (#0)`:
1. New entry before `**judgment defect**:`, separated by one blank line:
   ~~~~
   **FAIL ground**:
   (plan 2026-10-27-refutation-pass, unit rfp-u7a) — one reason a reviewer FAIL
     verdict rests on, listed in the verdict as a reproducible defect. It is
     either a [[mechanical ground]], such as a `review-precheck.sh` failure line,
     which is a FAIL ground on its own, or a [[judgment defect]]. Only the
     acceptance-criteria commands and the materiality filter make one: the
     `roast-work` and `ubiquitous-language` passes never add a FAIL ground, and
     their findings stay in the advisory sections after the verdict.
   _Avoid_: FAIL reason, FAIL cause
   ~~~~
2. In **mechanical ground**, the first two lines become
   `(plan 2026-10-27-refutation-pass, unit rfp-u6c) — a [[FAIL ground]] the` and
   `  reviewer established with a check rather than by reading:` (the rest of the entry is unchanged).
3. In **refutation outcome**, the lines from `  re-check. REFUTED: the defect is dropped and recorded as a` to
   `  stays a defect.` become:
   ~~~~
     re-check, which keeps a defect standing when it finds a reason the
     artifact does not defeat the claim. REFUTED: the defect is dropped and
     recorded as a `NOTE[code]: refuted:` note on the PASS when every defect is
     REFUTED, or in the verdict's `refutation` advisory section when another
     defect keeps the FAIL or when the rest are UNCERTAIN and the verdict is
     INSUFFICIENT-CONTEXT (under review gating off, always in that section).
     CONFIRMED: it stays a defect.
   ~~~~
4. New entry after **refutation outcome**'s `_Avoid_: refutation verdict` line, separated by one blank line:
   ~~~~
   **refutation sample**:
   (plan 2026-10-27-refutation-pass, unit rfp-u7a) — the milestone auditor's
     check on the [[refutation pass]]. No later gate re-checks a refutation that
     turned a FAIL into a PASS, so at each milestone the auditor re-verifies the
     first 3 `NOTE[code]: refuted:` notes of that milestone's PASS markers (all,
     if fewer) against the code at the marker's commit. Its findings list ends
     with one line, `refutation-sample: sampled=<s> held=<h> prevented=<p>
     eligible=<p+f>`. `sampled` counts the notes it re-verified. `held` counts
     the ones it decided hold; one it cannot decide counts toward `sampled`,
     never toward `held`. `prevented` counts the PASS markers in the whole
     project that carry a `refuted:` note, each a FAIL the pass prevented.
     `eligible` adds to that the [[FAIL block]]s whose [[refutation line]] shows
     the pass ran and the FAIL survived (`refutation: confirmed=`). A refutation
     that does not hold is a finding of at least moderate severity. When
     `eligible` is 20 or more and `prevented` is under a tenth of it, the
     auditor recommends a follow-up to retire or re-scope the pass.
   _Avoid_: refutation audit, refutation spot-check
   ~~~~

rfp-u7a criteria (each printed the stated line on the scratch clone, and the stated mutation output on the
CONTEXT.md of b9bcdf92):
- `bash -c 'for t in "FAIL ground" "refutation sample" "refutation outcome" "mechanical ground"; do printf "%s=%s/%s " "$t" "$(grep -cxF "**$t**:" CONTEXT.md)" "$(grep -cxF "**$t**:" docs/harness-glossary.md)"; done | sed "s/ $//"; echo'`
  prints `FAIL ground=1/0 refutation sample=1/0 refutation outcome=1/0 mechanical ground=1/0` (b9bcdf92: `FAIL ground=0/0 refutation sample=0/0 …`).
- A source-and-entry check of **refutation outcome**, in rfp-u6c criterion 3's shape. Source phrases, from the
  flattened `agents/reviewer.md` with backticks removed: "You may keep a defect standing with a stated reason",
  "and the REFUTED ones and your reasons go in the refutation advisory section, as in a FAIL", and "(under review
  gating off, to the refutation section instead)". Entry phrases: "re-check, which keeps a defect standing when
  it finds a reason the artifact does not defeat the claim. REFUTED: the defect is dropped", "REFUTED: the defect
  is dropped and recorded as a NOTE[code]: refuted: note on the PASS when every defect is REFUTED", "refutation
  advisory section when another defect keeps the FAIL or when the rest are UNCERTAIN and the verdict is
  INSUFFICIENT-CONTEXT (under review gating off, always in that section). CONFIRMED: it stays a defect",
  "UNCERTAIN: it stays in a FAIL that happens anyway, prefixed [unconfirmed]", "REFUTED and CONFIRMED need an
  artifact", and "the verdict is INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN". The last line is
  `checked late-unless=<grep -cF "always in that section), unless">`, so stdout is `checked late-unless=0`.
  On b9bcdf92's entry it prints two `missing:` lines and `checked late-unless=1`. On b9bcdf92's
  `agents/reviewer.md` it prints `no-source: and the REFUTED ones … as in a FAIL`, exit 1 (the reason it waits for
  rfp-u7b).
- A source-and-entry check of **FAIL ground**. Source: "is a FAIL ground on its own" and "never adds a new FAIL
  ground" in `agents/reviewer.md`. Entry: "one reason a reviewer FAIL verdict rests on", "either a [[mechanical
  ground]], such as a review-precheck.sh failure line, which is a FAIL ground on its own, or a [[judgment
  defect]]", "the roast-work and ubiquitous-language passes never add a FAIL ground", and "_Avoid_: FAIL reason,
  FAIL cause". The **mechanical ground** entry must contain "a [[FAIL ground]] the reviewer established with a
  check rather than by reading". Stdout `checked`; b9bcdf92 prints `no-entry`.
- A source-and-entry check of **refutation sample**. Source: "Re-verify the first 3 of them (all, if fewer)",
  "refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>", "one you cannot decide counts toward
  sampled, never toward held", "When eligible is 20 or more and p is under a tenth of it", and "a finding of at
  least moderate severity", all in `agents/milestone-auditor.md`. Entry: each counted field's defining sentence
  as written above, and the `_Avoid_:` line. Stdout `checked`; b9bcdf92 prints `no-entry`.
- `node tests/context-glossary-links.test.js | tail -1` prints `All context-glossary-links checks passed.`
- Scope: the `(rfp-u7a): ` commits touch only `CONTEXT.md` (`0`, or `no-commits`, exit 1). Dirty:
  `git status --porcelain --untracked-files=no -- CONTEXT.md` counts `0`.
- On the scratch clone, rfp-u5 criterion 4 printed `checked` and rfp-u6c criteria 1 to 5 printed their stated
  lines, so the earlier pins hold.

rfp-u7e, lead-programmer, commit subject `fix(rfp-u7e): guard.py refuses a .. path segment after a colon`:
1. `guard.py` docstring: `  that starts with `/` or `~` or has a `..` path segment, and none of the options that read or write`
   becomes two lines: `  that starts with `/` or `~` or has a `..` path segment (a `..` right after a `:` counts, as in`
   and `  `-L1,2:../x` or `HEAD:../x`), and none of the options that read or write`.
2. `UP = re.compile(r'(^|/)\.\.(/|$)')` becomes `UP = re.compile(r'(^|[/:])\.\.(/|$)')`.
3. In `tests/refutation-replay-isolation.test.sh`, after `gb 2 'git log -pRO/abs/x -SObject'`, add:
   `# rfp-u7e: a .. path segment right after a colon leaves the clone too; a range's .. and a colon value stay allowed`,
   `gb 2 'git log -L1,2:../x'`, `gb 2 'git log -L:main:../x'`, `gb 2 'git show HEAD:../x'`,
   `gb 0 'git diff HEAD~1..HEAD'`, `gb 0 'git log ..HEAD'`, `gb 0 'git log -L:main:src/a.sh'` and
   `gb 0 'git show HEAD:src/a.sh'`, one per line.

rfp-u7e criteria (run on the scratch clone):
- `bash -c 'out=$(bash tests/refutation-replay-isolation.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") g2=$(printf "%s\n" "$out" | grep -c "^OK   (g2) ") rc=$rc"'`
  prints `fails=0 g2=1 rc=0`. Mutations: the old `UP` makes (g2) red on the three `gb 2` lines; `UP = \.\.` makes
  (g) and (g2) red (`HEAD~1..HEAD` refused); `(^|[/:])\.\.` without the trailing group makes (g2) red
  (`git log ..HEAD rc=2`).
- `bash -c 'r=; for c in "git log -L1,2:../x" "git show HEAD:../x" "git log -L1,2:src/IO.c" "git log -SObject" "git log -G[O]" "git log --grep=FOO" "git diff HEAD~1..HEAD"; do python3 -c "import json,sys;print(json.dumps({\"tool_name\":\"Bash\",\"tool_input\":{\"command\":sys.argv[1]}}))" "$c" | python3 -B eval/refutation-replay/guard.py . /dev/null 2>/dev/null; r="$r$?"; done; echo "guard=$r"'`
  prints `guard=2200000` (b9bcdf92: `guard=0000000`).
- `bash -c 'grep -cF -- "-L1,2:../x" eval/refutation-replay/guard.py'` prints `1` (b9bcdf92: `0`).
- Scope: the `(rfp-u7e): ` commits touch only `guard.py` and the isolation suite. Truth and dirty: as rfp-u7c
  criterion 6, with the pathspec `eval/refutation-replay/guard.py tests/refutation-replay-isolation.test.sh`
  plus the three ground-truth files, printing `truth-diff=0 dirty=0`.

No Step 7 item needs an ADR: none is hard to reverse, and each follows a rule already written down.

## Out of scope (named follow-ups)

1. The orphan check, as a `review-precheck.sh` fix-round extension.
2. An Integrity rubric item (hardcoded expected values, disabled tests, bypassed validation).
3. Exempting read-only identities from the stop gate's `grant-denied` line (R4).
4. The refutation pass in the codex and cursor ports, which write `skipped=no-subagent` only.
5. Any change to the orchestrator body, the route or stop gates, `ladder-tier.sh`, `fail-count.sh` or
   `escalation-card.sh`.
6. A config switch for the pass. Gate G gates the shipping of the instructions instead.
7. Adding `eval/refutation-replay/labels.tsv` to `protectedPaths`, so that agent Write/Edit on it is refused
   mechanically. It is a persona-config change on the harness surface, not rfp-u2c's.
8. A committed attestation that labels came from a human session. Any process that can run `label.py` could
   forge it. The local write log and the human's commit are the evidence (rfp-u2c).
9. Gating on the other cut-off subtypes, `error_max_budget_usd` (the $1 cap) and `error_during_execution`.
   rfp-u2f records them on each row but does not count them in `capped`, because Open Question 4 (a) named
   only the turn cap. Such a run writes `NONE` rows, so the 20% unanswered rule still sees it. Adding them is
   the user's call.
10. The rfp-u2c advisory notes (Revision 3, carried item b): the B12 second-write re-click, the wheel re-arm,
    a pointer move during an in-flight POST, and `label.py`'s traceback on a broken `score.py`. They touch only
    the label server, which run 2 does not need. *Step 6 (rfp-u6b) takes the first three; the fourth is Open
    Question 8.*

## Open Questions

1. **Replay corpus size.** The measured pool at 958f557e is 57 proxy-real candidates (judgment defect, cited
   file present at the reviewed commit, later fixed, unit later passed). It is smaller than spec-master's
   first estimate of 118, which ignored the reviewed-commit and PASS checks.
   - *(Recommended, applied)* (a) `--size 40`: 41 rows in 24 groups, so 24 sonnet runs, and at least 30
     must be confirmed real. At most 1 miss gives a raw-miss upper bound of about 17%.
   - (b) all 57 candidates (`--size 57`): about 33 runs. Raise `MIN_REAL` to 45; at most 1 miss then
     bounds the raw miss rate at about 11%.
   - (c) (a) now, then re-run (b) once 20 more FAIL records exist. *(from CHK18)*
2. **If Gate G fails.** *Resolved: (a), per user (Clarifications 2026-10-28). Run 1 failed, and Revision 3
   applies it.*
   - *(Recommended)* (a) Stop and return the report to spec-master for a brief revision (rfp-u1 debug spec),
     then re-run the replay.
   - (b) Ship anyway with a sample of every refutation by the milestone auditor instead of 3. *(from CHK19)*
3. **The `guard.py` `-O` bundling note (`rfp-u2b.pass` `NOTE[spec]` 1), before G2.** *Resolved: (a), as
   rfp-u2d (a6ecb429, PASS).* `git diff -RO/abs/path`
   passes the guard, which gives a file-existence oracle and reorders output, but leaks no content. It is not
   rfp-u2c's scope. *(from CHK40)*
   - *(Recommended)* (a) A one-line follow-up unit before G2: refuse any single-dash token containing `O`, plus
     one isolation-suite case.
   - (b) Accept it for G2 and record it as a fidelity limit in the README.
4. **The Gate G turn rule counts tool calls, not turns** (Revision 3, diagnosis 1). "No run exceeded 10 turns"
   reads score.py's `max-turns`, which is the CLI's `num_turns`. On a finished run that is 1 plus the run's
   tool calls. A run cut off at the cap also reports 11, but it writes `NONE` rows, so today only the 20%
   unanswered rule sees it. **The threshold is the user's.** This plan changes nothing until the user answers.
   *(from CHK47)* *Resolved: (a), per user (2026-10-28), as unit rfp-u2f. The sentence above about the
   unanswered rule is corrected under diagnosis 1: the turn rule fails a capped run too.*
   - *(Recommended)* (a) Keep the rule as written, which holds each run to at most 9 tool calls (rfp-u1b). Also
     add one check: no run may end `error_max_turns` (rfp-u2f: `run.sh` records `subtype`, `score.py` fails
     the gate on it). No threshold is relaxed. One criterion is added, and a cut-off run can no longer hide
     under the unanswered allowance.
   - (b) Keep the rule as written and change only the brief (rfp-u1b). Run 2 can follow rfp-u1b alone, but a
     cut-off run is still visible only through the unanswered rule.
   - (c) Replace the rule with the cap check from (a), which is what the Cost model meant. Run 1 cannot be
     re-scored, because `subtype` was not recorded, so run 2 is still needed. rfp-u1b stays useful as a cost
     bound, but no criterion needs it.
   - (d) Keep a 10-turn rule, but count turns: `run.sh` counts distinct assistant message ids from
     `--output-format stream-json --verbose`. This is the most faithful turn count and the largest `run.sh`
     change.
5. **Long files against the per-defect share** (rfp-u1b edit 13). The Goal says the explorer reads "the whole
   file". A file longer than one Read page costs several calls: `docs/harness-glossary.md` was 2,892 lines at
   esc-left-4's reviewed commit. *(from CHK50)* *Resolved: (a), per user (2026-10-28). rfp-u1b already ships
   it.*
   - *(Recommended, applied in rfp-u1b)* (a) The share wins. The explorer reads the cited region plus the places
     grep finds for the cited code, and names what it read in the artifact.
   - (b) The whole file always: drop that sentence. Defects in long files then run out of share more often and
     end UNCERTAIN.
6. **Corpus claims are clipped** (Revision 3, diagnosis 3). 37 of the 41 claims end mid-sentence, and 7
   UNCERTAIN artifacts name it. The gate is unaffected, but run 2's `u` (the Cost model) is not. *(from CHK52)*
   *Resolved: (a), per user (2026-10-28), as unit rfp-u2f. The claim is the whole defect item, cut at 8000
   rather than 1,000, and `--refresh-claims` keeps the ids (Clarifications).*
   - *(Recommended)* (a) Before run 2, rfp-u2f also makes `build-corpus.py` keep a wrapped bullet's continuation
     lines and cut at 1,000 characters instead of 300, without changing which defects it selects. The criteria
     check that the 41 ids and `labels.tsv` are byte-identical and that `--check` prints `unlabeled=0`.
   - (b) Run 2 on the corpus as it is, and record `u` as an upper estimate.
7. **The kill rule and the UNCERTAIN-only round trip** (Cost model, "Measured in Gate G run 1"). At run 1's
   `u` of 29%, break-even rises from `r > ~15%` to `r > ~25%`. The kill rule (`r` < 10% after 20 eligible
   runs) does not see round trips. *(from CHK55)* *Resolved: (a), per user (2026-10-28). It is decided after
   run 2's G3 and before rfp-u3 is dispatched.*
   - *(Recommended)* (a) Decide after run 2 and before rfp-u3 is dispatched, once `u` is measured on full
     claims. rfp-u3 and rfp-u4 stay as written until then.
   - (b) Now: open the follow-up also when more than 25% of eligible runs end UNCERTAIN-only. rfp-u3's reviewer
     bullet then tags that INSUFFICIENT-CONTEXT's `missing:` line (`missing: refutation:` …), and rfp-u4's
     auditor counts it. Both contracts change before dispatch.
   - (c) Keep the kill rule as written.
8. **`label.py` on a broken `score.py`** (Step 6; Out of scope 10's fourth item; rfp-u2c PASS note). The
   original note is about `label.py`, not `score.py`: `read_min_real` (`label.py:81-87`) exits 1 with a
   traceback when `score.py` has a syntax error or no `MIN_REAL`, and it accepts `MIN_REAL = True` (the page
   then reads "at least true real"). rfp-u6b fixes `score.py`'s own bad-input exit, which the coordinator
   named, but not this. Nothing is written and no socket is bound on that path. *(from CHK80)*
   - *(Recommended)* (a) Leave it as a named follow-up: it needs a broken `score.py` beside `label.py`, and
     Gate G1's labels are done.
   - (b) Fold it into rfp-u6b before dispatch: catch any exception in `read_min_real` as a `LabelError` (exit 2,
     one line) and refuse a `bool`, with a server-suite case. It adds `label.py` and
     `tests/refutation-label-server.py` (9 files in rfp-u6b, still under 10).
   *Resolved 2026-10-29: in scope, per the coordinator's Step 7 dispatch (item 8), as unit rfp-u7d. Not folded
   into rfp-u6b, which has passed.*
9. **REFUTED defects on the resume after an UNCERTAIN-only INSUFFICIENT-CONTEXT** (Step 7 item 4). rfp-u7b
   puts them in the INSUFFICIENT-CONTEXT verdict's `refutation` advisory section. On the resume the reviewer
   FAILs what it now reproduces and makes the rest `NOTE[code]: unconfirmed:` lines. If that resume ends in a
   PASS, the earlier REFUTED defects appear nowhere on the marker, so the milestone auditor's refutation sample
   never sees them and `prevented` does not count that PASS. *(from CHK86)*
   - *(Recommended)* (a) Leave the resume text as it is. That matches the mixed FAIL, whose REFUTED defects are
     also only in the unpersisted advisory section, and a PASS reached on the resume is decided by the reviewer's
     own reproduction, not by the refutation.
   - (b) On a resume that ends in PASS, also write one `NOTE[code]: refuted:` line per earlier REFUTED defect,
     so the sample covers them. That is one more sentence in rfp-u7b (before its dispatch) or a later
     version-stamped unit.
10. **The codex and cursor ports' Verdict bullets** (Step 7 item 5). They also say "and nothing more" and
    "nothing else", while their inlined roast-work section is "appended AFTER the verdict line" and their
    protocol files require the STATUS line. *(from CHK87)*
    - *(Recommended)* (a) Leave them, as Step 6 did: the item names `agents/reviewer.md` only, and the ports are
      hand-synced copies whose parity tests spec-master did not run for this change.
    - (b) Add the same "bounds the verdict block itself" sentence to both ports in rfp-u7b (two more files in
      the one serial unit; its scope criterion and Do NOT touch list change).

## Self-check
- CHK1: Is the verdict defined for every combination of standing, CONFIRMED and UNCERTAIN defects, and for
  a skipped pass? — PASS (both Context tables)
- CHK2: Is behaviour defined for a truncated explorer, a missing answer line, and a non-reproducing
  artifact? — PASS ("stands as found")
- CHK3: Does the plan define what the FAIL block's last line says in each case, including skipped? — PASS
  (verdict table, last column)
- CHK4: Do Step 3 and the readers table agree that `refutation:` is the last line and `[unconfirmed]` a
  prefix? — PASS
- CHK5: Is the `refutation:` vocabulary checked against unit-outcomes.js's class substrings by a runnable
  check, not only by reading? — FAIL (missing) — revised in place (rfp-u3 fixture test case c reads the live
  `CLASSES` table)
- CHK6: Is the replay gate non-vacuous on an empty or small report? — FAIL (missing) — revised in place
  (`score.py` exits 2 with `insufficient` below 30 confirmed-real; rfp-u2 criterion 3)
- CHK7: Is it stated what is manual in Gate G, and who does it? — PASS
- CHK8: Is the PASS-after-refutation state stated (marker, stamps, flags)? — PASS
- CHK9: Does the payload delete the "may not argue away" sentence, and is that checked? — PASS (rfp-u3 pin
  `hasnot`)
- CHK10: Is the turn budget justified, with an enforced check? — PASS (cap 3; the replay fails on more than
  10 turns)
- CHK11: Does the reviewer.md "PASS is one line" rule conflict with the `refuted:` notes? — PASS (notes go
  in the marker; the section is advisory)
- CHK12: Is the :137-138 word collision resolved in a step? — PASS (rfp-u3 edit 3)
- CHK13: Are all four hand-synced ports in rfp-u3's Affected files, with a check? — PASS
  (adapter-fail-tier-pin extended)
- CHK14: Is P3 per-commit discipline stated for every unit touching stamped paths, fix rounds included? —
  PASS (contracts' commit notes, plus version-stamp criteria)
- CHK15: Could any range criterion pass on an empty range? — PASS (each prints `no-commits` and exits 1)
- CHK16: Does each Goal clause map to a criterion?
  - Sonnet: rfp-u3 pin 3.
  - Cap 3: rfp-u1 test case b.
  - Telemetry line: rfp-u3 fixture test.
  - `[unconfirmed]`: rfp-u3 pins and fixture test.
  - Gate: rfp-u3 `score.py`.
  - Milestone sample: rfp-u4 criteria 1 and 2 (pins, and the fixture test of the shipped commands).
  - No marker or stamp: the route-gate case.

  — FAIL (missing) at the revision-2 checkpoint, when rfp-u4's criteria were not yet written — revised in
  place (the rfp-u4 contract now carries them). PASS on re-check.
- CHK17: Does criterion rfp-u3/`validate.sh` still fail under its own `mutation:` line, given that gh317,
  gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1-3, rollout-map-1 and spec2-unitA/B
  recorded class vacuous or host? — PASS (the mutation breaks a registered suite)
- CHK18: Is the corpus size settled against cost and confidence? — FAIL (ambiguous) — converted to Open
  Question 1
- CHK19: Is the course of action defined when Gate G fails? — FAIL (missing) — converted to Open Question 2
- CHK20: Does criterion rfp-u3/reviewer.md-numstat still fail under its mutation, given that gh307,
  gh348-3, gh385-2, memdirt-1 and mw-step1-3 recorded class vacuous or host? — PASS
- CHK21: Does criterion rfp-u3/version-stamp still fail under its mutation, given that
  ci-fetch-depth-cleanup and item17-4-name-p3-offenders recorded class host? — PASS
- CHK22: Do the units table, R5, the Step headings and each contract's Retrieval agree on every dependency
  (u1, u2, Gate G, u3, u4, u5)? — FAIL (conflicting): Step 5 said "after rfp-u4" while R5 listed u3, u4, u5
  without edges — revised in place ("Units and order"; Step 5 now reads "after rfp-u3 and rfp-u4")
- CHK23: Is P3 checked per commit, fix rounds included, for rfp-u4, and only over this unit's commits? —
  PASS (rfp-u4 criterion 5 runs `version-stamp-check.sh` on each `(rfp-u4): ` commit; its mutation, an
  unbumped fix commit, prints `bad=1`)
- CHK24: Can any rfp-u4 or rfp-u5 range criterion pass with no unit commit? — PASS (each prints
  `no-commits` and exits 1; rfp-u5 criterion 9 needs commits from all four earlier units)
- CHK25: Are the auditor's commands defined so they run under the gates? — FAIL (missing) at drafting: a
  single substituted command was refused — revised in place (two plain counts; R8)
- CHK26: Does each rfp-u5 claim criterion fail when the glossary disagrees with its source, not only when a
  word is absent? — PASS (spec-master mutated both sides on a scratch copy: entry and source)
- CHK27: Does criterion rfp-u4/validate.sh still fail under its own `mutation:` line, given the units
  recorded class vacuous or host in CHK17? — PASS (the mutation breaks a newly registered suite)
- CHK28: Does each non-blocking note in `rfp-u2.pass` map to an rfp-u2b fix, a suite case and a criterion?
  — PASS (Step 2b table; contract criteria 1, 3 to 7)
- CHK29: Do the units table, R5, the Step 2b heading, the Gate G heading and the rfp-u2b contract's
  Retrieval agree that rfp-u2b sits after rfp-u2 and before Gate G? — PASS
- CHK30: Can any rfp-u2b range criterion pass with no `(rfp-u2b)` commit? — PASS (criteria 3, 4 and 7 print
  `no-commits` and exit 1; spec-master ran them on the real tree)
- CHK31: Is the one assumption the offline suite cannot test (a `--settings` hook fires in `-p` mode)
  backed by a mechanical check? — FAIL (missing) at drafting — revised in place (the `run.sh` exit-3
  tripwire, suite case m, mutation (vii) of criterion 1)
- CHK32: Does criterion rfp-u2b/validate.sh still fail under its own `mutation:` line, given the units
  recorded class vacuous or host in CHK17? — PASS (the mutation breaks the newly registered suite; the
  4-lane run exited 0 in scratch in about 250 s)
- CHK33: Is every rfp-u2b expected stdout one line, given the precheck's two-line literal quirk? — PASS
  (spec-master parsed the contract with the precheck's own awk)
- CHK34: Does rfp-u3 criterion 8 (`cut -d" " -f1-2` of the scorer line) still read the verdict after
  rfp-u2b appends fields? — PASS (rfp-u2b criterion 5)
- CHK35: Do rfp-u2b's ordered edits pass `contract-anchors.js`, and do they reproduce the tested payload?
  — FAIL (conflicting) at drafting: the first draft replaced `score.py` and `run.sh` whole and gave two
  hunks per item, so the checker reported 8 bad and 8 unchecked — revised in place (one hunk per item,
  generated from the scratch diff). The checker now reports `ok checks=40 bad=0 unchecked=0`, and a
  separate applier reproduces all seven files.
- CHK36: Does each user decision of 2026-10-28 map to a contract case and a criterion? — PASS:
  - server-only, no export: rfp-u2c criteria 4 and 5;
  - clicks written straight into `labels.tsv`: S09 and B02;
  - 127.0.0.1 only: S04 and S14;
  - only a human click writes: S01, B03 to B05 and B09;
  - mouse-only, r/b/u removed: B05 and the `keys` mutation;
  - no focus kept, `detail === 0` dropped: B02, B04 and the `detail` mutation.
- CHK37: Does every mutation the task names map to a named case that criterion 3 checks? — PASS. Token S03,
  Host S04, version S08, non-atomic S09, key label B05, `detail === 0` B04, scroll-before-refresh B06, plus
  Origin S05.
- CHK38: Can a criterion-3 mutation pass vacuously when its anchor is missing or the suite is red for
  another reason? — PASS. It prints `noanchor` when the file is unchanged, `other` when the named case did not
  fail, and `base=fail` unless the unmutated suite is all-pass with no SKIP. spec-master ran it on today's
  tree (`base=fail`, no `red`).
- CHK39: Can any rfp-u2c range criterion pass with no `(rfp-u2c)` commit? — PASS. Criteria 7 and 8 print
  `no-commits` and exit 1 (run on today's tree). This plan's own docs commit names the unit without the
  parenthesised tag.
- CHK40: Does every `NOTE[spec]` in the swept surfaces have a disposition? — FAIL (missing) at drafting: the
  `rfp-u2b.pass` `-O` bundling note had none — converted to Open Question 3. The "unknown in the denominator"
  note is resolved in place (Gate G preamble), and the `tests/validate.sh` sweep lines are historical (units
  124 to 149).
- CHK41: Does any rfp-u2c criterion depend on label values, which the human may commit before review? —
  FAIL (conflicting) at drafting: criterion 8 reused rfp-u2b's `unlabeled=41` pin — revised in place. It now
  checks only that no `(rfp-u2c)` commit touches the labels and that the tree is clean; criterion 4 uses
  copies and checks the row count.
- CHK42: Do the units table, R5, the Step 2c heading, the Gate G heading and the rfp-u2c contract's Retrieval
  agree that rfp-u2c sits after rfp-u2b and before Gate G? — PASS.
- CHK43: Is "on screen" defined once and used by both the page and the probe? — PASS (contract edit 2, which
  edit 5 refers to; Clarifications 2026-10-28).
- CHK44: Does criterion rfp-u2c/`validate.sh` still fail under its own `mutation:` line, given the units
  recorded class vacuous or host in CHK17? — PASS. The mutation breaks the newly registered suite, and the
  block sets `fail=1`.
- CHK45: Is the honest limit stated, that a local process with the token or file access can still change
  labels? — PASS (R10, Clarifications, contract edit 8 and the README section).
- CHK46: Are rfp-u2c's criteria proven green against an implementation? — FAIL (missing): no payload exists
  — revised in place. R11 and the contract's "Criteria provenance" state this, and each criterion has
  `bash -n` and today's-tree evidence. Criterion 3 is the reviewer's full proof.

Revision 3 (2026-10-28):
- CHK47: Does what the Gate G turn rule measures agree with what the Cost model says it checks? — FAIL
  (conflicting): `num_turns` counts 1 plus tool calls, and the Cost model says the rule checks the turn cap
  — converted to Open Question 4
- CHK48: Does revision 3 change or reinterpret any Gate G threshold? — PASS (none changes; `score.py` and
  `labels.tsv` are in rfp-u1b's "Do NOT touch", criterion 6)
- CHK49: Is the `num_turns` claim backed by evidence the plan cites, not by inference? — PASS (the bundled
  source's `gr=tn+1` check and `Je++` per user message, 2,388 transcript tool results, and the answered
  11-turn rows)
- CHK50: Do the Goal's "whole file" and rfp-u1b's per-defect share agree for a file longer than one Read
  page? — FAIL (conflicting) — converted to Open Question 5 (default applied in rfp-u1b edit 13)
- CHK51: Is the budget of 9 consistent with the rule as written, and is its assumption stated? — FAIL
  (missing) at drafting: the assumption that only tool results add to `num_turns` was unstated — revised in
  place (R12)
- CHK52: Is the replay's UNCERTAIN rate defined well enough to stand in for the Cost model's `u`? — FAIL
  (ambiguous): 37 of 41 claims are clipped — converted to Open Question 6
- CHK53: Do the units table, Step 1b, the Gate G section and rfp-u1b's Retrieval agree on the order (rfp-u2e's
  review, then rfp-u1b, then rfp-u2f if any, then run 2, then rfp-u3)? — PASS
- CHK54: Can any rfp-u1b criterion pass on today's tree in a way that hides a missing payload? — PASS.
  Criterion 2 prints an empty line, criterion 4 an empty line, and criterion 6 `no-commits`, all run on
  today's tree. Criteria 1, 3, 5, 7, 8 and 9 are preservation checks, and their mutations were run.
- CHK55: Is the kill rule defined for the UNCERTAIN-only round trips the replay measured? — FAIL (missing) —
  converted to Open Question 7
- CHK56: Does the plan say whether rfp-u3's reviewer text must change? — PASS (Step 1b: no, under the
  defaults; Open Question 7 (b) or Open Question 4 (c) or (d) would change it)
- CHK57: Can rfp-u1b's brief raise `refuted-real`? — PASS. A spent share ends in UNCERTAIN, no new text
  invites REFUTED, the q1 short-circuit was rejected, and run 2 re-measures it.
- CHK58: Does every note the sweep returned, and every note the task named, have a disposition? — PASS
  (Context, "Prior FAIL history", rfp-u1b; Revision 3, "Carried open items")
- CHK59: Do revision 3's counts agree with each other? — PASS: 14 UNCERTAIN = 7 + 2 + 2 + 1 + 2; 24 runs =
  7 UNCERTAIN-only + 4 mixed + 13 clean FAILs; 37 clipped = 31 cut + 6 unwrapped
- CHK60: Does criterion rfp-u1b/`validate.sh` still fail under its own `mutation:` line, given the units
  recorded class vacuous or host in CHK17? — PASS (the mutation breaks the suite already registered at
  `tests/validate.sh:823`)
- CHK61: Do rfp-u1b's hunks reproduce the tested payload, and do they pass `contract-anchors.js`? — PASS. A
  scratch applier gives byte-identical files, the checker reports `ok checks=31 bad=0 unchecked=0`, and
  `contract-score.js` scores it 4, as it scores rfp-u1.
- CHK62: Is run 1's record durable once run 2 starts? — FAIL (missing): `run.sh` empties the report, and only
  an out-of-repo copy holds run 1 — revised in place (the Gate G note before G2; where the copy lives is the
  user's call, and Revision 3 cites its numbers)

rfp-u2f (2026-10-28):
- CHK63: Does each of the user's answers to Open Questions 4 to 7 map to a contract edit and a criterion? —
  PASS. 4 (a): edits 22 to 37, cases r and s, and criteria 1, 6 and 7. 5 (a): nothing for rfp-u2f (rfp-u1b
  ships it). 6 (a): edits 13 to 21 and 43, cases k, l and m, and criteria 3 to 5. 7 (a): nothing, and no
  rfp-u2f text blocks it.
- CHK64: Is the "whole claim" rule defined for every shape in the FAIL records (wrapped lines, blank lines
  inside an item, indented sub-bullets, an unindented line after an item)? — FAIL (ambiguous) at drafting:
  "continuation lines" left blank-line paragraphs open, and gh-303 D1 differs by 1,168 characters between the
  two readings — revised in place. The item crosses blank lines and stops at a column-0 bullet or an unindented
  line. Case (k) covers the blank line and the unindented line.
- CHK65: Can the regenerated corpus change an id, a group or `labels.tsv`? — FAIL (conflicting) at drafting:
  the task said "regenerated corpus.jsonl with the same 41 ids", but a rebuild on today's records selects
  different ids and rewrites `labels.tsv` — revised in place (`--refresh-claims`; criteria 3 to 5).
- CHK66: Do the README, the builder docstring and the scorer docstring agree with the code on the cut, the
  refresh and the capped rule? — PASS. Case (p) reads the cut from the code, and case (v) reads the counted
  subtype from `score.py`.
- CHK67: Is the new gate field appended after every existing field, and does every existing parser still
  read the line? — PASS. Criterion 6 prints the field order. Of the existing parsers, only isolation case
  (e) anchored on the last field, and edit 4 updates it. rfp-u3 criterion 8 reads fields 1 and 2.
- CHK68: Are the thresholds unchanged, as the user required? — PASS (criterion 7 pins the constants line and
  the `--max-turns 10` and `--max-budget-usd 1` flags; criterion 8 pins the whole dry-run).
- CHK69: Does the plan say what "capped" means for a report with no `subtype`? — FAIL (missing) at drafting
  — revised in place. Such a row is not counted (score.py docstring, README, R15), and G2's check requires a
  `subtype` on all 41 rows of run 2.
- CHK70: Can any rfp-u2f range criterion pass with no `(rfp-u2f)` commit? — PASS. Criteria 2, 3, 4, 5, 8 and 9
  print `no-commits` and exit 1 (spec-master ran them on the real tree). This plan's docs commit names the
  unit without the parenthesised tag.
- CHK71: Does criterion rfp-u2f/`validate.sh` still fail under its own `mutation:` line, given that gh317,
  gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1, mw-step2, mw-step3, rollout-map-1,
  spec2-unitA and spec2-unitB recorded class vacuous or host and touched `tests/validate.sh`? — PASS. The
  mutation breaks a suite that `tests/validate.sh:833-838` runs, and that block sets `fail=1`.
- CHK72: Does each folded hardening item have a case that fails without it? — PASS. Mutations (ii), (iii) and
  (iv) of criterion 1 turn cases q, u and t red. (ii) was run with an open pipe as the suite's stdin: it
  fails, with no hang.
- CHK73: Do the units table, Step 1b, Step 2f, the Gate G section and both contracts agree on the order
  (rfp-u1b and rfp-u2f in either order, both PASS before run 2, run 2 on unchanged tooling)? — PASS
- CHK74: Is every carried review note either folded in or named as out of scope? — PASS (Context, "Prior FAIL
  history", rfp-u2f; Out of scope 9 and 10)
- CHK75: Does the contract give the lead every hard rule the task named (scratch-only mutations, no kill of a
  foreign process, no real `run.sh`, hands off `report.jsonl`, the writer-scope-gate false positive,
  Write/Edit for tests, 4 lanes)? — PASS (contract "Escalation")
- CHK76: Do the 42 hunks reproduce the tested payload? — PASS. A separate applier gives byte-identical files
  from 4ec89dae, and `contract-anchors.js` prints `ok checks=89 bad=0 unchecked=0`.
- CHK77 (Step 6): Does every one of the ten Step 6 items name a unit or a stated reason it was dropped? —
  PASS (Step 6 table; items 7 and the port and ADR halves of 1 and 8 are dropped with their evidence)
- CHK78: Does each code change in rfp-u6b have a case that fails without it? — PASS. rfp-u6b criteria 1 and 2
  list sixteen mutants; spec-master ran each in the scratch clone and each turned one case red. A first B14
  draft passed on the old page (Playwright's `mouse.click` sends a mousemove that re-arms labelling); it was
  revised in place to bare down/up clicks.
- CHK79: Do the three units share any file, so that order or one-unit-mid-review could matter? — PASS (the
  scope criteria list disjoint sets: rfp-u6a criterion 4, rfp-u6b criterion 5, rfp-u6c criterion 6)
- CHK80: Is the rfp-u2c note "a broken `score.py` exits 1 with a traceback" covered as the note meant it? —
  FAIL (conflicting): the dispatch read it as `score.py`'s own input handling, the note is about `label.py`
  reading `score.py` — converted to Open Question 8
- CHK81: Can any Step 6 criterion pass with no unit commit, or read the real labels or corpus? — PASS. Every
  range criterion prints `no-commits`, exit 1; rfp-u6b criterion 3 points `score.py` at the directory, whose
  labels lookup is `eval/labels.tsv` (absent); the label suite builds fixtures under `mktemp -d`; rfp-u6b
  criterion 6 checks `labels.tsv`, `corpus.jsonl` and `report.jsonl` against 57ec2d70.
- CHK82: Does rfp-u6c keep the phrases rfp-u5's criteria 4 and 5 pin? — PASS (rfp-u5 criteria 3 to 6 print
  `checked` on the scratch CONTEXT.md built from the rfp-u6c contract text)
- CHK83: Is every stdout spec in the Step 6 contracts one line, so that `review-precheck.sh` can read it? —
  PASS (multi-value results are printed as `k=v` fields on one line)
- CHK84: Does criterion rfp-u6a/7 (`validate.sh`) still fail under its own `mutation:` line, given the units
  recorded class vacuous or host that touched `tests/validate.sh` (CHK71's list)? — PASS. The mutation breaks
  `tests/refutation-sample.test.sh`, which `tests/validate.sh:869-874` runs with `fail=1` on failure, and
  rfp-u6a does not touch `tests/validate.sh`.
- CHK85 (Step 7): Does each of the nine Step 7 items name a unit, or a stated reason it was dropped? — PASS
  (Step 7 table: 9a dropped with git 2.43 evidence; the rfp-u6b B12 note recorded as not an item)
- CHK86: Is it defined where REFUTED defects go on the resume after an UNCERTAIN-only INSUFFICIENT-CONTEXT? —
  FAIL (missing) — converted to Open Question 9
- CHK87: Do the ports' Verdict bullets agree with rfp-u7b's "bounds the verdict block itself" sentence? — FAIL
  (conflicting) — converted to Open Question 10
- CHK88: Does any file, mirror or stamped file included, appear in two Step 7 units? — PASS (Step 7 "Concurrency
  and order" lists five disjoint sets; each scope criterion pins one; only rfp-u7b names `plugin.json`,
  `package.json`, `CHANGELOG.md` or `.claude/`)
- CHK89: Do rfp-u7a's **refutation outcome** text and rfp-u7b's Refutation pass sentence agree about
  INSUFFICIENT-CONTEXT, and is their order stated? — PASS (rfp-u7a's source check reads rfp-u7b's phrase; the
  units table puts rfp-u7a after rfp-u7b's PASS)
- CHK90: Does rfp-u7a keep the phrases that rfp-u5 criterion 4 and rfp-u6c criteria 1 to 5 pin? — PASS (all
  printed their stated lines on the scratch clone; Clarifications record the choice not to move the qualifier
  to right after "REFUTED:")
- CHK91: Can any Step 7 criterion pass with no unit commit, run `run.sh` without `--dry-run`, run `label.py
  serve` on the real labels or corpus, or need `rm -rf`? — PASS (scope criteria print `no-commits`, exit 1;
  rfp-u7c criterion 3 only reads `report.jsonl`; rfp-u7d's variants run under `mktemp` and the suite's own cleanup)
- CHK92: Is every Step 7 stdout spec one line? — PASS (rfp-u7c criterion 3 joins its two lines with
  `paste -sd " " -`; no "A then B" spec)
- CHK93: Can a unit's dirty-tree criterion fail because of a sibling unit's work in progress in the same tree? —
  FAIL (conflicting): the first draft of the rfp-u7c to rfp-u7e criteria used the whole `eval/refutation-replay`
  directory as the pathspec — revised in place (each names its own files plus the ground truth)
- CHK94: Is rfp-u7b's `validate.sh` precondition stated for parallel building? — PASS (rfp-u7b criterion 7)
- CHK95: Does criterion rfp-u7b/7 (`validate.sh`) still fail under its own `mutation:` line, given the units with
  recorded class vacuous or host that touched `agents/reviewer.md` or `.claude-plugin/plugin.json` (gh307,
  gh-303, gh313, gh339, gh348-4)? — PASS (the mutation breaks `tests/refutation-sample.test.sh`, which
  `tests/validate.sh:869-874` runs with `fail=1`)
- CHK96: Does criterion rfp-u7b/5 (`version-stamp-check.sh`) still fail under its own `mutation:` line, given
  ci-fetch-depth-cleanup and item17-4-name-p3-offenders (class host) touched that script? — PASS (spec-master's
  scratch fix-round commit with no bump printed `bad=1 touched=yes`)
- CHK97: Does rfp-u7a's `context-glossary-links` criterion still fail under its mutation, given
  item03-2-link-integrity-guard's recorded class vacuous? — PASS (removing the **FAIL ground** entry leaves
  `[[FAIL ground]]` dangling: `2 context-glossary-links check(s) FAILED.`)
- CHK98: Does criterion rfp-u7b/1 (prose pins on the reviewer mirror) still fail under its mutation, given
  gh307's recorded class vacuous on `.claude/agents/reviewer.md`? — PASS (skipping `--update` printed
  `fails=3 rc=1`)

Prose-mode `ubiquitous-language`, Step 7 (advisory):
- Lens 1: "FAIL ground" was used in `CONTEXT.md:1103` and `agents/reviewer.md` for one meaning, a reason a FAIL
  rests on; rfp-u7a defines it so. "Sample" stays distinct from the plan's "replay corpus".
- Lens 2: no new synonym. "Bad input" and "parsing step" are local to `score.py`; "verdict block" names the
  verdict line plus its FAIL list and is used only inside the reviewer's Verdict bullet.
- Lens 3: **FAIL ground** and **refutation sample** are the load-bearing new entries, and rfp-u7a adds both.

Prose-mode `ubiquitous-language`, rfp-u2f (advisory):
- Lens 1: no `CONTEXT.md` term is used with another meaning. "Capped" is the CLI's turn-cap stop, not the
  plan's defect "cap of 3" (D4); the plan writes "capped run" or `capped=` for the first, and "the cap of 3"
  for the second.
- Lens 2: no new synonym. "Claim" keeps rfp-u2's meaning (the defect text after the cite); "whole claim" is
  defined once (Clarifications).
- Lens 3: `--refresh-claims`, `capped` and "defect item" are tool-local and defined in the contract. No
  glossary entry is proposed.

Prose-mode `ubiquitous-language`, revision 3 (advisory):
- Lens 1: "turn" was used for both the loop iteration and the `num_turns` field. Resolved by the
  2026-10-28 terminology clarification. No `CONTEXT.md` term is used with another meaning.
- Lens 2: no new synonym. "Round trip" follows the plan's existing "UNCERTAIN-only round trip".
- Lens 3: "tool-call budget" and "share" are local to the brief and defined in rfp-u1b. `num_turns` is a
  CLI field. No glossary entry is proposed.

Prose-mode `ubiquitous-language` (advisory):
- Lens 1: "refutation" means the change at `agents/reviewer.md:46,137-138` and the reviewer's own findings
  here. Resolved by rewording :138 and by a glossary acknowledgement.
- Lens 2: "refuter" and "verifier" are avoided. "FAIL-block count" is used per its entry.
- Lens 3: new terms are judgment defect, refutation pass, refutation outcome, refutation line and Gate G
  (Gate G is plan-local, not a glossary term).
- rfp-u2b (advisory):
  - `CONTEXT.md` "Contract-score guard" and "guard demotion" use "guard" for another mechanism, so the
    plan and contract always say `guard.py` or "the guard hook", never a bare "guard".
  - "Replay clone" is distinct from "per-clone review state".
  - The scorer fields `foreign`, `dup-conflict` and `missing` are output fields, not domain terms; no
    glossary entry is proposed.
- rfp-u2c (advisory):
  - "Operator" and "human" are used as synonyms, per the `CONTEXT.md` **operator** entry.
  - "Target", "on screen", "label button" and "write log" are page- and tool-local and defined in the
    contract; no glossary entry is proposed.
  - "label-ui" names a superseded unit, not a term.

## Scribe update hint

rfp-u2c needs no scribe step: its README edit is in its own contract, and it adds no glossary term. rfp-u5 is
the scribe's unit ([contract](2026-10-27-refutation-pass/contracts/rfp-u5.md)), after rfp-u3 and
rfp-u4 PASS. Quote rfp-u3's and rfp-u4's PASS lines in its dispatch.

Revision 3: rfp-u1b needs no scribe step. Its CHANGELOG entry is in its contract, and it adds no glossary
term. For rfp-u5's ADR: the Consequences paragraph may cite the measured per-run cost ($0.065) and say that the
explorer brief states a 9-call budget. That is a knowledge proposal for the scribe, not an edit made here.

rfp-u2f needs no scribe step. Its README edit is in its own contract, it adds no glossary term, and it touches
no stamped path, so it has no CHANGELOG entry.

Step 6: rfp-u6c is the scribe's unit ([contract](2026-10-27-refutation-pass/contracts/rfp-u6c.md)); it edits
only `CONTEXT.md`. rfp-u6a and rfp-u6b need no scribe step: rfp-u6a's CHANGELOG entry is in its contract, and
neither adds a glossary term. Prose-mode `ubiquitous-language` on Step 6 (advisory): lens 1, "verifier" was
used for both the reviewer (`CONTEXT.md:57`) and a refutation-pass synonym, resolved by rfp-u6c; lens 2, no
new synonym ("bad input" and "pointer rule" are tool-local); lens 3, **mechanical ground** is the one new
load-bearing term, and rfp-u6c adds it.

Step 7: rfp-u7a is the scribe's unit (its contract comes with the next spec-master spawn); it edits only
`CONTEXT.md`. rfp-u7b's CHANGELOG entry is in its contract. rfp-u7c, rfp-u7d and rfp-u7e touch no stamped
path, so they have no CHANGELOG entry, and none adds a glossary term.
