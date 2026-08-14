---
name: measure-the-gate-baseline-first
description: Run tests/validate.sh BEFORE writing criteria that assert it exits 0 — it was already RED on the committed tree at 33c4960, which would have failed every unit of a spec for an unrelated reason.
metadata:
  type: feedback
---

**The rule:** before authoring any acceptance criterion of the form
`bash tests/validate.sh exits 0` (i.e. nearly every unit in this repo), run it
first and record the result. A RED baseline turns every unit of the spec red
for a reason that has nothing to do with that unit, and the reviewer has no way
to tell the difference.

**Why:** measured 2026-08-11 at commit `33c4960` — `tests/validate.sh` exited
**1**. Cause: commit `c6ac6e9` edited `agents/agent-auditor.md` and committed
neither the regenerated `.claude/agents/` mirror nor a version bump, so
`tests/cli-backfill.test.js`'s F2 regression failed. Nothing in the repo
surfaces this; a green gate looked like a safe assumption and was not.

The failure is self-concealing in a second way: because the stale mirror's stamp
still equalled `plugin.json`'s version, a plain `--update` takes its version
fast-path and reports "already current". Only `--update --check` (the
force-the-loop flag, *not* a dry run — it writes) re-renders and clears it.

**How to apply:**
- Run the gate as a first investigation step, alongside reading the code. Treat
  its result as a *measurement with an expiry*, same as any other baseline.
- If RED and the cause is unrelated to your spec, add a mechanical, judgment-free
  first unit that clears it and sequence it as a hard blocker on all the others —
  the exact call this repo's R9 precedent already made once
  (`docs/plans/2026-08-09-agent-auditor-persona.md`, Step 0, and again at
  round 3's Step 11).
- Do NOT fold the clearing work into a feature unit: it drags an unrelated
  version bump into the feature diff and no reviewer can separate them (the
  documented `224` failure mode).
- Related but distinct: [[dont-slice-units-across-a-parity-test]] is about how to
  *slice* a source+mirror change. This memory is about discovering that someone
  else's un-mirrored change has already broken the gate you were about to
  assert on.
