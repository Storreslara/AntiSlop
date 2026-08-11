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

# Wire data reaching an append-only audit log. Percent-encodes every byte
# outside the identity token charset (alnum/:/-/_/.), which makes the result
# single-line, space-free and glob-free - so it can neither forge a second line
# into the log the review lifecycle uses nor be read back as a pattern - while
# staying INJECTIVE. Injectivity is the load-bearing property: the encoded form
# is also the dedupe key below, and the earlier strip-the-bad-bytes version was
# many-to-one, so a crafted identity could collapse onto a genuine one's key and
# suppress it. Runs in the C locale to encode bytes, not multibyte characters.
_identity_sanitize() {
  local LC_ALL=C s="${1-}" out="" trunc="" i c
  if [ "${#s}" -gt 128 ]; then
    # A cap is still needed to bound log growth, and truncation is inherently
    # lossy. "~" cannot be produced by the encoder, so it keeps every truncated
    # value in a keyspace disjoint from every pristine one; two over-long
    # identities sharing a 128-byte prefix do share one key, which only ever
    # buckets crafted noise together (a real agent identity is never this long)
    # and cannot cross classes, since class is part of the key below.
    s="${s:0:128}"
    trunc="~"
  fi
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [A-Za-z0-9:_.-]) out+="$c" ;;
      *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
    esac
  done
  printf '%s' "${out}${trunc}"
}

# Logs only the two drift classes that signal an identity-FORM change. A bare
# identity that is merely an unknown persona name (Explore, general-purpose) is
# normal traffic and must stay unlogged, or the log is swamped and useless.
identity_drift_log() {
  local id="${1-}" hook="${2-}" audit="${3-}" class="" ns safe imarker cmarker line
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
  # Dedupe on the (class, identity) PAIR, not on the identity field alone.
  # `class` is computed from the RAW id while `safe` is the encoded one, so
  # keying on `safe` alone is only sound where the encoding is injective - and
  # the 128-byte cap above deliberately is not. Matching both fields keeps the
  # key injective within a class, which is what dedupe actually needs. Both
  # markers are compared as literals via suffix/prefix stripping rather than
  # grepped, since the identity is wire data and would otherwise be read as a
  # pattern. `hook` sits between the two fields, hence two markers.
  imarker=" identity=${safe}"
  cmarker=" identity-drift class=${class} hook="
  # An unreadable-but-existing audit log must not abort the caller either: the
  # read below is a redirection, whose failure `set -e` treats as fatal.
  if [ -f "$audit" ] && [ -r "$audit" ]; then
    while IFS= read -r line; do
      if [ "${line%"$imarker"}" != "$line" ] && [ "${line#*"$cmarker"}" != "$line" ]; then
        return 0
      fi
    done < "$audit"
  fi
  # Dedupe is best-effort, not a hard guarantee: a concurrent writer can append between this scan and the write below (TOCTOU), producing a duplicate rather than corrupting the log.
  # A write failure here (disk full, unwritable audit path, ...) must degrade
  # to "the drift wasn't logged" rather than aborting the calling hook under
  # its `set -e` - this is a logging side-effect, never a gate decision. The
  # brace group is required: a failed redirection is diagnosed by the shell
  # itself, so a bare `2>/dev/null` on the command would not silence it.
  { printf '%s identity-drift class=%s hook=%s identity=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$class" "$(_identity_sanitize "$hook")" "$safe" \
      >> "$audit"; } 2>/dev/null || true
}
