#!/usr/bin/env bash
# Standing guard (gh425): a full tests/validate.sh run must not leave the
# real .claude/reviewed/ directory's entry list changed. Regression guard for
# the tests/marker-write.test.sh leak, which planted fixtures into the real
# directory whenever CLAUDE_PROJECT_DIR was set - exactly the condition under
# which the harness runs the suite. See
# docs/plans/2026-09-02-blocked-marker-scoping-gh425.md, F3/F4/R7.
set -uo pipefail
cd "$(dirname "$0")/.."

# Avoid infinite recursion: this test invokes a full nested validate.sh run
# below, which reaches this same test file again. On that nested pass, skip
# straight to a no-op success instead of recursing forever.
if [ -n "${REVIEWED_DIR_LEAK_GUARD_NESTED:-}" ]; then
  exit 0
fi

before="$(ls -1 .claude/reviewed 2>/dev/null | sort)"
CLAUDE_PROJECT_DIR="$(pwd)" REVIEWED_DIR_LEAK_GUARD_NESTED=1 \
  bash tests/validate.sh >/dev/null 2>&1 || true
after="$(ls -1 .claude/reviewed 2>/dev/null | sort)"

if [ "$before" = "$after" ]; then
  echo "OK   .claude/reviewed/ entry list unchanged across a full validate.sh run"
  exit 0
fi

echo "FAIL .claude/reviewed/ entry list changed across a full validate.sh run -"
echo "     a test suite leaked fixtures into the real project directory instead"
echo "     of its own mktemp sandbox. Known past offender: tests/marker-write.test.sh"
echo "     (see docs/plans/2026-09-02-blocked-marker-scoping-gh425.md). Diff:"
diff <(echo "$before") <(echo "$after") | sed 's/^/     /'
exit 1
