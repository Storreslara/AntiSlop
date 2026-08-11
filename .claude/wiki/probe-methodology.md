# Probe Methodology: Value Space vs. Presence

## The Lesson (from Probe A gap, #139)

When designing an empirical probe to verify a field's behavior in hook
payloads, you must **enumerate the field's value space** — all possible forms
the value can legitimately take — not just verify the field's presence.

### What went wrong

`docs/experiments/2026-07-probe-hook-payloads.md` Probe A asked a narrow
question: *Is `agent_type` present in hook payloads?* It verified that the
field existed by scaffolding a test fixture with `eval/harness/scaffold.sh`,
capturing one observed payload, and finding `"agent_type":"lead-programmer"`.

The gate layer scripts (`reviewed-path-gate.sh`, `stop-gate.sh`,
`reviewer-route-gate.sh`) were then written to match against that bare form
using exact string equality. But Probe A never asked: *What other forms can
this field's value take?*

In production, hook payloads included namespaced forms (`"agent_type":"antislop:lead-programmer"`), which coexist with bare forms in the same session. Every
exact-match comparison against the bare form silently missed the namespaced
cases — a live authorization defect that survived code review and testing
because the test fixture could only produce one form.

### The correction

Probe C (Step 9 of #139) was designed to answer the right question: *What
forms can the value legitimately take, and does the gate layer handle all of
them consistently?* It scaffolded a fixture that actually dispatches personas
via the namespaced form (by enabling the marketplace plugin), captured payloads
from both bare and namespaced dispatch, and verified the gates behave
identically under both forms.

### How to apply

For any future probe of a hook-payload field:

1. **Ask about value space, not just presence.** The question is not "does the
   field exist?" but "what are all the forms this field's value can take in a
   real session?"

2. **Exercise the full value space in your fixture.** If the field can take
   multiple forms (namespaced and bare, structured variants, etc.), your test
   must exercise all of them, not just the form your fixture happens to produce
   by default.

3. **Capture and record the actual payloads.** Include raw JSON from the probe
   in the documentation so the next reader can verify the value space was
   actually exercised, not inferred.

4. **Match the gate logic to the actual value space.** When you write
   matching/comparison code based on the probe's findings, ensure it handles
   every form you discovered, and add a regression criterion to the test suite
   so a future identity-form drift becomes a test failure, not a silent bypass.

### Related

- **ADR 0008** (agent-identity normalization) documents the specific design
  rule that emerged: gates must normalize agent identities by extracting the
  persona-name suffix and comparing suffix-to-suffix (GATE sites) or
  suffix-to-literal (GRANT sites), so both bare and namespaced dispatch works.
- **#139** is the full incident record, including how this was discovered,
  verified, and fixed.
- **R1 (Release atomicity)** in the plan shows why gate changes must be atomic
  in pairs: the flag-creation and flag-clearing sites must land together,
  or intermediate states deadlock.
