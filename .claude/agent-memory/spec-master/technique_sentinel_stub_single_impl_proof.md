---
name: sentinel-stub-single-impl-proof
description: Criterion shape that proves the shipped page calls an injected shared module rather than an inline re-implementation — closes the gh320 D4 "tested code is not shipped code" failure class
metadata:
  type: feedback
---

When a spec adds a shared module that is BOTH `require`d by tests and
injected verbatim into a page (the `feedback-block.js` /
`decision-block.js` / `markdown-lite.js` pattern in
`bin/microworld-dashboard/`), write this criterion:

> Run the client harness with a **stub** of the module's function installed
> as the sandbox global *instead of* the real source, returning a sentinel
> string. Assert the sentinel appears at every site that should call it, and
> at none of the sites that must not.

**Why:** gh320 D4 — `feedback-block.js` was fully unit-tested while the
shipped client re-implemented the same logic inline at `index.html:657-685`.
Three acceptance criteria passed and were **vacuous with respect to shipped
behaviour**; the two implementations had already silently diverged, and that
divergence is what hid a separate missing-feature defect from its own
criterion. Ordinary unit tests cannot detect this — they pass either way.
A sentinel stub cannot: an inline copy never emits the sentinel.

**How to apply:** the stub case does double duty — the same pass proves
positive coverage (all N intended sites) and the negative control (zero
unintended sites), so over-application and under-wiring both fail one
assertion pair. Pair it with a served-page assertion that the injection
placeholder comment was actually consumed
(`body` contains `function <name>`, does not contain `__<NAME>_SOURCE__`).

Existence greps for the placeholder are NOT a substitute: a page can carry
the placeholder and still call its own inline copy.

Related: [[verify-own-criteria-nonvacuous]],
[[dashboard-usability-revision-spec]].
