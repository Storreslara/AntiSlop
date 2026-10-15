# Skills audit follow-ups (slice `sfu`)

Status: FINAL, ready to dispatch (fast path, 5 units, strict order sfu-1 -> sfu-5). All 4 Open Questions answered by the user 2026-10-14 (each as recommended). Contracts: `## Dispatch contracts` below; each scores `contract-guard: haiku ... score=7/7`.
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
- Prior FAIL history: no `.fail` record exists for any skr unit (all eleven have only `.pass`). The `bin/marker-audit.sh --notes --surface=<path>` sweep over every touched path completed (background run, 2026-10-14): 40 `NOTE[code]` lines, no `NOTE[spec]` line and no `untagged` line. One note bears on this slice and is dispositioned in sfu-2: `ci-fetch-depth-cleanup` says `docs/trust-model.md` row 25 dropped the "why explicit range" rationale, so sfu-2's row-25 edit restores it ("Takes an explicit range because a unit's range is a per-unit input only the reviewer knows."). The others concern files or claims this slice does not change. An empty sweep would prove nothing (per-clone state).
- End-to-end verification: the five contracts were parsed from this file and applied in order to a fresh clone of `e6b9ee5`: every before block matched exactly once and every command exited as expected, including both `node bin/cli.js --update --force-render` runs and all five commits. Every acceptance criterion then held, and `bash tests/validate-lanes.sh --lanes 6` on the final state passed (118 sections, 3171 OK lines, no FAIL, 135 s). That run caught a gap the draft missed: `skills/roast-work/SKILL.md` is inlined byte-for-byte into `adapters/codex/agents/reviewer.toml` and `adapters/cursor/agents/reviewer.md` (`tests/adapter-skill-parity.test.js`), so sfu-2 edits both ports too.

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
- 2026-10-14 Edge cases / failure handling: Q Is the `+++` exclusion mutant killable? → A (self-resolved): no fixture is added for it. Corrected 2026-10-14 (unit lov-1): it is not an equivalent mutant. The header line is always `+++ b/CHANGELOG.md` or `+++ /dev/null` and names no version, but an added line whose text starts with `++` also renders as `+++...`: the shipped code skips it and the mutant counts it. That old false-violation path stays unpinned on purpose. The substring boundary itself is Open Question 2.
- 2026-10-14 Technical constraints & tradeoffs: Q Does fixing ADR-0041's title and Decision 3 wording need an amendment ADR rather than an in-place edit? → A (self-resolved): in-place edit plus a dated `## Corrections` section. Both are factual misstatements of the ADR's own content (the count of skills retired; the npm-only reach of ADR-0022), not a change of decision. Precedent: ADR-0039 corrected in place (2c3f3c4). Amendment sections (ADR-0040) and new ADRs are for changed decisions. Other ADRs stay untouched; the ADR-0020 link edit in sfu-5 changes only markdown link syntax, and only if Open Question 1 = A.
- 2026-10-14 Technical constraints & tradeoffs: Q Which units owe the P3 version bump? → A (self-resolved): only sfu-3, the one unit that edits `agents/*.md` (0.31.167 -> 0.31.168, `.claude-plugin/plugin.json` + `package.json` + CHANGELOG entry naming it, then `node bin/cli.js --update --force-render`). sfu-4 edits a hook, not a version-stamped path. It still runs `node bin/cli.js --update --force-render` to refresh the `.claude/hooks` mirror and fileHashes (measured, Context).
- 2026-10-14 Terminology consistency: Q "CHANGELOG line" or "CHANGELOG entry"? → A (self-resolved): "CHANGELOG entry", the canonical glossary term (CONTEXT.md:133). sfu-3 renames every live "CHANGELOG line", riding the version bump that sfu-3 already owes. CONTEXT.md:150 says how an entry is detected ("an added CHANGELOG.md line naming the version"), so "line" stays a description and never becomes a synonym.

- 2026-10-14 Functional scope & success criteria: Q How far should the relative-link check go? → A: fix all 55 broken links and add the test (option A), per user.
- 2026-10-14 Edge cases / failure handling: Q Should version-stamp-check stop matching substrings (0.31.16 named by 0.31.166)? → A: close it; a version may not run into a digit on the right or a digit or dot on the left, per user.
- 2026-10-14 Technical constraints & tradeoffs: Q Who fixes the two stale spec-master memory notes? → A: spec-master, now, in its own commit separate from the plan, per user (done, `e6b9ee5`).
- 2026-10-14 Terminology consistency: Q Does spec-master's PRD-template credit carry the MIT copyright line? → A: include "Copyright (c) 2026 Matt Pocock", riding sfu-3's bump, per user.

## Risks / dependencies

- R1. Strict chain sfu-1 -> sfu-2 -> sfu-3 -> sfu-4 -> sfu-5. `CHANGELOG.md` is shared by every unit; `CONTEXT.md` by sfu-1, sfu-3 and sfu-5. sfu-5's link test needs every earlier unit's text final, and new prose in sfu-1/sfu-2 adds no markdown links except root-correct ones in CONTEXT.md.
- R2. `tests/harness-integrity-gate.test.sh` C4.1 sweeps `git grep -l` for four fixed gate phrases (its `c41_pattern`) across the whole tree, including `docs/plans/`. No new text in this slice or in this plan may contain them. This plan was written to avoid them.
- R3. Gates on command text. A Bash command naming the persona config is refused by `harness-integrity-gate.sh`, so stage `.claude` changes with `git add -u .claude`, never by naming that file. A Bash command spelling the per-clone review-record directory is refused by `reviewed-path-gate.sh`, so sfu-5's ADR-0020 edit is an Edit-tool before/after, never a sed.
- R4. `tests/validate.sh` exceeds the 600 s Bash cap serially. Use `bash docs/plans/skr-criteria/skr-core.sh` (3.5 s at HEAD) and the unit criteria. `bash tests/validate-lanes.sh --lanes 6` is the full-suite check. Leave `tests/validate-lanes*`, `tests/reviewed-dir-leak-guard.test.sh`, `docs/plans/epfd-criteria/`, `docs/plans/lgc-criteria/` and `docs/plans/vlg-criteria/` alone.
- R5. Marker-audit sweep: done (Context). No `NOTE[spec]`; the one relevant `NOTE[code]` is dispositioned in sfu-2.
- R6. Contract-guard demotion (see Report-only 1). Issue bodies with a prose preamble before `Unit:` score `reason=no-contract`. On the fast path the guard reads this plan file, so each contract must sit in a fenced block whose first interior line is `Unit: sfu-N`. The outer fence must be `~~~~` (four tildes), because the payloads use `~~~`.
- R7. Commit trailer: the per-unit criterion greps only `^Co-Authored-By: Claude `. The orchestrator supplies the tier's own attribution line at dispatch, per agents/task-master.md:210 ("the exact trailer line the dispatch gives").
- R8. Where a contract and the narrative Steps differ, the contract governs (it is what was applied and verified); the Steps keep their draft line references for reading only.
- R9. sfu-4 touches `hooks/scripts/version-stamp-check.sh`, an area with a history of FAILs, so its Suggested model is `sonnet` although the guard scores it haiku-eligible. Every other unit is tagged `haiku`.

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

## Dispatch contracts

Strict order sfu-1 -> sfu-2 -> sfu-3 -> sfu-4 -> sfu-5; each unit is blocked by the previous one (shared `CHANGELOG.md`; `CONTEXT.md` in sfu-1, sfu-3, sfu-5; sfu-5's link test reads the text the earlier units leave). Each contract is the fenced block below its heading; the guard reads it with `node bin/contract-guard.js docs/plans/2026-10-14-skills-audit-followups.md --unit=sfu-N`.

### Contract sfu-1: glossary entries, stale skill references and ADR-0041 corrections

Suggested model: haiku

~~~~
Unit: sfu-1

## Objective
`CONTEXT.md` no longer describes `to-spec`, `to-tickets` or `fail-triage` as live and defines Retired skill, Forked skill (fork-and-own), PRD template, debug spec, self-grill, Open Questions, work the frontier and expand-contract; `docs/harness-glossary.md` defines **skill base directory** and fixes three stale passages; ADR-0041 says "ten skills", its Decision 3 no longer claims nothing ships the archive, and a `## Corrections` section records both. No version bump (no `agents/*.md` or `templates/` change). Edits are listed top to bottom per file; apply them in order.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-followups.md`. Criteria scripts and payloads: `docs/plans/sfu-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop` (the umbrella of the skr slice whose review findings this slice closes).

## Affected files
- `CONTEXT.md` (anchors in edits 1-7)
- `docs/harness-glossary.md` (anchors in edits 8-11)
- `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md` (anchors in edits 12-14)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `CONTEXT.md`
   anchor: line matching `turns ambiguous goals into precise specs via grilling and publishes via`
   before:
   ~~~
     turns ambiguous goals into precise specs via grilling and publishes via
     `to-spec`; `task-master` reads finalized specs and writes dispatch
     instructions for `lead-programmer`, owns `to-tickets` slicing outright, tags
   ~~~
   after:
   ~~~
     turns ambiguous goals into precise specs via grilling and publishes through
     its own [[PRD template]] appendix (formerly the `to-spec` skill); `task-master`
     reads finalized specs and writes dispatch instructions for `lead-programmer`,
     owns slicing through the `pathfinder` skill, tags
   ~~~
   indent: 3
2. file: `CONTEXT.md`
   anchor: line matching `vendored first-party skill (originally from Matt`
   before:
   ~~~
   vendored first-party skill (originally from Matt
     Pocock's `skills` repo, see `skills/THIRD-PARTY-NOTICES.md`), wired to
     `spec-master` via `antislop:to-spec`. Turns a finalized spec
     conversation into a single published spec (Problem Statement / Solution /
     User Stories / Implementation Decisions / Testing Decisions / Out of Scope)
     on the issue tracker, no further interview. Complements `grill-me`
     sequentially: grill to resolve ambiguity, then to-spec to synthesize and
     publish. The template LAYERS on top of the v0.9.0 spec-kit format (Goal →
     Context → Clarifications → …), not replacing it.
   ~~~
   after:
   ~~~
   a retired vendored skill (originally from Matt
     Pocock's `skills` repo, see `skills/THIRD-PARTY-NOTICES.md`) that was wired to
     `spec-master` via `antislop:to-spec`. It turned a finalized spec
     conversation into a single published spec (Problem Statement / Solution /
     User Stories / Implementation Decisions / Testing Decisions / Out of Scope)
     on the issue tracker, with no further interview, after `grill-me` had
     resolved the ambiguity. The template layered on top of the v0.9.0 spec-kit
     format (Goal → Context → Clarifications → …), not replacing it; it lives
     on as the [[PRD template]].
   ~~~
   indent: 3
3. file: `CONTEXT.md`
   anchor: line matching `are bypassed,`
   before:
   ~~~
     the `docs/plans/` document — `task-master` and `to-tickets` are bypassed,
   ~~~
   after:
   ~~~
     the `docs/plans/` document — `task-master` and its `pathfinder` slicing are bypassed,
   ~~~
   indent: 3
4. file: `CONTEXT.md`
   anchor: line matching `PRD template and publishes it to the issue`
   before:
   ~~~
     plan onto the `to-spec` PRD template and publishes it to the issue
   ~~~
   after:
   ~~~
     plan onto its [[PRD template]] and publishes it to the issue
   ~~~
   indent: 3
5. file: `CONTEXT.md`
   anchor: line matching `latest-only snapshot. Read by`
   before:
   ~~~
     latest-only snapshot. Read by `bin/fail-count.sh` and by `fail-triage`/debug
     spec when a unit reaches [[ladder exhaustion]].
   ~~~
   after:
   ~~~
     latest-only snapshot. Read by `bin/fail-count.sh` and by `spec-master`'s
     [[debug spec]] when a unit reaches [[ladder exhaustion]] (formerly the
     `fail-triage` skill).
   ~~~
   indent: 3
6. file: `CONTEXT.md`
   anchor: line matching `directory and commit. Nothing loads, lists, mirrors, hashes or ships it.`
   before:
   ~~~
     directory and commit. Nothing loads, lists, mirrors, hashes or ships it.
   ~~~
   after:
   ~~~
     directory and commit. No skill loader discovers it and nothing lists,
     mirrors or hashes it; the npm package ships no `docs/` path, while a git
     clone or plugin install carries it as inert files.
   ~~~
   indent: 3
7. file: `CONTEXT.md`
   anchor: line matching `  still live).`
   insert-after:
   ~~~

   **Retired skill**:
   a skill removed from every discovery root: no persona preloads or invokes it
     and no skill menu lists it. Its original is kept as an [[Archived skill]].
     The archive index's disposition column records what became of each archived
     original: `retired` (gone; a successor is named, or none), `merged away` (its
     content now lives in a persona or another skill), `rewritten` or `trimmed`
     (still live, edited), `forked` (still live, see [[Forked skill]]).

   **Forked skill** (synonym: **fork-and-own**):
   a vendored skill whose live file antislop now edits. The live file carries a
     "Derived from" header instead of the byte-verbatim vendoring header, and
     upstream drift is tracked on its byte-verbatim original under
     `docs/archive/skills/<name>/`, not on the live file, so upstream fixes are
     ported by hand. A declared deviation, by contrast, keeps the live file
     drift-tracked against reconstructed upstream text. Current set: `grilling`,
     `tdd`, `diagnosing-bugs`, `improve-codebase-architecture`
     ([ADR-0041](docs/adr/0041-retire-skills-fork-and-own-archive-originals.md)).

   **PRD template**:
   the section layout `spec-master` maps a finished plan onto when it publishes
     to the issue tracker: Problem Statement, Solution, User Stories,
     Implementation Decisions, Testing Decisions, Out of Scope, Further Notes. It
     lives in `agents/spec-master.md` under `## Appendix: PRD template` and layers
     on top of the plan format (Goal, Context, Clarifications, ...) without
     replacing it; the `docs/plans/` document stays the canonical artifact. See
     [[publish threshold]].

   **debug spec**:
   the focused artifact `spec-master` writes when the orchestrator escalates a
     unit that hit the 2-FAIL cap: after re-running the failing criterion fresh,
     a root-cause read of the plan (a plan gap, an unverifiable criterion, missing
     context or the wrong approach), then the failed steps rewritten with
     corrected acceptance criteria and a table mapping every recorded defect to a
     criterion that detects it. Never a from-scratch replan. Formerly the
     `fail-triage` skill (original: `docs/archive/skills/fail-triage/`).

   **self-grill**:
   the `grilling` mode with no one to ask, for example when auditing a plan's
     premises: the agent answers each question itself from evidence in the repo
     (files, tests, history, tools), and a question the evidence cannot settle,
     including an undecided decision, becomes a finding rather than a guess.
     Compare [[Open Questions]], the mode for a dispatched agent whose answers
     come from the user through the orchestrator.

   **Open Questions**:
   the section a one-shot dispatched agent (typically `spec-master` while
     grilling) returns when a decision needs the user: up to 4 questions per
     round, ordered by impact x uncertainty, each with a recommended default and
     options where the answer space is discrete. The agent stops; the
     orchestrator relays the questions and re-dispatches with the answers, and
     rounds repeat until every question converges. Returning Open Questions is a
     finished turn, not a failure.

   **work the frontier**:
   the order in which the units of a `pathfinder` slice are dispatched: next is
     any unit whose blockers are all done; for a purely linear chain that is top
     to bottom.

   **expand-contract**:
   the `pathfinder` sequencing for a wide refactor, one mechanical change whose
     blast radius fans across the whole codebase so no single vertical slice can
     land green: first expand (add the new form beside the old), then migrate the
     call sites in batches, each its own unit blocked by the expand, then contract
     (delete the old form) in a unit blocked by every migrate batch.
   ~~~
   indent: 3
8. file: `docs/harness-glossary.md`
   anchor: line matching `glossary) as we go.") depending on the harness's selection order. The descriptions cannot`
   before:
   ~~~
     glossary) as we go.") depending on the harness's selection order. The descriptions cannot
     be edited to disambiguate because both are **drift-tracked skills** — their descriptions
     are reconstructed byte-for-byte from upstream by the `fm-noflag` declared-deviation type,
     and editing the descriptions would break the `fm-noflag` declared-deviation class check.
     The only available mitigation is explicit prose naming of the intended skill in the persona
     or dispatch context (e.g., in `agents/spec-master.md`'s instructions to use `grill-with-docs`
     rather than bare "grilling"), since descriptions themselves cannot be used as a
   ~~~
   after:
   ~~~
     glossary) as we go.") depending on the harness's selection order. The descriptions could not
     be edited to disambiguate because both were then **drift-tracked skills** — their descriptions
     were reconstructed byte-for-byte from upstream by the `fm-noflag` declared-deviation type,
     and editing the descriptions would have broken the `fm-noflag` declared-deviation class check.
     The only available mitigation was explicit prose naming of the intended skill in the persona
     or dispatch context (e.g., in `agents/spec-master.md`'s instructions to use `grill-with-docs`
     rather than bare "grilling"), since descriptions themselves could not be used as a
   ~~~
   indent: 3
9. file: `docs/harness-glossary.md`
   anchor: line matching `Root cause is upstream installer content bug, not antislop defect. Now that`
   before:
   ~~~
     Root cause is upstream installer content bug, not antislop defect. Now that
     these SKILL.md files are tracked/shipped, the gap is more visible and should
     be fixed in the installer itself.
   ~~~
   after:
   ~~~
     Root cause is upstream installer content bug, not antislop defect. While
     these SKILL.md files were tracked/shipped, the gap was more visible; any fix
     belongs in the installer itself.
   ~~~
   indent: 3
10. file: `docs/harness-glossary.md`
   anchor: line matching `re-derive the real location.`
   before:
   ~~~
     re-derive the real location.
     Archived originals (skills audit, 2026-10-14): `docs/archive/skills/code-review/`.
   ~~~
   after:
   ~~~
     re-derive the real location.
     Not the retired `code-review` skill, a different tool (original: `docs/archive/skills/code-review/`).
   ~~~
   indent: 3
11. file: `docs/harness-glossary.md`
   anchor: line matching `No `REPOINT_SKILLS` remain. See `docs/maintenance/resync-vendored-skills.md`.`
   insert-after:
   ~~~

   **skill base directory**:
   (unit sfu-1, 2026-10-14) — the directory a loaded skill's files live in. The
     harness announces it as a "Base directory for this skill: <path>" line when
     the skill loads; for a plugin skill it is the plugin cache, not the
     consumer's repo. A skill names its companion files relative to it (for
     example `diagnosing-bugs`'s `scripts/hitl-loop.template.sh`), because the
     same relative path read from the working directory finds nothing in a
     consumer project.
   ~~~
   indent: 3
12. file: `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`
   anchor: line matching `# ADR 0041: Retire five skills, fork-and-own the edited vendored skills, archive originals under`
   before:
   ~~~
   # ADR 0041: Retire five skills, fork-and-own the edited vendored skills, archive originals under `docs/archive/skills/`
   ~~~
   after:
   ~~~
   # ADR 0041: Retire ten skills, fork-and-own the edited vendored skills, archive originals under `docs/archive/skills/`
   ~~~
   indent: 3
13. file: `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`
   anchor: line matching `3. Every pre-change original of a skill that was deleted, merged away or rewritten is kept byte-identical under`
   before:
   ~~~
   3. Every pre-change original of a skill that was deleted, merged away or rewritten is kept byte-identical under `docs/archive/skills/<name>/`, with an index row in `docs/archive/skills/README.md` naming its origin path and commit. Nothing loads, lists, mirrors, hashes or ships that directory.
   ~~~
   after:
   ~~~
   3. Every pre-change original of a skill that was deleted, merged away or rewritten is kept byte-identical under `docs/archive/skills/<name>/`, with an index row in `docs/archive/skills/README.md` naming its origin path and commit. No skill loader discovers that directory and nothing lists, mirrors or hashes it; the npm package ships no `docs/` path, while a git clone or plugin install carries it as inert files (ADR-0022).
   ~~~
   indent: 3
14. file: `docs/adr/0041-retire-skills-fork-and-own-archive-originals.md`
   anchor: line matching `- `docs/archive/skills/README.md`: the archive index.`
   insert-after:
   ~~~

   ## Corrections

   - 2026-10-14 (unit sfu-1): the title said five skills while Decision 1 retires ten, and Decision 3 said nothing ships the archive, overstating ADR-0022's npm-only exclusion. Both corrected in place; the decision is unchanged.
   ~~~
   indent: 3
15. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Glossary and ADR-0041 follow-ups to the skills audit (sfu-1).** `CONTEXT.md` drops stale `to-spec`/`to-tickets`/`fail-triage` wording and gains eight entries (Retired skill, Forked skill / fork-and-own, PRD template, debug spec, self-grill, Open Questions, work the frontier, expand-contract); `docs/harness-glossary.md` gains **skill base directory** and fixes three stale passages; ADR-0041's title and Decision 3 are corrected in place, recorded under its new `## Corrections` section.
   ~~~
   indent: 3
16. command: `git add CONTEXT.md docs/harness-glossary.md docs/adr/0041-retire-skills-fork-and-own-archive-originals.md CHANGELOG.md && git commit -m "docs(sfu-1): glossary entries, stale skill references and ADR-0041 corrections (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/` (no persona text changes in this unit)
- `skills/` (prose fixes there are sfu-2)
- `docs/adr/0022-npm-distribution-skills-excluded.md` and every ADR other than 0041 (historical, not edited)
- `.claude/persona-config.json` (written only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-1`
   exit: 0
   stdout: `sfu-claims: sfu-1 ok`
   mutation: skip edit 12; the Retire five skills check prints count=1 want=0 and the script exits 1.
2. run: `node tests/context-glossary-links.test.js`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: write [[PRD templates]] instead of [[PRD template]] in edit 4; the link resolves to no heading and the test exits 1.
3. run: `bash docs/plans/skr-criteria/skr-glossary.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage`
   exit: 0
   stdout: `skr-glossary: fail-triage ok`
   mutation: drop "(original: `docs/archive/skills/fail-triage/`)" from the debug spec entry in edit 7; that entry names fail-triage without an archive pointer and the script exits 1.
4. run: `bash docs/plans/skr-criteria/skr-core.sh`
   exit: 0
   stdout: `skr-core: ok`
   mutation: write [[PRD templates]] in edit 4; tests/context-glossary-links.test.js fails inside it and the script prints skr-core: FAIL.
5. run: `C=$(git log -1 --format=%H -F --grep='docs(sfu-1): '); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
6. run: `C=$(git log -1 --format=%H -F --grep='docs(sfu-1): '); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 16; no commit has the subject, test -n fails and nothing prints.
7. run: `git diff --quiet HEAD -- CONTEXT.md docs/harness-glossary.md docs/adr CHANGELOG.md`
   exit: 0
   stdout: `empty`
   mutation: skip edit 16; the edited files stay modified and git diff exits 1.

## Pre-resolved context
tdd: no prose and glossary edits only; sfu-claims.sh is the claim-anchored check
blast-radius: CONTEXT.md:52, CONTEXT.md:521, CONTEXT.md:538, CONTEXT.md:552, CONTEXT.md:641, CONTEXT.md:644, CONTEXT.md:920, docs/harness-glossary.md:977, docs/harness-glossary.md:1628, docs/harness-glossary.md:1674, docs/harness-glossary.md:1846, docs/adr/0041-retire-skills-fork-and-own-archive-originals.md:1
commit-message: docs(sfu-1): glossary entries, stale skill references and ADR-0041 corrections (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block was matched exactly once against the tree as the previous units leave it, by applying this plan's edits in order to a fresh clone of 7ae820e
review-packet:
~~~
unit: sfu-1
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract sfu-2: skills and docs prose

Suggested model: haiku

~~~~
Unit: sfu-2

## Objective
The skill and doc contradictions the skr reviewers recorded are gone: grilling's self-grill rule, install-antislop's `jq` check and its missing Read-tool pointer (live file and `.claude/skills` mirror stay byte-identical), pathfinder's hard-coded local-files path, roast-work's PASS/FAIL sentence, improve-codebase-architecture's "one-shot subagent" claim, persona-design-notes' live `to-spec`/`to-tickets`, trust-model row 25, THIRD-PARTY-NOTICES (four forked skills, rows 1-10), the resync runbook (forked shapes, re-pin limits) and the archive README's "ships" sentence. No version bump.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-followups.md`. Criteria scripts and payloads: `docs/plans/sfu-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop` (the umbrella of the skr slice whose review findings this slice closes).

## Affected files
- `docs/persona-design-notes.md`
- `docs/trust-model.md` (row 25)
- `skills/THIRD-PARTY-NOTICES.md`
- `docs/maintenance/resync-vendored-skills.md`
- `docs/archive/skills/README.md` (line 3 only; the archived skill directories are not touched)
- `skills/grilling/SKILL.md`
- `skills/install-antislop/SKILL.md` and its byte mirror `.claude/skills/install-antislop/SKILL.md` (copied by edit 14)
- `skills/pathfinder/SKILL.md`
- `skills/roast-work/SKILL.md`
- `adapters/codex/agents/reviewer.toml` and `adapters/cursor/agents/reviewer.md` (inlined roast-work body, edits 17-18; `tests/adapter-skill-parity.test.js` requires it byte-equal to the skill)
- `skills/improve-codebase-architecture/SKILL.md`
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `docs/persona-design-notes.md`
   anchor: line matching `spec-master owns the spec through Open Questions relay and publishing via`
   before:
   ~~~
   spec-master owns the spec through Open Questions relay and publishing via
   `to-spec`; ticket-slicing (`to-issues`), per-unit model tagging, the
   ~~~
   after:
   ~~~
   spec-master owns the spec through Open Questions relay and publishing
   through its own PRD-template appendix; ticket-slicing (the `pathfinder`
   skill), per-unit model tagging, the
   ~~~
   indent: 3
2. file: `docs/persona-design-notes.md`
   anchor: line matching `slicing outright, per-unit model`
   before:
   ~~~
   task-master owns `to-issues`/`to-tickets` slicing outright, per-unit model
   ~~~
   after:
   ~~~
   task-master owns slicing through the `pathfinder` skill, per-unit model
   ~~~
   indent: 3
3. file: `docs/persona-design-notes.md`
   anchor: line matching `interrogation, Open Questions, Self-check, publishing via`
   before:
   ~~~
   interrogation, Open Questions, Self-check, publishing via `to-spec`).
   ~~~
   after:
   ~~~
   interrogation, Open Questions, Self-check, publishing through its
   PRD-template appendix).
   ~~~
   indent: 3
4. file: `docs/trust-model.md`
   anchor: line matching `(units version-stamp-guard-1, version-stamp-check-roast-1). Implements **per-commit semantics**: every commit in the range that touches a version-stamped path is checked against its own immediate parent. Deterministic given an explicit`
   before:
   ~~~
   | 25 | A unit touching `agents/*.md` or `templates/` bumped `.claude-plugin/plugin.json`'s version in each commit that touched it (constitution P3 / version-stamp discipline) | `hooks/scripts/version-stamp-check.sh` | self-reported | Deliberately **not** hook-registered — a reviewer-invoked helper, matching `heavy-trigger.sh`/`reviewer-tier.sh` (units version-stamp-guard-1, version-stamp-check-roast-1). Implements **per-commit semantics**: every commit in the range that touches a version-stamped path is checked against its own immediate parent. Deterministic given an explicit `<commit-range>` argument; nothing independently re-derives whether the reviewer actually ran it against the right range. |
   ~~~
   after:
   ~~~
   | 25 | A unit touching `agents/*.md` or `templates/` bumped `.claude-plugin/plugin.json`'s version in each commit that touched it, and added a CHANGELOG entry naming the new version in that same commit (constitution P3 / version-stamp discipline) | `hooks/scripts/version-stamp-check.sh` | self-reported | Deliberately **not** hook-registered — a reviewer-invoked helper, matching `heavy-trigger.sh`/`reviewer-tier.sh` (units version-stamp-guard-1, version-stamp-check-roast-1). Implements **per-commit semantics**: every commit in the range that touches a version-stamped path is checked against its own immediate parent. Takes an explicit range because a unit's range is a per-unit input only the reviewer knows. Deterministic given an explicit `<commit-range>` argument; nothing independently re-derives whether the reviewer actually ran it against the right range. |
   ~~~
   indent: 3
5. file: `skills/THIRD-PARTY-NOTICES.md`
   anchor: line matching `is forked: its live file carries a "Derived from" header and antislop edits, and its drift tracking moves to the archived original.`
   before:
   ~~~
   `handoff` and `improve-codebase-architecture` have the `disable-model-invocation: true` frontmatter flag stripped (tracked as `fm-noflag` reconstruction type in the drift check). `grill-me` and `grill-with-docs` were retired by the skills audit; their originals are kept, byte-identical, under `docs/archive/skills/` (see its README). `code-review` was retired by the skills audit (original: `docs/archive/skills/code-review/`). `tdd` is forked: its live file carries a "Derived from" header and antislop edits, and its drift tracking moves to the archived original. `skills/pathfinder` is first-party (derived from `wayfinder`; `to-tickets` original: `docs/archive/skills/to-tickets/`). All other vendored skills are byte-verbatim aside from the
   ~~~
   after:
   ~~~
   `handoff` and `improve-codebase-architecture` have the `disable-model-invocation: true` frontmatter flag stripped (tracked as `fm-noflag` reconstruction type in the drift check). `grill-me` and `grill-with-docs` were retired by the skills audit; their originals are kept, byte-identical, under `docs/archive/skills/` (see its README). `code-review` was retired by the skills audit (original: `docs/archive/skills/code-review/`). `grilling`, `tdd`, `diagnosing-bugs` and `improve-codebase-architecture` are forked: each live file carries a "Derived from" header and antislop edits, and drift tracking moves to the archived original. `skills/pathfinder` is first-party (derived from `wayfinder`; `to-tickets` original: `docs/archive/skills/to-tickets/`). All other vendored skills are byte-verbatim aside from the
   ~~~
   indent: 3
6. command: `python3 -c "import re,pathlib; p=pathlib.Path('skills/THIRD-PARTY-NOTICES.md'); t=p.read_text(); n=iter(range(1,100)); t2=re.sub(r'(?m)^[|] [0-9]+ [|]', lambda m: '| %d |' % next(n), t); assert t2.count(chr(10)+'| ')>=10; p.write_text(t2)"`
   expect: 0
7. file: `docs/maintenance/resync-vendored-skills.md`
   anchor: line matching `skills/productivity/grilling`
   before:
   ~~~
   | `grilling` | `skills/productivity/grilling` | verbatim |
   ~~~
   after:
   ~~~
   | `grilling` | `skills/productivity/grilling` | forked (rows diff the archived copy) |
   ~~~
   indent: 3
8. file: `docs/maintenance/resync-vendored-skills.md`
   anchor: line matching `skills/engineering/tdd`
   before:
   ~~~
   | `tdd` (+ `tests.md`, `mocking.md`) | `skills/engineering/tdd` | verbatim |
   ~~~
   after:
   ~~~
   | `tdd` (+ `tests.md`, `mocking.md`) | `skills/engineering/tdd` | forked (rows diff the archived copy) |
   ~~~
   indent: 3
9. file: `docs/maintenance/resync-vendored-skills.md`
   anchor: line matching `4. Once all desired files are updated, re-pin: fetch upstream's current`
   before:
   ~~~
   4. Once all desired files are updated, re-pin: fetch upstream's current
      commit SHA for `main`
      (`git ls-remote https://github.com/mattpocock/skills main`) and update
      the SHA in `skills/THIRD-PARTY-NOTICES.md` (both the prose sentence and
      every per-file provenance header comment across all 7 skills — a
      project-wide find/replace of the old SHA for the new one).
   ~~~
   after:
   ~~~
   4. Once all desired files are updated, re-pin: fetch upstream's current
      commit SHA for `main`
      (`git ls-remote https://github.com/mattpocock/skills main`) and update
      the SHA in `skills/THIRD-PARTY-NOTICES.md` (the prose sentence) and in the
      provenance header of every file the FILES table names under `skills/`.
      Do not run a project-wide find/replace: archived originals under
      `docs/archive/skills/` stay byte-identical to the commit their README row
      names, and a forked skill's live "Derived from" header (short SHA) changes
      only when an upstream change is ported by hand (step 3). Re-pinning while
      forked skills exist is not covered by this runbook (their archived copies
      would then drift against the new pin); stop and raise it.
   ~~~
   indent: 3
10. file: `docs/archive/skills/README.md`
   anchor: line matching `Byte-identical originals of skills that were retired, merged away or rewritten. Nothing loads, lists, mirrors, hashes or ships this directory: it is outside every discovery root and package.json ships no docs/ path. Read it for history; do not edit it. Each directory is verified against git by docs/plans/skr-criteria/skr-archive-verify.sh.`
   before:
   ~~~
   Byte-identical originals of skills that were retired, merged away or rewritten. Nothing loads, lists, mirrors, hashes or ships this directory: it is outside every discovery root and package.json ships no docs/ path. Read it for history; do not edit it. Each directory is verified against git by docs/plans/skr-criteria/skr-archive-verify.sh.
   ~~~
   after:
   ~~~
   Byte-identical originals of skills that were retired, merged away or rewritten. No skill loader discovers this directory and nothing lists, mirrors or hashes it: it is outside every discovery root, and package.json ships no docs/ path (a git clone or plugin install carries it as inert files). Read it for history; do not edit it. Each directory is verified against git by docs/plans/skr-criteria/skr-archive-verify.sh.
   ~~~
   indent: 3
11. file: `skills/grilling/SKILL.md`
   anchor: line matching `- The *decisions* belong to the user: put each one to the user (or return it as an Open Question) and do not decide it yourself.`
   before:
   ~~~
   - The *decisions* belong to the user: put each one to the user (or return it as an Open Question) and do not decide it yourself.
   ~~~
   after:
   ~~~
   - The *decisions* belong to the user: put each one to the user (or return it as an Open Question) and do not decide it yourself. In a self-grill there is no one to ask, so an undecided decision becomes a finding, like an unanswerable question.
   ~~~
   indent: 3
12. file: `skills/install-antislop/SKILL.md`
   anchor: line matching `(creating it with just that field if step 6 hasn't`
   before:
   ~~~
     `persona-config.json` (creating it with just that field if step 6 hasn't
   ~~~
   after:
   ~~~
     `persona-config.json` (inspect it with the `Read` tool, because a Bash command naming that file can be refused by `harness-integrity-gate.sh`; the file is created with just that field if step 6 hasn't
   ~~~
   indent: 3
13. file: `skills/install-antislop/SKILL.md`
   anchor: line matching `Validate the file against`
   before:
   ~~~
   Validate the file against `templates/persona-config.schema.json` (a `jq`
   check that every required key is present and typed correctly) before moving
   ~~~
   after:
   ~~~
   Validate the file against `templates/persona-config.schema.json` (read it
   with the `Read` tool and check that every required key is present and typed
   correctly; a Bash command such as `jq` naming that file can be refused by
   `harness-integrity-gate.sh`) before moving
   ~~~
   indent: 3
14. command: `cp skills/install-antislop/SKILL.md .claude/skills/install-antislop/SKILL.md`
   expect: 0
15. file: `skills/pathfinder/SKILL.md`
   anchor: line matching `in dependency order (blockers first). Each file's "Blocked by" lists the numbers or titles it depends on. One unit per file, never a single combined file; use the template below.`
   before:
   ~~~
   - **Local files** -> write one file per unit under `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers or titles it depends on. One unit per file, never a single combined file; use the template below.
   ~~~
   after:
   ~~~
   - **Local files** -> write one file per unit under the directory the `issueTracker` line names (if it names none, `.scratch/<feature-slug>/issues/`), as `<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers or titles it depends on. One unit per file, never a single combined file; use the template below.
   ~~~
   indent: 3
16. file: `skills/roast-work/SKILL.md`
   anchor: line matching `entries are blocking defects, no matter how sharply worded.`
   before:
   ~~~
   entries are blocking defects, no matter how sharply worded.
   ~~~
   after:
   ~~~
   entries are blocking defects, no matter how sharply worded. It never determines
   PASS/FAIL: the acceptance-criteria commands and the materiality filter remain
   the only gate.
   ~~~
   indent: 3
17. file: `adapters/codex/agents/reviewer.toml`
   anchor: line matching `entries are blocking defects, no matter how sharply worded.`
   before:
   ~~~
   entries are blocking defects, no matter how sharply worded.
   ~~~
   after:
   ~~~
   entries are blocking defects, no matter how sharply worded. It never determines
   PASS/FAIL: the acceptance-criteria commands and the materiality filter remain
   the only gate.
   ~~~
   indent: 3
18. file: `adapters/cursor/agents/reviewer.md`
   anchor: line matching `entries are blocking defects, no matter how sharply worded.`
   before:
   ~~~
   entries are blocking defects, no matter how sharply worded.
   ~~~
   after:
   ~~~
   entries are blocking defects, no matter how sharply worded. It never determines
   PASS/FAIL: the acceptance-criteria commands and the materiality filter remain
   the only gate.
   ~~~
   indent: 3
19. file: `skills/improve-codebase-architecture/SKILL.md`
   anchor: line matching `You run as a one-shot subagent: you cannot ask a question, open a browser or wait for a reply. Do the exploration, then return the result as your final message.`
   before:
   ~~~
   You run as a one-shot subagent: you cannot ask a question, open a browser or wait for a reply. Do the exploration, then return the result as your final message.
   ~~~
   after:
   ~~~
   Whether you run as a one-shot subagent or are invoked through the `Skill` tool inside another persona's turn, you cannot ask a question, open a browser or wait for a reply. Do the exploration, then return the result as your final message.
   ~~~
   indent: 3
20. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Skills and docs prose follow-ups to the skills audit (sfu-2).** `skills/grilling`, `skills/install-antislop` (and its `.claude/skills` mirror), `skills/pathfinder`, `skills/roast-work` and `skills/improve-codebase-architecture` fix the contradictions the skr reviewers recorded (the roast-work sentence also lands in the Codex and Cursor reviewer ports, which inline that skill); `docs/persona-design-notes.md`, `docs/trust-model.md` row 25, `skills/THIRD-PARTY-NOTICES.md` (four forked skills, rows renumbered 1-10), the resync runbook (forked shapes, re-pin limits) and the archive README are brought up to date.
   ~~~
   indent: 3
21. command: `git add docs/persona-design-notes.md docs/trust-model.md skills/THIRD-PARTY-NOTICES.md docs/maintenance/resync-vendored-skills.md docs/archive/skills/README.md skills/grilling/SKILL.md skills/install-antislop/SKILL.md .claude/skills/install-antislop/SKILL.md skills/pathfinder/SKILL.md skills/roast-work/SKILL.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md skills/improve-codebase-architecture/SKILL.md CHANGELOG.md && git commit -m "docs(sfu-2): skills and docs prose follow-ups from the skills audit (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `docs/archive/skills/grilling/` and every other archived skill directory (byte-identical originals)
- `agents/` (persona text is sfu-3)
- `CONTEXT.md` (sfu-1 and sfu-3)
- `.claude/persona-config.json` (written only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-2`
   exit: 0
   stdout: `sfu-claims: sfu-2 ok`
   mutation: skip edit 11; the self-grill check prints count=0 want=1 and the script exits 1.
2. run: `diff -rq skills/install-antislop .claude/skills/install-antislop`
   exit: 0
   stdout: `empty`
   mutation: skip edit 14; the mirror differs and diff exits 1.
3. run: `grep -oE '^[|] [0-9]+ [|]' skills/THIRD-PARTY-NOTICES.md | tr -dc '0-9\n' | paste -sd' '`
   exit: 0
   stdout: `1 2 3 4 5 6 7 8 9 10`
   mutation: skip edit 6; the output is 2 3 4 5 6 7 8 9 10 11.
4. run: `bash docs/plans/skr-criteria/skr-archive-verify.sh grilling tdd diagnosing-bugs improve-codebase-architecture`
   exit: 0
   stdout: `one ok line per archive row`
   mutation: edit docs/archive/skills/grilling/SKILL.md; its row no longer matches git and the script exits 1.
5. run: `bash docs/plans/skr-criteria/skr-live-refs.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage`
   exit: 0
   stdout: `skr-live-refs: fail-triage hits=0`
   mutation: write `to-spec` back into skills/pathfinder/SKILL.md; the to-spec key reports a hit and the script exits 1.
6. run: `node tests/adapter-skill-parity.test.js`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: skip edit 17; the Codex port inlines a roast-work body that differs from the skill and the test exits 1.
7. run: `bash docs/plans/skr-criteria/skr-core.sh`
   exit: 0
   stdout: `skr-core: ok`
   mutation: skip edit 14; the .claude/skills/install-antislop parity check prints FAIL.
8. run: `C=$(git log -1 --format=%H -F --grep='docs(sfu-2): '); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
9. run: `C=$(git log -1 --format=%H -F --grep='docs(sfu-2): '); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 21; no commit has the subject, test -n fails and nothing prints.
10. run: `git diff --quiet HEAD -- docs skills .claude/skills adapters CHANGELOG.md`
   exit: 0
   stdout: `empty`
   mutation: skip edit 21; the edited files stay modified and git diff exits 1.

## Pre-resolved context
tdd: no prose edits only; sfu-claims.sh is the claim-anchored check
blast-radius: skills/grilling/SKILL.md:21, skills/install-antislop/SKILL.md:213, skills/install-antislop/SKILL.md:313, skills/pathfinder/SKILL.md:50, skills/roast-work/SKILL.md:39, skills/improve-codebase-architecture/SKILL.md:18, docs/maintenance/resync-vendored-skills.md:121, skills/THIRD-PARTY-NOTICES.md:29
commit-message: docs(sfu-2): skills and docs prose follow-ups from the skills audit (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block was matched exactly once against the tree as the previous units leave it, by applying this plan's edits in order to a fresh clone of 7ae820e
review-packet:
~~~
unit: sfu-2
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract sfu-3: agent-teams TDD fallback, CHANGELOG entry wording, MIT credit (0.31.168)

Suggested model: haiku

~~~~
Unit: sfu-3

## Objective
`agents/lead-programmer.md` gives a teammate (no `skills:` preload) a TDD fallback; "CHANGELOG line" becomes the canonical "CHANGELOG entry" in three agents, the version-stamp-discipline skill and `CONTEXT.md`; `agents/spec-master.md`'s PRD-template credit carries "Copyright (c) 2026 Matt Pocock". Version-stamp discipline (constitution P3): the plugin version goes 0.31.167 -> 0.31.168 in `.claude-plugin/plugin.json` and `package.json`, a CHANGELOG entry naming 0.31.168 lands in the same commit, and `node bin/cli.js --update --force-render` re-renders the `.claude/` mirrors before that one commit.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-followups.md`. Criteria scripts and payloads: `docs/plans/sfu-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop` (the umbrella of the skr slice whose review findings this slice closes).

## Affected files
- `agents/lead-programmer.md`
- `agents/scribe.md`
- `agents/reviewer.md`
- `agents/spec-master.md`
- `skills/version-stamp-discipline/SKILL.md`
- `CONTEXT.md` (line 150 entry)
- `.claude-plugin/plugin.json` (version 0.31.167 -> 0.31.168)
- `package.json` (version 0.31.167 -> 0.31.168)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, `.claude/persona-config.json` (rendered by edit 11, never hand-edited)

## Ordered edits
1. file: `agents/lead-programmer.md`
   anchor: line matching `red-green-refactor loop (write the failing test`
   before:
   ~~~
     preloaded `antislop:tdd` red-green-refactor loop (write the failing test
     first). For hard bugs, invoke
   ~~~
   after:
   ~~~
     preloaded `antislop:tdd` red-green-refactor loop (write the failing test
     first; in agent-teams mode, where `skills:` preloads are not applied, read
     the `tdd` skill's `SKILL.md` once before the first test). For hard bugs, invoke
   ~~~
   indent: 3
2. file: `agents/lead-programmer.md`
   anchor: line matching `bump and the same-commit CHANGELOG line naming it, per commit);`
   before:
   ~~~
     bump and the same-commit CHANGELOG line naming it, per commit); `violation`
     means a bump or its CHANGELOG line is missing (`offenders` names `sha:path`,
   ~~~
   after:
   ~~~
     bump and the same-commit CHANGELOG entry naming it, per commit); `violation`
     means a bump or its CHANGELOG entry is missing (`offenders` names `sha:path`,
   ~~~
   indent: 3
3. file: `agents/scribe.md`
   anchor: line matching `CHANGELOG line naming it, per commit);`
   before:
   ~~~
     CHANGELOG line naming it, per commit); `violation` means a bump or its
     CHANGELOG line is missing (`offenders` names `sha:path`) and must be fixed
   ~~~
   after:
   ~~~
     CHANGELOG entry naming it, per commit); `violation` means a bump or its
     CHANGELOG entry is missing (`offenders` names `sha:path`) and must be fixed
   ~~~
   indent: 3
4. file: `agents/reviewer.md`
   anchor: line matching `clears both the version bump and the CHANGELOG line). It changes no verdict rules beyond the`
   before:
   ~~~
     for its runnable P3 check (`ok` clears both the version bump and the CHANGELOG line). It changes no verdict rules beyond the
   ~~~
   after:
   ~~~
     for its runnable P3 check (`ok` clears both the version bump and the CHANGELOG entry). It changes no verdict rules beyond the
   ~~~
   indent: 3
5. file: `skills/version-stamp-discipline/SKILL.md`
   anchor: line matching `- every touching commit bumped the version and added its CHANGELOG line. Clears the whole P3 rule.`
   before:
   ~~~
   - `ok touched: yes` - every touching commit bumped the version and added its CHANGELOG line. Clears the whole P3 rule.
   - `ok touched: no` - the range touches no `agents/*.md` or `templates/*`; P3 does not apply and nothing is owed.
   - `violation` - a touching commit did not bump the version or did not add a CHANGELOG line naming it; `offenders` lists `sha:path`, and `sha:CHANGELOG.md` for a missing CHANGELOG line. Fix it in the same commit.
   ~~~
   after:
   ~~~
   - `ok touched: yes` - every touching commit bumped the version and added its CHANGELOG entry. Clears the whole P3 rule.
   - `ok touched: no` - the range touches no `agents/*.md` or `templates/*`; P3 does not apply and nothing is owed.
   - `violation` - a touching commit did not bump the version or did not add a CHANGELOG entry naming it; `offenders` lists `sha:path`, and `sha:CHANGELOG.md` for a missing CHANGELOG entry. Fix it in the same commit.
   ~~~
   indent: 3
6. file: `CONTEXT.md`
   anchor: line matching `discipline: for every touching commit that bumps the version the script also requires a same-commit CHANGELOG line naming it (unit skr-5, 2026-10-14).`
   before:
   ~~~
     discipline: for every touching commit that bumps the version the script also requires a same-commit CHANGELOG line naming it (unit skr-5, 2026-10-14).
   ~~~
   after:
   ~~~
     discipline: for every touching commit that bumps the version the script also requires a same-commit CHANGELOG entry naming it (detected as an added CHANGELOG.md line that names the version) (unit skr-5, 2026-10-14).
   ~~~
   indent: 3
7. file: `agents/spec-master.md`
   anchor: line matching `. Map the finished plan onto these sections when publishing.`
   before:
   ~~~
   Derived from mattpocock/skills (MIT, see `skills/THIRD-PARTY-NOTICES.md`): the `to-spec` PRD template, original archived at `docs/archive/skills/to-spec/`. Map the finished plan onto these sections when publishing.
   ~~~
   after:
   ~~~
   Derived from mattpocock/skills (MIT, Copyright (c) 2026 Matt Pocock; full license text in the antislop plugin's `skills/THIRD-PARTY-NOTICES.md`): the `to-spec` PRD template, original archived at `docs/archive/skills/to-spec/`. Map the finished plan onto these sections when publishing.
   ~~~
   indent: 3
8. file: `.claude-plugin/plugin.json`
   anchor: line matching `"version": "0.31.167",`
   before:
   ~~~
     "version": "0.31.167",
   ~~~
   after:
   ~~~
     "version": "0.31.168",
   ~~~
   indent: 3
9. file: `package.json`
   anchor: line matching `"version": "0.31.167",`
   before:
   ~~~
     "version": "0.31.167",
   ~~~
   after:
   ~~~
     "version": "0.31.168",
   ~~~
   indent: 3
10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Agent-teams TDD fallback, CHANGELOG entry wording, MIT credit (sfu-3, 0.31.168).** `agents/lead-programmer.md` tells a teammate (no `skills:` preload) to read the `tdd` skill's `SKILL.md` before the first test; `agents/lead-programmer.md`, `agents/scribe.md`, `agents/reviewer.md`, `skills/version-stamp-discipline/SKILL.md` and `CONTEXT.md` say "CHANGELOG entry", the canonical term; `agents/spec-master.md`'s PRD-template credit carries the MIT copyright line.
   ~~~
   indent: 3
11. command: `node bin/cli.js --update --force-render`
   expect: 0
12. command: `git add agents/lead-programmer.md agents/scribe.md agents/reviewer.md agents/spec-master.md skills/version-stamp-discipline/SKILL.md CONTEXT.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u .claude && git commit -m "fix(sfu-3): agent-teams TDD fallback, CHANGELOG entry wording, MIT credit (0.31.168) (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `templates/` (no template change; the protocol files are only re-stamped by the render)
- `adapters/` (the hand-maintained ports carry no preload concept)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `bash docs/plans/sfu-criteria/sfu-claims.sh sfu-3`
   exit: 0
   stdout: `sfu-claims: sfu-3 ok`
   mutation: skip edit 11; the .claude/agents/lead-programmer.md check prints count=0 want=1 and the script exits 1.
2. run: `tr -s '\n ' ' ' < .claude/agents/spec-master.md | grep -cF 'Copyright (c) 2026 Matt Pocock'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; the count is 0 and grep exits 1.
3. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;if(a!==b||a!=='0.31.168')process.exit(1);console.log('version-sync: ok')"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 9; package.json stays 0.31.167 and node exits 1.
4. run: `node bin/cli.js --update --force-render --dry-run | grep -c 'would be'`
   exit: 1
   stdout: `0`
   mutation: skip edit 11; the dry run lists the stale .claude/agents files and the count is above 0.
5. run: `bash docs/plans/skr-criteria/skr-live-refs.sh tdd-skill-invoke vsd-preload grill-me to-spec`
   exit: 0
   stdout: `skr-live-refs: to-spec hits=0`
   mutation: phrase edit 1 as "the `antislop:tdd` skill via the `Skill` tool"; the tdd-skill-invoke key reports a hit and the script exits 1.
6. run: `bash docs/plans/skr-criteria/skr-core.sh`
   exit: 0
   stdout: `skr-core: ok`
   mutation: skip edit 11; tests/filehashes-currency.test.js fails inside it and the script prints skr-core: FAIL.
7. run: `C=$(git log -1 --format=%H -F --grep='fix(sfu-3): '); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes old: 0.31.167 new: 0.31.168 offenders: -`
   mutation: skip the plugin.json edit; the line reads violation with the agents paths as offenders.
8. run: `C=$(git log -1 --format=%H -F --grep='fix(sfu-3): '); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; no commit has the subject, test -n fails and nothing prints.
9. run: `git diff --quiet HEAD -- agents skills CONTEXT.md .claude-plugin package.json CHANGELOG.md .claude/agents .claude/persona-protocol.md .claude/persona-protocol-slim.md .claude/protocol-digest.md`
   exit: 0
   stdout: `empty`
   mutation: skip edit 12; the edited files stay modified and git diff exits 1.

## Pre-resolved context
tdd: no persona prose and a version bump; sfu-claims.sh and the render checks are the checks
blast-radius: agents/lead-programmer.md:55, agents/lead-programmer.md:98, agents/scribe.md:47, agents/reviewer.md:122, agents/spec-master.md:301, skills/version-stamp-discipline/SKILL.md:30, CONTEXT.md:150
commit-message: fix(sfu-3): agent-teams TDD fallback, CHANGELOG entry wording, MIT credit (0.31.168) (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block was matched exactly once against the tree as the previous units leave it, by applying this plan's edits in order to a fresh clone of 7ae820e
review-packet:
~~~
unit: sfu-3
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract sfu-4: version-stamp-check CHANGELOG match hardening

Suggested model: sonnet

~~~~
Unit: sfu-4

## Objective
`changelog_adds_version` in `hooks/scripts/version-stamp-check.sh` reads the diff with `--no-color --no-ext-diff`, counts only added lines, matches the version with literal dots, and requires a whole version (no digit on the right; no digit or dot on the left), so 0.31.16 is not named by 0.31.166 or 10.31.16 while `v0.31.16` is. `tests/version-stamp-check.test.sh` gains cases (e) Half-2 pin, (f) context line, (g) literal dots, (h1)-(h3) boundaries, (i) color.ui=always, plus mutation controls mc8-mc13 that pin each fix. The `+++`-exclusion mutant is equivalent (the header is always `+++ b/CHANGELOG.md` or `+++ /dev/null`) and gets no fixture. TDD order: edits 1-2 (tests) first, run the suite and see it fail, then edits 3-4. No version bump (hooks are not version-stamped); edit 5 refreshes the `.claude/hooks` mirror and fileHashes.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-followups.md`. Criteria scripts and payloads: `docs/plans/sfu-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop` (the umbrella of the skr slice whose review findings this slice closes).

## Affected files
- `tests/version-stamp-check.test.sh` (anchors in edits 1-2)
- `hooks/scripts/version-stamp-check.sh` (anchors in edits 3-4)
- `.claude/hooks/scripts/version-stamp-check.sh` and `.claude/persona-config.json` (rendered by edit 5)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `expect_offender "(d) names the earlier commit"`
   insert-after:
   ~~~

   echo "-- CHANGELOG half hardening (sfu-4) --"
   run_case_color() {
     # run_case with color.ui=always forced on every git call the script makes
     if ! ( export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always; fail=0; run_case "$@"; exit "$fail" ); then
       fail=1
     fi
   }

   echo "chg e1" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.6
   changelog_line 0.3.6
   r_chg_e1=$(snap chglog-e1-own-line)
   echo "chg e2" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.7
   changelog_line 0.3.7
   snap chglog-e2-own-line > /dev/null
   r_chg_e="${r_chg_e1%%..*}..$(git -C "$repo" rev-parse HEAD)"
   run_case "(e) two compliant bumps, each line names only its own version" "ok" "$r_chg_e"

   changelog_line 0.3.8
   echo "notes" > "$repo/README.md"
   snap chglog-f-line-before-bump > /dev/null
   echo "chg f" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.8
   changelog_line unrelated
   r_chg_f=$(snap chglog-f-context-only)
   run_case "(f) version only on a context line" "violation" "$r_chg_f"

   echo "chg g" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.9
   printf '**entry (0x3y9).**\n' >> "$repo/CHANGELOG.md"
   r_chg_g=$(snap chglog-g-dots-literal)
   run_case "(g) 0x3y9 does not name 0.3.9" "violation" "$r_chg_g"

   echo "chg h1" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.10
   changelog_line 0.3.100
   r_chg_h1=$(snap chglog-h1-longer-right)
   run_case "(h1) 0.3.100 does not name 0.3.10" "violation" "$r_chg_h1"

   echo "chg h2" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.11
   changelog_line 10.3.11
   r_chg_h2=$(snap chglog-h2-longer-left)
   run_case "(h2) 10.3.11 does not name 0.3.11" "violation" "$r_chg_h2"

   echo "chg h3" > "$repo/agents/lead-programmer.md"
   plugin_version 0.3.12
   changelog_line v0.3.12
   r_chg_h3=$(snap chglog-h3-v-prefix)
   run_case "(h3) v0.3.12 names 0.3.12" "ok" "$r_chg_h3"

   run_case_color "(i) color.ui=always, compliant bump" "ok" "$r_chg_ok"
   ~~~
   indent: 3
2. file: `tests/version-stamp-check.test.sh`
   anchor: line matching `echo "-- offender collection is computed, not hardcoded (item 5) --"`
   before:
   ~~~
   echo "-- offender collection is computed, not hardcoded (item 5) --"
   ~~~
   after:
   ~~~
   if mutate added-line-filter-removed 's/l.startswith("+") and not l.startswith("+++")/not l.startswith("+++")/'; then
     run_case "(mc8) added-line filter removed: (f) should flip to" "ok" "$r_chg_f" "$MUTANT"
   fi

   if mutate escape-removed 's/re.escape(sys.argv\[1\])/sys.argv[1]/'; then
     run_case "(mc9) re.escape removed: (g) should flip to" "ok" "$r_chg_g" "$MUTANT"
   fi

   if mutate right-boundary-removed 's/ + r"(?!\[0-9\])"//'; then
     run_case "(mc10) right boundary removed: (h1) should flip to" "ok" "$r_chg_h1" "$MUTANT"
   fi

   if mutate left-boundary-removed 's/r"(?<!\[0-9.\])" + //'; then
     run_case "(mc11) left boundary removed: (h2) should flip to" "ok" "$r_chg_h2" "$MUTANT"
   fi

   if mutate half2-endpoint-version 's/changelog_adds_version "\$c" "\$cnew"/changelog_adds_version "$c" "$new_ver"/'; then
     run_case "(mc12) range-endpoint version passed: (e) should flip to" "violation" "$r_chg_e" "$MUTANT"
   fi

   if mutate no-color-removed 's/git diff --no-color --no-ext-diff --no-renames/git diff --no-renames/'; then
     run_case_color "(mc13) --no-color removed: (i) should flip to" "violation" "$r_chg_ok" "$MUTANT"
   fi

   echo "-- offender collection is computed, not hardcoded (item 5) --"
   ~~~
   indent: 3
3. file: `hooks/scripts/version-stamp-check.sh`
   anchor: line matching `# changelog_adds_version <commit> <version>: succeeds iff <commit> adds a CHANGELOG.md`
   before:
   ~~~
   # changelog_adds_version <commit> <version>: succeeds iff <commit> adds a CHANGELOG.md
   # line (not the +++ header) containing <version> as a fixed string. The diff is
   # taken against the first parent, like version_at "$c^", so a merge commit counts
   # the lines its branch added. The last grep reads all of its input (no -q), so
   # pipefail never sees a SIGPIPE from an early exit.
   changelog_adds_version() {
     git diff --no-renames "$1^" "$1" -- CHANGELOG.md 2>/dev/null \
       | grep '^+' | grep -v '^+++' | grep -F -- "$2" > /dev/null
   }
   ~~~
   after:
   ~~~
   # changelog_adds_version <commit> <version>: succeeds iff <commit> adds a CHANGELOG.md
   # line (a `+` line, not the +++ header) naming <version> as a whole version: the
   # dots are literal, and the match may not continue into a digit on the right or
   # into a digit or dot on the left, so 0.31.16 is not named by 0.31.166 or 10.31.16,
   # while v0.31.16 and (0.31.16) are. The diff is taken against the first parent,
   # like version_at "$c^", so a merge commit counts the lines its branch added.
   # --no-color and --no-ext-diff keep a user's color.ui=always or diff.external
   # from rewriting the lines this parses. python3 reads all of its input, so
   # pipefail never sees a SIGPIPE from an early exit.
   changelog_adds_version() {
     git diff --no-color --no-ext-diff --no-renames "$1^" "$1" -- CHANGELOG.md 2>/dev/null \
       | python3 -c '
   import re, sys
   pat = re.compile(r"(?<![0-9.])" + re.escape(sys.argv[1]) + r"(?![0-9])")
   lines = sys.stdin.read().splitlines()
   sys.exit(0 if any(l.startswith("+") and not l.startswith("+++") and pat.search(l[1:]) for l in lines) else 1)
   ' "$2"
   }
   ~~~
   indent: 3
4. file: `hooks/scripts/version-stamp-check.sh`
   anchor: line matching `# containing, as a fixed string, the version read from that commit's own`
   before:
   ~~~
   # containing, as a fixed string, the version read from that commit's own
   ~~~
   after:
   ~~~
   # naming, as a whole version (see changelog_adds_version), the version read from that commit's own
   ~~~
   indent: 3
5. command: `node bin/cli.js --update --force-render`
   expect: 0
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **version-stamp-check CHANGELOG match hardened (sfu-4).** `hooks/scripts/version-stamp-check.sh` reads the CHANGELOG diff with `--no-color --no-ext-diff`, counts added lines only, and matches the version literally as a whole version (0.31.16 is no longer named by 0.31.166 or 10.31.16; `v0.31.16` still is); `tests/version-stamp-check.test.sh` gains cases (e)-(i) and mutation controls mc8-mc13, which pin every mutant the skr-5 review found surviving except the `+++`-exclusion one, an equivalent mutant.
   ~~~
   indent: 3
7. command: `git add hooks/scripts/version-stamp-check.sh tests/version-stamp-check.test.sh CHANGELOG.md && git add -u .claude && git commit -m "fix(sfu-4): version-stamp-check CHANGELOG match hardening (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/` and `templates/` (no version-stamped change in this unit)
- `hooks/hooks.json` (the script stays unregistered, a reviewer-invoked helper)
- `.claude/persona-config.json` by hand (only `node bin/cli.js --update --force-render` writes it)

## Acceptance criteria
1. run: `bash tests/version-stamp-check.test.sh`
   exit: 0
   stdout: `every line OK, the last check is (mc6)`
   mutation: revert edit 3; cases (h1), (h2) and (i) print FAIL, mc8-mc11 and mc13 report that their sed matched nothing, and the suite exits 1. Cases (f) and (g) still print OK: each is a regression pin for the rewritten matcher, not a red-first test (corrected 2026-10-14, unit lov-1).
2. run: `bash tests/version-stamp-check.test.sh | grep -cE '^OK   [(](e|f|g|h1|h2|h3|i|mc8|mc9|mc10|mc11|mc12|mc13)[)]'`
   exit: 0
   stdout: `13`
   mutation: skip edit 2; the six mc8-mc13 lines are missing and the count is 7.
3. run: `bash hooks/scripts/version-stamp-check.sh e9a2bf3~1..879c678`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes old: 0.31.162 new: 0.31.167 offenders: -`
   mutation: make the right boundary (?![0-9.]); a real CHANGELOG line such as (skr-6, 0.31.167). no longer matches and the line reads violation.
4. run: `diff -q hooks/scripts/version-stamp-check.sh .claude/hooks/scripts/version-stamp-check.sh`
   exit: 0
   stdout: `empty`
   mutation: skip edit 5; the mirror differs and diff exits 1.
5. run: `node tests/filehashes-currency.test.js`
   exit: 0
   stdout: `exit 0, no FAIL line`
   mutation: skip edit 5; the recorded hash of the mirror is stale and the test exits 1.
6. run: `bash docs/plans/skr-criteria/skr-core.sh`
   exit: 0
   stdout: `skr-core: ok`
   mutation: skip edit 5; the hook mirror parity check prints FAIL.
7. run: `C=$(git log -1 --format=%H -F --grep='fix(sfu-4): '); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
8. run: `C=$(git log -1 --format=%H -F --grep='fix(sfu-4): '); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; no commit has the subject, test -n fails and nothing prints.
9. run: `git diff --quiet HEAD -- hooks tests .claude/hooks CHANGELOG.md`
   exit: 0
   stdout: `empty`
   mutation: skip edit 7; the edited files stay modified and git diff exits 1.

## Pre-resolved context
tdd: yes tests/version-stamp-check.test.sh
blast-radius: hooks/scripts/version-stamp-check.sh:64, hooks/scripts/version-stamp-check.sh:125, tests/version-stamp-check.test.sh:128, tests/version-stamp-check.test.sh:229
commit-message: fix(sfu-4): version-stamp-check CHANGELOG match hardening (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block was matched exactly once against the tree as the previous units leave it, by applying this plan's edits in order to a fresh clone of 7ae820e
review-packet:
~~~
unit: sfu-4
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

### Contract sfu-5: offline resync test, relative-link test and the 55 link fixes

Suggested model: haiku

~~~~
Unit: sfu-5

## Objective
Two new tests, registered in `tests/validate.sh`: `tests/resync-vendored-skills-offline.test.sh` (FILES/SKILL_ORDER of `scripts/resync-vendored-skills.sh` checked without the network) and `tests/doc-relative-links.test.js` (every relative markdown link in the maintained docs resolves to a tracked file). The 55 broken links the link test finds are fixed: 45 root-relative links in `docs/harness-glossary.md`, 7 in `.claude/wiki/modules/hooks.md` (one also named a placeholder ADR), 1 wrong ADR-0010 file name in `CONTEXT.md`, and ADR-0020's two links to untracked per-clone review records, which become plain code spans. TDD order: create the tests (edits 1-3) and run the link test red (55 broken) before edits 4-7. No version bump.

## Retrieval
Fast path, no tracker issue: this contract is the `## Dispatch contracts` block for this unit in `docs/plans/2026-10-14-skills-audit-followups.md`. Criteria scripts and payloads: `docs/plans/sfu-criteria/`. Background only: `gh issue view 530 --repo Storreslara/AntiSlop` (the umbrella of the skr slice whose review findings this slice closes).

## Affected files
- `tests/resync-vendored-skills-offline.test.sh` (new, edits 1-2)
- `tests/doc-relative-links.test.js` (new, edits 1 and 3)
- `docs/harness-glossary.md` (edit 4, 45 link targets)
- `.claude/wiki/modules/hooks.md` (edit 5, 8 link targets)
- `CONTEXT.md` (edit 6, line 501)
- `docs/adr/0020-write-edit-content-not-scanned.md` (edit 7, lines 76-77, link syntax only)
- `tests/validate.sh` (edit 8, two sections after the context-glossary-links section)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. command: `touch tests/resync-vendored-skills-offline.test.sh tests/doc-relative-links.test.js && chmod +x tests/resync-vendored-skills-offline.test.sh`
   expect: 0
2. file: `tests/resync-vendored-skills-offline.test.sh`
   anchor: the empty file created by edit 1
   insert-after:
   ~~~
   #!/usr/bin/env bash
   # Offline checks for scripts/resync-vendored-skills.sh (unit sfu-5). The --check
   # run needs the network; these read only the script's own FILES table and the
   # tree, so a renamed or deleted local copy fails here without a fetch.
   set -uo pipefail
   cd "$(dirname "$0")/.."
   SCRIPT=scripts/resync-vendored-skills.sh
   FORKED="grilling tdd diagnosing-bugs improve-codebase-architecture"
   fail=0
   ok() { echo "OK   $1"; }
   no() { echo "FAIL $1"; fail=1; }

   rows="$(sed -n '/^FILES="$/,/^"$/p' "$SCRIPT" | sed '1d;$d')"
   order="$(sed -n 's/^SKILL_ORDER="\(.*\)"$/\1/p' "$SCRIPT")"
   [ -n "$rows" ] || no "FILES table not found in $SCRIPT"
   [ -n "$order" ] || no "SKILL_ORDER not found in $SCRIPT"

   while IFS=: read -r skill type local upstream extra; do
     [ -n "$skill" ] || continue
     [ -z "$extra" ] || no "$skill row has more than four fields"
     case "$type" in fm|fm-noflag|doc|raw) ;; *) no "$skill row type '$type' unknown" ;; esac
     if git ls-files --error-unmatch -- "$local" >/dev/null 2>&1; then ok "$skill $local is tracked"; else no "$skill $local is not tracked"; fi
     case "$upstream" in skills/*/"${skill}"/*) ;; *) no "$skill upstream path '$upstream' is not under skills/<group>/$skill/" ;; esac
     case " $FORKED " in
       *" $skill "*) want="docs/archive/skills/$skill/" ;;
       *) want="skills/$skill/" ;;
     esac
     case "$local" in "$want"*) ;; *) no "$skill local path '$local' is not under $want" ;; esac
   done <<< "$rows"

   in_files="$(printf '%s\n' "$rows" | cut -d: -f1 | sort -u | tr '\n' ' ')"
   in_order="$(printf '%s\n' $order | sort -u | tr '\n' ' ')"
   [ "$in_files" = "$in_order" ] && ok "FILES and SKILL_ORDER name the same skills" || no "FILES skills '$in_files' differ from SKILL_ORDER '$in_order'"
   n="$(printf '%s\n' $order | wc -l | tr -d ' ')"
   [ "$n" = 7 ] && ok "7 drift-tracked skills" || no "SKILL_ORDER has $n skills, the runbook and NOTICES say 7"
   grep -q 'vendors 7 skills' docs/maintenance/resync-vendored-skills.md && ok "runbook says 7" || no "runbook does not say 'vendors 7 skills'"
   for s in $FORKED; do
     grep -q "^<!-- Derived from mattpocock/skills " "skills/$s/SKILL.md" && ok "skills/$s/SKILL.md has a Derived from header" || no "skills/$s/SKILL.md lacks a Derived from header"
   done

   [ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"
   exit "$fail"
   ~~~
   indent: 3
3. file: `tests/doc-relative-links.test.js`
   anchor: the empty file created by edit 1
   insert-after:
   ~~~
   #!/usr/bin/env node
   'use strict';
   // Unit sfu-5: every relative markdown link in the maintained docs resolves to a
   // tracked file or directory, relative to the linking file's own directory (the way GitHub
   // renders it). Fenced code is skipped. URLs and <angle> targets are skipped.
   const fs = require('fs');
   const path = require('path');
   const { execFileSync } = require('child_process');

   const ROOT = path.resolve(__dirname, '..');
   const SCOPE = ['CONTEXT.md', 'docs/harness-glossary.md', 'docs/trust-model.md', 'docs/adr',
     '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills'];

   const git = (args) => execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' }).split('\0').filter(Boolean);
   const tracked = new Set(git(['ls-files', '-z']));
   for (const t of [...tracked]) {
     for (let d = path.posix.dirname(t); d !== '.'; d = path.posix.dirname(d)) tracked.add(d);
   }
   const files = git(['ls-files', '-z', '--', ...SCOPE]).filter((f) => f.endsWith('.md'));
   let links = 0;
   let broken = 0;
   for (const f of files) {
     const text = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^\s*(```|~~~)[\s\S]*?^\s*\1/gm, '');
     for (const m of text.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)) {
       const target = m[1];
       if (/^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith('<')) continue;
       links += 1;
       const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(f), decodeURI(target))).replace(/\/$/, '');
       if (!tracked.has(resolved)) {
         broken += 1;
         console.log(`FAIL ${f}: ${target}`);
       }
     }
   }
   if (links === 0) {
     console.log('FAIL no links found: the scope list matches nothing');
     process.exit(1);
   }
   if (broken > 0) {
     console.log(`doc-relative-links: ${broken} broken of ${links} links`);
     process.exit(1);
   }
   console.log(`doc-relative-links: ok (${links} links in ${files.length} files)`);
   ~~~
   indent: 3
4. command: `python3 -c "import pathlib; p=pathlib.Path('docs/harness-glossary.md'); t=p.read_text(); assert t.count('](docs/adr/')==42 and t.count('](.claude/wiki/')==3; p.write_text(t.replace('](docs/adr/','](adr/').replace('](.claude/wiki/','](../.claude/wiki/'))"`
   expect: 0
5. command: `python3 -c "import pathlib; p=pathlib.Path('.claude/wiki/modules/hooks.md'); t=p.read_text(); assert t.count('](../../')==7 and t.count('00NN-marker-commit-attribution')==1; p.write_text(t.replace('](../../','](../../../').replace('00NN-marker-commit-attribution','0023-marker-commit-attribution'))"`
   expect: 0
6. file: `CONTEXT.md`
   anchor: line matching `[[Writer tier]], [ADR-0010](docs/adr/0010-haiku-as-default-implementer-model.md),`
   before:
   ~~~
     [[Writer tier]], [ADR-0010](docs/adr/0010-haiku-as-default-implementer-model.md),
   ~~~
   after:
   ~~~
     [[Writer tier]], [ADR-0010](docs/adr/0010-implementer-haiku-default.md),
   ~~~
   indent: 3
7. file: `docs/adr/0020-write-edit-content-not-scanned.md`
   anchor: line matching `](../../.claude/reviewed/gh-281-detection.fail) — reviewer's finding that the incident file contained an unsafe bypass technique`
   before:
   ~~~
     - [`.claude/reviewed/gh-281-detection.fail`](../../.claude/reviewed/gh-281-detection.fail) — reviewer's finding that the incident file contained an unsafe bypass technique
     - [`.claude/reviewed/gh-281-detection.pass`](../../.claude/reviewed/gh-281-detection.pass) — reviewer's approval of the remediation
   ~~~
   after:
   ~~~
     - `.claude/reviewed/gh-281-detection.fail` (per-clone review state, not tracked) — reviewer's finding that the incident file contained an unsafe bypass technique
     - `.claude/reviewed/gh-281-detection.pass` (per-clone review state, not tracked) — reviewer's approval of the remediation
   ~~~
   indent: 3
8. file: `tests/validate.sh`
   anchor: line matching `echo "== CONTEXT.md / docs/harness-glossary.md: [[link]] integrity (Node) =="`
   before:
   ~~~
   echo
   echo "== CONTEXT.md / docs/harness-glossary.md: [[link]] integrity (Node) =="
   if node tests/context-glossary-links.test.js; then
     echo "OK   tests/context-glossary-links.test.js"
   else
     echo "FAIL tests/context-glossary-links.test.js"
     fail=1
   fi
   ~~~
   after:
   ~~~
   echo
   echo "== CONTEXT.md / docs/harness-glossary.md: [[link]] integrity (Node) =="
   if node tests/context-glossary-links.test.js; then
     echo "OK   tests/context-glossary-links.test.js"
   else
     echo "FAIL tests/context-glossary-links.test.js"
     fail=1
   fi

   echo
   echo "== docs: relative markdown links resolve to tracked files (Node, sfu-5) =="
   if node tests/doc-relative-links.test.js; then
     echo "OK   tests/doc-relative-links.test.js"
   else
     echo "FAIL tests/doc-relative-links.test.js"
     fail=1
   fi

   echo
   echo "== scripts/resync-vendored-skills.sh: offline FILES/SKILL_ORDER checks (sfu-5) =="
   if bash tests/resync-vendored-skills-offline.test.sh; then
     echo "OK   tests/resync-vendored-skills-offline.test.sh"
   else
     echo "FAIL tests/resync-vendored-skills-offline.test.sh"
     fail=1
   fi
   ~~~
   indent: 3
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after:
   ~~~

   **Offline resync table test and relative-link test (sfu-5).** `tests/resync-vendored-skills-offline.test.sh` checks the FILES/SKILL_ORDER table of `scripts/resync-vendored-skills.sh` without the network; `tests/doc-relative-links.test.js` checks that every relative markdown link in the maintained docs resolves to a tracked file. Both are registered in `tests/validate.sh`. The 55 broken links it found are fixed: `docs/harness-glossary.md` links are now relative to `docs/`, `.claude/wiki/modules/hooks.md` climbs three levels and names ADR-0023, `CONTEXT.md` names the real ADR-0010 file, and ADR-0020's two per-clone review-record links become plain code spans.
   ~~~
   indent: 3
10. command: `git add tests/resync-vendored-skills-offline.test.sh tests/doc-relative-links.test.js tests/validate.sh docs/harness-glossary.md .claude/wiki/modules/hooks.md CONTEXT.md docs/adr/0020-write-edit-content-not-scanned.md CHANGELOG.md && git commit -m "test(sfu-5): offline resync table test and relative-link test (#530 follow-up)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/validate-lanes.sh` and `tests/reviewed-dir-leak-guard.test.sh` (another session's files)
- `scripts/resync-vendored-skills.sh` (tested, not changed)
- `.claude/agents/` and `adapters/` (their broken links are out of the test scope by design)

## Acceptance criteria
1. run: `bash tests/resync-vendored-skills-offline.test.sh`
   exit: 0
   stdout: `resync-vendored-skills-offline: ok`
   mutation: point the grilling:fm: FILES row of scripts/resync-vendored-skills.sh at skills/grilling/SKILL.md; the local-path check prints FAIL and the test exits 1.
2. run: `node tests/doc-relative-links.test.js`
   exit: 0
   stdout: `doc-relative-links: ok (162 links in 80 files)`
   mutation: skip edit 4; the test prints doc-relative-links: 45 broken of 162 links and exits 1.
3. run: `grep -cE 'tests/(doc-relative-links[.]test[.]js|resync-vendored-skills-offline[.]test[.]sh)' tests/validate.sh`
   exit: 0
   stdout: `6`
   mutation: skip edit 8; the count is 0 and grep exits 1.
4. run: `bash docs/plans/skr-criteria/skr-glossary.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage`
   exit: 0
   stdout: `skr-glossary: fail-triage ok`
   mutation: delete an archive pointer line from docs/harness-glossary.md in edit 4; the script exits 1.
5. run: `bash docs/plans/skr-criteria/skr-core.sh`
   exit: 0
   stdout: `skr-core: ok`
   mutation: break a [[link]] in CONTEXT.md; tests/context-glossary-links.test.js fails inside it and the script prints skr-core: FAIL.
6. run: `bash tests/validate-lanes.sh --lanes 6`
   exit: 0
   stdout: `no FAIL line`
   mutation: skip edit 4; the new doc-relative-links section prints FAIL and the run exits 1.
7. run: `C=$(git log -1 --format=%H -F --grep='test(sfu-5): '); bash hooks/scripts/version-stamp-check.sh "$C~1..$C"`
   exit: 0
   stdout: `version-stamp-check: ok touched: no old: - new: - offenders: -`
   mutation: add any agents/*.md change to this commit without a bump; the line reads violation.
8. run: `C=$(git log -1 --format=%H -F --grep='test(sfu-5): '); test -n "$C" && git log -1 --format=%B "$C" | grep -c "^Co-Authored-By: Claude "`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no commit has the subject, test -n fails and nothing prints.
9. run: `git diff --quiet HEAD -- tests docs .claude/wiki CONTEXT.md CHANGELOG.md`
   exit: 0
   stdout: `empty`
   mutation: skip edit 10; the edited files stay modified and git diff exits 1.

## Pre-resolved context
tdd: yes tests/doc-relative-links.test.js
blast-radius: docs/harness-glossary.md:1669, .claude/wiki/modules/hooks.md:25, CONTEXT.md:501, docs/adr/0020-write-edit-content-not-scanned.md:76, tests/validate.sh:921
commit-message: test(sfu-5): offline resync table test and relative-link test (#530 follow-up)
trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> (the orchestrator substitutes the dispatched tier's own attribution line; the criterion greps only the Co-Authored-By: Claude prefix)
measured: every before block was matched exactly once against the tree as the previous units leave it, by applying this plan's edits in order to a fresh clone of 7ae820e
review-packet:
~~~
unit: sfu-5
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written (a before block that does not match, a command that exits non-zero when expect is 0, a criterion that does not hold), STOP and report a spec gap; do not improvise.
~~~~

## Open Questions

All resolved 2026-10-14 by the user (via the orchestrator's AskUserQuestion), each as recommended.

1. RESOLVED: link-check scope A, fix all 55 broken links and add the test. Effect on the spec: sfu-5 carries the four link-fix edits and the full-scope `tests/doc-relative-links.test.js`.
2. RESOLVED: close the substring match. Effect on the spec: sfu-4 carries the boundary rule, cases (h1)-(h3) and controls mc10/mc11.
3. RESOLVED: spec-master fixes its own stale memory notes now, in a separate commit. Done in `e6b9ee5 docs(agent-memory): retarget spec-master notes off retired grill-me and to-spec`: `antislop-spec-master/feedback_resume_from_artifact.md:11` now says "do not re-run the `grilling` session"; `spec-master/project_to_spec_slash_only.md` is rewritten as superseded (publish via the PRD-template appendix, grill with `antislop:grilling`), and its MEMORY.md index line is updated. Effect on the spec: no unit.
4. RESOLVED: include "Copyright (c) 2026 Matt Pocock". Effect on the spec: sfu-3 edit 7 and its criterion 2.

## Self-check
- CHK1: Does every Goal clause map to a step criterion? — PASS. Each F-row names its unit, and each unit's criteria cover its F-rows: sfu-claims.sh for F1-F21, the test counts for F22, and the two tests for F23-F24.
- CHK2: Is the vacuous-criteria risk for prose units addressed (criteria that pass whether the prose is true or not)? — PASS. sfu-claims.sh is claim-anchored, and all of its checks were run red at HEAD.
- CHK3: Is the link-check scope decided? — PASS (Open Question 1 resolved: option A)
- CHK4: Is the substring behaviour of version-stamp-check decided? — PASS (Open Question 2 resolved: closed)
- CHK5: Is the disposition of the stale agent-memory notes decided? — PASS (Open Question 3 resolved; done in e6b9ee5)
- CHK6: Is the MIT credit change in or out? — PASS (Open Question 4 resolved: included)
- CHK7: Do steps 1 and 3 agree on CONTEXT.md:150? — PASS. Only step 3 edits :150, and step 1 does not list it.
- CHK8: Does each unit that touches agents/*.md satisfy P3 per commit? — PASS. Only sfu-3 does; it has the bump, the CHANGELOG entry, `--update --force-render`, and a criterion that runs version-stamp-check.sh over its own commit.
- CHK9: Is every per-unit version-stamp criterion independent of HEAD (the #541 lesson)? — PASS. The range is taken from the unit's commit by subject grep.
- CHK10: Does any new text risk the C4.1 phrase sweep or the reviewed-path gate? — PASS. R2 and R3 name both, and the ADR-0020 edit is an Edit-tool before/after.
- CHK11: Are the nine-element contracts present for the fast path? — PASS. Five fenced contracts, each opening `Unit: sfu-N`; `node bin/contract-guard.js` scores all five `haiku ... score=7/7`.
- CHK12: Does every before block match exactly once against the tree the earlier units leave? — PASS (applied in order to a fresh clone; see Context).
- CHK13: Does every criterion hold after its unit, and is the suite green at the end? — PASS (all criteria held in the clone; `tests/validate-lanes.sh --lanes 6` 118 sections, no FAIL).
- CHK14: Does any unit edit a skill that an adapter port inlines without editing the port? — FAIL (missing) — revised in place: sfu-2 edits 17-18 update both reviewer ports, and sfu-2 criterion 6 runs `tests/adapter-skill-parity.test.js`.
- CHK15: Is the sfu-3 bump rule complete (plugin.json and package.json to 0.31.168, a CHANGELOG entry naming it in the same commit, `node bin/cli.js --update --force-render` before that commit, a version-stamp-check criterion over that commit)? — PASS (sfu-3 edits 8-12; criteria 3, 4, 7).
- CHK16: Is sfu-4 tagged no lower than sonnet? — PASS (Suggested model: sonnet; R9).

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

## Corrections

- 2026-10-14 (unit lov-1): the sfu-4 notes said cases (f) and (g) fail against the pre-sfu-4 script (Step 4 edit 1 and its first criterion, contract criterion 1). They print OK there, because that script already read added lines only and matched with `grep -F`; each is a regression pin for the rewritten matcher, not a red-first test. Only (h1), (h2) and (i) are red against it. The `+++`-exclusion mutant was called equivalent (Clarifications, contract sfu-4 Objective); it is not, see the corrected Clarifications line. Contract criterion 1 and the Clarifications line are corrected in place; Step 4 and the contract Objective keep their original text.
