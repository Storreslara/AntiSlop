---
name: seal-append-guard-is-intentional
description: audit_seal_verify treats a bare unresealed append as ok by design — mutation-proof a seal checker with a rewrite/truncation, not a plain append
metadata:
  type: technique
---

`hooks/scripts/lib/audit-log.sh`'s `audit_seal_verify` only hashes the log's
first `N` lines (`N` = line count at last reseal). Appending new lines after
that point without resealing reads as `ok`, on purpose — this is a tested
GUARD case in `tests/audit-seal.test.sh` ("append without reseal -> ok"), not
an oversight. A plan or spec that says "mutation-prove by appending a line to
a log copy" (item15-2's own dispatch text used this phrasing) will NOT
actually trigger detection if taken literally — the append lands past the
sealed region and audit_seal_verify ignores it. To prove a seal-verification
consumer actually detects tampering, mutate content *within* the sealed
region instead (rewrite an existing line, or truncate) — matching the
library's own already-established `truncated` cases.

**Why:** discovered building `bin/audit-seal-verify.sh` (item15-2,
2026-09-26) — the first literal-append mutation test passed with exit 0
when it should have failed, because the mutation was invisible to the
checker by design, not a bug in the new checker.

**How to apply:** any future unit mutation-proving a consumer of
`audit_seal_verify` (or writing a new one) must rewrite/truncate a copy's
sealed content, not merely append to it. See [[audit_seal_verify_consumer]].
