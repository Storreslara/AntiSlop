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
# EMBEDDED DATA: Wave definitions (W0-W10)
# ============================================================================
# W0: unbrick CI (spec 6's P0)
# W1: spec 3's M1 + thin-shim ports (M2 tier 1)
# W2: microworlds workflow redesign (spec 4)
# W3: rerun latency + coverage (spec 2 Unit A→B, Unit E)
# W4: independent-implementation ports (spec 3 M2 tier 2)
# W5: spec 1's ported steps (Step 3→1→9) + spec 3 M3
# W6: spec 1's unported steps (Step 2,5,6,7,8)
# W7: spec 1 Step 4 (drift disarm)
# W8: spec 6 Phase 1 (CI path)
# W9: spec 6 Phase 2 (ruleset + reviewGating.mode)
# W10: unscheduled - spec 3 M4 (blocked)

# ============================================================================
# EMBEDDED DATA: Edges (E1-E11) - blocking relationships
# ============================================================================
# E1: W0 → W8, W9 (spec 6 A0: no criterion until CI green)
# E2: W1 → W2 (spec 3 M1 must precede microworlds workflow)
# E3: W1, W2 → W3 (both needed before rerun work)
# E4: W1 → W4 (thin-shim tier establishes contract for tier 2)
# E5: W3, W4 → W5 (ported steps need both tiers ready)
# E6: W5 → W6 (Step 2 uses library Step 3 ships)
# E7: W7 → W9 (escape hatch: pin baseline or land before flip)
# E8: W3 → W9 (Unit E expands protectedPaths; A22 must see it)
# E9: W6 → spec 2 Unit C (Step 5 lands first per H7)
# E10: this unit → spec 2 Unit E (validates.sh wiring)
# E11: W6 → W10 (evaluation: Step 2 may satisfy M4 precondition)

# ============================================================================
# EMBEDDED DATA: File ownership (H2)
# ============================================================================
declare -A FILE_OWNERS
FILE_OWNERS[hooks/scripts/microworld-rerun.sh]="1:W5 2:W3 3:M2 4:W2"
FILE_OWNERS[hooks/scripts/reviewed-path-gate.sh]="1:W6 2:W3 3:M4"
FILE_OWNERS[hooks/scripts/stop-gate.sh]="1:W5,W6,W7 2:W3 3:M2,M3"
FILE_OWNERS[hooks/scripts/protected-paths.sh]="1:W6 2:W3 3:M2"
FILE_OWNERS[hooks/scripts/reviewer-route-gate.sh]="1:W6 3:M2,M3"
FILE_OWNERS[hooks/scripts/human-decision-gate.sh]="1:W6 2:W3 3:M4"
FILE_OWNERS[hooks/scripts/session-start.sh]="1:W7 3:M2 4:W2"
FILE_OWNERS[.claude/persona-config.json]="1:W7 2:W3 3:A30 6:Phase2"
FILE_OWNERS[agents/reviewer.md]="1:W6 4:W2 6:Phase2"
FILE_OWNERS[agents/lead-programmer.md]="2:W3 4:W2 6:Phase2"
FILE_OWNERS[agents/orchestrator.md]="2:W3 4:W2 6:Phase2"
FILE_OWNERS[agents/task-master.md]="2:W3 4:W2 6:Phase2"
FILE_OWNERS[bin/cli.js]="3:M1,M2 4:W2"
FILE_OWNERS[adapters/*/hooks/scripts/**]="1:W5 2:W3 4:W2"
FILE_OWNERS[tests/watch-map.json]="4:W2 6:A10-A12"
FILE_OWNERS[tests/validate.sh]="1-4:various 2:A-E 6:A4,A12"
FILE_OWNERS[.github/workflows/**]="6:Phase1,Phase2"

# ============================================================================
# EMBEDDED DATA: Resource allocation (H3)
# ============================================================================
# ADRs: 0026→spec 2 Unit D, 0027→spec 6, 0028→spec 4 (conditional, no backfill)
# protectedPaths: written by spec 2 Unit E (F6)
# version stamp: per unit that edits agents/*.md or templates/*
# CHANGELOG: one entry per version bump

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

check_wave() {
  local wave="$1"

  case "$wave" in
    W0)
      # CI must be green
      local ci_status=$(gh run list --branch master --workflow validate --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown")
      if [ "$ci_status" = "success" ]; then
        echo "W0: CI is green ✓"
        return 0
      else
        echo "W0: CI conclusion is '$ci_status' (expected 'success')"
        echo "  Run: gh run list --branch master --workflow validate --limit 1"
        return 1
      fi
      ;;
    W1)
      # Depends on: nothing (parallel with W0)
      # Measures: spec 3 M1 and M2 (thin-shim tier) criteria
      echo "W1: waiting for spec 3 M1, M2 implementation"
      return 1
      ;;
    W2)
      # Depends on: W1
      # Measures: spec 4 criteria
      if [ ! -f "tests/watch-map.json" ]; then
        echo "W2: tests/watch-map.json not found (spec 4 Step 1)"
        return 1
      fi
      echo "W2: watch-map exists; waiting for spec 4 AC1-AC5"
      return 1
      ;;
    W3)
      # Depends on: W1, W2
      # Measures: spec 2 Unit A, B, E criteria
      echo "W3: waiting for spec 2 Unit A, B, E implementation"
      return 1
      ;;
    W4)
      # Depends on: W1
      # Measures: spec 3 M2 (independent-impl tier) criteria
      echo "W4: waiting for spec 3 M2 independent-implementation tier"
      return 1
      ;;
    W5)
      # Depends on: W3, W4
      # Measures: spec 1 Steps 1, 3, 9 + spec 3 M3 criteria
      echo "W5: waiting for spec 1 (Steps 1, 3, 9) and spec 3 M3"
      return 1
      ;;
    W6)
      # Depends on: W5
      # Measures: spec 1 Steps 2, 5, 6, 7, 8 criteria
      echo "W6: waiting for spec 1 (Steps 2, 5, 6, 7, 8)"
      return 1
      ;;
    W7)
      # Depends on: W6
      # Measures: spec 1 Step 4 (drift disarm) criteria
      echo "W7: E7 escape hatch: land Step 4 before Phase 2 flip, OR pin baseline to pre-flip commit and record in PASS marker"
      return 1
      ;;
    W8)
      # Depends on: W0, W2
      # Measures: spec 6 Phase 1 criteria
      echo "W8: waiting for spec 6 Phase 1"
      return 1
      ;;
    W9)
      # Depends on: W3, W7, W8 (E7, E8)
      # Measures: spec 6 Phase 2 + E7/E8 semantics
      echo "W9: unmet predecessors:"
      echo "  - W3 (spec 2 rerun coverage)"
      echo "  - W7 (spec 1 Step 4, with E7 escape hatch)"
      echo "  - W8 (spec 6 Phase 1)"
      echo "E8 semantics: protectedPaths entries must be tagged (local-only|server-mirror-eligible)"
      echo "E8 gate: only server-mirror-eligible subset mirrors to A22 file_path_restriction"
      return 1
      ;;
    W10)
      # Unscheduled - blocked by design
      echo "W10: blocked by design"
      echo "  Preconditions: spec 3's A23 and OQ2 must be answered"
      echo "  Evaluation: after W6, assess whether Step 2's Bash-half coverage satisfies M4"
      return 1
      ;;
    *)
      echo "Error: unknown wave '$wave' (expected W0-W10)"
      return 1
      ;;
  esac
}

show_owner() {
  local path="$1"

  if [ -z "$path" ]; then
    echo "Error: --owner requires a path" >&2
    return 1
  fi

  case "$path" in
    hooks/scripts/microworld-rerun.sh)
      echo "spec 1 (W5), spec 2 (W3), spec 3 (M2), spec 4 (W2)"
      ;;
    hooks/scripts/reviewed-path-gate.sh)
      echo "spec 1 (W6), spec 2 (W3), spec 3 (M4)"
      echo "Note (H7): spec 1 Step 5 and spec 2 Unit C both rewrite denial messages"
      echo "  Ruling: Step 5 lands first; Unit C is then reduced to marker-writing-helper"
      ;;
    hooks/scripts/stop-gate.sh)
      echo "spec 1 (W5, W6, W7), spec 2 (W3), spec 3 (M2, M3)"
      ;;
    .github/workflows/*)
      echo "spec 6 (Phase 1, Phase 2) - sole owner"
      ;;
    hooks/scripts/*)
      echo "Multiple specs edit hooks/scripts/"
      ;;
    agents/reviewer.md)
      echo "spec 1 (W6), spec 4 (W2), spec 6 (Phase 2)"
      ;;
    tests/validate.sh)
      echo "specs 1-4 (various), spec 2 (Units A-E), spec 6 (A4, A12)"
      ;;
    *)
      echo "Path not in rollout map or not yet owned: $path"
      return 1
      ;;
  esac
}

show_resource() {
  local resource="$1"

  if [ -z "$resource" ]; then
    echo "Error: --resource requires a name" >&2
    return 1
  fi

  case "$resource" in
    adr)
      cat <<'EOF'
ADR allocation (next free: 0026):

0026 → spec 2, Unit D (amending ADR-0010)
  Unconditional; Unit D is a float with no predecessors

0027 → spec 6, CI-shaped architecture (with D0 scope split as a section)
  Unconditional; cited by A25b and A27

0028 → spec 4, conditional D9/D11 ADR
  Conditional ("consider"). If declined, stays unused.
  Do not backfill it — increment-never-backfill convention.

0029+ → unallocated
  Specs 1 and 3 owe none today.
EOF
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

reverify_spec() {
  local spec="$1"
  local checked=0 skipped=0 failed=0

  if [ -z "$spec" ]; then
    echo "Error: --reverify requires a spec number" >&2
    return 1
  fi

  case "$spec" in
    6)
      echo "spec 6 end-state-sensitive criteria re-verification:"
      echo ""

      # A24: hook script count must be 14
      local hook_count=$(find hooks/scripts -maxdepth 1 -name '*.sh' -type f | wc -l)
      echo "checked: A24 — hook script count"
      echo "  Expected: 14, Actual: $hook_count"
      if [ "$hook_count" -eq 14 ]; then
        echo "  ✓ passing"
      else
        echo "  ✗ FAILING"
        failed=1
      fi
      checked=$((checked + 1))
      echo ""

      # A13: reporter scripts diff empty (cannot fully verify without phase-1-base)
      echo "skipped: A13 — reporter scripts diff (requires phase-1-base commit)"
      echo "  Reason: git-diff-range criterion; phase-1-base not yet defined"
      skipped=$((skipped + 1))
      echo ""

      # A25b second half: reviewer-judgement
      echo "skipped: A25b (second half) — reviewer-judgement"
      echo "  Reason: reviewer-judgement criteria cannot be re-measured mechanically"
      skipped=$((skipped + 1))
      echo ""

      # Network/CI state criteria
      echo "skipped: A1-A16 (Phase 1) — live CI state dependencies"
      echo "  Reason: CI/network state dependencies; re-verify after Phase 1 lands"
      skipped=$((skipped + 1))
      echo ""

      # A17-A28 (Phase 2) prerequisites
      echo "skipped: A17-A28 (Phase 2) — Phase 1 not yet in tree"
      echo "  Reason: Phase 2 criteria depend on Phase 1 implementation"
      skipped=$((skipped + 1))
      echo ""

      echo "Summary: checked=$checked, skipped=$skipped, failed=$failed"

      if [ "$failed" -gt 0 ]; then
        return 1
      fi
      return 0
      ;;
    *)
      echo "reverify: spec $spec not yet implemented or not supported"
      return 1
      ;;
  esac
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
