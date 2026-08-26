# Close the review-harness trust gaps: the unguarded kill switch, the erasable deterrent, the bypass-teaching refusals, the self-report surface, and the self-graded microworld check

**Status:** FINALIZED. All five Open Questions are resolved (see *Resolved
decisions*). Dispatchable.

**Authoring commit:** `09cc304ab682bb057d8ab0f349b0d5d4515ba42e` (2026-08-25).
Every baseline below was measured at that tree and **re-verified after spec 6
landed** — `hooks/` and `.claude/persona-config.json` are byte-unchanged, so all
baselines stand. Baselines expire (`[[baselines-expire]]`); re-derive with the
probe commands quoted inline rather than trusting the recorded numbers.

## Relationship to spec 6 (Architecture D) — read this first

**A mid-flight draft of spec 6 said this spec was superseded and should be
retargeted to `.github/workflows/**`, the ruleset and the CI secret. That draft
was retracted by its own author.** This document was briefly rewritten against
it and has been reverted. The retracted reading would have hardened the CI layer
while leaving the shipped product's trust gaps open — and, worse, would have
removed the one gate spec 6 now depends on.

Spec 6 as **landed** (`docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`,
FINAL, 1,179 lines) rules the opposite, in D0:

> *"This repository's own gate **enforcement** moves to CI. The hook scripts,
> their test corpus, and their place in the shipped plugin all stay exactly where
> they are."*

and, in its reconciliation table, for this spec specifically:

> *"**Survives fully intact — and under RD1 it is more needed, not less.** Its
> subject is the **product's** trust posture, and RD1 keeps the product. …
> **Land it. Do not rescope it.**"*

Three concrete couplings follow, and each is carried as a criterion rather than a
note:

1. **Step 2's gate is exempt from `reviewGating.mode`.** D0 names it directly —
   *"sibling spec 1's `harness-integrity-gate.sh`, which is **configless by
   design** and must stay that way. Wiring the switch into any of the six is a
   defect."* Step 2 already specifies configless; **C2.2 now proves the
   exemption**, so a later D unit cannot wire the switch in by accident.
2. **D adds a new kill switch, and Step 4 is what detects it being thrown.**
   `reviewGating.mode` (`enforce` | `warn` | `off`, defaulting to `enforce` when
   absent) is a single config key that disables the whole gate battery. D's own
   A30 names the danger: *"a `reviewGating` read that defaults to `off` instead of
   `enforce` would pass every other criterion while silently disarming every
   downstream project."* That is finding F1 reborn inside D's mechanism.
   **`reviewGating.mode` is therefore added to Step 4's disarm surface**, with the
   absent → `"off"` transition treated as a weakening (C4.2).
3. **This repo will set `reviewGating.mode: "off"`, so Steps 1, 5, 6, 7 and 9
   become product-facing here.** After D's flip, the six gates Step 1 adopts stop
   enforcing *in this repo*. They keep enforcing for every downstream adopter, and
   Step 2's configless gate keeps enforcing here — which is exactly the *"genuine
   safety net for D5's advisory-only residual"* D credits it with. Stated plainly
   so nobody reads a green local session as evidence a gate ran.

**Value-add flagged by spec 6, deliberately not taken as scope.** D11 observes
that Step 2 registers on both `PreToolUse (Write|Edit)` **and** `PreToolUse
(Bash)` — *"exactly the Bash-half coverage spec 3's OQ2 doubted was
achievable"* — and that if it lands and demonstrably denies the shapes the
textual-gate corpus covers, **spec 3's M4 unblocks via this spec, not via D**.
Recorded here as a sequencing fact so whoever evaluates M4's precondition (spec
3's A23) tests against Step 2's gate. **M4 remains spec 3's to adjudicate; no
step below deletes a line of the corpus.**

**Sibling specs — do not annex.** Spec 2 (performance, FINAL — ADR-0010 reversed,
implementer default `sonnet`), spec 3 (ceremony consolidation, FINAL, M4 blocked),
spec 4 (Microworlds workflow, FINAL), spec 5 (rollout sequencing, FINAL), spec 6
(CI architecture, FINAL, gated on its P0). Overlaps are declared per step.
**No criterion in this document names a model tier**, so spec 2's ratification
requires no edit here; the only tier mentions are this sentence and the D7 note,
both prose, neither inside a fenced block. Spec 5's rollout map does not yet
include spec 6 — flagged by D and owned by spec 5, noted here only because both
this spec and D touch `.claude/persona-config.json`.

---

## Goal

The harness's security posture currently rests on five claims that are false or
unproven at HEAD:

1. **The harness cannot be silently disarmed.** It can — one `Write` to
   `.claude/persona-config.json`, or one `rm` of it, and 9 of the 14 hook scripts
   early-exit `0`. Measured below. D adds a *second* one-key switch on top of it.
2. **The audit logs are a deterrent.** They are, but only against an agent that
   does not delete them. Nothing protects them and nothing detects their
   destruction. Three hook headers say so in their own words: *"`.claude/…-audit.log`
   is the deterrent, not a guarantee."*
3. **A blocked agent learns only that it was blocked.** It also learns, verbatim
   in the refusal text, the general principle that defeats the gate.
4. **A PASS marker means the unit passed.** It means a string starting
   `PASS <id> ` exists in a directory only the reviewer may write. The marker's
   own `criteria:` field — the list of commands the reviewer says it ran — is
   never re-run by anything.
5. **A microworld bundle's `result=pass` is a check result.** It is the exit code
   of a script the implementer wrote, about the implementer's own work, with no
   provenance recorded anywhere the reader of the dashboard can see.

This spec closes 1, 2, 3 and 5, converts as much of 4 from self-report to
mechanical check as is feasible, and — for the irreducible remainder — makes the
self-report surface **enumerated and labelled** rather than implicit.

**Non-goal, stated up front:** none of this makes the harness proof against a
determined adversary with `Bash`. It cannot be: every gate is a text scan over a
command whose meaning bash resolves from state the text does not carry. The
achievable property, and the one every acceptance criterion below is written
against, is: **a disarm or an erasure must stop being free, silent, and
one-call — it must become either blocked, or loudly and mechanically evident
afterwards.**

---

## Context — the critique's five findings, verified against HEAD

The critique was taken as a hypothesis, not as fact. Each finding was reproduced
with real payloads against the real scripts. Two of the five needed correction.

### F1 — Unguarded kill switch: CONFIRMED, with one correction

**Correction to the critique.** It states *"every gate script in `hooks/scripts/`
opens with `[ -f .claude/persona-config.json ] || exit 0`."* Not every one — 9 of
14, and the exceptions matter:

```
GUARDED   dispatch-hygiene.sh  graph-update.sh  lint-on-edit.sh
          protected-paths.sh   reviewed-path-gate.sh  session-start.sh
          stop-gate.sh         task-gate.sh
unguarded heavy-trigger.sh  human-decision-gate.sh  marker-commit-check.sh
          microworld-rerun.sh  reviewer-route-gate.sh  reviewer-tier.sh
```

`human-decision-gate.sh` reads no config at all and therefore **survives** the
kill switch — a deliberate property of a gate that "grants nobody", the design
precedent for Step 2, and the same property D0 now requires of Step 2's gate.
`reviewer-route-gate.sh` is a partial survivor: its two identity blocks
(`:51-65`) run configless, while its pending-review branch (`:68`) is
config-gated. The three helpers (`heavy-trigger`, `reviewer-tier`,
`marker-commit-check`) are CLI utilities, not hooks.

**The substance of the finding stands, and is worse than "not in
`protectedPaths`."** Measured at `09cc304`, on a fixture project that is
demonstrably *adapted* (`.claude/agents/reviewer.md` present) but whose
`persona-config.json` has been deleted:

```
dispatch-hygiene(Agent)      exit=0      # control, config present: exit=2
reviewer-route-gate(Agent)   exit=0
task-gate(TaskCompleted)     exit=0      # control, config present: exit=2
stop-gate(SubagentStop)      exit=0
```

The controls are what make this attributive rather than a payload-shape
artifact: the *identical* payloads exit `2` the moment the config is restored.

And the write itself is unopposed. All three `Write|Edit` PreToolUse gates pass a
`Write` targeting the config:

```
protected-paths      exit=0     # persona-config.json is not in protectedPaths
reviewed-path-gate   exit=0     # only owns .claude/reviewed
human-decision-gate  exit=0     # only owns .claude/human-review/*/DECISION
```

**The bootstrap problem, which is why the obvious fix does not work.** Adding
`.claude/persona-config.json` to `protectedPaths` is self-referential:
`protected-paths.sh:27` reads its pattern list *out of the file it would be
protecting*, and `:17` early-exits when that file is absent. A `Write` that
empties `protectedPaths` is evaluated against the pre-edit config and passes; a
`Write` that deletes the file disarms the check outright. `protected-paths.sh`
also matches `Write|Edit` **only** (`:8-11`, and `[[escalation-vs-protectedpaths]]`),
so `jq '.gatedAgents=[]' … > cfg` via `Bash` never reaches it at all.

Therefore the guard must be **hardcoded and configless**, not config-driven.
That is Steps 1 and 2 — and it is why D0 exempts Step 2's gate from
`reviewGating.mode`: a switch on it would reintroduce the exact bootstrap defect
it exists to remove.

**Local aggravating factor, worth the operator knowing.** This repo's own
`.claude/settings.local.json` carries `"Edit(.claude/persona-config.json)"` in
its permission allowlist, so the disarming `Edit` does not even raise a
permission prompt here. Out of scope to change (it is operator configuration,
not plugin code), but it is why the finding is live rather than theoretical in
this working copy.

### F2 — The deterrent is erasable: CONFIRMED

`.claude/review-audit.log` (254 KB at `09cc304`), `dispatch-audit.log`,
`microworld-audit.log` and `wip-audit.log` are gitignored (`.gitignore:15-24`),
live outside `.claude/reviewed/`, and are named in no `protectedPaths` entry.
Measured — `reviewed-path-gate.sh` on `: > .claude/<name>.log`:

```
review-audit exit=0   dispatch-audit exit=0
microworld-audit exit=0   wip-audit exit=0
```

The system says this about itself, in three places:

- `stop-gate.sh:109-112` — *"this cannot force the orchestrator's next action.
  `rm -f .claude/.pending-review.*` via Bash remains possible;
  `.claude/review-audit.log` is the deterrent, not a guarantee."*
- `dispatch-hygiene.sh:75-78` — same sentence for `dispatch-audit.log`.
- `stop-gate.sh:82-88` — the WIP sentinel is *"a friction/audit-trail fix, not a
  guarantee against abuse."*

Every one of those honest disclaimers is load-bearing on the audit trail
surviving. Nothing makes it survive, and — the actual gap — nothing **notices**
when it does not. Because the logs are gitignored, git cannot serve as the
baseline the way it can for the config; the detection mechanism has to be built.
That is Step 3.

### F3 — The refusal messages teach the bypass: CONFIRMED, and demonstrated live

While gathering baselines for this very spec, two of my own `Bash` calls were
blocked. Both refusals handed me the general principle unprompted. Verbatim from
`reviewed-path-gate.sh:285`:

> *"Both sanctioned workarounds keep the path **OUT of the command text
> entirely**; respelling it in place does not work … because quote-split,
> dot-segment, doubled-slash and `..` traversal spellings are all recognized
> here."*

and from `human-decision-gate.sh:285-288`:

> *"**Splitting the path across shell variables**, or otherwise rephrasing so
> the command text never spells it, is a self-authorized bypass for this gate …
> That workaround is scoped to `reviewed-path-gate.sh`."*

Measured occurrence counts in the two gates' actual denial stderr at `09cc304`
(all `1`, i.e. all present):

```
rpg  'OUT of the command text entirely'          1
rpg  'human-decision-gate.sh'                    1
rpg  'quote-split, dot-segment, doubled-slash'   1
hdg  'Splitting the path across shell variables' 1
```

Both files additionally enumerate their live open classes in header comments
(`reviewed-path-gate.sh:35-41`, `human-decision-gate.sh:158-164`, `:322-326`) —
that is correct and must stay, because headers are read by humans and reviewers
at leisure, not by a thwarted agent at the moment of maximum motivation to route
around the block.

The distinction this spec draws, and the only one it acts on: a refusal message
may state **what is sanctioned** and **that everything else is forbidden**; it
may not state **why the forbidden things work**. Step 5.

**Why this step survives D.** Under D0 the gates remain the shipped product, and
their refusal text ships with them. The footgun is live for every downstream
adopter regardless of this repo's own posture.

### F4 — Self-report-only enforcement: CONFIRMED; map below

Verified mechanically:

- `task-gate.sh:54-62` `marker_valid()` — checks `[ -f ]`, `[ -s ]`, and that
  line 1 begins `PASS <task-id> `. It does not parse `commit:` and does not
  parse `criteria:`.
- `stop-gate.sh:365-391` — `defer:`/`skip:` are matched as prefixes with a
  non-empty tail. `:419-430` — the WIP sentinel is honored on `[ -s ]` alone.
- `dispatch-hygiene.sh:341-360` H4 — eight `## ` headings matched as plain
  substrings anywhere in the prompt, plus a `Unit:` regex. Its own comment
  (`:64-68`) says it: *"H4 checks LABELS, NOT SUBSTANCE … an agent can emit all
  nine headings and fill them with nothing, and H4 will pass it."* Reproduced: a
  prompt with all nine elements and every body empty fires **no** H4.

**Prior art that makes the conversions tractable.** `marker-commit-check.sh`
already does exactly the thing this finding asks for, for one field: it takes a
self-reported claim (the marker's `commit:` sha), checks it against ground truth
(git history), and emits one classified line
(`marker-commit-check=<ok|mismatch|unverifiable> …`), always exiting `0` and
never deciding policy for its caller. Every conversion below copies that shape
rather than inventing one.

**The current trust map** (the artifact Step 8 makes durable):

| # | Trust-critical claim | Asserted by | Checked today | Convertible? |
|---|---|---|---|---|
| 1 | This unit passed review | reviewer | `task-gate.sh` `marker_valid()`: line-1 prefix + non-empty | Partly — Step 6 |
| 2 | The marker's `commit:` names this unit's commit | reviewer | **`marker-commit-check.sh`** (mechanical, advisory, `mode: warn`) | Already done |
| 3 | The `criteria:` commands actually pass | reviewer | *nothing* | **Yes — Step 6** |
| 4 | The `criteria results:` prose is true | reviewer | *nothing* | Subsumed by 3 |
| 5 | The reviewer, not the writer, wrote the marker | `agent_type` | `reviewed-path-gate.sh` grant matcher | Already done |
| 6 | A WIP sentinel names a real pause | gated agent | non-empty only | **No** (semantic) — Step 7 makes the *rate* visible |
| 7 | A `defer:` reason is real | main session | prefix + non-empty | **No** — same |
| 8 | A `skip:` abandonment is legitimate | main session | prefix + non-empty | **No**, but its *consequence* is — Step 7 |
| 9 | A dispatch carries a real nine-element contract | dispatcher | H4: headings present | **Partly — Step 7** (non-empty bodies) |
| 10 | A microworld `result=pass` is a check result | implementer's `run.sh` | exit code taken at face value | **Provenance is — Step 9** |
| 11 | The harness is armed | — | *nothing* | **Yes — Steps 1, 2, 4** |
| 12 | The audit trail is complete | — | *nothing* | **Yes — Step 3** |
| 13 | `reviewGating.mode` has not been flipped to `off` | — | *nothing* (key does not exist yet) | **Yes — Step 4** |

Rows 6, 7 and 8 are the honest irreducible remainder: no mechanism can decide
whether a stated reason is true. What *is* mechanizable there is frequency and
consequence, which is all Step 7 claims. Row 13 is new, added by D.

### F5 — The implementer authors the check that grades the implementer: CONFIRMED, with two corrections

**Correction 1 — "treated as ground truth" overstates `microworld-rerun.sh`.**
Its own header (`:5-7`) is explicit: *"This is a REPORTER, not a gate."* Its
`exit 2` surfaces stderr to the model; it blocks nothing, and the edit has
already happened. D8 retains it for exactly that reason, and D0 exempts it from
`reviewGating.mode`.

**Correction 2 — the protocol is already honest; the surfaces are not.**
`.claude/persona-protocol.md:608` — the dashboard *"is a human-facing exploration
surface and never an acceptance criterion — no hook registers it, no gate
consults it, and no acceptance criterion in this or any future spec may name
it."* And `:644` — *"A check result is advisory only."*

**What remains true, and is the real gap.** `run.sh` is implementer-authored
(`persona-protocol.md:608`), gitignored working-tree scratch (`:639`), and the
reviewer verifies bundles as a *filesystem presence check, never by executing
their entries* (`:608`). The audit line `microworld-rerun.sh:23` emits —
`<ts> unit=<slug> result=<pass|fail|…> file=<path>` — carries **no authorship
field**, and `index.html:218-223` renders `result === 'pass'` as an unqualified
green dot identical in appearance to any other green signal on the page. A human
scanning the dashboard cannot tell a self-graded pass from anything else, and no
artifact anywhere records who wrote the grader.

Measured: `grep -cE 'authority=' .claude/microworld-audit.log` → `0`;
`grep -cF 'authority' bin/microworld-dashboard/audit-log.js` → `0`.

Step 9 fixes the **authorship/trust-authority** problem only. It does not touch
the bundle lifecycle (spec 4's job). Under D0 `.claude/reviewed/` survives as the
product's mechanism, so the countersign marker has a home (OQ5).

---

## Resolved decisions (formerly OQ1–OQ5)

All five were answered with the recommended default, ratified 2026-08-25.

**RD1 — `marker-verify.sh --execute` executes the marker's `criteria:` text, but
only when asked.** `--list` is the default and performs no execution; `--execute`
is an explicit flag; the script is **never registered in any hook**. The marker is
written by the reviewer, inside the repo whose own `tests/validate.sh` the
operator already runs, so the marginal execution risk over existing practice is
small — and the alternative, never re-running, leaves the single most load-bearing
claim in the system permanently unverified. C6.1's never-registered assertion is
the standing guard.

**RD2 — `harness_armed()` returning `tampered` BLOCKS.** A trust gate that fails
open on evidence of tampering is not a trust gate, and the whole finding is that
these gates currently fail open on exactly that evidence. Named risk (R1): a
genuinely lost config bricks the session, and Step 2's gate simultaneously
refuses the write that would restore it — so the refusal **must** name a recovery
route, and verifying that the named route really reconstructs a *deleted* config
is a **precondition on Step 1**, not an assumption.

> **RD2 amended 2026-08-26 (see RD2a).** The precondition was executed and the
> originally-named route, `node bin/cli.js --update`, **failed it**. The ruling
> above (tampered BLOCKS) is unchanged; only the named route changed. Read RD2a
> before implementing Step 1.

**RD2a — the sanctioned recovery route is `git restore`, performed by the
operator, and the refusal names no self-service rebuild command.** *Ratified
2026-08-26, replacing RD2's `--update` route after C1.0 was executed.*

Three measured facts drive this, each re-verified against `bin/cli.js` at
v0.31.65 on throwaway fixtures (`--personas=reviewer` and `--yes` scaffolds):

1. **`--update` cannot reconstruct a deleted config, by construction.**
   `runUpdate()` early-exits `process.exit(1)` when the config is absent
   (`bin/cli.js:1076-1083`) — a circular check that refuses to proceed precisely
   *because* the file it would rebuild is missing, regardless of which other
   adaptation witnesses survive. Six flag combinations were tested
   (`--update` alone, `+--force-render`, `+--check`, `+--dry-run`,
   `+--allow-downgrade`, and all of them together): every one exits `1` and
   mutates zero bytes of the tree. There is no bypass flag.
2. **The scaffold path "works" but writes a weaker harness than it found.**
   `node bin/cli.js --yes --overwrite` does exit `0` and does write a config, but
   the config it writes carries only ten default-valued fields:
   `protectedPaths: []`, `testAndLintCommand: ""`, `lintCommand: ""`,
   `graphUpdateCommand: ""`, `sourceGlobs: []`, `issueTracker: ""`,
   `gatedAgents: ["lead-programmer"]`, `humanReviewMode: "critical"`, plus
   `pluginVersion` and `personaSelection` — and **no `fileHashes`, no
   `substitutions`, no `dispatchHygiene`, no `markerCommitCheck` keys at all.**
   Against this repo's own live config that is the loss of **26 `protectedPaths`
   entries**, the `testAndLintCommand`, the `issueTracker` retrieval contract,
   both MCP launch `substitutions`, and all **52 `fileHashes`** rows.
   `personaSelection` is **not** recovered from the surviving
   `.claude/agents/*.md` witnesses either: a fixture scaffolded
   `--personas=reviewer` (four agent files on disk) came back with all seven
   optional personas selected and **six agent files it had never selected newly
   written to disk**. Nor does chaining heal it — `--update` run immediately
   after such a rebuild exits `1`, refusing to render `explorer.md` because the
   `substitutions` that carried its MCP launch command are gone.
3. **Naming that command in *this particular* refusal would teach the disarm.**
   The `tampered` verdict fires exactly when the config is missing on an adapted
   project. A refusal that answers "run `node bin/cli.js --yes --overwrite`"
   hands the reader a two-step recipe whose net effect is
   `protectedPaths: []` — it converts the gate from a tamper *detector* into a
   documented tamper *completion*. That is F3's failure mode in its sharpest
   form, and RD4 is the standing ruling that such sentences are replaced rather
   than kept.

**So the route is version control, and it is an operator action.**
`.claude/persona-config.json` is a tracked file — confirmed by
`git ls-files --error-unmatch`, and confirmed *for adopters* by
`OPERATIONAL_GITIGNORE_PATTERNS` (`bin/cli.js:155-170`), the single-sourced
managed ignore list every target's scaffold appends, which does not contain it.
`git restore` is therefore the only route that returns the *actual* prior config
rather than a weaker stand-in, and it needs no new code. This is the same
mechanism D3 already ratified as the config's drift **baseline**; RD2a simply
makes the **recovery** route agree with the baseline route instead of diverging
from it.

It is scoped to the operator deliberately, and the scoping costs nothing that was
ever available: Step 2's `Bash` branch matches Set A, which contains
`.claude/persona-config.json`, so any in-session command spelling that path is
denied. An operator at their own terminal runs no hooks. Rewording the command so
Step 2 stops seeing the path would be a self-authorized bypass, and the refusal
must not hint at one (RD4, F3).

**What this costs, accepted explicitly.** A session that hits `tampered` halts
until a human intervenes. That is the intended behaviour, not a regression: two
independent adaptation witnesses plus a missing config is either tampering or the
loss of an irreplaceable judgment-bearing file, and neither is a state an agent
should self-service its way out of. The halt is one operator command wide, and
the alternative — a self-service rebuild — is strictly worse than the halt,
because it ends with the harness disarmed and the session *unblocked*.

**RD3 — Config drift is reported at `SessionStart` and blocks only at a gated
agent's `SubagentStop`; never at main-session `Stop`.** The operator edits this
config legitimately and often (this repo's `settings.local.json` allowlists it);
a gated agent has no legitimate reason to leave one weakened. The asymmetry
matches `stop-gate.sh`'s existing design, where the main session is deliberately
non-gated (`:11-18`).

**RD4 — The bypass-teaching sentences are REPLACED, not merely deleted.** They do
two jobs at once: they forbid the technique and they describe it. Keeping the
prohibition and dropping the description is strictly better — an agent that has
not thought of the technique is not given it, while one that has is still told it
is forbidden. *The conditional drop attached to this ruling ("drop Step 5 entirely
if the retarget moots it") does **not** fire: under D0 the gates remain the
shipped product, so the disclosure is live for every downstream adopter.* Step 5
stands.

**RD5 — `.countersign` lives in gitignored `.claude/reviewed/`, failing safe to
`authority=self` on loss.** It is the only location with a mechanically-enforced
write identity, which is the entire property Step 9a depends on; its loss
degrades to the honest default. Same accepted consequence README's known-limitation
(c) records for escalation packets. D0 keeps the marker directory, so this
resolution stands unchanged.

---

## Clarifications — decisions taken, with the reasoning

**D1 — The guard must be configless, or it is not a guard.** Step 2's gate reads
no `persona-config.json` and takes no config-driven early exit, following
`human-decision-gate.sh`'s precedent exactly. A guard whose arming lives inside
the thing it guards protects nothing. D0 independently requires this and names
wiring `reviewGating.mode` into it *"a defect"* — C2.2 proves the exemption.

**D2 — Prevention is best-effort; detection is the load-bearing half, and only
one of the two detectors is strong.** Step 2's **`Bash`** deny inherits every
residual the existing gates disclose (variable assembly, glob metacharacters,
`$'…'`, `cd`-relative writes, symlink hops — see `reviewed-path-gate.sh:35-41`
and the `rpg-canon-2` marker's note N3). Step 2's **`Write`/`Edit`** deny does
not: it is an exact path match with no lexer, which is why Set B exists on that
branch only. Neither is claimed airtight.

Of the two detectors, they are **not** equally strong and the spec must not
imply they are:

- **Step 4's config check is genuinely hard to forge.** Its baseline is
  `git show <sha>:.claude/persona-config.json` — an object in git's content-addressed
  store that an in-session write cannot alter without rewriting history.
- **Step 3's seal is not.** It is defeated by any adversary willing to reseal,
  and the only thing raising that cost is the `Bash` text scan above — the same
  defeatable class. It catches accidents and prices intent; it does not stop it.
  Stated in full under Step 3's *What the seal does and does not prove*, and
  pinned into the shipped header by C3.6.

**D3 — Git is the baseline for the config; a seal is the baseline for the logs.**
`.claude/persona-config.json` is tracked (confirmed: absent from `.gitignore`,
which covers only `.claude/settings.local.*` among config-ish paths), so
`git show <sha>:.claude/persona-config.json` is an immutable reference no
in-session write can alter. The four audit logs are gitignored, so they need a
sidecar seal instead. Different mechanisms, same property.

**D4 — The drift baseline is the session baseline, not `HEAD`.**
`session-start.sh:33-38` already writes `.claude/.session-baseline.<session-id>`
containing the starting sha (verified: this session's file holds `09cc304…`).
Comparing against that sha rather than live `HEAD` catches both an uncommitted
weakening *and* one committed mid-session to hide it.

**D5 — Refusal messages change; header comments and `docs/` do not.** The
disclosure content removed from runtime stderr in Step 5 already exists in the
file headers and belongs there. Nothing is deleted from the repo; it is moved out
of the one channel that delivers it to a blocked agent.

**D6 — `reviewGating.mode` is a disarm-surface field from the moment it is
defined, including while absent.** Absent means `enforce` (D's A24b), so the
transition absent → `"off"` is a weakening and Step 4 must catch it. An extractor
that only compares present-vs-present would miss the single most consequential
edit D introduces. C4.2 pins the absent-baseline case explicitly.

**D7 — Overlap declarations.**
- *Spec 6 (D):* Step 2's gate is a named dependency of D0 and must stay
  configless; Step 4 monitors the key D introduces. Nothing here changes a
  workflow, a ruleset, or D's verdict contract.
- *Spec 3:* Step 2 may unblock M4 as a side effect (D11). Recorded, not taken —
  **no step here deletes a line of the textual-gate corpus.** Step 5 edits two
  gates' refusal *strings*; spec 3's M4 concerns deleting the *corpus*, which is
  disjoint.
- *Spec 4:* Step 9 adds one optional marker kind and one audit field; bundle
  lifecycle, `functions[]` and capture are spec 4's.
- *Spec 2:* no criterion names a model tier, so the `sonnet` ratification needs
  no edit here.
- *Spec 5:* owns the rollout map; this spec asserts no ordering against siblings
  beyond the internal step order and R7's adapter obligations.

**D8 — Self-reference trap avoided deliberately.** Step 5's criteria grep the
gates' **runtime stderr**, never the repo tree. A tree-wide grep for the banned
phrases would match this plan document and the new test file, and would be
unsatisfiable by construction (`[[verify-own-criteria-nonvacuous]]`, trap two).

**D9 — A recovery route that writes a weaker config is not a recovery route
(2026-08-26).** *Added when C1.0's precondition failed; see RD2a.* The tempting
fix was to repoint Step 1 at `node bin/cli.js --yes --overwrite`, which does
work in the narrow sense of exiting `0` with a config on disk. It is rejected
because "reconstructs the config" and "writes a file at that path" are not the
same claim, and only the first one makes the gate's refusal honest. The measured
gap is in RD2a fact 2; the shape of the error is worth stating separately because
it generalizes: a fail-closed gate's refusal is read at the moment its reader has
the least context and the most incentive to take the first offered exit, so the
route it names has to be the *correct* one, not the *available* one.

Two consequences follow that the rest of this spec now depends on:
- **Step 1 ships no new `bin/cli.js` code, and no new unit was created.** A
  narrower `--reconstruct-config` was considered and rejected on value: the
  fields it could recover from disk (`personaSelection`, `fileHashes`,
  `substitutions`, `pluginVersion`) are the recoverable ones, and the fields that
  make the config load-bearing for *these six gates* — `protectedPaths`,
  `gatedAgents`, `humanReviewMode`, `testAndLintCommand`, `issueTracker` — have
  no on-disk witness and would still come back empty or defaulted. New code in
  `bin/cli.js` that leaves `protectedPaths: []` buys collateral reduction, not
  correctness, and `bin/cli.js` is not a file where speculative code is cheap.
  Constitution P2 also points this way: `--update`'s deterministic backfill is
  the sanctioned mechanism, and it is precisely the mechanism that cannot reach
  the judgment fields.
- **`git restore` is not a new mechanism here; it is D3's.** D3 already ratified
  git as the config's immutable baseline for Step 4's drift check. RD2a makes the
  recovery route the same mechanism as the baseline route, which is a
  simplification of the spec, not an addition to it.

---

## Risks / dependencies

- **R1 — Fail-closed halts a session, and no in-session route un-halts it
  (RESOLVED 2026-08-26 as RD2a; the precondition ran and the original route
  failed).** If Step 1's `harness_armed()` blocks on "adapted but no config", and
  the config is genuinely lost, Step 2's gate simultaneously refuses the write
  that would restore it. The originally-named route, `node bin/cli.js --update`,
  was **verified not to work**: `runUpdate()` early-exits `1` on an absent config
  (`bin/cli.js:1076-1083`) across all six flag combinations tested, mutating
  nothing. The scaffold path does write a config but writes a materially weaker
  one (RD2a fact 2), so it is rejected as a *named* route rather than adopted.

  The resolution keeps the block and moves the route out of the session: the
  operator runs `git restore` on a tracked file, outside any hook. Three residual
  properties, recorded so nobody re-opens them as defects:
  - **The session stays halted until a human acts.** Intended (RD2a). A
    `tampered` verdict is not an agent-recoverable condition.
  - **Step 2 denies the recovery command in-session.**
    `.claude/persona-config.json` is in Step 2's Set A, which the `Bash` branch
    scans, so `git restore .claude/persona-config.json` is denied from inside a
    session. Consistent, not contradictory — the route was never an in-session
    one. **No Step 2 change is required or authorized by this amendment**; its
    Set A membership and its C2.4 `node bin/cli.js --update` GUARD both remain
    correct as written (that GUARD asserts a legitimate command is not
    over-blocked; it never claimed the command reconstructs anything).
  - **An untracked config has no lossless route.** A project that gitignored or
    never committed its config can only be rebuilt by re-running
    `/antislop:install-antislop`, whose repo scan refills the judgment fields
    with a human in the loop. The plain CLI rescaffold is not a substitute and
    Step 1's message must not present it as one.

  `[[verify-own-criteria-nonvacuous]]` trap nine (the tool self-repairing your
  negative fixture) is what C1.0 was written to catch. It caught the opposite and
  rarer case: the tool refusing to repair at all.
- **R2 — Adaptation detection false-positives.** `harness_armed()` must not report
  "tampered" for a project mid-`install-antislop`. Detection keys on
  `.claude/agents/*.md` existing; a partial adapt could satisfy that before the
  config is written. Mitigation: treat *unwritable/absent config + present agents*
  as tampered only when `.claude/reviewed/` **or** `.claude/hooks/scripts/` also
  exists — two independent adaptation witnesses.
- **R3 — Log rotation must be sanctioned or it reads as tampering.**
  `review-audit.log` is already 254 KB and grows every session. Step 3 must ship
  `bin/harness-integrity.sh --rotate` in the *same unit* as the seal, or the first
  legitimate rotation trips the alarm this spec just installed.
- **R4 — `marker-verify.sh --execute` runs text from a marker file.** Resolved as
  RD1. It is not a new capability class in a repo whose reviewers already run
  `bash tests/validate.sh`, but it is the one place this spec adds an execution
  path, and it must never be hook-wired.
- **R5 — INTERACTION WITH D: after the flip, Steps 1/5/6/7/9 stop protecting *this*
  repo, and Step 4 is HALVED.** With `reviewGating.mode: "off"` the six gates Step
  1 adopts no longer enforce here. They still ship and still enforce downstream,
  and Step 2's configless gate still enforces here. Nobody should read a green
  local session as evidence that a Step 1 gate ran — the same caution the
  `rpg-canon-2` marker's note N7 already records about this repo's hook wiring.

  **Step 4 specifically degrades to report-only, and this is easy to miss.** Its
  two halves live in different scripts with different fates under the flip,
  verified against D0's exemption list and D11's retention table:
  - its **reporting** half is in `session-start.sh`, one of the four reporters
    D0 exempts and D11 lists as *"retained and still enforcing"*. **Survives.**
  - its **blocking** half is a gated agent's `SubagentStop` inside
    `stop-gate.sh`, which is **not** in D0's six-script exemption list and falls
    under D11's *"retained, no longer enforcing here"* row. **Goes dead in this
    repo.**

  So post-flip, disarm-surface drift — including a later hostile edit to
  `reviewGating.mode` itself — surfaces here as **one `SessionStart` context line
  and nothing more**. The block survives for every downstream adopter, and the
  detection is still recorded, but in this repo it stops being enforcement. That
  is an accepted consequence of D0, not a defect in Step 4; it is recorded so
  nobody later reads "Step 4 blocks on drift" as true of this repository.
- **R6 — INTERACTION WITH D: ordering against the flip.** Step 4 monitors
  `reviewGating.mode`. If D's flip unit lands **first**, Step 4's baseline is a
  config already carrying `"off"`, and the weakening it exists to catch is already
  in the baseline. **Step 4 should land before D's flip**, or its baseline must be
  pinned to a pre-flip commit and that choice recorded in the PASS marker.
- **R7 — Adapter ports are hand-maintained, and they are a bigger dependency than
  the critique implies.** Verified inventory: `adapters/codex/hooks/scripts/` and
  `adapters/cursor/hooks/scripts/` each carry seven scripts — `graph-update.sh`,
  `lint-on-edit.sh`, `microworld-rerun.sh`, `protected-paths.sh`,
  `reviewer-route-gate.sh`, `stop-gate.sh` — plus a `lib/` holding **only**
  `agent-identity.sh` (no `benign-command.sh`). The ports are meaningfully
  divergent, not copies: the codex port of `protected-paths.sh` reads the project
  dir from the payload's `.cwd` and parses `apply_patch` unified-diff headers,
  because Codex has no `tool_input.file_path`. Consequences:
  - **Step 1 touches three ported scripts** (`protected-paths.sh`, `stop-gate.sh`,
    `reviewer-route-gate.sh`) → six hand-edits plus a copy of
    `lib/harness-arm.sh` into both adapter `lib/` directories.
    `tests/adapter-stop-gate-parity.test.sh` is a *behavioural* parity guard over
    all three `stop-gate` ports and will exercise the change.
  - **Step 3 touches two ported scripts** (`stop-gate.sh`, `reviewer-route-gate.sh`,
    plus `microworld-rerun.sh` in Step 9) → the same hand-edit obligation for
    `lib/audit-log.sh`.
  - **Step 9 touches `microworld-rerun.sh`** in both ports.
  - **Steps 2 and 5 need no port.** Neither adapter carries `reviewed-path-gate.sh`
    or `human-decision-gate.sh`, and `human-decision-gate.sh:29-31` records that
    absence as deliberate precedent. Step 2's new gate follows it.
  `harness_armed()` and the seal library are both **payload-independent** — they
  inspect the filesystem, never the hook payload — so each port is a straight copy
  with the dot-dir substituted (`.claude` → `.codex` / `.cursor`). That is what
  makes porting cheap enough to be the recommendation rather than a declared
  parity hole (`[[dont-slice-units-across-a-parity-test]]`).
- **R8 — The `.claude/` mirror and `fileHashes`.** Every `hooks/scripts/` change
  needs a `node bin/cli.js --update` regen and a `fileHashes` entry, and
  `tests/validate.sh` is the mirror-parity check
  (`[[validate-sh-is-a-mirror-parity-check]]`). Every new script needs a
  `fileHashes` row and mode `100755` in the git index.
- **R9 — Local baseline is GREEN; CI is not.** `bash tests/validate.sh` exits `0`
  at `09cc304` with `0` `FAIL` lines (measured 2026-08-25), so no Step-0 clearing
  unit is needed for local work. The **CI** `validate` workflow is red at the same
  commit — that is spec 6's P0 and is not a blocker for this spec, whose criteria
  all run locally. Re-measure before dispatch
  (`[[measure-the-gate-baseline-first]]`).
- **R10 — `microworld-audit.log`'s line format is a consumed cross-language
  interface.** `microworld-rerun.sh:9-12` says so, `bin/microworld-dashboard/audit-log.js:47`
  holds the anchored regex, and `tests/microworld-audit-contract.test.js` pins the
  pair with a mutation proof. Step 9 must change hook, parser, and contract test
  in one unit (`[[dont-slice-units-across-a-parity-test]]`).
- **R11 — `humanReviewMode` is `"off"` in this repo.** ESCALATE-TO-HUMAN does not
  fire here whatever a unit touches (`[[escalation-vs-protectedpaths]]`). No step
  below may assume an escalation will surface anything.

---

## Steps

Each step is independently dispatchable. Every acceptance criterion below was
**executed against `09cc304`** and is currently RED unless explicitly labelled
`GUARD` (already green; proves scope was not exceeded). Criteria are shipped as
fenced `sh` blocks, with single-quoted patterns, and never reference `git diff`
— the tree is committed and clean when a reviewer evaluates them.

### Step 1 — `harness_armed()`: stop failing open when an adapted project's config is gone

Add `hooks/scripts/lib/harness-arm.sh` exporting one function,
`harness_armed <project_dir>`, returning:

- `0` — armed (config present and parseable),
- `1` — unadapted (no adaptation witness; every gate keeps its current silent
  `exit 0`),
- `2` — **tampered** (two independent adaptation witnesses present — any of
  `.claude/agents/*.md`, `.claude/hooks/scripts/`, `.claude/reviewed/` — but the
  config is absent, empty, or unparseable by `jq`).

Adopt it in the six trust gates whose disarming is the finding:
`reviewed-path-gate.sh`, `stop-gate.sh`, `task-gate.sh`, `reviewer-route-gate.sh`,
`dispatch-hygiene.sh`, `protected-paths.sh`. On `2` each blocks (`exit 2`) with
the fixed message specified below (RD2a, R1).
On `1` each keeps today's behaviour byte-for-byte. `graph-update.sh`,
`lint-on-edit.sh` and `session-start.sh` are **not** adopters — they are
reporters, not trust gates, and D0 independently exempts them.

The function must never consult `persona-config.json` to decide whether the
project is adapted (D1).

**The `tampered` denial message (RD2a).** Ship this text, once, in the shared
library rather than copied into six gates — the six adopters emit it verbatim so
a later correction lands in one place. `<witnesses>` is the concrete witness list
that fired; `<state>` is `absent`, `empty` or `unparseable`.

```
antislop: harness disarmed — refusing to proceed.

This project is adapted (<witnesses> present) but .claude/persona-config.json
is <state>. The trust gates cannot verify their own configuration, so this
action is denied rather than silently allowed.

This file is judgment-bearing and cannot be regenerated from what is on disk:
protectedPaths, testAndLintCommand, issueTracker, gatedAgents and
humanReviewMode have no other on-disk witness. Restoring it is an operator
action, not an in-session one.

Operator: restore the file from version control — it is a tracked file — then
start a new session. If it was never committed, run /antislop:install-antislop,
whose repo scan refills those fields with you in the loop. Re-running the
plain CLI scaffold is NOT equivalent: it writes protectedPaths empty and would
leave this project's harness weaker than it was before the file went missing.
```

Three properties of this text are load-bearing and each is pinned by a criterion
below, because each is a thing a well-meaning later edit would undo:

- **It names no self-service rebuild command** (C1.7). Under RD2a fact 3 such a
  sentence would be a disarm recipe, not a recovery route. This is the same
  discipline Step 5 applies to the two gates it edits; Step 1 must not
  reintroduce the class Step 5 is removing.
- **It names the operator, not the agent, as the actor** (C1.7). The route is
  denied in-session by Step 2's own `Bash` branch (R1), and a message that
  implied otherwise would push its reader toward rephrasing around that gate.
- **It states the rescaffold's cost rather than the rescaffold's command**
  (C1.7). Warning about a footgun without handing over the footgun is exactly
  RD4's "keep the prohibition, drop the technique".

Nothing here changes the *verdict* RD2 ratified — `tampered` still blocks. Only
the recovery route named in the refusal changed.

**Adapter ports (R7).** Three of the six adopters are ported. Copy
`lib/harness-arm.sh` into `adapters/codex/hooks/scripts/lib/` and
`adapters/cursor/hooks/scripts/lib/` with the dot-dir substituted, and hand-edit
both ports of `protected-paths.sh`, `stop-gate.sh` and `reviewer-route-gate.sh`.
The function is payload-independent, so no port-specific logic is needed.

**Acceptance criteria**

```sh
# C1.0  DISCHARGED 2026-08-26 — do NOT re-run as a gate on the approach.
#       The original precondition ("prove `node bin/cli.js --update` reconstructs
#       a DELETED config") was executed and FAILED. RD2a is the ruling that
#       replaced it; the recovery route is now `git restore`, performed by the
#       operator, and Step 1 ships no self-service rebuild command. What survives
#       as a criterion is the GUARD below, which pins the two measured facts the
#       denial message asserts, so that a later `bin/cli.js` change making either
#       one false is visible instead of silently rotting the message.

# C1.0a GUARD: `--update` still cannot reconstruct a deleted config (exit 1,
#       writes nothing). If this ever goes red, RD2a's fact 1 is stale and the
#       message should be revisited — that is the signal, not a failure.
#       DO NOT DROP THE `test ! -e` LINE. Measured 2026-08-26 against a mutant
#       cli.js with the early exit replaced by a config write: the mutant STILL
#       exits 1 (it fails later, on the missing `substitutions` that render
#       explorer.md). The exit code alone therefore passes for both the real and
#       the mutated CLI; only the absent-file assertion kills the mutant.
t=$(mktemp -d)
( cd "$t" && node "$OLDPWD/bin/cli.js" --personas=reviewer >/dev/null 2>&1 )
rm -f "$t/.claude/persona-config.json"
( cd "$t" && node "$OLDPWD/bin/cli.js" --update >/dev/null 2>&1 ); test $? = 1
test ! -e "$t/.claude/persona-config.json"
rm -rf "$t"

# C1.0b GUARD: the CLI scaffold path rebuilds the config with protectedPaths
#       EMPTY and no fileHashes — the measured basis for the message's claim
#       that a rescaffold leaves the harness weaker. Pinned so the claim cannot
#       become a false statement without a red criterion.
t=$(mktemp -d)
( cd "$t" && node "$OLDPWD/bin/cli.js" --personas=reviewer >/dev/null 2>&1 )
rm -f "$t/.claude/persona-config.json"
( cd "$t" && node "$OLDPWD/bin/cli.js" --yes --overwrite >/dev/null 2>&1 ); test $? = 0
test "$(jq '.protectedPaths | length' "$t/.claude/persona-config.json")" = 0
test "$(jq 'has("fileHashes")' "$t/.claude/persona-config.json")" = false
# and it does NOT recover the recorded persona selection from the surviving
# .claude/agents/*.md witnesses (measured: --personas=reviewer comes back as 7)
test "$(jq '.personaSelection | length' "$t/.claude/persona-config.json")" != 1
rm -rf "$t"

# C1.1  the library exists and is sourced by exactly the six adopters
test -f hooks/scripts/lib/harness-arm.sh
for g in reviewed-path-gate stop-gate task-gate reviewer-route-gate \
         dispatch-hygiene protected-paths; do
  grep -qF 'harness-arm.sh' "hooks/scripts/$g.sh" || { echo "MISSING $g"; exit 1; }
done
# and NOT by the three non-adopters
for g in graph-update lint-on-edit session-start; do
  test "$(grep -cF 'harness-arm.sh' "hooks/scripts/$g.sh")" = 0 || exit 1
done

# C1.2  behavioural: adapted-but-config-deleted now BLOCKS (baseline: all exit 0)
bash tests/harness-arm.test.sh

# C1.3  GUARD: an unadapted project is still silently allowed (baseline: exit 0)
t=$(mktemp -d)
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"antislop:lead-programmer","prompt":"Unit: u1"}}' \
  | CLAUDE_PROJECT_DIR="$t" bash hooks/scripts/dispatch-hygiene.sh; test $? = 0
rm -rf "$t"

# C1.4  mutation proof, recorded in the PASS marker: reverting the adoption in
#       ANY ONE of the six adopters must make tests/harness-arm.test.sh exit 1.
#       The implementer runs all six single-site reverts and records six kill
#       counts; a revert that leaves the suite green means that adopter is
#       untested.

# C1.5  adapter parity: the library is present in both ports' lib/, all six
#       ported adopters source it, and the behavioural parity guard still passes
test "$(ls adapters/*/hooks/scripts/lib/harness-arm.sh | wc -l)" = 2
test "$(grep -lF 'harness-arm.sh' \
        adapters/*/hooks/scripts/{protected-paths,stop-gate,reviewer-route-gate}.sh \
        | wc -l)" = 6
bash tests/adapter-stop-gate-parity.test.sh

# C1.6  mirror + hashes regenerated
node bin/cli.js --update --check
bash tests/validate.sh

# C1.7  RD2a message discipline. The message lives once, in the library, and
#       names no self-service rebuild command. Asserted over the shipped text
#       AND both adapter ports, since a hand-edited port is where this would
#       drift first (R7).
#   (a) the message is single-sourced: the six adopters carry the literal text
#       zero times; only the library does.
test "$(grep -cF 'harness disarmed' hooks/scripts/lib/harness-arm.sh)" -ge 1
for g in reviewed-path-gate stop-gate task-gate reviewer-route-gate \
         dispatch-hygiene protected-paths; do
  test "$(grep -cF 'harness disarmed' "hooks/scripts/$g.sh")" = 0 || exit 1
done
#   (b) no rebuild command is named anywhere in the library or either port.
#       `--update` is included: it does not work (C1.0a) and naming it would
#       send the reader down the dead route this amendment removed.
for f in hooks/scripts/lib/harness-arm.sh \
         adapters/codex/hooks/scripts/lib/harness-arm.sh \
         adapters/cursor/hooks/scripts/lib/harness-arm.sh; do
  for banned in '--overwrite' '--update' '--force-render' '--personas='; do
    test "$(grep -cF -- "$banned" "$f")" = 0 || { echo "BANNED $banned in $f"; exit 1; }
  done
done
#   (c) the operator route and the rescaffold warning are both present — (b)
#       alone is satisfiable by deleting the whole message, so this pins the
#       content it is meant to constrain.
grep -qF 'restore the file from version control' hooks/scripts/lib/harness-arm.sh
grep -qF 'protectedPaths empty' hooks/scripts/lib/harness-arm.sh
grep -qF '/antislop:install-antislop' hooks/scripts/lib/harness-arm.sh
```

*Baseline at `09cc304`, re-verified after spec 6 landed:* `harness-arm.sh`
absent; the four attributive probes (`dispatch-hygiene`, `reviewer-route-gate`,
`task-gate`, `stop-gate`) all exit `0` on a config-deleted adapted fixture, and
the two with a positive verdict for that payload exit `2` with the config
restored.

**Do not touch:** any gate's behaviour when the config is *present*. This step
changes exactly one branch — the absent-config one. In particular, do **not**
add a `reviewGating` read here; that is D's unit, and the six exempt scripts are
D0's list, not this step's.

---

### Step 2 — `harness-integrity-gate.sh`: a configless, hardcoded write-deny for the harness's own control surface

New `hooks/scripts/harness-integrity-gate.sh`, registered in `hooks/hooks.json`
on **both** `PreToolUse (Write|Edit)` and `PreToolUse (Bash)`.

**Registration paths, verified.** `templates/settings-fragment.json` carries **no
`hooks` key at all** (checked: its top-level keys are `_comment`, `agent`, `env`,
`permissions`), so it is *not* a registration site. Hooks reach a project by
exactly two routes: the marketplace plugin auto-loading `hooks/hooks.json`
(`bin/cli.js:1768-1776`), and — when the plugin is not enabled — the standalone
CLI scaffold, which `bin/cli.js:1816-1819` describes as *"the ONLY
hook-registration path"*. Adding the gate to `hooks/hooks.json` covers both;
`tests/cli-hook-propagation.test.js` is the guard that proves it.

**The two branches carry DIFFERENT literal sets, and the asymmetry is the point.**
Both are hardcoded in the script and never read from config.

**Set A — both branches** (`Write`/`Edit` *and* `Bash`):

```
.claude/persona-config.json
.claude/review-audit.log
.claude/dispatch-audit.log
.claude/microworld-audit.log
.claude/wip-audit.log
```

plus each log's `.seal` sidecar from Step 3.

**Set B — `Write`/`Edit` ONLY** (the gate-registration surface):

```
hooks/hooks.json
.claude/settings.json
hooks/scripts/harness-integrity-gate.sh
```

**Why Set B is `Write`/`Edit`-only, measured rather than asserted.** The two
branches have completely different false-positive economics:

- The **`Bash` branch is a text scan**, and ADR-0025 is the standing ruling on
  what that costs: *"a gate triggered by the mere presence of words in text
  necessarily triggers on prose mentions, not just write attempts."* Measured at
  `09cc304`, the FP surface for a `hooks/`-shaped trigger is large — **144
  tracked files mention `hooks/`, 1,183 occurrences in total, 186 of them in
  `tests/` alone.** Nearly every command this repo's own suites run would carry
  the token. Scanning Bash text for `hooks/` would over-block exactly as
  ADR-0025's failure mode 1 describes, and the escape valve is the
  self-authorized rephrasing F3 exists to stamp out. **So the `Bash` route to Set
  B stays open. That is a deliberate, ratified gap, not an oversight.**
- The **`Write`/`Edit` branch is an exact path match** on
  `tool_input.file_path` after `normalize_path` — no lexer, no substring
  matching, no prose exposure, and therefore near-zero FP risk. The ADR-0025
  argument simply does not reach it. Verified there is no tooling FP either:
  `bin/cli.js` writes these files through `fs.writeFileSync` (26 sites), which
  is a Bash-invoked node process, not a `Write` tool call, so `--update` never
  touches this branch.

**What Set B actually closes.** Set A protects the config that arms the *other*
gates, but leaves the cheapest kill of *this* gate wide open: one `Write` to
`hooks/hooks.json` deregisters it, and one `Write` to
`harness-integrity-gate.sh` redefines it to `exit 0`. Both are single tool calls
with no obfuscation required. `.claude/settings.json` is the third route,
verified as a real registration site: `bin/cli.js`'s
`findStandaloneHookRegistrations(settings)` reads `settings.hooks`, and the
standalone scaffold writes registrations there (`bin/cli.js:1151`, `:2316`) — it
is *"the ONLY hook-registration path"* for a project without the marketplace
plugin.

**Two consequences to accept explicitly rather than discover later:**

1. **`.claude/settings.json` is a mixed-purpose file** — permissions, `env`,
   `agent`, and hooks. Blocking `Write`/`Edit` on it blocks legitimate
   permission edits too. That is the intended trade: an agent editing its own
   permission grants is precisely the escalation this gate exists to make
   non-free. `.claude/settings.local.json` — the smaller, more frequently edited
   file (316 bytes vs 1,107 at `09cc304`) — stays **unblocked**, and C2.4 already
   pins that as a GUARD.
2. **The gate becomes self-protecting, so it becomes a protected path for
   maintenance too.** After this lands, a future `Write`/`Edit` to
   `harness-integrity-gate.sh` is refused, and the route is the same one every
   `protectedPaths` entry already uses: ask the operator. This does not block
   Step 2's own implementation — a repo-side script is not live until the plugin
   snapshot carries it — but it does affect every later maintenance unit, and
   that cost is accepted deliberately.

- **`Write`/`Edit` branch:** `normalize_path` the `file_path`, strip the project
  prefix, exact-match **Set A ∪ Set B** → deny. An absent/unreadable `file_path`
  fails closed, mirroring `reviewed-path-gate.sh:195-201`.
- **`Bash` branch:** **Set A only.** A single raw `case` over the five literals
  first, then
  the quote-joined + per-word-normalized mention test generalized from
  `reviewed-path-gate.sh`'s `mentions_marker_dir()`, then the shared
  `command_is_provably_benign()` read-only carve-out so `cat`/`grep`/`jq -r`
  inspection stays allowed. The raw-`case`-first ordering is a hot-path
  requirement: this fires on every `Bash` call in the session, and
  `reviewed-path-gate.sh:63-71` records what a careless per-word fork costs
  (9 ms typical, 6.0 s on a crafted 3000-word command).
- **No config precondition, no grant branch, no identity exemption, and no
  `reviewGating` read.** Precedent: `human-decision-gate.sh:2-5`. Requirement:
  D0's exemption list.
- Denials append one line to `.claude/review-audit.log` via Step 3's
  `audit_append`. That log is in Set A, so the record of a denial is itself
  covered on both branches — **but only to the strength Set A actually has**,
  which is exact-match on `Write`/`Edit` and a defeatable text scan on `Bash`
  (D2). This is a raised cost, not a closed loop; see Step 3's *What the seal
  does and does not prove*.

Sanctioned write routes (`node bin/cli.js --update`, `bin/harness-integrity.sh
--rotate`) pass naturally because their command text does not spell the
protected paths. Document that in the **header**, not in the refusal (Step 5).

**Spec 3 side effect, recorded not taken (D11).** This gate is the first
mechanical denial in the system covering the **Bash** half of a protected-path
write. Spec 3's M4 is blocked on precisely that, and its OQ2 doubts it is
reachable. Whoever evaluates M4's precondition should test against this gate.
**No part of M4 is in scope here.**

**Acceptance criteria**

```sh
# C2.1  script exists, executable, and registered on both matchers
test -x hooks/scripts/harness-integrity-gate.sh
test "$(jq '[.hooks.PreToolUse[] | select(.matcher=="Write|Edit") | .hooks[]
             | select(.command|test("harness-integrity-gate"))] | length' hooks/hooks.json)" = 1
test "$(jq '[.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[]
             | select(.command|test("harness-integrity-gate"))] | length' hooks/hooks.json)" = 1

# C2.2  CONFIGLESS, and exempt from reviewGating.mode (spec 6 D0: wiring the
#       switch in is "a defect"). Both halves asserted, because the second is
#       the one a later D unit could break.
test "$(grep -cF 'persona-config.json' hooks/scripts/harness-integrity-gate.sh)" = 0
test "$(grep -cF 'reviewGating' hooks/scripts/harness-integrity-gate.sh)" = 0

# C2.3  hot-path ordering: the raw literal `case` precedes any subshell, `jq`,
#       or per-word loop. Pinned as a line-number ordering assertion in the
#       suite, not by eye.
bash tests/harness-integrity-gate.test.sh

# C2.4  the suite must cover, at minimum:
#   - Write to .claude/persona-config.json                -> exit 2   (baseline 0)
#   - Bash `: > .claude/review-audit.log` (x4 logs)       -> exit 2   (baseline 0)
#   - Bash `rm -f .claude/persona-config.json`            -> exit 2   (baseline 0)
#   - GUARD Bash `node bin/cli.js --update`               -> exit 0
#   - GUARD Bash `cat .claude/persona-config.json`        -> exit 0
#   - GUARD Bash `jq -r .gatedAgents .claude/persona-config.json` -> exit 0
#   - GUARD Write to .claude/settings.local.json          -> exit 0
#   - GUARD the gate still denies with NO persona-config.json present at all
#     (this is the configless property, and it is what D0 depends on)
#   - a mutation control: deleting the Write/Edit branch, and separately the
#     Bash branch, each kills a disjoint, non-empty set of the suite's cases.
#
#   SET B (Write/Edit only) -- the gate-registration surface:
#   - Write to hooks/hooks.json                           -> exit 2   (baseline 0)
#   - Write to .claude/settings.json                      -> exit 2   (baseline 0)
#   - Write to hooks/scripts/harness-integrity-gate.sh    -> exit 2   (baseline 0)
#   - Edit (not Write) to each of the three               -> exit 2
#   - GUARD Bash `sed -i s/x/y/ hooks/hooks.json`         -> exit 0
#     (the ratified ADR-0025 gap: Set B is deliberately NOT on the Bash branch.
#      Assert it explicitly so a later unit cannot quietly add it and inherit
#      the 1,183-occurrence false-positive surface measured above.)
#   - GUARD Bash `bash tests/validate.sh`                 -> exit 0
#   - GUARD Bash `grep -r hooks/scripts/`                 -> exit 0
#   - asymmetry mutation control: adding Set B to the Bash branch must make the
#     two Bash GUARDs above fail. Recorded as the proof the asymmetry is real
#     and not an accident of ordering.

# C2.5  the standalone-scaffold registration path carries it too
node --test tests/cli-hook-propagation.test.js

# C2.6  mirror + hashes + exec bit
node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`, all measured:* all three existing `Write|Edit` gates exit
`0` on a `Write` to `persona-config.json`; `reviewed-path-gate.sh` exits `0` on
`: >` for all four logs; both `jq` registration queries return `0` while the same
queries for `human-decision-gate` return `1` and `1` (control, proving the query
shape).

**Set B baseline — the three new denials, measured across every existing
`Write|Edit` gate (9 probes, all `exit=0`):**

```
                                          protected-  reviewed-   human-
                                          paths       path-gate   decision
hooks/hooks.json                          0           0           0
.claude/settings.json                     0           0           0
hooks/scripts/harness-integrity-gate.sh   0           0           0
```

Nothing in the harness opposes any of the three today. The four guards are green
today and must stay so: `sed -i s/x/y/ hooks/hooks.json` → `0`,
`bash tests/validate.sh` → `0`, `grep -r hooks/scripts/` → `0`, and
`Write .claude/settings.local.json` → `0`.

**Do not touch:** `reviewed-path-gate.sh` or `human-decision-gate.sh` — this is a
new sibling, not an extension of either. Do not add either gate to
`protectedPaths` or remove it (that list's contents are an operator decision
recorded in `[[escalation-vs-protectedpaths]]`).

---

### Step 3 — Append-only seals: make erasing the deterrent detectable

New `hooks/scripts/lib/audit-log.sh`:

- `audit_append <log> <line>` — appends, then rewrites the sidecar `<log>.seal`
  holding `lines=<N> sha256=<hash of the whole file>`.
- `audit_seal_verify <log>` → `ok` | `truncated` | `missing-seal` | `absent` |
  `unverifiable`. Verification: the file has **≥ N** lines and the `sha256` of
  its **first N lines** equals the sealed hash. Appends by a writer that did not
  reseal are therefore fine; truncation, deletion and mid-file rewriting are not.
- `audit_rotate <log>` — moves the log to
  `.claude/audit-archive/<utc>-<name>.log`, starts a fresh log whose **first
  line** records the archived file's name, line count and `sha256`, and seals it.
  This is what makes the chain continuous, and why `truncated` can be read as
  "unsanctioned" (R3).

Convert every existing append site to `audit_append`. **Re-measured at
`e685a01` (2026-08-26), after spec 3's M2 core extraction — see the correction
at the end of this step** — **23 sites across nine files**:
`lib/stop-gate-core.sh` 13, `reviewed-path-gate.sh` 2, `task-gate.sh` 2, and one
each in `dispatch-hygiene.sh`, `human-decision-gate.sh` (`deny()`),
`lib/microworld-rerun-core.sh` (`log()`), `lib/reviewer-route-gate-core.sh`,
`lib/agent-identity.sh` (`identity_drift_log()`, shared by three gates) and
`lib/microworld-queue.sh` (`_log_result()`). Re-derive with C3.2's grep rather
than trusting these counts.

New `bin/harness-integrity.sh` — read-only report, always `exit 0`, one line,
same contract as `marker-commit-check.sh`:

```
harness-integrity=<ok|drift|tampered|unverifiable> config=<ok|drift|missing> logs=<ok|LIST>
```

**What the seal does and does not prove — read this before writing the header.**
The seal is **circular in the weak direction**, and the spec says so rather than
letting the implementer discover it:

- **It detects:** accidental truncation, a crashed or partial write, a `git
  clean` that removed the log, an out-of-band edit by a tool that does not know
  about the seal, and an adversary who truncates the log **and does not reseal**.
- **It does NOT detect:** an adversary who truncates *and* reseals. Resealing is
  one `sha256sum` plus a two-line rewrite. The only thing standing between an
  agent and a valid forged seal is Step 2's **`Bash` text scan** over the `.seal`
  path — the same defeatable class F3 documents and D2 accepts (variable
  assembly, glob metacharacters, `cd`-relative writes). A determined resealer
  wins.
- **Therefore the honest claim is:** the seal **prices** the attack — it converts
  a one-call `: > log` into a two-step operation that must also model the seal
  format — and it **catches accidents reliably**. It is tamper-*evident* against
  carelessness, not tamper-*proof* against intent. No criterion below asserts
  otherwise, and the script header must carry this paragraph rather than a
  stronger summary.

This is the same honesty the three existing hook headers already practise —
*"the deterrent, not a guarantee"* — extended to the mechanism that replaces
them, and it is why Step 4's git-anchored config check (which an in-session
write genuinely cannot forge) carries the load that the seal cannot.

**Adapter ports (R7).** `stop-gate.sh`, `reviewer-route-gate.sh` and
`microworld-rerun.sh` are ported, so `lib/audit-log.sh` needs copying into both
adapter `lib/` directories and the append sites in all six ported scripts need
hand-editing.

**Acceptance criteria**

```sh
# C3.1  library and CLI exist
test -f hooks/scripts/lib/audit-log.sh
test -x bin/harness-integrity.sh

# C3.2  every append site goes through audit_append; no raw `>>` redirection to
#       an audit log survives under hooks/scripts/. TWO HALVES, both required.
#
#   (a) ATTRIBUTION -- a per-file check over every file that holds an append site
#       today, so a failure names the file whose conversion was missed. The loop
#       covers each gate's entry point AND its extracted lib/<name>-core.sh,
#       because M2 moved stop-gate's, microworld-rerun's and reviewer-route-gate's
#       append logic into their cores after this spec was finalized. The
#       `[ -f ] || continue` keeps the loop correct for the four gates that were
#       not extracted and have no core.
#
#   (b) BACKSTOP -- a sweep proving no OTHER file under hooks/scripts/ holds one.
#       This is what stops the criterion going silently vacuous the next time a
#       site moves, which is exactly how (a)'s file list went stale once already.
#       hooks/scripts/lib/audit-log.sh is the single sanctioned holder of a raw
#       `>>` (inside audit_append) and is the sweep's only exemption.
#
#       The pattern is `>>` + optional space + a double quote, NOT an enumeration
#       of destination variable names. The old enumeration
#       ($audit|$review_audit|$project_dir) was broken by M2's port-neutral
#       rename of ${project_dir}/.claude to ${dot}, which silently dropped
#       stop-gate's wip-audit.log site (12 of its 13 matched). Measured at
#       e685a01: every `>>` redirection under hooks/scripts/ targets an audit
#       log, and the only two `>>` mentions that are prose rather than
#       redirection -- human-decision-gate.sh:282 and lib/benign-command.sh:145 --
#       do not match, so the wider pattern costs no false positive.

# (a) attribution: entry point and extracted core, each individually provable
for f in stop-gate dispatch-hygiene reviewed-path-gate human-decision-gate \
         task-gate microworld-rerun reviewer-route-gate; do
  for p in "hooks/scripts/$f.sh" "hooks/scripts/lib/$f-core.sh"; do
    [ -f "$p" ] || continue
    test "$(grep -cE '>>[[:space:]]*"' "$p")" = 0 || { echo "RAW APPEND in $p"; exit 1; }
  done
done
# shared libraries, each reached by three or more of the gates above and named
# after none of them: agent-identity.sh's identity_drift_log() (called from
# reviewed-path-gate.sh, reviewer-route-gate.sh and its core, and
# stop-gate-core.sh) and microworld-queue.sh's _log_result() (the deferred
# writer for the microworld audit log). Neither is reachable by the loop above.
for p in hooks/scripts/lib/agent-identity.sh hooks/scripts/lib/microworld-queue.sh; do
  test "$(grep -cE '>>[[:space:]]*"' "$p")" = 0 || { echo "RAW APPEND in $p"; exit 1; }
done

# (b) backstop: nothing else under hooks/scripts/ holds one either
test "$(grep -rlE '>>[[:space:]]*"' hooks/scripts/ \
        | grep -vF 'hooks/scripts/lib/audit-log.sh' | wc -l)" = 0

# C3.3  detection behaviour, over a fixture (the suite):
#   - seal, append, verify                     -> ok
#   - seal, truncate to 0 bytes, verify        -> truncated
#   - seal, delete the log, verify             -> absent
#   - seal, delete the .seal, log non-empty    -> missing-seal
#   - seal, rewrite line 1 in place, verify    -> truncated
#   - seal, append 10 lines without resealing  -> ok      (GUARD)
#   - audit_rotate, then verify                -> ok      (GUARD, and the new
#     log's line 1 names the archive's sha256)
bash tests/audit-seal.test.sh

# C3.4  the CLI reports it
t=$(mktemp -d); bash tests/fixtures/seed-truncated-log.sh "$t"
bash bin/harness-integrity.sh "$t" | grep -qF 'logs=truncated:review-audit.log'
rm -rf "$t"

# C3.5  mutation proof: with audit_seal_verify's first-N-lines hash comparison
#       replaced by a bare `test -f`, the truncated and rewrite cases in
#       tests/audit-seal.test.sh both flip to `ok`. Both kill counts recorded.
#       SCOPE OF THIS PROOF, stated so it is not over-read: it proves the
#       verifier is not vacuous. It does NOT prove resistance to an adversarial
#       RESEALER, which the seal structurally does not have (see "What the seal
#       does and does not prove"). No criterion in this step attempts that.

# C3.6  the honest-strength statement is IN the shipped header, not only in this
#       plan. Survival pins, so a later tidy-up cannot quietly upgrade the claim.
grep -qiF 'does not detect' hooks/scripts/lib/audit-log.sh
grep -qiF 'reseal' hooks/scripts/lib/audit-log.sh
# and the over-claim is absent from the shipped file
test "$(grep -ciE 'tamper-proof|cannot be forged|guarantees the log' \
        hooks/scripts/lib/audit-log.sh)" = 0

# C3.7  adapter parity
test "$(ls adapters/*/hooks/scripts/lib/audit-log.sh | wc -l)" = 2
bash tests/adapter-stop-gate-parity.test.sh

node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`:* `hooks/scripts/lib/audit-log.sh`,
`bin/harness-integrity.sh`, `tests/audit-seal.test.sh` all absent — still true at
`e685a01`.

*C3.2 re-measured at `e685a01` (2026-08-26), after M2's core extraction:* the
rewritten criterion is RED **nine** times over — `lib/stop-gate-core.sh` 13,
`reviewed-path-gate.sh` 2, `task-gate.sh` 2, and one each in
`dispatch-hygiene.sh`, `human-decision-gate.sh`, `lib/microworld-rerun-core.sh`,
`lib/reviewer-route-gate-core.sh`, `lib/agent-identity.sh` and
`lib/microworld-queue.sh`. Its per-file form (rather than one recursive sweep) is
what makes each conversion individually provable; the backstop sweep is what
keeps that per-file list honest. Non-vacuity was proved by execution, not
asserted: over a fixture with every one of the 23 sites converted the criterion
goes GREEN, and re-introducing a single raw append in each of the nine files in
turn kills it nine times, naming the right file each time — with a tenth
re-introduction, in a file on no list (`lib/graph-update-core.sh`), caught by the
backstop alone.

**Do not touch:** the audit-log **line formats**. Every existing consumer
(`bin/microworld-dashboard/audit-log.js`, `bin/marker-commit-audit.sh`,
`tests/marker-commit-audit.test.sh`) must keep parsing today's lines
byte-for-byte. `audit_append` changes the write *path*, never the written *text*.

**Correction (2026-08-26) — C3.2's target file set only. Step 3's substance is
unchanged, and no other criterion in this document is touched.**

C3.2 as originally written greped `hooks/scripts/$g.sh` for seven gate names.
After this spec was finalized at `09cc304`, spec 3's **M2** work (`gh410` tier 1,
`gh411`/`gh412` tier 2 — all three reviewer-PASSed and correctly implemented; the
staleness is this criterion's, not theirs) extracted the port-invariant decision
logic of several hooks into sourced `hooks/scripts/lib/<name>-core.sh` files.
Three of C3.2's seven targets moved with it: `stop-gate.sh`'s appends (13) now
live in `lib/stop-gate-core.sh`, `microworld-rerun.sh`'s (1) in
`lib/microworld-rerun-core.sh`, and `reviewer-route-gate.sh`'s (1) in
`lib/reviewer-route-gate-core.sh`. Their entry-point files now hold **zero**
appends, so the criterion read `0` for all three **whether or not the conversion
to `audit_append` had happened** — vacuous for three of seven. The `lead-programmer`
dispatched on `gh415` stopped and escalated rather than implement against it,
which was the right call. The four gates M2 did **not** extract —
`dispatch-hygiene.sh`, `reviewed-path-gate.sh`, `human-decision-gate.sh`,
`task-gate.sh` — were always checkable as written and their checks are unchanged
in intent.

Two further defects surfaced while verifying that claim rather than trusting it,
and both are fixed in the same rewrite because leaving either would ship a
criterion already known to be partly vacuous:

1. **The destination-variable enumeration was itself broken by M2.** The old
   pattern matched `$audit|$review_audit|$project_dir`. M2's port-neutral rename
   of `${project_dir}/.claude` to `${dot}` dropped `stop-gate`'s
   `wip-audit.log` append out of the pattern — 12 of its 13 sites match, and the
   one that does not is the WIP audit trail. Enumerating destination spellings
   was the wrong shape (`[[branch-agreement-criterion]]`); the rewrite asserts
   *no quoted `>>` redirection at all*, which is sound here because every `>>`
   redirection under `hooks/scripts/` targets an audit log, verified at
   `e685a01`.
2. **Two shared libraries with real append sites were on no list at all.**
   `lib/agent-identity.sh`'s `identity_drift_log()` — one append, reached by
   `reviewed-path-gate.sh`, `reviewer-route-gate.sh` (entry point *and* core) and
   `stop-gate-core.sh` — was present at `09cc304` and simply missed by the
   original inventory. `lib/microworld-queue.sh`'s `_log_result()` — one append
   to the microworld audit log — did not exist at `09cc304` and arrived
   post-baseline. Neither is named after a gate, so neither was reachable by a
   loop over gate filenames.

The structural fix is the **backstop sweep**, half (b) of the rewritten
criterion. Half (a) still names files, so a failure still says which conversion
was missed; half (b) fails on any file under `hooks/scripts/` that the list does
not know about, so the *next* extraction cannot make this criterion silently
vacuous the way M2's did.

**Two knock-ons flagged, deliberately not taken as scope here** (both are for
whoever dispatches Step 3; neither changes a criterion):

- **The adapter port obligation moved the same way.** The paragraph above and
  C3.7 name `stop-gate.sh`, `reviewer-route-gate.sh` and `microworld-rerun.sh`;
  measured at `e685a01`, both ports' append sites now sit in
  `lib/stop-gate-core.sh` (13 each), `lib/microworld-rerun-core.sh`,
  `lib/reviewer-route-gate-core.sh`, `lib/agent-identity.sh` and
  `lib/microworld-queue.sh`, plus one remaining in the codex port's own
  `stop-gate.sh`. C3.7 is left as written — it asserts library presence and the
  behavioural parity suite, both still correct — but the hand-edit list is
  today's file layout, not the baseline's.
- **A sanctioned rotator already exists, and R3 does not know about it.**
  `bin/human-review-cleanup.sh:166-212` already rotates all four audit logs as
  part of the Sweep (`CONTEXT.md`, *Log rotation / archive*, unit #409), and it
  was present at `09cc304`. R3 anticipated the hazard in the abstract but assumed
  rotation would arrive with `audit_rotate`; in fact `audit_rotate` must either
  replace that mechanism or be integrated with it, or the first `--apply` sweep
  after Step 3 lands will `mv` a sealed log out from under its `.seal` and the
  seal check will report `absent` on a legitimate, already-shipped operation.
  Raised here, unresolved, because resolving it is a Step 3 design decision and
  this amendment is scoped to C3.2.

---

### Step 4 — Disarm-surface drift: detect a weakened config, in-session

Extend `bin/harness-integrity.sh` with a config comparison that scans no command
text (D2). Read the session baseline sha from
`.claude/.session-baseline.<session-id>`, extract the **disarm surface** from
both `git show <sha>:.claude/persona-config.json` and the working tree, and
report per-field drift.

**Disarm surface** — the fields whose weakening turns a gate off:
`gatedAgents`, `protectedPaths`, `personaSelection`, `dispatchHygiene.mode`,
`dispatchHygiene.requireContract`, `markerCommitCheck.mode`, `humanReviewMode`,
`testAndLintCommand`, and **`reviewGating.mode`** (spec 6, D6 above).
Explicitly **excluded**: `fileHashes`, `pluginVersion`, `substitutions` —
`bin/cli.js --update` rewrites those routinely and they carry no gating
authority.

**Absent-key semantics matter here (D6).** `reviewGating.mode` does not exist at
`09cc304` (verified: `jq -r 'has("reviewGating")'` → `false`), and absent means
`enforce` per spec 6's A24b. The extractor must therefore normalize each field to
its *effective* value — absent → documented default — so the transition
absent → `"off"` registers as drift. An extractor comparing only present keys
would miss the single most consequential edit D introduces.

Wire it:
- `session-start.sh` — on `drift`, emit one `additionalContext` line naming the
  drifted fields. Report only (RD3).
- `stop-gate.sh` — a **gated agent's** `SubagentStop` with `config=drift`
  **blocks**, with the existing `defer:`/`skip:` escape-hatch shape (`:365-391`)
  as the documented override. Main-session `Stop` never blocks on this (RD3).

**Acceptance criteria**

```sh
# C4.1  drift is detected and attributed to the right field
bash tests/harness-config-drift.test.sh

# C4.2  the suite must cover:
#   - working tree == baseline                          -> config=ok   (GUARD)
#   - gatedAgents [] vs baseline ["lead-programmer"]     -> drift fields=gatedAgents
#   - dispatchHygiene.mode "off" vs "warn"              -> drift fields=dispatchHygiene.mode
#   - protectedPaths [] vs a non-empty baseline          -> drift fields=protectedPaths
#   - reviewGating ABSENT in baseline, "off" in tree     -> drift fields=reviewGating.mode
#     (THE SPEC-6 CASE: absent normalizes to "enforce", so this is a weakening.
#      A present-keys-only comparison misses it -- assert it explicitly.)
#   - reviewGating absent in BOTH                        -> config=ok   (GUARD)
#   - reviewGating "enforce" in tree, absent in baseline -> config=ok   (GUARD:
#      same effective value, not a weakening)
#   - config file deleted                                -> config=missing
#   - fileHashes rewritten, everything else equal        -> config=ok   (GUARD)
#   - a drift COMMITTED mid-session (baseline sha still the older one)
#                                                        -> config=drift (GUARD:
#     the "commit it to hide it" case must NOT report ok)

# C4.3  stop-gate blocks a gated SubagentStop under drift, and does not block
#       the main-session Stop under the same drift (RD3)
bash tests/stop-gate-config-drift.test.sh

# C4.4  session-start reports without blocking
bash tests/harness-config-drift.test.sh --session-start

node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`:* no drift check exists anywhere;
`jq -r 'has("reviewGating")' .claude/persona-config.json` returns `false`;
`git diff --stat HEAD -- .claude/persona-config.json` is empty and the session
baseline equals `HEAD`, so a fresh fixture is required for every case above.

**Ordering (R6):** land this **before** spec 6's flip unit, or pin the baseline
to a pre-flip commit and record that choice in the PASS marker.

**Do not touch:** the set of gated agents, or any actual config value in this
repo. This step reads the config; it never writes it. Adding `reviewGating` to
the config is **spec 6's** unit, not this one.

---

### Step 5 — Refusal-message disclosure hygiene: state the rule, not the technique

*(RD4: replace, do not merely delete. The conditional drop does not fire — under
spec 6's D0 the gates remain the shipped product, so the disclosure is live for
every downstream adopter.)*

Rewrite the denial stderr of `reviewed-path-gate.sh` (`:270`, `:278`, `:285`) and
`human-decision-gate.sh` (`deny()`, `:270-298`) so each message contains
**exactly three things**: what was blocked; the one sanctioned route for *this*
gate; and a flat, technique-free prohibition on everything else.

Removed from runtime stderr (retained in the file headers and `docs/design.md`,
D5):

- the generalization *"…keep the path OUT of the command text entirely"*;
- the named technique *"Splitting the path across shell variables, or otherwise
  rephrasing so the command text never spells it"*;
- the enumeration of which spellings **are** recognized (*"quote-split,
  dot-segment, doubled-slash and `..` traversal"*) — a map of where the scan does
  and does not reach;
- the cross-reference telling one gate's blocked caller what the *other* gate
  sanctions;
- the rationale clause *"whose command text then never spells the path"* attached
  to the `git commit -F` route.

Retained verbatim, because they restore real capability rather than teaching a
bypass: the `git commit -F <file>` route, the `grep -r` route, the sanctioned
heredoc marker-write template with its four rules, and the
`rm -rf .claude/human-review/<task-id>` packet-discard route.

Replacement prohibition sentence (technique-free), one per gate, e.g.:

> Any other route to this path is a self-authorized bypass whether or not this
> gate blocks it. If the sanctioned route does not fit, report the block and
> wait.

New `tests/refusal-disclosure.test.sh` asserting, **against the gates' runtime
stderr only** (D8), that every banned phrase is absent from every denial path and
every required phrase is present.

**Acceptance criteria**

```sh
# C5.1  banned disclosure phrases are absent from runtime denial stderr. All
#       eleven phrases below were measured at 09cc304 and every one returns
#       exactly 1 today. Probes live in the suite so the criterion command
#       itself never spells a protected path (not hypothetical: two of this
#       spec's own baseline probes were blocked for doing so).
bash tests/refusal-disclosure.test.sh

# C5.2  the suite must assert ABSENT, in each gate's denial stderr:
#   rpg: 'OUT of the command text entirely'            (baseline 1)
#   rpg: 'quote-split, dot-segment, doubled-slash'     (baseline 1)
#   rpg: 'human-decision-gate.sh'                      (baseline 1)
#   rpg: 'never spells the path'                       (baseline 1)
#   hdg: 'Splitting the path across shell variables'   (baseline 1)
#   hdg: 'reviewed-path-gate.sh'                       (baseline 1)
#   hdg: 'never spells DECISION'                       (baseline 1)

# C5.3  the suite must assert PRESENT (GUARDs; all baseline 1 -- capability must
#       not be removed along with the disclosure):
#   rpg: 'git commit -F'      rpg: 'grep -r'
#   hdg: 'the delimiter is single-quoted'
#   hdg: 'rm -rf .claude/human-review/'
#   both: the new technique-free prohibition sentence

# C5.4  the disclosure did not simply move to another runtime channel: the two
#       gates' stdout is empty on every denial path, and no new file is written.

# C5.5  GUARD: neither gate's VERDICT changes. Both existing suites still pass
#       with identical assertion counts to the pre-step run (record both numbers).
bash tests/reviewed-path-gate.test.sh
bash tests/human-decision-gate.test.sh

# C5.6  the removed content still exists in the headers (survival pins, not
#       deletion checks -- [[verify-own-criteria-nonvacuous]] trap six)
grep -qF 'STILL OPEN' hooks/scripts/reviewed-path-gate.sh
grep -qF 'STILL OPEN' hooks/scripts/human-decision-gate.sh

node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`,* measured against each gate's real denial stderr — all
eleven counts are exactly `1`:

```
rpg  OUT of the command text entirely          1   BANNED
rpg  quote-split, dot-segment, doubled-slash   1   BANNED
rpg  human-decision-gate.sh                    1   BANNED
rpg  never spells the path                     1   BANNED
rpg  git commit -F                             1   REQUIRED (guard)
rpg  grep -r                                   1   REQUIRED (guard)
hdg  Splitting the path across shell variables 1   BANNED
hdg  reviewed-path-gate.sh                     1   BANNED
hdg  never spells DECISION                     1   BANNED
hdg  the delimiter is single-quoted            1   REQUIRED (guard)
hdg  rm -rf .claude/human-review/              1   REQUIRED (guard)
```

Note the deliberate pairing: `git commit -F` is REQUIRED while
`never spells the path` — the clause currently attached to it — is BANNED. The
route survives; its rationale does not. Same shape for
`rm -rf .claude/human-review/` and `never spells DECISION`.

**Do not touch:** either gate's matching logic, or any line of the textual-gate
corpus (spec 3's M4). This step changes only strings emitted on the denial path.
C5.5 is what proves it.

---

### Step 6 — `marker-verify.sh`: re-run the criteria the marker claims it ran

*(RD1: `--list` default, explicit `--execute`, never hook-wired.)*

New `hooks/scripts/marker-verify.sh <task-id> [project-dir] [--execute]`,
modelled line-for-line on `marker-commit-check.sh`: always `exit 0`, exactly one
output line, never decides policy for its caller, **never registered in any
hook**.

- Default (`--list`): parse the marker's `criteria:` field, split on `;`, print
  `marker-verify=listed unit=<id> criteria=<n>`. No execution.
- `--execute`: run each criterion from the project root at the marker's cited
  `commit:` (checked out into a throwaway worktree, so a live tree cannot
  contaminate the result), print
  `marker-verify=<ok|mismatch|unverifiable> unit=<id> ran=<n> failed=<n> [failing=<i,j>]`.
- `unverifiable` covers: no marker, no `criteria:` field, an unreachable
  `commit:`, or no git worktree.

Extend `bin/marker-commit-audit.sh` (or a sibling `bin/marker-audit.sh`) to sweep
every `.pass` marker in `--list` mode by default.

**Acceptance criteria**

```sh
# C6.1  exists, executable, and registered NOWHERE (the safety property of RD1,
#       and a GUARD that must stay green forever)
test -x hooks/scripts/marker-verify.sh
test "$(grep -cF 'marker-verify' hooks/hooks.json)" = 0
test "$(grep -rcF 'marker-verify' .claude/settings.json templates/settings-fragment.json | \
        awk -F: '{s+=$2} END {print s+0}')" = 0

# C6.2  --list never executes: a fixture marker whose criteria: is
#       `touch SENTINEL` leaves no SENTINEL behind in --list mode, and does
#       create one under --execute. Both halves asserted.
bash tests/marker-verify.test.sh

# C6.3  the suite must cover:
#   - marker with 3 passing criteria      -> marker-verify=ok ran=3 failed=0
#   - marker with 1 of 3 failing          -> marker-verify=mismatch ran=3 failed=1 failing=2
#   - marker with no criteria: field      -> marker-verify=unverifiable
#   - marker with unreachable commit:     -> marker-verify=unverifiable
#   - absent marker                       -> marker-verify=unverifiable
#   - --execute runs in a throwaway worktree: a dirty live tree does not change
#     the verdict (GUARD; this is what makes the result about the commit)

# C6.4  the sweep tool defaults to --list
bash bin/marker-audit.sh . | grep -qE '^marker-verify=listed|^ok=[0-9]+'

node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`:* `hooks/scripts/marker-verify.sh` absent; C6.1's two
registration greps both return `0` today and are GUARDs that must stay `0`.
Row 3 of the trust map is unchecked by anything in the repo.

**Do not touch:** `task-gate.sh`'s `marker_valid()`. Tightening the *gate* on
marker substance is a separate policy decision with a real deadlock risk (a
reviewer whose criteria are slow or environment-dependent could not write a
marker at all). This step ships the verifier as an operator/reviewer tool;
making it a gate is deliberately deferred.

---

### Step 7 — Substance floor on H4, and visibility on the irreducible self-reports

Two independent conversions from the F4 map, sized as one unit because both are
small edits to already-open files.

**7a — H4 gains a body check.** `dispatch-hygiene.sh:341-360` currently matches
eight `## ` headings as plain substrings. Extend it: each heading must be
followed by at least one non-blank line that is not itself a `## ` heading,
before the next `## ` or EOF. Still form, not substance — but it kills the exact
case the file's own comment (`:64-68`) names. Config-driven as today
(`requireContract`, `mode`); no new config key.

**7b — Self-report accounting.** Add `bin/harness-integrity.sh --self-report`,
printing one line tallied since the session baseline sha:

```
self-report wip-sentinels=<n> defers=<n> skips=<n> abandoned-unrecorded=<n>
```

`abandoned-unrecorded` counts unit ids appearing in a `skip:` line in
`wip-audit.log`/`review-audit.log` with **no** `.pass`, `.fail`, `.blocked` or
`.escalated` marker on disk — the one *consequence* of a `skip:` that is
mechanically checkable even though its *reason* never will be. Surfaced at
`session-start.sh` when any tally is non-zero.

**Acceptance criteria**

```sh
# C7.1  H4 now fires on nine headings with empty bodies.
#       TWO-ASSERTION FORM, and the first half is load-bearing:
#       tests/dispatch-hygiene.test.sh ALREADY EXISTS AND ALREADY PASSES
#       (measured exit 0 at 09cc304), so citing the suite alone would be
#       vacuous -- it would be reported satisfied without the work being done
#       ([[verify-own-criteria-nonvacuous]], trap eleven). Pin the new case by
#       sentinel first, then require the suite green.
test "$(grep -ciE 'empty body|body-empty|blank body' tests/dispatch-hygiene.test.sh)" -ge 1
bash tests/dispatch-hygiene.test.sh

# C7.2  the suite must cover:
#   - all nine elements, every body empty              -> H4 fires   (baseline: silent)
#   - all nine elements, one body empty                -> H4 fires, naming that heading
#   - all nine elements, every body filled             -> silent     (GUARD)
#   - a body that is only a nested '### ' heading      -> H4 fires
#   - requireContract:false                            -> silent     (GUARD)
#   - mutation proof: reverting the body check drops the suite by a recorded,
#     non-zero number of cases

# C7.3  self-report tally, over a fixture with a known seeded history
bash tests/self-report-tally.test.sh

# C7.4  the suite must cover: a skip:ped unit WITH a .fail marker is not counted
#       as abandoned-unrecorded (GUARD), and one WITHOUT any marker is.

node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`:* a prompt with `Unit: u1` plus all eight headings and
every body empty produces **zero** `H4` lines from `dispatch-hygiene.sh`.

**Do not touch:** H1, H2, H3, the `dispatchHygiene` config schema, or the
`mode`/`requireContract` semantics. 7a widens one existing check; it adds no key
and no new failure class.

---

### Step 8 — `docs/trust-model.md`: make the self-report surface enumerated, not implicit

Publish the F4 map as a durable document with one row per trust-critical claim,
each row naming either the script that mechanically checks it or the literal
token `self-reported`. Add a bijection test so a future gate cannot be added
without being classified.

**Two additions requested by spec 6**, both belonging here rather than in D:

1. **The credential-split upgrade path.** D's RD3 accepted advisory-only for the
   CI layer, with option (b) — a fine-grained agent PAT carrying
   `contents: write` + `pull_requests: write` but **not** `administration` or
   `workflows` — recorded as the only configuration that delivers the property D
   claimed. D asks that this live in this spec's trust-model document. Record it
   as a documented upgrade path with its cost (a token-management workflow the
   operator does not have today), **not** as a claimed current property.
2. **A row for `reviewGating.mode`**, marked as checked by Step 4, so the key D
   introduces cannot be added to the config without appearing in the map.

**Acceptance criteria**

```sh
# C8.1  the document exists and classifies every hook-registered script
test -f docs/trust-model.md
node --test tests/trust-model-bijection.test.js

# C8.2  the test must assert, in both directions:
#   - every *.sh under hooks/scripts/ (excluding lib/) appears in the table
#   - every script named in the table exists on disk
#   - every row's "checked by" cell is either an existing path or the literal
#     token `self-reported`
#   - the count of `self-reported` rows is asserted EXACTLY, so converting one
#     without updating the doc fails the test (a survival pin, not a ceiling)

# C8.3  the two spec-6 additions are present
grep -qF 'reviewGating.mode' docs/trust-model.md
grep -qiF 'fine-grained' docs/trust-model.md
grep -qiF 'advisory' docs/trust-model.md

# C8.4  the credential split is documented as an UPGRADE PATH, not a current
#       property. Absence check on over-claiming, scoped to this file only
#       (never docs/plans/**, which quotes the phrase to ban it -- D8).
test "$(grep -cF 'the agent cannot edit' docs/trust-model.md)" = 0

# C8.5  mutation proof: adding a stub hooks/scripts/zz-probe.sh makes
#       tests/trust-model-bijection.test.js exit 1; removing it restores exit 0.

bash tests/validate.sh
```

*Baseline at `09cc304`:* `docs/trust-model.md` absent; no test enumerates
`hooks/scripts/`. C8.4 is a GUARD (`0` today by virtue of the file not existing)
and becomes meaningful the moment the file does.

**Do not touch:** `CONTEXT.md` or the glossary — new terms introduced here
(`disarm surface`, `audit seal`, `countersign`, `authority`) are routed to
`scribe` in the hint below, per ADR-0003.

---

### Step 9 — Break the microworld self-grading chain: reviewer countersign + `authority=` provenance

*(RD5: `.countersign` lives in `.claude/reviewed/`, failing safe to
`authority=self`. Spec 6's D0 keeps the marker directory, so this stands.)*

Anchor bundle-check provenance in the **one authority boundary the system already
enforces mechanically** — the `.claude/reviewed/` identity grant that only the
reviewer holds (`reviewed-path-gate.sh:232-234`, `:274-280`).

**9a — A new marker kind.** The reviewer may write
`.claude/reviewed/<slug>.countersign` containing
`COUNTERSIGN <slug> <UTC ISO-8601> runsh: <sha256 of microworlds/<slug>/run.sh>`.
Writing it attests that the reviewer **read `run.sh` and re-derived what it
checks** — not that it re-authored it. Countersigning is **optional**; the
default stays uncountersigned, and uncountersigned is labelled honestly rather
than treated as an error. Add `countersign` to `human-decision-gate.sh:64`'s
suffix alternation so the sanctioned heredoc template can write it (verified RED:
that write is denied today). Do **not** add it to `stop-gate.sh:240-241`'s
verdict globs.

**9b — Provenance in the audit line.** `microworld-rerun.sh` computes
`sha256sum` of the bundle's `run.sh` and appends an **optional trailing field**:
`authority=reviewer` when a `.countersign` marker for that slug carries a
matching `runsh:` hash, `authority=self` otherwise — including no countersign at
all, and a countersign whose hash no longer matches because `run.sh` was edited
afterwards. Editing `run.sh` invalidates its own countersign automatically; that
is the point.

**9c — The parser and the dashboard.** Extend
`bin/microworld-dashboard/audit-log.js:47`'s anchored regex with an optional
`authority` capture (old lines must still parse), pass it through `discover.js`,
and render it in `index.html` as an explicit **text label**, not a colour: only
`authority=reviewer` gets the plain green dot; `authority=self` gets the dot plus
a visible `unverified — implementer-authored check` label at all three render
sites (`:264`, `:318`, `:736`).

**9d — Protocol and ports.** Add the countersign route and the `authority`
vocabulary to `templates/persona-protocol.md`'s microworld section, regenerate
the `.claude/` mirror, and **hand-edit both adapter ports** of
`microworld-rerun.sh` plus their protocol fragments, with literal-string probes
added to `tests/adapter-protocol-parity.test.js`'s probe array (R7).

**Acceptance criteria**

```sh
# EVERY suite named in this step ALREADY EXISTS AND ALREADY PASSES at 09cc304
# (all six measured exit 0). Citing any of them alone is vacuous
# ([[verify-own-criteria-nonvacuous]], trap eleven), so each criterion is a
# TWO-ASSERTION pair: a sentinel proving the new case was added, then the suite.
# Sentinel counts measured at 09cc304 are given; each is currently 0.
# Note the attribution trap avoided in C9.5: a bare `authority` grep against
# adapter-protocol-parity.test.js returns 2 TODAY, from unrelated comments
# ("authority line", "authority constraint"). The pin uses `authority=` (with
# the equals sign), measured 0.

# C9.1  the sanctioned template accepts a .countersign target (baseline: exit 2)
#       and the .pass case is unchanged (GUARD: baseline exit 0)
test "$(grep -cF 'countersign' tests/human-decision-gate.test.sh)" -ge 1   # baseline 0
bash tests/human-decision-gate.test.sh

# C9.2  authority is emitted, and is derived from the countersign, not declared
test "$(grep -cF 'authority=reviewer' tests/microworld-rerun.test.sh)" -ge 1  # baseline 0
test "$(grep -cF 'authority=self' tests/microworld-rerun.test.sh)" -ge 1      # baseline 0
bash tests/microworld-rerun.test.sh
# the suite must cover:
#   - no countersign marker                       -> authority=self
#   - countersign with matching runsh: hash        -> authority=reviewer
#   - countersign, then run.sh edited              -> authority=self
#   - countersign with a malformed/absent runsh:   -> authority=self
#   - a manifest.json field claiming authority     -> IGNORED, still authority=self
#     (GUARD: provenance must not be self-declarable)

# C9.3  cross-language contract holds, old lines still parse
test "$(grep -cF 'authority' tests/microworld-audit-contract.test.js)" -ge 1   # baseline 0
node --test tests/microworld-audit-contract.test.js
# the contract test must additionally pin: a pre-change line with NO authority
# field parses to authority undefined, not to a parse failure.

# C9.4  the dashboard labels it in text, at all three render sites
test "$(grep -cF 'unverified' tests/dashboard-server.test.js)" -ge 1           # baseline 0
node --test tests/dashboard-server.test.js
# asserted via the sentinel-stub shape ([[sentinel-stub-single-impl-proof]]):
# with getStatusClass stubbed to a sentinel, the sentinel appears at exactly the
# three sites, and the `unverified` label appears iff authority !== 'reviewer'.

# C9.5  both adapter ports carry the emit, pinned by literal probes.
#       `authority=` not bare `authority` -- see the attribution note above.
test "$(grep -cF 'authority=' tests/adapter-protocol-parity.test.js)" -ge 1   # baseline 0
node --test tests/adapter-protocol-parity.test.js
test "$(grep -lF 'authority=' adapters/*/hooks/scripts/microworld-rerun.sh | wc -l)" = 2

# C9.6  GUARD: the dashboard is still not an acceptance criterion anywhere.
#       Green today and labelled a guard, not a change-proof (trap ten).
grep -qF 'never an acceptance criterion' templates/persona-protocol.md

node bin/cli.js --update --check
bash tests/validate.sh
```

*Baseline at `09cc304`:* `grep -cE 'authority=' .claude/microworld-audit.log` →
`0`; `grep -cF 'authority' bin/microworld-dashboard/audit-log.js` → `0`; the
sanctioned heredoc to a `.countersign` target exits `2` while the `.pass` twin
exits `0`; both adapter ports of `microworld-rerun.sh` exist.

**Do not touch:** the bundle lifecycle — how bundles are created, discovered,
captured into escalation packets, or retired. That is spec 4. This step adds one
optional marker kind, one optional audit field, and one label. It changes no
bundle's contents and no bundle's schedule.

---

## Self-check

### Amendment self-check — RD2a (2026-08-26)

Run against the amendment only; the original items below stand unchanged except
where an item explicitly names Step 1's recovery route.

- **CHK-A1: Is the recovery route named in Step 1 proven to work?** — PASS.
  The original route was not, which is what triggered this amendment. The
  replacement is `git restore` on a tracked file, with tracked-ness verified two
  ways: `git ls-files --error-unmatch` for this repo, and the absence of the path
  from `OPERATIONAL_GITIGNORE_PATTERNS` (`bin/cli.js:155-170`) for adopters.
- **CHK-A2: Does the plan state what the rejected route actually does, rather
  than only that it was rejected?** — PASS. RD2a fact 2 enumerates the ten
  default-valued fields written and the four keys omitted entirely, and C1.0b
  pins three of those facts as executable assertions.
- **CHK-A3: Do RD2, RD2a, R1, D9, Step 1's body and C1.0 agree on which route is
  sanctioned?** — PASS after revision. RD2's original sentence still named
  `--update` after RD2a was drafted; revised in place to carry an explicit
  "amended, see RD2a" marker rather than being silently rewritten, so the
  superseded ruling stays legible.
- **CHK-A4: Is C1.0 still phrased as a precondition that gates the approach?** —
  FAIL (conflicting) — revised in place. It was, and re-running it would have
  re-escalated the unit forever. It is now marked DISCHARGED and replaced by two
  GUARDs (C1.0a, C1.0b) that pin the measured facts instead of re-litigating the
  decision.
- **CHK-A5: Is the denial message's content constrained by anything, or only its
  absences?** — FAIL (ambiguous) — revised in place. C1.7(b) alone is satisfied
  by deleting the message entirely. C1.7(c) was added to pin the three positive
  strings (operator route, rescaffold warning, `/antislop:install-antislop`).
- **CHK-A6: Are C1.0a and C1.0b non-vacuous?** — PASS, proved rather than
  asserted. Both were executed as written (green). C1.0b was shown to
  discriminate by running its assertions against this repo's live config, where
  all three go red (26 `protectedPaths`, `fileHashes` present). C1.0a was shown
  to discriminate against a mutated `bin/cli.js` with the early exit replaced by
  a config write — **and that mutation exposed that the `test $? = 1` half is
  vacuous on its own**, since the mutant still exits 1 for a later reason. The
  criterion now carries a DO-NOT-DROP note naming the `test ! -e` line as the
  load-bearing half.
- **CHK-A7: Does the amendment stay inside Step 1?** — PASS. Step 3 (gh415,
  PASSed) is untouched; no sibling spec or the rollout doc is touched. The one
  cross-step interaction found — `.claude/persona-config.json` being in Step 2's
  Set A, so the recovery command is denied in-session — is *recorded* in R1 as a
  consistent-and-intended property with an explicit "no Step 2 change is required
  or authorized", not acted on.
- **CHK-A8: Does the amendment introduce a bypass hint?** — PASS. The message
  names an operator action outside the session and never suggests rewording a
  command so Step 2 stops matching the path; R1 and RD2a both state plainly that
  such rewording would be a self-authorized bypass.
- **CHK-A9: Is Step 1's model tag still right?** — FAIL (missing) — converted to
  Open Question A1. The unit is no longer the one `sonnet` was tagged for: it now
  carries a prior escalation and a hand-authored message with three pinned
  content properties.

**Constitution check (`.claude/constitution.md` v1.0.0), amendment scope only**
- P1 "Verify, don't assume": satisfied — every claim in RD2a was executed on
  throwaway fixtures, including the mutation proof; nothing is carried over from
  the escalation brief on its word.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied, and it is
  the affirmative argument against direction (b) — the deterministic backfill
  path is the sanctioned one and it structurally cannot reach the judgment
  fields, so hand-writing new reconstruction code would be working against this
  principle, not with it.
- P3 "Version-stamp discipline": satisfied — no version-stamped file changed
  (docs only).
- P5 "`tests/validate.sh` is the merge gate": satisfied — re-run green after the
  edit; the amendment touches no shell or JSON.

### Open Questions raised by this amendment

1. **A1 — Should gh416's `Suggested model` tag rise from `sonnet`?**
   *Recommended default: yes, `opus`.* The unit already escalated once, and its
   deliverable now includes a message whose wording is load-bearing (C1.7 pins
   three positive strings and four banned substrings). Model tagging is
   `task-master`'s dispatch decision, not mine, so this is raised rather than
   applied.
2. **A2 — Is halting the session until a human acts acceptable, or should
   `tampered` warn rather than block for one release?**
   *Recommended default: keep the block (RD2's ruling stands).* Flagged because
   RD2 was ratified when a self-service recovery route was believed to exist, and
   that premise is now false — the cost of the ruling went up even though the
   ruling itself did not change. Ratifying it a second time with the true cost
   visible is worth one explicit confirmation.

### Original self-check (2026-08-25)

- **Does every step carry a criterion that would fail if the step were not
  done?** Yes — every criterion above was executed at `09cc304` and is RED, or is
  explicitly labelled `GUARD`. The RED baselines are quoted inline per step, and
  all were **re-verified after spec 6 landed** (`hooks/` byte-unchanged,
  `reviewGating` still absent).
- **Is any criterion phrased against `git diff`?** No. The tree is committed and
  clean when a reviewer evaluates them (`[[verify-own-criteria-nonvacuous]]`,
  trap four); every criterion asserts content, exit codes, or fixture behaviour.
- **Is any criterion a `! … | grep -qE` form?** No — banned by precedent
  (`028bc23`).
- **Does any criterion grep this plan document?** No (D8). Step 5's criteria are
  the near miss and are deliberately scoped to runtime stderr; C8.4 is scoped to
  `docs/trust-model.md` alone.
- **Are the grep patterns single-quoted?** Yes — this repo's prose is
  backtick-dense and double quotes are a live command-substitution landmine
  (trap five).
- **Is any criterion a deletion check on a rule that states itself?** Step 5's
  banned-phrase checks are the risk shape. They are safe because they target
  *runtime stderr*, and C5.6 pairs them with survival pins proving the content
  still exists in the headers (trap six).
- **Does any step cite a passing test that does not probe its subject?** This was
  caught and fixed rather than merely asserted. Steps 7 and 9 name **six suites
  that already exist and already exit `0`** at `09cc304` — `dispatch-hygiene`,
  `human-decision-gate`, `microworld-rerun`, `microworld-audit-contract`,
  `dashboard-server`, `adapter-protocol-parity`. As first written, both steps
  would have been reported satisfied with no work done (trap eleven). Every one
  is now a **two-assertion pair**: a sentinel pin measured at `0` today, then the
  suite. Verified by execution — both blocks now stop on their first assertion
  (`test 0 -ge 1`) instead of running past a green suite. One of those pins also
  hit trap eight: a bare `authority` grep against
  `tests/adapter-protocol-parity.test.js` returns **2** today from unrelated
  comments, so the pin uses `authority=`, measured `0`.
- **Were the criteria executed, not just written?** Yes. All nine fenced blocks
  were extracted from the finished document, `bash -n`-checked, and run under
  `set -e`; each stops at its first substantive assertion, so none is vacuous.
- **Is the baseline green?** Locally yes — `bash tests/validate.sh` exits `0`
  with `0` `FAIL` lines at `09cc304`. No Step-0 clearing unit needed. CI is red
  at the same commit, which is spec 6's P0 and blocks none of these criteria
  (R9). Re-measure before dispatch.
- **Are the adapter ports accounted for?** Yes, and the inventory was verified
  rather than assumed (R7): Steps 1, 3 and 9 each touch ported scripts and each
  carries an explicit port criterion; Steps 2 and 5 touch scripts with no port,
  following `human-decision-gate.sh:29-31`'s recorded precedent.
- **Constitution v1.0.0:** P1 (verify, don't assume) — every finding reproduced
  with real payloads, two of five corrected, and the retracted spec-6 draft
  independently re-verified against D0 before reverting rather than taken on
  instruction. P3 (version-stamp discipline) — Steps 1, 2, 3, 5, 7, 9 touch
  `hooks/scripts/`, `agents/*.md` or `templates/`, so a version bump plus a
  regenerated `.claude/` mirror and `fileHashes` is owed on each (R8). P5 — every
  step ends on `bash tests/validate.sh` exit `0`.
- **Did any step annex a sibling spec?** No. Spec 6: Step 2 satisfies a
  dependency D0 declares and Step 4 monitors the key D adds — neither edits a
  workflow, a ruleset, or D's verdict contract, and neither adds the
  `reviewGating` key. Spec 3: the M4 unblock is recorded as a side effect and
  **no step deletes a line of the corpus**. Spec 4: Step 9 adds one marker kind
  and one audit field, no lifecycle change. Spec 2: no criterion names a model
  tier. Spec 5: no cross-spec ordering asserted beyond R6's note.
- **Was C3.2 re-verified against the tree it will actually run on, not just the
  tree it was written against?** *(added 2026-08-26)* Not at authoring — and the
  gap was real. Spec 3's M2 extraction moved three of C3.2's seven target files'
  append logic into `lib/<name>-core.sh` after this document was finalized, so the
  criterion read `0` for them regardless of whether the work was done
  (`[[verify-own-criteria-nonvacuous]]`). See Step 3's 2026-08-26 correction. The
  rewritten C3.2 was executed at `e685a01`: RED nine times over today, GREEN over
  a fixture with all 23 sites converted, and killed individually by a single
  re-introduced raw append in each of the nine files, plus a tenth caught only by
  its new backstop half. **Every other criterion in this document still carries
  only its `09cc304` baseline and must be re-measured before dispatch, for
  exactly the same reason** (`[[baselines-expire]]`) — this correction fixed one
  instance of a hazard the whole document is exposed to, not the hazard itself.
- **Was the retracted instruction handled correctly?** The CI retarget was
  applied, then reverted after reading D0 directly rather than on the
  coordinator's word alone — the same verification spec 3 performed
  independently. The only artifacts carried forward from that pass are ones that
  survive on their own merits: R7's adapter inventory, the registration-path
  verification in Step 2, and Step 4's `reviewGating.mode` field, which the
  retracted draft is what surfaced.

---

## Scribe update hint

New load-bearing terms for `CONTEXT.md`'s glossary, none of which exist today:
**disarm surface** (the config field set whose weakening turns a gate off, now
including `reviewGating.mode`), **audit seal** (the append-only sidecar and its
first-N-lines hash), **sanctioned rotation**, **countersign** (a reviewer's
`run.sh` hash attestation in the marker directory), and **authority** (`self` vs
`reviewer` provenance on a microworld result). `docs/trust-model.md` (Step 8)
becomes the canonical home for the self-report-vs-mechanical distinction, and —
per spec 6's request — for the credential-split upgrade path.

**Added by the RD2a amendment (2026-08-26).** Two terminology items, from the
prose-mode glossary check against `CONTEXT.md`:
- **Terminology collision, worth resolving before it spreads.** `CONTEXT.md`
  already defines **skeleton** as `command_skeleton` — the gate lexer's masked
  view of a Bash command. `bin/cli.js` independently prints "skeleton" for the
  blank-field `persona-config.json` it writes on a rescaffold. Two unrelated
  meanings, one term. This amendment therefore says **"blank-field config"** or
  **"default-valued config"** throughout and quotes the CLI's own word only when
  quoting its output. `scribe` should decide whether to rename the CLI's usage or
  record both senses explicitly.
- **New load-bearing term with no entry:** **adaptation witness** — an on-disk
  artefact (`.claude/agents/*.md`, `.claude/hooks/scripts/`, `.claude/reviewed/`)
  that proves a project was adapted *without* consulting `persona-config.json`.
  It is the whole basis of `harness_armed()`'s `1` vs `2` split (D1, R2) and is
  used across Step 1's text with no glossary entry behind it.

Also flagged for `scribe`, found while verifying and out of this spec's scope:
`README.md`'s "Known limitations" still names only variable-splitting as
`reviewed-path-gate.sh`'s residual, though the header now lists five classes and
the `rpg-canon-2` marker's note N3 adds a sixth (symlink hops) — the same gap
that marker's notes N3 and N4 already recorded. Separately, spec 6's D0 §3 makes
documenting that AntiSlop no longer self-hosts its own gates a stated honesty
obligation; that is spec 6's unit, but it lands in the same `README.md` section
and the two edits should be coordinated rather than raced.
