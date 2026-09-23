#!/usr/bin/env bash
# Behavioural suite for hooks/scripts/version-stamp-check.sh (constitution
# P3 / version-stamp discipline, unit version-stamp-guard-1). Builds a
# throwaway git repo with known commit shapes so the ok/violation/unknown
# verdict can be pinned by example rather than reasoned about.
set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$PWD/hooks/scripts/version-stamp-check.sh"
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
repo="$tmproot/repo"
mkdir -p "$repo/.claude-plugin" "$repo/agents" "$repo/templates" "$repo/hooks/scripts"
git -C "$repo" init -q
git -C "$repo" config user.email tester@example.com
git -C "$repo" config user.name tester
git -C "$repo" config commit.gpgsign false

plugin_version() {
  # <version> -> writes .claude-plugin/plugin.json with that version
  printf '{"name": "antislop", "version": "%s"}\n' "$1" > "$repo/.claude-plugin/plugin.json"
}

plugin_version 0.1.0
git -C "$repo" add -A
git -C "$repo" commit -qm base

snap() {
  # <label> -> commits the current worktree, echoes the range it spans
  git -C "$repo" add -A
  git -C "$repo" commit -qm "$1"
  echo "$(git -C "$repo" rev-parse HEAD~1)..$(git -C "$repo" rev-parse HEAD)"
}

run_case() {
  # <label> <expected-verdict> <range> [script-under-test]
  local label="$1" expected="$2" range="$3" script="${4:-$SCRIPT}"
  local got rc=0
  got="$(cd "$repo" && bash "$script" "$range" 2>/dev/null)" || rc=$?
  if [ "$rc" = 0 ] && printf '%s\n' "$got" | grep -Eq "^version-stamp-check: ${expected} touched: (yes|no|-) old: \S+ new: \S+\$"; then
    echo "OK   $label -> $got"
  else
    echo "FAIL $label expected 'version-stamp-check: $expected ...', got '$got' (rc=$rc)"
    fail=1
  fi
}

echo "-- unrelated file touched, no version-stamped path in the diff --"
echo "hello" > "$repo/README.md"
r_unrelated=$(snap unrelated)
run_case "unrelated-file" "ok" "$r_unrelated"

echo "-- agents/*.md touched, no version bump: VIOLATION --"
echo "content" > "$repo/agents/lead-programmer.md"
r_agents_no_bump=$(snap agents-no-bump)
run_case "agents-touched-no-bump" "violation" "$r_agents_no_bump"

echo "-- agents/*.md touched, WITH a version bump: OK --"
echo "content v2" > "$repo/agents/lead-programmer.md"
plugin_version 0.2.0
r_agents_with_bump=$(snap agents-with-bump)
run_case "agents-touched-with-bump" "ok" "$r_agents_with_bump"

echo "-- templates/* touched, no version bump: VIOLATION --"
echo "tmpl" > "$repo/templates/persona-protocol.md"
r_templates_no_bump=$(snap templates-no-bump)
run_case "templates-touched-no-bump" "violation" "$r_templates_no_bump"

echo "-- templates/* touched, WITH a version bump: OK --"
echo "tmpl v2" > "$repo/templates/persona-protocol.md"
plugin_version 0.3.0
r_templates_with_bump=$(snap templates-with-bump)
run_case "templates-touched-with-bump" "ok" "$r_templates_with_bump"

echo "-- hooks/scripts touched only: OK, not a version-stamped path --"
echo "#!/usr/bin/env bash" > "$repo/hooks/scripts/example.sh"
r_hooks_only=$(snap hooks-only)
run_case "hooks-scripts-only-not-gated" "ok" "$r_hooks_only"

echo "-- python3 missing from PATH: unknown, not a crash (item 1) --"
fakebin="$tmproot/fakebin-no-python3"
mkdir -p "$fakebin"
ln -s "$(command -v git)" "$fakebin/git"
ln -s "$(command -v bash)" "$fakebin/bash"

make_no_python3_wrapper() {
  # <target-script> -> writes+echoes a wrapper that runs target-script with
  # python3 hidden from PATH (git/bash still resolvable via $fakebin)
  local target="$1" wrapper="$tmproot/no-python3-wrapper-$(basename "$1").sh"
  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
PATH="$fakebin" exec bash "$target" "\$@"
EOF
  echo "$wrapper"
}

nopython_wrapper="$(make_no_python3_wrapper "$SCRIPT")"
run_case "python3-missing-reports-unknown" "unknown" "$r_agents_no_bump" "$nopython_wrapper"

echo "-- widened range masks a per-commit violation without the fix (item 4) --"
echo "content v3, no bump" > "$repo/agents/lead-programmer.md"
r_violation_only=$(snap violation-commit-no-bump)
run_case "violation-commit-alone" "violation" "$r_violation_only"

echo "unrelated change, unrelated version bump" > "$repo/README.md"
plugin_version 0.4.0
snap unrelated-bump-after-violation > /dev/null
widened_range="${r_violation_only%%..*}..$(git -C "$repo" rev-parse HEAD)"
run_case "widened-range-still-catches-violation" "violation" "$widened_range"

echo "-- plugin.json missing at one end of the range: unknown, not a crash (item 3) --"
rm "$repo/.claude-plugin/plugin.json"
echo "more content" > "$repo/agents/lead-programmer.md"
r_plugin_missing=$(snap plugin-json-missing-at-new-end)
run_case "plugin-json-missing-at-new-end" "unknown" "$r_plugin_missing"

echo "-- unmeasurable ranges --"
run_case "empty-range" "unknown" ""
run_case "leading-dash" "unknown" "-U0"
run_case "no-double-dot" "unknown" "$(git -C "$repo" rev-parse HEAD)"
run_case "unresolvable-range" "unknown" "nonexistent-ref-aaa..nonexistent-ref-bbb"

echo "-- mutation controls --"
MUTANT=""
mutate() {
  # <name> <sed-expr>: writes the mutant to $MUTANT, fails loudly if the sed
  # matched nothing (a silently-unmutated copy would "prove" anything).
  MUTANT="$tmproot/$1.sh"
  sed "$2" "$SCRIPT" > "$MUTANT"
  if cmp -s "$MUTANT" "$SCRIPT"; then
    echo "FAIL mutation control '$1': the sed matched nothing"
    fail=1
    return 1
  fi
  return 0
}

if mutate agents-pattern-removed 's#agents/\*\.md|templates/\*#templates/\*#'; then
  run_case "(mc1) agents/*.md pattern removed: agents-touched-no-bump should flip to" \
    "ok" "$r_agents_no_bump" "$MUTANT"
fi

if mutate compare-inverted 's/\[ "\$old_ver" = "\$new_ver" \]/[ "$old_ver" != "$new_ver" ]/'; then
  run_case "(mc2) version-equality check inverted: agents-with-bump should flip to" \
    "violation" "$r_agents_with_bump" "$MUTANT"
fi

if mutate python3-guard-disabled 's/if ! command -v python3 >\/dev\/null 2>&1; then/if false; then/'; then
  nopython_wrapper_mutant="$(make_no_python3_wrapper "$MUTANT")"
  rc=0
  got="$(cd "$repo" && bash "$nopython_wrapper_mutant" "$r_agents_no_bump" 2>/dev/null)" || rc=$?
  if [ "$rc" != 0 ] && [ -z "$got" ]; then
    echo "OK   (mc3) python3 guard disabled: crashes instead of reporting unknown (rc=$rc), proving the guard is load-bearing"
  else
    echo "FAIL (mc3) python3 guard disabled: expected a crash (rc!=0, empty output), got rc=$rc output='$got'"
    fail=1
  fi
fi

if mutate percommit-check-disabled 's/elif \[ "\$cold" = "\$cnew" \]; then/elif false; then/'; then
  run_case "(mc4) per-commit violation check disabled: widened-range should flip to" \
    "ok" "$widened_range" "$MUTANT"
fi

if mutate unmeasurable-check-disabled 's/\[ -z "\$old_ver" \] || \[ -z "\$new_ver" \] || \[ "\$unmeasurable" = yes \]/false/'; then
  got="$(cd "$repo" && bash "$MUTANT" "$r_plugin_missing" 2>/dev/null)"
  if ! printf '%s\n' "$got" | grep -q '^version-stamp-check: unknown '; then
    echo "OK   (mc5) unmeasurable/empty-version check disabled: plugin-json-missing no longer reports unknown -> $got"
  else
    echo "FAIL (mc5) unmeasurable/empty-version check disabled: still reports unknown, got '$got'"
    fail=1
  fi
fi

exit "$fail"
