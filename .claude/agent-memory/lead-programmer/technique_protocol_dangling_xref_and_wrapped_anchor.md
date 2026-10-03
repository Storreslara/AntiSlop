---
name: protocol-dangling-xref-and-wrapped-anchor
description: cli.js aborts if kept protocol prose names a dropped section header; acceptance grep anchors break on line wrap; plain --update does not re-render after a template re-edit
metadata:
  type: feedback
---

Prose added to a protocol section that is kept by a persona must not name a header (e.g. "Pending-review flag") that persona's matrix row drops: `cli.js` throws assertNoDanglingCrossReferences at load, so `--update` dies. Describe the thing inline instead.

**Why:** esf-flag-prose first draft cross-referenced the flag section from the "Review gating off" paragraph.
**How to apply:** after any template edit run `--update`, then `--update --check` (force-render) and confirm `git status` is clean before committing; multi-word `git grep` anchors in the plan must sit on one physical line (reflow, then re-render and amend). Use `git commit -a -F file` to dodge the persona-config literal. See [[project-protocol-template-derivation-model]].
