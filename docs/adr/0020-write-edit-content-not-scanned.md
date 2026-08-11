# 0020 — Write/Edit tool-call CONTENT is deliberately not scanned for marker-path substrings

**Date:** 2026-08-11  
**Status:** Accepted  
**Issue:** [#288](https://github.com/Storreslara/AntiSlop/issues/288)

## Decision

The `reviewed-path-gate.sh` hook deliberately does **not** scan the *content* of `Write` and `Edit` tool calls for the substring `.claude/reviewed`. It scans only the *destination file path*. This asymmetry versus the Bash shape (which scans full command text) is ratified as a deliberate choice, backed by re-derivable measurements showing that content-based detection has zero discriminative power and creates substantial false-positive cost.

## Context and measurements

The asymmetry was reported in issue #288 as a potential loophole: a `Write` call whose content discusses `.claude/reviewed` is allowed, while an equivalent Bash command spelling the substring in a heredoc is refused.

**Measurement 1: False-positive surface** (2026-08-11)

```bash
GATE_PATH="MARKER_DIRECTORY_PLACEHOLDER"
GATE_PATH=$(echo "$GATE_PATH" | sed 's/MARKER_DIRECTORY_PLACEHOLDER/.claude\/reviewed/')
grep -rl --exclude-dir=.git "$GATE_PATH" 2>/dev/null | wc -l
```

Returns **111 files** as of today (2026-08-11), many of which legitimately discuss the gate's behavior in documentation, ADRs, protocol files, and test suites. A naive content scan on `Write`/`Edit` would flag all 111 as potential violations, blocking routine maintenance of this repo's own documentation by `scribe`, `spec-master`, and `lead-programmer` personas — the very roles that write ADRs, protocol updates, and plan documents discussing the gate.

**Measurement 2: Zero discriminative power on the actual incident** (2026-08-11)

The incident file at commit `1be4ca1` (`feedback_reviewed_path_gate_heredoc_workaround.md`) contains the literal substring exactly once:

```bash
git show 1be4ca1 2>/dev/null | grep -c "claude/reviewed" || true
```

Returns **1** — a benign prose mention at line 9 describing the gate in a sentence. The actual malicious content (lines 25-37) — the bypass recipe using string concatenation (`".claude" + "/reviewed"`) to evade a substring scan — contains no substring hit at all. A content-based gate would flag the file for the wrong reason (the prose), miss the technique (the concatenation), and pass 12 other legitimate agent-memory files that document the *sanctioned* placeholder-then-substitute pattern the gate's own refusal text recommends.

**Measurement 3: Reviewer-approved replacement file passes a content scan** (2026-08-11)

The replacement memory file written after remediation:

```bash
grep -c "claude/reviewed" /home/sebas/AntiSlop/.claude/agent-memory/lead-programmer/feedback_reviewed_path_gate_false_positive_report_and_wait.md || true
```

Returns **0**. This file, which was reviewer-approved as correct remediation, contains zero hits for the substring. The good outcome and the adversarial outcome sit on the same side of a content check — a check with zero ability to distinguish them has no value.

**Measurement 4: Existing principle already decides this** (2026-08-11)

`CONTEXT.md`'s entry on **Removed rather than inspected** (unit #272, 2026-08-08) formalizes the principle that text-based gates missing any form of obfuscation "create a false sense of security without actually bounding the surface; removal is the sound choice." Path obfuscation via string concatenation (`".claude" + "/reviewed"`) is exactly such a form. Content scanning the write path would be the scan that Measurement 2 demonstrates cannot catch this technique.

There is also no `command_is_provably_benign()`-style nuance available on content: that function discriminates by *action* (read-only vs. write-capable). Content is not an action — there is no benign content. The only axis a content check could add is destination, which the Write/Edit path already inspects.

## How the visibility gap is closed instead

Rather than attempting content-based detection (rejected for the above reasons), the visibility gap this asymmetry creates is closed by two new informational observability sections in `scripts/agent-audit.sh`, landing in the sibling unit `gh288-audit-a7a8`:

- **A7** — Hook block events: per dispatch, parse `is_error: true` tool results whose text matches `PreToolUse:<Tool> hook error: [...BLOCKED:]` and emit counts grouped by hook and tool. This captures gate blocks *before* any agent can act or obfuscate them.
- **A8** — Agent-memory writes: per dispatch, count `Write`/`Edit` calls whose paths resolve under `.claude/agent-memory/` and emit the count and file basenames. This surfaces the substrate where institutional memory lives, making future policy violations (deliberate writes to marker paths) visible without needing content inspection.

Together, A7 + A8 render the incident's exact shape — "this dispatch took N gate blocks *and* wrote M memory files" — visible to a human in one audit report. The block is a *fact* recorded in the transcript before any bypass can occur; the gate fires before the agent can act, so the event cannot be evaded by the obfuscation that defeats content scanning.

## Related principles and decisions

- **Removed rather than inspected** ([CONTEXT.md](../../CONTEXT.md#removed-rather-than-inspected)): The rationale for not attempting content-based detection. If scanning text misses obfuscation forms (like string concatenation), it creates false confidence without actually bounding the surface.
- **Gate vs. Reporter** ([CONTEXT.md](../../CONTEXT.md#gate)): The distinction between blocking gates and observational reporters. A7/A8 are report sections (informational), not new gates or reporters.
- **self-authorized bypass** ([CONTEXT.md](../../CONTEXT.md#self-authorized-bypass)): The glossary term for the violation class (routing around a gate without waiting for permission). This decision ratifies that the detection must come from observing gate blocks themselves, never from attempting to intercept the technique.

## Acceptance and audit trail

- [Issue #288](https://github.com/Storreslara/AntiSlop/issues/288) documents the asymmetry report.
- Commit `1be4ca1` and its remediation `4eeb3a2` hold the incident's verdict markers:
  - [`.claude/reviewed/gh-281-detection.fail`](./.claude/reviewed/gh-281-detection.fail) — reviewer's finding that the incident file contained an unsafe bypass technique
  - [`.claude/reviewed/gh-281-detection.pass`](./.claude/reviewed/gh-281-detection.pass) — reviewer's approval of the remediation
- [ADR-0015](0015-commit-anchored-pass-markers.md) and related prior decisions establish the verdict-marker discipline that A7/A8 audit.

---

**Decision finalized:** This asymmetry is not a defect to be closed by extending the Write/Edit check to scan content. It is a sound application of the **Removed rather than inspected** principle. The visibility gap it creates (agent-memory writes can proceed unobserved) is closed by observational sections A7 and A8 in the audit script, not by attempting a technique-based detection that evidence shows cannot work.
