---
name: ac-c6-stale-pin-blocks-rpg-hdg-edits
description: tests/marker-write.test.sh AC-C6 pins reviewed-path-gate.sh + human-decision-gate.sh SHA-256 to commit 33ac79b — breaks CC3 for ANY later commit editing either file
metadata:
  type: project
---

`tests/marker-write.test.sh`'s AC-C6 section (~line 196-205) asserts
`hooks/scripts/reviewed-path-gate.sh` and `hooks/scripts/human-decision-gate.sh`
are byte-identical to pinned commit `33ac79b` (SHA-256 `fc2f32b9...`), to prove
marker-write.sh's OWN commit (spec2-unitC era) made no edit to either gate.
That pin never got relaxed after landing, so it silently became "these two
files must never change again" — which directly contradicts the
2026-09-09-fable-gate-audit-remediation.md plan, whose Steps 4, 8 and 10 all
explicitly edit `reviewed-path-gate.sh`.

**Why this matters:** `bash tests/validate.sh` (CC3, the merge gate) will
FAIL for the first of those steps to land, and reproduce for every one after
it, purely from this stale pin — not from any defect in the step's own diff.
Confirmed live on gate-audit-step4 (2026-09-10): `HEAD~1`'s
`reviewed-path-gate.sh` hash matched the pin exactly; my one-line fallback
change (the only edit Step 4 authorizes) is what trips AC-C6.

**How to apply:** if your unit's affected-files list includes
`hooks/scripts/reviewed-path-gate.sh` or `hooks/scripts/human-decision-gate.sh`
and CC3 fails with `FAIL AC-C6: ... differs from pinned 33ac79b`, this is a
spec gap, not your bug — `tests/marker-write.test.sh` is very likely NOT in
your dispatch's affected-files list, so updating its pin is out of your
declared scope per Boundaries/Escalation. STOP and report it upward (a fresh
[[gate-audit-step4]]-style report) rather than editing that test yourself;
spec-master needs to decide the fix (drop the pin, retarget it at a narrower
invariant, or fold "update AC-C6" into every step's own affected-files list).
Do not assume a later step already fixed it — check `git show
33ac79b:hooks/scripts/reviewed-path-gate.sh | sha256sum` against
`HEAD` yourself.
