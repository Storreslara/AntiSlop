---
name: specs-publish-as-per-step-issues
description: This repo files one GitHub issue PER STEP under a plan/<slug> label via task-master's to-tickets — never an umbrella to-spec PRD issue. Don't publish a spec issue yourself.
metadata:
  type: project
---

The tracker convention here is **step-level issues only**. Every open issue is
one sliced unit, labelled `ready-for-agent` + `plan/<plan-doc-slug>` (e.g.
`plan/2026-08-04-skills-library-remediation`), filed by `task-master` running
`to-tickets`. Verified 2026-08-07 by sampling the 8 most recent issues
(#248-#255): all step-level, zero umbrella/PRD issues.

**Why:** the `docs/plans/YYYY-MM-DD-<slug>.md` document is the canonical spec
artifact, and `task-master` owns slicing. A separate `to-spec` PRD issue would
duplicate the plan doc in a second place and break the one-issue-per-grabbable-
unit model the whole dispatch pipeline (retrieval contract, H3, `.pass` markers
keyed to unit ids) is built on.

**How to apply:** my persona text says to publish specs of >=3 units via
`to-spec`. In THIS repo, satisfy that by writing the `docs/plans/` doc and
handing off to `task-master` — do not run `gh issue create` for the spec
itself. The `plan/<slug>` label is derived from the plan doc's filename, so
name the doc first and let the slug follow. Related:
[[to-spec-slash-only]] for that skill's flag-state quirk.

**#122/#123 are the SUPERSEDED pattern, not the current one.** Those two are
umbrella `Spec: ...` issues carrying a `plan/<slug>` label, from 2026-07-28.
Re-confirmed 2026-08-07 (issue #226 dispatch cited them as the convention to
follow): everything from ~#248 onward is step-level. If a dispatch points at
#122/#123 as the model, say so rather than filing an umbrella issue — the
`plan/<slug>` label on them is what makes them look current.
