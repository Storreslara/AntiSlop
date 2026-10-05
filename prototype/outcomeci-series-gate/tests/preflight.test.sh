#!/usr/bin/env bash
# Exercises preflight.sh (or $PREFLIGHT_BIN) with stubbed oci/docker/curl/wget/pip/pipx on a minimal PATH.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="${PREFLIGHT_BIN:-$here/../preflight.sh}"
repo="$(cd "$here/../../.." && pwd)"
rv=reviewed
failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
status0="$(git -C "$repo" status --porcelain)"

fail() { printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }

# Real tools the script may need, symlinked so PATH holds nothing else (no curl, wget, pip, pipx, oci).
mkdir -p "$work/tools" "$work/stub"
for t in bash git jq mktemp cp rm cat dirname grep cut env sed; do
  ln -s "$(command -v "$t")" "$work/tools/$t"
done
for t in curl wget pip pipx; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$0 $*" >> "$STUB_NET_LOG"\n' > "$work/stub/$t"
done
cat > "$work/oci" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_OCI_LOG"
case "$1" in
  --version) printf '%s\n' "${STUB_OCI_VERSION:-oci 0.50.1}" ;;
  validate) printf '%s\n' "${STUB_VALIDATE_OUT:-{\"valid\": true, \"workflow_revision\": \"x\"}}" ;;
esac
EOS
cat > "$work/docker" <<'EOS'
#!/usr/bin/env bash
exit "${STUB_DOCKER_RC:-0}"
EOS
chmod +x "$work"/stub/* "$work/oci" "$work/docker"

# run <name> <with-oci 0|1> [args...]; env STUB_* and CLAUDE_CODE_OAUTH_TOKEN pass through from the caller.
run() {
  local name="$1" with_oci="$2"
  shift 2
  mkdir -p "$work/p-$name"
  rm -f "$work/oci.log"
  : > "$work/net.log"
  cp "$work/docker" "$work/p-$name/docker"
  [ "$with_oci" = 1 ] && cp "$work/oci" "$work/p-$name/oci"
  out="$(STUB_OCI_LOG="$work/oci.log" STUB_NET_LOG="$work/net.log" PATH="$work/p-$name:$work/stub:$work/tools" \
    bash "$bin" "$@" 2>&1)"
  rc=$?
  # P7: per-case network and oci-argv assertions.
  [ ! -s "$work/net.log" ] || fail "$name/P7" "network tool called: $(cat "$work/net.log")"
  if [ -e "$work/oci.log" ] && grep -qvE '^--version$|^validate --dir ' "$work/oci.log"; then
    fail "$name/P7" "unexpected oci argv: $(cat "$work/oci.log")"
  fi
}

want() { # <case> <rc> [substring...]
  local name="$1" w="$2" s
  shift 2
  [ "$rc" -eq "$w" ] || fail "$name" "rc=$rc, want $w"
  for s in "$@"; do
    [[ $out == *"$s"* ]] || fail "$name" "output lacks '$s'"
  done
}

export CLAUDE_CODE_OAUTH_TOKEN=SECRETVALUE
run p1 1
want P1 0 'preflight=ready' 'oci-series-gate.sh --unit' 'state-snapshot.sh' 'next:'
[ "${out##*$'\n'}" = preflight=ready ] || fail P1 "last line is not preflight=ready"
[ -s "$work/oci.log" ] || fail P1 "oci stub was never called (validate not exercised)"
[[ $out != *SECRETVALUE* ]] || fail P6 "token value printed"
# P8: the next: block never names --cloud.
nb="${out#*next:}"
[[ $nb != *--cloud* ]] || fail P8 "next: block contains --cloud"

run p2 0
want P2 3 'check oci=missing' 'pipx install outcomeci-cli==0.50.1' 'preflight=blocked reason=oci'

STUB_OCI_VERSION='oci 0.49.0' run p3 1
want P3 4 'preflight=blocked reason=oci-version'

STUB_VALIDATE_OUT='{"valid": false}' run p4 1
want P4 5 'preflight=blocked reason=validate'

STUB_DOCKER_RC=1 run p5 1
want P5 6 'preflight=blocked reason=docker'

unset CLAUDE_CODE_OAUTH_TOKEN
run p6 1
want P6 7 'preflight=blocked reason=token'
export CLAUDE_CODE_OAUTH_TOKEN=SECRETVALUE
STUB_DOCKER_RC=1 run p6b 1
[[ $out != *SECRETVALUE* ]] || fail P6 "token value printed on a failing run"

# The first failing check wins: missing oci beats a failing docker, and docker is still reported.
STUB_DOCKER_RC=1 run p2b 0
want P2b 3 'preflight=blocked reason=oci' 'check docker=fail'

# P9: --unit substitutes the cited commit; without it the placeholders stay.
fx="$work/fx"
mkdir -p "$fx/.claude/$rv"
printf 'PASS ocig-fx 2026-10-05T00:00:00Z commit: abc1234 criteria: true\n' > "$fx/.claude/$rv/ocig-fx.pass"
run p9 1 --unit ocig-fx --project-dir "$fx"
want P9 0 '--unit ocig-fx --sha abc1234'
run p9b 1
want P9b 0 '--unit <unit> --sha <sha>'
run p9c 1 --unit ocig-absent --project-dir "$fx"
want P9c 0 '--unit ocig-absent --sha <sha>'
run p9d 1 --unit '../evil' --project-dir "$fx"
want P9d 64
# A marker whose commit field is not hex never reaches the commands, and is never executed.
printf 'PASS ocig-bad 2026-10-05T00:00:00Z commit: $(touch %s/pwned) criteria: true\n' "$work" > "$fx/.claude/$rv/ocig-bad.pass"
run p9e 1 --unit ocig-bad --project-dir "$fx"
want P9e 0 '--sha <sha>'
[ ! -e "$work/pwned" ] || fail P9e "marker text was executed"

# P10: the repo is untouched.
[ "$(git -C "$repo" status --porcelain)" = "$status0" ] || fail P10 "git status changed"

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
