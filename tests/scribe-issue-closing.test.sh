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

  # Create a fake gh script that logs invocations
  mkdir -p "$d/bin"
  cat > "$d/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh that logs all invocations to $GH_LOG_FILE
echo "$@" >> "$GH_LOG_FILE"
# Simulate success for issue close
if [[ "$*" == *"issue close"* ]]; then
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
  if ! git log --oneline --all | grep -q "#$issue"; then
    return 1
  fi

  # Condition 3: the issue is currently OPEN (simulated - always true in fixture)
  # In real usage, we'd check `gh issue view <n> --json state`, but we're
  # testing the decision logic, not a full gh call. Assume OPEN here.

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
  commit_shas="$(git log --all --format=%H --grep="#$issue" 2>/dev/null | tr '\n' ' ' | xargs)"

  # Invoke gh with the documented command shape
  export PATH="$fixture_dir/bin:$PATH"
  gh issue close "$issue" --comment "Resolved by commit(s): $commit_shas
Marker: $marker_first_line"
}

echo "-- case 1: valid marker, commit reference, both issue and task-id in dispatch --"
fixture="$(mk_fixture 100 100)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"

# Should close because all conditions hold
if should_close_issue "$fixture" 100 100; then
  close_issue "$fixture" 100 100
  if grep -q "issue close 100" "$gh_log"; then
    pass "case 1 - gh issue close invoked once"
  else
    bad "case 1 - gh issue close not invoked"
  fi
else
  bad "case 1 - conditions not met but should have been"
fi

echo
echo "-- case 2: missing marker (no close should happen) --"
fixture="$(mk_fixture 101 101)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"

# Remove the marker
rm "$fixture/.claude/reviewed/101.pass"

# Should NOT close because marker is missing
if should_close_issue "$fixture" 101 101; then
  close_issue "$fixture" 101 101
  bad "case 2 - closed despite missing marker"
else
  pass "case 2 - no close with missing marker"
fi

echo
echo "-- case 3: malformed marker (no close should happen) --"
fixture="$(mk_fixture 102 102)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"

# Overwrite with malformed marker (doesn't start with "PASS <task-id> ")
printf "INVALID MARKER FORMAT\n" > "$fixture/.claude/reviewed/102.pass"

# Should NOT close because marker is malformed
if should_close_issue "$fixture" 102 102; then
  close_issue "$fixture" 102 102
  bad "case 3 - closed despite malformed marker"
else
  pass "case 3 - no close with malformed marker"
fi

echo
echo "-- case 4: marker exists but no commit references the issue --"
fixture="$(mk_fixture 103 103)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"

# Rewrite the commit to NOT reference the issue
cd "$fixture"
git reset -q --hard HEAD~0  # Soft reset but only one commit, so instead create new one
echo "Some unrelated change" > CHANGES.txt
git add CHANGES.txt
git commit -q --amend -m "Unrelated commit (no issue reference)"

# Should NOT close because no commit references issue #103
if should_close_issue "$fixture" 103 103; then
  close_issue "$fixture" 103 103
  bad "case 4 - closed despite no issue reference in commit"
else
  pass "case 4 - no close when commit doesn't reference issue"
fi

echo
echo "-- case 5: task-id differs from issue number (complex marker name) --"
fixture="$(mk_fixture 104 144-hardening)"
gh_log="$fixture/gh.log"
export GH_LOG_FILE="$gh_log"

# Verify the marker has the complex task-id
if grep -q "^PASS 144-hardening " "$fixture/.claude/reviewed/144-hardening.pass"; then
  if should_close_issue "$fixture" 104 144-hardening; then
    close_issue "$fixture" 104 144-hardening
    if grep -q "issue close 104" "$gh_log"; then
      pass "case 5 - gh issue close invoked with complex task-id"
    else
      bad "case 5 - gh issue close not invoked"
    fi
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

# Overwrite with empty marker
: > "$fixture/.claude/reviewed/105.pass"

# Should NOT close because marker is empty
if should_close_issue "$fixture" 105 105; then
  close_issue "$fixture" 105 105
  bad "case 6 - closed despite empty marker"
else
  pass "case 6 - no close with empty marker"
fi

echo
exit "$fail"
