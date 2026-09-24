# A human-confirmation branch for `harness-integrity-gate.sh`'s Set A and Set B

**Status:** FINAL — dispatch-ready, no open questions.
OQ1–OQ4 are **resolved** (operator, 2026-09-23) and every step below now reflects
the answer given, not the recommendation. OQ4 was answered **against** the
recommended default — Set B is **in scope** — and the design was reworked
accordingly rather than cloned. **OQ5**, raised by that rework, was resolved the
same day (operator: (a) — the gate's mirror becomes Set B's fourth literal).
No open questions remain. Steps 1–7 are complete and dispatchable.

**Amended 2026-09-23 (targeted, Step 4 only).** `task-master` reported a
mid-flight gap while slicing: C4.1's sweep returns hits that neither of its two
escapes admitted. Re-running the sweep found **three** such hits (the report
named two). Closed by a four-category classification with a both-directions
closure assertion — see *Sweep closure* under Step 4, new row 13, rewritten
C4.1, new C4.9, new R13, CHK21–CHK23. **Nothing outside Step 4 is changed**;
Steps 1–3 and 5–7 are byte-unchanged and remain dispatchable as already
sliced. One ruling inside the fix (`CHANGELOG.md` is exempt rather than
annotated) is self-resolved against ratified ADR-0029 and is reversible by a
one-row change — see the Clarifications line dated 2026-09-23 under *Technical
constraints & tradeoffs*.

**Amended 2026-09-24 (targeted, Step 3's C3.3 only).** The `hcb-regcheck`
implementer reported a mid-flight tension while building C3.3: C3.3 demanded
that all four mutation controls kill **pairwise disjoint** case sets, but
C1.3(a)'s stated scope (*all* of Set B's 6 deny rows) necessarily contains
C1.3(b)'s stated scope (*exactly* the Set B `acceptEdits` row), so the two can
never be disjoint by the plan's own definitions. **Ruling: C3.3 was wrong,
C1.3(a) and C1.3(b) were right.** The containment is not a flaw to be excepted
— it is the load-bearing evidence that the tier boundary lives *inside* the
frozen `case` and nowhere else, and asserting it positively is strictly stronger
than the blanket disjointness it replaces. Closed by a frozen **kill-set
relation table** over an explicitly-declared cell space — see the rewritten
C3.3, new R14, CHK25–CHK27, and the three Clarifications lines dated 2026-09-24.
**Nothing outside C3.3 is changed**: C1.3(a), C1.3(b), C1.4 and C2.2 keep their
existing wording, `.claude/reviewed/hcb-branch.pass` stands unamended (see R14
for why the narrowing commit `d598603` is a *correction toward* C1.3(a)'s
wording, not a redefinition of it), and Steps 1, 2 and 4–7 are byte-unchanged.

**Amended 2026-09-24 (second targeted amendment; Step 4's C4.2 only).** The
`hcb-prose-gate` implementer reported that C4.2's acceptance-criterion snippet is
**unsatisfiable**, made zero edits, and escalated rather than improvising.
C4.2's *prose intent* was always right — the **deny message** must stop claiming
"may not be written directly by any agent identity, ever" and stop saying "no
exemption" — but the snippet mistranslated it into a **file-wide substring**
count for `ever`, which three other mandatory requirements of this same step each
independently guarantee a hit for (C4.3c's frozen ADR-0025 paragraph, C4.3b's
required "never emits `ask` from a subagent", Do-NOT-touch's `reason_b`).
**Ruling: the prose was right, the mechanism was wrong** — and two further
defects were found while verifying the remedy, so the fix is not a bare scope
narrowing: (i) whole-word narrowing alone is *also* wrong, because `:6` carries a
still-true whole-word "ever" of exactly the lens-2 kind `:8-9` keeps; (ii) C4.2's
second half was **vacuous** — its file-wide `grep -qF 'bin/cli.js'` is already
satisfied by the two frozen `reason_a`/`reason_b` literals, so it passed even for
a deleted message, the one failure its own prose claimed to prevent. Closed by a
four-part C4.2 scoped to `deny()`'s body, with non-vacuity guards asserted first
and one fixed-phrase file-wide arm retained so the absolute cannot be relocated
instead of retired — see the rewritten C4.2, new R15, CHK28–CHK30, and the three
Clarifications lines dated 2026-09-24 (second amendment). **Nothing outside C4.2
is changed**: C4.1, C4.3, C4.3b, C4.3c, C4.4–C4.9 keep their wording verbatim,
Steps 1–3 and 5–7 are byte-unchanged, and no marker is amended. The remedy was
mutation-verified against seven mutants before being written down.

**Authoring commit:** `d807630` (2026-09-23); revised at the same tree. Every
baseline below was measured there. Baselines expire — re-derive with the probe
commands quoted inline rather than trusting the recorded numbers. The first
2026-09-24 amendment above was authored at `d598603`; the second at `094a17e`,
where the gate script's blob is identical to `8f85ce1`'s
(`bbc17e78cdfe3fd84885b32d32c4a0c2b55d28de`) — only `CONTEXT.md` and
`tests/harness-integrity-gate.test.sh` moved between them.

---

## Goal

Replace `harness-integrity-gate.sh`'s unconditional hard deny of `Write`/`Edit`
on **the harness's persona-selection config (Set A) and the gate's own
registration surface (Set B)** with a **human-confirmation branch**: in a
session where Claude Code can actually render a permission prompt, the gate
emits `permissionDecision: "ask"` instead of exiting 2, so the human — not the
agent — decides. In every other session shape it keeps today's exit-2 deny,
unchanged.

Set A and Set B share the mechanism but **not** the conditions. Set B is the
gate's own registration surface, where a single approval can remove every future
prompt, so it carries a narrower mode allowlist, its own fixed prompt wording,
and a new mechanical check that the gate is still registered — see *Set B is not
a mechanical clone of Set A*.

The four audit logs, their `.seal` sidecars, and the entire `Bash` branch keep
today's unconditional deny. Nothing else about the gate changes.

**The scope rule, stated once so it is not re-derived per path.** A path enters
the human-confirmation branch if and only if **a legitimate agent-authored write
to it exists**. The persona-selection config has one (`install-antislop` § 6).
Set B has one (every maintenance unit on this gate, including the unit that will
implement this spec). The four audit logs and their `.seal` sidecars have
**none** — their content is produced by hook code via `audit_append` and rotated
by `bin/harness-integrity.sh --rotate` — so a prompt over them would authorize
nothing and would only weaken the tamper-evidence trail. That single rule
decides all three cases; it is not three separate judgment calls.

---

## Context

### The trigger, and what it actually is

An ADAPT/setup session was observed hard-blocked trying to `Write` the
persona-selection config. The operator's reaction — *"let's not hard block that,
have it be a user question prompt"* — was read as an ergonomics complaint. It is
narrower and worse than that: **the gate blocks the plugin's own documented
fresh-install path, and there is no sanctioned route that completes it.**

Measured at `d807630`:

- `bin/cli.js`'s scaffold writes a **skeleton** config — `testAndLintCommand: ''`,
  `lintCommand: ''`, `sourceGlobs: []`, `protectedPaths: []`, `issueTracker: ''`
  (`bin/cli.js:2447-2462`) — and its own console line says so verbatim:
  `"written (skeleton — fields blank until /install-antislop fills them in from a
  real repo scan)"` (`bin/cli.js:2465`).
- `skills/install-antislop/SKILL.md` § 6 is the step that fills them in, and it
  is explicitly the *judgment* half: *"Copy `templates/persona-config.schema.json`'s
  shape and fill in from an actual scan of this repo … don't guess"*, plus a
  MERGE requirement (*"do not overwrite the file wholesale"*). No CLI flag
  performs this.
- The gate denies that write on **both** branches: `Write`/`Edit` by exact path
  match (`harness-integrity-gate.sh:82-85`), and any `Bash` spelling of the path
  — heredoc, `jq … > file`, `printf` — by the Set A text scan
  (`:102-174`, `:193-201`).
- `node bin/cli.js --update`, the one sanctioned un-gated writer, **refuses on a
  project whose config is absent** (`bin/cli.js:1082`) and, where it does run,
  preserves judgment fields rather than authoring them.

So the CLI delegates field-filling to `install-antislop`, and the gate forbids
`install-antislop` from doing it. That contradiction is the bug in the
screenshot. It is a shipped regression in the primary onboarding path, not a
papercut.

**Second, independent manifestation, measured first-person while authoring this
spec.** The `Bash` branch also fires on read-only introspection. A single
compound read-only command (`echo … ; jq -r '.fileHashes|keys[]' <that path> ;
grep -n … tests/validate.sh`) was denied, because `is_benign_jq_read()`
(`:183-191`) requires the *whole* command to be one `jq` invocation with no pipe,
redirection or separator. `.claude/reviewed/reviewer-changes-examples-lean-2.pass`
carries a `NOTE[code]` recording the same class from a prior reviewer: *"blocked
four of my read-only commands during this review because their TEXT named the
harness persona-selection config file."* This spec does **not** fix that half —
see *Out of scope* — but it is the same operator complaint and should not be
mistaken for closed when this lands.

### Why the gate is absolute today, and what that buys

`docs/plans/2026-08-25-harness-trust-gaps.md` Step 2 (`:976`) is the origin:
*"No config precondition, no grant branch, no identity exemption, and no
`reviewGating` read."* The reason is the bootstrap defect in F1: the config
holds `gatedAgents`, `humanReviewMode` and (per spec 6) `reviewGating.mode`, the
master switch for whether review is enforced at all. A config-driven guard over
a config file is self-referential — a `Write` that empties `protectedPaths` is
evaluated against the *pre-edit* config and passes. Hence hardcoded and
configless. `docs/trust-model.md` row 11 is the durable claim this underwrites.

**What it does not buy, and this bounds how much the hatch costs.** The
`Write`/`Edit` branch is an exact path match and is airtight. The `Bash` branch
is a text scan and is **already defeated by a documented, still-open family**:
`.claude/reviewed/harness-integrity-gate-hardening.fail` records four
counterexamples reproduced against the shipped gate, all `exit 0` (ALLOWED), one
proven destructive in a scratch repo — `cd .claude; rm -f <the file>`,
`cd .claude && git add persona*.json`, `git -C .claude add persona*.json`, and a
split-variable spelling. Root cause: `set_a_mentioned()` matches per-chunk with
no notion of the command's working directory. So against a *determined* agent
the config is already reachable without any prompt. Against an *honest, confused*
agent — the screenshot — the gate is a wall with no door. The hatch changes the
second case and barely touches the first.

### Engaging with the prior `fable` analysis, rather than re-deriving it

A `fable` dispatch earlier this session analysed whether `AskUserQuestion` could
front the sibling `human-decision-gate.sh`. Its conclusion, restated so this spec
argues against the real thing: an `AskUserQuestion` answer, *once relayed as text
inside a model's own turn*, is byte-identical from any downstream consumer's
vantage to a fabricated one — because "no message from any agent is ever your
user's consent" is the harness's own standing rule. The only design preserving
non-repudiation is a `PostToolUse` hook reading the **harness-constructed**
`tool_response` directly, verifying the question was shaped as a fixed
authorization prompt rather than model-composed wording, and performing the write
as hook code so no Claude tool call — and therefore no `PreToolUse` gate — is in
the path.

That reasoning is correct **and it is reasoning about a different problem**, for
a reason worth stating precisely. `docs/plans/2026-08-11-human-decision-channel.md`
(§ *Why not Claude Code's own permission prompt as the channel*) rejects the
permission prompt on three grounds: (a) provenance is unobservable **to the
agent**; (b) mode-dependent; (c) session-bound. Grounds (a) and (c) presuppose
that the consent must survive as a **durable artifact** that a **later agent**
**verifies with its own Read tool**. That is exactly what a `DECISION` file is
for. It is not what this request needs. Here the consumer of the consent is the
**hook itself, synchronously, for one tool call** — which is the role that same
document assigns the permission system in its own closing sentence: *"The
permission system keeps its existing role (per-call consent); the DECISION file
carries escalation consent."*

So the honest reading is not "`fable` was wrong"; it is "`fable` answered the
escalation-artifact question, and this is the per-call-consent question, which
its own source document already routes to the permission system."

Ground (b), mode-dependence, **does transfer in full** and is the one real cost.
It is what Step 1's frozen mode allowlist exists to price.

### Why `AskUserQuestion` is the wrong primitive here specifically

Not a judgment call — four measured/documented blockers, any one of which is
disqualifying:

1. **`AskUserQuestion` is unavailable to subagents** — `docs/design.md:111`,
   *"confirmed against the Claude Code docs, not assumed"*. A hatch built on it
   could never serve a `lead-programmer`, `scribe` or `install-antislop`
   sub-dispatch. `PreToolUse` hooks, by contrast, fire inside subagents.
2. **The payload is arbitrary JSON, not a small enum.** `DECISION` carries a
   route enum — a fixed, enumerable choice a prompt can faithfully present. The
   persona-selection config is an arbitrary structured document. A
   `PostToolUse`-performs-the-write design must source that document from
   somewhere; the harness-constructed `tool_response` of an `AskUserQuestion`
   does not carry it, so it would come from an agent-authored staging artifact —
   reintroducing precisely the agent-authored-content problem the design exists
   to remove. It would buy "a human approved *something*", not "a human approved
   *this content*".
3. **The `tool_response` shape for `AskUserQuestion` is undocumented.** Confirmed
   against the current hooks reference. Building the system's strongest
   non-repudiation claim on an unverified harness contract is the kind of thing
   constitution P1 exists to stop.
4. **The model composes the question.** `fable` named this as the thing a design
   must verify away. `permissionDecision: "ask"` removes it structurally: the
   prompt is rendered by Claude Code from the hook's own
   `permissionDecisionReason` (a fixed literal in the gate source, C1.6) plus the
   tool call's own `tool_input` — which *is* the thing being authorized, shown to
   the human as a diff. There is no model-composed wording anywhere in the path.

### The mechanism, and why it is sound

Documented against the current Claude Code hooks reference:

- A `PreToolUse` hook may return
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask",
  "permissionDecisionReason":"…"}}`. `"ask"` surfaces Claude Code's interactive
  permission prompt, labelled with the hook's origin (`[plugin:<name>]` here).
- In `auto` mode it is documented that a hook's `"ask"` forces the prompt: *"the
  classifier can still deny the tool call, but it can't approve the call
  silently."*
- `permission_mode` is a **documented common input field present on every**
  `PreToolUse` invocation, with a closed value set:
  `default | plan | acceptEdits | auto | dontAsk | bypassPermissions`.
- `agent_id` is documented as *"present only when the hook fires inside a
  subagent."*

Those last two are what make a **fail-closed frozen allowlist** possible, which
is this design's whole safety argument (and the discipline
`harness-integrity-gate-hardening-3` already established for this file: a frozen
family table, never an unbounded universal).

**The one invariant that carries the non-repudiation property:** the gate gains
`ask` and keeps `deny`. **It never gains `allow`.** No agent-authored byte — not
the file content, not a planted file on disk, not a claim in the turn text —
can move the verdict past `ask`. The only thing that converts `ask` into a write
is a human at the prompt. C1.5 pins this by grepping the gate source for a
permission-decision `allow` and requiring zero.

### Set B is not a mechanical clone of Set A

OQ4 resolved to **(b) yes, same branch**. The mechanism is the same; four things
about the situation are not, and each one moves the design.

**1. Set B already has a door, and it is a silent one.** Set A's justification
was *a wall with no door* — both branches deny, and no sanctioned route
completes the write. Set B's `Write`/`Edit` deny has a **ratified, documented,
unprompted alternative**: the `Bash` branch is Set A only by deliberate ADR-0025
decision (`harness-integrity-gate.sh:28-36`), and the shared persona protocol
*teaches* the `Bash` heredoc fallback. `.claude/settings.json`'s
`permissions.allow` additionally carries `Bash(sed -i *)` (measured at
`d807630`), so `sed -i hooks/hooks.json` is allowed today with no prompt at all.

This inverts the naive risk reading, and the inversion is the core of the case
for (b): **today's deny does not prevent a Set B write, it routes that write
away from the only surface a human can see.** An agent intent on deregistering
the gate quietly would never choose the prompted path; it would use `Bash`, as
it may today. So `ask` cannot be chosen *instead of* the silent route by a
determined agent — it can only be reached by an agent acting in the open. Against
that agent, `ask` is strictly more observable than today's deny.

**2. The legitimate write here is the maintenance path — including this spec's
own.** `hooks/hooks.json` and `hooks/scripts/harness-integrity-gate.sh` are
ordinary source files in this repo under active maintenance; R3 records that
every unit touching them must currently use `Bash` heredocs. The trust-gaps plan
accepted the same cost for `.claude/settings.json` explicitly (*"blocks
legitimate permission edits too … that is the intended trade"*). So the scope
rule in the Goal admits Set B on the same ground it admits Set A, and on the
same ground it **excludes** the audit logs.

**3. `agent_id`-present → deny bounds the blast radius for free, and it is worth
stating because it is counter-intuitive.** The condition is carried over from Set
A unchanged, and its consequence for Set B is large: the branch **can never fire
from a subagent**, so `lead-programmer` — the highest-volume writer of these
three files — still hard-denies and still uses the `Bash` route (R3 survives
untouched, including for the unit that implements this spec; there is no
bootstrap paradox). Only the main session can reach the Set B prompt. That
caps R2 (habituation) at a handful of prompts per maintenance cycle rather than
one per dispatch.

**4. Post-hoc detectability is *not* uniform across the three literals, and the
worst-detected one is the highest-value target.** Measured at `d807630`:

| Set B literal | If it is gutted, what notices? |
|---|---|
| `hooks/scripts/harness-integrity-gate.sh` | `tests/harness-integrity-gate.test.sh`, run by `tests/validate.sh:354`, executes the gate and asserts its verdicts. A gutted gate is a red merge gate. **Best detected.** |
| `.claude/settings.json` | `tests/cli-hook-propagation.test.js` compares a scaffolded project's registrations against `hooks/hooks.json`. Partial, and only for the standalone-scaffold shape. |
| `hooks/hooks.json` | **Nothing.** `expectedRegistrations()` (`tests/cli-hook-propagation.test.js:147-159`) reads `hooks/hooks.json` and *derives* the expectation from it. Deleting the gate's registration shrinks the expectation in lockstep and the suite stays green. `bin/harness-integrity.sh` checks log seals, not registrations (zero `hooks.json`/`PreToolUse` matches). `protectedPaths` carries no `hooks`/`settings` entry, and `tests/protected-paths-coverage.test.js:14` exempts this gate as *"self-protecting instead"*. |

So the one Set B member whose loss disables everything is the one member nothing
currently checks. **Step 7 closes that**, with a *fixed literal* expectation
table rather than a derived one — and it is the reconciler for U5 below. This is
a pre-existing hole, not one (b) creates; but (b) is what makes it load-bearing,
because a prompt that a human approves is only a safeguard if something
afterwards can tell whether the gate survived.

**What follows from 1–4, concretely:**

- Set B's mode allowlist **excludes `acceptEdits`** (Set A's keeps it). Whether a
  hook's `ask` overrides `acceptEdits`'s auto-accept posture is undocumented —
  the same family as U1 — and the cost of being wrong is asymmetric: a silent
  auto-approve on Set A writes one config while the gate stays armed and
  re-guards the next call; a silent auto-approve on Set B can remove the gate,
  after which nothing is guarded and nothing notices. Excluding it is a strict
  fail-close with **zero regression**: in `acceptEdits` the Set B verdict stays
  exactly today's deny, and the agent falls back to `Bash` exactly as today.
- Set B gets its **own fixed reason literal**, naming what approval costs. The
  additional safeguard that is actually achievable beyond *"a human must
  approve"* is **telling the human what they are giving up** — that this write
  can disable every future prompt, including this one. It must remain a literal
  with no interpolation (C1.6), so this is two frozen strings selected by set,
  never one constructed string.
- Set B's branch is **gated on measuring U1 first** (Step 5, C5.5). See R10: the
  `permissions.allow` escalation chain is materially cheaper to exploit against
  `ask` than against `deny`, and `.claude/settings.local.json` is not guarded by
  anything.

### Undocumented harness behaviours this design deliberately does not depend on

Confirmed undocumented; each is routed around rather than assumed:

| # | Unknown | How the design avoids depending on it |
|---|---|---|
| U1 | Does a hook's `"ask"` override a matching `permissions.allow` entry in `default`/`acceptEdits`? | Set A: OQ3 removes the one such entry in this repo, making the question moot here. Set B: **not moot** — an agent can add an entry to the unguarded `.claude/settings.local.json` (R10), so Set B's branch does not ship until Step 5 measures it (C5.5). Named as a residual in the ADR either way. |
| U2 | What does `"ask"` do under `bypassPermissions` / `dontAsk`? | Both are **excluded from both allowlists** → deny. The gate never emits `ask` in a mode whose prompt behaviour is unknown. |
| U2b | Does a hook's `"ask"` override `acceptEdits`'s auto-accept posture? | Set A accepts the risk (bounded: the gate stays armed). Set B **excludes `acceptEdits`** → deny, because there the cost of a silent auto-approve is the gate itself. Zero regression: that is today's verdict. |
| U3 | Does `"ask"` render for a tool call made inside a subagent? | `agent_id` present → deny. The gate never emits `ask` from a subagent — for Set B this is also what keeps `lead-programmer` on the existing `Bash` route (R3) and caps R2. |
| U4 | What does `"ask"` do in a non-interactive/headless (`-p`) session? | No documented field distinguishes interactive from headless. Accepted residual, priced in R4: a `-p` run in `default` mode reaching this write is the one shape where the gate emits `ask` without knowing a prompt can render. Documented evidence points to fail-closed (for `PermissionRequest`: *"in sessions that can't show a prompt … it denies the tool call"*; for `PreModelSwitch`: *"treats `ask` as a refusal"*), but neither statement is made about `PreToolUse`. |
| U5 | **Set B only.** Does the `PostToolUse` completion record (Step 2) still fire for the very write that edits the gate or its registration? | Undocumented, and possibly *no* by construction: a `hooks/hooks.json` edit that removes the registration, or a `harness-integrity-gate.sh` edit that no-ops the script, may suppress its own completion line. Consequence: **for Set B, an `asked` line with no `completed` line is ambiguous** — denied, or approved-and-self-disabled, which are opposite outcomes. Not closable inside the hook. Reconciled *outside* it by Step 7's registration-presence assertion plus `git log` on the surface; stated as a bounded claim in the ADR and trust-model, never as "the log distinguishes them". |

### Terminology (`antislop:ubiquitous-language`, prose mode, advisory)

Glossary read: `CONTEXT.md` (2,865 lines).

- **Lens 1 — a glossary term used with a different meaning: one finding.**
  `CONTEXT.md:1879` puts *escape hatch* on the `_Avoid_` list for the
  bootstrap-window pattern, and `:486`/`:2586` use it for **file-based override
  artifacts** (`.claude/.dispatch-override`, the `defer:`/`skip:` override). The
  request's "escape hatch" is not a file and not an override — it is a
  synchronous per-call prompt. Canonical term proposed below; *escape hatch* is
  avoided throughout this document.
- **Lens 2 — a new synonym for an already-defined term: one finding, and it is
  load-bearing in the other direction.** *grant branch* (`CONTEXT.md:2160`,
  `harness-integrity-gate.sh:9`) means an **identity-scoped exemption** — the
  reviewer may write `.claude/reviewed/*.pass`. The new branch is **not** a grant
  branch: it exempts no identity and hands nobody a unilateral capability.
  Consequence for Step 4: the header's *"no grant branch, no identity exemption"*
  stays **literally true** and must not be deleted; what becomes false is the
  deny message's *"may not be written directly by any agent identity, ever"* and
  *"no exemption"*. Deleting the true clause alongside the false one would
  silently discard a real property. **This holds identically for Set B** — the
  new branch grants Set B no identity anything either; it routes the decision to
  a human.
- **Lens 2, second finding (surfaced by the Set B rework, and it is a live
  misreading risk).** The `agent_id` condition is **identity-sensitive in the
  restricting direction**, which is the opposite of a [[grant branch]]: no
  identity gains a capability, one class of identity (subagents) is held at
  today's deny. Step 4's header prose and the ADR must say *"never emits `ask`
  from a subagent"*, never *"exempts the main session"* — the second phrasing
  would read as a grant branch, invert the property, and is exactly the
  over-claim class R5 records two FAILs for.
- **Lens 3 — load-bearing new domain term with no entry: one.** Proposed
  canonical term **human-confirmation branch** — *the branch of
  `harness-integrity-gate.sh`'s `Write`/`Edit` path that, for the
  persona-selection config (Set A) and the gate's own registration surface
  (Set B) and only in a frozen per-set allowlist of session shapes, returns
  `permissionDecision: "ask"` instead of exiting 2, so Claude Code's own
  permission prompt decides. The two sets share the mechanism and differ in
  their allowlist and their prompt wording. Distinct from a [[grant branch]]
  (identity-scoped, unilateral) and from an override artifact (a file). Never
  returns `allow`, and never fires inside a subagent.* Suggested for `scribe`;
  see *Scribe update hint*.

---

## Clarifications

*Re-scored 2026-09-23 after the operator resolved OQ1–OQ4, then again after
OQ5, and a third time after the mid-flight sweep-closure gap. That third pass
moved **Completion / acceptance signals** back to **Partial** — a criterion
(C4.1) whose escape set could not classify its own sweep's output is not a
usable completion signal — and it is resolved back to Clear by the rewritten
C4.1 plus C4.9.*

*Re-scored a fourth time 2026-09-24 after the `hcb-regcheck` kill-set tension.
That pass moved three categories back to **Partial**: **Edge cases / failure
handling** (a criterion that contradicted the two criteria it audited),
**Domain entities / data model** (no declared unit for a "kill set"), and
**Technical constraints & tradeoffs** (whether the fix may disturb an
already-granted PASS). All three are resolved to Clear by the rewritten C3.3 and
R14 — the three dated lines closing them are the last three below.
**Terminology consistency** was re-checked in the same pass and stays Clear:
`CONTEXT.md:219-225` already defines **two-tier allowlist** and already names
C1.3(b) as its defender, which the ruling follows rather than contradicts; the
two undefined load-bearing terms the amendment does introduce (**kill set**,
**kill-set relation table**) are routed to `scribe` as advisory lens-3
suggestions, not treated as blockers.*

*Re-scored a fifth time 2026-09-24 (second amendment) after the `hcb-prose-gate`
implementer reported C4.2 unsatisfiable. That pass moved **Completion /
acceptance signals** back to **Partial** for the second time in this spec's life,
on the same underlying ground R13 raised and R15 now generalizes: a criterion
that cannot go green against its own step's mandatory content is not an
acceptance signal, and one whose second half is satisfied by untouchable frozen
literals is not either. It is resolved back to **Clear** by the rewritten C4.2,
whose four parts were mutation-verified red-and-green before being written down.
**Edge cases / failure handling** was re-examined in the same pass and stays
**Clear**: the scoping the fix introduces is itself a new failure surface
(vanished span, run-to-EOF span, relocated absolute), and all three are covered
by C4.2(a) and (c) rather than deferred. The one new load-bearing term the fix
makes explicit (**over-scoped criterion**) is routed to `scribe` as an advisory
lens-3 suggestion, not a blocker. All nine categories are Clear; no category
is deferred as an assumption.*

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-23 Functional scope & success criteria: Q Does the hatch cover the
  four audit logs and their `.seal` sidecars, or only the persona-selection
  config? → A: **config only — operator confirmed OQ1 (a).** Re-verified after
  OQ4 moved Set B into scope: the reasoning is **unaffected and reinforced.**
  The discriminator that admits Set B is the same one that excludes the logs —
  a legitimate agent-authored write exists for Set B (every maintenance unit on
  this gate) and exists for none of the logs or seals. That is now stated once,
  as the scope rule in the Goal, rather than as three separate judgment calls.
- 2026-09-23 User interaction flow: Q Through what surface does the human
  confirm — `AskUserQuestion`, or Claude Code's permission prompt? → A:
  **`permissionDecision: "ask"` — operator confirmed OQ2 (a).** Re-verified
  under OQ4: all four `AskUserQuestion` blockers apply to Set B unchanged, and
  blocker 2 (the payload is arbitrary JSON, so approval cannot bind to content)
  is *sharper* there — a hooks registration file and a shell script are less
  bindable than a config, not more.
- 2026-09-23 Functional scope & success criteria: Q Does the branch extend to
  Set B (`hooks/hooks.json`, `.claude/settings.json`,
  `hooks/scripts/harness-integrity-gate.sh`)? → A: **yes — operator chose OQ4
  (b), against the recommended default.** Reworked rather than cloned: Set B
  excludes `acceptEdits` from its allowlist, carries its own fixed prompt
  literal naming the self-disablement cost, is gated on measuring U1 first
  (R10), and requires the new registration-presence assertion (Step 7) because
  `hooks/hooks.json`'s registration is pinned by nothing today.
- 2026-09-23 Non-functional attributes (perf, security, scale): Q Does making
  Set B `ask` rather than `deny` open a new escalation chain? → A
  (self-resolved): **yes, and it is priced, not hidden.**
  `.claude/settings.local.json` is guarded by nothing, so an agent can add a
  `permissions.allow` entry for a Set B path and then write it. The chain is not
  strictly new — it already depends on U1 — but its *cost* drops: today it needs
  `allow` to override a hook **deny** (which, if true, would already be a live
  defect independent of this spec); under (b) it needs `allow` to override a
  hook **ask**, a materially weaker and more plausible harness behaviour.
  Handled by gating Set B on C5.5's measurement rather than by guessing. See R10.
- 2026-09-23 Edge cases / failure handling: Q For Set B, does "asked but never
  completed" still read as a denial? → A (self-resolved): **no — it is
  ambiguous, and saying otherwise would be an over-claim (R5).** A Set B write
  can suppress its own `PostToolUse` record (U5). Reconciled outside the log by
  Step 7 plus `git log` on the registration surface; the ADR and trust-model
  state the ambiguity rather than papering over it.
- 2026-09-23 Functional scope & success criteria: Q Does Set B gain a fourth
  literal — the gate's mirror at `.claude/hooks/scripts/harness-integrity-gate.sh`?
  → A: **yes — operator resolved OQ5 (a).** Raised by OQ4's rework, not by the
  original request: Set B exists to protect the gate's own definition, but it
  named only the plugin-source copy, while a standalone (non-plugin) install
  executes the mirror (`bin/cli.js:1899-1905`), which matched no Set B literal
  and was writable. Pre-existing, but material once Set B is prompted rather
  than denied. Closed by one line in the existing `case` plus C1.11 (Write/Edit
  asks under Set B's tier) and C1.12 (Bash still exits 0). Cost is near-zero:
  the mirror must never be hand-edited anyway, and `--update` writes it through
  `fs`, invisible to this gate by construction. R12 ships closed, not as a
  residual.
- 2026-09-23 External dependencies & integrations: Q Does OQ4 change the
  adapter answer? → A (self-resolved): **no.** Set B is the literal path
  `hooks/hooks.json`; the generated `.cursor/hooks.json` and `.codex/hooks.json`
  are not Set B members and stay writable — correctly, since neither adapter
  registers this gate at all (`adapters/*/hooks/scripts/` carries graph-update,
  lint-on-edit, microworld-rerun, protected-paths, reviewer-route-gate and
  stop-gate only). No adapter port, same precedent as `human-decision-gate.sh`.
- 2026-09-23 Technical constraints & tradeoffs: Q Can a `PreToolUse` hook
  surface a human prompt at all, and can it tell whether one will render? → A
  (self-resolved): yes to both. `permissionDecision: "ask"` is documented;
  `permission_mode` (closed 6-value set) and `agent_id` are documented
  always-present / conditional payload fields. A hook **cannot** prompt
  synchronously itself — hooks *"run in their own session without a controlling
  terminal … can't open `/dev/tty`"* — so no hook-side `read` design exists.
  `permissionDecision: "defer"` is honoured only under `-p` and *"logged as a
  warning and ignored"* interactively, so it is not a usable third option.
- 2026-09-23 Technical constraints & tradeoffs: Q Is a deterministic CLI writer
  (`bin/cli.js --merge-config`) the sounder alternative, since it keeps the deny
  intact? → A (self-resolved): **no — it is strictly less sound.** `bin/cli.js`
  writes via `fs.writeFileSync` and is invisible to this gate by construction, so
  a merge flag taking agent-authored JSON would be an un-prompted, unlogged,
  full-capability writer of `gatedAgents`, `humanReviewMode` and
  `reviewGating.mode` available to every agent with `Bash`. Today `--update`
  cannot do this (it preserves judgment fields rather than authoring them). The
  prompt is better precisely because the human sees the content.
- 2026-09-23 Edge cases / failure handling: Q What happens in session shapes
  where a prompt cannot render? → A (self-resolved): the mode/identity check is
  an **allowlist**, not a denylist — `ask` only for
  `default|plan|acceptEdits|auto` with `agent_id` absent; everything else,
  including an absent, empty or unrecognised `permission_mode`, denies. A future
  mode added by Claude Code therefore denies by default. One residual remains
  (U4/R4), named not hidden.
- 2026-09-23 Edge cases / failure handling: Q Does the audit trail survive the
  change? → A (self-resolved): only with Step 2. There is **no hook event that
  fires when a human approves an interactive permission prompt** (documented
  gap), so the `PreToolUse` hook cannot record the outcome. `PostToolUse` *"runs
  immediately after a tool completes successfully"*, so its firing is the
  available proxy for "the write happened". Without Step 2 the most
  security-relevant event in the system becomes the only unlogged one, and
  trust-model row 11 becomes unverifiable rather than merely weaker.
- 2026-09-23 External dependencies & integrations: Q Do the codex/cursor
  adapters need a port? → A (self-resolved): **no.** Neither adapter carries
  `harness-integrity-gate.sh` (`adapters/*/hooks/scripts/` holds graph-update,
  lint-on-edit, microworld-rerun, protected-paths, reviewer-route-gate,
  stop-gate only), the same precedent `human-decision-gate.sh` and
  `reviewed-path-gate.sh` already set. State the parity in the header.
- 2026-09-23 Terminology consistency: Q Does the draft drift against
  `CONTEXT.md`? → A (self-resolved): one lens-1 finding (*escape hatch*, avoided
  here), one lens-2 finding (*grant branch* — which changes Step 4's edit from a
  deletion to a split), one lens-3 finding (**human-confirmation branch**,
  routed to `scribe`). Advisory only; details in Context.
- 2026-09-23 Functional scope & success criteria: Q Is the `Bash` branch in
  scope for the hatch? → A (self-resolved): **no.** The `Bash` prompt renders the
  agent's own command text, which the agent composes and can pad so the real
  write is not what the human's eye lands on — `fable`'s "model-composed wording
  that could mislead", exactly. The `Write`/`Edit` prompt renders a normalized
  exact path plus a diff. That asymmetry is the line, and it mirrors the existing
  ratified Set A/Set B branch asymmetry rather than inventing a new principle.
  The sanctioned `Bash` route (`node bin/cli.js`) already passes. **Unchanged by
  OQ4:** Set B remains absent from the `Bash` branch (ADR-0025), so the `Bash`
  side of Set B stays allowed exactly as today — that asymmetry is what
  *motivates* the Set B prompt (Context, point 1), not something this spec
  closes.
- 2026-09-23 Technical constraints & tradeoffs: Q Should
  `Edit(.claude/persona-config.json)` be removed from
  `.claude/settings.local.json`'s `permissions.allow`? → A: **yes — operator
  confirmed OQ3 (a).** Re-verified under OQ4: no Set B path currently appears in
  either settings file's `allow` list (measured at `d807630`), so Step 5 removes
  exactly one entry — but C5.1 is widened to assert *zero* entries for Set A
  **and** Set B paths, so a later addition is caught rather than assumed absent.
  Note `.claude/settings.local.json` is itself **not** a Set B member and is not
  guarded by anything; Step 5 is therefore executable by ordinary `Edit`, and
  that same lack of guarding is R10.
- 2026-09-23 Completion / acceptance signals: Q C4.1's sweep returns three hits
  that neither of its two escapes admits — what bucket do they go in? → A
  (self-resolved): **a third and a fourth category, plus a closure assertion.**
  The two escapes were narrower than the filter that built Step 4's table
  ("filtered to this gate"), so any hit that is neither about
  `human-decision-gate.sh` nor amended had nowhere to go. Cat 3
  (*about this gate, still literally true*) admits
  `docs/plans/2026-09-02-blocked-marker-scoping-gh425.md:621`; Cat 4
  (*excluded file*) admits `CHANGELOG.md`; row 13 handles the third hit,
  `docs/plans/2026-08-11-microworld-silo.md:300,559`, as ordinary Cat 2. The
  durable fix is C4.1(a)'s **both-directions closure check** — an unlisted
  hit-bearing file is now red, which is the assertion whose absence let three
  hits go unnoticed at authoring time. See R13.
- 2026-09-23 Technical constraints & tradeoffs: Q Is `CHANGELOG.md` amended in
  place / annotated, or exempt from prose-reconciliation sweeps? → A
  (self-resolved, **and cheaply reversible — one table row**): **exempt, as the
  sole Cat 4 member.**
  [ADR-0029](docs/adr/0029-microworld-silo-namespaced-directories.md)'s
  *Consequences* is a ratified repo ruling naming `CHANGELOG.md` as a
  historical-citation surface whose entries are *"left exactly as written"* and
  read *"as of that entry's date"*; its stated reason (rewriting destroys the
  audit trail between a commit and its description) transfers from path
  citations to behaviour descriptions more strongly, not less. The competing
  reading — that rows 7–9 annotate `docs/plans/`, which ADR-0029 lists in the
  same breath — is reconciled by chronology: a plan doc is not chronologically
  ordered, so a dated note appended under the relevant step is coherent there
  and destroys nothing, whereas the same note in a CHANGELOG interleaves a
  2026-09 correction into a `0.31.x`-era section. Paid for by narrowing C4.1's
  headline claim and by C4.9's ADR supersession record; the alternative (a
  dated note at `CHANGELOG.md:102`) is a one-row change to the Cat 4 list if
  the operator prefers it.
- 2026-09-24 Edge cases / failure handling: Q When one mutation control's scope
  is a strict narrowing of another's, is the overlap a defect to eliminate or a
  property to assert? → A (self-resolved): **a property to assert.** Verified
  from `hooks/scripts/harness-integrity-gate.sh`'s `ask_allowed()` — under the
  C1.3(a) mutant the `case` is a no-op, so `acceptEdits` + Set B +
  `agent_id`-absent necessarily reaches `ask`; containment is a consequence of
  the source's own structure, not of either mutant's construction. Eliminating it
  would require weakening C1.3(a) or gutting C1.3(b) (R14). C3.3(d) therefore
  asserts `K_b ⊊ K_a` positively and freezes the other five pairs as disjoint.
- 2026-09-24 Domain entities / data model: Q What is the unit of measurement a
  kill set is a set *of*? → A (self-resolved): a **cell**, the tuple
  `(hook_event_name, tool_name, subject, permission_mode, agent_id-state)`, with
  the universe declared once as a literal in the test and every control driven
  from it. The old C3.3's "set of cases" admitted at least two accountings that
  give different numbers for the same mutant — both are recorded in
  `.claude/reviewed/hcb-branch.pass` — and a subset/disjointness claim is
  meaningless until one is fixed. C3.3(a).
- 2026-09-24 Technical constraints & tradeoffs: Q Does redefining C3.3
  retroactively disturb `hcb-branch`'s already-granted PASS? → A (self-resolved):
  **no, and deliberately not.** C1.3(a) and C1.3(b) keep their wording verbatim;
  only C3.3 — a Step 3 criterion evaluated by `hcb-regcheck`, never by
  `hcb-branch` — changes. The alternative considered and rejected was option (b)
  of the implementer's report: narrowing C1.3(a) to "Set B's 5 *other* deny
  rows", which would both weaken the mutant (a partial-allowlist mutation would
  survive) and move an already-PASSed criterion's goalposts after the fact. See
  R14 (ii) for why `d598603` needs no retroactive re-review.
- 2026-09-24 (second amendment) Completion / acceptance signals: Q C4.2's check
  is file-wide but its prose names only the deny message — which scope governs? →
  A (self-resolved): **the prose governs; the check was wrong and is rewritten.**
  Not a judgment call in the end, because the two readings are not both available:
  the file-wide reading is unsatisfiable (15 hits at `094a17e`, three of them
  pinned by this step's own other criteria), so it cannot be a completion signal
  at all. The narrow reading is satisfiable and is what every surrounding
  artifact — the plan's row 3, issue #471's ordered edit 3 — already describes.
  See R15 and CHK28.
- 2026-09-24 (second amendment) Completion / acceptance signals: Q Does C4.2's
  "still names the sanctioned route" half describe the baseline, or require a
  change? → A (self-resolved): **it requires a change, and the word "still" was
  inaccurate.** Measured: the baseline deny message names
  `docs/plans/2026-08-25-harness-trust-gaps.md` Step 2 and no route; the only two
  `bin/cli.js` mentions in the file are the frozen `reason_a`/`reason_b` literals
  this unit may not touch. So the half was simultaneously mis-described *and*
  vacuous. Resolved by scoping it to the span and stating plainly that the
  implementer must add the route. Disclosure hygiene is unaffected — both reason
  literals already name it, and a remedy is the rule, not the technique.
- 2026-09-24 (second amendment) Edge cases / failure handling: Q Once a criterion
  is scoped to a code region, what stops it going green because the region moved?
  → A (self-resolved): **three guards asserted before the substantive arms, plus
  one fixed-phrase file-wide arm.** Non-empty span, span ends on its closing `}`,
  exactly one `BLOCKED:` line inside it — covering rename, unterminated-function
  run-to-EOF, and message deletion respectively; and a file-wide zero for the
  fixed phrase "any agent identity, ever" covering relocation out of the span.
  All four failure modes were built as live mutants and confirmed red, not
  reasoned about. See R15 (ii)-(iii) and CHK30.

---

## Risks / dependencies

- **R1 — mode-dependence is the real cost, and it is `fable`'s ground (b).** In
  `bypassPermissions` or `dontAsk`, today's behaviour is a hard deny. Step 1
  keeps it a hard deny by excluding both from the allowlist. The risk is a later
  unit "simplifying" the allowlist into an unconditional `ask`. C1.3's mutation
  proof exists to make that a red test, not a review catch.
- **R2 — habituation, and it is the risk OQ4 changes most.** A prompt clicked
  through reflexively is worse than a wall, because it launders the decision.
  Three things bound it: the branch covers five files written rarely (one config
  per project plus this gate's own maintenance cycle); it covers neither the
  `Bash` branch (which fires on prose and would generate volume) nor the audit
  logs; and `agent_id`-present → deny means **it cannot fire from a subagent at
  all**, so the busiest writer of the Set B files (`lead-programmer`) never
  reaches it. The residual that genuinely worsens under OQ4 is *legibility*, not
  volume: a `hooks/hooks.json` diff removing one array entry among many is the
  least eye-catching of the four. That is what Set B's own prompt literal and
  Step 7's post-hoc check exist to compensate for; neither eliminates it.
- **R3 — this gate is Set B, so editing it is itself blocked — and OQ4 does not
  change that for the implementer.** `Write`/`Edit` on
  `hooks/scripts/harness-integrity-gate.sh` exits 2 for every identity;
  `docs/plans/2026-08-25-harness-trust-gaps.md` Step 2 accepted this
  deliberately (*"it does affect every later maintenance unit, and that cost is
  accepted"*). The implementer must edit it via `Bash` (the ratified ADR-0025
  `Bash`-side Set B gap), and **must not** add Set B to the `Bash` branch to
  "fix" anything — the asymmetry mutation control exists to catch that. **Under
  OQ4 the `Bash` route survives for the implementer specifically because the new
  branch denies inside subagents** (U3): a `lead-programmer` editing this file
  sees today's exit 2, unchanged. There is no bootstrap paradox, and the
  implementing unit must not "discover" the new branch and try to use it.
- **R4 — residual U4, headless `default` mode.** Named in the Context table.
  Not closable from inside the hook: no documented field distinguishes
  interactive from headless. Tracked open, **not accepted as safe** — Step 5's
  characterization record is what would close or confirm it.
- **R5 — prior defect history on this exact file, and it is the same class as
  the risk here.** `.claude/reviewed/harness-integrity-gate-hardening.fail` is a
  blocking FAIL whose ground was an **over-claimed universal** in prose the code
  did not hold; `docs/plans/2026-09-09-debug-spec-harness-integrity-gate-hardening.md`
  records it cost two FAIL cycles.
  `.claude/reviewed/hdg-prose-2.fail` is the sibling gate's equivalent. **No step
  below may be tagged `haiku`**, and every claim added to the gate header, the
  deny message, `CONTEXT.md`, `docs/trust-model.md` or the ADR must be a bounded
  statement. `tests/harness-integrity-gate.test.sh:363-383` enforces this
  mechanically over both the gate source and the lead-programmer memory note —
  the forbidden phrases are `any spelling`, `all spellings`, `no glob can`,
  `every spelling`, `is always detected`. A phrase like "no agent can ever reach
  this branch" is that same failure mode and will fail C3.6.
- **R6 — `.claude/hooks/scripts/harness-integrity-gate.sh` is a byte-identical
  mirror** (`tests/validate.sh:318`, `diff -rq`) and is keyed in `fileHashes`
  (verified present). A gate edit is a three-artifact change: source, mirror,
  hash. Regenerate with `node bin/cli.js --update`; never hand-edit the mirror
  (constitution P2).
- **R7 — `docs/trust-model.md` is bijection-tested.**
  `tests/trust-model-bijection.test.js` pins `EXPECTED_SELF_REPORTED_COUNT = 10`
  and requires every `hooks/scripts/*.sh` to appear. Amending row 11 in place
  keeps both invariants; **adding a new script would require a new row**, which
  is one reason Step 2 extends the existing script rather than adding a sibling.
- **R8 — disposition of the `.claude/reviewed/` sweep.** `bash bin/marker-audit.sh .
  --notes --surface=hooks/scripts/harness-integrity-gate.sh` returns
  `spec=0 code=1 untagged=1 malformed=4`. The `NOTE[code]`
  (`reviewer-changes-examples-lean-2`) is the read-only-false-positive class —
  **acknowledged, explicitly out of scope**, recorded in Context so this spec is
  not mistaken for closing it. The `untagged` note (`gh418`) confirms the
  `tr '\n\r'` newline flattening on the deny path is sound and has no
  printf-format vector — **no action; it is a clean bill of health on a line
  Step 2 must not regress** (the new audit records must use the same
  `audit_append` idiom). The sweep is best-effort and `.claude/reviewed/` is
  gitignored per-clone state, so an empty result would never have been proof of
  absence.
- **R9 — 108 `.fail` records exist in this clone; the two named in R5 are the
  ones on this surface.** Enumerated, not sampled.
- **R10 — [OQ4] the `permissions.allow` escalation chain, and why it gates Set
  B's ship.** `.claude/settings.local.json` is a member of **no** protected set
  and is not guarded by any gate (verified: `protectedPaths` carries no
  `settings` entry; Set A and Set B both name `.claude/settings.json`, not the
  `.local` variant). If U1 resolves "an `allow` entry overrides a hook's `ask`",
  an agent can write `permissions.allow: ["Edit(hooks/hooks.json)"]` there and
  then deregister the gate with **no prompt and no human in the loop** — two
  unprompted steps. Today the same chain would need `allow` to override a hook
  **deny**, which if true is already a live defect independent of this spec; the
  change is that (b) lowers the bar to the much more plausible `allow`-over-`ask`.
  **Mitigation, and it is a hard precondition, not advice: Step 1's Set B half
  does not land until C5.5 measures U1 and finds `allow` does not override
  `ask`.** If it does override, Set B routes back to spec-master (the same branch
  shape C5.4 already uses for R4). Set A is unaffected — OQ3 removes its one
  entry, and C5.1 now asserts zero entries for both sets.
- **R11 — [OQ4] `hooks/hooks.json`'s gate registration is pinned by nothing
  today, and the naive fix is vacuous.** `expectedRegistrations()`
  (`tests/cli-hook-propagation.test.js:147-159`) reads `hooks/hooks.json` and
  derives its expectation from it, so deleting the gate's registration shrinks
  the expectation and the suite stays green. `bin/harness-integrity.sh` checks
  log seals only. `tests/protected-paths-coverage.test.js:14` exempts this gate
  as *"self-protecting instead"* — an exemption that is now one branch weaker.
  Step 7 closes this with a **fixed literal expectation table**; an
  implementation that re-derives the expectation from `hooks/hooks.json` would
  reproduce the exact defect and is a FAIL, not a stylistic preference (C7.2 is
  the mutation proof).
- **R12 — [OQ4] the gate's *executing* copy in an adapted project is not in Set
  B.** Set B names `hooks/scripts/harness-integrity-gate.sh`; a standalone
  (non-plugin) install runs
  `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/harness-integrity-gate.sh`
  (`bin/cli.js:1899-1905`), which matches no Set B literal and is writable. In
  *this* repo the plugin-root copy is the executing one (`hooks/hooks.json`
  invokes `${CLAUDE_PLUGIN_ROOT}/...`) and `tests/validate.sh:318` diffs the
  mirror, so the hole is not live here. It is **pre-existing, not created by
  OQ4** — but OQ4 makes it material, because prompting on the source copy is a
  weaker safeguard than it reads if the executing copy is unguarded elsewhere.
  **CLOSED by OQ5 (a), operator 2026-09-23:** the mirror becomes Set B's fourth
  literal in Step 1, guarded by C1.11 (Write/Edit now asks) and C1.12 (Bash
  still exit 0). R12 therefore ships as a *fixed* gap rather than a recorded
  residual, and the ADR records it as closed, not accepted.
- **R13 — [2026-09-23] an enumeration whose escape set is narrower than the
  filter that built it, and it is a defect class worth naming.** Step 4's table
  was enumerated by running the authoring grep and filtering to *"this gate"*,
  but C4.1 admitted only two escapes — about `human-decision-gate.sh`, or
  amended. Everything that is neither had no bucket, so a literal implementation
  of C4.1 flags a **correct** tree. Three hits were in that state and none was
  noticed at authoring time, because **nothing asserted the table was closed**:
  the criterion checked the listed files and never checked that the list covered
  the sweep. Rewritten C4.1(a) closes it in both directions (an unlisted
  hit-bearing file is red; a listed file with zero hits is also red, so the
  table cannot rot into a stale allowlist). Two consequences worth carrying
  forward rather than rediscovering: a reconciliation sweep needs a
  **still-true** category or it will flag correct prose, and an **excluded
  file** must cost something explicit (C4.9) or the exclusion becomes the place
  stale claims go to die. Same family as R5 — a claim wider than the check
  behind it — applied to the criterion rather than to the prose it audits.
  **Two traps this criterion sets for its own implementer**, both found by
  running it against the amendment itself (CHK24) rather than reasoning about
  it: (i) **a spec that quotes the prose it is reconciling becomes a hit of its
  own sweep** — this plan doc carries 22 and is untracked today, so it appears
  only *after* the implementing unit commits, which is the worst possible moment
  for a closure check to go red; it is classified Cat 3 for that reason. (ii)
  **do not transcribe the hit list from a report or a wider exploratory grep** —
  the first draft of the Cat 1 list did, and picked up three files whose
  *"no grant / branch"* is line-wrapped and therefore never matched, which
  C4.1(a)'s zero-hit arm would have failed on. Re-run the exact authoring
  pattern with `git grep -l`; do not reuse a neighbouring one.
- **R14 — [2026-09-24] a mutation-control suite asserts a RELATION between kill
  sets, and "all pairs disjoint" is the wrong relation whenever one control
  narrows another.** The old C3.3 demanded four pairwise-disjoint kill sets. Two
  of its four controls cannot satisfy that and should not: C1.3(b) mutates one
  arm *of the very `case` block* C1.3(a) mutates wholesale, so `K_b ⊆ K_a` holds
  by construction, and the only ways to force disjointness are to carve
  `acceptEdits` out of C1.3(a) (leaving a partial-allowlist mutation that escapes
  detection — a real coverage hole) or to make C1.3(b) kill something other than
  the `acceptEdits` row (destroying its entire purpose). **The containment is
  evidence, not noise**: it says the Set B `acceptEdits` deny is produced by the
  frozen `case` and by nothing else, so a future unit that relocates that deny to
  a separate check breaks C3.3 even while both mutants stay individually green.
  Three further facts this risk records, each verified rather than assumed:
  (i) **the pair that genuinely must be disjoint is C1.3(a) × C1.4**, and it was
  genuinely violated — the mutant shipped by `hcb-branch` stubbed the *whole*
  `ask_allowed()` function, subsuming C1.4's `agent_id` kill set; `d598603`
  narrowed it to the `case`/`esac` block. (ii) **That narrowing is a correction
  *toward* C1.3(a)'s wording, not a redefinition of it** — C1.3(a) says
  "replacing the frozen `case`", the whole-function stub was already wider than
  that, and `.claude/reviewed/hcb-branch.pass` records the reviewer's own
  independent re-derivation using the *narrow* mutant ("the frozen case replaced
  by a bare catch-all … Zero `agent_id`-present cells flipped, correct"). So
  `hcb-branch`'s PASS stands unamended, on its original basis; `hcb-regcheck`
  records the narrowing in its own marker so the audit trail links the two.
  (iii) **the old C3.3 was also silently ambiguous about its unit of
  measurement** — that same marker records two legitimate accountings of the same
  mutant (29 probe cells, or 11 normalized `(set, mode)` rows), and a set relation
  is only well-defined once one of them is fixed. C3.3(a) fixes it. Same family as
  R5 and R13 — a claim wider than the check behind it — applied here to the
  claim a criterion makes about *other criteria*.
- **R15 — [2026-09-24, second amendment] a criterion whose GREP SCOPE is wider
  than its PROSE SCOPE is not merely loose; on a file that legitimately contains
  the banned token it is UNSATISFIABLE, and narrowing the token instead of the
  scope does not fix it.** C4.2's prose said *the deny message*; its snippet
  grepped *the file*, for the bare substring `ever`. Because this same step is
  independently required to freeze a paragraph containing "Nearly every command"
  (C4.3c), to add "never emits `ask` from a subagent" (C4.3b), and to leave
  `reason_b`'s "every future prompt" alone (Do-NOT-touch), the file-wide count
  can never reach zero: measured 15 at `094a17e`. This is R5's family inverted —
  R5 is prose over-claiming relative to its check; R15 is a **check
  over-claiming relative to its prose**, and it is the third member of the family
  alongside R13's escape-set gap. Three further facts this risk records, each
  measured rather than assumed. (i) **Narrowing the token is not a fix.** The
  whole-word form is satisfiable (2 hits, not 15) but still wrong: `:6`'s "not
  its review-gating mode switch - ever" is a still-TRUE claim, and a criterion
  that reds on it steers the implementer into the true-clause deletion R5 and
  Step 4's whole premise exist to prevent. The scope is what was wrong, and the
  token narrowing is a secondary refinement, not the remedy. (ii) **Narrowing
  the scope opens a relocation escape, so a scoped check needs a fixed-phrase
  file-wide companion.** A `deny()`-scoped check passes if the absolute is moved
  to the comment line above `deny()` — verified as a live mutant. The companion
  arm greps a *fixed false phrase* ("any agent identity, ever"), which is safe
  file-wide precisely because the bare substring never was. (iii) **A scoped
  extraction is a new vacuity surface.** Rename `deny()` and the span is empty;
  drop its closing `}` and the span silently runs to EOF, restoring the original
  bug. Both are red only because (a)'s three guards are asserted *before* the
  substantive arms. The same "a vacuous case is worse than a missing one"
  principle `hcb-regcheck` records applies to a criterion's own scoping
  machinery, not just to its mutants. **Generalization for later units on this
  surface:** when a criterion's prose names a region and its check names a file,
  the check is wrong until proven otherwise — and proving it means running it
  against the tree plus a correct-edit mutant, which is how both of C4.2's
  defects (the unsatisfiable half and the vacuous half) surfaced together.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every harness capability this design
  rests on is cited as documented or listed as undocumented-and-routed-around
  (U1, U2, U2b, U3, U4, U5); `AskUserQuestion`'s undocumented `tool_response`
  shape is a stated disqualifier rather than an assumption. The one place a
  residual could have been *assumed* benign — U1 against Set B — is instead a
  hard precondition on measurement (R10, C5.5), which is P1 applied rather than
  cited.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  mirror and `fileHashes` are regenerated by `node bin/cli.js --update` (C6.1),
  never hand-edited.
- P3 "Version-stamp discipline": **deviation — justified.** P3 binds
  `agents/*.md` and `templates/`; `hooks/scripts/version-stamp-check.sh:62,91`
  matches exactly those two globs, and `hooks/scripts/harness-integrity-gate.sh`
  carries no version-stamp comment (`grep -c 'antislop v'` → 0). `--update`
  propagates `.claude/hooks/scripts/**` by **content hash**, not version
  (`tests/validate.sh:315`), so no bump is mechanically required. A plugin
  version bump plus CHANGELOG entry is still specified in C6.2 as the repo's
  norm for a shipped behaviour change — as a norm, not as P3 compliance.
- P5 "`tests/validate.sh` is the merge gate": satisfied — C6.1.

---

## Steps

> **Ordering.** Step 5 (OQ3's operator change **and** C5.5's U1 measurement)
> must land **before** Step 1, twice over: without C5.1 the branch cannot be
> observed working here, and without C5.5 **Set B's half must not ship at all**
> (R10). Step 7 should land with or before Step 1's Set B half — it is what
> makes a Set B approval auditable after the fact (U5, R11). Steps 1→2→3 are one
> code unit's worth of sequence; Step 4 depends on 1–3 having settled the exact
> shipped wording; Step 6 is independent and may land any time.

### Step 1 — the human-confirmation branch (OQ1, OQ2, OQ4)

**Affected files:** `hooks/scripts/harness-integrity-gate.sh` (edit via `Bash`
per R3), `.claude/hooks/scripts/harness-integrity-gate.sh` (regenerated),
`.claude/persona-config.json`'s `fileHashes` (regenerated).

On the `Write`/`Edit` branch only, and only when `subject` exact-matches a Set A
persona-selection-config literal (`$persona_cfg`) **or a Set B literal**,
consult two harness-constructed payload fields before denying. The allowlist is
**two-tier**: Set B excludes `acceptEdits` (U2b — a silent auto-approve there
costs the gate itself, and excluding it is exactly today's verdict, so the
exclusion is free).

```
ask_allowed() {
  # $1 = matched set (A|B). FROZEN two-tier allowlist, never a denylist.
  # An absent, empty, or unrecognised permission_mode denies, as does any
  # mode added later by Claude Code, for BOTH sets.
  case "$permission_mode" in
    default|plan|auto) ;;
    acceptEdits)  [ "$1" = A ] || return 1 ;;   # Set B: deny. U2b / R10.
    *) return 1 ;;
  esac
  # agent_id is documented present ONLY inside a subagent. Restricting, not
  # exempting: subagents keep today's deny for both sets (U3, R2, R3).
  [ -z "$agent_id" ]
}
```

On success emit, on stdout, exit 0:

```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse",
 "permissionDecision":"ask",
 "permissionDecisionReason":"<one of TWO fixed literals — no interpolation>"}}
```

**Two frozen reason literals, selected by matched set — never one constructed
string.** Set A's states the rule and the sanctioned route. Set B's must
additionally state what approval costs: that this write targets the gate's own
registration surface and can disable every future prompt from this gate,
including this one. That sentence is the only additional safeguard beyond "a
human must approve" that is actually achievable at the prompt, and it is why
Set B is not a mechanical clone.

Append one `audit_append` line recording `asked` **and the matched set**
(`set=A` / `set=B`), matching `deny()`'s existing `set=` field. Otherwise fall
through to today's `deny A` / `deny B`, byte-unchanged. Every other case — the
four logs, the `.seal` sidecars, the whole `Bash` branch — is untouched.

**Set B gains a fourth literal (OQ5 (a), operator 2026-09-23):** add
`.claude/hooks/scripts/harness-integrity-gate.sh` — the gate's mirror, and the
copy that actually *executes* in a standalone (non-plugin) install — to the same
`case` as the other three Set B literals (R12). It is one line in the existing
`case` and it is guarded by C1.11. Two things must stay true of it, both asserted:
it takes **Set B's** allowlist (so `acceptEdits` denies), and it does **not**
join the `Bash` branch, exactly like the other three.

**Acceptance criteria**

```sh
# C1.1  the branch exists and fires, for BOTH sets: Write/Edit to the
#       persona-selection config (Set A) and to EACH of the 4 Set B literals,
#       with permission_mode in that set's allowlist and no agent_id -> exit 0
#       AND stdout parses as JSON whose .hookSpecificOutput.permissionDecision
#       is exactly "ask". Asserted for BOTH tool_name values. 5 subjects x 2
#       tool_name = 10 ask cases minimum.
bash tests/harness-integrity-gate.test.sh

# C1.2  FROZEN TWO-TIER ALLOWLIST, exhaustive over the documented 6-value set
#       plus the three degenerate spellings, asserted SEPARATELY PER SET.
#       Set A — exactly 4 ask, exactly 5 deny:
#         default|plan|acceptEdits|auto        -> ask   (exit 0 + ask JSON)
#         dontAsk|bypassPermissions            -> deny  (exit 2 + stderr)
#         absent key | ""  | "someFutureMode"  -> deny  (exit 2 + stderr)
#       Set B — exactly 3 ask, exactly 6 deny (acceptEdits moves to deny):
#         default|plan|auto                    -> ask
#         acceptEdits                          -> deny  [U2b — today's verdict]
#         dontAsk|bypassPermissions            -> deny
#         absent key | ""  | "someFutureMode"  -> deny
#       Counts asserted as numbers per set, so adding a mode, or quietly
#       levelling the two tiers, is a red test rather than a silent widening.

# C1.3  MUTATION PROOF, recorded in the PASS marker. TWO mutants, each with its
#       own non-empty kill set:
#   (a) replacing the frozen `case` with an unconditional pass must flip Set A's
#       5 deny rows AND Set B's 6 deny rows to ask;
#   (b) TIER-COLLAPSE: changing the `acceptEdits` arm to allow both sets must
#       flip exactly the Set B acceptEdits row and NOTHING else. This is the
#       specific regression a later "simplification" would introduce (R1/R10),
#       and mutant (a) does not catch it on its own.

# C1.4  SUBAGENT FAIL-CLOSED: identical payloads plus a non-empty agent_id ->
#       exit 2, for every allowlisted mode of BOTH sets (4 for A, 3 for B) and
#       for all 5 subjects. Mutation control: deleting the agent_id test must
#       flip all of them to ask. Phrase every assertion message as "no ask from
#       a subagent", never "the main session is exempt" (lens-2, R5).

# C1.5  THE NON-REPUDIATION INVARIANT — the gate can never auto-approve.
#       No permission-decision `allow` appears anywhere in the gate source:
test "$(grep -cE '"permissionDecision"[[:space:]]*:[[:space:]]*"allow"|permissionDecision.*allow' \
        hooks/scripts/harness-integrity-gate.sh)" = 0

# C1.6  THE REASON STRINGS ARE FIXED LITERALS — the structural replacement for
#       fable's "verify the question was shaped as an authorization prompt".
#       Now TWO literals, and all three halves are asserted:
#   (a) exactly 2 permissionDecisionReason literals exist in the source, no more
#       (a third would mean a constructed string crept in);
#   (b) NEITHER contains `$`, a backtick, or `$(` — no agent-controlled text can
#       reach the human's prompt;
#   (c) the Set B literal states the self-disablement cost: it names the gate's
#       registration surface AND says approval can disable future prompts from
#       this gate. Asserted as substring presence against a fixture string held
#       in the suite, so rewording the prompt into something anodyne is red.
#       (c) alone is satisfiable by a literal that says nothing true; (a)+(b)
#       alone permit a Set B prompt indistinguishable from Set A's. All three.

# C1.7  SCOPE GUARDS — the branch is exactly five paths wide. All still exit 2
#       under an allowlisted mode with no agent_id (baseline: exit 2 today):
#   - Write/Edit to each of the 4 audit logs           -> exit 2   [OQ1]
#   - Write/Edit to each of the 4 `.seal` sidecars     -> exit 2   [OQ1]
#   - Bash to each of the 4 Set B literals             -> exit 0   [ADR-0025,
#         unchanged: Set B is absent from the Bash branch and stays absent]
#   - Bash `printf x > <the config path>`              -> exit 2
#   - Bash `: > .claude/review-audit.log`              -> exit 2
#       Note the Set B Bash row asserts exit 0 deliberately. It is today's
#       ratified behaviour (Context, point 1) and the asymmetry mutation control
#       in C3.4 already fails if a later unit "fixes" it.

# C1.8  CONFIGLESS PRESERVED. The branch reads only the two payload fields and
#       nothing on disk:
#   - the ask case still returns ask with NO .claude/ directory present at all
#   - the ask case returns ask UNCHANGED with a planted file whose content
#     claims a human already approved (proves no on-disk artifact is consulted)
test "$(grep -cF 'persona-config.json' hooks/scripts/harness-integrity-gate.sh)" = 0
test "$(grep -cF 'reviewGating' hooks/scripts/harness-integrity-gate.sh)" = 0
#       (C2.2 of the source spec, re-asserted: the split-spelling discipline and
#        the reviewGating exemption must both survive this edit.)

# C1.9  HOT PATH UNCHANGED. The raw literal `case` still precedes any subshell,
#       jq, or per-word loop on the Bash branch — the existing line-number
#       ordering assertion (source-spec C2.3) still passes. The new branch adds
#       no work to the Bash path.

# C1.10 the existing suite passes in full, unmodified cases included:
bash tests/harness-integrity-gate.test.sh

# C1.11 THE MIRROR IS THE FOURTH SET B LITERAL (OQ5 (a)). Write/Edit to
#       `.claude/hooks/scripts/harness-integrity-gate.sh`:
#   - ask, under each of Set B's 3 allowlisted modes, agent_id absent
#   - deny under acceptEdits (it is Set B, not Set A — the tier matters here
#     and C1.3(b)'s tier-collapse mutant must kill this row too)
#   - deny under a non-empty agent_id
#   - the Set B reason literal, not Set A's (C1.6(c) applies to it)
#   Baseline being changed: this path is exit 0 on Write/Edit at d807630 —
#   it matches no Set B literal today. Assert the before/after explicitly so
#   the new coverage is visible rather than inferred.

# C1.12 THE MIRROR DOES NOT JOIN THE BASH BRANCH. Bash naming that path -> exit
#       0, same as the other 3 Set B literals (C1.7). The path contains
#       `.claude`, so it reaches set_a_mentioned()'s per-chunk normalize
#       fallback rather than short-circuiting at the `*) return 1` arm — true
#       of `.claude/settings.json` too, and of no other Set B literal. Both are
#       asserted, since "falls through the cheap arm" and "falls through the
#       expensive arm" are different code paths to the same exit 0.
```

### Step 2 — the completion audit record

**Affected files:** as Step 1, plus `hooks/hooks.json`.

Register the same script on `PostToolUse (Write|Edit)` and branch on
`hook_event_name` **as the first thing the script does** — without this the
`PostToolUse` payload (no `.tool_input.command`) would fall through to the
`Write`/`Edit` deny path and block on success. On `PostToolUse` with `subject`
exact-matching **any Set A or Set B literal that the branch can `ask` on**,
append one `audit_append` line recording that the write completed, carrying the
same `set=A`/`set=B` field; exit 0 in every other `PostToolUse` case, touching
nothing.

Rationale (carried into the header, not just here): **no hook event fires when a
human approves an interactive permission prompt** — confirmed documented gap.
`PostToolUse` *"runs immediately after a tool completes successfully"*, so its
firing is the only available evidence the human said yes. A `PreToolUse` `asked`
line plus a `PostToolUse` `completed` line is the pair that keeps
`docs/trust-model.md` row 11 verifiable.

**The pairing is sound for Set A and NOT for Set B (U5), and the difference must
be written down rather than smoothed over.** A Set B write can plausibly suppress
its own completion record: removing the registration from `hooks/hooks.json`, or
no-opping `harness-integrity-gate.sh`, may stop the very `PostToolUse` invocation
that would have logged it. So for Set B, `asked` with no `completed` means
*either* denied *or* approved-and-self-disabled — opposite outcomes. Claiming the
log distinguishes them would be precisely R5's over-claim failure mode. The
reconciler lives outside the log: **Step 7's registration-presence assertion**
turns "is the gate still armed?" into a merge-gate question, and `git log` on the
surface answers "who changed it". C2.4 asserts the Set A pairing as a count and
asserts the Set B case as *ambiguous-by-design*, so a later unit cannot quietly
promote it.

Extending this script rather than adding a sibling is deliberate: a new
`hooks/scripts/*.sh` would require a new `docs/trust-model.md` row for the
bijection test (R7), and Set A's literals would then live in two files.

**Acceptance criteria**

```sh
# C2.1  registered on the third matcher, alongside the existing three commands:
test "$(jq '[.hooks.PostToolUse[] | select(.matcher=="Edit|Write") | .hooks[]
             | select(.command|test("harness-integrity-gate"))] | length' hooks/hooks.json)" = 1
test "$(jq '[.hooks.PostToolUse[] | select(.matcher=="Edit|Write") | .hooks[]] | length' hooks/hooks.json)" = 4

# C2.2  REGRESSION GUARD, and the reason this step is not optional: a
#       PostToolUse payload for a Write to ANY path must exit 0. Assert
#       explicitly for the persona-selection config, one audit log, EACH of the
#       4 Set B literals, and one ordinary source file. Mutation control:
#       removing the hook_event_name branch must make all but the last exit 2 —
#       i.e. the gate would block its own successful writes, and under OQ4 it
#       would block every maintenance edit to itself.

# C2.3  the completion line lands in .claude/review-audit.log, is exactly ONE
#       line, carries the correct set= field for Set A and Set B subjects, and
#       survives a file_path containing a newline (the gh418 `tr '\n\r'`
#       flattening idiom, re-asserted on the new call site).

# C2.4  PAIRING, asserted DIFFERENTLY PER SET — this is where U5 is pinned:
#   (a) Set A: a PreToolUse ask followed by a PostToolUse for the same path
#       produces exactly 2 new audit lines; a PreToolUse deny produces exactly
#       1. "Asked but never completed" is readable as a denial.
#   (b) Set B: the same two-line pairing is asserted for the case where the
#       PostToolUse hook DOES still fire — but the suite must ALSO carry a case
#       proving the one-line shape is reachable without a denial, and the
#       trust-model/ADR wording asserted by C4.x must not claim the Set B pair
#       distinguishes denial from approval. Mechanically: assert that no
#       artifact in this repo makes that claim (fixed file list, per R5).

# C2.5  the gate remains exempt from reviewGating and configless (C1.8 re-run).
```

### Step 3 — test coverage and the mutation proofs

**Affected files:** `tests/harness-integrity-gate.test.sh`.

The existing `run()` discards stdout (`>/dev/null`, `:32`) and `check()` knows
only `allowed`/`blocked` (`:36-44`). Both need extending, not replacing: capture
stdout to a file alongside `$errf`, and add an `ask` verdict asserting exit 0 **and**
a stdout body that parses as JSON **and** whose `permissionDecision` is exactly
`ask`. Exit 0 alone is not sufficient — an `allowed` result would pass a weaker
check, and `allowed` is precisely the outcome this gate must never produce.

**Acceptance criteria**

```sh
# C3.1  helper shape: `ask_case` asserts all three conditions above, and takes
#       the expected SET so the two reason literals are not interchangeable.
#       Proven non-vacuous by a deliberately-wrong fixture in the suite's own
#       self-test, or by the C1.3 mutant.
# C3.2  every criterion in Steps 1, 2 and 7 is realised as at least one case.
# C3.3  REWRITTEN 2026-09-24 (see the amendment note at the head of this doc and
#       R14). The FOUR mutation controls (C1.3(a) allowlist, C1.3(b)
#       tier-collapse, C1.4 agent_id, C2.2 hook_event_name) are compared in ONE
#       declared cell space against a FROZEN relation table. Blanket pairwise
#       disjointness is NOT the requirement and never was satisfiable: C1.3(b)'s
#       kill set is contained in C1.3(a)'s by construction (R14).
#   (a) CELL SPACE, declared once as a literal list in the test and used to drive
#       all four mutants AND the shipped gate. A cell is the tuple
#         (hook_event_name, tool_name, subject, permission_mode, agent_id-state)
#       The subject list is the UNION of the subject lists the four controls
#       already probe, plus one ordinary non-Set-A/B file as a control; the mode
#       list is C1.2's 9 documented spellings; agent_id-state is {absent,
#       non-empty}. A cell's VERDICT under a gate is exactly one of ask / deny /
#       allowed, derived as C3.1 derives it (exit code AND stdout
#       permissionDecision - never exit code alone). Cell c is KILLED by mutant M
#       iff verdict_M(c) != verdict_shipped(c). Enumerate the space once; do not
#       let each control define its own private accounting, which is what made
#       the old C3.3 unanswerable.
#   (b) NON-EMPTY: all four kill sets are non-empty. Counts recorded in the PASS
#       marker as numbers, stating the cell space's own size alongside them so a
#       later reader can tell a count from a coverage claim.
#   (c) DISTINCT: no two of the four kill sets are equal. A control whose kill set
#       merely duplicates another's is not a second control.
#   (d) THE FROZEN RELATION TABLE - a literal in the test, one row per unordered
#       pair, asserted for all SIX pairs. The expected relation is a hardcoded
#       literal; DERIVING it from the measured sets reproduces R11's exact defect
#       (an expectation computed from the thing under test) and is a FAIL:
#         C1.3(a) x C1.3(b)  NESTED   K_b is a PROPER SUBSET of K_a, and K_b is
#                                     exactly the Set B x acceptEdits x
#                                     agent_id-absent cells - no Set A cell, no
#                                     other Set B mode. Both halves asserted.
#         C1.3(a) x C1.4     DISJOINT K_a is agent_id-absent only, K_id is
#                                     agent_id-present only. This is the pair the
#                                     over-broad mutant violated (R14).
#         C1.3(b) x C1.4     DISJOINT same axis separation.
#         C1.3(a) x C2.2     DISJOINT different hook_event_name.
#         C1.3(b) x C2.2     DISJOINT different hook_event_name.
#         C1.4    x C2.2     DISJOINT different hook_event_name.
#       What the NESTED row proves is what the old disjointness clause was
#       reaching for and could not express: the Set B acceptEdits deny is
#       PRODUCED BY the frozen case, so neutering the whole case necessarily
#       flips it too. Move that deny to a check outside the case and the
#       containment breaks - which is the regression R1/R10 name.
#   (e) TIER ISOLATION, stated separately because (d)'s NESTED row alone does not
#       give it: K_b intersected with the Set A cells is EMPTY, and Set A's own
#       ask/deny split is bit-identical under the tier-collapse mutant and under
#       the shipped gate. This, not disjointness, is what proves the two-tier
#       allowlist is tested as two tiers rather than as one with extra rows.
# C3.4  the pre-existing mutation controls still hold: deleting the Write/Edit
#       branch and deleting the Bash branch each kill a disjoint non-empty set;
#       adding Set B to the Bash branch still makes the two Bash guards fail.
#       THIS SURVIVES OQ4 UNCHANGED and is the guard that stops an implementer
#       from reading "Set B is in scope" as "Set B joins the Bash branch".
# C3.5  GUARD — the family table and its reachability preconditions are
#       untouched; the brace-collapse fixpoint property test still passes.
# C3.6  GUARD — the note-parity block (`:363-383`) still passes: no
#       unbounded-universal phrasing in EITHER the gate source or
#       .claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md,
#       and family-slug parity holds in both directions. New prose from Steps 1,
#       2 and 4 must be written to survive this.
bash tests/harness-integrity-gate.test.sh
```

### Step 4 — prose reconciliation: nothing may still say "no exemption, ever"

**Affected files** (enumerated by `git grep -n "no grant branch\|no identity
exemption\|no exemption\|any agent identity, ever"` at `d807630`, filtered to
this gate):

| # | File | What changes |
|---|---|---|
| 1 | `hooks/scripts/harness-integrity-gate.sh:2-9` | Header. **Split, do not delete** (lens-2 finding): *"No grant branch, no identity exemption"* stays TRUE and stays; add the human-confirmation branch as a bounded, separate sentence naming **both tiers** (Set A's 4 modes, Set B's 3), the `agent_id` condition phrased as *"never emits `ask` from a subagent"* (never *"the main session is exempt"* — lens-2 second finding), the five paths, and the never-`allow` invariant. |
| 2 | `hooks/scripts/harness-integrity-gate.sh:11-36` | **The Set A / Set B block itself.** Set B is currently described as *"denied on Write/Edit ONLY"*, which becomes false for 3 of the 4 allowlisted-mode cases. Amend to *"denied on Write/Edit, except the human-confirmation branch (see above)"*. The ADR-0025 paragraph at `:28-36` stays **byte-unchanged** — Set B's absence from the `Bash` branch is untouched and C3.4 still guards it. |
| 3 | `hooks/scripts/harness-integrity-gate.sh:62` | Deny message. *"may not be written directly by any agent identity, ever"* and *"no exemption"* become FALSE for five paths. Per `docs/plans/2026-08-25-harness-trust-gaps.md` Step 5 / ADR-0025 disclosure hygiene, the message states the rule, not the technique. |
| 4 | `.claude/hooks/scripts/harness-integrity-gate.sh` | Mirror — regenerated, never hand-edited. |
| 5 | `CONTEXT.md:234-247` (`Set A / Set B`) | Amend; add the **human-confirmation branch** entry (lens 3) with `_Avoid_: escape hatch, grant branch`. The Set A / Set B entry must now say the two sets differ in their **allowlist and prompt wording**, not just in Bash coverage, and must list Set B's **four** literals (OQ5). `scribe` owns this file. **Corrected 2026-09-23:** the original row also directed an amendment at `:322`. Re-read at that revision, `:322` is the `foreign-claude-dir` [[documented residual]] entry, whose claim is that Set A is *confined to the repo's own `.claude/` directory, not `~/.claude/`* — a **directory-confinement** claim, not a deny-absoluteness claim, and the human-confirmation branch does not touch it. **Do not amend `:322`**; amending it would add an unbounded claim to a file C4.3b already constrains. |
| 6 | `docs/trust-model.md` row 11 | The claim *"the harness is armed"* is now conditional for five paths, and — the honest part — the row's subject is the gate's *own* registration surface, so the conditionality is self-referential. Amend the Notes cell to name the branch, the two-tier allowlist, the subagent exclusion, and **U5's ambiguity** (a Set B `asked` with no `completed` does not distinguish denial from approval). Do **not** convert to `self-reported` (R7); Step 7 is what keeps it mechanical. |
| 7 | `docs/plans/2026-08-25-harness-trust-gaps.md:976` | FINALIZED historical plan — **append a dated amendment note under Step 2, do not rewrite it.** Same append-only convention the DECISION-channel plan used for its own partial supersession (`:R-B`, *"Partly superseded, 2026-08-12"*). The note must cover **both** the Set A claim at `:976` and Step 2's separate ruling that blocking `.claude/settings.json` *"blocks legitimate permission edits too … that is the intended trade"* — OQ4 partially reverses that trade, and leaving it unannotated would be the same stale-absolute defect one level up. |
| 8 | `docs/plans/2026-08-25-harness-ceremony-consolidation.md:900` | Quotes Set A's *"no grant branch, no identity exemption"* — dated one-line amendment note. |
| 9 | `docs/plans/2026-09-09-fable-gate-audit-remediation.md:119,122` | Two *"no exemption"* assertions — dated one-line amendment note. |
| 10 | `.claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md:10,18,21` | Mechanically coupled to the suite (C3.6). Must be updated in the same commit. |
| 11 | `tests/protected-paths-coverage.test.js:14` | The exemption rationale *"Self-protecting instead: its own Write/Edit …"* is now one branch weaker. Amend the comment so it does not read as an unconditional self-protection claim (R11). |
| 12 | `docs/adr/00NN-*.md` | **New ADR.** Next free number — `0032` at authoring time (verified: `docs/adr/` tops out at `0031`); **re-derive at execution time**, never backfill the `0007` hole. |
| 13 | `docs/plans/2026-08-11-microworld-silo.md:300,559` | **Added 2026-09-23** (see *Sweep closure*, below). Both lines describe **Set A's persona-selection config**: *"refuses writes from every agent identity with no exemption"* (`:300`) and *"refuses direct writes from every agent identity, with no exemption"* (`:559`). The predicate *"refuses writes"* becomes **false** for the main session under an allowlisted mode. The words *"no exemption"* stay **TRUE** (lens-2 — the branch exempts no identity) and **must not be deleted**, exactly the split row 1 makes for the header. FINALIZED historical plan → **two dated amendment notes, one per hit**; they are 259 lines apart, so C4.1's within-5-lines rule needs one at each site, not one for the file. The adjacent claim that `node bin/cli.js --update --force-render` is *"the only sanctioned route"* stays true and **must not be annotated** — `--update` writes through `fs` and is invisible to this gate by construction. |

#### Sweep closure — every hit is classified, and the classification is closed

*Added 2026-09-23, closing a mid-flight gap `task-master` found while slicing
this step. The defect was structural, not clerical: the table above was
enumerated by running the authoring grep and then **filtering to this gate**,
while C4.1 admitted only two escapes — (a) the hit is about
`human-decision-gate.sh`, or (b) it carries a dated amendment note. Any hit that
is neither about that one sibling gate nor amended had no bucket, so a literal
implementation of C4.1 flags it. Three such hits exist. The fix is to make the
escape set as wide as the filter that built the table, and then to **close** it —
see R13.*

**The classification is keyed on FILE, not on line, and is FILE-EXHAUSTIVE.**
Measured at the amendment tree: the sweep returns **23 hits across 13 tracked
files** (`git grep -c` per file: 3, 2, 3, 1, 1, 2, 2, 1, 1, 1, 2, 2, 2). Line
numbers are deliberately *not* the key — the Cat 2 amendment notes shift them by
construction, so a line-keyed table would go red on its own remedy. Hit *counts*
are deliberately not asserted either, for the same reason: Step 4's own prose
edits change several of them (C4.3 requires the header to keep saying *"no grant
branch"*). What is asserted is set equality over files, plus a per-hit rule
inside Cat 2 only.

- **Cat 1 — not about this gate.** No action. Four files, all describing
  `human-decision-gate.sh`, whose absoluteness is untouched:
  `docs/adr/0030-…` (1 hit), `docs/plans/2026-08-11-human-decision-channel.md`
  (2), `CONTEXT.md` (1, at `:2185`), `tests/human-decision-gate.test.sh` (2).
  **`CONTEXT.md` is Cat 1 for the sweep's purposes and is still amended by row
  5** — those are not in conflict: row 5's target (`:234-247`, the *Set A / Set
  B* entry) contains none of the swept phrases and is therefore not a hit. A
  file may be reached by this step for reasons the sweep does not see.
- **Cat 2 — about this gate and made false by this change.** Seven files.
  Corrected in place — `hooks/scripts/harness-integrity-gate.sh` (rows 1–3),
  its mirror (row 4), `.claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md`
  (row 10) — or annotated with a dated amendment note:
  `docs/plans/2026-08-25-harness-trust-gaps.md` (row 7),
  `docs/plans/2026-08-25-harness-ceremony-consolidation.md` (row 8),
  `docs/plans/2026-09-09-fable-gate-audit-remediation.md` (row 9),
  `docs/plans/2026-08-11-microworld-silo.md` (row 13). This is the **only**
  category with a per-hit rule (C4.1(b)).
- **Cat 3 — about this gate and STILL LITERALLY TRUE after this change.** No
  action, and **no note** — annotating a true sentence would imply it had
  changed. Two files:
  - `docs/plans/2026-09-02-blocked-marker-scoping-gh425.md` (1 hit, `:621`):
    *"the audit log is Set A with no grant branch — not even for the reviewer"*.
    True twice over — its subject is an **audit log**, which keeps today's
    unconditional deny per OQ1, so no branch reaches it at all; and *"no grant
    branch"* stays true even for the five branched paths, per the lens-2 finding
    row 1 already turns on.
  - **This plan document itself**, once committed (22 hits at the amendment
    tree). It is about this gate and it describes the post-change state
    correctly; its hits are quotations of the prose Cat 2 is reconciling. Listed
    explicitly because it is otherwise an invisible trap: the file is untracked
    today, so the sweep does not see it, and it becomes a 14th hit-bearing file
    the moment the implementing unit commits — turning C4.1(a) red on the spec
    that defines C4.1. The same applies to any follow-up plan doc in this
    family, which is why Cat 3 is a category and not a two-item allowlist.

  **Cat 3 did not exist before 2026-09-23** and its absence is what made the
  `gh425` hit unresolvable.
- **Cat 4 — EXCLUDED FILE.** Exactly one file, `CHANGELOG.md`, excluded
  **whole-file**: its three hits split across the gate-introduction entry
  (`:102`, the stale one) and two `human-decision-gate.sh` entries
  (`:664,666`, which would be Cat 1), and the exclusion makes that split moot
  rather than requiring the suite to discriminate entries within a changelog.
  The exclusion is a ruling with a reason, not a convenience — see immediately
  below.

**The `CHANGELOG.md` ruling (self-resolved 2026-09-23; cheaply reversible).**
`CHANGELOG.md:102` is the release entry for commit `2e608dc`, the commit that
introduced this gate. It is about this gate and it is not Cat 3, so it would
otherwise be Cat 2. It is nonetheless **left byte-unchanged and gets no
amendment note**, because
[ADR-0029](docs/adr/0029-microworld-silo-namespaced-directories.md)'s
*Consequences* already rules on exactly this surface: *"Historical citations are
not rewritten. Existing entries in `CHANGELOG.md` … are left exactly as written
— rewriting them would make their commit SHAs disagree with the paths they
describe and destroy the audit trail … must be read as 'the path as of that
entry's date'."* That reasoning transfers from path citations to behaviour
descriptions **more** strongly, not less: the entry is the record of what
`2e608dc` shipped, and `2e608dc` did hardcode an unconditional deny. A
within-5-lines note would additionally interleave a 2026-09 correction into a
`0.31.x`-era section, destroying the one property a CHANGELOG has. A CHANGELOG's
own built-in correction mechanism is the *next* entry, which Step 6 (C6.2)
already adds.

Two things keep this from being a loophole:

1. **C4.1's headline claim is narrowed** to match what it actually checks. The
   old wording — *"no stale absolute remains **anywhere** that describes this
   gate"* — would become an over-claim the moment any file is excluded, which is
   R5's own failure class one level up. The rewritten C4.1 claims closure over a
   classified hit set, not absence over the repo.
2. **The supersession is recorded, just not in the CHANGELOG.** Row 12's new ADR
   must state that entry `:102`'s *"hardcodes a deny"* description and its
   three-item Set B enumeration are narrowed by this change, and that the entry
   is left as written per ADR-0029. C4.9 asserts it. This keeps the fix entirely
   inside this step — **no criterion here depends on Step 6's CHANGELOG entry**,
   so this unit stays independently dispatchable.

**Two premise corrections to the mid-flight report, because they change what the
remedy must say.** `task-master` described `CHANGELOG.md:102` as carrying *"two
of the four grepped absolutes"* plus a *"now-false"* claim that Set B is
*"checked on the Write/Edit branch only"*. Measured at `d807630`:

- The two grepped absolutes it carries — *"no grant branch, no identity
  exemption"* — **stay literally true**, for the same lens-2 reason row 1 keeps
  them in the gate's own header. They are not what makes the entry stale.
- *"checked on the Write/Edit branch only"* **also stays true**: Set B remains
  absent from the `Bash` branch (C1.7 asserts `exit 0` there deliberately, C3.4
  guards it, C4.3c freezes the ADR-0025 paragraph).
- What is actually stale is narrower: *"hardcodes a deny … on writes to Set A …
  and Set B"* (now `ask` for five paths in allowlisted main-session shapes), and
  the **three-item** Set B enumeration (four literals after OQ5). The ADR record
  required by C4.9 must name **those two**, not the absolutes.

`README.md` makes no claim about this gate (verified: zero `harness-integrity`
matches), so it is outside the classification entirely rather than a Cat 1
member. `harness-integrity-gate.sh:28-36` (the ADR-0025 Bash-asymmetry
paragraph) is untouched — see row 2.

**The ADR meets all three tests** — hard to reverse (a ratified trust-posture
property); surprising without context (a gate documented as absolute grows a
branch, and its *own registration surface* is inside that branch); a real
trade-off ((a) `AskUserQuestion` / (b) `ask` / (c) refuse, with `fable`'s prior
analysis on the other side). Its Decision must record: the per-call-consent vs
durable-artifact distinction; the four `AskUserQuestion` blockers; the scope rule
(*a legitimate agent-authored write exists*) that admits Set A and Set B and
excludes the audit logs; **why Set B is a narrower tier rather than a clone** —
the `acceptEdits` exclusion, the dedicated prompt literal, and the U1
precondition; why the `Bash` branch is excluded; and U1, U2, U2b, U3, U4, U5 as
residuals. R12 is recorded as **closed** by OQ5 (a), not as an accepted residual.

**Added 2026-09-23** — the ADR's Consequences must additionally carry the
`CHANGELOG.md` supersession record described under *Sweep closure*: that the
`CHANGELOG.md` entry introducing this gate describes an unconditional deny that
this change narrows for five paths, that its Set B enumeration predates OQ5's
fourth literal, and that the entry is deliberately left as written per
ADR-0029's historical-citation rule. C4.9 asserts this.

**Acceptance criteria**

```sh
# C4.1  SWEEP CLOSURE — REWRITTEN 2026-09-23 (see *Sweep closure* above; R13).
#       The claim is NOT "no stale absolute remains anywhere" — that would be an
#       over-claim relative to what any fixed-list check can verify, i.e. R5's
#       own failure class one level up. The claim is: the authoring sweep's hit
#       set is fully classified, and the classification is closed.
#
#       Re-run the authoring sweep, FILE-keyed (line numbers shift when the Cat 2
#       notes land; hit counts shift when Step 4's own prose edits land — neither
#       is asserted, or the criterion goes red on its own remedy):
#         git grep -l "no grant branch\|no identity exemption\|no exemption\|any agent identity, ever"
#       The suite holds a LITERAL table mapping each hit-bearing FILE to exactly
#       one of four categories (Cat 1 not-about-this-gate / Cat 2 made-false /
#       Cat 3 still-true / Cat 4 excluded-file). Assert all four:
#
#   (a) CLOSURE, BOTH DIRECTIONS, over FILES. The sweep's file set equals the
#       table's key set EXACTLY. An unlisted hit-bearing file is RED — this is
#       the specific assertion whose absence produced the three unclassified hits
#       found mid-flight. A listed file with ZERO hits is ALSO red, so the table
#       cannot rot into a stale allowlist. Baseline at the amendment tree: 13
#       tracked files, 23 hits; 14 files once this plan doc is committed (Cat 3).
#   (b) Cat 2 files ONLY: EVERY hit carries a dated amendment note within 5
#       lines, or the stale text is gone. Asserted per HIT — row 13's two hits
#       are 259 lines apart and one note cannot cover both.
#   (c) Cat 3 files: NO hit carries an amendment note (annotating a still-true
#       sentence would imply it changed), and the table records per file WHY it
#       is still true. Non-vacuity: this arm must have at least one member, so a
#       suite that silently drops Cat 3 is red rather than trivially green.
#   (d) Cat 4 is EXACTLY ONE FILE and it is CHANGELOG.md — asserted as a count
#       of 1 plus string equality on the name. A second excluded file added later
#       is red: the exclusion is a ruling with a recorded reason (ADR-0029 +
#       C4.9), never a way to retire an inconvenient hit.
#
#       Cat 1 is asserted by table membership only. "Is this sentence about
#       human-decision-gate.sh?" is not grep-decidable in general, which is why
#       the mechanism is a reviewed literal table plus (a)'s closure check, and
#       not a cleverer pattern. NOTE the asymmetry this creates and do not
#       "tidy" it: a file can be Cat 1 for the sweep and still be edited by this
#       step for reasons the sweep cannot see (CONTEXT.md, row 5).
# C4.2  REWRITTEN 2026-09-24 (targeted; see R15, CHK28–CHK30). The prose intent
#       is unchanged and was always right — the DENY MESSAGE must stop claiming
#       the write "may not be written directly by any agent identity, ever" and
#       stop saying "no exemption", while still naming the sanctioned route. What
#       changed is the mechanism, which mistranslated that intent into a
#       FILE-WIDE substring count and was therefore UNSATISFIABLE: three other
#       mandatory requirements of this same step each guarantee a file-wide
#       "ever" hit — C4.3c freezes the ADR-0025 paragraph containing "Nearly
#       every command", C4.3b requires adding "never emits `ask` from a
#       subagent", and Do-NOT-touch pins reason_b's "every future prompt".
#       Measured at `094a17e`: file-wide substring count is 15, not 0.
#
#       Narrowing the substring to the WHOLE WORD "ever" is necessary but NOT
#       sufficient. Measured at `094a17e` the file carries exactly two whole-word
#       hits, and one of them is `:6`'s "not its review-gating mode switch -
#       ever" — a still-TRUE claim (the gate reads nothing from the config) of
#       exactly the same lens-2 kind as `:8-9`'s surviving "no grant branch".
#       Failing on it would push the implementer into the true-clause deletion
#       this step exists to prevent. So the scope is the deny message, and the
#       old single (a)/(b) split is superseded by four lettered parts:
#
#   (a) NON-VACUITY OF THE EXTRACTION, asserted FIRST. `deny()`'s body is
#       extracted once; the span must be non-empty, must end on the closing `}`
#       (so a missing terminator cannot silently widen it back to EOF), and must
#       carry EXACTLY ONE `BLOCKED:` line. This is the arm that keeps "satisfy it
#       by deleting the message" red, and it is why a scoped check is safe here:
#       a scoped grep that returns nothing is green for the wrong reason.
#   (b) the span contains no WHOLE-WORD "ever". Whole-word, per the `:6` finding
#       above; a comment inside `deny()` using "never" or "every" is not an
#       absoluteness claim and must not go red.
#   (c) FILE-WIDE, two FIXED PHRASES — scope deliberately NOT narrowed. Zero
#       "no exemption" (unchanged from the original; measured 1 today, the deny
#       message, and the header's "no identity exemption" does not match this
#       literal, so the TRUE clause survives). Plus, ADDED, zero "any agent
#       identity, ever" (measured 1 today, the deny message; 0 in the frozen
#       ADR-0025 span and 0 in `:1-9`). The added arm is what stops the absolute
#       being RELOCATED out of `deny()` into an adjacent comment and still
#       passing — narrowing (b)'s scope without it would open a fresh escape.
#       A fixed false phrase is safe file-wide; the substring "ever" never was.
#   (d) THE SPAN NAMES THE SANCTIONED ROUTE: `bin/cli.js`. STRENGTHENED, and the
#       implementer must ADD it. Two corrections behind that: the baseline deny
#       message names only `docs/plans/2026-08-25-harness-trust-gaps.md` Step 2 —
#       a provenance citation, not a route — so the original's "still names" was
#       inaccurate about the baseline; and the original's FILE-WIDE
#       `grep -qF 'bin/cli.js'` was VACUOUS, because the two frozen reason
#       literals (`:121-122`, Do-NOT-touch) already contain it, so the
#       anti-deletion half passed even for a deleted message — precisely the
#       failure its own prose said it prevented. Naming the route is
#       disclosure-hygiene-clean (ADR-0025 / trust-gaps Step 5): reason_a and
#       reason_b both name it, and a remedy is the rule, not the technique.
#
#       Satisfiability VERIFIED at `094a17e`, not assumed, against seven mutants
#       of a scratch copy — correct edit; message deleted; route omitted;
#       `deny()` renamed; a "never"/"every" comment added inside `deny()`; the
#       message reflowed across three physical lines; and the absolute relocated
#       to the line immediately above `deny()`. Verdicts: RED on the unedited
#       baseline and on all five defect mutants, GREEN on the correct edit and on
#       the reflow, identical under BOTH grep implementations this repo exposes
#       (`ugrep` inline, GNU `grep` inside `bash <script>`). Under the correct
#       edit the ADR-0025 span's sha256 is unchanged from `d807630`, so C4.2 and
#       C4.3c do not collide, and `:6`'s true clause survives untouched:
G=hooks/scripts/harness-integrity-gate.sh
DENY="$(awk '/^deny\(\) \{/{f=1} f{print; if (/^\}/) exit}' "$G")"
test -n "$DENY" || { echo "C4.2(a): deny() span not found"; exit 1; }
test "$(printf '%s\n' "$DENY" | tail -n1)" = '}' || { echo "C4.2(a): span unterminated"; exit 1; }
test "$(printf '%s\n' "$DENY" | grep -c 'BLOCKED:')" = 1 || { echo "C4.2(a): not exactly one BLOCKED: line"; exit 1; }
printf '%s\n' "$DENY" | grep -qw 'ever' && { echo "C4.2(b): whole-word 'ever' survives in the deny message"; exit 1; }
test "$(grep -cF 'any agent identity, ever' "$G")" = 0 || { echo "C4.2(c): the absolute was relocated, not retired"; exit 1; }
test "$(grep -cF 'no exemption' "$G")" = 0 || { echo "C4.2(c): 'no exemption' survives"; exit 1; }
printf '%s\n' "$DENY" | grep -qF 'bin/cli.js' || { echo "C4.2(d): deny message does not name the sanctioned route"; exit 1; }
echo "C4.2 OK"
# C4.3  the header still contains the literal "no grant branch" (the lens-2
#       TRUE clause survives the edit) AND contains the new branch's bounded
#       description naming BOTH tiers explicitly — Set A's 4 modes and Set B's
#       3. A header that names only "the allowlisted modes" without the per-set
#       split is an unbounded universal of exactly R5's class and fails.
# C4.3b THE SET B PROSE DOES NOT INVERT THE PROPERTY (lens-2, second finding):
#       neither the header, the ADR, CONTEXT.md, nor docs/trust-model.md
#       contains "exempt" within the same sentence as "main session" or
#       "orchestrator". Asserted over a fixed file list. The sanctioned phrasing
#       is "never emits ask from a subagent".
# C4.3c THE SET B BLOCK AT :11-36 no longer says Set B is denied on Write/Edit
#       without qualification, AND the ADR-0025 paragraph at :28-36 is
#       byte-identical to `d807630` (asserted by hashing that span). Both:
#       amending the first by deleting the second would silently drop the
#       ratified Bash-asymmetry rationale.
# C4.4  docs/trust-model.md row 11 is amended AND names U5's ambiguity AND the
#       bijection test passes with EXPECTED_SELF_REPORTED_COUNT still 10:
node --test tests/trust-model-bijection.test.js
# C4.5  the ADR exists, its number is one greater than the current highest under
#       docs/adr/, its Status line is `Accepted`, and CONTEXT.md links it.
# C4.6  the CONTEXT.md entry exists, carries the `_Avoid_` line, and its term is
#       the one the ADR and the gate header use — asserted as string equality
#       across the three, not by eye.
# C4.7  C3.6 still passes after every prose edit in this step.
# C4.8  NO ARTIFACT CLAIMS THE SET B AUDIT PAIR IS UNAMBIGUOUS (U5, C2.4(b)).
#       Over the same fixed file list as C4.3b, assert that any sentence pairing
#       "asked" with "completed" is either scoped to Set A or carries the
#       ambiguity qualifier. Fixed list, never an unbounded repo-wide claim.

# C4.9  THE CAT-4 EXCLUSION IS PAID FOR (added 2026-09-23). The new ADR's
#       Consequences records the CHANGELOG supersession, asserted as all three
#       halves — (a) alone is satisfiable by an ADR that merely name-drops the
#       file:
#   (a) it names CHANGELOG.md and cites ADR-0029's historical-citation rule as
#       the reason the entry is left as written;
#   (b) it names the TWO claims that actually go stale — the unconditional-deny
#       description, and the Set B enumeration predating OQ5's fourth literal.
#       NOT the "no grant branch / no identity exemption" absolutes, which stay
#       true (lens-2, row 1); an ADR asserting those went stale is WRONG and is
#       a FAIL, not a wording preference.
#   (c) it does NOT claim the CHANGELOG was corrected.
#       This criterion is what stops Cat 4 from being an unpriced hole, and it
#       depends on nothing outside this step — Step 6's CHANGELOG entry is not
#       referenced by any criterion here, so this unit stays independently
#       dispatchable.
```

### Step 5 — operator-side: make the prompt observable, and measure U1 (OQ3, OQ4)

**Affected files:** `.claude/settings.local.json` (operator config, not plugin
code); a new characterization record under `docs/`.

`.claude/settings.local.json`'s `permissions.allow` carries
`Edit(.claude/persona-config.json)` (verified present at `d807630`; the source
spec's F1 flagged it as a *"local aggravating factor"* in 2026-08). Whether a
hook's `ask` overrides an `allow` entry outside `auto` mode is **undocumented**
(U1). Removing the entry makes the question moot **for Set A here**.

**It does not make it moot for Set B, and that is why this step grew a
precondition.** `.claude/settings.local.json` is a member of no protected set
and is guarded by nothing, so an agent can add an entry for a Set B path at any
time (R10). Set A's exposure is one config with the gate still armed; Set B's is
the gate itself. So C5.5 measures U1 directly, and **Step 1's Set B half does
not ship until it comes back "`allow` does not override `ask`."** This step is
executable by ordinary `Edit`: `settings.local.json` is not `.claude/settings.json`
and is not in Set B.

Then record a live characterization: for each of the 6 documented
`permission_mode` values plus a `-p` headless run, what actually happened — the
prompt rendered / was auto-approved / the call was denied.

**Acceptance criteria**

```sh
# C5.1  jq over BOTH .claude/settings.local.json and .claude/settings.json:
#       zero permissions.allow entries matching the persona-selection config
#       (Set A) or ANY of the 4 Set B literals. Widened from Set A only, so a
#       later addition is caught rather than assumed absent (measured zero for
#       Set B at d807630 — a baseline, not a guarantee).
# C5.2  the characterization record exists and has one row per documented
#       permission_mode value (6) plus one headless row (7 total), each naming
#       the observed outcome and the date observed. Rows are recorded PER SET
#       where the two tiers differ, so acceptEdits carries both verdicts.
# C5.3  HONESTY GUARD — the record is labelled self-reported (it cannot be
#       re-derived by any test in this repo) and docs/trust-model.md does not
#       cite it as a mechanical check.
# C5.4  if the headless `default` row shows a silent auto-approve, R4 is not a
#       residual but a defect: `default` leaves the allowlist and this step
#       routes back to spec-master. Stated as a branch, so the outcome is
#       decided now rather than argued later.
# C5.5  U1 MEASURED DIRECTLY, and it is a SHIP GATE for Set B, not a note.
#       Procedure: with a temporary permissions.allow entry for a throwaway
#       path that the gate is made to treat as Set B in a scratch fixture,
#       observe whether the hook's `ask` still renders a prompt.
#         - "ask still prompts"  -> Set B's half of Step 1 ships. Record it.
#         - "allow silently wins" -> Set B's half DOES NOT SHIP; the step routes
#           back to spec-master, and the recorded finding is itself the reason.
#           Set A is unaffected either way (C5.1 removed its entry).
#       Recorded in the characterization record with the date observed. Same
#       decide-now-not-later branch shape as C5.4.
```

### Step 6 — close the workflow contradiction at its source

**Affected files:** `skills/install-antislop/SKILL.md` § 6.

Independent of the gate change and worth landing either way: § 6 must say what
an agent should do when its config write is prompted. Today it says neither that
nor what the sanctioned route is, which is why the screenshot's agent had
nowhere to go.

It must also state the one thing an ADAPT-session agent will otherwise get
wrong under OQ4: **a subagent still sees a hard deny** (U3). An
`install-antislop` run dispatched as a subagent gets exit 2 exactly as today,
and § 6 must say so rather than promising a prompt that will not appear.

**Acceptance criteria**

```sh
# C6.0  § 6 names the gate by script name, states the expected interaction (a
#       permission prompt, not a hard block) in the main session, AND states
#       that a subagent dispatch still hard-denies. Both halves: the first
#       alone documents a promise the gate does not keep for subagents.
# C6.1  mirror + hashes + exec bit + merge gate:
node bin/cli.js --update --check
bash tests/validate.sh
# C6.2  plugin version bumped and a CHANGELOG entry added (repo norm; NOT P3 —
#       see Constitution check).
# C6.3  the standalone-scaffold registration path carries the new PostToolUse
#       registration too:
node --test tests/cli-hook-propagation.test.js
```

### Step 7 — the registration-presence assertion (OQ4)

**Affected files:** `tests/harness-integrity-gate.test.sh` (new assertion
block). No production code.

**Why this exists, stated as the measured gap it is (R11):** nothing in this
repo currently checks that `harness-integrity-gate.sh` is registered at all.
`expectedRegistrations()` (`tests/cli-hook-propagation.test.js:147-159`) reads
`hooks/hooks.json` and *derives* its expectation from that same file, so
deleting the gate's registration shrinks the expectation in lockstep and the
suite stays green. `bin/harness-integrity.sh` verifies log seals, not
registrations. `protectedPaths` carries no `hooks`/`settings` entry.

This was tolerable while Set B was an unconditional deny on `Write`/`Edit`.
Under OQ4 it is not: a prompt a human approves is a safeguard only if something
afterwards can tell whether the gate survived, and it is also the only available
reconciler for U5's `asked`-without-`completed` ambiguity. One mechanism, both
jobs.

Assert, from a **fixed literal expectation table written into the test**, that
`hooks/hooks.json` registers `harness-integrity-gate.sh` on every event/matcher
pair the design depends on: `PreToolUse` × `Write|Edit`, `PreToolUse` × `Bash`,
and (after Step 2) `PostToolUse` × `Edit|Write`.

**Acceptance criteria**

```sh
# C7.1  the assertion exists and passes, and its expectation is a LITERAL table
#       in the test file — asserted by grepping the test source for the three
#       event/matcher pairs as literal strings.
# C7.2  NON-VACUITY, and this is the criterion that matters: deleting the gate's
#       PreToolUse Write|Edit registration from hooks/hooks.json must make the
#       new assertion RED. Run the mutant, record the result in the PASS marker.
#       An implementation that re-derives the expectation from hooks/hooks.json
#       survives this mutant and is a FAIL — it reproduces R11's exact defect.
#       Repeat the mutant for each of the three pairs; all three must be red.
# C7.3  the assertion is reached by the merge gate:
bash tests/validate.sh
# C7.4  SCOPE — Step 7 adds no production code and does not change any gate
#       verdict: `git diff --stat` for this step touches tests/ only.
```

---

## Open Questions

All five are **resolved** by the operator, 2026-09-23. Each entry records the
answer and points at the Clarifications line carrying its dated `Q … → A`.
Nothing below is awaiting a decision.

**OQ1 — RESOLVED 2026-09-23, operator: (a) config only.** Audit logs and `.seal`
sidecars stay at today's unconditional deny. Re-verified against OQ4's answer and
unaffected — see the Clarifications entry dated 2026-09-23 under *Functional
scope & success criteria*, and the scope rule in the Goal.

**OQ2 — RESOLVED 2026-09-23, operator: (a) `permissionDecision: "ask"`.** Not
`AskUserQuestion`. See the Clarifications entry under *User interaction flow*
and the four blockers in Context.

**OQ3 — RESOLVED 2026-09-23, operator: (a) remove the
`Edit(.claude/persona-config.json)` allow entry.** Executed by Step 5; C5.1 is
widened to cover Set B paths and both settings files. See the Clarifications
entry under *Technical constraints & tradeoffs*.

**OQ4 — RESOLVED 2026-09-23, operator: (b) yes, extend to Set B** — against the
recommended default. Reworked, not cloned: Set B excludes `acceptEdits`, carries
its own fixed prompt literal, is gated on C5.5's U1 measurement, and requires
Step 7. See *Set B is not a mechanical clone of Set A* in Context, R10–R12, and
the Clarifications entry under *Functional scope & success criteria*.

---

**OQ5 — RESOLVED 2026-09-23, operator: (a) yes.**
`.claude/hooks/scripts/harness-integrity-gate.sh` — the gate's mirror, and the
copy that actually executes in a standalone (non-plugin) install
(`bin/cli.js:1899-1905`) — becomes **Set B's fourth literal**. Implemented in
Step 1 (one line in the existing `case`), guarded by C1.11 (Write/Edit asks
under Set B's tier) and C1.12 (Bash still exits 0, like the other three). R12 is
closed rather than carried as a residual, and the ADR records it that way.

Cost is near-zero: the mirror must never be hand-edited anyway (R6, constitution
P2 — regenerate with `node bin/cli.js --update`), and `--update` writes it
through `fs`, which is invisible to this gate by construction. The added
friction therefore falls entirely on a write already prohibited by convention,
while closing the one install shape where the executing gate was unprotected.

---

**No open questions remain.** Every question raised by this spec has an operator
answer recorded above and a dated line in *Clarifications*.

---

## Self-check

*Re-run 2026-09-23 after the OQ4 rework. CHK1–CHK12 were re-checked against the
revised text, not carried forward; CHK13–CHK19 are new and interrogate the Set B
half specifically.*

- CHK1: Does the plan state, for every session shape **and for each set**,
  whether the gate asks or denies? — FAIL (missing) — CHK1 passed against the
  single-tier draft, and OQ4's two-tier allowlist reopened it: the first revision
  enumerated modes once, leaving `acceptEdits` × Set B unstated. **Revised in
  place**: C1.2 now asserts the two tiers separately with per-set counts (A: 4
  ask / 5 deny; B: 3 ask / 6 deny), and C1.3(b) is a dedicated tier-collapse
  mutant, since C1.3(a) does not catch a levelled allowlist on its own.
- CHK2: Do Step 1 and Step 2 agree about which `hook_event_name` values reach
  which branch? — FAIL (conflicting) — Step 1 as first drafted described the
  `Write`/`Edit` branch without stating that a `PostToolUse` payload also has no
  `.tool_input.command` and would fall into it. **Revised in place**: Step 2 now
  specifies the `hook_event_name` branch as the script's *first* action, and
  C2.2 is a mutation control proving the gate would otherwise block its own
  successful writes.
- CHK3: Is "the human-confirmation branch cannot be triggered by agent-authored
  content alone" expressed as a runnable check rather than prose? — PASS (C1.5,
  the never-`allow` grep; C1.6(a)+(b), now two fixed literals with an exact count
  so a constructed string cannot creep in; C1.8's planted-file case).
- CHK4: Is the term for the new branch defined once and used consistently across
  gate header, `CONTEXT.md` and the ADR? — FAIL (ambiguous) — the draft used
  "escape hatch", which `CONTEXT.md:1879` puts on the `_Avoid_` list and
  `:486`/`:2586` already bind to file-based overrides. **Revised in place**:
  canonical term **human-confirmation branch**, and C4.6 asserts string equality
  across the three surfaces.
- CHK5: Does the plan say what happens to the audit trail when the human
  approves? — FAIL (conflicting) — Step 2's original claim that "asked with no
  completed reads as a denial" is **false for Set B**, where the approved write
  can suppress its own `PostToolUse` record. Two parts of the revised plan then
  disagreed about what the log proves. **Revised in place**: U5 names the
  ambiguity, C2.4 splits into (a) Set A pairing-as-count and (b) Set B
  ambiguous-by-design, C4.8 asserts no artifact claims otherwise, and Step 7 is
  the out-of-band reconciler.
- CHK6: Do the Context and Step 4 agree on which "no exemption" assertions become
  false? — PASS, and the lens-2 finding makes this non-obvious: the header's "no
  grant branch, no identity exemption" stays TRUE (the branch is not
  identity-scoped and grants nothing unilaterally) while the deny message's
  "ever"/"no exemption" become false. C4.2 and C4.3 assert both halves
  separately.
- CHK7: Is the audit-logs scope decision made, and does it still hold with Set B
  in scope? — PASS (resolved as OQ1 (a) by the operator; re-verified and
  **reinforced**, because the scope rule now stated in the Goal — *a legitimate
  agent-authored write exists* — is the single discriminator that admits Set A,
  admits Set B, and excludes the logs, rather than three separate calls).
- CHK8: Is the (a)/(b)/(c) mechanism choice justified against (c) explicitly, as
  the dispatch required? — PASS (Context, *Engaging with the prior `fable`
  analysis*): (c) is **accepted** for the audit logs, the whole `Bash` branch,
  and every non-allowlisted session shape, and **rejected** for five paths, on
  the ground that the consumer is the hook synchronously rather than a later
  agent reading an artifact. Updated for OQ4: Set B is no longer on the accepted
  side of that list.
- CHK9: Does any criterion rest on an undocumented harness behaviour? — PASS
  (U1, U2, U2b, U3, U4, U5 are each routed around; C1.2's allowlist is
  fail-closed over the documented closed value set, so an undocumented or future
  mode denies for both tiers). The one residual that could not be routed around
  inside the hook — U1 against Set B — is converted into a **measurement
  precondition** (C5.5) rather than an assumption, which is the same discipline
  rather than an exception to it.
- CHK10: Is every claim added to prose bounded, given R5's two-FAIL history on
  this file? — PASS (C3.6 re-runs the note-parity block over gate source and
  memory note; C4.1 is a fixed file list, deliberately not an unbounded "no file
  says X").
- CHK11: Does the plan state how the implementer edits a file the gate itself
  blocks? — PASS (R3: `Bash`, via the ratified ADR-0025 Set B gap, with an
  explicit prohibition on "fixing" that gap).
- CHK12: Is the mirror/hash/adapter blast radius stated? — PASS (R6, C6.1;
  adapters confirmed to carry no port of this gate, and the generated
  `.cursor`/`.codex` `hooks.json` files confirmed NOT to be Set B members,
  correctly, since neither registers this gate — matching the
  `human-decision-gate.sh` precedent).
- CHK13: Does the plan say whether Set B's conditions are identical to Set A's,
  or different — and if different, why? — PASS (*Set B is not a mechanical clone
  of Set A*: four numbered situational differences, each mapped to a concrete
  design consequence; the `acceptEdits` exclusion, the second prompt literal, and
  the C5.5 precondition are each traced to one of them rather than asserted).
- CHK14: Does the plan state how a Set B approval can be audited **after** the
  fact? — FAIL (missing) — the revised draft asserted Step 7 as the reconciler
  before establishing that no such check exists today. **Revised in place**: R11
  and Step 7's rationale both record the measured gap
  (`expectedRegistrations()` derives its expectation from the file it checks), and
  C7.2 makes re-deriving it a FAIL rather than a style note.
- CHK15: Do Step 1 and Step 3 agree that Set B stays off the `Bash` branch? —
  PASS (Step 1's C1.7 asserts Set B `Bash` → exit 0 deliberately; C3.4 keeps the
  pre-existing asymmetry mutation control; Step 4 row 2 freezes the ADR-0025
  paragraph byte-for-byte via C4.3c). All three say the same thing, and the third
  is what stops an implementer "tidying" the first two into agreement the wrong
  way.
- CHK16: Is the `agent_id` condition described consistently, given it is now
  identity-sensitive on a much higher-value surface? — FAIL (ambiguous) — "the
  main session may write Set B" and "the gate never asks from a subagent" are the
  same rule with opposite connotations, and the first reads as a grant branch,
  inverting the property R5 already cost two FAILs. **Revised in place**: the
  lens-2 second finding fixes the canonical phrasing, C1.4 constrains the
  assertion messages, and C4.3b is a mechanical check over a fixed file list.
- CHK17: Does the plan state what happens if the U1 measurement comes back
  badly? — PASS (C5.5 is a two-branch ship gate with both outcomes written down,
  matching C5.4's existing shape; R10 states the escalation chain it defends
  against and why the chain is cheaper under `ask` than under `deny`).
- CHK18: Is the implementer's own edit route still viable now that the gate it is
  editing is inside the new branch? — PASS (R3: subagents keep today's exit 2, so
  the `Bash` route is unchanged for `lead-programmer`; the step also forbids the
  implementer from routing its own edit through the new branch).
- CHK19: Is the gate's *executing* copy covered in every install shape? — FAIL
  (missing) — it was not: a standalone install runs
  `.claude/hooks/scripts/harness-integrity-gate.sh`, which matched no Set B
  literal. Pre-existing, but material once Set B is prompted rather than denied.
  Not resolvable by me — widening a ratified trust set is the operator's call.
  **Converted to Open Question 5**, now **resolved (a)**: the mirror is Set B's
  fourth literal, implemented in Step 1 and guarded by C1.11/C1.12. Re-checked
  and passing.
- CHK20: Does adding a fifth path leave any count, tier, or scope claim stale? —
  FAIL (missing) — OQ5's one-line change touches eleven separate counted claims
  ("four paths" in C1.7, the deny message, trust-model row 11 and CHK8; the
  per-set subject counts in C1.1, C1.4, C2.2, C5.1; the Set B literal count in
  C1.2 and C1.7's Bash row; "four files" in R2). **Revised in place**, all
  eleven, and verified by re-running the reference sweep rather than by eye —
  this is precisely the renumbering class where prose labels drift out of step
  with the rows they describe.
- CHK21: Does every hit of C4.1's own sweep have a bucket to land in? — FAIL
  (missing) — it did not, and this is the mid-flight gap `task-master` reported
  on 2026-09-23. Re-running the authoring sweep at that tree returns **three**
  hits admitted by neither escape: `CHANGELOG.md:102`,
  `docs/plans/2026-09-02-blocked-marker-scoping-gh425.md:621`, and
  `docs/plans/2026-08-11-microworld-silo.md:300,559` (the third was **not** in
  the mid-flight report — it was found by re-running the sweep rather than
  trusting the report's hit list, and it is the one hit of the three that is
  plainly made FALSE by this change). **Revised in place**: four-category
  classification with a both-directions closure assertion (C4.1), Cat 3 for
  still-true prose, Cat 4 for `CHANGELOG.md` with C4.9 pricing it, row 13 for
  `microworld-silo`, and R13 recording the defect class. Not converted to an
  Open Question: the one genuine ruling inside it — whether `CHANGELOG.md` is
  annotated or exempt — is decided by an already-ratified ADR (0029), and the
  Clarifications line records both readings plus the one-row reversal.
- CHK22: Do the plan's own hit classifications agree with the tree, or only with
  the report that prompted them? — FAIL (conflicting) — two of the mid-flight
  report's premises about `CHANGELOG.md:102` are wrong against `d807630`: the
  two grepped absolutes it carries stay **true** (lens-2, row 1), and *"checked
  on the Write/Edit branch only"* also stays **true** (C1.7/C3.4/C4.3c all
  preserve it). Had the remedy been written from the report, C4.9(b) would have
  required the ADR to assert two stale claims that are not stale — a FAIL
  manufactured by the fix. **Revised in place**: the corrections are stated
  under *Sweep closure*, and C4.9(b) names the two claims that genuinely do go
  stale (the unconditional-deny description; the pre-OQ5 Set B enumeration) and
  explicitly rules the absolutes out.
- CHK23: Is any criterion added by this amendment dependent on a step outside
  its own unit? — PASS (C4.9 is satisfied entirely by row 12's ADR, which Step 4
  authors; Step 6's CHANGELOG entry is referenced in *Sweep closure* as context
  for why Cat 4 is tolerable, but no criterion asserts anything about it, so
  this step remains independently dispatchable and Step 6 is untouched).
- CHK24: Does the amendment's own classification table survive the closure check
  it introduces? — FAIL (conflicting) — the first draft of *Sweep closure* did
  not. It listed `.claude/wiki/architecture.md:115`, `agents/orchestrator.md:235`
  and `.claude/agents/orchestrator.md:236` as Cat 1 members; those three are
  **not** hits of the authoring sweep (their *"no grant branch"* is line-wrapped
  as *"no grant / branch"*, so `git grep` does not match — they were carried in
  from a *wider* exploratory grep), and C4.1(a)'s new "listed file with zero hits
  is red" arm would therefore have failed on the table that introduced it. Two
  further conflicts in the same draft: it claimed each file maps to exactly one
  category while `CHANGELOG.md` carries hits of two, and it omitted the fact that
  **this plan document becomes a 14th hit-bearing file once committed** (22 hits
  measured), which would turn the closure check red on the spec defining it.
  **Revised in place**: the three non-hits are removed and the counts are
  measured per file (`git grep -c`) rather than transcribed; Cat 4 is excluded
  whole-file so `CHANGELOG.md`'s split is moot; Cat 3 carries this plan doc and
  any follow-up in the family; and the key is file, never line or count, because
  both shift when the remedy lands.
- CHK25: Is C3.3's required relation between the four kill sets satisfiable at
  all, given C1.3(a)'s and C1.3(b)'s own stated scopes? — FAIL (conflicting) —
  it was not. C1.3(a) enumerates *"Set B's 6 deny rows"*, C1.3(b) targets
  *"exactly the Set B `acceptEdits` row"*, and `acceptEdits` is one of those six,
  so the old C3.3's pairwise-disjointness clause contradicted the two criteria it
  was auditing. **Revised in place**: C3.3 is rewritten around a frozen relation
  table in which that one pair is `NESTED` and the other five are `DISJOINT`, and
  R14 records why the containment is stronger evidence than the disjointness it
  replaces. Neither C1.3(a) nor C1.3(b) changes.
- CHK26: Does the plan define the unit a kill set is a set of, precisely enough
  that "disjoint" and "subset" are decidable? — FAIL (ambiguous) — *"a DISJOINT,
  NON-EMPTY set of cases"* named no unit, and the same mutant is legitimately
  countable as 29 probe cells or 11 normalized `(set, mode)` rows (both recorded
  in `.claude/reviewed/hcb-branch.pass`). Under the first accounting the overlap
  is 4 cells; under the second it is 1 row; a reviewer and an implementer could
  agree on the property and still disagree on every number. **Revised in place**:
  C3.3(a) declares the cell tuple, the verdict function, and the kill predicate,
  and requires one shared enumeration to drive all four controls.
- CHK27: Does C3.3, as rewritten, still deliver the thing the old clause claimed
  to deliver — that the two-tier allowlist is tested as two tiers and not as one
  with extra rows? — PASS, and not via the relation table. The table's `NESTED`
  row alone would be satisfied by a tier-collapse mutant that flipped *every*
  Set B deny row, which proves nothing about the tier; C3.3(e) is the clause that
  carries the claim, asserting `K_b ∩ Set A = ∅` plus a bit-identical Set A split
  under the mutant. `CONTEXT.md:219-225` independently assigns this job to
  C1.3(b) — *"the exact point defended by acceptance criterion C1.3(b)"* — and
  says nothing about C1.3(a)'s scope, which is the glossary agreeing with the
  ruling rather than with the old clause.

*Three items added 2026-09-24 (second amendment), interrogating the rewritten
C4.2 rather than the system.*

- CHK28: Is C4.2, as rewritten, satisfiable against the rest of Step 4's own
  mandatory content? — PASS, and this is the item the old wording failed. Checked
  by construction against all four constraints that made the old one impossible:
  the frozen ADR-0025 span (C4.3c) sits outside `deny()` and its sha256 is
  unchanged under a correct edit; the required "never emits `ask` from a
  subagent" (C4.3b) goes in the header, outside the span, and is not a whole-word
  "ever" in any case; `reason_b` (`:122`, Do-NOT-touch) sits outside the span;
  and `:6`'s still-true whole-word "ever" sits outside it too. The deny message,
  once edited, is the only place any arm of C4.2 looks for `ever` — which is what
  the escalation asked be confirmed rather than assumed.
- CHK29: Does C4.2's anti-deletion half actually test anything? — FAIL
  (ambiguous, in the machine-checkable sense: the criterion had no check behind
  its stated claim) — **revised in place.** The original's file-wide
  `grep -qF 'bin/cli.js'` is satisfied by `reason_a` and `reason_b`, which this
  unit may not touch, so it returned green for a deleted message — the exact case
  its own prose named. Now scoped to the span, and paired with (a)'s
  exactly-one-`BLOCKED:` guard, so deletion is red twice over. Note the
  consequence, stated so the implementer is not surprised: this **strengthens**
  the requirement — the baseline message does not name `bin/cli.js` and must gain
  it.
- CHK30: Can the rewritten C4.2 be satisfied without the deny message actually
  changing? — PASS, verified by mutation rather than by reading. RED on the
  unedited baseline, RED on message-deleted, route-omitted, `deny()`-renamed and
  absolute-relocated; GREEN only on a correct edit and on a correct edit reflowed
  across three lines; identical verdicts under `ugrep` (inline) and GNU `grep`
  (inside `bash <script>`), so the criterion does not depend on which `grep` the
  implementer's shell resolves. A criterion this step could satisfy by doing
  nothing would be worse than the unsatisfiable one it replaces.

## Scribe update hint

- **`CONTEXT.md`**: add **human-confirmation branch** (lens 3, text drafted in
  Context) with `_Avoid_: escape hatch, grant branch`; amend the existing
  **Set A / Set B** entry (`:234-247`) so **neither set** is described as
  uniformly denied on `Write`/`Edit`, so the entry records that the two sets
  differ in allowlist and prompt wording rather than only in `Bash` coverage,
  and so Set B lists its **four** literals (OQ5). **Corrected 2026-09-23:** this
  hint previously also directed an amendment at `:322`. It should not be amended
  — see Step 4 row 5; `:322` is the `foreign-claude-dir` residual's
  directory-confinement claim, which this change does not touch.
- **`CONTEXT.md` (added 2026-09-23, lens 3, advisory)**: two further terms
  surfaced by the sweep-closure fix and confirmed to have no entry today —
  **sweep closure** (*a reconciliation criterion that asserts its classification
  table covers its own sweep's output in both directions, so an unlisted hit is
  red and a listed-but-hitless entry is also red*) and **historical-citation
  surface** (*a file whose entries are read as of their own date and are never
  rewritten — `CHANGELOG.md`, `.claude/wiki/changelog.md`, `docs/plans/`,
  `docs/adr/`, per ADR-0029; corrections are appended, or recorded elsewhere and
  cross-referenced*). Both are load-bearing in R13 and C4.1. `scribe`'s call
  whether to add them; neither gates this spec.
- **`CONTEXT.md` (added 2026-09-24, lens 3, advisory)**: two terms the C3.3
  rewrite makes load-bearing, confirmed absent from the glossary today —
  **kill set** (*the set of probe cells whose verdict differs between the shipped
  artifact and one named mutant; meaningless until the cell space is declared,
  since the same mutant is legitimately countable several ways*) and **kill-set
  relation table** (*a frozen literal table asserting the expected relation —
  disjoint, or nested with a named overlap — between every pair of a suite's
  mutation controls, so that one over-broad mutant silently standing in for two
  controls is red; the same discipline as a* [[family table]] *applied to mutants
  instead of bypass families*). The existing **two-tier allowlist** entry needs
  no change — it already assigns the tier defence to C1.3(b), which is what the
  2026-09-24 ruling relies on. `scribe`'s call; neither gates this spec.
- **`CONTEXT.md` (added 2026-09-24, second amendment, lens 3, advisory)**: one
  term the C4.2 rewrite makes load-bearing, confirmed absent from the glossary
  today — **over-scoped criterion** (*an acceptance criterion whose mechanical
  scope is wider than the prose intent it encodes — typically a file-wide grep
  standing in for a claim about one region. On a file that legitimately contains
  the banned token elsewhere it is not merely loose but* unsatisfiable*, and
  narrowing the token rather than the scope does not fix it. The inverse of an*
  unbounded universal*, which over-claims in prose relative to its check; both
  are diagnosed the same way, by running the check against the tree plus a
  correct-edit mutant. Narrowing the scope creates two fresh obligations: a
  fixed-phrase file-wide companion arm, so the banned claim cannot be relocated
  out of scope, and non-vacuity guards on the extraction itself*). Load-bearing
  in R15 and C4.2, and the third instance of this family in this spec alone
  (R5, R13, R15). `scribe`'s call; it does not gate this spec.
- **`docs/adr/`**: one new ADR — next free number (`0032` at authoring time),
  re-derived at execution time. Subject: per-call consent belongs to the
  permission system; durable escalation consent belongs to the `DECISION` file;
  why a gate documented as absolute grew a bounded branch over **its own
  registration surface**, and why that branch is a narrower tier rather than a
  clone of the config branch. Residuals to record: U1, U2, U2b, U3, U4, U5.
  R12 is recorded as closed (the mirror is Set B's fourth literal), not as a
  residual.
- **`docs/trust-model.md`**: row 11 Notes cell — name the branch, both tiers,
  the subagent exclusion, and U5's ambiguity; keep the row mechanical (Step 7),
  not `self-reported` (R7).
