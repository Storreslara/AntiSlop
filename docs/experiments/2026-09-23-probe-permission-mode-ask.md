# Probe: `permissionDecision: "ask"` across `permission_mode` values (2026-09-23)

Characterization record for Step 5 of
`docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md` (spec
#466, issue #467). Measures what a hook returning `permissionDecision: "ask"`
actually does in each of the six documented `permission_mode` values plus a
headless `-p` run, and the U1 ship-gate question for Set B. Per the
`docs/experiments/2026-07-probe-hook-payloads.md` precedent, any probe hook
wiring lives only in a disposable scratch fixture outside this working tree
and is deleted after capture — never registered in this repo's
`hooks/hooks.json`.

**Status: MEASURED.** On 2026-09-24 the operator ran the procedure in
`## Method` below and observed seven live outcomes — one per documented
`permission_mode` value (6) plus one headless `-p` run — and U1. Those seven
are the operator's direct observations, not an agent's inference: an agent
cannot drive `permission_mode` switches or a live prompt-render decision
itself. The eighth row, `acceptEdits set=B`, is the one exception — it is an
**inference** from the single `acceptEdits` observation, and is labelled as
such below.

Claude Code CLI version, for future staleness-checking: `claude --version`
reports `2.1.281 (Claude Code)` in this repo on 2026-09-24, the same date as
the rows below.

## Method

1. Scaffold a fresh, disposable fixture outside this working tree (following
   `eval/harness/scaffold.sh`'s pattern from the 2026-07 precedent).
2. Register a temporary hook in the fixture's own `.claude/settings.json`
   (never this repo's `hooks/hooks.json`) that always returns
   `{"permissionDecision": "ask", ...}` for a matching `Write`/`Edit` call, so
   the operator can observe the human-facing effect directly.
3. For each of the six documented `permission_mode` values, and once more as
   a headless `claude -p` run, trigger the matching tool call and record
   whether a prompt rendered, the call auto-approved, or it was denied.
4. For `acceptEdits`, record one row per set, since the plan's `permission_mode`
   allowlist is two-tier (Set A is allowed under `acceptEdits`, Set B is not —
   `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`
   :730-733). **Only one `acceptEdits` probe was actually run**, against a
   single generic `target.txt`; the `set=B` row's value is an inference from
   that one run, not a second run. See the `acceptEdits set=B` note under
   `## Characterization rows`.
5. For U1, add a temporary `permissions.allow` entry in the fixture for a
   throwaway path the gate is made to treat as Set B, then observe whether
   the hook's `ask` still renders a prompt or is silently overridden.
6. Discard the fixture, its probe hook, and all captures after recording the
   outcomes here.

## Characterization rows

Each row: `Probe row: <mode> <verdict> <date>`, where verdict is one of
`prompt-rendered` / `auto-approved` / `denied`.

```
Probe row: default prompt-rendered 2026-09-24
Probe row: plan prompt-rendered 2026-09-24
Probe row: acceptEdits set=A prompt-rendered 2026-09-24
Probe row: acceptEdits set=B prompt-rendered 2026-09-24
Probe row: auto prompt-rendered 2026-09-24
Probe row: dontAsk prompt-rendered 2026-09-24
Probe row: bypassPermissions prompt-rendered 2026-09-24
Probe row: headless-p denied 2026-09-24
```

`acceptEdits set=B` note — **this row is an inference, not an observation.**
Exactly one `acceptEdits` probe was run, against a single generic `target.txt`,
and it produced the `set=A` row. No separate Set B target was set up for it, so
there is no fixture classification mechanism to report for this row. The
`set=B` row carries the same value by inference, on these premises:

- The fixture hook is **unconditional** (Method step 2): it returns
  `{"permissionDecision": "ask", ...}` for any matching `Write`/`Edit`
  regardless of mode or target path. It therefore contributes no per-set or
  per-mode variation of its own for the probe to observe.
- What this probe measures is the **harness's handling of an `ask` decision** —
  whether Claude Code renders a prompt for a decision it has already received,
  in a given mode. That handling is keyed on `permission_mode`. "Set A" and
  "Set B" are this repo's own protected-file-path categories (CONTEXT.md); the
  harness knows nothing about them, so they cannot change how it renders an
  `ask` it has been handed.
- The mode-vs-set conditioning belongs to the **production gate**, not to this
  probe's fixture hook: `ask_allowed()`'s `case "$permission_mode"`
  (`docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`
  :730-733) is what excludes Set B under `acceptEdits`, and it governs whether
  the gate emits `ask` at all. Within a single call that is a mode-driven
  decision; the matched set only selects which mode list applies.

So the `set=B` value is sound as a derivation, and nothing here should be read
as a direct observation of that row. Note also that the production gate denies
Set B under `acceptEdits` outright — it never emits `ask` there — so no shipped
code path depends on this row's value.

`bypassPermissions` / `dontAsk` note: these two rows measure U2 (plan doc
:308 — "what does `ask` do under `bypassPermissions` / `dontAsk`?"), which the
plan recorded as unknown for both modes. Measured value, stated as measured:
`prompt-rendered` in both, on 2026-09-24. That is the observation and nothing
more; it is not read here as licence to widen anything. The plan excludes both
modes from both allowlists, so the gate never emits `ask` in either, and that
exclusion is unaffected by these rows.

**C5.4 branch resolved:** the `headless-p` row shows `denied`, not a silent
auto-approve. This is NOT a defect — `default` stays in Set A's
**permission-mode** allowlist. (Set A / Set B in CONTEXT.md are protected
file-path categories; the allowlist meant here is the separate
`permission_mode` one.) The branch that would have routed this unit back to
`spec-master` did not fire. R4 — residual U4, headless `default` mode, which
the plan names Step 5's record as what would close or confirm it — is confirmed
**fail-closed** by this measurement.

## U1 — does `permissions.allow` override a hook's "ask"?

U1 verdict: ask-still-prompts 2026-09-24

Procedure the operator ran: in a scratch fixture (never this repo), added a
temporary `permissions.allow` entry for a throwaway path that the gate was
made to treat as a Set B literal, then retested `default` mode against a
matching call. The hook's `permissionDecision: "ask"` still rendered a
prompt — the `allow` entry did not silently override it.

**Honest gap:** exactly *how* the throwaway path was made to be treated as a
Set B literal inside the scratch fixture was not recorded at capture time, so
that one detail of the procedure cannot be reproduced from this record. It is
stated as a gap rather than reconstructed after the fact.

**C5.5 ship gate resolved:** `ask-still-prompts` is the PASS outcome. Set B's
half of Step 1 (the human-confirmation branch spec) is cleared to proceed as
designed.

Set A is unaffected either way — C5.1 (issue #467; the criterion is stated in
the plan doc, not in this record) already confirms the one Set A
`permissions.allow` entry that could have masked this question in this repo
was removed.

## Status

Status: self-reported — no test in this repo can re-derive these rows.
Every verdict above traces to a human operator switching `permission_mode`
live and observing the actual UI/CLI behavior — the `acceptEdits set=B` row by
inference from one such observation, per its note above. Nothing under `tests/`
invokes a real permission-mode transition, so this record can never be
mechanically regenerated. It is evidence, not a check.

## Cleanup

The operator ran the `## Method` and `## U1` procedures in a scratch fixture
outside this working tree, per the 2026-07 precedent. Two separate claims, each
paired with the check that actually covers it:

- **This repo's own `hooks/hooks.json` carries no probe hook registration.**
  Checked directly: `grep -ic probe hooks/hooks.json` prints `0` (exit 1, no
  matches), run in this repo on 2026-09-24. C5.1 does **not** cover this claim —
  its `jq` reads only `.permissions.allow` inside the two settings files and
  never opens `hooks/hooks.json`.
- **No `permissions.allow` entry names the Set A or Set B literals.** That is
  what C5.1's zero-match check over `.claude/settings.local.json` and
  `.claude/settings.json` shows, and it shows nothing about `hooks/hooks.json`.

So no probe wiring landed in the tracked tree — on the strength of the first
check, not the second.
