# Drops the WARN/error lines `claude plugin tag --dry-run` permanently emits
# in this repo (see docs/plans/2026-07-22-fable-roast-cli-guard-followups.md
# Unit C) so tests/validate.sh's advisory block only surfaces genuinely new
# mismatches. Sourced by tests/validate.sh and tests/claude-tag-filter.test.sh.
# NOTE: matched against canned/fixture strings, not live `claude` output — if
# agents/explorer.md's placeholder text or claude's wording ever drifts, this
# filter (and its fixture test) won't notice; that's an accepted tradeoff of
# not requiring a real `claude` binary in CI (issue #111, C2).
filter_known_claude_tag_noise() {
  local line drop_next=0
  local -a pending=()
  while IFS= read -r line; do
    if [[ "$line" == *"CLAUDE.md at the plugin root is not loaded as project context"* ]]; then
      continue
    fi
    if [[ "$drop_next" -eq 1 ]]; then
      if [[ -z "$line" ]]; then
        pending+=("$line")
        continue
      fi
      drop_next=0
      if [[ "$line" == *"frontmatter: YAML frontmatter failed to parse"* ]]; then
        pending=()
        continue
      fi
      printf '%s\n' "${pending[@]}"
      pending=()
    fi
    if [[ "$line" == *"Plugin validation failed for"* && "$line" == *"agents/explorer.md"* ]]; then
      drop_next=1
      pending=("$line")
      continue
    fi
    echo "$line"
  done
  if [[ "$drop_next" -eq 1 ]]; then
    printf '%s\n' "${pending[@]}"
  fi
}
