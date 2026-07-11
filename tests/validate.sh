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
# planner/repo-historian/reviewer/researcher are opt-out (see README.md); a
# bare unconditional reference to one of them is exactly the class of bug
# that hard-errors when a project skips that persona. Checked per-PARAGRAPH
# (blank-line-separated, wrapped lines joined) rather than per physical line,
# since a conditional qualifier often lands on the next wrapped line.
for p in planner repo-historian reviewer researcher; do
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
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
