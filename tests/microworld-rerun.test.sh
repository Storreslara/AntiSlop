#!/usr/bin/env bash
# Fixture-driven test for hooks/scripts/microworld-rerun.sh - the reactive
# PostToolUse(Edit|Write) microworld rerun hook. Canned hook-input JSON piped
# to the script against throwaway fixture projects; the hook is EXECUTED, never
# source-inspected. Also carries the executable relocation proof (case f) that
# the escalation packet depends on.
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
  # exit code; stderr lands in $tmproot/stderr.txt
  local rc=0
  printf '{"tool_input":{"file_path":"%s"}}' "$1/$2" \
    | CLAUDE_PROJECT_DIR="$1" bash "$hook" 2>"$tmproot/stderr.txt" || rc=$?
  return "$rc"
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
  echo "OK   (b) edit matching no watch glob -> exit 0 and no audit line"
else
  echo "FAIL (b) expected exit 0 with no audit line (rc=$rc lines=$(audit_lines "$dir"))"
  fail=1
fi

# (c) an edit matching a bundle whose run.sh exits 0 -> exit 0 + result=pass line
dir="$(make_project pass)"
make_bundle "$dir" widget 'src/*.js' 0
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 0 ] \
   && grep -q 'unit=widget result=pass file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (c) matching bundle whose run.sh exits 0 -> exit 0 and a result=pass audit line"
else
  echo "FAIL (c) expected exit 0 and a result=pass audit line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (d) an edit matching a bundle whose run.sh exits 1 -> exit 2, stderr names the
#     unit, and a result=fail audit line. Paired with (e) this is the whole
#     exit-code asymmetry: 2 for a real bundle failure, 0 for infrastructure.
dir="$(make_project fail)"
make_bundle "$dir" widget 'src/*.js' 1
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 2 ] && grep -q 'widget' "$tmproot/stderr.txt" \
   && grep -q 'unit=widget result=fail file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (d) matching bundle whose run.sh exits 1 -> exit 2, stderr names the unit, result=fail logged"
else
  echo "FAIL (d) expected exit 2 naming the unit plus a result=fail line (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")] log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (d2) a matched bundle that exceeds its manifest timeoutSeconds -> exit 2 and a
#      result=timeout line (distinct from the plain-failure result)
dir="$(make_project timeout)"
make_bundle "$dir" widget 'src/*.js' 0
printf '{"unit":"widget","watch":["src/*.js"],"timeoutSeconds":1}\n' \
  > "$dir/microworlds/widget/manifest.json"
printf '#!/usr/bin/env bash\nsleep 30\n' > "$dir/microworlds/widget/run.sh"
rc=0
run_hook "$dir" src/app.js || rc=$?
if [ "$rc" = 2 ] \
   && grep -q 'unit=widget result=timeout file=src/app.js' "$dir/.claude/microworld-audit.log"; then
  echo "OK   (d2) a bundle exceeding timeoutSeconds -> exit 2 and a result=timeout audit line"
else
  echo "FAIL (d2) expected exit 2 and a result=timeout line (rc=$rc log=[$(cat "$dir/.claude/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

# (e) a bundle with a malformed manifest.json -> exit 0 (fail open) and a logged
#     line: infrastructure breakage is reported, never gated on
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

# (e2) a matched bundle with NO run.sh -> exit 0 (fail open) and a logged line
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

# (g) ADAPTER PARITY - both hand-adapted mirrors are EXECUTED with their own
#     payload shapes and must reproduce the same exit-code asymmetry into their
#     own dot-dir audit log. bash -n in validate.sh only proves they parse.
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
  { [ "$rc" = 0 ] && grep -q 'unit=widget result=pass' "$dir/$dot/microworld-audit.log"; } || ok=false
  pass_rc="$rc"

  dir="$(make_project "$adapter-fail")"
  make_bundle "$dir" widget 'src/*.js' 1
  rc=0
  adapter_payload "$adapter" "$dir" "$dir/src/app.js" | bash "$script" >/dev/null 2>&1 || rc=$?
  { [ "$rc" = 2 ] && grep -q 'unit=widget result=fail' "$dir/$dot/microworld-audit.log"; } || ok=false

  if [ "$ok" = true ]; then
    echo "OK   (g) $adapter mirror: pass bundle -> exit 0, failing bundle -> exit 2, both logged to $dot/microworld-audit.log"
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
if [ "$rc" = 2 ] && grep -q 'unit=widget result=fail' "$dir/.codex/microworld-audit.log"; then
  echo "OK   (g2) codex mirror resolves apply_patch header paths and still reports the failing bundle"
else
  echo "FAIL (g2) codex apply_patch path extraction broken (rc=$rc log=[$(cat "$dir/.codex/microworld-audit.log" 2>/dev/null || true)])"
  fail=1
fi

exit "$fail"
