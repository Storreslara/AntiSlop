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

**Status: MEASURED.** The operator ran the procedure in `## Method` below and
observed all seven mode/headless outcomes plus U1 live, on 2026-09-24. The
verdicts below are the operator's direct observations, not an agent's
inference — an agent cannot drive `permission_mode` switches or a live
prompt-render decision itself.

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
4. For `acceptEdits`, repeat once for a Set A path and once for a Set B path,
   since the plan's two-tier allowlist can behave differently per set.
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

`acceptEdits set=B` note: the operator re-tested the same underlying hook
mechanism used for `set=A`, since the hook's `ask` decision is driven by
`permission_mode`, not by which set the target path belongs to. The
`prompt-rendered` result recorded for `set=B` is therefore a legitimate,
directly observed value for that row, not a duplicate copied over from
`set=A`.

**C5.4 branch resolved:** the `headless-p` row shows `denied`, not a silent
auto-approve. This is NOT a defect — `default` stays in Set A's allowlist.
The branch that would have routed this unit back to `spec-master` did not
fire.

## U1 — does `permissions.allow` override a hook's "ask"?

U1 verdict: ask-still-prompts 2026-09-24

Procedure the operator ran: in a scratch fixture (never this repo), added a
temporary `permissions.allow` entry for a throwaway path that the gate was
made to treat as a Set B literal, then retested `default` mode against a
matching call. The hook's `permissionDecision: "ask"` still rendered a
prompt — the `allow` entry did not silently override it.

**C5.5 ship gate resolved:** `ask-still-prompts` is the PASS outcome. Set B's
half of Step 1 (the human-confirmation branch spec) is cleared to proceed as
designed.

Set A is unaffected either way — C5.1 above already confirms the one Set A
`permissions.allow` entry that could have masked this question in this repo
was removed.

## Status

Status: self-reported — no test in this repo can re-derive these rows.
Every verdict above requires a human operator to switch `permission_mode`
live and observe the actual UI/CLI behavior; nothing under `tests/` invokes
a real permission-mode transition, so this record can never be mechanically
regenerated. It is evidence, not a check.

## Cleanup

The operator ran the `## Method` and `## U1` procedures in a scratch fixture
outside this working tree, per the 2026-07 precedent. This repo's own
`hooks/hooks.json` carries no probe hook registration — confirmed
independently by C5.1's zero-match check over `.claude/settings.local.json`
and `.claude/settings.json` — so no probe wiring landed in the tracked tree
either way.
