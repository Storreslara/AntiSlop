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
to="$(command -v timeout)"

fail() { printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }

# Real tools the script may need, symlinked so PATH holds nothing else (no curl, wget, pip, pipx, oci).
mkdir -p "$work/tools" "$work/tools-nojq" "$work/stub"
for t in bash git jq mktemp cp rm cat dirname grep cut env sed timeout sleep; do
  ln -s "$(command -v "$t")" "$work/tools/$t"
  [ "$t" = jq ] || ln -s "$(command -v "$t")" "$work/tools-nojq/$t"
done
for t in curl wget pip pipx; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$0 $*" >> "$STUB_NET_LOG"\n' > "$work/stub/$t"
done
cat > "$work/oci" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_OCI_LOG"
case "$1" in
  --version) printf '%s\n' "${STUB_OCI_VERSION:-oci 0.50.1}" ;;
  validate)
    yml=0 oc=0
    [ -e "$3/outcome.yml" ] && yml=1
    [ -e "$3/.outcomeci" ] && oc=1
    printf '%s yml=%s outcomeci=%s\n' "$3" "$yml" "$oc" >> "$STUB_VDIR_LOG"
    printf '%s\n' "${STUB_VALIDATE_OUT:-{\"valid\": true, \"workflow_revision\": \"x\"}}" ;;
esac
EOS
cat > "$work/docker" <<'EOS'
#!/usr/bin/env bash
[ -z "${STUB_DOCKER_HANG:-}" ] || exec sleep 60
exit "${STUB_DOCKER_RC:-0}"
EOS
chmod +x "$work"/stub/* "$work/oci" "$work/docker"

# run <case id> <with-oci 0|1> [args...]; env STUB_*, TOOLS, TMPDIR_CASE and the token pass through from the caller.
# Sets out (stdout), rc; stderr lands in $work/err.
run() {
  local name="$1" with_oci="$2"
  shift 2
  mkdir -p "$work/p-$name"
  rm -rf "$work/oci.log" "$work/vdir.log" "$work/tmpd"
  mkdir "$work/tmpd"
  : > "$work/net.log"
  cp "$work/docker" "$work/p-$name/docker"
  [ "$with_oci" = 1 ] && cp "$work/oci" "$work/p-$name/oci"
  out="$(STUB_OCI_LOG="$work/oci.log" STUB_VDIR_LOG="$work/vdir.log" STUB_NET_LOG="$work/net.log" \
    TMPDIR="${TMPDIR_CASE:-$work/tmpd}" PATH="$work/p-$name:$work/stub:${TOOLS:-$work/tools}" \
    "$to" 25 bash "$bin" "$@" 2>"$work/err")"
  rc=$?
  [ "$rc" -ne 124 ] || fail "$name" "timed out (outer timeout 25)"
  # P7: per-case network and oci-argv assertions.
  [ ! -s "$work/net.log" ] || fail P7 "$name: network tool called: $(cat "$work/net.log")"
  if [ -e "$work/oci.log" ] && grep -qvE '^--version$|^validate --dir ' "$work/oci.log"; then
    fail P7 "$name: unexpected oci argv: $(cat "$work/oci.log")"
  fi
  ! grep -qF SECRETVALUE "$work/err" || fail P6 "$name: token value on stderr"
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
TOOLS="$work/tools-nojq" run P0 1
want P0 2 'check tools=fail'
[ "${out##*$'\n'}" = 'preflight=blocked reason=tools' ] || fail P0 "last line is not preflight=blocked reason=tools"

run P1 1
want P1 0 'preflight=ready' 'oci-series-gate.sh --unit' 'state-snapshot.sh' 'next:'
[ "${out##*$'\n'}" = preflight=ready ] || fail P1 "last line is not preflight=ready"
[ -s "$work/oci.log" ] || fail P1 "oci stub was never called (validate not exercised)"
# P11: the temp copy is removed.
[ -z "$(ls -A "$work/tmpd")" ] || fail P11 "temp dir not empty after run: $(ls -A "$work/tmpd")"
# P12: validate saw a temp copy under TMPDIR holding the workflow files.
vline="$(cat "$work/vdir.log" 2>/dev/null)"
[[ $vline == "$work/tmpd/"*" yml=1 outcomeci=1" ]] || fail P12 "validate dir log: '$vline'"
[[ $out != *SECRETVALUE* ]] || fail P6 "token value printed"
# P8: the next: block never names --cloud.
nb="${out#*next:}"
[[ $nb != *--cloud* ]] || fail P8 "next: block contains --cloud"

run P2 0
want P2 3 'check oci=missing' 'pipx install outcomeci-cli==0.50.1' 'preflight=blocked reason=oci'

STUB_OCI_VERSION='oci 0.49.0' run P3 1
want P3 4 'preflight=blocked reason=oci-version'

STUB_VALIDATE_OUT='{"valid": false}' run P4 1
want P4 5 'preflight=blocked reason=validate'

STUB_DOCKER_RC=1 run P5 1
want P5 6 'preflight=blocked reason=docker'

unset CLAUDE_CODE_OAUTH_TOKEN
run P6 1
want P6 7 'preflight=blocked reason=token'
export CLAUDE_CODE_OAUTH_TOKEN=SECRETVALUE
STUB_DOCKER_RC=1 run P6b 1
[[ $out != *SECRETVALUE* ]] || fail P6 "token value printed on a failing run"

# The first failing check wins: missing oci beats a failing docker, and docker is still reported.
STUB_DOCKER_RC=1 run P2b 0
want P2b 3 'preflight=blocked reason=oci' 'check docker=fail'

# P9: --unit substitutes the cited commit; without it the placeholders stay.
fx="$work/fx"
mkdir -p "$fx/.claude/$rv"
printf 'PASS ocig-fx 2026-10-05T00:00:00Z commit: abc1234 criteria: true\n' > "$fx/.claude/$rv/ocig-fx.pass"
run P9 1 --unit ocig-fx --project-dir "$fx"
want P9 0 '--unit ocig-fx --sha abc1234'
run P9b 1
want P9b 0 '--unit <unit> --sha <sha>'
run P9c 1 --unit ocig-absent --project-dir "$fx"
want P9c 0 '--unit ocig-absent --sha <sha>'
run P9d 1 --unit '../evil' --project-dir "$fx"
want P9d 64
# A marker whose commit field is not hex never reaches the commands, and is never executed.
# Each fixture's task-id equals --unit, so only the hex check can cause the fallback.
printf 'PASS ocig-bad 2026-10-05T00:00:00Z commit: $(touch %s/pwned) criteria: true\n' "$work" > "$fx/.claude/$rv/ocig-bad.pass"
printf 'PASS ocig-bad2 2026-10-05T00:00:00Z commit: zzzzzzz criteria: true\n' > "$fx/.claude/$rv/ocig-bad2.pass"
printf 'PASS ocig-bad3 2026-10-05T00:00:00Z commit: $(id)abcdef criteria: true\n' > "$fx/.claude/$rv/ocig-bad3.pass"
for u in ocig-bad ocig-bad2 ocig-bad3; do
  run P9e 1 --unit "$u" --project-dir "$fx"
  want P9e 0 "--unit $u --sha <sha>"
done
[ ! -e "$work/pwned" ] || fail P9e "marker text was executed"

# P13: a failing mktemp reports validate=fail and never runs oci validate.
TMPDIR_CASE="$work/missing" run P13 1
want P13 5 'check validate=fail'
! grep -q '^validate' "$work/oci.log" 2>/dev/null || fail P13 "oci validate ran: $(cat "$work/oci.log")"

# P14: line 1 naming another unit is not trusted.
printf 'PASS ocig-other 2026-10-05T00:00:00Z commit: abc1234 criteria: true\n' > "$fx/.claude/$rv/ocig-fx2.pass"
run P14 1 --unit ocig-fx2 --project-dir "$fx"
want P14 0 '--unit ocig-fx2 --sha <sha>'
[[ $out != *abc1234* ]] || fail P14 "mismatched marker commit used"

# P15: empty or non-directory arguments are usage errors.
run P15 1 --unit ''
want P15 64
run P15 1 --project-dir ''
want P15 64
run P15 1 --project-dir "$work/nonexistent"
want P15 64

# P16: a missing marker writes nothing to stderr.
run P16 1 --unit ocig-absent --project-dir "$fx"
want P16 0
[ ! -s "$work/err" ] || fail P16 "stderr not empty: $(cat "$work/err")"

# P17: a FIFO marker is never opened.
mkfifo "$fx/.claude/$rv/ocig-ff.pass"
run P17 1 --unit ocig-ff --project-dir "$fx"
want P17 0 '--unit ocig-ff --sha <sha>'

# P18: a hanging docker is cut off and reported as docker=fail.
t0=$SECONDS
STUB_DOCKER_HANG=1 run P18 1
want P18 6 'check docker=fail'
[ $((SECONDS - t0)) -lt 20 ] || fail P18 "took $((SECONDS - t0)) s"

# P19: --project-dir is passed on, %q-quoted, to the wrapper and both snapshots.
fx2="$work/fx sp"
q="$(printf %q "$fx2")"
mkdir -p "$fx2/.claude/$rv"
printf 'PASS ocig-fx 2026-10-05T00:00:00Z commit: abc1234 criteria: true\n' > "$fx2/.claude/$rv/ocig-fx.pass"
run P19 1 --unit ocig-fx --project-dir "$fx2"
want P19 0 "--sha abc1234 --project-dir $q --"
n="$(printf '%s\n' "$out" | grep -cF -- "state-snapshot.sh $q")"
[ "$n" = 2 ] || fail P19 "state-snapshot.sh $q lines: $n, want 2"
run P19 1
[[ $out != *--project-dir* ]] || fail P19 "--project-dir printed without the option"
n="$(printf '%s\n' "$out" | grep -cF -- 'state-snapshot.sh . ')"
[ "$n" = 2 ] || fail P19 "state-snapshot.sh . lines: $n, want 2"

# P10: the repo is untouched.
[ "$(git -C "$repo" status --porcelain)" = "$status0" ] || fail P10 "git status changed"

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
