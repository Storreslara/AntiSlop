# Efficiency audit — Pass 2 convergence re-audit (fresh Fable audit)

Date: 2026-08-01 (audit executed 2026-08-02 UTC)
Auditor: fresh read-only Fable dispatch (unit 206, spec Step 8 of
`docs/plans/2026-08-01-efficiency-audit-remediation-pass2.md`)
Tree audited: `1e1f414` (Steps 1–7 all merged)
Surface: `agents/*.md`, `templates/persona-protocol.md`, `hooks/scripts/*`,
`adapters/codex/`, `adapters/cursor/`, `bin/cli.js` mirror generation,
`.claude/review-audit.log`.

Method: every verdict below was verified against the current source and by
live behavioural probes in throwaway fixture repos / fixture project dirs
(reviewer-tier invocations from a subdirectory with `diff.relative=true`,
piped Stop payloads into the stop-gate scripts, direct node probes of the
cli exports), plus the repo's own suites re-run from scratch:
`tests/reviewer-tier.test.sh` (rc 0), `tests/stop-gate-blocked.test.sh`
(rc 0), `tests/adapter-stop-gate-parity.test.sh` (rc 0),
`tests/cli-backfill.test.js` (rc 0), `bash tests/validate.sh` (rc 0,
"All checks passed"). No prior unit report was taken on its word.

## Part A — convergence verdict (GATING)

- `P2-A1` `reviewer-tier.sh` measurement loss under `diff.relative`: closed.
  `git -c core.quotepath=false -c diff.relative=false` at the single call site
  (`hooks/scripts/reviewer-tier.sh:88`). Live probe: fixture repo with
  `diff.relative=true` set, sensitive `hooks/scripts/thing.sh` in the range,
  invoked from a subdirectory → prints `opus`; a non-sensitive 1-line control
  in the same fixture prints `sonnet`, so the probe is non-vacuous. Suite's
  under-match sweep + mutation control (mc12/mc13 flip to `sonnet` when the
  fix is reverted) confirm the fix is binding. Verdict: CONVERGED
- `P2-A2` `reviewer-tier.sh` marker-directory fail-open on the `.fail`
  disqualifier: closed. Project dir resolves via `CLAUDE_PROJECT_DIR`, else
  `git rev-parse --show-toplevel` (`reviewer-tier.sh:58-62`), and an absent
  marker directory now fails closed (`:72 [ -d "$marker_dir" ] || opus`).
  Live probes: live `u1.fail` + subdirectory cwd + env unset → `opus`;
  marker directory deleted entirely → `opus`. Verdict: CONVERGED
- `P2-A3` persona sources absent from `SENSITIVE_PATHS`: closed. `'^agents/'`
  and `'^\.claude/agents/'` present (`reviewer-tier.sh:34-35`). Live probe: a
  1-line `agents/reviewer.md` diff prints `opus` from the repo root, from a
  subdirectory, and under `diff.relative=true`. Verdict: CONVERGED
- `P2-B1` multi-line `defer:` defeating the audit-log dedupe: closed. Flag
  content is flattened (`tr '\n\r' '  '`, `stop-gate.sh:140`) before both the
  comparison and the write. Live probe: multi-line reason + three Stops → all
  rc 0, exactly one log record (`defer: line1 line2`). Suite covers
  trailing-whitespace, CR, >1KB shapes and a mutation control showing 3
  records with the flattening reverted. Verdict: CONVERGED
- `P2-B2` empty-after-colon `defer: ` / `skip: ` accepted: closed per the
  operator ruling. Exact-empty arm precedes the accepting globs
  (`stop-gate.sh:141-147`). Live probes: `defer: ` → rc 2, nothing logged;
  `skip: ` → rc 2, flag NOT deleted. Matches the "Empty reason rejected."
  block message. (The whitespace-padded variant is still accepted — that is
  the pre-Pass-2 gap tracked in Part B, outside this id's thesis boundary.)
  Verdict: CONVERGED
- `P2-C1` adapter stop-gate ports missing the dedupe and carrying the stale
  block message: closed. Both ports now carry the exact-empty rejection arm,
  the flatten+dedupe, and the confirm-or-defer block message
  (`adapters/codex/.../stop-gate.sh:132-163`,
  `adapters/cursor/.../stop-gate.sh:92-123`). Amendment A2's criteria of
  record both pass live (2a: no `spawn the reviewer` in any of the three
  stop-gate scripts; 2b: all three carry `confirm the reviewer is
  dispatched`). `tests/adapter-stop-gate-parity.test.sh` drives all three
  scripts behaviourally (single-line, multi-line, A→B two-record, empty
  defer/skip) and its mutation control proves the guard fails when a port's
  dedupe is reverted. The three residual repo-wide `spawn the reviewer`
  matches are Keep-unchanged surfaces (route-gate's own true block message
  and the "never blocked" protocol-mirror prose), per Amendment A2 — none is
  a stale stop-gate block message. Verdict: CONVERGED
- `P2-C2` Cursor rules file's false one-shot claim: closed.
  `adapters/cursor/rules/persona-protocol.mdc:83` now reads "this is sticky,
  not one-shot: it permits turn-end on every subsequent `stop` until the
  reviewer's `subagentStop` clears the flag or a `skip:` deletes it".
  Case-insensitive sweep `grep -rni 'one stop allowed' adapters/ templates/
  skills/ hooks/` finds nothing. Verdict: CONVERGED
- `P2-D1` `gatedAgents` force-include silently no-op for a slim-tier persona:
  closed, fail-loudly as scoped. `assertGatedAgentsFullTier`
  (`bin/cli.js:691-694`) throws naming the persona, called from
  `inlineProtocolBlock` (`:732`, the shipped render path);
  `selectProtocolSections` now refuses to answer for the slim tier (`:706-707`
  — verified by direct node probe, throws). `tests/cli-backfill.test.js`
  covers the throw via `renderCleanBody` against the REAL persona-config on
  both render paths, plus a positive control: the shipped config renders
  clean and `.claude/agents/lead-programmer.md` still carries both `## WIP
  sentinel` and `## Pending-review flag`. Mutation control proves the
  assertion is load-bearing. Verdict: CONVERGED
- `P2-E1` ADR-0006 missing its ADR-0009 back-pointer: closed.
  `docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md:74` carries
  `**Amended by ADR-0009:** …` in the Related section, matching ADR-0004's
  form; the 0004→0006→0009 chain now links in both directions. The decision
  text above it is unchanged. Verdict: CONVERGED

Summary: 9 of 9 finding ids CONVERGED; no Pass 2 mechanism was found failing
open, silently diverged, or asserting something false about itself at the
audited tree. The three already-known gaps flagged to this audit (whitespace-
laundered reasons, the Codex loop-guard interaction, the `--update` error
cosmetics) were each re-checked: all are pre-existing or by-design bounds,
none undoes a Pass 2 fix, and each appears in Part B.

## Part B — re-derived backlog inventory (NON-GATING, seeds Pass 3)

Fidelity caveat, stated up front: the original lists (nine "contradictions /
redundant mechanisms", six "heavyweight-model trigger-happiness" items)
existed only in Pass 1's live audit session and are confirmed unrecoverable —
no overlap with the originals can be verified. What follows is re-derived
from the current surface during this audit's own read; item counts differ
from the originals and no claim of reconstruction fidelity is made.

### B.1 Contradictions / redundant mechanisms (re-derived)

1. **Whitespace-laundered `defer:`/`skip:` reasons are accepted.** Reproduced
   live: `defer:   ` (spaces only after the colon) → rc 0 and a log record,
   in the canonical `stop-gate.sh` (the `"defer: "*` glob at `:148` matches a
   whitespace tail; flattening converts newline-only reasons into exactly
   this shape) and, by the same arm structure, both adapter ports. This
   contradicts the intent of the "Empty reason rejected." message while
   satisfying its letter. Already tracked for Pass 3; predates Pass 2's
   thesis boundary. Scope for a fix: trim before the case statement.
2. **Codex loop-guard force-allow bounds every block, including the new
   empty-reason rejection.** `adapters/codex/hooks/scripts/stop-gate.sh:25-33`:
   5 consecutive blocks force an ALLOW. An operator (or agent) that simply
   re-stops against a standing empty `defer: ` flag is force-allowed on the
   6th stop — the operator's "must block" ruling is soft-capped in that port
   by design of the guard. Needs an explicit ruling whether the guard should
   exempt pending-review blocks or stay as-is (it is a workaround for an
   unconfirmed platform primitive).
3. **Cross-unit dedupe collision.** The dedupe compares only the log's last
   line (`stop-gate.sh:153`); two flags with identical text share one record,
   and interleaved distinct units re-log. Known, deferred by Pass 2 itself —
   the fix is a log-format change (agent-id in the record).
4. **Three parallel parity mechanisms with disjoint coverage.** Byte-parity
   (`tests/validate.sh`, `lib/agent-identity.sh` only), doc-section parity
   (`tests/adapter-protocol-parity.test.js`), behavioural parity
   (`tests/adapter-stop-gate-parity.test.sh`, stop-gate defer scenarios
   only). No mechanism observes behavioural drift in the ported
   `reviewer-route-gate.sh`, the loop guards, or any future ported hook —
   the drift class Pass 2 closed for one script remains open for the rest.
5. **Two escape hatches with divergent empty-reason enforcement.** The WIP
   sentinel enforces via `[ -s ]` (accepts whitespace-only content); the
   pending-review flag enforces via exact-match case arms (accepts
   whitespace-padded content). Near-identical semantics, two mechanisms, two
   different holes — the #205 escalation showed even the wiki conflated
   them. Candidate for a single shared reason-validation helper.
6. **`.fail`-based disqualification is encoded twice.** Once in script
   (`reviewer-tier.sh:73`) and once in prose (`agents/orchestrator.md:229`,
   automatic fable disqualifier). Two encodings of one rule, free to drift;
   the task-id-mismatch hole the spec already defers compounds it.
7. **The reviewer persona must persist artifacts but has no Write tool.**
   Markers, `.fail` records, and this very report are written via Bash
   `printf`/heredoc as a named "precedent" — a standing contradiction
   between tool policy and assigned duties that also feeds the
   `reviewed-path-gate.sh` false-positive set (F7, issue #155).
8. **`--update` fail-loudly path prints a repeated/misleading error for the
   slim-tier `gatedAgents` case** (rated cosmetic by two independent reviews
   this session). The throw fires per-render, so the same message repeats
   once per mirror instead of once per run.

### B.2 Heavyweight-model trigger-happiness (re-derived)

1. **`^agents/` + `^\.claude/agents/` in `SENSITIVE_PATHS` makes every
   mirror regeneration opus-mandatory.** Pass 2's own A3 fix means a
   Step-6-type unit (version bump + `node bin/cli.js --update`, purely
   mechanical, deterministic output) and any 1-line persona-prose typo fix
   can never measure `sonnet` again. Correct per the fail-closed thesis, but
   it is a new standing opus trigger on the most mechanical unit shape the
   repo has; a carve-out (e.g. regeneration verified by idempotence check)
   would need its own spec.
2. **A durable `.fail` record disqualifies a unit from `sonnet` and from
   `fable` permanently.** `.fail` records are never deleted on later PASS
   (only `.blocked` is), so a unit that failed once is opus-reviewed forever
   — #205's eventual one-sentence wiki fix carried full opus review plus a
   debug-spec escalation. No decay or reset rule exists.
3. **Plan-level model floors.** Pass 2's R1 declares "No unit in this plan
   is `haiku`-eligible" for all seven units because two surfaces carry prior
   FAILs — a plan-granularity floor where the mechanism (reviewer-tier.sh)
   is deliberately unit-granular.
4. **Tier-2 from-scratch reviewer verification on any prior-`.fail`
   surface** (Methodology rule 2) — opus re-derivation from scratch even for
   doc-only units on that surface.
5. **The roast-pass trigger is judgment prose, not a measurement.**
   `agents/orchestrator.md:250-276` gates the extra `model: fable` advisory
   dispatch on a three-criteria judgment call; Pass 1's F4 ("roast passes
   fire too readily") remains open and unmeasured, unlike the reviewer tier
   which got a deterministic script.
6. **Every pass now terminates in a full-surface fable re-audit by operator
   ruling** (Pass 1's prose bar, Pass 2's Step 8). The per-id re-run rule
   bounds repeats, but the base cost is a full fable dispatch per pass
   confirming mechanisms that already carry binding mutation-controlled
   tests; whether per-step mutation controls could substitute for the
   full-surface gate is itself a Pass 3-scopable question.

### B.3 Read-only / green-tree confirmation

`bash tests/validate.sh` → rc 0 at the audited tree. This audit modified no
tracked file, opened no issue, and created exactly one new untracked file:
this report. Pre-existing working-tree modifications (agent-memory, wiki,
CONTEXT.md and other session artifacts) predate this dispatch and are not
attributable to it.
