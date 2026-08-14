## [0.31.33] - 2026-08-14

**Widen marker-filename charclass to match dispatch grammar (gh360, Step 7 of #348 spec).** The `is_sanctioned_marker_write()` function in human-decision-gate.sh now accepts dots and hashes in marker-file ids (e.g., `gh345.1.pass`, `gh#348.pass`), matching the id grammar used by other dispatch gates. Leading-dot and traversal rejection unchanged.

### Changed
- **`hooks/scripts/human-decision-gate.sh`:** Widened id charclass from `[A-Za-z0-9_-]+` to `[A-Za-z0-9_][A-Za-z0-9_#.-]*` (line 58). Updated header comment (lines 19-23) to document the widened charclass and traversal-prevention mechanism.
- **`.claude/hooks/scripts/human-decision-gate.sh`:** Mirror regenerated to match source byte-for-byte.
- **`tests/human-decision-gate.test.sh`:** Added four new test cases (N24-N27) covering dot-containing ids, hash-containing ids, leading-dot rejection, and traversal prevention. Mutation-proof verified.

### Notes
- All 22 existing attack-case tests pass unchanged (C7.2 verified).
- BASH_REMATCH indices remain stable (no new capture group added; id charclass widened in-place).
- Byte-identical sync of source and mirror confirmed (C7.5).
- Validation passes (C7.6 verified).

# Changelog

## [0.31.32] - 2026-08-14

**Remove `antislop:coding-discipline` skill from reviewer persona (gh359, Step 6 of #348).** The reviewer persona never writes code, so the coding-discipline skill was dead weight. This change removes it from the reviewer's `skills:` frontmatter line, leaving only `antislop:roast-work` and `antislop:ubiquitous-language`.

### Changed
- **`agents/reviewer.md`:** Removed `antislop:coding-discipline` from frontmatter `skills:` line (C6.1).
- All persona mirrors (`.claude/agents/reviewer.md`, etc.) regenerated via `--update` to match.

### Notes
- No body references to coding-discipline existed to remove (C6.2 verified).
- Validation passes (C6.3 verified).

## [0.31.31] - 2026-08-14

**Documentation: remove expired legacy-marker grace-period paragraph from persona protocol.** The grace period ending on 2026-07-27 expired 18 days ago. This change removes the descriptive paragraph referencing the 2026-07-27 cutover from the canonical protocol template and regenerates all inline mirrors, leaving the hook script's actual expiry logic untouched. Addresses gh355 (Step 1 of #348 spec).

### Changed
- **`templates/persona-protocol.md` (before "Pending-review flag" section):** Deleted "Until 2026-07-27 (legacy-marker grace period)..." paragraph describing the warning-and-allow behavior that expired and was superseded by unconditional rejection.
- All persona mirrors (`.claude/agents/*`, `.claude/persona-protocol.md`, `.claude/protocol-digest.md`) regenerated via `--update` to match.

### Notes
- `hooks/scripts/task-gate.sh` expiry logic is unchanged — only the prose describing it was deleted.
- `GRACE_PERIOD_END` constant remains in place and continues to guard the expired behavior path for backward compatibility.

## [0.31.30] - 2026-08-13

**Documentation update: annotate superseded fable-roast-pass policy in three ADRs (gh361, Step 8 of #348 spec).** ADR-0013 removes the separate fable advisory dispatch for roast-work. This change adds inline annotations to ADR-0004, ADR-0006, and ADR-0010 marking the affected passages as superseded by ADR-0013, following the precedent of ADR-0004's "Cost claim superseded" marker. Annotations are positioned adjacent to the dead text (not in footers) for immediate visibility to a reader following the pointer chain from `agents/reviewer.md` to ADR-0004's heavy-unit trigger.

