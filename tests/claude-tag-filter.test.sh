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

new_single_line_error="✘ Plugin validation failed for /home/example/project/agents/explorer.md: some new single-line error"
filtered=$(printf '%s\n' "$new_single_line_error" | filter_known_claude_tag_noise)
if [ "$filtered" = "$new_single_line_error" ]; then
  echo "OK   a new single-line error on agents/explorer.md survives the filter"
else
  echo "FAIL a new single-line error on agents/explorer.md was swallowed (or altered), got: $filtered"
  fail=1
fi

new_detail_block="✘ Plugin validation failed for /home/example/project/agents/explorer.md:
  some other, unrelated validation error that isn't the known frontmatter issue."
filtered=$(printf '%s\n' "$new_detail_block" | filter_known_claude_tag_noise)
if [ "$filtered" = "$new_detail_block" ]; then
  echo "OK   a header match with a mismatched detail line survives the filter intact"
else
  echo "FAIL a header match with a mismatched detail line was altered/swallowed, got: $filtered"
  fail=1
fi

explorer_header_line="✘ Plugin validation failed for /home/example/project/agents/explorer.md:"
explorer_detail_line="  frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token. At runtime this agent loads with empty metadata (all frontmatter fields silently dropped)."
block_with_blank_line="$explorer_header_line

$explorer_detail_line"
filtered=$(printf '%s\n' "$block_with_blank_line" | filter_known_claude_tag_noise)
if [ -z "$filtered" ]; then
  echo "OK   known-permanent block is still suppressed across a blank line"
else
  echo "FAIL known-permanent block leaked when a blank line was inserted, residual:"
  echo "$filtered"
  fail=1
fi

exit "$fail"
