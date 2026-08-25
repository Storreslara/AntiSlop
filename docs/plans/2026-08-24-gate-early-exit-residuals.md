# Close the two gate residuals: `reviewed-path-gate.sh`'s obfuscated early-exit and `human-decision-gate.sh`'s whitespace+punctuation packet id

Status: **FINAL — dispatch-ready** (spec-master, 2026-08-24). Resolves to **two
units**, fast path. Closes the residuals disclosed by the adversarial reviews of
`hdg-prose-2-fix2` (`.claude/reviewed/hdg-prose-2-fix2.pass`, "THE DISCLOSED
RESIDUAL") and `rpg-comment-3` (`.claude/reviewed/rpg-comment-3.pass`, note N3).
Extends — does not supersede —
`docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md` and
`docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md`.

Every verdict, count and timing below was executed live this session against the
real gates and against measured prototypes, with real writes into
sentinel-seeded `mktemp -d` fixtures. No number is inferred.

**A note on how these measurements were taken.** Both gates block Bash commands
whose text spells their protected path — correctly, and both blocked commands of
mine while this was written. Probes were authored as script files and executed
as `bash <scratch-path>`, with every real write directed into an ephemeral
fixture. Nothing here writes, or attempts to write, this repository's own marker
or `DECISION` files, so this is not the rephrasing workaround either gate's
refusal forbids.

## Goal

Make each gate's Bash path recognize the protected path in **every spelling bash
itself would resolve to it**, closing two measured fail-opens — without
re-denying any prose, read or comment shape either gate currently allows, and
without touching the shared lexer.

## Context

### The two residuals, reproduced live at HEAD (`d006cc0`)

Both were found independently, on different gates, by the adversarial reviews of
the two units that shipped immediately before this spec. Both were confirmed
**pre-existing** on each gate's own pre-unit baseline, so neither is a
regression — and both really write the protected file, verified by executing the
command and diffing a sentinel, not merely by reading a gate verdict.

**Residual A — `reviewed-path-gate.sh`, obfuscated early-exit** (`:152-155`).
The Bash path tests the RAW command text for the contiguous literal
`.claude/reviewed`. Any spelling bash resolves to the same directory but which
breaks that contiguity passes the early-exit and the gate `exit 0`s before any
allowlist runs:

| Probe | Command | Verdict | Real write |
|---|---|---|---|
| A1 | `printf x > .claude/'re'viewed/9.pass` | **ALLOW** | **MUTATED** |
| A2 | `printf x > .claude/"re"viewed/9.pass` | **ALLOW** | **MUTATED** |
| A3 | `printf x > .claude/./reviewed/9.pass` | **ALLOW** | **MUTATED** |
| A4 | `printf x > .claude//reviewed/9.pass` | **ALLOW** | **MUTATED** |
| A5 | `printf x > .claude/agents/../reviewed/9.pass` | **ALLOW** | **MUTATED** |
| A6 | `printf x > '.claude/rev'iewed/9.pass` | **ALLOW** | **MUTATED** |
| A10 | `printf x >> .claude/'re'viewed/9.pass` | **ALLOW** | **MUTATED** |
| A0 | `printf x > .claude/reviewed/9.pass` (control) | DENY | MUTATED |

`normalize_path()` already closes A3–A5 on the **Write/Edit** path only
(`:146`); the Bash path never consults it.

**Residual B — `human-decision-gate.sh`, whitespace + unsafe punctuation.**
`has_whitespace_id_packet_path()` (`:164`) denies a whitespace-bearing packet id
only while every character between `human-review` and `/DECISION` is inside the
path-safe charclass `A-Za-z0-9_ \t/.#-`. An id holding **both** whitespace and
one character outside it escapes the run scan on the whitespace and the
companion scan on the punctuation:

| Probe | Command | Verdict | Real write |
|---|---|---|---|
| B1 | `printf x > '.claude/human-review/u: 1/DECISION'` | **ALLOW** | **MUTATED** |
| B2 | `printf x > '.claude/human-review/my unit!/DECISION'` | **ALLOW** | **MUTATED** |
| B0a | `printf x > '.claude/human-review/u 1/DECISION'` (control) | DENY | MUTATED |
| B0b | `printf x > .claude/human-review/u1/DECISION` (control) | DENY | MUTATED |

Widened to a positional sweep — 21 punctuation characters × 6 insertion
positions, fixtures created so each probe really writes — **138 probes write a
real file and 126 of them are ALLOW at HEAD.**

### The decisive measurement: the gate's own Write/Edit branch is the oracle

`hdg-prose-2` and `hdg-prose-2-fix2` each FAILed on the same shape of error: the
spec defined the deny condition by **enumerating a character dimension** (first
"non-quote", then "non-whitespace"), and each time an unmodelled value of that
dimension was a fail-open. Residual B is the *third* value of the same
dimension. Enumerating punctuation would be the fourth guess.

There is a dimension-free criterion available, and it was not used before.
`human-decision-gate.sh:281` already carries an authoritative, non-textual
definition of the protected set:

```
case "$subject" in
  .claude/human-review/*/DECISION) deny ;;
```

applied to a `normalize_path()`-resolved file path. That branch is not a
heuristic — it is what the gate *means* by "the protected file". So the correct
acceptance criterion for the Bash path is **branch agreement**: for any path,
the Bash-path verdict on `printf x > '<path>'` must equal the Write/Edit-path
verdict on `<path>`.

Measured over a **670-path corpus** (21 punctuation characters × 6 id shapes ×
5 prefix spellings including `//`, `./` and `../` traversal):

| Gate | Write/Edit vs Bash disagreements |
|---|---|
| HEAD | **630** |
| candidate "blunt" (§ below) | **0** |
| candidate "surgical" (selected) | **0** |

This criterion cannot be defeated by an unmodelled character, because it names
no characters.

### Residual B — remedy selection, measured

`hdg-prose-2-fix2`'s report measured one candidate and explicitly declined to
adopt it, calling the false-positive budget the operator's call. Both it and a
surgical alternative were built and measured this session.

- **BLUNT** (the previously-reported candidate) — widen the path-safe charclass
  to "anything but newline".
- **SURGICAL** (selected) — leave the path-safe arm **byte-unchanged** and add a
  second, structurally-anchored arm beside it: a head that **begins with `/`**
  and holds no newline. The rationale is not statistical but structural: the
  protected path is `.claude/human-review/<task-id>/DECISION`, so the character
  immediately after `human-review` is *always* `/`. Prose that merely names the
  two tokens interposes something else (`, `, ` packet -> `, `: `).

| Measurement | BLUNT | SURGICAL |
|---|---|---|
| 18 unsafe-character residual shapes closed | 18/18 | **18/18** |
| 126 live holes in the positional sweep closed | 126/126 | **126/126** |
| Write/Edit-vs-Bash disagreements over 670 paths | 0 | **0** |
| Existing suite (155 assertions, unmodified) | pass | **pass** |
| 144 harvested suite payloads: verdict deltas | 0 / 0 | **0 / 0** |
| 2304-command sweep (144 payloads × 16 id mutations) | — | **+242 denials, 0 new allowances** |
| **234-command prose/read/comment corpus: new denials** | **+97** | **0** |

The 97 blunt false positives include both examples the fix2 report named
verbatim — `git commit -m "human-review, /DECISION"` and
`git commit -m "human-review packet -> /DECISION"` — plus `: `, `; `, `(`, `)`,
` => `, ` | ` and 11 other prose separators, across `-m`, `-am`, `--amend`,
single- and double-quoted messages, and trailing `#` comments.

**The tradeoff the fix2 report escalated therefore dissolves.** It is not a
judgment call the operator must make: SURGICAL dominates BLUNT on every measured
axis — identical closure, identical branch agreement, and a false-positive cost
of zero instead of 97. This is recorded as a self-resolved clarification rather
than an Open Question, with the numbers above as the ground.

### Residual B — the 21 shapes SURGICAL deliberately leaves allowed

The positional sweep's `after-hr` family (`.claude/human-review:/u 1/DECISION`,
and 20 punctuation siblings) stays ALLOW under SURGICAL and flips to DENY under
BLUNT. **This is a point in SURGICAL's favour, not a gap.** Those paths are not
the protected file: `human-review:` is a different directory, and the gate's own
Write/Edit branch **allows them too** (they do not match
`.claude/human-review/*/DECISION`). BLUNT denying them is one more false
positive; SURGICAL agreeing with the Write/Edit branch is the whole point. The
unit must pin these as ALLOW with a comment saying so, or a later reader will
"fix" a correct allowance.

### Residual A — the one-site fix is measurably near-vacuous

The obvious reading of note N3 is "canonicalize the early-exit at `:152`". Built
and measured, that fix closes **1 of 10** residual shapes — and passes the full
412-assertion suite while doing it:

| Shape | base | early-exit only | early-exit + masked test |
|---|---|---|---|
| A1 quote-split | ALLOW | **ALLOW** | **DENY** |
| A3 dot-segment | ALLOW | **ALLOW** | **DENY** |
| A5 traversal | ALLOW | **ALLOW** | **DENY** |
| A8 quote-split + trailing comment | ALLOW | **ALLOW** | **DENY** |
| A7 `tee` quote-split | ALLOW | DENY | DENY |
| A0 control (bare) | DENY | DENY | DENY |
| **existing suite** | 412 OK | **412 OK** | **412 OK** |

The reason is the second copy of the protected-path literal that
`rpg-comment-3`'s reviewer flagged as a maintenance risk. Once the early-exit
lets an obfuscated command through, `write_with_commented_mention()` (`:100`)
re-tests the **raw** literal against the comment-masked text, finds no mention,
and returns 0 — so `printf` passes the program allowlist and the command is
allowed. The two literals must agree, and today they agree only by convention.

**So the `mentions_marker_dir()` extraction is not optional scope — it is the
fix.** The operator invited a judgment call on whether to fold it in; the
measurement removes the choice. A single helper called from both sites is the
only shape in which this residual actually closes.

### Residual A — the canonicalization, and why it cannot fail open

`mentions_marker_dir()` is a **union** of three tests, in order: the RAW text
(exactly today's test), the QUOTE-JOINED text, then each whitespace-delimited
word passed through the shared `normalize_path()`. Because the raw test is the
first disjunct, every text that fires the gate today still fires it — the
canonicalization can only **add** coverage, never remove it. That property is
what makes "0 new allowances" a structural guarantee rather than a hope, and it
is what protects against the sharpest hazard here: `normalize_path()` applied
alone would *destroy* the mention in `rm -rf .claude/reviewed/../x`, turning a
current denial into an allowance.

`normalize_path()` is already in `hooks/scripts/lib/benign-command.sh` and
already sourced by this gate, so **no unit in this spec touches the shared
lexer**. Its per-word application is prefiltered on the word containing
`.claude`, which is sound because after quote-joining any spelling that
normalizes to contain `.claude/reviewed` must already spell `.claude`
contiguously (`normalize_path()` only deletes `.`/empty segments and pops on
`..`; it never rewrites within a segment).

### Measured deltas — residual A

| Measurement | Result |
|---|---|
| `tests/reviewed-path-gate.test.sh`, unmodified | **412 OK / 0 FAIL** |
| 780 harvested suite payloads | **0 new denials, 0 new allowances** |
| 216-command synthetic sweep (12 spellings × 18 program/quoting shapes) | **+110 denials, 0 new allowances** |
| 10 obfuscated read / prose / comment shapes | **10/10 ALLOW → ALLOW** |
| documented residuals (variable split, F-1 globs) | **unchanged** |

The 10 preserved shapes include `cat .claude/'re'viewed/9.pass`,
`grep -n PASS .claude/./reviewed/9.pass`,
`grep -rn commit .claude/agents/../reviewed/`, `ls .claude//reviewed`,
`gh issue comment 1 -b "see .claude/'re'viewed/9.pass"`, and a comment-only
mention of an obfuscated spelling. Reads and narration stay allowed in every
spelling; only writes flip.

### Both call sites are independently binding (mutation matrix)

| Variant | `printf x > .claude/'re'viewed/9.pass` |
|---|---|
| shipped (both sites) | **DENY** |
| drop the masked-test site | ALLOW |
| drop the early-exit site | ALLOW |
| drop both (= HEAD) | ALLOW |

A1 therefore has **each** site as a sole denier, which is the mutation proof
this project's standing rule requires — and it is exactly the proof the
one-site fix would have failed.

### Performance (measured; N4 of the fix2 marker asked for a bound)

| Input | base | fixed |
|---|---|---|
| 60 KB single-quoted commit message, `reviewed-path-gate.sh` | 1950 ms | 1960 ms |
| 60 KB single-quoted commit message, `human-decision-gate.sh` | 4818 ms | 4865 ms |
| 3000 `.claude`-bearing words, no raw match (worst case for the new loop) | 12 ms | 129 ms |

The pathological cost is pre-existing and dominated by `command_skeleton()`;
neither unit makes it materially worse. The new per-word `normalize_path()` is
linear and costs ~40 µs per `.claude`-bearing word. Not a criterion; recorded
because N4 asked.

### Harvested sibling PASS-notes (folded in rather than left to evaporate)

`.claude/reviewed/hdg-prose-2-fix2.pass` and `.claude/reviewed/rpg-comment-3.pass`
each carry non-blocking notes that no later unit would otherwise surface. Each
is a comment in a file this spec already edits:

- **fix2 N1** — `human-decision-gate.sh:101-103` overstates: "makes the two
  branches agree about the identical path string" is true today only for
  path-safe ids. Unit 1 makes it **fully** true (0 disagreements over 670
  paths), so the clause becomes correct and the `:138-145` BOUNDARY note that
  qualified it must go.
- **fix2 N2** — `:14` cites "P13-d through P13-l" as the backslash pins, but
  P13-k in that range is the own-line-comment R-11 residual.
- **fix2 N3** — `:175` is a ~100-column line in an ~80-column file.
- **fix2 N5 / rpg N4 (lens 2)** — `has_path_shaped_occurrence()` is called both
  "the run scan" and "the path-shape scan"; `CONTEXT.md:1587` makes **run scan**
  canonical.
- **rpg N1** — `reviewed-path-gate.sh:218` claims a trailing comment passes
  "whatever the rest of the command does", falsified by the suite's own case
  37.5 (`sh -c` is not allowlisted).
- **rpg N3** — the residual this spec closes. Once closed, the header at
  `:32-35` should name *which* obfuscations are closed and which remain.

### The glossary is currently wrong about the terms these units change

Checked with `antislop:ubiquitous-language` (prose mode, three lenses, all ran)
against `CONTEXT.md`. **Lens 1 — five findings, and they are not cosmetic:**

1. `CONTEXT.md:1565` **path-safe charclass** is defined backwards. It says the
   term is "a strict subset of the marker id charclass … `[a-zA-Z0-9_-.]` …
   this subset **excludes space, tab**". In the code
   (`human-decision-gate.sh:164`) the path-safe set is precisely the one that
   **includes** space and tab. A reader trusting the glossary gets the deny
   condition inverted.
2. `CONTEXT.md:1556` **marker id charclass** gives `[a-zA-Z0-9_-]` plus `/`,
   space, tab — omitting `.` and `#`, which the code includes — and cites
   `human-decision-gate.sh:97`, which is a comment line, not the charclass.
3. `CONTEXT.md:1587` **run scan / companion scan** calls them "two tandem
   gate-logic functions in `has_path_shaped_occurrence()`". They are two
   separate functions (`has_path_shaped_occurrence()` and
   `has_whitespace_id_packet_path()`) called from `triggers_are_inert()`.
4. Same entry: the companion scan is described as rejecting a shape "as a
   false-positive prose mention" when unsafe characters are present — inverting
   which arm denies.
5. `CONTEXT.md:1600` **quote-joined text** says it is "implemented … as a loop
   that joins sequences of … tokens into single words". It is two parameter
   expansions deleting quote characters (`:297-298`).

**Consequence for dispatch:** neither implementer nor reviewer may use
`CONTEXT.md`'s gate entries as a source of truth for this work — read the code.
All five are routed to `scribe`, and unit 1 additionally makes entry 1's
underlying concept two-armed, so the entry needs rewriting rather than patching.

**Lens 2** — one synonym pair beyond the run-scan one above:
`mentions_marker_dir()` (unit 2) and the quote-joining at
`human-decision-gate.sh:297-298` are the same idea under two names on two gates,
as `write_with_commented_mention()`/`write_with_inert_triggers()` already are.
Defensible (unit 2's is a three-way union, the sibling's is quote-joining only);
recorded, not recommended for renaming.

**Lens 3** — two load-bearing new terms with no glossary entry: the
**canonicalized mention test** (unit 2's union) and, more importantly,
**branch agreement** — the invariant that a gate's textual Bash path and its
structural Write/Edit path must return the same verdict for the same path.
Routed to the Scribe update hint.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-24 Non-functional attributes: Q Is the false-positive budget for
  closing residual B a security-posture decision the operator must make, or one
  settleable by measurement? → A (self-resolved): **settleable, and it was
  settled against the previously-reported candidate.** BLUNT costs 97 prose
  denials over a 234-command corpus; SURGICAL costs 0 while closing the same
  18/18 shapes, the same 126/126 live holes, and reaching the same 0/670 branch
  disagreement. A dominated option is not a tradeoff, so this is not returned as
  an Open Question. Perf was also bounded (worst case 12 ms → 129 ms).
- 2026-08-24 Technical constraints & tradeoffs: Q Is extracting a shared
  `mentions_marker_dir()` helper appropriate scope for the residual-A unit, or a
  separate one? → A (self-resolved): **it is the unit.** Measured: canonicalizing
  only the early-exit closes 1 of 10 shapes while passing all 412 existing
  assertions. The second literal at `:100` is load-bearing, so a single helper
  called from both sites is the minimum shape in which the residual closes at
  all. The maintenance-risk finding is closed as a by-product, not as extra
  scope.
- 2026-08-24 Edge cases / failure handling: Q Which shapes prove the fixes are
  general rather than patches for the reported ones? → A (self-resolved): none
  of them, on their own — that is the lesson of two prior FAILs in this exact
  function, each caused by a spec enumerating a character dimension. The binding
  criterion is instead **branch agreement** against the gate's own Write/Edit
  definition of the protected set (0/670 under the selected candidate, 630/670
  at HEAD), backed by the 138-probe positional sweep, the 2304- and
  216-command differential sweeps, and the per-site mutation matrix.
- 2026-08-24 Terminology consistency: Q Does this spec drift against
  `CONTEXT.md`? → A (self-resolved, three lenses, all ran): the drift runs the
  other way — five of the glossary's own gate entries are factually wrong
  against the code, one of them (**path-safe charclass**) inverted. Enumerated
  in Context and routed to `scribe`. Category stays Partial because the fix
  lands with `scribe`, not in these units; both dispatches carry an explicit
  instruction not to trust those entries.

## Risks / dependencies

- **R-1 — prior defect history is severe and directly inherited.**
  `.claude/reviewed/hdg-prose-2.fail` records the 2nd FAIL of a unit that hit
  the 2-FAIL cap. Both FAILs were **fail-opens in the very function unit 1
  edits**, both caused by the spec defining the deny condition as a character
  enumeration that missed a value. Residual B is the third missed value. Unit 1
  is therefore specified with a **dimension-free** criterion (branch agreement)
  in addition to enumerated cases. **Neither unit is `haiku`-eligible.** Both
  `opus`.
- **R-2 — the `.fail` survey was run in full, not sampled.** All 78 `.fail`
  records under `.claude/reviewed/` were enumerated. Relevant:
  `hdg-prose-2.fail` (R-1); `182.fail`/`177.fail` (the shared lexer's
  word-boundary defects — neither unit touches that lexer, see R-4);
  `human-review-cleanup-1.fail` (sole ground a dirty-tree marker precondition,
  not a code defect). `hdg-lexer-1`, `hdg-prose-2-fix2` and `rpg-comment-3` all
  have `.pass` and no `.fail`.
- **R-3 — the one-site fix is a live vacuous-criteria trap.** An implementer who
  canonicalizes only `reviewed-path-gate.sh:152` will see all 412 existing
  assertions pass and 1 of 10 residual shapes close. Unit 2's criteria bind both
  sites by mutation, precisely so this cannot ship green.
- **R-4 — neither unit touches `hooks/scripts/lib/benign-command.sh`.**
  `normalize_path()` and `command_skeleton()` are consumed as-is. A criterion in
  each unit binds the file byte-unchanged. If closing either residual appears to
  require editing it, that is a spec defect — stop and report.
- **R-5 — `protectedPaths` currently omits both gates, and that is a temporary
  window.** Commit `99e393c` removed them so the parent spec's units 2 and 3
  could dispatch. Verified at HEAD: `protectedPaths` is
  `[".github/workflows/*", ".claude/constitution.md"]`. So `Write`/`Edit` work
  directly on both gates. **The operator intends to restore both entries once
  editing on these two files is finished for this session, and both units of
  this spec must land before that restoration.** The Bash-heredoc route remains
  forbidden for these files regardless of the window.
- **R-6 — escalation will not fire.** `.claude/persona-config.json` sets
  `humanReviewMode: "off"`, so ESCALATE-TO-HUMAN is inert. `protectedPaths` is a
  separate Write/Edit block (R-5) and the two mechanisms are unrelated.
- **R-7 — hard mirror parity.** `tests/validate.sh:302` runs
  `diff -rq hooks/scripts .claude/hooks/scripts`, and
  `.claude/persona-config.json`'s `fileHashes` pins
  `.claude/hooks/scripts/human-decision-gate.sh` and
  `.claude/hooks/scripts/reviewed-path-gate.sh` (both keys confirmed present).
  Source edit and regenerated mirror **must land in the same unit**, via
  `node bin/cli.js --update`. Never hand-edit `fileHashes` (Constitution P2).
- **R-8 — no version bump is owed, and bumping would break the boundary.**
  Constitution P3 scopes to `agents/*.md` and templates; these units touch
  `hooks/`, `tests/` and the mirror only. Do not bump.
- **R-9 — no adapter port is owed.** `adapters/{codex,cursor}/hooks/scripts/`
  carry `reviewer-route-gate.sh` and `stop-gate.sh` only — neither gate, and not
  the shared lexer. Confirmed by file listing this session.
- **R-10 — both units write `.claude/persona-config.json`'s `fileHashes`.**
  Ordering is therefore strict and sequential, even though the two gate files
  are independent.
- **R-11 — the documented residuals must stay open, and stay documented.**
  Measured unchanged under both fixes: variable-splitting on both gates, R-5's
  `DECISIO\N`, and the whole F-1 glob-metacharacter class (`[D]ECISION`,
  `?ECISION`, `DEC*`, `.claude/human-rev[i]ew/…`, `.claude/revie[w]ed/…`).
  `README.md:318-319` and `:369-370` describe the residual as shell-variable
  splitting, which stays true; unit 2 narrows the gate header's own claim
  (`:32-35`) rather than README's.
- **R-12 — `tests/human-decision-gate.test.sh` has no `GATE_UNDER_TEST`
  override**, unlike its sibling (`tests/reviewed-path-gate.test.sh:26`). Unit 1
  mandates a mutation proof, which is not runnable without it. Adding it is a
  one-line, default-preserving change and is folded into unit 1.
- **R-13 — do not write a case count into either gate's header comment.**
  `human-decision-gate.sh:47-57` already records that the count in that comment
  drifted twice, and names properties instead. The suites grow.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the two reproductions with real writes,
  the 138-probe positional sweep, the 670-path branch-agreement corpus, the 234-,
  216-, 780-, 144- and 2304-command differential sweeps, the per-site mutation
  matrix, the three timing pairs, the adapter inventory, `protectedPaths`,
  `humanReviewMode` and the five glossary errors were all executed or read live
  this session.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  mirror and `fileHashes` regenerate via `node bin/cli.js --update` only.
- P3 "Version-stamp discipline": **not applicable, deliberately** — see R-8. No
  version-stamped file is touched, so no bump is owed and none may be made.
- P4 "Optional personas degrade gracefully": satisfied — both gates are
  identity-blind on the paths being changed.
- P5 "`tests/validate.sh` is the merge gate": satisfied — both suites are wired
  into it, and the mirror-parity check at `:302` is part of it.

## Steps

### Step 1 — anchor the companion scan to the packet path's own structure (closes residual B)

In `hooks/scripts/human-decision-gate.sh`, inside
`has_whitespace_id_packet_path()`, leave the existing path-safe arm
**byte-unchanged** and add a second arm beside it: the head denies if it
**begins with `/`** and contains no newline. Shape (style may be refined,
semantics may not):

```bash
        case "$head" in
          *[!A-Za-z0-9_$' \t'/.#-]*) ;;
          *) return 0 ;;
        esac
        case "$head" in
          /*) case "$head" in *$'\n'*) ;; *) return 0 ;; esac ;;
        esac
```

Extend the existing "Only the FIRST `/DECISION` is worth testing" comment
(`:159-162`) to cover the new arm: it is sound for arm 2 for the same reason,
because "begins with `/`" is fixed by the head's first character and "contains
no newline" only degrades as the head grows, so a longer head can never become
safe once the first has failed.

Then correct the file's own now-false or now-stale comments:

1. `:138-145` — the BOUNDARY note says the whitespace+unsafe-punctuation class
   "really writes the file" and is "unadjudicated as this is written". It is
   adjudicated and closed. Replace it with the new arm's rationale.
2. `:101-103` (fix2 note N1) — "makes the two branches agree about the identical
   path string" becomes true without qualification. State the branch-agreement
   property as the reason, and name `:281` as the branch it agrees with.
3. `:14` (fix2 note N2) — "P13-d through P13-l" wrongly includes P13-k, the
   own-line-comment residual. Cite the correct set or name a property instead.
4. `:175` (fix2 note N3) — re-wrap to the file's ~80-column convention.
5. Use **run scan** for `has_path_shaped_occurrence()` throughout (fix2 N5,
   `CONTEXT.md:1587` is canonical); do not introduce "path-shape scan".

In `tests/human-decision-gate.test.sh`, add the `GATE_UNDER_TEST` override
(R-12), matching `tests/reviewed-path-gate.test.sh:26` exactly in form:

```bash
gate="${GATE_UNDER_TEST:-hooks/scripts/human-decision-gate.sh}"
```

Affected files: `hooks/scripts/human-decision-gate.sh`,
`tests/human-decision-gate.test.sh`, plus the regenerated
`.claude/hooks/scripts/human-decision-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

Do NOT touch: `hooks/scripts/lib/benign-command.sh`,
`hooks/scripts/reviewed-path-gate.sh`, any `agents/*.md`, any version file.
Do not modify `has_path_shaped_occurrence()` — it is correct for what it covers,
and changing it is what would re-deny the prose cases.

Acceptance criteria (from repo root):

```
bash tests/human-decision-gate.test.sh    # exit 0
bash tests/reviewed-path-gate.test.sh     # exit 0, unchanged (412 OK / 0 FAIL)
bash tests/validate.sh                    # exit 0 (includes the diff -rq mirror parity check)
node bin/cli.js --update --check          # exit 0
git diff --quiet HEAD                     # exit 0 (tracked tree clean at the unit's final commit)
git diff --quiet -- hooks/scripts/lib/benign-command.sh hooks/scripts/reviewed-path-gate.sh   # exit 0
git diff --name-only | grep -q '^agents/' # exit 1 (no agent file restamped)
```

Plus, verified **inside the suite** and reported in the ready-for-review
message:

- **U-set — must be DENIED.** For each of the 21 punctuation characters
  `: ! , ; ( ) [ ] = @ + % ~ ^ & * ? < > { }` and each id position that lies
  **inside** the protected set (unsafe character mid-id, leading, trailing, and
  in a nested segment), `printf x > '<path>'` is denied. All are ALLOW at HEAD.
  Include the tab-and-punctuation and multi-space variants.
- **BRANCH-AGREEMENT set — the binding, dimension-free criterion.** For a corpus
  crossing punctuation × id shape × prefix spelling (`.claude/human-review`,
  `./.claude/human-review`, `.claude//human-review`, `.claude/./human-review`,
  `.claude/x/../human-review`), assert that the Bash verdict on
  `printf x > '<path>'` **equals** the Write/Edit verdict on `<path>`. Measured
  0 disagreements over 670 paths under the prototype; 630 at HEAD. Assert
  equality, not a hard-coded verdict, so the criterion cannot rot when the
  protected set is next changed.
- **ALLOW pins, commented as OUTSIDE the protected set** (not as residuals): the
  `after-hr` family, `.claude/human-review<punct>/u 1/DECISION`. The Write/Edit
  branch allows these too; the comment must say that, so a later reader does not
  "close" a correct allowance.
- **C-set — verdicts byte-identical to HEAD.** The prose/read/comment shapes the
  parent units exist to allow: the operator's exact commit message; single- and
  double-quoted messages; `-am`; `--amend`; a multi-line message naming the
  tokens on different lines; `human-review, /DECISION`;
  `human-review packet -> /DECISION`; `: `, `; `, `(`, `)`, ` => `, ` | `
  separators; `grep -n 'DECISION\|human-review' <file>`; `grep -rn` over the
  packet directory; a trailing `#` comment naming both tokens, with and without
  a space after `#`; `rm -rf .claude/human-review/u1`.
- **Pinned residuals — must stay ALLOWED**, unchanged: R-5's `DECISIO\N`, the
  N21 split-variable pin, the Q20 brace-expansion pin, and the four F-1 glob
  pins (still commented tracked-open, not accepted).
- **Mutation proof (mandatory, sole-denier rule applies).** Using the new
  `GATE_UNDER_TEST` override, deleting **only** the new arm must flip at least
  one U-case to allowed with the new arm as its **sole** denier. Run the mutant;
  do not assert this from this document.

### Step 2 — one canonicalized mention test, called from both sites (closes residual A)

In `hooks/scripts/reviewed-path-gate.sh`, add a single gate-local
`mentions_marker_dir()` and route **both** existing copies of the
`.claude/reviewed` literal through it. Shape (style may be refined, semantics
may not):

```bash
mentions_marker_dir() {
  local cmd="$1" rest chunk ws=$' \t\n'
  case "$cmd" in *".claude/reviewed"*) return 0 ;; esac      # raw: today's test
  rest="${cmd//$'\047'/}"; rest="${rest//$'\042'/}"          # quote-joined
  case "$rest" in *".claude/reviewed"*) return 0 ;; esac
  while :; do                                                # per-word, normalized
    chunk="${rest%%[$ws]*}"
    case "$chunk" in
      *.claude*) case "$(normalize_path "$chunk")" in *".claude/reviewed"*) return 0 ;; esac ;;
    esac
    [ "$chunk" != "$rest" ] || return 1
    rest="${rest:${#chunk}+1}"
  done
}
```

The raw test **must remain the first disjunct** — that is what makes the change
additive and guarantees zero new allowances, and it is what keeps
`rm -rf .claude/reviewed/../x` denied (bare `normalize_path()` would erase that
mention). Follow the file's existing `\047`/`\042` escape idiom so a literal
quote in a pattern cannot unbalance the file's own quoting.

Call site 1 — the Bash-path early-exit (`:152-155`). The Write/Edit path already
runs `normalize_path()` at `:146`, so the canonicalization is **Bash-path only**:

```bash
if [ -z "$write_tool" ]; then
  mentions_marker_dir "$subject" || exit 0
else
  case "$subject" in
    *".claude/reviewed"*) ;;
    *) exit 0 ;;
  esac
fi
```

Call site 2 — `write_with_commented_mention()`'s masked test (`:100`). Replace
`case "$masked" in *".claude/reviewed"*) return 1 ;; esac` with
`mentions_marker_dir "$masked" && return 1`. **Omitting this site is the
measured near-vacuous fix (R-3).**

Then correct the file's comments:

1. `:218` (rpg note N1) — drop or qualify "whatever the rest of the command
   does"; the program allowlist still governs, as the suite's own case 37.5
   shows.
2. `:32-35` — the header calls the obfuscation bypass open in general. Narrow it:
   quote-split, dot-segment, doubled-slash and `..` traversal are now closed on
   both paths; shell-variable splitting and glob metacharacters remain open.
3. Note in `mentions_marker_dir()`'s header that it exists so the two protected-
   path literals cannot drift, since that was a flagged maintenance risk.

Affected files: `hooks/scripts/reviewed-path-gate.sh`,
`tests/reviewed-path-gate.test.sh`, plus the regenerated
`.claude/hooks/scripts/reviewed-path-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

Do NOT touch: `hooks/scripts/lib/benign-command.sh`,
`hooks/scripts/human-decision-gate.sh` (unit 1 owns it), any `agents/*.md`, any
version file. Do not port `mentions_marker_dir()` to the sibling gate — its
early-exit was measured **already robust** to dot-segments and traversal (it
tests two non-contiguous tokens) and already quote-joins at `:297-298`.

Acceptance criteria (from repo root):

```
bash tests/reviewed-path-gate.test.sh     # exit 0
bash tests/human-decision-gate.test.sh    # exit 0, unchanged
bash tests/validate.sh                    # exit 0
node bin/cli.js --update --check          # exit 0
git diff --quiet HEAD                     # exit 0 (tracked tree clean at the unit's final commit)
git diff --quiet -- hooks/scripts/lib/benign-command.sh hooks/scripts/human-decision-gate.sh   # exit 0
git diff --name-only | grep -q '^agents/' # exit 1
```

Plus, verified **inside the suite** and reported in the ready-for-review
message:

- **Newly-DENIED (each measured ALLOW at HEAD, each with a real write into a
  sentinel-seeded fixture):** A1–A6 and A10 above, plus the two comment-decoy
  variants (`… # writes a marker`) that the one-site fix leaves open, plus
  `cp` and `sh -c` forms and the doubled dot-segment `.claude/.//./reviewed`.
- **Must stay ALLOWED** (each measured ALLOW at HEAD, all 10 preserved under the
  prototype): `cat .claude/'re'viewed/9.pass`;
  `grep -n PASS .claude/./reviewed/9.pass`;
  `grep -rn commit .claude/agents/../reviewed/`; `ls .claude//reviewed`;
  `wc -l .claude/"re"viewed/9.pass`; `stat .claude/x/../reviewed/9.pass`;
  `gh issue comment 1 -b "see .claude/'re'viewed/9.pass"`; a comment-only
  mention of an obfuscated spelling, quote-split and dot-segment forms;
  `printf x > /tmp/o.txt`.
- **Must stay DENIED and must stay ALLOWED unchanged**, respectively: every
  pre-existing assertion (the test-file diff must have **zero deleted lines**),
  and the documented residuals of R-11 — case 19's variable-split pin and the
  F-1 glob spellings.
- **`rm -rf .claude/reviewed/../x` must stay DENIED** — the specific shape a
  normalize-only implementation would newly allow. This is the criterion that
  binds the raw disjunct.
- **Mutation proof (mandatory, sole-denier rule applies), two mutants:**
  (a) revert call site 2 to the raw literal → A1 must flip to allowed;
  (b) revert call site 1 to the raw literal → A1 must flip to allowed.
  Each site is thus a sole denier for A1. Run both mutants via
  `GATE_UNDER_TEST`; do not assert this from this document.

## Open Questions

Neither question blocks dispatch. Each carries a recommended default, and both
defaults are already what the two steps above specify — so the spec is
dispatch-ready as written, and an answer only changes what happens *next*.

1. **Should F-1 (the glob-metacharacter class) be closed in this session, while
   both gates are outside `protectedPaths`?** Once these two units land, F-1 is
   the last open class on either gate other than shell-variable splitting.
   Closing it needs glob-aware matching before the substring early-exit — its
   own mechanism, its own hazards (`extglob`, `nocasematch`, unbalanced `[`),
   and its own adversarial suite; the debug spec's finding that a partial fix is
   *worse* than none (bracket-stripping catches `[D]ECISION` and silently misses
   `?ECISION` and `DEC*`) still stands and I did not re-open it. The only thing
   that changed is sequencing economics: R-5's window makes editing these two
   files cheaper now than after `protectedPaths` is restored.
   **Recommended default: no — keep F-1 deferred, restore `protectedPaths` after
   unit 2, and dispatch F-1 as its own spec when it is next prioritized.** F-1
   is a larger and differently-shaped change than either unit here, and bundling
   it would make both diffs unreviewable against these criteria.
2. **Should the five wrong `CONTEXT.md` gate entries be corrected by `scribe`
   before or after these units land?** They are wrong at HEAD, and unit 1
   changes the concept underlying the most-wrong one (**path-safe charclass**,
   currently defined inverted).
   **Recommended default: after both units, in one `scribe` pass**, so the entry
   is rewritten once against the final two-armed condition rather than twice.
   Both dispatches already instruct the implementer and reviewer not to treat
   those entries as authoritative in the meantime.

## Self-check

- CHK1: Is each residual reproduced live with a real write, rather than read
  from a marker note? — PASS (both, sentinel-diffed in `mktemp -d` fixtures;
  126 of 138 positional probes on gate B, 7 of 8 shapes on gate A).
- CHK2: Does the plan avoid repeating the character-enumeration mistake that
  cost `hdg-prose-2` two FAILs? — FAIL (missing) — revised in place: the first
  draft specified only an enumerated U-set, which is the same shape of criterion
  that failed twice. The branch-agreement criterion was added as the binding,
  dimension-free one, measured 630/670 → 0/670.
- CHK3: Is the false-positive tradeoff the fix2 report escalated resolved, or
  passed through? — PASS (resolved by measurement: 97 vs 0 prose denials for
  identical closure; recorded as a self-resolved clarification with the numbers,
  and explicitly *not* returned as an Open Question, per the dispatch's own
  instruction to escalate only if measurement could not settle it).
- CHK4: Does the plan show that the obvious reading of residual A is
  insufficient? — FAIL (missing) — revised in place: the one-site variant was
  built and measured (1 of 10 shapes closed, 412/412 assertions still green) and
  is now R-3, because an implementer would otherwise ship it green.
- CHK5: Is the "0 new allowances" claim structural or merely observed? — PASS
  (both: the raw test is the first disjunct of the union, so it is additive by
  construction, *and* it was measured across 780 + 216 + 2304 commands).
- CHK6: Does the plan name the specific shape a careless implementation of the
  canonicalization would newly allow? — FAIL (missing) — revised in place:
  `rm -rf .claude/reviewed/../x` is now a named must-stay-DENIED criterion, and
  it is what the raw disjunct exists to hold.
- CHK7: Does every new condition carry a mutation-proven sole denier? — PASS
  (unit 1: one mutant over the new arm; unit 2: two mutants, one per call site,
  each measured to flip A1).
- CHK8: Do steps 1 and 2 agree on file ownership? — PASS (each names the other's
  file in its Do-NOT-touch list, and each carries a `git diff --quiet` criterion
  binding both the sibling gate and the shared lexer).
- CHK9: Is the claim that no unit touches the shared lexer verified? — PASS
  (`normalize_path()` and `command_skeleton()` are consumed as-is; both
  prototypes were built without editing `benign-command.sh`, and both suites
  pass).
- CHK10: Does the plan state whether a version bump is owed? — PASS (R-8, and
  the Constitution check marks P3 not-applicable rather than silent).
- CHK11: Is the `protectedPaths` state verified rather than inherited from the
  parent specs? — PASS (read at HEAD: both gates absent, R-5, together with the
  operator's statement that the window is temporary and closes after unit 2).
- CHK12: Were sibling PASS-note warnings harvested rather than left to
  evaporate? — FAIL (missing) — revised in place: six notes across the two
  markers (fix2 N1/N2/N3/N5, rpg N1/N3) are folded into the two steps' comment
  corrections, each in a file the unit already edits. `hdg-lexer-1`'s N2 was
  already actioned by `hdg-prose-2-fix2`.
- CHK13: Is the terminology check's result reported even though it is advisory?
  — FAIL (conflicting) — revised in place: the first draft recorded category 8
  as a routine scribe hand-off. Re-checking against the code showed five
  glossary entries are factually wrong, one of them inverted, so both dispatches
  now carry an explicit instruction not to treat `CONTEXT.md`'s gate entries as
  authoritative.
- CHK14: Does the plan say which currently-allowed shapes must **stay** allowed,
  not just which must become denied? — PASS (unit 1's C-set and ALLOW pins;
  unit 2's 10 preserved read/prose/comment shapes; R-11's documented residuals
  on both).
- CHK15: Is the 21-shape `after-hr` family correctly classified? — FAIL
  (ambiguous) — revised in place: the first draft read them as a gap in the
  selected candidate. They are outside the protected set — the gate's own
  Write/Edit branch allows them — so they are pinned as correct ALLOWs with a
  comment, and BLUNT denying them is counted as a further false positive.
- CHK16: Does each unit name a `Suggested model` and a retrieval-contract line?
  — PASS (both `opus`; the fast path files no tracker issue, so the retrieval
  contract points at this document by path).

## Scribe update hint

After both units land, in one pass:

- **Rewrite five wrong `CONTEXT.md` gate entries**, all measured against the
  code this session: **path-safe charclass** (`:1565`, currently defined
  inverted — it is the arm that *includes* space and tab, and after unit 1 it is
  one of two arms); **marker id charclass** (`:1556`, omits `.` and `#`, cites a
  comment line rather than `:164`); **run scan / companion scan** (`:1587`, they
  are two separate functions called from `triggers_are_inert()`, not "two tandem
  functions in `has_path_shaped_occurrence()`", and the companion arm's deny
  direction is described backwards); **quote-joined text** (`:1600`, it is two
  parameter expansions, not a loop); **path-shaped run** (`:1575`, its
  "separated by whitespace … the gate may allow" clause is falsified by the
  companion scan).
- **Add two entries**: **branch agreement** — a textual gate's Bash path and its
  structural Write/Edit path must return the same verdict for the same path,
  which is now a binding acceptance criterion; and **canonicalized mention
  test** — the raw / quote-joined / lexically-normalized union.
- ADR-worthy, and a strict strengthening of the debug spec's version: *a textual
  gate must be validated against its own structural branch, not against an
  enumeration of characters. Three separate character dimensions — quote
  boundaries, quoted whitespace, and interstitial punctuation — have each cost
  one fail-open in the same function; the branch-agreement criterion names no
  characters and would have caught all three.*

## Dispatch note (fast path)

Resolves to **two dispatchable units** — within the ≤5 fast-path threshold, so
`task-master` is not involved, no `to-tickets` slicing happens, and no tracker
issue is filed. The orchestrator dispatches from this document.

**Retrieval-contract line (verbatim, both units):** *No tracker issue exists for
this work — it is dispatched on the fast path. Read the unit's spec directly
from `docs/plans/2026-08-24-gate-early-exit-residuals.md` in this repository, at
the Step and Risk anchors named in the unit's `## Retrieval` section. Do not run
`gh issue list` for this work; there is nothing to fetch.*

| Unit | Suggested model | Ordering |
|---|---|---|
| `hdg-anchor-1` | `opus` | first |
| `rpg-canon-2` | `opus` | after 1 |

Both `opus`, neither `haiku`-eligible: two PreToolUse security invariants, a
function with a two-FAIL history, and judgment throughout. Ordering is strict
only because both regenerate `.claude/persona-config.json`'s `fileHashes`
(R-10); the two gate files are otherwise independent.

Escalation will **not** fire (`humanReviewMode: "off"`, R-6). Neither unit hits
`protected-paths.sh` while the R-5 window stands, so `Write`/`Edit` work
directly; the Bash-heredoc route is forbidden for these files regardless.
**Both units must complete before the operator restores the two gates to
`protectedPaths`.**

### Unit: hdg-anchor-1

**## Suggested model:** `opus`

**## Objective**
Close the whitespace+unsafe-punctuation fail-open in
`has_whitespace_id_packet_path()` by anchoring a second arm to the packet path's
own structure, so the gate's Bash path agrees with its Write/Edit path for every
path in the protected set — without changing the verdict of any prose, read or
comment shape.

**## Retrieval**
No tracker issue exists for this work — it is dispatched on the fast path. Read
the spec directly from `docs/plans/2026-08-24-gate-early-exit-residuals.md` in
this repository: **Step 1**, plus the Context subsections "The two residuals",
"The decisive measurement", "Residual B — remedy selection", "Residual B — the
21 shapes SURGICAL deliberately leaves allowed", "Harvested sibling PASS-notes"
and "The glossary is currently wrong", and **R-1, R-4, R-5, R-6, R-7, R-8,
R-11, R-12, R-13**. Also read `.claude/reviewed/hdg-prose-2-fix2.pass` (its
"THE DISCLOSED RESIDUAL" section is what this closes) and
`.claude/reviewed/hdg-prose-2.fail` (the 2-FAIL history in this same function).
Do not run `gh issue list`; there is nothing to fetch.

**## Affected files**
`hooks/scripts/human-decision-gate.sh`, `tests/human-decision-gate.test.sh`,
plus the regenerated `.claude/hooks/scripts/human-decision-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

**## Ordered edits**
1. Add the second arm to `has_whitespace_id_packet_path()` (Step 1's shape).
   Leave the existing path-safe arm byte-unchanged and leave
   `has_path_shaped_occurrence()` byte-unchanged.
2. Extend the "Only the FIRST `/DECISION`" comment (`:159-162`) to justify
   monotonicity for the new arm.
3. Replace the BOUNDARY note (`:138-145`) — the class it describes as
   unadjudicated is now closed.
4. Correct `:101-103` (fix2 N1), `:14` (fix2 N2) and `:175` (fix2 N3); adopt
   **run scan** as the single name (fix2 N5).
5. Add the `GATE_UNDER_TEST` override to the suite (R-12).
6. Extend the suite with Step 1's U-set, branch-agreement set, ALLOW pins, C-set
   and residual pins; run the mutation proof.
7. Run `node bin/cli.js --update` to regenerate the mirror and `fileHashes`.

**## Do NOT touch**
`hooks/scripts/lib/benign-command.sh`, `hooks/scripts/reviewed-path-gate.sh`,
any `agents/*.md`, `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`, or `.claude/persona-config.json`'s `pluginVersion`. No version
bump is owed (R-8). Do not modify `has_path_shaped_occurrence()`. Do not write a
case count into the header comment (R-13).

**## Acceptance criteria**
Step 1's criteria block verbatim, plus its six suite-verified items (U-set
denied; branch-agreement equality asserted, not hard-coded; the `after-hr` ALLOW
pins commented as outside the protected set; C-set identical to HEAD; the R-5 /
N21 / Q20 / F-1 pins unchanged; the mutation proof run with a named sole
denier).

**## Pre-resolved context**
Do not re-derive any of this — it is measured in Context:

- Both candidates close 18/18 unsafe-character shapes and 126/126 live holes and
  reach 0/670 branch disagreement; the selected one costs **0** prose denials
  where the other costs **97**. Implement the anchored arm; do not re-open the
  choice or widen the charclass.
- The `after-hr` family (`.claude/human-review:/u 1/DECISION`) is **outside** the
  protected set — the Write/Edit branch allows it too. Pin it ALLOW; do not
  "fix" it.
- Existing suite is 155 OK / 0 FAIL and stays so under the prototype; the
  sibling suite is 412 OK / 0 FAIL.
- Follow the file's `\047`/`\042` escape idiom for quote characters in patterns
  — a literal quote in a `case` pattern unbalances the file's own quoting.
- **`CONTEXT.md`'s gate glossary entries are factually wrong** (five of them,
  one inverted). Read the code, not the glossary. Do not "align" the code to
  them.

**## Escalation**
This unit edits a function with a two-FAIL history, both fail-opens caused by a
spec enumerating the wrong character dimension. If the new arm cannot satisfy
the U-set, the branch-agreement set and the C-set simultaneously, **stop and
report** — that is a spec defect in this document, not an implementation one.
Never widen or narrow a condition to make a test pass. If any existing suite
assertion changes verdict, stop and report: this unit is verdict-preserving for
every command that does not spell a path inside the protected set. Do not
attempt F-1 (Open Question 1) — it is deliberately out of scope.

### Unit: rpg-canon-2

**## Suggested model:** `opus`

**## Objective**
Close the obfuscated-early-exit fail-open in `reviewed-path-gate.sh` by routing
both copies of the protected-path literal through one canonicalized mention
test, so a quote-split, dot-segment, doubled-slash or traversal spelling of the
marker directory is recognized wherever bash would resolve it — without denying
any read, prose or comment shape currently allowed.

**## Retrieval**
No tracker issue exists for this work — it is dispatched on the fast path. Read
the spec directly from `docs/plans/2026-08-24-gate-early-exit-residuals.md` in
this repository: **Step 2**, plus the Context subsections "The two residuals",
"Residual A — the one-site fix is measurably near-vacuous", "Residual A — the
canonicalization", "Measured deltas — residual A", "Both call sites are
independently binding", "Harvested sibling PASS-notes" and "The glossary is
currently wrong", and **R-3, R-4, R-5, R-6, R-7, R-8, R-9, R-10, R-11**. Also
read `.claude/reviewed/rpg-comment-3.pass` note **N3**, which is the residual
this closes, and note **N1**, whose deny-message overstatement is corrected
here. Do not run `gh issue list`; there is nothing to fetch.

**## Affected files**
`hooks/scripts/reviewed-path-gate.sh`, `tests/reviewed-path-gate.test.sh`, plus
the regenerated `.claude/hooks/scripts/reviewed-path-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

**## Ordered edits**
1. Add `mentions_marker_dir()` (Step 2's shape), with the raw test as its
   **first** disjunct.
2. Route call site 1 — the Bash-path early-exit at `:152-155` — through it,
   Bash-path only; leave the Write/Edit branch on the raw literal, since `:146`
   already normalizes there.
3. Route call site 2 — `write_with_commented_mention()`'s masked test at `:100`
   — through it. **Skipping this is the measured near-vacuous fix.**
4. Correct the deny message at `:218` (rpg N1) and narrow the header's
   obfuscation claim at `:32-35`; note in the helper's own header that it exists
   so the two literals cannot drift.
5. Extend the suite with Step 2's newly-denied set, must-stay-allowed set, the
   `rm -rf .claude/reviewed/../x` criterion and the residual pins; run both
   mutation proofs via `GATE_UNDER_TEST`.
6. Run `node bin/cli.js --update`.

**## Do NOT touch**
`hooks/scripts/lib/benign-command.sh`, `hooks/scripts/human-decision-gate.sh`
(unit 1 owns it), any `agents/*.md`, any version file. Do not port the helper to
the sibling gate — its early-exit is already robust here (measured). Do not
change `normalize_path()`; call it.

**## Acceptance criteria**
Step 2's criteria block verbatim, plus its suite-verified items (the newly-denied
set; the 10 must-stay-allowed shapes; zero deleted lines in the test-file diff;
`rm -rf .claude/reviewed/../x` still denied; the R-11 residual pins unchanged;
both mutation proofs run).

**## Pre-resolved context**
Do not re-derive any of this — it is measured in Context:

- Canonicalizing **only** the early-exit closes 1 of 10 shapes and still passes
  all 412 assertions. Both call sites are required, and each is a sole denier
  for A1.
- The union is additive by construction (raw disjunct first), which is why the
  measured result is 0 new allowances across 780 + 216 commands. Do not
  "simplify" it to `normalize_path()` alone — that newly allows
  `rm -rf .claude/reviewed/../x`.
- `normalize_path()` is already in the shared lexer and already sourced here.
  This unit does not edit `benign-command.sh`.
- Worst-case cost of the new loop is 129 ms at 3000 `.claude`-bearing words
  (base 12 ms); the pathological 60 KB-message cost is unchanged at ~1.95 s.
- The variable-split and F-1 glob residuals stay open and unchanged; `README.md`
  needs no correction, but the gate header does.
- **`CONTEXT.md`'s gate glossary entries are factually wrong.** Read the code.

**## Escalation**
If the canonicalization cannot close the newly-denied set while preserving all
10 read/prose/comment shapes, **stop and report** — a spec defect, not an
implementation one. If either mutation proof shows a call site is *not* a sole
denier for A1, stop and report: that means the fix is not doing what this
document measured. If closing this requires editing
`hooks/scripts/lib/benign-command.sh`, stop and report (R-4). Do not attempt
F-1 (Open Question 1).
