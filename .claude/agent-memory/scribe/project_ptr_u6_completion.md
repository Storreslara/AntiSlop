---
name: ptr-u6-completion
description: ptr-u6 PASS c9313b3 closed #552; reviewer escalation machinery moved to protocol; six open follow-ups
metadata:
  type: project
---

PASS c9313b3 closed #552. agents/reviewer.md now points at `## Fourth verdict: escalate-to-human` in the protocol; probes pinned in tests/fixtures/reviewer-escalation-probes.txt. Glossary added: escalation probe list (harness-glossary); staleness binding already lived in CONTEXT.md, so the duplicate harness-glossary entry was removed. Protocol heading "Durable escalation packet" is a synonym of **Escalation packet** (noted, not renamed).

Open follow-ups (not fixed):
- CHANGELOG ptr-u6 says Codex/Cursor protocol ports "already carry" the moved directives; they lack the approve-route commit: fallback and literal `cp -a`.
- templates/persona-protocol.md ~485-486 "Write neither .pass nor .fail for this verdict" sits in the manifest bullet; "this verdict" is ambiguous.
- Nothing committed reads the probes fixture; consider wiring into adapter-protocol-parity.test.js.
- No test checks the pointer's target heading exists.
- Two adjacent "transcribe, never re-review" paragraphs (~685-708) could merge.
- Removed "never substitute your own judgment" DECISION clause has no exact copy.

**Why:** reviewer non-blocking notes. **How to apply:** check these before the next protocol/reviewer.md edit.
