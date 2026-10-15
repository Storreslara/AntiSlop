---
name: ptr-u1 completion and carry-forward gaps
description: ptr-u1 (#543, validate.sh quiet output) closed on PASS 720b542; five non-blocking reviewer follow-ups carried forward; full serial validate.sh never run end to end
metadata:
  type: project
---

ptr-u1 (issue #543) reached reviewer PASS at commit 720b542 and was closed 2026-10-15. Quiet mode is now the default for `tests/validate.sh`; `--verbose` / `ANTISLOP_VALIDATE_VERBOSE=1` restores the full stream. Glossary entries for **quiet mode**, **keep override**, and **Full log** were added to `docs/harness-glossary.md`.

**Why:** the reviewer marked these non-blocking, so none gated the close, but each is a gap a later unit or a human may need to act on.

Carry-forward gaps:
- The stub in `tests/validate-quiet.test.sh` ignores its arguments, so a wrapper that forwards `--verbose` to the inner run would not be caught. The `Counts:` values are also never checked. Harmless today because the inner pass reads no arguments.
- Criterion 2's `miss=0` check can't fail on a green run. With KEEP set to match nothing, the real lanes stream still gives `miss=0`. Only the size bounds and criterion 1 carry the filter's correctness.
- Quiet mode has no EXIT trap, so every default run (including every stop-gate `testAndLintCommand` run) leaves a ~250 KB full log in TMPDIR. The plan does not mention the accumulation.
- The frozen DROP `^Test ` hides a failing case's `Test (x):` announcement when any line sits between it and the `✗` line. This is by design under the one-line context rule.
- The full serial `bash tests/validate.sh` was run end to end by neither the implementer nor the reviewer (about 14 min, over the tool ceiling). The wrapper is exercised only through stub-tree cases, and the real section bodies only through the lanes runner.

**How to apply:** before any later unit relies on quiet-mode output, or on `tests/validate.sh` as a stop-gate run, check these. The EXIT-trap and TMPDIR accumulation are the first candidates for a follow-up unit. Do not treat the serial gate as end-to-end verified until someone runs it. Related: [[feedback_verify_plan_premise_freshness]] (the miss=0 gap is a negative claim that looked strong).
