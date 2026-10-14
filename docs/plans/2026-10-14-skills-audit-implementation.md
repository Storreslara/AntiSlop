# Skills audit implementation: retire, merge, fork-and-own, archive originals

Status: FINAL (2026-10-14). Open Questions round 1 answered by the user (all
four resolved; see Clarifications). 11 units → `task-master` (standard path).
Unit prefix: `skr`. Baseline: `12227b4`. Plugin version at baseline: `0.31.162`.
Criteria scripts: `docs/plans/skr-criteria/` (each was run red at baseline, or
mutation-proven in a scratch worktree, by spec-master on 2026-10-14).

## Goal

Implement the skills audit's approved scope:

- G1. Delete `skills/grill-me`, `skills/grill-with-docs`, `skills/code-review`
  and `.claude/skills/{debug-issue,explore-codebase,refactor-safely,review-changes}`.
- G2. Merge `to-spec` into spec-master prose (PRD template kept as an
  appendix), `to-tickets` + `pathfinder` into one slicing skill based on
  `pathfinder`, and `fail-triage` into spec-master's debug-spec bullet.
- G3. Rewrite `grilling` (one-shot subagent reality),
  `version-stamp-discipline` (fix the Half-2 defect, mechanize Half 2 in
  `version-stamp-check.sh`, stop preloading it), and
  `improve-codebase-architecture` (no HTML, CDN, `xdg-open` or ask-user).
- G4. Trim `tdd` (no "confirm seams with the user", no `code-review`
  reference, no lead-programmer double load), and `coding-discipline`,
  `roast-work`, `ubiquitous-language` (Step 10); `domain-modeling` and
  `codebase-design` are re-derived as KEEP, unchanged (Clarifications).
- G5. Keep with fixes: `diagnosing-bugs` (hitl template path), `handoff`
  (on demand, not preloaded), `install-antislop` (shorter description,
  re-verified 2.1.x claims).
- G6. Fix every reference the above breaks: persona `skills:` lists, persona
  prose, adapter inlined copies, the `.claude/skills` mirror, CONTEXT.md and
  harness glossary entries, the vendoring runbook, NOTICES and the resync
  script.
- G7. User requirement: every skill that is deleted, merged away or
  rewritten (and, by the uniform rule below, every skill whose text changes)
  keeps its ORIGINAL, byte-identical, in `docs/archive/skills/<name>/`, where
  nothing loads, lists, mirrors, hashes or ships it.

Goal-to-criterion map (every clause has a runnable check):

| Goal | Steps | Criterion |
|---|---|---|
| G1 | 1, 2, 6 | `skr-discovery.sh` exact skill sets; `skr-live-refs.sh grill-me grill-with-docs code-review` |
| G2 | 3, 4 | `skr-discovery.sh`; `skr-live-refs.sh to-spec to-tickets fail-triage`; appendix and VERIFY/CATEGORIZE/BRIEF greps |
| G3 | 5, 7, 8 | new `tests/version-stamp-check.test.sh` cases; `skr-live-refs.sh vsd-preload`; grilling and ICA content greps |
| G4 | 6, 10 | `skr-live-refs.sh seams-confirm code-review tdd-skill-invoke`; `tests/adapter-skill-parity.test.js`; AC10.1-AC10.6 |
| G5 | 6, 9 | `skr-live-refs.sh handoff-preload`; hitl path grep; description length and version-floor checks |
| G6 | every step | `skr-core.sh`; `skr-glossary.sh`; `resync-vendored-skills.sh --check` |
| G7 | every step | `skr-archive-verify.sh <names>` |

## Context

### The audit report is missing

The dispatch names the audit report at
`/tmp/claude-1000/-home-sebas-AntiSlop/49048167-.../scratchpad/skills-audit-report.md`.
That file does not exist: the scratchpad directory is empty, and a `find`
over `/tmp/claude-1000` found no audit report anywhere. This plan is built
from the approved-scope list in the dispatch, with every claim it depends on
re-verified against the tree. The per-skill TRIM detail for
`coding-discipline`, `roast-work`, `ubiquitous-language`, `domain-modeling`
and `codebase-design` was only in the report. The user answered by having it
re-derived (Clarifications, category 1); Step 10 is built from that
re-derivation after spec-master re-verified it.

### Verified facts (2026-10-14, at 12227b4)

- **Nothing enumerates below depth 1.** `tests/validate.sh:220` globs
  `skills/*/SKILL.md`; `:231-243` resolves persona `skills:` tokens to
  `skills/<x>/SKILL.md`; `:361-371` diffs each `.claude/skills/<d>/` against
  `skills/<d>` and SKIPs dirs with no `skills/` source (the four
  graph-generated ones). `bin/cli.js` copies only `skills/install-antislop`
  and `skills/coding-discipline` (`:2517-2518`). `package.json` `files` names
  only those two skills (ADR-0022). `plugin.json`/`marketplace.json` have no
  skills key. No hook globs `skills/`; `agent-audit.sh`'s SKILLS inventory
  comes from transcripts, not the filesystem. No tool enumerates `docs/`.
- **Claude Code discovery** (claude-code-guide, docs + changelog): the
  documented layout is `skills/<name>/SKILL.md`; nested `.claude/skills`
  directories load since 2.1.178 when working on files there; recursion
  deeper than one level under `skills/` is undocumented. So
  `skills/_archive/<x>/SKILL.md` is unverifiable, and it would also ship with
  the plugin over git and marketplace. `docs/archive/skills/` is outside every
  discovery root.
- **Mirror and parity tests.** `.claude/skills` vs `skills/` byte identity
  (validate.sh `:361`); adapter inlined copies via
  `tests/adapter-skill-parity.test.js` ROWS: `coding-discipline` and `tdd` in
  both lead-programmer ports, `roast-work` in both reviewer ports.
  `tests/ubiquitous-language.test.js` checks that skill's structure. No skill
  is in `persona-config.json` `fileHashes`.
- **Persona preloads.** lead-programmer: `coding-discipline, handoff, tdd,
  version-stamp-discipline`. milestone-auditor: `grilling,
  ubiquitous-language`. reviewer: `roast-work, ubiquitous-language`. scribe:
  `domain-modeling`. spec-master: `grill-with-docs, grilling, domain-modeling,
  to-spec, fail-triage, ubiquitous-language`. task-master: `to-tickets,
  pathfinder`.
- **References the explorer sweep missed.** `agents/reviewer.md:124-132`
  invokes `antislop:code-review` on demand (advisory). Deleting
  `code-review` must remove that bullet. `agents/task-master.md:290` uses
  `skills/to-tickets/SKILL.md` as a "Do NOT touch" path in a worked contract
  example that `tests/contract-examples.test.js` scores 7/7 (any path with
  `/` or `.` keeps R6 green). 25 `tests/fixtures/contract-score/*.md` files
  use the same string as inert sample text; `bin/contract-score.js` R6 never
  checks existence, so the fixtures stay untouched.
- **Vendored drift tracking.** `scripts/resync-vendored-skills.sh` FILES
  byte-diffs 9 skills against upstream `e9fcdf9`: `grill-me`,
  `grill-with-docs`, `grilling`, `handoff`, `tdd` (+`tests.md`,
  `mocking.md`), `diagnosing-bugs` (+`scripts/hitl-loop.template.sh`),
  `improve-codebase-architecture` (+`HTML-REPORT.md`), `codebase-design`
  (+2 docs), `domain-modeling` (+2 docs). REPOINT_SKILLS (never diffed):
  `to-spec to-tickets code-review`. `--check` exits 0 at baseline (network
  available). It is not run by `tests/validate.sh`.
- **Half-2 defect, confirmed.** `skills/version-stamp-discipline/SKILL.md:37`
  reads the version from the working tree (`jq -r .version
  .claude-plugin/plugin.json`), not from `<sha>`, so for any commit but the
  last bump it greps for the wrong version; the unescaped dots also make it a
  regex. `version-stamp-check.sh` is not wired as a hook; personas run it by
  hand. Measured: of the 124 history commits that touch `agents/*.md` or
  `templates/*` and bump the version, 123 add a CHANGELOG line containing
  that commit's own version (fixed-string). The only miss is `e21c9ec`
  (0.1.0, the initial import).
- **Persona-config refusal, confirmed.** `harness-integrity-gate.sh` refused
  this session's `git show ... .claude/persona-config.json` and a piped
  `grep ... .claude/persona-config.json | head`; a bare `grep -c` passed.
  `agents/reviewer.md` already carries the sanctioned phrasing ("read the
  key from `.claude/persona-config.json` with the `Read` tool (a Bash command
  naming that file is refused by `harness-integrity-gate.sh`)"). Skills that
  say "check `.claude/persona-config.json`": `to-spec:9`, `to-tickets:11,60`,
  `code-review`, `install-antislop:48,65,105,161,175` and
  `hook-verification.md:14`.
- **`.claude/skills/{debug-issue,explore-codebase,refactor-safely,review-changes}`**
  are git-tracked, written by `code-review-graph install --platform
  claude-code` (install-antislop `:149-153`), and call graph MCP tools that
  only the `explorer` can reach (ADR-0001). install-antislop `:167-171` tells
  consumers they "can stay".
- **hitl path.** `skills/diagnosing-bugs/SKILL.md:30,59` say
  `scripts/hitl-loop.template.sh`. The file is at
  `skills/diagnosing-bugs/scripts/`. From the repo root (an agent's cwd),
  that relative path names the repo's own unrelated `scripts/` directory.
- **2.1.x claims** (`install-antislop:27-34`, checked by claude-code-guide
  against the changelog and docs): nesting arrived in 2.1.172 but was off by
  default in 2.1.217-2.1.218 and defaults to depth 3 since 2.1.219 (claim
  needs qualifying); TeamCreate/TeamDelete removed in 2.1.178 (confirmed);
  `experimental.cacheTtl` needs 2.1.248 (confirmed, matches `plugin.json`'s
  ">=2.1.248"); "confirmed on Claude Code 2.1.201" for bare-name spawns is
  unverifiable (the 2.1.201 entry is unrelated; the sub-agents doc covers
  bare-name addressing without a version).
- **Validate cap.** The full `bash tests/validate.sh` exited 0 at baseline
  but took more than 600 s (NOTE[spec] hyg-1 says the same). Units run
  `skr-core.sh` (2.5 s: the skill-relevant validate sections plus 12 suites),
  and the orchestrator's merge-gate run covers the rest.

### Prior FAIL history and notes on these surfaces

`bash bin/marker-audit.sh . --notes --surface=<p>` was run for `skills`,
`.claude/skills`, `agents`, `adapters`, `hooks/scripts/version-stamp-check.sh`
and `scripts/resync-vendored-skills.sh`. Dispositions:

- NOTE[spec] `cache-ttl-gapped-personas` (install-antislop `:27` said
  v2.1.178+): already fixed on disk (now v2.1.248+). Step 9 re-verifies the
  rest of that paragraph.
- NOTE[spec] `hyg-1` (validate.sh exceeds 600 s): adopted as R4.
- NOTE[spec] `saa-u1` (harness-glossary scaffold-only mirror entry says all
  `.claude/skills` are mirrored, but 4 of 6 are graph-generated): closed by
  Step 1.
- untagged `248` Roast Major 1 (dangling `/implement` in
  `skills/to-tickets/SKILL.md`): closed by Step 4, which retires that file.
- untagged `245-CF1` (ADR-0012 says "five skills" but REPOINT has three):
  superseded; Step 11's ADR records the new state.
- untagged `253` (install-antislop graph-skill parenthetical): Step 1
  rewrites that paragraph.

`.fail` records that name these surfaces (a full `grep -rlE` over every
record, not a sample): `item17-3-wire-p3-check`, `item17-4-name-p3-offenders`,
`item17-1-clarify-p3-granularity`, `gh-212-version-bump`,
`ci-fetch-depth-cleanup` (all `version-stamp-check.sh` / P3),
`grilling-fix-1`, `cache-ttl-gapped-personas`, plus 18 others that only
mention `skills/` in passing. The P3 cluster says Step 5 needs more judgment
than its size suggests: task-master must not tag it below the
Implementer-tier ratchet, and its criteria include a historical replay
(AC5.4), not only fixtures.

### Draft ADR (scribe numbers and lands it; Step 11)

**ADR-NNNN: Retire five skills, fork-and-own the edited vendored skills,
archive originals under `docs/archive/skills/`** (amends ADR-0005, ADR-0012,
ADR-0031; touches ADR-0003's `to-spec`/`to-tickets` wording and ADR-0022's
skill count). NNNN is re-derived at execution time; it is 0041 at baseline,
but sibling specs may take it first.

- Context: the skills audit found two near-duplicate grill skills (the
  ADR-0031 description collision), a `code-review` skill that duplicates
  the reviewer, `to-spec`/`to-tickets`/`fail-triage` that only restate or
  conflict with persona prose (task-master's "to-tickets precedence" block
  existed only to override `to-tickets`), and vendored text written for an
  interactive human (grilling one question at a time, an HTML report opened
  with `xdg-open`, "confirm seams with the user") that a one-shot subagent
  cannot follow.
- Decision: (1) retire `grill-me`, `grill-with-docs`, `code-review`,
  `to-spec`, `to-tickets`, `fail-triage` and the four graph-generated local
  skills; (2) the vendored skills whose text antislop now edits (`grilling`,
  `tdd`, `diagnosing-bugs`, `improve-codebase-architecture`) are
  fork-and-own: the live file carries a "Derived from" header,
  and drift tracking moves to the archived byte-verbatim copy, so
  `--check` still reports upstream drift; (3) every pre-change original is
  kept byte-identical under `docs/archive/skills/<name>/` with an index row
  naming its origin path and commit.
- Consequences: upstream fixes no longer flow into forked skills
  automatically; `--check` on the archived copy tells a maintainer when to
  port one by hand. `handoff`, `domain-modeling` and `codebase-design` stay
  vendored verbatim.
  Consumers lose six skills on their next plugin update.
- Why the three ADR tests hold: hard to reverse (consumer-visible skill
  removals and a changed drift-tracking target); surprising without context
  (an in-tree archive when git history already has the files: the operator
  required originals browsable without git archaeology); a real trade-off
  (fork-and-own vs a per-edit declared-deviation class vs keeping the text
  verbatim, Open Question 2).

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Missing
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-14 Functional scope & success criteria: Q What does TRIM mean for
  coding-discipline, roast-work, ubiquitous-language, domain-modeling and
  codebase-design, given the audit report file does not exist? → A: per
  user (Open Question 1), re-derived by a fresh read-only pass
  (`trim-recommendations.md`, model output; spec-master re-verified its
  file:line claims and re-ran its ubiquitous-language replacement through an
  unmodified copy of `tests/ubiquitous-language.test.js`: exit 0, and exit 1
  with `UL_TEST_MUTATE=1`). Result: trim `coding-discipline` (principle 6
  genericized), `roast-work` (delete `:10-15` only) and
  `ubiquitous-language` (lens 2 names `_Avoid_`, both mode sections
  halved); KEEP `domain-modeling` and `codebase-design` unchanged. Its claim
  that the coding-discipline skill caused the largest test bloat is
  unconfirmed and is not cited.
- 2026-10-14 Functional scope & success criteria: Q Does the rewritten
  improve-codebase-architecture keep the design-it-twice pointer (ICA
  `:71`)? → A (self-resolved): yes. `codebase-design/DESIGN-IT-TWICE.md` is
  kept, so the pointer does not dangle; it is reworded as an optional later
  dispatch (AC8.4).
- 2026-10-14 Domain entities / data model: Q Where do archived originals
  live, and what identifies one? → A (self-resolved):
  `docs/archive/skills/<name>/`, the whole pre-change skill directory,
  byte-identical, plus one row in `docs/archive/skills/README.md` (`| skill |
  origin dir | archived-from sha | disposition | successor |`). No
  enumerator in the repo or in Claude Code's documented discovery reaches
  `docs/`, and `package.json` ships no `docs/` path, so this is not a user
  decision. `skills/_archive/` was rejected: it would ship with the plugin
  and its discovery is undocumented.
- 2026-10-14 Domain entities / data model: Q Which skills get archived, only
  deleted/merged/rewritten ones or also trimmed and fixed ones? → A
  (self-resolved): every skill whose files change at all is archived once, at
  the first unit that changes it, from that unit's base commit. One uniform
  rule, and a later unit never re-archives. `handoff` (only its preload
  changes) is not archived.
- 2026-10-14 Non-functional attributes (perf, security, scale): Q How does
  each unit prove the suite stays green when `tests/validate.sh` exceeds the
  600 s cap? → A (self-resolved): each unit runs `skr-core.sh`, which repeats
  the validate sections and suites a skills change can break; the
  orchestrator's merge-gate run covers the full file (R4, P5 deviation).
- 2026-10-14 External dependencies & integrations: Q How do edits to
  vendored text coexist with ADR-0005/0012/0031 byte-pinning and
  `resync-vendored-skills.sh --check`? → A: fork-and-own, drift tracking
  moved to the archived copy, recorded in a new ADR (user, Open Question 2).
- 2026-10-14 External dependencies & integrations: Q Will re-running
  `code-review-graph install` regenerate the four deleted local skills, and
  what should consumers be told? → A: install-antislop must ASK the
  consumer whether to delete the four directories, and delete them only on
  yes; never auto-delete, never keep them silently (user, Open Question 4;
  Step 1).
- 2026-10-14 Edge cases / failure handling: Q The Set A string
  `persona-config.json` `issueTracker` says "to-tickets' own default
  (ready-for-agent)"; no agent may edit that file. → A (self-resolved): the
  merged `pathfinder` keeps the `ready-for-agent` default (AC4.5), so the
  string stays true in substance; a human may reword it (R6). Not gated.
- 2026-10-14 Edge cases / failure handling: Q What if a unit's
  `resync --check` cannot reach GitHub? → A (self-resolved): exit 2 is an
  environment gap, reported as such, never a pass; exit 1 is a FAIL.
- 2026-10-14 Technical constraints & tradeoffs: Q What is the merged
  slicing skill called? → A: `pathfinder` (user, Open Question 3).
- 2026-10-14 Technical constraints & tradeoffs: Q Which "lead-programmer
  double load" does the tdd item mean? → A (self-resolved): lead-programmer
  preloads `antislop:tdd` and its prose also says to invoke it again via the
  `Skill` tool every time (`agents/lead-programmer.md:54-64`). Step 6 drops
  the re-invocation. The separate fact that this repo lists both
  `coding-discipline` (project copy) and `antislop:coding-discipline`
  (plugin) is out of scope (R9).
- 2026-10-14 Technical constraints & tradeoffs: Q Where does the PRD
  template appendix go in `agents/spec-master.md`? → A (self-resolved): a
  `## Appendix: PRD template` section at the end of the source file. The
  source carries no protocol marker; `bin/cli.js` appends the
  `<!-- ANTISLOP:BEGIN persona-protocol -->` block only in the rendered
  `.claude/agents/spec-master.md`, so there the appendix lands just before
  that block and the inlining never touches it.
- 2026-10-14 Terminology consistency: Q Is "archived skill" a new term, and
  is "fork-and-own" a synonym of "declared deviation"? → A (self-resolved):
  "archived skill" is new and load-bearing (Step 1 adds a CONTEXT.md entry).
  "Fork-and-own" is not a synonym: a declared deviation keeps the live file
  drift-tracked against reconstructed upstream text; a forked skill's live
  file is not drift-tracked, only its archived copy is. Step 11's ADR and
  the harness-glossary **drift-tracked skills** entry use the distinction.

## Risks / dependencies

- R1. **Plugin cache.** Skill menus come from the installed plugin cache, so
  retirements reach a session only after `/plugin update` (or reinstall).
  Unit criteria check the repo, not the cache.
- R2. **code-review-graph regeneration.** `code-review-graph install`
  re-creates the four `.claude/skills` directories. install-antislop now
  asks the consumer whether to delete them (Step 1). For this repo,
  re-running the installer brings them back and they must be deleted again.
- R3. **Self-editing persona.** Steps 2-4 edit `agents/spec-master.md` and
  `agents/task-master.md`. A spec-master or task-master spawned mid-plan
  loads whichever body is on disk. Units run strictly in order.
- R4. **600 s cap.** See the validate-cap fact. No unit runs `tests/validate.sh` whole.
- R5. **Stamped-file units serialize** (task-master rule): Steps 2, 3, 4, 5
  and 6 edit `agents/*.md`. Each one bumps to the next patch version **at
  execution time** (never a pinned number), adds a CHANGELOG line containing
  that version in the same commit, and refreshes mirrors with
  `node bin/cli.js --update --force-render` before committing (`git add -u
  -- .claude`). From Step 5 on, `version-stamp-check.sh` enforces the
  CHANGELOG half too.
- R6. **Set A string.** `.claude/persona-config.json` `issueTracker` names
  `to-tickets`. No agent edits it (P2, harness-integrity-gate). Optional
  human follow-up only.
- R7. **Shared files.** CHANGELOG.md, CONTEXT.md, docs/harness-glossary.md,
  skills/THIRD-PARTY-NOTICES.md, scripts/resync-vendored-skills.sh,
  docs/maintenance/resync-vendored-skills.md and docs/archive/skills/README.md
  are touched by most steps. That is a strict linear chain, 1 → 11.
- R8. **MIT attribution.** Archived vendored copies keep their own headers.
  NOTICES must keep crediting every file derived from upstream: forked
  skills, the spec-master PRD appendix (from `to-spec`) and the merged
  `pathfinder` (from `to-tickets`).
- R9. **Out of scope, named:** this repo lists `coding-discipline` twice in
  skill menus (the scaffolded project copy and the plugin skill); ADR-0003,
  0005, 0012, 0022 and 0031 are historical and not edited in place;
  `tests/fixtures/contract-score/*` keep `skills/to-tickets/SKILL.md` as
  inert sample text; `.claude/wiki/changelog.md` is history.
- R10. **The `to-spec` publish step for this plan.** It resolves to more than 6
  units, so it must be published to the tracker. `to-spec` is still live
  until Step 3 lands, so that publish has to happen before Step 3.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every claim in Context was measured
  at 12227b4. The criteria scripts were run red at baseline
  (`skr-live-refs.sh`, `skr-glossary.sh`) or mutation-proven in a scratch
  worktree (`skr-core.sh`: deleting `skills/tdd` and editing one tdd line
  both turn it FAIL; `skr-archive-verify.sh`: one appended byte and one
  missing row both turn it FAIL; `skr-discovery.sh`: wrong expected sets
  turn it FAIL).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied.
  Mirrors and fileHashes are refreshed only by `node bin/cli.js --update
  --force-render`. Archives are made by `git mv` (retired skills) or `cp -r`
  from the base commit (kept skills). `persona-config.json` is never
  hand-edited (R6).
- P3 "Version-stamp discipline": satisfied (R5). Step 5 mechanizes the
  CHANGELOG half, which tightens P3 rather than relaxing it.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. New prose
  that names `scribe`, `reviewer` or `explorer` keeps an "if present"
  phrasing. The ICA rewrite names `explorer` "if present, otherwise read
  directly".
- P5 "`tests/validate.sh` is the merge gate": scoped deviation. Units run
  `skr-core.sh` (the touched sections) because the full file exceeds the
  600 s cap. The orchestrator's merge-gate run covers the rest, as in
  `docs/plans/2026-10-14-validate-concurrency-tmpnames.md` R4.

## Common rules for every step

- **Archive first, in the same commit.** For each skill the step changes or
  removes and that has no archive row yet: retired skill, `git mv
  <origin> docs/archive/skills/<name>`; kept skill, `cp -r` the directory
  as it is at the unit's base commit. Then append one index row with
  `archived-from` = the unit's base commit (full or 7+ char sha). The
  `.claude/skills` dirs use origin `.claude/skills/<name>`.
- **Drift rows (fork-and-own, Open Question 2).** A forked skill's FILES rows in
  `scripts/resync-vendored-skills.sh` keep their upstream paths but point
  the local path at `docs/archive/skills/<name>/...`. A retired vendored
  skill's rows (and REPOINT entries) are removed. SKILL_ORDER and the "9
  drift-tracked" counts follow. NOTICES and
  `docs/maintenance/resync-vendored-skills.md` follow in the same commit.
- **Glossary.** Any CONTEXT.md or harness-glossary entry that still names a
  retired skill must carry a `docs/archive/skills/<name>/` pointer in that
  entry (`skr-glossary.sh`).
- **Persona-config phrasing.** Any rewritten text that tells an agent to
  consult `.claude/persona-config.json` uses reviewer.md's sanctioned
  phrasing: read it with the `Read` tool, because a Bash command naming that
  file can be refused by `harness-integrity-gate.sh`.
- Every step ends with `bash docs/plans/skr-criteria/skr-core.sh` (exit 0)
  and `bash docs/plans/skr-criteria/skr-archive-verify.sh <its names>` (exit 0).

## Steps

Expected live sets after each step (input to `skr-discovery.sh`):

| after | skills/ | .claude/skills/ |
|---|---|---|
| base | 19 dirs (all current) | coding-discipline debug-issue explore-codebase install-antislop refactor-safely review-changes |
| 1 | unchanged | coding-discipline install-antislop |
| 2 | minus grill-me grill-with-docs | same |
| 3 | minus to-spec fail-triage | same |
| 4 | minus to-tickets | same |
| 6 | minus code-review | same |

Final `skills/`: `codebase-design coding-discipline diagnosing-bugs
domain-modeling grilling handoff improve-codebase-architecture
install-antislop pathfinder roast-work tdd ubiquitous-language
version-stamp-discipline` (13).

### Step 1 (skr-1): archive scaffold; retire the four graph-generated local skills
Stamped: no.
Affected files: `docs/archive/skills/README.md` (new: purpose paragraph,
"never loaded, listed, mirrored, hashed or shipped", the index table);
`docs/archive/skills/{debug-issue,explore-codebase,refactor-safely,review-changes}/SKILL.md`
(git mv from `.claude/skills/`); `docs/harness-glossary.md` (`:1617` entry
and the **scaffold-only mirror** entry at `:299`); `CONTEXT.md` (new
**Archived skill** entry, see Scribe hint); `skills/install-antislop/SKILL.md`
`:149-153` (drop "(all query interfaces, not workflow commands)") and the
`:167-171` bullet replaced by this text (wrapping free):

> The generated `.claude/skills/debug-issue/`, `.claude/skills/explore-codebase/`,
> `.claude/skills/refactor-safely/` and `.claude/skills/review-changes/`
> directories call graph MCP tools that, after the rescoping step above,
> only the `explorer` can reach, so antislop does not use them. Ask the user
> whether to delete these four directories (use `AskUserQuestion` if it is
> available; otherwise ask in plain text and wait for the answer). Delete
> them only if the user says yes. If the user says no, leave them in place,
> and don't wire them into `explorer.md` either way.

plus the byte-identical `.claude/skills/install-antislop/` copy and the
install-antislop archive (first change); `CHANGELOG.md`.
Acceptance criteria:
- AC1.1 run: `bash docs/plans/skr-criteria/skr-discovery.sh "$(ls -d skills/*/ | xargs -n1 basename | tr '\n' ' ')" "coding-discipline install-antislop"` expect: exit 0. mutation: restore `.claude/skills/debug-issue` → exit 1.
- AC1.2 run: `bash docs/plans/skr-criteria/skr-archive-verify.sh debug-issue explore-codebase refactor-safely review-changes install-antislop` expect: exit 0. mutation: append a byte to any archived file → exit 1.
- AC1.3 run: `bash docs/plans/skr-criteria/skr-glossary.sh debug-issue explore-codebase refactor-safely review-changes` expect: exit 0. mutation: at baseline the harness-glossary `:1617` entry has no archive pointer → exit 1.
- AC1.4 run: `grep -c '^\*\*Archived skill\*\*:' CONTEXT.md` expect: `1`. And `node tests/context-glossary-links.test.js` exit 0.
- AC1.5 run: `tr -s '\n ' ' ' < skills/install-antislop/SKILL.md | grep -c 'Ask the user whether to delete these four directories'` expect `1`; same pipe with `'Delete them only if the user says yes'` expect `1`; `grep -c 'legitimate and can stay' skills/install-antislop/SKILL.md` expect `0`; `grep -c 'review-changes' skills/install-antislop/SKILL.md` expect ≥1. mutation: baseline gives 0, 0, 1 (observed).
- AC1.6 run: `diff -rq skills/install-antislop .claude/skills/install-antislop` exit 0; `bash docs/plans/skr-criteria/skr-core.sh` expect: exit 0.

### Step 2 (skr-2): retire grill-me and grill-with-docs
Stamped: yes (R5).
Affected files: `skills/grill-me/`, `skills/grill-with-docs/` (git mv to the
archive); `skills/ubiquitous-language/SKILL.md` (prose-mode "never block
progression to `grill-with-docs`, `to-spec`, or `task-master` handoff" →
"never block progression to grilling, spec publication, or `task-master`
handoff"; archive first); `agents/spec-master.md` (`:8` drop
`antislop:grill-with-docs`; `:21`, `:39-41`, `:98`, `:150`, `:200`: name
"`grilling` with `domain-modeling`" instead of `grill-with-docs`; the `:150`
line also drops `to-spec`); `agents/milestone-auditor.md:24` ("Invoke
`grill-me` (the skill invoked is grilling)" → "Invoke `antislop:grilling`");
`scripts/resync-vendored-skills.sh` (drop both FILES rows and SKILL_ORDER
entries, counts 9 → 7); `skills/THIRD-PARTY-NOTICES.md`;
`docs/maintenance/resync-vendored-skills.md`; CONTEXT.md entries at `:251`,
`:517`, `:585`; harness-glossary entries at `:969`, `:1589`, `:1602`,
`:1650`; `CHANGELOG.md`; `package.json` + `.claude-plugin/plugin.json`
version; `.claude/` mirrors via `--update --force-render`.
Acceptance criteria:
- AC2.1 run: `bash docs/plans/skr-criteria/skr-live-refs.sh grill-me grill-with-docs` expect: exit 0. mutation: at baseline it reports 20 and 35 hits (observed) → exit 1.
- AC2.2 run: `bash docs/plans/skr-criteria/skr-glossary.sh grill-me grill-with-docs` expect: exit 0. mutation: at baseline 7 entries fail (observed) → exit 1.
- AC2.3 run: `bash docs/plans/skr-criteria/skr-archive-verify.sh grill-me grill-with-docs ubiquitous-language` expect: exit 0.
- AC2.4 run: `bash docs/plans/skr-criteria/skr-discovery.sh "<base set minus grill-me grill-with-docs>" "coding-discipline install-antislop"` expect: exit 0.
- AC2.5 run: `bash hooks/scripts/version-stamp-check.sh <base>..HEAD` expect: stdout starts `version-stamp-check: ok touched: yes`. mutation: commit without the bump → `violation`.
- AC2.6 run: `bash scripts/resync-vendored-skills.sh --check` expect: exit 0 (exit 2 = network gap, report it; exit 1 = FAIL).
- AC2.7 run: `bash docs/plans/skr-criteria/skr-core.sh` expect: exit 0.

### Step 3 (skr-3): merge to-spec and fail-triage into spec-master
Stamped: yes (R5).
Affected files: `skills/to-spec/`, `skills/fail-triage/` (git mv to the
archive); `agents/spec-master.md`: `:3` description ("publishes a finalized
spec via `to-spec`" → "publishes it to the issue tracker"); `:8` drop
`antislop:to-spec` and `antislop:fail-triage`; `:142` "publish via `to-spec`"
→ "publish (see below)"; the `:197-213` "Publish via `to-spec`" bullet
becomes "Publish to the tracker": same mapping, now onto
`## Appendix: PRD template`, the tracker taken from `issueTracker` (read with
the `Read` tool, per the common rule), label `ready-for-agent`, and no
"check the seams with the user" step; the `:259-261` debug-spec text replaces
"invoke `antislop:fail-triage`" with three inline steps, VERIFY (re-run the
failing criterion fresh, confirmed or could-not-reproduce), CATEGORIZE (code
defect → normal FAIL route; spec/criterion defect → revised-criteria path;
no third route), BRIEF (feed both into the existing debug-spec output, no
second format, never re-grill, never edit code); new `## Appendix: PRD
template` as the last section of the source file (the rendered mirror puts
the protocol block after it),
holding to-spec's template sections verbatim (Problem Statement, Solution,
User Stories, Implementation Decisions, Testing Decisions, Out of Scope,
Further Notes) and a one-line MIT credit; `agents/task-master.md:25` ("its
`to-spec` tracker publication" → "its tracker publication");
`.claude-plugin/plugin.json` description (drop `fail-triage`);
`scripts/resync-vendored-skills.sh` (REPOINT drops `to-spec`); NOTICES (to-spec
row → archive path + "template carried in `agents/spec-master.md`");
runbook; CONTEXT.md `:47-54`, `:517-545`, `:585`, `:895-901`; harness-glossary
`:1589`; CHANGELOG; version; mirrors.
Acceptance criteria:
- AC3.1 run: `bash docs/plans/skr-criteria/skr-live-refs.sh to-spec fail-triage` expect: exit 0. mutation: baseline 43 and 9 hits (observed) → exit 1.
- AC3.2 run: `bash docs/plans/skr-criteria/skr-glossary.sh to-spec fail-triage` expect: exit 0.
- AC3.3 run: `bash docs/plans/skr-criteria/skr-archive-verify.sh to-spec fail-triage` expect: exit 0.
- AC3.4 run: `awk '/^## Appendix: PRD template/{a=1} a' agents/spec-master.md | grep -cE '^#+ (Problem Statement|Solution|User Stories|Implementation Decisions|Testing Decisions|Out of Scope|Further Notes)$'` expect: `7`. mutation: delete one heading → 6.
- AC3.5 run: `grep -cE '\b(VERIFY|CATEGORIZE|BRIEF)\b' agents/spec-master.md` expect: ≥3 (baseline 0); and `awk '/^## Appendix: PRD template/{a=1} a' agents/spec-master.md | grep -c 'mattpocock'` expect ≥1; and `awk '/^## Appendix: PRD template/{a=1} /ANTISLOP:BEGIN persona-protocol/{a=0} a' .claude/agents/spec-master.md | grep -c '^## Problem Statement$'` expect 1 (the rendered mirror keeps the appendix outside the protocol block).
- AC3.6 run: `grep -c 'agents/spec-master.md' skills/THIRD-PARTY-NOTICES.md` expect: ≥1.
- AC3.7 run: `bash scripts/resync-vendored-skills.sh --check` expect: exit 0 (2 = env gap).
- AC3.8 run: `bash hooks/scripts/version-stamp-check.sh <base>..HEAD` expect: `ok touched: yes`.
- AC3.9 run: `bash docs/plans/skr-criteria/skr-core.sh` and `skr-discovery.sh` (table) expect: exit 0.

### Step 4 (skr-4): merge to-tickets into pathfinder
Stamped: yes (R5).
Affected files: archive `skills/pathfinder/` (cp, first change) and
`skills/to-tickets/` (git mv); `skills/pathfinder/SKILL.md` rewritten: new
description (slices a finalized spec into dispatch-ready units and publishes
them); "Derived from mattpocock/skills `wayfinder` and `to-tickets` @ e9fcdf9,
MIT, see NOTICES" header; pathfinder's four rules unchanged in substance;
plus a **Publishing** section taken from to-tickets (local files under
`.scratch/<slug>/issues/NN-<slug>.md` with the local template, or one tracker
issue per unit in dependency order using native blocking links, label
`ready-for-agent`, work the frontier), the wide-refactor expand–contract
paragraph, and the tracker read from `issueTracker` with the `Read` tool.
Dropped: the user quiz (the finalized spec stands in for approval), the
"avoid file paths and snippets" rule (contracts need them), context-window
sizing, and the `/implement` reference. `agents/task-master.md`: `:3`
description, `:11` `skills: antislop:pathfinder`, `:33` "(`pathfinder`,
owned outright)", `:50-59` the pathfinder-vs-to-tickets precedence block
collapses to one sentence (units sized by pathfinder and the contract
budget, not the context window), `:290` demo path →
`skills/pathfinder/SKILL.md`, `:428`; `agents/spec-master.md:220,225,234`
(`to-tickets` → `pathfinder`); resync REPOINT drops `to-tickets`; NOTICES;
runbook; CONTEXT.md (`:47-54`, `:555-561` pathfinder entry, others the
script lists); harness-glossary; CHANGELOG; version; mirrors.
Acceptance criteria:
- AC4.1 run: `bash docs/plans/skr-criteria/skr-live-refs.sh to-tickets` expect: exit 0. mutation: baseline 44 hits (observed).
- AC4.2 run: `bash docs/plans/skr-criteria/skr-glossary.sh to-tickets` and `skr-archive-verify.sh pathfinder to-tickets` expect: exit 0.
- AC4.3 run: `node tests/contract-examples.test.js` expect: exit 0. mutation: change the demo bullet to a bare word → R6 fails.
- AC4.4 run: `grep -cE 'Quiz the user|/implement|Iterate until the user approves' skills/pathfinder/SKILL.md` expect: `0`.
- AC4.5 run: `grep -c 'ready-for-agent' skills/pathfinder/SKILL.md` ≥1, `grep -c 'Blocked by' skills/pathfinder/SKILL.md` ≥1, `grep -c 'expand' skills/pathfinder/SKILL.md` ≥1.
- AC4.6 run: `grep -c '^skills: antislop:pathfinder$' agents/task-master.md` expect: `1`.
- AC4.7: version-stamp-check `ok touched: yes`; `resync --check` exit 0; `skr-core.sh` and `skr-discovery.sh` exit 0.

### Step 5 (skr-5): mechanize the CHANGELOG half; rewrite version-stamp-discipline; stop preloading it
Stamped: yes (R5). Prior P3 FAIL cluster applies (Context).
Affected files: `hooks/scripts/version-stamp-check.sh`: for every commit in
the range that touches a stamped path AND changes the version, require
`git show <c> -- CHANGELOG.md` to add a line (`^+`, not `+++`) containing,
as a fixed string, the version read from `<c>:.claude-plugin/plugin.json`;
a miss is a `violation` with offender `<short>:CHANGELOG.md`. Output format
unchanged. `tests/version-stamp-check.test.sh`: new cases (a) bump +
matching CHANGELOG line → ok; (b) bump, no CHANGELOG hunk → violation,
offenders contain `:CHANGELOG.md`; (c) CHANGELOG line names a different
version → violation; (d) two bumping commits where only the earlier one
lacks its line, with HEAD's working-tree version different from the
earlier commit's → violation naming the earlier commit (the Half-2
defect). `.claude/hooks/scripts/` via `--update`. Archive then rewrite
`skills/version-stamp-discipline/SKILL.md`: run the script, which checks
both halves per commit; verdict meanings; repo-only applicability; no `jq`
command. `agents/lead-programmer.md:8` drop
`antislop:version-stamp-discipline`; `:97-103`, `agents/scribe.md:42-47`,
`agents/reviewer.md:120-123`: `ok` now clears both halves; CONTEXT.md `:149`.
CHANGELOG; version; mirrors.
Acceptance criteria:
- AC5.1 run: `bash tests/version-stamp-check.test.sh` expect: exit 0. mutation: revert the script's CHANGELOG hunk → cases (b)-(d) fail.
- AC5.2 run: `git grep -n -i -E 'does not check this|CHANGELOG-entry half|only the version-bump half|reviewer-inspection-only' -- agents templates CONTEXT.md skills docs/harness-glossary.md adapters` expect: no output (exit 1). mutation: baseline has 6 hits (observed).
- AC5.3 run: `bash docs/plans/skr-criteria/skr-live-refs.sh vsd-preload` expect: exit 0. mutation: baseline 2 hits.
- AC5.4 (historical replay) run: `bash hooks/scripts/version-stamp-check.sh <W>..<unit-base>`, where `<W>` is the oldest commit such that the OLD script (at `<unit-base>`) prints `ok` for that range; the implementer records `<W>` in the commit message. expect: the NEW script also prints `ok` for the same range. This proves the CHANGELOG half does not flag compliant history (123 of 124 historical bumps comply; the miss is the 0.1.0 import). mutation: a range ending at a fixture commit with no CHANGELOG line → `violation`. A shallow clone yields `unknown`, which is a FAIL, never a pass.
- AC5.5 run: `grep -c 'jq' skills/version-stamp-discipline/SKILL.md` expect: `0`; `bash docs/plans/skr-criteria/skr-archive-verify.sh version-stamp-discipline` exit 0.
- AC5.6: version-stamp-check `<base>..HEAD` → `ok touched: yes`; `skr-core.sh` exit 0.

### Step 6 (skr-6): fork and trim tdd; retire code-review; lead-programmer load fixes
Stamped: yes (R5).
Affected files: archive `skills/tdd/` (cp, 3 files) and `skills/code-review/`
(git mv); `skills/tdd/SKILL.md`: header → "Derived from mattpocock/skills
skills/engineering/tdd/SKILL.md @ e9fcdf9 (MIT, see
skills/THIRD-PARTY-NOTICES.md); vendored original archived at
docs/archive/skills/tdd/"; the seams paragraph → "Test at the seams your
plan or dispatch names. If it names none, pick the highest public seam that
exercises the behaviour and name it in your report." (drop the "Ask: ..."
line); the last bullet → "It belongs to the review stage, not the red →
green implementation cycle." Both adapter lead-programmer ports' inlined tdd
blocks updated byte-identically. `agents/lead-programmer.md:8` drop
`antislop:handoff`; `:54-64` "invoke the `antislop:tdd` skill via the
`Skill` tool ... (preloaded ... re-reading ...)" → follow the preloaded
`antislop:tdd` loop; `diagnosing-bugs` stays on demand; `:77-80` handoff
stays on demand. Same prose in both adapter lead-programmer ports if present.
`agents/reviewer.md:124-132` remove the `antislop:code-review` bullet.
Resync: tdd rows point to the archive; REPOINT drops `code-review`
(becomes empty: remove the repoint report block or print "none"). NOTICES;
runbook; CONTEXT.md **Preloaded skill** example (`:614-625`); CHANGELOG;
version; mirrors.
Acceptance criteria:
- AC6.1 run: `bash docs/plans/skr-criteria/skr-live-refs.sh code-review seams-confirm tdd-skill-invoke handoff-preload` expect: exit 0. mutation: baseline 7, 3, 2 and 2 hits (observed).
- AC6.2 run: `node tests/adapter-skill-parity.test.js` expect: exit 0. mutation: edit one adapter's tdd block → exit 1.
- AC6.3 run: `bash docs/plans/skr-criteria/skr-archive-verify.sh tdd code-review` expect: exit 0.
- AC6.4 run: `bash scripts/resync-vendored-skills.sh --check` expect: exit 0 and stdout contains `[OK] tdd` (now diffing the archived copy).
- AC6.5 run: `bash docs/plans/skr-criteria/skr-glossary.sh code-review` exit 0; version-stamp-check `ok touched: yes`; `skr-core.sh` and `skr-discovery.sh` exit 0.

### Step 7 (skr-7): rewrite grilling for one-shot subagents
Stamped: no.
Affected files: archive `skills/grilling/`; `skills/grilling/SKILL.md`
rewritten ("Derived from" header): three contexts. (1) Live user in the
main session: one question at a time, each with a recommended answer. (2)
Dispatched subagent with no live user: batch up to 4 questions per round,
ordered by impact × uncertainty, each with a recommended default and
options where the answer space is discrete; return them as Open Questions
and stop; resume when re-dispatched with answers. (3) Self-grill (no user,
e.g. auditing a plan's premises): answer each question from evidence in the
repo; an unanswerable one becomes a finding, never a guess. All modes: look
facts up instead of asking; decisions belong to the user; take no action
until the questions converge. Description updated. Resync row → archive;
NOTICES; runbook; CHANGELOG.
Acceptance criteria:
- AC7.1 run: `grep -c 'one at a time' skills/grilling/SKILL.md` ≥1; `grep -c 'Open Questions' skills/grilling/SKILL.md` ≥1; `grep -cE 'up to 4|at most 4' skills/grilling/SKILL.md` ≥1; `grep -ci 'evidence' skills/grilling/SKILL.md` ≥1. mutation: the baseline file fails the 2nd, 3rd and 4th (observed: no "Open Questions", no "4", no "evidence").
- AC7.2 run: `skr-archive-verify.sh grilling`, `resync --check` (`[OK] grilling`), `skr-core.sh` expect: exit 0.

### Step 8 (skr-8): rewrite improve-codebase-architecture for subagent context
Stamped: no (unless scribe.md prose changes; then R5 applies).
Affected files: archive `skills/improve-codebase-architecture/` (SKILL.md +
HTML-REPORT.md); `git rm` the live `HTML-REPORT.md`; SKILL.md rewritten
("Derived from" header): explore (`explorer` if present, otherwise read
directly; never the built-in `Explore` type), then return the candidates in
the final message as a markdown list (Files, Problem, Solution, Benefits,
Recommendation strength) plus a Top recommendation. No file is written, no
browser is opened, no CDN is used, no question is asked. Grilling a chosen
candidate is a later, separate dispatch using `grilling` and
`domain-modeling`. The design-it-twice pointer (old `:71`) stays, reworded:
to compare alternative interfaces for a chosen candidate, a later dispatch
can use `codebase-design`'s design-it-twice pattern
(`DESIGN-IT-TWICE.md`, kept). Resync rows → archive; NOTICES; runbook;
CHANGELOG.
Acceptance criteria:
- AC8.1 run: `grep -ciE 'xdg-open|CDN|Tailwind|Mermaid|HTML|subagent_type=Explore|Which of these would you like' skills/improve-codebase-architecture/SKILL.md` expect: `0`. mutation: baseline >0.
- AC8.2 run: `test ! -e skills/improve-codebase-architecture/HTML-REPORT.md && test -f docs/archive/skills/improve-codebase-architecture/HTML-REPORT.md` exit 0.
- AC8.3 run: `skr-archive-verify.sh improve-codebase-architecture`, `resync --check` (`[OK] improve-codebase-architecture`), `skr-core.sh` exit 0.
- AC8.4 run: `grep -c 'design-it-twice' skills/improve-codebase-architecture/SKILL.md` expect ≥1 and `test -f skills/codebase-design/DESIGN-IT-TWICE.md` exit 0. mutation: drop the pointer → 0.

### Step 9 (skr-9): diagnosing-bugs path; install-antislop description and version claims
Stamped: no.
Affected files: archive `skills/diagnosing-bugs/` (fork);
`skills/diagnosing-bugs/SKILL.md:30,59` → "`scripts/hitl-loop.template.sh`
in this skill's base directory (the "Base directory for this skill" line
shown when the skill loads)" plus a "Derived from" header;
`skills/install-antislop/SKILL.md` (archived in Step 1): description ≤ 300
characters; `:27-34` keep the v2.1.248 floor and the two confirmed reasons
(TeamCreate/TeamDelete removed in 2.1.178; `experimental.cacheTtl` needs
2.1.248), qualify nesting (from 2.1.172, off by default in 2.1.217-2.1.218,
depth 3 by default since 2.1.219, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`),
drop "confirmed on Claude Code 2.1.201"; the `:48,65,105,161,175` and
`hook-verification.md:14` instructions that read persona-config get the
Read-tool phrasing; `.claude/skills/install-antislop/` copied
byte-identically. Resync diagnosing-bugs rows → archive; NOTICES; runbook;
CHANGELOG.
Acceptance criteria:
- AC9.1 run: `grep -c "base directory" skills/diagnosing-bugs/SKILL.md` expect: ≥2. mutation: baseline 0.
- AC9.2 run: `python3 -c "import re,yaml;c=open('skills/install-antislop/SKILL.md').read();d=yaml.safe_load(re.match(r'^---\n(.*?)\n---\n',c,re.S).group(1))['description'];assert len(d)<=300,len(d)"` exit 0. mutation: baseline 788 chars.
- AC9.3 run: `grep -c '2\.1\.201' skills/install-antislop/SKILL.md` expect `0`; `grep -c '2\.1\.219' skills/install-antislop/SKILL.md` ≥1; the floor matches the plugin: `grep -o '>=2\.1\.[0-9]*' .claude-plugin/plugin.json | tr -d '>='` equals the `v2.1.NNN+` in the SKILL.md.
- AC9.4 run: `diff -rq skills/install-antislop .claude/skills/install-antislop` exit 0; `skr-archive-verify.sh diagnosing-bugs install-antislop`, `resync --check` (`[OK] diagnosing-bugs`), `skr-core.sh` exit 0.

### Step 10 (skr-10): trim coding-discipline, roast-work, ubiquitous-language
Stamped: no (skills and adapters only).
Each skill is archived at its first change: `coding-discipline` and
`roast-work` here; `ubiquitous-language` was already archived by Step 2 and
is not re-archived (CHK6). `domain-modeling` and `codebase-design` are not
touched.
Affected files and edits:
- `skills/coding-discipline/SKILL.md`: principle 6 (`:35-40`) replaced by
  exactly:
  ```
  6. NO REACHING THROUGH — use only what you were handed, built, or own: one
     hop into your own input is fine (reading one field off the argument you
     were passed); chaining into another unit's internals is not (`a().b.c`,
     parsing a sibling module's private output, grepping another file's prose
     for a value). Read shared formats via their owner: call the helper that
     defines a path, pattern, or layout; don't re-derive it inline.
  ```
  The same body goes byte-identically into `.claude/skills/coding-discipline/SKILL.md`
  (copied by hand) and the inlined `coding-discipline` blocks of
  `adapters/codex/agents/lead-programmer.toml` and
  `adapters/cursor/agents/lead-programmer.md`.
- `skills/roast-work/SKILL.md`: delete `:10-15` (the "This skill produces
  ONE advisory section ..." paragraph and the blank line after it); keep the
  rest verbatim. `:41-45` ("Output shape ... appended AFTER the verdict
  line ... none of its entries are blocking defects") stays, because the
  Codex and Cursor reviewer ports state the advisory-only rule only inside
  their inlined block (ADR-0004 Tension 1, kept by ADR-0013). Mirror the
  change into the inlined `roast-work` blocks of
  `adapters/codex/agents/reviewer.toml` and `adapters/cursor/agents/reviewer.md`.
- `skills/ubiquitous-language/SKILL.md` (on top of Step 2's text): lens 2
  replaced by
  ```
  2. **A new synonym for an already-defined term.** The input introduces a new
     way to say something already defined in the glossary — including any
     word listed under an entry's `_Avoid_:` line. Name the canonical term,
     state the new synonym, and note that both refer to the same thing.
  ```
  and everything from `## Diff mode` to the end of the file replaced by
  ```
  ## Diff mode

  **Input:** a diff. **Consumer:** `reviewer`.

  **Output:** ONE clearly-demarcated advisory section appended AFTER the
  verdict line; never flips PASS/FAIL, never adds a FAIL ground, never
  substitutes for the acceptance-criteria command. Findings go to the
  `.pass` marker's non-blocking notes.

  **Anchor:** every finding names `file:line`, states the drift in one
  sentence, and the canonical term in one more. Check identifiers,
  type/module names, comments, and docs the diff introduces or renames.

  ## Prose mode

  **Input:** a natural-language request or a draft spec. **Consumer:**
  `spec-master`, or `milestone-auditor` (if present).

  **Output:** advisory only; informs the category-8 score but never blocks
  progression to grilling, spec publication, or `task-master` handoff. No
  new gate, no new hook.

  **Anchor:** a quoted span from the input, or the plan's own step/heading
  number (e.g. "Step 3"). State the drift, name the canonical term (or
  suggest one for `scribe` if the term is new).
  ```
  (Applied to a scratch copy on 2026-10-14: 75 → 64 lines;
  `tests/ubiquitous-language.test.js` exit 0, mutated run exit 1.)
- `docs/archive/skills/README.md` rows for `coding-discipline` and
  `roast-work`; `CHANGELOG.md`.
Acceptance criteria:
- AC10.1 run: `grep -cE 'state-access\.sh|agent_type' skills/coding-discipline/SKILL.md` expect `0`. mutation: baseline 2 (observed).
- AC10.2 run: `node tests/adapter-skill-parity.test.js` expect exit 0. mutation: edit one adapter block → exit 1.
- AC10.3 run: `diff -rq skills/coding-discipline .claude/skills/coding-discipline` expect exit 0.
- AC10.4 run: `grep -c 'This skill produces ONE advisory section' skills/roast-work/SKILL.md` expect `0`; `grep -c 'appended AFTER the verdict line' skills/roast-work/SKILL.md` expect `1`; `grep -c '^[1-4]\. [A-Z]' skills/roast-work/SKILL.md` expect `4`. mutation: baseline 1, 1, 4.
- AC10.5 run: `node tests/ubiquitous-language.test.js` exit 0 and `UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js` exit 1; `grep -c '_Avoid_' skills/ubiquitous-language/SKILL.md` expect ≥1 (baseline 0); `wc -l < skills/ubiquitous-language/SKILL.md` expect ≤ 66.
- AC10.6 run: `bash docs/plans/skr-criteria/skr-archive-verify.sh coding-discipline roast-work ubiquitous-language` exit 0; `git diff --quiet <unit-base> HEAD -- skills/domain-modeling skills/codebase-design` exit 0; `bash scripts/resync-vendored-skills.sh --check` exit 0 (`[OK] domain-modeling`, `[OK] codebase-design`); `bash docs/plans/skr-criteria/skr-core.sh` exit 0.

### Step 11 (skr-11, scribe): land the ADR; wiki; final sweep
Affected files: `docs/adr/NNNN-...md` (from the draft in Context, number
re-derived at execution); reciprocal `## Related` "Amended by ADR-NNNN"
bullets in ADR-0005, 0012, 0031 (append-only, the established convention);
`.claude/wiki/dependencies.md`; harness-glossary **drift-tracked skills**
entry (new set and the fork-and-own distinction); CHANGELOG.
Acceptance criteria:
- AC11.1 run: `grep -l 'docs/archive/skills' docs/adr/*.md | wc -l` expect ≥1, and `grep -l 'Amended by ADR-' docs/adr/0005-*.md docs/adr/0012-*.md docs/adr/0031-*.md | wc -l` expect `3`.
- AC11.2 run: `bash docs/plans/skr-criteria/skr-live-refs.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage vsd-preload handoff-preload tdd-skill-invoke seams-confirm` expect exit 0; `bash docs/plans/skr-criteria/skr-glossary.sh grill-me grill-with-docs code-review to-spec to-tickets fail-triage` exit 0; `git grep -c -E 'grill-me|to-tickets|to-spec' -- .claude/wiki/dependencies.md` no output.
- AC11.3 run: `bash docs/plans/skr-criteria/skr-archive-verify.sh debug-issue explore-codebase refactor-safely review-changes grill-me grill-with-docs to-spec fail-triage to-tickets pathfinder version-stamp-discipline tdd code-review grilling improve-codebase-architecture diagnosing-bugs install-antislop ubiquitous-language coding-discipline roast-work` exit 0; `node tests/context-glossary-links.test.js` exit 0.

## Open Questions

None open. Round 1 (2026-10-14), answered by the user:
1. TRIM scope → re-derived (Step 10: coding-discipline, roast-work,
   ubiquitous-language; domain-modeling and codebase-design KEEP).
2. Vendored-text policy → (a) fork-and-own, with a new ADR (Step 11).
3. Merged slicing skill name → (a) `pathfinder`.
4. Graph-generated local skills → install-antislop asks the consumer
   whether to delete them (Step 1, AC1.5).

## Self-check
- CHK1: Is the TRIM content for coding-discipline, roast-work,
  ubiquitous-language, domain-modeling and codebase-design defined? — PASS
  (was FAIL (missing), converted to Open Question 1; answered, Step 10
  revised in place with literal replacement text)
- CHK2: Is the policy for editing vendored text defined, and do Steps 6-9
  agree on it? — PASS (was FAIL (missing), converted to Open Question 2;
  answered (a), which Steps 6-9 and Common rules already use)
- CHK3: Is the merged slicing skill's name defined consistently in Steps 4
  and 11 and the expected-set table? — PASS (was FAIL (missing), converted
  to Open Question 3; answered `pathfinder`)
- CHK4: Is the consumer guidance for the four graph-generated skills
  defined? — PASS (was FAIL (missing), converted to Open Question 4;
  answered "ask the consumer"; Step 1 wording plus AC1.5)
- CHK5: Is the archive location defined so that no enumerator loads, lists,
  mirrors, hashes or ships it? — PASS (Context, verified facts;
  `skr-discovery.sh`)
- CHK6: Is the `archived-from` commit defined for a skill that two units
  change (`ubiquitous-language`, `install-antislop`)? — PASS (archive once,
  at the first change; Common rules)
- CHK7: Do Steps 2 and 3 agree on who fixes the lines that name both
  `grill-with-docs` and `to-spec` (spec-master `:150`, ubiquitous-language
  prose mode)? — PASS (both assigned to Step 2)
- CHK8: Does Step 4 conflict with the `issueTracker` string in Set A
  config? — FAIL (conflicting) — revised in place (R6 plus AC4.5 keep the
  string true in substance; no agent edit)
- CHK9: Is every Goal clause mapped to a runnable criterion? — PASS
  (Goal-to-criterion map; G4 maps to AC10.1-AC10.6)
- CHK10: Is the merge gate defined under the 600 s cap? — PASS (R4, P5)
- CHK11: Do the steps agree on version numbers? — PASS (next patch at
  execution time, none pinned; R5)
- CHK12: Is the PRD appendix's position relative to the inlined protocol
  block defined? — FAIL (conflicting) — revised in place (the first draft
  placed it before a marker that exists only in the rendered mirror; Step 3
  and AC3.4/AC3.5 now target the source file's end and check the mirror)
- CHK13: Does deleting `code-review` leave the reviewer's on-demand bullet
  dangling? — PASS (Step 6 removes `agents/reviewer.md:124-132`; AC6.1)
- CHK14: Does criterion AC5.1 still fail under its own `mutation:` line,
  given item17-4-name-p3-offenders's recorded class host? — PASS (the
  mutation reverts the script hunk; the fixture repo is built in a temp dir,
  so host state does not enter)
- CHK15: Does criterion AC5.4 still fail under its own `mutation:` line,
  given ci-fetch-depth-cleanup's recorded class host? — FAIL (ambiguous) —
  revised in place (AC5.4 needs full history: a shallow clone makes the
  range unmeasurable, which reports `unknown`, never `ok`, so a host gap
  fails loudly instead of passing)
- CHK16: Does criterion AC*.core (`skr-core.sh`) still fail under its own
  `mutation:` line, given 373's recorded class vacuous
  (`tests/heavy-trigger.test.sh`)? — PASS (the mutation was observed to
  fail at the aggregate; the suite's own vacuity is not this plan's to fix)
- CHK17: Does `skr-core.sh` still fail under its mutation, given
  examples-2's recorded class host (`tests/adapter-protocol-parity.test.js`)?
  — PASS (observed in a scratch worktree on this host)
- CHK18: Does `skr-core.sh` still fail under its mutation, given
  item03-2-link-integrity-guard's recorded class vacuous
  (`tests/context-glossary-links.test.js`)? — PASS (AC1.4 also runs it
  directly, and the new glossary entry is checked by its own grep)
- CHK19: Does `skr-core.sh` still fail under its mutation, given
  spec2-unitB's recorded class vacuous (`tests/filehashes-currency.test.js`)?
  — PASS (no skill is in fileHashes; the stamped-unit mirrors are checked
  by the same aggregate run, mutation observed)
- CHK20: Does the improve-codebase-architecture rewrite (Step 8) keep or
  drop the design-it-twice pointer, and does it agree with keeping
  codebase-design (Step 10)? — PASS (kept and reworded; AC8.4 checks the
  pointer and the target file)
- CHK21: Do Steps 2 and 10 agree on ubiquitous-language's prose-mode
  progression wording? — PASS (Step 10's replacement text repeats Step 2's
  "grilling, spec publication, or `task-master` handoff")
- CHK22: Does the roast-work trim leave the Codex/Cursor reviewer ports
  without an advisory-only statement? — PASS (`:41-45` kept; AC10.4 checks
  "appended AFTER the verdict line" survives, and parity carries it into
  both ports)
- CHK23: Is install-antislop's delete decision defined so it can neither
  auto-delete nor silently keep? — PASS (Step 1 literal text; AC1.5 checks
  both the ask and the "only if the user says yes" sentences, and that
  "can stay" is gone)

Advisory ubiquitous-language (prose mode) on this plan: lens 1, nothing
found ("preload" matches **Preloaded skill**; "mirror" matches
**scaffold-only mirror**). Lens 2: "fork-and-own" sits close to
**declared deviation** but is a different concept (Clarifications, category
8). Lens 3: "archived skill" is new and load-bearing; Step 1 adds it.

## Handoff

The plan resolves to 11 units, so it goes to `task-master` (standard path).
It is published to the tracker with `to-spec` before Step 3 retires that
skill (R10).
Milestones: M1 = Steps 1-4 (retirements and merges), M2 = Steps 5-9
(mechanize and rewrite), M3 = Steps 10-11.

## Scribe update hint
- CONTEXT.md, new entry (Step 1): **Archived skill**: a skill whose
  original files are kept, byte-identical, under
  `docs/archive/skills/<name>/` with an index row naming its origin
  directory and commit. Nothing loads, lists, mirrors, hashes or ships it.
  It exists so a retired or rewritten skill's original stays readable
  without git archaeology. _Avoid_: "deprecated skill" (a deprecated skill is
  still live).
- harness-glossary **drift-tracked skills**: after Step 9, the set is the
  live `handoff` (`fm-noflag`), `codebase-design` and `domain-modeling`
  (`fm`), plus the archived copies of `grilling`, `tdd`, `diagnosing-bugs`
  and `improve-codebase-architecture` (7 skills).
- ADR per the draft in Context (Step 11).
