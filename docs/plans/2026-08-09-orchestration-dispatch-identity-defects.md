# Four orchestration defects from the #302-#305 session: dispatch identity, teammate tool availability, silent report loss, reviewer re-tasking

Status: finalized spec, ready for `task-master` slicing.
Author: `spec-master`. Date: 2026-08-09.
Supersedes nothing. Does **not** re-open ADR-0016.

## Goal

Close, or explicitly rule out closing, four process defects observed while
implementing issues #302-#305. Each item below resolves to exactly one of:

- **repo-fixable defect** — a hook script, persona file, template or command
  file changes, with a machine-checkable criterion and (for behavioural
  changes) a mutation proof; or
- **harness limitation** — the behaviour is outside repo control, and the only
  available remedy is protocol prose plus, where possible, a mechanical
  fail-fast that converts a late, expensive failure into an early, cheap one.

The four items are not independent. Items 1, 3 and 4 share a single root
cause established empirically below, and the fix for one constrains the fix
for another. That coupling is the main finding of this spec and is stated
before the per-item steps.

## The root cause, established empirically

**Finding R1 (measured this session, 2026-08-09).** When an `Agent`-tool
dispatch supplies the optional `name:` parameter, every hook payload generated
by that subagent's own subsequent tool calls carries that **dispatch name**
verbatim in the top-level `agent_type` field. It does **not** carry the
persona type, and it carries no namespace prefix.

Measurement: this `spec-master` instance was dispatched as a teammate under the
name `spec-hookfix`. It ran, deliberately, a command the marker-directory gate
refuses, and read the identity back out of the gate's own refusal text:

    $ cat .claude/reviewed/__probe_nonexistent__ > /dev/null
    BLOCKED: 'spec-hookfix' may not write to .claude/reviewed/ via Bash - ...

`spec-hookfix` is the dispatch name. `spec-master` is the persona. The gate saw
the former. This is a direct read of the harness's own payload, not an
inference from behaviour.

**Finding R1b (measured this session, the complementary control).** An
**unnamed** dispatch reports the **bare persona name**. The same probe was run
inside an `explorer` dispatched with no `name:` parameter; the gate reported
`'explorer'` — not a namespaced `antislop:explorer`, and not a suffixed
variant. Two things follow, and together they are what make "dispatch unnamed"
a remedy rather than merely a preference:

- An unnamed reviewer dispatch produces `agent_type = reviewer`, which
  satisfies `persona_matches_grant` on its first, exact-string branch. The
  privileges are retained with no reliance on namespace resolution.
- **An unnamed spawn is not auto-suffixed on collision.** This probe was the
  *second* concurrently-live unnamed `explorer` in the session, and it still
  reported `explorer`, not `explorer-2`. The auto-suffix trap recorded from
  unit 238 — where a spawn *requesting* the bare name `reviewer` was silently
  renamed `reviewer-2` and blocked identically — is therefore a property of
  **explicitly named** spawns, not of unnamed ones.

Scope of the measurement, stated honestly: both probes were nested dispatches
issued by a teammate, and R1b was measured on `explorer`. That a top-level
unnamed dispatch from the main session behaves identically is a reasonable
inference from the same mechanism, not a direct measurement. Nothing in this
spec breaks if that inference is wrong — Step 1 fails open and Step 6's roster
check stands either way.

**Finding R2 (read from the code).** `persona_matches_grant` is deliberately
conservative (`hooks/scripts/lib/agent-identity.sh:92-105`): it matches on an
exact string, or on a bare persona name inside this plugin's own recognized
namespace. A dispatch name such as `rev-302` contains no colon, so
`identity_namespace` returns empty and the matcher fails closed. The asymmetry
is by design and documented in that file's header (`:6-16`) — over-matching at
a privilege-grant site would hand PASS-marker authority to a foreign namespace.

**Therefore: a reviewer dispatched with any `name:` other than the bare string
`reviewer` holds none of the reviewer's mechanical privileges.** Three distinct
consequences follow, only the first of which was in the briefing:

- **C1 — cannot write its own verdict marker.**
  `hooks/scripts/reviewed-path-gate.sh:287` runs
  `persona_matches_grant "$agent_type" reviewer`; on failure every write to the
  reviewer-owned marker directory is refused, on the `Write`/`Edit` path and
  the `Bash` path alike. The gate fires only at the marker write, i.e. at the
  very end, so a full opus-tier review is paid for and then discarded.
- **C2 — cannot clear the pending-review flag, and cannot consume the
  review-join stamp.** `hooks/scripts/stop-gate.sh:228` guards the entire
  reviewer `SubagentStop` branch with
  `[ "$(identity_persona_name "$agent_type")" = "reviewer" ]`. For
  `agent_type=rev-302` that resolves to `rev-302`, so the branch is not merely
  denied — it is never entered. The flags stay standing, the stamp is never
  consumed, and consequently the main session's turn-end stays blocked ("a
  completed unit is awaiting review") and `reviewer-route-gate.sh` keeps
  blocking the next gated dispatch. This consequence was **not** in the
  briefing and is the mechanism behind the "session trapped by the
  pending-review flag" described in item 4's incident.
- **C3 — agent-teams mode mandates the failing shape.**
  `commands/start-feature-team.md:9-10` instructs the team lead to "spawn
  **named** teammates ... spec-master/task-master/scribe/reviewer join if they
  exist", and `:40-43` then requires that same reviewer to write the marker.
  Taken together the command as written is satisfiable only when the reviewer
  teammate's name happens to be exactly `reviewer`. Any other name silently
  produces C1 and C2.

**Finding R3 (measured).** The failure is invisible in the audit log.
`identity_drift_log` records only two classes, `unparseable` and
`unrecognized-namespace` (`hooks/scripts/lib/agent-identity.sh:140-152`); a
custom bare name such as `rev-302` is neither. Measured on this repo's live
log: `grep -c identity-drift .claude/review-audit.log` returns **0**, in a
session that contains the failure. The only evidence today is the transient
block message inside the blocked agent's own transcript.

### What R1 does to the briefing's proposed item-4 rule

The briefing proposes, for item 4, a rule that the orchestrator should "never
dispatch a reviewer under the literal bare name `reviewer`", to avoid the
bare-name collision that misrouted a `SendMessage`. **That rule cannot be
adopted as stated.** By R1+R2, the bare string `reviewer` is the *only* name a
reviewer dispatch may carry and still retain its privileges; forbidding it in
agent-teams mode — where `start-feature-team.md` requires teammates to be named
— would forbid every working configuration. The addressable remedy for item 4
is therefore the second half of the briefing's proposal only (never re-task an
existing reviewer onto a different unit by message), plus a roster check before
spawning. This is spelled out in Step 6.

## Context

Verified facts this spec rests on, all measured at commit `877ef87`
(`master`, 2026-08-09). Re-measure if execution is deferred past further
commits.

- `hooks/hooks.json` registers exactly six events. `PreToolUse` has three
  matchers and no others: `Write|Edit` (`protected-paths.sh`,
  `reviewed-path-gate.sh`), `Agent` (`reviewer-route-gate.sh`,
  `dispatch-hygiene.sh`), `Bash` (`reviewed-path-gate.sh`). There is **no**
  matcher covering `SendMessage` today.
- `hooks/scripts/reviewer-route-gate.sh` is already the `PreToolUse (Agent)`
  hook and already reads `.tool_input.subagent_type` (`:31`) and
  `.tool_input.prompt` (`:68`). No hook in the repo reads `.tool_input.name`
  (verified: zero matches across `hooks/scripts/*.sh`).
- The `SubagentStop` payload carries `agent_type`, `agent_id` and `session_id`,
  and carries no unit id and no prompt — recorded at
  `docs/plans/2026-08-07-per-unit-review-join.md:71` and unchanged.
- `templates/persona-protocol.md`'s section
  `Agent-teams mode (only relevant if you were spawned as a teammate)` is a
  member of `UNIVERSAL_PROTOCOL_CORE` (`bin/cli.js:525-532`), so every
  full-tier persona carries it, and the same heading also exists in
  `templates/persona-protocol-slim.md:48`, so slim-tier personas carry it too.
- `bin/cli.js` asserts at load that `PROTOCOL_SECTIONS_BY_PERSONA` classifies
  **every** canonical `##` section of `templates/persona-protocol.md`
  (`:653-676`, `assertProtocolMatrixComplete`). Adding a NEW protocol section
  therefore forces an edit to every persona row or the CLI becomes unloadable.
  Adding a **bullet inside an existing section** forces nothing.
  `tests/adapter-protocol-parity.test.js` is likewise section-level, so a new
  bullet does not trip it either. This is why Step 4 adds bullets, not a
  section.
- `tests/validate.sh:130-162` enforces that any paragraph in
  `agents/orchestrator.md`, `agents/lead-programmer.md` or
  `commands/start-feature-team.md` mentioning `` `reviewer` `` (backticked)
  also contains one of the literal qualifiers `if present`, `this project`,
  `it exists`, `doesn't exist`, `does not exist`, `otherwise`, `if there's no`,
  `if there is no`, `if no `. Paragraphs are blank-line separated with wrapped
  lines joined. **Every new paragraph this spec adds to those three files must
  satisfy that checker**; this is a merge-gate constraint, not a style note.
- `agents/spec-master.md` and `agents/task-master.md` do **not** list
  `Write`/`Edit` in their `tools:` frontmatter; they receive those tools only
  through the `memory: project` auto-grant documented in the protocol's
  "A note on `memory`" section. `agents/lead-programmer.md` and
  `agents/scribe.md` list `Write, Edit` explicitly.
- Version-stamp discipline (constitution principle 3) applies: this spec edits
  `agents/*.md`, `templates/*.md` and `commands/*.md`, so
  `.claude-plugin/plugin.json` + `package.json` must be bumped and a CHANGELOG
  entry added. Current version `0.31.4`.

## Verdicts, one line each

| # | Item | Verdict | Remedy |
|---|------|---------|--------|
| 1 | Named reviewer dispatch defeats the grant matcher | **Confirmed defect, partly repo-fixable.** The `agent_type`-carries-the-name behaviour is a harness fact (R1) no hook can change. The repo's *response* is fixable: fail fast at dispatch time instead of failing at marker-write time, make the failure visible in the audit log, and correct the prose that currently mandates the broken shape. | Steps 1, 2, 3, 6 |
| 2 | `Write`/`Edit` unavailable to a named/teammate dispatch | **Confirmed harness limitation, and no repo-side code fix exists.** Measured on both grant paths (see OQ2): the tools are withheld from a named teammate whether they come from an explicit `tools:` entry or the `memory:` auto-grant. Protocol prose is the entire remedy. | Step 4 |
| 3 | Named dispatch loses its report unless it `SendMessage`s | **Confirmed; compliance gap, not a missing instruction.** Protocol already states the rule. Orchestrator-side routing guidance is missing. A mechanical backstop is *feasible* but recommended **deferred**, with the design recorded. | Step 5, plus a documented deferral |
| 4 | Global vs per-unit stop-gate scoping | **Not an unfixed code defect.** Already closed at `ddb8ac0` / ADR-0016; the gh-304 incident hit ADR-0016's own documented, accepted residual. The addressable remainder is orchestrator operator discipline, and half of the briefing's proposed rule is unsafe (see above). | Step 6 |

## Clarifications

Resolved during authoring; recorded so the implementer does not re-litigate them.

- **Q: Should `persona_matches_grant` be relaxed to accept custom dispatch
  names (e.g. a `rev-*` prefix)?**
  A: **No, and this is a hard boundary.** The matcher's conservatism is the
  documented design (`agent-identity.sh:6-16`): a grant-site miss fails closed,
  loud and recoverable, while an over-match hands PASS-marker authority to any
  agent that chooses a matching name. Loosening it would convert the
  Writer/Reviewer split from a mechanical property into a naming convention.
  No step in this spec edits `lib/agent-identity.sh`.
- **Q: Should the hook instead record a dispatch-name to persona binding at
  dispatch time (an alias file), so a named reviewer keeps its privileges?**
  A: **Rejected for this spec**, recorded so it is not rediscovered as novel.
  It is technically feasible — `reviewer-route-gate.sh` sees both the true
  persona (`tool_input.subagent_type`) and the name at spawn time, so it could
  write a binding the grant sites later consult. It is rejected because it
  moves a privilege decision out of the payload and into mutable on-disk state
  that nothing protects (the same `rm -f`-able surface ADR-0016 already flags
  as an "honest limit"), and because it would make the grant depend on a file
  written by an earlier, possibly foreign, dispatch. Fail-fast (Step 1) gets
  most of the benefit at none of that cost. If a future spec revisits this, it
  must treat the binding file as a privilege store and gate it accordingly.
- **Q: Does the fail-fast block of Step 1 break agent-teams mode, which
  requires named teammates?**
  A: No, because it blocks only names that are *not* the bare persona name.
  `name: "reviewer"` is permitted and is exactly what `start-feature-team.md`
  needs; `name: "rev-302"` is refused. Step 3 makes that requirement explicit
  in the command file rather than leaving it implicit.
- **Q: Can the block catch the auto-suffix trap (a second `reviewer` spawn
  silently becoming `reviewer-2`)?**
  A: **No.** The caller passes `reviewer`; any suffixing happens inside the
  harness after the hook has already seen the payload. This is a stated
  residual gap, mitigated only by the roster-check prose in Step 6.
- **Q: Is item 4's mechanism worth re-opening?**
  A: No. ADR-0016 accepted this residual deliberately, in writing
  (`docs/plans/2026-08-07-per-unit-review-join.md:508-515`), because the
  `SendMessage` payload carries no unit id. Nothing has changed to invalidate
  that tradeoff. This spec adds operator discipline around it and nothing else.

## Steps

Every step below states its own acceptance criteria. Per this repo's
convention, each criterion names a value that is measurably different from the
pre-change working tree, and every behavioural change carries a mutation proof
(run the new assertion against a build with the mechanism reverted; record both
outputs). A criterion that still passes with the mechanism removed does not
satisfy this spec.

### Step 1 — `reviewer-route-gate.sh` refuses a mis-named reviewer dispatch (fail fast)

Owner: `lead-programmer`.

**Affected files**

- `hooks/scripts/reviewer-route-gate.sh` — one new block.
- `tests/review-join.test.sh` — new fixtures in the existing suite.
- `adapters/codex/hooks/scripts/reviewer-route-gate.sh`,
  `adapters/cursor/hooks/scripts/reviewer-route-gate.sh` — ports.

**Behaviour**

Inside the existing `persona_matches_gate "$target_type" reviewer` branch
(`:67`), before the `Unit:` parsing, read `.tool_input.name`. If it is
non-empty AND `identity_persona_name` of it is not `reviewer`, block the
dispatch (exit 2) with a message that states: the dispatch would produce an
`agent_type` equal to the name; that name fails the grant matcher; the reviewer
would therefore be unable to write its verdict marker or clear the
pending-review flag; and the fix is to re-dispatch with no `name` at all, or —
in agent-teams mode, where a teammate must be named — with exactly `reviewer`.

Fail-open conditions, all deliberate and all required:

- `.tool_input.name` absent or empty (an unnamed dispatch, and also the case
  where the harness does not surface the field at all) — exit 0. This is what
  makes the change a strict no-op if OQ1 resolves negatively.
- `.tool_input.name` equal to the bare persona name `reviewer`, or to a
  recognized-namespace form resolving to it — exit 0.
- The payload not being a reviewer dispatch at all — unchanged, exit 0.

The block must be ordered **before** the review-join stamp write, so a refused
dispatch leaves no stamp behind.

**Acceptance criteria**

1. Baseline, run before the change:
   `grep -c 'tool_input.name' hooks/scripts/reviewer-route-gate.sh` is exactly
   `0`. After the change it is `>= 1`.
2. `bash tests/review-join.test.sh` exits 0, and its output contains all four
   of these new case names:
   - `route-gate-blocks-named-reviewer` — payload with
     `tool_input.name = "rev-302"` and `tool_input.subagent_type = "reviewer"`
     exits **2**, and no `.review-join.*` stamp file is created in the fixture
     project (`stamp_count` is `0`).
   - `route-gate-allows-bare-reviewer-name` — same payload with
     `tool_input.name = "reviewer"` exits **0** and DOES write the stamp for
     its `Unit:` line.
   - `route-gate-allows-unnamed-reviewer` — same payload with no `name` key at
     all exits **0** and writes the stamp.
   - `route-gate-named-non-reviewer-unaffected` — `subagent_type` of
     `lead-programmer` with `tool_input.name = "lp-302"` exits **0**.
3. Mutation proof, recorded verbatim in the unit's report: with the new block
   commented out, `bash tests/review-join.test.sh` **fails** and its output
   names `route-gate-blocks-named-reviewer`. With the block restored it
   passes. A test that passes in both states does not satisfy this step.
4. `bash tests/validate.sh` exits 0 and the working tree is clean of unintended
   changes: `git status --porcelain -uno` lists only the files named above.
5. Both adapter ports carry the same block: for each of
   `adapters/codex/hooks/scripts/reviewer-route-gate.sh` and
   `adapters/cursor/hooks/scripts/reviewer-route-gate.sh`,
   `grep -c 'tool_input.name'` (or that port's equivalent extraction
   expression, whichever the port uses for `tool_input` fields) is `>= 1`,
   where the pre-change value is `0` for both.

**Out of scope for this step:** any change to `lib/agent-identity.sh`, and any
attempt to make a mis-named reviewer *work*. This step only makes it fail early
and legibly.

### Step 2 — the two grant sites log a denial

Owner: `lead-programmer`.

**Affected files**

- `hooks/scripts/reviewed-path-gate.sh`
- `hooks/scripts/stop-gate.sh`
- `tests/reviewed-path-gate.test.sh` (assertions live inside this file, per its
  own header rule)
- adapter ports of both scripts

**Behaviour**

R3 established that this failure leaves no trace in `.claude/review-audit.log`.
Add one append-only record at each of the two sites where a reviewer privilege
is denied to an identity that resolves to neither `reviewer` nor a recognized
namespace form of it:

- in `reviewed-path-gate.sh`, on the path where `persona_matches_grant` fails
  and the call is about to be blocked;
- in `stop-gate.sh`, where a `SubagentStop` identity does **not** enter the
  reviewer branch but the session holds at least one standing pending-review
  flag — the state in which C2 actually bites.

Record shape: a single line, `<UTC ISO-8601> grant-denied hook=<hook>
identity=<sanitized>`, written with the existing `_identity_sanitize` encoder
so wire data cannot forge a second line. Reuse the existing degrade-on-failure
posture: a failed write must never abort the calling hook.

This is observability only. **No exit code changes in this step.**

**Acceptance criteria**

1. Baseline: `grep -c 'grant-denied' hooks/scripts/*.sh` is `0` before the
   change, `>= 2` after (at least one per script).
2. `bash tests/reviewed-path-gate.test.sh` exits 0 and its output contains a
   new case name `path-gate-logs-grant-denied` asserting that a blocked
   Bash payload with `agent_type = "rev-302"` produces exactly one line
   matching `grant-denied` in the fixture project's audit log, and that a
   payload with `agent_type = "reviewer"` produces **zero** such lines.
3. Mutation proof: with the new log line removed, that case fails; restored, it
   passes.
4. `bash tests/validate.sh` exits 0.
5. Exit-code non-regression, asserted explicitly: the full pre-existing case
   list of `tests/reviewed-path-gate.test.sh` still passes unchanged, and the
   count of `OK ` lines in its output is `>=` the pre-change count. No
   pre-existing case may be deleted or reworded to accommodate the new one.

### Step 3 — the prose that currently mandates the broken shape is corrected

Owner: `lead-programmer` (persona/command files are not `scribe`'s to own here;
they are source artifacts of the plugin, not institutional records).

**Affected files**

- `agents/orchestrator.md` — "Review routing — you are the single owner".
- `agents/reviewer.md` — the "if a stop-gate block demands a marker" bullet
  (`:151-165`).
- `commands/start-feature-team.md` — the named-teammate instruction (`:9-16`).

**Behaviour**

1. `agents/orchestrator.md` gains a dispatch-naming rule inside Review routing,
   stating that the reviewer, if present, is dispatched with **no** `name:`
   parameter in subagent-orchestrator mode, because a supplied name becomes the
   `agent_type` the grant matcher sees and costs the dispatch both its marker
   write and its flag clear; and that where a name is unavoidable (agent-teams
   mode) it must be exactly `reviewer`.
2. `agents/reviewer.md` extends its existing blocked-by-a-gate bullet with the
   mis-named case: if the marker write is refused and the refusal names an
   identity that is the dispatch's own name rather than this persona, the
   reviewer reports the block, the full verdict, **and the exact marker body it
   would have written**, so a correctly-dispatched replacement can confirm
   rather than re-derive a completed review.
3. `commands/start-feature-team.md` states that where a reviewer teammate
   exists it is spawned under exactly the name `reviewer` and no variant,
   since any other name silently costs it the marker write the same file
   already requires of it at `:40-43`.

**Wording constraint (merge gate, not style).** `tests/validate.sh:130-162`
rejects any paragraph in these files that mentions backticked `` `reviewer` ``
without one of its literal qualifiers. Each new or edited paragraph must
contain one of: `if present`, `this project`, `it exists`, `doesn't exist`,
`does not exist`, `otherwise`, `if there's no`, `if there is no`, `if no `.
Paragraph = blank-line separated, wrapped lines joined. Write the qualifier in
deliberately; do not discover this at merge time.

**Acceptance criteria**

1. `grep -c 'no `name:` parameter' agents/orchestrator.md` is `>= 1`; the
   pre-change value is `0`. (Any equivalent literal may be substituted, but the
   criterion must be re-stated in the unit's report with the literal actually
   used, and its pre-change count must be shown to be `0`.)
2. The same literal appears in the mirror after regeneration: running
   `node bin/cli.js --update` then `grep -c` of that literal in
   `.claude/agents/orchestrator.md` is `>= 1`.
3. `grep -c 'exact marker body' agents/reviewer.md` is `>= 1` (pre-change `0`),
   and `>= 1` in `.claude/agents/reviewer.md` after `--update`.
4. `grep -c 'exactly the name' commands/start-feature-team.md` is `>= 1`
   (pre-change `0`).
5. `bash tests/validate.sh` exits 0 — this is what proves the conditional-
   phrasing constraint was met. Mutation proof for the constraint: the unit
   records the output of `bash tests/validate.sh` run once with a qualifier
   deliberately removed from one new paragraph (must FAIL, naming the
   optional-persona check) and once with it restored (must pass).
6. `git status --porcelain -uno` after `node bin/cli.js --update` shows the
   `.claude/` mirrors as modified — i.e. propagation actually happened rather
   than being asserted. If a mirror is unchanged while its source changed, the
   step is not done.

### Step 4 — the teammate `Write`/`Edit` fallback moves from tribal memory into the shared protocol

Owner: `lead-programmer`.

**Affected files**

- `templates/persona-protocol.md` — bullets appended to the existing
  `## Agent-teams mode (only relevant if you were spawned as a teammate)`
  section.
- `templates/persona-protocol-slim.md` — the same, under its identically-named
  section (`:48`), since `scribe` is slim-tier and holds `Write`/`Edit`.

**Why bullets and not a new section.** `bin/cli.js:653-676` asserts at load
that every canonical `##` section is classified by every persona row of
`PROTOCOL_SECTIONS_BY_PERSONA`; a new section makes the CLI unloadable until
all rows are edited, and `tests/adapter-protocol-parity.test.js` would demand a
present-or-deferred decision in both adapter ports. A bullet inside an existing
universal section reaches every persona (that heading is in
`UNIVERSAL_PROTOCOL_CORE`, `bin/cli.js:529`) at zero table churn. This is a
deliberate design choice, not an omission.

**Content the bullets must carry**

- `Write` and `Edit` may be listed in your `tools:` frontmatter and still be
  rejected at call time in a teammate dispatch, with the runtime error
  `<tool> exists but is not enabled in this context`. Re-measured 2026-08-09.
- Do not retry, do not request permission, do not treat it as a defect to
  diagnose mid-task: fall back immediately to `Bash` — a quoted heredoc
  (`cat > file << 'EOF'`) for whole-file authoring, or a `python3` heredoc that
  asserts `old` occurs exactly once before replacing, for surgical edits.
- The fallback inherits the marker-directory gate's constraint: that gate
  matches on **command text**, so a heredoc whose body merely spells the
  reviewer-owned marker directory is refused regardless of where it writes.
  Author such a document with a placeholder token and substitute the real value
  from its canonical definition, so the invoking command text never spells the
  path. (This is the same move the gate's own refusal text recommends for
  `git commit -F <file>`.)
- This applies **regardless of how the tools were granted**. A persona that
  lists `Write, Edit` in its own `tools:` frontmatter loses them exactly as a
  persona that receives them through the `memory:` auto-grant does — measured
  on both paths, 2026-08-09. Do not read a persona's frontmatter as evidence
  that the call will succeed.

**Acceptance criteria**

1. `grep -c 'is not enabled in this context' templates/persona-protocol.md` is
   `>= 1`, pre-change `0`. Same for `templates/persona-protocol-slim.md`.
2. Section count is unchanged: `grep -c '^## ' templates/persona-protocol.md`
   equals its pre-change value exactly, which is **16**, measured 2026-08-09
   (proving a bullet was added, not a section).
3. `node bin/cli.js --update` completes with exit 0 — this is the real test of
   claim (2), since a new section would make the CLI throw at load.
4. After `--update`, the literal from criterion 1 appears in the inlined
   protocol block of at least the four personas that hold `Write`/`Edit`:
   `grep -c 'is not enabled in this context'` is `>= 1` in each of
   `.claude/agents/lead-programmer.md`, `.claude/agents/scribe.md`,
   `.claude/agents/spec-master.md`, `.claude/agents/task-master.md`.
5. `bash tests/validate.sh` exits 0 and `node tests/adapter-protocol-parity.test.js`
   exits 0.
6. Non-vacuity: the four `grep -c` values in criterion 4 are all `0` before the
   change. Record the before values.

### Step 5 — orchestrator routing gains "default unnamed", and the mechanical backstop is explicitly deferred

Owner: `lead-programmer`.

**Affected files**

- `agents/orchestrator.md` — "Delegation contract" and/or "Managing a
  long-running background dispatch".

**Behaviour**

The briefing's diagnosis is confirmed and is a compliance gap, not a missing
instruction: `templates/persona-protocol.md:53-60` already tells a teammate to
"report finished work by `SendMessage` to the name the lead spawned you under,
never turn-text". What is missing is on the **dispatcher's** side — nothing
tells the orchestrator that naming a dispatch changes how its result comes
back. Add a rule stating that:

- an `Agent` dispatch given no `name:`, issued from the **main session**,
  returns its full result to the dispatcher automatically on completion;
- a **named** dispatch does not — completion surfaces only as a content-free
  idle notification, and the report exists only if the subagent itself called
  `SendMessage`;
- the auto-notification is **not** a property to rely on from inside a
  dispatched persona. Measured while authoring this spec: three unnamed
  subagents dispatched by a teammate all completed without notifying their
  dispatcher, each returning "had no active task" when later resumed. A
  persona that spawns its own subagent must therefore collect the result
  explicitly rather than waiting to be told, which is the same conclusion the
  shared protocol's "there is no self-wake" section already reaches for
  background `Bash`;
- therefore name a dispatch only when genuine mid-flight addressability is
  needed (a long-running teammate you must query or re-task), and leave it
  unnamed otherwise;
- when you do name one, say so in the dispatch prompt and require the
  `SendMessage` report explicitly, rather than relying on the persona
  remembering;
- a named dispatch that ends with no report is recovered by `SendMessage`-ing
  it by name, never by re-`Agent`-ing that name (which spawns an unrelated
  sibling) — this is already stated at `agents/orchestrator.md:443-447` and
  must not be duplicated, only cross-referenced.

**Interaction to preserve, not overwrite.** `agents/orchestrator.md:434-437`
currently *requires* naming a nested dispatch in the 2-FAIL-cap / debug-spec
path, precisely to make the grandchild addressable. That requirement stays.
The new rule must be phrased as a default with that case named as the standing
exception, or the two paragraphs contradict each other. An implementer who
deletes `:434-437` has failed this step.

**Deferred: the mechanical backstop.** The briefing asks whether a hook could
detect a named agent's `SubagentStop` with no prior `SendMessage`. Findings:

- `hooks/hooks.json` today registers `PreToolUse` matchers for `Write|Edit`,
  `Agent` and `Bash` only. There is no `SendMessage` matcher, and no hook in
  this repo has ever observed that tool.
- The `SubagentStop` payload carries `agent_type` and `agent_id`, so a hook
  *could* distinguish a named dispatch from an unnamed one: by R1, `agent_type`
  for a named dispatch is a string that resolves to no persona in
  `personaSelection`, while for an unnamed one it resolves to a known persona.
- A backstop would therefore need: a new `PreToolUse` matcher on `SendMessage`
  writing a per-identity "reported" marker, plus a new `stop-gate.sh` branch
  that warns when a non-persona `agent_type` stops with no such marker.

**Recommendation: defer, and record the deferral.** Two reasons, both concrete.
First, the premise is unverified — that a `PreToolUse` matcher fires on
`SendMessage` at all is an assumption about the harness, and this spec has
already found one place where an assumption about harness identity was wrong.
Second, the failure mode it guards is fully removed at the source by the
"default unnamed" rule above for every dispatch that does not need a name, and
for the few that do, the dispatch prompt now carries the explicit requirement.
Building a new cross-hook state file and a new matcher to catch a residue of a
residue is disproportionate. If the practice recurs after this spec lands, the
design above is the starting point and OQ3 is the gating measurement.

**Acceptance criteria**

1. `grep -c 'unnamed' agents/orchestrator.md` is `>= 2` after the change;
   pre-change value is exactly `1` (a single occurrence at `:430`). Record
   both.
2. `agents/orchestrator.md:434-437`'s requirement survives verbatim:
   `grep -c 'assign that nested call an explicit' agents/orchestrator.md` is
   exactly `1`, unchanged from pre-change. A step that drops to `0` has
   overwritten the standing exception and fails.
3. After `node bin/cli.js --update`, criterion 1's literal count in
   `.claude/agents/orchestrator.md` is `>= 2`.
4. `bash tests/validate.sh` exits 0, including the optional-persona
   conditional-phrasing check on any new paragraph mentioning
   `` `reviewer` ``.
5. No hook script and no `hooks.json` file is modified by this step:
   `git status --porcelain -uno -- hooks/` is empty. The deferral is real, and
   this criterion is what proves it was honoured.

### Step 6 — orchestrator operator discipline for reviewer re-tasking (item 4's whole remedy)

Owner: `lead-programmer`.

**Affected files**

- `agents/orchestrator.md` — "Review routing — you are the single owner".

**Behaviour**

ADR-0016's residual is real and stays. Two rules close its practical incidence:

1. **Never re-task an existing reviewer onto a different unit by message.**
   Only a fresh `Agent` dispatch whose first non-blank line is `Unit: <id>`
   writes the per-unit review-join stamp; a `SendMessage` carries no unit id
   and cannot. Resuming a reviewer by message is correct for exactly one
   purpose — continuing the unit it was already dispatched for (for example the
   `INSUFFICIENT-CONTEXT` resume already documented at `:149-165`) — and is
   wrong for every other. A second unit gets a second dispatch.
2. **Check the roster before dispatching.** If an addressable agent already
   holds the reviewer's name, a bare-name `SendMessage` resolves to the most
   recent holder of that name, which may be a stale session from an unrelated
   plan. Confirm which unit the addressee was dispatched for before sending;
   if it is not the unit at hand, dispatch fresh instead.

State plainly why, so the rule survives contact with a hurry: this is exactly
what produced the gh-304 dual-marker incident, where a bare-name message
reached an idle session from an earlier plan, which then performed a genuine
review and wrote a real, conflicting verdict.

**Explicitly NOT adopted:** the briefing's proposed "never dispatch a reviewer
under the literal bare name `reviewer`". Finding R1/R2 shows that name is the
only one that preserves the reviewer's privileges, so the rule as proposed would
forbid the only working agent-teams configuration. Step 3 requires that name;
this step governs how it is *addressed* afterwards.

**Acceptance criteria**

1. `grep -c 'review-join stamp' agents/orchestrator.md` is `>= 1` after the
   change (pre-change value is `1`, at `:118`) — so this criterion alone is
   insufficient and must be paired with 2.
2. A literal naming the new rule appears where it did not before:
   `grep -c 'different unit' agents/orchestrator.md` is `>= 1`, pre-change `0`.
3. `grep -c 'gh-304' agents/orchestrator.md` is `>= 1`, pre-change `0` — the
   incident is named, not abstracted away.
4. After `node bin/cli.js --update`, criteria 2 and 3 hold in
   `.claude/agents/orchestrator.md`.
5. `bash tests/validate.sh` exits 0.
6. No hook script is modified: `git status --porcelain -uno -- hooks/` is empty
   for this step. Item 4 is prose-only by ruling, and this proves it.

### Step 7 — glossary correction (`scribe`-owned)

Owner: `scribe`.

`CONTEXT.md`'s **Agent identity** entry currently defines `agent_type` as "the
possibly-namespaced wire form of a persona name". Finding R1 shows that is
false for a named dispatch, where the field carries a dispatch name that is not
a persona name at all. Left uncorrected, the glossary actively teaches the
misconception this spec exists to fix.

Amend that entry to state both forms the field can take and which one the grant
matcher requires, and add an `_Avoid_` line if a near-synonym is introduced,
per `CONTEXT-FORMAT.md`.

**Acceptance criteria**

1. `grep -c 'dispatch name' CONTEXT.md` is `>= 1`, pre-change `0`.
2. The existing **Agent identity** entry is amended, not duplicated:
   `grep -c '^\*\*Agent identity\*\*' CONTEXT.md` is exactly `1`, unchanged.
3. `bash tests/validate.sh` exits 0.

### Step 8 — version stamp and CHANGELOG

Owner: `lead-programmer` (last unit, after every other step has PASSed).

Constitution principle 3 (MUST): this spec edits version-stamped files, so
`.claude-plugin/plugin.json` and `package.json` are bumped together and a
CHANGELOG entry is added covering all executed steps, and recording that item 2
resolved to a documentation-only mitigation because no repo-side code fix
exists for it.

**Acceptance criteria**

1. `.claude-plugin/plugin.json` and `package.json` carry the same new version,
   strictly greater than `0.31.4`:
   `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b&&a!=='0.31.4'?0:1)"`
   exits 0.
2. `grep -c '^## \[' CHANGELOG.md` is exactly one greater than its pre-change
   value, which is **69**, measured 2026-08-09.
3. The new CHANGELOG entry names all four items: `grep -c 'orchestration'
   CHANGELOG.md` is `>= 1`, where the pre-change value is **0**, measured
   2026-08-09; and the new entry's body mentions each of `dispatch identity`,
   `Write`, `SendMessage` and `ADR-0016` at least once (one `grep -c` per
   literal, each `>= 1` within the new entry).
4. `bash tests/validate.sh` exits 0.

## Open Questions

Each carries a recommended default. Answering "all recommended defaults" is a
complete answer. Only OQ2 changes the work in a way the implementer must know
before starting.

**OQ1 — Does the `PreToolUse (Agent)` payload actually carry
`tool_input.name`?**
Not verified. No hook in this repo reads that field today, so the repo itself
cannot answer it, and the author's tool access does not permit naming a
dispatch (a teammate cannot spawn a teammate: the harness returns "Teammates
cannot spawn other teammates — the team roster is flat", so the experiment is
unavailable from here).

*Recommendation: proceed with Step 1 as written regardless, and measure after
it lands.* Step 1 is designed to fail open on an absent field, so if the answer
is "no" the block is a documented no-op rather than a regression, and the
fixture tests still pass because they supply the field directly. The live
measurement is cheap and is the orchestrator's to run once Step 1 is merged:
dispatch the reviewer, if this project has one, with
`name: "probe-named-reviewer"` and a throwaway prompt. A refusal carrying
Step 1's new message proves the field is present; a dispatch that proceeds
normally proves it is absent, and that result should be appended to the plan
document as a documented residual rather than triggering a redesign.

**OQ2 — Are `Write`/`Edit` unavailable to *every* named teammate, or only to
personas that receive them via the `memory:` auto-grant? — ANSWERED: every
named teammate. Both grant paths fail.**
Measured on both sides, 2026-08-09:

- `spec-master`, which does **not** list them in `tools:` and receives them via
  the `memory: project` auto-grant, lost `Write` in a teammate dispatch.
- `scribe`, which **does** list `Write, Edit` explicitly in its own `tools:`
  frontmatter, lost **both**, with byte-identical errors:
  `No such tool available: Write. Write exists but is not enabled in this
  context.` and the same for `Edit`.

The grant path is therefore irrelevant, which retires the hypothesis this OQ
was raised to test. **Consequence: the conditional Step 4b is dropped from this
spec entirely** — there is no frontmatter change that would fix
`spec-master`/`task-master`, because the mechanism is not frontmatter. Step 4's
protocol bullets are the whole remedy, and item 2 is a documentation-only
outcome by measurement rather than by concession.

*Recommendation: no action required; this OQ is closed.*

A note on how that answer arrived, because it is itself evidence for item 3:
the probe dispatched to measure it completed its work and then went idle three
times without ever calling `SendMessage`, and its findings had to be recovered
by reading its raw transcript with `agent-auditor`. The failure mode this spec
documents in item 3 occurred, unprompted, inside the investigation of item 2.
Step 5's "default unnamed" rule is aimed squarely at that.

**OQ3 — Can a `PreToolUse` hook match the `SendMessage` tool?**
Unverified, and only relevant if the Step 5 deferral is ever revisited. No
measurement is proposed now.

*Recommendation: leave unanswered.* Measuring it costs a live hook edit, and
nothing in this spec depends on the answer.

**OQ4 — What `agent_type` does an *unnamed* dispatch report, and does a name
collision auto-suffix an unnamed spawn? — ANSWERED, see Finding R1b.**
Measured after this spec was first drafted: an unnamed dispatch reports the
bare persona name (`explorer`), and a second concurrently-live unnamed spawn of
the same persona was **not** suffixed. So "dispatch unnamed" retains the grant
and does not decay into the unit-238 auto-suffix trap.

*Recommendation: no action required; this OQ is closed.* The one unmeasured
edge is whether a top-level dispatch from the main session behaves like the
nested one measured here. Step 6's roster check is retained as a cheap belt to
that brace rather than being removed on the strength of one measurement.

## Residual gaps (state them, do not paper over them)

- **The auto-suffix case is not caught by Step 1.** Where a name *is* supplied
  — which agent-teams mode requires — the caller passes `reviewer` and any
  suffixing happens inside the harness after the hook has already seen the
  payload, so no hook can detect it. Mitigated only by Step 6's roster check.
  Per Finding R1b this does not affect unnamed dispatches, which is a further
  reason to prefer them wherever a name is not required.
- **ADR-0016's documented residual stands unchanged.** A reviewer re-tasked
  onto a second unit by `SendMessage` alone still produces no stamp and still
  fails open at its stop. This spec reduces the practical incidence via prose;
  it does not close the mechanism, and nothing here should be read as claiming
  otherwise.
- **Step 2 is observability, not enforcement.** A `grant-denied` record makes
  the failure findable after the fact. It does not prevent it, and it does not
  fire for a reviewer whose stop simply never enters the branch unless a
  pending-review flag is standing at that moment.
- **Item 3 has no mechanical backstop after this spec.** A named dispatch that
  ends its turn without `SendMessage` still loses its report silently. The
  remedy is prose and the "default unnamed" rule, by explicit ruling in Step 5.
- **None of this is tamper-proof**, exactly as ADR-0016 already says of the
  flags and stamps. The audit log is the deterrent.

## Self-check

- Does every step carry a criterion that would fail if the step were not done?
  Yes — every criterion names a pre-change baseline value (`0`, or a recorded
  count) that the change must move, and the three behavioural steps (1, 2, 3)
  additionally require a mutation proof.
- Is any criterion vacuous? The known local failure mode is a criterion whose
  exit code is discarded by a pipe. No criterion here uses the
  `! <cmd> | grep -qE` form; the `grep -c` criteria are compared against a
  recorded baseline rather than asserted to be merely non-zero, and the
  script-effect criteria use the two-assertion form (exit code plus
  `git status --porcelain -uno`).
- Is any criterion self-referential (the artifact under test being this plan)?
  No. Every criterion names a file this plan changes, never this plan.
- Does the spec force a code change where none exists? No. Item 4 is ruled
  prose-only and carries a criterion (`git status --porcelain -uno -- hooks/`
  empty) that *proves* no hook was touched. Item 3's mechanical option is
  explicitly deferred with the same proof.
- Does it re-open ADR-0016? No, by ruling, and Step 6's criteria are
  prose-only.
- Terminology: uses this repo's glossary terms (**Gate**, **Agent identity**,
  **review-join stamp**, pending-review flag, **Mutation-proved**) as defined
  in `CONTEXT.md`, and Step 7 corrects the one glossary entry this spec proves
  wrong rather than silently diverging from it.

## Scribe update hint

After the units land: `CONTEXT.md` **Agent identity** (Step 7, owned there),
plus a new glossary entry for the dispatch-name-versus-persona distinction if
Step 7's amendment does not already carry it; `.claude/wiki/modules/hooks.md`
for the new route-gate block and the `grant-denied` record. No ADR is required
— this spec introduces no new architectural decision, and the one decision it
*declines* (the alias-binding design) is recorded in Clarifications above,
which is the right weight for a rejected option.

## Handoff

Ready for `task-master`. Suggested slicing: Steps 1 and 2 are one unit each
(both are hook + test + adapter ports, opus-tier review warranted); Step 3,
Step 4, Step 5 and Step 6 are prose units that all edit
`agents/orchestrator.md` and therefore **must not run concurrently** — slice
them as a single sequenced chain or as one unit, or they will conflict on that
file; Step 7 is `scribe`-owned; Step 8 is last and depends on every other unit
having PASSed. All Open Questions that gate the work are now answered, so the
spec can be sliced in full — nothing is left conditional.
