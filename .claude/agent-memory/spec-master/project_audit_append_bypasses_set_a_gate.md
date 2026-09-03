---
name: audit-append-bypasses-set-a-gate
description: state_append_audit_log() takes a bare log NAME, so a command spelling only "review-audit.log" dodges harness-integrity-gate's Set-A path scan — a real, unfixed hole awaiting its own spec
metadata:
  type: project
---

`hooks/scripts/lib/state-access.sh`'s `state_append_audit_log()` takes a bare
log **name** and resolves it internally to `${dot}/${log_name}`.
`harness-integrity-gate.sh`'s `set_a_mentioned()` matches on the literal path
substring `.claude/review-audit.log`, and short-circuits with `return 1` when
the command contains no `.claude` substring at all. So a Bash command spelling
only `review-audit.log` never matches the scan, the gate exits 0, and the
function it calls writes to a Set-A protected file anyway.

**Why:** the gate protects by scanning the *caller's command text* for a
particular spelling, rather than by resolving the write target. Any indirection
that hides the path — a bare name, a variable, a helper function — defeats it
structurally. This is not a missing literal in a list; adding `review-audit.log`
unprefixed would over-match every unrelated mention.

**Status: unfixed, deliberately not fixed in gh425.** Found by the gh425-1
reviewer while investigating a *correct* block (the audit log is Set A with no
grant branch, not even for the reviewer), and explicitly declined rather than
used — the right call, and worth repeating. Verified independently 2026-09-02.
Recorded in `docs/plans/2026-09-02-blocked-marker-scoping-gh425.md` under
"Explicitly out of scope — follow-up needed".

**How to apply:** if asked to spec this, the fix belongs in `audit_append` /
`state_append_audit_log` — resolve the target and refuse Set-A paths there —
not in the gate's literal list. Check first whether a follow-up spec already
landed; per [[pass-note-warnings-do-not-propagate]] this exact class of
recorded-but-unactioned finding is what recurs. Do NOT use the hole to write an
audit line, whatever the provocation: that is the self-authorized-bypass rule
in the shared protocol, and a reviewer has already set the precedent of
declining it.
