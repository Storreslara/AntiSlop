---
name: context_commit_before_reviewer
description: CONTEXT.md updates must be committed before reviewer dispatch
metadata:
  type: feedback
---

**Rule:** Commit all CONTEXT.md updates before the reviewer is dispatched.

**Why:** This project has hit "scribe left CONTEXT.md uncommitted" multiple times in recent sessions. When the reviewer stage is reached, a dirty working tree with CONTEXT.md changes blocks subsequent operations and creates confusion about what state the reviewer was actually checking.

**How to apply:** At the end of a scribe task, immediately stage and commit CONTEXT.md (and any other wiki/memory changes) via git before ending the turn or passing to the next stage. Do not leave CONTEXT.md in the working tree as a separate task for later. This is especially critical when the unit will be moving into reviewer dispatch.

Related pattern: `.claude/agent-memory/**` changes can also dirty the tree — consider whether they should be committed as part of the same scribe commit or kept separate per the project's conventions.
