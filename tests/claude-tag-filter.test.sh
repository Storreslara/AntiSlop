#!/usr/bin/env bash
# Fixture-driven test for tests/lib/claude-tag-filter.sh's
# filter_known_claude_tag_noise, run with canned `claude plugin tag --dry-run`
# output so it never needs the real `claude` binary.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/claude-tag-filter.sh
fail=0

claude_md_notice="⚠ CLAUDE.md: CLAUDE.md at the plugin root is not loaded as project context. To ship context with your plugin, use a skill (skills/<name>/SKILL.md) instead."
explorer_placeholder_block="✘ Plugin validation failed for /home/example/project/agents/explorer.md:
  frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token. At runtime this agent loads with empty metadata (all frontmatter fields silently dropped)."
known_permanent_output="$claude_md_notice
$explorer_placeholder_block"

filtered=$(printf '%s\n' "$claude_md_notice" | filter_known_claude_tag_noise)
if [ -z "$filtered" ]; then
  echo "OK   CLAUDE.md-not-loaded notice is suppressed"
else
  echo "FAIL CLAUDE.md-not-loaded notice not suppressed, residual: $filtered"
  fail=1
fi

filtered=$(printf '%s\n' "$known_permanent_output" | filter_known_claude_tag_noise)
if [ -z "$filtered" ]; then
  echo "OK   both known-permanent WARNs are fully suppressed"
else
  echo "FAIL known-permanent WARNs not fully suppressed, residual:"
  echo "$filtered"
  fail=1
fi

new_mismatch_line="✘ Plugin validation failed for /home/example/project/.claude-plugin/marketplace.json: entry 'antislop' source '../antislop' does not match plugin.json"
injected_output="$known_permanent_output
$new_mismatch_line"

filtered=$(printf '%s\n' "$injected_output" | filter_known_claude_tag_noise)
if [ "$filtered" = "$new_mismatch_line" ]; then
  echo "OK   a genuinely new mismatch line survives the filter"
else
  echo "FAIL a genuinely new mismatch line was swallowed (or altered) by the allowlist filter, got: $filtered"
  fail=1
fi

exit "$fail"
