---
name: project_vendor_mattpocock_skills
description: Vendoring convention for mattpocock/skills content under skills/ — where provenance headers go and don't go
metadata:
  type: project
---

Plan `docs/plans/2026-07-15-vendor-mattpocock-skills.md` vendors 12
mattpocock/skills skills verbatim into `skills/<name>/`, pinned at upstream
SHA `e9fcdf95b402d360f90f1db8d776d5dd450f9234` (recorded in
`skills/THIRD-PARTY-NOTICES.md`). Step A.2 (#47, this repo's issue tracker is
GitHub issues on `Storreslara/AntiSlop`) vendored the 9 non-repoint skills;
Step A.3 (#49, 2026-07-15, commit 14a028c) vendored `to-spec`, `to-tickets`,
`code-review` with the `/setup-matt-pocock-skills` repoint — done, all
acceptance criteria + `resync-vendored-skills.sh --check` pass (script
already reports these 3 as `[VENDORED]`, no script edit needed). Step E.1
(#48, 2026-07-15, commit fee4cdf) landed
`docs/maintenance/resync-vendored-skills.md` +
`scripts/resync-vendored-skills.sh --check` (0 drift confirmed against the
9) — resequenced to run right after A.2/#57, not after Track D, and gates
Track B per task-master's dispatch note.

**Provenance header placement decision (corrected 2026-07-15, issue #57,
commit 78e2525):** Step A.2 originally prepended the header BEFORE the `---`
on every `SKILL.md` and `.md` companion, pushing frontmatter to line 3 —
this violated the repo's frontmatter-first convention (caught by fable
advisory review, fixed as a fast-follow, did not reopen A.2's PASS). Correct
placement, verified against `skills/pathfinder/SKILL.md` /
`skills/fail-triage/SKILL.md` and `.claude/agents/explorer.md`'s own
version-stamp comment:
- **`SKILL.md` files (have frontmatter):** header goes immediately after the
  closing `---`, no blank line before it, one blank line after it, then body.
- **`.md` companions (tests.md, mocking.md, HTML-REPORT.md, DEEPENING.md,
  DESIGN-IT-TWICE.md, ADR-FORMAT.md, CONTEXT-FORMAT.md):** none of these have
  their own YAML frontmatter — confirmed by inspection, not assumed. Header
  stays at the very top (line 1) since there's no frontmatter to protect.
  These files needed NO change in the #57 fix.
- **`hitl-loop.template.sh`:** still deliberately has no header at all (shebang
  must stay line 1). Unchanged, verified via empty `git diff`.

**Why:** the repo's own frontmatter-first constraint (documented for persona
`.md` files, applies identically to skills) requires `---` as literal byte 1
whenever a file has frontmatter; A.2's literal-but-wrong criterion ("each
SKILL.md starts with the header") didn't check position, only presence.

**How to apply:** if A.3's repoint work re-touches these files, preserve this
placement — header after `---` for files with frontmatter, header at top for
files without, no header on the `.sh`. Don't assume `head -c1 == '-'` is a
valid check for ALL 16 files, since it only holds for the 9 that actually
have frontmatter (see [[project_cli_update_testing]] for the general "verify
assumptions against disk" pattern in this codebase).

**E.1's drift-check implementation chose forward reconstruction over backward
stripping:** rather than stripping N lines off the local file and hoping the
count is right, `scripts/resync-vendored-skills.sh` fetches the upstream file
fresh and inserts the header at the documented position (after `---` for
`fm`, at top + blank line for `doc`, untouched for `raw`), then diffs that
reconstruction against the local file. This sidesteps a subtlety: upstream
SKILL.md files already have their own blank line after the closing `---`
(before the body) — the vendored header is inserted before that existing
blank, not instead of it, so `fm`-type files need only the header line
removed/inserted, never the blank line, while `doc`-type companions (no
frontmatter, upstream body starts at line 1 with no blank) need the header
line AND the following blank line handled since neither exists upstream.
Getting `fm` vs `doc` blank-line handling swapped is the exact bug the E.1
issue warned about ("spurious drift on every file").

**A.3 plan/issue defect found and resolved (2026-07-15, issue #49, commit
14a028c):** the issue's own mandated provenance-header sentence for the 3
repoint skills — quoted verbatim as `"Repointed `/setup-matt-pocock-skills`
references to antislop's native setup; otherwise verbatim."` — contains the
exact literal substring (`setup-matt-pocock-skills`) that the sibling
acceptance criterion greps for and requires zero occurrences of
(`grep -rniI 'setup-matt-pocock-skills' skills/to-spec skills/to-tickets
skills/code-review` — "returns 0" here means literal zero matches, the
consistent convention this plan uses for every other residual-check, e.g.
Step B.1/C.1/D.1's `<MATTPOCOCK...>`/`mattpocockSkills` absence checks —
NOT the shell exit code). Taken literally, both cannot be satisfied at once.
**Resolution applied:** paraphrased the header sentence to preserve meaning
and the required "repointed" keyword without the literal banned substring:
"Repointed the external Matt Pocock setup-wizard slash-command references to
antislop's native setup; otherwise verbatim." All 3 files verified 0 matches
for the residual-pointer grep post-edit. **How to apply:** if a future step
in this plan (or any plan) hands you a "verbatim quoted sentence" to insert
alongside a "must not contain string X" grep check, check for this exact
tension before writing — don't insert the quoted text blindly. Flag it in
the ready-for-review report rather than silently choosing an interpretation.
