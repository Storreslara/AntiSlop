#!/usr/bin/env bash
# Fixture-driven test for hooks/scripts/microworld-rerun.sh - the PostToolUse
# (Edit|Write) microworld rerun hook. Canned hook-input JSON piped to the
# script against throwaway fixture projects; the hook is EXECUTED, never
# source-inspected. Also carries the executable relocation proof (case f) that
# the escalation packet depends on.
#
# Unit A (async rerun): the hook now enqueues and returns immediately (always
# exit 0); actual bundle/watch-map execution happens in a detached background
# drain loop. wait_for_drain polls for that loop's completion before a test
# asserts on the audit log. Blocking (exit 2) moved downstream to
# stop-gate.sh's deferred-result reporting (tests/stop-gate.test.sh) - it is
# NOT re-asserted here.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

hook=hooks/scripts/microworld-rerun.sh

make_project() {
  # $1 = case name -> echoes a fresh project dir with one editable source file
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude" "$dir/src"
  printf 'source\n' > "$dir/src/app.js"
  echo "$dir"
}

make_bundle() {
  # $1 = project dir, $2 = slug, $3 = watch glob, $4 = run.sh final exit code
  # The fixture run.sh is RELOCATABLE by construction: it resolves its own
  # inputs/expected via $(dirname "$0"), never via the cwd.
  local b="$1/microworlds/$2"
  mkdir -p "$b/inputs" "$b/expected"
  printf '{"unit":"%s","watch":["%s"],"description":"fixture bundle","timeoutSeconds":10}\n' \
    "$2" "$3" > "$b/manifest.json"
  printf 'ok\n' > "$b/inputs/sample.txt"
  printf 'ok\n' > "$b/expected/sample.txt"
  cat > "$b/run.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
here="\$(cd "\$(dirname "\$0")" && pwd)"
diff -q "\$here/inputs/sample.txt" "\$here/expected/sample.txt" >/dev/null
exit $4
EOF
  chmod +x "$b/run.sh"
}

run_hook() {
  # $1 = project dir, $2 = project-relative edited path -> returns the hook's
  # exit code (always 0 once a bundle/entry is merely enqueued); stderr lands
  # in $tmproot/stderr.txt
  local rc=0
  printf '{"tool_input":{"file_path":"%s"}}' "$1/$2" \
    | CLAUDE_PROJECT_DIR="$1" bash "$hook" 2>"$tmproot/stderr.txt" || rc=$?
  return "$rc"
}

wait_for_drain() {
  # $1 = project dir, $2 = dot-dir (default .claude) -> polls up to ~10s for
  # the async drain loop's lock to clear (queue fully processed).
  local dir="$1" dot="${2:-.claude}" lock="${1}/${2:-.claude}/microworld-queue/.runner.lock" i
  for i in $(seq 1 50); do
    [ -d "$lock" ] || return 0
    sleep 0.2
  done
  return 0
}

audit_lines() {
  # $1 = project dir -> number of audit lines (0 when the log does not exist)
  local log="$1/.claude/microworld-audit.log" n
  [ -f "$log" ] || { echo 0; return 0; }
  n="$(wc -l < "$log")"
  echo "${n:-0}"
}

# (a) no microworlds/ dir -> exit 0, no audit log written at all
dir="$(make_project no-bundles)"
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/microworld-audit.log" ]; then
  echo "OK   (a) no microworlds/ dir -> exit 0 and no audit log written"
else
  echo "FAIL (a) expected exit 0 with no audit log (rc=$rc log-exists=$([ -e "$dir/.claude/microworld-audit.log" ] && echo yes || echo no))"
  fail=1
fi

# (b) an edit matching NO manifest watch glob -> exit 0, no audit line
dir="$(make_project no-match)"
make_bundle "$dir" widget 'lib/*.js' 0
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 0 ] && [ "$(audit_lines "$dir")" = 0 ]; then
  echo "OK   (b) edit matching no watch glob -> exit 0, no audit line"
else
  echo "FAIL (b) expected exit 0 with no audit line (rc=$rc lines=$(audit_lines "$dir"))"
  fail=1
fi

# (c) an edit matching a bundle whose run.sh exits 0 -> hook returns 0
#     IMMEDIATELY (enqueue-and-return); after the drain loop finishes, a
#     result=pass line is on the audit log.
dir="$(make_project pass)"
make_bundle "$dir" widget 'src/*.js' 0
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=pass file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (c) matching bundle whose run.sh exits 0 -> exit 0 and, after the drain, a result=pass audit line"
else
  echo "FAIL (c) expected exit 0 and a result=pass audit line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (d) an edit matching a bundle whose run.sh exits 1 -> hook STILL returns 0
#     immediately (it is a reporter that no longer knows the result at
#     return time - see the core's own header). After the drain loop
#     finishes, a result=fail audit line is recorded; deferred BLOCKING on
#     this result is stop-gate.sh's job, asserted in tests/stop-gate.test.sh,
#     not here.
dir="$(make_project fail)"
make_bundle "$dir" widget 'src/*.js' 1
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=fail file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (d) matching bundle whose run.sh exits 1 -> hook exit 0 (deferred), result=fail logged after the drain"
else
  echo "FAIL (d) expected exit 0 immediately plus a deferred result=fail line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (d2) a matched bundle that exceeds its manifest timeoutSeconds -> hook
#      exit 0 immediately; after the drain, a result=timeout line (distinct
#      from the plain-failure result)
dir="$(make_project timeout)"
make_bundle "$dir" widget 'src/*.js' 0
printf '{"unit":"widget","watch":["src/*.js"],"timeoutSeconds":1}\n' \
  > "$dir/microworlds/widget/manifest.json"
printf '#!/usr/bin/env bash\nsleep 30\n' > "$dir/microworlds/widget/run.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=timeout file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (d2) a bundle exceeding timeoutSeconds -> hook exit 0 (deferred), result=timeout logged after the drain"
else
  echo "FAIL (d2) expected exit 0 immediately plus a deferred result=timeout line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (c2) a matching, hash-verified .countersign for the bundle's run.sh ->
#      the deferred result line carries authority=reviewer
dir="$(make_project countersigned)"
make_bundle "$dir" widget 'src/*.js' 0
mkdir -p "$dir/.claude/reviewed"
hash="$(sha256sum "$dir/microworlds/widget/run.sh" | cut -d' ' -f1)"
printf 'COUNTERSIGN widget 2026-08-26T00:00:00Z runsh: %s\n' "$hash" \
  > "$dir/.claude/reviewed/widget.countersign"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=pass file=src/app.js authority=reviewer' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (c2) matching countersign -> deferred result line carries authority=reviewer"
else
  echo "FAIL (c2) expected an authority=reviewer result line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (c3) no countersign at all -> authority=self (never self-declarable as reviewer)
dir="$(make_project uncountersigned)"
make_bundle "$dir" widget 'src/*.js' 0
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=pass file=src/app.js authority=self' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (c3) no countersign -> deferred result line carries authority=self"
else
  echo "FAIL (c3) expected an authority=self result line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (c4) a countersign exists but run.sh was edited AFTER it was written -> the
#      hash no longer matches, invalidating the countersign back to authority=self
dir="$(make_project stale-countersign)"
make_bundle "$dir" widget 'src/*.js' 0
mkdir -p "$dir/.claude/reviewed"
printf 'COUNTERSIGN widget 2026-08-26T00:00:00Z runsh: %s\n' "$(printf 'a%.0s' {1..64})" \
  > "$dir/.claude/reviewed/widget.countersign"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=pass file=src/app.js authority=self' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (c4) run.sh edited after countersigning -> invalidated back to authority=self"
else
  echo "FAIL (c4) expected an authority=self result line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (e) a bundle with a malformed manifest.json -> exit 0 (fail open) and a
#     logged line, SYNCHRONOUSLY (infrastructure checks are not deferred -
#     they are cheap, no subprocess involved)
dir="$(make_project malformed)"
mkdir -p "$dir/microworlds/broken"
printf '{"unit":"broken","watch":["src/*.js",,,\n' > "$dir/microworlds/broken/manifest.json"
printf '#!/usr/bin/env bash\nexit 1\n' > "$dir/microworlds/broken/run.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 0 ] \
   && grep -q 'unit=broken result=error' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (e) malformed manifest.json -> exit 0 (fail open) and a logged line"
else
  echo "FAIL (e) expected exit 0 plus a logged error line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (e2) a matched bundle with NO run.sh -> exit 0 (fail open) and a logged
#      line, SYNCHRONOUSLY
dir="$(make_project no-run-sh)"
make_bundle "$dir" widget 'src/*.js' 0
rm "$dir/microworlds/widget/run.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=error .*missing-run-sh' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (e2) matched bundle with no run.sh -> exit 0 (fail open) and a logged line"
else
  echo "FAIL (e2) expected exit 0 plus a missing-run-sh line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (f) RELOCATION - the same fixture bundle copied to a second path outside
#     microworlds/ (mimicking the Step 4 escalation packet) and invoked directly
#     as `bash <copied-path>/run.sh` from the project root exits with the SAME
#     status as the original. Asserted in BOTH directions (a passing and a
#     failing bundle) so "same status" cannot hold vacuously.
dir="$(make_project relocate)"
make_bundle "$dir" good 'src/*.js' 0
make_bundle "$dir" bad  'src/*.js' 1
packet="$dir/.claude/human-review/task-1"
mkdir -p "$packet"
cp -R "$dir/microworlds/good" "$dir/microworlds/bad" "$packet/"
same=true
for slug in good bad; do
  orig=0; copy=0
  ( cd "$dir" && bash "microworlds/$slug/run.sh" ) >/dev/null 2>&1 || orig=$?
  ( cd "$dir" && bash ".claude/human-review/task-1/$slug/run.sh" ) >/dev/null 2>&1 || copy=$?
  [ "$orig" = "$copy" ] || same=false
  eval "rc_$slug=\$orig"
done
if [ "$same" = true ] && [ "$rc_good" = 0 ] && [ "$rc_bad" = 1 ]; then
  echo "OK   (f) relocation: a bundle copied outside microworlds/ exits with the same status as the original (0 and 1 both tracked)"
else
  echo "FAIL (f) relocation broken (same=$same good=$rc_good bad=$rc_bad)"
  fail=1
fi

# (f2) MUTATION CONTROL for (f): a run.sh resolving its data through the cwd and
#      a hardcoded microworlds/ path instead of $(dirname "$0") must FAIL once
#      relocated and the original bundle is gone - the state an escalation packet
#      actually lives in. Without this, (f) could pass for free.
dir="$(make_project relocate-mutation)"
make_bundle "$dir" good 'src/*.js' 0
cp -R "$dir/microworlds/good" "$dir/microworlds/nonrelocatable"
cat > "$dir/microworlds/nonrelocatable/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
diff -q microworlds/nonrelocatable/inputs/sample.txt microworlds/nonrelocatable/expected/sample.txt >/dev/null
EOF
chmod +x "$dir/microworlds/nonrelocatable/run.sh"
packet="$dir/.claude/human-review/task-1"
mkdir -p "$packet"
cp -R "$dir/microworlds/good" "$dir/microworlds/nonrelocatable" "$packet/"
rm -rf "$dir/microworlds"
reloc=0; nonreloc=0
( cd "$dir" && bash ".claude/human-review/task-1/good/run.sh" ) >/dev/null 2>&1 || reloc=$?
( cd "$dir" && bash ".claude/human-review/task-1/nonrelocatable/run.sh" ) >/dev/null 2>&1 || nonreloc=$?
if [ "$reloc" = 0 ] && [ "$nonreloc" != 0 ]; then
  echo "OK   (f2) mutation control: with the original bundle gone the relocatable run.sh still passes and a cwd-anchored one fails, so (f) is binding"
else
  echo "FAIL (f2) mutation control did not discriminate (relocatable=$reloc cwd-anchored=$nonreloc)"
  fail=1
fi

# (h) WATCH-MAP with no microworlds/ -> hook exit 0 immediately, and after
#     the drain loop, result=pass logged (watch-map entries are deferred too)
dir="$(make_project watch-map-no-bundles)"
mkdir -p "$dir/tests"
printf '{"entries":[{"id":"sample","watch":["src/*.js"],"run":["bash tests/sample.test.sh"],"timeoutSeconds":10}]}\n' \
  > "$dir/tests/watch-map.json"
printf '#!/bin/bash\nexit 0\n' > "$dir/tests/sample.test.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] && grep -q 'unit=sample result=pass file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (h) watch-map entry with no microworlds/ dir -> hook exit 0, result=pass logged after the drain"
else
  echo "FAIL (h) expected exit 0 and result=pass from watch-map (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (h2) watch-map entry that fails -> hook exit 0 immediately; result=fail
#      logged after the drain
dir="$(make_project watch-map-fail)"
mkdir -p "$dir/tests"
printf '{"entries":[{"id":"sample","watch":["src/*.js"],"run":["bash tests/sample.test.sh"],"timeoutSeconds":10}]}\n' \
  > "$dir/tests/watch-map.json"
printf '#!/bin/bash\nexit 1\n' > "$dir/tests/sample.test.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] && grep -q 'unit=sample result=fail file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (h2) watch-map entry with failing command -> hook exit 0 (deferred), result=fail logged after the drain"
else
  echo "FAIL (h2) expected exit 0 immediately plus a deferred result=fail (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (h3) watch-map entry with multiple commands, second one fails -> hook exit
#      0 immediately; after the drain, result=fail logged and the first
#      command was run
dir="$(make_project watch-map-multi-fail)"
mkdir -p "$dir/tests"
printf '{"entries":[{"id":"multi","watch":["src/*.js"],"run":["bash tests/first.test.sh","bash tests/second.test.sh"],"timeoutSeconds":10}]}\n' \
  > "$dir/tests/watch-map.json"
printf '#!/bin/bash\necho "first ran" >> tests/trace.txt\nexit 0\n' > "$dir/tests/first.test.sh"
printf '#!/bin/bash\nexit 1\n' > "$dir/tests/second.test.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] && grep -q 'unit=multi result=fail' "$dir/.claude/microworld-audit.log" && [ -f "$dir/tests/trace.txt" ]; then
  echo "OK   (h3) watch-map multi-command: first succeeds, second fails -> hook exit 0 (deferred), result=fail logged, first was executed"
else
  echo "FAIL (h3) expected exit 0 immediately, a deferred result=fail, and first command execution (rc=$rc trace-exists=$([ -f "$dir/tests/trace.txt" ] && echo yes || echo no))"
  fail=1
fi

# (h4) watch-map entry that times out -> hook exit 0 immediately; result=timeout
#      logged after the drain
dir="$(make_project watch-map-timeout)"
mkdir -p "$dir/tests"
printf '{"entries":[{"id":"slow","watch":["src/*.js"],"run":["bash tests/slow.test.sh"],"timeoutSeconds":1}]}\n' \
  > "$dir/tests/watch-map.json"
printf '#!/bin/bash\nsleep 30\n' > "$dir/tests/slow.test.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
if [ "$rc" = 0 ] && grep -q 'unit=slow result=timeout file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (h4) watch-map entry that times out -> hook exit 0 (deferred), result=timeout logged after the drain"
else
  echo "FAIL (h4) expected exit 0 immediately plus a deferred result=timeout (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (h5) malformed watch-map.json -> exit 0 (fail open) and a logged error line,
#      SYNCHRONOUSLY
dir="$(make_project watch-map-malformed)"
mkdir -p "$dir/tests"
printf '{"entries":[{"id":,"watch":["src/*"],\n' > "$dir/tests/watch-map.json"
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 0 ] && grep -q 'result=error' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (h5) malformed watch-map.json -> exit 0 (fail open) and a logged error line"
else
  echo "FAIL (h5) expected exit 0 plus error log (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (h6) watch-map entry without microworlds/ dir, unrelated file edit -> exit 0, no audit line
dir="$(make_project watch-map-nomatch)"
mkdir -p "$dir/tests"
printf '{"entries":[{"id":"sample","watch":["src/*.js"],"run":["bash tests/sample.test.sh"],"timeoutSeconds":10}]}\n' \
  > "$dir/tests/watch-map.json"
rc=0
run_hook "$dir" lib/other.js || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/microworld-audit.log" ]; then
  echo "OK   (h6) watch-map with no microworlds/ and unrelated edit -> exit 0, no audit line"
else
  echo "FAIL (h6) expected exit 0 with no audit log (rc=$rc log-exists=$([ -e "$dir/.claude/microworld-audit.log" ] && echo yes || echo no))"
  fail=1
fi

# (i) AC-A4 - DEDUP: one enqueue matching THREE bundles that each shell out
#     to the identical `bash tests/shared.test.sh` invocation inside their
#     own run.sh executes that suite exactly ONCE (a marker file the suite
#     appends to has exactly one line), while still emitting one audit line
#     PER bundle (3 lines) - bundle-level results are not collapsed, only the
#     underlying suite execution is.
dir="$(make_project dedup)"
mkdir -p "$dir/tests"
marker="$dir/marker.txt"
: > "$marker"
cat > "$dir/tests/shared.test.sh" <<EOF
#!/usr/bin/env bash
echo ran >> "$marker"
exit 0
EOF
chmod +x "$dir/tests/shared.test.sh"
for slug in b1 b2 b3; do
  mkdir -p "$dir/microworlds/$slug"
  printf '{"unit":"%s","watch":["src/*.js"],"timeoutSeconds":10}\n' "$slug" \
    > "$dir/microworlds/$slug/manifest.json"
  cat > "$dir/microworlds/$slug/run.sh" <<'RUNEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/../.."
bash tests/shared.test.sh
RUNEOF
  chmod +x "$dir/microworlds/$slug/run.sh"
done
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
suite_runs="$(wc -l < "$marker" 2>/dev/null || echo 0)"
# grep -c already prints "0" (and exits 1) when there are no matches, so
# `|| echo 0` would double-print in that case; only the missing-file case
# needs a fallback, guarded separately.
bundle_lines="$(grep -c 'result=pass' "$dir/.claude/microworld-audit.log" 2>/dev/null || true)"
[ -n "$bundle_lines" ] || bundle_lines=0
if [ "$rc" = 0 ] && [ "$suite_runs" = 1 ] && [ "$bundle_lines" = 3 ]; then
  echo "OK   (i) dedup: 3 bundles sharing one suite invocation -> the suite ran exactly once, 3 per-bundle audit lines"
else
  echo "FAIL (i) expected 1 suite execution and 3 audit lines (rc=$rc suite_runs=$suite_runs bundle_lines=$bundle_lines)"
  fail=1
fi

# (j) AC-A5 - BOUNDED QUEUE / COALESCING: 10 rapid enqueues for the same
#     bundle leave no orphaned process once the drain completes, and the
#     bundle's own run.sh (traced via a counter file) does not run once per
#     enqueue - coalescing collapses the pending slot.
dir="$(make_project coalesce)"
counter="$dir/run-count.txt"
: > "$counter"
b="$dir/microworlds/widget"
mkdir -p "$b"
printf '{"unit":"widget","watch":["src/*.js"],"timeoutSeconds":10}\n' > "$b/manifest.json"
cat > "$b/run.sh" <<EOF
#!/usr/bin/env bash
echo ran >> "$counter"
sleep 0.3
exit 0
EOF
chmod +x "$b/run.sh"
for i in $(seq 1 5); do
  printf '{"tool_input":{"file_path":"%s/src/app.js"}}' "$dir" \
    | CLAUDE_PROJECT_DIR="$dir" timeout 5 bash "$hook" >/dev/null 2>&1 || true
done
wait_for_drain "$dir"
runs="$(wc -l < "$counter" 2>/dev/null || echo 0)"
# pgrep exits 1 when it finds nothing (the expected outcome here); under
# this script's `set -e`+pipefail, that would otherwise abort silently even
# though `wc -l` itself succeeds - `|| true` on the whole pipe absorbs it
# without adding output (unlike `|| echo 0`, which would double-print).
orphans="$(pgrep -f "$dir/microworlds/widget/run.sh" 2>/dev/null | wc -l || true)"
if [ "$runs" -ge 1 ] && [ "$runs" -le 2 ] && [ "$orphans" = 0 ]; then
  echo "OK   (j) coalescing: 10 rapid enqueues collapsed to $runs actual run(s), no orphaned process survives"
else
  echo "FAIL (j) expected 1-2 actual runs and 0 orphans (runs=$runs orphans=$orphans)"
  fail=1
fi

# (k) AC-1.3 - MUTATION-PROOF REGRESSION: the same suite invoked once plainly
#     and once with a differing GATE-style env prefix (mirroring
#     microworlds/rpg-canon-2 and hdg-anchor-1's own pattern) must observe
#     DIFFERENT exit codes, even when another bundle already populated the
#     memo cache for the plain invocation first - the realistic ordering that
#     exposed the naive owner-PID key variant during scoping.
dir="$(make_project mutation-proof)"
mkdir -p "$dir/tests"
cat > "$dir/tests/fixture-suite.test.sh" <<'EOF'
#!/usr/bin/env bash
if [ "${FIXTURE_MUTANT:-}" = "1" ]; then
  exit 1
fi
exit 0
EOF
chmod +x "$dir/tests/fixture-suite.test.sh"
mkdir -p "$dir/microworlds/a-populate"
printf '{"unit":"a-populate","watch":["src/*.js"],"timeoutSeconds":10}\n' \
  > "$dir/microworlds/a-populate/manifest.json"
cat > "$dir/microworlds/a-populate/run.sh" <<'RUNEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/../.."
bash tests/fixture-suite.test.sh
RUNEOF
chmod +x "$dir/microworlds/a-populate/run.sh"
mkdir -p "$dir/microworlds/b-mutant"
printf '{"unit":"b-mutant","watch":["src/*.js"],"timeoutSeconds":10}\n' \
  > "$dir/microworlds/b-mutant/manifest.json"
cat > "$dir/microworlds/b-mutant/run.sh" <<'RUNEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/../.."
rc1=0
bash tests/fixture-suite.test.sh || rc1=$?
rc2=0
FIXTURE_MUTANT=1 bash tests/fixture-suite.test.sh || rc2=$?
echo "$rc1" > rc1.txt
echo "$rc2" > rc2.txt
RUNEOF
chmod +x "$dir/microworlds/b-mutant/run.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
rc1="$(cat "$dir/rc1.txt" 2>/dev/null || echo MISSING)"
rc2="$(cat "$dir/rc2.txt" 2>/dev/null || echo MISSING)"
if [ "$rc" = 0 ] && [ "$rc1" != "MISSING" ] && [ "$rc2" != "MISSING" ] && [ "$rc1" != "$rc2" ]; then
  echo "OK   (k) mutation-proof: suite invoked plainly then with a differing env prefix returns different exit codes (rc1=$rc1 rc2=$rc2), even after another bundle pre-populated the memo cache"
else
  echo "FAIL (k) expected different exit codes for plain vs mutant invocation (rc=$rc rc1=$rc1 rc2=$rc2)"
  fail=1
fi

# (l) AC-1.9 - PER-PASS FLUSH REGRESSION: a bundle that is still executing
#     (>=2s) when it is re-enqueued must be RE-EXECUTED in drain-loop PASS 2,
#     not served pass 1's cached memo result. R11: deterministic via polling
#     .runner.lock AND the original .pending file's removal before the
#     second enqueue, never a bare sleep race.
dir="$(make_project per-pass-flush)"
mkdir -p "$dir/tests"
marker="$dir/flush-marker.txt"
: > "$marker"
cat > "$dir/tests/flush-suite.test.sh" <<EOF
#!/usr/bin/env bash
echo ran >> "$marker"
exit 0
EOF
chmod +x "$dir/tests/flush-suite.test.sh"
b="$dir/microworlds/slow-flush"
mkdir -p "$b"
printf '{"unit":"slow-flush","watch":["src/*.js"],"timeoutSeconds":30}\n' > "$b/manifest.json"
cat > "$b/run.sh" <<'RUNEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/../.."
sleep 3
bash tests/flush-suite.test.sh
RUNEOF
chmod +x "$b/run.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
lock="$dir/.claude/microworld-queue/.runner.lock"
for i in $(seq 1 50); do
  [ -d "$lock" ] && break
  sleep 0.1
done
pending="$dir/.claude/microworld-queue/slow-flush.pending"
for i in $(seq 1 50); do
  [ -f "$pending" ] || break
  sleep 0.1
done
run_hook "$dir" src/app.js || rc=$?
wait_for_drain "$dir"
audit_slug_lines="$(grep -c 'unit=slow-flush' "$dir/.claude/microworld-audit.log" 2>/dev/null || true)"
[ -n "$audit_slug_lines" ] || audit_slug_lines=0
marker_lines="$(wc -l < "$marker" 2>/dev/null || echo 0)"
if [ "$rc" = 0 ] && [ "$audit_slug_lines" = 2 ] && [ "$marker_lines" = 2 ]; then
  echo "OK   (l) per-pass flush: a bundle re-enqueued mid-run is re-executed in drain pass 2 (2 audit lines, 2 marker lines)"
else
  echo "FAIL (l) expected 2 audit lines and 2 marker lines from a genuine second drain pass (rc=$rc audit=$audit_slug_lines marker=$marker_lines)"
  fail=1
fi

# (g) ADAPTER PARITY - both hand-adapted mirrors are EXECUTED with their own
#     payload shapes and must reproduce the same async contract (exit 0
#     immediately; audit log populated after the drain) into their own
#     dot-dir audit log. bash -n in validate.sh only proves they parse.
adapter_payload() {
  # $1 = adapter, $2 = project dir, $3 = absolute edited path
  case "$1" in
    cursor) printf '{"workspace_roots":["%s"],"file_path":"%s"}' "$2" "$3" ;;
    codex)  printf '{"cwd":"%s","tool_input":{"file_path":"%s"}}' "$2" "$3" ;;
  esac
}

for adapter in cursor codex; do
  case "$adapter" in
    cursor) dot=.cursor ;;
    codex)  dot=.codex ;;
  esac
  script="adapters/$adapter/hooks/scripts/microworld-rerun.sh"
  ok=true

  dir="$(make_project "$adapter-pass")"
  make_bundle "$dir" widget 'src/*.js' 0
  rc=0
  adapter_payload "$adapter" "$dir" "$dir/src/app.js" | bash "$script" >/dev/null 2>&1 || rc=$?
  for i in $(seq 1 50); do [ -d "$dir/$dot/microworld-queue/.runner.lock" ] || break; sleep 0.2; done
  { [ "$rc" = 0 ] && grep -q 'unit=widget result=pass' "$dir/$dot/microworld-audit.log"; } || ok=false
  pass_rc="$rc"

  dir="$(make_project "$adapter-fail")"
  make_bundle "$dir" widget 'src/*.js' 1
  rc=0
  adapter_payload "$adapter" "$dir" "$dir/src/app.js" | bash "$script" >/dev/null 2>&1 || rc=$?
  for i in $(seq 1 50); do [ -d "$dir/$dot/microworld-queue/.runner.lock" ] || break; sleep 0.2; done
  { [ "$rc" = 0 ] && grep -q 'unit=widget result=fail' "$dir/$dot/microworld-audit.log"; } || ok=false

  if [ "$ok" = true ]; then
    echo "OK   (g) $adapter mirror: hook exit 0 immediately for pass and fail bundles, both logged to $dot/microworld-audit.log after the drain"
  else
    echo "FAIL (g) $adapter mirror parity broken (pass-rc=$pass_rc fail-rc=$rc)"
    fail=1
  fi
done

# (g2) the codex mirror's apply_patch fallback: no tool_input.file_path at all,
#      paths parsed out of the patch headers instead
dir="$(make_project codex-apply-patch)"
make_bundle "$dir" widget 'src/*.js' 1
rc=0
printf '{"cwd":"%s","tool_name":"apply_patch","tool_input":{"input":"*** Update File: %s/src/app.js\\n"}}' \
  "$dir" "$dir" | bash adapters/codex/hooks/scripts/microworld-rerun.sh >/dev/null 2>&1 || rc=$?
for i in $(seq 1 50); do [ -d "$dir/.codex/microworld-queue/.runner.lock" ] || break; sleep 0.2; done
if [ "$rc" = 0 ] && grep -q 'unit=widget result=fail' "$dir/.codex/microworld-audit.log"; then
  echo "OK   (g2) codex mirror resolves apply_patch header paths and still reports the failing bundle after the drain"
else
  echo "FAIL (g2) codex apply_patch path extraction broken (rc=$rc log=[$(cat "$dir/.codex/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

exit "$fail"
