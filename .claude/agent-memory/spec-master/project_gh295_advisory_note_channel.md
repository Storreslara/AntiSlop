---
name: gh295-advisory-note-channel
description: Issue #295's four sub-items are ALREADY closed and its deferral is recorded in the plan doc; only the systemic channel remains — plus the four hard constraints (gitignore, write-gate, format variance, five-artifact) that bound any design.
metadata:
  type: project
---

Issue #295 ("reviewer's advisory notes on a PASSing review rarely get routed
to spec-master"). Measured 2026-09-01 at `7581ca6`.

## Do not re-scope the four sub-items — they are closed

`docs/plans/2026-08-09-agent-auditor-persona.md:2030` says verbatim: **"Issue
#295's systemic recommendation is deferred and NOT addressed here."** That
round (Steps 11-12+) fixed the four concrete artifacts and built no routing
mechanism. Its own decay table at `:1957-1960` re-verified each sub-item, and
two were already stale when checked (295-3 half-stale, 295-4 already closed by
Step 10 at `22f5bb2`). Independently re-confirmed: the effective-tools formula
at `:269-272` now documents three union terms including `SendMessage`, and
`scripts/agent-audit.sh:367-369,613-615` emits `status=executed|refused`.

**How to apply:** the live scope of #295 is the *systemic half only*. Anyone
citing the four sub-items as evidence of a live defect is reading a stale
issue body — cite the pattern, not the items.

## Four constraints that bound any channel design

1. **`.claude/reviewed/` is gitignored** (`.gitignore:12`, under the "local
   only, not project docs" block; `*.log` at `:3` catches new logs too). The
   300 `.pass` markers and their notes are untracked per-clone state with no
   history and no recovery source. A sweep over them is zero-ceremony but the
   record dies with the clone. Per [[baselines-expire]], an untracked store
   needs a stated recovery-source precondition.
2. **spec-master cannot write there at all.** `reviewed-path-gate.sh` blocked
   four of my own read-shaped commands in this session — any pipe to a
   non-allowlisted program (`sort`, `uniq`, `wc -l <`), any `git`/`rg`, and
   any `*`/backslash it cannot lex. Only bare `ls`/`cat`/`grep`/`test` pass.
   So a disposition ledger or a legacy backfill **cannot** live under
   `.claude/reviewed/` for any persona but the reviewer.
3. **The note heading is near-universal but syntactically varied.** Measured
   over 300 `.pass` markers: 285 multi-line, 266 contain "non-blocking notes"
   case-insensitively, **232** match a loosened line-initial anchor
   `^[#> -]{0,4}[Nn]on-blocking [Nn]ote`, but only **80** match the exact
   `^Non-blocking notes:`. A parser anchored on the exact form misses ~70% of
   note-carrying markers. Any criterion quoting a coverage number must say
   which anchor it used.
4. **Changing the note format is a five-artifact change.** The reviewer's
   write duty lives at `agents/reviewer.md:134` → `.claude/agents/reviewer.md:135`;
   the protocol's "marker MAY carry ... notes" sentence lives at
   `templates/persona-protocol.md:239` → `.claude/persona-protocol.md:240`
   plus six inlined persona mirrors. See
   [[validate-sh-is-a-mirror-parity-check]] and
   [[protocol-amendments-do-not-propagate]]. By contrast spec-master's
   `.fail`-check bullet is only **two** files (`agents/spec-master.md:97` and
   its mirror) — no adapter port exists for spec-master.

## The best existing seam, and the posture that constrains it

`hooks/scripts/marker-verify.sh` is the precedent: a read-only, advisory-only,
always-exit-0, one-line-output marker parser over `lib/state-access.sh`, swept
by `bin/marker-audit.sh` and tested by `tests/marker-verify.test.sh`. Prefer
extending that pair (a `--notes` mode) over adding a second sweep script.

Two records set the posture against anything heavier: **ADR-0024** reduced
*automatic* triggering across the board and made the milestone audit
on-demand-only — which makes #295 strictly worse, since the milestone audit
was the only backstop that ever caught these notes. **ADR-0021** is the
precedent for deferring a hook-based backstop as disproportionate.
Constitution P2 ("prefer deterministic scripts over LLM re-derivation")
favours a script over a pure instruction.

**A tempting option with a fatal write-side snag:** `.claude/agent-memory/` IS
tracked, and spec-master's `MEMORY.md` is auto-loaded every session — the
strongest "reaches spec-master" mechanism in the repo. But the reviewer cannot
be its writer: an agent-memory write dirties the tree and breaks the
reviewer's own `git diff --quiet HEAD` PASS precondition
(`agents/reviewer.md:112`). Any memory-landing design needs a different
write-side owner (orchestrator post-PASS, scribe, or spec-master at sweep
time). See [[pass-note-warnings-do-not-propagate]].

## Two parser defects found after gh295-1 PASSed (Addendum A, 2026-09-01)

The shipped `--notes` parser mis-reads tags reviewers plausibly write. Both
measured against a verbatim copy of `marker-verify.sh:66-94`:

- **Defect A — mis-attribution.** `:78` merges ANY whitespace-leading line into
  the current note, so an indented tagged line inherits the PRECEDING note's
  tag. `- NOTE[code]: a` / `  - NOTE[spec]: b` yields ONE note tagged `code`.
  Worse than loss: the tag is wrong. Population 19 of 233 note sections.
- **Defect B — loss.** `:85` strips exactly one leading list marker, so all of
  `- **NOTE[spec]:** x`, `**NOTE[code]:** x`, `` - `NOTE[spec]:` x ``,
  `- __..__`, `- _.._` classify `untagged`. Population **79 of 233** — the
  larger one, and the house style of this corpus.

**How to apply:** any future note-format work must harden the parser BEFORE
mandating a write format. The store is gitignored (R2) and there is no
backfill, so a note mis-parsed at write time is wrong forever.

**AC1.8 is superseded.** Its `spec=0 code=0` half is a snapshot, and it holds
today only BECAUSE of Defect A — `gh295-1.pass` is the only marker of 301
containing `NOTE[`, and its tags are swallowed as continuations. Never
re-assert `spec=`/`code=`/`markers=` on the live corpus; only `untagged >= 200`
survives. See [[baselines-expire]].
