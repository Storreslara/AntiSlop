# unit-scope.sh (st-u1): unit-scope classification shared by review-precheck.sh
# (the reviewer's mechanical pre-review) and writer-scope-gate.sh (SubagentStop).
# Sourced, never executed (mode 644). Pure functions over files and git objects;
# nothing here writes a file.

# us_section <file> <heading>: the lines of `## <heading>` up to the next `## `
# heading, outside ``` and ~~~ fences.
us_section() {
  awk -v h="## $2" '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / { on = ($0 == h || index($0, h " ") == 1); next }
    on { print }
  ' "$1"
}

# us_entries <file> [<heading>]: every backtick-quoted token with no space that
# contains a `/` or a `.` in the file's `## <heading>` section (default
# `Affected files`), one per line.
us_entries() {
  us_section "$1" "${2:-Affected files}" | grep -oE '`[^` ]+`' | tr -d '`' | grep -E '[/.]' || true
}

# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a
# directory prefix of it, or is a glob that matches it.
us_listed() {
  local p="$1" e
  [ -s "$2" ] || return 1
  while IFS= read -r e || [ -n "$e" ]; do
    e="${e%/}"
    [ -n "$e" ] || continue
    [ "$p" = "$e" ] && return 0
    case "$p" in "$e"/*) return 0 ;; esac
    case "$e" in *[*?]*) [[ "$p" == $e ]] && return 0 ;; esac
  done < "$2"
  return 1
}

# us_named_in <path> <text-file>: exit 0 when the path occurs in the text as a
# whole path token (no path character directly before or after it).
us_named_in() {
  [ -s "$2" ] || return 1
  local q
  q="$(printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
  grep -qE "(^|[^A-Za-z0-9._/-])${q}(\$|[^A-Za-z0-9._/-])" "$2"
}

# us_executed_in <path> <text-file>: exit 0 when the text runs the path: as the
# script handed to bash, sh, node or python3 (flags between are allowed), or in
# command position (line start, after a backtick, ;, &, | or (). A path a
# command only reads is not executed (the rp-u1 unit-scope rule).
us_executed_in() {
  [ -s "$2" ] || return 1
  local q e='($|[^A-Za-z0-9._/-])'
  q="$(printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
  grep -qE "(^|[^A-Za-z0-9._/-])(bash|sh|node|python3)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*${q}${e}" "$2" \
    || grep -qE "(^|[\`;&|(])[[:space:]]*${q}${e}" "$2"
}

# us_excluded <path> <entries-file>: exit 0 when an entry of the contract's
# `## Do NOT touch` equals the path exactly. Exact only: a glob or directory
# there states a reason, and must never override a listed file.
us_excluded() {
  [ -s "$2" ] || return 1
  grep -qxF -- "$1" "$2"
}

# us_plugin_version <path> <rev>: exit 0 when <rev> is this plugin's own repo
# layout (it tracks .claude-plugin/plugin.json) and the path is one of the three
# version-stamp files that constitution P3 and validate.sh require every
# version-bumping commit to change.
us_plugin_version() {
  git cat-file -e "$2:.claude-plugin/plugin.json" 2>/dev/null || return 1
  case "$1" in .claude-plugin/plugin.json|package.json|CHANGELOG.md) return 0 ;; esac
  return 1
}

# us_version_name <path>: exit 0 for a file name that commonly holds a version
# stamp in other projects; such a path is left to the reviewer (class judge).
us_version_name() {
  case "${1##*/}" in package.json|plugin.json|CHANGELOG.md|VERSION|pyproject.toml|Cargo.toml|setup.cfg) return 0 ;; esac
  return 1
}

# us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text> [<excluded>]:
# prints exactly one class word: excluded | listed | criteria | fail-record |
# fix-contract | plugin-version | judge | out. Every file argument may be
# /dev/null; <excluded> (the `## Do NOT touch` entries) defaults to it. A
# criteria path counts only when the criteria read it, never when they run it.
us_classify() {
  local p="$1"
  if us_excluded "$p" "${7:-/dev/null}"; then echo excluded
  elif us_listed "$p" "$3"; then echo listed
  elif us_named_in "$p" "$5" && ! us_executed_in "$p" "$5"; then echo criteria
  elif us_named_in "$p" "$6"; then echo fail-record
  elif us_listed "$p" "$4"; then echo fix-contract
  elif us_plugin_version "$p" "$2"; then echo plugin-version
  elif us_version_name "$p"; then echo judge
  else echo out
  fi
}
