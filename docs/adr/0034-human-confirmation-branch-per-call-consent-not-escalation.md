# ADR 0034: The human-confirmation branch answers per-call consent, not escalation consent, and Set B is a narrower tier of it, not a clone

Date: 2026-09-24

Status: Accepted (units hcb-branch, hcb-regcheck, hcb-posttool, hcb-step5-measure,
hcb-prose-context, 2026-09-24; plan
`docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`, FINAL)

## Context

An ADAPT/setup session was observed hard-blocked trying to `Write` the
persona-selection config: `harness-integrity-gate.sh` denied it unconditionally,
and no sanctioned route completed the plugin's own documented fresh-install path
(`bin/cli.js`'s scaffold writes a skeleton config; `skills/install-antislop/SKILL.md`
§ 6 is the step that fills it in from a real repo scan — a legitimate
agent-authored write with nowhere to go). The operator's request — replace the
hard block with a human-confirmed prompt — required choosing a mechanism, and the
choice was not free: this same gate's header already stated "no grant branch, no
identity exemption," a property that must survive whatever mechanism was picked.

**Engaging with the prior `fable` analysis, rather than re-deriving it.** A `fable`
dispatch earlier in this project's history analysed whether `AskUserQuestion`
could front the sibling `human-decision-gate.sh`, and concluded that an
`AskUserQuestion` answer, once relayed as text inside a model's own turn, is
byte-identical from any downstream consumer's vantage to a fabricated one — this
project's standing rule is that no message from any agent is ever the user's own
consent. That conclusion is correct, and it is reasoning about a different
problem. `docs/plans/2026-08-11-human-decision-channel.md` rejects the permission
prompt as *that* problem's channel on three grounds, two of which (provenance
unobservable to the agent; session-bound) presuppose that the consent must
survive as a **durable artifact** a **later agent verifies with its own Read
tool** — exactly what a DECISION file is for, and exactly what this request does
not need. Here the consumer of the consent is the hook itself, synchronously, for
one tool call — the role that same document's own closing sentence assigns to the
permission system: "The permission system keeps its existing role (per-call
consent); the DECISION file carries escalation consent." So `fable`'s analysis
answered the **escalation-artifact** question; this decision answers the
**per-call-consent** question, which `fable`'s own source document already routes
to the permission system.

## Decision

**The write path gains a human-confirmation branch: `permissionDecision: "ask"`
instead of exiting 2, for a scoped set of paths and session shapes. It never
gains `allow`.** No agent-authored byte — not file content, not a planted file on
disk, not a claim in the turn text — can move the verdict past `ask`. Only a
human at Claude Code's own permission prompt converts `ask` into a write.

**Why not `AskUserQuestion`.** Not a judgment call — four measured/documented
blockers, any one of which is disqualifying:

1. `AskUserQuestion` is unavailable to subagents, so a hatch built on it could
   never serve a `lead-programmer`, `scribe`, or `install-antislop` sub-dispatch.
   `PreToolUse` hooks, by contrast, fire inside subagents (and this design denies
   there regardless — see below).
2. Its payload is arbitrary JSON, not a small enum, so approval cannot bind to
   content: the persona-selection config is an arbitrary structured document, and
   a design that performs the write from the tool's `tool_response` would source
   that document from an agent-authored staging artifact — reintroducing the
   exact agent-authored-content problem the design exists to remove. It would buy
   "a human approved *something*," not "a human approved *this content*."
3. The `tool_response` shape for `AskUserQuestion` is undocumented, and this
   project's constitution does not permit building the system's strongest
   non-repudiation claim on an unverified harness contract.
4. The model composes the question. `permissionDecision: "ask"` removes this
   structurally: the prompt is rendered by Claude Code from the hook's own fixed
   `permissionDecisionReason` literal plus the tool call's own `tool_input` — the
   normalized path plus a diff, for `Write`/`Edit` — with no model-composed
   wording anywhere in the path.

**The scope rule, stated once.** A path enters the human-confirmation branch if
and only if a legitimate agent-authored write to it exists. The persona-selection
config has one (`install-antislop` § 6); this admits **Set A**. The gate's own
registration surface has one — every maintenance unit on this gate, including the
units that implemented this decision; this admits **Set B**. The four audit logs
and their `.seal` sidecars have none — their content is produced by hook code via
`audit_append` and rotated by `bin/harness-integrity.sh --rotate` — so a prompt
over them would authorize nothing and would only weaken the tamper-evidence
trail; this **excludes** them. One rule decides all three cases.

**Why the `Bash` branch is excluded.** A `Bash` permission prompt would render the
agent's own composed command text, which the agent can pad so the write is not
what the human's eye lands on — the same "model-composed wording that could
mislead" `fable` named for a different gate. The `Write`/`Edit` prompt instead
renders a normalized, exact path plus a diff, sourced from the tool's own
`tool_input` rather than from anything the agent wrote in prose. That asymmetry
mirrors the gate's existing, ratified Set A/Set B-versus-Bash asymmetry
([[Set A / Set B]], ADR-0025) rather than inventing a new principle: Set B
remains absent from the `Bash` branch, unchanged by this decision.

**Why Set B is a narrower tier of the same branch, not a clone of Set A's.** The
mechanism is identical — `permissionDecision: "ask"`, never `allow`, never from a
subagent — but three properties differ and each moves the design toward
narrower, not equal, exposure:

- **The `acceptEdits` exclusion.** Set A's allowlist keeps `acceptEdits`,
  accepting the risk of a silent auto-approve because the gate stays armed and
  re-guards the next call either way. Set B's allowlist **excludes**
  `acceptEdits`: a silent auto-approve there could remove the gate itself, after
  which nothing is guarded and nothing notices. Excluding it is a strict
  fail-close with zero regression — in `acceptEdits`, Set B's verdict stays
  exactly today's deny.
- **The dedicated prompt literal.** Set B carries its own fixed
  `permissionDecisionReason` string, distinct from Set A's, naming what approval
  actually costs: that the write can disable every future prompt, including this
  one. This is two frozen strings selected by set, never one constructed string.
- **The U1 measurement precondition.** Whether a hook's `ask` overrides a
  matching `permissions.allow` entry is undocumented (U1, below). For Set A, OQ3
  removed the one such entry in this repo, making the question moot here. For Set
  B it is **not** moot — `.claude/settings.local.json` is unguarded, so an agent
  could add an entry there — so Set B's branch does not ship until Step 5's C5.5
  measures U1 directly. Set A's branch carries no such precondition.

**Residuals.** Six undocumented harness behaviours are routed around rather than
assumed, and are recorded here rather than silently accepted:

| # | Unknown | Disposition |
|---|---|---|
| U1 | Does a hook's `ask` override a matching `permissions.allow` entry in `default`/`acceptEdits`? | Moot for Set A (OQ3 removed the one entry). Not moot for Set B — gated on Step 5's C5.5 measurement before shipping. |
| U2 | What does `ask` do under `bypassPermissions`/`dontAsk`? | Both excluded from both allowlists → deny. The gate never emits `ask` in a mode whose prompt behaviour is unknown. |
| U2b | Does a hook's `ask` override `acceptEdits`'s auto-accept posture? | Set A accepts the risk (bounded: the gate stays armed). Set B excludes `acceptEdits` → deny, because there the cost of a silent auto-approve is the gate itself. |
| U3 | Does `ask` render for a tool call made inside a subagent? | `agent_id` present → deny. The branch never emits `ask` from a subagent, for either set. |
| U4 | What does `ask` do in a non-interactive/headless (`-p`) session? | No documented field distinguishes interactive from headless. Accepted residual: a `-p` run in `default` mode reaching this write is the one shape where the gate emits `ask` without knowing a prompt can render. |
| U5 | Set B only. Does the `PostToolUse` completion record still fire for the very write that edits the gate or its registration? | Undocumented, and possibly no by construction. **Bounded claim, stated once so it is not overstated elsewhere:** for Set B, an `asked` audit line with no paired `completed` line is ambiguous — it does not distinguish a denial from an approval that later disabled the hook. Not closable inside the hook itself; reconciled outside it by a registration-presence assertion plus `git log` on the surface. |

**R12 is recorded as closed, not as an accepted residual.** An earlier open
question (R12 — the gate's executing copy in an adapted project, i.e. the mirror,
was not itself in Set B) was closed by OQ5(a): the mirror
(`.claude/hooks/scripts/harness-integrity-gate.sh`) became Set B's fourth
literal. It is listed in [[Set A / Set B]]'s four-literal enumeration above, not
carried here as an open item.

## Consequences

- The gate's write-deny is no longer unconditional for five paths (the
  persona-selection config plus Set B's four registration-surface literals);
  Claude Code's own permission prompt, not the agent, decides those five in
  allowlisted main-session shapes. The four audit logs, their `.seal` sidecars,
  and the entire `Bash` branch keep today's unconditional deny, unchanged.
- The gate's own header property — no grant branch, no identity exemption —
  stays literally true: the human-confirmation branch hands nobody a unilateral
  capability, and it never emits `ask` from a subagent. What changes is narrower:
  the write is no longer denied outright for these five paths in these session
  shapes; it is decided by a human at a prompt instead.
- For Set B specifically, an `asked` audit line with no paired `completed` line
  remains ambiguous (U5) — this is a standing, bounded limitation of the audit
  trail, not a defect introduced by this decision, and it must never be
  characterized elsewhere as resolved or as distinguishing denial from approval.
- **`CHANGELOG.md` supersession.** Per ADR-0029's historical-citation rule, the
  `CHANGELOG.md` entry that introduced `harness-integrity-gate.sh` is left
  exactly as written. Two of its claims are narrowed by this change: its
  'hardcodes a deny' description (now `ask` for five paths in allowlisted
  main-session shapes) and its three-item Set B enumeration (four literals after
  OQ5). The 'no grant branch, no identity exemption' absolutes it carries are not
  among them — those stay true. The CHANGELOG was not corrected.

## Related

- [ADR-0025](0025-textual-gate-protection-requires-structural-triggers.md) — the
  ratified Bash-coverage asymmetry this decision leaves unchanged and explicitly
  does not re-litigate.
- [ADR-0029](0029-microworld-silo-namespaced-directories.md) — the
  historical-citation rule governing the `CHANGELOG.md` disposition above.
- `docs/plans/2026-08-11-human-decision-channel.md` — the prior `fable`-informed
  decision this ADR distinguishes itself from (escalation consent vs. per-call
  consent).
- `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md` — the
  finalized spec this ADR records the decision from.
- `docs/trust-model.md` row 11 — the trust-model row this decision makes
  conditional for five paths.
- `CONTEXT.md`'s **human-confirmation branch** and **Set A / Set B** entries —
  the canonical terminology this ADR uses verbatim.
