#!/usr/bin/env bash
# Diffs the vendored mattpocock/skills content in skills/ against the
# upstream SHA pinned in skills/THIRD-PARTY-NOTICES.md.
# See docs/maintenance/resync-vendored-skills.md for the full runbook.
#
# Usage:
#   scripts/resync-vendored-skills.sh          # print a per-skill drift report
#   scripts/resync-vendored-skills.sh --check  # same report; exit 1 if any of
#                                               # the 9 verbatim skills (Step
#                                               # A.2) has genuine content
#                                               # drift (all fetches ok); exit
#                                               # 2 if any upstream fetch
#                                               # errored (drift status
#                                               # unknown) or on any other
#                                               # script error, incl. an
#                                               # unrecognized argument
set -uo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  "") CHECK=0 ;;
  --check) CHECK=1 ;;
  *)
    echo "ERROR: unrecognized argument '$1' (expected no argument, or --check)" >&2
    exit 2
    ;;
esac

NOTICES="skills/THIRD-PARTY-NOTICES.md"
SHA="$(grep -oE '`[0-9a-f]{40}`' "$NOTICES" | head -1 | tr -d '\`')"
if [ -z "$SHA" ]; then
  echo "ERROR: could not find pinned SHA in $NOTICES" >&2
  exit 2
fi
RAW_BASE="https://raw.githubusercontent.com/mattpocock/skills/$SHA"

# skill:type:local_path:upstream_path
# type: fm  = SKILL.md (frontmatter; header inserted right after closing ---)
#       doc = markdown companion, no frontmatter (header + blank at line 1-2)
#       raw = no header at all (e.g. the .sh companion); compare whole file
FILES="
grill-me:fm:skills/grill-me/SKILL.md:skills/productivity/grill-me/SKILL.md
grilling:fm:skills/grilling/SKILL.md:skills/productivity/grilling/SKILL.md
handoff:fm:skills/handoff/SKILL.md:skills/productivity/handoff/SKILL.md
tdd:fm:skills/tdd/SKILL.md:skills/engineering/tdd/SKILL.md
tdd:doc:skills/tdd/tests.md:skills/engineering/tdd/tests.md
tdd:doc:skills/tdd/mocking.md:skills/engineering/tdd/mocking.md
diagnosing-bugs:fm:skills/diagnosing-bugs/SKILL.md:skills/engineering/diagnosing-bugs/SKILL.md
diagnosing-bugs:raw:skills/diagnosing-bugs/scripts/hitl-loop.template.sh:skills/engineering/diagnosing-bugs/scripts/hitl-loop.template.sh
improve-codebase-architecture:fm:skills/improve-codebase-architecture/SKILL.md:skills/engineering/improve-codebase-architecture/SKILL.md
improve-codebase-architecture:doc:skills/improve-codebase-architecture/HTML-REPORT.md:skills/engineering/improve-codebase-architecture/HTML-REPORT.md
codebase-design:fm:skills/codebase-design/SKILL.md:skills/engineering/codebase-design/SKILL.md
codebase-design:doc:skills/codebase-design/DEEPENING.md:skills/engineering/codebase-design/DEEPENING.md
codebase-design:doc:skills/codebase-design/DESIGN-IT-TWICE.md:skills/engineering/codebase-design/DESIGN-IT-TWICE.md
domain-modeling:fm:skills/domain-modeling/SKILL.md:skills/engineering/domain-modeling/SKILL.md
domain-modeling:doc:skills/domain-modeling/ADR-FORMAT.md:skills/engineering/domain-modeling/ADR-FORMAT.md
domain-modeling:doc:skills/domain-modeling/CONTEXT-FORMAT.md:skills/engineering/domain-modeling/CONTEXT-FORMAT.md
implement:fm:skills/implement/SKILL.md:skills/engineering/implement/SKILL.md
"
SKILL_ORDER="grill-me grilling handoff tdd diagnosing-bugs improve-codebase-architecture codebase-design domain-modeling implement"

# to-spec/to-tickets/code-review are the 3 repoint skills Step A.3 lands.
# Report-only: not gated by --check since they don't exist until A.3 lands.
REPOINT_SKILLS="to-spec to-tickets code-review"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Builds, in $TMPDIR/expected, "what the local file should contain" by
# inserting the provenance header into a fresh copy of the upstream file,
# then diffs it against the actual local file.
check_one_file() {
  local type="$1" local_path="$2" upstream_path="$3" upstream_file="$4"
  local header="<!-- Vendored verbatim from mattpocock/skills $upstream_path @ $SHA. MIT © 2026 Matt Pocock — see skills/THIRD-PARTY-NOTICES.md. -->"
  local expected="$TMPDIR/expected"

  case "$type" in
    fm)
      # insert header immediately after the closing frontmatter '---' line,
      # leaving the blank line + body that already follow it untouched.
      awk -v header="$header" '
        NR==1 { print; next }
        !closed && $0=="---" { print; print header; closed=1; next }
        { print }
      ' "$upstream_file" >"$expected"
      ;;
    doc)
      { printf '%s\n\n' "$header"; cat "$upstream_file"; } >"$expected"
      ;;
    raw)
      cp "$upstream_file" "$expected"
      ;;
  esac
  diff -q "$expected" "$local_path" >/dev/null 2>&1
}

declare -A skill_status
declare -A skill_detail
fetch_error=0

echo "Pinned upstream SHA: $SHA"
echo

while IFS=: read -r skill type local_path upstream_path; do
  [ -z "$skill" ] && continue
  upstream_file="$TMPDIR/up_$(echo "$upstream_path" | tr '/' '_')"
  if ! curl -sS -f -m 20 "$RAW_BASE/$upstream_path" -o "$upstream_file" 2>"$TMPDIR/curl.err"; then
    skill_status[$skill]="ERROR"
    skill_detail[$skill]="${skill_detail[$skill]:-}  fetch failed: $upstream_path ($(cat "$TMPDIR/curl.err"))\n"
    fetch_error=1
    continue
  fi
  if [ ! -f "$local_path" ]; then
    [ "${skill_status[$skill]:-}" = "ERROR" ] || skill_status[$skill]="MISSING"
    skill_detail[$skill]="${skill_detail[$skill]:-}  missing: $local_path\n"
  elif ! check_one_file "$type" "$local_path" "$upstream_path" "$upstream_file"; then
    [ "${skill_status[$skill]:-}" = "ERROR" ] || skill_status[$skill]="DRIFTED"
    skill_detail[$skill]="${skill_detail[$skill]:-}  drift: $local_path\n"
  fi
  : "${skill_status[$skill]:=OK}"
done <<EOF
$FILES
EOF

# Safety net for the FILES/SKILL_ORDER parallel-list desync risk: a skill
# added to FILES but not SKILL_ORDER would otherwise have its drift computed
# above but never reported or gated below.
for skill in "${!skill_status[@]}"; do
  case " $SKILL_ORDER " in
    *" $skill "*) ;;
    *)
      echo "ERROR: skill '$skill' appears in FILES but not in SKILL_ORDER" >&2
      exit 2
      ;;
  esac
done

drifted=0
for skill in $SKILL_ORDER; do
  status="${skill_status[$skill]:-OK}"
  echo "[$status] $skill"
  if [ "$status" != "OK" ]; then
    printf '%b' "${skill_detail[$skill]:-}"
    [ "$status" = "ERROR" ] || drifted=1
  fi
done

echo
echo "-- 3 repoint skills (Step A.3, may not be vendored yet) --"
for skill in $REPOINT_SKILLS; do
  if [ -f "skills/$skill/SKILL.md" ]; then
    echo "[VENDORED] $skill (not diffed by this script; repointed content, see docs/maintenance/resync-vendored-skills.md)"
  else
    echo "[PENDING] $skill (Step A.3 not landed yet)"
  fi
done

if [ "$CHECK" -eq 1 ]; then
  if [ "$fetch_error" -eq 1 ]; then
    echo
    echo "FETCH ERRORS — drift status unknown." >&2
    exit 2
  fi
  if [ "$drifted" -eq 1 ]; then
    echo
    echo "DRIFT DETECTED among the 9 verbatim vendored skills." >&2
    exit 1
  fi
fi
exit 0
