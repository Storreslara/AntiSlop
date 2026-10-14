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

changelog_line() {
  # <version> -> appends a CHANGELOG.md line naming that version
  printf '**entry (%s).**\n' "$1" >> "$repo/CHANGELOG.md"
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
  if [ "$rc" = 0 ] && printf '%s\n' "$got" | grep -Eq "^version-stamp-check: ${expected} touched: (yes|no|-) old: \S+ new: \S+( offenders: \S+)?\$"; then
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
changelog_line 0.2.0
r_agents_with_bump=$(snap agents-with-bump)
run_case "agents-touched-with-bump" "ok" "$r_agents_with_bump"

echo "-- templates/* touched, no version bump: VIOLATION --"
echo "tmpl" > "$repo/templates/persona-protocol.md"
r_templates_no_bump=$(snap templates-no-bump)
run_case "templates-touched-no-bump" "violation" "$r_templates_no_bump"

echo "-- templates/* touched, WITH a version bump: OK --"
echo "tmpl v2" > "$repo/templates/persona-protocol.md"
plugin_version 0.3.0
changelog_line 0.3.0
r_templates_with_bump=$(snap templates-with-bump)
run_case "templates-touched-with-bump" "ok" "$r_templates_with_bump"

echo "-- hooks/scripts touched only: OK, not a version-stamped path --"
echo "#!/usr/bin/env bash" > "$repo/hooks/scripts/example.sh"
r_hooks_only=$(snap hooks-only)
run_case "hooks-scripts-only-not-gated" "ok" "$r_hooks_only"

echo "-- CHANGELOG half (skr-5): a bump needs a same-commit CHANGELOG line naming it --"
expect_offender() {
  # <label> <range> <substring>: the offenders field of the verdict must contain the substring
  local label="$1" range="$2" want="$3" got
  got="$(cd "$repo" && bash "$SCRIPT" "$range" 2>/dev/null)" || true
  if printf '%s\n' "$got" | grep -q "offenders: .*${want}"; then
    echo "OK   $label -> $got"
  else
    echo "FAIL $label expected offenders containing '$want', got '$got'"
    fail=1
  fi
}

echo "chg a" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.1
changelog_line 0.3.1
r_chg_ok=$(snap chglog-ok)
run_case "(a) bump plus matching CHANGELOG line" "ok" "$r_chg_ok"

echo "chg b" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.2
r_chg_missing=$(snap chglog-missing)
run_case "(b) bump, no CHANGELOG hunk" "violation" "$r_chg_missing"
expect_offender "(b) offenders name CHANGELOG.md" "$r_chg_missing" ":CHANGELOG.md"

echo "chg c" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.3
changelog_line 9.9.9
r_chg_wrong=$(snap chglog-wrong-version)
run_case "(c) CHANGELOG line names a different version" "violation" "$r_chg_wrong"
expect_offender "(c) offenders name CHANGELOG.md" "$r_chg_wrong" ":CHANGELOG.md"

echo "chg d1" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.4
r_chg_d1=$(snap chglog-d1-no-line)
echo "chg d2" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.5
changelog_line 0.3.5
snap chglog-d2-with-line > /dev/null
r_chg_d="${r_chg_d1%%..*}..$(git -C "$repo" rev-parse HEAD)"
run_case "(d) earlier bumping commit lacks its line, HEAD version differs" "violation" "$r_chg_d"
expect_offender "(d) names the earlier commit" "$r_chg_d" "$(git -C "$repo" rev-parse --short=7 "${r_chg_d1##*..}"):CHANGELOG.md"

echo "-- CHANGELOG half hardening (sfu-4) --"
run_case_color() {
  # run_case with color.ui=always forced on every git call the script makes
  if ! ( export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always; fail=0; run_case "$@"; exit "$fail" ); then
    fail=1
  fi
}

echo "chg e1" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.6
changelog_line 0.3.6
r_chg_e1=$(snap chglog-e1-own-line)
echo "chg e2" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.7
changelog_line 0.3.7
snap chglog-e2-own-line > /dev/null
r_chg_e="${r_chg_e1%%..*}..$(git -C "$repo" rev-parse HEAD)"
run_case "(e) two compliant bumps, each line names only its own version" "ok" "$r_chg_e"

changelog_line 0.3.8
echo "notes" > "$repo/README.md"
snap chglog-f-line-before-bump > /dev/null
echo "chg f" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.8
changelog_line unrelated
r_chg_f=$(snap chglog-f-context-only)
run_case "(f) version only on a context line" "violation" "$r_chg_f"

echo "chg g" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.9
printf '**entry (0x3y9).**\n' >> "$repo/CHANGELOG.md"
r_chg_g=$(snap chglog-g-dots-literal)
run_case "(g) 0x3y9 does not name 0.3.9" "violation" "$r_chg_g"

echo "chg h1" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.10
changelog_line 0.3.100
r_chg_h1=$(snap chglog-h1-longer-right)
run_case "(h1) 0.3.100 does not name 0.3.10" "violation" "$r_chg_h1"

echo "chg h2" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.11
changelog_line 10.3.11
r_chg_h2=$(snap chglog-h2-longer-left)
run_case "(h2) 10.3.11 does not name 0.3.11" "violation" "$r_chg_h2"

echo "chg h3" > "$repo/agents/lead-programmer.md"
plugin_version 0.3.12
changelog_line v0.3.12
r_chg_h3=$(snap chglog-h3-v-prefix)
run_case "(h3) v0.3.12 names 0.3.12" "ok" "$r_chg_h3"

run_case_color "(i) color.ui=always, compliant bump" "ok" "$r_chg_ok"

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

if mutate changelog-check-disabled 's/&& ! changelog_adds_version/\&\& false \&\& ! changelog_adds_version/'; then
  run_case "(mc7) CHANGELOG check disabled: (b) should flip to" "ok" "$r_chg_missing" "$MUTANT"
  run_case "(mc7) CHANGELOG check disabled: (c) should flip to" "ok" "$r_chg_wrong" "$MUTANT"
  run_case "(mc7) CHANGELOG check disabled: (d) should flip to" "ok" "$r_chg_d" "$MUTANT"
fi

if mutate added-line-filter-removed 's/l.startswith("+") and not l.startswith("+++")/not l.startswith("+++")/'; then
  run_case "(mc8) added-line filter removed: (f) should flip to" "ok" "$r_chg_f" "$MUTANT"
fi

if mutate escape-removed 's/re.escape(sys.argv\[1\])/sys.argv[1]/'; then
  run_case "(mc9) re.escape removed: (g) should flip to" "ok" "$r_chg_g" "$MUTANT"
fi

if mutate right-boundary-removed 's/ + r"(?!\[0-9\])"//'; then
  run_case "(mc10) right boundary removed: (h1) should flip to" "ok" "$r_chg_h1" "$MUTANT"
fi

if mutate left-boundary-removed 's/r"(?<!\[0-9.\])" + //'; then
  run_case "(mc11) left boundary removed: (h2) should flip to" "ok" "$r_chg_h2" "$MUTANT"
fi

if mutate half2-endpoint-version 's/changelog_adds_version "\$c" "\$cnew"/changelog_adds_version "$c" "$new_ver"/'; then
  run_case "(mc12) range-endpoint version passed: (e) should flip to" "violation" "$r_chg_e" "$MUTANT"
fi

if mutate no-color-removed 's/git diff --no-color --no-ext-diff --no-renames/git diff --no-renames/'; then
  run_case_color "(mc13) --no-color removed: (i) should flip to" "violation" "$r_chg_ok" "$MUTANT"
fi

echo "-- offender collection is computed, not hardcoded (item 5) --"
if mutate offender-collection-disabled 's|offenders="\${offenders:+\$offenders,}\$short:\$p"|true|'; then
  got="$(bash "$MUTANT" "61ff35a~1..e9f07c2" 2>/dev/null)"
  if ! printf '%s\n' "$got" | grep -q '61ff35a'; then
    echo "OK   (mc6) offender-collection step disabled: real-history violation no longer names 61ff35a -> $got"
  else
    echo "FAIL (mc6) offender-collection step disabled: still names 61ff35a, got '$got'"
    fail=1
  fi
fi

exit "$fail"
