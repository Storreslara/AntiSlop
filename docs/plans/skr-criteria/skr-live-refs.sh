#!/usr/bin/env bash
# Usage: skr-live-refs.sh <key>...
# Keys: grill-me grill-with-docs code-review to-spec to-tickets fail-triage
#       vsd-preload handoff-preload tdd-skill-invoke seams-confirm
# Exit 0 iff no key has a hit on a live surface. A hit on a line that also
# names docs/archive/skills/ is a pointer into the archive and is allowed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

pat() {
  case "$1" in
    grill-me) echo 'grill-me' ;;
    grill-with-docs) echo 'grill-with-docs' ;;
    code-review) echo 'skills/code-review|antislop:code-review|`code-review` skill' ;;
    to-spec) echo 'to-spec' ;;
    to-tickets) echo 'to-tickets' ;;
    fail-triage) echo 'fail-triage' ;;
    vsd-preload) echo '^skills:.*version-stamp-discipline' ;;
    handoff-preload) echo '^skills:.*antislop:handoff' ;;
    tdd-skill-invoke) echo '`antislop:tdd` skill via the `Skill` tool|^ *`antislop:tdd` skill via' ;;
    seams-confirm) echo 'confirm them with the user|unconfirmed seam' ;;
    *) return 1 ;;
  esac
}

LIVE=(agents .claude/agents templates .claude/persona-protocol.md
      .claude/persona-protocol-slim.md .claude/protocol-digest.md adapters
      skills .claude/skills hooks .claude/hooks bin commands scripts
      README.md .claude-plugin docs/maintenance)
# CONTEXT.md and docs/harness-glossary.md are checked by skr-glossary.sh.

[ "$#" -gt 0 ] || { echo "usage: $0 <key>..." >&2; exit 2; }
total=0
for key in "$@"; do
  p="$(pat "$key")" || { echo "unknown key: $key" >&2; exit 2; }
  hits="$(git grep -n -w -E -e "$p" -- "${LIVE[@]}" 2>/dev/null | grep -v 'docs/archive/skills/' || true)"
  n=0
  [ -n "$hits" ] && n="$(printf '%s\n' "$hits" | wc -l)"
  echo "skr-live-refs: $key hits=$n"
  [ "$n" -gt 0 ] && printf '%s\n' "$hits" | head -20 | sed 's/^/  /'
  total=$((total + n))
done
[ "$total" -eq 0 ]
