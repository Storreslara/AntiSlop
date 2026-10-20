# Shared helpers for the validate-speed criteria (vsp-1, vsp-2). Sourced, never run.
# Every case builds a throwaway git tree under a private mktemp root that holds:
#   - tests/validate.sh: the REAL file's lines 1 .. '# <<< skip-summary wrapper' (so the
#     real wrapper is under test), followed by stub sections and validate.sh's closing summary;
#   - copies of tests/validate-lanes.sh and every tests/lib/*.sh from this checkout.
# Nothing here reads or writes this checkout's .claude/ state.
set -uo pipefail
VSP_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VSP_ROOT="$(mktemp -d)" || exit 99
trap 'rm -rf "$VSP_ROOT"' EXIT
vsp_failures=0

mono() { cut -d' ' -f1 /proc/uptime; }

# vsp_body <sections...>: the stub suite body that follows the real wrapper block.
vsp_closing() {
  printf 'echo\nif [ "$fail" -eq 0 ]; then\n  echo "All checks passed."\nelse\n  echo "One or more checks FAILED."\nfi\nexit "$fail"\n'
}
# vsp_sec <n> [command]: one stub section; default command prints OK.
vsp_sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "${2:-echo \"OK   s$1\"}"; }

# vsp_tree <name> <body>: build the tree, print its path. Exit 99 when setup fails.
vsp_tree() {
  local t="$VSP_ROOT/$1" wrap_end
  mkdir -p "$t/tests/lib" "$t/.claude/reviewed" "$t/tmp"
  wrap_end="$(grep -n '^# <<< skip-summary wrapper' "$VSP_REPO/tests/validate.sh" | head -n 1 | cut -d: -f1)"
  [ -n "$wrap_end" ] || { echo "vsp_tree: no '# <<< skip-summary wrapper' line in tests/validate.sh" >&2; exit 99; }
  { sed -n "1,${wrap_end}p" "$VSP_REPO/tests/validate.sh"; printf '%s\n' "$2"; vsp_closing; } > "$t/tests/validate.sh"
  cp "$VSP_REPO/tests/validate-lanes.sh" "$t/tests/validate-lanes.sh"
  cp "$VSP_REPO"/tests/lib/*.sh "$t/tests/lib/"
  printf 'PASS old x\n' > "$t/.claude/reviewed/old.pass"
  printf 'tmp/\n' > "$t/.gitignore"
  (cd "$t" && git init -q && git add -A && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm init) \
    > /dev/null 2>&1 || { echo "vsp_tree: git setup failed in $t" >&2; exit 99; }
  printf '%s\n' "$t"
}

# vsp_run <dir> [env assignments...] -- [args...]: run <dir>/tests/validate.sh as the harness
# would (no INNER or leak-guard variables inherited). Sets RC, OUT, SECS.
vsp_run() {
  local d="$1" t0 t1; shift
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  t0="$(mono)"
  OUT="$(cd "$d" && env -u ANTISLOP_VALIDATE_INNER -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_SERIAL \
    -u ANTISLOP_VALIDATE_LANES -u ANTISLOP_VALIDATE_VERBOSE TMPDIR="$d/tmp" CLAUDE_PROJECT_DIR="$d" \
    ${envs[@]+"${envs[@]}"} bash tests/validate.sh "$@" 2>&1)"
  RC=$?
  t1="$(mono)"
  SECS="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')"
}

# vsp_check <id> <desc> <want-rc> <substring>...: '!' prefix = must be absent.
vsp_check() {
  local id="$1" desc="$2" want="$3" s bad=""; shift 3
  [ "$RC" = "$want" ] || bad="exit $RC, want $want"
  for s in "$@"; do
    case "$s" in
      '!'*) case "$OUT" in *"${s#!}"*) bad="${bad:+$bad; }unexpected: ${s#!}" ;; esac ;;
      *) case "$OUT" in *"$s"*) ;; *) bad="${bad:+$bad; }missing: $s" ;; esac ;;
    esac
  done
  if [ -z "$bad" ]; then echo "ok   ($id) $desc"; else echo "FAIL ($id) $desc: $bad"; vsp_failures=$((vsp_failures + 1)); fi
}

# vsp_assert <id> <desc> <condition-result: 0 pass, else fail> [detail]
vsp_assert() {
  if [ "$3" = 0 ]; then echo "ok   ($1) $2"; else echo "FAIL ($1) $2${4:+: $4}"; vsp_failures=$((vsp_failures + 1)); fi
}

vsp_done() {
  if [ "$vsp_failures" -eq 0 ]; then echo "all cases passed"; exit 0; fi
  echo "$vsp_failures case(s) FAILED"; exit 1
}
