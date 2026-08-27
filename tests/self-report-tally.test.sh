#!/usr/bin/env bash
# Fixture suite for bin/harness-integrity.sh --self-report (Step 7b) and its
# wiring into hooks/scripts/session-start.sh's additionalContext. No claude
# CLI, no live session - canned fixtures with a real throwaway git repo per
# case, since the baseline sha's COMMITTER DATE is what "since the session
# baseline sha" filters audit-log lines against (D4's sha-baseline mechanism,
# applied to a timestamp comparison rather than a content diff).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# make_repo <name> -> echoes a fresh project dir, git-initted, with one
# --allow-empty commit backdated to 2020-01-01T00:00:00Z (both author and
# committer date), so its sha's committer date is fixed and known.
make_repo() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  git -C "$dir" init -q
  GIT_COMMITTER_DATE="2020-01-01T00:00:00Z" GIT_AUTHOR_DATE="2020-01-01T00:00:00Z" \
    git -C "$dir" -c user.email=t@example.com -c user.name=t \
        commit --allow-empty -q -m baseline
  echo "$dir"
}

# T1 - basic tally + baseline filtering: one wip-sentinel line before the
# baseline commit's date (excluded) and one after (counted); one defer: and
# one skip: after the baseline. The skip: reason is REAL free text (as
# stop-gate-core.sh:460 actually writes it - no structured unit-id field),
# naming no unit that carries a marker anywhere.
dir="$(make_repo t1)"
sha="$(git -C "$dir" rev-parse HEAD)"
printf '2019-01-01T00:00:00Z agent=a1 reason=old, before baseline\n' >> "$dir/.claude/wip-audit.log"
printf '2025-01-01T00:00:00Z agent=a2 reason=new, after baseline\n' >> "$dir/.claude/wip-audit.log"
printf '2025-01-02T00:00:00Z defer: still working on it\n' >> "$dir/.claude/review-audit.log"
printf '2025-01-03T00:00:00Z skip: human decided to drop it\n' >> "$dir/.claude/review-audit.log"
out="$(bash bin/harness-integrity.sh "$dir" --self-report "$sha")"
if [ "$out" = "self-report wip-sentinels=1 defers=1 skips=1 abandoned-unrecorded=0" ]; then
  ok "T1 tallies since baseline sha, excludes a pre-baseline wip-sentinel line"
else
  bad "T1 expected 'self-report wip-sentinels=1 defers=1 skips=1 abandoned-unrecorded=0', got '$out'"
fi

# T2 - GUARD, using the reviewer's own gh421 repro: unit gh998 HAS a .fail
# marker, and the real skip: reason names it MID-SENTENCE (not as the first
# word) - "abandoning gh998, it already has a FAIL verdict". No first-token
# or positional extraction can find gh998 here; abandoned-unrecorded must
# stay 0 regardless.
dir="$(make_repo t2)"
sha="$(git -C "$dir" rev-parse HEAD)"
printf 'FAIL gh998 2026-01-01T00:00:00Z\nsome defect\n' > "$dir/.claude/reviewed/gh998.fail"
printf '2025-01-01T00:00:00Z skip: abandoning gh998, it already has a FAIL verdict\n' >> "$dir/.claude/review-audit.log"
out="$(bash bin/harness-integrity.sh "$dir" --self-report "$sha")"
if [ "$out" = "self-report wip-sentinels=0 defers=0 skips=1 abandoned-unrecorded=0" ]; then
  ok "T2 GUARD: a real, mid-sentence unit id with a .fail marker never counts toward abandoned-unrecorded"
else
  bad "T2 expected skips=1 abandoned-unrecorded=0, got '$out'"
fi

# T3 - the OTHER gh421 repro: two skip: lines whose free text has no
# extractable unit id at all - first-token extraction previously misread
# "human" and "superseded" as unit ids. Neither should ever count as
# abandoned-unrecorded (no id is present in the log line to begin with).
dir="$(make_repo t3)"
sha="$(git -C "$dir" rev-parse HEAD)"
printf '2025-01-01T00:00:00Z skip: human abandoned this line of work\n' >> "$dir/.claude/review-audit.log"
printf '2025-01-02T00:00:00Z skip: superseded by a later spec revision\n' >> "$dir/.claude/review-audit.log"
out="$(bash bin/harness-integrity.sh "$dir" --self-report "$sha")"
if [ "$out" = "self-report wip-sentinels=0 defers=0 skips=2 abandoned-unrecorded=0" ]; then
  ok "T3 free-text skip: reasons with no real unit id never inflate abandoned-unrecorded"
else
  bad "T3 expected skips=2 abandoned-unrecorded=0, got '$out'"
fi

# T4 - fallback: an invalid/unresolvable baseline sha (or no git repo at all)
# disarms time-based filtering and tallies the WHOLE log, rather than
# silently reporting zero everywhere.
dir="$tmproot/t4"
mkdir -p "$dir/.claude/reviewed"
printf '2019-01-01T00:00:00Z agent=a1 reason=no git repo here\n' >> "$dir/.claude/wip-audit.log"
out="$(bash bin/harness-integrity.sh "$dir" --self-report deadbeef)"
if [ "$out" = "self-report wip-sentinels=1 defers=0 skips=0 abandoned-unrecorded=0" ]; then
  ok "T4 unresolvable baseline sha -> no filtering, whole log tallied"
else
  bad "T4 expected wip-sentinels=1 with no filtering, got '$out'"
fi

# T5 - all-zero case prints the all-zero line rather than nothing, so a
# caller (session-start.sh) decides on the emit-vs-silent policy itself.
dir="$(make_repo t5)"
sha="$(git -C "$dir" rev-parse HEAD)"
out="$(bash bin/harness-integrity.sh "$dir" --self-report "$sha")"
if [ "$out" = "self-report wip-sentinels=0 defers=0 skips=0 abandoned-unrecorded=0" ]; then
  ok "T5 an empty history reports all-zero counts (always exits 0, per the reporter contract)"
else
  bad "T5 expected all-zero counts, got '$out'"
fi

# T6 - session-start.sh wiring: a non-zero self-report tally is surfaced in
# additionalContext.
dir="$(make_repo t6-wired)"
printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
  > "$dir/.claude/persona-config.json"
printf '2025-01-01T00:00:00Z agent=a1 reason=stuck on something\n' >> "$dir/.claude/wip-audit.log"
rc=0
output=$(printf '%s' '{"hook_event_name":"SessionStart","session_id":"t6","source":"startup"}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh || rc=$?)
if [ "$rc" = 0 ] && echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null \
     | grep -q 'wip-sentinels=1'; then
  ok "T6 session-start.sh surfaces a non-zero self-report tally in additionalContext"
else
  bad "T6 expected wip-sentinels=1 in additionalContext (output: $output)"
fi

# T7 - session-start.sh wiring, negative: an all-zero tally is never surfaced.
dir="$(make_repo t7-silent)"
printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
  > "$dir/.claude/persona-config.json"
rc=0
output=$(printf '%s' '{"hook_event_name":"SessionStart","session_id":"t7","source":"startup"}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh || rc=$?)
ctx="$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
if [ "$rc" = 0 ] && ! echo "$ctx" | grep -q 'self-report'; then
  ok "T7 an all-zero self-report tally is never surfaced in additionalContext"
else
  bad "T7 expected no self-report mention with an all-zero tally (output: $output)"
fi

# T8 - MUTATION CONTROL: bin/harness-integrity.sh always exits 0 for
# --self-report even against a project with no .claude dir at all (dead
# reporter script would abort the whole session-start.sh chain under set -e
# if it exited non-zero and were ever piped/checked strictly).
dir="$tmproot/t8-empty"
mkdir -p "$dir"
rc=0
bash bin/harness-integrity.sh "$dir" --self-report >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
  ok "T8 --self-report exits 0 even with no .claude dir at all"
else
  bad "T8 expected exit 0 against a project with no .claude dir, got rc=$rc"
fi

exit "$fail"
