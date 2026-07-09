---
id: memory-note
title: A note on memory
applies_to: [lead-programmer, planner, repo-historian]
---
If your persona has a `memory` field set, Claude Code auto-grants you Read,
Write, and Edit so you can manage your memory files — this happens regardless
of your declared `tools:` list. That is not license to edit source code if
your role says you never do (e.g. the planner never writes production code,
pseudo-code aside). The restriction in that case is enforced by instruction,
not by the tool allowlist — treat it as a hard rule anyway.
