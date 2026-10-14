# Skills audit follow-ups (slice `sfu`)

Status: DRAFT for approval. 4 Open Questions. Not dispatched.
Slug: `2026-10-14-skills-audit-followups`. Unit ids: `sfu-1` .. `sfu-5`. Criteria and verified payloads: `docs/plans/sfu-criteria/`.

## Goal

Close the non-blocking reviewer findings left by the skills-audit slice (umbrella #530, units skr-1..skr-11, issues #531-#541), after checking each finding against the tree at `ca6959b`. Each unit leaves the repo suite green. Findings that no longer hold, or that need no change, are listed with the reason and get no unit.

## Context

Input: the closing comments on #530-#541, collected and deduplicated, with every file:line re-checked at HEAD `ca6959b` (version 0.31.167).

Measured facts the steps rely on:

- `docs/plans/skr-criteria/skr-glossary.sh` passes at HEAD for all six retired skills. It cannot catch stale prose, because an appended "Archived originals ... `docs/archive/skills/<x>/`" pointer satisfies it while the sentence above still says the skill is live (CONTEXT.md:53-54, :520-529, :538, :552, :920). `skr-live-refs.sh` does not scan CONTEXT.md, `docs/persona-design-notes.md` or the wiki. The new criterion `sfu-criteria/sfu-claims.sh` anchors on the wrong phrase (count 0) and on the canonical phrase (count 1). Every one of its checks is red at HEAD (0 OK lines for each of sfu-1, sfu-2, sfu-3).
- Version-stamp-check mutants: all four reviewer mutants survive `tests/version-stamp-check.test.sh` at HEAD. Reproduced 2026-10-14 in a scratch copy: dropping the `^+` filter, dropping the `+++` exclusion, a regex grep in place of `grep -F`, and `"$new_ver"` in place of `"$cnew"` each left the suite at exit 0.
- Prototype of sfu-4, verified in a scratch copy. The rewritten `changelog_adds_version` (payload `sfu-criteria/sfu-4-function-after.txt`), 7 new cases and 6 in-suite mutation controls (`sfu-4-test-cases.txt`, `sfu-4-mutation-controls.txt`) give a suite at exit 0, and every new mutation control reports its case flipping. The new script still reports `ok touched: yes old: 0.31.162 new: 0.31.167` on the real range `e9a2bf3~1..879c678`, the same verdict as the HEAD script.
- `node bin/cli.js --update --force-render --dry-run` in a scratch copy with an edited `hooks/scripts/version-stamp-check.sh` reports that the `.claude/hooks/scripts/version-stamp-check.sh` mirror would be updated and `.claude/persona-config.json` rewritten (fileHashes). So the hook mirror is refreshed without a version bump.
- Relative markdown links. A scan of tracked `.md` files, resolving each link against the linking file's own directory and checking it against the tracked-file set, finds 55 broken links in maintained docs at HEAD:
  - `docs/harness-glossary.md`: 45, all written root-relative since the item03 split (42 `](docs/adr/`, 3 `](.claude/wiki/`). This includes the ADR-0041 link the #541 reviewer asked about.
  - `.claude/wiki/modules/hooks.md`: 7, `../../` that should be `../../../`. One of them is a placeholder `00NN-marker-commit-attribution.md` for `0023-marker-commit-attribution.md`.
  - `CONTEXT.md:501`: links `0010-haiku-as-default-implementer-model.md`, but the file is `0010-implementer-haiku-default.md`.
  - `docs/adr/0020-write-edit-content-not-scanned.md:76-77`: link per-clone `.fail`/`.pass` review records that are never tracked.

  Outside maintained docs (report only): rendered `.claude/agents/*.md` 18 (the protocol block's `../docs/` is relative to `templates/`), `adapters/cursor` 2, `docs/plans` 15. The prototype test `sfu-criteria/sfu-5-doc-relative-links.test.js` reports exactly the 55 at HEAD.
- Prototype `sfu-criteria/sfu-5-resync-vendored-skills-offline.test.sh` passes at HEAD (22 OK lines). Three mutants of `scripts/resync-vendored-skills.sh`, each run in a scratch git copy, make it fail: a forked row pointed at the live file, a renamed local file, and a skill dropped from SKILL_ORDER.
- ADR convention: ADR-0041's own Related section calls ADR-0003 and ADR-0022 "historical ... not edited in place". Decision changes go through a new ADR or an `## Amendments` section (ADR-0040:108). Factual misstatements have been corrected in place (ADR-0039 line count, commit 2c3f3c4). Neither ADR-0041 error changes the decision, so sfu-1 corrects them in place and records the correction in a dated `## Corrections` section (see Clarifications 7).
- Prior FAIL history: no `.fail` record exists for any skr unit (all eleven have only `.pass`). The `bin/marker-audit.sh --notes --surface=<path>` sweep over the touched paths did not finish within 300 s and ran in the background, so its results are not reflected here. Recorded as a Risk (R5). An empty or absent sweep proves nothing.

### Verified in-scope findings (deduplicated)

| # | Finding (source issue) | Verified at HEAD | Unit |
|---|---|---|---|
| F1 | CONTEXT.md persona entry: spec-master "publishes via `to-spec`", task-master "owns `to-tickets` slicing" (#533, #534) | yes, :52-54 | sfu-1 |
| F2 | CONTEXT.md `to-spec` skill entry body in present tense ("wired to ... Turns ...") (#533) | yes, :521-529 | sfu-1 |
| F3 | CONTEXT.md fast-path "`task-master` and `to-tickets` are bypassed" (:538); publish threshold "`to-spec` PRD template" (:552) (#533) | yes | sfu-1 |
| F4 | CONTEXT.md FAIL record "read by `fail-triage`/debug spec" (#533) | yes, :920 | sfu-1 |
| F5 | Missing glossary entries: forked skill / fork-and-own, PRD template, debug spec, self-grill, Open Questions, work the frontier, expand-contract, retired skill (+ archive "disposition" column), skill base directory (#531, #533, #534, #536, #537, #538, #539, #541) | yes, no heading for any | sfu-1 |
| F6 | docs/harness-glossary.md :977-984 "description collision": "both are drift-tracked skills" in present tense (#541) | yes | sfu-1 |
| F7 | docs/harness-glossary.md :1628-1630 "Now that these SKILL.md files are tracked/shipped ... should be fixed" next to "are retired" (#531) | yes | sfu-1 |
| F8 | docs/harness-glossary.md :1846 code-review archive pointer sits in the "Function location" entry, which names the code-review *graph* (#536) | yes. The pointer is there because `skr-glossary.sh`'s pattern matches "code-review graph" | sfu-1 (reworded, not deleted, so `skr-glossary.sh code-review` stays green) |
| F9 | ADR-0041 title "Retire five skills" vs Decision 1 retiring ten; Decision 3 "Nothing loads, lists, mirrors, hashes or ships that directory" vs ADR-0022 (the git/marketplace path carries the full tree) (#541) | yes | sfu-1 |
| F10 | Same "ships" over-claim in CONTEXT.md **Archived skill** entry (:641) and `docs/archive/skills/README.md:3` | yes (found while verifying F9) | sfu-1 (CONTEXT), sfu-2 (README) |
| F11 | docs/persona-design-notes.md :48, :72, :77 describe `to-spec`/`to-issues`/`to-tickets` as live (#533, #534, #541) | yes | sfu-2 |
| F12 | docs/trust-model.md:63 row 25 describes only the version-bump half (#535) | yes | sfu-2 |
| F13 | skills/THIRD-PARTY-NOTICES.md:29 names only `tdd` as forked; table rows numbered 2-11 (#532, #537, #541) | yes. No file refers to the row numbers | sfu-2 |
| F14 | docs/maintenance/resync-vendored-skills.md :14 (`grilling`) and :16 (`tdd`) say "verbatim"; re-pin step 4 prescribes a project-wide find/replace, which would rewrite archived originals and miss forked live headers (`e9fcdf9`) (#536, #537) | yes | sfu-2 |
| F15 | skills/grilling/SKILL.md :16 vs :21: self-grill has no one to return a decision to (#537) | yes | sfu-2 |
| F16 | skills/install-antislop/SKILL.md :313-314 prescribes a `jq` check of the persona config (refused by harness-integrity-gate); :213 (`--wire-arxiv-mcp`) lacks the Read-tool pointer its twin at :152 has (#539) | yes; `.claude/skills/install-antislop/` is a byte mirror | sfu-2 |
| F17 | skills/pathfinder/SKILL.md:48 reads the tracker from `issueTracker` but :50 hardcodes `.scratch/<feature-slug>/issues/`; install-antislop :275/:283 uses `docs/plans/<slug>/issues/` (#534) | yes (line numbers moved from :27/:29 to :48/:50) | sfu-2 |
| F18 | skills/roast-work/SKILL.md output-shape paragraph (:35-39) no longer says it never determines PASS/FAIL (Codex/Cursor ports lean on it, ADR-0004 Tension 1) (#540) | yes | sfu-2 |
| F19 | skills/improve-codebase-architecture/SKILL.md:18 "You run as a one-shot subagent" while agents/scribe.md:24-25 invokes it through the Skill tool (#538) | yes | sfu-2 |
| F20 | "CHANGELOG line" (agents/lead-programmer.md:98-99, agents/scribe.md:47-48, agents/reviewer.md:122, skills/version-stamp-discipline/SKILL.md:30,32, CONTEXT.md:150) vs canonical "CHANGELOG entry" (CONTEXT.md:133) (#535) | yes | sfu-3 |
| F21 | agents/lead-programmer.md:54-56 TDD-first says "follow the preloaded `antislop:tdd` loop" with no fallback for agent-teams mode, where `skills:` preloads are not applied (#536) | yes. The inlined protocol's teammate bullet attaches its "read its SKILL.md directly" remedy to `disable-model-invocation` skills, not to preloads | sfu-3 |
| F22 | Version-stamp-check: case (d) does not pin the Half-2 defect; three more surviving mutants; `git diff` lacks `--no-color --no-ext-diff` (hooks/scripts/version-stamp-check.sh:65); substring match (0.31.16 matched by 0.31.166) (#535) | yes, all four mutants reproduced | sfu-4 |
| F23 | No offline test for scripts/resync-vendored-skills.sh FILES/SKILL_ORDER (#532, #539) | yes | sfu-5 |
| F24 | No test for ADR cross-links / the glossary's link to ADR-0041 (#541) | yes, and wider: 55 broken links (Context) | sfu-5 (scope = Open Question 1) |
| F25 | agents/spec-master.md:301 MIT credit omits the copyright line in a consumer's rendered copy (#533) | yes. The line cites `skills/THIRD-PARTY-NOTICES.md`, which a consumer repo does not have | sfu-3 (Open Question 4) |

### Findings that get no unit

- `.claude/wiki/dependencies.md:21,:23` (stale `to-tickets` / `code-review`): **already fixed** by skr-11; the bullet now reads historically and cites ADR-0041.
- docs/harness-glossary.md:1662 drift-tracked skills entry (`REPOINT_SKILLS` live, tdd byte-diffed): **already fixed** by skr-11 (:1663-1674).
- `docs/archive/skills/README.md` source commit `7adddc1` vs parent `4ed8fc9` (#532): accurate as written. `skr-archive-verify.sh` passes for every row at HEAD, so the archived bytes equal the tree at `7adddc1`. No change.
- skills/ubiquitous-language/SKILL.md Prose mode dropped "auditing a plan's prose" and the "## Context" anchor example (#540): no consumer or test reads the dropped text, `milestone-auditor` is still named as a consumer, and the "Step 3" anchor example still shows the form. No change.
- improve-codebase-architecture grilling-loop rules condensed (#538): both rules ("create CONTEXT.md lazily", "offer ADRs sparingly") are stated in `skills/domain-modeling/SKILL.md`, which the later grilling dispatch uses. No change.
- agents/spec-master.md:300-352 PRD template headings are `##` siblings of the appendix heading (#533): set by the skr-3 plan (AC7), with no functional effect. Changing it would cost a version bump for nothing. No change.
- Scribe AC12 / lead-programmer AC4 of skr-11 are HEAD-relative (#541): a lesson for criteria, applied here. Every per-unit `version-stamp-check.sh` criterion below takes its range from the unit's own commit, found by subject, not from `HEAD~1`.
- docs/harness-glossary.md:1541 (`to-tickets`) and :1610-1620 (fm-noflag set): dated measurement/history entries that already carry a supersession note. No change.

### Unverified (not in scope)

- The `bin/marker-audit.sh --notes` sweep results for the touched paths (the run timed out at 300 s; see R5).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-14 Functional scope & success criteria: Q Which reviewer findings enter the slice? → A (self-resolved): only findings that still hold at `ca6959b` and need a change (F1-F25); the rest are listed under "Findings that get no unit" with the reason. The link-check breadth stays open as Open Question 1.
- 2026-10-14 Domain entities / data model: Q Which new terms get glossary entries, and where? → A (self-resolved): eight domain entries in CONTEXT.md (Retired skill, Forked skill with synonym fork-and-own, PRD template, debug spec, self-grill, Open Questions, work the frontier, expand-contract), plus one harness entry in docs/harness-glossary.md (skill base directory). The archive "disposition" column is defined inside **Retired skill**, not as its own term.
- 2026-10-14 External dependencies & integrations: Q Can the runbook's re-pin procedure handle forked skills? → A (self-resolved): no. An archived copy stays byte-identical to the commit its README row names, and a re-pinned copy never matched any commit. sfu-2 states this limitation and forbids a project-wide replace. Designing a forked-skill re-pin is out of slice.
- 2026-10-14 Edge cases / failure handling: Q Is the `+++` exclusion mutant killable? → A (self-resolved): no, it is an equivalent mutant. The header line is always `+++ b/CHANGELOG.md` or `+++ /dev/null`, and with the boundary rule a version cannot match inside it. No fixture is added for it; the plan records why. The substring boundary itself is Open Question 2.
- 2026-10-14 Technical constraints & tradeoffs: Q Does fixing ADR-0041's title and Decision 3 wording need an amendment ADR rather than an in-place edit? → A (self-resolved): in-place edit plus a dated `## Corrections` section. Both are factual misstatements of the ADR's own content (the count of skills retired; the npm-only reach of ADR-0022), not a change of decision. Precedent: ADR-0039 corrected in place (2c3f3c4). Amendment sections (ADR-0040) and new ADRs are for changed decisions. Other ADRs stay untouched; the ADR-0020 link edit in sfu-5 changes only markdown link syntax, and only if Open Question 1 = A.
- 2026-10-14 Technical constraints & tradeoffs: Q Which units owe the P3 version bump? → A (self-resolved): only sfu-3, the one unit that edits `agents/*.md` (0.31.167 -> 0.31.168, `.claude-plugin/plugin.json` + `package.json` + CHANGELOG entry naming it, then `node bin/cli.js --update --force-render`). sfu-4 edits a hook, not a version-stamped path. It still runs `node bin/cli.js --update --force-render` to refresh the `.claude/hooks` mirror and fileHashes (measured, Context).
- 2026-10-14 Terminology consistency: Q "CHANGELOG line" or "CHANGELOG entry"? → A (self-resolved): "CHANGELOG entry", the canonical glossary term (CONTEXT.md:133). sfu-3 renames every live "CHANGELOG line", riding the version bump that sfu-3 already owes. CONTEXT.md:150 says how an entry is detected ("an added CHANGELOG.md line naming the version"), so "line" stays a description and never becomes a synonym.

## Risks / dependencies

- R1. Strict chain sfu-1 -> sfu-2 -> sfu-3 -> sfu-4 -> sfu-5. `CHANGELOG.md` is shared by every unit; `CONTEXT.md` by sfu-1, sfu-3 and sfu-5. sfu-5's link test needs every earlier unit's text final, and new prose in sfu-1/sfu-2 adds no markdown links except root-correct ones in CONTEXT.md.
- R2. `tests/harness-integrity-gate.test.sh` C4.1 sweeps `git grep -l` for four fixed gate phrases (its `c41_pattern`) across the whole tree, including `docs/plans/`. No new text in this slice or in this plan may contain them. This plan was written to avoid them.
- R3. Gates on command text. A Bash command naming the persona config is refused by `harness-integrity-gate.sh`, so stage `.claude` changes with `git add -u .claude`, never by naming that file. A Bash command spelling the per-clone review-record directory is refused by `reviewed-path-gate.sh`, so sfu-5's ADR-0020 edit is an Edit-tool before/after, never a sed.
- R4. `tests/validate.sh` exceeds the 600 s Bash cap serially. Use `bash docs/plans/skr-criteria/skr-core.sh` (3.5 s at HEAD) and the unit criteria. `bash tests/validate-lanes.sh --lanes 6` is the full-suite check. Leave `tests/validate-lanes*`, `tests/reviewed-dir-leak-guard.test.sh`, `docs/plans/epfd-criteria/`, `docs/plans/lgc-criteria/` and `docs/plans/vlg-criteria/` alone.
- R5. The marker-audit `--notes` sweep for the touched paths did not finish inside 300 s, so its results are not in this plan. Before dispatch, task-master or the orchestrator re-runs `bash bin/marker-audit.sh . --notes --surface=<path>` for the paths in the Steps below and records any `NOTE[spec]` line. An empty sweep proves nothing (`.claude/reviewed/` is per-clone).
- R6. Contract-guard demotion (see Report-only 1). Issue bodies with a prose preamble before `Unit:` score `reason=no-contract`. On the fast path the guard reads this plan file, so each contract must sit in a fenced block whose first interior line is `Unit: sfu-N`. The outer fence must be `~~~~` (four tildes), because the payloads use `~~~`.
- R7. Commit trailer: the per-unit criterion greps only `^Co-Authored-By: Claude `. The orchestrator supplies the tier's own attribution line at dispatch, per agents/task-master.md:210 ("the exact trailer line the dispatch gives").
- R8. The Open Question answers change sfu-3, sfu-4 and sfu-5 content. The nine-element fast-path contracts are written in the re-delegation round after the answers, from the payloads already verified in `docs/plans/sfu-criteria/`. Each contract is scored with `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-followups.md --unit=sfu-N` before handoff.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every in-scope finding was re-checked at HEAD. The sfu-4 and sfu-5 payloads were run in a scratch copy, and sfu-claims.sh was run red at HEAD.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors, fileHashes and rendered agents come only from `node bin/cli.js --update --force-render`; nothing hand-edits `.claude/persona-config.json`.
- P3 "Version-stamp discipline": satisfied. sfu-3 is the only unit touching `agents/*.md`, and it bumps 0.31.167 -> 0.31.168 with a same-commit CHANGELOG entry. No unit touches `templates/`.
- P5 "`tests/validate.sh` is the merge gate": deviation. Units gate on `skr-core.sh` plus their own criteria, because the serial suite exceeds the 600 s Bash cap. The full suite runs once per unit as `bash tests/validate-lanes.sh --lanes 6`, the same lane runner the skr reviewers used.

## Steps

Every unit ends with one commit, staged by explicit path. The subject prefix is `docs(sfu-N)`, `fix(sfu-N)` or `test(sfu-N)`, as shown in each step. Common criteria for every unit (C = `git log -1 --format=%H -F --grep='(sfu-N): '`):
- `bash hooks/scripts/version-stamp-check.sh $C~1..$C` prints `ok touched: no`, except sfu-3, which prints `ok touched: yes old: 0.31.167 new: 0.31.168`.
- `bash docs/plans/skr-criteria/skr-core.sh` exits 0 and prints `skr-core: ok`.
- `bash docs/plans/skr-criteria/skr-glossary.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage` and `bash docs/plans/skr-criteria/skr-live-refs.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage` exit 0. Both are green at HEAD and must stay so.
- `git log -1 --format=%B $C | grep -c '^Co-Authored-By: Claude '` prints 1.
- `git diff --quiet HEAD -- <the unit's own files>` exits 0.

### Step 1 (sfu-1): glossary and ADR-0041 corrections. Lead-programmer, no version bump

Implementer: lead-programmer, as in skr-1, which edited CONTEXT.md and the harness glossary under a lead contract. The text of every entry is fixed in the contract, so no domain judgment is delegated.

Affected files: `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`, `CHANGELOG.md`.

Edits:
1. CONTEXT.md:52-54. spec-master "publishes through its own [[PRD template]] appendix (formerly the `to-spec` skill)"; task-master "owns slicing through the `pathfinder` skill". The entry must not newly name `to-tickets`, because its only archive pointer is for `to-spec`.
2. CONTEXT.md:521-529. Rewrite the `to-spec` skill entry body in the past tense ("was wired ... turned ..."), ending "it lives on as the [[PRD template]]". The retirement lines (:530-533) stay.
3. CONTEXT.md:538. "`task-master` and its `pathfinder` slicing are bypassed".
4. CONTEXT.md:552. "plan onto its [[PRD template]]".
5. CONTEXT.md:920-921. "Read by `bin/fail-count.sh` and by `spec-master`'s [[debug spec]] when a unit reaches [[ladder exhaustion]] (formerly the `fail-triage` skill)". The pointer line :922 stays.
6. CONTEXT.md:641 (**Archived skill**). Replace "Nothing loads, lists, mirrors, hashes or ships it." with "No skill loader discovers it and nothing lists, mirrors or hashes it; the npm package ships no `docs/` path, while a git clone or plugin install carries it as inert files."
7. CONTEXT.md, insert after the **Archived skill** entry's last line (`  still live).`, :644) the eight entries below. Texts are drafted in this plan's Clarifications domain decisions and finalized verbatim in the contract.
   - **Retired skill**: defines the archive disposition values retired / merged away / rewritten / trimmed / forked.
   - **Forked skill** (synonym: **fork-and-own**): live file edited with a "Derived from" header; drift tracked on the archived original; upstream ported by hand; contrasted with a declared deviation; the set of four; root-relative link to ADR-0041.
   - **PRD template**: its sections, where it lives, and that it layers on the plan format.
   - **debug spec**: the 2-FAIL-cap artifact. It ends "Formerly the `fail-triage` skill (original: `docs/archive/skills/fail-triage/`)", so `skr-glossary.sh fail-triage` stays green.
   - **self-grill**: an undecided decision becomes a finding.
   - **Open Questions**: the one-shot return contract (up to 4 per round, recommended defaults, the orchestrator relays, repeat until converged).
   - **work the frontier**.
   - **expand-contract**: wording taken from skills/pathfinder/SKILL.md:56.
8. docs/harness-glossary.md:977-984 (**description collision**). Change to past tense ("could not", "were then", "was").
9. docs/harness-glossary.md:1628-1630. "While these SKILL.md files were tracked/shipped, the gap was more visible; any fix belongs in the installer itself."
10. docs/harness-glossary.md:1846. Replace the pointer line with "Not the retired `code-review` skill, a different tool (original: `docs/archive/skills/code-review/`)."
11. docs/harness-glossary.md, insert after the **drift-tracked skills** entry (anchor: the line ending "No `REPOINT_SKILLS` remain. See `docs/maintenance/resync-vendored-skills.md`.") the **skill base directory** entry. The harness announces the directory as "Base directory for this skill: <path>"; companion files such as `scripts/hitl-loop.template.sh` resolve against it, not against the working directory. Use no markdown link.
12. ADR-0041:1. "Retire five skills" -> "Retire ten skills".
13. ADR-0041:16 (Decision 3), last sentence. "No skill loader discovers that directory and nothing lists, mirrors or hashes it; the npm package ships no `docs/` path, while a git clone or plugin install carries it as inert files (ADR-0022)."
14. ADR-0041, append `## Corrections` with one line: "- 2026-10-14 (unit sfu-1): the title said five skills while Decision 1 retires ten, and Decision 3 said nothing ships the archive, overstating ADR-0022's npm-only exclusion. Both corrected in place; the decision is unchanged."
15. CHANGELOG.md, an entry under `## [Unreleased]` naming sfu-1.
16. Commit `docs(sfu-1): glossary entries, stale skill references and ADR-0041 corrections (#530 follow-up)`.

Acceptance criteria:
- `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-1`: exit 0, last line `sfu-claims: sfu-1 ok`. Mutation: skip edit 12 -> `Retire five skills` count 1, exit 1. Red at HEAD (0 OK lines).
- `node tests/context-glossary-links.test.js`: exit 0. Mutation: write `[[PRD templates]]` in edit 4 -> exit 1.
- `node tests/ubiquitous-language.test.js`: exit 0. It guards the skill file, which this unit must not touch.
- The common criteria.

### Step 2 (sfu-2): docs and skill prose. Lead-programmer, no version bump

Affected files: `docs/persona-design-notes.md`, `docs/trust-model.md`, `skills/THIRD-PARTY-NOTICES.md`, `docs/maintenance/resync-vendored-skills.md`, `docs/archive/skills/README.md`, `skills/grilling/SKILL.md`, `skills/install-antislop/SKILL.md`, `.claude/skills/install-antislop/SKILL.md` (copied with `cp`), `skills/pathfinder/SKILL.md`, `skills/roast-work/SKILL.md`, `skills/improve-codebase-architecture/SKILL.md`, `CHANGELOG.md`.

Edits:
1. persona-design-notes.md:47-48. "publishing through its own PRD-template appendix; ticket-slicing (the `pathfinder` skill)".
2. persona-design-notes.md:72. "task-master owns slicing through the `pathfinder` skill".
3. persona-design-notes.md:77. "publishing through its PRD-template appendix".
4. trust-model.md:63 row 25. "...bumped `.claude-plugin/plugin.json`'s version in each commit that touched it, and added a CHANGELOG entry naming the new version in that same commit (constitution P3 / version-stamp discipline)".
5. THIRD-PARTY-NOTICES.md:29. Replace "`tdd` is forked: its live file carries ... archived original." with "`grilling`, `tdd`, `diagnosing-bugs` and `improve-codebase-architecture` are forked: each live file carries a "Derived from" header and antislop edits, and drift tracking moves to the archived original."
6. THIRD-PARTY-NOTICES.md. Renumber the table rows contiguously 1-10 with one `python3 -c` command whose expect is 0.
7. resync runbook :14 and :16. Shape `forked (rows diff the archived copy)`, matching :17-18.
8. resync runbook step 4 (:121-126). Keep "update the SHA in `skills/THIRD-PARTY-NOTICES.md`", restricted to the prose sentence and the headers of the live files the FILES table names under `skills/`. Add: "Do not run a project-wide find/replace: archived originals under `docs/archive/skills/` stay byte-identical to the commit their README row names, and a forked skill's live "Derived from" header (short SHA) changes only when an upstream change is ported by hand (step 3). Re-pinning a forked skill's archived copy is not covered by this runbook; stop and raise it." The phrase "vendors 7 skills" at :3 must stay (sfu-5's test reads it).
9. archive README:3. Same narrowing as sfu-1 edit 6.
10. grilling SKILL.md:21. Append "In a self-grill there is no one to ask, so an undecided decision becomes a finding, like an unanswerable question."
11. install-antislop SKILL.md:213. "`persona-config.json` (inspect it with the `Read` tool, because a Bash command naming that file can be refused by `harness-integrity-gate.sh`; the file is created with just that field if step 6 hasn't".
12. install-antislop SKILL.md:313-314. Replace "(a `jq` check that every required key is present and typed correctly)" with "(read it with the `Read` tool and check that every required key is present and typed correctly; a Bash command such as `jq` naming that file can be refused by `harness-integrity-gate.sh`)".
13. `cp skills/install-antislop/SKILL.md .claude/skills/install-antislop/SKILL.md`.
14. pathfinder SKILL.md:50. "write one file per unit under the directory the `issueTracker` line names (if it names none, `.scratch/<feature-slug>/issues/`), as `<NN>-<slug>.md`, numbered ...".
15. roast-work SKILL.md:39. After "entries are blocking defects, no matter how sharply worded." add "It never determines PASS/FAIL: the acceptance-criteria commands and the materiality filter remain the only gate."
16. improve-codebase-architecture SKILL.md:18. "Whether you run as a one-shot subagent or are invoked through the `Skill` tool inside another persona's turn, you cannot ask a question, open a browser or wait for a reply."
17. CHANGELOG entry; commit `docs(sfu-2): skills and docs prose follow-ups from the skills audit (#530 follow-up)`.

Acceptance criteria:
- `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-2`: exit 0, last line `sfu-claims: sfu-2 ok`. Mutation: skip edit 10 -> exit 1. Red at HEAD.
- `diff -rq skills/install-antislop .claude/skills/install-antislop`: exit 0, empty. Mutation: skip edit 13 -> exit 1.
- `grep -oE '^\| [0-9]+ \|' skills/THIRD-PARTY-NOTICES.md | tr -dc '0-9\n' | paste -sd' '`: prints `1 2 3 4 5 6 7 8 9 10`. Mutation: skip edit 6 -> `2 3 4 5 6 7 8 9 10 11`.
- `bash docs/plans/skr-criteria/skr-archive-verify.sh grilling`: exit 0. The archive copies are untouched.
- `node tests/adapter-skill-parity.test.js`: exit 0.
- The common criteria.

### Step 3 (sfu-3): agents. TDD fallback, "CHANGELOG entry", MIT line. Lead-programmer, version bump 0.31.168

Affected files: `agents/lead-programmer.md`, `agents/scribe.md`, `agents/reviewer.md`, `agents/spec-master.md` (only if Open Question 4 = include), `skills/version-stamp-discipline/SKILL.md`, `CONTEXT.md`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`. Rendered by `node bin/cli.js --update --force-render`: `.claude/agents/*.md`, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, `.claude/persona-config.json`.

Edits:
1. lead-programmer.md:55-56. "(write the failing test first; in agent-teams mode, where `skills:` preloads are not applied, read the `tdd` skill's `SKILL.md` once before the first test)". Must not match `skr-live-refs.sh tdd-skill-invoke`.
2. "CHANGELOG line" -> "CHANGELOG entry" at lead-programmer.md:98, :99; scribe.md:47, :48; reviewer.md:122; version-stamp-discipline SKILL.md:30, :32.
3. CONTEXT.md:150. "requires a same-commit CHANGELOG entry naming it (detected as an added CHANGELOG.md line that names the version)".
4. (Open Question 4 = include) spec-master.md:301. "Derived from mattpocock/skills (MIT, Copyright (c) 2026 Matt Pocock; full license text in the antislop plugin's `skills/THIRD-PARTY-NOTICES.md`)".
5. `.claude-plugin/plugin.json` "version": "0.31.167" -> "0.31.168"; `package.json` "version": "0.31.167" -> "0.31.168".
6. A CHANGELOG entry naming `0.31.168`.
7. `node bin/cli.js --update --force-render`, expect 0.
8. `git add agents skills/version-stamp-discipline CONTEXT.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u .claude && git commit ...`. Subject: `fix(sfu-3): agent-teams TDD fallback and CHANGELOG entry wording (0.31.168) (#530 follow-up)`.

Acceptance criteria:
- `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-3`: exit 0. Mutation: skip edit 7 -> the `.claude/agents/lead-programmer.md` check fails.
- `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;if(a!==b||a!=='0.31.168')process.exit(1);console.log('version-sync: ok')"`: prints `version-sync: ok`.
- `node bin/cli.js --update --force-render --dry-run | grep -c 'would be'`: prints 0, exit 1. Mutation: skip edit 7 -> count > 0.
- `bash docs/plans/skr-criteria/skr-live-refs.sh tdd-skill-invoke vsd-preload`: exit 0.
- `node tests/adapter-skill-parity.test.js` and `node tests/filehashes-currency.test.js`: exit 0.
- If Open Question 4 = include: `tr -s '\n ' ' ' < agents/spec-master.md | grep -cF 'Copyright (c) 2026 Matt Pocock'` prints 1.
- The common criteria, with the sfu-3 stamp line.

### Step 4 (sfu-4): version-stamp-check hardening. Lead-programmer, TDD, no version bump

Affected files: `hooks/scripts/version-stamp-check.sh`, `tests/version-stamp-check.test.sh`, `CHANGELOG.md`. Rendered: `.claude/hooks/scripts/version-stamp-check.sh` and `.claude/persona-config.json` fileHashes (via `node bin/cli.js --update --force-render`).

Edits (payloads verified in a scratch copy, all in `docs/plans/sfu-criteria/`):
1. Test first. Insert `sfu-4-test-cases.txt` after the line `expect_offender "(d) names the earlier commit" ...`. Insert `sfu-4-mutation-controls.txt` before `echo "-- offender collection is computed, not hardcoded (item 5) --"`. The suite must then fail: (f), (g), (h1), (h2) and (i) are red against the HEAD script, and mc8-mc13 seds match nothing.
2. Replace the block in `sfu-4-function-before.txt` with `sfu-4-function-after.txt` (hooks/scripts/version-stamp-check.sh:59-67). This adds `--no-color --no-ext-diff`, takes added lines only, matches the version literally, and adds the boundary rule (Open Question 2).
3. Header comment :19-23. "containing, as a fixed string," -> "naming, as a whole version (see changelog_adds_version),".
4. `node bin/cli.js --update --force-render`, expect 0.
5. CHANGELOG entry; commit `fix(sfu-4): version-stamp-check CHANGELOG match hardening (#530 follow-up)`.

Acceptance criteria:
- `bash tests/version-stamp-check.test.sh`: exit 0. Output contains `OK   (mc12)` and `OK   (mc13)`. Mutation: revert edit 2 -> (f), (g), (h1), (h2), (i) and mc8-mc13 FAIL, exit 1.
- `bash tests/version-stamp-check.test.sh | grep -cE '^OK   \((e|f|g|h1|h2|h3|i|mc8|mc9|mc10|mc11|mc12|mc13)\)'`: prints 13.
- `bash hooks/scripts/version-stamp-check.sh e9a2bf3~1..879c678`: prints `version-stamp-check: ok touched: yes old: 0.31.162 new: 0.31.167 offenders: -`. Real history is unchanged.
- `diff -q hooks/scripts/version-stamp-check.sh .claude/hooks/scripts/version-stamp-check.sh`: exit 0. Mutation: skip edit 4 -> exit 1.
- The common criteria.

If Open Question 2 = keep: drop the two lookarounds from the payload, drop cases (h1), (h2), (h3) and controls mc10 and mc11, and the count above becomes 9.

### Step 5 (sfu-5): offline resync test and relative-link test. Lead-programmer, TDD, no version bump

Affected files: `tests/resync-vendored-skills-offline.test.sh` (new, content `sfu-criteria/sfu-5-resync-vendored-skills-offline.test.sh`), `tests/doc-relative-links.test.js` (new, content `sfu-criteria/sfu-5-doc-relative-links.test.js`), `tests/validate.sh` (two sections inserted after the `context-glossary-links` section at :921-928), `CHANGELOG.md`. If Open Question 1 = A, also `docs/harness-glossary.md`, `.claude/wiki/modules/hooks.md`, `CONTEXT.md` and `docs/adr/0020-write-edit-content-not-scanned.md`.

Edits:
1. Create both tests. Running the link test at this point prints `doc-relative-links: 55 broken of ...` and exits 1, so it starts red.
2. (Open Question 1 = A) Fix the links:
   - docs/harness-glossary.md: `](docs/adr/` -> `](adr/` (42 sites) and `](.claude/wiki/` -> `](../.claude/wiki/` (3 sites). One `python3 -c` command that asserts both counts first.
   - .claude/wiki/modules/hooks.md: `](../../` -> `](../../../` (7 sites), then `00NN-marker-commit-attribution` -> `0023-marker-commit-attribution` (1 site).
   - CONTEXT.md:501: `0010-haiku-as-default-implementer-model.md` -> `0010-implementer-haiku-default.md`.
   - ADR-0020:76-77: an Edit-tool before/after that turns the two review-record links into plain code spans followed by "(per-clone review state, not tracked)".
3. Register both tests in tests/validate.sh in the existing `echo "== ... =="` / `if ...; then echo "OK   ..."; else echo "FAIL ..."; fail=1; fi` form.
4. CHANGELOG entry; commit `test(sfu-5): offline resync table test and relative-link test (#530 follow-up)`.

Acceptance criteria:
- `bash tests/resync-vendored-skills-offline.test.sh`: exit 0, last line `resync-vendored-skills-offline: ok`. Mutation: in a scratch git copy, point the `grilling:fm:` row at `skills/grilling/SKILL.md` -> exit 1 (verified).
- `node tests/doc-relative-links.test.js`: exit 0, line starts `doc-relative-links: ok`. Mutation: revert edit 2 -> 55 broken, exit 1 (verified at HEAD).
- `grep -cE 'tests/(doc-relative-links\.test\.js|resync-vendored-skills-offline\.test\.sh)' tests/validate.sh`: prints 6 (three lines per section). Mutation: skip edit 3 -> 0.
- `node tests/context-glossary-links.test.js`: exit 0.
- `bash tests/validate-lanes.sh --lanes 6`: exit 0.
- The common criteria.

If Open Question 1 = B, edit 2 shrinks to the one harness-glossary link to ADR-0041, and the test SCOPE becomes the files that link to ADR-0041. If C, the link test and edit 2 are dropped and sfu-5 holds only the resync test.

## Open Questions

1. **Relative-link check scope.** A test for the ADR-0041 links finds a wider defect: 55 broken relative links in maintained docs (45 in docs/harness-glossary.md, where every link is root-relative). Options:
   - **A (recommended).** Fix all 55 and add `tests/doc-relative-links.test.js` over CONTEXT.md, docs/harness-glossary.md, docs/trust-model.md, docs/adr, .claude/wiki, docs/maintenance, the archive README and skills/. The fixes are mechanical and verified to 0 in a scratch copy.
   - **B.** Fix only the ADR-0041 link and test only links to ADR-0041.
   - **C.** Defer; report only.

   (from CHK3)
2. **Version-stamp-check substring match.** At HEAD, bumping to 0.31.16 is satisfied by a CHANGELOG line naming 0.31.166. The skr-5 spec allowed this. Options:
   - **Close it (recommended).** A version may not continue into a digit on the right, or into a digit or dot on the left. `v0.31.16` and `(0.31.16)` still count. Verified with cases (h1)-(h3) and controls mc10/mc11; real history is unchanged.
   - **Keep it.** Leave the match as the skr-5 spec allowed.

   (from CHK4)
3. **Stale agent-memory notes.** `.claude/agent-memory/antislop-spec-master/feedback_resume_from_artifact.md:11` says "do not re-invoke `grill-me`". `.claude/agent-memory/spec-master/project_to_spec_slash_only.md` steers toward `antislop:to-spec`. Options:
   - **Owner fixes outside the slice (recommended).** spec-master retargets both notes in a `docs(agent-memory)` commit when re-delegated with these answers. Memory is per-persona state and not reviewed work.
   - **A scribe unit.**
   - **Leave them.**

   (from CHK5)
4. **MIT copyright line in spec-master's PRD-template credit.** A consumer's rendered spec-master.md cites `skills/THIRD-PARTY-NOTICES.md`, which a consumer repo lacks. Options:
   - **Include "Copyright (c) 2026 Matt Pocock" (recommended).** It rides sfu-3's version bump at no extra cost.
   - **Leave as is.**

   (from CHK6)

## Self-check
- CHK1: Does every Goal clause map to a step criterion? — PASS. Each F-row names its unit, and each unit's criteria cover its F-rows: sfu-claims.sh for F1-F21, the test counts for F22, and the two tests for F23-F24.
- CHK2: Is the vacuous-criteria risk for prose units addressed (criteria that pass whether the prose is true or not)? — PASS. sfu-claims.sh is claim-anchored, and all of its checks were run red at HEAD.
- CHK3: Is the link-check scope decided? — FAIL (missing) — converted to Open Question 1
- CHK4: Is the substring behaviour of version-stamp-check decided? — FAIL (missing) — converted to Open Question 2
- CHK5: Is the disposition of the stale agent-memory notes decided? — FAIL (missing) — converted to Open Question 3
- CHK6: Is the MIT credit change in or out? — FAIL (missing) — converted to Open Question 4
- CHK7: Do steps 1 and 3 agree on CONTEXT.md:150? — PASS. Only step 3 edits :150, and step 1 does not list it.
- CHK8: Does each unit that touches agents/*.md satisfy P3 per commit? — PASS. Only sfu-3 does; it has the bump, the CHANGELOG entry, `--update --force-render`, and a criterion that runs version-stamp-check.sh over its own commit.
- CHK9: Is every per-unit version-stamp criterion independent of HEAD (the #541 lesson)? — PASS. The range is taken from the unit's commit by subject grep.
- CHK10: Does any new text risk the C4.1 phrase sweep or the reviewed-path gate? — PASS. R2 and R3 name both, and the ADR-0020 edit is an Edit-tool before/after.
- CHK11: Are the nine-element contracts present for the fast path? — FAIL (missing) — revised in place. R8 states that the contracts are written after the answers to Open Questions 1, 2 and 4, which change their content, and that each is scored with contract-guard before handoff.

## Report only (out of slice, not specced)

1. **Contract-guard `reason=no-contract` on every skr issue (cause confirmed).** `bin/contract-guard.js` `blocks()` (:36-51) accepts a contract in only two places: a fenced block whose first interior line is exactly `Unit: <id>`, or a whole input whose line 1 is `Unit: <id>`. Each skr issue body task-master published opens with a prose preamble (`Step N of ...`, `Suggested model`, `Depends on`), then `## Dispatch contract` (or `## Dispatch contract (scribe)`), then an unfenced `Unit: skr-N` at line 10 or 11. Neither form matches. Confirmed on #531: piping the body from line 10 on (`tail -n +10 | node bin/contract-guard.js - --unit=skr-1`) scores `contract-guard: haiku unit=skr-1 shape=lead score=7/7`, so the content was haiku-grade and only the placement demoted it. Wrapping the contract in a fence would also need an outer fence longer than or different from the `~~~` payload fences inside it (#531 has `~~~` at :226/:241). Contributing gap: agents/task-master.md:132 and :319 require `Unit: <task-id>` as line 1 of the dispatch contract, and its "In the issue body it sits under the heading `## Dispatch contract (scribe)`" places the contract after a heading. Neither text reconciles the published issue-body layout with what the orchestrator's guard (agents/orchestrator.md:511-518, `gh issue view <N> --json body -q .body` piped into the guard) accepts. Fix candidates (not specced): the guard locates `Unit: <id>` after a `## Dispatch contract` heading, or task-master fences the contract.
2. **stop-gate stamp attribution (mechanism confirmed from source; the incident sequence not confirmed).** From source:
   - `reviewer-route-gate-core.sh:149-152` writes `.claude/.review-join.<unit-id>` at dispatch time. The stamp holds only `<ts> unit= prior= prior_mtime=`: no agent id or dispatch id.
   - `stop-gate-core.sh` `review_join_state` (:239-329) globs every `.review-join.*` in the directory on any reviewer's SubagentStop. The comment at :210-213 says why: the SubagentStop payload carries no unit id.
   - The block at :460-469 fires when no stamp is satisfied, no stamp is fail-open, and at least one is unsatisfied.

   Consequence: a reviewer whose own stamp was already consumed (deleted on an earlier satisfied stop, :429) and that stops again while another unit's freshly written, still-unsatisfied stamp exists is blocked and told to write a verdict for the other unit. That matches the observed skr-3/skr-4 report. I could not confirm from the hook source alone that the skr-3 reviewer's own stamp had already been consumed (a resumed or second turn) when it stopped. Confirming that needs the `.claude/review-audit.log` lines around 2026-10-14T17:33-17:52 (`join-consumed=skr-3`, `review-join=skr-4`), read with the Read tool. A Bash command naming that log is refused by harness-integrity-gate. The orchestrator's "Reviewer re-tasking discipline" (docs/harness-glossary.md:1825-1829) covers the resume-for-a-different-unit case, not a concurrent second dispatch.
3. Other report-only items: the persona config's `issueTracker` string still cites "to-tickets' own default" (human-only edit, agents may not touch it). Broken relative links outside maintained docs: rendered `.claude/agents` 18, `adapters/cursor` 2, `docs/plans` 15. There is no re-pin procedure for forked skills (sfu-2 documents the limitation).

## Scribe update hint

After sfu-5 passes, scribe should check the wiki changelog for the five sfu units. No new ADR: the ADR-0041 corrections are recorded in its own `## Corrections` section.
