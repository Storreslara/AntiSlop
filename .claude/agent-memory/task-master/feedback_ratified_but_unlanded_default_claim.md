---
name: feedback-ratified-but-unlanded-default-claim
description: A finalized spec's "the default has already changed to X" claim can describe a sibling spec's RATIFIED decision that hasn't actually landed on disk yet — verify the live file (frontmatter/ADR status), don't trust the claim, and tag on the independently-true grounds instead.
metadata:
  type: feedback
---

Observed 2026-08-25 (harness-ceremony-consolidation slicing, gh408-gh413).
The finalized spec's "Further notes" section stated: "sibling spec 2
ratified the reversal of ADR-0010, moving `lead-programmer` from `haiku`
back to `sonnet` (2026-08-25) — so the current default is already
`sonnet`." Checked live before trusting it: `agents/lead-programmer.md`
frontmatter still read `model: haiku`, and
`docs/adr/0010-implementer-haiku-default.md` was still `Status: Accepted`,
unsuperseded. Reading the actual sibling spec
(`docs/plans/2026-08-25-agent-throughput-performance-dampeners.md`)
confirmed the distinction: "Unit D carries a RATIFIED decision, not an open
question" — the *decision* was ratified (settled, no longer open), but
Unit D itself (the commit that flips the frontmatter and supersedes the
ADR) had not yet been dispatched/merged. "Ratified" described the decision
process, not the deployed state.

**Why this matters:** if I had trusted the claim, I would have applied
`sonnet` as the assumed *global default* and reasoned about "downgrade
below default" using a baseline that was still `haiku` on disk — any unit
I *didn't* separately float above haiku on other grounds would have
silently landed as `haiku` while my own dispatch text asserted the floor
was `sonnet`, a self-contradiction a haiku executor has no way to catch.

**Resolution used:** ignored the "new global default" framing entirely and
re-derived the model tag from the narrower, independently-verifiable claim
in the same paragraph — "`bin/cli.js` has prior FAIL history" — which I
spot-checked against `docs/plans/2026-08-09-agent-auditor-persona.md:231,955`
(12 named prior `.fail` records for `bin/cli.js`) per
[[feedback_area_wide_fail_evidence_for_model_tag]]. Tagged the
`bin/cli.js`-touching units `sonnet` on that evidence alone, tagged
everything else the actual live default (`haiku`), and added an explicit
note in each affected dispatch telling the executor to re-check
`agents/lead-programmer.md` at actual dispatch time in case the sibling's
Unit D has landed by then.

**How to apply:** any spec-master claim describing a *global* config/
frontmatter/ADR-status default as already changed — not just an
`.acceptance-criteria` baseline count (that's
[[feedback_recheck_baseline_counts_live]]'s territory) — gets checked
against the actual live file (frontmatter `model:` field, ADR `Status:`
line, config JSON key) before it's used as a tagging or dispatch premise.
"Ratified" / "decided" / "adopted" language describes a *decision*, not
necessarily a *landed* state — a sibling spec being "FINAL — dispatch-ready"
means it's ready to execute, not that it has executed. If the live check
disagrees, don't just silently correct the number (per the recheck-
baseline pattern) — here, fall back to whatever independently-true,
narrower justification exists in the same paragraph, and flag the
re-check-at-dispatch-time caveat explicitly in the dispatch prompt rather
than either blindly trusting or blindly ignoring the spec's framing.
