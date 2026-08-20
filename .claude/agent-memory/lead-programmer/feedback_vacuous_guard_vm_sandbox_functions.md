---
name: vacuous-guard-vm-sandbox-functions
description: Two recurring reviewer-FAIL patterns in this dashboard test suite - asserting on a response field that doesn't exist, and claiming a vm-sandboxed harness "can't simulate clicks" when the target function is directly callable
metadata:
  type: feedback
---

Two patterns recurred in dash-ux-4's FAIL (`.claude/reviewed/dash-ux-4.fail`),
both worth checking before writing a "verified" comment next to an assertion:

1. **Don't assert against a field the endpoint response never sends.** The
   original guard read `armData.body` off `POST /api/decision/arm`'s 200
   response, but that response is `{ armed: true, expiresInMs }` — no `body`
   field, ever. The assertion always ran against `undefined || ''`, so it
   passed no matter what the server did. Fix: drive the real sink (here,
   follow through with `POST /api/decision/run` and read back the actual
   written file / log line) rather than trusting an endpoint's response
   shape without checking it against the handler source first.

2. **`vm.runInContext` exposes every top-level `function` declaration in the
   injected module script on the sandbox object** — `typeof
   sandbox.someFn === 'function'` is true for any such declaration, so a
   test can call it directly instead of writing "click simulation isn't
   supported" and skipping the assertion. Check this before writing that
   excuse into a test. Fix here: have the test harness's render helper
   return the `sandbox` object itself, then call `sandbox.selectDecisionView(...)`
   directly to drive real state transitions.

**Why:** both defects let a suite exit 0 while testing nothing — the
reviewer caught them via mutation proof (flip the real behavior, confirm the
test goes red; it didn't, twice).

**How to apply:** when writing a test-file guard, (a) trace the assertion's
input back to the actual response/return shape in the source before trusting
it's populated, and (b) before writing a "harness doesn't support X"
justification inside a `vm.runInContext`-based test, check whether the
target function is a top-level declaration in the injected script — if so
it's directly callable on the sandbox. See [[project_gh385_marker_commit_attribution]]
for the neighboring convention on this dashboard's review-audit trail.
