#!/usr/bin/env bash
# Externalization precondition wrapper: execs oci only after the unit's PASS marker verifies.
# Usage: oci-series-gate.sh --unit <task-id> [--project-dir <dir>] [--sha <rev>] -- <args for oci>
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hooks="$here/../../hooks/scripts"

unit="" proj="$here/../.." sha=HEAD sep=0
refuse() { # <exit code> <reason>
  printf 'series-gate=refuse unit=%s reason=%s\n' "$unit" "$2" >&2
  exit "$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --unit) unit="${2:-}"; shift 2 || refuse 64 usage ;;
    --project-dir) proj="${2:-}"; shift 2 || refuse 64 usage ;;
    --sha) sha="${2:-}"; shift 2 || refuse 64 usage ;;
    --) shift; sep=1; break ;;
    *) refuse 64 usage ;;
  esac
done

dot="$proj/.claude"
. "$hooks/lib/state-access.sh"
set +e
[ -n "$unit" ] && [ "$sep" -eq 1 ] && unit_id_valid "$unit" || refuse 64 usage  # CHECK:R1

marker="$(unit_id_marker_path "$unit" pass)"
[ -s "$marker" ] || refuse 65 marker-missing  # CHECK:R2

line="$(head -n 1 "$marker" 2>/dev/null)"
rest="${line#"PASS $unit "}"
[ "$rest" != "$line" ] && [[ $rest =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\ commit:\ [0-9a-f]{7,40}\ criteria:\ .+$ ]] || refuse 66 marker-invalid  # CHECK:R3

attribution="$(bash "$hooks/marker-commit-check.sh" "$unit" "$proj" 2>/dev/null)"
[[ $attribution == "marker-commit-check=ok "* ]] || refuse 67 commit-attribution  # CHECK:R4

cited="${line#* commit: }"
cited="${cited%% *}"
full_cited="$(git -C "$proj" rev-parse -q --verify "${cited}^{commit}")"
full_sha="$(git -C "$proj" rev-parse -q --verify "${sha}^{commit}")"
[ -n "$full_cited" ] && [ "$full_cited" = "$full_sha" ] || refuse 68 sha-mismatch  # CHECK:R5

verify="$(bash "$hooks/marker-verify.sh" "$unit" "$proj" --execute 2>/dev/null)"
case "$verify" in "marker-verify=ok "*) ;; "marker-verify=mismatch "*) refuse 69 criteria-mismatch ;; *) refuse 69 criteria-unverifiable ;; esac  # CHECK:R6

printf 'series-gate=allow unit=%s commit=%s\n' "$unit" "$full_cited" >&2
exec oci "$@"
