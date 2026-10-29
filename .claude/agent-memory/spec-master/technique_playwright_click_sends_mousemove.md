---
name: technique-playwright-click-sends-mousemove
description: Playwright mouse.click(x,y) dispatches a mousemove even at the pointer's current point; a "stationary click" test must use bare mouse.down()/up() or it re-arms pointer-movement rules and passes vacuously
metadata:
  type: reference
---

Playwright's `page.mouse.click(x, y)` first sends a `mousemove` to (x, y), even when the pointer is already
there. A page rule keyed on "the pointer moved since X" sees that event. A test meant to prove "a click with
no movement is accepted/dropped" must use `mouse.down(); mouse.up()` instead.

**Why:** rfp-u6b (2026-10-29), the label page's in-flight pointer rule: a first draft of B14 passed on the
unfixed page, because the click's own mousemove re-armed labelling. Only running the old page against the
new test (mutation M0) exposed it.

**How to apply:** for any browser case about pointer stillness, also check the comparison is with the
page's integer `clientX/Y` (from a recorded `mousedown`), not Playwright's fractional coordinates; and
always run the pre-fix page against the new case. See [[feedback-verify-own-criteria-nonvacuous]].
