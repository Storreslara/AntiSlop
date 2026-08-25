---
name: technique-deterministic-date-stub-for-race-tests
description: how to write a deterministic regression test for a same-second/timing-collision bug in a bash script that calls `date`
metadata:
  type: project
---

To regression-test a timing-dependent collision (e.g. two script runs in the
same wall-clock second producing the same `date`-derived filename and one
clobbering the other), don't rely on running the script twice fast and
hoping the race lands — that's flaky. Instead, put a stub `date` executable
earlier in `PATH` for just that test's invocations, e.g.:

```bash
stubdir="$tmproot/stub-date-collision"
mkdir -p "$stubdir"
cat > "$stubdir/date" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-u" ] && [ "$2" = "+%Y%m%dT%H%M%SZ" ]; then
  echo "20260101T000000Z"; exit 0
fi
exec /usr/bin/date "$@"
EOF
chmod +x "$stubdir/date"
PATH="$stubdir:$PATH" "$script" --apply ...
```

The stub only special-cases the exact `date` invocation whose output drives
the collision (match on argv, not just presence), and falls through to the
real `/usr/bin/date` (absolute path, to avoid re-entering the stub) for
everything else the script needs (e.g. `date +%s` for retention/cutoff
math). This forces the collision deterministically on every run instead of
depending on real timing.

**Why:** used for gh409 (bin/human-review-cleanup.sh archive-name collision)
— fixing the collision (counter-suffix on clobber) needed a test proving the
fix, but the bug is inherently a same-second race. A real two-invocations-
fast test would be flaky in CI.

**How to apply:** any bash script under test that computes a filename or
identity from `date` and where a collision/race is the exact defect being
regression-tested. Not needed for ordinary "this ran and produced X" tests —
only for tests whose entire point is forcing a timing collision.
