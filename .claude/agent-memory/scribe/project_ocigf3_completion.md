---
name: ocigf-3 completion
description: ocigf-3 scribe update completion; FAIL fixed to PASS; convention and glossary updates
metadata:
  type: project
---

## PASS ocigf-3 (2026-10-05)

Reviewer verdict (quoted verbatim): "PASS ocigf-3 (commit d9a378d). I checked AC-3.1 through AC-3.9".

Marker: `.claude/reviewed/ocigf-3.pass`

### History: FAIL → PASS

Commit range: 4f391e3~1..d9a378d

**FAIL verdict** (4f391e3, sonnet): command injection in token-usage.sh via shell arithmetic on usage.json fields. The script summed token values with `$((in + out))`, allowing string fields to execute shell commands and off-schema values to receive the wrong exit code. Fixed by opus re-write (d9a378d).

**PASS fix** (d9a378d, opus): fields are now validated in jq before any shell arithmetic sees them. All token fields must be non-negative integers ≤ 2^53-1. Totals are computed in jq. The `--cap` parameter is bounded to 15 decimal digits. Includes new test suite (tests/token-usage.test.sh, U1-U16 + M1 mutant, 755 mode) and README documentation for operator checks AC4.5 and AC4.6.

### Scope

Prototype/outcomeci-series-gate/ only. Scribe documentation updates, no code edits.

### Convention Recorded

**Values read from LLM-produced JSON are validated in jq and never reach shell arithmetic.**

This convention closes a class of injection vulnerabilities where unchecked JSON fields are interpolated into bash expressions. The fix in token-usage.sh is the canonical example: all token-count fields are now validated as integers in jq (lines 12-14 of token-usage.sh), exit 2 if any fail schema, and only then are the results safe for shell use (lines 19-20).

### Glossary Entries Added to CONTEXT.md

Two new entries, both warranted for understanding the live trial workflow:

1. **operator check** — a runbook check run by the trial operator during the live run (AC4.5, AC4.6), not part of repo CI. Distinct from automated acceptance criteria — the operator must manually verify token spend and static guards.

2. **token cap** — the `--cap` parameter to `token-usage.sh`, and the `OCI_TOKEN_CAP` environment variable placeholder. Bounds the total input+output token spend (e.g., `--cap 60000`). Exit codes: 0 ok, 1 over cap, 2 invalid field, 64 cap out of range.

All entries follow existing glossary style and cross-link existing related terms.

### Non-Blocking Gaps

**Implementation concerns (low severity, noted for future refinement):**

- **token-usage.sh:11 boolean false → 0**: The jq expression `(. // 0)` treats boolean `false` as 0 (neither null nor missing). A malformed usage.json with `"input_tokens": false` would sum as 0 and exit 0 instead of 2. Unlikely in practice because LLM-produced JSON uses numbers only, but worth noting for defense-in-depth.

- **Multi-document usage.json**: If the file contains multiple JSON documents (one per line), jq reads only the first. The spec does not address multi-record files; this is a silent-discard gap.

- **jq number formatting**: Printed numbers retain jq's internal formatting (e.g., `1E+15`, `1.0`, `-0`). A hardening fix would be `. + 0` before output to normalize. Minor cosmetic impact on operator readability.

- **Float imprecision in totals**: Token counts are numbers, and jq's `+` operator computes them as IEEE 754 floats. For totals above 2^53, the sum loses precision (by design; the field validator rejects individual fields > 2^53-1). Unlikely in practice but worth documenting for large-scale runs.

- **No `--` separator before "$1"**: The token-usage.sh invocation does not use `--` to separate options from the filename argument. If a file path starts with `-`, it could be misinterpreted as an option. Cosmetic; operator controls the file path in practice.

- **Limits undocumented**: The hardcoded limits (2^53-1 for individual fields, 15 decimal digits for `--cap`) are author-chosen and not documented in the design spec or README (only in code comments). A future update should document these limits openly in the spec.

- **usage.json directory path UNVERIFIED**: The README documents two lookup paths (first: `.outcomeci/outcomes/*/transcripts/summarize/usage.json`, fallback: `find .outcomeci -name usage.json`), but neither is verified against live OutcomeCI output until the first live run. Path discovery is a post-PASS concern; this gap is expected for a prototype.

### Test Verification

Ran `node tests/context-glossary-links.test.js` — all checks passed.

### Related Entries

- [[ocif-1 completion]] (prototype suite runner entry)
- [[ocig-1 completion]] (externalization, broker journal, policy decision entries)
- [[ocig-2 completion]] (zero-API workflow entry)
- [[ocig-3 completion]] (external run journal, external workflow runner entries)
