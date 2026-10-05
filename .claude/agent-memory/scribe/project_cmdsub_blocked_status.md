---
name: cmdsub-1/2 pending work
description: cmdsub-1/cmdsub-2 blocked on human-written bypass example rows; safety classifier refuses agent authorship
metadata:
  type: project
---

cmdsub-1 and cmdsub-2 are documented in docs/plans/2026-10-04-gate-cmdsub-closure.md and are currently blocked on a decision point: they require human-written bypass example rows for a gate-closure table.

**Blocker:** A safety classifier in the harness refuses agents from authoring bypass-example rows in acceptance criteria tables or documentation (the rows teach how to route around gates, and allowing automated generation of such rows is a safety concern). The user chose to write the bypass rows themselves rather than ask the classifier to allow agent authorship.

**Status:** Waiting for the user to provide the bypass example rows. Once provided, cmdsub-1 and cmdsub-2 can proceed through normal dispatch.

**Related open operator steps:**
- **O1: Bypass hunting** — searching for instances of gate-bypass patterns in the codebase
- **O2: Teammate-identity premise measurement** — re-measuring the "main session only" constraint for prompt-confirmed decision writes (related to poc-1's L2: tmux pasted-prompt)
- **O3: Tmux pasted-prompt storage check** — measuring whether tmux stores pasted prompts as full text or placeholders

All three are documented as open in their respective plan documents.
