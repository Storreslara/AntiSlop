#!/bin/bash
# Rollout preflight checker: wave graph, edges, file ownership, resource allocation.
# Delete this file, its test, and its `tests/validate.sh` block once W9 is green and
# W10 is adjudicated; it is rollout scaffolding, not a harness feature.
#
# Usage:
#   rollout-preflight.sh <wave>           - check if wave can be dispatched
#   rollout-preflight.sh --owner <path>   - list specs that edit this file
#   rollout-preflight.sh --resource <name> - show resource allocation
#   rollout-preflight.sh --reverify <spec> - re-run spec's end-state-sensitive criteria
#
# Delete this file, its test, and its `tests/validate.sh` block once W9 is green and
# W10 is adjudicated; it is rollout scaffolding, not a harness feature.
set -euo pipefail

# ============================================================================
# EMBEDDED DATA: which spec(s) own each wave (numbers, per the Wave graph table)
# ============================================================================
declare -A WAVE_OWNER_SPECS
WAVE_OWNER_SPECS[W0]="6"
WAVE_OWNER_SPECS[W1]="3"
WAVE_OWNER_SPECS[W2]="4"
WAVE_OWNER_SPECS[W3]="2"
WAVE_OWNER_SPECS[W4]="3"
WAVE_OWNER_SPECS[W5]="1 3"
WAVE_OWNER_SPECS[W6]="1"
WAVE_OWNER_SPECS[W7]="1"
WAVE_OWNER_SPECS[W8]="6"
WAVE_OWNER_SPECS[W9]="6"
WAVE_OWNER_SPECS[W10]="3"

# ============================================================================
# EMBEDDED DATA: which plan document is each spec (for the staleness gate, AC14)
# ============================================================================
declare -A SPEC_FILE
SPEC_FILE[1]="docs/plans/2026-08-25-harness-trust-gaps.md"
SPEC_FILE[2]="docs/plans/2026-08-25-agent-throughput-performance-dampeners.md"
SPEC_FILE[3]="docs/plans/2026-08-25-harness-ceremony-consolidation.md"
SPEC_FILE[4]="docs/plans/2026-08-25-microworlds-workflow-redesign.md"
SPEC_FILE[6]="docs/plans/2026-08-25-ci-shaped-review-architecture-d.md"

# ============================================================================
# EMBEDDED DATA: edges (E1-E11 plus unnumbered same-spec sequencing, S1-S3)
# format: EDGES[id]="source wave(s)|target wave or unit|sibling sentence"
# ============================================================================
declare -A EDGES
EDGES[E1]="W0|W8|spec 6 A0: no other criterion may be evaluated until A0 holds (chains to W9 via S3)"
EDGES[E2]="W1|W2|spec 3 M1 and M2 tier 1 must precede spec 4 Step 1's edit to microworld-rerun.sh"
EDGES[E3]="W1 W2|W3|Unit A must be written against the post-spec-4 hook; Unit A precedes Unit B"
EDGES[E4]="W1|W4|M2 tier 1 establishes the core+shim contract tier 2 reuses"
EDGES[E5]="W3 W4|W5|Steps 1 and 3 need both ported tiers ready"
EDGES[E6]="W5|W6|Step 2 consumes audit_append, which Step 3 ships"
EDGES[E7]="W7|W9|escape hatch: land Step 4 before the flip, or pin the baseline to a pre-flip commit and record it in the PASS marker"
EDGES[E8]="W3|W9|only the server-mirror-eligible subset of protectedPaths may feed spec 6's A22 file_path_restriction"
EDGES[E9]="W6|UnitC|spec 1 Step 5 lands first; spec 2 Unit C is reduced to its marker-writing-helper deliverable"
EDGES[E10]="THISUNIT|UnitE|this unit lands before spec 2's Unit E (tests/validate.sh wiring)"
EDGES[E11]="W6|W10|evaluation only, not a blocker: Step 2's Bash-half coverage may satisfy spec 3's M4 precondition"
EDGES[S1]="W6|W7|spec 1's own step ordering: unported steps precede Step 4"
EDGES[S2]="W2|W8|spec 6 Phase 1 needs spec 4's microworlds workflow landed"
EDGES[S3]="W8|W9|spec 6's own phase ordering: P0 -> Phase 1 -> Phase 2"

# ============================================================================
# EMBEDDED DATA: file ownership (H2), one entry per row (17, matching the plan)
# format: FILE_OWNERS[path]="specN:claim (wave)|specM:claim (wave)|..."
# ============================================================================
declare -A FILE_OWNERS
FILE_OWNERS[hooks/scripts/stop-gate.sh]="1:Steps 1, 3, 4 (W5, W7)|2:Unit B (W3)|3:M2, M3 (W4, W5)"
FILE_OWNERS[hooks/scripts/microworld-rerun.sh]="1:Step 9 (W5)|2:Unit A (W3)|3:M2 (W1)|4:Step 1 (W2)"
FILE_OWNERS[hooks/scripts/reviewer-route-gate.sh]="1:Steps 1, 3 (W5)|3:M2, M3 (W4, W5)"
FILE_OWNERS[hooks/scripts/protected-paths.sh]="1:Step 1 (W5)|2:Unit E (W3)|3:M2 (W1)"
FILE_OWNERS[hooks/scripts/reviewed-path-gate.sh]="1:Steps 1, 5 (W5, W6)|2:Unit C (float, after W6)|3:M4 (blocked, W10)"
FILE_OWNERS[hooks/scripts/human-decision-gate.sh]="1:Step 5 (W6)|2:Unit C (float, after W6)|3:M4 (blocked, W10)"
FILE_OWNERS[hooks/scripts/session-start.sh]="1:Steps 4, 7 (W6, W7)|3:M2|4:Step 2 (W2)"
FILE_OWNERS[.claude/persona-config.json]="1:Step 4, reads (W7)|2:Unit E, protectedPaths (W3)|3:A30, constrains|6:Phase 2, reviewGating.mode (W9)"
FILE_OWNERS[agents/reviewer.md]="1:Step 9 (W5)|2:out of scope, AC-B4|4:Step 3 (W2)|6:Phase 2, D3 shim (W9)"
FILE_OWNERS[agents/lead-programmer.md]="2:Unit D|4:Step 3, D7 (W2)|6:Phase 2 (W9)"
FILE_OWNERS[agents/orchestrator.md]="2:Unit D|4:Step 3, D7 (W2)|6:Phase 2 (W9)"
FILE_OWNERS[agents/task-master.md]="2:Unit D|4:Step 3, D7 (W2)|6:Phase 2 (W9)"
FILE_OWNERS[bin/cli.js]="3:M1.2, M2.2 (W1)"
FILE_OWNERS[adapters/*/hooks/scripts/**]="1:Steps 1, 3, 9 (W5)|2:Unit A (W3)|3:M2 (W1)"
FILE_OWNERS[tests/watch-map.json]="4:Step 1, author (W2)|6:A10-A12, consumer (W8)"
FILE_OWNERS[tests/validate.sh]="1:several (various waves)|2:Units A-E (W3; Units C, D are floats)|3:M1-M3 (W1, W4, W5)|4:AC1.6 (W2)|6:A4, A12 (W8)"
FILE_OWNERS[.github/workflows/**]="6:P0, Phase 1 (W0, W8)"

declare -A FILE_NOTES
FILE_NOTES[hooks/scripts/stop-gate.sh]="three-way; M2 restructures it into a core + shims. Step 4 wires drift-blocking into it."
FILE_NOTES[hooks/scripts/microworld-rerun.sh]="four-way -- the most contended file in the rollout."
FILE_NOTES[hooks/scripts/reviewed-path-gate.sh]="H7: spec 1 Step 5 and spec 2 Unit C both rewrite denial messages (E9: Step 5 lands first)."
FILE_NOTES[hooks/scripts/human-decision-gate.sh]="H7: see hooks/scripts/reviewed-path-gate.sh."
FILE_NOTES[hooks/scripts/session-start.sh]="corrected in revision 3: Step 1 is not a claimant (session-start.sh is a non-adopter)."
FILE_NOTES[.claude/persona-config.json]="three writers, three different keys."
FILE_NOTES[tests/watch-map.json]="one file, multiple consumers after spec 4 lands."
FILE_NOTES[tests/validate.sh]="everyone registers suites here."
FILE_NOTES[.github/workflows/**]="sole owner."

# ============================================================================
# EMBEDDED DATA: ADR allocation (H3)
# format: ADR_ALLOC[number]="allocated to|basis"
# ============================================================================
declare -A ADR_ALLOC
ADR_ALLOC[0026]="spec 2, Unit D (amending ADR-0010)|unconditional; Unit D is a float with no predecessors, so it may write first"
ADR_ALLOC[0027]="spec 6 -- exactly one ADR, covering both the CI-shaped architecture and the D0 scope split as a section of it|unconditional; cited by its own A25b and A27. Ruling: one ADR, 0027, D0 as a section"
ADR_ALLOC[0028]="spec 4, the conditional D9/D11 ADR|conditional (\"consider\"). If declined, 0028 stays unused. Do not backfill it, per this project's increment-never-backfill convention"

# ============================================================================
# EMBEDDED DATA: which specs have a real --reverify implementation. Single
# source of truth for both reverify_spec()'s dispatch and
# wave_staleness_check()'s "stale" vs "no support" distinction.
# ============================================================================
declare -A REVERIFY_IMPLEMENTED
REVERIFY_IMPLEMENTED[6]="reverify_spec6"

REVERIFY_STATE_DIR="${ROLLOUT_PREFLIGHT_STATE_DIR:-${TMPDIR:-/tmp}/rollout-preflight-reverify-state}"

# ============================================================================
# Helper functions
# ============================================================================

print_help() {
  cat >&2 <<'EOF'
Usage: scripts/rollout-preflight.sh <wave>
       scripts/rollout-preflight.sh --owner <path>
       scripts/rollout-preflight.sh --resource <name>
       scripts/rollout-preflight.sh --reverify <spec>

Rollout preflight checker for specs 1-6 sequencing.
Delete this file, its test, and its `tests/validate.sh` block once W9 is green and
W10 is adjudicated; it is rollout scaffolding, not a harness feature.

Subcommands:
  <wave>              Check if wave can be dispatched (W0-W10)
  --owner <path>      List specs editing this file
  --resource <name>   Show allocation (adr, version, changelog, protected-paths)
  --reverify <spec>   Re-run spec's end-state-sensitive criteria
EOF
}

p_live_status() {
  # Report plugin snapshot status (never a gate)
  local plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
  if [ -z "$plugin_root" ]; then
    # Try to find plugin root
    plugin_root="$(cd "$(dirname "$0")/.." && npm root -g 2>/dev/null)/../@anthropic-ai/antislop" || true
  fi

  if [ -d "$plugin_root" ]; then
    local plugin_version=$(grep -oP '"version":\s*"\K[^"]+' "$plugin_root/package.json" 2>/dev/null || echo "unknown")
    echo "P-live: plugin at v$plugin_version (session snapshot may differ if started before 2026-08-25T15:09:01Z)"
  else
    echo "P-live: plugin root not found (pre-started session may execute older snapshot)"
  fi
}

# Union of edge sources whose target list contains $1, derived from EDGES (not
# hardcoded) so deleting a single EDGES[...] line removes exactly its wave(s).
wave_predecessors() {
  local wave="$1" eid data src dst note d s preds=""
  for eid in "${!EDGES[@]}"; do
    data="${EDGES[$eid]}"
    IFS='|' read -r src dst note <<< "$data"
    for d in $dst; do
      if [ "$d" = "$wave" ]; then
        for s in $src; do
          preds="$preds $s"
        done
      fi
    done
  done
  echo "$preds" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' || true
}

# True if $1 has a real --reverify implementation (see REVERIFY_IMPLEMENTED).
reverify_supported() {
  [ -n "${REVERIFY_IMPLEMENTED[$1]:-}" ]
}

# AC14: reports unmet-on-staleness if the wave's owning spec's plan doc was
# amended more recently than the last recorded --reverify run for that spec.
# A spec with no --reverify implementation can't have its staleness measured
# at all, so it gets a distinct no-reverify-support line instead and never
# counts toward the stale=1 return.
# Returns 0 (fresh) or 1 (stale, with a printed line naming the spec and time).
wave_staleness_check() {
  local wave="$1" specs="${WAVE_OWNER_SPECS[$1]:-}"
  local spec_num spec_file mtime mtime_iso last_run stale=0
  for spec_num in $specs; do
    spec_file="${SPEC_FILE[$spec_num]:-}"
    [ -z "$spec_file" ] && continue
    [ -f "$spec_file" ] || continue
    if ! reverify_supported "$spec_num"; then
      echo "$wave: no-reverify-support -- spec $spec_num has no --reverify implementation; staleness cannot be measured"
      continue
    fi
    mtime=$(stat -c %Y "$spec_file" 2>/dev/null || echo 0)
    last_run=0
    if [ -f "$REVERIFY_STATE_DIR/spec-$spec_num.stamp" ]; then
      last_run=$(cat "$REVERIFY_STATE_DIR/spec-$spec_num.stamp" 2>/dev/null || echo 0)
    fi
    if [ "$mtime" -gt "$last_run" ]; then
      mtime_iso=$(date -u -d "@$mtime" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
      echo "$wave: unmet-on-staleness -- spec $spec_num ($spec_file) amended $mtime_iso; no --reverify since"
      stale=1
    fi
  done
  [ "$stale" -eq 0 ]
}

owner_text_for() {
  local wave="$1" spec_num text=""
  for spec_num in ${WAVE_OWNER_SPECS[$wave]:-}; do
    text="$text spec $spec_num,"
  done
  echo "${text%,}" | sed 's/^ *//'
}

check_wave0() {
  local ci_status ok=0
  ci_status=$(gh run list --branch master --workflow validate --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown")
  if [ "$ci_status" = "success" ]; then
    echo "W0: CI is green (validate workflow conclusion: success)"
    ok=1
  else
    echo "W0: CI conclusion is '$ci_status' (expected 'success')"
    echo "  Run: gh run list --branch master --workflow validate --limit 1"
  fi
  local stale=0
  wave_staleness_check "W0" || stale=1
  if [ "$ok" -eq 1 ] && [ "$stale" -eq 0 ]; then
    return 0
  fi
  return 1
}

check_wave10() {
  echo "W10: blocked by design"
  echo "  Preconditions: spec 3's A23 and OQ2 must be answered"
  local e11note
  IFS='|' read -r _ _ e11note <<< "${EDGES[E11]}"
  echo "  Evaluation: $e11note"
  wave_staleness_check "W10" || true
  return 1
}

# W1-W9: prints unmet predecessors from wave_predecessors(), plus any
# wave-specific measurement (W2's watch-map check, W7's escape hatch, W9's E8
# semantics), plus the staleness gate. Always unmet today (see AC2/AC3/AC5).
check_wave_generic() {
  local wave="$1" preds owner note
  preds=$(wave_predecessors "$wave")
  owner=$(owner_text_for "$wave")
  if [ -z "$preds" ]; then
    echo "$wave: no blocking predecessors; waiting for $owner implementation"
  else
    echo "$wave: unmet predecessors:"
    local p
    for p in $preds; do
      echo "  - $p"
    done
  fi
  case "$wave" in
    W2)
      if [ ! -f "tests/watch-map.json" ]; then
        echo "$wave: tests/watch-map.json not found (spec 4 Step 1)"
      fi
      ;;
    W7)
      IFS='|' read -r _ _ note <<< "${EDGES[E7]}"
      echo "$wave: $note"
      ;;
    W9)
      echo "E8 semantics: protectedPaths entries must be tagged (local-only|server-mirror-eligible)"
      echo "E8 gate: only server-mirror-eligible subset mirrors to A22 file_path_restriction"
      ;;
  esac
  wave_staleness_check "$wave" || true
  return 1
}

check_wave() {
  local wave="$1"
  case "$wave" in
    W0) check_wave0 ;;
    W10) check_wave10 ;;
    W1|W2|W3|W4|W5|W6|W7|W8|W9) check_wave_generic "$wave" ;;
    *)
      echo "Error: unknown wave '$wave' (expected W0-W10)"
      return 1
      ;;
  esac
}

print_file_owners() {
  local key="$1" data="${FILE_OWNERS[$1]}" tok specnum label
  IFS='|' read -ra toks <<< "$data"
  for tok in "${toks[@]}"; do
    specnum="${tok%%:*}"
    label="${tok#*:}"
    echo "spec $specnum ($label)"
  done
  local note="${FILE_NOTES[$key]:-}"
  if [ -n "$note" ]; then
    echo "Note: $note"
  fi
  return 0
}

show_owner() {
  local path="$1"

  if [ -z "$path" ]; then
    echo "Error: --owner requires a path" >&2
    return 1
  fi

  if [ -n "${FILE_OWNERS[$path]:-}" ]; then
    print_file_owners "$path"
    return 0
  fi

  case "$path" in
    adapters/*/hooks/scripts/*)
      print_file_owners 'adapters/*/hooks/scripts/**'
      ;;
    .github/workflows/*)
      print_file_owners '.github/workflows/**'
      ;;
    hooks/scripts/*)
      echo "$path is not individually listed in H2 (multiple specs edit files under hooks/scripts/ generally)"
      ;;
    *)
      echo "Path not in rollout map or not yet owned: $path (informational; H2 does not list it)"
      ;;
  esac
  return 0
}

show_resource_adr() {
  echo "ADR allocation (next free: 0026):"
  echo ""
  local num alloc basis
  for num in $(printf '%s\n' "${!ADR_ALLOC[@]}" | sort); do
    IFS='|' read -r alloc basis <<< "${ADR_ALLOC[$num]}"
    echo "$num -> $alloc"
    echo "  $basis"
    echo ""
  done
  echo "0029+ -> unallocated"
  echo "  Specs 1 and 3 owe none today; if spec 3's M4 ever unblocks it takes the lowest free number then."
}

show_resource() {
  local resource="$1"

  if [ -z "$resource" ]; then
    echo "Error: --resource requires a name" >&2
    return 1
  fi

  case "$resource" in
    adr)
      show_resource_adr
      ;;
    version)
      echo "One bump per unit that edits agents/*.md or templates/*."
      echo "This unit takes no version number (no stamped files edited)."
      ;;
    changelog)
      echo "One CHANGELOG entry per version bump."
      echo "This unit adds no entry (no version bump)."
      ;;
    protected-paths)
      cat <<'EOF'
Written by: spec 2, Unit E (F6 corrected revision 2 allocation)
Not written by: spec 1 Step 2 (configless by design)

E8 semantics contract (Unit E must tag each entry):
  - local-only: changes frequently; freezing server-side impedes scheduled work
  - server-mirror-eligible: changes rarely; safe to mirror
  - hooks/scripts/** entries are local-only by default

E8 gate: only server-mirror-eligible subset mirrors to spec 6's A22
  (hooks/scripts/** entries default to local-only; promote only with stated reason)
EOF
      ;;
    *)
      echo "Error: unknown resource '$resource' (try: adr, version, changelog, protected-paths)" >&2
      return 1
      ;;
  esac
}

reverify_spec6() {
  local checked=0 skipped=0 failed=0
  mkdir -p "$REVERIFY_STATE_DIR"
  date +%s > "$REVERIFY_STATE_DIR/spec-6.stamp"

  echo "spec 6 end-state-sensitive criteria re-verification:"
  echo ""

  # Baseline bumped 14 -> 15 (2026-08-26) once spec 1's Step 2 (gh418) landed
  # hooks/scripts/harness-integrity-gate.sh, then 15 -> 16 (2026-08-26) once
  # spec 1's Step 6 (gh420) landed hooks/scripts/marker-verify.sh, then
  # 16 -> 17 (2026-08-27) once spec2-unitC landed hooks/scripts/marker-write.sh,
  # then 17 -> 18 (2026-09-23) once version-stamp-guard-1 landed
  # hooks/scripts/version-stamp-check.sh -- exactly the staleness the
  # rollout-sequencing doc's own A24 discussion predicted ("the literal 14
  # is stale even though nothing in spec 6 is wrong"). This snapshot must
  # move again if a later unit adds or removes a top-level
  # hooks/scripts/*.sh file; re-derive by counting rather than trusting this
  # comment.
  local hook_count=$(find hooks/scripts -maxdepth 1 -name '*.sh' -type f | wc -l)
  echo "checked: A24 — hook script count"
  echo "  Expected: 18, Actual: $hook_count"
  if [ "$hook_count" -eq 18 ]; then
    echo "  ✓ passing"
  else
    echo "  ✗ FAILING"
    failed=1
  fi
  checked=$((checked + 1))
  echo ""

  echo "skipped: A13 — reporter scripts diff (requires phase-1-base commit)"
  echo "  Reason: git-diff-range criterion; phase-1-base not yet defined"
  skipped=$((skipped + 1))
  echo ""

  echo "skipped: A25b (second half) — reviewer-judgement"
  echo "  Reason: reviewer-judgement criteria cannot be re-measured mechanically"
  skipped=$((skipped + 1))
  echo ""

  echo "skipped: A1-A16 (Phase 1) — live CI state dependencies"
  echo "  Reason: CI/network state dependencies; re-verify after Phase 1 lands"
  skipped=$((skipped + 1))
  echo ""

  echo "skipped: A17-A28 (Phase 2) — Phase 1 not yet in tree"
  echo "  Reason: Phase 2 criteria depend on Phase 1 implementation"
  skipped=$((skipped + 1))
  echo ""

  echo "Summary: checked=$checked, skipped=$skipped, failed=$failed"

  [ "$failed" -eq 0 ]
}

reverify_spec() {
  local spec="$1" fn

  if [ -z "$spec" ]; then
    echo "Error: --reverify requires a spec number" >&2
    return 1
  fi

  if ! reverify_supported "$spec"; then
    echo "reverify: spec $spec not yet implemented or not supported"
    return 1
  fi

  fn="${REVERIFY_IMPLEMENTED[$spec]}"
  "$fn"
}

# ============================================================================
# Main entry point
# ============================================================================

if [ $# -eq 0 ]; then
  print_help
  exit 1
fi

# Always report P-live status
p_live_status
echo ""

case "$1" in
  W[0-9]|W10)
    check_wave "$1"
    ;;
  W*)
    # Looks like a wave but not valid
    echo "Error: unknown wave '$1' (expected W0-W10)" >&2
    exit 1
    ;;
  --owner)
    if [ $# -lt 2 ]; then
      echo "Error: --owner requires a path" >&2
      exit 1
    fi
    show_owner "$2"
    ;;
  --resource)
    if [ $# -lt 2 ]; then
      echo "Error: --resource requires a resource name" >&2
      exit 1
    fi
    show_resource "$2"
    ;;
  --reverify)
    if [ $# -lt 2 ]; then
      echo "Error: --reverify requires a spec number" >&2
      exit 1
    fi
    reverify_spec "$2"
    ;;
  -h|--help)
    print_help
    exit 0
    ;;
  *)
    echo "Error: unknown argument '$1'" >&2
    print_help
    exit 1
    ;;
esac
