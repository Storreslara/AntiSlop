---
name: feedback_version_bump_on_agents_templates_edit
description: Any edit to agents/*.md or templates/ MUST bump plugin.json+package.json and add a CHANGELOG entry in the same unit, even when the dispatch's scope statement says "only these files" — --update propagates stamped mirrors by version comparison only (FAILed reviewer-changes-examples-lean-2)
metadata:
  type: feedback
---

Rule: when a unit changes `agents/*.md`, `templates/*`, or anything else that
renders into a version-stamped mirror, bump the version in BOTH
`.claude-plugin/plugin.json` and `package.json`, add a CHANGELOG entry (style:
bold `**X.Y.Z — title (unit-ids).**` paragraph + `### Changed` file list naming
the bump and the regenerated set), re-run `node bin/cli.js --update
--force-render`, and land it all in the unit's commit — constitution §3 /
"Version-stamp discipline" (P3). Do this even if the dispatch's boundary or
"expected files" list omits the manifests; flag the scope tension in the report
rather than obeying it silently.

**Why:** `bin/cli.js --update` early-exits on a stamped persona mirror using
only `stampVersionOf(body) !== version` (never a content diff — that exists
only for `kind === 'raw'` hook-script specs). At an unchanged version an
already-adapted downstream project reports "already current" and never
receives the edited instructions, so the change is functionally lost. This
slipped past two consecutive units (1a20c7d PASSed with the gap unnoticed,
c6c2476 FAILed on it); nothing in validate.sh enforces it.

**How to apply:** at step-7-style "git diff --stat shows only the expected
files" checks, treat a diff touching `agents/`, `templates/`, or `adapters/`
without a manifest bump as a red flag, not as compliance. The bump ripples a
stamp refresh across ALL ten `.claude/agents/*.md` plus
`.claude/persona-protocol.md`, `persona-protocol-slim.md`,
`protocol-digest.md`, and the config hash file — name that full set in the
CHANGELOG's regeneration bullet (0.31.73's entry was corrected for
under-naming it). Commit route is `git add -A` + plain `-m` because the config
file is Set A (see [[harness-integrity-gate-persona-config-commit]]).
