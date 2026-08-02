#!/usr/bin/env bash
# Behavioral regression suite for scribe's issue-closing duty: verifies the
# conditions under which scribe closes a tracker issue, and that the `gh issue
# close` command is invoked with the correct arguments (including the marker's
# first line and commit sha(s) in a comment).
#
# Fixtures are seeded under mktemp -d with a git repository, valid marker file,
# a commit referencing the issue, and a fake `gh` on PATH recording its argv.
# No live GitHub API, no network.
#
# This test calls helper functions to simulate scribe's decision logic, not the
# scribe persona itself (which requires full Claude Code context). The helper
# function models the condition checks from agents/scribe.md's issue-closing
# section and invokes the documented `gh issue close` command shape.

set -euo pipefail
cd "$(dirname "$0")/.."

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# Helper: set up a test fixture directory with git repo, marker, and commit.
# Usage: mk_fixture <issue_number> [<task_id>]
#   Default task_id is the issue_number (for single-number cases).
mk_fixture() {
  local issue="$1"
  local task_id="${2:-$issue}"
  local d="$tmproot/fixture-$issue"

  mkdir -p "$d/.claude/reviewed"
  cd "$d"

  # Initialize git repo with a commit referencing the issue
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create a commit that references the issue number
  echo "Fix for issue #$issue" > CHANGES.txt
  git add CHANGES.txt
  git commit -q -m "Fix issue #$issue"

  # Create a valid v2 marker (non-empty, first line begins "PASS <task-id> ")
  local marker_ts="2026-08-02T10:30:00Z"
  printf "PASS %s %s criteria: bash tests/validate.sh\n" "$task_id" "$marker_ts" \
    > ".claude/reviewed/${task_id}.pass"

  # Create a fake gh script that logs invocations, and tracks issue state
  # (via $ISSUE_STATE_FILE) so `issue view --json state` and the state flip
  # on `issue close` can be simulated for the OPEN-check and idempotence cases.
  mkdir -p "$d/bin"
  cat > "$d/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh that logs all invocations to $GH_LOG_FILE and simulates issue state.
echo "$@" >> "$GH_LOG_FILE"
if [[ "$1 $2" == "issue view" ]]; then
  if [ -n "${ISSUE_STATE_FILE:-}" ] && [ -f "$ISSUE_STATE_FILE" ]; then
    cat "$ISSUE_STATE_FILE"
  else
    echo "OPEN"
  fi
  exit 0
fi
if [[ "$1 $2" == "issue close" ]]; then
  [ -n "${ISSUE_STATE_FILE:-}" ] && echo "CLOSED" > "$ISSUE_STATE_FILE"
  exit 0
fi
exit 0
EOF
  chmod +x "$d/bin/gh"

  printf '%s' "$d"
}

# Helper: simulate scribe's issue-closing logic for a dispatched unit
# Returns 0 (close issued) or 1 (no close) based on condition checks
# Usage: should_close_issue <fixture_dir> <issue_number> <task_id>
should_close_issue() {
  local fixture_dir="$1"
  local issue="$2"
  local task_id="$3"
  local marker_path="$fixture_dir/.claude/reviewed/${task_id}.pass"
  local blocked_path="$fixture_dir/.claude/reviewed/${task_id}.blocked"

  # Never-close: a .blocked marker exists (reviewer could not confirm)
  if [ -f "$blocked_path" ]; then
    return 1
  fi

  # Condition 1: valid v2 marker exists
  if ! [ -f "$marker_path" ] || ! [ -s "$marker_path" ]; then
    return 1
  fi
  local first_line
  first_line="$(head -n 1 "$marker_path")"
  if [[ ! "$first_line" =~ ^PASS[[:space:]]${task_id}[[:space:]] ]]; then
    return 1
  fi

  # Condition 2: at least one commit reachable from HEAD references the issue
  cd "$fixture_dir"
  if ! git log --oneline HEAD | grep -qE "#$issue([^0-9]|$)"; then
    return 1
  fi

  # Condition 3: the issue is currently OPEN
  local state
  state="$(PATH="$fixture_dir/bin:$PATH" gh issue view "$issue" --json state --jq .state 2>/dev/null)"
  if [ "$state" != "OPEN" ]; then
    return 1
  fi

  # Condition 4: both issue number and task-id were named in dispatch
  # This is enforced at dispatch time, so we assume it's true here.

  return 0
}

# Helper: invoke the actual close logic (call gh with correct arguments)
# Usage: close_issue <fixture_dir> <issue_number> <task_id>
close_issue() {
  local fixture_dir="$1"
  local issue="$2"
  local task_id="$3"
  local marker_path="$fixture_dir/.claude/reviewed/${task_id}.pass"

  cd "$fixture_dir"
  local marker_first_line
  marker_first_line="$(head -n 1 "$marker_path")"

  # Find commit sha(s) referencing the issue
  local commit_shas
  commit_shas="$(git log HEAD --format=%H --grep="#$issue" 2>/dev/null | tr '\n' ' ' | xargs)"

  # Invoke gh with the documented command shape; PATH is scoped to this one
  # call only, so fixture bin/ dirs don't accumulate on PATH across cases.
  PATH="$fixture_dir/bin:$PATH" gh issue close "$issue" --comment "Resolved by commit(s): $commit_shas
Marker: $marker_first_line"
}

# Helper: assert a fixture's gh_log records exactly one `gh issue close <n>`
# invocation, whose --comment cites the marker's first line and commit sha.
# Usage: assert_close_once_with_comment <fixture_dir> <issue> <task_id> <gh_log> <label>
assert_close_once_with_comment() {
  local fixture_dir="$1" issue="$2" task_id="$3" gh_log="$4" label="$5"
  local marker_line sha count

  marker_line="$(head -n 1 "$fixture_dir/.claude/reviewed/${task_id}.pass")"
  sha="$(cd "$fixture_dir" && git log HEAD --format=%H --grep="#$issue")"

  count="$(grep -c "issue close $issue" "$gh_log" || true)"
  if [ "$count" -ne 1 ]; then
    bad "$label - expected exactly one 'issue close $issue' invocation, got $count"
    return
  fi
  if ! grep -qF -- '--comment' "$gh_log"; then
    bad "$label - --comment flag not recorded"
    return
  fi
  if ! grep -qF "$marker_line" "$gh_log"; then
    bad "$label - comment missing marker's first line"
    return
  fi
  if ! grep -qF "$sha" "$gh_log"; then
    bad "$label - comment missing commit sha"
    return
  fi
  pass "$label - gh issue close invoked exactly once with --comment citing marker and sha"
}

echo "-- case 1: valid marker, commit reference, both issue and task-id in dispatch --"
fixture="$(mk_fixture 100 100)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

# Should close because all conditions hold
if should_close_issue "$fixture" 100 100; then
  close_issue "$fixture" 100 100
  assert_close_once_with_comment "$fixture" 100 100 "$gh_log" "case 1"
else
  bad "case 1 - conditions not met but should have been"
fi

echo
echo "-- case 2: missing marker (no close should happen) --"
fixture="$(mk_fixture 101 101)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

# Remove the marker
rm "$fixture/.claude/reviewed/101.pass"

# Should NOT close because marker is missing
if should_close_issue "$fixture" 101 101; then
  close_issue "$fixture" 101 101
  bad "case 2 - closed despite missing marker"
elif [ ! -s "$gh_log" ]; then
  pass "case 2 - no close with missing marker (zero gh invocations)"
else
  bad "case 2 - gh was invoked despite missing marker"
fi

echo
echo "-- case 3: malformed marker (no close should happen) --"
fixture="$(mk_fixture 102 102)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

# Overwrite with malformed marker (doesn't start with "PASS <task-id> ")
printf "INVALID MARKER FORMAT\n" > "$fixture/.claude/reviewed/102.pass"

# Should NOT close because marker is malformed
if should_close_issue "$fixture" 102 102; then
  close_issue "$fixture" 102 102
  bad "case 3 - closed despite malformed marker"
elif [ ! -s "$gh_log" ]; then
  pass "case 3 - no close with malformed marker (zero gh invocations)"
else
  bad "case 3 - gh was invoked despite malformed marker"
fi

echo
echo "-- case 4: marker exists but no commit references the issue --"
fixture="$(mk_fixture 103 103)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

# Rewrite the commit to NOT reference the issue
cd "$fixture"
echo "Some unrelated change" > CHANGES.txt
git add CHANGES.txt
git commit -q --amend -m "Unrelated commit (no issue reference)"

# Should NOT close because no commit references issue #103
if should_close_issue "$fixture" 103 103; then
  close_issue "$fixture" 103 103
  bad "case 4 - closed despite no issue reference in commit"
elif [ ! -s "$gh_log" ]; then
  pass "case 4 - no close when commit doesn't reference issue (zero gh invocations)"
else
  bad "case 4 - gh was invoked despite no issue reference in commit"
fi

echo
echo "-- case 5: task-id differs from issue number (complex marker name) --"
fixture="$(mk_fixture 104 144-hardening)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

# Verify the marker has the complex task-id
if grep -q "^PASS 144-hardening " "$fixture/.claude/reviewed/144-hardening.pass"; then
  if should_close_issue "$fixture" 104 144-hardening; then
    close_issue "$fixture" 104 144-hardening
    assert_close_once_with_comment "$fixture" 104 144-hardening "$gh_log" "case 5"
  else
    bad "case 5 - conditions not met but should have been"
  fi
else
  bad "case 5 - marker format wrong"
fi

echo
echo "-- case 6: empty marker (no close should happen) --"
fixture="$(mk_fixture 105 105)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

# Overwrite with empty marker
: > "$fixture/.claude/reviewed/105.pass"

# Should NOT close because marker is empty
if should_close_issue "$fixture" 105 105; then
  close_issue "$fixture" 105 105
  bad "case 6 - closed despite empty marker"
elif [ ! -s "$gh_log" ]; then
  pass "case 6 - no close with empty marker (zero gh invocations)"
else
  bad "case 6 - gh was invoked despite empty marker"
fi

echo
echo "-- case 7: a .blocked marker present alongside a valid .pass (never close) --"
fixture="$(mk_fixture 108 108)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"
: > "$fixture/.claude/reviewed/108.blocked"

# Should NOT close because a .blocked marker exists, even with a valid .pass
if should_close_issue "$fixture" 108 108; then
  close_issue "$fixture" 108 108
  bad "case 7 - closed despite a .blocked marker present"
elif [ ! -s "$gh_log" ]; then
  pass "case 7 - no close with a .blocked marker present (zero gh invocations)"
else
  bad "case 7 - gh was invoked despite a .blocked marker present"
fi

echo
echo "-- case 8: issue already CLOSED (OPEN check should refuse) --"
fixture="$(mk_fixture 106 106)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"
echo "CLOSED" > "$ISSUE_STATE_FILE"

# Should NOT close because the issue is not OPEN
if should_close_issue "$fixture" 106 106; then
  close_issue "$fixture" 106 106
  bad "case 8 - closed despite issue already being CLOSED"
elif ! grep -q "issue close" "$gh_log" 2>/dev/null; then
  pass "case 8 - no 'issue close' invocation when issue is already CLOSED"
else
  bad "case 8 - gh issue close invoked despite CLOSED state"
fi

echo
echo "-- case 9: idempotent close (already-closed issue is a no-op, no duplicate comment) --"
fixture="$(mk_fixture 107 107)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"
export ISSUE_STATE_FILE="$fixture/issue_state"

if should_close_issue "$fixture" 107 107; then
  close_issue "$fixture" 107 107
  assert_close_once_with_comment "$fixture" 107 107 "$gh_log" "case 9 (first close)"
else
  bad "case 9 - conditions not met on first close attempt"
fi

# Second attempt: the fake gh's state file now reports CLOSED (close_issue's
# gh flipped it), so scribe's OPEN check must refuse - no duplicate comment.
if should_close_issue "$fixture" 107 107; then
  close_issue "$fixture" 107 107
  bad "case 9 - closed a second time (not idempotent)"
else
  count="$(grep -c "issue close 107" "$gh_log" || true)"
  if [ "$count" -eq 1 ]; then
    pass "case 9 - second close attempt is a no-op, no duplicate comment"
  else
    bad "case 9 - expected exactly one 'issue close 107' invocation after second attempt, got $count"
  fi
fi

echo
exit "$fail"
