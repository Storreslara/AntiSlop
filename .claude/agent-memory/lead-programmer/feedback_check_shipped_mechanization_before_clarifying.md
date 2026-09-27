---
name: feedback-check-shipped-mechanization-before-clarifying
description: before writing constitution/spec prose that resolves an ambiguity, grep for an already-shipped script or glossary entry that may have already settled it
metadata:
  type: feedback
---

When a task asks you to resolve an ambiguity in a rule (e.g. "is X per-unit
or per-spec?"), grep for an already-shipped mechanization or a canonical
glossary entry (CONTEXT.md, docs/harness-glossary.md, CHANGELOG.md) BEFORE
deriving the answer from first-principles reasoning about the rule's own
stated rationale — the answer may already be settled elsewhere, and your
own reasoning can independently arrive at a *wrong* value even when it looks
internally sound.

**Why:** on item17-1-clarify-p3-granularity I was asked to state whether
constitution P3's version-bump requirement is per-unit or per-spec. I
reasoned from the `--update` staleness rationale alone and concluded
"per-unit" — but `hooks/scripts/version-stamp-check.sh` (shipped
2026-09-23) already implements **per-commit** semantics, and
`CONTEXT.md`'s `version-stamp discipline` glossary entry already says "same
commit". My own added sentence was even internally self-contradicting: the
rationale I wrote argued per-commit, but the normative clause I wrote said
per-unit. The reviewer FAILed it, correctly, citing exactly these three
pre-existing sources. This is the THIRD real FAIL in this project's history
on this same version-stamp-discipline area (see
`version-stamp-discipline-gap` in the separate Claude Code auto-memory
index) — a signal that this specific rule keeps costing FAILs precisely
because agents (including me) reason about it from principles instead of
checking what's already shipped.

**How to apply:** whenever a plan or dispatch asks you to "clarify" or
"resolve" wording for an existing convention, run `grep -rn <topic>
CONTEXT.md docs/harness-glossary.md CHANGELOG.md hooks/scripts/` (or use the
`explorer` for this) before drafting the new prose, not after. If a shipped
script or glossary entry already encodes the granularity/semantics in
question, your job is to align new prose to it, not to re-derive it. See
[[project_version_stamp_discipline_gap]] if it exists in this namespace, or
the Claude Code auto-memory equivalent, for the running history of this
recurring failure class.
