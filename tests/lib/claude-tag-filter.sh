# Drops the WARN/error lines `claude plugin tag --dry-run` permanently emits
# in this repo (see docs/plans/2026-07-22-fable-roast-cli-guard-followups.md
# Unit C) so tests/validate.sh's advisory block only surfaces genuinely new
# mismatches. Sourced by tests/validate.sh and tests/claude-tag-filter.test.sh.
filter_known_claude_tag_noise() {
  local line drop_next=0
  while IFS= read -r line; do
    if [[ "$line" == *"CLAUDE.md at the plugin root is not loaded as project context"* ]]; then
      continue
    fi
    if [[ "$line" == *"Plugin validation failed for"* && "$line" == *"agents/explorer.md"* ]]; then
      drop_next=1
      continue
    fi
    if [[ "$drop_next" -eq 1 ]]; then
      drop_next=0
      if [[ "$line" == *"frontmatter: YAML frontmatter failed to parse"* ]]; then
        continue
      fi
    fi
    echo "$line"
  done
}
