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
# `Affected files`), one per line. `Do NOT touch` is read by us_exclusions
# instead: a token there may sit in a reason or a partial-file qualifier.
us_entries() {
  if [ "${2:-}" = "Do NOT touch" ]; then us_exclusions "$1"; return 0; fi
  us_section "$1" "${2:-Affected files}" | grep -oE '`[^` ]+`' | tr -d '`' | grep -E '[/.]' || true
}

# us_exclusions <file>: the whole-file exclusions of the file's `## Do NOT touch`
# section, one per line (rp-u9). A bullet is a line starting `- ` plus its
# indented continuation lines, joined by one space. Its subject is the text
# before the first ` (`, `: `, ` - ` or ` — `, with trailing spaces and `.,;:`
# dropped. The subject excludes only when it is nothing but backticked path
# tokens (each holding a `/` or a `.`, no space) joined by `, `, ` and `,
# `, and `, ` or ` or `, or `; then every token is printed. Any other word in
# the subject (`by hand`, `except ...`, `ESCALATE-TO-HUMAN steps`) makes the
# bullet a partial restriction, never an exclusion. A bullet holding the
# marker `partial:` anywhere (written after the path: `x` partial: <part>)
# is a partial-file restriction whatever else it says.
us_exclusions() {
  us_section "$1" "Do NOT touch" | awk '
    function flush(   s, c, i, k, n, tok, seps) {
      s = b; b = ""; on = 0
      if (s == "" || index(s, "partial:") > 0) return
      c = 0; split(" (|: | - | — ", seps, "|")
      for (k = 1; k <= 4; k++) { i = index(s, seps[k]); if (i > 0 && (c == 0 || i < c)) c = i }
      if (c > 0) s = substr(s, 1, c - 1)
      sub(/[[:space:].,;:]+$/, "", s)
      n = 0
      while (1) {
        if (!match(s, /^`[^` ]+`/)) return
        tok[++n] = substr(s, 2, RLENGTH - 2)
        if (tok[n] !~ /[\/.]/) return
        s = substr(s, RLENGTH + 1)
        if (s == "") break
        if (!match(s, /^(, and |, or |, | and | or )/)) return
        s = substr(s, RLENGTH + 1)
      }
      for (k = 1; k <= n; k++) print tok[k]
    }
    /^- / { flush(); b = substr($0, 3); on = 1; next }
    on && /^[[:space:]]+[^[:space:]]/ { t = $0; sub(/^[[:space:]]+/, "", t); b = b " " t; next }
    { flush() }
    END { flush() }
  '
}

# us_safe_path <path>: exit 0 for a path the classes can judge: not empty, no
# newline (it would split into two grep patterns) and no `.` or `..` segment
# (`src/../x` must not count as under `src`). git never prints such a path
# unquoted; callers classify anything else `out`.
us_safe_path() {
  case "$1" in
    ''|*$'\n'*|.|..|./*|../*|*/.|*/..|*/./*|*/../*) return 1 ;;
  esac
  return 0
}

# us_glob_re <glob>: an anchored ERE for a contract glob. `*` and `?` match
# within one path segment, never across `/`; every other character is literal.
us_glob_re() {
  printf '^%s$' "$(printf '%s' "$1" | sed -e 's/[].[^$\\+(){}|]/\\&/g' -e 's#\*#[^/]*#g' -e 's#?#[^/]#g')"
}

# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a
# directory prefix of it, or is a glob that matches it (`*` and `?` within one
# segment). An unsafe path (us_safe_path) is never listed.
us_listed() {
  local p="$1" e re
  [ -s "$2" ] || return 1
  us_safe_path "$p" || return 1
  while IFS= read -r e || [ -n "$e" ]; do
    e="${e%/}"
    [ -n "$e" ] || continue
    [ "$p" = "$e" ] && return 0
    case "$p" in "$e"/*) return 0 ;; esac
    case "$e" in *[*?]*) re="$(us_glob_re "$e")"; [[ "$p" =~ $re ]] && return 0 ;; esac
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
# /dev/null; <excluded> (us_exclusions of the contract) defaults to it. A
# criteria path counts only when the criteria read it, never when they run it.
# An unsafe path (us_safe_path) is `out` before any other class is tried.
us_classify() {
  local p="$1"
  if ! us_safe_path "$p"; then echo out
  elif us_excluded "$p" "${7:-/dev/null}"; then echo excluded
  elif us_listed "$p" "$3"; then echo listed
  elif us_named_in "$p" "$5" && ! us_executed_in "$p" "$5"; then echo criteria
  elif us_named_in "$p" "$6"; then echo fail-record
  elif us_listed "$p" "$4"; then echo fix-contract
  elif us_plugin_version "$p" "$2"; then echo plugin-version
  elif us_version_name "$p"; then echo judge
  else echo out
  fi
}
