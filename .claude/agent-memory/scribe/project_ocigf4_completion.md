---
name: ocigf-4 completion
description: PASS 2026-10-05; spec-defect FAIL-to-PASS cycle with host-dependent PATH lesson; glossary entry added; known gaps recorded
metadata:
  type: project
---

## ocigf-4 PASS closure — 2026-10-05

Unit ocigf-4 (OutcomeCI Series-Gate Trial Phase 0 — Scribe Post-Review) reached PASS on commit d2b9572. Reviewer verdict quoted verbatim: "PASS ocigf-4 at d2b9572. I re-ran AC-4.1 through AC-4.13 myself, including AC-4.3 and AC-4.9 exactly as written, and all pass."

## FAIL-to-PASS history

**FAIL 1 (initial attempt, sonnet 954b693)**: AC-4.3 host-dependent; test environment had jq at ~/.local/bin, making the tools check exit 2 (tools missing) instead of expected 3 (tools not a directory).

**Remedy**: Spec-master amended the plan (d9c1e11) and hardened acceptance criteria. Opus re-implemented with four consecutive fix commits: 9452910 (add P0, P9e fixtures, P11-P19 suite), 538bcca (guard marker read, bound docker info, validate args, pass --project-dir on), bc93dca (mutation proof M1-M5), d2b9572 (README step 0 documents --project-dir and 10 s docker timeout).

## Scribe completion

**Glossary entry added to CONTEXT.md**:
- **preflight** — a zero-API Step 4 validation tool run before OutcomeCI workflow execution. Command: `preflight.sh [--unit <id>] [--project-dir <dir>]`. Prints `check <name>=<value>` lines; exit code is first failing check (tools 2, oci 3, version 4, validate 5, docker 6, token 7; bad usage/empty/non-dir args 64). Outputs `next:` block of operator commands and final `preflight=ready|blocked reason=<check>`. Implements zero-API pattern: oci only called with --version or `validate --dir <temp copy>`, `docker info` under `timeout 10`, marker read via file-existence check. Token never printed. Defined in `prototype/outcomeci-series-gate/preflight.sh`. Test suites: `tests/preflight.test.sh` (P0-P19, 25s outer timeout), `tests/preflight-mutation.test.sh` (M1-M5 mutation proof, 5 killed 5).

**Pointer added** near existing [[prototype suite runner]] entry to cross-link the preflight tool to the run-all.sh suite runner concept.

## Convention recorded as load-bearing

**Post-FAIL spec amendment commit-range disclosure**: When a spec-master amends a plan following a FAIL verdict, the amendment document should explicitly name the commit range for each stretch of unit commits affected (e.g., "AC-4.7 (commits 9452910..d2b9572)" rather than leaving the commits implicit or summarized). This ensures future reviewers can trace the defect→amendment→fix sequence with precision.

## Known gaps (non-blocking — do not fix)

These gaps are acknowledged observations suitable for future maintenance or refinement:

- **Hex-check end not pinned** — dropping `criteria:` from a marker still parses. A fixture with `commit: abc1234$(id) criteria:` would catch truncation, but none currently exists.
- **Task-id prefix-match not pinned** — task-id extraction uses prefix match; a fixture would strengthen this, but none currently enforces exact match.
- **Mode-000 marker prints "Permission denied"** — unexpected error message in error paths (documented, not a correctness defect).
- **No timeout on `oci --version` / `oci validate`** — only `docker info` is guarded by `timeout 10`; the tools themselves run unbounded (pre-existing convention, not ocigf-4's scope).
- **Success detection via substring** — preflight detects valid JSON by checking for substring `"valid": true`. A stricter jq check (`jq -e '.valid == true'`) would be more robust (minor hardening opportunity).
- **`timeout` without `-k`** — standard timeout without `-9` kill flag; process may persist after timeout (documented risk, common pattern).
- **AC-4.7 full span includes non-unit commits** — the acceptance criterion's range spans commits outside the unit's own work (e.g., spec-amendment commits); clarify whether this is intended scope or should narrow.

## Related units and cross-references

This unit completes the preflight tool work for the OutcomeCI Design A series-gate trial (Phase 0, `prototype/outcomeci-series-gate/`). `run-all.sh` now suites=7 (was 6). Scribe glossary entry added for load-bearing [[preflight]] term flagged by reviewer as essential for operator documentation.
