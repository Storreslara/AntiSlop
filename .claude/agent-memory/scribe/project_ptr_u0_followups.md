---
name: ptr-u0 follow-ups
description: ptr-u0 (token-usage agg.py vendoring, #546) reviewer non-blocking notes: baseline doc command line, unpinned window boundary, p90/ZeroDivision/ValueError, host-slug default, unrun serial validate, unmeasured baseline
metadata:
  type: project
---

ptr-u0 PASS (marker 2026-10-15, commit 886785f); issue #546 closed by scribe. Glossary commit 935dbf0 added "token-usage baseline", "first-turn ctx" and "minimum sample" to docs/harness-glossary.md, and a disambiguation note to CONTEXT.md's "token cap" entry (scripts/token-usage/ is not the OutcomeCI token-usage.sh). The reviewer's non-blocking follow-ups, recorded without code change:

- (a) docs/audits/2026-10-15-token-baseline.md:7 lists only `agg.py 21`, but its validate.sh-runs and gate-blocks columns come from agg2.py (ptr-u0b, #547). The table is not reproducible from agg.py alone.
- (b) Test gaps in tests/token-usage.test.sh: the --since/--until boundary is unpinned (`e < until` in in_range can become `<=` and still pass 5/5); p90, the default --root expansion and malformed JSONL are untested.
- (c) agg.py p90 is `xs[int(len*0.9)-1]`, which returns the minimum for n=2. Nearest-rank ceil(0.9n)-1 fixes it; the harness glossary's [[nearest-rank convention]] is the term to align with. The share loop divides by `tot` and raises ZeroDivisionError when every kept dispatch has zero input. A bad ISO value for --since/--until gives a raw ValueError traceback.
- (d) The default --root embeds the host slug `-home-sebas-AntiSlop`. The contract's `[/]home[/]` host-path check (C4) cannot catch the dash form.
- (e) The full serial tests/validate.sh was not run. The lanes run (C5, validate-lanes --lanes 4) first failed on tests/rollout-preflight.test.sh AC14/W9, a `sleep 1` mtime check unrelated to this unit; it passed standalone and on rerun.
- (f) The baseline numbers and the "HEAD 3dfdf2f" label were not re-measured; C3 checks row presence only.

**Why:** none of these block the PASS, but (b) and (c) are correctness gaps in the tool whose numbers feed the persona-token-reduction targets, so they matter before any after-measurement is read against a target.

**How to apply:** before reading an after-measurement against a target, fix (c) and pin the boundary from (b). Before trusting the baseline table, land ptr-u0b and re-measure per (a) and (f). Treat the rollout-preflight AC14 flake in (e) as its own item, not as part of this unit.
