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

**Status at authoring time: SKELETON ONLY.** The rows below are placeholders.
None of the seven mode/headless outcomes, and no U1 outcome, has been
observed yet — an agent cannot drive `permission_mode` switches or a live
prompt-render decision itself. See `## Operator procedure` below.

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
`prompt-rendered` / `auto-approved` / `denied` / `PENDING-OPERATOR`.

```
Probe row: default PENDING-OPERATOR 2026-09-24
Probe row: plan PENDING-OPERATOR 2026-09-24
Probe row: acceptEdits set=A PENDING-OPERATOR 2026-09-24
Probe row: acceptEdits set=B PENDING-OPERATOR 2026-09-24
Probe row: auto PENDING-OPERATOR 2026-09-24
Probe row: dontAsk PENDING-OPERATOR 2026-09-24
Probe row: bypassPermissions PENDING-OPERATOR 2026-09-24
Probe row: headless-p PENDING-OPERATOR 2026-09-24
```

Note per C5.4: if the `headless-p` row above comes back showing a silent
auto-approve, that is not a residual but a defect — `default` must leave the
Set A allowlist and this unit routes back to `spec-master`. Not yet decided;
`PENDING-OPERATOR`.

## U1 — does `permissions.allow` override a hook's "ask"?

U1 verdict: PENDING-OPERATOR 2026-09-24

Procedure the operator must run: in a scratch fixture (never this repo), add
a temporary `permissions.allow` entry for a throwaway path that the gate is
made to treat as a Set B literal, then trigger a matching call and observe
whether the hook's `permissionDecision: "ask"` still renders a prompt or is
silently overridden by the allow entry. Record exactly one of:

- `ask-still-prompts` -> Set B's half of Step 1 ships.
- `allow-silently-wins` -> Set B's half of Step 1 DOES NOT SHIP; this unit
  routes back to `spec-master`, and this finding is itself the reason.

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

No probe fixture has been built or discarded yet — the operator procedure in
`## Method` and `## U1` above has not been run. Once it is, this section
should be updated to confirm the scratch fixture (hook scripts, settings.json
edits, captures) was deleted after capture, exactly as the 2026-07 precedent
records.
