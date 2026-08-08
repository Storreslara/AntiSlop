# hooks/

`hooks/hooks.json` wires Claude Code lifecycle events to
`hooks/scripts/*.sh`. Ships as a plugin file (auto-active once the plugin
is enabled — unlike `settings.json`, which plugins cannot ship, hence the
separate merge-in-project-settings step for `agent`/`env`/`permissions`).
All scripts reference `${CLAUDE_PLUGIN_ROOT}` so they run from the
installed plugin location, not a per-project copy (that copying only
happens on the npx/non-plugin scaffold path).

| Script | Event | Purpose |
| --- | --- | --- |
| `graph-update.sh` | PostToolUse (Edit\|Write) | Incremental Code Review Graph update on the changed file; no-ops if graph isn't installed. Known gap: only reads `tool_input.file_path`, misses MultiEdit's array form / NotebookEdit. |
| `lint-on-edit.sh` | PostToolUse (Edit\|Write) | Runs the project's configured formatter/linter (`persona-config.json`'s `lintCommand`) on the changed file only; no-ops if unconfigured. |
| `protected-paths.sh` | PreToolUse (Write\|Edit) | Blocks writes to configured `protectedPaths` (migrations, lockfiles, this repo's `.claude-plugin/*` etc.) pending human approval. Advisory only — covers Write/Edit, not Bash (`sed -i` bypasses it). |
| `reviewed-path-gate.sh` | PreToolUse (Bash \| Write\|Edit) | Two matchers, one script: on Bash, allows a command mentioning `.claude/reviewed` only if it's provably read-only or text-only (an allowlist), blocking write-intent commands; on Write\|Edit, blocks any write to the path outright. Both defer to the caller's `agent_type` (`reviewer`, or the main session only in the no-reviewer fallback). Hit live during this repo's own ADAPT — see [ADR 0002](../../docs/adr/0002-reviewed-dir-owned-by-reviewer.md). |
| `reviewer-route-gate.sh` | PreToolUse (Agent) | Mechanically enforces "lead-programmer never spawns/messages reviewer directly"; also blocks dispatching the next gated unit while an earlier one awaits review. |
| `session-start.sh` | SessionStart | Records session-start HEAD sha for `stop-gate.sh`; drift-checks `persona-config.json`'s stamped `pluginVersion` vs. the installed plugin version; re-injects `protocol-digest.md` as additionalContext on resume/compact only. |
| `stop-gate.sh` | Stop + SubagentStop | Core "done = reviewer PASS" enforcement — checks commits/PASS markers before allowing a gated agent (`persona-config.json`'s `gatedAgents`, default `["lead-programmer"]`) to stop. |
| `task-gate.sh` | TaskCompleted | Agent-teams-mode equivalent of stop-gate: requires a reviewer PASS marker before completing any `impl:*` task; planning/research/doc tasks pass through ungated. |

## Historical issues resolved before plan 2026-08-02

**Issue #152** — Block message asserted "spawn the reviewer" as fact. **Resolved
by issues #193–#195** (commits 30da859, 72d8582): the block message now
correctly states *"Unit awaiting review — confirm the reviewer is dispatched
for it, or dispatch it now if not … this hook cannot tell which"* (direction 3
verbatim), and `stop-gate.sh`'s audit-log deduplication stops duplicate
`defer:` lines per turn. No step in plan 2026-08-02 touches this. Recommend
closing #152 with a pointer to #193 and #195.

**Issue #155** — Three observed false positives in `reviewed-path-gate.sh`.
**All resolved by issues #177–#182** (plan
`docs/plans/2026-07-31-reviewed-path-gate-write-intent.md`, Steps 1–6, all
closed). Re-measured live this session: `gh issue create` body and `gh issue
close --comment` citing the marker path are now allowed (✓), read-only
`ls`/`cat` of the marker dir is allowed (✓), real write as `lead-programmer`
is blocked (✓ correct), real write as `reviewer` is allowed (✓ correct). Two
residuals remain and are ratified (not oversights): `git commit -m` naming the
path stays blocked by ADR-0002's ratified ruling (git consults out-of-band
config), and the `${var}`-split path obfuscation still under-blocks (recorded
in [README](../../README.md)'s "Known limitations"). Recommend closing #155
with a pointer to #177–#182 and #185.

## Sticky `defer:` semantics and the audit-log dedupe (issue #190, F3)

`stop-gate.sh`'s pending-review flag (`.claude/.pending-review.<agent-id>`)
accepts two contents from a persona confirming a unit is under review:
`defer: <reason>` or `skip: <reason>`. **A `defer:` is sticky, not
one-shot**: writing it once persists on the flag and permits turn-end
(`Stop`) on **every** subsequent turn — not just the one that wrote it —
until either the reviewer's own `SubagentStop` clears the flag or a
`skip:` deletes it. This was **always** the implemented behaviour; prior
documentation (in `templates/persona-protocol.md`, this repo's own
`stop-gate.sh` comments, and both adapter ports) claimed the opposite —
"that one Stop allowed, review still owed next turn" — and was corrected
in place rather than the code being changed to match the stale prose.

**Why this is safe to leave sticky:** the strong guard lives in
`reviewer-route-gate.sh`, which blocks dispatching the next gated unit on
the pending-review flag's **existence alone** — it never reads the flag's
content, so a `defer:` cannot unblock it. "No next implementation unit
until the reviewer runs" is untouched by the sticky semantics; only the
weaker per-turn nag (which the orchestrator was needlessly re-satisfying
every turn while a background reviewer ran) is relaxed. The orchestrator's
convention as of this pass: write `defer: reviewer dispatched (agent <id>),
awaiting verdict` once, at the moment it dispatches the reviewer in the
background — not on every subsequent turn.

**Audit-log dedupe:** `stop-gate.sh` used to append the flag's content to
`.claude/review-audit.log` on every `Stop`, so a sticky defer produced one
duplicate log line per turn (this is what misled the original efficiency
audit — "5 identical defers in 21 minutes" was one write plus five
turn-ends, not five separate decisions). `stop-gate.sh` now appends a
`defer:` line only when it differs from the immediately preceding log
line (compared after the timestamp field). The fix (2026-08-01) handles
multi-line reasons correctly: flag content is flattened to a single logical
line (newlines and CRs become spaces) before both the comparison and the
write, ensuring the dedupe works for reasons containing `\n`. **Not
deduped** — these remain one line per event, always: the `skip:` branch,
`cleared-by=reviewer`, and `verdict=blocked flags-kept`. A `defer:` that
changes reason, or one separated from an identical earlier line by any
other line (e.g. a `cleared-by=reviewer` in between), is still logged —
only *consecutive identical* `defer:` lines are suppressed.

**Empty-reason rejection (2026-08-01):** Flag content of exactly `defer: `
or `skip: ` (with no text after the colon) is now rejected — `stop-gate.sh`
exits 2, writes no audit record, and for `skip: ` does not delete the flag.
This operationalizes an Amendment A1 ruling after the pending-review
flag's `defer: `/`skip: ` branch was observed accepting such content
despite the hook's own "Empty reason rejected." block message. The
rejection applies only to empty content after the colon; whitespace-only
reasons (e.g. `defer:  ` with two spaces) remain accepted per WIP-sentinel
precedent (non-empty file is sufficient).

## stop-gate.sh: adapter-port behavioural parity (issue #202)

The two adapter ports (`adapters/codex/hooks/scripts/stop-gate.sh`,
`adapters/cursor/hooks/scripts/stop-gate.sh`) had silently diverged from
the main hook above: neither ported the `defer:`-dedupe fix, so a sticky
`defer:` produced a duplicate audit-log line on every `Stop` in those two
ports even after the main hook was fixed. Nothing in the merge gate could
see this — the existing document-parity check
(`tests/adapter-protocol-parity.test.js`) only verifies that canonical
protocol *sections* are present in the doc ports, not that a script
*behaves* correctly.

`tests/adapter-stop-gate-parity.test.sh` closes that gap and is now
registered in `tests/validate.sh` as its own merge-gate check, alongside
the byte-parity check on `lib/agent-identity.sh` and the document-parity
check above — three distinct parity mechanisms, not one generalized past
what it verifies. It drives all three stop-gate scripts (claude, codex,
cursor) through the same defer-dedupe scenario via each port's own event
name and payload shape, asserting the same audit-log record count and exit
code from each. See [modules/adapters.md](adapters.md)'s "Behavioural
parity guard" section for what the guard covers and what it deliberately
does not.

## Measured reviewer tier: `reviewer-tier.sh` is not a hook

`hooks/scripts/reviewer-tier.sh` lives alongside the registered hook
scripts above but is **deliberately absent from `hooks/hooks.json`** — it
is an orchestrator-invoked helper (`reviewer-tier.sh <task-id> <git-range>`
→ prints `sonnet` or `opus`), not a lifecycle hook. It lives under
`hooks/scripts/` only so `tests/validate.sh`'s bash-syntax sweep covers it
automatically. See the glossary entry in [CONTEXT.md](../../CONTEXT.md)
and [ADR 0009](../../docs/adr/0009-reviewer-tier-measured-eligibility.md)
for what it decides and why.

## Config-driven, not hardcoded
Every gate reads `.claude/persona-config.json` at runtime (via `jq`) — the
same hook scripts are generic across every ADAPTed project;
project-specific behavior (which paths are protected, which agents are
gated, whether a reviewer even exists) comes entirely from that file.

## dispatch-hygiene checks: H1–H4

`dispatch-hygiene.sh` is a PreToolUse gate applied at the Agent/orchestrator
seam, checking dispatch prompts before spawn. Configured via
`.claude/persona-config.json`'s `dispatchHygiene` field (`mode`:
`block`/`warn`/`off`, plus optional overrides `maxPromptBytes`/`maxInlineBlockLines`/`requireContract`;
defaults: `block`/30000/80/`true`). Single-use escape hatch: `.claude/.dispatch-override`
(content must start with `override: <reason>`). Checks run in sequence:

- **H1 — Oversize prompt** (default 30000 bytes): blocks dispatches where the
  prompt body exceeds the configured byte limit. Fail-closed; a persona
  cannot self-recover from prompt overflow via retries.
- **H2 — Inlined artifact as fenced block** (default 80 interior lines):
  detects markdown fenced code blocks in the dispatch body and blocks if they
  exceed the interior line limit. Intended to catch artifact inlining; a
  fenced block larger than the threshold is presumed an artifact that should
  have been an external artifact instead.

  **Threshold calibration corpus (H1/H2, recorded 2026-08-07, unit #165):**
  the 30000-byte / 80-line defaults were derived, not invented, from a
  corpus of n=26 real dispatch prompts, measured as: p50 9,341 bytes, max
  14,898 bytes, largest fenced block 41 interior lines. Both thresholds sit
  well above the observed max, leaving headroom for legitimately larger
  dispatches while still catching genuine outliers. The originating plan
  doc (`docs/plans/2026-07-30-token-hygiene-dispatch-gate.md`, which held
  the exact re-runnable `gh issue list … | wc -c` measurement command) no
  longer exists in this repo — confirmed absent via `ls docs/plans/` as of
  this recording, not a mistake in this note. If the thresholds are ever
  retuned, re-derive the command rather than assuming one exists on disk;
  this paragraph preserves only the corpus size and summary statistics, not
  the exact command.
- **H3 — Re-dispatch gate** (best-effort, convention-dependent): fires when
  the dispatch prompt's `Unit:` line (if present) matches a reviewer's marker
  id in `.claude/reviewed/<task-id>.pass`, i.e. when a unit already marked
  done is being re-dispatched. If no marker file exists at all there is
  nothing to check and H3 never fires on that unit (a separate, prior
  condition). Given a marker file exists, the check has six branches, and an
  unverifiable commit preserves pre-v3 behaviour by firing, not by allowing
  re-dispatch: (1) marker lacks a `commit:` field (legacy v2 format) —
  fires; (2) marker has `commit: none` — fires; (3) marker's `commit:` token
  is not a well-formed SHA — fires; (4) marker's commit is well-formed but
  the project directory is not a git work tree (unverifiable) — fires; (5)
  marker's commit sha resolves and is reachable from `HEAD` — fires (unit's
  work is confirmed still live); (6) marker's commit sha resolves and is
  confirmed unreachable from `HEAD` (work was lost to history) — does not
  fire (unit may be re-dispatched). Only fires if the convention `Unit: <id>`
  is reliably followed; read as best-effort protection, not a guaranteed catch.
  Issue #153 originally flagged this as unreliable in a specific way: a
  reviewer could clear pending-review flags without writing *any* marker at
  all, so H3 would have nothing to check against. That specific gap is now
  mechanically closed — see "stop-gate.sh: marker coupling via review-join stamp"
  below, which blocks a reviewer's flag-clear when no verdict marker exists for
  the dispatched unit. That coupling does not itself verify a written marker's id
  matches the *dispatched* unit, so H3 remains best-effort, not provably airtight
  — it just no longer faces silent marker omission.
- **H4 — Dispatch contract audit** (checks labels, not substance): fires when
  `dispatchHygiene.requireContract` is `true` (default `true`) and the
  dispatch prompt lacks the required nine contract elements: `Unit: <id>` as the
  first line, plus eight markdown headings — `## Objective`, `## Retrieval`,
  `## Affected files`, `## Ordered edits`, `## Do NOT touch`,
  `## Acceptance criteria`, `## Pre-resolved context`, and `## Escalation`.
  H4 checks *structure*, not content — an agent can emit all headings and fill
  them with empty strings, and H4 passes. The purpose is to detect accidental
  omissions of required framing; it does not validate that the content is
  complete or sensible. The override sentinel `.claude/.dispatch-override`
  (checked before any H-check runs) exempts a single dispatch from all
  constraints; it is consumed once and not reusable. Caveat: the sentinel is
  `rm -f`'d *before* its reason line is validated
  (`hooks/scripts/dispatch-hygiene.sh:105-107`), so a malformed `override:`
  line burns the sentinel and the checks still run.

## stop-gate.sh: marker coupling via review-join stamp (issue #153, resolved by #226)

The reviewer's flag-clear path (in `stop-gate.sh`'s `SubagentStop` grant
branch) couples the removal of pending-review flags to a verdict-marker check,
enforced via per-unit **review-join stamps** — `.claude/.review-join.<unit-id>`,
one file per unit currently under review. Each stamp is written by
`reviewer-route-gate.sh` when a reviewer is dispatched, and deleted by
`stop-gate.sh` when a format-valid verdict marker is found for that unit. This
per-unit design replaces the prior global clear-watermark, closing concurrency
defects where concurrent reviewers could interfere with each other's verdicts.

**State table for reviewer's SubagentStop**

Evaluated after the `.blocked` early-exit and before flag deletion:

| # | Condition | Classification | Exit | Action |
|---|-----------|----------------|------|--------|
| 1 | No stamps exist at all | **allow**, bootstrap | 0 | Clear flags |
| 2 | Stamp for U; format-valid `.pass` or `.fail` exists; no `prior_mtime` recorded | Satisfied | 0 | Delete stamp, clear flags |
| 3 | Stamp for U; format-valid marker exists; marker mtime **greater than** recorded `prior_mtime` | Satisfied | 0 | Delete stamp, clear flags |
| 4 | Stamp for U; format-valid marker exists; marker mtime **not greater than** recorded `prior_mtime` | Unsatisfied | 2 | Keep flags, block |
| 5 | Stamp for U; marker exists but fails format check (e.g., zero-byte) | Unsatisfied | 2 | Keep flags, block |
| 6 | Stamp for U; no marker at all | Unsatisfied | 2 | Keep flags, block |
| 7 | Stamp unreadable/malformed | Satisfied, fail-open | 0 | Delete stamp, clear flags |

**Governing rule:** A reviewer's stop is allowed iff no stamps exist, or at least one stamp is satisfied.

**Format validation:** Marker must exist, be non-empty, and its first line must
begin `PASS <unit-id> ` or `FAIL <unit-id> ` (matching `task-gate.sh`'s
`marker_valid()` check). A zero-byte `touch` now fails the check.

**Audit vocabulary:**
- `marker-check=bootstrap` — first clear in a project (no stamps yet)
- `marker=MISSING unit=<U>` — marker required for unit U but not found
- `join-consumed=<U>` — satisfied stamp for unit U was deleted
- `cleared-by=reviewer` — successful clear with valid verdict marker on record

**Implementation details:**
- The check runs **after** the existing `.blocked` early-exit (an
  INSUFFICIENT-CONTEXT verdict keeps flags and is not a missing-marker event)
  and **before** the flag deletion.
- Stamp files are enumerated and read once; no subprocess fan-out. Marker format
  is validated using the same `marker_format_valid()` helper as `task-gate.sh`.
- Ports to `adapters/codex/hooks/scripts/stop-gate.sh` and
  `adapters/cursor/hooks/scripts/stop-gate.sh` are verified by
  `tests/adapter-stop-gate-parity.test.sh` (see "Adapter behavioural parity"
  under [CONTEXT.md](../../CONTEXT.md)).
- In codex, the block path routes through `block()`, preserving the loop-guard
  escape; claude and cursor keep bare `exit 2`. See [ADR-0016](../../docs/adr/0016-per-unit-review-join.md).

## dispatch-hygiene.sh: idempotency window for escape-hatch replay (issue #166)

The `.claude/.dispatch-override` escape hatch (single-use operator override of
dispatch blocks) now survives double registration or simultaneous hook fires
via an **idempotency window**, bound to payload identity. The escape hatch
still honours only one operator action, but now does so reliably even when the
hook fires multiple times for the same dispatch.

**Consumption and replay logic:**
- On a valid `override: <reason>` directive, honour it (log key `override=`,
  delete the sentinel), then write a consumption stamp
  `.claude/.dispatch-override.consumed` containing
  `<epoch-seconds> <key> <reason>`.
- On a missing sentinel, honour a **replay** if: (1) the consumption stamp
  exists, (2) its epoch is within a 10-second window, and (3) its `key` equals
  this dispatch's `key`. Log under a distinct audit key `override-replay=`
  (never `override=`), so double-fire recovery stays visible in
  `.claude/dispatch-audit.log`.
- A stale, unparseable, or key-mismatched stamp is ignored and deleted
  opportunistically.

**Payload identity key:** `cksum` of `subagent_type` plus the prompt (which
also folds in the prompt's byte length via `cksum`'s own output), POSIX, no
fallback chain — `dispatch_key="$(cksum <<< "${target_type} ${prompt}" | tr
-d ' ')"`. `subagent_type` is folded in so the same prompt text sent to a
DIFFERENT target is never honoured as a replay of a different dispatch.
Treated as an identity hint, not a security boundary, in code comments: an
attacker capable of crafting a colliding prompt inside a 10-second window has
sufficient capability to write a second override file.

**Window duration:** 10 seconds. Two sequential fires of one tool call are
microseconds apart; 10s is generous slack under load and far below any
plausible interval between two distinct operator dispatches. The key binding
ensures a distinct dispatch cannot reuse a consumed override even within the
window.

**Fail-open floor:** if the stamp cannot be written, the first invocation still
honours and the sibling still blocks — exactly today's behaviour, never worse.

**Audit distinction:** `grep 'override=' .claude/dispatch-audit.log` counts
first honours; `grep 'override-replay=' .claude/dispatch-audit.log` counts
replays. Both keys appear in a double-fire recovery scenario, making the
recovery visible rather than hidden.

**Scope and trade:** This widens the escape hatch in a narrow, controlled way
(10 seconds, payload-bound identity). Two *identical* dispatches inside the
window both pass; two *different* dispatches never do. This is a deliberate
trade: an escape hatch that actually survives the failure modes in issue #166
in exchange for replayability within a bounded window.

**Related context:** ADR-0011 documents the rejected alternative ("extend
`mergeNestedHooksJson` to the standalone path") and explains why it is
structurally unable to fix the named state (two different files, one the CLI
never writes).

**Known issues:**
- **Issue #227** — a narrower follow-up specific to the replay-stamp staleness
  check: a future-dated or negative-delta stamp (from clock skew or a failed
  `date` call) can still trigger the same "unrelated dispatch destroys a live
  replay stamp" defect class on a narrow flank. Non-blocking for #166 itself,
  but rated Major priority by the reviewer who found it.

## reviewed-path-gate write-intent matching

The `reviewed-path-gate.sh` Bash matcher (commit 5836d99, issue #182) identifies write-intent using quote-aware operator detection:

- **command_skeleton()** reduces a command to a length-preserving skeleton where contents of quoted spans and comment bodies become `X`, and quote characters stay. Quote detection and comment detection resolve in one left-to-right pass: a `#` opens a comment only at the start of a word (preceded by nothing, whitespace, or one of `;&|()<>`) and only outside quotes. This prevents fail-open comment mis-detection that would hide `>` characters. This lets operator detection (`>`, `;`, `|`, `&&`) run on the skeleton, so a `>` inside a string literal or comment is read as data, not an operator. Returns non-zero for an unbalanced quote, any backslash anywhere in the command, or a heredoc operator `<<` — unresolvable is never assumed benign (spec R1). For example, `echo a\ b` fails closed simply because it contains a backslash. The rule was widened from `\'`/`\"` to any backslash because an escaped space defeats the word-start test: in `echo a\ # x > <marker>/9.pass` bash treats `a\ #` as one ordinary word, so the `#` opens no comment and the redirection is live — masking it would have been a fail-open.
- **mask_inert_redirections()** blanks two harmless redirection forms: fd duplication (`N>&M`, `>&N`) and exact `/dev/null` redirections, both ending at whitespace/EOS. Every other `>` (including `>>`, `>/dev/null.txt`, spaced `> /dev/null`) still disqualifies.
- **Backtick and command-substitution scans deliberately read raw command text**, not the skeleton. Double quotes do NOT inhibit substitution, so skeletonizing would hide `echo "$(rm .claude/reviewed/9.pass)"` — a fail-open. This is the single most important invariant (test case 24.7).

Key conventions for contributors: operator detection is quote-aware; three nested mechanisms in order:
1. **Backtick/command-substitution scans** deliberately read raw command text (case 24.7) — double quotes do NOT inhibit substitution, so the skeleton would hide `$(rm .claude/reviewed/9.pass)`.
2. **Program allowlist and flag scans** read real text (the conservative direction, cases 26, 28) — text-aware boundary detection for flag tokens.
3. **Expansion refusal** (cases 29.j-29.n) — does NOT read or model text; instead refuses on principle when certain bash metacharacters are present, blocking constructs where shell expansion would forge flags out of text that spells no flag at all.

The exemption set for `>` is **closed** and must not be generalized to "harmless-looking targets" (spec R2). Performance: the shipped span-based skeletonizer is ~200× faster than a per-character loop (86ms vs 17s on 40KB input). Heredoc workaround: `git commit -F -` fails when the message body discusses `.claude/reviewed` alongside any operator; use `git commit -F <file>` instead. 

### Standing regression techniques
Two complementary approaches now anchor the test suite (102 assertions):
- **Case 26 differential sweep**: Probes `command_skeleton()` and `mask_inert_redirections()` against 127 byte values, measuring how many reach a real bash interpreter in a sandbox. Requires an observable effect (file creation/truncation) to detect divergence — when such an effect exists, this is the strongest form.
- **Case 28 exhaustive assertion**: Probes `program_allowed()`'s flag-boundary detector at 127 byte values, measuring blockage. Where an effect cannot be observed in the test (e.g. `git diff --output` outside a repo, which errors without modifying any file), the regression form is one-directional: assert that the blocked-byte set is exact, with mutation controls proving each byte's necessity.

### Institutionalized lesson
This file has produced three bugs of the same general class across #177, #182, and #184: ad-hoc or incomplete text-matching predicates that fail on edge cases. The project's standing answer is to enumerate exactly, not approximate. #184's instance was a distinct sub-class (bash expansion, not just boundary/quote handling), but the lesson remains: each new mechanism must have its own closed enumeration of what it blocks, validated by mutation.
