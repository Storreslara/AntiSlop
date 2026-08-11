# The microworld dashboard — a standing, interactive exploration surface

Date: 2026-08-10 | Author: `spec-master` | Status: finalized, ready for
`task-master` slicing

**Revision 2 — 2026-08-10 (same day).** The user added two capabilities after
reading revision 1: **notebook-style interaction** in place of a one-shot
form-submit-view-result cycle, and the ability to **annotate a function and
copy a structured feedback block to the clipboard** for pasting into a coding
agent. Both are folded in below as Steps D6 and D7, with the step list
renumbered (nothing was published from revision 1, so renumbering costs
nothing). Neither addition reopens Open Questions 1-5 — but both touch the
guardrails decided in Open Question 4 at two specific points, and that is
stated plainly rather than glossed: see "Where the additions touch already-
decided ground". Two new questions (6 and 7) were raised and **both were
answered by the user on 2026-08-10, on the recommended default in each case**.
**No Open Questions remain outstanding in this plan.**

**Supersedes, in part,
`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`.**
Specifically: that plan's Step 2 (bundle format), its "deliberate narrowing"
passages in Context/Design-provenance, its recorded architectural fact "No
daemon is introduced", and its convergence-round Step 9 (F1, `explore.sh`).
Everything else in that document — Steps 3a, 3b, 4, 5, 6, 7, 8a, 8b, 10, 11 —
stands unchanged and is a **prerequisite** of this one. See "Relationship to
the 2026-07-28 plan" for the exact disposition of each.

## Goal

Make **microworld** mean what the user meant by it: a persistent, interactive
surface where a human explores the code agents have written for this repo,
piece by piece, passing their own inputs to individual functions, seeing what
comes back, and feeding a situated reaction straight back to a coding agent.

Concretely, add one new component to the antislop plugin:

- **The microworld dashboard** — a user-launched, long-running local process
  (`node bin/cli.js --dashboard`) serving a browser UI on `127.0.0.1`. It:
  1. discovers every microworld bundle in the working tree (Step D2);
  2. shows each bundle's latest check result, live, as agents edit code
     (Step D3);
  3. presents each unit as a nested tab tree — group (the class) then
     function — and lets a human supply inputs to any single function and see
     its actual output (Steps D4, D5);
  4. accumulates those invocations as **notebook cells** with per-cell input
     history and edit-and-re-run (Step D6);
  5. lets a human attach a comment to a function and **copy a feedback block**
     — comment plus function name, file path, line numbers, and commit — to the
     clipboard, ready to paste into a coding agent (Step D7);
  6. also reads durable escalation packets, so an escalated unit stays
     explorable in a later session (Step D8).

And extend one existing artifact to feed it:

- **Microworld bundle format v2** (Step D1) — `manifest.json` gains a
  declarative `functions[]` array. Each entry is a bundle-relative executable
  taking one JSON object on stdin and printing a result to stdout, plus an
  optional `location` naming where in the repo that function actually lives.
  This is what makes "the class and its functions" navigable, and its feedback
  citable, without the dashboard knowing anything about the language the unit
  is written in.

**Scope trigger: every unit that has a bundle gets a dashboard entry.** The
dashboard is a general observability and exploration surface, wholly
independent of `ESCALATE-TO-HUMAN`, `humanReviewMode`, and the heavy-unit
trigger. It never gates anything and is never on any gate path.

## Context

### Why this exists, and what it replaces

The 2026-07-28 plan took the word "microworld" from a Geoffrey Litt thread on
Papert-style microworlds — playable environments a human explores to build
intuition — and then **deliberately narrowed** it to a fixture bundle whose
entire contract is `run.sh`'s exit code. That narrowing was logged as an
explicit user reinterpretation, defended at length in that plan's
Design-provenance section, and re-affirmed in its 2026-08-09 convergence round
under "What is NOT a gap" #1 ("is not being rewritten").

**The user has overridden that narrowing.** In their own words:

> What I had in mind from micro-worlds is that this is going to be a
> constantly running terminal window on the side that is part of anti-slop.
> The idea being that in this window, we would have pieces of code that the
> agents have written for the repo. And there would be live tests of key
> infrastructure pieces. For example, let's say that the agent is building a
> custom distribution using Python. Then in micro-worlds, the user would see
> a nested tab with the class and its functions and then get to test each
> part of that class, the custom distribution, the sampling, the fitting,
> stuff like that. So user passes inputs for a desired function, sees the
> output. Does it behave the way it's expected, et cetera.

This is closer to the source than the narrowing was, and it is now the
**primary** meaning of the word in this system. The narrowing is not deleted —
it is **demoted to a layer**. The machine-checkable half survives intact and
unchanged underneath the dashboard, because the two consumers that motivated
it are unchanged: the `reviewer` adjudicating a unit and the `PostToolUse`
rerun hook firing on every edit both still want a binary result, and a hook
still cannot wait for a human to play.

**The one-line summary of the re-scoping**, because everything else follows
from it:

| Layer | Artifact | Consumer | Contract |
|---|---|---|---|
| Human-facing (**primary**) | the microworld dashboard | a human | interactive; no verdict, no exit-code meaning |
| Machine-facing (**underlying**) | `run.sh`, "the check" | `reviewer`, rerun hook | exit 0 = pass, non-zero = fail |

### Notebook interaction and the feedback block (added revision 2)

After reading revision 1, the user added two things, in their own words:

> After reading the current spec, I like the idea of turning MicroWorld's
> environment/dashboard into something similar to a Jupyter notebook, but
> rather [than form-and-run] to have the interaction of it. And also, on the
> side, have the ability to make comments on the function that was written or
> the code that was written and be able to copy and paste that into a
> clipboard and then pass it along to my coding agent, let's say. That
> clipboard should also by default contain the function name and its location
> in the repo, both at the path of the file and line numbers.

**What "notebook" is taken to mean here** (Open Question 6, answered (a) by the
user 2026-08-10): a **UI and UX framing, not an execution-model change**. Each
invocation becomes a **cell** — a durable-within-the-session record of one
function, one input set, and one output — and cells accumulate in order, with
edit-and-re-run producing a new cell rather than overwriting the old one. What
it explicitly is *not* — settled, not provisional — is a **kernel**: there is no
warm process, and two cells share no state. That
distinction is load-bearing enough that the UI is required to say so on screen
(Step D6), because a "notebook" that silently drops state between cells is
worse than no notebook at all for anyone carrying Jupyter expectations.

The reason for the default is not squeamishness. A real kernel needs a
per-language adapter — which is precisely the ground on which per-language
introspection was rejected in Open Question 1 — and it breaks two of the
guardrails settled one round ago in Open Question 4. The middle path (a
bundle-provided warm session process, so the *bundle* owns the language and the
dashboard stays agnostic) is real and is offered as Open Question 6 option (b);
it is deferrable at zero cost because every `manifest.json` field is optional
by construction.

**What the feedback capability is for.** The dashboard is the first place in
this system where a human forms an opinion about agent-written code while
looking at it running. That opinion currently has nowhere to go but the human's
memory and a retyped prompt. The **feedback block** closes that loop: a
comment, plus enough situating detail that a coding agent receiving it does not
have to ask "where?" — function name, group, file path, line range, commit
SHA, bundle path, and (when copied from a cell) the exact inputs and output
that provoked the comment.

**Naming — it is a "feedback block", not a "handoff".** `handoff` is already a
shipped skill in this repo (`skills/handoff/`, "compact the current
conversation into a handoff document") and `.claude/wip-handoff.*` is an
existing artifact. Calling this a handoff packet would have created a
near-synonym for two live concepts — exactly the drift
`antislop:ubiquitous-language` exists to catch, caught here by running it.

### Where the additions touch already-decided ground

Open Questions 1-5 are **not** reopened, and this was checked rather than
assumed:

- **OQ1 (declarative manifest) — extended, not reopened.** `functions[]` gains
  one optional field, `location`. Adding an optional field is additive; the
  `entry` execution contract is untouched. Open Question 6 option (b), if
  chosen, would add a second optional key (`session`) — still additive, still
  declarative, still language-agnostic.
- **OQ2 (HTTP server + browser tab) — not reopened, and retroactively
  strengthened.** Notebook cells, a rendered source excerpt, and the Clipboard
  API all require a browser. A terminal UI could not have delivered the
  clipboard capability at all in any portable way. The shape chosen last round
  is what makes this round cheap.
- **OQ3 (explicit start, nothing auto-starts it) — not reopened.**
- **OQ4 (no sandbox, guardrails only) — put in question at exactly two points,
  and both guardrails survived intact.** Guardrail 4 ("bounded": every
  invocation runs under a timeout and is killed on expiry) would have been
  meaningless for a warm kernel, and guardrail 5 ("the dashboard writes no
  files at all") would have been reversed by persisting comments. Both
  couplings were put to the user as Open Questions 6 and 7, and **both were
  answered on the option that preserves the guardrail** (2026-08-10). Nothing
  in the security posture changed. Recorded here rather than dropped, because
  these are the two seams where a future "improvement" would silently cost a
  guardrail.
- **OQ5 (terminology) — not reopened**, but three new terms need glossary
  entries: **notebook cell**, **feedback block**, **function location**
  (Step D10).

One genuinely new capability comes with the additions and needs its own
guardrail: rendering a source excerpt means the dashboard reads **arbitrary
files under the project root** for the first time — until now it read only
`microworlds/` and `.claude/human-review/`. `location.file` comes from an
agent-authored, gitignored manifest, so a path-traversal guard is required, not
optional. Step D7 owns it and asserts it by execution.

### Terminology (decided — Open Question 5, answer (a))

The word carried two senses and the 2026-08-09 round closed that hazard by
documentation only, on the grounds that renaming "would invalidate eight open
issues for a cosmetic gain". Those issues are being re-sliced anyway, so that
argument no longer holds and the naming is fixed here instead:

- **Microworld** — the dashboard entry for a unit: the thing a human opens,
  navigates, and passes inputs to. This is the primary sense.
- **Microworld bundle** — the gitignored `microworlds/<unit-slug>/` directory
  backing a microworld. Storage and lifecycle unchanged from the 2026-07-28
  plan.
- **The check** — the bundle's `run.sh`. The machine-facing, exit-code
  contract.
- **Microworld dashboard** — the long-running local process serving the
  microworlds.
- **Function entry** — one element of `manifest.json`'s `functions[]`: a
  named, bundle-relative executable a human can invoke with their own inputs.
- **Function location** — a function entry's optional `location` field, naming
  where in the repo the code it exercises actually lives (`file`, `startLine`,
  `endLine`).
- **Notebook cell** — one recorded invocation: a function, an input set, and
  its output, held in the browser session.
- **Feedback block** — the markdown block a human copies to the clipboard: a
  comment plus the situating detail a coding agent needs to act on it.
  Deliberately **not** called a handoff; see above.

**Decision — `run.sh` keeps its filename.** Only the prose noun becomes "the
check". Renaming the file would ripple through the rerun hook (#132), the
packet snapshot and marker body (#133), and human-decision routing (#136) —
none of which the user reopened — for zero functional gain. The ambiguity Open
Question 5 fixes was in the word "microworld", never in `run.sh`. Stated here
because a rename is exactly what a reader will expect and then wonder about.
For the same reason the hook keeps the filename `microworld-rerun.sh`: it
re-runs the check for a microworld bundle, which remains accurate.

### Design decisions taken with the user

**Function contract — declarative, language-agnostic** (OQ1(a)). Rejected:
per-language runtime introspection (breaks R8 for every language without an
adapter, imports agent-written code into the dashboard's own process) and a
single `explore.sh` whose stdout is parsed (fragile, and per-function inputs
have nowhere to live).

**UI shape — a local HTTP server plus a browser tab** (OQ2(a)), on `node:http`
with zero new dependencies. Two decisive reasons over a terminal UI: nested
tabs, typed input forms, and output rendering are cheap in HTML and expensive
hand-rolled at zero dependencies; and a JSON HTTP API is the only shape here
yielding machine-checkable acceptance criteria, which constitution P1/P5 and
this project's criteria discipline require.

**Lifecycle — user-launched, never auto-started** (OQ3(a)). Hooks are
synchronous and short-lived, and the shared protocol already records that a
background job started inside a session goes dormant with no self-wake — a
hook-spawned detached process would be unobservable and unkillable from the
session.

**Trust boundary — no sandbox, guardrails only** (OQ4(a)). This is the user's
own working tree, and the hooks and the reviewer already execute this code.

### Security posture (Open Question 4, answer (a))

Each is a machine-checkable criterion in Step D2, D4, or D7, not an
aspiration:

1. **Loopback only.** The server binds `127.0.0.1`, never `0.0.0.0`.
2. **Per-launch token.** A cryptographically random token from `node:crypto`,
   generated at startup, printed in the URL, required on **every** request as
   `?t=` or an `X-Antislop-Token` header. Missing or wrong → `401`, empty body.
   A loopback bind alone still exposes the endpoint to every other process and
   every browser page on the machine. Accepted tradeoff, stated plainly: the
   token appears in terminal scrollback and the address bar; it is a
   per-launch, non-persisted secret, not a credential.
3. **No shell.** Function entries are spawned with an argv array and never
   through a shell; human-supplied values are delivered as one JSON object on
   **stdin** and are never interpolated into a command string. Same injection
   guard `lint-on-edit.sh` and `graph-update.sh` already document, applied at
   the one place a human types free text.
4. **Bounded.** Every invocation runs under a timeout (the manifest's
   `timeoutSeconds`, default 60) and is killed on expiry; captured stdout and
   stderr are capped at 1 MiB each and truncated with an explicit marker.
   *(A warm kernel would have made this meaningless; Open Question 6 was
   answered (a), so it stands unchanged.)*
5. **Writes nothing.** No state directory, no history, no cache. Nothing needs
   a new `.gitignore` line, and nothing survives a restart. Notebook cells and
   comments are in-page only. *(Persisting comments would have reversed this;
   Open Question 7 was answered (a), so it stands unchanged.)*
6. **Reads only within the project root.** Bundle contents, escalation
   packets, the audit log, and — new in Step D7 — source excerpts, every one
   of them resolved and verified to fall inside the project root before
   opening. A `location.file` escaping the root is a `400`, never a read.
7. **Never on a gate path.** No hook registers it, no gate consults it, no
   acceptance criterion may name it. Asserted negatively in D2.

### Architectural facts this plan is built on (verified 2026-08-10, not assumed)

- **This repo has zero runtime npm dependencies.** `package.json` has no
  `dependencies` and no `devDependencies` key at all; `bin/cli.js` (2151
  lines) requires only `fs`, `os`, `path`, `crypto`, `readline`,
  `child_process`. `engines.node` is `>=18`. A dashboard on `node:http`,
  `node:crypto`, `fs.watch`, and `child_process.spawn` preserves this exactly;
  anything else would be the project's first ever runtime dependency.
- **No shipped long-running process exists anywhere.** The only precedent is
  `prototype/protocol-mcp/server.py`, explicitly a prototype and absent from
  `package.json`'s `files`. Nothing in `hooks/`, `bin/`, or `scripts/` runs
  longer than one synchronous invocation. This plan introduces the first, as a
  **foreground process the user starts and stops**, never a daemon.
- **The CLI convention is flags, not subcommands.** `bin/cli.js:1788` parses
  `process.argv.slice(2)`; existing flags include `--update`, `--check`,
  `--wire-graph-mcp`, `--target=`, `--overwrite`, `--yes`. `--dashboard`
  follows that convention and dispatches early in `main()`, alongside
  `--update` and before any scaffolding path, so no existing-install guard can
  intercept it.
- **`package.json`'s `files` already ships the whole `bin` directory**, and
  `tests/validate.sh`'s npm-pack check (lines 44-57) asserts
  `included = ['agents/','hooks/','templates/','skills/']` and
  `excluded = ['docs/','eval/','prototype/','specs/','.claude/']`. Siting the
  dashboard under `bin/dashboard/` therefore needs **no** `files` change and
  **no** `validate.sh` change; a new top-level directory would need both.
- **`tests/validate.sh` registers each test explicitly**, in an
  `if bash tests/<name>; then echo "OK ..." else echo "FAIL ..."; fail=1`
  block — there is no glob-driven auto-discovery. An unregistered test file
  silently never runs.
- **`hooks/hooks.json` PostToolUse `Edit|Write`** currently carries
  `graph-update.sh` and `lint-on-edit.sh`; the 2026-07-28 plan's Step 3b
  (#132) appends `microworld-rerun.sh`. This plan adds nothing to any hook
  file.
- **The rerun hook's audit line format is specified** by that plan's Step 3 as
  `<ts> unit=<slug> result=pass|fail|timeout file=<path>` in
  `.claude/microworld-audit.log`. This plan **consumes** it, which promotes it
  from a log to an interface (R4, Step D3).
- **`*.log` is already gitignored wholesale** here, so
  `.claude/microworld-audit.log` is covered in this repo today even before
  #131 lands its explicit entry; downstream projects still need #131.
- **`handoff` is a shipped skill** (`skills/handoff/SKILL.md`) and
  `.claude/wip-handoff.*` is an existing gitignored artifact — which is why the
  clipboard artifact is named a **feedback block**.
- **`http://127.0.0.1` is a potentially-trustworthy origin**, so the async
  Clipboard API is available over plain HTTP on loopback. This is a claim about
  browser behaviour that cannot be verified from this environment, so Step D7
  requires a `document.execCommand('copy')` textarea fallback and asserts its
  presence — the feature must not be load-bearing on an unverifiable claim
  (constitution P1).
- **NOTHING from the 2026-07-28 plan has been built. Every step in this plan
  authors fresh; no step edits a microworld artifact in place.** Measured
  2026-08-10, after the orchestrator caught revision 2 claiming otherwise for
  D1: `grep -ci microworld templates/persona-protocol.md` is **0**;
  `git log -S'Microworld' -- templates/persona-protocol.md` is **empty** (the
  section never existed at any commit); `hooks/scripts/microworld-rerun.sh`,
  `.claude/microworld-audit.log`, and `.claude/human-review/` are **absent**;
  `grep -c 'microworlds/' .gitignore` is **0**; `grep -ci microworld README.md`
  is **0**; `grep -c '^\*\*Microworld' CONTEXT.md` is **0**; and
  `grep -c microworld tests/validate.sh` is **0**. The only repo-wide hits
  outside `docs/plans/` are `CONTEXT.md` (a cross-reference), `CHANGELOG.md`,
  and `docs/adr/0014`. **Consequence, and it is the general rule for this plan:
  wherever a step inherits language from #130 or #137/#138, that language
  describes a specification, never an artifact on disk.** D1, D9, and D10 each
  carried some version of this error in revision 2 and are corrected.
- **A new canonical `## ` section in `templates/persona-protocol.md` REQUIRES
  parity-map entries.** `tests/adapter-protocol-parity.test.js` derives the
  header list live via `canonicalHeaders()` (it reads the template and filters
  `## ` lines, never a hard-coded list), and `checkPort()` asserts in both
  directions: every canonical header must have a map key
  (`canonical section "<h>" has no parity-map entry — drift, decide present or
  deferred`) and every map key must still be a canonical header (stale-entry
  check). The file self-tests this at its `withExtra` case, which asserts that
  an unmapped section throws. So D1 — the step that actually creates the
  section — must add an entry to **both** `codexMap` and `cursorMap` in the same
  commit. This is R3, and revision 2 wrongly framed D1 as exempt from it.
- **The heavy-unit trigger is NOT in `templates/persona-protocol.md`, and the
  2026-07-28 plan is wrong about this.** That plan's Step 4 (#133) says the
  trigger is "already defined in this protocol's 'Reviewer roast-work advisory
  pass trigger' section" and carries the acceptance criterion
  `grep -c '≥ ~8 impacted files' templates/persona-protocol.md` is 1. Measured
  2026-08-10: that string occurs **zero** times, no such section exists, and
  `grep -rn 'impacted files' agents/ templates/ adapters/` returns nothing at
  all. The trigger's only definition is
  `docs/adr/0004-reviewer-roast-work-dual-model-routing.md` § "Heavy unit
  trigger" (≥~8 impacted files OR ≥~400 changed lines; structural/cross-cutting;
  security-sensitive), amended by ADR-0013, which removed the separate fable
  dispatch the trigger originally gated. **Consequences:** this plan's D1
  references the ADR and asserts non-duplication instead (see D1's criteria),
  and **#133 carries an acceptance criterion that cannot pass as written** —
  recorded in Tracker dispositions so it is corrected before dispatch rather
  than discovered as a FAIL.
- **Next ADR number is 0017.** `docs/adr/` runs 0004-0016 with a known hole at
  0007 that must not be backfilled (`CONTEXT.md` links it).
- **No prior FAIL history in this area.** All 37 `.fail` records under
  `.claude/reviewed/` were enumerated; none corresponds to #129-138 or
  #298-300, consistent with none being built. No step here is a re-scope after
  a failure, and none should be tagged as mechanical on that basis.

### Global constraints

**G1 — the version-bump triple.** Every unit touches a version-stamped file,
so every unit also touches: `.claude-plugin/plugin.json` (`version`, patch
bump), `package.json` (`version`, same value), `CHANGELOG.md` (an entry), and
`.claude/persona-config.json` (`pluginVersion`). Constitution P3 requires it
and `tests/validate.sh:34-42` (P5) FAILs on a mismatch.

**G2 — never hand-edit generated files.** `.claude/agents/*.md` and
`persona-config.json`'s `fileHashes` are regenerated by `node bin/cli.js
--update` (P2). Any unit changing a template or an `agents/*.md` source ends
with `--update` and asserts the copies actually changed (R2).

**G3 — optional-persona phrasing.** New prose in
`templates/persona-protocol.md` and the adapter ports referencing
`reviewer`/`scribe`/`spec-master`/`task-master` must be conditionally phrased;
`tests/validate.sh` hard-fails on a bare unconditional reference.

**G4 — zero runtime dependencies.** `package.json` must continue to declare no
`dependencies` and no `devDependencies`. Asserted in Step D2 and never relaxed
by a later step. The entire UI-shape decision rests on this holding.

**G5 — the dashboard is never a gate.** No hook registers it, no gate consults
it, and no acceptance criterion in this or any future spec may name it.
Asserted negatively in D2 and stated as a sentinel phrase in D1.

**G6 — every acceptance criterion is a post-condition on the COMMITTED tree,
never an assertion about a working-tree diff.** Added 2026-08-10 after the D1
reviewer found the anti-pattern in R2 and in two step criteria (CHK29).

The reviewer may only write a PASS marker when `git diff --quiet HEAD` exits 0
— the tree is fully committed before any criterion is evaluated. Therefore a
bare `git diff`, `git diff --name-only`, or `git diff --stat` is **empty by
construction** at review time, and any criterion phrased against one is
unsatisfiable no matter how correct the work was. It does not fail loudly
either: it silently reports "no match", so a reviewer must either hand-improvise
a substitute or fail the unit on a technicality. Both happened on D1.

The rule, in the two forms it actually takes:

| To prove | Do NOT write | Write instead |
|---|---|---|
| "the unit changed X" | `git diff --name-only` includes `X` | an assertion about what `X` now **contains** (a sentinel string, a parsed value, a regenerated stamp) |
| "the unit did NOT need to change Y" | `git diff --name-only` does not include `Y` | an assertion that `Y` still contains its **expected prior value**, quoted literally |

Why content assertions rather than the range-relative form (`git diff
--name-only <base>..HEAD`) the D1 reviewer improvised: a spec is authored
**before** any unit is dispatched, so no baseline SHA exists to hard-code, and
injecting one at slice time would couple every criterion to `task-master`'s
dispatch bookkeeping. Range-relative also breaks on the cases this repo
actually produces — multi-commit units, FAIL→fix cycles that add commits, and
rebases. A content assertion has none of these failure modes, needs no
baseline, and is re-runnable by a human months later.

`git status --porcelain` **before-and-after a command within the review
session** is unaffected by this rule and is used deliberately in D2, D4, D6, D7,
and D8: it is a delta measured inside the review, not a claim about what the
unit committed. It stays valid on a clean tree (both readings empty) and stays
valid amid unrelated untracked files (both readings identical).

## Clarifications

Scored 2026-08-10 against the user's re-scoping request, then rescored the
same day against the revision-2 additions. Categories 2, 3, 4, and 6 were
re-opened by the additions and are re-scored below; all others hold at their
revision-1 values.

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

**Revision 1 (five questions, all answered by the user 2026-08-10 on the
recommended default):**

- 2026-08-10 Functional scope & success criteria: Q Does the dashboard replace
  the escalation-only, one-shot `explore.sh` (2026-07-28 Step 9, F1), or
  coexist with it? → A (self-resolved): **replaces it.** Four independent
  grounds — it is escalation-only (contradicts the every-bundle scope
  trigger), one-shot (contradicts "constantly running"), whole-bundle rather
  than per-function (contradicts "the class and its functions"), and shipping
  both would put two competing human-facing exploration entry points in one
  bundle, precisely the near-synonym drift `antislop:ubiquitous-language`
  exists to catch. Every property Step 9 specified survives: relocatability
  (the `entry` contract, D1), non-asserting output (D1), human-legible
  rendering (D5), and "at least one concrete thing to try" (migrates to
  `functions[].description`, required by D1). Issue #298 is superseded.
- 2026-08-10 Domain entities / data model: Q How does a bundle declare "the
  class and its functions"? → A: **declarative `functions[]` in
  `manifest.json`**, per user (OQ1(a)). Specified in Step D1.
- 2026-08-10 User interaction flow: Q Terminal UI, or a local server plus a
  browser tab? → A: **local HTTP server plus a browser tab**, `node:http`,
  zero new dependencies, per user (OQ2(a)).
- 2026-08-10 Non-functional attributes: Q What is the trust boundary when a
  human invokes agent-written code with arbitrary inputs from a standing
  process? → A: **no sandbox, guardrails only**, per user (OQ4(a)).
- 2026-08-10 External dependencies & integrations: Q May this add the repo's
  first-ever runtime npm dependency? → A (self-resolved): **no.** Verified
  `package.json` declares none today and that every chosen mechanism is a Node
  ≥18 builtin. Encoded as G4 with its own criterion.
- 2026-08-10 Edge cases / failure handling: Q What does the dashboard show
  when no bundles exist — the normal state of a fresh clone, per R8? → A
  (self-resolved): it starts, renders an explicit empty state naming where
  bundles come from, and stays running. Never errors, never blocks. Asserted
  by D2 case (a).
- 2026-08-10 Technical constraints & tradeoffs: Q Does a standing process
  contradict the 2026-07-28 plan's recorded fact "No daemon is introduced
  (constitution P2)"? → A (self-resolved): **yes, directly — and that line is
  retracted, not worked around.** It also miscited P2, which governs
  LLM-versus-script derivation, not process lifetime. The correct framing is a
  *user-launched foreground process*, not a daemon: nothing auto-starts it,
  nothing restarts it, it holds no state.
- 2026-08-10 Terminology consistency: Q Which layer owns the word
  "microworld"? → A: **the dashboard entry**, with the directory becoming the
  "microworld bundle" and `run.sh` the "check", per user (OQ5(a)), including
  the sub-decision that the `run.sh` filename does not change.
- 2026-08-10 Completion / acceptance signals: Q What is a runnable acceptance
  criterion for a navigable UI, given no precedent here? → A (self-resolved,
  enabled by the OQ2 answer): **the JSON HTTP API is the single seam**, and
  every behavioural criterion in D2-D8 is an HTTP request against it with an
  asserted status and JSON body. The HTML client is a thin consumer carrying
  only structural greps.

**Revision 2 (the two additions):**

- 2026-08-10 User interaction flow: Q Does "like a Jupyter notebook" mean a
  persistent kernel with state shared across cells, or cell-shaped UI over the
  existing fresh-process invocations? → A: **UI framing only, no kernel**, per
  user — surfaced as Open Question 6 with this default already applied, and
  answered (a) on 2026-08-10. No change to Step D6.
- 2026-08-10 Domain entities / data model: Q How does the clipboard learn a
  function's name, file path, and line numbers? → A (self-resolved):
  `functions[]` gains an optional `location: { file, startLine, endLine }`,
  authored by `lead-programmer` — the persona that just wrote the code and
  knows exactly where it is. The two alternatives were rejected on the same
  ground that decided OQ1: deriving it by grep is language-specific and
  fragile (breaks R8), and the code-review-graph is MCP-scoped to `explorer`
  and absent downstream. Absent `location` → the block says
  `location: not declared` rather than fabricating one.
- 2026-08-10 Domain entities / data model: Q Where does a human's comment
  live — in the browser tab, or on disk? → A: **ephemeral, in-page only**, per
  user — surfaced as Open Question 7 with this default already applied, and
  answered (a) on 2026-08-10. No change to Step D7; guardrail 5 stands.
- 2026-08-10 Edge cases / failure handling: Q What happens when a
  `location` is stale, points outside the repo, or names a file that no longer
  exists? → A (self-resolved): each is an explicit, visible degradation, never
  a fabrication and never a crash. Outside the project root → `400`, no read
  (guardrail 6). Missing file or an out-of-range line span → no excerpt and a
  stated reason. Stale-but-valid line numbers are unfixable in general, so the
  block carries the **commit SHA at copy time** — reusing the device the
  2026-07-28 plan's `.escalated` marker already uses for the same problem — so
  the receiving agent can tell what the numbers were relative to. Recorded as
  R9.
- 2026-08-10 Non-functional attributes: Q Does rendering a source excerpt
  widen the dashboard's read surface, and does that need a guardrail? → A
  (self-resolved): **yes to both.** Until now it read only `microworlds/`,
  `.claude/human-review/`, and the audit log; `location.file` is an arbitrary
  project-relative path from an agent-authored, gitignored manifest. Guardrail
  6 is added to the security posture and asserted by a path-traversal case in
  D7.
- 2026-08-10 Terminology consistency: Q Is "handoff" a safe name for the
  clipboard artifact? → A (self-resolved): **no — renamed to feedback block.**
  Found by running `antislop:ubiquitous-language` in prose mode: `handoff` is
  a shipped skill (`skills/handoff/SKILL.md`) and `.claude/wip-handoff.*` is an
  existing artifact, so "handoff packet" would be a new synonym for two live
  concepts (lens 2).

### Terminology check (`antislop:ubiquitous-language`, prose mode, against `CONTEXT.md`)

Run against this plan's own draft before handoff, both revisions. Advisory; no
finding blocks.

- **Lens 1 — a glossary term used with a different meaning.** `CONTEXT.md` does
  not yet define **Microworld** (2026-07-28 Step 8b / #138 is unbuilt), so
  there is no canonical entry to diverge from; the only prior definition is the
  superseded plan's. This plan supplies the replacements and Step D10 lands
  them. No unresolved finding.
- **Lens 2 — a new synonym for an already-defined term.** Three found, all
  three closed. "Live tests of key infrastructure pieces" (the user's phrase)
  is a synonym for the check's result stream — closed by defining **the check**
  and routing live status through the existing audit log rather than inventing
  a second concept. "Dashboard" overlapped Step 9's **explore mode** — closed by
  superseding explore mode outright rather than shipping both. "Handoff"
  overlapped the shipped `handoff` skill and `.claude/wip-handoff.*` — closed by
  renaming the artifact to **feedback block**.
- **Lens 3 — load-bearing new domain terms with no glossary entry.** Eight:
  *microworld dashboard*, *microworld bundle*, *the check*, *function entry*,
  *function location*, *notebook cell*, *feedback block*, *microworld token*.
  All routed to `scribe` in Step D10 with required contrasts.

## Risks and dependencies

- **R1 — the dashboard is only as good as bundles nobody can verify exist.**
  Bundles are gitignored working-tree scratch; no commit, clone, or CI run ever
  sees one, so no test can assert `lead-programmer` actually authored
  `functions[]` or `location` for a unit. Mitigation is deliberately weak and
  stated as such: D1 makes both a documented expectation for units meeting the
  heavy-unit trigger (referenced, not restated), and the `reviewer` continues
  to establish bundle presence by filesystem check. **Not fixed**, because
  fixing it means gating on a gitignored artifact, which the storage decision
  rules out. Recorded so it is a known cost, not a surprise.
- **R2 — stranded version stamps in `.claude/agents/*.md`** (inherited).
  History shows agent copies repeatedly stranded at older versions and
  `validate.sh` has no stamp-sync check. Mitigation: every unit touching a
  template or agent source ends with `node bin/cli.js --update` and then
  asserts, **as a post-condition on the committed tree**, that every
  full-protocol copy carries the *current* plugin version in its stamp:

  ```sh
  v=$(node -p "require('./.claude-plugin/plugin.json').version")
  for n in orchestrator lead-programmer reviewer spec-master task-master milestone-auditor; do
    grep -q "antislop v$v |" ".claude/agents/$n.md" || { echo "stranded stamp: $n"; exit 1; }
  done
  ```

  **Corrected 2026-08-10 (G6, CHK29).** The former mitigation asserted
  `git diff --name-only` includes `.claude/persona-config.json`. That is
  unsatisfiable at review time: the reviewer may only write a PASS marker on a
  fully-committed tree (`git diff --quiet HEAD` exits 0), so the bare
  working-tree diff is **empty by construction** by the time anyone checks. The
  D1 reviewer had to hand-substitute a range-relative check to avoid failing the
  unit on a technicality.

  The replacement is strictly better than the diff it replaces, not merely
  runnable: the old check proved only that a file *appeared in a diff*, which
  any unrelated edit satisfies, while this proves the actual R2 invariant — the
  copies are in sync with the manifest. Verified 2026-08-10: currently passes
  (all six at `v0.31.6`), and mutation-proved by rewriting one stamp to
  `v0.30.0`, which the check catches. Paired with G1's mandatory version bump it
  is red-until-done: bump without `--update` leaves all six stranded at the
  previous version and fails. Note the honest limit — it proves
  *internal consistency*, not that a bump happened; that remains G1's concern.
- **R3 — parity test throws on a new protocol section** (inherited, and **D1
  incurs it**). Corrected 2026-08-10: revision 2 claimed D1 was exempt because
  it "rewrites the existing section in place". There is no existing section —
  D1 creates `## Microworld bundles (format and the check contract)` as a new
  canonical `## ` header, so `tests/adapter-protocol-parity.test.js` **will**
  throw unless D1 adds an entry to both `codexMap` and `cursorMap` in the same
  commit. This is not a risk to watch for; it is a required, mechanically
  enforced deliverable of D1, asserted by that step's map-coverage and mutation
  criteria. Deferred entries are permitted only with a written justification in
  the map value string.
- **R4 — audit-log format drift between a bash producer and a Node consumer.**
  The rerun hook (#132) writes the line; the dashboard parses it. Two
  languages, one undocumented format, no shared constant — a classic
  silent-drift shape. Mitigation: D3 adds a cross-language contract test that
  runs the **real hook** against a fixture and feeds its **real emitted line**
  into the **real parser**. Prose agreement between two files would not have
  caught a drift; this does.
- **R5 — this repo is a poor dogfooding target for its own feature.** "A class
  and its functions" assumes OO-shaped code; antislop is bash scripts, a
  single-file Node CLI, and markdown personas, with essentially no classes. The
  first genuinely convincing microworld will come from a downstream ADAPT-ed
  project. Do not expect this repo's own units to demonstrate the feature and
  do not let that absence read as a defect during review. The 2026-07-28 plan's
  "ship only, do not dogfood" decision carries forward unchanged.
- **R6 — a long-running process is a new operational category.** Nothing here
  has ever needed starting, stopping, or noticing-to-be-dead. Mitigation: the
  process is foreground and stateless, holds no lock, writes no pidfile, uses
  an ephemeral port by default, and is killed with Ctrl-C. Two dashboards on
  one repo is legal and harmless — each binds its own port with its own token
  and neither writes anything — and D2 states this rather than pretending it
  cannot happen.
- **R7 — token exposure through scrollback.** The launch URL carries the token,
  so it lands in terminal scrollback and the browser address bar. Accepted: a
  per-launch, non-persisted secret guarding a loopback-only endpoint on the
  user's own machine; the alternative (an interactive paste step) adds friction
  to the one thing that must be frictionless. Documented in README (D9).
- **R8 — downstream-project variability** (inherited, and load-bearing for the
  function contract). Microworlds ship to every ADAPT-ed project, which may be
  any language. This is exactly why `functions[]` is "an executable, one JSON
  object on stdin, output on stdout" and not runtime introspection, and why
  Open Question 6's warm-session option puts the kernel **in the bundle**
  rather than in the dashboard. Node is already an ADAPT prerequisite
  (`bin/cli.js`), so the dashboard shell adds no new constraint on the
  downstream project's own language.
- **R9 — `location` line numbers go stale.** `location` lives in a gitignored
  manifest and names line numbers in files agents keep editing; nothing
  revalidates it. A feedback block can therefore cite a line range that has
  moved. Mitigation, not a fix: the block carries the **commit SHA at copy
  time** (the device the `.escalated` marker already uses for the same
  problem), the dashboard verifies the file exists and the range is in bounds
  before rendering an excerpt, and an unverifiable range is labelled rather
  than silently printed. A receiving agent can then re-derive the location
  itself instead of trusting a stale number.
- **R10 — the source-excerpt read widens the dashboard's file surface.** Until
  D7 the dashboard read only bundle contents, packets, and the audit log; a
  rendered excerpt means reading an arbitrary project-relative path supplied by
  an agent-authored manifest. Mitigation: guardrail 6 — resolve and verify the
  path falls inside the project root before opening, `400` otherwise, asserted
  by an executable traversal case in D7. Read-only, always; the dashboard never
  writes to a source file.
- **R11 — a "notebook" that silently shares no state is worse than no
  notebook.** Anyone carrying Jupyter expectations will assume cell 2 can see
  cell 1's variables. It cannot, and that is settled (Open Question 6, answer
  (a), 2026-08-10). Mitigation: D6
  requires the UI to state it on screen and asserts the sentence with a grep,
  rather than trusting the distinction to be inferred from behaviour.

**Dependencies on the 2026-07-28 plan.** Its Steps 3a and 3b (#131, #132) and
Step 4 (#133) are prerequisites of specific steps here:

| This plan | Blocked on |
|---|---|
| D1 | — (replaces that plan's Step 2 / #130). **Still first; creating rather than editing the section does not move it.** But see the shared-file note below |
| D2 | D1 |
| D3 | D1, D2, and **#132** (the rerun hook and its audit log must exist) |
| D4 | D1, D2 |
| D5 | D4 |
| D6 | D5 |
| D7 | D5 (and D6, for cell-sourced blocks) |
| D8 | D2 and **#133** (the escalation packet must exist) |
| D9 | D7, D8; coordinates with **#131**, amends **#137** |
| D10 | D9; amends **#138** |

Internal order is **D1 → D2 → {D3, D4} → D5 → D6 → D7 → D8 → D9 → D10**. D3
and D4 are independent of each other and may run in parallel once D2 lands;
D8 needs only D2 and may run in parallel with D5-D7.

**Does D1 authoring a new canonical section change its position?** No — D1 was
already first and stays first; nothing in this plan can precede the format it
defines. But it does create a **shared-file coordination constraint that did not
exist when D1 was framed as an in-place edit**, and it is worth stating because
it is invisible from either unit alone:

- **#133 (2026-07-28 Step 4) also adds a new canonical `## ` section**
  (`## Fourth verdict: escalate-to-human`) with its own `codexMap`/`cursorMap`
  entries. D1 and #133 therefore both edit the same four files:
  `templates/persona-protocol.md`, both adapter ports, and
  `tests/adapter-protocol-parity.test.js`.
- They are **independent in content** — different sections, different map keys
  — so there is no ordering *requirement*. The hazard is mechanical, not
  logical: whichever lands second must **add** its map entries rather than
  replacing the map, and must re-run the parity test after rebasing. The
  stale-entry half of `checkPort()` means a clobbered entry fails loudly rather
  than silently, which is the good case.
- **Recommendation:** do not run D1 and #133 concurrently. Serialise them in
  either order. This is a `task-master` dispatch note, not a plan dependency.
- The same constraint does **not** apply to D2-D8, none of which touch the
  protocol template or the parity test.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every step's criteria are runnable
  commands; the security guardrails are proved by execution (an injection
  sentinel that must not appear, a path-traversal request that must `400`, a
  pid check after a timeout kill) rather than asserted in prose; R4's format
  contract runs the real producer into the real consumer; and the one claim
  that **cannot** be verified from this environment (that `127.0.0.1` is a
  potentially-trustworthy origin for the Clipboard API) is explicitly made
  non-load-bearing by a required fallback whose presence is asserted.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied.
  `.claude/agents/*.md` and `fileHashes` are regenerated via `bin/cli.js
  --update` in every step touching a template or agent source (G2); the
  dashboard is deterministic code, not an LLM pass. **Stated explicitly so the
  earlier confusion is not re-derived:** the 2026-07-28 plan cited P2 as the
  reason "No daemon is introduced". P2 governs LLM-versus-script derivation,
  not process lifetime, so a user-launched foreground process is **not** a P2
  deviation. Retracting that line is correcting a miscitation, not waiving a
  principle.
- P3 "Version-stamp discipline": satisfied — G1 makes the plugin.json bump plus
  a CHANGELOG entry a mandatory part of every unit's affected-files list.
- P4 "Optional personas degrade gracefully": satisfied — the dashboard binary
  is wholly independent of `personaSelection` (it reads the filesystem, not
  personas), so it cannot break when a persona is absent; and G3 `(if present)`
  phrasing is required on all new protocol and orchestrator prose.
- P5 "`tests/validate.sh` is the merge gate": satisfied — `bash
  tests/validate.sh` is a criterion on every step, and D2, D3, D4, D5, D6, D7,
  and D8 each explicitly register their new test file in it, since
  `validate.sh` has no auto-discovery and an unregistered test silently never
  runs.

## Steps

> Every step also touches the G1 version-bump triple:
> `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
> `.claude/persona-config.json` (`pluginVersion`). Not repeated below.

### Milestone M1 — format and shell

#### Step D1 — Microworld bundle format v2: `functions[]`, `location`, and the terminology rename

**Replaces the 2026-07-28 plan's Step 2 (#130) outright.** #130 was never
built, so **there is nothing here to edit in place — this step authors the
section from scratch.** Corrected 2026-08-10 after the orchestrator caught the
opposite claim in revision 2; see the architectural fact "NOTHING from the
2026-07-28 plan has been built" above, R3, and CHK28.

Add a **new** canonical section `## Microworld bundles (format and the check
contract)` to `templates/persona-protocol.md`, hand-port a condensed
equivalent into both adapter ports in their own established style, and — because
this is a new `## ` header — **add matching entries to both `codexMap` and
`cursorMap` in `tests/adapter-protocol-parity.test.js` in the same unit.** That
is not optional and not conditional: `checkPort()` asserts every canonical
header has a map entry and throws `canonical section "<h>" has no parity-map
entry — drift, decide present or deferred` otherwise. This is R3, and D1 is the
step that incurs it.

**Header name — deliberately not `## Microworlds`.** Because the section is
being authored fresh rather than renamed, the correct name under Open Question
5's terminology is available for free: this section specifies the **microworld
bundle** (the gitignored directory and its `run.sh` check), not the
**microworld** (the dashboard entry a human explores). Naming it `##
Microworlds` would bake the superseded meaning into the one header a reader
scans for. The parity-map keys must match this header **exactly**, since
`canonicalHeaders()` derives them live from the template.

**What this step must author, carried forward from #130's specification (which
was written but never implemented):** the gitignored-scratch storage rules, the
"not part of the reviewed diff" filesystem-check rule for the reviewer,
`run.sh`'s relocatability requirement (the `$(cd "$(dirname "$0")" && pwd)`
idiom), the `watch` globs, `timeoutSeconds`, `inputs/`, `expected/`, the
human-facing `README.md`, and the authority rule that a check result is advisory
unless a spec step's acceptance criteria names it. None of this exists on disk
today; #130 specified it and was closed in favour of this step. Treat that list
as a **requirements checklist to write**, not as text to preserve.

**What is new — `manifest.json` gains `functions[]`:**

```json
{
  "unit": "<unit-slug>",
  "watch": ["<project-relative glob>", "..."],
  "description": "<one line>",
  "timeoutSeconds": 60,
  "functions": [
    {
      "id": "<stable slug, unique within the bundle>",
      "group": "<the class or other grouping this belongs to>",
      "label": "<what a human reads on the tab>",
      "entry": "<bundle-relative path to an executable>",
      "description": "<one line: what this does AND one concrete thing to try>",
      "location": { "file": "<project-relative path>",
                    "startLine": 1, "endLine": 1 },
      "inputs": [
        { "name": "<key>", "type": "string|number|json|file",
          "default": <any>, "description": "<one line>" }
      ]
    }
  ]
}
```

**The `entry` execution contract**, stated precisely because everything
downstream depends on it:

- `entry` is executable, resolved **relative to the bundle directory**, and
  inherits `run.sh`'s relocatability rule so it survives the packet copy.
- It runs with **cwd = the project root** (same as the check) and receives the
  bundle's own absolute path in the environment variable
  `MICROWORLD_BUNDLE_DIR`. Nothing may hard-code a `microworlds/<unit>/`
  prefix.
- It receives **exactly one JSON object on stdin**: the input names from
  `inputs[]` mapped to the values the human supplied. Nothing is passed as a
  shell string and nothing is interpolated into a command.
- It prints its result to **stdout**, in whatever form is legible to a human.
- **Its exit code carries no verdict.** A non-zero exit is displayed as an
  error to the human and means nothing to any gate. `run.sh` remains the sole
  exit-code contract in the system.
- Each invocation is a **fresh process**. No state carries from one to the
  next (see D6 and Open Question 6).
- `functions` is **optional**. A bundle without it is fully valid and appears
  in the dashboard with its check status and nothing to invoke.

**The `location` field** is optional and names where in the repo the code this
function exercises actually lives: a **project-relative** `file` and an
inclusive `startLine`/`endLine`. It exists so a human's feedback can cite a
place (D7). `lead-programmer` authors it, because it is the persona that just
wrote the code. Absent → the dashboard shows no source excerpt and the feedback
block records `location: not declared`. Nothing derives it by guessing.

**Authoring policy.** `lead-programmer` SHOULD author `functions[]`, with
`location` on each, for units meeting the existing heavy-unit trigger and MAY
skip it otherwise. **Reference the trigger by pointing at
`docs/adr/0004-reviewer-roast-work-dual-model-routing.md` § "Heavy unit
trigger" (as amended by ADR-0013); do not restate the thresholds.** That ADR is
the single source of truth — verified 2026-08-10, and see the architectural
fact below, because the 2026-07-28 plan assumed it lived somewhere it does
not. A mandatory
interactive artifact on every unit is the ceremony that gets stubbed into a
one-line `echo` and stops meaning anything.

**Terminology.** The section states the eight terms from "Terminology" above
and states that the dashboard is **never an acceptance criterion**, using that
exact sentinel phrase (G5).

**Non-goals recorded in the text itself:** the rerun hook never invokes a
function entry (it would convert a silent hook into a hang), and the reviewer
never invokes one to adjudicate.

**Affected files**
- `templates/persona-protocol.md` (**new** `## Microworld bundles (format and
  the check contract)` section — authored, not edited; no such section exists)
- `adapters/cursor/rules/persona-protocol.mdc` (condensed hand-port, that
  port's own style)
- `adapters/codex/agents-md-fragment.md` (condensed hand-port, that port's own
  style)
- `tests/adapter-protocol-parity.test.js` — **REQUIRED, not conditional.** Add
  one entry keyed by the exact new header to **both** `codexMap` and
  `cursorMap`. `{ probe: '<text that must appear in that port>' }` is the
  expected form for both, since this section is being ported to both;
  `{ deferred: '<written justification>' }` is acceptable only with a stated
  reason in the value string (R3). Omitting either entry makes the test throw.
- `templates/persona-protocol-slim.md` — **deliberately NOT touched.** The slim
  tier (`explorer`, `researcher`, `scribe`) does not author or execute bundles.
  Listed here as an explicit non-edit so the omission is a decision rather than
  an oversight, and asserted negatively below.
- `agents/lead-programmer.md` (authoring policy; the `entry` contract;
  `location`)
- `agents/reviewer.md` (the check remains the sole execution contract; never
  invoke a function entry to adjudicate; bundle presence stays a filesystem
  check)
- `.claude/agents/{orchestrator,lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  and `.claude/persona-config.json` (regenerated by `bin/cli.js --update`, G2)

**Acceptance criteria**
- `node tests/adapter-protocol-parity.test.js` exits 0. **What this proves has
  changed:** not "no new section", but that the new canonical header has a
  `codexMap` **and** a `cursorMap` entry and that each port actually contains
  its probe text. `checkPort()` asserts map coverage in both directions, so
  exit 0 here is the real gate on R3.
- **Mutation proof for the above** (it would otherwise be possible to satisfy
  the parity test by never adding the section at all): deleting either map
  entry, or renaming the canonical header without updating both maps, must make
  `node tests/adapter-protocol-parity.test.js` exit non-zero. Run it once in
  each broken state; if either passes, the section was not actually added as a
  canonical `## ` header and the step is not done.
- `grep -c '^## Microworld bundles (format and the check contract)$' templates/persona-protocol.md`
  is **1** — the section exists, at top level, under the exact header the
  parity maps are keyed by.
- `node -e "const t=require('fs').readFileSync('tests/adapter-protocol-parity.test.js','utf8'); process.exit(/Microworld bundles \(format and the check contract\)/.test(t)?0:1)"`
  exits 0, and the header appears **twice** in that file (once per map) —
  `grep -c 'Microworld bundles (format and the check contract)' tests/adapter-protocol-parity.test.js`
  is **2**. A count of 1 means only one port was mapped.
- `bash tests/validate.sh` exits 0.
- `grep -q 'functions' templates/persona-protocol.md` and
  `grep -q 'MICROWORLD_BUNDLE_DIR' templates/persona-protocol.md` both exit 0.
- `grep -q 'exactly one JSON object on stdin' templates/persona-protocol.md`
  exits 0 — the sentinel phrase separating this contract from a
  shell-argument one. This is the single instruction standing between the
  design and a command-injection surface, so it is asserted rather than trusted
  to survive editing.
- `grep -q 'startLine' templates/persona-protocol.md` exits 0 and
  `grep -q 'location: not declared' templates/persona-protocol.md` exits 0 —
  proving the **absent** case's spelling was written down, not only the present
  case. Without it a persona invents its own spelling and the block stops being
  parseable.
- `grep -q 'never an acceptance criterion' templates/persona-protocol.md`
  exits 0 **and** the same grep against `.claude/agents/reviewer.md` exits 0
  (G5 reached the persona that would otherwise be tempted).
- The three storage sentinels each exit 0 against
  `templates/persona-protocol.md` — `not part of the reviewed diff`,
  `gitignored`, `dirname`. All three are **0 today** (verified 2026-08-10:
  nothing in that file mentions microworlds at all), so these are
  post-conditions this step must create, not invariants it must preserve.
  Carried over from #130's specification because the rules are still correct,
  not because any text exists to protect.
- `grep -q 'not part of the reviewed diff' .claude/agents/reviewer.md` exits 0.
- **Slim tier stays clean:**
  `grep -ci 'microworld' templates/persona-protocol-slim.md` is **0**, and
  `grep -ci 'microworld' .claude/agents/explorer.md` is **0**, while
  `grep -ci 'microworld' .claude/agents/lead-programmer.md` is ≥ 1. This proves
  the full/slim fan-out split held — a new full-protocol section must reach the
  six full-protocol personas and none of the three slim ones.
- **Single source of truth for the heavy-unit trigger**, asserted as a pair
  rather than the unsatisfiable single grep the 2026-07-28 plan used:
  `grep -c 'impacted files' templates/persona-protocol.md` is **0** (the
  thresholds were not copied in) **and**
  `grep -q '0004-reviewer-roast-work-dual-model-routing' templates/persona-protocol.md`
  exits 0 (the authoring policy points at the ADR that actually defines them).
- `grep -ci 'microworld' adapters/cursor/rules/persona-protocol.mdc` ≥ 1 and
  the same for `adapters/codex/agents-md-fragment.md` — proves the ports were
  actually hand-written, not merely mapped. A `{ deferred: … }` entry in either
  map is acceptable only if this criterion is explicitly waived for that port in
  the unit's commit message, with the justification in the map value string
  (R3).
- `grep -q 'functions' .claude/agents/lead-programmer.md` exits 0 (proves
  `--update` propagated to the persona that authors bundles).
- **Stamp sync (R2, G6):** the six full-protocol copies all carry the current
  plugin version —
  `v=$(node -p "require('./.claude-plugin/plugin.json').version"); for n in orchestrator lead-programmer reviewer spec-master task-master milestone-auditor; do grep -q "antislop v$v |" ".claude/agents/$n.md" || exit 1; done`
  exits 0. (Replaces the former `git diff --name-only` check, which is empty by
  construction at review time — see G6.)

#### Step D2 — `--dashboard`: CLI flag, HTTP server, discovery, token, empty state

The shell. Everything a human can see, before anything can be invoked.

**CLI.** `node bin/cli.js --dashboard` dispatches early in `main()`
(`bin/cli.js:1788`), alongside `--update` and before any scaffolding path, so
no existing-install guard can intercept it. Optional `--dashboard-port=<n>`;
default is an ephemeral port. On start it prints one line: the full
`http://127.0.0.1:<port>/?t=<token>` URL. It then runs in the foreground until
interrupted.

**Modules** live under `bin/dashboard/` — chosen because `package.json`'s
`files` already ships the whole `bin` directory and `validate.sh`'s npm-pack
check needs no new entry. A new top-level directory would require both.

**Discovery.** Enumerate `microworlds/*/manifest.json` from the project root.
For each, read `unit`, `description`, and `functions[]`. Malformed JSON, a
missing `manifest.json`, a missing `entry`, or a non-executable `entry` never
crashes the server: the bundle (or the individual function) is listed with an
explicit `disabled` flag and a one-line reason. **Fail soft, always** — this
process is a viewer, and a bad bundle is a thing to show a human, not a thing
to die on.

**Identity.** Every microworld carries a namespaced id, `working:<unit-slug>`,
so Step D8's packets (`packet:<task-id>`) can coexist with a working bundle of
the same unit without collision.

**HTTP API — the single seam.** All behavioural criteria in this plan are
requests against it.

| Method | Path | Returns | Added by |
|---|---|---|---|
| `GET` | `/` | the HTML client | D2 (placeholder), D5 (real) |
| `GET` | `/api/bundles` | `[{ id, unit, source, description, disabled, disabledReason, functions: [{ id, group, label, description, location, inputs, disabled, disabledReason }], status }]` | D2 |
| `GET` | `/api/status` | the parsed recent check results | D3 |
| `POST` | `/api/invoke` | one function invocation | D4 |
| `GET` | `/api/context` | `{ commit, projectRoot }` | D7 |
| `GET` | `/api/source` | a bounded source excerpt | D7 |

**Auth.** Every request requires the launch token as `?t=<token>` or an
`X-Antislop-Token` header. Missing or wrong → `401` with an empty body. The
token is generated per launch from `node:crypto` and never written to disk.

**Bind.** `127.0.0.1` only, never `0.0.0.0`.

**Empty state.** No `microworlds/` directory, or a directory with no valid
bundle, is the **normal** case in a fresh clone (R8). The server starts anyway,
`/api/bundles` returns `[]`, and `/` renders an explicit message naming where
bundles come from. It never exits non-zero and never warns.

**Concurrency and state.** Two dashboards on one repo is legal: each binds its
own ephemeral port with its own token, and neither writes anything. No
lockfile, no pidfile, no persisted state of any kind.

**Affected files**
- `bin/dashboard/server.js` (new — HTTP server, routing, auth, bind)
- `bin/dashboard/discover.js` (new — bundle enumeration and manifest parsing)
- `bin/dashboard/index.html` (new — placeholder client; the real UI is D5)
- `bin/cli.js` (`--dashboard` / `--dashboard-port=` dispatch in `main()`)
- `tests/dashboard-server.test.js` (new)
- `tests/validate.sh` (**register the new test explicitly** — no auto-discovery)
- `README.md` is deliberately **not** touched here; documentation lands in D9
  once the feature is complete, so the README never describes a half-built
  surface.

**Acceptance criteria**
- `node tests/dashboard-server.test.js` exits 0, with cases asserting:
  (a) with no `microworlds/` directory, the server starts and
      `GET /api/bundles` with a valid token returns `200` and `[]`;
  (b) with two fixture bundles, `GET /api/bundles` returns both, with
      `functions[]`, `group`, and `location` values matching the fixtures'
      manifests;
  (c) a request with **no** token returns `401`, and one with a **wrong** token
      returns `401`;
  (d) the listening address is exactly `127.0.0.1` — asserted from
      `server.address().address`, not from reading the source;
  (e) a bundle with malformed `manifest.json` and a bundle whose `entry` does
      not exist are both returned with `disabled: true` and a non-empty
      `disabledReason`, and the server still returns `200` — fail-soft proved
      by execution;
  (f) two servers started simultaneously on the same project both serve `200`
      on their own port with their own token, and neither accepts the other's
      token.
- `bash tests/validate.sh` exits 0 **and** its output includes an `OK` line for
  `tests/dashboard-server.test.js` — proving the test was registered and is not
  silently skipped.
- **G4, zero dependencies:**
  `python3 -c "import json,sys; p=json.load(open('package.json')); sys.exit(0 if not p.get('dependencies') and not p.get('devDependencies') else 1)"`
  exits 0. The test suite must pass with no `node_modules/` present.
- **G5, never on a gate path:** `grep -c dashboard hooks/hooks.json` is **0**,
  and `grep -rl dashboard hooks/scripts/ | wc -l` is **0**. This is the
  executable form of "nothing auto-starts it and no gate consults it".
- **Writes nothing:** `git status --porcelain` is byte-identical before and
  after a full start → discover → shutdown cycle.
- `node bin/cli.js --dashboard --dashboard-port=0` prints a line matching
  `http://127\.0\.0\.1:[0-9]+/\?t=.+` and exits 0 on `SIGINT`.
- **Shipped with no packaging edit** — asserted as two post-conditions on the
  committed tree (G6), not as a diff:
  - `npm pack --dry-run --json` lists at least one `bin/dashboard/` path
    (it ships), **and**
  - `grep -Fq "included = ['agents/', 'hooks/', 'templates/', 'skills/']" tests/validate.sh`
    exits 0 — the npm-pack `included` list still holds its **expected prior
    value**, quoted literally, proving it was not extended to make
    `bin/dashboard/` ship. Verified 2026-08-10: currently passes, and
    mutation-proved by appending `'bin/dashboard/'` to that list, which the
    check catches.

#### Step D3 — Live status by tailing the rerun hook's audit log

**Blocked on #132** (the rerun hook and `.claude/microworld-audit.log` must
exist).

"Live tests of key infrastructure pieces", in the user's phrase, is delivered
by **consuming the signal that already exists** rather than by running anything
a second time. The rerun hook already executes each matching bundle's check on
every `Edit`/`Write` and appends
`<ts> unit=<slug> result=pass|fail|timeout file=<path>` to
`.claude/microworld-audit.log`. The dashboard tails that file.

Two watchers, and only two:

1. **Status** — tail `.claude/microworld-audit.log`; the most recent line per
   unit becomes that microworld's `status`. The dashboard **never runs a check
   itself**; doing so would double every execution and race the hook.
2. **Structure** — `fs.watch` on `microworlds/` for bundles appearing and
   disappearing, so a microworld added by `lead-programmer` mid-session shows
   up without a restart.

The log may be absent (nothing has run yet) or unreadable — both yield
`status: null` and never an error.

**R4's cross-language contract test is the substance of this step.** The hook
is bash and the parser is JavaScript; a prose agreement would drift silently.
The test runs the **real hook** against a fixture and feeds its **real emitted
line** into the **real parser**.

**Affected files**
- `bin/dashboard/audit-log.js` (new — tail and parse)
- `bin/dashboard/discover.js` (attach `status`; `fs.watch` on `microworlds/`)
- `bin/dashboard/server.js` (`GET /api/status`)
- `tests/microworld-audit-contract.test.js` (new — the R4 contract test)
- `tests/dashboard-server.test.js` (extend)
- `tests/validate.sh` (**register the new test**)
- `hooks/scripts/microworld-rerun.sh` — **header comment only**: state that the
  audit line format is a consumed interface with a Node parser on the other
  side, and name the contract test. No logic change. This is the note that
  stops a future maintainer from "tidying" the log format.

**Acceptance criteria**
- `node tests/microworld-audit-contract.test.js` exits 0: it executes
  `hooks/scripts/microworld-rerun.sh` with canned hook-input JSON against a
  fixture bundle whose check fails, reads the line the hook actually appended,
  parses it with `bin/dashboard/audit-log.js`, and asserts `{ unit, result:
  'fail', file }` are all recovered. **Mutation proof:** changing the hook's
  emitted separator must make this test fail — if it does not, the test is
  vacuous and the step is not done.
- `node tests/dashboard-server.test.js` exits 0, with new cases asserting:
  (g) with a fixture audit log, `GET /api/bundles` reports each unit's **most
      recent** line as its status, not its first;
  (h) with **no** audit log present, every bundle reports `status: null` and
      the response is still `200`;
  (i) appending a new line to the log is reflected in a subsequent
      `GET /api/bundles` without restarting the server;
  (j) creating a new bundle directory is reflected in a subsequent
      `GET /api/bundles` without restarting the server.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/microworld-audit-contract.test.js`.
- `grep -q 'consumed interface' hooks/scripts/microworld-rerun.sh` exits 0.
- `grep -c 'run.sh' bin/dashboard/audit-log.js` is **0** — the dashboard reads
  results, it does not execute checks. A non-zero count means the
  double-execution hazard was reintroduced.

### Milestone M2 — invocation and interaction

#### Step D4 — `POST /api/invoke`: running one function entry, with the guardrails

**Request:** `{ id, functionId, inputs: { <name>: <value> } }`.
**Response:** `{ ok, exitCode, stdout, stderr, durationMs, timedOut, truncated }`.

**Execution**, following D1's `entry` contract exactly:

- Spawn via `child_process.spawn` with an **argv array and no shell**. The
  entry's own path is the only thing on the command line.
- cwd = project root; `MICROWORLD_BUNDLE_DIR` = the bundle's absolute path.
- Human-supplied `inputs` are serialised to **one JSON object on stdin**.
  Values are never placed on a command line, never interpolated into a string,
  and never passed to a shell.
- Kill on `timeoutSeconds` (manifest value, default 60) and return
  `timedOut: true` rather than hanging the request.
- Cap captured `stdout` and `stderr` at 1 MiB each; on overflow, truncate and
  set `truncated: true`.
- A non-zero exit is reported as-is and means nothing to any gate.
- Concurrent invocations are allowed; each is its own process, nothing is
  serialised or queued.
- Unknown `id`, unknown `functionId`, or a disabled function → `400` with a
  reason, never a spawn attempt.

**Affected files**
- `bin/dashboard/invoke.js` (new)
- `bin/dashboard/server.js` (`POST /api/invoke` route)
- `tests/dashboard-invoke.test.js` (new)
- `tests/validate.sh` (**register the new test**)

**Acceptance criteria**
- `node tests/dashboard-invoke.test.js` exits 0, with cases asserting:
  (a) a fixture entry echoing its stdin back returns `200` with the supplied
      inputs recovered intact from `stdout` — the JSON-on-stdin contract proved
      end to end;
  (b) **injection proof (mutation-style):** an input value of
      `"; touch /tmp/antislop-microworld-pwned #"` is delivered verbatim in the
      entry's stdin JSON, and `test -e /tmp/antislop-microworld-pwned` exits
      **non-zero** afterwards. If this sentinel ever appears, the no-shell rule
      has been broken;
  (c) an entry sleeping past `timeoutSeconds` returns `timedOut: true`, and the
      child process is no longer running afterwards (asserted by pid check, not
      by elapsed time alone);
  (d) an entry printing more than 1 MiB returns `truncated: true` with captured
      output at or below the cap;
  (e) an entry exiting non-zero returns `200` with that `exitCode` — the
      dashboard reports, it does not adjudicate;
  (f) an unknown `functionId` returns `400` and no process is spawned;
  (g) `POST /api/invoke` with no token or a wrong token returns `401` and no
      process is spawned — the guardrail holds on the one endpoint that
      executes code;
  (h) two concurrent invocations of the same entry both complete and neither
      sees the other's output.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-invoke.test.js`.
- `grep -cE "shell:\s*true" bin/dashboard/invoke.js` is **0**, and
  `grep -cE "execSync|[^a-z]exec\(" bin/dashboard/invoke.js` is **0** — the
  no-shell rule asserted structurally as well as behaviourally, because case
  (b) can only prove the absence of one specific escape.
- `git status --porcelain` is byte-identical before and after a full invoke
  cycle against a fixture that itself writes nothing.

#### Step D5 — The browser client: nested tabs, input forms, output

The thin client over D2/D3/D4's seam. No new server behaviour.

- **Left rail** — one entry per microworld: unit slug, description, and live
  check status as a coloured indicator (pass / fail / timeout / unknown),
  refreshed by polling `/api/bundles`.
- **Nested tabs** — within a microworld, one tab per `group` (the class), and
  within a group one tab per function. This is the user's "nested tab with the
  class and its functions" literally. A bundle with no `functions[]` shows its
  status and an explicit "no function entries declared" note.
- **Input form** — generated from `inputs[]`: a text field for `string`, a
  number field for `number`, a JSON-validated textarea for `json`, a path field
  for `file`. `default` prefills. `description` shows beside each field — this
  is where D1's required "one concrete thing to try" reaches the human who has
  never seen the code.
- **Output pane** — `stdout`, `stderr`, exit code, and duration, with explicit
  banners for `timedOut` and `truncated`. A non-zero exit is displayed
  neutrally as a result, never as a verdict.
- **Empty state** — when `/api/bundles` returns `[]`, an explicit message
  naming what a microworld bundle is and where it comes from.

No framework, no build step, no bundler: one HTML file with inline
module-type JavaScript, consistent with G4.

**Affected files**
- `bin/dashboard/index.html` (the real client)
- `tests/dashboard-client.test.js` (new — structural assertions over the served
  HTML; behaviour is covered at the API seam)
- `tests/validate.sh` (**register the new test**)

**Acceptance criteria**
- `node tests/dashboard-client.test.js` exits 0, with cases asserting:
  (a) `GET /` with a valid token returns `200` and `text/html`;
  (b) the served HTML references `/api/bundles` and `/api/invoke` — proving the
      client consumes the seam rather than reimplementing discovery;
  (c) the served HTML contains no `<script src=` pointing outside the origin —
      no CDN, no remote fetch, consistent with a loopback-only tool;
  (d) `GET /` with no token returns `401`.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-client.test.js`.
- `grep -c 'node_modules' bin/dashboard/index.html` is **0**, and
  `package.json`'s `scripts` gains nothing (no build step).
- Manual confirmation, recorded as a note and **not** a gate: with a fixture
  bundle present, a human opens the printed URL, navigates group → function,
  submits an input, and sees output. Stated as a note because it is the one
  claim in this plan no command can make.

#### Step D6 — Notebook interaction: cells, history, and edit-and-re-run

The user's "similar to a Jupyter notebook … to have the interaction of it".
**Per Open Question 6, answer (a), this is a client-side change only — the HTTP
API gains nothing and the execution model is untouched.**
That is a feature, not a shortcut: the notebook adds zero new attack surface.

- Each `POST /api/invoke` result becomes a **cell**:
  `{ cellId, functionId, inputs, startedAt, result }`, appended to that
  microworld's cell list in order.
- **Re-running appends a new cell** rather than overwriting the old one, so the
  history of what was tried and what came back accumulates — the property that
  makes a notebook a notebook.
- Each cell offers **edit-and-re-run** (prefills a fresh input form from that
  cell's inputs), collapse/expand of its output, and remove.
- Cells belong to a function's tab and persist while the tab is switched away
  and back.
- **Cell state is in-page only.** It is lost on refresh and never written to
  disk, preserving guardrail 5. Outputs are cheap to regenerate; the human's
  own words are not, which is exactly why comments (D7) are the thing Open
  Question 7 is about and cells are not.
- **No shared state between cells, and the UI must say so.** Each cell is a
  fresh process (D1, D4). Cell 2 cannot see cell 1's variables. A visible,
  permanent line in the notebook pane states this in plain words. R11 is the
  reason: anyone carrying Jupyter expectations will assume otherwise, and a
  silent mismatch is worse than no notebook at all.

**Affected files**
- `bin/dashboard/index.html` (cell list, per-cell controls, the no-shared-state
  notice)
- `tests/dashboard-notebook.test.js` (new)
- `tests/validate.sh` (**register the new test**)

**Acceptance criteria**
- `node tests/dashboard-notebook.test.js` exits 0, with cases asserting:
  (a) **fresh-process proof:** a fixture entry that prints its own PID,
      invoked twice, returns two **different** PIDs. This proves by execution
      that no warm kernel was introduced and that D1's fresh-process contract
      holds — the single most important thing to keep true under this step;
  (b) **no-shared-state proof:** a fixture entry that increments an in-process
      counter and prints it returns the same value on every invocation, never
      an increasing one;
  (c) the server's route table is **unchanged** from D2+D3+D4 — no endpoint was
      added for notebook state, proving the notebook is a client concept;
  (d) `GET /` still returns `200` and the served HTML references
      `/api/invoke` exactly as D5 required (no regression).
- The served HTML contains the no-shared-state sentence:
  `grep -q 'each cell runs in a fresh process' bin/dashboard/index.html`
  exits 0. R11's mitigation is asserted rather than trusted to be inferred.
- `grep -c 'localStorage\|sessionStorage\|indexedDB' bin/dashboard/index.html`
  is **0** — cells are in-page, not persisted, so guardrail 5 holds on the
  client side too.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-notebook.test.js`.
- `git status --porcelain` is byte-identical before and after a full multi-cell
  session.

#### Step D7 — Annotate a function and copy a feedback block

The other half of the user's addition: attach a comment to what you are looking
at, and copy something a coding agent can act on without asking "where?".

**Source excerpt (new read primitive — see R10).** When a function declares
`location`, the client renders a read-only excerpt of `file` lines
`startLine..endLine`, fetched from `GET /api/source`. The endpoint:

- resolves `file` against the project root and **verifies the resolved path
  falls inside it**; anything escaping → `400`, no read (guardrail 6);
- returns `404` with a stated reason when the file does not exist, and a
  stated reason when the line span is out of range — **never a fabricated
  excerpt and never a silent empty one**;
- caps the returned span (e.g. 400 lines) so a pathological `endLine` cannot
  stream a whole file;
- is read-only. The dashboard never writes to a source file.

**Comment.** A free-text box per function, and per cell. **Ephemeral in the
browser tab**, per Open Question 7, answer (a): the clipboard is the handoff,
and the durable copy lives in the agent conversation it gets pasted into.
Nothing is written to disk, so a comment is lost on refresh — which is the
accepted cost of guardrail 5, not an oversight.

**The feedback block.** A "Copy feedback" button produces a fixed markdown
block. The shape is fixed so an LLM parses it reliably and a human can grep
it:

```
## Microworld feedback — <unit-slug> / <function label>

- function: `<function id>` (group: `<group>`)
- location: `<file>:<startLine>-<endLine>`   |   location: not declared
- commit: <sha at copy time>
- bundle: microworlds/<unit-slug>/

### Comment
<the human's text, verbatim>

### Last run
- inputs: <compact JSON>
- exit: <code>   duration: <ms>

<output, fenced, truncated with an explicit marker>
```

- Location fields default from `location`; the human may narrow the line range
  before copying.
- `commit` comes from `GET /api/context` (`git rev-parse HEAD`, read-only). It
  is what makes a possibly-stale line range interpretable (R9) — the same
  device the `.escalated` marker already uses.
- The `### Last run` section appears **only** when copying from a cell; a block
  copied from a function with no run yet omits it rather than emitting empty
  fields.
- The comment is reproduced **verbatim**, including backticks and fenced
  blocks. The formatter must not corrupt or truncate it.

**Clipboard mechanics.** `navigator.clipboard.writeText` on a user-gesture
click. `http://127.0.0.1` is a potentially-trustworthy origin so this is
expected to work over plain HTTP — but that is a claim about browser behaviour
this project cannot verify, so a `<textarea>` + `document.execCommand('copy')`
fallback is **required**, and its presence is asserted. The feature must not be
load-bearing on an unverifiable claim (P1).

**Affected files**
- `bin/dashboard/feedback-block.js` (new — the pure formatter. Named for the
  artifact, **not** `handoff.js`: `handoff` is a shipped skill and
  `.claude/wip-handoff.*` an existing artifact, and the D7 criterion
  `grep -ci handoff bin/dashboard/` is 0 enforces the separation)
- `bin/dashboard/source.js` (new — bounded, root-confined excerpt reader)
- `bin/dashboard/server.js` (`GET /api/source`, `GET /api/context`)
- `bin/dashboard/index.html` (excerpt pane, comment box, copy button, fallback)
- `tests/dashboard-feedback.test.js` (new)
- `tests/validate.sh` (**register the new test**)

**Acceptance criteria**
- `node tests/dashboard-feedback.test.js` exits 0, with cases asserting:
  (a) `GET /api/context` returns the same SHA as `git rev-parse HEAD` run in
      the same tree;
  (b) a function declaring `location` yields an excerpt containing **exactly**
      the declared line range — not one line more or fewer;
  (c) **path-traversal proof:** `location.file` of `../../etc/passwd` (and an
      absolute path) each return `400` and read nothing. This is the guardrail
      R10 exists for and it is proved by execution, not by inspection;
  (d) a `location` naming a nonexistent file returns a stated reason and no
      excerpt, and a `startLine` beyond EOF does the same — neither fabricates
      nor returns a silent empty body;
  (e) an `endLine` far beyond the cap returns at most the capped number of
      lines;
  (f) `GET /api/source` and `GET /api/context` with no token each return `401`;
  (g) the formatter reproduces a comment containing backticks and a fenced code
      block **byte-for-byte**;
  (h) a function with **no** `location` produces a block containing exactly
      `location: not declared` — the degradation string from D1, so the two
      artifacts agree;
  (i) a block copied from a function with no run contains no `### Last run`
      section, and one copied from a cell does.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-feedback.test.js`.
- `grep -q 'navigator.clipboard' bin/dashboard/index.html` **and**
  `grep -q 'execCommand' bin/dashboard/index.html` both exit 0 — the fallback
  exists, so the unverifiable secure-context claim is not load-bearing.
- `grep -ci 'handoff' bin/dashboard/` (recursive) is **0** — the naming
  decision held, and the shipped `handoff` skill keeps sole ownership of that
  word.
- **Writes nothing still holds:** `git status --porcelain` is byte-identical
  before and after a full annotate-and-copy cycle, and
  `grep -c 'writeFile\|appendFile\|mkdir' bin/dashboard/source.js` is **0**.

### Milestone M3 — reach and record

#### Step D8 — Escalation packets as a second read source

**Blocked on #133** (the escalation packet must exist). May run in parallel
with D5-D7.

Microworld bundles are gitignored working-tree scratch; the durable copy of an
escalated unit's bundle is the packet at `.claude/human-review/<task-id>/`.
This step preserves the single genuinely valuable property of the superseded
Step 9 (F1): a human exploring an escalated unit **in a later session**, after
the working tree has moved on.

- Discovery additionally enumerates `.claude/human-review/*/`, listing each as
  a microworld with `source: "packet"` and id `packet:<task-id>`.
- Packets appear in a **separately labelled section**, never interleaved with
  working bundles, so a human is never confused about which copy they are
  exercising.
- A packet and a working bundle for the same unit coexist without collision —
  that is what D2's id namespacing is for.
- Packets have no live status: they are snapshots and the rerun hook does not
  watch them. `status` is always `null` for `source: "packet"`.
- **This is a second read location, not a coupling.** The dashboard never reads
  `humanReviewMode`, never reads a `.escalated` marker, never writes anything
  under `.claude/`, and its behaviour does not change when human review is off.
  The scope trigger remains "every unit that has a bundle".
- `.claude/human-review/` is ungated by `reviewed-path-gate.sh` by design (that
  gate blocks the `.claude/reviewed` substring only), which is precisely why
  the packet was sited there — the dashboard inherits that reachability for
  free and must not be "tidied" to read the marker directory instead.

**Affected files**
- `bin/dashboard/discover.js` (second read source; `source` and id namespacing)
- `bin/dashboard/index.html` (the separate packet section)
- `tests/dashboard-packets.test.js` (new)
- `tests/validate.sh` (**register the new test**)

**Acceptance criteria**
- `node tests/dashboard-packets.test.js` exits 0, with cases asserting:
  (a) a fixture packet at `.claude/human-review/<task-id>/` appears in
      `GET /api/bundles` with `source: "packet"` and id `packet:<task-id>`;
  (b) a working bundle and a packet for the **same** unit slug both appear with
      distinct ids — the collision case;
  (c) every `source: "packet"` entry has `status: null`, even with an audit log
      present that names that unit;
  (d) a function entry inside a packet is invocable via `POST /api/invoke` and
      resolves its assets from the **packet's** directory, not from
      `microworlds/` — the executable proof that D1's relocatability rule
      survived the copy;
  (e) with no `.claude/human-review/` directory at all, the response is `200`
      and contains only working bundles.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-packets.test.js`.
- `grep -rc 'humanReviewMode' bin/dashboard/ | grep -v ':0$' | wc -l` is **0**
  and the same for `escalated` — executable proof that the dashboard is
  decoupled from the escalation machinery, which is the user's second fixed
  premise.
- `git status --porcelain` is byte-identical before and after a packet
  discovery and invoke cycle.

#### Step D9 — Documentation and packaging

- `README.md` gains a **Microworld dashboard** section: what it is, how to
  start it (`node bin/cli.js --dashboard`), that nothing auto-starts it, that
  it binds loopback only and requires the printed token, that it writes
  nothing, that cells are in-page and lost on refresh, that cells share no
  state, and that it is never a gate. Document the feedback block's shape and
  that `location` is authored by `lead-programmer`.
- Under **Known limitations**, add R7 (the token appears in scrollback and the
  address bar — a per-launch, non-persisted secret on a loopback endpoint,
  accepted), R1 (bundles are gitignored, so nothing can verify one was
  authored; the dashboard is only as good as the bundles present), and R9
  (`location` line numbers can go stale; the block carries the commit SHA so a
  receiving agent can re-derive).
- **Bundle documentation is authored, not updated.** `grep -ci microworld
  README.md` is **0** today — #137 (Step 8a) was never built, so there is no
  existing bundle section to amend. This step writes it: format v2
  (`functions[]`, `location`), the storage rules, and the terminology from Open
  Question 5.
- **Ordering with #137.** If #137 lands first, this step amends its section; if
  this step lands first, #137 must not re-author one. Either is fine, but
  **they must not both write a bundle section independently** — that is the
  concrete collision risk, and whichever runs second must read the README
  before writing. `task-master` should state this in both dispatches.
- **Packaging assertions**, so the zero-change claim is proved rather than
  assumed: `bin/dashboard/` ships because `files` already contains `bin`, and
  `validate.sh`'s npm-pack `included`/`excluded` lists need no edit.
- Coordinates with **#131**: no new `.gitignore` entry is needed, because the
  dashboard writes nothing. State this in that unit's dispatch so nobody adds a
  speculative ignore line for a state directory that does not exist. This is
  settled, not provisional: Open Question 7 was answered (a) on 2026-08-10, so
  the dashboard persists nothing and #131 gains no ignore line.

**Affected files**
- `README.md`

**Acceptance criteria**
- `bash tests/validate.sh` exits 0, including its npm-pack composition check
  unchanged.
- `grep -q 'dashboard' README.md` exits 0 and the surrounding paragraph
  contains `127.0.0.1`.
- `grep -q 'node bin/cli.js --dashboard' README.md` exits 0.
- `grep -q 'feedback block' README.md` exits 0 and
  `grep -q 'each cell runs in a fresh process' README.md` exits 0 — the two
  things a user will most plausibly assume wrongly are documented, not just
  implemented.
- The token limitation appears under Known limitations:
  `awk '/^## Known limitations/,/^## /' README.md | grep -qi 'token'` exits 0.
- `npm pack --dry-run --json | python3 -c "import json,sys; f=[x['path'] for x in json.load(sys.stdin)[0]['files']]; sys.exit(0 if any(p.startswith('bin/dashboard/') for p in f) else 1)"`
  exits 0.
- **The packaging claim held and no `included` list needed extending** —
  asserted as a post-condition (G6), not as a diff:
  `grep -Fq "included = ['agents/', 'hooks/', 'templates/', 'skills/']" tests/validate.sh`
  exits 0, i.e. the list still holds its expected prior value verbatim. Same
  assertion D2 makes, deliberately repeated here because D9 is the step that
  *documents* the claim and must not be able to pass while quietly having
  broken it.

#### Step D10 — `scribe`: glossary, ADR, wiki

**Reconciled 2026-08-11 (revision 3), issue #323, both Open Questions
answered on the recommended default.** This step was rewritten from scratch
after a re-verification found that six of its eight originally-required
`CONTEXT.md` terms, and the Cell/Notebook pair that stands in for "notebook
cell", had *already shipped* under units #314/#315/#319/#320/#322/#138 by the
time this step would have dispatched — the "eight entries" framing below and
`ADR-0017`'s number are both now factually wrong (0017 and 0018 were taken by
unrelated ADRs, `0017-microworld-bundles-gitignored.md` and
`0018-human-in-the-loop-review-on-by-default.md`, landed 2026-08-11). This
revision is a **reconciliation**, not a rewrite of intent: it re-verifies each
of the original eight terms against current `CONTEXT.md`, authors only the
terms still genuinely missing, and drops instructions to re-author anything
that already stands verbatim. See "Reconciliation ledger" below for the term-
by-term evidence, and `docs/plans/2026-08-11-gh138-debug-spec-wiki-accuracy.md`
Step 6 for the verified-RED discipline this revision follows for its
acceptance criteria.

**Reconciliation ledger (re-verified 2026-08-11, live against HEAD, not
assumed from the prior pass):**

| Original term | Status in `CONTEXT.md` today | Action this step takes |
|---|---|---|
| Microworld | Shipped (unit #314, refreshed #138) | None — verify only |
| Microworld bundle | Shipped (unit #314, refreshed #138) | None — verify only |
| Function entry | Shipped (unit #314) | None — verify only |
| Microworld dashboard | Shipped (unit #314/#322) | Append one contrast sentence (see below) |
| Feedback block | Shipped (unit #320), already contrasts with `handoff` | None — verify only |
| Notebook cell | **Not present under that name.** Shipped instead as the **Cell** + **Notebook** pair (unit #319) — see "Cell/Notebook resolution" below | None — this is a shipped-design win, not a gap; do not add a standalone "notebook cell" entry |
| The check | **Genuinely missing.** `the check` appears only inside the section title `**Microworld bundles (format and the check contract)**:` (line 520) and once in unrelated prose (line 242, "test failures prove the check detects real problems") — no headword entry defines it | Author new entry |
| Function location | **Genuinely missing.** Zero occurrences. `**Function entry**`'s own text mentions "location (relative path)" as one of its fields, but there is no standalone entry contrasting `location` with the code-review graph or noting staleness | Author new entry |
| — (not an original term) | "never an acceptance criterion" — present in `templates/persona-protocol.md` and all four persona copies, **zero occurrences in `CONTEXT.md`** | Fold the literal phrase into the new **The check** entry and the existing **Microworld dashboard** entry |
| — (not an original term) | "microworld rerun hook" — zero occurrences anywhere in the repo except this plan's own prose; the shipped name is `microworld-rerun.sh`, glossed generically as a **Reporter** (see **Reporter** and **Microworld audit log** entries) | **Decision: do not mint it.** See "Rerun-hook naming decision" below |

**Cell/Notebook resolution (Open Question 2, answered 2026-08-10, recorded
here per the user's instruction — not a re-litigation of #319's already-PASSed
work).** The user's original prose ("turning MicroWorld's environment/
dashboard into something similar to a Jupyter notebook... rather to have the
interaction of it") used "notebook cell" informally. What shipped at unit
#319 is more precise than that one phrase: **Cell** (one recorded invocation —
function, input set, output, held in browser session state) and **Notebook**
(the per-function ordered list of Cells, keyed by `functionId`, in-memory
only, lost on refresh) as two distinct, already-contrasted glossary entries
(`CONTEXT.md:848` and `:860`). This is a **strictly better outcome** than a
single "notebook cell" entry would have been — it separately names the
invocation-record noun and the ordering/collection noun, which the original
plan's single term conflated. Nothing further is required of this step.

**Rerun-hook naming decision.** The original draft asked the **Microworld
dashboard** entry to contrast with "the microworld rerun hook" as if that
were an established term. It is not: the shipped, glossary-established name is
the `microworld-rerun.sh` **Reporter** hook (`CONTEXT.md`'s **Reporter** entry,
line 69, and **Microworld audit log** entry, line 90). `templates/
persona-protocol.md:514` and the superseded 2026-07-28 plan both already use
the lowercase, informal phrase "the rerun hook" in running prose, but neither
treats it as a defined term. **Decision: do not introduce "microworld rerun
hook" as a new glossary headword.** Minting one now would create exactly the
near-synonym hazard this plan's own **Feedback block**/`handoff` decision
exists to avoid (see the Terminology section above) — a second name for a
thing that already has one, discoverable only by `antislop:ubiquitous-
language`'s Lens 2. Instead, the **Microworld dashboard** entry is amended to
contrast against the shipped name directly: "the `microworld-rerun.sh`
**Reporter** hook", not a new term.

**What this step now builds, in full (replacing the original list):**

- `CONTEXT.md` (owned by `scribe`) gains **two** new entries and **one**
  amendment to an existing entry:
  - **The check** (new) — the bundle's `run.sh`, the sole exit-code contract,
    contrasted with **Function entry** (the asserting machine entry point
    versus the non-asserting human one) and stating plainly that the
    **Microworld dashboard** is a human-facing exploration surface and
    **never an acceptance criterion**: no hook registers it, no gate consults
    it, and no acceptance criterion in this or any future spec may name it.
    Suggested text:
    ```
    **The check**:
    (unit #323, 2026-08-11) — the prose noun for a **microworld bundle**'s
      `run.sh`: the sole, machine-facing, exit-code contract consumed by the
      `reviewer` (filesystem-presence check only, never executed) and the
      `microworld-rerun.sh` **Reporter** hook (0 = pass, non-zero =
      fail/timeout, logged to the **Microworld audit log**). Contrast with
      **Function entry**: the check is the one asserting entry point a bundle
      has, and the only thing any gate or hook may ever consult; a function
      entry is a non-asserting, human-invoked probe whose exit code carries no
      verdict (`POST /api/invoke` never inspects it). The **Microworld
      dashboard** renders function entries for human exploration but never
      runs or displays the check's own exit code as a verdict — the dashboard
      is a human-facing exploration surface and **never an acceptance
      criterion**: no hook registers it, no gate consults it, and no
      acceptance criterion in this or any future spec may name it. `run.sh`
      keeps its filename; only the prose noun "the check" is new (Open
      Question 5, 2026-08-10) — there was never a file rename.
    ```
  - **Function location** (new) — a function entry's optional `location`,
    contrasted with the **code-review graph** (an author-declared pointer
    versus a derived, auto-updating index) and noting the accepted staleness
    risk (R9). Suggested text:
    ```
    **Function location**:
    (unit #323, 2026-08-11) — a **function entry**'s optional `location`
      field in `manifest.json` (`{ file, startLine, endLine }`), naming where
      in the repo the code that function entry exercises actually lives.
      Author-declared by `lead-programmer` at bundle-authoring time; consumed
      by the dashboard's **Source excerpt** pane (`GET /api/source`) and
      copied verbatim into a **Feedback block**'s metadata lines, or the
      literal string `location: not declared` when the field is absent.
      Contrast with the **code-review graph** (`explorer`'s MCP-backed
      structural index, which auto-updates on every file change via hooks and
      a git pre-commit check): `location` is a static, hand-authored pointer
      with no such refresh mechanism. This is an accepted staleness risk (R9,
      `docs/plans/2026-08-10-microworld-dashboard.md`): a `location.file`/
      `startLine`/`endLine` can silently go stale the moment the code it
      points to moves, and nothing revalidates it automatically. Mitigation,
      not a fix: a copied feedback block carries the commit SHA at copy time,
      so a receiving agent can re-derive the real location instead of
      trusting a stale line range.
    ```
  - **Microworld dashboard** (amend existing entry, `CONTEXT.md:721`) — append
    the rerun-hook contrast decided above. Suggested addition, appended after
    the entry's existing "Distinct from... the other two are what it
    displays." sentence:
    ```
      Also distinct from the `microworld-rerun.sh` **Reporter** hook (see that
      entry and **Microworld audit log**): the dashboard is the standing,
      human-facing viewer a user starts and stops; the reporter is the
      synchronous, per-edit machine process that never renders anything a
      human sees, and never gates on the dashboard's behalf. (Naming note: a
      new headword "microworld rerun hook" was considered and rejected for
      this contrast — see this plan's D10 "Rerun-hook naming decision" — to
      avoid minting an avoidable synonym for the already-named reporter.)
    ```
- `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md`
  (new — **0019, the re-verified next-free number**; `ls docs/adr/` runs
  0001-0018 today with only the known, deliberate 0007 hole; do not backfill
  it and do not reuse 0017/0018, both already taken by unrelated ADRs): record
  that "microworld" was re-scoped from a fixture bundle to an interactive
  dashboard, that the machine-checkable check layer survives underneath
  unchanged, the alternatives rejected for the function contract and the UI
  shape, the decision that "notebook" is a UI framing rather than a kernel
  (and what would have to change if that is ever reversed), the Cell/Notebook
  terminology realization (see above — a decision record, not a re-litigation
  of #319), the retraction of "No daemon is introduced" and the fact that it
  miscited constitution P2, and the accepted costs (R1, R5, R7, R9).
- `.claude/wiki/architecture.md` — **currently zero occurrences of
  "dashboard"** (re-verified 2026-08-11: `grep -qi dashboard
  .claude/wiki/architecture.md` exits 1) — this half of D10 has not started.
  Add: the dashboard as the plugin's first long-running component, its
  loopback/token posture, the audit-log contract between a bash producer and
  a Node consumer, and the root-confined source read.
- `.claude/wiki/conventions.md` — **currently zero occurrences of
  "MICROWORLD_BUNDLE_DIR"** (re-verified 2026-08-11: `grep -q
  MICROWORLD_BUNDLE_DIR .claude/wiki/conventions.md` exits 1) — this half of
  D10 has not started either. Add: bundle format v2 (`functions[]`), the
  `entry` execution contract (argv array, one JSON object on stdin, no shell,
  `MICROWORLD_BUNDLE_DIR` set in the invoked process's environment), the
  `location` field, and the authoring policy (heavy-unit trigger reference,
  ADR-0004 as amended by ADR-0013).
- **Relationship to the 2026-07-28 plan's Step 8b (#138) — resolved, not
  hypothetical.** #138 landed (`gh138`, PASS 2026-08-11T18:26:51Z, commit
  `15c67d7`). Its **Microworld** entry already uses this plan's definition (the
  dashboard entry a human explores), confirmed live in the reconciliation
  ledger above. The sequencing hazard the original draft flagged ("if #138
  has not run, this step must author the neighbour it contrasts against") is
  moot — #138's terms exist and this step's contrasts (**Function entry**,
  **code-review graph**, the `microworld-rerun.sh` **Reporter**) all resolve
  against present text. No dependency ordering is needed for this revision.

**Affected files**
- `CONTEXT.md`
- `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md`
  (new)
- `.claude/wiki/architecture.md`
- `.claude/wiki/conventions.md`

**Acceptance criteria — verified against HEAD on 2026-08-11 (`spec-master` ran
every command below before publishing). C1-C7 and C9-C13 were each confirmed
RED (exit 1) today, so none is vacuous; C8 and C14 are stated exceptions,
each an explicit non-regression guard already green today that must stay
green — the same C9-as-regression-gate pattern
`docs/plans/2026-08-11-gh138-debug-spec-wiki-accuracy.md` Step 6 uses, applied
here to two guards instead of one. Anchored to specific new content, never to
a bare ADR number — see "Reconciliation ledger" above for why that specific
trap matters here.**

```sh
set -u; fail=0
p(){ if [ "$2" -eq 0 ]; then echo "$1 PASS"; else echo "$1 FAIL"; fail=1; fi; }

adr=docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md

# C1  new entry headword: The check
grep -q '\*\*The check\*\*' CONTEXT.md; p C1 $?
# C2  The check's entry contrasts with Function entry
grep -A 10 -i '\*\*The check\*\*' CONTEXT.md | grep -qi 'function entry'; p C2 $?
# C3  new entry headword: Function location
grep -q '\*\*Function location\*\*' CONTEXT.md; p C3 $?
# C4  Function location contrasts with the code-review graph
grep -A 10 -i '\*\*Function location\*\*' CONTEXT.md | grep -qi 'code.review graph'; p C4 $?
# C5  Function location states the staleness risk
grep -A 10 -i '\*\*Function location\*\*' CONTEXT.md | grep -qi 'stale'; p C5 $?
# C6  the sentinel phrase now lands in CONTEXT.md (it already exists in the
#     shared protocol; this is the first time it reaches the glossary)
grep -q 'never an acceptance criterion' CONTEXT.md; p C6 $?
# C7  ADR-0019 exists at the re-verified next-free number, content-anchored
#     filename (not a bare number a coincidental future ADR could satisfy)
test -f "$adr"; p C7 $?
# C8  non-regression guard (green today, must stay green): the 0007 hole
#     stays a hole — this is not new work, it is a standing invariant this
#     step must not break
test ! -e docs/adr/0007-*.md 2>/dev/null; p C8 $?
# C9  the retraction is recorded in the ADR, not only in a plan document
grep -q 'No daemon is introduced' "$adr" 2>/dev/null; p C9 $?
# C10 the ADR names what the retracted claim miscited
grep -qi 'miscited' "$adr" 2>/dev/null; p C10 $?
# C11 the ADR records the Cell/Notebook terminology realization (both nouns,
#     not just one — a single hit would allow an incomplete record)
grep -q 'Cell' "$adr" 2>/dev/null && grep -q 'Notebook' "$adr" 2>/dev/null; p C11 $?
# C12 wiki architecture.md documents the dashboard (currently absent)
grep -qi 'dashboard' .claude/wiki/architecture.md; p C12 $?
# C13 wiki conventions.md documents the env var contract (currently absent)
grep -q 'MICROWORLD_BUNDLE_DIR' .claude/wiki/conventions.md; p C13 $?

# C14 regression gate (constitution P5) — green today, must stay green
bash tests/validate.sh >/dev/null 2>&1; p C14 $?
exit $fail
```

Two notes on why these are shaped this way:
- **C2/C4/C5 use `grep -A 10` scoped to the headword line, not a bare
  full-file grep**, because "function entry", "code-review graph", and
  "stale" all already occur elsewhere in `CONTEXT.md` in unrelated entries —
  an unscoped grep would pass without the new entry containing the required
  contrast at all.
- **C7 names the ADR's full topic slug, not just `0019-*`**, and **C8/C9/C10/
  C11 all target that same named file**, so a future, unrelated ADR that
  happens to land at 0019 first cannot make these criteria pass by
  coincidence — the exact failure mode that made the original `0017-*.md`
  criterion silently point at the wrong (unrelated) ADR once 0017 was taken.

**ADR-0019 draft content**, for `scribe` to adapt (matching the prose shape of
ADR-0017/0018 — Context/Decision/Rationale/Consequences/Related decisions):

- **Title:** "ADR 0019: Microworld dashboard supersedes the fixture-only
  narrowing"
- **Status:** Accepted (plan `2026-08-10-microworld-dashboard`, Step D10;
  issue #323)
- **Context:** the 2026-07-28 plan deliberately narrowed "microworld" to a
  fixture bundle whose entire contract is `run.sh`'s exit code (a Papert-
  microworlds name applied to a much narrower thing); the user overrode that
  narrowing on 2026-08-10, restoring the primary sense to an interactive,
  human-explored dashboard while keeping the machine-checkable layer intact
  underneath as "the check". Cite the two-layer table from this plan's Goal
  section (human-facing/primary vs machine-facing/underlying).
- **Decision:**
  - Function contract is declarative and language-agnostic
    (`functions[]`/`entry`, one JSON object on stdin, argv-only, no shell) —
    rejected per-language runtime introspection (breaks R8, imports
    agent-written code into the dashboard's own process) and a single
    `explore.sh` whose stdout is parsed (fragile, no home for per-function
    inputs).
  - UI shape is a local `node:http` server plus a browser tab — rejected a
    true in-terminal TUI (cannot deliver the Clipboard API portably) and a
    TUI-over-JSON-core hybrid (doubles the UI surface for no capability
    gain).
  - "Notebook" is a UI/UX framing only, never a kernel: cells are independent
    fresh processes sharing no state, and the UI states this on screen. State
    what would have to change if this is ever reversed — a bundle-provided
    warm `session` process (an optional, additive manifest field), which
    would also require redefining guardrail 4 (bounded execution).
  - **Cell/Notebook terminology realization** (record verbatim, do not
    re-litigate #319's already-PASSed work): the user's original phrase
    "notebook cell" shipped as two distinct terms, **Cell** (one invocation
    record) and **Notebook** (the per-function ordered list of Cells) — a
    more precise outcome than the single original phrase, decided at unit
    #319 and recorded here as an architectural decision, not reopened.
- **Retraction:** "No daemon is introduced" (`docs/plans/2026-07-28-
  microworlds-ubiquitous-language-human-review.md`, its architectural-facts
  prose) is retracted. This plan introduces the plugin's first standing
  long-running process — the dashboard, `node bin/cli.js --dashboard` — a
  **foreground process the user starts and stops**, never a background
  daemon; state plainly that "no daemon" remains true in the narrow sense
  (nothing detaches or survives the terminal) but the original sentence's
  framing ("no daemon is introduced") is misleading given a long-running
  process now exists. Also record that the original citation **miscited
  constitution P2** ("prefer deterministic scripts over LLM re-derivation") —
  P2 has nothing to do with process lifecycle; the constraint actually in
  tension is G4 (zero runtime dependencies, this plan's own global
  constraint), which the dashboard satisfies by using only `node:http`,
  `node:crypto`, `fs.watch`, and `child_process`.
- **Accepted costs (R1, R5, R7, R9):** bundle-authorship unverifiability (no
  commit/clone/CI ever sees a gitignored bundle, so nothing can assert
  `functions[]`/`location` were actually authored); this repo being a poor
  dogfooding target for its own "class and its functions" framing (antislop
  is bash + a single-file Node CLI + markdown personas, with no classes);
  token-in-scrollback exposure (the per-launch token appears in terminal
  scrollback and the browser address bar, accepted as a per-launch,
  non-persisted secret on a loopback-only endpoint); and `location` line
  numbers going stale (R9, mitigated but not fixed by the commit-SHA-at-copy-
  time device, per the new **Function location** glossary entry).
- **Related decisions:** ADR-0004 (heavy-unit trigger, amended by ADR-0013),
  ADR-0017 (microworld bundles gitignored — the storage layer this ADR's
  dashboard renders), ADR-0018 (human-in-the-loop review default, the
  escalation-packet consumer this ADR's dashboard also reads).

## Relationship to the 2026-07-28 plan

`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md` is
**not** rewritten. Its 2026-08-09 round wrote an append-only contract into
itself, and this repo has a fresh precedent for superseding-by-new-document
(the 2026-08-09 `ubiquitous-language` spec superseding that plan's Step 1,
recorded in `CONTEXT.md`). Step numbering there is untouched.

What is **not** acceptable is leaving text standing that is now false. Four
surgical `**Superseded 2026-08-10**` pointers are written into that document,
changing no step and renumbering nothing:

1. Line ~88 — the Design-provenance table row describing ask #2 as
   "deliberately narrowed".
2. Lines ~93-102 — the paragraph "The narrowing of 'microworld', stated so it
   is not mistaken for a misreading."
3. Line ~252 — the architectural fact "**No daemon is introduced**
   (constitution P2)", which is both retracted and corrected: it miscited P2.
4. Lines ~1509-1517 — "What is NOT a gap" #1, which states the narrowing "is
   not being rewritten". It now is.

Its **Step 9 (F1, `explore.sh`) is superseded in full** and no pointer can
soften that; the pointer at (4) names it.

## Tracker dispositions

`spec-master` does not mutate the tracker; `task-master` owns issue slicing and
issue state (ADR-0003). The dispositions below are the specification of what
`task-master` should do, published here as the authoritative list. New units
are filed as one issue per step under the existing
`plan/2026-07-28-microworlds-human-review` label or a new
`plan/2026-08-10-microworld-dashboard` label at `task-master`'s discretion —
**no umbrella PRD issue**, per this repo's established per-step convention.

| Issue | Action | Reason |
|---|---|---|
| #122 (spec) | **Amend body** with a pointer to this document | Its Step 2 and Step 9 no longer describe what will be built |
| #129 Step 1 `ubiquitous-language` | **Close** | Already stale independently of this plan — superseded by #302-305, all CLOSED; `skills/ubiquitous-language/SKILL.md` ships today |
| #130 Step 2 bundle format | **Close, replaced by Step D1** | Format v2 plus `location` plus the terminology rename is a rewrite, not an amendment |
| #131 Step 3a `.gitignore` reach | **Amend dispatch note only** | Still valid and still required. Add: the dashboard writes nothing, so **no** new ignore line is needed for it — settled by Open Question 7's answer (a), not provisional |
| #132 Step 3b rerun hook | **Amend** | Logic unchanged. Add the header-comment note that the audit line is a consumed interface, and ensure the R4 contract test lands — here or in D3, but somewhere |
| #133 Step 4 verdict + packet | **Untouched in substance — one stale criterion must be corrected before dispatch** | The escalation machinery is unaffected by the re-scoping. But its criterion `grep -c '≥ ~8 impacted files' templates/persona-protocol.md` is 1 **cannot pass**: measured 2026-08-10, that string occurs zero times and no such protocol section exists. The trigger lives only in ADR-0004 (amended by ADR-0013). Replace with the reference-plus-non-duplication pair D1 uses, or the unit FAILs on a criterion no implementation can satisfy |
| #134 Step 5 stop-gate | **Untouched** | " |
| #135 Step 6 `humanReviewMode` | **Untouched** | " |
| #136 Step 7 routing | **Untouched** | " |
| #137 Step 8a README | **Amend** | Must also document the dashboard (D9 folds into it, or lands beside it) |
| #138 Step 8b glossary/ADR/wiki | **Landed, no further action** | PASSed 2026-08-11 (`gh138`, commit `15c67d7`). Its **Microworld** entry already uses this plan's definition, re-verified live 2026-08-11. **Reconciled 2026-08-11 (D10 revision 3, issue #323): D10 no longer adds eight entries and ADR-0017 — six of the eight terms and the ADR-number slot both landed under other units before D10 was reconciled. D10 now adds two entries (**The check**, **Function location**) plus an amendment to the shipped **Microworld dashboard** entry, and files ADR-0019 (0017/0018 taken by unrelated ADRs)** |
| #298 Step 9 `explore.sh` | **Close, superseded** | Subsumed by the dashboard; see Clarifications |
| #299 Step 10 `CHANGES.md` | **Untouched** | Explains *the change*; the dashboard shows *behaviour*. Genuinely complementary |
| #300 Step 11 `QUIZ.md` | **Untouched** | " |
| **#314 (D1)** | **Amend in place — do NOT re-slice** | Corrected 2026-08-10 (CHK28). The unit's deliverable, boundaries, and blast radius are unchanged; only its *description* was wrong. Four edits: (1) "rewrite in place" → **author fresh**; (2) header becomes `## Microworld bundles (format and the check contract)`, not `## Microworlds`; (3) `tests/adapter-protocol-parity.test.js` moves from "only if the header set changed — it must not" to **required, one entry in each of `codexMap` and `cursorMap`**; (4) the criterion `node tests/adapter-protocol-parity.test.js # exit 0 (no new top-level section)` is replaced — exit 0 now proves the new header **is** mapped in both ports, plus the mutation proof and the `grep -c … is 2` map-coverage check. Also add the slim-tier negative check. **Model tag:** this is not mechanical — it authors a canonical protocol section plus two hand-adapted ports; do not tag `haiku` |
| **#315 (D2)** | **Amend in place — do NOT re-slice** | Corrected 2026-08-10 (G6, CHK29). Replace the criterion `npm pack … and git diff --name-only does not include tests/validate.sh's npm-pack included list changing` with the two post-conditions now in D2: `npm pack --dry-run --json` lists a `bin/dashboard/` path, **and** `grep -Fq "included = ['agents/', 'hooks/', 'templates/', 'skills/']" tests/validate.sh` exits 0. Nothing else in the unit changes — same deliverable, same blast radius |
| **#322 (D9)** | **Amend in place — do NOT re-slice** | Corrected 2026-08-10 (G6, CHK29). Replace `git diff --name-only does not include tests/validate.sh for this step` with the same literal-value `grep -Fq …` assertion now in D9 |
| **#314 (D1)** | **No tracker action — already PASSed** | Its `git diff --name-only … .claude/persona-config.json` criterion carried the same defect; the reviewer hand-substituted a range-relative check and passed the unit. The plan text is corrected to the stamp-sync check for future readers and for any re-review, but the issue is closed and needs no amendment |
| — | **File 9 further new issues** | Steps D2-D10 |

## Open Questions

**All seven are RESOLVED** — the user chose the recommended default in every
case (Questions 1-5 and Questions 6-7, all on 2026-08-10). **Nothing in this
plan is outstanding**, and every default was already applied in the steps
above, so no step content changed when the answers arrived. Each question is
recorded rather than deleted, with the chosen answer restated up top and the
rejected options kept below, so the reasoning stays legible to `task-master`
and to a later reader.

1. **RESOLVED — How does a bundle declare "the class and its functions"?**
   (CHK3.) **Answer: (a), a declarative `functions[]` in `manifest.json`.**
   - **(a) CHOSEN** — language-agnostic, honours R8, and the dashboard never
     parses free-form output.
   - (b) Rejected — per-language runtime introspection. Closest to the user's
     literal description and near-zero authoring burden, but needs a
     per-language adapter set (breaking R8), imports agent-written code into
     the dashboard's own process, and cannot know sensible inputs.
   - (c) Rejected — convention inside one `explore.sh` whose stdout is parsed.
     Cheapest; a fragile contract, and per-function inputs have nowhere to live.
2. **RESOLVED — Terminal UI, or a local server plus a browser tab?** (CHK4.)
   **Answer: (a), a local HTTP server on `node:http`.**
   - **(a) CHOSEN** — zero new dependencies, the only shape yielding
     machine-checkable criteria (P1/P5), and — as revision 2 confirmed — the
     only shape in which the clipboard capability is achievable at all.
   - (b) Rejected — a true in-terminal TUI.
   - (c) Rejected — both, with a TUI client over a JSON core.
3. **RESOLVED — Who starts it and owns its lifecycle?** (CHK10.) **Answer:
   (a), the user starts it explicitly; nothing auto-starts it.**
   - **(a) CHOSEN** — a new CLI flag, foreground, Ctrl-C to stop. Asserted by
     D2's negative hook-integration criterion (G5).
   - (b) Rejected — auto-start from a `SessionStart` hook with a pidfile.
   - (c) Rejected — no standing process; render-and-exit.
4. **RESOLVED — Trust boundary for human-driven invocation of agent-written
   code.** (CHK9.) **Answer: (a), no sandbox, guardrails only.**
   - **(a) CHOSEN** — the seven guardrails above, each asserted by execution.
   - (b) Rejected — additionally a manifest-declared `sideEffects` field with a
     per-invocation confirm. Available later as a pure addition.
   - (c) Rejected — real per-invocation sandboxing.
5. **RESOLVED — What is each layer called?** (CHK8.) **Answer: (a), rename the
   layers around the dashboard**, including the sub-decision that the `run.sh`
   **filename** does not change, only the prose noun.
6. **RESOLVED 2026-08-10 — Does "like a Jupyter notebook" mean a persistent
   kernel, or cell-shaped UI over the existing fresh-process invocations?**
   (Originating check: CHK19.) **Answer: (a), UI and UX framing only** — the
   recommended default, confirmed by the user. No kernel and no warm session;
   cells remain independent fresh processes under D4's guardrails, and the UI
   states plainly that they share no state. No change to Step D6, whose cases
   (a) and (b) already prove the fresh-process contract by execution.
   Guardrail 4 (bounded execution) therefore stands unchanged.
   - **(a) CHOSEN — UI and UX framing only.** Cells, history, and
     edit-and-re-run in the browser; each cell is still a fresh process under
     D4's guardrails, and the UI states plainly that cells share no state.
     A real kernel needs a per-language adapter — the exact ground on which
     per-language introspection was rejected in Question 1 — and it breaks
     guardrail 4 (bounded execution, which is meaningless for a process that
     outlives the request) and the stateless-process property. Costs nothing
     later: `manifest.json` fields are optional by construction, so (b) remains
     a pure addition.
   - (b) Rejected — a **bundle-provided warm session**: `manifest.json` gains an optional
     `session` entry — a long-lived process speaking line-delimited JSON on
     stdin/stdout, so the *bundle* owns the language-specific kernel and the
     dashboard stays language-agnostic. Gives genuine cross-cell state. Costs:
     process lifecycle and orphan cleanup, per-tab isolation, and a redefinition
     of guardrail 4, which currently kills per invocation.
   - (c) Rejected — ship (a) now and revisit (b) once real bundles exist and it
     is known whether anyone actually wants shared state. Materially the same
     as (a) today; differs only in whether (b) is recorded as planned or as
     merely possible. The chosen answer (a) already leaves (b) available, so
     this option bought nothing.
7. **RESOLVED 2026-08-10 — Are comments ephemeral in the browser tab, or
   persisted to disk?** (Originating check: CHK20.) **Answer: (a), ephemeral
   and in-page only** — the recommended default, confirmed by the user. No new
   files, no new `.gitignore` line, and the pasted copy in the agent
   conversation is the durable record. No change to Step D7. Guardrail 5 (the
   dashboard writes no files at all) therefore stands unchanged, and #131's
   dispatch note does **not** invert.
   - **(a) CHOSEN — ephemeral, in-page.** The clipboard is the handoff and
     the durable copy lives in the agent conversation it is pasted into.
     Persisting reverses guardrail 5 ("the dashboard writes no files at all"),
     which was decided one round ago; it needs a location, a `.gitignore` line
     that #131 was explicitly told it would not need, and a lifecycle — and it
     inherits the same session-boundary fragility R10 of the 2026-07-28 plan
     already documents for packets.
   - (b) Rejected — persist to an append-only, gitignored `.claude/microworld-comments/`.
     A running record survives refresh and restart, and comments can be
     accumulated and copied in a batch. Costs: reverses guardrail 5, adds the
     ignore line, and adds a lifecycle question (when is a comment cleared?)
     that nothing currently answers.
   - (c) Rejected — ephemeral by default, with an explicit "Save to file" action the human
     triggers. Keeps the default clean and the write only ever happens on a
     deliberate gesture — but it still needs (b)'s location, ignore line, and
     lifecycle, so it is (b)'s cost with (a)'s default.

## Self-check

- CHK1: Is the dashboard's relationship to the check's machine-checkable
  contract stated for both existing consumers (`reviewer`, rerun hook)? — PASS
  (the layer table; D1's `never an acceptance criterion` sentinel, asserted in
  both the template and the regenerated reviewer copy; G5).
- CHK2: Do the two fixed premises and the Step 9 supersession call agree that
  no escalation-only human-facing artifact remains? — PASS (Clarifications; D8
  states the packet is a read location and not a coupling, and asserts the
  decoupling with zero-match greps for `humanReviewMode` and `escalated`).
- CHK3: Is the `entry` execution contract defined precisely enough to implement
  without guessing — cwd, environment, input channel, output channel,
  exit-code meaning? — FAIL (missing) — **revised in place.** The first draft
  named only "one JSON object on stdin". cwd, `MICROWORLD_BUNDLE_DIR`, and the
  explicit statement that the exit code carries no verdict were added to D1,
  each with a criterion.
- CHK4: Does every step name at least one command that can be run and produce a
  pass/fail? — PASS (every step's criteria are exit-code or `grep` assertions;
  the single exception, D5's manual navigation check, is explicitly labelled a
  note and not a gate).
- CHK5: Do D2 and D8 agree on how a working bundle and a packet for the same
  unit are distinguished? — FAIL (conflicting) — **revised in place.** An
  earlier draft keyed microworlds by bare unit slug, which would have made a
  packet silently shadow its own working bundle. D2 now specifies namespaced
  ids and D8 case (b) asserts the collision case by execution.
- CHK6: Is behaviour defined when a manifest is malformed, an `entry` is
  missing, or `functions[]` is absent entirely? — FAIL (missing) — **revised in
  place.** D1 states `functions` is optional; D2 states fail-soft with a
  `disabled` flag and a reason, asserted by case (e).
- CHK7: Is there a bound on what a single invocation can consume — time and
  output? — FAIL (missing) — **revised in place.** D4 specifies the
  `timeoutSeconds` kill and a 1 MiB per-stream cap with a `truncated` flag,
  asserted by cases (c) and (d).
- CHK8: Is "microworld" unambiguously defined across both layers, including
  whether the `run.sh` filename changes? — PASS (Terminology, with the filename
  sub-decision stated explicitly because a reader will expect a rename; eight
  contrasted glossary entries required by D10).
- CHK9: Is the trust boundary stated **and** backed by executable criteria
  rather than prose? — PASS (seven guardrails, each mapped to a D2, D4, or D7
  case, including the injection sentinel, the traversal `400`, and the pid
  check after timeout).
- CHK10: Is it stated who starts the process, and is "nothing auto-starts it"
  machine-checkable? — PASS (Question 3; D2's
  `grep -c dashboard hooks/hooks.json` is 0 criterion, encoded as G5).
- CHK11: Does the plan say how the two-language audit-log contract is kept from
  drifting? — PASS (R4; D3's contract test runs the real hook into the real
  parser and carries an explicit mutation-proof requirement, so a vacuous test
  is itself a failure of the step).
- CHK12: Do the affected-files lists distinguish generated files from
  hand-edited ones, so no step silently violates P2? — PASS (G2; D1 marks
  `.claude/agents/*.md` as regenerated by `--update` and flags the adapter
  ports as hand-adapted rather than byte-identical copies).
- CHK13: Is G1's version-bump coupling represented for every step? — PASS
  (stated once with the four literal paths, referenced by the note above the
  Steps section).
- CHK14: Does the plan state what happens when the dashboard runs with no
  bundles — the normal state of a fresh clone? — PASS (D2's empty state, with
  criterion (a) asserting `200` and `[]`).
- CHK15: Does the plan claim the dashboard changes anything about escalation,
  contradicting the second fixed premise? — PASS (D8 states the decoupling in
  prose and asserts it with two zero-match greps; nothing in D1-D7 reads any
  escalation state).
- CHK16: Is the supersession of the 2026-07-28 document specified precisely
  enough that a reader of the old document cannot be misled? — PASS
  ("Relationship to the 2026-07-28 plan" names four line ranges and states that
  Step 9 is superseded in full with no softening).
- CHK17: Does the plan state a per-issue disposition for all fourteen
  already-published issues? — PASS (Tracker dispositions, all fourteen plus the
  ten new units).
- CHK18: Is a packaging change needed, and is that claim verified rather than
  assumed? — PASS (Architectural facts establish `files` already ships `bin` and
  `validate.sh`'s npm-pack lists need no edit; D2 and D9 each assert it by
  running `npm pack --dry-run`).
- CHK19: Does the plan define whether "notebook" means a persistent kernel or a
  UI framing? — FAIL (ambiguous) — **converted to Open Question 6**, default
  (a) applied in D6, with the coupling to guardrail 4 named in the question so
  the user could see what a different answer costs. **Answered (a) by the user
  2026-08-10, confirming the applied default; now RESOLVED and D6 unchanged.**
- CHK20: Does the plan define where a human's comment lives, and for how long?
  — FAIL (missing) — **converted to Open Question 7**, default (a) applied in
  D7, with the coupling to guardrail 5 and to #131's ignore line named in the
  question. **Answered (a) by the user 2026-08-10, confirming the applied
  default; now RESOLVED, D7 unchanged, and #131's note does not invert.**
- CHK21: Do D1 and D7 agree on the exact spelling used when `location` is
  absent? — FAIL (conflicting) — **revised in place.** An earlier draft had D1
  silent on the absent case while D7 emitted `location: not declared`. D1 now
  states the string and greps for it, and D7 case (h) asserts the two artifacts
  produce the same one. Two independently-invented spellings would have made
  the block unparseable for the agent it exists to be pasted into.
- CHK22: Does rendering a source excerpt widen the dashboard's read surface,
  and is that guarded? — FAIL (missing) — **revised in place.** The first draft
  of D7 read `location.file` with no path check at all. Guardrail 6 was added
  to the security posture, R10 records the risk, and D7 case (c) proves the
  traversal `400` by execution.
- CHK23: Does the plan avoid introducing a term that collides with an existing
  shipped concept? — FAIL (conflicting) — **revised in place.** The draft
  called the clipboard artifact a "handoff packet"; `handoff` is a shipped
  skill and `.claude/wip-handoff.*` an existing artifact. Renamed to **feedback
  block**, with a zero-match `grep -ci handoff bin/dashboard/` criterion in D7
  and a required contrasting glossary entry in D10.
- CHK24: Is the one claim this environment cannot verify prevented from being
  load-bearing? — PASS (the Clipboard-API secure-context claim is labelled as
  unverifiable in Architectural facts, and D7 requires and asserts an
  `execCommand` fallback, so the feature works either way — P1).
- CHK25: Do D6's notebook framing and D1's fresh-process contract agree, and is
  the agreement observable to a user rather than only true? — PASS (D6 case (a)
  proves distinct PIDs and case (b) proves a non-incrementing counter; R11
  requires the on-screen sentence and D6 greps for it; D9 requires the same
  sentence in the README).
- CHK26: Does every clause of the Goal map to a step with a criterion? — PASS
  (Goal items 1-6 map to D2, D3, D4/D5, D6, D7, D8 respectively; the format
  clause maps to D1; documentation and glossary to D9 and D10).
- CHK27: Was every acceptance criterion in this plan that asserts something
  about the **current** tree actually executed against it, rather than
  inherited on trust? — FAIL (conflicting) — **revised in place.** All such
  criteria were run on 2026-08-10. Six hold (`package.json` declares no
  dependencies; `grep -c dashboard hooks/hooks.json` is 0;
  `grep -rl dashboard hooks/scripts/` is empty; no `docs/adr/0007-*`;
  `README.md` does have a `## Known limitations` heading at line 177, so D9's
  `awk` range criterion is satisfiable; `npm pack --dry-run` lists `bin/`).
  **One did not:** the heavy-unit-trigger grep, inherited verbatim from the
  2026-07-28 plan, returns 0 and can never return 1 because the string and the
  section it names do not exist anywhere in `templates/` or `agents/`. D1's
  criterion was replaced with a satisfiable reference-plus-non-duplication
  pair, the finding was recorded as an architectural fact, and #133's identical
  criterion was flagged in Tracker dispositions. Had this not been run, D1 and
  #133 would both have shipped a criterion no implementation could satisfy.

- CHK28: Does any step assume an artifact already exists that was specified by
  the 2026-07-28 plan but never built? — FAIL (conflicting) — **revised in
  place, three occurrences.** Caught by the orchestrator on 2026-08-10 during
  pre-dispatch verification of D1, then re-verified here from scratch. **D1**
  said "rewrite the canonical `## Microworlds` section in place — same `## `
  header, so no new parity-map entry"; that section has never existed at any
  commit, so D1 must author it and **must** add `codexMap`/`cursorMap` entries
  (R3), which its own affected-files list had marked conditional and its
  acceptance criterion had denied. **D9** said "the existing bundle
  documentation is updated"; `README.md` has zero microworld content. **D10**
  said #138's glossary entries "stand"; `CONTEXT.md` has none. All three are
  corrected, a general architectural fact now states that *nothing* from the
  2026-07-28 plan is on disk, and the D1↔#133 shared-file constraint that the
  correction exposed is recorded in the dependency section. The root cause is
  specific and worth naming: CHK27 verified criteria that assert things about
  the current tree, but **D1's false claim was in prose, not in a criterion**,
  so a criteria-only sweep could not have caught it — the prose said "rewrite"
  while the criteria correctly treated the sentinels as post-conditions, and
  the contradiction sat between them unexamined.

- CHK29: Is every acceptance criterion evaluable under the reviewer's own
  precondition that the tree is fully committed? — FAIL (ambiguous) — **revised
  in place, four occurrences, and the underlying rule added as G6.** Found by
  the D1 reviewer, who could not satisfy `git diff --name-only` includes
  `.claude/persona-config.json` because the marker rule requires
  `git diff --quiet HEAD` to exit 0 first, making the bare working-tree diff
  empty by construction; it hand-substituted a range-relative check and passed
  the unit rather than failing it on a technicality, then flagged the pattern.
  Swept all ten steps myself rather than trusting the report: exactly four
  occurrences, all now corrected — R2's general mitigation, D1's criterion
  (already passed, corrected for future readers only), and the negative-form
  criteria in D2 and D9. The five `git status --porcelain` before-and-after
  checks in D2/D4/D6/D7/D8 were examined and are **sound** — they measure a
  delta inside the review session rather than claiming what the unit committed,
  so they hold on a clean tree and amid unrelated untracked files alike. Both
  replacements were run and mutation-proved before being written in. The root
  cause is worth naming precisely, because it is not the same as CHK27 or
  CHK28: the criteria were individually runnable and individually true-shaped,
  but they were evaluated **at the wrong moment in the lifecycle** — authored
  against a mental model of the working tree mid-implementation, then executed
  after the commit that empties it. Neither a criteria-run sweep nor a
  prose-premise sweep catches that; only asking "when, exactly, does the
  reviewer run this?" does.

Thirteen items failed across the two revisions. The revision-1 four (CHK3, CHK5,
CHK6, CHK7) all failed for one underlying reason: the draft specified the
*shape* of the invocation contract without its *boundaries*. The revision-2
failures split cleanly — CHK19 and CHK20 are genuine user decisions and became
Open Questions 6 and 7; CHK21, CHK22, CHK23, and CHK27 were defects in the
draft (a spelling that existed on only one side of a contract, an unguarded new
read primitive, a name collision with a shipped skill, and an inherited
criterion that could not pass) and were revised in place. CHK28 was found
after the plan was already marked finalized, by the orchestrator verifying D1's
target file before dispatch — the correct catch at the correct moment, and the
reason a "finalized" spec is still worth checking against the tree one more
time at dispatch.

## Scribe update hint

**Reconciled 2026-08-11 (D10 revision 3, issue #323) — six of the eight
originally-listed `CONTEXT.md` entries and the ADR-number slot below are
stale; see Step D10's "Reconciliation ledger" for the live, re-verified
status of each term.** After Step D10 lands, `scribe` should:
- Add the **two** new `CONTEXT.md` entries from D10 (**The check**,
  **Function location**), each contrasted per D10's suggested text (**The
  check** vs **Function entry**; **Function location** vs the **code-review
  graph**, noting staleness), and append the rerun-hook contrast sentence to
  the already-shipped **Microworld dashboard** entry. Do **not** re-author
  **Microworld**, **Microworld bundle**, **Function entry**, **Feedback
  block**, or a standalone "notebook cell" entry — all already stand (the
  last as the shipped **Cell** + **Notebook** pair, unit #319), and
  re-authoring them risks a duplicate or drifted second copy.
- Write `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md`
  — **0019, the re-verified next-free number (0017 and 0018 are both already
  taken by unrelated ADRs), and do not backfill the 0007 hole**, which
  `CONTEXT.md` links. The retraction of "No daemon is introduced", the fact
  that it miscited P2, the notebook-is-not-a-kernel decision, and the
  Cell/Notebook terminology realization (a decision record, not a
  re-litigation of #319's already-PASSed work) all belong in this ADR,
  because those are the lines a future maintainer will find and try to
  re-apply or "strengthen".
- Update `.claude/wiki/architecture.md` with the plugin's first long-running
  component, the bash-producer/Node-consumer audit-log contract, and the
  root-confined source read; and `.claude/wiki/conventions.md` with bundle
  format v2, `location`, and the `entry` execution contract. Both files
  currently have zero mentions of "dashboard"/"MICROWORLD_BUNDLE_DIR"
  (re-verified 2026-08-11) — this half of D10 has not started.
- Record in `.claude/wiki/changelog.md` that "microworld" now means the
  dashboard entry and that the check layer survives underneath, with a
  pointer to ADR-0019 (not 0017) — the single most likely thing a downstream
  maintainer will need to look up after an update.
