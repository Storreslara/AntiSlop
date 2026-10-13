# Shared helpers for the epf-1..epf-6 acceptance scripts (source this file).
# Every script starts at the repository root, so a criterion is `bash <script>`
# run from anywhere inside the checkout.
cd "$(git rev-parse --show-toplevel)" || exit 99

# vsec <i> <j>: run validate.sh sections i..j (1-based header order; j>=count
# means "to the end"). Set REVIEWED_DIR_LEAK_GUARD_NESTED=1 first (section 101
# is a nested full validate.sh and is a no-op under that variable).
vsec() {
  local s rc; s=$(mktemp)
  { printf 'set -uo pipefail\ncd %s\nfail=0\n' "$(git rev-parse --show-toplevel)"
    awk -v i="$1" -v j="$2" '
      NR==FNR { if (/^echo "== /) h[++c]=FNR; next }
      FNR==1  { lo=h[i]; hi=(j<c)?h[j+1]-1:999999 }
      FNR>=lo && FNR<=hi' tests/validate.sh tests/validate.sh
    printf '\nexit "$fail"\n'; } > "$s"
  bash "$s"; rc=$?; rm -f "$s"; return "$rc"
}

# vrun '<header substring>': run every section whose == header contains the string.
vrun() {
  local s rc; s=$(mktemp)
  { printf 'set -uo pipefail\ncd %s\nfail=0\n' "$(git rev-parse --show-toplevel)"
    awk -v k="$1" '/^echo "== /{on=index($0,k)>0} on' tests/validate.sh
    printf '\nexit "$fail"\n'; } > "$s"
  grep -q '^echo "== ' "$s" || { echo "vrun: no section matches: $1"; rm -f "$s"; return 2; }
  bash "$s"; rc=$?; rm -f "$s"; return "$rc"
}

# ucommits <unit-id>: the unit's own commits, newest first, matched on the
# subject scope only (never on a body line).
ucommits() {
  local id; id=$(printf '%s' "$1" | sed 's/\./\\./g')
  git log --format='%H %s' | grep -E "^[0-9a-f]+ [a-z]+\\(${id}\\): " | cut -d' ' -f1
}
uF() { ucommits "$1" | tail -1; }   # first commit of the unit
uL() { ucommits "$1" | head -1; }   # last commit of the unit

# need_unit <unit-id>: set F and L, or fail with exit 3 (no commit yet).
need_unit() {
  F=$(uF "$1"); L=$(uL "$1")
  [ -n "$F" ] && [ -n "$L" ] || { echo "no-unit-commit: $1"; exit 3; }
}

# MIRROR_RE: the generated mirrors a mirror-refreshing unit may change.
MIRROR_RE='^\.claude/(agents/[^/]+\.md|persona-protocol(-slim)?\.md|protocol-digest\.md|persona-config[.]json)$'
