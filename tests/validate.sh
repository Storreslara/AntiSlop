#!/usr/bin/env bash
# Validates the antislop plugin's own files. Run locally before pushing,
# or via .github/workflows/validate.yml. Exits non-zero on any failure.
# This is a best-effort sanity net for a plugin whose "code" is mostly
# prose/config, not a substitute for the empirical smoke tests noted in
# README.md.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

echo "== bash syntax =="
for f in hooks/scripts/*.sh; do
  if bash -n "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== JSON validity =="
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json \
         templates/persona-config.schema.json templates/settings-fragment.json; do
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== package.json / plugin.json version sync =="
pkg_version=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")
plugin_version=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")
if [ "$pkg_version" = "$plugin_version" ]; then
  echo "OK   package.json version ($pkg_version) matches .claude-plugin/plugin.json version ($plugin_version)"
else
  echo "FAIL package.json version ($pkg_version) != .claude-plugin/plugin.json version ($plugin_version)"
  fail=1
fi

echo
echo "== npm pack: dev-scratch dirs excluded, shipped dirs included =="
if npm pack --dry-run --json 2>/dev/null | python3 -c "
import json, sys
files = [f['path'] for f in json.load(sys.stdin)[0]['files']]
excluded = ['docs/', 'eval/', 'prototype/', 'specs/', '.claude/']
included = ['agents/', 'hooks/', 'templates/', 'skills/']
present = [d for d in excluded if any(f.startswith(d) for f in files)]
missing = [d for d in included if not any(f.startswith(d) for f in files)]
if present or missing:
    sys.stderr.write('excluded-dirs-present=%s included-dirs-missing=%s\n' % (present, missing))
    sys.exit(1)
" 2>/tmp/npm_pack_err; then
  echo "OK   npm pack tarball excludes dev-scratch dirs, includes shipped dirs"
else
  echo "FAIL npm pack tarball composition ($(cat /tmp/npm_pack_err))"
  fail=1
fi
rm -f /tmp/npm_pack_err

echo
echo "== marketplace.json / plugin.json consistency =="
if python3 -c "
import json
plugin = json.load(open('.claude-plugin/plugin.json'))
marketplace = json.load(open('.claude-plugin/marketplace.json'))
entries = [p for p in marketplace['plugins'] if p.get('name') == plugin['name']]
assert entries, 'no marketplace entry named %r' % plugin['name']
assert entries[0].get('source') == './', 'marketplace entry source is %r, expected \"./\"' % entries[0].get('source')
" 2>/tmp/marketplace_err; then
  echo "OK   marketplace.json plugin entry matches plugin.json name and source"
else
  echo "FAIL marketplace.json / plugin.json mismatch ($(cat /tmp/marketplace_err | tail -1))"
  fail=1
fi
rm -f /tmp/marketplace_err

echo
echo "== claude plugin tag (advisory - cross-validates plugin.json vs marketplace entry; run manually before release) =="
if command -v claude >/dev/null 2>&1; then
  if claude plugin tag --dry-run >/tmp/claude_plugin_tag_out 2>&1; then
    echo "OK   claude plugin tag --dry-run"
  else
    echo "WARN claude plugin tag --dry-run reported an issue (advisory only, not failing this run):"
    sed 's/^/     /' /tmp/claude_plugin_tag_out
  fi
else
  echo "SKIP (claude CLI not on PATH - run \`claude plugin tag --dry-run\` manually before release)"
fi
rm -f /tmp/claude_plugin_tag_out

echo
echo "== agent/template frontmatter has name: and description: =="
for f in agents/*.md templates/researcher.md.tmpl; do
  if grep -q '^name:' "$f" && grep -q '^description:' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing name: or description: in frontmatter)"
    fail=1
  fi
done

echo
echo "== skill frontmatter has name: and description: =="
for f in skills/*/SKILL.md; do
  if grep -q '^name:' "$f" && grep -q '^description:' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing name: or description: in frontmatter)"
    fail=1
  fi
done

echo
echo "== optional-persona references must be phrased conditionally =="
# scribe/reviewer/researcher are opt-out (see README.md); a bare
# unconditional reference to one of them is exactly the class of bug that
# hard-errors when a project skips that persona. Checked per-PARAGRAPH
# (blank-line-separated, wrapped lines joined) rather than per physical line,
# since a conditional qualifier often lands on the next wrapped line.
# NOTE: spec-master/task-master are also opt-out but deliberately excluded
# from this loop — agents/orchestrator.md references them far more densely,
# with "(if present)" qualifiers scoped per-section rather than repeated
# every paragraph, which this paragraph-scoped checker would false-positive
# on.
for p in scribe reviewer researcher; do
  bad=0
  for f in agents/orchestrator.md agents/lead-programmer.md commands/start-feature-team.md; do
    [ -f "$f" ] || continue
    while IFS= read -r para; do
      case "$para" in
        *"\`$p\`"*)
          case "$para" in
            *"if present"*|*"this project"*|*"it exists"*|*"doesn't exist"*|*"does not exist"*|*"otherwise"*|*"if there's no"*|*"if there is no"*|*"if no "*)
              ;;
            *)
              echo "FAIL: unconditional reference to optional persona '$p' in $f:"
              echo "  $para"
              bad=1
              ;;
          esac
          ;;
      esac
    done < <(awk -v RS='' '{gsub(/\n/, " "); print}' "$f")
  done
  [ "$bad" -eq 0 ] && echo "OK   all references to '$p' are conditionally phrased" || fail=1
done

echo
echo "== Cursor adapter: bash syntax =="
for f in adapters/cursor/hooks/scripts/*.sh; do
  if bash -n "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Cursor adapter: JSON validity =="
for f in adapters/cursor/hooks/hooks.json \
         adapters/cursor/.cursor-plugin/plugin.json \
         adapters/cursor/.cursor-plugin/marketplace.json; do
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Cursor adapter: agent/rule frontmatter has name/description or alwaysApply =="
for f in adapters/cursor/agents/*.md; do
  if grep -q '^name:' "$f" && grep -q '^description:' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing name: or description: in frontmatter)"
    fail=1
  fi
done
if grep -q '^alwaysApply:' adapters/cursor/rules/persona-protocol.mdc; then
  echo "OK   adapters/cursor/rules/persona-protocol.mdc"
else
  echo "FAIL adapters/cursor/rules/persona-protocol.mdc (missing alwaysApply:)"
  fail=1
fi

echo
echo "== Codex adapter: bash syntax =="
for f in adapters/codex/hooks/scripts/*.sh; do
  if bash -n "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Codex adapter: JSON validity =="
for f in adapters/codex/hooks/hooks.json \
         adapters/codex/.codex-plugin/plugin.json \
         adapters/codex/.codex-plugin/marketplace.json; do
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Codex adapter: TOML validity + name/description present =="
if python3 -c "import tomllib" >/dev/null 2>&1; then
  for f in adapters/codex/agents/*.toml; do
    if python3 -c "
import sys, tomllib
with open('$f', 'rb') as fh:
    d = tomllib.load(fh)
assert 'name' in d and d['name'], 'missing name'
assert 'description' in d and d['description'], 'missing description'
assert 'developer_instructions' in d and d['developer_instructions'].strip(), 'missing developer_instructions'
" 2>/tmp/codex_toml_err; then
      echo "OK   $f"
    else
      echo "FAIL $f ($(cat /tmp/codex_toml_err | tail -1))"
      fail=1
    fi
  done
  rm -f /tmp/codex_toml_err
else
  echo "SKIP (no python3 tomllib available - needs Python 3.11+; TOML validity not checked this run)"
fi

echo
echo "== Codex adapter: agents-md-fragment.md is clean of scaffold-time markers =="
# The ANTISLOP:BEGIN/END markers are added by bin/cli.js's upsertMarkedBlock
# at scaffold time (with a version number baked in) - the SOURCE fragment
# must never bake them in itself, or a scaffold run would nest one pair
# inside another instead of doing a clean version-agnostic replace.
if grep -q 'ANTISLOP:BEGIN\|ANTISLOP:END' adapters/codex/agents-md-fragment.md; then
  echo "FAIL adapters/codex/agents-md-fragment.md contains a literal ANTISLOP:BEGIN/END marker - remove it, markers are scaffold-time-only"
  fail=1
else
  echo "OK   adapters/codex/agents-md-fragment.md"
fi

echo
echo "== bin/cli.js legacy-backfill logic (Node) =="
if node tests/cli-backfill.test.js; then
  echo "OK   tests/cli-backfill.test.js"
else
  echo "FAIL tests/cli-backfill.test.js"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
