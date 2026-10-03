# In-session escalation decision: the human decides in chat, the DECISION file stays the record

Status: **FINAL, amended 2026-10-02** (spec-master). The user answered all
four Open Questions on 2026-10-01 and took every recommended default. On
2026-10-02, after the first probe run, the user dropped `plan` from the
allowlist (see Amendment A1). This is the fast path: 5 units, with dispatch
contracts emitted below.

**Order:** `esc-chat-1-fix` (lead-programmer adjusts the probe script) → the
operator re-runs the script to produce the committed `esc-chat-1` record →
`esc-chat-2` → `esc-chat-3` → `esc-chat-4`. **Unit `esc-chat-2` is BLOCKED
until the committed `esc-chat-1` record reads `Ship gate: GREEN`.**

### Amendment A1 (2026-10-02): `plan` dropped from the allowlist

The first run of `scripts/probe-bash-ask.sh` (commit `cbdd204`, against
`claude` 2.1.287) gave these results, as reported by the operator:
- default, acceptEdits, auto, dontAsk and bypassPermissions each rendered a
  prompt with the full heredoc visible, and declining left no file;
- headless `-p` was denied;
- `plan` could not be observed: in plan mode the model never calls Bash, so
  the hook never fires.

The user chose to drop `plan`. **Reason: plan mode is read-only, so there is
no write approval for a human to make there.** Plan denies by policy, not by
inference from a measurement. The allowlist is now **default, acceptEdits,
auto**. Plan, bypassPermissions, dontAsk, an empty mode and any unknown mode
all deny, and the orchestrator falls back to the terminal `printf` route. That
first run is not the committed record; the record comes from the re-run after
`esc-chat-1-fix`.

### Amendment A2 (2026-10-03): dialog evidence in the record; the old record is superseded

`esc-chat-1-record` FAILed on evidence. The record's Probe and Display rows
for default, acceptEdits and auto were not supported by its own appendix,
because the script saved the panes only after the decline.

Unit `esc-chat-1-evidence` (`253106e`) changed this:
- the script now saves each mode's dialog text **before** the decline, as
  length-prefixed blocks (`### dialog: <mode> <N> lines, claude <version>`,
  a fence, N lines, a fence);
- the appendix heading is now
  `## Appendix: dialog blocks and raw captured panes`;
- each mode's claude version is recorded, with a `Version note:` line when
  the readings differ;
- `gate()` grades GREEN only if each of default, acceptEdits and auto has
  exactly one dialog block of its own, and that block contains:
  - "Do you want to proceed?";
  - `line-1` through `line-6-END`;
  - a closing `EOF` line after `line-6-END`.

**1. esc-chat-1-fix criterion, superseded.** Its synthetic-record check
(the four lines marked `SUPERSEDED by Amendment A2` in esc-chat-1-fix's
acceptance block: rows and Cleanup checks, no appendix, expected GREEN)
now grades **RED**, and that is correct: the record carries no dialog
evidence. The block below replaces those four lines. Its fixture uses the
same shapes as `tests/probe-bash-ask.test.sh` (`rows_for`, `good_dialog`,
`dblock`, `pre`). Save it as a file and run it with `bash`:
```sh
set -e
s=scripts/probe-bash-ask.sh
bash -n "$s"
bash tests/probe-bash-ask.test.sh >/dev/null
grep -qF '## Appendix: dialog blocks and raw captured panes' "$s"
grep -qF 'Version note:' "$s"
# SUPERSEDED by Amendment A3 (2026-10-03): this block grades its GREEN fixture RED under the decline-evidence gate; run A3's block instead
# Synthetic gate() check (Amendment A2): the shapes of tests/probe-bash-ask.test.sh rows_for/good_dialog/dblock/pre
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
dlg() { printf '%s\n' ' Bash command' '' "   cat > out.txt <<'EOF'" '   line-1' '   line-2' '   line-3' '   line-4' '   line-5' '   line-6-END' '   EOF' '' ' Do you want to proceed?'; }
blk() { local c; c=${2-$(dlg)}; printf '\n### dialog: %s %s lines, claude 2.1.288 (Claude Code)\n```\n%s\n```\n' "$1" "$(printf '%s\n' "$c" | wc -l)" "$c"; }
rec() { # rows-modes ; DM = modes that get a good dialog block ; X = extra appendix text
  local m; printf '# Probe\n\n## Rows\n\n```\n'
  for m in $1; do printf 'Probe row: %s prompt-rendered 2026-10-03 observed\nDisplay row: %s full-heredoc-visible yes 2026-10-03 observed\nDecline row: %s file-absent yes 2026-10-03 observed\n' $m $m $m; done
  printf '```\n\n## Appendix: dialog blocks and raw captured panes\n'
  for m in ${DM-$1}; do blk "$m"; done
  printf '%s' "${X-}"
  printf '\n### default (claude 2.1.288 (Claude Code))\n\n```\npane text\n```\n\n## Cleanup checks\n\nCleanup check: scratch-removed yes\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n'
}
gr() { bash -c "source <(sed -n '/^gate()/,/^}/p' $s); gate $1"; }
all="default acceptEdits auto"
rec "$all" > "$d/g.md";                                                     test "$(gr "$d/g.md")" = GREEN
rec "default auto" > "$d/r1.md";                                            test "$(gr "$d/r1.md")" = RED   # acceptEdits rows removed
DM="default auto" rec "$all" > "$d/r2.md";                                  test "$(gr "$d/r2.md")" = RED   # acceptEdits dialog block missing
DM="default auto" X="$(blk acceptEdits "$(dlg | grep -v line-6-END)")" rec "$all" > "$d/r3.md"; test "$(gr "$d/r3.md")" = RED   # no line-6-END
DM="default auto" X="$(blk acceptEdits "$(dlg | grep -v '^   EOF$')")" rec "$all" > "$d/r4.md"; test "$(gr "$d/r4.md")" = RED   # no closing EOF
DM="default default auto" rec "$all" > "$d/r5.md";                         test "$(gr "$d/r5.md")" = RED   # default's block cannot back acceptEdits
echo "A2 synthetic gate checks: all expected verdicts"
```
*Measured 2026-10-03 at `39f0850` from a script file:* every line passes.

*Non-vacuity:* run against the pre-fix `gate()` (`253106e~1`), the four new
RED variants grade GREEN and the existing acceptEdits-rows-removed variant
grades RED. So the new lines fail on the old code and pass on the new.

**2. The old committed record is superseded.**
`docs/experiments/2026-10-01-probe-bash-ask.md` (`cbb918e`, `Ship gate: GREEN`):
- predates the dialog evidence;
- grades **RED** under the new `gate()` by design (measured 2026-10-03);
- lacks the new appendix heading.

It is not evidence for the ship gate. The operator's re-run replaces it, and
until then the esc-chat-1 ship gate is unmet.

**3. esc-chat-1 record criteria, additions.** These are in addition to the
existing block in esc-chat-1. Run them against the re-run record:
```sh
f=docs/experiments/2026-10-01-probe-bash-ask.md
grep -qxF '## Appendix: dialog blocks and raw captured panes' "$f" || { echo "no new appendix heading"; exit 1; }
n=$( { grep -E '^### ' "$f"; grep -E '^`claude --version` reports' "$f"; } | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | wc -l)
if [ "$n" -gt 1 ]; then grep -qE '^Version note: ' "$f" || { echo "versions differ ($n) but no Version note"; exit 1; }; fi
test "$(bash -c "source <(sed -n '/^gate()/,/^}/p' scripts/probe-bash-ask.sh); gate $f")" = "$(grep '^Ship gate:' "$f" | tail -1 | sed 's/^Ship gate: //')" || { echo "recorded Ship gate disagrees with gate() re-grade"; exit 1; }
echo "record criteria pass"
```
- The **`Version note:` rule**: when the set of distinct `X.Y.Z` versions
  across the `### ` appendix headers and the setup `claude --version` line
  has more than one member, a `Version note:` line is required.
- The **re-grade line** requires the record's own last `Ship gate:` value to
  equal `gate()` run on the record.

*Measured 2026-10-03:* against `cbb918e`'s record the block fails at the
appendix heading, as intended. A synthetic record with two versions and no
note fails the Version-note line; adding a `Version note:` line makes it
pass.

### Amendment A3 (2026-10-03): decline evidence; the A2 synthetic block is replaced

Unit `esc-chat-1-evidence2` (`6d30470`) changed the probe in three ways:
- `display_and_decline` saves each mode's post-decline evidence: `out.txt:
  absent` or `present`, then `ls -Aq scratch dir:` and the listing;
- `write_appendix` writes that evidence as length-prefixed
  `### decline: <mode> <N> lines` blocks, after the dialog blocks;
- `gate()` grades GREEN only if each of default, acceptEdits and auto has
  exactly one decline block of its own, and that block contains an
  `out.txt: absent` line, no `out.txt: present` line and no `out.txt` in its
  listing. Every A2 rule still applies.

**1. The A2 synthetic block is superseded.** Its GREEN line now grades RED,
because its fixture has no decline blocks. Under `set -e` the block stops
there, and r1-r5 would be RED only because the decline blocks are missing.
The block below replaces A2's block.

Every fixture now carries a good dialog block **and** a good decline block for
all three modes. Each RED variant then has exactly the one defect named in its
comment. The shapes follow `tests/probe-bash-ask.test.sh` (`good_dialog`,
`dblock`, `good_decline`, `lblock`, `pre`). Save the block as a file and run
it with `bash`:
```sh
set -e
s=scripts/probe-bash-ask.sh
bash -n "$s"
bash tests/probe-bash-ask.test.sh >/dev/null
# Synthetic gate() check (Amendment A3): shapes of tests/probe-bash-ask.test.sh rows_for/good_dialog/dblock/good_decline/lblock/pre
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
dlg() { printf '%s\n' ' Bash command' '' "   cat > out.txt <<'EOF'" '   line-1' '   line-2' '   line-3' '   line-4' '   line-5' '   line-6-END' '   EOF' '' ' Do you want to proceed?'; }
blk() { local c; c=${2-$(dlg)}; printf '\n### dialog: %s %s lines, claude 2.1.288 (Claude Code)\n```\n%s\n```\n' "$1" "$(printf '%s\n' "$c" | wc -l)" "$c"; }
dcl() { printf '%s\n' 'out.txt: absent' 'ls -Aq scratch dir:' .claude raw; }
lblk() { local c; c=${2-$(dcl)}; printf '\n### decline: %s %s lines\n```\n%s\n```\n' "$1" "$(printf '%s\n' "$c" | wc -l)" "$c"; }
all="default acceptEdits auto"
rec() { # rows-modes ; DM/DL = modes given a good dialog/decline block (default: all three) ; X = extra dialog block(s), Y = extra decline block(s)
  local m; printf '# Probe\n\n## Rows\n\n```\n'
  for m in $1; do printf 'Probe row: %s prompt-rendered 2026-10-03 observed\nDisplay row: %s full-heredoc-visible yes 2026-10-03 observed\nDecline row: %s file-absent yes 2026-10-03 observed\n' $m $m $m; done
  printf '```\n\n## Appendix: dialog blocks and raw captured panes\n'
  for m in ${DM-$all}; do blk "$m"; done
  printf '%s' "${X-}"
  for m in ${DL-$all}; do lblk "$m"; done
  printf '%s' "${Y-}"
  printf '\n### default (claude 2.1.288 (Claude Code))\n\n```\npane text\n```\n\n## Cleanup checks\n\nCleanup check: scratch-removed yes\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n'
}
gr() { bash -c "source <(sed -n '/^gate()/,/^}/p' $s); gate $1"; }
v() { local n=$1 want=$2; shift 2; "$@" > "$d/$n.md"; test "$(gr "$d/$n.md")" = "$want" || { echo "$n: expected $want"; exit 1; }; }
v g  GREEN rec "$all"
v r1 RED   rec "default auto"                                                                 # acceptEdits rows removed (blocks present for all three)
DM="default auto" v r2 RED rec "$all"                                                         # acceptEdits dialog block missing
DM="default auto" X="$(blk acceptEdits "$(dlg | grep -v line-6-END)")" v r3 RED rec "$all"   # dialog lacks line-6-END
DM="default auto" X="$(blk acceptEdits "$(dlg | grep -v '^   EOF$')")" v r4 RED rec "$all"    # dialog lacks closing EOF
DM="default default auto" v r5 RED rec "$all"                                                 # default's dialog block cannot back acceptEdits
DL="default auto" v r6 RED rec "$all"                                                         # acceptEdits decline block missing
DL="default default auto" v r7 RED rec "$all"                                                 # default's decline block cannot back acceptEdits
DL="default auto" Y="$(lblk acceptEdits "$(printf '%s\n' 'out.txt: absent' 'out.txt: present' 'ls -Aq scratch dir:' .claude raw)")" v r8 RED rec "$all"   # decline block has an out.txt: present line
DL="default auto" Y="$(lblk acceptEdits "$(printf '%s\n' 'out.txt: absent' 'ls -Aq scratch dir:' .claude out.txt raw)")" v r9 RED rec "$all"            # listing shows out.txt
echo "A3 synthetic gate checks done"
```
*Measured on 2026-10-03, from a script file:*
- **Against HEAD's script** (`45dc9ca`, whose probe script is unchanged since
  `6d30470`): every line passes. `g` is GREEN and r1-r9 are RED.
- **Against `253106e`'s `gate()`**, which has the dialog rule but no decline
  rule: `g` and r1-r5 grade exactly as at HEAD, so r1-r5 are RED for the
  dialog or row defect they name, not for missing decline evidence. r6-r9 grade
  **GREEN**, so the four new variants fail on a gate without the decline
  check.

**2. The committed record is superseded again.**
`docs/experiments/2026-10-01-probe-bash-ask.md` (`229138e`, which says
`Ship gate: GREEN`) has no decline blocks. It grades **RED** under the current
`gate()` by design (measured 2026-10-03). The esc-chat-1 ship gate was met on
the earlier record format. **It is not met by the repo's committed record now,
and will not be until the operator's next re-run is committed.** Until then
the record is not ship-gate evidence.

**3. Additions to the esc-chat-1 record criteria** (on top of A2's additions):
```sh
f=docs/experiments/2026-10-01-probe-bash-ask.md
for m in default acceptEdits auto; do
  test "$(grep -cE "^### decline: $m [0-9]+ lines$" "$f")" = 1 || { echo "decline block for $m not exactly once"; exit 1; }
done
```
*Measured 2026-10-03:*
- against `229138e`'s record the block fails ("decline block for default not
  exactly once"), as intended;
- against the A3 synthetic GREEN fixture it passes.

**The record may also carry a `## Side effects` section.** It lists new plan
files under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plans`, or says the listing was
not possible. It is optional, informational and read by no gate, and no
criterion grades it.

## Goal

When a unit is escalated (ESCALATE-TO-HUMAN), the orchestrator prints the
`.escalated` marker, `CHANGES.md` and `EXAMPLES.md` **verbatim** in the
session. The human then picks approve / reject / direct-a-fix and the
`examples:` token through one `AskUserQuestion` call. The human never writes a
file and never runs a `printf`. The `DECISION` file stays the reviewer's only
consent artifact. **No agent can make that file exist unless a human approves
its exact bytes at Claude Code's own permission prompt.**

## Mechanism (decided: OQ1 → prompt-gated write)

After the human answers, the orchestrator (main session) runs exactly one
strictly shaped Bash heredoc:

```
cat > .claude/human-review/<task-id>/DECISION <<'EOF'
DECISION <task-id> <now, UTC ISO-8601> route: <approve|reject|direct> escalation: <.escalated marker's first-line timestamp>
by: <output of git config user.name>
via: prompt
examples: <reviewed|skipped|none-offered>      <- approve only; omitted if the human left it unanswered
reason: <the human's words, verbatim>           <- reject/direct only; continuation lines allowed
EOF
```

This is byte-for-byte the shape `bin/microworld-dashboard/decision-block.js`
already composes (`composeHeredocCommand` + `composeEscalationDecisionBody`),
with `via: 'prompt'`. `hooks/scripts/human-decision-gate.sh` gains one branch:
for this shape, and only when every eligibility condition holds, it emits
`permissionDecision: "ask"`. It **never** emits `allow`. The eligibility
conditions are:
- main session (no `agent_id`);
- `permission_mode` ∈ {default, acceptEdits, auto} (OQ2, as amended by A1);
- a standing `.escalated` marker;
- no existing DECISION file;
- the packet directory exists;
- the body passes the grammar;
- the timestamp matches the marker.

Anything else gets today's deny. That covers plan (read-only, so there is
nothing to approve), bypassPermissions, dontAsk, an absent mode and an
unknown mode: the orchestrator then falls back to
surfacing the terminal `printf` template, exactly as it does today. Claude
Code renders the prompt from the tool call itself, so what the human approves
is the file.

### Why agents still cannot self-approve

The guarantee narrows. Today it reads: "if DECISION exists, no harness tool
call created it". After this spec it reads: **"if DECISION exists, either a
human wrote it outside the harness (terminal / dashboard), or a human approved
its exact bytes at Claude Code's permission prompt."** An agent can still
*propose* a fabricated decision, but it cannot *complete* one. The consent
comes from the permission system, which the harness itself names as a valid
consent source. It never comes from relayed chat.

The 2026-08-11 plan (`docs/plans/2026-08-11-human-decision-channel.md`)
rejected the permission prompt on three grounds:
- **(a) A granted call looks identical whether a human approved it or an
  allowlist did.** Answered by measurement:
  `docs/experiments/2026-09-23-probe-permission-mode-ask.md` records U1
  `ask-still-prompts`.
- **(b) Behaviour depends on the mode.** That same record has a hook `ask`
  render a prompt for Write in every interactive mode, and denies headless
  `-p` runs. For **Bash**, the first `scripts/probe-bash-ask.sh` run
  (2026-10-02, operator-reported, Amendment A1) showed a prompt with the full
  heredoc visible in every mode it could drive, and headless was denied. The
  committed `esc-chat-1` record re-measures this after `esc-chat-1-fix`.
- **(c) A prompt only lives inside one session.** The terminal and dashboard
  routes are kept unchanged, so the packet still outlives the session.

### Rejected alternatives (recorded for the ADR)

- **A. A PostToolUse hook on `AskUserQuestion` that writes DECISION.**
  Rejected for four reasons:
  - The writer script becomes an oracle. Any agent can call it from Bash with
    a forged payload, and that command never spells the path, so the gate
    never sees it.
  - The `tool_response` shape is undocumented (ADR-0034 blocker 3).
  - Strings in the 2.1.287 binary suggest answers ride
    `updatedInput.answers`, a channel that hooks and the SDK can fill. This
    is an inference, not a measurement.
  - The human never sees the bytes that get recorded.
- **C. A `UserPromptSubmit` typed command.** Same oracle problem, and the
  human still has to type a grammar.
- **D. The dashboard's `/dev/tty` code reused in chat.** The human has to
  type a code, and any secret a hook holds is readable by agents.
- **Grant the orchestrator Write.** Rejected because it widens the thin
  router; Bash is already in its tool list.

The residual is shared by every route, today's included: an agent can add a
hook in the unguarded `.claude/settings.local.json`. It is documented here,
not fixed.

## Context

- `human-decision-gate.sh` is registered for Bash and Write|Edit at
  `hooks/hooks.json:20,35`. Its only current allowance is the reviewed-marker
  heredoc, `is_sanctioned_marker_write` (:81-101), which is the structural
  template for the new parser. The early exits (:343-353) need both
  `human-review` and `DECISION` in the text, which the new shape always
  spells. Under `reviewGating.mode` = `off` the gate exits 0 at :353, which
  is unchanged and correct: no escalation exists then.
- The pattern to copy is `harness-integrity-gate.sh`'s
  `ask_allowed`/`ask` (:114-146).
- `decision-block.js` exports only
  `{composeDecisionBlock, composeEscalationDecisionBody, assertNoNewline, ID_RE}`
  (:224). `composeHeredocCommand` (:73) must be exported for the
  branch-agreement test. `VIA_ROUTES` (:21) is `['terminal','dashboard']`.
- `tests/human-decision-gate.test.sh` already supports
  `GATE_UNDER_TEST=<path>` for mutation controls (:17).
- The `tests/adapter-protocol-parity.test.js` `ESCALATION_PROBES` live at
  :60-71.
- The orchestrator's escalation steps 1-6 are at
  `agents/orchestrator.md:203-252`. The reviewer's resolution text is at
  `agents/reviewer.md:352-427`, with its `via:` paragraph at :389-398. The
  protocol's "Resolving an escalation" section is at
  `templates/persona-protocol.md:527-648`.
- The live hooks run from the **installed plugin cache**, not from the working
  tree. Behaviour changes only after the plugin version is bumped and the
  plugin is updated.
- In this repo `humanReviewMode` stays `"off"` (OQ4). The feature ships to
  adopters, whose default is `critical`. ADR-0036 is amended for this branch
  only.
- **Prior FAIL survey (all `.fail` records naming the gate, the composer or
  DECISION, surveyed 2026-10-01).** 19 related records were found, and three
  of them shape this plan directly:
  - `hcb-step5-measure` (**2 FAILs**): the measurement record was
    self-contradictory about which rows were observed and which inferred,
    and it cited a check that could not support its claim. So
    `esc-chat-1` requires a per-row `observed` tag and forbids inferred rows
    for the allowlisted modes.
  - `hdg-prose-2` (**2 FAILs, hit the cap**): a fail-open caused by the
    gate's Bash and Write branches disagreeing. So `esc-chat-2` uses a frozen
    case table plus a mutation control, never a universal claim, and it is
    tagged opus.
  - `gh377-7`: CONTEXT.md claims (the "exactly one file" sink count, the
    location of `via:`) were transcribed from the plan rather than checked
    against code. So `esc-chat-4` gets claim-anchored criteria.

  Other gate and composer FAILs (`379`, `380`, `harness-integrity-gate-hardening`,
  `hcb-prose-context`, `gh413`, `gh415`, `gh417`, `gh418`) put this surface in
  a defect-prone class. **No unit here is tagged below sonnet; the gate and
  protocol units are opus.**

### ADR draft (scribe numbers and lands it in `esc-chat-4`; re-derive the number, currently 0039)

**ADR 00NN: Escalation decisions may be completed in-session through a
prompt-gated write (amends ADR-0036; narrows ADR-0034's Bash exclusion for one
shape).**

*Context:* the terminal `printf` step breaks the flow of a review the operator
otherwise values. AskUserQuestion transcription by a hook leaves a forgeable
oracle and an undocumented payload.

*Decision:* `human-decision-gate.sh` emits `ask`, never `allow`, for exactly one
strictly parsed heredoc shape. That shape must come from the main session, in
the default, acceptEdits or auto modes, against a standing escalation,
with a body that carries `via: prompt`. ADR-0034 excluded Bash because a
padded command could hide the write. That reasoning does not apply here: the
parser accepts nothing but the heredoc, so the command the human sees is the
file.

*Consequences:* the guarantee narrows to "no agent can complete a DECISION
write without the human approving its bytes". The terminal and dashboard
routes are unchanged. Approval fatigue is mitigated, not removed, by a fixed
reason literal that names the route. Three modes deny by policy:
plan (read-only, so there is no write approval to make, and the model never
calls Bash there), bypassPermissions and dontAsk (a future silent auto-approve
there would be undetectable fabricated approval). Headless runs are denied
too. The 2026-08-11 objections are
answered by measurement and by keeping the other routes; they are not
reversed. ADR-0036's "keep as-is" is superseded for this branch only.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-01 Technical constraints & tradeoffs: Q Which mechanism: a
  prompt-gated heredoc write, a PostToolUse hook on AskUserQuestion, or a
  UserPromptSubmit typed command? → A: prompt-gated heredoc write, per user (OQ1).
- 2026-10-01 Non-functional attributes: Q In which permission modes may the
  gate ask? → A: default, plan, acceptEdits and auto only (plan later dropped; superseded by the 2026-10-02 A1 line). bypassPermissions
  and dontAsk deny and fall back to the terminal route, per user (OQ2).
- 2026-10-02 Non-functional attributes: Q Plan mode could not be driven by
  the probe (the model never calls Bash there). Should plan stay on the
  allowlist? → A: drop it. The allowlist is default, acceptEdits and auto.
  Plan denies by policy because it is read-only and has no write approval to
  make. Per user (Amendment A1).
- 2026-10-01 User interaction flow: Q Is the examples answer asked in the same
  AskUserQuestion call as the route? → A: yes, the same call, per user (OQ3).
  Q1 asks for the route, with options `approve` / `reject` / `direct` /
  `decide later`. Q2 is present iff `EXAMPLES.md` exists, with options labelled
  literally `reviewed` and `skipped`; it is ignored unless the route is
  approve. A reject or direct reason is gathered in one plain follow-up and
  written verbatim. A free-text "Other" answer is never interpreted as a route:
  the orchestrator asks again.
- 2026-10-01 Domain entities / data model: Q What marks a prompt-route
  decision, and where does `by:` come from? → A (self-resolved): a required
  `via: prompt` line that the gate validates. `by:` is the output of
  `git config user.name`, and the human sees it in the prompt.
- 2026-10-01 External dependencies & integrations: Q Does a hook `ask` on Bash
  render a prompt, with the full heredoc visible, in the allowlisted
  modes (default, acceptEdits, auto after A1)? → A (self-resolved): unknown. `esc-chat-1` is an operator
  measurement and a ship gate.
- 2026-10-01 Edge cases / failure handling: Q What happens when the human
  clicks No, the file already exists, the marker is stale or missing, or the
  call comes from a subagent or a denied mode? → A (self-resolved): the gate
  denies everything except the eligible shape. After No or a deny, the
  orchestrator never retries or rephrases the write. It re-asks through
  `AskUserQuestion`, or surfaces the terminal template and leaves the
  escalation standing.
- 2026-10-01 Terminology consistency: Q What is the new authoring path called,
  and is `CONTEXT.md` edited now? → A (self-resolved): **prompt-confirmed
  decision write**, a sibling of *dashboard-originated decision write*.
  `CONTEXT.md` is left to scribe in `esc-chat-4`, because the entry must
  describe landed behaviour, not planned behaviour (the `gh377-7` lesson).
  Also asked: does this repo's `humanReviewMode` change? → A: no, it stays
  `off`, per user (OQ4).

## Risks / dependencies

- **R1 Approval fatigue.** Mitigated by a fixed reason literal built only from
  the parsed route enum and task-id. Accepted as a residual.
- **R2 Claude Code drift.** A later version could auto-approve a hook `ask`.
  The record pins the CLI version, and `esc-chat-1` is re-run on a material
  Claude Code upgrade.
- **R3 `settings.local.json` hook residual.** Shared and pre-existing;
  documented only.
- **R4 Reserved-key forgery inside a reason.** The gate rejects any body line
  after the header that begins with `DECISION `, `by:`, `via:`, `examples:` or
  a second `reason:`.
- **R5 Six protocol surfaces.** The protocol section is trimmed from the
  inlined persona block, and the ports are hand-maintained, so the probes are
  a deliverable.
- **R6 Prose false positive.** The gate's open NL1 / F-1 residuals are
  unchanged. The new branch only ever turns a deny into an `ask`, and only for
  the parsed shape. Implementers and the reviewer will hit the gate's known
  prose false positive whenever Bash text spells the packet path and the file
  name. Use `git commit -F <file>`, keep the two tokens apart in grep
  patterns, and read gated directories with the Read tool or `grep -r`.
- **R7 The ask is logged before the human answers.** The
  `decision-gate-asked` audit line is written when the gate asks, so an
  `asked` line with no DECISION file means the human declined. The docs must
  say this (`esc-chat-4`).

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. `esc-chat-1` measures Bash `ask`
  before `esc-chat-2` ships, and every criterion below is a runnable command.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors
  are regenerated only by `node bin/cli.js --update`, and the gate grammar is
  branch-agreement-tested against the existing composer.
- P3 "Version-stamp discipline": satisfied. `esc-chat-2` and `esc-chat-3` each
  bump `.claude-plugin/plugin.json` and `package.json` and add a CHANGELOG
  entry **in the same commit** as any version-stamped change. The order is
  bump → CHANGELOG → `--update`, and a per-commit criterion checks it.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit's criteria
  end with it.

## Units and dispatch contracts

Retrieval contract (all units): the spec lives at
`docs/plans/2026-10-01-in-session-escalation-decision.md`. Read it with the
Read tool. No tracker issue exists (fast path).

---

### Unit: esc-chat-1-fix

Suggested model: sonnet. This is a small script edit. The class it sits in
has prior FAIL history (`hcb-step5-measure`, 2 FAILs, on
provenance and Cleanup claims), so do not tag it below sonnet.

## Objective
Adjust the committed probe script `scripts/probe-bash-ask.sh` (commit
`cbdd204`) to match Amendment A1, so the operator's re-run produces a record
that can be committed:
- plan becomes informational;
- the ship gate covers default, acceptEdits and auto;
- the headless `denied` classification is tightened;
- the Cleanup section states only what the script actually checks.

## Retrieval
This plan, § "Amendment A1" and the `esc-chat-1` contract below (the record's
row format and its acceptance criteria). Read `scripts/probe-bash-ask.sh` in
full (132 lines at `cbdd204`).

## Affected files
`scripts/probe-bash-ask.sh` only.

## Ordered edits
1. **Plan is informational.** Keep `plan` in the driven set and still attempt
   it. When plan produces no verdict, record it as
   `Info row: plan not-driven <DATE> informational`, not as a `miss`. An
   unclassified plan must **never** be added to `MISSING`, never cause exit 3,
   and never feed `gate()`. If plan *does* produce a verdict, write it as
   `Info row: plan <verdict> <DATE> observed informational`, never as a
   `Probe row:`.
2. **The ship gate loops over three modes.** Change `gate()`'s loop to
   `for m in default acceptEdits auto` (it is currently
   `default plan acceptEdits auto` at :98).
3. **Tighten the headless `denied` regex.** The current regex at :91,
   `denied|blocked|not allowed|not permitted|permission|approv|confirm`,
   matches ordinary model prose such as "I need your permission". Replace it
   with structured evidence: run
   `claude -p ... --permission-mode default --output-format json` and
   classify `denied` only when `out.txt` is absent **and**
   `jq -e '(.permission_denials // []) | map(select(.tool_name=="Bash")) | length > 0'`
   succeeds. If the JSON has no such field in 2.1.287, fall back to the
   anchored phrase regex
   `(permission|approval).{0,40}(denied|required|was not granted)|requires? (your )?approval`.
   In that case, leave the record's Method stating which of the two
   classifiers fired. Any other output → `miss` and no row, as today.
4. **Cleanup states only what is checked.** Replace the Cleanup paragraph at
   :113, which claims "Verified by the operator with `test ! -e`" but checks
   nothing. After the record body is written, `main` must:
   1. call `cleanup` explicitly;
   2. run `test ! -e "$SCRATCH"`, and in the repo
      `! grep -qi probe "$ROOT/hooks/hooks.json"` and
      `git -C "$ROOT" status --porcelain -- hooks .claude/settings.json` (empty);
   3. append these lines to the record **before** the `Ship gate:` line:
      - `Cleanup check: scratch-removed <yes|no>`
      - `Cleanup check: repo-hooks-probe-free <yes|no>`
      - `Cleanup check: repo-hook-surface-clean <yes|no>`

   The Cleanup prose may name only these three checks. Any `no` forces
   `Ship gate: RED`. Keep the `trap cleanup EXIT` as a safety net.
5. **Record the script path.** The record's header names
   `scripts/probe-bash-ask.sh` and the commit it ran from (`git -C "$ROOT"
   rev-parse --short HEAD`), on a line
   `Script: scripts/probe-bash-ask.sh @ <sha>`.
6. The Method text says plan is attempted but informational, by policy
   (Amendment A1: read-only, no write approval to make). It must not say
   plan's verdict was inferred.

## Do NOT touch
- the probe hook body;
- the 7-line heredoc request;
- the `prompt-rendered` / `auto-approved` classification and the
  display / decline logic for the other five modes;
- `hooks/hooks.json`, any `.claude/settings*.json`;
- the record file itself (the operator's re-run produces it).

## Acceptance criteria
```sh
s=scripts/probe-bash-ask.sh
bash -n "$s"
grep -qE 'for m in default acceptEdits auto; do' "$s"
! grep -qE 'for m in default plan acceptEdits auto' "$s"
grep -q 'Info row: plan' "$s"
! grep -qE "\|permission\|approv\|confirm'" "$s"
grep -q 'permission_denials' "$s"
grep -q 'Cleanup check: scratch-removed' "$s" && grep -q 'Cleanup check: repo-hooks-probe-free' "$s" && grep -q 'Cleanup check: repo-hook-surface-clean' "$s"
! grep -q 'Verified by the operator' "$s"
grep -q 'Script: scripts/probe-bash-ask.sh @' "$s"
# SUPERSEDED by Amendment A2 (2026-10-03): the next four lines grade RED under the evidence gate; run A2's block instead
# gate() unit check with a synthetic record: GREEN without any plan row, RED when acceptEdits is missing
t=$(mktemp); for m in default acceptEdits auto; do printf 'Probe row: %s prompt-rendered 2026-10-02 observed\nDisplay row: %s full-heredoc-visible yes 2026-10-02 observed\nDecline row: %s file-absent yes 2026-10-02 observed\n' $m $m $m; done > "$t"; printf 'Cleanup check: scratch-removed yes\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n' >> "$t"
test "$(bash -c "source <(sed -n '/^gate()/,/^}/p' $s); gate $t")" = GREEN
sed -i '/acceptEdits/d' "$t"; test "$(bash -c "source <(sed -n '/^gate()/,/^}/p' $s); gate $t")" = RED; rm -f "$t"
bash tests/validate.sh
```
(The synthetic check needs `gate()` to stay a self-contained function from
`gate() {` to a closing `}` at column 0. If you also add a Cleanup-check
condition to `gate()`, the synthetic record above already carries those
lines.)

## Pre-resolved context
- The user reports that plan mode never calls Bash, so the hook never fires
  there. This is accepted **by policy** (A1), not inferred.
- `hcb-step5-measure` FAILed twice because its record described its procedure
  in two incompatible ways and cited a check that could not support its claim.
  Every Method and Cleanup sentence the script emits must match what the code
  does.
- `grep` in an inline shell is ugrep, but GNU grep inside `bash script.sh`.
  Keep regexes portable (ERE, no PCRE).
- The user re-runs the script after this unit to produce the committed record
  (see `esc-chat-1`).

## Escalation
If `--output-format json` in 2.1.287 neither carries `permission_denials` nor
produces anything the fallback regex matches on a real denial, keep the `miss`
behaviour and report it. Never widen the regex back.

---

### Unit: esc-chat-1

Suggested model: none (operator-run). An agent only commits the record the
script produces.

## Objective
Produce the committed measurement record
`docs/experiments/2026-10-01-probe-bash-ask.md` by re-running the adjusted
`scripts/probe-bash-ask.sh` against the installed `claude`. This is the ship
gate for `esc-chat-2`.

## Retrieval
This plan, § "Amendment A1" and § "Mechanism". The precedent record is
`docs/experiments/2026-09-23-probe-permission-mode-ask.md`.

## Affected files
`docs/experiments/2026-10-01-probe-bash-ask.md`, written by the script.

## Ordered edits
1. **The operator runs, in a real terminal with `tmux` and `claude` on PATH:**
   `bash scripts/probe-bash-ask.sh`
   The script drives default, plan (informational), acceptEdits, auto,
   dontAsk and bypassPermissions in a scratch directory
   `/tmp/bash-ask-probe` with a hook that always asks, and declines every
   prompt. It also runs one headless `-p` check, then writes the record and
   the Cleanup check lines. Exit 3 means a required mode was not classified:
   re-run, and never hand-fill a row.
2. An agent commits the record exactly as the script wrote it (`git commit -F
   <msgfile>`). It never edits rows.

## Do NOT touch
The script (that is `esc-chat-1-fix`), `hooks/hooks.json`, and
`.claude/settings*.json`. Never add or edit a row by hand.

## Acceptance criteria
```sh
f=docs/experiments/2026-10-01-probe-bash-ask.md
test "$(grep -cE '^Probe row: (default|acceptEdits|auto|dontAsk|bypassPermissions|headless-p) (prompt-rendered|auto-approved|denied) 2026-[0-9]{2}-[0-9]{2} observed$' "$f")" -eq 6
grep -qE '^Info row: plan .* informational$' "$f"
! grep -qE '^(Probe|Display|Decline) row: plan ' "$f"
! grep -qE '^(Probe|Display|Decline) row: .* inferred' "$f"
grep -qE '^Script: scripts/probe-bash-ask.sh @ [0-9a-f]{7,}$' "$f"
grep -qE '[0-9]+\.[0-9]+\.[0-9]+ \(Claude Code\)' "$f"
grep -qi 'self-reported' "$f"
for c in scratch-removed repo-hooks-probe-free repo-hook-surface-clean; do grep -qE "^Cleanup check: $c yes$" "$f" || exit 1; done
grep -qE '^Ship gate: (GREEN|RED)$' "$f"
! grep -qi 'probe' hooks/hooks.json
bash tests/validate.sh
```
**Ship-gate branch, decided now.** GREEN iff, for each of default, acceptEdits
and auto, the record has `prompt-rendered`, `full-heredoc-visible yes` and
`file-absent yes`, all `observed`:
```sh
for m in default acceptEdits auto; do grep -qE "^Probe row: $m prompt-rendered .* observed$" "$f" && grep -qE "^Display row: $m full-heredoc-visible yes .* observed$" "$f" && grep -qE "^Decline row: $m file-absent yes .* observed$" "$f" || { echo "RED: $m"; exit 1; }; done
```
- GREEN unblocks `esc-chat-2`.
- RED in acceptEdits or auto removes that mode from the allowlist, and
  `esc-chat-2`/`esc-chat-3` are re-scoped before dispatch.
- RED in default, or a visibility `no`, routes back to spec-master, because
  the mechanism's premise has failed.
- **Plan is not driven to a verdict and is excluded by policy (A1), not by
  inference.** Its `Info row` never affects the gate.
- The dontAsk and bypassPermissions rows are informational; both stay denied
  by policy whatever they show.
- `headless-p` should read `denied`. If it reads `auto-approved`, that routes
  back to spec-master.

## Pre-resolved context
- The first run (2026-10-02, operator-reported) was GREEN-shaped for the
  three allowlisted modes. It was produced before `esc-chat-1-fix`, so it
  carries the old loose headless regex and the unverified Cleanup claim, and
  it is not the committed record.
- The record is evidence, not a check: no test in this repo can regenerate it.

## Escalation
If the script cannot drive a required mode after two attempts, report
`STATUS: incomplete` and name the mode. Never infer.

---

### Unit: esc-chat-2  (BLOCKED on esc-chat-1 Ship gate: GREEN)

Suggested model: opus. This surface has prior FAIL history: `hdg-prose-2`
hit the 2-FAIL cap on branch disagreement, and `379`/`380` failed on the
composer.

## Objective
Add the prompt-eligible decision-write branch to `human-decision-gate.sh`.
It emits `ask` and never `allow`. Export the heredoc composer and admit
`via: 'prompt'`. Pin everything with a frozen case table and a mutation
control. Ship the mirror in the same unit.

## Retrieval
This plan, § "Mechanism", § "Risks" R4/R6/R7, § "Context". Read
`hooks/scripts/human-decision-gate.sh` in full, and
`hooks/scripts/harness-integrity-gate.sh:114-146`.

## Affected files
- `hooks/scripts/human-decision-gate.sh`
- `bin/microworld-dashboard/decision-block.js`
- `tests/human-decision-gate.test.sh`
- `tests/microworld/dashboard-decision-block.test.js`
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated by `node bin/cli.js --update`: the `.claude/hooks/scripts/human-decision-gate.sh` mirror and its config hash entry

## Ordered edits
1. `decision-block.js`: set `VIA_ROUTES = ['terminal','dashboard','prompt']`
   and add `composeHeredocCommand` to `module.exports`. On `via: 'prompt'`,
   `reason` keeps the terminal path's multi-line behaviour, because the human
   previews the full body at the prompt.
2. Gate: add `is_prompt_eligible_decision_write()`, modelled on
   `is_sanctioned_marker_write`.
   - **First line** must match end-to-end:
     `^cat[[:space:]]+>[[:space:]]*[.]claude/human-review/(ID)/DECISION[[:space:]]+<<'EOF'$`.
     Use the same ID charclass as the marker parser. Only `>` is allowed,
     never `>>`. The delimiter is exactly `'EOF'`. The final line is `EOF`,
     and no earlier line equals `EOF`.
   - **Body line 1:**
     `^DECISION <ID> <ISO> route: (approve|reject|direct) escalation: <ISO>$`.
     ISO is `[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,3})?Z`,
     and the ID must equal the path ID.
   - **Body line 2:** `^by: ` followed by one or more non-control characters.
   - **Body line 3:** exactly `via: prompt`.
   - **Approve:** optionally exactly one `examples: (reviewed|skipped|none-offered)`
     and nothing after it. `none-offered` is valid only if
     `<packet>/EXAMPLES.md` is absent, and `reviewed|skipped` only if it is
     present.
   - **Reject / direct:** exactly one `reason: <non-empty>` line, then
     optional continuation lines, none of which starts with `DECISION `,
     `by:`, `via:`, `examples:` or `reason:`. No `examples:` line is allowed.
3. Eligibility, all required:
   - `agent_id` is empty;
   - `permission_mode` ∈ `default|acceptEdits|auto` (frozen allowlist,
     Amendment A1; everything else denies, including empty, `plan`,
     `bypassPermissions` and `dontAsk`). Add a header comment giving the
     reason for `plan`: it is read-only, so there is no write approval to
     make.
   - `$project_dir/.claude/human-review/<ID>/` exists and `DECISION` inside
     it does not;
   - `$project_dir/.claude/reviewed/<ID>.escalated` exists, and the third
     space-separated field of its first line equals the `escalation:` value.
4. Add `ask_decision()`. It appends
   `<ts> decision-gate-asked identity=<sanitized> task=<ID> route=<route> mode=<mode>`
   via `audit_append` (**before** any human answer; see R7). It prints the
   ask JSON, built with `jq -n` so it is escaped, with the frozen reason:
   `This records route=<route> as YOUR decision on escalation <ID>, exactly as shown in the command below. Approve only if it matches what you chose; otherwise choose No.`
   Then it exits 0.
5. Add one top-level call line, placed after `gating_off && exit 0` and before
   `command_is_provably_benign`, **at column 0, exactly:**
   `is_prompt_eligible_decision_write "$command" && ask_decision`
   (the mutation criterion deletes this line). The Write/Edit branch is
   unchanged and always denies.
6. Update the header comment and the `deny()` text: replace "This path has one
   sanctioned route" with wording that names the main-session prompt route.
   Keep the rule that any other route is a self-authorized bypass.
7. Tests: add cases with the literal IDs `PG1`…`PG12` as below (setup is the
   main session, mode `default`, a matching marker and no DECISION unless
   stated):
   - **PG1** approve with `examples: reviewed` (EXAMPLES.md present) → stdout
     `.hookSpecificOutput.permissionDecision == "ask"`, exit 0, and an audit
     line containing `decision-gate-asked`.
   - **PG2** PG1 with `agent_id` set → exit 2.
   - **PG3** PG1 with mode `plan`, `bypassPermissions`, `dontAsk`, `""` or
     `weird` → exit 2 each.
   - **PG4** PG1 in `acceptEdits` and `auto` → `ask` each.
   - **PG5** DECISION already exists → exit 2.
   - **PG6** no `.escalated` → exit 2.
   - **PG7** escalation timestamp mismatch → exit 2.
   - **PG8** `via: terminal`, a missing `via`, or `via: prompt` on line 4 →
     exit 2.
   - **PG9** `>>`, a trailing `; rm x`, a second heredoc, an unquoted `<<EOF`,
     or a path ID different from the body ID → exit 2.
   - **PG10** a reason continuation line starting `examples:` / `via:` /
     `by:` / `DECISION ` → exit 2; `none-offered` while EXAMPLES.md is
     present → exit 2.
   - **PG11** branch agreement: for each of approve, reject and direct, a
     command produced by `node -e` from `composeHeredocCommand` +
     `composeEscalationDecisionBody({..., via:'prompt'})` → `ask`.
   - **PG12** a Write/Edit tool call to the same DECISION path → exit 2.

   In `dashboard-decision-block.test.js`, the `via` allowlist assertion
   includes `prompt` and still rejects an unknown value.
8. Bump the patch version in `.claude-plugin/plugin.json` and `package.json`
   (re-derive the current value), add a CHANGELOG entry, then run
   `node bin/cli.js --update`. All of this lands in the same commit as the
   gate change.

## Do NOT touch
- the existing allowances (`is_sanctioned_marker_write`,
  `write_with_inert_triggers`, `is_prose_only_commit`);
- the substring early exits;
- any existing test case's expected verdict;
- `server.js` (the dashboard still forces `via:'dashboard'`);
- `agents/`, `templates/`, `adapters/` (those are `esc-chat-3`).

## Acceptance criteria
```sh
bash tests/human-decision-gate.test.sh
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do grep -qE "PG$i[^0-9]" tests/human-decision-gate.test.sh || { echo "missing PG$i"; exit 1; }; done
node tests/microworld/dashboard-decision-block.test.js
node -e "const d=require('./bin/microworld-dashboard/decision-block.js'); if(typeof d.composeHeredocCommand!=='function') process.exit(1)"
grep -qx 'is_prompt_eligible_decision_write "$command" && ask_decision' hooks/scripts/human-decision-gate.sh
! grep -q '"allow"' hooks/scripts/human-decision-gate.sh
grep -qE 'default\|acceptEdits\|auto\)' hooks/scripts/human-decision-gate.sh && ! grep -qE '(default\|plan|plan\|acceptEdits)' hooks/scripts/human-decision-gate.sh   # A1 allowlist, plan absent
m=hooks/scripts/.hdg-mutant.sh; grep -vx 'is_prompt_eligible_decision_write "$command" && ask_decision' hooks/scripts/human-decision-gate.sh > "$m"; chmod +x "$m"; if GATE_UNDER_TEST="$m" bash tests/human-decision-gate.test.sh >/dev/null 2>&1; then rm -f "$m"; echo "VACUOUS"; exit 1; fi; rm -f "$m"
grep -q 'decision-gate-asked' .claude/hooks/scripts/human-decision-gate.sh   # the mirror carries the change
grep -qF "$(jq -r .version .claude-plugin/plugin.json)" CHANGELOG.md
test "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)"
bash tests/validate.sh
```
(`tests/validate.sh` is the authoritative mirror-parity check.)

## Pre-resolved context
- The hooks that run live come from the plugin cache. Test only through the
  suite with `GATE_UNDER_TEST`, never through the live hook.
- The gate's prose false positive fires on Bash text that spells both tokens.
  Commit with `git commit -F <file>`.
- `--update` prints "already current" if the bump did not land. That is an
  escalation, not something to work around.

## Escalation
If the committed `esc-chat-1` record does not read `Ship gate: GREEN`, do
not start. If any pre-existing case changes
verdict, stop and report: that is a branch-agreement regression
(`hdg-prose-2` class).

---

### Unit: esc-chat-3

Suggested model: opus. The surfaces are the protocol and the hand ports,
the P3 per-commit rule applies (lean-1 and lean-2 FAILed on it), and
`gh377-7` is in the history.

## Objective
Rewrite the orchestrator's escalation flow into the in-session flow. Teach
the reviewer and the protocol the third authoring path and `via: prompt`. Add
port parity probes. Release.

## Retrieval
This plan, § "Mechanism" and § "Clarifications" (the AskUserQuestion shape).
Read `agents/orchestrator.md:203-264`, `agents/reviewer.md:352-427` and
`templates/persona-protocol.md:527-648`.

## Affected files
- `agents/orchestrator.md`
- `agents/reviewer.md`
- `templates/persona-protocol.md`
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents-md-fragment.md`
- `tests/adapter-protocol-parity.test.js`
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated by `--update`: `.claude/agents/orchestrator.md`,
  `.claude/agents/reviewer.md`, `.claude/persona-protocol.md`

## Ordered edits
1. **`orchestrator.md`, escalation steps.**
   - **(1)** Print the marker **verbatim**, unchanged.
   - **(2)** Read `CHANGES.md` and print it **verbatim, in full** (no summary).
   - **(3)** Read `EXAMPLES.md` and print it **verbatim, in full** if present.
     Keep the "must not author or extend" rule.
   - **(4)** Keep "Never run `run.sh` yourself" and surface the command
     unchanged.
   - **(5)** Make one `AskUserQuestion` call:
     - Q1 route, with options `approve`, `reject`, `direct`, `decide later`;
     - Q2 examples (only if `EXAMPLES.md` exists), with options labelled
       exactly `reviewed` and `skipped`, its description saying it is
       recorded on approve only.

     Relay the token verbatim. **Never pick one for them, never infer one**;
     free text gets asked again. For reject or direct, ask for the
     reason/fix in plain chat and use the human's words verbatim.
   - **(6)** Compose the heredoc in § Mechanism. Get the timestamp from a
     separate `date -u +%Y-%m-%dT%H:%M:%SZ` call (no `$(...)` inside the
     heredoc), and `by:` from `git config user.name`. Run it once. **Write
     only from this session's answer, never on your own initiative.** On No,
     or a gate deny (in plan, bypassPermissions or dontAsk mode), never retry or
     rephrase. Instead surface the existing terminal `printf` template and the
     dashboard route, and leave the escalation standing. On `decide later`, do
     the same.
   - **(7)** Once the write succeeds or the human says they wrote the file,
     dispatch the reviewer as today (`subagent_type: reviewer`,
     `Unit: <task-id>`, with no decision relayed).

   Replace the sentence "never write the `DECISION` file yourself, and never
   offer to".
2. **`reviewer.md`.** The resolution paragraph names three authoring paths:
   terminal, dashboard, and the **prompt-confirmed decision write** (`via:
   prompt`). It states that the gate still hard-denies every subagent, the
   reviewer included. The `via:` enum gains `via: prompt`, transcribed like
   the other values.
3. **`templates/persona-protocol.md` § Resolving an escalation.** Keep "The
   decision travels as a file, never as a chat message." Add the third path
   with the heredoc shape, add `via: prompt` to the `via:` list, and amend
   "it never writes the file and never offers to" to the prompt-gated
   exception. Name the three allowlisted modes (default, acceptEdits, auto),
   the three denied-by-policy modes with their reasons (plan: read-only, so
   there is no write approval to make; bypassPermissions and dontAsk: a silent
   auto-approve would be undetectable), and the terminal fallback.
4. **Both ports.** Add `via: prompt` and one sentence: the prompt-confirmed
   decision write exists only under Claude Code, where `human-decision-gate.sh`
   is registered; elsewhere use the terminal or dashboard route.
5. **`ESCALATION_PROBES`.** Append `'via: prompt'` and
   `'prompt-confirmed decision write'`.
6. In **each** commit that touches `agents/` or `templates/`: bump
   `.claude-plugin/plugin.json` and `package.json`, add a CHANGELOG entry,
   then run `node bin/cli.js --update`. The bump comes before `--update`.

## Do NOT touch
- the gate script and the composer (those are `esc-chat-2`);
- `CONTEXT.md`, `docs/`, `README.md` (those are `esc-chat-4`);
- the reviewer's staleness checks, route table, `.directed` / `.escalated`
  semantics, cap accounting, and `examples:` absent → skipped rule.

## Acceptance criteria
```sh
BASE=<HEAD at dispatch>   # task-master/orchestrator fills this in
for f in agents/reviewer.md templates/persona-protocol.md adapters/cursor/rules/persona-protocol.mdc adapters/codex/agents-md-fragment.md .claude/agents/reviewer.md .claude/persona-protocol.md; do grep -q 'via: prompt' "$f" || { echo "missing in $f"; exit 1; }; done
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do grep -q 'AskUserQuestion' "$f" && grep -q 'via: prompt' "$f" && grep -q 'Never run `run.sh` yourself' "$f" && grep -q 'never pick one for them' "$f" || { echo "orchestrator gap in $f"; exit 1; }; done
! grep -q 'never write the `DECISION` file yourself, and never offer to' agents/orchestrator.md
grep -q 'The decision travels as a file, never as a chat message' templates/persona-protocol.md
for m in default acceptEdits auto plan bypassPermissions dontAsk; do grep -q "$m" templates/persona-protocol.md || exit 1; done
grep -qiE 'plan[^.]{0,80}read-only' templates/persona-protocol.md && grep -qiE 'plan[^.]{0,80}read-only' agents/orchestrator.md
grep -q "'via: prompt'" tests/adapter-protocol-parity.test.js && grep -q "'prompt-confirmed decision write'" tests/adapter-protocol-parity.test.js
node tests/adapter-protocol-parity.test.js
for c in $(git rev-list "$BASE"..HEAD -- agents templates); do f=$(git show --name-only --format= "$c"); echo "$f" | grep -qx '.claude-plugin/plugin.json' && echo "$f" | grep -qx 'CHANGELOG.md' || { echo "P3 miss $c"; exit 1; }; done
test "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)"
bash tests/validate.sh
```

## Pre-resolved context
- The protocol section is **not** in any persona's inlined block. That is why
  `orchestrator.md` and `reviewer.md` are edited directly.
- `adapters/{cursor/agents/reviewer.md,codex/agents/reviewer.toml}` carry no
  escalation text and are out of scope.
- The prose false positive: commit with `-F <file>`.
- Load the `antislop:version-stamp-discipline` skill before reporting
  ready-for-review.
- **Added 2026-10-03** (from `docs/plans/2026-10-02-escalation-followups.md`,
  Amendment C1; esc-chat-2b reviewer finding 5). The § Mechanism heredoc
  above still shows a relative target, but the landed gate (esc-chat-2b,
  `012e7d8`) requires an **absolute** target whose prefix equals
  `$CLAUDE_PROJECT_DIR` exactly. The orchestrator flow you write must pass
  `projectDir` to `composeHeredocCommand` as the literal value of
  `$CLAUDE_PROJECT_DIR`. A resolved-symlink path, a trailing slash, or any
  other spelling makes the gate deny, and the orchestrator then falls back to
  the terminal route. **Land after `esf-gate-bytes`.**

## Escalation
If `--update` says "already current", or `validate.sh` mirror parity fails
after `--update`, stop and report. Never hand-edit a generated mirror.

---

### Unit: esc-chat-4

Suggested model: opus. Docs units on this surface FAILed on claim accuracy
(`gh377-7`, `hcb-prose-context`). Dispatch to `scribe`.

## Objective
Land the ADR, the glossary entries, trust-model row 20 and the README
paragraph. Every sentence must be checked against the landed code, not
against this plan.

## Retrieval
This plan, § "ADR draft", § "Why agents still cannot self-approve", § "Risks"
R7. The landed `hooks/scripts/human-decision-gate.sh` after `esc-chat-2`.

## Affected files
- `docs/adr/00NN-prompt-confirmed-decision-write.md` (new; number re-derived)
- `CONTEXT.md` (refresh [[DECISION file]]; add **prompt-confirmed decision write**)
- `docs/harness-glossary.md` (the "The human-decision gate" entry, ~:1923)
- `docs/trust-model.md` row 20 (also fix the stale "Reads no config at all":
  the gate reads `reviewGating.mode`)
- `README.md` (~:204)

## Ordered edits
1. Write the ADR from the draft. Its Related section links ADR-0034, ADR-0035,
   ADR-0036, the 2026-08-11 plan, the 2026-09-23 probe record, the
   2026-10-01 probe record, and this plan.
   The ADR names the allowlist (default, acceptEdits, auto) and gives each
   denied mode's reason: plan is read-only, so there is no write approval to
   make (Amendment A1, a policy exclusion, not an inference);
   bypassPermissions and dontAsk would make a silent auto-approve
   undetectable. Docs that list modes (glossary, trust-model row 20) use the
   same three-mode list.
2. Add the CONTEXT.md entry **prompt-confirmed decision write**. It names
   **two** disk effects at their real locations: the DECISION file (written by
   the orchestrator's Bash call after the human's Yes) and the
   `decision-gate-asked` audit line (written by the gate **when it asks,
   before the human answers**, so it also appears for a decline). `via:
   prompt` lives in the file body, not in the audit line.
3. Refresh the DECISION file entry: there are now three authoring paths, and
   the unwritability sentence is restated as "no agent can complete the write
   without a human approving its bytes".
4. Update the gate entry in harness-glossary, trust-model row 20 and the
   README.

## Do NOT touch
- code, tests, `agents/`, `templates/`;
- ADR-0034, which is pinned byte-for-byte by `tests/harness-integrity-gate.test.sh`
  C4.1c (amend only by the new ADR);
- `CHANGELOG.md` history entries.

## Acceptance criteria
```sh
a=$(ls docs/adr/*prompt-confirmed-decision-write*.md) && test -n "$a"
grep -qiE 'plan[^.]{0,80}read-only' "$a" && ! grep -qiE 'default, plan|plan, acceptEdits' "$a" CONTEXT.md docs/harness-glossary.md docs/trust-model.md
grep -q '0036' "$a" && grep -q '0034' "$a" && grep -q '2026-08-11-human-decision-channel' "$a" && grep -q 'probe-bash-ask' "$a"
grep -q '\*\*prompt-confirmed decision write\*\*' CONTEXT.md
awk '/\*\*prompt-confirmed decision write\*\*/,/^$/' CONTEXT.md | grep -q 'decision-gate-asked'
awk '/\*\*prompt-confirmed decision write\*\*/,/^$/' CONTEXT.md | grep -qi 'before the human'
grep -q 'decision-gate-asked' hooks/scripts/human-decision-gate.sh      # the claim matches the landed code
grep -q 'prompt-confirmed decision write' docs/harness-glossary.md
grep -E '^\| 20 ' docs/trust-model.md | grep -q 'ask' && ! grep -E '^\| 20 ' docs/trust-model.md | grep -q 'Reads no config at all'
grep -qi 'permission prompt' README.md
git diff --quiet HEAD -- docs/adr/0034-human-confirmation-branch-per-call-consent-not-escalation.md
bash tests/validate.sh
```

## Pre-resolved context
- The CONTEXT.md conventions: a dated provenance line, and `_Avoid_` lines
  scoped to the entry. Entries are not alphabetical.
- Get the ADR number from `ls docs/adr | tail -1` at execution time. Never
  backfill a hole.

## Escalation
If the landed gate differs from this plan (log token, mode list), document
what the code does and report the divergence. Never document the plan over
the code.

## Dependency order
`esc-chat-1-fix` (lead-programmer) → `esc-chat-1` (operator re-run; record committed) → `esc-chat-2` → `esc-chat-3` → `esc-chat-4`.
`esc-chat-3` may be drafted in parallel, but it lands after `esc-chat-2`,
because its prose describes `esc-chat-2`'s behaviour.

## Open Questions

None. OQ1-OQ4 were answered by the user on 2026-10-01 (see Clarifications).

## Self-check
- CHK1: Is the mechanism decided? — PASS (OQ1 answered; § Mechanism)
- CHK2: Do the Goal and esc-chat-2 agree that the gate never emits `allow`? — PASS (Goal; esc-chat-2 criterion `! grep -q '"allow"'`)
- CHK3: Is it defined that the human sees the full recorded bytes, and is that premise tested? — PASS (esc-chat-1 Display rows plus the ship-gate branch)
- CHK4: Is the mode allowlist defined, and do esc-chat-2 and esc-chat-3 agree on it? — PASS (A1: both name default|acceptEdits|auto, plan denied; PG3/PG4 plus the allowlist grep; esc-chat-3 grep and read-only-reason grep)
- CHK5: Are the rules preserved and checked: run.sh never run, examples relayed verbatim, `.directed`/`.escalated` unchanged? — PASS (esc-chat-3 greps; Do NOT touch)
- CHK6: Is this repo's mode-off posture reconciled with ADR-0036? — PASS (OQ4; ADR draft amends 0036 for this branch only)
- CHK7: Does every Goal clause map to a criterion? — PASS (verbatim display and AskUserQuestion → esc-chat-3; no human-authored file → esc-chat-2 PG1/PG11; no self-approval → PG2/PG3/PG5-PG10 plus the mutation control)
- CHK8: Is P3 specified per commit? — PASS (esc-chat-2 step 8; esc-chat-3 per-commit loop)
- CHK9: Is esc-chat-1 a real ship gate with a branch decided now? — PASS
- CHK10: Is the declined-prompt case defined for both the orchestrator and the audit trail? — PASS (esc-chat-3 step 6; R7; esc-chat-4 criterion "before the human")
- CHK11: Is each criterion non-vacuous? — PASS (the esc-chat-2 mutation control fails the suite when the call line is removed; esc-chat-4 cross-checks its claim against the gate source)

- CHK12: Do esc-chat-1-fix's criteria fail against the current script and pass once the fix lands? — PASS (measured 2026-10-02 at `cbdd204`: the synthetic `gate()` check prints RED today and GREEN with `plan` removed from the loop; the loose-regex and "Verified by the operator" greps each match once today, so their negations fail until the fix)
- CHK13: Is plan's exclusion stated as policy rather than inference, everywhere it appears? — PASS (Amendment A1, esc-chat-1 ship-gate note, esc-chat-1-fix edit 6, esc-chat-2 eligibility comment, esc-chat-3/4 read-only-reason greps)

## Scribe update hint
This is unit `esc-chat-4`. In addition, after esc-chat-2 lands, the
`humanReviewMode` entry's ADR-0036 sentence should note that 0036 is amended
by the new ADR.
