---
name: project_persona_audit_plan
description: 13-unit persona-system-audit-patch plan tracking (issue #121) — version-stamp plan defect found in U4, OQ6=A selected in U2, U13 done, per-unit status
metadata:
  type: project
---

Tracking `docs/plans/2026-07-22-persona-system-audit-patch.md` (issue
#121), an 11-step plan remediating an external architecture audit of the
persona system. Units are dispatched as `persona-audit-U<n>`.

**U11 (Step 11, final) — done, commits `f2383a7` (version bump +
CHANGELOG) + `874bd07` (final `.claude/` resync).** Bumped both
`.claude-plugin/plugin.json` and `package.json` to 0.13.14 (both files'
existing convention). Ran the SECOND, final `bin/cli.js --update` — most
of the .claude/agents/*.md deltas (Steps 8-10, 12, 13) turned out to
already be sitting uncommitted on disk from earlier units' own
verification `--update` runs (see [[project_cli_update_testing]] Gotcha
7); this unit's job was mainly to confirm correctness and commit them,
plus actually bump `pluginVersion`. Stamp-placement check applied
correctly per-file-type: the 9 `.claude/agents/*.md` files (frontmatter)
need `head -1 == "---"` (stamp lands after frontmatter); the untracked-
in-source `.claude/persona-protocol-slim.md` has NO frontmatter, so its
correct/expected placement is the stamp AT the top of the file (line 1),
not after a `---` — confirmed this is a companion-file convention (same
family as [[project_vendor_mattpocock_skills]]'s header-placement note),
not a bug. **Plan-doc inconsistency flagged, not fixed:** Step 11's
literal acceptance-criteria text (written pre-U12) still names
`.claude/persona-protocol.md` in both the idempotency `git diff --quiet`
path list and the stamp-check file list — that file no longer exists
post-U12 (OQ11=DROP). Applied the check to files that actually exist
instead of silently reconciling the plan doc itself (out of scope for
lead-programmer to edit).

**U13 (Step 13, post-U6 stale-reference/comment sweep, roast-follow-up) —
done, commit `52b10af`.** Doc/comment-only, three items: README L182 (setup
table) corrected from "+ one `@import` line in CLAUDE.md" to the inlined-
per-persona wording; README L212 dropped the stale `@.claude/persona-
protocol.md`-line cleanup bullet (L205-206 file-entry bullet left untouched
— that one's U12's); `session-start.sh`'s re-anchor-skip comment recites the
real reason now (orchestrator's inlined protocol body) instead of the
removed import; `inlineProtocolBlock` in `bin/cli.js` got a comment
documenting its intentional version-less marker vs. `upsertMarkedBlock`'s
versioned one (marker format itself untouched, per spec-master's
document-not-change call).

**U10 (Step 10, mirror full/slim split to Codex + Cursor adapters) — done,
commit `5a5c8ce`.** Key finding: the split ALREADY rode the existing
hand-authored per-agent inlined backstop — explorer carries NO "## Shared
protocol essentials (inlined backstop)" section (=slim); orchestrator/
lead-programmer/reviewer each carry one (=full), on BOTH adapters. So NO
cli.js change was needed: `scaffoldCodex` reads each `.toml` verbatim (prepends
a `#` stamp), `scaffoldCursor` copies each `.md` verbatim — no backstop-
generation logic exists (the dispatch's "Cursor inline-backstop generation
logic in cli.js" was a misconception). The adapters use platform-FLAVORED
digests (`.codex/`/`.cursor/` paths, Cursor's UNVERIFIED-rule caveat), NOT the
Claude `templates/persona-protocol.md` — so injecting templates per-agent
(a literal reading of the dispatch) would be WRONG (Claude-flavored `.claude/`
paths + TOML-invalidity: HTML marker can't be appended to a .toml). Instead:
added one third-verdict `INSUFFICIENT-CONTEXT` bullet to each of the 6 full-tier
backstops (inside the codex developer_instructions triple-quoted strings, kept
tomllib-parseable; kept Cursor's caveat verbatim). Made INSUFFICIENT-CONTEXT
the assertable full-only marker. Did NOT touch persona-protocol.mdc (split
rides the body, not the rule) or explorer files. Test: one scaffold-and-grep
per adapter in cli-backfill.test.js. NOTE: mid-unit the working tree was
externally reset once (wiped uncommitted edits + advanced history past U6/U7/
U8/U9/U13) — re-applied cleanly; watch for transient `git status` glitches
during such resets (showed clean tree momentarily, then edits reappeared).

**U6 (Step 6, per-persona protocol injection + CLAUDE.md migration) — done,
commits `1f69388` (mechanism) + `46740da` (interim live re-sync).** OQ6=A
body-inlining: `renderCleanBody` appends the tier-appropriate protocol as an
`ANTISLOP:BEGIN/END persona-protocol` marked block (reusing the Codex marker
constants) — deterministic/idempotent since source bodies carry no marker.
`buildFileSpecs` tags each persona spec `protocolTier` via `protocolTierFor`
(slim = explorer/researcher/scribe, full = everyone else). Fresh install now
inlines protocol into bodies and never adds the global CLAUDE.md import.
`--update` auto-migration (OQ9=A): `migrateGlobalProtocolImport` strips the
`@.claude/persona-protocol.md` line from CLAUDE.md and its return value is
added to the fast-path guard, so removing the import FORCES the render loop
even at a matching pluginVersion (this is what makes migration work on a
version-matched project — key design point). Slim-persona audit: explorer/
researcher/scribe bodies reference ZERO omitted sections (grepped WIP/pending/
verdict/marker/retrieval/machine-checkable/FAIL-cap) — no per-line inlining
needed; scribe body is fully role-agnostic. Interim live re-sync ran clean (no
pending files), pluginVersion left at 0.13.13 (bump is U11). The graph
pre-commit hook flagged the 5 new/changed fns "untested" — the known
false-negative ([[project_cli_update_testing]] Gotcha 1/5); they ARE covered by
two new tests in cli-backfill.test.js (renderCleanBody tier check + the
`--update` migration integration test).

**U3 (Step 3, verify Cursor subagent-body delivery of the inlined
full/slim backstop) — done.** Result: PASS, via documented conclusion
(not a live probe — Cursor has no CLI reachable from this environment,
unlike U1/U2's nested Claude Code sessions, so the plan's own fallback
methodology applies). Live-fetched `cursor.com/docs/subagents`
(2026-07-22): its "File format" section states a subagent file is
"YAML frontmatter ... followed by the prompt" — the post-frontmatter
body IS the subagent's instructions by construction of the documented
file format, with no separate frontmatter field for instructions. This
is independent of the separately-UNVERIFIED `persona-protocol.mdc`
alwaysApply-rule-reaches-subagents question (that caveat is unaffected
and still stands). Recorded in `docs/persona-design-notes.md`'s
Verification section. Clears the prerequisite for U10's Cursor portion —
no degrade-to-full-everywhere fallback needed on this axis.

**U5 (Step 5, author `templates/persona-protocol-slim.md` + register in
`bin/cli.js`) — done, commit `8ed4b04`.** Created the slim digest with
exactly the five OQ8=A sections, registered it in `buildFileSpecs()`
(fileHashes tracking is automatic once a spec is in that list — no
separate registration step needed). Added a targeted `cli-backfill.test.js`
check asserting the spec appears in `buildFileSpecs([])`'s output. Did
NOT wire per-persona delivery (full vs. slim) — that's U6.

**U4 (Step 4, relocate maintainer rationale to
`docs/persona-design-notes.md`) — done, commit `aa52c4e`.**

**U2 (Step 2, verify `@import`-in-body resolution) — done, commit
`68c6156`.** Result: @import does NOT resolve inside a persona `.md`
body — Step 6 must use OQ6=A (`--update` body-inlining), not the OQ6=B
per-body `@import` fallback. Methodology note for future probe-style
units: the naive text-relay pattern (parent `claude -p` paraphrases the
subagent's reply) is NOT reliable enough alone — a first pass gave one
PRESENT then five ABSENT on identical unmodified re-runs, i.e. the
parent occasionally hallucinates/guesses instead of faithfully relaying.
Fixed by having the dispatched subagent use Write to record its own
result to a file, read back directly, bypassing the parent's paraphrase
entirely; 4/4 positive + 1/1 control trials then agreed consistently.
Any future probe unit should default straight to the file-write
methodology rather than text-relay, even though U1's Step 1 probe
(text-relay only, one trial each direction) happened not to expose this
flakiness.

**U1 (Step 1, verify HTML-comment token cost) — done, commit `2be9a17`.**
Live probe (nested `claude -p` headless session, Task-tool dispatch to a
throwaway `.claude/agents/probe-subagent.md` with a unique-token HTML
comment, plus a no-comment negative control) confirmed comments are NOT
stripped before dispatch — they reach the subagent's system prompt.
Recorded under docs/persona-design-notes.md's new "Verification" heading.
This makes U4's already-merged relocation a real token-cost win, not just
readability; does not reopen U4.

**Plan-defect found in U4, relevant to any later unit touching the
`<!-- antislop vX | source: ... -->` stamp line:** the plan's acceptance
criteria (Step 4, and likely others referencing "the version-stamp line
remains in `agents/<persona>.md`") assume source `agents/*.md` files
carry this stamp. They never have — confirmed via `git log --follow` on
every persona file plus reading `bin/cli.js`'s `versionStamp`/
`copyStamped`/`insertStampAfterFrontmatter` (~L97-118): the stamp is
generated dynamically at ADAPT/`--update` time with the *live* plugin
version and inserted only into the copied `.claude/agents/*.md` files,
right after the frontmatter's closing `---`. Source `agents/*.md` is
never stamped. `grep -q '<!-- antislop' agents/<persona>.md` will fail
for all 8 personas regardless of what a unit does — this is a plan
authoring mistake (confusing source with ADAPT-copied output), not
something to fix by fabricating a hardcoded version string in source.
Flagged in the U4 report rather than worked around; future units
touching this criterion should flag it the same way instead of
re-deriving the same investigation.

Also found in U4: `agents/lead-programmer.md` carries no maintainer-
rationale HTML comment block at all (confirmed back to its earliest
tracked frontmatter, commit `53b4db6`) — a plan step describing "each
persona body" for that stamp/rationale work is vacuously satisfied for
this one persona; nothing to relocate there.

**U7 (Step 7, inverted-version-skew pre-flight guard for `--update`) — done,
no code changes.** `runUpdate()` in `bin/cli.js` already has a full downgrade
guard (issue #102, `bin/cli.js` ~L500-528): refuses (exit 1, not just warns)
when resolved plugin version < recorded `.claude/persona-config.json`
`pluginVersion`, before any file write, with an explicit `--allow-downgrade`
escape hatch; `tests/cli-backfill.test.js` L378-482 already cover both the
refusal (asserting byte-identical files via sha256 before/after) and the
override. `warnIfDowngradeStamp` (the helper named in this unit's dispatch)
is a *different*, deliberately warn-and-proceed guard scoped only to the
three `--overwrite` scaffold paths (issue #110) — it does NOT fire on
`--update` and was correctly left untouched (single `--update` entry point
confirmed at `bin/cli.js` ~L1404-1405, calling `runUpdate` directly). Step
7's acceptance criteria were already satisfied pre-dating this plan; flagged
rather than adding a duplicate test.

See also [[feedback_grep_acceptance_line_wrap]] — relevant again for any
later unit writing prose into `docs/persona-design-notes.md` or the new
`templates/persona-protocol-slim.md` (Step 5): reflow hand-wrapped source
lines so a chosen grep-test sentence doesn't span the doc's own line
wrap.
