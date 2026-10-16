---
name: ptr-u5-completion
description: ptr-u5 PASS closed #554; five open follow-ups (stale cli.js comment, orchestrator pointer, unpinned Microworld pointer, trailer tier, AC17 stdout)
metadata:
  type: project
---

PASS 8867a94 closed #554. Template now 20 sections; lead-programmer reads Microworld bundles via a file pointer.

Open follow-ups (not fixed):
- bin/cli.js ~843-846 reviewer-row comment still places the "flag stays standing" paragraph in Review ownership (stale).
- agents/orchestrator.md ~420 stale pointer; ptr-u12 owns it.
- No test asserts the Microworld pointer at agents/lead-programmer.md ~68-70 resolves; suggest asserting `## Microworld bundles` in tests/protocol-cross-references.test.js.
- Commit trailer names Haiku though implementer tier was sonnet.
- AC17 expected stdout can never match exactly (version-stamp-check appends fields).

**Why:** reviewer notes, deliberately left for later units.
**How to apply:** check these before concluding the area is clean.
