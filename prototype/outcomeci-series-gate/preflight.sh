#!/usr/bin/env bash
# Host-only, zero-API Step 4 preflight: reports each check, prints the operator's next commands.
# Usage: preflight.sh [--unit <task-id>] [--project-dir <dir>]
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
proj="$here/../.."
unit="" pdir=""
usage() { echo 'usage: preflight.sh [--unit <task-id>] [--project-dir <dir>]' >&2; exit 64; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --unit) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; unit="$2"; shift 2 ;;
    --project-dir) [ "$#" -ge 2 ] && [ -d "$2" ] || usage; proj="$2" pdir="$2"; shift 2 ;;
    *) usage ;;
  esac
done

dot="$proj/.claude"
. "$here/../../hooks/scripts/lib/state-access.sh"
set +e
if [ -n "$unit" ]; then unit_id_valid "$unit" || usage; fi

first=0 reason=""
report() { # <name> <rc> <exit code if rc!=0> <value>
  printf 'check %s=%s\n' "$1" "$4"
  if [ "$2" -ne 0 ] && [ "$first" -eq 0 ]; then first="$3"; reason="$1"; fi
}

have=0
for t in bash git jq; do command -v "$t" >/dev/null 2>&1 || have=1; done
report tools "$have" 2 "$([ "$have" -eq 0 ] && echo ok || echo fail)"

have_oci=0
command -v oci >/dev/null 2>&1 || have_oci=1
report oci "$have_oci" 3 "$([ "$have_oci" -eq 0 ] && echo present || echo missing)"

if [ "$have_oci" -eq 0 ]; then
  ver="$(oci --version 2>/dev/null)"
  [ "$ver" = 'oci 0.50.1' ]; rc=$?
  report oci-version "$rc" 4 "$([ "$rc" -eq 0 ] && echo ok || echo bad)"
  tmp="" vout=""
  if tmp="$(mktemp -d 2>/dev/null)" && cp -a "$here/workflow/." "$tmp"/; then
    vout="$(oci validate --dir "$tmp" 2>/dev/null)"
  fi
  rm -rf "$tmp"
  [[ $vout == *'"valid": true'* ]]; rc=$?
  report validate "$rc" 5 "$([ "$rc" -eq 0 ] && echo ok || echo fail)"
else
  report oci-version 0 4 skipped
  report validate 0 5 skipped
fi

timeout 10 docker info >/dev/null 2>&1; rc=$?
report docker "$rc" 6 "$([ "$rc" -eq 0 ] && echo ok || echo fail)"

[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; rc=$?
report token "$rc" 7 "$([ "$rc" -eq 0 ] && echo set || echo unset)"

# The commit comes from a regular-file marker's first line, naming this unit and hex-validated; nothing else is used.
sha='<sha>' uid="${unit:-<unit>}"
if [ -n "$unit" ]; then
  line="" m="$(unit_id_marker_path "$unit" pass)"
  [ -f "$m" ] && read -r line < "$m"
  if [[ $line =~ ^PASS\ ([^\ ]+)\ [^\ ]+\ commit:\ ([0-9a-f]{7,40})\ criteria: ]] && [ "${BASH_REMATCH[1]}" = "$unit" ]; then
    sha="${BASH_REMATCH[2]}"
  fi
fi
snap=. pdopt=""
if [ -n "$pdir" ]; then snap="$(printf %q "$pdir")" pdopt=" --project-dir $snap"; fi

p=prototype/outcomeci-series-gate
echo 'next:'
[ "$have_oci" -eq 0 ] || echo '  pipx install outcomeci-cli==0.50.1'
cat <<NEXT
  export OCI_TRIAL_DIR=\$(mktemp -d) && cp -a $p/workflow/. "\$OCI_TRIAL_DIR"/
  bash $p/state-snapshot.sh $snap > "\$OCI_TRIAL_DIR/before.txt"
  bash $p/oci-series-gate.sh --unit $uid --sha $sha$pdopt -- workflow run --dir "\$OCI_TRIAL_DIR" --auto-continue 2> "\$OCI_TRIAL_DIR/gate.log"
  bash $p/state-snapshot.sh $snap > "\$OCI_TRIAL_DIR/after.txt"
  diff "\$OCI_TRIAL_DIR/before.txt" "\$OCI_TRIAL_DIR/after.txt"
  bash $p/check-journal.sh --allow-absent "\$OCI_TRIAL_DIR" <run-id>
NEXT

if [ "$first" -eq 0 ]; then echo 'preflight=ready'; else echo "preflight=blocked reason=$reason"; fi
exit "$first"
