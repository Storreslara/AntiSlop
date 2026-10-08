---
name: feedback-flip-default-run-suites-first
description: When a spec flips a shipped default (a frontmatter model, a schema default), replay its units in a scratch worktree before filing - the spec's edit list can miss a hard-coded copy of the old default, and its own criterion then cannot pass.
metadata:
  type: feedback
---

Observed 2026-10-08 (haiku-default-tier plan, units htd-1..htd-7). Step U4 flipped
`agents/lead-programmer.md` to `model: haiku` and its AC4.3 required
`tests/default-implementer-model.test.js` to exit 0, but `bin/cli.js` also
hard-codes `defaultImplementerModel: 'sonnet'` in the fresh-scaffold skeleton and the
spec had no edit for it. The existing test (skeleton must equal the frontmatter) failed
only when the unit was actually run.

**Why:** a grep of the spec's own text could not show this; only running the unit's
criteria against the edited tree did. Reading the plan alone would have filed a unit
whose acceptance criterion was unsatisfiable.

**How to apply:** for any spec that changes a default literal, apply the edits in a
scratch `git worktree add --detach` chained in dispatch order (cherry-pick earlier unit
commits), run every non-validate criterion, and run the existing suites that mention the
old literal. If one fails for a reason no edit covers, that is a spec gap: file the unit
HELD with the failing command, the scratch fix that made it pass, and the ruling needed.
Do not add the edit yourself. Note `bash tests/validate.sh` takes about 11 minutes and
fails in a fresh worktree for environment reasons (agent-memory notes, unreachable
commits), so do not use it as the scratch check.
