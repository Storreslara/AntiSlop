---
name: ptr-u0b follow-ups
description: ptr-u0b (agg2.py and cache.py companions) PASS 2026-10-15 e149c3a, issue #547 closed; glossary entries for cache share and gaps>5min; six non-blocking reviewer follow-ups (persona attribution, main-session date filter, inherited defects, thin tests, baseline column mapping, unrun serial validate)
metadata:
  type: project
---

ptr-u0b PASS (marker 2026-10-15T20:24:47Z, commit e149c3a); issue #547 closed with a citing comment. Glossary: "cache share" and "gaps>5min" added to docs/harness-glossary.md; "first-turn ctx" gained the synonyms `1st-ctx med` (agg.py) and `first-ctx med` (agg2.py) instead of a new term; the "token-usage baseline" entry no longer calls agg2.py "planned". No code, test or plan-doc edits. The reviewer's non-blocking follow-ups, recorded here and not fixed:

- (a) Personas are attributed differently across the three scripts. agg.py credits the fixture's lead-programmer dispatch through the parent Agent call; cache.py lists it as `other n=1`; agg2.py drops it. The three baseline tables therefore count personas differently. The fix is to port agg.py's parent-Agent attribution into cache.py and agg2.py.
- (b) agg2.py's main-session (orchestrator) section (around lines 114-133) filters by file mtime only and ignores --since/--until. The baseline doc's "repeat with --since" after-measurement would report unfiltered orchestrator numbers. The fix is to apply in_range to main-session records.
- (c) Inherited part-1 defects: the p90 index at agg2.py:110 returns the minimum when n=2; cache.py:77 divides by a total that can be zero (ZeroDivisionError); a bad --since/--until date gives a raw ValueError traceback in both scripts; cache.py:46 has no try/except around json.loads, so one malformed line stops the run (agg2.py has one).
- (d) tests/token-usage.test.sh:48, the sixth case, checks only the exit status. Nothing exercises --since/--until, --repo, or the empty-root `sessions=0` path, and no output value is asserted.
- (e) docs/audits/2026-10-15-token-baseline.md still does not say which command produced each table column. Command lines were added; the column mapping was not.
- (f) The full serial validate.sh was not run. The first validate-lanes run (--lanes 4) failed on the flaky 100 ms TTL timing test in tests/microworld/dashboard-decision-run.test.js Test 5, which passed 3 of 3 alone and was clean on the second run. The serial run exceeds the 600000 ms ceiling.

Process note: `gh issue close --comment` takes a string only, so my first close call ran with an empty comment and no citing text. The issue was briefly CLOSED with no comment; the citing comment was posted afterwards with `gh issue comment --body-file` (issue 547 now has exactly one comment). Next time, post the comment first, then close.

**How to apply:** when a later unit touches these scripts, check (a)-(f) first. The baseline's persona counts are not comparable across the three tables until (a) is fixed.
