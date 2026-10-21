Unit: rp-u2

## Objective
Findings B and H (gate correctness), `hooks/scripts/lib/stop-gate-core.sh` and `hooks/scripts/stop-gate.sh`:
- B: `review_inflight_units` counts a review-join stamp as in flight only when its timestamp is exactly
  `YYYY-MM-DDTHH:MM:SSZ` and not later than now. Today `now` and `2099-01-01T00:00:00Z` both count (GNU
  `date -d` accepts them and only the age upper bound is checked).
- H: a reviewer's SubagentStop with `stop_hook_active: true` (the stop that follows a `marker=MISSING`
  block) still runs the review-join consume and the bounded flag clear. Today `stop-gate.sh` exits 0 on
  that field before anything else, so a verdict written after the block never consumes its stamp and the
  pending-review flag stands until a human writes `skip:` (seen for aof-u4, audit lines
  2026-10-21T01:00:02Z to 01:01:31Z). Such a loop-guarded stop never blocks: a still-missing verdict logs
  `loop-guard=allow marker=MISSING unit=<id>` and allows, and marker-commit-check `block` mode does not
  exit 2. Every other stop with `stop_hook_active: true` allows at once, as today. Only an identity that
  passes the reviewer grant clears a flag, as today; a regression case pins it for `explorer`.
- Tests: `tests/stop-gate-review-inflight.test.sh` gains future, non-ISO, `.blocked`, `.escalated`,
  `date -j` fallback, block-message and duplicate-audit-line cases; `tests/review-join.test.sh` gains four
  loop-guard cases. Both are already registered in `tests/validate.sh`.
- The generated core copies (`.claude/hooks/scripts/lib/`, `adapters/codex|cursor/hooks/scripts/lib/`) and
  `.claude/hooks/scripts/stop-gate.sh` change only through `node bin/cli.js --update`. The codex and cursor
  entry scripts are unchanged and never set `loop_guard_active`, so their behaviour is unchanged.
This is spec Step 2.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 2 (rp-u2)" and
"Context", findings B and H. This file is the contract of record. Dispatch after rp-u1; no queued contract
edits these files.

## Affected files
- `tests/stop-gate-review-inflight.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `tests/review-join.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `hooks/scripts/lib/stop-gate-core.sh` (anchors: line matching `    ts="${line%%[[:space:]]*}"`; line matching `            if [ "$mcc_mode" = block ]; then`; line matching `      missing=""`)
- `hooks/scripts/stop-gate.sh` (anchor: line matching `[ "$stop_active" = "true" ] && allow`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/stop-gate.sh`,
  `.claude/hooks/scripts/lib/stop-gate-core.sh`, `adapters/codex/hooks/scripts/lib/stop-gate-core.sh`,
  `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh`, `.claude/agents/*.md` and `.claude/persona-protocol*.md`
  and `.claude/protocol-digest.md` (version stamps only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/stop-gate-review-inflight.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# rp-u2: strict ISO-8601 stamps not in the future, the .blocked/.escalated skips, the date -j fallback,
# the block message's last sentence and the duplicate-audit-line check.
run_stop_err() {
  printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"session_id":"s1"}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/stop-gate.sh 2>&1 >/dev/null || true
}
# (l) future-dated stamp -> blocked
dir="$(make_project l)"; flag "$dir"
printf '2099-01-01T00:00:00Z unit=u1 prior=none prior_mtime=-\n' > "$dir/.claude/.review-join.u1"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(l) future-dated stamp blocks" pass; else check "(l) future-dated stamp blocks (rc=$rc)" fail; fi

# (m) non-ISO timestamp that GNU date accepts -> blocked
dir="$(make_project m)"; flag "$dir"
printf 'now unit=u1 prior=none prior_mtime=-\n' > "$dir/.claude/.review-join.u1"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(m) non-ISO stamp blocks" pass; else check "(m) non-ISO stamp blocks (rc=$rc)" fail; fi

# (n) fresh stamp whose unit has a .blocked marker -> blocked
dir="$(make_project n)"; flag "$dir"; fresh "$dir"; printf 'BLOCKED u1\n' > "$dir/.claude/reviewed/u1.blocked"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(n) .blocked unit is not in flight" pass; else check "(n) .blocked unit is not in flight (rc=$rc)" fail; fi

# (o) fresh stamp whose unit has an .escalated marker -> blocked
dir="$(make_project o)"; flag "$dir"; fresh "$dir"; printf 'ESCALATED u1\n' > "$dir/.claude/reviewed/u1.escalated"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(o) .escalated unit is not in flight" pass; else check "(o) .escalated unit is not in flight (rc=$rc)" fail; fi

# (p) a date with no -d (BSD) -> the date -j fallback parses the stamp, Stop allowed
real_date="$(command -v date)"
mkdir -p "$tmproot/bsd"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = -d ] && exit 1; done\nif [ "${1:-}" = -j ]; then exec %s -u -d "$5" "$6"; fi\nexec %s "$@"\n' "$real_date" "$real_date" > "$tmproot/bsd/date"
chmod +x "$tmproot/bsd/date"
dir="$(make_project p)"; flag "$dir"; fresh "$dir"
rc=0
printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"session_id":"s1"}' \
  | PATH="$tmproot/bsd:$PATH" CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && grep -q 'stop-allowed=review-in-flight units=u1' "$dir/.claude/review-audit.log" 2>/dev/null; then
  check "(p) date -j fallback parses the stamp" pass
else check "(p) date -j fallback parses the stamp (rc=$rc)" fail; fi

# (q) the block message ends with the review-in-flight sentence
dir="$(make_project q)"; flag "$dir"
err="$(run_stop_err "$dir")"
if printf '%s' "$err" | grep -qF 'A reviewer dispatched with a `Unit:` line lets Stop through for 1800 s on its own; no flag write is needed.'; then
  check "(q) block message names the review-in-flight allow" pass
else check "(q) block message names the review-in-flight allow" fail; fi

# (r) two allowed Stops in a row log the review-in-flight line once
dir="$(make_project r)"; flag "$dir"; fresh "$dir"
rc1="$(run_stop "$dir")"; rc2="$(run_stop "$dir")"
n="$(grep -c 'stop-allowed=review-in-flight units=u1' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
if [ "$rc1" = 0 ] && [ "$rc2" = 0 ] && [ "$n" = 1 ]; then check "(r) repeated allow logs one audit line" pass
else check "(r) repeated allow logs one audit line (rc1=$rc1 rc2=$rc2 lines=$n)" fail; fi

exit "$fail"
~~~
2. file: `tests/review-join.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# rp-u2: the reviewer stop that follows a marker=MISSING block carries stop_hook_active; it still
# consumes the stamp and clears the flag, never blocks, and no other identity clears anything.
lg_stop() { # $1 = project dir, $2 = agent_type, $3 = stop_hook_active (true|false) -> rc
  jq -n --arg a "$2" --argjson s "$3" \
    '{hook_event_name:"SubagentStop",agent_type:$a,agent_id:"rev-lg",session_id:"s-lg",stop_hook_active:$s}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1
}
lg_flag() { printf '%s agent=lp1\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$1/.claude/.pending-review.lp1"; }
lg_pass() { printf 'PASS %s %s commit: none criteria: true\n' "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$1/.claude/reviewed/$2.pass"; }

dir="$(make_project loop-guard-consumes)"
run_route_gate "$dir" "$(reviewer_payload $'Unit: lg-a\n\nReview.')" || true
lg_flag "$dir"
rc1=0; lg_stop "$dir" reviewer false || rc1=$?
lg_pass "$dir" lg-a
rc2=0; lg_stop "$dir" reviewer true || rc2=$?
if [ "$rc1" = 2 ] && [ "$rc2" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp1" ] \
   && [ ! -e "$dir/.claude/.review-join.lg-a" ] && grep -q 'join-consumed=lg-a' "$dir/.claude/review-audit.log"; then
  echo "OK   (loop-guard-consumes) the verdict written after a MISSING block is consumed on the stop_hook_active stop"
else
  echo "FAIL (loop-guard-consumes) expected rc1=2, rc2=0, flag and stamp gone (rc1=$rc1 rc2=$rc2)"
  fail=1
fi

dir="$(make_project loop-guard-never-blocks)"
run_route_gate "$dir" "$(reviewer_payload $'Unit: lg-b\n\nReview.')" || true
lg_flag "$dir"
rc=0; lg_stop "$dir" reviewer true || rc=$?
if [ "$rc" = 0 ] && [ -e "$dir/.claude/.pending-review.lp1" ] && [ -e "$dir/.claude/.review-join.lg-b" ] \
   && grep -q 'loop-guard=allow marker=MISSING unit=lg-b' "$dir/.claude/review-audit.log"; then
  echo "OK   (loop-guard-never-blocks) a stop_hook_active reviewer stop with no verdict allows, keeps flag and stamp, logs"
else
  echo "FAIL (loop-guard-never-blocks) expected rc=0, flag and stamp kept, loop-guard line (rc=$rc)"
  fail=1
fi

dir="$(make_project explorer-never-clears)"
run_route_gate "$dir" "$(reviewer_payload $'Unit: lg-c\n\nReview.')" || true
lg_flag "$dir"; lg_pass "$dir" lg-c
rc1=0; lg_stop "$dir" explorer false || rc1=$?
rc2=0; lg_stop "$dir" explorer true || rc2=$?
if [ "$rc1" = 0 ] && [ "$rc2" = 0 ] && [ -e "$dir/.claude/.pending-review.lp1" ] \
   && [ -e "$dir/.claude/.review-join.lg-c" ] && grep -q 'grant-denied hook=stop-gate identity=explorer' "$dir/.claude/review-audit.log"; then
  echo "OK   (explorer-never-clears) an explorer stop, with or without stop_hook_active, leaves flag and stamp"
else
  echo "FAIL (explorer-never-clears) expected rc 0/0 and flag and stamp kept (rc1=$rc1 rc2=$rc2)"
  fail=1
fi

dir="$(make_project loop-guard-gated-agent)"
printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"false"}\n' > "$dir/.claude/persona-config.json"
rc=0; lg_stop "$dir" lead-programmer true || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (loop-guard-gated-agent) a gated agent's stop_hook_active stop still allows at once"
else
  echo "FAIL (loop-guard-gated-agent) expected rc=0 (rc=$rc)"
  fail=1
fi

exit "$fail"
~~~
3. command: `bash -c 'bash tests/stop-gate-review-inflight.test.sh >/dev/null 2>&1; a=$?; bash tests/review-join.test.sh >/dev/null 2>&1; echo "$a $?"'`
   expect: 0
   The red step: it prints `1 1` (cases (l), (m), loop-guard-consumes and loop-guard-never-blocks fail).
4. file: `hooks/scripts/lib/stop-gate-core.sh`
   anchor: line matching `    ts="${line%%[[:space:]]*}"`
   indent: 4
   before:
~~~
    ts="${line%%[[:space:]]*}"
    epoch="$(date -u -d "$ts" +%s 2>/dev/null || date -j -u -f %Y-%m-%dT%H:%M:%SZ "$ts" +%s 2>/dev/null || true)"
    case "$epoch" in ''|*[!0-9]*) continue ;; esac
    [ $(( now - epoch )) -le "$REVIEW_INFLIGHT_MAX_AGE_S" ] || continue
~~~
   after:
~~~
    ts="${line%%[[:space:]]*}"
    # Only the stamp writer's own format counts, never a future time: GNU date -d also accepts
    # words such as "now", and a future stamp would otherwise stay in flight forever.
    [[ $ts =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || continue
    epoch="$(date -u -d "$ts" +%s 2>/dev/null || date -j -u -f %Y-%m-%dT%H:%M:%SZ "$ts" +%s 2>/dev/null || true)"
    case "$epoch" in ''|*[!0-9]*) continue ;; esac
    [ "$epoch" -le "$now" ] || continue
    [ $(( now - epoch )) -le "$REVIEW_INFLIGHT_MAX_AGE_S" ] || continue
~~~
5. file: `hooks/scripts/lib/stop-gate-core.sh`
   anchor: line matching `            if [ "$mcc_mode" = block ]; then`
   indent: 12
   before: `            if [ "$mcc_mode" = block ]; then`
   after: `            if [ "$mcc_mode" = block ] && [ "${loop_guard_active:-false}" != true ]; then`
6. file: `hooks/scripts/lib/stop-gate-core.sh`
   anchor: line matching `      missing=""`
   indent: 6
   before:
~~~
      missing=""
      idx=0
      while [ "$idx" -lt "${#JOIN_UNSATISFIED_UNITS[@]}" ]; do
~~~
   after:
~~~
      if [ "${loop_guard_active:-false}" = true ]; then
        # The stop that follows a block (loop_guard_active, set by the Claude entry script on
        # stop_hook_active): never block a second time; log each unit still missing a verdict, allow.
        for unit in "${JOIN_UNSATISFIED_UNITS[@]}"; do
          state_append_audit_log "review-audit.log" "$(printf '%s loop-guard=allow marker=MISSING unit=%s' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$unit")"
        done
        allow
      fi
      missing=""
      idx=0
      while [ "$idx" -lt "${#JOIN_UNSATISFIED_UNITS[@]}" ]; do
~~~
7. file: `hooks/scripts/stop-gate.sh`
   anchor: line matching `[ "$stop_active" = "true" ] && allow`
   indent: 0
   before:
~~~
stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && allow

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
~~~
   after:
~~~
stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Loop guard (rp-u2). The stop that follows a block carries stop_hook_active. For this project's
# reviewer it still runs the review-join consume and the bounded flag clear, so a verdict written
# after a marker=MISSING block is not lost; the core never blocks such a stop (loop_guard_active).
# Every other stop with stop_hook_active allows at once, as before.
loop_guard_active=false
if [ "$stop_active" = "true" ]; then
  if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" = "reviewer" ] \
     && persona_matches_grant "$agent_type" reviewer; then
    loop_guard_active=true
  else
    allow
  fi
fi
~~~
8. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.194 to 0.31.195 if rp-u1 ran just before).
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Stop gate: strict review-in-flight stamps; a loop-guarded reviewer stop still consumes (rp-u2, VERSION).** hooks/scripts/lib/stop-gate-core.sh: a review-join stamp counts as a review in flight only with an exact `YYYY-MM-DDTHH:MM:SSZ` timestamp not later than now (`now` and future stamps no longer let Stop through forever). hooks/scripts/stop-gate.sh: a reviewer's SubagentStop with `stop_hook_active` (the stop after a `marker=MISSING` block) now runs the review-join consume and flag clear instead of exiting at once, so a verdict written after the block no longer leaves the pending-review flag standing; such a stop never blocks (a still-missing verdict logs `loop-guard=allow`). Other stops are unchanged, and only the reviewer clears flags. New cases in tests/stop-gate-review-inflight.test.sh and tests/review-join.test.sh.
~~~
   Replace `VERSION` with the version that edit 8 wrote.
10. command: `node bin/cli.js --update`
   expect: 0
11. command: `bash -c 'bash tests/stop-gate-review-inflight.test.sh >/dev/null 2>&1 && bash tests/review-join.test.sh >/dev/null 2>&1'`
   expect: 0
12. command: `git add -u && git commit -m "fix(rp-u2): strict review-in-flight stamps; a loop-guarded reviewer stop still consumes its verdict"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `adapters/codex/hooks/scripts/stop-gate.sh`, `adapters/cursor/hooks/scripts/stop-gate.sh` (port loop guards differ; criterion 5)
- `hooks/scripts/lib/state-access.sh`, `hooks/scripts/lib/reviewer-route-gate-core.sh` (flag and stamp writers unchanged; criterion 5)
- `tests/validate.sh` (both tests are already registered; criterion 5)

## Acceptance criteria
1. run: `bash -c 'bash tests/stop-gate-review-inflight.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the line `[ "$epoch" -le "$now" ] || continue`; case (l) fails and stdout is `1`. A second mutation, deleting `[ -e "${dot}/reviewed/${unit}.blocked" ] && continue`, fails case (n).
2. run: `bash -c 'bash tests/review-join.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: restore `[ "$stop_active" = "true" ] && allow` above the new block in hooks/scripts/stop-gate.sh; loop-guard-consumes and loop-guard-never-blocks fail and stdout is `1`.
3. run: `bash -c 'cmp hooks/scripts/lib/stop-gate-core.sh adapters/codex/hooks/scripts/lib/stop-gate-core.sh && cmp hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh && cmp hooks/scripts/lib/stop-gate-core.sh .claude/hooks/scripts/lib/stop-gate-core.sh && cmp hooks/scripts/stop-gate.sh .claude/hooks/scripts/stop-gate.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 10 (`--update`); the first `cmp` reports a difference and the command exits 1.
4. run: `bash -c 'bash tests/adapter-stop-gate-parity.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: set `loop_guard_active=true` unconditionally at the top of the core copy in `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh`; the copies differ and stdout is `1`.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u2)" | tail -1); l=$(git log --format=%H --grep="(rp-u2)" | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md adapters/codex/hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh hooks/scripts/lib/stop-gate-core.sh hooks/scripts/stop-gate.sh package.json tests/review-join.test.sh tests/stop-gate-review-inflight.test.sh `
   mutation: also edit `adapters/cursor/hooks/scripts/stop-gate.sh` in an rp-u2 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u2)" | tail -1); l=$(git log --format=%H --grep="(rp-u2)" | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: no`
   mutation: also edit `templates/persona-protocol.md` in an rp-u2 commit with no bump; stdout reads `version-stamp-check: violation touched: yes`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/review-join.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1-2 add the cases; edit 3 runs them red (`1 1`) before the code edits 4-7.
cause: Claude Code sets `stop_hook_active: true` on the stop that follows a Stop-hook block, and `hooks/scripts/stop-gate.sh:141-142` exited 0 on it before any review-join work. Flags are cleared only in the reviewer branch (`stop-gate-core.sh:397`, identity `reviewer` plus `persona_matches_grant`) and by a `skip:` flag; the `cleared-by=reviewer marker=MISSING` audit line clears nothing, it precedes a block.
loop-safety: the only exits on a loop-guarded reviewer stop are `allow` (config absent, review gating off, `.blocked`/`.escalated`, consume path, the new MISSING path) and the marker-commit-check `exit 2`, which edit 5 disables under the guard. The microworld surfacing block above the reviewer branch is one-shot (watermark), so it cannot loop.
ports: the codex and cursor entry scripts never set `loop_guard_active`; `${loop_guard_active:-false}` keeps their path unchanged. Cursor's `loop_count >= 5` early allow has the same shape; recorded in the spec Risks, not fixed here.
proof: spec-master applied edits 1 to 12 to a scratch clone of cfb7ddac with rp-u1 applied, and again on 8b931f0f (qw-u5 landed) between rp-u1 and rp-u3, using a script that requires each `before:` payload to occur exactly once: every payload matched once, edit 3 printed `1 1`, edit 11 exited 0, and criteria 1 to 6 printed the stated stdout after `VERSION` was replaced. Mutations proven on the clone: deleting the future check fails (l), deleting the `.blocked` skip fails (n), deleting the `date -j` fallback fails (p), dropping the dedupe guard fails (r), restoring the early allow fails loop-guard-consumes and loop-guard-never-blocks. stop-gate-blocked, -escalated, -config-drift, -microworld-skip and -deferred-microworld stay green; no test sends `stop_hook_active: true` today. validate.sh was not run by spec-master.
chained: no queued contract (qw-u5, qw-u6, st-u1 to st-u4) edits any file in this unit's list; st-u3 adds a separate SubagentStop hook (`writer-scope-gate.sh`) and registers it in `hooks/hooks.json`, which this unit does not touch.
prior-fail: aof-u2 (the in-flight allow) FAILed on contract anchors AC2.2/AC2.3, not on code; its AC2.6 reads HEAD and fails on any later commit (note only).
blast-radius: hooks/scripts/lib/stop-gate-core.sh:356-359 (review_inflight_units), :486 (mcc block), :524-532 (MISSING branch), hooks/scripts/stop-gate.sh:141-146; callers: hooks/scripts/stop-gate.sh sources the core; adapters/codex|cursor/hooks/scripts/stop-gate.sh source their generated copies. Line numbers are at cfb7ddac; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.194 after rp-u1 if no fix round bumped; edit 8 adds one to whatever they read when the unit starts (expected 0.31.195). The bump is what makes `--update` regenerate the copies; without it `--update` reports the project already current.
mirrors: generated copies change only through `node bin/cli.js --update` (constitution P2); never hand-edit them.
commit-message: fix(rp-u2): strict review-in-flight stamps; a loop-guarded reviewer stop still consumes its verdict
diagnosis: none
review-packet:
~~~
unit: rp-u2
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim, stop and report the current text. If `node bin/cli.js
--update` does not rewrite the three core copies, or reports one as diverged, quote its output and stop;
do not copy the files by hand. If a gate blocks a command, report it and wait. Anything outside "Affected
files" goes to your report as a proposal.
