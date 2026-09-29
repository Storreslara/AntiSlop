---
name: slim-tier-full-only-token
description: tests/cli-backfill.test.js detects full-protocol inlining in slim-tier persona bodies (scribe, explorer, researcher, agent-auditor) by the literal `INSUFFICIENT-CONTEXT`; prose added to a slim-tier agents/*.md must not spell it
metadata:
  type: project
---

`tests/cli-backfill.test.js` (FULL_ONLY constant, two sites) asserts a
slim-tier rendered body does NOT contain `INSUFFICIENT-CONTEXT` — its proxy
for "full protocol was inlined". Adding that uppercase token to
`agents/scribe.md` persona prose (rgo-4) turned validate.sh RED with a
misleading "must NOT inline the full protocol" message.

**Why:** the detector is a token proxy, not a structural check.
**How to apply:** in slim-tier persona prose write "insufficient-context
verdict" (lowercase) instead. After editing an `agents/*.md` at an unchanged
version, `--update` is stamp-only; use `--update --force-render`.
