#!/usr/bin/env bash
# Standing guard (gh425, reworked by lgc-1): a full tests/validate.sh run must
# not write into the .claude/reviewed/ directory of the project that
# CLAUDE_PROJECT_DIR names. Regression guard for the tests/marker-write.test.sh
# leak, which planted fixtures there whenever CLAUDE_PROJECT_DIR was set -
# exactly the condition under which the harness runs the suite. See
# docs/plans/2026-09-02-blocked-marker-scoping-gh425.md, F3/F4/R7.
#
# The nested run gets a fresh mktemp project root as its CLAUDE_PROJECT_DIR,
# holding an empty .claude/reviewed/, and the guard fails if anything appears
# there or the directory goes away. It never reads this checkout's own marker
# directory, so a reviewer writing or removing a marker while the nested run
# is in flight cannot cause a false FAIL (watch item j; see
# docs/plans/2026-10-14-leak-guard-concurrency.md). Starting empty also
# catches a leak that overwrites a marker name the project already has.
#
# The guard also FAILs when the nested run does not reach validate.sh's own
# closing summary (vlg-1): a run that aborts part-way would silently shrink
# what the guard observes. A nested run that finishes with failing checks is
# only a NOTE, because the outer run already reports those checks.
#
# Accepted blind spot (docs/plans/2026-10-14-validate-lanes-and-guard-followups.md,
# item 2): a writer that ignores CLAUDE_PROJECT_DIR and writes the marker
# directory relative to the repository root, or under an explicit repo-root
# argument, is not seen here.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Avoid infinite recursion: this test invokes a full nested validate.sh run
# below, which reaches this same test file again. On that nested pass, skip
# straight to a no-op success instead of recursing forever.
if [ -n "${REVIEWED_DIR_LEAK_GUARD_NESTED:-}" ]; then
  exit 0
fi

sandbox="$(mktemp -d)" || exit 1
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.claude/reviewed"

# The nested run's failing checks are not this guard's business: the outer
# run reports every suite itself. What the guard does need is a nested run
# that reached its own closing summary, because a run that aborts part-way
# silently stops observing the suites after the abort point (vlg-1).
# ANTISLOP_VALIDATE_INNER=1 skips validate.sh's skip-summary wrapper, so the
# closing summary line is the last line of the nested output.
nested_out="$sandbox/nested.out"
CLAUDE_PROJECT_DIR="$sandbox" REVIEWED_DIR_LEAK_GUARD_NESTED=1 ANTISLOP_VALIDATE_INNER=1 \
  bash tests/validate.sh >"$nested_out" 2>&1
nested_rc=$?
nested_last="$(grep -v '^[[:space:]]*$' "$nested_out" | tail -n 1)"

status=0
case "$nested_rc:$nested_last" in
  "0:All checks passed.") ;;
  "1:One or more checks FAILED.")
    echo "NOTE the nested validate.sh run reported failing checks (exit 1); the outer run reports them itself" ;;
  *)
    echo "FAIL the nested validate.sh run did not finish (exit $nested_rc; last line: ${nested_last:-(no output)}) -"
    echo "     an aborted run stops observing every suite after the abort point, so"
    echo "     the leak check below covers only part of the suite."
    status=1 ;;
esac

if [ -d "$sandbox/.claude/reviewed" ]; then
  leaked="$(find "$sandbox/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"
else
  leaked="(the .claude/reviewed/ directory itself was removed)"
fi

if [ -n "$leaked" ]; then
  echo "FAIL a full validate.sh run wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ -"
  echo "     a test suite leaked fixtures into the project directory instead of its"
  echo "     own mktemp sandbox. Known past offender: tests/marker-write.test.sh"
  echo "     (see docs/plans/2026-09-02-blocked-marker-scoping-gh425.md). Entries:"
  printf '%s\n' "$leaked" | sed 's/^/     /'
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "OK   no suite wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ during a full validate.sh run"
fi
exit "$status"
