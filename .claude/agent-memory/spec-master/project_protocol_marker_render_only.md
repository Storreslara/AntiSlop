---
name: protocol-marker-render-only
description: agents/*.md sources carry NO `ANTISLOP:BEGIN persona-protocol` marker; only the rendered .claude/agents mirror does — anchor edits on the source's own end, not the marker
metadata:
  type: project
---

`agents/<persona>.md` (source) ends with the persona's own prose; `bin/cli.js`
appends the `<!-- ANTISLOP:BEGIN/END persona-protocol -->` block only when it
renders `.claude/agents/<persona>.md`. A plan step that says "insert before the
BEGIN marker" in the source is unsatisfiable.

**Why:** the 2026-10-14 skills-audit spec first placed spec-master's PRD
appendix "before the marker" in `agents/spec-master.md`; caught in self-check
(CHK12) by grepping the source and finding no marker.

**How to apply:** target the source file's end; if position relative to the
protocol block matters, check it in the rendered mirror with an awk range
(`/heading/{a=1} /ANTISLOP:BEGIN/{a=0} a`). See [[protocol-amendments-do-not-propagate]].
