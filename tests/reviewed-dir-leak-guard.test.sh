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

# The nested exit code is discarded on purpose: the outer run already checks
# every suite; this run exists only to observe what the suites write.
CLAUDE_PROJECT_DIR="$sandbox" REVIEWED_DIR_LEAK_GUARD_NESTED=1 \
  bash tests/validate.sh >/dev/null 2>&1 || true

if [ -d "$sandbox/.claude/reviewed" ]; then
  leaked="$(find "$sandbox/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"
else
  leaked="(the .claude/reviewed/ directory itself was removed)"
fi

if [ -z "$leaked" ]; then
  echo "OK   no suite wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ during a full validate.sh run"
  exit 0
fi

echo "FAIL a full validate.sh run wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ -"
echo "     a test suite leaked fixtures into the project directory instead of its"
echo "     own mktemp sandbox. Known past offender: tests/marker-write.test.sh"
echo "     (see docs/plans/2026-09-02-blocked-marker-scoping-gh425.md). Entries:"
printf '%s\n' "$leaked" | sed 's/^/     /'
exit 1
