#!/usr/bin/env bash
# Shared agent-identity matching for the gate hooks. Sourced, never executed.
# An agent identity is "[<namespace>:]<persona-name>" and only the FIRST colon
# splits it; a persona name is always bare.
#
# The two matchers fail in deliberately OPPOSITE directions - this asymmetry is
# the design, not an inconsistency:
#   persona_matches_gate  LIBERAL      for GATE sites, where a miss fails OPEN.
#                                      Over-matching costs one extra gate;
#                                      under-matching IS the bug.
#   persona_matches_grant CONSERVATIVE for privilege-GRANT sites (writing PASS
#                                      markers, clearing review flags), where a
#                                      miss fails CLOSED, loud and recoverable,
#                                      but over-matching hands authority to a
#                                      foreign namespace. Its <expected> arg
#                                      MUST be a bare script literal.

_IDENTITY_TOKEN='[A-Za-z0-9_.-]+'
_identity_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
_identity_ns=""

# The recognized namespace is derived from the library's own on-disk location,
# which is what lets one byte-identical file serve all three platform ports.
# Resolved once per script invocation (memoized), and never on the GATE-only
# paths, so the hot hooks pay no jq for it.
identity_recognized_namespace() {
  if [ -n "$_identity_ns" ]; then
    printf '%s' "$_identity_ns"
    return 0
  fi
  local dir mf name=""
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -r "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    name="$(jq -r '.name // empty' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || true)"
  fi
  dir="$_identity_lib_dir"
  while [ -z "$name" ] && [ -n "$dir" ]; do
    for mf in .claude-plugin .cursor-plugin .codex-plugin; do
      if [ -r "${dir}/${mf}/plugin.json" ]; then
        name="$(jq -r '.name // empty' "${dir}/${mf}/plugin.json" 2>/dev/null || true)"
        break
      fi
    done
    if [ "$dir" = "/" ]; then
      break
    fi
    dir="$(dirname "$dir")"
  done
  if [ -z "$name" ]; then
    name="antislop"
  fi
  _identity_ns="$name"
  printf '%s' "$_identity_ns"
}

# Canonical comparable form: the <persona-name> suffix. Unchanged (not an
# error) for a bare identity or a malformed split such as ":x" or "x:".
identity_persona_name() {
  local id="${1-}" ns rest
  case "$id" in
    *:*) ;;
    *) printf '%s' "$id"; return 0 ;;
  esac
  ns="${id%%:*}"
  rest="${id#*:}"
  if [[ $ns =~ ^${_IDENTITY_TOKEN}$ ]] && [ -n "$rest" ]; then
    printf '%s' "$rest"
  else
    printf '%s' "$id"
  fi
}

identity_namespace() {
  local id="${1-}" ns rest
  case "$id" in
    *:*) ;;
    *) return 0 ;;
  esac
  ns="${id%%:*}"
  rest="${id#*:}"
  if [[ $ns =~ ^${_IDENTITY_TOKEN}$ ]] && [ -n "$rest" ]; then
    printf '%s' "$ns"
  fi
}

persona_matches_gate() {
  local a b
  a="$(identity_persona_name "${1-}")"
  b="$(identity_persona_name "${2-}")"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" = "$b" ]
}

persona_matches_grant() {
  local cand="${1-}" want="${2-}" ns
  if [ -z "$cand" ] || [ -z "$want" ]; then
    return 1
  fi
  if [ "$cand" = "$want" ]; then
    return 0
  fi
  ns="$(identity_namespace "$cand")"
  if [ -z "$ns" ] || [ "$ns" != "$(identity_recognized_namespace)" ]; then
    return 1
  fi
  [ "$(identity_persona_name "$cand")" = "$want" ]
}

# Wire data reaching an append-only audit log: strip CR/LF and cap length, or a
# crafted value can forge a second line into the log the review lifecycle uses.
_identity_sanitize() {
  local s="${1-}"
  s="${s//$'\n'/}"
  s="${s//$'\r'/}"
  printf '%s' "${s:0:128}"
}

# Logs only the two drift classes that signal an identity-FORM change. A bare
# identity that is merely an unknown persona name (Explore, general-purpose) is
# normal traffic and must stay unlogged, or the log is swamped and useless.
identity_drift_log() {
  local id="${1-}" hook="${2-}" audit="${3-}" class="" ns safe marker line
  if [ -z "$id" ] || [ -z "$audit" ] || [ ! -d "$(dirname "$audit")" ]; then
    return 0
  fi
  if [[ $id =~ ^${_IDENTITY_TOKEN}$ ]] || [[ $id =~ ^${_IDENTITY_TOKEN}:${_IDENTITY_TOKEN}$ ]]; then
    ns="$(identity_namespace "$id")"
    if [ -n "$ns" ] && [ "$ns" != "$(identity_recognized_namespace)" ]; then
      class="unrecognized-namespace"
    fi
  else
    class="unparseable"
  fi
  if [ -z "$class" ]; then
    return 0
  fi
  safe="$(_identity_sanitize "$id")"
  # Dedupe on the identity field alone, which is the last field on the line.
  # Equivalent to keying on (class, identity) since class is a pure function of
  # the identity. Suffix-stripped rather than grepped: the identity is wire data
  # and would otherwise be interpreted as a pattern.
  marker=" identity=${safe}"
  if [ -f "$audit" ]; then
    while IFS= read -r line; do
      if [ "${line%"$marker"}" != "$line" ]; then
        return 0
      fi
    done < "$audit"
  fi
  printf '%s identity-drift class=%s hook=%s identity=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$class" "$(_identity_sanitize "$hook")" "$safe" >> "$audit"
}
