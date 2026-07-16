---
name: project_threefold_update
description: Multi-track plan doc/issue tracking and per-step commit convention for the 2026-07-14 threefold-update work on seb_claude_setup (antislop plugin)
metadata:
  type: project
---

The repo is executing a multi-track, fully-approved plan at
`docs/plans/2026-07-14-threefold-update.md`, tracked via GitHub issues in
`Storreslara/AntiSlop` under label `plan/2026-07-14-threefold-update` (one
issue per step, e.g. issue #12 = Track 1 Step 1.3).

**Why:** Steps are dispatched one at a time as separate lead-programmer
sessions with no shared memory between them, so each dispatch prompt
restates the retrieval-contract line and prior-step status explicitly.

**How to apply:** On a fresh dispatch for this plan, trust the prompt's
retrieval-contract line over any older assumption about tracker/fetch
method. Note the observed commit convention: only the exact files touched
by that step are staged (e.g. `git add agents/foo.md .claude/agents/foo.md`),
never a bulk `git add .claude/` or `-A` — most `.claude/agents/*.md`
dogfood-adapted copies are untracked in git except the ones an earlier step
explicitly touched (verify with `git ls-files .claude/agents/` before
assuming a file is already tracked). Each step gets its own small commit,
scoped to that step's acceptance-criteria files only.

**Track 3 (hivemind split) progress:** Step 3.1 (`agents/spec-master.md`,
commit fed9155) and Step 3.1b (debug-spec artifact bullet, commit 736a971,
issue #19) are done and reported ready-for-review. Load-bearing detail
for later Track 3 dispatches (3.2 task-master, 3.5 orchestrator routing,
etc.): the plan's responsibility table reassigns per-step `Suggested
model: haiku|sonnet` tagging AND the retrieval-contract line to
`task-master`, not `spec-master` — spec-master's "Plan output format" and
"Self-check" prose were adapted (not verbatim) to drop those two items
even though hivemind's original bullets included them, because they're
framing/description, not worked examples. Only the three fenced-code
worked examples (Clarifications, Constitution check, Self-check) were
required verbatim; everything else in the split is judgment-adapted per
the plan's responsibility table — re-check that table before assuming a
hivemind bullet transfers unmodified. `agents/hivemind.md` is still on
disk (untouched, live) until Step 3.3 removes it.

**Step 3.4 done (commit 8f9e40d, issue #22):** `bin/cli.js`
`OPTIONAL_PERSONAS` now `['spec-master', 'task-master', 'scribe', 'reviewer',
'milestone-auditor']` (hivemind fully removed). `LEGACY_PERSONA_MAP` values
changed from bare strings to arrays (`{ planner: ['hivemind'], hivemind:
['spec-master', 'task-master'], 'repo-historian': ['scribe'] }`) plus a new
`resolveLegacyToken(token)` helper that recursively flat-maps through the
map, so `migrateLegacyPersonaTokens` now dedupes+chains transitively
(`planner` -> `hivemind` -> `spec-master`+`task-master`, still one hop for
`repo-historian` -> `scribe`). `applyMattpocockSubs` needed NO change — it's
generic over whatever file body it's given, driven entirely by
`OPTIONAL_PERSONAS` selecting which `agents/*.md` get rendered, so
`spec-master.md`'s/`task-master.md`'s `<MATTPOCOCK:*>` tokens resolve for
free. Explorer-confirmed blast radius: nothing outside `bin/cli.js` and
`tests/cli-backfill.test.js` depends on the old string-valued map shape or
on `'hivemind'` being in `OPTIONAL_PERSONAS` — Steps 3.5+ touching
orchestrator/lead-programmer prose don't need to know cli.js internals.
tests/cli-backfill.test.js `:140` legacy-fixture subtest is STILL
skip+TODO'd (untouched, Step 3.6's job) — I only added two new subtests
after the existing `:123` `migrateLegacyPersonaTokens` check, did not
un-skip anything.

Step 3.1b added a new "Debug spec on 2-FAIL-cap escalation" bullet to
`agents/spec-master.md` (end of the bullet list, after "Convergence
follow-ups") — deliberately did NOT add a new mattpocock skill (e.g. no
`<MATTPOCOCK:diagnose>`); it reuses spec-master's existing
Read/Grep/Glob/Bash and the taxonomy/constitution/self-check machinery
already in the file. Commit 736a971 (first pass) got FAILed by reviewer
and fixed in commit adb59bc: **there is only ONE `.fail` record per
task-id, ever** — `.claude/reviewed/<task-id>.fail` is a single path, a
second FAIL overwrites the first, no append/rotation/`.fail.N` mechanism
exists anywhere in persona-protocol. My first draft wrongly claimed
spec-master reads "two durable FAIL records" and "synthesizes across
both" — not representable, and contradicted the file's own pre-existing
single-record `.fail` check bullet (line 104). Corrected shape: debug
spec reads the SINGLE latest `.fail` record plus `git log`/`git diff`
over the unit's fix-attempt commits (one lead-programmer commit per
attempt) to reconstruct what changed between tries. **Load-bearing for
later Track 3 steps**: Step 3.2 (task-master) and Step 3.5-ish
(orchestrator FAIL-routing) must NOT assume multiple `.fail` files
exist either — any wording there should also say "single latest record +
commit history," not "records" plural, or it'll repeat this same defect.

**Step 3.5 done (commit 78ab467, issue #23):** both `agents/orchestrator.md`
and `.claude/agents/orchestrator.md` rewritten — zero `hivemind` refs left.
Gotcha hit and fixed: the new "task-master model routing" heading originally
read `### \`task-master\` model routing` (persona name backticked) which
broke the acceptance grep for the literal substring `task-master model
routing` (the backtick sits between the two words) — headings that must
satisfy a literal-substring grep should NOT backtick-wrap only part of the
matched phrase; dropped the backticks entirely (matches the plain-text style
of the sibling `### Opus|Fable routing for...` heading anyway). The 2-FAIL-cap
debug-spec routing landed as new prose directly under "Review routing — you
are the single owner" (right after the point-4 normal-FAIL sentence), not a
new top-level section — that's where the file's only prior 2-FAIL-cap
mention lived. Both `.claude/agents/orchestrator.md` and `agents/orchestrator.md`
are byte-identical except for the ADAPT-substituted header comment on line 7
of the `.claude/` copy — cheapest way to keep them in sync for a full-file
rewrite is to finish editing the `agents/` copy first, Read it back, then
Write the `.claude/` copy as that same body with the header line inserted,
rather than repeating every Edit twice.

**Step 4.2 done (commit ef40679, issue #30):** added "Reviewer roast-work
advisory pass (fable heavy-lifting)" as a new `###` subsection to both
orchestrator.md copies, placed right after the existing `### task-master
model routing` subsection (same "model-routing area" as the Opus|Fable
routing subsections). `agents/task-master.md`/`.claude/agents/task-master.md`
needed NO edit — the `Roast pass: fable` tag documentation was already
present from Step 3.2's original authoring (description field + a dedicated
"Optional `Roast pass: fable` tag" bullet); don't re-add it if dispatched
again. **Gotcha hit:** `tests/validate.sh`'s "optional-persona references
must be phrased conditionally" check is paragraph-scoped (blank-line
joined) and only fires on a literal backtick-wrapped occurrence of the
persona name, e.g. `` `reviewer` `` — a bare unbacktick'd "reviewer" in the
same prose never triggers it (that's why the pre-existing "Review routing —
you are the single owner" section, which says bare "reviewer" a dozen times
with no "if present" qualifier, has always passed). So the fix for a
tripped check is usually to drop the backticks around the persona name
rather than add a qualifier phrase — cheaper and matches existing style
better when the surrounding paragraph is clearly already scoped to reviewer
being present (e.g. describing reviewer's own frontmatter/behavior, not a
routing decision that depends on optionality).
