---
name: technique-contract-guard-r6-bullet-shape
description: contract-score v2 R6 fails a lead contract unless EVERY "Do NOT touch" bullet opens with a backticked path; prose-first bullets silently drop the unit to sonnet.
metadata:
  type: feedback
---

`bin/contract-score.js` r6v2 requires >= 2 bullets in `## Do NOT touch`, and every one must match
`^- \`[^\`]*[/.][^\`]*\`` — the FIRST token is a backticked path containing `/` or `.`.
A bullet like "- the rest of `agents/orchestrator.md` ..." or "- the adapter ports under `adapters/`"
scores R6 false, and the guard prints `contract-guard: sonnet ... failed=R6`.

**Why:** 2026-10-10 rnf-4/rnf-5 drafts scored 6/7 for exactly this; rewording to
"- `agents/orchestrator.md` outside edit 1, ..." restored 7/7.

**Other rows that silently drop a prose-style draft to 3-5/7** (2026-10-13 epfb drafts):
R1 needs every edit item as `file:` (backticked first) + `anchor:` + `indent: N` (when the
payload is fenced) + `before:`/`after:` (or `insert-after:`), and commands as `command:` + `expect: N`.
A "replace every occurrence" prose edit fails, so write one item per site. R5 needs `tdd: yes|no <path>`,
`blast-radius:` with a `file:line`, `commit-message:`, and a `review-packet:` fenced block of
`<FILL: ...>` blanks. Any other `<word>` in that block fails it. R7 needs the literal line
`diagnosis: none`, so put a real diagnosis under another key (`measured:`). R2 (stamped
units) needs semver on the plugin.json/package.json edit lines, a CHANGELOG `insert-after:`
item, `node bin/cli.js --update` in the text, and a `run:` containing `version-stamp-check.sh`.
Also: never splice a plan by `text.index('## Heading')`. The Status line mentioned that
heading inline, and the splice deleted the whole plan body. Anchor on a line start or on a unique string.

**How to apply:** after drafting fast-path contracts, always run
`node bin/contract-guard.js <plan> --unit=<id> [--shape=scribe]` for every unit before handoff;
lead every Do NOT touch bullet with the backticked path. Related: [[verify-own-criteria-nonvacuous]].
