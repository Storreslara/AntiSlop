---
name: grid-test-for-decision-tables
description: A decision table with several interacting dimensions needs a generated cube test with a literal oracle, not hand-picked cells; abt-u21a rounds 3-5 (2026-10-17).
metadata:
  type: feedback
---

When a reviewer finds one missing cell of a Decision table, enumerate the whole cube (N bucket x bad rows x provenance x stall x defect) and generate it in a test whose oracle is written out literally (precedence rules plus per-bucket wording strings), not read from the code under test. Hand cells stay for numeric bands (Fisher, R_tokens).

**Why:** score.py checks N before bad rows, so report.py's per-reason wording said NEEDS MORE DATA where OD-12(a) makes the outcome INCONCLUSIVE at every N; a hand-picked cell list had missed it twice. The fix needed no scorer change: the outcome was already right, only the printed reason differed, so report.py reads status tallies.

**How to apply:** split by contract budget (30000 bytes): code + changed-cell rows first, then hand-cell walk, then grid, each a separate test file. Leave an empty OUT_DIR on success when a later unit git-adds it (git refuses a missing path, accepts an empty dir). `pkill -f tests/validate.s[h]` still kills your own shell; use the bracket form with a separate command.
